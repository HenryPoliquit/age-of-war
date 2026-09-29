# 3D architecture for bases and towers: design

Follows `2026-09-29-3d-rig-side-view-design.md`. Owner, 2026-09-29: "We'll also need to improve the towers and base to actually have some level of architecture similar to the 3d approach on units."

## Why

Units are 3D bodies seen through a 25° camera; the bases and towers are flat front elevations, one polygon per part, with no depth. Beside a soldier who shows his side and a hint of his front, a castle that is a painted backdrop breaks the picture. Every structure needs volume: a front, a lane-facing end, bodies standing in front of and behind each other.

## Approach

**Bodies in depth, projected through the units' camera.** Structures are built from a few 3D primitives (`Arch`, `scripts/view/art/arch.gd`) standing in the view's local space (x toward the enemy, y down, z toward the viewer), projected with `FkRig`'s camera yaw (`UnitArt.view_yaw`, 25°). No new renderer: everything is still `_draw` calls, and bases still render once into a cached texture.

**A face is a plane, and flat art goes on it.** Each vertical face has a transform: the front plane z = zf is the picture squeezed by cos(yaw) and shifted by −zf · sin(yaw) (the chariot's `_plane`); the lane-facing end plane x = xr maps its depth to screen x at sin(yaw) per unit, so a 44-deep wall shows an 18 px end. The existing 2D detail code (masonry courses, planks, windows, banners) is drawn on a face through its plane, so most of the old art is reused, foreshortened for free.

**Primitives.** `box` (front and end faces, optional ink), `cylinder` (round towers, with masonry whose joints squeeze toward the edges), `cone` and `pyramid` (roofs, with the visible slopes), `crenellate` (merlons that are thin blocks with two faces), `recess` (a door, window or slit set back into a face, with the near jamb showing), `arch_pts` (round or pointed openings), `bars` (a portcullis or grille inside an opening, clipped to what the opening shows). The geometry is in pure functions that return polygons, so it is tested without drawing.

**Mirroring.** A base is a mirror image (the view flips x), not a base turned around, as it is today. Both bases therefore show the face that looks toward the lane, and the composition stays symmetric. (Units are turned around, not reflected, because a soldier is handed; a building is not.)

**Constraints kept.**
- The footprint and gate position stay (units spawn at x = 0; turrets stand on `PADS` in front).
- Bases still render to a cached texture per race, age, team and camera (the key includes the yaw); the animated bits (lit windows, banners, fire) draw live on the same planes, windows on the recess's inner plane.
- A tower's turret still mounts at (0, −h): the top platform stays centred on x = 0.
- The camera is the units' `UnitArt.view_yaw`, so `--yaw=` on `base_gallery.gd` and the other tools moves everything together. At yaw 0 the volumes still read (bodies overlap in depth) and the end faces vanish.

## Pilot (built): the human medieval castle and stone tower

- **Castle.** A curtain wall 44 deep with a parapet of merlons; the keep set back behind it, its lower part hidden by the wall, with crenellations and a slate pyramid roof showing two slopes; a gatehouse projecting 10 in front of the wall with its own merlons, the arch a 30-deep recess with a portcullis inside; a round bastion at the left end, standing proud of the wall under a slate cone. Windows are recessed slits, lit at night on their inner plane.
- **Tower.** A square shaft with visible end face, a machicolation ledge, thick merlons, a recessed arrow slit, hoarding brackets, a hanging banner and ivy on the front.
- Checked square-on (yaw 0) and at night; tests cover the plane transforms, the end width (`depth · sin(yaw)`), the jamb width, the pyramid's visible slopes and the merlons.

## Rollout (not built)

1. **Humans:** the other five bases (hide camp, temple, Roman castrum, star fort, wizard citadel) and towers (lashed lookout, temple plinth, watchtower, earthwork bastion, arcane pylon).
2. **Elves:** grown structures, not masonry. The trunks are cylinders with root flares, the tree-halls timber bodies with real eaves, the canopies layered masses in depth; the towers woven and vine-bound columns (cylinders with spiral detail).
3. **Dwarves:** mountain holds as stacked rock slabs with side faces and a stone hall at the foot; iron-banded towers as boxes and cylinders with rivet lines.

Each step ends with a before and after gallery (`tools/base_gallery.gd`, with `--towers` and `--night=1`) for the owner to review; visual work cannot be verified in the cloud.

## Open questions for the owner

- How far to go on depth: this pilot puts the keep 50 px behind the wall front and the gatehouse 10 px in front. More depth reads more 3D but widens footprints and covers the first tower slot.
- Whether the towers should keep the ink outline (they do in the pilot; the bases have none).
