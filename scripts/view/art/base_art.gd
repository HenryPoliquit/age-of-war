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
		FkPaint.push(ci, Transform2D(0.0, Vector2(0, rise)))
		ci.draw_texture(static_texture(age, team, host, race), -TEX_ORIGIN)
		FkPaint.pop(ci)
	FkPaint.push(ci, Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2(0, rise)))
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
	FkPaint.pop(ci)


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
	var key := "%s_%d_%s_%d" % [race, age, team.to_html(), roundi(rad_to_deg(UnitArt.view_yaw))]
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return _cache[key].get_texture()
	var vp := SubViewport.new()
	vp.size = TEX_SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var n := Node2D.new()
	n.draw.connect(func():
		FkPaint.begin(n, Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, TEX_ORIGIN))
		dynamic_pass = false
		_art(n, race, age, team, 0.0)
		n.draw_set_transform(Vector2.ZERO))
	vp.add_child(n)
	host.add_child(vp)
	_cache[key] = vp
	return vp.get_texture()


static func _art(ci: CanvasItem, race: StringName, age: int, team: Color, t: float) -> void:
	Arch.yaw = UnitArt.view_yaw
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
	FkPaint.shade_poly(ci, pts, col, Vector2(0.5, -0.8))


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
	# The tent's door: a dark flap on the front slope of the pyramid.
	var door := PackedVector2Array()
	var apex := Vector3(-102, -176, -4)
	for p in [Vector3(-114, -100, 14), Vector3(-86, -100, 14), Vector3(-100, -100, 14).lerp(apex, 0.44)]:
		door.append(FkRig.project(p, {"yaw": Arch.yaw}))
	if dynamic_pass:
		if night > 0.05:
			ci.draw_colored_polygon(door, Color(1.0, 0.6, 0.25, 0.6 * night))
		# Fire pit, in front of the rock.
		Arch.on_front(ci, 44.0, func() -> void:
			var fl := 0.7 + 0.3 * sin(t * 11.0)
			ci.draw_circle(Vector2(-150, -6), 14, Color(1.0, 0.55, 0.2, 0.18 + 0.2 * night))
			for k in 3:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-158 + k * 6, -2), Vector2(-152 + k * 6, -2), Vector2(-155 + k * 6, -14 * fl - k * 2)]), Color(1.0, 0.6 + k * 0.1, 0.2)))
		_banner(ci, Vector2(Arch.cylinder_x(-102, -4), -222), team, t)
		return
	# A rock outcrop with a hide tent on a timber ledge cut into it, a stake palisade bound with rope in front, a
	# fire pit: the rock a solid mass, the tent a pyramid, the stakes thin pointed slabs.
	var rock := Color("7d6a58")
	var rock_pts := [Vector2(-205, 0), Vector2(-196, -72), Vector2(-160, -118), Vector2(-104, -142), Vector2(-52, -124), Vector2(-20, -84), Vector2(-4, -30), Vector2(10, 0)]
	Arch.prism(ci, rock_pts, -44, 18, rock)
	Arch.on_front(ci, 18.0, func() -> void:
		_sp(ci, [Vector2(-160, -118), Vector2(-104, -142), Vector2(-80, -132), Vector2(-128, -104)], rock.lightened(0.12))
		for k in 6:
			var a := Vector2(-190 + k * 28, -50 - (k % 3) * 22)
			ci.draw_polyline(PackedVector2Array([a, a + Vector2(9, 8), a + Vector2(4, 18)]), Color(0, 0, 0, 0.3), 1.5))
	var wood := Color("6b4a2b")
	Arch.box(ci, -156, -48, -100, -94, 6, 50, wood.lightened(0.05), func(r: Rect2) -> void: _planks(ci, r, wood.lightened(0.05), 9), Callable())
	var hide := Color("8a6440")
	Arch.pyramid(ci, -148, -56, -22, 14, -100, -176, hide, 4)
	ci.draw_colored_polygon(door, Color(0.12, 0.08, 0.05))
	for k in 10:
		var x := -4.0 - k * 13.0
		var h := 40.0 + (k % 3) * 5.0
		Arch.prism(ci, [Vector2(x - 4.5, 0), Vector2(x - 4.5, -h), Vector2(x, -h - 9), Vector2(x + 4.5, -h), Vector2(x + 4.5, 0)], 24, 32, wood.lightened(0.04 * (k % 2)))
	Arch.on_front(ci, 32.0, func() -> void:
		for y in [-20.0, -32.0]:
			ci.draw_line(Vector2(-134, y), Vector2(0, y + 2), Color("b09060"), 2.0))


static func _bronze(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		_banner(ci, Vector2(Arch.cylinder_x(-98, 3), -248), team, t)
		return
	# Temple-fort: two podium steps, a cella set back behind a fluted colonnade, an entablature under a pediment
	# with a team-coloured tympanum and gilt roundels, bronze shields on the cella wall.
	var stone := Color("e1d3b3")
	var cream := Color("f0e8d4")
	Arch.box(ci, -204, 10, -12, 0, -34, 44, stone.darkened(0.14), _face_msn(ci, stone.darkened(0.14), 6, 26), _end_msn(ci, stone.darkened(0.14), 6, 14))
	Arch.box(ci, -200, 6, -34, -12, -30, 36, stone.darkened(0.08), _face_msn(ci, stone.darkened(0.08), 11, 26), _end_msn(ci, stone.darkened(0.08), 11, 14))
	Arch.box(ci, -178, -6, -132, -34, -28, 8, stone, _face_msn(ci, stone, 12, 30), _end_msn(ci, stone, 12, 14))
	Arch.on_front(ci, 8.0, func() -> void:
		# (The colonnade stands 16 nearer the camera than this wall, so a shield that reads as between two columns from
		# the camera sits 16 · tan(yaw) further back along the wall.)
		for k in 4:
			var c := Vector2(-160 + k * 30 - 16.0 * tan(Arch.yaw), -84)
			ci.draw_circle(c, 9, Color("8a5a24"))
			ci.draw_circle(c, 7, Color("c28c3e"))
			ci.draw_circle(c, 2, Color("f0d090")))
	# The doorway, cut through both steps into the cella.
	var door := Arch.arch_pts(-42, -8, 0, -34, 14)
	Arch.recess(ci, door, 44.0, 14.0, stone.darkened(0.4), Color("5b3f24"))
	Arch.bars(ci, door, 44.0, 14.0, 14.0, [-36, -30, -24, -18, -12], [], Color(0, 0, 0, 0.4), 1.2)
	for k in 6:
		var cx := -175.0 + k * 30.0
		Arch.cylinder(ci, cx, 24, 7, -126, -34, cream, 0.0, 12.0, 3)
	for k in 6:
		var cx := -175.0 + k * 30.0
		Arch.box(ci, cx - 10, cx + 10, -132, -126, 14, 34, Color("d8c8a4"), Callable(), Callable(), false)
	Arch.box(ci, -198, 4, -142, -132, -28, 34, Color("cdb88c"), Callable(), Callable())
	Arch.prism(ci, [Vector2(-204, -142), Vector2(8, -142), Vector2(-98, -196)], -28, 34, Color("c9a060"))
	Arch.on_front(ci, 34.0, func() -> void:
		_sp(ci, [Vector2(-172, -148), Vector2(-24, -148), Vector2(-98, -186)], team.darkened(0.1))
		for k in 5:
			ci.draw_circle(Vector2(-140 + k * 21, -158), 4, Color("d9b25e")))


## Masonry (or any flat art) for a body's front and end faces, as the Callables Arch.box takes.
static func _face_msn(ci: CanvasItem, col: Color, course := 11.0, block := 22.0) -> Callable:
	return func(r: Rect2) -> void: _masonry(ci, r, col, course, block)


static func _end_msn(ci: CanvasItem, col: Color, course := 11.0, block := 14.0) -> Callable:
	return func(r: Rect2) -> void: _masonry(ci, r, Arch.end_col(col), course, block)


## A recessed slit (or window) on a face: dark by day, lit warm at night on its inner plane.
static func _slit(ci: CanvasItem, r: Rect2, zf: float, depth: float, jamb: Color) -> void:
	var opening := Arch.rect_pts(r.position.x, r.position.y, r.end.x, r.end.y)
	if dynamic_pass:
		Arch.on_front(ci, zf - depth, func() -> void: _window(ci, r))
	else:
		Arch.recess(ci, opening, zf, depth, jamb, Color(0.06, 0.05, 0.05))


static func _medieval(ci: CanvasItem, team: Color, t: float) -> void:
	# A curtain wall with a projecting gatehouse and a round corner bastion, the keep set back behind it under a
	# slate pyramid roof: bodies in depth (wall front z = 22, keep front z = 6, gatehouse front z = 32), seen
	# through the units' camera.
	var stone := Color("8d8e8a")
	var keep_col := stone.darkened(0.06)
	var slate := Color("4b5058")
	var jamb := stone.darkened(0.35)
	var keep_slits := [Rect2(-104, -200, 5, 16), Rect2(-86, -200, 5, 16), Rect2(-104, -160, 5, 16), Rect2(-86, -160, 5, 16)]
	var wall_slits := [Rect2(-150, -96, 5, 16), Rect2(-128, -96, 5, 16)]
	if dynamic_pass:
		for r in keep_slits:
			_slit(ci, r, 6.0, 4.0, jamb)
		for r in wall_slits:
			_slit(ci, r, 22.0, 4.0, jamb)
		_banner(ci, Vector2(Arch.cylinder_x(-98.0, -19.0), -350), team, t, 32)
		return
	# The keep, set back: its lower part is hidden by the wall in front of it.
	Arch.box(ci, -136, -60, -232, 0, -44, 6, keep_col,
		func(r: Rect2) -> void: _masonry(ci, r, keep_col, 11, 20),
		func(r: Rect2) -> void: _masonry(ci, r, Arch.end_col(keep_col), 11, 14))
	Arch.crenellate(ci, -136, -60, -44, 6, -232, 12, 10, 16, keep_col, 4)
	Arch.pyramid(ci, -144, -52, -52, 14, -244, -304, slate, 5)
	for r in keep_slits:
		_slit(ci, r, 6.0, 4.0, jamb)
	Arch.on_front(ci, 6.0, func() -> void:
		ci.draw_rect(Rect2(-112, -210, 28, 36), team)
		ci.draw_rect(Rect2(-112, -210, 28, 36), Color(0, 0, 0, 0.3), false, 1.5))
	# The curtain wall with its parapet.
	Arch.box(ci, -200, 4, -122, 0, -22, 22, stone,
		func(r: Rect2) -> void: _masonry(ci, r, stone, 11, 24),
		func(r: Rect2) -> void: _masonry(ci, r, Arch.end_col(stone), 11, 14))
	Arch.crenellate(ci, -200, 4, -22, 22, -122, 16, 22, 38, stone, 6)
	for r in wall_slits:
		_slit(ci, r, 22.0, 4.0, jamb)
	# The gatehouse, projecting from the wall, its arch a deep recess with the portcullis inside.
	Arch.box(ci, -72, 8, -150, 0, -22, 32, stone.darkened(0.03),
		func(r: Rect2) -> void: _masonry(ci, r, stone.darkened(0.03), 11, 22),
		func(r: Rect2) -> void: _masonry(ci, r, Arch.end_col(stone.darkened(0.03)), 11, 14))
	Arch.crenellate(ci, -72, 8, -22, 32, -150, 14, 14, 22, stone.darkened(0.03), 5)
	var gate := Arch.arch_pts(-52, -4, 0, -56, 24)
	Arch.recess(ci, gate, 32.0, 30.0, jamb, Color(0.13, 0.09, 0.06))
	Arch.bars(ci, gate, 32.0, 30.0, 14.0, [-46, -36, -26, -16, -10], [-70, -56, -42, -28, -14], Color(0.38, 0.35, 0.31), 2.0)
	# The round corner bastion, standing proud of the wall, under a slate cone.
	Arch.cylinder(ci, -192, 12, 22, -176, 0, stone.darkened(0.03), 11, 14)
	Arch.cone(ci, -192, 12, 27, -176, -220, slate, 4)
	var tx := Arch.cylinder_x(-192, 12)
	ci.draw_rect(Rect2(tx - 1.5, -128, 3, 14), Color(0.06, 0.05, 0.05))
	ci.draw_rect(Rect2(tx - 1.5, -84, 3, 14), Color(0.06, 0.05, 0.05))


static func _gunpowder(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		Arch.on_front(ci, 4.0, func() -> void: _window(ci, Rect2(-101, -210, 10, 14)))
		_banner(ci, Vector2(Arch.cylinder_x(-95, -13), -300), team, t, 30)
		return
	# Star-fort bastion: a sloped earthwork mass with embrasures and cannon, a masonry gun deck above it, a brick
	# watchtower set back under a slate hip roof, a plank gate recessed into the slope.
	var earth := Color("8a7b66")
	var mound := [Vector2(-214, 0), Vector2(-204, -108), Vector2(-152, -142), Vector2(-40, -142), Vector2(12, -100), Vector2(22, 0)]
	var brick := Color("8a5a44")
	Arch.box(ci, -122, -68, -224, -150, -28, 4, brick, _face_msn(ci, brick, 7, 12), _end_msn(ci, brick, 7, 8))
	Arch.pyramid(ci, -128, -62, -34, 10, -224, -252, Color("3a3f58"), 3)
	Arch.on_front(ci, 4.0, func() -> void: _window(ci, Rect2(-101, -210, 10, 14)))
	Arch.box(ci, -152, -40, -162, -142, -30, 12, Color("6a5e52"), _face_msn(ci, Color("6a5e52"), 10, 18), _end_msn(ci, Color("6a5e52"), 10, 12))
	Arch.prism(ci, mound, -44, 30, earth)
	Arch.on_front(ci, 30.0, func() -> void:
		for r in 9:
			var y := -12.0 - r * 14.0
			ci.draw_line(Vector2(-210 + r * 1.2, y), Vector2(16 - r * 3.0, y), Color(0, 0, 0, 0.22), 1.2))
	for k in 3:
		var gp := Vector2(-140 + k * 44, -120)
		Arch.recess(ci, Arch.rect_pts(gp.x, gp.y, gp.x + 22, gp.y + 14), 30.0, 8.0, earth.darkened(0.4), Color(0.08, 0.07, 0.06))
		Arch.on_front(ci, 30.0, func() -> void: ci.draw_line(gp + Vector2(11, 7), gp + Vector2(34, 5), Color(0.18, 0.18, 0.2), 6.0))
	var gate := Arch.rect_pts(-42, -64, -6, 0)
	Arch.recess(ci, gate, 30.0, 22.0, earth.darkened(0.45), Color("3a2a1c"))
	Arch.bars(ci, gate, 30.0, 22.0, 22.0, [-36, -30, -24, -18, -12], [], Color(0, 0, 0, 0.4), 1.2)


static func _castrum(ci: CanvasItem, team: Color, t: float) -> void:
	var tufa := Color("c2b08e")
	var tile := Color("b0583a")
	var top_x := Arch.cylinder_x(-135, -14)
	if dynamic_pass:
		for p in [Vector2(-128, -186)]:
			Arch.on_front(ci, 6.0, func() -> void: _window(ci, Rect2(p, Vector2(6, 12))))
		for p in [Vector2(-66, -140), Vector2(-4, -140)]:
			Arch.on_front(ci, 34.0, func() -> void: _window(ci, Rect2(p, Vector2(6, 12))))
		# Torches at the gate.
		Arch.on_front(ci, 34.0, func() -> void:
			for x in [-52.0, -4.0]:
				var fl := 0.7 + 0.3 * sin(t * 12.0 + x)
				ci.draw_circle(Vector2(x, -70), 10.0, Color(1.0, 0.6, 0.25, 0.15 + 0.25 * night))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -66), Vector2(x + 3, -66), Vector2(x, -66 - 10 * fl)]), Color(1.0, 0.7, 0.3)))
		# Legion standard: a square vexillum under a gilded eagle.
		var top := Vector2(top_x, -318)
		ci.draw_line(top, top + Vector2(0, 84), Color("3b2c20"), 3.0)
		ci.draw_line(top + Vector2(-14, 10), top + Vector2(14, 10), Color("3b2c20"), 2.0)
		var sway := sin(t * 2.2) * 1.5
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-13, 10), top + Vector2(13, 10), top + Vector2(13 + sway, 36), top + Vector2(-13 + sway, 36)]), team)
		for k in 5:
			ci.draw_line(top + Vector2(-12 + k * 6 + sway, 36), top + Vector2(-12 + k * 6 + sway, 40), Color("d9b25c"), 1.5)
		ci.draw_circle(top + Vector2(0, -3), 5.0, Color("d9b25c"))
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-10, -6), top + Vector2(0, -2), top + Vector2(10, -6), top + Vector2(0, 2)]), Color("c9a24c"))
		return
	# Roman castrum: a tufa wall with a timber walkway and palisade, a tiled central tower set back, and a twin-towered
	# gate projecting from the wall with the arch recessed between the towers.
	var timber := Color("7a5a3a")
	Arch.box(ci, -170, -100, -206, -110, -34, 6, tufa.lightened(0.05), _face_msn(ci, tufa.lightened(0.05), 12, 20), _end_msn(ci, tufa.lightened(0.05), 12, 14))
	Arch.pyramid(ci, -180, -90, -44, 16, -206, -240, tile, 6)
	Arch.box(ci, -206, 4, -110, 0, -20, 20, tufa, _face_msn(ci, tufa, 12, 28), _end_msn(ci, tufa, 12, 14))
	Arch.box(ci, -208, 6, -124, -110, -24, 24, timber, func(r: Rect2) -> void: _planks(ci, r, timber, 8), Callable())
	for k in 14:
		Arch.box(ci, -206 + k * 15, -200 + k * 15, -134, -124, 16, 24, Color("6a4a2e"), Callable(), Callable(), false)
	# Twin gate towers, projecting, with tiled caps; the arched gate between them.
	for x in [-80.0, -14.0]:
		Arch.box(ci, x, x + 30, -160, 0, -20, 34, tufa.darkened(0.05), _face_msn(ci, tufa.darkened(0.05), 11, 15), _end_msn(ci, tufa.darkened(0.05), 11, 12))
		Arch.pyramid(ci, x - 5, x + 35, -25, 39, -160, -184, tile, 3)
	var gate := Arch.arch_pts(-50, -30, 0, -62, 18)
	gate = Arch.arch_pts(-50, -14, 0, -62, 18)
	Arch.recess(ci, gate, 20.0, 14.0, tufa.darkened(0.35), Color(0.12, 0.09, 0.07))
	Arch.bars(ci, gate, 20.0, 14.0, 14.0, [-44, -38, -32, -26, -20], [], Color(0.05, 0.03, 0.02, 0.7), 1.4)
	Arch.on_front(ci, 20.0, func() -> void:
		var stroke := PackedVector2Array()
		for p in gate:
			stroke.append(p)
		ci.draw_polyline(stroke, tufa.darkened(0.25), 2.5))
	# Legion shields hung along the wall.
	Arch.on_front(ci, 20.0, func() -> void:
		for k in 4:
			var c := Vector2(-194 + k * 30, -70)
			_sp(ci, [c + Vector2(-8, -14), c + Vector2(8, -14), c + Vector2(9, 14), c + Vector2(-9, 14)], team.darkened(0.1))
			ci.draw_circle(c, 3.0, Color("d9b25c")))
	Arch.on_front(ci, 6.0, func() -> void:
		for p in [Vector2(-128, -186)]:
			_window(ci, Rect2(p, Vector2(6, 12))))
	Arch.on_front(ci, 34.0, func() -> void:
		for p in [Vector2(-66, -140), Vector2(-4, -140)]:
			_window(ci, Rect2(p, Vector2(6, 12))))


## A pointed window on a face: dark (recessed) by day, glowing on its inner plane by night.
static func _pwin(ci: CanvasItem, p: Vector2, zf: float, depth: float, jamb: Color, glow: Color, k: float) -> void:
	var pts: Array = [p + Vector2(0, 18), p, p + Vector2(5, -6), p + Vector2(10, 0), p + Vector2(10, 18)]
	if dynamic_pass:
		Arch.on_front(ci, zf - depth, func() -> void:
			ci.draw_rect(Rect2(p, Vector2(10, 18)), Color(glow, 0.35 + 0.35 * night))
			ci.draw_rect(Rect2(p, Vector2(10, 18)).grow(4), Color(glow, 0.08 + 0.1 * night)))
	else:
		Arch.recess(ci, pts, zf, depth, jamb, Color(0.1, 0.08, 0.12))


static func _citadel(ci: CanvasItem, team: Color, t: float) -> void:
	var glow: Color = RaceLook.look(&"human").glow
	var stone := Color("6e6582")
	var roof := Color("3a2d5e")
	var brass := Color("c9a45c")
	var jamb := stone.darkened(0.4)
	var hall_windows := [Vector2(-190, -92), Vector2(-160, -92), Vector2(-120, -92)]
	var spire_windows := [Vector2(-112, -250), Vector2(-112, -200)]
	if dynamic_pass:
		var k := 0.6 + 0.4 * sin(t * 1.8)
		for p in hall_windows:
			_pwin(ci, p, 22.0, 4.0, jamb, glow, k)
		for p in spire_windows:
			_pwin(ci, p, 10.0, 4.0, jamb, glow, k)
		_pwin(ci, Vector2(-186, -170), 19.0, 4.0, jamb, glow, k)
		# Floating crystal above the spire, and the ward across the gate.
		var c := Vector2(Arch.cylinder_x(-108, -12), -392 + sin(t * 1.4) * 5.0)
		for i in 4:
			ci.draw_circle(c, 34.0 - i * 7.0, Color(glow, 0.06 + i * 0.05 * k))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(9, 0), c + Vector2(0, 20), c + Vector2(-9, 0)]), glow.lightened(0.3))
		ci.draw_line(c + Vector2(0, -18), c + Vector2(0, 18), Color(1, 1, 1, 0.8), 1.5)
		Arch.on_front(ci, 22.0, func() -> void:
			for i in 5:
				var y := -8.0 - i * 13.0
				ci.draw_line(Vector2(-46, y), Vector2(-8, y), Color(glow, 0.25 + 0.2 * sin(t * 4.0 + i)), 1.5))
		_banner(ci, Vector2(Arch.cylinder_x(-182, 0), -254), team, t)
		return
	# Wizard citadel: a violet-grey hall with sloped buttresses and pointed windows, a slender brass-banded spire
	# rising behind it under a violet pyramid, a round side turret, a pointed gate in a brass frame.
	Arch.box(ci, -140, -76, -286, 0, -34, 10, stone.lightened(0.06), _face_msn(ci, stone.lightened(0.06), 12, 16), _end_msn(ci, stone.lightened(0.06), 12, 12))
	for y in [-150.0, -210.0, -270.0]:
		Arch.on_front(ci, 10.0, func() -> void: ci.draw_line(Vector2(-140, y), Vector2(-76, y), brass, 3.0))
		Arch.on_end(ci, -76.0, 10.0, func() -> void: ci.draw_line(Vector2(0, y), Vector2(44, y), Arch.end_col(brass), 3.0))
	Arch.pyramid(ci, -150, -66, -44, 20, -286, -360, roof, 4)
	ci.draw_line(Vector2(Arch.cylinder_x(-108, -12), -360), Vector2(Arch.cylinder_x(-108, -12), -366), brass, 3.0)
	for p in spire_windows:
		_pwin(ci, p, 10.0, 4.0, jamb, glow, 1.0)
	Arch.box(ci, -206, 4, -122, 0, -26, 22, stone, _face_msn(ci, stone, 12, 24), _end_msn(ci, stone, 12, 14))
	for x in [-206.0, -138.0, -70.0]:
		Arch.prism(ci, [Vector2(x, 0), Vector2(x, -110), Vector2(x + 14, -60), Vector2(x + 18, 0)], 22, 32, stone.darkened(0.12))
	for p in hall_windows:
		_pwin(ci, p, 22.0, 4.0, jamb, glow, 1.0)
	# The side turret, standing on the hall's left corner.
	Arch.cylinder(ci, -182, 2, 19, -200, -122, stone.darkened(0.04), 11, 12)
	Arch.cone(ci, -182, 2, 25, -200, -244, roof, 4)
	_pwin(ci, Vector2(-186, -170), 19.0, 4.0, jamb, glow, 1.0)
	# The gate: a pointed arch in a brass frame.
	var gate := Arch.arch_pts(-48, -6, 0, -60, 6, 20)
	Arch.recess(ci, gate, 22.0, 16.0, jamb, Color(0.09, 0.07, 0.11))
	Arch.on_front(ci, 22.0, func() -> void:
		var stroke := PackedVector2Array(gate)
		ci.draw_polyline(stroke, brass, 2.0)
		ci.draw_rect(Rect2(-190, -60, 40, 20), team.darkened(0.1)))


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
		FkPaint.shade_poly(ci, FkPaint.ellipse_pts(p, Vector2(64, 40), 0.0, 14), leaf.darkened(0.25))
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
		FkPaint.shade_poly(ci, FkPaint.ellipse_pts(p, Vector2(40, 26), 0.2, 12), canopy)


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
				FkPaint.shade_poly(ci, FkPaint.ellipse_pts(Vector2(-200 + k * 15, -10 - (k % 2) * 8), Vector2(9, 7), 0.0, 8), stone)
			for k in 4:
				FkPaint.shade_poly(ci, FkPaint.ellipse_pts(Vector2(-110, -126 - k * 12), Vector2(12 - k * 2, 6), 0.0, 8), stone.darkened(0.05 * k))
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
				_sp(ci, FkPaint.ellipse_pts(Vector2(x, -84), Vector2(16, 18), 0.0, 12), stone.lightened(0.05))
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
			_hub(ci, base, team, metal, dim)
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
			_hub(ci, base, team, metal, dim)
		"support":
			var pulse := 0.5 + 0.5 * sin(t * 3.0)
			if race == &"elf":
				if def.age <= 4:
					# Thorn bramble (Thornbrake / Mistwell sit in a knot of briars).
					for n in 5:
						var c := Vector2(-10 + n * 5, -8 - (n % 2) * 6)
						FkPaint.ellipse(ci, c, Vector2(8, 6), Color("3e5a2e").darkened(dim + 0.05 * (n % 2)))
						ci.draw_line(c, c + Vector2(-4 + n * 2, -9), Color("6e5236").darkened(dim), 1.2)
					if def.age == 4:
						for n in 3:
							ci.draw_circle(Vector2(-6 + n * 6, -18 - pulse * 6 - n * 3), 3.0, Color(0.85, 0.92, 0.95, 0.45))
				else:
					# A seed-pod of light cupped in petals.
					for n in 4:
						var a := PI + (n + 0.5) * PI / 4.0
						FkPaint.ellipse(ci, Vector2(cos(a), sin(a)) * 8.0 + Vector2(0, -6), Vector2(8, 3.5), Color("e8eef6").darkened(dim), a)
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
	FkPaint.ellipse(ci, Vector2(0, 2), Vector2(22, 5), Color(0, 0, 0, 0.25))
	ci.draw_rect(Rect2(-18, -5, 36, 6), col)
	ci.draw_line(Vector2(-18, -5), Vector2(18, -5), col.lightened(0.2), 1.2)
	for x in [-14.0, 14.0]:
		ci.draw_line(Vector2(x, -5), Vector2(x, -14), col.darkened(0.2), 2.0)


## A turret's tower, feet at the origin, drawn at TOWER_SCALE by the caller (TowerArt holds the
## designs). `dim` darkens an outclassed tower.
static func draw_tower(ci: CanvasItem, race: StringName, age: int, team: Color, t: float, dim := 0.0) -> void:
	TowerArt.draw(ci, race, age, tower_height(race, age), team, t, dim)


## Swivel mount under a turret's weapon: a short drum with a team-coloured band and a lit top.
static func _hub(ci: CanvasItem, c: Vector2, team: Color, metal: Color, dim: float) -> void:
	var body := metal.darkened(0.4 + dim)
	var drum := [c + Vector2(-7, -1), c + Vector2(7, -1), c + Vector2(7, 5), c + Vector2(-7, 5)]
	FkPaint.shade_poly(ci, drum, body)
	ci.draw_rect(Rect2(c + Vector2(-7, 1), Vector2(14, 2.5)), team.darkened(dim))
	FkPaint.shade_poly(ci, FkPaint.ellipse_pts(c + Vector2(0, -1), Vector2(7, 2.4), 0.0, 12), metal.darkened(0.15 + dim))
	for x in [-4.0, 0.0, 4.0]:
		ci.draw_circle(c + Vector2(x, 4.2), 0.6, metal.lightened(0.3).darkened(dim))
	var ink := PackedVector2Array([c + Vector2(-7, -1), c + Vector2(-7, 5), c + Vector2(7, 5), c + Vector2(7, -1)])
	ci.draw_polyline(ink, TowerArt.INK, 1.0)
	var top := PackedVector2Array()
	for n in 11:
		var ang := PI + PI * n / 10.0
		top.append(c + Vector2(cos(ang) * 7.0, -1.0 + sin(ang) * 2.4))
	ci.draw_polyline(top, TowerArt.INK, 1.0)
