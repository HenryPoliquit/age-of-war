class_name FkFigure
extends RefCounted
## Human figure rig: legs, torso, head (hair, beard, ears), arms and weapon, drawn back to front by the
## skeleton's depth; plus the offset/crew variants used by riders and machine crews. Local space: feet
## at y = 0, facing +x, up is −y.


## Near (weapon) arm from solved joints: inked upper arm and bracered forearm, then the hand, so it
## reads over the body.
static func arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, hand_angle: float, b: float, sleeve: Color, skin: Color, bracer: Color, ink_boost := 0.0) -> void:
	var ink := Color(0.08, 0.06, 0.05)
	# ink_boost (0..1) snaps the outline to full weight on an impact frame.
	var k := 2.6 * ink_boost * b
	FkPaint.seg(ci, shoulder, elbow, 7.8 * b + k, 7.0 * b + k, ink)
	FkPaint.seg(ci, elbow, hand, 7.0 * b + k, 6.0 * b + k, ink)
	FkPaint.seg(ci, shoulder, elbow, 5.4 * b, 4.6 * b, sleeve)
	FkPaint.seg(ci, elbow, hand, 4.6 * b, 3.8 * b, bracer)
	fist(ci, hand, hand_angle, b, skin)


## The near arm's two halves, for an arm swinging out of the picture plane: each sorts by its own depth.
static func upper_arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, b: float, sleeve: Color, ink_boost := 0.0) -> void:
	var k := 2.6 * ink_boost * b
	FkPaint.seg(ci, shoulder, elbow, 7.8 * b + k, 7.0 * b + k, Color(0.08, 0.06, 0.05))
	FkPaint.seg(ci, shoulder, elbow, 5.4 * b, 4.6 * b, sleeve)


static func forearm(ci: CanvasItem, elbow: Vector2, hand: Vector2, hand_angle: float, b: float, skin: Color, bracer: Color, ink_boost := 0.0) -> void:
	var k := 2.6 * ink_boost * b
	FkPaint.seg(ci, elbow, hand, 7.0 * b + k, 6.0 * b + k, Color(0.08, 0.06, 0.05))
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


## Figure parts in today's draw order, back to front. Each frame they are sorted by depth; a tie keeps
## this order, so parts only swap where the pose really puts one in front of another.
const PARTS := ["shadow", "far leg", "near leg", "cape", "pack", "far arm", "torso", "head", "bow", "shield", "smear",
	"near upper arm", "near forearm", "shoulder cap", "weapon", "impact", "dust"]


static func humanoid(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, scale := 1.0, legs := true) -> void:
	for p in _parts(ci, st, pose, seed, scale, legs):
		(p[3] as Callable).call()


## This frame's part names, back to front: what humanoid() draws, without drawing.
static func layers(st: Dictionary, pose: Dictionary, seed := 0, scale := 1.0, legs := true) -> Array:
	return _parts(null, st, pose, seed, scale, legs).map(func(p: Array) -> String: return p[2])


## [depth, rank, name, draw] per part, sorted back to front. Depth comes from the skeleton's joints
## (j.z, + toward the viewer); rank is the part's place in PARTS.
static func _parts(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, scale: float, legs: bool) -> Array:
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
	var shield: String = st.get("shield", "")
	# One skeleton per frame, in the race's proportions; the idle-breath phase is offset per individual.
	var j := FkSkeleton.solve(build, weapon, pose.merged({"t": t + seed / 2.1}, true), shield, not legs, lk)
	var z: Dictionary = j.z
	if pose.get("mirrored", false):
		# Drawn flipped, the figure is the same right-handed body seen from its other side (not a
		# left-handed one): every depth flips, so the weapon arm goes behind the body and the shield arm,
		# the left leg and the left side's lighting come to the front.
		z = z.duplicate()
		for k in z:
			z[k] = -z[k]
	var hip: Vector2 = j.hip
	var sh: Vector2 = j.sh
	var b := build
	# Outline offsets and limb widths take the race's proportions (the bones already have them).
	var bb := body * b
	var hb: float = b * lk.head
	var fam: String = FkSkeleton.FAMILY.get(weapon, "idle")
	var parts := []
	var add := func(name: String, depth: float, draw: Callable) -> void:
		parts.append([depth, PARTS.find(name), name, draw])
	var nothing := func() -> void:
		pass

	var draw_shadow := func() -> void:
		if legs:
			FkPaint.shadow(ci, 12 * bb.x)
	add.call("shadow", -100.0, draw_shadow)
	# Far leg (darker), then the near one; a rider shows only the near leg, its foot in the stirrup.
	var draw_leg := func(i: int) -> void:
		var tag := "n" if i == 0 else "f"
		if not legs and z["hip_" + tag] < 0.0:
			return
		var root: Vector2 = j["hip_" + tag]
		var knee: Vector2 = j["knee_" + tag]
		var foot: Vector2 = j["foot_" + tag]
		var back := 0.22 if z["hip_" + tag] < 0.0 else 0.0
		FkPaint.seg(ci, root, knee, 7.2 * bb.x, 5.4 * bb.x, trim.darkened(back))
		FkPaint.seg(ci, knee, foot, 5.4 * bb.x, 4.2 * bb.x, trim.darkened(back + 0.08))
		if armoured:
			FkPaint.seg(ci, knee.lerp(foot, 0.1), foot + Vector2(0, -2) * bb, 5.8 * bb.x, 4.8 * bb.x, metal.darkened(back))
			ci.draw_circle(knee, 3.2 * bb.x, metal.darkened(back - 0.1))
		# Boot: heel, sole and toe — pointing forward, rolling heel to toe with the stride.
		var boot := FkSkeleton.boot(foot, j["rot_" + tag], b, j["toe_bend_" + tag], body)
		FkPaint.shade_poly(ci, boot, leather.darkened(back))
		ci.draw_line(boot[5], boot[4], Color(0.08, 0.06, 0.05), 1.2 * b)
	add.call("far leg", -50.0 + 0.5 * signf(z.hip_f), draw_leg.bind(1))
	add.call("near leg", -50.0 + 0.5 * signf(z.hip_n), draw_leg.bind(0))
	# Cape trails behind and lags the body (secondary motion).
	var draw_cape := func() -> void:
		if st.get("cape", false) or helmet == "greathelm":
			# Riders' cloaks whip in the wind of the gait and harder on the charge.
			var flap: float = sin(t * 3.0 + seed) * 2.0 + (mv + pose.get("ride_mv", 0.0)) * 3.0 + (4.0 if atk >= 0.3 and atk < 0.75 else 0.0)
			FkPaint.shade_poly(ci, [sh + Vector2(-6, 0) * bb, sh + Vector2(2, 1) * bb, hip + Vector2(-2, 8) * bb,
				hip + Vector2(-12 - flap, 10) * bb, hip + Vector2(-9 - flap * 0.5, -2) * bb], tm.darkened(0.35))
	add.call("cape", -40.0, draw_cape)
	# The pack is laid out around the shoulder line; scaling about it gives the race's proportions.
	var draw_pack := func() -> void:
		FkPaint.push(ci, Transform2D(0.0, sh) * Transform2D(0.0, body, 0.0, Vector2.ZERO) * Transform2D(0.0, -sh))
		FkArmour.pack(ci, st.get("pack", ""), sh, sh + (hip - sh) / body, build, pal, tm, pose, t, lk)
		FkPaint.pop(ci)
	add.call("pack", -39.0, draw_pack)
	# Far arm, behind the body: counter-swings, carries the shield, or holds the bow / the weapon's haft.
	var draw_far_arm := func() -> void:
		var fs: Vector2 = j.sh_f
		var fe: Vector2 = j.elbow_f
		var fh: Vector2 = j.hand_f
		var shade := 0.3 if z.sh_f < 0.0 else -0.12
		FkPaint.seg(ci, fs, fe, 5.0 * bb.x, 4.2 * bb.x, cloth.darkened(shade))
		FkPaint.seg(ci, fe, fh, 4.2 * bb.x, 3.4 * bb.x, cloth.darkened(shade + 0.04))
		fist(ci, fh, (fh - fe).angle(), b * 0.85, skin.darkened(maxf(shade, 0.0) * 0.8), false)
	add.call("far arm", (z.sh_f + z.elbow_f + z.hand_f) / 3.0, draw_far_arm)
	# Torso: hips, waist, chest, shoulders.
	var draw_torso := func() -> void:
		var torso := [hip + Vector2(-6.5, 3) * bb, hip + Vector2(7, 3) * bb, hip + Vector2(6, -8) * bb, sh + Vector2(8.5, 5) * bb,
			sh + Vector2(7.5, -1.5) * bb, sh + Vector2(-7.5, -1.5) * bb, sh + Vector2(-8, 5) * bb, hip + Vector2(-5.5, -8) * bb]
		FkPaint.shade_poly(ci, torso, cloth)
		if armoured:
			# Breastplate / hauberk; Roman plate reads as horizontal bands, the rest as mail rows.
			FkPaint.shade_poly(ci, [hip + Vector2(-5.5, -5) * bb, hip + Vector2(6.5, -5) * bb, sh + Vector2(8, 4) * bb, sh + Vector2(6, -0.5) * bb,
				sh + Vector2(-6, -0.5) * bb, sh + Vector2(-7, 4) * bb], metal)
			var bands := helmet == "galea"
			for r in 4:
				var y := -1.0 - r * 3.4
				ci.draw_line(hip + Vector2(-4.5, y) * bb, hip + Vector2(6, y) * bb, Color(metal.darkened(0.45), 0.8 if bands else 0.5), (1.4 if bands else 0.8) * b)
			if helmet == "leaf":
				# Elven scale: overlapping leaf plates.
				for r in 3:
					for c in 3:
						var p := hip + Vector2(-3 + c * 3.5, -4 - r * 4.5) * bb
						ci.draw_arc(p, 2.2 * b, 0.2, PI - 0.2, 6, metal.darkened(0.3), 0.8)
		# Team tabard with a hem, belt and buckle.
		FkPaint.shade_poly(ci, [sh + Vector2(-3, 2) * bb, sh + Vector2(5, 2) * bb, hip + Vector2(5.5, 8) * bb, hip + Vector2(2, 5.5) * bb,
			hip + Vector2(-1.5, 8.5) * bb, hip + Vector2(-3.5, 2) * bb], tm)
		ci.draw_line(hip + Vector2(5.5, 8) * bb, hip + Vector2(2, 5.5) * bb, tm.darkened(0.3), 1.0 * b)
		ci.draw_line(hip + Vector2(-6, -1) * bb, hip + Vector2(6.8, -1) * bb, leather, 2.4 * b)
		ci.draw_rect(Rect2(hip + Vector2(1.2, -2.4) * bb, Vector2(2.6, 2.8) * bb), FkPaint.tint(Color("c9a45c"), pose))
		if armoured:
			# Pauldron.
			FkPaint.shade_poly(ci, FkPaint.ellipse_pts(sh + Vector2(1, 1.5) * bb, Vector2(6, 4.2) * bb, -0.2), metal.lightened(0.05))
	add.call("torso", 0.0, draw_torso)
	# Head on its neck joint, turned by its (small) tilt: long hair, neck, face, beard, helmet, ears.
	var draw_head := func() -> void:
		var head: Vector2 = j.head
		FkPaint.push(ci, Transform2D(0.0, head) * Transform2D(j.head_tilt, Vector2.ZERO) * Transform2D(0.0, -head))
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
		FkPaint.pop(ci)
	add.call("head", 0.5, draw_head)
	# Weapons: a bow is held in the far hand, at its own layer under the drawing arm; the rest ride on
	# the near hand, over it.
	var draw_weapon := func() -> void:
		FkWeapons.weapon(ci, weapon, j, build, FkUnits.swing(atk), atk, pal, tm, skin, pose, t, lk)
	var held_far: bool = weapon in FkWeapons.HELD_FAR
	# Standing to shoot, the bow is out in front of the face; carried on the march it hangs in the bow
	# hand beside the outside of that side's leg: behind both legs on the far side, in front of the body
	# when the figure is turned around.
	var carried: float = -51.0 if z.hand_f < 0.0 else z.hand_f
	var bow_z := lerpf(1.0, carried, mv) if held_far and atk < 0.0 else 1.0
	add.call("bow", bow_z, draw_weapon if held_far else nothing)
	# The shield rides on the far hand: its drawing is laid out around sh with the grip at SHIELD_GRIP.
	# It stands in front of the chest and head at the near shoulder's depth, so the weapon arm (same
	# depth, later rank) always strikes over it.
	# Seen from the side a shield is turned toward the enemy: a figure facing right (unmirrored) shows us
	# the back of the shield on its far arm, its hand on the grip; a mirrored one shows the painted face.
	var back_view: bool = not pose.get("mirrored", false)
	var draw_shield := func() -> void:
		FkArmour.shield(ci, shield, (j.hand_f as Vector2) - FkSkeleton.SHIELD_GRIP * b, build, pal, tm, team, pose, t, lk,
			st.get("runes", false), j.shield_turn, back_view)
		if back_view and shield not in ["", "energy"]:
			fist(ci, j.hand_f, 0.0, b * 0.85, skin.darkened(0.25))
	add.call("shield", maxf(z.sh_n, z.sh_f), draw_shield)
	var draw_smear := func() -> void:
		if fam in ["blade", "chop"]:
			_smear(ci, st, pose, seed, build, weapon, not legs, metal)
	add.call("smear", z.sh_n, draw_smear)
	# Near arm: whole while it stays in the picture plane (today's strokes); split at the elbow once it
	# swings toward the viewer, so the upper arm and forearm each sort by their own depth.
	var grip: float = (j.hand_n - j.elbow_n).angle() if fam in ["idle", "crew", "bow"] else (j.dir as Vector2).angle()
	var impact := clampf(1.0 - absf(atk - 0.52) / 0.08, 0.0, 1.0) if fam in ["blade", "chop"] else 0.0
	# The weapon arm takes the far side's shadow when it is behind the body.
	var sleeve := cloth.lightened(0.12) if z.sh_n > 0.0 else cloth.darkened(0.3)
	var bracer := (metal if armoured else leather).darkened(0.0 if z.sh_n > 0.0 else 0.3)
	var planar: bool = absf(z.elbow_n - z.sh_n) < 1e-3 and absf(z.hand_n - z.sh_n) < 1e-3
	var draw_upper := func() -> void:
		if planar:
			arm(ci, j.sh_n, j.elbow_n, j.hand_n, grip, b, sleeve, skin, bracer, impact)
		else:
			upper_arm(ci, j.sh_n, j.elbow_n, b, sleeve, impact)
	var draw_fore := func() -> void:
		if not planar:
			forearm(ci, j.elbow_n, j.hand_n, grip, b, skin, bracer, impact)
	var upper_z: float = (z.sh_n + z.elbow_n) / 2.0
	add.call("near upper arm", upper_z, draw_upper)
	# The hand always reads over its own upper arm (folded back along the neck on a bow release it would
	# otherwise vanish under the sleeve); against every other part the forearm sorts by its own depth.
	add.call("near forearm", maxf((z.elbow_n + z.hand_n) / 2.0, upper_z), draw_fore)
	var draw_cap := func() -> void:
		shoulder_cap(ci, j.sh_n, j.elbow_n, b, metal.lightened(0.05) if armoured else cloth.lightened(0.05))
	add.call("shoulder cap", z.sh_n, draw_cap)
	add.call("weapon", z.hand_n + 0.01, nothing if held_far else draw_weapon)
	var draw_impact := func() -> void:
		if fam in ["blade", "chop"] and legs:
			_impact_accents(ci, j, weapon, build, atk)
	add.call("impact", 100.0, draw_impact)
	# Heavy stride: small dust puffs kicked up where a heel lands.
	var draw_dust := func() -> void:
		for tag in ["n", "f"]:
			var d: float = j["dust_" + tag]
			if d > 0.05:
				var heel: Vector2 = (j["foot_" + tag] as Vector2) + Vector2(-2, 1) * b
				for i in 3:
					var r := (1.5 + i * 0.8 + (1.0 - d) * 2.5) * b
					ci.draw_circle(heel + Vector2(-3.5 + i * 3.5, -r * 0.6), r, Color(0.72, 0.64, 0.5, 0.35 * d))
	add.call("dust", 101.0, draw_dust)
	parts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
	return parts


## Motion smear behind a cutting weapon: the tip's actual path over the last part of the strike,
## sampled from the skeleton, fading in toward the blade.
static func _smear(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, b: float, weapon: String, seated: bool, metal: Color) -> void:
	var atk: float = pose.get("atk", -1.0)
	if atk < 0.35 or atk >= 0.62:
		return
	var fade := clampf((0.62 - atk) / 0.07, 0.0, 1.0)
	var length := FkWeapons.weapon_length(weapon) * b
	var shield: String = st.get("shield", "")
	var pts := PackedVector2Array()
	for i in 9:
		var p := pose.merged({"atk": lerpf(0.33, minf(atk, 0.55), i / 8.0), "t": pose.get("t", 0.0) + seed / 2.1}, true)
		var s := FkSkeleton.solve(b, weapon, p, shield, seated, st.look)
		pts.append((s.hand_n as Vector2) + (s.dir as Vector2) * length)
	for i in pts.size() - 1:
		var u := float(i + 1) / (pts.size() - 1)
		# A crescent: thin where the cut began, full and bright at the blade.
		ci.draw_line(pts[i], pts[i + 1], Color(metal.lightened(0.55).lerp(Color.WHITE, u), 0.6 * u * fade), (1.5 + 6.0 * u) * b)


## Impact accents at the lockout: slash lines bursting from the blade along the cutting edge, and dirt
## chips kicked out from under the braced front boot.
static func _impact_accents(ci: CanvasItem, j: Dictionary, weapon: String, b: float, atk: float) -> void:
	if atk >= 0.44 and atk < 0.64:
		var u := (atk - 0.44) / 0.2
		var dir: Vector2 = j.dir
		var p: Vector2 = (j.hand_n as Vector2) + dir * FkWeapons.weapon_length(weapon) * b * 0.7
		var edge := FkWeapons.edge_normal(dir)
		for i in 5:
			var d := edge.rotated(-0.8 + i * 0.4)
			ci.draw_line(p + d * (3.0 + 6.0 * u) * b, p + d * (6.0 + 14.0 * u) * b, Color(1, 1, 0.9, 0.9 * (1.0 - u)), 1.4 * b)
	if atk >= 0.48 and atk < 0.72:
		var u := (atk - 0.48) / 0.24
		var foot: Vector2 = j.foot_n
		for i in 5:
			var q := foot + Vector2(4.0 + i * 2.2 + u * (10.0 + i * 3.0), -u * (6.0 + i * 2.5) + u * u * 9.0) * b
			ci.draw_rect(Rect2(q, Vector2(1.6, 1.3) * b), Color(0.42, 0.32, 0.22, 1.0 - u))


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
