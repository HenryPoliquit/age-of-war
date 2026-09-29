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
	_anim_bounds()
	weather = palette.weather


## Gives each animation that stays in one place the horizontal extent it needs, so the backdrop can skip it off screen.
func _anim_bounds() -> void:
	for a in anims:
		var lo := INF
		var hi := -INF
		var pad := 120.0
		match a.type:
			"smoke", "flag", "lamp", "glow", "sails", "wheel":
				lo = a.pos.x
				hi = a.pos.x
				pad = 260.0 if a.type in ["smoke", "drift_smoke"] else 90.0
			"cart", "rune":
				for v in a.pts:
					lo = minf(lo, v.x)
					hi = maxf(hi, v.x)
			"bucket":
				lo = minf(a.a.x, a.b.x)
				hi = maxf(a.a.x, a.b.x)
			"fall":
				lo = a.top.x
				hi = a.top.x
			"drift_smoke":
				lo = a.pos.x
				hi = a.pos.x
				pad = 260.0
		if lo < INF:
			a["ax0"] = lo - pad
			a["ax1"] = hi + pad


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
	# Horizontal extent, so the backdrop can skip shapes that are off screen.
	var lo_x := INF
	var hi_x := -INF
	if shape.has("poly"):
		for v in shape.poly:
			lo_x = minf(lo_x, v.x)
			hi_x = maxf(hi_x, v.x)
	elif shape.has("circle"):
		lo_x = shape.circle.x - shape.r
		hi_x = shape.circle.x + shape.r
	elif shape.has("line"):
		lo_x = minf(shape.line.x, shape.to.x) - shape.w
		hi_x = maxf(shape.line.x, shape.to.x) + shape.w
	elif shape.has("polyline"):
		for v in shape.polyline:
			lo_x = minf(lo_x, v.x)
			hi_x = maxf(hi_x, v.x)
		lo_x -= shape.w
		hi_x += shape.w
	elif shape.has("grad"):
		lo_x = shape.grad.position.x
		hi_x = shape.grad.end.x
	if lo_x < INF:
		shape["x0"] = lo_x
		shape["x1"] = hi_x
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

# --- Human scenery helpers -------------------------------------------------

func _tent(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_tri(layer, Vector2(x - 34 * s, y), Vector2(x + 34 * s, y), Vector2(x, y - 58 * s), col)
	_tri(layer, Vector2(x + 4 * s, y), Vector2(x + 34 * s, y), Vector2(x, y - 58 * s), col.darkened(0.16))
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 8 * s, y), Vector2(x - 2 * s, y - 24 * s), Vector2(x + 6 * s, y)]), "col": Color(0.08, 0.06, 0.05)})
	_line(layer, Vector2(x, y - 58 * s), Vector2(x - 4 * s, y - 72 * s), 2.0, col.darkened(0.4))
	_line(layer, Vector2(x, y - 58 * s), Vector2(x + 6 * s, y - 72 * s), 2.0, col.darkened(0.4))


func _mammoth(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_add(layer, {"poly": _blob(Vector2(x, y - 26 * s), Vector2(34 * s, 20 * s), 12), "col": col})
	_add(layer, {"poly": _blob(Vector2(x + 26 * s, y - 34 * s), Vector2(15 * s, 17 * s), 10), "col": col})
	_add(layer, {"poly": PackedVector2Array([Vector2(x + 36 * s, y - 34 * s), Vector2(x + 48 * s, y - 14 * s), Vector2(x + 44 * s, y - 6 * s), Vector2(x + 38 * s, y - 20 * s)]), "col": col})
	_add(layer, {"poly": PackedVector2Array([Vector2(x + 34 * s, y - 24 * s), Vector2(x + 52 * s, y - 20 * s), Vector2(x + 44 * s, y - 27 * s)]), "col": Color("d8cbb0")})
	for lx in [-22.0, -8.0, 10.0, 24.0]:
		_line(layer, Vector2(x + lx * s, y - 14 * s), Vector2(x + lx * s, y), 7.0 * s, col.darkened(0.1))


func _volcano(layer: int, x: float, base_y: float, w: float, h: float, col: Color) -> void:
	_add(layer, {"poly": PackedVector2Array([Vector2(x - w, base_y), Vector2(x - w * 0.16, base_y - h), Vector2(x + w * 0.16, base_y - h), Vector2(x + w, base_y)]), "col": col})
	_add(layer, {"poly": PackedVector2Array([Vector2(x + w * 0.16, base_y - h), Vector2(x + w, base_y), Vector2(x + w * 0.2, base_y)]), "col": col.darkened(0.18)})
	_add(layer, {"poly": PackedVector2Array([Vector2(x - w * 0.16, base_y - h), Vector2(x, base_y - h - 10), Vector2(x + w * 0.16, base_y - h), Vector2(x, base_y - h + 8)]), "col": Color(1.0, 0.5, 0.2)})
	for k in 3:
		_add(layer, {"polyline": PackedVector2Array([Vector2(x - w * 0.05 + k * w * 0.08, base_y - h + 10), Vector2(x - w * 0.2 + k * w * 0.2, base_y - h * 0.5), Vector2(x - w * 0.3 + k * w * 0.32, base_y - h * 0.1)]), "w": 3.0, "col": Color(1.0, 0.5, 0.2, 0.7)})
	_glow(layer, Vector2(x, base_y - h), 60.0, Color(1.0, 0.5, 0.2))
	anims.append({"type": "smoke", "layer": layer, "pos": Vector2(x, base_y - h - 8), "col": Color(0.3, 0.26, 0.26, 0.5), "rate": 1.0})


func _hill_town(layer: int, x0: float, x1: float, y_top: float) -> void:
	var cx := x0
	while cx < x1 - 24.0:
		var bw := rng.randf_range(22, 40)
		var bh := rng.randf_range(20, 36)
		var wall := Color("f0ece0").darkened(rng.randf() * 0.08)
		_rect(layer, Rect2(cx, y_top - bh, bw, bh), wall)
		_rect(layer, Rect2(cx + bw * 0.6, y_top - bh, bw * 0.4, bh), wall.darkened(0.1))
		_rect(layer, Rect2(cx + bw * 0.2, y_top - bh * 0.6, 5, 9), Color(0.16, 0.2, 0.3))
		if rng.randf() < 0.35:
			_add(layer, {"poly": PackedVector2Array([Vector2(cx + 3, y_top - bh), Vector2(cx + bw * 0.5, y_top - bh - bw * 0.42), Vector2(cx + bw - 3, y_top - bh)]), "col": Color("3f7fc0")})
		cx += bw + rng.randf_range(1, 6)


func _lighthouse(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 16 * s, y), Vector2(x - 9 * s, y - 150 * s), Vector2(x + 9 * s, y - 150 * s), Vector2(x + 16 * s, y)]), "col": col})
	for k in 3:
		_rect(layer, Rect2(x - (14 - k * 2.4) * s, y - (40 + k * 40) * s, (28 - k * 4.8) * s, 12 * s), Color("b8503a"))
	_rect(layer, Rect2(x - 12 * s, y - 166 * s, 24 * s, 16 * s), Color(1.0, 0.9, 0.6))
	_tri(layer, Vector2(x - 15 * s, y - 166 * s), Vector2(x + 15 * s, y - 166 * s), Vector2(x, y - 190 * s), Color("b8503a"))
	_glow(layer, Vector2(x, y - 158 * s), 46.0 * s, Color(1.0, 0.9, 0.6))
	anims.append({"type": "lamp", "layer": layer, "pos": Vector2(x, y - 158 * s), "col": Color(1.0, 0.9, 0.6), "r": 70.0 * s})


func _windmill(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 20 * s, y), Vector2(x - 12 * s, y - 70 * s), Vector2(x + 12 * s, y - 70 * s), Vector2(x + 20 * s, y)]), "col": col})
	_add(layer, {"poly": PackedVector2Array([Vector2(x + 2 * s, y), Vector2(x + 12 * s, y - 70 * s), Vector2(x + 20 * s, y)]), "col": col.darkened(0.14)})
	_tri(layer, Vector2(x - 16 * s, y - 70 * s), Vector2(x + 16 * s, y - 70 * s), Vector2(x, y - 90 * s), col.darkened(0.3))
	_rect(layer, Rect2(x - 4 * s, y - 20 * s, 8 * s, 20 * s), Color(0.15, 0.12, 0.1))
	anims.append({"type": "sails", "layer": layer, "pos": Vector2(x, y - 66 * s), "len": 46.0 * s, "col": Color("e8dcc0")})


func _church(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_rect(layer, Rect2(x - 40 * s, y - 40 * s, 80 * s, 40 * s), col)
	_tri(layer, Vector2(x - 46 * s, y - 40 * s), Vector2(x + 46 * s, y - 40 * s), Vector2(x, y - 66 * s), col.darkened(0.3))
	_rect(layer, Rect2(x + 30 * s, y - 100 * s, 22 * s, 100 * s), col.lightened(0.04))
	_tri(layer, Vector2(x + 27 * s, y - 100 * s), Vector2(x + 55 * s, y - 100 * s), Vector2(x + 41 * s, y - 148 * s), col.darkened(0.32))
	_line(layer, Vector2(x + 41 * s, y - 148 * s), Vector2(x + 41 * s, y - 162 * s), 2.0, Color("d9b25c"))
	_line(layer, Vector2(x + 35 * s, y - 158 * s), Vector2(x + 47 * s, y - 158 * s), 2.0, Color("d9b25c"))
	_rect(layer, Rect2(x + 37 * s, y - 84 * s, 8 * s, 14 * s), Color(0.12, 0.1, 0.1))
	for k in 3:
		_rect(layer, Rect2(x - 30 * s + k * 22 * s, y - 28 * s, 8 * s, 14 * s), Color(0.12, 0.1, 0.1))


func _village(layer: int, x: float, y: float, n: int, roof: Color, wall: Color) -> void:
	var hx := x
	for k in n:
		var w := rng.randf_range(30, 46)
		var h := rng.randf_range(22, 34)
		_rect(layer, Rect2(hx, y - h, w, h), wall.darkened(rng.randf() * 0.1))
		_rect(layer, Rect2(hx + w * 0.5, y - h, w * 0.5, h), wall.darkened(0.16))
		_tri(layer, Vector2(hx - 5, y - h), Vector2(hx + w + 5, y - h), Vector2(hx + w * 0.5, y - h - w * 0.42), roof)
		_rect(layer, Rect2(hx + w * 0.16, y - h * 0.62, 6, 10), Color(1.0, 0.85, 0.5, 0.75))
		_rect(layer, Rect2(hx + w * 0.72, y - h - w * 0.36, 6, 14), roof.darkened(0.3))
		if rng.randf() < 0.4:
			anims.append({"type": "smoke", "layer": layer, "pos": Vector2(hx + w * 0.75, y - h - w * 0.4), "col": Color(0.85, 0.85, 0.85, 0.3), "rate": 0.6})
		hx += w + rng.randf_range(6, 18)


func _roman_city(layer: int, x: float, y: float, col: Color) -> void:
	_rect(layer, Rect2(x - 150, y - 56, 300, 56), col)
	for r in 4:
		_line(layer, Vector2(x - 150, y - 46 + r * 12), Vector2(x + 150, y - 46 + r * 12), 1.0, col.darkened(0.12))
	for k in 24:
		_rect(layer, Rect2(x - 150 + k * 12.5, y - 62, 7, 6), col)
	for tx in [-150.0, -50.0, 50.0, 150.0]:
		_rect(layer, Rect2(x + tx - 14, y - 96, 28, 96), col.darkened(0.06))
		_tri(layer, Vector2(x + tx - 18, y - 96), Vector2(x + tx + 18, y - 96), Vector2(x + tx, y - 124), Color("b0583a"))
	# Inside: red-tiled roofs, a domed hall, a column.
	for k in 5:
		var hx := x - 120 + k * 50
		_rect(layer, Rect2(hx, y - 84, 36, 28), Color("e6dcc6"))
		_tri(layer, Vector2(hx - 4, y - 84), Vector2(hx + 40, y - 84), Vector2(hx + 18, y - 102), Color("b0583a"))
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 26, y - 84), Vector2(x - 22, y - 116), Vector2(x, y - 130), Vector2(x + 22, y - 116), Vector2(x + 26, y - 84)]), "col": Color("d8ccb0")})
	_rect(layer, Rect2(x - 12, y - 30, 24, 30), Color(0.14, 0.1, 0.08))


func _factory(layer: int, x: float, y: float, w: float, h: float, col: Color, smoke: Color) -> void:
	_rect(layer, Rect2(x, y - h, w, h), col)
	for k in int(w / 26.0):
		_tri(layer, Vector2(x + k * 26, y - h), Vector2(x + k * 26 + 26, y - h), Vector2(x + k * 26 + 26, y - h - 14), col.darkened(0.18))
	for r in int(h / 26.0):
		for k in int(w / 24.0):
			_rect(layer, Rect2(x + 6 + k * 24, y - h + 10 + r * 26, 10, 12), Color(1.0, 0.75, 0.4, rng.randf_range(0.2, 0.7)))
	for k in rng.randi_range(1, 3):
		var cx := x + rng.randf_range(10, w - 20)
		var ch := rng.randf_range(60, 130)
		_rect(layer, Rect2(cx, y - h - ch, 12, ch), col.darkened(0.1))
		_rect(layer, Rect2(cx - 2, y - h - ch, 16, 5), col.darkened(0.3))
		anims.append({"type": "drift_smoke", "layer": layer, "pos": Vector2(cx + 6, y - h - ch), "col": smoke})


func _stone() -> void:
	var p := palette
	# A great range of red mesas, a smoking volcano far off, herds on the plain, stone circles and hide camps.
	for x: float in _xs(560, 180):
		_massif(0, x, 650, rng.randf_range(200, 300), rng.randf_range(200, 320), _haze(p.far, 0.5), Color(0, 0, 0, 0), 0.0)
	for x: float in _xs(2300, 700):
		_volcano(0, x, 660, rng.randf_range(260, 340), rng.randf_range(300, 380), _haze(Color("6a4a4a"), 0.4))
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
	for x: float in _xs(700, 220):
		for k in rng.randi_range(2, 4):
			_mammoth(1, x + k * 74, 690, rng.randf_range(0.8, 1.15), _haze(Color("4a3a30"), 0.3))
	for x: float in _xs(1000, 260):
		# A hide camp: tents round a fire, a drying rack.
		for k in 3:
			_tent(2, x + k * 84, 728, rng.randf_range(0.85, 1.2), Color("8a6440").darkened(0.05 * k))
		_line(2, Vector2(x + 250, 728), Vector2(x + 250, 690), 3.0, Color("4a3a2a"))
		_line(2, Vector2(x + 300, 728), Vector2(x + 300, 690), 3.0, Color("4a3a2a"))
		_line(2, Vector2(x + 246, 696), Vector2(x + 304, 696), 2.0, Color("4a3a2a"))
		for k in 4:
			_rect(2, Rect2(x + 252 + k * 13, 696, 9, 18), Color("b0946a"))
	for x: float in _xs(1500, 400):
		# A ring of standing stones with two lintelled trilithons.
		for k in 6:
			var sh := rng.randf_range(34, 52)
			_add(2, {"poly": PackedVector2Array([Vector2(x + k * 34 - 8, 726), Vector2(x + k * 34 - 6, 726 - sh), Vector2(x + k * 34 + 8, 726 - sh + 4), Vector2(x + k * 34 + 9, 726)]), "col": p.mid.darkened(0.3)})
		_rect(2, Rect2(x + 26, 726 - 62, 48, 9), p.mid.darkened(0.34))
		_rect(2, Rect2(x + 130, 726 - 62, 48, 9), p.mid.darkened(0.34))


func _acacia(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_line(layer, Vector2(x, y), Vector2(x + 6 * s, y - 60 * s), 6 * s, col.darkened(0.2))
	_line(layer, Vector2(x + 4 * s, y - 40 * s), Vector2(x - 22 * s, y - 70 * s), 4 * s, col.darkened(0.2))
	for i in 3:
		var cx := x + (i - 1) * 30 * s + 4 * s
		_add(layer, {"poly": _blob(Vector2(cx, y - 76 * s), Vector2(34 * s, 9 * s)), "col": col.lerp(Color("4f5a2a"), 0.55)})


func _bronze() -> void:
	var p := palette
	for x: float in _xs(520, 160):
		_massif(0, x, 566, rng.randf_range(180, 260), rng.randf_range(160, 250), _haze(Color("6a8ab0"), 0.4), Color("f4f4f4"), 0.25)
	_rect(0, Rect2(X0, 560, X1 - X0, 200), p.far)                   # sea
	for k in 4:
		anims.append({"type": "ship", "layer": 0, "pos": Vector2(rng.randf_range(X0, X1), rng.randf_range(600, 690)), "speed": rng.randf_range(6.0, 12.0), "s": rng.randf_range(0.8, 1.2), "hull": Color("5a3a26"), "sail": Color("f2ead8")})
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
		# A white-washed town spilling down the cliff, blue domes, and a lighthouse at its foot.
		_hill_town(1, x - w * 0.18, x + w * 0.24, 704 - h)
		_hill_town(1, x - w * 0.3, x + w * 0.4, 704 - h * 0.55)
		if rng.randf() < 0.5:
			_lighthouse(1, x + w * 0.46, 740, rng.randf_range(0.8, 1.05), Color("efe8d8"))
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
	for x: float in _xs(560, 180):
		_massif(0, x, 640, rng.randf_range(200, 300), rng.randf_range(260, 400), _haze(Color("6a86a8"), 0.35), Color("f4f6fa"), 0.32)
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
	# A walled city on the hills, a legion camp with red pennants, vineyards on the slopes.
	for x: float in _xs(1700, 400):
		_roman_city(1, x, 668, _haze(Color("d6c8a8"), 0.25))
	for x: float in _xs(1200, 300):
		for k in 5:
			_tent(2, x + k * 60, 726, 0.85, Color("c8c0a8").darkened(0.04 * (k % 2)))
			_line(2, Vector2(x + k * 60, 726 - 50), Vector2(x + k * 60, 726 - 72), 1.6, Color("4a3a2a"))
			_tri(2, Vector2(x + k * 60, 726 - 72), Vector2(x + k * 60 + 14, 726 - 68), Vector2(x + k * 60, 726 - 64), Color("a83a32"))
		_line(2, Vector2(x - 12, 726), Vector2(x + 310, 726), 3.0, Color("6a4a30"))
	for x: float in _xs(500, 160):
		for k in 22:
			_line(2, Vector2(x + k * 7, 730), Vector2(x + k * 7 + 3, 722 - (k % 3)), 1.6, Color("4a6a30"))


func _medieval() -> void:
	var p := palette
	for x: float in _xs(600, 200):
		_massif(0, x, 630, rng.randf_range(220, 320), rng.randf_range(260, 380), _haze(Color("7a8898"), 0.4), Color("e8eef4"), 0.28)
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
	# Villages under the castles: thatched houses, a church, windmills turning, dark woods.
	for x: float in _xs(1300, 320):
		_village(2, x, 726, rng.randi_range(4, 6), Color("8a6a3a"), Color("d8ccb0"))
		_church(2, x + 300, 726, rng.randf_range(0.9, 1.15), Color("bcb8ac"))
	for x: float in _xs(900, 260):
		_windmill(2, x, 726, rng.randf_range(0.9, 1.25), Color("cfc4a8"))
	for x: float in _xs(420, 140):
		_pine(2, x, 728, rng.randf_range(0.8, 1.2), Color("2f4a34"))


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
	for x: float in _xs(400, 130):
		_factory(1, x, 660, rng.randf_range(80, 160), rng.randf_range(40, 90), _haze(Color("5a4e4a"), 0.25), Color(0.5, 0.48, 0.46, 0.32))
	for k in 6:
		anims.append({"type": "ship", "layer": 0, "pos": Vector2(rng.randf_range(X0, X1), rng.randf_range(625, 700)), "speed": rng.randf_range(10.0, 18.0), "s": rng.randf_range(1.0, 1.5), "hull": Color("2e2a2a"), "sail": Color("b8b0a0"), "funnel": true})
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
	anims.append({"type": "aurora", "layer": 0, "cols": [Color("6fe0ff"), Color("b070ff"), Color("ff70c8")]})
	# Ley lines: beams of violet light from the tower tips into the sky.
	for x: float in _xs(760, 240):
		_add(0, {"poly": PackedVector2Array([Vector2(x - 6, 200), Vector2(x + 6, 200), Vector2(x + 26, -300), Vector2(x - 26, -300)]), "cols": PackedColorArray([Color(glow, 0.18), Color(glow, 0.18), Color(glow, 0.0), Color(glow, 0.0)])})
	for x: float in _xs(1300, 400):
		# A cluster of crystal pylons on the ridge.
		for k in 5:
			var ch := rng.randf_range(50, 130)
			_add(2, {"poly": PackedVector2Array([Vector2(x + k * 16 - 8, 730), Vector2(x + k * 16 - 3, 730 - ch), Vector2(x + k * 16 + 8, 730)]), "col": Color(glow, 0.55).lerp(p.mid, 0.3)})
		_glow(2, Vector2(x + 32, 690), 46.0, glow)
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
# Elves: the world tree and its forest through the ages

## A limb: a tapered ribbon along a quadratic curve a → b → c, `w0` wide at a and `w1` at c.
func _limb(layer: int, a: Vector2, b: Vector2, c: Vector2, w0: float, w1: float, col: Color) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var pt := a * (1.0 - t) * (1.0 - t) + b * 2.0 * (1.0 - t) * t + c * t * t
		var tangent := ((b - a) * 2.0 * (1.0 - t) + (c - b) * 2.0 * t).normalized()
		var nrm := Vector2(-tangent.y, tangent.x)
		var w := lerpf(w0, w1, t) * 0.5
		left.append(pt + nrm * w)
		right.append(pt - nrm * w)
	right.reverse()
	left.append_array(right)
	_add(layer, {"poly": left, "col": col})


func _crown_edge(x: float, edge: float, amp: float, ph: Vector2) -> float:
	return edge + amp * (0.5 * sin(x / 210.0 + ph.x) + 0.5 * sin(x / 71.0 + ph.y))


## The crown of the world tree seen from below: a mass hanging from the top of the view with a ragged underside of leaf
## clusters and lighter clumps on its face. Returns the phases of its edge, for hanging things from it.
func _crown(layer: int, edge: float, amp: float, col: Color, spacing: float, size: float) -> Vector2:
	var ph := Vector2(rng.randf() * TAU, rng.randf() * TAU)
	var pts := PackedVector2Array([Vector2(X0, -420)])
	var x := X0
	while x <= X1:
		pts.append(Vector2(x, _crown_edge(x, edge, amp, ph) + absf(sin(x / 19.0)) * 9.0))
		x += 30.0
	pts.append(Vector2(X1, -420))
	_add(layer, {"poly": pts, "col": col})
	for cx: float in _xs(spacing, spacing * 0.4):
		var ey := _crown_edge(cx, edge, amp, ph)
		var r := rng.randf_range(38, 74) * size
		_add(layer, {"poly": _blob(Vector2(cx, ey + rng.randf_range(-6, 20)), Vector2(r, r * 0.62), 12), "col": col.darkened(rng.randf_range(0.02, 0.14))})
		_add(layer, {"poly": _blob(Vector2(cx + rng.randf_range(-40, 40), rng.randf_range(edge - 190, ey - 30)), Vector2(r * 1.1, r * 0.7), 12), "col": col.lightened(rng.randf_range(0.02, 0.16))})
	# A fringe of small leaf tufts along the ragged underside.
	x = X0
	while x <= X1:
		var ty := _crown_edge(x, edge, amp, ph) + absf(sin(x / 19.0)) * 9.0
		var l := rng.randf_range(10, 26) * size
		_add(layer, {"poly": PackedVector2Array([Vector2(x - 9, ty - 6), Vector2(x - 5, ty + l * 0.7), Vector2(x, ty + l), Vector2(x + 6, ty + l * 0.6), Vector2(x + 10, ty - 6)]), "col": col.darkened(rng.randf_range(0.02, 0.2))})
		x += rng.randf_range(15, 28)
	return ph


## A leafy clump: several overlapping blobs of slightly different tone rather than one flat disc.
func _leaf_clump(layer: int, c: Vector2, r: Vector2, col: Color) -> void:
	for k in 5:
		var o := Vector2(rng.randf_range(-r.x * 0.5, r.x * 0.5), rng.randf_range(-r.y * 0.4, r.y * 0.4))
		_add(layer, {"poly": _blob(c + o, r * rng.randf_range(0.5, 0.78), 11), "col": col.darkened(rng.randf() * 0.14).lightened(rng.randf() * 0.05)})


## Vines hanging from a crown's edge, some ending in a leaf.
func _vines(layer: int, edge: float, amp: float, ph: Vector2, col: Color, spacing: float) -> void:
	for x: float in _xs(spacing, spacing * 0.5):
		var y0 := _crown_edge(x, edge, amp, ph) + 8.0
		var length := rng.randf_range(30, 130)
		var sway := rng.randf_range(-12, 12)
		_add(layer, {"polyline": PackedVector2Array([Vector2(x, y0), Vector2(x + sway * 0.4, y0 + length * 0.5), Vector2(x + sway, y0 + length)]), "w": 2.2, "col": col})
		if length > 70.0:
			_add(layer, {"poly": _blob(Vector2(x + sway, y0 + length + 5), Vector2(7, 5), 6), "col": col.lightened(0.12)})


## Slanting shafts of light from gaps in the crown down to the ground, fading out.
func _shafts(layer: int, col: Color, spacing: float, top: float) -> void:
	for x: float in _xs(spacing, spacing * 0.5):
		var w := rng.randf_range(30, 70)
		var dx := rng.randf_range(90, 190)
		_add(layer, {"poly": PackedVector2Array([Vector2(x, top), Vector2(x + w, top), Vector2(x + w + dx + w, GROUND_Y), Vector2(x + dx, GROUND_Y)]),
			"cols": PackedColorArray([Color(col, 0.2), Color(col, 0.2), Color(col, 0.0), Color(col, 0.0)])})


## A soft band of mist between two heights, fading in toward the bottom.
func _mist(layer: int, y0: float, y1: float, col: Color, alpha: float) -> void:
	_add(layer, {"grad": Rect2(X0, y0, X1 - X0, y1 - y0), "top": Color(col, 0.0), "bottom": Color(col, alpha)})


## One colossal trunk of the world tree: bark with ridges and a lit flank, buttress roots, great limbs climbing into the
## crown, foliage where they meet it; from the Iron age the elven city is built into it.
func _world_trunk(x: float, w: float) -> void:
	var p := palette
	var leaf: Color = p.leaf
	var glow: Color = p.light
	var tc := _haze((p.near as Color).lightened(0.1), 0.3)
	_add(1, {"poly": PackedVector2Array([Vector2(x - w * 0.98, 748), Vector2(x - w * 0.62, 690), Vector2(x - w * 0.5, 560), Vector2(x - w * 0.47, 300), Vector2(x - w * 0.5, -300),
		Vector2(x + w * 0.5, -300), Vector2(x + w * 0.47, 300), Vector2(x + w * 0.5, 560), Vector2(x + w * 0.62, 690), Vector2(x + w * 0.98, 748)]), "col": tc})
	_add(1, {"poly": PackedVector2Array([Vector2(x - w * 0.5, 560), Vector2(x - w * 0.47, 300), Vector2(x - w * 0.5, -300), Vector2(x - w * 0.18, -300), Vector2(x - w * 0.16, 300), Vector2(x - w * 0.2, 640)]), "col": tc.lightened(0.09)})
	_add(1, {"poly": PackedVector2Array([Vector2(x + w * 0.32, 690), Vector2(x + w * 0.3, 300), Vector2(x + w * 0.34, -300), Vector2(x + w * 0.5, -300), Vector2(x + w * 0.47, 300), Vector2(x + w * 0.5, 560), Vector2(x + w * 0.62, 690)]), "col": tc.darkened(0.14)})
	for k in 18:
		var u := lerpf(-0.46, 0.46, k / 17.0)
		var line := PackedVector2Array()
		for j in 9:
			var y := 700.0 - j * 130.0
			line.append(Vector2(x + u * w + sin(k * 1.9 + j * 0.9) * 7.0, y))
		_add(1, {"polyline": line, "w": 2.0 + (k % 3), "col": Color(0, 0, 0, 0.16)})
	# Buttress roots spreading over the ground, mossy on top.
	for side in [-1.0, 1.0]:
		for k in 3:
			_limb(1, Vector2(x + side * w * 0.42, 610 - k * 12), Vector2(x + side * w * (0.72 + k * 0.2), 715), Vector2(x + side * w * (1.0 + k * 0.32), 750), 52 - k * 10, 8, tc.darkened(0.04 * k))
			_add(1, {"poly": _blob(Vector2(x + side * w * (0.72 + k * 0.22), 706), Vector2(30, 9), 8), "col": leaf.darkened(0.2)})
	# Great limbs climbing into the crown.
	for side in [-1.0, 1.0]:
		_limb(1, Vector2(x + side * w * 0.4, 340), Vector2(x + side * w * 1.1, 250), Vector2(x + side * w * 1.7, 50), 96, 20, tc.darkened(0.06))
		_limb(1, Vector2(x + side * w * 0.45, 520), Vector2(x + side * w * 1.25, 470), Vector2(x + side * w * 2.05, 290), 64, 12, tc.darkened(0.1))
	for k in 16:
		var side := -1.0 if k % 2 == 0 else 1.0
		_leaf_clump(1, Vector2(x + side * rng.randf_range(w * 0.3, w * 1.9), rng.randf_range(20, 300)), Vector2(rng.randf_range(60, 100), rng.randf_range(36, 56)), _haze(leaf, 0.25))
	if age <= 2:
		# A hollow at the foot with a fire in it.
		_add(1, {"poly": PackedVector2Array([Vector2(x - 34, 748), Vector2(x - 34, 690), Vector2(x, 660), Vector2(x + 34, 690), Vector2(x + 34, 748)]), "col": Color(0.06, 0.05, 0.04)})
		_glow(1, Vector2(x, 728), 44.0, Color(1.0, 0.7, 0.35))
	else:
		# The elven city: lit windows spiralling up the trunk, timber halls on the flanks with lanterns and stairs.
		for k in 10:
			var wx := x + lerpf(-0.36, 0.36, fposmod(k * 0.37, 1.0)) * w
			var wy := 650.0 - k * 46.0
			_add(1, {"poly": PackedVector2Array([Vector2(wx - 9, wy + 26), Vector2(wx - 9, wy + 8), Vector2(wx, wy - 4), Vector2(wx + 9, wy + 8), Vector2(wx + 9, wy + 26)]), "col": Color(glow.lerp(Color(1.0, 0.8, 0.45), 0.6), 0.85)})
			_glow(1, Vector2(wx, wy + 14), 24.0, glow.lerp(Color(1.0, 0.8, 0.45), 0.5))
		var wood := _haze(Color("7a5a3a"), 0.25)
		for k in 3:
			for side in [-1.0, 1.0]:
				var hx: float = x + side * w * 0.5
				var hy := 470.0 + k * 90.0 + (0.0 if side < 0.0 else 40.0)
				var span := 130.0 - k * 20.0
				var x0: float = hx if side > 0.0 else hx - span
				_rect(1, Rect2(x0, hy, span, 9), wood)
				_rect(1, Rect2(x0 + span * 0.15, hy - 44, span * 0.7, 44), wood.lightened(0.06))
				_add(1, {"poly": PackedVector2Array([Vector2(x0 + span * 0.08, hy - 44), Vector2(x0 + span * 0.5, hy - 78), Vector2(x0 + span * 0.92, hy - 44)]), "col": _haze(leaf, 0.15).darkened(0.1)})
				_rect(1, Rect2(x0 + span * 0.42, hy - 30, 14, 30), Color(glow.lerp(Color(1.0, 0.8, 0.4), 0.6), 0.75))
				_line(1, Vector2(x0 + (span if side < 0.0 else 0.0), hy + 9), Vector2(x0 + (span - 26.0 if side < 0.0 else 26.0), hy + 46), 4.0, wood.darkened(0.2))
				anims.append({"type": "lamp", "layer": 1, "pos": Vector2(x0 + (span - 8.0 if side < 0.0 else 8.0), hy + 20), "col": Color(1.0, 0.85, 0.5), "r": 38.0})
	if age == 6:
		# Runes glowing in the bark.
		for k in 5:
			var rx := x + rng.randf_range(-w * 0.35, w * 0.35)
			var ry := rng.randf_range(160, 620)
			anims.append({"type": "rune", "layer": 1, "pts": PackedVector2Array([Vector2(rx, ry), Vector2(rx + 10, ry - 22), Vector2(rx + 20, ry), Vector2(rx + 30, ry - 22)]), "col": glow})


func _forest() -> void:
	var p := palette
	var leaf: Color = p.leaf
	var glow: Color = p.light
	var bark: Color = p.near
	var trunks := [-620.0, 1215.0]
	_ridge(0, 600 if age != 6 else 640, 50, 280, _haze(p.far, 0.4), 4)
	if age == 2:
		# River glinting between the hills.
		_rect(0, Rect2(X0, 640, X1 - X0, 40), _haze(Color("6ab0d8"), 0.2))
		anims.append({"type": "shimmer", "layer": 0, "col": Color(1, 1, 1, 0.22)})
	# The far crown of the world tree, hazy, hanging over everything.
	var far_leaf := _haze(leaf, 0.5).darkened(0.05)
	_crown(0, 400.0, 60.0, far_leaf, 95.0, 1.3)
	# Distant canopy line and forest floor.
	var far_canopy := _haze(p.mid, 0.35)
	for x: float in _xs(60, 20):
		var r := rng.randf_range(34, 60)
		_add(1, {"poly": _blob(Vector2(x, 650 - r * 0.4), Vector2(r, r * 0.8), 10), "col": far_canopy.darkened(rng.randf() * 0.08)})
	_rect(1, Rect2(X0, 650, X1 - X0, 110), far_canopy.darkened(0.1))
	# The far forest rises in hazy tiers toward the crown: distant giants, then banks of foliage.
	for x: float in _xs(190, 70):
		var tw := rng.randf_range(10, 20)
		_add(0, {"poly": PackedVector2Array([Vector2(x - tw, 660), Vector2(x - tw * 0.6, 300), Vector2(x + tw * 0.6, 300), Vector2(x + tw, 660)]), "col": _haze(bark, 0.55)})
	for row in 3:
		var yb := 610.0 - row * 60.0
		for x: float in _xs(72, 30):
			var r := rng.randf_range(44, 84)
			_add(1, {"poly": _blob(Vector2(x, yb), Vector2(r, r * 0.55), 11), "col": _haze(p.mid, 0.5 + row * 0.06).darkened(rng.randf() * 0.1)})
	if age == 4 or age == 5:
		# White elven towers rising through the trees toward the crown.
		for x: float in _xs(900, 260):
			if absf(x - trunks[0]) < 420.0 or absf(x - trunks[1]) < 420.0:
				continue
			var h := rng.randf_range(300, 420)
			var tc := _haze(Color("e8e4dc"), 0.3 if age == 4 else 0.45)
			_rect(1, Rect2(x - 9, 650 - h, 18, h), tc)
			_add(1, {"poly": PackedVector2Array([Vector2(x - 16, 650 - h), Vector2(x, 650 - h - 70), Vector2(x + 16, 650 - h), Vector2(x, 650 - h + 10)]), "col": tc.lerp(leaf, 0.3)})
			_rect(1, Rect2(x - 14, 650 - h * 0.55, 28, 6), tc.darkened(0.1))
			if age == 5:
				_glow(1, Vector2(x, 650 - h - 20), 20.0, glow)
	if age == 6:
		for x: float in _xs(700, 200):
			var y := rng.randf_range(330, 520)
			_add(1, {"poly": PackedVector2Array([Vector2(x, y - 24), Vector2(x + 8, y), Vector2(x, y + 24), Vector2(x - 8, y)]), "col": Color(glow, 0.8)})
			_glow(1, Vector2(x, y), 34.0, glow)
	# The world tree itself: colossal trunks behind each base, their limbs lost in the crown.
	for tx: float in trunks:
		_world_trunk(tx, 430.0)
	_mist(1, 470, 700, _haze(p.sky[1], 0.2), 0.25)
	# Mid forest: trunks climbing into the crown, leafy clumps on their branches.
	_ridge(2, 736, 12, 200, p.mid.darkened(0.12), 2)
	for x: float in _xs(300 if age != 3 else 380, 100):
		var w := rng.randf_range(16, 28) * (1.7 if age == 3 else 1.0)
		var tc := _haze(bark, 0.25)
		if age == 2:
			tc = _haze(Color("e8e4d8"), 0.15)
		_add(2, {"poly": PackedVector2Array([Vector2(x - w * 0.9, 740), Vector2(x - w * 0.5, 700), Vector2(x - w * 0.45, -40), Vector2(x + w * 0.45, -40), Vector2(x + w * 0.5, 700), Vector2(x + w * 0.9, 740)]), "col": tc})
		_add(2, {"poly": PackedVector2Array([Vector2(x + w * 0.1, 720), Vector2(x + w * 0.1, -40), Vector2(x + w * 0.45, -40), Vector2(x + w * 0.5, 700), Vector2(x + w * 0.9, 740)]), "col": tc.darkened(0.12)})
		if age == 2:
			for k in 9:
				_line(2, Vector2(x - w * 0.4, 260 + k * 52 + rng.randf() * 20), Vector2(x + w * 0.1, 260 + k * 52 + rng.randf() * 20), 2, Color(0.2, 0.2, 0.2, 0.6))
		var lc := _haze(leaf, 0.2)
		for k in 3:
			var by := rng.randf_range(300, 620)
			var dir := -1.0 if rng.randf() < 0.5 else 1.0
			_limb(2, Vector2(x, by), Vector2(x + dir * 30, by - 24), Vector2(x + dir * 76, by - 34), w * 0.45, 4.0, tc.darkened(0.08))
			_leaf_clump(2, Vector2(x + dir * 80, by - 38), Vector2(rng.randf_range(44, 66), rng.randf_range(26, 38)), lc)
		if age == 6:
			for k in 3:
				_glow(2, Vector2(x + rng.randf_range(-60, 60), rng.randf_range(220, 420)), 18.0, glow)
	# Tree-halls on the giant trunks (Iron onward): platforms, rails and lanterns.
	if age >= 3:
		for x: float in _xs(760, 200):
			var y := rng.randf_range(430, 600)
			var wood := _haze(Color("7a5a3a"), 0.2)
			_rect(2, Rect2(x - 60, y, 120, 8), wood)
			_line(2, Vector2(x - 60, y + 8), Vector2(x - 30, y + 40), 3, wood.darkened(0.2))
			_line(2, Vector2(x + 60, y + 8), Vector2(x + 30, y + 40), 3, wood.darkened(0.2))
			_rect(2, Rect2(x - 40, y - 34, 80, 34), wood.lightened(0.05))
			_add(2, {"poly": PackedVector2Array([Vector2(x - 50, y - 34), Vector2(x, y - 64), Vector2(x + 50, y - 34)]), "col": _haze(leaf, 0.15).darkened(0.1)})
			_rect(2, Rect2(x - 8, y - 24, 16, 24), Color(glow.lerp(Color(1.0, 0.8, 0.4), 0.6), 0.7))
			anims.append({"type": "lamp", "layer": 2, "pos": Vector2(x + 44, y + 16), "col": Color(1.0, 0.85, 0.5), "r": 40.0})
			# A rope walkway with hanging lanterns running off to the next trunk.
			var bridge := PackedVector2Array()
			for k in 9:
				var u := k / 8.0
				bridge.append(Vector2(x + 60 + u * 190.0, y + 4 + sin(u * PI) * 16.0))
			_add(2, {"polyline": bridge, "w": 3.0, "col": wood.darkened(0.15)})
			anims.append({"type": "lamp", "layer": 2, "pos": Vector2(x + 155, y + 24), "col": Color(1.0, 0.85, 0.5), "r": 30.0})
	if age == 5:
		for x: float in _xs(500, 160):
			anims.append({"type": "drift_smoke", "layer": 2, "pos": Vector2(x, 700), "col": Color(0.85, 0.95, 1.0, 0.25)})
	_mist(2, 560, 750, _haze(p.sky[1], 0.15), 0.3)
	# Near: shafts of light, mossy trunks framing the lane, then the near crown with hanging vines.
	_shafts(3, glow.lerp(Color.WHITE, 0.3), 620.0, 190.0)
	for x: float in _xs(560, 180):
		var w := rng.randf_range(30, 46)
		var nc := bark.darkened(0.15)
		_add(3, {"poly": PackedVector2Array([Vector2(x - w * 1.3, 754), Vector2(x - w * 0.55, 720), Vector2(x - w * 0.5, -60), Vector2(x + w * 0.5, -60), Vector2(x + w * 0.6, 720), Vector2(x + w * 1.4, 754)]), "col": nc})
		_line(3, Vector2(x - w * 0.2, 700), Vector2(x - w * 0.25, 60), 2, nc.darkened(0.2))
		_line(3, Vector2(x + w * 0.2, 700), Vector2(x + w * 0.16, 80), 3, nc.darkened(0.25))
		_add(3, {"poly": _blob(Vector2(x - w * 0.3, 690), Vector2(w * 0.35, 14), 8), "col": leaf.darkened(0.2)})
		for k in 2:
			_leaf_clump(3, Vector2(x + rng.randf_range(-70, 70), rng.randf_range(300, 560)), Vector2(rng.randf_range(56, 86), rng.randf_range(26, 40)), leaf.darkened(0.32))
	if age == 2:
		for x: float in _xs(900, 200):
			for k in 3:
				var sx := x + k * 36
				var sh := rng.randf_range(40, 60)
				_add(3, {"poly": PackedVector2Array([Vector2(sx - 9, 752), Vector2(sx - 7, 752 - sh), Vector2(sx + 2, 752 - sh - 6), Vector2(sx + 9, 752 - sh + 4), Vector2(sx + 9, 752)]), "col": Color("8a8a80")})
	for x: float in _xs(160, 60):
		_fern(3, x, 752, rng.randf_range(0.7, 1.1), leaf.darkened(0.15))
	var near_leaf := leaf.darkened(0.34)
	var ph := _crown(3, 140.0, 50.0, near_leaf, 100.0, 1.35)
	_vines(3, 140.0, 50.0, ph, near_leaf.lightened(0.06), 80.0)
	if age == 2:
		# Blossom in the crown.
		for x: float in _xs(70, 40):
			_circle(3, Vector2(x, rng.randf_range(20, 170)), rng.randf_range(2.0, 4.0), Color("f7d6e4"))
	if age >= 3:
		# Lanterns and glowing fruit hanging in the crown.
		for x: float in _xs(430, 160):
			var y := _crown_edge(x, 140.0, 50.0, ph) + rng.randf_range(20, 90)
			_line(3, Vector2(x, y - 40), Vector2(x, y), 1.5, near_leaf.lightened(0.1))
			_circle(3, Vector2(x, y + 5), 6.0, Color(glow.lerp(Color(1.0, 0.85, 0.5), 0.6), 0.95))
			anims.append({"type": "lamp", "layer": 3, "pos": Vector2(x, y + 5), "col": Color(1.0, 0.85, 0.5) if age != 6 else glow, "r": 34.0})


func _fern(layer: int, x: float, y: float, s: float, col: Color) -> void:
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.45
		var tip := Vector2(x, y) + Vector2(cos(a), sin(a)) * 30 * s
		_add(layer, {"poly": PackedVector2Array([Vector2(x - 2, y), tip, Vector2(x + 2, y)]), "col": col.darkened(0.05 * k)})


# ---------------------------------------------------------------------------
# Dwarves: mountains and mines through the ages

## A massif: a jagged flank up to a summit, split by a ridge into a lit and a shadowed face, snow above a ragged line
## (`snow_frac` of the height, 0 = bare). Returns the summit.
func _massif(layer: int, x: float, base_y: float, w: float, h: float, col: Color, snow: Color, snow_frac: float) -> Vector2:
	var s := Vector2(x + rng.randf_range(-w * 0.08, w * 0.08), base_y - h)
	var fl := Vector2(x - w, base_y)
	var fr := Vector2(x + w, base_y)
	var left := PackedVector2Array([fl])
	for i in range(1, 6):
		var t := i / 6.0
		var q := fl.lerp(s, t)
		q += Vector2(rng.randf_range(-w * 0.05, w * 0.05) - (w * 0.1 * t if i % 2 == 0 else 0.0), -(rng.randf_range(0.0, h * 0.06) if i % 2 == 1 else 0.0))
		left.append(q)
	left.append(s)
	var right := PackedVector2Array()
	for i in range(5, 0, -1):
		var t := i / 6.0
		var q := fr.lerp(s, t)
		q += Vector2(rng.randf_range(-w * 0.05, w * 0.05) + (w * 0.09 * t if i % 2 == 0 else 0.0), -(rng.randf_range(0.0, h * 0.06) if i % 2 == 1 else 0.0))
		right.append(q)
	right.append(fr)
	var rx := x + w * rng.randf_range(-0.05, 0.25)
	var ridge := PackedVector2Array([s])
	for i in range(1, 5):
		ridge.append(s.lerp(Vector2(rx, base_y), i / 5.0) + Vector2(rng.randf_range(-w * 0.06, w * 0.06), 0.0))
	ridge.append(Vector2(rx, base_y))
	var lit := PackedVector2Array(left)
	for i in range(1, ridge.size()):
		lit.append(ridge[i])
	var shade := PackedVector2Array([s])
	shade.append_array(right)
	for i in range(ridge.size() - 1, 0, -1):
		shade.append(ridge[i])
	_add(layer, {"poly": lit, "col": col.lightened(0.07)})
	_add(layer, {"poly": shade, "col": col.darkened(0.16)})
	# Strata: a few ragged bands across the flanks.
	var sil := left.duplicate()
	sil.append_array(right)
	for k in 4:
		var y := base_y - h * (0.18 + k * 0.17)
		var line := PackedVector2Array()
		for j in 8:
			line.append(Vector2(x - w * 0.8 + j * w * 0.23, y + rng.randf_range(-7, 7)))
		for piece in Geometry2D.intersect_polyline_with_polygon(line, sil):
			_add(layer, {"polyline": piece, "w": 1.4, "col": Color(0, 0, 0, 0.1)})
	if snow.a > 0.0 and snow_frac > 0.0:
		var line_y := base_y - h * (1.0 - snow_frac)
		var region := PackedVector2Array([Vector2(x - w * 1.4, base_y - h * 1.6), Vector2(x + w * 1.4, base_y - h * 1.6)])
		for k in 13:
			region.append(Vector2(x + w * 1.4 - k * (w * 2.8 / 12.0), line_y + rng.randf_range(-16, 26)))
		for poly in Geometry2D.intersect_polygons(lit, region):
			_add(layer, {"poly": poly, "col": snow})
		for poly in Geometry2D.intersect_polygons(shade, region):
			_add(layer, {"poly": poly, "col": snow.darkened(0.12).lerp(Color("9fb0cc"), 0.3)})
	return s


## A mine mouth in a hillside: a dark adit framed by timber posts and a lintel with a lantern, a spoil heap, and a track
## running off down the slope with an ore cart on it.
func _mine(layer: int, x: float, y: float, s: float, timber: Color, lamp: Color, cart_speed := 26.0) -> void:
	_tri(layer, Vector2(x + 16 * s, y), Vector2(x + 76 * s, y), Vector2(x + 46 * s, y - 24 * s), Color("5a5650"))
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 20 * s, y), Vector2(x - 17 * s, y - 40 * s), Vector2(x + 17 * s, y - 40 * s), Vector2(x + 20 * s, y)]), "col": Color(0.05, 0.04, 0.04)})
	_rect(layer, Rect2(x - 26 * s, y - 46 * s, 8 * s, 46 * s), timber)
	_rect(layer, Rect2(x + 18 * s, y - 46 * s, 8 * s, 46 * s), timber)
	_rect(layer, Rect2(x - 30 * s, y - 53 * s, 60 * s, 8 * s), timber.lightened(0.06))
	_glow(layer, Vector2(x, y - 30 * s), 30.0 * s, lamp)
	anims.append({"type": "lamp", "layer": layer, "pos": Vector2(x, y - 30 * s), "col": lamp, "r": 34.0 * s})
	# The track: two rails and sleepers, down to the right.
	var a := Vector2(x + 6 * s, y - 2.0)
	var b := Vector2(x + 260 * s, y + 20.0 * s)
	_add(layer, {"polyline": PackedVector2Array([a, b]), "w": 2.5, "col": Color("3a3632")})
	for k in 18:
		var u := (k + 0.5) / 18.0
		var c := a.lerp(b, u)
		_line(layer, c + Vector2(0, -3), c + Vector2(0, 3), 2.0, timber.darkened(0.3))
	anims.append({"type": "cart", "layer": layer, "pts": PackedVector2Array([a + Vector2(0, -7), b + Vector2(0, -7)]), "speed": cart_speed, "phase": rng.randf(), "col": timber.darkened(0.15)})


## A headframe over a shaft: an A-frame of timbers carrying a winding wheel, and a shed at its foot.
func _headframe(layer: int, x: float, y: float, s: float, col: Color) -> void:
	_add(layer, {"polyline": PackedVector2Array([Vector2(x - 26 * s, y), Vector2(x, y - 96 * s), Vector2(x + 26 * s, y)]), "w": 5.0 * s, "col": col})
	_line(layer, Vector2(x - 15 * s, y - 40 * s), Vector2(x + 15 * s, y - 40 * s), 3.0 * s, col)
	_line(layer, Vector2(x - 8 * s, y - 68 * s), Vector2(x + 8 * s, y - 68 * s), 3.0 * s, col)
	_rect(layer, Rect2(x + 26 * s, y - 24 * s, 34 * s, 24 * s), col.lightened(0.05))
	_tri(layer, Vector2(x + 22 * s, y - 24 * s), Vector2(x + 64 * s, y - 24 * s), Vector2(x + 43 * s, y - 38 * s), col.darkened(0.1))
	anims.append({"type": "wheel", "layer": layer, "pos": Vector2(x, y - 98 * s), "r": 14.0 * s, "col": col.lightened(0.1)})


## A cableway between two pylons with a bucket riding it.
func _cableway(layer: int, a: Vector2, b: Vector2, col: Color) -> void:
	for pt: Vector2 in [a, b]:
		_add(layer, {"polyline": PackedVector2Array([Vector2(pt.x - 10, pt.y + 60), Vector2(pt.x, pt.y), Vector2(pt.x + 10, pt.y + 60)]), "w": 4.0, "col": col})
	var mid := a.lerp(b, 0.5) + Vector2(0, 26)
	_add(layer, {"polyline": PackedVector2Array([a, mid, b]), "w": 1.6, "col": col.darkened(0.2)})
	anims.append({"type": "bucket", "layer": layer, "a": a, "b": b, "sag": 26.0, "speed": 0.05, "phase": rng.randf(), "col": col})


## A waterfall spilling from a ledge, in pale streaks that run down.
func _waterfall(layer: int, x: float, top: float, length: float) -> void:
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 7, top), Vector2(x + 7, top), Vector2(x + 12, top + length), Vector2(x - 12, top + length)]), "cols": PackedColorArray([Color(0.85, 0.93, 1.0, 0.55), Color(0.85, 0.93, 1.0, 0.55), Color(0.85, 0.93, 1.0, 0.1), Color(0.85, 0.93, 1.0, 0.1)])})
	anims.append({"type": "fall", "layer": layer, "top": Vector2(x, top), "length": length})


## A great gate carved into a mountain foot: a heavy stone frame with a dark hall behind, steps, braziers, two guardian
## statues.
func _carved_gate(layer: int, x: float, y: float, s: float, col: Color) -> void:
	var c := col.lightened(0.08)
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 120 * s, y), Vector2(x - 104 * s, y - 190 * s), Vector2(x + 104 * s, y - 190 * s), Vector2(x + 120 * s, y)]), "col": c})
	_add(layer, {"poly": PackedVector2Array([Vector2(x - 54 * s, y), Vector2(x - 46 * s, y - 132 * s), Vector2(x + 46 * s, y - 132 * s), Vector2(x + 54 * s, y)]), "col": Color(0.04, 0.035, 0.035)})
	_rect(layer, Rect2(x - 64 * s, y - 146 * s, 128 * s, 16 * s), c.darkened(0.12))
	for k in 5:
		_rect(layer, Rect2(x - 80 * s + k * 40 * s, y - 182 * s, 14 * s, 12 * s), c.darkened(0.06))
	for side in [-1.0, 1.0]:
		# A guardian either side, a brazier at its foot.
		var gx: float = x + side * 84.0 * s
		_add(layer, {"poly": PackedVector2Array([Vector2(gx - 14 * s, y), Vector2(gx - 12 * s, y - 100 * s), Vector2(gx + 12 * s, y - 100 * s), Vector2(gx + 14 * s, y)]), "col": c.darkened(0.1)})
		_add(layer, {"poly": _blob(Vector2(gx, y - 116 * s), Vector2(12 * s, 13 * s), 9), "col": c.lightened(0.05)})
		_add(layer, {"poly": PackedVector2Array([Vector2(gx - 12 * s, y - 118 * s), Vector2(gx, y - 132 * s), Vector2(gx + 12 * s, y - 118 * s)]), "col": c.darkened(0.2)})
		_line(layer, Vector2(gx + side * 16 * s, y - 40 * s), Vector2(gx + side * 16 * s, y - 130 * s), 3.0 * s, c.darkened(0.3))
		_rect(layer, Rect2(gx - side * 34 * s - 6 * s, y - 36 * s, 12 * s, 36 * s), c.darkened(0.3))
		_circle(layer, Vector2(gx - side * 34 * s, y - 40 * s), 7 * s, Color("ffb050"))
		anims.append({"type": "lamp", "layer": layer, "pos": Vector2(gx - side * 34 * s, y - 44 * s), "col": Color("ffb050"), "r": 60.0 * s})
	for k in 3:
		_rect(layer, Rect2(x - (66 + k * 8) * s, y - (6 - k * 2) * s - 2, (132 + k * 16) * s, 6 * s), c.darkened(0.05 * k))


func _mountains() -> void:
	var p := palette
	var glow: Color = p.light
	var snow := Color("eef2f6") if age in [1, 3] else (Color("6a6a9a") if age == 6 else Color(0, 0, 0, 0))
	var timber := Color("6b4a2b") if age <= 3 else Color("4a3a30")
	var lamp := Color("ffb050") if age != 6 else glow
	# Far ranges: colossal massifs under bands of cloud.
	for x: float in _xs(520, 170):
		_massif(0, x, 720, rng.randf_range(260, 380), rng.randf_range(470, 640), _haze(p.far, 0.4), snow, 0.4)
	_mist(0, 300, 520, _haze(p.sky[1], 0.1), 0.3)
	for x: float in _xs(400, 130):
		_massif(0, x, 720, rng.randf_range(190, 290), rng.randf_range(300, 440), _haze(p.far, 0.24), snow, 0.32)
	# Mid range: the mountains the mines are cut into.
	var mids: Array = []
	for x: float in _xs(620, 200):
		var w := rng.randf_range(250, 360)
		var h := rng.randf_range(250, 360)
		_massif(1, x, 700, w, h, _haze(p.mid, 0.15), snow, 0.22)
		mids.append([x, w, h])
	if age == 2:
		# The canyon: guardians carved into its walls, helmed, bearded, leaning on great axes.
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
	# Mines: an adit with a track and cart at the foot of most massifs, headframes and cableways between them.
	for i in mids.size():
		var m: Array = mids[i]
		var mx: float = m[0] + (m[1] * 0.28 if i % 2 == 0 else -m[1] * 0.42)
		var low_y := 700.0 - rng.randf_range(0.0, 24.0)
		_mine(1, mx, low_y, rng.randf_range(1.35, 1.75), timber, lamp, rng.randf_range(20.0, 36.0))
		# A second adit higher up the mountain, joined to the first by a zigzag mule path with lanterns.
		var high := Vector2(m[0] + (-m[1] * 0.12 if i % 2 == 0 else m[1] * 0.2), 700.0 - m[2] * 0.36)
		var path := PackedVector2Array([high + Vector2(30, 0)])
		for k in 5:
			path.append(Vector2(high.x + 30.0 + (110.0 if k % 2 == 0 else -20.0), high.y + (low_y - high.y) * (k + 1) / 5.0))
		_add(1, {"polyline": path, "w": 3.5, "col": Color("8a7a60", 0.75)})
		for k in 3:
			var lp: Vector2 = path[1 + k * 2 if 1 + k * 2 < path.size() else path.size() - 1]
			_circle(1, lp + Vector2(0, -8), 3.0, lamp)
			anims.append({"type": "lamp", "layer": 1, "pos": lp + Vector2(0, -8), "col": lamp, "r": 24.0})
		_mine(1, high.x, high.y, rng.randf_range(1.0, 1.3), timber, lamp, rng.randf_range(14.0, 24.0))
		if i % 3 == 1:
			_headframe(1, m[0] + m[1] * 0.55, 700.0, rng.randf_range(1.3, 1.7), timber.lightened(0.05))
		if i % 2 == 0 and i + 1 < mids.size():
			var n: Array = mids[i + 1]
			_cableway(1, Vector2(m[0] + m[1] * 0.2, 700.0 - m[2] * 0.55), Vector2(n[0] - n[1] * 0.2, 700.0 - n[2] * 0.42), timber.lightened(0.1))
		if age <= 4 and i % 2 == 1:
			_waterfall(1, m[0] - m[1] * 0.15, 700.0 - m[2] * 0.5, m[2] * 0.5)
	match age:
		3:
			# Great gates carved into the mountain feet, braziers and guardians either side.
			for x: float in _xs(1500, 300):
				_carved_gate(1, x, 700.0, 1.0, _haze(p.mid, 0.1))
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
			# Rune lines glowing along the cliff faces; floating runestones; veins of light in the rock.
			for x: float in _xs(420, 140):
				var y := rng.randf_range(520, 640)
				var pts := PackedVector2Array([Vector2(x, y), Vector2(x + 12, y - 18), Vector2(x + 24, y), Vector2(x + 36, y - 18)])
				anims.append({"type": "rune", "layer": 1, "pts": pts, "col": glow})
			for x: float in _xs(800, 240):
				var y := rng.randf_range(380, 500)
				_add(1, {"poly": PackedVector2Array([Vector2(x - 12, y + 20), Vector2(x - 14, y - 16), Vector2(x, y - 26), Vector2(x + 14, y - 14), Vector2(x + 12, y + 22)]), "col": _haze(p.mid.lightened(0.1), 0.1)})
				anims.append({"type": "rune", "layer": 1, "pts": PackedVector2Array([Vector2(x - 5, y - 8), Vector2(x, y + 4), Vector2(x + 5, y - 8)]), "col": glow})
				_glow(1, Vector2(x, y), 30.0, glow)
	# Foothills with a long mine railway along them, ore carts running, spoil heaps and timber scaffolds.
	_ridge(2, 722, 22, 180, p.near.lightened(0.08), 8, 26)
	_add(2, {"polyline": PackedVector2Array([Vector2(X0, 734), Vector2(X1, 734)]), "w": 3.0, "col": Color("2e2a28")})
	var sx := X0
	while sx < X1:
		_line(2, Vector2(sx, 731), Vector2(sx, 738), 2.0, timber.darkened(0.25))
		sx += 22.0
	for x: float in _xs(820, 260):
		anims.append({"type": "cart", "layer": 2, "pts": PackedVector2Array([Vector2(x, 728), Vector2(x + 600, 728)]), "speed": rng.randf_range(32.0, 52.0), "phase": rng.randf(), "col": timber.darkened(0.1)})
	for x: float in _xs(700, 220):
		var sh := rng.randf_range(30, 60)
		_tri(2, Vector2(x - sh * 1.6, 736), Vector2(x + sh * 1.6, 736), Vector2(x + rng.randf_range(-10, 10), 736 - sh), Color("4a4640"))
	for x: float in _xs(1100, 300):
		# A timber scaffold with a hoist.
		for k in 3:
			_line(2, Vector2(x + k * 22, 736), Vector2(x + k * 22, 690), 3.0, timber)
		_line(2, Vector2(x, 690), Vector2(x + 44, 690), 3.0, timber)
		_line(2, Vector2(x, 736), Vector2(x + 44, 690), 2.0, timber.darkened(0.1))
		_line(2, Vector2(x + 44, 690), Vector2(x + 44, 716), 1.5, Color("b0a890"))
	# Near: pines (highlands and snow), boulders, cairns, and the tools of the trade.
	if age in [1, 3]:
		for x: float in _xs(240, 90):
			_pine(3, x, 752, rng.randf_range(0.9, 1.4), Color("2e4a38") if age == 1 else Color("30443c"), age == 3)
	for x: float in _xs(420, 140):
		var s2 := rng.randf_range(16, 30)
		_add(3, {"poly": _blob(Vector2(x, 752 - s2 * 0.5), Vector2(s2 * 1.4, s2), 9), "col": p.near.lightened(0.05)})
	for x: float in _xs(900, 260):
		# A pile of ore and a barrow.
		for k in 5:
			_add(3, {"poly": _blob(Vector2(x + k * 9 - 18, 748 - (k % 2) * 6), Vector2(9, 7), 8), "col": Color("3e3a3a").lightened(0.04 * k)})
		_rect(3, Rect2(x + 30, 736, 20, 10), timber)
		_circle(3, Vector2(x + 36, 750), 5, Color("2a2826"))
		_line(3, Vector2(x + 50, 738), Vector2(x + 68, 730), 3.0, timber.darkened(0.2))
	if age <= 2:
		for x: float in _xs(900, 200):
			for k in 4:
				_add(3, {"poly": _blob(Vector2(x + 300, 746 - k * 12), Vector2(12 - k * 2, 6), 8), "col": Color("8a8478").darkened(0.05 * k)})
	if age == 4 or age == 6:
		for x: float in _xs(700, 200):
			_rect(3, Rect2(x - 5, 712, 10, 40), Color("3a3230"))
			_circle(3, Vector2(x, 708), 7, lamp)
			anims.append({"type": "lamp", "layer": 3, "pos": Vector2(x, 704), "col": lamp, "r": 50.0})


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
