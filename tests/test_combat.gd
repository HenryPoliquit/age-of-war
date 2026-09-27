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
	# A standing ally: its own copy of the unit data with no speed (the shared data stays untouched).
	front.def = front.def.duplicate()
	front.def.speed = 0.0
	var back := place(sim, 0, "vanguard", 400.0)
	run_for(sim, 5.0)
	check(back.progress <= front.progress - sim.rules.unit_spacing + 0.01, "spacing held")


func test_base_damage_gives_xp() -> void:
	var sim := new_sim(false)
	place(sim, 0, "vanguard", sim.rules.lane_length - 10.0)
	run_for(sim, 1.0)
	var r := sim.sides[1]
	check(r.base_hp < r.base_max_hp, "base hit")
	var dmg := r.base_max_hp - r.base_hp
	check_near(sim.sides[0].xp, dmg * 0.1, 0.01, "1 XP per 10 damage")


func test_all_units_damage_turrets_before_base() -> void:
	var sim := new_sim()
	sim.sides[1].age = 2
	sim.build_turret(1, 0, sim.data.turret_for_kind(2, "sentry"))
	var t: SimTurret = sim.sides[1].turrets[0]
	var v := place(sim, 0, "vanguard", sim.rules.lane_length - 5.0, 2)
	v.hp = 1e9
	var base_hp := sim.sides[1].base_hp
	sim.step()
	check_near(t.max_hp - t.hp, v.def.damage * sim.rules.matrix(v.def.damage_type, "structure"), 0.01, "vanguard hits the turret at its structure multiplier")
	run_for(sim, 2.0)
	check_near(sim.sides[1].base_hp, base_hp, 0.01, "base untouched while a turret stands")


func test_ranged_siege_min_range() -> void:
	var sim := new_sim()
	var treb := place(sim, 0, "siege", 1000.0, 3)
	var e := place(sim, 1, "vanguard", sim.rules.lane_length - 1000.0 - 60.0, 3)
	e.hp = 1e9
	var before := e.hp
	run_pinned(sim, 4.0, [e])
	check_near(e.hp, before, 0.01, "cannot hit inside min range")
	check(treb.alive())


func test_sentry_targets_most_advanced() -> void:
	var sim := new_sim()
	sim.build_turret(1, 0, sim.data.turret_for_kind(1, "sentry"))
	var near := place(sim, 0, "vanguard", sim.rules.lane_length - 100.0)
	var far := place(sim, 0, "vanguard", sim.rules.lane_length - 250.0)
	run_pinned(sim, 0.2, [near, far])
	check(near.hp < near.max_hp, "closest to base hit")
	check_near(far.hp, far.max_hp, 0.01)


## Front-edge gap between two opposing units (bodies, not weapons).
func _gap(sim: MatchSim, a: SimUnit, b: SimUnit) -> float:
	return sim.rules.lane_length - a.progress - b.progress - a.def.footprint - b.def.footprint


func test_melee_fronts_keep_a_gap() -> void:
	var sim := new_sim()
	var a := place(sim, 0, "vanguard", 1100.0)
	var b := place(sim, 1, "vanguard", 1100.0)
	run_for(sim, 3.0)
	check_near(_gap(sim, a, b), sim.rules.melee_contact, 0.1, "bodies stop melee_contact apart")
	check(sim.rules.lane_length - a.progress - b.progress > a.def.footprint + b.def.footprint, "centres farther apart than the two half-bodies")
	check(a.hp < a.max_hp and b.hp < b.max_hp, "they still fight across the gap")


func test_cavalry_do_not_overlap() -> void:
	var sim := new_sim()
	var a := place(sim, 0, "heavy", 1100.0)
	var b := place(sim, 1, "heavy", 1100.0)
	run_for(sim, 4.0)
	check(a.def.footprint > 20.0, "mounts are deep")
	check_near(_gap(sim, a, b), sim.rules.melee_contact, 0.1)


func test_mixed_pair_uses_both_footprints() -> void:
	var sim := new_sim()
	var a := place(sim, 0, "heavy", 1100.0)
	var b := place(sim, 1, "vanguard", 1100.0)
	b.hp = 1e9
	b.max_hp = 1e9
	run_for(sim, 4.0)
	check_near(_gap(sim, a, b), sim.rules.melee_contact, 0.1)


func test_ranks_in_reach_unchanged() -> void:
	# Guard: the refactor keeps the old reach in edge terms — 4 Vanguard ranks (gap 8, spacing 6, range 30).
	var sim := new_sim()
	var wall := place(sim, 1, "vanguard", 1100.0)
	wall.def = wall.def.duplicate()
	wall.def.speed = 0.0
	wall.hp = 1e9
	wall.max_hp = 1e9
	var ours: Array = []
	for k in 6:
		ours.append(place(sim, 0, "vanguard", 1000.0 - k * 10.0))
	for u in ours:
		u.hp = 1e9
		u.max_hp = 1e9
	run_for(sim, 6.0)
	check_eq(ours.filter(func(u): return u.state == &"attack").size(), 4)


func test_melee_stops_short_of_the_gate() -> void:
	var sim := new_sim(false)
	var v := place(sim, 0, "vanguard", sim.rules.lane_length - 200.0)
	v.hp = 1e9
	v.max_hp = 1e9
	run_for(sim, 6.0)
	check_near(sim.rules.lane_length - v.progress - v.def.footprint, sim.rules.melee_contact, 0.1, "front edge stops melee_contact from the gate")
	check(sim.sides[1].base_hp < sim.sides[1].base_max_hp, "and hits it")
