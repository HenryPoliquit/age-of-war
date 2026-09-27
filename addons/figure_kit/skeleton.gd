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
