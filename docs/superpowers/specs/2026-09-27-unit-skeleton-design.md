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

## 1. Skeleton (`scripts/view/art/skeleton.gd`, pure math)

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

## 2. Renderer (`humanoid()` rewritten on the skeleton)

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

## 3. Melee spacing (sim: `scripts/sim/`, data: `data/`)

- **New data stat:** `UnitDef.footprint`, in px. It is the half-depth from the unit's centre to its front edge, body only (not the weapon). Races are cosmetic and share one `UnitDef`, so each value is the largest across the three races' art.

  | Units | Footprint (px) |
  |---|---|
  | foot units | ~10 |
  | heavies (mounts, chariots, steam tank, golem, treant) | ~26 |
  | siege machines | ~22 |

  Final values come from measuring the gallery.
- **Unit-vs-unit distances become edge-to-edge.** Every unit-to-unit distance in the sim (targeting and the melee press-in limit) is `centre distance − attacker.footprint − target.footprint`.
- **`melee_contact` now means the visible gap between fronts.** It stays 8 px, and ranges stay unchanged.

  In edge terms, nothing about who can reach whom changes. Four ranks of Vanguards still attack, exactly as today, but the bodies now stand 8 px apart instead of overlapping. The strike pose reaches across that gap, so the swing still visibly "hits".
- **Structures:** a unit's own footprint is subtracted from its distance to the enemy gate, so it stops in front of the gate rather than inside it.
- **Allied stacking (`unit_spacing`) is unchanged.**
- **Balance:**
  - Ranged units now measure to the enemy's front edge, so they fire slightly sooner.
  - Run the harness before and after.
  - Record the change in `docs/balance_log.md` and attach `reports/sim_report.md`, per project rules.

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

- **Skeleton** (`tests/test_skeleton.gd`, headless):
  - bone lengths are constant across walk and attack frames;
  - the knee is in front of the hip-ankle line and the elbow is below/behind the shoulder-hand line;
  - toes are ahead of ankles;
  - out-of-reach targets clamp;
  - the strike hand is ahead of the guard hand for chop and thrust;
  - the axe's leading edge faces the swing direction at contact.
- **Sim** (`tests/test_combat.gd`):
  - two melee fronts stop with an 8 px gap between their edges;
  - cavalry against cavalry doesn't overlap;
  - the number of Vanguard ranks in reach of the enemy front is the same as before (4);
  - ranged units still hold at range.
- **Suite:** all existing tests stay green, and the data validator passes.
- **Visual:**
  - per-role sheets are approved by the owner;
  - the silhouette gallery is re-checked;
  - an in-game 1600×900 screenshot of a melee clash is taken. The owner reviews locally.
