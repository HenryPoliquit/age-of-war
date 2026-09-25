extends TestCase


func test_matrix_applied() -> void:
	var sim := new_sim()
	var h := place(sim, 1, "heavy", 100.0)
	var hp := h.hp
	sim._damage_unit(h, 100.0, "pierce", 0)
	check_near(hp - h.hp, 60.0, 0.01, "pierce vs heavy = 0.6")


func test_units_meet_and_fight() -> void:
	var sim := new_sim()
	var a := place(sim, 0, "vanguard", 1100.0)
	var b := place(sim, 1, "vanguard", 1100.0)
	run_for(sim, 3.0)
	check(a.hp < a.max_hp and b.hp < b.max_hp, "both took damage")
	check(sim.rules.lane_length - a.progress - b.progress <= a.def.range + 0.01, "stopped in range")


func test_never_walks_past_enemy() -> void:
	var sim := new_sim()
	var a := place(sim, 0, "heavy", 1000.0)
	var b := place(sim, 1, "heavy", 1000.0)
	for i in 100:
		sim.step()
		if a.alive() and b.alive():
			check(sim.to_world(0, a.progress) <= sim.to_world(1, b.progress), "passed through at t=%s" % sim.time)


func test_allies_do_not_overlap() -> void:
	var sim := new_sim()
	var front := place(sim, 0, "heavy", 500.0)
	var back := place(sim, 0, "vanguard", 400.0)
	sim.set_stance(0, &"hold", 500.0)
	run_for(sim, 5.0)
	check(back.progress <= front.progress - sim.rules.unit_spacing + 0.01, "spacing held")


func test_hold_stops_at_rally_line() -> void:
	var sim := new_sim()
	var u := place(sim, 0, "vanguard", 0.0)
	sim.set_stance(0, &"hold", 600.0)
	run_for(sim, 20.0)
	check_near(u.progress, 600.0, 0.01)
	sim.set_stance(0, &"advance")
	run_for(sim, 2.0)
	check(u.progress > 600.0, "released")


func test_base_damage_gives_xp_and_defender_momentum() -> void:
	var sim := new_sim(false)
	place(sim, 0, "vanguard", sim.rules.lane_length - 10.0)
	run_for(sim, 1.0)
	var r := sim.sides[1]
	check(r.base_hp < r.base_max_hp, "base hit")
	var dmg := r.base_max_hp - r.base_hp
	check_near(sim.sides[0].xp, dmg * 0.1, 0.01, "1 XP per 10 damage")
	check_near(r.momentum, dmg / r.base_max_hp * 100.0 * 0.5, 0.01, "1 momentum per 2% lost")


func test_only_siege_damages_turrets() -> void:
	var sim := new_sim()
	sim.sides[1].age = 2
	sim.build_turret(1, 0, sim.data.turret_for_kind(2, "sentry"))
	var t: SimTurret = sim.sides[1].turrets[0]
	var v := place(sim, 0, "vanguard", sim.rules.lane_length - 5.0, 2)
	v.hp = 1e9
	run_for(sim, 2.0)
	check_near(t.hp, t.max_hp, 0.01, "vanguard must not hit turrets")
	var ram := place(sim, 0, "siege", sim.rules.lane_length - 5.0, 2)
	ram.hp = 1e9
	run_for(sim, 3.0)
	check(t.hp < t.max_hp, "ram hits turret")


func test_ranged_siege_min_range() -> void:
	var sim := new_sim()
	var treb := place(sim, 0, "siege", 1000.0, 3)
	var e := place(sim, 1, "vanguard", sim.rules.lane_length - 1000.0 - 60.0, 3)
	e.hp = 1e9
	var before := e.hp
	sim.set_stance(1, &"hold", sim.to_world(1, e.progress))
	run_for(sim, 4.0)
	check_near(e.hp, before, 0.01, "cannot hit inside min range")
	check(treb.alive())


func test_sentry_targets_most_advanced() -> void:
	var sim := new_sim()
	sim.build_turret(1, 0, sim.data.turret_for_kind(1, "sentry"))
	var near := place(sim, 0, "vanguard", sim.rules.lane_length - 100.0)
	var far := place(sim, 0, "vanguard", sim.rules.lane_length - 250.0)
	sim.set_stance(0, &"hold", 0.0)
	run_for(sim, 0.2)
	check(near.hp < near.max_hp, "closest to base hit")
	check_near(far.hp, far.max_hp, 0.01)
