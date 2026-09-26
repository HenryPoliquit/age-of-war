class_name UnitDef
extends Resource
## One lane unit at one age. Stats are the final values for that age (GDD §5.4 scaling is baked in).

@export var id: StringName
@export var display_name: String
@export var age: int = 1
@export_enum("vanguard", "ranged", "heavy", "siege") var role: String = "vanguard"
@export_enum("light", "heavy") var armour: String = "light"
@export_enum("slash", "pierce", "blast", "siege") var damage_type: String = "slash"
@export var cost: int = 0
@export var train_time: float = 0.0
@export var hp: float = 0.0
@export var damage: float = 0.0
@export var attack_interval: float = 0.0
@export var range: float = 0.0
## Ranged Siege cannot hit anything closer than this (GDD §5.6). 0 = no minimum.
@export var min_range: float = 0.0
@export var speed: float = 0.0
## Momentum granted to the killer (GDD §8.2).
@export var momentum_on_kill: int = 0


func is_ranged_siege() -> bool:
	return role == "siege" and min_range > 0.0
