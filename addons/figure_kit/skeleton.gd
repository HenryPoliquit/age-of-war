class_name FkSkeleton
extends RefCounted
## Joint math for the human figure: fixed bone lengths, two-bone IK and stance keyframes.
## Local space: feet at y = 0, facing +x, up is −y. Lengths are multiplied by the figure's build.

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
## Default elbow bend side: down and a little back.
const ELBOW := Vector2(-0.3, 1.0)


## Middle joint (knee, elbow) of a two-bone limb from `root` to `target`. Of the two solutions it
## takes the one lying toward `side`. Call with a reachable target (see reach()).
static func ik(root: Vector2, target: Vector2, l1: float, l2: float, side: Vector2) -> Vector2:
	var v := target - root
	var d := clampf(v.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var dir := v.normalized() if v.length() > 1e-4 else Vector2.DOWN
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var j1 := root + dir.rotated(a) * l1
	var j2 := root + dir.rotated(-a) * l1
	return j1 if (j1 - root).dot(side) >= (j2 - root).dot(side) else j2


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
##   s / sf  near / far shoulder offset     e / ef  near / far elbow bend side
##   lean  torso lean (rad, + forward)      lunge  body shift forward (px)
##   crouch  hip drop (px)                  step  passing step (0..1: the back foot swings through to the front)
## path: "line" (the near hand travels straight between keys) or "arc" (around the shoulder, overhead chops).
const STANCES := {
	"idle": {"guard": {"h": Vector2(3, 16)}, "wind": {"h": Vector2(3, 16)}, "hit": {"h": Vector2(3, 16)}},
	# One-handed blade: chambered high beside the ear (arm bent), blade back; a passing step and a steep
	# cut that sweeps the arm out to full, straight extension at shoulder height, the wrist snapping the
	# blade level; off hand at the chest, checking to the ribs.
	"blade": {"path": "arc",
		"guard": {"h": Vector2(13, 3), "a": -0.5, "f": Vector2(4, 6), "crouch": 1.0, "lean": 0.03},
		"wind": {"h": Vector2(-2, -10), "a": -2.3, "f": Vector2(3, 6), "s": Vector2(-1, -2), "e": Vector2(1, 0.5),
			"crouch": 2.5, "lean": -0.05, "lunge": -1.0},
		"hit": {"h": Vector2(22, 5), "a": 0.02, "f": Vector2(-1, 8), "s": Vector2(2, 1), "crouch": 3.0, "lean": 0.18,
			"lunge": 7.0, "step": 1.0}},
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
	"aim": {
		"guard": {"h": Vector2(12, 1), "f": Vector2(17, 2), "a": 0.0},
		"wind": {"h": Vector2(12, 1), "f": Vector2(17, 2), "a": 0.0},
		"hit": {"h": Vector2(8.5, 1), "f": Vector2(13.5, 2), "a": -0.08, "lean": -0.06}},
	"bow": {
		"guard": {"h": Vector2(11, 1), "f": Vector2(15, 1), "a": 0.0},
		"wind": {"h": Vector2(3, -3), "f": Vector2(16, 0), "a": 0.0, "lean": -0.03},
		"hit": {"h": Vector2(11, 1), "f": Vector2(15, 1), "a": 0.0}},
	"throw": {"path": "arc",
		"guard": {"h": Vector2(4, -9), "a": -0.23},
		"wind": {"h": Vector2(-7, -10), "a": -0.35, "lean": -0.1, "lunge": -1.5},
		"hit": {"h": Vector2(15, 0), "a": 0.1, "lean": 0.2, "lunge": 6.0}},
	"sling": {"guard": {"h": Vector2(2, -14)}, "wind": {"h": Vector2(2, -14)}, "hit": {"h": Vector2(8, -10), "lean": 0.1}},
	"staff": {
		"guard": {"h": Vector2(10, 6), "f": Vector2(9, 13), "a": -1.456},
		"wind": {"h": Vector2(8, 6), "f": Vector2(7, 13), "a": -1.5},
		"hit": {"h": Vector2(15, 0), "f": Vector2(13, 8), "a": -1.2, "lean": 0.12, "lunge": 3.0}},
	"crew": {"guard": {"h": Vector2(14, 8), "f": Vector2(12, 9)}, "wind": {"h": Vector2(14, 8), "f": Vector2(12, 9)},
		"hit": {"h": Vector2(15, 8), "f": Vector2(13, 9), "lean": 0.1}},
}

## Far-hand shield grip (relative to sh) for shield bearers: holds the shield in front of the chest.
const SHIELD_GRIP := Vector2(6, 11)

const _FLOATS := ["a", "lean", "lunge", "crouch", "step"]
const _VECTORS := {"s": Vector2.ZERO, "sf": Vector2.ZERO, "e": ELBOW, "ef": ELBOW}


## One frame's keyframe values, on FkUnits.swing's beats: guard → wind (anticipation, 0–0.35),
## wind → hit (strike, 0.35–0.55; contact), hit → guard (recovery). Idle (atk < 0) is the guard.
static func key(family: String, atk: float) -> Dictionary:
	var st: Dictionary = STANCES.get(family, STANCES.idle)
	var a: Dictionary = st.guard
	var z: Dictionary = st.guard
	var k := 0.0
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
	var out := {"two": st.get("two", false)}
	for c in _FLOATS:
		out[c] = lerpf(a.get(c, 0.0), z.get(c, 0.0), k)
	for c in _VECTORS:
		out[c] = (a.get(c, _VECTORS[c]) as Vector2).lerp(z.get(c, _VECTORS[c]), k)
	var h0: Vector2 = a.h
	var h1: Vector2 = z.h
	if st.get("path", "line") == "arc":
		out["h"] = Vector2.from_angle(lerpf(h0.angle(), h1.angle(), k)) * lerpf(h0.length(), h1.length(), k)
	else:
		out["h"] = h0.lerp(h1, k)
	if a.has("f"):
		out["f"] = (a.f as Vector2).lerp(z.f, k)
	# The swinging foot of a passing step lifts mid-way through it.
	out["step_lift"] = sin(k * PI) if a.get("step", 0.0) != z.get("step", 0.0) else 0.0
	return out


## Boot outline points for an ankle at `foot`, rotated by `rot` (rad; − = toes up, + = heel up).
static func boot(foot: Vector2, rot: float, b: float) -> Array:
	return BOOT.map(func(p: Vector2) -> Vector2: return foot + (p * b).rotated(rot))


## Heel-to-toe roll over a stride: toes up as the foot lands in front (phase PI/2), heel up as it
## pushes off behind (3·PI/2), flat in between.
static func _roll(ph: float) -> float:
	return -0.35 * _bell(ph - PI / 2) + 0.5 * _bell(ph - 3 * PI / 2)


## A single bump of width PI/2 centred on d = 0 (one stride is TAU).
static func _bell(d: float) -> float:
	var w := wrapf(d, -PI, PI)
	return cos(2.0 * w) if absf(w) < PI / 4 else 0.0


## All joints for one frame. b = build; pose = {walk, move, atk, t}; shield = far hand holds a shield;
## seated = rider (one leg in a stirrup, no walk cycle).
static func solve(b: float, weapon: String, pose: Dictionary, shield := false, seated := false) -> Dictionary:
	var mv: float = pose.get("move", 1.0 if pose.get("moving", false) else 0.0)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var k := key(FAMILY.get(weapon, "idle"), pose.get("atk", -1.0))
	var bob := lerpf(sin(t * 2.1) * 0.7, absf(sin(walk)) * 2.2, mv)
	var lunge: float = k.lunge * b * (0.0 if seated else 1.0)
	var crouch: float = k.crouch * b * (0.0 if seated else 1.0)
	var hip := Vector2(lunge * 0.6, -HIP_Y * b + bob * 0.5 + crouch)
	var sh := hip + Vector2(1.5 * b, -SPINE * b).rotated(k.lean)
	var j := {"hip": hip, "sh": sh, "lean": k.lean, "lunge": lunge, "crouch": k.crouch, "dir": Vector2.from_angle(k.a),
		"e_n": k.e, "e_f": k.ef}
	# Legs: feet on the ground line; a stride with lift and heel-to-toe roll while walking, the front
	# foot planted forward on a lunge, the back foot swinging through on a passing step.
	for i in 2:
		var foot: Vector2
		var rot := 0.0
		if seated:
			foot = hip + Vector2(5.0 - 3.0 * i, 16.0) * b
			rot = -0.3
		else:
			var ph := walk + PI * i
			var fx := lerpf(2.8 if i == 0 else -3.6, 13.0 * sin(ph), mv)
			var lift := 4.5 * maxf(0.0, cos(ph)) * mv
			rot = _roll(ph) * mv
			if i == 0:
				fx += lunge * 1.6 / b * (1.0 - k.step)
			else:
				fx = lerpf(fx, 2.8 + lunge * 1.6 / b, k.step)
				lift += 4.0 * k.step_lift
				rot -= 0.2 * k.step_lift
			foot = Vector2(fx * b, -lift * b)
			# Keep the boot's lowest point on (never under) the ground.
			var low := 0.0
			for p in BOOT:
				low = maxf(low, ((p as Vector2) * b).rotated(rot).y)
			foot.y = minf(foot.y, -low)
		foot = reach(hip, foot, THIGH * b, SHIN * b)
		var tag := "n" if i == 0 else "f"
		j["foot_" + tag] = foot
		j["rot_" + tag] = rot
		j["knee_" + tag] = ik(hip, foot, THIGH * b, SHIN * b, Vector2.RIGHT)
	# Arms: shoulders move with the pose; near arm to the stance's hand target; far arm to the shield
	# grip, the stance's far target, the weapon (two-handed), or hanging with a counter-swing.
	j["sh_n"] = sh + Vector2(2, 1) * b + (k.s as Vector2) * b
	j["sh_f"] = sh + Vector2(-3, 1) * b + (k.sf as Vector2) * b
	var hand_n := reach(j.sh_n, sh + (k.h as Vector2) * b, UPPER * b, FORE * b)
	j["hand_n"] = hand_n
	j["elbow_n"] = ik(j.sh_n, hand_n, UPPER * b, FORE * b, k.e)
	var ft: Vector2
	if shield:
		ft = sh + SHIELD_GRIP * b
	elif k.has("f"):
		ft = sh + (k.f as Vector2) * b
	elif k.two:
		ft = hand_n - (j.dir as Vector2) * 8.0 * b
	else:
		ft = j.sh_f + Vector2(0, 16.5 * b).rotated(sin(walk) * 0.5 * mv - 0.1)
	var hand_f := reach(j.sh_f, ft, UPPER * b, FORE * b)
	j["hand_f"] = hand_f
	j["elbow_f"] = ik(j.sh_f, hand_f, UPPER * b, FORE * b, k.ef)
	return j
