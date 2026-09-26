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


func test_kill_pays_bounty_and_xp() -> void:
	var sim := new_sim(false)
	var victim := place(sim, 1, "heavy", 100.0)
	var gold := sim.sides[0].gold
	victim.hp = 1.0
	sim._damage_unit(victim, 100.0, "blast", 0)
	check_near(sim.sides[0].gold - gold, victim.cost_paid * 0.5, 0.01, "bounty")
	check_near(sim.sides[0].xp, victim.cost_paid * 0.8, 0.01, "xp")


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
