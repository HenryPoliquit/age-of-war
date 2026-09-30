# Balance sim report

**Result: FAIL (4/8 targets)** — 20 matches per pairing, seed 1, 320 matches total.

| Area | Metric | Target | Value | |
| --- | --- | --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% | 42% | ❌ |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min | 12:15 | ✅ |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 | 13:10 (62% of sides reach it) | ❌ |
| Balance | Each personality's aggregate win rate (Hard vs. Hard) | 40–60% | tactician 45%, rusher 51%, turtle 47%, economist 57% | ✅ |
| Balance | Any single personality pairing (first-named side's win rate) | 30–70% | tactician vs rusher 55%; tactician vs turtle 50%; tactician vs economist 30%; rusher vs turtle 53%; rusher vs economist 55%; turtle vs economist 43% | ✅ |
| Decisions | Fast-age vs. skill-heavy Tactician (fast-age win rate) | 40–60% | 48% | ✅ |
| Dominant units | Single-role spam vs. Tactician (Hard), spam win rate | < 30% each | vanguard 20%, ranged 60%, heavy 48%, siege 15% | ❌ |
| Worst-case defence | Turtle vs. Turtle | < 25% reach escalation; none > 18:00 | 40% escalate; longest 29:59 | ❌ |

## Match length distribution (round robin + mirror + fast/skill)

| Minutes | Matches |
| --- | --- |
| 2–4 | 3 |
| 4–6 | 9 |
| 6–8 | 12 |
| 8–10 | 23 |
| 10–12 | 64 |
| 12–14 | 12 |
| 14–16 | 6 |
| 16–18 | 9 |
| 18–20 | 11 |
| 20+ | 71 |

## Age arrival, Tactician mirror (median)

| Age | Median arrival | Sides reaching |
| --- | --- | --- |
| 2 | 2:05 | 100% |
| 3 | 3:53 | 100% |
| 4 | 6:39 | 95% |
| 5 | 9:22 | 74% |
| 6 | 13:10 | 62% |

## Where units die (share of gold lost, by distance from the dying unit's own gate)

| Lane | 0% | 8% | 16% | 25% | 33% | 41% | 50% | 58% | 66% | 75% | 83% | 91% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lost | 9% | 7% | 8% | 9% | 9% | 9% | 9% | 8% | 8% | 7% | 13% | 5% |

## Per-unit trade efficiency (all suites)

| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |
| --- | --- | --- | --- |
| arcane_heavy | 125 | 3.43 | 7.76 |
| arcane_ranged | 11963 | 5.87 | 4.37 |
| arcane_siege | 637 | 2.30 | 2.46 |
| arcane_vanguard | 18544 | 4.82 | 8.03 |
| bronze_heavy | 92 | 5.44 | 4.27 |
| bronze_ranged | 2844 | 3.86 | 2.80 |
| bronze_siege | 265 | 0.43 | 1.75 |
| bronze_vanguard | 5591 | 3.04 | 4.88 |
| gunpowder_heavy | 71 | 2.40 | 6.75 |
| gunpowder_ranged | 3403 | 5.71 | 3.62 |
| gunpowder_siege | 255 | 3.76 | 2.03 |
| gunpowder_vanguard | 5629 | 4.51 | 6.75 |
| iron_heavy | 87 | 3.59 | 4.90 |
| iron_ranged | 3886 | 4.21 | 3.12 |
| iron_siege | 183 | 2.33 | 1.77 |
| iron_vanguard | 7832 | 3.72 | 5.70 |
| medieval_heavy | 146 | 2.20 | 5.96 |
| medieval_ranged | 3556 | 5.12 | 3.51 |
| medieval_siege | 147 | 3.65 | 2.14 |
| medieval_vanguard | 8504 | 3.52 | 6.33 |
| stone_heavy | 634 | 3.27 | 4.20 |
| stone_ranged | 4676 | 3.31 | 2.52 |
| stone_vanguard | 9186 | 2.57 | 4.40 |
