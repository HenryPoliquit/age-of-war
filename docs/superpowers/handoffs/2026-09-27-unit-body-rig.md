# Handoff: full-body unit rig (humanoid and mount joints)

## Context: why a new rig

Over this session the unit figures moved from hand-placed limbs to a solved skeleton. That skeleton was then pushed through about a dozen owner motion briefs (sword cut, shield cleave, walk styles, mounted, giants, bow, javelin, sling, rifle). It works, and there are 121 tests.

The body model underneath is still too thin for natural movement:
- **Missing joints.** There is no chest, neck or head joint; the head is placed as an offset from the shoulder line. There is no ankle-and-toe split beyond a rotated boot.
- **Shoulders are just offsets.** They are points relative to one spine line, not a clavicle/chest structure.
- **No depth.** Near/far layering comes only from draw order.
- **The bow hack.** The bow draw needed a special "steered elbow" (`el`) with fake foreshortening, and the owner still sees *elbows rendering behind the shoulder, especially for bows*.

The owner wants the next context to design a proper 2D body rig, one per unit type:
- **Humanoid joints:** head, neck, 2 shoulders, 2 elbows, 2 hands, chest, hips, 2 legs (hip joints), 2 knees, 2 feet (ankles and toes).
- **Goal:** coded in 2D so movement is more natural and elbows and shoulders layer correctly.
- **Later, not now:** attachment points for weapons and shields.
- **Mounts:** defined the same way as the humanoid (a real quadruped skeleton), so horse and boar movement is smoother.

**The next session should start with `superpowers:brainstorming`.** This is an architectural change, so it follows the spec → plan path. Don't jump to code.

## Repo state

- **Branch:** `art/readable-arms`, 35 commits ahead of `main`. Not merged and not pushed; the owner decides when.
- **Tests:** `timeout 300 ../Godot_v4.7/Godot_v4.7-stable_win64_console.exe --headless --path . -s tests/run_tests.gd` → **121 tests, 0 failures**.
- **Godot (local, Windows):** `../Godot_v4.7/Godot_v4.7-stable_win64_console.exe`. Always wrap it in `timeout`.
  - Running `--import` rewrites `.import` line endings. Revert with `git checkout -- assets/fonts/*.import reports/*.import`.
  - Screenshot runs segfault on quit (exit 139). This is known and not a failure.
- **Scratch ledger:** `.superpowers/sdd/2026-09-27-figure-kit-plan-3-skeleton/` (git-ignored). It holds rulings from this session. The Plan 1/2 ledgers were archived into it.
- **Docs to know:**
  - `docs/superpowers/specs/2026-09-27-unit-skeleton-design.md`:
    - §0 kit;
    - §1–2 skeleton;
    - §3 spacing, revised to view-only;
    - §6 motion pass, the owner's briefs.
  - Plans 1, 2 and 3 are in `docs/superpowers/plans/2026-09-27-figure-kit-plan-*.md`. Plan 3's later tasks were overtaken by the owner-driven motion passes.

## Architecture as it stands

**`addons/figure_kit/`** is a reusable kit and must never reference a game class; `tests/test_fk_boundary.gd` enforces this. The game-side adapter is `scripts/view/art/unit_art.gd`, which maps `UnitDef` + race to a kit spec.

| File | Class | Role |
|---|---|---|
| `paint.gd` | FkPaint | Primitives: `begin`/`push`/`pop` transform stack, `seg`, `shade_poly`, `ellipse`, `halo`, `shadow`, `tint`, `move_amount` |
| `looks.gd` | FkLooks | Race body presets (proportions, skin, hair, glow) and era palettes |
| `units.gd` | FkUnits | Entry point `draw(ci, spec, pose, seed)`; `RIGS` (with `depth`); `height`, `muzzle`, `shot`, `wreck`, `depth`, `swing` |
| `skeleton.gd` | FkSkeleton | **The humanoid rig today** (details below) |
| `figure.gd` | FkFigure | Draws the humanoid from `FkSkeleton.solve` joints: legs, torso, head, arms, fist, shoulder cap, smear, impact accents, dust |
| `weapons.gd` | FkWeapons | Weapons drawn at the solved hand and `dir`: `edge_normal`, `LENGTH`, `MUZZLE`, `GUN_BUTT` |
| `armour.gd` | FkArmour | Helmets, packs, shields (`SHIELD_TOP` = grip-to-rim per shield) |
| `mounts.gd` | FkMounts | `quadruped` (procedural leg angles, no skeleton), `mounted`, `_rider`, chariot |
| `machines.gd` | FkMachines | Siege engines; golem and treant (own rigs, giant stride, `giant_contact`) |

**Contracts:**
- `spec` = style keys (`rig`, `helmet`, `weapon`, `shield`, …) + `look` + `palette` + `team`.
- `pose` = `walk`, `move`, `atk`, `t`, `flash`, plus the rider-only keys `ride_walk`, `ride_mv` and `ride_bob`.

**View-side pieces touched this session:**
- `WorldLayer.drawn_x` and `draw_scale`: units are drawn back by their body depth, so opposing bodies keep an 8 px gap. The sim is unchanged.
- `MatchView.AIM = 0.72`: every attack aims at the target's head-to-chest band.

### FkSkeleton today: what the new rig replaces or extends

**Bones and joints:**
- **Bones (× build):** thigh 15, shin 14, upper arm 9, forearm 8.5, spine 20, `HIP_Y` 28.
- **Joints `solve()` returns:**
  - `hip`, `sh` (the shoulder line);
  - `sh_n`/`sh_f` (shoulders = `sh` + fixed offset + pose offset);
  - `elbow_n`/`elbow_f`, `hand_n`/`hand_f`;
  - `knee_n`/`knee_f`, `foot_n`/`foot_f`, `rot_n`/`rot_f` (boot roll);
  - `dir` (weapon direction), `lean`, `lunge`, `crouch`, `zoom`;
  - `dust_*`, `bend_n`, `el_w`, `gait`.
- **Missing:** chest, neck and head joints (the head is `sh + (1.8, -9.5)`), a pelvis tilt, and a toe joint.

**How poses work:**
- **IK:** `ik(root, target, l1, l2, bend)`, with a fixed anatomical bend. `ELBOW = +1`: below a forward reach, in front of an overhead one, behind a hanging one. `KNEE = −1`.
- **Keyframes:** `STANCES[family]` = guard / wind / hit keyframes, blended on `FkUnits.swing` beats: 0–0.35 wind-up, 0.35–0.55 strike, then recovery.
- **Stance channels:**

  | Channel | Meaning |
  |---|---|
  | `h`, `f` | Near- and far-hand targets |
  | `a` | Weapon angle |
  | `s`, `sf` | Shoulder offsets |
  | `lean`, `lunge`, `crouch`, `step`, `wide` | Body placement |
  | `zoom` | Weapon foreshortening |
  | `lock` | Wrist locked to the forearm |
  | `rim` | Shield top-rim position |
  | `rise` | Rider's half-seat |
  | `bend` | Elbow fold side; the arm straightens through a sign change |
  | `el` | Steered elbow, blended by weight (used only by the bow) |

  Paths are `line` or `arc`.
- **Families:** `blade`, `shield`, `chop`, `thrust`, `pole`, `aim`, `bow`, `throw`, `sling`, `staff`, `crew`, `ride_blade`, `ride_thrust`, `idle`.
- **Gaits (`GAITS`):**
  - the styles are `default`, `glide`, `heavy`, `bounce`, `track`, `patrol`, `wall`;
  - each has `bob`, `stride`, `lift`, `heel`, `toe`, `swing` and `hswing`, plus a `carry` pose blended in by `move`;
  - `gait_for(weapon, shield)` picks the style.
- **Drawing quirks the new rig should remove:**
  - The far arm is drawn inside the race-body scale transform, using `unmap`.
  - The near arm is drawn after the head and shield, with arm joints offset by `off` to follow the scaled shoulder.
  - Layering is purely code order in `FkFigure.humanoid`.

**Mounts today:**
- `FkMounts.quadruped` computes each leg as angle-rotated segments per front/hind and near/far, with phase offsets for a four-beat walk. There are no joints or IK, and the body and neck are fixed polygons.
- The rider is a seated humanoid (`legs=false`) sitting on the returned saddle point.

## Owner direction to carry forward

**Owner's words:**
- "all feet should look at the same direction"
- "elbows shouldn't move on top of the shoulder"
- "the arm to hand is straight" on a downward slash
- "the wind up for the bow so that the elbows move from the side"
- "aim all attacks on the area between head and chests"
- "units should not touch the opponent too closely" (the gap is view-only: balance must not move)

**Look:** eyes over the shield rim, relaxed but tense shield walk, full range of motion, no limb snapping. The owner judges by watching motion, so always republish the animation page.

**Briefs:** the owner's pasted motion briefs are recorded in spec §6 and in the commit messages. Re-read them before changing any stance.

**Process preferences:**
- Show, then iterate: publish the animation page after each change.
- The owner likes being asked a decision with a recommendation.
- Keep balance untouched (view-only changes).
- The kit must stay reusable for other games.

## Review tooling

- **Animation page:** `https://claude.ai/artifact/NmKt5Dn4HPV7ArTeiv3RXm` (version 11 at handoff). It shows every unit's walk and attack GIF, grouped by role with the three races side by side.
  - Rebuild:
    1. Render frames: `timeout 200 "$G" --path . --resolution 1280x720 -s tools/unit_anim.gd -- --out=<scratch>/anim/frames --frames=24`.
    2. Build the page: `python tools/anim_page.py <scratch>/anim/frames <scratch>/anim "<build note>"`.
    3. Republish `<scratch>/anim/index.html` with `root=<scratch>/anim` and `files` = every `gif/*.gif` (69).
  - A new conversation must pass the artifact `url` to update it in place.
- **Other tools:**
  - `tools/unit_sheet.gd --role= --race=` for static sheets;
  - `tools/unit_gallery.gd` (colour / grey / silhouette; `--atk=`);
  - `tools/base_gallery.gd`.
- **Frame-by-frame strips:** crop cells from the frames with Pillow. Walk is the left 200 px of a 400×260 cell; attack is the right 200 px.

## Open items, not part of the next task

- **The branch:** merge and push are the owner's call.
- **Kit README:** it lacks FkSkeleton, stances, gaits, `depth`, and the required spec keys `look`/`palette`/`team` (Plan 3 Task 9 was never done).
- **Deferred minors:**
  - turret barrel aims at sim x;
  - `UnitArt.AGE_CLOTH` is dead code;
  - the `wood` local shadows the `wood()` function;
  - units are drawn up to 62 px behind their own gate at spawn;
  - two low-value tests.
- **Balance:** not green (3/8 targets, seed 1), unrelated to this work. The "waves don't form without Hold" design question is still open.
- **Not briefed yet:** the staff, siege crews and chariot drivers only got generic joints; siege machines are untouched.

## Next task: brief for the new session

**1. Humanoid body rig.** Joints: head, neck, chest, hips (pelvis), 2 shoulders, 2 elbows, 2 wrists/hands, 2 hips (leg roots), 2 knees, 2 ankles, 2 toes (feet).
- **Hierarchy:** pelvis → spine/chest → neck → head, with shoulders on the chest and legs on the pelvis.
- **Solving:** each joint is solved in 2D. Bone lengths are fixed per race/build, but foreshortening is allowed for limbs swinging toward or away from the viewer.

**2. Depth for correct layering.** Add a per-joint or per-bone depth (near/far/front/back), so:
- the draw order of arm, shoulder, torso, head and weapon comes from the pose, not from fixed code order;
- the "elbow behind the shoulder" artefact (bow draw especially) can't happen.

Diagnose the current artefact first. Render bow draw frames and see whether it is z-order (near upper arm drawn over/under the torso, head or shoulder cap) or position (the steered `el` path).

**3. Natural movement from the structure.**
- Chest and pelvis counter-rotate while walking.
- The shoulder rides on the chest, the head stays level via the neck, and the heel-toe roll comes from real ankle/toe joints.
- Keep every existing owner-approved motion (stances and gaits); re-express them on the new joints.

**4. Weapon and shield attachment points: planned but decided later.** Leave a hook (e.g. named sockets on the hand, forearm and back).

**5. Mount rig**, the quadruped equivalent:
- poll/head, neck, withers, back, croup, dock/tail;
- per leg: shoulder or hip, elbow or stifle, knee (carpus) or hock, fetlock, hoof.

It needs a proper gait on it (four-beat walk now; trot/gallop for charges later), plus the rider sitting on a saddle joint rather than a returned point.

**Questions to settle in brainstorming:**
- Representation: forward kinematics (joint angles per pose) vs the current IK-to-targets vs a hybrid (IK for hands and feet, FK for spine, neck and head).
- How poses and stances are authored: keep the channel keyframes, or move to per-joint angle keys.
- Depth model: a z value per joint, or near/far layers only.
- Migration: rebuild behind the existing `FkSkeleton.solve` contract so `figure.gd`, `weapons.gd` and the 121 tests keep working, or replace it with a new contract.
- Whether mounts share a generic rig engine (bones + IK + depth) with humanoids.

**Keep invariant:**
- the kit boundary (no game classes);
- the sim and balance untouched;
- the approved motions and briefs;
- the tests (update deliberately, never weaken);
- review via the animation page after each step.

## Verification for the handoff itself

- `docs/superpowers/handoffs/2026-09-27-unit-body-rig.md` exists on `art/readable-arms` and is committed.
- The next session can reproduce, from it alone:
  - the test run (121 passing);
  - one animation page rebuild and republish to the same URL.
