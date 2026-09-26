# Simplify systems, add upgrades, rebuild the HUD — design

**Date:** 2026-09-26
**Status:** Approved in conversation, awaiting written-spec review
**Branch:** `claude/sharp-ptolemy-mmxowi`
**Supersedes:** parts of `docs/GDD.md` v2 (§4 veterancy, §8 front line & momentum, §9 doctrines, §10 controls/HUD) and `docs/PRD.md` goals G3/G4 and the doctrine row of §6.

## 1. Why

The owner's first local playtest found the game harder to read than Age of War:

- The command panel (bottom right) is a cluster of small, similar grey buttons; the top bar is mostly empty space.
- Veterancy (abstract ranks that reset on evolving) and doctrines (Elite/Horde, Bastion/Siegecraft) were confusing and did not exist in Age of War.
- The special skill was unclear to use (hold Space to aim, release to fire), fiddly to aim, and did not visibly do much.
- Hold/Advance is added complexity.
- Missing: Age of War-style stat upgrades per unit type and for turrets.

Direction agreed: stay close to Age of War's simplicity, keep one real decision per currency.

- **Gold buys the army:** units, turrets, turret slots, and all upgrades. Decision: more units or stronger units.
- **XP buys progress:** evolving, and the special skill. Decision: use the skill now or evolve sooner.

The PRD's own risk note ("more systems can bury the hook") is the justification; this replaces G3's "evolve or veterancy" with "skill or evolve" and G4's doctrines with AI personalities (already present) as the source of variety.

## 2. Game rules

### 2.1 Removed

| System | Replacement |
| --- | --- |
| Veterancy (XP ranks, reset on evolve) | Stat upgrades (§2.2), bought with gold |
| Doctrines (Elite/Horde at Age 2, Bastion/Siegecraft at Age 4) | None. AI personalities provide match variety |
| Momentum (front-line pushing, kills, base damage → ability charge) | The skill costs XP (§3) |
| Forge button | "Income" row in the upgrade panel (same effect) |
| Stance: Hold/Advance, rally line (Shift+click), `S` hotkey | Units always advance. Applies to the AI as well |
| "Only Siege damages turrets" (PLAN D3) | All units can attack turrets (§2.3) |

The front line remains as a visual (the seam where the two eras' backdrops meet) but grants nothing.

### 2.2 Upgrades

Bought with **gold**, **3 levels** each, **permanent for the match** (carried across evolutions and applied to new-era units), and applied **immediately** to units and turrets already on the field.

| Row | Upgrade 1 | Upgrade 2 | Upgrade 3 |
| --- | --- | --- | --- |
| Each unit slot (Vanguard, Ranged, Heavy, Siege) — 4 rows | ⚔ Attack +15% / level | ♥ Health +15% / level | 🛡 Defence: −10% damage taken / level |
| Turrets (all turrets) | ⚔ Attack +15% / level | ♥ Health +15% / level | ➶ Range +10% / level |
| 💰 Income | +20% passive income / level (today's Forge) | — | — |

15 upgrades in total. Upgrades are per unit **slot** (role), not per unit name: "Archer ⚔ level 2" becomes "Ranged ⚔ level 2" and applies to every era's Ranged unit, displayed with the current era's unit name.

**Starting costs** (all values in data, tuned by the harness):

- Unit rows: level *n* costs `k[n] × current price of that slot's unit`, with `k = (0.6, 1.0, 1.5)`. Scales with era and with the unit (Heavy upgrades cost more than Vanguard ones).
- Turret row: `k[n] × average cost of the current era's turrets`, same `k`.
- Income: 100 / 250 / 500 gold (today's Forge costs).

Health upgrades raise max HP and current HP by the same ratio, so buying one mid-fight heals proportionally, the same rule evolving uses for bases.

### 2.3 Turrets and slots

- **Slots:** 1 free slot; slots 2, 3, 4 unlock with gold (starting costs 150 / 400 / 700 × era cost multiplier — today's slot 3–5 costs moved down one slot). Maximum 4.
- **Building:** click an empty slot → the current era's turret roster, with prices. **Selling:** click a built turret → "Sell for *x* g" (50% refund, unchanged). Turrets still do not auto-upgrade on evolving.
- **Targeting:** any unit with no enemy unit in range attacks the nearest structure: turrets (lowest slot first) before the base, as Siege does today. Damage uses the existing damage matrix against `structure` armour (Slash 0.5×, Pierce 0.4×, Blast 1.2×, Siege 2.5×), so Siege keeps its role as the structure-breaker.

### 2.4 Unchanged

Evolving (XP cost, 5 s transition, base HP ×1.7 keeping its percentage), the unit roster and roles, the damage matrix, the tide (shared rising income), escalation from 15:00, the 5-slot training queue, the 30-unit field cap, bounties.

## 3. Special skill

- **Use:** click ☄ Skill (top bar) or press Space. It fires immediately; **no aiming**.
- **Cost:** XP, per era (data). Starting value: 25% of that era's next evolution cost; Age 6 set explicitly in data. Plus a **cooldown** (starting value 20 s) so banked XP can't be dumped in a burst.
- **Button:** shows name and XP cost; disabled when unaffordable; cooldown ring after use; tooltip names the effect and shape.
- **Targets units only**, never turrets or bases (PLAN D8, unchanged).

### 3.1 Shapes (auto-targeted)

| Shape | Where it lands |
| --- | --- |
| **Area** | Centred on the densest enemy group (most enemy unit value within the skill's width) |
| **Strip** | Starts at the enemy's front unit and extends toward their base for the skill's width |
| **Sweep** | Travels from our gate to the enemy gate over its duration; hits every enemy unit it passes |

### 3.2 Per era

| Era | Skill | Shape | Note |
| --- | --- | --- | --- |
| 1 | Stampede | Sweep | Knockback |
| 2 | Rockfall | Area | **New**; replaces Shieldwall (an invisible ally buff) |
| 3 | Volley | Strip | |
| 4 | Bombardment | Sweep | Walking barrage |
| 5 | Cannonade | Strip | |
| 6 | Starfall | Area | Large meteor |

### 3.3 Readability

A telegraph marks where it will land during the wind-up; stronger impact VFX and screen shake; a short result line afterwards ("Volley: 6 killed"). Damage values raised as the harness allows.

## 4. HUD

The bottom-centre of the screen is the battlefield; the HUD sits on the top edge and the bottom corners.

### 4.1 Top bar (slim, single row)

| Left | Centre | Right |
| --- | --- | --- |
| ★ XP · ▲ Evolve (XP cost, `T`) · ☄ Skill (name, XP cost, `Space`) | Your era · elapsed time · enemy era | ⬆ Upgrades (toggle, drops the upgrade grid below it) · ● Gold (+income/s) · 1×/2× toggle · ⏸ Pause · ⚙ Settings |

Removed from the top: the tide pips and the minimap strip under the bar.

### 4.2 Upgrade grid (drop-down)

Opened and closed by ⬆ Upgrades. Rows: the 4 unit slots (named by the current era's units), Turrets, Income. Columns: ⚔ ♥ 🛡 (➶ for the Turrets row). Each cell: level pips and next price; greyed when unaffordable; gold border at max level; hover shows the exact effect ("Ranged ⚔ 2 → 3: +15% damage for all Ranged units, every era — 60 g"). The game keeps running while it is open. Mouse only.

### 4.3 Bottom

| Left | Centre | Right |
| --- | --- | --- |
| 4 unit cards, smaller than today (portrait, name, price; hotkeys 1–4) | **Lane map**: a strip with both gates and a dot per unit, blue and orange. Under it, next to the unit cards: **Training** (current unit + progress bar) and the **queue** (5 slots) | 4 turret slots (hotkeys Q W E R): built (portrait, name), empty (＋), locked (🔒 + unlock price) |

Turret popups open directly above the slot clicked, like a drop-down: the build list for an empty slot, "Sell for *x* g" for a built one. One popup at a time; clicking elsewhere closes it.

### 4.4 In the world

A base HP bar above each base.

### 4.5 Controls

Kept: 1–4 (train), Q–R (turret slots), T (evolve), Space (skill), A/D and right-drag (pan), Esc (settings/pause). Removed: S (stance), V (veterancy), F (Forge), Shift+click (rally), and F1–F3 (speed presets and pause), which the 1×/2× toggle and ⏸ button replace; Esc still pauses via settings.

Mockups: the approved layout is `hud-v6.html` from the brainstorming session (not committed); §4 is the source of truth.

## 5. AI

- **Remove:** veterancy purchases, doctrine picks and preferences, stance/staged-push logic, momentum-based ability timing.
- **Keep:** role-mix/counter unit choice (B9, B14), no hoarding (B13), and this session's two fixes — save for a turret when camped at the gate if it is affordable before the base falls, and allow a longer save (30 s) for Siege.
- **Add — upgrades:** after unit and structural wants, buy upgrades by a personality-weighted score: Tactician upgrades the roles it fields most; Turtle favours the Turrets row; Economist favours Income early; Rusher favours Vanguard ⚔ and buys few.
- **Add — skill:** fire when the skill's auto-target would hit enemy unit value (gold paid) ≥ `skill_min_value × current era cost multiplier`, a difficulty field in data (Easy fires on any 2+ units), or immediately when the base is under pressure. Skip if the XP spent would delay an evolution the age plan wants within 10 s.
- **Personalities without stance:** Rusher keeps early aggression through its unit mix, fast age plan and few turrets; Turtle through turrets, turret upgrades and range.
- **Sim-only archetypes:** `strong_age` (relied on veterancy) is replaced by `skill_heavy` (fires the skill whenever affordable; otherwise balanced).

## 6. Simulation and data

- `MatchSim`: remove `buy_veterancy`, `choose_doctrine`, `awaiting_doctrine`, momentum, `set_stance`/rally; `buy_forge` becomes part of `buy_upgrade(side, row, stat)`; `fire_ability(side)` takes no target, charges XP, applies the cooldown and resolves the shape; unit structure targeting per §2.3; slot count per §2.3.
- `SimSide`: `upgrades` (row → stat → level); stat lookups multiply by upgrade level at damage/HP time so upgrades apply live.
- Data: `rules.tres` gains upgrade percentages, level cost factors, income costs, skill cooldown; loses veterancy, momentum and doctrine fields. `data/doctrines/` deleted. Each ability gains `shape` (`area`/`strip`/`sweep`) and `xp_cost`; `shieldwall.tres` replaced by `rockfall.tres`. Personality files lose `doctrine_prefs`, `uses_hold`, `hold_release_seconds`, `push_ratio`, veterancy fields; gain upgrade weights and a skill threshold.
- `tools/validate_data.gd` updated for the new schema.
- Match log and post-match screen: drop momentum series and doctrine events; add upgrade purchases and skill uses.
- Determinism rules unchanged (no unseeded randomness in `scripts/sim/`).

## 7. Balance harness and targets

PRD §6 changes:

| Row | Change |
| --- | --- |
| Doctrine win rate | Removed |
| Decisions | Fast-age vs. **skill-heavy** Tactician, 40–60% |
| Worst-case defence | "Turtle vs. Turtle" (no Bastion), same thresholds |

All other targets stay. After the rules and AI land, run the harness on two seeds, tune data until green, and record every change in `docs/balance_log.md`; anything that won't go green is reported with the harness evidence rather than forced.

Known risk: removing momentum and staged pushes removes two anti-stalemate tools (B12 cut Turtle-mirror escalation from 45% to 5–15%). Units now attacking turrets and the tide/escalation are the remaining pressure; the harness decides whether more is needed.

## 8. Tests

- **Remove or rewrite:** veterancy (`test_evolution`), doctrine costs (`test_economy`), momentum and ability-momentum tests (`test_match`), "only Siege hits turrets" (`test_combat`), stance/Hold tests.
- **Add:** upgrade cost by level and era; each stat's effect (attack, health incl. proportional heal, defence, turret range, income); upgrades persist through evolving and apply to already-fielded units; one free slot and unlock costs; non-Siege units damage turrets at their matrix multiplier, turrets before base; each skill shape selects the right targets (area → densest group, strip → from the enemy front, sweep → whole lane); skill XP cost and cooldown; AI buys upgrades and fires skills in a full match; determinism test still byte-identical.

## 9. Docs

- `docs/GDD.md` → v3: "What changed in v3" section with the reasons above; rewrite §1 loop, §4 (XP: evolve or skill), §6 (turrets/slots), §7 (skills), §8 (front line visual only, no momentum), §9 (doctrines removed), §10 controls/HUD.
- `docs/PRD.md`: G3 → "Gold: army or upgrades; XP: skill or evolve"; G4 → personalities (campaign modifiers later); §6 targets per §7 here; teaching-battle list updated.
- `docs/PLAN.md`: D3 superseded; new decisions for upgrades, skill shapes, slots; §5 AI; §10 HUD rows.
- `docs/balance_log.md`: entries for the removals and this session's AI fixes; `docs/tasks/`: new milestone task list for this change.
- `CLAUDE.md`: remove references to removed systems if any.

## 10. Order of work

Rules first, then HUD (agreed):

1. Docs (GDD/PRD/PLAN) updated to v3 so the code has a spec to match.
2. Sim + data + validator + tests (§2, §3, §6, §8).
3. AI (§5), full-match tests green.
4. Harness targets (§7), balance pass, balance log.
5. HUD (§4), owner reviews locally.

## 11. Out of scope

Tutorial/Chronicle battles, flying units (and "ground only" skill variants), per-race skill names or art beyond today's race system, new painted art, multiplayer. Doctrines may return later as campaign battle modifiers.
