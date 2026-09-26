class_name MatchRunner
extends RefCounted
## Runs a full AI-vs-AI match headless at maximum speed. Used by the balance harness and tests.


## Returns {winner, duration, escalated, age_times: [PackedFloat32Array x2], doctrines: [[ids],[ids]], log}.
static func run(data: GameData, left: Dictionary, right: Dictionary, seed: int, random_doctrines := false, start_age := 1) -> Dictionary:
	var sim := MatchSim.new(data, seed)
	if start_age > 1:
		sim.set_start_age(start_age)
	var ais: Array[UtilityAI] = []
	var cfgs := [left, right]
	for i in 2:
		var ai := UtilityAI.make(data, cfgs[i].personality, cfgs[i].get("difficulty", &"hard"), i, seed * 31 + i * 7919)
		ai.random_doctrines = random_doctrines or cfgs[i].get("random_doctrines", false)
		ai.forced_doctrines = cfgs[i].get("doctrines", [])
		ai.setup(sim)
		sim.sides[i].race = StringName(cfgs[i].get("race", "human"))
		ais.append(ai)
	var dt := data.rules.tick_dt
	while not sim.is_over():
		for ai in ais:
			ai.update(sim, dt)
		sim.step()
	sim.match_log.meta = {
		"left": String(left.personality), "right": String(right.personality),
		"left_difficulty": String(left.get("difficulty", &"hard")), "right_difficulty": String(right.get("difficulty", &"hard")),
		"winner": sim.winner, "duration": snappedf(sim.time, 0.1),
	}
	var docs := []
	for s in sim.sides:
		var ids := []
		for d in s.doctrines:
			ids.append(d.id)
		docs.append(ids)
	return {
		"winner": sim.winner,
		"duration": sim.time,
		"escalated": sim.time >= data.rules.escalation_start,
		"age_times": [sim.sides[0].age_times, sim.sides[1].age_times],
		"final_ages": [sim.sides[0].age, sim.sides[1].age],
		"doctrines": docs,
		"log": sim.match_log,
	}
