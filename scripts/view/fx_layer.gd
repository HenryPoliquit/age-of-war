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
var actors: Array[Dictionary] = []    # stampede beasts, lasting domes, beams
var scheduled: Array[Dictionary] = [] # {at, fn: Callable}
var glow: Node2D
var rng := RandomNumberGenerator.new()
var intensity := 1.0                  # VFX preset scale (Low halves particle counts)
var flash_scale := 1.0                # 0.5 with "Reduce flashing" (GDD §14)


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
	var arc := {"arrow": 0.22, "stone": 0.2, "javelin": 0.2, "axe": 0.2, "ball": 0.18, "shell": 0.55, "orb": 0.4}.get(kind, 0.0) as float
	projectiles.append({"kind": kind, "from": from, "to": to, "born": now(), "dur": maxf(0.06, dist / speed),
		"arc": dist * arc, "dtype": dtype, "on_hit": on_hit, "heavy": heavy})


func _proj_pos(p: Dictionary, u: float) -> Vector2:
	var a: Vector2 = p.from
	var b: Vector2 = p.to
	return a.lerp(b, u) + Vector2(0, -4.0 * p.arc * u * (1.0 - u))


# ---------------------------------------------------------------------------
# Abilities (GDD §7)

## Race flavour for the shared abilities: same footprint and timing, different stuff falling.
const STAMPEDE_BEAST := {&"human": "boar", &"elf": "stag", &"dwarf": "ram"}
const VOLLEY_SHOT := {&"human": "javelin", &"elf": "arrow", &"dwarf": "axe"}
const BOMBARD_SHOT := {&"human": "shell", &"elf": "javelin", &"dwarf": "shell"}
const CANNONADE_SHOT := {&"human": "ball", &"elf": "orb", &"dwarf": "ball"}


func ability_pulse(ability: String, lo: float, hi: float, side: int, team: Color, race: StringName = &"human") -> void:
	var dir := 1.0 if side == 0 else -1.0
	var magic: Color = RaceLook.look(race).glow
	match ability:
		"stampede":
			_sound("stampede", Vector2((lo + hi) * 0.5, GROUND_Y))
			for i in 8:
				var start := (lo if dir > 0 else hi) - dir * rng.randf_range(80, 220)
				actors.append({"kind": "beast", "beast": STAMPEDE_BEAST.get(race, "boar"), "x": start, "y": GROUND_Y + rng.randf_range(-6, 8), "vx": dir * rng.randf_range(620, 760),
					"until_x": hi + 120 if dir > 0 else lo - 120, "born": now(), "life": 1.2, "side": side})
			for k in 10:
				burst("smoke", Vector2(rng.randf_range(lo, hi), GROUND_Y), 2, Color(0.7, 0.58, 0.42, 0.55), Vector2(20, 80), Vector2(0.6, 1.1), Vector2(10, 22), -20.0)
			view.add_shake(8.0)
		"shieldwall":
			actors.append({"kind": "dome", "lo": lo, "hi": hi, "born": now(), "life": 8.0, "col": team})
			ring(Vector2((lo + hi) * 0.5, GROUND_Y - 30), (hi - lo) * 0.6, Color(team.lightened(0.5), 0.6), 0.5, 6.0)
		"volley":
			var kind: String = VOLLEY_SHOT.get(race, "arrow")
			for i in 22:
				var x := rng.randf_range(lo, hi)
				var to := Vector2(x, GROUND_Y - rng.randf_range(4, 30))
				var from := to + Vector2(-dir * rng.randf_range(160, 260), -rng.randf_range(520, 640))
				later(rng.randf_range(0.0, 0.3), func(): shoot(kind, from, to, "pierce", func(): impact("pierce", to)))
		"bombardment", "cannonade":
			var n := 4 if ability == "bombardment" else 3
			var kind: String = (BOMBARD_SHOT if ability == "bombardment" else CANNONADE_SHOT).get(race, "shell")
			for i in n:
				var x := rng.randf_range(lo, hi)
				var to := Vector2(x, GROUND_Y - 6)
				# Siege shot arcs in from the home lines; elven moonfire drops from high above.
				var from := to + (Vector2(-dir * 60, -620) if kind == "orb" else Vector2(-dir * 900, -300 if kind != "shell" else -420))
				later(rng.randf_range(0.0, 0.25), func():
					shoot(kind, from, to, "blast", func(): impact("blast", to, true))
					if kind == "orb":
						projectiles[-1]["col"] = magic)
		"starfall":
			var c := Vector2((lo + hi) * 0.5, GROUND_Y)
			actors.append({"kind": "beam", "x": c.x, "w": hi - lo, "born": now(), "life": 0.6, "col": magic})
			_light(c + Vector2(0, -60), magic.lightened(0.3), 2.5, 700.0, 0.8)
			impact("blast", c + Vector2(0, -10), true)
			ring(c, 260, Color(magic.lightened(0.3), 0.8), 0.6, 8.0)
			for k in 10:
				burst("spark", c + Vector2(rng.randf_range(-60, 60), -rng.randf_range(0, 120)), 2, magic.lightened(0.3), Vector2(80, 260), Vector2(0.3, 0.7), Vector2(2, 3.5), 300.0, PI, -PI * 0.5, true)
			view.add_shake(16.0)
			view.zoom_punch(0.06)


func ability_cast(ability: String, x: float, side: int, race: StringName = &"human") -> void:
	# A beacon at the caster's base marks the call (the effect itself arrives with the pulses).
	var dir := 1.0 if side == 0 else -1.0
	var magic: Color = RaceLook.look(race).glow
	if ability in ["starfall", "cannonade"]:
		flash(Vector2(view.sim.to_world(side, 0.0) + dir * 60.0, GROUND_Y - 200), 90, Color(magic, 0.5), 0.35)
	if ability == "starfall":
		ring(Vector2(x, GROUND_Y - 20), 120, Color(magic, 0.7), 0.8, 4.0)


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
	var act: Array[Dictionary] = []
	for a in actors:
		if t - a.born > a.life:
			continue
		if a.has("vx"):
			a.x += a.vx * dt
			if a.kind == "beast" and rng.randf() < 0.3:
				_p({"kind": "smoke", "pos": Vector2(a.x, GROUND_Y), "vel": Vector2(-a.vx * 0.05, -20), "life": 0.6, "size": 10.0, "col": Color(0.7, 0.58, 0.42, 0.45), "g": 0.0, "add": false, "rot": 0.0, "spin": 0.0})
		act.append(a)
	actors = act
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	var t := now()
	for d in decals:
		var a: float = 1.0 - (t - d.born) / d.life
		UnitArt._ellipse(self, Vector2(d.x, GROUND_Y + 6), Vector2(d.w, 6), Color(0.08, 0.06, 0.05, 0.5 * a))
	for a in actors:
		_draw_actor(a, t)
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
			_:
				draw_circle(p.pos, p.size * (1.0 - u), Color(c, c.a * (1.0 - u)))
	for p in projectiles:
		var u: float = (t - p.born) / p.dur
		var pos := _proj_pos(p, u)
		var ahead := _proj_pos(p, minf(1.0, u + 0.04))
		var dirv := (ahead - pos).normalized()
		match p.kind:
			"arrow", "javelin":
				var l := 16.0 if p.kind == "arrow" else 22.0
				draw_line(pos - dirv * l, pos, Color("6b4a2b"), 2.0)
				draw_line(pos - dirv * l, pos - dirv * (l - 4) + dirv.orthogonal() * 3, Color(0.9, 0.9, 0.9), 1.5)
				draw_colored_polygon(PackedVector2Array([pos + dirv * 4, pos + dirv.orthogonal() * 2.5, pos - dirv.orthogonal() * 2.5]), Color("b5b9bf"))
			"stone":
				draw_circle(pos, 3.0, Color("7b7466"))
			"axe":
				# Spinning throwing axe.
				var a: float = (t - p.born) * 18.0
				var d := Vector2.RIGHT.rotated(a)
				draw_line(pos - d * 7, pos + d * 7, Color("6b4a2b"), 2.0)
				draw_colored_polygon(PackedVector2Array([pos + d * 7, pos + d * 7 + d.orthogonal() * 6, pos + d * 3 + d.orthogonal() * 6]), Color("b5b9bf"))
			"orb":
				draw_circle(pos, 4.5, Color(1, 1, 1, 0.9))
			"ball":
				draw_circle(pos, 5.5, Color(0.1, 0.1, 0.1))
			"shell":
				draw_circle(pos, 5.0, Color(0.2, 0.2, 0.18))
			"bullet", "tracer":
				pass
			"bolt":
				pass


func _draw_actor(a: Dictionary, t: float) -> void:
	var u: float = (t - a.born) / a.life
	match a.kind:
		"beast":
			var dir := signf(a.vx)
			UnitArt.begin(self, Transform2D(0.0, Vector2(dir * 0.9, 0.9), 0.0, Vector2(a.x, a.y)))
			UnitArt.quadruped(self, a.get("beast", "boar"), Color("5b4130"), {"moving": true, "walk": t * 26.0 + a.y, "t": t}, 0)
			draw_set_transform(Vector2.ZERO)
		"dome":
			var c: Color = a.col.lightened(0.5)
			var fade := minf(1.0, (1.0 - u) * 6.0)
			var cx: float = (a.lo + a.hi) * 0.5
			var rx: float = (a.hi - a.lo) * 0.5
			var pts := PackedVector2Array()
			for i in 25:
				var ang := PI + PI * i / 24.0
				pts.append(Vector2(cx + cos(ang) * rx, GROUND_Y + sin(ang) * 110.0))
			draw_colored_polygon(pts, Color(c, 0.08 * fade))
			draw_polyline(pts, Color(c, 0.55 * fade), 2.0)
		"beam":
			pass


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
			"fire":
				glow.draw_circle(p.pos, p.size * (1.0 - u * 0.6), Color(c, 0.8 * (1.0 - u)))
			_:
				glow.draw_circle(p.pos, p.size * (1.0 - u), Color(c, c.a * (1.0 - u)))
	for p in projectiles:
		var u: float = (t - p.born) / p.dur
		var pos := _proj_pos(p, u)
		var back := _proj_pos(p, maxf(0.0, u - 0.08))
		match p.kind:
			"bullet", "tracer":
				glow.draw_line(back, pos, Color(1.0, 0.85, 0.5, 0.9), 2.0)
			"bolt":
				var c: Color = p.get("col", Color("37e7ff"))
				glow.draw_line(back, pos, Color(c, 0.9), 4.0)
				glow.draw_circle(pos, 6.0, Color(c, 0.6))
			"shell", "ball":
				glow.draw_circle(pos, 8.0, Color(1.0, 0.6, 0.3, 0.25))
			"orb":
				var c: Color = p.get("col", Color("9fe4ff"))
				glow.draw_line(back, pos, Color(c, 0.6), 6.0)
				glow.draw_circle(pos, 10.0, Color(c, 0.55))
	for a in actors:
		if a.kind == "beam":
			var u: float = (t - a.born) / a.life
			var c: Color = a.col.lightened(0.6)
			var w: float = a.w * (1.0 - u * 0.7)
			glow.draw_rect(Rect2(a.x - w * 0.5, -600, w, GROUND_Y + 600), Color(c, 0.35 * (1.0 - u)))
			glow.draw_rect(Rect2(a.x - w * 0.18, -600, w * 0.36, GROUND_Y + 600), Color(1, 1, 1, 0.8 * (1.0 - u)))
	# Telegraphs for pending abilities (GDD §13.4: ground decal before every ability).
	for e in view.sim.effects:
		var def: AbilityDef = e.def
		if e.pulse > 0 and not def.sweep:
			continue
		var c := view.team_color(e.side).lightened(0.4)
		var pulse := 0.5 + 0.5 * sin(t * 18.0)
		var lo: float = e.center - def.width * 0.5
		glow.draw_rect(Rect2(lo, GROUND_Y - 4, def.width, 14), Color(c, 0.25 + 0.2 * pulse))
		if def.id == &"starfall":
			glow.draw_arc(Vector2(e.center, GROUND_Y), 40.0 + 20.0 * pulse, 0, TAU, 40, Color(c, 0.8), 2.0)
			glow.draw_line(Vector2(e.center, -400), Vector2(e.center, GROUND_Y), Color(c, 0.35 * pulse), 2.0)
