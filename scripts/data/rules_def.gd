class_name RulesDef
extends Resource
## Match-wide rules and economy constants (GDD §2, §3, §5.5, §6, §8).

@export_group("Simulation")
@export var tick_dt: float = 0.1
@export var match_time_limit: float = 1800.0
@export var lane_length: float = 2400.0
@export var unit_spacing: float = 12.0
## Units with range at or below this are melee: they press in until their front is melee_contact px from the enemy front (or gate).
@export var melee_range_max: float = 45.0
@export var melee_contact: float = 8.0

@export_group("Start")
@export var start_gold: float = 150.0
@export var start_turret_slots: int = 1

@export_group("Economy")
@export var base_income: float = 2.0
@export var tide_start_times: PackedFloat32Array = PackedFloat32Array([0, 135, 270, 405, 540, 675])
@export var tide_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 1.7, 2.9, 4.9, 8.4, 14.2])
@export var age_cost_multiplier: float = 1.7
@export var bounty_fraction: float = 0.5
@export var xp_per_kill_fraction: float = 0.8
@export var xp_per_base_damage: float = 0.1

@export_group("Upgrades")
## Gold for upgrade level n (1-based) = factor[n − 1] × the current price of what is upgraded
## (the role's current-age unit, or the average current-age turret).
@export var upgrade_cost_factors: PackedFloat32Array = PackedFloat32Array([0.6, 1.0, 1.5])
@export var upgrade_attack_bonus: float = 0.15
@export var upgrade_health_bonus: float = 0.15
## Fraction of incoming damage removed per Defence level.
@export var upgrade_defence_bonus: float = 0.1
## Turret range and Support aura radius per Range level.
@export var upgrade_range_bonus: float = 0.1
## Income row (was the Forge): cost per level (× age cost multiplier) and income bonus per level.
@export var income_upgrade_costs: PackedInt32Array = PackedInt32Array([100, 250, 500])
@export var income_upgrade_bonus: float = 0.2

@export_group("Spawning")
@export var queue_slots: int = 5
@export var field_cap: int = 30

@export_group("Evolution")
@export var evolve_time: float = 5.0

@export_group("Turrets")
## Cost to unlock slot N (index N − 1; slot 1 is free). The array length is the slot maximum.
## Multiplied by the age cost multiplier.
@export var turret_slot_costs: PackedInt32Array = PackedInt32Array([0, 150, 400, 700])
@export var sell_refund: float = 0.5
## Turrets and the base share the gate; units must be this close to hit them.
@export var structure_offset: float = 0.0

@export_group("Skills")
## Seconds before the same side can fire its skill again.
@export var ability_cooldown: float = 20.0

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
