class_name SimSide
extends RefCounted
## All per-side match state. Index 0 = left (player in Skirmish), 1 = right.

var index: int
var gold: float = 0.0
var xp: float = 0.0
var age: int = 1
## Upgrade levels: row -> {stat -> level}; missing = 0 (MatchSim.UPGRADES lists rows and stats).
var upgrades: Dictionary = {}
## XP research levels: research id -> level; missing = 0 (data/research/*.tres).
var research: Dictionary = {}
## Research effect totals (level × bonus per perk id), kept in step with `research` by MatchSim.
var research_totals: Dictionary = {}
var turret_slots: int = 1
var turrets: Array = [null, null, null, null]
var base_hp: float = 1000.0
var base_max_hp: float = 1000.0
var queue: Array[UnitDef] = []
## Gold paid for each queued unit, parallel to `queue`.
var queue_paid: Array[float] = []
var train_progress: float = 0.0
## Seconds left in the evolution transition; 0 when not evolving.
var evolve_left: float = 0.0
var ability_cooldown: float = 0.0
var units: Array[SimUnit] = []
var income_bonus: float = 0.0
var last_base_hit_time: float = -100.0
## Presentation/AI info.
var controller_name: String = ""
## Cosmetic: which race's names and looks this side uses (stats are shared, see RaceDef).
var race: StringName = &"human"
var age_times: PackedFloat32Array = PackedFloat32Array([0.0, -1, -1, -1, -1, -1])
var stat_gold_earned: float = 0.0
var stat_gold_spent: float = 0.0
var stat_xp_earned: float = 0.0
var stat_xp_research: float = 0.0


func is_evolving() -> bool:
	return evolve_left > 0.0



func upgrade_level(row: String, stat: String) -> int:
	return upgrades.get(row, {}).get(stat, 0)


func set_upgrade_level(row: String, stat: String, level: int) -> void:
	if not upgrades.has(row):
		upgrades[row] = {}
	upgrades[row][stat] = level


func research_level(id: StringName) -> int:
	return research.get(id, 0)


## Sum of this side's research bonuses for an effect (a fraction; whole slots for queue_slots).
func research_total(id: StringName) -> float:
	return research_totals.get(id, 0.0)


func turret_count() -> int:
	var n := 0
	for t in turrets:
		if t != null:
			n += 1
	return n


func army_value() -> float:
	var v := 0.0
	for u in units:
		v += u.cost_paid
	return v


func queued_value() -> float:
	var v := 0.0
	for p in queue_paid:
		v += p
	return v
