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
	_check(r.turret_slot_costs.size() == 4 and r.turret_slot_costs[0] == 0, "4 turret slots, the first free")
	_check(r.start_turret_slots == 1, "one slot at start")
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
		_check(a.ability != null and a.ability.age == a.index, tag + " ability")
		if a.ability != null:
			var ab := a.ability
			_check(ab.shape in ["area", "sweep"] and ab.xp_cost > 0 and ab.pulses >= 1, tag + " skill shape/cost/pulses")
			_check(ab.shape == "sweep" or ab.width > 0, tag + " skill width")
			_check(ab.aim in ["auto", "target"], tag + " skill aim")
			_check(ab.aim == "auto" or ab.shape == "area", tag + " only an area skill can be aimed")
			_check(ab.damage_mode in ["flat", "true", "percent"], tag + " skill damage mode")
			_check(ab.damage_mode == "percent" or ab.damage > 0, tag + " flat/true skill has damage")
			_check(ab.damage_mode != "percent" or (ab.damage_pct > 0.0 and ab.damage_pct <= 1.0), tag + " percent skill has damage_pct in (0, 1]")
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
	# Races are cosmetic (GDD §5.7): every slot needs a name in every race.
	_check(gd.races.has(&"human"), "human race exists (fallback)")
	for rid in gd.races:
		var rd: RaceDef = gd.races[rid]
		_check(rd.id == rid and rd.display_name != "", "race %s id/name" % rid)
		for a in gd.ages:
			for u in a.units:
				_check(rd.unit_names.has(String(u.id)), "race %s names unit %s" % [rid, u.id])
			for t in a.turrets:
				_check(rd.turret_names.has(String(t.id)), "race %s names turret %s" % [rid, t.id])
			_check(rd.ability_names.has(String(a.ability.id)), "race %s names ability %s" % [rid, a.ability.id])
	var research_ids := {}
	_check(gd.research.size() >= 1, "research perks load")
	for d in gd.research:
		var rt := "research %s" % d.id
		_check(not research_ids.has(d.id), rt + " id unique")
		research_ids[d.id] = true
		_check(d.display_name != "" and d.description != "", rt + " name and description")
		_check(d.group in ["fortify", "logistics", "skills", "ascension"], rt + " group")
		_check(d.bonus > 0.0, rt + " bonus")
		_check(d.levels >= 0 and not d.cost_factors.is_empty() and not d.min_ages.is_empty(), rt + " levels/prices/ages")
		_check(d.is_endless() or (d.cost_factors.size() == d.levels and d.min_ages.size() == d.levels), rt + " one price and one era per level")
		_check(not d.is_endless() or d.cost_growth > 1.0, rt + " endless perk gets dearer")
		for i in range(1, d.cost_factors.size()):
			_check(d.cost_factors[i] > d.cost_factors[i - 1], rt + " prices rise")
		for i in range(1, d.min_ages.size()):
			_check(d.min_ages[i] >= d.min_ages[i - 1], rt + " eras do not go backwards")
		for age in d.min_ages:
			_check(age >= 2 and age <= GameData.AGE_COUNT, rt + " era in 2..6")
		if d.id == &"queue_slots":
			_check(is_equal_approx(d.bonus, 1.0) and d.levels == 3, rt + " is +1 slot a level, three levels")
		if d.id in [&"skill_damage", &"skill_zone"]:
			_check(d.bonus * d.levels <= 0.1501, rt + " is capped at +15%")
	for need in ["turret_attack", "turret_health", "turret_range", "base_health", "train_speed", "queue_slots", "income", "skill_damage", "skill_zone", "ascension"]:
		_check(research_ids.has(StringName(need)), "research %s exists" % need)
	for id in gd.personalities:
		var p: AiPersonalityDef = gd.personalities[id]
		_check(p.age_plan in ["balanced", "fast"], "personality %s age_plan" % id)
		for rid in p.research_priority:
			_check(research_ids.has(StringName(rid)), "personality %s research %s exists" % [id, rid])
	for id in gd.difficulties:
		var d: AiDifficultyDef = gd.difficulties[id]
		_check(d.decision_interval > 0, "difficulty %s interval" % id)
		_check(d.income_bonus == 0.0 or id in [&"brutal", &"nightmare"], "difficulty %s: only Brutal/Nightmare get bonuses (GDD §11.1)" % id)
	if problems.is_empty():
		print("data OK: %d ages, %d ids, %d races, %d personalities, %d difficulties, %d research perks" % [gd.ages.size(), ids.size(), gd.races.size(), gd.personalities.size(), gd.difficulties.size(), gd.research.size()])
	else:
		for p in problems:
			print("INVALID: ", p)
	quit(0 if problems.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		problems.append(what)
