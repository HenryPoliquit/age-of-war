class_name AgeDef
extends Resource
## One of the six ages (GDD §4).

@export var index: int = 1
@export var display_name: String
## XP needed to evolve INTO this age (0 for Age 1).
@export var evolve_cost: int = 0
@export var base_max_hp: float = 1000.0
@export var units: Array[UnitDef] = []
@export var turrets: Array[TurretDef] = []
@export var ability: AbilityDef
@export_group("Graybox palette")
@export var sky_color: Color = Color(0.5, 0.6, 0.8)
@export var ground_color: Color = Color(0.4, 0.35, 0.25)
