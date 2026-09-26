class_name RaceDef
extends Resource
## A playable race: names (and, in the view, looks) for every unit, turret and ability slot.
## Stats are shared: all races use the same UnitDef/TurretDef/AbilityDef per age and role, so the
## choice of race is cosmetic and balance work carries over (docs/GDD.md §5.7).

@export var id: StringName
@export var display_name: String
@export var description: String
## Keyed by the shared ids, e.g. "iron_vanguard" -> "Legionary".
@export var unit_names: Dictionary = {}
@export var turret_names: Dictionary = {}
@export var ability_names: Dictionary = {}


func unit_name(def: UnitDef) -> String:
	return unit_names.get(String(def.id), def.display_name)


func turret_name(def: TurretDef) -> String:
	return turret_names.get(String(def.id), def.display_name)


func ability_name(def: AbilityDef) -> String:
	return ability_names.get(String(def.id), def.display_name)
