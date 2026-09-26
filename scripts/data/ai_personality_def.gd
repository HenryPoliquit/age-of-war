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
## Gold kept back for turrets/Forge/etc. before spending on units, as seconds of income.
@export var reserve_seconds: float = 4.0

## What to build against each enemy role. Derived from the single-role duel matrix
## (balance log B11): Vanguard beats Heavy, Heavy beats Ranged, Ranged beats Vanguard.
@export var counter_table: Dictionary = {"vanguard": "ranged", "ranged": "heavy", "heavy": "vanguard", "siege": "vanguard"}
## How strongly Hard+ AIs shift their mix toward counters (share of enemy army value × this).
@export var counter_strength: float = 1.5

@export_group("Evolution")
## "balanced" | "fast" (evolve immediately, never veterancy) | "strong" (all 3 ranks first)
@export_enum("balanced", "fast", "strong") var age_plan: String = "balanced"
## Balanced plan: buy this many veterancy ranks per age before evolving.
@export var balanced_vet_ranks: int = 0

@export_group("Economy & defence")
## Forge levels to target, and the earliest time to buy each.
@export var forge_target: int = 2
@export var forge_after: float = 45.0
@export var turret_target: int = 2
@export var turret_after: float = 60.0
## Build turrets sooner if own base HP fraction falls below this.
@export var turret_panic_hp: float = 0.8

@export_group("Stance")
@export var uses_hold: bool = false
## Army value (as seconds of income) to amass before releasing a Hold.
@export var hold_release_seconds: float = 20.0
## Staged pushes: gather just outside enemy turret range and attack the gate together once the
## gathered group outweighs the defence by this ratio (0 = never stage; walk straight in).
@export var push_ratio: float = 1.3

@export_group("Doctrines")
## Preferred doctrine ids; empty = random (the harness randomises).
@export var doctrine_prefs: Array[StringName] = []
