# GDD: Timefront — Game Design Document

**Working title:** Timefront
**Author:** Paul
**Status:** Draft v2
**Last updated:** 2026-09-25
**Companion document:** `PRD_Timefront.md` — goals, success metrics, scope, engine choice, development workflow. This document is the spec: how the game works, with starting numbers.

> **About the numbers.** Every value here is a *starting baseline* for the balance harness (§15), not a final answer. Values live in data files, not code, and are expected to move. What should not move without revisiting the PRD are the *systems* and the *acceptance targets*.

### What changed in v2

- **Economy rebuilt (§3–4).** v1 paired flat income with unit costs rising ×1.7 per age: armies shrank every age, and XP arrived far too slowly — a 12-minute match stalled around Age 3–4 and Age 6 took over an hour. Income now rises on a shared match-wide **tide**, bounty drops to 50%, and evolution costs are re-derived from an explicit pacing model (§4.3).
- **Front line simplified (§8).** It now has one reward, momentum. The +25% gold "Foothold" bonus is gone — two rewards for the same thing was redundant and snowballed.
- **Doctrines: two picks, not three (§9).** Age 6 arrives around minute 11, too late for a third pick to matter; it moves to post-v1.
- **Base HP scales ×1.7 per age** (was ×1.5), so a single late-game leak doesn't end a match in seconds.
- **Momentum from kills is flat per unit** (was per gold), so abilities don't come faster just because later units cost more.
- **New:** targeting rules (§5.6), sim-only AI archetypes (§11.3), post-match stats (§12.3), teaching battles (§12.2), animation blending and a VFX kit (§13), VFX presets (§16), match logs (§15.4).

---

## 1. Overview & Core Loop

Two bases, one lane, left vs. right. The player (left) and an AI opponent (right) each:

1. **Earn gold** from passive income, which rises for both sides as the match goes on (the tide), plus bounties for kills.
2. **Spend gold** to queue units, which walk down the lane and fight automatically, and to build turrets on the base.
3. **Earn experience (XP)** from kills and base damage.
4. **Spend XP** to evolve to the next age *or* to buy veterancy for the current age (§4).
5. **Push the front line** to build **momentum**, which fuels a targeted age ability (§7, §8).

A match is won by destroying the enemy base. Target: median 10–14 minutes, most matches ending in Age 5 or 6.

```
  Tide ──► Gold ──► Units & Turrets ──► Combat ──► XP ──► Evolve  or  Veterancy
              ▲                            │
              └───────── Bounties ◄────────┴──► Front line ──► Momentum ──► Age Ability
```

## 2. Match Structure & Win Conditions

- **Win:** reduce the enemy base to 0 HP.
- **Start:** both sides begin in Age 1 with 150 gold, 0 XP, 0 momentum, 2 turret slots (empty), base at 1,000 HP.
- **Escalation (anti-stalemate backstop):** from **15:00** — see §8.3. Matches cannot run indefinitely.
- **Speed control:** 1× / 2× / pause in single player.

## 3. Resources & Economy

### 3.1 Gold

| Source | Value |
| --- | --- |
| Passive income | 2 gold/s × current **tide multiplier** (§3.2) |
| Forge upgrades | +20% passive income per level, 3 levels. Cost 100 / 250 / 500 gold × your age cost multiplier (1.7^(age − 1)) |
| Kill bounty | 50% of the killed unit's gold cost |

The Forge is the economy-vs-army decision: gold into the Forge is gold not on the lane *now*. Because its cost scales with your age, it stays a decision at every stage rather than becoming an automatic late buy.

### 3.2 The Tide

Passive income rises for **both sides equally** on a fixed schedule, shown on the HUD as a tide marker. This is what lets later, more expensive armies stay full-sized, and it pushes every match toward a decisive late game.

| Tide level | Starts at | Multiplier |
| --- | --- | --- |
| 1 | 0:00 | ×1.0 |
| 2 | 2:15 | ×1.7 |
| 3 | 4:30 | ×2.9 |
| 4 | 6:45 | ×4.9 |
| 5 | 9:00 | ×8.4 |
| 6 | 11:15 | ×14.2 |

**Why the tide is tied to time, not to your age:** if income scaled with your own age, being one age ahead would mean better units *and* 1.7× the gold — evolving would snowball harder than it does in Age of War 2, the opposite of goal G3. With a shared tide, a side that stays behind in age has the same income and cheaper units, so the strong-age strategy (§4.4) stays viable.

### 3.3 Experience (XP)

| Source | Value |
| --- | --- |
| Killing a unit | 80% of that unit's gold cost |
| Damaging the enemy base | 1 XP per 10 damage |

XP is **spent**, not a threshold. It buys either evolution or veterancy (§4).

### 3.4 Momentum

A 0–100 meter per side, spent on the age ability (§7). Sources in §8.2.

## 4. Ages, Evolution & Pacing

### 4.1 The Six Ages

| # | Age | Palette & lighting | Lane backdrop |
| --- | --- | --- | --- |
| 1 | **Stone** | Warm dawn, long soft shadows | Savanna, rock outcrops, smoke from fires |
| 2 | **Bronze** | Bright midday sun, high contrast | Coastal cliffs, whitewashed ruins, sea haze |
| 3 | **Medieval** | Overcast, cool greens and greys | Highland moor, stone walls, banners in wind |
| 4 | **Gunpowder** | Stormy, lightning flashes | Rocky coast, gun smoke drifting across the lane |
| 5 | **Industrial** | Smog dusk, sodium-orange lamps | Trenches, rail lines, factory silhouettes |
| 6 | **Future** | Night, neon cyan and magenta rim light | Glass towers, holographic signage, drones |

### 4.2 Evolution Costs

| To age | XP cost |
| --- | --- |
| 2 Bronze | 300 |
| 3 Medieval | 650 |
| 4 Gunpowder | 1,200 |
| 5 Industrial | 2,050 |
| 6 Future | 3,750 |

### 4.3 Pacing Model

The costs above come from a simple model, written down so the balance sim can check it and so later changes don't silently break pacing.

**Assumptions (a balanced player, no veterancy):**

- Passive income ≈ **2.6 gold/s × tide multiplier**: 2 gold/s base with an average of 1.5 Forge levels (+30%) across the match.
- With a 50% bounty and ~85% of spending dying, total spend settles at income ÷ (1 − 0.5 × 0.85) ≈ **1.74× passive income** (each side's kills fund part of its next wave).
- XP ≈ 0.8 × 0.85 × 1.74 × 2.6 ≈ **3.1 XP/s × tide multiplier**, ignoring the small amount from base damage.

**Resulting timeline** (checked with a 1-second-step model):

| Event | Cumulative XP | Approx. time |
| --- | --- | --- |
| Age 2 | 300 | 1:40 |
| Age 3 | 950 | 4:00 |
| Age 4 | 2,150 | 6:25 |
| Age 5 | 4,200 | 8:50 |
| Age 6 | 7,950 | 11:20 |

**Sensitivity:** Age 6 arrival moves by about a minute for every ±25% change in the XP rate, so the Forge and bounty assumptions matter. Treat this table as the prediction the sim tests, not a fact.

Evolutions land roughly every 2–2.5 minutes, each age has time to be seen and played, and Age 6 arrives before the median match ends. A strong-age player who buys all three veterancy ranks in every age reaches Age 6 around 13:00 — still before escalation, but late enough that it aims to win in Age 5.

The sim's pacing target (PRD §6): median Age 6 arrival for a balanced AI between 10:00 and 12:00. If it drifts, adjust evolution costs first, the tide schedule second.

### 4.4 What Evolution Does

- **Base:** max HP ×1.7 per age (1,000 / 1,700 / 2,890 / 4,913 / 8,352 / 14,199); **current HP keeps its percentage**, so evolving is not a heal.
- **Units:** the new age's roster replaces the spawn menu. Units already on the lane stay in their old age and fight on.
- **Turrets:** existing turrets stay but do **not** upgrade. New turret types unlock. Old turrets get outclassed and should be sold (50% refund) and replaced — a deliberate gold sink and decision.
- **Transition:** 5 s. The spawn queue pauses; turrets keep firing; the base is vulnerable. Evolving under pressure is a gamble.
- **Doctrine pick:** evolving into Age 2 and Age 4 presents a doctrine choice (§9).

### 4.5 Veterancy (the alternative to evolving)

XP can instead buy **veterancy ranks** for the *current* age: each rank gives current-age lane units +10% HP and damage. **Veterancy never applies to turrets** — otherwise Turtle + veterancy + Bastion would stack into exactly the unbreakable defence this design exists to prevent. Three ranks per age, costing 15% / 20% / 25% of that age's next evolution cost. Ranks reset on evolving.

This is the core strategic tension Age of War 2 lacked: **fast-age** (evolve ASAP, accept a weaker army during transitions) vs. **strong-age** (bank veterancy, dominate the current age, evolve later from strength). The sim checks both win 40–60% against each other.

Why strong-age works: per gold, each age's units are about 12% more efficient than the previous age's (stats ×1.9 for cost ×1.7), while full veterancy is +30% — so a fully drilled army can beat a freshly evolved one at equal spend, until the evolved side drills too.

## 5. Units

### 5.1 Roles

| Role | Job | Armour | Damage type |
| --- | --- | --- | --- |
| **Vanguard** | Cheap melee frontliner that holds the line and screens ranged units | Light | Slash |
| **Ranged** | Damage from behind the Vanguard; fragile | Light | Pierce |
| **Heavy** | Expensive, armoured, slow; breaks enemy Heavies | Heavy | Blast |
| **Siege** *(Age 2+)* | Fragile, slow; bonus damage to bases and turrets; weak vs. units | Light | Siege |

Siege makes base damage a deliberate investment, not a side effect of whoever wins the midfield.

### 5.2 Damage × Armour Matrix

Shown in every unit tooltip. Unit-vs-unit multipliers stay within 0.5–1.5 so no role is hard-countered into uselessness — the dominant-unit problem in Age of War 2.

| Damage ↓ / Armour → | Light | Heavy | Structure |
| --- | --- | --- | --- |
| **Slash** | 1.0 | 0.7 | 0.5 |
| **Pierce** | 1.25 | 0.6 | 0.4 |
| **Blast** | 0.8 | 1.3 | 1.2 |
| **Siege** | 0.5 | 0.5 | 2.5 |

Reading it: Ranged shreds Vanguards and other Ranged but bounces off Heavies; Heavies beat Heavies and hold well against Ranged; Vanguards are the efficient generalist wall; Siege is for structures.

### 5.3 Roster (working names — original designs)

| Age | Vanguard | Ranged | Heavy | Siege |
| --- | --- | --- | --- | --- |
| Stone | Brawler | Slinger | Tusk Rider | — |
| Bronze | Hoplite | Javelineer | Chariot | Ram Crew |
| Medieval | Man-at-Arms | Longbowman | Knight | Trebuchet |
| Gunpowder | Halberdier | Musketeer | Cuirassier | Mortar Team |
| Industrial | Trench Raider | Rifleman | Armoured Car | Field Howitzer |
| Future | Aegis Trooper | Pulse Rifleman | Strider Mech | Rail Artillery |

### 5.4 Age 1 Baseline Stats

| Unit | Cost | Train time | HP | Damage | Attack interval | Range (px) | Speed (px/s) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Brawler | 15 | 1.0 s | 110 | 14 | 1.0 s | 30 (melee) | 70 |
| Slinger | 25 | 1.5 s | 60 | 10 | 1.2 s | 220 | 60 |
| Tusk Rider | 100 | 3.0 s | 420 | 30 | 1.6 s | 40 (melee) | 45 |

**Scaling per age:** cost ×1.7, HP and damage ×1.9, train time and speed unchanged. The tide scales income at the same ×1.7 step, so army size stays roughly constant across ages while each age hits harder.

**Siege baselines (Age 2):**

| Unit | Cost | HP | Damage | Attack interval | Range | Speed |
| --- | --- | --- | --- | --- | --- | --- |
| Ram Crew | 90 | 160 | 60 | 2.5 s | 30 (melee) | 40 |

From Age 3, Siege units are ranged (Trebuchet onward: range 380 px, minimum range 120 px) — see §5.6.

### 5.5 Spawning & Lane Rules

- **Spawn queue:** 5 slots; units train one at a time.
- **Field cap:** 30 units per side (performance and readability; §16).
- **Blocking:** units stop at the first enemy in range; allies queue behind without overlapping (slight vertical jitter so crowds read as crowds).

### 5.6 Targeting Rules

| Attacker | Rule |
| --- | --- |
| Vanguard, Ranged, Heavy | Attack the nearest enemy unit in range. If no enemy unit is in range and a structure is, attack the structure. Never walk past a living enemy unit. |
| Melee Siege (Ram Crew) | Walks toward structures; if blocked by an enemy unit, attacks it (at its poor multiplier) until the path clears. |
| Ranged Siege (Age 3+) | Fires **over** units at structures whenever a structure is in range; otherwise advances. Cannot hit anything inside its minimum range. Needs a Vanguard screen. |
| Sentry turret | Enemy unit closest to its own base. |
| Artillery turret | Densest enemy cluster in range; cannot hit units inside its minimum range (deliberate weakness vs. units at the gate). |
| Support turret | Aura only, no targeting. |

Ties break by unit ID, so sim runs are reproducible (§15.3).

## 6. Turrets

- **Slots:** 2 at start; slot 3 costs 150 gold, slot 4 costs 400 gold (both × your age cost multiplier).
- **Sell:** 50% refund, instant.
- **No auto-upgrade on evolution** (§4.4). Turret stats scale by age like units.

| Type | Unlocks | Damage type | Behaviour | Baseline |
| --- | --- | --- | --- | --- |
| **Sentry** | Age 1 | Pierce | Fast single-target, long range | Rock Thrower: 100 g, 18 dmg / 1.4 s, range 300 |
| **Artillery** | Age 2 | Blast | Slow, splash, minimum range | Stone Catapult: 180 g, 45 dmg / 3.0 s, splash 60 px, range 150–420 |
| **Support** | Age 3 | — | Aura near the base: slows enemies or grants allies armour | Tar Cauldron: 220 g, −30% enemy speed within 180 px |

## 7. Age Abilities

Each age has one **signature ability**, costing **100 momentum**, with a 45 s minimum cooldown. Unlike Age of War's untargeted specials, every ability is **aimed**: the player drags a ground marker along the lane.

| Age | Ability | Effect |
| --- | --- | --- |
| Stone | **Stampede** | A herd charges across a targeted 300 px section, knocking back and damaging enemies |
| Bronze | **Shieldwall** | Allies in a targeted zone gain +40% armour for 8 s |
| Medieval | **Arrow Storm** | Three volleys land in a targeted 250 px area over 3 s (Pierce) |
| Gunpowder | **Broadside** | Cannon fire walks across a 400 px strip (Blast) |
| Industrial | **Air Raid** | A bomber pass along a targeted line; heavy Blast, telegraphed shadow first |
| Future | **Orbital Lance** | A charged beam at one point after a 1.5 s telegraph; massive damage in a narrow column |

Ability damage scales by age like units. The AI gets the same abilities under the same rules and must also aim them.

## 8. Front Line, Momentum & Escalation

The central fix for Age of War 2's stalemates: something rewards pushing, the tide makes late armies strong enough to break defences, and a backstop forces an ending.

### 8.1 The Front Line

The **front** is the midpoint between the two sides' most-advanced units — regardless of stance, so units held at a rally line past midfield count. If one side has no units on the lane, the front is that side's base gate. If **neither** side has units on the lane, the front holds its last position until either side fields a unit. It is always visible as the seam where the two ages' backdrops meet (§13.6).

The lane is 2,400 px at 1080p (roughly 1.25 screens); the camera pans.

### 8.2 Momentum

| Source | Gain |
| --- | --- |
| Front line on the enemy's half | +2 per second |
| Killing an enemy unit | +1 Vanguard or Ranged, +2 Siege, +3 Heavy |
| Your base taking damage | +1 per 2% of your base's max HP lost |

Momentum caps at 100 and is spent entirely on the age ability. Values are flat per unit and per percentage, so ability frequency doesn't creep up in later ages. The pushing side earns it fastest; the losing side still gets a comeback ability eventually.

### 8.3 Escalation

From **15:00**, one stack is added every 30 s (max 4):

- Turrets deal −15% damage per stack (to −60%).
- Units deal +10% damage to structures per stack (to +40%). "Structures" means the base **and** turrets, as everywhere in this document — escalation is aimed squarely at turret walls.

Full escalation (4 stacks) is reached at 16:30. Announced on screen and in the music. The tide stays at level 6. PRD target: fewer than 10% of simulated matches reach escalation — it's a guarantee, not the normal ending.

## 9. Doctrines

On evolving into Age 2 and Age 4, the player picks one of two doctrines, kept for the rest of the match. The AI's doctrines are shown as banners on its base so the player can counter-plan.

| Pick | Option A | Option B |
| --- | --- | --- |
| Age 2 | **Horde** — units −20% cost, −15% HP | **Elite** — units +25% HP and damage, +30% cost |
| Age 4 | **Bastion** — turrets +25% damage, a 5th turret slot | **Siegecraft** — Siege units +50% structure damage, −25% cost |

Four combinations per match, against four AI personalities. A third pick at Age 6 (Blitz / Attrition) is a post-v1 candidate.

## 10. Player Controls & Unit Stances

| Action | Mouse | Keyboard |
| --- | --- | --- |
| Queue unit | Click unit card | 1 / 2 / 3 / 4 |
| Build / sell turret | Click slot | Q / W / E / R |
| Evolve / buy veterancy | Click age panel | T / V |
| Forge upgrade | Click Forge | F |
| Aim ability | Drag on lane, release to fire | Space, then click |
| Toggle stance | Click stance button | S |
| Pan camera | Edge-pan or right-drag | A / D |
| Speed | Buttons | F1 / F2 / F3 (1×, 2×, pause) |

**Stances:**

- **Advance** (default): units march to the enemy base.
- **Hold:** units stop at a rally line you place and wait for the group to build up. Releasing Hold sends them in together — the coordinated push that breaks a defended line.

## 11. AI Opponents

### 11.1 Rules

The AI plays by the same rules as the player: same costs, same tide, same queue, same field cap, same abilities it must aim. On **Easy, Normal and Hard it receives no resource bonuses**; difficulty comes from reaction speed, decision quality and counter-play. Only **Brutal** (+10% income) and **Nightmare** (+25% income) add bonuses — the fix for Age of War 2's difficulty spikes.

| Difficulty | Decision interval | Counter-play | Ability aim | Bonus |
| --- | --- | --- | --- | --- |
| Easy | 3.0 s | Ignores composition | Random within zone | — |
| Normal | 1.5 s | Reacts to your majority role | Largest cluster | — |
| Hard | 0.75 s | Full matrix-aware counters | Highest-value cluster, timed with pushes | — |
| Brutal | 0.5 s | As Hard | As Hard | +10% income |
| Nightmare | 0.5 s | As Hard, plus doctrine counters | As Hard | +25% income |

### 11.2 Personalities

| Personality | Plan |
| --- | --- |
| **Rusher** | Early aggression, Horde, fast-age, uses Hold to mass pushes |
| **Turtle** | Early turrets, Bastion, strong-age via veterancy, counter-attacks when you over-extend |
| **Economist** | Early Forge levels, Elite, big late-game waves |
| **Tactician** | Adapts to your composition and doctrines; the default balanced opponent |

### 11.3 Sim-Only Archetypes

Used by the balance harness, never shipped as opponents:

- **Fast-age Tactician:** always evolves the moment XP allows; never buys veterancy.
- **Strong-age Tactician:** buys all three veterancy ranks before evolving.
- **Spam bots:** queue only one role (one bot per role). Used for the dominant-unit check (PRD §6).

### 11.4 Implementation Approach

**Utility AI:** at each decision tick, score the candidate actions (queue each unit, build/sell a turret, evolve, veterancy, Forge, ability, stance change) with personality-weighted scoring over the lane state (front position, compositions, gold, XP, momentum, base HP, tide level), and pick the best. Weights live in data files; the same AI drives both sides in the sim.

## 12. Modes, Onboarding & Progression

### 12.1 Modes

- **Skirmish:** choose opponent personality, difficulty, and optionally starting age.
- **Chronicle (campaign):** ~18 handcrafted battles across the six ages, each with a modifier and a 1–3 star rating. Example modifiers: *start one age behind*; *no turrets*; *double income, half base HP*; *the enemy has already evolved*; *fog beyond the front line*.

### 12.2 Teaching Battles

The first five Chronicle battles each introduce exactly one layer, with a short prompt the first time it appears:

| Battle | Introduces |
| --- | --- |
| 1 | Queueing units; the damage × armour matrix via tooltips |
| 2 | Turrets, selling and replacing |
| 3 | Evolving (the enemy evolves first, so the player sees why) |
| 4 | The front line, momentum and the age ability |
| 5 | Veterancy vs. evolving, and the first doctrine pick |

### 12.3 Post-Match Screen

Win/lose banner, then: graphs over time of gold, army value, front-line position and age for both sides; markers for evolutions, abilities and doctrine picks; the three biggest trades (gold destroyed per engagement); Rematch / Change settings / Main menu. The same data is written to the match log (§15.4).

### 12.4 Progression

Light and non-power: Chronicle stars unlock cosmetic base banners. Skirmish is always fair; no stat grind.

## 13. Presentation

### 13.1 Art Direction

Hand-painted 2D, stylised proportions (slightly large heads and hands for readability at lane scale), strong silhouettes per role so a Heavy is identifiable by shape alone. Parts painted at 2× display resolution with soft, neutral lighting; normal maps and 2D lights supply the drama. Team colour via a tinted cloth/banner layer — **left side cool blue, right side warm orange**, chosen to stay distinguishable for common forms of colour blindness, with an alternate palette in settings.

### 13.2 Rigs (modular skeletons)

| Rig | Used by |
| --- | --- |
| Humanoid | All Vanguard and Ranged, Siege crews |
| Mounted | Tusk Rider, Knight, Cuirassier |
| Vehicle | Chariot, Armoured Car, siege engines (wheels, recoil, articulated parts) |
| Mech | Strider Mech, Future turrets |

A new unit is new painted parts on an existing rig plus shared animations.

### 13.3 Animation Spec

**Per unit:**

| Animation | Notes |
| --- | --- |
| Spawn | 0.4 s — steps out of the base gate with a dust puff |
| Idle | Loop, with secondary motion (cloth, hair, plumes) lagging behind the body |
| Walk | Loop; stride speed synced to movement speed so feet don't slide |
| Attack | Anticipation → contact → recovery. **Damage is applied on the contact keyframe event**, not on a timer, so hits land visually |
| Hit react | Short additive flinch layered over the current animation |
| Death | Two variants per rig, ending in a dissolve (Heavies and vehicles: explosion and debris) |

**Smoothness rules:**

- An animation state machine drives every unit; transitions blend over ~0.1 s (death transitions are immediate).
- Movement is code-driven; animation only follows it (no root motion), so the sim and the visuals agree.
- Keys authored at ~30 fps; skeletal interpolation plays them smoothly at display frame rate.
- Each unit passes the PRD §11 quality checklist before it counts as done.

### 13.4 VFX Kit

Effects are built per damage type, so the counter system is visible:

| Damage type | Hit effect layers |
| --- | --- |
| Slash | Weapon arc trail, spark or dust burst by armour material, small flash |
| Pierce | Projectile (arrow/javelin arcs; bullets get tracers), impact puff, brief flash |
| Blast | Flash, core explosion, debris, smoke, screen-space shockwave distortion, scorch decal that fades |
| Siege | Dust burst, structure chunks, heavy camera shake on the base |

**Game-feel rules:**

| Effect | Spec |
| --- | --- |
| Hit flash | Shader: sprite flashes toward white for 60 ms on taking damage |
| Hitstop | 40–60 ms micro-freeze on Heavy and Siege impacts only |
| Screen shake | Heavy impacts, abilities, base hits; short and capped; slider in settings |
| Lights | Muzzle flashes, explosions and abilities spawn short-lived 2D lights that shade nearby units |
| Glow | Emissive effects (muzzle flashes, Future-age energy weapons, ability beams) glow; confirm how 2D glow behaves in the chosen renderer during M2 |
| Knockback | Blast damage pushes units back a few pixels with a small hop |
| Telegraphs | Ground decal before every ability; Air Raid shows a moving shadow first |
| Damage numbers | Optional, off by default |

### 13.5 The Evolution Moment

Over the 5 s transition:

1. Time slows to 50% for 0.5 s.
2. A radial shockwave expands from your base.
3. Your half of the backdrop cross-fades into the new age with a painterly dissolve shader.
4. The base rebuilds: old structure dissolves out, new one assembles in.
5. The music crossfades to the new age's theme.
6. A banner shows the new age name and, at Age 2 and 4, opens the doctrine choice (the transition timer pauses while the player chooses; the AI chooses instantly).

### 13.6 The Split Battlefield (signature visual)

The backdrop behind each half of the lane shows **that side's current age**, blending across a soft seam **at the front line**. As the front moves, the seam moves. Who's ahead in time and who's winning the lane are both readable at a glance — and it's literally what the working title means. It needs only the per-age backdrop art the game needs anyway, plus one blend shader.

### 13.7 Camera

Smooth follow-pan with easing; brief, subtle zoom punch on ability impacts and evolution; never auto-moves while the player is dragging.

### 13.8 Audio

- **Music:** one theme per age, in stems. An intensity layer rises with lane pressure (units in combat, base under attack) and when escalation begins.
- **SFX:** grouped by damage type so counters are audible — Slash, Pierce, Blast and Siege sound distinct.
- **UI:** clear confirmation sounds for queueing, not-enough-gold, ability ready, and tide level-ups.

### 13.9 HUD

- Bottom bar: four unit cards (portrait, cost, role icon, hotkey), queue display.
- Top: both bases' HP bars, ages, doctrine banners, match timer, tide level (and escalation stacks once active).
- Right: gold, XP, momentum meter with ability button, evolve/veterancy panel, Forge.
- Tooltips show the damage × armour matrix row for the hovered unit.

## 14. Accessibility & Settings

Colour-blind team palette option; screen shake slider (0–100%); flash reduction toggle; damage numbers toggle; VFX preset (Low / Medium / High); key rebinding; UI scale; game speed control; separate music, SFX and UI volume sliders; pause at any time in single player.

## 15. Data & Balance

### 15.1 Data-Driven Content

Every unit, turret, ability, age, doctrine, tide level and AI personality is a **Godot Resource file** (`.tres`) under `data/` — plain text, diffable, editable without touching code. A script exports all of them to one CSV for spreadsheet review, and a validation script (run by Haiku in the workflow — PRD §10.2) checks every file against the schema.

### 15.2 Balance Simulation Harness

A headless Godot scene runs AI-vs-AI matches at maximum speed with no rendering:

- Runs *N* matches per personality pairing and difficulty, with randomised doctrine choices, plus the sim-only archetypes (§11.3).
- Reports: win rates by personality, doctrine and archetype; match-length distribution; Age 6 arrival times; share reaching escalation; spam-bot win rates; per-unit damage dealt and absorbed per gold.
- Exits non-zero if any acceptance target fails.

**Acceptance targets** (identical to PRD §6):

| Check | Target |
| --- | --- |
| Matches reaching escalation (15:00) | < 10% |
| Median match length, Tactician vs. Tactician | 10–14 min |
| Median Age 6 arrival, balanced AI | 10:00–12:00 |
| Each personality's aggregate win rate across all opponents (equal difficulty) | 40–60% |
| Any single personality pairing | 30–70% (designed counters allowed, hard counters not) |
| Any doctrine's win rate | 40–60% |
| Fast-age vs. strong-age Tactician | each wins 40–60% |
| Any spam bot vs. Tactician (Hard) | wins < 30% |
| Turtle vs. Turtle, both Bastion (worst-case defence mirror) | < 25% reach escalation; no match exceeds 18:00 |

This is the balance equivalent of a test suite: after any balance change, edit the `.tres` values, run the harness, read the report, iterate until green — with a human reviewing the diff and playing the result.

### 15.3 Determinism

Seeded random number generation and deterministic tie-breaking (§5.6), so any flagged match replays exactly — for debugging outliers and reproducing bug reports.

### 15.4 Match Logs

Every match — sim or real — writes a local JSON log: a timeline sampled every second (gold, XP, momentum, army value, front position, age, tide level) plus events (evolutions, doctrine picks, abilities, turret changes, base damage). The sim computes its report from these logs; the post-match screen draws from them; playtest logs are compared with sim logs (PRD §7).

## 16. Performance Budgets

| Budget | Target |
| --- | --- |
| Frame rate | 60 fps on both PRD §6 reference machines (High preset on the GTX 1060-class PC, Low on integrated graphics) |
| Units on field | Hard cap 30 per side |
| Pooling | Projectiles, particles, damage numbers, decals and hit sparks all pooled — no per-hit allocation |
| Animation LOD | Units in the middle of a dense crowd update bones at half rate |
| Particles | GPU particles on PC; CPU-particle fallback for web and mobile exports |
| Lights | Pooled short-lived lights with a per-frame cap; oldest culled first |
| VFX presets | Low halves particle counts and disables distortion and glow; Medium disables distortion; High is everything |

Profile against these budgets from M1 onwards with boxes, then again at the vertical slice with real rigs — skeletal animation is where this game's CPU goes.

## 17. Open Design Questions

- Is the front-line seam readable enough alone, or does it need a subtle marker (a flag, dust line)?
- Should escalation start by clock (15:00) or by condition (no base damage in the last 3 minutes)? Clock is simpler and predictable; condition is more targeted.
- Veterancy: flat +10% per rank, or role-specific bonuses (Ranged +range, Heavy +armour) for more texture?
- Is a fifth unit role per age (e.g. a support/medic unit) worth its art cost after the vertical slice?
- Should the tide schedule be visible as a countdown to the next level, or just as the current level?