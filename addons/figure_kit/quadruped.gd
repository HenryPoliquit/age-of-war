class_name FkQuadruped
extends RefCounted
## Joint math for four-legged beasts (horse, deer, boar, ram, bear): a gait-driven spine and head, and legs
## that plant their hooves by two-bone IK. Joints are in rig space (x forward, y down, z toward the viewer;
## see FkRig), each leg in the plane of its own side. Proportions come from a beast preset (FkMounts.BEASTS:
## L = half the body's length, H = leg height).

## Ground covered per radian of walk phase (screen px) unless the pose gives its own (pose.pace): a planted
## hoof slides back at exactly this pace on the screen, so it stays put on the ground.
const PACE := 1.0 / 0.11
## Leg strides per radian of walk phase for a beast of height 33; smaller beasts step faster.
const CADENCE := 2.1
## Share of a stride a hoof spends planted.
const DUTY := 0.65
## Four-beat lateral walk as stride offsets (a higher offset lifts off earlier): left hind, left fore,
## right hind, right fore. Unmirrored, the right legs are the near ones (n), the left the far ones (f).
const LEGS := {"hf": 0.0, "ff": 0.75, "hn": 0.5, "fn": 0.25}
## Rest position of the poll (head joint) per head kind, relative to the barrel centre plus L along x,
## and how far the head thrusts on the charge (× lunge).
const HEAD := {"horse": [Vector2(12, -25), 0.4], "deer": [Vector2(10, -29), 0.4], "boar": [Vector2(4, -2), 0.5],
	"ram": [Vector2(5, -8), 0.6], "bear": [Vector2(6, -8), 0.6]}
## The IK pair's length over the rest distance from the top joint to the fetlock: a foreleg is nearly straight
## when it carries the weight, a hind leg keeps its hock bent. `REACH_*` is how much of that length a planted leg
## may use (a foreleg gets nearly straight as the body passes over it; a hock stays a little bent).
const SLACK_FORE := 1.035
const SLACK_HIND := 1.075
const REACH_FORE := 0.995
const REACH_HIND := 0.965
## The hoof's pitch (rad, + toe down) as the heel lifts at the end of the stance (the toe stays planted), and the fetlock's
## fold at the middle of the swing.
const BREAKOVER := 0.45
const FOLD := 1.4


static func cadence(bp: Dictionary) -> float:
	return CADENCE * 33.0 / float(bp.H)


## One leg's place in its stride at walk phase `theta`: {s (share of the stride), planted, gx (hoof ahead of its rest
## spot, rig px), lift, pitch (hoof pitch, rad, + toe down), pivot (1 = the hoof turns about its toe, planted; 0 = about its
## middle, in the air), fold (0..1)}. The swing leaves and arrives at the stance's own pace, so the hoof never lurches.
static func _state(theta: float, leg: String, span: float, H: float) -> Dictionary:
	var front: bool = leg[0] == "f"
	var s := fposmod(theta / TAU + LEGS[leg], 1.0)
	if s < DUTY:
		var v := s / DUTY
		return {"s": s, "planted": true, "gx": span * (0.5 - v), "lift": 0.0, "fold": 0.0,
			"pitch": BREAKOVER * FkGait.smooth((v - 0.7) / 0.3), "pivot": 1.0}
	var u := (s - DUTY) / (1.0 - DUTY)
	# A Hermite from the back of the stance to the front, leaving and arriving at the stance's pace.
	var m := -span * (1.0 - DUTY) / DUTY
	var u2 := u * u
	var u3 := u2 * u
	var gx := (2.0 * u3 - 3.0 * u2 + 1.0) * (-span * 0.5) + (u3 - 2.0 * u2 + u) * m + (-2.0 * u3 + 3.0 * u2) * (span * 0.5) + (u3 - u2) * m
	var e := sin(u * PI)
	# The pastern folds up and back and opens again gently (a smoothstep of the swing), so the joints above it do not
	# lurch at lift-off; the hoof carries on from the breakover pitch.
	var fold := e * e * (3.0 - 2.0 * e)
	return {"s": s, "planted": false, "gx": gx, "lift": e * (0.18 if front else 0.14) * H, "fold": fold,
		"pitch": FOLD * fold + BREAKOVER * (1.0 - FkGait.smooth(u / 0.3)), "pivot": 1.0 - FkGait.smooth(u / 0.3)}


static var _body_cache := {}


## How high the body may stand over a stride (rig y of the barrel centre, up is negative), one sample in 64 of the walk phase:
## as high as the legs on the ground allow, smoothed a little (about a tenth of the stride) without ever rising above what a leg
## allows, so the back rises and falls smoothly rather than lurching as legs lift and land.
static func _body_curve(bp: Dictionary, span: float) -> PackedFloat32Array:
	var key := "%s|%s|%s|%s" % [bp.H, bp.L, bp.head, snappedf(span, 0.001)]
	if _body_cache.has(key):
		return _body_cache[key]
	var H: float = bp.H
	var P := 0.14 * H
	var raw := PackedFloat32Array()
	for k in 64:
		var bound := -INF
		for leg in LEGS:
			var st := _state(TAU * k / 64.0, leg, span, H)
			if not st.planted:
				continue
			var front: bool = leg[0] == "f"
			var top_off := Vector2(0, 0.22 * H) if front else Vector2(0.12 * H, 0.28 * H)
			var rest_top_y := -H - 5 + top_off.y
			var pair := (SLACK_FORE if front else SLACK_HIND) * absf(-cos(0.6) * P - rest_top_y)
			var reach := pair * (REACH_FORE if front else REACH_HIND)
			var a := 0.6 - float(st.pitch)
			var dx := sin(0.6) * P + float(st.gx) - sin(a) * P
			var dy := sqrt(maxf(0.0, reach * reach - dx * dx))
			bound = maxf(bound, -cos(a) * P - dy - 5.0 - top_off.y)
		raw.append(bound)
	# Dilate the bound by 3 samples (the body starts to sink just before a leg lands), then average over the same window: the
	# result follows the bound closely, is smooth, and never rises above what any leg allows.
	var dil := PackedFloat32Array()
	for k in 64:
		var m := raw[k]
		for d in range(-3, 4):
			m = maxf(m, raw[(k + d + 64) % 64])
		dil.append(m)
	var curve := PackedFloat32Array()
	for k in 64:
		var sum := 0.0
		for d in range(-3, 4):
			sum += dil[(k + d + 64) % 64]
		curve.append(sum / 7.0)
	_body_cache[key] = curve
	return curve


## All joints for one frame. `view` is the camera ({yaw}, see FkRig). Returns:
##   c, withers, croup, back, dock, poll   in rig space, all in the plane z = 0: draw them under a horizontal
##                                         scale of j.cy, which is what the camera does to that plane
##   saddle                                where the rider sits, on the screen
##   head_angle, lunge, bob, cadence, cy   floats (cy = cos of the camera's yaw)
##   legs                                  {leg: {root, top, mid, fetlock, hoof: screen Vector2, p3: the same
##                                         in rig space (Vector3), planted: bool, pitch: the hoof's pitch (rad, + toe
##                                         down), pivot: 1 turning about its toe (planted) .. 0 about its middle}}
##                                         for each leg in LEGS
##   z                                     {leg: side of the body, + toward the viewer; negated for a mirrored beast}
static func solve(bp: Dictionary, pose: Dictionary, seed := 0, view := {}) -> Dictionary:
	var L: float = bp.L
	var H: float = bp.H
	var mv := FkPaint.move_amount(pose)
	var t: float = pose.get("t", 0.0)
	var cad := cadence(bp)
	var theta: float = pose.get("walk", 0.0) * cad
	# The ground scrolls at the beast's speed on the screen, but the camera squeezes the rig's x by cos(yaw):
	# the rig's stride is that much longer, so the projected hoof still slides back at `pace`.
	var cy := cos(view.get("yaw", 0.0))
	var pace: float = pose.get("pace", PACE) / cy
	var lunge := maxf(0.0, FkUnits.swing(pose.get("atk", -1.0))) * 5.0
	var span := pace / cad * DUTY * TAU
	# Idle sway; a walking beast's back follows the legs (see _body_curve): one smooth swell per step.
	var idle_y := -H - 10 + sin(t * 1.5 + seed) * 0.5
	var curve := _body_curve(bp, span)
	var f64 := fposmod(theta, TAU) / TAU * 64.0
	var k0 := int(f64) % 64
	var walk_y := lerpf(curve[k0], curve[(k0 + 1) % 64], f64 - floorf(f64))
	var c := Vector2(lunge, lerpf(idle_y, walk_y, mv))
	var bob := c.y - (-H - 10)
	# The back pitches with the gait: withers leading, croup lagging.
	var pitch := sin(theta * 2.0 + 0.5) * mv
	var head_kind: String = bp.head
	var j := {"c": c, "lunge": lunge, "bob": bob, "cadence": cad, "cy": cy,
		"withers": c + Vector2(0.55 * L, -11 + pitch), "croup": c + Vector2(-0.6 * L, -9 - pitch)}
	j["back"] = (j.withers as Vector2).lerp(j.croup, 0.5)
	j["dock"] = (j.croup as Vector2) + Vector2(-5, -2)
	var seat := c + Vector2(-2, -10 - (5.0 if head_kind == "bear" else 0.0) - pitch * 0.3)
	j["saddle"] = FkRig.project(FkRig.at(seat), view)
	# The head nods twice a stride, as a walking horse's does.
	var hk: Array = HEAD.get(head_kind, HEAD.horse)
	var nod := sin(theta * 2.0) * mv
	j["head_angle"] = nod * 0.06
	j["poll"] = c + (hk[0] as Vector2) + Vector2(L + lunge * float(hk[1]), nod * 1.2)
	# Legs: the top joint rides the body; the hoof follows the gait; knee (fore) or hock (hind) by IK.
	var P := 0.14 * H
	var w := 0.3 * L
	var mirrored: bool = pose.get("mirrored", false)
	var z := {}
	var legs := {}
	for leg in LEGS:
		var front: bool = leg[0] == "f"
		var near: bool = leg[1] == "n"
		var zl := w if near else -w
		var root := c + Vector2(0.62 * L * (1.0 if front else -1.0), 5)
		var top_off := Vector2(0, 0.22 * H) if front else Vector2(0.12 * H, 0.28 * H)
		var top := root + top_off
		# At rest the fetlock stands straight under the top joint, the pastern sloping up and back.
		var rest_pastern := Vector2(-sin(0.6), -cos(0.6)) * P
		var hoof_x0 := top.x - rest_pastern.x
		var rest_top_y := -H - 5 + top_off.y
		var pair := (SLACK_FORE if front else SLACK_HIND) * absf(rest_pastern.y - rest_top_y)
		var l1 := pair * (0.52 if front else 0.5)
		var l2 := pair - l1
		var st := _state(theta, leg, span, H)
		var planted: bool = st.planted
		var hoof := Vector2(hoof_x0 + float(st.gx) * mv, -float(st.lift) * mv)
		var hpitch: float = float(st.pitch) * mv
		var a := 0.6 - hpitch
		var pastern := Vector2(-sin(a), -cos(a)) * P
		var top3 := FkRig.at(top, zl)
		var fet3 := FkRig.reach3(top3, FkRig.at(hoof + pastern, zl), l1, l2)
		var p3 := {"root": FkRig.at(root, zl), "top": top3,
			"mid": FkRig.ik3(top3, fet3, l1, l2, FkRig.plane_pole(top3, fet3, FkSkeleton.KNEE if front else FkSkeleton.ELBOW)),
			"fetlock": fet3, "hoof": FkRig.at(FkRig.xy(fet3) - pastern, zl)}
		var g: Dictionary = FkRig.project_all(p3, view)
		g["p3"] = p3
		g["pitch"] = hpitch
		g["pivot"] = float(st.pivot) if mv > 0.0 else 1.0
		g["planted"] = planted or mv == 0.0
		legs[leg] = g
		z[leg] = zl * (-1.0 if mirrored else 1.0)
	j["legs"] = legs
	j["z"] = z
	return j
