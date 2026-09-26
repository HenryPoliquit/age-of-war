class_name AbilityDef
extends Resource
## An era's special skill (GDD §7). Fired with one click, aimed automatically by its shape, paid in XP.
## Skills hit enemy units only, never structures.

@export var id: StringName
@export var display_name: String
@export var age: int = 1
## area: centred on the densest enemy group. strip: from the enemy's front unit back toward their base.
## sweep: travels from our gate to the enemy gate, one slice per pulse.
@export_enum("area", "strip", "sweep") var shape: String = "area"
## XP spent to fire it.
@export var xp_cost: int = 0
## Zone length in px for area and strip (a sweep always covers the whole lane).
@export var width: float = 300.0
## Delay between firing and the first pulse (telegraph).
@export var telegraph: float = 0.5
@export var pulses: int = 1
@export var pulse_interval: float = 0.0
@export var damage: float = 0.0
@export_enum("slash", "pierce", "blast", "siege") var damage_type: String = "blast"
@export var knockback: float = 0.0
