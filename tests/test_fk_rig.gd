extends TestCase
## FkRig: the 3D helpers under the humanoid rig: camera projection, two-bone IK with a pole vector.

const YAW := 0.35


func test_project_at_yaw_zero_is_the_flat_picture() -> void:
	for p in [Vector3(3, -20, 4), Vector3(-7, 0, -2), Vector3.ZERO]:
		check_eq(FkRig.project(p), Vector2(p.x, p.y), "no yaw: (x, y)")
		check_eq(FkRig.project(p, {"yaw": 0.0}), Vector2(p.x, p.y), "explicit yaw 0")
		check_eq(FkRig.depth(p), p.z, "no yaw: depth is z")


func test_yaw_moves_the_near_side_toward_the_rear() -> void:
	var near := FkRig.project(Vector3(0, -10, 4), {"yaw": YAW})
	var far := FkRig.project(Vector3(0, -10, -4), {"yaw": YAW})
	check(near.x < 0.0 and far.x > 0.0, "near side toward the rear, far side toward the front")
	check_near(near.x, -4.0 * sin(YAW), 1e-5, "by z · sin(yaw)")
	check_eq(near.y, -10.0, "height is untouched")


func test_projection_and_depth_are_a_rotation() -> void:
	for p in [Vector3(3, -20, 4), Vector3(-7, 5, -2), Vector3(12, 0, 9)]:
		var s := FkRig.project(p, {"yaw": YAW})
		check_near(Vector2(s.x, FkRig.depth(p, {"yaw": YAW})).length(), Vector2(p.x, p.z).length(), 1e-4, "lengths in (x, z) survive")


func test_a_figure_turned_around_projects_as_its_mirror() -> void:
	# The view flips x and the kit negates depth for the enemy army; a world-fixed camera agrees.
	for p in [Vector3(3, -20, 4), Vector3(-7, 5, -2), Vector3(12, 0, 9)]:
		var turned := Vector3(-p.x, p.y, -p.z)
		var a := FkRig.project(p, {"yaw": YAW})
		var b := FkRig.project(turned, {"yaw": YAW})
		check_near(b.x, -a.x, 1e-5, "screen x mirrors")
		check_near(b.y, a.y, 1e-6, "height matches")
		check_near(FkRig.depth(turned, {"yaw": YAW}), -FkRig.depth(p, {"yaw": YAW}), 1e-5, "depth negates")


func test_reach3_clamps_far_targets_only() -> void:
	var root := Vector3(1, 2, 3)
	var end := FkRig.reach3(root, Vector3(101, 2, 3), 9.0, 8.5)
	check_near(root.distance_to(end), 17.49, 1e-4, "full extension")
	check(end.y == 2.0 and end.z == 3.0, "along the line to the target")
	check_eq(FkRig.reach3(root, Vector3(5, 5, 6), 9.0, 8.5), Vector3(5, 5, 6), "reachable target unchanged")


func test_ik3_with_the_plane_pole_is_the_2d_ik() -> void:
	for lens in [Vector2(15, 14), Vector2(9, 8.5)]:
		for root in [Vector2(0, -28), Vector2(3, -50)]:
			for target in [Vector2(0, 0), Vector2(10, -2), Vector2(-12, 0), Vector2(3, -20), Vector2(40, 0), Vector2(14, -50), Vector2(-3, -60)]:
				for bend in [FkSkeleton.ELBOW, FkSkeleton.KNEE, 0.0]:
					var end := FkSkeleton.reach(root, target, lens.x, lens.y)
					var flat := FkSkeleton.ik(root, end, lens.x, lens.y, bend)
					var r3 := FkRig.at(root, 1.7)
					var e3 := FkRig.at(end, 1.7)
					var j := FkRig.ik3(r3, e3, lens.x, lens.y, FkRig.plane_pole(r3, e3, bend))
					var tag := "%s %s %s bend %s" % [lens, root, target, bend]
					check(Vector2(j.x, j.y).distance_to(flat) < 1e-3, "same joint as the 2D solve: " + tag)
					check_near(j.z, 1.7, 1e-6, "stays in its plane: " + tag)


func test_ik3_keeps_bone_lengths_out_of_the_plane() -> void:
	var root := Vector3(0, -28, 1)
	for target in [Vector3(10, -2, 6), Vector3(-12, 0, -5), Vector3(3, -20, 12), Vector3(6, -40, -9)]:
		for pole in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(-1, 1, 1)]:
			var end := FkRig.reach3(root, target, 15.0, 14.0)
			var j := FkRig.ik3(root, end, 15.0, 14.0, pole)
			check_near(root.distance_to(j), 15.0, 0.02, "upper bone for %s pole %s" % [target, pole])
			check_near(j.distance_to(end), 14.0, 0.02, "lower bone for %s pole %s" % [target, pole])


func test_ik3_joint_turns_smoothly_with_the_pole() -> void:
	# An elbow that swings round the shoulder-to-hand axis moves on a circle, without jumping.
	var root := Vector3(0, 0, 0)
	var target := Vector3(10, 3, 4)
	var l1 := 9.0
	var l2 := 8.5
	var axis := (target - root).normalized()
	var u := axis.cross(Vector3.UP).normalized()
	var v := axis.cross(u)
	var d := root.distance_to(target)
	var a := acos((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d))
	var radius := l1 * sin(a)
	var prev := Vector3.ZERO
	for deg in 361:
		var th := deg_to_rad(deg)
		var j := FkRig.ik3(root, target, l1, l2, u * cos(th) + v * sin(th))
		var off := (j - root) - axis * (j - root).dot(axis)
		check_near(off.length(), radius, 1e-3, "constant distance from the axis at %d°" % deg)
		if deg > 0:
			check(j.distance_to(prev) <= radius * deg_to_rad(1.0) * 1.001 + 1e-4, "no jump at %d°" % deg)
		prev = j


func test_ik3_degenerate_pole_puts_the_joint_on_the_line() -> void:
	var root := Vector3(0, -28, 0)
	var target := Vector3(0, -2, 0)
	var axis := (target - root).normalized()
	for pole in [Vector3.ZERO, axis * 3.0, -axis]:
		var j := FkRig.ik3(root, target, 15.0, 14.0, pole)
		check(not is_nan(j.x) and not is_nan(j.y) and not is_nan(j.z), "no NaN for pole %s" % pole)
		check(j.distance_to(root + axis * 15.0) < 1e-4, "on the line for pole %s" % pole)
