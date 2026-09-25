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


func test_doctrine_offers_at_2_and_4() -> void:
	var gd := GameData.get_default()
	for i in range(1, 7):
		var n := gd.age(i).doctrine_options.size()
		check_eq(n, 2 if i in [2, 4] else 0, "age %d" % i)


func test_evolution_costs_increase() -> void:
	var gd := GameData.get_default()
	for i in range(3, 7):
		check(gd.age(i).evolve_cost > gd.age(i - 1).evolve_cost, "age %d cost" % i)
