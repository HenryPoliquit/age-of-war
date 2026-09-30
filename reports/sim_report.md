# Balance sim report

**Result: FAIL (2/8 targets)** — 20 matches per pairing, seed 1, 320 matches total.

| Area | Metric | Target | Value | |
| --- | --- | --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% | 46% | ❌ |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min | 13:25 | ✅ |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 | 12:50 (60% of sides reach it) | ❌ |
| Balance | Each personality's aggregate win rate (Hard vs. Hard) | 40–60% | tactician 38%, rusher 57%, turtle 39%, economist 66% | ❌ |
| Balance | Any single personality pairing (first-named side's win rate) | 30–70% | tactician vs rusher 15%; tactician vs turtle 65%; tactician vs economist 33%; rusher vs turtle 48%; rusher vs economist 40%; turtle vs economist 30% | ❌ |
| Decisions | Fast-age vs. skill-heavy Tactician (fast-age win rate) | 40–60% | 54% | ✅ |
| Dominant units | Single-role spam vs. Tactician (Hard), spam win rate | < 30% each | vanguard 20%, ranged 53%, heavy 60%, siege 20% | ❌ |
| Worst-case defence | Turtle vs. Turtle | < 25% reach escalation; none > 18:00 | 45% escalate; longest 29:59 | ❌ |

## Match length distribution (round robin + mirror + fast/skill)

| Minutes | Matches |
| --- | --- |
| 4–6 | 6 |
| 6–8 | 8 |
| 8–10 | 33 |
| 10–12 | 57 |
| 12–14 | 10 |
| 14–16 | 8 |
| 16–18 | 13 |
| 18–20 | 12 |
| 20+ | 73 |

## Age arrival, Tactician mirror (median)

| Age | Median arrival | Sides reaching |
| --- | --- | --- |
| 2 | 2:10 | 100% |
| 3 | 3:56 | 99% |
| 4 | 6:35 | 96% |
| 5 | 9:10 | 76% |
| 6 | 12:50 | 60% |

## Where units die (share of gold lost, by distance from the dying unit's own gate)

| Lane | 0% | 8% | 16% | 25% | 33% | 41% | 50% | 58% | 66% | 75% | 83% | 91% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lost | 9% | 7% | 8% | 8% | 9% | 8% | 8% | 8% | 8% | 7% | 14% | 5% |

## Per-unit trade efficiency (all suites)

| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |
| --- | --- | --- | --- |
| arcane_heavy | 75 | 2.99 | 7.40 |
| arcane_ranged | 12255 | 5.92 | 4.42 |
| arcane_siege | 636 | 2.35 | 2.39 |
| arcane_vanguard | 19376 | 4.78 | 8.00 |
| bronze_heavy | 94 | 4.63 | 4.48 |
| bronze_ranged | 2821 | 3.75 | 2.78 |
| bronze_siege | 251 | 0.46 | 1.77 |
| bronze_vanguard | 5627 | 3.14 | 4.88 |
| gunpowder_heavy | 74 | 2.51 | 6.42 |
| gunpowder_ranged | 3470 | 5.53 | 3.63 |
| gunpowder_siege | 237 | 3.08 | 2.02 |
| gunpowder_vanguard | 5832 | 4.51 | 6.80 |
| iron_heavy | 86 | 4.65 | 4.60 |
| iron_ranged | 4042 | 4.16 | 3.12 |
| iron_siege | 197 | 2.11 | 1.88 |
| iron_vanguard | 8288 | 3.63 | 5.73 |
| medieval_heavy | 99 | 2.98 | 4.91 |
| medieval_ranged | 3516 | 5.07 | 3.47 |
| medieval_siege | 121 | 3.98 | 2.14 |
| medieval_vanguard | 8156 | 3.57 | 6.32 |
| stone_heavy | 639 | 3.31 | 4.20 |
| stone_ranged | 4650 | 3.24 | 2.51 |
| stone_vanguard | 9180 | 2.63 | 4.39 |
