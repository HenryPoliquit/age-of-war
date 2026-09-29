# 3D Rig: the sword arm and the shield (stage 3) Implementation Plan

**Goal:** Get the raised sword arm out of its folded loop by swinging the elbow out toward the viewer, and make the shield a plate whose width and visible side come from its facing and the camera.

**Spec:** `docs/superpowers/specs/2026-09-29-3d-rig-side-view-design.md` (§4, stage 3 of §6). Builds on `2026-09-29-3d-rig-torso-and-camera.md`.

## Global Constraints

- Same as the earlier stages: `tools/godot` under `timeout`, the kit boundary, view-only, tests deliberately updated and never weakened.
- The approved shield-wall march and every strike stay as they were. The camera is the game's 25°.

**Scope decisions made while building (the spec is updated to match):**
1. **Weapon frame dropped.** `zoom` is a perspective cue (bigger toward the viewer) that the owner asked for; an orthographic camera projects a blade swinging toward the viewer *shorter*. A frame cannot replace it, so `zoom` and `lock` stay.
2. **Torso outline dropped.** A torso is about as wide front-on as it is deep in profile; its silhouette barely changes with `chest_yaw`.
3. **`elbow_out` instead of a `pole` channel.** A swivel angle about the shoulder→hand axis blends as a scalar, keeps the in-plane fold side, and 0 is today's pose exactly.
4. **Shield yaws are authored for the 25° camera.** 55° and 78° read 0.5 and 0.8 wide from it, the widths the owner approved.

## Tasks

### Task 1: `FkRig.swivel_pole`
- [x] `swivel_pole(root, target, bend, out, side := 1.0)`: the in-plane pole turned about the root→target axis toward the viewer's side (or away, for the far arm).
- [x] Tests: swivel 0 equals the in-plane pole; a quarter turn is straight toward the viewer and at right angles to the axis; a unit pole at every angle; the swivelled elbow keeps both bone lengths and moves by less than 0.35 px per degree.

### Task 2: the elbow swing
- [x] `elbow_out` channel (default 0); `solve` builds the near elbow from `swivel_pole`.
- [x] Authored: blade wind 1.0; chop wind 1.0; shield guard 0.9 and wind 1.0; the shield-wall carry 0 (so the march is unchanged). Strikes are 0.
- [x] `FkFigure` treats an arm as planar up to 0.75 px of z (was 1e-3), so a barely swung elbow does not switch drawing mode.
- [x] Tests: the raised arm's elbow stands out at least 2.5 px, the upper arm foreshortens, and the hand stays in the shoulder's plane; the march and the strike stay in the plane; no elbow snap in 3D. The two standing-order layering tests now expect the new order for a sword or axe with a shield (upper arm and forearm over the cap and weapon), and `PARTS` for everything else.

### Task 3: the shield plate
- [x] `shield_yaw` channel replaces `turn` (default 55°); `solve` emits `j.shield = {yaw, width, back}`; `FkFigure` draws with them (`shield_turn` and `back_view` are gone).
- [x] Tests: the width is `|sin(yaw − camera)|` at 0°, 15° and 25°; the brace and the cleave read 0.5 and 0.8 from the game camera; our army shows the back and the mirrored army the face at every camera and phase; no shield, no plate.

### Task 4: verify
- [x] Golden file: 43 more rows regenerated (the shield family's guard and the raised arms); every other row as it was.
- [x] Full test run, kit boundary green.
- [x] At the 25° camera, ranged, heavy and siege sheets byte-identical to before this stage. In the vanguard sheet the walk columns differ by at most one pixel (the plate reproduces today's widths), the spear and halberd rows are untouched, and only the sword-type attack frames differ.

## Result

Done on `art/readable-arms`.

- **Tests:** 174, 0 failures (166 after stage 2, plus 8).
- **The loop is gone.** In the guard and wind-up frames of the sword, axe and shield units the arm now reads as a raised arm: the upper arm foreshortens toward the camera and the forearm and fist rise above it. Strike frames are unchanged (the arm is straight there).
- **The swing is modest where the arm is already long.** The elbow stands out about 6 px for the bare sword's wind-up, but only 3 to 4 px for the shield family and the axe, whose hands sit farther from the shoulder. `elbow_out` is a plain number in `STANCES` if the owner wants it stronger.
- **Not done:** the weapon frame and the torso outline (see the decisions above); the raised arm's shading and the far (shield) arm are as before; the bow, marksman, thrower and staff families keep the in-plane arm until stage 4.
