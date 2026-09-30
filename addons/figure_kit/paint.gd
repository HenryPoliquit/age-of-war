class_name FkPaint
extends RefCounted
## Canvas primitives shared by every figure-kit drawing: a transform stack over
## draw_set_transform_matrix, shaded polygons and tapered limbs. Local space: +x forward, up is −y.


## Walk blend 0..1. Callers pass `move` (eased per unit); `moving` is the legacy on/off form.
static func move_amount(pose: Dictionary) -> float:
	return pose.get("move", 1.0 if pose.get("moving", false) else 0.0)


static func tint(col: Color, pose: Dictionary) -> Color:
	var f: float = pose.get("flash", 0.0)
	return col.lerp(Color.WHITE, f * 0.85) if f > 0.0 else col


static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, col, w)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


static func ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, rot := 0.0, n := 18) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	ci.draw_colored_polygon(pts, col)


static func poly(ci: CanvasItem, pts: Array, col: Color, offset := Vector2.ZERO) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(v + offset)
	ci.draw_colored_polygon(p, col)


## Polygon shaded as a volume: vertices facing the key light (upper front) lighter, far side darker.
static func shade_poly(ci: CanvasItem, pts: Array, col: Color, light := Vector2(0.45, -0.9)) -> void:
	var c := Vector2.ZERO
	for v in pts:
		c += v
	c /= pts.size()
	var p := PackedVector2Array()
	var cols := PackedColorArray()
	var ln := light.normalized()
	for v in pts:
		p.append(v)
		var d: Vector2 = (v - c)
		var k := d.normalized().dot(ln) if d.length() > 0.001 else 0.0
		cols.append(col.lightened(0.16 * k) if k > 0.0 else col.darkened(-0.22 * k))
	ci.draw_polygon(p, cols)


static func ellipse_pts(c: Vector2, r: Vector2, rot := 0.0, n := 14) -> Array:
	var out := []
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return out


## Tapered limb segment with rounded joints, shaded across its width.
static func seg(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, col: Color) -> void:
	var d := (b - a)
	if d.length() < 0.01:
		return
	var n := d.normalized().orthogonal()
	var lit := col.lightened(0.12)
	var dark := col.darkened(0.2)
	# The side facing the light (up/forward) is lighter.
	var s := 1.0 if n.dot(Vector2(0.45, -0.9)) > 0.0 else -1.0
	ci.draw_polygon(PackedVector2Array([a + n * wa * 0.5 * s, b + n * wb * 0.5 * s, b - n * wb * 0.5 * s, a - n * wa * 0.5 * s]),
		PackedColorArray([lit, lit, dark, dark]))
	ci.draw_circle(a, wa * 0.5, col)
	ci.draw_circle(b, wb * 0.5, col.darkened(0.05))


static func wheel(ci: CanvasItem, c: Vector2, r: float, rot: float, rim: Color, hub: Color, spokes := 6) -> void:
	ci.draw_circle(c, r, rim)
	ci.draw_circle(c, r * 0.72, rim.darkened(0.35))
	for i in spokes:
		var a := rot + TAU * i / spokes
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.75, rim.lightened(0.15), 2.0)
	ci.draw_circle(c, r * 0.22, hub)


static func shadow(ci: CanvasItem, w: float) -> void:
	ellipse(ci, Vector2(0, 1), Vector2(w, 4), Color(0, 0, 0, 0.28))


static func rivets(ci: CanvasItem, a: Vector2, b: Vector2, n: int, col: Color, r := 1.1) -> void:
	for i in n:
		ci.draw_circle(a.lerp(b, (i + 0.5) / n), r, col)


## Soft additive-looking halo (drawn as stacked translucent discs; the glow pass adds bloom).
static func halo(ci: CanvasItem, c: Vector2, r: float, col: Color, k := 1.0) -> void:
	for i in 3:
		ci.draw_circle(c, r * (1.0 - i * 0.28), Color(col, (0.16 + i * 0.16) * k))


## A tiny transform stack on top of draw_set_transform_matrix (CanvasItem has no push/pop).
static var _stack: Array[Transform2D] = []
static var _current := Transform2D.IDENTITY


static func begin(ci: CanvasItem, xf: Transform2D) -> void:
	_stack.clear()
	_current = xf
	ci.draw_set_transform_matrix(xf)


static func push(ci: CanvasItem, local: Transform2D) -> void:
	_stack.append(_current)
	_current = _current * local
	ci.draw_set_transform_matrix(_current)


static func pop(ci: CanvasItem) -> void:
	_current = _stack.pop_back() if not _stack.is_empty() else Transform2D.IDENTITY
	ci.draw_set_transform_matrix(_current)
