class_name HudModel
extends RefCounted
## What the match HUD shows, as plain data (GDD §13.9). The HUD's panels only render these values and
## call MatchSim commands, so the display rules are testable headless (tests/test_hud_model.gd).

const ROLE_NAME := {"vanguard": "Vanguard", "ranged": "Ranged", "heavy": "Heavy", "siege": "Siege"}
const STAT_ICON := {"attack": "⚔", "health": "♥", "defence": "🛡"}
const STAT_NAME := {"attack": "Attack", "health": "Health", "defence": "Defence"}
const RESEARCH_GROUPS := {"fortify": "Fortifications", "logistics": "Logistics", "skills": "Skills", "ascension": "Ascension"}
const SHAPE_TEXT := {
	"area": "strikes the biggest enemy group",
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


## Upgrade-grid row heading: the current era's unit in that slot.
static func row_label(sim: MatchSim, side: int, row: String, race: RaceDef) -> String:
	var def := sim.data.unit_for_role(sim.sides[side].age, row)
	return race.unit_name(def) if def != null else ROLE_NAME[row]


## One upgrade-grid cell: {text, tooltip, enabled, maxed}. Effects in tooltips are totals after the level.
static func upgrade_cell(sim: MatchSim, side: int, row: String, stat: String) -> Dictionary:
	var level := sim.upgrade_level(side, row, stat)
	var levels := sim.rules.upgrade_cost_factors.size()
	var cost := sim.upgrade_cost(side, row, stat)
	var title := "%s %s %s" % [ROLE_NAME[row], STAT_ICON[stat], STAT_NAME[stat]]
	var subject := " for all %s units, every era" % ROLE_NAME[row]
	if level >= levels:
		return {"text": pips(level, levels) + "  MAX", "enabled": false, "maxed": true,
			"tooltip": "%s: level %d (max) — %s%s." % [title, level, _effect(sim, stat, level), subject]}
	if is_inf(cost):
		return {"text": pips(level, levels), "enabled": false, "maxed": false,
			"tooltip": "No %s unit this era yet." % ROLE_NAME.get(row, row)}
	return {"text": "%s  %dg" % [pips(level, levels), cost], "enabled": sim.can_buy_upgrade(side, row, stat), "maxed": false,
		"tooltip": "%s %d → %d: %s%s — %d g" % [title, level, level + 1, _effect(sim, stat, level + 1), subject, cost]}


static func _effect(sim: MatchSim, stat: String, level: int) -> String:
	var r := sim.rules
	match stat:
		"attack":
			return "+%d%% damage" % roundi(r.upgrade_attack_bonus * level * 100.0)
		"health":
			return "+%d%% health" % roundi(r.upgrade_health_bonus * level * 100.0)
		_:
			return "−%d%% damage taken" % roundi(r.upgrade_defence_bonus * level * 100.0)


## One research cell (GDD §6.2): {text, tooltip, enabled, maxed, locked}. `text` is two lines: the perk and
## its level pips with the XP price (or MAX / the era that opens it).
static func research_cell(sim: MatchSim, side: int, id: StringName) -> Dictionary:
	var def := sim.data.research_def(id)
	var level := sim.research_level(side, id)
	var head := def.display_name
	var now := research_effect(sim, def, level)
	if def.is_maxed(level):
		return {"text": "%s\n%s  MAX" % [head, pips(level, def.levels)], "enabled": false, "maxed": true, "locked": false,
			"tooltip": "%s: level %d (max) — %s.\n%s" % [head, level, now, def.description]}
	var counter := ("Lv %d" % level) if def.is_endless() else pips(level, def.levels)
	if sim.research_locked(side, id):
		var era := sim.data.age(def.age_for_next(level)).display_name
		return {"text": "%s\n🔒 %s Age" % [head, era], "enabled": false, "maxed": false, "locked": true,
			"tooltip": "%s: level %d opens in the %s Age.\n%s" % [head, level + 1, era, def.description]}
	var cost := sim.research_cost(side, id)
	var tip := "%s %d → %d: %s — %d XP\n%s" % [head, level, level + 1, research_effect(sim, def, level + 1), cost, def.description]
	if not def.is_endless() and level == 0:
		tip += "\nEach level is priced off the XP your next evolution costs, so it gets dearer the later you buy it."
	return {"text": "%s\n%s  %d XP" % [head, counter, cost], "enabled": sim.can_buy_research(side, id), "maxed": false, "locked": false,
		"tooltip": tip}


## What a perk gives in total at `level`, in words.
static func research_effect(sim: MatchSim, def: ResearchDef, level: int) -> String:
	var pct := roundi(def.bonus * level * 100.0)
	match def.id:
		&"turret_attack":
			return "+%d%% turret damage" % pct
		&"turret_health":
			return "+%d%% turret health" % pct
		&"turret_range":
			return "+%d%% turret range (Support auras too)" % pct
		&"base_health":
			return "+%d%% base health" % pct
		&"train_speed":
			return "+%d%% training speed" % pct
		&"queue_slots":
			return "%d queue slots (+%d)" % [sim.rules.queue_slots + roundi(def.bonus * level), roundi(def.bonus * level)]
		&"income":
			return "+%d%% gold income" % pct
		&"skill_damage":
			return "+%d%% skill damage" % pct
		&"skill_zone":
			return "+%d%% area-skill size (sweeps already cover the whole lane)" % pct
		_:
			return "+%d%% damage and health for all units" % pct


## True when some research level is open and affordable: the Research button hints at it.
static func research_ready(sim: MatchSim, side: int) -> bool:
	for def in sim.data.research:
		if sim.can_buy_research(side, def.id):
			return true
	return false


## What a skill does to each unit it hits, in words: damage mode, hits per unit, knockback.
## `power` is the caster's Skill Damage multiplier.
static func skill_effect_text(ab: AbilityDef, power := 1.0) -> String:
	# A sweep's slices cross each unit once; every other shape hits it on every pulse.
	var hits := 1 if ab.shape == "sweep" else ab.pulses
	var times := "" if hits == 1 else " × %d" % hits
	var text := ""
	match ab.damage_mode:
		"percent":
			text = "%d%% of each unit's max health%s, ignoring armour" % [roundi(ab.damage_pct * power * 100.0), times]
		"true":
			text = "%d true damage%s, ignoring armour and Defence" % [roundi(ab.damage * power), times]
		_:
			text = "%d %s damage%s (armour applies)" % [roundi(ab.damage * power), ab.damage_type, times]
	if ab.knockback >= 20.0:
		text += "; shoves units back"
	return text


## Where the skill lands, in words.
## `width` is the zone length with the caster's Skill Zone research (default: the skill's own).
static func skill_aim_text(ab: AbilityDef, width := -1.0) -> String:
	if ab.is_targeted():
		var shape := "a circle" if SkillLook.footprint(ab.id) == "circle" else "a field of land"
		return "aimed: press it, then click a spot on the lane (%s, %d px wide). Press Space again to let the game aim" % [shape, roundi(ab.width if width < 0.0 else width)]
	return SHAPE_TEXT[ab.shape]


## The Skill button: {text, tooltip, enabled}. `aiming` = aim mode is open (the button then cancels it).
static func skill_state(sim: MatchSim, side: int, race: RaceDef, aiming := false) -> Dictionary:
	var s := sim.sides[side]
	var ab := sim.ability_def(side)
	var skill := race.ability_name(ab)
	var has_target := not sim.ability_zone(side).is_empty()
	var text := "%s %s · %d XP" % ["◎" if ab.is_targeted() else "☄", skill, ab.xp_cost]
	if aiming:
		text = "✕ Cancel aim"
	elif s.ability_cooldown > 0.0:
		text += " · %ds" % ceili(s.ability_cooldown)
	var tip := "%s [Space]: %s.\nDeals %s.\nCosts %d XP; %d s cooldown." % [skill, skill_aim_text(ab, sim.ability_width(side)), skill_effect_text(ab, sim.skill_damage_mult(side)), ab.xp_cost, roundi(sim.rules.ability_cooldown)]
	if not has_target:
		tip += "\nNo enemy units to hit."
	return {"text": text, "tooltip": tip, "enabled": (sim.can_fire_ability(side) and has_target) or aiming}


## The line shown while aiming: what the cursor would hit. `preview` is SkillAim.preview().
static func aim_hint(sim: MatchSim, side: int, race: RaceDef, preview: Dictionary) -> String:
	var skill := race.ability_name(sim.ability_def(side))
	var head := "AIM %s  ·  click to fire  ·  Space: aim for me  ·  Esc: cancel" % skill.to_upper()
	if preview.is_empty():
		return head + "\nMove the cursor over the battlefield"
	if preview.count == 0:
		return head + "\nNo enemy units in the zone"
	return head + "\n%d enemy unit%s in the zone (%d g of army)" % [preview.count, "" if preview.count == 1 else "s", roundi(preview.value)]


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
	var asc := sim.research_level(side, &"ascension")
	if asc > 0:
		ups.append("✦ Ascension %d" % asc)
	if not ups.is_empty():
		text += "\nUpgrades: " + "  ".join(ups)
	return text


## Damage multipliers of this side's units (rows) against the enemy's current units and structures
## (columns), from the damage × armour matrix (GDD §5.2). {cols: [String], rows: [{name, mults: [float]}]}.
static func matchup_table(sim: MatchSim, side: int, race: RaceDef, enemy_race: RaceDef) -> Dictionary:
	var enemy := sim.enemy_of(side)
	var cols: Array[String] = []
	var armours: Array[String] = []
	for u in sim.roster(enemy):
		cols.append("%s (%s)" % [enemy_race.unit_name(u), u.armour])
		armours.append(u.armour)
	cols.append("Structures")
	armours.append("structure")
	var rows: Array[Dictionary] = []
	for u in sim.roster(side):
		var mults: Array[float] = []
		for a in armours:
			mults.append(sim.rules.matrix(u.damage_type, a))
		rows.append({"name": "%s (%s)" % [race.unit_name(u), u.damage_type], "mults": mults})
	return {"cols": cols, "rows": rows}
