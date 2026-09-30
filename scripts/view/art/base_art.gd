class_name BaseArt
extends RefCounted
## Bases, towers and turrets per race and age: human forts (hide camp → temple → Roman castrum →
## castle → star fort → wizard citadel), elven tree-halls and dwarven mountain holds that grow with
## each age. Turrets stand on their own towers on the ground in front of the base, one per slot, so
## base art never has to leave room for mounts. Local space: the gate is at x = 0 on the ground
## (y = 0), the base extends toward −x, and the enemy is toward +x (the right base is drawn mirrored).

## Tower foot per turret slot, in front of the gate; odd slots stand a step further back in depth.
const PADS := [Vector2(44, -4), Vector2(124, -16), Vector2(204, -4), Vector2(284, -16), Vector2(364, -4)]
const SCALE := 1.35
const TOWER_SCALE := 1.35
## Tower height (before TOWER_SCALE) per race and age. A tower stands well above the tallest mounted troop of its age (the
## heavy horsemen and the bronze age chariot are drawn 90–120 px tall): about 30 px over their heads, so a turret looks down on
## everyone it protects (the infantry are 63–104 px). In px after TOWER_SCALE: humans 132–148, elves 138–153, dwarves 120–134.
const TOWER_H := {
	&"human": [98.0, 101.0, 103.0, 105.0, 107.0, 110.0],
	&"elf": [102.0, 103.0, 107.0, 109.0, 111.0, 113.0],
	&"dwarf": [89.0, 96.0, 96.0, 97.0, 98.0, 99.0],
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
const TEX_SIZE := Vector2i(380, 500)


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
	# A stockade camp: a log palisade with a tall lashed gate, hide tents behind it, a lashed timber watchtower on a
	# rock outcrop at the far end, a fire pit in front. The gate stands at x = 0.
	if dynamic_pass:
		if night > 0.05:
			# Firelight inside the gate.
			Arch.on_front(ci, 4.0, func() -> void:
				ci.draw_rect(Rect2(-28, -88, 30, 88), Color(1.0, 0.6, 0.25, 0.3 * night)))
		# The fire pit, in front of the wall.
		Arch.on_front(ci, 40.0, func() -> void:
			var fl := 0.7 + 0.3 * sin(t * 11.0)
			ci.draw_circle(Vector2(-96, -6), 14, Color(1.0, 0.55, 0.2, 0.18 + 0.2 * night))
			for k in 3:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-104 + k * 6, -2), Vector2(-98 + k * 6, -2), Vector2(-101 + k * 6, -14 * fl - k * 2)]), Color(1.0, 0.6 + k * 0.1, 0.2)))
		_banner(ci, Vector2(Arch.cylinder_x(-186, 0), -258), team, t)
		return
	var wood := Color("6b4a2b")
	var rock := Color("7d6a58")
	var hide := Color("8a6440")
	var rope := Color("b09060")
	var bone := Color("d8cbb0")
	# The rock the watchtower stands against, behind everything.
	Arch.prism(ci, [Vector2(-236, 0), Vector2(-230, -48), Vector2(-206, -78), Vector2(-178, -64), Vector2(-154, -30), Vector2(-144, 0)], -44, -6, rock)
	# Hide tents behind the wall, showing above it.
	Arch.pyramid(ci, -158, -84, -44, -6, -40, -128, hide, 5)
	Arch.pyramid(ci, -92, -38, -38, -8, -40, -104, hide.darkened(0.08), 4)
	# The palisade: a dark backing with a visible thick end, then pointed logs lashed with rails.
	var dark := wood.darkened(0.28)
	Arch.box(ci, -158, -36, -64, 0, -6, 8, dark, Callable(), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(dark), 8))
	for k in 15:
		var x := -153.0 + k * 8.0
		var h := 58.0 + fposmod(k * 7.0, 5.0) * 3.0
		Arch.prism(ci, [Vector2(x - 4, 0), Vector2(x - 4, -h), Vector2(x, -h - 8), Vector2(x + 4, -h), Vector2(x + 4, 0)], 8, 15, wood.lightened(0.05 * (k % 3)), Color(0, 0, 0, 0.3), 0.8)
	Arch.on_front(ci, 15.0, func() -> void:
		for y in [-22.0, -44.0]:
			_sp(ci, _rect_pts(Rect2(-158, y - 3, 122, 6)), wood.lightened(0.16))
			for x in range(-150, -38, 16):
				ci.draw_line(Vector2(x, y - 4), Vector2(x, y + 4), rope, 1.6)
		# Skulls hung on the wall.
		for x in [-120.0, -70.0]:
			ci.draw_circle(Vector2(x, -52), 3.6, bone)
			ci.draw_rect(Rect2(x - 1.6, -52, 3.2, 3.5), bone)
			ci.draw_circle(Vector2(x - 1.3, -52), 0.8, Color(0.1, 0.08, 0.06))
			ci.draw_circle(Vector2(x + 1.3, -52), 0.8, Color(0.1, 0.08, 0.06)))
	# The gate: an opening onto the camp's dark inside, two tall posts, a lintel with a skull and horns.
	Arch.on_front(ci, 4.0, func() -> void:
		_sp(ci, _rect_pts(Rect2(-28, -90, 30, 90)), Color(0.09, 0.06, 0.05)))
	for gx in [[-40.0, -28.0], [2.0, 14.0]]:
		Arch.box(ci, gx[0], gx[1], -104, 0, 5, 19, wood.lightened(0.04), func(r: Rect2) -> void: _planks(ci, r, wood.lightened(0.04), 6), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(wood), 6))
	Arch.box(ci, -46, 20, -100, -88, 4, 20, wood.darkened(0.06), func(r: Rect2) -> void: _planks(ci, r, wood.darkened(0.06), 9), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(wood), 9))
	Arch.on_front(ci, 20.0, func() -> void:
		for gx in [-34.0, 8.0]:
			for y in [-30.0, -62.0, -82.0]:
				ci.draw_line(Vector2(gx - 6.5, y), Vector2(gx + 6.5, y), rope, 2.2)
		# A horned skull over the gate.
		ci.draw_polyline(PackedVector2Array([Vector2(-19, -104), Vector2(-33, -114), Vector2(-30, -128)]), bone, 3.0)
		ci.draw_polyline(PackedVector2Array([Vector2(-7, -104), Vector2(7, -114), Vector2(4, -128)]), bone, 3.0)
		ci.draw_circle(Vector2(-13, -106), 8.0, bone)
		ci.draw_rect(Rect2(-17.5, -106, 9, 8), bone)
		ci.draw_circle(Vector2(-16, -107), 2.0, Color(0.1, 0.08, 0.06))
		ci.draw_circle(Vector2(-10, -107), 2.0, Color(0.1, 0.08, 0.06)))
	# The watchtower: four leaning lashed posts, cross-braces and a ladder, a plank platform with a stake rim, a hide roof.
	var lean := 6.0
	for zr in [[-15.0, -8.0], [8.0, 15.0]]:
		for xs in [[-212.0, -212.0 + lean], [-160.0, -160.0 - lean]]:
			var xb: float = xs[0]
			var xt: float = xs[1]
			Arch.prism(ci, [Vector2(xb - 3.5, 0), Vector2(xt - 3.5, -150), Vector2(xt + 3.5, -150), Vector2(xb + 3.5, 0)], zr[0], zr[1], wood, Color(0, 0, 0, 0.3), 0.8)
	Arch.on_front(ci, 15.0, func() -> void:
		for y in [-46.0, -98.0]:
			_sp(ci, _rect_pts(Rect2(-208, y - 2.5, 48, 5)), wood.lightened(0.1))
		ci.draw_line(Vector2(-208, -10), Vector2(-166, -92), wood.darkened(0.15), 4.0)
		ci.draw_line(Vector2(-166, -10), Vector2(-208, -92), wood.darkened(0.15), 4.0)
		for pr in [Vector2(-208, -46), Vector2(-166, -46), Vector2(-206, -98), Vector2(-168, -98), Vector2(-187, -51)]:
			ci.draw_circle(pr, 2.4, rope)
		# A ladder up the middle.
		for x in [-196.0, -186.0]:
			ci.draw_line(Vector2(x, 0), Vector2(x, -142), wood.darkened(0.3), 2.2)
		for k in 11:
			ci.draw_line(Vector2(-196, -8 - k * 12.0), Vector2(-186, -8 - k * 12.0), rope, 1.6))
	Arch.box(ci, -218, -154, -152, -142, -17, 18, wood.lightened(0.05), func(r: Rect2) -> void: _planks(ci, r, wood.lightened(0.05), 8), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(wood), 8))
	Arch.crenellate(ci, -218, -154, -17, 18, -152, 20, 5, 8.5, wood.darkened(0.06), 3.0)
	for x in [-216.0, -158.0]:
		Arch.box(ci, x - 1.5, x + 1.5, -180, -152, 14, 17, wood.darkened(0.15), Callable(), Callable(), false)
	Arch.pyramid(ci, -226, -146, -24, 26, -180, -214, hide, 5)
	# Boulders at the gate, a ring of stones round the fire pit.
	for k in 3:
		Arch.blob(ci, 22 + k * 9, -7 - (k % 2) * 4, 22 + k * 3, Vector2(9, 7), rock.lightened(0.05 * k), 0.0, 10)
	for k in 6:
		var a := TAU * k / 6.0
		Arch.blob(ci, -96 + cos(a) * 14, -4.0, 38 + sin(a) * 6, Vector2(5, 3.6), rock.lightened(0.06 * (k % 2)), 0.0, 8)


static func _bronze(ci: CanvasItem, team: Color, t: float) -> void:
	if dynamic_pass:
		_banner(ci, Vector2(Arch.cylinder_x(-98, 3), -248), team, t)
		# Fire in the two bronze braziers on the steps.
		for bx in [-62.0, 16.0]:
			_torch_flame(ci, Arch.front_plane(38.0) * Vector2(bx, -30), t, bx)
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
			var c := Vector2(-158.5 + k * 27 - 16.0 * tan(Arch.yaw), -84)
			ci.draw_circle(c, 9, Color("8a5a24"))
			ci.draw_circle(c, 7, Color("c28c3e"))
			ci.draw_circle(c, 2, Color("f0d090")))
	# The doorway, cut through both steps into the cella.
	var door := Arch.arch_pts(-42, -8, 0, -34, 14)
	Arch.recess(ci, door, 44.0, 14.0, stone.darkened(0.4), Color("5b3f24"))
	Arch.bars(ci, door, 44.0, 14.0, 14.0, [-36, -30, -24, -18, -12], [], Color(0, 0, 0, 0.4), 1.2)
	# Five columns, the last one well clear of the doorway (the sixth used to stand in it).
	for k in 5:
		var cx := -172.0 + k * 27.0
		Arch.cylinder(ci, cx, 24, 7, -126, -34, cream, 0.0, 12.0, 3)
	for k in 5:
		var cx := -172.0 + k * 27.0
		Arch.box(ci, cx - 10, cx + 10, -132, -126, 14, 34, Color("d8c8a4"), Callable(), Callable(), false)
	Arch.box(ci, -198, 4, -142, -132, -28, 34, Color("cdb88c"), Callable(), Callable())
	Arch.prism(ci, [Vector2(-204, -142), Vector2(8, -142), Vector2(-98, -196)], -28, 34, Color("c9a060"))
	Arch.on_front(ci, 34.0, func() -> void:
		_sp(ci, [Vector2(-172, -148), Vector2(-24, -148), Vector2(-98, -186)], team.darkened(0.1))
		for k in 5:
			ci.draw_circle(Vector2(-140 + k * 21, -158), 4, Color("d9b25e")))
	var gold := Color("d9b25e")
	Arch.on_front(ci, 34.0, func() -> void:
		# A Greek-key frieze along the entablature, a palmette on the pediment's apex, acroteria at its feet and antefixes
		# marching up both raking cornices.
		for k in 24:
			var x := -196.0 + k * 8.5
			ci.draw_polyline(PackedVector2Array([Vector2(x, -133.5), Vector2(x, -139.0), Vector2(x + 6.0, -139.0), Vector2(x + 6.0, -136.0), Vector2(x + 3.0, -136.0)]), gold.darkened(0.25), 1.1)
		for k in 5:
			var a := -PI * 0.5 + (k - 2) * 0.5
			ci.draw_line(Vector2(-98, -196), Vector2(-98, -196) + Vector2(cos(a), sin(a)) * 11.0, gold, 2.4)
		ci.draw_circle(Vector2(-98, -196), 2.6, gold)
		for ax in [-204.0, 8.0]:
			ci.draw_circle(Vector2(ax, -146.0), 4.0, gold)
			ci.draw_circle(Vector2(ax, -146.0), 1.8, gold.darkened(0.3))
		for k in 8:
			var u := (k + 0.5) / 8.0
			for slope in [[Vector2(-204, -142), Vector2(-98, -196)], [Vector2(8, -142), Vector2(-98, -196)]]:
				var q: Vector2 = slope[0].lerp(slope[1], u)
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-2.5, 2), q + Vector2(2.5, 2), q + Vector2(0, -3.5)]), gold))
	# Scrolled capitals on the columns.
	for k in 5:
		var vx := Arch.cylinder_x(-172.0 + k * 27.0, 24.0)
		for side in [-1.0, 1.0]:
			ci.draw_circle(Vector2(vx + side * 8.5, -128.0), 3.4, Color("c8b88a"))
			ci.draw_circle(Vector2(vx + side * 8.5, -128.0), 1.4, Color("9a8a60"))
	# Bronze warriors on the podium at either end, bronze braziers on the steps, laurel over the doorway.
	Arch.on_front(ci, 34.0, func() -> void:
		_statue_warrior(ci, -192.0, -34.0, 0.5, Color("b8834a"))
		_statue_warrior(ci, 2.0, -34.0, 0.5, Color("b8834a")))
	Arch.on_front(ci, 38.0, func() -> void:
		for bx in [-62.0, 16.0]:
			ci.draw_line(Vector2(bx - 6, -12), Vector2(bx - 3, -24), Color("6a4a26"), 2.2)
			ci.draw_line(Vector2(bx + 6, -12), Vector2(bx + 3, -24), Color("6a4a26"), 2.2)
			ci.draw_line(Vector2(bx, -12), Vector2(bx, -24), Color("6a4a26"), 2.2)
			_sp(ci, [Vector2(bx - 8, -30), Vector2(bx + 8, -30), Vector2(bx + 5, -23), Vector2(bx - 5, -23)], Color("b8834a"))
			ci.draw_line(Vector2(bx - 8, -30), Vector2(bx + 8, -30), Color("e0b070"), 1.6))
	Arch.on_front(ci, 44.0, func() -> void:
		for k in 13:
			var a := PI + PI * (k + 0.5) / 13.0
			var lp := Vector2(-25.0 + cos(a) * 21.0, -34.0 + sin(a) * 19.0)
			FkPaint.ellipse(ci, lp, Vector2(3.6, 1.8), Color("5f7f3a"), a + PI * 0.5)
		ci.draw_circle(Vector2(-25.0, -55.0), 2.4, Color("d9b25e")))


## Alternating long and short corner stones up a vertical edge on the current plane (`dir` −1: the stones lie left of x).
static func _quoins(ci: CanvasItem, x: float, y0: float, y1: float, w: float, col: Color, dir := -1.0) -> void:
	var y := y0
	var k := 0
	while y < y1 - 1.0:
		var ww := w * (1.0 if k % 2 == 0 else 0.62)
		var x0 := x if dir > 0.0 else x - ww
		_sp(ci, _rect_pts(Rect2(x0, y, ww, 8.0)), col.lightened(0.05 * (k % 3)))
		y += 9.0
		k += 1


## A window with shutters and a sill: recessed, dark by day, lit at night on its inner plane.
static func _shuttered(ci: CanvasItem, r: Rect2, zf: float, depth: float, jamb: Color, shutter: Color) -> void:
	_slit(ci, r, zf, depth, jamb)
	if not dynamic_pass:
		Arch.on_front(ci, zf, func() -> void:
			_sp(ci, _rect_pts(Rect2(r.position.x - 5.0, r.position.y, 4.0, r.size.y)), shutter)
			_sp(ci, _rect_pts(Rect2(r.end.x + 1.0, r.position.y, 4.0, r.size.y)), shutter)
			_sp(ci, _rect_pts(Rect2(r.position.x - 2.0, r.end.y, r.size.x + 4.0, 3.0)), jamb.lightened(0.35)))


## A banner hanging on the current plane from a bar at (x, y): swallow-tailed, trimmed, with a roundel.
static func _hang_banner(ci: CanvasItem, x: float, y: float, w: float, length: float, col: Color, trim: Color) -> void:
	ci.draw_line(Vector2(x - w * 0.5 - 2.0, y), Vector2(x + w * 0.5 + 2.0, y), Color("3b2c20"), 2.2)
	_sp(ci, [Vector2(x - w * 0.5, y), Vector2(x + w * 0.5, y), Vector2(x + w * 0.5, y + length), Vector2(x, y + length - w * 0.4), Vector2(x - w * 0.5, y + length)], col)
	ci.draw_line(Vector2(x - w * 0.5 + 1.5, y + 3.0), Vector2(x + w * 0.5 - 1.5, y + 3.0), trim, 1.4)
	ci.draw_circle(Vector2(x, y + length * 0.38), w * 0.2, trim)


## A pole with a waving pennant, drawn live: foot `b` on the screen, pole `h` tall.
static func _pennon(ci: CanvasItem, b: Vector2, h: float, col: Color, t: float) -> void:
	var top := b + Vector2(0, -h)
	ci.draw_line(b, top, Color("3b2c20"), 1.8)
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(top + Vector2(i * 4.0, sin(t * 5.0 - i * 0.8) * 1.2 * i / 4.0))
	pts.append(top + Vector2(20 + sin(t * 5.0 - 3.2) * 2.0, 4))
	for i in range(4, -1, -1):
		pts.append(top + Vector2(i * 4.0, 8 + sin(t * 5.0 - i * 0.8) * 1.2 * i / 4.0))
	ci.draw_colored_polygon(pts, col)


## A stave barrel standing on the ground at (cx, cz).
static func _barrel(ci: CanvasItem, cx: float, cz: float, s: float, col: Color) -> void:
	Arch.cylinder(ci, cx, cz, 7.0 * s, -15.0 * s, 0.0, col)
	var x := Arch.cylinder_x(cx, cz)
	for y in [-11.0 * s, -4.0 * s]:
		ci.draw_line(Vector2(x - 7.0 * s, y), Vector2(x + 7.0 * s, y), Color(0.12, 0.1, 0.1, 0.7), 1.4)


## A torch flame drawn live at `base` (screen); glows more at night.
static func _torch_flame(ci: CanvasItem, base: Vector2, t: float, phase: float, tint := Color(1.0, 0.7, 0.3)) -> void:
	var fl := 0.7 + 0.3 * sin(t * 12.0 + phase)
	ci.draw_circle(base + Vector2(0, -5), 11.0, Color(tint, 0.14 + 0.26 * night))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(3, 0), base + Vector2(0, -11 * fl)]), tint)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-1.5, 0), base + Vector2(1.5, 0), base + Vector2(0, -6 * fl)]), tint.lerp(Color.WHITE, 0.6))


## An iron torch bracket with its cup on the current plane (the flame is drawn live).
static func _sconce(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_line(p + Vector2(-5, 3), p + Vector2(0, 0), Color("3a3a3e"), 2.0)
	_sp(ci, [p + Vector2(-4, 0), p + Vector2(4, 0), p + Vector2(2.5, 6), p + Vector2(-2.5, 6)], Color("4a4a50"))


## A patch of ivy climbing a wall: a wandering vine with leaves, on the current plane.
static func _ivy(ci: CanvasItem, x: float, y_bottom: float, height: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(Vector2(x + sin(k * 1.3) * 5.0, y_bottom - height * k / 8.0))
	ci.draw_polyline(pts, col.darkened(0.25), 1.6)
	for k in 9:
		var q: Vector2 = pts[k]
		FkPaint.ellipse(ci, q + Vector2(3.5, -1), Vector2(4.2, 2.4), col.lightened(0.05 * (k % 3)), 0.4)
		FkPaint.ellipse(ci, q + Vector2(-3.5, 2), Vector2(4.0, 2.2), col.darkened(0.06 * (k % 2)), -0.4)


## A stern bronze warrior on the current plane, feet at (x, y): greaves, a cuirass, a crested helm, a spear and round shield.
static func _statue_warrior(ci: CanvasItem, x: float, y: float, s: float, col: Color) -> void:
	_sp(ci, [Vector2(x - 8 * s, y), Vector2(x + 8 * s, y), Vector2(x + 6 * s, y - 24 * s), Vector2(x - 6 * s, y - 24 * s)], col.darkened(0.08))
	_sp(ci, [Vector2(x - 8 * s, y - 24 * s), Vector2(x + 8 * s, y - 24 * s), Vector2(x + 10 * s, y - 44 * s), Vector2(x - 10 * s, y - 44 * s)], col)
	_sp(ci, FkPaint.ellipse_pts(Vector2(x, y - 51 * s), Vector2(6 * s, 7 * s), 0.0, 10), col.lightened(0.06))
	_sp(ci, [Vector2(x - 6.5 * s, y - 52 * s), Vector2(x, y - 62 * s), Vector2(x + 6.5 * s, y - 52 * s)], col.darkened(0.12))
	ci.draw_line(Vector2(x, y - 62 * s), Vector2(x - 3 * s, y - 68 * s), col.darkened(0.3), 2.0 * s)
	ci.draw_line(Vector2(x + 13 * s, y - 4 * s), Vector2(x + 13 * s, y - 74 * s), col.darkened(0.3), 1.8 * s)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 13 * s, y - 74 * s), Vector2(x + 11 * s, y - 68 * s), Vector2(x + 15 * s, y - 68 * s)]), col.lightened(0.15))
	ci.draw_circle(Vector2(x - 12 * s, y - 34 * s), 8.0 * s, col.darkened(0.14))
	ci.draw_circle(Vector2(x - 12 * s, y - 34 * s), 4.5 * s, col.lightened(0.1))


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
		for r in [Rect2(-38, -118, 5, 16), Rect2(-24, -118, 5, 16)]:
			_slit(ci, r, 32.0, 4.0, jamb)
		# Pennants on the gatehouse corners and the bastion's cone, flames in the gate's sconces.
		for x in [-66.0, 2.0]:
			_pennon(ci, Arch.pt(x, -164.0, 28.0), 22.0, team, t)
		_pennon(ci, Arch.pt(-192.0, -220.0, 12.0), 26.0, team, t)
		for x in [-62.0, 4.0]:
			_torch_flame(ci, Arch.front_plane(32.0) * Vector2(x, -58), t, x)
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
	# Buttresses up the wall, a timber hoarding along its top with shuttered openings, machicolation corbels under the
	# gatehouse parapet.
	var timber := Color("6b4a2b")
	for bx in [-166.0, -106.0]:
		Arch.prism(ci, [Vector2(bx - 8, 0), Vector2(bx - 8, -92), Vector2(bx - 2, -112), Vector2(bx + 8, -112), Vector2(bx + 8, 0)], 22, 30, stone.darkened(0.08))
	Arch.box(ci, -196, -100, -142, -122, 22, 36, timber, func(r: Rect2) -> void: _planks(ci, r, timber, 8), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(timber), 8))
	Arch.box(ci, -199, -97, -148, -142, 20, 40, timber.darkened(0.2), Callable(), Callable())
	Arch.on_front(ci, 36.0, func() -> void:
		for k in 5:
			_sp(ci, _rect_pts(Rect2(-190 + k * 18, -136, 11, 9)), Color(0.06, 0.05, 0.05))
			ci.draw_line(Vector2(-190 + k * 18, -136), Vector2(-179 + k * 18, -127), Color(timber.lightened(0.1), 0.7), 1.2))
	Arch.on_front(ci, 32.0, func() -> void:
		for k in 8:
			var cx := -70.0 + k * 10.0
			_sp(ci, [Vector2(cx, -151), Vector2(cx + 7, -151), Vector2(cx + 5, -139), Vector2(cx + 2, -139)], stone.darkened(0.2)))
	# The round corner bastion, standing proud of the wall, under a slate cone.
	Arch.cylinder(ci, -192, 12, 22, -176, 0, stone.darkened(0.03), 11, 14)
	Arch.cone(ci, -192, 12, 27, -176, -220, slate, 4)
	var tx := Arch.cylinder_x(-192, 12)
	ci.draw_rect(Rect2(tx - 1.5, -128, 3, 14), Color(0.06, 0.05, 0.05))
	ci.draw_rect(Rect2(tx - 1.5, -84, 3, 14), Color(0.06, 0.05, 0.05))
	# Heraldry and ironwork: banners between the buttresses, sconces and a lowered drawbridge at the gate, ivy on the wall,
	# arrow slits over the gate.
	for r in [Rect2(-38, -118, 5, 16), Rect2(-24, -118, 5, 16)]:
		_slit(ci, r, 32.0, 4.0, jamb)
	Arch.on_front(ci, 30.0, func() -> void:
		_hang_banner(ci, -136.0, -120.0, 22.0, 70.0, team, Color("d9b25c"))
		_hang_banner(ci, -86.0, -120.0, 22.0, 70.0, team, Color("d9b25c")))
	Arch.on_front(ci, 32.0, func() -> void:
		for x in [-62.0, 4.0]:
			_sconce(ci, Vector2(x, -58)))
	Arch.box(ci, -52, -4, -5, 0, 32, 68, timber, func(r: Rect2) -> void: _planks(ci, r, timber, 7), Callable())
	Arch.on_front(ci, 50.0, func() -> void:
		for x in [-50.0, -6.0]:
			ci.draw_line(Vector2(x, -60), Vector2(x, -6), Color("4a4c52"), 1.8)
			ci.draw_circle(Vector2(x, -60), 2.6, Color("4a4c52")))
	Arch.on_front(ci, 22.0, func() -> void:
		_ivy(ci, -178.0, 0.0, 96.0, Color("4f7a3a"))
		_ivy(ci, -120.0, 0.0, 60.0, Color("5a8a40"))
		ci.draw_line(Vector2(-200, -60), Vector2(-72, -60), Color(0, 0, 0, 0.16), 2.0))


## An arched window on the plane z = zf, set `depth` into the wall: a limestone surround (`dress`, if opaque), a dark recess by
## day, and at night the inner plane glows warm (drawn live).
static func _arch_win(ci: CanvasItem, x: float, y_bottom: float, w: float, h: float, zf: float, depth: float, jamb: Color, dress := Color(0, 0, 0, 0), point := 0.0) -> void:
	var y_spring := y_bottom - (h - w * 0.5 - point)
	var op := Arch.arch_pts(x, x + w, y_bottom, y_spring, w * 0.5, point, 8)
	if dynamic_pass:
		if night > 0.05:
			Arch.on_front(ci, zf - depth, func() -> void:
				ci.draw_colored_polygon(PackedVector2Array(op), Color(1.0, 0.72, 0.35, 0.9 * night)))
		return
	if dress.a > 0.0:
		var sur := Arch.arch_pts(x - 2.5, x + w + 2.5, y_bottom + 3.0, y_spring, w * 0.5 + 2.5, point, 8)
		Arch.on_front(ci, zf, func() -> void:
			_sp(ci, sur, dress)
			ci.draw_line(Vector2(x - 4.5, y_bottom + 3.5), Vector2(x + w + 4.5, y_bottom + 3.5), dress.lightened(0.2), 2.5))
	Arch.recess(ci, op, zf, depth, jamb, Color(0.06, 0.05, 0.05))


## Slate courses on a roof face (on the current plane): rows of staggered joints clipped to the outline.
static func _slates(ci: CanvasItem, outline: Array, row := 6.0) -> void:
	var poly := PackedVector2Array(outline)
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for v in outline:
		x0 = minf(x0, v.x)
		x1 = maxf(x1, v.x)
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var y := y0 + row
	var r := 0
	while y < y1:
		for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x0 - 2.0, y), Vector2(x1 + 2.0, y)]), poly):
			ci.draw_polyline(piece, Color(0, 0, 0, 0.3), 1.0)
		var x := x0 + (row if r % 2 == 0 else 0.0)
		while x < x1:
			if Geometry2D.is_point_in_polygon(Vector2(x, y + row * 0.5), poly):
				ci.draw_line(Vector2(x, y), Vector2(x, y + row), Color(0, 0, 0, 0.2), 1.0)
			x += row * 1.8
		y += row
		r += 1


## Where the muzzle of _cannon() is, on its plane.
static func _cannon_muzzle(x: float, y: float, s: float, lift: float) -> Vector2:
	return Vector2(x, y - 6.0 * s) + Vector2(cos(lift), -sin(lift)) * 15.0 * s + Vector2(0, -2.0 * s)


## A muzzle-loading gun on a wooden carriage on the current plane, wheel resting on (x, y), the barrel tilted up toward the
## lane by `lift` (rad).
static func _cannon(ci: CanvasItem, x: float, y: float, s: float, lift: float) -> void:
	var wood := Color("5a3e26")
	var iron := Color("34353b")
	var dir := Vector2(cos(lift), -sin(lift))
	var n := Vector2(-dir.y, dir.x)
	var axle := Vector2(x, y - 6.0 * s)
	var lift_y := Vector2(0, -2.0 * s)
	var breech := axle - dir * 11.0 * s + lift_y
	var muzzle := _cannon_muzzle(x, y, s, lift)
	_sp(ci, [Vector2(x - 17.0 * s, y), Vector2(x - 12.0 * s, y - 9.0 * s), Vector2(x + 6.0 * s, y - 11.0 * s), Vector2(x + 6.0 * s, y - 4.0 * s), Vector2(x - 10.0 * s, y - 3.0 * s)], wood)
	ci.draw_circle(axle, 6.4 * s, wood.darkened(0.35))
	ci.draw_circle(axle, 5.0 * s, wood.lightened(0.08))
	for k in 4:
		var a := k * PI / 4.0
		ci.draw_line(axle + Vector2(cos(a), sin(a)) * 5.0 * s, axle - Vector2(cos(a), sin(a)) * 5.0 * s, wood.darkened(0.4), 1.0)
	ci.draw_circle(axle, 1.4 * s, iron)
	_sp(ci, [breech + n * 4.8 * s, muzzle + n * 3.0 * s, muzzle - n * 3.0 * s, breech - n * 4.8 * s], iron)
	ci.draw_line(breech - n * 3.4 * s + dir * 2.0, muzzle - n * 2.0 * s, Color(1, 1, 1, 0.22), 1.0)
	ci.draw_line(muzzle + n * 3.6 * s, muzzle - n * 3.6 * s, iron.lightened(0.18), 2.0 * s)
	ci.draw_circle(breech - dir * 2.0 * s, 2.0 * s, iron.lightened(0.08))


## A gun firing, drawn live: a flash at the muzzle `m` (screen) then a puff of smoke that drifts along `dir` and thins. It
## fires once every ~4 s, offset by `phase`.
static func _gun_fire(ci: CanvasItem, m: Vector2, dir: Vector2, t: float, phase: float) -> void:
	var ph := fposmod(t * 0.23 + phase, 1.0)
	if ph > 0.3:
		return
	var k := ph / 0.3
	if k < 0.25:
		var f := 1.0 - k * 3.0
		ci.draw_circle(m + dir * 5.0, 5.0 + 6.0 * f, Color(1.0, 0.8, 0.35, 0.9 * f))
		ci.draw_circle(m + dir * 3.0, 3.0 + 2.0 * f, Color(1.0, 0.95, 0.7, 0.95 * f))
	for j in 3:
		var kk := clampf(k * 1.25 - j * 0.12, 0.0, 1.0)
		ci.draw_circle(m + dir * (6.0 + kk * 28.0) + Vector2(0, -kk * 12.0 - j * 2.0), 4.0 + kk * 9.0, Color(0.8, 0.78, 0.74, 0.5 * (1.0 - kk)))


static func _gunpowder(ci: CanvasItem, team: Color, t: float) -> void:
	# An artillery fortress of red brick and pale limestone. The arsenal hall stands back under a slate mansard roof with dormers,
	# a clock cupola and a verdigris onion dome; in front a brick rampart with guns in its gaps and casemates below, a drum bastion
	# under a copper cone, and a baroque gatehouse with a pediment and a lowered drawbridge. Bodies in depth: hall front z = -6,
	# rampart front z = 30, gatehouse front z = 34, drum tower centre z = 14.
	var brick := Color("9a5a42")
	var stone := Color("c2b9a4")
	var slate := Color("3b404e")
	var verd := Color("5f9a88")
	var timber := Color("5a3e26")
	var iron := Color("34353b")
	var gold := Color("d9b25c")
	var jamb := stone.darkened(0.42)
	var tx := Arch.cylinder_x(-198.0, 14.0)
	var dome_x := Arch.cylinder_x(-119.0, -26.0)
	var gun_xs := [-141.0, -99.0]
	if dynamic_pass:
		for x in [-158.0, -134.0, -110.0, -86.0]:
			_arch_win(ci, x, -162.0, 14.0, 26.0, -6.0, 5.0, jamb)
			_arch_win(ci, x, -124.0, 14.0, 26.0, -6.0, 5.0, jamb)
		for x in [-150.0, -126.0, -102.0]:
			_arch_win(ci, x + 3.0, -213.0, 8.0, 14.0, 2.0, 3.0, jamb)
		for x in [-62.0, -6.0]:
			_arch_win(ci, x, -100.0, 12.0, 28.0, 34.0, 5.0, jamb)
		# The clock's hands, the lantern glow at the gate, a lit oculus in the tower's roof.
		Arch.on_front(ci, -18.0, func() -> void:
			var c := Vector2(-119.0, -268.0)
			var a := t * 0.4
			ci.draw_line(c, c + Vector2(sin(a), -cos(a)) * 6.0, Color("2a2a2e"), 1.2)
			ci.draw_line(c, c + Vector2(sin(a / 12.0), -cos(a / 12.0)) * 4.0, Color("2a2a2e"), 1.7))
		for x in [-58.0, 2.0]:
			_lantern_glow(ci, 34.0, x, -72.0, t)
		if night > 0.05:
			ci.draw_circle(Vector2(tx, -196.0), 3.6, Color(1.0, 0.72, 0.35, 0.9 * night))
			ci.draw_circle(Vector2(tx, -196.0), 9.0, Color(1.0, 0.72, 0.35, 0.14 * night))
		_banner(ci, Vector2(dome_x, -352), team, t, 30)
		_pennon(ci, Vector2(tx, -228.0), 22.0, team, t)
		for x in [-71.0, 15.0]:
			_pennon(ci, Arch.pt(x, -166.0, 8.0), 20.0, team, t)
		# Guns firing in turn: two from the rampart, two from the casemates.
		var wall_dir := Vector2(cos(0.5), -sin(0.5))
		for i in 2:
			_gun_fire(ci, Arch.front_plane(28.0) * _cannon_muzzle(gun_xs[i], -108.0, 0.9, 0.5), wall_dir, t, i * 0.5)
			_gun_fire(ci, Arch.front_plane(30.0) * Vector2(gun_xs[i] + 6.0, -44.0), Vector2(1, -0.1).normalized(), t, 0.25 + i * 0.5)
		# Smoke from the chimneys.
		for cx in [-158.0, -95.0]:
			for i in 4:
				var ph := fmod(t * 0.3 + i * 0.25 + cx * 0.01, 1.0)
				ci.draw_circle(Arch.pt(cx, -282.0, -25.0) + Vector2(ph * 24.0, -ph * 56.0), 3.5 + ph * 10.0, Color(0.34, 0.32, 0.31, 0.42 * (1.0 - ph)))
		return
	# --- The arsenal hall, set back, its lower part hidden by the rampart ---
	var hall := brick.darkened(0.04)
	Arch.box(ci, -176, -62, -198, -60, -50, -6, hall, _face_msn(ci, hall, 7, 13), _end_msn(ci, hall, 7, 9))
	Arch.on_front(ci, -6.0, func() -> void:
		_quoins(ci, -176.0, -198.0, -108.0, 7.0, stone, 1.0)
		_quoins(ci, -62.0, -198.0, -108.0, 7.0, stone, -1.0)
		ci.draw_line(Vector2(-176, -156), Vector2(-62, -156), stone, 3.0))
	for x in [-158.0, -134.0, -110.0, -86.0]:
		_arch_win(ci, x, -162.0, 14.0, 26.0, -6.0, 5.0, jamb, stone)
		_arch_win(ci, x, -124.0, 14.0, 26.0, -6.0, 5.0, jamb, stone)
	Arch.box(ci, -182, -56, -206, -198, -54, -1, stone.lightened(0.04))
	# Chimneys and the clock cupola, behind the roof's front so their feet sink into it.
	for cx in [-158.0, -95.0]:
		Arch.box(ci, cx - 6.0, cx + 6.0, -282.0, -240.0, -30.0, -20.0, brick.darkened(0.1), _face_msn(ci, brick.darkened(0.1), 6, 10), Callable())
		Arch.box(ci, cx - 8.0, cx + 8.0, -286.0, -282.0, -32.0, -18.0, stone.darkened(0.1), Callable(), Callable(), false)
	var cup := stone.lightened(0.02)
	Arch.box(ci, -131, -107, -286, -254, -34, -18, cup, Callable(), Callable())
	Arch.on_front(ci, -18.0, func() -> void:
		ci.draw_circle(Vector2(-119, -268), 8.0, stone.lightened(0.18))
		ci.draw_circle(Vector2(-119, -268), 6.6, Color("efe6d0"))
		for k in 12:
			var a := k * TAU / 12.0
			ci.draw_line(Vector2(-119, -268) + Vector2(sin(a), -cos(a)) * 5.0, Vector2(-119, -268) + Vector2(sin(a), -cos(a)) * 6.0, Color("2a2a2e"), 1.0)
		var bel := Arch.arch_pts(-123.0, -115.0, -276.0, -280.0, 4.0, 0.0, 6)
		_sp(ci, bel, Color(0.07, 0.06, 0.06))
		ci.draw_line(Vector2(-131, -257), Vector2(-107, -257), stone.lightened(0.15), 2.0))
	# The mansard roof: a shallow crown over a steep skirt, slate courses on each, lead rolls along the hips.
	var upper := [Vector2(-164, -238), Vector2(-146, -256), Vector2(-92, -256), Vector2(-74, -238)]
	var lower := [Vector2(-184, -206), Vector2(-164, -238), Vector2(-74, -238), Vector2(-54, -206)]
	Arch.prism(ci, upper, -44, -10, slate.lightened(0.05))
	Arch.on_front(ci, -10.0, func() -> void:
		_slates(ci, upper, 5.0)
		ci.draw_polyline(PackedVector2Array(upper), Color("6a707c"), 1.8))
	Arch.prism(ci, lower, -50, -4, slate)
	Arch.on_front(ci, -4.0, func() -> void:
		_slates(ci, lower, 6.0)
		ci.draw_polyline(PackedVector2Array(lower), Color("6a707c"), 1.8)
		ci.draw_line(Vector2(-184, -206), Vector2(-54, -206), Color(0, 0, 0, 0.35), 2.0))
	# Dormers in the skirt: little gables with round-headed windows.
	for x in [-150.0, -126.0, -102.0]:
		Arch.prism(ci, [Vector2(x, -212), Vector2(x, -226), Vector2(x + 7, -234), Vector2(x + 14, -226), Vector2(x + 14, -212)], -14, 2, stone)
		Arch.on_front(ci, 2.0, func() -> void:
			ci.draw_polyline(PackedVector2Array([Vector2(x, -226), Vector2(x + 7, -234), Vector2(x + 14, -226)]), stone.lightened(0.2), 1.6))
		_arch_win(ci, x + 3.0, -213.0, 8.0, 14.0, 2.0, 3.0, jamb, stone.lightened(0.05))
	# The onion dome on the cupola, gilt ribs and a gilt finial.
	var dome := [[-322.0, 0.6], [-316.0, 3.0], [-309.0, 8.0], [-301.0, 12.5], [-295.0, 12.0], [-290.0, 8.0], [-287.0, 12.0], [-284.0, 14.5]]
	Arch.lathe(ci, -119, -26, dome, verd, 0, 14)
	for ph in [0.0, PI * 0.5, PI, PI * 1.5]:
		Arch.helix(ci, -119, -26, 12.0, -318.0, -288.0, 0.0, ph, gold, 1.2, func(y: float) -> float: return _profile_r(dome, y))
	ci.draw_line(Vector2(dome_x, -322), Vector2(dome_x, -332), gold, 2.0)
	ci.draw_circle(Vector2(dome_x, -336), 3.0, gold)
	# --- The rampart: brick on a limestone plinth, a cordon, a coping, gaps for guns between broad merlons ---
	Arch.box(ci, -212, -70, -104, 0, -6, 30, brick, _face_msn(ci, brick, 7, 13), _end_msn(ci, brick, 7, 9))
	var plinth := stone.darkened(0.06)
	Arch.box(ci, -214, -68, -22, 0, -8, 34, plinth, _face_msn(ci, plinth, 10, 20), _end_msn(ci, plinth, 10, 14))
	Arch.box(ci, -214, -68, -26, -22, -8, 34, stone.lightened(0.05))
	Arch.box(ci, -214, -68, -108, -104, -8, 33, stone.lightened(0.05))
	Arch.on_front(ci, 30.0, func() -> void:
		# Pilasters between the casemates and at the gatehouse, with capital blocks.
		for x in [-124.0, -82.0]:
			_sp(ci, _rect_pts(Rect2(x, -100, 7, 74)), stone.lightened(0.04))
			_sp(ci, _rect_pts(Rect2(x - 1.5, -104, 10, 4)), stone.lightened(0.14))
			_sp(ci, _rect_pts(Rect2(x - 1.5, -30, 10, 4)), stone.lightened(0.1))
		# Soot above the casemates, a stain running down from the coping.
		for cx in gun_xs:
			ci.draw_rect(Rect2(cx - 9.0, -92.0, 18.0, 26.0), Color(0, 0, 0, 0.09)))
	for cx in gun_xs:
		Arch.on_front(ci, 30.0, func() -> void: _sp(ci, Arch.arch_pts(cx - 15.0, cx + 15.0, -27.0, -54.0, 15.0), stone))
		Arch.recess(ci, Arch.arch_pts(cx - 12.0, cx + 12.0, -30.0, -54.0, 12.0), 30.0, 9.0, jamb, Color(0.07, 0.06, 0.06))
		Arch.on_front(ci, 24.0, func() -> void:
			ci.draw_circle(Vector2(cx, -44.0), 6.8, iron)
			ci.draw_circle(Vector2(cx, -44.0), 5.0, iron.lightened(0.14))
			ci.draw_circle(Vector2(cx, -44.0), 2.8, Color(0.03, 0.03, 0.03)))
	Arch.crenellate(ci, -212, -70, -6, 30, -108, 17, 16, 42, stone.darkened(0.04), 5)
	for gx in gun_xs:
		Arch.on_front(ci, 28.0, func() -> void: _cannon(ci, gx, -108.0, 0.9, 0.5))
	# --- The drum bastion at the left, standing proud of the wall under a copper cone ---
	Arch.cylinder(ci, -198, 14, 31, -24, 0, plinth, 9, 18)
	Arch.cylinder(ci, -198, 14, 28, -150, -24, brick, 7, 12)
	Arch.cylinder(ci, -198, 14, 29.6, -66, -60, stone.lightened(0.04))
	Arch.cylinder(ci, -198, 14, 31.6, -164, -150, stone.lightened(0.04))
	Arch.cone(ci, -198, 14, 36, -164, -228, verd, 6)
	for x in [-13.0, 9.0]:
		ci.draw_rect(Rect2(tx + x, -136, 3.5, 18), Color(0.06, 0.05, 0.05))
	ci.draw_rect(Rect2(tx + 2.0, -100, 14, 12), Color(0.06, 0.05, 0.05))
	ci.draw_circle(Vector2(tx + 9.0, -94.0), 4.6, iron.lightened(0.12))
	ci.draw_circle(Vector2(tx + 9.0, -94.0), 2.4, Color(0.03, 0.03, 0.03))
	ci.draw_circle(Vector2(tx, -196.0), 5.6, stone)
	ci.draw_circle(Vector2(tx, -196.0), 4.0, Color(0.07, 0.06, 0.06))
	ci.draw_line(Vector2(tx, -228), Vector2(tx, -236), gold, 1.6)
	ci.draw_circle(Vector2(tx, -238), 2.4, gold)
	# --- The gatehouse: rusticated limestone, a pediment with a gilt sun, a round-headed gateway with heavy doors ---
	var gs := stone.darkened(0.02)
	Arch.box(ci, -74, 18, -138, 0, -22, 34, gs, _face_msn(ci, gs, 13, 26), _end_msn(ci, gs, 13, 16))
	Arch.on_front(ci, 34.0, func() -> void:
		_quoins(ci, -74.0, -138.0, 0.0, 9.0, stone.lightened(0.1), 1.0)
		_quoins(ci, 18.0, -138.0, 0.0, 9.0, stone.lightened(0.1), -1.0))
	Arch.box(ci, -80, 24, -148, -138, -26, 40, stone.lightened(0.06), Callable(), Callable())
	var ped := [Vector2(-74, -148), Vector2(-28, -180), Vector2(18, -148)]
	Arch.prism(ci, ped, -18, 34, stone.lightened(0.02))
	Arch.on_front(ci, 34.0, func() -> void:
		_sp(ci, [Vector2(-62, -151), Vector2(-28, -173), Vector2(6, -151)], stone.darkened(0.14))
		for k in 7:
			var a := PI + PI * (k + 0.5) / 7.0
			ci.draw_line(Vector2(-28, -155) + Vector2(cos(a), sin(a)) * 5.0, Vector2(-28, -155) + Vector2(cos(a), sin(a)) * 9.0, gold, 1.3)
		ci.draw_circle(Vector2(-28, -155), 4.2, gold)
		ci.draw_polyline(PackedVector2Array(ped), stone.lightened(0.22), 2.0)
		# The team's arms on a cartouche over the gate, between two windows.
		_sp(ci, [Vector2(-40, -128), Vector2(-16, -128), Vector2(-16, -112), Vector2(-28, -98), Vector2(-40, -112)], stone.lightened(0.16))
		_sp(ci, [Vector2(-37, -125), Vector2(-19, -125), Vector2(-19, -113), Vector2(-28, -102), Vector2(-37, -113)], team)
		ci.draw_line(Vector2(-28, -124), Vector2(-28, -106), gold, 2.0)
		ci.draw_line(Vector2(-35, -116), Vector2(-21, -116), gold, 2.0))
	for x in [-62.0, -6.0]:
		_arch_win(ci, x, -100.0, 12.0, 28.0, 34.0, 5.0, jamb, stone.lightened(0.08))
	for x in [-71.0, 15.0]:
		Arch.box(ci, x - 3.0, x + 3.0, -166, -148, -8, 24, stone.lightened(0.08), Callable(), Callable())
		Arch.blob(ci, x, -168.0, 8.0, Vector2(4.0, 4.0), gold, 0.0, 10)
	var gate := Arch.arch_pts(-52, -4, 0, -56, 24)
	Arch.recess(ci, gate, 34.0, 30.0, jamb, Color("2a1c12"))
	Arch.bars(ci, gate, 34.0, 30.0, 14.0, [-46, -38, -30, -22, -14, -8], [-26, -52], Color(0.2, 0.17, 0.14), 2.2)
	Arch.on_front(ci, 34.0, func() -> void:
		ci.draw_polyline(PackedVector2Array(gate), stone.lightened(0.2), 4.0)
		_sp(ci, [Vector2(-33, -92), Vector2(-23, -92), Vector2(-24, -78), Vector2(-32, -78)], stone.lightened(0.16))
		for x in [-58.0, 2.0]:
			_hang_lantern(ci, x, -72.0, iron))
	# The drawbridge lowered on chains.
	Arch.box(ci, -52, -4, -5, 0, 34, 70, timber, func(r: Rect2) -> void: _planks(ci, r, timber, 7), Callable())
	for x in [-50.0, -6.0]:
		ci.draw_line(Arch.pt(x, -62.0, 36.0), Arch.pt(x, -4.0, 70.0), iron, 1.6)
	# --- In front: gabions along the foot, shot in pyramids, powder barrels, a field gun ---
	for k in 4:
		var gx := -196.0 + k * 20.0
		Arch.cylinder(ci, gx, 58.0, 9.0, -17.0, 0.0, Color("8a7a5a"))
		Arch.helix(ci, gx, 58.0, 9.3, -17.0, 0.0, 1.6, 0.0, Color(0.2, 0.16, 0.1, 0.55), 1.3)
		Arch.helix(ci, gx, 58.0, 9.3, -17.0, 0.0, 1.6, PI, Color(0.2, 0.16, 0.1, 0.55), 1.3)
	Arch.on_front(ci, 56.0, func() -> void: _cannon(ci, -86.0, 0.0, 1.4, 0.1))
	_barrel(ci, 8.0, 48.0, 1.0, Color("5a3e26"))
	_barrel(ci, 22.0, 48.0, 1.0, Color("6a4a2e"))
	Arch.on_front(ci, 44.0, func() -> void:
		for base in [[Vector2(-128, -4), 3], [Vector2(-121, -12), 2]]:
			for k in base[1]:
				ci.draw_circle(base[0] + Vector2(k * 7.0 - (base[1] - 1) * 3.5, 0.0), 3.6, Color("2a2a2e"))
		ci.draw_circle(Vector2(-124.5, -19.0), 3.6, Color("2a2a2e")))


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
		# Cavalry pennants on the gate towers' caps.
		for x in [-80.0, -14.0]:
			_pennon(ci, Arch.pt(x + 15.0, -184.0, 7.0), 26.0, team, t)
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
	# Dressed stone: quoins up the gate towers' edges, a cornice under their tiled caps, tiled window frames.
	Arch.on_front(ci, 34.0, func() -> void:
		for x in [-80.0, -14.0]:
			_quoins(ci, x, -158.0, 0.0, 7.0, tufa.lightened(0.06), 1.0)
			_quoins(ci, x + 30.0, -158.0, 0.0, 7.0, tufa.lightened(0.06), -1.0)
			_sp(ci, _rect_pts(Rect2(x - 4.0, -166.0, 38.0, 6.0)), tile.darkened(0.1))
		for p in [Vector2(-66, -140), Vector2(-4, -140)]:
			ci.draw_rect(Rect2(p - Vector2(3, 3), Vector2(12, 18)), Color(tile, 0.9), false, 2.0)
			ci.draw_rect(Rect2(p - Vector2(5, 5), Vector2(16, 6)), Color(tile.darkened(0.1), 0.0), false))
	# A plaque over the gate, a step up to it, shields joined by laurel swags, weapon racks, barrels and a ballista.
	Arch.on_front(ci, 24.0, func() -> void:
		_sp(ci, _rect_pts(Rect2(-46, -100, 28, 9)), Color("5a4a34"))
		for k in 5:
			ci.draw_line(Vector2(-43 + k * 5.5, -95.5), Vector2(-40 + k * 5.5, -95.5), Color("d9b25c"), 1.6))
	Arch.box(ci, -58, -6, -5, 0, 20, 40, tufa.darkened(0.12), _face_msn(ci, tufa.darkened(0.12), 5, 16), Callable())
	Arch.on_front(ci, 20.0, func() -> void:
		for k in 3:
			var a := Vector2(-194 + k * 30, -84)
			var b := Vector2(-194 + (k + 1) * 30, -84)
			var sw := PackedVector2Array()
			for j in 9:
				var u := j / 8.0
				sw.append(a.lerp(b, u) + Vector2(0, sin(u * PI) * 7.0))
			ci.draw_polyline(sw, Color("4f7a3a"), 2.4)
			ci.draw_circle(a.lerp(b, 0.5) + Vector2(0, 7.5), 2.0, Color("b0403a")))
	Arch.on_front(ci, 28.0, func() -> void:
		# A rack of pila and a stack of round shields against the wall.
		for x in [-172.0, -142.0]:
			ci.draw_line(Vector2(x, 0), Vector2(x, -30), timber.darkened(0.1), 2.6)
		ci.draw_line(Vector2(-174, -26), Vector2(-140, -26), timber.darkened(0.1), 2.2)
		for k in 6:
			var sx := -170.0 + k * 5.6
			ci.draw_line(Vector2(sx, -2), Vector2(sx + 2.0, -48), Color("8a8e96"), 1.4)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(sx + 2.0, -52), Vector2(sx, -46), Vector2(sx + 4.0, -46)]), Color("c8ccd2"))
		for k in 3:
			ci.draw_circle(Vector2(-118.0 + k * 3.0, -8.0 - k * 5.0), 8.0, team.darkened(0.15))
			ci.draw_circle(Vector2(-118.0 + k * 3.0, -8.0 - k * 5.0), 2.6, Color("d9b25c"))
		# The ballista on the walkway.
		ci.draw_polyline(PackedVector2Array([Vector2(-158, -134), Vector2(-148, -156), Vector2(-138, -134)]), timber.darkened(0.2), 2.6)
		ci.draw_polyline(PackedVector2Array([Vector2(-166, -152), Vector2(-148, -146), Vector2(-130, -152)]), timber.darkened(0.3), 2.8)
		ci.draw_line(Vector2(-160, -150), Vector2(-134, -157), Color("c8ccd2"), 1.6))
	_barrel(ci, -104.0, 30.0, 1.0, Color("7a5a3a"))
	_barrel(ci, -90.0, 30.0, 1.0, Color("6a4a2e"))
	Arch.box(ci, -122, -108, -12, 0, 22, 34, Color("8a6a40"), Callable(), Callable(), true)


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
		# The rose window glows, runes glide along the hall's foot, two rings with orbs circle the spire's tip, cold fire at the gate.
		Arch.on_front(ci, 10.0, func() -> void:
			ci.draw_circle(Vector2(-108, -216), 14.0, Color(glow, 0.1 + 0.16 * k))
			ci.draw_circle(Vector2(-108, -216), 6.5, Color(glow, 0.25 + 0.4 * k)))
		Arch.on_front(ci, 22.0, func() -> void:
			for i in 12:
				var p := Vector2(-198 + i * 16.0, -16.0)
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(3, -6), p + Vector2(6, 0), p + Vector2(9, -6)]), Color(glow, 0.3 + 0.4 * sin(t * 1.6 + i * 0.7) ** 2), 1.6))
		var spire_c := Vector2(Arch.cylinder_x(-108, -12), -320)
		for ring in 2:
			var tilt := 0.28 if ring == 0 else -0.34
			var rx := 56.0 - ring * 10.0
			var ry := 10.0 + ring * 2.0
			var pts := PackedVector2Array()
			for i in 33:
				var a := TAU * i / 32.0
				pts.append(spire_c + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
			ci.draw_polyline(pts, Color(glow, 0.18 + 0.1 * k), 3.0)
			ci.draw_polyline(pts, Color(glow, 0.55 + 0.25 * k), 1.0)
			var oa := t * (0.9 if ring == 0 else -1.2) + ring * 2.0
			ci.draw_circle(spire_c + Vector2(cos(oa) * rx, sin(oa) * ry).rotated(tilt), 3.6, glow.lightened(0.3))
			ci.draw_circle(spire_c + Vector2(cos(oa) * rx, sin(oa) * ry).rotated(tilt), 8.0, Color(glow, 0.2))
		for x in [-54.0, 0.0]:
			_torch_flame(ci, Arch.front_plane(22.0) * Vector2(x, -52), t, x, glow.lightened(0.15))
		for gem in [Arch.pt(-182, -246, 2), Arch.pt(-12, -246, 4)]:
			ci.draw_circle(gem, 9.0, Color(glow, 0.2 + 0.2 * k))
			ci.draw_circle(gem, 3.0, glow.lightened(0.4))
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
	# A rose window in the spire, pinnacles over the buttresses, a second slim turret, a rune band, hanging banners and cold-fire sconces.
	Arch.on_front(ci, 10.0, func() -> void:
		var rc := Vector2(-108, -216)
		ci.draw_circle(rc, 13.0, brass)
		ci.draw_circle(rc, 11.0, Color(0.1, 0.08, 0.14))
		for k in 6:
			var a := TAU * k / 6.0
			_sp(ci, [rc, rc + Vector2(cos(a - 0.5), sin(a - 0.5)) * 10.0, rc + Vector2(cos(a + 0.5), sin(a + 0.5)) * 10.0], glow.darkened(0.3 + 0.1 * (k % 2)))
		ci.draw_circle(rc, 3.4, brass))
	for x in [-206.0, -138.0, -70.0]:
		Arch.prism(ci, [Vector2(x + 2, -122), Vector2(x + 2, -144), Vector2(x + 8, -162), Vector2(x + 14, -144), Vector2(x + 14, -122)], 22, 32, stone.darkened(0.05))
		Arch.on_front(ci, 32.0, func() -> void: ci.draw_circle(Vector2(x + 8, -164), 3.0, brass))
	Arch.cylinder(ci, -12, 4, 13, -196, -122, stone.darkened(0.04), 11, 12)
	Arch.cone(ci, -12, 4, 18, -196, -246, roof, 4)
	_pwin(ci, Vector2(-17, -176), 17.0, 4.0, jamb, glow, 1.0)
	Arch.on_front(ci, 22.0, func() -> void:
		for i in 12:
			var p := Vector2(-198 + i * 16.0, -16.0)
			ci.draw_polyline(PackedVector2Array([p, p + Vector2(3, -6), p + Vector2(6, 0), p + Vector2(9, -6)]), Color(0, 0, 0, 0.28), 1.6)
		_hang_banner(ci, -175.0, -120.0, 12.0, 44.0, team, brass)
		_hang_banner(ci, -96.0, -120.0, 14.0, 50.0, team, brass)
		for x in [-54.0, 0.0]:
			_sconce(ci, Vector2(x, -52)))


## The trunk's radius at height y (linear between profile rows), for things that wind round it.
static func _profile_r(profile: Array, y: float) -> float:
	for i in range(profile.size() - 1):
		var a: Array = profile[i]
		var b: Array = profile[i + 1]
		if y >= a[0] and y <= b[0]:
			return lerpf(a[1], b[1], (y - a[0]) / (b[0] - a[0]))
	return profile[profile.size() - 1][1] if y > profile[0][0] else profile[0][1]


## A toadstool at (x, z) on the ground.
static func _mushroom(ci: CanvasItem, x: float, z: float, s: float, cap: Color) -> void:
	Arch.cylinder(ci, x, z, 2.4 * s, -9.0 * s, 0.0, Color("efe6d0"))
	Arch.blob(ci, x, -10.0 * s, z, Vector2(7.0 * s, 4.6 * s), cap, 0.0, 10)
	var c := Arch.pt(x, -11.0 * s, z)
	ci.draw_circle(c + Vector2(-2.6 * s, 0.5), 0.9 * s, Color(1, 1, 1, 0.85))
	ci.draw_circle(c + Vector2(2.4 * s, -0.6), 0.8 * s, Color(1, 1, 1, 0.85))


## A hanging lantern on the current plane (hook at (x, y)); the glow is drawn live.
static func _hang_lantern(ci: CanvasItem, x: float, y: float, frame: Color) -> void:
	ci.draw_line(Vector2(x, y), Vector2(x, y + 4.0), frame, 1.0)
	_sp(ci, [Vector2(x - 3.4, y + 4.0), Vector2(x + 3.4, y + 4.0), Vector2(x + 4.2, y + 12.0), Vector2(x - 4.2, y + 12.0)], Color("f0d890"))
	ci.draw_line(Vector2(x - 4.0, y + 4.0), Vector2(x + 4.0, y + 4.0), frame, 1.6)
	ci.draw_line(Vector2(x - 4.4, y + 12.0), Vector2(x + 4.4, y + 12.0), frame, 1.6)


## A glow drawn live for a lantern hung on plane z = zf.
static func _lantern_glow(ci: CanvasItem, zf: float, x: float, y: float, t: float) -> void:
	var c := Arch.front_plane(zf) * Vector2(x, y + 8.0)
	var k := 0.8 + 0.2 * sin(t * 3.0 + x)
	ci.draw_circle(c, 11.0, Color(1.0, 0.85, 0.5, (0.1 + 0.28 * night) * k))
	ci.draw_circle(c, 3.0, Color(1.0, 0.9, 0.6, 0.35 + 0.6 * night))


# ---------------------------------------------------------------------------
# Elves: architecture that improves with each age, standing in the forest (trees flank the buildings, the buildings are
# not trees). Stone: a woodland camp of turf and wattle. Bronze: a timber lodge on a stone footing under a swooping roof.
# Iron: a tiered timber hall. Medieval: a white-stone citadel with pointed arcades and copper-green cones. Gunpowder: silver
# spires linked by sky-bridges. Arcane: a crystal palace.

## A leaf-shaped (pointed at both ends) outline centred on (cx, cy).
static func _leaf_pts(cx: float, cy: float, w: float, h: float, n := 8) -> Array:
	var pts: Array = []
	for i in n + 1:
		var s := float(i) / n
		pts.append(Vector2(cx + w * 0.5 * pow(sin(PI * s), 0.85), cy - h * 0.5 + h * s))
	for i in range(n - 1, 0, -1):
		var s := float(i) / n
		pts.append(Vector2(cx - w * 0.5 * pow(sin(PI * s), 0.85), cy - h * 0.5 + h * s))
	return pts


## A leaf-shaped window on the plane z = zf: a gilt frame, dark by day, warm at night (drawn live).
static func _leaf_win(ci: CanvasItem, cx: float, cy: float, w: float, h: float, zf: float, frame: Color) -> void:
	if dynamic_pass:
		if night > 0.05:
			var g := _leaf_pts(cx, cy, w - 2.0, h - 3.0)
			Arch.on_front(ci, zf, func() -> void:
				ci.draw_colored_polygon(PackedVector2Array(g), Color(1.0, 0.75, 0.4, 0.9 * night)))
		return
	var outer := _leaf_pts(cx, cy, w + 5.0, h + 6.0)
	var inner := _leaf_pts(cx, cy, w, h)
	Arch.on_front(ci, zf, func() -> void:
		ci.draw_colored_polygon(PackedVector2Array(outer), frame)
		ci.draw_colored_polygon(PackedVector2Array(inner), Color(0.07, 0.06, 0.05))
		ci.draw_line(Vector2(cx, cy - h * 0.4), Vector2(cx, cy + h * 0.4), Color(frame, 0.6), 1.0))


## The front outline of a swooping hip roof over x in [x0, x1]: eaves at y_eave curling up at the tips, slopes shallow at
## the eaves and steep toward the ridge (at y_ridge, from x0 + inset to x1 - inset).
static func _elf_roof_pts(x0: float, x1: float, y_eave: float, y_ridge: float, inset: float, curl: float) -> Array:
	var n := 7
	var pts: Array = [Vector2(x0 - 7.0, y_eave - curl)]
	for i in n + 1:
		var u := float(i) / n
		pts.append(Vector2(lerpf(x0, x0 + inset, u), y_eave + (y_ridge - y_eave) * pow(u, 1.8)))
	for i in range(n, -1, -1):
		var u := float(i) / n
		pts.append(Vector2(lerpf(x1, x1 - inset, u), y_eave + (y_ridge - y_eave) * pow(u, 1.8)))
	pts.append(Vector2(x1 + 7.0, y_eave - curl))
	pts.append(Vector2(x1 + 1.0, y_eave + 5.0))
	pts.append(Vector2((x0 + x1) * 0.5, y_eave + 8.0))
	pts.append(Vector2(x0 - 1.0, y_eave + 5.0))
	return pts


## A swooping hip roof: shingle courses, a ridge cap, gilt horns at the ridge ends, a dark eave board.
static func _elf_roof(ci: CanvasItem, x0: float, x1: float, y_eave: float, y_ridge: float, inset: float, curl: float, z0: float, z1: float, col: Color, trim: Color) -> void:
	var pts := _elf_roof_pts(x0, x1, y_eave, y_ridge, inset, curl)
	Arch.prism(ci, pts, z0, z1, col)
	Arch.on_front(ci, z1, func() -> void:
		_slates(ci, pts, 5.0)
		ci.draw_line(Vector2(x0 + inset, y_ridge), Vector2(x1 - inset, y_ridge), trim, 2.6)
		for side in [-1.0, 1.0]:
			var rx := x0 + inset if side < 0.0 else x1 - inset
			ci.draw_polyline(PackedVector2Array([Vector2(rx, y_ridge), Vector2(rx + side * 3.0, y_ridge - 6.0), Vector2(rx + side * 8.0, y_ridge - 10.0), Vector2(rx + side * 12.0, y_ridge - 9.0)]), trim, 2.2)
		var n := pts.size()
		ci.draw_polyline(PackedVector2Array([pts[n - 3], pts[n - 2], pts[n - 1]]), col.darkened(0.45), 2.6)
		ci.draw_polyline(PackedVector2Array(pts.slice(0, 10)), Color(1, 1, 1, 0.16), 1.2))


## Timber framing on a wall face: plaster panels, posts, rails and braces.
static func _elf_frame(ci: CanvasItem, r: Rect2, plaster: Color, timber: Color, step := 30.0) -> void:
	_sp(ci, _rect_pts(r), plaster)
	var mid := r.position.y + r.size.y * 0.5
	ci.draw_line(Vector2(r.position.x, mid), Vector2(r.end.x, mid), timber, 3.0)
	var x := r.position.x
	var k := 0
	while x + step <= r.end.x + 0.5:
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), timber, 3.4)
		var a := Vector2(x + 2.0, mid) if k % 2 == 0 else Vector2(x + step - 2.0, mid)
		var b := Vector2(x + step - 2.0, r.position.y + 2.0) if k % 2 == 0 else Vector2(x + 2.0, r.position.y + 2.0)
		ci.draw_line(a, b, timber.lightened(0.05), 2.2)
		x += step
		k += 1
	ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), timber, 3.4)
	ci.draw_line(Vector2(r.position.x, r.position.y + 1.0), Vector2(r.end.x, r.position.y + 1.0), timber, 4.0)
	ci.draw_line(Vector2(r.position.x, r.end.y - 1.0), Vector2(r.end.x, r.end.y - 1.0), timber, 4.0)


## A slender carved post standing at (x, z) on y_base: a swelling foot, a leaf-flared capital.
static func _elf_post(ci: CanvasItem, x: float, z: float, y_top: float, col: Color, y_base := 0.0, r := 3.6) -> void:
	var prof := [[y_top, r * 1.9], [y_top + 5.0, r * 1.9], [y_top + 9.0, r * 1.1], [y_base - 14.0, r], [y_base - 6.0, r * 1.15], [y_base, r * 1.6]]
	Arch.lathe(ci, x, z, prof, col, 0, 10)
	var top := Arch.pt(x, y_top + 3.0, z)
	for s in [-1.0, 1.0]:
		FkPaint.ellipse(ci, top + Vector2(s * 7.0, -3.0), Vector2(5.5, 2.4), col.lightened(0.14), s * -0.55)


## A broadleaf tree standing at (x, z): a tapering trunk with a root flare and crowns of foliage in depth.
static func _elf_tree(ci: CanvasItem, x: float, z: float, h: float, leaf: Color, trunk: Color, birch := false) -> void:
	var prof := [[-h, 2.2], [-h * 0.6, 3.6], [-26.0, 5.2], [-9.0, 7.0], [0.0, 10.5]]
	Arch.lathe(ci, x, z, prof, trunk, 2, 10)
	var cx := Arch.cylinder_x(x, z)
	if birch:
		for k in 7:
			var y := -14.0 - k * h * 0.085
			ci.draw_line(Vector2(cx - 3.2, y), Vector2(cx + 0.5 + (k % 2) * 2.0, y - 1.6), Color(0.1, 0.09, 0.08, 0.7), 1.5)
	ci.draw_line(Arch.pt(x, -h * 0.5, z), Arch.pt(x - 18.0, -h * 0.8, z), trunk.darkened(0.1), 3.0)
	ci.draw_line(Arch.pt(x, -h * 0.56, z), Arch.pt(x + 20.0, -h * 0.86, z), trunk.darkened(0.1), 3.0)
	var r := h * 0.2
	for b in [[-0.7, 0.8, -8.0, 0.8, -0.14], [0.75, 0.86, 6.0, 0.85, -0.06], [0.0, 0.97, 0.0, 0.95, 0.0], [-0.25, 0.72, 12.0, 0.72, 0.06], [0.55, 0.7, 14.0, 0.6, 0.1]]:
		var tone: float = b[4]
		var col := leaf.lightened(tone) if tone > 0.0 else leaf.darkened(-tone)
		Arch.blob(ci, x + float(b[0]) * r, -h * float(b[1]), z + float(b[2]), Vector2(r * float(b[3]), r * float(b[3]) * 0.74), col, 0.15)


## A woven dome hut: bent-sapling ribs, hoops, a low door, a leaf thatch.
static func _elf_hut(ci: CanvasItem, cx: float, r: float, h: float, z0: float, z1: float, col: Color, leaf: Color) -> void:
	var dome: Array = []
	for i in 13:
		var da := PI * i / 12.0
		dome.append(Vector2(cx - cos(da) * r, -sin(da) * h))
	Arch.prism(ci, dome, z0, z1, col, Color(0, 0, 0, 0.3), 0.8)
	Arch.on_front(ci, z1, func() -> void:
		for k in 5:
			var wa := Vector2(cx - r * 0.85 + k * r * 0.425, 0.0)
			ci.draw_polyline(PackedVector2Array([wa, wa + Vector2(4, -h * 0.55), wa + Vector2(2 + k, -h * 0.9)]), Color(0, 0, 0, 0.22), 1.3)
		for k in 4:
			ci.draw_arc(Vector2(cx, 0), r * 0.35 + k * r * 0.22, PI, TAU, 12, Color(0, 0, 0, 0.16), 1.2)
		_sp(ci, [Vector2(cx - 8, 0), Vector2(cx - 8, -h * 0.4), Vector2(cx, -h * 0.55), Vector2(cx + 8, -h * 0.4), Vector2(cx + 8, 0)], Color(0.08, 0.06, 0.05))
		for k in 6:
			FkPaint.ellipse(ci, Vector2(cx - r * 0.9 + k * r * 0.36, -h * 0.72 - sin(k * 1.0) * 5.0 - (k % 2) * 4.0), Vector2(6.0, 3.0), leaf.darkened(0.05 * (k % 3)), 0.4 * (k % 2 - 0.5)))


## Fireflies drifting in a box, drawn live.
static func _fireflies(ci: CanvasItem, t: float, n: int, x0: float, x1: float, y0: float, y1: float, tint := Color(1.0, 0.95, 0.55)) -> void:
	for i in n:
		var fx := lerpf(x0, x1, 0.5 + 0.5 * sin(t * 0.37 + i * 1.7)) + cos(t * 0.31 + i) * 14.0
		var fy := lerpf(y0, y1, float(i) / maxi(n - 1, 1)) + sin(t * 0.9 + i * 2.3) * 16.0
		var fk := 0.4 + 0.6 * sin(t * 2.2 + i * 1.3) ** 2
		var fp := Arch.pt(fx, fy, sin(t * 0.4 + i) * 34.0)
		ci.draw_circle(fp, 5.0, Color(tint, 0.12 * fk))
		ci.draw_circle(fp, 1.4, Color(tint.lightened(0.3), 0.85 * fk))


## Leaves drifting down through the frame, drawn live.
static func _falling_leaves(ci: CanvasItem, t: float, col: Color, n := 9) -> void:
	for i in n:
		var ph := fposmod(t * 0.12 + i * 0.113, 1.0)
		var p := Arch.pt(-220.0 + fposmod(i * 37.0, 240.0) + sin(t * 0.8 + i * 2.0) * 14.0, -330.0 + ph * 320.0, 40.0)
		FkPaint.ellipse(ci, p, Vector2(3.6, 1.8), col.darkened(0.08 * (i % 3)), t * 1.6 + i)


static func _elf(ci: CanvasItem, age: int, team: Color, t: float) -> void:
	match age:
		1: _elf_camp(ci, team, t)
		2: _elf_lodge(ci, team, t)
		3: _elf_hall(ci, team, t)
		4: _elf_citadel(ci, team, t)
		_: _elf_spires(ci, age, team, t)


## Stone Age: a woodland camp. A turf-roofed longhouse of wattle and daub, a woven dome hut, a stake fence, a hearth, and a
## gate of two carved totem posts under an arch of bent saplings, all among birch and oak.
static func _elf_camp(ci: CanvasItem, team: Color, t: float) -> void:
	var leaf: Color = Scenery.look(&"elf", 1).leaf
	var timber := Color("6b4a2b")
	var daub := Color("c9ad7a")
	var turf := Color("5f8a3a")
	var trunk := Color("6a5040")
	var bone := Color("d8cbb0")
	var bark := Color("5e4632")
	if dynamic_pass:
		for i in 4:
			var ph := fmod(t * 0.3 + i * 0.25, 1.0)
			ci.draw_circle(Arch.pt(-107.0, -124.0, -2.0) + Vector2(ph * 22.0, -ph * 58.0), 3.5 + ph * 10.0, Color(0.72, 0.72, 0.7, 0.4 * (1.0 - ph)))
		var fire := Arch.pt(-92.0, -4.0, 56.0)
		var fl := 0.7 + 0.3 * sin(t * 11.0)
		ci.draw_circle(fire + Vector2(0, -6), 20.0, Color(1.0, 0.55, 0.2, 0.16 + 0.22 * night))
		for k in 3:
			ci.draw_colored_polygon(PackedVector2Array([fire + Vector2(-6 + k * 6, 0), fire + Vector2(k * 6, 0), fire + Vector2(-3 + k * 6, -15 * fl - k * 2)]), Color(1.0, 0.6 + k * 0.1, 0.2))
		for x in [-46.0, 0.0]:
			_torch_flame(ci, Arch.pt(x, -110.0, 22.0), t, x)
		_fireflies(ci, t, 8, -200.0, 20.0, -210.0, -30.0)
		_banner(ci, Vector2(Arch.cylinder_x(-108.0, -12.0), -150.0), team, t)
		return
	_elf_tree(ci, -214.0, -46.0, 230.0, leaf, trunk)
	_elf_tree(ci, 14.0, -72.0, 190.0, leaf.lightened(0.04), Color("d8d4c8"), true)
	# The dome hut at the left, the longhouse beside it.
	_elf_hut(ci, -198.0, 30.0, 40.0, 4.0, 32.0, Color("a88a5a"), leaf)
	Arch.box(ci, -158, -60, -46, 0, -16, 22, daub, func(r: Rect2) -> void: _elf_frame(ci, r, daub, timber, 24), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(timber), 8))
	Arch.on_front(ci, 22.0, func() -> void:
		_sp(ci, [Vector2(-116, 0), Vector2(-116, -22), Vector2(-108, -28), Vector2(-100, -22), Vector2(-100, 0)], Color(0.08, 0.06, 0.05))
		for x in [-146.0, -84.0]:
			ci.draw_circle(Vector2(x, -22), 4.5, Color(0.1, 0.08, 0.06))
			ci.draw_arc(Vector2(x, -22), 4.5, 0, TAU, 10, bone, 1.0))
	# The turf roof: a rounded hummock, grass tufts along its top, a smoke-hole cowl.
	var hump := func(x: float) -> float:
		var u := clampf((x + 166.0) / 116.0, 0.0, 1.0)
		return -46.0 - 54.0 * pow(sin(PI * u), 0.55)
	var roof: Array = []
	for i in 13:
		var x := lerpf(-166.0, -50.0, i / 12.0)
		roof.append(Vector2(x, hump.call(x)))
	Arch.box(ci, -113, -101, -114, -88, -8, 4, timber, Callable(), Callable())
	Arch.prism(ci, [Vector2(-115, -114), Vector2(-107, -122), Vector2(-99, -114)], -10, 6, timber.darkened(0.2))
	Arch.prism(ci, roof, -20, 26, turf)
	Arch.on_front(ci, 26.0, func() -> void:
		for i in 11:
			var x := -160.0 + i * 10.6
			var y: float = hump.call(x)
			ci.draw_line(Vector2(x, y + 20.0), Vector2(x + 6.0, y + 24.0), turf.darkened(0.25), 2.0)
			ci.draw_line(Vector2(x, y + 1.0), Vector2(x - 1.0, y - 5.0), turf.lightened(0.14), 1.4)
			ci.draw_line(Vector2(x + 3.0, y + 1.0), Vector2(x + 5.0, y - 4.0), turf.lightened(0.08), 1.4)
		ci.draw_line(Vector2(-166, -46), Vector2(-50, -46), Color(0, 0, 0, 0.3), 2.0))
	# The gate: two carved totem posts topped with fire bowls, an arch of bent saplings between them, charms hanging.
	for x in [-46.0, 0.0]:
		_elf_post(ci, x, 22.0, -102.0, timber, 0.0, 4.2)
		for y in [-84.0, -64.0, -44.0]:
			Arch.lathe(ci, x, 22.0, [[y, 5.1], [y + 4.0, 5.1]], bone.darkened(0.15), 0, 8)
		Arch.on_front(ci, 22.0, func() -> void: _sp(ci, [Vector2(x - 8, -108), Vector2(x + 8, -108), Vector2(x + 4, -101), Vector2(x - 4, -101)], Color("4a4038")))
	Arch.on_front(ci, 14.0, func() -> void: ci.draw_arc(Vector2(-23, -80), 21.0, PI, TAU, 12, bark.darkened(0.2), 4.0))
	Arch.on_front(ci, 30.0, func() -> void:
		ci.draw_arc(Vector2(-23, -80), 21.0, PI, TAU, 12, bark.lightened(0.1), 4.0)
		for k in 6:
			var a := PI + PI * (k + 0.5) / 6.0
			FkPaint.ellipse(ci, Vector2(-23, -80) + Vector2(cos(a), sin(a)) * 21.0, Vector2(5.0, 2.4), leaf.darkened(0.06 * (k % 3)), a + 1.2)
		for k in 3:
			var cx := -33.0 + k * 10.0
			ci.draw_line(Vector2(cx, -76.0 - sin(k * 1.5) * 4.0), Vector2(cx, -66.0 - k * 4.0), bone, 1.0)
			ci.draw_circle(Vector2(cx, -64.0 - k * 4.0), 2.4, bone))
	# A lashed stake fence along the front, a ring of stones round the hearth, a few toadstools.
	for k in 8:
		var x := -206.0 + k * 10.0
		Arch.prism(ci, [Vector2(x - 3.5, 0), Vector2(x - 3.5, -19), Vector2(x, -26), Vector2(x + 3.5, -19), Vector2(x + 3.5, 0)], 44, 51, timber.lightened(0.05 * (k % 3)), Color(0, 0, 0, 0.3), 0.8)
	Arch.on_front(ci, 51.0, func() -> void:
		ci.draw_line(Vector2(-210, -14), Vector2(-134, -13), Color("9a8a5a"), 2.0)
		ci.draw_line(Vector2(-210, -6), Vector2(-134, -5), Color("9a8a5a"), 2.0))
	for k in 8:
		var a := TAU * k / 8.0
		Arch.blob(ci, -92.0 + cos(a) * 13.0, -3.0, 56.0 + sin(a) * 6.0, Vector2(4.5, 3.2), Color("8a8880").darkened(0.06 * (k % 3)), 0.0, 8)
	for m in [[-62.0, 40.0, 1.0, Color("c86a4a")], [-52.0, 46.0, 0.7, Color("c86a4a")], [-176.0, 60.0, 0.8, Color("e8dcc0")]]:
		_mushroom(ci, m[0], m[1], m[2], m[3])


## Bronze Age: a timber lodge on a stone footing, plastered panels framed in dark posts, a swooping shingle roof with a louvre
## cupola, a porch over a round-headed door, a carved spirit pole, birches close by.
static func _elf_lodge(ci: CanvasItem, team: Color, t: float) -> void:
	var leaf: Color = Scenery.look(&"elf", 2).leaf
	var timber := Color("6b4a2b")
	var plaster := Color("dccca2")
	var stone := Color("8e8a80")
	var roofc := Color("6f8a52")
	var gold := Color("d9b25c")
	var birch := Color("d8d4c8")
	var win_xs := [-182.0, -150.0, -118.0, -86.0, -54.0]
	var door := Arch.arch_pts(-40, -6, -22, -50, 12, 12)
	if dynamic_pass:
		for x in win_xs:
			_leaf_win(ci, x, -62.0, 11.0, 24.0, 22.0, gold)
		if night > 0.05:
			Arch.on_front(ci, 14.0, func() -> void: ci.draw_colored_polygon(PackedVector2Array(door), Color(1.0, 0.72, 0.35, 0.55 * night)))
		for x in [-40.0, -6.0]:
			_lantern_glow(ci, 44.0, x, -78.0, t)
		for i in 3:
			var ph := fmod(t * 0.3 + i * 0.33, 1.0)
			ci.draw_circle(Arch.pt(-108.0, -194.0, -2.0) + Vector2(ph * 20.0, -ph * 44.0), 3.0 + ph * 9.0, Color(0.72, 0.72, 0.7, 0.4 * (1.0 - ph)))
		_fireflies(ci, t, 9, -210.0, 20.0, -230.0, -40.0)
		_banner(ci, Vector2(Arch.cylinder_x(-108.0, -6.0), -260.0), team, t)
		return
	_elf_tree(ci, -220.0, -34.0, 250.0, leaf, birch, true)
	_elf_tree(ci, -66.0, -90.0, 290.0, leaf.lightened(0.05), birch, true)
	# The louvre cupola on the ridge, behind the roof's front so its foot sinks into it.
	Arch.box(ci, -122, -94, -196, -150, -8, 4, plaster, func(r: Rect2) -> void: _elf_frame(ci, r, plaster, timber, 14), Callable())
	_elf_roof(ci, -132, -84, -192, -220, 10, 7, -12, 8, roofc.darkened(0.08), gold)
	ci.draw_line(Arch.pt(-108.0, -226.0, -2.0), Arch.pt(-108.0, -242.0, -2.0), gold, 1.8)
	# The stone footing and the lodge on it.
	Arch.box(ci, -206, -12, -22, 0, -30, 30, stone, _face_msn(ci, stone, 9, 18), _end_msn(ci, stone, 9, 12))
	Arch.box(ci, -198, -14, -100, -22, -28, 22, plaster, func(r: Rect2) -> void: _elf_frame(ci, r, plaster, timber, 32), func(r: Rect2) -> void: _elf_frame(ci, r, Arch.end_col(plaster), Arch.end_col(timber), 24))
	for x in win_xs:
		_leaf_win(ci, x, -62.0, 11.0, 24.0, 22.0, gold)
	Arch.recess(ci, door, 22.0, 8.0, timber.darkened(0.3), Color(0.1, 0.08, 0.06))
	Arch.on_front(ci, 22.0, func() -> void: ci.draw_polyline(PackedVector2Array(door), gold, 2.0))
	_elf_roof(ci, -214, 2, -96, -160, 46, 12, -34, 30, roofc, gold)
	# The porch: steps, two carved posts, a lintel, a small swooping roof, lanterns.
	Arch.box(ci, -50, 4, -11, 0, 30, 50, stone.lightened(0.05), _face_msn(ci, stone.lightened(0.05), 9, 16), Callable())
	Arch.box(ci, -46, -2, -22, -11, 30, 40, stone.lightened(0.08), _face_msn(ci, stone.lightened(0.08), 9, 16), Callable())
	for x in [-46.0, 0.0]:
		_elf_post(ci, x, 44.0, -84.0, timber, -11.0, 3.8)
	Arch.box(ci, -52, 6, -84, -78, 38, 48, timber, func(r: Rect2) -> void: _planks(ci, r, timber, 9), Callable())
	_elf_roof(ci, -62, 16, -86, -116, 12, 8, -4, 50, roofc.lightened(0.04), gold)
	Arch.on_front(ci, 44.0, func() -> void:
		for x in [-40.0, -6.0]:
			_hang_lantern(ci, x, -78.0, timber.darkened(0.2)))
	# A carved spirit pole at the left, a team banner hanging from its arm.
	_elf_post(ci, -216.0, 44.0, -150.0, timber.lightened(0.05), 0.0, 3.4)
	for y in [-120.0, -96.0, -72.0]:
		Arch.lathe(ci, -216.0, 44.0, [[y, 4.4], [y + 4.0, 4.4]], gold.darkened(0.1), 0, 8)
	Arch.on_front(ci, 44.0, func() -> void:
		ci.draw_line(Vector2(-216, -140), Vector2(-194, -140), timber, 2.5)
		_hang_banner(ci, -203.0, -139.0, 14.0, 44.0, team, gold))
	for m in [[-30.0, 62.0, 0.9, Color("c86a4a")], [-190.0, 66.0, 0.8, Color("e8dcc0")]]:
		_mushroom(ci, m[0], m[1], m[2], m[3])


## Iron Age: a tiered timber hall. A stone plinth and steps, a plank hall with carved posts and leaf windows under a wide
## swooping roof, a second storey under a narrower roof, a small pavilion crowning it with a gilt spire; lanterns and banners
## hang under the eaves.
static func _elf_hall(ci: CanvasItem, team: Color, t: float) -> void:
	var leaf: Color = Scenery.look(&"elf", 3).leaf
	var timber := Color("7a5636")
	var plank := Color("a88358")
	var stone := Color("bab6aa")
	var roofc := Color("4a8a5a")
	var gold := Color("d9b25c")
	var trunk := Color("5a4030")
	var low_win := [-187.0, -153.0, -119.0, -85.0, -51.0]
	var up_win := [-170.0, -142.0, -114.0, -86.0, -58.0]
	var door := Arch.arch_pts(-40, -6, -30, -66, 10, 18)
	if dynamic_pass:
		for x in low_win:
			_leaf_win(ci, x, -70.0, 12.0, 28.0, 22.0, gold)
		for x in up_win:
			_leaf_win(ci, x, -172.0, 11.0, 26.0, 14.0, gold)
		_leaf_win(ci, -115.0, -262.0, 10.0, 24.0, 6.0, gold)
		if night > 0.05:
			Arch.on_front(ci, 12.0, func() -> void: ci.draw_colored_polygon(PackedVector2Array(door), Color(1.0, 0.72, 0.35, 0.55 * night)))
		for x in low_win:
			_lantern_glow(ci, 32.0, x, -98.0, t)
		_fireflies(ci, t, 10, -215.0, 20.0, -280.0, -40.0)
		_banner(ci, Vector2(Arch.cylinder_x(-115.0, -4.0), -354.0), team, t, 26)
		return
	_elf_tree(ci, -224.0, -44.0, 270.0, leaf, trunk)
	_elf_tree(ci, 14.0, -80.0, 220.0, leaf.lightened(0.05), trunk)
	# The pavilion on top, then the upper storey, each under its own roof.
	Arch.box(ci, -134, -96, -282, -240, -14, 6, plank, func(r: Rect2) -> void: _planks(ci, r, plank, 8), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(plank), 8))
	_leaf_win(ci, -115.0, -262.0, 10.0, 24.0, 6.0, gold)
	_elf_roof(ci, -148, -82, -278, -316, 12, 9, -18, 10, roofc.darkened(0.1), gold)
	ci.draw_line(Arch.pt(-115.0, -316.0, -4.0), Arch.pt(-115.0, -336.0, -4.0), gold, 1.8)
	ci.draw_circle(Arch.pt(-115.0, -338.0, -4.0), 2.6, gold)
	Arch.box(ci, -186, -44, -196, -150, -22, 14, plank, func(r: Rect2) -> void: _planks(ci, r, plank, 9), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(plank), 9))
	Arch.on_front(ci, 14.0, func() -> void:
		for x in [-186.0, -158.0, -130.0, -102.0, -74.0, -44.0]:
			ci.draw_line(Vector2(x, -196), Vector2(x, -150), timber, 3.2)
		ci.draw_line(Vector2(-186, -194), Vector2(-44, -194), timber, 3.6))
	for x in up_win:
		_leaf_win(ci, x, -172.0, 11.0, 26.0, 14.0, gold)
	_elf_roof(ci, -204, -26, -192, -240, 38, 12, -26, 18, roofc.darkened(0.05), gold)
	# The plinth and the ground-floor hall.
	Arch.box(ci, -212, 8, -30, 0, -34, 32, stone, _face_msn(ci, stone, 10, 22), _end_msn(ci, stone, 10, 14))
	Arch.box(ci, -204, 2, -106, -30, -28, 22, plank,
		func(r: Rect2) -> void:
			_planks(ci, r, plank, 9)
			for x in [-204.0, -170.0, -136.0, -102.0, -68.0, -34.0, 0.0]:
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), timber, 3.4),
		func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(plank), 9))
	for x in low_win:
		_leaf_win(ci, x, -70.0, 12.0, 28.0, 22.0, gold)
	Arch.recess(ci, door, 22.0, 10.0, timber.darkened(0.3), Color(0.1, 0.08, 0.06))
	Arch.on_front(ci, 22.0, func() -> void: ci.draw_polyline(PackedVector2Array(door), gold, 2.4))
	_elf_roof(ci, -224, 10, -102, -152, 52, 14, -32, 32, roofc, gold)
	# Steps, the carved posts that carry the eave over the door, lanterns and banners under the eave.
	Arch.box(ci, -52, 4, -15, 0, 32, 52, stone.lightened(0.05), _face_msn(ci, stone.lightened(0.05), 10, 18), Callable())
	Arch.box(ci, -48, 0, -30, -15, 32, 42, stone.lightened(0.08), _face_msn(ci, stone.lightened(0.08), 10, 18), Callable())
	for x in [-46.0, 2.0]:
		_elf_post(ci, x, 30.0, -100.0, timber, -30.0, 4.2)
	Arch.on_front(ci, 32.0, func() -> void:
		for x in low_win:
			_hang_lantern(ci, x, -98.0, Color("5a4a34"))
		for x in [-170.0, -102.0]:
			_hang_banner(ci, x, -98.0, 12.0, 42.0, team, gold))
	for m in [[-30.0, 62.0, 0.9, Color("c86a4a")], [-196.0, 58.0, 0.8, Color("e8dcc0")]]:
		_mushroom(ci, m[0], m[1], m[2], m[3])


## Medieval: a white-stone citadel. A pointed arcade under an upper storey of lancets and a leaf frieze, a swooping copper-green
## roof, a great pointed gate with gilt tracery, a round tower at the left, two more behind, all under cones; autumn trees.
static func _elf_citadel(ci: CanvasItem, team: Color, t: float) -> void:
	var leaf: Color = Scenery.look(&"elf", 4).leaf
	var white := Color("e8e4da")
	var verd := Color("5aa08a")
	var gold := Color("d9b25c")
	var trunk := Color("6a4a30")
	var jamb := white.darkened(0.42)
	var arcade := [-194.0, -156.0, -118.0, -80.0]
	var lancets := [-181.0, -143.0, -105.0, -67.0]
	var gate := Arch.arch_pts(-42, -4, -26, -84, 14, 24)
	var tx := Arch.cylinder_x(-198.0, 6.0)
	var mx := Arch.cylinder_x(-108.0, -34.0)
	var rx := Arch.cylinder_x(-2.0, -14.0)
	if dynamic_pass:
		for x in arcade:
			_arch_win(ci, x, -26.0, 30.0, 74.0, 14.0, 10.0, jamb, Color(0, 0, 0, 0), 14.0)
		for cx in lancets:
			_arch_win(ci, cx - 6.0, -112.0, 12.0, 40.0, 14.0, 6.0, jamb, Color(0, 0, 0, 0), 8.0)
		_window(ci, Rect2(tx - 3.0, -224.0, 6, 18))
		_window(ci, Rect2(tx - 3.0, -176.0, 6, 18))
		if night > 0.05:
			Arch.on_front(ci, 2.0, func() -> void: ci.draw_colored_polygon(PackedVector2Array(gate), Color(1.0, 0.72, 0.35, 0.5 * night)))
			ci.draw_circle(Arch.pt(-23.0, -142.0, 14.0), 8.0, Color(1.0, 0.72, 0.35, 0.9 * night))
		for x in [-46.0, 0.0]:
			_lantern_glow(ci, 16.0, x, -92.0, t)
		_pennon(ci, Vector2(tx, -334.0), 22.0, team, t)
		_pennon(ci, Vector2(rx, -264.0), 20.0, team, t)
		_banner(ci, Vector2(mx, -350.0), team, t, 26)
		_falling_leaves(ci, t, leaf.lightened(0.1))
		_fireflies(ci, t, 6, -215.0, 20.0, -260.0, -40.0)
		return
	_elf_tree(ci, -226.0, -50.0, 250.0, leaf, trunk)
	_elf_tree(ci, 22.0, -84.0, 210.0, leaf.lightened(0.05), trunk)
	# The towers: the tall one behind the hall, the small one behind the gate, the round one at the hall's left end.
	Arch.cylinder(ci, -108, -34, 17, -252, -70, white.darkened(0.03), 12, 13)
	for y in [-236.0, -190.0, -146.0]:
		Arch.cylinder(ci, -108, -34, 18.4, y - 2.0, y + 2.0, gold.darkened(0.15))
	Arch.cone(ci, -108, -34, 23, -252, -326, verd, 6)
	ci.draw_line(Vector2(mx, -326), Vector2(mx, -340), gold, 1.8)
	ci.draw_circle(Vector2(mx, -342), 2.6, gold)
	Arch.cylinder(ci, -2, -14, 13, -214, -60, white.darkened(0.04), 12, 12)
	Arch.cone(ci, -2, -14, 18, -214, -264, verd, 4)
	Arch.cylinder(ci, -198, 6, 19, -264, -26, white, 12, 13)
	for y in [-246.0, -206.0, -150.0]:
		Arch.cylinder(ci, -198, 6, 20.4, y - 2.0, y + 2.0, gold.darkened(0.15))
	Arch.lathe(ci, -198, 6, [[-196.0, 25.0], [-192.0, 25.0], [-186.0, 20.0]], white.lightened(0.02))
	Arch.cone(ci, -198, 6, 26, -264, -334, verd, 6)
	ci.draw_line(Vector2(tx, -334), Vector2(tx, -342), gold, 1.8)
	_window(ci, Rect2(tx - 3.0, -224.0, 6, 18))
	_window(ci, Rect2(tx - 3.0, -176.0, 6, 18))
	# The platform, the hall, its steps.
	Arch.box(ci, -218, 8, -26, 0, -34, 16, white.darkened(0.07), _face_msn(ci, white.darkened(0.07), 10, 22), _end_msn(ci, white.darkened(0.07), 10, 14))
	Arch.box(ci, -204, 4, -172, -26, -30, 14, white, _face_msn(ci, white, 12, 24), _end_msn(ci, white, 12, 14))
	Arch.on_front(ci, 14.0, func() -> void:
		ci.draw_line(Vector2(-204, -100), Vector2(4, -100), white.darkened(0.2), 3.0)
		ci.draw_line(Vector2(-204, -98), Vector2(4, -98), Color(1, 1, 1, 0.2), 1.0)
		for k in 30:
			FkPaint.ellipse(ci, Vector2(-200.0 + k * 6.9, -155.0), Vector2(3.4, 1.7), gold.darkened(0.1), 0.0)
		ci.draw_line(Vector2(-204, -158), Vector2(4, -158), gold.darkened(0.2), 1.2)
		ci.draw_line(Vector2(-204, -152), Vector2(4, -152), gold.darkened(0.2), 1.2))
	for x in arcade:
		_arch_win(ci, x, -26.0, 30.0, 74.0, 14.0, 10.0, jamb, white.lightened(0.05), 14.0)
	for cx in lancets:
		_arch_win(ci, cx - 6.0, -112.0, 12.0, 40.0, 14.0, 6.0, jamb, white.lightened(0.05), 8.0)
	Arch.recess(ci, gate, 14.0, 12.0, jamb, Color(0.09, 0.07, 0.06))
	Arch.bars(ci, gate, 14.0, 12.0, 8.0, [-32, -23, -14], [-70, -50], gold.darkened(0.2), 1.6)
	Arch.on_front(ci, 14.0, func() -> void:
		ci.draw_polyline(PackedVector2Array(gate), gold, 3.0)
		ci.draw_circle(Vector2(-23, -142), 10.0, gold)
		ci.draw_circle(Vector2(-23, -142), 8.2, Color(0.1, 0.08, 0.06))
		for k in 8:
			var a := TAU * k / 8.0
			ci.draw_line(Vector2(-23, -142), Vector2(-23, -142) + Vector2(cos(a), sin(a)) * 8.0, gold.darkened(0.1), 1.0)
		for x in [-162.0, -124.0, -86.0]:
			_hang_banner(ci, x, -150.0, 10.0, 40.0, team, gold))
	_elf_roof(ci, -212, 10, -168, -238, 60, 14, -34, 18, verd, gold)
	Arch.box(ci, -56, 10, -13, 0, 16, 36, white.darkened(0.04), _face_msn(ci, white.darkened(0.04), 10, 20), Callable())
	Arch.box(ci, -50, 4, -26, -13, 16, 26, white.darkened(0.02), _face_msn(ci, white.darkened(0.02), 10, 20), Callable())
	Arch.on_front(ci, 16.0, func() -> void:
		for x in [-46.0, 0.0]:
			_hang_lantern(ci, x, -92.0, Color("5a4a34")))


## Gunpowder and Arcane: slender silver spires (Gunpowder) or crystal towers (Arcane) rising behind an ivory hall under a
## swooping roof, joined by sky-bridges, in a misty wood (Gunpowder) or a starlit grove (Arcane). The hall has a pointed arcade with a great gate.
static func _elf_spires(ci: CanvasItem, age: int, team: Color, t: float) -> void:
	var crystal := age == 6
	var leaf: Color = Scenery.look(&"elf", age).leaf
	var glow: Color = RaceLook.look(&"elf").glow
	var ivory := Color("ece8dc")
	var spire_col := Color("cfd6dc") if not crystal else Color(glow, 0.95).lerp(Color("8fd0e8"), 0.35)
	var gold := Color("d9b25c")
	var trunk := Color("2a3a36")
	var jamb := ivory.darkened(0.45)
	var arcade := [-200.0, -164.0, -128.0, -92.0]
	var gate := Arch.arch_pts(-42, -4, -30, -84, 14, 24)
	# [x, z, top, r]: the tall one in the middle, behind the dome.
	var top_c := -330.0 if crystal else -350.0
	var spires := [[-206.0, -8.0, -292.0, 15.0, [0.42, 0.62]], [-150.0, -30.0, -252.0, 13.0, [0.3]], [-104.0, -34.0, top_c, 17.0, [0.3]], [-58.0, -30.0, -300.0, 13.0, [0.3]], [-2.0, -8.0, -264.0, 14.0, [0.42, 0.62]]]
	var roof_col := Color("9cc8c4") if not crystal else Color(glow, 0.9).lerp(Color("8fd0e8"), 0.3)
	if dynamic_pass:
		for x in arcade:
			_arch_win(ci, x, -30.0, 26.0, 74.0, 16.0, 10.0, jamb, Color(0, 0, 0, 0), 16.0)
		for sp in spires:
			var sx := Arch.cylinder_x(sp[0], sp[1])
			for f: float in sp[4]:
				_window(ci, Rect2(sx - 2.0, float(sp[2]) + f * (-96.0 - float(sp[2])), 4, 9))
			if crystal:
				var c := Vector2(sx, float(sp[2]) + 14.0)
				var k := 0.7 + 0.3 * sin(t * 1.7 + sp[0] * 0.05)
				ci.draw_circle(c, 22.0, Color(glow, 0.10 * k))
				ci.draw_circle(c, 10.0, Color(glow, 0.16 * k))
		if night > 0.05:
			Arch.on_front(ci, 4.0, func() -> void: ci.draw_colored_polygon(PackedVector2Array(gate), Color(1.0, 0.72, 0.35, 0.5 * night)))
		for x in [-46.0, 0.0]:
			_lantern_glow(ci, 20.0, x, -92.0, t)
		_pennon(ci, Vector2(Arch.cylinder_x(-206.0, -8.0), -294.0), 20.0, team, t)
		_pennon(ci, Vector2(Arch.cylinder_x(-58.0, -30.0), -302.0), 20.0, team, t)
		if crystal:
			# The crown crystal floating over the central spire, shards circling the dome, glowing runes along the platform.
			var c := Vector2(Arch.cylinder_x(-104.0, -26.0), top_c - 22.0 + sin(t * 1.2) * 4.0)
			for i in 4:
				ci.draw_circle(c, 24.0 - i * 5.0, Color(glow, 0.05 + i * 0.05))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(7, 0), c + Vector2(0, 16), c + Vector2(-7, 0)]), glow.lightened(0.3))
			for i in 5:
				var a := t * 0.5 + TAU * i / 5.0
				var sp := Arch.pt(-104.0 + cos(a) * 118.0, -220.0 + sin(a * 1.6) * 40.0, -10.0 + sin(a) * 70.0)
				ci.draw_circle(sp, 12.0, Color(glow, 0.14 + 0.1 * sin(t * 2.0 + i)))
				ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -8), sp + Vector2(4, 0), sp + Vector2(0, 8), sp + Vector2(-4, 0)]), glow.lightened(0.3))
			Arch.on_front(ci, 16.0, func() -> void:
				for i in 14:
					var p := Vector2(-206.0 + i * 15.0, -16.0)
					ci.draw_polyline(PackedVector2Array([p, p + Vector2(3, -6), p + Vector2(6, 0), p + Vector2(9, -6)]), Color(glow, 0.5 + 0.3 * sin(t * 2.0 + i)), 1.6))
		else:
			# Mist along the foot.
			for i in 7:
				var mx := -230.0 + fposmod(i * 61.0 + t * 5.0, 290.0)
				FkPaint.ellipse(ci, Vector2(mx, -6.0 - (i % 3) * 6.0), Vector2(40.0, 7.0), Color(0.85, 0.95, 1.0, 0.11))
		_fireflies(ci, t, 8, -215.0, 20.0, -260.0, -40.0, Color(0.7, 0.95, 1.0))
		return
	_elf_tree(ci, -228.0, -52.0, 260.0, leaf, trunk)
	_elf_tree(ci, 24.0, -86.0, 215.0, leaf.lightened(0.05), trunk)
	# The spires behind: a needle with a swelling lantern chamber, gilt bands (silver) or facets that glow (crystal).
	for sp in spires:
		var x: float = sp[0]
		var z: float = sp[1]
		var top: float = sp[2]
		var r: float = sp[3]
		# A slender leaf-blade: narrow at the tip, swelling about two thirds of the way down.
		var h := -96.0 - top
		var prof := [[top, 0.8], [top + 0.3 * h, r * 0.5], [top + 0.6 * h, r * 0.9], [top + 0.85 * h, r], [-96.0, r * 0.9]]
		Arch.faceted(ci, x, z, prof, spire_col, 6, 0.0, Color(0, 0, 0, 0.22) if crystal else Color(0, 0, 0, 0.0), 0.8)
		if not crystal:
			for f: float in [0.36, 0.72]:
				var y := top + f * h
				var rr := _profile_r(prof, y) * 1.06
				Arch.faceted(ci, x, z, [[y - 1.5, rr], [y + 1.5, rr]], gold, 6, 0.0)
		var sx := Arch.cylinder_x(x, z)
		for f: float in sp[4]:
			_window(ci, Rect2(sx - 2.0, top + f * h, 4, 9))
		ci.draw_line(Vector2(sx, top), Vector2(sx, top - 8.0), gold, 1.4)
	# Sky-bridges between the spires: a slender arched span with a gilt rail.
	for pair in [[0, 1, -226.0], [1, 2, -238.0], [2, 3, -238.0], [3, 4, -222.0]]:
		var a: Array = spires[pair[0]]
		var b: Array = spires[pair[1]]
		var pts := PackedVector2Array()
		var rail := PackedVector2Array()
		for i in 11:
			var u := i / 10.0
			var y := float(pair[2]) - sin(PI * u) * 9.0
			var p := Arch.pt(lerpf(a[0], b[0], u), y, lerpf(a[1], b[1], u))
			pts.append(p)
			rail.append(p + Vector2(0, -7))
		ci.draw_polyline(pts, Color(glow, 0.55) if crystal else spire_col.darkened(0.12), 5.0)
		ci.draw_polyline(rail, gold, 1.2)
	# The platform, the hall with its pointed arcade and leaf frieze, and a swooping roof over it.
	Arch.box(ci, -218, 8, -30, 0, -34, 16, ivory.darkened(0.08), _face_msn(ci, ivory.darkened(0.08), 10, 22), _end_msn(ci, ivory.darkened(0.08), 10, 14))
	Arch.box(ci, -206, 4, -132, -30, -30, 14, ivory, _face_msn(ci, ivory, 12, 24), _end_msn(ci, ivory, 12, 14))
	Arch.on_front(ci, 14.0, func() -> void:
		ci.draw_line(Vector2(-206, -110), Vector2(4, -110), ivory.darkened(0.2), 3.0)
		for k in 30:
			FkPaint.ellipse(ci, Vector2(-202.0 + k * 6.9, -116.0), Vector2(3.4, 1.7), gold.darkened(0.1), 0.0))
	for x in arcade:
		_arch_win(ci, x, -30.0, 26.0, 74.0, 14.0, 10.0, jamb, ivory.lightened(0.04), 16.0)
	Arch.recess(ci, gate, 14.0, 12.0, jamb, Color(0.09, 0.07, 0.06))
	Arch.bars(ci, gate, 14.0, 12.0, 8.0, [-32, -23, -14], [-70, -50], gold.darkened(0.2), 1.6)
	Arch.on_front(ci, 14.0, func() -> void:
		ci.draw_polyline(PackedVector2Array(gate), gold, 3.0)
		for x in [-172.0, -136.0, -100.0, -64.0]:
			_hang_banner(ci, x, -102.0, 10.0, 34.0, team, gold))
	_elf_roof(ci, -216, 12, -128, -196, 78, 16, -36, 18, roof_col, gold)
	Arch.box(ci, -56, 10, -15, 0, 16, 36, ivory.darkened(0.04), _face_msn(ci, ivory.darkened(0.04), 10, 20), Callable())
	Arch.box(ci, -50, 4, -30, -15, 16, 26, ivory.darkened(0.02), _face_msn(ci, ivory.darkened(0.02), 10, 20), Callable())
	Arch.on_front(ci, 20.0, func() -> void:
		for x in [-46.0, 0.0]:
			_hang_lantern(ci, x, -92.0, Color("5a4a34")))


## The part of a silhouette between two heights (a slab of a mountain).
static func _band(pts: Array, y_top: float, y_bottom: float) -> Array:
	var clipped := Geometry2D.intersect_polygons(PackedVector2Array(pts), PackedVector2Array([Vector2(-1000, y_top), Vector2(1000, y_top), Vector2(1000, y_bottom), Vector2(-1000, y_bottom)]))
	return Array(clipped[0]) if not clipped.is_empty() else []


## Draws a polygon clipped to a silhouette (a facet of a mountain).
static func _clip_sp(ci: CanvasItem, poly: Array, silhouette: Array, col: Color) -> void:
	for c in Geometry2D.intersect_polygons(PackedVector2Array(poly), PackedVector2Array(silhouette)):
		_sp(ci, Array(c), col)


## A craggy mountain front on the current plane: ridges from the peak splitting it into lit and shadowed faces, jagged
## strata, a few chevron cracks.
static func _crags(ci: CanvasItem, silhouette: Array, rock: Color) -> void:
	var peak := Vector2(-150, -270)
	_sp(ci, silhouette, rock)
	_clip_sp(ci, [Vector2(-300, -300), peak, Vector2(-172, -190), Vector2(-196, -110), Vector2(-214, 0), Vector2(-300, 0)], silhouette, rock.lightened(0.1))
	_clip_sp(ci, [peak, Vector2(-112, -200), Vector2(-84, -130), Vector2(-60, 0), Vector2(-118, 0), Vector2(-124, -90), Vector2(-138, -170)], silhouette, rock.darkened(0.1))
	_clip_sp(ci, [peak, Vector2(100, -300), Vector2(100, 0), Vector2(-60, 0), Vector2(-84, -130), Vector2(-112, -200)], silhouette, rock.darkened(0.24))
	_clip_sp(ci, [Vector2(-176, -214), Vector2(-204, -190), Vector2(-200, -140), Vector2(-178, -160)], silhouette, rock.lightened(0.16))
	for row in 6:
		var y := -34.0 - row * 38.0
		var line := PackedVector2Array()
		for i in 20:
			var x := -250.0 + i * 14.0
			line.append(Vector2(x, y + (_hash(x, y) - 0.5) * 9.0))
		for piece in Geometry2D.intersect_polyline_with_polygon(line, PackedVector2Array(silhouette)):
			ci.draw_polyline(piece, Color(0, 0, 0, 0.13), 1.4)
			var lit := PackedVector2Array()
			for v in piece:
				lit.append(v + Vector2(0, 1.6))
			ci.draw_polyline(lit, Color(1, 1, 1, 0.05), 1.0)
	for k in 7:
		var a := Vector2(-214 + k * 30, -60 - (k % 3) * 50)
		ci.draw_polyline(PackedVector2Array([a, a + Vector2(10, 12), a + Vector2(4, 26)]), Color(0, 0, 0, 0.24), 1.5)


## A colossal statue of a dwarf king, feet on the ground at the origin, about 150 tall: a plinth, a robe, a broad chest and
## pauldrons, a braided beard, a crested helm, an upright axe. Drawn on the current plane.
static func _dwarf_statue(ci: CanvasItem, stone: Color, gold: Color) -> void:
	var lit := stone.lightened(0.08)
	var shade := stone.darkened(0.16)
	_sp(ci, _rect_pts(Rect2(-18, -20, 36, 20)), shade)
	ci.draw_line(Vector2(-18, -20), Vector2(18, -20), lit, 1.6)
	_sp(ci, [Vector2(-15, -20), Vector2(15, -20), Vector2(13, -74), Vector2(-13, -74)], stone)
	for x in [-6.0, 0.0, 6.0]:
		ci.draw_line(Vector2(x, -24), Vector2(x * 0.9, -72), Color(0, 0, 0, 0.16), 1.2)
	_sp(ci, _rect_pts(Rect2(-14.5, -78, 29, 6)), gold.darkened(0.15))
	_sp(ci, [Vector2(-13, -74), Vector2(13, -74), Vector2(21, -100), Vector2(20, -112), Vector2(-20, -112), Vector2(-21, -100)], lit)
	# The axe, held upright at the right, the arms across the chest.
	ci.draw_line(Vector2(23, -22), Vector2(23, -150), shade.darkened(0.2), 3.6)
	_sp(ci, [Vector2(25, -152), Vector2(42, -160), Vector2(47, -142), Vector2(42, -124), Vector2(25, -132)], lit)
	_sp(ci, [Vector2(21, -152), Vector2(12, -160), Vector2(14, -142), Vector2(21, -136)], shade)
	ci.draw_line(Vector2(-19, -106), Vector2(4, -88), lit.lightened(0.05), 9.0)
	ci.draw_line(Vector2(19, -106), Vector2(22, -90), lit.lightened(0.05), 9.0)
	ci.draw_circle(Vector2(23, -88), 5.0, stone.lightened(0.14))
	for sx in [-21.0, 21.0]:
		_sp(ci, FkPaint.ellipse_pts(Vector2(sx, -108), Vector2(9, 8), 0.0, 10), lit.lightened(0.06))
	# The head: a crested helm with a nose guard, a long braided beard.
	_sp(ci, FkPaint.ellipse_pts(Vector2(0, -122), Vector2(10, 11), 0.0, 12), stone.lightened(0.12))
	_sp(ci, [Vector2(-11, -122), Vector2(-10, -136), Vector2(0, -146), Vector2(10, -136), Vector2(11, -122), Vector2(6, -127), Vector2(-6, -127)], gold.darkened(0.2))
	ci.draw_line(Vector2(0, -146), Vector2(0, -132), gold.lightened(0.1), 2.0)
	ci.draw_line(Vector2(0, -127), Vector2(0, -119), gold.darkened(0.3), 1.6)
	ci.draw_line(Vector2(-5, -123), Vector2(-2, -123), Color(0, 0, 0, 0.6), 1.6)
	ci.draw_line(Vector2(2, -123), Vector2(5, -123), Color(0, 0, 0, 0.6), 1.6)
	_sp(ci, [Vector2(-10, -119), Vector2(10, -119), Vector2(11, -104), Vector2(4, -88), Vector2(0, -82), Vector2(-4, -88), Vector2(-11, -104)], shade.lightened(0.04))
	for k in 3:
		ci.draw_line(Vector2(-5 + k * 5.0, -116), Vector2(-3 + k * 3.0, -90), Color(0, 0, 0, 0.22), 1.2)


## The carved front of the hold from Bronze on: a plinth and steps, a sheer masonry face with a crenellated parapet, arched
## niches holding colossal kings, a great trapezoid gate under a heavy lintel (recessed, with its doors set inside),
## braziers on the lintel, team banners; the upper tiers, towers and details by age.
static func _dwarf_facade(ci: CanvasItem, age: int, team: Color, stone: Color, iron: Color, glow: Color) -> void:
	var gold := Color("c9a45c") if age != 2 else Color("d08a3a")
	var face_z := 40.0
	var top := -150.0
	var face := stone
	# Plinth and the steps up to the gate.
	Arch.box(ci, -232, 22, -10, 0, -12, face_z + 8.0, stone.darkened(0.16), _face_msn(ci, stone.darkened(0.16), 10, 30), _end_msn(ci, stone.darkened(0.16), 10, 14))
	# Upper tier behind the parapet (Iron on): windows in a second wall stepping back up the mountain.
	if age >= 3:
		var tier := stone.darkened(0.03)
		Arch.box(ci, -196, -36, -216, top, -12.0, 16.0, tier, _face_msn(ci, tier, 14, 30), _end_msn(ci, tier, 14, 14))
		Arch.box(ci, -200, -32, -224, -216, -14.0, 20.0, stone.darkened(0.2))
		Arch.crenellate(ci, -200, -32, -12.0, 20.0, -224, 12, 12, 22, stone.darkened(0.06), 5.0)
		for cx in [-172.0, -146.0, -120.0, -94.0]:
			_slit(ci, Rect2(cx - 6, -198, 12, 24), 16.0, 6.0, stone.darkened(0.45))
	# The face, its ledge and parapet.
	Arch.box(ci, -226, 14, top, 0, -8.0, face_z, face, _face_msn(ci, face, 22, 44), _end_msn(ci, face, 22, 16))
	var cap := Color("b87a3a") if age == 2 else stone.darkened(0.2)
	Arch.box(ci, -230, 18, top - 8.0, top, -12.0, face_z + 4.0, cap)
	if age >= 3:
		Arch.crenellate(ci, -230, 18, -10.0, face_z + 4.0, top - 8.0, 16, 14, 26, stone.darkened(0.08), 6.0)
	# Arched niches with the kings (two from Iron on, one in Bronze).
	var niches: Array = [-108.0] if age == 2 else [-196.0, -108.0]
	for cx in niches:
		for sx in [cx - 28.0, cx + 22.0]:
			Arch.box(ci, sx, sx + 6.0, -146, 0, face_z, face_z + 5.0, face.lightened(0.05), _face_msn(ci, face.lightened(0.05), 20, 8), Callable())
		var arch := Arch.arch_pts(cx - 22.0, cx + 22.0, 0, -116, 24, 0.0, 12)
		var inner := Arch.recess(ci, arch, face_z, 12.0, face.darkened(0.42), face.darkened(0.3))
		Arch.on_front(ci, inner + 2.0, func() -> void:
			FkPaint.push(ci, Transform2D(0.0, Vector2(0.86, 0.86), 0.0, Vector2(cx, 0)))
			_dwarf_statue(ci, stone, gold)
			FkPaint.pop(ci))
	# A running frieze of chevrons under the parapet.
	Arch.on_front(ci, face_z, func() -> void:
		for k in 24:
			var x := -222.0 + k * 10.0
			ci.draw_polyline(PackedVector2Array([Vector2(x, -142), Vector2(x + 3, -137), Vector2(x + 6, -142), Vector2(x + 9, -137)]), Color(gold, 0.45), 1.1))
	# The great gate: jambs and a lintel standing proud, the opening recessed, doors inside.
	Arch.box(ci, -76, -58, -128, 0, face_z, face_z + 10.0, face.lightened(0.04), _face_msn(ci, face.lightened(0.04), 16, 18), _end_msn(ci, face.lightened(0.04), 16, 10))
	Arch.box(ci, 0, 16, -128, 0, face_z, face_z + 10.0, face.lightened(0.04), _face_msn(ci, face.lightened(0.04), 16, 18), _end_msn(ci, face.lightened(0.04), 16, 10))
	var door := [Vector2(-58, 0), Vector2(-52, -104), Vector2(-6, -104), Vector2(0, 0)]
	var d_in := Arch.recess(ci, door, face_z, 16.0, face.darkened(0.42), Color(0.08, 0.07, 0.06))
	Arch.on_front(ci, d_in + 4.0, func() -> void:
		if age >= 3:
			for x in [-56.0, -28.0]:
				_sp(ci, [Vector2(x, 0), Vector2(x + 2, -100), Vector2(x + 28, -100), Vector2(x + 28, 0)], iron if age != 5 else Color("8a6a3a"))
				for r in 4:
					_rivets_line(ci, Vector2(x + 4, -84 + r * 22), Vector2(x + 24, -84 + r * 22), 4, Color("9aa0a6"))
			ci.draw_circle(Vector2(-28, -46), 4.5, gold)
			ci.draw_line(Vector2(-28, -100), Vector2(-28, 0), Color(0, 0, 0, 0.5), 1.6)
		else:
			_planks(ci, Rect2(-56, -100, 56, 100), Color("5b3f24"), 8)
			for k in 4:
				ci.draw_line(Vector2(-56, -84 + k * 22), Vector2(0, -84 + k * 22), Color("b87a3a"), 3.0))
	Arch.box(ci, -80, 20, -134, -104, face_z, face_z + 12.0, face.lightened(0.02), _face_msn(ci, face.lightened(0.02), 15, 20), _end_msn(ci, face.lightened(0.02), 15, 10))
	Arch.on_front(ci, face_z + 12.0, func() -> void:
		# The emblem on the lintel: an anvil under crossed hammers, in gilt, between two braziers' bowls.
		var c := Vector2(-30, -119)
		_sp(ci, [c + Vector2(-13, 4), c + Vector2(13, 4), c + Vector2(10, 0), c + Vector2(4, -1), c + Vector2(4, -5), c + Vector2(16, -6), c + Vector2(-14, -6), c + Vector2(-10, -1)], gold)
		ci.draw_line(c + Vector2(-9, -8), c + Vector2(9, -20), gold.lightened(0.1), 2.4)
		ci.draw_line(c + Vector2(9, -8), c + Vector2(-9, -20), gold.lightened(0.1), 2.4)
		for bx in [-70.0, 10.0]:
			_sp(ci, [Vector2(bx - 9, -142), Vector2(bx + 9, -142), Vector2(bx + 5, -134), Vector2(bx - 5, -134)], iron.darkened(0.1))
			ci.draw_line(Vector2(bx - 9, -142), Vector2(bx + 9, -142), gold, 1.8))
	# Steps up to the door.
	Arch.box(ci, -84, 24, -6, 0, face_z + 10.0, face_z + 30.0, stone.darkened(0.08), _face_msn(ci, stone.darkened(0.08), 6, 26), _end_msn(ci, stone.darkened(0.08), 6, 10))
	Arch.box(ci, -78, 18, -12, -6, face_z + 10.0, face_z + 22.0, stone.darkened(0.04), Callable(), Callable())
	# Team banners hung from the ledge between the kings.
	Arch.on_front(ci, face_z + 1.0, func() -> void:
		for bx in [-152.0]:
			ci.draw_line(Vector2(bx - 11, top), Vector2(bx + 11, top), Color("3b2c20"), 2.2)
			_sp(ci, [Vector2(bx - 10, top), Vector2(bx + 10, top), Vector2(bx + 10, top + 74), Vector2(bx, top + 64), Vector2(bx - 10, top + 74)], team)
			ci.draw_circle(Vector2(bx, top + 28), 5.0, gold.darkened(0.1)))
	if age >= 4:
		# The gate tower above the gate and a corner tower, both crenellated with a lit window.
		Arch.box(ci, -80, 20, -230, top - 8.0, 8.0, face_z + 4.0, stone.lightened(0.03), _face_msn(ci, stone.lightened(0.03), 14, 26), _end_msn(ci, stone.lightened(0.03), 14, 12))
		Arch.crenellate(ci, -82, 22, 6.0, face_z + 6.0, -230, 12, 12, 22, stone.darkened(0.06), 5.0)
		Arch.box(ci, -238, -200, -222, top - 8.0, -6.0, 26.0, stone.lightened(0.03), _face_msn(ci, stone.lightened(0.03), 14, 20), _end_msn(ci, stone.lightened(0.03), 14, 12))
		Arch.crenellate(ci, -240, -198, -6.0, 26.0, -222, 12, 10, 16, stone.darkened(0.06), 5.0)
		_slit(ci, Rect2(-36, -212, 12, 22), face_z + 4.0, 6.0, stone.darkened(0.45))
		_slit(ci, Rect2(-224, -202, 10, 20), 26.0, 6.0, stone.darkened(0.45))
	if age == 5:
		# Chimney stacks on the upper tier, a gear housing between the kings.
		for cx in [-160.0, -128.0]:
			Arch.cylinder(ci, cx, 0, 8, -286, -216, iron)
			for k in 2:
				Arch.cylinder(ci, cx, 0, 10, -276 + k * 26, -272 + k * 26, Color("8a6a3a"))
		Arch.on_front(ci, face_z + 2.0, func() -> void:
			ci.draw_circle(Vector2(-152, -40), 17.0, iron)
			ci.draw_circle(Vector2(-152, -40), 6.0, Color("c9a45c")))
	if age == 6:
		# Runes carved between the kings; the gate outlined in cold light (drawn live).
		Arch.on_front(ci, 16.0, func() -> void:
			for i in 5:
				var p := Vector2(-190 + i * 26, -160)
				ci.draw_polyline(PackedVector2Array([p, p + Vector2(6, -10), p + Vector2(12, 0), p + Vector2(18, -10)]), Color(0, 0, 0, 0.4), 2.6))


## Dwarven hold in a mountain: mine camp → carved hall behind a great gate → towered hold → forge-fort → rune-hold. The
## mountain is craggy faces on a sheer cliff, slabs stacked behind them (each shows its lane-facing side, the higher
## ones shallower); the hold is a masonry face carved into it with colossal kings in niches and a monumental gate
## (_dwarf_facade), or, in the Stone age, a timber-framed mine camp (_dwarf_camp).
static func _dwarf(ci: CanvasItem, age: int, team: Color, t: float) -> void:
	var glow: Color = RaceLook.look(&"dwarf").glow
	var rock := Color("6e6a64") if age != 2 else Color("8a5a40")
	if age == 6:
		rock = Color("4a4a58")
	var stone := rock.lightened(0.12)
	var iron := Color("4a4c52")
	var rock_z := -4.0
	var face_z := 40.0
	var peak_z := -22.0
	var tier_windows := [-172.0, -146.0, -120.0, -94.0]
	var tower_windows := [[Rect2(-36, -212, 12, 22), face_z + 4.0], [Rect2(-224, -202, 10, 20), 26.0]]
	if dynamic_pass:
		if age == 1:
			# A brazier on the cairn, a lantern over the mine mouth.
			var fl := 0.7 + 0.3 * sin(t * 11.0)
			var c := Arch.pt(-150, -124, 0)
			ci.draw_circle(c + Vector2(0, -6), 12.0, Color(1.0, 0.6, 0.25, 0.15 + 0.25 * night))
			for k in 3:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-5 + k * 3, 0), c + Vector2(-2 + k * 3, 0), c + Vector2(-3.5 + k * 3, -12 * fl - k * 2)]), Color(1.0, 0.6, 0.25).lightened(0.2 * k))
			Arch.on_front(ci, 10.0, func() -> void:
				ci.draw_circle(Vector2(-34, -66), 9.0, Color(1.0, 0.75, 0.4, 0.12 + 0.3 * night)))
		if age >= 2:
			# Fire in the braziers on the lintel.
			Arch.on_front(ci, face_z + 12.0, func() -> void:
				for bx in [-70.0, 10.0]:
					var fl := 0.7 + 0.3 * sin(t * 11.0 + bx)
					var c: Color = Color(1.0, 0.6, 0.25) if age < 6 else glow
					ci.draw_circle(Vector2(bx, -148), 13.0, Color(c, 0.15 + 0.25 * night))
					for k in 3:
						ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - 5 + k * 3, -142), Vector2(bx - 2 + k * 3, -142), Vector2(bx - 3.5 + k * 3, -144 - 13 * fl - k * 2)]), c.lightened(0.2 * k)))
		if age >= 3:
			# The upper windows glow after dark (and flicker with the forges in the Medieval and Gunpowder ages).
			for cx in tier_windows:
				var r := Rect2(cx - 6, -198, 12, 24)
				_slit(ci, r, 16.0, 6.0, Color.BLACK)
				if age in [4, 5]:
					Arch.on_front(ci, 10.0, func() -> void:
						ci.draw_rect(r, Color(1.0, 0.55, 0.2, 0.5 + 0.3 * sin(t * 6.0 + cx))))
		if age >= 4:
			for w in tower_windows:
				_slit(ci, w[0], w[1], 6.0, Color.BLACK)
			for i in 5:
				var ph := fmod(t * 0.4 + i * 0.2, 1.0)
				var src := Arch.pt(-144, -286, 0) if age == 5 else Arch.pt(-150, -262, rock_z)
				if age in [4, 5]:
					ci.draw_circle(src + Vector2(ph * 30, -ph * 80), 7 + ph * 18, Color(0.3, 0.28, 0.28, 0.5 * (1.0 - ph)))
		if age == 5:
			Arch.on_front(ci, face_z + 2.0, func() -> void:
				var c := Vector2(-152, -40)
				for k in 8:
					var a := t * 1.2 + TAU * k / 8.0
					ci.draw_line(c + Vector2(cos(a), sin(a)) * 6.0, c + Vector2(cos(a), sin(a)) * 16.0, Color("c9a45c"), 3.0))
		if age == 6:
			var k := 0.55 + 0.45 * sin(t * 1.6)
			# The gate outlined in cold light, runes between the kings.
			Arch.on_front(ci, face_z, func() -> void:
				ci.draw_polyline(PackedVector2Array([Vector2(-58, 0), Vector2(-52, -104), Vector2(-6, -104), Vector2(0, 0)]), Color(glow, 0.9 * k), 2.5))
			Arch.on_front(ci, 16.0, func() -> void:
				for i in 5:
					var p := Vector2(-190 + i * 26, -160)
					ci.draw_polyline(PackedVector2Array([p, p + Vector2(6, -10), p + Vector2(12, 0), p + Vector2(18, -10)]), Color(glow, 0.8 * k), 1.8))
			var c := Vector2(Arch.cylinder_x(-150, peak_z), -330 + sin(t * 1.3) * 5.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 16), c + Vector2(-14, -12), c + Vector2(0, -22), c + Vector2(14, -10), c + Vector2(12, 18)]), stone)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(0, 6), c + Vector2(5, -6)]), Color(glow, k), 2.0)
			for i in 3:
				ci.draw_circle(c, 26.0 - i * 7.0, Color(glow, 0.05 + i * 0.04 * k))
		# Banner on the peak (on the corner tower once there is one and the rune stone floats over the peak): a dwarf standard with a notched hem.
		var top := Arch.pt(-150, -312, peak_z) if age < 6 else Arch.pt(-219, -282, 10)
		ci.draw_line(top, top + Vector2(0, 50), Color("3b2c20"), 3.0)
		ci.draw_line(top + Vector2(-2, 4), top + Vector2(26, 4), Color("3b2c20"), 2.0)
		var sway := sin(t * 2.4) * 1.2
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(0, 4), top + Vector2(24, 4), top + Vector2(24 + sway, 34), top + Vector2(18 + sway, 28), top + Vector2(12 + sway, 34), top + Vector2(6 + sway, 28), top + Vector2(0 + sway, 34)]), team)
		return
	# The mountain: craggy faces on one front, slabs behind it whose lane-facing sides show, the higher ones shallower.
	var mountain := [Vector2(-240, 0), Vector2(-240, -170), Vector2(-226, -196), Vector2(-204, -208), Vector2(-190, -240), Vector2(-172, -228), Vector2(-150, -266), Vector2(-134, -250), Vector2(-118, -262), Vector2(-96, -234), Vector2(-70, -224), Vector2(-50, -198), Vector2(-20, -178), Vector2(16, -160), Vector2(20, 0)]
	for slab in [[0.0, -80.0, -30.0], [-80.0, -150.0, -24.0], [-150.0, -210.0, -18.0], [-210.0, -290.0, -12.0]]:
		Arch.prism(ci, _band(mountain, slab[1], slab[0]), slab[2], rock_z, rock, Color(0, 0, 0, 0), 1.0, false)
	Arch.on_front(ci, rock_z, func() -> void:
		_crags(ci, mountain, rock)
		if age == 1 or age == 3:
			_clip_sp(ci, [Vector2(-170, -248), Vector2(-150, -268), Vector2(-118, -262), Vector2(-128, -244), Vector2(-146, -250)], mountain, Color("eef2f6")))
	# Scree at the foot.
	for k in 6:
		Arch.blob(ci, -238 + k * 9, -5.0 - (k % 2) * 3, 4.0 + (k % 3) * 2, Vector2(8, 6), rock.darkened(0.04 * (k % 3)), 0.0, 9)
	if age == 1:
		_dwarf_camp(ci, rock, stone)
	else:
		_dwarf_facade(ci, age, team, stone, iron, glow)


## The Stone-age dwarf camp: a timber-framed mine mouth in the rock, a drystone wall, a stone lookout cairn with a brazier,
## an ore cart, an anvil and a rune stone.
static func _dwarf_camp(ci: CanvasItem, rock: Color, stone: Color) -> void:
	var timber := Color("6b4a2b")
	var rock_z := -4.0
	# The mine mouth: a dark adit cut into the rock, framed by two posts and a heavy lintel with a lantern.
	var mouth := Arch.rect_pts(-60, -74, -8, 0)
	Arch.recess(ci, mouth, rock_z, 28.0, rock.darkened(0.45), Color(0.06, 0.05, 0.05))
	for px in [-68.0, -8.0]:
		Arch.box(ci, px, px + 8.0, -84, 0, 0, 12, timber, func(r: Rect2) -> void: _planks(ci, r, timber, 5), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(timber), 5))
	Arch.box(ci, -74, 4, -90, -78, -2, 14, timber.lightened(0.05), func(r: Rect2) -> void: _planks(ci, r, timber.lightened(0.05), 9), func(r: Rect2) -> void: _planks(ci, r, Arch.end_col(timber), 9))
	Arch.on_front(ci, 12.0, func() -> void:
		ci.draw_line(Vector2(-34, -78), Vector2(-34, -70), Color("3a2c20"), 1.2)
		_sp(ci, _rect_pts(Rect2(-37, -70, 6, 8)), Color("c9a45c"))
		for y in [-30.0, -60.0]:
			ci.draw_line(Vector2(-68, y), Vector2(-60, y), Color("b09060"), 2.0)
			ci.draw_line(Vector2(-8, y), Vector2(0, y), Color("b09060"), 2.0))
	# A drystone wall along the front with big rough blocks and coping stones.
	var wall := stone.darkened(0.06)
	Arch.box(ci, -224, -84, -36, 0, 10, 26, wall, _face_msn(ci, wall, 12, 22), _end_msn(ci, wall, 12, 12))
	for k in 7:
		Arch.blob(ci, -216 + k * 19, -38.0, 18.0, Vector2(11, 5), wall.lightened(0.05 * (k % 2)), 0.0, 9)
	# The lookout cairn: rings of stones narrowing upward, a slab on top for a brazier.
	var stones: Array = []
	for k in 6:
		var r := 22.0 - k * 1.8
		for n in 6:
			var th := TAU * n / 6.0 + k * 0.6
			stones.append({"x": -150.0 + r * 0.72 * sin(th), "y": -8.0 - k * 19.0, "z": r * 0.72 * cos(th), "w": r * 0.5, "k": k, "tone": (n + k) % 3})
	stones.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.k < q.k or (p.k == q.k and p.z < q.z))
	for st in stones:
		Arch.blob(ci, st.x, st.y, st.z, Vector2(st.w, 10.0), stone.darkened(0.06 * st.tone), 0.0, 9)
	Arch.box(ci, -168, -132, -122, -112, -16, 16, stone.darkened(0.12), func(r: Rect2) -> void: _masonry(ci, r, stone.darkened(0.12), 5, 12), Callable())
	# An ore cart with a heap of ore, an anvil on a stump, a rune stone.
	var cart := timber.lightened(0.06)
	Arch.prism(ci, [Vector2(-52, -12), Vector2(-16, -12), Vector2(-10, -32), Vector2(-58, -32)], 34, 46, cart, Color(0, 0, 0, 0.3), 0.8)
	Arch.on_front(ci, 46.0, func() -> void:
		for wx in [-46.0, -22.0]:
			ci.draw_circle(Vector2(wx, -6), 6.5, Color("3a3a3e"))
			ci.draw_circle(Vector2(wx, -6), 2.2, Color("8a8e96"))
		for y in [-18.0, -26.0]:
			ci.draw_line(Vector2(-54, y), Vector2(-14, y), Color("4a4c52"), 1.6))
	for k in 5:
		Arch.blob(ci, -46 + k * 6, -34.0 - (k % 2) * 3, 40.0, Vector2(7, 5), Color("3e3a3a").lightened(0.05 * (k % 3)), 0.0, 8)
	Arch.cylinder(ci, -186, 36, 9, -18, 0, timber)
	Arch.prism(ci, [Vector2(-200, -18), Vector2(-172, -18), Vector2(-176, -26), Vector2(-196, -26), Vector2(-212, -30)], 30, 42, Color("55575e"), Color(0, 0, 0, 0.3), 0.8)
	Arch.prism(ci, [Vector2(-116, 0), Vector2(-118, -44), Vector2(-110, -54), Vector2(-100, -46), Vector2(-100, 0)], 32, 44, stone.lightened(0.08), Color(0, 0, 0, 0.3), 0.8)
	Arch.on_front(ci, 44.0, func() -> void:
		var p := Vector2(-114, -30)
		ci.draw_polyline(PackedVector2Array([p, p + Vector2(4, -8), p + Vector2(8, 0), p + Vector2(12, -8)]), Color(0, 0, 0, 0.4), 1.6))


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
	Arch.yaw = UnitArt.view_yaw
	var col: Color = {&"elf": Color("6a5a3a"), &"dwarf": Color("6e6a64")}.get(race, Color("7a6a54"))
	FkPaint.ellipse(ci, Vector2(0, 2), Vector2(22, 5), Color(0, 0, 0, 0.25))
	Arch.box(ci, -18, 18, -5, 1, -10, 10, col)
	ci.draw_line(Arch.pt(-18, -5, 10), Arch.pt(18, -5, 10), col.lightened(0.2), 1.2)
	for x in [-14.0, 14.0]:
		Arch.box(ci, x - 1.0, x + 1.0, -14, -5, 6, 9, col.darkened(0.2))


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
