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
			for bone in [["hip_n", "knee_n", FkSkeleton.THIGH], ["knee_n", "foot_n", FkSkeleton.SHIN],
					["hip_f", "knee_f", FkSkeleton.THIGH], ["knee_f", "foot_f", FkSkeleton.SHIN],
					["sh_n", "elbow_n", FkSkeleton.UPPER], ["elbow_n", "hand_n", FkSkeleton.FORE],
					["sh_f", "elbow_f", FkSkeleton.UPPER], ["elbow_f", "hand_f", FkSkeleton.FORE]]:
				# Measured in 3D: the bow's drawing arm swings toward the viewer and draws foreshortened.
				check_near(_d3(j, bone[0], bone[1]), bone[2] * b, 0.05, "%s %s-%s" % [tag, bone[0], bone[1]]))


func test_knees_forward_elbows_down_feet_grounded() -> void:
	for w in ["sword", "spear", "musket", "bow", "none"]:
		_each_frame(w, func(j: Dictionary, f: Array) -> void:
			var tag := "%s %s" % [w, f]
			# The knee lies forward (+x) of the hip→foot midpoint.
			check(j.knee_n.x >= j.hip_n.lerp(j.foot_n, 0.5).x - 0.01, tag + " near knee forward")
			check(j.knee_f.x >= j.hip_f.lerp(j.foot_f, 0.5).x - 0.01, tag + " far knee forward")
			# The elbow always folds to the same side of the shoulder→hand line: below a forward reach,
			# in front of an overhead one, behind a hanging one.
			var d: Vector2 = j.hand_n - j.sh_n
			# (The bow's drawing arm folds the other way while drawing; bend_n says which way this frame used.)
			if j.el_w == 0.0:
				check((j.elbow_n - j.sh_n.lerp(j.hand_n, 0.5)).dot(Vector2(-d.y, d.x)) * j.bend_n >= -0.01, tag + " elbow folds the pose's way")
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
			for p in FkSkeleton.boot(j["foot_" + tag], j["rot_" + tag], 1.0, j["toe_bend_" + tag]):
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
			var eye: float = j.eye.y
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


func _walk(w: String, shield := "", n := 16, view := {}) -> Array:
	var out := []
	for i in n:
		out.append(FkSkeleton.solve(1.0, w, {"walk": TAU * i / n, "move": 1.0, "t": 0.0}, shield, false, {}, view))
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
	check(fr[0].dir.y < -0.5 and fr[0].dir.x > 0.3, "weapon held up and forward, ready")
	check(fr[0].hand_n.distance_to(fr[0].head) > 14.0, "weapon hand well away from the face")
	check(fr[0].hand_n.y > fr[0].sh.y + 3.0, "shoulder and elbow relaxed: hand below the shoulder")


# --- Mounted (owner briefs: collected gait, sabre draw-cut, couched lance) ---------------------

## A rider's local y → world y on a standard horse (H 33): the rider is drawn 26 px lower.
const RIDER_Y := -26.0


func _ride(w: String, atk: float, extra := {}) -> Dictionary:
	return FkSkeleton.solve(1.0, w, {"atk": atk}.merged(extra, true), "", true)


func test_rider_head_stays_level_as_the_horse_bobs() -> void:
	var low := _ride("saber", -1.0, {"ride_bob": 0.0})
	var high := _ride("saber", -1.0, {"ride_bob": 2.0})
	check(absf((low.sh.y + 0.0) - (high.sh.y + 2.0)) < 0.3, "spine absorbs the horse's bob")


func test_rider_hips_sway_with_the_gait() -> void:
	var a := _ride("saber", -1.0, {"ride_walk": 0.4, "ride_mv": 1.0})
	var b := _ride("saber", -1.0, {"ride_walk": 2.0, "ride_mv": 1.0})
	check(absf(a.hip.x - b.hip.x) > 0.3, "hips sway in sync with the horse")


func test_reins_low_over_the_withers() -> void:
	for w in ["saber", "lance"]:
		for atk in [-1.0, 0.34, 0.5]:
			var j := _ride(w, atk)
			check((j.hand_f - j.sh).distance_to(Vector2(8, 16)) < 2.5, "%s at %s: rein hand low over the withers" % [w, atk])


func test_sabre_half_seat_draw_cut() -> void:
	var guard := _ride("saber", -1.0)
	var hit := _ride("saber", 0.55)
	check(guard.hip.y - hit.hip.y >= 3.0, "rises into a half-seat")
	check(hit.foot_n.distance_to(guard.foot_n) < 0.6, "feet stay in the stirrups")
	check(hit.rot_n < guard.rot_n - 0.05, "heels pressed deeper")
	check(hit.lean >= 0.25, "leans forward with the stride")
	check(hit.sh_n.distance_to(hit.hand_n) > (FkSkeleton.UPPER + FkSkeleton.FORE) * 0.93, "arm extended")
	check(absf((hit.hand_n - hit.elbow_n).normalized().angle_to(hit.dir)) < 0.15, "wrist locked")
	check(hit.dir.y > 0.3 and hit.dir.x > 0.3, "blade angled down and forward along the flank")
	var tip: Vector2 = hit.hand_n + hit.dir * FkWeapons.weapon_length("saber")
	check(tip.y + RIDER_Y > -60.0 and tip.y + RIDER_Y < -38.0, "cut lands head-to-chest on a foot soldier (y %.1f)" % (tip.y + RIDER_Y))


func test_lance_couched_at_chest_height() -> void:
	var guard := _ride("lance", -1.0)
	check(guard.dir.y < -0.8, "lance carried upright on the walk")
	var hit := _ride("lance", 0.55)
	var tip: Vector2 = hit.hand_n + hit.dir * 36.0
	check(tip.y + RIDER_Y > -60.0 and tip.y + RIDER_Y < -38.0, "levelled into the head-to-chest band (y %.1f)" % (tip.y + RIDER_Y))
	check(hit.lean >= 0.2, "leans into the charge")


# --- Ranged attacks (owner briefs: bow, javelin, sling, rifle) --------------------------------

func _straight(j: Dictionary, tag: String) -> bool:
	return (j["sh_" + tag] as Vector2).distance_to(j["hand_" + tag]) > (FkSkeleton.UPPER + FkSkeleton.FORE) * 0.95


func test_bow_draw_anchor_and_release() -> void:
	var pre := FkSkeleton.solve(1.0, "bow", {"atk": -1.0})
	var wind := FkSkeleton.solve(1.0, "bow", {"atk": 0.34})
	var hit := FkSkeleton.solve(1.0, "bow", {"atk": 0.54})
	for j in [pre, wind, hit]:
		check(_straight(j, "f"), "bow arm a rigid strut toward the target")
	check(pre.elbow_n.x > pre.sh_n.x + 3.0 and absf(pre.elbow_n.y - pre.sh_n.y) < 3.5, "pre-draw: elbow in front at shoulder height")
	# (With the figure's arm lengths, an elbow straight back at shoulder height puts the hand under the
	# back of the jawline.)
	check(wind.hand_n.distance_to(wind.sh + Vector2(-2.5, -5.5)) < 2.0, "full draw: hand anchored at the back of the jaw")
	check(wind.hand_n.y > wind.eye.y + 3.0, "arrow rests beneath the sighting eye")
	check(wind.elbow_n.x < wind.sh_n.x - 2.0, "full draw: elbow pulled straight back behind the archer")
	check(absf(wind.elbow_n.y - wind.sh_n.y) < 3.5, "full draw: elbow level with the shoulder")
	check(absf((wind.hand_n - wind.elbow_n).angle()) < 0.35, "full draw: forearm parallel to the arrow")
	check(hit.hand_n.x < wind.hand_n.x - 3.0, "release: the hand glides back along the neck")
	check(hit.elbow_n.x < wind.elbow_n.x - 0.5, "release: the elbow snaps further back")
	check(hit.hand_f.distance_to(wind.hand_f) < 0.6, "bow arm stays locked on target")


func test_javelin_wind_up_and_release() -> void:
	var wind := FkSkeleton.solve(1.0, "javelin", {"atk": 0.34})
	check(wind.hand_n.x < wind.sh.x - 8.0, "throwing arm drawn back behind the shoulder")
	check(wind.elbow_n.y < wind.sh_n.y, "elbow high")
	check(wind.hand_f.x > wind.sh.x + 12.0 and _straight(wind, "f"), "lead arm fully extended forward")
	check(wind.lunge < 0.0 and wind.crouch >= 2.0, "weight loaded on the bent back leg")
	var hit := FkSkeleton.solve(1.0, "javelin", {"atk": 0.5})
	check(hit.hand_n.x > hit.sh.x + 12.0 and hit.hand_n.y < hit.sh.y, "whips forward at head height")
	check(_straight(FkSkeleton.solve(1.0, "javelin", {"atk": 0.55}), "n"), "follow-through: the whole arm straight")


func test_sling_aim_whip_release() -> void:
	var guard := FkSkeleton.solve(1.0, "sling", {"atk": -1.0})
	check(guard.hand_f.x > guard.sh.x + 12.0, "lead hand holds the pouch forward")
	check(guard.hand_n.distance_to(guard.sh + Vector2(-1, -9)) < 3.0, "dominant hand back by the ear")
	var wind := FkSkeleton.solve(1.0, "sling", {"atk": 0.3})
	check(wind.hand_n.y < wind.sh.y - 13.0, "overhead whip")
	var hit := FkSkeleton.solve(1.0, "sling", {"atk": 0.5})
	check(hit.hand_n.x > hit.sh.x + 10.0 and hit.hand_n.y < hit.sh.y - 6.0, "snaps forward at peak height")
	check(hit.hand_f.x < hit.sh.x + 3.0, "lead arm tucks to the ribs")


func test_rifle_shouldered_at_eye_height_with_recoil() -> void:
	var guard := FkSkeleton.solve(1.0, "musket", {"atk": -1.0})
	var kick0 := FkSkeleton.solve(1.0, "musket", {"atk": 0.5})
	for j in [guard, kick0]:
		var butt: Vector2 = j.hand_n + FkWeapons.GUN_BUTT.rotated(j.dir.angle())
		check(butt.distance_to(j.sh_n) < 2.5, "butt of the stock rests in the shoulder")
		var muzzle: Vector2 = butt + Vector2(34, -2).rotated(j.dir.angle())
		check(absf(muzzle.y - butt.y) < 4.0 and muzzle.y > j.eye.y, "gun level, under the sighting eye")
		check(j.hand_f.distance_to(butt) > 12.0, "support hand out on the forend")
	check(guard.elbow_f.y > guard.hand_f.y + 2.0, "support elbow tucked beneath the forend")
	check(guard.lean >= 0.08 and guard.crouch >= 1.5, "aggressive lean, soft knees")
	var kick := FkSkeleton.solve(1.0, "musket", {"atk": 0.5})
	check(guard.hand_n.x - kick.hand_n.x >= 2.0, "straight rearward recoil")
	var settle := FkSkeleton.solve(1.0, "musket", {"atk": 0.95})
	check(settle.hand_n.distance_to(guard.hand_n) < 1.0, "recovers onto the aim")


func test_archer_walk_relaxed_carriage() -> void:
	var fr := _walk("bow")
	var reach := FkSkeleton.UPPER + FkSkeleton.FORE
	for j in fr:
		var bow_arm: float = j.sh_f.distance_to(j.hand_f)
		check(bow_arm < reach * 0.95 and bow_arm > reach * 0.75, "bow arm's elbow soft, not locked or cramped")
		var u: Vector2 = j.sh_n - j.elbow_n
		var f: Vector2 = j.hand_n - j.elbow_n
		var ang := rad_to_deg(absf(u.angle_to(f)))
		check(ang > 80.0 and ang < 125.0, "drawing arm bent comfortably, ~100 degrees (got %.0f)" % ang)
	check(_spread(fr, func(j): return j.hand_n.x) >= 3.0, "drawing arm swings with the counter-stride")


func test_archer_elbow_switch_is_continuous() -> void:
	# Walking (elbow folds back) → standing at the pre-draw (elbow up and behind): the arm straightens
	# through the switch instead of snapping across.
	var prev := {}
	for i in 51:
		var j := FkSkeleton.solve(1.0, "bow", {"walk": 0.7, "move": 1.0 - i / 50.0})
		if not prev.is_empty():
			var jump: float = (j.elbow_n - prev.elbow_n).length() - (j.hand_n - prev.hand_n).length() - (j.sh_n - prev.sh_n).length()
			check(jump < 2.0, "no elbow snap at move %.2f (%.1f px)" % [1.0 - i / 50.0, jump])
		prev = j


func test_bow_draw_elbow_travels_level_not_over_the_shoulder() -> void:
	# The drawing elbow swings back around the side: at shoulder height the whole way, moving steadily back.
	var prev_x := INF
	for i in 36:
		var j := FkSkeleton.solve(1.0, "bow", {"atk": i / 100.0})
		check(j.elbow_n.y >= j.sh_n.y - 3.5, "elbow never rises over the shoulder (atk %.2f)" % (i / 100.0))
		check(j.elbow_n.x <= prev_x + 0.05, "elbow moves steadily back (atk %.2f)" % (i / 100.0))
		prev_x = j.elbow_n.x


# --- Body rig (spec 2026-09-27-humanoid-body-rig-design) ---------------------------------------

const DWARF := {"body": Vector2(1.24, 0.76), "head": 1.1}
const ELF := {"body": Vector2(0.9, 1.1), "head": 0.93}
const GOLDEN_KEYS := ["hip", "sh", "sh_n", "sh_f", "elbow_n", "elbow_f", "hand_n", "hand_f", "knee_n", "knee_f", "foot_n",
	"foot_f", "rot_n", "rot_f", "dir", "lean", "lunge", "crouch", "zoom", "el_w"]


## Joint-to-joint distance in (x, y, z).
func _d3(j: Dictionary, a: String, c: String) -> float:
	var z: Dictionary = j.z
	return Vector3(j[a].x, j[a].y, z[a]).distance_to(Vector3(j[c].x, j[c].y, z[c]))


func test_default_look_matches_the_pre_rig_skeleton() -> void:
	var rows: Array = str_to_var(FileAccess.get_file_as_string("res://tests/fk_golden.txt"))
	check_eq(rows.size(), 720, "golden loaded")
	for row in rows:
		var j := FkSkeleton.solve(1.1, row.w, row.pose, row.shield, row.seated)
		for k in GOLDEN_KEYS:
			# A steered elbow (the bow draw) is now pulled within reach of both bones; its lengths are
			# checked in 3D instead.
			if k == "elbow_n" and row.el_w > 0.0:
				continue
			var d: float = (j[k] - row[k]).length() if row[k] is Vector2 else absf(j[k] - row[k])
			if d > 1e-3:
				check(false, "%s %s seated=%s atk=%.1f: %s moved %.4f" % [row.w, row.shield, row.seated, row.pose.atk, k, d])


func test_bones_keep_their_length_in_3d_for_every_race() -> void:
	var b := 1.16
	for lk in [{}, DWARF, ELF]:
		var body: Vector2 = lk.get("body", Vector2.ONE)
		var hb: float = b * lk.get("head", 1.0)
		var by: float = b * body.y
		for w in ["sword", "spear", "musket", "bow", "javelin", "sling", "none"]:
			for f in FRAMES:
				var j := FkSkeleton.solve(b, w, {"walk": f[0], "move": f[1], "atk": f[2]}, "", false, lk)
				var foot := (FkSkeleton.BALL * body * b).length()
				for bone in [["hip_n", "knee_n", FkSkeleton.THIGH * by], ["knee_n", "foot_n", FkSkeleton.SHIN * by],
						["hip_f", "knee_f", FkSkeleton.THIGH * by], ["knee_f", "foot_f", FkSkeleton.SHIN * by],
						["sh_n", "elbow_n", FkSkeleton.UPPER * b], ["elbow_n", "hand_n", FkSkeleton.FORE * b],
						["sh_f", "elbow_f", FkSkeleton.UPPER * b], ["elbow_f", "hand_f", FkSkeleton.FORE * b],
						["foot_n", "toe_n", foot], ["foot_f", "toe_f", foot],
						["hip", "sh", Vector2(1.5, -FkSkeleton.SPINE * body.y).length() * b],
						["sh", "neck", Vector2(0.8, -3.5).length() * hb], ["neck", "head", Vector2(1.0, -6.0).length() * hb],
						["hip", "hip_n", j.w], ["hip", "hip_f", j.w]]:
					check_near(_d3(j, bone[0], bone[1]), bone[2], 0.05, "%s %s %s: %s-%s" % [lk, w, f, bone[0], bone[1]])


func test_rider_sits_on_the_saddle_whatever_the_race() -> void:
	var human := FkSkeleton.solve(1.0, "saber", {"atk": -1.0}, "", true)
	var dwarf := FkSkeleton.solve(1.0, "saber", {"atk": -1.0}, "", true, DWARF)
	check_near(dwarf.hip.y, human.hip.y, 1e-4, "seat height is the saddle's, not the race's")
	check(dwarf.foot_n.y < human.foot_n.y - 2.0, "a dwarf's shorter legs hang higher in the stirrup")


func test_race_height_lives_in_the_legs() -> void:
	var human := FkSkeleton.solve(1.0, "none", {"atk": -1.0})
	var dwarf := FkSkeleton.solve(1.0, "none", {"atk": -1.0}, "", false, DWARF)
	check_near(dwarf.hip.y, human.hip.y * 0.76, 0.3, "dwarf hips stand at 0.76 of human height")
	var sole: float = FkSkeleton.boot(dwarf.foot_n, dwarf.rot_n, 1.0, 0.0, DWARF.body).map(func(q): return q.y).max()
	check_near(sole, 0.0, 0.05, "boot sole still on the ground")


func test_depth_near_side_toward_the_viewer() -> void:
	var j := FkSkeleton.solve(1.0, "sword", {"atk": -1.0})
	check(j.z.sh_n > 0.0 and j.z.sh_f < 0.0, "near shoulder toward the viewer, far shoulder away")
	check(j.z.hip_n > 0.0 and j.z.hip_f < 0.0, "near hip toward the viewer, far hip away")
	check_eq(j.z.hand_n, j.z.sh_n, "the hand stays in its shoulder's plane")
	check(j.z.elbow_n > j.z.sh_n, "the elbow swings out toward the viewer, never behind the shoulder")
	check_eq(j.z.hand_n, j.z.sh_n, "…hand too")


func test_bow_elbow_swings_toward_the_viewer_mid_draw() -> void:
	var peak := 0.0
	for i in 36:
		var j := FkSkeleton.solve(1.0, "bow", {"atk": i / 100.0})
		peak = maxf(peak, j.z.elbow_n - j.z.sh_n)
	check(peak > 4.0, "mid-draw the upper arm points at the viewer (peak depth %.1f)" % peak)


func test_head_rides_the_neck_and_stays_level() -> void:
	var idle := FkSkeleton.solve(1.0, "none", {"atk": -1.0})
	check((idle.head - (idle.sh + Vector2(1.8, -9.5))).length() < 1e-3, "upright head where it always was")
	check((idle.eye - (idle.sh + Vector2(5.2, -10.4))).length() < 1e-3, "upright eye where it always was")
	for w in ["sword", "axe", "spear", "musket", "bow", "javelin", "sling", "saber"]:
		for atk in [-1.0, 0.2, 0.34, 0.45, 0.55, 0.8]:
			var j := FkSkeleton.solve(1.0, w, {"atk": atk}, "round" if w == "sword" else "")
			check(absf(j.head_tilt) < 0.1, "%s at %s: head level (tilt %.2f)" % [w, atk, j.head_tilt])
	var hit := FkSkeleton.solve(1.0, "sword", {"atk": 0.55}, "round")
	check(hit.head.x > hit.sh.x + 1.8, "the head follows a strong lean a little")


func test_sockets_sit_on_the_hands_and_back() -> void:
	var j := FkSkeleton.solve(1.0, "spear", {"atk": 0.5})
	check_eq(j.sockets.grip_n.p, j.hand_n)
	check_near(j.sockets.grip_n.a, j.dir.angle(), 1e-5)
	check_eq(j.sockets.grip_n.z, j.z.hand_n)
	check_eq(j.sockets.grip_f.p, j.hand_f)
	check_eq(j.sockets.back.p, j.chest)


func test_toe_stays_down_as_the_heel_lifts() -> void:
	var best := {}
	for i in 64:
		var j := FkSkeleton.solve(1.0, "none", {"walk": TAU * i / 64.0, "move": 1.0})
		if best.is_empty() or j.rot_n > best.rot_n:
			best = j
	var pts := FkSkeleton.boot(best.foot_n, best.rot_n, 1.0, best.toe_bend_n)
	check_near(best.toe_bend_n, best.rot_n, 0.02, "toe cap lies flat at push-off")
	check(absf((pts[4] as Vector2).y) < 0.1, "toe tip on the ground (y %.2f)" % (pts[4] as Vector2).y)
	check((pts[5] as Vector2).y < -2.0, "heel lifted (y %.2f)" % (pts[5] as Vector2).y)
	for i in 64:
		var j := FkSkeleton.solve(1.0, "none", {"walk": TAU * i / 64.0, "move": 1.0})
		check(j.toe_bend_n >= 0.0 and j.toe_bend_n <= maxf(j.rot_n, 0.0) + 1e-5, "bend only while the heel is up (phase %d)" % i)


func _corr(a: Array, c: Array) -> float:
	var ma := 0.0
	var mc := 0.0
	for i in a.size():
		ma += a[i] / a.size()
		mc += c[i] / c.size()
	var sab := 0.0
	var saa := 0.0
	var scc := 0.0
	for i in a.size():
		sab += (a[i] - ma) * (c[i] - mc)
		saa += (a[i] - ma) * (a[i] - ma)
		scc += (c[i] - mc) * (c[i] - mc)
	return sab / sqrt(saa * scc) if saa > 0.0 and scc > 0.0 else 0.0


func test_walk_counter_rotates_chest_against_pelvis() -> void:
	var fr := _walk("none", "", 32)
	var foot: Array = fr.map(func(j): return j.foot_n.x)
	check(_corr(fr.map(func(j): return (j.hip_n - j.hip).x), foot) > 0.5, "near hip rides forward with its foot")
	check(_corr(fr.map(func(j): return (j.sh_n - j.sh).x), foot) < -0.5, "near shoulder swings back against it")
	check(_spread(fr, func(j): return (j.sh_n - j.sh).x) > 1.5, "the shoulder's travel reads")
	for g in FkSkeleton.GAITS:
		check(FkSkeleton.GAITS[g].has("twist"), "%s has a twist" % g)


func test_steady_gaits_barely_twist() -> void:
	for w in ["bow", "musket"]:
		check(_spread(_walk(w), func(j): return (j.sh_n - j.sh).x) < 1.0, "%s: carriage stays steady" % w)
	check(_spread(_walk("sword", "round"), func(j): return (j.sh_n - j.sh).x) < 1.0, "shield wall: steady")


func test_head_level_while_walking() -> void:
	for w in ["none", "spear", "throwing_axe", "sling", "bow", "musket", "sword"]:
		for j in _walk(w, "round" if w == "sword" else ""):
			check(absf(j.head_tilt) < 0.1, "%s: head level on the march" % w)


# --- Shield turn (owner: shields face the camera while the body is side-on) --------------------

## The camera the game draws with (25°): the shield yaws are authored to read 0.5 and 0.8 wide from it.
const GAME_VIEW := {"yaw": 0.4363}


func test_shield_turns_open_on_the_strike() -> void:
	var turn := func(atk: float) -> float: return FkSkeleton.solve(1.0, "sword", {"atk": atk}, "round", false, {}, GAME_VIEW).shield.width
	check_near(turn.call(-1.0), 0.5, 1e-3, "braced at a three-quarter turn on guard")
	check_near(turn.call(0.34), 0.5, 0.02, "still braced through the coil")
	check(turn.call(0.55) > 0.7, "swings open as the cut comes over the rim (%.2f)" % turn.call(0.55))
	check(absf(turn.call(0.99) - 0.5) < 0.05, "back to the brace by the end of the recovery")
	for i in 100:
		check(absf(turn.call((i + 1) / 100.0) - turn.call(i / 100.0)) < 0.1, "no snap at atk %.2f" % (i / 100.0))


func test_shield_braced_on_the_march_and_for_spears() -> void:
	for j in _walk("sword", "round", 16, GAME_VIEW):
		check_near(j.shield.width, 0.5, 1e-3, "shield wall march")
	for atk in [-1.0, 0.34, 0.5]:
		check_near(FkSkeleton.solve(1.0, "spear", {"atk": atk}, "round", false, {}, GAME_VIEW).shield.width, 0.5, 1e-3, "spear and shield at %s" % atk)


func test_shield_plate_shows_as_wide_as_the_camera_sees_it() -> void:
	for yaw in [0.0, 0.2618, 0.4363]:
		for atk in [-1.0, 0.2, 0.34, 0.45, 0.55, 0.8]:
			var j := FkSkeleton.solve(1.0, "sword", {"atk": atk}, "round", false, {}, {"yaw": yaw})
			check_near(j.shield.width, absf(sin(j.shield.yaw - yaw)), 1e-5, "width at camera %.2f, atk %.1f" % [yaw, atk])
			check(j.shield.width > 0.1 and j.shield.width <= 1.0, "never edge-on or past full at camera %.2f, atk %.1f" % [yaw, atk])
	check(not FkSkeleton.solve(1.0, "sword", {"atk": -1.0}).has("shield"), "no shield, no plate")


func test_shield_shows_its_back_to_our_army_and_its_face_to_the_mirrored_one() -> void:
	for yaw in [0.0, 0.2618, 0.4363]:
		for atk in [-1.0, 0.34, 0.55, 0.9]:
			var ours := FkSkeleton.solve(1.0, "sword", {"atk": atk}, "round", false, {}, {"yaw": yaw})
			var theirs := FkSkeleton.solve(1.0, "sword", {"atk": atk, "mirrored": true}, "round", false, {}, {"yaw": yaw})
			check(ours.shield.back and not theirs.shield.back, "back for ours, face for theirs, camera %.2f atk %.1f" % [yaw, atk])
			check_eq(ours.shield.width, theirs.shield.width, "the same width either way")


func test_raised_sword_arm_swings_its_elbow_out() -> void:
	# The wind-up puts the elbow out toward the viewer instead of folding the arm over itself in the picture.
	for spec in [["sword", ""], ["sword", "round"], ["axe", ""], ["axe", "round"]]:
		var wind := FkSkeleton.solve(1.0, spec[0], {"atk": 0.34}, spec[1])
		var tag := "%s %s" % spec
		check(wind.z.elbow_n > wind.z.sh_n + 2.5, tag + ": the elbow stands out toward the viewer (%.1f)" % (wind.z.elbow_n - wind.z.sh_n))
		check_near(wind.z.hand_n, wind.z.sh_n, 1e-4, tag + ": the hand stays in the shoulder's plane")
		check(wind.sh_n.distance_to(wind.elbow_n) < FkSkeleton.UPPER * 0.95, tag + ": the upper arm foreshortens on screen")
	var coil := FkSkeleton.solve(1.0, "sword", {"atk": -1.0}, "round")
	check(coil.z.elbow_n > coil.z.sh_n + 2.5, "the shield family's coiled guard has its elbow out too")


func test_marching_and_striking_arms_stay_in_their_plane() -> void:
	# The approved shield-wall march and the locked-out strike are as they were: only the raised arm swings out.
	for j in _walk("sword", "round"):
		check_near(j.z.elbow_n, j.z.sh_n, 1e-3, "shield wall march keeps the elbow in the plane")
	for w in ["sword", "axe"]:
		for shield in ["", "round"]:
			var hit := FkSkeleton.solve(1.0, w, {"atk": 0.55}, shield)
			check_near(hit.z.elbow_n, hit.z.sh_n, 1e-3, "%s %s: the strike is in the plane" % [w, shield])


func test_elbows_never_snap_in_3d() -> void:
	for w in ["sword", "axe"]:
		for shield in ["", "round"]:
			var prev := {}
			for i in 101:
				var j := FkSkeleton.solve(1.0, w, {"atk": i / 100.0}, shield)
				if not prev.is_empty():
					var jump: float = (j.p3.elbow_n - prev.p3.elbow_n).length() - (j.p3.hand_n - prev.p3.hand_n).length() - (j.p3.sh_n - prev.p3.sh_n).length()
					check(jump < 2.0, "%s %s: elbow snaps in 3D at atk %.2f (%.1f px)" % [w, shield, i / 100.0, jump])
				prev = j


# --- Refinements (owner, 2026-09-28) ------------------------------------------------------------

func test_lance_arm_locks_straight_on_the_thrust() -> void:
	var hit := _ride("lance", 0.55)
	check(hit.sh_n.distance_to(hit.hand_n) > (FkSkeleton.UPPER + FkSkeleton.FORE) * 0.97, "full extension at the end of the thrust")


func test_bow_full_draw_has_range() -> void:
	# Owner: "the pull lacks weight" — at least 2 px longer than the old anchor under the jaw (13.8 px).
	var wind := FkSkeleton.solve(1.0, "bow", {"atk": 0.34})
	check(wind.hand_f.x - wind.hand_n.x >= 16.0, "draw length %.1f px" % (wind.hand_f.x - wind.hand_n.x))


func test_staff_raised_one_handed_straight_at_30_degrees() -> void:
	var hit := FkSkeleton.solve(1.0, "staff", {"atk": 0.55})
	var arm: Vector2 = hit.hand_n - hit.sh_n
	check(arm.length() > (FkSkeleton.UPPER + FkSkeleton.FORE) * 0.97, "arm, elbow and hand in one straight line")
	check(absf(rad_to_deg(arm.angle()) + 30.0) < 8.0, "raised about 30 degrees (got %.0f)" % rad_to_deg(-arm.angle()))
	# The staff runs from 22 px behind the hand to its head (FkWeapons "staff").
	var butt: Vector2 = hit.hand_n - hit.dir * 22.0
	var near := Geometry2D.get_closest_point_to_segment(hit.hand_f, butt, hit.hand_n)
	check(near.distance_to(hit.hand_f) > 6.0, "the other hand has let go of the staff")


## Every weapon the rig knows, plus none; the p3 tests run this whole roster.
func _all_weapons() -> Array:
	var out: Array = FkSkeleton.FAMILY.keys()
	out.append("none")
	return out


## Camera angles the projection tests run at: square-on, and turned 15° and 25° toward the side the figure faces.
const VIEWS := [{}, {"yaw": 0.2618}, {"yaw": 0.4363}]


## `fn(j, look, tag)` for every weapon, race, frame, and (no shield / a shield / a rider) combination.
func _each_p3_frame(fn: Callable, view := {}) -> void:
	for lk in [{}, DWARF, ELF]:
		for w in _all_weapons():
			for f in FRAMES:
				for opt in [["", false], ["round", false], ["", true]]:
					var j := FkSkeleton.solve(1.16, w, {"walk": f[0], "move": f[1], "atk": f[2]}, opt[0], opt[1], lk, view)
					fn.call(j, lk, "%s %s %s shield=%s seated=%s view=%s" % [lk.get("body", "human"), w, f, opt[0], opt[1], view])


func test_flat_keys_and_z_are_read_off_p3() -> void:
	var want := ["hip", "chest", "sh", "neck", "head", "eye", "sh_n", "sh_f", "elbow_n", "elbow_f", "hand_n", "hand_f",
		"hip_n", "hip_f", "knee_n", "knee_f", "foot_n", "foot_f", "toe_n", "toe_f"]
	want.sort()
	for view in VIEWS:
		_each_p3_frame(func(j: Dictionary, _lk: Dictionary, tag: String) -> void:
			var p3: Dictionary = j.p3
			var have := p3.keys()
			have.sort()
			check_eq(have, want, "p3 holds every joint: " + tag)
			for k in p3:
				check_eq(j[k], FkRig.project(p3[k], view), "%s is the projection of p3: %s" % [k, tag])
				check_eq(j.z[k], (p3[k] as Vector3).z, "%s z is p3's z, whatever the camera: %s" % [k, tag]), view)


func test_the_camera_moves_the_picture_not_the_rig() -> void:
	# p3 is rig space: turning the camera must not move a single joint.
	for lk in [{}, DWARF, ELF]:
		for w in ["sword", "spear", "bow", "musket", "javelin", "none"]:
			for f in FRAMES:
				var pose := {"walk": f[0], "move": f[1], "atk": f[2]}
				var flat := FkSkeleton.solve(1.1, w, pose, "round", false, lk)
				for view in VIEWS:
					var turned := FkSkeleton.solve(1.1, w, pose, "round", false, lk, view)
					for k in flat.p3:
						check_eq(turned.p3[k], flat.p3[k], "%s %s %s: %s in rig space, view %s" % [lk.get("body", "human"), w, f, k, view])
	var a := FkSkeleton.solve(1.0, "sword", {"atk": 0.5})
	var c := FkSkeleton.solve(1.0, "sword", {"atk": 0.5}, "", false, {}, {"yaw": 0.0})
	for k in a:
		if k != "p3" and k != "z" and k != "sockets":
			check_eq(c[k], a[k], "an explicit yaw of 0 is the same figure: " + k)


func test_camera_yaw_spreads_the_near_and_far_sides() -> void:
	var flat := FkSkeleton.solve(1.0, "none", {"atk": -1.0})
	var turned := FkSkeleton.solve(1.0, "none", {"atk": -1.0}, "", false, {}, {"yaw": deg_to_rad(20.0)})
	# Near side (z > 0) toward the rear, far side toward the front, by z · sin(yaw); the middle stays.
	check_near(flat.sh_n.x - turned.sh_n.x, flat.z.sh_n * sin(deg_to_rad(20.0)) + flat.sh_n.x * (1.0 - cos(deg_to_rad(20.0))), 1e-4, "near shoulder")
	check(turned.sh_f.x > flat.sh_f.x - 0.5 and turned.sh_n.x < flat.sh_n.x, "far shoulder forward, near shoulder back")
	check(turned.hip_f.x - turned.hip_n.x > flat.hip_f.x - flat.hip_n.x + 2.0, "the hips spread apart on screen")
	check_near(turned.hip.x, flat.hip.x * cos(deg_to_rad(20.0)), 1e-4, "the spine, at z = 0, only foreshortens")


func test_weapon_direction_is_the_projected_direction() -> void:
	for w in ["sword", "spear", "axe"]:
		for atk in [-1.0, 0.2, 0.34, 0.5, 0.75]:
			var flat := FkSkeleton.solve(1.0, w, {"atk": atk})
			var turned := FkSkeleton.solve(1.0, w, {"atk": atk}, "", false, {}, {"yaw": 0.4363})
			check_near(turned.dir.length(), 1.0, 1e-5, "%s %.2f: still a unit direction" % [w, atk])
			check(turned.dir.dot(FkRig.project_dir(Vector3(flat.dir.x, flat.dir.y, 0.0), {"yaw": 0.4363})) > 0.999, "%s %.2f: the flat direction, projected" % [w, atk])


func test_p3_bones_keep_their_exact_length() -> void:
	var b := 1.16
	_each_p3_frame(func(j: Dictionary, lk: Dictionary, tag: String) -> void:
		var body: Vector2 = lk.get("body", Vector2.ONE)
		var hb: float = b * lk.get("head", 1.0)
		var by := b * body.y
		var p3: Dictionary = j.p3
		for bone in [["hip_n", "knee_n", FkSkeleton.THIGH * by], ["knee_n", "foot_n", FkSkeleton.SHIN * by],
				["hip_f", "knee_f", FkSkeleton.THIGH * by], ["knee_f", "foot_f", FkSkeleton.SHIN * by],
				["sh_n", "elbow_n", FkSkeleton.UPPER * b], ["elbow_n", "hand_n", FkSkeleton.FORE * b],
				["sh_f", "elbow_f", FkSkeleton.UPPER * b], ["elbow_f", "hand_f", FkSkeleton.FORE * b],
				["foot_n", "toe_n", (FkSkeleton.BALL * body * b).length()], ["foot_f", "toe_f", (FkSkeleton.BALL * body * b).length()],
				["hip", "sh", Vector2(1.5, -FkSkeleton.SPINE * body.y).length() * b],
				["sh", "neck", Vector2(0.8, -3.5).length() * hb], ["neck", "head", Vector2(1.0, -6.0).length() * hb],
				["head", "eye", Vector2(3.4, -0.9).length() * hb],
				["hip", "hip_n", j.w], ["hip", "hip_f", j.w]]:
			var d: float = (p3[bone[0]] as Vector3).distance_to(p3[bone[1]])
			check_near(d, bone[2], 0.05, "%s: %s-%s" % [tag, bone[0], bone[1]]))


func _shaft_offset(j: Dictionary) -> float:
	return absf(((j.hand_f as Vector2) - (j.hand_n as Vector2)).cross(j.dir))


func test_two_handed_grip_puts_the_far_hand_on_the_shaft_from_the_game_camera() -> void:
	# Each hand used to be drawn in its own shoulder's plane, a shoulder-width apart: seen from 25° the far hand
	# stood off a vertical shaft by up to 3.4 px. Both hands now grip the shaft on the centreline.
	for atk in [-1.0, 0.2, 0.34, 0.45, 0.55]:
		check(_shaft_offset(FkSkeleton.solve(1.0, "spear", {"atk": atk}, "", false, {}, GAME_VIEW)) < 0.1, "spear grip at atk %.2f" % atk)
	for atk in [0.2, 0.34, 0.45, 0.55]:
		check(_shaft_offset(FkSkeleton.solve(1.0, "halberd", {"atk": atk}, "", false, {}, GAME_VIEW)) < 0.1, "halberd grip at atk %.2f" % atk)
	check(_shaft_offset(FkSkeleton.solve(1.0, "halberd", {"atk": -1.0}, "", false, {}, GAME_VIEW)) < 1.6, "halberd carried upright")
	for atk in [-1.0, 0.2, 0.34]:
		check(_shaft_offset(FkSkeleton.solve(1.0, "staff", {"atk": atk}, "", false, {}, GAME_VIEW)) < 0.6, "staff in both hands at atk %.2f" % atk)


func test_the_grip_is_left_alone_when_a_hand_is_not_on_the_shaft() -> void:
	var held := FkSkeleton.solve(1.0, "spear", {"atk": -1.0}, "round")
	check_near(held.z.hand_n, held.z.sh_n, 1e-3, "a spear held in one hand with a shield stays in its shoulder's plane")
	for j in _walk("spear"):
		check_near(j.z.hand_f, j.z.sh_f, 1e-3, "the skirmisher's free off hand swings in its own plane")
	var hit := FkSkeleton.solve(1.0, "staff", {"atk": 0.55})
	check_near(hit.z.hand_n, hit.z.sh_n, 1e-3, "the staff raised in one hand is in its shoulder's plane")


func test_every_bent_arm_swings_out_toward_the_viewer_never_away() -> void:
	# The elbow's default swing is toward the viewer; no arm folds toward the far side (the bow's steered elbow aside).
	for w in FkSkeleton.FAMILY.keys():
		_each_frame(w, func(j: Dictionary, f: Array) -> void:
			if j.el_w == 0.0:
				check(j.z.elbow_n >= minf(j.z.sh_n, j.z.hand_n) - 1e-3, "%s %s: the elbow is not behind its arm" % [w, f]))
	var idle := FkSkeleton.solve(1.0, "none", {"atk": -1.0})
	check(idle.z.elbow_n > idle.z.sh_n + 1.0, "even a hanging arm's elbow stands a little out (%.1f)" % (idle.z.elbow_n - idle.z.sh_n))
