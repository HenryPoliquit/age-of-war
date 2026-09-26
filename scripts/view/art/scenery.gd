class_name Scenery
extends RefCounted
## Procedural per-age backdrops (GDD §4.1 palette/lighting/lane backdrop table), built once per age
## from a fixed seed. Layers carry a parallax factor: 0 = fixed to the sky, 1 = moves with the lane.

const GROUND_Y := 760.0
const X0 := -1600.0
const X1 := 4000.0

## Per-age palette. sky: [top, horizon]; ground: [top, bottom]; light: tint for units/FX.
const PALETTES := [
	{"sky": [Color("4d4f86"), Color("f4b27a")], "sun": Color("ffd9a0"), "sun_pos": Vector2(0.72, 560), "sun_r": 70.0,
	 "far": Color("a3727f"), "mid": Color("b27a4f"), "near": Color("7c5433"), "ground": [Color("b98d55"), Color("6f5030")],
	 "road": Color("d0a970"), "light": Color("ffc88a")},
	{"sky": [Color("2f7fd0"), Color("d6eef8")], "sun": Color("fffbea"), "sun_pos": Vector2(0.3, 140), "sun_r": 46.0,
	 "far": Color("3b86b5"), "mid": Color("e3d6b8"), "near": Color("f2ede2"), "ground": [Color("dcc792"), Color("a88a55")],
	 "road": Color("eadcb0"), "light": Color("fff6dc")},
	{"sky": [Color("66727e"), Color("bcc6bb")], "sun": Color("e8ecdf"), "sun_pos": Vector2(0.6, 250), "sun_r": 60.0,
	 "far": Color("84977f"), "mid": Color("617758"), "near": Color("7c7b75"), "ground": [Color("64803f"), Color("3a4f2a")],
	 "road": Color("8e7e5c"), "light": Color("dfe8e4")},
	{"sky": [Color("1f2635"), Color("5e6979")], "sun": Color("aab4c4"), "sun_pos": Vector2(0.45, 200), "sun_r": 0.0,
	 "far": Color("2e3d4c"), "mid": Color("4b4845"), "near": Color("5a4632"), "ground": [Color("5e5345"), Color("3a3129")],
	 "road": Color("75695a"), "light": Color("cfd8ff")},
	{"sky": [Color("37262b"), Color("d77238")], "sun": Color("ff9a4a"), "sun_pos": Vector2(0.8, 600), "sun_r": 90.0,
	 "far": Color("3d2d2c"), "mid": Color("2a2121"), "near": Color("6b5a43"), "ground": [Color("4b3c31"), Color("2a211b")],
	 "road": Color("5b4a3c"), "light": Color("ffb35c")},
	{"sky": [Color("080720"), Color("2d1a4f")], "sun": Color("d6f4ff"), "sun_pos": Vector2(0.2, 170), "sun_r": 34.0,
	 "far": Color("17163a"), "mid": Color("221f4a"), "near": Color("2a3052"), "ground": [Color("1d1f33"), Color("0c0d18")],
	 "road": Color("2a2d48"), "light": Color("8ff4ff")},
]

## Shader looks per age: ground material kind and cloud character (GDD §4.1 palette & lighting).
const GROUND_KIND := [0, 1, 2, 3, 4, 5]
const CLOUDS := [
	{"cover": 0.35, "band": 0.55, "light": Color("ffd9b0"), "shadow": Color("9a6a7a")},
	{"cover": 0.3, "band": 0.35, "light": Color("ffffff"), "shadow": Color("b8c8dc")},
	{"cover": 0.75, "band": 0.35, "light": Color("d9ddd8"), "shadow": Color("7f8a86")},
	{"cover": 0.85, "band": 0.3, "light": Color("7f8899"), "shadow": Color("2a303d")},
	{"cover": 0.7, "band": 0.45, "light": Color("e29a62"), "shadow": Color("5a3a34")},
	{"cover": 0.25, "band": 0.5, "light": Color("6a4a9a"), "shadow": Color("1a1030")},
]

## layers: Array[{factor, shapes: Array[Dictionary]}]; shapes: {poly, col} | {circle, r, col} | {line, to, w, col}
## anims: Array[Dictionary] evaluated each frame (smoke, flags, drones, lamps, signs).
var age: int
var palette: Dictionary
var layers: Array = []
var anims: Array = []
## Foreground props drawn in front of the lane (parallax FRONT_FACTOR) and the age's weather.
var front: Array = []
var weather: Dictionary = {}
const FRONT_FACTOR := 1.35
var rng := RandomNumberGenerator.new()

static var _cache := {}


static func for_age(age: int) -> Scenery:
	if not _cache.has(age):
		var s := Scenery.new()
		s.build(age)
		_cache[age] = s
	return _cache[age]


func build(p_age: int) -> void:
	age = p_age
	palette = PALETTES[age - 1]
	rng.seed = 9173 + age * 7919
	for f in [0.08, 0.25, 0.5, 0.78, 1.0]:
		layers.append({"factor": f, "shapes": []})
	match age:
		1: _stone()
		2: _bronze()
		3: _medieval()
		4: _gunpowder()
		5: _industrial()
		6: _future()
	_ground()
	_front()


# ---------------------------------------------------------------------------
# Shape helpers

func _add(layer: int, shape: Dictionary) -> void:
	# Painterly shading: tall shapes get a vertical gradient, lit from above, shadowed at the base.
	if shape.has("poly") and not shape.has("cols"):
		var pts: PackedVector2Array = shape.poly
		var lo := INF
		var hi := -INF
		for v in pts:
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
		if hi - lo > 14.0:
			var col: Color = shape.col
			var cols := PackedColorArray()
			for v in pts:
				var k := (v.y - lo) / (hi - lo)
				cols.append(col.lightened(0.1 * (1.0 - k)).darkened(0.16 * k))
			shape["cols"] = cols
	layers[layer].shapes.append(shape)


func _ridge(layer: int, base_y: float, amp: float, wave: float, col: Color, jag := 0.0, step := 40.0) -> void:
	var pts := PackedVector2Array()
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var x := X0
	while x <= X1:
		var y := base_y - amp * (0.6 * sin(x / wave + ph1) + 0.4 * sin(x / (wave * 0.37) + ph2)) - rng.randf() * jag
		pts.append(Vector2(x, y))
		x += step
	pts.append(Vector2(X1, GROUND_Y + 40))
	pts.append(Vector2(X0, GROUND_Y + 40))
	_add(layer, {"poly": pts, "col": col})


func _ridge_y(x: float, base_y: float) -> float:
	return base_y


func _rect(layer: int, r: Rect2, col: Color) -> void:
	_add(layer, {"poly": PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), "col": col})


func _tri(layer: int, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	_add(layer, {"poly": PackedVector2Array([a, b, c]), "col": col})


func _circle(layer: int, c: Vector2, r: float, col: Color) -> void:
	_add(layer, {"circle": c, "r": r, "col": col})


func _line(layer: int, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	_add(layer, {"line": a, "to": b, "w": w, "col": col})


func _haze(col: Color, amount: float) -> Color:
	# Atmospheric perspective: far layers drift toward the horizon colour.
	return col.lerp(palette.sky[1], amount)


func _xs(spacing: float, jitter: float) -> Array:
	var out := []
	var x := X0 + rng.randf() * spacing
	while x < X1:
		out.append(x)
		x += spacing + rng.randf_range(-jitter, jitter)
	return out


# ---------------------------------------------------------------------------
# Ages

func _stone() -> void:
	var p := palette
	_ridge(0, 600, 70, 260, _haze(p.far, 0.45), 6)            # distant mesas
	for x: float in _xs(700, 200):
		var w := rng.randf_range(120, 260)
		var h := rng.randf_range(60, 120)
		_add(0, {"poly": PackedVector2Array([Vector2(x - w * 0.6, 640), Vector2(x - w * 0.4, 640 - h), Vector2(x + w * 0.4, 640 - h - 8), Vector2(x + w * 0.6, 640)]), "col": _haze(p.far, 0.35)})
	_ridge(1, 680, 40, 330, _haze(p.mid, 0.25), 4)
	_ridge(2, 720, 22, 200, p.mid.darkened(0.08), 3)
	for x: float in _xs(520, 180):
		_acacia(3, x, 752, rng.randf_range(0.8, 1.25), p.near)
	for x: float in _xs(380, 150):
		var s := rng.randf_range(14, 34)
		_add(2, {"poly": PackedVector2Array([Vector2(x - s, 722), Vector2(x - s * 0.5, 722 - s), Vector2(x + s * 0.6, 722 - s * 0.8), Vector2(x + s, 722)]), "col": p.mid.darkened(0.25)})
	for x: float in _xs(900, 250):
		anims.append({"type": "smoke", "layer": 2, "pos": Vector2(x, 716), "col": Color(0.85, 0.8, 0.75, 0.35), "rate": 0.6})
		_circle(2, Vector2(x, 718), 6, Color("ff9a3c"))


func _acacia(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_line(layer, Vector2(x, y), Vector2(x + 6 * s, y - 60 * s), 6 * s, col.darkened(0.2))
	_line(layer, Vector2(x + 4 * s, y - 40 * s), Vector2(x - 22 * s, y - 70 * s), 4 * s, col.darkened(0.2))
	for i in 3:
		var cx := x + (i - 1) * 30 * s + 4 * s
		_add(layer, {"poly": _blob(Vector2(cx, y - 76 * s), Vector2(34 * s, 9 * s)), "col": col.lerp(Color("4f5a2a"), 0.55)})


func _blob(c: Vector2, r: Vector2, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + rng.randf_range(-0.12, 0.12)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts


func _bronze() -> void:
	var p := palette
	_rect(0, Rect2(X0, 560, X1 - X0, 200), p.far)                   # sea
	for i in 40:
		var x := rng.randf_range(X0, X1)
		var y := rng.randf_range(575, 700)
		_line(0, Vector2(x, y), Vector2(x + rng.randf_range(20, 70), y), 2, Color(1, 1, 1, 0.35))
	anims.append({"type": "shimmer", "layer": 0, "col": Color(1, 1, 1, 0.25)})
	for x: float in _xs(1100, 300):
		var w := rng.randf_range(260, 480)
		var h := rng.randf_range(110, 190)
		var pts := PackedVector2Array([Vector2(x - w * 0.5, 740), Vector2(x - w * 0.42, 700 - h * 0.6), Vector2(x - w * 0.2, 700 - h), Vector2(x + w * 0.25, 704 - h), Vector2(x + w * 0.5, 740)])
		_add(1, {"poly": pts, "col": _haze(p.mid, 0.15)})
		_add(1, {"poly": PackedVector2Array([Vector2(x + w * 0.05, 700 - h + 4), Vector2(x + w * 0.25, 704 - h), Vector2(x + w * 0.5, 740), Vector2(x + w * 0.1, 740)]), "col": p.mid.darkened(0.12)})
	_ridge(2, 736, 14, 240, p.mid.darkened(0.05), 2)
	for x: float in _xs(620, 200):
		_ruin(3, x, 752, p.near)
	for x: float in _xs(340, 120):
		var h := rng.randf_range(70, 120)
		_add(3, {"poly": _blob(Vector2(x, 752 - h * 0.5), Vector2(9, h * 0.5), 10), "col": Color("3f5a2e")})


func _ruin(layer: int, x: float, y: float, col: Color) -> void:
	var n := rng.randi_range(2, 4)
	var h := rng.randf_range(80, 120)
	for i in n:
		var cx := x + i * 34
		var ch := h * rng.randf_range(0.55, 1.0)
		_rect(layer, Rect2(cx - 7, y - ch, 14, ch), col)
		_rect(layer, Rect2(cx - 10, y - ch - 6, 20, 6), col.darkened(0.08))
		_line(layer, Vector2(cx - 3, y - ch + 4), Vector2(cx - 3, y - 2), 1.5, col.darkened(0.12))
	if n >= 3:
		_rect(layer, Rect2(x - 12, y - h - 14, 34 * (n - 1) + 24, 10), col.darkened(0.04))


func _medieval() -> void:
	var p := palette
	for i in 7:
		# Clouds come from shaders/sky.gdshader; keep the random draws so the layout is unchanged.
		rng.randf(); rng.randf(); rng.randf(); rng.randf()
		for k in 14:
			rng.randf()
	_ridge(0, 610, 60, 300, _haze(p.far, 0.4), 3)
	_ridge(1, 670, 40, 260, _haze(p.mid, 0.2), 3)
	for x: float in _xs(1500, 300):
		_castle(1, x, 640, _haze(Color("55585c"), 0.2), p)
	_ridge(2, 725, 18, 180, p.mid.darkened(0.1), 2)
	for x: float in _xs(700, 200):
		var w := rng.randf_range(160, 300)
		for k in int(w / 18):
			_rect(3, Rect2(x + k * 18, 738 - (k % 2) * 3, 17, 14 + (k % 2) * 3), p.near.darkened(0.04 * (k % 3)))
	for x: float in _xs(560, 160):
		_line(3, Vector2(x, 752), Vector2(x, 660), 3, Color("4a3a2a"))
		anims.append({"type": "flag", "layer": 3, "pos": Vector2(x, 662), "col": Color("8b2d2d") if rng.randf() < 0.5 else Color("2d4a8b")})


func _castle(layer: int, x: float, y: float, col: Color, p: Dictionary) -> void:
	_rect(layer, Rect2(x - 90, y - 70, 180, 70), col)
	for r in 6:
		_line(layer, Vector2(x - 90, y - 64 + r * 11), Vector2(x + 90, y - 64 + r * 11), 1, col.darkened(0.12))
	for i in 3:
		var tx := x - 90 + i * 90
		_rect(layer, Rect2(tx - 16, y - 120, 32, 120), col.darkened(0.06))
		for r in 9:
			_line(layer, Vector2(tx - 16, y - 114 + r * 12), Vector2(tx + 16, y - 114 + r * 12), 1, col.darkened(0.16))
		for k in 3:
			_rect(layer, Rect2(tx - 16 + k * 12, y - 128, 8, 8), col.darkened(0.06))
		_tri(layer, Vector2(tx - 19, y - 120), Vector2(tx + 19, y - 120), Vector2(tx, y - 152), col.darkened(0.25))
		_rect(layer, Rect2(tx - 2, y - 100, 4, 12), col.darkened(0.45))
		_rect(layer, Rect2(tx - 2, y - 70, 4, 12), col.darkened(0.45))
	for k in 12:
		_rect(layer, Rect2(x - 90 + k * 15, y - 78, 9, 8), col)
	_rect(layer, Rect2(x - 14, y - 34, 28, 34), col.darkened(0.4))


func _gunpowder() -> void:
	var p := palette
	for i in 10:
		rng.randf(); rng.randf(); rng.randf(); rng.randf()
		for k in 14:
			rng.randf()
	anims.append({"type": "lightning"})
	_rect(0, Rect2(X0, 600, X1 - X0, 160), p.far)
	_ridge(1, 640, 90, 280, _haze(p.mid, 0.15), 12, 30)
	for x: float in _xs(1600, 300):
		_rect(1, Rect2(x - 10, 470, 20, 90), Color("7a7470"))
		_circle(1, Vector2(x, 466), 9, Color("f6e7a6"))
		anims.append({"type": "lamp", "layer": 1, "pos": Vector2(x, 466), "col": Color("fff1b0"), "r": 60.0})
	_ridge(2, 728, 20, 160, p.mid.darkened(0.15), 6, 30)
	for x: float in _xs(700, 180):
		for k in rng.randi_range(6, 12):
			var px := x + k * 12
			_add(3, {"poly": PackedVector2Array([Vector2(px - 5, 752), Vector2(px - 5, 700 + (k % 3) * 4), Vector2(px, 692 + (k % 3) * 4), Vector2(px + 5, 700 + (k % 3) * 4), Vector2(px + 5, 752)]), "col": p.near.darkened(0.05 * (k % 2))})
	for x: float in _xs(600, 200):
		anims.append({"type": "drift_smoke", "layer": 2, "pos": Vector2(x, 690), "col": Color(0.78, 0.76, 0.7, 0.28)})


func _industrial() -> void:
	var p := palette
	_rect(0, Rect2(X0, 470, X1 - X0, 120), Color(p.sky[1].darkened(0.1), 0.35))   # smog band
	for x: float in _xs(260, 80):
		var w := rng.randf_range(80, 180)
		var h := rng.randf_range(60, 150)
		_rect(0, Rect2(x, 640 - h, w, h + 120), _haze(p.far, 0.3))
		for k in int(w / 22):
			_tri(0, Vector2(x + k * 22, 640 - h), Vector2(x + k * 22 + 22, 640 - h), Vector2(x + k * 22 + 22, 640 - h - 12), _haze(p.far, 0.26))
		for r in int(h / 30):
			for k in int(w / 24):
				if rng.randf() < 0.45:
					_rect(0, Rect2(x + 6 + k * 24, 650 - h + r * 30, 10, 12), Color(1.0, 0.62, 0.25, rng.randf_range(0.15, 0.45)))
		if rng.randf() < 0.55:
			var cx := x + rng.randf_range(10, w - 20)
			var ch := rng.randf_range(80, 160)
			_rect(0, Rect2(cx, 640 - h - ch, 14, ch), _haze(p.far, 0.25))
			anims.append({"type": "smoke", "layer": 0, "pos": Vector2(cx + 7, 640 - h - ch), "col": Color(0.3, 0.26, 0.26, 0.4), "rate": 1.0})
	# Rail trestle.
	_rect(1, Rect2(X0, 610, X1 - X0, 10), p.mid)
	for x: float in _xs(90, 0):
		_line(1, Vector2(x, 620), Vector2(x + 45, 740), 4, p.mid)
		_line(1, Vector2(x + 45, 620), Vector2(x, 740), 4, p.mid)
	_ridge(2, 730, 14, 200, Color("3b2f28"), 4)
	for x: float in _xs(420, 120):
		_line(2, Vector2(x, 730), Vector2(x, 610), 4, Color("1e1918"))
		_line(2, Vector2(x, 612), Vector2(x + 16, 612), 3, Color("1e1918"))
		_circle(2, Vector2(x + 16, 616), 5, Color("ffc36a"))
		anims.append({"type": "lamp", "layer": 2, "pos": Vector2(x + 16, 616), "col": Color("ffb347"), "r": 70.0})
	for x: float in _xs(520, 160):
		for k in rng.randi_range(4, 8):
			_add(3, {"poly": _blob(Vector2(x + k * 16, 744 - (k % 2) * 9), Vector2(10, 6), 8), "col": p.near.darkened(0.05 * (k % 3))})
		var wire := PackedVector2Array()
		for k in 12:
			wire.append(Vector2(x + 140 + k * 10, 730 + (4 if k % 2 == 0 else -4)))
		_add(3, {"polyline": wire, "w": 1.5, "col": Color("2a2320")})


func _future() -> void:
	var p := palette
	for i in 160:
		_circle(0, Vector2(rng.randf_range(X0, X1), rng.randf_range(-200, 480)), rng.randf_range(0.8, 2.0), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	for x: float in _xs(150, 60):
		var w := rng.randf_range(60, 120)
		var h := rng.randf_range(160, 420)
		_rect(0, Rect2(x, 700 - h, w, h + 60), _haze(p.far, 0.15))
		var neon := Color("37e7ff") if rng.randf() < 0.5 else Color("ff4fd8")
		for k in int(h / 26):
			for j in int(w / 18):
				if rng.randf() < 0.35:
					_rect(0, Rect2(x + 6 + j * 18, 712 - h + k * 26, 8, 10), Color(neon, rng.randf_range(0.25, 0.7)))
		_line(0, Vector2(x, 700 - h), Vector2(x + w, 700 - h), 2, Color(neon, 0.8))
	for x: float in _xs(700, 200):
		var neon := Color("37e7ff") if rng.randf() < 0.5 else Color("ff4fd8")
		anims.append({"type": "sign", "layer": 1, "rect": Rect2(x, rng.randf_range(420, 560), rng.randf_range(80, 160), rng.randf_range(34, 60)), "col": neon})
	for i in 10:
		anims.append({"type": "drone", "layer": 2, "pos": Vector2(rng.randf_range(X0, X1), rng.randf_range(300, 560)), "speed": rng.randf_range(30, 90)})
	_rect(3, Rect2(X0, 700, X1 - X0, 8), p.near)
	for x: float in _xs(160, 0):
		_line(3, Vector2(x, 708), Vector2(x, 752), 4, p.near)
	_line(3, Vector2(X0, 700), Vector2(X1, 700), 2, Color("37e7ff", 0.7))


func _ground() -> void:
	# The ground itself is shaded by shaders/ground.gdshader; only Future keeps its neon lane lines.
	if age == 6:
		_line(4, Vector2(X0, GROUND_Y + 24), Vector2(X1, GROUND_Y + 24), 2, Color("37e7ff", 0.55))
		_line(4, Vector2(X0, GROUND_Y + 30), Vector2(X1, GROUND_Y + 30), 1, Color("ff4fd8", 0.45))


func _front() -> void:
	var p := palette
	var dark: Color = p.ground[1].darkened(0.45)
	var y0 := GROUND_Y + 130.0
	for x: float in _xs(760, 260):
		match age:
			1, 2:
				for k in 7:
					var h := rng.randf_range(40, 110)
					var bx := x + k * 9.0
					front.append({"poly": PackedVector2Array([Vector2(bx - 4, y0 + 200), Vector2(bx + rng.randf_range(-14, 14), y0 - h), Vector2(bx + 5, y0 + 200)]), "col": dark.lerp(Color("4f5a2a"), 0.3)})
				front.append({"poly": _blob(Vector2(x + 120, y0 + 60), Vector2(70, 40), 10), "col": dark})
			3:
				for k in 9:
					var h := rng.randf_range(50, 130)
					var bx := x + k * 7.0
					front.append({"poly": PackedVector2Array([Vector2(bx - 3, y0 + 200), Vector2(bx + rng.randf_range(-20, 20), y0 - h), Vector2(bx + 4, y0 + 200)]), "col": dark.lerp(Color("2e4020"), 0.5)})
			4:
				front.append({"poly": _blob(Vector2(x, y0 + 50), Vector2(110, 60), 9), "col": dark})
				front.append({"poly": PackedVector2Array([Vector2(x + 60, y0 + 100), Vector2(x + 90, y0 - 70), Vector2(x + 100, y0 - 66), Vector2(x + 80, y0 + 100)]), "col": dark.lightened(0.05)})
			5:
				for k in 5:
					front.append({"poly": _blob(Vector2(x + k * 34, y0 + 40 - (k % 2) * 22), Vector2(22, 14), 8), "col": dark.lightened(0.04 * (k % 2))})
				var wire := PackedVector2Array()
				for k in 16:
					wire.append(Vector2(x + 180 + k * 12, y0 + (6 if k % 2 == 0 else -6)))
				front.append({"polyline": wire, "w": 2.5, "col": dark})
				front.append({"line": Vector2(x + 180, y0 - 40), "to": Vector2(x + 184, y0 + 100), "w": 5, "col": dark})
			6:
				front.append({"poly": PackedVector2Array([Vector2(x, y0 + 200), Vector2(x + 20, y0 - 40), Vector2(x + 260, y0 - 40), Vector2(x + 280, y0 + 200)]), "col": Color("0c0d18")})
				front.append({"line": Vector2(x + 20, y0 - 40), "to": Vector2(x + 260, y0 - 40), "w": 2, "col": Color("37e7ff", 0.8)})
	weather = [
		{"kind": "motes", "n": 60, "col": Color(1.0, 0.9, 0.7, 0.5)},
		{"kind": "gulls", "n": 7, "col": Color(0.2, 0.25, 0.3, 0.8)},
		{"kind": "drizzle", "n": 120, "col": Color(0.85, 0.9, 0.95, 0.22)},
		{"kind": "rain", "n": 240, "col": Color(0.75, 0.8, 0.95, 0.35)},
		{"kind": "ash", "n": 90, "col": Color(0.35, 0.32, 0.3, 0.6)},
		{"kind": "neon_rain", "n": 140, "col": Color("37e7ff", 0.35)},
	][age - 1]
