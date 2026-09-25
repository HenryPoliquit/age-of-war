class_name AiDifficultyDef
extends Resource
## AI difficulty level (GDD §11.1). Easy–Hard get no resource bonus.

@export var id: StringName
@export var display_name: String
@export var decision_interval: float = 1.5
## 0 = ignores composition, 1 = reacts to majority role, 2 = matrix-aware, 3 = + doctrine counters.
@export var counter_level: int = 1
## 0 = random within zone, 1 = largest cluster, 2 = highest-value cluster timed with pushes.
@export var aim_level: int = 1
@export var income_bonus: float = 0.0
