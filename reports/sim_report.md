# Balance sim report

**Result: FAIL (4/8 targets)** — 20 matches per pairing, seed 1, 320 matches total.

| Area | Metric | Target | Value | |
| --- | --- | --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% | 51% | ❌ |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min | 12:01 | ✅ |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 | 14:35 (55% of sides reach it) | ❌ |
| Balance | Each personality's aggregate win rate (Hard vs. Hard) | 40–60% | tactician 49%, rusher 56%, turtle 41%, economist 54% | ✅ |
| Balance | Any single personality pairing (first-named side's win rate) | 30–70% | tactician vs rusher 45%; tactician vs turtle 63%; tactician vs economist 40%; rusher vs turtle 50%; rusher vs economist 63%; turtle vs economist 35% | ✅ |
| Decisions | Fast-age vs. skill-heavy Tactician (fast-age win rate) | 40–60% | 53% | ✅ |
| Dominant units | Single-role spam vs. Tactician (Hard), spam win rate | < 30% each | vanguard 20%, ranged 73%, heavy 60%, siege 15% | ❌ |
| Worst-case defence | Turtle vs. Turtle | < 25% reach escalation; none > 18:00 | 50% escalate; longest 29:59 | ❌ |

## Match length distribution (round robin + mirror + fast/skill)

| Minutes | Matches |
| --- | --- |
| 2–4 | 4 |
| 4–6 | 8 |
| 6–8 | 5 |
| 8–10 | 23 |
| 10–12 | 48 |
| 12–14 | 18 |
| 14–16 | 3 |
| 16–18 | 11 |
| 18–20 | 7 |
| 20+ | 93 |

## Age arrival, Tactician mirror (median)

| Age | Median arrival | Sides reaching |
| --- | --- | --- |
| 2 | 1:51 | 99% |
| 3 | 4:03 | 98% |
| 4 | 6:57 | 91% |
| 5 | 9:45 | 71% |
| 6 | 14:35 | 55% |

## Where units die (share of gold lost, by distance from the dying unit's own gate)

| Lane | 0% | 8% | 16% | 25% | 33% | 41% | 50% | 58% | 66% | 75% | 83% | 91% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lost | 9% | 7% | 7% | 8% | 10% | 10% | 10% | 9% | 8% | 7% | 12% | 4% |

## Per-unit trade efficiency (all suites)

| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |
| --- | --- | --- | --- |
| arcane_heavy | 146 | 2.03 | 7.48 |
| arcane_ranged | 16669 | 5.65 | 4.61 |
| arcane_siege | 1009 | 2.68 | 2.56 |
| arcane_vanguard | 26587 | 4.20 | 8.45 |
| bronze_heavy | 94 | 4.70 | 3.98 |
| bronze_ranged | 3184 | 3.74 | 2.82 |
| bronze_siege | 301 | 0.39 | 1.76 |
| bronze_vanguard | 6144 | 3.01 | 4.86 |
| gunpowder_heavy | 91 | 2.26 | 6.59 |
| gunpowder_ranged | 4167 | 5.56 | 3.76 |
| gunpowder_siege | 301 | 3.32 | 2.11 |
| gunpowder_vanguard | 7138 | 4.36 | 6.92 |
| iron_heavy | 72 | 4.42 | 4.44 |
| iron_ranged | 4449 | 4.17 | 3.18 |
| iron_siege | 215 | 1.82 | 1.83 |
| iron_vanguard | 8496 | 3.64 | 5.72 |
| medieval_heavy | 107 | 2.10 | 5.45 |
| medieval_ranged | 4266 | 5.09 | 3.58 |
| medieval_siege | 126 | 4.38 | 2.19 |
| medieval_vanguard | 9768 | 3.39 | 6.40 |
| stone_heavy | 638 | 3.21 | 4.20 |
| stone_ranged | 4728 | 3.21 | 2.53 |
| stone_vanguard | 9231 | 2.54 | 4.39 |
