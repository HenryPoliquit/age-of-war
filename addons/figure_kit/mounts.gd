class_name FkMounts
extends RefCounted
## Beasts (horse, boar, elk, ram, bear, …), riders seated on them, and the war chariot.


## Beast parameters: coat, body half-length L, leg height H, head kind, antlers, cover (tack/armour).
const BEASTS := {
	"boar": {"col": Color("5b4130"), "L": 21.0, "H": 22.0, "head": "boar", "cover": "blanket"},
	"warboar": {"col": Color("4a3528"), "L": 22.0, "H": 23.0, "head": "boar", "cover": "plates"},
	"horse": {"col": Color("6a4a31"), "L": 24.0, "H": 33.0, "head": "horse", "cover": "blanket"},
	"warhorse": {"col": Color("d8d2c4"), "L": 24.0, "H": 33.0, "head": "horse", "cover": "caparison"},
	"barded": {"col": Color("3a2c22"), "L": 24.0, "H": 33.0, "head": "horse", "cover": "scale"},
	"elfsteed": {"col": Color("efeade"), "L": 24.0, "H": 35.0, "head": "horse", "cover": "caparison", "slim": true},
	"stag": {"col": Color("8a5a34"), "L": 22.0, "H": 35.0, "head": "deer", "antlers": 1, "cover": "blanket", "slim": true},
	"elk": {"col": Color("6e5038"), "L": 25.0, "H": 37.0, "head": "deer", "antlers": 2, "cover": "blanket"},
	"ram": {"col": Color("d6cab2"), "L": 20.0, "H": 24.0, "head": "ram", "cover": "blanket", "wool": true},
	"warram": {"col": Color("8a7c6a"), "L": 21.0, "H": 25.0, "head": "ram", "cover": "plates", "wool": true},
	"bear": {"col": Color("4a3426"), "L": 26.0, "H": 26.0, "head": "bear", "cover": "plates", "paws": true},
}


## Beast drawn on the quadruped skeleton (FkQuadruped): folding knees and hocks, planted hooves, a nodding head.
## Everything on the beast's centre plane (body, neck, head, tail, cover) is drawn under the camera's squeeze of
## that plane; the legs, each in the plane of its side, are drawn from their projected joints, so a turned camera
## shows the near and far legs apart. `view` is the camera ({yaw}). Returns the skeleton's joints.
static func quadruped(ci: CanvasItem, kind: String, team: Color, pose: Dictionary, seed: int, metal := Color("a5a9ae"), view := {}) -> Dictionary:
	var bp: Dictionary = BEASTS.get(kind, BEASTS["horse"])
	var j := FkQuadruped.solve(bp, pose, seed, view)
	var mv := FkPaint.move_amount(pose)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var head_kind: String = bp.head
	var col := FkPaint.tint(bp.col, pose)
	var dark := col.darkened(0.35)
	var tm := FkPaint.tint(team, pose)
	var mt := FkPaint.tint(metal, pose)
	var L: float = bp.L
	var H: float = bp.H
	var slim: bool = bp.get("slim", false)
	var heavy := head_kind in ["boar", "bear", "ram"]
	var c: Vector2 = j.c
	var lunge: float = j.lunge
	var squeeze := Transform2D(Vector2(j.cy, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	FkPaint.push(ci, squeeze)
	FkPaint.shadow(ci, L + 8)
	FkPaint.pop(ci)
	# Legs: shoulder or hip down to the elbow or stifle (carried by the body), the knee folding forward or the
	# hock back, the fetlock and a planted hoof (or a paw). The far side is shaded darker.
	var w0 := 9.0 if heavy else (6.8 if slim else 8.0)
	var w1 := 5.2 if not slim else 3.8
	if head_kind == "bear":
		w0 = 12.0
		w1 = 8.0
	var draw_leg := func(leg: String) -> void:
		var g: Dictionary = j.legs[leg]
		var lc := col.darkened(0.28 if j.z[leg] < 0.0 else 0.0)
		FkPaint.seg(ci, g.root, g.top, w0, w0 * 0.9, lc)
		FkPaint.seg(ci, g.top, g.mid, w0 * 0.9, w1, lc)
		ci.draw_circle(g.mid, w1 * 0.5, lc.darkened(0.08))
		FkPaint.seg(ci, g.mid, g.fetlock, w1 * 0.88, w1 * 0.66, lc)
		if bp.get("paws", false):
			FkPaint.ellipse(ci, (g.hoof as Vector2) + Vector2(2, -2), Vector2(6, 3.2), lc.darkened(0.15))
		else:
			FkPaint.seg(ci, g.fetlock, g.hoof, w1 * 0.66, w1 * 0.72, lc.darkened(0.1))
			ci.draw_rect(Rect2((g.hoof as Vector2) + Vector2(-2.5, -2.6), Vector2(5.5, 2.8)), Color(0.12, 0.1, 0.08))
	var far_legs: Array = FkQuadruped.LEGS.keys().filter(func(l: String) -> bool: return j.z[l] < 0.0)
	var near_legs: Array = FkQuadruped.LEGS.keys().filter(func(l: String) -> bool: return j.z[l] > 0.0)
	for leg in far_legs:
		draw_leg.call(leg)
	FkPaint.push(ci, squeeze)
	# Tail behind the far legs.
	match head_kind:
		"horse":
			for k in 5:
				var sway := sin(t * 2.5 + k * 0.4) * 3.0 + mv * 4.0
				ci.draw_polyline(PackedVector2Array([c + Vector2(-L - 2, -6 + k), c + Vector2(-L - 9 - sway * 0.5, 2 + k), c + Vector2(-L - 12 - sway, 14 + k * 1.5)]), dark.darkened(0.1 * (k % 2)), 2.0)
		"deer":
			FkPaint.ellipse(ci, c + Vector2(-L - 4, -7 + sin(t * 5.0)), Vector2(3, 4.5), Color("efe6d4"), -0.5)
		"boar":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-L - 2, -4), c + Vector2(-L - 6, -2 + sin(t * 6.0)), c + Vector2(-L - 5, 3)]), dark, 1.5)
		_:
			ci.draw_circle(c + Vector2(-L - 4, -4), 3.5, dark)
	# Barrel: chest, withers, back, croup, hindquarters, belly.
	var top_y := -12.0
	if head_kind == "boar":
		top_y = -15.0
	elif head_kind == "bear":
		top_y = -19.0
	var body := [c + Vector2(L + 6, -2), c + Vector2(L - 2, -11), c + Vector2(L * 0.2, top_y), c + Vector2(-L * 0.6, -11),
		c + Vector2(-L - 5, -6), c + Vector2(-L - 6, 4), c + Vector2(-L * 0.5, 10), c + Vector2(L * 0.4, 10), c + Vector2(L + 5, 6)]
	FkPaint.shade_poly(ci, body, col)
	if bp.get("wool", false):
		# Fleece: a scalloped outline of curls.
		for k in 9:
			var wp := c + Vector2(-L - 2 + k * (2 * L + 6) / 8.0, -10 - 2 * sin(k * 1.3))
			ci.draw_circle(wp, 4.2, col.lightened(0.08))
			ci.draw_arc(wp, 2.4, 0.5, 3.6, 6, col.darkened(0.15), 0.8)
		for k in 5:
			ci.draw_circle(c + Vector2(-L + k * L * 0.45, 7), 3.6, col.darkened(0.06))
	FkPaint.push(ci, Transform2D(0.0, j.poll) * Transform2D(j.head_angle, Vector2.ZERO) * Transform2D(0.0, -(j.poll as Vector2)))
	match head_kind:
		"horse", "deer":
			var deer := head_kind == "deer"
			# Neck up to the head.
			var hd: Vector2 = j.poll
			var neck_top := hd - Vector2(4, -1)
			FkPaint.shade_poly(ci, [c + Vector2(L - 4, -10), c + Vector2(L + 6, -4), neck_top + Vector2(5 if not deer else 3.5, 4), neck_top + Vector2(-2, -1)], col)
			if deer:
				FkPaint.shade_poly(ci, [hd + Vector2(-4, -3.5), hd + Vector2(3, -5), hd + Vector2(11, 2), hd + Vector2(10.5, 5), hd + Vector2(5, 5.5), hd + Vector2(-3, 3)], col)
				FkPaint.ellipse(ci, hd + Vector2(-3.5, -5.5), Vector2(3.8, 1.6), dark, -0.7)
				ci.draw_circle(hd + Vector2(10.4, 3.4), 1.2, Color(0.1, 0.07, 0.06))
				_antlers(ci, hd + Vector2(-0.5, -4), int(bp.get("antlers", 1)), FkPaint.tint(Color("d9c9a6"), pose))
			else:
				FkPaint.shade_poly(ci, [hd + Vector2(-4, -4), hd + Vector2(3, -6), hd + Vector2(13, 3), hd + Vector2(12, 7), hd + Vector2(6, 7), hd + Vector2(-3, 3)], col)
				ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(-2, -4), hd + Vector2(0, -10), hd + Vector2(2, -5)]), dark)
				ci.draw_circle(hd + Vector2(11.5, 4.5), 0.9, Color(0.1, 0.07, 0.06))
			ci.draw_circle(hd + Vector2(2.5, -1.5), 1.2, Color(0.05, 0.04, 0.04))
			# Bridle and reins in team colour.
			ci.draw_polyline(PackedVector2Array([hd + Vector2(-1, -3), hd + Vector2(8, 3), hd + Vector2(9, 6)]), tm.darkened(0.2), 1.2)
			ci.draw_line(hd + Vector2(8, 3), c + Vector2(4, -14), Color(0.25, 0.18, 0.12), 1.0)
			if not deer:
				# Mane strands lag behind (secondary motion); elven steeds get a long silver mane.
				var mane := dark if kind != "elfsteed" else FkPaint.tint(Color("c9d2dc"), pose)
				for k in 6:
					var mp := (c + Vector2(L - 4, -11)).lerp(neck_top + Vector2(-2, -2), k / 5.0)
					ci.draw_line(mp, mp + Vector2(-5 - mv * 2.0, 3 + sin(t * 4.0 + k) * 1.5) * (1.5 if kind == "elfsteed" else 1.0), mane, 2.2)
				if kind in ["barded", "elfsteed"]:
					# Chanfron.
					FkPaint.poly(ci, [hd + Vector2(-2, -4), hd + Vector2(4, -6), hd + Vector2(11, 1), hd + Vector2(8, 3)], mt)
					if kind == "elfsteed":
						ci.draw_line(hd + Vector2(1, -5), hd + Vector2(-2, -12), mt.lightened(0.3), 1.6)
		"boar":
			# Boar head: heavy snout, tusks, bristled back.
			var hd: Vector2 = j.poll
			FkPaint.shade_poly(ci, [hd + Vector2(-4, -9), hd + Vector2(6, -6), hd + Vector2(14, 1), hd + Vector2(13, 6), hd + Vector2(2, 7), hd + Vector2(-4, 4)], col)
			ci.draw_rect(Rect2(hd + Vector2(12, 0), Vector2(3, 5)), col.darkened(0.3))
			ci.draw_polyline(PackedVector2Array([hd + Vector2(10, 5), hd + Vector2(15, 2), hd + Vector2(14, -3)]), Color("efe6cf"), 2.4)
			ci.draw_circle(hd + Vector2(4, -3), 1.1, Color(0.05, 0.04, 0.04))
			ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(-2, -8), hd + Vector2(-1, -13), hd + Vector2(2, -8)]), dark)
			for k in 8:
				var bpk := c + Vector2(-L * 0.6 + k * 4.5, -12 - (2 if k % 2 == 0 else 0))
				ci.draw_line(bpk, bpk + Vector2(-2, -4), dark, 1.6)
			if kind == "warboar":
				FkPaint.poly(ci, [hd + Vector2(-3, -9), hd + Vector2(7, -6), hd + Vector2(10, -1), hd + Vector2(-2, -2)], mt)
				ci.draw_line(hd + Vector2(2, -8), hd + Vector2(4, -14), mt.lightened(0.2), 1.8)
		"ram":
			# Ram head: short muzzle and a heavy curled horn.
			var hd: Vector2 = j.poll
			FkPaint.shade_poly(ci, [c + Vector2(L - 2, -10), c + Vector2(L + 4, -2), hd + Vector2(2, 6), hd + Vector2(-2, -4)], col)
			FkPaint.shade_poly(ci, [hd + Vector2(-4, -5), hd + Vector2(4, -6), hd + Vector2(11, 1), hd + Vector2(10, 5), hd + Vector2(3, 6), hd + Vector2(-3, 2)], FkPaint.tint(Color("b8ab92"), pose))
			ci.draw_circle(hd + Vector2(4, -2), 1.1, Color(0.05, 0.04, 0.04))
			var horn := PackedVector2Array()
			for k in 16:
				var a := -1.2 + k * 0.38
				horn.append(hd + Vector2(-1, -1) + Vector2(cos(a), sin(a)) * (7.5 - k * 0.32))
			ci.draw_polyline(horn, FkPaint.tint(Color("c9b48a"), pose), 3.4)
			ci.draw_polyline(horn, FkPaint.tint(Color("8a7656"), pose), 1.0)
			if kind == "warram":
				FkPaint.poly(ci, [hd + Vector2(-2, -6), hd + Vector2(5, -7), hd + Vector2(10, 0), hd + Vector2(3, 0)], mt)
		"bear":
			# Bear: shoulder hump, round head, small ears, short snout.
			var hd: Vector2 = j.poll
			FkPaint.shade_poly(ci, FkPaint.ellipse_pts(hd, Vector2(8.5, 7.5)), col)
			FkPaint.shade_poly(ci, [hd + Vector2(4, -2), hd + Vector2(13, 0), hd + Vector2(13, 5), hd + Vector2(5, 6)], col.lightened(0.12))
			ci.draw_circle(hd + Vector2(13, 1.2), 1.6, Color(0.06, 0.05, 0.05))
			ci.draw_circle(hd + Vector2(-3, -7), 3.0, col.darkened(0.1))
			ci.draw_circle(hd + Vector2(3.5, -2.5), 1.1, Color(0.05, 0.04, 0.04))
			if atk >= 0.0 and atk < 0.6:
				ci.draw_line(hd + Vector2(6, 5), hd + Vector2(12, 7), Color(0.6, 0.2, 0.2), 2.0)
	FkPaint.pop(ci)
	FkPaint.pop(ci)
	for leg in near_legs:
		draw_leg.call(leg)
	if atk >= 0.3 and atk < 0.8:
		# Dust kicking up from the hooves on the charge.
		var du := (atk - 0.3) / 0.5
		for k in 4:
			var dp := c * Vector2(j.cy, 1.0) + Vector2((-L * 0.6 + k * L * 0.45) * j.cy - du * 10.0, H + 8.0 - du * 6.0 - k % 2 * 3.0)
			ci.draw_circle(dp, 2.5 + du * 5.0, Color(0.72, 0.64, 0.5, 0.4 * (1.0 - du)))
	# Cover: tack or barding in team colour, on the centre plane.
	FkPaint.push(ci, squeeze)
	match bp.cover:
		"caparison":
			var trim := FkPaint.tint(Color("d9c27a") if kind != "elfsteed" else Color("dfe6ee"), pose)
			FkPaint.shade_poly(ci, [c + Vector2(-L - 5, -9), c + Vector2(L + 3, -9), c + Vector2(L + 6, 14), c + Vector2(-L - 7, 14)], tm)
			for k in 6:
				var hx := -L - 5 + k * (2 * L + 10) / 6.0
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(hx, 14), c + Vector2(hx + 4, 19), c + Vector2(hx + 8, 14)]), tm.darkened(0.25))
			ci.draw_line(c + Vector2(-L - 5, -5), c + Vector2(L + 3, -5), trim, 2.0)
			ci.draw_line(c + Vector2(-L - 6, 11), c + Vector2(L + 5, 11), trim, 1.5)
		"scale":
			# Cataphract barding: rows of scales over the body, team saddle cloth on top.
			FkPaint.shade_poly(ci, [c + Vector2(-L - 5, -10), c + Vector2(L + 4, -10), c + Vector2(L + 6, 11), c + Vector2(-L - 6, 11)], mt.darkened(0.15))
			for r in 4:
				for k in 9:
					ci.draw_arc(c + Vector2(-L - 2 + k * (2 * L + 6) / 8.0 + (r % 2) * 2.5, -6 + r * 5), 2.8, 0.1, PI - 0.1, 6, mt.darkened(0.45), 1.0)
			FkPaint.shade_poly(ci, [c + Vector2(-9, -13), c + Vector2(8, -13), c + Vector2(9, -2), c + Vector2(-10, -2)], tm)
		"plates":
			FkPaint.shade_poly(ci, [c + Vector2(-L * 0.7, -14), c + Vector2(L * 0.7, -14), c + Vector2(L * 0.8, -4), c + Vector2(-L * 0.8, -4)], mt)
			FkPaint.rivets(ci, c + Vector2(-L * 0.7, -12), c + Vector2(L * 0.7, -12), 6, mt.lightened(0.35))
			FkPaint.shade_poly(ci, [c + Vector2(-9, -16), c + Vector2(8, -16), c + Vector2(9, -7), c + Vector2(-10, -7)], tm)
		_:
			# Saddle blanket.
			FkPaint.shade_poly(ci, [c + Vector2(-9, -13), c + Vector2(8, -13), c + Vector2(9, -4), c + Vector2(-10, -4)], tm)
			ci.draw_rect(Rect2(c + Vector2(-6, -15), Vector2(12, 3)), Color(0.3, 0.2, 0.12))
	FkPaint.pop(ci)
	return j


static func _antlers(ci: CanvasItem, at: Vector2, kind: int, col: Color) -> void:
	if kind == 2:
		# Elk: broad palmate antlers with tines.
		FkPaint.poly(ci, [at, at + Vector2(-4, -8), at + Vector2(-12, -12), at + Vector2(-16, -9), at + Vector2(-8, -6)], col)
		for k in 4:
			var p := at + Vector2(-5 - k * 3.2, -9 - k * 0.8)
			ci.draw_line(p, p + Vector2(-1 + k * 0.3, -5), col, 1.6)
		ci.draw_line(at, at + Vector2(4, -7), col, 1.8)
	else:
		# Stag: branching beams.
		ci.draw_polyline(PackedVector2Array([at, at + Vector2(-3, -8), at + Vector2(-2, -16), at + Vector2(-6, -22)]), col, 1.8)
		ci.draw_line(at + Vector2(-2.6, -7), at + Vector2(3, -11), col, 1.4)
		ci.draw_line(at + Vector2(-2.2, -14), at + Vector2(3, -18), col, 1.3)
		ci.draw_line(at + Vector2(-3.5, -18), at + Vector2(-9, -19), col, 1.2)
		ci.draw_polyline(PackedVector2Array([at + Vector2(1, 0), at + Vector2(1, -7), at + Vector2(4, -14)]), col.darkened(0.2), 1.4)


## A rider's pose on a beast: it doesn't walk, it rides the gait: hips sway with the stride and its spine
## absorbs the beast's bob, so the head stays level.
static func rider_pose(j: Dictionary, pose: Dictionary) -> Dictionary:
	var p := pose.duplicate()
	p["moving"] = false
	p["move"] = 0.0
	p["ride_walk"] = pose.get("walk", 0.0)
	p["ride_mv"] = FkPaint.move_amount(pose)
	p["ride_bob"] = j.bob
	return p


static func mounted(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var pal: Array = st.palette
	var j := quadruped(ci, st.get("beast", "horse"), st.team, pose, seed, pal[2], st.get("view", {}))
	_rider(ci, st, rider_pose(j, pose), seed, j.saddle)


static func _rider(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, at: Vector2) -> void:
	# Seated on the saddle: the figure draws its near leg with the foot in the stirrup.
	FkFigure.offset_humanoid(ci, st, pose, seed, at + Vector2(0, 27))


## The camera's projection of the plane z = dz (see FkRig): the picture squeezed in x by cos(yaw) and shifted back
## by dz · sin(yaw). Anything standing in that plane (a wheel, a panel, the centre line) is drawn through it.
static func _plane(view: Dictionary, dz := 0.0) -> Transform2D:
	var yaw: float = view.get("yaw", 0.0)
	return Transform2D(Vector2(cos(yaw), 0.0), Vector2(0.0, 1.0), Vector2(-dz * sin(yaw), 0.0))


## Chariot layers, back to front: the driver stands inside the car, its near panel hiding them below the thigh,
## the near wheel over the panel.
const CHARIOT_ORDER := ["pole", "far wheel", "car back", "driver", "car front", "near wheel", "yoke"]
## Ground covered per radian of walk phase for a chariot (screen px), and the wheel's radius.
const CHARIOT_PACE := 1.0 / 0.12
const WHEEL_R := 13.0
## Where the driver stands (x) in the car, and how far out of the centre line the wheels and the car's
## panels stand (z), the near side toward the viewer.
const DRIVER_X := -17.0
const WHEEL_Z := 8.0
const PANEL_Z := 6.0


## Wheel joints (center = axle, top, bottom = ground contact) in the wheel's own plane (draw them under
## _plane(view, ±WHEEL_Z)); the wheel's spin, which turns it by the ground covered over its radius as it looks
## on the screen (a disc seen from a turned camera is foreshortened by cos(yaw), so it spins that much more per
## px: no slipping); the car floor's height; and, on the screen, where the driver stands (bumped by the ride).
static func chariot_joints(pose: Dictionary, view := {}) -> Dictionary:
	var cy := cos(view.get("yaw", 0.0))
	var center := Vector2(-18, -WHEEL_R)
	var angle: float = pose.get("walk", 0.0) * CHARIOT_PACE / (WHEEL_R * cy)
	var floor := -16.0
	var bump := sin(angle * 6.0) * 0.6 * FkPaint.move_amount(pose)
	return {"center": center, "top": center + Vector2(0, -WHEEL_R), "bottom": center + Vector2(0, WHEEL_R),
		"angle": angle, "floor": floor, "driver": Vector2(DRIVER_X * cy, floor + bump)}


## The car's side silhouette per kind (its bottom edge is the floor).
static func _car_outline(kind: String) -> Array:
	match kind:
		"wood":
			return [Vector2(-30, -16), Vector2(-6, -16), Vector2(0, -30), Vector2(-4, -40), Vector2(-12, -30), Vector2(-28, -28)]
		"iron":
			return [Vector2(-30, -14), Vector2(-4, -14), Vector2(-4, -32), Vector2(-30, -32)]
		_:
			return [Vector2(-30, -16), Vector2(-6, -16), Vector2(-4, -36), Vector2(-26, -34)]


static func chariot(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var pal: Array = st.palette
	var team: Color = st.team
	var view: Dictionary = st.get("view", {})
	var cj := chariot_joints(pose, view)
	# The beast, scaled ahead of the car; its hooves keep pace with the wheels.
	FkPaint.push(ci, Transform2D(0.0, Vector2(26.0 * cos(view.get("yaw", 0.0)), 0)) * Transform2D(0.0, Vector2(0.78, 0.78), 0.0, Vector2.ZERO))
	quadruped(ci, st.get("beast", "horse"), team, pose.merged({"pace": CHARIOT_PACE / 0.78}, true), seed, pal[2], view)
	FkPaint.pop(ci)
	var wood := FkMachines.wood(pose)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var tm := FkPaint.tint(team, pose)
	var kind: String = st.get("car", "bronze")
	var body_col: Color = FkPaint.tint(Color("b89a6a"), pose) if kind == "wood" else (metal.darkened(0.2) if kind == "iron" else metal)
	var parts := {}
	parts["pole"] = func() -> void:
		FkPaint.push(ci, _plane(view))
		ci.draw_line(Vector2(-10, -18), Vector2(18, -24), wood.darkened(0.2), 3.0)
		FkPaint.pop(ci)
	parts["far wheel"] = func() -> void:
		FkPaint.push(ci, _plane(view, -WHEEL_Z))
		FkPaint.wheel(ci, cj.center, WHEEL_R, cj.angle, wood.darkened(0.35), metal.darkened(0.35))
		FkPaint.pop(ci)
	parts["car back"] = func() -> void:
		# The far wall's rim, seen behind the driver.
		FkPaint.push(ci, _plane(view, -PANEL_Z))
		FkPaint.shade_poly(ci, _car_outline(kind), body_col.darkened(0.4))
		FkPaint.pop(ci)
	parts["driver"] = func() -> void:
		FkPaint.push(ci, Transform2D(0.0, cj.driver))
		FkFigure.humanoid(ci, FkFigure.dress(st, {"helmet": st.get("crew", "crest"), "weapon": st.get("weapon", "spear")}),
			pose.merged({"move": 0.0, "moving": false, "shadow": false}, true), seed)
		FkPaint.pop(ci)
	parts["car front"] = func() -> void:
		FkPaint.push(ci, _plane(view, PANEL_Z))
		match kind:
			"wood":
				# Elven car: a curved prow of pale wood, like a leaf.
				FkPaint.shade_poly(ci, _car_outline(kind), body_col)
				FkPaint.poly(ci, [Vector2(-26, -19), Vector2(-9, -19), Vector2(-6, -27), Vector2(-24, -26)], tm)
				ci.draw_polyline(PackedVector2Array([Vector2(-6, -16), Vector2(0, -30), Vector2(-4, -40), Vector2(-8, -36)]), FkPaint.tint(Color("d9b25c"), pose), 1.4)
			"iron":
				# Dwarf car: an iron-bound box with a ram's-head prow.
				FkPaint.shade_poly(ci, _car_outline(kind), body_col)
				FkPaint.poly(ci, [Vector2(-27, -18), Vector2(-8, -18), Vector2(-8, -28), Vector2(-27, -28)], tm)
				FkPaint.rivets(ci, Vector2(-29, -31), Vector2(-5, -31), 6, metal.lightened(0.3))
				ci.draw_arc(Vector2(-3, -30), 4.0, -2.0, 2.0, 8, FkPaint.tint(Color("c9b48a"), pose), 2.2)
			_:
				FkPaint.shade_poly(ci, _car_outline(kind), body_col)
				FkPaint.poly(ci, [Vector2(-28, -19), Vector2(-8, -19), Vector2(-7, -31), Vector2(-25, -30)], tm)
		FkPaint.pop(ci)
	parts["near wheel"] = func() -> void:
		FkPaint.push(ci, _plane(view, WHEEL_Z))
		FkPaint.wheel(ci, cj.center, WHEEL_R, cj.angle, wood, metal)
		FkPaint.pop(ci)
	parts["yoke"] = func() -> void:
		FkPaint.push(ci, _plane(view))
		ci.draw_line(Vector2(15, -27), Vector2(19, -21), wood.darkened(0.1), 2.5)
		FkPaint.pop(ci)
	for name in CHARIOT_ORDER:
		(parts[name] as Callable).call()
