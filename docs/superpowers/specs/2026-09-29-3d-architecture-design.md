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
- Tower heights (`BaseArt.TOWER_H`, revised 2026-09-30): about 1.35 times the infantry of the age for humans and elves, 1.5 for dwarves, so the turret stands above the units it protects.
- In the match (`WorldLayer._draw_base`) each tower and turret sets its transform with `FkPaint.begin`, never `draw_set_transform_matrix`: the 3D art composes its parts onto FkPaint's own transform, so a directly set canvas transform left the towers drawn at the base's origin (behind the gate) and their turrets hanging in the air (found by building turrets in the running game; `tests/test_view_paint.gd` guards it).
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

## Revisions after the owner's first review

- **Human Stone Age:** the hide tent on a rock became a stockade camp: a log palisade (pointed logs lashed with rails, skulls), a tall lashed gate with a horned skull, hide tents behind the wall, and a leaning-post watchtower with a ladder, a stake rim and a hide roof on a rock outcrop.
- **Human Bronze:** the colonnade is five columns re-spaced so the doorway stands clear (the sixth column used to stand in the door bay).
- **Dwarves (second pass, after "reference Lord of the Rings or Warcraft"):** the hold is a carved mountain fortress in the manner of Erebor, Moria and Ironforge. The mountain is a sheer craggy massif (ridges from the peak, jagged strata, scree, slabs stacked behind whose lane-facing sides show). From Bronze on, a masonry face is cut into it on a plinth: arched niches holding colossal dwarf kings (helm with a gilt crest, braided beard, upright axe), a monumental trapezoid gate under a heavy lintel with a gilt anvil-and-hammers emblem, the doors set inside a deep recess, braziers on the lintel, a chevron frieze, team banners hung between the kings, steps. Bronze has one king, a copper cap and plank doors; Iron adds the second king, a crenellated parapet, an upper tier with windows and iron doors; Medieval adds a gate tower and a corner tower with lit windows and forge smoke; Gunpowder adds chimney stacks and a gear housing; Arcane adds runes on the upper tier, the gate outlined in cold light and a floating rune stone. Stone Age stays the mine camp (timber-framed mine mouth, drystone wall, stone lookout cairn with a brazier, ore cart, anvil, rune stone).
- **Human and elf detail pass (after "improve the elves and human bases by enhancing details"):**
  - **Bronze temple:** a Greek-key frieze, a palmette and acroteria, antefixes along the raking cornices, scrolled capitals, bronze warriors on the podium, braziers on the steps, laurel over the doorway.
  - **Roman castrum:** quoins and tiled window frames on the gate towers, a cornice, a plaque over the gate, shield swags of laurel, a pila rack, barrels, a ballista on the walkway, tower pennants.
  - **Medieval castle:** buttresses, a timber hoarding with shuttered openings, machicolation corbels, hanging heraldic banners, a lowered drawbridge on chains, sconces, arrow slits over the gate, ivy, pennants.
  - **Star fort:** brick facing, a stone cordon and counterforts on the earth slope, sod and sandbags on the crest, gabions at the foot, sentry boxes and a chimney on the gun deck, a lowered drawbridge, powder barrels and a pyramid of shot.
  - **Wizard citadel:** a rose window, pinnacles over the buttresses, a second slim turret, a rune band along the foot (glowing live), two rings with orbiting orbs round the spire's tip, hanging banners, cold-fire sconces.
  - **Elves:** a hollow door in the trunk, mushrooms at the roots, fireflies drifting through the branches, hanging vines, lanterns and banners along the deck, a rope ladder, wicker huts (Bronze), a stair winding up the trunk and flower boxes and wind chimes on the hall (Iron on), a spiral stair and balcony on the white tower, a fluted silver spire, crystals among the roots (Arcane) and crystal shards circling the crown.

- **Medieval backdrop and Gunpowder base (after "castles on the medieval background are weird" and "do better on the gunpowder stage"):**
  - **Medieval backdrop:** the distant castles are gone. The land around the player's castle is countryside: strip fields on the hills (light and dark furrow bands), belts of round-headed woods, an abbey with a needle spire and a cloister range (no battlements), villages with churches, windmills, haystacks and flocks of sheep.
  - **Gunpowder base:** the earthwork mound with a small brick keep became an artillery fortress of red brick and limestone. The arsenal hall stands back under a slate mansard roof (slate courses, dormers, chimneys with smoke) with a clock cupola (live hands) and a verdigris onion dome; in front a brick rampart on a limestone plinth with a cordon, coping and broad merlons, iron guns on carriages in the gaps and two casemates below with muzzles showing; a drum bastion under a copper cone with a lit oculus; a rusticated baroque gatehouse with a pediment and gilt sun, team arms on a cartouche, round-headed windows, lanterns and a heavy-doored gateway with a lowered drawbridge on chains. The guns fire in turn (flash and drifting smoke, drawn live).
- **Elf bases as architecture, not a tree (after "their base doesn't really need to be a tree"):** the elf bases are rebuilt as buildings that improve over the ages, standing among trees (the world tree stays in the backdrop). Shared helpers: a swooping hip roof (`_elf_roof`: eaves curled up at the tips, shallow at the eave and steep to the ridge, shingle courses, gilt horns), timber framing, carved posts with leaf capitals, leaf-shaped windows, a broadleaf tree with a crown of blobs in depth, a woven dome hut.
  - **Stone:** a woodland camp: a turf-roofed wattle-and-daub longhouse with a smoke-hole cowl, a woven dome hut, a stake fence, a hearth ring, and a gate of two carved totem posts with fire bowls under an arch of bent saplings.
  - **Bronze:** a timber lodge on a drystone footing, plastered panels in dark posts, a swooping shingle roof with a louvre cupola, a porch with carved posts over a round-headed door, a spirit pole with a banner, birches.
  - **Iron:** a tiered timber hall: plinth and steps, a plank hall with carved posts and leaf windows, a second storey and a pavilion each under its own swooping roof, gilt spire, lanterns and banners under the eaves.
  - **Medieval:** a white-stone citadel: a pointed arcade under an upper storey of lancets and a leaf frieze, a copper-green swooping roof, a great pointed gate with gilt tracery and a rose window, a round tower with a cone at the left and two more behind, autumn trees and falling leaves.
  - **Gunpowder:** the same hall grown taller: a pale teal roof, slender silver leaf-blade spires with gilt bands joined by sky-bridges, in a misty wood.
  - **Arcane:** the same plan as crystal: glowing faceted towers, a glassy roof, a crown crystal floating over the central spire, shards circling, runes along the platform.
- **Stone Age towers:** the human lookout gains a stake rim, lashings, a skull and a team hide banner; the elf standing stone gains two small standing stones; the dwarf cairn sits on a drystone plinth with a rune slab.

All three races are converted. Not converted: the turrets themselves (`draw_turret`) stay flat.

Each step ends with a before and after gallery (`tools/base_gallery.gd`, with `--towers` and `--night=1`) for the owner to review; visual work cannot be verified in the cloud.

## Open questions for the owner

- How far to go on depth: this pilot puts the keep 50 px behind the wall front and the gatehouse 10 px in front. More depth reads more 3D but widens footprints and covers the first tower slot.
- Whether the towers should keep the ink outline (they do in the pilot; the bases have none).
