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
## Damage per hit.
var base_damage: float
var cost_paid: float
var cooldown: float = 0.0
var slow: float = 0.0
## A skill's slow (fraction of speed lost) and the match time it lasts until; folded into `slow` each tick.
var skill_slow: float = 0.0
var skill_slow_until: float = -1.0
## Presentation hooks — the sim never reads these.
var state: StringName = &"walk"
var last_hit_time: float = -10.0
var last_attack_time: float = -10.0
var stat_damage_dealt: float = 0.0
var stat_damage_taken: float = 0.0


func alive() -> bool:
	return hp > 0.0
