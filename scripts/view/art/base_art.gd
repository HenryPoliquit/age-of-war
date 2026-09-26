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


static func draw_base(ci: CanvasItem, age: int, team: Color, hp_frac: float, t: float, build: float, slots: int) -> void:
	# `build` 0→1 plays the rebuild after evolving: the new structure rises out of the ground.
	var rise := (1.0 - ease(build, 0.4)) * 240.0
	UnitArt._push(ci, Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2(0, rise)))
	match age:
		1: _stone(ci, team, t)
		2: _bronze(ci, team, t)
		3: _medieval(ci, team, t)
		4: _gunpowder(ci, team, t)
		5: _industrial(ci, team, t)
		_: _future(ci, team, t)
	# Turret platforms.
	for i in slots:
		var p: Vector2 = SLOTS[i]
		ci.draw_rect(Rect2(p + Vector2(-17, 10), Vector2(34, 7)), Color(0.12, 0.1, 0.09, 0.85))
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


static func _stone(ci: CanvasItem, team: Color, t: float) -> void:
	# Rock outcrop with a hide hut and a stake palisade.
	_poly(ci, [Vector2(-200, 0), Vector2(-190, -70), Vector2(-150, -120), Vector2(-90, -140), Vector2(-30, -110), Vector2(0, -60), Vector2(10, 0)], Color("7d6a58"))
	_poly(ci, [Vector2(-150, -120), Vector2(-90, -140), Vector2(-60, -126), Vector2(-120, -100)], Color("9a8570"))
	_poly(ci, [Vector2(-140, -100), Vector2(-60, -100), Vector2(-100, -170)], Color("8a6440"))
	_poly(ci, [Vector2(-112, -100), Vector2(-88, -100), Vector2(-100, -130)], Color("2a1d14"))
	for i in 9:
		var x := -6.0 - i * 14.0
		_poly(ci, [Vector2(x - 4, 0), Vector2(x - 4, -36 - (i % 3) * 4), Vector2(x, -44 - (i % 3) * 4), Vector2(x + 4, -36 - (i % 3) * 4), Vector2(x + 4, 0)], Color("6b4a2b"))
	ci.draw_line(Vector2(-130, -22), Vector2(0, -22), Color("4a3320"), 3.0)
	_banner(ci, Vector2(-100, -216), team, t)


static func _bronze(ci: CanvasItem, team: Color, t: float) -> void:
	var stone := Color("e4d6b6")
	ci.draw_rect(Rect2(-190, -130, 190, 130), stone)
	ci.draw_rect(Rect2(-190, -130, 190, 12), Color("c9b58c"))
	for i in 6:
		ci.draw_rect(Rect2(-178 + i * 30, -118, 12, 118), Color("f1e8d2"))
	_poly(ci, [Vector2(-200, -130), Vector2(10, -130), Vector2(-95, -186)], Color("c9a060"))
	_poly(ci, [Vector2(-170, -136), Vector2(-20, -136), Vector2(-95, -176)], team)
	ci.draw_rect(Rect2(-40, -70, 40, 70), Color("5b3f24"))
	_banner(ci, Vector2(-96, -236), team, t)


static func _medieval(ci: CanvasItem, team: Color, t: float) -> void:
	var stone := Color("8b8c88")
	ci.draw_rect(Rect2(-200, -120, 200, 120), stone)
	ci.draw_rect(Rect2(-130, -220, 70, 220), stone.darkened(0.08))
	for k in 5:
		ci.draw_rect(Rect2(-200 + k * 42, -134, 24, 14), stone)
		ci.draw_rect(Rect2(-130 + k * 16, -232, 10, 12), stone.darkened(0.08))
	for r in 6:
		for k in 6:
			ci.draw_rect(Rect2(-196 + k * 33 + (r % 2) * 16, -112 + r * 18, 30, 1.5), Color(0, 0, 0, 0.15))
	_poly(ci, [Vector2(-44, 0), Vector2(-44, -58), Vector2(-22, -76), Vector2(0, -58), Vector2(0, 0)], Color("3d2b1a"))
	ci.draw_rect(Rect2(-110, -190, 30, 42), team)
	_banner(ci, Vector2(-95, -278), team, t, 32)


static func _gunpowder(ci: CanvasItem, team: Color, t: float) -> void:
	# Star-fort bastion: sloped earthwork faces and a gun deck.
	_poly(ci, [Vector2(-210, 0), Vector2(-200, -110), Vector2(-150, -140), Vector2(-40, -140), Vector2(10, -100), Vector2(20, 0)], Color("8a7b66"))
	_poly(ci, [Vector2(-40, -140), Vector2(10, -100), Vector2(20, 0), Vector2(-20, 0)], Color("75685a"))
	ci.draw_rect(Rect2(-150, -158, 110, 18), Color("5b5046"))
	for k in 4:
		ci.draw_rect(Rect2(-146 + k * 28, -166, 18, 10), Color("5b5046"))
	ci.draw_rect(Rect2(-120, -210, 50, 52), Color("6c5f52"))
	_poly(ci, [Vector2(-126, -210), Vector2(-64, -210), Vector2(-95, -236)], Color("3a3f58"))
	ci.draw_rect(Rect2(-40, -60, 34, 60), Color("3a2a1c"))
	_banner(ci, Vector2(-95, -290), team, t, 30)


static func _industrial(ci: CanvasItem, team: Color, t: float) -> void:
	var concrete := Color("6f6e66")
	ci.draw_rect(Rect2(-210, -120, 210, 120), concrete)
	ci.draw_rect(Rect2(-210, -128, 210, 8), concrete.darkened(0.2))
	ci.draw_rect(Rect2(-190, -250, 26, 130), Color("5a4a40"))
	ci.draw_rect(Rect2(-190, -250, 26, 10), Color("3a302a"))
	for i in 5:
		var ph := fmod(t * 0.4 + i * 0.2, 1.0)
		ci.draw_circle(Vector2(-177 + ph * 30, -258 - ph * 90), 8 + ph * 22, Color(0.3, 0.28, 0.28, 0.5 * (1.0 - ph)))
	for k in 5:
		ci.draw_rect(Rect2(-196 + k * 40, -90, 26, 12), Color("20201e"))
		ci.draw_rect(Rect2(-196 + k * 40, -89, 26, 4), Color(1.0, 0.7, 0.3, 0.5 + 0.2 * sin(t * 2.0 + k)))
	ci.draw_rect(Rect2(-60, -160, 60, 40), concrete.darkened(0.1))
	ci.draw_rect(Rect2(-120, -110, 60, 20), team)
	ci.draw_rect(Rect2(-40, -56, 36, 56), Color("2b2b27"))
	_banner(ci, Vector2(-100, -176), team, t)


static func _future(ci: CanvasItem, team: Color, t: float) -> void:
	var hull := Color("2c3246")
	var glow := team.lightened(0.5)
	_poly(ci, [Vector2(-220, 0), Vector2(-200, -120), Vector2(-140, -300), Vector2(-100, -320), Vector2(-60, -300), Vector2(-10, -120), Vector2(12, 0)], hull)
	_poly(ci, [Vector2(-100, -320), Vector2(-60, -300), Vector2(-10, -120), Vector2(12, 0), Vector2(-40, 0)], hull.lightened(0.08))
	for i in 6:
		ci.draw_line(Vector2(-190 + i * 30, -20), Vector2(-150 + i * 16, -280 + i * 10), Color(glow, 0.25), 2.0)
	var pulse := 0.6 + 0.4 * sin(t * 2.4)
	for i in 4:
		ci.draw_circle(Vector2(-100, -230), 30.0 - i * 6.0, Color(glow, 0.12 * pulse + i * 0.08))
	ci.draw_circle(Vector2(-100, -230), 8, Color(1, 1, 1, 0.9))
	ci.draw_rect(Rect2(-46, -70, 42, 70), Color(glow, 0.25))
	ci.draw_rect(Rect2(-46, -70, 42, 70), Color(glow, 0.8), false, 2.0)


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
