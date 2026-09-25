# Balance sim report

**Result: FAIL** — 20 matches per pairing, seed 1, 300 matches total, 168 s.

| Area | Metric | Target | Value | |
| --- | --- | --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% | 33% | ❌ |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min | 14:00 | ❌ |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 | 12:01 (75% of sides reach it) | ❌ |
| Balance | Each personality's aggregate win rate (Hard vs. Hard) | 40–60% | tactician 65%, rusher 17%, turtle 40%, economist 78% | ❌ |
| Balance | Any single personality pairing (first-named side's win rate) | 30–70% | tactician vs rusher 75%; tactician vs turtle 70%; tactician vs economist 50%; rusher vs turtle 20%; rusher vs economist 5%; turtle vs economist 10% | ❌ |
| Balance | Win rate of each doctrine (Tactician mirror, random picks) | 40–60% | horde 25% (n=20), elite 79% (n=19), bastion 63% (n=16), siegecraft 41% (n=17) | ❌ |
| Decisions | Fast-age vs. strong-age Tactician (fast-age win rate) | 40–60% | 40% | ✅ |
| Dominant units | Single-role spam vs. Tactician (Hard), spam win rate | < 30% each | vanguard 30%, ranged 0%, heavy 50%, siege 15% | ❌ |
| Worst-case defence | Turtle vs. Turtle, both Bastion | < 25% reach escalation; none > 18:00 | 85% escalate; longest 27:45 | ❌ |

## Match length distribution (round robin + mirror + fast/strong)

| Minutes | Matches |
| --- | --- |
| 2–4 | 5 |
| 4–6 | 22 |
| 6–8 | 12 |
| 8–10 | 19 |
| 10–12 | 18 |
| 12–14 | 29 |
| 14–16 | 55 |
| 16–18 | 24 |
| 18–20 | 12 |
| 20+ | 4 |

## Age arrival, Tactician mirror (median)

| Age | Median arrival | Sides reaching |
| --- | --- | --- |
| 2 | 2:30 | 99% |
| 3 | 4:39 | 98% |
| 4 | 7:07 | 91% |
| 5 | 8:52 | 85% |
| 6 | 12:01 | 75% |

## Per-unit trade efficiency (all suites)

| Unit | Spawned | Damage dealt / gold | Damage absorbed / gold |
| --- | --- | --- | --- |
| aegis_trooper | 3829 | 4.29 | 7.79 |
| armoured_car | 520 | 4.66 | 7.35 |
| brawler | 5459 | 2.59 | 4.21 |
| chariot | 464 | 4.76 | 5.13 |
| cuirassier | 423 | 4.98 | 6.48 |
| field_howitzer | 478 | 3.19 | 3.08 |
| halberdier | 2609 | 3.22 | 6.04 |
| hoplite | 3123 | 2.56 | 4.69 |
| javelineer | 2558 | 5.01 | 2.91 |
| knight | 468 | 4.18 | 5.70 |
| longbowman | 2704 | 5.11 | 3.31 |
| man_at_arms | 3277 | 2.83 | 5.53 |
| mortar_team | 512 | 3.74 | 2.62 |
| musketeer | 2081 | 6.01 | 3.67 |
| pulse_rifleman | 3032 | 7.18 | 4.50 |
| rail_artillery | 802 | 4.18 | 2.44 |
| ram_crew | 594 | 0.75 | 1.87 |
| rifleman | 2546 | 6.41 | 4.18 |
| slinger | 4369 | 4.31 | 2.61 |
| strider_mech | 560 | 6.24 | 8.02 |
| trebuchet | 485 | 2.24 | 2.02 |
| trench_raider | 3019 | 3.56 | 7.05 |
| tusk_rider | 828 | 3.13 | 4.39 |
