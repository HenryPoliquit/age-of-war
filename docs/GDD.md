# GDD: Timefront — Game Design Document

**Working title:** Timefront
**Author:** Paul
**Status:** Draft v3.1
**Last updated:** 2026-09-30
**Companion document:** `docs/PRD.md` — goals, success metrics, scope, engine choice, development workflow. This document is the spec: how the game works, with starting numbers.

> **About the numbers.** Every value here is a *starting baseline* for the balance harness (§15), not a final answer. Values live in data files, not code, and are expected to move. What should not move without revisiting the PRD are the *systems* and the *acceptance targets*.

### What changed in v3.1

From the owner's request to make skills more playable: every skill was auto-aimed, hit the same way, and several were hard to read on screen. Spec of the change is §7; the balance evidence is in `docs/balance_log.md` (B20+).

- **Aimed skills (§7, §10):** four of the six skills are aimed — click the Skill button or press Space, then click the lane (or the lane map). The two sweeps stay one-click. Space twice lets the game aim an aimed skill.
- **Two marks on the ground (§7):** a **circle** for the small targets (Rockfall, Starfall) and a **field of land** for the wide ones (Volley's arrow rain, Cannonade). The same mark is the aim reticle and, after firing, the warning, so you always see where a skill will land. The marks are part of the ground: drawn *under* the units (they stand on it), feathered, in the skill's own colour. The skills that run from your base to theirs (Stampede, Bombardment) put no mark on the ground.
- **Starfall hits units only (§7):** inside its circle a strike (a lance of light, a star, a lightning bolt, by race) lands on every enemy unit, six times, and nothing falls on empty ground: no blast zone, crater or shake.
- **Three damage rules (§7):** *flat* (armour and Defence apply, like a unit), *true* (ignores both) and *percent* (a share of each victim's max health, ignores both).
- **Readable skills (§13.4):** a countdown that fills the mark's outline, the skill's name (red and "ENEMY …" for the opponent's), a target count and markers while aiming, shots that land inside the mark exactly when the damage does, and damage numbers coloured by rule. Each race has its own look for every skill, with identical footprint, timing and damage (§5.7).
- **Simpler:** the *strip* shape is gone (Volley was the only one; it is an aimed field now) and so is Rockfall's slow. A sweep's herd moves at 1,200 px/s instead of 2,000, so a Stampede can be followed.
- **Fixes:** an area skill's zone is centred on the group it found, not pinned to its edge; a skill that would hit nothing fails without cost.

### What changed in v3

From the owner's first local playtest (spec: `docs/superpowers/specs/2026-09-26-simplify-systems-and-hud-design.md`). The game read as more complicated than Age of War without being more fun, so v3 cuts the systems players had to learn and keeps one decision per currency: **gold buys the army** (units, turrets, slots, upgrades), **XP buys progress** (evolving, the special skill).

- **Removed:** veterancy (§4.5), doctrines (§9), momentum (§8.2), Hold/Advance stances and the rally line (§10), the Forge button (now the Income upgrade, §6.1).
- **New — upgrades (§6.1):** gold buys Attack / Health / Defence for each unit slot, Attack / Health / Range for all turrets, and Income. Three levels each, kept for the whole match.
- **Skills (§7)** cost XP, fire with one click and aim themselves by shape (area, strip, sweep). Shieldwall is replaced by Rockfall.
- **Turrets (§6):** one free slot, three to unlock; every unit can attack turrets, Siege hardest.
- **HUD (§13.9):** slim top bar; units bottom-left, turret slots bottom-right, lane map and training queue between them; upgrades in a drop-down.

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
4. **Spend XP** to evolve to the next age *or* to fire the age's special skill (§4, §7).
5. **Spend gold on upgrades** (§6.1) to make a unit slot or your turrets stronger for the rest of the match.

A match is won by destroying the enemy base. Target: median 10–14 minutes, most matches ending in Age 5 or 6.

```
  Tide ──► Gold ──► Units, Turrets & Upgrades ──► Combat ──► XP ──► Evolve  or  Skill
              ▲                                      │
              └─────────────── Bounties ◄────────────┘
```

## 2. Match Structure & Win Conditions

- **Win:** reduce the enemy base to 0 HP.
- **Start:** both sides begin in Age 1 with 150 gold, 0 XP, 1 turret slot (empty), base at 1,000 HP.
- **Escalation (anti-stalemate backstop):** from **15:00** — see §8.3. Matches cannot run indefinitely.
- **Speed control:** 1× / 2× / pause in single player.

## 3. Resources & Economy

### 3.1 Gold

| Source | Value |
| --- | --- |
| Passive income | 2 gold/s × current **tide multiplier** (§3.2) |
| Income upgrade | +20% passive income per level, 3 levels. Cost 100 / 250 / 500 gold × your age cost multiplier (1.7^(age − 1)) (§6.1) |
| Kill bounty | 50% of the killed unit's gold cost |

The Income upgrade is the economy-vs-army decision: gold into Income is gold not on the lane *now*. Because its cost scales with your age, it stays a decision at every stage rather than becoming an automatic late buy.

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

XP is **spent**, not a threshold. It buys either evolution or the special skill (§4, §7).

### 3.4 Momentum (removed in v3)

The special skill is paid in XP (§7). The front line is still drawn (§8.1) but grants nothing.

## 4. Ages, Evolution & Pacing

### 4.1 The Six Ages

The ages run from the Stone Age to an **Arcane** finale of "steam and sorcery" — no modern or space
ages, so the fantasy races of §5.7 fit every age. Each race has its own backdrop per age (below);
stats, pacing and ability mechanics are the same for all races.

| # | Age | Humans | Elves | Dwarves |
| --- | --- | --- | --- | --- |
| 1 | **Stone** | Warm dawn savanna, mesas, fire smoke | Primeval glade at dawn, fireflies | Cold highland foothills, pines, cairns |
| 2 | **Bronze** | Bright coast, whitewashed ruins, gulls | Birch riverwood, standing stones, petals | Red-rock copper pass, carved guardians |
| 3 | **Iron** | Mediterranean hills, aqueducts, cypresses | Overcast deepwood, tree-halls, lanterns | Snowbound mountain gates, braziers, snowfall |
| 4 | **Medieval** | Overcast moor, castles, banners, drizzle | Golden autumn wood, white towers, falling leaves | Deep forges under a smoky dusk, ash |
| 5 | **Gunpowder** | Stormy coast, lightning, gun smoke | Misty moonlit wood, pale spires | Steam valley of chimneys and pipes |
| 6 | **Arcane** | Violet twilight, floating isles, wizard towers, airships | Starlit grove, glowing leaves, floating crystals | Rune halls under the stars, floating runestones |

### 4.2 Evolution Costs

| To age | XP cost |
| --- | --- |
| 2 Bronze | 300 |
| 3 Iron | 650 |
| 4 Medieval | 1,200 |
| 5 Gunpowder | 2,050 |
| 6 Arcane | 3,750 |

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
- **Upgrades carry over:** everything bought in §6.1 applies to the new age's units and turrets.

### 4.5 Veterancy (removed in v3)

Replaced by upgrades (§6.1), bought with gold. XP's alternative to evolving is now the special skill (§7): every skill fired pushes the next evolution back.

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

Units are data slots (`iron_vanguard`, …) with one stat line each; every race names and draws the
slot its own way (§5.7). Human names:

| Age | Vanguard | Ranged | Heavy | Siege |
| --- | --- | --- | --- | --- |
| Stone | Brawler | Slinger | Boar Rider | — |
| Bronze | Hoplite | Javelineer | Chariot | Ram Crew |
| Iron | Legionary | Auxilia Archer | Cataphract | Onager |
| Medieval | Man-at-Arms | Longbowman | Knight | Trebuchet |
| Gunpowder | Halberdier | Musketeer | Cuirassier | Great Cannon |
| Arcane | Spellblade | Arcane Rifleman | Steam Juggernaut | Sky Cannon |

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

### 5.7 Races

Players pick a **race** for each side: **Humans**, **Elves** or **Dwarves**. Races are cosmetic —
every race fields the same slots with the same stats, costs, abilities and turrets — so balance and
the AI never need per-race tuning. What changes: unit names and looks, the base, turrets, the
battlefield of every age (§4.1) and the flavour of each ability (§7).

| Age | Elves (V / R / H / S) | Dwarves (V / R / H / S) |
| --- | --- | --- |
| Stone | Thornblade / Hunter / Stag Rider / — | Hammerer / Stone Thrower / Ram Rider / — |
| Bronze | Grove Warden / Javelin Dancer / Elk Chariot / Rootbreaker | Shieldbearer / Axe Thrower / Goat Chariot / Battering Ram |
| Iron | Glade Guard / Longstrider / Elk Lancer / Bolt Engine | Ironbreaker / Crossbowman / Boar Knight / Stone Hurler |
| Medieval | Bladesinger / Ranger / Silver Knight / Great Ballista | Hearthguard / Arbalester / Bear Knight / Siege Bombard |
| Gunpowder | Sentinel / Starbow Archer / Wild Rider / Moonfire Catapult | Longbeard / Thunderer / Ironhorn Rider / Flame Cannon |
| Arcane | Moonblade / Arcanist / Treant / Starfall Obelisk | Runeguard / Rune Rifleman / Steam Golem / Rune Cannon |

Look: elves are tall and slender with pointed ears, long hair, leaf helms, recurved bows, stags and
elk; dwarves are short and broad with braided beards, round helms, axes, hammers, crossbows, rams and
bears; humans follow their history, from hides to legions to knights to arcane engineers. Each race
has a magic colour for its Arcane age (human violet, elven moon-blue, dwarven forge-orange).
Names live in `data/races/*.tres`; looks in `scripts/view/art/race_look.gd`.

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

- **Slots:** 1 free; slots 2, 3 and 4 cost 150 / 400 / 700 gold × your age cost multiplier. Maximum 4.
- **Every unit attacks turrets.** A unit with no enemy unit in range hits the nearest structure — turrets (lowest slot first), then the base — at its damage type's Structure multiplier (§5.2), so Siege stays the structure-breaker.
- **Sell:** 50% refund, instant.
- **No auto-upgrade on evolution** (§4.4). Turret stats scale by age like units.

| Type | Unlocks | Damage type | Behaviour | Baseline |
| --- | --- | --- | --- | --- |
| **Sentry** | Age 1 | Pierce | Fast single-target, long range | Rock Thrower: 100 g, 18 dmg / 1.4 s, range 300 |
| **Artillery** | Age 2 | Blast | Slow, splash, minimum range | Stone Catapult: 180 g, 45 dmg / 3.0 s, splash 60 px, range 150–420 |
| **Support** | Age 3 | — | Aura near the base: slows enemies or grants allies armour | Tar Cauldron: 220 g, −30% enemy speed within 180 px |

### 6.1 Upgrades

Bought with **gold**, **3 levels** each, **kept for the whole match** (they carry across evolutions) and applied **immediately** to units and turrets already on the field. Unit upgrades belong to a unit **slot** (Vanguard, Ranged, Heavy, Siege), so the next era's unit in that slot inherits them.

| Row | ⚔ | ♥ | Third |
| --- | --- | --- | --- |
| Each unit slot (4 rows) | Attack +15% / level | Health +15% / level | 🛡 Defence −10% damage taken / level |
| Turrets (all) | Attack +15% / level | Health +15% / level | ➶ Range +10% / level (Support auras too) |
| 💰 Income | +20% passive income / level | — | — |

**Costs:** level *n* of a unit row costs 0.6× / 1.0× / 1.5× the current price of that slot's unit; the turret row uses the average current-era turret cost; Income costs 100 / 250 / 500 × the age cost multiplier. Health upgrades keep the current HP percentage. The Siege row is unavailable until Siege exists (Age 2).

## 7. Special Skills

Each era has one **special skill**. It costs **XP** (so every use delays the next evolution) and has a **40 s cooldown**. Skills hit units only, never turrets or bases. Firing a skill whose zone holds no enemy unit fails and costs nothing.

The six skills differ in two ways: **how you aim them** and **how they hurt**.

### Aim

| Aim | How it works |
| --- | --- |
| **Auto** | One click on ☄ Skill (or Space) and it fires. The game picks the spot from the skill's shape: **area** — the densest enemy group (most enemy unit value within its width); **sweep** — travels from your gate to the enemy gate, one slice per pulse, hitting every enemy unit it passes |
| **Aimed** | Click ◎ Skill (or Space) to enter aim mode. A reticle follows the cursor — the skill's mark on the ground, a number for the enemy units inside it and a marker over each. **Left-click the lane** (or the **lane map**, on or off screen) to fire. **Space again** fires at the spot the game would pick (the densest group); **Esc**, a **right-click** (not a camera drag) or the button again cancels. A click that would hit nothing fails and keeps aiming. The game never pauses; aim mode ends by itself if the skill stops being available (XP spent, era changed, no enemy left). An aimed skill is an area of fixed width centred on the click |

The AI aims the same skills through the same command: at the densest group, off by up to 220 / 140 / 70 / 30 / 0 px on Easy / Normal / Hard / Brutal / Nightmare.

### The mark on the ground

| Mark | Skills | What it looks like |
| --- | --- | --- |
| **Circle** | Rockfall, Starfall (small: 250–260 px) | A ring on the ground whose outline brightens clockwise as the warning runs out. Rockfall's has dust turning round the rim and what falls lands inside it; Starfall's is a sigil (a second ring and a star turning inside it: eight points for the lance, five for the star, six for the rune) |
| **Field of land** | Volley, Cannonade (wide: 500–520 px) | A piece of land tinted in the skill's colour, with brackets painted at its corners; its back edge brightens as the countdown runs. Arrows or shells land anywhere across it, and shafts stay standing in it for a moment |
| **None** | Stampede, Bombardment | Sweeps run from your gate to theirs and need no marker; the herd or the barrage is the picture |

A mark is drawn *under* the units, as a soft shade with a thin light on it, in the skill's own (race) colour, fading in as the warning runs out. The opponent's is pushed toward red and labelled "ENEMY …", and pending marks also show on the lane map. The aim reticle is the same mark in gold (red when it would hit nothing), with a crosshair for a circle.

### Damage

| Rule | What it does | Good against |
| --- | --- | --- |
| **Flat** | Damage × the armour matrix (§5.2) × the target's Defence upgrades, like a unit's attack | Everything the matrix favours; weak against what the type bounces off |
| **True** | Fixed damage that ignores armour and Defence upgrades | Heavies and upgraded stacks that Pierce or Slash bounce off |
| **Percent** | A share of each victim's **max** health per pulse; ignores armour and Defence | Big units: it takes as much from a Heavy as its size deserves, and it scales by itself with every age and Health upgrade |

Balance caution (balance log B20): anything that blunts Heavy pushes without killing lengthens matches, so percent numbers must stay small.

A skill can also **shove** the units it hits back toward their base.

| Era | Skill | Aim | Shape | Damage (per unit hit) | XP (starting) |
| --- | --- | --- | --- | --- | --- |
| Stone | **Stampede** — a herd charges down the lane at 1,200 px/s | Auto | Sweep | Flat Slash 35, shoves back 60 px | 60 |
| Bronze | **Rockfall** — boulders crash inside a circle | **Aimed** | Circle, 260 px | Flat Blast 90 × 3 pulses | 75 |
| Iron | **Volley** — three waves of arrows rain on a field of land | **Aimed** | Field, 520 px | **True** 123 × 3 pulses (Pierce look) | 175 |
| Medieval | **Bombardment** — a walking barrage from gate to gate | Auto | Sweep | **Percent** 12% of max HP, shoves back 12 px | 275 |
| Gunpowder | **Cannonade** — signal flares mark a field, then heavy shells carpet it | **Aimed** | Field, 500 px | Flat Blast 912 × 5 pulses | 700 |
| Arcane | **Starfall** — after a 1.5 s warning, a strike lands on every enemy unit inside the circle, six times, 0.5 s apart | **Aimed** | Circle, 250 px | **Percent** 18% of max HP × 6 pulses | 1,000 |

A sweep's slices cross each unit once, so its damage is per unit, not per pulse. Every other shape hits a unit on every pulse it stands in.

### What you see

- **Warning.** While an aimed skill winds up, its mark stays on the ground (§ The mark on the ground) with the outline filling as the warning runs out and the skill's name and seconds left above it: in your colour for your skills, red with "ENEMY" for the opponent's. The lane map marks pending zones too, so a skill off-screen is never a surprise. Sweeps show no warning.
- **Starfall** (Arcane Lance, Thunder Rune) draws nothing on empty ground: each strike comes from the sim's hit on a unit and lands exactly where that unit stands, so a unit that walks in is struck and one that walks out is not. No crater, ring, scorch or shake. A dense pack gets at most 12 full strikes per pulse and a glint for the rest.
- **Landing.** Shots are launched early enough to land at the instant their pulse resolves, and inside the mark; incoming boulders and shells cast a growing shadow on the ground, arrows and thorns stay standing for a moment, and a light curtain falls over a volley's field. Cannonade plants three coloured signal flares in its field during the warning.
- **Numbers.** Every unit a skill hits shows what it took, coloured by rule: orange for flat, cyan with a diamond for true, green with a percent sign for percent; bigger when it kills. A setting turns them off.
- **Result.** When your skill finishes, a line reports it: "Rockfall: 4 hit, 1 killed", or "Rockfall: missed".

### Races

Each race names and dresses the same skill; footprint, timing and damage never change (§5.7).

| Skill | Human | Elf | Dwarf |
| --- | --- | --- | --- |
| Stone | **Stampede** — a herd of boars in road dust | **Wild Hunt** — stags trailing petals and light | **Ram Charge** — rams striking sparks |
| Bronze | **Rockfall** — quarried boulders, burning at the edges, from above | **Stone Rain** — mint crystal shards streaking in slantwise | **Boulder Toss** — rune-carved boulders lobbed from behind the lines |
| Iron | **Pilum Volley** — heavy javelins on the field | **Arrow Rain** — a swarm of glowing arrows | **Axe Storm** — spinning throwing axes |
| Medieval | **Trebuchet Barrage** — flaming stones lobbed from your walls | **Hail of Thorns** — briar spikes raining down | **Rockslide** — an avalanche of tumbling boulders |
| Gunpowder | **Cannonade** — iron round shot with smoke and a muzzle flash | **Moonfire** — silver orbs in pillars of moonlight | **Grand Cannonade** — rune-forged shells trailing furnace fire |
| Arcane | **Arcane Lance** — a spear of light through each unit | **Starfall** — a star dives onto each unit | **Thunder Rune** — a lightning bolt strikes each unit |

The AI uses the same skills under the same rules.

## 8. Front Line & Escalation

The central fix for Age of War 2's stalemates: the tide makes late armies strong enough to break defences, every unit can break turrets, and a backstop forces an ending.

### 8.1 The Front Line

The **front** is the midpoint between the two sides' most-advanced units. If one side has no units on the lane, the front is that side's base gate. If **neither** side has units on the lane, the front holds its last position until either side fields a unit. It is always visible as the seam where the two ages' backdrops meet (§13.6).

The lane is 2,400 px at 1080p (roughly 1.25 screens); the camera pans.

### 8.2 Momentum (removed in v3)

Skills are paid in XP (§7).

### 8.3 Escalation

From **15:00**, one stack is added every 30 s (max 4):

- Turrets deal −15% damage per stack (to −60%).
- Units deal +10% damage to structures per stack (to +40%). "Structures" means the base **and** turrets, as everywhere in this document — escalation is aimed squarely at turret walls.

Full escalation (4 stacks) is reached at 16:30. Announced on screen and in the music. The tide stays at level 6. PRD target: fewer than 10% of simulated matches reach escalation — it's a guarantee, not the normal ending.

## 9. Doctrines (removed in v3)

Cut after the first playtest: invisible modifiers that confused players and were the least balanced system in the simulations. AI personalities (§11.2) provide match variety. Doctrines may return as Chronicle battle modifiers.

## 10. Player Controls

| Action | Mouse | Keyboard |
| --- | --- | --- |
| Queue unit | Click unit card | 1 / 2 / 3 / 4 |
| Build / sell turret | Click slot (a list opens above it) | Q / W / E / R |
| Evolve | Click ▲ Evolve | T |
| Fire an auto skill | Click ☄ Skill | Space |
| Aim a skill | Click ◎ Skill, then click the lane or the lane map | Space, then click; Space again = let the game aim |
| Cancel aiming | Right-click (not a drag), click ✕ Cancel aim | Esc |
| Upgrades | ⬆ Upgrades opens the grid; click a cell | — |
| Pan camera | Edge-pan or right-drag | A / D |
| Speed / pause | 1×/2× toggle, ⏸ | Esc opens settings (pauses) |

Units always advance; there are no stances.

## 11. AI Opponents

### 11.1 Rules

The AI plays by the same rules as the player: same costs, same tide, same queue, same field cap, same skills. On **Easy, Normal and Hard it receives no resource bonuses**; difficulty comes from reaction speed, decision quality and counter-play. Only **Brutal** (+10% income) and **Nightmare** (+25% income) add bonuses — the fix for Age of War 2's difficulty spikes.

| Difficulty | Decision interval | Counter-play | Skill use | Bonus |
| --- | --- | --- | --- | --- |
| Easy | 3.0 s | Ignores composition | Any 2+ units | — |
| Normal | 1.5 s | Reacts to your majority role | Worthwhile group | — |
| Hard | 0.75 s | Full matrix-aware counters | Highest-value moments; never delays a planned evolution | — |
| Brutal | 0.5 s | As Hard | As Hard | +10% income |
| Nightmare | 0.5 s | As Hard | As Hard | +25% income |

### 11.2 Personalities

| Personality | Plan |
| --- | --- |
| **Rusher** | Early aggression, fast-age, few turrets, upgrades its Vanguards |
| **Turtle** | Early turrets and turret upgrades, counter-attacks when you over-extend |
| **Economist** | Early Income upgrades, big late-game waves |
| **Tactician** | Adapts to your composition; upgrades what it fields most; the default balanced opponent |

### 11.3 Sim-Only Archetypes

Used by the balance harness, never shipped as opponents:

- **Fast-age Tactician:** always evolves the moment XP allows; fires the skill only when it can't delay an evolution.
- **Skill-heavy Tactician:** fires the skill whenever it can hit anything.
- **Spam bots:** queue only one role (one bot per role). Used for the dominant-unit check (PRD §6).

### 11.4 Implementation Approach

**Utility AI:** at each decision tick, score the candidate actions (queue each unit, build/sell a turret, unlock a slot, evolve, fire the skill, buy an upgrade) with personality-weighted scoring over the lane state (front position, compositions, gold, XP, base HP, tide level), and pick the best. Weights live in data files; the same AI drives both sides in the sim.

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
| 4 | The special skill (XP) and the front line |
| 5 | Upgrades: more units or stronger units |

### 12.3 Post-Match Screen

Win/lose banner, then: graphs over time of gold, army value, front-line position and age for both sides; markers for evolutions, skills and upgrades; the three biggest trades (gold destroyed per engagement); Rematch / Change settings / Main menu. The same data is written to the match log (§15.4).

### 12.4 Progression

Light and non-power: Chronicle stars unlock cosmetic base banners. Skirmish is always fair; no stat grind.

## 13. Presentation

### 13.1 Art Direction

Hand-painted 2D, stylised proportions (slightly large heads and hands for readability at lane scale), strong silhouettes per role so a Heavy is identifiable by shape alone. Parts painted at 2× display resolution with soft, neutral lighting; normal maps and 2D lights supply the drama. Team colour via a tinted cloth/banner layer — **left side cool blue, right side warm orange**, chosen to stay distinguishable for common forms of colour blindness, with an alternate palette in settings.

### 13.2 Rigs (modular skeletons)

| Rig | Used by |
| --- | --- |
| Humanoid | All Vanguard and Ranged, Siege crews |
| Mounted | Heavy riders on boars, horses, stags, elk, rams and bears |
| Vehicle | Chariots, siege engines (ram, onager/catapult, ballista, trebuchet, cannon), Steam Juggernaut |
| Walker | Steam Golem, Treant |

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
| Glow | Emissive effects (muzzle flashes, Arcane-age magic weapons, ability beams) glow; confirm how 2D glow behaves in the chosen renderer during M2 |
| Knockback | Blast damage pushes units back a few pixels with a small hop |
| Telegraphs | A circle or a field of land on the ground, *under* the units, for every aimed skill: a soft shade with a thin light in the skill's colour that brightens as the warning runs out, with the skill's name (red and "ENEMY" for the opponent's); none for the base-to-base sweeps; Starfall also charges (a sigil, converging rings, a rising column, motes) and Cannonade plants signal flares |
| Damage numbers | Optional, off by default for units and turrets; skill numbers (coloured by damage rule, §7) are on by default and have their own toggle |

### 13.5 The Evolution Moment

Over the 5 s transition:

1. Time slows to 50% for 0.5 s.
2. A radial shockwave expands from your base.
3. Your half of the backdrop cross-fades into the new age with a painterly dissolve shader.
4. The base rebuilds: old structure dissolves out, new one assembles in.
5. The music crossfades to the new age's theme.
6. A banner shows the new age name.

### 13.6 The Split Battlefield (signature visual)

The backdrop behind each half of the lane shows **that side's current age**, blending across a soft seam **at the front line**. As the front moves, the seam moves. Who's ahead in time and who's winning the lane are both readable at a glance — and it's literally what the working title means. It needs only the per-age backdrop art the game needs anyway, plus one blend shader.

### 13.7 Camera

Smooth follow-pan with easing; brief, subtle zoom punch on ability impacts and evolution; never auto-moves while the player is dragging.

### 13.8 Audio

- **Music:** one theme per age, in stems. An intensity layer rises with lane pressure (units in combat, base under attack) and when escalation begins.
- **SFX:** grouped by damage type so counters are audible — Slash, Pierce, Blast and Siege sound distinct.
- **UI:** clear confirmation sounds for queueing, not-enough-gold, ability ready, and tide level-ups.

### 13.9 HUD

- **Top bar (slim):** left — XP, ▲ Evolve, ☄ Skill; centre — your era, elapsed time, enemy era; right — ⬆ Upgrades (drop-down grid), gold (+income/s), 1×/2× toggle, pause, settings.
- **Bottom left:** four unit cards (portrait, name, price, hotkey).
- **Bottom centre:** lane map (gates and a dot per unit); under it, the unit in training with its progress bar and the 5-slot queue.
- **Bottom right:** four turret slots (built, empty, locked with unlock price); clicking one opens the build list or a Sell option directly above it.
- **In the world:** a base HP bar above each base.
- Tooltips show the damage × armour matrix row for the hovered unit, and exact effects and prices for upgrades.

## 14. Accessibility & Settings

Colour-blind team palette option; screen shake slider (0–100%); flash reduction toggle; damage numbers toggle; VFX preset (Low / Medium / High); key rebinding; UI scale; game speed control; separate music, SFX and UI volume sliders; pause at any time in single player.

## 15. Data & Balance

### 15.1 Data-Driven Content

Every unit, turret, skill, age, tide level and AI personality is a **Godot Resource file** (`.tres`) under `data/` — plain text, diffable, editable without touching code. A script exports all of them to one CSV for spreadsheet review, and a validation script (run by Haiku in the workflow — PRD §10.2) checks every file against the schema.

### 15.2 Balance Simulation Harness

A headless Godot scene runs AI-vs-AI matches at maximum speed with no rendering:

- Runs *N* matches per personality pairing and difficulty, plus the sim-only archetypes (§11.3).
- Reports: win rates by personality and archetype; match-length distribution; Age 6 arrival times; share reaching escalation; spam-bot win rates; per-unit damage dealt and absorbed per gold.
- Exits non-zero if any acceptance target fails.

**Acceptance targets** (identical to PRD §6):

| Check | Target |
| --- | --- |
| Matches reaching escalation (15:00) | < 10% |
| Median match length, Tactician vs. Tactician | 10–14 min |
| Median Age 6 arrival, balanced AI | 10:00–12:00 |
| Each personality's aggregate win rate across all opponents (equal difficulty) | 40–60% |
| Any single personality pairing | 30–70% (designed counters allowed, hard counters not) |
| Fast-age vs. skill-heavy Tactician | each wins 40–60% |
| Any spam bot vs. Tactician (Hard) | wins < 30% |
| Turtle vs. Turtle (worst-case defence mirror) | < 25% reach escalation; no match exceeds 18:00 |

This is the balance equivalent of a test suite: after any balance change, edit the `.tres` values, run the harness, read the report, iterate until green — with a human reviewing the diff and playing the result.

### 15.3 Determinism

Seeded random number generation and deterministic tie-breaking (§5.6), so any flagged match replays exactly — for debugging outliers and reproducing bug reports.

### 15.4 Match Logs

Every match — sim or real — writes a local JSON log: a timeline sampled every second (gold, XP, army value, front position, age, tide level) plus events (evolutions, skills, upgrades, turret changes, base damage). The sim computes its report from these logs; the post-match screen draws from them; playtest logs are compared with sim logs (PRD §7).

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
- Upgrades: flat percentages per level, or role-specific bonuses (Ranged +range, Heavy +armour) for more texture?
- Is a fifth unit role per age (e.g. a support/medic unit) worth its art cost after the vertical slice?
- Should the tide schedule be visible as a countdown to the next level, or just as the current level?