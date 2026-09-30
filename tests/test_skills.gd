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
	var lead := front.def.speed * def.telegraph
	check(lead > 0.0)
	check_near(zone[0], fx - lead, 0.01, "starts at the front unit, ahead by what it walks during the telegraph")
	check_near(zone[1], fx - lead + def.width, 0.01, "extends toward the enemy base")
	var mine := place(sim, 0, "vanguard", 700.0, 3)
	var z1 := sim.ability_zone(1)
	check_near(z1[1], 700.0 + mine.def.speed * def.telegraph, 0.01, "mirrored for the right side")
	check_near(z1[0], z1[1] - def.width, 0.01)


func test_the_strip_still_holds_the_front_unit_when_the_first_pulse_lands() -> void:
	var sim := new_sim()
	sim.sides[0].age = 3
	sim.sides[1].age = 3
	var front := place(sim, 1, "vanguard", 1000.0, 3)
	front.hp = 1e6
	front.max_hp = 1e6
	check(sim.fire_ability(0))
	# Not pinned: it walks toward us during the telegraph and the first pulse must still find it.
	var def := sim.data.age(3).ability
	run_for(sim, def.telegraph + 0.15)
	check(front.hp < front.max_hp, "the walking front unit is hit by the first volley")


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


# ---------------------------------------------------------------------------
# Aimed skills

func _tough(u: SimUnit) -> SimUnit:
	u.hp = 1e9
	u.max_hp = 1e9
	return u


func test_an_aimed_skill_centres_on_the_aim_point() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var def := sim.data.age(2).ability
	check(def.is_targeted() and sim.ability_is_targeted(0), "Bronze skill is aimed")
	# The densest group is at x = 900; aim elsewhere on purpose.
	var pack := [place(sim, 1, "vanguard", 1500.0, 2), place(sim, 1, "vanguard", 1506.0, 2)]
	var lone := place(sim, 1, "vanguard", 400.0, 2)
	var zone := sim.ability_zone(0, 2000.0)
	check_near(zone[0], 2000.0 - def.width * 0.5, 0.01, "left edge")
	check_near(zone[1], 2000.0 + def.width * 0.5, 0.01, "right edge")
	var auto_zone := sim.ability_zone(0)
	check_near((auto_zone[0] + auto_zone[1]) * 0.5, sim.ability_default_aim(0), 0.01, "no aim = the densest group")
	check(sim.to_world(1, pack[0].progress) >= auto_zone[0] and sim.to_world(1, pack[0].progress) <= auto_zone[1], "default aim finds the pack")
	var far := sim.ability_zone(0, 99999.0)
	check_near((far[0] + far[1]) * 0.5, sim.rules.lane_length, 0.01, "aim is clamped to the lane")
	check(lone.alive())


func test_an_auto_skill_ignores_an_aim_point() -> void:
	var sim := new_sim()
	check_eq(sim.data.age(1).ability.aim, "auto")
	place(sim, 1, "vanguard", 1500.0)
	check_eq(sim.ability_zone(0, 100.0), sim.ability_zone(0), "the aim point changes nothing")
	check(not sim.ability_is_targeted(0))


func test_an_aimed_skill_hits_where_it_was_aimed_and_only_there() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var here := _tough(place(sim, 1, "vanguard", 900.0, 2))   # x = 1500
	var there := _tough(place(sim, 1, "vanguard", 1800.0, 2)) # x = 600
	check(sim.fire_ability(0, sim.to_world(1, here.progress)))
	run_pinned(sim, 2.0, [here, there])
	check(here.hp < here.max_hp, "the aimed spot is hit")
	check_near(there.hp, there.max_hp, 0.001, "the rest of the lane is not")


func test_firing_at_an_empty_zone_fails_and_costs_nothing() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var e := _tough(place(sim, 1, "vanguard", 900.0, 2))
	var xp := sim.sides[0].xp
	check(not sim.fire_ability(0, 100.0), "nothing near x = 100")
	check_near(sim.sides[0].xp, xp, 0.001, "no XP spent")
	check_near(sim.sides[0].ability_cooldown, 0.0, 0.001, "no cooldown")
	check(sim.effects.is_empty(), "no effect queued")
	check(sim.fire_ability(0, sim.to_world(1, e.progress) + 100.0), "a zone that overlaps the unit works")


func test_an_aimed_skill_without_an_aim_uses_the_densest_group() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var pack := [_tough(place(sim, 1, "vanguard", 600.0, 2)), _tough(place(sim, 1, "vanguard", 606.0, 2))]
	var lone := _tough(place(sim, 1, "vanguard", 1900.0, 2))
	check(sim.fire_ability(0))
	run_pinned(sim, 2.0, pack + [lone])
	check(pack[0].hp < pack[0].max_hp and pack[1].hp < pack[1].max_hp, "the pack is hit")
	check_near(lone.hp, lone.max_hp, 0.001, "the lone unit is not")


func test_preview_reports_targets_and_value() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var a := place(sim, 1, "vanguard", 900.0, 2)
	var b := place(sim, 1, "ranged", 905.0, 2)
	place(sim, 1, "vanguard", 1900.0, 2)
	var pv := sim.ability_preview(0, sim.to_world(1, a.progress))
	check_eq(pv.count, 2)
	check_near(pv.value, a.cost_paid + b.cost_paid, 0.01)
	check_eq(sim.ability_preview(0, 50.0).count, 0)
	check_near(sim.ability_zone_value(0, sim.to_world(1, a.progress)), pv.value, 0.001)


# ---------------------------------------------------------------------------
# Damage modes

## Damage `victim` (parked at `progress`) takes from `sim`'s side-0 skill fired once at it.
func _damage_taken(sim: MatchSim, victim: SimUnit, seconds := 6.0) -> float:
	var before := victim.hp
	check(sim.fire_ability(0, sim.to_world(1, victim.progress)), "skill fires")
	run_pinned(sim, seconds, [victim])
	return before - victim.hp


func test_flat_skills_go_through_the_armour_matrix() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var def := sim.data.age(2).ability
	check_eq(def.damage_mode, "flat")
	var light := place(sim, 1, "vanguard", 900.0, 2)
	var heavy := place(sim, 1, "heavy", 1500.0, 2)
	heavy.hp = 1e6
	heavy.max_hp = 1e6
	var d_heavy := _damage_taken(sim, heavy)
	var d_light := 0.0
	sim = new_sim()
	sim.sides[0].age = 2
	light = place(sim, 1, "vanguard", 900.0, 2)
	light.hp = 1e6
	light.max_hp = 1e6
	d_light = _damage_taken(sim, light)
	check_near(d_heavy, def.damage * def.pulses * sim.rules.matrix(def.damage_type, "heavy"), 0.5, "blast x1.3 vs Heavy")
	check_near(d_light, def.damage * def.pulses * sim.rules.matrix(def.damage_type, "light"), 0.5, "blast x0.8 vs Light")


func test_true_damage_ignores_armour_and_defence() -> void:
	var def := GameData.get_default().age(3).ability
	check_eq(def.damage_mode, "true", "Iron skill is true damage")
	var results := []
	for role in ["vanguard", "heavy"]:
		var sim := new_sim()
		sim.sides[0].age = 3
		sim.sides[1].age = 3
		sim.sides[1].set_upgrade_level(role, "defence", 3)
		var v := place(sim, 1, role, 1500.0, 3)
		v.hp = 1e6
		v.max_hp = 1e6
		results.append(_damage_taken(sim, v))
	for r in results:
		check_near(r, def.damage * def.pulses, 0.5, "every volley does its full damage, armour or not")


func test_percent_damage_takes_a_share_of_max_health() -> void:
	var def := GameData.get_default().age(4).ability
	check_eq(def.damage_mode, "percent", "Medieval skill is percent damage")
	var sim := new_sim()
	sim.sides[0].age = 4
	sim.sides[1].age = 4
	sim.sides[1].set_upgrade_level("heavy", "defence", 3)
	# Off the slice boundaries (multiples of 300 px), so each unit is hit by exactly one pulse.
	var light := place(sim, 1, "vanguard", 1450.0, 4)
	var heavy := place(sim, 1, "heavy", 550.0, 4)
	check(sim.fire_ability(0))
	run_pinned(sim, 6.0, [light, heavy])
	check_near(light.hp, light.max_hp * (1.0 - def.damage_pct), 0.5, "Light loses its share")
	check_near(heavy.hp, heavy.max_hp * (1.0 - def.damage_pct), 0.5, "Heavy loses the same share, Defence or not")
	check(heavy.max_hp - heavy.hp > 4.0 * (light.max_hp - light.hp), "so the bigger unit loses far more")


func test_percent_damage_is_of_max_health_not_current() -> void:
	var sim := new_sim()
	sim.sides[0].age = 4
	var u := place(sim, 1, "vanguard", 1450.0, 4)
	u.hp = u.max_hp * 0.5
	var pct := sim.data.age(4).ability.damage_pct
	check(sim.fire_ability(0))
	run_pinned(sim, 6.0, [u])
	check_near(u.hp, u.max_hp * (0.5 - pct), 0.5)


func test_percent_damage_can_kill_and_is_counted() -> void:
	var sim := new_sim()
	sim.sides[0].age = 4
	var u := place(sim, 1, "vanguard", 1450.0, 4)
	u.hp = 1.0
	check(sim.fire_ability(0))
	run_pinned(sim, 6.0, [u])
	check(not u.alive())
	var end: Dictionary = sim.match_log.events.filter(func(ev): return ev.type == "ability_end")[0]
	check_eq(end.kills, 1)
	check_eq(end.hits, 1)
	check_near(end.damage, 1.0, 0.11, "damage counts only what was left")


# ---------------------------------------------------------------------------
# Slow and reporting

func test_rockfall_slows_what_it_hits_for_a_while() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var def := sim.data.age(2).ability
	check(def.slow > 0.0 and def.slow_time > 0.0, "Rockfall slows")
	var hit := _tough(place(sim, 1, "vanguard", 900.0, 2))
	var missed := _tough(place(sim, 1, "vanguard", 1900.0, 2))
	check(sim.fire_ability(0, sim.to_world(1, hit.progress)))
	run_pinned(sim, def.telegraph + def.pulse_interval * def.pulses + 0.3, [hit, missed])
	check_near(hit.slow, def.slow, 0.001, "slowed right after the rocks land")
	check_near(missed.slow, 0.0, 0.001, "units outside are not")
	run_pinned(sim, def.slow_time + 0.5, [hit, missed])
	check_near(hit.slow, 0.0, 0.001, "the slow wears off")


func test_a_slowed_unit_walks_slower() -> void:
	var sim := new_sim()
	var slowed := place(sim, 1, "vanguard", 100.0)
	var normal := place(sim, 0, "vanguard", 100.0)
	slowed.skill_slow = 0.5
	slowed.skill_slow_until = 100.0
	slowed.progress = 100.0
	normal.progress = 100.0
	run_for(sim, 1.0)
	check(slowed.progress - 100.0 < 0.6 * (normal.progress - 100.0), "half speed")


func test_skill_hits_are_recorded_for_the_view() -> void:
	var sim := new_sim()
	sim.record_fx = true
	sim.sides[0].age = 4
	var u := _tough(place(sim, 1, "vanguard", 1450.0, 4))
	check(sim.fire_ability(0))
	var hits := []
	for i in 80:
		sim.step()
		u.progress = 1450.0
		hits.append_array(sim.fx.filter(func(f): return f.type == "skill_hit"))
		sim.fx.clear()
	check_eq(hits.size(), 1)
	check_eq(hits[0].mode, "percent")
	check_near(hits[0].dealt, u.max_hp * sim.data.age(4).ability.damage_pct, 0.5)


func test_the_ability_event_says_whether_it_was_aimed() -> void:
	var sim := new_sim()
	place(sim, 1, "vanguard", 1450.0)
	check(sim.fire_ability(0))
	var ev: Dictionary = sim.match_log.events.filter(func(e): return e.type == "ability")[0]
	check_eq(ev.aimed, false)
	sim.sides[0].ability_cooldown = 0.0
	sim.sides[0].age = 2
	place(sim, 1, "vanguard", 1450.0, 2)
	check(sim.fire_ability(0, 900.0))
	ev = sim.match_log.events.filter(func(e): return e.type == "ability")[-1]
	check_eq(ev.aimed, true)
	check_near(ev.x, 900.0, 0.01)


# ---------------------------------------------------------------------------
# The AI aims like a player

func _ai_shot(difficulty: StringName, seed: int) -> Dictionary:
	var sim := new_sim()
	sim.sides[0].age = 2
	# The densest enemy group sits at x = 1500; a lone unit far behind it.
	place(sim, 1, "vanguard", 900.0, 2)
	place(sim, 1, "vanguard", 906.0, 2)
	place(sim, 1, "vanguard", 1900.0, 2)
	var ai := UtilityAI.make(sim.data, &"skill_heavy", difficulty, 0, seed)
	ai.update(sim, 100.0)
	var shots := sim.match_log.events.filter(func(ev): return ev.type == "ability")
	return {"shots": shots, "aim": sim.to_world(1, 903.0)}


func test_the_ai_aims_an_aimed_skill_at_the_densest_group() -> void:
	var r := _ai_shot(&"nightmare", 3)
	check_eq(r.shots.size(), 1, "the AI fired")
	check_eq(r.shots[0].aimed, true)
	check(absf(r.shots[0].x - r.aim) <= 8.0, "a perfect aimer lands on the pack (x=%s)" % r.shots[0].x)


func test_easier_ais_aim_loosely_but_still_hit() -> void:
	var loose := 0
	for seed in 12:
		var r := _ai_shot(&"easy", seed)
		check_eq(r.shots.size(), 1, "seed %d fired" % seed)
		var err: float = absf(r.shots[0].x - r.aim)
		check(err <= 220.0 + 8.0, "seed %d within the difficulty's aim error (%s)" % [seed, err])
		if err > 40.0:
			loose += 1
	check(loose > 0, "some easy shots really are off-centre")


func test_a_skill_counts_each_unit_it_hit_once_however_many_pulses() -> void:
	var sim := new_sim()
	sim.sides[0].age = 2
	var a := _tough(place(sim, 1, "vanguard", 900.0, 2))
	var b := _tough(place(sim, 1, "vanguard", 920.0, 2))
	var def := sim.data.age(2).ability
	check(def.pulses > 1, "Rockfall pulses more than once")
	check(sim.fire_ability(0, sim.to_world(1, 910.0)))
	run_pinned(sim, 4.0, [a, b])
	var end: Dictionary = sim.match_log.events.filter(func(ev): return ev.type == "ability_end")[0]
	check_eq(end.hits, 2, "two units, hit on every pulse")
	check_near(end.damage, 2.0 * def.pulses * def.damage * sim.rules.matrix(def.damage_type, "light"), 0.5)
