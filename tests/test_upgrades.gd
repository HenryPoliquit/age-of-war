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
	check(not sim.buy_upgrade(0, "wizard", "attack"))


func test_gold_upgrades_are_for_units_only() -> void:
	var sim := new_sim()
	var gold := sim.sides[0].gold
	check_eq(MatchSim.UPGRADES.keys(), ["vanguard", "ranged", "heavy", "siege"], "one gold row per role")
	for spec in [["turret", "attack"], ["turret", "health"], ["turret", "range"], ["income", "income"]]:
		check(sim.upgrade_cost(0, spec[0], spec[1]) == INF, "%s %s is XP research now" % spec)
		check(not sim.buy_upgrade(0, spec[0], spec[1]))
	check_near(sim.sides[0].gold, gold, 0.001, "nothing charged")


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
