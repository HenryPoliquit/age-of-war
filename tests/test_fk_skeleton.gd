extends TestCase
## FkSkeleton: fixed bones, IK bend sides, and the per-frame joint invariants the owner asked for.


func test_ik_keeps_bone_lengths() -> void:
	var root := Vector2(0, -28)
	for target in [Vector2(0, 0), Vector2(10, -2), Vector2(-12, 0), Vector2(3, -20), Vector2(40, 0)]:
		var end := FkSkeleton.reach(root, target, 15.0, 14.0)
		var j := FkSkeleton.ik(root, end, 15.0, 14.0, Vector2.RIGHT)
		check_near(root.distance_to(j), 15.0, 0.02, "thigh for %s" % target)
		check_near(j.distance_to(end), 14.0, 0.02, "shin for %s" % target)


func test_ik_bend_sides() -> void:
	var knee := FkSkeleton.ik(Vector2(0, -28), Vector2(0, 0), 15.0, 14.0, Vector2.RIGHT)
	check(knee.x > 0.0, "knee bends forward")
	var elbow := FkSkeleton.ik(Vector2(0, 0), Vector2(14, 0), 9.0, 8.5, Vector2(-0.3, 1.0))
	check(elbow.y > 0.0, "elbow bends down")


func test_reach_clamps_far_targets() -> void:
	var end := FkSkeleton.reach(Vector2.ZERO, Vector2(100, 0), 9.0, 8.5)
	check(end.x < 17.5 and end.x > 17.4, "clamped to full extension")
	check_eq(FkSkeleton.reach(Vector2.ZERO, Vector2(5, 5), 9.0, 8.5), Vector2(5, 5), "reachable target unchanged")
