class_name UnitArt
extends RefCounted
## Adapter from this game's units to the figure kit (addons/figure_kit): maps a UnitDef + race to a
## kit `spec` (RaceLook's style table, role fallbacks and role builds, the race's body preset and era
## palette) and draws it with FkUnits. Local space: feet at y = 0, facing +x, up is −y.
##
## pose = {walk: float (stride phase, radians), move: float (0 idle … 1 walking, blended by the caller), atk: float (0..1 attack progress, <0 idle),
##         t: float (seconds, for idle motion), flash: float (0..1 hit flash)}

## Human palettes, kept for callers that dress non-unit props (base defenders).
const AGE_CLOTH: Array = FkLooks.PALETTES[&"human"]

## Per-rig facts (visual height, projectile, muzzle, wreck) live in the kit.
const RIGS := FkUnits.RIGS

const ROLE_FALLBACK := {
	"vanguard": {"rig": "humanoid", "helmet": "cap", "weapon": "sword", "shield": "round"},
	"ranged": {"rig": "humanoid", "helmet": "cap", "weapon": "bow"},
	"heavy": {"rig": "mounted", "beast": "horse", "helmet": "greathelm", "weapon": "lance"},
	"siege": {"rig": "ram", "variant": "wood"},
}

## Role silhouettes (PRD §11: role identifiable by shape alone): Vanguards are broad and shielded
## (or carry an upright polearm); Ranged are slighter and carry a pack on the back.
const ROLE_BUILD := {"vanguard": 1.16, "ranged": 0.94}

## Camera yaw (rad) the figures are seen at; 0 is the square-on side view. The one knob for the whole view;
## the review tools set it from --yaw= (degrees).
static var view_yaw := 0.0

static var _style_cache := {}


static func style_for(def: UnitDef, race: StringName = &"human") -> Dictionary:
	var key := "%s/%s" % [race, def.id]
	if _style_cache.has(key):
		return _style_cache[key]
	var st: Dictionary = RaceLook.style(race, def.id).duplicate()
	if st.is_empty():
		st = ROLE_FALLBACK.get(def.role, ROLE_FALLBACK.vanguard).duplicate()
	if not st.has("build") and ROLE_BUILD.has(def.role):
		st["build"] = ROLE_BUILD[def.role]
	if not st.has("shot"):
		st["shot"] = FkUnits.shot(st)
	st["race"] = race
	_style_cache[key] = st
	return st


## Visual height in px (for HP bars and selection).
static func height_for(def: UnitDef, race: StringName = &"human") -> float:
	return FkUnits.height(style_for(def, race).merged({"look": RaceLook.look(race)}))


## Body half-depth in local px (centre to front edge): the view draws units this far back so opposing
## bodies don't overlap.
static func depth_for(def: UnitDef, race: StringName = &"human") -> float:
	return FkUnits.depth(style_for(def, race))


## Muzzle in unit-local space (feet origin, facing +x).
static func muzzle_for(st: Dictionary) -> Vector2:
	return FkUnits.muzzle(st)


## "blast", "siege" or "" (a body that falls over).
static func wreck_kind(st: Dictionary) -> String:
	return FkUnits.wreck(st)


static func draw_unit(ci: CanvasItem, def: UnitDef, team: Color, pose: Dictionary, seed: int = 0, race: StringName = &"human") -> void:
	FkUnits.draw(ci, style_for(def, race).merged({"look": RaceLook.look(race), "palette": RaceLook.palette(race, def.age), "team": team, "view": {"yaw": view_yaw}}), pose, seed)
