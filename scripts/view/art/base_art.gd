class_name BaseArt
extends RefCounted
## Bases, towers and turrets per race and age: human forts (hide camp → temple → Roman castrum →
## castle → star fort → wizard citadel), elven tree-halls and dwarven mountain holds that grow with
## each age. Turrets stand on their own towers on the ground in front of the base, one per slot, so
## base art never has to leave room for mounts. Local space: the gate is at x = 0 on the ground
## (y = 0), the base extends toward −x, and the enemy is toward +x (the right base is drawn mirrored).

## Tower foot per turret slot, in front of the gate; odd slots stand a step further back in depth.
const PADS := [Vector2(44, -4), Vector2(104, -16), Vector2(164, -4), Vector2(224, -16), Vector2(284, -4)]
const SCALE := 1.35
const TOWER_SCALE := 1.2
## Tower height (before TOWER_SCALE) per race and age.
const TOWER_H := {
	&"human": [46.0, 50.0, 62.0, 70.0, 50.0, 78.0],
	&"elf": [50.0, 56.0, 66.0, 74.0, 82.0, 86.0],
	&"dwarf": [36.0, 40.0, 46.0, 48.0, 50.0, 52.0],
}


## Foot of a slot's tower, relative to the gate on the ground.
static func slot_pos(i: int) -> Vector2:
	return PADS[i]


## Where a slot's turret sits: the top of its tower.
static func mount_pos(i: int, race: StringName, age: int) -> Vector2:
	return PADS[i] + Vector2(0, -tower_height(race, age) * TOWER_SCALE)


static func tower_height(race: StringName, age: int) -> float:
	return TOWER_H.get(race, TOWER_H[&"human"])[clampi(age - 1, 0, 5)]


static func _poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)


static func draw_base(ci: CanvasItem, age: int, team: Color, hp_frac: float, t: float, build: float, host: Node = null, race: StringName = &"human") -> void:
	# `build` 0→1 plays the rebuild after evolving: the new structure rises out of the ground.
	var rise := (1.0 - ease(build, 0.4)) * 240.0
	if host != null:
		UnitArt._push(ci, Transform2D(0.0, Vector2(0, rise)))
		ci.draw_texture(static_texture(age, team, host, race), -TEX_ORIGIN)
		UnitArt._pop(ci)
	UnitArt._push(ci, Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2(0, rise)))
	if host == null:
		dynamic_pass = false
		_art(ci, race, age, team, t)
	dynamic_pass = true
	_art(ci, race, age, team, t)
	dynamic_pass = false
	# Damage: cracks, smoke and fire as HP falls.
	if hp_frac < 0.66:
		for i in 3:
			var c := Vector2(-40 - i * 50, -60 - (i % 2) * 50)
			ci.draw_polyline(PackedVector2Array([c, c + Vector2(8, 12), c + Vector2(2, 24), c + Vector2(10, 34)]), Color(0, 0, 0, 0.55), 2.0)
	if hp_frac < 0.4:
		for i in 3:
			var c := Vector2(-50 - i * 45, -150 + (i % 2) * 40)
			var fl := 0.6 + 0.4 * sin(t * 13.0 + i * 2.0)
			ci.draw_circle(c, 9.0 * fl, Color(1.0, 0.55, 0.15, 0.85))
			ci.draw_circle(c + Vector2(0, -6), 5.0 * fl, Color(1.0, 0.9, 0.4, 0.9))
	UnitArt._pop(ci)


static func _banner(ci: CanvasItem, top: Vector2, team: Color, t: float, h := 26.0) -> void:
	ci.draw_line(top, top + Vector2(0, 46), Color("3b2c20"), 3.0)
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(top + Vector2(i * 6.0, sin(t * 3.5 - i * 0.8) * 2.0 * i / 5.0))
	for i in range(5, -1, -1):
		pts.append(top + Vector2(i * 6.0 - 2.0, h + sin(t * 3.5 - i * 0.8) * 2.0 * i / 5.0))
	ci.draw_colored_polygon(pts, team)


## 0 by day … 1 at night; set by the view so windows and fires glow after dark.
static var night := 0.0
## Bases draw in two passes: the static art is rendered once per age/team into a cached texture,
## the animated bits (banners, fire, smoke, lit windows) are drawn live every frame.
static var dynamic_pass := false
static var _cache := {}
const TEX_ORIGIN := Vector2(312, 490)
const TEX_SIZE := Vector2i(350, 500)


## Cached texture of an age's static base art (drawn at SCALE), rendered by a one-shot SubViewport.


static func static_texture(age: int, team: Color, host: Node, race: StringName = &"human") -> Texture2D:
	var key := "%s_%d_%s" % [race, age, team.to_html()]
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return _cache[key].get_texture()
	var vp := SubViewport.new()
	vp.size = TEX_SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var n := Node2D.new()
	n.draw.connect(func():
		UnitArt.begin(n, Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, TEX_ORIGIN))
		dynamic_pass = false
		_art(n, race, age, team, 0.0)
		n.draw_set_transform(Vector2.ZERO))
	vp.add_child(n)
	host.add_child(vp)
	_cache[key] = vp
	return vp.get_texture()


static func _art(ci: CanvasItem, race: StringName, age: int, team: Color, t: float) -> void:
	match race:
		&"elf":
			_elf(ci, age, team, t)
		&"dwarf":
			_dwarf(ci, age, team, t)
		_:
			match age:
				1: _stone(ci, team, t)
				2: _bronze(ci, team, t)
				3: _castrum(ci, team, t)
				4: _medieval(ci, team, t)
				5: _gunpowder(ci, team, t)
				_: _citadel(ci, team, t)


static func _sp(ci: CanvasItem, pts: Array, col: Color) -> void:
	UnitArt._shade_poly(ci, pts, col, Vector2(0.5, -0.8))


static func _rect_pts(r: Rect2) -> Array:
	return [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]


static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


## Stone courses: shaded wall with per-block tone variation, mortar lines and staggered joints.


static func _masonry(ci: CanvasItem, r: Rect2, col: Color, course := 11.0, block := 22.0) -> void:
	_sp(ci, _rect_pts(r), col)
	var rows := int(r.size.y / course)
	for row in rows:
		var y := r.position.y + row * course
		var off := (block * 0.5) if row % 2 == 1 else 0.0
		var x := r.position.x - off
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + block, r.end.x)
			var k := _hash(x, y) - 0.5
			ci.draw_rect(Rect2(x0 + 1, y + 1, x1 - x0 - 2, course - 2), Color(col.lightened(0.1) if k > 0 else col.darkened(0.12), absf(k) * 0.9))
			ci.draw_line(Vector2(x1, y), Vector2(x1, y + course), Color(0, 0, 0, 0.25), 1.0)
			x += block
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.3), 1.2)
		ci.draw_line(Vector2(r.position.x, y + 1.5), Vector2(r.end.x, y + 1.5), Color(1, 1, 1, 0.06), 1.0)


static func _planks(ci: CanvasItem, r: Rect2, col: Color, w := 7.0) -> void:
	_sp(ci, _rect_pts(r), col)
	var x := r.position.x
	var i := 0
	while x < r.end.x:
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.35), 1.0)
		ci.draw_line(Vector2(x + w * 0.5, r.position.y + 3 + (i % 3) * 6), Vector2(x + w * 0.5, r.position.y + 6 + (i % 3) * 6), Color(0, 0, 0, 0.2), 1.0)
		x += w
		i += 1


## A window/slit: dark recess by day, warm light at night.


static func _window(ci: CanvasItem, r: Rect2, warm := Color(1.0, 0.72, 0.35)) -> void:
	if not dynamic_pass:
		ci.draw_rect(r, Color(0.06, 0.05, 0.05))
		ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 1, 1, 0.12), 1.0)
	elif night > 0.05:
		ci.draw_rect(r.grow(-1), Color(warm, 0.9 * night))
		ci.draw_rect(r.grow(5), Color(warm, 0.12 * night))


static func _stone(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		if night > 0.05:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-110, -100), Vector2(-90, -100), Vector2(-100, -124)]), Color(1.0, 0.6, 0.25, 0.6 * night))
		# Fire pit.
		var fl := 0.7 + 0.3 * sin(t * 11.0)
		ci.draw_circle(Vector2(-150, -6), 14, Color(1.0, 0.55, 0.2, 0.18 + 0.2 * night))
		for k in 3:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-158 + k * 6, -2), Vector2(-152 + k * 6, -2), Vector2(-155 + k * 6, -14 * fl - k * 2)]), Color(1.0, 0.6 + k * 0.1, 0.2))
		_banner(ci, Vector2(-100, -222), team, t)
		return
	# Rock outcrop, hide tent with stitched seams, stake palisade bound with rope, fire pit.
	var rock := Color("7d6a58")
	_sp(ci, [Vector2(-205, 0), Vector2(-196, -72), Vector2(-160, -118), Vector2(-104, -142), Vector2(-52, -124), Vector2(-20, -84), Vector2(-4, -30), Vector2(10, 0)], rock)
	_sp(ci, [Vector2(-160, -118), Vector2(-104, -142), Vector2(-80, -132), Vector2(-128, -104)], rock.lightened(0.12))
	for k in 6:
		var a := Vector2(-190 + k * 28, -50 - (k % 3) * 22)
		ci.draw_polyline(PackedVector2Array([a, a + Vector2(9, 8), a + Vector2(4, 18)]), Color(0, 0, 0, 0.3), 1.5)
	var hide := Color("8a6440")
	_sp(ci, [Vector2(-148, -100), Vector2(-56, -100), Vector2(-100, -176)], hide)
	for k in 4:
		ci.draw_line(Vector2(-100, -176), Vector2(-138 + k * 26, -100), Color(0.25, 0.16, 0.1, 0.6), 1.2)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-114, -100), Vector2(-86, -100), Vector2(-100, -134)]), Color(0.12, 0.08, 0.05))
	for k in 10:
		var x := -4.0 - k * 13.0
		var h := 40.0 + (k % 3) * 5.0
		_sp(ci, [Vector2(x - 4.5, 0), Vector2(x - 4.5, -h), Vector2(x, -h - 9), Vector2(x + 4.5, -h), Vector2(x + 4.5, 0)], Color("6b4a2b").lightened(0.04 * (k % 2)))
	for y in [-20.0, -32.0]:
		ci.draw_line(Vector2(-134, y), Vector2(0, y + 2), Color("b09060"), 2.0)


static func _bronze(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		_banner(ci, Vector2(-98, -248), team, t)
		return
	# Temple-fort: stepped masonry podium, fluted columns, pediment with a team frieze, bronze shields.
	var stone := Color("e1d3b3")
	_masonry(ci, Rect2(-200, -34, 206, 34), stone.darkened(0.08), 11, 26)
	_masonry(ci, Rect2(-190, -132, 186, 98), stone, 12, 30)
	for k in 6:
		var x := -182.0 + k * 30.0
		_sp(ci, _rect_pts(Rect2(x, -126, 14, 92)), Color("f0e8d4"))
		for f in 3:
			ci.draw_line(Vector2(x + 3 + f * 4, -122), Vector2(x + 3 + f * 4, -38), Color(0, 0, 0, 0.12), 1.0)
		_sp(ci, _rect_pts(Rect2(x - 3, -132, 20, 6)), Color("d8c8a4"))
	_sp(ci, _rect_pts(Rect2(-198, -142, 202, 12)), Color("cdb88c"))
	_sp(ci, [Vector2(-204, -142), Vector2(8, -142), Vector2(-98, -196)], Color("c9a060"))
	_sp(ci, [Vector2(-172, -148), Vector2(-24, -148), Vector2(-98, -186)], team.darkened(0.1))
	for k in 5:
		ci.draw_circle(Vector2(-140 + k * 21, -158), 4, Color("d9b25e"))
	for k in 3:
		var c := Vector2(-160 + k * 50, -80)
		ci.draw_circle(c, 9, Color("8a5a24"))
		ci.draw_circle(c, 7, Color("c28c3e"))
		ci.draw_circle(c, 2, Color("f0d090"))
	_planks(ci, Rect2(-42, -76, 38, 76), Color("5b3f24"), 6)
	for k in 4:
		ci.draw_circle(Vector2(-35 + (k % 2) * 22, -60 + (k / 2) * 30), 1.8, Color("d9b25e"))


static func _medieval(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		for p in [Vector2(-180, -96), Vector2(-160, -96), Vector2(-104, -200), Vector2(-86, -200), Vector2(-104, -160), Vector2(-86, -160)]:
			_window(ci, Rect2(p, Vector2(5, 16)))
		_banner(ci, Vector2(-98, -344), team, t, 32)
		return
	# Curtain wall and keep in masonry, crenellations, arrow slits, slate cone roof, portcullis.
	var stone := Color("8d8e8a")
	_masonry(ci, Rect2(-204, -122, 208, 122), stone, 11, 24)
	_masonry(ci, Rect2(-136, -232, 76, 110), stone.darkened(0.06), 11, 20)
	for k in 6:
		_masonry(ci, Rect2(-204 + k * 38, -138, 22, 16), stone, 8, 11)
	for k in 5:
		_sp(ci, _rect_pts(Rect2(-136 + k * 16, -244, 10, 12)), stone.darkened(0.06))
	_sp(ci, [Vector2(-142, -244), Vector2(-54, -244), Vector2(-98, -300)], Color("4b5058"))
	for k in 5:
		ci.draw_line(Vector2(-98, -300), Vector2(-138 + k * 20, -244), Color(0, 0, 0, 0.25), 1.0)
	for p in [Vector2(-180, -96), Vector2(-160, -96), Vector2(-104, -200), Vector2(-86, -200), Vector2(-104, -160), Vector2(-86, -160)]:
		_window(ci, Rect2(p, Vector2(5, 16)))
	ci.draw_rect(Rect2(-112, -210, 28, 36), team)
	ci.draw_rect(Rect2(-112, -210, 28, 36), Color(0, 0, 0, 0.3), false, 1.5)
	_sp(ci, [Vector2(-48, 0), Vector2(-48, -60), Vector2(-24, -80), Vector2(0, -60), Vector2(0, 0)], Color(0.14, 0.1, 0.07))
	for k in 5:
		ci.draw_line(Vector2(-45 + k * 10, -64), Vector2(-45 + k * 10, 0), Color(0.35, 0.33, 0.3), 2.0)
	for k in 5:
		ci.draw_line(Vector2(-48, -56 + k * 12), Vector2(0, -56 + k * 12), Color(0.35, 0.33, 0.3), 2.0)


static func _gunpowder(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		_window(ci, Rect2(-101, -210, 10, 14))
		_banner(ci, Vector2(-95, -300), team, t, 30)
		return
	# Star-fort bastion: sloped masonry glacis, gun ports with cannon, brick watchtower.
	var earth := Color("8a7b66")
	_sp(ci, [Vector2(-214, 0), Vector2(-204, -108), Vector2(-152, -142), Vector2(-40, -142), Vector2(12, -100), Vector2(22, 0)], earth)
	for r in 9:
		var y := -12.0 - r * 14.0
		ci.draw_line(Vector2(-210 + r * 1.2, y), Vector2(16 - r * 3.0, y), Color(0, 0, 0, 0.22), 1.2)
	_sp(ci, [Vector2(-40, -142), Vector2(12, -100), Vector2(22, 0), Vector2(-18, 0)], earth.darkened(0.15))
	_masonry(ci, Rect2(-152, -162, 112, 20), Color("6a5e52"), 10, 18)
	for k in 3:
		var gp := Vector2(-140 + k * 44, -120)
		ci.draw_rect(Rect2(gp, Vector2(22, 14)), Color(0.08, 0.07, 0.06))
		ci.draw_line(gp + Vector2(11, 7), gp + Vector2(34, 5), Color(0.18, 0.18, 0.2), 6.0)
	_masonry(ci, Rect2(-122, -224, 54, 62), Color("8a5a44"), 7, 12)
	_sp(ci, [Vector2(-128, -224), Vector2(-62, -224), Vector2(-95, -252)], Color("3a3f58"))
	_window(ci, Rect2(-101, -210, 10, 14))
	_planks(ci, Rect2(-42, -64, 36, 64), Color("3a2a1c"), 6)




static func _castrum(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		for p in [Vector2(-128, -186), Vector2(-66, -140), Vector2(-4, -140)]:
			_window(ci, Rect2(p, Vector2(6, 12)))
		# Torches at the gate.
		for x in [-52.0, -4.0]:
			var fl := 0.7 + 0.3 * sin(t * 12.0 + x)
			ci.draw_circle(Vector2(x, -70), 10.0, Color(1.0, 0.6, 0.25, 0.15 + 0.25 * night))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -66), Vector2(x + 3, -66), Vector2(x, -66 - 10 * fl)]), Color(1.0, 0.7, 0.3))
		# Legion standard: a square vexillum under a gilded eagle.
		var top := Vector2(-135, -318)
		ci.draw_line(top, top + Vector2(0, 84), Color("3b2c20"), 3.0)
		ci.draw_line(top + Vector2(-14, 10), top + Vector2(14, 10), Color("3b2c20"), 2.0)
		var sway := sin(t * 2.2) * 1.5
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-13, 10), top + Vector2(13, 10), top + Vector2(13 + sway, 36), top + Vector2(-13 + sway, 36)]), team)
		for k in 5:
			ci.draw_line(top + Vector2(-12 + k * 6 + sway, 36), top + Vector2(-12 + k * 6 + sway, 40), Color("d9b25c"), 1.5)
		ci.draw_circle(top + Vector2(0, -3), 5.0, Color("d9b25c"))
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-10, -6), top + Vector2(0, -2), top + Vector2(10, -6), top + Vector2(0, 2)]), Color("c9a24c"))
		return
	# Roman castrum: tufa wall with a timber walkway, tiled tower and a twin-towered gate.
	var tufa := Color("c2b08e")
	var tile := Color("b0583a")
	_masonry(ci, Rect2(-206, -110, 210, 110), tufa, 12, 28)
	_planks(ci, Rect2(-208, -124, 214, 14), Color("7a5a3a"), 8)
	for k in 14:
		ci.draw_rect(Rect2(-206 + k * 15, -134, 6, 10), Color("6a4a2e"))
	_masonry(ci, Rect2(-170, -206, 70, 96), tufa.lightened(0.05), 12, 20)
	_sp(ci, [Vector2(-180, -206), Vector2(-90, -206), Vector2(-135, -240)], tile)
	for k in 6:
		ci.draw_line(Vector2(-135, -240), Vector2(-176 + k * 16, -206), Color(0, 0, 0, 0.2), 1.0)
	for x in [-80.0, -14.0]:
		_masonry(ci, Rect2(x, -160, 30, 160), tufa.darkened(0.05), 11, 15)
		_sp(ci, [Vector2(x - 5, -160), Vector2(x + 35, -160), Vector2(x + 15, -184)], tile)
	for p in [Vector2(-128, -186), Vector2(-66, -140), Vector2(-4, -140)]:
		_window(ci, Rect2(p, Vector2(6, 12)))
	# Arched gate with timber doors.
	_sp(ci, [Vector2(-50, 0), Vector2(-50, -62), Vector2(-32, -80), Vector2(-14, -62), Vector2(-14, 0)], Color(0.12, 0.09, 0.07))
	_planks(ci, Rect2(-48, -58, 32, 58), Color("5b3f24"), 6)
	ci.draw_arc(Vector2(-32, -62), 18.0, PI, TAU, 12, tufa.darkened(0.25), 3.0)
	# Legion shields hung along the wall.
	for k in 4:
		var c := Vector2(-194 + k * 30, -70)
		_sp(ci, [c + Vector2(-8, -14), c + Vector2(8, -14), c + Vector2(9, 14), c + Vector2(-9, 14)], team.darkened(0.1))
		ci.draw_circle(c, 3.0, Color("d9b25c"))


static func _citadel(ci: CanvasItem, team: Color, t: float) -> void:
	var glow: Color = RaceLook.look(&"human").glow
	if dynamic_pass:
		var k := 0.6 + 0.4 * sin(t * 1.8)
		for p in [Vector2(-190, -92), Vector2(-160, -92), Vector2(-120, -92), Vector2(-112, -250), Vector2(-112, -200), Vector2(-186, -170)]:
			ci.draw_rect(Rect2(p, Vector2(10, 18)), Color(glow, 0.35 + 0.35 * night))
			ci.draw_rect(Rect2(p, Vector2(10, 18)).grow(4), Color(glow, 0.08 + 0.1 * night))
		# Floating crystal above the spire, and the ward across the gate.
		var c := Vector2(-108, -392 + sin(t * 1.4) * 5.0)
		for i in 4:
			ci.draw_circle(c, 34.0 - i * 7.0, Color(glow, 0.06 + i * 0.05 * k))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(9, 0), c + Vector2(0, 20), c + Vector2(-9, 0)]), glow.lightened(0.3))
		ci.draw_line(c + Vector2(0, -18), c + Vector2(0, 18), Color(1, 1, 1, 0.8), 1.5)
		for i in 5:
			var y := -8.0 - i * 13.0
			ci.draw_line(Vector2(-46, y), Vector2(-8, y), Color(glow, 0.25 + 0.2 * sin(t * 4.0 + i)), 1.5)
		_banner(ci, Vector2(-180, -254), team, t)
		return
	# Wizard citadel: violet-grey hall with buttresses, a slender brass-banded spire and a side turret.
	var stone := Color("6e6582")
	var roof := Color("3a2d5e")
	var brass := Color("c9a45c")
	_masonry(ci, Rect2(-206, -122, 210, 122), stone, 12, 24)
	for x in [-206.0, -138.0, -70.0]:
		_sp(ci, [Vector2(x, 0), Vector2(x, -110), Vector2(x + 14, -60), Vector2(x + 18, 0)], stone.darkened(0.12))
	for p in [Vector2(-190, -92), Vector2(-160, -92), Vector2(-120, -92)]:
		_sp(ci, [p + Vector2(0, 18), p, p + Vector2(5, -6), p + Vector2(10, 0), p + Vector2(10, 18)], Color(0.1, 0.08, 0.12))
	_masonry(ci, Rect2(-140, -286, 64, 164), stone.lightened(0.06), 12, 16)
	for y in [-150.0, -210.0, -270.0]:
		ci.draw_line(Vector2(-142, y), Vector2(-74, y), brass, 3.0)
	for p in [Vector2(-112, -250), Vector2(-112, -200)]:
		_sp(ci, [p + Vector2(0, 18), p, p + Vector2(5, -6), p + Vector2(10, 0), p + Vector2(10, 18)], Color(0.1, 0.08, 0.12))
	_sp(ci, [Vector2(-150, -286), Vector2(-66, -286), Vector2(-108, -360)], roof)
	ci.draw_line(Vector2(-108, -360), Vector2(-108, -366), brass, 3.0)
	_masonry(ci, Rect2(-200, -200, 36, 78), stone.darkened(0.04), 11, 12)
	_sp(ci, [Vector2(-206, -200), Vector2(-158, -200), Vector2(-182, -240)], roof)
	_sp(ci, [Vector2(-186, -170), Vector2(-186, -152), Vector2(-176, -152), Vector2(-176, -170), Vector2(-181, -176)], Color(0.1, 0.08, 0.12))
	# Gate: pointed arch in a brass frame.
	_sp(ci, [Vector2(-48, 0), Vector2(-48, -60), Vector2(-27, -86), Vector2(-6, -60), Vector2(-6, 0)], Color(0.09, 0.07, 0.11))
	ci.draw_polyline(PackedVector2Array([Vector2(-48, 0), Vector2(-48, -60), Vector2(-27, -86), Vector2(-6, -60), Vector2(-6, 0)]), brass, 2.0)
	ci.draw_rect(Rect2(-190, -60, 40, 20), team.darkened(0.1))


## Elven tree-hall: a great tree that gains decks, halls, a white tower and silver spires with each
## age, crowned with glowing crystal in the Arcane age.
static func _elf(ci: CanvasItem, age: int, team: Color, t: float) -> void:
	var look := Scenery.look(&"elf", age)
	var leaf: Color = look.leaf
	var glow: Color = RaceLook.look(&"elf").glow
	var bark := Color("5e4632")
	var wood := Color("9a7650")
	if dynamic_pass:
		if age >= 3:
			for p in [Vector2(-150, -150), Vector2(-60, -150), Vector2(-120, -222)]:
				var k := 0.8 + 0.2 * sin(t * 3.0 + p.x)
				ci.draw_circle(p, 12.0, Color(1.0, 0.85, 0.5, (0.1 + 0.25 * night) * k))
				ci.draw_circle(p, 3.0, Color(1.0, 0.9, 0.6, 0.5 + 0.5 * night))
		if age >= 5:
			ci.draw_circle(Vector2(-198, -238), 10.0, Color(glow, 0.25 + 0.2 * sin(t * 2.0)))
		if age == 6:
			for i in 8:
				var a := t * 0.4 + TAU * i / 8.0
				var p := Vector2(-110 + cos(a) * 90.0, -300 + sin(a * 1.3) * 40.0)
				ci.draw_circle(p, 2.2, Color(glow, 0.7 + 0.3 * sin(t * 3.0 + i)))
			var c := Vector2(-110, -372 + sin(t * 1.2) * 4.0)
			for i in 4:
				ci.draw_circle(c, 26.0 - i * 6.0, Color(glow, 0.06 + i * 0.06))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(7, 0), c + Vector2(0, 16), c + Vector2(-7, 0)]), glow.lightened(0.3))
			for i in 3:
				ci.draw_line(Vector2(-118, -60 - i * 50), Vector2(-104, -72 - i * 50), Color(glow, 0.5 + 0.3 * sin(t * 2.0 + i)), 2.0)
		# Leaf pennant at the crown.
		var top := Vector2(-110, -340) if age < 4 else Vector2(-27, -326)
		ci.draw_line(top, top + Vector2(0, 30), Color("3b2c20"), 2.0)
		var sway := sin(t * 3.0) * 3.0
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(0, 2), top + Vector2(22 + sway, 6), top + Vector2(34 + sway * 1.5, 4), top + Vector2(22 + sway, 12), top + Vector2(0, 14)]), team)
		return
	# Back canopy.
	for p in [Vector2(-170, -290), Vector2(-60, -296), Vector2(-110, -320)]:
		UnitArt._shade_poly(ci, UnitArt._ellipse_pts(p, Vector2(64, 40), 0.0, 14), leaf.darkened(0.25))
	# Trunk with root flare and bark grooves.
	_sp(ci, [Vector2(-196, 0), Vector2(-156, -18), Vector2(-138, -90), Vector2(-134, -262), Vector2(-86, -262), Vector2(-82, -90), Vector2(-62, -18), Vector2(-22, 0)], bark)
	for k in 5:
		var x := -130.0 + k * 10.0
		ci.draw_polyline(PackedVector2Array([Vector2(x, -250), Vector2(x + 2 + (k % 2) * 3, -150), Vector2(x - 2, -40)]), Color(0, 0, 0, 0.22), 1.5)
	for k in 3:
		ci.draw_line(Vector2(-140 - k * 14, -20 + k * 5), Vector2(-176 - k * 8, 0), bark.darkened(0.2), 3.0)
	# Branches reaching out to the canopy.
	ci.draw_line(Vector2(-130, -230), Vector2(-190, -280), bark, 8.0)
	ci.draw_line(Vector2(-90, -236), Vector2(-40, -286), bark, 8.0)
	match age:
		1:
			# Hide shelter against the roots, a lashed stake fence and an antler totem.
			_sp(ci, [Vector2(-210, 0), Vector2(-160, 0), Vector2(-176, -52)], Color("8a6440"))
			for k in 8:
				var x := -18.0 - k * 11.0
				_sp(ci, [Vector2(x - 3.5, 0), Vector2(x - 3.5, -34), Vector2(x, -42), Vector2(x + 3.5, -34), Vector2(x + 3.5, 0)], Color("6b4a2b"))
			ci.draw_line(Vector2(-100, -22), Vector2(-10, -20), Color("9a8a5a"), 2.0)
			ci.draw_line(Vector2(-150, 0), Vector2(-150, -84), Color("5a3a22"), 4.0)
			ci.draw_polyline(PackedVector2Array([Vector2(-150, -84), Vector2(-162, -104), Vector2(-160, -118)]), Color("d8cbb0"), 2.5)
			ci.draw_polyline(PackedVector2Array([Vector2(-150, -84), Vector2(-138, -104), Vector2(-140, -118)]), Color("d8cbb0"), 2.5)
		_:
			if age == 2:
				for k in 3:
					var x := -200.0 + k * 22.0
					_sp(ci, [Vector2(x - 8, 0), Vector2(x - 6, -42 - k * 4), Vector2(x + 2, -48 - k * 4), Vector2(x + 8, -40), Vector2(x + 8, 0)], Color("8a8a80"))
	# Decks (Bronze on) carry the turret mounts.
	if age >= 2:
		_planks(ci, Rect2(-182, -124, 170, 9), wood, 9)
		for x in [-176.0, -120.0, -60.0, -18.0]:
			ci.draw_line(Vector2(x, -115), Vector2(x + 8, -80), wood.darkened(0.3), 3.0)
		ci.draw_line(Vector2(-182, -140), Vector2(-12, -140), Color("c9b28a"), 1.2)
	if age >= 3:
		# Tree-hall wrapped round the trunk, leaf-shingle roof, round windows; upper deck.
		_planks(ci, Rect2(-172, -168, 130, 44), wood.lightened(0.05), 10)
		_sp(ci, [Vector2(-182, -168), Vector2(-32, -168), Vector2(-70, -190), Vector2(-144, -190)], leaf.darkened(0.1))
		for x in [-150.0, -60.0]:
			ci.draw_circle(Vector2(x, -150), 7.0, Color(0.1, 0.08, 0.06))
			ci.draw_arc(Vector2(x, -150), 7.0, 0, TAU, 12, Color("d9b25c"), 1.2)
		_planks(ci, Rect2(-156, -202, 112, 7), wood, 9)
	if age >= 4:
		# White stone tower with a green cone roof, bound by vines.
		var white := Color("e6e2d8")
		_masonry(ci, Rect2(-40, -262, 26, 262), white, 13, 13)
		_sp(ci, [Vector2(-46, -262), Vector2(-8, -262), Vector2(-27, -318)], leaf.darkened(0.05))
		for k in 5:
			ci.draw_arc(Vector2(-27, -40 - k * 50), 14.0, 0.3, 2.8, 8, leaf.darkened(0.2), 2.0)
		_window(ci, Rect2(-30, -230, 6, 14))
	if age >= 5:
		# Silver spire on the far side.
		_sp(ci, [Vector2(-206, 0), Vector2(-204, -200), Vector2(-198, -232), Vector2(-192, -200), Vector2(-190, 0)], Color("cfd6dc"))
		ci.draw_line(Vector2(-198, -232), Vector2(-198, -250), Color("dfe6ee"), 1.5)
	# Gate.
	if age <= 2:
		ci.draw_arc(Vector2(-22, 0), 20.0, PI, TAU, 10, bark.lightened(0.1), 4.0)
		for k in 3:
			ci.draw_line(Vector2(-36 + k * 14, 0), Vector2(-34 + k * 12, -18), leaf.darkened(0.2), 2.0)
	else:
		_sp(ci, [Vector2(-40, 0), Vector2(-40, -48), Vector2(-22, -68), Vector2(-4, -48), Vector2(-4, 0)], Color(0.1, 0.08, 0.06))
		ci.draw_polyline(PackedVector2Array([Vector2(-40, 0), Vector2(-40, -48), Vector2(-22, -68), Vector2(-4, -48), Vector2(-4, 0)]), Color("d9b25c") if age >= 4 else wood, 2.0)
	# Front canopy.
	var canopy := leaf if age != 6 else leaf.lerp(glow, 0.25)
	for p in [Vector2(-196, -262), Vector2(-40, -272), Vector2(-120, -300), Vector2(-150, -330), Vector2(-80, -330)]:
		UnitArt._shade_poly(ci, UnitArt._ellipse_pts(p, Vector2(40, 26), 0.2, 12), canopy)


## Dwarven hold carved into a mountain: cave → carved door → fortified gate → towered hold → forge-fort
## → rune-hold.
static func _dwarf(ci: CanvasItem, age: int, team: Color, t: float) -> void:
	var glow: Color = RaceLook.look(&"dwarf").glow
	var rock := Color("6e6a64") if age != 2 else Color("8a5a40")
	if age == 6:
		rock = Color("4a4a58")
	var stone := rock.lightened(0.12)
	var iron := Color("4a4c52")
	if dynamic_pass:
		if age >= 3:
			for x in [-58.0, 10.0]:
				var fl := 0.7 + 0.3 * sin(t * 11.0 + x)
				var c: Color = Color(1.0, 0.6, 0.25) if age < 6 else glow
				ci.draw_circle(Vector2(x, -84), 12.0, Color(c, 0.15 + 0.25 * night))
				for k in 3:
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 5 + k * 3, -78), Vector2(x - 2 + k * 3, -78), Vector2(x - 3.5 + k * 3, -80 - 12 * fl - k * 2)]), c.lightened(0.2 * k))
		if age in [4, 5]:
			for p in [Vector2(-186, -150), Vector2(-150, -150), Vector2(-86, -210)]:
				ci.draw_rect(Rect2(p, Vector2(12, 10)), Color(1.0, 0.55, 0.2, 0.6 + 0.3 * sin(t * 6.0 + p.x)))
			for i in 5:
				var ph := fmod(t * 0.4 + i * 0.2, 1.0)
				var src := Vector2(-184, -300) if age == 5 else Vector2(-160, -262)
				ci.draw_circle(src + Vector2(ph * 30, -ph * 80), 7 + ph * 18, Color(0.3, 0.28, 0.28, 0.5 * (1.0 - ph)))
		if age == 5:
			var c := Vector2(-120, -60)
			for k in 8:
				var a := t * 1.2 + TAU * k / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 6.0, c + Vector2(cos(a), sin(a)) * 16.0, Color("c9a45c"), 3.0)
		if age == 6:
			var k := 0.55 + 0.45 * sin(t * 1.6)
			for i in 4:
				var p := Vector2(-190 + i * 40, -40 - (i % 2) * 70)
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(8, -14), p + Vector2(16, 0), p + Vector2(24, -14)]), Color(glow, 0.8 * k), 2.0)
			ci.draw_polyline(PackedVector2Array([Vector2(-48, -76), Vector2(-26, -96), Vector2(-4, -76)]), Color(glow, 0.9 * k), 2.5)
			var c := Vector2(-150, -330 + sin(t * 1.3) * 5.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 16), c + Vector2(-14, -12), c + Vector2(0, -22), c + Vector2(14, -10), c + Vector2(12, 18)]), stone)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(0, 6), c + Vector2(5, -6)]), Color(glow, k), 2.0)
			for i in 3:
				ci.draw_circle(c, 26.0 - i * 7.0, Color(glow, 0.05 + i * 0.04 * k))
		# Banner on the peak: a dwarf standard with a notched hem.
		var top := Vector2(-150, -312) if age < 6 else Vector2(-196, -262)
		ci.draw_line(top, top + Vector2(0, 50), Color("3b2c20"), 3.0)
		ci.draw_line(top + Vector2(-2, 4), top + Vector2(26, 4), Color("3b2c20"), 2.0)
		var sway := sin(t * 2.4) * 1.2
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(0, 4), top + Vector2(24, 4), top + Vector2(24 + sway, 34), top + Vector2(18 + sway, 28), top + Vector2(12 + sway, 34), top + Vector2(6 + sway, 28), top + Vector2(0 + sway, 34)]), team)
		return
	# The mountain.
	_sp(ci, [Vector2(-230, 0), Vector2(-224, -120), Vector2(-200, -214), Vector2(-150, -272), Vector2(-112, -258), Vector2(-72, -206), Vector2(-34, -160), Vector2(-4, -126), Vector2(12, -80), Vector2(16, 0)], rock)
	_sp(ci, [Vector2(-150, -272), Vector2(-112, -258), Vector2(-90, -230), Vector2(-132, -226)], rock.lightened(0.14))
	for k in 7:
		var a := Vector2(-214 + k * 30, -60 - (k % 3) * 50)
		ci.draw_polyline(PackedVector2Array([a, a + Vector2(10, 12), a + Vector2(4, 26)]), Color(0, 0, 0, 0.28), 1.5)
	if age == 1 or age == 3:
		_sp(ci, [Vector2(-166, -256), Vector2(-150, -272), Vector2(-112, -258), Vector2(-122, -246), Vector2(-146, -250)], Color("eef2f6"))
	match age:
		1:
			# Cave mouth with a hide flap, a stacked-stone wall and a cairn.
			_sp(ci, [Vector2(-60, 0), Vector2(-56, -52), Vector2(-34, -72), Vector2(-10, -54), Vector2(-6, 0)], Color(0.08, 0.06, 0.05))
			_sp(ci, [Vector2(-56, -48), Vector2(-40, -66), Vector2(-40, 0), Vector2(-56, 0)], Color("8a6440"))
			for k in 9:
				UnitArt._shade_poly(ci, UnitArt._ellipse_pts(Vector2(-200 + k * 15, -10 - (k % 2) * 8), Vector2(9, 7), 0.0, 8), stone)
			for k in 4:
				UnitArt._shade_poly(ci, UnitArt._ellipse_pts(Vector2(-110, -126 - k * 12), Vector2(12 - k * 2, 6), 0.0, 8), stone.darkened(0.05 * k))
		_:
			# Carved facade with a ledge for the turret mounts.
			_masonry(ci, Rect2(-196, -122, 200, 122), stone, 16, 34)
			_sp(ci, _rect_pts(Rect2(-200, -130, 208, 10)), stone.darkened(0.2))
			if age >= 3:
				for k in 9:
					_sp(ci, _rect_pts(Rect2(-196 + k * 24, -144, 14, 14)), stone.darkened(0.08))
			# Door: carved lintel (Bronze), then iron-bound double doors.
			_sp(ci, [Vector2(-54, 0), Vector2(-54, -70), Vector2(2, -70), Vector2(2, 0)], Color(0.08, 0.07, 0.06))
			_sp(ci, _rect_pts(Rect2(-62, -84, 72, 16)), stone.darkened(0.12) if age != 2 else Color("b87a3a"))
			if age >= 3:
				for x in [-52.0, -25.0]:
					_sp(ci, _rect_pts(Rect2(x, -68, 25, 68)), iron if age != 5 else Color("8a6a3a"))
					for r in 3:
						_rivets_line(ci, Vector2(x + 3, -60 + r * 22), Vector2(x + 22, -60 + r * 22), 4, Color("9aa0a6"))
				ci.draw_circle(Vector2(-26, -34), 4.0, Color("c9a45c"))
			else:
				_planks(ci, Rect2(-52, -68, 52, 68), Color("5b3f24"), 8)
				for k in 3:
					ci.draw_line(Vector2(-54, -56 + k * 22), Vector2(2, -56 + k * 22), Color("b87a3a"), 3.0)
			# Guardian faces carved beside the door.
			for x in [-86.0]:
				_sp(ci, UnitArt._ellipse_pts(Vector2(x, -84), Vector2(16, 18), 0.0, 12), stone.lightened(0.05))
				_sp(ci, [Vector2(x - 14, -80), Vector2(x + 14, -80), Vector2(x + 6, -34), Vector2(x, -26), Vector2(x - 6, -34)], stone.darkened(0.08))
				ci.draw_line(Vector2(x - 8, -90), Vector2(x - 2, -90), Color(0, 0, 0, 0.5), 2.0)
				ci.draw_line(Vector2(x + 2, -90), Vector2(x + 8, -90), Color(0, 0, 0, 0.5), 2.0)
	if age >= 4:
		# Towers carved from the rock.
		for r in [Rect2(-204, -214, 40, 92), Rect2(-104, -246, 44, 124)]:
			_masonry(ci, r, stone.darkened(0.04), 12, 14)
			for k in 3:
				_sp(ci, _rect_pts(Rect2(r.position.x + k * 16, r.position.y - 10, 10, 10)), stone.darkened(0.1))
		for p in [Vector2(-186, -150), Vector2(-150, -150), Vector2(-86, -210)]:
			ci.draw_rect(Rect2(p, Vector2(12, 10)), Color(0.08, 0.06, 0.05))
	if age == 5:
		# Chimney stacks and brass pipes; a gear housing.
		_sp(ci, _rect_pts(Rect2(-192, -300, 18, 88)), iron)
		for k in 3:
			ci.draw_rect(Rect2(-194, -290 + k * 26, 22, 4), Color("8a6a3a"))
		ci.draw_polyline(PackedVector2Array([Vector2(-174, -236), Vector2(-150, -236), Vector2(-150, -126)]), Color("b8914a"), 5.0)
		ci.draw_circle(Vector2(-120, -60), 18.0, iron)
		ci.draw_circle(Vector2(-120, -60), 6.0, Color("c9a45c"))
	if age == 6:
		for i in 4:
			var p := Vector2(-190 + i * 40, -40 - (i % 2) * 70)
			ci.draw_polyline(PackedVector2Array([p, p + Vector2(8, -14), p + Vector2(16, 0), p + Vector2(24, -14)]), Color(0, 0, 0, 0.4), 3.0)


static func _rivets_line(ci: CanvasItem, a: Vector2, b: Vector2, n: int, col: Color) -> void:
	for i in n:
		ci.draw_circle(a.lerp(b, i / float(maxi(1, n - 1))), 1.3, col)


## Turret on a slot. `aim` is the barrel angle (0 = level toward the enemy); `kick` 0..1 recoil.
## Same stats for every race; the build follows the race (bows for elves, crossbows and organ guns
## for dwarves, engines and guns for humans) and arcane turrets glow in the race's colour.
static func draw_turret(ci: CanvasItem, def: TurretDef, team: Color, aim: float, kick: float, t: float, outclassed: bool, race: StringName = &"human") -> void:
	var pal: Array = RaceLook.palette(race, def.age)
	var glow: Color = RaceLook.look(race).glow
	var metal: Color = pal[2]
	var wood := Color("6b4a2b") if race != &"elf" else Color("a88a5a")
	var dim := 0.35 if outclassed else 0.0
	var arcane := def.age >= 6
	match def.kind:
		"sentry":
			if race != &"elf":
				ci.draw_rect(Rect2(-12, -6, 24, 16), wood.darkened(dim) if def.age <= 3 else metal.darkened(0.3 + dim))
			var dirv := Vector2.RIGHT.rotated(aim)
			var n := dirv.orthogonal()
			var base := Vector2(0, -8)
			var bowlike := race == &"elf" or (race == &"dwarf" and def.age <= 4) or (race == &"human" and def.age in [2, 3, 4])
			if bowlike:
				# Bow or crossbow on a swivel: limbs across the aim, string drawn back until it looses.
				var span := 16.0 if race == &"elf" else 11.0
				var pull := 6.0 * (1.0 - kick)
				var tip := base + dirv * (18.0 if race == &"dwarf" else 10.0)
				var a := tip - n * span - dirv * 5.0
				var b := tip + n * span - dirv * 5.0
				ci.draw_polyline(PackedVector2Array([a, tip, b]), (wood.lightened(0.2) if not arcane else glow).darkened(dim), 3.0)
				ci.draw_polyline(PackedVector2Array([a, tip - dirv * (5.0 + pull), b]), Color(0.9, 0.88, 0.8, 0.8), 1.0)
				if race != &"elf":
					ci.draw_line(base - dirv * 6.0, tip + dirv * 4.0, wood.darkened(0.2 + dim), 4.0)
				ci.draw_line(tip - dirv * (5.0 + pull), tip + dirv * 12.0, Color(glow, 0.9) if def.age >= 5 and race == &"elf" else wood.lightened(0.3), 1.5)
			elif race == &"dwarf" and def.age == 5:
				# Organ gun: a fan of short barrels.
				for k in 3:
					var o := n * (k - 1) * 4.0
					ci.draw_line(base + o - dirv * kick * 4.0, base + o + dirv * (24.0 - kick * 4.0), metal.darkened(0.1 + dim), 3.5)
			else:
				var length := 22.0 + def.age * 2.0
				ci.draw_line(base - dirv * kick * 5.0, base + dirv * (length - kick * 5.0), metal.darkened(dim), 5.0 + def.age * 0.5)
				if arcane:
					ci.draw_line(base + dirv * 6.0, base + dirv * (length - 4.0), Color(glow, 0.8), 2.0)
			ci.draw_circle(base, 7.0, team.darkened(dim))
			if arcane:
				ci.draw_circle(base, 3.0, Color(glow, 0.6 + 0.3 * sin(t * 4.0)))
		"artillery":
			if race != &"elf":
				ci.draw_rect(Rect2(-16, -4, 32, 14), wood.darkened(0.2 + dim) if def.age <= 3 else metal.darkened(0.35 + dim))
			var base := Vector2(-2, -8)
			if race == &"elf" and not arcane:
				# Leaf-wood throwing arm.
				var arm := lerpf(-2.6, -1.3, kick)
				var tip := base + Vector2(30, 0).rotated(arm)
				ci.draw_line(base, tip, wood.darkened(dim), 4.0)
				ci.draw_circle(tip, 4.0, Color(glow, 0.8) if def.age >= 5 else Color("7b7466"))
			else:
				var dirv := Vector2.RIGHT.rotated(minf(aim, 0.0) - 0.55)
				var w := 12.0 if race == &"dwarf" else 10.0
				ci.draw_line(base - dirv * kick * 7.0, base + dirv * (30.0 - kick * 7.0), metal.darkened(0.15 + dim), w)
				if race == &"dwarf":
					for k in 2:
						var p := base + dirv * (10.0 + k * 10.0 - kick * 7.0)
						ci.draw_line(p - dirv.orthogonal() * 6.5, p + dirv.orthogonal() * 6.5, Color("c9a45c").darkened(dim), 2.0)
				ci.draw_circle(base + dirv * (30.0 - kick * 7.0), 5.5, Color(glow, 0.8) if arcane else Color(0.1, 0.1, 0.1))
			ci.draw_circle(base, 7.0, team.darkened(dim))
		"support":
			var pulse := 0.5 + 0.5 * sin(t * 3.0)
			if race == &"elf":
				if def.age <= 4:
					# Thorn bramble (Thornbrake / Mistwell sit in a knot of briars).
					for n in 5:
						var c := Vector2(-10 + n * 5, -8 - (n % 2) * 6)
						UnitArt._ellipse(ci, c, Vector2(8, 6), Color("3e5a2e").darkened(dim + 0.05 * (n % 2)))
						ci.draw_line(c, c + Vector2(-4 + n * 2, -9), Color("6e5236").darkened(dim), 1.2)
					if def.age == 4:
						for n in 3:
							ci.draw_circle(Vector2(-6 + n * 6, -18 - pulse * 6 - n * 3), 3.0, Color(0.85, 0.92, 0.95, 0.45))
				else:
					# A seed-pod of light cupped in petals.
					for n in 4:
						var a := PI + (n + 0.5) * PI / 4.0
						UnitArt._ellipse(ci, Vector2(cos(a), sin(a)) * 8.0 + Vector2(0, -6), Vector2(8, 3.5), Color("e8eef6").darkened(dim), a)
					ci.draw_circle(Vector2(0, -12), 6.0, Color(glow, 0.5 + 0.4 * pulse))
				return
			match def.age:
				3, 4:
					# Cauldron / smoke pot / thorn thicket / steam vent.
					ci.draw_rect(Rect2(-14, -18, 28, 20), Color("3a3a3a") if race != &"elf" else Color("4f6a3a"))
					for i in 3:
						ci.draw_circle(Vector2(-6 + i * 6, -22 - pulse * 6 - i * 3), 3.0, Color(0.2, 0.18, 0.15, 0.6) if race != &"dwarf" else Color(0.85, 0.85, 0.85, 0.5))
				_:
					ci.draw_rect(Rect2(-10, -24, 20, 26), metal.darkened(0.3 + dim))
					ci.draw_circle(Vector2(0, -26), 6.0, Color((glow if arcane else team.lightened(0.4)), 0.5 + 0.4 * pulse))


## An unlocked slot with nothing built: a marked foundation on the ground.
static func draw_pad(ci: CanvasItem, race: StringName) -> void:
	var col: Color = {&"elf": Color("6a5a3a"), &"dwarf": Color("6e6a64")}.get(race, Color("7a6a54"))
	UnitArt._ellipse(ci, Vector2(0, 2), Vector2(22, 5), Color(0, 0, 0, 0.25))
	ci.draw_rect(Rect2(-18, -5, 36, 6), col)
	ci.draw_line(Vector2(-18, -5), Vector2(18, -5), col.lightened(0.2), 1.2)
	for x in [-14.0, 14.0]:
		ci.draw_line(Vector2(x, -5), Vector2(x, -14), col.darkened(0.2), 2.0)


## A turret's tower, feet at the origin, drawn at TOWER_SCALE by the caller. Each race builds its own:
## human posts, plinths and stone towers up to an arcane pylon; elven living-wood stands and white
## spires; squat dwarven stone bastions. `dim` darkens an outclassed tower.
static func draw_tower(ci: CanvasItem, race: StringName, age: int, team: Color, t: float, dim := 0.0) -> void:
	var h := tower_height(race, age)
	var glow: Color = RaceLook.look(race).glow
	var tm := team.darkened(0.1 + dim)
	UnitArt._ellipse(ci, Vector2(0, 2), Vector2(24, 5), Color(0, 0, 0, 0.3))
	match race:
		&"elf":
			_elf_tower(ci, age, h, tm, glow, t, dim)
		&"dwarf":
			var stone := (Color("8a8278") if age != 2 else Color("9a6a4a")).darkened(dim)
			if age == 6:
				stone = Color("5a5a68").darkened(dim)
			if age <= 1:
				# Stacked-stone cairn tower.
				for k in 4:
					var w := 22.0 - k * 2.0
					_sp(ci, UnitArt._ellipse_pts(Vector2(0, -5 - k * 9.5), Vector2(w, 6), 0.0, 10), stone.darkened(0.05 * (k % 2)))
			else:
				_masonry(ci, Rect2(-22, -h, 44, h), stone, 9, 15)
				for k in 4:
					_sp(ci, _rect_pts(Rect2(-24 + k * 13, -h - 7, 9, 7)), stone.darkened(0.08))
				var band := Color("b87a3a") if age == 2 else (Color("b8914a") if age == 5 else Color("4a4c52"))
				ci.draw_line(Vector2(-23, -h * 0.35), Vector2(23, -h * 0.35), band.darkened(dim), 3.0)
				# Team shield on the face.
				ci.draw_circle(Vector2(0, -h * 0.62), 7.0, Color("4a4c52").darkened(dim))
				ci.draw_circle(Vector2(0, -h * 0.62), 5.5, tm)
				if age == 6:
					var k := 0.55 + 0.45 * sin(t * 1.6)
					ci.draw_polyline(PackedVector2Array([Vector2(-14, -10), Vector2(-9, -18), Vector2(-4, -10), Vector2(1, -18)]), Color(glow, 0.85 * k), 2.0)
				if age == 5:
					ci.draw_polyline(PackedVector2Array([Vector2(18, -4), Vector2(18, -h * 0.5), Vector2(26, -h * 0.5)]), Color("b8914a").darkened(dim), 3.0)
		_:
			var wood := Color("6b4a2b").darkened(dim)
			match age:
				1:
					# Lookout on lashed posts.
					for x in [-12.0, 12.0]:
						ci.draw_line(Vector2(x, 0), Vector2(x * 0.8, -h), wood, 4.0)
					ci.draw_line(Vector2(-12, -6), Vector2(10, -h + 6), wood.darkened(0.2), 2.5)
					ci.draw_line(Vector2(12, -6), Vector2(-10, -h + 6), wood.darkened(0.2), 2.5)
					_planks(ci, Rect2(-17, -h - 4, 34, 6), wood.lightened(0.1), 6)
					ci.draw_line(Vector2(-10, -h * 0.5), Vector2(10, -h * 0.5), Color("b09060").darkened(dim), 1.5)
				2:
					_masonry(ci, Rect2(-15, -h, 30, h), Color("e1d3b3").darkened(dim), 10, 15)
					_sp(ci, _rect_pts(Rect2(-18, -h - 5, 36, 6)), Color("c9a060").darkened(dim))
					ci.draw_circle(Vector2(0, -h * 0.5), 5.0, Color("c28c3e").darkened(dim))
				3:
					_masonry(ci, Rect2(-16, -h * 0.45, 32, h * 0.45), Color("c2b08e").darkened(dim), 10, 16)
					for x in [-14.0, 14.0]:
						ci.draw_line(Vector2(x, -h * 0.45), Vector2(x, -h), wood, 4.0)
					ci.draw_line(Vector2(-14, -h * 0.45), Vector2(14, -h), wood.darkened(0.2), 2.5)
					_sp(ci, [Vector2(-20, -h), Vector2(20, -h), Vector2(16, -h + 6), Vector2(-16, -h + 6)], Color("b0583a").darkened(dim))
					_sp(ci, _rect_pts(Rect2(-9, -h * 0.4, 18, 12)), tm)
				4:
					_masonry(ci, Rect2(-18, -h, 36, h), Color("8d8e8a").darkened(dim), 10, 14)
					for k in 3:
						_sp(ci, _rect_pts(Rect2(-20 + k * 15, -h - 7, 10, 7)), Color("8d8e8a").darkened(0.08 + dim))
					_window(ci, Rect2(-2, -h * 0.6, 4, 12))
					ci.draw_rect(Rect2(-8, -h * 0.35, 16, 12), tm)
				5:
					# Earthwork bastion with a brick cap and gabions.
					_sp(ci, [Vector2(-24, 0), Vector2(-16, -h + 8), Vector2(16, -h + 8), Vector2(24, 0)], Color("8a7b66").darkened(dim))
					_masonry(ci, Rect2(-18, -h, 36, 9), Color("8a5a44").darkened(dim), 4.5, 9)
					for x in [-28.0, 28.0]:
						_sp(ci, _rect_pts(Rect2(x - 6, -14, 12, 14)), Color("6a5a40").darkened(dim))
					ci.draw_rect(Rect2(-8, -h * 0.5, 16, 10), tm)
				_:
					# Arcane pylon: slender stone, brass rings, a glowing crystal band.
					_sp(ci, [Vector2(-14, 0), Vector2(-9, -h), Vector2(9, -h), Vector2(14, 0)], Color("6e6582").darkened(dim))
					for k in 3:
						var y := -14.0 - k * (h - 24) / 2.0
						ci.draw_line(Vector2(-13 + k * 1.5, y), Vector2(13 - k * 1.5, y), Color("c9a45c").darkened(dim), 2.5)
					var k := 0.6 + 0.4 * sin(t * 2.2)
					ci.draw_rect(Rect2(-3, -h * 0.7, 6, h * 0.3), Color(glow, 0.5 + 0.4 * k))
					ci.draw_rect(Rect2(-8, -h * 0.25, 16, 9), tm)
					_sp(ci, _rect_pts(Rect2(-14, -h - 4, 28, 5)), Color("c9a45c").darkened(dim))


## Elven towers are grown or woven from nature, not built: a mossy standing stone with a nest, a
## wicker tower, braided living roots, a vine-bound white stone column with a leaf balcony, a
## flower on a tall stem cupping the turret, and a cluster of glowing crystal under a floating leaf.
static func _elf_tower(ci: CanvasItem, age: int, h: float, tm: Color, glow: Color, t: float, dim: float) -> void:
	var moss := Color("5f7f3a").darkened(dim)
	var leaf := Color("4f7a3a").darkened(dim)
	var wicker := Color("b08e5a").darkened(dim)
	var stone := Color("9a968a").darkened(dim)
	var gold := Color("d9b25c").darkened(dim)
	match age:
		1:
			# Mossy standing stone, lashed with vines, a woven nest on top.
			_sp(ci, UnitArt._ellipse_pts(Vector2(0, -6), Vector2(22, 9), 0.0, 12), stone.darkened(0.1))
			_sp(ci, [Vector2(-12, -8), Vector2(-11, -h + 12), Vector2(-5, -h + 5), Vector2(7, -h + 7), Vector2(12, -h + 16), Vector2(12, -8)], stone)
			for p in [Vector2(-8, -h + 14), Vector2(6, -h * 0.5), Vector2(-5, -18)]:
				UnitArt._ellipse(ci, p, Vector2(7, 4), moss, 0.3)
			var vine := PackedVector2Array()
			for n in 13:
				var y := -8.0 - n * (h - 16) / 12.0
				vine.append(Vector2(sin(n * 1.1) * 12.0, y))
			ci.draw_polyline(vine, leaf, 2.0)
			_nest(ci, Vector2(0, -h), 18.0, wicker)
		2:
			# Woven wicker tower: tapered basket of staves and bands, a leaf collar.
			var pts := [Vector2(-17, 0), Vector2(-11, -h), Vector2(11, -h), Vector2(17, 0)]
			_sp(ci, pts, wicker)
			for n in 5:
				var x := -12.0 + n * 6.0
				ci.draw_line(Vector2(x * 1.35, 0), Vector2(x, -h), wicker.darkened(0.3), 1.2)
			var rows := int(h / 5.0)
			for r in rows:
				var y := -3.0 - r * 5.0
				var w := lerpf(17.0, 11.0, -y / h) - 1.0
				ci.draw_polyline(PackedVector2Array([Vector2(-w, y - 1.5), Vector2(0, y + 1.0), Vector2(w, y - 1.5)]), wicker.lightened(0.12) if r % 2 == 0 else wicker.darkened(0.15), 2.0)
			for n in 7:
				var a := PI + n * PI / 6.0
				UnitArt._ellipse(ci, Vector2(cos(a) * 15.0, -h + 2 + sin(a) * 3.0), Vector2(7, 3), leaf.lightened(0.05 * (n % 2)), a)
			_sp(ci, UnitArt._ellipse_pts(Vector2(0, -h), Vector2(17, 4), 0.0, 12), wicker.darkened(0.1))
			for x in [-18.0, 18.0]:
				UnitArt._ellipse(ci, Vector2(x, -2), Vector2(8, 4), moss)
		3:
			# Three living roots braided into a column, cupping the platform.
			for strand in 3:
				var line := PackedVector2Array()
				for n in 17:
					var u := n / 16.0
					var spread := lerpf(18.0, 6.0, sin(u * PI) * 0.9 + u * 0.1)
					line.append(Vector2(sin(u * 9.0 + strand * TAU / 3.0) * spread, -u * h))
				ci.draw_polyline(line, Color("6e5236").darkened(dim + 0.1 * strand), 6.5 - strand * 0.5)
			for x in [-22.0, -12.0, 14.0, 23.0]:
				ci.draw_line(Vector2(x * 0.4, -6), Vector2(x, 1), Color("5e4630").darkened(dim), 3.0)
			ci.draw_arc(Vector2(0, -h + 6), 16.0, 0.2, PI - 0.2, 12, Color("6e5236").darkened(dim), 5.0)
			_sp(ci, UnitArt._ellipse_pts(Vector2(0, -h), Vector2(16, 4), 0.0, 12), moss)
			for p in [Vector2(-15, -h + 4), Vector2(16, -h + 6), Vector2(-9, -h * 0.55), Vector2(10, -h * 0.3)]:
				UnitArt._ellipse(ci, p, Vector2(5, 2.5), leaf, -0.6 if p.x < 0 else 0.6)
		4:
			# Vine-bound white stone column with a leaf-shaped balcony.
			var white := Color("e8e4da").darkened(dim)
			_sp(ci, [Vector2(-13, 0), Vector2(-9, -h + 6), Vector2(9, -h + 6), Vector2(13, 0)], white)
			for n in 4:
				ci.draw_line(Vector2(-10 + n * 0.8, -12 - n * (h - 20) / 4.0), Vector2(10 - n * 0.8, -12 - n * (h - 20) / 4.0), white.darkened(0.12), 1.0)
			var vine := PackedVector2Array()
			for n in 25:
				var u := n / 24.0
				vine.append(Vector2(sin(u * 14.0) * 11.0, -u * (h - 6)))
			ci.draw_polyline(vine, leaf, 2.0)
			for n in 7:
				var u := (n + 0.5) / 7.0
				UnitArt._ellipse(ci, Vector2(sin(u * 14.0) * 11.0 + 3.0, -u * (h - 6)), Vector2(4, 2), leaf.lightened(0.1), 0.5)
			# Balcony: a broad leaf with a gilt rib, tips curling up.
			_sp(ci, [Vector2(-22, -h + 2), Vector2(-14, -h + 7), Vector2(14, -h + 7), Vector2(22, -h + 2), Vector2(12, -h - 2), Vector2(-12, -h - 2)], leaf.lightened(0.05))
			ci.draw_line(Vector2(-20, -h + 2), Vector2(20, -h + 2), gold, 1.2)
		5:
			# A great flower: a curving stem with broad leaves, petals cupping the turret.
			var stem := PackedVector2Array()
			for n in 13:
				var u := n / 12.0
				stem.append(Vector2(sin(u * 3.0) * 5.0, -u * (h - 8)))
			ci.draw_polyline(stem, Color("4f7a3a").darkened(dim), 7.0)
			for side in [-1.0, 1.0]:
				var base := Vector2(side * 3.0, -h * (0.3 if side < 0 else 0.5))
				_sp(ci, [base, base + Vector2(side * 14, -12), base + Vector2(side * 26, -6), base + Vector2(side * 14, 2)], leaf.lightened(0.08))
				ci.draw_line(base, base + Vector2(side * 24, -6), leaf.darkened(0.2), 1.0)
			var petal := Color("e8eef6").darkened(dim)
			for n in 5:
				var a := PI + (n + 0.5) * PI / 5.0
				var d := Vector2(cos(a), sin(a))
				_sp(ci, [Vector2(0, -h + 6), Vector2(0, -h + 6) + d * 14 + d.orthogonal() * 6, Vector2(0, -h + 6) + d * 22, Vector2(0, -h + 6) + d * 14 - d.orthogonal() * 6], petal.lerp(glow, 0.15 * (n % 2)))
			var k := 0.6 + 0.4 * sin(t * 2.0)
			for n in 4:
				var a := t * 0.8 + n * TAU / 4.0
				ci.draw_circle(Vector2(cos(a) * 16.0, -h - 4 + sin(a) * 5.0), 1.4, Color(glow, 0.7 * k))
		_:
			# Crystal bloom: faceted shards grown from a mossy mound, a leaf floating above them.
			_sp(ci, UnitArt._ellipse_pts(Vector2(0, -4), Vector2(22, 9), 0.0, 12), moss)
			var crystal := Color("cfe6f2").lerp(glow, 0.35).darkened(dim)
			var k := 0.6 + 0.4 * sin(t * 1.8)
			for p in [[-9.0, 0.62, -0.2], [9.0, 0.7, 0.18], [0.0, 0.9, 0.0]]:
				var x: float = p[0]
				var sh: float = p[1] * (h - 14)
				var lean: float = p[2]
				var base := Vector2(x, -6)
				var tip := base + Vector2(0, -sh).rotated(lean)
				var side := Vector2(6, 0).rotated(lean)
				_sp(ci, [base - side, tip - side * 0.6 + Vector2(0, 8).rotated(lean), tip, tip + side * 0.6 + Vector2(0, 8).rotated(lean), base + side], crystal)
				ci.draw_line(base, tip, Color(1, 1, 1, 0.5), 1.0)
			ci.draw_circle(Vector2(0, -h * 0.5), 12.0, Color(glow, 0.18 * k))
			# Motes rising from the crystals hold up the floating leaf.
			for n in 4:
				var u := fmod(t * 0.5 + n * 0.25, 1.0)
				ci.draw_circle(Vector2(-8 + n * 5, lerpf(-h * 0.8, -h + 6, u)), 1.5, Color(glow, 0.8 * (1.0 - u)))
			var hover := sin(t * 1.5) * 2.0
			ci.draw_circle(Vector2(0, -h + 6 + hover), 16.0, Color(glow, 0.12 + 0.08 * k))
			_sp(ci, [Vector2(-28, -h + 1 + hover), Vector2(-16, -h + 7 + hover), Vector2(16, -h + 7 + hover), Vector2(28, -h + 1 + hover), Vector2(16, -h - 3 + hover), Vector2(-16, -h - 3 + hover)], leaf.lerp(glow, 0.25))
			ci.draw_line(Vector2(-26, -h + 2 + hover), Vector2(26, -h + 2 + hover), Color(glow, 0.8), 1.4)
			for x in [-12.0, 0.0, 12.0]:
				ci.draw_line(Vector2(x, -h + 2 + hover), Vector2(x + 5, -h + 6 + hover), Color(glow, 0.5), 1.0)
	# Team colour: a leaf-shaped ribbon tied round the tower.
	var ry := -h * 0.45
	ci.draw_colored_polygon(PackedVector2Array([Vector2(8, ry), Vector2(18, ry + 3), Vector2(24, ry + 10), Vector2(16, ry + 8), Vector2(8, ry + 5)]), tm)


static func _nest(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_sp(ci, UnitArt._ellipse_pts(c + Vector2(0, 2), Vector2(r, 5), 0.0, 12), col.darkened(0.15))
	for n in 7:
		var x := -r + n * r / 3.0
		ci.draw_line(c + Vector2(x - 5, -1), c + Vector2(x + 6, 5), col.lightened(0.1), 1.5)
		ci.draw_line(c + Vector2(x + 5, -1), c + Vector2(x - 4, 5), col.darkened(0.1), 1.5)
