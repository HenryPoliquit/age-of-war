# Humanoid body rig: design

Follows `docs/superpowers/handoffs/2026-09-27-unit-body-rig.md`. Extends `2026-09-27-unit-skeleton-design.md` (§1–2 skeleton, §6 owner motion briefs).

## Why

The solved skeleton (`FkSkeleton`) carries a dozen approved owner motion briefs, but its body model is thin:
- no chest, neck, head or toe joints (the head is an offset from the shoulder line);
- shoulders are fixed offsets, not carried by a chest;
- no depth: layering is the fixed code order in `FkFigure.humanoid`;
- race proportions are a non-uniform scale transform around the drawing, with `off`/`unmap` hacks for the arms.

The owner wants a proper 2D rig with correct layering, and movement that comes from the structure.

## Diagnosis: the bow "elbow behind the shoulder" artefact

Bow draw frames were rendered with a skeleton overlay. The joints do what the brief asks: the elbow travels level and straight back. The artefact is **z-order**:
1. The shoulder cap is drawn after the whole near arm. At full draw the folded arm puts the elbow and forearm root under the cap, so the elbow disappears into it.
2. The bow (limbs, string, arrow) is drawn after the near arm, so the string crosses over the drawing arm.

A pose-derived draw order fixes both, which is what this design adds.

## Decisions (owner, 2026-09-27)

| Question | Decision |
|---|---|
| Scope | Humanoid first. The quadruped mount rig gets its own spec → plan cycle right after. |
| Representation | 2.5D hybrid: every joint has a depth `z`. FK chain for pelvis → chest → neck → head. IK for hands and feet to the **existing** stance targets. |
| Authoring | Keep the stance/gait channel keyframes. No approved motion is re-authored. |
| Depth model | A z per joint. Each drawn part gets z from its joints plus a bias; parts are sorted. |
| Migration | Extend the `FkSkeleton.solve` contract: every existing key keeps its meaning, and new keys are added. |
| Mounts | Out of scope here. They share the IK helper and the sorted draw list later. |

## 1. Rig (`FkSkeleton.solve`)

**Space.** Unchanged: feet at y = 0, facing +x, up is −y. New: depth `z`, positive toward the viewer. `j.z` is a Dictionary from joint name to float. `W` = half body width = `4.0 × build × body.x`. At rest the near side sits at `z = +W` and the far side at `−W`.

**Signature.** `solve(b, weapon, pose, shield := "", seated := false, look := {})`. From `look`, `body` (Vector2, default `(1, 1)`) and `head` (float, default 1) are read. The defaults reproduce today's joints exactly, so existing callers and tests are unaffected.

**Joints.** ★ marks a new joint.

| Chain | Joint | Definition |
|---|---|---|
| Spine | `hip` | Pelvis centre, as today. z 0. |
| | ★`chest` | `hip.lerp(sh, 0.55)`. z 0. Anchor for the torso drawing and the `back` socket. |
| | `sh` | Neck base, as today: `hip + (1.5, −SPINE)·b·body.y` rotated by `lean`. |
| | ★`neck` | `sh + (0.8, −3.5)·b`, rotated by `0.5·lean`. |
| | ★`head` | `neck + (1.0, −6.0)·hb`, rotated by `head_tilt = 0.25·lean` (hb = b·look.head). At lean 0 it equals today's `sh + (1.8, −9.5)·hb`. The head is drawn rotated by `head_tilt`. |
| | ★`eye` | `head + (3.4, −0.9)·hb`, rotated by `head_tilt`. |
| Pelvis | ★`hip_n` / `hip_f` | `hip + (±W·sin yaw_p, 0)`, z `±W·cos yaw_p`. These are the leg roots. |
| Shoulders | `sh_n` / `sh_f` | Today's offsets (`(2, 1)·b + s`, `(−3, 1)·b + sf`) plus `(∓W·sin yaw_c, 0)`, z `±W·cos yaw_c` (clavicles on the chest). |
| Arms | `elbow_*`, `hand_*` | IK to the same stance targets as today. |
| Legs | `knee_*`, `foot_*` | IK from `hip_*`. `foot` stays the ankle. |
| | ★`toe_n` / `toe_f` | Ball of the foot: `foot + (4.5, 1.5)·b` rotated by `rot`. |
| | ★`toe_bend_*` | See §3. |
| Hook | ★`sockets` | `{grip_n, grip_f, back}`, each `{p: Vector2, a: float, z: float}`. `grip_*` sit at the hands (`a` = weapon dir for near, forearm dir for far); `back` sits at the chest (`a` = spine angle). They feed the layering only, with no other consumers yet. |

**Bone lengths in 3D.** THIGH, SHIN and SPINE are multiplied by `body.y`; UPPER and FORE are not (arms keep their own proportions, as today). Every bone keeps its exact length measured in (x, y, z).

**Foreshortening replaces the `el` hack.** When a stance steers an elbow (`el`), the elbow's on-screen position is `el` (clamped so its screen distance from the shoulder is ≤ UPPER). Its depth is then `z_sh + sqrt(UPPER² − d²)`, toward the viewer. The hand's depth completes the forearm the same way (`z_el − sqrt(FORE² − d²)`, back toward the body). Unsteered arms are planar: elbow and hand take the shoulder's z. So mid-draw, the bow elbow points at the viewer (large z); at full draw it is back near the plane.

**Race proportions in bones, not a transform.** `figure.gd` stops wrapping the body in a scale transform. Legs and spine get their length from `body.y`; drawn widths (limb strokes, torso polygon x-offsets) are multiplied by `body.x`. This removes `off`, `jn` and `unmap`. It also fixes dwarf thighs, which are currently solved at human length and then squashed, so their drawn length changes as they swing. Expected visible change: dwarf strides are about 20% shorter. Reviewed on the page.

## 2. Depth and layering (`FkFigure.humanoid`)

`humanoid()` works in three steps:
1. Solve.
2. Build `parts` = an Array of `[z, rank, name, Callable]`.
3. Sort by `(z, rank)` and draw.

`rank` is the part's index in today's draw order, so ties keep today's approved look. A part's `z` is the mean z of the joints it covers plus the bias below.

| rank | Part | z |
|---|---|---|
| 0 | shadow | −100 |
| 1–2 | far leg, near leg | −50, −49 (the torso keeps covering the hip joints) |
| 3–4 | cape, pack | −40, −39 |
| 5 | far arm (upper, fore, hand) | mean of the far arm's joints (≈ −W) |
| 6 | torso (body, armour, tabard, belt, pauldron) | 0 |
| 7 | head (long hair, neck, face, beard, helmet, ears) | 0.5 |
| 8 | shield | `grip_f.z + 2W` (in front of the chest and head: eyes over the rim) |
| 9 | bow / starbow (limbs, string, arrow) | 1.0: over the head (the string anchors on the near side of the jaw), under any near-arm part (their z stays ≥ W − 1 > 1 at every draw frame). Weapons in `FkWeapons.HELD_FAR` use this part instead of rank 14. |
| 10 | smear | 50 |
| 11 | near upper arm | mean(`sh_n`, `elbow_n`) |
| 12 | near forearm + fist | mean(`elbow_n`, `hand_n`) |
| 13 | shoulder cap | `sh_n.z` |
| 14 | other weapons | `grip_n.z + 0.01` |
| 15–16 | impact accents, dust | 100, 101 |

Consequences:
- **Unchanged at rest.** With yaw 0 and planar elbows the sorted order equals today's order.
- **Bow fixed.** The bow sorts under the near arm and cap (the string no longer crosses the arm). Whenever the elbow is toward the viewer (mid-draw strongly, full draw slightly), the upper arm sorts over the shoulder cap, so the elbow stays visible. The forearm, running back toward the jaw at full draw, sorts under the cap, which matches its real depth.
- **No flicker.** Every z is continuous in the pose. Parts swap only where depths genuinely cross.
- **Same path everywhere.** Riders, crews and chariot drivers go through `humanoid()` and get the same layering.

`FkFigure.layers(spec, pose, seed := 0) -> Array[String]` returns the sorted part names without drawing. It exists for tests.

`FkArmour.shield` and `FkWeapons.weapon` keep their signatures. They are called from part Callables.

## 3. Natural movement

**Walk counter-rotation.** Each gait gets a `twist` value (rad):
- **Motion:** `yaw_p = twist·sin(walk)·move` (the pelvis turns with the near foot); `yaw_c = −0.8·yaw_p` (the chest turns against it).
- **Values:** `default` and `bounce` 0.35; `glide` and `heavy` 0.25; `track`, `patrol` and `wall` 0.1.
- **Attacks and riders:** yaw 0. No stance twist channel this cycle.

**Level head.** The neck follows half the spine's lean and the head a quarter (§1). Upright, the head sits exactly where it does today.

**Ankle and toe.**
- **Push-off:** the heel lifts while the toe cap stays flat on the ground, `toe_bend = max(rot, 0)·(1 − lift/1.5)` clamped to [0, rot] (`lift` is the foot's lift in px/b). The foot hinges at `toe`.
- **Heel strike:** the toes rise with the foot (bend 0).
- **Ground rule:** covers the heel part and the bent toe part. The ankle rises only as far as the heel part needs.
- **Drawing:** `FkSkeleton.boot(foot, rot, b, toe := 0.0)` rotates the boot points ahead of the ball (x > 4.5) about the ball by `−toe`.

**Out of scope:**
- pelvis side-drop (invisible in profile);
- torso turn in attack stances (a new motion, so it waits for an owner brief);
- socket consumers;
- the mount rig (next cycle);
- staff, crew and chariot briefs;
- siege machines, golem and treant.

## 4. Testing

**Existing 121 tests** keep passing, with two deliberate, stricter changes:
- `test_bones_never_stretch`: the bow's "foreshortened, never longer" branch becomes exact 3D length for every arm bone.
- Eye/rim tests (`test_eyes_over_the_rim_for_every_shield`, rifle "under the sighting eye", bow "arrow beneath the eye") use `j.eye.y` instead of `sh.y − 10.4`.

**New tests (`tests/test_fk_skeleton.gd`, `tests/test_fk_units.gd`):**
- Every bone, new ones included (neck, head, foot, toe), keeps its 3D length in every `FRAMES` frame for every weapon, and with dwarf and elf `look`.
- Default look (`look = {}`) returns the same pre-existing joints as before, at rest and attack frames (yaw 0).
- Counter-rotation: over a default walk cycle, `(sh_n − sh).x` is anti-correlated with `foot_n.x` (correlation < −0.5). Existing steadiness bounds hold for `track`, `patrol` and `wall`.
- Head: `|head_tilt| < 0.1` in every stance and gait frame.
- Toe: at maximum toe-off the toe tip is on the ground (|y| < 0.1) and the heel is lifted (> 2 px). No boot point is below ground in any walk frame.
- Layers: for each weapon family's guard frame, `layers()` equals the legacy order. For the bow at every atk in 0..1 (step 0.01), the bow sorts under `near upper arm` and `near forearm`, and `near upper arm` sorts over `shoulder cap` whenever `z(elbow_n) > z(sh_n) + 1`.
- Kit boundary test unchanged (no game class referenced).

**Commands:**
```sh
timeout 300 ../Godot_v4.7/Godot_v4.7-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
```

## 5. Review loop

Three stages, each ending with the animation page rebuilt and republished to the same URL (`https://claude.ai/artifact/NmKt5Dn4HPV7ArTeiv3RXm`, rebuild steps in the handoff), plus a before/after close-up strip of the bow draw:

1. **Joints and depth in `solve()`**: new joints, `look`, z, sockets, 3D foreshortening. Nothing visual changes (the drawing still uses the old keys).
2. **Layering**: `figure.gd` moves to bone-length proportions and the depth-sorted part list. This fixes the bow artefact.
3. **Movement**: counter-rotation, level head, toe joint.

The owner reviews locally. The sim and balance are untouched: all changes are in `addons/figure_kit/` and its tests.
