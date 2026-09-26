# Balance log

Every change from the GDD baselines, and why. Harness numbers are from `run_sim.gd` at the sample size noted. Small samples are noisy.

| # | Change | Evidence |
| --- | --- | --- |
| B1 | `unit_spacing` 12 → 6 px | With 12 px, only the front melee unit could reach its target; late bases took minutes to break |
| B2 | Evolution costs 300/650/1,200/2,050/3,750 → **240/300/700/1,100/2,800** (veterancy bases follow) | Re-derived from the measured XP-earned curve, as GDD §4.3 prescribes ("adjust evolution costs first"). Measured cumulative XP at 1:40 / 4:00 / 6:25 / 8:50 / 11:20 was 244 / 436 / 1,264 / 2,346 / 5,140, well below the GDD model's early and mid game (the model assumes 1.5 Forge levels from 0:00). Result at n=20: median Age 6 at 12:01 (target 10:00–12:00; 75% of sides reach it before the match ends). Age 3 is now cheaper than the GDD curve implies, because the mid-game XP rate is lowest. Revisit when the economy changes |
| B3 | Vanguard line: cost ×4/3, HP ×0.73, damage ×0.64 (Brawler 15 g/110/14 → 20 g/80/9). Ranged damage ×1.2 (Slinger 10 → 12) | GDD baselines gave Brawler ~7× the Lanchester value (HP × DPS ÷ cost²) of Slinger or Tusk Rider; Vanguard spam beat the Hard Tactician 92% |
| B4 | Melee units press in to 8 px contact while fighting (sim rule, PLAN D5) | Units stopped at max range, so the next ally was always out of reach: fights were 1-v-1 at the front, single big units dominated, and at most one melee unit could hit a base |
| B5 | Heavy line: HP back to GDD baseline (after a temporary +24%), damage ×1.2 × 0.85 ≈ ×1.02, cost unchanged | Heavy spam beat the Tactician 100% while Heavies were buffed; 50% at n=20 after B4–B9. Open |
| B6 | Vanguard damage ×1.25 (Brawler 9 → 11.2) | After B3 Vanguards were the weakest dealers per gold in every age |
| B7 | All turret damage ×0.6 | Armies are small (2–10 units); two same-age turrets erased any push at the gate. Stalemate share 54% → 38% |
| B8 | Horde: −20% cost, **−15% HP, −10% damage** (GDD: −15% HP only). Elite: **+25% HP, +20% damage, +20% cost** (GDD: +25%/+25%/+30%) | GDD values: Horde ≈ +33% value per gold, Elite ≈ −8%. Horde won 10/10. After the change: 50/50 at n=8, but the result flips with small unrelated changes (0↔100%). Mirrors amplify any edge. At n=20: Horde 25%, Elite 79%, so Elite is now slightly ahead. Open |
| B9 | Tactician role mix 45/30/20/5 → 35/30/30/5 (V/R/H/S); counter weights cubed and clamped 0.25–3 | The Tactician barely changed its build against Heavy spam |
| B10 | Rusher: Hold releases at 45 s of income (was 20); 2 turrets from 1:30; Forge from 1:00 | Rusher sent units one by one into early turrets and fed the opponent XP. 17% aggregate at n=20. Open |

| B11 | Horde cost multiplier 0.8 → **0.73** | Forced Horde-vs-Elite Tactician mirrors, n=60: 0.80 → 10%, 0.76 → 25%, 0.74 → 38%, 0.72 → 57%. On one lane only the front few units fight, so per-unit strength beats unit count; Horde needs a bigger per-gold edge than Lanchester arithmetic suggests |
| B12 | AI: staged pushes. Gather just outside enemy turret range, attack together once the group outweighs the defence (`push_ratio`, default 1.3); needed margin shrinks as the enemy base weakens; never stage more than 30 s | Stalled matches showed armies arriving strung out by speed and dying one at a time at the gate. Turtle mirror escalation 45% → 5–15% |
| B13 | AI: buy the best affordable unit instead of hoarding for an expensive pick when the army is thin, under pressure, or the wait is over 8 s | A defending AI sat on 1,500+ gold for minutes, saving for a 1,700 g Strider while being pushed. Fixing it cut escalation from 36% to ~2% and median length from 14:23 to ~7:30 |
| B14 | AI counters from a data table (`counter_table`), derived from single-role duels: Vanguard > Heavy (100% in every age), Heavy > Ranged (100% through Age 4; flips in Age 6), Ranged > Vanguard (100%, 31% in Age 6) | The matrix-reasoned counters answered Heavies with Heavies, which loses; Heavy spam beat the Hard Tactician 95%. The role triangle is legible rock-paper-scissors |

| B15 | **v3 rules** (spec 2026-09-26): no veterancy, doctrines, momentum or stances; gold upgrades; XP skills with auto-targeted shapes; every unit attacks turrets; 1 free turret slot | New baseline, n=20: seed 1 **2/8**, seed 2 **2/8**. Passing: Tactician mirror 10:11 / 10:26, fast-age vs. skill-heavy 53% / 59%. Failing: escalation 30% / 35%, Rusher 13% / 15%, Heavy spam 100%, Ranged spam 73% / 70%, Turtle mirror to 30:00 |
| B16 | AI buys an upgrade only when its bonus on the gold already fielded in that row (× personality `upgrade_bias`) covers its price; Turtle turret bias 3 → 5 | Code fix (with test), not judged by the keep-rule. Traces showed the AI spending almost all its gold on 12 g Age 1 upgrades from 0:30 with two units on the lane and never evolving. After: Rusher 48% / 56%, but escalation 47% / 48% and seed 1 **1/8**, seed 2 **0/8** — which exposed B17 and B18 |
| B17 | Skill cooldown 20 → 40 s | Escalation 47 → 37%, 48 → 38%; passing targets unchanged (1 / 0) |
| B18 | Stampede damage 80 → 35, Bombardment 480 → 200 (the two whole-lane sweeps); Ranged damage ×0.85 in every age | 4 of 6 Tactician mirrors ended at 96 s: a 60 XP Stampede one-shot the whole enemy Age 1 army (6 kills in 1.6 s) and the loser never recovered. Lower sweep damage alone let Ranged spam reach 100% (the sweep had been hiding it), so it was tested together with the Ranged cut. Pair: seed 1 **1 → 4/8**, seed 2 **0 → 2/8**; mirror 11:52 / 11:35; Age 6 13:55 / 14:02 (57% / 53% of sides); Ranged spam 42% / 55%; Heavy spam 75% / 75% |
| — | Rejected on both seeds (keep-rule: target metric better on both seeds, passing count not lower, no failing target more than 10 points worse) | Heavy HP ×0.85 or Heavy cost ×1.2 (escalation +20 points); skill XP costs ×2 (escalation +3–4); Heavy HP ×0.85 on top of B18 (Vanguard spam 50–65%); evolution costs ×0.8 / ×0.7 (passing 4 → 2 / 1, fewer sides reach Age 6); base HP ×0.8 (passing 4 → 2). Three rejections in a row ended the pass |
| B19 | Review fix: the AI saves for an upgrade in a row it favours strongly (bias ≥ 3, i.e. Turtle's turrets) like a structure; a turret slot far out of reach no longer blocks that want | Turtle (one turret all game, never 60–470 g spare) upgraded turrets in 1 of 5 test matches; now 5 of 5 (GDD §11.2 identity). Cost: seed 1 **4 → 3/8**, seed 2 **2/8**; escalation 41 → 46%, 40 → 45%; Turtle 42% / 37%. Letting the blocked slot fall through to Income as well (65–69% escalation) and saving for Rusher's Vanguard upgrades (Rusher 78–81%) were both tried and dropped |

## Findings for the design docs

- **Army size.** The GDD economy gives about 2–10 units per side on the lane, not the 30-vs-30 that PRD §6 and §11 budget for. See PLAN §9.
- **GDD §4.3 pacing model** overestimates early XP: it assumes average Forge levels from 0:00 and ignores gold spent on turrets and the Forge.
- **Doctrine parity** has to be checked per gold (HP × damage ÷ cost), not by eye: the v2 numbers were a 45% swing apart.
- **The role triangle is rock-paper-scissors in practice** (B14): Vanguards swarm Heavies, Heavies hold Ranged, Ranged shred Vanguards. The damage matrix alone suggests "Heavies beat Heavies", which is true per hit but loses to cheap mass on one lane. GDD §5.2's "reading it" line should be updated once balance settles.
- **Hoarding and trickling, not numbers, caused most stalemates** (B12, B13). With the AI spending properly and pushing together, matches resolve — now too fast (see the next tuning pass).

## v3 findings (M1b-7 not green)

After B15–B19 the harness passes **3/8 on seed 1 and 2/8 on seed 2** (`reports/sim_report.md` is seed 1). Still failing, with the diagnosed cause:

- **Stalemates: 41% of matches reach 15:00 (target < 10%); the Turtle mirror escalates 45–50% and runs to 30:00.** Not fully isolated. The prime suspect is the removal of Hold/staged pushes: B12 had cut Turtle-mirror escalation from 45% to 5–15%. Units now walk out as they are trained — fast Vanguards ahead of the slower units — and die piecemeal at defended gates. The levers that cut stalemates (cheaper evolution, lower base HP) broke other targets. **Needs a design decision:** some way for waves to form (for example units wait at the gate until a wave is ready, or a "send wave" button), or stronger escalation.
- **Heavy spam beats the Tactician 75%.** The Stone Age Heavy (420 HP, ~19 damage/s) beats an equal-gold mixed army that arrives strung out. Heavy nerfs pushed stalemates up 20 points or let Vanguard spam through, so this is tied to the wave problem above.
- **Age 6 arrives at ~14:00 (target 10:00–12:00) and only ~55% of sides reach it.** XP is now split between skills and evolving; cheaper evolution made matches end before Age 6 more often.
- **Ranged spam wins 42–55%** (target < 30%).
- **Turtle keeps only one turret all game:** slots 2–4 (400 × 1.7ⁿ g by then) are never affordable within its 30 s saving window, so its "turret wall" identity rests on one upgraded turret. Slot prices or the AI's saving window need a look.
