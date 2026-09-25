extends TestCase


func test_evolve_transition_and_base_percentage() -> void:
	var sim := new_sim()
	var s := sim.sides[0]
	s.base_hp = 500.0
	var xp := s.xp
	check(sim.evolve(0))
	check_near(s.xp, xp - sim.data.age(2).evolve_cost, 0.01)
	check(s.awaiting_doctrine == false and s.evolve_left > 0.0)
	sim.step()
	check(s.awaiting_doctrine, "Age 2 offers a doctrine")
	run_for(sim, 10.0)
	check_eq(s.age, 1, "timer paused while choosing")
	check(sim.choose_doctrine(0, sim.data.doctrines[&"horde"]))
	run_for(sim, 5.1)
	check_eq(s.age, 2)
	check_near(s.base_hp / s.base_max_hp, 0.5, 1e-4, "keeps percentage")


func test_queue_paused_while_evolving() -> void:
	var sim := new_sim()
	sim.queue_role(0, "vanguard")
	sim.sides[0].age = 2  # evolve 2->3 has no doctrine pick
	sim.evolve(0)
	run_for(sim, 4.0)
	check_eq(sim.sides[0].units.size(), 0)
	run_for(sim, 3.0)
	check_eq(sim.sides[0].units.size(), 1, "trains after transition")


func test_veterancy_buffs_current_age_and_resets() -> void:
	var sim := new_sim()
	var u := place(sim, 0, "vanguard", 50.0)
	var hp := u.max_hp
	var cost := sim.veterancy_cost(0)
	check_near(cost, roundf(0.15 * sim.data.age(1).veterancy_base_xp), 0.01)
	check(sim.buy_veterancy(0))
	check_near(u.max_hp, hp * 1.1, 0.01)
	check_eq(u.vet_rank, 1)
	sim.buy_veterancy(0)
	sim.buy_veterancy(0)
	check(not sim.buy_veterancy(0), "max three ranks")
	sim.evolve(0)
	sim.step()
	sim.choose_doctrine(0, sim.data.doctrines[&"elite"])
	run_for(sim, 5.1)
	check_eq(sim.sides[0].vet_ranks, 0, "ranks reset on evolving")


func test_turrets_do_not_upgrade() -> void:
	var sim := new_sim()
	sim.build_turret(0, 0, sim.data.turret_for_kind(1, "sentry"))
	sim.sides[0].age = 2
	sim.evolve(0)
	run_for(sim, 6.0)
	check_eq(sim.sides[0].turrets[0].def.age, 1)


func test_turret_slots_and_sell() -> void:
	var sim := new_sim()
	check_near(sim.slot_cost(0), 150.0, 0.01)
	check(sim.unlock_slot(0))
	check_near(sim.slot_cost(0), 400.0, 0.01)
	check(sim.unlock_slot(0))
	check(not sim.unlock_slot(0), "4 slots max without Bastion")
	sim.sides[0].doctrines.append(sim.data.doctrines[&"bastion"])
	check(sim.unlock_slot(0), "Bastion 5th slot")
	var def := sim.data.turret_for_kind(1, "sentry")
	sim.build_turret(0, 0, def)
	var g := sim.sides[0].gold
	check(sim.sell_turret(0, 0))
	check_near(sim.sides[0].gold - g, def.cost * 0.5, 0.01)
