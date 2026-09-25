class_name GameData
extends RefCounted
## Loads every data resource under res://data. Nothing gameplay-related is hardcoded in scripts.

const AGE_COUNT := 6

var rules: RulesDef
var ages: Array[AgeDef] = []
var doctrines: Dictionary = {}      # StringName -> DoctrineDef
var personalities: Dictionary = {}  # StringName -> AiPersonalityDef
var difficulties: Dictionary = {}   # StringName -> AiDifficultyDef

static var _cached: GameData


static func get_default() -> GameData:
	if _cached == null:
		_cached = GameData.load_from("res://data")
	return _cached


static func load_from(root: String) -> GameData:
	var gd := GameData.new()
	gd.rules = load(root + "/rules.tres")
	for i in range(1, AGE_COUNT + 1):
		gd.ages.append(load("%s/ages/age_%d.tres" % [root, i]))
	for r in _load_dir(root + "/doctrines"):
		gd.doctrines[r.id] = r
	for r in _load_dir(root + "/ai/personalities"):
		gd.personalities[r.id] = r
	for r in _load_dir(root + "/ai/difficulties"):
		gd.difficulties[r.id] = r
	return gd


static func _load_dir(path: String) -> Array:
	var out := []
	var files := Array(DirAccess.get_files_at(path))
	files.sort()
	for f in files:
		# Exported builds list remapped files; strip the suffix so load() resolves them.
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			out.append(load(path + "/" + f))
	return out


func age(index: int) -> AgeDef:
	return ages[index - 1]


func unit_for_role(age_index: int, role: String) -> UnitDef:
	for u in age(age_index).units:
		if u.role == role:
			return u
	return null


func turret_for_kind(age_index: int, kind: String) -> TurretDef:
	for t in age(age_index).turrets:
		if t.kind == kind:
			return t
	return null
