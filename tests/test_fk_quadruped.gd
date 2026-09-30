extends TestCase
## FkQuadruped: bones keep their length in 3D, hooves plant without sliding on the screen, a four-beat walk,
## knees and hocks fold their own way, the saddle sits where riders have always sat, near and far legs
## spread with the camera.

const KINDS := ["horse", "boar", "ram", "bear"]
## The camera the game draws with (25°).
const GAME_VIEW := {"yaw": 0.4363}


func _j(kind: String, walk: float, mv := 1.0, extra := {}, view := {}) -> Dictionary:
	return FkQuadruped.solve(FkMounts.BEASTS[kind], {"walk": walk, "move": mv, "t": 0.0}.merged(extra, true), 0, view)


func test_leg_bones_keep_their_length_in_3d() -> void:
	for view in [{}, GAME_VIEW]:
		for kind in KINDS:
			var rest := _j(kind, 0.0, 0.0, {}, view)
			var frames := []
			for i in 32:
				frames.append(_j(kind, TAU * i / 32.0, 1.0, {}, view))
			frames.append(_j(kind, 1.0, 1.0, {"atk": 0.4}, view))
			frames.append(_j(kind, 0.0, 0.0, {"atk": 0.4}, view))
			for j in frames:
				for leg in FkQuadruped.LEGS:
					for pair in [["root", "top"], ["top", "mid"], ["mid", "fetlock"], ["fetlock", "hoof"]]:
						var want: float = rest.legs[leg].p3[pair[0]].distance_to(rest.legs[leg].p3[pair[1]])
						check_near(j.legs[leg].p3[pair[0]].distance_to(j.legs[leg].p3[pair[1]]), want, 0.05, "%s %s %s view %s" % [kind, leg, pair, view])


func test_planted_hooves_stay_put_on_the_ground_seen_on_the_screen() -> void:
	# The ground scrolls at the beast's speed on the screen, so a planted hoof slides back at `pace` screen px
	# per radian of walk: at any camera, whatever the camera does to the rig's x.
	for view in [{}, GAME_VIEW]:
		for kind in KINDS:
			var step := 0.01
			var prev := _j(kind, 0.0, 1.0, {}, view)
			for i in range(1, 700):
				var w := i * step
				var j := _j(kind, w, 1.0, {}, view)
				for leg in FkQuadruped.LEGS:
					var a: Dictionary = prev.legs[leg]
					var b: Dictionary = j.legs[leg]
					if a.planted and b.planted:
						check(absf(b.hoof.y) < 0.3, "%s %s planted on the ground (y %.2f)" % [kind, leg, b.hoof.y])
						var slide: float = (b.hoof.x - a.hoof.x) + FkQuadruped.PACE * step
						check(absf(slide) < 0.05, "%s %s slides %.3f px at walk %.2f, view %s" % [kind, leg, slide, w, view])
				prev = j


func test_swinging_hooves_lift() -> void:
	for kind in KINDS:
		var H: float = FkMounts.BEASTS[kind].H
		for leg in FkQuadruped.LEGS:
			var top := 0.0
			for i in 200:
				top = maxf(top, -(_j(kind, i * 0.05).legs[leg].hoof as Vector2).y)
			check(top >= 0.08 * H, "%s %s lifts %.1f px" % [kind, leg, top])


func test_four_beat_lateral_walk() -> void:
	var cad := FkQuadruped.cadence(FkMounts.BEASTS["horse"])
	var stride := TAU / cad
	var lift_off := {}
	var prev := _j("horse", 0.0)
	for i in range(1, 801):
		var w := stride * 2.0 * i / 800.0
		var j := _j("horse", w)
		for leg in FkQuadruped.LEGS:
			if prev.legs[leg].planted and not j.legs[leg].planted and not lift_off.has(leg):
				lift_off[leg] = w
		prev = j
	var order: Array = FkQuadruped.LEGS.keys()
	order.sort_custom(func(a, b): return lift_off[a] < lift_off[b])
	# Cyclic order LH → LF → RH → RF (hf → ff → hn → fn).
	var cyc := ["hf", "ff", "hn", "fn"]
	var start := cyc.find(order[0])
	for k in 4:
		check_eq(order[k], cyc[(start + k) % 4], "four-beat order")
	for k in 3:
		check_near(lift_off[order[k + 1]] - lift_off[order[k]], stride / 4.0, 0.02, "a quarter stride apart")


func test_knees_forward_hocks_back() -> void:
	for kind in KINDS:
		for i in 40:
			var j := _j(kind, i * 0.157)
			for leg in FkQuadruped.LEGS:
				var g: Dictionary = j.legs[leg]
				var side: float = (g.mid - g.top).cross(g.fetlock - g.top)
				if leg[0] == "f":
					check(side > 0.0, "%s %s knee folds forward" % [kind, leg])
				else:
					check(side < 0.0, "%s %s hock folds back" % [kind, leg])


func test_joints_never_snap() -> void:
	for kind in KINDS:
		var prev := _j(kind, 0.0)
		for i in range(1, 101):
			var j := _j(kind, TAU * i / 100.0)
			for leg in FkQuadruped.LEGS:
				for k in ["top", "mid", "fetlock", "hoof"]:
					check((j.legs[leg][k] - prev.legs[leg][k]).length() < 3.0, "%s %s %s jumps" % [kind, leg, k])
			prev = j


func test_saddle_where_riders_have_always_sat_and_bobbing_on_the_walk() -> void:
	for kind in FkMounts.BEASTS:
		var bp: Dictionary = FkMounts.BEASTS[kind]
		var j := _j(kind, 0.0, 0.0)
		var want := Vector2(-2, -bp.H - 20 - (5.0 if bp.head == "bear" else 0.0))
		check((j.saddle - want).length() < 1e-3, "%s saddle at rest (%s vs %s)" % [kind, j.saddle, want])
	var lo := INF
	var hi := -INF
	for i in 32:
		var y: float = _j("horse", TAU * i / 32.0).saddle.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	check(hi - lo > 1.0, "the saddle bobs with the back")


func test_mirrored_beast_flips_depth() -> void:
	var a := _j("horse", 1.0)
	var b := _j("horse", 1.0, 1.0, {"mirrored": true})
	for leg in FkQuadruped.LEGS:
		check_eq(b.z[leg], -a.z[leg], leg)
	check(a.z.fn > 0.0 and a.z.ff < 0.0, "right legs near, left legs far")


func test_the_camera_spreads_the_near_and_far_legs() -> void:
	# The near legs stand at z > 0 and the far ones at z < 0, so a turned camera shows them apart, by
	# 2 · z · sin(yaw); the spine, at z = 0, only foreshortens.
	var flat := _j("horse", 0.0, 0.0)
	var turned := _j("horse", 0.0, 0.0, {}, GAME_VIEW)
	var w: float = 0.3 * FkMounts.BEASTS["horse"].L
	var gap_flat: float = flat.legs.fn.hoof.x - flat.legs.ff.hoof.x
	var gap_turned: float = turned.legs.fn.hoof.x - turned.legs.ff.hoof.x
	check_near(gap_flat - gap_turned, 2.0 * w * sin(0.4363), 0.05, "the near hoof stands further back on the screen")
	check_near(turned.saddle.x, flat.saddle.x * cos(0.4363), 1e-4, "the saddle, on the spine, only foreshortens")
	check_near(turned.legs.fn.p3.hoof.x, flat.legs.fn.p3.hoof.x, 1e-3, "and the rig itself, at rest, does not move")
