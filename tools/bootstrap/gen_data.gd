extends SceneTree
## ONE-SHOT BOOTSTRAP: writes the initial data/*.tres from the GDD baselines and scaling rules.
## After bootstrap the .tres files are the source of truth — edit them, not this script.
## Refuses to overwrite existing files unless run with `-- --force`.
##   tools/godot --headless --path . -s tools/bootstrap/gen_data.gd

const AGE_NAMES := ["Stone", "Bronze", "Iron", "Medieval", "Gunpowder", "Arcane"]
const EVOLVE_COSTS := [0, 300, 650, 1200, 2050, 3750]
## Age 6 has no next evolution; its veterancy ranks price off this value (PLAN §4 decision D6).
const AGE6_VET_BASE := 6000
const SKY := [Color("e8b77a"), Color("8fc7ee"), Color("9aa7a0"), Color("5b6573"), Color("a0664a"), Color("1c1433")]
const GROUND := [Color("a07a45"), Color("c9b98a"), Color("5f7a4a"), Color("58524a"), Color("4a3b30"), Color("2b2f3f")]

## Units and turrets get neutral per-slot ids ("iron_vanguard"); each race names them (data/races).
# role: [first_age, cost, train, hp, dmg, interval, range, min_range, speed, armour, dtype, momentum]
const BASE := {
	"vanguard": [1, 15, 1.0, 110, 14, 1.0, 30, 0, 70, "light", "slash", 1],
	"ranged": [1, 25, 1.5, 60, 10, 1.2, 220, 0, 60, "light", "pierce", 1],
	"heavy": [1, 100, 3.0, 420, 30, 1.6, 40, 0, 45, "heavy", "blast", 3],
	"siege": [2, 90, 3.0, 160, 60, 2.5, 30, 0, 40, "light", "siege", 2],
}
# kind: [first_age, dtype, cost, hp, dmg, interval, range, min_range, splash, aura_radius, aura_slow]
const TURRET_BASE := {
	"sentry": [1, "pierce", 100, 400, 18, 1.4, 300, 0, 0, 0, 0.0],
	"artillery": [2, "blast", 180, 500, 45, 3.0, 420, 150, 60, 0, 0.0],
	"support": [3, "none", 220, 500, 0, 1.0, 0, 0, 0, 180, 0.3],
}
const ABILITIES := [
	{"id": "stampede", "name": "Stampede", "affects": "enemy", "width": 300, "telegraph": 0.5, "pulses": 1, "interval": 0.0, "sweep": false, "damage": 80, "dtype": "slash", "knockback": 60},
	{"id": "shieldwall", "name": "Shieldwall", "affects": "ally", "width": 300, "telegraph": 0.2, "pulses": 1, "interval": 0.0, "sweep": false, "armour": 0.4, "duration": 8.0},
	{"id": "volley", "name": "Volley", "affects": "enemy", "width": 250, "telegraph": 0.5, "pulses": 3, "interval": 1.0, "sweep": false, "damage": 34, "dtype": "pierce"},
	{"id": "bombardment", "name": "Bombardment", "affects": "enemy", "width": 400, "telegraph": 0.6, "pulses": 4, "interval": 0.5, "sweep": true, "damage": 70, "dtype": "blast", "knockback": 12},
	{"id": "cannonade", "name": "Cannonade", "affects": "enemy", "width": 500, "telegraph": 1.5, "pulses": 5, "interval": 0.3, "sweep": true, "damage": 70, "dtype": "blast", "knockback": 12},
	{"id": "starfall", "name": "Starfall", "affects": "enemy", "width": 90, "telegraph": 1.5, "pulses": 1, "interval": 0.0, "sweep": false, "damage": 400, "dtype": "blast"},
]

var force := false


func _init() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	for d in ["data", "data/ages", "data/units", "data/turrets", "data/abilities", "data/doctrines", "data/ai/personalities", "data/ai/difficulties"]:
		DirAccess.make_dir_recursive_absolute("res://" + d)
	_save(RulesDef.new(), "res://data/rules.tres")
	var doctrines := _doctrines()
	for age in range(1, 7):
		_gen_age(age, doctrines)
	_gen_ai()
	print("bootstrap done")
	quit()


func _save(res: Resource, path: String) -> void:
	if FileAccess.file_exists(path) and not force:
		res.take_over_path(path)
		print("skip (exists): ", path)
		return
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "save failed: " + path)
	res.take_over_path(path)


func _slug(s: String) -> String:
	return s.to_lower().replace(" ", "_").replace("-", "_")


func _gen_age(age: int, doctrines: Dictionary) -> void:
	var a := AgeDef.new()
	a.index = age
	a.display_name = AGE_NAMES[age - 1]
	a.evolve_cost = EVOLVE_COSTS[age - 1]
	a.veterancy_base_xp = EVOLVE_COSTS[age] if age < 6 else AGE6_VET_BASE
	a.base_max_hp = roundf(1000.0 * pow(1.7, age - 1))
	a.sky_color = SKY[age - 1]
	a.ground_color = GROUND[age - 1]
	for role in ["vanguard", "ranged", "heavy", "siege"]:
		var b: Array = BASE[role]
		if age < b[0]:
			continue
		var steps: int = age - int(b[0])
		var u := UnitDef.new()
		u.display_name = "%s %s" % [AGE_NAMES[age - 1], role.capitalize()]
		u.id = StringName(_slug(u.display_name))
		u.age = age
		u.role = role
		u.cost = int(roundf(b[1] * pow(1.7, steps)))
		u.train_time = b[2]
		u.hp = roundf(b[3] * pow(1.9, steps))
		u.damage = roundf(b[4] * pow(1.9, steps) * 10.0) / 10.0
		u.attack_interval = b[5]
		u.range = b[6]
		u.min_range = b[7]
		u.speed = b[8]
		u.armour = b[9]
		u.damage_type = b[10]
		u.momentum_on_kill = b[11]
		if role == "siege" and age >= 3:
			u.range = 380
			u.min_range = 120
			u.attack_interval = 3.5
		_save(u, "res://data/units/%s.tres" % u.id)
		a.units.append(u)
	for kind in ["sentry", "artillery", "support"]:
		var t: Array = TURRET_BASE[kind]
		if age < t[0]:
			continue
		var steps: int = age - int(t[0])
		var td := TurretDef.new()
		td.display_name = "%s %s" % [AGE_NAMES[age - 1], kind.capitalize()]
		td.id = StringName(_slug(td.display_name))
		td.age = age
		td.kind = kind
		td.damage_type = t[1]
		td.cost = int(roundf(t[2] * pow(1.7, steps)))
		td.hp = roundf(t[3] * pow(1.9, steps))
		td.damage = roundf(t[4] * pow(1.9, steps) * 10.0) / 10.0
		td.attack_interval = t[5]
		td.range = t[6]
		td.min_range = t[7]
		td.splash = t[8]
		td.aura_radius = t[9]
		td.aura_slow = t[10]
		_save(td, "res://data/turrets/%s.tres" % td.id)
		a.turrets.append(td)
	var ab: Dictionary = ABILITIES[age - 1]
	var ad := AbilityDef.new()
	ad.id = StringName(ab.id)
	ad.display_name = ab.name
	ad.age = age
	ad.affects = ab.affects
	ad.width = ab.width
	ad.telegraph = ab.telegraph
	ad.pulses = ab.pulses
	ad.pulse_interval = ab.interval
	ad.sweep = ab.sweep
	ad.damage = roundf(float(ab.get("damage", 0)) * pow(1.9, age - 1))
	ad.damage_type = ab.get("dtype", "blast")
	ad.knockback = ab.get("knockback", 0)
	ad.armour_buff = ab.get("armour", 0.0)
	ad.buff_duration = ab.get("duration", 0.0)
	_save(ad, "res://data/abilities/%s.tres" % ad.id)
	a.ability = ad
	if age == 2:
		a.doctrine_options = [doctrines.horde, doctrines.elite]
	elif age == 4:
		a.doctrine_options = [doctrines.bastion, doctrines.siegecraft]
	_save(a, "res://data/ages/age_%d.tres" % age)


func _doctrines() -> Dictionary:
	var out := {}
	var horde := DoctrineDef.new()
	horde.id = &"horde"; horde.display_name = "Horde"; horde.pick_age = 2
	horde.description = "Units −20% cost, −15% HP."
	horde.unit_cost_mult = 0.8; horde.unit_hp_mult = 0.85
	var elite := DoctrineDef.new()
	elite.id = &"elite"; elite.display_name = "Elite"; elite.pick_age = 2
	elite.description = "Units +25% HP and damage, +30% cost."
	elite.unit_cost_mult = 1.3; elite.unit_hp_mult = 1.25; elite.unit_damage_mult = 1.25
	var bastion := DoctrineDef.new()
	bastion.id = &"bastion"; bastion.display_name = "Bastion"; bastion.pick_age = 4
	bastion.description = "Turrets +25% damage, a 5th turret slot."
	bastion.turret_damage_mult = 1.25; bastion.extra_turret_slots = 1
	var siegecraft := DoctrineDef.new()
	siegecraft.id = &"siegecraft"; siegecraft.display_name = "Siegecraft"; siegecraft.pick_age = 4
	siegecraft.description = "Siege units +50% structure damage, −25% cost."
	siegecraft.siege_structure_mult = 1.5; siegecraft.siege_cost_mult = 0.75
	for d in [horde, elite, bastion, siegecraft]:
		_save(d, "res://data/doctrines/%s.tres" % d.id)
		out[String(d.id)] = d
	return out


func _gen_ai() -> void:
	var diffs := [
		["easy", "Easy", 3.0, 0, 0, 0.0],
		["normal", "Normal", 1.5, 1, 1, 0.0],
		["hard", "Hard", 0.75, 2, 2, 0.0],
		["brutal", "Brutal", 0.5, 2, 2, 0.1],
		["nightmare", "Nightmare", 0.5, 3, 2, 0.25],
	]
	for d in diffs:
		var r := AiDifficultyDef.new()
		r.id = StringName(d[0]); r.display_name = d[1]; r.decision_interval = d[2]
		r.counter_level = d[3]; r.aim_level = d[4]; r.income_bonus = d[5]
		_save(r, "res://data/ai/difficulties/%s.tres" % d[0])

	var tac := AiPersonalityDef.new()
	tac.id = &"tactician"; tac.display_name = "Tactician"
	_save(tac, "res://data/ai/personalities/tactician.tres")

	var rush := AiPersonalityDef.new()
	rush.id = &"rusher"; rush.display_name = "Rusher"
	rush.role_mix = {"vanguard": 0.55, "ranged": 0.3, "heavy": 0.1, "siege": 0.05}
	rush.reserve_seconds = 1.0; rush.age_plan = "fast"; rush.forge_target = 1; rush.forge_after = 120.0
	rush.turret_target = 1; rush.turret_after = 240.0; rush.uses_hold = true
	rush.doctrine_prefs = [&"horde", &"siegecraft"]
	_save(rush, "res://data/ai/personalities/rusher.tres")

	var turtle := AiPersonalityDef.new()
	turtle.id = &"turtle"; turtle.display_name = "Turtle"
	turtle.role_mix = {"vanguard": 0.4, "ranged": 0.35, "heavy": 0.2, "siege": 0.05}
	turtle.reserve_seconds = 6.0; turtle.age_plan = "strong"; turtle.forge_target = 2
	turtle.turret_target = 4; turtle.turret_after = 20.0; turtle.turret_panic_hp = 0.95
	turtle.doctrine_prefs = [&"elite", &"bastion"]
	_save(turtle, "res://data/ai/personalities/turtle.tres")

	var eco := AiPersonalityDef.new()
	eco.id = &"economist"; eco.display_name = "Economist"
	eco.role_mix = {"vanguard": 0.4, "ranged": 0.3, "heavy": 0.25, "siege": 0.05}
	eco.reserve_seconds = 6.0; eco.forge_target = 3; eco.forge_after = 10.0
	eco.doctrine_prefs = [&"elite", &"siegecraft"]
	_save(eco, "res://data/ai/personalities/economist.tres")

	var fast := AiPersonalityDef.new()
	fast.id = &"fast_age"; fast.display_name = "Fast-age Tactician"; fast.sim_only = true
	fast.age_plan = "fast"
	_save(fast, "res://data/ai/personalities/fast_age.tres")

	var strong := AiPersonalityDef.new()
	strong.id = &"strong_age"; strong.display_name = "Strong-age Tactician"; strong.sim_only = true
	strong.age_plan = "strong"
	_save(strong, "res://data/ai/personalities/strong_age.tres")

	for role in ["vanguard", "ranged", "heavy", "siege"]:
		var s := AiPersonalityDef.new()
		s.id = StringName("spam_" + role); s.display_name = "Spam: " + role.capitalize(); s.sim_only = true
		s.spam_role = role; s.age_plan = "fast"
		_save(s, "res://data/ai/personalities/spam_%s.tres" % role)
