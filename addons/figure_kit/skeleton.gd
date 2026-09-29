class_name FkSkeleton
extends RefCounted
## Joint math for the human figure: fixed bone lengths, two-bone IK, stance keyframes for attacks and
## gaits (walk styles with their carry poses). Local space: feet at y = 0, facing +x, up is −y.
## Lengths are multiplied by the figure's build.

const THIGH := 15.0
const SHIN := 14.0
const UPPER := 9.0
const FORE := 8.5
## Hip to shoulder line.
const SPINE := 20.0
## Standing hip height: a little under THIGH + SHIN so knees are soft.
const HIP_Y := 28.0
## Boot outline around the ankle (× build): heel, instep, toe, sole. solve() keeps its lowest point on the ground.
const BOOT := [Vector2(-3.2, -6), Vector2(3, -6), Vector2(4.5, -2), Vector2(8.5, -0.5), Vector2(8.5, 1.5), Vector2(-3.5, 1.5)]
## Half the body's width at shoulders and hips (× build × body.x): the near side stands this far toward
## the viewer in depth (z), the far side this far away.
const HALF_W := 4.0
## Ball of the foot in the boot's space (× build): the toe joint, where the boot bends.
const BALL := Vector2(4.5, 1.5)
## Bend rules. An elbow always folds to the same side of its shoulder→hand line (below a forward
## reach, in front of an overhead one, behind a hanging one) and a knee to the other, so a limb can
## never snap across to its mirror solution between frames.
const ELBOW := 1.0
const KNEE := -1.0


## Middle joint (knee, elbow) of a two-bone limb from `root` to `target`, bent to `bend`'s side
## (ELBOW or KNEE). Call with a reachable target (see reach()).
static func ik(root: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	# (bend 0 = on the line: only for a fully extended limb, where both solutions meet.)
	var v := target - root
	var d := clampf(v.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var dir := v.normalized() if v.length() > 1e-4 else Vector2.DOWN
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	return root + dir.rotated(a * signf(bend)) * l1


## Where the limb's end actually gets to: `target` if reachable, else full extension toward it.
static func reach(root: Vector2, target: Vector2, l1: float, l2: float) -> Vector2:
	var v := target - root
	var m := l1 + l2 - 0.01
	return target if v.length() <= m else root + v.normalized() * m


## Weapon kind → stance family.
const FAMILY := {
	"club": "blade", "sword": "blade", "saber": "blade", "gladius": "blade", "leafblade": "blade",
	"spellsword": "blade", "baton": "blade", "shovel": "blade",
	"axe": "chop", "hammer": "chop", "rune_hammer": "chop",
	"spear": "thrust", "lance": "thrust", "halberd": "pole", "glaive": "pole",
	"musket": "aim", "rifle": "aim", "arcane_rifle": "aim", "rune_rifle": "aim", "crossbow": "aim",
	"bow": "bow", "starbow": "bow", "javelin": "throw", "throwing_axe": "throw", "sling": "sling",
	"staff": "staff", "crew": "crew",
}

## Keyframes guard / wind / hit, relative to the shoulder line `sh`, in px × build. Channels:
##   h  near-hand target        f   far-hand target (absent = hangs and counter-swings)
##   a  weapon angle (rad; 0 = forward, −PI/2 = up) — a fast change against the forearm is a wrist snap
##   s / sf  near / far shoulder offset     lock  wrist locked (0..1): the weapon continues the forearm
##   lean  torso lean (rad, + forward)      lunge  body shift forward (px)
##   crouch  hip drop (px)                  step  passing step (0..1: the back foot swings through to the front)
##   wide  extra stance width (px)          zoom  weapon scale (foreshortening as it swings toward the viewer)
##   rise  a rider standing up in the stirrups (px)
##   el  near-elbow position, steered directly: an arm swinging toward the viewer, drawn foreshortened
##   bend  which way the near elbow folds (+1 the ordinary way, −1 up-and-behind as in a bow draw); the
##         arm straightens through a change of sign, so the elbow crosses over without snapping
##   rim  shield top-rim position (the far hand then grips the shield below it, by the shield's size)
##   turn  how open the shield face is to the camera (its drawn width, 0..1; 0.5 = braced toward the enemy)
## path: "line" (the near hand travels straight between keys) or "arc" (around the shoulder, overhead chops).
const STANCES := {
	"idle": {"guard": {"h": Vector2(3, 16)}, "wind": {"h": Vector2(3, 16)}, "hit": {"h": Vector2(3, 16)}},
	# One-handed blade: chambered high beside the ear (arm bent), blade back; a passing step and a steep
	# cut that sweeps the arm out to full, straight extension at shoulder height, the wrist snapping the
	# blade level; off hand at the chest, checking to the ribs.
	"blade": {"path": "arc",
		"guard": {"h": Vector2(13, 3), "a": -0.5, "f": Vector2(4, 6), "crouch": 1.0, "lean": 0.03},
		"wind": {"h": Vector2(-2, -10), "a": -2.3, "f": Vector2(3, 6), "s": Vector2(-1, -2),
			"crouch": 2.5, "lean": -0.05, "lunge": -1.0},
		"hit": {"h": Vector2(22, 5), "a": 0.02, "f": Vector2(-1, 8), "s": Vector2(2, 1), "crouch": 3.0, "lean": 0.18,
			"lunge": 7.0, "step": 1.0}},
	# Sword or hand axe with a shield: coil — deep wide crouch, weapon raised high and pulled back above
	# the helmet, blade pointing back; cleave — a 45° line of action, the weapon sweeping a crescent over
	# the shield's rim, foreshortened larger as it comes down; lockout — arm straight, wrist locked with
	# the forearm, stopping rigid at chest-to-waist height.
	"shield": {"path": "arc",
		"guard": {"h": Vector2(0, -12), "a": -2.2, "rim": Vector2(10, -9.5), "s": Vector2(-0.5, -1), "crouch": 3.5,
			"wide": 10.0, "lean": 0.06},
		"wind": {"h": Vector2(-7, -15), "a": -2.7, "rim": Vector2(10, -9.5), "s": Vector2(-1.5, -2),
			"crouch": 5.0, "wide": 12.0, "lean": -0.05, "lunge": -1.0},
		"hit": {"h": Vector2(20, 10), "a": 0.49, "rim": Vector2(11, -9.5), "s": Vector2(3, 1), "crouch": 5.5,
			"wide": 14.0, "lean": 0.35, "lunge": 8.0, "zoom": 1.12, "lock": 1.0, "turn": 0.8}},
	"chop": {"path": "arc",
		"guard": {"h": Vector2(14, 5), "a": -0.33},
		"wind": {"h": Vector2(3.6, -14.5), "a": -2.03, "lean": -0.08, "lunge": -1.5},
		"hit": {"h": Vector2(13, 9), "a": 0.1, "lean": 0.2, "lunge": 6.0}},
	"thrust": {"two": true,
		"guard": {"h": Vector2(12, 9), "a": -0.12},
		"wind": {"h": Vector2(0, 9), "a": -0.12, "lean": -0.06, "lunge": -2.0},
		"hit": {"h": Vector2(22, 8), "a": -0.12, "lean": 0.18, "lunge": 7.0}},
	"pole": {"two": true,
		"guard": {"h": Vector2(10, 8), "a": -PI / 2},
		"wind": {"h": Vector2(0, 9), "a": -0.12, "lean": -0.06, "lunge": -2.0},
		"hit": {"h": Vector2(22, 8), "a": -0.12, "lean": 0.18, "lunge": 7.0}},
	# Marksman: aggressive forward lean, soft knees, the butt of the stock seated in the shoulder pocket
	# (the shoulder lifts to meet it), trigger hand just ahead of it, the support hand out on the forend
	# with its elbow tucked under (that shoulder rolls forward); the shot kicks straight back through the
	# shoulder and settles back onto the aim.
	"aim": {
		"guard": {"h": Vector2(7.5, -1), "f": Vector2(17, -2.5), "s": Vector2(-1, -3), "sf": Vector2(4, -1), "a": -0.03,
			"lean": 0.1, "crouch": 2.0},
		"wind": {"h": Vector2(7.5, -1), "f": Vector2(17, -2.5), "s": Vector2(-1, -3), "sf": Vector2(4, -1), "a": -0.03,
			"lean": 0.1, "crouch": 2.0},
		"hit": {"h": Vector2(5.5, -1), "f": Vector2(15, -2.5), "s": Vector2(-3, -3), "sf": Vector2(2, -1), "a": -0.04,
			"lean": 0.04, "crouch": 2.0}},
	# Archer, side-on (owner brief): the bow arm a rigid strut toward the target with its shoulder locked
	# down. A heavy draw (owner: "the pull lacks weight"): the drawing shoulder retracts hard and the hand
	# anchors at the back of the jaw. The drawing elbow swings back around the side — in profile it travels straight back at
	# shoulder height, the upper arm foreshortening as it points at the viewer mid-draw (`el` steers it),
	# never rising over the shoulder. Pre-draw: hand hooked on the string, elbow out in front. Full draw:
	# shoulder blade retracted, elbow straight back level with the shoulder, forearm along the arrow, hand
	# anchored under the back of the jawline (arrow under the eye). Release: the elbow snaps back and the
	# hand glides back along the neck while the bow arm stays locked.
	"bow": {
		"guard": {"h": Vector2(15, -3), "el": Vector2(9, -1), "f": Vector2(18, -4), "sf": Vector2(0, 1), "a": 0.0},
		"wind": {"h": Vector2(-2.5, -5), "el": Vector2(-11.5, -2.5), "f": Vector2(18, -4), "sf": Vector2(0, 1), "s": Vector2(-3.5, -3),
			"a": 0.0, "lean": -0.05},
		"hit": {"h": Vector2(-6, -5), "el": Vector2(-12.5, -1.5), "f": Vector2(18, -4), "sf": Vector2(0, 1),
			"s": Vector2(-4.5, -3), "a": 0.0, "lean": -0.05}},
	# Javelin: torso turned away, lead arm fully extended forward, throwing arm straight back behind the
	# shoulder with the elbow high, weight on the bent back leg; then the arm whips over and forward at
	# head height, finishing fully extended (shoulder, elbow and hand in one straight line), as the weight
	# moves onto the front leg and the lead arm tucks.
	"throw": {"path": "arc",
		"guard": {"h": Vector2(4, -9), "a": -0.23, "f": Vector2(6, 8)},
		"wind": {"h": Vector2(-12, -4), "a": -0.3, "f": Vector2(17, -2), "lean": -0.12, "lunge": -3.0, "crouch": 3.0},
		"hit": {"h": Vector2(20, -3), "a": -0.1, "f": Vector2(3, 7), "lean": 0.22, "lunge": 6.0, "crouch": 1.5}},
	# Slinger: two-handed aim (pouch held forward, dominant hand back by the ear), an overhead whip with
	# the lead arm pointing downrange, then the snap forward at peak height as the lead arm tucks to the
	# ribs and the weight shifts from the back leg to the front.
	"sling": {"path": "arc",
		"guard": {"h": Vector2(-1, -9), "f": Vector2(15, -1)},
		"wind": {"h": Vector2(2, -16), "f": Vector2(16, -1), "lunge": -2.0},
		"hit": {"h": Vector2(15, -12), "f": Vector2(-1, 8), "lean": 0.15, "lunge": 6.0}},
	# Staff (owner brief): held in both hands at guard; the strike raises it confidently in one hand, the
	# arm straight from shoulder to hand at about 30 degrees up and forward, the staff upright; the other
	# hand lets go and settles by the hip.
	"staff": {
		"guard": {"h": Vector2(10, 6), "f": Vector2(9, 13), "a": -1.456},
		"wind": {"h": Vector2(8, 6), "f": Vector2(7, 13), "a": -1.5},
		"hit": {"h": Vector2(19, -9), "f": Vector2(2, 17), "a": -1.25, "lean": 0.12, "lunge": 3.0}},
	"crew": {"guard": {"h": Vector2(14, 8), "f": Vector2(12, 9)}, "wind": {"h": Vector2(14, 8), "f": Vector2(12, 9)},
		"hit": {"h": Vector2(15, 8), "f": Vector2(13, 9), "lean": 0.1}},
	# Mounted sabre: seated deep, reins low over the withers in the off hand, the hilt resting at the
	# thigh; the strike rises into a half-seat (heels deep, leaning with the stride) and the arm extends
	# down and forward along the mount's flank, wrist locked, in an angled draw-cut.
	"ride_blade": {"path": "arc",
		"guard": {"h": Vector2(6, 14), "a": -1.9, "f": Vector2(8, 16)},
		"wind": {"h": Vector2(-4, -13), "a": -2.6, "f": Vector2(8, 16), "s": Vector2(-1, -2), "lean": 0.1, "rise": 3.0},
		"hit": {"h": Vector2(17, 13), "a": 0.7, "f": Vector2(8, 16), "s": Vector2(2, 1), "lean": 0.3, "rise": 4.0,
			"lock": 1.0, "zoom": 1.1}},
	# Mounted lance: carried upright at the walk, couched under the arm, then driven into the charge at the
	# opponent's chest with the arm locked straight (owner: full range of motion on the thrust).
	"ride_thrust": {
		"guard": {"h": Vector2(6, 10), "a": -1.35, "f": Vector2(8, 16)},
		"wind": {"h": Vector2(1, 9), "a": 0.1, "f": Vector2(8, 16), "lean": 0.05, "rise": 2.0},
		"hit": {"h": Vector2(24, 11), "a": 0.4, "f": Vector2(8, 16), "lean": 0.25, "rise": 3.0}},
}

## Walk styles. bob = hip drop at each contact (px); stride = foot reach (px); lift = knee lift (px);
## heel / toe = foot roll at landing / push-off (rad; a negative heel lands on the ball of the foot);
## swing = free-arm swing (rad); dust = puffs at heel contact; twist = pelvis yaw at full stride (rad), the
## chest turning against it at 0.8. `carry` is the pose (stance channels)
## the unit blends into as it walks; "free" lets the off hand swing even if the stance holds it.
const GAITS := {
	"default": {"bob": 2.2, "stride": 13.0, "lift": 4.5, "heel": 0.35, "toe": 0.5, "swing": 0.5, "twist": 0.35},
	# Spear skirmisher: low stealthy glide, torso canted 15°, spear gripped at the hip angled up 30°.
	"glide": {"bob": 0.6, "stride": 13.0, "lift": 3.5, "heel": 0.35, "toe": 0.5, "swing": 0.55, "twist": 0.25,
		"carry": {"h": Vector2(6, 17), "a": -0.52, "lean": 0.26, "crouch": 3.0, "free": true}},
	# Axe thrower: heavy heel strikes with dust, upright broad chest, hunched shoulders, axe low at the
	# hip with the blade down, short tight arm swing, a distinct bob.
	"heavy": {"bob": 3.0, "stride": 12.0, "lift": 4.0, "heel": 0.45, "toe": 0.45, "swing": 0.3, "dust": true, "twist": 0.25,
		"carry": {"h": Vector2(5, 18), "a": 1.25, "s": Vector2(1, 0.6), "lean": 0.0, "free": true}},
	# Slinger: light bouncy scout walk on the balls of the feet, high knee lift, sling draped between
	# both hands at chest level.
	"bounce": {"bob": 3.2, "stride": 11.0, "lift": 8.0, "heel": -0.25, "toe": 0.45, "swing": 0.4, "twist": 0.35,
		"carry": {"h": Vector2(8, 6), "f": Vector2(4, 8), "lean": 0.0}},
	# Archer: level grouse glide — soft knees, hips and head level. Bow arm low and relaxed (shoulder
	# pressed down, elbow soft) holding the bow vertically at the flank, a little forward of the legs;
	# the drawing arm dropped, elbow ~100°, a relaxed hook swinging by the hip with the counter-stride.
	"track": {"bob": 0.0, "stride": 12.0, "lift": 3.0, "heel": 0.3, "toe": 0.4, "swing": 0.25, "hswing": 4.0, "twist": 0.1,
		"carry": {"h": Vector2(4, 15), "f": Vector2(7, 14), "s": Vector2(0, 1.5), "sf": Vector2(0, 1.5),
			"lean": 0.08, "crouch": 3.5, "bend": 1.0}},
	# Rifleman: patrol low-ready — hips low, torso 10° forward, firing hand at the waist, support hand
	# under the forend, barrel 45° down ahead of the lead knee, locked steady while the legs step.
	"patrol": {"bob": 0.5, "stride": 11.0, "lift": 3.0, "heel": 0.3, "toe": 0.4, "swing": 0.0, "twist": 0.1,
		"carry": {"h": Vector2(4, 12), "f": Vector2(10, 13), "s": Vector2.ZERO, "sf": Vector2.ZERO, "a": 0.785, "lean": 0.17,
			"crouch": 2.5}},
	# Shield wall: low guarded advance in measured wide steps, shield fixed across the chest (eyes over
	# the rim), weapon held ready up-and-forward at chest height with the shoulder and elbow relaxed
	# (clear of the face), minimal bob.
	"wall": {"bob": 0.4, "stride": 9.0, "lift": 2.0, "heel": 0.2, "toe": 0.3, "swing": 0.0, "twist": 0.1,
		"carry": {"h": Vector2(9, 8), "a": -0.9, "s": Vector2(0, 1), "rim": Vector2(10, -9.5), "lean": 0.08, "crouch": 4.0,
			"wide": 8.0}},
}

## Far-hand shield grip (relative to sh) for shield bearers: holds the shield in front of the chest.
const SHIELD_GRIP := Vector2(6, 11)

const _FLOATS := {"a": 0.0, "lean": 0.0, "lunge": 0.0, "crouch": 0.0, "step": 0.0, "wide": 0.0, "zoom": 1.0, "lock": 0.0, "rise": 0.0, "bend": 1.0, "turn": 0.5}
const _VECTORS := {"s": Vector2.ZERO, "sf": Vector2.ZERO}


## Walk style for a figure: shield bearers advance as a wall; otherwise by what they carry.
static func gait_for(weapon: String, shield: String) -> String:
	var family: String = FAMILY.get(weapon, "idle")
	if shield != "":
		return "wall"
	if weapon == "throwing_axe" or family == "chop":
		return "heavy"
	if family in ["thrust", "pole"] or weapon == "javelin":
		return "glide"
	return {"sling": "bounce", "bow": "track", "aim": "patrol"}.get(family, "default")


## One frame's keyframe values, on FkUnits.swing's beats: guard → wind (anticipation, 0–0.35),
## wind → hit (strike, 0.35–0.55; contact), hit → guard (recovery). Not attacking (atk < 0), the guard
## blends into the gait's carry pose as the figure walks (mv 0..1).
static func key(family: String, atk: float, carry := {}, mv := 0.0) -> Dictionary:
	var st: Dictionary = STANCES.get(family, STANCES.idle)
	var a: Dictionary = st.guard
	var z: Dictionary = st.guard
	var k := 0.0
	var path: String = st.get("path", "line")
	if atk >= 0.0 and atk < 0.35:
		z = st.wind
		k = ease(atk / 0.35, 0.6)
	elif atk >= 0.35 and atk < 0.55:
		a = st.wind
		z = st.hit
		k = ease((atk - 0.35) / 0.2, 0.4)
	elif atk >= 0.55:
		a = st.hit
		k = ease((atk - 0.55) / 0.45, 1.6)
	elif not carry.is_empty():
		z = st.guard.merged(carry, true)
		if not carry.has("el"):
			z.erase("el")
		k = mv
		path = "line"
	var free: bool = z.get("free", false) and k > 0.5
	var out := {"two": st.get("two", false) and not free, "free": free}
	for c in _FLOATS:
		out[c] = lerpf(a.get(c, _FLOATS[c]), z.get(c, _FLOATS[c]), k)
	for c in _VECTORS:
		out[c] = (a.get(c, _VECTORS[c]) as Vector2).lerp(z.get(c, _VECTORS[c]), k)
	var h0: Vector2 = a.h
	var h1: Vector2 = z.h
	if path == "arc":
		out["h"] = Vector2.from_angle(lerpf(h0.angle(), h1.angle(), k)) * lerpf(h0.length(), h1.length(), k)
	else:
		out["h"] = h0.lerp(h1, k)
	# `el` steers the near elbow directly (blended in by weight, so entering or leaving it never snaps).
	out["el_w"] = lerpf(1.0 if a.has("el") else 0.0, 1.0 if z.has("el") else 0.0, k)
	if a.has("el") or z.has("el"):
		out["el"] = (a.get("el", z.get("el")) as Vector2).lerp(z.get("el", a.get("el")), k)
	for c in ["f", "rim"]:
		if a.has(c) and z.has(c):
			out[c] = (a[c] as Vector2).lerp(z[c], k)
		elif z.has(c) and k > 0.5:
			out[c] = z[c]
		elif a.has(c) and k <= 0.5:
			out[c] = a[c]
	if free:
		out.erase("f")
	# The swinging foot of a passing step lifts mid-way through it.
	out["step_lift"] = sin(k * PI) if a.get("step", 0.0) != z.get("step", 0.0) else 0.0
	return out


## Boot outline points for an ankle at `foot`, rotated by `rot` (rad; − = toes up, + = heel up), the toe
## cap bent back by `toe` at the ball of the foot; `body` gives the race's proportions.
static func boot(foot: Vector2, rot: float, b: float, toe := 0.0, body := Vector2.ONE) -> Array:
	var ball := BALL * body * b
	return BOOT.map(func(p: Vector2) -> Vector2:
		var q := p * body * b
		if p.x > BALL.x:
			q = ball + (q - ball).rotated(-toe)
		return foot + q.rotated(rot))


## Heel-to-toe roll over a stride: `heel` as the foot lands in front (phase PI/2; toes up), `toe` as it
## pushes off behind (3·PI/2; heel up), flat in between.
static func _roll(ph: float, heel: float, toe: float) -> float:
	return -heel * _bell(ph - PI / 2) + toe * _bell(ph - 3 * PI / 2)


## A single bump of width PI/2 centred on d = 0 (one stride is TAU).
static func _bell(d: float) -> float:
	var w := wrapf(d, -PI, PI)
	return cos(2.0 * w) if absf(w) < PI / 4 else 0.0


## All joints for one frame. b = build; pose = {walk, move, atk, t}; shield = the shield kind the far
## hand holds ("" = none); seated = rider (one leg in a stirrup, no walk cycle); look = the race preset:
## its `body` gives legs and spine their height (y) and the figure its width (x), its `head` the head's
## size. Every joint also has a depth in j.z (+ toward the viewer), and every bone keeps its length in 3D.
static func solve(b: float, weapon: String, pose: Dictionary, shield := "", seated := false, look := {}) -> Dictionary:
	var mv: float = pose.get("move", 1.0 if pose.get("moving", false) else 0.0)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var body: Vector2 = look.get("body", Vector2.ONE)
	var hb: float = b * look.get("head", 1.0)
	var by := b * body.y
	var w := HALF_W * b * body.x
	var family: String = FAMILY.get(weapon, "idle")
	if seated:
		family = "ride_blade" if family in ["blade", "chop"] else ("ride_thrust" if family in ["thrust", "pole"] else family)
	elif shield != "" and family in ["blade", "chop"]:
		family = "shield"
	var g: Dictionary = GAITS[gait_for(weapon, shield)]
	var k := key(family, pose.get("atk", -1.0), {} if seated else g.get("carry", {}), mv)
	var bob := lerpf(sin(t * 2.1) * 0.7, absf(sin(walk)) * g.bob, mv)
	var lunge: float = k.lunge * b * (0.0 if seated else 1.0)
	var crouch: float = k.crouch * b * (0.0 if seated else 1.0)
	# On foot the hips stand at the race's leg height; a rider's seat is the saddle's whatever the race.
	var hip := Vector2(lunge * 0.6, (-HIP_Y * b + bob * 0.5 + crouch) * (1.0 if seated else body.y))
	# A rider's feet stay in the stirrups (relative to the saddle) while the hips rise off it; the hips
	# sway with the mount's gait and the spine absorbs its bob so the head stays level.
	var saddle_hip := hip
	if seated:
		hip.y -= k.rise * b
		hip.x += sin(pose.get("ride_walk", 0.0) * 2.0) * 0.8 * pose.get("ride_mv", 0.0) * b
	var sh := hip + Vector2(1.5 * b, -SPINE * by).rotated(k.lean)
	if seated:
		sh.y -= pose.get("ride_bob", 0.0)
	# Pelvis and chest turn against each other about the vertical axis as the figure walks.
	var yaw_p: float = 0.0 if seated else g.get("twist", 0.0) * sin(walk) * mv
	var yaw_c := -0.8 * yaw_p
	var j := {"lean": k.lean, "lunge": lunge, "crouch": k.crouch, "dir": Vector2.from_angle(k.a), "zoom": k.zoom,
		"gait": gait_for(weapon, shield), "w": w, "shield_turn": k.turn}
	# Every joint in rig space (x forward, y down, z toward the viewer). The flat keys the parts are drawn
	# from, and the depths j.z they sort by, are derived from these at the end.
	var p := {"hip": FkRig.at(hip), "sh": FkRig.at(sh), "chest": FkRig.at(hip.lerp(sh, 0.55))}
	# Neck and head: the neck follows half the spine's lean and the head a quarter, so the gaze stays level.
	var tilt: float = k.lean * 0.25
	var neck := sh + Vector2(0.8, -3.5).rotated(k.lean * 0.5) * hb
	var head := neck + Vector2(1.0, -6.0).rotated(tilt) * hb
	j["head_tilt"] = tilt
	p["neck"] = FkRig.at(neck)
	p["head"] = FkRig.at(head)
	p["eye"] = FkRig.at(head + Vector2(3.4, -0.9).rotated(tilt) * hb)
	# Legs: from hip roots either side of the pelvis; feet on the ground line; the gait's stride, lift and
	# heel-to-toe roll while walking, the front foot planted forward on a lunge, the back foot swinging
	# through on a passing step. Each leg lies in the plane of its own hip.
	for i in 2:
		var tag := "n" if i == 0 else "f"
		var side := 1.0 if i == 0 else -1.0
		var root := FkRig.at(hip + Vector2(side * w * sin(yaw_p), 0), side * w * cos(yaw_p))
		var foot: Vector2
		var rot := 0.0
		var flex := 0.0
		var ph := walk + PI * i
		if seated:
			foot = saddle_hip + Vector2(5.0 - 3.0 * i, 16.0) * b * body
			rot = -0.3 - 0.05 * k.rise
		else:
			var fx := lerpf(2.8 if i == 0 else -3.6, g.stride * sin(ph), mv)
			var lift: float = g.lift * maxf(0.0, cos(ph)) * mv
			rot = _roll(ph, g.heel, g.toe) * mv
			fx += k.wide * (0.5 if i == 0 else -0.5)
			if i == 0:
				fx += lunge * 1.6 / b * (1.0 - k.step)
			else:
				fx = lerpf(fx, 2.8 + lunge * 1.6 / b, k.step)
				lift += 4.0 * k.step_lift
				rot -= 0.2 * k.step_lift
			# At push-off the heel lifts while the toe cap stays flat on the ground: the foot bends at the
			# ball, straightening again as it lifts into the swing.
			flex = clampf(maxf(rot, 0.0) * (1.0 - lift / 1.5), 0.0, maxf(rot, 0.0))
			foot = Vector2(fx, -lift) * by
			# Keep the boot's lowest point on (never under) the ground.
			var low := 0.0
			for q in boot(Vector2.ZERO, rot, b, flex, body):
				low = maxf(low, (q as Vector2).y)
			foot.y = minf(foot.y, -low)
		var ankle := FkRig.reach3(root, FkRig.at(foot, root.z), THIGH * by, SHIN * by)
		p["hip_" + tag] = root
		p["knee_" + tag] = FkRig.ik3(root, ankle, THIGH * by, SHIN * by, FkRig.plane_pole(root, ankle, KNEE))
		p["foot_" + tag] = ankle
		p["toe_" + tag] = ankle + FkRig.at((BALL * body * b).rotated(rot))
		j["rot_" + tag] = rot
		j["toe_bend_" + tag] = flex
		j["dust_" + tag] = _bell(ph - PI / 2) * mv if g.get("dust", false) and not seated else 0.0
	# Arms: shoulders ride on the chest (turned by its yaw) and move with the pose; near arm to the
	# stance's hand target; far arm to the shield (by its rim), the stance's far target, the weapon
	# (two-handed), or swinging with the gait. Each arm lies in the plane of its own shoulder.
	var shoulder_n := FkRig.at(sh + Vector2(2, 1) * b * body + (k.s as Vector2) * b + Vector2(w * sin(yaw_c), 0), w * cos(yaw_c))
	var shoulder_f := FkRig.at(sh + Vector2(-3, 1) * b * body + (k.sf as Vector2) * b - Vector2(w * sin(yaw_c), 0), -w * cos(yaw_c))
	var target_n := sh + (k.h as Vector2) * b
	if pose.get("atk", -1.0) < 0.0:
		target_n.x -= sin(walk) * g.get("hswing", 0.0) * mv * b
	var hand_n := FkRig.reach3(shoulder_n, FkRig.at(target_n, shoulder_n.z), UPPER * b, FORE * b)
	var bend: float = k.bend
	if absf(bend) < 1.0:
		# Changing which way the elbow folds: the arm straightens through the change, so it never snaps.
		var v := hand_n - shoulder_n
		hand_n = shoulder_n + v.normalized() * lerpf((UPPER + FORE) * b - 0.01, v.length(), absf(bend))
	j["bend_n"] = 1.0 if bend >= 0.0 else -1.0
	var elbow_n := FkRig.ik3(shoulder_n, hand_n, UPPER * b, FORE * b,
		FkRig.plane_pole(shoulder_n, hand_n, j.bend_n if absf(bend) > 1e-3 else 0.0))
	j["el_w"] = k.el_w
	if k.el_w > 0.0:
		# A steered elbow sits where it shows on screen; its depth keeps both bones their length, so an
		# arm swinging round toward the viewer draws foreshortened.
		var s2 := FkRig.project(shoulder_n)
		var h2 := FkRig.project(hand_n)
		var el := _fit(FkRig.project(elbow_n).lerp(sh + (k.el as Vector2) * b, k.el_w), s2, h2, UPPER * b, FORE * b)
		elbow_n = FkRig.at(el, shoulder_n.z + sqrt(maxf(0.0, pow(UPPER * b, 2) - el.distance_squared_to(s2))))
		hand_n.z = elbow_n.z - sqrt(maxf(0.0, pow(FORE * b, 2) - el.distance_squared_to(h2)))
	var hand_flat := FkRig.project(hand_n)
	if k.lock > 0.0:
		j["dir"] = (j.dir as Vector2).slerp((hand_flat - FkRig.project(elbow_n)).normalized(), k.lock)
	var ft: Vector2
	if k.has("rim") and shield != "":
		ft = sh + ((k.rim as Vector2) + Vector2(0, FkArmour.SHIELD_TOP.get(shield, 10.5))) * b
	elif k.has("f"):
		ft = sh + (k.f as Vector2) * b
	elif shield != "":
		ft = sh + SHIELD_GRIP * b
	elif k.two:
		ft = hand_flat - (j.dir as Vector2) * 8.0 * b
	else:
		ft = FkRig.project(shoulder_f) + Vector2(0, 16.5 * b).rotated(sin(walk) * g.swing * mv - 0.1)
	var hand_f := FkRig.reach3(shoulder_f, FkRig.at(ft, shoulder_f.z), UPPER * b, FORE * b)
	p["sh_n"] = shoulder_n
	p["sh_f"] = shoulder_f
	p["elbow_n"] = elbow_n
	p["hand_n"] = hand_n
	p["elbow_f"] = FkRig.ik3(shoulder_f, hand_f, UPPER * b, FORE * b, FkRig.plane_pole(shoulder_f, hand_f, ELBOW))
	p["hand_f"] = hand_f
	# The one place the flat picture is read off the rig.
	var z := {}
	for joint in p:
		j[joint] = FkRig.project(p[joint])
		z[joint] = FkRig.depth(p[joint])
	j["p3"] = p
	j["z"] = z
	# Attachment points (weapons and shields are still drawn from the hands; these are the hook).
	j["sockets"] = {"grip_n": {"p": j.hand_n, "a": (j.dir as Vector2).angle(), "z": z.hand_n},
		"grip_f": {"p": j.hand_f, "a": ((j.hand_f as Vector2) - (j.elbow_f as Vector2)).angle(), "z": z.hand_f},
		"back": {"p": j.chest, "a": ((j.sh as Vector2) - (j.hip as Vector2)).angle(), "z": 0.0}}
	return j


## `p` pulled within reach of both `a` (bone la) and `c` (bone lc): alternating projections onto the
## two discs, so a steered joint never stretches either bone.
static func _fit(p: Vector2, a: Vector2, c: Vector2, la: float, lc: float) -> Vector2:
	for i in 8:
		if p.distance_to(a) > la:
			p = a + (p - a).normalized() * la
		if p.distance_to(c) > lc:
			p = c + (p - c).normalized() * lc
	return p
