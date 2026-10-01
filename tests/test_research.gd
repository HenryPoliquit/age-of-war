extends TestCase
## XP research (GDD §6.2): prices, era gates, every perk's effect, and the rule that the tree cannot be
## bought out before evolving.


func _unlock(sim: MatchSim, age: int) -> void:
	sim.sides[0].age = age
	sim.sides[0].xp = 99999.0


func test_perks_load_in_panel_order() -> void:
	var gd := GameData.get_default()
	var ids: Array = gd.research.map(func(d): return String(d.id))
	check_eq(ids, ["turret_attack", "turret_health", "turret_range", "base_health", "train_speed", "queue_slots", "income",
		"skill_damage", "skill_zone", "ascension"])
	check(not ids.has("evolve_cost") and not ids.has("skill_cooldown"), "no cheaper evolution, no shorter cooldown")
	check(gd.research_def(&"ascension").is_endless())


func test_price_is_a_share_of_the_next_evolution() -> void:
	var sim := new_sim()
	var attack := sim.data.research_def(&"turret_attack")
	_unlock(sim, 2)
	check_near(sim.research_basis(0), float(sim.data.age(3).evolve_cost), 0.01, "priced off the next evolution")
	check_near(sim.research_cost(0, &"turret_attack"), roundf(attack.cost_factors[0] * sim.data.age(3).evolve_cost), 0.01, "level 1 in Age 2")
	check(sim.buy_research(0, &"turret_attack"))
	_unlock(sim, 3)
	check_near(sim.research_cost(0, &"turret_attack"), roundf(attack.cost_factors[1] * sim.data.age(4).evolve_cost), 0.01, "level 2 in Age 3: dearer in factor and in basis")
	_unlock(sim, 6)
	check_near(sim.research_basis(0), float(sim.data.age(6).evolve_cost), 0.01, "the last era is priced off its own evolution")
	var base := sim.data.research_def(&"base_health")
	check_near(sim.research_cost(0, &"base_health"), roundf(base.cost_factors[0] * sim.data.age(6).evolve_cost), 0.01)
	check(sim.research_cost(0, &"turret_attack") > sim.research_cost(0, &"turret_health"), "each perk has its own price")


func test_research_costs_xp_not_gold() -> void:
	var sim := new_sim()
	_unlock(sim, 2)
	var gold := sim.sides[0].gold
	var xp := sim.sides[0].xp
	var cost := sim.research_cost(0, &"income")
	check(sim.buy_research(0, &"income"))
	check_near(sim.sides[0].gold, gold, 0.001, "gold untouched")
	check_near(sim.sides[0].xp, xp - cost, 0.001, "XP paid")
	sim.sides[0].xp = 10.0
	check(not sim.buy_research(0, &"turret_range"), "not enough XP")
	check_near(sim.sides[0].xp, 10.0, 0.001, "nothing charged")


func test_levels_open_by_era() -> void:
	var sim := new_sim()
	for def in sim.data.research:
		check(sim.research_cost(0, def.id) == INF and sim.research_locked(0, def.id), "%s is shut in Age 1" % def.id)
		check(not sim.buy_research(0, def.id))
	_unlock(sim, 2)
	check(sim.research_cost(0, &"turret_attack") < INF, "level 1 opens in Age 2")
	check(sim.research_locked(0, &"skill_damage"), "skill perks open in Age 3")
	check(sim.research_locked(0, &"ascension"), "Ascension is a last-era perk")
	sim.buy_research(0, &"turret_attack")
	check(sim.research_locked(0, &"turret_attack"), "level 2 needs Age 3")
	check(not sim.buy_research(0, &"turret_attack"))
	_unlock(sim, 3)
	check(sim.buy_research(0, &"turret_attack"))
	check(sim.research_locked(0, &"turret_attack"), "level 3 needs Age 4")
	_unlock(sim, 6)
	check(sim.buy_research(0, &"turret_attack"))
	check(sim.research_cost(0, &"turret_attack") == INF and not sim.research_locked(0, &"turret_attack"), "maxed, not locked")
	check(not sim.buy_research(0, &"turret_attack"), "no fourth level")
	check(not sim.buy_research(0, &"wizardry"), "unknown perk")


func test_the_tree_cannot_be_bought_out_before_evolving() -> void:
	# An era earns about 1.2-1.5x its evolution's cost in XP (docs/balance_log.md B26). Everything open in an
	# era costs more than 1.25x that evolution, so evolving and buying the lot is out of reach: a player picks
	# a few perks per era and still has to choose between them and the next age.
	var sim := new_sim()
	for age in range(2, 6):
		sim.sides[0].age = age
		var open := 0.0
		for def in sim.data.research:
			var levels := 1 if def.is_endless() else def.levels
			for level in levels:
				if def.min_ages[mini(level, def.min_ages.size() - 1)] <= age:
					open += roundf(def.factor_for_next(level) * sim.research_basis(0))
		check(open >= 1.25 * sim.evolve_cost(0), "Age %d: %d XP of open research vs a %d XP evolution" % [age, open, sim.evolve_cost(0)])
	# A whole era's worth of every non-skill perk's first level alone is more than the evolution itself.
	sim.sides[0].age = 2
	var level_ones := 0.0
	for def in sim.data.research:
		if def.min_ages[0] <= 2:
			level_ones += sim.research_cost(0, def.id)
	check(level_ones > sim.evolve_cost(0), "first levels alone cost more than evolving: %d vs %d" % [level_ones, sim.evolve_cost(0)])


func test_turret_attack_and_health() -> void:
	var sim := new_sim()
	_unlock(sim, 2)
	var def := sim.data.turret_for_kind(2, "sentry")
	sim.build_turret(0, 0, def)
	var t: SimTurret = sim.sides[0].turrets[0]
	t.hp = t.max_hp * 0.5
	check(sim.buy_research(0, &"turret_health"))
	check_near(t.max_hp, def.hp * 1.15, 0.01, "built turret gains HP")
	check_near(t.hp / t.max_hp, 0.5, 1e-4, "keeps percentage")
	sim.sell_turret(0, 0)
	sim.build_turret(0, 0, def)
	check_near(sim.sides[0].turrets[0].max_hp, def.hp * 1.15, 0.01, "turret built later has it too")
	check_near(sim.attack_mult(0, "turret"), 1.0, 1e-6)
	check(sim.buy_research(0, &"turret_attack"))
	check_near(sim.attack_mult(0, "turret"), 1.15, 1e-6)
	check_near(sim.attack_mult(0, "vanguard"), 1.0, 1e-6, "units are not turrets")
	var e := place(sim, 1, "vanguard", sim.rules.lane_length - def.range * 0.5, 2)
	var before := e.hp
	run_pinned(sim, 0.1, [e])
	check_near(before - e.hp, def.damage * sim.rules.matrix(def.damage_type, e.def.armour) * 1.15, 0.05, "turret hits 15% harder")


func test_turret_range_and_support_aura() -> void:
	var sim := new_sim()
	var support: TurretDef = null
	var age := 1
	for a in sim.data.ages:
		for t in a.turrets:
			if t.kind == "support" and support == null:
				support = t
				age = a.index
	check(support != null, "some age has a Support turret")
	_unlock(sim, maxi(age, 2))
	sim.sides[0].age = age
	sim.build_turret(0, 0, support)
	var e := place(sim, 1, "vanguard", sim.rules.lane_length - support.aura_radius * 1.05, age)
	sim.step()
	check_near(e.slow, 0.0, 1e-4, "outside the base aura")
	sim.sides[0].age = maxi(age, 2)
	check(sim.buy_research(0, &"turret_range"))
	check_near(sim.turret_range_mult(0), 1.1, 1e-6)
	e.progress = sim.rules.lane_length - support.aura_radius * 1.05
	sim.step()
	check(e.slow > 0.0, "inside the upgraded aura")


func test_base_health_keeps_percentage_and_carries_over() -> void:
	var sim := new_sim()
	sim.set_start_age(2)
	_unlock(sim, 2)
	var s := sim.sides[0]
	var base := sim.data.age(2).base_max_hp
	s.base_hp = s.base_max_hp * 0.5
	check(sim.buy_research(0, &"base_health"))
	check_near(s.base_max_hp, base * 1.1, 0.01)
	check_near(s.base_hp / s.base_max_hp, 0.5, 1e-4, "keeps percentage")
	sim.evolve(0)
	run_for(sim, sim.rules.evolve_time + 0.2)
	check_eq(s.age, 3)
	check_near(s.base_max_hp, sim.data.age(3).base_max_hp * 1.1, 0.01, "the next era's base has it too")
	check_near(s.base_hp / s.base_max_hp, 0.5, 1e-3, "percentage survives evolving")
	check_near(sim.sides[1].base_max_hp, sim.data.age(2).base_max_hp, 0.01, "the enemy's base is untouched")


func test_base_health_applies_to_a_skirmish_start_age() -> void:
	var sim := new_sim()
	sim.sides[0].research[&"base_health"] = 1
	sim.sides[0].research_totals[&"base_health"] = 0.1
	sim.set_start_age(3)
	check_near(sim.sides[0].base_max_hp, sim.data.age(3).base_max_hp * 1.1, 0.01)


func test_training_speed() -> void:
	var sim := new_sim()
	_unlock(sim, 2)
	var def := sim.data.unit_for_role(2, "vanguard")
	sim.queue_unit(0, def)
	sim.queue_unit(1, def)
	check(sim.buy_research(0, &"train_speed"))
	check_near(sim.train_speed_mult(0), 1.15, 1e-6)
	sim.sides[1].age = 2
	run_for(sim, def.train_time / 1.15 + 0.25)
	check_eq(sim.sides[0].units.size(), 1, "the researched side has trained its unit")
	check_eq(sim.sides[1].units.size(), 0, "the other side is still training")
	_unlock(sim, 4)
	sim.buy_research(0, &"train_speed")
	sim.buy_research(0, &"train_speed")
	check_near(sim.train_speed_mult(0), 1.45, 1e-6, "three levels: +45%")


func test_queue_slots_add_one_per_level_up_to_three() -> void:
	var sim := new_sim()
	_unlock(sim, 4)
	var def := sim.data.unit_for_role(4, "vanguard")
	check_eq(sim.queue_capacity(0), sim.rules.queue_slots)
	for i in 3:
		check(sim.buy_research(0, &"queue_slots"), "level %d" % (i + 1))
	check_eq(sim.queue_capacity(0), sim.rules.queue_slots + 3, "+3 at most")
	check(not sim.buy_research(0, &"queue_slots"), "no fourth slot")
	sim.sides[0].gold = 99999.0
	var queued := 0
	while sim.queue_unit(0, def):
		queued += 1
	check_eq(queued, sim.rules.queue_slots + 3, "that many units wait")
	check_eq(sim.queue_capacity(1), sim.rules.queue_slots, "the other side keeps the base count")


func test_income_research() -> void:
	var sim := new_sim()
	_unlock(sim, 2)
	check_near(sim.income_rate(0), sim.rules.base_income, 1e-6)
	check(sim.buy_research(0, &"income"))
	check_near(sim.income_rate(0), sim.rules.base_income * 1.2, 1e-6)
	_unlock(sim, 4)
	sim.buy_research(0, &"income")
	sim.buy_research(0, &"income")
	check_near(sim.income_rate(0), sim.rules.base_income * 1.6, 1e-6, "three levels: +60%")


func test_skill_damage_and_zone_are_capped_at_15_percent() -> void:
	var sim := new_sim()
	_unlock(sim, 5)
	for i in 3:
		check(sim.buy_research(0, &"skill_damage"))
		check(sim.buy_research(0, &"skill_zone"))
	check_near(sim.skill_damage_mult(0), 1.15, 1e-6)
	check_near(sim.skill_zone_mult(0), 1.15, 1e-6)
	check(not sim.buy_research(0, &"skill_damage") and not sim.buy_research(0, &"skill_zone"), "nothing beyond +15%")
	var ab := sim.ability_def(0)
	check_near(sim.ability_width(0), ab.width * 1.15, 0.01)
	sim.sides[1].age = 5
	check_near(sim.ability_width(1), ab.width, 0.01, "the other side is unchanged")


func _volley_damage(levels: int) -> float:
	var sim := new_sim()
	_unlock(sim, 5)   # every level of the perk is open
	for i in levels:
		sim.buy_research(0, &"skill_damage")
	sim.sides[0].age = 3   # Volley: true damage, aimed
	var ab := sim.ability_def(0)
	check_eq(ab.damage_mode, "true")
	var u := place(sim, 1, "heavy", 1100.0, 3)
	check(sim.fire_ability(0, sim.to_world(1, u.progress)))
	while not sim.effects.is_empty():
		sim.step()
	return (u.max_hp - u.hp) / ab.pulses


func test_skill_damage_raises_each_hit() -> void:
	var plain := _volley_damage(0)
	check_near(plain, sim_volley_damage(), 0.01, "a plain Volley hits for its listed damage")
	check_near(_volley_damage(1), plain * 1.05, 0.01, "+5% with one level")
	check_near(_volley_damage(3), plain * 1.15, 0.01, "+15% at most")


func sim_volley_damage() -> float:
	return GameData.get_default().age(3).ability.damage


func test_skill_zone_widens_the_zone() -> void:
	var sim := new_sim()
	_unlock(sim, 3)
	var ab := sim.ability_def(0)
	place(sim, 1, "vanguard", 1000.0, 3)
	var before := sim.ability_zone(0, 1000.0)
	sim.buy_research(0, &"skill_zone")
	var after := sim.ability_zone(0, 1000.0)
	check_near(before[1] - before[0], ab.width, 0.01)
	check_near(after[1] - after[0], ab.width * 1.05, 0.01)
	check_near((after[0] + after[1]) * 0.5, 1000.0, 0.01, "still centred on the aim")


func test_ascension_is_endless_and_gets_dearer() -> void:
	var sim := new_sim()
	_unlock(sim, 5)
	check(sim.research_locked(0, &"ascension"))
	_unlock(sim, 6)
	var u := place(sim, 0, "heavy", 100.0, 6)
	u.hp = u.max_hp * 0.5
	var base_hp := u.max_hp
	var prev := 0.0
	for n in 12:
		var cost := sim.research_cost(0, &"ascension")
		check(cost < INF and cost > prev, "level %d costs %d, more than the last (%d)" % [n + 1, cost, prev])
		prev = cost
		sim.sides[0].xp = cost
		check(sim.buy_research(0, &"ascension"))
	check_eq(sim.research_level(0, &"ascension"), 12, "no cap")
	check_near(prev, roundf(0.5 * 2800.0 * pow(1.3, 11)), 1.0, "price grows 30% a level")
	check_near(sim.attack_mult(0, "vanguard"), 1.0 + 0.03 * 12, 1e-6, "units hit harder")
	check_near(sim.health_mult(0, "vanguard"), 1.0 + 0.03 * 12, 1e-6)
	check_near(sim.attack_mult(0, "turret"), 1.0, 1e-6, "turrets are not units")
	check_near(u.max_hp, base_hp * (1.0 + 0.03 * 12), 0.01, "fielded units gain HP too")
	check_near(u.hp / u.max_hp, 0.5, 1e-4, "keeps percentage")
	var v := place(sim, 0, "ranged", 50.0, 6)
	check_near(v.max_hp, v.def.hp * 1.36, 0.01, "new units have it")


func test_ascension_stacks_with_unit_upgrades() -> void:
	var sim := new_sim()
	_unlock(sim, 6)
	sim.buy_upgrade(0, "vanguard", "attack")
	sim.buy_research(0, &"ascension")
	check_near(sim.attack_mult(0, "vanguard"), 1.15 * 1.03, 1e-6)


func test_the_ai_buys_research_but_still_evolves() -> void:
	var gd := GameData.get_default()
	var r := MatchRunner.run(gd, {"personality": &"tactician"}, {"personality": &"tactician"}, 7)
	var bought := [0, 0]
	var evolves := [0, 0]
	for ev in r.log.events:
		if ev.type == "research":
			bought[ev.side] += 1
		elif ev.type == "evolve":
			evolves[ev.side] += 1
	check(bought[0] > 0 and bought[1] > 0, "both sides researched: %s" % str(bought))
	check(evolves[0] >= 3 and evolves[1] >= 3, "and both still evolved: %s" % str(evolves))


func test_spam_archetypes_wait_for_the_last_era() -> void:
	var gd := GameData.get_default()
	var r := MatchRunner.run(gd, {"personality": &"spam_heavy"}, {"personality": &"spam_vanguard"}, 3)
	for ev in r.log.events:
		if ev.type == "research":
			var side_age := 1
			for e2 in r.log.events:
				if e2.type == "evolve" and e2.side == ev.side and e2.t <= ev.t:
					side_age = e2.age
			check_eq(side_age, 6, "a spam bot only researches in the last era (bought %s at %s)" % [ev.id, ev.t])
