class_name SkillFx
extends RefCounted
## Everything you see of a skill (GDD §7, §13.4): the warning on the ground, the aim reticle, the herd,
## rocks, volleys, shells, stars and lightning, what they leave behind, and the numbers over the units they hit.
##
## FxLayer owns the particle pool and the draw passes and hands this class three hooks (`draw_under`,
## `draw_over`, `draw_glow`) plus `step`. Effects are choreographed when the skill is *cast*: each projectile
## is launched early enough to land at the instant its pulse resolves, so the picture and the damage agree.
## Which race's version plays comes from SkillLook; footprint, timing and damage are the sim's, never ours.

const GROUND_Y := FxLayer.GROUND_Y
const INK := Color(0.06, 0.05, 0.05, 0.85)
## How long a projectile spends in the air, by launch style (a launch is delayed to land on time).
const FLIGHT := {"sky": 0.42, "diag": 0.7, "home": 0.65}
const MAX_POPUPS := 40
## Most strikes a Starfall pulse draws in full (a dense pack gets a glint for the rest).
const MAX_STRIKES := 12
## The ground is seen at a slant: a circle on it is drawn as an ellipse this flat.
const CIRCLE_SQUASH := 0.30
## A field of land reaches from just behind the units' feet to well in front of them.
const FIELD_BACK := -12.0
const FIELD_FRONT := 62.0

var fxl: FxLayer
var items: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var _strike_budget := 0
var rng := RandomNumberGenerator.new()


func _init(p_fxl: FxLayer = null) -> void:
	fxl = p_fxl
	rng.seed = 7


var view: MatchView:
	get:
		return fxl.view


func _n(n: int) -> int:
	return maxi(2, roundi(n * (0.6 + 0.4 * fxl.intensity)))


# ---------------------------------------------------------------------------
# Casting: choreograph the whole skill

## Called when a skill is fired. `ev` is the sim's "ability" event (side, lo, hi, x, aimed).
func cast(ev: Dictionary, def: AbilityDef, race: StringName) -> void:
	var side: int = ev.side
	var c := {"def": def, "look": SkillLook.for_skill(race, String(def.id)), "side": side, "dir": 1.0 if side == 0 else -1.0,
		"lo": float(ev.lo), "hi": float(ev.hi), "home": view.sim.to_world(side, 0.0), "race": race, "glow": Color.WHITE}
	c.glow = c.look.get("glow", Color.WHITE)
	# A beacon at the caster's gate marks the call.
	fxl.flash(Vector2(c.home + c.dir * 70.0, GROUND_Y - 150), 80, Color(c.glow, 0.5), 0.35)
	match String(def.id):
		"stampede":
			_cast_stampede(c)
		"rockfall":
			_cast_rockfall(c)
		"volley":
			_cast_volley(c)
		"bombardment":
			_cast_bombardment(c)
		"cannonade":
			_cast_cannonade(c)
		"starfall":
			_cast_starfall(c)


## Seconds from now until pulse k lands.
func _t(c: Dictionary, k: int) -> float:
	var def: AbilityDef = c.def
	return def.telegraph + k * def.pulse_interval


## The slice of the lane pulse k of a sweep crosses (mirrors MatchSim._ability_pulse).
func _slice(c: Dictionary, k: int) -> Vector2:
	var def: AbilityDef = c.def
	if def.shape != "sweep" or def.pulses <= 1:
		return Vector2(c.lo, c.hi)
	var w: float = (c.hi - c.lo) / def.pulses
	var i: int = k if c.side == 0 else def.pulses - 1 - k
	return Vector2(c.lo + w * i, c.lo + w * (i + 1))


func _ground(x: float, depth := 12.0) -> Vector2:
	return Vector2(x, GROUND_Y - rng.randf_range(0.0, depth))


## A landing spot inside a circle's footprint (the i-th of n, spread round it).
func _in_circle(c: Dictionary, i: int, n: int) -> Vector2:
	var mid: float = (c.lo + c.hi) * 0.5
	var half: float = (c.hi - c.lo) * 0.5
	var a := TAU * (i + rng.randf_range(0.0, 0.8)) / n + rng.randf() * 0.3
	var r := sqrt(rng.randf_range(0.15, 1.0))
	return Vector2(mid + cos(a) * r * (half - 24.0), GROUND_Y + 10.0 + sin(a) * r * (half * CIRCLE_SQUASH - 8.0))


## A landing spot inside a field of land (the i-th of n across its width, anywhere in its depth).
func _in_field(c: Dictionary, i: int, n: int) -> Vector2:
	return Vector2(lerpf(c.lo + 10.0, c.hi - 10.0, (i + rng.randf_range(0.1, 0.9)) / n), GROUND_Y + rng.randf_range(FIELD_BACK + 6.0, FIELD_FRONT - 8.0))


## Launches one projectile so that it lands at pulse `k` (a little early, never late).
func _launch(c: Dictionary, k: int, to: Vector2, opts := {}) -> void:
	var look: Dictionary = c.look
	var style: String = look.get("from", "sky")
	var land_at := fxl.now() + _t(c, k) - rng.randf_range(0.0, 0.1)
	var flight: float = FLIGHT.get(style, 0.5)
	fxl.later(maxf(0.0, land_at - fxl.now() - flight), func():
		var p := _make_proj(c, to, maxf(0.12, land_at - fxl.now()), opts)
		items.append(p)
		if style == "home" and p.shot in ["ball", "runeshell"]:
			fxl.muzzle(p.from, 0.0 if c.dir > 0 else PI, true, c.glow, "cannon")
		elif style == "home":
			fxl.flash(p.from, 26.0, Color(c.glow, 0.7), 0.1))


func _make_proj(c: Dictionary, to: Vector2, dur: float, opts: Dictionary) -> Dictionary:
	var look: Dictionary = c.look
	var dir: float = c.dir
	var style: String = opts.get("from", look.get("from", "sky"))
	var from: Vector2
	var arc := 0.0
	var drop := false
	match style:
		"diag":
			from = to + Vector2(-dir * rng.randf_range(300.0, 460.0), -rng.randf_range(560.0, 700.0))
			arc = 70.0
		"home":
			from = Vector2(c.home + dir * rng.randf_range(20.0, 110.0), GROUND_Y - rng.randf_range(150.0, 260.0))
			arc = 170.0 + absf(to.x - from.x) * 0.16
		_:
			from = to + Vector2(rng.randf_range(-40.0, 40.0), -rng.randf_range(680.0, 800.0))
			drop = true
	var shot: String = opts.get("shot", look.get("shot", "rock"))
	return {"k": "proj", "shot": shot, "from": from, "to": to, "born": fxl.now(), "dur": dur, "arc": arc, "drop": drop,
		"spin": rng.randf_range(-7.0, 7.0), "r": float(opts.get("r", look.get("r", 20.0))) * rng.randf_range(0.85, 1.15),
		"seed": rng.randf() * 100.0, "look": look, "dir": dir, "shadow": opts.get("shadow", true), "last": opts.get("last", false)}


# --- Stampede ---------------------------------------------------------------

func _cast_stampede(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	var slice: float = (c.hi - c.lo) / def.pulses
	var v := slice / def.pulse_interval
	var dir: float = c.dir
	var look: Dictionary = c.look
	var lead := 0.25
	var beasts := []
	for i in _n(12):
		beasts.append({"back": (i % 4) * 70.0 + rng.randf_range(0.0, 34.0) + (i / 4) * 8.0, "y": GROUND_Y + ((i * 7) % 29) - 14.0,
			"ph": rng.randf() * TAU, "s": rng.randf_range(1.25, 1.55)})
	# Far beasts first, so the near ones stand in front of them.
	beasts.sort_custom(func(a, b): return a.y < b.y)
	fxl.later(maxf(0.0, def.telegraph - lead), func():
		items.append({"k": "herd", "born": fxl.now(), "dir": dir, "x0": c.home - dir * v * lead, "v": v, "look": look, "beasts": beasts,
			"life": (c.hi - c.lo) / v + lead + 0.5, "side": c.side})
		fxl.sound("stampede", Vector2(c.home, GROUND_Y)))
	# Where the front crosses a slice: a shockwave and a spray of what the ground is made of.
	for k in def.pulses:
		var s := _slice(c, k)
		fxl.later(_t(c, k), func():
			var mid := (s.x + s.y) * 0.5
			_dust(Vector2(mid, GROUND_Y), 1.2, look.get("dust", Color(0.7, 0.6, 0.45, 0.5)))
			fxl.burst("spark", Vector2(mid, GROUND_Y - 20), 4, Color(c.glow, 0.9), Vector2(120, 300), Vector2(0.15, 0.3), Vector2(2, 3.5), 500.0, PI, -PI * 0.5, true)
			view.add_shake(4.0))


# --- Rockfall ---------------------------------------------------------------

func _cast_rockfall(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	for k in def.pulses:
		var n := _n(3)
		for i in n:
			_launch(c, k, _in_circle(c, i, n), {"last": k == def.pulses - 1})
		fxl.later(_t(c, k), func():
			view.add_shake(6.0))


# --- Volley -----------------------------------------------------------------

func _cast_volley(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	var look: Dictionary = c.look
	var count := {"pilum": 16, "arrow": 34, "axe": 14}.get(look.shot, 16) as int
	for k in def.pulses:
		var n := _n(count)
		for i in n:
			_launch(c, k, _in_field(c, i, n), {"shadow": false})
		fxl.later(_t(c, k), func():
			# The field the volley falls on, as a curtain of shafts.
			items.append({"k": "curtain", "born": fxl.now(), "life": 0.5, "lo": c.lo, "hi": c.hi, "col": c.glow})
			fxl.sound("bow", Vector2((c.lo + c.hi) * 0.5, GROUND_Y - 200), -2.0)
			view.add_shake(2.0))


# --- Bombardment ------------------------------------------------------------

func _cast_bombardment(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	for k in def.pulses:
		var s := _slice(c, k)
		var n := _n(4)
		for i in n:
			_launch(c, k, _ground(lerpf(s.x + 14.0, s.y - 14.0, (i + rng.randf_range(0.1, 0.9)) / n), 6.0))
		fxl.later(_t(c, k), func():
			view.add_shake(3.0)
			fxl.ring(Vector2((s.x + s.y) * 0.5, GROUND_Y + 4), (s.y - s.x) * 0.7, Color(c.glow, 0.4), 0.3, 5.0))


# --- Cannonade --------------------------------------------------------------

func _cast_cannonade(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	# Signal flares planted in the field: coloured smoke marks where the guns are about to fall.
	var last_pulse := _t(c, def.pulses - 1)
	for f in 3:
		items.append({"k": "flare", "born": fxl.now(), "life": last_pulse + 0.4, "x": lerpf(c.lo + 50.0, c.hi - 50.0, (f + 0.5) / 3.0),
			"y": GROUND_Y + 24.0, "col": c.glow})
	for k in def.pulses:
		var n := _n(4)
		for i in n:
			_launch(c, k, _in_field(c, i, n), {"last": k == def.pulses - 1})
		fxl.later(_t(c, k), func():
			view.add_shake(5.0))


# --- Starfall ---------------------------------------------------------------

## Starfall hits units only: nothing is thrown at the ground. The circle charges while it warns, and then a
## strike lands on every enemy inside it at each pulse (`_strike_unit`, driven by the sim's hit records).
func _cast_starfall(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	items.append({"k": "charge", "born": fxl.now(), "life": def.telegraph, "x": (c.lo + c.hi) * 0.5, "w": c.hi - c.lo, "look": c.look, "side": c.side})


# ---------------------------------------------------------------------------
# Impacts

func _dust(pos: Vector2, s: float, col: Color) -> void:
	for d in [0.0, PI]:
		fxl.burst("smoke", pos, 5, col, Vector2(70, 190) * s, Vector2(0.5, 1.0), Vector2(11, 24) * s, -10.0, 0.3, d)
	fxl.burst("smoke", pos + Vector2(0, -6), 4, Color(col, col.a * 0.8), Vector2(20, 80), Vector2(0.7, 1.3), Vector2(14, 26) * s, -22.0, 0.7, -PI * 0.5)


func _boom(pos: Vector2, s: float, fire: Color, shake: float) -> void:
	fxl.flash(pos, 46 * s, Color(fire.lightened(0.35), 0.5), 0.15)
	fxl.flash(pos, 18 * s, Color(1, 0.96, 0.85, 0.8), 0.08)
	fxl.light(pos, fire, 1.3 * s, 250.0 * s, 0.35)
	fxl.burst("fire", pos, roundi(9 * s), fire, Vector2(40, 170), Vector2(0.25, 0.5), Vector2(9, 18) * s, -60.0, PI, -PI * 0.5, true)
	fxl.burst("chunk", pos, roundi(7 * s), Color("3b3026"), Vector2(150, 360), Vector2(0.5, 1.0), Vector2(3, 7), 900.0, 1.1)
	fxl.burst("smoke", pos + Vector2(0, -8), roundi(6 * s), Color(0.25, 0.22, 0.2, 0.6), Vector2(20, 60), Vector2(0.8, 1.5), Vector2(10, 20) * s, -30.0)
	fxl.ring(pos, 100 * s, Color(fire.lightened(0.5), 0.6), 0.35, 5.0)
	fxl.scorch(pos.x, 42 * s)
	view.add_shake(shake * s)
	fxl.sound("blast", pos, -4.0)


func _column(x: float, w: float, col: Color, life: float) -> void:
	items.append({"k": "column", "born": fxl.now(), "life": life, "x": x, "w": w, "col": col})


func _crack(pos: Vector2, s: float, col: Color) -> void:
	var lines := []
	for i in 6:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var pts := PackedVector2Array([Vector2.ZERO])
		var x := 0.0
		var y := 0.0
		for j in 4:
			x += dir * rng.randf_range(12.0, 30.0) * s
			y += rng.randf_range(-3.0, 5.0)
			pts.append(Vector2(x, y))
		lines.append(pts)
	items.append({"k": "crack", "born": fxl.now(), "life": 2.2, "pos": Vector2(pos.x, GROUND_Y + 8), "lines": lines, "col": col})


func _land(p: Dictionary) -> void:
	var to: Vector2 = p.to
	var look: Dictionary = p.look
	var glow: Color = look.get("glow", Color.WHITE)
	var s: float = clampf(p.r / 24.0, 0.7, 1.6)
	var ang: float = (to - (p.from as Vector2)).angle()
	match p.shot:
		"rock", "boulder":
			_dust(to, s, Color(0.66, 0.6, 0.5, 0.6))
			fxl.burst("chunk", to, 9, look.body, Vector2(160, 380), Vector2(0.5, 1.0), Vector2(4, 9), 900.0, 1.0)
			fxl.burst("spark", to, 5, glow.lightened(0.3), Vector2(100, 260), Vector2(0.15, 0.3), Vector2(2, 3.5), 400.0, 1.1, -PI * 0.5, true)
			fxl.flash(to, 36 * s, Color(glow, 0.4), 0.11)
			fxl.ring(to, 90 * s, Color(1, 0.92, 0.75, 0.5), 0.3, 5.0)
			fxl.scorch(to.x, 46 * s)
			view.add_shake(4.0 * s)
			fxl.sound("siege", to, -4.0)
		"crystal":
			fxl.burst("chunk", to, 8, look.lit, Vector2(150, 330), Vector2(0.4, 0.8), Vector2(3, 7), 900.0, 1.0)
			fxl.burst("spark", to, 10, glow, Vector2(100, 300), Vector2(0.25, 0.55), Vector2(2, 4), 300.0, PI, -PI * 0.5, true)
			fxl.burst("leaf", to, 6, glow.darkened(0.15), Vector2(60, 200), Vector2(0.7, 1.3), Vector2(6, 10), 40.0, PI, -PI * 0.5)
			fxl.flash(to, 40 * s, Color(glow, 0.42), 0.12)
			fxl.ring(to, 80 * s, Color(glow.lightened(0.4), 0.7), 0.4, 4.0)
			fxl.light(to, glow, 1.0, 200.0, 0.3)
			view.add_shake(2.5)
			fxl.sound("pierce", to, -2.0)
		"runestone":
			_dust(to, s, Color(0.55, 0.5, 0.45, 0.6))
			fxl.burst("chunk", to, 9, look.body, Vector2(160, 380), Vector2(0.5, 1.0), Vector2(4, 9), 900.0, 1.0)
			fxl.burst("fire", to, 8, glow, Vector2(40, 170), Vector2(0.25, 0.5), Vector2(8, 15), -60.0, PI, -PI * 0.5, true)
			fxl.flash(to, 44 * s, Color(glow, 0.45), 0.13)
			fxl.ring(to, 100 * s, Color(glow.lightened(0.4), 0.7), 0.4, 6.0)
			fxl.light(to, glow, 1.2, 230.0, 0.3)
			_crack(to, s, glow)
			fxl.scorch(to.x, 46 * s)
			view.add_shake(4.5 * s)
			fxl.sound("siege", to, -3.0)
		"pilum", "arrow", "axe":
			fxl.burst("smoke", to, 3, Color(0.86, 0.8, 0.68, 0.5), Vector2(10, 50), Vector2(0.3, 0.6), Vector2(5, 10))
			fxl.burst("spark", to, 4, glow, Vector2(80, 200), Vector2(0.12, 0.25), Vector2(1.5, 3), 300.0, 1.0, -PI * 0.5, true)
			fxl.flash(to, 11.0, Color(glow, 0.42), 0.07)
			if look.get("land", "") == "leaves":
				fxl.burst("leaf", to, 2, glow.darkened(0.1), Vector2(40, 120), Vector2(0.6, 1.0), Vector2(5, 8), 60.0, 0.8, -PI * 0.5)
			items.append({"k": "stuck", "shot": p.shot, "pos": to + Vector2(0, 4), "ang": clampf(ang, 0.4, 2.8) if p.shot != "axe" else rng.randf_range(-0.5, 0.5),
				"born": fxl.now(), "life": 2.0, "look": look, "r": p.r})
		"fireball":
			_boom(to, 0.85, glow, 2.5)
			fxl.burst("fire", to, 6, glow.lightened(0.3), Vector2(80, 220), Vector2(0.3, 0.6), Vector2(6, 12), 100.0, 1.2, -PI * 0.5, true)
		"ball":
			_boom(to, 1.15, glow, 3.5)
		"runeshell":
			_boom(to, 1.25, glow, 4.0)
			_crack(to, 1.0, glow)
			fxl.burst("spark", to, 10, look.lit, Vector2(120, 340), Vector2(0.25, 0.5), Vector2(2, 4), 500.0, PI, -PI * 0.5, true)
		"thorn":
			fxl.burst("leaf", to, 8, glow, Vector2(60, 240), Vector2(0.6, 1.2), Vector2(6, 11), 200.0, PI, -PI * 0.5)
			fxl.burst("chunk", to, 5, look.body, Vector2(120, 260), Vector2(0.4, 0.8), Vector2(3, 6), 900.0, 1.0)
			fxl.flash(to, 34, Color(glow, 0.55), 0.12)
			fxl.ring(to, 70, Color(glow.lightened(0.3), 0.6), 0.35, 4.0)
			fxl.scorch(to.x, 24)
			view.add_shake(2.0)
			items.append({"k": "stuck", "shot": "thorn", "pos": to + Vector2(0, 6), "ang": rng.randf_range(1.2, 1.9), "born": fxl.now(), "life": 2.4,
				"look": look, "r": p.r})
			fxl.sound("pierce", to, -3.0)
		"moon":
			_column(to.x, 46.0, glow, 0.5)
			fxl.flash(to, 60, Color(glow, 0.7), 0.18)
			fxl.ring(to, 110, Color(glow.lightened(0.5), 0.8), 0.45, 5.0)
			fxl.burst("spark", to, 12, Color.WHITE, Vector2(80, 300), Vector2(0.3, 0.7), Vector2(2, 4), 200.0, PI, -PI * 0.5, true)
			fxl.burst("leaf", to, 5, glow.lightened(0.5), Vector2(40, 160), Vector2(0.8, 1.5), Vector2(5, 9), -20.0, PI, -PI * 0.5)
			fxl.light(to, glow, 1.6, 300.0, 0.4)
			fxl.scorch(to.x, 34)
			view.add_shake(4.0)
			fxl.sound("zap", to, -2.0)
		"star":
			# A star that found a unit: a glint on it and a few sparks, no crater.
			fxl.flash(to, 34.0, Color(glow, 0.55), 0.12)
			fxl.particle({"kind": "flare", "pos": to, "vel": Vector2.ZERO, "life": 0.3, "size": 38.0, "col": look.body, "g": 0.0, "add": true, "rot": 0.0, "spin": 0.5})
			_sparks(to, glow)


func _sparks(at: Vector2, glow: Color) -> void:
	fxl.burst("spark", at, 6, glow.lightened(0.4), Vector2(80, 260), Vector2(0.2, 0.45), Vector2(2, 3.5), 350.0, PI, -PI * 0.5, true)


## Starfall, Arcane Lance and Thunder Rune hit units only. A strike lands on an enemy unit exactly where it
## stands and leaves nothing on the ground: no crater, no ring, no scorch, no shake.
func _strike_unit(at: Vector2, caster_race: StringName, dir: float) -> void:
	var look := SkillLook.for_skill(caster_race, "starfall")
	var glow: Color = look.get("glow", Color.WHITE)
	if _strike_budget <= 0:
		fxl.flash(at, 22.0, Color(glow, 0.45), 0.1)
		return
	_strike_budget -= 1
	match look.shot:
		"lance":
			# A thin spear of light, through the unit.
			_column(at.x, 22.0, glow, 0.24)
			fxl.flash(at, 38.0, Color(glow, 0.6), 0.14)
			_sparks(at, glow)
		"bolt":
			var top := Vector2(at.x + rng.randf_range(-40.0, 40.0), -200.0)
			items.append({"k": "bolt", "born": fxl.now(), "life": 0.24, "main": _bolt_points(top, at, 26.0), "forks": [], "col": glow})
			fxl.flash(at, 38.0, Color(glow, 0.6), 0.14)
			_sparks(at, glow)
		_:
			# A star that dives onto it from behind the caster's line.
			items.append({"k": "proj", "shot": "star", "from": at + Vector2(-dir * rng.randf_range(40.0, 90.0), -380.0), "to": at, "born": fxl.now(), "dur": 0.14,
				"arc": 0.0, "drop": false, "spin": rng.randf_range(-7.0, 7.0), "r": 13.0, "seed": rng.randf() * 100.0, "look": look, "dir": dir,
				"shadow": false, "last": false})


func _bolt_points(top: Vector2, bottom: Vector2, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array([top])
	var n := 9
	for i in range(1, n):
		var f := float(i) / n
		var p := top.lerp(bottom, f)
		p.x += rng.randf_range(-jag, jag) * (1.0 - f * 0.6)
		pts.append(p)
	pts.append(bottom)
	return pts


# ---------------------------------------------------------------------------
# Damage numbers

## A skill hit a unit (sim record "skill_hit"): a marker in the mode's colour and the number taken.
func hit(f: Dictionary) -> void:
	var def: UnitDef = f.get("def")
	var side: int = f.side
	var x := view.world.drawn_x(def, side, f.x) if def != null else float(f.x)
	var h := UnitArt.height_for(def, view.race_of(side)) * WorldLayer.draw_scale(def) if def != null else 90.0
	var mode: String = f.mode
	var col := {"flat": Color("ffb45e"), "true": Color("8fe4ff"), "percent": Color("9df08a")}.get(mode, Color.WHITE) as Color
	var text := "−%d%%" % roundi(f.pct * 100.0) if mode == "percent" else "−%d" % roundi(f.dealt)
	var killed: bool = f.killed
	if GameSettings.get_value("skill_numbers"):
		if popups.size() >= MAX_POPUPS:
			popups.pop_front()
		popups.append({"x": x + rng.randf_range(-10.0, 10.0), "y": GROUND_Y - h - 8.0 - (int(f.unit_id) % 3) * 17.0, "text": text, "col": col,
			"mode": mode, "born": fxl.now(), "life": 1.25 if killed else 1.0, "size": 32 if killed else 25})
	# A mark on the unit itself, coloured like the number.
	var pos := Vector2(x, GROUND_Y - h * 0.55)
	fxl.flash(pos, 26.0, Color(col, 0.55), 0.14)
	if f.ability == "starfall":
		_strike_unit(Vector2(x, GROUND_Y + WorldLayer.jitter(int(f.unit_id)) - h * 0.55), view.race_of(1 - side), 1.0 if side == 1 else -1.0)
	else:
		fxl.ring(pos, 36.0, Color(col, 0.7), 0.25, 3.0)


## A skill pulse resolved (sim record "ability_pulse"): the strikes of this pulse start fresh.
func pulse(f: Dictionary) -> void:
	_strike_budget = MAX_STRIKES
	if f.ability == "starfall":
		fxl.sound("zap", Vector2((f.lo + f.hi) * 0.5, GROUND_Y - 80.0), -4.0)


# ---------------------------------------------------------------------------
# Per frame

func step(_dt: float) -> void:
	var t := fxl.now()
	var keep: Array[Dictionary] = []
	for it in items:
		match it.k:
			"proj":
				var u: float = (t - it.born) / it.dur
				if u >= 1.0:
					_land(it)
					continue
				_trail(it, u)
			"herd":
				if t - it.born > it.life:
					continue
				_herd_dust(it, t)
			"charge":
				if t - it.born > it.life:
					continue
				_charge_motes(it)
			"flare":
				if t - it.born > it.life:
					continue
				_flare_smoke(it)
			_:
				if t - it.born > it.life:
					continue
		keep.append(it)
	items = keep
	popups = popups.filter(func(p): return t - p.born < p.life)


func _pos(p: Dictionary, u: float) -> Vector2:
	var e: float = u * u if p.drop else u
	return (p.from as Vector2).lerp(p.to, e) + Vector2(0, -4.0 * p.arc * u * (1.0 - u))


func _trail(p: Dictionary, u: float) -> void:
	var look: Dictionary = p.look
	var pos := _pos(p, u)
	var glow: Color = look.get("glow", Color.WHITE)
	if rng.randf() > 0.55 * fxl.intensity + 0.2:
		return
	match look.get("trail", "none"):
		"ember":
			fxl.particle({"kind": "fire", "pos": pos, "vel": Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 40)), "life": 0.4, "size": p.r * 0.5,
				"col": glow, "g": -40.0, "add": true, "rot": 0.0, "spin": 0.0})
		"smoke":
			fxl.particle({"kind": "smoke", "pos": pos, "vel": Vector2.ZERO, "life": 0.55, "size": p.r * 0.35, "col": Color(0.78, 0.78, 0.78, 0.4),
				"g": -20.0, "add": false, "rot": 0.0, "spin": 0.0})
		"leaf", "petal":
			var c := glow if look.trail == "leaf" else Color("ffb6cf")
			fxl.particle({"kind": "leaf", "pos": pos, "vel": Vector2(rng.randf_range(-40, 40), rng.randf_range(-10, 50)), "life": 0.8, "size": 6.0,
				"col": c, "g": 30.0, "add": false, "rot": rng.randf() * TAU, "spin": rng.randf_range(-6, 6)})
		"spark":
			fxl.particle({"kind": "spark", "pos": pos, "vel": Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 60)), "life": 0.3, "size": 2.4,
				"col": glow.lightened(0.3), "g": 200.0, "add": true, "rot": 0.0, "spin": 0.0})


func _herd_dust(h: Dictionary, t: float) -> void:
	var look: Dictionary = h.look
	var front: float = h.x0 + h.dir * h.v * (t - h.born)
	view.add_shake(0.5)  # the ground shakes under the herd
	if rng.randf() > 0.7 * fxl.intensity + 0.15:
		return
	var b: Dictionary = h.beasts[rng.randi_range(0, h.beasts.size() - 1)]
	var pos := Vector2(front - h.dir * b.back, b.y)
	match look.get("trail", "smoke"):
		"smoke":
			fxl.particle({"kind": "smoke", "pos": pos, "vel": Vector2(-h.dir * 60, -20), "life": 0.7, "size": 14.0, "col": look.dust, "g": -10.0, "add": false, "rot": 0.0, "spin": 0.0})
		"petal":
			fxl.particle({"kind": "leaf", "pos": pos + Vector2(0, -30), "vel": Vector2(-h.dir * 90, rng.randf_range(-70, -10)), "life": 0.9, "size": 7.0,
				"col": [Color("ffb6cf"), Color("bfe89a"), Color("fff0b0")][rng.randi_range(0, 2)], "g": 60.0, "add": false, "rot": rng.randf() * TAU, "spin": rng.randf_range(-7, 7)})
		"spark":
			fxl.particle({"kind": "spark", "pos": pos, "vel": Vector2(-h.dir * 120, rng.randf_range(-120, -30)), "life": 0.35, "size": 2.6, "col": Color(1.0, 0.7, 0.3), "g": 500.0,
				"add": true, "rot": 0.0, "spin": 0.0})
			fxl.particle({"kind": "smoke", "pos": pos, "vel": Vector2(-h.dir * 60, -10), "life": 0.6, "size": 12.0, "col": look.dust, "g": -10.0, "add": false, "rot": 0.0, "spin": 0.0})


## Coloured smoke rising from a signal flare.
func _flare_smoke(f: Dictionary) -> void:
	if rng.randf() > 0.95 * fxl.intensity + 0.05:
		return
	var col: Color = f.col
	fxl.particle({"kind": "smoke", "pos": Vector2(f.x + rng.randf_range(-4.0, 4.0), f.y - 34.0), "vel": Vector2(rng.randf_range(-10, 10), rng.randf_range(-170, -110)),
		"life": 2.2, "size": 13.0, "col": Color(col.r, col.g, col.b, 0.62), "g": -4.0, "add": false, "rot": 0.0, "spin": 0.0})


## Motes drawn in toward a charging Starfall.
func _charge_motes(ch: Dictionary) -> void:
	if rng.randf() > 0.85 * fxl.intensity:
		return
	var look: Dictionary = ch.look
	var glow: Color = look.get("glow", Color.WHITE)
	var target := Vector2(ch.x, GROUND_Y - 40.0)
	var from := target + Vector2(rng.randf_range(-1.0, 1.0) * ch.w * 0.9, -rng.randf_range(20.0, 260.0))
	fxl.particle({"kind": "spark", "pos": from, "vel": (target - from) * 1.8, "life": 0.55, "size": 2.6, "col": glow.lightened(0.3), "g": 0.0, "add": true, "rot": 0.0, "spin": 0.0})


# ---------------------------------------------------------------------------
# Drawing: under the particles (shadows, things stuck in the ground, the herd)

func draw_under(ci: CanvasItem, t: float) -> void:
	for it in items:
		match it.k:
			"proj":
				if it.shadow:
					var u: float = clampf((t - it.born) / it.dur, 0.0, 1.0)
					var rx: float = lerpf(5.0, it.r * 1.2 + 8.0, u * u)
					FkPaint.ellipse(ci, Vector2(it.to.x, it.to.y + 8), Vector2(rx, rx * 0.24), Color(0, 0, 0, lerpf(0.08, 0.5, u)))
			"stuck":
				_draw_stuck(ci, it, t)
			"crack":
				var a: float = 1.0 - (t - it.born) / it.life
				for line in it.lines:
					var pts := PackedVector2Array()
					for q in line:
						pts.append(it.pos + q)
					ci.draw_polyline(pts, Color(0.05, 0.04, 0.03, 0.75 * a), 3.0)
			"herd":
				_draw_herd(ci, it, t)
			"flare":
				ci.draw_line(Vector2(it.x, it.y), Vector2(it.x, it.y - 30.0), INK, 6.0)
				ci.draw_line(Vector2(it.x, it.y), Vector2(it.x, it.y - 30.0), Color("8a7a66"), 3.0)


## The skills on their way that mark the ground (aimed ones; a sweep needs no warning).
func _marked_effects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in view.sim.effects:
		if SkillLook.footprint(e.def.id) != "":
			out.append(e)
	return out


# ---------------------------------------------------------------------------
# The marks on the ground (drawn by SkillGround, under the units)

## Everything marking the ground right now: the warnings of skills on their way, and the aim reticle.
## A mark is {lo, hi, kind, id, shot, col, progress, reticle}; `progress` (0..1) is how far a warning has run.
func _marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sim := view.sim
	for e in _marked_effects():
		var def: AbilityDef = e.def
		var look := SkillLook.for_skill(view.race_of(e.side), String(def.id))
		# A mark glows in its race's colour; the opponent's is pushed toward red so it reads as a threat.
		var col: Color = look.get("glow", Color.WHITE)
		if e.side != 0:
			col = col.lerp(SkillLook.DANGER, 0.65)
		var progress := 1.0
		if e.pulse == 0:
			progress = clampf(1.0 - (e.next_t - sim.time) / maxf(0.05, def.telegraph), 0.0, 1.0)
		out.append({"lo": e.lo, "hi": e.hi, "kind": SkillLook.footprint(def.id), "id": String(def.id), "shot": look.get("shot", ""), "col": col,
			"progress": progress, "reticle": false})
	if view.aim.active:
		var pv := view.aim.preview()
		if not pv.is_empty():
			var ab := sim.ability_def(view.aim.side)
			out.append({"lo": pv.zone[0], "hi": pv.zone[1], "kind": SkillLook.footprint(ab.id), "id": String(ab.id), "shot": "",
				"col": Color("ffc61a") if pv.count > 0 else Color("ff5a4a"), "progress": -1.0, "reticle": true})
	return out


## The shade under a mark: feathered, like the shadow of what is about to fall. A warning deepens as it runs out.
func draw_ground(ci: CanvasItem, _t: float) -> void:
	for m in _marks():
		var st: float = 0.7 if m.reticle else lerpf(0.3, 1.0, m.progress)
		var lo: float = m.lo
		var hi: float = m.hi
		if m.kind == "circle":
			var c := Vector2((lo + hi) * 0.5, GROUND_Y + 10.0)
			var half := (hi - lo) * 0.5
			for i in 6:
				var k := 1.0 - i * 0.13
				FkPaint.ellipse(ci, c, Vector2(half * k, half * CIRCLE_SQUASH * k), Color(0, 0, 0, 0.07 * st))
		else:
			var top := GROUND_Y + FIELD_BACK
			var h := FIELD_FRONT - FIELD_BACK
			for i in 6:
				var inset := i * 6.0
				ci.draw_rect(Rect2(lo + inset, top + inset * 0.5, (hi - lo) - inset * 2.0, h - inset), Color(0, 0, 0, 0.08 * st))


## The light of a mark: a thin ring or brackets in the skill's own colour, fading in as the warning runs out.
func draw_ground_glow(ci: CanvasItem, t: float) -> void:
	for m in _marks():
		var st: float = 1.15 if m.reticle else lerpf(0.4, 1.0, m.progress)
		var col: Color = m.col
		var lo: float = m.lo
		var hi: float = m.hi
		var half := (hi - lo) * 0.5
		if m.kind == "circle":
			var c := Vector2((lo + hi) * 0.5, GROUND_Y + 10.0)
			var ry := half * CIRCLE_SQUASH
			var ring := _ring(c, half, ry)
			ci.draw_colored_polygon(ring.slice(0, ring.size() - 1), Color(col, (0.04 + 0.07 * st) * 0.8))
			ci.draw_polyline(ring, Color(col, 0.14 * st), 9.0)
			ci.draw_polyline(ring, Color(col, 0.6 * st), 2.5)
			if m.progress >= 0.0 and m.progress < 1.0:
				# The ring brightens clockwise from the top as the warning runs out.
				var arc := PackedVector2Array()
				var n := maxi(2, int(64 * m.progress))
				for i in n + 1:
					var a: float = -PI * 0.5 + TAU * m.progress * i / n
					arc.append(c + Vector2(cos(a) * half, sin(a) * ry))
				ci.draw_polyline(arc, Color(col.lightened(0.35), 0.95), 3.5)
			if m.id == "starfall":
				_sigil(ci, c, half, ry, col, t, st, m.shot)
			elif m.id == "rockfall":
				# Dust turning slowly round the rim.
				for i in 18:
					if i % 2 == 0:
						var a0 := TAU * i / 18.0 + t * 0.7
						var a1 := a0 + TAU / 36.0
						ci.draw_line(c + Vector2(cos(a0) * half * 0.86, sin(a0) * ry * 0.86), c + Vector2(cos(a1) * half * 0.86, sin(a1) * ry * 0.86), Color(col, 0.35 * st), 3.0)
			if m.reticle:
				ci.draw_line(c + Vector2(-14, 0), c + Vector2(14, 0), Color(col, 0.9), 2.5)
				ci.draw_line(c + Vector2(0, -5), c + Vector2(0, 5), Color(col, 0.9), 2.5)
		else:
			var top := GROUND_Y + FIELD_BACK
			var bot := GROUND_Y + FIELD_FRONT
			var r := Rect2(lo, top, hi - lo, bot - top)
			ci.draw_rect(r, Color(col, (0.05 + 0.08 * st) * 0.8))
			ci.draw_rect(r, Color(col, 0.13 * st), false, 9.0)
			ci.draw_rect(r, Color(col, 0.5 * st), false, 2.0)
			# Brackets painted at the corners.
			for corner in [Vector2(lo, top), Vector2(hi, top), Vector2(lo, bot), Vector2(hi, bot)]:
				var sx: float = 1.0 if corner.x == lo else -1.0
				var sy: float = 1.0 if corner.y == top else -1.0
				ci.draw_line(corner, corner + Vector2(sx * 24.0, 0), Color(col, 0.85 * st), 4.0)
				ci.draw_line(corner, corner + Vector2(0, sy * 18.0), Color(col, 0.85 * st), 4.0)
			if m.progress >= 0.0 and m.progress < 1.0:
				ci.draw_line(Vector2(lo, top), Vector2(lo + (hi - lo) * m.progress, top), Color(col.lightened(0.35), 0.95), 3.5)
			if m.reticle:
				var mid := (lo + hi) * 0.5
				ci.draw_line(Vector2(mid, top + 6), Vector2(mid, bot - 6), Color(col, 0.5), 2.0)
				ci.draw_line(Vector2(mid - 20, (top + bot) * 0.5), Vector2(mid + 20, (top + bot) * 0.5), Color(col, 0.5), 2.0)


## The sigil Starfall is cast from: a second ring, a star of the skill's own kind (a lance's eight points, a
## star's five, a rune's six) turning inside it, and glyph ticks. It wakes up as the warning runs out.
func _sigil(ci: CanvasItem, c: Vector2, half: float, ry: float, col: Color, t: float, st: float, shot: String) -> void:
	ci.draw_polyline(_ring(c, half * 0.66, ry * 0.66), Color(col, 0.4 * st), 2.0)
	var n := {"lance": 8, "star": 5, "bolt": 6}.get(shot, 6) as int
	var step := 3 if n == 8 else 2
	var pts := PackedVector2Array()
	for i in n:
		var a := t * 0.5 + TAU * i / n - PI * 0.5
		pts.append(c + Vector2(cos(a) * half * 0.6, sin(a) * ry * 0.6))
	for i in n:
		ci.draw_line(pts[i], pts[(i + step) % n], Color(col, (0.25 + 0.4 * st) * 0.8), 2.0)
	for i in 12:
		var a := -t * 0.35 + TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + Vector2(d.x * half * 0.74, d.y * ry * 0.74), c + Vector2(d.x * half * 0.86, d.y * ry * 0.86), Color(col, 0.55 * st), 2.5)


## A closed ellipse as a polyline.
func _ring(c: Vector2, rx: float, ry: float, n := 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _draw_stuck(ci: CanvasItem, s: Dictionary, t: float) -> void:
	var a: float = 1.0 - clampf(((t - s.born) - (s.life - 0.5)) / 0.5, 0.0, 1.0)
	var look: Dictionary = s.look
	var pos: Vector2 = s.pos
	var up := Vector2.from_angle(s.ang + PI)  # pointing back where it came from
	match s.shot:
		"pilum", "arrow":
			var l: float = s.r * 0.55
			ci.draw_line(pos, pos + up * l, Color(INK, INK.a * a), 4.4)
			ci.draw_line(pos, pos + up * l, Color(look.body, a), 2.4)
			ci.draw_line(pos, pos + up * 8.0, Color(look.lit, a), 2.6)
			if s.shot == "arrow":
				var g: Color = look.glow
				ci.draw_line(pos + up * (l - 7.0), pos + up * l, Color(g, a), 3.4)
		"axe":
			var d := Vector2.from_angle(s.ang)
			ci.draw_line(pos + Vector2(0, 2), pos + Vector2(0, -18), Color(INK, INK.a * a), 4.6)
			ci.draw_line(pos + Vector2(0, 2), pos + Vector2(0, -18), Color(look.body, a), 2.6)
			ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -18), pos + Vector2(10 * signf(d.x + 0.01), -22), pos + Vector2(8 * signf(d.x + 0.01), -10)]), Color(look.lit, a))
		"thorn":
			var l: float = s.r * 0.9
			var side := up.orthogonal()
			var pts := PackedVector2Array([pos + side * 5.0, pos + up * l, pos - side * 5.0])
			ci.draw_colored_polygon(pts, Color(INK, INK.a * a))
			ci.draw_colored_polygon(PackedVector2Array([pos + side * 3.5, pos + up * (l - 3.0), pos - side * 3.5]), Color(look.body.lerp(look.glow, 0.35), a))


func _draw_herd(ci: CanvasItem, h: Dictionary, t: float) -> void:
	var look: Dictionary = h.look
	var front: float = h.x0 + h.dir * h.v * (t - h.born)
	for i in h.beasts.size():
		var b: Dictionary = h.beasts[i]
		var x: float = front - h.dir * b.back
		var s: float = b.s
		FkPaint.ellipse(ci, Vector2(x, b.y + 6), Vector2(46.0 * s, 8.0 * s), Color(0, 0, 0, 0.3))
		FkPaint.begin(ci, Transform2D(0.0, Vector2(h.dir * s, s), 0.0, Vector2(x, b.y)))
		FkMounts.quadruped(ci, look.beast, look.body, {"moving": true, "walk": t * 30.0 + b.ph, "t": t}, i, Color("a5a9ae"), {"yaw": UnitArt.view_yaw})
		ci.draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------------------
# Drawing: over the particles (projectile bodies, labels, numbers)

func draw_over(ci: CanvasItem, t: float) -> void:
	for it in items:
		if it.k == "proj":
			_draw_proj(ci, it, t)
	_draw_labels(ci, t)
	var f := UiStyle.font("bold")
	for p in popups:
		var u: float = (t - p.born) / p.life
		var a := clampf((1.0 - u) * 3.0, 0.0, 1.0)
		var y: float = p.y - 46.0 * (1.0 - pow(1.0 - u, 2.0))
		var size: int = p.size
		var w := f.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(p.x - w * 0.5, y)
		ci.draw_string_outline(f, at, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.8 * a))
		ci.draw_string(f, at, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(p.col, a))
		if p.mode == "true":
			var c := at + Vector2(-11.0, -size * 0.35)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), Color(p.col, a))


func _blob(ci: CanvasItem, c: Vector2, r: float, rot: float, seed: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 9.0 + rot
		pts.append(c + Vector2(cos(a), sin(a)) * r * (0.82 + 0.28 * absf(sin(seed * 7.3 + i * 2.17))))
	ci.draw_colored_polygon(pts, col)


func _draw_proj(ci: CanvasItem, p: Dictionary, t: float) -> void:
	var u: float = (t - p.born) / p.dur
	var pos := _pos(p, u)
	var dirv := (_pos(p, minf(1.0, u + 0.03)) - pos).normalized()
	if dirv.length() < 0.1:
		dirv = Vector2.DOWN
	var look: Dictionary = p.look
	var r: float = p.r
	var rot: float = t * p.spin + p.seed
	var side := dirv.orthogonal()
	match p.shot:
		"rock", "boulder":
			_blob(ci, pos, r + 3.0, rot, p.seed, INK)
			_blob(ci, pos, r, rot, p.seed, look.body)
			_blob(ci, pos + Vector2(-r * 0.22, -r * 0.28), r * 0.55, rot, p.seed + 3.0, look.lit)
			ci.draw_line(pos + Vector2.from_angle(rot) * r * 0.2, pos + Vector2.from_angle(rot + 2.4) * r * 0.75, Color(INK, 0.6), 2.0)
		"runestone":
			_blob(ci, pos, r + 3.0, rot, p.seed, INK)
			_blob(ci, pos, r, rot, p.seed, look.body)
			_blob(ci, pos + Vector2(-r * 0.22, -r * 0.28), r * 0.5, rot, p.seed + 3.0, look.lit.darkened(0.2))
			for k in 3:
				var a := rot + k * 2.1
				var q := pos + Vector2.from_angle(a) * r * 0.45
				ci.draw_line(q, q + Vector2.from_angle(a + 1.0) * r * 0.36, Color(look.glow.lightened(0.3), 0.95), 3.0)
		"crystal":
			var l := r * 1.9
			var pts := PackedVector2Array([pos + dirv * l * 0.6, pos + side * r * 0.62, pos - dirv * l * 0.6, pos - side * r * 0.62])
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * (l * 0.6 + 3.0), pos + side * (r * 0.62 + 3.0), pos - dirv * (l * 0.6 + 3.0), pos - side * (r * 0.62 + 3.0)]), INK)
			ci.draw_colored_polygon(pts, look.body)
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * l * 0.6, pos + side * r * 0.62, pos - dirv * l * 0.05]), look.lit)
		"pilum":
			_streak(ci, p, u, 90.0, Color(1, 1, 1, 0.55), 3.0)
			var l: float = r
			ci.draw_line(pos - dirv * l, pos, INK, 6.0)
			ci.draw_line(pos - dirv * l, pos - dirv * 8.0, look.body, 3.6)
			ci.draw_line(pos - dirv * 22.0, pos, look.lit.darkened(0.15), 2.4)
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * 15.0, pos + side * 5.5, pos - side * 5.5]), INK)
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * 12.5, pos + side * 3.6 - dirv * 1.0, pos - side * 3.6 - dirv * 1.0]), look.lit)
		"arrow":
			_streak(ci, p, u, 110.0, Color(look.glow, 0.85), 3.4)
			var l: float = r
			ci.draw_line(pos - dirv * l, pos, INK, 5.4)
			ci.draw_line(pos - dirv * l, pos, look.body, 2.8)
			for k in 3:
				var at := pos - dirv * (l - 2.0 - k * 3.6)
				ci.draw_line(at, at - dirv * 4.0 + side * 4.0, look.glow, 2.2)
				ci.draw_line(at, at - dirv * 4.0 - side * 4.0, look.glow, 2.2)
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * 12.0, pos + side * 4.6, pos - side * 4.6]), INK)
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * 10.0, pos + side * 3.0, pos - side * 3.0]), look.lit)
		"axe":
			var a: float = t * 16.0 + p.seed
			for k in 3:
				var back := _pos(p, maxf(0.0, u - k * 0.018))
				var d := Vector2.RIGHT.rotated(a - k * 0.7)
				var fade := 1.0 - k * 0.32
				if k == 0:
					ci.draw_line(back - d * 15, back + d * 15, INK, 7.0)
					ci.draw_colored_polygon(PackedVector2Array([back + d * 17.5, back + d * 17.5 + d.orthogonal() * 15.0, back + d * 3.0 + d.orthogonal() * 15.0]), INK)
				ci.draw_line(back - d * 15, back + d * 15, Color(look.body, fade), 4.0)
				ci.draw_colored_polygon(PackedVector2Array([back + d * 15, back + d * 15 + d.orthogonal() * 12.5, back + d * 5 + d.orthogonal() * 12.5]), Color(look.lit, fade))
		"fireball":
			_streak(ci, p, u, 120.0, Color(look.glow, 0.7), r * 0.9)
			_blob(ci, pos, r + 2.5, rot, p.seed, INK)
			_blob(ci, pos, r, rot, p.seed, look.body)
			_blob(ci, pos, r * 0.6, rot + 1.0, p.seed + 2.0, look.lit.darkened(0.25))
		"ball":
			_streak(ci, p, u, 90.0, Color(0.85, 0.85, 0.85, 0.35), r * 0.6)
			ci.draw_circle(pos, r + 1.8, Color(0.9, 0.9, 0.86, 0.9))
			ci.draw_circle(pos, r, look.body)
			ci.draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.5))
		"runeshell":
			var l := r * 1.25
			ci.draw_line(pos - dirv * l, pos + dirv * l, INK, r * 1.5)
			ci.draw_line(pos - dirv * l, pos + dirv * l, look.body, r * 1.1)
			ci.draw_line(pos - dirv * l * 0.3, pos + dirv * l * 0.1, look.lit, r * 1.15)
			ci.draw_circle(pos + dirv * l, r * 0.55, look.body)
		"thorn":
			var l := r
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * l * 0.6, pos + side * (r * 0.2 + 3.0), pos - dirv * l * 0.5, pos - side * (r * 0.2 + 3.0)]), INK)
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * l * 0.55, pos + side * r * 0.17, pos - dirv * l * 0.45, pos - side * r * 0.17]), look.body)
			ci.draw_colored_polygon(PackedVector2Array([pos + dirv * l * 0.55, pos + side * r * 0.11, pos + dirv * l * 0.05, pos - side * r * 0.11]), look.lit)
		"moon":
			_streak(ci, p, u, 160.0, Color(look.glow, 0.7), 5.0)
			ci.draw_circle(pos, r * 0.8, Color(1, 1, 1, 0.95))
		"star":
			_streak(ci, p, u, 200.0, Color(look.glow, 0.8), 6.0)
			_star(ci, pos, r, rot, INK, 1.25)
			_star(ci, pos, r, rot, look.body, 1.0)
			ci.draw_circle(pos, r * 0.35, Color(1, 1, 1, 0.95))


func _star(ci: CanvasItem, c: Vector2, r: float, rot: float, col: Color, k: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot - PI * 0.5 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * k * (1.0 if i % 2 == 0 else 0.45))
	ci.draw_colored_polygon(pts, col)


## A fading streak behind a projectile: a dark under-stroke so it reads on a bright sky, then the colour.
func _streak(ci: CanvasItem, p: Dictionary, u: float, span: float, col: Color, w: float) -> void:
	var du := minf(span / maxf(1.0, (p.to as Vector2).distance_to(p.from)), u)
	if du <= 0.0:
		return
	var n := 8
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(_pos(p, u - du * i / n))
	ci.draw_polyline(pts, Color(0.05, 0.05, 0.08, 0.2), w + 2.5)
	for i in n:
		var f := float(i) / n
		ci.draw_line(pts[i], pts[i + 1], Color(col, col.a * (1.0 - f)), maxf(0.6, w * (1.0 - 0.8 * f)))


func _draw_labels(ci: CanvasItem, _t: float) -> void:
	var sim := view.sim
	var f := UiStyle.font("bold")
	for e in _marked_effects():
		var def: AbilityDef = e.def
		var remain: float = maxf(0.0, e.next_t - sim.time)
		var name := view.race_def(e.side).ability_name(def).to_upper()
		var col := _warn_color(e.side)
		var text := name if e.side == 0 else "ENEMY " + name
		if e.pulse == 0:
			text += "  %.1f" % remain
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var at := Vector2((e.lo + e.hi) * 0.5 - w * 0.5, GROUND_Y - 140.0)
		ci.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 7, Color(0, 0, 0, 0.8))
		ci.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col.lightened(0.25))
	var aim := view.aim
	if aim.active:
		var pv := aim.preview()
		if not pv.is_empty():
			var z: Array = pv.zone
			var mid: float = (z[0] + z[1]) * 0.5
			var text := "%d" % pv.count if pv.count > 0 else "no targets"
			var col := Color("ffd84a") if pv.count > 0 else Color("ff7a6a")
			var size := 40 if pv.count > 0 else 22
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			var at := Vector2(mid - w * 0.5, GROUND_Y - 130.0)
			ci.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 9, Color(0, 0, 0, 0.85))
			ci.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ---------------------------------------------------------------------------
# Drawing: the additive glow pass (telegraphs, the aim reticle, everything luminous)

func draw_glow(ci: CanvasItem, t: float) -> void:
	_draw_reticle_overlay(ci, t)
	for it in items:
		match it.k:
			"proj":
				_glow_proj(ci, it, t)
			"curtain":
				var u: float = (t - it.born) / it.life
				var a: float = (1.0 - u) * 0.5 * fxl.flash_scale
				var lo: float = it.lo
				var w: float = it.hi - lo
				for i in 4:
					ci.draw_rect(Rect2(lo, GROUND_Y - 420.0 + i * 100.0, w, 105.0), Color(it.col, a * (0.15 + 0.22 * i)))
				for k in 14:
					var x := lo + fmod(k * 37.7 + it.born * 91.0, w)
					ci.draw_line(Vector2(x, GROUND_Y - 360.0), Vector2(x - 26.0, GROUND_Y + 6.0), Color(1, 1, 1, a * 0.7), 1.6)
			"column":
				var u: float = (t - it.born) / it.life
				var w: float = it.w * (1.0 - u * 0.6)
				var a: float = (1.0 - u) * fxl.flash_scale
				ci.draw_rect(Rect2(it.x - w * 0.5, -600, w, GROUND_Y + 610), Color(it.col, 0.35 * a))
				ci.draw_rect(Rect2(it.x - w * 0.18, -600, w * 0.36, GROUND_Y + 610), Color(1, 1, 1, 0.85 * a))
			"bolt":
				var u: float = (t - it.born) / it.life
				var a: float = (1.0 - u) * (0.7 + 0.3 * sin(t * 90.0)) * fxl.flash_scale
				for line in [it.main] + it.forks:
					ci.draw_polyline(line, Color(it.col, 0.5 * a), 12.0 if line == it.main else 7.0)
					ci.draw_polyline(line, Color(1, 1, 1, 0.95 * a), 3.6 if line == it.main else 2.0)
			"crack":
				var a: float = 1.0 - (t - it.born) / it.life
				for line in it.lines:
					var pts := PackedVector2Array()
					for q in line:
						pts.append(it.pos + q)
					ci.draw_polyline(pts, Color(it.col, 0.6 * a), 2.0)
			"charge":
				_glow_charge(ci, it, t)
			"flare":
				var flick := 0.7 + 0.3 * sin(t * 30.0 + it.x)
				ci.draw_circle(Vector2(it.x, it.y - 32.0), 16.0 * flick, Color(it.col, 0.3))
				ci.draw_circle(Vector2(it.x, it.y - 32.0), 6.0, Color(1, 1, 1, 0.9))
			"herd":
				var front: float = it.x0 + it.dir * it.v * (t - it.born)
				for b in it.beasts:
					var x: float = front - it.dir * b.back
					ci.draw_line(Vector2(x - it.dir * 40.0, b.y - 24.0), Vector2(x - it.dir * 200.0, b.y - 24.0), Color(it.look.glow, 0.14), 16.0)


func _glow_proj(ci: CanvasItem, p: Dictionary, t: float) -> void:
	var u: float = (t - p.born) / p.dur
	var pos := _pos(p, u)
	var look: Dictionary = p.look
	var glow: Color = look.get("glow", Color.WHITE)
	var r: float = p.r
	match p.shot:
		"fireball", "runeshell":
			ci.draw_circle(pos, r * 1.9, Color(glow, 0.22))
			ci.draw_circle(pos, r * 1.15, Color(glow, 0.45))
		"ball":
			ci.draw_circle(pos, r * 1.5, Color(glow, 0.2))
		"runestone":
			ci.draw_circle(pos, r * 1.6, Color(glow, 0.18))
		"rock":
			if look.get("trail", "") == "ember":
				ci.draw_circle(pos, r * 1.5, Color(glow, 0.2))
		"crystal":
			ci.draw_circle(pos, r * 1.5, Color(glow, 0.3))
		"moon":
			ci.draw_circle(pos, r * 2.4, Color(glow, 0.3))
			ci.draw_circle(pos, r * 1.4, Color(glow, 0.55))
		"star":
			ci.draw_circle(pos, r * 2.2, Color(glow, 0.3))
		"arrow", "pilum", "axe":
			ci.draw_circle(pos, 9.0, Color(glow, 0.2))
		"thorn":
			ci.draw_circle(pos, r * 0.5, Color(glow, 0.2))


## What the reticle adds above the ground: a beam for a circle, and a marker over every unit it would hit.
func _draw_reticle_overlay(ci: CanvasItem, t: float) -> void:
	var aim := view.aim
	if not aim.active:
		return
	var pv := aim.preview()
	if pv.is_empty():
		return
	var z: Array = pv.zone
	var col := Color("ffc61a") if pv.count > 0 else Color("ff5a4a")
	var mid: float = (z[0] + z[1]) * 0.5
	if SkillLook.footprint(view.sim.ability_def(aim.side).id) == "circle":
		for k in 12:
			var y := -300.0 + k * 90.0
			ci.draw_line(Vector2(mid, y + fmod(t * 120.0, 90.0)), Vector2(mid, y + 40.0 + fmod(t * 120.0, 90.0)), Color(col, 0.3), 2.0)
	var sim := view.sim
	var enemy := 1 - aim.side
	for u in sim.sides[enemy].units:
		if not u.alive():
			continue
		var x := sim.to_world(enemy, u.progress)
		if x < z[0] or x > z[1]:
			continue
		var pos := view.world.unit_pos(u)
		var top := pos.y - UnitArt.height_for(u.def, view.race_of(enemy)) * WorldLayer.draw_scale(u.def) - 16.0 - 3.0 * sin(t * 9.0 + u.id)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(pos.x - 9, top - 12), Vector2(pos.x + 9, top - 12), Vector2(pos.x, top)]), Color(col, 0.95))


func _warn_color(side: int) -> Color:
	return view.team_color(0).lightened(0.4) if side == 0 else SkillLook.DANGER


func _glow_charge(ci: CanvasItem, ch: Dictionary, t: float) -> void:
	var look: Dictionary = ch.look
	var glow: Color = look.get("glow", Color.WHITE)
	var f: float = clampf((t - ch.born) / ch.life, 0.0, 1.0)
	var mid: float = ch.x
	var half: float = ch.w * 0.5
	# Rings converge on the target, faster as the strike nears.
	for k in 3:
		var ph := fmod(f * 2.4 + k / 3.0, 1.0)
		var rx := half * (1.6 - 1.3 * ph)
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(Vector2(mid + cos(a) * rx, GROUND_Y + 6 + sin(a) * rx * 0.2))
		ci.draw_polyline(pts, Color(glow, 0.55 * ph), 3.0)
	ci.draw_rect(Rect2(mid - half * 0.16, -600, half * 0.32, GROUND_Y + 610), Color(glow, 0.06 + 0.22 * f * f))
