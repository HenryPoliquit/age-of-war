class_name AiDifficultyDef
extends Resource
## AI difficulty level (GDD §11.1). Easy–Hard get no resource bonus.

@export var id: StringName
@export var display_name: String
@export var decision_interval: float = 1.5
## 0 = ignores composition, 1 = reacts to majority role, 2+ = counters every enemy role.
@export var counter_level: int = 1
## Enemy value (Age 1 gold, scaled by the era cost multiplier) a skill must hit before the AI fires it.
@export var skill_min_value: float = 60.0
## Aimed skills land this many px (at most) off the densest enemy group; 0 = perfectly aimed.
@export var skill_aim_error: float = 0.0
@export var income_bonus: float = 0.0
## Scales a personality's research share: 0 = never buys research before the last era.
@export_range(0.0, 1.0, 0.05) var research_skill: float = 1.0
