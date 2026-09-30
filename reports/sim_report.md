# Balance sim report

**Result: FAIL (2/8 targets)** — 20 matches per pairing, seed 1, 320 matches total.

| Area | Metric | Target | Value | |
| --- | --- | --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% | 43% | ❌ |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min | 14:21 | ❌ |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 | 13:30 (59% of sides reach it) | ❌ |
| Balance | Each personality's aggregate win rate (Hard vs. Hard) | 40–60% | tactician 47%, rusher 51%, turtle 42%, economist 61% | ❌ |
| Balance | Any single personality pairing (first-named side's win rate) | 30–70% | tactician vs rusher 55%; tactician vs turtle 53%; tactician vs economist 33%; rusher vs turtle 55%; rusher vs economist 53%; turtle vs economist 33% | ✅ |
| Decisions | Fast-age vs. skill-heavy Tactician (fast-age win rate) | 40–60% | 54% | ✅ |
| Dominant units | Single-role spam vs. Tactician (Hard), spam win rate | < 30% each | vanguard 30%, ranged 60%, heavy 45%, siege 15% | ❌ |
| Worst-case defence | Turtle vs. Turtle | < 25% reach escalation; none > 18:00 | 40% escalate; longest 29:59 | ❌ |

## Match length distribution (round robin + mirror + fast/skill)

| Minutes | Matches |
| --- | --- |
| 2–4 | 3 |
| 4–6 | 9 |
| 6–8 | 10 |
| 8–10 | 30 |
| 10–12 | 59 |
| 12–14 | 9 |
| 14–16 | 10 |
| 16–18 | 16 |
| 18–20 | 22 |
| 20+ | 52 |

## Age arrival, Tactician mirror (median)

| Age | Median arrival | Sides reaching |
| --- | --- | --- |
| 2 | 2:05 | 100% |
| 3 | 3:53 | 100% |
| 4 | 6:42 | 95% |
| 5 | 9:21 | 78% |
| 6 | 13:30 | 59% |

## Where units die (share of gold lost, by distance from the dying unit's own gate)

| Lane | 0% | 8% | 16% | 25% | 33% | 41% | 50% | 58% | 66% | 75% | 83% | 91% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lost | 10% | 8% | 8% | 8% | 8% | 8% | 8% | 7% | 7% | 6% | 16% | 5% |

## Per-unit trade efficiency (all suites)

| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |
| --- | --- | --- | --- |
| arcane_heavy | 40 | 3.25 | 7.79 |
| arcane_ranged | 10280 | 6.05 | 4.36 |
| arcane_siege | 443 | 3.07 | 2.30 |
| arcane_vanguard | 15341 | 4.72 | 7.94 |
| bronze_heavy | 92 | 5.42 | 4.27 |
| bronze_ranged | 2843 | 3.86 | 2.80 |
| bronze_siege | 265 | 0.43 | 1.75 |
| bronze_vanguard | 5587 | 3.04 | 4.88 |
| gunpowder_heavy | 87 | 2.45 | 6.67 |
| gunpowder_ranged | 3272 | 5.73 | 3.64 |
| gunpowder_siege | 237 | 3.63 | 1.99 |
| gunpowder_vanguard | 5425 | 4.53 | 6.75 |
| iron_heavy | 88 | 3.72 | 4.93 |
| iron_ranged | 3923 | 4.03 | 3.12 |
| iron_siege | 196 | 2.27 | 1.79 |
| iron_vanguard | 7868 | 3.61 | 5.70 |
| medieval_heavy | 127 | 2.56 | 5.86 |
| medieval_ranged | 3551 | 5.13 | 3.51 |
| medieval_siege | 133 | 3.15 | 2.12 |
| medieval_vanguard | 8340 | 3.60 | 6.33 |
| stone_heavy | 634 | 3.27 | 4.20 |
| stone_ranged | 4676 | 3.31 | 2.52 |
| stone_vanguard | 9186 | 2.57 | 4.40 |
