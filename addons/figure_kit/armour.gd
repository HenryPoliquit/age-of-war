class_name FkArmour
extends RefCounted
## Worn gear: helmets and hoods, shields, back packs (quivers, powder kegs, satchels).


const ENCLOSED := ["greathelm", "visor", "hood", "rune"]

## Distance (× build) from a shield's grip up to its top rim, per shield kind — so a stance can hold
## any shield with its rim just under the eyes.
const SHIELD_TOP := {"round": 10.5, "kite": 10.0, "hide": 10.0, "scutum": 16.0, "leaf": 17.0, "moon": 17.0,
	"dwarf": 12.5, "plate": 14.0, "energy": 16.0}


static func pack(ci: CanvasItem, kind: String, sh: Vector2, hip: Vector2, b: float, pal: Array, tm: Color, pose: Dictionary, t: float, lk: Dictionary) -> void:
	var back := sh + Vector2(-8, 4) * b
	match kind:
		"quiver", "javelins":
			var leather := FkPaint.tint(Color("6b4a2b"), pose)
			FkPaint.poly(ci, [back + Vector2(-3, -6) * b, back + Vector2(3, -8) * b, back + Vector2(1, 16) * b, back + Vector2(-5, 14) * b], leather)
			for i in 3:
				var tip := back + Vector2(-2 + i * 2.5, -16 - (i % 2) * 3) * b
				ci.draw_line(back + Vector2(-1 + i * 1.5, -4) * b, tip, FkPaint.tint(Color("c9b28a"), pose), 1.6 * b)
				if kind == "javelins":
					ci.draw_line(tip, tip + Vector2(0.5, -4) * b, FkPaint.tint(pal[2], pose), 2.2 * b)
		"axes":
			var metal: Color = FkPaint.tint(pal[2], pose)
			for i in 2:
				var h := back + Vector2(-2 + i * 3, -2 - i * 3) * b
				ci.draw_line(h + Vector2(0, 10) * b, h + Vector2(1, -8) * b, FkPaint.tint(Color("6b4a2b"), pose), 2.0 * b)
				FkPaint.poly(ci, [h + Vector2(1, -8) * b, h + Vector2(6, -11) * b, h + Vector2(6, -3) * b, h + Vector2(1, -5) * b], metal)
		"pouch":
			FkPaint.ellipse(ci, hip + Vector2(-7, -4) * b, Vector2(4.5, 5.5) * b, FkPaint.tint(Color("7a5a3a"), pose))
			FkPaint.ellipse(ci, back + Vector2(1, 2) * b, Vector2(4, 7) * b, FkPaint.tint(pal[1], pose).darkened(0.2))
		"backpack":
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 16) * b), FkPaint.tint(pal[1], pose).darkened(0.25))
			ci.draw_rect(Rect2(back + Vector2(-7, -6) * b, Vector2(10, 4) * b), FkPaint.tint(pal[1], pose).darkened(0.4))
		"cell":
			# Arcane power cell: brass casing with a glowing crystal core.
			var g: Color = lk.glow
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 16) * b), FkPaint.tint(Color(pal[2]).darkened(0.45), pose))
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 2) * b), FkPaint.tint(pal[2], pose))
			ci.draw_rect(Rect2(back + Vector2(-4, -1) * b, Vector2(4, 10) * b), Color(g, 0.6 + 0.3 * sin(t * 4.0)))


static func helmet(ci: CanvasItem, kind: String, head: Vector2, b: float, pal: Array, tm: Color, pose: Dictionary, t: float, seed: int, hair: Color, lk: Dictionary) -> void:
	var metal: Color = FkPaint.tint(pal[2], pose)
	var gold := FkPaint.tint(Color("d9b25c"), pose)
	match kind:
		"hair":
			FkPaint.ellipse(ci, head + Vector2(-1.5, -3) * b, Vector2(7, 4.5) * b, hair)
			FkPaint.ellipse(ci, head + Vector2(-5, 1) * b, Vector2(3, 5) * b, hair)
		"band":
			FkPaint.ellipse(ci, head + Vector2(-1.5, -3) * b, Vector2(7, 4) * b, hair)
			ci.draw_line(head + Vector2(-7, -2) * b, head + Vector2(7, -2) * b, tm, 2.5 * b)
		"cap":
			FkPaint.ellipse(ci, head + Vector2(0, -3.5) * b, Vector2(7.5, 4.5) * b, FkPaint.tint(pal[1], pose))
		"crest":
			FkPaint.ellipse(ci, head + Vector2(0, -2) * b, Vector2(7.8, 6.5) * b, metal)
			ci.draw_rect(Rect2(head + Vector2(1, -2) * b, Vector2(6, 7) * b), metal.darkened(0.25))
			# Plume lags behind the head (secondary motion).
			var lag := sin(t * 5.0) * 1.5
			for i in 5:
				ci.draw_circle(head + Vector2(-2.5 - i * 2.6, -9.5 + i * 0.7 + lag * i * 0.2) * b, (3.4 - i * 0.35) * b, tm)
		"galea":
			# Roman helmet: bowl, brow ridge, neck guard, cheek plate and a short brush crest.
			FkPaint.shade_poly(ci, FkPaint.ellipse_pts(head + Vector2(-0.5, -3) * b, Vector2(7.4, 5.8) * b, 0.0, 16), metal)
			FkPaint.poly(ci, [head + Vector2(-7.5, -1) * b, head + Vector2(-5, 1) * b, head + Vector2(-9.5, 4) * b, head + Vector2(-11, 3) * b], metal.darkened(0.2))
			FkPaint.poly(ci, [head + Vector2(1.5, -1) * b, head + Vector2(5, -1) * b, head + Vector2(4, 5) * b, head + Vector2(1.5, 5.5) * b], metal.darkened(0.12))
			ci.draw_line(head + Vector2(-6, -2) * b, head + Vector2(7, -2.4) * b, gold, 1.3 * b)
			for i in 6:
				ci.draw_line(head + Vector2(-5 + i * 1.8, -7.5) * b, head + Vector2(-5.6 + i * 1.8, -12.5 - sin(t * 4.0 + i) * 0.4) * b, tm, 2.0 * b)
		"conical":
			# Spangenhelm: tall cone, nasal and a mail aventail.
			FkPaint.shade_poly(ci, [head + Vector2(-7, -1) * b, head + Vector2(7, -1) * b, head + Vector2(1.5, -13) * b], metal)
			ci.draw_line(head + Vector2(4.8, -2) * b, head + Vector2(5.2, 3.2) * b, metal.darkened(0.2), 1.6 * b)
			FkPaint.poly(ci, [head + Vector2(-7, -1) * b, head + Vector2(-2, -1) * b, head + Vector2(-1, 7) * b, head + Vector2(-8, 6) * b], metal.darkened(0.3))
			ci.draw_line(head + Vector2(-7, -1.5) * b, head + Vector2(7, -1.5) * b, gold, 1.2 * b)
		"kettle":
			FkPaint.ellipse(ci, head + Vector2(0, -3) * b, Vector2(11, 2.5) * b, metal.darkened(0.15))
			FkPaint.ellipse(ci, head + Vector2(0, -5) * b, Vector2(6.5, 4.5) * b, metal)
		"greathelm":
			ci.draw_rect(Rect2(head + Vector2(-7, -8) * b, Vector2(14, 15) * b), metal)
			ci.draw_line(head + Vector2(0, -1) * b, head + Vector2(7, -1) * b, Color(0.1, 0.1, 0.1), 1.6 * b)
			for i in 3:
				ci.draw_circle(head + Vector2(-3 - i * 2.5, -10 - i) * b, 2.6 * b, tm)
		"morion":
			FkPaint.poly(ci, [head + Vector2(-11, -2) * b, head + Vector2(-6, -7) * b, head + Vector2(0, -12) * b, head + Vector2(6, -7) * b, head + Vector2(11, -2) * b], metal)
		"hood":
			FkPaint.ellipse(ci, head + Vector2(-1, -1) * b, Vector2(8, 8) * b, FkPaint.tint(Color(pal[0]).darkened(0.15), pose))
			ci.draw_circle(head + Vector2(2, 0.5) * b, 5.2 * b, FkPaint.tint(lk.skin[seed % lk.skin.size()], pose))
			ci.draw_circle(head + Vector2(3.6, -0.6) * b, 0.8 * b, Color(0.08, 0.06, 0.05))
		"tricorne":
			FkPaint.poly(ci, [head + Vector2(-10, -3) * b, head + Vector2(-3, -10) * b, head + Vector2(4, -10) * b, head + Vector2(10, -3) * b], Color(0.12, 0.12, 0.15))
			ci.draw_line(head + Vector2(-9, -3.5) * b, head + Vector2(9, -3.5) * b, pal[1], 1.5 * b)
		"visor":
			# Arcane sallet: swept tail and a glowing eye-slit.
			FkPaint.shade_poly(ci, [head + Vector2(-12, 1) * b, head + Vector2(-6, -8) * b, head + Vector2(3, -8.5) * b, head + Vector2(8, -2) * b,
				head + Vector2(7.5, 4) * b, head + Vector2(-3, 5) * b], metal)
			ci.draw_line(head + Vector2(-1, -1) * b, head + Vector2(8, -1) * b, Color(lk.glow, 0.95), 2.2 * b)
			ci.draw_line(head + Vector2(-6, -8) * b, head + Vector2(3, -8.5) * b, metal.lightened(0.25), 1.2 * b)
		"goggles":
			FkPaint.ellipse(ci, head + Vector2(-0.5, -3.5) * b, Vector2(7.2, 4.6) * b, FkPaint.tint(Color("5a3d28"), pose))
			ci.draw_line(head + Vector2(-6, -2.5) * b, head + Vector2(6, -2.5) * b, FkPaint.tint(Color("3a2a1c"), pose), 1.6 * b)
			ci.draw_circle(head + Vector2(3.5, -3.5) * b, 2.4 * b, metal)
			ci.draw_circle(head + Vector2(3.5, -3.5) * b, 1.5 * b, Color(lk.glow, 0.8))
		"leaf":
			# Elven helm: a smooth bowl sweeping back into a long leaf point, gilt edge.
			FkPaint.shade_poly(ci, [head + Vector2(6.5, -1) * b, head + Vector2(6.5, -4) * b, head + Vector2(1, -9) * b, head + Vector2(-5, -7) * b,
				head + Vector2(-17, -10) * b, head + Vector2(-9, -2.5) * b, head + Vector2(-6.5, 1) * b, head + Vector2(-2, -2) * b], metal)
			ci.draw_polyline(PackedVector2Array([head + Vector2(6.5, -1.5) * b, head + Vector2(-2, -2.5) * b, head + Vector2(-9, -1.5) * b, head + Vector2(-16, -8.5) * b]), gold, 1.0 * b)
			ci.draw_line(head + Vector2(-3, -7) * b, head + Vector2(-12, -6) * b, tm, 1.4 * b)
		"circlet":
			FkPaint.ellipse(ci, head + Vector2(-1.5, -3.5) * b, Vector2(7, 4.2) * b, hair)
			ci.draw_line(head + Vector2(-6.5, -2.5) * b, head + Vector2(6.5, -2.5) * b, gold, 1.3 * b)
			ci.draw_circle(head + Vector2(5.4, -2.6) * b, 1.3 * b, Color(lk.glow, 0.95))
		"antler":
			FkPaint.ellipse(ci, head + Vector2(-1.5, -3) * b, Vector2(7, 4.5) * b, hair)
			var bone := FkPaint.tint(Color("d8cbb0"), pose)
			ci.draw_polyline(PackedVector2Array([head + Vector2(-1, -6) * b, head + Vector2(-4, -12) * b, head + Vector2(-3, -18) * b]), bone, 1.4 * b)
			ci.draw_line(head + Vector2(-3.6, -11) * b, head + Vector2(0, -15) * b, bone, 1.2 * b)
			ci.draw_line(head + Vector2(-3.2, -15) * b, head + Vector2(-7, -18) * b, bone, 1.1 * b)
			ci.draw_line(head + Vector2(-6.5, -2) * b, head + Vector2(6.5, -2) * b, tm, 1.8 * b)
		"dwarf", "horned", "rune":
			# Dwarf helm: deep round bowl, heavy brim, nasal and cheek plates.
			FkPaint.shade_poly(ci, FkPaint.ellipse_pts(head + Vector2(-0.5, -3.5) * b, Vector2(7.6, 6.2) * b, 0.0, 16), metal)
			ci.draw_line(head + Vector2(-8, -1) * b, head + Vector2(7.5, -1) * b, metal.darkened(0.3), 2.4 * b)
			ci.draw_line(head + Vector2(4.8, -1) * b, head + Vector2(5.2, 3.5) * b, metal.darkened(0.15), 2.0 * b)
			FkPaint.rivets(ci, head + Vector2(-6.5, -1) * b, head + Vector2(4, -1) * b, 4, metal.lightened(0.35), 0.7 * b)
			ci.draw_line(head + Vector2(0, -9.6) * b, head + Vector2(-1, 0) * b, gold if kind != "rune" else metal.lightened(0.2), 1.2 * b)
			if kind == "horned":
				var horn := FkPaint.tint(Color("e2d6b8"), pose)
				FkPaint.shade_poly(ci, [head + Vector2(-4, -6) * b, head + Vector2(-2, -8) * b, head + Vector2(-8, -15) * b, head + Vector2(-13, -16) * b, head + Vector2(-9, -12) * b], horn)
			if kind == "rune":
				var g: Color = lk.glow
				ci.draw_polyline(PackedVector2Array([head + Vector2(-5, -4) * b, head + Vector2(-3, -7) * b, head + Vector2(-1, -4) * b, head + Vector2(1, -7) * b]),
					Color(g, 0.75 + 0.25 * sin(t * 3.0 + seed)), 1.2 * b)
				FkPaint.poly(ci, [head + Vector2(-2, -1) * b, head + Vector2(7.5, -1) * b, head + Vector2(7, 4) * b, head + Vector2(-1, 5) * b], metal.darkened(0.2))
				ci.draw_line(head + Vector2(2, 1) * b, head + Vector2(7, 1) * b, Color(g, 0.9), 1.4 * b)
		"brodie":
			FkPaint.ellipse(ci, head + Vector2(0, -4) * b, Vector2(10.5, 3) * b, FkPaint.tint(Color("5c5f4a"), pose))
			FkPaint.ellipse(ci, head + Vector2(0, -6) * b, Vector2(6, 3.5) * b, FkPaint.tint(Color("666a52"), pose))


## A shield held at the grip (`sh` + SHIELD_GRIP), turned toward the enemy: the face narrows to `turn`
## of its width about the grip, and the rim's thickness shows as a sliver on one edge. `back` shows the
## side facing the bearer (plain wood or leather, grip bar and straps, the painted face peeking around
## the rim) — what we see of a shield carried on the far arm; otherwise the painted face.
static func shield(ci: CanvasItem, kind: String, sh: Vector2, b: float, pal: Array, tm: Color, team: Color, pose: Dictionary, t: float, lk: Dictionary, runes := false, turn := 1.0, back := false) -> void:
	if kind == "":
		return
	if kind == "energy":
		# A translucent ward looks the same from either side.
		back = false
	var grip := sh + FkSkeleton.SHIELD_GRIP * b
	var edge := 2.2 * b * sqrt(maxf(0.0, 1.0 - turn * turn))
	var squash := func(dx: float) -> void:
		FkPaint.push(ci, Transform2D(0.0, grip + Vector2(dx, 0)) * Transform2D(0.0, Vector2(turn, 1.0), 0.0, Vector2.ZERO) * Transform2D(0.0, -grip))
	if back:
		# The painted face peeks around the leading rim; the bare back covers the rest.
		squash.call(edge)
		_face(ci, kind, sh, b, pal, tm, pose, t, lk, runes, false)
		FkPaint.pop(ci)
		squash.call(0.0)
		_face(ci, kind, sh, b, pal, FkPaint.tint(Color("6b4a2b"), pose), pose, t, lk, runes, true)
		var strap := FkPaint.tint(Color("3a2616"), pose)
		for y in [-4.0, 4.0]:
			ci.draw_line(grip + Vector2(-4, y) * b, grip + Vector2(4, y) * b, strap, 1.4 * b)
		ci.draw_line(grip + Vector2(0, -3) * b, grip + Vector2(0, 3) * b, strap.lightened(0.15), 2.0 * b)
		FkPaint.pop(ci)
	else:
		# The rim's thickness, behind the face.
		var metal: Color = FkPaint.tint(pal[2], pose)
		var dark := [metal.darkened(0.55), metal.darkened(0.55), metal.darkened(0.45)]
		squash.call(-edge)
		_face(ci, kind, sh, b, dark, metal.darkened(0.5), pose, t, lk, runes, true)
		FkPaint.pop(ci)
		squash.call(0.0)
		_face(ci, kind, sh, b, pal, tm, pose, t, lk, runes, false)
		FkPaint.pop(ci)


## One shield kind laid out around `sh` (grip at SHIELD_GRIP). `plain` leaves off the painted and
## fitted details (bosses, emblems, ribs, runes): the outline, rim and field only.
static func _face(ci: CanvasItem, kind: String, sh: Vector2, b: float, pal: Array, tm: Color, pose: Dictionary, t: float, lk: Dictionary, runes: bool, plain: bool) -> void:
	var metal: Color = FkPaint.tint(pal[2], pose)
	var g: Color = lk.glow
	match kind:
		"round":
			var c := sh + Vector2(7, 11) * b
			ci.draw_circle(c, 10.5 * b, metal.darkened(0.2))
			ci.draw_circle(c, 9 * b, tm)
			if not plain:
				ci.draw_circle(c, 2.5 * b, metal)
		"kite":
			var c := sh + Vector2(7, 9) * b
			FkPaint.poly(ci, [c + Vector2(-7, -8) * b, c + Vector2(7, -8) * b, c + Vector2(6, 4) * b, c + Vector2(0, 14) * b, c + Vector2(-6, 4) * b], metal.darkened(0.3))
			FkPaint.poly(ci, [c + Vector2(-5.5, -6.5) * b, c + Vector2(5.5, -6.5) * b, c + Vector2(4.5, 3.5) * b, c + Vector2(0, 11.5) * b, c + Vector2(-4.5, 3.5) * b], tm)
		"hide":
			var c := sh + Vector2(7, 12) * b
			FkPaint.ellipse(ci, c, Vector2(8.5, 11) * b, FkPaint.tint(Color("6e4a2c"), pose))
			FkPaint.ellipse(ci, c, Vector2(6.5, 9) * b, FkPaint.tint(Color("8d6a45"), pose))
			if not plain:
				ci.draw_line(c + Vector2(-5, -2) * b, c + Vector2(5, -2) * b, tm, 2.5 * b)
		"scutum":
			# Tall curved legion shield: team field, metal rim and boss, painted wings.
			var c := sh + Vector2(8, 10) * b
			FkPaint.shade_poly(ci, [c + Vector2(-5, -15) * b, c + Vector2(5, -14) * b, c + Vector2(6, 0) * b, c + Vector2(5, 14) * b, c + Vector2(-5, 15) * b, c + Vector2(-4, 0) * b], metal.darkened(0.25))
			FkPaint.shade_poly(ci, [c + Vector2(-3.8, -13.5) * b, c + Vector2(4, -12.5) * b, c + Vector2(4.8, 0) * b, c + Vector2(4, 12.5) * b, c + Vector2(-3.8, 13.5) * b, c + Vector2(-2.8, 0) * b], tm)
			if not plain:
				ci.draw_circle(c + Vector2(0.8, 0) * b, 3.0 * b, metal)
				ci.draw_line(c + Vector2(0.8, -11) * b, c + Vector2(0.8, 11) * b, Color(FkPaint.tint(Color("d9b25c"), pose), 0.8), 1.2 * b)
		"leaf":
			# Elven shield: a tall leaf of lacquered wood with a gilt rib.
			var c := sh + Vector2(7, 10) * b
			FkPaint.shade_poly(ci, [c + Vector2(0, -16) * b, c + Vector2(6.5, -6) * b, c + Vector2(6, 6) * b, c + Vector2(0, 16) * b, c + Vector2(-5.5, 6) * b, c + Vector2(-6, -6) * b], FkPaint.tint(Color("5a6a3a"), pose))
			FkPaint.shade_poly(ci, [c + Vector2(0, -13) * b, c + Vector2(4.8, -5) * b, c + Vector2(4.4, 5) * b, c + Vector2(0, 13) * b, c + Vector2(-4, 5) * b, c + Vector2(-4.4, -5) * b], tm)
			if not plain:
				ci.draw_line(c + Vector2(0, -14) * b, c + Vector2(0, 14) * b, FkPaint.tint(Color("d9b25c"), pose), 1.4 * b)
				for k in 3:
					ci.draw_line(c + Vector2(0, -6 + k * 5) * b, c + Vector2(3.5, -9 + k * 5) * b, FkPaint.tint(Color("d9b25c"), pose), 0.8)
		"moon":
			# Moonsilver leaf shield with a glowing rim.
			var c := sh + Vector2(7, 10) * b
			var pts := [c + Vector2(0, -16) * b, c + Vector2(6.5, -6) * b, c + Vector2(6, 6) * b, c + Vector2(0, 16) * b, c + Vector2(-5.5, 6) * b, c + Vector2(-6, -6) * b]
			FkPaint.shade_poly(ci, pts, metal)
			var ring := PackedVector2Array(pts)
			ring.append(pts[0])
			if not plain:
				ci.draw_polyline(ring, Color(g, 0.6 + 0.3 * sin(t * 4.0)), 1.6 * b)
				ci.draw_arc(c, 5 * b, -2.2, 1.0, 12, tm, 2.4 * b)
		"dwarf":
			# Big round dwarf shield: iron rim with rivets, team field, anvil boss.
			var c := sh + Vector2(6, 11) * b
			ci.draw_circle(c, 12.5 * b, metal.darkened(0.3))
			ci.draw_circle(c, 10.5 * b, tm.darkened(0.08))
			for k in 8:
				ci.draw_circle(c + Vector2.RIGHT.rotated(TAU * k / 8.0) * 11.5 * b, 0.9 * b, metal.lightened(0.3))
			if plain:
				return
			for k in 4:
				ci.draw_line(c, c + Vector2.RIGHT.rotated(TAU * k / 4.0 + 0.4) * 10 * b, tm.darkened(0.3), 1.4 * b)
			FkPaint.shade_poly(ci, FkPaint.ellipse_pts(c, Vector2(4, 4) * b), metal)
			if runes:
				ci.draw_arc(c, 7.5 * b, 0, TAU, 20, Color(g, 0.6 + 0.3 * sin(t * 3.0)), 1.2 * b)
		"plate":
			var c := sh + Vector2(8, 8) * b
			ci.draw_rect(Rect2(c + Vector2(-6, -11) * b, Vector2(12, 24) * b), metal.darkened(0.35))
			if not plain:
				ci.draw_rect(Rect2(c + Vector2(-2, -6) * b, Vector2(6, 2) * b), Color(0.05, 0.05, 0.05))
				ci.draw_rect(Rect2(c + Vector2(-6, 6) * b, Vector2(12, 3) * b), tm)
		"energy":
			# Arcane ward: a translucent hex pane on a brass bracer.
			var c := sh + Vector2(10, 10) * b
			var a := 0.3 + 0.1 * sin(t * 6.0)
			var hex := []
			for k in 6:
				hex.append(c + Vector2(cos(TAU * k / 6.0) * 7, sin(TAU * k / 6.0) * 15) * b)
			FkPaint.poly(ci, hex, Color(g, a))
			var ring := PackedVector2Array(hex)
			ring.append(hex[0])
			ci.draw_polyline(ring, Color(g.lightened(0.4), 0.9), 1.4)
			ci.draw_circle(c + Vector2(-5, 0) * b, 2.2 * b, metal)
