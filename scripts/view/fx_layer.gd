class_name FxLayer
extends Node2D
## World-space effects: pooled particles, projectiles, decals, ability visuals and shockwaves.
## Effects are built per damage type so counters read visually (GDD §13.4). Two passes: normal
## (smoke, debris, projectiles) and additive glow (flashes, muzzle fire, beams — the "lights").

const MAX_PARTICLES := 1400
const MAX_DECALS := 40
const GROUND_Y := 760.0

var view: MatchView
var lights: LightPool
var particles: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var decals: Array[Dictionary] = []
var skills: SkillFx                   # everything a skill looks like (GDD §7)
var scheduled: Array[Dictionary] = [] # {at, fn: Callable}
var glow: Node2D
var rng := RandomNumberGenerator.new()
var intensity := 1.0                  # VFX preset scale (Low halves particle counts)
var flash_scale := 1.0                # 0.5 with "Reduce flashing" (GDD §14)


func _init() -> void:
	skills = SkillFx.new(self)


func _ready() -> void:
	glow = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.draw.connect(_draw_glow)
	add_child(glow)


func now() -> float:
	return view.anim_time


func later(delay: float, fn: Callable) -> void:
	scheduled.append({"at": now() + delay, "fn": fn})


## Public hooks for SkillFx.
func sound(name: String, pos: Vector2, db := 0.0) -> void:
	_sound(name, pos, db)


func light(pos: Vector2, col: Color, energy: float, radius: float, life: float) -> void:
	_light(pos, col, energy, radius, life)


func particle(d: Dictionary) -> void:
	_p(d)


# ---------------------------------------------------------------------------
# Particle helpers

func _p(d: Dictionary) -> void:
	if particles.size() >= MAX_PARTICLES:
		particles.pop_front()
	d["born"] = now()
	particles.append(d)


func burst(kind: String, pos: Vector2, n: int, col: Color, speed: Vector2, life: Vector2, size: Vector2, gravity := 0.0, spread := PI, dir := -PI * 0.5, add := false) -> void:
	for i in maxi(1, int(n * intensity)):
		var a := dir + rng.randf_range(-spread, spread)
		_p({"kind": kind, "pos": pos, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(speed.x, speed.y),
			"life": rng.randf_range(life.x, life.y), "size": rng.randf_range(size.x, size.y), "col": col,
			"g": gravity, "add": add, "rot": rng.randf() * TAU, "spin": rng.randf_range(-8, 8)})


func flash(pos: Vector2, r: float, col: Color, life := 0.12) -> void:
	col.a *= flash_scale
	_p({"kind": "flash", "pos": pos, "vel": Vector2.ZERO, "life": life, "size": r, "col": col, "g": 0.0, "add": true, "rot": 0.0, "spin": 0.0})


func ring(pos: Vector2, r: float, col: Color, life := 0.45, width := 4.0) -> void:
	_p({"kind": "ring", "pos": pos, "vel": Vector2.ZERO, "life": life, "size": r, "col": col, "g": 0.0, "add": true, "rot": width, "spin": 0.0})


func scorch(x: float, w: float) -> void:
	if decals.size() >= MAX_DECALS:
		decals.pop_front()
	decals.append({"x": x, "w": w, "born": now(), "life": 7.0})


# ---------------------------------------------------------------------------
# Impacts per damage type

func _sound(name: String, pos: Vector2, db := 0.0) -> void:
	if view.audio != null:
		view.audio.play(name, pos, db)


func impact(dtype: String, pos: Vector2, heavy := false, structure := false) -> void:
	_sound({"slash": "slash", "pierce": "pierce", "blast": "blast", "siege": "siege"}.get(dtype, "pierce"), pos,
		0.0 if heavy or structure else -5.0)
	match dtype:
		"slash":
			_p({"kind": "arc", "pos": pos + Vector2(0, -6), "vel": Vector2.ZERO, "life": 0.14, "size": 16.0, "col": Color(1, 1, 1, 0.9), "g": 0.0, "add": true, "rot": rng.randf_range(-0.6, 0.6), "spin": 0.0})
			burst("spark", pos, 6, Color("fff1c4"), Vector2(120, 260), Vector2(0.12, 0.25), Vector2(2, 4), 400.0, 1.2, -PI * 0.5, true)
			flash(pos, 14, Color(1, 1, 0.9, 0.5), 0.07)
		"pierce":
			burst("smoke", pos, 3, Color(0.9, 0.88, 0.8, 0.5), Vector2(10, 40), Vector2(0.3, 0.5), Vector2(4, 8))
			burst("spark", pos, 3, Color("ffe7a0"), Vector2(80, 180), Vector2(0.1, 0.2), Vector2(1.5, 3), 300.0, 1.0, -PI * 0.5, true)
			flash(pos, 10, Color(1, 0.95, 0.8, 0.45), 0.06)
		"blast":
			var s := 1.6 if heavy else 1.0
			flash(pos, 42 * s, Color(1.0, 0.72, 0.4, 0.6), 0.14)
			_light(pos, Color(1.0, 0.62, 0.3), 1.4 * s, 260.0 * s, 0.35)
			flash(pos, 18 * s, Color(1.0, 0.95, 0.8, 0.9), 0.08)
			burst("fire", pos, 8, Color("ff8a2a"), Vector2(40, 160), Vector2(0.2, 0.4), Vector2(8, 16) * s, -60.0, PI, -PI * 0.5, true)
			burst("chunk", pos, 7, Color("3b3026"), Vector2(150, 340), Vector2(0.5, 0.9), Vector2(3, 6), 900.0, 1.1)
			burst("smoke", pos + Vector2(0, -8), 7, Color(0.25, 0.22, 0.2, 0.6), Vector2(20, 60), Vector2(0.8, 1.4), Vector2(10, 18) * s, -30.0)
			ring(pos, 90 * s, Color(1, 0.85, 0.6, 0.5), 0.35, 5.0)
			if pos.y > GROUND_Y - 40:
				scorch(pos.x, 40 * s)
			view.add_shake(6.0 * s)
		"siege":
			burst("smoke", pos, 9, Color(0.62, 0.52, 0.4, 0.6), Vector2(30, 110), Vector2(0.6, 1.1), Vector2(10, 20), -20.0)
			burst("chunk", pos, 8, Color("8a7a66") if structure else Color("5a4a3a"), Vector2(160, 320), Vector2(0.5, 1.0), Vector2(3, 7), 900.0, 1.2)
			flash(pos, 30, Color(1, 0.9, 0.7, 0.4), 0.08)
			view.add_shake(9.0 if structure else 4.0)
	if heavy:
		view.hitstop(0.05)


func muzzle(pos: Vector2, dir: float, big := false, col := Color(1.0, 0.8, 0.4), sound := "gun") -> void:
	_sound(sound, pos, 0.0 if big else -3.0)
	var s := 1.8 if big else 1.0
	flash(pos, 18 * s, Color(col, 0.9), 0.07)
	_light(pos, col, 0.9 * s, 150.0 * s, 0.12)
	_p({"kind": "cone", "pos": pos, "vel": Vector2.ZERO, "life": 0.07, "size": 22 * s, "col": col, "g": 0.0, "add": true, "rot": dir, "spin": 0.0})
	burst("smoke", pos, 3 if not big else 6, Color(0.85, 0.85, 0.82, 0.45), Vector2(10, 40), Vector2(0.5, 1.0), Vector2(5, 10) * s, -20.0, 0.6, dir)
	if big:
		view.add_shake(3.0)


# ---------------------------------------------------------------------------
# Projectiles

## kind: arrow | stone | javelin | bullet | tracer | ball | shell | bolt
func shoot(kind: String, from: Vector2, to: Vector2, dtype: String, on_hit: Callable, heavy := false) -> void:
	var dist := from.distance_to(to)
	var speed := {"arrow": 760.0, "stone": 620.0, "javelin": 660.0, "axe": 600.0, "bullet": 2400.0, "tracer": 2600.0, "ball": 700.0,
		"shell": 520.0, "bolt": 1500.0, "orb": 560.0}.get(kind, 800.0) as float
	if kind in ["arrow", "stone", "javelin", "axe"]:
		_sound("bow", from, -6.0)
	if kind == "stone":
		# The crack of the sling as the stone is let go.
		flash(from, 9.0, Color(1.0, 0.98, 0.9, 0.6), 0.06)
	var arc := {"arrow": 0.22, "stone": 0.2, "javelin": 0.2, "axe": 0.2, "ball": 0.18, "shell": 0.55, "orb": 0.4}.get(kind, 0.0) as float
	projectiles.append({"kind": kind, "from": from, "to": to, "born": now(), "dur": maxf(0.06, dist / speed),
		"arc": dist * arc, "dtype": dtype, "on_hit": on_hit, "heavy": heavy})


func _proj_pos(p: Dictionary, u: float) -> Vector2:
	var a: Vector2 = p.from
	var b: Vector2 = p.to
	return a.lerp(b, u) + Vector2(0, -4.0 * p.arc * u * (1.0 - u))


## A fading streak behind a projectile: a dark under-stroke, so it shows on a bright sky, and a light one on top of it.
func _streak(ci: CanvasItem, p: Dictionary, u: float, span: float, col: Color, w: float) -> void:
	var du := minf(span / maxf(1.0, (p.to as Vector2).distance_to(p.from)), u)
	if du <= 0.0:
		return
	var n := 8
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(_proj_pos(p, u - du * i / n))
	ci.draw_polyline(pts, Color(0.05, 0.05, 0.08, 0.2), w + 2.5)
	for i in n:
		var f := float(i) / n
		ci.draw_line(pts[i], pts[i + 1], Color(col, col.a * (1.0 - f)), maxf(0.6, w * (1.0 - 0.8 * f)))


# Skills are in SkillFx (skill_fx.gd); FxLayer only lends it the particle pool and the draw passes.


func _light(pos: Vector2, col: Color, energy: float, radius: float, life: float) -> void:
	if lights != null:
		lights.flash(pos, col, energy, radius, life, now())


func evolution_wave(x: float, team: Color) -> void:
	_light(Vector2(x, GROUND_Y - 120), team.lightened(0.5), 2.0, 900.0, 1.2)
	ring(Vector2(x, GROUND_Y - 80), 1200, Color(team.lightened(0.6), 0.75), 1.1, 10.0)
	ring(Vector2(x, GROUND_Y - 80), 700, Color(1, 1, 1, 0.6), 0.8, 5.0)
	flash(Vector2(x, GROUND_Y - 120), 220, Color(team.lightened(0.5), 0.6), 0.4)
	burst("smoke", Vector2(x, GROUND_Y), 26, Color(0.8, 0.75, 0.65, 0.55), Vector2(60, 260), Vector2(0.8, 1.6), Vector2(14, 30), -10.0, 0.6, -PI * 0.5)
	view.add_shake(10.0)
	view.zoom_punch(0.05)


# ---------------------------------------------------------------------------
# Update & draw

func step(dt: float) -> void:
	var t := now()
	var due := scheduled.filter(func(s): return s.at <= t)
	scheduled = scheduled.filter(func(s): return s.at > t)
	for s in due:
		s.fn.call()
	var keep: Array[Dictionary] = []
	for p in particles:
		if t - p.born > p.life:
			continue
		p.vel.y += p.g * dt
		if p.kind in ["smoke", "fire"]:
			p.vel *= 1.0 - 1.8 * dt
		p.pos += p.vel * dt
		if p.kind == "spark" and p.pos.y > GROUND_Y + 14:
			continue
		if p.kind == "chunk" and p.pos.y > GROUND_Y + 8:
			p.pos.y = GROUND_Y + 8
			p.vel = Vector2(p.vel.x * 0.4, -p.vel.y * 0.25)
		p.rot += p.spin * dt
		keep.append(p)
	particles = keep
	var live: Array[Dictionary] = []
	for p in projectiles:
		var u: float = (t - p.born) / p.dur
		if u >= 1.0:
			if p.on_hit.is_valid():
				p.on_hit.call()
			continue
		if p.kind in ["shell", "ball"] and rng.randf() < 0.5:
			_p({"kind": "smoke", "pos": _proj_pos(p, u), "vel": Vector2.ZERO, "life": 0.5, "size": 4.0, "col": Color(0.8, 0.8, 0.8, 0.35), "g": -20.0, "add": false, "rot": 0.0, "spin": 0.0})
		live.append(p)
	projectiles = live
	decals = decals.filter(func(d): return t - d.born < d.life)
	skills.step(dt)
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	var t := now()
	for d in decals:
		var a: float = 1.0 - (t - d.born) / d.life
		FkPaint.ellipse(self, Vector2(d.x, GROUND_Y + 6), Vector2(d.w, 6), Color(0.08, 0.06, 0.05, 0.5 * a))
	skills.draw_under(self, t)
	for p in particles:
		if p.add:
			continue
		var u: float = (t - p.born) / p.life
		var c: Color = p.col
		match p.kind:
			"smoke":
				draw_circle(p.pos, p.size * (1.0 + u * 1.6), Color(c, c.a * (1.0 - u)))
			"chunk":
				draw_set_transform(p.pos, p.rot)
				draw_rect(Rect2(-p.size * 0.5, -p.size * 0.5, p.size, p.size), Color(c, 1.0 - u * u))
				draw_set_transform(Vector2.ZERO)
			"leaf":
				draw_set_transform(p.pos, p.rot)
				var lf: float = p.size
				draw_colored_polygon(PackedVector2Array([Vector2(-lf, 0), Vector2(0, -lf * 0.45), Vector2(lf, 0), Vector2(0, lf * 0.45)]), Color(c, 1.0 - u * u))
				draw_set_transform(Vector2.ZERO)
			_:
				draw_circle(p.pos, p.size * (1.0 - u), Color(c, c.a * (1.0 - u)))
	for p in projectiles:
		var u: float = (t - p.born) / p.dur
		var pos := _proj_pos(p, u)
		var ahead := _proj_pos(p, minf(1.0, u + 0.04))
		var dirv := (ahead - pos).normalized()
		var tint: Color = p.get("col", Color(1, 1, 1))
		var ink := Color(0.06, 0.05, 0.05, 0.85)
		match p.kind:
			"arrow", "javelin":
				var l := 28.0 if p.kind == "arrow" else 36.0
				var side := dirv.orthogonal()
				_streak(self, p, u, l * 2.2, Color(0.98, 0.95, 0.85, 0.7), 2.6)
				draw_line(pos - dirv * l, pos, ink, 4.6)
				draw_line(pos - dirv * l, pos, Color("dcb57c"), 2.6)
				# Fletching in the shooter's colour, so a volley shows whose it is.
				for k in 3:
					var at := pos - dirv * (l - 1.0 - k * 3.2)
					draw_line(at, at - dirv * 3.6 + side * 3.6, ink, 3.2)
					draw_line(at, at - dirv * 3.6 - side * 3.6, ink, 3.2)
					draw_line(at, at - dirv * 3.6 + side * 3.6, tint, 1.8)
					draw_line(at, at - dirv * 3.6 - side * 3.6, tint, 1.8)
				var head := PackedVector2Array([pos + dirv * 9.0, pos + side * 3.4 - dirv * 1.5, pos - side * 3.4 - dirv * 1.5])
				draw_colored_polygon(PackedVector2Array([pos + dirv * 11.0, pos + side * 5.0 - dirv * 2.5, pos - side * 5.0 - dirv * 2.5]), ink)
				draw_colored_polygon(head, Color("e2e6ec"))
			"stone":
				_streak(self, p, u, 46.0, Color(0.98, 0.95, 0.85, 0.8), 3.4)
				draw_circle(pos, 6.0, ink)
				draw_circle(pos, 4.8, Color("b4ad99"))
				draw_circle(pos + Vector2(1.3, 1.3), 2.6, Color("8c8571"))
				draw_circle(pos + Vector2(-1.6, -1.6), 1.6, Color(1, 1, 1, 0.9))
			"axe":
				# A spinning throwing axe, with the ghosts of where it just was.
				var a: float = (t - p.born) * 18.0
				for k in 3:
					var back := _proj_pos(p, maxf(0.0, u - k * 0.02))
					var d := Vector2.RIGHT.rotated(a - k * 0.7)
					var fade := 1.0 - k * 0.35
					if k == 0:
						draw_line(back - d * 13, back + d * 13, ink, 6.0)
					draw_line(back - d * 13, back + d * 13, Color(Color("dcb57c"), fade), 3.6)
					var blade := PackedVector2Array([back + d * 13, back + d * 13 + d.orthogonal() * 11, back + d * 5 + d.orthogonal() * 11])
					if k == 0:
						draw_colored_polygon(PackedVector2Array([back + d * 15.5, back + d * 15.5 + d.orthogonal() * 13.5, back + d * 2.5 + d.orthogonal() * 13.5]), ink)
					draw_colored_polygon(blade, Color(Color("e4e8ed"), fade))
			"orb":
				draw_circle(pos, 6.5, Color(1, 1, 1, 0.95))
			"ball":
				_streak(self, p, u, 30.0, Color(0.8, 0.8, 0.8, 0.35), 5.0)
				draw_circle(pos, 8.8, Color(0.85, 0.85, 0.8, 0.9))
				draw_circle(pos, 7.6, Color(0.07, 0.07, 0.08))
				draw_circle(pos + Vector2(-2.4, -2.4), 2.4, Color(1, 1, 1, 0.5))
			"shell":
				_streak(self, p, u, 30.0, Color(0.8, 0.8, 0.8, 0.35), 5.0)
				draw_circle(pos, 8.0, Color(0.9, 0.85, 0.7, 0.9))
				draw_circle(pos, 6.8, Color(0.24, 0.22, 0.2))
				draw_circle(pos + Vector2(-2.0, -2.0), 2.2, Color(1, 1, 1, 0.5))
			"bullet", "tracer":
				var back := _proj_pos(p, maxf(0.0, u - 44.0 / maxf(1.0, (p.to as Vector2).distance_to(p.from))))
				draw_line(back, pos, Color(1.0, 0.72, 0.3, 0.55), 5.0)
				draw_line(back, pos, Color(1.0, 0.95, 0.75, 0.95), 2.6)
				draw_circle(pos, 3.0, Color(1, 1, 0.9))
			"bolt":
				var back := _proj_pos(p, maxf(0.0, u - 40.0 / maxf(1.0, (p.to as Vector2).distance_to(p.from))))
				draw_line(back, pos, Color(1, 1, 1, 0.95), 2.4)
				draw_circle(pos, 3.6, Color(1, 1, 1))
	skills.draw_over(self, t)


func _draw_glow() -> void:
	var t := now()
	for p in particles:
		if not p.add:
			continue
		var u: float = (t - p.born) / p.life
		var c: Color = p.col
		match p.kind:
			"flash":
				for i in 3:
					glow.draw_circle(p.pos, p.size * (0.4 + i * 0.35) * (1.0 + u * 0.3), Color(c, c.a * (1.0 - u) * (0.5 - i * 0.12)))
			"ring":
				glow.draw_arc(p.pos, p.size * ease(u, 0.4), 0, TAU, 64, Color(c, c.a * (1.0 - u)), p.rot * (1.0 - u) + 1.0)
			"arc":
				glow.draw_arc(p.pos, p.size, p.rot - 1.0, p.rot + 1.0, 12, Color(c, c.a * (1.0 - u)), 3.0)
			"cone":
				var d := Vector2.RIGHT.rotated(p.rot)
				glow.draw_colored_polygon(PackedVector2Array([p.pos, p.pos + d * p.size + d.orthogonal() * p.size * 0.35, p.pos + d * p.size * 1.3, p.pos + d * p.size - d.orthogonal() * p.size * 0.35]), Color(c, 0.9 * (1.0 - u)))
			"spark":
				glow.draw_line(p.pos, p.pos - p.vel * 0.03, Color(c, 1.0 - u), p.size)
			"flare":
				# A four-pointed glint: two crossed slivers, turning as they fade.
				var fl: float = p.size * (1.0 - u * 0.4)
				for k in 2:
					var d := Vector2.from_angle(p.rot + k * PI * 0.5 + u * p.spin)
					glow.draw_colored_polygon(PackedVector2Array([p.pos + d * fl, p.pos + d.orthogonal() * fl * 0.07, p.pos - d * fl, p.pos - d.orthogonal() * fl * 0.07]), Color(c, 0.9 * (1.0 - u)))
			"fire":
				glow.draw_circle(p.pos, p.size * (1.0 - u * 0.6), Color(c, 0.8 * (1.0 - u)))
			_:
				glow.draw_circle(p.pos, p.size * (1.0 - u), Color(c, c.a * (1.0 - u)))
	for p in projectiles:
		var u: float = (t - p.born) / p.dur
		var pos := _proj_pos(p, u)
		var span := 44.0 / maxf(1.0, (p.to as Vector2).distance_to(p.from))
		var back := _proj_pos(p, maxf(0.0, u - span))
		match p.kind:
			"bullet", "tracer":
				glow.draw_line(back, pos, Color(1.0, 0.85, 0.5, 0.9), 4.0)
				glow.draw_circle(pos, 7.0, Color(1.0, 0.85, 0.5, 0.45))
			"bolt":
				var c: Color = p.get("col", Color("37e7ff"))
				glow.draw_line(back, pos, Color(c, 0.9), 7.0)
				glow.draw_circle(pos, 10.0, Color(c, 0.6))
			"shell", "ball":
				glow.draw_circle(pos, 12.0, Color(1.0, 0.6, 0.3, 0.3))
			"orb":
				var c: Color = p.get("col", Color("9fe4ff"))
				glow.draw_line(back, pos, Color(c, 0.6), 8.0)
				glow.draw_circle(pos, 13.0, Color(c, 0.55))
			"stone":
				# A soft halo so a small stone still shows against dark ground and bright sky.
				glow.draw_circle(pos, 10.0, Color(1.0, 0.97, 0.88, 0.13))
			"arrow", "javelin", "axe":
				glow.draw_circle(pos, 8.0, Color(1.0, 0.97, 0.88, 0.14))
	skills.draw_glow(glow, t)
