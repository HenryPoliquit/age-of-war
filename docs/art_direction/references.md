# Art references per era

**Purpose:** pick a target look before producing more art, and collect references for each age.
**Status:** research notes (September 2026). Links come from web searches; a few sites (armorgames.com, gameart2d.com) couldn't be opened from the cloud session, so check every licence on the store page before buying or shipping anything.

## 1. What we're measuring against

| Game | What it does well | Lesson for Timefront |
| --- | --- | --- |
| **Age of War 2** (Max Games, 2012) | Seven ages, 29 unit types, "crisper art style" than the original; simple 2D sprites ([Max Games](https://www.maxgames.com/game/age-of-war-2.html), [Google Play](https://play.google.com/store/apps/details?id=com.maxgames.aow2&hl=en_US)) | The bar is *authored* sprites with personality per unit, not quantity of effects |
| **Incursion / Incursion 2: The Artifact** (booblyc, Armor Games) | Hand-drawn backgrounds with a moody, painted battlefield; cartoon units; compared to Kingdom Rush ([Armor Games community](https://armorgames.com/community/thread/11109950/incursion), [Incursion 2](https://armorgames.com/play/14978/incursion-2-the-artifact), [review](http://awesomerthanthou.blogspot.com/2014/07/game-reviews-incursion-2-artifact.html), [BoardGameGeek review](https://boardgamegeek.com/thread/1438039/a-browser-game-review-incursion-2-the-artifact)) | The "Incursion look" = hand-drawn vector cartoon units + painted, atmospheric backgrounds |
| **Kingdom Rush** (Ironhide) | Hand-drawn vector art, cel shading with only 3–4 tones per surface, no pure blacks, slightly muted/greyed palette, limited animation ([Ironhide forum on the style](https://forums.ironhidegames.com/viewtopic.php?f=5&t=158), [Wikipedia](https://en.wikipedia.org/wiki/Kingdom_Rush), [Juan Pais, Ironhide](https://juanpais.artstation.com/projects/q9NOee), [vector background art](https://www.artstation.com/artwork/ba5GrE)) | The most *producible* high-quality 2D style for a small team: flat tones, bold outlines, disciplined palette |
| **Valiant Hearts: The Great War** (Ubisoft, UbiArt) | Side-view, hand-drawn Euro-comic look (Hergé / Moebius): bold dark outlines, fine texture over simple painted colour, illustrated foreground-to-background layers; illustrators draw, animators rig with skeletons ([Wikipedia](https://en.wikipedia.org/wiki/Valiant_Hearts:_The_Great_War), [Ubisoft](https://news.ubisoft.com/en-us/article/50ITr78VlLHkrN1Nuc20XU/valiant-hearts-the-great-war-interactive-comic), [Steam](https://store.steampowered.com/app/260230/Valiant_Hearts_The_Great_War__Soldats_Inconnus__Memoires_de_la_Grande_Guerre/)) | Exactly our camera and pipeline (painted parts + skeleton), and the reference for the Industrial age |

## 2. Style direction: recommendation

**Target: "Incursion / Kingdom Rush" cel-shaded vector cartoon, with painted atmospheric backgrounds.**

- **Characters:** clean vector parts, 3–4 tones per material (light, base, shadow, deep shadow), a consistent dark-brown (not black) outline, slightly exaggerated proportions (big hands and weapons, readable heads). Role silhouettes as in `reports/unit_gallery.png`.
- **Backgrounds:** painted, moody, with atmospheric depth, as Incursion and Valiant Hearts do. Our sky and ground shaders and the split battlefield already point this way; they need authored painted layers instead of procedural shapes.
- **Palette discipline:** muted, slightly greyed colours (Kingdom Rush), with each age keeping the GDD §4.1 lighting, and team colour only on cloth and banners.
- **Why this one:** it's the style that reaches "better than Age of War 2" for the least art cost. It animates well as cut-out parts on bones (GDD §13.2 modular rigs), and it can be produced by one artist or bought as consistent packs.

**Rejected / secondary:**

- **Pixel art** (most free packs): cheap, but it reads as retro, not "better than Age of War". Mixing it with our painted backgrounds looks wrong.
- **Realistic painting:** too expensive at 24+ units, and the non-goal in PRD §4.
- **Pure procedural (current):** it has hit its ceiling. It's fine as a graybox and for effects, but figures drawn from code primitives can't reach hand-drawn quality.

## 3. Per-era references

Each age: art and game references, historical sources (public-domain first), the visual motifs that sell the age, and candidate ready-made assets.

### Age 1 — Stone
- **Art/game:** Kingdom Rush jungle and savanna levels for palette and foliage; Age of War 2's cave age for readability.
- **Historical (public domain):** Charles R. Knight's paleoart (d. 1953; pre-1931 works PD in the US), e.g. *Neanderthal Flintworkers* (1920) and *Cro-Magnon artists painting in Font-de-Gaume* ([Wikimedia category](https://commons.wikimedia.org/wiki/Category:Charles_R._Knight), [Neanderthal Flintworkers](https://commons.wikimedia.org/wiki/File:Neanderthal_Flintworkers_(Knight,_1920).jpg), [Wikipedia](https://en.wikipedia.org/wiki/Charles_R._Knight)); Font-de-Gaume cave paintings ([Don's Maps](https://donsmaps.com/fontdegaume.html)) for ochre/charcoal accents.
- **Motifs:** hides and furs, bone and antler, flint heads with visible knapping, ochre body paint, fire-lit dusk, mammoth or boar riders.
- **Assets:** *The Cavemen* by pzUH, cartoon vector, side-scroller, 2 heroes + 4 enemies animated ([itch.io](https://pzuh.itch.io/the-cavemen-game-sprites), [Construct](https://www.construct.net/en/game-assets/graphics/sprites/cavemen-game-sprites-1403)); *Prehistoric Age* ([GameArt2D](https://www.gameart2d.com/character-spritesheet-6.html)); *Tiny Caveman* ([Tokegameart](https://tokegameart.net/item/tiny-caveman/)).

### Age 2 — Bronze
- **Art/game:** **Apotheon** (Alientrap), a whole game in Greek black-figure vase style: vector figures animated like shadow puppets, limited palette, faded background layers for depth ([Wikipedia](https://en.wikipedia.org/wiki/Apotheon), [Game Developer](https://www.gamedeveloper.com/art/-em-apotheon-em-makes-ancient-art-work-in-a-modern-game), [Ancient World Magazine](https://www.ancientworldmagazine.com/reviews/apotheon-2015/)).
- **Historical (public domain):** Greek black-figure pottery ([Wikipedia](https://en.wikipedia.org/wiki/Black-figure_pottery)); The Met's Open Access collection, CC0, including an Arms and Armor theme ([Open Access](https://www.metmuseum.org/hubs/open-access), [announcement](https://www.metmuseum.org/perspectives/open-access-at-the-met)).
- **Motifs:** bronze Corinthian helms with crests, round aspis shields with painted emblems (team colour), linothorax, chariots with spoked wheels, whitewashed stone with meander friezes. Apotheon's vase-painting accents (meander borders, black-figure shields) would also make lovely HUD ornaments for this age.
- **Assets:** Spartan and Roman soldier sprites on [GameDev Market (Spartan)](https://www.gamedevmarket.net/asset/spartan-sprite) and [(Roman)](https://www.gamedevmarket.net/asset/roman-soldier-game-sprite-1835); free [RomanSoldiers side-scroller animation](https://squareant.itch.io/romansoldiers-2d-sideview-animation/purchase); [itch.io roman tag](https://itch.io/game-assets/tag-roman). Styles vary between these; check they match before mixing.

### Age 3 — Medieval
- **Art/game:** Kingdom Rush and Incursion 2 (forests, ruined forts, knights), the core style target.
- **Historical (public domain):** The Met Arms and Armor gallery (CC0) for plate, mail, helms and heraldry ([gallery photo on Commons](https://commons.wikimedia.org/wiki/File:Arms_and_Armor_gallery_371,_Metropolitan_Museum_of_Art_01.jpg)).
- **Motifs:** heraldic surcoats and caparisons (team colour), kettle hats and great helms, kite and heater shields, longbows, trebuchets, stone keeps with banners, overcast moorland.
- **Assets:** *The Knights* by pzUH, fantasy-medieval, side-scroller ([GameArt2D](https://www.gameart2d.com/the-knights---game-sprites1.html), [GraphicRiver](https://graphicriver.net/item/the-knights-game-sprites/22878171)); *Medieval Soldiers* by MtPixls, pixel art, includes a mounted soldier and archer, free for commercial use ([itch.io](https://mtpixls.itch.io/medieval-soldiers)); [2D side-scroller animated knight](https://buzpin.itch.io/side-scroller-2d-animated-character); [itch.io medieval side-scroller tag](https://itch.io/game-assets/tag-medieval/tag-side-scroller).

### Age 4 — Gunpowder
- **Art/game:** few side-view games live here, which is an opportunity. Use Incursion-style cel shading on 17th–18th-century uniforms; public-domain battle paintings for composition and smoke.
- **Motifs:** tricornes and morions, bandoliers, musket smoke banks drifting across the lane, star forts and bastions, mortars and field guns, storm-lit coasts, lighthouses.
- **Assets:** OpenGameArt side-scroll set with "Ye Oldy Musket Guy" and "Musketeer Officer & Cannon" (animated) ([OpenGameArt](https://opengameart.org/content/2dspritesidescroll)); *The Pirate* by pzUH, cartoon, same family as the other pzUH packs ([GameArt2D](https://www.gameart2d.com/pirate-game-sprites.html)); [free pirate characters](https://craftpix.net/freebies/free-2d-pirate-character-sprites/) and a [pirate pixel pack](https://craftpix.net/product/pirate-pixel-art-sprites-pack/) (CraftPix).

### Age 5 — Industrial
- **Art/game:** **Valiant Hearts** (side-view WW1, hand-drawn Euro-comic; the strongest single reference for this age); **Jakub Różalski's *1920+*** paintings (Scythe, Iron Harvest): 19th-century painting style with dieselpunk war machines in pastoral landscapes ([artist project: Iron Harvest](https://jrozalski.com/projects/8R3dQ), [Fields of Usonia](https://jrozalski.com/projects/aYerRk), [Culture.pl](https://culture.pl/en/article/painters-art-turns-into-video-game-with-dieselpunk-robots), [Ensemble interview](https://www.ensemble.art/blog/inside-the-art-of-1920-with-jakub-rozalski)). Use as mood reference only; the art itself is copyrighted.
- **Motifs:** Brodie helmets, greatcoats, trench boards, sandbags, barbed wire, armoured cars with riveted plates, smokestacks, sodium-orange dusk.
- **Assets:** [WW1 Soldiers pixel pack (GameDev Market)](https://www.gamedevmarket.net/asset/ww1-soldiers-2d-pixel-art-pack); [itch.io WW1 tag](https://itch.io/game-assets/tag-ww1); [WW1 trench assets (ArtStation Marketplace)](https://www.artstation.com/marketplace/p/03Ox/world-war-i-trench-assets); *The Soldier* by pzUH, cartoon, 22 animation states ([RenderHub](https://www.renderhub.com/pzuh/the-soldier-game-sprites)).

### Age 6 — Future
- **Art/game:** StarCraft II concept art for chunky, readable sci-fi silhouettes (Glenn Rane, Wei Wang, Peter Lee, Samwise Didier) ([Concept Art World](https://conceptartworld.com/news/starcraft-ii-concept-art/), [Brian Huang portraits](https://www.artstation.com/artwork/lDyb4z)); Into the Breach mechs for clean, iconic mech shapes ([example fan study](https://www.deviantart.com/shenky/art/Into-the-Breach-Mechs-953754448)); [future soldier concept (Stefan Celic)](https://www.artstation.com/artwork/W2BnL3).
- **Motifs:** visor helmets with emissive strips, energy shields, walker mechs with digitigrade legs, rail guns with charge coils, neon city at night, holographic signage.
- **Assets:** *Future Soldier* by pzUH, 4 characters ([itch.io](https://pzuh.itch.io/future-soldier-game-sprites)); *The Mechs* by pzUH, 5 mechs including walkers ([Construct](https://www.construct.net/en/game-assets/graphics/sprites/mechs-game-sprites-1010), [GameArt2D](https://www.gameart2d.com/the-mech-game-sprites.html)); [itch.io 2D mech sprites tag](https://itch.io/game-assets/tag-2d/tag-mechs/tag-sprites).

## 4. Getting the art: options

| Option | Cost | Consistency | Notes |
| --- | --- | --- | --- |
| **A. One asset family across ages** (e.g. pzUH/GameArt2D: Cavemen, Knights, Pirate, Soldier, Future Soldier, Mechs) | Low (tens of $ per pack) | Good within one artist's family | Covers Stone, Medieval, Gunpowder (pirate), Industrial-ish and Future; **no Bronze** pack found in the family. pzUH states an extended licence allowing commercial use ([GameArt2D sprites](https://www.gameart2d.com/sprites.html), [pzUH on itch.io](https://pzuh.itch.io/)); verify per pack. Best for prototyping the M2 slice quickly |
| **B. Mixed packs** (CraftPix, GameDev Market, itch.io) | Low | Poor: styles clash (pixel vs vector, different outline weights) | CraftPix allows commercial use in unlimited projects but not reselling raw files ([CraftPix](https://craftpix.net/)); fine for placeholders only |
| **C. Commissioned artist** for a style guide + Ages 1–2 (PRD M2) | Highest | Best; original IP, matches our rigs | Brief them with this document. The only route that fully satisfies PRD §11/§12 (original look, not an Age of War clone) |
| **D. AI-assisted parts + human cleanup** | Low–medium | Hard to keep consistent across 24+ units | PRD §11 already flags this: keep sources, and Steam requires AI-content disclosure |

**Suggested plan:** use **A** now to validate the look and feel in the M2 vertical slice (Stone + Bronze), with a stand-in for Bronze from GameDev Market re-coloured to match. In parallel, write a one-page style guide from section 2 and get quotes for **C**. Keep all our procedural effects, sky and ground shaders, lighting and the split battlefield; they sit well under authored sprites.

## 5. What changes in the engine

Nothing about Godot blocks this. The limit is authored art, not the platform: Godot's `Skeleton2D` + `Polygon2D` cut-out rigs (or Spine, PRD §10.1) are exactly how Valiant Hearts and Incursion-style games animate painted parts.

Swapping styles means:

1. Replace `UnitArt` code-drawn rigs with per-unit scenes: sprite parts on a `Skeleton2D` (or sprite-sheet animations for packs that ship frames).
2. Keep the sim → view contract: position, `state`, attack timing, flash.
3. Keep role silhouettes: re-run `tools/unit_gallery.gd` on the new art.
4. Replace `BaseArt` bases and `Scenery` shapes with painted layers per age; keep the seam shader.
