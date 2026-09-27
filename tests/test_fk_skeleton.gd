extends TestCase
## FkSkeleton: fixed bones, IK bend sides, and the per-frame joint invariants the owner asked for.


func test_ik_keeps_bone_lengths() -> void:
	var root := Vector2(0, -28)
	for target in [Vector2(0, 0), Vector2(10, -2), Vector2(-12, 0), Vector2(3, -20), Vector2(40, 0)]:
		var end := FkSkeleton.reach(root, target, 15.0, 14.0)
		var j := FkSkeleton.ik(root, end, 15.0, 14.0, FkSkeleton.KNEE)
		check_near(root.distance_to(j), 15.0, 0.02, "thigh for %s" % target)
		check_near(j.distance_to(end), 14.0, 0.02, "shin for %s" % target)


func test_ik_bend_sides() -> void:
	var knee := FkSkeleton.ik(Vector2(0, -28), Vector2(0, 0), 15.0, 14.0, FkSkeleton.KNEE)
	check(knee.x > 0.0, "knee bends forward")
	var elbow := FkSkeleton.ik(Vector2(0, 0), Vector2(14, 0), 9.0, 8.5, FkSkeleton.ELBOW)
	check(elbow.y > 0.0, "elbow bends down")


func test_reach_clamps_far_targets() -> void:
	var end := FkSkeleton.reach(Vector2.ZERO, Vector2(100, 0), 9.0, 8.5)
	check(end.x < 17.5 and end.x > 17.4, "clamped to full extension")
	check_eq(FkSkeleton.reach(Vector2.ZERO, Vector2(5, 5), 9.0, 8.5), Vector2(5, 5), "reachable target unchanged")


const FRAMES := [[0.0, 1.0, -1.0], [1.6, 1.0, -1.0], [3.1, 1.0, -1.0], [4.7, 1.0, -1.0],
	[0.6, 0.0, -1.0], [0.6, 0.0, 0.2], [0.6, 0.0, 0.34], [0.6, 0.0, 0.45], [0.6, 0.0, 0.75], [2.0, 0.5, 0.4]]


func _each_frame(weapon: String, fn: Callable, shield := "", seated := false) -> void:
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
			# The elbow always folds to the same side of the shoulder→hand line: below a forward reach,
			# in front of an overhead one, behind a hanging one.
			var d: Vector2 = j.hand_n - j.sh_n
			check((j.elbow_n - j.sh_n.lerp(j.hand_n, 0.5)).dot(Vector2(-d.y, d.x)) >= -0.01, tag + " elbow folds the anatomical way")
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
	var j := FkSkeleton.solve(1.0, "lance", {"atk": -1.0}, "", true)
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


# --- Sword / hand axe with a shield: coil → rim cleave → lockout (owner brief 3) --------------

func _rim_y(j: Dictionary, kind: String, b: float) -> float:
	return (j.hand_f as Vector2).y - FkArmour.SHIELD_TOP[kind] * b


func test_coil_weapon_high_and_back_deep_wide_crouch() -> void:
	for w in ["sword", "axe"]:
		var j := FkSkeleton.solve(1.0, w, {"atk": 0.34}, "round")
		check(j.hand_n.y < j.sh.y - 12.0 and j.hand_n.x < j.sh.x, "%s: weapon hand raised high and pulled back above the helmet" % w)
		check(j.dir.x < 0.0 and j.dir.y < 0.0, "%s: blade points up and back" % w)
		check(j.crouch >= 4.0, "%s: deep crouch" % w)
		check(j.foot_n.x - j.foot_f.x >= 14.0, "%s: legs wide" % w)


func test_eyes_over_the_rim_for_every_shield() -> void:
	for kind in FkArmour.SHIELD_TOP:
		for atk in [-1.0, 0.34, 0.55]:
			var j := FkSkeleton.solve(1.0, "sword", {"atk": atk}, kind)
			var eye: float = j.sh.y - 10.4
			var rim := _rim_y(j, kind, 1.0)
			check(rim >= eye - 0.5 and rim <= eye + 5.0, "%s at %s: rim just under the eyes (rim %.1f, eye %.1f)" % [kind, atk, rim, eye])
			check(j.hand_f.x > j.sh.x + 6.0, "%s at %s: shield forward on the centre line" % [kind, atk])


func test_cleave_crosses_the_band_over_the_rim() -> void:
	for w in ["sword", "axe"]:
		var crossed := false
		for i in 11:
			var atk := 0.40 + i * 0.01
			var j := FkSkeleton.solve(1.0, w, {"atk": atk}, "round")
			var tip := _tip(j, FkWeapons.weapon_length(w), 1.0)
			if tip.y > -60.0 and tip.y < -38.0 and tip.x > j.hand_f.x:
				crossed = true
		check(crossed, "%s: the edge sweeps through the head-to-chest band beyond the shield" % w)


func test_lockout_arm_straight_wrist_flat_chest_to_waist() -> void:
	for w in ["sword", "axe"]:
		var j := FkSkeleton.solve(1.0, w, {"atk": 0.55}, "round")
		check(j.sh_n.distance_to(j.hand_n) > (FkSkeleton.UPPER + FkSkeleton.FORE) * 0.93, "%s: arm locked out straight" % w)
		var fore: Vector2 = (j.hand_n - j.elbow_n).normalized()
		check(absf(fore.angle_to(j.dir)) < 0.15, "%s: wrist flat with the forearm" % w)
		check(j.hand_n.y > j.sh.y + 2.0 and j.hand_n.y < j.sh.y + 16.0, "%s: locks at chest-to-waist height" % w)
		check(j.lean >= 0.3, "%s: strong diagonal line of action" % w)
		check(j.zoom > 1.05, "%s: weapon foreshortened larger at the bottom of the cut" % w)


# --- Elbow continuity and gaits (owner: "it suddenly broke the elbow"; walk-cycle briefs) -----

func test_elbows_never_snap() -> void:
	# Between frames 1% of an attack apart, an elbow moves no further than its hand and shoulder do.
	var weapons := ["sword", "axe", "spear", "halberd", "musket", "bow", "javelin", "sling", "staff", "crew", "none"]
	for w in weapons:
		for shield in ["", "round"]:
			var prev := {}
			for i in 101:
				var j := FkSkeleton.solve(1.0, w, {"atk": i / 100.0}, shield)
				if not prev.is_empty():
					for tag in ["n", "f"]:
						var jump: float = (j["elbow_" + tag] - prev["elbow_" + tag]).length() \
							- (j["hand_" + tag] - prev["hand_" + tag]).length() - (j["sh_" + tag] - prev["sh_" + tag]).length()
						check(jump < 2.0, "%s %s: %s elbow snaps at atk %.2f (%.1f px)" % [w, shield, tag, i / 100.0, jump])
				prev = j


func _walk(w: String, shield := "", n := 16) -> Array:
	var out := []
	for i in n:
		out.append(FkSkeleton.solve(1.0, w, {"walk": TAU * i / n, "move": 1.0, "t": 0.0}, shield))
	return out


func _spread(frames: Array, f: Callable) -> float:
	var vals: Array = frames.map(f)
	return vals.max() - vals.min()


func test_archer_head_stays_level() -> void:
	var fr := _walk("bow")
	check(_spread(fr, func(j): return j.sh.y) <= 0.6, "no vertical head bob")
	check(fr[0].crouch >= 3.0, "bent knees, low centre")
	check(fr[0].hand_f.y > fr[0].sh.y + 10.0, "bow held low at the side")


func test_slinger_bounces_on_the_balls_of_the_feet() -> void:
	var fr := _walk("sling")
	check(fr[4].rot_n > 0.1, "lands toe-first")
	check(_spread(fr, func(j): return -j.foot_n.y) >= 6.0, "high knee lift")
	check(fr[0].hand_n.y < fr[0].sh.y + 10.0 and fr[0].hand_f.y < fr[0].sh.y + 10.0, "sling draped between both hands at chest level")


func test_axe_thrower_heavy_stride() -> void:
	var fr := _walk("throwing_axe")
	check(_spread(fr, func(j): return j.sh.y) >= 1.2, "distinct vertical bob")
	check(absf(fr[0].hand_n.y - fr[0].hip.y) < 4.0, "axe carried low at the hip")
	check(fr.any(func(j): return j.dust_n > 0.5), "dust at heel contact")
	check(absf(fr[0].lean) < 0.03, "spine upright")


func test_spear_skirmisher_glide() -> void:
	var fr := _walk("spear")
	check(absf(fr[0].lean - 0.26) < 0.02, "torso canted forward 15 degrees")
	check(absf(fr[0].dir.angle() + 0.52) < 0.05, "spear angled up and forward 30 degrees")
	check(absf(fr[0].hand_n.y - fr[0].hip.y) < 4.0, "gripped at hip level")
	check(_spread(fr, func(j): return j.hand_f.x) >= 3.0, "off hand swings for counterbalance")


func test_rifle_patrol_low_ready() -> void:
	var fr := _walk("musket")
	check(absf(fr[0].dir.angle() - 0.785) < 0.05, "barrel 45 degrees down")
	check(_spread(fr, func(j): return (j.hand_n - j.sh).length()) <= 0.3, "rifle locked steady while the legs step")
	for j in fr:
		check((j.hand_n + j.dir * 21.0).x > j.knee_n.x, "muzzle ahead of the lead knee")


func test_shield_wall_advance() -> void:
	var fr := _walk("sword", "round")
	check(fr[0].crouch >= 3.5, "low guarded stance")
	check(_spread(fr, func(j): return j.sh.y) <= 0.5, "minimal bob")
	check(_spread(fr, func(j): return (j.hand_f - j.sh).y) <= 0.3, "shield fixed across the chest")
	check(fr[0].dir.y < -0.8, "weapon resting tip-up by the shoulder")
