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
	check_near(sim.upgrade_cost(0, "income", "income"), roundf(250.0 * sim.rules.age_cost_mult(3)), 0.01)
