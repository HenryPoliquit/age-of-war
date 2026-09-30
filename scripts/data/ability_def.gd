class_name AbilityDef
extends Resource
## An era's special skill (GDD §7), paid in XP. Skills hit enemy units only, never structures.
## Where it lands is `aim` (the sim picks, or the caster aims it); what it does to each victim is `damage_mode`.

@export var id: StringName
@export var display_name: String
@export var age: int = 1
## area: one window on the lane. strip: from the enemy's front unit back toward their base.
## sweep: travels from our gate to the enemy gate, one slice per pulse.
@export_enum("area", "strip", "sweep") var shape: String = "area"
## auto: the sim picks the spot from the shape (area: the densest enemy group; strip: the enemy front;
## sweep: the whole lane) and one click fires it. target: the caster clicks a point on the lane and an
## area lands centred there (only area skills can be aimed).
@export_enum("auto", "target") var aim: String = "auto"
## XP spent to fire it.
@export var xp_cost: int = 0
## Zone length in px for area and strip (a sweep always covers the whole lane).
@export var width: float = 300.0
## Delay between firing and the first pulse (telegraph).
@export var telegraph: float = 0.5
@export var pulses: int = 1
@export var pulse_interval: float = 0.0
## flat: `damage` through the armour matrix and the Defence upgrades, like a unit's attack.
## true: `damage` ignoring armour and Defence upgrades (armour-piercing).
## percent: `damage_pct` of each victim's max health, ignoring armour and Defence upgrades.
@export_enum("flat", "true", "percent") var damage_mode: String = "flat"
## Damage per pulse for flat and true skills.
@export var damage: float = 0.0
## Share of each victim's max HP taken per pulse (0.25 = 25%) for percent skills.
@export_range(0.0, 1.0, 0.01) var damage_pct: float = 0.0
## Flat skills go through the matrix with this type; true and percent skills only use it for the impact look.
@export_enum("slash", "pierce", "blast", "siege") var damage_type: String = "blast"
@export var knockback: float = 0.0
## Speed lost by every unit hit (0.4 = 40% slower) for `slow_time` seconds; 0 = no slow.
@export_range(0.0, 0.9, 0.05) var slow: float = 0.0
@export var slow_time: float = 0.0


func is_targeted() -> bool:
	return aim == "target"


## True when armour and Defence upgrades do not reduce this skill's damage.
func ignores_armour() -> bool:
	return damage_mode != "flat"
