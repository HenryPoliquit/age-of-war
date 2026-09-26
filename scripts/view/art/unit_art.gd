class_name UnitArt
extends RefCounted
## Procedural "paper-doll" unit figures: a small set of rigs (humanoid, quadruped rider, vehicle,
## mech, siege engines) dressed per unit — GDD §13.2's modular-rig idea, drawn with canvas calls
## until painted parts exist. Local space: feet at y = 0, facing +x, up is −y.
##
## pose = {walk: float (stride phase, radians), move: float (0 idle … 1 walking, blended by the caller), atk: float (0..1 attack progress, <0 idle),
##         t: float (seconds, for idle motion), flash: float (0..1 hit flash)}

const SKIN := [Color("e0b48c"), Color("c68e62"), Color("8d5a3b"), Color("f1cfae"), Color("a86e48")]
const HAIR := [Color("2a1d14"), Color("5a3a1f"), Color("1a1a1a"), Color("8a5a2b")]

## Per-age clothing: [main cloth, secondary/trim, metal]
const AGE_CLOTH := [
	[Color("8a6a45"), Color("5e4630"), Color("9a9080")],  # Stone: hides
	[Color("e6dcc6"), Color("b07a3a"), Color("c28c3e")],  # Bronze: linen + bronze
	[Color("7d7f85"), Color("4c4a48"), Color("b5b9bf")],  # Medieval: mail + steel
	[Color("3b3f58"), Color("c9b27a"), Color("a5a9ae")],  # Gunpowder: coats + brass
	[Color("7b7350"), Color("4e4a33"), Color("6e7066")],  # Industrial: khaki + gunmetal
	[Color("3a3f4c"), Color("20242d"), Color("9aa4b5")],  # Future: armour plates
]

## Unit styles by id. rig: humanoid | mounted | chariot | car | mech | ram | trebuchet | mortar | howitzer | rail
const STYLES := {
	&"brawler": {"rig": "humanoid", "helmet": "hair", "weapon": "club", "shield": "hide"},
	&"slinger": {"rig": "humanoid", "helmet": "band", "weapon": "sling", "pack": "pouch"},
	&"tusk_rider": {"rig": "mounted", "beast": "boar", "helmet": "hair", "weapon": "spear"},
	&"hoplite": {"rig": "humanoid", "helmet": "crest", "weapon": "spear", "shield": "round"},
	&"javelineer": {"rig": "humanoid", "helmet": "cap", "weapon": "javelin", "pack": "javelins"},
	&"chariot": {"rig": "chariot"},
	&"ram_crew": {"rig": "ram"},
	&"man_at_arms": {"rig": "humanoid", "helmet": "kettle", "weapon": "sword", "shield": "kite"},
	&"longbowman": {"rig": "humanoid", "helmet": "hood", "weapon": "bow", "pack": "quiver"},
	&"knight": {"rig": "mounted", "beast": "warhorse", "helmet": "greathelm", "weapon": "lance"},
	&"trebuchet": {"rig": "trebuchet"},
	&"halberdier": {"rig": "humanoid", "helmet": "morion", "weapon": "halberd"},
	&"musketeer": {"rig": "humanoid", "helmet": "tricorne", "weapon": "musket", "pack": "backpack"},
	&"cuirassier": {"rig": "mounted", "beast": "horse", "helmet": "morion", "weapon": "saber"},
	&"mortar_team": {"rig": "mortar"},
	&"trench_raider": {"rig": "humanoid", "helmet": "brodie", "weapon": "shovel", "shield": "plate"},
	&"rifleman": {"rig": "humanoid", "helmet": "brodie", "weapon": "rifle", "pack": "backpack"},
	&"armoured_car": {"rig": "car"},
	&"field_howitzer": {"rig": "howitzer"},
	&"aegis_trooper": {"rig": "humanoid", "helmet": "visor", "weapon": "baton", "shield": "energy"},
	&"pulse_rifleman": {"rig": "humanoid", "helmet": "visor", "weapon": "pulse", "pack": "cell"},
	&"strider_mech": {"rig": "mech"},
	&"rail_artillery": {"rig": "rail"},
}

const ROLE_FALLBACK := {
	"vanguard": {"rig": "humanoid", "helmet": "cap", "weapon": "sword", "shield": "round"},
	"ranged": {"rig": "humanoid", "helmet": "cap", "weapon": "bow"},
	"heavy": {"rig": "mounted", "beast": "horse", "helmet": "greathelm", "weapon": "lance"},
	"siege": {"rig": "ram"},
}


## Role silhouettes (PRD §11: role identifiable by shape alone): Vanguards are broad and shielded
## (or carry an upright polearm); Ranged are slighter and carry a pack on the back.
const ROLE_BUILD := {"vanguard": 1.16, "ranged": 0.94}

static var _style_cache := {}


static func style_for(def: UnitDef) -> Dictionary:
	if _style_cache.has(def.id):
		return _style_cache[def.id]
	var st: Dictionary = STYLES.get(def.id, ROLE_FALLBACK.get(def.role, ROLE_FALLBACK.vanguard)).duplicate()
	if not st.has("build") and ROLE_BUILD.has(def.role):
		st["build"] = ROLE_BUILD[def.role]
	_style_cache[def.id] = st
	return st


## Visual height in px (for HP bars and selection).
static func height_for(def: UnitDef) -> float:
	match style_for(def).rig:
		"humanoid":
			return 66.0
		"mounted", "chariot":
			return 82.0
		"mech":
			return 92.0
		"car":
			return 52.0
		"trebuchet":
			return 96.0
		_:
			return 50.0


## Attack animation shape: anticipation (0→−1), contact at 0.35–0.55 (−1→+1), recovery (+1→0).
static func swing(atk: float) -> float:
	if atk < 0.0:
		return 0.0
	if atk < 0.35:
		return -ease(atk / 0.35, 0.6)
	if atk < 0.55:
		return lerpf(-1.0, 1.0, ease((atk - 0.35) / 0.2, 0.4))
	return lerpf(1.0, 0.0, ease((atk - 0.55) / 0.45, 1.6))


static func draw_unit(ci: CanvasItem, def: UnitDef, team: Color, pose: Dictionary, seed: int = 0) -> void:
	var st := style_for(def)
	var pal: Array = AGE_CLOTH[clampi(def.age - 1, 0, 5)]
	match st.rig:
		"humanoid":
			humanoid(ci, st, pal, team, pose, seed)
		"mounted":
			mounted(ci, st, pal, team, pose, seed)
		"chariot":
			chariot(ci, pal, team, pose, seed)
		"car":
			car(ci, pal, team, pose)
		"mech":
			mech(ci, team, pose)
		"ram":
			ram(ci, pal, team, pose, seed)
		"trebuchet":
			trebuchet(ci, pal, team, pose, seed)
		"mortar":
			mortar(ci, pal, team, pose, seed)
		"howitzer":
			howitzer(ci, pal, team, pose, seed)
		"rail":
			rail(ci, team, pose)


# ---------------------------------------------------------------------------
# Helpers

## Walk blend 0..1. Callers pass `move` (eased per unit); `moving` is the legacy on/off form.
static func _mv(pose: Dictionary) -> float:
	return pose.get("move", 1.0 if pose.get("moving", false) else 0.0)


static func _c(col: Color, pose: Dictionary) -> Color:
	var f: float = pose.get("flash", 0.0)
	return col.lerp(Color.WHITE, f * 0.85) if f > 0.0 else col


static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, col, w)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, rot := 0.0, n := 18) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	ci.draw_colored_polygon(pts, col)


static func _poly(ci: CanvasItem, pts: Array, col: Color, offset := Vector2.ZERO) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(v + offset)
	ci.draw_colored_polygon(p, col)


## Polygon shaded as a volume: vertices facing the key light (upper front) lighter, far side darker.
static func _shade_poly(ci: CanvasItem, pts: Array, col: Color, light := Vector2(0.45, -0.9)) -> void:
	var c := Vector2.ZERO
	for v in pts:
		c += v
	c /= pts.size()
	var p := PackedVector2Array()
	var cols := PackedColorArray()
	var ln := light.normalized()
	for v in pts:
		p.append(v)
		var d: Vector2 = (v - c)
		var k := d.normalized().dot(ln) if d.length() > 0.001 else 0.0
		cols.append(col.lightened(0.16 * k) if k > 0.0 else col.darkened(-0.22 * k))
	ci.draw_polygon(p, cols)


static func _ellipse_pts(c: Vector2, r: Vector2, rot := 0.0, n := 14) -> Array:
	var out := []
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return out


## Tapered limb segment with rounded joints, shaded across its width.
static func _seg(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color) -> void:
	var d := (b - a)
	if d.length() < 0.01:
		return
	var n := d.normalized().orthogonal()
	var lit := col.lightened(0.12)
	var dark := col.darkened(0.2)
	# The side facing the light (up/forward) is lighter.
	var s := 1.0 if n.dot(Vector2(0.45, -0.9)) > 0.0 else -1.0
	ci.draw_polygon(PackedVector2Array([a + n * wa * 0.5 * s, b + n * wb * 0.5 * s, b - n * wb * 0.5 * s, a - n * wa * 0.5 * s]),
		PackedColorArray([lit, lit, dark, dark]))
	ci.draw_circle(a, wa * 0.5, col)
	ci.draw_circle(b, wb * 0.5, col.darkened(0.05))


static func _wheel(ci: CanvasItem, c: Vector2, r: float, rot: float, rim: Color, hub: Color, spokes := 6) -> void:
	ci.draw_circle(c, r, rim)
	ci.draw_circle(c, r * 0.72, rim.darkened(0.35))
	for i in spokes:
		var a := rot + TAU * i / spokes
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.75, rim.lightened(0.15), 2.0)
	ci.draw_circle(c, r * 0.22, hub)


static func _shadow(ci: CanvasItem, w: float) -> void:
	_ellipse(ci, Vector2(0, 1), Vector2(w, 4), Color(0, 0, 0, 0.28))


# ---------------------------------------------------------------------------
# Humanoid rig (Vanguard, Ranged, crews)

static func humanoid(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int, scale := 1.0, legs := true) -> void:
	var build: float = st.get("build", 1.0) * scale
	var mv := _mv(pose)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var skin: Color = _c(SKIN[seed % SKIN.size()], pose)
	var cloth: Color = _c(pal[0], pose)
	var trim: Color = _c(pal[1], pose)
	var metal: Color = _c(pal[2], pose)
	var tm: Color = _c(team, pose)
	var armoured: bool = st.get("helmet", "") in ["crest", "kettle", "greathelm", "morion", "visor"]
	var leather := _c(Color("4a3322"), pose)
	var bob := lerpf(sin(t * 2.1 + seed) * 0.7, absf(sin(walk)) * 2.2, mv)
	var hip := Vector2(0, -30 * build + bob * 0.5)
	var sh := Vector2(1.5, -50 * build + bob)
	var head := sh + Vector2(1.8, -9.5 * build)
	var b := build
	if legs:
		_shadow(ci, 12 * b)
		for i in [1, 0]:
			var ph: float = walk + PI * i
			var thigh := lerpf(0.12 if i == 0 else -0.1, sin(ph) * 0.6, mv)
			var knee := hip + Vector2(0, 15 * b).rotated(-thigh)
			var bend := lerpf(0.05, maxf(0.0, cos(ph)) * 0.9, mv)
			var foot := knee + Vector2(0, 14 * b).rotated(-thigh + bend)
			var back := 0.22 if i == 1 else 0.0
			_seg(ci, hip, knee, 7.2 * b, 5.4 * b, trim.darkened(back))
			_seg(ci, knee, foot, 5.4 * b, 4.2 * b, trim.darkened(back + 0.08))
			if armoured:
				_seg(ci, knee.lerp(foot, 0.1), foot + Vector2(0, -2 * b), 5.8 * b, 4.8 * b, metal.darkened(back))
				ci.draw_circle(knee, 3.2 * b, metal.darkened(back - 0.1))
			# Boot: heel, sole and toe.
			_shade_poly(ci, [foot + Vector2(-3.2, -6) * b, foot + Vector2(3, -6) * b, foot + Vector2(4.5, -2) * b,
				foot + Vector2(8.5, -0.5) * b, foot + Vector2(8.5, 1.5) * b, foot + Vector2(-3.5, 1.5) * b], leather.darkened(back))
			ci.draw_line(foot + Vector2(-3.5, 1.5) * b, foot + Vector2(8.5, 1.5) * b, Color(0.08, 0.06, 0.05), 1.2 * b)
	# Cape trails behind and lags the body (secondary motion).
	if st.get("cape", false) or st.get("helmet", "") == "greathelm":
		var flap := sin(t * 3.0 + seed) * 2.0 + mv * 3.0
		_shade_poly(ci, [sh + Vector2(-6, 0) * b, sh + Vector2(2, 1) * b, hip + Vector2(-2, 8) * b,
			hip + Vector2(-12 - flap, 10) * b, hip + Vector2(-9 - flap * 0.5, -2) * b], tm.darkened(0.35))
	_pack(ci, st.get("pack", ""), sh, hip, build, pal, tm, pose, t)
	# Back arm swings opposite the front leg: upper arm, forearm, hand.
	var arm_sw := sin(walk) * 0.5 * mv
	var elbow := sh + Vector2(-3, 1) * b + Vector2(0, 10 * b).rotated(arm_sw)
	var back_hand := elbow + Vector2(0, 9 * b).rotated(arm_sw * 0.6 - 0.25)
	_seg(ci, sh + Vector2(-3, 1) * b, elbow, 5.0 * b, 4.2 * b, cloth.darkened(0.3))
	_seg(ci, elbow, back_hand, 4.2 * b, 3.4 * b, cloth.darkened(0.34))
	ci.draw_circle(back_hand, 2.1 * b, skin.darkened(0.25))
	# Torso: hips, waist, chest, shoulders.
	var torso := [hip + Vector2(-6.5, 3) * b, hip + Vector2(7, 3) * b, hip + Vector2(6, -8) * b, sh + Vector2(8.5, 5) * b,
		sh + Vector2(7.5, -1.5) * b, sh + Vector2(-7.5, -1.5) * b, sh + Vector2(-8, 5) * b, hip + Vector2(-5.5, -8) * b]
	_shade_poly(ci, torso, cloth)
	if armoured:
		# Breastplate / hauberk with mail rows.
		_shade_poly(ci, [hip + Vector2(-5.5, -5) * b, hip + Vector2(6.5, -5) * b, sh + Vector2(8, 4) * b, sh + Vector2(6, -0.5) * b,
			sh + Vector2(-6, -0.5) * b, sh + Vector2(-7, 4) * b], metal)
		for r in 4:
			var y := -1.0 - r * 3.4
			ci.draw_line(hip + Vector2(-4.5, y) * b, hip + Vector2(6, y) * b, Color(metal.darkened(0.35), 0.5), 0.8 * b)
	# Team tabard with a hem, belt and buckle.
	_shade_poly(ci, [sh + Vector2(-3, 2) * b, sh + Vector2(5, 2) * b, hip + Vector2(5.5, 8) * b, hip + Vector2(2, 5.5) * b,
		hip + Vector2(-1.5, 8.5) * b, hip + Vector2(-3.5, 2) * b], tm)
	ci.draw_line(hip + Vector2(5.5, 8) * b, hip + Vector2(2, 5.5) * b, tm.darkened(0.3), 1.0 * b)
	ci.draw_line(hip + Vector2(-6, -1) * b, hip + Vector2(6.8, -1) * b, leather, 2.4 * b)
	ci.draw_rect(Rect2(hip + Vector2(1.2, -2.4) * b, Vector2(2.6, 2.8) * b), _c(Color("c9a45c"), pose))
	if armoured:
		# Pauldron.
		_shade_poly(ci, _ellipse_pts(sh + Vector2(1, 1.5) * b, Vector2(6, 4.2) * b, -0.2), metal.lightened(0.05))
	# Neck and head: skull, jaw, ear, brow, eye, nose.
	ci.draw_rect(Rect2(sh + Vector2(-0.5, -4.5) * b, Vector2(4.5, 4.5) * b), skin.darkened(0.15))
	_shade_poly(ci, _ellipse_pts(head, Vector2(5.4, 6.0) * b, 0.0), skin)
	_shade_poly(ci, [head + Vector2(-2.5, 3) * b, head + Vector2(4.8, 2.2) * b, head + Vector2(4.2, 5.2) * b, head + Vector2(0.5, 6.4) * b], skin.darkened(0.06))
	ci.draw_circle(head + Vector2(-1.4, 0.6) * b, 1.5 * b, skin.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([head + Vector2(5.0, -0.8) * b, head + Vector2(7.0, 1.6) * b, head + Vector2(5.0, 2.2) * b]), skin.darkened(0.05))
	ci.draw_line(head + Vector2(2.0, -2.2) * b, head + Vector2(4.6, -2.0) * b, Color(0.15, 0.1, 0.07, 0.8), 0.9 * b)
	ci.draw_circle(head + Vector2(3.4, -0.9) * b, 0.75 * b, Color(0.08, 0.06, 0.05))
	ci.draw_line(head + Vector2(3.2, 3.6) * b, head + Vector2(4.6, 3.4) * b, Color(0.3, 0.15, 0.12, 0.7), 0.7 * b)
	if seed % 3 == 0 and st.get("helmet", "") in ["hair", "band", "cap", "kettle", "morion", "tricorne", "brodie"]:
		var hair: Color = _c(HAIR[seed % HAIR.size()], pose)
		_shade_poly(ci, [head + Vector2(-2.5, 2) * b, head + Vector2(4.8, 2.4) * b, head + Vector2(3.5, 6.8) * b, head + Vector2(0.5, 7.4) * b, head + Vector2(-2, 5) * b], hair)
	_helmet(ci, st.get("helmet", ""), head, build * 0.84, pal, tm, pose, t, seed)
	# Front arm + weapon.
	_weapon(ci, st.get("weapon", "sword"), sh, build, swing(atk), atk, pal, tm, skin, pose, t)
	match st.get("shield", ""):
		"round":
			var c := sh + Vector2(10, 11) * build
			ci.draw_circle(c, 10.5 * build, metal.darkened(0.2))
			ci.draw_circle(c, 9 * build, tm)
			ci.draw_circle(c, 2.5 * build, metal)
		"kite":
			var c := sh + Vector2(10, 9) * build
			_poly(ci, [c + Vector2(-7, -8), c + Vector2(7, -8), c + Vector2(6, 4), c + Vector2(0, 14), c + Vector2(-6, 4)], metal.darkened(0.3))
			_poly(ci, [c + Vector2(-5.5, -6.5), c + Vector2(5.5, -6.5), c + Vector2(4.5, 3.5), c + Vector2(0, 11.5), c + Vector2(-4.5, 3.5)], tm)
		"hide":
			var c := sh + Vector2(10, 12) * build
			_ellipse(ci, c, Vector2(8.5, 11) * build, _c(Color("6e4a2c"), pose))
			_ellipse(ci, c, Vector2(6.5, 9) * build, _c(Color("8d6a45"), pose))
			ci.draw_line(c + Vector2(-5, -2) * build, c + Vector2(5, -2) * build, tm, 2.5 * build)
		"plate":
			var c := sh + Vector2(11, 8) * build
			ci.draw_rect(Rect2(c + Vector2(-6, -11) * build, Vector2(12, 24) * build), metal.darkened(0.35))
			ci.draw_rect(Rect2(c + Vector2(-2, -6) * build, Vector2(6, 2) * build), Color(0.05, 0.05, 0.05))
			ci.draw_rect(Rect2(c + Vector2(-6, 6) * build, Vector2(12, 3) * build), tm)
		"energy":
			var c := sh + Vector2(13, 10) * build
			var g := Color(team.lightened(0.5), 0.35 + 0.1 * sin(t * 6.0))
			_ellipse(ci, c, Vector2(4, 17) * build, g)
			ci.draw_line(c + Vector2(0, -16) * build, c + Vector2(0, 16) * build, Color(team.lightened(0.7), 0.9), 2.0)


static func _pack(ci: CanvasItem, kind: String, sh: Vector2, hip: Vector2, b: float, pal: Array, tm: Color, pose: Dictionary, t: float) -> void:
	var back := sh + Vector2(-8, 4) * b
	match kind:
		"quiver", "javelins":
			var leather := _c(Color("6b4a2b"), pose)
			_poly(ci, [back + Vector2(-3, -6) * b, back + Vector2(3, -8) * b, back + Vector2(1, 16) * b, back + Vector2(-5, 14) * b], leather)
			for i in 3:
				var tip := back + Vector2(-2 + i * 2.5, -16 - (i % 2) * 3) * b
				ci.draw_line(back + Vector2(-1 + i * 1.5, -4) * b, tip, _c(Color("c9b28a"), pose), 1.6 * b)
				if kind == "javelins":
					ci.draw_line(tip, tip + Vector2(0.5, -4) * b, _c(pal[2], pose), 2.2 * b)
		"pouch":
			_ellipse(ci, hip + Vector2(-7, -4) * b, Vector2(4.5, 5.5) * b, _c(Color("7a5a3a"), pose))
			_ellipse(ci, back + Vector2(1, 2) * b, Vector2(4, 7) * b, _c(pal[1], pose).darkened(0.2))
		"backpack":
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 16) * b), _c(pal[1], pose).darkened(0.25))
			ci.draw_rect(Rect2(back + Vector2(-7, -6) * b, Vector2(10, 4) * b), _c(pal[1], pose).darkened(0.4))
		"cell":
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 16) * b), _c(Color("2a2f3c"), pose))
			ci.draw_rect(Rect2(back + Vector2(-4, -1) * b, Vector2(4, 10) * b), Color(tm.lightened(0.6), 0.6 + 0.3 * sin(t * 4.0)))


static func _helmet(ci: CanvasItem, kind: String, head: Vector2, b: float, pal: Array, tm: Color, pose: Dictionary, t: float, seed: int) -> void:
	var metal: Color = _c(pal[2], pose)
	var hair: Color = _c(HAIR[seed % HAIR.size()], pose)
	match kind:
		"hair":
			_ellipse(ci, head + Vector2(-1.5, -3) * b, Vector2(7, 4.5) * b, hair)
			_ellipse(ci, head + Vector2(-5, 1) * b, Vector2(3, 5) * b, hair)
		"band":
			_ellipse(ci, head + Vector2(-1.5, -3) * b, Vector2(7, 4) * b, hair)
			ci.draw_line(head + Vector2(-7, -2) * b, head + Vector2(7, -2) * b, tm, 2.5 * b)
		"cap":
			_ellipse(ci, head + Vector2(0, -3.5) * b, Vector2(7.5, 4.5) * b, _c(pal[1], pose))
		"crest":
			_ellipse(ci, head + Vector2(0, -2) * b, Vector2(7.8, 6.5) * b, metal)
			ci.draw_rect(Rect2(head + Vector2(1, -2) * b, Vector2(6, 7) * b), metal.darkened(0.25))
			# Plume lags behind the head (secondary motion).
			var lag := sin(t * 5.0) * 1.5
			for i in 5:
				ci.draw_circle(head + Vector2(-2.5 - i * 2.6, -9.5 + i * 0.7 + lag * i * 0.2) * b, (3.4 - i * 0.35) * b, tm)
		"kettle":
			_ellipse(ci, head + Vector2(0, -3) * b, Vector2(11, 2.5) * b, metal.darkened(0.15))
			_ellipse(ci, head + Vector2(0, -5) * b, Vector2(6.5, 4.5) * b, metal)
		"greathelm":
			ci.draw_rect(Rect2(head + Vector2(-7, -8) * b, Vector2(14, 15) * b), metal)
			ci.draw_line(head + Vector2(0, -1) * b, head + Vector2(7, -1) * b, Color(0.1, 0.1, 0.1), 1.6 * b)
			for i in 3:
				ci.draw_circle(head + Vector2(-3 - i * 2.5, -10 - i) * b, 2.6 * b, tm)
		"morion":
			_poly(ci, [head + Vector2(-11, -2) * b, head + Vector2(-6, -7) * b, head + Vector2(0, -12) * b, head + Vector2(6, -7) * b, head + Vector2(11, -2) * b], metal)
		"hood":
			_ellipse(ci, head + Vector2(-1, -1) * b, Vector2(8, 8) * b, _c(Color("4f5a33"), pose))
			ci.draw_circle(head + Vector2(2, 0.5) * b, 5.2 * b, _c(SKIN[seed % SKIN.size()], pose))
		"tricorne":
			_poly(ci, [head + Vector2(-10, -3) * b, head + Vector2(-3, -10) * b, head + Vector2(4, -10) * b, head + Vector2(10, -3) * b], Color(0.12, 0.12, 0.15))
			ci.draw_line(head + Vector2(-9, -3.5) * b, head + Vector2(9, -3.5) * b, pal[1], 1.5 * b)
		"brodie":
			_ellipse(ci, head + Vector2(0, -4) * b, Vector2(10.5, 3) * b, _c(Color("5c5f4a"), pose))
			_ellipse(ci, head + Vector2(0, -6) * b, Vector2(6, 3.5) * b, _c(Color("666a52"), pose))
		"visor":
			_ellipse(ci, head + Vector2(0, -1) * b, Vector2(8, 8) * b, metal)
			var g := tm.lightened(0.45)
			ci.draw_line(head + Vector2(-1, -1) * b, head + Vector2(8, -1) * b, g, 3.0 * b)


static func _weapon(ci: CanvasItem, kind: String, sh: Vector2, b: float, s: float, atk: float, pal: Array, tm: Color, skin: Color, pose: Dictionary, t: float) -> void:
	var wood := _c(Color("6b4a2b"), pose)
	var metal: Color = _c(pal[2], pose)
	var sleeve: Color = _c(pal[0], pose).darkened(0.1)
	match kind:
		"club", "sword", "shovel", "baton", "saber":
			# Overhead chop: arm angle from straight down (0) to overhead (~2.7 rad).
			var theta := 0.6
			if atk >= 0.0:
				if atk < 0.35:
					theta = lerpf(0.6, 2.7, ease(atk / 0.35, 0.6))
				elif atk < 0.5:
					theta = lerpf(2.7, 1.1, ease((atk - 0.35) / 0.15, 0.4))
				else:
					theta = lerpf(1.1, 0.6, (atk - 0.5) / 0.5)
			var hand := sh + Vector2(0, 15 * b).rotated(-theta)
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_circle(hand, 2.6 * b, skin)
			var dirv := (hand - sh).normalized().rotated(-0.7)
			var length := {"club": 20.0, "sword": 22.0, "shovel": 20.0, "baton": 18.0, "saber": 22.0}[kind] as float
			var tip := hand + dirv * length * b
			match kind:
				"club":
					ci.draw_line(hand, tip, wood, 4.5 * b)
					ci.draw_circle(tip, 4.5 * b, wood.darkened(0.2))
				"sword", "saber":
					ci.draw_line(hand - dirv * 3, hand + dirv * 3, metal.darkened(0.4), 5.0 * b)
					ci.draw_line(hand, tip, metal.lightened(0.25), 3.0 * b)
				"shovel":
					ci.draw_line(hand, tip, wood, 3.0 * b)
					_ellipse(ci, tip, Vector2(4, 6) * b, metal, dirv.angle())
				"baton":
					ci.draw_line(hand, tip, Color(0.15, 0.15, 0.2), 4.0 * b)
					ci.draw_line(hand + dirv * 8, tip, Color(tm.lightened(0.6), 0.9), 2.5 * b)
		"halberd" when atk < 0.0:
			# At rest the halberd stands upright: a tall vertical line in silhouette.
			var hand := sh + Vector2(10, 8) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_line(hand + Vector2(0, 22) * b, hand + Vector2(0, -44) * b, wood, 2.8 * b)
			var top := hand + Vector2(0, -44) * b
			_poly(ci, [top + Vector2(0, -2), top + Vector2(8, 3), top + Vector2(8, 12), top + Vector2(0, 8)], metal)
			_poly(ci, [top + Vector2(-1.5, 0), top + Vector2(0, -10), top + Vector2(1.5, 0)], metal.lightened(0.2))
			ci.draw_circle(hand, 2.6 * b, skin)
		"spear", "halberd", "lance":
			# Thrust: pulled back, then driven forward.
			var reach := s * 9.0
			var hand := sh + Vector2(9 + reach, 9) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_circle(hand, 2.6 * b, skin)
			var dirv := Vector2(1, -0.12).normalized()
			var back := hand - dirv * 20 * b
			var tip := hand + dirv * (26.0 if kind != "lance" else 36.0) * b
			ci.draw_line(back, tip, wood, 2.6 * b)
			if kind == "halberd":
				_poly(ci, [tip + Vector2(-8, -2), tip + Vector2(-2, -9), tip + Vector2(0, -2), tip + Vector2(-2, 5)], metal)
			_poly(ci, [tip + Vector2(0, -2.6) * b, tip + Vector2(8, 0) * b, tip + Vector2(0, 2.6) * b], metal.lightened(0.2))
			if kind == "lance":
				ci.draw_line(back + dirv * 8, back + dirv * 14, tm, 4.0 * b)
		"javelin":
			var ang := -0.9 + 1.4 * maxf(0.0, s)
			var hand := sh + Vector2(-2, -10 * b).rotated(ang) if s < 0.5 else sh + Vector2(10, 2) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_circle(hand, 2.6 * b, skin)
			if atk < 0.0 or atk < 0.4 or atk > 0.9:
				ci.draw_line(hand + Vector2(-14, 4) * b, hand + Vector2(16, -3) * b, wood, 2.2 * b)
				_poly(ci, [hand + Vector2(16, -5) * b, hand + Vector2(22, -4) * b, hand + Vector2(16, -1) * b], metal)
		"sling":
			var hand := sh + Vector2(2, -14) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_circle(hand, 2.6 * b, skin)
			var spin := t * (22.0 if atk >= 0.0 and atk < 0.4 else 5.0)
			var stone := hand + Vector2(cos(spin), sin(spin) * 0.5) * 10 * b
			ci.draw_line(hand, stone, Color("c9b28a"), 1.2)
			ci.draw_arc(hand, 10 * b, 0, TAU, 16, Color(0.8, 0.75, 0.6, 0.35), 1.5)
			if atk < 0.4 or atk > 0.9:
				ci.draw_circle(stone, 2.2 * b, Color("7b7466"))
		"bow":
			var draw_back := clampf(-s, 0.0, 1.0) * 9.0
			var hand := sh + Vector2(15, 1) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			var top := hand + Vector2(-2, -19) * b
			var bot := hand + Vector2(-2, 19) * b
			var pts := PackedVector2Array()
			for i in 9:
				var u := i / 8.0
				pts.append(top.lerp(bot, u) + Vector2(sin(u * PI) * 7 * b, 0))
			ci.draw_polyline(pts, wood, 2.6 * b)
			var nock := hand + Vector2(-4 - draw_back, 0) * b
			ci.draw_polyline(PackedVector2Array([top, nock, bot]), Color(0.9, 0.88, 0.8, 0.9), 1.0)
			_limb(ci, sh + Vector2(-1, 1), nock, 4.0 * b, sleeve.darkened(0.2))
			if atk < 0.35:
				ci.draw_line(nock, nock + Vector2(24, 0) * b, wood.lightened(0.3), 1.5)
			ci.draw_circle(hand, 2.6 * b, skin)
		"crew":
			# Hands forward on the engine.
			var hand := sh + Vector2(14, 8) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_circle(hand, 2.6 * b, skin)
		"musket", "rifle", "pulse":
			var kick := maxf(0.0, s) * 4.0
			var hand := sh + Vector2(12 - kick, 4) * b
			var stock := sh + Vector2(-2 - kick, 3) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			var length := {"musket": 34.0, "rifle": 30.0, "pulse": 28.0}[kind] as float
			var muzzle := stock + Vector2(length, -2) * b
			var body := Color(0.18, 0.18, 0.2) if kind == "pulse" else wood
			ci.draw_line(stock, stock + Vector2(12, 0) * b, body, 5.0 * b)
			ci.draw_line(stock + Vector2(8, -1) * b, muzzle, metal.darkened(0.3) if kind != "pulse" else Color(0.25, 0.27, 0.32), 3.0 * b)
			if kind == "pulse":
				ci.draw_line(stock + Vector2(12, -3) * b, stock + Vector2(24, -3) * b, Color(tm.lightened(0.6), 0.6 + 0.4 * sin(t * 8.0)), 2.0 * b)
			if kind == "rifle":
				ci.draw_line(muzzle, muzzle + Vector2(7, 0) * b, metal.lightened(0.3), 1.2)
			ci.draw_circle(hand, 2.6 * b, skin)


# ---------------------------------------------------------------------------
# Mounted rig (Tusk Rider, Knight, Cuirassier)

static func quadruped(ci: CanvasItem, kind: String, team: Color, pose: Dictionary, seed: int) -> Vector2:
	var mv := _mv(pose)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var boar := kind == "boar"
	var col := _c({"boar": Color("5b4130"), "warhorse": Color("d8d2c4"), "horse": Color("6a4a31")}[kind], pose)
	var dark := col.darkened(0.35)
	var tm := _c(team, pose)
	var L := 21.0 if boar else 24.0
	var H := 22.0 if boar else 33.0
	var bob := lerpf(sin(t * 1.5 + seed) * 0.5, absf(sin(walk * 2.0)) * 2.0, mv)
	var lunge := maxf(0.0, swing(atk)) * 5.0
	var c := Vector2(lunge, -H - 10 + bob)
	_shadow(ci, 32)
	# Legs: far pair first (darker), then near pair. Front legs bend forward at the knee, hind legs
	# bend back at the hock; each ends in a fetlock and hoof.
	for pass_i in 2:
		for front in [false, true]:
			var near := pass_i == 1
			var ph: float = walk + (0.0 if near else PI) + (PI * 0.5 if front else 0.0)
			var swing_a := lerpf(0.05, sin(ph) * 0.5, mv)
			var lift := maxf(0.0, cos(ph)) * 0.8 * mv
			var top := c + Vector2(L * (0.62 if front else -0.62), 5)
			var lc := col.darkened(0.28 if not near else 0.0)
			var upper := top + Vector2(0, H * 0.42).rotated(-swing_a)
			var lower_dir := -swing_a + (lift if front else -lift * 0.6) + (0.0 if front else 0.35)
			var fet := upper + Vector2(0, H * 0.42).rotated(lower_dir)
			var hoof := fet + Vector2(1.5, H * 0.14).rotated(lower_dir * 0.5)
			_seg(ci, top, upper, (9.0 if boar else 8.0), 5.2, lc)
			_seg(ci, upper, fet, 4.6, 3.4, lc)
			_seg(ci, fet, hoof, 3.4, 3.8, lc.darkened(0.1))
			ci.draw_rect(Rect2(hoof + Vector2(-2.5, -1.2), Vector2(5.5, 2.8)), Color(0.12, 0.1, 0.08))
		if pass_i == 0:
			# Tail behind the far legs.
			if boar:
				ci.draw_polyline(PackedVector2Array([c + Vector2(-L - 2, -4), c + Vector2(-L - 6, -2 + sin(t * 6.0)), c + Vector2(-L - 5, 3)]), dark, 1.5)
			else:
				for k in 5:
					var sway := sin(t * 2.5 + k * 0.4) * 3.0 + mv * 4.0
					ci.draw_polyline(PackedVector2Array([c + Vector2(-L - 2, -6 + k), c + Vector2(-L - 9 - sway * 0.5, 2 + k), c + Vector2(-L - 12 - sway, 14 + k * 1.5)]), dark.darkened(0.1 * (k % 2)), 2.0)
			# Barrel: chest, withers, back, croup, hindquarters, belly.
			var body := [c + Vector2(L + 6, -2), c + Vector2(L - 2, -11), c + Vector2(L * 0.2, -12 if not boar else -15), c + Vector2(-L * 0.6, -11),
				c + Vector2(-L - 5, -6), c + Vector2(-L - 6, 4), c + Vector2(-L * 0.5, 10), c + Vector2(L * 0.4, 10), c + Vector2(L + 5, 6)]
			_shade_poly(ci, body, col)
			if not boar:
				# Neck up to the head.
				var neck_top := c + Vector2(L + 8, -24) + Vector2(lunge * 0.4, 0)
				_shade_poly(ci, [c + Vector2(L - 4, -10), c + Vector2(L + 6, -4), neck_top + Vector2(5, 4), neck_top + Vector2(-2, -1)], col)
				var hd := neck_top + Vector2(4, -1)
				_shade_poly(ci, [hd + Vector2(-4, -4), hd + Vector2(3, -6), hd + Vector2(13, 3), hd + Vector2(12, 7), hd + Vector2(6, 7), hd + Vector2(-3, 3)], col)
				ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(-2, -4), hd + Vector2(0, -10), hd + Vector2(2, -5)]), dark)
				ci.draw_circle(hd + Vector2(2.5, -1.5), 1.2, Color(0.05, 0.04, 0.04))
				ci.draw_circle(hd + Vector2(11.5, 4.5), 0.9, Color(0.1, 0.07, 0.06))
				# Bridle and reins in team colour.
				ci.draw_polyline(PackedVector2Array([hd + Vector2(-1, -3), hd + Vector2(8, 3), hd + Vector2(9, 6)]), tm.darkened(0.2), 1.2)
				ci.draw_line(hd + Vector2(8, 3), c + Vector2(4, -14), Color(0.25, 0.18, 0.12), 1.0)
				# Mane strands lag behind (secondary motion).
				for k in 6:
					var mp := (c + Vector2(L - 4, -11)).lerp(neck_top + Vector2(-2, -2), k / 5.0)
					ci.draw_line(mp, mp + Vector2(-5 - mv * 2.0, 3 + sin(t * 4.0 + k) * 1.5), dark, 2.2)
			else:
				# Boar head: heavy snout, tusks, bristled back.
				var hd := c + Vector2(L + 4, -2) + Vector2(lunge * 0.5, 0)
				_shade_poly(ci, [hd + Vector2(-4, -9), hd + Vector2(6, -6), hd + Vector2(14, 1), hd + Vector2(13, 6), hd + Vector2(2, 7), hd + Vector2(-4, 4)], col)
				ci.draw_rect(Rect2(hd + Vector2(12, 0), Vector2(3, 5)), col.darkened(0.3))
				ci.draw_polyline(PackedVector2Array([hd + Vector2(10, 5), hd + Vector2(15, 2), hd + Vector2(14, -3)]), Color("efe6cf"), 2.4)
				ci.draw_circle(hd + Vector2(4, -3), 1.1, Color(0.05, 0.04, 0.04))
				ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(-2, -8), hd + Vector2(-1, -13), hd + Vector2(2, -8)]), dark)
				for k in 8:
					var bp := c + Vector2(-L * 0.6 + k * 4.5, -12 - (2 if k % 2 == 0 else 0))
					ci.draw_line(bp, bp + Vector2(-2, -4), dark, 1.6)
	if kind == "warhorse":
		# Caparison in team colour with a scalloped hem and gold trim.
		_shade_poly(ci, [c + Vector2(-L - 5, -9), c + Vector2(L + 3, -9), c + Vector2(L + 6, 14), c + Vector2(-L - 7, 14)], tm)
		for k in 6:
			var hx := -L - 5 + k * (2 * L + 10) / 6.0
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(hx, 14), c + Vector2(hx + 4, 19), c + Vector2(hx + 8, 14)]), tm.darkened(0.25))
		ci.draw_line(c + Vector2(-L - 5, -5), c + Vector2(L + 3, -5), Color("d9c27a"), 2.0)
		ci.draw_line(c + Vector2(-L - 6, 11), c + Vector2(L + 5, 11), Color("d9c27a"), 1.5)
	else:
		# Saddle blanket.
		_shade_poly(ci, [c + Vector2(-9, -13), c + Vector2(8, -13), c + Vector2(9, -4), c + Vector2(-10, -4)], tm)
		ci.draw_rect(Rect2(c + Vector2(-6, -15), Vector2(12, 3)), Color(0.3, 0.2, 0.12))
	return c + Vector2(-2, -10)


static func mounted(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var saddle := quadruped(ci, st.get("beast", "horse"), team, pose, seed)
	var p := pose.duplicate()
	p["moving"] = false
	p["move"] = 0.0
	_rider(ci, st, pal, team, p, seed, saddle)


static func _rider(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int, at: Vector2) -> void:
	# Upper body only, offset to the saddle; legs drawn as a straddling thigh.
	var cloth: Color = _c(pal[1], pose)
	ci.draw_line(at + Vector2(0, -2), at + Vector2(8, 10), cloth, 6.0)
	var shifted := {}
	for k in pose:
		shifted[k] = pose[k]
	_offset_humanoid(ci, st, pal, team, shifted, seed, at + Vector2(0, 27))


static func _offset_humanoid(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int, offset: Vector2) -> void:
	# The humanoid rig draws around a hip at y≈−25; drawing it with a translated transform keeps one rig.
	var xf := Transform2D(0.0, offset)
	_push(ci, xf)
	humanoid(ci, st, pal, team, pose, seed, 1.0, false)
	_pop(ci)


## A tiny transform stack on top of draw_set_transform_matrix (CanvasItem has no push/pop).
static var _stack: Array[Transform2D] = []
static var _current := Transform2D.IDENTITY


static func begin(ci: CanvasItem, xf: Transform2D) -> void:
	_stack.clear()
	_current = xf
	ci.draw_set_transform_matrix(xf)


static func _push(ci: CanvasItem, local: Transform2D) -> void:
	_stack.append(_current)
	_current = _current * local
	ci.draw_set_transform_matrix(_current)


static func _pop(ci: CanvasItem) -> void:
	_current = _stack.pop_back() if not _stack.is_empty() else Transform2D.IDENTITY
	ci.draw_set_transform_matrix(_current)


# ---------------------------------------------------------------------------
# Vehicles and engines

static func chariot(ci: CanvasItem, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var p := pose.duplicate()
	_push(ci, Transform2D(0.0, Vector2(26, 0)) * Transform2D(0.0, Vector2(0.78, 0.78), 0.0, Vector2.ZERO))
	quadruped(ci, "horse", team, p, seed)
	_pop(ci)
	var wood := _c(Color("7a5532"), pose)
	var metal: Color = _c(pal[2], pose)
	var roll: float = pose.get("walk", 0.0) * 1.3
	ci.draw_line(Vector2(-10, -18), Vector2(18, -24), wood.darkened(0.2), 3.0)
	_poly(ci, [Vector2(-30, -16), Vector2(-6, -16), Vector2(-4, -36), Vector2(-26, -34)], metal)
	_poly(ci, [Vector2(-28, -19), Vector2(-8, -19), Vector2(-7, -31), Vector2(-25, -30)], _c(team, pose))
	_wheel(ci, Vector2(-18, -13), 13, roll, wood, metal)
	var st := {"helmet": "crest", "weapon": "spear"}
	_offset_humanoid(ci, st, pal, team, pose, seed, Vector2(-16, 4))


static func car(ci: CanvasItem, pal: Array, team: Color, pose: Dictionary) -> void:
	var hull := _c(Color("5d6150"), pose)
	var roll: float = pose.get("walk", 0.0) * 1.6
	var kick := maxf(0.0, swing(pose.get("atk", -1.0))) * 4.0
	var bob := sin(pose.get("t", 0.0) * 9.0) * 0.6 * _mv(pose)
	_shadow(ci, 40)
	_push(ci, Transform2D(0.0, Vector2(0, bob)))
	_poly(ci, [Vector2(-38, -12), Vector2(34, -12), Vector2(42, -24), Vector2(30, -38), Vector2(-30, -38), Vector2(-40, -26)], hull)
	ci.draw_line(Vector2(-30, -38), Vector2(30, -38), hull.lightened(0.2), 2.0)
	ci.draw_rect(Rect2(Vector2(10, -34), Vector2(12, 6)), Color(0.1, 0.1, 0.1))
	_poly(ci, [Vector2(-34, -24), Vector2(-10, -24), Vector2(-10, -30), Vector2(-32, -30)], _c(team, pose))
	_ellipse(ci, Vector2(-4, -44), Vector2(15, 8), hull.darkened(0.15))
	ci.draw_line(Vector2(6, -46), Vector2(34 - kick, -48), Color(0.2, 0.2, 0.2), 4.0)
	_pop(ci)
	for x in [-26.0, 2.0, 28.0]:
		_wheel(ci, Vector2(x, -10), 10, roll, Color(0.14, 0.14, 0.14), Color(0.5, 0.5, 0.45), 5)


static func mech(ci: CanvasItem, team: Color, pose: Dictionary) -> void:
	var mv := _mv(pose)
	var walk: float = pose.get("walk", 0.0) * 0.8
	var t: float = pose.get("t", 0.0)
	var armour := _c(Color("596274"), pose)
	var glow := team.lightened(0.5)
	var kick := maxf(0.0, swing(pose.get("atk", -1.0))) * 5.0
	var bob := lerpf(sin(t * 1.3) * 0.8, absf(sin(walk)) * 3.0, mv)
	var hip := Vector2(0, -48 + bob)
	_shadow(ci, 30)
	for i in [1, 0]:
		var ph: float = walk + PI * i
		var a := lerpf(0.1 if i == 0 else -0.1, sin(ph) * 0.5, mv)
		var knee := hip + Vector2(10, 22).rotated(-a)
		var ankle := knee + Vector2(-10, 22).rotated(-a + maxf(0.0, cos(ph)) * 0.6 * mv)
		var c := armour.darkened(0.3 if i == 1 else 0.0)
		_limb(ci, hip, knee, 9.0, c)
		_limb(ci, knee, ankle, 7.0, c)
		_poly(ci, [ankle + Vector2(-10, 4), ankle + Vector2(12, 4), ankle + Vector2(8, -2), ankle + Vector2(-6, -2)], c.darkened(0.2))
	_poly(ci, [hip + Vector2(-22, 2), hip + Vector2(20, 2), hip + Vector2(26, -22), hip + Vector2(8, -36), hip + Vector2(-20, -30)], armour)
	_poly(ci, [hip + Vector2(-18, -6), hip + Vector2(0, -6), hip + Vector2(0, -20), hip + Vector2(-16, -22)], _c(team, pose))
	ci.draw_line(hip + Vector2(6, -26), hip + Vector2(22, -22), Color(glow, 0.9), 3.0)
	ci.draw_line(hip + Vector2(12, -8), hip + Vector2(46 - kick, -12), armour.darkened(0.35), 7.0)
	ci.draw_line(hip + Vector2(30 - kick, -12), hip + Vector2(46 - kick, -12), Color(glow, 0.5 + 0.4 * sin(t * 7.0)), 2.5)


static func _crew(ci: CanvasItem, pal: Array, team: Color, pose: Dictionary, seed: int, at: Vector2, helmet: String) -> void:
	_push(ci, Transform2D(0.0, Vector2(0.85, 0.85), 0.0, at))
	humanoid(ci, {"helmet": helmet, "weapon": "crew"}, pal, team, pose, seed)
	_pop(ci)


static func ram(ci: CanvasItem, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var wood := _c(Color("75512f"), pose)
	var roof := _c(Color("8c6b3f"), pose)
	var thrust := maxf(0.0, swing(pose.get("atk", -1.0))) * 14.0 - maxf(0.0, -swing(pose.get("atk", -1.0))) * 6.0
	var roll: float = pose.get("walk", 0.0)
	_shadow(ci, 38)
	_crew(ci, pal, team, pose, seed, Vector2(-26, 0), "hair")
	ci.draw_line(Vector2(-30 + thrust, -24), Vector2(34 + thrust, -24), wood.darkened(0.15), 8.0)
	ci.draw_circle(Vector2(36 + thrust, -24), 6.0, _c(pal[2], pose))
	_poly(ci, [Vector2(-34, -16), Vector2(24, -16), Vector2(18, -42), Vector2(-8, -54), Vector2(-30, -42)], roof)
	for i in 5:
		ci.draw_line(Vector2(-30 + i * 11, -18), Vector2(-24 + i * 9, -46), roof.darkened(0.25), 2.0)
	_poly(ci, [Vector2(-18, -30), Vector2(4, -30), Vector2(2, -40), Vector2(-14, -42)], _c(team, pose))
	for x in [-24.0, 14.0]:
		_wheel(ci, Vector2(x, -9), 9, roll, wood, _c(pal[2], pose), 5)


static func trebuchet(ci: CanvasItem, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var wood := _c(Color("7a5532"), pose)
	var atk: float = pose.get("atk", -1.0)
	var arm := -2.3
	if atk >= 0.0:
		arm = lerpf(-2.3, -0.5, ease(clampf((atk - 0.2) / 0.3, 0.0, 1.0), 0.3)) if atk < 0.7 else lerpf(-0.5, -2.3, (atk - 0.7) / 0.3)
	var roll: float = pose.get("walk", 0.0)
	_shadow(ci, 40)
	ci.draw_line(Vector2(-34, -12), Vector2(34, -12), wood.darkened(0.2), 7.0)
	ci.draw_line(Vector2(-22, -12), Vector2(0, -70), wood, 5.0)
	ci.draw_line(Vector2(22, -12), Vector2(0, -70), wood, 5.0)
	var pivot := Vector2(0, -70)
	var long_end := pivot + Vector2(56, 0).rotated(arm)
	var short_end := pivot + Vector2(-18, 0).rotated(arm)
	ci.draw_line(short_end, long_end, wood.lightened(0.1), 5.0)
	ci.draw_rect(Rect2(short_end + Vector2(-9, 0), Vector2(18, 16)), _c(pal[2], pose).darkened(0.3))
	ci.draw_line(long_end, long_end + Vector2(0, 14).rotated(arm * 0.3), Color("c9b28a"), 1.5)
	ci.draw_rect(Rect2(Vector2(-12, -36), Vector2(24, 10)), _c(team, pose))
	for x in [-26.0, 26.0]:
		_wheel(ci, Vector2(x, -8), 8, roll, wood, _c(pal[2], pose), 5)
	_crew(ci, pal, team, pose, seed, Vector2(-44, 0), "kettle")


static func mortar(ci: CanvasItem, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var kick := maxf(0.0, swing(pose.get("atk", -1.0))) * 4.0
	_shadow(ci, 26)
	_crew(ci, pal, team, pose, seed, Vector2(-18, 0), "tricorne")
	ci.draw_rect(Rect2(Vector2(-4, -8), Vector2(28, 8)), _c(Color("5a3d24"), pose))
	var base := Vector2(10, -8)
	var dirv := Vector2(0.55, -1).normalized()
	ci.draw_line(base - dirv * kick, base + dirv * (26 - kick), _c(Color(0.22, 0.22, 0.24), pose), 11.0)
	ci.draw_circle(base + dirv * (26 - kick), 6.0, Color(0.12, 0.12, 0.12))
	ci.draw_rect(Rect2(Vector2(-2, -6), Vector2(8, 4)), _c(team, pose))


static func howitzer(ci: CanvasItem, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var kick := maxf(0.0, swing(pose.get("atk", -1.0))) * 8.0
	var gun := _c(Color("5b604a"), pose)
	var roll: float = pose.get("walk", 0.0)
	_shadow(ci, 36)
	_crew(ci, pal, team, pose, seed, Vector2(-34, 0), "brodie")
	ci.draw_line(Vector2(-30, -6), Vector2(4, -20), gun.darkened(0.3), 6.0)
	ci.draw_line(Vector2(0 - kick, -28), Vector2(46 - kick, -40), gun, 8.0)
	_poly(ci, [Vector2(4, -12), Vector2(16, -12), Vector2(18, -46), Vector2(6, -44)], gun.lightened(0.1))
	ci.draw_rect(Rect2(Vector2(6, -34), Vector2(10, 8)), _c(team, pose))
	_wheel(ci, Vector2(0, -14), 14, roll, Color(0.2, 0.18, 0.15), gun, 8)


static func rail(ci: CanvasItem, team: Color, pose: Dictionary) -> void:
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var armour := _c(Color("4b5262"), pose)
	var glow := team.lightened(0.55)
	var charge := clampf(atk / 0.35, 0.0, 1.0) if atk >= 0.0 and atk < 0.35 else 0.0
	_shadow(ci, 40)
	_poly(ci, [Vector2(-40, -4), Vector2(38, -4), Vector2(44, -14), Vector2(-44, -14)], Color(0.14, 0.15, 0.18))
	for i in 7:
		ci.draw_circle(Vector2(-36 + i * 12, -8), 4.5, Color(0.25, 0.26, 0.3))
	_poly(ci, [Vector2(-32, -14), Vector2(24, -14), Vector2(18, -30), Vector2(-28, -30)], armour)
	ci.draw_rect(Rect2(Vector2(-26, -26), Vector2(18, 8)), _c(team, pose))
	ci.draw_line(Vector2(-10, -34), Vector2(58, -52), armour.darkened(0.3), 6.0)
	ci.draw_line(Vector2(-10, -38), Vector2(58, -56), armour.lightened(0.1), 3.0)
	for i in 4:
		var c := Vector2(4 + i * 12, -40 - i * 3.2)
		ci.draw_circle(c, 3.0 + charge * 2.0, Color(glow, 0.4 + 0.3 * sin(t * 6.0 + i) + charge * 0.3))
