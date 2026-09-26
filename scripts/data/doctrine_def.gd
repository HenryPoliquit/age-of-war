class_name DoctrineDef
extends Resource
## A doctrine picked on evolving into Age 2 or Age 4 (GDD §9). Multipliers are neutral at 1.0.

@export var id: StringName
@export var display_name: String
@export var description: String
## The age whose evolution offers this doctrine.
@export var pick_age: int = 2
@export var unit_cost_mult: float = 1.0
@export var unit_hp_mult: float = 1.0
@export var unit_damage_mult: float = 1.0
@export var siege_cost_mult: float = 1.0
@export var siege_structure_mult: float = 1.0
@export var turret_damage_mult: float = 1.0
@export var extra_turret_slots: int = 0
