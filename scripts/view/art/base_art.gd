class_name BaseArt
extends RefCounted
## Per-age bases and turrets. Local space: the gate is at x = 0 on the ground (y = 0), the base
## extends toward −x, and the enemy is toward +x (the right base is drawn mirrored).

const SLOTS := [Vector2(-38, -118), Vector2(-96, -150), Vector2(-150, -118), Vector2(-66, -196), Vector2(-126, -196)]
const SCALE := 1.35


## Slot position in the base's local space, after BaseArt.SCALE.


static func slot_pos(i: int) -> Vector2:
	return SLOTS[i] * SCALE


static func _poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)


static func draw_base(ci: CanvasItem, age: int, team: Color, hp_frac: float, t: float, build: float, slots: int, host: Node = null) -> void:
	# `build` 0→1 plays the rebuild after evolving: the new structure rises out of the ground.
	var rise := (1.0 - ease(build, 0.4)) * 240.0
	if host != null:
		UnitArt._push(ci, Transform2D(0.0, Vector2(0, rise)))
		ci.draw_texture(static_texture(age, team, host), -TEX_ORIGIN)
		UnitArt._pop(ci)
	UnitArt._push(ci, Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2(0, rise)))
	if host == null:
		dynamic_pass = false
		_age_art(ci, age, team, t)
	dynamic_pass = true
	_age_art(ci, age, team, t)
	dynamic_pass = false
	# Turret platforms.
	for i in slots:
		# Timber turret mount with a lit top edge and two braces.
		var p: Vector2 = SLOTS[i]
		ci.draw_rect(Rect2(p + Vector2(-17, 10), Vector2(34, 6)), Color("5a4028"))
		ci.draw_line(p + Vector2(-17, 10), p + Vector2(17, 10), Color("8a6a44"), 1.5)
		ci.draw_line(p + Vector2(-12, 16), p + Vector2(-6, 24), Color("4a3320"), 2.0)
		ci.draw_line(p + Vector2(12, 16), p + Vector2(6, 24), Color("4a3320"), 2.0)
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


static func static_texture(age: int, team: Color, host: Node) -> Texture2D:
	var key := "%d_%s" % [age, team.to_html()]
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
		_age_art(n, age, team, 0.0)
		n.draw_set_transform(Vector2.ZERO))
	vp.add_child(n)
	host.add_child(vp)
	_cache[key] = vp
	return vp.get_texture()


static func _age_art(ci: CanvasItem, age: int, team: Color, t: float) -> void:
	match age:
		1: _stone(ci, team, t)
		2: _bronze(ci, team, t)
		3: _medieval(ci, team, t)
		4: _gunpowder(ci, team, t)
		5: _industrial(ci, team, t)
		_: _future(ci, team, t)


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


static func _industrial(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		for i in 5:
			var ph := fmod(t * 0.4 + i * 0.2, 1.0)
			ci.draw_circle(Vector2(-180 + ph * 30, -270 - ph * 90), 8 + ph * 22, Color(0.3, 0.28, 0.28, 0.5 * (1.0 - ph)))
		for k in 5:
			_window(ci, Rect2(-196 + k * 40, -94, 26, 12), Color(1.0, 0.75, 0.35))
		_banner(ci, Vector2(-100, -180), team, t)
		return
	# Concrete bunker with panel seams and rivets, banded smokestack, lit window row, sandbags.
	var concrete := Color("74736b")
	_sp(ci, _rect_pts(Rect2(-212, -126, 214, 126)), concrete)
	for k in 8:
		ci.draw_line(Vector2(-212 + k * 27, -126), Vector2(-212 + k * 27, 0), Color(0, 0, 0, 0.18), 1.0)
		for r in 3:
			ci.draw_circle(Vector2(-208 + k * 27, -112 + r * 44), 1.4, Color(0.2, 0.2, 0.2, 0.6))
	_sp(ci, _rect_pts(Rect2(-216, -134, 222, 10)), concrete.darkened(0.25))
	_sp(ci, _rect_pts(Rect2(-194, -262, 28, 136)), Color("5a4a40"))
	for k in 4:
		ci.draw_rect(Rect2(-196, -250 + k * 30, 32, 5), Color("3a302a"))
	ci.draw_rect(Rect2(-190, -262, 20, 3), Color(0.05, 0.05, 0.05))
	for k in 5:
		_window(ci, Rect2(-196 + k * 40, -94, 26, 12), Color(1.0, 0.75, 0.35))
	_sp(ci, _rect_pts(Rect2(-62, -164, 64, 38)), concrete.darkened(0.08))
	ci.draw_rect(Rect2(-122, -112, 60, 18), team)
	for k in 7:
		UnitArt._shade_poly(ci, UnitArt._ellipse_pts(Vector2(-200 + k * 20, -138 - (k % 2) * 6), Vector2(11, 6)), Color("7a6a50"))
	_sp(ci, _rect_pts(Rect2(-42, -58, 38, 58)), Color("2b2b27"))
	ci.draw_line(Vector2(-42, -30), Vector2(-4, -30), Color(0.4, 0.4, 0.38), 2.0)


static func _future(ci: CanvasItem, team: Color, t: float) -> void:
	# Faceted spire: glass and alloy panels, glowing seams, pulsing core, energy gate.
	var hull := Color("2c3246")
	var glow := team.lightened(0.5)
	if dynamic_pass:
		for k in 7:
			var y := -30.0 - k * 40.0
			var half := 110.0 - k * 13.0
			ci.draw_line(Vector2(-100 - half, y), Vector2(-100 + half * 0.8, y + 6), Color(glow, 0.18 + 0.1 * sin(t * 2.0 + k)), 1.5)
		for k in 12:
			var wx := -170.0 + (k % 4) * 34.0
			var wy := -60.0 - (k / 4) * 60.0
			ci.draw_rect(Rect2(wx, wy, 14, 22), Color(0.3, 0.6, 0.9, 0.4 * night))
		var pulse := 0.6 + 0.4 * sin(t * 2.4)
		for i in 4:
			ci.draw_circle(Vector2(-100, -232), 30.0 - i * 6.0, Color(glow, 0.12 * pulse + i * 0.08))
		ci.draw_circle(Vector2(-100, -232), 8, Color(1, 1, 1, 0.9))
		for k in 5:
			ci.draw_line(Vector2(-46, -70 + k * 15), Vector2(-6, -70 + k * 15), Color(glow, 0.3 + 0.2 * sin(t * 5.0 + k)), 1.5)
		return
	_sp(ci, [Vector2(-222, 0), Vector2(-202, -122), Vector2(-142, -304), Vector2(-100, -326), Vector2(-58, -304), Vector2(-8, -122), Vector2(14, 0)], hull)
	_sp(ci, [Vector2(-100, -326), Vector2(-58, -304), Vector2(-8, -122), Vector2(14, 0), Vector2(-40, 0)], hull.lightened(0.1))
	for k in 6:
		ci.draw_line(Vector2(-190 + k * 30, -20), Vector2(-150 + k * 16, -280 + k * 10), Color(glow, 0.22), 1.5)
	for k in 12:
		ci.draw_rect(Rect2(-170.0 + (k % 4) * 34.0, -60.0 - (k / 4) * 60.0, 14, 22), Color(0.3, 0.6, 0.9, 0.18))
	ci.draw_rect(Rect2(-48, -74, 44, 74), Color(glow, 0.22))
	ci.draw_rect(Rect2(-48, -74, 44, 74), Color(glow, 0.8), false, 2.0)


## Turret on a slot. `aim` is the barrel angle (0 = level toward the enemy); `kick` 0..1 recoil.


static func draw_turret(ci: CanvasItem, def: TurretDef, team: Color, aim: float, kick: float, t: float, outclassed: bool) -> void:
	var pal: Array = UnitArt.AGE_CLOTH[clampi(def.age - 1, 0, 5)]
	var metal: Color = pal[2]
	var wood := Color("6b4a2b")
	var dim := 0.35 if outclassed else 0.0
	match def.kind:
		"sentry":
			ci.draw_rect(Rect2(-12, -6, 24, 16), wood.darkened(dim) if def.age <= 3 else metal.darkened(0.3 + dim))
			var dirv := Vector2.RIGHT.rotated(aim)
			var base := Vector2(0, -8)
			var length := 22.0 + def.age * 2.0
			ci.draw_line(base - dirv * kick * 5.0, base + dirv * (length - kick * 5.0), metal.darkened(dim), 5.0 + def.age * 0.5)
			ci.draw_circle(base, 7.0, team.darkened(dim))
			if def.age >= 6:
				ci.draw_line(base + dirv * 6.0, base + dirv * (length - 4.0), Color(team.lightened(0.6), 0.8), 2.0)
		"artillery":
			ci.draw_rect(Rect2(-16, -4, 32, 14), wood.darkened(0.2 + dim) if def.age <= 3 else metal.darkened(0.35 + dim))
			var dirv := Vector2.RIGHT.rotated(minf(aim, 0.0) - 0.55)
			var base := Vector2(-2, -8)
			ci.draw_line(base - dirv * kick * 7.0, base + dirv * (30.0 - kick * 7.0), metal.darkened(0.15 + dim), 10.0)
			ci.draw_circle(base + dirv * (30.0 - kick * 7.0), 5.5, Color(0.1, 0.1, 0.1))
			ci.draw_circle(base, 7.0, team.darkened(dim))
		"support":
			var pulse := 0.5 + 0.5 * sin(t * 3.0)
			match def.age:
				3:
					ci.draw_rect(Rect2(-14, -18, 28, 20), Color("3a3a3a"))
					for i in 3:
						ci.draw_circle(Vector2(-6 + i * 6, -22 - pulse * 6 - i * 3), 3.0, Color(0.2, 0.18, 0.15, 0.6))
				_:
					ci.draw_rect(Rect2(-10, -24, 20, 26), metal.darkened(0.3 + dim))
					ci.draw_circle(Vector2(0, -26), 6.0, Color(team.lightened(0.4), 0.5 + 0.4 * pulse))
