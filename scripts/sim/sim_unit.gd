class_name SimUnit
extends RefCounted
## A unit on the lane. `progress` is distance from its own gate (0 .. lane_length).

var id: int
var side: int
var def: UnitDef
var age: int
var progress: float = 0.0
var hp: float
var max_hp: float
## Damage before veterancy (doctrine multipliers baked in at spawn).
var base_damage: float
var cost_paid: float
var vet_rank: int = 0
var cooldown: float = 0.0
var armour_buff: float = 0.0
var armour_buff_until: float = -1.0
var slow: float = 0.0
## Presentation hooks — the sim never reads these.
var state: StringName = &"walk"
var last_hit_time: float = -10.0
var last_attack_time: float = -10.0
var stat_damage_dealt: float = 0.0
var stat_damage_taken: float = 0.0


func alive() -> bool:
	return hp > 0.0


func damage_mult(vet_bonus: float) -> float:
	return 1.0 + vet_bonus * vet_rank
