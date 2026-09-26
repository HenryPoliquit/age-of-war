class_name Scenery
extends RefCounted
## Procedural backdrops per race and age (GDD §4.1 palette/lighting/lane backdrop table, §5.7
## races): human lands, elven forests and dwarven mountains, each through Stone → Arcane. Built once
## per (race, age) from a fixed seed. Layers carry a parallax factor: 0 = fixed to the sky, 1 = moves
## with the lane.

const GROUND_Y := 760.0
const X0 := -1600.0
const X1 := 4000.0

## Look per race and age. sky: [top, horizon]; ground: [top, bottom]; light: tint for units/FX;
## clouds: sky-shader cloud character; kind: ground material (shaders/ground.gdshader);
## dn: how strongly the day/night cycle applies; ambient: canvas tint; stars: always starry;
## front: foreground prop set; weather: FrontLayer particles.
const LOOKS := {
	&"human": [
		{"sky": [Color("4d4f86"), Color("f4b27a")], "sun": Color("ffd9a0"), "sun_pos": Vector2(0.72, 560), "sun_r": 70.0,
		 "far": Color("a3727f"), "mid": Color("b27a4f"), "near": Color("7c5433"), "ground": [Color("b98d55"), Color("6f5030")],
		 "road": Color("d0a970"), "light": Color("ffc88a"), "kind": 0, "dn": 0.9, "ambient": Color(1.0, 0.97, 0.93),
		 "clouds": {"cover": 0.35, "band": 0.55, "light": Color("ffd9b0"), "shadow": Color("9a6a7a")},
		 "front": "grass", "weather": {"kind": "motes", "n": 60, "col": Color(1.0, 0.9, 0.7, 0.5)}},
		{"sky": [Color("2f7fd0"), Color("d6eef8")], "sun": Color("fffbea"), "sun_pos": Vector2(0.3, 140), "sun_r": 46.0,
		 "far": Color("3b86b5"), "mid": Color("e3d6b8"), "near": Color("f2ede2"), "ground": [Color("dcc792"), Color("a88a55")],
		 "road": Color("eadcb0"), "light": Color("fff6dc"), "kind": 1, "dn": 1.0, "ambient": Color(1, 1, 1),
		 "clouds": {"cover": 0.3, "band": 0.35, "light": Color("ffffff"), "shadow": Color("b8c8dc")},
		 "front": "grass", "weather": {"kind": "gulls", "n": 7, "col": Color(0.2, 0.25, 0.3, 0.8)}},
		# Iron: Mediterranean hills, aqueducts and cypresses.
		{"sky": [Color("3f7fc0"), Color("f2dcb0")], "sun": Color("fff4d8"), "sun_pos": Vector2(0.65, 180), "sun_r": 52.0,
		 "far": Color("7d93a8"), "mid": Color("8a9a5a"), "near": Color("5e6a3e"), "ground": [Color("8a8a50"), Color("4f5030")],
		 "road": Color("b8a88a"), "light": Color("fff0d0"), "kind": 2, "dn": 1.0, "ambient": Color(1.0, 0.99, 0.95),
		 "clouds": {"cover": 0.3, "band": 0.4, "light": Color("fff8ea"), "shadow": Color("c0b8a8")},
		 "front": "grass", "weather": {"kind": "motes", "n": 40, "col": Color(1.0, 0.95, 0.8, 0.45)}},
		{"sky": [Color("66727e"), Color("bcc6bb")], "sun": Color("e8ecdf"), "sun_pos": Vector2(0.6, 250), "sun_r": 60.0,
		 "far": Color("84977f"), "mid": Color("617758"), "near": Color("7c7b75"), "ground": [Color("64803f"), Color("3a4f2a")],
		 "road": Color("8e7e5c"), "light": Color("dfe8e4"), "kind": 2, "dn": 0.85, "ambient": Color(0.93, 0.95, 0.95),
		 "clouds": {"cover": 0.75, "band": 0.35, "light": Color("d9ddd8"), "shadow": Color("7f8a86")},
		 "front": "tallgrass", "weather": {"kind": "drizzle", "n": 120, "col": Color(0.85, 0.9, 0.95, 0.22)}},
		{"sky": [Color("1f2635"), Color("5e6979")], "sun": Color("aab4c4"), "sun_pos": Vector2(0.45, 200), "sun_r": 0.0,
		 "far": Color("2e3d4c"), "mid": Color("4b4845"), "near": Color("5a4632"), "ground": [Color("5e5345"), Color("3a3129")],
		 "road": Color("75695a"), "light": Color("cfd8ff"), "kind": 3, "dn": 0.55, "ambient": Color(0.8, 0.83, 0.92),
		 "clouds": {"cover": 0.85, "band": 0.3, "light": Color("7f8899"), "shadow": Color("2a303d")},
		 "front": "gabion", "weather": {"kind": "rain", "n": 240, "col": Color(0.75, 0.8, 0.95, 0.35)}},
		# Arcane: violet twilight, floating isles and wizard towers.
		{"sky": [Color("1a1238"), Color("b0609a")], "sun": Color("ffd6f0"), "sun_pos": Vector2(0.3, 540), "sun_r": 62.0,
		 "far": Color("3a2d5e"), "mid": Color("4a3a6a"), "near": Color("3a3040"), "ground": [Color("4a4058"), Color("241e2e")],
		 "road": Color("7a6a8a"), "light": Color("d8b8ff"), "kind": 3, "dn": 0.5, "ambient": Color(0.86, 0.8, 0.95), "stars": true,
		 "clouds": {"cover": 0.45, "band": 0.5, "light": Color("e89ac8"), "shadow": Color("3a2550")},
		 "front": "crystals", "weather": {"kind": "motes", "n": 70, "col": Color(0.77, 0.6, 1.0, 0.7)}},
	],
	&"elf": [
		# Stone: primeval glade at dawn, fireflies.
		{"sky": [Color("5a8a9a"), Color("f3d9a0")], "sun": Color("ffe6b0"), "sun_pos": Vector2(0.75, 500), "sun_r": 64.0,
		 "far": Color("6a8a70"), "mid": Color("3e6a44"), "near": Color("3a2e22"), "ground": [Color("5f7a3a"), Color("34461f")],
		 "road": Color("a08a5a"), "light": Color("ffe6b8"), "kind": 2, "dn": 0.9, "ambient": Color(0.97, 1.0, 0.94), "leaf": Color("4f7a3a"),
		 "clouds": {"cover": 0.35, "band": 0.5, "light": Color("fff0d8"), "shadow": Color("8aa0a0")},
		 "front": "ferns", "weather": {"kind": "motes", "n": 60, "col": Color(1.0, 0.95, 0.55, 0.75)}},
		# Bronze: riverwood of birches and standing stones.
		{"sky": [Color("3d8ad8"), Color("dff2f0")], "sun": Color("fffbe8"), "sun_pos": Vector2(0.3, 150), "sun_r": 46.0,
		 "far": Color("5a9ab8"), "mid": Color("7aa860"), "near": Color("e8e4d8"), "ground": [Color("7a9a48"), Color("465e2a")],
		 "road": Color("c9b88a"), "light": Color("fffbe0"), "kind": 2, "dn": 1.0, "ambient": Color(1, 1, 1), "leaf": Color("7aa84a"),
		 "clouds": {"cover": 0.3, "band": 0.35, "light": Color("ffffff"), "shadow": Color("b8d0dc")},
		 "front": "ferns", "weather": {"kind": "leaves", "n": 26, "col": Color(1.0, 0.86, 0.9, 0.85)}},
		# Iron: the deepwood — giant trunks, tree-halls and lanterns.
		{"sky": [Color("4a6a60"), Color("a8c0a0")], "sun": Color("e8f0dc"), "sun_pos": Vector2(0.6, 250), "sun_r": 50.0,
		 "far": Color("4a6a58"), "mid": Color("2e4a36"), "near": Color("4a3a2a"), "ground": [Color("4a6a30"), Color("2a3a1c")],
		 "road": Color("7a6a4a"), "light": Color("e0f0d8"), "kind": 2, "dn": 0.8, "ambient": Color(0.9, 0.97, 0.92), "leaf": Color("3e6a36"),
		 "clouds": {"cover": 0.7, "band": 0.35, "light": Color("d0dccc"), "shadow": Color("6a7a70")},
		 "front": "ferns", "weather": {"kind": "motes", "n": 50, "col": Color(0.8, 1.0, 0.7, 0.5)}},
		# Medieval: golden autumn wood and white towers.
		{"sky": [Color("5a6aa0"), Color("f6c880")], "sun": Color("ffe0a0"), "sun_pos": Vector2(0.7, 330), "sun_r": 60.0,
		 "far": Color("b89a78"), "mid": Color("b8702e"), "near": Color("5a3a24"), "ground": [Color("9a7a3a"), Color("5a4020")],
		 "road": Color("d0b080"), "light": Color("ffd8a0"), "kind": 2, "dn": 0.9, "ambient": Color(1.0, 0.95, 0.86), "leaf": Color("d0782a"),
		 "clouds": {"cover": 0.4, "band": 0.45, "light": Color("ffe8c0"), "shadow": Color("a07a6a")},
		 "front": "ferns", "weather": {"kind": "leaves", "n": 40, "col": Color("e08a30")}},
		# Gunpowder: mistwood at dusk, pale spires.
		{"sky": [Color("1e3a4a"), Color("7aa0a8")], "sun": Color("e0f4ff"), "sun_pos": Vector2(0.25, 220), "sun_r": 40.0,
		 "far": Color("4a6a78"), "mid": Color("2a4a52"), "near": Color("2a2e2a"), "ground": [Color("3a5a4a"), Color("1e2e26")],
		 "road": Color("6a7a70"), "light": Color("cfeaff"), "kind": 3, "dn": 0.6, "ambient": Color(0.85, 0.92, 0.98), "leaf": Color("2e5a4a"),
		 "clouds": {"cover": 0.6, "band": 0.3, "light": Color("a0b8c0"), "shadow": Color("2a3a48")},
		 "front": "reeds", "weather": {"kind": "motes", "n": 70, "col": Color(0.8, 0.95, 1.0, 0.5)}},
		# Arcane: the starlit grove, glowing leaves and floating crystals.
		{"sky": [Color("070a28"), Color("24306a")], "sun": Color("e8f4ff"), "sun_pos": Vector2(0.78, 150), "sun_r": 38.0,
		 "far": Color("18204a"), "mid": Color("1c2a50"), "near": Color("1c1a2a"), "ground": [Color("1e3040"), Color("0c141e")],
		 "road": Color("3a4a68"), "light": Color("9fe4ff"), "kind": 2, "dn": 0.35, "ambient": Color(0.78, 0.82, 0.98), "stars": true, "leaf": Color("2f7a8a"),
		 "clouds": {"cover": 0.25, "band": 0.5, "light": Color("5a70b0"), "shadow": Color("0e1430")},
		 "front": "mushrooms", "weather": {"kind": "motes", "n": 90, "col": Color(0.6, 0.9, 1.0, 0.8)}},
	],
	&"dwarf": [
		# Stone: highland foothills, cairns and pines.
		{"sky": [Color("5a7aa8"), Color("d8e0e0")], "sun": Color("fff4dc"), "sun_pos": Vector2(0.7, 300), "sun_r": 50.0,
		 "far": Color("8a96a8"), "mid": Color("6a7060"), "near": Color("4a5040"), "ground": [Color("7a7058"), Color("4a4232")],
		 "road": Color("9a8a6a"), "light": Color("f0f0e8"), "kind": 0, "dn": 0.9, "ambient": Color(0.97, 0.98, 1.0),
		 "clouds": {"cover": 0.45, "band": 0.4, "light": Color("f4f4f0"), "shadow": Color("8a90a0")},
		 "front": "rocks", "weather": {"kind": "motes", "n": 40, "col": Color(1, 1, 1, 0.4)}},
		# Bronze: red-rock copper pass with carved guardians.
		{"sky": [Color("4a7ac0"), Color("f4d0a0")], "sun": Color("ffe8c0"), "sun_pos": Vector2(0.35, 160), "sun_r": 48.0,
		 "far": Color("c08a6a"), "mid": Color("a0603a"), "near": Color("7a4a2a"), "ground": [Color("b08050"), Color("6a4428")],
		 "road": Color("d0a070"), "light": Color("ffe0c0"), "kind": 1, "dn": 1.0, "ambient": Color(1.0, 0.97, 0.92),
		 "clouds": {"cover": 0.25, "band": 0.4, "light": Color("fff0e0"), "shadow": Color("c09080")},
		 "front": "rocks", "weather": {"kind": "motes", "n": 60, "col": Color(1.0, 0.85, 0.6, 0.5)}},
		# Iron: snowbound mountain gates.
		{"sky": [Color("5a6878"), Color("c8d0d8")], "sun": Color("f0f4f8"), "sun_pos": Vector2(0.55, 230), "sun_r": 50.0,
		 "far": Color("c8d0dc"), "mid": Color("6a7078"), "near": Color("4a4a50"), "ground": [Color("6a6a6a"), Color("3a3a3e")],
		 "road": Color("8a8a86"), "light": Color("e8f0ff"), "kind": 3, "dn": 0.85, "ambient": Color(0.93, 0.96, 1.0),
		 "clouds": {"cover": 0.7, "band": 0.35, "light": Color("eef2f6"), "shadow": Color("7a8490")},
		 "front": "rocks", "weather": {"kind": "snow", "n": 140, "col": Color(1, 1, 1, 0.8)}},
		# Medieval: deep forges under a smoky dusk.
		{"sky": [Color("2a2030"), Color("c86a3a")], "sun": Color("ffb070"), "sun_pos": Vector2(0.8, 560), "sun_r": 80.0,
		 "far": Color("4a3a44"), "mid": Color("3a2e30"), "near": Color("3a302a"), "ground": [Color("5a4a3e"), Color("2e241e")],
		 "road": Color("7a6a58"), "light": Color("ffb880"), "kind": 0, "dn": 0.6, "ambient": Color(0.92, 0.85, 0.8),
		 "clouds": {"cover": 0.7, "band": 0.4, "light": Color("e08a5a"), "shadow": Color("4a2a2a")},
		 "front": "rocks", "weather": {"kind": "ash", "n": 90, "col": Color(0.35, 0.32, 0.3, 0.6)}},
		# Gunpowder: steam valley of chimneys and pipes.
		{"sky": [Color("37262b"), Color("d77238")], "sun": Color("ff9a4a"), "sun_pos": Vector2(0.8, 600), "sun_r": 90.0,
		 "far": Color("3d2d2c"), "mid": Color("2a2121"), "near": Color("6b5a43"), "ground": [Color("4b3c31"), Color("2a211b")],
		 "road": Color("5b4a3c"), "light": Color("ffb35c"), "kind": 4, "dn": 0.7, "ambient": Color(0.9, 0.84, 0.8),
		 "clouds": {"cover": 0.7, "band": 0.45, "light": Color("e29a62"), "shadow": Color("5a3a34")},
		 "front": "pipes", "weather": {"kind": "ash", "n": 90, "col": Color(0.35, 0.32, 0.3, 0.6)}},
		# Arcane: rune halls under a starry night.
		{"sky": [Color("0a0c1c"), Color("2a2440")], "sun": Color("ffd8a0"), "sun_pos": Vector2(0.2, 160), "sun_r": 30.0,
		 "far": Color("1e2030"), "mid": Color("262838"), "near": Color("1a1c26"), "ground": [Color("2a2c36"), Color("12131a")],
		 "road": Color("4a4a5a"), "light": Color("ffc070"), "kind": 3, "dn": 0.4, "ambient": Color(0.8, 0.78, 0.9), "stars": true,
		 "clouds": {"cover": 0.35, "band": 0.45, "light": Color("4a4a70"), "shadow": Color("10101c")},
		 "front": "runestones", "weather": {"kind": "motes", "n": 70, "col": Color(1.0, 0.7, 0.3, 0.8)}},
	],
}

## layers: Array[{factor, shapes: Array[Dictionary]}]; shapes: {poly, col} | {circle, r, col} | {line, to, w, col}
## anims: Array[Dictionary] evaluated each frame (smoke, flags, lamps, glows, airships, runes).
var race: StringName
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


static func for_look(p_race: StringName, p_age: int) -> Scenery:
	if not LOOKS.has(p_race):
		p_race = &"human"
	var key := "%s_%d" % [p_race, p_age]
	if not _cache.has(key):
		var s := Scenery.new()
		s.build(p_race, p_age)
		_cache[key] = s
	return _cache[key]


static func for_age(p_age: int) -> Scenery:
	return for_look(&"human", p_age)


static func look(p_race: StringName, p_age: int) -> Dictionary:
	return LOOKS.get(p_race, LOOKS[&"human"])[clampi(p_age - 1, 0, 5)]


func build(p_race: StringName, p_age: int) -> void:
	race = p_race
	age = p_age
	palette = look(race, age)
	rng.seed = 9173 + age * 7919 + {&"human": 0, &"elf": 104729, &"dwarf": 224737}.get(race, 0)
	for f in [0.08, 0.25, 0.5, 0.78, 1.0]:
		layers.append({"factor": f, "shapes": []})
	match race:
		&"elf":
			_forest()
		&"dwarf":
			_mountains()
		_:
			match age:
				1: _stone()
				2: _bronze()
				3: _iron()
				4: _medieval()
				5: _gunpowder()
				6: _arcane()
	_front()
	weather = palette.weather


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


func _blob(c: Vector2, r: Vector2, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + rng.randf_range(-0.12, 0.12)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts


func _glow(layer: int, pos: Vector2, r: float, col: Color) -> void:
	anims.append({"type": "glow", "layer": layer, "pos": pos, "r": r, "col": col})


func _pine(layer: int, x: float, y: float, s: float, col: Color, snow := false) -> void:
	_line(layer, Vector2(x, y), Vector2(x, y - 14 * s), 4 * s, col.darkened(0.3))
	for k in 4:
		var w := (26.0 - k * 5.0) * s
		var yb := y - (10.0 + k * 16.0) * s
		_tri(layer, Vector2(x - w, yb), Vector2(x + w, yb), Vector2(x, yb - 26 * s), col.darkened(0.05 * k))
		if snow:
			_tri(layer, Vector2(x - w * 0.35, yb - 17 * s), Vector2(x + w * 0.35, yb - 17 * s), Vector2(x, yb - 26 * s), Color("eef2f6"))


# ---------------------------------------------------------------------------
# Humans

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


func _iron() -> void:
	var p := palette
	_ridge(0, 610, 60, 320, _haze(p.far, 0.35), 3)
	# Aqueduct marching across the hills: two tiers of arches.
	_ridge(1, 668, 34, 280, _haze(p.mid, 0.3), 3)
	var aq := _haze(Color("c8b89a"), 0.25)
	var ax := X0 + 200.0
	while ax < X1 - 200.0:
		var span := rng.randf_range(900, 1400)
		var x := ax
		while x < ax + span:
			_rect(1, Rect2(x, 560, 12, 130), aq)
			_rect(1, Rect2(x + 3, 520, 8, 40), aq.darkened(0.04))
			x += 44.0
		_rect(1, Rect2(ax - 4, 554, span + 12, 10), aq.lightened(0.05))
		_rect(1, Rect2(ax - 4, 514, span + 12, 8), aq.lightened(0.05))
		ax += span + rng.randf_range(600, 1100)
	_ridge(2, 724, 18, 220, p.mid.darkened(0.06), 2)
	# Villas with terracotta roofs, stone pines and cypresses.
	for x: float in _xs(900, 260):
		var w := rng.randf_range(90, 150)
		_rect(2, Rect2(x, 690, w, 36), Color("e6dcc6").darkened(0.1))
		_tri(2, Vector2(x - 8, 690), Vector2(x + w + 8, 690), Vector2(x + w * 0.5, 668), Color("b0583a"))
		for k in int(w / 22):
			_rect(2, Rect2(x + 8 + k * 22, 700, 7, 14), Color(0.2, 0.15, 0.12))
	for x: float in _xs(260, 90):
		var h := rng.randf_range(70, 120)
		_add(3, {"poly": _blob(Vector2(x, 752 - h * 0.5), Vector2(10, h * 0.5), 10), "col": Color("2f4a2a")})
	for x: float in _xs(640, 200):
		var s := rng.randf_range(0.9, 1.3)
		_line(3, Vector2(x, 752), Vector2(x + 4 * s, 752 - 64 * s), 5 * s, Color("5a4030"))
		_add(3, {"poly": _blob(Vector2(x + 4 * s, 752 - 74 * s), Vector2(44 * s, 12 * s), 14), "col": Color("3e5a30")})
	for x: float in _xs(700, 200):
		_rect(3, Rect2(x, 734, 10, 18), Color("b8ae98"))
		_rect(3, Rect2(x - 1, 732, 12, 3), Color("a09680"))


func _medieval() -> void:
	var p := palette
	_ridge(0, 610, 60, 300, _haze(p.far, 0.4), 3)
	_ridge(1, 670, 40, 260, _haze(p.mid, 0.2), 3)
	for x: float in _xs(1500, 300):
		_castle(1, x, 640, _haze(Color("55585c"), 0.2))
	_ridge(2, 725, 18, 180, p.mid.darkened(0.1), 2)
	for x: float in _xs(700, 200):
		var w := rng.randf_range(160, 300)
		for k in int(w / 18):
			_rect(3, Rect2(x + k * 18, 738 - (k % 2) * 3, 17, 14 + (k % 2) * 3), p.near.darkened(0.04 * (k % 3)))
	for x: float in _xs(560, 160):
		_line(3, Vector2(x, 752), Vector2(x, 660), 3, Color("4a3a2a"))
		anims.append({"type": "flag", "layer": 3, "pos": Vector2(x, 662), "col": Color("8b2d2d") if rng.randf() < 0.5 else Color("2d4a8b")})


func _castle(layer: int, x: float, y: float, col: Color) -> void:
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


func _arcane() -> void:
	var p := palette
	var glow: Color = p.light
	_ridge(0, 640, 50, 300, _haze(p.far, 0.2), 4)
	# Floating isles with towers, light spilling from their undersides.
	for x: float in _xs(900, 300):
		var y := rng.randf_range(300, 460)
		var w := rng.randf_range(90, 170)
		var rock := _haze(p.mid, 0.25)
		_add(0, {"poly": PackedVector2Array([Vector2(x - w * 0.5, y), Vector2(x + w * 0.5, y), Vector2(x + w * 0.2, y + w * 0.45), Vector2(x - w * 0.05, y + w * 0.7), Vector2(x - w * 0.3, y + w * 0.4)]), "col": rock})
		_rect(0, Rect2(x - 10, y - 70, 20, 70), rock.lightened(0.05))
		_tri(0, Vector2(x - 16, y - 70), Vector2(x + 16, y - 70), Vector2(x, y - 110), rock.darkened(0.2))
		_rect(0, Rect2(x - 3, y - 54, 6, 10), Color(glow, 0.7))
		_glow(0, Vector2(x - w * 0.05, y + w * 0.66), 28.0, glow)
	for i in 3:
		anims.append({"type": "airship", "layer": 1, "pos": Vector2(rng.randf_range(X0, X1), rng.randf_range(200, 420)), "speed": rng.randf_range(14, 28)})
	_ridge(1, 690, 36, 240, _haze(p.mid, 0.1), 3)
	# Wizard towers on the ridge: tall, slender, with glowing windows and crystal finials.
	for x: float in _xs(760, 240):
		var h := rng.randf_range(150, 240)
		var tc: Color = p.mid.darkened(0.15)
		_rect(1, Rect2(x - 14, 690 - h, 28, h), tc)
		_tri(1, Vector2(x - 20, 690 - h), Vector2(x + 20, 690 - h), Vector2(x, 690 - h - 60), tc.darkened(0.25))
		for k in int(h / 40):
			_rect(1, Rect2(x - 3, 690 - h + 20 + k * 40, 6, 12), Color(glow, 0.6))
		_circle(1, Vector2(x, 690 - h - 66), 5, glow)
		_glow(1, Vector2(x, 690 - h - 66), 26.0, glow)
	_ridge(2, 730, 14, 200, p.near.darkened(0.05), 2)
	# Near: crystal lamp posts along a low stone wall.
	for x: float in _xs(560, 160):
		var w := rng.randf_range(140, 240)
		for k in int(w / 20):
			_rect(3, Rect2(x + k * 20, 738 - (k % 2) * 2, 19, 14 + (k % 2) * 2), p.near.lightened(0.04 * (k % 3)))
		_line(3, Vector2(x - 20, 752), Vector2(x - 20, 690), 3, Color("2a2230"))
		_tri(3, Vector2(x - 26, 690), Vector2(x - 14, 690), Vector2(x - 20, 672), Color(glow, 0.9))
		anims.append({"type": "lamp", "layer": 3, "pos": Vector2(x - 20, 684), "col": glow, "r": 50.0})


# ---------------------------------------------------------------------------
# Elves: forests through the ages

func _forest() -> void:
	var p := palette
	var leaf: Color = p.leaf
	var glow: Color = p.light
	_ridge(0, 600 if age != 6 else 640, 50, 280, _haze(p.far, 0.4), 4)
	if age == 2:
		# River glinting between the hills.
		_rect(0, Rect2(X0, 640, X1 - X0, 40), _haze(Color("6ab0d8"), 0.2))
		anims.append({"type": "shimmer", "layer": 0, "col": Color(1, 1, 1, 0.22)})
	# Distant canopy line.
	var far_canopy := _haze(p.mid, 0.35)
	for x: float in _xs(60, 20):
		var r := rng.randf_range(34, 60)
		_add(1, {"poly": _blob(Vector2(x, 650 - r * 0.4), Vector2(r, r * 0.8), 10), "col": far_canopy.darkened(rng.randf() * 0.08)})
	_rect(1, Rect2(X0, 650, X1 - X0, 110), far_canopy.darkened(0.1))
	if age == 4 or age == 5:
		# White elven towers rising above the canopy.
		for x: float in _xs(900, 260):
			var h := rng.randf_range(200, 300)
			var tc := _haze(Color("e8e4dc"), 0.3 if age == 4 else 0.45)
			_rect(1, Rect2(x - 9, 650 - h, 18, h), tc)
			_add(1, {"poly": PackedVector2Array([Vector2(x - 16, 650 - h), Vector2(x, 650 - h - 70), Vector2(x + 16, 650 - h), Vector2(x, 650 - h + 10)]), "col": tc.lerp(leaf, 0.3)})
			_rect(1, Rect2(x - 14, 650 - h * 0.55, 28, 6), tc.darkened(0.1))
			if age == 5:
				_glow(1, Vector2(x, 650 - h - 20), 20.0, glow)
	if age == 6:
		for x: float in _xs(700, 200):
			var y := rng.randf_range(360, 520)
			_add(1, {"poly": PackedVector2Array([Vector2(x, y - 24), Vector2(x + 8, y), Vector2(x, y + 24), Vector2(x - 8, y)]), "col": Color(glow, 0.8)})
			_glow(1, Vector2(x, y), 34.0, glow)
	# Mid trunks and canopies.
	_ridge(2, 736, 12, 200, p.mid.darkened(0.12), 2)
	var bark: Color = p.near
	for x: float in _xs(300 if age != 3 else 380, 100):
		var w := rng.randf_range(16, 28) * (1.6 if age == 3 else 1.0)
		var tc := _haze(bark, 0.25)
		if age == 2:
			tc = _haze(Color("e8e4d8"), 0.15)
		_add(2, {"poly": PackedVector2Array([Vector2(x - w * 0.9, 740), Vector2(x - w * 0.5, 700), Vector2(x - w * 0.45, 260), Vector2(x + w * 0.45, 260), Vector2(x + w * 0.5, 700), Vector2(x + w * 0.9, 740)]), "col": tc})
		if age == 2:
			for k in 6:
				_line(2, Vector2(x - w * 0.4, 300 + k * 70 + rng.randf() * 20), Vector2(x + w * 0.1, 300 + k * 70 + rng.randf() * 20), 2, Color(0.2, 0.2, 0.2, 0.6))
		var lc := _haze(leaf, 0.2)
		for k in 4:
			_add(2, {"poly": _blob(Vector2(x + rng.randf_range(-70, 70), rng.randf_range(160, 330)), Vector2(rng.randf_range(60, 100), rng.randf_range(40, 60)), 12), "col": lc.darkened(rng.randf() * 0.12)})
		if age == 6:
			for k in 3:
				_glow(2, Vector2(x + rng.randf_range(-60, 60), rng.randf_range(200, 320)), 18.0, glow)
	# Tree-halls on the giant trunks (Iron onward): platforms, rails and lanterns.
	if age >= 3:
		for x: float in _xs(760, 200):
			var y := rng.randf_range(460, 600)
			var wood := _haze(Color("7a5a3a"), 0.2)
			_rect(2, Rect2(x - 60, y, 120, 8), wood)
			_line(2, Vector2(x - 60, y + 8), Vector2(x - 30, y + 40), 3, wood.darkened(0.2))
			_line(2, Vector2(x + 60, y + 8), Vector2(x + 30, y + 40), 3, wood.darkened(0.2))
			_rect(2, Rect2(x - 40, y - 34, 80, 34), wood.lightened(0.05))
			_add(2, {"poly": PackedVector2Array([Vector2(x - 50, y - 34), Vector2(x, y - 64), Vector2(x + 50, y - 34)]), "col": _haze(leaf, 0.15).darkened(0.1)})
			_rect(2, Rect2(x - 8, y - 24, 16, 24), Color(glow.lerp(Color(1.0, 0.8, 0.4), 0.6), 0.7))
			anims.append({"type": "lamp", "layer": 2, "pos": Vector2(x + 44, y + 16), "col": Color(1.0, 0.85, 0.5), "r": 40.0})
	if age == 5:
		for x: float in _xs(500, 160):
			anims.append({"type": "drift_smoke", "layer": 2, "pos": Vector2(x, 700), "col": Color(0.85, 0.95, 1.0, 0.25)})
	# Near: mossy trunks, roots, standing stones, undergrowth.
	for x: float in _xs(560, 180):
		var w := rng.randf_range(30, 46)
		var nc := bark.darkened(0.15)
		_add(3, {"poly": PackedVector2Array([Vector2(x - w * 1.3, 754), Vector2(x - w * 0.55, 720), Vector2(x - w * 0.5, 120), Vector2(x + w * 0.5, 120), Vector2(x + w * 0.6, 720), Vector2(x + w * 1.4, 754)]), "col": nc})
		_line(3, Vector2(x - w * 0.2, 700), Vector2(x - w * 0.25, 200), 2, nc.darkened(0.2))
		_add(3, {"poly": _blob(Vector2(x - w * 0.3, 690), Vector2(w * 0.35, 14), 8), "col": leaf.darkened(0.2)})
		for k in 2:
			_add(3, {"poly": _blob(Vector2(x + rng.randf_range(-90, 90), rng.randf_range(40, 130)), Vector2(rng.randf_range(90, 140), rng.randf_range(50, 70)), 12), "col": leaf.darkened(0.25 + rng.randf() * 0.1)})
	if age == 2:
		for x: float in _xs(900, 200):
			for k in 3:
				var sx := x + k * 36
				var sh := rng.randf_range(40, 60)
				_add(3, {"poly": PackedVector2Array([Vector2(sx - 9, 752), Vector2(sx - 7, 752 - sh), Vector2(sx + 2, 752 - sh - 6), Vector2(sx + 9, 752 - sh + 4), Vector2(sx + 9, 752)]), "col": Color("8a8a80")})
	for x: float in _xs(160, 60):
		_fern(3, x, 752, rng.randf_range(0.7, 1.1), leaf.darkened(0.15))


func _fern(layer: int, x: float, y: float, s: float, col: Color) -> void:
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.45
		var tip := Vector2(x, y) + Vector2(cos(a), sin(a)) * 30 * s
		_add(layer, {"poly": PackedVector2Array([Vector2(x - 2, y), tip, Vector2(x + 2, y)]), "col": col.darkened(0.05 * k)})


# ---------------------------------------------------------------------------
# Dwarves: mountains through the ages

func _mountains() -> void:
	var p := palette
	var glow: Color = p.light
	var snow := age in [1, 3]
	# Far peaks with snowcaps.
	for x: float in _xs(360, 140):
		var h := rng.randf_range(220, 380)
		var w := rng.randf_range(200, 320)
		var col := _haze(p.far, 0.3)
		_add(0, {"poly": PackedVector2Array([Vector2(x - w, 700), Vector2(x - w * 0.2, 700 - h + 20), Vector2(x, 700 - h), Vector2(x + w * 0.3, 700 - h + 30), Vector2(x + w, 700)]), "col": col})
		if snow or age == 6:
			var sc := Color("eef2f6") if age != 6 else _haze(Color("4a4a70"), 0.2)
			_add(0, {"poly": PackedVector2Array([Vector2(x - w * 0.22, 700 - h + 50), Vector2(x - w * 0.2, 700 - h + 20), Vector2(x, 700 - h), Vector2(x + w * 0.3, 700 - h + 30), Vector2(x + w * 0.32, 700 - h + 58), Vector2(x + w * 0.05, 700 - h + 44)]), "col": sc})
	# Mid cliffs.
	_ridge(1, 640 if age != 2 else 610, 70, 220, _haze(p.mid, 0.15), 24, 24)
	match age:
		2:
			# Guardians carved into the canyon walls: helmed, bearded, leaning on great axes.
			for x: float in _xs(1300, 300):
				var c := _haze(p.mid.lightened(0.15), 0.1)
				_rect(1, Rect2(x - 56, 640, 112, 24), c.darkened(0.1))
				_add(1, {"poly": PackedVector2Array([Vector2(x - 40, 640), Vector2(x - 52, 520), Vector2(x - 30, 490), Vector2(x + 30, 490), Vector2(x + 52, 520), Vector2(x + 40, 640)]), "col": c})
				_add(1, {"poly": _blob(Vector2(x, 468), Vector2(24, 24), 12), "col": c.lightened(0.04)})
				_add(1, {"poly": PackedVector2Array([Vector2(x - 26, 462), Vector2(x - 22, 440), Vector2(x, 430), Vector2(x + 22, 440), Vector2(x + 26, 462)]), "col": c.darkened(0.18)})
				_add(1, {"poly": PackedVector2Array([Vector2(x - 22, 474), Vector2(x + 22, 474), Vector2(x + 10, 560), Vector2(x, 574), Vector2(x - 10, 560)]), "col": c.darkened(0.08)})
				_line(1, Vector2(x, 500), Vector2(x, 650), 6, c.darkened(0.25))
				_add(1, {"poly": PackedVector2Array([Vector2(x - 4, 504), Vector2(x - 34, 490), Vector2(x - 38, 530), Vector2(x - 4, 520)]), "col": c.darkened(0.14)})
				_add(1, {"poly": PackedVector2Array([Vector2(x + 4, 504), Vector2(x + 34, 490), Vector2(x + 38, 530), Vector2(x + 4, 520)]), "col": c.darkened(0.2)})
		3:
			# Great gates carved into the mountain, braziers either side.
			for x: float in _xs(1400, 300):
				var c := _haze(p.mid.lightened(0.08), 0.12)
				_rect(1, Rect2(x - 110, 470, 220, 190), c)
				_add(1, {"poly": PackedVector2Array([Vector2(x - 120, 470), Vector2(x + 120, 470), Vector2(x + 80, 420), Vector2(x - 80, 420)]), "col": c.darkened(0.08)})
				_rect(1, Rect2(x - 50, 540, 100, 120), c.darkened(0.45))
				_line(1, Vector2(x, 540), Vector2(x, 660), 3, c.darkened(0.25))
				for k in 4:
					_line(1, Vector2(x - 90 + k * 60, 480), Vector2(x - 90 + k * 60, 660), 2, c.darkened(0.15))
				for bx in [x - 80, x + 80]:
					_rect(1, Rect2(bx - 6, 610, 12, 50), c.darkened(0.3))
					_circle(1, Vector2(bx, 606), 7, Color("ffb050"))
					anims.append({"type": "lamp", "layer": 1, "pos": Vector2(bx, 600), "col": Color("ffb050"), "r": 60.0})
		4:
			# Forge mouths and chimneys glowing in the cliffs.
			for x: float in _xs(600, 200):
				var y := rng.randf_range(560, 640)
				_add(1, {"poly": PackedVector2Array([Vector2(x - 26, y + 40), Vector2(x - 26, y), Vector2(x, y - 16), Vector2(x + 26, y), Vector2(x + 26, y + 40)]), "col": Color(1.0, 0.55, 0.2, 0.85)})
				_glow(1, Vector2(x, y + 10), 50.0, Color(1.0, 0.55, 0.2))
				_rect(1, Rect2(x + 40, y - 120, 16, 150), _haze(p.mid.darkened(0.2), 0.1))
				anims.append({"type": "smoke", "layer": 1, "pos": Vector2(x + 48, y - 120), "col": Color(0.25, 0.22, 0.22, 0.45), "rate": 1.0})
		5:
			_steamworks()
		6:
			# Rune lines glowing along the cliff faces; floating runestones.
			for x: float in _xs(420, 140):
				var y := rng.randf_range(520, 640)
				var pts := PackedVector2Array([Vector2(x, y), Vector2(x + 12, y - 18), Vector2(x + 24, y), Vector2(x + 36, y - 18)])
				anims.append({"type": "rune", "layer": 1, "pts": pts, "col": glow})
			for x: float in _xs(800, 240):
				var y := rng.randf_range(380, 500)
				_add(1, {"poly": PackedVector2Array([Vector2(x - 12, y + 20), Vector2(x - 14, y - 16), Vector2(x, y - 26), Vector2(x + 14, y - 14), Vector2(x + 12, y + 22)]), "col": _haze(p.mid.lightened(0.1), 0.1)})
				anims.append({"type": "rune", "layer": 1, "pts": PackedVector2Array([Vector2(x - 5, y - 8), Vector2(x, y + 4), Vector2(x + 5, y - 8)]), "col": glow})
				_glow(1, Vector2(x, y), 30.0, glow)
	_ridge(2, 722, 22, 180, p.near.lightened(0.08), 8, 26)
	# Near: pines (highlands and snow), boulders, cairns.
	if age in [1, 3]:
		for x: float in _xs(240, 90):
			_pine(3, x, 752, rng.randf_range(0.9, 1.4), Color("2e4a38") if age == 1 else Color("30443c"), age == 3)
	for x: float in _xs(420, 140):
		var s := rng.randf_range(16, 30)
		_add(3, {"poly": _blob(Vector2(x, 752 - s * 0.5), Vector2(s * 1.4, s), 9), "col": p.near.lightened(0.05)})
	if age <= 2:
		for x: float in _xs(900, 200):
			for k in 4:
				_add(3, {"poly": _blob(Vector2(x, 746 - k * 12), Vector2(12 - k * 2, 6), 8), "col": Color("8a8478").darkened(0.05 * k)})
	if age == 4 or age == 6:
		for x: float in _xs(700, 200):
			_rect(3, Rect2(x - 5, 712, 10, 40), Color("3a3230"))
			_circle(3, Vector2(x, 708), 7, Color("ffb050") if age == 4 else glow)
			anims.append({"type": "lamp", "layer": 3, "pos": Vector2(x, 704), "col": Color("ffb050") if age == 4 else glow, "r": 50.0})


func _steamworks() -> void:
	var p := palette
	for x: float in _xs(300, 100):
		var w := rng.randf_range(70, 150)
		var h := rng.randf_range(40, 110)
		_rect(1, Rect2(x, 640 - h, w, h + 40), _haze(p.far, 0.2))
		for k in int(w / 22):
			_tri(1, Vector2(x + k * 22, 640 - h), Vector2(x + k * 22 + 22, 640 - h), Vector2(x + k * 22 + 22, 640 - h - 12), _haze(p.far, 0.16))
		for r in int(h / 30):
			for k in int(w / 24):
				if rng.randf() < 0.45:
					_rect(1, Rect2(x + 6 + k * 24, 650 - h + r * 30, 10, 12), Color(1.0, 0.62, 0.25, rng.randf_range(0.15, 0.45)))
		if rng.randf() < 0.6:
			var cx := x + rng.randf_range(10, w - 20)
			var ch := rng.randf_range(80, 160)
			_rect(1, Rect2(cx, 640 - h - ch, 14, ch), _haze(p.far, 0.15))
			anims.append({"type": "smoke", "layer": 1, "pos": Vector2(cx + 7, 640 - h - ch), "col": Color(0.3, 0.26, 0.26, 0.4), "rate": 1.0})
	# Pipes along the valley with valve wheels.
	_rect(1, Rect2(X0, 676, X1 - X0, 8), Color("6a5a40"))
	for x: float in _xs(240, 60):
		_circle(1, Vector2(x, 680), 7, Color("8a6a3a"))
		_line(1, Vector2(x, 684), Vector2(x, 740), 4, Color("4a3a2a"))


# ---------------------------------------------------------------------------
# Foreground props

func _front() -> void:
	var p := palette
	var dark: Color = p.ground[1].darkened(0.45)
	var glow: Color = p.light
	var y0 := GROUND_Y + 130.0
	for x: float in _xs(760, 260):
		match p.front:
			"grass":
				for k in 7:
					var h := rng.randf_range(40, 110)
					var bx := x + k * 9.0
					front.append({"poly": PackedVector2Array([Vector2(bx - 4, y0 + 200), Vector2(bx + rng.randf_range(-14, 14), y0 - h), Vector2(bx + 5, y0 + 200)]), "col": dark.lerp(Color("4f5a2a"), 0.3)})
				front.append({"poly": _blob(Vector2(x + 120, y0 + 60), Vector2(70, 40), 10), "col": dark})
			"tallgrass", "reeds":
				for k in 9:
					var h := rng.randf_range(50, 130) * (1.3 if p.front == "reeds" else 1.0)
					var bx := x + k * 7.0
					front.append({"poly": PackedVector2Array([Vector2(bx - 3, y0 + 200), Vector2(bx + rng.randf_range(-20, 20), y0 - h), Vector2(bx + 4, y0 + 200)]), "col": dark.lerp(Color("2e4020"), 0.5)})
			"gabion":
				front.append({"poly": _blob(Vector2(x, y0 + 50), Vector2(110, 60), 9), "col": dark})
				front.append({"poly": PackedVector2Array([Vector2(x + 60, y0 + 100), Vector2(x + 90, y0 - 70), Vector2(x + 100, y0 - 66), Vector2(x + 80, y0 + 100)]), "col": dark.lightened(0.05)})
			"ferns":
				for k in 7:
					var a := -PI * 0.5 + (k - 3) * 0.32
					var tip := Vector2(x, y0 + 80) + Vector2(cos(a), sin(a)) * rng.randf_range(110, 170)
					front.append({"poly": PackedVector2Array([Vector2(x - 6, y0 + 90), tip, Vector2(x + 6, y0 + 90)]), "col": dark.lerp(Color("24401e"), 0.4).darkened(0.04 * k)})
				front.append({"poly": _blob(Vector2(x + 150, y0 + 70), Vector2(80, 44), 10), "col": dark})
			"rocks":
				front.append({"poly": _blob(Vector2(x, y0 + 50), Vector2(120, 70), 9), "col": dark})
				front.append({"poly": _blob(Vector2(x + 110, y0 + 70), Vector2(60, 40), 8), "col": dark.lightened(0.04)})
			"pipes":
				front.append({"line": Vector2(x - 40, y0 - 10), "to": Vector2(x + 220, y0 - 10), "w": 14, "col": dark})
				front.append({"line": Vector2(x + 180, y0 - 10), "to": Vector2(x + 180, y0 + 200), "w": 14, "col": dark})
				front.append({"circle": Vector2(x + 60, y0 - 10), "r": 18.0, "col": dark.lightened(0.06)})
			"crystals", "mushrooms", "runestones":
				front.append({"poly": _blob(Vector2(x, y0 + 60), Vector2(110, 60), 9), "col": dark})
				for k in 3:
					var bx := x - 30 + k * 34
					var h := rng.randf_range(60, 120)
					match p.front:
						"crystals":
							front.append({"poly": PackedVector2Array([Vector2(bx - 10, y0 + 40), Vector2(bx - 4, y0 - h), Vector2(bx + 10, y0 + 40)]), "col": dark.lerp(glow, 0.12)})
							front.append({"line": Vector2(bx - 4, y0 - h), "to": Vector2(bx + 6, y0 + 20), "w": 1.5, "col": Color(glow, 0.5)})
						"mushrooms":
							front.append({"line": Vector2(bx, y0 + 40), "to": Vector2(bx + 4, y0 - h * 0.5), "w": 8.0, "col": dark.lightened(0.05)})
							front.append({"poly": _blob(Vector2(bx + 4, y0 - h * 0.5), Vector2(26, 12), 10), "col": dark.lerp(glow, 0.15)})
							front.append({"circle": Vector2(bx + 10, y0 - h * 0.5 - 4), "r": 2.5, "col": Color(glow, 0.8)})
						_:
							front.append({"poly": PackedVector2Array([Vector2(bx - 12, y0 + 40), Vector2(bx - 10, y0 - h * 0.7), Vector2(bx + 4, y0 - h * 0.8), Vector2(bx + 12, y0 + 40)]), "col": dark.lightened(0.04)})
							front.append({"polyline": PackedVector2Array([Vector2(bx - 4, y0 - h * 0.5), Vector2(bx, y0 - h * 0.35), Vector2(bx + 4, y0 - h * 0.5)]), "w": 2.0, "col": Color(glow, 0.7)})
