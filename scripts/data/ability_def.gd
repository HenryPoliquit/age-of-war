class_name AbilityDef
extends Resource
## An age's signature ability (GDD §7). Every ability is aimed at a lane position.

@export var id: StringName
@export var display_name: String
@export var age: int = 1
@export_enum("enemy", "ally") var affects: String = "enemy"
## Width of the targeted zone in px, centred on the aim point.
@export var width: float = 300.0
## Delay between firing and the first pulse (telegraph).
@export var telegraph: float = 0.5
@export var pulses: int = 1
@export var pulse_interval: float = 0.0
## If true, each pulse hits the next slice of the zone (Broadside walking fire, Air Raid pass).
@export var sweep: bool = false
@export var damage: float = 0.0
@export_enum("slash", "pierce", "blast", "siege") var damage_type: String = "blast"
@export var knockback: float = 0.0
## Ally buff: fraction of incoming damage removed = 1 − 1/(1 + armour_buff).
@export var armour_buff: float = 0.0
@export var buff_duration: float = 0.0
