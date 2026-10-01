class_name ResearchDef
extends Resource
## One XP research perk (GDD §6.2). Research is bought with XP, never gold, and holds everything that is
## not a unit upgrade: fortifications, training, income, skills and Ascension. Prices are fractions of the
## XP the next evolution costs, so a perk bought later in the match costs more, and every level opens in
## a given era: nobody can buy the whole tree before they have evolved through it.

## Also the effect key: turret_attack | turret_health | turret_range | base_health | train_speed | queue_slots |
## income | skill_damage | skill_zone | ascension (MatchSim reads `research_total(side, id)`).
@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
## Panel row: fortify | logistics | skills | ascension.
@export_enum("fortify", "logistics", "skills", "ascension") var group: String = "fortify"
## Sort key inside the panel.
@export var order: int = 0
## Value added per level: a fraction (0.1 = +10%), or whole slots for `queue_slots`.
@export var bonus: float = 0.1
## Levels; 0 = endless (Ascension), whose price is `cost_factors[0] × cost_growth^level`.
@export var levels: int = 3
## Price of level n (1-based) = factor[n − 1] × research_basis (the XP the current era's evolution costs).
@export var cost_factors: PackedFloat32Array = PackedFloat32Array([0.25, 0.4, 0.6])
## Endless perks only: each further level costs this many times the one before.
@export var cost_growth: float = 1.0
## The earliest era that opens level n (index n − 1; an endless perk uses entry 0 for every level).
@export var min_ages: PackedInt32Array = PackedInt32Array([2, 3, 4])


func is_endless() -> bool:
	return levels <= 0


func is_maxed(level: int) -> bool:
	return not is_endless() and level >= levels


## Era that opens the level after `level` (the next purchase).
func age_for_next(level: int) -> int:
	return min_ages[mini(level, min_ages.size() - 1)]


## Price factor of the level after `level` (the next purchase).
func factor_for_next(level: int) -> float:
	if is_endless():
		return cost_factors[0] * pow(cost_growth, level)
	return cost_factors[mini(level, cost_factors.size() - 1)]
