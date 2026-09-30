class_name FkWeapons
extends RefCounted
## Hand weapons, drawn attached to the skeleton's solved hands (FkSkeleton.solve): chopping blades and
## hafts, polearms, throws, slings, bows, staves, crossbows and long guns. Also which projectile each
## one fires. The arms themselves are FkFigure's.


## Projectile per hand weapon (melee weapons fire nothing).
const SHOTS := {"sling": "stone", "javelin": "javelin", "throwing_axe": "axe", "bow": "arrow", "starbow": "bolt",
	"crossbow": "arrow", "musket": "bullet", "arcane_rifle": "bolt", "rune_rifle": "bolt", "staff": "bolt"}


const CHOP := ["club", "sword", "gladius", "shovel", "baton", "saber", "axe", "hammer", "leafblade", "spellsword", "rune_hammer"]

## Weapons held in the far hand (drawn at its depth, under the drawing arm).
const HELD_FAR := ["bow", "starbow"]

## Where a figure's shot leaves its weapon (feet origin, facing +x, pre-scale): the muzzle or arrow
## at head height, since ranged units now aim and fire from the shoulder and jaw.
const MUZZLE := {"musket": Vector2(36, -50), "rifle": Vector2(32, -50), "arcane_rifle": Vector2(32, -50),
	"rune_rifle": Vector2(32, -50), "crossbow": Vector2(27, -50), "bow": Vector2(22, -53), "starbow": Vector2(22, -53),
	"javelin": Vector2(20, -56), "throwing_axe": Vector2(20, -56), "sling": Vector2(10, -68)}

## How far into the attack the shot leaves the weapon (the default is the bow's and the guns': as the wind-up ends). The slinger
## lets go later, in the middle of the forward whip, once the stone has been whirled up to speed.
const RELEASE := {"sling": 0.46}
const RELEASE_DEFAULT := 0.35

## The sling: cord and pouch from the hand to the stone (px × build), the angle the stone is let go at (rad, y down: just before
## the top of the circle, where it is travelling forward and up), the whole turns it makes on top of the way round to that
## angle, and the angle it starts from (hanging below the hand).
const SLING_R := 15.0
const SLING_LET_GO := deg_to_rad(-112.0)
const SLING_TURNS := 1.0
const SLING_START := PI * 0.5

## A long gun's butt relative to the trigger hand (× build, along the gun): it sits in the shoulder.
const GUN_BUTT := Vector2(-6, -1)

## Hand-weapon lengths from the grip to the tip, px × build.
const LENGTH := {"club": 20.0, "gladius": 16.0, "axe": 20.0, "hammer": 20.0, "rune_hammer": 21.0, "leafblade": 22.0, "baton": 18.0}


static func weapon_length(kind: String) -> float:
	return LENGTH.get(kind, 22.0)


## Side a bladed head's edge faces: the leading side of the figure's forward/downward strike.
static func edge_normal(dir: Vector2) -> Vector2:
	return -dir.orthogonal()


## How far into the attack (0..1) this weapon's shot leaves it.
static func release(kind: String) -> float:
	return RELEASE.get(kind, RELEASE_DEFAULT)


## The sling at attack progress `atk` (0..1) for a hand at `hand`; `carried` is where the pouch hangs when it is not being swung
## and `kx` how much the camera squeezes horizontal distances (cos of its yaw). The pouch is carried up into a whirl over the
## head that speeds up until the release (RELEASE.sling), then swings on over the top and down, and settles back into the
## carried pose. Returns {pouch, theta, speed (rad per unit of atk), loaded (the stone is in it), hold (0..1, how much the
## far hand has the pouch)}.
static func sling_pose(atk: float, hand: Vector2, carried: Vector2, b: float, kx: float) -> Dictionary:
	var rel: float = RELEASE.sling
	var r := SLING_R * b
	var let_go := SLING_LET_GO + TAU
	var total := let_go + TAU * SLING_TURNS - SLING_START
	if atk < rel:
		var s := clampf(atk / rel, 0.0, 1.0)
		var theta := SLING_START + total * pow(s, 1.7)
		var swing := hand + Vector2(cos(theta) * kx, sin(theta)) * r
		var lift := smoothstep(0.0, 0.25, s)
		return {"pouch": carried.lerp(swing, lift), "theta": theta, "speed": total * 1.7 * pow(s, 0.7) / rel, "loaded": true, "hold": 1.0 - lift}
	var u := clampf((atk - rel) / (1.0 - rel), 0.0, 1.0)
	# The empty sling carries on over the top and hangs, wobbling as it comes to rest, then goes back to the far hand.
	var fall := clampf(u / 0.5, 0.0, 1.0)
	var phi := let_go + deg_to_rad(202.0) * (1.0 - (1.0 - fall) * (1.0 - fall)) + deg_to_rad(14.0) * sin(u * 10.0) * (1.0 - u)
	var reach := r * lerpf(1.0, 0.82, fall)
	var hang := hand + Vector2(cos(phi) * kx, sin(phi)) * reach
	var back := smoothstep(0.65, 1.0, u)
	return {"pouch": hang.lerp(carried, back), "theta": phi, "speed": 0.0, "loaded": false, "hold": back}


## j = FkSkeleton.solve() joints (arms already offset to the drawn shoulders); s = FkUnits.swing(atk).
static func weapon(ci: CanvasItem, kind: String, j: Dictionary, b: float, s: float, atk: float, pal: Array, tm: Color, skin: Color, pose: Dictionary, t: float, lk: Dictionary) -> void:
	var wood := FkPaint.tint(Color("6b4a2b"), pose)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var g: Color = lk.glow
	var hand: Vector2 = j.hand_n
	var dirv: Vector2 = j.dir
	var en := edge_normal(dirv)
	if kind in CHOP:
		# Foreshortening: the weapon grows a little as the cut comes down toward the viewer.
		var bw: float = b * j.get("zoom", 1.0)
		var length := weapon_length(kind)
		var orth := dirv.orthogonal()
		var tip := hand + dirv * length * bw
		match kind:
			"club":
				ci.draw_line(hand, tip, wood, 4.5 * bw)
				ci.draw_circle(tip, 4.5 * bw, wood.darkened(0.2))
			"sword", "saber", "gladius", "spellsword":
				ci.draw_line(hand - orth * 3 * bw, hand + orth * 3 * bw, metal.darkened(0.4), 2.2 * bw)
				ci.draw_line(hand - dirv * 3 * bw, hand, wood.darkened(0.3), 2.4 * bw)
				ci.draw_line(hand, tip, metal.lightened(0.25), (3.6 if kind == "gladius" else 3.0) * bw)
				if kind == "spellsword":
					ci.draw_line(hand + dirv * 4 * bw, tip, Color(g, 0.55 + 0.3 * sin(t * 7.0)), 5.0 * bw)
					ci.draw_line(hand + dirv * 4 * bw, tip, Color(1, 1, 1, 0.9), 1.2 * bw)
			"leafblade":
				# Curved elven blade; the belly of the curve is the cutting edge.
				var pts := PackedVector2Array()
				for i in 7:
					var u := i / 6.0
					pts.append(hand + dirv * length * bw * u + en * sin(u * PI * 0.9) * 3.5 * bw)
				ci.draw_line(hand - orth * 2.5 * bw, hand + orth * 2.5 * bw, FkPaint.tint(Color("d9b25c"), pose), 1.8 * bw)
				ci.draw_polyline(pts, metal.lightened(0.3), 2.6 * bw)
			"shovel":
				ci.draw_line(hand, tip, wood, 3.0 * bw)
				FkPaint.ellipse(ci, tip, Vector2(4, 6) * bw, metal, dirv.angle())
			"baton":
				ci.draw_line(hand, tip, Color(0.15, 0.15, 0.2), 4.0 * bw)
				ci.draw_line(hand + dirv * 8, tip, Color(tm.lightened(0.6), 0.9), 2.5 * bw)
			"axe":
				# The bit sweeps out on the edge side, so the blade leads the chop.
				ci.draw_line(hand - dirv * 3 * bw, tip, wood, 2.8 * bw)
				var hd := hand + dirv * (length - 4) * bw
				FkPaint.shade_poly(ci, [hd + en * 1.5 * bw, hd + dirv * 5 * bw + en * 1.5 * bw, hd + dirv * 8 * bw + en * 7 * bw, hd + en * 6 * bw - dirv * 3 * bw], metal)
				ci.draw_line(hd + dirv * 8 * bw + en * 7 * bw, hd + en * 6 * bw - dirv * 3 * bw, metal.lightened(0.4), 1.2)
			"hammer", "rune_hammer":
				ci.draw_line(hand - dirv * 3 * bw, tip, wood if kind == "hammer" else Color(0.2, 0.18, 0.2), 2.8 * bw)
				var hc := tip - dirv * 2 * bw
				FkPaint.shade_poly(ci, [hc - orth * 6 * bw - dirv * 3.5 * bw, hc + orth * 6 * bw - dirv * 3.5 * bw, hc + orth * 6 * bw + dirv * 3.5 * bw, hc - orth * 6 * bw + dirv * 3.5 * bw], metal)
				if kind == "rune_hammer":
					ci.draw_line(hc - orth * 4 * bw, hc + orth * 4 * bw, Color(g, 0.7 + 0.3 * sin(t * 5.0)), 1.8 * bw)
					FkPaint.halo(ci, hc, 7 * bw, g, 0.35)
		return
	match kind:
		"spear", "halberd", "lance", "glaive":
			# Shaft along the stance's weapon angle: upright at rest (halberd, glaive), levelled to thrust.
			var length: float = {"spear": 26.0, "lance": 36.0, "halberd": 40.0, "glaive": 40.0}[kind]
			var back := hand - dirv * 20 * b
			var tip := hand + dirv * length * b
			# Head points in (along the shaft, toward the edge side) coordinates.
			var at := func(a: float, e: float) -> Vector2: return tip + (dirv * a + en * e) * b
			ci.draw_line(back, tip, wood, 2.6 * b)
			match kind:
				"halberd":
					FkPaint.poly(ci, [at.call(2.0, 0.0), at.call(-3.0, 8.0), at.call(-12.0, 8.0), at.call(-8.0, 0.0)], metal)
					FkPaint.poly(ci, [at.call(0.0, -1.5), at.call(10.0, 0.0), at.call(0.0, 1.5)], metal.lightened(0.2))
				"glaive":
					FkPaint.shade_poly(ci, [at.call(-2.0, -1.5), at.call(4.0, 3.5), at.call(14.0, 4.0), at.call(20.0, 0.0), at.call(8.0, -1.5)], metal.lightened(0.15))
					ci.draw_line(at.call(-2.0, -3.0), at.call(-2.0, 3.0), FkPaint.tint(Color("d9b25c"), pose), 1.8)
				_:
					FkPaint.poly(ci, [at.call(0.0, -2.6), at.call(8.0, 0.0), at.call(0.0, 2.6)], metal.lightened(0.2))
			if kind == "lance":
				ci.draw_line(back + dirv * 8, back + dirv * 14, tm, 4.0 * b)
			FkFigure.fist(ci, hand, dirv.angle(), b, skin, false)
		"javelin", "throwing_axe":
			if atk < 0.0 or atk < 0.4 or atk > 0.9:
				if kind == "javelin":
					ci.draw_line(hand - dirv * 14 * b, hand + dirv * 16 * b, wood, 2.2 * b)
					var h := hand + dirv * 16 * b
					FkPaint.poly(ci, [h - en * 2 * b, h + dirv * 6 * b, h + en * 2 * b], metal)
				else:
					ci.draw_line(hand + Vector2(-2, 6) * b, hand + Vector2(1, -10) * b, wood, 2.2 * b)
					FkPaint.poly(ci, [hand + Vector2(1, -10) * b, hand + Vector2(7, -13) * b, hand + Vector2(7, -5) * b, hand + Vector2(1, -7) * b], metal)
				FkFigure.fist(ci, hand, dirv.angle(), b, skin, false)
		"sling":
			_sling(ci, j, b, atk, pose, t)
		"bow", "starbow":
			# The far hand holds the bow at the throat; the near hand hooks and draws the string.
			var grip: Vector2 = j.hand_f
			# Hooked while standing ready and through the draw; after the release, or on the march, the
			# string runs straight between the limb tips.
			var standing: bool = pose.get("move", 1.0 if pose.get("moving", false) else 0.0) < 0.5
			var drawing := (atk >= 0.0 and atk < 0.35) or (atk < 0.0 and standing)
			var nock := hand if drawing else grip + Vector2(-1.5, 0) * b
			# On the release the bow leaps forward in the loose palm and tips over on its upper limb.
			var rel := clampf((atk - 0.35) / 0.45, 0.0, 1.0) if atk >= 0.35 else 0.0
			var tilt := sin(rel * PI) * 0.25
			# Carried on the march the bow leans forward — top limb ahead of the face, bottom limb trailing.
			if atk < 0.0:
				tilt += 0.5 * FkPaint.move_amount(pose)
			var leap := Vector2(sin(rel * PI) * 1.5, 0) * b
			# Tension: the further the string is drawn, the deeper the limbs bend and the more their tips pull
			# in toward the archer; loosed, they spring back.
			var pull := clampf((grip.x - nock.x) / (20.0 * b), 0.0, 1.0) if drawing else 0.0
			# Elves carry the tall recurved longbow.
			var tall: float = (23.0 if lk.long_hair else 19.0) * (1.0 - 0.07 * pull)
			var top := grip + Vector2(-2 - 4 * pull, -tall) * b
			var bot := grip + Vector2(-2 - 4 * pull, tall) * b
			var pts := PackedVector2Array()
			for i in 11:
				var u := i / 10.0
				var curl := (-2.5 if u < 0.08 or u > 0.92 else 0.0) if lk.long_hair else 0.0
				var q := top.lerp(bot, u) + Vector2((sin(u * PI) * (7 + 3 * pull) + curl) * b, 0)
				pts.append(grip + leap + (q - grip).rotated(tilt))
			var bow_col := wood if kind == "bow" else FkPaint.tint(Color("e8e4d4"), pose)
			ci.draw_polyline(pts, bow_col, 2.6 * b)
			if not drawing:
				nock = grip + leap + (nock - grip).rotated(tilt)
			ci.draw_polyline(PackedVector2Array([pts[0], nock, pts[pts.size() - 1]]), Color(0.9, 0.88, 0.8, 0.9), 1.0)
			if drawing:
				var head := Vector2(grip.x + 9 * b, nock.y)
				if kind == "starbow":
					ci.draw_line(nock, head, Color(g, 0.9), 2.0)
					FkPaint.halo(ci, head, 4.0 * b, g, 0.6)
				else:
					ci.draw_line(nock, head, wood.lightened(0.3), 1.5)
			if atk >= 0.35 and atk < 0.7:
				var u := (atk - 0.35) / 0.35
				# The string shivers between the limb tips.
				for k in 2:
					var off := sin(u * 40.0 + k * 2.0) * (1.0 - u) * 1.6 * b
					ci.draw_line(pts[0] + Vector2(off, 0), pts[pts.size() - 1] + Vector2(off, 0), Color(0.9, 0.88, 0.8, 0.35 * (1.0 - u)), 1.0)
				if u < 0.5:
					# The arrow's flight streaks away level from the bow.
					var y := grip.y - 1.5 * b
					for k in 3:
						var x0 := grip.x + (6.0 + u * 30.0) * b
						ci.draw_line(Vector2(x0, y + (k - 1) * 1.2 * b), Vector2(x0 + (14.0 + k * 6.0) * b, y + (k - 1) * 1.2 * b),
							Color(1, 1, 0.95, 0.6 * (1.0 - u * 2.0)), 1.0)
				if u < 0.6:
					# Release lines framing the drawing hand's snap back along the neck.
					for k in 3:
						var d := Vector2(-1, 0).rotated((k - 1) * 0.5)
						ci.draw_line(hand + d * (3.5 + u * 4.0) * b, hand + d * (6.5 + u * 8.0) * b, Color(1, 1, 0.95, 0.7 * (1.0 - u / 0.6)), 1.0)
			# A relaxed hold on the riser, knuckles at 45 degrees.
			FkFigure.fist(ci, grip + leap, -PI / 4, b, skin, false)
		"staff":
			# Staff held in both hands; on the attack it is thrust forward and the head flares.
			var fw := maxf(0.0, s)
			var top := hand + dirv * 30 * b
			ci.draw_line(hand - dirv * 22 * b, top, FkPaint.tint(Color("a88a5a"), pose), 2.4 * b)
			ci.draw_arc(top + Vector2(0, -3) * b, 4.0 * b, PI * 0.2, PI * 1.8, 10, FkPaint.tint(Color("d9b25c"), pose), 1.2 * b)
			var k := 0.6 + 0.4 * sin(t * 3.0) + fw
			FkPaint.halo(ci, top + Vector2(0, -3) * b, 6.0 * b * (1.0 + fw), g, minf(1.0, k))
			ci.draw_circle(top + Vector2(0, -3) * b, 2.2 * b, Color(1, 1, 1, 0.95))
			FkFigure.fist(ci, hand, dirv.angle(), b, skin, false)
		"crossbow", "musket", "rifle", "arcane_rifle", "rune_rifle":
			# Stock at the shoulder, both hands on the gun; the stance's recoil moves and tilts it.
			var rot := dirv.angle()
			var stock := hand + GUN_BUTT.rotated(rot) * b
			var at := func(x: float, y: float) -> Vector2: return stock + Vector2(x, y).rotated(rot) * b
			if kind == "crossbow":
				ci.draw_line(stock, at.call(24.0, -1.5), wood, 3.6 * b)
				var bend := 3.0 if atk < 0.0 or atk > 0.45 else 1.0
				var prod: Vector2 = at.call(22.0, -1.5)
				var up: Vector2 = at.call(22.0 - bend, -10.5)
				var down: Vector2 = at.call(22.0 - bend, 7.5)
				ci.draw_polyline(PackedVector2Array([up, prod, down]), metal.darkened(0.2), 2.0 * b)
				var nut: Vector2 = at.call(8.0 if atk < 0.0 or atk > 0.45 else 18.0, -2.0)
				ci.draw_polyline(PackedVector2Array([up, nut, down]), Color(0.9, 0.88, 0.8, 0.8), 0.9)
				if atk < 0.0 or atk > 0.6:
					ci.draw_line(nut, at.call(25.0, -1.5), wood.lightened(0.3), 1.4)
			else:
				var length: float = {"musket": 34.0, "rifle": 30.0, "arcane_rifle": 30.0, "rune_rifle": 30.0}[kind]
				var arcane := kind in ["arcane_rifle", "rune_rifle"]
				ci.draw_line(stock, at.call(12.0, 0.0), wood, 5.0 * b)
				var barrel := metal.darkened(0.3) if not arcane else FkPaint.tint(Color("b8914a") if kind == "arcane_rifle" else Color("4a4a54"), pose)
				ci.draw_line(at.call(8.0, -1.0), at.call(length, -2.0), barrel, 3.0 * b)
				if arcane:
					ci.draw_line(at.call(12.0, -3.5), at.call(24.0, -3.5), Color(g, 0.6 + 0.4 * sin(t * 8.0)), 2.0 * b)
					FkPaint.ellipse(ci, at.call(12.0, 1.5), Vector2(2.4, 2.4) * b, Color(g, 0.9))
					for i in 3:
						ci.draw_line(at.call(16.0 + i * 4, -2.5), at.call(16.0 + i * 4, 0.5), metal.lightened(0.2), 1.0)
			FkFigure.fist(ci, hand, dirv.angle(), b, skin, false)


## A cord from a to c with a little sag, dark outlined so it reads against any backdrop.
static func _cord(ci: CanvasItem, a: Vector2, c: Vector2, sag: float, b: float, pose: Dictionary, alpha := 1.0) -> void:
	var chord := a.lerp(c, 0.5)
	var mid := chord + Vector2(0, sag * b)
	var pts := PackedVector2Array([a, a.lerp(mid, 0.5), mid, mid.lerp(c, 0.5), c])
	ci.draw_polyline(pts, Color(0.1, 0.08, 0.05, 0.55 * alpha), 2.6)
	ci.draw_polyline(pts, Color(FkPaint.tint(Color("dcc79c"), pose), alpha), 1.3)


## The sling: braided cords and a leather pouch that drapes between the hands, is whirled overhead through the wind-up (a stone in
## the pouch, a blur behind it that grows with its speed), lets the stone go as the arm whips forward, and swings on empty.
static func _sling(ci: CanvasItem, j: Dictionary, b: float, atk: float, pose: Dictionary, t: float) -> void:
	var hand: Vector2 = j.hand_n
	var other: Vector2 = j.hand_f
	var sway := sin(pose.get("walk", 0.0) * 2.0 + t) * 2.0 * b
	var carried := hand.lerp(other, 0.5) + Vector2(sway, 6.0 * b)
	var pouch := carried
	var hold := 1.0
	var loaded := true
	var spin := 0.0
	var theta := 0.0
	var kx := cos(j.get("yaw", 0.0))
	if atk >= 0.0:
		var sp := sling_pose(atk, hand, carried, b, kx)
		pouch = sp.pouch
		hold = sp.hold
		loaded = sp.loaded
		spin = sp.speed
		theta = sp.theta
	# The blur behind a stone in the whirl: the faster it goes, the longer the arc.
	var span := clampf(spin * 0.045, 0.0, 2.4)
	if loaded and span > 0.15:
		var r := (pouch - hand).length()
		var arc := PackedVector2Array()
		var n := 12
		for i in n + 1:
			var a := theta - span * i / n
			arc.append(hand + Vector2(cos(a) * kx, sin(a)) * r)
		ci.draw_polyline(arc, Color(0.1, 0.08, 0.05, 0.22), 4.0)
		for i in n:
			var f := float(i) / n
			ci.draw_line(arc[i], arc[i + 1], Color(0.97, 0.93, 0.8, 0.75 * (1.0 - f)), lerpf(2.6, 0.6, f))
	# The far hand holds the pouch until the whirl starts, and takes the ends back after the throw.
	_cord(ci, hand, pouch, 0.0 if atk < 0.0 or loaded else 2.5, b, pose)
	if atk < 0.0 or not loaded:
		_cord(ci, hand + Vector2(1.2, 1.0) * b, pouch, 3.5 if loaded else 5.0, b, pose, 0.9)
	if hold > 0.02:
		_cord(ci, pouch, other, 2.0, b, pose, hold)
	var tilt := (pouch - hand).angle() + PI * 0.5
	var leather := FkPaint.tint(Color("8a6a45"), pose)
	FkPaint.ellipse(ci, pouch, Vector2(3.8, 2.7) * b, Color(0.1, 0.08, 0.05, 0.7), tilt)
	FkPaint.ellipse(ci, pouch, Vector2(3.0, 2.0) * b, leather, tilt)
	if loaded:
		ci.draw_circle(pouch, 3.4 * b, Color(0.1, 0.08, 0.05, 0.8))
		ci.draw_circle(pouch, 2.6 * b, FkPaint.tint(Color("cfc9b8"), pose))
		ci.draw_circle(pouch + Vector2(-0.8, -0.8) * b, 0.9 * b, Color(1, 1, 1, 0.8))
