# Balance sim report

**Result: FAIL (3/8 targets)** — 20 matches per pairing, seed 1, 320 matches total.

| Area | Metric | Target | Value | |
| --- | --- | --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% | 46% | ❌ |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min | 11:52 | ✅ |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 | 13:55 (57% of sides reach it) | ❌ |
| Balance | Each personality's aggregate win rate (Hard vs. Hard) | 40–60% | tactician 43%, rusher 57%, turtle 42%, economist 59% | ✅ |
| Balance | Any single personality pairing (first-named side's win rate) | 30–70% | tactician vs rusher 30%; tactician vs turtle 48%; tactician vs economist 50%; rusher vs turtle 55%; rusher vs economist 45%; turtle vs economist 28% | ❌ |
| Decisions | Fast-age vs. skill-heavy Tactician (fast-age win rate) | 40–60% | 57% | ✅ |
| Dominant units | Single-role spam vs. Tactician (Hard), spam win rate | < 30% each | vanguard 20%, ranged 43%, heavy 75%, siege 20% | ❌ |
| Worst-case defence | Turtle vs. Turtle | < 25% reach escalation; none > 18:00 | 55% escalate; longest 29:59 | ❌ |

## Match length distribution (round robin + mirror + fast/skill)

| Minutes | Matches |
| --- | --- |
| 4–6 | 16 |
| 6–8 | 12 |
| 8–10 | 28 |
| 10–12 | 46 |
| 12–14 | 12 |
| 14–16 | 9 |
| 16–18 | 12 |
| 18–20 | 13 |
| 20+ | 72 |

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
| arcane_heavy | 134 | 3.93 | 7.42 |
| arcane_ranged | 11323 | 5.81 | 4.37 |
| arcane_siege | 656 | 2.97 | 2.41 |
| arcane_vanguard | 17611 | 4.78 | 7.88 |
| bronze_heavy | 91 | 5.39 | 4.22 |
| bronze_ranged | 2836 | 3.72 | 2.78 |
| bronze_siege | 229 | 0.63 | 1.74 |
| bronze_vanguard | 5889 | 3.04 | 4.86 |
| gunpowder_heavy | 94 | 3.01 | 6.67 |
| gunpowder_ranged | 3620 | 5.39 | 3.76 |
| gunpowder_siege | 209 | 3.23 | 2.10 |
| gunpowder_vanguard | 6309 | 4.56 | 6.98 |
| iron_heavy | 73 | 5.20 | 4.60 |
| iron_ranged | 3773 | 4.11 | 3.09 |
| iron_siege | 170 | 3.36 | 1.66 |
| iron_vanguard | 7636 | 3.61 | 5.65 |
| medieval_heavy | 77 | 3.15 | 4.39 |
| medieval_ranged | 3337 | 4.72 | 3.47 |
| medieval_siege | 116 | 2.79 | 2.09 |
| medieval_vanguard | 7085 | 3.59 | 6.31 |
| stone_heavy | 638 | 3.31 | 4.20 |
| stone_ranged | 4652 | 3.24 | 2.51 |
| stone_vanguard | 9190 | 2.63 | 4.39 |
