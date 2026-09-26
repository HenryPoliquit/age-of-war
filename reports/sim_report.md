# Balance sim report

**Result: FAIL (4/8 targets)** — 20 matches per pairing, seed 1, 320 matches total.

| Area | Metric | Target | Value | |
| --- | --- | --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% | 41% | ❌ |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min | 11:52 | ✅ |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 | 13:55 (57% of sides reach it) | ❌ |
| Balance | Each personality's aggregate win rate (Hard vs. Hard) | 40–60% | tactician 41%, rusher 50%, turtle 53%, economist 56% | ✅ |
| Balance | Any single personality pairing (first-named side's win rate) | 30–70% | tactician vs rusher 30%; tactician vs turtle 43%; tactician vs economist 50%; rusher vs turtle 35%; rusher vs economist 45%; turtle vs economist 38% | ✅ |
| Decisions | Fast-age vs. skill-heavy Tactician (fast-age win rate) | 40–60% | 57% | ✅ |
| Dominant units | Single-role spam vs. Tactician (Hard), spam win rate | < 30% each | vanguard 20%, ranged 43%, heavy 75%, siege 20% | ❌ |
| Worst-case defence | Turtle vs. Turtle | < 25% reach escalation; none > 18:00 | 50% escalate; longest 29:59 | ❌ |

## Match length distribution (round robin + mirror + fast/skill)

| Minutes | Matches |
| --- | --- |
| 4–6 | 19 |
| 6–8 | 16 |
| 8–10 | 30 |
| 10–12 | 47 |
| 12–14 | 14 |
| 14–16 | 7 |
| 16–18 | 12 |
| 18–20 | 13 |
| 20+ | 62 |

## Age arrival, Tactician mirror (median)

| Age | Median arrival | Sides reaching |
| --- | --- | --- |
| 2 | 2:10 | 100% |
| 3 | 3:59 | 98% |
| 4 | 6:33 | 93% |
| 5 | 9:08 | 73% |
| 6 | 13:55 | 57% |

## Where units die (share of gold lost, by distance from the dying unit's own gate)

| Lane | 0% | 8% | 16% | 25% | 33% | 41% | 50% | 58% | 66% | 75% | 83% | 91% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lost | 9% | 7% | 8% | 8% | 9% | 9% | 9% | 8% | 7% | 7% | 14% | 5% |

## Per-unit trade efficiency (all suites)

| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |
| --- | --- | --- | --- |
| arcane_heavy | 137 | 3.96 | 7.47 |
| arcane_ranged | 10534 | 5.86 | 4.36 |
| arcane_siege | 601 | 2.77 | 2.39 |
| arcane_vanguard | 16266 | 4.70 | 7.90 |
| bronze_heavy | 91 | 5.39 | 4.22 |
| bronze_ranged | 2803 | 3.75 | 2.78 |
| bronze_siege | 227 | 0.63 | 1.75 |
| bronze_vanguard | 5845 | 3.09 | 4.87 |
| gunpowder_heavy | 79 | 2.91 | 6.70 |
| gunpowder_ranged | 3306 | 5.60 | 3.72 |
| gunpowder_siege | 203 | 2.93 | 2.09 |
| gunpowder_vanguard | 5733 | 4.64 | 6.91 |
| iron_heavy | 72 | 5.25 | 4.59 |
| iron_ranged | 3713 | 4.09 | 3.06 |
| iron_siege | 161 | 3.63 | 1.63 |
| iron_vanguard | 7548 | 3.66 | 5.65 |
| medieval_heavy | 77 | 3.15 | 4.39 |
| medieval_ranged | 3216 | 4.76 | 3.46 |
| medieval_siege | 113 | 3.18 | 2.06 |
| medieval_vanguard | 7008 | 3.46 | 6.31 |
| stone_heavy | 636 | 3.32 | 4.20 |
| stone_ranged | 4632 | 3.20 | 2.51 |
| stone_vanguard | 9229 | 2.65 | 4.41 |
