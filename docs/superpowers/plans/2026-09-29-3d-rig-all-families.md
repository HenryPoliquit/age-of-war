# 3D Rig: the remaining families (stage 4) Implementation Plan

**Goal:** Bring every other weapon family, the walks, the riders and the crews onto the 3D arm: no elbow folded into a ring, and two-handed weapons gripped on one line from any camera.

**Spec:** `docs/superpowers/specs/2026-09-29-3d-rig-side-view-design.md` (§4, stage 4 of §6). Builds on `2026-09-29-3d-rig-arms-and-shield.md`.

## Global Constraints

- Same as the earlier stages. The approved shield-wall march and the melee strikes stay exactly in the plane; joints other than the arms do not move.

**Decisions made while building:**
1. **A default, not a table.** The ring shows in nearly every bent-arm frame (slinger, javelineer, archers, riflemen, spear and halberd, crews), so `elbow_out` defaults to 0.6 and the exceptions are explicit 0s (blade, shield and chop strikes; the shield-wall carry).
2. **The arm's sort order gets the same 0.75 px slack as its draw mode.** Without it the arm jumped over the shoulder cap the moment an elbow moved 0.01 px out. The bow's rule (arm over the cap whenever the elbow is more than 1 px toward the viewer) still holds.
3. **The upper arm wears the cap's colour**, since it now sorts over the cap instead of hiding under it (an armoured figure's sleeve was showing as dark cloth).
4. **`mid` grip for two-handed weapons**, gated on both hands being on the weapon (not with a shield, not while an off hand swings free).
5. **`el`, `bend` and `lock` are not retired.** The bow's steered elbow already keeps both bones their length in 3D and the bow motion is finely tuned; re-deriving it would risk that for no visible change.

## Tasks

- [x] `elbow_out` defaults to 0.6; explicit 0 on the three melee strikes.
- [x] `mid` channel and `solve` (hands drawn in to the centreline); 1 for thrust, pole and the staff's guard and wind-up.
- [x] `FkFigure`: sleeve is the cap's colour; `ELBOW_SLACK` for the arm's sort order; the weapon sorts at `max(hand, shoulder) z + 0.01`.
- [x] Tests: the far hand on the shaft from 25° (spear and halberd wind-up and strike 0.1 px, carried halberd 1.6 px, staff guard 0.6 px); the grip left alone with a shield, for a free off hand and for the staff raised in one hand; no elbow behind its arm for any weapon; the order changes at most 6 times over a swing; a two-handed weapon stays over the head and torso. The layering tests now demand the exact approved order only while the arm is in its plane, and the body's order always.
- [x] Golden file: 628 of 720 rows regenerated. Only arm joints changed (elbows by up to 2.7 px, hands by at most 0.47 px, the weapon direction by 0.05); hips, spine, shoulders, legs, feet and lean are identical in all 720 frames.
- [x] Every role's sheet looked at before and after: spear and halberd, sling, javelin, musket and rifle, both archers, the chariot driver, the cataphract, crews.

## Result

- **Tests:** 180, 0 failures (174 after stage 3, plus 6).
- **Approved poses:** the shield-wall march is joint-for-joint the same (its 28 to 57 differing pixels per walk cell are the sleeve taking the cap's colour at the elbow end). The bow draw frames are unchanged.
- **Not done:** retiring `el`, `bend` and `lock`; the far arm's swing; lateral paths for one-handed grips (nothing needed one).
