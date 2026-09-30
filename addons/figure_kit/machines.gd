class_name FkMachines
extends RefCounted
## Siege engines and walkers: ram, catapult, ballista, trebuchet, cannon, steam tank, golem,
## treant, sky cannon and obelisk, with their crews.


static func wood(pose: Dictionary) -> Color:
	return FkPaint.tint(Color("7a5532"), pose)


static func ram(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var pal: Array = st.palette
	var team: Color = st.team
	var variant: String = st.get("variant", "wood")
	var wood := FkPaint.tint(Color("75512f"), pose)
	var roof := FkPaint.tint(Color("8c6b3f"), pose)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var tm := FkPaint.tint(team, pose)
	var thrust := maxf(0.0, FkUnits.swing(pose.get("atk", -1.0))) * 14.0 - maxf(0.0, -FkUnits.swing(pose.get("atk", -1.0))) * 6.0
	var roll: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	FkPaint.shadow(ci, 38)
	FkFigure.crew(ci, st, pose, seed, Vector2(-26, 0))
	match variant:
		"root":
			# Rootbreaker: a living trunk, still sprouting, slung under a canopy of woven boughs.
			var bark := FkPaint.tint(Color("5e4a36"), pose)
			ci.draw_line(Vector2(-30 + thrust, -24), Vector2(32 + thrust, -24), bark, 10.0)
			for k in 4:
				ci.draw_line(Vector2(-24 + k * 14 + thrust, -28), Vector2(-18 + k * 14 + thrust, -20), bark.darkened(0.3), 1.2)
			FkPaint.shade_poly(ci, [Vector2(32 + thrust, -30), Vector2(40 + thrust, -27), Vector2(42 + thrust, -21), Vector2(32 + thrust, -18)], bark.darkened(0.15))
			for k in 3:
				ci.draw_line(Vector2(38 + thrust, -24), Vector2(46 + thrust + k * 2, -30 + k * 6), bark.darkened(0.2), 1.6)
			FkPaint.ellipse(ci, Vector2(-6 + thrust, -31), Vector2(5, 3), FkPaint.tint(Color("6a9a4a"), pose), -0.4)
			ci.draw_line(Vector2(-26, -16), Vector2(-20, -48), wood, 3.0)
			ci.draw_line(Vector2(18, -16), Vector2(12, -48), wood, 3.0)
			var leaf := FkPaint.tint(Color("4f7a3a"), pose)
			for k in 7:
				var lx := -30 + k * 8.0
				FkPaint.shade_poly(ci, FkPaint.ellipse_pts(Vector2(lx, -50 - absf(sin(k * 1.7)) * 4), Vector2(8, 5), -0.3 + sin(t + k) * 0.05, 8), leaf.darkened(0.08 * (k % 2)))
			ci.draw_line(Vector2(-18, -44), Vector2(6, -44), tm, 3.0)
		"iron":
			# Dwarf ram: iron-shod beam with a ram's-head, under an iron-plated roof.
			ci.draw_line(Vector2(-30 + thrust, -24), Vector2(34 + thrust, -24), wood.darkened(0.15), 8.0)
			FkPaint.shade_poly(ci, [Vector2(30 + thrust, -31), Vector2(42 + thrust, -28), Vector2(44 + thrust, -20), Vector2(30 + thrust, -17)], metal)
			ci.draw_arc(Vector2(36 + thrust, -31), 5.0, PI, TAU + 0.8, 10, FkPaint.tint(Color("c9b48a"), pose), 2.6)
			FkPaint.shade_poly(ci, [Vector2(-34, -16), Vector2(24, -16), Vector2(18, -42), Vector2(-8, -52), Vector2(-30, -42)], metal.darkened(0.3))
			for i in 4:
				ci.draw_line(Vector2(-30 + i * 14, -18), Vector2(-24 + i * 11, -46), metal.darkened(0.5), 1.4)
			FkPaint.rivets(ci, Vector2(-30, -42), Vector2(18, -42), 7, metal.lightened(0.3))
			FkPaint.poly(ci, [Vector2(-18, -28), Vector2(4, -28), Vector2(2, -38), Vector2(-14, -40)], tm)
		_:
			ci.draw_line(Vector2(-30 + thrust, -24), Vector2(34 + thrust, -24), wood.darkened(0.15), 8.0)
			ci.draw_circle(Vector2(36 + thrust, -24), 6.0, metal)
			FkPaint.poly(ci, [Vector2(-34, -16), Vector2(24, -16), Vector2(18, -42), Vector2(-8, -54), Vector2(-30, -42)], roof)
			for i in 5:
				ci.draw_line(Vector2(-30 + i * 11, -18), Vector2(-24 + i * 9, -46), roof.darkened(0.25), 2.0)
			FkPaint.poly(ci, [Vector2(-18, -30), Vector2(4, -30), Vector2(2, -40), Vector2(-14, -42)], tm)
	for x in [-24.0, 14.0]:
		FkPaint.wheel(ci, Vector2(x, -9), 9, roll, wood if variant != "iron" else metal.darkened(0.3), metal, 5)


## Torsion engine (onager / stone hurler / moonfire catapult): the arm lies back loaded and slams
## up into the crossbar on release.
static func catapult(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var pal: Array = st.palette
	var team: Color = st.team
	var variant: String = st.get("variant", "onager")
	var atk: float = pose.get("atk", -1.0)
	var t: float = pose.get("t", 0.0)
	var roll: float = pose.get("walk", 0.0)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var tm := FkPaint.tint(team, pose)
	var wood := wood(pose)
	if variant == "moonfire":
		wood = FkPaint.tint(Color("a88a5a"), pose)
	elif variant == "stone":
		wood = FkPaint.tint(Color("5e4630"), pose)
	var rest := -2.84
	var fire := -1.35
	var arm := rest
	if atk >= 0.0:
		arm = lerpf(rest, fire, ease(clampf((atk - 0.25) / 0.15, 0.0, 1.0), 0.3)) if atk < 0.7 else lerpf(fire, rest, (atk - 0.7) / 0.3)
	FkPaint.shadow(ci, 40)
	FkFigure.crew(ci, st, pose, seed, Vector2(-46, 0))
	# Frame: sill beams, uprights and the stop-beam.
	ci.draw_line(Vector2(-34, -14), Vector2(34, -14), wood.darkened(0.2), 7.0)
	ci.draw_line(Vector2(-28, -22), Vector2(28, -22), wood.darkened(0.1), 4.0)
	ci.draw_line(Vector2(10, -14), Vector2(8, -56), wood, 5.0)
	ci.draw_line(Vector2(24, -14), Vector2(10, -52), wood.darkened(0.1), 4.0)
	ci.draw_line(Vector2(2, -54), Vector2(14, -56), wood.lightened(0.1), 6.0)
	FkPaint.shade_poly(ci, [Vector2(4, -60), Vector2(14, -60), Vector2(14, -52), Vector2(4, -52)], tm)
	if variant == "stone":
		FkPaint.rivets(ci, Vector2(-32, -14), Vector2(32, -14), 7, metal.lightened(0.2), 1.3)
	# Torsion bundle and arm.
	var pivot := Vector2(-18, -22)
	ci.draw_circle(pivot, 6.5, FkPaint.tint(Color("8a7a5a"), pose))
	ci.draw_circle(pivot, 3.0, metal)
	var tip := pivot + Vector2(50, 0).rotated(arm)
	ci.draw_line(pivot, tip, wood.lightened(0.12), 5.0)
	var cup := tip + Vector2(0, -3).rotated(arm + PI * 0.5)
	FkPaint.ellipse(ci, cup, Vector2(6, 3.5), wood.darkened(0.25), arm)
	var loaded := atk < 0.0 or atk < 0.35 or atk > 0.85
	if loaded:
		match variant:
			"moonfire":
				var g: Color = st.look.glow
				FkPaint.halo(ci, cup + Vector2(0, -4).rotated(arm + PI * 0.5), 9.0, g, 0.8 + 0.2 * sin(t * 5.0))
				ci.draw_circle(cup + Vector2(0, -4).rotated(arm + PI * 0.5), 3.4, Color(1, 1, 1, 0.9))
			_:
				ci.draw_circle(cup + Vector2(0, -4).rotated(arm + PI * 0.5), 5.0 if variant == "stone" else 4.2, FkPaint.tint(Color("7b7466"), pose))
	if variant == "moonfire":
		# Living-wood flourishes on the uprights.
		ci.draw_arc(Vector2(10, -58), 6.0, PI, TAU, 8, FkPaint.tint(Color("5f8a45"), pose), 2.0)
		FkPaint.ellipse(ci, Vector2(4, -62), Vector2(4, 2.2), FkPaint.tint(Color("6a9a4a"), pose), -0.6)
	for x in [-24.0, 22.0]:
		FkPaint.wheel(ci, Vector2(x, -9), 9, roll, wood if variant != "stone" else metal.darkened(0.35), metal, 6)


## Bolt thrower on a wheeled stand: the bow limbs flex back, then the bolt flies.
static func ballista(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var pal: Array = st.palette
	var team: Color = st.team
	var great: bool = st.get("variant", "") == "great"
	var k := 1.25 if great else 1.0
	var atk: float = pose.get("atk", -1.0)
	var roll: float = pose.get("walk", 0.0)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var tm := FkPaint.tint(team, pose)
	var wood := FkPaint.tint(Color("a88a5a"), pose)
	var gold := FkPaint.tint(Color("d9b25c"), pose)
	# Loaded (drawn) at rest; released at contact and re-spanned during recovery.
	var pull := 1.0
	if atk >= 0.0:
		pull = 1.0 if atk < 0.4 else (0.0 if atk < 0.7 else (atk - 0.7) / 0.3)
	FkPaint.shadow(ci, 36 * k)
	FkFigure.crew(ci, st, pose, seed, Vector2(-40 * k, 0))
	if great:
		FkFigure.crew(ci, st, pose, seed + 1, Vector2(-26 * k, 0))
	ci.draw_line(Vector2(-30, -12) * k, Vector2(28, -12) * k, wood.darkened(0.3), 6.0)
	ci.draw_line(Vector2(-4, -12) * k, Vector2(0, -32) * k, wood.darkened(0.15), 5.0)
	ci.draw_line(Vector2(10, -12) * k, Vector2(2, -32) * k, wood.darkened(0.2), 4.0)
	# Stock (slightly elevated), bow limbs curving like a leaf, and the string.
	var el := -0.12
	var s0 := Vector2(-22, -36) * k
	var dirv := Vector2(1, 0).rotated(el)
	var s1 := s0 + dirv * 56 * k
	FkPaint.shade_poly(ci, [s0 + Vector2(0, -3) * k, s1 + Vector2(0, -3) * k, s1 + Vector2(0, 3) * k, s0 + Vector2(0, 3) * k], wood)
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
		FkPaint.poly(ci, [nock + dirv * 40 * k + Vector2(0, -3), nock + dirv * 47 * k, nock + dirv * 40 * k + Vector2(0, 3)], metal.lightened(0.2))
	ci.draw_rect(Rect2(Vector2(-8, -28) * k, Vector2(14, 8) * k), tm)
	for x in [-20.0, 18.0]:
		FkPaint.wheel(ci, Vector2(x, -9) * k, 9 * k, roll, wood.darkened(0.2), metal, 6)


static func trebuchet(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var pal: Array = st.palette
	var team: Color = st.team
	var wood := wood(pose)
	var atk: float = pose.get("atk", -1.0)
	var arm := -2.3
	if atk >= 0.0:
		arm = lerpf(-2.3, -0.5, ease(clampf((atk - 0.2) / 0.3, 0.0, 1.0), 0.3)) if atk < 0.7 else lerpf(-0.5, -2.3, (atk - 0.7) / 0.3)
	var roll: float = pose.get("walk", 0.0)
	FkPaint.shadow(ci, 40)
	ci.draw_line(Vector2(-34, -12), Vector2(34, -12), wood.darkened(0.2), 7.0)
	ci.draw_line(Vector2(-22, -12), Vector2(0, -70), wood, 5.0)
	ci.draw_line(Vector2(22, -12), Vector2(0, -70), wood, 5.0)
	var pivot := Vector2(0, -70)
	var long_end := pivot + Vector2(56, 0).rotated(arm)
	var short_end := pivot + Vector2(-18, 0).rotated(arm)
	ci.draw_line(short_end, long_end, wood.lightened(0.1), 5.0)
	ci.draw_rect(Rect2(short_end + Vector2(-9, 0), Vector2(18, 16)), FkPaint.tint(pal[2], pose).darkened(0.3))
	ci.draw_line(long_end, long_end + Vector2(0, 14).rotated(arm * 0.3), Color("c9b28a"), 1.5)
	ci.draw_rect(Rect2(Vector2(-12, -36), Vector2(24, 10)), FkPaint.tint(team, pose))
	for x in [-26.0, 26.0]:
		FkPaint.wheel(ci, Vector2(x, -8), 8, roll, wood, FkPaint.tint(pal[2], pose), 5)
	FkFigure.crew(ci, st, pose, seed, Vector2(-44, 0))


## Wheeled gun: great cannon (bronze), bombard (squat, banded, on a sled), flame cannon (dragon
## muzzle) and rune cannon (dark iron with glowing rune bands).
static func cannon(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var pal: Array = st.palette
	var team: Color = st.team
	var variant: String = st.get("variant", "great")
	var kick := maxf(0.0, FkUnits.swing(pose.get("atk", -1.0))) * 7.0
	var roll: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var tm := FkPaint.tint(team, pose)
	var wood := wood(pose)
	var g: Color = st.look.glow
	var barrel_col: Color = {"great": Color("b98a3e"), "bombard": Color("4e4c4a"), "flame": Color("a8743a"), "rune": Color("3a3a44")}.get(variant, Color("5b604a"))
	var gun := FkPaint.tint(barrel_col, pose)
	FkPaint.shadow(ci, 38)
	FkFigure.crew(ci, st, pose, seed, Vector2(-38, 0))
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
		FkPaint.shade_poly(ci, [Vector2(-28, -4), Vector2(26, -4), Vector2(30, -14), Vector2(-24, -20)], wood.darkened(0.15))
		ci.draw_line(Vector2(-32, -2), Vector2(32, -2), wood.darkened(0.35), 4.0)
	else:
		# Trail and cheeks.
		FkPaint.shade_poly(ci, [Vector2(-34, -4), Vector2(-28, -2), Vector2(8, -22), Vector2(4, -30)], wood.darkened(0.1))
	FkPaint.shade_poly(ci, [breech - n * r0, muzzle - n * r1, muzzle + n * r1, breech + n * r0], gun)
	ci.draw_circle(breech, r0 * 0.9, gun.darkened(0.15))
	for i in 3:
		var p := breech + dirv * (8 + i * (length - 12) / 2.0)
		var rr := lerpf(r0, r1, (8 + i * (length - 12) / 2.0) / length) + 1.2
		ci.draw_line(p - n * rr, p + n * rr, gun.lightened(0.18) if variant != "rune" else Color(g, 0.6 + 0.35 * sin(t * 3.0 + i)), 2.2)
	match variant:
		"flame":
			# Dragon-mouth muzzle with a banked glow inside.
			FkPaint.shade_poly(ci, [muzzle - n * (r1 + 3), muzzle + dirv * 7 - n * 2, muzzle + dirv * 9 + n * 1, muzzle + n * (r1 + 3)], gun.lightened(0.1))
			ci.draw_circle(muzzle + dirv * 2, 3.0, Color(1.0, 0.55, 0.2, 0.7 + 0.3 * sin(t * 9.0)))
			ci.draw_circle(muzzle - n * 2 + dirv * 1, 1.0, Color(0.1, 0.05, 0.02))
		"rune":
			FkPaint.halo(ci, muzzle, 7.0, g, 0.6 + 0.3 * sin(t * 3.0))
			ci.draw_circle(breech, 3.0, Color(g, 0.9))
		_:
			ci.draw_circle(muzzle, r1 + 1.5, gun.lightened(0.1))
			ci.draw_circle(muzzle + dirv * 1.5, r1 * 0.55, Color(0.08, 0.07, 0.06))
	ci.draw_rect(Rect2(Vector2(-2, -22), Vector2(10, 7)), tm)
	if variant != "bombard":
		FkPaint.wheel(ci, Vector2(0, -14), 14, roll, wood.darkened(0.25) if variant != "rune" else metal.darkened(0.35), metal, 10)


## Steam Juggernaut: a riveted brass-and-iron hull on a great drive wheel, smokestack puffing,
## with a crystal cannon in the cupola.
static func steamtank(ci: CanvasItem, st: Dictionary, pose: Dictionary, _seed: int) -> void:
	var team: Color = st.team
	var brass := FkPaint.tint(Color("b8914a"), pose)
	var iron := FkPaint.tint(Color("4a4c52"), pose)
	var tm := FkPaint.tint(team, pose)
	var g: Color = st.look.glow
	var t: float = pose.get("t", 0.0)
	var roll: float = pose.get("walk", 0.0) * 1.6
	var kick := maxf(0.0, FkUnits.swing(pose.get("atk", -1.0))) * 4.0
	var bob := sin(t * 9.0) * 0.6 * FkPaint.move_amount(pose)
	FkPaint.shadow(ci, 44)
	FkPaint.push(ci, Transform2D(0.0, Vector2(0, bob)))
	# Smokestack and puffs (drift back as it rolls).
	ci.draw_rect(Rect2(Vector2(-26, -66), Vector2(8, 22)), iron.darkened(0.2))
	ci.draw_rect(Rect2(Vector2(-28, -68), Vector2(12, 4)), brass)
	for k in 3:
		var u := fmod(t * 0.8 + k / 3.0, 1.0)
		ci.draw_circle(Vector2(-22 - u * 26, -72 - u * 26), 4.0 + u * 7.0, Color(0.85, 0.85, 0.82, 0.45 * (1.0 - u)))
	FkPaint.shade_poly(ci, [Vector2(-42, -14), Vector2(36, -14), Vector2(44, -26), Vector2(34, -44), Vector2(-30, -46), Vector2(-44, -30)], brass)
	FkPaint.shade_poly(ci, [Vector2(-40, -18), Vector2(34, -18), Vector2(38, -26), Vector2(-42, -28)], iron)
	FkPaint.rivets(ci, Vector2(-38, -42), Vector2(30, -42), 9, brass.lightened(0.35), 1.2)
	FkPaint.rivets(ci, Vector2(-38, -22), Vector2(34, -22), 9, iron.lightened(0.3), 1.1)
	FkPaint.poly(ci, [Vector2(-34, -30), Vector2(-8, -30), Vector2(-8, -38), Vector2(-32, -38)], tm)
	# Porthole with furnace light.
	ci.draw_circle(Vector2(8, -34), 4.5, brass.darkened(0.2))
	ci.draw_circle(Vector2(8, -34), 3.0, Color(1.0, 0.6, 0.25, 0.8 + 0.2 * sin(t * 7.0)))
	# Cupola and crystal cannon.
	FkPaint.shade_poly(ci, FkPaint.ellipse_pts(Vector2(-2, -50), Vector2(15, 8), 0.0, 14), iron)
	ci.draw_line(Vector2(8, -52), Vector2(40 - kick, -56), brass.darkened(0.2), 5.0)
	ci.draw_line(Vector2(18 - kick, -54), Vector2(36 - kick, -56), Color(g, 0.6 + 0.35 * sin(t * 6.0)), 2.0)
	FkPaint.halo(ci, Vector2(40 - kick, -56), 4.0, g, 0.7)
	FkPaint.pop(ci)
	FkPaint.wheel(ci, Vector2(-24, -16), 16, roll, iron.darkened(0.2), brass, 8)
	for x in [8.0, 30.0]:
		FkPaint.wheel(ci, Vector2(x, -9), 9, roll * 1.7, iron.darkened(0.2), brass, 6)


## Draw order of a giant's limbs around its body (golem, treant). Drawn facing right, its left side is
## the far one; mirrored (the enemy army), it is the same right-handed body turned around, so its right
## (attacking) arm and leg go behind the body and the left ones come to the front.
static func giant_order(pose: Dictionary) -> Array:
	if pose.get("mirrored", false):
		return ["right leg", "left leg", "right arm", "body", "left arm"]
	return ["left leg", "right leg", "left arm", "body", "right arm"]


## The two-legged giants' walk (see FkGait): stride (px a foot reaches ahead of the hips), lift, ankle angles, the bones (thigh,
## shin), the ankle's height over the sole for a flat foot, the idle feet and the standing hip height.
const GIANT_GAITS := {
	"golem": {"stride": 15.0, "lift": 7.0, "heel": 0.04, "toe": 0.32, "clear": 0.08, "arc": 1.0,
		"l1": 18.44, "l2": 18.11, "flat": 4.0, "idle": [5.6, -1.6], "hip": 40.0},
	"treant": {"stride": 14.0, "lift": 6.0, "heel": 0.04, "toe": 0.3, "clear": 0.08, "arc": 1.0,
		"l1": 16.9, "l2": 16.8, "flat": 5.0, "idle": [6.4, -0.4], "hip": 38.0},
}
## The golem's iron foot relative to its ankle (sole at y = 4): heel, ball (x = 6, where it bends), toe, top.
const GOLEM_FOOT := [Vector2(-10, 4), Vector2(6, 4), Vector2(13, 4), Vector2(10, -4), Vector2(6, -4), Vector2(-7, -4)]
## The treant's root tips relative to its ankle.
const TREANT_ROOTS := [Vector2(-8, 2), Vector2(1, 3.5), Vector2(10, 2)]


## A giant's foot for this frame, relative to its ankle: the outline (golem) or the root tips (treant), pitched `rot` at the
## ankle, the toe bent `flex` at the ball, squashed by the landing `sq` (0..1).
static func _giant_foot(kind: String, rot: float, flex: float, sq: float) -> Array:
	var out := []
	if kind == "golem":
		for v: Vector2 in GOLEM_FOOT:
			var p := v
			if v.x > 6.0:
				p = Vector2(6, 4) + (v - Vector2(6, 4)).rotated(-flex)
			p = Vector2(p.x * (1.0 + 0.35 * sq), p.y * (1.0 - 0.4 * sq) + 1.6 * sq)
			out.append(p.rotated(rot))
	else:
		for v: Vector2 in TREANT_ROOTS:
			out.append(Vector2(v.x * (1.0 + 0.4 * sq), v.y - 1.5 * sq).rotated(rot))
	return out


static func _giant_low(kind: String, rot: float, flex: float) -> float:
	var low := 0.0
	for p: Vector2 in _giant_foot(kind, rot, flex, 0.0):
		low = maxf(low, p.y + (1.5 if kind == "treant" else 0.0))
	return low


static func _giant_spec(kind: String) -> Dictionary:
	var cfg: Dictionary = GIANT_GAITS[kind]
	return {"l": float(cfg.l1) + float(cfg.l2), "scale": 1.0, "flat": cfg.flat,
		"low": func(rot: float, flex: float) -> float: return _giant_low(kind, rot, flex),
		"root_dx": func(_w: float, _i: int) -> float: return 0.0}


## Where a giant's hips stand and where its two ankles and knees go this frame (`i` = 0 the right leg, 1 the left): the hips
## ride over nearly straight legs, the feet stay put on the ground, the ankles pitch through the stride.
## Returns {hip, legs: [{knee, ankle, foot: Array, low, u, sq}]}.
static func _giant_walk(kind: String, walk: float, mv: float, idle_hip_y: float) -> Dictionary:
	var cfg: Dictionary = GIANT_GAITS[kind]
	var hip_y := lerpf(idle_hip_y, -FkGait.hip_height(cfg, walk, kind, _giant_spec.bind(kind)), mv)
	var hip := Vector2(0, hip_y)
	var legs := []
	for i in 2:
		var ph: float = walk + PI * i
		var pos := FkGait.stride_pos(ph)
		var lift: float = float(cfg.lift) * FkGait.swing_lift(pos) * mv
		var rot: float = FkGait.ankle(pos, cfg) * mv
		var fx := lerpf(float(cfg.idle[i]), float(cfg.stride) * FkGait.foot_x(ph), mv)
		var u := giant_contact(ph) if mv > 0.3 else -1.0
		var sq := 1.0 - u / 0.35 if u >= 0.0 and u < 0.35 else 0.0
		var flex := FkGait.toe_bend(rot, lift)
		var foot := _giant_foot(kind, rot, flex, sq)
		var low := 0.0
		for p: Vector2 in foot:
			low = maxf(low, p.y + (1.5 if kind == "treant" else 0.0))
		var ankle := Vector2(fx, -(low + maxf(0.0, lift - float(cfg.flat))))
		ankle = FkSkeleton.reach(hip, ankle, cfg.l1, cfg.l2)
		var knee := FkSkeleton.ik(hip, ankle, cfg.l1, cfg.l2, FkSkeleton.KNEE)
		legs.append({"knee": knee, "ankle": ankle, "foot": foot, "low": low, "u": u, "sq": sq})
	return {"hip": hip, "legs": legs}


## Steam Golem: an iron-and-brass walker with a furnace chest and a hammer fist.
static func golem(ci: CanvasItem, st: Dictionary, pose: Dictionary, _seed: int) -> void:
	var team: Color = st.team
	var mv := FkPaint.move_amount(pose)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var iron := FkPaint.tint(Color("5a5a62"), pose)
	var brass := FkPaint.tint(Color("c09a4a"), pose)
	var tm := FkPaint.tint(team, pose)
	var g: Color = st.look.glow
	var gw := _giant_walk("golem", walk, mv, -40.0 + (1.0 - sin(t * 1.3)) * 0.4)
	var hip: Vector2 = gw.hip
	var order := giant_order(pose)
	# The side turned away from us is shaded darker.
	var far_side := "left" if order[0] == "left leg" else "right"
	FkPaint.shadow(ci, 30)
	var contacts := []
	for leg in order.slice(0, 2):
		var i := 0 if leg == "right leg" else 1
		var lg: Dictionary = gw.legs[i]
		var knee: Vector2 = lg.knee
		var ankle: Vector2 = lg.ankle
		var far: bool = leg.begins_with(far_side)
		var c := iron.darkened(0.3 if far else 0.0)
		FkPaint.seg(ci, hip, knee, 13.0, 11.0, c)
		ci.draw_circle(knee, 5.0, brass.darkened(0.2 if far else 0.0))
		FkPaint.seg(ci, knee, ankle, 11.0, 10.0, c)
		FkPaint.shade_poly(ci, (lg.foot as Array).map(func(v: Vector2) -> Vector2: return ankle + v), c.darkened(0.15))
		if lg.u >= 0.0:
			contacts.append([ankle + Vector2(1.5, lg.low + 1.0), lg.u])
	# A hunched, heavy torso rocking over the supporting leg.
	FkPaint.push(ci, Transform2D(sin(walk) * 0.06 * mv + 0.08, hip) * Transform2D(0.0, -hip))
	var drag := sin(walk - 0.9) * 0.35 * mv
	var parts := {}
	# Left arm: a heavy pendulum lagging behind the stride — upper arm, forearm and an iron fist.
	parts["left arm"] = func() -> void:
		var c := iron.darkened(0.3 if far_side == "left" else 0.0)
		var sh := hip + Vector2(-8, -30)
		# Hung a little back from the barrel so it reads beside the body, swinging wide with the stride.
		var elbow := sh + Vector2(-5, 17).rotated(drag * 1.5 + 0.25)
		var hand := elbow + Vector2(-2, 16).rotated(drag * 1.8 + 0.3)
		FkPaint.seg(ci, sh, elbow, 10.0, 9.0, c)
		ci.draw_circle(elbow, 4.0, brass.darkened(0.2 if far_side == "left" else 0.0))
		FkPaint.seg(ci, elbow, hand, 9.0, 8.0, c)
		FkPaint.shade_poly(ci, FkPaint.ellipse_pts(hand + Vector2(0, 3), Vector2(6, 5)), c.darkened(0.15))
	# Barrel body with a furnace, head and chimney.
	parts["body"] = func() -> void:
		var body := [hip + Vector2(-20, 2), hip + Vector2(18, 2), hip + Vector2(22, -24), hip + Vector2(14, -40), hip + Vector2(-16, -40), hip + Vector2(-22, -22)]
		FkPaint.shade_poly(ci, body, iron)
		ci.draw_line(hip + Vector2(-21, -14), hip + Vector2(20, -14), brass, 3.0)
		ci.draw_line(hip + Vector2(-19, -34), hip + Vector2(17, -34), brass, 3.0)
		FkPaint.rivets(ci, hip + Vector2(-19, -14), hip + Vector2(19, -14), 7, brass.lightened(0.35), 1.1)
		ci.draw_rect(Rect2(hip + Vector2(0, -30), Vector2(12, 12)), Color(0.12, 0.1, 0.1))
		ci.draw_rect(Rect2(hip + Vector2(1.5, -28.5), Vector2(9, 9)), Color(1.0, 0.55, 0.2, 0.75 + 0.25 * sin(t * 8.0)))
		for k in 3:
			ci.draw_line(hip + Vector2(1.5, -26 + k * 3), hip + Vector2(10.5, -26 + k * 3), Color(0.15, 0.1, 0.08), 1.0)
		FkPaint.poly(ci, [hip + Vector2(-18, -10), hip + Vector2(-4, -10), hip + Vector2(-4, -2), hip + Vector2(-18, -2)], tm)
		# Head: a small domed helm with a rune visor.
		var head := hip + Vector2(4, -46)
		FkPaint.shade_poly(ci, FkPaint.ellipse_pts(head, Vector2(9, 7.5)), brass)
		ci.draw_line(head + Vector2(0, 0), head + Vector2(9, 0), Color(g, 0.95), 2.4)
		# Chimney pipes puffing.
		ci.draw_rect(Rect2(hip + Vector2(-18, -52), Vector2(5, 14)), iron.darkened(0.25))
		var u := fmod(t * 0.9, 1.0)
		ci.draw_circle(hip + Vector2(-16 - u * 10, -54 - u * 20), 3.0 + u * 6.0, Color(0.85, 0.85, 0.82, 0.4 * (1.0 - u)))
	# Right arm: a piston swing into a hammer fist.
	parts["right arm"] = func() -> void:
		var shade := 0.3 if far_side == "right" else 0.0
		var theta := 0.3 - drag
		if atk >= 0.0:
			theta = lerpf(0.3, 2.4, ease(atk / 0.35, 0.6)) if atk < 0.35 else (lerpf(2.4, 0.9, ease((atk - 0.35) / 0.15, 0.4)) if atk < 0.5 else lerpf(0.9, 0.3, (atk - 0.5) / 0.5))
		var shp := hip + Vector2(10, -32)
		var elbow := shp + Vector2(0, 16).rotated(-theta)
		var fist := elbow + Vector2(0, 14).rotated(-theta * 0.7 - 0.5)
		ci.draw_circle(shp, 7.0, brass.darkened(shade))
		FkPaint.seg(ci, shp, elbow, 10.0, 9.0, iron.darkened(shade))
		FkPaint.seg(ci, elbow, fist, 9.0, 8.0, iron.lightened(0.05).darkened(shade))
		var orth := (fist - elbow).normalized().orthogonal()
		var fd := (fist - elbow).normalized()
		FkPaint.shade_poly(ci, [fist - orth * 9 - fd * 3, fist + orth * 9 - fd * 3, fist + orth * 9 + fd * 8, fist - orth * 9 + fd * 8], iron.darkened(0.2 + shade))
		ci.draw_line(fist - orth * 7 + fd * 2.5, fist + orth * 7 + fd * 2.5, Color(g, 0.7), 1.6)
	for name in order.slice(2):
		(parts[name] as Callable).call()
	FkPaint.pop(ci)
	for c in contacts:
		_giant_contact(ci, c[0], c[1])


## Treant: a walking tree — root feet, bark body, branch arms and a leafy crown.
static func treant(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var team: Color = st.team
	var mv := FkPaint.move_amount(pose)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var bark := FkPaint.tint(Color("6a5038"), pose)
	var leaf := FkPaint.tint(Color("4f7f3c"), pose)
	var tm := FkPaint.tint(team, pose)
	var g: Color = st.look.glow
	var gw := _giant_walk("treant", walk, mv, -38.0 + (1.0 - sin(t * 1.1 + seed)) * 0.4)
	var hip: Vector2 = gw.hip
	var order := giant_order(pose)
	# The side turned away from us is shaded darker.
	var far_side := "left" if order[0] == "left leg" else "right"
	FkPaint.shadow(ci, 30)
	var contacts := []
	for leg in order.slice(0, 2):
		var i := 0 if leg == "right leg" else 1
		var lg: Dictionary = gw.legs[i]
		var knee: Vector2 = lg.knee
		var foot: Vector2 = lg.ankle
		var c := bark.darkened(0.3 if leg.begins_with(far_side) else 0.0)
		FkPaint.seg(ci, hip, knee, 14.0, 11.0, c)
		FkPaint.seg(ci, knee, foot, 11.0, 9.0, c)
		# Roots spread and pitch with the foot, and splay flat as the weight crushes down on the landing foot.
		for r: Vector2 in lg.foot:
			ci.draw_line(foot, foot + r, c.darkened(0.1), 3.0)
		if lg.u >= 0.0:
			contacts.append([foot + Vector2(0, lg.low), lg.u])
	# A hunched, heavy trunk rocking over the supporting leg.
	FkPaint.push(ci, Transform2D(sin(walk) * 0.06 * mv + 0.07, hip) * Transform2D(0.0, -hip))
	var sway := sin(t * 1.4 + seed) * 0.08
	var drag := sin(walk - 0.9) * 0.35 * mv
	var parts := {}
	# Left branch arm: a heavy pendulum lagging behind the stride, ending in a twig hand.
	parts["left arm"] = func() -> void:
		var c := bark.darkened(0.3 if far_side == "left" else 0.0)
		var sh := hip + Vector2(-8, -38)
		var elbow := sh + Vector2(-7, 15).rotated(drag * 1.4 + 0.1)
		var hand := elbow + Vector2(-3, 14).rotated(drag * 1.7)
		FkPaint.seg(ci, sh, elbow, 8.0, 6.5, c)
		FkPaint.seg(ci, elbow, hand, 6.5, 5.0, c)
		for k in 3:
			ci.draw_line(hand, hand + (hand - elbow).normalized().rotated(-0.6 + k * 0.6) * 7.0, c.darkened(0.1), 2.2)
	# Trunk with bark grooves, a knot face with glowing eyes, a team sash of woven vines, a leafy crown.
	parts["body"] = func() -> void:
		var trunk := [hip + Vector2(-15, 4), hip + Vector2(15, 4), hip + Vector2(13, -30), hip + Vector2(10, -52), hip + Vector2(-10, -54), hip + Vector2(-14, -30)]
		FkPaint.shade_poly(ci, trunk, bark)
		for k in 4:
			ci.draw_polyline(PackedVector2Array([hip + Vector2(-10 + k * 6, 2), hip + Vector2(-8 + k * 6 + sin(k) * 2, -24), hip + Vector2(-9 + k * 6, -48)]), bark.darkened(0.3), 1.4)
		FkPaint.ellipse(ci, hip + Vector2(4, -40), Vector2(7, 5), bark.darkened(0.35))
		for e in [Vector2(1, -41), Vector2(8, -41)]:
			FkPaint.halo(ci, hip + e, 3.0, g, 0.8)
			ci.draw_circle(hip + e, 1.2, Color(1, 1, 1, 0.9))
		ci.draw_line(hip + Vector2(-15, -14), hip + Vector2(15, -20), tm, 4.0)
		var crown := hip + Vector2(0, -62)
		for k in 9:
			var a := TAU * k / 9.0 + sway
			var p := crown + Vector2(cos(a) * 17, sin(a) * 11)
			FkPaint.shade_poly(ci, FkPaint.ellipse_pts(p, Vector2(10, 8), a, 10), leaf.darkened(0.12 * (k % 3)))
		FkPaint.shade_poly(ci, FkPaint.ellipse_pts(crown + Vector2(2, -2), Vector2(14, 10), 0.0, 12), leaf.lightened(0.06))
		for k in 5:
			ci.draw_circle(crown + Vector2(-12 + k * 6, -8 + sin(k * 2.1) * 6), 1.6, Color(g, 0.7))
	# Right branch arm: a heavy overhead slam.
	parts["right arm"] = func() -> void:
		var shade := 0.3 if far_side == "right" else 0.0
		var theta := 0.35 - drag
		if atk >= 0.0:
			theta = lerpf(0.35, 2.5, ease(atk / 0.35, 0.6)) if atk < 0.35 else (lerpf(2.5, 0.8, ease((atk - 0.35) / 0.15, 0.4)) if atk < 0.5 else lerpf(0.8, 0.35, (atk - 0.5) / 0.5))
		var shp := hip + Vector2(8, -40)
		var elbow := shp + Vector2(0, 18).rotated(-theta)
		var hand := elbow + Vector2(0, 16).rotated(-theta * 0.8 - 0.4)
		FkPaint.seg(ci, shp, elbow, 10.0, 8.0, bark.darkened(shade))
		FkPaint.seg(ci, elbow, hand, 8.0, 6.0, bark.lightened(0.05).darkened(shade))
		for k in 3:
			ci.draw_line(hand, hand + (hand - elbow).normalized().rotated(-0.6 + k * 0.6) * 9.0, bark.darkened(0.1 + shade), 2.6)
		FkPaint.ellipse(ci, elbow + Vector2(-2, -4), Vector2(5, 3), leaf.darkened(shade), 0.6)
	for name in order.slice(2):
		(parts[name] as Callable).call()
	FkPaint.pop(ci)
	for c in contacts:
		_giant_contact(ci, c[0], c[1])


## Time since a giant's foot landed, as 0..1 over the moment after contact (stride phase PI/2), else −1.
static func giant_contact(ph: float) -> float:
	var d := wrapf(ph - PI / 2, 0.0, TAU)
	return d / 1.2 if d < 1.2 else -1.0


## The earth-shaker's footfall, u = 0..1 after landing: shockwave arcs rolling out along the ground,
## cracks in the stone, dust plumes and speed lines kicking upward around the planted foot.
static func _giant_contact(ci: CanvasItem, p: Vector2, u: float) -> void:
	var a := 1.0 - u
	for k in 2:
		var r := (10.0 + u * 34.0) * (1.0 + k * 0.45)
		var pts := PackedVector2Array()
		for s in 13:
			var ang := PI + PI * s / 12.0
			pts.append(p + Vector2(cos(ang) * r, sin(ang) * r * 0.28))
		ci.draw_polyline(pts, Color(0.95, 0.9, 0.8, 0.55 * a / (1.0 + k)), 2.0)
	for k in 4:
		var side := -1.0 if k < 2 else 1.0
		var l := (8.0 + k * 3.0) * minf(1.0, u * 4.0)
		ci.draw_polyline(PackedVector2Array([p, p + Vector2(side * l * 0.5, (k % 2) * 1.5 - 0.5), p + Vector2(side * l, 1.0)]),
			Color(0.18, 0.14, 0.1, 0.8 * a), 1.2)
	for k in 4:
		ci.draw_circle(p + Vector2(-12 + k * 8, -u * (10.0 + k * 4.0)), 3.0 + u * 7.0, Color(0.72, 0.64, 0.5, 0.35 * a))
	for k in 3:
		var x := -9.0 + k * 9.0
		ci.draw_line(p + Vector2(x, -4.0 - u * 6.0), p + Vector2(x * 1.2, -14.0 - u * 16.0), Color(1, 1, 1, 0.5 * a), 1.2)


## Sky Cannon: a long brass barrel on a gilded carriage, ringed with floating arcane circles.
static func skycannon(ci: CanvasItem, st: Dictionary, pose: Dictionary, _seed: int) -> void:
	var team: Color = st.team
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var roll: float = pose.get("walk", 0.0)
	var brass := FkPaint.tint(Color("c9a45c"), pose)
	var dark := FkPaint.tint(Color("3a3448"), pose)
	var tm := FkPaint.tint(team, pose)
	var g: Color = st.look.glow
	var charge := clampf(atk / 0.35, 0.0, 1.0) if atk >= 0.0 and atk < 0.35 else 0.0
	var kick := maxf(0.0, FkUnits.swing(atk)) * 5.0
	FkPaint.shadow(ci, 42)
	FkPaint.shade_poly(ci, [Vector2(-40, -6), Vector2(36, -6), Vector2(42, -18), Vector2(-42, -20)], dark)
	FkPaint.shade_poly(ci, [Vector2(-30, -18), Vector2(22, -18), Vector2(16, -32), Vector2(-26, -32)], brass.darkened(0.2))
	ci.draw_rect(Rect2(Vector2(-24, -29), Vector2(16, 8)), tm)
	var dirv := Vector2(1, -0.42).normalized()
	var b0 := Vector2(-12, -38) - dirv * kick
	var b1 := b0 + dirv * 72
	var n := dirv.orthogonal()
	FkPaint.shade_poly(ci, [b0 - n * 7, b1 - n * 4, b1 + n * 4, b0 + n * 7], brass)
	ci.draw_line(b0 + dirv * 6, b1, brass.darkened(0.35), 1.2)
	for i in 3:
		var c := b0 + dirv * (22 + i * 16)
		var r := 9.0 - i * 1.2 + charge * 2.0
		var spin := t * (1.5 + i * 0.4) + i
		ci.draw_arc(c, r, spin, spin + TAU * 0.8, 16, Color(g, 0.55 + 0.3 * sin(t * 4.0 + i) + charge * 0.3), 1.6)
	FkPaint.halo(ci, b1, 5.0 + charge * 5.0, g, 0.6 + charge * 0.4)
	for x in [-26.0, 22.0]:
		FkPaint.wheel(ci, Vector2(x, -9), 10, roll, dark, brass, 8)


## Starfall Obelisk: a crystal spire hovering over a runner-sled, pushed by an elven crew.
static func obelisk(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int) -> void:
	var team: Color = st.team
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var wood := FkPaint.tint(Color("b89a6a"), pose)
	var stone := FkPaint.tint(Color("d8dce8"), pose)
	var tm := FkPaint.tint(team, pose)
	var g: Color = st.look.glow
	var charge := clampf(atk / 0.35, 0.0, 1.0) if atk >= 0.0 and atk < 0.35 else 0.0
	FkPaint.shadow(ci, 38)
	FkFigure.crew(ci, st, pose, seed, Vector2(-40, 0))
	# Sled with curled runners and a carved plinth.
	ci.draw_polyline(PackedVector2Array([Vector2(-32, -3), Vector2(28, -3), Vector2(36, -8), Vector2(34, -13)]), wood.darkened(0.3), 3.0)
	FkPaint.shade_poly(ci, [Vector2(-26, -6), Vector2(22, -6), Vector2(18, -18), Vector2(-22, -18)], wood)
	FkPaint.shade_poly(ci, [Vector2(-14, -18), Vector2(10, -18), Vector2(6, -26), Vector2(-10, -26)], stone.darkened(0.2))
	ci.draw_rect(Rect2(Vector2(-18, -14), Vector2(12, 6)), tm)
	# The crystal hovers and bobs; motes orbit it.
	var hover := sin(t * 1.8 + seed) * 3.0
	var base := Vector2(-2, -34 + hover)
	var crystal := [base + Vector2(-7, 0), base + Vector2(7, 0), base + Vector2(5, -40), base + Vector2(0, -52), base + Vector2(-5, -40)]
	FkPaint.halo(ci, base + Vector2(0, -26), 20.0 + charge * 10.0, g, 0.35 + charge * 0.5)
	FkPaint.shade_poly(ci, crystal, stone.lerp(g, 0.35 + charge * 0.4))
	ci.draw_line(base + Vector2(0, -2), base + Vector2(0, -50), Color(1, 1, 1, 0.55), 1.4)
	for k in 4:
		var a := t * 1.6 + TAU * k / 4.0
		ci.draw_circle(base + Vector2(cos(a) * 16, -26 + sin(a) * 6), 1.8, Color(g, 0.85))
	FkPaint.halo(ci, base + Vector2(0, 4), 6.0, g, 0.5)
