extends TestCase
## FkRig: the 3D helpers under the humanoid rig: camera projection, two-bone IK with a pole vector.

const YAW := 0.35


func test_project_at_yaw_zero_is_the_flat_picture() -> void:
	for p in [Vector3(3, -20, 4), Vector3(-7, 0, -2), Vector3.ZERO]:
		check_eq(FkRig.project(p), Vector2(p.x, p.y), "no yaw: (x, y)")
		check_eq(FkRig.project(p, {"yaw": 0.0}), Vector2(p.x, p.y), "explicit yaw 0")


func test_yaw_moves_the_near_side_toward_the_rear() -> void:
	var near := FkRig.project(Vector3(0, -10, 4), {"yaw": YAW})
	var far := FkRig.project(Vector3(0, -10, -4), {"yaw": YAW})
	check(near.x < 0.0 and far.x > 0.0, "near side toward the rear, far side toward the front")
	check_near(near.x, -4.0 * sin(YAW), 1e-5, "by z · sin(yaw)")
	check_eq(near.y, -10.0, "height is untouched")


func test_yaw_spreads_the_two_sides_evenly_and_leaves_the_middle() -> void:
	for p in [Vector3(3, -20, 4), Vector3(-7, 5, 2), Vector3(12, 0, 9)]:
		var near := FkRig.project(p, {"yaw": YAW})
		var far := FkRig.project(Vector3(p.x, p.y, -p.z), {"yaw": YAW})
		check_near((near.x + far.x) / 2.0, p.x * cos(YAW), 1e-5, "the pair's middle is the flat picture, foreshortened")
		check_near(far.x - near.x, 2.0 * p.z * sin(YAW), 1e-5, "and the sides spread by 2 · z · sin(yaw)")
		check_eq(near.y, far.y, "height matches")
	check_eq(FkRig.project(Vector3(5, -3, 0), {"yaw": YAW}).y, -3.0, "height is untouched")


func test_a_figure_turned_around_projects_as_its_mirror() -> void:
	# The view flips x and the kit negates z for the enemy army; a world-fixed camera agrees.
	for p in [Vector3(3, -20, 4), Vector3(-7, 5, -2), Vector3(12, 0, 9)]:
		var turned := Vector3(-p.x, p.y, -p.z)
		var a := FkRig.project(p, {"yaw": YAW})
		var b := FkRig.project(turned, {"yaw": YAW})
		check_near(b.x, -a.x, 1e-5, "screen x mirrors")
		check_near(b.y, a.y, 1e-6, "height matches")


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


func test_project_all_is_project_per_joint() -> void:
	var p := {"a": Vector3(3, -20, 4), "b": Vector3(-7, 5, -2), "c": Vector3(12, 0, 9)}
	for view in [{}, {"yaw": 0.0}, {"yaw": YAW}, {"yaw": -0.6}]:
		var all := FkRig.project_all(p, view)
		check_eq(all.keys(), p.keys(), "every joint projected")
		for k in p:
			check_eq(all[k], FkRig.project(p[k], view), "%s, view %s" % [k, view])


func test_xy_drops_the_depth() -> void:
	check_eq(FkRig.xy(Vector3(3, -20, 4)), Vector2(3, -20), "the flat picture of a point")


func test_project_dir_is_the_screen_direction_of_a_rig_direction() -> void:
	var d := Vector3(0.6, -0.8, 0.0)
	check_eq(FkRig.project_dir(d), Vector2(0.6, -0.8), "square-on: unchanged")
	var s := FkRig.project_dir(d, {"yaw": YAW})
	check_near(s.length(), 1.0, 1e-5, "a screen direction is a unit vector")
	check_near(s.angle(), Vector2(0.6 * cos(YAW), -0.8).angle(), 1e-5, "x foreshortens by cos(yaw)")
	# A direction along the camera's line of sight has no screen direction: it falls back, never NaN.
	var line := FkRig.project_dir(Vector3(sin(YAW), 0, cos(YAW)), {"yaw": YAW})
	check(not is_nan(line.x) and not is_nan(line.y), "no NaN along the line of sight")


func test_swivel_zero_is_the_plane_pole() -> void:
	for target in [Vector3(10, -2, 1.7), Vector3(-12, 5, 1.7), Vector3(3, -20, 1.7)]:
		var root := Vector3(0, -28, 1.7)
		for bend in [FkSkeleton.ELBOW, FkSkeleton.KNEE, 0.0]:
			check_eq(FkRig.swivel_pole(root, target, bend, 0.0), FkRig.plane_pole(root, target, bend), "swivel 0, bend %s" % bend)


func test_swivel_turns_the_fold_toward_the_viewer_about_the_axis() -> void:
	var root := Vector3(0, 0, 2.0)
	var target := Vector3(12, 3, 2.0)
	var axis := (target - root).normalized()
	var flat := FkRig.plane_pole(root, target, FkSkeleton.ELBOW)
	var quarter := FkRig.swivel_pole(root, target, FkSkeleton.ELBOW, PI / 2.0)
	check(quarter.distance_to(Vector3(0, 0, 1)) < 1e-5, "a quarter turn folds straight toward the viewer")
	check(absf(quarter.dot(axis)) < 1e-5, "and stays at right angles to the axis")
	var away := FkRig.swivel_pole(root, target, FkSkeleton.ELBOW, PI / 2.0, -1.0)
	check(away.distance_to(Vector3(0, 0, -1)) < 1e-5, "the far arm's side turns the other way")
	for deg in range(0, 91, 10):
		var p := FkRig.swivel_pole(root, target, FkSkeleton.ELBOW, deg_to_rad(deg))
		check_near(p.length(), 1.0, 1e-5, "a unit pole at %d°" % deg)
		check_near(p.dot(flat), cos(deg_to_rad(deg)), 1e-5, "%d° from the in-plane fold" % deg)


func test_swivelled_elbow_keeps_bone_lengths_and_moves_smoothly() -> void:
	var root := Vector3(0, 0, 4.0)
	var target := Vector3(8, -9, 4.0)
	var prev := Vector3.ZERO
	for i in 91:
		var pole := FkRig.swivel_pole(root, target, FkSkeleton.ELBOW, deg_to_rad(i))
		var elbow := FkRig.ik3(root, target, 9.0, 8.5, pole)
		check_near(root.distance_to(elbow), 9.0, 0.02, "upper arm at %d°" % i)
		check_near(elbow.distance_to(target), 8.5, 0.02, "forearm at %d°" % i)
		if i > 0:
			check(elbow.distance_to(prev) < 0.35, "no jump at %d°" % i)
		prev = elbow
	var flat := FkRig.ik3(root, target, 9.0, 8.5, FkRig.swivel_pole(root, target, FkSkeleton.ELBOW, 0.0))
	var out := FkRig.ik3(root, target, 9.0, 8.5, FkRig.swivel_pole(root, target, FkSkeleton.ELBOW, PI / 2.0))
	check(out.z > flat.z + 5.0, "swivelled out, the elbow stands well toward the viewer (%.1f vs %.1f)" % [out.z, flat.z])
