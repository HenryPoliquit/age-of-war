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

## Findings for the design docs

- **Army size.** The GDD economy gives about 2–10 units per side on the lane, not the 30-vs-30 that PRD §6 and §11 budget for. See PLAN §9.
- **GDD §4.3 pacing model** overestimates early XP: it assumes average Forge levels from 0:00 and ignores gold spent on turrets and the Forge.
- **Doctrine parity** has to be checked per gold (HP × damage ÷ cost), not by eye: the v2 numbers were a 45% swing apart.
- **The role triangle is rock-paper-scissors in practice** (B14): Vanguards swarm Heavies, Heavies hold Ranged, Ranged shred Vanguards. The damage matrix alone suggests "Heavies beat Heavies", which is true per hit but loses to cheap mass on one lane. GDD §5.2's "reading it" line should be updated once balance settles.
- **Hoarding and trickling, not numbers, caused most stalemates** (B12, B13). With the AI spending properly and pushing together, matches resolve — now too fast (see the next tuning pass).
