class_name Arch
extends RefCounted
## 3D architecture seen through the units' camera. Structures stand in the view's local space (x toward the
## enemy, y down, z toward the viewer) and are built from boxes, cylinders and roofs, projected through the camera
## yaw (FkRig) so a wall shows its front, its lane-facing end and a hint of depth, as a soldier shows his side.
## Each vertical face is a plane, and the flat art of a face (masonry, windows, planks) is drawn on it through the
## plane's transform, so the existing 2D detail code is reused. A mirrored base is a mirror image (the view flips
## x), so both bases show the face that looks toward the lane.

## The camera's yaw (rad), set by the caller each draw from the units' camera.
static var yaw := 0.0
## Brightness of the lane-facing end faces against the front (light from the upper left, in front).
const END := 0.74
const EDGE := Color(0, 0, 0, 0.32)


## The plane z = zf: face-local (x, y) → screen.
static func front_plane(zf: float) -> Transform2D:
	return Transform2D(Vector2(cos(yaw), 0.0), Vector2(0.0, 1.0), Vector2(-zf * sin(yaw), 0.0))


## The plane x = xr (the face that looks toward the lane): face-local (u, y) → screen, u running from the front
## edge (z = zf) toward the back, so art drawn left to right reads from the front corner to the far one.
static func side_plane(xr: float, zf: float) -> Transform2D:
	return Transform2D(Vector2(sin(yaw), 0.0), Vector2(0.0, 1.0), Vector2(xr * cos(yaw) - zf * sin(yaw), 0.0))


## Screen x of a vertical axis at (x, z): the centre of a round tower.
static func cylinder_x(x: float, z: float) -> float:
	return x * cos(yaw) - z * sin(yaw)


## How much of the inside of an opening `depth` deep the camera sees on its near jamb.
static func jamb_width(depth: float) -> float:
	return depth * sin(yaw)


## Runs `art` on the front plane z = zf (its face-local coordinates are x, y).
static func on_front(ci: CanvasItem, zf: float, art: Callable) -> void:
	FkPaint.push(ci, front_plane(zf))
	art.call()
	FkPaint.pop(ci)


## Runs `art` on the end plane x = xr (face-local coordinates u, y; see side_plane).
static func on_end(ci: CanvasItem, xr: float, zf: float, art: Callable) -> void:
	FkPaint.push(ci, side_plane(xr, zf))
	art.call()
	FkPaint.pop(ci)


static func _shade(col: Color, k: float) -> Color:
	return Color(col.r * k, col.g * k, col.b * k, col.a)


## `col` as it looks on an end face (turned away from the light).
static func end_col(col: Color) -> Color:
	return _shade(col, END)


static func _rect(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]


## A box: x in [x0, x1], y in [y0 (top), y1 (bottom)], z in [z0 (back), z1 (front)]. Draws its lane-facing end
## then its front. `front_art(rect)` and `end_art(rect)` draw detail on those faces, in face-local coordinates
## (the end's u is the depth from the front); pass Callables that take a Rect2, or leave them empty.
static func box(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col: Color,
		front_art := Callable(), end_art := Callable(), edge := true, ink := Color(0, 0, 0, 0), ink_w := 1.1) -> void:
	var depth := z1 - z0
	if sin(yaw) > 1e-4:
		on_end(ci, x1, z1, func() -> void:
			FkPaint.shade_poly(ci, _rect(0.0, y0, depth, y1), _shade(col, END), Vector2(0.5, -0.8))
			if end_art.is_valid():
				end_art.call(Rect2(0.0, y0, depth, y1 - y0)))
	on_front(ci, z1, func() -> void:
		FkPaint.shade_poly(ci, _rect(x0, y0, x1, y1), col, Vector2(0.5, -0.8))
		if front_art.is_valid():
			front_art.call(Rect2(x0, y0, x1 - x0, y1 - y0)))
	if ink.a > 0.0:
		# An ink outline round each visible face (the towers' style).
		var v := {"yaw": yaw}
		var fr := PackedVector2Array([FkRig.project(Vector3(x0, y0, z1), v), FkRig.project(Vector3(x1, y0, z1), v),
			FkRig.project(Vector3(x1, y1, z1), v), FkRig.project(Vector3(x0, y1, z1), v), FkRig.project(Vector3(x0, y0, z1), v)])
		ci.draw_polyline(fr, ink, ink_w)
		if sin(yaw) > 1e-4:
			ci.draw_polyline(PackedVector2Array([FkRig.project(Vector3(x1, y0, z1), v), FkRig.project(Vector3(x1, y0, z0), v),
				FkRig.project(Vector3(x1, y1, z0), v), FkRig.project(Vector3(x1, y1, z1), v)]), ink, ink_w)
	elif edge:
		var a := FkRig.project(Vector3(x0, y0, z1), {"yaw": yaw})
		var b := FkRig.project(Vector3(x1, y0, z1), {"yaw": yaw})
		var c := FkRig.project(Vector3(x1, y1, z1), {"yaw": yaw})
		var d := FkRig.project(Vector3(x1, y0, z0), {"yaw": yaw})
		ci.draw_line(a, b, EDGE, 1.0)
		ci.draw_line(b, c, EDGE, 1.0)
		if sin(yaw) > 1e-4:
			ci.draw_line(b, d, EDGE, 1.0)


static func rect_pts(x0: float, y0: float, x1: float, y1: float) -> Array:
	return _rect(x0, y0, x1, y1)


## A round-arched (or pointed, `point` > 0) opening's outline on its plane, from the spring line up.
static func arch_pts(x0: float, x1: float, y_bottom: float, y_spring: float, rise: float, point := 0.0, n := 10) -> Array:
	var pts: Array = [Vector2(x0, y_bottom), Vector2(x0, y_spring)]
	var cx := (x0 + x1) * 0.5
	var r := (x1 - x0) * 0.5
	for i in range(1, n):
		var a := PI * i / n
		pts.append(Vector2(cx - cos(a) * r, y_spring - (sin(a) * rise + sin(a) * point * (1.0 - absf(cos(a))))))
	pts.append(Vector2(x1, y_spring))
	pts.append(Vector2(x1, y_bottom))
	return pts


## The polygons of a recessed opening: its outline on the plane z = zf and how deep it goes. Returns
## {jamb_left, jamb_right (screen x of the near jamb's two edges), outer (the opening's outline on the screen), inner (the
## inner wall's visible part)}: the inner wall sits `depth` further back, so a turned camera shifts it and shows the near
## jamb between.
static func recess_polys(opening: Array, zf: float, depth: float) -> Dictionary:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var back := front_plane(zf - depth)
	var near := front_plane(zf)
	var left := INF
	for p in opening:
		var o: Vector2 = near * p
		outer.append(o)
		inner.append(back * p)
		left = minf(left, o.x)
	var clipped := Geometry2D.intersect_polygons(inner, outer)
	var vis := PackedVector2Array() if clipped.is_empty() else clipped[0]
	return {"jamb_left": left, "jamb_right": left + jamb_width(depth), "outer": outer, "inner": vis}


## Draws a recessed opening: the near jamb in `jamb_col`, the inner wall in `inner_col`. Returns the inner wall's
## plane z, so bars, doors or shutters can be drawn on it with on_front.
static func recess(ci: CanvasItem, opening: Array, zf: float, depth: float, jamb_col: Color, inner_col: Color) -> float:
	var r := recess_polys(opening, zf, depth)
	ci.draw_colored_polygon(r.outer, jamb_col)
	if r.inner.size() >= 3:
		ci.draw_colored_polygon(r.inner, inner_col)
	return zf - depth


## The visible roof slopes of a pyramid over the footprint x in [x0, x1], z in [z0, z1] at y_base, apex at y_apex above
## its middle: [front slope, lane-facing slope (only while the camera is turned)], each a screen triangle whose third
## point is the apex.
static func pyramid_faces(x0: float, x1: float, z0: float, z1: float, y_base: float, y_apex: float) -> Array:
	var v := {"yaw": yaw}
	var apex := FkRig.project(Vector3((x0 + x1) * 0.5, y_apex, (z0 + z1) * 0.5), v)
	var fl := FkRig.project(Vector3(x0, y_base, z1), v)
	var fr := FkRig.project(Vector3(x1, y_base, z1), v)
	var faces: Array = [[fl, fr, apex]]
	if sin(yaw) > 1e-4:
		faces.append([fr, FkRig.project(Vector3(x1, y_base, z0), v), apex])
	return faces


static func pyramid(ci: CanvasItem, x0: float, x1: float, z0: float, z1: float, y_base: float, y_apex: float, col: Color, ribs := 0) -> void:
	var faces := pyramid_faces(x0, x1, z0, z1, y_base, y_apex)
	for i in range(faces.size() - 1, -1, -1):
		var f: Array = faces[i]
		var k := 1.0 if i == 0 else END
		FkPaint.shade_poly(ci, f, _shade(col, k), Vector2(0.5, -0.8))
		if ribs > 0:
			for r in ribs:
				var u := (r + 1.0) / (ribs + 1.0)
				ci.draw_line((f[0] as Vector2).lerp(f[1], u), f[2], Color(0, 0, 0, 0.22), 1.0)
		ci.draw_polyline(PackedVector2Array([f[0], f[2], f[1]]), EDGE, 1.0)


## A cone (a round tower's roof): centre (cx, cz), base radius r at y_base, apex y_apex. Lit on the left.
static func cone(ci: CanvasItem, cx: float, cz: float, r: float, y_base: float, y_apex: float, col: Color, ribs := 0) -> void:
	var x := cylinder_x(cx, cz)
	var apex := Vector2(x, y_apex)
	FkPaint.shade_poly(ci, [Vector2(x - r, y_base), apex, Vector2(x + r * 0.1, y_base)], _shade(col, 1.06), Vector2(0.5, -0.8))
	FkPaint.shade_poly(ci, [Vector2(x + r * 0.1, y_base), apex, Vector2(x + r, y_base)], _shade(col, 0.66), Vector2(0.5, -0.8))
	for k in ribs:
		var u := lerpf(-r, r, (k + 1.0) / (ribs + 1.0))
		ci.draw_line(Vector2(x + u, y_base), apex, Color(0, 0, 0, 0.2), 1.0)


## A vertical cylinder (a round tower): centre (cx, cz), radius r, y in [y0 (top), y1 (bottom)]. Lit on the left, in
## shadow on the right. `course` > 0 lays courses of masonry `block` wide whose joints squeeze toward the edges.
static func cylinder(ci: CanvasItem, cx: float, cz: float, r: float, y0: float, y1: float, col: Color, course := 0.0, block := 12.0, flutes := 0) -> void:
	var x := cylinder_x(cx, cz)
	var n := 12
	for i in n:
		var u0 := lerpf(-r, r, float(i) / n)
		var u1 := lerpf(-r, r, float(i + 1) / n)
		var um := clampf((u0 + u1) * 0.5 / r, -1.0, 1.0)
		var facing := Vector2(um, sqrt(maxf(0.0, 1.0 - um * um)))
		var k := 0.5 + 0.62 * maxf(0.0, facing.dot(Vector2(-0.55, 0.83)))
		ci.draw_rect(Rect2(x + u0 - 0.3, y0, u1 - u0 + 0.6, y1 - y0), _shade(col, k))
	if course > 0.0:
		var rows := int((y1 - y0) / course)
		for row in rows:
			var y := y0 + row * course
			ci.draw_line(Vector2(x - r, y), Vector2(x + r, y), Color(0, 0, 0, 0.3), 0.9)
			var step := block / r
			var phi := -PI * 0.5 + (row % 2) * step * 0.5 + 0.0001
			var prev := -r
			while phi < PI * 0.5:
				var u := r * sin(phi)
				if u > -r + 0.5 and u < r - 0.5:
					ci.draw_line(Vector2(x + u, y), Vector2(x + u, y + course), Color(0, 0, 0, 0.26), 0.8)
					var tone := fposmod(sin(u * 12.9898 + y * 78.233) * 43758.5453, 1.0) - 0.5
					ci.draw_rect(Rect2(x + prev + 0.5, y + 0.6, u - prev - 1.0, course - 1.2), Color(1, 1, 1, 0.1) if tone > 0.0 else Color(0, 0, 0, 0.1))
					prev = u
				phi += step
	for k in flutes:
		# Flutes: grooves down the shaft, squeezed toward the edges like the joints.
		var u := r * sin(lerpf(-PI * 0.42, PI * 0.42, (k + 0.5) / flutes))
		ci.draw_line(Vector2(x + u, y0), Vector2(x + u, y1), Color(0, 0, 0, 0.16), 1.0)
	ci.draw_line(Vector2(x - r, y0), Vector2(x - r, y1), EDGE, 1.0)
	ci.draw_line(Vector2(x + r, y0), Vector2(x + r, y1), EDGE, 1.0)


## Crenellation: the merlons along the front edge (z1) and, while the camera is turned, the lane-facing end (x1), as
## boxes [{side, x0, x1, z0, z1}] `h` tall and `w` wide every `pitch`, `thick` deep, on a wall top at y_top.
static func merlon_boxes(x0: float, x1: float, z0: float, z1: float, y_top: float, h: float, w: float, pitch: float, thick: float) -> Array:
	var out: Array = []
	if sin(yaw) > 1e-4:
		# Along the end, a merlon and a gap of the same width, starting a half-gap in from the back.
		var z := z0 + w * 0.5
		while z + w <= z1 + 0.01:
			out.append({"side": "end", "x0": x1 - thick, "x1": x1, "z0": z, "z1": z + w})
			z += w * 2.0
	var x := x0
	while x + w <= x1 + 0.01:
		out.append({"side": "front", "x0": x, "x1": x + w, "z0": z1 - thick, "z1": z1})
		x += pitch
	return out


static func crenellate(ci: CanvasItem, x0: float, x1: float, z0: float, z1: float, y_top: float, h: float, w: float, pitch: float, col: Color, thick := 5.0, ink := Color(0, 0, 0, 0)) -> void:
	for b in merlon_boxes(x0, x1, z0, z1, y_top, h, w, pitch, thick):
		box(ci, b.x0, b.x1, y_top - h, y_top, b.z0, b.z1, col, Callable(), Callable(), true, ink, 0.9)


## Bars (a portcullis, a grille) standing `bar_depth` inside an opening: lines at the given x's (vertical) and y's
## (horizontal), in the opening's plane coordinates, drawn on the plane behind the front and clipped to what the opening
## shows from the camera.
static func bars(ci: CanvasItem, opening: Array, zf: float, depth: float, bar_depth: float, xs: Array, ys: Array, col: Color, w := 2.0) -> void:
	var r := recess_polys(opening, zf, depth)
	var plane := front_plane(zf - bar_depth)
	var near := front_plane(zf)
	var outer := PackedVector2Array()
	var y_min := INF
	var y_max := -INF
	var x_min := INF
	var x_max := -INF
	for p in opening:
		outer.append(near * p)
		y_min = minf(y_min, p.y)
		y_max = maxf(y_max, p.y)
		x_min = minf(x_min, p.x)
		x_max = maxf(x_max, p.x)
	var lines: Array = []
	for x in xs:
		lines.append(PackedVector2Array([plane * Vector2(x, y_min), plane * Vector2(x, y_max)]))
	for y in ys:
		lines.append(PackedVector2Array([plane * Vector2(x_min, y), plane * Vector2(x_max, y)]))
	for l in lines:
		for piece in Geometry2D.intersect_polyline_with_polygon(l, outer):
			ci.draw_polyline(piece, col, w)


## The visible side faces of a silhouette `pts` (x, y on the front plane) extruded from z0 (back) to z1 (front): the
## edges whose outward normal points toward the lane, each as {normal (unit, in x and y), quad (4 screen points)}.
## While the camera is square-on none show. Works for convex and mildly concave outlines.
static func prism_sides(pts: Array, z0: float, z1: float) -> Array:
	var out: Array = []
	if sin(yaw) <= 1e-4:
		return out
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var v := {"yaw": yaw}
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var e := b - a
		if e.length() < 1e-4:
			continue
		var n := Vector2(e.y, -e.x).normalized()
		if n.dot((a + b) * 0.5 - c) < 0.0:
			n = -n
		if n.x > 0.02:
			out.append({"normal": n, "quad": [FkRig.project(Vector3(a.x, a.y, z1), v), FkRig.project(Vector3(b.x, b.y, z1), v),
				FkRig.project(Vector3(b.x, b.y, z0), v), FkRig.project(Vector3(a.x, a.y, z0), v)]})
	return out


## A silhouette extruded in depth (a rock, a gable roof, a buttress, a tent, a stake): the lane-facing sides in shade
## (lighter where they slope up), then the front. `ink` outlines every visible face.
static func prism(ci: CanvasItem, pts: Array, z0: float, z1: float, col: Color, ink := Color(0, 0, 0, 0), ink_w := 1.0) -> void:
	for s in prism_sides(pts, z0, z1):
		var k := END * (0.9 + 0.35 * maxf(0.0, -s.normal.y))
		FkPaint.shade_poly(ci, s.quad, _shade(col, k), Vector2(0.5, -0.8))
		if ink.a > 0.0:
			var q := PackedVector2Array(s.quad)
			q.append(s.quad[0])
			ci.draw_polyline(q, ink, ink_w)
	on_front(ci, z1, func() -> void:
		FkPaint.shade_poly(ci, pts, col, Vector2(0.5, -0.8))
		if ink.a > 0.0:
			var p := PackedVector2Array(pts)
			p.append(pts[0])
			ci.draw_polyline(p, ink, ink_w))


## The visible faces of a tapered body (a sloped earthwork, a pylon): bottom rectangle x in [xb0, xb1], z in
## [zb0, zb1] at y = 0, top rectangle x in [xt0, xt1], z in [zt0, zt1] at y_top. [front, lane-facing end]: each 4 screen
## points, bottom-left, bottom-right, top-right, top-left as seen.
static func frustum_faces(xb0: float, xb1: float, xt0: float, xt1: float, zb0: float, zb1: float, zt0: float, zt1: float, y_top: float) -> Array:
	var v := {"yaw": yaw}
	var front: Array = [FkRig.project(Vector3(xb0, 0, zb1), v), FkRig.project(Vector3(xb1, 0, zb1), v),
		FkRig.project(Vector3(xt1, y_top, zt1), v), FkRig.project(Vector3(xt0, y_top, zt1), v)]
	var end: Array = [FkRig.project(Vector3(xb1, 0, zb1), v), FkRig.project(Vector3(xb1, 0, zb0), v),
		FkRig.project(Vector3(xt1, y_top, zt0), v), FkRig.project(Vector3(xt1, y_top, zt1), v)]
	return [front, end]


static func frustum(ci: CanvasItem, xb0: float, xb1: float, xt0: float, xt1: float, zb0: float, zb1: float, zt0: float, zt1: float, y_top: float, col: Color, ink := Color(0, 0, 0, 0), ink_w := 1.0) -> void:
	var f := frustum_faces(xb0, xb1, xt0, xt1, zb0, zb1, zt0, zt1, y_top)
	# The end slope leans away from the light more than the front, which leans up: shade both by their slope.
	var slope := absf(xb1 - xt1) / maxf(1.0, absf(y_top))
	if sin(yaw) > 1e-4:
		FkPaint.shade_poly(ci, f[1], _shade(col, END * (1.0 + 0.4 * slope)), Vector2(0.5, -0.8))
	FkPaint.shade_poly(ci, f[0], _shade(col, 1.0 + 0.1 * slope), Vector2(0.5, -0.8))
	if ink.a > 0.0:
		for i in (2 if sin(yaw) > 1e-4 else 1):
			var q := PackedVector2Array(f[i])
			q.append(f[i][0])
			ci.draw_polyline(q, ink, ink_w)
