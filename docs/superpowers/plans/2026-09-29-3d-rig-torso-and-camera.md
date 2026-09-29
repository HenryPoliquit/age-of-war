# 3D Rig: torso turn and camera yaw (stage 2) Implementation Plan

**Goal:** Let the camera turn (`view.yaw`, default 0) and let the torso turn in attacks (`pelvis_yaw`, `chest_yaw`), so the side view starts to read as a 3D body. The camera default stays square-on until the owner picks an angle from the review sheets.

**Spec:** `docs/superpowers/specs/2026-09-29-3d-rig-side-view-design.md` (stage 2 of §6). Builds on `2026-09-29-3d-rig-core.md`.

## Global Constraints

- Same as stage 1: `tools/godot` under `timeout`, kit boundary (no game class named in `addons/figure_kit/`), view-only (no sim, no balance, nothing under `data/`), tests deliberately updated, never weakened.
- At yaw 0 with no stance yaw, every figure is exactly stage 1's. The only intended visual change at yaw 0 is the melee swings (blade, shield and chop families) in their wind-up, strike and recover frames.

**Decisions made while building (the spec is updated to match):**
1. **Parts sort by the rig's z, not by camera depth.** Sorting by `z·cos(yaw) + x·sin(yaw)` reordered the near-arm group in 86 of 88 test poses at 15° (the shoulder cap under the arm, the weapon under the shield). `j.z` is the joint's z at any yaw, so `FkFigure.layers` is identical at every yaw. `FkRig.depth` was removed.
2. **No `Frame` helper.** The pelvis and chest are already a yaw of the lateral offset; nothing needs roll or pitch yet.
3. **The strike targets move forward with the shoulder.** The hand targets clamp the arm to full extension. A chest turn moves the shoulder about 2 px forward, which put the same target inside reach and broke "arm to hand is straight" (an owner brief, `test_blade_arm_straight_at_the_hit` and the shield lockout test). Blade `hit` `h` went from `(22, 5)` to `(25, 5)` and shield `hit` `h` from `(20, 10)` to `(22.5, 10)`. Contact reaches about 2 px further: the reach a torso turn adds.
4. **Yaw reaches only humanoids** (and their riders, crews and drivers, through `dress`). Mounts, machines, golem and treant follow at stage 5.

## Tasks

### Task 1: the camera
- [x] `FkRig.project_all(p, view)` (one read of the view per figure), `project_dir`, `xy`; tests.
- [x] `FkSkeleton.solve(…, look, view)`: everything is solved in rig space and projected once at the end. The weapon direction is the projection of its in-plane direction.
- [x] `FkFigure` passes `spec.view` to `solve` (and to `_smear`); `dress` carries it to crews and drivers.
- [x] `UnitArt.view_yaw` (one static knob, default 0) and `--yaw=DEG` on `unit_sheet`, `unit_gallery`, `unit_anim`.
- [x] Tests: `p3` is identical at every yaw; keys are `project(p3, view)`, and `z` is `p3.z`, at 0°, 15° and 25° for every weapon, race, shield and rider; an explicit yaw 0 is the same figure; the sides spread by `2·z·sin(yaw)`; the weapon direction is the projected direction; `FkFigure.layers` is the same at ±15° and 25°.

### Task 2: the torso turn
- [x] Channels `pelvis_yaw`, `chest_yaw` in `_FLOATS` and `solve` (added to the walk's counter-rotation).
- [x] First pass, blade / shield / chop only. Wind-up: pelvis −0.2 / −0.15 / −0.25 and chest −0.6 / −0.5 / −0.7 rad. Strike: pelvis +0.3 / +0.25 / +0.3 and chest +0.6 / +0.55 / +0.7 rad. Guard: 0. The hips lead, the chest follows.
- [x] Strike targets moved forward with the shoulder (decision 3).
- [x] Golden file: 54 of 720 rows regenerated (the wind-up to recover frames of sword, axe and saber, with and without a shield); every other row is byte-for-byte as it was.

### Task 3: verify
- [x] Full test run, kit boundary green.
- [x] Sheets before and after at yaw 0: ranged, heavy and siege byte-identical. Vanguard sheets differ only in the wind-up, strike and recover columns of the sword-type units, never in a walk or guard column and never in the spear or halberd rows.
- [x] Sheets at 15° and 25° rendered and compared with 0° (`tools/unit_sheet.gd --yaw=`): no layering artefacts.

## Result

Done on `art/readable-arms`.

- **Tests:** 166, 0 failures (159 after stage 1, plus 7).
- **Yaw 0 identity:** for everything except the three melee families' attack frames, the joints are as in stage 1 (worst deviation 0.00003 px against the pre-rig golden file) and the sheets are byte-identical.
- **The torso turn is modest in profile, as physics says.** A chest yaw of 0.6 rad moves the weapon shoulder about 2.3 px forward or back on a 9 px wide torso. The camera yaw adds `z·sin(yaw)` on top (about 1.9 px per side at 25°). The bigger payoff is the arm and shield motion of stages 3 and 4. The yaw values are plain numbers in `STANCES` for the owner to tune.
- **Speed:** `solve()` about 85 µs per call, as after stage 1 (fixed loop; noisy, 81 to 95).
- **Not done here:** the torso outline does not turn with `chest_yaw` (stage 3), and the elbow loop in the raised sword arm is still there (stage 4).
