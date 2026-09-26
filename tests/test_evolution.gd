extends TestCase


func test_evolve_transition_and_base_percentage() -> void:
	var sim := new_sim()
	var s := sim.sides[0]
	s.base_hp = 500.0
	var xp := s.xp
	check(sim.evolve(0))
	check_near(s.xp, xp - sim.data.age(2).evolve_cost, 0.01)
	check(s.evolve_left > 0.0 and s.is_evolving())
	run_for(sim, 4.9)
	check_eq(s.age, 1, "still transitioning")
	run_for(sim, 0.2)
	check_eq(s.age, 2)
	check_near(s.base_hp / s.base_max_hp, 0.5, 1e-4, "keeps percentage")


func test_queue_paused_while_evolving() -> void:
	var sim := new_sim()
	sim.queue_role(0, "vanguard")
	sim.sides[0].age = 2  # any age works
	sim.evolve(0)
	run_for(sim, 4.0)
	check_eq(sim.sides[0].units.size(), 0)
	run_for(sim, 3.0)
	check_eq(sim.sides[0].units.size(), 1, "trains after transition")


func test_turrets_do_not_upgrade() -> void:
	var sim := new_sim()
	sim.build_turret(0, 0, sim.data.turret_for_kind(1, "sentry"))
	sim.sides[0].age = 2
	sim.evolve(0)
	run_for(sim, 6.0)
	check_eq(sim.sides[0].turrets[0].def.age, 1)


func test_turret_slots_and_sell() -> void:
	var sim := new_sim()
	check_eq(sim.sides[0].turret_slots, 1, "one free slot")
	check_near(sim.slot_cost(0), 150.0, 0.01)
	check(sim.unlock_slot(0))
	check_near(sim.slot_cost(0), 400.0, 0.01)
	check(sim.unlock_slot(0))
	check_near(sim.slot_cost(0), 700.0, 0.01)
	check(sim.unlock_slot(0))
	check(not sim.unlock_slot(0), "4 slots max")
	check(sim.slot_cost(0) == INF)
	var def := sim.data.turret_for_kind(1, "sentry")
	check(not sim.build_turret(0, 4, def), "no fifth slot")
	sim.build_turret(0, 0, def)
	var g := sim.sides[0].gold
	check(sim.sell_turret(0, 0))
	check_near(sim.sides[0].gold - g, def.cost * 0.5, 0.01)
	sim.sides[1].age = 3
	check_near(sim.slot_cost(1), roundf(150.0 * sim.rules.age_cost_mult(3)), 0.01, "scales with age")
