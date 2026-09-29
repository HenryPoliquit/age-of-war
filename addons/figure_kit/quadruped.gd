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
const CADENCE := 1.8
## Share of a stride a hoof spends planted.
const DUTY := 0.65
## Four-beat lateral walk as stride offsets (a higher offset lifts off earlier): left hind, left fore,
## right hind, right fore. Unmirrored, the right legs are the near ones (n), the left the far ones (f).
const LEGS := {"hf": 0.0, "ff": 0.75, "hn": 0.5, "fn": 0.25}
## Rest position of the poll (head joint) per head kind, relative to the barrel centre plus L along x,
## and how far the head thrusts on the charge (× lunge).
const HEAD := {"horse": [Vector2(12, -25), 0.4], "deer": [Vector2(10, -29), 0.4], "boar": [Vector2(4, -2), 0.5],
	"ram": [Vector2(5, -8), 0.6], "bear": [Vector2(6, -8), 0.6]}
## The IK pair's length over the rest distance from the top joint to the fetlock: soft legs, and every
## planted hoof within reach.
const SLACK := 1.10


static func cadence(bp: Dictionary) -> float:
	return CADENCE * 33.0 / float(bp.H)


## All joints for one frame. `view` is the camera ({yaw}, see FkRig). Returns:
##   c, withers, croup, back, dock, poll   in rig space, all in the plane z = 0: draw them under a horizontal
##                                         scale of j.cy, which is what the camera does to that plane
##   saddle                                where the rider sits, on the screen
##   head_angle, lunge, bob, cadence, cy   floats (cy = cos of the camera's yaw)
##   legs                                  {leg: {root, top, mid, fetlock, hoof: screen Vector2, p3: the same
##                                         in rig space (Vector3), planted: bool}} for each leg in LEGS
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
	var bob := lerpf(sin(t * 1.5 + seed) * 0.5, absf(sin(theta)) * 2.0, mv)
	var c := Vector2(lunge, -H - 10 + bob)
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
	var span := pace / cad * DUTY * TAU
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
		var pair := SLACK * absf(rest_pastern.y - rest_top_y)
		var l1 := pair * (0.52 if front else 0.5)
		var l2 := pair - l1
		var s := fposmod(theta / TAU + LEGS[leg], 1.0)
		var planted := s < DUTY
		var gx: float
		var lift := 0.0
		var fold := 0.0
		if planted:
			gx = span * (0.5 - s / DUTY)
		else:
			var u := (s - DUTY) / (1.0 - DUTY)
			gx = span * (u - 0.5)
			var e := sin(u * PI)
			lift = e * (0.18 if front else 0.14) * H
			# The pastern folds up and back and opens again gently (a smoothstep of the swing), so the joints
			# above it do not lurch at lift-off.
			fold = e * e * (3.0 - 2.0 * e)
		var hoof := Vector2(hoof_x0 + gx * mv, -lift * mv)
		var a := lerpf(0.6, 0.6 - 1.4 * fold, mv)
		var pastern := Vector2(-sin(a), -cos(a)) * P
		var top3 := FkRig.at(top, zl)
		var fet3 := FkRig.reach3(top3, FkRig.at(hoof + pastern, zl), l1, l2)
		var p3 := {"root": FkRig.at(root, zl), "top": top3,
			"mid": FkRig.ik3(top3, fet3, l1, l2, FkRig.plane_pole(top3, fet3, FkSkeleton.KNEE if front else FkSkeleton.ELBOW)),
			"fetlock": fet3, "hoof": FkRig.at(FkRig.xy(fet3) - pastern, zl)}
		var g: Dictionary = FkRig.project_all(p3, view)
		g["p3"] = p3
		g["planted"] = planted or mv == 0.0
		legs[leg] = g
		z[leg] = zl * (-1.0 if mirrored else 1.0)
	j["legs"] = legs
	j["z"] = z
	return j
