extends TestCase
## Arch: the 3D architecture helpers. Faces are planes seen through the units' camera, so a wall's front, its
## lane-facing end and a door's recess all follow FkRig's projection.

const YAW := 0.4363


func test_front_plane_is_the_camera_projection_of_that_plane() -> void:
	for y in [0.0, 0.2618, YAW]:
		Arch.yaw = y
		for zf in [0.0, 14.0, -9.0]:
			for p in [Vector2(-30, -40), Vector2(12, -3), Vector2(0, 0)]:
				var want := FkRig.project(Vector3(p.x, p.y, zf), {"yaw": y})
				check((Arch.front_plane(zf) * p).distance_to(want) < 1e-4, "front plane z=%.0f yaw %.2f point %s" % [zf, y, p])
	Arch.yaw = 0.0


func test_side_plane_maps_depth_from_the_front_edge_to_screen_x() -> void:
	for y in [0.0, 0.2618, YAW]:
		Arch.yaw = y
		var xr := -60.0
		var zf := 20.0
		for u in [0.0, 12.0, 48.0]:
			# u runs from the front edge (z = zf) toward the back (z = zf - u).
			var want := FkRig.project(Vector3(xr, -30.0, zf - u), {"yaw": y})
			check((Arch.side_plane(xr, zf) * Vector2(u, -30.0)).distance_to(want) < 1e-4, "side plane u=%.0f yaw %.2f" % [u, y])
	Arch.yaw = 0.0


func test_a_wall_end_is_as_wide_as_its_depth_times_sin_yaw() -> void:
	Arch.yaw = YAW
	var w := (Arch.side_plane(0.0, 22.0) * Vector2(44.0, 0.0)).x - (Arch.side_plane(0.0, 22.0) * Vector2(0.0, 0.0)).x
	check_near(w, 44.0 * sin(YAW), 1e-4, "the lane-facing end of a 44-deep wall")
	Arch.yaw = 0.0
	var flat := (Arch.side_plane(0.0, 22.0) * Vector2(44.0, 0.0)).x - (Arch.side_plane(0.0, 22.0) * Vector2(0.0, 0.0)).x
	check_near(flat, 0.0, 1e-6, "seen square-on a wall's end has no width")


func test_recess_jamb_is_the_depth_times_sin_yaw() -> void:
	Arch.yaw = YAW
	check_near(Arch.jamb_width(14.0), 14.0 * sin(YAW), 1e-5, "the visible side of a 14-deep opening")
	Arch.yaw = 0.0
	check_near(Arch.jamb_width(14.0), 0.0, 1e-9, "no jamb square-on")


func test_cylinder_keeps_its_width_at_every_camera() -> void:
	# A vertical cylinder is as wide from any side.
	for y in [0.0, 0.2618, YAW]:
		Arch.yaw = y
		check_near(Arch.cylinder_x(30.0, 10.0) - Arch.cylinder_x(30.0, 10.0), 0.0, 1e-9, "centre is a point")
		check_near(Arch.cylinder_x(30.0, 10.0), 30.0 * cos(y) - 10.0 * sin(y), 1e-5, "centre projects like a point")
	Arch.yaw = 0.0


func test_pyramid_shows_a_front_slope_and_a_lane_facing_slope_when_the_camera_is_turned() -> void:
	Arch.yaw = YAW
	var f := Arch.pyramid_faces(-142.0, -54.0, -46.0, 14.0, -244.0, -300.0)
	check_eq(f.size(), 2, "front slope and lane-facing slope")
	var apex: Vector2 = f[0][2]
	check_near(apex.x, Arch.cylinder_x(-98.0, -16.0), 1e-4, "the apex over the middle of the footprint")
	check_eq(apex.y, -300.0, "at its height")
	Arch.yaw = 0.0
	var flat := Arch.pyramid_faces(-142.0, -54.0, -46.0, 14.0, -244.0, -300.0)
	check_eq(flat.size(), 1, "square-on only the front slope shows")


func test_recess_shows_a_jamb_only_from_a_turned_camera() -> void:
	var opening := Arch.rect_pts(-48.0, -80.0, 0.0, 0.0)
	Arch.yaw = YAW
	var r := Arch.recess_polys(opening, 22.0, 14.0)
	var jamb_w: float = r.jamb_right - r.jamb_left
	check_near(jamb_w, Arch.jamb_width(14.0), 1e-4, "the near jamb is depth · sin(yaw) wide")
	check(r.inner.size() >= 3, "the inner wall shows")
	var top_left: Vector2 = r.inner[0]
	check(top_left.x > (Arch.front_plane(22.0) * Vector2(-48.0, -80.0)).x, "the inner wall starts after the jamb")
	Arch.yaw = 0.0
	var flat := Arch.recess_polys(opening, 22.0, 14.0)
	check_near(flat.jamb_right - flat.jamb_left, 0.0, 1e-6, "no jamb square-on")


func test_merlons_stand_along_the_front_and_the_lane_facing_end() -> void:
	Arch.yaw = YAW
	var m := Arch.merlon_boxes(-204.0, 4.0, -22.0, 22.0, -122.0, 16.0, 22.0, 38.0, 5.0)
	var front := m.filter(func(b: Dictionary) -> bool: return b.side == "front")
	var end := m.filter(func(b: Dictionary) -> bool: return b.side == "end")
	check(front.size() >= 5 and end.size() >= 1, "merlons along both (%d front, %d end)" % [front.size(), end.size()])
	for b in m:
		check((b.z1 - b.z0 if b.side == "front" else b.x1 - b.x0) <= 5.01, "a merlon is a thin block")
	Arch.yaw = 0.0
	check_eq(Arch.merlon_boxes(-204.0, 4.0, -22.0, 22.0, -122.0, 16.0, 22.0, 38.0, 5.0).filter(func(b: Dictionary) -> bool: return b.side == "end").size(), 0, "square-on the end merlons are edge-on and are not drawn")


func test_prism_shows_only_the_right_facing_sides() -> void:
	# A rock silhouette extruded in depth: the sides that face the lane show while the camera is turned; the ones
	# facing up (edge-on) and the left never do.
	var rock := [Vector2(-40, 0), Vector2(-36, -60), Vector2(0, -80), Vector2(30, -40), Vector2(40, 0)]
	Arch.yaw = YAW
	var sides := Arch.prism_sides(rock, -20.0, 30.0)
	check(sides.size() >= 1, "some sides show")
	for s in sides:
		check(s.normal.x > 0.0, "a visible side faces the lane (normal %s)" % s.normal)
		check(s.quad.size() == 4, "a side is a quad")
	Arch.yaw = 0.0
	check_eq(Arch.prism_sides(rock, -20.0, 30.0).size(), 0, "square-on no side shows")


func test_prism_sides_widen_with_depth() -> void:
	Arch.yaw = YAW
	var wall := [Vector2(0, 0), Vector2(0, -50), Vector2(20, -50), Vector2(20, 0)]
	var shallow := Arch.prism_sides(wall, -10.0, 10.0)
	var deep := Arch.prism_sides(wall, -30.0, 30.0)
	var w1: float = (shallow[0].quad[1] as Vector2).x - (shallow[0].quad[2] as Vector2).x
	var w2: float = (deep[0].quad[1] as Vector2).x - (deep[0].quad[2] as Vector2).x
	check_near(w2 / w1, 3.0, 1e-3, "a body three times as deep shows a side three times as wide")
	Arch.yaw = 0.0


func test_frustum_faces_taper() -> void:
	Arch.yaw = YAW
	var f := Arch.frustum_faces(-24.0, 24.0, -16.0, 16.0, -14.0, 14.0, -10.0, 10.0, -70.0)
	check_eq(f.size(), 2, "front and lane-facing faces")
	var front: Array = f[0]
	check(front[0].x < front[3].x and front[1].x > front[2].x, "the front narrows toward the top")
	check_eq(front[2].y, -70.0, "up to its height")
	Arch.yaw = 0.0
	check_eq(Arch.frustum_faces(-24.0, 24.0, -16.0, 16.0, -14.0, 14.0, -10.0, 10.0, -70.0).size(), 2, "the end of a tapered body still shows square-on: its slope faces the camera")


func test_pt_is_the_camera_projection() -> void:
	Arch.yaw = YAW
	for p in [Vector3(-30, -50, 12), Vector3(20, -5, -8)]:
		check(Arch.pt(p.x, p.y, p.z).distance_to(FkRig.project(p, {"yaw": YAW})) < 1e-4, "same as FkRig.project for %s" % p)
	Arch.yaw = 0.0


func test_lathe_follows_its_profile_and_leaves_the_camera_to_the_axis() -> void:
	# A trunk's silhouette is its radius each side of the axis, whatever the yaw; the axis itself shifts with depth.
	var profile := [[-100.0, 20.0], [-40.0, 26.0], [0.0, 60.0]]
	for yaw in [0.0, YAW]:
		Arch.yaw = yaw
		var lo := INF
		var hi := -INF
		var strips := Arch.lathe_strips(-50.0, 10.0, profile)
		for st in strips:
			for v in st.poly:
				lo = minf(lo, v.x)
				hi = maxf(hi, v.x)
		var axis := Arch.cylinder_x(-50.0, 10.0)
		check(absf((axis - lo) - 61.2) < 0.5 and absf((hi - axis) - 61.2) < 0.5, "a base 60 each side of the axis at yaw %s (%s..%s)" % [yaw, lo, hi])
		check(strips[2].k > strips[strips.size() - 1].k, "lit on the left, dark on the right")
	Arch.yaw = 0.0


func test_helix_draws_only_the_near_half() -> void:
	Arch.yaw = YAW
	var runs := Arch.helix_runs(-30.0, 0.0, 14.0, -200.0, 0.0, 3.0, -PI / 2.0)
	var x := Arch.cylinder_x(-30.0, 0.0)
	check_eq(runs.size(), 3, "a run of vine for each near half turn")
	for run in runs:
		for v in run:
			check(v.x >= x - 14.01 and v.x <= x + 14.01, "inside the column's silhouette")
			check(v.y <= 0.0 and v.y >= -200.0, "between the two ends")
	Arch.yaw = 0.0


func test_facets_show_the_faces_that_look_at_the_camera() -> void:
	# A four-sided column with a face square to the viewer: one face square-on, two once the camera turns.
	var profile := [[-40.0, 10.0], [0.0, 10.0]]
	Arch.yaw = 0.0
	check_eq(Arch.facets(0.0, 0.0, profile, 4, PI / 4.0).size(), 1, "square-on: the front face only")
	Arch.yaw = YAW
	var f := Arch.facets(0.0, 0.0, profile, 4, PI / 4.0)
	check_eq(f.size(), 2, "turned: the front and the lane-facing face")
	check(f[0].k != f[1].k, "the two faces are lit differently")
	Arch.yaw = 0.0
	check_eq(Arch.facets(0.0, 0.0, profile, 6).size(), 3, "a hexagon shows three faces from any side")
