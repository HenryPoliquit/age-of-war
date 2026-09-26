extends TestCase


func test_tide_levels() -> void:
	var r := GameData.get_default().rules
	check_eq(r.tide_level_at(0.0), 1)
	check_eq(r.tide_level_at(134.9), 1)
	check_eq(r.tide_level_at(135.0), 2)
	check_eq(r.tide_level_at(700.0), 6)
	check_near(r.tide_multiplier_at(600.0), 8.4, 1e-4)


func test_passive_income() -> void:
	var sim := new_sim(false)
	run_for(sim, 10.0)
	check_near(sim.sides[0].gold, 150.0 + 20.0, 0.01)


func test_forge_raises_income_and_scales_with_age() -> void:
	var sim := new_sim()
	check_near(sim.forge_cost(0), 100.0, 0.01)
	check(sim.buy_forge(0), "forge")
	check_near(sim.income_rate(0), 2.4, 1e-4)
	sim.sides[0].age = 3
	check_near(sim.forge_cost(0), 250.0 * 1.7 * 1.7, 1.0)


func test_kill_pays_bounty_xp_momentum() -> void:
	var sim := new_sim(false)
	var victim := place(sim, 1, "heavy", 100.0)
	var gold := sim.sides[0].gold
	victim.hp = 1.0
	sim._damage_unit(victim, 100.0, "blast", 0)
	check_near(sim.sides[0].gold - gold, victim.cost_paid * 0.5, 0.01, "bounty")
	check_near(sim.sides[0].xp, victim.cost_paid * 0.8, 0.01, "xp")
	check_near(sim.sides[0].momentum, 3.0, 0.01, "heavy kill momentum")


func test_queue_charges_and_refunds() -> void:
	var sim := new_sim(false)
	var def := sim.data.unit_for_role(1, "vanguard")
	check(sim.queue_unit(0, def))
	check_near(sim.sides[0].gold, 150.0 - def.cost, 0.01)
	check(sim.dequeue_last(0))
	check_near(sim.sides[0].gold, 150.0, 0.01)


func test_queue_limit_and_training() -> void:
	var sim := new_sim()
	for i in 5:
		check(sim.queue_role(0, "vanguard"), "slot %d" % i)
	check(not sim.queue_role(0, "vanguard"), "sixth slot must fail")
	run_for(sim, 1.05)
	check_eq(sim.sides[0].units.size(), 1, "one trained after 1 s")


func test_doctrine_costs() -> void:
	var sim := new_sim()
	var def := sim.data.unit_for_role(2, "vanguard")
	var horde: DoctrineDef = sim.data.doctrines[&"horde"]
	sim.sides[0].doctrines.append(horde)
	check(horde.unit_cost_mult < 1.0, "Horde is a discount")
	check_near(sim.unit_price(0, def), roundf(def.cost * horde.unit_cost_mult), 0.01)
