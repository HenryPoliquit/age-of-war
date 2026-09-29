class_name TowerArt
extends RefCounted
## Turret towers per race and age (BaseArt places them on the ground in front of the gate). Feet at
## the origin, up is −y, the turret sits at (0, −h). Every piece is ink-outlined and shaded, with a
## few props per tower (lanterns, braziers, banners, moss, rocks) so they hold up next to the units.
##   Humans: lashed lookout → temple plinth → Roman watchtower → stone tower → earthwork bastion → arcane pylon
##   Elves (grown or woven from nature): standing stone and nest → wicker tower → braided roots →
##          vine-bound column → great flower → crystal bloom
##   Dwarves: stone cairn → copper-banded tower with a carved face → iron-banded keep → bannered keep →
##          steam tower → rune tower

const INK := Color(0.09, 0.07, 0.06, 0.9)

static var _t := 0.0
static var _dim := 0.0


static func draw(ci: CanvasItem, race: StringName, age: int, h: float, team: Color, t: float, dim := 0.0) -> void:
	_t = t
	_dim = dim
	Arch.yaw = UnitArt.view_yaw
	var glow: Color = RaceLook.look(race).glow
	var tm := team.darkened(dim)
	FkPaint.ellipse(ci, Vector2(0, 2), Vector2(26, 5), Color(0, 0, 0, 0.32))
	match race:
		&"elf":
			_elf(ci, age, h, tm, glow)
		&"dwarf":
			_dwarf(ci, age, h, tm, glow)
		_:
			_human(ci, age, h, tm, glow)


# ---------------------------------------------------------------------------
# Helpers

static func _d(col: Color) -> Color:
	return col.darkened(_dim)


## Shaded polygon with an ink outline.
static func _shape(ci: CanvasItem, pts: Array, col: Color, ink := 1.1) -> void:
	FkPaint.shade_poly(ci, pts, _d(col))
	if ink > 0.0:
		var p := PackedVector2Array(pts)
		p.append(pts[0])
		ci.draw_polyline(p, INK, ink)


static func _rect(r: Rect2) -> Array:
	return [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]


static func _oval(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, ink := 1.0, rot := 0.0) -> void:
	_shape(ci, FkPaint.ellipse_pts(c, r, rot, 12), col, ink)


## Lit edge along the top-left of a form.
static func _rim(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 1.2) -> void:
	ci.draw_line(a, b, Color(_d(col).lightened(0.35), 0.8), w)


## Stone blocks with per-block tone, drawn inside a rect.
static func _blocks(ci: CanvasItem, r: Rect2, col: Color, course := 7.0, block := 11.0) -> void:
	_shape(ci, _rect(r), col)
	var rows := int(r.size.y / course)
	for row in rows:
		var y := r.position.y + row * course
		var off := block * 0.5 if row % 2 == 1 else 0.0
		var x := r.position.x - off
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + block, r.end.x)
			var k := fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0) - 0.5
			ci.draw_rect(Rect2(x0 + 0.6, y + 0.6, x1 - x0 - 1.2, course - 1.2), Color(_d(col).lightened(0.12) if k > 0 else _d(col).darkened(0.12), absf(k) * 0.9))
			ci.draw_line(Vector2(x1, y), Vector2(x1, y + course), Color(0, 0, 0, 0.3), 0.8)
			x += block
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.32), 0.9)
	_rim(ci, r.position, Vector2(r.end.x, r.position.y), col)


static func _tufts(ci: CanvasItem, xs: Array, col: Color) -> void:
	for x: float in xs:
		for k in 3:
			ci.draw_line(Vector2(x + k * 1.5, 1), Vector2(x - 2 + k * 2.5, -5 - (k % 2) * 3), _d(col).lightened(0.06 * k), 1.2)


static func _rock(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_shape(ci, [c + Vector2(-r, 0), c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.2, -r), c + Vector2(r, -r * 0.4), c + Vector2(r * 0.9, 0)], col, 0.9)


static func _moss(ci: CanvasItem, c: Vector2, r: Vector2, col := Color("5f7f3a")) -> void:
	FkPaint.ellipse(ci, c, r, _d(col))
	for k in 3:
		ci.draw_circle(c + Vector2(-r.x * 0.5 + k * r.x * 0.5, -r.y * 0.4), r.y * 0.45, _d(col).lightened(0.12))


static func _lantern(ci: CanvasItem, hook: Vector2, col: Color, frame := Color("3a2c20")) -> void:
	var k := 0.8 + 0.2 * sin(_t * 3.0 + hook.x)
	var p := hook + Vector2(0, 5)
	ci.draw_line(hook, p + Vector2(0, -3), _d(frame), 0.8)
	ci.draw_circle(p, 7.0, Color(col, (0.12 + 0.3 * BaseArt.night) * k))
	_shape(ci, [p + Vector2(-2.5, -3), p + Vector2(2.5, -3), p + Vector2(3, 3), p + Vector2(-3, 3)], col.lerp(Color.WHITE, 0.2), 0.8)
	ci.draw_line(p + Vector2(-3, -3), p + Vector2(3, -3), _d(frame), 1.2)


static func _flame(ci: CanvasItem, base: Vector2, s := 1.0, col := Color(1.0, 0.6, 0.25)) -> void:
	var fl := 0.75 + 0.25 * sin(_t * 12.0 + base.x * 3.0)
	ci.draw_circle(base + Vector2(0, -3 * s), 9.0 * s, Color(col, 0.14 + 0.25 * BaseArt.night))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0) * s, base + Vector2(3, 0) * s, base + Vector2(0.5, -9 * fl) * s]), col)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-1.5, 0) * s, base + Vector2(1.5, 0) * s, base + Vector2(0, -5 * fl) * s]), Color(1.0, 0.92, 0.6))


static func _brazier(ci: CanvasItem, p: Vector2, col := Color(1.0, 0.6, 0.25)) -> void:
	_shape(ci, [p + Vector2(-5, -4), p + Vector2(5, -4), p + Vector2(3, 1), p + Vector2(-3, 1)], Color("3a3a3e"), 0.8)
	_flame(ci, p + Vector2(0, -4), 0.8, col)


## A pennant on a short pole, flapping.
static func _pennant(ci: CanvasItem, foot: Vector2, team: Color, len := 16.0) -> void:
	var top := foot + Vector2(0, -len)
	ci.draw_line(foot, top, _d(Color("3b2c20")), 1.4)
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(top + Vector2(i * 2.6, sin(_t * 4.0 - i * 0.8) * 0.7 * i))
	pts.append(top + Vector2(12, 3 + sin(_t * 4.0 - 3.2) * 2.0))
	for i in range(4, -1, -1):
		pts.append(top + Vector2(i * 2.6, 6 + sin(_t * 4.0 - i * 0.8) * 0.7 * i))
	ci.draw_colored_polygon(pts, team)


## A hanging banner down a tower face with an emblem.
static func _banner(ci: CanvasItem, top: Vector2, w: float, len: float, team: Color, emblem: Color, notched := false) -> void:
	var sway := sin(_t * 1.6 + top.x) * 0.8
	var pts := [top + Vector2(-w, 0), top + Vector2(w, 0), top + Vector2(w + sway, len)]
	if notched:
		pts += [top + Vector2(sway, len - 5)]
	else:
		pts += [top + Vector2(sway, len + 4)]
	pts += [top + Vector2(-w + sway, len)]
	_shape(ci, pts, team, 0.9)
	ci.draw_line(top + Vector2(-w - 1, 0), top + Vector2(w + 1, 0), _d(Color("3b2c20")), 1.6)
	ci.draw_circle(top + Vector2(sway * 0.5, len * 0.45), w * 0.45, emblem)


# ---------------------------------------------------------------------------
# Humans

static func _human(ci: CanvasItem, age: int, h: float, tm: Color, glow: Color) -> void:
	var wood := Color("6b4a2b")
	var gold := Color("d9b25c")
	match age:
		1:
			# Lashed lookout in three dimensions: four tapered posts, cross braces, a plank platform with a rail, a hide
			# draped over the front, a torch and an antler totem.
			_rock(ci, Vector2(-15, 0), 6.0, Color("8a7a66"))
			_rock(ci, Vector2(16, 0), 5.0, Color("7a6a58"))
			for z in [-8.0, 8.0]:
				for x in [-12.0, 12.0]:
					Arch.prism(ci, [Vector2(x - 2, 0), Vector2(x * 0.8 - 1.5, -h), Vector2(x * 0.8 + 1.5, -h), Vector2(x + 2, 0)], z - 2, z + 2, _d(wood), INK, 0.8)
			Arch.on_front(ci, 10.0, func() -> void:
				ci.draw_line(Vector2(-11, -5), Vector2(9, -h + 7), _d(wood.darkened(0.15)), 2.2)
				ci.draw_line(Vector2(11, -5), Vector2(-9, -h + 7), _d(wood.darkened(0.15)), 2.2)
				for y in [-5.0, -h + 7]:
					for x in [-11.0, 10.0]:
						ci.draw_line(Vector2(x - 1.5, y - 1.5), Vector2(x + 1.5, y + 1.5), _d(Color("c9b28a")), 1.4))
			Arch.box(ci, -17, 17, -h - 4, -h + 2, -13, 13, _d(wood.lightened(0.1)),
				func(r: Rect2) -> void:
					for k in 5:
						ci.draw_line(Vector2(-17 + k * 7, -h - 4), Vector2(-17 + k * 7, -h + 2), Color(0, 0, 0, 0.35), 0.8), Callable(), false, INK, 1.0)
			Arch.on_front(ci, 13.0, func() -> void:
				# Hide draped over the rail, and the torch beyond it.
				_shape(ci, [Vector2(-15, -h + 2), Vector2(-3, -h + 2), Vector2(-5, -h + 13), Vector2(-9, -h + 10), Vector2(-13, -h + 14)], Color("9a7048"), 0.9)
				ci.draw_line(Vector2(15, -h + 2), Vector2(15, -h - 12), _d(wood), 1.6)
				_flame(ci, Vector2(15, -h - 12), 0.9)
				ci.draw_polyline(PackedVector2Array([Vector2(-14, -h - 4), Vector2(-18, -h - 11), Vector2(-17, -h - 15)]), _d(Color("e0d4b8")), 1.5)
				ci.draw_polyline(PackedVector2Array([Vector2(-14, -h - 4), Vector2(-11, -h - 11), Vector2(-12, -h - 15)]), _d(Color("e0d4b8")), 1.5))
			_tufts(ci, [-22.0, 4.0, 21.0], Color("7a7a3a"))
		2:
			# Temple plinth in three dimensions: stepped base, a marble shaft between two fluted pilaster columns, a bronze
			# boss, a gilt cornice with dentils under a top slab, a braziers on the ground.
			var marble := Color("e6dcc4")
			Arch.box(ci, -20, 20, -5, 0, -18, 18, _d(marble.darkened(0.12)), Callable(), Callable(), false, INK, 0.9)
			Arch.box(ci, -17, 17, -9, -5, -15, 15, _d(marble.darkened(0.06)), Callable(), Callable(), false, INK, 0.9)
			Arch.box(ci, -14, 14, -h + 6, -9, -11, 11, _d(marble), Callable(), Callable(), false, INK, 0.9)
			for x in [-10.0, 10.0]:
				Arch.cylinder(ci, x, 13.0, 2.6, -h + 6, -9, _d(marble.lightened(0.05)), 0.0, 12.0, 2)
			Arch.on_front(ci, 11.0, func() -> void:
				_oval(ci, Vector2(0, -h * 0.5), Vector2(5.5, 5.5), Color("b07a3a"))
				ci.draw_circle(Vector2(-1.5, -h * 0.5 - 1.5), 1.8, _d(Color("f0d090")))
				ci.draw_arc(Vector2(0, -h + 14), 7.0, 0.3, PI - 0.3, 10, tm, 1.6))
			Arch.box(ci, -18, 18, -h + 1, -h + 6, -14, 14, _d(Color("c9a060")),
				func(r: Rect2) -> void:
					for k in 8:
						ci.draw_rect(Rect2(-17 + k * 4.4, -h + 4, 2.2, 2), Color(0, 0, 0, 0.3)), Callable(), false, INK, 0.9)
			Arch.box(ci, -17, 17, -h - 3, -h + 1, -13, 13, _d(marble.darkened(0.04)), Callable(), Callable(), false, INK, 0.9)
			_brazier(ci, Vector2(-27, -9))
			_tufts(ci, [18.0, 24.0], Color("8a8a4a"))
		3:
			# Roman watchtower in three dimensions: a tufa base with an arched door, a timber frame of four posts with cross
			# braces, a tiled skirt under a top slab, a legion shield and a torch.
			var tufa := Color("c2b08e")
			Arch.box(ci, -16, 16, -h * 0.45, 0, -14, 14, _d(tufa),
				func(r: Rect2) -> void: _blocks(ci, r, tufa),
				func(r: Rect2) -> void: _blocks(ci, r, Arch.end_col(tufa)), false, INK, 1.0)
			Arch.recess(ci, Arch.arch_pts(-5, 5, 0, -9, 4), 14.0, 5.0, _d(tufa.darkened(0.4)), Color(0.12, 0.09, 0.07))
			for z in [-11.0, 11.0]:
				for x in [-14.0, 14.0]:
					Arch.box(ci, x - 1.8, x + 1.8, -h + 2, -h * 0.45, z - 1.8, z + 1.8, _d(wood), Callable(), Callable(), false, INK, 0.8)
			Arch.on_front(ci, 13.0, func() -> void:
				ci.draw_line(Vector2(-13, -h * 0.45), Vector2(13, -h + 4), _d(wood.darkened(0.2)), 2.2)
				ci.draw_line(Vector2(13, -h * 0.45), Vector2(-13, -h + 4), _d(wood.darkened(0.25)), 2.2)
				_shape(ci, [Vector2(-5, -h * 0.66), Vector2(5, -h * 0.66), Vector2(5.5, -h * 0.4), Vector2(-5.5, -h * 0.4)], tm, 0.9)
				ci.draw_circle(Vector2(0, -h * 0.53), 1.6, _d(gold))
				ci.draw_line(Vector2(16, -h * 0.35), Vector2(20, -h * 0.4), _d(wood), 1.4)
				_flame(ci, Vector2(20, -h * 0.4), 0.7))
			Arch.prism(ci, [Vector2(-21, -h + 1), Vector2(21, -h + 1), Vector2(17, -h + 7), Vector2(-17, -h + 7)], -16, 16, _d(Color("b0583a")), INK, 0.9)
			Arch.on_front(ci, 16.0, func() -> void:
				for k in 7:
					ci.draw_line(Vector2(-19 + k * 6, -h + 1), Vector2(-16 + k * 5.4, -h + 7), Color(0, 0, 0, 0.3), 0.8))
			Arch.box(ci, -17, 17, -h - 3, -h + 1, -13, 13, _d(wood.lightened(0.1)), Callable(), Callable(), false, INK, 0.9)
			_tufts(ci, [-20.0, 19.0], Color("6a7a3a"))
		4:
			# Stone tower in three dimensions: a square shaft, a machicolation ledge under crenellations, a recessed
			# arrow slit, hoarding brackets, a hanging banner and ivy, seen through the units' camera.
			var stone := Color("8d8e8a")
			_rock(ci, Vector2(-27, 0), 5.0, stone.darkened(0.15))
			Arch.box(ci, -17, 17, -h + 2, 0, -15, 15, _d(stone),
				func(r: Rect2) -> void: _blocks(ci, r, stone),
				func(r: Rect2) -> void: _blocks(ci, r, Arch.end_col(stone), 7.0, 8.0), false, INK)
			Arch.box(ci, -19, 19, -h + 1, -h + 4, -17, 17, _d(stone.darkened(0.2)), Callable(), Callable(), false, INK, 0.9)
			Arch.crenellate(ci, -19, 19, -17, 17, -h + 1, 7, 10, 14, _d(stone.darkened(0.05)), 4, INK)
			Arch.on_front(ci, 17.0, func() -> void:
				for x in [-15.0, -5.0, 5.0, 15.0]:
					ci.draw_line(Vector2(x, -h + 4), Vector2(x, -h + 8), _d(Color("3a2c20")), 1.4))
			Arch.recess(ci, Arch.rect_pts(-1.5, -h * 0.72, 1.5, -h * 0.72 + 9.0), 15.0, 4.0, _d(stone.darkened(0.4)), Color(0.06, 0.05, 0.05))
			Arch.on_front(ci, 15.0, func() -> void:
				_banner(ci, Vector2(0, -h * 0.55), 6.0, h * 0.35, tm, _d(gold))
				for k in 6:
					FkPaint.ellipse(ci, Vector2(-15 + (k % 2) * 3, -4 - k * 5), Vector2(3.5, 2.2), _d(Color("3e6a36")), 0.4))
			_tufts(ci, [-10.0, 20.0], Color("5a7a3a"))
		5:
			# Earthwork bastion in three dimensions: a sloped earth frustum with quoins, a brick cap with sandbags, gabion
			# baskets and barrels at the foot, a hanging banner and a lantern post.
			var earth := Color("8a7b66")
			Arch.frustum(ci, -24, 24, -16, 16, -16, 16, -10, 10, -h + 9, _d(earth), INK, 1.0)
			Arch.on_front(ci, 14.0, func() -> void:
				for r in 4:
					ci.draw_line(Vector2(-22 + r * 2, -6 - r * (h - 14) / 4.0), Vector2(22 - r * 2, -6 - r * (h - 14) / 4.0), Color(0, 0, 0, 0.18), 0.9)
				for k in 4:
					_shape(ci, _rect(Rect2(-23 + k * 2.2, -8 - k * 9, 6, 5)), Color("b0a490"), 0.7)
					_shape(ci, _rect(Rect2(17 - k * 2.2, -8 - k * 9, 6, 5)), Color("a0947e"), 0.7))
			Arch.box(ci, -18, 18, -h, -h + 9, -12, 12, _d(Color("8a5a44")),
				func(r: Rect2) -> void: _blocks(ci, r, Color("8a5a44"), 4.5, 7),
				func(r: Rect2) -> void: _blocks(ci, r, Arch.end_col(Color("8a5a44")), 4.5, 6), false, INK, 1.0)
			Arch.on_front(ci, 12.0, func() -> void:
				for k in 4:
					_oval(ci, Vector2(-12 + k * 8, -h - 1), Vector2(4.5, 2.5), Color("a89468"), 0.7))
			for x in [-32.0, 32.0]:
				Arch.box(ci, x - 6, x + 6, -14, 0, -6, 6, _d(Color("7a6a48")),
					func(r: Rect2) -> void:
						for k in 3:
							ci.draw_line(Vector2(r.position.x, -12 + k * 4.5), Vector2(r.end.x, -12 + k * 4.5), _d(Color("a88a5a")), 0.9), Callable(), false, INK, 1.0)
			Arch.on_front(ci, 16.0, func() -> void:
				_oval(ci, Vector2(-10, -4), Vector2(3.5, 4), Color("5a3a22"), 0.8)
				ci.draw_line(Vector2(-13.5, -4), Vector2(-6.5, -4), _d(Color("3a3a3a")), 0.8))
			Arch.on_front(ci, 14.0, func() -> void:
				_banner(ci, Vector2(0, -h * 0.75), 5.0, h * 0.3, tm, _d(Color("e6e2d6")))
				ci.draw_line(Vector2(21, -h + 9), Vector2(21, -h - 6), _d(Color("3a3a3e")), 1.4)
				_lantern(ci, Vector2(21, -h - 6), Color(1.0, 0.85, 0.5)))
		_:
			# Arcane pylon in three dimensions: a tapering violet-stone body on a plinth, brass rings, a crystal core, a
			# brass capstone, orbiting runestones.
			var stone := Color("6e6582")
			var brass := Color("c9a45c")
			Arch.box(ci, -16, 16, -6, 0, -16, 16, _d(stone.darkened(0.15)), Callable(), Callable(), false, INK, 1.0)
			FkPaint.push(ci, Transform2D(0.0, Vector2(0, -6)))
			Arch.frustum(ci, -13, 13, -9, 9, -13, 13, -9, 9, -(h - 10), _d(stone), INK, 1.0)
			for k in 3:
				var y := -6.0 - k * (h - 22) / 2.0
				var w := lerpf(12.5, 9.5, float(k) / 2.0)
				Arch.box(ci, -w - 1, w + 1, y - 1.5, y + 1.5, -w - 1, w + 1, _d(brass), Callable(), Callable(), false, INK, 0.8)
			FkPaint.pop(ci)
			var k := 0.6 + 0.4 * sin(_t * 2.2)
			Arch.on_front(ci, 9.0, func() -> void:
				ci.draw_rect(Rect2(-7, -h * 0.72, 14, h * 0.34), Color(glow, 0.12 * k))
				_shape(ci, [Vector2(0, -h * 0.72), Vector2(3.5, -h * 0.55), Vector2(0, -h * 0.38), Vector2(-3.5, -h * 0.55)], glow.lerp(Color.WHITE, 0.3), 0.8)
				for s2 in [-1.0, 1.0]:
					ci.draw_arc(Vector2(s2 * 6, -h * 0.25), 4.0, 0, PI, 8, _d(brass), 1.0))
			FkPaint.push(ci, Transform2D(0.0, Vector2(0, -h + 4)))
			Arch.frustum(ci, -15, 15, -12, 12, -15, 15, -12, 12, -6, _d(brass), INK, 1.0)
			FkPaint.pop(ci)
			for n in 3:
				var a := _t * 0.9 + n * TAU / 3.0
				var p := Vector2(cos(a) * 22.0, -h * 0.55 + sin(a) * 6.0)
				if sin(a) > 0.0:
					_shape(ci, [p + Vector2(-2.5, 3), p + Vector2(-2.5, -3), p + Vector2(0, -5), p + Vector2(2.5, -3), p + Vector2(2.5, 3)], stone.lightened(0.1), 0.7)
					ci.draw_line(p + Vector2(0, -2), p + Vector2(0, 2), Color(glow, 0.9), 1.0)
			Arch.on_front(ci, 10.0, func() -> void: ci.draw_rect(Rect2(-7, -h * 0.24, 14, 7), tm))


# ---------------------------------------------------------------------------
# Elves: grown or woven from nature

## A solid of revolution with the towers' ink outline (see Arch.lathe).
static func _lathe(ci: CanvasItem, profile: Array, col: Color, grain := 0, cx := 0.0, cz := 0.0) -> void:
	Arch.lathe(ci, cx, cz, profile, _d(col), grain, 14, INK, 1.1)


## A rock as an extruded silhouette.
static func _rock3(ci: CanvasItem, c: Vector2, r: float, col: Color, z0: float, z1: float) -> void:
	Arch.prism(ci, [c + Vector2(-r, 0), c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.2, -r), c + Vector2(r, -r * 0.4), c + Vector2(r * 0.9, 0)], z0, z1, _d(col), INK, 0.9)


## A leaf (an oval) standing at rig point (x, y, z).
static func _leaf3(ci: CanvasItem, x: float, y: float, z: float, r: Vector2, col: Color, rot := 0.0) -> void:
	_oval(ci, Arch.pt(x, y, z), r, col, 0.7, rot)


## A ring of `n` leaves round the vertical axis at radius `r` and height `y`, the half behind (back) or in front of the
## column. Drawn twice around the column so the leaves cross it.
static func _leaf_ring(ci: CanvasItem, y: float, r: float, n: int, size: Vector2, col: Color, back: bool, phase := 0.0) -> void:
	for i in n:
		var th := phase + TAU * i / n
		var z := r * cos(th)
		if (z < 0.0) != back:
			continue
		var x := r * sin(th)
		_leaf3(ci, x, y, z, size, col.lightened(0.04 * (i % 2)), -0.3 * sin(th))


## Small leaves and flowers along a helix, on its near half.
static func _vine(ci: CanvasItem, r: float, y_top: float, y_bottom: float, turns: float, phase: float, leaf: Color, flower := Color(0, 0, 0, 0)) -> void:
	Arch.helix(ci, 0, 0, r, y_top, y_bottom, turns, phase, _d(leaf.darkened(0.2)), 1.7)
	var steps := int(turns * 5.0)
	for i in steps:
		var th := phase + TAU * turns * (i + 0.5) / steps
		if cos(th) <= 0.1:
			continue
		var p := Vector2(Arch.cylinder_x(0, 0) + r * sin(th), lerpf(y_bottom, y_top, (i + 0.5) / steps))
		_oval(ci, p + Vector2(2.5, 0), Vector2(3.4, 1.7), leaf.lightened(0.1), 0.6, 0.5)
		if flower.a > 0.0 and i % 3 == 0:
			ci.draw_circle(p + Vector2(-2, -1), 1.6, _d(flower))


static var _braids := {}
const _QUAD_UV := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]


## The pieces of the three braided strands of the Iron-age elf tower, [{ink, col (screen quads), depth, strand, shade}]
## sorted back to front by camera depth so the strands really pass over and under each other. Each piece is a quad
## between mitred joints, so neighbouring pieces meet edge to edge with no notches. Cached per height and camera.
static func _braid(h: float) -> Array:
	var key := "%s_%s" % [h, snappedf(Arch.yaw, 0.001)]
	if _braids.has(key):
		return _braids[key]
	var out: Array = []
	for strand in 3:
		var w := 8.0 - strand * 0.5
		var pts: Array = []
		var deps: Array = []
		for n in 41:
			var u := n / 40.0
			var spread := lerpf(17.0, 6.0, sin(u * PI) * 0.9 + u * 0.1)
			var ph := u * 9.0 + strand * TAU / 3.0
			var c := Vector3(sin(ph) * spread, -u * h, cos(ph) * spread)
			pts.append(Arch.pt(c.x, c.y, c.z))
			deps.append(c.z * cos(Arch.yaw) + c.x * sin(Arch.yaw))
		# A normal at each joint: at right angles to the mean of the two directions, its length stretched to keep the width.
		var normals: Array = []
		var stretch: Array = []
		for i in pts.size():
			var d0: Vector2 = (pts[i] - pts[maxi(i - 1, 0)]).normalized()
			var d1: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[i]).normalized()
			var m := (d0 + d1).normalized()
			var nrm := Vector2(-m.y, m.x)
			normals.append(nrm)
			stretch.append(1.0 / maxf(0.5, nrm.dot(Vector2(-d1.y, d1.x))))
		for i in pts.size() - 1:
			var dir: Vector2 = (pts[i + 1] - pts[i]).normalized()
			var quad := func(hw: float, ext: float) -> PackedVector2Array:
				var a: Vector2 = pts[i] - dir * ext
				var b: Vector2 = pts[i + 1] + dir * ext
				return PackedVector2Array([a + normals[i] * hw * stretch[i], b + normals[i + 1] * hw * stretch[i + 1], b - normals[i + 1] * hw * stretch[i + 1], a - normals[i] * hw * stretch[i]])
			var depth: float = (deps[i] + deps[i + 1]) * 0.5
			out.append({"ink": quad.call(w * 0.5, 0.0), "col": quad.call(w * 0.5 - 0.9, 0.5), "depth": depth, "strand": strand, "shade": clampf(depth / 17.0, -1.0, 1.0)})
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.depth < q.depth)
	_braids[key] = out
	return out


static func _elf(ci: CanvasItem, age: int, h: float, tm: Color, glow: Color) -> void:
	var moss := Color("5f7f3a")
	var leaf := Color("4f7a3a")
	var wicker := Color("b08e5a")
	var stone := Color("9a968a")
	var gold := Color("d9b25c")
	var bark := Color("6e5236")
	match age:
		1:
			# Mossy standing stone lashed with vines, a spiral carving, a twig nest with a feather: the stone a slab with
			# thickness, the nest a woven bowl.
			_lathe(ci, [[-9.0, 18.0], [0.0, 21.0]], stone.darkened(0.1))
			_rock3(ci, Vector2(-18, 0), 6.0, stone.darkened(0.12), -6.0, 6.0)
			Arch.prism(ci, [Vector2(-12, -8), Vector2(-11, -h + 12), Vector2(-5, -h + 5), Vector2(7, -h + 7), Vector2(12, -h + 16), Vector2(12, -8)], -8.0, 9.0, _d(stone), INK, 1.1)
			Arch.on_front(ci, 9.0, func() -> void:
				_rim(ci, Vector2(-11, -h + 12), Vector2(-5, -h + 5), stone)
				for k in 10:
					var p := Vector2(-9 + fposmod(k * 7.3, 18.0), -12 - fposmod(k * 11.7, h - 22))
					ci.draw_circle(p, 0.8, _d(Color("c8c4a0")))
				var spiral := PackedVector2Array()
				for n in 16:
					var a := n * 0.7
					spiral.append(Vector2(1, -h * 0.5) + Vector2(cos(a), sin(a)) * (0.4 * n))
				ci.draw_polyline(spiral, Color(0, 0, 0, 0.35), 0.9)
				for p in [Vector2(-8, -h + 14), Vector2(8, -h * 0.35), Vector2(-6, -14)]:
					_moss(ci, p, Vector2(6, 3), moss))
			_vine(ci, 13.5, -h + 12, -8.0, 2.0, 0.6, leaf)
			var bowl := [[-h - 2.0, 17.0], [-h, 18.5], [-h + 3.0, 17.5], [-h + 6.0, 13.0], [-h + 9.0, 7.0]]
			_lathe(ci, bowl, wicker.darkened(0.05))
			var bowl_r := func(y: float) -> float:
				return lerpf(18.5, 8.0, clampf((y + h) / 9.0, 0.0, 1.0)) + 0.4
			Arch.helix(ci, 0, 0, 18.0, -h + 8, -h - 1, 2.4, 0.0, _d(wicker.lightened(0.16)), 1.3, bowl_r)
			Arch.helix(ci, 0, 0, 18.0, -h + 8, -h - 1, 2.4, PI, _d(wicker.darkened(0.25)), 1.3, bowl_r)
			# Twigs sticking out of the rim.
			for i in 8:
				var th := 0.4 + TAU * i / 8.0
				var from := Arch.pt(18.0 * sin(th), -h - 1.0, 18.0 * cos(th))
				ci.draw_line(from, from + Vector2(5.0 * sin(th) * cos(Arch.yaw) - 5.0 * cos(th) * sin(Arch.yaw), -1.5 - 2.0 * (i % 2)), _d(wicker.lightened(0.1 * (i % 3))), 1.3)
			Arch.on_front(ci, 9.0, func() -> void:
				ci.draw_line(Vector2(12, -h - 1), Vector2(19, -h - 7), _d(Color("f0ece0")), 1.6)
				_ferns(ci, [-20.0, 19.0], leaf)
				_mushrooms(ci, [Vector2(14, 0), Vector2(17, 0)], Color("c86a4a")))
		2:
			# Wicker tower: staves woven over and under round a cone, a layered leaf collar all the way round, flowers, a reed lantern.
			_leaf_ring(ci, -h + 1.0, 16.0, 12, Vector2(6.5, 2.8), leaf, true)
			_lathe(ci, [[-h, 11.0], [0.0, 17.0]], wicker, 5)
			var rows := int(h / 4.0)
			for r in rows:
				var y := -2.0 - r * 4.0
				var w := lerpf(17.0, 11.0, -y / h) - 0.4
				for n in 6:
					var u0 := sin(lerpf(-PI * 0.46, PI * 0.46, n / 6.0))
					var u1 := sin(lerpf(-PI * 0.46, PI * 0.46, (n + 1) / 6.0))
					var over := (n + r) % 2 == 0
					ci.draw_line(Vector2(u0 * w, y - 1.2), Vector2(u1 * w, y - 1.2), _d(wicker.lightened(0.14) if over else wicker.darkened(0.2)), 2.4)
			_leaf_ring(ci, -h + 1.0, 16.0, 12, Vector2(6.5, 2.8), leaf, false)
			_leaf_ring(ci, -h - 1.0, 12.0, 10, Vector2(5.5, 2.4), leaf.lightened(0.08), false, 0.3)
			for p in [Vector2(-9, -h + 4), Vector2(6, -h + 5), Vector2(14, -h + 3)]:
				var c := Arch.pt(p.x, p.y, sqrt(maxf(0.0, 17.0 * 17.0 - p.x * p.x)))
				ci.draw_circle(c, 1.8, _d(Color("f2d8e6")))
				ci.draw_circle(c, 0.8, _d(Color("f2c94c")))
			_oval(ci, Vector2(0, -h), Vector2(16, 3.5), wicker.darkened(0.12), 0.8)
			_lantern(ci, Arch.pt(-15, -h * 0.55, 4), Color(1.0, 0.88, 0.55), wicker.darkened(0.3))
			for x in [-18.0, 18.0]:
				_moss(ci, Arch.pt(x, -2, 6), Vector2(7, 3.5), moss)
			Arch.on_front(ci, 8.0, func() -> void:
				_ferns(ci, [22.0], leaf))
		3:
			# Braided living roots: three strands that really wind round each other (each segment drawn in camera depth
			# order), cupping a mossy bowl; glowing fungi, hanging moss, a lantern.
			for x in [-22.0, -13.0, 14.0, 24.0]:
				ci.draw_line(Arch.pt(x * 0.4, -6, 0), Arch.pt(x, 1, 6 if x > 0 else -6), _d(bark.darkened(0.15)), 3.4)
			for sg in _braid(h):
				var col := _d(bark.darkened(0.12 * sg.strand).lightened(0.05 * sg.shade))
				ci.draw_primitive(sg.ink, PackedColorArray([INK, INK, INK, INK]), _QUAD_UV)
				ci.draw_primitive(sg.col, PackedColorArray([col, col, col, col]), _QUAD_UV)
			_lathe(ci, [[-h + 2.0, 17.0], [-h + 6.0, 15.0], [-h + 12.0, 7.0]], bark, 4)
			_oval(ci, Vector2(0, -h), Vector2(16, 4), moss, 0.8)
			for x in [-12.0, -4.0, 9.0]:
				ci.draw_line(Arch.pt(x, -h + 4, 12), Arch.pt(x + 0.5, -h + 11 + fposmod(x, 4.0), 12), _d(Color("7a9a50")), 1.4)
			for p in [Vector3(-15, -h + 4, 8), Vector3(16, -h + 6, 6), Vector3(-9, -h * 0.55, 10), Vector3(10, -h * 0.3, 10)]:
				_leaf3(ci, p.x, p.y, p.z, Vector2(5, 2.4), leaf, -0.6 if p.x < 0 else 0.6)
			for p in [Vector3(8, -h * 0.62, 12), Vector3(-7, -h * 0.2, 12), Vector3(4, -8, 14)]:
				var c := Arch.pt(p.x, p.y, p.z)
				ci.draw_circle(c, 3.5, Color(glow, 0.15 + 0.2 * BaseArt.night))
				_shape(ci, [c + Vector2(-2.5, 0), c + Vector2(0, -2), c + Vector2(2.5, 0)], Color("d8f0e0"), 0.6)
			_lantern(ci, Arch.pt(18, -h + 8, 4), Color(1.0, 0.88, 0.55), bark)
		4:
			# Vine-bound white column: fluting, gilded leaf capital, flowering vine, moon banner, leaf balcony.
			var white := Color("e8e4da")
			Arch.box(ci, -16, 16, -5, 0, -14, 14, _d(white.darkened(0.12)), Callable(), Callable(), false, INK, 1.0)
			_leaf_ring(ci, -h + 8.0, 9.5, 8, Vector2(5, 2.2), gold, true)
			_lathe(ci, [[-h + 8.0, 9.0], [-5.0, 13.0]], white, 3)
			Arch.on_front(ci, 0.0, func() -> void:
				_banner(ci, Vector2(0, -h * 0.72), 5.0, h * 0.34, tm, _d(Color("eef2f8")))
				ci.draw_arc(Vector2(0.5, -h * 0.72 + h * 0.34 * 0.45), 2.2, -1.2, 2.0, 8, _d(Color("3a4a7a")), 1.2))
			_vine(ci, 11.5, -h + 10, -8.0, 2.3, 0.4, leaf, Color("f4f0ff"))
			_leaf_ring(ci, -h + 8.0, 9.5, 8, Vector2(5, 2.2), gold, false)
			# A broad leaf balcony with veins.
			_lathe(ci, [[-h - 3.0, 14.0], [-h + 1.0, 24.0], [-h + 7.0, 15.0]], leaf.lightened(0.05))
			ci.draw_line(Vector2(-22, -h + 2), Vector2(22, -h + 2), _d(gold), 1.2)
			for x in [-14.0, -6.0, 6.0, 14.0]:
				ci.draw_line(Vector2(x * 0.6, -h + 2), Vector2(x, -h + 5.5), Color(0, 0, 0, 0.25), 0.8)
			Arch.on_front(ci, 10.0, func() -> void:
				_ferns(ci, [-19.0, 18.0], leaf))
		5:
			# Moon-mushroom: a pale stalk with a ring and shelf-fungus steps, a broad capped top with
			# glowing gills, spots, and a lantern hanging from the rim.
			var stalk := Color("e6e0cc")
			var cap := Color("b9c6e0")
			var rim_y := -h + 9.0
			_lathe(ci, [[-6.0, 19.0], [0.0, 21.0]], moss)
			_lathe(ci, [[-h + 10.0, 6.0], [-h * 0.5, 7.0], [-2.0, 11.0]], stalk, 3)
			# Skirt ring and three shelf fungi spiralling up the stalk.
			_lathe(ci, [[-h * 0.52, 10.0], [-h * 0.46, 12.0]], stalk.darkened(0.08))
			for n in 3:
				var side := -1.0 if n % 2 == 0 else 1.0
				var y := -12.0 - n * (h * 0.22)
				var c := Vector2(side * 9.0, y)
				Arch.prism(ci, [c + Vector2(-side * 2, 2), c + Vector2(side * 9, 1), c + Vector2(side * 7, -3), c + Vector2(-side * 1, -3)], -6.0, 6.0, _d(Color("c8a878")), INK, 0.8)
			# Cap: a broad dome whose flat top carries the turret; gills glow underneath.
			for n in 9:
				var x := -22.0 + n * 5.5
				ci.draw_line(Vector2(x * 0.3, rim_y - 1), Vector2(x, rim_y + 1.5), Color(glow, 0.35 + 0.35 * BaseArt.night), 1.2)
			_lathe(ci, [[-h - 2.0, 10.0], [-h + 1.0, 22.0], [rim_y, 28.0], [rim_y + 3.0, 16.0]], cap)
			for p in [Vector2(-17, -h + 3), Vector2(-7, -h), Vector2(15, -h + 2), Vector2(21, -h + 6), Vector2(-23, -h + 7)]:
				var rad := lerpf(22.0, 28.0, clampf((p.y + h - 1.0) / 8.0, 0.0, 1.0)) if p.y > -h + 1.0 else lerpf(10.0, 22.0, clampf((p.y + h + 2.0) / 3.0, 0.0, 1.0))
				ci.draw_circle(Arch.pt(p.x, p.y, sqrt(maxf(0.0, rad * rad - p.x * p.x))), 1.6, _d(Color("f2f4fa")))
			_lantern(ci, Arch.pt(22, rim_y + 2, 17), glow.lerp(Color.WHITE, 0.4), Color("6a6a7a"))
			var k := 0.6 + 0.4 * sin(_t * 2.0)
			for n in 4:
				var a := _t * 0.7 + n * TAU / 4.0
				ci.draw_circle(Arch.pt(cos(a) * 30.0, -h * 0.6 + sin(a) * 8.0, sin(a) * 30.0), 1.4, Color(glow, 0.7 * k))
			Arch.on_front(ci, 12.0, func() -> void:
				_mushrooms(ci, [Vector2(-16, -2), Vector2(-13, -1), Vector2(15, -2)], Color("b9c6e0"))
				_ferns(ci, [-21.0, 21.0], leaf))
		_:
			# Crystal spire: a hexagonal pillar grown from a mossy stone, flat-topped for the turret, with
			# smaller crystals at its foot, a moonsilver vine and a pulsing core.
			var crystal := Color("6fa4cc").lerp(glow, 0.25)
			var k := 0.6 + 0.4 * sin(_t * 1.8)
			var top := -h + 3.0
			_rock3(ci, Vector2(-14, 0), 8.0, stone.darkened(0.1), -8.0, 6.0)
			_rock3(ci, Vector2(13, 0), 7.0, stone.darkened(0.18), -10.0, 4.0)
			_lathe(ci, [[-8.0, 16.0], [0.0, 18.0]], stone)
			_moss(ci, Arch.pt(-8, -8, 12), Vector2(7, 2.5), moss)
			ci.draw_circle(Vector2(0, -h * 0.5), 22.0, Color(glow, 0.08 + 0.07 * k))
			# The shards at the foot, back to front.
			for i in [1, 3, 0, 2]:
				var sh: Array = [[-12.0, 26.0, -0.45, 8.0], [12.0, 22.0, 0.4, -2.0], [-6.0, 16.0, -0.15, 14.0], [7.0, 14.0, 0.2, 4.0]][i]
				var base := Vector2(sh[0], -6)
				var tip := base + Vector2(0, -float(sh[1])).rotated(float(sh[2]))
				var side := Vector2(3.5, 0).rotated(float(sh[2]))
				var pts := [base - side, tip - side * 0.5 + Vector2(0, 4).rotated(float(sh[2])), tip, tip + side * 0.5 + Vector2(0, 4).rotated(float(sh[2])), base + side]
				Arch.prism(ci, pts, float(sh[3]) - 6.0, float(sh[3]), _d(crystal), INK, 0.8)
				Arch.on_front(ci, float(sh[3]), func() -> void:
					ci.draw_colored_polygon(PackedVector2Array([base, tip, tip + side * 0.5 + Vector2(0, 4).rotated(float(sh[2])), base + side]), Color(_d(crystal).darkened(0.2), 0.8)))
			var pillar := [[top, 12.0], [top + 6.0, 8.0], [-8.0, 10.0]]
			Arch.faceted(ci, 0, 0, pillar, _d(crystal), 6, 0.0, INK, 1.0)
			var cx := Arch.cylinder_x(0, 0)
			ci.draw_rect(Rect2(cx - 2.5, top + 10, 5, -top - 22), Color(glow, 0.35 + 0.35 * k))
			ci.draw_line(Arch.pt(-5, -10, 8), Arch.pt(-5, top + 6, 8), Color(1, 1, 1, 0.55), 1.0)
			_shape(ci, FkPaint.ellipse_pts(Vector2(cx, top), Vector2(12.5, 3.2), 0.0, 12), crystal.lightened(0.2), 0.9)
			for y in [-h * 0.3, -h * 0.62]:
				var w := lerpf(10.0, 8.5, -y / h)
				Arch.faceted(ci, 0, 0, [[y - 2.0, w + 1.5], [y + 2.0, w + 1.0]], _d(gold), 6, 0.0, INK, 0.8)
				ci.draw_circle(Arch.pt(0, y, w + 1.0), 1.5, Color(glow, 0.9))
			for p in [Vector2(-7, -h * 0.45), Vector2(4, -h * 0.78), Vector2(-3, -h * 0.18)]:
				ci.draw_line(Arch.pt(p.x, p.y, 8), Arch.pt(p.x + 3, p.y - 6, 8), Color(1, 1, 1, 0.45), 0.9)
			for n in 3:
				var a := _t * 1.1 + n * TAU / 3.0
				if sin(a) > -0.3:
					var p := Arch.pt(cos(a) * 20.0, top + 14 + sin(a) * 5.0, sin(a) * 20.0)
					_shape(ci, [p + Vector2(0, -4), p + Vector2(2, 0), p + Vector2(0, 4), p + Vector2(-2, 0)], crystal.lightened(0.2), 0.6)
	# Team colour: a leaf-shaped ribbon tied round the tower.
	var ry := -h * 0.42
	Arch.on_front(ci, 9.0, func() -> void:
		_shape(ci, [Vector2(8, ry), Vector2(18, ry + 3), Vector2(24, ry + 10), Vector2(16, ry + 8), Vector2(8, ry + 5)], tm, 0.8))


static func _nest(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_oval(ci, c + Vector2(0, 2), Vector2(r, 5), col.darkened(0.15), 0.9)
	for n in 9:
		var x := -r + n * r / 4.0
		ci.draw_line(c + Vector2(x - 5, -1), c + Vector2(x + 6, 5), _d(col.lightened(0.12)), 1.3)
		ci.draw_line(c + Vector2(x + 5, -1), c + Vector2(x - 4, 5), _d(col.darkened(0.12)), 1.3)
	ci.draw_line(c + Vector2(-r - 3, 1), c + Vector2(-r + 4, -2), _d(col), 1.2)
	ci.draw_line(c + Vector2(r + 3, 0), c + Vector2(r - 5, -3), _d(col), 1.2)


static func _ferns(ci: CanvasItem, xs: Array, col: Color) -> void:
	for x: float in xs:
		for k in 5:
			var a := -PI * 0.5 + (k - 2) * 0.45
			var tip := Vector2(x, 0) + Vector2(cos(a), sin(a)) * 11.0
			ci.draw_line(Vector2(x, 0), tip, _d(col.lightened(0.05 * k)), 1.8)
			ci.draw_line(Vector2(x, 0).lerp(tip, 0.5), Vector2(x, 0).lerp(tip, 0.5) + Vector2(2, -1.5), _d(col.lightened(0.15)), 1.0)


static func _mushrooms(ci: CanvasItem, ps: Array, col: Color) -> void:
	for p: Vector2 in ps:
		ci.draw_line(p, p + Vector2(0, -4), _d(Color("efe6d0")), 1.4)
		_shape(ci, [p + Vector2(-3, -4), p + Vector2(0, -7), p + Vector2(3, -4)], col, 0.6)
		ci.draw_circle(p + Vector2(-0.8, -5), 0.6, Color(1, 1, 1, 0.8))


# ---------------------------------------------------------------------------
# Dwarves

static func _dwarf(ci: CanvasItem, age: int, h: float, tm: Color, glow: Color) -> void:
	var stone := Color("8a8278")
	if age == 2:
		stone = Color("9a6a4a")
	elif age == 6:
		stone = Color("5a5a68")
	var iron := Color("4a4c52")
	var brass := Color("b8914a")
	var gold := Color("d9b25c")
	if age <= 1:
		# Stone cairn: stacked, individually outlined stones, moss, a rune-scratched capstone, a torch.
		for k in 5:
			var w := 21.0 - k * 2.0
			var y := -4.0 - k * (h - 8) / 5.0
			for n in 3:
				_oval(ci, Vector2(-w * 0.62 + n * w * 0.62, y), Vector2(w * 0.36, 4.2), stone.darkened(0.06 * ((n + k) % 3)), 0.8)
		_moss(ci, Vector2(-10, -7), Vector2(6, 2.5))
		_shape(ci, _rect(Rect2(-15, -h - 3, 30, 5)), stone.lightened(0.05))
		ci.draw_polyline(PackedVector2Array([Vector2(-6, -h - 1), Vector2(-3, -h + 1), Vector2(0, -h - 1), Vector2(3, -h + 1)]), Color(0, 0, 0, 0.45), 0.9)
		ci.draw_line(Vector2(17, 0), Vector2(17, -h + 2), _d(Color("5a3a22")), 1.8)
		_flame(ci, Vector2(17, -h + 2), 0.9)
		_pennant(ci, Vector2(-15, -h - 3), tm, 12.0)
		_tufts(ci, [-22.0, 22.0], Color("7a7a4a"))
		return
	# A squat keep on a battered plinth.
	_shape(ci, [Vector2(-26, 0), Vector2(-23, -8), Vector2(23, -8), Vector2(26, 0)], stone.darkened(0.12))
	_blocks(ci, Rect2(-22, -h, 44, h - 8), stone, 8.0, 13.0)
	for k in 4:
		_shape(ci, _rect(Rect2(-24 + k * 13, -h - 7, 9, 7)), stone.darkened(0.06), 0.9)
	_shape(ci, _rect(Rect2(-24, -h - 1, 48, 3)), stone.darkened(0.2), 0.8)
	match age:
		2:
			# Copper bands and a carved dwarf face over the door.
			for y in [-h * 0.3, -h * 0.75]:
				_shape(ci, _rect(Rect2(-23, y - 1.5, 46, 3)), Color("b87a3a"), 0.7)
				for n in 6:
					ci.draw_circle(Vector2(-20 + n * 8, y), 0.8, _d(Color("f0c080")))
			_face(ci, Vector2(0, -h * 0.6), stone)
			_brazier(ci, Vector2(-26, -8))
		3, 4:
			# Iron bands with rivets, a door, braziers on the corners, a shield (Iron) or a long banner (Medieval).
			_shape(ci, _rect(Rect2(-23, -h * 0.3 - 1.5, 46, 3)), iron, 0.7)
			for n in 7:
				ci.draw_circle(Vector2(-20 + n * 6.7, -h * 0.3), 0.8, _d(Color("aab0b8")))
			_shape(ci, [Vector2(-5, -8), Vector2(-5, -17), Vector2(5, -17), Vector2(5, -8)], iron.darkened(0.2), 0.8)
			for y in [-10.0, -14.0]:
				ci.draw_line(Vector2(-5, y), Vector2(5, y), _d(Color("8a8e96")), 0.8)
			if age == 3:
				_oval(ci, Vector2(0, -h * 0.66), Vector2(7.5, 7.5), iron)
				_oval(ci, Vector2(0, -h * 0.66), Vector2(6, 6), tm.lerp(Color.BLACK, 0.0), 0.6)
				_shape(ci, [Vector2(-3.5, -h * 0.66 - 1), Vector2(3.5, -h * 0.66 - 1), Vector2(2, -h * 0.66 + 1.5), Vector2(-2, -h * 0.66 + 1.5)], Color("c8ccd2"), 0.5)
			else:
				_banner(ci, Vector2(0, -h * 0.9), 7.0, h * 0.5, tm, _d(gold), true)
				_shape(ci, [Vector2(-2.5, -h * 0.72), Vector2(2.5, -h * 0.72), Vector2(1.2, -h * 0.64), Vector2(-1.2, -h * 0.64)], Color("c8ccd2"), 0.5)
				ci.draw_line(Vector2(0, -h * 0.64), Vector2(0, -h * 0.56), _d(Color("6a4a2b")), 1.2)
			_brazier(ci, Vector2(-22, -h - 7))
			_brazier(ci, Vector2(22, -h - 7))
		5:
			# Steam tower: riveted iron plates, brass pipes with a valve wheel and gauge, a smoking stack.
			for r in 3:
				ci.draw_line(Vector2(-22, -8 - r * (h - 8) / 3.0), Vector2(22, -8 - r * (h - 8) / 3.0), _d(iron), 2.2)
				for n in 8:
					ci.draw_circle(Vector2(-19 + n * 5.4, -9.5 - r * (h - 8) / 3.0), 0.8, _d(Color("aab0b8")))
			ci.draw_polyline(PackedVector2Array([Vector2(24, -2), Vector2(24, -h * 0.6), Vector2(17, -h * 0.6)]), INK, 4.4)
			ci.draw_polyline(PackedVector2Array([Vector2(24, -2), Vector2(24, -h * 0.6), Vector2(17, -h * 0.6)]), _d(brass), 3.0)
			_oval(ci, Vector2(24, -h * 0.35), Vector2(4, 4), brass, 0.8)
			for n in 4:
				var a := n * PI / 4.0 + _t * 0.3
				ci.draw_line(Vector2(24, -h * 0.35) - Vector2(cos(a), sin(a)) * 3.5, Vector2(24, -h * 0.35) + Vector2(cos(a), sin(a)) * 3.5, _d(iron), 0.8)
			_oval(ci, Vector2(-8, -h * 0.55), Vector2(4, 4), Color("e8e0c8"), 0.8)
			var needle := -2.4 + 0.6 * sin(_t * 1.3)
			ci.draw_line(Vector2(-8, -h * 0.55), Vector2(-8, -h * 0.55) + Vector2(cos(needle), sin(needle)) * 3.0, Color(0.6, 0.1, 0.1), 0.9)
			_shape(ci, _rect(Rect2(-19, -h - 18, 6, 12)), iron.darkened(0.1))
			for n in 3:
				var u := fmod(_t * 0.5 + n / 3.0, 1.0)
				ci.draw_circle(Vector2(-16 - u * 8, -h - 20 - u * 18), 2.5 + u * 5.0, Color(0.85, 0.85, 0.82, 0.45 * (1.0 - u)))
			_shape(ci, [Vector2(-5, -8), Vector2(-5, -17), Vector2(5, -17), Vector2(5, -8)], iron.darkened(0.2), 0.8)
			for n in 3:
				_oval(ci, Vector2(-26 + n * 4, -2 - (n % 2) * 2), Vector2(3, 2.2), Color("2a2a2e"), 0.5)
			_pennant(ci, Vector2(18, -h - 7), tm, 12.0)
		_:
			# Rune tower: glowing rune lines, a forge-glow slit, gold trim, a floating runestone.
			var k := 0.55 + 0.45 * sin(_t * 1.6)
			ci.draw_line(Vector2(-22, -h * 0.5), Vector2(22, -h * 0.5), _d(gold), 1.4)
			for p in [Vector2(-15, -12), Vector2(6, -12), Vector2(-15, -h * 0.72)]:
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(3, -6), p + Vector2(6, 0), p + Vector2(9, -6)]), Color(glow, 0.25 * k), 4.0)
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(3, -6), p + Vector2(6, 0), p + Vector2(9, -6)]), Color(glow, 0.9 * k), 1.3)
			ci.draw_rect(Rect2(8, -h * 0.8, 3, 9), Color(glow, 0.6 + 0.3 * k))
			_shape(ci, [Vector2(-5, -8), Vector2(-5, -17), Vector2(0, -20), Vector2(5, -17), Vector2(5, -8)], iron.darkened(0.2), 0.8)
			ci.draw_polyline(PackedVector2Array([Vector2(-3, -12), Vector2(0, -16), Vector2(3, -12)]), Color(glow, 0.9 * k), 1.0)
			var fp := Vector2(-17, -h - 20 + sin(_t * 1.4) * 2.5)
			ci.draw_circle(fp, 8.0, Color(glow, 0.12 * k))
			_shape(ci, [fp + Vector2(-4, 5), fp + Vector2(-4.5, -4), fp + Vector2(0, -7), fp + Vector2(4.5, -3.5), fp + Vector2(4, 5.5)], stone.lightened(0.1), 0.8)
			ci.draw_polyline(PackedVector2Array([fp + Vector2(-2, -2), fp + Vector2(0, 2), fp + Vector2(2, -2)]), Color(glow, k), 1.2)
			_oval(ci, Vector2(0, -h * 0.3), Vector2(6, 6), tm, 0.8)
	_tufts(ci, [-28.0, 28.0], Color("6a6a44"))


## A stern carved dwarf face: brow, eyes, nose and a braided beard.
static func _face(ci: CanvasItem, c: Vector2, stone: Color) -> void:
	var s := stone.lightened(0.08)
	_oval(ci, c, Vector2(8, 8), s, 0.8)
	_shape(ci, [c + Vector2(-8, -2), c + Vector2(8, -2), c + Vector2(6, -5), c + Vector2(-6, -5)], s.darkened(0.12), 0.7)
	ci.draw_line(c + Vector2(-5, 0), c + Vector2(-2, 0), Color(0, 0, 0, 0.55), 1.2)
	ci.draw_line(c + Vector2(2, 0), c + Vector2(5, 0), Color(0, 0, 0, 0.55), 1.2)
	_shape(ci, [c + Vector2(-1.5, 0), c + Vector2(1.5, 0), c + Vector2(2, 4), c + Vector2(-2, 4)], s.darkened(0.06), 0.6)
	_shape(ci, [c + Vector2(-7, 4), c + Vector2(7, 4), c + Vector2(4, 14), c + Vector2(0, 17), c + Vector2(-4, 14)], s.darkened(0.1), 0.8)
	for n in 3:
		ci.draw_line(c + Vector2(-3 + n * 3, 6), c + Vector2(-2 + n * 2, 14), Color(0, 0, 0, 0.3), 0.8)
