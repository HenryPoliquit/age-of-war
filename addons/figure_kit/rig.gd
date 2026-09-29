class_name FkRig
extends RefCounted
## 3D helpers under the figure rigs. A joint is a Vector3 in rig space: x forward (the way the figure
## faces), y down (up is −y), z toward the viewer (the near side is +z). A fixed orthographic camera,
## optionally turned about the vertical, projects it to the flat picture the parts are drawn in. Parts
## still sort by z (which side of the body they are on), not by camera depth: sorting by the camera's depth
## reorders the arm, cap, weapon and shield layering as soon as the camera turns.


## A flat (x, y) point lifted into rig space at `z`.
static func at(p: Vector2, z := 0.0) -> Vector3:
	return Vector3(p.x, p.y, z)


## The flat (x, y) of a rig point, as the picture would show it with the camera square-on.
static func xy(p: Vector3) -> Vector2:
	return Vector2(p.x, p.y)


## Screen position of a rig point. `view.yaw` (rad, default 0) turns the camera about the vertical toward
## the side the figure faces, so a positive yaw shifts the near side (z > 0) toward the rear.
static func project(p: Vector3, view := {}) -> Vector2:
	var yaw: float = view.get("yaw", 0.0)
	if yaw == 0.0:
		return Vector2(p.x, p.y)
	return Vector2(p.x * cos(yaw) - p.z * sin(yaw), p.y)


## Every joint in `p` (name → Vector3) projected at once, reading the view a single time (name → Vector2).
## Equal to project() per joint.
static func project_all(p: Dictionary, view := {}) -> Dictionary:
	var yaw: float = view.get("yaw", 0.0)
	var out := {}
	if yaw == 0.0:
		for k in p:
			var v: Vector3 = p[k]
			out[k] = Vector2(v.x, v.y)
	else:
		var c := cos(yaw)
		var s := sin(yaw)
		for k in p:
			var v: Vector3 = p[k]
			out[k] = Vector2(v.x * c - v.z * s, v.y)
	return out


## Screen direction (a unit vector) of a rig direction. Square-on that is its (x, y) as given.
static func project_dir(d: Vector3, view := {}) -> Vector2:
	var yaw: float = view.get("yaw", 0.0)
	if yaw == 0.0:
		return Vector2(d.x, d.y)
	var flat := Vector2(d.x * cos(yaw) - d.z * sin(yaw), d.y)
	return flat.normalized() if flat.length() > 1e-6 else Vector2.RIGHT


## Where the limb's end actually gets to: `target` if reachable, else full extension toward it.
static func reach3(root: Vector3, target: Vector3, l1: float, l2: float) -> Vector3:
	var v := target - root
	var m := l1 + l2 - 0.01
	return target if v.length() <= m else root + v.normalized() * m


## Middle joint (knee, elbow) of a two-bone limb from `root` to `target`. It lies in the plane through
## root→target that contains `pole`, on the pole's side, so turning the pole about that axis swings the
## joint round it without a jump. Call with a reachable target (see reach3()). With no usable pole (zero,
## or along root→target) the joint sits on the line, which is right only for a fully extended limb.
static func ik3(root: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var v := target - root
	var d := clampf(v.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var axis := v.normalized() if v.length() > 1e-4 else Vector3.DOWN
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var unit := pole.normalized()
	var side := unit - axis * unit.dot(axis)
	if side.length() < 1e-4:
		return root + axis * l1
	return root + (axis * cos(a) + side.normalized() * sin(a)) * l1


## The pole that folds a limb lying in a plane z = const the way FkSkeleton.ik does for `bend` (+1, −1; 0
## = on the line): the in-plane direction at right angles to root→target, on the bend's side.
static func plane_pole(root: Vector3, target: Vector3, bend: float) -> Vector3:
	var v := Vector2(target.x - root.x, target.y - root.y)
	var dir := v.normalized() if v.length() > 1e-4 else Vector2.DOWN
	return Vector3(-dir.y, dir.x, 0.0) * signf(bend)


## `plane_pole` swivelled about the root→target axis by `out` (rad) toward the viewer's side (`side` +1, the
## near side) or away from it (−1): 0 is the in-plane fold, PI/2 a fold straight out of the picture. The joint
## turns round the axis, so the bones keep their lengths and the elbow only swings out and in.
static func swivel_pole(root: Vector3, target: Vector3, bend: float, out: float, side := 1.0) -> Vector3:
	var pole := plane_pole(root, target, bend)
	if out == 0.0 or pole == Vector3.ZERO:
		return pole
	var axis := (target - root).normalized()
	var toward := Vector3(0, 0, side)
	toward = (toward - axis * toward.dot(axis)).normalized()
	return pole * cos(out) + toward * sin(out)
