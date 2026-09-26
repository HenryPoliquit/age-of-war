class_name UnitArt
extends RefCounted
## Procedural "paper-doll" unit figures: a small set of rigs (humanoid, rider on a beast, chariot,
## siege engines, walkers) dressed per race and unit slot (RaceLook) — GDD §13.2's modular-rig idea,
## drawn with canvas calls until painted parts exist. Local space: feet at y = 0, facing +x, up is −y.
##
## pose = {walk: float (stride phase, radians), move: float (0 idle … 1 walking, blended by the caller), atk: float (0..1 attack progress, <0 idle),
##         t: float (seconds, for idle motion), flash: float (0..1 hit flash)}

## Human palettes, kept for callers that dress non-unit props (base defenders).
const AGE_CLOTH: Array = RaceLook.CLOTH[&"human"]

## Per-rig facts the view needs: visual height, projectile, muzzle (local, pre-scale), whether a
## death leaves a wreck (no topple) and what it looks like.
const RIGS := {
	"humanoid": {"h": 66.0},
	"mounted": {"h": 82.0},
	"chariot": {"h": 82.0, "wreck": "siege"},
	"ram": {"h": 56.0, "wreck": "siege"},
	"catapult": {"h": 76.0, "wreck": "siege", "shot": "shell", "muzzle": Vector2(8, -80)},
	"ballista": {"h": 60.0, "wreck": "siege", "shot": "javelin", "muzzle": Vector2(38, -40)},
	"trebuchet": {"h": 96.0, "wreck": "siege", "shot": "shell", "muzzle": Vector2(32, -88)},
	"cannon": {"h": 56.0, "wreck": "blast", "shot": "ball", "muzzle": Vector2(46, -34), "gun": true},
	"steamtank": {"h": 72.0, "wreck": "blast", "shot": "bolt", "muzzle": Vector2(42, -46), "gun": true},
	"golem": {"h": 90.0, "wreck": "blast"},
	"treant": {"h": 104.0},
	"skycannon": {"h": 70.0, "wreck": "blast", "shot": "bolt", "muzzle": Vector2(52, -60), "gun": true},
	"obelisk": {"h": 100.0, "wreck": "siege", "shot": "bolt", "muzzle": Vector2(4, -80), "gun": true},
}

## Projectile per hand weapon (melee weapons fire nothing).
const SHOTS := {"sling": "stone", "javelin": "javelin", "throwing_axe": "axe", "bow": "arrow", "starbow": "bolt",
	"crossbow": "arrow", "musket": "bullet", "arcane_rifle": "bolt", "rune_rifle": "bolt", "staff": "bolt"}

const ROLE_FALLBACK := {
	"vanguard": {"rig": "humanoid", "helmet": "cap", "weapon": "sword", "shield": "round"},
	"ranged": {"rig": "humanoid", "helmet": "cap", "weapon": "bow"},
	"heavy": {"rig": "mounted", "beast": "horse", "helmet": "greathelm", "weapon": "lance"},
	"siege": {"rig": "ram", "variant": "wood"},
}

## Role silhouettes (PRD §11: role identifiable by shape alone): Vanguards are broad and shielded
## (or carry an upright polearm); Ranged are slighter and carry a pack on the back.
const ROLE_BUILD := {"vanguard": 1.16, "ranged": 0.94}

const CHOP := ["club", "sword", "gladius", "shovel", "baton", "saber", "axe", "hammer", "leafblade", "spellsword", "rune_hammer"]
const ENCLOSED := ["greathelm", "visor", "hood", "rune"]

static var _style_cache := {}
## Race being drawn (set by draw_unit; rigs that add crew read it).
static var _look: Dictionary = RaceLook.BODY[&"human"]


static func style_for(def: UnitDef, race: StringName = &"human") -> Dictionary:
	var key := "%s/%s" % [race, def.id]
	if _style_cache.has(key):
		return _style_cache[key]
	var st: Dictionary = RaceLook.style(race, def.id).duplicate()
	if st.is_empty():
		st = ROLE_FALLBACK.get(def.role, ROLE_FALLBACK.vanguard).duplicate()
	if not st.has("build") and ROLE_BUILD.has(def.role):
		st["build"] = ROLE_BUILD[def.role]
	var info: Dictionary = RIGS.get(st.rig, {})
	if not st.has("shot"):
		st["shot"] = SHOTS.get(st.get("weapon", ""), info.get("shot", "")) if st.rig in ["humanoid"] else info.get("shot", "")
	st["race"] = race
	_style_cache[key] = st
	return st


## Visual height in px (for HP bars and selection).
static func height_for(def: UnitDef, race: StringName = &"human") -> float:
	var st := style_for(def, race)
	var h: float = RIGS.get(st.rig, {}).get("h", 50.0)
	var body: Vector2 = RaceLook.look(race).body
	if st.rig == "humanoid":
		return h * body.y
	if st.rig == "mounted":
		return h + (body.y - 1.0) * 40.0
	return h


## Muzzle in unit-local space (feet origin, facing +x).
static func muzzle_for(st: Dictionary) -> Vector2:
	return st.get("muzzle", RIGS.get(st.rig, {}).get("muzzle", Vector2(22, -34)))


## "blast", "siege" or "" (a body that falls over).
static func wreck_kind(st: Dictionary) -> String:
	return RIGS.get(st.rig, {}).get("wreck", "")


## Attack animation shape: anticipation (0→−1), contact at 0.35–0.55 (−1→+1), recovery (+1→0).
static func swing(atk: float) -> float:
	if atk < 0.0:
		return 0.0
	if atk < 0.35:
		return -ease(atk / 0.35, 0.6)
	if atk < 0.55:
		return lerpf(-1.0, 1.0, ease((atk - 0.35) / 0.2, 0.4))
	return lerpf(1.0, 0.0, ease((atk - 0.55) / 0.45, 1.6))


static func draw_unit(ci: CanvasItem, def: UnitDef, team: Color, pose: Dictionary, seed: int = 0, race: StringName = &"human") -> void:
	var st := style_for(def, race)
	_look = RaceLook.look(race)
	var pal: Array = RaceLook.palette(race, def.age)
	match st.rig:
		"humanoid":
			humanoid(ci, st, pal, team, pose, seed)
		"mounted":
			mounted(ci, st, pal, team, pose, seed)
		"chariot":
			chariot(ci, st, pal, team, pose, seed)
		"ram":
			ram(ci, st, pal, team, pose, seed)
		"catapult":
			catapult(ci, st, pal, team, pose, seed)
		"ballista":
			ballista(ci, st, pal, team, pose, seed)
		"trebuchet":
			trebuchet(ci, st, pal, team, pose, seed)
		"cannon":
			cannon(ci, st, pal, team, pose, seed)
		"steamtank":
			steamtank(ci, pal, team, pose)
		"golem":
			golem(ci, pal, team, pose)
		"treant":
			treant(ci, team, pose, seed)
		"skycannon":
			skycannon(ci, pal, team, pose)
		"obelisk":
			obelisk(ci, st, pal, team, pose, seed)
	_look = RaceLook.BODY[&"human"]


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


static func _rivets(ci: CanvasItem, a: Vector2, b: Vector2, n: int, col: Color, r := 1.1) -> void:
	for i in n:
		ci.draw_circle(a.lerp(b, (i + 0.5) / n), r, col)


## Soft additive-looking halo (drawn as stacked translucent discs; the glow pass adds bloom).
static func _halo(ci: CanvasItem, c: Vector2, r: float, col: Color, k := 1.0) -> void:
	for i in 3:
		ci.draw_circle(c, r * (1.0 - i * 0.28), Color(col, (0.16 + i * 0.16) * k))


# ---------------------------------------------------------------------------
# Humanoid rig (Vanguard, Ranged, riders, crews)

static func humanoid(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int, scale := 1.0, legs := true) -> void:
	var lk := _look
	var body: Vector2 = lk.body
	var build: float = st.get("build", 1.0) * scale
	var mv := _mv(pose)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var skins: Array = lk.skin
	var hairs: Array = lk.hair
	var skin: Color = _c(skins[seed % skins.size()], pose)
	var hair: Color = _c(hairs[(seed / 3) % hairs.size()], pose)
	var cloth: Color = _c(pal[0], pose)
	var trim: Color = _c(pal[1], pose)
	var metal: Color = _c(pal[2], pose)
	var tm: Color = _c(team, pose)
	var helmet: String = st.get("helmet", "")
	var armoured: bool = helmet in ["crest", "kettle", "greathelm", "morion", "visor", "galea", "conical", "leaf", "dwarf", "horned", "rune"]
	var leather := _c(Color("4a3322"), pose)
	var bob := lerpf(sin(t * 2.1 + seed) * 0.7, absf(sin(walk)) * 2.2, mv)
	var hip := Vector2(0, -30 * build + bob * 0.5)
	var sh := Vector2(1.5, -50 * build + bob)
	var b := build
	# Race proportions scale legs and torso about the feet (or the hip for riders); head and arms
	# keep their own proportions so a dwarf reads broad, not squashed.
	var pivot := Vector2.ZERO if legs else hip
	_push(ci, Transform2D(0.0, pivot) * Transform2D(0.0, body, 0.0, Vector2.ZERO) * Transform2D(0.0, -pivot))
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
	if st.get("cape", false) or helmet == "greathelm":
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
		# Breastplate / hauberk; Roman plate reads as horizontal bands, the rest as mail rows.
		_shade_poly(ci, [hip + Vector2(-5.5, -5) * b, hip + Vector2(6.5, -5) * b, sh + Vector2(8, 4) * b, sh + Vector2(6, -0.5) * b,
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
	_shade_poly(ci, [sh + Vector2(-3, 2) * b, sh + Vector2(5, 2) * b, hip + Vector2(5.5, 8) * b, hip + Vector2(2, 5.5) * b,
		hip + Vector2(-1.5, 8.5) * b, hip + Vector2(-3.5, 2) * b], tm)
	ci.draw_line(hip + Vector2(5.5, 8) * b, hip + Vector2(2, 5.5) * b, tm.darkened(0.3), 1.0 * b)
	ci.draw_line(hip + Vector2(-6, -1) * b, hip + Vector2(6.8, -1) * b, leather, 2.4 * b)
	ci.draw_rect(Rect2(hip + Vector2(1.2, -2.4) * b, Vector2(2.6, 2.8) * b), _c(Color("c9a45c"), pose))
	if armoured:
		# Pauldron.
		_shade_poly(ci, _ellipse_pts(sh + Vector2(1, 1.5) * b, Vector2(6, 4.2) * b, -0.2), metal.lightened(0.05))
	_pop(ci)
	sh = pivot + (sh - pivot) * body
	var hb: float = b * lk.head
	var head := sh + Vector2(1.8, -9.5) * hb
	# Long hair falls behind the neck (elves), under any open helmet.
	if lk.long_hair and helmet not in ["hood", "greathelm", "visor"]:
		var sway := sin(t * 2.0 + seed) * 1.2 + mv * 1.5
		_shade_poly(ci, [head + Vector2(-5.5, -3) * hb, head + Vector2(1, -5) * hb, head + Vector2(-1, 6) * hb,
			sh + Vector2(-5 - sway, 8) * b, sh + Vector2(-9 - sway, 5) * b, head + Vector2(-7.5, 3) * hb], hair)
	# Neck and head: skull, jaw, ear, brow, eye, nose.
	ci.draw_rect(Rect2(sh + Vector2(-0.5, -4.5) * b, Vector2(4.5, 4.5) * b), skin.darkened(0.15))
	_shade_poly(ci, _ellipse_pts(head, Vector2(5.4, 6.0) * hb, 0.0), skin)
	_shade_poly(ci, [head + Vector2(-2.5, 3) * hb, head + Vector2(4.8, 2.2) * hb, head + Vector2(4.2, 5.2) * hb, head + Vector2(0.5, 6.4) * hb], skin.darkened(0.06))
	if lk.ears == "round":
		ci.draw_circle(head + Vector2(-1.4, 0.6) * hb, 1.5 * hb, skin.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([head + Vector2(5.0, -0.8) * hb, head + Vector2(7.0, 1.6) * hb, head + Vector2(5.0, 2.2) * hb]), skin.darkened(0.05))
	ci.draw_line(head + Vector2(2.0, -2.2) * hb, head + Vector2(4.6, -2.0) * hb, Color(0.15, 0.1, 0.07, 0.8), 0.9 * hb)
	ci.draw_circle(head + Vector2(3.4, -0.9) * hb, 0.75 * hb, Color(0.08, 0.06, 0.05))
	ci.draw_line(head + Vector2(3.2, 3.6) * hb, head + Vector2(4.6, 3.4) * hb, Color(0.3, 0.15, 0.12, 0.7), 0.7 * hb)
	var open_face := helmet not in ENCLOSED
	match int(lk.beard):
		1:
			if helmet not in ["greathelm", "visor"]:
				_dwarf_beard(ci, head, hb, hair, t, seed)
		3:
			if seed % 3 == 0 and helmet in ["hair", "band", "cap", "kettle", "morion", "tricorne", "brodie", "galea", "conical", "goggles"]:
				_shade_poly(ci, [head + Vector2(-2.5, 2) * hb, head + Vector2(4.8, 2.4) * hb, head + Vector2(3.5, 6.8) * hb, head + Vector2(0.5, 7.4) * hb, head + Vector2(-2, 5) * hb], hair)
	_helmet(ci, helmet, head, hb * 0.84, pal, tm, pose, t, seed, hair)
	# Pointed ears sweep up and back past the hair or an open helm.
	if lk.ears == "pointed" and open_face:
		_poly(ci, [head + Vector2(-0.6, 2.2) * hb, head + Vector2(-2.4, -0.6) * hb, head + Vector2(-8.5, -6.5) * hb, head + Vector2(-2.6, 2.8) * hb], skin.darkened(0.08))
		ci.draw_line(head + Vector2(-2.2, 1.0) * hb, head + Vector2(-6.8, -4.8) * hb, skin.darkened(0.25), 0.7)
	# Front arm + weapon.
	_weapon(ci, st.get("weapon", "sword"), sh, build, swing(atk), atk, pal, tm, skin, pose, t)
	_shield(ci, st.get("shield", ""), sh, build, pal, tm, team, pose, t)


static func _dwarf_beard(ci: CanvasItem, head: Vector2, b: float, hair: Color, t: float, seed: int) -> void:
	var sway := sin(t * 1.7 + seed) * 0.6
	var tip := head + Vector2(2.5 + sway, 15) * b
	_shade_poly(ci, [head + Vector2(-2.6, 0.5) * b, head + Vector2(1.5, 3.2) * b, head + Vector2(6.2, 2.0) * b, head + Vector2(6.6, 6.5) * b,
		head + Vector2(5.0, 11.5) * b, tip, head + Vector2(-0.5, 12) * b, head + Vector2(-3.0, 6) * b], hair)
	# Strands and a braid clasp.
	for k in 3:
		var x := -0.5 + k * 2.2
		ci.draw_line(head + Vector2(x, 5) * b, head + Vector2(x + 0.8, 11.5) * b, hair.darkened(0.25), 0.7)
	ci.draw_rect(Rect2(head + Vector2(1.6, 11.2) * b, Vector2(2.6, 1.6) * b), Color("c9a45c"))
	# Moustache over the mouth.
	_ellipse(ci, head + Vector2(4.6, 3.3) * b, Vector2(2.6, 1.3) * b, hair.lightened(0.08), 0.25)


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
		"axes":
			var metal: Color = _c(pal[2], pose)
			for i in 2:
				var h := back + Vector2(-2 + i * 3, -2 - i * 3) * b
				ci.draw_line(h + Vector2(0, 10) * b, h + Vector2(1, -8) * b, _c(Color("6b4a2b"), pose), 2.0 * b)
				_poly(ci, [h + Vector2(1, -8) * b, h + Vector2(6, -11) * b, h + Vector2(6, -3) * b, h + Vector2(1, -5) * b], metal)
		"pouch":
			_ellipse(ci, hip + Vector2(-7, -4) * b, Vector2(4.5, 5.5) * b, _c(Color("7a5a3a"), pose))
			_ellipse(ci, back + Vector2(1, 2) * b, Vector2(4, 7) * b, _c(pal[1], pose).darkened(0.2))
		"backpack":
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 16) * b), _c(pal[1], pose).darkened(0.25))
			ci.draw_rect(Rect2(back + Vector2(-7, -6) * b, Vector2(10, 4) * b), _c(pal[1], pose).darkened(0.4))
		"cell":
			# Arcane power cell: brass casing with a glowing crystal core.
			var g: Color = _look.glow
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 16) * b), _c(Color(pal[2]).darkened(0.45), pose))
			ci.draw_rect(Rect2(back + Vector2(-6, -4) * b, Vector2(9, 2) * b), _c(pal[2], pose))
			ci.draw_rect(Rect2(back + Vector2(-4, -1) * b, Vector2(4, 10) * b), Color(g, 0.6 + 0.3 * sin(t * 4.0)))


static func _helmet(ci: CanvasItem, kind: String, head: Vector2, b: float, pal: Array, tm: Color, pose: Dictionary, t: float, seed: int, hair: Color) -> void:
	var metal: Color = _c(pal[2], pose)
	var gold := _c(Color("d9b25c"), pose)
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
		"galea":
			# Roman helmet: bowl, brow ridge, neck guard, cheek plate and a short brush crest.
			_shade_poly(ci, _ellipse_pts(head + Vector2(-0.5, -3) * b, Vector2(7.4, 5.8) * b, 0.0, 16), metal)
			_poly(ci, [head + Vector2(-7.5, -1) * b, head + Vector2(-5, 1) * b, head + Vector2(-9.5, 4) * b, head + Vector2(-11, 3) * b], metal.darkened(0.2))
			_poly(ci, [head + Vector2(1.5, -1) * b, head + Vector2(5, -1) * b, head + Vector2(4, 5) * b, head + Vector2(1.5, 5.5) * b], metal.darkened(0.12))
			ci.draw_line(head + Vector2(-6, -2) * b, head + Vector2(7, -2.4) * b, gold, 1.3 * b)
			for i in 6:
				ci.draw_line(head + Vector2(-5 + i * 1.8, -7.5) * b, head + Vector2(-5.6 + i * 1.8, -12.5 - sin(t * 4.0 + i) * 0.4) * b, tm, 2.0 * b)
		"conical":
			# Spangenhelm: tall cone, nasal and a mail aventail.
			_shade_poly(ci, [head + Vector2(-7, -1) * b, head + Vector2(7, -1) * b, head + Vector2(1.5, -13) * b], metal)
			ci.draw_line(head + Vector2(4.8, -2) * b, head + Vector2(5.2, 3.2) * b, metal.darkened(0.2), 1.6 * b)
			_poly(ci, [head + Vector2(-7, -1) * b, head + Vector2(-2, -1) * b, head + Vector2(-1, 7) * b, head + Vector2(-8, 6) * b], metal.darkened(0.3))
			ci.draw_line(head + Vector2(-7, -1.5) * b, head + Vector2(7, -1.5) * b, gold, 1.2 * b)
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
			_ellipse(ci, head + Vector2(-1, -1) * b, Vector2(8, 8) * b, _c(Color(pal[0]).darkened(0.15), pose))
			ci.draw_circle(head + Vector2(2, 0.5) * b, 5.2 * b, _c(_look.skin[seed % _look.skin.size()], pose))
			ci.draw_circle(head + Vector2(3.6, -0.6) * b, 0.8 * b, Color(0.08, 0.06, 0.05))
		"tricorne":
			_poly(ci, [head + Vector2(-10, -3) * b, head + Vector2(-3, -10) * b, head + Vector2(4, -10) * b, head + Vector2(10, -3) * b], Color(0.12, 0.12, 0.15))
			ci.draw_line(head + Vector2(-9, -3.5) * b, head + Vector2(9, -3.5) * b, pal[1], 1.5 * b)
		"visor":
			# Arcane sallet: swept tail and a glowing eye-slit.
			_shade_poly(ci, [head + Vector2(-12, 1) * b, head + Vector2(-6, -8) * b, head + Vector2(3, -8.5) * b, head + Vector2(8, -2) * b,
				head + Vector2(7.5, 4) * b, head + Vector2(-3, 5) * b], metal)
			ci.draw_line(head + Vector2(-1, -1) * b, head + Vector2(8, -1) * b, Color(_look.glow, 0.95), 2.2 * b)
			ci.draw_line(head + Vector2(-6, -8) * b, head + Vector2(3, -8.5) * b, metal.lightened(0.25), 1.2 * b)
		"goggles":
			_ellipse(ci, head + Vector2(-0.5, -3.5) * b, Vector2(7.2, 4.6) * b, _c(Color("5a3d28"), pose))
			ci.draw_line(head + Vector2(-6, -2.5) * b, head + Vector2(6, -2.5) * b, _c(Color("3a2a1c"), pose), 1.6 * b)
			ci.draw_circle(head + Vector2(3.5, -3.5) * b, 2.4 * b, metal)
			ci.draw_circle(head + Vector2(3.5, -3.5) * b, 1.5 * b, Color(_look.glow, 0.8))
		"leaf":
			# Elven helm: a smooth bowl sweeping back into a long leaf point, gilt edge.
			_shade_poly(ci, [head + Vector2(6.5, -1) * b, head + Vector2(6.5, -4) * b, head + Vector2(1, -9) * b, head + Vector2(-5, -7) * b,
				head + Vector2(-17, -10) * b, head + Vector2(-9, -2.5) * b, head + Vector2(-6.5, 1) * b, head + Vector2(-2, -2) * b], metal)
			ci.draw_polyline(PackedVector2Array([head + Vector2(6.5, -1.5) * b, head + Vector2(-2, -2.5) * b, head + Vector2(-9, -1.5) * b, head + Vector2(-16, -8.5) * b]), gold, 1.0 * b)
			ci.draw_line(head + Vector2(-3, -7) * b, head + Vector2(-12, -6) * b, tm, 1.4 * b)
		"circlet":
			_ellipse(ci, head + Vector2(-1.5, -3.5) * b, Vector2(7, 4.2) * b, hair)
			ci.draw_line(head + Vector2(-6.5, -2.5) * b, head + Vector2(6.5, -2.5) * b, gold, 1.3 * b)
			ci.draw_circle(head + Vector2(5.4, -2.6) * b, 1.3 * b, Color(_look.glow, 0.95))
		"antler":
			_ellipse(ci, head + Vector2(-1.5, -3) * b, Vector2(7, 4.5) * b, hair)
			var bone := _c(Color("d8cbb0"), pose)
			ci.draw_polyline(PackedVector2Array([head + Vector2(-1, -6) * b, head + Vector2(-4, -12) * b, head + Vector2(-3, -18) * b]), bone, 1.4 * b)
			ci.draw_line(head + Vector2(-3.6, -11) * b, head + Vector2(0, -15) * b, bone, 1.2 * b)
			ci.draw_line(head + Vector2(-3.2, -15) * b, head + Vector2(-7, -18) * b, bone, 1.1 * b)
			ci.draw_line(head + Vector2(-6.5, -2) * b, head + Vector2(6.5, -2) * b, tm, 1.8 * b)
		"dwarf", "horned", "rune":
			# Dwarf helm: deep round bowl, heavy brim, nasal and cheek plates.
			_shade_poly(ci, _ellipse_pts(head + Vector2(-0.5, -3.5) * b, Vector2(7.6, 6.2) * b, 0.0, 16), metal)
			ci.draw_line(head + Vector2(-8, -1) * b, head + Vector2(7.5, -1) * b, metal.darkened(0.3), 2.4 * b)
			ci.draw_line(head + Vector2(4.8, -1) * b, head + Vector2(5.2, 3.5) * b, metal.darkened(0.15), 2.0 * b)
			_rivets(ci, head + Vector2(-6.5, -1) * b, head + Vector2(4, -1) * b, 4, metal.lightened(0.35), 0.7 * b)
			ci.draw_line(head + Vector2(0, -9.6) * b, head + Vector2(-1, 0) * b, gold if kind != "rune" else metal.lightened(0.2), 1.2 * b)
			if kind == "horned":
				var horn := _c(Color("e2d6b8"), pose)
				_shade_poly(ci, [head + Vector2(-4, -6) * b, head + Vector2(-2, -8) * b, head + Vector2(-8, -15) * b, head + Vector2(-13, -16) * b, head + Vector2(-9, -12) * b], horn)
			if kind == "rune":
				var g: Color = _look.glow
				ci.draw_polyline(PackedVector2Array([head + Vector2(-5, -4) * b, head + Vector2(-3, -7) * b, head + Vector2(-1, -4) * b, head + Vector2(1, -7) * b]),
					Color(g, 0.75 + 0.25 * sin(t * 3.0 + seed)), 1.2 * b)
				_poly(ci, [head + Vector2(-2, -1) * b, head + Vector2(7.5, -1) * b, head + Vector2(7, 4) * b, head + Vector2(-1, 5) * b], metal.darkened(0.2))
				ci.draw_line(head + Vector2(2, 1) * b, head + Vector2(7, 1) * b, Color(g, 0.9), 1.4 * b)
		"brodie":
			_ellipse(ci, head + Vector2(0, -4) * b, Vector2(10.5, 3) * b, _c(Color("5c5f4a"), pose))
			_ellipse(ci, head + Vector2(0, -6) * b, Vector2(6, 3.5) * b, _c(Color("666a52"), pose))


static func _weapon(ci: CanvasItem, kind: String, sh: Vector2, b: float, s: float, atk: float, pal: Array, tm: Color, skin: Color, pose: Dictionary, t: float) -> void:
	var wood := _c(Color("6b4a2b"), pose)
	var metal: Color = _c(pal[2], pose)
	var sleeve: Color = _c(pal[0], pose).darkened(0.1)
	var g: Color = _look.glow
	if kind in CHOP:
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
		var orth := dirv.orthogonal()
		var length: float = {"club": 20.0, "gladius": 16.0, "axe": 20.0, "hammer": 20.0, "rune_hammer": 21.0, "leafblade": 22.0, "baton": 18.0}.get(kind, 22.0)
		var tip := hand + dirv * length * b
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
				ci.draw_line(hand - orth * 2.5 * b, hand + orth * 2.5 * b, _c(Color("d9b25c"), pose), 1.8 * b)
				ci.draw_polyline(pts, metal.lightened(0.3), 2.6 * b)
			"shovel":
				ci.draw_line(hand, tip, wood, 3.0 * b)
				_ellipse(ci, tip, Vector2(4, 6) * b, metal, dirv.angle())
			"baton":
				ci.draw_line(hand, tip, Color(0.15, 0.15, 0.2), 4.0 * b)
				ci.draw_line(hand + dirv * 8, tip, Color(tm.lightened(0.6), 0.9), 2.5 * b)
			"axe":
				ci.draw_line(hand - dirv * 3 * b, tip, wood, 2.8 * b)
				var hd := hand + dirv * (length - 4) * b
				_shade_poly(ci, [hd - orth * 1.5 * b, hd + dirv * 5 * b - orth * 1.5 * b, hd + dirv * 8 * b + orth * 7 * b, hd + orth * 6 * b - dirv * 3 * b], metal)
				ci.draw_line(hd + dirv * 8 * b + orth * 7 * b, hd + orth * 6 * b - dirv * 3 * b, metal.lightened(0.4), 1.2)
			"hammer", "rune_hammer":
				ci.draw_line(hand - dirv * 3 * b, tip, wood if kind == "hammer" else Color(0.2, 0.18, 0.2), 2.8 * b)
				var hc := tip - dirv * 2 * b
				_shade_poly(ci, [hc - orth * 6 * b - dirv * 3.5 * b, hc + orth * 6 * b - dirv * 3.5 * b, hc + orth * 6 * b + dirv * 3.5 * b, hc - orth * 6 * b + dirv * 3.5 * b], metal)
				if kind == "rune_hammer":
					ci.draw_line(hc - orth * 4 * b, hc + orth * 4 * b, Color(g, 0.7 + 0.3 * sin(t * 5.0)), 1.8 * b)
					_halo(ci, hc, 7 * b, g, 0.35)
		return
	match kind:
		"halberd", "glaive" when atk < 0.0:
			# At rest the polearm stands upright: a tall vertical line in silhouette.
			var hand := sh + Vector2(10, 8) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_line(hand + Vector2(0, 22) * b, hand + Vector2(0, -44) * b, wood, 2.8 * b)
			var top := hand + Vector2(0, -44) * b
			if kind == "halberd":
				_poly(ci, [top + Vector2(0, -2), top + Vector2(8, 3), top + Vector2(8, 12), top + Vector2(0, 8)], metal)
				_poly(ci, [top + Vector2(-1.5, 0), top + Vector2(0, -10), top + Vector2(1.5, 0)], metal.lightened(0.2))
			else:
				# Glaive: a long curved leaf blade.
				_shade_poly(ci, [top + Vector2(-1.5, 2), top + Vector2(3.5, -4), top + Vector2(4, -14), top + Vector2(0, -20), top + Vector2(-1.5, -8)], metal.lightened(0.15))
				ci.draw_line(top + Vector2(-3, 2), top + Vector2(3, 2), _c(Color("d9b25c"), pose), 1.8)
			ci.draw_circle(hand, 2.6 * b, skin)
		"spear", "halberd", "lance", "glaive":
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
			if kind == "glaive":
				_poly(ci, [tip + Vector2(-2, -2.5) * b, tip + Vector2(14, -3) * b, tip + Vector2(4, 2.5) * b], metal.lightened(0.2))
			else:
				_poly(ci, [tip + Vector2(0, -2.6) * b, tip + Vector2(8, 0) * b, tip + Vector2(0, 2.6) * b], metal.lightened(0.2))
			if kind == "lance":
				ci.draw_line(back + dirv * 8, back + dirv * 14, tm, 4.0 * b)
		"javelin", "throwing_axe":
			var ang := -0.9 + 1.4 * maxf(0.0, s)
			var hand := sh + Vector2(-2, -10 * b).rotated(ang) if s < 0.5 else sh + Vector2(10, 2) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_circle(hand, 2.6 * b, skin)
			if atk < 0.0 or atk < 0.4 or atk > 0.9:
				if kind == "javelin":
					ci.draw_line(hand + Vector2(-14, 4) * b, hand + Vector2(16, -3) * b, wood, 2.2 * b)
					_poly(ci, [hand + Vector2(16, -5) * b, hand + Vector2(22, -4) * b, hand + Vector2(16, -1) * b], metal)
				else:
					ci.draw_line(hand + Vector2(-2, 6) * b, hand + Vector2(1, -10) * b, wood, 2.2 * b)
					_poly(ci, [hand + Vector2(1, -10) * b, hand + Vector2(7, -13) * b, hand + Vector2(7, -5) * b, hand + Vector2(1, -7) * b], metal)
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
		"bow", "starbow":
			var draw_back := clampf(-s, 0.0, 1.0) * 9.0
			var hand := sh + Vector2(15, 1) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			# Elves carry the tall recurved longbow.
			var tall := 23.0 if _look.long_hair else 19.0
			var top := hand + Vector2(-2, -tall) * b
			var bot := hand + Vector2(-2, tall) * b
			var pts := PackedVector2Array()
			for i in 11:
				var u := i / 10.0
				var curl := (-2.5 if u < 0.08 or u > 0.92 else 0.0) if _look.long_hair else 0.0
				pts.append(top.lerp(bot, u) + Vector2((sin(u * PI) * 7 + curl) * b, 0))
			var bow_col := wood if kind == "bow" else _c(Color("e8e4d4"), pose)
			ci.draw_polyline(pts, bow_col, 2.6 * b)
			var nock := hand + Vector2(-4 - draw_back, 0) * b
			ci.draw_polyline(PackedVector2Array([pts[0], nock, pts[pts.size() - 1]]), Color(0.9, 0.88, 0.8, 0.9), 1.0)
			_limb(ci, sh + Vector2(-1, 1), nock, 4.0 * b, sleeve.darkened(0.2))
			if atk < 0.35:
				if kind == "starbow":
					ci.draw_line(nock, nock + Vector2(24, 0) * b, Color(g, 0.9), 2.0)
					_halo(ci, nock + Vector2(24, 0) * b, 4.0 * b, g, 0.6)
				else:
					ci.draw_line(nock, nock + Vector2(24, 0) * b, wood.lightened(0.3), 1.5)
			ci.draw_circle(hand, 2.6 * b, skin)
		"staff":
			# Staff held upright; on the attack it is thrust forward and the head flares.
			var fw := maxf(0.0, s)
			var hand := sh + Vector2(10 + fw * 5, 6 - fw * 6) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			var top := hand + Vector2(4 + fw * 8, -30) * b
			ci.draw_line(hand + Vector2(-2, 22) * b, top, _c(Color("a88a5a"), pose), 2.4 * b)
			ci.draw_arc(top + Vector2(0, -3) * b, 4.0 * b, PI * 0.2, PI * 1.8, 10, _c(Color("d9b25c"), pose), 1.2 * b)
			var k := 0.6 + 0.4 * sin(t * 3.0) + fw
			_halo(ci, top + Vector2(0, -3) * b, 6.0 * b * (1.0 + fw), g, minf(1.0, k))
			ci.draw_circle(top + Vector2(0, -3) * b, 2.2 * b, Color(1, 1, 1, 0.95))
			ci.draw_circle(hand, 2.6 * b, skin)
		"crew":
			# Hands forward on the engine.
			var hand := sh + Vector2(14, 8) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_circle(hand, 2.6 * b, skin)
		"crossbow":
			var kick := maxf(0.0, s) * 2.0
			var hand := sh + Vector2(12 - kick, 4) * b
			var stock := sh + Vector2(-2 - kick, 3) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			ci.draw_line(stock, stock + Vector2(24, -1.5) * b, wood, 3.6 * b)
			var prod := stock + Vector2(22, -1.5) * b
			var bend := 3.0 if atk < 0.0 or atk > 0.45 else 1.0
			ci.draw_polyline(PackedVector2Array([prod + Vector2(-bend, -9) * b, prod, prod + Vector2(-bend, 9) * b]), metal.darkened(0.2), 2.0 * b)
			var nut := stock + Vector2(8 if atk < 0.0 or atk > 0.45 else 18, -2) * b
			ci.draw_polyline(PackedVector2Array([prod + Vector2(-bend, -9) * b, nut, prod + Vector2(-bend, 9) * b]), Color(0.9, 0.88, 0.8, 0.8), 0.9)
			if atk < 0.0 or atk > 0.6:
				ci.draw_line(nut, prod + Vector2(3, 0) * b, wood.lightened(0.3), 1.4)
			ci.draw_circle(hand, 2.6 * b, skin)
		"musket", "rifle", "arcane_rifle", "rune_rifle":
			var kick := maxf(0.0, s) * 4.0
			var hand := sh + Vector2(12 - kick, 4) * b
			var stock := sh + Vector2(-2 - kick, 3) * b
			_limb(ci, sh + Vector2(2, 1), hand, 4.5 * b, sleeve)
			var length: float = {"musket": 34.0, "rifle": 30.0, "arcane_rifle": 30.0, "rune_rifle": 30.0}[kind]
			var muzzle := stock + Vector2(length, -2) * b
			var arcane := kind in ["arcane_rifle", "rune_rifle"]
			ci.draw_line(stock, stock + Vector2(12, 0) * b, wood, 5.0 * b)
			var barrel := metal.darkened(0.3) if not arcane else _c(Color("b8914a") if kind == "arcane_rifle" else Color("4a4a54"), pose)
			ci.draw_line(stock + Vector2(8, -1) * b, muzzle, barrel, 3.0 * b)
			if arcane:
				ci.draw_line(stock + Vector2(12, -3.5) * b, stock + Vector2(24, -3.5) * b, Color(g, 0.6 + 0.4 * sin(t * 8.0)), 2.0 * b)
				_ellipse(ci, stock + Vector2(12, 1.5) * b, Vector2(2.4, 2.4) * b, Color(g, 0.9))
				for i in 3:
					ci.draw_line(stock + Vector2(16 + i * 4, -2.5) * b, stock + Vector2(16 + i * 4, 0.5) * b, metal.lightened(0.2), 1.0)
			ci.draw_circle(hand, 2.6 * b, skin)


static func _shield(ci: CanvasItem, kind: String, sh: Vector2, b: float, pal: Array, tm: Color, team: Color, pose: Dictionary, t: float) -> void:
	var metal: Color = _c(pal[2], pose)
	var g: Color = _look.glow
	match kind:
		"round":
			var c := sh + Vector2(10, 11) * b
			ci.draw_circle(c, 10.5 * b, metal.darkened(0.2))
			ci.draw_circle(c, 9 * b, tm)
			ci.draw_circle(c, 2.5 * b, metal)
		"kite":
			var c := sh + Vector2(10, 9) * b
			_poly(ci, [c + Vector2(-7, -8), c + Vector2(7, -8), c + Vector2(6, 4), c + Vector2(0, 14), c + Vector2(-6, 4)], metal.darkened(0.3))
			_poly(ci, [c + Vector2(-5.5, -6.5), c + Vector2(5.5, -6.5), c + Vector2(4.5, 3.5), c + Vector2(0, 11.5), c + Vector2(-4.5, 3.5)], tm)
		"hide":
			var c := sh + Vector2(10, 12) * b
			_ellipse(ci, c, Vector2(8.5, 11) * b, _c(Color("6e4a2c"), pose))
			_ellipse(ci, c, Vector2(6.5, 9) * b, _c(Color("8d6a45"), pose))
			ci.draw_line(c + Vector2(-5, -2) * b, c + Vector2(5, -2) * b, tm, 2.5 * b)
		"scutum":
			# Tall curved legion shield: team field, metal rim and boss, painted wings.
			var c := sh + Vector2(11, 10) * b
			_shade_poly(ci, [c + Vector2(-5, -15) * b, c + Vector2(5, -14) * b, c + Vector2(6, 0) * b, c + Vector2(5, 14) * b, c + Vector2(-5, 15) * b, c + Vector2(-4, 0) * b], metal.darkened(0.25))
			_shade_poly(ci, [c + Vector2(-3.8, -13.5) * b, c + Vector2(4, -12.5) * b, c + Vector2(4.8, 0) * b, c + Vector2(4, 12.5) * b, c + Vector2(-3.8, 13.5) * b, c + Vector2(-2.8, 0) * b], tm)
			ci.draw_circle(c + Vector2(0.8, 0) * b, 3.0 * b, metal)
			ci.draw_line(c + Vector2(0.8, -11) * b, c + Vector2(0.8, 11) * b, Color(_c(Color("d9b25c"), pose), 0.8), 1.2 * b)
		"leaf":
			# Elven shield: a tall leaf of lacquered wood with a gilt rib.
			var c := sh + Vector2(10, 10) * b
			_shade_poly(ci, [c + Vector2(0, -16) * b, c + Vector2(6.5, -6) * b, c + Vector2(6, 6) * b, c + Vector2(0, 16) * b, c + Vector2(-5.5, 6) * b, c + Vector2(-6, -6) * b], _c(Color("5a6a3a"), pose))
			_shade_poly(ci, [c + Vector2(0, -13) * b, c + Vector2(4.8, -5) * b, c + Vector2(4.4, 5) * b, c + Vector2(0, 13) * b, c + Vector2(-4, 5) * b, c + Vector2(-4.4, -5) * b], tm)
			ci.draw_line(c + Vector2(0, -14) * b, c + Vector2(0, 14) * b, _c(Color("d9b25c"), pose), 1.4 * b)
			for k in 3:
				ci.draw_line(c + Vector2(0, -6 + k * 5) * b, c + Vector2(3.5, -9 + k * 5) * b, _c(Color("d9b25c"), pose), 0.8)
		"moon":
			# Moonsilver leaf shield with a glowing rim.
			var c := sh + Vector2(10, 10) * b
			var pts := [c + Vector2(0, -16) * b, c + Vector2(6.5, -6) * b, c + Vector2(6, 6) * b, c + Vector2(0, 16) * b, c + Vector2(-5.5, 6) * b, c + Vector2(-6, -6) * b]
			_shade_poly(ci, pts, metal)
			var ring := PackedVector2Array(pts)
			ring.append(pts[0])
			ci.draw_polyline(ring, Color(g, 0.6 + 0.3 * sin(t * 4.0)), 1.6 * b)
			ci.draw_arc(c, 5 * b, -2.2, 1.0, 12, tm, 2.4 * b)
		"dwarf":
			# Big round dwarf shield: iron rim with rivets, team field, anvil boss.
			var c := sh + Vector2(9, 11) * b
			ci.draw_circle(c, 12.5 * b, metal.darkened(0.3))
			ci.draw_circle(c, 10.5 * b, tm.darkened(0.08))
			for k in 8:
				ci.draw_circle(c + Vector2.RIGHT.rotated(TAU * k / 8.0) * 11.5 * b, 0.9 * b, metal.lightened(0.3))
			for k in 4:
				ci.draw_line(c, c + Vector2.RIGHT.rotated(TAU * k / 4.0 + 0.4) * 10 * b, tm.darkened(0.3), 1.4 * b)
			_shade_poly(ci, _ellipse_pts(c, Vector2(4, 4) * b), metal)
			if pal == RaceLook.palette(&"dwarf", 6):
				ci.draw_arc(c, 7.5 * b, 0, TAU, 20, Color(g, 0.6 + 0.3 * sin(t * 3.0)), 1.2 * b)
		"plate":
			var c := sh + Vector2(11, 8) * b
			ci.draw_rect(Rect2(c + Vector2(-6, -11) * b, Vector2(12, 24) * b), metal.darkened(0.35))
			ci.draw_rect(Rect2(c + Vector2(-2, -6) * b, Vector2(6, 2) * b), Color(0.05, 0.05, 0.05))
			ci.draw_rect(Rect2(c + Vector2(-6, 6) * b, Vector2(12, 3) * b), tm)
		"energy":
			# Arcane ward: a translucent hex pane on a brass bracer.
			var c := sh + Vector2(13, 10) * b
			var a := 0.3 + 0.1 * sin(t * 6.0)
			var hex := []
			for k in 6:
				hex.append(c + Vector2(cos(TAU * k / 6.0) * 7, sin(TAU * k / 6.0) * 15) * b)
			_poly(ci, hex, Color(g, a))
			var ring := PackedVector2Array(hex)
			ring.append(hex[0])
			ci.draw_polyline(ring, Color(g.lightened(0.4), 0.9), 1.4)
			ci.draw_circle(c + Vector2(-5, 0) * b, 2.2 * b, metal)


# ---------------------------------------------------------------------------
# Beasts and riders

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


static func quadruped(ci: CanvasItem, kind: String, team: Color, pose: Dictionary, seed: int, metal := Color("a5a9ae")) -> Vector2:
	var bp: Dictionary = BEASTS.get(kind, BEASTS["horse"])
	var mv := _mv(pose)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var head_kind: String = bp.head
	var col := _c(bp.col, pose)
	var dark := col.darkened(0.35)
	var tm := _c(team, pose)
	var mt := _c(metal, pose)
	var L: float = bp.L
	var H: float = bp.H
	var slim: bool = bp.get("slim", false)
	var heavy := head_kind in ["boar", "bear", "ram"]
	var bob := lerpf(sin(t * 1.5 + seed) * 0.5, absf(sin(walk * 2.0)) * 2.0, mv)
	var lunge := maxf(0.0, swing(atk)) * 5.0
	var c := Vector2(lunge, -H - 10 + bob)
	_shadow(ci, L + 8)
	# Legs: far pair first (darker), then near pair. Front legs bend forward at the knee, hind legs
	# bend back at the hock; each ends in a fetlock and hoof (or a paw).
	var w0 := 9.0 if heavy else (6.8 if slim else 8.0)
	var w1 := 5.2 if not slim else 3.8
	if head_kind == "bear":
		w0 = 12.0
		w1 = 8.0
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
			_seg(ci, top, upper, w0, w1, lc)
			_seg(ci, upper, fet, w1 * 0.88, w1 * 0.66, lc)
			if bp.get("paws", false):
				_ellipse(ci, fet + Vector2(3, 3), Vector2(6, 3.2), lc.darkened(0.15))
			else:
				_seg(ci, fet, hoof, w1 * 0.66, w1 * 0.72, lc.darkened(0.1))
				ci.draw_rect(Rect2(hoof + Vector2(-2.5, -1.2), Vector2(5.5, 2.8)), Color(0.12, 0.1, 0.08))
		if pass_i == 0:
			# Tail behind the far legs.
			match head_kind:
				"horse":
					for k in 5:
						var sway := sin(t * 2.5 + k * 0.4) * 3.0 + mv * 4.0
						ci.draw_polyline(PackedVector2Array([c + Vector2(-L - 2, -6 + k), c + Vector2(-L - 9 - sway * 0.5, 2 + k), c + Vector2(-L - 12 - sway, 14 + k * 1.5)]), dark.darkened(0.1 * (k % 2)), 2.0)
				"deer":
					_ellipse(ci, c + Vector2(-L - 4, -7 + sin(t * 5.0)), Vector2(3, 4.5), Color("efe6d4"), -0.5)
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
			_shade_poly(ci, body, col)
			if bp.get("wool", false):
				# Fleece: a scalloped outline of curls.
				for k in 9:
					var wp := c + Vector2(-L - 2 + k * (2 * L + 6) / 8.0, -10 - 2 * sin(k * 1.3))
					ci.draw_circle(wp, 4.2, col.lightened(0.08))
					ci.draw_arc(wp, 2.4, 0.5, 3.6, 6, col.darkened(0.15), 0.8)
				for k in 5:
					ci.draw_circle(c + Vector2(-L + k * L * 0.45, 7), 3.6, col.darkened(0.06))
			match head_kind:
				"horse", "deer":
					var deer := head_kind == "deer"
					# Neck up to the head.
					var neck_top := c + Vector2(L + (6.0 if deer else 8.0), -28.0 if deer else -24.0) + Vector2(lunge * 0.4, 0)
					_shade_poly(ci, [c + Vector2(L - 4, -10), c + Vector2(L + 6, -4), neck_top + Vector2(5 if not deer else 3.5, 4), neck_top + Vector2(-2, -1)], col)
					var hd := neck_top + Vector2(4, -1)
					if deer:
						_shade_poly(ci, [hd + Vector2(-4, -3.5), hd + Vector2(3, -5), hd + Vector2(11, 2), hd + Vector2(10.5, 5), hd + Vector2(5, 5.5), hd + Vector2(-3, 3)], col)
						_ellipse(ci, hd + Vector2(-3.5, -5.5), Vector2(3.8, 1.6), dark, -0.7)
						ci.draw_circle(hd + Vector2(10.4, 3.4), 1.2, Color(0.1, 0.07, 0.06))
						_antlers(ci, hd + Vector2(-0.5, -4), int(bp.get("antlers", 1)), _c(Color("d9c9a6"), pose))
					else:
						_shade_poly(ci, [hd + Vector2(-4, -4), hd + Vector2(3, -6), hd + Vector2(13, 3), hd + Vector2(12, 7), hd + Vector2(6, 7), hd + Vector2(-3, 3)], col)
						ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(-2, -4), hd + Vector2(0, -10), hd + Vector2(2, -5)]), dark)
						ci.draw_circle(hd + Vector2(11.5, 4.5), 0.9, Color(0.1, 0.07, 0.06))
					ci.draw_circle(hd + Vector2(2.5, -1.5), 1.2, Color(0.05, 0.04, 0.04))
					# Bridle and reins in team colour.
					ci.draw_polyline(PackedVector2Array([hd + Vector2(-1, -3), hd + Vector2(8, 3), hd + Vector2(9, 6)]), tm.darkened(0.2), 1.2)
					ci.draw_line(hd + Vector2(8, 3), c + Vector2(4, -14), Color(0.25, 0.18, 0.12), 1.0)
					if not deer:
						# Mane strands lag behind (secondary motion); elven steeds get a long silver mane.
						var mane := dark if kind != "elfsteed" else _c(Color("c9d2dc"), pose)
						for k in 6:
							var mp := (c + Vector2(L - 4, -11)).lerp(neck_top + Vector2(-2, -2), k / 5.0)
							ci.draw_line(mp, mp + Vector2(-5 - mv * 2.0, 3 + sin(t * 4.0 + k) * 1.5) * (1.5 if kind == "elfsteed" else 1.0), mane, 2.2)
						if kind in ["barded", "elfsteed"]:
							# Chanfron.
							_poly(ci, [hd + Vector2(-2, -4), hd + Vector2(4, -6), hd + Vector2(11, 1), hd + Vector2(8, 3)], mt)
							if kind == "elfsteed":
								ci.draw_line(hd + Vector2(1, -5), hd + Vector2(-2, -12), mt.lightened(0.3), 1.6)
				"boar":
					# Boar head: heavy snout, tusks, bristled back.
					var hd := c + Vector2(L + 4, -2) + Vector2(lunge * 0.5, 0)
					_shade_poly(ci, [hd + Vector2(-4, -9), hd + Vector2(6, -6), hd + Vector2(14, 1), hd + Vector2(13, 6), hd + Vector2(2, 7), hd + Vector2(-4, 4)], col)
					ci.draw_rect(Rect2(hd + Vector2(12, 0), Vector2(3, 5)), col.darkened(0.3))
					ci.draw_polyline(PackedVector2Array([hd + Vector2(10, 5), hd + Vector2(15, 2), hd + Vector2(14, -3)]), Color("efe6cf"), 2.4)
					ci.draw_circle(hd + Vector2(4, -3), 1.1, Color(0.05, 0.04, 0.04))
					ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(-2, -8), hd + Vector2(-1, -13), hd + Vector2(2, -8)]), dark)
					for k in 8:
						var bpk := c + Vector2(-L * 0.6 + k * 4.5, -12 - (2 if k % 2 == 0 else 0))
						ci.draw_line(bpk, bpk + Vector2(-2, -4), dark, 1.6)
					if kind == "warboar":
						_poly(ci, [hd + Vector2(-3, -9), hd + Vector2(7, -6), hd + Vector2(10, -1), hd + Vector2(-2, -2)], mt)
						ci.draw_line(hd + Vector2(2, -8), hd + Vector2(4, -14), mt.lightened(0.2), 1.8)
				"ram":
					# Ram head: short muzzle and a heavy curled horn.
					var hd := c + Vector2(L + 5, -8) + Vector2(lunge * 0.6, 0)
					_shade_poly(ci, [c + Vector2(L - 2, -10), c + Vector2(L + 4, -2), hd + Vector2(2, 6), hd + Vector2(-2, -4)], col)
					_shade_poly(ci, [hd + Vector2(-4, -5), hd + Vector2(4, -6), hd + Vector2(11, 1), hd + Vector2(10, 5), hd + Vector2(3, 6), hd + Vector2(-3, 2)], _c(Color("b8ab92"), pose))
					ci.draw_circle(hd + Vector2(4, -2), 1.1, Color(0.05, 0.04, 0.04))
					var horn := PackedVector2Array()
					for k in 16:
						var a := -1.2 + k * 0.38
						horn.append(hd + Vector2(-1, -1) + Vector2(cos(a), sin(a)) * (7.5 - k * 0.32))
					ci.draw_polyline(horn, _c(Color("c9b48a"), pose), 3.4)
					ci.draw_polyline(horn, _c(Color("8a7656"), pose), 1.0)
					if kind == "warram":
						_poly(ci, [hd + Vector2(-2, -6), hd + Vector2(5, -7), hd + Vector2(10, 0), hd + Vector2(3, 0)], mt)
				"bear":
					# Bear: shoulder hump, round head, small ears, short snout.
					var hd := c + Vector2(L + 6, -8) + Vector2(lunge * 0.6, 0)
					_shade_poly(ci, _ellipse_pts(hd, Vector2(8.5, 7.5)), col)
					_shade_poly(ci, [hd + Vector2(4, -2), hd + Vector2(13, 0), hd + Vector2(13, 5), hd + Vector2(5, 6)], col.lightened(0.12))
					ci.draw_circle(hd + Vector2(13, 1.2), 1.6, Color(0.06, 0.05, 0.05))
					ci.draw_circle(hd + Vector2(-3, -7), 3.0, col.darkened(0.1))
					ci.draw_circle(hd + Vector2(3.5, -2.5), 1.1, Color(0.05, 0.04, 0.04))
					if atk >= 0.0 and atk < 0.6:
						ci.draw_line(hd + Vector2(6, 5), hd + Vector2(12, 7), Color(0.6, 0.2, 0.2), 2.0)
	# Cover: tack or barding in team colour.
	match bp.cover:
		"caparison":
			var trim := _c(Color("d9c27a") if kind != "elfsteed" else Color("dfe6ee"), pose)
			_shade_poly(ci, [c + Vector2(-L - 5, -9), c + Vector2(L + 3, -9), c + Vector2(L + 6, 14), c + Vector2(-L - 7, 14)], tm)
			for k in 6:
				var hx := -L - 5 + k * (2 * L + 10) / 6.0
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(hx, 14), c + Vector2(hx + 4, 19), c + Vector2(hx + 8, 14)]), tm.darkened(0.25))
			ci.draw_line(c + Vector2(-L - 5, -5), c + Vector2(L + 3, -5), trim, 2.0)
			ci.draw_line(c + Vector2(-L - 6, 11), c + Vector2(L + 5, 11), trim, 1.5)
		"scale":
			# Cataphract barding: rows of scales over the body, team saddle cloth on top.
			_shade_poly(ci, [c + Vector2(-L - 5, -10), c + Vector2(L + 4, -10), c + Vector2(L + 6, 11), c + Vector2(-L - 6, 11)], mt.darkened(0.15))
			for r in 4:
				for k in 9:
					ci.draw_arc(c + Vector2(-L - 2 + k * (2 * L + 6) / 8.0 + (r % 2) * 2.5, -6 + r * 5), 2.8, 0.1, PI - 0.1, 6, mt.darkened(0.45), 1.0)
			_shade_poly(ci, [c + Vector2(-9, -13), c + Vector2(8, -13), c + Vector2(9, -2), c + Vector2(-10, -2)], tm)
		"plates":
			_shade_poly(ci, [c + Vector2(-L * 0.7, -14), c + Vector2(L * 0.7, -14), c + Vector2(L * 0.8, -4), c + Vector2(-L * 0.8, -4)], mt)
			_rivets(ci, c + Vector2(-L * 0.7, -12), c + Vector2(L * 0.7, -12), 6, mt.lightened(0.35))
			_shade_poly(ci, [c + Vector2(-9, -16), c + Vector2(8, -16), c + Vector2(9, -7), c + Vector2(-10, -7)], tm)
		_:
			# Saddle blanket.
			_shade_poly(ci, [c + Vector2(-9, -13), c + Vector2(8, -13), c + Vector2(9, -4), c + Vector2(-10, -4)], tm)
			ci.draw_rect(Rect2(c + Vector2(-6, -15), Vector2(12, 3)), Color(0.3, 0.2, 0.12))
	return c + Vector2(-2, -10 - (5.0 if head_kind == "bear" else 0.0))


static func _antlers(ci: CanvasItem, at: Vector2, kind: int, col: Color) -> void:
	if kind == 2:
		# Elk: broad palmate antlers with tines.
		_poly(ci, [at, at + Vector2(-4, -8), at + Vector2(-12, -12), at + Vector2(-16, -9), at + Vector2(-8, -6)], col)
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


static func mounted(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var saddle := quadruped(ci, st.get("beast", "horse"), team, pose, seed, pal[2])
	var p := pose.duplicate()
	p["moving"] = false
	p["move"] = 0.0
	_rider(ci, st, pal, team, p, seed, saddle)


static func _rider(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int, at: Vector2) -> void:
	# Upper body only, offset to the saddle; legs drawn as a straddling thigh.
	var cloth: Color = _c(pal[1], pose)
	ci.draw_line(at + Vector2(0, -2), at + Vector2(8, 10), cloth, 6.0)
	_offset_humanoid(ci, st, pal, team, pose, seed, at + Vector2(0, 27))


static func _offset_humanoid(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int, offset: Vector2) -> void:
	# The humanoid rig draws around a hip at y≈−25; drawing it with a translated transform keeps one rig.
	_push(ci, Transform2D(0.0, offset))
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
# Chariots, engines and walkers

static func _crew(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int, at: Vector2, weapon := "crew") -> void:
	_push(ci, Transform2D(0.0, Vector2(0.85, 0.85), 0.0, at))
	humanoid(ci, {"helmet": st.get("crew", "cap"), "weapon": weapon}, pal, team, pose, seed)
	_pop(ci)


static func _wood(pose: Dictionary) -> Color:
	return _c(Color("7a5532"), pose)


static func chariot(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var p := pose.duplicate()
	_push(ci, Transform2D(0.0, Vector2(26, 0)) * Transform2D(0.0, Vector2(0.78, 0.78), 0.0, Vector2.ZERO))
	quadruped(ci, st.get("beast", "horse"), team, p, seed, pal[2])
	_pop(ci)
	var wood := _wood(pose)
	var metal: Color = _c(pal[2], pose)
	var tm := _c(team, pose)
	var roll: float = pose.get("walk", 0.0) * 1.3
	ci.draw_line(Vector2(-10, -18), Vector2(18, -24), wood.darkened(0.2), 3.0)
	match st.get("car", "bronze"):
		"wood":
			# Elven car: a curved prow of pale wood, like a leaf.
			_shade_poly(ci, [Vector2(-30, -16), Vector2(-6, -16), Vector2(0, -30), Vector2(-4, -40), Vector2(-12, -30), Vector2(-28, -28)], _c(Color("b89a6a"), pose))
			_poly(ci, [Vector2(-26, -19), Vector2(-9, -19), Vector2(-6, -27), Vector2(-24, -26)], tm)
			ci.draw_polyline(PackedVector2Array([Vector2(-6, -16), Vector2(0, -30), Vector2(-4, -40), Vector2(-8, -36)]), _c(Color("d9b25c"), pose), 1.4)
		"iron":
			# Dwarf car: an iron-bound box with a ram's-head prow.
			_shade_poly(ci, [Vector2(-30, -14), Vector2(-4, -14), Vector2(-4, -32), Vector2(-30, -32)], metal.darkened(0.2))
			_poly(ci, [Vector2(-27, -18), Vector2(-8, -18), Vector2(-8, -28), Vector2(-27, -28)], tm)
			_rivets(ci, Vector2(-29, -31), Vector2(-5, -31), 6, metal.lightened(0.3))
			ci.draw_arc(Vector2(-3, -30), 4.0, -2.0, 2.0, 8, _c(Color("c9b48a"), pose), 2.2)
		_:
			_shade_poly(ci, [Vector2(-30, -16), Vector2(-6, -16), Vector2(-4, -36), Vector2(-26, -34)], metal)
			_poly(ci, [Vector2(-28, -19), Vector2(-8, -19), Vector2(-7, -31), Vector2(-25, -30)], tm)
	_wheel(ci, Vector2(-18, -13), 13, roll, wood, metal)
	_offset_humanoid(ci, {"helmet": st.get("crew", "crest"), "weapon": st.get("weapon", "spear")}, pal, team, pose, seed, Vector2(-16, 4))


static func ram(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var variant: String = st.get("variant", "wood")
	var wood := _c(Color("75512f"), pose)
	var roof := _c(Color("8c6b3f"), pose)
	var metal: Color = _c(pal[2], pose)
	var tm := _c(team, pose)
	var thrust := maxf(0.0, swing(pose.get("atk", -1.0))) * 14.0 - maxf(0.0, -swing(pose.get("atk", -1.0))) * 6.0
	var roll: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	_shadow(ci, 38)
	_crew(ci, st, pal, team, pose, seed, Vector2(-26, 0))
	match variant:
		"root":
			# Rootbreaker: a living trunk, still sprouting, slung under a canopy of woven boughs.
			var bark := _c(Color("5e4a36"), pose)
			ci.draw_line(Vector2(-30 + thrust, -24), Vector2(32 + thrust, -24), bark, 10.0)
			for k in 4:
				ci.draw_line(Vector2(-24 + k * 14 + thrust, -28), Vector2(-18 + k * 14 + thrust, -20), bark.darkened(0.3), 1.2)
			_shade_poly(ci, [Vector2(32 + thrust, -30), Vector2(40 + thrust, -27), Vector2(42 + thrust, -21), Vector2(32 + thrust, -18)], bark.darkened(0.15))
			for k in 3:
				ci.draw_line(Vector2(38 + thrust, -24), Vector2(46 + thrust + k * 2, -30 + k * 6), bark.darkened(0.2), 1.6)
			_ellipse(ci, Vector2(-6 + thrust, -31), Vector2(5, 3), _c(Color("6a9a4a"), pose), -0.4)
			ci.draw_line(Vector2(-26, -16), Vector2(-20, -48), wood, 3.0)
			ci.draw_line(Vector2(18, -16), Vector2(12, -48), wood, 3.0)
			var leaf := _c(Color("4f7a3a"), pose)
			for k in 7:
				var lx := -30 + k * 8.0
				_shade_poly(ci, _ellipse_pts(Vector2(lx, -50 - absf(sin(k * 1.7)) * 4), Vector2(8, 5), -0.3 + sin(t + k) * 0.05, 8), leaf.darkened(0.08 * (k % 2)))
			ci.draw_line(Vector2(-18, -44), Vector2(6, -44), tm, 3.0)
		"iron":
			# Dwarf ram: iron-shod beam with a ram's-head, under an iron-plated roof.
			ci.draw_line(Vector2(-30 + thrust, -24), Vector2(34 + thrust, -24), wood.darkened(0.15), 8.0)
			_shade_poly(ci, [Vector2(30 + thrust, -31), Vector2(42 + thrust, -28), Vector2(44 + thrust, -20), Vector2(30 + thrust, -17)], metal)
			ci.draw_arc(Vector2(36 + thrust, -31), 5.0, PI, TAU + 0.8, 10, _c(Color("c9b48a"), pose), 2.6)
			_shade_poly(ci, [Vector2(-34, -16), Vector2(24, -16), Vector2(18, -42), Vector2(-8, -52), Vector2(-30, -42)], metal.darkened(0.3))
			for i in 4:
				ci.draw_line(Vector2(-30 + i * 14, -18), Vector2(-24 + i * 11, -46), metal.darkened(0.5), 1.4)
			_rivets(ci, Vector2(-30, -42), Vector2(18, -42), 7, metal.lightened(0.3))
			_poly(ci, [Vector2(-18, -28), Vector2(4, -28), Vector2(2, -38), Vector2(-14, -40)], tm)
		_:
			ci.draw_line(Vector2(-30 + thrust, -24), Vector2(34 + thrust, -24), wood.darkened(0.15), 8.0)
			ci.draw_circle(Vector2(36 + thrust, -24), 6.0, metal)
			_poly(ci, [Vector2(-34, -16), Vector2(24, -16), Vector2(18, -42), Vector2(-8, -54), Vector2(-30, -42)], roof)
			for i in 5:
				ci.draw_line(Vector2(-30 + i * 11, -18), Vector2(-24 + i * 9, -46), roof.darkened(0.25), 2.0)
			_poly(ci, [Vector2(-18, -30), Vector2(4, -30), Vector2(2, -40), Vector2(-14, -42)], tm)
	for x in [-24.0, 14.0]:
		_wheel(ci, Vector2(x, -9), 9, roll, wood if variant != "iron" else metal.darkened(0.3), metal, 5)


## Torsion engine (onager / stone hurler / moonfire catapult): the arm lies back loaded and slams
## up into the crossbar on release.
static func catapult(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var variant: String = st.get("variant", "onager")
	var atk: float = pose.get("atk", -1.0)
	var t: float = pose.get("t", 0.0)
	var roll: float = pose.get("walk", 0.0)
	var metal: Color = _c(pal[2], pose)
	var tm := _c(team, pose)
	var wood := _wood(pose)
	if variant == "moonfire":
		wood = _c(Color("a88a5a"), pose)
	elif variant == "stone":
		wood = _c(Color("5e4630"), pose)
	var rest := -2.84
	var fire := -1.35
	var arm := rest
	if atk >= 0.0:
		arm = lerpf(rest, fire, ease(clampf((atk - 0.25) / 0.15, 0.0, 1.0), 0.3)) if atk < 0.7 else lerpf(fire, rest, (atk - 0.7) / 0.3)
	_shadow(ci, 40)
	_crew(ci, st, pal, team, pose, seed, Vector2(-46, 0))
	# Frame: sill beams, uprights and the stop-beam.
	ci.draw_line(Vector2(-34, -14), Vector2(34, -14), wood.darkened(0.2), 7.0)
	ci.draw_line(Vector2(-28, -22), Vector2(28, -22), wood.darkened(0.1), 4.0)
	ci.draw_line(Vector2(10, -14), Vector2(8, -56), wood, 5.0)
	ci.draw_line(Vector2(24, -14), Vector2(10, -52), wood.darkened(0.1), 4.0)
	ci.draw_line(Vector2(2, -54), Vector2(14, -56), wood.lightened(0.1), 6.0)
	_shade_poly(ci, [Vector2(4, -60), Vector2(14, -60), Vector2(14, -52), Vector2(4, -52)], tm)
	if variant == "stone":
		_rivets(ci, Vector2(-32, -14), Vector2(32, -14), 7, metal.lightened(0.2), 1.3)
	# Torsion bundle and arm.
	var pivot := Vector2(-18, -22)
	ci.draw_circle(pivot, 6.5, _c(Color("8a7a5a"), pose))
	ci.draw_circle(pivot, 3.0, metal)
	var tip := pivot + Vector2(50, 0).rotated(arm)
	ci.draw_line(pivot, tip, wood.lightened(0.12), 5.0)
	var cup := tip + Vector2(0, -3).rotated(arm + PI * 0.5)
	_ellipse(ci, cup, Vector2(6, 3.5), wood.darkened(0.25), arm)
	var loaded := atk < 0.0 or atk < 0.35 or atk > 0.85
	if loaded:
		match variant:
			"moonfire":
				var g: Color = _look.glow
				_halo(ci, cup + Vector2(0, -4).rotated(arm + PI * 0.5), 9.0, g, 0.8 + 0.2 * sin(t * 5.0))
				ci.draw_circle(cup + Vector2(0, -4).rotated(arm + PI * 0.5), 3.4, Color(1, 1, 1, 0.9))
			_:
				ci.draw_circle(cup + Vector2(0, -4).rotated(arm + PI * 0.5), 5.0 if variant == "stone" else 4.2, _c(Color("7b7466"), pose))
	if variant == "moonfire":
		# Living-wood flourishes on the uprights.
		ci.draw_arc(Vector2(10, -58), 6.0, PI, TAU, 8, _c(Color("5f8a45"), pose), 2.0)
		_ellipse(ci, Vector2(4, -62), Vector2(4, 2.2), _c(Color("6a9a4a"), pose), -0.6)
	for x in [-24.0, 22.0]:
		_wheel(ci, Vector2(x, -9), 9, roll, wood if variant != "stone" else metal.darkened(0.35), metal, 6)


## Bolt thrower on a wheeled stand: the bow limbs flex back, then the bolt flies.
static func ballista(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var great: bool = st.get("variant", "") == "great"
	var k := 1.25 if great else 1.0
	var atk: float = pose.get("atk", -1.0)
	var roll: float = pose.get("walk", 0.0)
	var metal: Color = _c(pal[2], pose)
	var tm := _c(team, pose)
	var wood := _c(Color("a88a5a"), pose)
	var gold := _c(Color("d9b25c"), pose)
	# Loaded (drawn) at rest; released at contact and re-spanned during recovery.
	var pull := 1.0
	if atk >= 0.0:
		pull = 1.0 if atk < 0.4 else (0.0 if atk < 0.7 else (atk - 0.7) / 0.3)
	_shadow(ci, 36 * k)
	_crew(ci, st, pal, team, pose, seed, Vector2(-40 * k, 0))
	if great:
		_crew(ci, st, pal, team, pose, seed + 1, Vector2(-26 * k, 0))
	ci.draw_line(Vector2(-30, -12) * k, Vector2(28, -12) * k, wood.darkened(0.3), 6.0)
	ci.draw_line(Vector2(-4, -12) * k, Vector2(0, -32) * k, wood.darkened(0.15), 5.0)
	ci.draw_line(Vector2(10, -12) * k, Vector2(2, -32) * k, wood.darkened(0.2), 4.0)
	# Stock (slightly elevated), bow limbs curving like a leaf, and the string.
	var el := -0.12
	var s0 := Vector2(-22, -36) * k
	var dirv := Vector2(1, 0).rotated(el)
	var s1 := s0 + dirv * 56 * k
	_shade_poly(ci, [s0 + Vector2(0, -3) * k, s1 + Vector2(0, -3) * k, s1 + Vector2(0, 3) * k, s0 + Vector2(0, 3) * k], wood)
	ci.draw_line(s0 + dirv * 6 * k, s1 - dirv * 4 * k, gold, 1.2)
	var bow_c := s1 - dirv * 10 * k
	var flex := pull * 5.0
	var top := bow_c + Vector2(-6 - flex, -22) * k
	var bot := bow_c + Vector2(-6 - flex, 22) * k
	var limb := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		limb.append(top.lerp(bot, u) + Vector2((sin(u * PI) * 7 + (-3.0 if u < 0.1 or u > 0.9 else 0.0)) * k, 0))
	ci.draw_polyline(limb, wood.lightened(0.1), 4.0 * k)
	ci.draw_circle(top, 2.0 * k, gold)
	ci.draw_circle(bot, 2.0 * k, gold)
	var nock := bow_c - dirv * (6 + 22 * pull) * k
	ci.draw_polyline(PackedVector2Array([top, nock, bot]), Color(0.9, 0.88, 0.8, 0.9), 1.2)
	if atk < 0.0 or atk < 0.4 or atk > 0.9:
		ci.draw_line(nock, nock + dirv * 40 * k, wood.darkened(0.2), 2.4)
		_poly(ci, [nock + dirv * 40 * k + Vector2(0, -3), nock + dirv * 47 * k, nock + dirv * 40 * k + Vector2(0, 3)], metal.lightened(0.2))
	ci.draw_rect(Rect2(Vector2(-8, -28) * k, Vector2(14, 8) * k), tm)
	for x in [-20.0, 18.0]:
		_wheel(ci, Vector2(x, -9) * k, 9 * k, roll, wood.darkened(0.2), metal, 6)


static func trebuchet(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var wood := _wood(pose)
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
	_crew(ci, st, pal, team, pose, seed, Vector2(-44, 0))


## Wheeled gun: great cannon (bronze), bombard (squat, banded, on a sled), flame cannon (dragon
## muzzle) and rune cannon (dark iron with glowing rune bands).
static func cannon(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var variant: String = st.get("variant", "great")
	var kick := maxf(0.0, swing(pose.get("atk", -1.0))) * 7.0
	var roll: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var metal: Color = _c(pal[2], pose)
	var tm := _c(team, pose)
	var wood := _wood(pose)
	var g: Color = _look.glow
	var barrel_col: Color = {"great": Color("b98a3e"), "bombard": Color("4e4c4a"), "flame": Color("a8743a"), "rune": Color("3a3a44")}.get(variant, Color("5b604a"))
	var gun := _c(barrel_col, pose)
	_shadow(ci, 38)
	_crew(ci, st, pal, team, pose, seed, Vector2(-38, 0))
	var elev := -0.5 if variant == "bombard" else -0.22
	var dirv := Vector2(1, 0).rotated(elev)
	var breech := Vector2(-6, -28) - dirv * kick
	var length := 34.0 if variant == "bombard" else 50.0
	var r0 := 9.0 if variant == "bombard" else 7.0
	var r1 := 10.5 if variant == "bombard" else 5.0
	var muzzle := breech + dirv * length
	var n := dirv.orthogonal()
	if variant == "bombard":
		# Sled carriage.
		_shade_poly(ci, [Vector2(-28, -4), Vector2(26, -4), Vector2(30, -14), Vector2(-24, -20)], wood.darkened(0.15))
		ci.draw_line(Vector2(-32, -2), Vector2(32, -2), wood.darkened(0.35), 4.0)
	else:
		# Trail and cheeks.
		_shade_poly(ci, [Vector2(-34, -4), Vector2(-28, -2), Vector2(8, -22), Vector2(4, -30)], wood.darkened(0.1))
	_shade_poly(ci, [breech - n * r0, muzzle - n * r1, muzzle + n * r1, breech + n * r0], gun)
	ci.draw_circle(breech, r0 * 0.9, gun.darkened(0.15))
	for i in 3:
		var p := breech + dirv * (8 + i * (length - 12) / 2.0)
		var rr := lerpf(r0, r1, (8 + i * (length - 12) / 2.0) / length) + 1.2
		ci.draw_line(p - n * rr, p + n * rr, gun.lightened(0.18) if variant != "rune" else Color(g, 0.6 + 0.35 * sin(t * 3.0 + i)), 2.2)
	match variant:
		"flame":
			# Dragon-mouth muzzle with a banked glow inside.
			_shade_poly(ci, [muzzle - n * (r1 + 3), muzzle + dirv * 7 - n * 2, muzzle + dirv * 9 + n * 1, muzzle + n * (r1 + 3)], gun.lightened(0.1))
			ci.draw_circle(muzzle + dirv * 2, 3.0, Color(1.0, 0.55, 0.2, 0.7 + 0.3 * sin(t * 9.0)))
			ci.draw_circle(muzzle - n * 2 + dirv * 1, 1.0, Color(0.1, 0.05, 0.02))
		"rune":
			_halo(ci, muzzle, 7.0, g, 0.6 + 0.3 * sin(t * 3.0))
			ci.draw_circle(breech, 3.0, Color(g, 0.9))
		_:
			ci.draw_circle(muzzle, r1 + 1.5, gun.lightened(0.1))
			ci.draw_circle(muzzle + dirv * 1.5, r1 * 0.55, Color(0.08, 0.07, 0.06))
	ci.draw_rect(Rect2(Vector2(-2, -22), Vector2(10, 7)), tm)
	if variant != "bombard":
		_wheel(ci, Vector2(0, -14), 14, roll, wood.darkened(0.25) if variant != "rune" else metal.darkened(0.35), metal, 10)


## Steam Juggernaut: a riveted brass-and-iron hull on a great drive wheel, smokestack puffing,
## with a crystal cannon in the cupola.
static func steamtank(ci: CanvasItem, _pal: Array, team: Color, pose: Dictionary) -> void:
	var brass := _c(Color("b8914a"), pose)
	var iron := _c(Color("4a4c52"), pose)
	var tm := _c(team, pose)
	var g: Color = _look.glow
	var t: float = pose.get("t", 0.0)
	var roll: float = pose.get("walk", 0.0) * 1.6
	var kick := maxf(0.0, swing(pose.get("atk", -1.0))) * 4.0
	var bob := sin(t * 9.0) * 0.6 * _mv(pose)
	_shadow(ci, 44)
	_push(ci, Transform2D(0.0, Vector2(0, bob)))
	# Smokestack and puffs (drift back as it rolls).
	ci.draw_rect(Rect2(Vector2(-26, -66), Vector2(8, 22)), iron.darkened(0.2))
	ci.draw_rect(Rect2(Vector2(-28, -68), Vector2(12, 4)), brass)
	for k in 3:
		var u := fmod(t * 0.8 + k / 3.0, 1.0)
		ci.draw_circle(Vector2(-22 - u * 26, -72 - u * 26), 4.0 + u * 7.0, Color(0.85, 0.85, 0.82, 0.45 * (1.0 - u)))
	_shade_poly(ci, [Vector2(-42, -14), Vector2(36, -14), Vector2(44, -26), Vector2(34, -44), Vector2(-30, -46), Vector2(-44, -30)], brass)
	_shade_poly(ci, [Vector2(-40, -18), Vector2(34, -18), Vector2(38, -26), Vector2(-42, -28)], iron)
	_rivets(ci, Vector2(-38, -42), Vector2(30, -42), 9, brass.lightened(0.35), 1.2)
	_rivets(ci, Vector2(-38, -22), Vector2(34, -22), 9, iron.lightened(0.3), 1.1)
	_poly(ci, [Vector2(-34, -30), Vector2(-8, -30), Vector2(-8, -38), Vector2(-32, -38)], tm)
	# Porthole with furnace light.
	ci.draw_circle(Vector2(8, -34), 4.5, brass.darkened(0.2))
	ci.draw_circle(Vector2(8, -34), 3.0, Color(1.0, 0.6, 0.25, 0.8 + 0.2 * sin(t * 7.0)))
	# Cupola and crystal cannon.
	_shade_poly(ci, _ellipse_pts(Vector2(-2, -50), Vector2(15, 8), 0.0, 14), iron)
	ci.draw_line(Vector2(8, -52), Vector2(40 - kick, -56), brass.darkened(0.2), 5.0)
	ci.draw_line(Vector2(18 - kick, -54), Vector2(36 - kick, -56), Color(g, 0.6 + 0.35 * sin(t * 6.0)), 2.0)
	_halo(ci, Vector2(40 - kick, -56), 4.0, g, 0.7)
	_pop(ci)
	_wheel(ci, Vector2(-24, -16), 16, roll, iron.darkened(0.2), brass, 8)
	for x in [8.0, 30.0]:
		_wheel(ci, Vector2(x, -9), 9, roll * 1.7, iron.darkened(0.2), brass, 6)


## Steam Golem: an iron-and-brass walker with a furnace chest and a hammer fist.
static func golem(ci: CanvasItem, _pal: Array, team: Color, pose: Dictionary) -> void:
	var mv := _mv(pose)
	var walk: float = pose.get("walk", 0.0) * 0.8
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var iron := _c(Color("5a5a62"), pose)
	var brass := _c(Color("c09a4a"), pose)
	var tm := _c(team, pose)
	var g: Color = _look.glow
	var bob := lerpf(sin(t * 1.3) * 0.8, absf(sin(walk)) * 3.0, mv)
	var hip := Vector2(0, -40 + bob)
	_shadow(ci, 30)
	for i in [1, 0]:
		var ph: float = walk + PI * i
		var a := lerpf(0.1 if i == 0 else -0.1, sin(ph) * 0.45, mv)
		var knee := hip + Vector2(4, 18).rotated(-a)
		var ankle := knee + Vector2(-2, 18).rotated(-a + maxf(0.0, cos(ph)) * 0.5 * mv)
		var c := iron.darkened(0.3 if i == 1 else 0.0)
		_seg(ci, hip, knee, 13.0, 11.0, c)
		ci.draw_circle(knee, 5.0, brass.darkened(0.2 if i == 1 else 0.0))
		_seg(ci, knee, ankle, 11.0, 10.0, c)
		_shade_poly(ci, [ankle + Vector2(-10, 4), ankle + Vector2(13, 4), ankle + Vector2(10, -4), ankle + Vector2(-7, -4)], c.darkened(0.15))
	# Back arm.
	_seg(ci, hip + Vector2(-8, -30), hip + Vector2(-14, -8), 10.0, 9.0, iron.darkened(0.3))
	# Barrel body with a furnace.
	var body := [hip + Vector2(-20, 2), hip + Vector2(18, 2), hip + Vector2(22, -24), hip + Vector2(14, -40), hip + Vector2(-16, -40), hip + Vector2(-22, -22)]
	_shade_poly(ci, body, iron)
	ci.draw_line(hip + Vector2(-21, -14), hip + Vector2(20, -14), brass, 3.0)
	ci.draw_line(hip + Vector2(-19, -34), hip + Vector2(17, -34), brass, 3.0)
	_rivets(ci, hip + Vector2(-19, -14), hip + Vector2(19, -14), 7, brass.lightened(0.35), 1.1)
	ci.draw_rect(Rect2(hip + Vector2(0, -30), Vector2(12, 12)), Color(0.12, 0.1, 0.1))
	ci.draw_rect(Rect2(hip + Vector2(1.5, -28.5), Vector2(9, 9)), Color(1.0, 0.55, 0.2, 0.75 + 0.25 * sin(t * 8.0)))
	for k in 3:
		ci.draw_line(hip + Vector2(1.5, -26 + k * 3), hip + Vector2(10.5, -26 + k * 3), Color(0.15, 0.1, 0.08), 1.0)
	_poly(ci, [hip + Vector2(-18, -10), hip + Vector2(-4, -10), hip + Vector2(-4, -2), hip + Vector2(-18, -2)], tm)
	# Head: a small domed helm with a rune visor.
	var head := hip + Vector2(4, -46)
	_shade_poly(ci, _ellipse_pts(head, Vector2(9, 7.5)), brass)
	ci.draw_line(head + Vector2(0, 0), head + Vector2(9, 0), Color(g, 0.95), 2.4)
	# Chimney pipes puffing.
	ci.draw_rect(Rect2(hip + Vector2(-18, -52), Vector2(5, 14)), iron.darkened(0.25))
	var u := fmod(t * 0.9, 1.0)
	ci.draw_circle(hip + Vector2(-16 - u * 10, -54 - u * 20), 3.0 + u * 6.0, Color(0.85, 0.85, 0.82, 0.4 * (1.0 - u)))
	# Front arm: a piston swing into a hammer fist.
	var theta := 0.3
	if atk >= 0.0:
		theta = lerpf(0.3, 2.4, ease(atk / 0.35, 0.6)) if atk < 0.35 else (lerpf(2.4, 0.9, ease((atk - 0.35) / 0.15, 0.4)) if atk < 0.5 else lerpf(0.9, 0.3, (atk - 0.5) / 0.5))
	var shp := hip + Vector2(10, -32)
	var elbow := shp + Vector2(0, 16).rotated(-theta)
	var fist := elbow + Vector2(0, 14).rotated(-theta * 0.7 - 0.5)
	ci.draw_circle(shp, 7.0, brass)
	_seg(ci, shp, elbow, 10.0, 9.0, iron)
	_seg(ci, elbow, fist, 9.0, 8.0, iron.lightened(0.05))
	var orth := (fist - elbow).normalized().orthogonal()
	var fd := (fist - elbow).normalized()
	_shade_poly(ci, [fist - orth * 9 - fd * 3, fist + orth * 9 - fd * 3, fist + orth * 9 + fd * 8, fist - orth * 9 + fd * 8], iron.darkened(0.2))
	ci.draw_line(fist - orth * 7 + fd * 2.5, fist + orth * 7 + fd * 2.5, Color(g, 0.7), 1.6)


## Treant: a walking tree — root feet, bark body, branch arms and a leafy crown.
static func treant(ci: CanvasItem, team: Color, pose: Dictionary, seed: int) -> void:
	var mv := _mv(pose)
	var walk: float = pose.get("walk", 0.0) * 0.7
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var bark := _c(Color("6a5038"), pose)
	var leaf := _c(Color("4f7f3c"), pose)
	var tm := _c(team, pose)
	var g: Color = _look.glow
	var bob := lerpf(sin(t * 1.1 + seed) * 0.8, absf(sin(walk)) * 2.5, mv)
	var hip := Vector2(0, -34 + bob)
	_shadow(ci, 30)
	for i in [1, 0]:
		var ph: float = walk + PI * i
		var a := lerpf(0.1 if i == 0 else -0.1, sin(ph) * 0.45, mv)
		var knee := hip + Vector2(3, 17).rotated(-a)
		var foot := knee + Vector2(0, 17).rotated(-a + maxf(0.0, cos(ph)) * 0.5 * mv)
		var c := bark.darkened(0.3 if i == 1 else 0.0)
		_seg(ci, hip, knee, 14.0, 11.0, c)
		_seg(ci, knee, foot, 11.0, 9.0, c)
		for k in 3:
			ci.draw_line(foot, foot + Vector2(-8 + k * 9, 3 + (k % 2) * 1.5), c.darkened(0.1), 3.0)
	# Back branch arm.
	var sway := sin(t * 1.4 + seed) * 0.08
	_seg(ci, hip + Vector2(-8, -38), hip + Vector2(-22, -14), 8.0, 5.0, bark.darkened(0.3))
	# Trunk with bark grooves, a knot face with glowing eyes, and a team sash of woven vines.
	var trunk := [hip + Vector2(-15, 4), hip + Vector2(15, 4), hip + Vector2(13, -30), hip + Vector2(10, -52), hip + Vector2(-10, -54), hip + Vector2(-14, -30)]
	_shade_poly(ci, trunk, bark)
	for k in 4:
		ci.draw_polyline(PackedVector2Array([hip + Vector2(-10 + k * 6, 2), hip + Vector2(-8 + k * 6 + sin(k) * 2, -24), hip + Vector2(-9 + k * 6, -48)]), bark.darkened(0.3), 1.4)
	_ellipse(ci, hip + Vector2(4, -40), Vector2(7, 5), bark.darkened(0.35))
	for e in [Vector2(1, -41), Vector2(8, -41)]:
		_halo(ci, hip + e, 3.0, g, 0.8)
		ci.draw_circle(hip + e, 1.2, Color(1, 1, 1, 0.9))
	ci.draw_line(hip + Vector2(-15, -14), hip + Vector2(15, -20), tm, 4.0)
	# Leafy crown, swaying.
	var crown := hip + Vector2(0, -62)
	for k in 9:
		var a := TAU * k / 9.0 + sway
		var p := crown + Vector2(cos(a) * 17, sin(a) * 11)
		_shade_poly(ci, _ellipse_pts(p, Vector2(10, 8), a, 10), leaf.darkened(0.12 * (k % 3)))
	_shade_poly(ci, _ellipse_pts(crown + Vector2(2, -2), Vector2(14, 10), 0.0, 12), leaf.lightened(0.06))
	for k in 5:
		ci.draw_circle(crown + Vector2(-12 + k * 6, -8 + sin(k * 2.1) * 6), 1.6, Color(g, 0.7))
	# Front branch arm: a heavy overhead slam.
	var theta := 0.35
	if atk >= 0.0:
		theta = lerpf(0.35, 2.5, ease(atk / 0.35, 0.6)) if atk < 0.35 else (lerpf(2.5, 0.8, ease((atk - 0.35) / 0.15, 0.4)) if atk < 0.5 else lerpf(0.8, 0.35, (atk - 0.5) / 0.5))
	var shp := hip + Vector2(8, -40)
	var elbow := shp + Vector2(0, 18).rotated(-theta)
	var hand := elbow + Vector2(0, 16).rotated(-theta * 0.8 - 0.4)
	_seg(ci, shp, elbow, 10.0, 8.0, bark)
	_seg(ci, elbow, hand, 8.0, 6.0, bark.lightened(0.05))
	for k in 3:
		ci.draw_line(hand, hand + (hand - elbow).normalized().rotated(-0.6 + k * 0.6) * 9.0, bark.darkened(0.1), 2.6)
	_ellipse(ci, elbow + Vector2(-2, -4), Vector2(5, 3), leaf, 0.6)


## Sky Cannon: a long brass barrel on a gilded carriage, ringed with floating arcane circles.
static func skycannon(ci: CanvasItem, _pal: Array, team: Color, pose: Dictionary) -> void:
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var roll: float = pose.get("walk", 0.0)
	var brass := _c(Color("c9a45c"), pose)
	var dark := _c(Color("3a3448"), pose)
	var tm := _c(team, pose)
	var g: Color = _look.glow
	var charge := clampf(atk / 0.35, 0.0, 1.0) if atk >= 0.0 and atk < 0.35 else 0.0
	var kick := maxf(0.0, swing(atk)) * 5.0
	_shadow(ci, 42)
	_shade_poly(ci, [Vector2(-40, -6), Vector2(36, -6), Vector2(42, -18), Vector2(-42, -20)], dark)
	_shade_poly(ci, [Vector2(-30, -18), Vector2(22, -18), Vector2(16, -32), Vector2(-26, -32)], brass.darkened(0.2))
	ci.draw_rect(Rect2(Vector2(-24, -29), Vector2(16, 8)), tm)
	var dirv := Vector2(1, -0.42).normalized()
	var b0 := Vector2(-12, -38) - dirv * kick
	var b1 := b0 + dirv * 72
	var n := dirv.orthogonal()
	_shade_poly(ci, [b0 - n * 7, b1 - n * 4, b1 + n * 4, b0 + n * 7], brass)
	ci.draw_line(b0 + dirv * 6, b1, brass.darkened(0.35), 1.2)
	for i in 3:
		var c := b0 + dirv * (22 + i * 16)
		var r := 9.0 - i * 1.2 + charge * 2.0
		var spin := t * (1.5 + i * 0.4) + i
		ci.draw_arc(c, r, spin, spin + TAU * 0.8, 16, Color(g, 0.55 + 0.3 * sin(t * 4.0 + i) + charge * 0.3), 1.6)
	_halo(ci, b1, 5.0 + charge * 5.0, g, 0.6 + charge * 0.4)
	for x in [-26.0, 22.0]:
		_wheel(ci, Vector2(x, -9), 10, roll, dark, brass, 8)


## Starfall Obelisk: a crystal spire hovering over a runner-sled, pushed by an elven crew.
static func obelisk(ci: CanvasItem, st: Dictionary, pal: Array, team: Color, pose: Dictionary, seed: int) -> void:
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var wood := _c(Color("b89a6a"), pose)
	var stone := _c(Color("d8dce8"), pose)
	var tm := _c(team, pose)
	var g: Color = _look.glow
	var charge := clampf(atk / 0.35, 0.0, 1.0) if atk >= 0.0 and atk < 0.35 else 0.0
	_shadow(ci, 38)
	_crew(ci, st, pal, team, pose, seed, Vector2(-40, 0))
	# Sled with curled runners and a carved plinth.
	ci.draw_polyline(PackedVector2Array([Vector2(-32, -3), Vector2(28, -3), Vector2(36, -8), Vector2(34, -13)]), wood.darkened(0.3), 3.0)
	_shade_poly(ci, [Vector2(-26, -6), Vector2(22, -6), Vector2(18, -18), Vector2(-22, -18)], wood)
	_shade_poly(ci, [Vector2(-14, -18), Vector2(10, -18), Vector2(6, -26), Vector2(-10, -26)], stone.darkened(0.2))
	ci.draw_rect(Rect2(Vector2(-18, -14), Vector2(12, 6)), tm)
	# The crystal hovers and bobs; motes orbit it.
	var hover := sin(t * 1.8 + seed) * 3.0
	var base := Vector2(-2, -34 + hover)
	var crystal := [base + Vector2(-7, 0), base + Vector2(7, 0), base + Vector2(5, -40), base + Vector2(0, -52), base + Vector2(-5, -40)]
	_halo(ci, base + Vector2(0, -26), 20.0 + charge * 10.0, g, 0.35 + charge * 0.5)
	_shade_poly(ci, crystal, stone.lerp(g, 0.35 + charge * 0.4))
	ci.draw_line(base + Vector2(0, -2), base + Vector2(0, -50), Color(1, 1, 1, 0.55), 1.4)
	for k in 4:
		var a := t * 1.6 + TAU * k / 4.0
		ci.draw_circle(base + Vector2(cos(a) * 16, -26 + sin(a) * 6), 1.8, Color(g, 0.85))
	_halo(ci, base + Vector2(0, 4), 6.0, g, 0.5)
