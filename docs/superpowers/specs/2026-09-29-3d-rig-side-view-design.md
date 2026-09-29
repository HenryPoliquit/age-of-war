# 3D rig, seen from the side: design

Follows `2026-09-27-humanoid-body-rig-design.md` (the 2.5D rig this promotes) and comes before `2026-09-28-mount-rig-design.md`, which will be rebased onto it (§7).

## Why

Owner, 2026-09-29: "I want the models to basically be the 2D perspective of a 3D model. The model is actually doing the whole proper action, carrying a shield, walking, doing attacks, but we can only see the side perspective, hence the 2D. This makes the action still fluid."

So the body is a 3D skeleton and the game looks at it through one fixed, orthographic, side-on camera. The art stays painted 2D parts.

## Diagnosis: what is still 2D

The humanoid rig is 2.5D: every joint has a depth `z`, the pelvis and chest yaw on the walk, and parts sort by depth. The solve itself is planar.

| Where | What is 2D | Symptom |
|---|---|---|
| `FkSkeleton.ik` | Two-bone IK on `Vector2`, fold side picked by a ±1 `bend`. | An arm can only fold within the picture plane. Raised sword arms fold into a tight loop over the face (legionary, brawler, man-at-arms; guard and wind-up). A real elbow points out toward the camera there and the upper arm foreshortens. |
| `STANCES` | Hand targets `h`, `f`, `rim` are screen offsets from `sh`. | No lateral movement exists to author: nothing can cross the body or swing out to the side. |
| `el`, `el_w`, `_fit` | The bow elbow is steered on screen, and its `z` is back-computed to keep bone length. | One special case standing in for "arms move in 3D". |
| `zoom`, `lock` | Weapon foreshortening and wrist lock are hand-authored scalars. | `weapons.gd` grows the blade as the cut comes toward the viewer. |
| `turn` | Shield openness is a hand-authored scale (`armour.gd` `squash`). | The shield is a flat slab. Its facing, `back_view`, and rim sliver are all faked. |
| Torso | Yaw exists on the walk only. Attack stances have none. | The chest never turns into a cut. (The humanoid spec parked this for an owner brief.) |

## Decisions (owner, 2026-09-29)

| Question | Decision |
|---|---|
| Approach | **3D rig, painted 2D parts.** Solve in 3D, project, draw the same procedural parts at the projected joints. Not real meshes baked to sprites: that would replace the procedural kit with a mesh and bake pipeline. |
| Camera | **Profile by default, yaw as a parameter.** Ship yaw 0 (identical to today) and compare 0°, 15° and 25° on the review page before choosing. |
| Order | **3D core first, then mounts on it.** The mount rig is docs only so far, so nothing is redone. |

## 1. Space and camera

**Rig space.** The kit's axes, plus a real third one: `x` forward (the way the figure faces), `y` down (up is −y), `z` toward the viewer (the near side is +z, as today). A rig point is `Vector3(x, y, z)`. The axes are left-handed, so every rotation goes through an `FkRig` helper with its sign pinned by a test, never through `Basis` by hand.

**Camera.** A fixed world camera, orthographic (no perspective scaling):

```
screen.x = x·cos(yaw) − z·sin(yaw)      screen.y = y
```

At yaw 0 the projection is `(x, y)`, so everything is exactly today's picture. A positive yaw moves the camera toward the side the figure faces, so the near side shifts toward the rear by `z·sin(yaw)`. At 20° the near and far shoulders are about 3 px further apart, which is what makes a torso turn read.

**Parts still sort by z, not by camera depth.** The camera's depth is `z·cos(yaw) + x·sin(yaw)`. Sorting by it was tried first and rejected: the approved layering depends on parts that tie in z (the near arm's upper arm, forearm, cap, weapon and shield all sit at the shoulder's z and are ordered by rank), and the `x·sin(yaw)` term breaks those ties differently for each part. At 15°, 86 of 88 test poses reordered (the cap under the arm, the weapon under the shield: the "elbow behind the shoulder" artefact again). The rig's z, the side of the body a part is on, stays the sort key at any yaw. The yaw only moves the picture: the near side shifts back, the far side forward, and the layering is unchanged.

**Mirrored figures are unchanged.** A world-fixed camera projects a figure turned 180° as the exact mirror image of the unturned projection, and the view already flips x and the kit already negates depth (`FkFigure._parts`). No per-army yaw is needed. The yaw is one project constant that the game-side adapter (`UnitArt`) passes as `spec.view = {yaw}`.

**Out of scope:** camera pitch, perspective.

## 2. `FkRig` (`addons/figure_kit/rig.gd`, new, game-agnostic)

Pure math, no game classes.
- `project(p: Vector3, view: Dictionary) -> Vector2` (§1), `project_all(p, view)` (a whole joint dictionary, reading the view once), `project_dir(d, view)` (a rig direction as a screen unit vector) and `xy(p)`. There is no camera-depth function: parts sort by z (§1).
- `ik3(root, target, l1, l2, pole: Vector3) -> Vector3`: the middle joint (elbow or knee) of a two-bone limb.
  - It lies in the plane through `root→target` containing `pole`, on the pole's side, and never stretches (the distance is clamped exactly as `ik` does now).
  - The pole is a direction, so the joint turns continuously around the root→target axis. That replaces the ±1 flag and the "arm straightens through a sign change" workaround.
  - Degenerate when `pole ∥ root→target` (a fully extended limb): the joint sits on the line, and the caller passes the previous pole as the fallback.
- `reach3(root, target, l1, l2)`: the 3D `reach`.
- `Frame` (origin + yaw, lean, roll) was in the first draft and is **not built**: the pelvis and chest are already a yaw of the lateral offset in `solve`, which is all the torso turn needs. It arrives if a roll or pitch does.

`FkSkeleton.ik` and `reach` stay (mounts and tests use them) until stage 5.

## 3. `FkSkeleton.solve`: joints in 3D, contract kept

`solve(b, weapon, pose, shield := "", seated := false, look := {}, view := {})`.

**Output.** Every existing key keeps its name and type:
- `hand_n`, `elbow_n`, `sh_n`, … stay `Vector2`, now `project(p3[name])`;
- `j.z[name]` stays a float: the joint's z, whatever the camera.

New: `j.p3` (joint name → `Vector3`) and, from stage 3, `j.wpn` and `j.shield` (§4). At yaw 0 with in-plane inputs, every existing key equals today's value, so `figure.gd`, `weapons.gd`, `armour.gd` and `mounts.gd` keep working untouched in stage 1.

**Solving.**
- The hips and shoulders take their fore-aft shift and z from the pelvis and chest yaw. The walk twist and the stance channels `pelvis_yaw` / `chest_yaw` add up.
- Neck and head stay an FK chain on the chest frame (as today).
- Arms and legs are IK to 3D targets with a pole.
- Bone lengths are exact in 3D by construction, for every bone including the wrist and toe. `_fit` and the `el` special case go.

**Stance channels.**
- `h`, `f`, `rim` accept `Vector3`. Its `z` is the lateral offset, + toward the near side. A `Vector2` means today's meaning (the shoulder's own plane), so every existing keyframe stays valid.
- New `pole` (elbow or knee direction, `Vector3`). The default reproduces today's in-plane fold side from the `bend` rules, so nothing moves until a family opts in.
- New `pelvis_yaw` and `chest_yaw` (rad), blended like any channel (stage 2).
- Retired at stage 3: `el`, `bend`, `zoom`, `lock`, `turn`.
- `lean`, `lunge`, `crouch`, `step`, `wide`, `rise`, `s`, `sf`, `a` and the `guard / wind / hit` structure stay.

## 4. Held objects as 3D frames (stage 3)

**Weapon.** `j.wpn = {origin, axis, edge}` (`Vector3` each): grip, tip direction, and the cutting-edge normal. Drawing projects the tip and the edge:
- the blade lengthens or shortens with the projected axis, replacing `zoom` (`j.dir` and `j.zoom` are still emitted as projected values while consumers migrate);
- a blade reads thin when edge-on and wide when flat, from the projected edge normal;
- the wrist locking to the forearm is the axis following the forearm, replacing `lock`.

**Shield.** `j.shield = {origin, normal, up}`: a plate at the far hand.
- Each shield kind is still authored flat in its own plane (`_face`). It is drawn under one `Transform2D` built from the projected plate axes (`FkPaint.push` already takes a `Transform2D`; today's `squash` is the special case `Vector2(turn, 1)`).
- Which face shows (painted face or grip side, replacing `back_view`) is the sign of `normal · view`. The rim's thickness sliver is the plate thickness projected along the normal.
- A shield can now swing open, bash forward or tilt, by turning its frame.

**Body parts.** The same idea applies where it is cheap: the torso polygon is anchored on the chest frame (it turns with `chest_yaw`), and limbs stay capsules between projected joints. Head yaw is out of scope: the face art has no turned views.

## 5. Depth and layering

`FkFigure._parts` is unchanged in structure: `[depth, rank, name, draw]`, sorted. Depths come from `j.z`, the rig's z, so the order is the same at any camera yaw (§1). An arm swinging out of the plane already splits into upper arm and forearm parts; the splitting condition becomes "planar in 3D".

## 6. Staging and review

Every stage: tests green, `tools/unit_sheet.gd` renders, and the animation page republished (same URL) with a before/after strip. The owner reviews motion locally.

1. **Core.** `FkRig`, `p3`, IK3 with in-plane poles. Nothing visual changes. The 720-frame golden test (`fk_golden.txt`) proves it.
2. **Torso turn and camera yaw.** `pelvis_yaw`, `chest_yaw` channels, first authored for the melee swings (blade, shield, chop): the weapon shoulder pulls back on the wind-up and drives forward on the strike, the hips leading the chest, and the strike targets move forward with the shoulder so the arm still locks straight. `view.yaw` plumbed through `spec.view` (`UnitArt.view_yaw`). Sheet, gallery and animation tools get `--yaw=`. Review 0°, 15° and 25°, then the owner picks the default.
3. **Held-object frames.** Shield plate and weapon frames. Retire `turn`, `zoom`, `lock`, `el`, `bend`.
4. **Re-author the families in 3D**, one per owner brief, starting from the approved 2D motion (same hand target, plus a lateral component and a pole). Order: sword and shield (the brief that started this), blade, chop, thrust and pole, bow, aim, throw and sling, staff.
5. **Mounts on `FkRig`.** Revise the mount spec and plan: the quadruped's IK becomes `ik3` and its `z` a real axis. Then the rest of that spec.

## 7. Testing

**Kept, unchanged:** all existing tests (baseline on this branch: 148 tests, 0 failures). `test_default_look_matches_the_pre_rig_skeleton` (golden) stays the identity check for every stage-1 and stage-2 change at yaw 0.

**New (`tests/test_fk_rig.gd`, additions to `tests/test_fk_skeleton.gd`):**
- `ik3` with an in-plane pole equals `ik` for both bend signs, over a grid of targets.
- `ik3` keeps both bone lengths exactly, and the joint is continuous as the pole turns a full circle around the axis (no jump larger than the pole step).
- `project` at yaw 0 is `(x, y)`. A yawed near-side point shifts toward the rear, and a figure turned 180° projects as the mirror image, which is what the view's flip and the kit's negated z already do.
- The camera moves the picture, not the rig: `p3` is identical at every yaw. The layering (`FkFigure.layers`) is identical at every yaw.
- Every bone in `p3`, including the wrist and toe, keeps its 3D length in every `FRAMES` frame, for every weapon, race and shield, at yaw 0, 15° and 25°.
- Projected keys equal `project(p3[...], view)` and `z` equals `p3[...].z`, at yaw 0, 15° and 25°.
- With `chest_yaw`, the near shoulder moves forward and the far one back, with a fixed shoulder width in 3D.
- Stage 3: the shield's visible face flips with the sign of `normal · view`. A blade seen edge-on projects thin.

**Performance:** `solve()` runs per unit per frame (and 9 times per strike frame in `_smear`). Measure it before and after stage 1 with a fixed 1000-call loop, and keep it within 2×. The sim and balance are untouched, so the harness is not affected.

## Risks

- **Mounts and machines do not turn with the camera until stage 5.** At yaw ≠ 0 a rider is yawed and its horse is not (a couple of pixels of mismatch at 25°). Review the yaw on the foot soldiers.
- **Yaw ≠ 0 on 2D-authored motion.** The approved poses were tuned in the flat profile. At 15°–25° they project with the depth shift and a slight x compression (`cos 25° = 0.91`). The review in stage 2 decides whether to compensate (uniform x scale) or accept.
- **Degenerate pole.** A straight arm has no elbow plane. Covered by the fallback pole and the continuity test.
- **Left-handed axes.** Handled by pinning every rotation helper's sign with a test.

## Out of scope

Real meshes and sprite baking; camera pitch; perspective scaling; head yaw; cloth and cape simulation; siege machines, golem and treant (later, on `FkRig`).
