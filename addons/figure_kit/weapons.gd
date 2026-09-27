class_name FkWeapons
extends RefCounted
## Hand weapons and their attack motion: chopping blades and hafts, polearm thrusts, throws,
## slings, bows, staves, crossbows and long guns. Also which projectile each one fires.


## Projectile per hand weapon (melee weapons fire nothing).
const SHOTS := {"sling": "stone", "javelin": "javelin", "throwing_axe": "axe", "bow": "arrow", "starbow": "bolt",
	"crossbow": "arrow", "musket": "bullet", "arcane_rifle": "bolt", "rune_rifle": "bolt", "staff": "bolt"}


const CHOP := ["club", "sword", "gladius", "shovel", "baton", "saber", "axe", "hammer", "leafblade", "spellsword", "rune_hammer"]


static func weapon(ci: CanvasItem, kind: String, sh: Vector2, b: float, s: float, atk: float, pal: Array, tm: Color, skin: Color, pose: Dictionary, t: float, lk: Dictionary, armoured := false) -> void:
	var wood := FkPaint.tint(Color("6b4a2b"), pose)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var sleeve: Color = FkPaint.tint(pal[0], pose).lightened(0.12)
	var bracer: Color = metal if armoured else FkPaint.tint(Color("4a3322"), pose)
	var g: Color = lk.glow
	if kind in CHOP:
		# Overhead chop: arm angle from straight down (0) to overhead (~2.9 rad). Guard at 1.2 holds
		# the weapon out in front; the strike ends with the arm fully extended forward.
		var theta := 1.2
		if atk >= 0.0:
			if atk < 0.35:
				theta = lerpf(1.2, 2.9, ease(atk / 0.35, 0.6))
			elif atk < 0.5:
				theta = lerpf(2.9, 0.9, ease((atk - 0.35) / 0.15, 0.4))
			else:
				theta = lerpf(0.9, 1.2, (atk - 0.5) / 0.5)
		var length: float = {"club": 20.0, "gladius": 16.0, "axe": 20.0, "hammer": 20.0, "rune_hammer": 21.0, "leafblade": 22.0, "baton": 18.0}.get(kind, 22.0)
		var hand := sh + Vector2(0, 15 * b).rotated(-theta)
		var dirv := (hand - sh).normalized().rotated(-0.7)
		var orth := dirv.orthogonal()
		var tip := hand + dirv * length * b
		if atk >= 0.35 and atk < 0.55:
			# Smear along the tip's path from the wind-up, fading out after contact.
			var h0 := Vector2(0, 15 * b).rotated(-2.9)
			var t0 := h0 + h0.normalized().rotated(-0.7) * length * b
			ci.draw_arc(sh, (tip - sh).length(), t0.angle(), (tip - sh).angle(), 12, Color(metal.lightened(0.5), 0.45 * (0.55 - atk) / 0.2), 4.0 * b)
		FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
		match kind:
			"club":
				ci.draw_line(hand, tip, wood, 4.5 * b)
				ci.draw_circle(tip, 4.5 * b, wood.darkened(0.2))
			"sword", "saber", "gladius", "spellsword":
				ci.draw_line(hand - orth * 3 * b, hand + orth * 3 * b, metal.darkened(0.4), 2.2 * b)
				ci.draw_line(hand - dirv * 3 * b, hand, wood.darkened(0.3), 2.4 * b)
				ci.draw_line(hand, tip, metal.lightened(0.25), (3.6 if kind == "gladius" else 3.0) * b)
				if kind == "spellsword":
					ci.draw_line(hand + dirv * 4 * b, tip, Color(g, 0.55 + 0.3 * sin(t * 7.0)), 5.0 * b)
					ci.draw_line(hand + dirv * 4 * b, tip, Color(1, 1, 1, 0.9), 1.2 * b)
			"leafblade":
				# Curved elven blade.
				var pts := PackedVector2Array()
				for i in 7:
					var u := i / 6.0
					pts.append(hand + dirv * length * b * u - orth * sin(u * PI * 0.9) * 3.5 * b)
				ci.draw_line(hand - orth * 2.5 * b, hand + orth * 2.5 * b, FkPaint.tint(Color("d9b25c"), pose), 1.8 * b)
				ci.draw_polyline(pts, metal.lightened(0.3), 2.6 * b)
			"shovel":
				ci.draw_line(hand, tip, wood, 3.0 * b)
				FkPaint.ellipse(ci, tip, Vector2(4, 6) * b, metal, dirv.angle())
			"baton":
				ci.draw_line(hand, tip, Color(0.15, 0.15, 0.2), 4.0 * b)
				ci.draw_line(hand + dirv * 8, tip, Color(tm.lightened(0.6), 0.9), 2.5 * b)
			"axe":
				ci.draw_line(hand - dirv * 3 * b, tip, wood, 2.8 * b)
				var hd := hand + dirv * (length - 4) * b
				FkPaint.shade_poly(ci, [hd - orth * 1.5 * b, hd + dirv * 5 * b - orth * 1.5 * b, hd + dirv * 8 * b + orth * 7 * b, hd + orth * 6 * b - dirv * 3 * b], metal)
				ci.draw_line(hd + dirv * 8 * b + orth * 7 * b, hd + orth * 6 * b - dirv * 3 * b, metal.lightened(0.4), 1.2)
			"hammer", "rune_hammer":
				ci.draw_line(hand - dirv * 3 * b, tip, wood if kind == "hammer" else Color(0.2, 0.18, 0.2), 2.8 * b)
				var hc := tip - dirv * 2 * b
				FkPaint.shade_poly(ci, [hc - orth * 6 * b - dirv * 3.5 * b, hc + orth * 6 * b - dirv * 3.5 * b, hc + orth * 6 * b + dirv * 3.5 * b, hc - orth * 6 * b + dirv * 3.5 * b], metal)
				if kind == "rune_hammer":
					ci.draw_line(hc - orth * 4 * b, hc + orth * 4 * b, Color(g, 0.7 + 0.3 * sin(t * 5.0)), 1.8 * b)
					FkPaint.halo(ci, hc, 7 * b, g, 0.35)
		return
	match kind:
		"halberd", "glaive" when atk < 0.0:
			# At rest the polearm stands upright: a tall vertical line in silhouette.
			var hand := sh + Vector2(10, 8) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			ci.draw_line(hand + Vector2(0, 22) * b, hand + Vector2(0, -44) * b, wood, 2.8 * b)
			var top := hand + Vector2(0, -44) * b
			if kind == "halberd":
				FkPaint.poly(ci, [top + Vector2(0, -2), top + Vector2(8, 3), top + Vector2(8, 12), top + Vector2(0, 8)], metal)
				FkPaint.poly(ci, [top + Vector2(-1.5, 0), top + Vector2(0, -10), top + Vector2(1.5, 0)], metal.lightened(0.2))
			else:
				# Glaive: a long curved leaf blade.
				FkPaint.shade_poly(ci, [top + Vector2(-1.5, 2), top + Vector2(3.5, -4), top + Vector2(4, -14), top + Vector2(0, -20), top + Vector2(-1.5, -8)], metal.lightened(0.15))
				ci.draw_line(top + Vector2(-3, 2), top + Vector2(3, 2), FkPaint.tint(Color("d9b25c"), pose), 1.8)
			ci.draw_circle(hand, 3.2 * b, skin)
		"spear", "halberd", "lance", "glaive":
			# Thrust: pulled back, then driven forward.
			var reach := s * 13.0
			var hand := sh + Vector2(12 + reach, 9) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			var dirv := Vector2(1, -0.12).normalized()
			var back := hand - dirv * 20 * b
			var tip := hand + dirv * (26.0 if kind != "lance" else 36.0) * b
			ci.draw_line(back, tip, wood, 2.6 * b)
			if kind == "halberd":
				FkPaint.poly(ci, [tip + Vector2(-8, -2), tip + Vector2(-2, -9), tip + Vector2(0, -2), tip + Vector2(-2, 5)], metal)
			if kind == "glaive":
				FkPaint.poly(ci, [tip + Vector2(-2, -2.5) * b, tip + Vector2(14, -3) * b, tip + Vector2(4, 2.5) * b], metal.lightened(0.2))
			else:
				FkPaint.poly(ci, [tip + Vector2(0, -2.6) * b, tip + Vector2(8, 0) * b, tip + Vector2(0, 2.6) * b], metal.lightened(0.2))
			if kind == "lance":
				ci.draw_line(back + dirv * 8, back + dirv * 14, tm, 4.0 * b)
		"javelin", "throwing_axe":
			var ang := -0.9 + 1.4 * maxf(0.0, s)
			var hand := sh + Vector2(-2, -10 * b).rotated(ang) if s < 0.5 else sh + Vector2(10, 2) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			if atk < 0.0 or atk < 0.4 or atk > 0.9:
				if kind == "javelin":
					ci.draw_line(hand + Vector2(-14, 4) * b, hand + Vector2(16, -3) * b, wood, 2.2 * b)
					FkPaint.poly(ci, [hand + Vector2(16, -5) * b, hand + Vector2(22, -4) * b, hand + Vector2(16, -1) * b], metal)
				else:
					ci.draw_line(hand + Vector2(-2, 6) * b, hand + Vector2(1, -10) * b, wood, 2.2 * b)
					FkPaint.poly(ci, [hand + Vector2(1, -10) * b, hand + Vector2(7, -13) * b, hand + Vector2(7, -5) * b, hand + Vector2(1, -7) * b], metal)
		"sling":
			var hand := sh + Vector2(2, -14) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			var spin := t * (22.0 if atk >= 0.0 and atk < 0.4 else 5.0)
			var stone := hand + Vector2(cos(spin), sin(spin) * 0.5) * 10 * b
			ci.draw_line(hand, stone, Color("c9b28a"), 1.2)
			ci.draw_arc(hand, 10 * b, 0, TAU, 16, Color(0.8, 0.75, 0.6, 0.35), 1.5)
			if atk < 0.4 or atk > 0.9:
				ci.draw_circle(stone, 2.2 * b, Color("7b7466"))
		"bow", "starbow":
			var draw_back := clampf(-s, 0.0, 1.0) * 9.0
			var hand := sh + Vector2(15, 1) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			# Elves carry the tall recurved longbow.
			var tall := 23.0 if lk.long_hair else 19.0
			var top := hand + Vector2(-2, -tall) * b
			var bot := hand + Vector2(-2, tall) * b
			var pts := PackedVector2Array()
			for i in 11:
				var u := i / 10.0
				var curl := (-2.5 if u < 0.08 or u > 0.92 else 0.0) if lk.long_hair else 0.0
				pts.append(top.lerp(bot, u) + Vector2((sin(u * PI) * 7 + curl) * b, 0))
			var bow_col := wood if kind == "bow" else FkPaint.tint(Color("e8e4d4"), pose)
			ci.draw_polyline(pts, bow_col, 2.6 * b)
			var nock := hand + Vector2(-4 - draw_back, 0) * b
			ci.draw_polyline(PackedVector2Array([pts[0], nock, pts[pts.size() - 1]]), Color(0.9, 0.88, 0.8, 0.9), 1.0)
			FkFigure.arm(ci, sh + Vector2(-1, 1), nock, b, sleeve.darkened(0.15), skin, bracer)
			if atk < 0.35:
				if kind == "starbow":
					ci.draw_line(nock, nock + Vector2(24, 0) * b, Color(g, 0.9), 2.0)
					FkPaint.halo(ci, nock + Vector2(24, 0) * b, 4.0 * b, g, 0.6)
				else:
					ci.draw_line(nock, nock + Vector2(24, 0) * b, wood.lightened(0.3), 1.5)
			ci.draw_circle(hand, 3.2 * b, skin)
		"staff":
			# Staff held upright; on the attack it is thrust forward and the head flares.
			var fw := maxf(0.0, s)
			var hand := sh + Vector2(10 + fw * 5, 6 - fw * 6) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			var top := hand + Vector2(4 + fw * 8, -30) * b
			ci.draw_line(hand + Vector2(-2, 22) * b, top, FkPaint.tint(Color("a88a5a"), pose), 2.4 * b)
			ci.draw_arc(top + Vector2(0, -3) * b, 4.0 * b, PI * 0.2, PI * 1.8, 10, FkPaint.tint(Color("d9b25c"), pose), 1.2 * b)
			var k := 0.6 + 0.4 * sin(t * 3.0) + fw
			FkPaint.halo(ci, top + Vector2(0, -3) * b, 6.0 * b * (1.0 + fw), g, minf(1.0, k))
			ci.draw_circle(top + Vector2(0, -3) * b, 2.2 * b, Color(1, 1, 1, 0.95))
			ci.draw_circle(hand, 3.2 * b, skin)
		"crew":
			# Hands forward on the engine.
			var hand := sh + Vector2(14, 8) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
		"crossbow":
			var kick := maxf(0.0, s) * 2.0
			var hand := sh + Vector2(12 - kick, 1) * b
			var stock := sh + Vector2(-1 - kick, -1) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			ci.draw_line(stock, stock + Vector2(24, -1.5) * b, wood, 3.6 * b)
			var prod := stock + Vector2(22, -1.5) * b
			var bend := 3.0 if atk < 0.0 or atk > 0.45 else 1.0
			ci.draw_polyline(PackedVector2Array([prod + Vector2(-bend, -9) * b, prod, prod + Vector2(-bend, 9) * b]), metal.darkened(0.2), 2.0 * b)
			var nut := stock + Vector2(8 if atk < 0.0 or atk > 0.45 else 18, -2) * b
			ci.draw_polyline(PackedVector2Array([prod + Vector2(-bend, -9) * b, nut, prod + Vector2(-bend, 9) * b]), Color(0.9, 0.88, 0.8, 0.8), 0.9)
			if atk < 0.0 or atk > 0.6:
				ci.draw_line(nut, prod + Vector2(3, 0) * b, wood.lightened(0.3), 1.4)
			ci.draw_circle(hand, 3.2 * b, skin)
		"musket", "rifle", "arcane_rifle", "rune_rifle":
			var kick := maxf(0.0, s) * 4.0
			var hand := sh + Vector2(12 - kick, 1) * b
			var stock := sh + Vector2(-1 - kick, -1) * b
			FkFigure.arm(ci, sh + Vector2(2, 1), hand, b, sleeve, skin, bracer)
			var length: float = {"musket": 34.0, "rifle": 30.0, "arcane_rifle": 30.0, "rune_rifle": 30.0}[kind]
			var muzzle := stock + Vector2(length, -2) * b
			var arcane := kind in ["arcane_rifle", "rune_rifle"]
			ci.draw_line(stock, stock + Vector2(12, 0) * b, wood, 5.0 * b)
			var barrel := metal.darkened(0.3) if not arcane else FkPaint.tint(Color("b8914a") if kind == "arcane_rifle" else Color("4a4a54"), pose)
			ci.draw_line(stock + Vector2(8, -1) * b, muzzle, barrel, 3.0 * b)
			if arcane:
				ci.draw_line(stock + Vector2(12, -3.5) * b, stock + Vector2(24, -3.5) * b, Color(g, 0.6 + 0.4 * sin(t * 8.0)), 2.0 * b)
				FkPaint.ellipse(ci, stock + Vector2(12, 1.5) * b, Vector2(2.4, 2.4) * b, Color(g, 0.9))
				for i in 3:
					ci.draw_line(stock + Vector2(16 + i * 4, -2.5) * b, stock + Vector2(16 + i * 4, 0.5) * b, metal.lightened(0.2), 1.0)
			ci.draw_circle(hand, 3.2 * b, skin)
