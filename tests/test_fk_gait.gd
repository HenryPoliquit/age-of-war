extends TestCase
## FkGait, the walk cycle humans, golems and treants share, and the giants' and beasts' legs built on it.

const GAITS := ["golem", "treant"]


func _flex(hip: Vector2, knee: Vector2, ankle: Vector2) -> float:
	return 180.0 - absf(rad_to_deg((hip - knee).angle_to(ankle - knee)))


func test_the_foot_path_is_continuous_and_planted_in_the_stance() -> void:
	# Stance: −1 → +1 is the swing, then +1 → −1 at a steady pace; the path has no jump anywhere.
	var prev := FkGait.foot_x(0.0)
	for i in range(1, 721):
		var x := FkGait.foot_x(TAU * i / 720.0)
		check(absf(x - prev) < 0.03, "the foot path jumps at %d" % i)
		prev = x
	var a := FkGait.foot_x(PI * 0.5)
	var b := FkGait.foot_x(PI * 0.5 + 0.1)
	var c := FkGait.foot_x(PI * 1.2)
	var d := FkGait.foot_x(PI * 1.2 + 0.1)
	check_near(b - a, d - c, 1e-4, "a constant pace over the stance")
	check_near(FkGait.foot_x(PI * 0.5), 1.0, 1e-4, "lands a full stride ahead")
	check_near(FkGait.foot_x(PI * 1.5), -1.0, 1e-4, "leaves a full stride behind")


func test_the_ankle_curve_is_smooth_and_lands_flat() -> void:
	var g := {"heel": 0.05, "toe": 0.4, "clear": 0.1}
	var prev := FkGait.ankle(0.0, g)
	for i in range(1, 401):
		var pos := 2.0 * i / 400.0
		var a := FkGait.ankle(pos, g)
		check(absf(a - prev) < 0.03, "the ankle jumps at %.3f" % pos)
		prev = a
	check_near(FkGait.ankle(1.0, g), -0.05, 1e-4, "the landing angle is the gait's")
	check_near(FkGait.ankle(2.0 - 1e-6, g), 0.4, 1e-3, "the heel is fully lifted as the toe leaves")
	check_near(FkGait.ankle(1.3, g), 0.0, 1e-4, "flat in the first part of the stance")


func test_the_swing_lift_starts_and_ends_on_the_ground() -> void:
	check_near(FkGait.swing_lift(0.0), 0.0, 1e-4)
	check_near(FkGait.swing_lift(1.0), 0.0, 1e-4)
	check(FkGait.swing_lift(0.4) > 0.9, "peaks about 40% through")
	check_near(FkGait.swing_lift(1.5), 0.0, 1e-4, "no lift in the stance")


func test_each_gait_has_its_own_hip_curve() -> void:
	# (The hip range used to be cached by stride alone, so two gaits with one stride shared a curve.)
	var human := FkSkeleton.solve(1.0, "sword", {"walk": 0.0, "move": 1.0, "t": 0.0}, "round")
	var also := FkSkeleton.solve(1.0, "spear", {"walk": 0.0, "move": 1.0, "t": 0.0})
	var glide: Dictionary = FkSkeleton.GAITS["glide"]
	var heavy: Dictionary = FkSkeleton.GAITS["heavy"]
	check_near(glide.stride, heavy.stride, 1e-4, "these two share a stride")
	check(absf(also.hip.y - FkSkeleton.solve(1.0, "throwing_axe", {"walk": 0.0, "move": 1.0, "t": 0.0}).hip.y) > 0.05, "yet stand at different heights")
	check(human.hip.y != 0.0)


func test_giants_stand_on_the_ground_with_the_feet_flat_when_still() -> void:
	for kind in GAITS:
		var cfg: Dictionary = FkMachines.GIANT_GAITS[kind]
		var w := FkMachines._giant_walk(kind, 1.0, 0.0, -cfg.hip)
		for lg in w.legs:
			check_near(-(lg.ankle as Vector2).y, lg.low, 0.05, "%s: the sole is on the ground" % kind)
			check(_flex(w.hip, lg.knee, lg.ankle) < 30.0, "%s: the standing legs are nearly straight" % kind)


func test_giants_walk_with_nearly_straight_legs_and_planted_feet() -> void:
	for kind in GAITS:
		var cfg: Dictionary = FkMachines.GIANT_GAITS[kind]
		var sc := 1.3
		var rate := PI / (2.0 * float(cfg.stride) * sc)
		var span := {}
		var straightest := 999.0
		var bent := 0.0
		for i in 1600:
			var dist := i * 0.15
			var walk := rate * dist
			var w := FkMachines._giant_walk(kind, walk, 1.0, -cfg.hip)
			for j in 2:
				var lg: Dictionary = w.legs[j]
				# The sole never goes under the ground, a foot on the ground is on it.
				check(-(lg.ankle as Vector2).y >= lg.low - 0.05, "%s: the foot is never under the ground" % kind)
				var ph := walk + PI * j
				var a := fposmod(ph, TAU)
				var stance := a > PI * 0.62 and a < PI * 1.38
				if stance:
					var f := _flex(w.hip, lg.knee, lg.ankle)
					straightest = minf(straightest, f)
					var x := dist + sc * (lg.ankle as Vector2).x
					var key := "%d/%d" % [j, floori(ph / TAU)]
					var r: Vector2 = span.get(key, Vector2(x, x))
					span[key] = Vector2(minf(r.x, x), maxf(r.y, x))
				bent = maxf(bent, _flex(w.hip, lg.knee, lg.ankle))
		check(straightest < 24.0, "%s: the stance knee gets nearly straight (%.0f degrees)" % [kind, straightest])
		check(bent > 40.0, "%s: the swing knee bends (%.0f degrees)" % [kind, bent])
		check(span.size() >= 4, "%s: several stances measured" % kind)
		for key in span:
			check(span[key].y - span[key].x < 1.2, "%s: the foot on the ground slides %.2f px" % [kind, span[key].y - span[key].x])


func test_giants_rate_follows_their_stride_and_size() -> void:
	var golem := FkUnits.stride_rate({"rig": "golem"}, 1.3)
	check_near(golem, PI / (2.0 * float(FkMachines.GIANT_GAITS["golem"].stride) * 1.3), 1e-6)
	check(FkUnits.stride_rate({"rig": "golem"}, 2.6) < golem * 0.6, "drawn twice as big, it takes slower steps")
	check_near(FkUnits.stride_rate({"rig": "ram"}, 1.3, 0.11), 0.11, 1e-6, "other rigs keep their own rate")


# --- Beasts --------------------------------------------------------------------------------------

func _beast(kind: String, theta: float, mv := 1.0) -> Dictionary:
	var bp: Dictionary = FkMounts.BEASTS[kind]
	return FkQuadruped.solve(bp, {"walk": theta / FkQuadruped.cadence(bp), "move": mv, "t": 0.0})


func test_a_beast_hoof_lands_flat_and_breaks_over_at_the_end_of_the_stance() -> void:
	for kind in ["horse", "boar"]:
		var pitch_max := 0.0
		var landed_flat := true
		for i in 256:
			var j := _beast(kind, TAU * i / 256.0)
			for leg in FkQuadruped.LEGS:
				var g: Dictionary = j.legs[leg]
				pitch_max = maxf(pitch_max, g.pitch)
				var st := FkQuadruped._state(TAU * i / 256.0, leg, 20.0, 33.0)
				if st.planted and st.s < 0.65 * 0.5:
					landed_flat = landed_flat and absf(g.pitch) < 0.02
		check(pitch_max > 1.0, "%s: the hoof folds in the swing (%.2f rad)" % [kind, pitch_max])
		check(landed_flat, "%s: a planted hoof lies flat until the breakover" % kind)


func test_a_beast_hoof_pitch_never_jumps() -> void:
	for kind in ["horse", "boar", "bear"]:
		for leg in FkQuadruped.LEGS:
			var prev := 0.0
			for i in range(0, 1001):
				var j := _beast(kind, TAU * i / 1000.0)
				var p: float = j.legs[leg].pitch
				if i > 0:
					check(absf(p - prev) < 0.05, "%s %s hoof pitch jumps at %d (%.3f)" % [kind, leg, i, absf(p - prev)])
				prev = p


func test_a_beast_back_glides() -> void:
	for kind in ["horse", "boar", "stag"]:
		var prev: float = -float(_beast(kind, 0.0).c.y)
		var lo := prev
		var hi := prev
		for i in range(1, 129):
			var y := -float(_beast(kind, TAU * i / 128.0).c.y)
			check(absf(y - prev) < 0.35, "%s: the back jumps by %.2f px" % [kind, absf(y - prev)])
			prev = y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		check(hi - lo > 0.3, "%s: the back still rises and falls (%.2f px)" % [kind, hi - lo])


func test_a_beast_foreleg_gets_nearly_straight_under_its_weight() -> void:
	for kind in ["horse", "boar", "stag"]:
		var best := 999.0
		for i in 128:
			var g: Dictionary = _beast(kind, TAU * i / 128.0).legs.fn
			if g.planted:
				var p3: Dictionary = g.p3
				var f := 180.0 - rad_to_deg(((p3.top as Vector3) - (p3.mid as Vector3)).angle_to((p3.fetlock as Vector3) - (p3.mid as Vector3)))
				best = minf(best, f)
		check(best < 22.0, "%s: the knee straightens (%.0f degrees at best)" % [kind, best])
