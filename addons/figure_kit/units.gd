class_name FkUnits
extends RefCounted
## Figure-kit entry point. A unit is one `spec` Dictionary (rig + gear keys, plus look, palette and
## team) drawn with a `pose` Dictionary {walk, move, atk, t, flash}; see README.md.


## Per-rig facts the view needs: body half-depth (centre to front edge, weapon excluded), visual
## height, projectile, muzzle (local, pre-scale), whether a death leaves a wreck (no topple) and what
## it looks like.
const RIGS := {
	"humanoid": {"depth": 10.0, "h": 66.0},
	"mounted": {"depth": 50.0, "h": 82.0},
	"chariot": {"depth": 50.0, "h": 82.0, "wreck": "siege"},
	"ram": {"depth": 45.0, "h": 56.0, "wreck": "siege"},
	"catapult": {"depth": 34.0, "h": 76.0, "wreck": "siege", "shot": "shell", "muzzle": Vector2(8, -80)},
	"ballista": {"depth": 46.0, "h": 60.0, "wreck": "siege", "shot": "javelin", "muzzle": Vector2(38, -40)},
	"trebuchet": {"depth": 34.0, "h": 96.0, "wreck": "siege", "shot": "shell", "muzzle": Vector2(32, -88)},
	"cannon": {"depth": 48.0, "h": 56.0, "wreck": "blast", "shot": "ball", "muzzle": Vector2(46, -34), "gun": true},
	"steamtank": {"depth": 43.0, "h": 72.0, "wreck": "blast", "shot": "bolt", "muzzle": Vector2(42, -46), "gun": true},
	"golem": {"depth": 33.0, "h": 90.0, "wreck": "blast"},
	"treant": {"depth": 30.0, "h": 104.0},
	"skycannon": {"depth": 50.0, "h": 70.0, "wreck": "blast", "shot": "bolt", "muzzle": Vector2(52, -60), "gun": true},
	"obelisk": {"depth": 36.0, "h": 100.0, "wreck": "siege", "shot": "bolt", "muzzle": Vector2(4, -80), "gun": true},
}


## Attack animation shape: anticipation (0→−1), contact at 0.35–0.55 (−1→+1), recovery (+1→0).
static func swing(atk: float) -> float:
	if atk < 0.0:
		return 0.0
	if atk < 0.35:
		return -ease(atk / 0.35, 0.6)
	if atk < 0.55:
		return lerpf(-1.0, 1.0, ease((atk - 0.35) / 0.2, 0.4))
	return lerpf(1.0, 0.0, ease((atk - 0.55) / 0.45, 1.6))


## Draws one unit at the current FkPaint transform. spec = style keys + look, palette, team.
static func draw(ci: CanvasItem, spec: Dictionary, pose: Dictionary, seed: int = 0) -> void:
	match spec.rig:
		"humanoid":
			FkFigure.humanoid(ci, spec, pose, seed)
		"mounted":
			FkMounts.mounted(ci, spec, pose, seed)
		"chariot":
			FkMounts.chariot(ci, spec, pose, seed)
		"ram":
			FkMachines.ram(ci, spec, pose, seed)
		"catapult":
			FkMachines.catapult(ci, spec, pose, seed)
		"ballista":
			FkMachines.ballista(ci, spec, pose, seed)
		"trebuchet":
			FkMachines.trebuchet(ci, spec, pose, seed)
		"cannon":
			FkMachines.cannon(ci, spec, pose, seed)
		"steamtank":
			FkMachines.steamtank(ci, spec, pose, seed)
		"golem":
			FkMachines.golem(ci, spec, pose, seed)
		"treant":
			FkMachines.treant(ci, spec, pose, seed)
		"skycannon":
			FkMachines.skycannon(ci, spec, pose, seed)
		"obelisk":
			FkMachines.obelisk(ci, spec, pose, seed)


## Visual height in px (for HP bars and selection).
static func height(spec: Dictionary) -> float:
	var h: float = RIGS.get(spec.rig, {}).get("h", 50.0)
	var body: Vector2 = spec.get("look", FkLooks.BODIES[&"human"]).body
	if spec.rig == "humanoid":
		return h * body.y
	if spec.rig == "mounted":
		return h + (body.y - 1.0) * 40.0
	return h


## Stride phase (rad) per px of ground a foot soldier or a two-legged giant covers at `scale` (its drawn scale), so its feet stay
## put on the ground as it walks; the caller multiplies the distance walked by it to get pose.walk. Other rigs return `fallback`.
static func stride_rate(spec: Dictionary, scale: float, fallback := 0.1) -> float:
	if FkMachines.GIANT_GAITS.has(spec.rig):
		return PI / (2.0 * float(FkMachines.GIANT_GAITS[spec.rig].stride) * scale)
	if spec.rig != "humanoid":
		return fallback
	var body: Vector2 = spec.get("look", FkLooks.BODIES[&"human"]).body
	return FkSkeleton.stride_rate(spec.get("weapon", "none"), spec.get("shield", ""), spec.get("build", 1.0), body, scale)


## Muzzle in unit-local space (feet origin, facing +x).
static func muzzle(spec: Dictionary) -> Vector2:
	var hand: Vector2 = FkWeapons.MUZZLE.get(spec.get("weapon", ""), Vector2(22, -34)) if spec.rig == "humanoid" else Vector2(22, -34)
	return spec.get("muzzle", RIGS.get(spec.rig, {}).get("muzzle", hand))


## "blast", "siege" or "" (a body that falls over).
static func wreck(spec: Dictionary) -> String:
	return RIGS.get(spec.rig, {}).get("wreck", "")


## Projectile the unit fires ("" = melee): an explicit spec.shot, else its hand weapon's, else its rig's.
static func shot(spec: Dictionary) -> String:
	if spec.has("shot"):
		return spec.shot
	var info: Dictionary = RIGS.get(spec.rig, {})
	return FkWeapons.SHOTS.get(spec.get("weapon", ""), info.get("shot", "")) if spec.rig == "humanoid" else info.get("shot", "")


## Half-depth of the body in px, centre to front edge (weapon excluded). Draw a unit this far back
## toward its own side and two opposing bodies whose centres touch stand apart instead of overlapping.
static func depth(spec: Dictionary) -> float:
	var d: float = RIGS.get(spec.rig, {}).get("depth", 10.0)
	# A carried shield stands proud of a foot soldier's chest.
	return d + (8.0 if spec.rig == "humanoid" and spec.get("shield", "") != "" else 0.0)
