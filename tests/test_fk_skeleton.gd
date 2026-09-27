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
			var nrm := d.orthogonal() if d.orthogonal().dot(j.e_n) >= 0.0 else -d.orthogonal()
			check((j.elbow_n - j.sh_n.lerp(j.hand_n, 0.5)).dot(nrm) >= -0.01, tag + " elbow bends to the pose's side")
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


func test_axe_edge_leads_the_swing() -> void:
	# The blade's edge faces where the head is travelling at contact (the owner: "pointed end on the correct direction").
	var before := FkSkeleton.solve(1.0, "axe", {"atk": 0.40})
	var hit := FkSkeleton.solve(1.0, "axe", {"atk": 0.47})
	var tip0: Vector2 = before.hand_n + (before.dir as Vector2) * 20.0
	var tip1: Vector2 = hit.hand_n + (hit.dir as Vector2) * 20.0
	check(FkWeapons.edge_normal(hit.dir).dot(tip1 - tip0) > 0.0, "edge faces the direction of travel")


# --- Motion pass (spec §6) --------------------------------------------------------------------

func _tip(j: Dictionary, length: float, b: float) -> Vector2:
	return (j.hand_n as Vector2) + (j.dir as Vector2) * length * b


func test_shoulder_moves_with_the_pose() -> void:
	var guard := FkSkeleton.solve(1.0, "sword", {"atk": -1.0})
	var wind := FkSkeleton.solve(1.0, "sword", {"atk": 0.34})
	var hit := FkSkeleton.solve(1.0, "sword", {"atk": 0.54})
	check((wind.sh_n - wind.sh).distance_to(guard.sh_n - guard.sh) > 1.5, "shoulder lifts on the wind-up")
	check((hit.sh_n - hit.sh).x > (guard.sh_n - guard.sh).x + 1.0, "shoulder drives forward on the strike")


func test_blade_chambers_beside_the_ear() -> void:
	var j := FkSkeleton.solve(1.0, "sword", {"atk": 0.34})
	var ear: Vector2 = j.sh + Vector2(0.4, -8.9)
	check(j.hand_n.distance_to(ear) < 5.0, "hand beside the ear")
	check(j.dir.y < -0.5 and j.dir.x < 0.0, "blade angled up and back")
	check(j.crouch > 1.5, "low centre of gravity")


func test_blade_strike_lands_head_to_chest() -> void:
	# A same-size opponent's head top is ≈ −63 px and chest ≈ −38 px above the ground (build 1).
	var j := FkSkeleton.solve(1.0, "sword", {"atk": 0.5})
	var tip := _tip(j, 22.0, 1.0)
	check(tip.y > -60.0 and tip.y < -38.0, "tip in the head-to-chest band (y = %.1f)" % tip.y)
	check(tip.x > 20.0, "tip reaches past our own body front")
	check(absf(j.dir.angle()) < 0.25, "wrist snapped flat: blade level at contact")


func test_blade_passing_step() -> void:
	var guard := FkSkeleton.solve(1.0, "sword", {"atk": -1.0})
	var hit := FkSkeleton.solve(1.0, "sword", {"atk": 0.54})
	check(guard.foot_f.x < guard.foot_n.x, "back foot behind at guard")
	check(hit.foot_f.x > hit.foot_n.x, "back foot has passed the front foot on the strike")


func test_blade_off_hand_at_the_chest() -> void:
	for atk in [-1.0, 0.34, 0.5]:
		var j := FkSkeleton.solve(1.0, "sword", {"atk": atk})
		check(j.hand_f.distance_to(j.sh + Vector2(3, 7)) < 7.0, "off hand near the chest at %s" % atk)


func test_feet_roll_heel_to_toe() -> void:
	var toe_off := 0.0
	var heel_strike := 0.0
	for i in 32:
		var ph := TAU * i / 32.0
		var j := FkSkeleton.solve(1.0, "none", {"walk": ph, "move": 1.0})
		toe_off = maxf(toe_off, j.rot_n)
		heel_strike = minf(heel_strike, j.rot_n)
		for tag in ["n", "f"]:
			for p in FkSkeleton.boot(j["foot_" + tag], j["rot_" + tag], 1.0):
				check((p as Vector2).y <= 0.05, "sole never below ground (phase %.2f)" % ph)
	check(toe_off > 0.3, "heel lifts at toe-off")
	check(heel_strike < -0.2, "toes lift at heel strike")


func test_blade_arm_straight_at_the_hit() -> void:
	# Owner: "when you slash downwards, the arm to hand is straight" — full extension at contact.
	var arm := (FkSkeleton.UPPER + FkSkeleton.FORE)
	var hit := FkSkeleton.solve(1.0, "sword", {"atk": 0.54})
	check(hit.sh_n.distance_to(hit.hand_n) > arm * 0.97, "arm locked straight at the hit")
	var wind := FkSkeleton.solve(1.0, "sword", {"atk": 0.34})
	check(wind.sh_n.distance_to(wind.hand_n) < arm * 0.8, "arm chambered (bent) at the wind-up")
	# Full range: the hand travels from above the head down to shoulder height in front.
	check(wind.hand_n.y < wind.sh.y - 8.0 and hit.hand_n.x > hit.sh.x + 18.0, "full sweep from ear to extended")
