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


const FRAMES := [[0.0, 1.0, -1.0], [1.6, 1.0, -1.0], [3.1, 1.0, -1.0], [4.7, 1.0, -1.0],
	[0.6, 0.0, -1.0], [0.6, 0.0, 0.2], [0.6, 0.0, 0.34], [0.6, 0.0, 0.45], [0.6, 0.0, 0.75], [2.0, 0.5, 0.4]]


func _each_frame(weapon: String, fn: Callable, shield := false, seated := false) -> void:
	for f in FRAMES:
		fn.call(FkSkeleton.solve(1.16, weapon, {"walk": f[0], "move": f[1], "atk": f[2]}, shield, seated), f)


func test_bones_never_stretch() -> void:
	var b := 1.16
	for w in ["sword", "axe", "spear", "halberd", "musket", "crossbow", "bow", "javelin", "sling", "staff", "crew", "none"]:
		_each_frame(w, func(j: Dictionary, f: Array) -> void:
			var tag := "%s %s" % [w, f]
			check_near(j.hip.distance_to(j.knee_n), FkSkeleton.THIGH * b, 0.05, tag + " near thigh")
			check_near(j.knee_n.distance_to(j.foot_n), FkSkeleton.SHIN * b, 0.05, tag + " near shin")
			check_near(j.hip.distance_to(j.knee_f), FkSkeleton.THIGH * b, 0.05, tag + " far thigh")
			check_near(j.sh_n.distance_to(j.elbow_n), FkSkeleton.UPPER * b, 0.05, tag + " upper arm")
			check_near(j.elbow_n.distance_to(j.hand_n), FkSkeleton.FORE * b, 0.05, tag + " forearm")
			check_near(j.sh_f.distance_to(j.elbow_f), FkSkeleton.UPPER * b, 0.05, tag + " far upper arm")
			check_near(j.elbow_f.distance_to(j.hand_f), FkSkeleton.FORE * b, 0.05, tag + " far forearm"))


func test_knees_forward_elbows_down_feet_grounded() -> void:
	for w in ["sword", "spear", "musket", "bow", "none"]:
		_each_frame(w, func(j: Dictionary, f: Array) -> void:
			var tag := "%s %s" % [w, f]
			# The knee lies forward (+x) of the hip→foot midpoint.
			check(j.knee_n.x >= j.hip.lerp(j.foot_n, 0.5).x - 0.01, tag + " near knee forward")
			check(j.knee_f.x >= j.hip.lerp(j.foot_f, 0.5).x - 0.01, tag + " far knee forward")
			# The elbow lies on the down/back side of the shoulder→hand line (behind it when the arm is raised).
			var d: Vector2 = j.hand_n - j.sh_n
			var nrm := d.orthogonal() if d.orthogonal().dot(Vector2(-0.3, 1.0)) >= 0.0 else -d.orthogonal()
			check((j.elbow_n - j.sh_n.lerp(j.hand_n, 0.5)).dot(nrm) >= -0.01, tag + " elbow bends down/back")
			check(j.foot_n.y <= 0.01 and j.foot_f.y <= 0.01, tag + " feet not below ground")
			check(j.foot_n.y >= -7.0 and j.foot_f.y >= -7.0, tag + " feet lift at most 7 px"))


func test_strike_reaches_ahead_of_guard() -> void:
	for w in ["sword", "axe", "spear"]:
		var guard := FkSkeleton.solve(1.0, w, {"atk": -1.0})
		var hit := FkSkeleton.solve(1.0, w, {"atk": 0.5})
		check(hit.hand_n.x > guard.hand_n.x, "%s: strike hand ahead of guard" % w)
		check(hit.lean > 0.0, "%s: leans into the strike" % w)


func test_wind_up_is_overhead_for_chops() -> void:
	var wind := FkSkeleton.solve(1.0, "axe", {"atk": 0.34})
	check(wind.hand_n.y < wind.sh.y - 8.0, "hand above the shoulder at full wind-up")


func test_seated_foot_hangs_forward_below_hip() -> void:
	var j := FkSkeleton.solve(1.0, "lance", {"atk": -1.0}, false, true)
	check(j.foot_n.x > j.hip.x and j.foot_n.y > j.hip.y + 10.0, "stirrup foot forward and below")
	check(j.knee_n.x > j.hip.x, "thigh along the saddle")


func test_unknown_weapon_idles() -> void:
	var j := FkSkeleton.solve(1.0, "no_such_weapon", {"atk": 0.45})
	check_eq(j.lean, 0.0, "no stance, no lean")
