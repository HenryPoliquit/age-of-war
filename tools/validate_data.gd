extends SceneTree
## Schema/consistency check for data/*.tres (GDD §15.1). Exits 1 on any problem.
##   tools/godot --headless --path . -s tools/validate_data.gd

var problems: Array[String] = []


func _init() -> void:
	var gd := GameData.get_default()
	_check(gd.rules != null, "rules.tres loads")
	var r := gd.rules
	_check(r.tide_start_times.size() == r.tide_multipliers.size(), "tide arrays same length")
	for i in range(1, r.tide_start_times.size()):
		_check(r.tide_start_times[i] > r.tide_start_times[i - 1], "tide times increase")
		_check(r.tide_multipliers[i] > r.tide_multipliers[i - 1], "tide multipliers increase")
	_check(r.veterancy_fractions.size() == 3, "three veterancy ranks")
	_check(r.turret_slot_costs.size() >= 5, "turret slot costs for 5 slots")
	for dt in ["slash", "pierce", "blast", "siege"]:
		for arm in ["light", "heavy", "structure"]:
			_check(r.damage_matrix.has(dt) and r.damage_matrix[dt].has(arm), "matrix %s/%s" % [dt, arm])
	var ids := {}
	_check(gd.ages.size() == GameData.AGE_COUNT, "six ages")
	for a in gd.ages:
		var tag := "age %d" % a.index
		_check(a.display_name != "", tag + " name")
		_check(a.base_max_hp > 0, tag + " base HP")
		_check(a.index == 1 or a.evolve_cost > 0, tag + " evolve cost")
		_check(a.veterancy_base_xp > 0, tag + " veterancy base")
		_check(a.ability != null and a.ability.age == a.index, tag + " ability")
		var roles := {}
		for u in a.units:
			var ut := "unit %s" % u.id
			_check(not ids.has(u.id), ut + " id unique")
			ids[u.id] = true
			_check(u.age == a.index, ut + " age matches its age file")
			_check(not roles.has(u.role), ut + " one unit per role per age")
			roles[u.role] = true
			for f in ["cost", "train_time", "hp", "damage", "attack_interval", "range", "speed"]:
				_check(float(u.get(f)) > 0.0, "%s %s > 0" % [ut, f])
			_check(u.momentum_on_kill > 0, ut + " momentum_on_kill")
			_check(u.min_range < u.range, ut + " min_range < range")
			_check(r.damage_matrix.has(u.damage_type), ut + " damage type in matrix")
		_check(roles.has("vanguard") and roles.has("ranged") and roles.has("heavy"), tag + " core roles")
		_check(a.index == 1 or roles.has("siege"), tag + " siege from Age 2")
		for t in a.turrets:
			var tt := "turret %s" % t.id
			_check(not ids.has(t.id), tt + " id unique")
			ids[t.id] = true
			_check(t.age == a.index and t.cost > 0 and t.hp > 0, tt + " age/cost/hp")
			if t.kind == "support":
				_check(t.aura_radius > 0 and t.aura_slow > 0, tt + " aura")
			else:
				_check(t.damage > 0 and t.attack_interval > 0 and t.range > t.min_range, tt + " attack stats")
		for d in a.doctrine_options:
			_check(d.pick_age == a.index, "doctrine %s pick_age" % d.id)
	for id in gd.personalities:
		var p: AiPersonalityDef = gd.personalities[id]
		_check(p.age_plan in ["balanced", "fast", "strong"], "personality %s age_plan" % id)
		for pref in p.doctrine_prefs:
			_check(gd.doctrines.has(pref), "personality %s doctrine pref %s exists" % [id, pref])
	for id in gd.difficulties:
		var d: AiDifficultyDef = gd.difficulties[id]
		_check(d.decision_interval > 0, "difficulty %s interval" % id)
		_check(d.income_bonus == 0.0 or id in [&"brutal", &"nightmare"], "difficulty %s: only Brutal/Nightmare get bonuses (GDD §11.1)" % id)
	if problems.is_empty():
		print("data OK: %d ages, %d ids, %d personalities, %d difficulties" % [gd.ages.size(), ids.size(), gd.personalities.size(), gd.difficulties.size()])
	else:
		for p in problems:
			print("INVALID: ", p)
	quit(0 if problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		problems.append(what)
