class_name SimTurret
extends RefCounted
## A turret in a base slot. Only Siege units can damage turrets (PLAN D3).

var def: TurretDef
var slot: int
var hp: float
var max_hp: float
var cooldown: float = 0.0
var last_fire_time: float = -10.0
var last_target_x: float = 0.0
var stat_damage_dealt: float = 0.0


func alive() -> bool:
	return hp > 0.0
