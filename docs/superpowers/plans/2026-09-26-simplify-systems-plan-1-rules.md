# Simplify Systems — Plan 1: Rules, AI, Balance and Docs

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace veterancy, doctrines, momentum and stances with gold-bought stat upgrades and one-click XP skills, let every unit attack turrets, start with one turret slot, and re-balance — leaving the current HUD patched just enough to play.

**Architecture:** All rules live in `scripts/sim/match_sim.gd` (deterministic, render-free); data in `data/*.tres` resources; the AI (`scripts/ai/utility_ai.gd`) acts only through `MatchSim` commands. Removals go first (doctrines → stance → veterancy), then the new systems (skills → turret targeting → slots → upgrades → AI upgrades), then a balance pass. The full HUD rebuild is **Plan 2** (spec §4) and is out of scope here: this plan only removes dead controls and repoints two buttons.

**Tech Stack:** Godot 4.7-stable, GDScript, in-repo test runner (`tests/run_tests.gd`), balance harness (`tools/sim/run_sim.gd`), Python 3 for `tools/sim/tune.py`.

**Spec:** `docs/superpowers/specs/2026-09-26-simplify-systems-and-hud-design.md`

## Global Constraints

- Godot **4.7-stable** only. Locally: `export GODOT="$(pwd)/../Godot_v4.7/Godot_v4.7-stable_win64_console.exe"` from the repo root (Git Bash). In cloud sessions: `GODOT=tools/godot` after `tools/setup_env.sh`.
- Always wrap Godot in `timeout`: a script that fails to compile leaves headless Godot running forever.
- Test command: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd` → must end with `N tests, 0 failures` and exit 0. Data check: `timeout 60 "$GODOT" --headless --path . -s tools/validate_data.gd` → `data OK: ...`.
- `scripts/sim/` stays deterministic: no `randf()`/`Time` in sim code.
- Stats live in `data/*.tres`, never hardcoded in scripts.
- Typed GDScript: a `var x := <expr>` whose type can't be inferred (e.g. `Dictionary.get(...) in [...]`) is a compile error — declare the type (`var x: bool = ...`).
- Upgrades (spec §2.2): gold only; 3 levels; Attack +15%/level, Health +15%/level, Defence −10% damage taken/level, turret Range +10%/level; level *n* costs `(0.6, 1.0, 1.5)[n−1] × current price` (unit rows: that role's current-age unit; turret row: average current-age turret cost); Income 100 / 250 / 500 × age cost multiplier, +20% income/level; permanent for the match; applied immediately to fielded units/turrets; Health keeps HP percentage.
- Turret slots (spec §2.3): 1 free; slots 2/3/4 cost 150/400/700 × age cost multiplier; max 4.
- Skills (spec §3): XP cost per era in data (starting 60/75/175/275/700/1000), 20 s cooldown, auto-targeted `area`/`strip`/`sweep`, hit units only.
- Commit messages end with: `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`
- After any balance change under `data/` (or AI/sim logic), run the harness and record the change in `docs/balance_log.md` (CLAUDE.md rule). Tasks 2–9 change rules wholesale; the harness is re-baselined once in Task 10.

## Review Focus

1. **Siege upgrade row in Age 1** (no Siege unit exists): cost must be `INF`, the purchase must fail without charging, and it must become buyable after evolving to Age 2 — Task 8 `test_siege_row_unavailable_in_age_1`.
2. **Firing a skill with no enemy on the lane** must fail and charge no XP (not burn XP on nothing) — Task 5 `test_needs_a_target`.
3. **Health upgrade on damaged units and turrets** must keep the HP percentage (no free full heal, no kill) — Task 8 `test_health_upgrade_scales_fielded_and_new_units_keeping_percentage` and `test_turret_upgrades`.
4. **Turrets built after a Health upgrade** must get the upgraded HP, and the **Range upgrade must also widen Support auras** — Task 8 `test_turret_upgrades` and `test_range_upgrade_widens_support_aura`.
5. **Older-age units still on the lane** after evolving must receive role upgrades bought later (upgrades are per role, not per age) — Task 8 `test_upgrades_apply_to_older_age_units`.

---

### Task 0: Commit the pending balance-session work

**Files:**
- Already modified (uncommitted): `scripts/ai/utility_ai.gd` (gate-defence turret saving + Siege 30 s save), `tools/sim/tune.py` (Windows portability), `tools/sim/run_sim.gd` (doctrine metric fix — removed again in Task 2)
- Already created: `docs/superpowers/specs/2026-09-26-simplify-systems-and-hud-design.md`, this plan

- [ ] **Step 1: Verify the working tree is what we expect**

Run: `git status --short`
Expected: ` M scripts/ai/utility_ai.gd`, ` M tools/sim/run_sim.gd`, ` M tools/sim/tune.py`, `?? docs/superpowers/`, `?? Godot_v4.7-stable_win64.exe.zip`. Do **not** add the zip.

- [ ] **Step 2: Run the tests**

Run: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd`
Expected: `36 tests, 0 failures`

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/utility_ai.gd tools/sim/run_sim.gd tools/sim/tune.py docs/superpowers/
git commit -m "AI gate-defence and Siege saving fixes; portable tuner; simplify-systems spec and plan

- AI saves for a turret when camped at the gate, if affordable before the base falls
- AI may save up to 30 s for Siege (it never bought any, so won games stalled at the gate)
- run_sim: compare doctrines only within the same offer (Age 4 picks were survivor-biased)
- tune.py: GODOT env var, subprocess timeout, --workers

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 1: Design docs to v3

**Files:**
- Modify: `docs/GDD.md`, `docs/PRD.md`, `docs/PLAN.md`, `CLAUDE.md`
- Create: `docs/tasks/M1b.md`

This task is prose; each step gives the exact replacement text. "Replace section X" means from that heading line up to (not including) the next heading of the same or higher level.

- [ ] **Step 1: GDD header and v3 notes**

In `docs/GDD.md` change `**Status:** Draft v2` → `**Status:** Draft v3` and `**Last updated:** 2026-09-25` → `**Last updated:** 2026-09-26`. Insert before `### What changed in v2`:

```markdown
### What changed in v3

From the owner's first local playtest (spec: `docs/superpowers/specs/2026-09-26-simplify-systems-and-hud-design.md`). The game read as more complicated than Age of War without being more fun, so v3 cuts the systems players had to learn and keeps one decision per currency: **gold buys the army** (units, turrets, slots, upgrades), **XP buys progress** (evolving, the special skill).

- **Removed:** veterancy (§4.5), doctrines (§9), momentum (§8.2), Hold/Advance stances and the rally line (§10), the Forge button (now the Income upgrade, §6.1).
- **New — upgrades (§6.1):** gold buys Attack / Health / Defence for each unit slot, Attack / Health / Range for all turrets, and Income. Three levels each, kept for the whole match.
- **Skills (§7)** cost XP, fire with one click and aim themselves by shape (area, strip, sweep). Shieldwall is replaced by Rockfall.
- **Turrets (§6):** one free slot, three to unlock; every unit can attack turrets, Siege hardest.
- **HUD (§13.9):** slim top bar; units bottom-left, turret slots bottom-right, lane map and training queue between them; upgrades in a drop-down.

```

- [ ] **Step 2: GDD §1 core loop**

In §1 replace list items 4 and 5 with:

```markdown
4. **Spend XP** to evolve to the next age *or* to fire the age's special skill (§4, §7).
5. **Spend gold on upgrades** (§6.1) to make a unit slot or your turrets stronger for the rest of the match.
```

and replace the diagram inside the code fence with:

```
  Tide ──► Gold ──► Units, Turrets & Upgrades ──► Combat ──► XP ──► Evolve  or  Skill
              ▲                                      │
              └─────────────── Bounties ◄────────────┘
```

- [ ] **Step 3: GDD §3.4, §4.5**

Replace section `### 3.4 Momentum` with:

```markdown
### 3.4 Momentum (removed in v3)

The special skill is paid in XP (§7). The front line is still drawn (§8.1) but grants nothing.
```

Replace section `### 4.5 Veterancy (the alternative to evolving)` with:

```markdown
### 4.5 Veterancy (removed in v3)

Replaced by upgrades (§6.1), bought with gold. XP's alternative to evolving is now the special skill (§7): every skill fired pushes the next evolution back.
```

- [ ] **Step 4: GDD §6 turrets and new §6.1 upgrades**

In §6 replace the `- **Slots:** …` bullet with:

```markdown
- **Slots:** 1 free; slots 2, 3 and 4 cost 150 / 400 / 700 gold × your age cost multiplier. Maximum 4.
- **Every unit attacks turrets.** A unit with no enemy unit in range hits the nearest structure — turrets (lowest slot first), then the base — at its damage type's Structure multiplier (§5.2), so Siege stays the structure-breaker.
```

Append at the end of §6 (before `## 7.`):

```markdown
### 6.1 Upgrades

Bought with **gold**, **3 levels** each, **kept for the whole match** (they carry across evolutions) and applied **immediately** to units and turrets already on the field. Unit upgrades belong to a unit **slot** (Vanguard, Ranged, Heavy, Siege), so the next era's unit in that slot inherits them.

| Row | ⚔ | ♥ | Third |
| --- | --- | --- | --- |
| Each unit slot (4 rows) | Attack +15% / level | Health +15% / level | 🛡 Defence −10% damage taken / level |
| Turrets (all) | Attack +15% / level | Health +15% / level | ➶ Range +10% / level (Support auras too) |
| 💰 Income | +20% passive income / level | — | — |

**Costs:** level *n* of a unit row costs 0.6× / 1.0× / 1.5× the current price of that slot's unit; the turret row uses the average current-era turret cost; Income costs 100 / 250 / 500 × the age cost multiplier. Health upgrades keep the current HP percentage. The Siege row is unavailable until Siege exists (Age 2).
```

- [ ] **Step 5: GDD §7 skills**

Replace section `## 7. Age Abilities` with:

```markdown
## 7. Special Skills

Each era has one **special skill**. Click ☄ Skill or press Space: it fires immediately and **aims itself** — no aiming. It costs **XP** (so every use delays the next evolution) and has a **20 s cooldown**. Skills hit units only, never turrets or bases.

| Shape | Where it lands |
| --- | --- |
| **Area** | Centred on the densest enemy group (most enemy unit value within its width) |
| **Strip** | From the enemy's front unit back toward their base, for its width |
| **Sweep** | Travels from your gate to the enemy gate, hitting every enemy unit it passes |

| Era | Skill | Shape | XP (starting) |
| --- | --- | --- | --- |
| Stone | **Stampede** — a herd charges down the lane, knocking enemies back | Sweep | 60 |
| Bronze | **Rockfall** — boulders crash onto the biggest enemy group | Area | 75 |
| Iron | **Volley** — three volleys along the enemy line (Pierce) | Strip | 175 |
| Medieval | **Bombardment** — a walking barrage from gate to gate (Blast) | Sweep | 275 |
| Gunpowder | **Cannonade** — heavy Blast along the enemy line, telegraphed | Strip | 700 |
| Arcane | **Starfall** — a massive strike on the densest group after a 1.5 s telegraph | Area | 1,000 |

A marker shows where it will land during the telegraph; afterwards a short line reports the result ("Volley: 6 killed"). Each race names and dresses the same skill (human / elf / dwarf): Stampede / Wild Hunt / Ram Charge, Rockfall / Stone Rain / Boulder Toss, Pilum Volley / Arrow Rain / Axe Storm, Trebuchet Barrage / Hail of Thorns / Rockslide, Cannonade / Moonfire / Grand Cannonade, Arcane Lance / Starfall / Thunder Rune. The AI uses the same skills under the same rules.
```

- [ ] **Step 6: GDD §8, §9, §10**

Change heading `## 8. Front Line, Momentum & Escalation` → `## 8. Front Line & Escalation`, and its first paragraph to: `The central fix for Age of War 2's stalemates: the tide makes late armies strong enough to break defences, every unit can break turrets, and a backstop forces an ending.` In §8.1 delete ` — regardless of stance, so units held at a rally line past midfield count`. Replace section `### 8.2 Momentum` with:

```markdown
### 8.2 Momentum (removed in v3)

Skills are paid in XP (§7).
```

Replace section `## 9. Doctrines` with:

```markdown
## 9. Doctrines (removed in v3)

Cut after the first playtest: invisible modifiers that confused players and were the least balanced system in the simulations. AI personalities (§11.2) provide match variety. Doctrines may return as Chronicle battle modifiers.
```

Replace section `## 10. Player Controls & Unit Stances` with:

```markdown
## 10. Player Controls

| Action | Mouse | Keyboard |
| --- | --- | --- |
| Queue unit | Click unit card | 1 / 2 / 3 / 4 |
| Build / sell turret | Click slot (a list opens above it) | Q / W / E / R |
| Evolve | Click ▲ Evolve | T |
| Fire skill | Click ☄ Skill | Space |
| Upgrades | ⬆ Upgrades opens the grid; click a cell | — |
| Pan camera | Edge-pan or right-drag | A / D |
| Speed / pause | 1×/2× toggle, ⏸ | Esc opens settings (pauses) |

Units always advance; there are no stances.
```

- [ ] **Step 7: GDD §11, §12.2, §13.9, §15**

In §11.1: change `same abilities it must aim` → `same skills`; in the difficulty table rename the column `Ability aim` → `Skill use` with values Easy `Any 2+ units`, Normal `Worthwhile group`, Hard/Brutal/Nightmare `Highest-value moments; never delays a planned evolution`; change Nightmare's counter-play `As Hard, plus doctrine counters` → `As Hard`.

Replace the §11.2 table rows with:

```markdown
| **Rusher** | Early aggression, fast-age, few turrets, upgrades its Vanguards |
| **Turtle** | Early turrets and turret upgrades, counter-attacks when you over-extend |
| **Economist** | Early Income upgrades, big late-game waves |
| **Tactician** | Adapts to your composition; upgrades what it fields most; the default balanced opponent |
```

Replace the §11.3 archetype bullets with:

```markdown
- **Fast-age Tactician:** always evolves the moment XP allows; fires the skill only when it can't delay an evolution.
- **Skill-heavy Tactician:** fires the skill whenever it can hit anything.
- **Spam bots:** queue only one role (one bot per role). Used for the dominant-unit check (PRD §6).
```

In §11.4 replace the candidate-action list with `(queue each unit, build/sell a turret, unlock a slot, evolve, fire the skill, buy an upgrade)` and the state list with `(front position, compositions, gold, XP, base HP, tide level)`.

In §12.2 replace rows 4 and 5 with:

```markdown
| 4 | The special skill (XP) and the front line |
| 5 | Upgrades: more units or stronger units |
```

Replace section `### 13.9 HUD` with:

```markdown
### 13.9 HUD

- **Top bar (slim):** left — XP, ▲ Evolve, ☄ Skill; centre — your era, elapsed time, enemy era; right — ⬆ Upgrades (drop-down grid), gold (+income/s), 1×/2× toggle, pause, settings.
- **Bottom left:** four unit cards (portrait, name, price, hotkey).
- **Bottom centre:** lane map (gates and a dot per unit); under it, the unit in training with its progress bar and the 5-slot queue.
- **Bottom right:** four turret slots (built, empty, locked with unlock price); clicking one opens the build list or a Sell option directly above it.
- **In the world:** a base HP bar above each base.
- Tooltips show the damage × armour matrix row for the hovered unit, and exact effects and prices for upgrades.
```

In §15.1 change `Every unit, turret, ability, age, doctrine, tide level and AI personality` → `Every unit, turret, skill, age, tide level and AI personality`. In §15.2 delete `, with randomised doctrine choices`, change `win rates by personality, doctrine and archetype` → `win rates by personality and archetype`, and in the targets table delete the row `| Any doctrine's win rate | 40–60% |`, change `| Fast-age vs. strong-age Tactician | each wins 40–60% |` → `| Fast-age vs. skill-heavy Tactician | each wins 40–60% |` and `Turtle vs. Turtle, both Bastion (worst-case defence mirror)` → `Turtle vs. Turtle (worst-case defence mirror)`.

- [ ] **Step 8: PRD**

In `docs/PRD.md`:
- G1: `The front line rewards pushing, income rises` → `Income rises`; append `Every unit can attack turrets, so turret walls fall.` after `break defences,` (keep the rest).
- Replace G3 with: `- **G3 — Real decisions.** Gold buys *either* more units *or* stronger ones (per-unit and turret upgrades); XP buys *either* the next age *or* the era's special skill; turrets get outclassed and must be replaced. *(Fixes: shallow decisions.)*`
- Replace G4 with: `- **G4 — Replayability without grind.** AI opponents with distinct personalities, three races, and a campaign of handcrafted battle modifiers. *(Fixes: low replayability.)*`
- §6 table: delete the doctrine row; `Fast-age AI vs. strong-age AI (GDD §11.3)` → `Fast-age AI vs. skill-heavy AI (GDD §11.3)`; `Turtle vs. Turtle, both taking Bastion` → `Turtle vs. Turtle`.
- §9 vertical slice: `economy tide, front line, momentum, evolution, veterancy, turrets, first doctrine pick, escalation` → `economy tide, front line, evolution, special skills, upgrades, turrets, escalation`.
- §9 full game: delete `Two doctrine picks per match, ` (keep `four AI personalities, five difficulties.`); teaching battles `(queueing & counters → turrets → evolving → front line & abilities → veterancy & doctrines)` → `(queueing & counters → turrets → evolving → skills & the front line → upgrades)`; cut list item 4 → `4. Per-age extras beyond the core roster (skill variants, cosmetics).`
- Add under `### What changed in v2` a sibling section before it: `### What changed in v3` with one bullet: `- **Simplified after the first playtest** (GDD v3 notes): veterancy, doctrines, momentum and stances removed; gold-bought upgrades and XP skills added; G3, G4 and the §6 targets updated.`

- [ ] **Step 9: PLAN.md and CLAUDE.md**

In `docs/PLAN.md`:
- Commands line: replace the command list with `` `queue_unit`, `evolve`, `unlock_slot`, `build_turret`, `sell_turret`, `buy_upgrade`, `fire_ability` ``.
- Layout table `data/` row: `(roster, turrets, ability, doctrine offer, palette); units/, turrets/, abilities/, doctrines/;` → `(roster, turrets, skill, palette); units/, turrets/, abilities/;`. `tools/` row: delete `, bootstrap/gen_data.gd (one-shot, historical)`.
- §3: replace `doctrine \`pick_age\` consistency;` with `every skill has a shape and XP cost;`.
- §4 decisions: append to D3 ` **Superseded (v3):** every unit attacks turrets; the matrix makes Siege the breaker.`; append ` **Removed in v3.**` to D6, D7, D11, D12, D13; add rows:

```markdown
| D18 | Upgrades are per role (slot), stored on the side, and read at damage/HP time, so they apply to fielded and older-age units at once | Spec §2.2: "applied immediately", "carry over" |
| D19 | Health upgrades multiply max and current HP by the same ratio | Same rule evolving uses for bases; no free heals |
| D20 | A skill's zone is fixed when it fires (area: densest enemy window by gold value; strip: enemy front unit back toward their base; sweep: whole lane, one slice per pulse, away from the caster) | Auto-aim with a readable telegraph |
| D21 | Firing a skill with nothing to hit fails and costs nothing | Never burn XP on an empty lane |
| D22 | Siege upgrades cost `INF` (unavailable) while the age has no Siege unit | Age 1 has three roles |
```

- §5 AI: replace step 1 with `1. **Skill:** fire when the auto-target would hit enemy value ≥ \`skill_min_value\` × era cost multiplier (difficulty data), or at once under pressure; skip if it would delay an evolution due within 10 s. The skill-heavy archetype fires whenever it can hit anything.`; step 2 → `2. **XP:** evolve when affordable (Hard+ waits under pressure unless the enemy is an age ahead).`; delete step 3 (stance) and renumber; in the Gold step replace `→ Forge)` with `→ Income upgrade)`, delete `; Nightmare also counters doctrines`, and append `Leftover gold buys upgrades: rows weighted by the army's role shares × the personality's \`upgrade_bias\` (turrets by turret count), best level per gold first, only once the army is worth \`upgrade_after_army_seconds\` of income.`
- §6 harness table: `Tactician mirror, random doctrines | 3N | match length, Age 6 arrival, doctrine win rates` → `Tactician mirror | 3N | match length, Age 6 arrival`; `Fast-age vs. strong-age | 2N` → `Fast-age vs. skill-heavy | 2N`; `Turtle mirror (both Bastion by preference) | N` → `Turtle mirror | N`. Overrides example `--set=doctrines/horde.unit_cost_mult=0.75` → `--set=rules.income_upgrade_bonus=0.25`; experiment bullet delete `forced doctrines, `.
- §7: remove `momentum, ` from the timeline field list.

In `CLAUDE.md` replace `` - Stats live in `data/*.tres`, never hardcoded in scripts. `tools/bootstrap/gen_data.gd` was a one-shot; don't re-run it. `` with `` - Stats live in `data/*.tres`, never hardcoded in scripts. ``

- [ ] **Step 10: Task list**

Create `docs/tasks/M1b.md`:

```markdown
# M1b — Simplify systems (post-playtest)

Spec: `docs/superpowers/specs/2026-09-26-simplify-systems-and-hud-design.md`. Plan 1: `docs/superpowers/plans/2026-09-26-simplify-systems-plan-1-rules.md`.

| # | Task | Done-condition | Status |
| --- | --- | --- | --- |
| M1b-1 | Docs to v3 | GDD/PRD/PLAN describe the v3 rules | ⏳ |
| M1b-2 | Remove doctrines, stances, veterancy, momentum | Tests green; data validates; game runs | ⏳ |
| M1b-3 | XP skills with auto-targeted shapes; Rockfall | `test_skills` green | ⏳ |
| M1b-4 | All units attack turrets; 1 free slot + 3 to unlock | `test_combat`, `test_evolution` green | ⏳ |
| M1b-5 | Gold upgrades (units, turrets, income) | `test_upgrades` green | ⏳ |
| M1b-6 | AI buys upgrades and fires skills | Full-match tests green | ⏳ |
| M1b-7 | Balance to green | `run_sim.gd --matches=20` exits 0 on seeds 1 and 2, or findings recorded | ⏳ |
| M1b-8 | HUD rebuild (Plan 2) | Owner reviews locally | ⏳ |
```

- [ ] **Step 11: Commit**

```bash
git add docs/GDD.md docs/PRD.md docs/PLAN.md CLAUDE.md docs/tasks/M1b.md
git commit -m "Docs v3: cut veterancy, doctrines, momentum and stances; add upgrades and XP skills

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Remove doctrines

**Files:**
- Delete: `scripts/data/doctrine_def.gd`, `scripts/data/doctrine_def.gd.uid`, `data/doctrines/` (4 files), `tools/bootstrap/gen_data.gd`, `tools/bootstrap/gen_data.gd.uid`
- Modify: `scripts/data/age_def.gd`, `scripts/data/game_data.gd`, `scripts/data/ai_personality_def.gd`, `scripts/data/ai_difficulty_def.gd`, `scripts/sim/sim_side.gd`, `scripts/sim/sim_unit.gd`, `scripts/sim/match_sim.gd`, `scripts/sim/match_runner.gd`, `scripts/sim/sim_jobs.gd`, `scripts/ai/utility_ai.gd`, `scripts/view/match_hud.gd`, `scripts/view/world_layer.gd`, `scripts/view/post_match_graphs.gd`, `tools/sim/run_sim.gd`, `tools/sim/experiment.gd`, `tools/sim/tune.py`, `tools/validate_data.gd`, `data/ages/age_2.tres`, `data/ages/age_4.tres`, `data/ai/personalities/*.tres`
- Test: `tests/test_economy.gd`, `tests/test_evolution.gd`, `tests/test_data.gd`, `tests/test_match.gd`

**Interfaces:**
- Produces: `MatchRunner.run(data: GameData, left: Dictionary, right: Dictionary, seed: int, start_age := 1) -> Dictionary` (no `random_doctrines`, result has no `doctrines`); `MatchSim.unit_price(side, def)` returns `float(def.cost)`; `SimSide.is_evolving()` is `evolve_left > 0.0`.

- [ ] **Step 1: Update the tests first**

`tests/test_economy.gd`: delete the whole `func test_doctrine_costs()`.

`tests/test_data.gd`: delete the whole `func test_doctrine_offers_at_2_and_4()`.

`tests/test_match.gd` `test_determinism`: change both calls `MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"rusher"}, 42, true)` → `MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"rusher"}, 42)`.

`tests/test_evolution.gd` — replace `test_evolve_transition_and_base_percentage` with:

```gdscript
func test_evolve_transition_and_base_percentage() -> void:
	var sim := new_sim()
	var s := sim.sides[0]
	s.base_hp = 500.0
	var xp := s.xp
	check(sim.evolve(0))
	check_near(s.xp, xp - sim.data.age(2).evolve_cost, 0.01)
	check(s.evolve_left > 0.0 and s.is_evolving())
	run_for(sim, 4.9)
	check_eq(s.age, 1, "still transitioning")
	run_for(sim, 0.2)
	check_eq(s.age, 2)
	check_near(s.base_hp / s.base_max_hp, 0.5, 1e-4, "keeps percentage")
```

In `test_veterancy_buffs_current_age_and_resets` delete the two lines `sim.step()` and `sim.choose_doctrine(0, sim.data.doctrines[&"elite"])` (the test is deleted in Task 4).

In `test_turret_slots_and_sell` replace the lines from `check(not sim.unlock_slot(0), "4 slots max without Bastion")` through `check(sim.unlock_slot(0), "Bastion 5th slot")` with:

```gdscript
	check(not sim.unlock_slot(0), "4 slots max")
```

In `test_queue_paused_while_evolving` change the comment `# evolve 2->3 has no doctrine pick` → `# any age works`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd`
Expected: `FAIL test_evolution::test_evolve_transition_and_base_percentage … still transitioning` or `… expected 2` — the Age 2 doctrine offer pauses the evolution timer.

- [ ] **Step 3: Delete doctrine data, class and the obsolete generator**

```bash
git rm -q scripts/data/doctrine_def.gd scripts/data/doctrine_def.gd.uid data/doctrines/*.tres tools/bootstrap/gen_data.gd tools/bootstrap/gen_data.gd.uid
sed -i -e '/doctrine_def.gd/d' -e '/data\/doctrines\//d' -e '/^doctrine_options = /d' data/ages/age_*.tres
sed -i '/^doctrine_prefs = /d' data/ai/personalities/*.tres
grep -rn "doctrine" data/ || echo "no doctrine references left in data/"
```

Expected last line: `no doctrine references left in data/`.

- [ ] **Step 4: Data classes**

`scripts/data/age_def.gd`: delete the two lines

```gdscript
## Doctrine choice offered when evolving into this age (empty = none).
@export var doctrine_options: Array[DoctrineDef] = []
```

`scripts/data/game_data.gd`: delete `var doctrines: Dictionary = {}      # StringName -> DoctrineDef` and the two lines

```gdscript
	for r in _load_dir(root + "/doctrines"):
		gd.doctrines[r.id] = r
```

`scripts/data/ai_personality_def.gd`: delete the final group:

```gdscript
@export_group("Doctrines")
## Preferred doctrine ids; empty = random (the harness randomises).
@export var doctrine_prefs: Array[StringName] = []
```

`scripts/data/ai_difficulty_def.gd`: change the comment `## 0 = ignores composition, 1 = reacts to majority role, 2 = matrix-aware, 3 = + doctrine counters.` → `## 0 = ignores composition, 1 = reacts to majority role, 2+ = counters every enemy role.`

- [ ] **Step 5: SimSide / SimUnit**

`scripts/sim/sim_side.gd`: delete `var awaiting_doctrine: bool = false`, `var doctrines: Array[DoctrineDef] = []`, and the whole `func has_doctrine(...)`. Change the `queue_paid` comment to `## Gold paid for each queued unit, parallel to \`queue\`.` Replace `is_evolving` and `max_turret_slots` with:

```gdscript
func is_evolving() -> bool:
	return evolve_left > 0.0


func max_turret_slots() -> int:
	return 4
```

`scripts/sim/sim_unit.gd`: change `## Damage before veterancy (doctrine multipliers baked in at spawn).` → `## Damage per hit before veterancy.`

- [ ] **Step 6: MatchSim**

Replace `unit_price`:

```gdscript
func unit_price(_side: int, def: UnitDef) -> float:
	return float(def.cost)
```

Delete the whole `func choose_doctrine(...)` and the whole `func _doctrine_pending(...)`.

Replace the start of `_evolution` (everything before `s.evolve_left -= dt`) with:

```gdscript
func _evolution(s: SimSide, dt: float) -> void:
	if s.evolve_left <= 0.0:
		return
```

In `_spawn` replace

```gdscript
	var hp_mult := 1.0
	var dmg_mult := 1.0
	for d in s.doctrines:
		hp_mult *= d.unit_hp_mult
		dmg_mult *= d.unit_damage_mult
	u.vet_rank = s.vet_ranks if def.age == s.age else 0
	var vet := 1.0 + rules.veterancy_bonus * u.vet_rank
	u.max_hp = def.hp * hp_mult * vet
	u.hp = u.max_hp
	u.base_damage = def.damage * dmg_mult
```

with

```gdscript
	u.vet_rank = s.vet_ranks if def.age == s.age else 0
	var vet := 1.0 + rules.veterancy_bonus * u.vet_rank
	u.max_hp = def.hp * vet
	u.hp = u.max_hp
	u.base_damage = def.damage
```

In `_hit_structures` delete `var own := sides[u.side]` and

```gdscript
		for d in own.doctrines:
			raw *= d.siege_structure_mult
```

In `_turrets_act` delete

```gdscript
		for d in s.doctrines:
			mult *= d.turret_damage_mult
```

- [ ] **Step 7: AI, runner, jobs, harness tools**

`scripts/ai/utility_ai.gd`: delete the four lines declaring `random_doctrines` and `forced_doctrines` (with their `##` comments); in `update()` delete

```gdscript
	# The AI "chooses instantly" (GDD §13.5), independent of its decision interval.
	if s.awaiting_doctrine:
		sim.choose_doctrine(side, _pick_doctrine(sim))
```

and change the first line of `update()` from `var s := sim.sides[side]` to nothing (delete it — it is now unused). Delete the whole `func _pick_doctrine(...)`.

`scripts/sim/match_runner.gd`: change the doc comment to `## Returns {winner, duration, escalated, age_times: [PackedFloat32Array x2], final_ages, log}.`, the signature to `static func run(data: GameData, left: Dictionary, right: Dictionary, seed: int, start_age := 1) -> Dictionary:`, delete the lines `ai.random_doctrines = ...` and `ai.forced_doctrines = ...`, delete the block

```gdscript
	var docs := []
	for s in sim.sides:
		var ids := []
		for d in s.doctrines:
			ids.append(d.id)
		docs.append(ids)
```

and delete `"doctrines": docs,` from the returned dictionary.

`scripts/sim/sim_jobs.gd`: doc line `## Job: {suite, left, right, left_diff, right_diff, seed, random_doctrines, left_docs, right_docs, pair_a}` → `## Job: {suite, left, right, left_diff, right_diff, seed, pair_a, start_age}`; example `--set=doctrines/horde.unit_cost_mult=0.75` → `--set=rules.bounty_fraction=0.4`. In `run_job` replace the first three lines with:

```gdscript
	var left := {"personality": StringName(job.left), "difficulty": StringName(job.get("left_diff", "hard"))}
	var right := {"personality": StringName(job.right), "difficulty": StringName(job.get("right_diff", "hard"))}
	var r := MatchRunner.run(data, left, right, int(job.seed), int(job.get("start_age", 1)))
```

delete

```gdscript
	var docs := []
	for side_docs in r.doctrines:
		docs.append(side_docs.map(func(d): return String(d)))
```

and `"doctrines": docs,`.

`tools/sim/run_sim.gd`: delete the whole doctrine block from the comment `# Only count a doctrine against the opponent's different pick…` through `checks.append(_check("Balance", "Win rate of each doctrine …", doc_ok))`. Change `_series("mirror", "tactician", "tactician", matches * 3, true)` → `_series("mirror", "tactician", "tactician", matches * 3)`. Replace `_series` with:

```gdscript
func _series(suite: String, a: String, b: String, n: int) -> void:
	for k in n:
		_seed_counter += 1
		# Alternate sides so any left/right asymmetry cancels out.
		var a_left := k % 2 == 0
		_jobs.append({"suite": suite, "left": a if a_left else b, "right": b if a_left else a,
			"seed": base_seed * 100003 + _seed_counter, "pair_a": 0 if a_left else 1})
```

Change `"Turtle vs. Turtle, both Bastion"` → `"Turtle vs. Turtle"`.

`tools/sim/experiment.gd`: header option line → `## Options: --a=/--b= personality ids, --diff-a=/--diff-b= difficulty, --start-age=N, --n=matches, --seed=S, --workers=K,`; delete `var docs_a := []`, `var docs_b := []`, `var random_docs := false`, the three parse lines for `--docs-a=`, `--docs-b=`, `--random-docs`; in the job dictionary delete `"left_docs": docs_a if a_left else docs_b, "right_docs": docs_b if a_left else docs_a,` and `"random_doctrines": random_docs, `.

`tools/sim/tune.py`: delete the `PARAMS` rows `elite_cost`, `horde_cost`, `bastion`, `siegecraft`, and the line `    l += sum(band(v, 0.4, 0.6, 0.05) for v in m.get("doctrines", {}).values())`.

`tools/validate_data.gd`: delete

```gdscript
		for d in a.doctrine_options:
			_check(d.pick_age == a.index, "doctrine %s pick_age" % d.id)
```

and

```gdscript
		for pref in p.doctrine_prefs:
			_check(gd.doctrines.has(pref), "personality %s doctrine pref %s exists" % [id, pref])
```

- [ ] **Step 8: View**

`scripts/view/match_hud.gd`:
- delete vars `_doc_labels`, `_doctrine_panel`, `_doctrine_box`;
- in `_build_top` delete `_doc_labels.append(_label(row, "", 13, Color(1, 1, 1, 0.7)))`;
- in `_ready` delete `_build_doctrine()`; delete the whole `func _build_doctrine()` and `func _update_doctrine()`;
- in `_process` delete the three lines `var names := []`, `for d in s.doctrines: names.append(d.display_name)`, `_doc_labels[i].text = " · ".join(names)` and the line `_update_doctrine()`; change `_evolve.text = "Evolving…" if me.awaiting_doctrine else "Evolving… %.1fs" % me.evolve_left` → `_evolve.text = "Evolving… %.1fs" % me.evolve_left`;
- header comment: remove `, doctrine` from the line listing panels (keep the rest).

`scripts/view/world_layer.gd`: in `_draw_base` delete the comment `# Doctrine banners hang on the base…` and the whole `for i in s.doctrines.size():` loop (7 lines).

`scripts/view/post_match_graphs.gd`: `{"evolve": "E", "ability": "A", "doctrine": "D"}` → `{"evolve": "E", "ability": "A"}`; in the header comment `abilities and doctrines` → `and abilities`.

- [ ] **Step 9: Reimport, validate, test**

```bash
timeout 150 "$GODOT" --headless --path . --import > /dev/null 2>&1; echo "import $?"
timeout 60 "$GODOT" --headless --path . -s tools/validate_data.gd
timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd
grep -rn "doctrine\|Doctrine" scripts tools tests data --include=*.gd --include=*.tres --include=*.py || echo "clean"
```

Expected: `data OK: ...`; `N tests, 0 failures`; `clean`. Restore any `.import` files that only changed line endings: `git checkout -- assets reports` if `git status` lists them.

- [ ] **Step 10: Smoke-run the game**

Run: `timeout 90 "$GODOT" --path . --resolution 1920x1080 -- --autoplay --speed=12 --screenshot="$TMPDIR/doctrines.png" --after=20` (on Windows use the scratchpad path).
Expected: `screenshot saved: …` and no `SCRIPT ERROR` lines.

- [ ] **Step 11: Commit**

```bash
git add -A scripts tools tests data
git commit -m "Remove doctrines (GDD v3 §9)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Remove stances and the rally line

**Files:**
- Modify: `scripts/sim/match_sim.gd`, `scripts/sim/sim_side.gd`, `scripts/ai/utility_ai.gd`, `scripts/data/ai_personality_def.gd`, `data/ai/personalities/*.tres`, `scripts/view/match_view.gd`, `scripts/view/world_layer.gd`, `scripts/view/match_hud.gd`, `tools/sim/tune.py`
- Test: `tests/test_case.gd`, `tests/test_combat.gd`, `tests/test_match.gd`

**Interfaces:**
- Produces: `TestCase.run_pinned(sim: MatchSim, seconds: float, pinned: Array) -> void` — steps like `run_for` and puts each pinned unit back at its starting `progress` after every step. `MatchSim.set_stance` no longer exists.

- [ ] **Step 1: Add the test helper and rewrite stance-based tests**

Append to `tests/test_case.gd`:

```gdscript


## Like run_for, but each unit in `pinned` is put back at its starting progress after every step.
func run_pinned(sim: MatchSim, seconds: float, pinned: Array) -> void:
	var at := pinned.map(func(u): return u.progress)
	for i in roundi(seconds / sim.rules.tick_dt):
		sim.step()
		for k in pinned.size():
			pinned[k].progress = at[k]
```

`tests/test_combat.gd`: replace `test_allies_do_not_overlap` with

```gdscript
func test_allies_do_not_overlap() -> void:
	var sim := new_sim()
	var front := place(sim, 0, "heavy", 500.0)
	var back := place(sim, 0, "vanguard", 400.0)
	run_pinned(sim, 5.0, [front])
	check(back.progress <= front.progress - sim.rules.unit_spacing + 0.01, "spacing held")
```

delete the whole `test_hold_stops_at_rally_line`; in `test_ranged_siege_min_range` replace the two lines `sim.set_stance(1, &"hold", sim.to_world(1, e.progress))` and `run_for(sim, 4.0)` with `run_pinned(sim, 4.0, [e])`; in `test_sentry_targets_most_advanced` replace `sim.set_stance(0, &"hold", 0.0)` and `run_for(sim, 0.2)` with `run_pinned(sim, 0.2, [near, far])`.

`tests/test_match.gd`: replace `test_front_line_rules` with

```gdscript
func test_front_line_rules() -> void:
	var sim := new_sim()
	sim.step()
	check_near(sim.front_x, 1200.0, 0.01, "holds when empty")
	var a := place(sim, 0, "vanguard", 400.0)
	sim.step()
	check_near(sim.front_x, sim.rules.lane_length, 0.01, "no enemy units -> enemy gate")
	var b := place(sim, 1, "vanguard", 400.0)
	sim.step()
	check_near(sim.front_x, (a.progress + sim.rules.lane_length - b.progress) * 0.5, 0.01, "midpoint of the two fronts")
	a.hp = 0.0
	sim._remove_dead()
	sim.step()
	check_near(sim.front_x, 0.0, 0.01)
```

In `test_push_momentum` delete `sim.set_stance(0, &"hold", 1500.0)`. In `test_ability_spends_momentum_and_cools_down` delete `sim.set_stance(1, &"hold", sim.to_world(1, 1000.0))` and change `run_for(sim, 1.0)` → `run_pinned(sim, 1.0, [e])`.

- [ ] **Step 2: Run tests (helper compiles, rewritten tests pass on the old rules)**

Run: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd`
Expected: `0 failures`. The tests no longer depend on stances, so they must keep passing once stances are removed in Steps 3–4.

- [ ] **Step 3: Remove stance from sim and AI**

`scripts/sim/match_sim.gd`: delete `s.rally_progress = rules.lane_length * 0.35` in `_init`; delete the whole `func set_stance(...)`; in `_units_act` change the comment `# Movement is code-driven; blocked by the ally ahead, the nearest enemy and a Hold rally line.` → `# Movement is code-driven; blocked by the ally ahead and the nearest enemy.` and delete

```gdscript
				if s.stance == &"hold" and not attacking:
					limit = minf(limit, s.rally_progress)
```

`scripts/sim/sim_side.gd`: delete `var stance: StringName = &"advance"`, the comment `## Hold stance rally line, as progress from own gate.` and `var rally_progress: float = 800.0`.

`scripts/ai/utility_ai.gd`: delete `var _released_hold := false`, `var _pushing := false`, `var _staged_since := 0.0`; in `_decide` delete `_manage_stance(sim, pressure)`; delete the whole `func _manage_stance(...)`.

`scripts/data/ai_personality_def.gd`: delete the whole `@export_group("Stance")` block (`uses_hold`, `hold_release_seconds`, `push_ratio` with their comments).

```bash
sed -i -e '/^uses_hold = /d' -e '/^hold_release_seconds = /d' -e '/^push_ratio = /d' data/ai/personalities/*.tres
```

`tools/sim/tune.py`: delete the `PARAMS` rows `push_ratio` and `rusher_hold`.

- [ ] **Step 4: Remove stance from the view**

`scripts/view/match_view.gd`: delete the `elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and sim.sides[0].stance == &"hold" and event.shift_pressed:` branch (2 lines), the `KEY_S:` case (2 lines), and the whole `func toggle_stance()`.

`scripts/view/world_layer.gd`: delete the `# Hold rally line flags.` block (the `for s in sim.sides:` loop with `if s.stance == &"hold":`, 7 lines).

`scripts/view/match_hud.gd`: delete `var _stance: Button`, the two lines creating `_stance` in `_build_commands`, and `_stance.text = ...` in `_process`.

- [ ] **Step 5: Validate, test, grep**

```bash
timeout 150 "$GODOT" --headless --path . --import > /dev/null 2>&1
timeout 60 "$GODOT" --headless --path . -s tools/validate_data.gd
timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd
grep -rn "stance\|rally\|uses_hold\|push_ratio" scripts tools tests data --include=*.gd --include=*.tres --include=*.py || echo "clean"
```

Expected: `data OK`, `0 failures`, `clean`.

- [ ] **Step 6: Commit**

```bash
git add -A scripts tools tests data
git commit -m "Remove Hold/Advance stances and the rally line (GDD v3 §10)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Remove veterancy

**Files:**
- Modify: `scripts/data/rules_def.gd`, `data/rules.tres`, `scripts/data/age_def.gd`, `data/ages/*.tres`, `scripts/sim/sim_side.gd`, `scripts/sim/sim_unit.gd`, `scripts/sim/match_sim.gd`, `scripts/ai/utility_ai.gd`, `scripts/data/ai_personality_def.gd`, `data/ai/personalities/*.tres`, `tools/validate_data.gd`, `tools/sim/tune.py`, `tools/export_csv.gd`, `scripts/view/match_hud.gd`, `scripts/view/match_view.gd`, `scripts/view/world_layer.gd`
- Test: `tests/test_evolution.gd`

**Interfaces:**
- Produces: `SimUnit.base_damage` is the per-hit damage (no `damage_mult()`); `AiPersonalityDef.age_plan` ∈ `{"balanced", "fast"}`.

- [ ] **Step 1: Delete the veterancy test**

In `tests/test_evolution.gd` delete the whole `func test_veterancy_buffs_current_age_and_resets()`.

- [ ] **Step 2: Data and data classes**

`scripts/data/rules_def.gd`: rename `@export_group("Evolution & veterancy")` → `@export_group("Evolution")` and delete the `veterancy_fractions` and `veterancy_bonus` exports. `scripts/data/age_def.gd`: delete the `veterancy_base_xp` export and its comment. `scripts/data/ai_personality_def.gd`: replace the Evolution group body with

```gdscript
@export_group("Evolution")
## "balanced" (Hard+ waits out pressure before evolving) | "fast" (evolve the moment XP allows)
@export_enum("balanced", "fast") var age_plan: String = "balanced"
```

```bash
sed -i -e '/^veterancy_fractions = /d' -e '/^veterancy_bonus = /d' data/rules.tres
sed -i '/^veterancy_base_xp = /d' data/ages/age_*.tres
sed -i -e 's/^age_plan = "strong"/age_plan = "balanced"/' -e '/^balanced_vet_ranks = /d' data/ai/personalities/*.tres
```

- [ ] **Step 3: Sim**

`scripts/sim/sim_side.gd`: delete `var vet_ranks: int = 0`.

`scripts/sim/sim_unit.gd`: delete `var vet_rank: int = 0` and the whole `func damage_mult(...)`; comment `## Damage per hit before veterancy.` → `## Damage per hit.`

`scripts/sim/match_sim.gd`: delete `func veterancy_cost`, `func can_buy_veterancy`, `func buy_veterancy`; in `_evolution` delete `s.vet_ranks = 0`; in `_spawn` replace the four lines from `u.vet_rank = …` to `u.max_hp = def.hp * vet` with `u.max_hp = def.hp`; in `_units_act` change `u.base_damage * u.damage_mult(rules.veterancy_bonus)` → `u.base_damage`; in `_hit_structures` change `u.base_damage * u.damage_mult(rules.veterancy_bonus) * rules.matrix(...)` → `u.base_damage * rules.matrix(u.def.damage_type, "structure")`.

- [ ] **Step 4: AI**

Replace `_spend_xp` in `scripts/ai/utility_ai.gd` with:

```gdscript
func _spend_xp(sim: MatchSim, pressure: bool) -> void:
	var s := sim.sides[side]
	if not sim.can_evolve(side):
		return
	# Evolving under pressure is a gamble (5 s with a paused queue). Smarter AIs wait it out,
	# unless the enemy is already an age ahead.
	var enemy := sim.sides[sim.enemy_of(side)]
	if pressure and difficulty.counter_level >= 2 and personality.age_plan != "fast" \
			and enemy.age <= s.age and s.base_hp / s.base_max_hp > 0.25:
		return
	sim.evolve(side)
```

- [ ] **Step 5: Validator, tuner, view**

`tools/validate_data.gd`: delete `_check(r.veterancy_fractions.size() == 3, "three veterancy ranks")` and `_check(a.veterancy_base_xp > 0, tag + " veterancy base")`; change `p.age_plan in ["balanced", "fast", "strong"]` → `p.age_plan in ["balanced", "fast"]`.

`tools/sim/tune.py`: delete the `vet_bonus` PARAMS row.

`tools/export_csv.gd`: in the `"age"` CSV line replace `"vet_base=%d" % age.veterancy_base_xp` with `""`.

`scripts/view/match_hud.gd`: delete `var _vet: Button`, the two lines creating `_vet` in `_build_commands`, and the three `_vet.…` lines in `_process`. `scripts/view/match_view.gd`: delete the `KEY_V:` case (2 lines). `scripts/view/world_layer.gd`: in `_draw_bars` delete the `if u.vet_rank > 0:` block (3 lines); change the `_draw_overlay` doc comment `## HP bars, veterancy chevrons and the ability aim marker, …` → `## HP bars and the ability aim marker, drawn over the outlined units.`

- [ ] **Step 6: Validate, test, grep**

```bash
timeout 150 "$GODOT" --headless --path . --import > /dev/null 2>&1
timeout 60 "$GODOT" --headless --path . -s tools/validate_data.gd
timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd
grep -rn "veteran\|vet_rank\|vet_bonus\|\"strong\"" scripts tools tests data --include=*.gd --include=*.tres --include=*.py || echo "clean"
```

Expected: `data OK`, `0 failures`, `clean`.

- [ ] **Step 7: Commit**

```bash
git add -A scripts tools tests data
git commit -m "Remove veterancy (GDD v3 §4.5)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: XP skills with auto-targeted shapes (momentum removed)

**Files:**
- Create: `data/abilities/rockfall.tres`, `data/ai/personalities/skill_heavy.tres`, `tests/test_skills.gd`
- Delete: `data/abilities/shieldwall.tres`, `data/ai/personalities/strong_age.tres`
- Modify: `scripts/data/ability_def.gd`, `data/abilities/{stampede,volley,bombardment,cannonade,starfall}.tres`, `data/ages/age_2.tres`, `data/races/{human,elf,dwarf}.tres`, `scripts/data/rules_def.gd`, `data/rules.tres`, `scripts/data/unit_def.gd`, `data/units/*.tres`, `scripts/data/ai_difficulty_def.gd`, `data/ai/difficulties/*.tres`, `scripts/data/ai_personality_def.gd`, `scripts/sim/sim_side.gd`, `scripts/sim/sim_unit.gd`, `scripts/sim/match_sim.gd`, `scripts/sim/match_log.gd`, `scripts/ai/utility_ai.gd`, `tools/validate_data.gd`, `tools/sim/run_sim.gd`, `tools/sim/tune.py`, `tools/export_csv.gd`, `scripts/view/match_view.gd`, `scripts/view/world_layer.gd`, `scripts/view/fx_layer.gd`, `scripts/view/match_hud.gd`
- Test: `tests/test_skills.gd`, `tests/test_match.gd`, `tests/test_economy.gd`, `tests/test_combat.gd`, `tests/test_data.gd`

**Interfaces:**
- Produces (MatchSim):
  - `ability_cost(side: int) -> float` — XP cost of the side's current-era skill.
  - `can_fire_ability(side: int) -> bool` — not over, cooldown ≤ 0, `xp >= ability_cost`.
  - `ability_zone(side: int) -> Array` — `[lo, hi]` world x where the skill would land now, or `[]` if nothing to hit.
  - `ability_zone_value(side: int) -> float` — gold value (`cost_paid`) of enemy units inside that zone.
  - `fire_ability(side: int) -> bool` — no target argument; charges XP, sets `ability_cooldown`, emits `{"type": "ability", side, ability, x, lo, hi}`; when all pulses have resolved emits `{"type": "ability_end", side, ability, kills}`.
- Produces: `AbilityDef.shape: String` (`"area"|"strip"|"sweep"`), `AbilityDef.xp_cost: int`; `AiDifficultyDef.skill_min_value: float`; `AiPersonalityDef.skill_eager: bool`; harness metric key `fast_vs_skill`.

- [ ] **Step 1: Write the failing skill tests**

Create `tests/test_skills.gd`:

```gdscript
extends TestCase


func test_costs_xp_and_cools_down() -> void:
	var sim := new_sim(false)
	var e := place(sim, 1, "vanguard", 1000.0)
	e.hp = 1e9
	e.max_hp = 1e9
	var def := sim.data.age(1).ability
	sim.sides[0].xp = def.xp_cost - 1
	check(not sim.fire_ability(0), "not enough XP")
	sim.sides[0].xp = def.xp_cost * 2
	check(sim.fire_ability(0))
	check_near(sim.sides[0].xp, def.xp_cost, 0.01, "charged once")
	check(not sim.fire_ability(0), "cooldown")
	run_pinned(sim, sim.rules.ability_cooldown + 0.1, [e])
	check(sim.fire_ability(0), "ready again")


func test_needs_a_target() -> void:
	var sim := new_sim()
	check(not sim.fire_ability(0), "no enemy units")
	check_near(sim.sides[0].xp, 99999.0, 0.01, "nothing charged")
	check_near(sim.sides[0].ability_cooldown, 0.0, 0.001, "no cooldown started")


func test_sweep_hits_every_enemy_on_the_lane() -> void:
	var sim := new_sim()
	check_eq(sim.data.age(1).ability.shape, "sweep")
	var near := place(sim, 1, "vanguard", 2000.0)
	var far := place(sim, 1, "vanguard", 100.0)
	for u in [near, far]:
		u.hp = 1e6
		u.max_hp = 1e6
	check(sim.fire_ability(0))
	run_pinned(sim, 5.0, [near, far])
	check(near.hp < near.max_hp, "unit near our gate hit")
	check(far.hp < far.max_hp, "unit at their gate hit")


func test_area_lands_on_densest_group() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	check_eq(sim.data.age(2).ability.shape, "area")
	var lone := place(sim, 1, "vanguard", 1600.0, 2)
	var pack := [place(sim, 1, "vanguard", 600.0, 2), place(sim, 1, "vanguard", 606.0, 2), place(sim, 1, "vanguard", 612.0, 2)]
	var zone := sim.ability_zone(0)
	check_eq(zone.size(), 2)
	var lone_x := sim.to_world(1, lone.progress)
	check(lone_x < zone[0] or lone_x > zone[1], "lone unit outside")
	for u in pack:
		var x := sim.to_world(1, u.progress)
		check(x >= zone[0] and x <= zone[1], "pack inside")
	check_near(sim.ability_zone_value(0), 3.0 * pack[0].cost_paid, 0.01, "value = the pack")


func test_strip_starts_at_enemy_front() -> void:
	var sim := new_sim()
	sim.sides[0].age = 3
	sim.sides[1].age = 3
	var def := sim.data.age(3).ability
	check_eq(def.shape, "strip")
	var front := place(sim, 1, "vanguard", 900.0, 3)
	place(sim, 1, "vanguard", 500.0, 3)
	var zone := sim.ability_zone(0)
	var fx := sim.to_world(1, front.progress)
	check_near(zone[0], fx, 0.01, "starts at the front unit")
	check_near(zone[1], fx + def.width, 0.01, "extends toward the enemy base")
	place(sim, 0, "vanguard", 700.0, 3)
	var z1 := sim.ability_zone(1)
	check_near(z1[1], 700.0, 0.01, "mirrored for the right side")
	check_near(z1[0], 700.0 - def.width, 0.01)


func test_skills_never_hit_structures() -> void:
	var sim := new_sim()
	sim.build_turret(1, 0, sim.data.turret_for_kind(1, "sentry"))
	var t: SimTurret = sim.sides[1].turrets[0]
	var e := place(sim, 1, "vanguard", 10.0)
	e.hp = 1e9
	e.max_hp = 1e9
	var base := sim.sides[1].base_hp
	check(sim.fire_ability(0))
	run_pinned(sim, 3.0, [e])
	check_near(t.hp, t.max_hp, 0.01, "turret untouched")
	check_near(sim.sides[1].base_hp, base, 0.01, "base untouched")


func test_reports_kills() -> void:
	var sim := new_sim()
	var weak := place(sim, 1, "vanguard", 1500.0)
	weak.hp = 1.0
	check(sim.fire_ability(0))
	run_pinned(sim, 3.0, [weak])
	var ends := sim.match_log.events.filter(func(ev): return ev.type == "ability_end")
	check_eq(ends.size(), 1)
	check_eq(ends[0].kills, 1)


func test_ai_fires_skills() -> void:
	var gd := GameData.get_default()
	var r := MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"skill_heavy"}, 11)
	check(r.log.events.any(func(ev): return ev.type == "ability"), "a skill was fired")
```

In `tests/test_data.gd` add:

```gdscript


func test_every_skill_has_shape_and_cost() -> void:
	for a in GameData.get_default().ages:
		var ab := a.ability
		check(ab.shape in ["area", "strip", "sweep"], "age %d shape" % a.index)
		check(ab.xp_cost > 0, "age %d xp cost" % a.index)
		check(ab.pulses >= 1 and ab.damage > 0, "age %d pulses/damage" % a.index)
```

In `tests/test_match.gd` delete `test_push_momentum` and `test_ability_spends_momentum_and_cools_down`. In `tests/test_economy.gd` rename `test_kill_pays_bounty_xp_momentum` → `test_kill_pays_bounty_and_xp` and delete its line `check_near(sim.sides[0].momentum, 3.0, 0.01, "heavy kill momentum")`. In `tests/test_combat.gd` rename `test_base_damage_gives_xp_and_defender_momentum` → `test_base_damage_gives_xp` and delete its line `check_near(r.momentum, …)`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd`
Expected: `FAIL test_skills.gd (does not compile)` or failures in `test_skills` / `test_every_skill_has_shape_and_cost`.

- [ ] **Step 3: AbilityDef and skill data**

Replace `scripts/data/ability_def.gd` with:

```gdscript
class_name AbilityDef
extends Resource
## An era's special skill (GDD §7). Fired with one click, aimed automatically by its shape, paid in XP.
## Skills hit enemy units only, never structures.

@export var id: StringName
@export var display_name: String
@export var age: int = 1
## area: centred on the densest enemy group. strip: from the enemy's front unit back toward their base.
## sweep: travels from our gate to the enemy gate, one slice per pulse.
@export_enum("area", "strip", "sweep") var shape: String = "area"
## XP spent to fire it.
@export var xp_cost: int = 0
## Zone length in px for area and strip (a sweep always covers the whole lane).
@export var width: float = 300.0
## Delay between firing and the first pulse (telegraph).
@export var telegraph: float = 0.5
@export var pulses: int = 1
@export var pulse_interval: float = 0.0
@export var damage: float = 0.0
@export_enum("slash", "pierce", "blast", "siege") var damage_type: String = "blast"
@export var knockback: float = 0.0
```

Write each ability file in full (same header for all; `N` is the file's own values):

`data/abilities/stampede.tres`:
```
[gd_resource type="Resource" script_class="AbilityDef" format=3]

[ext_resource type="Script" path="res://scripts/data/ability_def.gd" id="1_ab"]

[resource]
script = ExtResource("1_ab")
id = &"stampede"
display_name = "Stampede"
age = 1
shape = "sweep"
xp_cost = 60
telegraph = 0.5
pulses = 8
pulse_interval = 0.15
damage = 80.0
damage_type = "slash"
knockback = 60.0
```

`data/abilities/rockfall.tres`:
```
[gd_resource type="Resource" script_class="AbilityDef" format=3]

[ext_resource type="Script" path="res://scripts/data/ability_def.gd" id="1_ab"]

[resource]
script = ExtResource("1_ab")
id = &"rockfall"
display_name = "Rockfall"
age = 2
shape = "area"
xp_cost = 75
width = 260.0
telegraph = 0.8
pulses = 3
pulse_interval = 0.35
damage = 90.0
damage_type = "blast"
```

`data/abilities/volley.tres`:
```
[gd_resource type="Resource" script_class="AbilityDef" format=3]

[ext_resource type="Script" path="res://scripts/data/ability_def.gd" id="1_ab"]

[resource]
script = ExtResource("1_ab")
id = &"volley"
display_name = "Volley"
age = 3
shape = "strip"
xp_cost = 175
width = 350.0
telegraph = 0.5
pulses = 3
pulse_interval = 1.0
damage = 123.0
damage_type = "pierce"
```

`data/abilities/bombardment.tres`:
```
[gd_resource type="Resource" script_class="AbilityDef" format=3]

[ext_resource type="Script" path="res://scripts/data/ability_def.gd" id="1_ab"]

[resource]
script = ExtResource("1_ab")
id = &"bombardment"
display_name = "Bombardment"
age = 4
shape = "sweep"
xp_cost = 275
telegraph = 0.6
pulses = 8
pulse_interval = 0.3
damage = 480.0
damage_type = "blast"
knockback = 12.0
```

`data/abilities/cannonade.tres`:
```
[gd_resource type="Resource" script_class="AbilityDef" format=3]

[ext_resource type="Script" path="res://scripts/data/ability_def.gd" id="1_ab"]

[resource]
script = ExtResource("1_ab")
id = &"cannonade"
display_name = "Cannonade"
age = 5
shape = "strip"
xp_cost = 700
width = 500.0
telegraph = 1.5
pulses = 5
pulse_interval = 0.3
damage = 912.0
damage_type = "blast"
knockback = 12.0
```

`data/abilities/starfall.tres`:
```
[gd_resource type="Resource" script_class="AbilityDef" format=3]

[ext_resource type="Script" path="res://scripts/data/ability_def.gd" id="1_ab"]

[resource]
script = ExtResource("1_ab")
id = &"starfall"
display_name = "Starfall"
age = 6
shape = "area"
xp_cost = 1000
width = 200.0
telegraph = 1.5
pulses = 1
damage = 9904.0
damage_type = "blast"
```

```bash
git rm -q data/abilities/shieldwall.tres
sed -i 's|res://data/abilities/shieldwall.tres|res://data/abilities/rockfall.tres|' data/ages/age_2.tres
sed -i 's/"shieldwall": "[^"]*"/"rockfall": "Rockfall"/' data/races/human.tres
sed -i 's/"shieldwall": "[^"]*"/"rockfall": "Stone Rain"/' data/races/elf.tres
sed -i 's/"shieldwall": "[^"]*"/"rockfall": "Boulder Toss"/' data/races/dwarf.tres
grep -rn "shieldwall" data || echo "clean"
```

- [ ] **Step 4: Remove momentum from data and classes**

`scripts/data/rules_def.gd`: replace the `@export_group("Momentum & abilities")` block with

```gdscript
@export_group("Skills")
## Seconds before the same side can fire its skill again.
@export var ability_cooldown: float = 20.0
```

`scripts/data/unit_def.gd`: delete `momentum_on_kill` and its comment.

```bash
sed -i -e '/^momentum_cap = /d' -e '/^momentum_push_rate = /d' -e '/^momentum_per_base_pct = /d' -e '/^ability_cost = /d' -e 's/^ability_cooldown = .*/ability_cooldown = 20.0/' data/rules.tres
sed -i '/^momentum_on_kill = /d' data/units/*.tres
```

`scripts/sim/sim_side.gd`: delete `var momentum: float = 0.0`. `scripts/sim/sim_unit.gd`: delete `var armour_buff: float = 0.0` and `var armour_buff_until: float = -1.0`. `scripts/sim/match_log.gd`: delete `"momentum": snappedf(s.momentum, 0.1),` and change the sample comment's `{gold, xp, momentum, army, …}` → `{gold, xp, army, …}`.

- [ ] **Step 5: MatchSim skills**

Change the `effects` comment to `## Pending skill pulses: {side, def, lo, hi, next_t, pulse, kills}`.

Replace `can_fire_ability` with:

```gdscript
func ability_cost(side: int) -> float:
	return float(data.age(sides[side].age).ability.xp_cost)


func can_fire_ability(side: int) -> bool:
	var s := sides[side]
	return not is_over() and s.ability_cooldown <= 0.0 and s.xp >= ability_cost(side)
```

Replace `fire_ability` with:

```gdscript
## Fires this side's current-era skill where its shape lands now (PLAN D20). Fails, costing nothing,
## when there is nothing to hit (D21).
func fire_ability(side: int) -> bool:
	if not can_fire_ability(side):
		return false
	var zone := ability_zone(side)
	if zone.is_empty():
		return false
	var s := sides[side]
	var def := data.age(s.age).ability
	s.xp -= def.xp_cost
	s.ability_cooldown = rules.ability_cooldown
	var center: float = (zone[0] + zone[1]) * 0.5
	effects.append({"side": side, "def": def, "lo": zone[0], "hi": zone[1], "next_t": time + def.telegraph, "pulse": 0, "kills": 0})
	_emit({"type": "ability", "side": side, "ability": String(def.id), "x": center, "lo": zone[0], "hi": zone[1]})
	return true


## [lo, hi] in world x where this side's skill would land now, or [] if no enemy unit is on the lane.
func ability_zone(side: int) -> Array:
	var def := data.age(sides[side].age).ability
	var enemy := enemy_of(side)
	var front := _front_unit(enemy)
	if front == null:
		return []
	match def.shape:
		"sweep":
			return [0.0, rules.lane_length]
		"strip":
			# From the enemy's front unit back toward the enemy base.
			var x := to_world(enemy, front.progress)
			return [x, x + def.width] if enemy == RIGHT else [x - def.width, x]
		_:
			var c := _densest_window(enemy, def.width)
			return [c - def.width * 0.5, c + def.width * 0.5]


## Gold value of the enemy units inside this side's skill zone right now.
func ability_zone_value(side: int) -> float:
	var zone := ability_zone(side)
	if zone.is_empty():
		return 0.0
	var enemy := enemy_of(side)
	var v := 0.0
	for u in sides[enemy].units:
		var x := to_world(enemy, u.progress)
		if u.alive() and x >= zone[0] and x <= zone[1]:
			v += u.cost_paid
	return v


## Centre of the `width` window holding the most gold of `of_side`'s units. Candidate windows start or
## end at a unit; the first best window in unit order wins ties (deterministic).
func _densest_window(of_side: int, width: float) -> float:
	var best := NAN
	var best_v := -1.0
	for u in sides[of_side].units:
		var start := to_world(of_side, u.progress)
		for c in [start + width * 0.5, start - width * 0.5]:
			var v := 0.0
			for w in sides[of_side].units:
				if w.alive() and absf(to_world(of_side, w.progress) - c) <= width * 0.5:
					v += w.cost_paid
			if v > best_v:
				best_v = v
				best = c
	return best
```

In `_damage_unit` delete

```gdscript
	if target.armour_buff_until > time:
		dmg /= 1.0 + target.armour_buff
```

In `_on_kill` delete the `s.momentum = …` line. In `damage_base` delete the `s.momentum = …` line.

In `step()` change `_front_and_momentum(dt)` → `_update_front()`, and replace the function with:

```gdscript
func _update_front() -> void:
	var lf := _front_unit(LEFT)
	var rf := _front_unit(RIGHT)
	var lane := rules.lane_length
	if lf == null and rf == null:
		return
	if lf == null:
		front_x = 0.0
	elif rf == null:
		front_x = lane
	else:
		front_x = (lf.progress + lane - rf.progress) * 0.5
```

Replace `_resolve_effects` and `_ability_pulse` with:

```gdscript
func _resolve_effects() -> void:
	var keep: Array[Dictionary] = []
	for e in effects:
		var def: AbilityDef = e.def
		while e.next_t <= time + 1e-6 and e.pulse < def.pulses:
			_ability_pulse(e)
			e.pulse += 1
			e.next_t += def.pulse_interval
		if e.pulse < def.pulses:
			keep.append(e)
		else:
			_emit({"type": "ability_end", "side": e.side, "ability": String(def.id), "kills": e.kills})
	effects = keep


func _ability_pulse(e: Dictionary) -> void:
	var def: AbilityDef = e.def
	var lo: float = e.lo
	var hi: float = e.hi
	if def.shape == "sweep" and def.pulses > 1:
		# Sweeps travel away from the caster, one slice per pulse.
		var slice := (hi - lo) / def.pulses
		var i: int = e.pulse if e.side == LEFT else def.pulses - 1 - e.pulse
		lo = e.lo + slice * i
		hi = lo + slice
	var target_side := enemy_of(e.side)
	if record_fx:
		fx.append({"type": "ability_pulse", "lo": lo, "hi": hi, "side": e.side, "ability": String(def.id)})
	for u in sides[target_side].units:
		if not u.alive():
			continue
		var x := to_world(u.side, u.progress)
		if x < lo or x > hi:
			continue
		_damage_unit(u, def.damage, def.damage_type, e.side)
		if not u.alive():
			e.kills += 1
		elif def.knockback > 0.0:
			u.progress = maxf(0.0, u.progress - def.knockback)
	match_log.count_ability_damage(e.side)
```

- [ ] **Step 6: AI skill use and the skill-heavy archetype**

`scripts/data/ai_difficulty_def.gd`: replace the `aim_level` export and its comment with

```gdscript
## Enemy value (Age 1 gold, scaled by the era cost multiplier) a skill must hit before the AI fires it.
@export var skill_min_value: float = 60.0
```

`scripts/data/ai_personality_def.gd`: add to the Evolution group

```gdscript
## Sim archetype: fire the skill whenever it can hit anything (GDD §11.3).
@export var skill_eager: bool = false
```

```bash
sed -i '/^aim_level = /d' data/ai/difficulties/*.tres
echo 'skill_min_value = 30.0' >> data/ai/difficulties/easy.tres
for d in hard brutal nightmare; do echo 'skill_min_value = 100.0' >> data/ai/difficulties/$d.tres; done
git rm -q data/ai/personalities/strong_age.tres
cat > data/ai/personalities/skill_heavy.tres <<'EOF'
[gd_resource type="Resource" script_class="AiPersonalityDef" format=3]

[ext_resource type="Script" path="res://scripts/data/ai_personality_def.gd" id="1_p"]

[resource]
script = ExtResource("1_p")
id = &"skill_heavy"
display_name = "Skill-heavy Tactician"
sim_only = true
skill_eager = true
EOF
```

`scripts/ai/utility_ai.gd`: in `_decide` change `_try_ability(sim)` → `_try_ability(sim, pressure)` (the `var pressure := _under_pressure(sim)` line is already above it). Replace the whole Abilities section (`_try_ability`, `_best_window`, `_window_value`) with:

```gdscript
# ---------------------------------------------------------------------------
# Skills

func _try_ability(sim: MatchSim, pressure: bool) -> void:
	if not sim.can_fire_ability(side):
		return
	var value := sim.ability_zone_value(side)
	if value <= 0.0:
		return
	if not personality.skill_eager and not pressure:
		if value < difficulty.skill_min_value * sim.rules.age_cost_mult(sim.sides[side].age):
			return
		if _evolve_soon(sim):
			return
	sim.fire_ability(side)


## True if an evolution is due within ~10 s at the current XP rate (spending XP on a skill would delay it).
func _evolve_soon(sim: MatchSim) -> bool:
	var s := sim.sides[side]
	if s.age >= GameData.AGE_COUNT or s.is_evolving():
		return false
	var rate := s.stat_xp_earned / maxf(sim.time, 1.0)
	return (sim.evolve_cost(side) - s.xp) / maxf(rate, 0.01) <= 10.0
```

- [ ] **Step 7: Validator and harness**

`tools/validate_data.gd`: delete `_check(u.momentum_on_kill > 0, ut + " momentum_on_kill")`; after the `ability` check line add

```gdscript
		if a.ability != null:
			var ab := a.ability
			_check(ab.shape in ["area", "strip", "sweep"] and ab.xp_cost > 0 and ab.pulses >= 1 and ab.damage > 0, tag + " skill shape/cost/pulses/damage")
			_check(ab.shape == "sweep" or ab.width > 0, tag + " skill width")
```

`tools/sim/run_sim.gd`: `_series("fast_strong", "fast_age", "strong_age", matches * 2)` → `_series("fast_skill", "fast_age", "skill_heavy", matches * 2)`; `var fast_strong: Array = by.fast_strong` → `var fast_skill: Array = by.fast_skill`; `var main_pool := round_robin + mirror + fast_strong` → `… + fast_skill`; replace the Decisions block with:

```gdscript
	var fast_rate := 0.0
	for r in fast_skill:
		fast_rate += _score(r, r.pair_a)
	fast_rate /= fast_skill.size()
	metrics["fast_vs_skill"] = fast_rate
	checks.append(_check("Decisions", "Fast-age vs. skill-heavy Tactician (fast-age win rate)", "40–60%", _pct(fast_rate), fast_rate >= 0.4 and fast_rate <= 0.6))
```

In `_markdown` change `"## Match length distribution (round robin + mirror + fast/strong)"` → `"## Match length distribution (round robin + mirror + fast/skill)"`.

`tools/sim/tune.py`: in `PERSONALITIES` replace `"strong_age"` with `"skill_heavy"`; in `loss` change `m["fast_vs_strong"]` → `m["fast_vs_skill"]`.

`tools/export_csv.gd`: replace the `"ability"` CSV line with

```gdscript
		f.store_csv_line(PackedStringArray(["ability", age.index, ab.id, ab.display_name, ab.shape, "", ab.damage_type, ab.xp_cost, "", ab.damage, ab.pulse_interval, ab.width, "", "", "", "pulses=%d telegraph=%s knockback=%s" % [ab.pulses, ab.telegraph, ab.knockback]]))
```

- [ ] **Step 8: View — one-click skill, no aiming**

`scripts/view/match_view.gd`:
- delete `var aiming := false` and `var aim_x := 0.0`; delete the whole `func begin_aim()`;
- in `_process` delete `if aiming:` and `aim_x = clampf(...)`;
- in `_unhandled_input` replace the right-button branch body with `_drag_pan = event.pressed` (delete the two `if event.pressed and aiming:` lines) and delete the whole `elif event.button_index == MOUSE_BUTTON_LEFT and aiming and not event.pressed:` branch (4 lines);
- `_hotkey`: `KEY_SPACE:` body → `hud.feedback(sim.fire_ability(0))`; `KEY_ESCAPE:` body → `hud.open_settings()`;
- `_consume_fx` `"ability_pulse":` → keep `fx.ability_pulse(...)`, delete `if f.ability != "shieldwall":` and dedent the `for` loop under it one level;
- in `_on_event` add after the `"ability":` case:

```gdscript
		"ability_end":
			if ev.side == 0 and ev.kills > 0:
				for a in sim.data.ages:
					if String(a.ability.id) == ev.ability:
						hud.banner("%s: %d killed" % [race_def(0).ability_name(a.ability), ev.kills], team_color(0), 0, true)
```

`scripts/view/world_layer.gd`: in `_draw_overlay` replace the whole `if view.aiming:` block with the telegraph marker (spec §3.3), and change the doc comment to `## HP bars and skill telegraphs, drawn over the outlined units.`:

```gdscript
	# Skill telegraph: mark each pending skill's zone until its first pulse lands.
	for e in sim.effects:
		if e.pulse == 0:
			var c := view.team_color(e.side).lightened(0.5)
			_overlay.draw_rect(Rect2(e.lo, GROUND_Y - 6, e.hi - e.lo, 16), Color(c, 0.35))
			_overlay.draw_line(Vector2(e.lo, GROUND_Y - 130), Vector2(e.lo, GROUND_Y + 10), c, 2.0)
			_overlay.draw_line(Vector2(e.hi, GROUND_Y - 130), Vector2(e.hi, GROUND_Y + 10), c, 2.0)
```

Delete the `if u.armour_buff_until > view.sim.time:` block (3 lines).

`scripts/view/fx_layer.gd`: replace the `"shieldwall":` case in `ability_pulse` with

```gdscript
		"rockfall":
			for i in 7:
				var x := rng.randf_range(lo, hi)
				var to := Vector2(x, GROUND_Y - rng.randf_range(2, 16))
				var from := to + Vector2(rng.randf_range(-40, 40), -rng.randf_range(560, 680))
				later(rng.randf_range(0.0, 0.25), func(): shoot("stone", from, to, "blast", func(): impact("blast", to, true)))
			view.add_shake(6.0)
```

delete the `"dome":` case in `_draw_actor` (11 lines), and change the `actors` comment `# stampede beasts, lasting domes, beams` → `# stampede beasts, beams`.

`scripts/view/match_hud.gd`: delete `var _momentum: Meter` and the four `_momentum` lines in `_build_commands`; change `_ability = _btn(row1, "", func(): view.begin_aim())` → `_ability = _btn(row1, "", func(): feedback(sim.fire_ability(0)))`; delete the two `_momentum.…` lines in `_process`; replace the `_ability.text = …` line with

```gdscript
	_ability.text = "⚡ %s  %d XP  [Space]%s" % [view.race_def(0).ability_name(ab), ab.xp_cost, "" if me.ability_cooldown <= 0 else "   %ds" % ceili(me.ability_cooldown)]
```

- [ ] **Step 9: Reimport, validate, test, grep**

```bash
timeout 150 "$GODOT" --headless --path . --import > /dev/null 2>&1
timeout 60 "$GODOT" --headless --path . -s tools/validate_data.gd
timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd
grep -rn "momentum\|armour_buff\|aiming\|aim_x\|aim_level\|strong_age\|shieldwall" scripts tools tests data --include=*.gd --include=*.tres --include=*.py || echo "clean"
```

Expected: `data OK`, `0 failures`, `clean`.

- [ ] **Step 10: Smoke-run and commit**

Run the screenshot command from Task 2 Step 10 (file name `skills.png`); expect no `SCRIPT ERROR`.

```bash
git add -A scripts tools tests data
git commit -m "Skills cost XP and aim themselves (area/strip/sweep); remove momentum; Rockfall replaces Shieldwall

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Every unit attacks turrets

**Files:**
- Modify: `scripts/sim/match_sim.gd` (`_hit_structures`), `scripts/sim/sim_turret.gd`
- Test: `tests/test_combat.gd`

- [ ] **Step 1: Replace the Siege-only test**

In `tests/test_combat.gd` replace `test_only_siege_damages_turrets` with:

```gdscript
func test_all_units_damage_turrets_before_base() -> void:
	var sim := new_sim()
	sim.sides[1].age = 2
	sim.build_turret(1, 0, sim.data.turret_for_kind(2, "sentry"))
	var t: SimTurret = sim.sides[1].turrets[0]
	var v := place(sim, 0, "vanguard", sim.rules.lane_length - 5.0, 2)
	v.hp = 1e9
	var base_hp := sim.sides[1].base_hp
	sim.step()
	check_near(t.max_hp - t.hp, v.def.damage * sim.rules.matrix(v.def.damage_type, "structure"), 0.01, "vanguard hits the turret at its structure multiplier")
	run_for(sim, 2.0)
	check_near(sim.sides[1].base_hp, base_hp, 0.01, "base untouched while a turret stands")
```

- [ ] **Step 2: Run tests to verify it fails**

Run: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd`
Expected: `FAIL test_combat::test_all_units_damage_turrets_before_base` (vanguard damage goes to the base).

- [ ] **Step 3: Implement**

Replace `_hit_structures` in `scripts/sim/match_sim.gd` with:

```gdscript
func _hit_structures(u: SimUnit, enemy: SimSide) -> void:
	var raw := u.base_damage * rules.matrix(u.def.damage_type, "structure")
	raw *= 1.0 + rules.escalation_structure_bonus * escalation
	# Any unit at the gate knocks out turrets (lowest slot first) before the base; the matrix makes
	# Siege the structure-breaker (spec §2.3, superseding PLAN D3).
	for t in enemy.turrets:
		if t != null and t.alive():
			var dmg := minf(raw, t.hp)
			t.hp -= dmg
			u.stat_damage_dealt += dmg
			match_log.count_damage(u.side, u.def, dmg)
			if t.hp <= 0.0:
				enemy.turrets[t.slot] = null
				_emit({"type": "turret_destroyed", "side": enemy.index, "slot": t.slot, "turret": String(t.def.id)})
			if record_fx:
				fx.append({"type": "hit", "x": to_world(enemy.index, 0.0), "dtype": u.def.damage_type, "side": enemy.index, "structure": true})
			return
	u.stat_damage_dealt += minf(raw, enemy.base_hp)
	match_log.count_damage(u.side, u.def, minf(raw, enemy.base_hp))
	damage_base(enemy, raw, u.side)
```

`scripts/sim/sim_turret.gd`: header comment `## A turret in a base slot. Only Siege units can damage turrets (PLAN D3).` → `## A turret in a base slot. Any unit at the gate damages turrets before the base.`

- [ ] **Step 4: Run tests to verify they pass**

Run: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd`
Expected: `0 failures`.

- [ ] **Step 5: Commit**

```bash
git add scripts/sim/match_sim.gd scripts/sim/sim_turret.gd tests/test_combat.gd
git commit -m "Every unit attacks turrets before the base; Siege still hits structures hardest

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: One free turret slot, three to unlock

**Files:**
- Modify: `scripts/data/rules_def.gd`, `data/rules.tres`, `scripts/sim/sim_side.gd`, `scripts/sim/match_sim.gd`, `scripts/ai/utility_ai.gd`, `scripts/view/match_hud.gd`, `tools/validate_data.gd`
- Test: `tests/test_evolution.gd`

**Interfaces:**
- Produces: `MatchSim.max_turret_slots() -> int` (= `rules.turret_slot_costs.size()`, 4). `SimSide.max_turret_slots()` is removed; `SimSide.turrets` has 4 entries.

- [ ] **Step 1: Rewrite the slot test**

Replace `test_turret_slots_and_sell` in `tests/test_evolution.gd`:

```gdscript
func test_turret_slots_and_sell() -> void:
	var sim := new_sim()
	check_eq(sim.sides[0].turret_slots, 1, "one free slot")
	check_near(sim.slot_cost(0), 150.0, 0.01)
	check(sim.unlock_slot(0))
	check_near(sim.slot_cost(0), 400.0, 0.01)
	check(sim.unlock_slot(0))
	check_near(sim.slot_cost(0), 700.0, 0.01)
	check(sim.unlock_slot(0))
	check(not sim.unlock_slot(0), "4 slots max")
	check(sim.slot_cost(0) == INF)
	var def := sim.data.turret_for_kind(1, "sentry")
	check(not sim.build_turret(0, 4, def), "no fifth slot")
	sim.build_turret(0, 0, def)
	var g := sim.sides[0].gold
	check(sim.sell_turret(0, 0))
	check_near(sim.sides[0].gold - g, def.cost * 0.5, 0.01)
	sim.sides[1].age = 3
	check_near(sim.slot_cost(1), roundf(150.0 * 1.7 * 1.7), 0.01, "scales with age")
```

- [ ] **Step 2: Run tests to verify it fails**

Expected: `FAIL test_evolution::test_turret_slots_and_sell … one free slot`.

- [ ] **Step 3: Implement**

`scripts/data/rules_def.gd`: `@export var start_turret_slots: int = 2` → `= 1`; replace the slot-cost export and comment with

```gdscript
## Cost to unlock slot N (index N − 1; slot 1 is free). The array length is the slot maximum.
## Multiplied by the age cost multiplier.
@export var turret_slot_costs: PackedInt32Array = PackedInt32Array([0, 150, 400, 700])
```

```bash
sed -i -e 's/^start_turret_slots = .*/start_turret_slots = 1/' -e 's/^turret_slot_costs = .*/turret_slot_costs = PackedInt32Array(0, 150, 400, 700)/' data/rules.tres
```

`scripts/sim/sim_side.gd`: `var turret_slots: int = 2` → `= 1`; `var turrets: Array = [null, null, null, null, null]` → `[null, null, null, null]`; delete `func max_turret_slots()`.

`scripts/sim/match_sim.gd`: add after `slot_cost`:

```gdscript
func max_turret_slots() -> int:
	return rules.turret_slot_costs.size()
```

and in `slot_cost` change `if s.turret_slots >= s.max_turret_slots():` → `if s.turret_slots >= max_turret_slots():`.

`scripts/ai/utility_ai.gd` `_structural_want`: `if s.turret_slots < s.max_turret_slots():` → `if s.turret_slots < sim.max_turret_slots():`.

`scripts/view/match_hud.gd`: in `_build_commands` change the slot loop `for i in 5:` → `for i in 4:`; in `_process` change `for i in 5:` → `for i in 4:`, delete `b.visible = i < me.max_turret_slots()`, and change `var key := "QWER"[i] if i < 4 else "–"` → `var key := "QWER"[i]`.

`tools/validate_data.gd`: replace `_check(r.turret_slot_costs.size() >= 5, "turret slot costs for 5 slots")` with

```gdscript
	_check(r.turret_slot_costs.size() == 4 and r.turret_slot_costs[0] == 0, "4 turret slots, the first free")
	_check(r.start_turret_slots == 1, "one slot at start")
```

- [ ] **Step 4: Validate and test**

```bash
timeout 60 "$GODOT" --headless --path . -s tools/validate_data.gd
timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd
```

Expected: `data OK`, `0 failures`.

- [ ] **Step 5: Commit**

```bash
git add -A scripts tools tests data
git commit -m "One free turret slot; slots 2-4 unlock for 150/400/700 x age

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Gold upgrades (units, turrets, income)

**Files:**
- Create: `tests/test_upgrades.gd`
- Modify: `scripts/data/rules_def.gd`, `data/rules.tres`, `scripts/sim/sim_side.gd`, `scripts/sim/match_sim.gd`, `scripts/ai/utility_ai.gd`, `scripts/data/ai_personality_def.gd`, `data/ai/personalities/{economist,rusher}.tres`, `scripts/sim/sim_jobs.gd`, `tools/sim/tune.py`, `scripts/view/match_hud.gd`, `scripts/view/match_view.gd`
- Test: `tests/test_upgrades.gd`, `tests/test_economy.gd`

**Interfaces:**
- Produces (MatchSim):
  - `const UPGRADES := {"vanguard": ["attack", "health", "defence"], "ranged": […], "heavy": […], "siege": […], "turret": ["attack", "health", "range"], "income": ["income"]}`
  - `upgrade_level(side: int, row: String, stat: String) -> int`
  - `upgrade_cost(side: int, row: String, stat: String) -> float` — `INF` when maxed, unknown, or the row has no unit this age
  - `can_buy_upgrade(side: int, row: String, stat: String) -> bool`
  - `buy_upgrade(side: int, row: String, stat: String) -> bool` — emits `{"type": "upgrade", side, row, stat, level}`
  - `attack_mult(side: int, row: String) -> float`, `health_mult(side: int, row: String) -> float`, `defence_mult(side: int, role: String) -> float`, `turret_range_mult(side: int) -> float`
- Produces (SimSide): `upgrades: Dictionary`, `upgrade_level(row: String, stat: String) -> int`, `set_upgrade_level(row: String, stat: String, level: int) -> void`. `forge_level`, `forge_cost`, `buy_forge` are removed.
- Produces (AiPersonalityDef): `income_target: int`, `income_after: float` (renamed from `forge_target`/`forge_after`).

- [ ] **Step 1: Write the failing tests**

Create `tests/test_upgrades.gd`:

```gdscript
extends TestCase


func test_costs_scale_with_level_and_price() -> void:
	var sim := new_sim()
	var def := sim.data.unit_for_role(1, "ranged")
	check_near(sim.upgrade_cost(0, "ranged", "attack"), roundf(0.6 * def.cost), 0.01)
	check(sim.buy_upgrade(0, "ranged", "attack"))
	check_near(sim.upgrade_cost(0, "ranged", "attack"), roundf(1.0 * def.cost), 0.01)
	sim.buy_upgrade(0, "ranged", "attack")
	sim.buy_upgrade(0, "ranged", "attack")
	check_eq(sim.upgrade_level(0, "ranged", "attack"), 3)
	check(sim.upgrade_cost(0, "ranged", "attack") == INF, "max level")
	check(not sim.buy_upgrade(0, "ranged", "attack"), "no fourth level")
	sim.sides[0].age = 2
	check_near(sim.upgrade_cost(0, "heavy", "health"), roundf(0.6 * sim.data.unit_for_role(2, "heavy").cost), 0.01, "priced off the current age's unit")


func test_siege_row_unavailable_in_age_1() -> void:
	var sim := new_sim()
	var gold := sim.sides[0].gold
	check(sim.upgrade_cost(0, "siege", "attack") == INF)
	check(not sim.buy_upgrade(0, "siege", "attack"))
	check_near(sim.sides[0].gold, gold, 0.001, "nothing charged")
	sim.evolve(0)
	run_for(sim, 5.1)
	check(sim.buy_upgrade(0, "siege", "attack"), "available from Age 2")


func test_unknown_row_or_stat_rejected() -> void:
	var sim := new_sim()
	check(not sim.buy_upgrade(0, "ranged", "range"), "units have no range upgrade")
	check(not sim.buy_upgrade(0, "turret", "defence"), "turrets have no defence upgrade")
	check(not sim.buy_upgrade(0, "wizard", "attack"))


func test_not_enough_gold() -> void:
	var sim := new_sim(false)
	sim.sides[0].gold = 1.0
	check(not sim.buy_upgrade(0, "vanguard", "attack"))
	check_near(sim.sides[0].gold, 1.0, 0.001, "nothing charged")


func test_attack_upgrade_applies_to_fielded_units() -> void:
	var sim := new_sim()
	var a := place(sim, 0, "vanguard", 1190.0)
	check(sim.buy_upgrade(0, "vanguard", "attack"))
	var b := place(sim, 1, "vanguard", 1190.0)
	sim.step()
	check_near(b.max_hp - b.hp, a.def.damage * 1.15, 0.01, "upgraded side hits 15% harder")
	check_near(a.max_hp - a.hp, b.def.damage, 0.01, "other side unchanged")


func test_health_upgrade_scales_fielded_and_new_units_keeping_percentage() -> void:
	var sim := new_sim()
	var u := place(sim, 0, "heavy", 100.0)
	u.hp = u.max_hp * 0.5
	var base := u.def.hp
	check(sim.buy_upgrade(0, "heavy", "health"))
	check_near(u.max_hp, base * 1.15, 0.01)
	check_near(u.hp / u.max_hp, 0.5, 1e-4, "keeps percentage")
	var v := place(sim, 0, "heavy", 50.0)
	check_near(v.max_hp, base * 1.15, 0.01, "new units get it")
	var other := place(sim, 0, "vanguard", 20.0)
	check_near(other.max_hp, other.def.hp, 0.01, "other roles unaffected")


func test_defence_reduces_damage_taken() -> void:
	var sim := new_sim()
	var u := place(sim, 0, "vanguard", 100.0)
	check(sim.buy_upgrade(0, "vanguard", "defence"))
	var hp := u.hp
	sim._damage_unit(u, 50.0, "slash", 1)
	check_near(hp - u.hp, 50.0 * 0.9, 0.01)


func test_upgrades_carry_over_to_next_age() -> void:
	var sim := new_sim()
	sim.buy_upgrade(0, "ranged", "health")
	sim.evolve(0)
	run_for(sim, 5.1)
	check_eq(sim.sides[0].age, 2)
	check_eq(sim.upgrade_level(0, "ranged", "health"), 1)
	var u := place(sim, 0, "ranged", 50.0, 2)
	check_near(u.max_hp, sim.data.unit_for_role(2, "ranged").hp * 1.15, 0.01)


func test_upgrades_apply_to_older_age_units() -> void:
	var sim := new_sim()
	var old := place(sim, 0, "vanguard", 100.0, 1)
	sim.evolve(0)
	run_for(sim, 5.1)
	check(sim.buy_upgrade(0, "vanguard", "health"))
	check_near(old.max_hp, old.def.hp * 1.15, 0.01, "Age 1 Vanguard still on the lane gets the Age 2 purchase")


func test_turret_upgrades() -> void:
	var sim := new_sim()
	var def := sim.data.turret_for_kind(1, "sentry")
	check_near(sim.upgrade_cost(0, "turret", "attack"), roundf(0.6 * def.cost), 0.01, "average Age 1 turret cost")
	sim.build_turret(0, 0, def)
	var t: SimTurret = sim.sides[0].turrets[0]
	t.hp = t.max_hp * 0.5
	check(sim.buy_upgrade(0, "turret", "health"))
	check_near(t.max_hp, def.hp * 1.15, 0.01, "built turret gains HP")
	check_near(t.hp / t.max_hp, 0.5, 1e-4, "keeps percentage")
	sim.sell_turret(0, 0)
	sim.build_turret(0, 0, def)
	check_near(sim.sides[0].turrets[0].max_hp, def.hp * 1.15, 0.01, "turret built later has it too")
	check(sim.buy_upgrade(0, "turret", "range"))
	var e := place(sim, 1, "vanguard", sim.rules.lane_length - def.range * 1.05)
	run_pinned(sim, 0.1, [e])
	check(e.hp < e.max_hp, "range upgrade reaches further")


func test_range_upgrade_widens_support_aura() -> void:
	var sim := new_sim()
	var support: TurretDef = null
	var age := 1
	for a in sim.data.ages:
		for t in a.turrets:
			if t.kind == "support" and support == null:
				support = t
				age = a.index
	check(support != null, "some age has a Support turret")
	sim.sides[0].age = age
	sim.build_turret(0, 0, support)
	var e := place(sim, 1, "vanguard", sim.rules.lane_length - support.aura_radius * 1.05, age)
	sim.step()
	check_near(e.slow, 0.0, 1e-4, "outside the base aura")
	check(sim.buy_upgrade(0, "turret", "range"))
	e.progress = sim.rules.lane_length - support.aura_radius * 1.05
	sim.step()
	check(e.slow > 0.0, "inside the upgraded aura")


func test_income_upgrade_replaces_forge() -> void:
	var sim := new_sim()
	check_near(sim.upgrade_cost(0, "income", "income"), 100.0, 0.01)
	check(sim.buy_upgrade(0, "income", "income"))
	check_near(sim.income_rate(0), 2.4, 1e-4)
	sim.sides[0].age = 3
	check_near(sim.upgrade_cost(0, "income", "income"), roundf(250.0 * 1.7 * 1.7), 0.01)
```

In `tests/test_economy.gd` delete the whole `test_forge_raises_income_and_scales_with_age`.

- [ ] **Step 2: Run tests to verify they fail**

Expected: `FAIL test_upgrades.gd (does not compile)` (no `upgrade_cost`).

- [ ] **Step 3: Rules**

`scripts/data/rules_def.gd`: delete `forge_costs` and `forge_income_bonus` from the Economy group and add a group:

```gdscript
@export_group("Upgrades")
## Gold for upgrade level n (1-based) = factor[n − 1] × the current price of what is upgraded
## (the role's current-age unit, or the average current-age turret).
@export var upgrade_cost_factors: PackedFloat32Array = PackedFloat32Array([0.6, 1.0, 1.5])
@export var upgrade_attack_bonus: float = 0.15
@export var upgrade_health_bonus: float = 0.15
## Fraction of incoming damage removed per Defence level.
@export var upgrade_defence_bonus: float = 0.1
## Turret range and Support aura radius per Range level.
@export var upgrade_range_bonus: float = 0.1
## Income row (was the Forge): cost per level (× age cost multiplier) and income bonus per level.
@export var income_upgrade_costs: PackedInt32Array = PackedInt32Array([100, 250, 500])
@export var income_upgrade_bonus: float = 0.2
```

```bash
sed -i -e 's/^forge_costs = /income_upgrade_costs = /' -e 's/^forge_income_bonus = /income_upgrade_bonus = /' data/rules.tres
sed -i -e 's/^forge_target = /income_target = /' -e 's/^forge_after = /income_after = /' data/ai/personalities/*.tres
```

- [ ] **Step 4: SimSide**

In `scripts/sim/sim_side.gd` replace `var forge_level: int = 0` with

```gdscript
## Upgrade levels: row -> {stat -> level}; missing = 0 (MatchSim.UPGRADES lists rows and stats).
var upgrades: Dictionary = {}
```

and add:

```gdscript
func upgrade_level(row: String, stat: String) -> int:
	return upgrades.get(row, {}).get(stat, 0)


func set_upgrade_level(row: String, stat: String, level: int) -> void:
	if not upgrades.has(row):
		upgrades[row] = {}
	upgrades[row][stat] = level
```

- [ ] **Step 5: MatchSim upgrades**

Add after `const ROLES`:

```gdscript
## Upgrade rows and the stats each offers (GDD §6.1). Unit rows are the four roles.
const UPGRADES := {
	"vanguard": ["attack", "health", "defence"],
	"ranged": ["attack", "health", "defence"],
	"heavy": ["attack", "health", "defence"],
	"siege": ["attack", "health", "defence"],
	"turret": ["attack", "health", "range"],
	"income": ["income"],
}
```

Delete `func forge_cost` and `func buy_forge`. In `income_rate` replace `(1.0 + rules.forge_income_bonus * s.forge_level)` with `(1.0 + rules.income_upgrade_bonus * s.upgrade_level("income", "income"))`. Add in the "Prices and availability" section:

```gdscript
func upgrade_level(side: int, row: String, stat: String) -> int:
	return sides[side].upgrade_level(row, stat)


## Gold for the next level; INF when maxed, unknown, or the row has no unit this age (PLAN D22).
func upgrade_cost(side: int, row: String, stat: String) -> float:
	if not UPGRADES.has(row) or not stat in UPGRADES[row]:
		return INF
	var s := sides[side]
	var level := s.upgrade_level(row, stat)
	if row == "income":
		if level >= rules.income_upgrade_costs.size():
			return INF
		return roundf(rules.income_upgrade_costs[level] * rules.age_cost_mult(s.age))
	if level >= rules.upgrade_cost_factors.size():
		return INF
	var basis := 0.0
	if row == "turret":
		var roster := turret_roster(side)
		for t in roster:
			basis += t.cost
		basis /= maxf(1.0, roster.size())
	else:
		var def := data.unit_for_role(s.age, row)
		if def == null:
			return INF
		basis = unit_price(side, def)
	return roundf(rules.upgrade_cost_factors[level] * basis)


func can_buy_upgrade(side: int, row: String, stat: String) -> bool:
	return not is_over() and sides[side].gold >= upgrade_cost(side, row, stat)


## Multipliers from upgrades; `row` is a role or "turret". Read at damage/HP time so they apply to
## everything already fielded, whatever its age (PLAN D18).
func attack_mult(side: int, row: String) -> float:
	return 1.0 + rules.upgrade_attack_bonus * sides[side].upgrade_level(row, "attack")


func health_mult(side: int, row: String) -> float:
	return 1.0 + rules.upgrade_health_bonus * sides[side].upgrade_level(row, "health")


func defence_mult(side: int, role: String) -> float:
	return maxf(0.0, 1.0 - rules.upgrade_defence_bonus * sides[side].upgrade_level(role, "defence"))


func turret_range_mult(side: int) -> float:
	return 1.0 + rules.upgrade_range_bonus * sides[side].upgrade_level("turret", "range")
```

Add in the Commands section:

```gdscript
func buy_upgrade(side: int, row: String, stat: String) -> bool:
	if not can_buy_upgrade(side, row, stat):
		return false
	var s := sides[side]
	var c := upgrade_cost(side, row, stat)
	var old_hp := health_mult(side, row)
	s.gold -= c
	s.stat_gold_spent += c
	s.set_upgrade_level(row, stat, s.upgrade_level(row, stat) + 1)
	if stat == "health":
		# Max HP rises for everything already fielded; current HP keeps its percentage (PLAN D19).
		var ratio := health_mult(side, row) / old_hp
		if row == "turret":
			for t in s.turrets:
				if t != null:
					t.max_hp *= ratio
					t.hp *= ratio
		else:
			for u in s.units:
				if u.def.role == row:
					u.max_hp *= ratio
					u.hp *= ratio
	_emit({"type": "upgrade", "side": side, "row": row, "stat": stat, "level": s.upgrade_level(row, stat)})
	return true
```

Apply the multipliers:
- `build_turret`: `t.max_hp = def.hp` → `t.max_hp = def.hp * health_mult(side, "turret")`; `t.hp = def.hp` → `t.hp = t.max_hp`.
- `_spawn`: `u.max_hp = def.hp` → `u.max_hp = def.hp * health_mult(s.index, def.role)`.
- `_units_act`: `_hit_unit(u, target_unit, u.base_damage, def.damage_type)` → `_hit_unit(u, target_unit, u.base_damage * attack_mult(u.side, def.role), def.damage_type)`.
- `_hit_structures`: first line → `var raw := u.base_damage * attack_mult(u.side, u.def.role) * rules.matrix(u.def.damage_type, "structure")`.
- `_damage_unit`: `var dmg := raw * rules.matrix(dtype, target.def.armour)` → `var dmg := raw * rules.matrix(dtype, target.def.armour) * defence_mult(target.side, target.def.role)`.
- `_apply_auras`: `rules.lane_length - u.progress <= t.def.aura_radius` → `rules.lane_length - u.progress <= t.def.aura_radius * turret_range_mult(s.index)`.
- `_turrets_act`: after `var raw: float = t.def.damage * mult` change it to `var raw: float = t.def.damage * mult * attack_mult(s.index, "turret")`, add `var reach := t.def.range * turret_range_mult(s.index)` below it, and use `reach` in place of `t.def.range` in the Sentry check (`<= reach`) and the Artillery check (`d > reach`).

- [ ] **Step 6: AI income want (was Forge)**

`scripts/data/ai_personality_def.gd`: rename the two exports and comment:

```gdscript
## Income upgrade levels to target, and the earliest time to buy each (was the Forge).
@export var income_target: int = 2
@export var income_after: float = 45.0
```

`scripts/ai/utility_ai.gd` `_structural_want`: replace the Forge branch with

```gdscript
	var inc := s.upgrade_level("income", "income")
	if inc < personality.income_target and sim.time >= personality.income_after + inc * 90.0 and not pressure:
		return {"kind": "income", "cost": sim.upgrade_cost(side, "income", "income")}
```

and in `_do_want` replace the `"forge":` case with

```gdscript
		"income":
			sim.buy_upgrade(side, "income", "income")
```

Update the structural-want comment `turret target → slot → Forge` if present to `→ Income`.

- [ ] **Step 7: Tools and view**

`scripts/sim/sim_jobs.gd` doc example `--set=rules.forge_income_bonus=0.1` → `--set=rules.income_upgrade_bonus=0.25`. `tools/sim/tune.py`: replace the `forge_bonus` row with `("income_bonus", "set", ["rules.income_upgrade_bonus"], 0.2, "rel:0.8,1.25"),`.

`scripts/view/match_view.gd`: delete the `KEY_F:` case (2 lines).

`scripts/view/match_hud.gd`: rename `var _forge: Button` → `var _income: Button`; creation → `_income = _btn(row3, "", func(): feedback(sim.buy_upgrade(0, "income", "income")))` and `_income.custom_minimum_size = Vector2(170, 34)`; replace the three `_forge.…` lines in `_process` with

```gdscript
	var inc := sim.upgrade_level(0, "income", "income")
	_income.text = "💰 Income %s  %s" % ["●".repeat(inc) + "○".repeat(3 - inc), "" if inc >= 3 else "%dg" % sim.upgrade_cost(0, "income", "income")]
	_income.tooltip_text = "Income: +20% passive income per level. Unit and turret upgrades arrive with the new HUD."
	_income.disabled = not sim.can_buy_upgrade(0, "income", "income")
```

- [ ] **Step 8: Validate, test, grep**

```bash
timeout 150 "$GODOT" --headless --path . --import > /dev/null 2>&1
timeout 60 "$GODOT" --headless --path . -s tools/validate_data.gd
timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd
grep -rn "forge" scripts tools tests data --include=*.gd --include=*.tres --include=*.py || echo "clean"
```

Expected: `data OK`, `0 failures`, `clean`.

- [ ] **Step 9: Commit**

```bash
git add -A scripts tools tests data
git commit -m "Gold upgrades: per-role attack/health/defence, turret attack/health/range, income

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: AI buys upgrades

**Files:**
- Modify: `scripts/data/ai_personality_def.gd`, `data/ai/personalities/{turtle,rusher}.tres`, `scripts/ai/utility_ai.gd`
- Test: `tests/test_match.gd`

**Interfaces:**
- Consumes: `MatchSim.UPGRADES`, `upgrade_cost`, `buy_upgrade` (Task 8).
- Produces: `AiPersonalityDef.upgrade_bias: Dictionary`, `AiPersonalityDef.upgrade_after_army_seconds: float`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_match.gd`:

```gdscript


func test_ai_buys_unit_or_turret_upgrades() -> void:
	var gd := GameData.get_default()
	var r := MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"turtle"}, 11)
	var bought: Array = r.log.events.filter(func(ev): return ev.type == "upgrade" and ev.row != "income")
	check(not bought.is_empty(), "some unit or turret upgrade was bought")
	check(bought.any(func(ev): return ev.row == "turret" and ev.side == 1), "Turtle upgrades its turrets")
```

- [ ] **Step 2: Run tests to verify it fails**

Expected: `FAIL test_match::test_ai_buys_unit_or_turret_upgrades … some unit or turret upgrade was bought`.

- [ ] **Step 3: Personality fields and data**

Add to `scripts/data/ai_personality_def.gd`:

```gdscript
@export_group("Upgrades")
## Appetite per upgrade row (roles and "turret"); multiplied by that role's share of the army
## (turrets: by turret count ÷ 2).
@export var upgrade_bias: Dictionary = {"vanguard": 1.0, "ranged": 1.0, "heavy": 1.0, "siege": 1.0, "turret": 1.0}
## Only buy unit/turret upgrades once the army on the lane is worth this many seconds of income.
@export var upgrade_after_army_seconds: float = 15.0
```

```bash
echo 'upgrade_bias = {"heavy": 1.0, "ranged": 1.0, "siege": 1.0, "turret": 3.0, "vanguard": 1.0}' >> data/ai/personalities/turtle.tres
echo 'upgrade_bias = {"heavy": 0.5, "ranged": 0.5, "siege": 0.5, "turret": 0.0, "vanguard": 2.0}' >> data/ai/personalities/rusher.tres
echo 'upgrade_after_army_seconds = 30.0' >> data/ai/personalities/rusher.tres
```

- [ ] **Step 4: AI**

In `_decide` add `_buy_upgrade(sim, pressure)` as the last line. Add to the Gold section of `scripts/ai/utility_ai.gd`:

```gdscript
## Leftover gold buys the best-value upgrade: rows the army actually uses, weighted by personality.
## At most one per decision; never under pressure or with a thin army.
func _buy_upgrade(sim: MatchSim, pressure: bool) -> void:
	var s := sim.sides[side]
	if pressure or s.army_value() < sim.income_rate(side) * personality.upgrade_after_army_seconds:
		return
	var share := {}
	var total := 0.0
	for u in s.units:
		share[u.def.role] = share.get(u.def.role, 0.0) + u.cost_paid
		total += u.cost_paid
	var best_row := ""
	var best_stat := ""
	var best_score := 0.0
	for row in MatchSim.UPGRADES:
		if row == "income":
			continue
		var weight: float = personality.upgrade_bias.get(row, 0.0)
		if row == "turret":
			weight *= s.turret_count() / 2.0
		else:
			weight *= share.get(row, 0.0) / maxf(total, 1.0)
		if weight <= 0.0:
			continue
		for stat in MatchSim.UPGRADES[row]:
			var cost := sim.upgrade_cost(side, row, stat)
			if cost > s.gold:
				continue
			var score := weight / cost
			if score > best_score:
				best_score = score
				best_row = row
				best_stat = stat
	if best_row != "":
		sim.buy_upgrade(side, best_row, best_stat)
```

- [ ] **Step 5: Test**

Run: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd` → `0 failures` (includes `test_determinism`, which proves the new AI code is still deterministic).

If `test_ai_buys_unit_or_turret_upgrades` fails only on the Turtle-turret check, print the match's upgrade events with `print(bought)` and check that Turtle ever has a turret and spare gold; adjust nothing in the test — adjust `turtle.tres` (`upgrade_after_army_seconds = 10.0`) and record it in the commit message.

- [ ] **Step 6: Commit**

```bash
git add -A scripts data tests
git commit -m "AI buys upgrades: army-share and personality weighted, best value per gold

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Balance pass

**Files:**
- Modify: `data/**/*.tres` (tuned values only), `docs/balance_log.md`, `reports/sim_report.md`, `docs/tasks/M1b.md`

This task is measured iteration with a fixed procedure; it ends green or with recorded findings, never with forced numbers.

- [ ] **Step 1: Baseline on two seeds**

```bash
S="$TMPDIR/balance"; mkdir -p "$S"   # on Windows: the session scratchpad
for seed in 1 2; do timeout 1500 "$GODOT" --headless --path . -s tools/sim/run_sim.gd -- --matches=20 --seed=$seed --workers=12 --out="$S/base$seed" > "$S/base$seed.log" 2>&1; sed -n 3,15p "$S/base$seed/sim_report.md"; done
```

Record both tables.

- [ ] **Step 2: Diagnose before tuning**

For each failing target, reproduce one match with the trace script pattern (one AI match printing both sides every 30 s: age, base HP, gold, XP, army value, units by role, turrets, upgrades) and `tools/sim/experiment.gd` for targeted matchups. Write one sentence per failing target naming the cause (e.g. "Turtle's range upgrades out-range Siege at the gate"). Fix AI behaviour bugs in code (with a test) before touching data.

- [ ] **Step 3: Tune with the keep-rule**

Change one data value at a time (or a `--set`/`--scale` override first, then apply it to `data/`). Keep a change only if, on **both** seeds, the targeted metric moves toward its band and the number of passing targets does not drop. Revert otherwise. Levers, in order: skill `xp_cost`/`damage`; `upgrade_*_bonus` and `upgrade_cost_factors`; `turret_slot_costs`; base HP; personality `upgrade_bias`/`income_target`/`turret_target`; unit stats last.

`tools/sim/tune.py` may propose values (`GODOT=… python tools/sim/tune.py --matches=12 --seed=3 --passes=2 --workers=12 --log="$S/tune.jsonl"`), but its proposals obey the same keep-rule on seeds 1 and 2.

- [ ] **Step 4: Record**

For every kept change append a row to `docs/balance_log.md` (B15, B16, …) with the change and the before/after numbers on both seeds. Add a first row `B15 | v3 rules (no veterancy/doctrines/momentum/stance; upgrades; XP skills; all units hit turrets; 1 free slot) | new baseline: <seed 1 table summary>; <seed 2 summary>`.

- [ ] **Step 5: Stop condition**

Stop when `run_sim.gd --matches=20` exits 0 on seeds 1 and 2, **or** when three consecutive candidate changes fail the keep-rule. In the second case add a "Findings" paragraph to `docs/balance_log.md` naming each still-failing target, the diagnosed cause, and what would need a design decision.

- [ ] **Step 6: Final report and commit**

```bash
timeout 1500 "$GODOT" --headless --path . -s tools/sim/run_sim.gd -- --matches=20 --seed=1 --workers=12
timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd
```

(The first command writes `reports/sim_report.md`.) Mark `M1b-7` in `docs/tasks/M1b.md` ✅ (green) or ❌ with a pointer to the findings.

```bash
git add data docs/balance_log.md reports/sim_report.md docs/tasks/M1b.md
git commit -m "Balance pass for the v3 rules

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```
