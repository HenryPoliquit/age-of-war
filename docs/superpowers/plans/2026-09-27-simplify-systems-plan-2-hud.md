# Simplify Systems — Plan 2: HUD Rebuild

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the match HUD with the approved layout: a slim top bar, a drop-down upgrade grid, unit cards bottom-left, lane map with training queue bottom-centre, turret slots bottom-right with popups above each slot, and base HP bars in the world.

**Architecture:** Everything the HUD *decides* (cell text and prices, tooltips, enabled states, slot kinds, build options, clock text) moves into a pure `HudModel` (`scripts/view/hud/hud_model.gd`, static functions over `MatchSim`), unit-tested headless. The HUD is split into one node script per panel under `scripts/view/hud/` that only renders `HudModel` output and calls `MatchSim` commands. `MatchHud` keeps orchestration (theme, banners, feedback, settings, post-match). Each task replaces one part of the old HUD and leaves the game playable.

**Tech Stack:** Godot 4.7-stable, GDScript, in-repo test runner.

**Spec:** `docs/superpowers/specs/2026-09-26-simplify-systems-and-hud-design.md` §4 (and §6 "post-match screen: upgrade purchases"). Plan 1 (`docs/superpowers/plans/2026-09-26-simplify-systems-plan-1-rules.md`) is complete; its rules and `MatchSim` API are the base.

## Global Constraints

- Godot **4.7-stable**. Git Bash from the repo root: `export GODOT="$(pwd)/../Godot_v4.7/Godot_v4.7-stable_win64_console.exe"`; always wrap Godot in `timeout`.
- Tests: `timeout 300 "$GODOT" --headless --path . -s tests/run_tests.gd` → `N tests, 0 failures` (script errors during a test count as failures).
- After adding a `class_name` script: `timeout 150 "$GODOT" --headless --path . --import > /dev/null 2>&1`, then `git checkout -- assets reports/*.import` if Godot rewrote their line endings.
- Screenshot check (the game at 1920×1080, AI playing both sides): `timeout 120 "$GODOT" --path . --resolution 1920x1080 -- --autoplay --speed=12 --screenshot="$SHOTS/<name>.png" --after=<seconds> 2>&1 | grep -E "screenshot|SCRIPT ERROR"` where `$SHOTS` is a scratch folder outside the repo. Expected: `screenshot saved` and **no** `SCRIPT ERROR`. Exit code 139 after the screenshot is a known pre-existing crash on quit (Plan 1 ledger) and is not a failure. Open the PNG and compare against the task's Expected description.
- Design resolution 1920×1080 (`stretch/mode = canvas_items`, `aspect = expand`); all offsets below are in that space.
- View code never changes game state except through `MatchSim` commands (`queue_unit`, `evolve`, `fire_ability`, `buy_upgrade`, `unlock_slot`, `build_turret`, `sell_turret`).
- Typed GDScript: declare types where inference fails (`var x: T = …` for Variant/Dictionary values).
- Layout from spec §4 (as approved in the brainstorm mockup): top bar left **XP · ▲ Evolve · ☄ Skill**, centre **your era · clock · enemy era**, right **⬆ Upgrades · gold (+income/s) · 1×/2× toggle · ⏸ · ⚙**; bottom-left 4 unit cards; bottom-centre lane map with **Training** + **queue (5)** under it; bottom-right 4 turret slots; popups open directly above the clicked slot; upgrade grid drops down under the top bar, mouse only, game keeps running; base HP bars above each base in the world; tide pips and the top minimap removed; F1–F3 removed (Esc opens settings/pause).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **Rows after evolving**: the upgrade grid's unit rows must show the *current* era's unit name and price after an evolution (upgrades are per slot) — Task 1 `test_row_label_follows_the_era`.
2. **Locked slots beyond the next one** must say which slot to unlock first, not offer a price — Task 1 `test_slot_states`.
3. **Escalation** was shown next to the tide pips, which are removed; the clock must now carry it — Task 1 `test_clock_shows_escalation`.
4. **Skill button with no target**: disabled with a reason, not an error flash on click — Task 1 `test_skill_needs_a_target`.
5. **Clicking the battlefield while the grid or a popup is open** must still pan/right-drag the camera: every new panel container passes clicks through outside its buttons (`mouse_filter = MOUSE_FILTER_PASS` on panels, `IGNORE` on the root) — checked by owner review in Task 6 (not testable headless).

---

### Task 1: HudModel — what the HUD shows, tested headless

**Files:**
- Create: `scripts/view/hud/hud_model.gd`
- Test: `tests/test_hud_model.gd`

**Interfaces:**
- Produces `class_name HudModel` (static functions):
  - `pips(level: int, levels: int) -> String`
  - `clock(sim: MatchSim) -> String` — `"m:ss"`, plus `"  ·  Escalation n/4"` once escalation starts
  - `era_name(sim: MatchSim, side: int) -> String` — e.g. `"Iron Age"`
  - `gold_text(sim: MatchSim, side: int) -> String` — e.g. `"199  +4.1/s"`
  - `row_label(sim: MatchSim, side: int, row: String, race: RaceDef) -> String`
  - `upgrade_cell(sim: MatchSim, side: int, row: String, stat: String) -> Dictionary` — `{text, tooltip, enabled, maxed}`
  - `skill_state(sim: MatchSim, side: int, race: RaceDef) -> Dictionary` — `{text, tooltip, enabled}`
  - `evolve_state(sim: MatchSim, side: int) -> Dictionary` — `{text, tooltip, enabled, progress}`
  - `slot_state(sim: MatchSim, side: int, i: int, race: RaceDef) -> Dictionary` — `{kind: "built"|"empty"|"unlock"|"locked", text, tooltip, outclassed?}`
  - `sell_value(sim: MatchSim, t: SimTurret) -> int`
  - `build_options(sim: MatchSim, side: int, race: RaceDef) -> Array[Dictionary]` — `[{def: TurretDef, text, enabled}]`
  - `unit_tooltip(sim: MatchSim, side: int, u: UnitDef, race: RaceDef) -> String`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_hud_model.gd`:

```gdscript
extends TestCase


func _race() -> RaceDef:
	return GameData.get_default().race(&"human")


func test_pips() -> void:
	check_eq(HudModel.pips(0, 3), "○○○")
	check_eq(HudModel.pips(2, 3), "●●○")


func test_clock_shows_escalation() -> void:
	var sim := new_sim()
	sim.time = 228.0
	check_eq(HudModel.clock(sim), "3:48")
	sim.time = 935.0
	sim.escalation = 2
	check_eq(HudModel.clock(sim), "15:35  ·  Escalation 2/4")


func test_era_and_gold_text() -> void:
	var sim := new_sim(false)
	check_eq(HudModel.era_name(sim, 0), "%s Age" % sim.data.age(1).display_name)
	check_eq(HudModel.gold_text(sim, 0), "150  +2.0/s")


func test_upgrade_cell_shows_price_and_effect() -> void:
	var sim := new_sim()
	var price := roundi(0.6 * sim.data.unit_for_role(1, "ranged").cost)
	var cell := HudModel.upgrade_cell(sim, 0, "ranged", "attack")
	check_eq(cell.text, "○○○  %dg" % price)
	check(cell.enabled, "affordable")
	check(not cell.maxed)
	check(cell.tooltip.contains("+15% damage for all Ranged units, every era"), cell.tooltip)
	check(cell.tooltip.ends_with("%d g" % price), cell.tooltip)


func test_maxed_cell() -> void:
	var sim := new_sim()
	for i in 3:
		sim.buy_upgrade(0, "vanguard", "health")
	var cell := HudModel.upgrade_cell(sim, 0, "vanguard", "health")
	check_eq(cell.text, "●●●  MAX")
	check(cell.maxed and not cell.enabled)
	check(cell.tooltip.contains("+45% health"), cell.tooltip)


func test_unaffordable_cell_is_disabled() -> void:
	var sim := new_sim(false)
	sim.sides[0].gold = 0.0
	var cell := HudModel.upgrade_cell(sim, 0, "heavy", "attack")
	check(not cell.enabled and not cell.maxed)


func test_siege_row_unavailable_in_age_1() -> void:
	var sim := new_sim()
	var cell := HudModel.upgrade_cell(sim, 0, "siege", "attack")
	check(not cell.enabled)
	check_eq(cell.text, "○○○")
	check(cell.tooltip.contains("No Siege unit"), cell.tooltip)
	check_eq(HudModel.row_label(sim, 0, "siege", _race()), "Siege")


func test_row_label_follows_the_era() -> void:
	var sim := new_sim()
	var race := _race()
	check_eq(HudModel.row_label(sim, 0, "ranged", race), race.unit_name(sim.data.unit_for_role(1, "ranged")))
	sim.sides[0].age = 3
	check_eq(HudModel.row_label(sim, 0, "ranged", race), race.unit_name(sim.data.unit_for_role(3, "ranged")))
	check_eq(HudModel.row_label(sim, 0, "turret", race), "Turrets")
	check_eq(HudModel.row_label(sim, 0, "income", race), "Income")


func test_income_and_range_cells() -> void:
	var sim := new_sim()
	var inc := HudModel.upgrade_cell(sim, 0, "income", "income")
	check_eq(inc.text, "○○○  100g")
	check(inc.tooltip.contains("+20% passive income"), inc.tooltip)
	check(HudModel.upgrade_cell(sim, 0, "turret", "range").tooltip.contains("Support auras"))


func test_skill_needs_a_target() -> void:
	var sim := new_sim()
	var st := HudModel.skill_state(sim, 0, _race())
	check(not st.enabled, "no enemy on the lane")
	check(st.tooltip.contains("No enemy units"), st.tooltip)
	place(sim, 1, "vanguard", 1000.0)
	st = HudModel.skill_state(sim, 0, _race())
	check(st.enabled)
	check(st.tooltip.contains("sweeps the whole lane"), st.tooltip)
	sim.fire_ability(0)
	st = HudModel.skill_state(sim, 0, _race())
	check(not st.enabled, "cooldown")
	check(st.text.ends_with("· %ds" % roundi(sim.rules.ability_cooldown)), st.text)


func test_evolve_state() -> void:
	var sim := new_sim()
	var st := HudModel.evolve_state(sim, 0)
	check(st.enabled)
	check_eq(st.text, "▲ Evolve · %d XP" % sim.data.age(2).evolve_cost)
	sim.sides[0].age = GameData.AGE_COUNT
	st = HudModel.evolve_state(sim, 0)
	check(not st.enabled)
	check_eq(st.text, "Final era")


func test_slot_states() -> void:
	var sim := new_sim()
	var race := _race()
	check_eq(HudModel.slot_state(sim, 0, 0, race).kind, "empty")
	var unlock := HudModel.slot_state(sim, 0, 1, race)
	check_eq(unlock.kind, "unlock")
	check_eq(unlock.text, "🔒 150g")
	var locked := HudModel.slot_state(sim, 0, 2, race)
	check_eq(locked.kind, "locked")
	check(locked.tooltip.contains("Unlock slot 2 first"), locked.tooltip)
	var def := sim.data.turret_for_kind(1, "sentry")
	sim.build_turret(0, 0, def)
	var built := HudModel.slot_state(sim, 0, 0, race)
	check_eq(built.kind, "built")
	check_eq(built.text, race.turret_name(def))
	check(built.tooltip.contains("sell for %d g" % roundi(def.cost * 0.5)), built.tooltip)


func test_build_options_follow_gold() -> void:
	var sim := new_sim(false)
	sim.sides[0].gold = 0.0
	var opts := HudModel.build_options(sim, 0, _race())
	check_eq(opts.size(), sim.turret_roster(0).size())
	check(not opts[0].enabled)
	sim.sides[0].gold = 9999.0
	check(HudModel.build_options(sim, 0, _race())[0].enabled)


func test_unit_tooltip_includes_upgrades() -> void:
	var sim := new_sim()
	var def := sim.data.unit_for_role(1, "heavy")
	sim.buy_upgrade(0, "heavy", "health")
	var tip := HudModel.unit_tooltip(sim, 0, def, _race())
	check(tip.contains("%d HP" % roundi(def.hp * 1.15)), tip)
	check(tip.contains("Upgrades: ♥ 1"), tip)
```

- [ ] **Step 2: Run tests to verify they fail**

Run the test command. Expected: `FAIL test_hud_model.gd (does not compile)` (no `HudModel`).

- [ ] **Step 3: Implement**

Create `scripts/view/hud/hud_model.gd`:

```gdscript
class_name HudModel
extends RefCounted
## What the match HUD shows, as plain data (GDD §13.9). The HUD's panels only render these values and
## call MatchSim commands, so the display rules are testable headless (tests/test_hud_model.gd).

const ROLE_NAME := {"vanguard": "Vanguard", "ranged": "Ranged", "heavy": "Heavy", "siege": "Siege"}
const STAT_ICON := {"attack": "⚔", "health": "♥", "defence": "🛡", "range": "➶", "income": "💰"}
const STAT_NAME := {"attack": "Attack", "health": "Health", "defence": "Defence", "range": "Range", "income": "Income"}
const SHAPE_TEXT := {
	"area": "strikes the biggest enemy group",
	"strip": "hits the enemy line from its front unit back toward their base",
	"sweep": "sweeps the whole lane from your gate to theirs",
}


static func pips(level: int, levels: int) -> String:
	return "●".repeat(level) + "○".repeat(maxi(0, levels - level))


static func clock(sim: MatchSim) -> String:
	var t := "%d:%02d" % [int(sim.time) / 60, int(sim.time) % 60]
	if sim.escalation > 0:
		t += "  ·  Escalation %d/%d" % [sim.escalation, sim.rules.escalation_max_stacks]
	return t


static func era_name(sim: MatchSim, side: int) -> String:
	return "%s Age" % sim.data.age(sim.sides[side].age).display_name


static func gold_text(sim: MatchSim, side: int) -> String:
	return "%d  +%.1f/s" % [sim.sides[side].gold, sim.income_rate(side)]


## Upgrade-grid row heading: the current era's unit in that slot, "Turrets" or "Income".
static func row_label(sim: MatchSim, side: int, row: String, race: RaceDef) -> String:
	if row == "turret":
		return "Turrets"
	if row == "income":
		return "Income"
	var def := sim.data.unit_for_role(sim.sides[side].age, row)
	return race.unit_name(def) if def != null else ROLE_NAME[row]


## One upgrade-grid cell: {text, tooltip, enabled, maxed}. Effects in tooltips are totals after the level.
static func upgrade_cell(sim: MatchSim, side: int, row: String, stat: String) -> Dictionary:
	var level := sim.upgrade_level(side, row, stat)
	var levels := sim.rules.income_upgrade_costs.size() if row == "income" else sim.rules.upgrade_cost_factors.size()
	var cost := sim.upgrade_cost(side, row, stat)
	var title := "%s %s %s" % [_row_title(row), STAT_ICON[stat], STAT_NAME[stat]]
	if level >= levels:
		return {"text": pips(level, levels) + "  MAX", "enabled": false, "maxed": true,
			"tooltip": "%s: level %d (max) — %s%s." % [title, level, _effect(sim, stat, level), _subject(row)]}
	if is_inf(cost):
		return {"text": pips(level, levels), "enabled": false, "maxed": false,
			"tooltip": "No %s unit this era yet." % ROLE_NAME.get(row, row)}
	return {"text": "%s  %dg" % [pips(level, levels), cost], "enabled": sim.can_buy_upgrade(side, row, stat), "maxed": false,
		"tooltip": "%s %d → %d: %s%s — %d g" % [title, level, level + 1, _effect(sim, stat, level + 1), _subject(row), cost]}


static func _row_title(row: String) -> String:
	return {"turret": "Turrets", "income": "Income"}.get(row, ROLE_NAME.get(row, row))


static func _subject(row: String) -> String:
	match row:
		"income":
			return ""
		"turret":
			return " for all turrets, every era"
		_:
			return " for all %s units, every era" % ROLE_NAME[row]


static func _effect(sim: MatchSim, stat: String, level: int) -> String:
	var r := sim.rules
	match stat:
		"attack":
			return "+%d%% damage" % roundi(r.upgrade_attack_bonus * level * 100.0)
		"health":
			return "+%d%% health" % roundi(r.upgrade_health_bonus * level * 100.0)
		"defence":
			return "−%d%% damage taken" % roundi(r.upgrade_defence_bonus * level * 100.0)
		"range":
			return "+%d%% range (Support auras too)" % roundi(r.upgrade_range_bonus * level * 100.0)
		_:
			return "+%d%% passive income" % roundi(r.income_upgrade_bonus * level * 100.0)


static func skill_state(sim: MatchSim, side: int, race: RaceDef) -> Dictionary:
	var s := sim.sides[side]
	var ab := sim.data.age(s.age).ability
	var skill := race.ability_name(ab)
	var has_target := not sim.ability_zone(side).is_empty()
	var text := "☄ %s · %d XP" % [skill, ab.xp_cost]
	if s.ability_cooldown > 0.0:
		text += " · %ds" % ceili(s.ability_cooldown)
	var tip := "%s [Space]: %s. Costs %d XP; %d s cooldown." % [skill, SHAPE_TEXT[ab.shape], ab.xp_cost, roundi(sim.rules.ability_cooldown)]
	if not has_target:
		tip += "\nNo enemy units to hit."
	return {"text": text, "tooltip": tip, "enabled": sim.can_fire_ability(side) and has_target}


static func evolve_state(sim: MatchSim, side: int) -> Dictionary:
	var s := sim.sides[side]
	if s.age >= GameData.AGE_COUNT:
		return {"text": "Final era", "tooltip": "", "enabled": false, "progress": 1.0}
	var cost := sim.evolve_cost(side)
	var text := ("Evolving… %.1fs" % s.evolve_left) if s.is_evolving() else ("▲ Evolve · %d XP" % cost)
	return {"text": text, "enabled": sim.can_evolve(side), "progress": clampf(s.xp / cost, 0.0, 1.0),
		"tooltip": "Evolve to the %s Age [T]: new units, turrets and skill. Upgrades carry over." % sim.data.age(s.age + 1).display_name}


static func slot_state(sim: MatchSim, side: int, i: int, race: RaceDef) -> Dictionary:
	var s := sim.sides[side]
	var key := "QWER"[i]
	if i < s.turret_slots:
		var t: SimTurret = s.turrets[i]
		if t == null:
			return {"kind": "empty", "text": "＋ Build", "tooltip": "Empty slot [%s]: click to build a turret" % key}
		var turret := race.turret_name(t.def)
		var old := t.def.age < s.age
		return {"kind": "built", "text": turret, "outclassed": old,
			"tooltip": "%s (%s Age) [%s]: click to sell for %d g%s" % [turret, sim.data.age(t.def.age).display_name, key, sell_value(sim, t), "\nOutclassed: sell it and build a new one" if old else ""]}
	if i == s.turret_slots:
		var c := sim.slot_cost(side)
		return {"kind": "unlock", "text": "🔒 %dg" % c, "tooltip": "Unlock slot %d for %d g [%s]" % [i + 1, c, key]}
	return {"kind": "locked", "text": "🔒", "tooltip": "Unlock slot %d first" % (s.turret_slots + 1)}


static func sell_value(sim: MatchSim, t: SimTurret) -> int:
	return roundi(t.def.cost * sim.rules.sell_refund)


static func build_options(sim: MatchSim, side: int, race: RaceDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in sim.turret_roster(side):
		out.append({"def": t, "text": "%s · %s   %dg" % [race.turret_name(t), t.kind.capitalize(), t.cost], "enabled": sim.sides[side].gold >= t.cost})
	return out


## Unit card tooltip: the damage × armour row plus this side's upgraded HP and damage.
static func unit_tooltip(sim: MatchSim, side: int, u: UnitDef, race: RaceDef) -> String:
	var r := sim.rules
	var text := "%s — %s\n%s damage · %s armour\nvs Light ×%.2f   vs Heavy ×%.2f   vs Structures ×%.2f\n%d HP · %.0f dmg every %.1fs · range %d · speed %d" % [
		race.unit_name(u), ROLE_NAME[u.role], u.damage_type.capitalize(), u.armour.capitalize(),
		r.matrix(u.damage_type, "light"), r.matrix(u.damage_type, "heavy"), r.matrix(u.damage_type, "structure"),
		roundi(u.hp * sim.health_mult(side, u.role)), u.damage * sim.attack_mult(side, u.role), u.attack_interval, u.range, u.speed]
	var ups: Array[String] = []
	for stat in MatchSim.UPGRADES[u.role]:
		var lv := sim.upgrade_level(side, u.role, stat)
		if lv > 0:
			ups.append("%s %d" % [STAT_ICON[stat], lv])
	if not ups.is_empty():
		text += "\nUpgrades: " + "  ".join(ups)
	return text
```

- [ ] **Step 4: Import and run tests**

Run the import command, then the test command. Expected: `0 failures` (14 new `test_hud_model` tests pass).

- [ ] **Step 5: Commit**

```bash
git add scripts/view/hud/ tests/test_hud_model.gd tests/test_hud_model.gd.uid
git commit -m "HudModel: HUD display rules as tested plain data

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Top bar

**Files:**
- Create: `scripts/view/hud/top_bar.gd`
- Modify: `scripts/view/match_hud.gd`, `scripts/view/match_view.gd`

**Interfaces:**
- Consumes: `HudModel.evolve_state/skill_state/era_name/clock/gold_text`; `MatchHud._label`, `MatchHud._btn`, `MatchHud.feedback`, `MatchHud.open_settings`, `MatchHud.Icon`, `MatchHud.Meter`, `MatchHud.XP`, `MatchHud._flash`; `MatchView.speed_index`, `MatchView.set_speed(i)` (speeds `[1.0, 2.0, 0.0]`, index 2 = paused).
- Produces: `class_name TopBar extends PanelContainer` with `_init(hud: MatchHud)`, `refresh()`, `upgrades_button: Button` (toggle; Task 3 connects it).

- [ ] **Step 1: Create the top bar**

Create `scripts/view/hud/top_bar.gd`:

```gdscript
class_name TopBar
extends PanelContainer
## Slim top bar (GDD §13.9): XP · Evolve · Skill | your era · clock · enemy era | Upgrades · gold ·
## speed · pause · settings. Renders HudModel values; acts only through MatchSim commands.

## Left and right groups share one minimum width so the centre group sits in the middle of the screen.
const SIDE_WIDTH := 620.0

var hud: MatchHud
var upgrades_button: Button
var _xp: Label
var _evolve: Button
var _evolve_meter: MatchHud.Meter
var _skill: Button
var _eras: Array[Label] = []
var _clock: Label
var _gold: Label
var _speed: Button
var _pause: Button
var _speed_before_pause := 0


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_left = 12
	offset_right = -12
	offset_top = 6
	offset_bottom = 54
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var left := HBoxContainer.new()
	left.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var xi := MatchHud.Icon.new()
	xi.kind = "xp"
	left.add_child(xi)
	_xp = hud._label(left, "", 18, MatchHud.XP)
	_xp.custom_minimum_size = Vector2(84, 0)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 2)
	left.add_child(ev)
	_evolve = hud._btn(ev, "", func(): hud.feedback(hud.sim.evolve(0)))
	_evolve.custom_minimum_size = Vector2(180, 30)
	_evolve_meter = MatchHud.Meter.new()
	_evolve_meter.col = MatchHud.XP
	_evolve_meter.custom_minimum_size = Vector2(0, 4)
	ev.add_child(_evolve_meter)
	_skill = hud._btn(left, "", func(): hud.feedback(hud.sim.fire_ability(0)))
	_skill.custom_minimum_size = Vector2(250, 34)

	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 18)
	row.add_child(mid)
	for i in 2:
		var era := hud._label(mid, "", 16, hud.view.team_color(i).lightened(0.4), true)
		_eras.append(era)
		if i == 0:
			_clock = hud._label(mid, "0:00", 22, UiStyle.TEXT, true)

	var right := HBoxContainer.new()
	right.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	upgrades_button = Button.new()
	upgrades_button.text = "⬆ Upgrades"
	upgrades_button.toggle_mode = true
	upgrades_button.tooltip_text = "Show or hide the upgrade grid"
	upgrades_button.custom_minimum_size = Vector2(140, 34)
	right.add_child(upgrades_button)
	var gi := MatchHud.Icon.new()
	gi.kind = "gold"
	right.add_child(gi)
	_gold = hud._label(right, "", 18, MatchHud.GOLD)
	_gold.custom_minimum_size = Vector2(130, 0)
	_speed = _small(right, "1×", "Game speed: 1× / 2×", _toggle_speed)
	_pause = _small(right, "❚❚", "Pause", _toggle_pause)
	_pause.toggle_mode = true
	_small(right, "⚙", "Settings (Esc)", hud.open_settings)


func _small(parent: Control, text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(40, 34)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _toggle_speed() -> void:
	var v := hud.view
	if v.speed_index == 2:
		return
	v.set_speed(1 - v.speed_index)


func _toggle_pause() -> void:
	var v := hud.view
	if v.speed_index == 2:
		v.set_speed(_speed_before_pause)
	else:
		_speed_before_pause = v.speed_index
		v.set_speed(2)


func refresh() -> void:
	var sim := hud.sim
	var race := hud.view.race_def(0)
	_xp.text = "%d XP" % sim.sides[0].xp
	var ev := HudModel.evolve_state(sim, 0)
	_evolve.text = ev.text
	_evolve.tooltip_text = ev.tooltip
	_evolve.disabled = not ev.enabled
	_evolve_meter.value = ev.progress
	var sk := HudModel.skill_state(sim, 0, race)
	_skill.text = sk.text
	_skill.tooltip_text = sk.tooltip
	_skill.disabled = not sk.enabled
	for i in 2:
		_eras[i].text = HudModel.era_name(sim, i)
	_clock.text = HudModel.clock(sim)
	_gold.text = HudModel.gold_text(sim, 0)
	_gold.modulate = Color(1, 0.45, 0.45) if hud._flash > 0.0 else Color.WHITE
	_speed.text = "2×" if hud.view.speed_index == 1 else "1×"
	_pause.set_pressed_no_signal(hud.view.speed_index == 2)
```

- [ ] **Step 2: Wire it into MatchHud and remove the old top bar and command-panel duplicates**

In `scripts/view/match_hud.gd`:
- Add `var _top: TopBar` to the fields; delete the fields `_hp`, `_age_labels`, `_clock`, `_tide`, `_gold`, `_xp`, `_ability`, `_evolve`, `_evolve_meter`, `_speed_buttons`.
- In `_ready` replace `_build_top()` with:

```gdscript
	_top = TopBar.new(self)
	_root.add_child(_top)
	_build_minimap()
```

- Replace the whole `func _build_top()` with (the minimap moves to the bottom panel in Task 5; until then it sits under the top bar):

```gdscript
func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.hud = self
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_minimap.offset_left = -300
	_minimap.offset_right = 300
	_minimap.offset_top = 62
	_minimap.offset_bottom = 84
	_root.add_child(_minimap)
```

- In `_build_commands`, delete everything from `var res := HBoxContainer.new()` through the `for i in 3:` speed-button loop **except** the `_income` button, which must stay (Task 3 moves it). Concretely, the body of `_build_commands` after the panel/`v` setup becomes:

```gdscript
	var row3 := HBoxContainer.new()
	v.add_child(row3)
	_income = _btn(row3, "", func(): feedback(sim.buy_upgrade(0, "income", "income")))
	_income.custom_minimum_size = Vector2(170, 34)
	var tl := _label(v, "Turrets — click an empty slot to build, a turret to sell (Q W E R)", 13, Color(1, 1, 1, 0.6))
```

  followed by the unchanged `tl.autowrap_mode …` and turret-slot `row4` code. Change the panel's `p.offset_top = -268` → `p.offset_top = -150`.
- In `_process` delete the `for i in 2:` HP/age block, `_clock.text = …`, `_tide.queue_redraw()`, the `_gold…`/`_flash…`/`_xp…` lines, the whole ability and evolve blocks, and the `for i in 3: _speed_buttons…` loop. Add as the first refresh line after `var me := sim.sides[0]`:

```gdscript
	_top.refresh()
	_flash = maxf(0.0, _flash - delta)
```

- Delete the whole `class TidePips`.
- Update the header comment to: `## Match HUD (GDD §13.9): top bar, upgrade grid, unit cards, lane map with training queue, turret slots,\n## event banners and the post-match screen. Panels render HudModel values; actions go through MatchSim.`

In `scripts/view/match_view.gd` `_hotkey`, delete the `KEY_F1:`, `KEY_F2:`, `KEY_F3:` cases (6 lines).

- [ ] **Step 3: Import, test, screenshot**

Run the import command, the test command (`0 failures`), then the screenshot check with name `hud-t2` and `--after=20`.
Expected: no `SCRIPT ERROR`; a single slim bar across the top: XP, Evolve (with a thin XP meter under it) and the skill button on the left; both era names with the clock between them in the exact centre; Upgrades, gold, `1×`, `❚❚`, `⚙` on the right. No tide pips. The minimap sits just below the bar. The old bottom-right panel now only has the Income button and turret slots.

- [ ] **Step 4: Commit**

```bash
git add scripts/view/hud/top_bar.gd scripts/view/hud/top_bar.gd.uid scripts/view/match_hud.gd scripts/view/match_view.gd
git commit -m "HUD: slim top bar (XP, Evolve, Skill | eras and clock | Upgrades, gold, speed, pause, settings)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Upgrade grid

**Files:**
- Create: `scripts/view/hud/upgrade_grid.gd`
- Modify: `scripts/view/match_hud.gd`

**Interfaces:**
- Consumes: `HudModel.row_label/upgrade_cell`; `MatchSim.UPGRADES`, `MatchSim.buy_upgrade`; `TopBar.upgrades_button`.
- Produces: `class_name UpgradeGrid extends PanelContainer` with `_init(hud: MatchHud)`, `refresh()`. `MatchHud` gains the dev flag `--hud-demo` (opens the grid 2 s into a match, for screenshots; Task 4 extends it).

- [ ] **Step 1: Create the grid**

Create `scripts/view/hud/upgrade_grid.gd`:

```gdscript
class_name UpgradeGrid
extends PanelContainer
## Drop-down upgrade grid under the top bar (GDD §6.1, §13.9): a row per unit slot (named after the
## current era's unit), Turrets and Income; columns ⚔ ♥ 🛡 (➶ Range for turrets). Mouse only; the game
## keeps running while it is open.

const ROWS := ["vanguard", "ranged", "heavy", "siege", "turret", "income"]

var hud: MatchHud
var _labels := {}   # row -> Label
var _cells := {}    # "row:stat" -> Button
var _max_box: StyleBox


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -12
	offset_left = -12
	offset_top = 58
	offset_bottom = 58
	_max_box = UiStyle.box(Color(0.33, 0.26, 0.1), UiStyle.ACCENT)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	hud._label(grid, "")
	for head in ["⚔ Attack", "♥ Health", "🛡 Defence · ➶ Range"]:
		var l := hud._label(grid, head, 14, UiStyle.ACCENT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for row in ROWS:
		var name_label := hud._label(grid, "", 15)
		name_label.custom_minimum_size = Vector2(130, 0)
		_labels[row] = name_label
		var stats: Array = MatchSim.UPGRADES[row]
		for c in 3:
			if c >= stats.size():
				hud._label(grid, "")
				continue
			var stat: String = stats[c]
			var b := Button.new()
			b.custom_minimum_size = Vector2(150, 32)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_font_size_override("font_size", 14)
			b.pressed.connect(func(): hud.feedback(hud.sim.buy_upgrade(0, row, stat)))
			grid.add_child(b)
			_cells["%s:%s" % [row, stat]] = b


func refresh() -> void:
	if not visible:
		return
	var sim := hud.sim
	var race := hud.view.race_def(0)
	for row in ROWS:
		(_labels[row] as Label).text = HudModel.row_label(sim, 0, row, race)
		for stat in MatchSim.UPGRADES[row]:
			var b: Button = _cells["%s:%s" % [row, stat]]
			var cell := HudModel.upgrade_cell(sim, 0, row, stat)
			b.text = cell.text
			b.tooltip_text = cell.tooltip
			b.disabled = not cell.enabled
			if cell.maxed:
				b.add_theme_stylebox_override("disabled", _max_box)
			else:
				b.remove_theme_stylebox_override("disabled")
```

- [ ] **Step 2: Wire it, remove the old Income button, add `--hud-demo`**

In `scripts/view/match_hud.gd`:
- Add `var _grid: UpgradeGrid`. In `_ready`, after `_build_banner()`:

```gdscript
	_grid = UpgradeGrid.new(self)
	_root.add_child(_grid)
	_top.upgrades_button.toggled.connect(func(on: bool): _grid.visible = on)
	# Dev aid for screenshots: open the HUD's pop-ups without clicking.
	if "--hud-demo" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(func(): _top.upgrades_button.button_pressed = true)
```

- In `_process` add `_grid.refresh()` after `_top.refresh()`.
- Delete `var _income: Button`, the `row3`/`_income` lines in `_build_commands`, and the four `inc`/`_income…` lines in `_process`.

- [ ] **Step 3: Import, test, screenshot**

Import, tests (`0 failures`), then screenshot `hud-t3` with `--after=20` and the extra user arg `--hud-demo` (append it after `--autoplay`).
Expected: no `SCRIPT ERROR`; under the right end of the top bar, a panel with a header row (⚔ Attack, ♥ Health, 🛡 Defence · ➶ Range) and six rows: the four current-era unit names (Siege shows "Siege" and greyed cells in Age 1), Turrets, Income (one cell). Cells read like `○○○  12g` or `●●○  40g`; unaffordable ones are greyed; maxed ones show `MAX` with a gold border.

- [ ] **Step 4: Commit**

```bash
git add scripts/view/hud/upgrade_grid.gd scripts/view/hud/upgrade_grid.gd.uid scripts/view/match_hud.gd
git commit -m "HUD: drop-down upgrade grid (15 upgrades) under the top bar

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Turret slots with popups above the slot

**Files:**
- Create: `scripts/view/hud/turret_bar.gd`
- Modify: `scripts/view/match_hud.gd`

**Interfaces:**
- Consumes: `HudModel.slot_state/build_options/sell_value`; `MatchSim.unlock_slot/build_turret/sell_turret`.
- Produces: `class_name TurretBar extends PanelContainer` with `_init(hud: MatchHud)`, `refresh()`, `open_menu(i: int)`. `MatchHud.slot_pressed(i)` (used by the Q W E R hotkeys in `match_view.gd`) delegates to `open_menu`.

- [ ] **Step 1: Create the turret bar**

Create `scripts/view/hud/turret_bar.gd`:

```gdscript
class_name TurretBar
extends PanelContainer
## Bottom-right turret slots (GDD §6, §13.9). Clicking a slot opens, directly above it, either the
## era's turrets to build or a Sell option; clicking the next locked slot unlocks it.

var hud: MatchHud
var _slots: Array[Button] = []
var _popup: PopupPanel
var _options: VBoxContainer


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -12
	offset_right = -12
	offset_top = -12
	offset_bottom = -12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 96)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func(): open_menu(i))
		row.add_child(b)
		_slots.append(b)
	_popup = PopupPanel.new()
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	_popup.add_child(_options)
	add_child(_popup)


func open_menu(i: int) -> void:
	var sim := hud.sim
	var st := HudModel.slot_state(sim, 0, i, hud.view.race_def(0))
	match st.kind:
		"unlock":
			hud.feedback(sim.unlock_slot(0))
			return
		"locked":
			hud.feedback(false)
			return
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()
	if st.kind == "built":
		var t: SimTurret = sim.sides[0].turrets[i]
		_add_option("Sell for %d g" % HudModel.sell_value(sim, t), true, func(): hud.feedback(sim.sell_turret(0, i)))
	else:
		for o in HudModel.build_options(sim, 0, hud.view.race_def(0)):
			var def: TurretDef = o.def
			_add_option(o.text, o.enabled, func(): hud.feedback(sim.build_turret(0, i, def)))
	# Open like a drop-down, directly above the clicked slot, kept on screen.
	var r := _slots[i].get_global_rect()
	_popup.reset_size()
	var sz := Vector2(_popup.get_contents_minimum_size())
	var pos := Vector2(r.position.x + r.size.x * 0.5 - sz.x * 0.5, r.position.y - sz.y - 6.0)
	pos.x = clampf(pos.x, 4.0, get_viewport_rect().size.x - sz.x - 4.0)
	_popup.popup(Rect2i(Vector2i(pos), Vector2i(sz)))


func _add_option(text: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		_popup.hide()
		cb.call())
	_options.add_child(b)


func refresh() -> void:
	var race := hud.view.race_def(0)
	for i in 4:
		var st := HudModel.slot_state(hud.sim, 0, i, race)
		var b := _slots[i]
		b.text = "%s\n%s" % ["QWER"[i], st.text]
		b.tooltip_text = st.tooltip
		if st.get("outclassed", false):
			b.modulate = Color(1, 0.75, 0.6)
		elif st.kind == "locked":
			b.modulate = Color(1, 1, 1, 0.55)
		else:
			b.modulate = Color.WHITE
```

- [ ] **Step 2: Wire it and remove the old command panel**

In `scripts/view/match_hud.gd`:
- Add `var _turrets: TurretBar`. In `_ready` replace `_build_commands()` with:

```gdscript
	_turrets = TurretBar.new(self)
	_root.add_child(_turrets)
```

  and delete the three `_slot_menu` lines at the end of `_ready`.
- Delete the whole `func _build_commands()`, the fields `_slots`, `_slot_menu`, `_slot_menu_index`, and the whole `func _on_slot_menu`.
- Replace `func slot_pressed(i: int)` with:

```gdscript
func slot_pressed(i: int) -> void:
	_turrets.open_menu(i)
```

- In `_process` delete the `for i in 4:` slot loop and add `_turrets.refresh()` after `_grid.refresh()`.
- Extend the `--hud-demo` timer callback to also open slot Q's menu:

```gdscript
		get_tree().create_timer(2.0).timeout.connect(func():
			_top.upgrades_button.button_pressed = true
			_turrets.open_menu(0))
```

- [ ] **Step 3: Import, test, screenshot**

Import, tests (`0 failures`), screenshot `hud-t4` with `--hud-demo`, `--after=20`.
Expected: no `SCRIPT ERROR`; bottom right shows four slot buttons labelled `Q`–`R` (built turret name, `＋ Build`, `🔒 150g`-style unlock price, dimmed `🔒`); a small popup sits directly above slot Q listing either the era's turrets with prices (unaffordable ones greyed) or `Sell for N g`. The old right-hand command panel is gone.

- [ ] **Step 4: Commit**

```bash
git add scripts/view/hud/turret_bar.gd scripts/view/hud/turret_bar.gd.uid scripts/view/match_hud.gd
git commit -m "HUD: bottom-right turret slots with build/sell popups above the slot

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Unit cards and the lane panel (lane map, training, queue)

**Files:**
- Create: `scripts/view/hud/unit_bar.gd`, `scripts/view/hud/lane_panel.gd`
- Modify: `scripts/view/match_hud.gd`

**Interfaces:**
- Consumes: `HudModel.unit_tooltip`; `MatchSim.roster/queue_unit/can_queue/unit_price`; `UnitArt.height_for/begin/draw_unit`; `MatchView._cam_x`, `MatchView.camera`.
- Produces: `class_name UnitBar extends PanelContainer` and `class_name LanePanel extends PanelContainer`, each with `_init(hud: MatchHud)` and `refresh()`. `MatchHud.matrix_tooltip` is removed (replaced by `HudModel.unit_tooltip`).

- [ ] **Step 1: Create the unit bar**

Create `scripts/view/hud/unit_bar.gd`:

```gdscript
class_name UnitBar
extends PanelContainer
## Bottom-left unit cards (GDD §13.9): portrait, name, price and hotkey 1–4; click to queue.

const CARD := Vector2(112, 100)

var hud: MatchHud
var _cards: Array[UnitCard] = []


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 12
	offset_right = 12
	offset_top = -12
	offset_bottom = -12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in 4:
		var c := UnitCard.new()
		c.hud = hud
		c.index = i
		c.custom_minimum_size = CARD
		c.pressed.connect(func(): hud.feedback(hud.sim.queue_unit(0, hud.sim.roster(0)[i]) if i < hud.sim.roster(0).size() else false))
		row.add_child(c)
		_cards.append(c)


func refresh() -> void:
	for c in _cards:
		c.refresh()
		c.queue_redraw()


class UnitCard extends Button:
	var hud: MatchHud
	var index := 0

	func refresh() -> void:
		var roster := hud.sim.roster(0)
		if index >= roster.size():
			disabled = true
			tooltip_text = "No %s this era" % HudModel.ROLE_NAME[MatchSim.ROLES[index]]
			return
		var u := roster[index]
		disabled = not hud.sim.can_queue(0, u)
		tooltip_text = HudModel.unit_tooltip(hud.sim, 0, u, hud.view.race_def(0))

	func _draw() -> void:
		var sim := hud.sim
		var roster := sim.roster(0)
		var f := UiStyle.font("bold")
		draw_string(f, Vector2(6, 16), "%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MatchHud.ACCENT)
		if index >= roster.size():
			draw_string(f, Vector2(0, size.y * 0.5), "Siege from %s" % sim.data.age(2).display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(1, 1, 1, 0.3))
			return
		var u := roster[index]
		var race := hud.view.race_of(0)
		var h := UnitArt.height_for(u, race)
		var sc := clampf((size.y - 46.0) / h, 0.35, 1.0)
		UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(size.x * 0.5, size.y - 36.0)))
		UnitArt.draw_unit(self, u, hud.view.team_color(0), {"walk": 0.0, "moving": false, "atk": -1.0, "t": Time.get_ticks_msec() / 1000.0, "flash": 0.0}, index + 3, race)
		draw_set_transform(Vector2.ZERO)
		var col := Color.WHITE if not disabled else Color(1, 1, 1, 0.4)
		draw_string(f, Vector2(0, size.y - 20.0), hud.view.race_def(0).unit_name(u), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, col)
		draw_string(f, Vector2(0, size.y - 5.0), "%d g" % sim.unit_price(0, u), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, MatchHud.GOLD if not disabled else Color(MatchHud.GOLD, 0.4))
```

- [ ] **Step 2: Create the lane panel**

Create `scripts/view/hud/lane_panel.gd`:

```gdscript
class_name LanePanel
extends PanelContainer
## Bottom-centre panel (GDD §13.9): the lane map (both gates, a dot per unit, the camera window; click to
## move the camera) and under it the unit in training with its progress and the 5-slot queue.

## Horizontal room left for the unit cards and the turret slots at 1920 px.
const LEFT := 512.0
const RIGHT := 486.0

var hud: MatchHud
var _map: LaneMap
var _train: TrainRow


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = LEFT
	offset_right = -RIGHT
	offset_top = -12
	offset_bottom = -12
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_map = LaneMap.new()
	_map.hud = hud
	_map.custom_minimum_size = Vector2(0, 30)
	v.add_child(_map)
	_train = TrainRow.new()
	_train.hud = hud
	_train.custom_minimum_size = Vector2(0, 40)
	v.add_child(_train)


func refresh() -> void:
	_map.queue_redraw()
	_train.queue_redraw()


class LaneMap extends Control:
	var hud: MatchHud

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			hud.view._cam_x = e.position.x / size.x * hud.sim.rules.lane_length

	func _draw() -> void:
		var sim := hud.sim
		var lane := sim.rules.lane_length
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		var fx := sim.front_x / lane * size.x
		draw_rect(Rect2(0, 0, fx, size.y), Color(hud.view.team_color(0), 0.18))
		draw_rect(Rect2(fx, 0, size.x - fx, size.y), Color(hud.view.team_color(1), 0.18))
		for i in 2:
			draw_rect(Rect2(0.0 if i == 0 else size.x - 5.0, 0, 5, size.y), hud.view.team_color(i))
		for s in sim.sides:
			for u in s.units:
				var x := sim.to_world(u.side, u.progress) / lane * size.x
				var r := 3.5 if u.def.role == "heavy" else 2.5
				draw_circle(Vector2(x, size.y * 0.5 + (u.id % 3 - 1) * 4), r, hud.view.team_color(u.side).lightened(0.3))
		draw_line(Vector2(fx, 0), Vector2(fx, size.y), Color.WHITE, 2.0)
		var vp := hud.view.get_viewport_rect().size
		var cx := hud.view.camera.get_screen_center_position().x
		var a := (cx - vp.x * 0.5) / lane * size.x
		var b := (cx + vp.x * 0.5) / lane * size.x
		draw_rect(Rect2(a, 0, b - a, size.y), Color(1, 1, 1, 0.6), false, 1.0)


class TrainRow extends Control:
	var hud: MatchHud

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sim := hud.sim
		var me := sim.sides[0]
		var race := hud.view.race_of(0)
		var f := UiStyle.font("bold")
		var dim := Color(1, 1, 1, 0.55)
		var y := size.y * 0.5 + 5.0
		draw_string(f, Vector2(4, y), "Training", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)
		var bar := Rect2(170, size.y * 0.5 - 5.0, 150, 10)
		draw_rect(bar, Color(0, 0, 0, 0.5))
		if me.queue.is_empty():
			draw_string(f, Vector2(80, y), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)
		else:
			var d := me.queue[0]
			draw_string(f, Vector2(80, y), hud.view.race_def(0).unit_name(d), HORIZONTAL_ALIGNMENT_LEFT, 86, 14, UiStyle.TEXT)
			var p := 0.0 if me.is_evolving() else clampf(me.train_progress / d.train_time, 0.0, 1.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), MatchHud.ACCENT)
		draw_rect(bar, Color(1, 1, 1, 0.2), false, 1.0)
		draw_string(f, Vector2(336, y), "Queue", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)
		for i in sim.rules.queue_slots:
			var r := Rect2(390 + i * 36, size.y * 0.5 - 15.0, 30, 30)
			draw_rect(r, Color(0, 0, 0, 0.4))
			if i < me.queue.size():
				var q := me.queue[i]
				var sc := 24.0 / UnitArt.height_for(q, race)
				UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, r.position + Vector2(15, 28)))
				UnitArt.draw_unit(self, q, hud.view.team_color(0), {"t": 0.0}, i, race)
				draw_set_transform(Vector2.ZERO)
			draw_rect(r, MatchHud.ACCENT if i == 0 and not me.queue.is_empty() else Color(1, 1, 1, 0.15), false, 1.0)
		draw_string(f, Vector2(390 + sim.rules.queue_slots * 36 + 12, y), "On field %d/%d" % [me.units.size(), sim.rules.field_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)
```

- [ ] **Step 3: Wire them and remove the old cards, queue strip and top minimap**

In `scripts/view/match_hud.gd`:
- Add `var _units: UnitBar` and `var _lane: LanePanel`. In `_ready` replace `_build_minimap()` with nothing and `_build_cards()` with:

```gdscript
	_units = UnitBar.new(self)
	_root.add_child(_units)
	_lane = LanePanel.new(self)
	_root.add_child(_lane)
```

  keeping the order so the upgrade grid (added later in `_ready`) draws above them.
- Delete `func _build_minimap()`, `func _build_cards()`, `func matrix_tooltip()`, the fields `_minimap`, `_cards`, `_queue`, and the classes `Minimap`, `UnitCard`, `QueueStrip`.
- In `_process` delete the `for c in _cards:` loop, `_queue.queue_redraw()` and `_minimap.queue_redraw()`; add `_units.refresh()` and `_lane.refresh()` after `_turrets.refresh()`.

- [ ] **Step 4: Import, test, screenshot**

Import, tests (`0 failures`), screenshot `hud-t5` with `--hud-demo`, `--after=30`.
Expected: no `SCRIPT ERROR`; bottom left four smaller unit cards (number, portrait, name, price); bottom centre the lane map (blue gate left, orange gate right, dots, white camera window) and under it `Training <unit> [progress bar]  Queue [5 boxes, first outlined gold]  On field n/30`; bottom right the turret slots. Nothing overlaps; the middle of the battlefield is clear.

- [ ] **Step 5: Commit**

```bash
git add scripts/view/hud/unit_bar.gd scripts/view/hud/unit_bar.gd.uid scripts/view/hud/lane_panel.gd scripts/view/hud/lane_panel.gd.uid scripts/view/match_hud.gd
git commit -m "HUD: smaller unit cards bottom-left; lane map with training and queue bottom-centre

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Base HP bars in the world, upgrade markers, docs, owner review

**Files:**
- Modify: `scripts/view/world_layer.gd`, `scripts/view/post_match_graphs.gd`, `docs/PLAN.md`, `docs/tasks/M1b.md`

- [ ] **Step 1: Base HP bars above each base**

In `scripts/view/world_layer.gd` add the constants near the top (after `extends`/existing constants):

```gdscript
## Base HP bar above each base (GDD §13.9), in world space: centred this far behind the gate, this high.
const BASE_BAR_BACK := 110.0
const BASE_BAR_HEIGHT := 470.0
const BASE_BAR_SIZE := Vector2(230, 12)
```

In `_draw_overlay`, after the unit HP-bar loop, add:

```gdscript
	for s in sim.sides:
		_draw_base_bar(_overlay, s)
```

and add the function:

```gdscript
func _draw_base_bar(ci: CanvasItem, s: SimSide) -> void:
	var dir := 1.0 if s.index == 0 else -1.0
	var centre := Vector2(view.sim.to_world(s.index, 0.0) - dir * BASE_BAR_BACK, GROUND_Y - BASE_BAR_HEIGHT)
	var r := Rect2(centre - BASE_BAR_SIZE * 0.5, BASE_BAR_SIZE)
	ci.draw_rect(r.grow(2.0), Color(0, 0, 0, 0.7))
	var frac := clampf(s.base_hp / s.base_max_hp, 0.0, 1.0)
	var fill := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
	if s.index == 1:
		fill.position.x = r.end.x - fill.size.x
	ci.draw_rect(fill, view.team_color(s.index))
	ci.draw_string(_font, Vector2(r.position.x, r.position.y - 4.0), "%d / %d" % [s.base_hp, s.base_max_hp], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(1, 1, 1, 0.85))
```

- [ ] **Step 2: Upgrade markers on the post-match graphs**

In `scripts/view/post_match_graphs.gd` change `{"evolve": "E", "ability": "A"}` → `{"evolve": "E", "ability": "A", "upgrade": "U"}` and the header comment's `markers for evolutions and abilities` → `markers for evolutions, abilities and upgrades`.

- [ ] **Step 3: Screenshot and tune the bar position**

Screenshot `hud-t6` with `--after=30` (no `--hud-demo`). Expected: no `SCRIPT ERROR`; a thin team-coloured HP bar with `current / max` text floats above each base (fully visible, not under the top bar, not overlapping the base's roof badly). If it is clipped or badly placed, adjust `BASE_BAR_BACK` / `BASE_BAR_HEIGHT` and re-shoot; record the final values in the commit message.

- [ ] **Step 4: Docs**

In `docs/PLAN.md` §10, replace the `scripts/view/match_hud.gd` row with:

```markdown
| `scripts/view/match_hud.gd`, `scripts/view/hud/` | HUD per GDD §13.9: `TopBar` (XP, Evolve, Skill · eras and clock · Upgrades, gold, speed, pause, settings), `UpgradeGrid` (drop-down, 15 upgrades), `UnitBar` (cards), `LanePanel` (lane map, training, queue), `TurretBar` (slots with build/sell popups above the slot). `HudModel` holds every display rule as plain data and is unit-tested. `MatchHud` keeps the theme, banners, feedback, settings and post-match screen. Dev flag `--hud-demo` opens the grid and a slot popup for screenshots |
```

In `docs/tasks/M1b.md` set `M1b-8` to `✅ built — owner reviews locally`.

- [ ] **Step 5: Final checks and commit**

Run the tests (`0 failures`) and the data validator. Then:

```bash
git add scripts/view/world_layer.gd scripts/view/post_match_graphs.gd docs/PLAN.md docs/tasks/M1b.md
git commit -m "Base HP bars above the bases; upgrade markers on post-match graphs; HUD docs

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Owner review**

Ask the owner to play one match locally and check: the layout matches the approved mockup; clicking the battlefield with the grid or a popup open still pans/right-drags (Review Focus 5); popups open above the right slot and close on an outside click; the skill button's tooltip explains why it is disabled; text is readable at their resolution.

---

### Task 7: Restart and End game in the in-match settings panel

Added at the owner's request (2026-09-27): during a match, the settings panel (⚙ or Esc) offers **Restart match** and **End game** (back to the main menu), each behind a confirmation.

**Files:**
- Modify: `scripts/view/settings.gd`, `scripts/view/match_hud.gd`

**Interfaces:**
- Consumes: `MatchView.rematch` and `MatchView.exit_to_menu` signals (already handled by `main.gd`: rematch starts a fresh match with the same opponent; exit shows the menu).
- Produces: `GameSettings.make_panel(on_close: Callable, extra: Control = null) -> PanelContainer` — `extra` is inserted above the Done button. `MatchHud` gains `--hud-demo-settings` (opens the in-match settings 2 s in, for a screenshot).

- [ ] **Step 1: Let the settings panel take extra controls**

In `scripts/view/settings.gd` change the signature to `static func make_panel(on_close: Callable, extra: Control = null) -> PanelContainer:` and insert before `var close := Button.new()`:

```gdscript
	if extra != null:
		v.add_child(extra)
```

Change `p.offset_top = -220` → `p.offset_top = -250` and `p.offset_bottom = 210` → `p.offset_bottom = 250` so the extra row fits.

- [ ] **Step 2: Add the match buttons with confirmation**

In `scripts/view/match_hud.gd` replace `var panel := GameSettings.make_panel(func(): …)` in `open_settings` with:

```gdscript
	var panel := GameSettings.make_panel(func():
		_settings_open = false
		view.apply_settings()
		view.set_speed(_speed_before), _match_actions())
```

and add:

```gdscript
## Restart / End game row for the in-match settings panel; each asks for confirmation first.
func _match_actions() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for spec in [["↻ Restart match", "Restart this match? The current match is lost.", view.rematch],
			["✕ End game", "End this match and return to the main menu?", view.exit_to_menu]]:
		var b := Button.new()
		b.text = spec[0]
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		var ask := ConfirmationDialog.new()
		ask.dialog_text = spec[1]
		ask.ok_button_text = "Yes"
		ask.cancel_button_text = "No"
		var sig: Signal = spec[2]
		ask.confirmed.connect(func(): sig.emit())
		b.add_child(ask)
		b.pressed.connect(func(): ask.popup_centered())
		row.add_child(b)
	return row
```

In `_ready`, next to the `--hud-demo` check, add:

```gdscript
	if "--hud-demo-settings" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(open_settings)
```

- [ ] **Step 3: Screenshot and play-check**

Tests (`0 failures`), then screenshot `hud-t7` with `--hud-demo-settings --after=5`. Expected: no `SCRIPT ERROR`; the centred Settings panel shows the sliders, options, a row with **↻ Restart match** and **✕ End game**, then **Done**. (The confirmation dialogs and the actual restart/exit are checked in the owner review: Restart starts a fresh match against the same opponent; End game returns to the main menu; No/closing the dialog leaves the match paused under the settings panel.)

- [ ] **Step 4: Commit**

```bash
git add scripts/view/settings.gd scripts/view/match_hud.gd
git commit -m "Settings during a match: Restart match and End game, each with confirmation

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```
