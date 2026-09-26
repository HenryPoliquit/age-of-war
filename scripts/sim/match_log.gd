class_name MatchLog
extends RefCounted
## Per-match JSON log (GDD §15.4): 1 s timeline samples, events, and per-unit trade stats.
## The harness computes its report from these; the post-match screen draws from them.

var seed: int = 0
var meta: Dictionary = {}
## Each sample: {t, front, tide, esc, sides: [{gold, xp, momentum, army, age, base_hp, base_max}, ...]}
var timeline: Array[Dictionary] = []
var events: Array[Dictionary] = []
## unit id -> {spawned, gold, dealt, absorbed}, per side.
var unit_stats: Array[Dictionary] = [{}, {}]
var base_damage: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var ability_pulses: PackedInt32Array = PackedInt32Array([0, 0])
## Gold value of units that died, by where they died: 12 buckets of 200 px of the victim's own
## progress (0 = at its own gate, 11 = at the enemy gate). Shows whether pushes die at the gates.
var deaths: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])


func sample(sim: MatchSim) -> void:
	var sides := []
	for s in sim.sides:
		sides.append({
			"gold": snappedf(s.gold, 0.1),
			"xp": snappedf(s.xp, 0.1),
			"xp_earned": snappedf(s.stat_xp_earned, 0.1),
			"gold_earned": snappedf(s.stat_gold_earned, 0.1),
			"momentum": snappedf(s.momentum, 0.1),
			"army": snappedf(s.army_value(), 0.1),
			"units": s.units.size(),
			"age": s.age,
			"base_hp": snappedf(s.base_hp, 0.1),
			"base_max": s.base_max_hp,
		})
	timeline.append({
		"t": snappedf(sim.time, 0.01),
		"front": snappedf(sim.front_x, 0.1),
		"tide": sim.rules.tide_level_at(sim.time),
		"esc": sim.escalation,
		"sides": sides,
	})


func _stat(side: int, def: UnitDef) -> Dictionary:
	var d: Dictionary = unit_stats[side]
	if not d.has(def.id):
		d[def.id] = {"spawned": 0, "gold": 0.0, "dealt": 0.0, "absorbed": 0.0}
	return d[def.id]


func count_spawn(side: int, def: UnitDef, paid: float) -> void:
	var st := _stat(side, def)
	st.spawned += 1
	st.gold += paid


func count_damage(side: int, def: UnitDef, dmg: float) -> void:
	_stat(side, def).dealt += dmg


func count_absorbed(side: int, def: UnitDef, dmg: float) -> void:
	_stat(side, def).absorbed += dmg


func count_death(progress: float, lane: float, value: float) -> void:
	deaths[clampi(int(progress / lane * 12.0), 0, 11)] += value


func count_base_damage(by_side: int, dmg: float) -> void:
	base_damage[by_side] += dmg


func count_ability_damage(side: int) -> void:
	ability_pulses[side] += 1


func to_dict() -> Dictionary:
	var us := []
	for d in unit_stats:
		var m := {}
		for k in d:
			m[String(k)] = d[k]
		us.append(m)
	return {
		"version": 1,
		"seed": seed,
		"meta": meta,
		"timeline": timeline,
		"events": events,
		"unit_stats": us,
		"base_damage": Array(base_damage),
	}


func save_json(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict()))
	return OK
