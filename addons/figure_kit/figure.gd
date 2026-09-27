class_name FkFigure
extends RefCounted
## Human figure rig: legs, torso, head (hair, beard, ears), the weapon arm and the offset/crew
## variants used by riders and machine crews. Local space: feet at y = 0, facing +x, up is −y.


## Near (weapon) arm from solved joints: inked upper arm and bracered forearm, then the hand, so it
## reads over the body.
static func arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, hand_angle: float, b: float, sleeve: Color, skin: Color, bracer: Color) -> void:
	var ink := Color(0.08, 0.06, 0.05)
	FkPaint.seg(ci, shoulder, elbow, 7.8 * b, 7.0 * b, ink)
	FkPaint.seg(ci, elbow, hand, 7.0 * b, 6.0 * b, ink)
	FkPaint.seg(ci, shoulder, elbow, 5.4 * b, 4.6 * b, sleeve)
	FkPaint.seg(ci, elbow, hand, 4.6 * b, 3.8 * b, bracer)
	fist(ci, hand, hand_angle, b, skin)


## A closed hand turned to `angle` (the grip's direction): knuckles lead, so wrist turns read.
## Without ink it is the fingers drawn back over a haft the hand holds.
static func fist(ci: CanvasItem, p: Vector2, angle: float, b: float, skin: Color, ink := true) -> void:
	if ink:
		FkPaint.ellipse(ci, p, Vector2(4.0, 3.3) * b, Color(0.08, 0.06, 0.05), angle, 12)
	FkPaint.ellipse(ci, p, Vector2(3.2, 2.5) * b, skin, angle, 12)
	var fwd := Vector2.from_angle(angle)
	ci.draw_line(p + fwd * 1.6 * b - fwd.orthogonal() * 1.8 * b, p + fwd * 1.6 * b + fwd.orthogonal() * 1.8 * b, skin.darkened(0.3), 0.8 * b)


## Shoulder cap over the arm's root, turned with the upper arm, so the shoulder's own motion reads.
static func shoulder_cap(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, b: float, col: Color) -> void:
	var ang := (elbow - shoulder).angle()
	var c := shoulder + Vector2.from_angle(ang) * 1.5 * b
	FkPaint.ellipse(ci, c, Vector2(4.2, 3.3) * b, col.darkened(0.4), ang, 12)
	FkPaint.ellipse(ci, c + Vector2(0, -0.4) * b, Vector2(3.5, 2.6) * b, col, ang, 12)


static func humanoid(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, scale := 1.0, legs := true) -> void:
	var pal: Array = st.palette
	var team: Color = st.team
	var lk: Dictionary = st.look
	var body: Vector2 = lk.body
	var build: float = st.get("build", 1.0) * scale
	var mv := FkPaint.move_amount(pose)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var skins: Array = lk.skin
	var hairs: Array = lk.hair
	var skin: Color = FkPaint.tint(skins[seed % skins.size()], pose)
	var hair: Color = FkPaint.tint(hairs[(seed / 3) % hairs.size()], pose)
	var cloth: Color = FkPaint.tint(pal[0], pose)
	var trim: Color = FkPaint.tint(pal[1], pose)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var tm: Color = FkPaint.tint(team, pose)
	var helmet: String = st.get("helmet", "")
	var armoured: bool = helmet in ["crest", "kettle", "greathelm", "morion", "visor", "galea", "conical", "leaf", "dwarf", "horned", "rune"]
	var leather := FkPaint.tint(Color("4a3322"), pose)
	var weapon: String = st.get("weapon", "none")
	# One skeleton per frame; the idle-breath phase is offset per individual (as the old bob was).
	var j := FkSkeleton.solve(build, weapon, pose.merged({"t": t + seed / 2.1}, true), st.get("shield", "") != "", not legs)
	var hip: Vector2 = j.hip
	var sh: Vector2 = j.sh
	var b := build
	# Race proportions scale legs and torso about the feet (or the hip for riders); head and arms
	# keep their own proportions so a dwarf reads broad, not squashed. Arm joints follow the scaled
	# shoulder by a plain offset; `unmap` takes them back into the scaled space for the far arm.
	var pivot := Vector2.ZERO if legs else hip
	var off: Vector2 = (pivot + (j.sh_n - pivot) * body) - (j.sh_n as Vector2)
	var jn := j.duplicate()
	for key in ["sh_n", "sh_f", "elbow_n", "hand_n", "elbow_f", "hand_f"]:
		jn[key] = (j[key] as Vector2) + off
	jn["sh"] = pivot + (sh - pivot) * body
	var unmap := func(p: Vector2) -> Vector2: return pivot + (p - pivot) / body
	FkPaint.push(ci, Transform2D(0.0, pivot) * Transform2D(0.0, body, 0.0, Vector2.ZERO) * Transform2D(0.0, -pivot))
	if legs:
		FkPaint.shadow(ci, 12 * b)
	# Far leg (darker), then the near one; a rider shows only the near leg, its foot in the stirrup.
	for i in ([1, 0] if legs else [0]):
		var tag := "n" if i == 0 else "f"
		var knee: Vector2 = j["knee_" + tag]
		var foot: Vector2 = j["foot_" + tag]
		var back := 0.22 if i == 1 else 0.0
		FkPaint.seg(ci, hip, knee, 7.2 * b, 5.4 * b, trim.darkened(back))
		FkPaint.seg(ci, knee, foot, 5.4 * b, 4.2 * b, trim.darkened(back + 0.08))
		if armoured:
			FkPaint.seg(ci, knee.lerp(foot, 0.1), foot + Vector2(0, -2 * b), 5.8 * b, 4.8 * b, metal.darkened(back))
			ci.draw_circle(knee, 3.2 * b, metal.darkened(back - 0.1))
		# Boot: heel, sole and toe — pointing forward, rolling heel to toe with the stride.
		var boot := FkSkeleton.boot(foot, j["rot_" + tag], b)
		FkPaint.shade_poly(ci, boot, leather.darkened(back))
		ci.draw_line(boot[5], boot[4], Color(0.08, 0.06, 0.05), 1.2 * b)
	# Cape trails behind and lags the body (secondary motion).
	if st.get("cape", false) or helmet == "greathelm":
		var flap := sin(t * 3.0 + seed) * 2.0 + mv * 3.0
		FkPaint.shade_poly(ci, [sh + Vector2(-6, 0) * b, sh + Vector2(2, 1) * b, hip + Vector2(-2, 8) * b,
			hip + Vector2(-12 - flap, 10) * b, hip + Vector2(-9 - flap * 0.5, -2) * b], tm.darkened(0.35))
	FkArmour.pack(ci, st.get("pack", ""), sh, hip, build, pal, tm, pose, t, lk)
	# Far arm, behind the body: counter-swings, carries the shield, or holds the bow / the weapon's haft.
	var fs: Vector2 = unmap.call(jn.sh_f)
	var fe: Vector2 = unmap.call(jn.elbow_f)
	var fh: Vector2 = unmap.call(jn.hand_f)
	FkPaint.seg(ci, fs, fe, 5.0 * b, 4.2 * b, cloth.darkened(0.3))
	FkPaint.seg(ci, fe, fh, 4.2 * b, 3.4 * b, cloth.darkened(0.34))
	fist(ci, fh, (fh - fe).angle(), b * 0.85, skin.darkened(0.25), false)
	# Torso: hips, waist, chest, shoulders.
	var torso := [hip + Vector2(-6.5, 3) * b, hip + Vector2(7, 3) * b, hip + Vector2(6, -8) * b, sh + Vector2(8.5, 5) * b,
		sh + Vector2(7.5, -1.5) * b, sh + Vector2(-7.5, -1.5) * b, sh + Vector2(-8, 5) * b, hip + Vector2(-5.5, -8) * b]
	FkPaint.shade_poly(ci, torso, cloth)
	if armoured:
		# Breastplate / hauberk; Roman plate reads as horizontal bands, the rest as mail rows.
		FkPaint.shade_poly(ci, [hip + Vector2(-5.5, -5) * b, hip + Vector2(6.5, -5) * b, sh + Vector2(8, 4) * b, sh + Vector2(6, -0.5) * b,
			sh + Vector2(-6, -0.5) * b, sh + Vector2(-7, 4) * b], metal)
		var bands := helmet == "galea"
		for r in 4:
			var y := -1.0 - r * 3.4
			ci.draw_line(hip + Vector2(-4.5, y) * b, hip + Vector2(6, y) * b, Color(metal.darkened(0.45), 0.8 if bands else 0.5), (1.4 if bands else 0.8) * b)
		if helmet == "leaf":
			# Elven scale: overlapping leaf plates.
			for r in 3:
				for k in 3:
					var p := hip + Vector2(-3 + k * 3.5, -4 - r * 4.5) * b
					ci.draw_arc(p, 2.2 * b, 0.2, PI - 0.2, 6, metal.darkened(0.3), 0.8)
	# Team tabard with a hem, belt and buckle.
	FkPaint.shade_poly(ci, [sh + Vector2(-3, 2) * b, sh + Vector2(5, 2) * b, hip + Vector2(5.5, 8) * b, hip + Vector2(2, 5.5) * b,
		hip + Vector2(-1.5, 8.5) * b, hip + Vector2(-3.5, 2) * b], tm)
	ci.draw_line(hip + Vector2(5.5, 8) * b, hip + Vector2(2, 5.5) * b, tm.darkened(0.3), 1.0 * b)
	ci.draw_line(hip + Vector2(-6, -1) * b, hip + Vector2(6.8, -1) * b, leather, 2.4 * b)
	ci.draw_rect(Rect2(hip + Vector2(1.2, -2.4) * b, Vector2(2.6, 2.8) * b), FkPaint.tint(Color("c9a45c"), pose))
	if armoured:
		# Pauldron.
		FkPaint.shade_poly(ci, FkPaint.ellipse_pts(sh + Vector2(1, 1.5) * b, Vector2(6, 4.2) * b, -0.2), metal.lightened(0.05))
	FkPaint.pop(ci)
	sh = jn.sh
	var hb: float = b * lk.head
	var head := sh + Vector2(1.8, -9.5) * hb
	# Long hair falls behind the neck (elves), under any open helmet.
	if lk.long_hair and helmet not in ["hood", "greathelm", "visor"]:
		var sway := sin(t * 2.0 + seed) * 1.2 + mv * 1.5
		FkPaint.shade_poly(ci, [head + Vector2(-5.5, -3) * hb, head + Vector2(1, -5) * hb, head + Vector2(-1, 6) * hb,
			sh + Vector2(-5 - sway, 8) * b, sh + Vector2(-9 - sway, 5) * b, head + Vector2(-7.5, 3) * hb], hair)
	# Neck and head: skull, jaw, ear, brow, eye, nose.
	ci.draw_rect(Rect2(sh + Vector2(-0.5, -4.5) * b, Vector2(4.5, 4.5) * b), skin.darkened(0.15))
	FkPaint.shade_poly(ci, FkPaint.ellipse_pts(head, Vector2(5.4, 6.0) * hb, 0.0), skin)
	FkPaint.shade_poly(ci, [head + Vector2(-2.5, 3) * hb, head + Vector2(4.8, 2.2) * hb, head + Vector2(4.2, 5.2) * hb, head + Vector2(0.5, 6.4) * hb], skin.darkened(0.06))
	if lk.ears == "round":
		ci.draw_circle(head + Vector2(-1.4, 0.6) * hb, 1.5 * hb, skin.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([head + Vector2(5.0, -0.8) * hb, head + Vector2(7.0, 1.6) * hb, head + Vector2(5.0, 2.2) * hb]), skin.darkened(0.05))
	ci.draw_line(head + Vector2(2.0, -2.2) * hb, head + Vector2(4.6, -2.0) * hb, Color(0.15, 0.1, 0.07, 0.8), 0.9 * hb)
	ci.draw_circle(head + Vector2(3.4, -0.9) * hb, 0.75 * hb, Color(0.08, 0.06, 0.05))
	ci.draw_line(head + Vector2(3.2, 3.6) * hb, head + Vector2(4.6, 3.4) * hb, Color(0.3, 0.15, 0.12, 0.7), 0.7 * hb)
	var open_face := helmet not in FkArmour.ENCLOSED
	match int(lk.beard):
		1:
			if helmet not in ["greathelm", "visor"]:
				_dwarf_beard(ci, head, hb, hair, t, seed)
		3:
			if seed % 3 == 0 and helmet in ["hair", "band", "cap", "kettle", "morion", "tricorne", "brodie", "galea", "conical", "goggles"]:
				FkPaint.shade_poly(ci, [head + Vector2(-2.5, 2) * hb, head + Vector2(4.8, 2.4) * hb, head + Vector2(3.5, 6.8) * hb, head + Vector2(0.5, 7.4) * hb, head + Vector2(-2, 5) * hb], hair)
	FkArmour.helmet(ci, helmet, head, hb * 0.84, pal, tm, pose, t, seed, hair, lk)
	# Pointed ears sweep up and back past the hair or an open helm.
	if lk.ears == "pointed" and open_face:
		FkPaint.poly(ci, [head + Vector2(-0.6, 2.2) * hb, head + Vector2(-2.4, -0.6) * hb, head + Vector2(-8.5, -6.5) * hb, head + Vector2(-2.6, 2.8) * hb], skin.darkened(0.08))
		ci.draw_line(head + Vector2(-2.2, 1.0) * hb, head + Vector2(-6.8, -4.8) * hb, skin.darkened(0.25), 0.7)
	# Shield (far arm) under the weapon arm, so the striking hand is always the top layer; then the
	# near arm and the weapon in its hand.
	# The shield rides on the far hand: its drawing is laid out around sh with the grip at SHIELD_GRIP.
	var shield_at: Vector2 = (jn.hand_f as Vector2) - FkSkeleton.SHIELD_GRIP * b
	FkArmour.shield(ci, st.get("shield", ""), shield_at, build, pal, tm, team, pose, t, lk, st.get("runes", false))
	var fam: String = FkSkeleton.FAMILY.get(weapon, "idle")
	if fam in ["blade", "chop"]:
		_smear(ci, st, pose, seed, build, weapon, pivot, body, not legs, metal)
	var grip: float = (jn.hand_n - jn.elbow_n).angle() if fam in ["idle", "crew", "bow"] else (jn.dir as Vector2).angle()
	arm(ci, jn.sh_n, jn.elbow_n, jn.hand_n, grip, b, cloth.lightened(0.12), skin, metal if armoured else leather)
	shoulder_cap(ci, jn.sh_n, jn.elbow_n, b, metal.lightened(0.05) if armoured else cloth.lightened(0.05))
	FkWeapons.weapon(ci, weapon, jn, build, FkUnits.swing(atk), atk, pal, tm, skin, pose, t, lk)


## Motion smear behind a cutting weapon: the tip's actual path over the last part of the strike,
## sampled from the skeleton, fading in toward the blade.
static func _smear(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, b: float, weapon: String, pivot: Vector2, body: Vector2, seated: bool, metal: Color) -> void:
	var atk: float = pose.get("atk", -1.0)
	if atk < 0.35 or atk >= 0.62:
		return
	var fade := clampf((0.62 - atk) / 0.07, 0.0, 1.0)
	var length := FkWeapons.weapon_length(weapon) * b
	var shield: bool = st.get("shield", "") != ""
	var pts := PackedVector2Array()
	for i in 9:
		var p := pose.merged({"atk": lerpf(0.33, minf(atk, 0.55), i / 8.0), "t": pose.get("t", 0.0) + seed / 2.1}, true)
		var s := FkSkeleton.solve(b, weapon, p, shield, seated)
		var off: Vector2 = (pivot + (s.sh_n - pivot) * body) - (s.sh_n as Vector2)
		pts.append((s.hand_n as Vector2) + off + (s.dir as Vector2) * length)
	for i in pts.size() - 1:
		var u := float(i + 1) / (pts.size() - 1)
		ci.draw_line(pts[i], pts[i + 1], Color(metal.lightened(0.55), 0.5 * u * fade), (1.5 + 4.0 * u) * b)


static func _dwarf_beard(ci: CanvasItem, head: Vector2, b: float, hair: Color, t: float, seed: int) -> void:
	var sway := sin(t * 1.7 + seed) * 0.6
	var tip := head + Vector2(2.5 + sway, 15) * b
	FkPaint.shade_poly(ci, [head + Vector2(-2.6, 0.5) * b, head + Vector2(1.5, 3.2) * b, head + Vector2(6.2, 2.0) * b, head + Vector2(6.6, 6.5) * b,
		head + Vector2(5.0, 11.5) * b, tip, head + Vector2(-0.5, 12) * b, head + Vector2(-3.0, 6) * b], hair)
	# Strands and a braid clasp.
	for k in 3:
		var x := -0.5 + k * 2.2
		ci.draw_line(head + Vector2(x, 5) * b, head + Vector2(x + 0.8, 11.5) * b, hair.darkened(0.25), 0.7)
	ci.draw_rect(Rect2(head + Vector2(1.6, 11.2) * b, Vector2(2.6, 1.6) * b), Color("c9a45c"))
	# Moustache over the mouth.
	FkPaint.ellipse(ci, head + Vector2(4.6, 3.3) * b, Vector2(2.6, 1.3) * b, hair.lightened(0.08), 0.25)


static func offset_humanoid(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, offset: Vector2) -> void:
	# The humanoid rig draws around a hip at y≈−25; drawing it with a translated transform keeps one rig.
	FkPaint.push(ci, Transform2D(0.0, offset))
	humanoid(ci, st, pose, seed, 1.0, false)
	FkPaint.pop(ci)


static func crew(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, at: Vector2, weapon := "crew") -> void:
	FkPaint.push(ci, Transform2D(0.0, Vector2(0.85, 0.85), 0.0, at))
	humanoid(ci, dress(st, {"helmet": st.get("crew", "cap"), "weapon": weapon}), pose, seed)
	FkPaint.pop(ci)


## A sub-figure (crew, driver) wearing `extra`'s gear in the parent's race look and colours.
static func dress(spec: Dictionary, extra: Dictionary) -> Dictionary:
	return extra.merged({"look": spec.look, "palette": spec.palette, "team": spec.team})
