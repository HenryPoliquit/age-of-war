extends TestCase


func test_costs_xp_and_cools_down() -> void:
	var sim := new_sim(false)
	var e := place(sim, 1, "vanguard", 1000.0)
	e.hp = 1e9
	e.max_hp = 1e9
	var def := sim.data.age(1).ability
	sim.sides[0].xp = def.xp_cost - 1
	check(not sim.fire_ability(0), "not enough XP")
	sim.sides[0].xp = def.xp_cost * 2
	check(sim.fire_ability(0))
	check_near(sim.sides[0].xp, def.xp_cost, 0.01, "charged once")
	check(not sim.fire_ability(0), "cooldown")
	run_pinned(sim, sim.rules.ability_cooldown + 0.1, [e])
	check(sim.fire_ability(0), "ready again")


func test_needs_a_target() -> void:
	var sim := new_sim()
	check(not sim.fire_ability(0), "no enemy units")
	check_near(sim.sides[0].xp, 99999.0, 0.01, "nothing charged")
	check_near(sim.sides[0].ability_cooldown, 0.0, 0.001, "no cooldown started")


func test_sweep_hits_every_enemy_on_the_lane() -> void:
	var sim := new_sim()
	check_eq(sim.data.age(1).ability.shape, "sweep")
	var near := place(sim, 1, "vanguard", 2000.0)
	var far := place(sim, 1, "vanguard", 100.0)
	for u in [near, far]:
		u.hp = 1e6
		u.max_hp = 1e6
	check(sim.fire_ability(0))
	run_pinned(sim, 5.0, [near, far])
	check(near.hp < near.max_hp, "unit near our gate hit")
	check(far.hp < far.max_hp, "unit at their gate hit")


func test_area_lands_on_densest_group() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	check_eq(sim.data.age(2).ability.shape, "area")
	var lone := place(sim, 1, "vanguard", 1600.0, 2)
	var pack := [place(sim, 1, "vanguard", 600.0, 2), place(sim, 1, "vanguard", 606.0, 2), place(sim, 1, "vanguard", 612.0, 2)]
	var zone := sim.ability_zone(0)
	check_eq(zone.size(), 2)
	var lone_x := sim.to_world(1, lone.progress)
	check(lone_x < zone[0] or lone_x > zone[1], "lone unit outside")
	for u in pack:
		var x := sim.to_world(1, u.progress)
		check(x >= zone[0] and x <= zone[1], "pack inside")
	check_near(sim.ability_zone_value(0), 3.0 * pack[0].cost_paid, 0.01, "value = the pack")


func test_strip_starts_at_enemy_front() -> void:
	var sim := new_sim()
	sim.sides[0].age = 3
	sim.sides[1].age = 3
	var def := sim.data.age(3).ability
	check_eq(def.shape, "strip")
	var front := place(sim, 1, "vanguard", 900.0, 3)
	place(sim, 1, "vanguard", 500.0, 3)
	var zone := sim.ability_zone(0)
	var fx := sim.to_world(1, front.progress)
	check_near(zone[0], fx, 0.01, "starts at the front unit")
	check_near(zone[1], fx + def.width, 0.01, "extends toward the enemy base")
	place(sim, 0, "vanguard", 700.0, 3)
	var z1 := sim.ability_zone(1)
	check_near(z1[1], 700.0, 0.01, "mirrored for the right side")
	check_near(z1[0], 700.0 - def.width, 0.01)


func test_skills_never_hit_structures() -> void:
	var sim := new_sim()
	sim.build_turret(1, 0, sim.data.turret_for_kind(1, "sentry"))
	var t: SimTurret = sim.sides[1].turrets[0]
	var e := place(sim, 1, "vanguard", 10.0)
	e.hp = 1e9
	e.max_hp = 1e9
	var base := sim.sides[1].base_hp
	check(sim.fire_ability(0))
	run_pinned(sim, 3.0, [e])
	check_near(t.hp, t.max_hp, 0.01, "turret untouched")
	check_near(sim.sides[1].base_hp, base, 0.01, "base untouched")


func test_reports_kills() -> void:
	var sim := new_sim()
	var weak := place(sim, 1, "vanguard", 1500.0)
	weak.hp = 1.0
	check(sim.fire_ability(0))
	run_pinned(sim, 3.0, [weak])
	var ends := sim.match_log.events.filter(func(ev): return ev.type == "ability_end")
	check_eq(ends.size(), 1)
	check_eq(ends[0].kills, 1)


func test_ai_fires_skills() -> void:
	var gd := GameData.get_default()
	var r := MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"skill_heavy"}, 11)
	check(r.log.events.any(func(ev): return ev.type == "ability"), "a skill was fired")
