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

var fxl: FxLayer
var items: Array[Dictionary] = []
var popups: Array[Dictionary] = []
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
	for i in _n(9):
		beasts.append({"back": (i % 3) * 84.0 + rng.randf_range(0.0, 30.0) + (i / 3) * 10.0, "y": GROUND_Y + ((i * 7) % 23) - 11.0,
			"ph": rng.randf() * TAU, "s": rng.randf_range(1.25, 1.5)})
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
			var x := lerpf(c.lo + 30.0, c.hi - 30.0, (i + rng.randf_range(0.15, 0.85)) / n)
			_launch(c, k, _ground(x, 8.0), {"last": k == def.pulses - 1})
		fxl.later(_t(c, k), func():
			view.add_shake(6.0)
			fxl.ring(Vector2((c.lo + c.hi) * 0.5, GROUND_Y + 4), (c.hi - c.lo) * 0.62, Color(c.glow, 0.5), 0.4, 6.0))


# --- Volley -----------------------------------------------------------------

func _cast_volley(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	var look: Dictionary = c.look
	var count := {"pilum": 12, "arrow": 26, "axe": 11}.get(look.shot, 14) as int
	for k in def.pulses:
		for i in _n(count):
			_launch(c, k, _ground(rng.randf_range(c.lo + 10.0, c.hi - 10.0), 26.0), {"shadow": false})
		fxl.later(_t(c, k), func():
			# The zone the volley falls on, as a curtain of shafts.
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
	for k in def.pulses:
		var n := _n(3)
		for i in n:
			_launch(c, k, _ground(lerpf(c.lo + 30.0, c.hi - 30.0, (i + rng.randf_range(0.15, 0.85)) / n), 6.0), {"last": k == def.pulses - 1})
		fxl.later(_t(c, k), func():
			view.add_shake(5.0)
			fxl.ring(Vector2((c.lo + c.hi) * 0.5, GROUND_Y + 4), (c.hi - c.lo) * 0.55, Color(c.glow, 0.45), 0.4, 6.0))


# --- Starfall ---------------------------------------------------------------

func _cast_starfall(c: Dictionary) -> void:
	var def: AbilityDef = c.def
	var mid: float = (c.lo + c.hi) * 0.5
	var w: float = c.hi - c.lo
	items.append({"k": "charge", "born": fxl.now(), "life": def.telegraph, "x": mid, "w": w, "look": c.look, "side": c.side})
	var offsets := [-0.3, 0.3, 0.0]
	for k in def.pulses:
		var last := k == def.pulses - 1
		var x: float = mid + w * (offsets[k % 3] if def.pulses > 1 else 0.0)
		_launch(c, k, Vector2(x, GROUND_Y - 4), {"last": last, "r": float(c.look.r) * (1.35 if last else 1.0)})
		if last:
			fxl.later(_t(c, k), func():
				view.add_shake(16.0)
				view.zoom_punch(0.05)
				fxl.ring(Vector2(mid, GROUND_Y), w * 1.4, Color(c.glow.lightened(0.3), 0.8), 0.7, 8.0))


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
			fxl.flash(to, 16, Color(glow, 0.6), 0.08)
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
			fxl.flash(to, 90 * s, Color(glow, 0.65), 0.22)
			fxl.particle({"kind": "flare", "pos": to + Vector2(0, -10), "vel": Vector2.ZERO, "life": 0.4, "size": 90.0 * s, "col": look.body, "g": 0.0, "add": true, "rot": 0.0, "spin": 0.5})
			fxl.ring(to, 150 * s, Color(glow.lightened(0.4), 0.85), 0.55, 6.0)
			fxl.burst("spark", to, 16, look.body, Vector2(100, 380), Vector2(0.35, 0.8), Vector2(2, 4), 300.0, PI, -PI * 0.5, true)
			fxl.light(to, glow, 2.0, 420.0, 0.5)
			fxl.scorch(to.x, 48)
			view.add_shake(6.0 if not p.last else 0.0)
			fxl.sound("blast", to, -2.0)
		"lance":
			_column(to.x, 70.0 * s, glow, 0.55)
			fxl.flash(to, 110 * s, Color(glow, 0.7), 0.25)
			fxl.particle({"kind": "flare", "pos": to + Vector2(0, -6), "vel": Vector2.ZERO, "life": 0.45, "size": 110.0 * s, "col": look.lit, "g": 0.0, "add": true, "rot": 0.0, "spin": 0.0})
			fxl.ring(to, 160 * s, Color(glow.lightened(0.4), 0.85), 0.5, 7.0)
			fxl.burst("spark", to, 16, glow.lightened(0.4), Vector2(100, 380), Vector2(0.35, 0.8), Vector2(2, 4), 300.0, PI, -PI * 0.5, true)
			fxl.light(to, glow, 2.2, 450.0, 0.5)
			fxl.scorch(to.x, 44)
			view.add_shake(6.0 if not p.last else 0.0)
			fxl.sound("zap", to, -1.0)
		"bolt":
			_strike(to, glow, p.r, p.last)


## Lightning from the clouds to the ground, with a couple of forks.
func _strike(to: Vector2, glow: Color, r: float, last: bool) -> void:
	var top := Vector2(to.x + rng.randf_range(-70.0, 70.0), -260.0)
	var main := _bolt_points(top, to, 46.0)
	var forks := []
	for i in 2:
		var at := main[rng.randi_range(3, 6)]
		forks.append(_bolt_points(at, at + Vector2(rng.randf_range(-150.0, 150.0), rng.randf_range(160.0, 300.0)), 24.0))
	items.append({"k": "bolt", "born": fxl.now(), "life": 0.32, "main": main, "forks": forks, "col": glow})
	fxl.flash(to, 100.0, Color(glow, 0.7), 0.2)
	fxl.flash(Vector2(to.x, 120.0), 520.0, Color(glow, 0.22), 0.16)
	fxl.ring(to, 130.0, Color(glow.lightened(0.5), 0.85), 0.45, 6.0)
	fxl.burst("spark", to, 18, Color.WHITE, Vector2(120, 420), Vector2(0.3, 0.7), Vector2(2, 4), 400.0, PI, -PI * 0.5, true)
	fxl.burst("chunk", to, 6, Color("3b3026"), Vector2(140, 320), Vector2(0.5, 0.9), Vector2(3, 6), 900.0, 1.0)
	fxl.light(to, glow, 2.4, 520.0, 0.4)
	_crack(to, 1.3, glow)
	fxl.scorch(to.x, 44)
	view.add_shake(5.0 if not last else 0.0)
	fxl.sound("zap", to, -1.0)


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
	if popups.size() >= MAX_POPUPS:
		popups.pop_front()
	popups.append({"x": x + rng.randf_range(-10.0, 10.0), "y": GROUND_Y - h - 8.0 - (int(f.unit_id) % 3) * 17.0, "text": text, "col": col, "mode": mode,
		"born": fxl.now(), "life": 1.25 if killed else 1.0, "size": 32 if killed else 25})
	# A mark on the unit itself, coloured like the number.
	var pos := Vector2(x, GROUND_Y - h * 0.55)
	fxl.flash(pos, 26.0, Color(col, 0.55), 0.14)
	fxl.ring(pos, 36.0, Color(col, 0.7), 0.25, 3.0)


# ---------------------------------------------------------------------------
# Per frame

func step(dt: float) -> void:
	var t := fxl.now()
	var keep: Array[Dictionary] = []
	for it in items:
		match it.k:
			"proj":
				var u: float = (t - it.born) / it.dur
				if u >= 1.0:
					_land(it)
					continue
				_trail(it, u, dt)
			"herd":
				if t - it.born > it.life:
					continue
				_herd_dust(it, t, dt)
			"charge":
				if t - it.born > it.life:
					continue
				_charge_motes(it, t, dt)
			_:
				if t - it.born > it.life:
					continue
		keep.append(it)
	items = keep
	popups = popups.filter(func(p): return t - p.born < p.life)


func _pos(p: Dictionary, u: float) -> Vector2:
	var e: float = u * u if p.drop else u
	return (p.from as Vector2).lerp(p.to, e) + Vector2(0, -4.0 * p.arc * u * (1.0 - u))


func _trail(p: Dictionary, u: float, dt: float) -> void:
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


func _herd_dust(h: Dictionary, t: float, _dt: float) -> void:
	var look: Dictionary = h.look
	var front: float = h.x0 + h.dir * h.v * (t - h.born)
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


## Motes drawn in toward a charging Starfall.
func _charge_motes(ch: Dictionary, t: float, _dt: float) -> void:
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
	_draw_zone_shadows(ci, t)
	for it in items:
		match it.k:
			"proj":
				if it.shadow:
					var u: float = clampf((t - it.born) / it.dur, 0.0, 1.0)
					var rx: float = lerpf(5.0, it.r * 1.2 + 8.0, u * u)
					FkPaint.ellipse(ci, Vector2(it.to.x, GROUND_Y + 8), Vector2(rx, rx * 0.24), Color(0, 0, 0, lerpf(0.08, 0.5, u)))
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


## A dark plate under every warning marker and the aim reticle: the coloured band is additive light and
## would vanish on bright ground, so it sits on a dark base with dark edge posts.
func _draw_zone_shadows(ci: CanvasItem, _t: float) -> void:
	var zones: Array[Vector2] = []
	for e in view.sim.effects:
		if e.pulse > 0 and e.def.shape != "sweep" and e.def.pulses <= 1:
			continue
		zones.append(_telegraph_zone(e))
	if view.aim.active:
		var pv := view.aim.preview()
		if not pv.is_empty():
			zones.append(Vector2(pv.zone[0], pv.zone[1]))
	for z in zones:
		ci.draw_rect(Rect2(z.x, GROUND_Y - 5, z.y - z.x, 22), Color(0, 0, 0, 0.38))
		for edge in [z.x, z.y]:
			ci.draw_line(Vector2(edge, GROUND_Y + 18), Vector2(edge, GROUND_Y - 88), Color(0, 0, 0, 0.55), 7.0)


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
		FkMounts.quadruped(ci, look.beast, look.body, {"moving": true, "walk": t * 26.0 + b.ph, "t": t}, i, Color("a5a9ae"), {"yaw": UnitArt.view_yaw})
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


func _draw_labels(ci: CanvasItem, t: float) -> void:
	var sim := view.sim
	var f := UiStyle.font("bold")
	for e in sim.effects:
		if e.pulse > 0 and not (e.def.pulses > 1 and e.def.shape == "sweep"):
			continue
		var def: AbilityDef = e.def
		var z := _telegraph_zone(e)
		var remain: float = maxf(0.0, e.next_t - sim.time)
		var name := view.race_def(e.side).ability_name(def).to_upper()
		var col := _warn_color(e.side)
		var text := name if e.side == 0 else "ENEMY " + name
		if e.pulse == 0:
			text += "  %.1f" % remain
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		var at := Vector2((z.x + z.y) * 0.5 - w * 0.5, GROUND_Y - 122.0)
		ci.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 9, Color(0, 0, 0, 0.9))
		ci.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col.lightened(0.3))
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
	_draw_telegraphs(ci, t)
	_draw_reticle(ci, t)
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
		"lance":
			# A spear of light: a tall taper falling faster than it can be followed.
			var top := pos + Vector2(0, -320.0 * clampf(u * 4.0, 0.0, 1.0) - 60.0)
			var w: float = r
			ci.draw_colored_polygon(PackedVector2Array([pos, top + Vector2(-w, 0), top + Vector2(w, 0)]), Color(glow, 0.32))
			ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(0, 6), top + Vector2(-w * 0.32, 0), top + Vector2(w * 0.32, 0)]), Color(1, 1, 1, 0.9))
			ci.draw_circle(pos, w * 0.9, Color(glow, 0.5))


func _warn_color(side: int) -> Color:
	return view.team_color(0).lightened(0.4) if side == 0 else SkillLook.DANGER


## [lo, hi] of the ground a pending skill is about to hit: the next slice for a sweep, the zone otherwise.
func _telegraph_zone(e: Dictionary) -> Vector2:
	var def: AbilityDef = e.def
	if def.shape == "sweep" and def.pulses > 1:
		return _slice({"def": def, "side": e.side, "lo": e.lo, "hi": e.hi}, mini(e.pulse, def.pulses - 1))
	return Vector2(e.lo, e.hi)


func _band(ci: CanvasItem, lo: float, hi: float, col: Color, t: float, strength: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 12.0)
	ci.draw_rect(Rect2(lo, GROUND_Y - 4, hi - lo, 20), Color(col, (0.22 + 0.16 * pulse) * strength))
	# Diagonal hatching that crawls along the zone, so it never reads as scenery.
	var off := fmod(t * 46.0, 22.0)
	var x := lo - 22.0 + off
	while x < hi:
		var x0 := maxf(lo, x)
		var x1 := minf(hi, x + 14.0)
		if x1 > x0:
			ci.draw_line(Vector2(x0, GROUND_Y + 15), Vector2(x1, GROUND_Y - 5), Color(col, 0.5 * strength), 2.0)
		x += 22.0
	for edge in [lo, hi]:
		ci.draw_line(Vector2(edge, GROUND_Y + 16), Vector2(edge, GROUND_Y - 84), Color(col, 0.85 * strength), 3.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(edge - 7, GROUND_Y - 84), Vector2(edge + 7, GROUND_Y - 84), Vector2(edge, GROUND_Y - 70)]), Color(col, 0.9 * strength))


func _draw_telegraphs(ci: CanvasItem, t: float) -> void:
	var sim := view.sim
	for e in sim.effects:
		var def: AbilityDef = e.def
		if e.pulse > 0 and def.shape != "sweep" and def.pulses <= 1:
			continue
		var z := _telegraph_zone(e)
		var col := _warn_color(e.side)
		_band(ci, z.x, z.y, col, t, 1.0)
		# A ring that fills as the warning runs out, over the middle of the zone.
		if e.pulse == 0 and def.telegraph >= 0.4:
			var f: float = clampf(1.0 - (e.next_t - sim.time) / def.telegraph, 0.0, 1.0)
			var c := Vector2((z.x + z.y) * 0.5, GROUND_Y - 38.0)
			ci.draw_arc(c, 24.0, 0.0, TAU, 32, Color(col, 0.25), 3.0)
			ci.draw_arc(c, 24.0, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Color(col.lightened(0.3), 0.95), 5.0)
			ci.draw_circle(c, 4.0 + 3.0 * (0.5 + 0.5 * sin(t * 14.0)), Color(col.lightened(0.4), 0.9))


func _draw_reticle(ci: CanvasItem, t: float) -> void:
	var aim := view.aim
	if not aim.active:
		return
	var pv := aim.preview()
	if pv.is_empty():
		return
	var z: Array = pv.zone
	var hits: bool = pv.count > 0
	var col := Color("ffc61a") if hits else Color("ff5a4a")
	_band(ci, z[0], z[1], col, t, 1.3)
	var mid: float = (z[0] + z[1]) * 0.5
	var half: float = (z[1] - z[0]) * 0.5
	# The footprint on the ground as a slowly turning dashed ellipse, and a beam down from the sky.
	var n := 36
	for i in n:
		if i % 2 == 0:
			var a0 := TAU * i / n + t * 0.8
			var a1 := TAU * (i + 1) / n + t * 0.8
			ci.draw_line(Vector2(mid + cos(a0) * half, GROUND_Y + 6 + sin(a0) * 22.0), Vector2(mid + cos(a1) * half, GROUND_Y + 6 + sin(a1) * 22.0), Color(col, 0.85), 3.0)
	for k in 12:
		var y := -300.0 + k * 90.0
		ci.draw_line(Vector2(mid, y + fmod(t * 120.0, 90.0)), Vector2(mid, y + 40.0 + fmod(t * 120.0, 90.0)), Color(col, 0.35), 2.0)
	# A marker over every unit the shot would hit.
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
	if look.get("shot", "") == "bolt":
		# The rune wakes: a star drawn inside the circle, turning.
		var pts := PackedVector2Array()
		for i in 6:
			var a := t * 1.2 + TAU * i / 6.0
			pts.append(Vector2(mid + cos(a) * half * 0.9, GROUND_Y + 6 + sin(a) * half * 0.9 * 0.2))
		for i in 6:
			ci.draw_line(pts[i], pts[(i + 2) % 6], Color(glow, 0.25 + 0.6 * f), 2.5)
