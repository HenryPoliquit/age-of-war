class_name FkUnits
extends RefCounted
## Figure-kit entry point. A unit is one `spec` Dictionary (rig + gear keys, plus look, palette and
## team) drawn with a `pose` Dictionary {walk, move, atk, t, flash}; see README.md.


## Per-rig facts the view needs: visual height, projectile, muzzle (local, pre-scale), whether a
## death leaves a wreck (no topple) and what it looks like.
const RIGS := {
	"humanoid": {"h": 66.0},
	"mounted": {"h": 82.0},
	"chariot": {"h": 82.0, "wreck": "siege"},
	"ram": {"h": 56.0, "wreck": "siege"},
	"catapult": {"h": 76.0, "wreck": "siege", "shot": "shell", "muzzle": Vector2(8, -80)},
	"ballista": {"h": 60.0, "wreck": "siege", "shot": "javelin", "muzzle": Vector2(38, -40)},
	"trebuchet": {"h": 96.0, "wreck": "siege", "shot": "shell", "muzzle": Vector2(32, -88)},
	"cannon": {"h": 56.0, "wreck": "blast", "shot": "ball", "muzzle": Vector2(46, -34), "gun": true},
	"steamtank": {"h": 72.0, "wreck": "blast", "shot": "bolt", "muzzle": Vector2(42, -46), "gun": true},
	"golem": {"h": 90.0, "wreck": "blast"},
	"treant": {"h": 104.0},
	"skycannon": {"h": 70.0, "wreck": "blast", "shot": "bolt", "muzzle": Vector2(52, -60), "gun": true},
	"obelisk": {"h": 100.0, "wreck": "siege", "shot": "bolt", "muzzle": Vector2(4, -80), "gun": true},
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


## Race body preset of the figure being drawn. Set by draw() from spec.look for the duration of one
## draw call (removed in the next refactor step — everything will read spec.look).
static var look: Dictionary = FkLooks.BODIES[&"human"]


## Draws one unit at the current FkPaint transform. spec = style keys + look, palette, team.
static func draw(ci: CanvasItem, spec: Dictionary, pose: Dictionary, seed: int = 0) -> void:
	look = spec.get("look", FkLooks.BODIES[&"human"])
	var pal: Array = spec.palette
	var team: Color = spec.team
	match spec.rig:
		"humanoid":
			FkFigure.humanoid(ci, spec, pal, team, pose, seed)
		"mounted":
			FkMounts.mounted(ci, spec, pal, team, pose, seed)
		"chariot":
			FkMounts.chariot(ci, spec, pal, team, pose, seed)
		"ram":
			FkMachines.ram(ci, spec, pal, team, pose, seed)
		"catapult":
			FkMachines.catapult(ci, spec, pal, team, pose, seed)
		"ballista":
			FkMachines.ballista(ci, spec, pal, team, pose, seed)
		"trebuchet":
			FkMachines.trebuchet(ci, spec, pal, team, pose, seed)
		"cannon":
			FkMachines.cannon(ci, spec, pal, team, pose, seed)
		"steamtank":
			FkMachines.steamtank(ci, pal, team, pose)
		"golem":
			FkMachines.golem(ci, pal, team, pose)
		"treant":
			FkMachines.treant(ci, team, pose, seed)
		"skycannon":
			FkMachines.skycannon(ci, pal, team, pose)
		"obelisk":
			FkMachines.obelisk(ci, spec, pal, team, pose, seed)
	look = FkLooks.BODIES[&"human"]


## Visual height in px (for HP bars and selection).
static func height(spec: Dictionary) -> float:
	var h: float = RIGS.get(spec.rig, {}).get("h", 50.0)
	var body: Vector2 = spec.get("look", FkLooks.BODIES[&"human"]).body
	if spec.rig == "humanoid":
		return h * body.y
	if spec.rig == "mounted":
		return h + (body.y - 1.0) * 40.0
	return h


## Muzzle in unit-local space (feet origin, facing +x).
static func muzzle(spec: Dictionary) -> Vector2:
	return spec.get("muzzle", RIGS.get(spec.rig, {}).get("muzzle", Vector2(22, -34)))


## "blast", "siege" or "" (a body that falls over).
static func wreck(spec: Dictionary) -> String:
	return RIGS.get(spec.rig, {}).get("wreck", "")


## Projectile the unit fires ("" = melee): an explicit spec.shot, else its hand weapon's, else its rig's.
static func shot(spec: Dictionary) -> String:
	if spec.has("shot"):
		return spec.shot
	var info: Dictionary = RIGS.get(spec.rig, {})
	return FkWeapons.SHOTS.get(spec.get("weapon", ""), info.get("shot", "")) if spec.rig == "humanoid" else info.get("shot", "")
