class_name TurretDef
extends Resource
## One turret type at one age (GDD §6). Support turrets use the aura fields and do not attack.

@export var id: StringName
@export var display_name: String
@export var age: int = 1
@export_enum("sentry", "artillery", "support") var kind: String = "sentry"
@export_enum("slash", "pierce", "blast", "siege", "none") var damage_type: String = "pierce"
@export var cost: int = 0
@export var hp: float = 0.0
@export var damage: float = 0.0
@export var attack_interval: float = 0.0
## Measured from the owning base's gate.
@export var range: float = 0.0
@export var min_range: float = 0.0
@export var splash: float = 0.0
@export var aura_radius: float = 0.0
## Fractional speed reduction applied to enemies inside the aura (0.3 = −30%).
@export var aura_slow: float = 0.0
