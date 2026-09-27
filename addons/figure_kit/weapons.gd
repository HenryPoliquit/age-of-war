class_name FkWeapons
extends RefCounted
## Hand weapons, drawn attached to the skeleton's solved hands (FkSkeleton.solve): chopping blades and
## hafts, polearms, throws, slings, bows, staves, crossbows and long guns. Also which projectile each
## one fires. The arms themselves are FkFigure's.


## Projectile per hand weapon (melee weapons fire nothing).
const SHOTS := {"sling": "stone", "javelin": "javelin", "throwing_axe": "axe", "bow": "arrow", "starbow": "bolt",
	"crossbow": "arrow", "musket": "bullet", "arcane_rifle": "bolt", "rune_rifle": "bolt", "staff": "bolt"}


const CHOP := ["club", "sword", "gladius", "shovel", "baton", "saber", "axe", "hammer", "leafblade", "spellsword", "rune_hammer"]

## Where a figure's shot leaves its weapon (feet origin, facing +x, pre-scale): the muzzle or arrow
## at head height, since ranged units now aim and fire from the shoulder and jaw.
const MUZZLE := {"musket": Vector2(34, -52), "rifle": Vector2(30, -52), "arcane_rifle": Vector2(30, -52),
	"rune_rifle": Vector2(30, -52), "crossbow": Vector2(26, -52), "bow": Vector2(22, -53), "starbow": Vector2(22, -53),
	"javelin": Vector2(20, -56), "throwing_axe": Vector2(20, -56), "sling": Vector2(18, -60)}

## Hand-weapon lengths from the grip to the tip, px × build.
const LENGTH := {"club": 20.0, "gladius": 16.0, "axe": 20.0, "hammer": 20.0, "rune_hammer": 21.0, "leafblade": 22.0, "baton": 18.0}


static func weapon_length(kind: String) -> float:
	return LENGTH.get(kind, 22.0)


## Side a bladed head's edge faces: the leading side of the figure's forward/downward strike.
static func edge_normal(dir: Vector2) -> Vector2:
	return -dir.orthogonal()


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
			if atk < 0.0:
				# Carried: the braided cords drape between both hands at chest level, the pouch swinging
				# with each bounce of the walk.
				var other: Vector2 = j.hand_f
				var sway := sin(pose.get("walk", 0.0) * 2.0 + t) * 2.0 * b
				var pouch := hand.lerp(other, 0.5) + Vector2(sway, 6.0 * b)
				var cord := Color("c9b28a")
				ci.draw_polyline(PackedVector2Array([hand, hand.lerp(pouch, 0.5) + Vector2(0, 1.5 * b), pouch]), cord, 1.2)
				ci.draw_polyline(PackedVector2Array([pouch, other.lerp(pouch, 0.5) + Vector2(0, 1.5 * b), other]), cord, 1.2)
				FkPaint.ellipse(ci, pouch, Vector2(2.4, 1.8) * b, Color("8a6a45"))
			else:
				var spin := t * (22.0 if atk < 0.4 else 5.0)
				var stone := hand + Vector2(cos(spin), sin(spin) * 0.5) * 10 * b
				ci.draw_line(hand, stone, Color("c9b28a"), 1.2)
				ci.draw_arc(hand, 10 * b, 0, TAU, 16, Color(0.8, 0.75, 0.6, 0.35), 1.5)
				if atk < 0.4 or atk > 0.9:
					ci.draw_circle(stone, 2.2 * b, Color("7b7466"))
		"bow", "starbow":
			# The far hand holds the bow out front; the near hand draws the string back.
			var grip: Vector2 = j.hand_f
			# Drawing (attacking): the string comes back to the near hand. Otherwise it runs straight.
			var drawing := atk >= 0.0 and atk < 0.35
			var nock := hand if drawing else grip + Vector2(-1.5, 0) * b
			# Elves carry the tall recurved longbow.
			var tall := 23.0 if lk.long_hair else 19.0
			var top := grip + Vector2(-2, -tall) * b
			var bot := grip + Vector2(-2, tall) * b
			var pts := PackedVector2Array()
			for i in 11:
				var u := i / 10.0
				var curl := (-2.5 if u < 0.08 or u > 0.92 else 0.0) if lk.long_hair else 0.0
				pts.append(top.lerp(bot, u) + Vector2((sin(u * PI) * 7 + curl) * b, 0))
			var bow_col := wood if kind == "bow" else FkPaint.tint(Color("e8e4d4"), pose)
			ci.draw_polyline(pts, bow_col, 2.6 * b)
			ci.draw_polyline(PackedVector2Array([pts[0], nock, pts[pts.size() - 1]]), Color(0.9, 0.88, 0.8, 0.9), 1.0)
			if drawing and atk < 0.35:
				var head := Vector2(grip.x + 9 * b, nock.y)
				if kind == "starbow":
					ci.draw_line(nock, head, Color(g, 0.9), 2.0)
					FkPaint.halo(ci, head, 4.0 * b, g, 0.6)
				else:
					ci.draw_line(nock, head, wood.lightened(0.3), 1.5)
			FkFigure.fist(ci, grip, -PI / 2, b, skin, false)
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
			var stock := hand + Vector2(-13, -2).rotated(rot) * b
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
