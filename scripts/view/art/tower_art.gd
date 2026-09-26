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
	var glow: Color = RaceLook.look(race).glow
	var tm := team.darkened(dim)
	UnitArt._ellipse(ci, Vector2(0, 2), Vector2(26, 5), Color(0, 0, 0, 0.32))
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
	UnitArt._shade_poly(ci, pts, _d(col))
	if ink > 0.0:
		var p := PackedVector2Array(pts)
		p.append(pts[0])
		ci.draw_polyline(p, INK, ink)


static func _rect(r: Rect2) -> Array:
	return [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]


static func _oval(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, ink := 1.0, rot := 0.0) -> void:
	_shape(ci, UnitArt._ellipse_pts(c, r, rot, 12), col, ink)


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
	UnitArt._ellipse(ci, c, r, _d(col))
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
			# Lashed lookout: four poles, cross braces, hides over the rail, a torch and a totem.
			_rock(ci, Vector2(-15, 0), 6.0, Color("8a7a66"))
			_rock(ci, Vector2(16, 0), 5.0, Color("7a6a58"))
			for x in [-12.0, 12.0]:
				_shape(ci, [Vector2(x - 2, 0), Vector2(x * 0.8 - 1.5, -h), Vector2(x * 0.8 + 1.5, -h), Vector2(x + 2, 0)], wood, 0.9)
			ci.draw_line(Vector2(-11, -5), Vector2(9, -h + 7), _d(wood.darkened(0.15)), 2.2)
			ci.draw_line(Vector2(11, -5), Vector2(-9, -h + 7), _d(wood.darkened(0.15)), 2.2)
			for y in [-5.0, -h + 7]:
				for x in [-11.0, 10.0]:
					ci.draw_line(Vector2(x - 1.5, y - 1.5), Vector2(x + 1.5, y + 1.5), _d(Color("c9b28a")), 1.4)
			_shape(ci, _rect(Rect2(-17, -h - 4, 34, 6)), wood.lightened(0.1))
			for k in 5:
				ci.draw_line(Vector2(-17 + k * 7, -h - 4), Vector2(-17 + k * 7, -h + 2), Color(0, 0, 0, 0.35), 0.8)
			# Hide draped over the rail.
			_shape(ci, [Vector2(-15, -h + 2), Vector2(-3, -h + 2), Vector2(-5, -h + 13), Vector2(-9, -h + 10), Vector2(-13, -h + 14)], Color("9a7048"), 0.9)
			ci.draw_line(Vector2(15, -h + 2), Vector2(15, -h - 12), _d(wood), 1.6)
			_flame(ci, Vector2(15, -h - 12), 0.9)
			# Antler totem on the far post.
			ci.draw_polyline(PackedVector2Array([Vector2(-14, -h - 4), Vector2(-18, -h - 11), Vector2(-17, -h - 15)]), _d(Color("e0d4b8")), 1.5)
			ci.draw_polyline(PackedVector2Array([Vector2(-14, -h - 4), Vector2(-11, -h - 11), Vector2(-12, -h - 15)]), _d(Color("e0d4b8")), 1.5)
			_tufts(ci, [-22.0, 4.0, 21.0], Color("7a7a3a"))
		2:
			# Temple plinth: stepped base, fluted pilasters, bronze boss, dentil cornice, braziers.
			var marble := Color("e6dcc4")
			_shape(ci, _rect(Rect2(-20, -5, 40, 5)), marble.darkened(0.12))
			_shape(ci, _rect(Rect2(-17, -9, 34, 4)), marble.darkened(0.06))
			_shape(ci, _rect(Rect2(-14, -h + 6, 28, h - 15)), marble)
			for x in [-12.0, 8.0]:
				_shape(ci, _rect(Rect2(x, -h + 6, 4, h - 15)), marble.lightened(0.05), 0.8)
				for f in 2:
					ci.draw_line(Vector2(x + 1.2 + f * 1.6, -h + 8), Vector2(x + 1.2 + f * 1.6, -11), Color(0, 0, 0, 0.18), 0.8)
			_oval(ci, Vector2(0, -h * 0.5), Vector2(5.5, 5.5), Color("b07a3a"))
			ci.draw_circle(Vector2(-1.5, -h * 0.5 - 1.5), 1.8, _d(Color("f0d090")))
			_shape(ci, _rect(Rect2(-18, -h + 1, 36, 5)), Color("c9a060"))
			for k in 8:
				ci.draw_rect(Rect2(-17 + k * 4.4, -h + 4, 2.2, 2), Color(0, 0, 0, 0.3))
			_shape(ci, _rect(Rect2(-17, -h - 3, 34, 4)), marble.darkened(0.04))
			ci.draw_arc(Vector2(0, -h + 14), 7.0, 0.3, PI - 0.3, 10, tm, 1.6)
			_brazier(ci, Vector2(-22, -9))
			_tufts(ci, [18.0, 24.0], Color("8a8a4a"))
		3:
			# Roman watchtower: stone base with an arched door, timber upper frame, tiled skirt.
			var tufa := Color("c2b08e")
			_blocks(ci, Rect2(-16, -h * 0.45, 32, h * 0.45), tufa)
			_shape(ci, [Vector2(-5, 0), Vector2(-5, -9), Vector2(0, -13), Vector2(5, -9), Vector2(5, 0)], Color(0.12, 0.09, 0.07), 0.8)
			for x in [-14.0, 14.0]:
				_shape(ci, _rect(Rect2(x - 1.8, -h + 2, 3.6, h * 0.55)), wood, 0.8)
			ci.draw_line(Vector2(-13, -h * 0.45), Vector2(13, -h + 4), _d(wood.darkened(0.2)), 2.2)
			ci.draw_line(Vector2(13, -h * 0.45), Vector2(-13, -h + 4), _d(wood.darkened(0.25)), 2.2)
			_shape(ci, [Vector2(-21, -h + 1), Vector2(21, -h + 1), Vector2(17, -h + 7), Vector2(-17, -h + 7)], Color("b0583a"))
			for k in 7:
				ci.draw_line(Vector2(-19 + k * 6, -h + 1), Vector2(-16 + k * 5.4, -h + 7), Color(0, 0, 0, 0.3), 0.8)
			_shape(ci, _rect(Rect2(-17, -h - 3, 34, 4)), wood.lightened(0.1))
			# Legion shield on the front and a torch bracket.
			_shape(ci, [Vector2(-5, -h * 0.66), Vector2(5, -h * 0.66), Vector2(5.5, -h * 0.4), Vector2(-5.5, -h * 0.4)], tm, 0.9)
			ci.draw_circle(Vector2(0, -h * 0.53), 1.6, _d(gold))
			ci.draw_line(Vector2(16, -h * 0.35), Vector2(20, -h * 0.4), _d(wood), 1.4)
			_flame(ci, Vector2(20, -h * 0.4), 0.7)
			_tufts(ci, [-20.0, 19.0], Color("6a7a3a"))
		4:
			# Stone tower: masonry, crenellations, arrow slit, hoarding brackets, hanging banner, ivy.
			var stone := Color("8d8e8a")
			_rock(ci, Vector2(-18, 0), 5.0, stone.darkened(0.15))
			_blocks(ci, Rect2(-17, -h + 2, 34, h - 2), stone)
			for k in 3:
				_shape(ci, _rect(Rect2(-19 + k * 14, -h - 5, 10, 7)), stone.darkened(0.05))
			_shape(ci, _rect(Rect2(-19, -h + 1, 38, 3)), stone.darkened(0.2), 0.8)
			for x in [-15.0, -5.0, 5.0, 15.0]:
				ci.draw_line(Vector2(x, -h + 4), Vector2(x, -h + 8), _d(Color("3a2c20")), 1.4)
			_shape(ci, _rect(Rect2(-1.5, -h * 0.72, 3, 9)), Color(0.06, 0.05, 0.05), 0.6)
			_banner(ci, Vector2(0, -h * 0.55), 6.0, h * 0.35, tm, _d(gold))
			for k in 6:
				UnitArt._ellipse(ci, Vector2(-15 + (k % 2) * 3, -4 - k * 5), Vector2(3.5, 2.2), _d(Color("3e6a36")), 0.4)
			_tufts(ci, [-10.0, 20.0], Color("5a7a3a"))
		5:
			# Earthwork bastion: sloped earth with stone quoins, brick cap, sandbags, gabions, barrels, lantern.
			var earth := Color("8a7b66")
			_shape(ci, [Vector2(-24, 0), Vector2(-16, -h + 9), Vector2(16, -h + 9), Vector2(24, 0)], earth)
			for r in 4:
				ci.draw_line(Vector2(-22 + r * 2, -6 - r * (h - 14) / 4.0), Vector2(22 - r * 2, -6 - r * (h - 14) / 4.0), Color(0, 0, 0, 0.18), 0.9)
			for k in 4:
				_shape(ci, _rect(Rect2(-23 + k * 2.2, -8 - k * 9, 6, 5)), Color("b0a490"), 0.7)
				_shape(ci, _rect(Rect2(17 - k * 2.2, -8 - k * 9, 6, 5)), Color("a0947e"), 0.7)
			_blocks(ci, Rect2(-18, -h, 36, 9), Color("8a5a44"), 4.5, 7)
			for k in 4:
				_oval(ci, Vector2(-12 + k * 8, -h - 1), Vector2(4.5, 2.5), Color("a89468"), 0.7)
			for x in [-30.0, 30.0]:
				_shape(ci, _rect(Rect2(x - 6, -14, 12, 14)), Color("7a6a48"))
				for k in 3:
					ci.draw_line(Vector2(x - 6, -12 + k * 4.5), Vector2(x + 6, -12 + k * 4.5), _d(Color("a88a5a")), 0.9)
			_oval(ci, Vector2(-10, -4), Vector2(3.5, 4), Color("5a3a22"), 0.8)
			ci.draw_line(Vector2(-13.5, -4), Vector2(-6.5, -4), _d(Color("3a3a3a")), 0.8)
			_banner(ci, Vector2(0, -h * 0.75), 5.0, h * 0.3, tm, _d(Color("e6e2d6")))
			ci.draw_line(Vector2(21, -h + 9), Vector2(21, -h - 6), _d(Color("3a3a3e")), 1.4)
			_lantern(ci, Vector2(21, -h - 6), Color(1.0, 0.85, 0.5))
		_:
			# Arcane pylon: tapering violet stone, brass rings and filigree, a crystal core, orbiting runestones.
			var stone := Color("6e6582")
			var brass := Color("c9a45c")
			_shape(ci, _rect(Rect2(-16, -6, 32, 6)), stone.darkened(0.15))
			_shape(ci, [Vector2(-13, -6), Vector2(-9, -h + 4), Vector2(9, -h + 4), Vector2(13, -6)], stone)
			for k in 3:
				var y := -12.0 - k * (h - 22) / 2.0
				var w := lerpf(12.5, 9.5, float(k) / 2.0)
				_shape(ci, _rect(Rect2(-w - 1, y - 1.5, 2 * w + 2, 3)), brass, 0.8)
			var k := 0.6 + 0.4 * sin(_t * 2.2)
			ci.draw_rect(Rect2(-7, -h * 0.72, 14, h * 0.34), Color(glow, 0.12 * k))
			_shape(ci, [Vector2(0, -h * 0.72), Vector2(3.5, -h * 0.55), Vector2(0, -h * 0.38), Vector2(-3.5, -h * 0.55)], glow.lerp(Color.WHITE, 0.3), 0.8)
			for s in [-1.0, 1.0]:
				ci.draw_arc(Vector2(s * 6, -h * 0.25), 4.0, 0, PI, 8, _d(brass), 1.0)
			_shape(ci, [Vector2(-15, -h + 4), Vector2(15, -h + 4), Vector2(12, -h - 2), Vector2(-12, -h - 2)], brass)
			for n in 3:
				var a := _t * 0.9 + n * TAU / 3.0
				var p := Vector2(cos(a) * 22.0, -h * 0.55 + sin(a) * 6.0)
				if sin(a) > 0.0:
					_shape(ci, [p + Vector2(-2.5, 3), p + Vector2(-2.5, -3), p + Vector2(0, -5), p + Vector2(2.5, -3), p + Vector2(2.5, 3)], stone.lightened(0.1), 0.7)
					ci.draw_line(p + Vector2(0, -2), p + Vector2(0, 2), Color(glow, 0.9), 1.0)
			ci.draw_rect(Rect2(-7, -h * 0.24, 14, 7), tm)


# ---------------------------------------------------------------------------
# Elves: grown or woven from nature

static func _elf(ci: CanvasItem, age: int, h: float, tm: Color, glow: Color) -> void:
	var moss := Color("5f7f3a")
	var leaf := Color("4f7a3a")
	var wicker := Color("b08e5a")
	var stone := Color("9a968a")
	var gold := Color("d9b25c")
	var bark := Color("6e5236")
	match age:
		1:
			# Mossy standing stone lashed with vines, a spiral carving, a twig nest with a feather.
			_rock(ci, Vector2(-18, 0), 6.0, stone.darkened(0.12))
			_oval(ci, Vector2(0, -5), Vector2(20, 7), stone.darkened(0.1))
			_shape(ci, [Vector2(-12, -8), Vector2(-11, -h + 12), Vector2(-5, -h + 5), Vector2(7, -h + 7), Vector2(12, -h + 16), Vector2(12, -8)], stone)
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
				_moss(ci, p, Vector2(6, 3), moss)
			var vine := PackedVector2Array()
			for n in 13:
				vine.append(Vector2(sin(n * 1.1) * 12.0, -8.0 - n * (h - 16) / 12.0))
			ci.draw_polyline(vine, _d(leaf.darkened(0.2)), 1.6)
			for n in range(1, 12, 2):
				UnitArt._ellipse(ci, vine[n] + Vector2(2, 0), Vector2(2.5, 1.4), _d(leaf.lightened(0.1)), 0.6)
			_nest(ci, Vector2(0, -h), 18.0, wicker)
			ci.draw_line(Vector2(12, -h - 1), Vector2(19, -h - 7), _d(Color("f0ece0")), 1.6)
			_ferns(ci, [-20.0, 19.0], leaf)
			_mushrooms(ci, [Vector2(14, 0), Vector2(17, 0)], Color("c86a4a"))
		2:
			# Wicker tower: staves woven over and under, a layered leaf collar, flowers, a reed lantern.
			_shape(ci, [Vector2(-17, 0), Vector2(-11, -h), Vector2(11, -h), Vector2(17, 0)], wicker)
			var rows := int(h / 4.0)
			for r in rows:
				var y := -2.0 - r * 4.0
				var w := lerpf(17.0, 11.0, -y / h) - 0.8
				for n in 6:
					var x0 := -w + n * (2.0 * w / 6.0)
					var over := (n + r) % 2 == 0
					ci.draw_line(Vector2(x0, y - 1.2), Vector2(x0 + 2.0 * w / 6.0, y - 1.2), _d(wicker.lightened(0.14) if over else wicker.darkened(0.2)), 2.4)
			for n in 5:
				var x := -10.0 + n * 5.0
				ci.draw_line(Vector2(x * 1.4, 0), Vector2(x, -h), Color(0, 0, 0, 0.25), 0.8)
			for layer in 2:
				for n in 8:
					var a := PI + n * PI / 7.0
					var p := Vector2(cos(a) * (17.0 - layer * 4.0), -h + 3 + sin(a) * 3.0 - layer * 2.0)
					_oval(ci, p, Vector2(6.5, 2.8), leaf.lightened(0.08 * layer + 0.04 * (n % 2)), 0.7, a)
			for p in [Vector2(-9, -h + 4), Vector2(6, -h + 5), Vector2(14, -h + 3)]:
				ci.draw_circle(p, 1.8, _d(Color("f2d8e6")))
				ci.draw_circle(p, 0.8, _d(Color("f2c94c")))
			_oval(ci, Vector2(0, -h), Vector2(16, 3.5), wicker.darkened(0.12), 0.8)
			_lantern(ci, Vector2(-15, -h * 0.55), Color(1.0, 0.88, 0.55), wicker.darkened(0.3))
			for x in [-18.0, 18.0]:
				_moss(ci, Vector2(x, -2), Vector2(7, 3.5), moss)
			_ferns(ci, [22.0], leaf)
		3:
			# Braided living roots cupping a mossy bowl; glowing fungi, hanging moss, a lantern.
			for x in [-22.0, -13.0, 14.0, 24.0]:
				ci.draw_line(Vector2(x * 0.4, -6), Vector2(x, 1), _d(bark.darkened(0.15)), 3.4)
			for strand in 3:
				var line := PackedVector2Array()
				for n in 19:
					var u := n / 18.0
					var spread := lerpf(17.0, 6.0, sin(u * PI) * 0.9 + u * 0.1)
					line.append(Vector2(sin(u * 9.0 + strand * TAU / 3.0) * spread, -u * h))
				ci.draw_polyline(line, INK, 8.0 - strand * 0.5)
				ci.draw_polyline(line, _d(bark.darkened(0.12 * strand)), 6.2 - strand * 0.5)
				var hi := PackedVector2Array()
				for v in line:
					hi.append(v + Vector2(-1.2, -0.6))
				ci.draw_polyline(hi, Color(_d(bark).lightened(0.3), 0.5), 1.0)
			ci.draw_arc(Vector2(0, -h + 6), 16.0, 0.2, PI - 0.2, 12, INK, 7.0)
			ci.draw_arc(Vector2(0, -h + 6), 16.0, 0.2, PI - 0.2, 12, _d(bark), 5.0)
			_oval(ci, Vector2(0, -h), Vector2(16, 4), moss, 0.8)
			for x in [-12.0, -4.0, 9.0]:
				ci.draw_line(Vector2(x, -h + 4), Vector2(x + 0.5, -h + 11 + fposmod(x, 4.0)), _d(Color("7a9a50")), 1.4)
			for p in [Vector2(-15, -h + 4), Vector2(16, -h + 6), Vector2(-9, -h * 0.55), Vector2(10, -h * 0.3)]:
				_oval(ci, p, Vector2(5, 2.4), leaf, 0.7, -0.6 if p.x < 0 else 0.6)
			for p in [Vector2(8, -h * 0.62), Vector2(-7, -h * 0.2), Vector2(4, -8)]:
				ci.draw_circle(p, 3.5, Color(glow, 0.15 + 0.2 * BaseArt.night))
				_shape(ci, [p + Vector2(-2.5, 0), p + Vector2(0, -2), p + Vector2(2.5, 0)], Color("d8f0e0"), 0.6)
			_lantern(ci, Vector2(18, -h + 8), Color(1.0, 0.88, 0.55), bark)
		4:
			# Vine-bound white column: fluting, gilded leaf capital, flowering vine, moon banner, leaf balcony.
			var white := Color("e8e4da")
			_shape(ci, _rect(Rect2(-16, -5, 32, 5)), white.darkened(0.12))
			_shape(ci, [Vector2(-13, -5), Vector2(-9, -h + 8), Vector2(9, -h + 8), Vector2(13, -5)], white)
			for n in 3:
				var x := -5.0 + n * 5.0
				ci.draw_line(Vector2(x * 1.3, -7), Vector2(x, -h + 10), Color(0, 0, 0, 0.12), 1.2)
			_rim(ci, Vector2(-12, -6), Vector2(-9, -h + 8), white)
			_banner(ci, Vector2(0, -h * 0.72), 5.0, h * 0.34, tm, _d(Color("eef2f8")))
			ci.draw_arc(Vector2(0.5, -h * 0.72 + h * 0.34 * 0.45), 2.2, -1.2, 2.0, 8, _d(Color("3a4a7a")), 1.2)
			var vine := PackedVector2Array()
			for n in 25:
				var u := n / 24.0
				vine.append(Vector2(sin(u * 14.0) * 11.0, -u * (h - 8)))
			ci.draw_polyline(vine, _d(leaf.darkened(0.15)), 1.8)
			for n in 8:
				var u := (n + 0.5) / 8.0
				var p := Vector2(sin(u * 14.0) * 11.0, -u * (h - 8))
				_oval(ci, p + Vector2(3, 0), Vector2(3.5, 1.8), leaf.lightened(0.1), 0.6, 0.5)
				if n % 3 == 0:
					ci.draw_circle(p + Vector2(-2, -1), 1.6, _d(Color("f4f0ff")))
			# Capital of gilt leaves and a broad leaf balcony with veins.
			for n in 5:
				var a := PI + (n + 0.5) * PI / 5.0
				_oval(ci, Vector2(cos(a) * 9.0, -h + 8 + sin(a) * 2.0), Vector2(5, 2.2), gold, 0.6, a)
			_shape(ci, [Vector2(-24, -h + 1), Vector2(-15, -h + 7), Vector2(15, -h + 7), Vector2(24, -h + 1), Vector2(14, -h - 3), Vector2(-14, -h - 3)], leaf.lightened(0.05))
			ci.draw_line(Vector2(-22, -h + 2), Vector2(22, -h + 2), _d(gold), 1.2)
			for x in [-14.0, -6.0, 6.0, 14.0]:
				ci.draw_line(Vector2(x * 0.6, -h + 2), Vector2(x, -h + 5.5), Color(0, 0, 0, 0.25), 0.8)
			_ferns(ci, [-19.0, 18.0], leaf)
		5:
			# Moon-mushroom: a pale stalk with a ring and shelf-fungus steps, a broad capped top with
			# glowing gills, spots, and a lantern hanging from the rim.
			var stalk := Color("e6e0cc")
			var cap := Color("b9c6e0")
			_oval(ci, Vector2(0, -3), Vector2(20, 6), moss, 0.9)
			_shape(ci, [Vector2(-11, -2), Vector2(-7, -h * 0.5), Vector2(-6, -h + 10), Vector2(6, -h + 10), Vector2(7, -h * 0.5), Vector2(11, -2)], stalk)
			for x in [-3.0, 0.5, 4.0]:
				ci.draw_line(Vector2(x * 1.5, -4), Vector2(x, -h + 12), Color(0, 0, 0, 0.12), 1.0)
			_rim(ci, Vector2(-10, -4), Vector2(-6, -h + 12), stalk)
			# Skirt ring and three shelf fungi spiralling up the stalk.
			_shape(ci, [Vector2(-10, -h * 0.52), Vector2(10, -h * 0.52), Vector2(12, -h * 0.46), Vector2(-12, -h * 0.46)], stalk.darkened(0.08), 0.9)
			for n in 3:
				var side := -1.0 if n % 2 == 0 else 1.0
				var y := -12.0 - n * (h * 0.22)
				var c := Vector2(side * 9.0, y)
				_shape(ci, [c + Vector2(-side * 2, 2), c + Vector2(side * 9, 1), c + Vector2(side * 7, -3), c + Vector2(-side * 1, -3)], Color("c8a878"), 0.8)
				ci.draw_line(c + Vector2(-side * 1, -1.5), c + Vector2(side * 7, -1.5), _d(Color("e8d0a0")), 0.8)
			# Cap: a broad dome whose flat top carries the turret; gills glow underneath.
			var rim_y := -h + 9.0
			for n in 9:
				var x := -22.0 + n * 5.5
				ci.draw_line(Vector2(x * 0.3, rim_y - 1), Vector2(x, rim_y + 1.5), Color(glow, 0.35 + 0.35 * BaseArt.night), 1.2)
			_shape(ci, [Vector2(-28, rim_y), Vector2(-22, -h + 1), Vector2(-10, -h - 2), Vector2(10, -h - 2), Vector2(22, -h + 1), Vector2(28, rim_y), Vector2(16, rim_y + 3), Vector2(-16, rim_y + 3)], cap)
			_rim(ci, Vector2(-22, -h + 1), Vector2(-10, -h - 2), cap)
			for p in [Vector2(-17, -h + 3), Vector2(-7, -h), Vector2(15, -h + 2), Vector2(21, -h + 6), Vector2(-23, -h + 7)]:
				ci.draw_circle(p, 1.6, _d(Color("f2f4fa")))
			_lantern(ci, Vector2(22, rim_y + 2), glow.lerp(Color.WHITE, 0.4), Color("6a6a7a"))
			var k := 0.6 + 0.4 * sin(_t * 2.0)
			for n in 4:
				var a := _t * 0.7 + n * TAU / 4.0
				ci.draw_circle(Vector2(cos(a) * 30.0, -h * 0.6 + sin(a) * 8.0), 1.4, Color(glow, 0.7 * k))
			_mushrooms(ci, [Vector2(-16, -2), Vector2(-13, -1), Vector2(15, -2)], Color("b9c6e0"))
			_ferns(ci, [-21.0, 21.0], leaf)
		_:
			# Crystal spire: a faceted pillar grown from a mossy stone, flat-topped for the turret, with
			# smaller crystals at its foot, a moonsilver vine and a pulsing core.
			var crystal := Color("6fa4cc").lerp(glow, 0.25)
			var k := 0.6 + 0.4 * sin(_t * 1.8)
			_rock(ci, Vector2(-14, 0), 8.0, stone.darkened(0.1))
			_rock(ci, Vector2(13, 0), 7.0, stone.darkened(0.18))
			_oval(ci, Vector2(0, -5), Vector2(17, 5), stone, 0.9)
			_moss(ci, Vector2(-8, -8), Vector2(7, 2.5), moss)
			ci.draw_circle(Vector2(0, -h * 0.5), 22.0, Color(glow, 0.08 + 0.07 * k))
			var top := -h + 3.0
			_shape(ci, [Vector2(-10, -8), Vector2(-8, top + 6), Vector2(-12, top), Vector2(12, top), Vector2(8, top + 6), Vector2(10, -8)], crystal)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(1, -8), Vector2(1, top + 2), Vector2(12, top), Vector2(8, top + 6), Vector2(10, -8)]), Color(_d(crystal).darkened(0.2), 0.85))
			ci.draw_rect(Rect2(-2.5, top + 10, 5, -top - 22), Color(glow, 0.35 + 0.35 * k))
			ci.draw_line(Vector2(-5, -10), Vector2(-5, top + 6), Color(1, 1, 1, 0.55), 1.0)
			_shape(ci, UnitArt._ellipse_pts(Vector2(0, top), Vector2(12.5, 3.2), 0.0, 12), crystal.lightened(0.2), 0.9)
			for p in [[-12.0, 26.0, -0.45], [12.0, 22.0, 0.4], [-6.0, 16.0, -0.15], [7.0, 14.0, 0.2]]:
				var base := Vector2(p[0], -6)
				var tip := base + Vector2(0, -float(p[1])).rotated(float(p[2]))
				var side := Vector2(3.5, 0).rotated(float(p[2]))
				_shape(ci, [base - side, tip - side * 0.5 + Vector2(0, 4).rotated(float(p[2])), tip, tip + side * 0.5 + Vector2(0, 4).rotated(float(p[2])), base + side], crystal, 0.8)
				ci.draw_colored_polygon(PackedVector2Array([base, tip, tip + side * 0.5 + Vector2(0, 4).rotated(float(p[2])), base + side]), Color(_d(crystal).darkened(0.2), 0.8))
			for y in [-h * 0.3, -h * 0.62]:
				var w := lerpf(10.0, 8.5, -y / h)
				_shape(ci, [Vector2(-w - 1.5, y - 2), Vector2(w + 1.5, y - 2), Vector2(w + 1, y + 2), Vector2(-w - 1, y + 2)], gold, 0.8)
				ci.draw_circle(Vector2(0, y), 1.5, Color(glow, 0.9))
			for p in [Vector2(-7, -h * 0.45), Vector2(4, -h * 0.78), Vector2(-3, -h * 0.18)]:
				ci.draw_line(p, p + Vector2(3, -6), Color(1, 1, 1, 0.45), 0.9)
			for n in 3:
				var a := _t * 1.1 + n * TAU / 3.0
				var p := Vector2(cos(a) * 20.0, top + 14 + sin(a) * 5.0)
				if sin(a) > -0.3:
					_shape(ci, [p + Vector2(0, -4), p + Vector2(2, 0), p + Vector2(0, 4), p + Vector2(-2, 0)], crystal.lightened(0.2), 0.6)
	# Team colour: a leaf-shaped ribbon tied round the tower.
	var ry := -h * 0.42
	_shape(ci, [Vector2(8, ry), Vector2(18, ry + 3), Vector2(24, ry + 10), Vector2(16, ry + 8), Vector2(8, ry + 5)], tm, 0.8)


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
