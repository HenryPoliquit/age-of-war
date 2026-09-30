extends TestCase


func test_six_ages_with_rosters() -> void:
	var gd := GameData.get_default()
	check_eq(gd.ages.size(), 6)
	check_eq(gd.age(1).units.size(), 3, "Age 1 has no Siege")
	for i in range(2, 7):
		check_eq(gd.age(i).units.size(), 4, "age %d roster" % i)
		check(gd.age(i).ability != null, "age %d ability" % i)


func test_unit_fields_positive() -> void:
	for a in GameData.get_default().ages:
		for u in a.units:
			check(u.cost > 0 and u.hp > 0 and u.damage > 0 and u.attack_interval > 0 and u.range > 0 and u.speed > 0 and u.train_time > 0,
				"%s has a zero stat" % u.id)
			check_eq(u.age, a.index, "%s age" % u.id)


func test_matrix_unit_multipliers_within_bounds() -> void:
	# GDD §5.2: no unit-vs-unit multiplier outside 0.5–1.5.
	var r := GameData.get_default().rules
	for dt in r.damage_matrix:
		for arm in ["light", "heavy"]:
			var m := r.matrix(dt, arm)
			check(m >= 0.5 and m <= 1.5, "%s vs %s = %s" % [dt, arm, m])


func test_base_hp_scales_1_7() -> void:
	var gd := GameData.get_default()
	for i in range(2, 7):
		check_near(gd.age(i).base_max_hp / gd.age(i - 1).base_max_hp, 1.7, 0.01)


func test_evolution_costs_increase() -> void:
	var gd := GameData.get_default()
	for i in range(3, 7):
		check(gd.age(i).evolve_cost > gd.age(i - 1).evolve_cost, "age %d cost" % i)


func test_every_skill_has_shape_and_cost() -> void:
	for a in GameData.get_default().ages:
		var ab := a.ability
		check(ab.shape in ["area", "strip", "sweep"], "age %d shape" % a.index)
		check(ab.xp_cost > 0, "age %d xp cost" % a.index)
		check(ab.pulses >= 1, "age %d pulses" % a.index)
		check(ab.aim in ["auto", "target"], "age %d aim" % a.index)
		check(ab.aim == "auto" or ab.shape == "area", "age %d: only an area skill can be aimed" % a.index)
		check(ab.damage_mode in ["flat", "true", "percent"], "age %d damage mode" % a.index)
		if ab.damage_mode == "percent":
			check(ab.damage_pct > 0.0 and ab.damage_pct <= 1.0, "age %d percent" % a.index)
		else:
			check(ab.damage > 0.0, "age %d damage" % a.index)


func test_skills_mix_aims_and_damage_modes() -> void:
	# The point of the skill set: some skills aim themselves, some are aimed, and the damage rules differ.
	var aims := {}
	var modes := {}
	for a in GameData.get_default().ages:
		aims[a.ability.aim] = true
		modes[a.ability.damage_mode] = true
	check_eq(aims.size(), 2, "both auto and aimed skills exist")
	check_eq(modes.size(), 3, "flat, true and percent skills all exist")
