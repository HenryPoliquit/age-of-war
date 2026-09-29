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

## Humans (built): the other five bases and towers

- **Bases.** Hide camp, temple, Roman castrum, star fort and wizard citadel are built from `Arch` volumes: boxes, prisms, frustums, cylinders and recesses, with the existing masonry, windows and banners drawn on their faces.
- **Towers.** Lashed lookout (tapered post prisms and a plank platform), temple plinth (stepped box base, fluted cylinder pilasters, gilt cornice), watchtower (tufa base with an arch recess, timber post boxes, tiled skirt), earthwork bastion (frustum of earth, brick cap, gabion boxes) and arcane pylon (tapered body, brass ring boxes, crystal on the front plane; the orbiting runestones stay flat).

## Elves (built): grown volumes

- **Bases.** The trunk is a solid of revolution (`Arch.lathe`) with a root flare, bark grooves and two root fins; the decks and hall are timber boxes wrapped round it, the hall under a hipped leaf roof with real eaves (an eave shadow on the wall); the canopy is layers of foliage at different depths (`Arch.blob`) that shift against each other as the camera turns; the gate is a bark-clad frame with a pointed doorway recessed into it; the white gate-tower is a masonry cylinder with a cone roof and two vines winding round it (`Arch.helix`); the silver spire is an extruded slab behind the trunk.
- **Towers.** Standing stone (a slab with thickness, a woven nest bowl with twigs), wicker cone with a leaf collar all the way round, three braided roots that really pass over and under each other (drawn in camera-depth order as mitred quads), fluted white column with a vine and a leaf balcony, moon-mushroom (stalk, ring, shelf fungi, domed cap with spots), hexagonal crystal pillar (`Arch.faceted`) with shards at its foot.

## Dwarves (built): stacked rock and iron-banded stone

- **Bases.** The mountain is one front with slabs stacked behind it whose lane-facing sides show (the higher, the shallower), so the right slope steps like strata; the cave mouth is a recess cut into it. The hold is a masonry hall built against the rock: a recessed door with the iron or plank leaves set inside, a lintel box, crenellations, a ledge; the two carved towers are boxes rising from the hall's roof with merlons and recessed windows (lit on their inner plane); the chimney and its brass bands are cylinders; the guardian face, gear housing and rune glyphs are drawn on the hall's front plane. The banner pole and the smoke follow the peak's depth.
- **Towers.** The cairn is rings of stones in depth under a capstone slab; the keep is a box on a battered plinth (a frustum) with a cornice, thick merlons and metal bands that wrap the body; the door is a recess; the steam stack is a cylinder; the rune tower's slit and doorway are recesses with the glow on their inner plane.
- Empty turret pads are a low box with two posts.

All three races are converted. Not converted: the turrets themselves (`draw_turret`) stay flat.

Each step ends with a before and after gallery (`tools/base_gallery.gd`, with `--towers` and `--night=1`) for the owner to review; visual work cannot be verified in the cloud.

## Open questions for the owner

- How far to go on depth: this pilot puts the keep 50 px behind the wall front and the gatehouse 10 px in front. More depth reads more 3D but widens footprints and covers the first tower slot.
- Whether the towers should keep the ink outline (they do in the pilot; the bases have none).
