class_name AgeDef
extends Resource
## One of the six ages (GDD §4).

@export var index: int = 1
@export var display_name: String
## XP needed to evolve INTO this age (0 for Age 1).
@export var evolve_cost: int = 0
## Veterancy ranks in this age cost fractions of this value (the next evolution's cost, GDD §4.5).
@export var veterancy_base_xp: int = 300
@export var base_max_hp: float = 1000.0
@export var units: Array[UnitDef] = []
@export var turrets: Array[TurretDef] = []
@export var ability: AbilityDef
## Doctrine choice offered when evolving into this age (empty = none).
@export var doctrine_options: Array[DoctrineDef] = []
@export_group("Graybox palette")
@export var sky_color: Color = Color(0.5, 0.6, 0.8)
@export var ground_color: Color = Color(0.4, 0.35, 0.25)
