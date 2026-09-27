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
## Ankle height above the ground line (the boot's sole is below it).
const ANKLE := 1.2


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
	"club": "chop", "sword": "chop", "saber": "chop", "gladius": "chop", "axe": "chop", "hammer": "chop",
	"rune_hammer": "chop", "leafblade": "chop", "spellsword": "chop", "baton": "chop", "shovel": "chop",
	"spear": "thrust", "lance": "thrust", "halberd": "pole", "glaive": "pole",
	"musket": "aim", "rifle": "aim", "arcane_rifle": "aim", "rune_rifle": "aim", "crossbow": "aim",
	"bow": "bow", "starbow": "bow", "javelin": "throw", "throwing_axe": "throw", "sling": "sling",
	"staff": "staff", "crew": "crew",
}

## Keyframes guard / wind / hit, relative to the shoulder line `sh`, in px × build:
## h = near-hand target, f = far-hand target (absent = hangs and counter-swings), a = weapon angle
## (rad; 0 = forward, −PI/2 = up), lean = torso lean (rad, + forward), lunge = body shift forward (px).
## arc = the near hand travels around the shoulder (overhead chops) instead of in a straight line.
const STANCES := {
	"idle": {"guard": {"h": Vector2(3, 16)}, "wind": {"h": Vector2(3, 16)}, "hit": {"h": Vector2(3, 16)}},
	"chop": {"arc": true,
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
	"throw": {"arc": true,
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
	var out := {"lean": lerpf(a.get("lean", 0.0), z.get("lean", 0.0), k),
		"lunge": lerpf(a.get("lunge", 0.0), z.get("lunge", 0.0), k),
		"a": lerpf(a.get("a", 0.0), z.get("a", 0.0), k), "two": st.get("two", false)}
	var h0: Vector2 = a.h
	var h1: Vector2 = z.h
	if st.get("arc", false):
		out["h"] = Vector2.from_angle(lerpf(h0.angle(), h1.angle(), k)) * lerpf(h0.length(), h1.length(), k)
	else:
		out["h"] = h0.lerp(h1, k)
	if a.has("f"):
		out["f"] = (a.f as Vector2).lerp(z.f, k)
	return out


## All joints for one frame. b = build; pose = {walk, move, atk}; shield = far hand holds a shield;
## seated = rider (one leg in a stirrup, no walk cycle).
static func solve(b: float, weapon: String, pose: Dictionary, shield := false, seated := false) -> Dictionary:
	var mv: float = pose.get("move", 1.0 if pose.get("moving", false) else 0.0)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var k := key(FAMILY.get(weapon, "idle"), pose.get("atk", -1.0))
	var bob := lerpf(sin(t * 2.1) * 0.7, absf(sin(walk)) * 2.2, mv)
	var lunge: float = k.lunge * b * (0.0 if seated else 1.0)
	var hip := Vector2(lunge * 0.6, -HIP_Y * b + bob * 0.5)
	var sh := hip + Vector2(1.5 * b, -SPINE * b).rotated(k.lean)
	var j := {"hip": hip, "sh": sh, "lean": k.lean, "lunge": lunge, "dir": Vector2.from_angle(k.a)}
	# Legs: feet on the ground line; a stride with lift while walking, the front foot planted forward on a lunge.
	for i in 2:
		var foot: Vector2
		if seated:
			foot = hip + Vector2(5.0 - 3.0 * i, 16.0) * b
		else:
			var ph := walk + PI * i
			var fx := lerpf(2.8 if i == 0 else -3.6, 13.0 * sin(ph), mv) + (lunge * 1.6 / b if i == 0 else 0.0)
			var lift := 4.5 * maxf(0.0, cos(ph)) * mv
			# The ankle sits ANKLE above the ground so the boot's sole is on it.
			foot = Vector2(fx * b, -(ANKLE + lift) * b)
		foot = reach(hip, foot, THIGH * b, SHIN * b)
		var tag := "n" if i == 0 else "f"
		j["foot_" + tag] = foot
		j["knee_" + tag] = ik(hip, foot, THIGH * b, SHIN * b, Vector2.RIGHT)
	# Arms: near arm to the stance's hand target; far arm to the shield grip, the weapon (two-handed),
	# the stance's far target, or hanging with a counter-swing.
	j["sh_n"] = sh + Vector2(2, 1) * b
	j["sh_f"] = sh + Vector2(-3, 1) * b
	var elbow_side := Vector2(-0.3, 1.0)
	var hand_n := reach(j.sh_n, sh + (k.h as Vector2) * b, UPPER * b, FORE * b)
	j["hand_n"] = hand_n
	j["elbow_n"] = ik(j.sh_n, hand_n, UPPER * b, FORE * b, elbow_side)
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
	j["elbow_f"] = ik(j.sh_f, hand_f, UPPER * b, FORE * b, elbow_side)
	return j
