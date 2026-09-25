class_name RulesDef
extends Resource
## Match-wide rules and economy constants (GDD §2, §3, §5.5, §6, §8).

@export_group("Simulation")
@export var tick_dt: float = 0.1
@export var match_time_limit: float = 1800.0
@export var lane_length: float = 2400.0
@export var unit_spacing: float = 12.0

@export_group("Start")
@export var start_gold: float = 150.0
@export var start_turret_slots: int = 2

@export_group("Economy")
@export var base_income: float = 2.0
@export var tide_start_times: PackedFloat32Array = PackedFloat32Array([0, 135, 270, 405, 540, 675])
@export var tide_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 1.7, 2.9, 4.9, 8.4, 14.2])
@export var forge_costs: PackedInt32Array = PackedInt32Array([100, 250, 500])
@export var forge_income_bonus: float = 0.2
@export var age_cost_multiplier: float = 1.7
@export var bounty_fraction: float = 0.5
@export var xp_per_kill_fraction: float = 0.8
@export var xp_per_base_damage: float = 0.1

@export_group("Spawning")
@export var queue_slots: int = 5
@export var field_cap: int = 30

@export_group("Evolution & veterancy")
@export var evolve_time: float = 5.0
@export var veterancy_fractions: PackedFloat32Array = PackedFloat32Array([0.15, 0.2, 0.25])
@export var veterancy_bonus: float = 0.1

@export_group("Turrets")
## Cost to unlock slot N (index = slot number − 1). Multiplied by the age cost multiplier.
@export var turret_slot_costs: PackedInt32Array = PackedInt32Array([0, 0, 150, 400, 700])
@export var sell_refund: float = 0.5
## Turrets and the base share the gate; units must be this close to hit them.
@export var structure_offset: float = 0.0

@export_group("Momentum & abilities")
@export var momentum_cap: float = 100.0
@export var momentum_push_rate: float = 2.0
@export var momentum_per_base_pct: float = 0.5
@export var ability_cost: float = 100.0
@export var ability_cooldown: float = 45.0

@export_group("Escalation")
@export var escalation_start: float = 900.0
@export var escalation_interval: float = 30.0
@export var escalation_max_stacks: int = 4
@export var escalation_turret_penalty: float = 0.15
@export var escalation_structure_bonus: float = 0.1

@export_group("Damage matrix")
## damage_type -> { armour -> multiplier } (GDD §5.2).
@export var damage_matrix: Dictionary = {
	"slash": {"light": 1.0, "heavy": 0.7, "structure": 0.5},
	"pierce": {"light": 1.25, "heavy": 0.6, "structure": 0.4},
	"blast": {"light": 0.8, "heavy": 1.3, "structure": 1.2},
	"siege": {"light": 0.5, "heavy": 0.5, "structure": 2.5},
}


func tide_level_at(t: float) -> int:
	var level := 1
	for i in tide_start_times.size():
		if t >= tide_start_times[i]:
			level = i + 1
	return level


func tide_multiplier_at(t: float) -> float:
	return tide_multipliers[tide_level_at(t) - 1]


func age_cost_mult(age: int) -> float:
	return pow(age_cost_multiplier, age - 1)


func matrix(damage_type: String, armour: String) -> float:
	return float(damage_matrix.get(damage_type, {}).get(armour, 1.0))


func escalation_stacks_at(t: float) -> int:
	if t < escalation_start:
		return 0
	return mini(escalation_max_stacks, 1 + int((t - escalation_start) / escalation_interval))
