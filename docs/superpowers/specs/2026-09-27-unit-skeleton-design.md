# Unit skeleton and melee spacing: design

Date: 2026-09-27 · Branch: `art/readable-arms` · Status: awaiting owner review

## Why

Owner feedback after the readable-arms pass:
- "axes should have the pointed end on the correct direction"
- "There's still an issue with most units … key problems is how the limbs are positioned. I want you to take a skeleton approach. All feet should look at the same direction. Same with the arms and weapons."
- "my units should not touch the opponent too closely vice versa so that we maintain the illusion of the swing and hit"

What close-up renders show today (`scripts/view/art/unit_art.gd`):
- **Limbs have no skeleton.**
  - Every limb is placed by hand-tuned offsets: `sh + Vector2(..)`, `hip + Vector2(..)`.
  - Arm length changes from pose to pose, and the elbow flips side depending on where the hand is.
  - The shoulder sits inside the torso, so some poses read as a loop coming out of the neck.
- **Legs.**
  - The back leg folds oddly in some walk frames.
  - Riders have a single line for a leg and no foot.
  - Crews float their hands near the engine.
- **No body motion.**
  - The body never leans or steps into a strike.
  - Arms don't swing while walking.
- **Axe and halberd heads face backward.** The blade sits on the trailing side of the swing.
- **Units overlap in melee.**
  - Melee units press to `melee_contact = 8` px centre-to-centre (`match_sim.gd:540`).
  - A figure is about 20 px deep and a horse about 50 px, so opponents always overlap.

## Decisions (owner, 2026-09-27)

1. **Skeleton approach** for every humanoid figure: foot soldiers, riders, chariot drivers and siege crews.
2. **Spacing: "gap + same reach".** Opponents keep a visible gap, and the same number of ranks still fight, so balance should barely move.
3. **Review loop: batch per role.** For each role (all races × ages), I show a sheet of walk, wind-up and strike frames. The owner approves or flags units before I move to the next role.
4. **Reusable kit** (owner: "I want to reuse the units in other games"). Everything that draws a unit moves into a self-contained kit: figures, gear, race presets, mounts and machines. The game keeps only a thin adapter.

## 0. Figure kit (`addons/figure_kit/`)

**Rule:** the kit depends on nothing but Godot built-ins. It never references a game class (`UnitDef`, `GameData`, `RaceLook`, `MatchView`, …). A test enforces this by scanning the kit's source for every game `class_name`. To reuse it, copy the folder into another project.

All kit class names carry the `Fk` prefix, so they can't collide with another project's classes.

| File | Class | Contents |
|---|---|---|
| `paint.gd` | `FkPaint` | Canvas primitives used by everything, including this game's bases, towers and FX: `begin`, `push`/`pop`, `seg`, `limb`, `poly`, `shade_poly`, `ellipse`, `ellipse_pts`, `halo`, `wheel`, `shadow` |
| `skeleton.gd` | `FkSkeleton` | Pure math: joints, bone lengths, IK, locomotion and stance keyframes (§1) |
| `figure.gd` | `FkFigure` | Human figure: body, head, hair, beards, ears, drawn from the skeleton (§2) |
| `weapons.gd` | `FkWeapons` | Every hand weapon, grips and leading edges |
| `armour.gd` | `FkArmour` | Helmets, shields, packs, capes, tabards |
| `mounts.gd` | `FkMounts` | Horse/boar quadrupeds, seated riders, chariot |
| `machines.gd` | `FkMachines` | Ram, catapult, ballista, trebuchet, cannon, steam tank, golem, treant, sky cannon, obelisk, and their crews |
| `looks.gd` | `FkLooks` | Preset library: race bodies (human/elf/dwarf proportions, skin, hair, ears, beards, glow) and era palettes |
| `units.gd` | `FkUnits` | Entry point: `draw(ci, spec, pose)`, plus `height(spec)`, `muzzle(spec)`, `shot(spec)`, `wreck(spec)` |
| `README.md` | — | The spec and pose contract, and how to drop the kit into a project |

**Spec contract.** A figure is described by one Dictionary, `spec`. It uses today's style keys:
- `rig`, `helmet`, `weapon`, `shield`, `pack`, `cape`, `build`, `beast`, `crew`, `variant`, `car`, `shot`;
- plus explicit `look` (a race body preset), `palette` ([cloth, trim, metal]) and `team` (Color).

The static `_look` global goes away, because the race travels inside the spec. The pose Dictionary contract is unchanged: `walk`, `move`, `atk`, `t`, `flash`.

**What stays in the game:**
- `scripts/view/art/unit_art.gd` becomes the adapter. It maps `UnitDef` + race to a kit `spec` using the role fallback, role builds and `RaceLook.STYLES`. It keeps its public API (`style_for`, `draw_unit`, `height_for`, `muzzle_for`, `wreck_kind`, `RIGS`), so callers barely change.
- `RaceLook` keeps this game's unit → gear table (`STYLES`) and race ids. Its `BODY` and `CLOTH` move into `FkLooks`.
- `base_art`, `tower_art` and `fx_layer` switch from `UnitArt._shade_poly` and friends to `FkPaint`.

**Order of work:**
1. **Extraction first, with zero visual change.** The unit and base galleries rendered before and after the move must be pixel-identical (automated image diff).
2. **Spacing (§3).**
3. **Skeleton (§1–2)**, built inside the kit.

This way the refactor is proven not to change anything before the art starts changing.

## 1. Skeleton (`addons/figure_kit/skeleton.gd`, pure math)

It has no drawing, so it can be unit-tested headless.

**Joints:**
- hip, chest, neck, head
- near/far shoulder, elbow, hand
- near/far knee, ankle, toe

**Fixed bone lengths** (scaled by `build` and race `body`):

| Bone | Length |
|---|---|
| spine | 20 |
| thigh | 15 |
| shin | 14 |
| upper arm | 9 |
| forearm | 8.5 |

**Two-bone IK:** `ik(root, target, l1, l2, bend) -> joint`. A target out of reach is clamped to full extension.

**Invariants** (these are what the owner is asking for):
- Knees always bend **forward**. Elbows always bend **down/back**.
- Feet are always flat and point **toward the enemy (+x)**. The head always faces +x.
- Bone lengths never change between frames.

**Pose = locomotion + stance:**
- **Locomotion:**
  - comes from `walk` phase and `move` blend (existing pose dict);
  - sets foot targets on the ground line (stride plus lift), hip bob and a counter-swing of the free arm.
- **Stance:**
  - is chosen by weapon family and gives keyframes: guard → wind-up → strike → recover;
  - each keyframe sets the near-hand target, far-hand target, weapon angle, torso lean and front-foot lunge;
  - timing keeps the `swing()` beats (contact at 0.35–0.55), so the hit frame still matches the sim's damage tick.

**Weapon families** (each existing `weapon` kind maps to one):

| Family | Weapons | Hands |
|---|---|---|
| chop (1-hand) | club, sword, saber, gladius, axe, hammer, leafblade, spellsword, rune_hammer, baton, shovel | near hand on the grip; far hand on the shield, or counter-swings |
| thrust (polearm) | spear, lance, halberd, glaive | near hand drives; far hand on the shaft behind it (2-hand when no shield) |
| aim (gun/crossbow) | musket, rifle, arcane_rifle, rune_rifle, crossbow | both hands on the weapon, stock at the shoulder; recoil on shot |
| bow | bow, starbow | far hand on the bow held forward; near hand draws the string to the cheek |
| throw | javelin, throwing_axe, sling | overhead wind-up; release forward |
| staff | staff | two-hand thrust forward; the head flares |
| crew | crew | both hands IK'd to a grip point that each machine passes in |

**Weapon attachment:**
- Each weapon is drawn in the hand's frame, using the pose's weapon angle and a per-weapon grip offset.
- Bladed heads (axe, halberd, glaive, hammer face) declare a **leading edge**: the side facing the strike's direction of travel. That fixes the axe.

## 2. Renderer (`FkFigure`, rewritten on the skeleton)

- **Layer order is fixed:**
  1. far leg
  2. far arm (+ shield on the far arm, as in the readable-arms pass)
  3. torso
  4. near leg under the tunic hem
  5. head
  6. near arm
  7. weapon
- The torso, head and gear rotate with the lean about the hip.
- **Cosmetics keep their current look:** helmets, armour, tabards, packs, capes, beards, hair and race proportions. They are re-anchored to joints instead of the old `sh`/`hip` offsets.
- **Riders:**
  - seated pose: thigh along the saddle, shin down, foot in a stirrup pointing forward;
  - the mount's gait bobs the hip.
- **Crews:** stand beside the engine with both hands on the grip point that machine provides.
- **Out of scope:**
  - quadrupeds (horse, boar);
  - machines (catapult, cannon, …);
  - golem, treant and steam tank bodies.

  They have no human limbs. If a sheet shows a problem with them, it gets flagged separately.

## 3. Melee spacing (view only — revised 2026-09-27)

**Revision (owner decision, after harness evidence).** Keeping the gap *in the sim* moved balance no matter how reach was measured. At 60 matches per test:
- **Edge distances for all units:** Ranged spam 48% → 73%.
- **Edge distances for melee only:** Vanguard spam 22% → 50%, Siege spam 15% → 35%, Tactician mirror 11:25 → 15:45.

Moving fighters apart moves everything positioned relative to them. So the sim is unchanged: `melee_contact` stays 8 px centre to centre, and there are no footprints in data.

**The gap is presentation.**
- `FkUnits.depth(spec)`: body half-depth in local px, centre to front edge, weapon excluded. The values were measured from renders with weapons removed:

  | Rig | Depth (px) |
  |---|---|
  | humanoid | 10 (+8 with a shield) |
  | mounted, chariot, sky cannon | 50 |
  | cannon | 48 |
  | ballista | 46 |
  | ram | 45 |
  | steam tank | 43 |
  | obelisk | 36 |
  | catapult, trebuchet | 34 |
  | golem | 33 |
  | treant | 30 |

- `WorldLayer.drawn_x(def, side, sim_x)` draws each unit that far back toward its own base (× `UNIT_SCALE`). Two bodies the sim keeps 8 px apart centre to centre are then drawn with their fronts 8 px apart.
- Shot origins and targets, turret targets, splash flashes, HP bars and corpses all use the drawn x.
- **Cost:** a unit is drawn up to 62 world px behind its sim spot, so a skill-zone edge can look about one body off. Cavalry with short weapons (sabre) may swing short of an opposing horse. The skeleton pass (§1) adds a lunge on the strike.

## 4. Review tooling

`tools/unit_sheet.gd --role=vanguard --race=human` renders one sheet:
- rows are ages 1–6;
- columns are 4 walk phases, then wind-up, strike and recover;
- it renders into a 1920×1080 SubViewport, like the gallery.

Batches go in this order, each shown for all three races and then approved:
1. Vanguard
2. Ranged
3. Heavy (riders/chariot)
4. Siege crews

## 5. Testing

- **Kit boundary** (`tests/test_fk_boundary.gd`): no file under `addons/figure_kit/` names a game `class_name`.
- **Extraction:** the unit gallery (all 3 races, plus `--atk` frames) and the base gallery are pixel-identical before and after the move.
- **Skeleton** (`tests/test_fk_skeleton.gd`, headless):
  - bone lengths are constant across walk and attack frames;
  - the knee is in front of the hip-ankle line and the elbow is below/behind the shoulder-hand line;
  - toes are ahead of ankles;
  - out-of-reach targets clamp;
  - the strike hand is ahead of the guard hand for chop and thrust;
  - the axe's leading edge faces the swing direction at contact.
- **Presentation depth** (`tests/test_fk_units.gd::test_depth_per_rig`): per-rig depths as measured; +8 for shield bearers. (The original sim tests below were dropped with the sim approach.)
- ~~**Sim**~~ (`tests/test_combat.gd`, dropped):
  - two melee fronts stop with an 8 px gap between their edges;
  - cavalry against cavalry doesn't overlap;
  - the number of Vanguard ranks in reach of the enemy front is the same as before (4);
  - ranged units still hold at range.
- **Suite:** all existing tests stay green, and the data validator passes.
- **Visual:**
  - per-role sheets are approved by the owner;
  - the silhouette gallery is re-checked;
  - an in-game 1600×900 screenshot of a melee clash is taken. The owner reviews locally.

## 6. Motion pass (owner direction, 2026-09-27)

Owner, after watching every unit loop (the animation review page, `tools/unit_anim.gd` + `tools/anim_page.py`):
- "I want to make the arm move properly so that we actually have shoulder arm and hand movements. for the legs, we have leg knees and feet."
- "Slashing looks clunky."
- A written motion brief for each weapon type, summarised in the table below.
- "to make the game look realistic, let's aim all attacks on the area between head and chests."

### 6.1 New joints and pose channels (FkSkeleton)

**New keyframe channels**, alongside h (near hand), f (far hand), a (weapon angle), lean and lunge:

| Channel | Meaning |
|---|---|
| `s` | Shoulder offset (px). The shoulder rises, drops, drives forward or pulls back per pose instead of staying fixed. |
| `e` | Elbow bend direction. Replaces the single hard-coded down/back side, e.g. a high level elbow on a bow draw, or back-and-up at a 90° axe cock. |
| `ef` | Elbow bend direction for the far arm. |
| `w` | Wrist angle (rad): the hand's rotation relative to the forearm. The hand is drawn as an oriented fist, not a circle. The weapon angle `a` stays the absolute blade direction, so a wrist "snap" is `a` changing fast while the forearm moves slowly. |
| `crouch` | Hip drop (px) for a low, athletic centre of gravity. Knees bend more. |
| `step` | Passing step. The back foot swings through to land in front during the strike. |
| `path` | `"line"` or `"arc"` for how the near hand travels between keys. |

**Feet:**
- The foot becomes its own segment, rotating at the ankle: heel strike (toes up) as the front foot lands, flat while planted, toe-off (heel up) as the back foot leaves. Lunges and steps plant flat.
- Riders' heels press down in the stirrup.

**Shoulders:**
- A visible shoulder cap sits on the arm root (pauldron on armoured units), so shoulder motion reads.
- The far arm also moves: a shield brace, off-hand at the chest or ribs, reins, the bow brace, or a counter-swing while walking.

### 6.2 Attack target zone

Every attack lands between the opponent's head and chest:
- At contact (atk 0.35–0.55), blade tips, spear points and axe heads are at the target's head-to-chest band.
- Projectiles and impact sparks aim there too. In the view, the target point moves from mid-body (`height × 0.5`) to about 0.72 of the target's height, for unit shots and turret shots.

### 6.3 Motion per weapon family (keys: guard → wind-up → strike → recover)

| Family (weapons) | Owner's brief → poses |
|---|---|
| **Blade, one-handed** (sword, saber, gladius, spellsword, leafblade, baton, shovel, club) | **Wind-up:** hand chambered high beside the ear, blade angled back, low crouch. **Strike:** a passing step forward; the arm drives down in a steep straight (`line`) path; the wrist snaps flat so the blade is level at mid-height, meeting the opponent's head or chest. Off hand rests near the chest, or checks back at the ribs on the strike. Hips square: lean forward into impact. The smear trail follows the downward path. |
| **Axe / hammer, one-handed** (axe, hammer, rune_hammer) | **Wind-up:** square stance, no body twist, shoulders level (lean ≈ 0); arm cocked back beside the ear with the elbow at 90°. **Strike:** a vertical overhead chop (`arc`) coming down on the head or upper chest, edge leading. Off hand tucked against the chest. |
| **Bow** (bow, starbow) | Body side-on. The lead (far) arm extends rigidly toward the target as a brace, shoulder pressed low, and the bow stays locked on target throughout. **Draw:** the drawing hand pulls with a high, level elbow and anchors at the jaw under the eye. **Release:** fingers open; the drawing hand snaps back along the neck in follow-through. The arrow flies level at head/chest height. |
| **Javelin** (javelin, throwing_axe) | **Wind-up:** torso turned away, chest out; lead arm fully extended forward with fingers open; throwing arm straight back behind the shoulder, elbow high by the ear, spear raised; weight on the bent back leg (crouch, lunge back). **Release:** the arm whips forward at head height; weight moves to the front leg; the lead arm tucks. |
| **Sling** | **Guard (aim):** two-handed: lead hand holds the pouch forward, dominant hand back by the ear. **Wind-up:** overhead circular whip (cords spinning above the head), lead arm pointing downrange. **Release:** the dominant arm snaps forward at peak height; the lead arm tucks hard to the ribs; weight shifts back → front. The smear shows the two cords. |
| **Guns** (musket, rifle, arcane_rifle, rune_rifle, crossbow) | Aggressive forward lean, soft knees (crouch). Stock seated in the shoulder pocket, cheek on the comb, the barrel level at eye/head height. The support (far) hand cradles the fore-end with the elbow tucked beneath; the trigger hand sits at the grip. **Shot:** muzzle flash (existing FX), then a sharp straight rearward recoil through the shoulder (the gun and shoulder slide back and recover), with the head steady. |
| **Mounted, sabre** (seated + blade family) | Half-seat: the rider rises (the hip lifts off the saddle) and leans forward; heels down. Off hand holds the reins low over the withers. **Wind-up:** blade high and back. **Strike:** arm extends down and forward along the flank, wrist locked, curved blade in a draw-cut at the opponent's head or chest. Motion smear; dust puffs kick up at the hooves during the strike. |
| **Mounted, lance** (seated + thrust) | Half-seat and forward lean; the lance couched and levelled at the opponent's chest height on the strike. Reins in the off hand. |
| **Polearm on foot** (spear, halberd, glaive) | Unchanged in character (upright at guard, levelled thrust), but the point meets the chest band; crouch plus the new shoulder drive. |
| **Staff, crew** | Unchanged except for the new joints (shoulder, wrist, feet). |

**Out of scope:**
- Cloth simulation: the existing capes keep their flap.
- Real motion blur: smear trails stand in for it.
- The motion lives in the kit (`FkSkeleton` stances + `FkFigure`/`FkWeapons`/`FkMounts` drawing). The view change is only the aim height (§6.2). No sim or balance change.

### 6.4 Verification

- **Skeleton tests, per family:**
  - the shoulder moves between keys;
  - the elbow lies on each key's side;
  - the wrist angle follows the keys;
  - bow: the draw hand is at the jaw at full draw, and the lead arm is fully extended at every key;
  - blade: the wind-up hand is above the shoulder and beside the head, and the strike tip is in the target band;
  - axe: the elbow is ~90° at the wind-up;
  - the heel lifts on toe-off and the toes lift on heel strike;
  - no boot sole below the ground at any frame;
  - bone lengths are fixed.
- **Target band test:** for every melee family, the weapon's contact point at the strike key lies in the head-to-chest band of a same-size opponent standing at the view gap (§3).
- **Review:** the animation review page is republished at the same URL, and the owner reviews every unit there.

## Revision: the walk (owner, 2026-09-30: "walking isn't that smooth yet; units walk with their knees bent as if too heavy")

Measured first: the stance knee was flexed 43–81° through the whole stride (standing is 30°), because the hips were held at a fixed low height, so the legs were never straight. And the phase advanced faster than a foot could plant (the stance foot slid on the ground, 1.3× the body's speed for humans, stopping at either end of the stance).

- **Hips ride the legs.** `FkSkeleton.walk_hip_height()`: the hips stand as high as the legs on the ground allow (the lowest of what each leg needs, from its ankle's height and its distance ahead of the hip root), with the stance ankle kept at 0.995 of the leg's length (a pendulum) except for a 2% give as the weight comes on (loading). So the stance knee is nearly straight (about 11°) as the heel lands and as the body passes over the foot, flexes to about 25° just after landing, and bends as the heel lifts; the swing knee bends to about 50° to bring the foot through. The hips are highest passing over the foot (1–2 px higher than at landing), so the head bobs a little.
- **`arc` replaces `bob` in the gaits.** 1 = the full pendulum arc (default, heavy, bounce); the level gaits (archer, rifleman, shield wall, spear glide) take 0.7–0.9 of it and stay at about 25–35° of flex: the hips arc a little so the knee can straighten. A stance pose's crouch counts for 15% of its depth on the march (it kept the knees bent). Strides shortened a little (13 → 12.5, 12 → 11, 11 → 10.5).
- **Planted feet.** `foot_x()`: the foot on the ground slides back at a steady pace (a sine skated); the swing leaves and arrives at that same pace, reaching a little past its landing spot before settling. `stride_rate()` (through `FkUnits.stride_rate` and `UnitArt.stride_rate`) gives the phase per px of ground for the gait, the build, the race's legs and the drawn scale; `WorldLayer._pose` uses it, so a planted foot moves less than 0.3 px on the ground. Cadence follows the legs and size: about 2 steps a second for a human at walking speed, quicker for dwarves.
- **Tests:** the stance knee gets within 26° of straight and stays within 30° for half the stride, the swing knee bends to 40° or more, the hips rise passing over the foot, no leg overextends, a planted foot slides under 0.8 px; the archer's and shield wall's "level" limits are now 1.6 and 1.4 px. The 720-frame standing golden test is untouched (the change only applies while walking).
- **Review:** `tools/walk_sheet.gd` (eight phases of one stride for an age's vanguard, ranged and heavy unit).

## Revision: feet, hips and mounted riders (owner, 2026-09-30: the mounted weapon looks attached to the shoulder; the boots look odd with barely any ankle movement, people land mid-foot; balance the hips, knees and ankles; mounted units lean forward when they attack)

- **Mounted carry.** `ride_blade` and `ride_thrust` guard: the hand is held out in front of the hip and the weapon is tilted up and toward the enemy (46° and 54° above level), like the bow on the march, with a slight lean into the ride (0.06 rad). Before, the weapon stood up out of the shoulder.
- **Mounted lean.** The wind-up leans 0.14 (blade) and 0.18 (lance) and the strike 0.42 and 0.40 rad, so the rider comes forward into the blow. The seated golden snapshot (`tests/fk_golden.txt`) was re-taken for these two stances (only the seated blade, axe, spear and halberd rows changed).
- **The ankle cycle** (`FkSkeleton._ankle`, replacing the two brief heel/toe bumps, which left the foot rigid the rest of the time): the foot lands nearly flat, a mid-foot strike (a few degrees of toe-up, `heel`; the slinger still lands on the ball), lies flat for the first part of the stance, then the heel lifts steadily to `toe` as the body rolls over the ball of the foot. After push-off the toe stays pointed a moment, drops, then lifts (`clear`) to clear the ground before laying down for the landing. Smooth eases throughout, 20–30° of travel.
- **The lift** (`_swing_lift`): rises briskly as the toe leaves, peaks 40% through, sets down with no vertical speed. The ankle's height is the boot's lowest-point height plus what the foot is lifted beyond a flat foot, so the pitched foot and the lift hand over with no jump; the toe cap bends at the ball until the foot has risen 3 px (`TOE_LIFT`).
- **The swing path** leaves the stance at a gentle −0.6 (the old sine-based Hermite overshot backward after push-off, straightening the knee for a moment) and arrives at the stance's pace.
- **Hips.** `walk_hip_height`: one smooth swell per step (lowest as the heel lands, highest passing over the foot) sized to the lowest the legs' own limit ever allows (`_walk_need`, sampled once per gait and build), clamped to it. The knee's curve is the classic double hump: about 11° at landing, 25–30° in loading, straight again at mid-stance, flexing to about 50° at push-off, about 60° at the peak of the swing, extending for the landing. Between 32 samples of a stride no joint jumps (hips under 0.9 px, knee under 22°, ankle under 0.15 rad, foot height under 2.2 px).
- **The boot.** A shaft that stays with the shin, a separate foot with a heel, a flat sole, a ball, a rounded toe and toe box (`BOOT`, `BOOT_HEEL`, `BOOT_TOE`), and a cap over the ankle joint where they meet.
- **Review:** `tools/walk_sheet.gd --role= --phases= --atk=sweep` (a role's walk at any number of phases, or its attack sweep across the columns).


## Revision: golems, treants, mounts and taller towers (owner, 2026-09-30: "do the golems, treants and mounts as well; the towers need to be a bit taller than the units")

- **One walk cycle.** The gait functions (stride position, planted foot path, swing lift, ankle curve, toe bend, the highest hips the legs allow and the smooth hip swell) moved out of `FkSkeleton` into `FkGait` (`addons/figure_kit/gait.gd`, game-agnostic like the rest of the kit). Humans, golems and treants call the same functions with their own numbers; the hip-height cache is keyed by gait name as well as stride, so two gaits sharing a stride no longer share a curve (`test_each_gait_has_its_own_hip_curve`).
- **Giants.** `FkMachines.GIANT_GAITS` gives the golem and the treant a stride, lift, ankle angles, bone lengths, idle feet and standing hip height; `_giant_walk` places the hips, knees and ankles from them (`FkSkeleton.reach` and `ik`). The hips ride over nearly straight legs (the stance knee gets within 24° of straight, before it was bent all the time), the swing knee bends over 40°, the feet stay put on the ground (under 1.2 px of slide), the ankle pitches heel-strike to toe-off, and the iron foot bends at the ball (the treant's roots pitch and dip). Standing, the soles are on the ground (0.05 px) and the legs are under 30° of flex; the idle sway only lowers the hips, so a foot never floats. `FkUnits.stride_rate` gives the giants their cadence from their own stride and drawn size.
- **Mounts.** `FkQuadruped` walks the four-beat gait with a duty of 0.65 and the planted hoof sliding at the beast's pace; the hoof lands flat, stays flat until the breakover, then pitches up about its toe and folds in the swing (`pitch`, `pivot`; `FkMounts` draws the hoof as a polygon rotated about that pivot, the paw as a rotated ellipse). The back is a smooth curve (`_body_curve`: the highest the legs allow, dilated then averaged so it never asks a leg for more than it has) that glides instead of stepping; the forelegs straighten under the weight (under 22° of flex).
- **Towers.** `BaseArt.TOWER_H` raised to about 1.35 times the infantry of the age for humans and elves (83–105 px before `TOWER_SCALE`) and 1.5 for dwarves (70–80): a turret now looks down on the units it protects. The turret still mounts at the tower's top (`BaseArt.mount_pos`).
- **Tests:** `tests/test_fk_gait.gd` (foot path, ankle curve, swing lift, hip curve per gait, giants standing and walking, giants' cadence, hoof landing and pitch, the back's glide, the forelegs' straightening). `tests/fk_golden.txt` covers the humanoid skeleton only, so it is unchanged by this pass.
- **Review:** `tools/walk_sheet.gd --race=dwarf --age=6 --role=heavy` (golem), `--race=elf --age=6 --role=heavy` (treant), `--race=human --age=5` for the horsemen; `tools/base_gallery.gd --towers` for the towers. Owner reviews locally.

## Revision: the limp (owner, 2026-09-30: "one of their legs looks like it is limping")

- **Cause.** Measured by mirroring the far leg half a stride on against the near leg (`test_the_two_legs_step_alike_in_every_walk`): every gait was exact except the shield wall's, which differed by 8 px. The stance's `wide` (the fighting stance sets the near foot ahead of the far one) was also in the wall's march carry, so the near foot's stride was centred 4 px ahead of the hips and the far foot's 4 px behind, all through the stride. Shield-and-weapon units are most of the front line. With the legs no longer bent all the time it showed: one leg reached and one came up short.
- **Fix.** The walk takes none of the stance's fore-aft foot offsets (`wide`, and the near foot's `lunge`), scaled by `1 − move`; they still shape the standing guard and the attack. The wall gait no longer carries `wide`. The golems, treants and the beasts were already exact mirrors (measured).

## Revision: the sling and the projectiles (owner, 2026-09-30: "improve the sling mechanics, it does not look great; make the projectiles easy to see")

- **Sling** (`FkWeapons.sling_pose` / `_sling`). Before, a faint ring and a grey dot circled the hand on the clock (not the attack), and vanished. Now the pouch hangs from the near hand on two cords between the hands, and through the wind-up is whirled overhead in a circle in the plane of the throw (squeezed by the camera yaw, carried in `j.yaw`): it starts from hanging below the hand, makes 1.4 turns speeding up as `s^1.7`, with a blur behind the stone that lengthens with its speed. The stone is let go at 46% of the attack, in the middle of the forward whip, at the angle where it is travelling forward and up; the empty sling swings on over the top, hangs and wobbles, and the far hand takes it back (no jump at either end of the attack). Cords and pouch are dark-outlined so they read against any backdrop.
- **Release time.** `FkWeapons.RELEASE` / `FkUnits.release` give the fraction of the attack the shot leaves at (0.35 for everything but the slinger, as before); `MatchView` schedules the shot with it. The slinger's muzzle (`FkUnits.muzzle`) is worked out from the pose, so the stone leaves exactly where the whirling stone was, for every race and build.
- **Projectiles** (`FxLayer`). Every kind gets a dark outline (so it shows on a bright sky) and a light body, a fading streak behind it and a soft halo. Stone: 10 px across with a shaded, highlighted rock and a 46 px streak, a flash as it is let go. Arrows and javelins: 28 and 36 px long (were 16 and 22), lighter shaft, a bigger head, fletching in the shooter's colour (`col`, now set on every shot; bolts and orbs keep their magic colour). Axes: 1.5× the size with two ghost images. Balls and shells: bigger, with a pale rim so a black ball shows on dark ground. Bullets, tracers and bolts: a longer streak with a white core, and a hot head.
- **Tests:** `tests/test_fk_sling.gd` (release fractions; the pouch never jumps through the attack, starts and ends in the carried pose; the whirl speeds up to the release and lets go forward and up; the shot leaves from where the stone was, per race).
- **Review:** `tools/walk_sheet.gd --race=human --age=1 --role=ranged --atk=sweep --phases=10` for the sling; owner reviews locally.
