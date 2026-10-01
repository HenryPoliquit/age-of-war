class_name AiPersonalityDef
extends Resource
## Utility-AI weights for one personality or sim-only archetype (GDD §11.2–11.4).

@export var id: StringName
@export var display_name: String
## Hidden from the Skirmish menu (sim-only archetypes, GDD §11.3).
@export var sim_only: bool = false

@export_group("Army")
## Preferred share of spend per role before counter-play adjusts it.
@export var role_mix: Dictionary = {"vanguard": 0.45, "ranged": 0.3, "heavy": 0.2, "siege": 0.05}
## If set, only this role is ever queued (spam bots).
@export var spam_role: String = ""
## Gold kept back for turrets/Income/etc. before spending on units, as seconds of income.
@export var reserve_seconds: float = 4.0

## What to build against each enemy role. Derived from the single-role duel matrix
## (balance log B11): Vanguard beats Heavy, Heavy beats Ranged, Ranged beats Vanguard.
@export var counter_table: Dictionary = {"vanguard": "ranged", "ranged": "heavy", "heavy": "vanguard", "siege": "vanguard"}
## How strongly Hard+ AIs shift their mix toward counters (share of enemy army value × this).
@export var counter_strength: float = 1.5

@export_group("Evolution")
## "balanced" (Hard+ waits out pressure before evolving) | "fast" (evolve the moment XP allows)
@export_enum("balanced", "fast") var age_plan: String = "balanced"
## Sim archetype: fire the skill whenever it can hit anything (GDD §11.3).
@export var skill_eager: bool = false

@export_group("Economy & defence")
@export var turret_target: int = 2
@export var turret_after: float = 60.0
## Build turrets sooner if own base HP fraction falls below this.
@export var turret_panic_hp: float = 0.8

@export_group("Upgrades")
## Appetite per unit upgrade row: scales the gold fielded in that row when judging whether an upgrade
## pays for itself (0 = never upgrade that row).
@export var upgrade_bias: Dictionary = {"vanguard": 1.0, "ranged": 1.0, "heavy": 1.0, "siege": 1.0}
## Only buy unit/turret upgrades once the army on the lane is worth this many seconds of income.
@export var upgrade_after_army_seconds: float = 15.0

@export_group("Research")
## Share of the XP earned in each era (before the last) this personality will put into research instead
## of the evolution; 0 = none until the last era, when everything spare goes into research.
@export_range(0.0, 1.0, 0.01) var research_share: float = 0.1
## Research ids in the order wanted (data/research/): the first one still open is saved for and bought.
@export var research_priority: PackedStringArray = PackedStringArray(["income", "skill_damage", "skill_zone", "train_speed", "queue_slots", "turret_attack", "turret_health", "turret_range", "base_health", "ascension"])
