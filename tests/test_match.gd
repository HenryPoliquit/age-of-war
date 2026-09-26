extends TestCase


func test_front_line_rules() -> void:
	var sim := new_sim()
	sim.step()
	check_near(sim.front_x, 1200.0, 0.01, "holds when empty")
	var a := place(sim, 0, "vanguard", 400.0)
	sim.step()
	check_near(sim.front_x, sim.rules.lane_length, 0.01, "no enemy units -> enemy gate")
	var b := place(sim, 1, "vanguard", 400.0)
	sim.step()
	check_near(sim.front_x, (a.progress + sim.rules.lane_length - b.progress) * 0.5, 0.01, "midpoint of the two fronts")
	a.hp = 0.0
	sim._remove_dead()
	sim.step()
	check_near(sim.front_x, 0.0, 0.01)


func test_escalation_stacks() -> void:
	var r := GameData.get_default().rules
	check_eq(r.escalation_stacks_at(899.0), 0)
	check_eq(r.escalation_stacks_at(900.0), 1)
	check_eq(r.escalation_stacks_at(930.0), 2)
	check_eq(r.escalation_stacks_at(990.0), 4)
	check_eq(r.escalation_stacks_at(2000.0), 4)


func test_base_destroyed_ends_match() -> void:
	var sim := new_sim()
	sim.sides[1].base_hp = 1.0
	place(sim, 0, "vanguard", sim.rules.lane_length - 5.0)
	run_for(sim, 1.0)
	check_eq(sim.winner, MatchSim.LEFT)


func test_determinism() -> void:
	var gd := GameData.get_default()
	var a := MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"rusher"}, 42)
	var b := MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"rusher"}, 42)
	check_eq(a.winner, b.winner)
	check_eq(a.duration, b.duration)
	check_eq(JSON.stringify(a.log.to_dict()), JSON.stringify(b.log.to_dict()), "identical logs")


func test_ai_match_completes_and_logs() -> void:
	var gd := GameData.get_default()
	var r := MatchRunner.run(gd, {"personality": &"economist", "difficulty": &"normal"}, {"personality": &"turtle", "difficulty": &"easy"}, 7)
	check(r.winner != -1, "match ended")
	check(r.log.timeline.size() >= int(r.duration) - 1, "1 s samples")
	var d: Dictionary = r.log.to_dict()
	check(d.has("events") and d.has("timeline") and d.has("unit_stats"))


func test_start_age() -> void:
	var sim := MatchSim.new(GameData.get_default(), 1)
	sim.set_start_age(4)
	for s in sim.sides:
		check_eq(s.age, 4)
		check_near(s.base_hp, sim.data.age(4).base_max_hp, 0.01)
		check_near(s.gold, sim.rules.start_gold * pow(1.7, 3), 0.5)
	check(sim.queue_role(0, "siege"), "Age 4 roster available")


func test_fx_records_only_when_enabled() -> void:
	var sim := new_sim()
	place(sim, 0, "ranged", 1000.0)
	place(sim, 1, "vanguard", 1250.0)
	run_for(sim, 2.0)
	check(sim.fx.is_empty(), "no fx without record_fx")
	sim.record_fx = true
	run_for(sim, 2.0)
	check(sim.fx.any(func(f): return f.type == "shot"), "shots recorded")


func test_ai_buys_unit_or_turret_upgrades() -> void:
	# Emergent behaviour, so judged over several matches rather than one seed.
	var gd := GameData.get_default()
	var turtle_turret_upgrades := 0
	for seed in range(11, 16):
		var r := MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"turtle"}, seed)
		var bought: Array = r.log.events.filter(func(ev): return ev.type == "upgrade" and ev.row != "income")
		check(not bought.is_empty(), "seed %d: some unit or turret upgrade was bought" % seed)
		turtle_turret_upgrades += bought.filter(func(ev): return ev.row == "turret" and ev.side == 1).size()
	check(turtle_turret_upgrades > 0, "Turtle upgrades its turrets in at least one of five matches")


func test_ai_upgrades_only_what_pays_off() -> void:
	var sim := new_sim()
	var ai := UtilityAI.make(sim.data, &"tactician", &"hard", 0)
	place(sim, 0, "vanguard", 100.0)
	place(sim, 0, "vanguard", 90.0)
	ai._buy_upgrade(sim, false)
	check(sim.sides[0].upgrades.is_empty(), "two Vanguards (40 g) don't justify a 12 g upgrade")
	for i in 8:
		place(sim, 0, "vanguard", 80.0 - i * 7.0)
	ai._buy_upgrade(sim, false)
	check(not sim.sides[0].upgrades.is_empty(), "ten Vanguards (200 g) do")
