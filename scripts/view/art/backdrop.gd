class_name Backdrop
extends Node2D
## One side's half of the split battlefield (GDD §13.6). Draws that side's age scenery across the
## whole view; a shader keeps only its half, cut at the front line with a painterly noisy seam.
## On evolution the previous age stays underneath while the new one dissolves in (GDD §13.5 step 3).

const SHADER := preload("res://shaders/split_backdrop.gdshader")
const SKY := preload("res://shaders/sky.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")

var side := 0
var age := 1
var race: StringName = &"human"
## Set by the owner every frame: camera centre x, seam (front line) world x, and animation time.
var cam_x := 960.0
var seam_x := 1200.0
var time := 0.0
## Day/night state from the owner (null = the age's static palette, e.g. the menu).
var dn: DayNight

static var _stars: PackedVector3Array
var _mat: ShaderMaterial
var _old: Backdrop
var _dissolve := 1.0


var _sky: Node2D
var _ground: Node2D
## The scenery, built once into cached nodes: per parallax layer a root (its x is the parallax offset, set every frame)
## holding chunks of static shapes (recorded once, culled by Godot when off screen) and one node that redraws the
## layer's animations each frame.
var _roots: Array[Node2D] = []
var _anim_nodes: Array[Node2D] = []
var _layer_anims: Array = []
var _overlay: Node2D
const CHUNK := 900.0


class AnimNode extends Node2D:
	var back: Backdrop
	var index := 0

	func _draw() -> void:
		back._draw_layer_anims(self, index)


class OverlayNode extends Node2D:
	var back: Backdrop

	func _draw() -> void:
		back._draw_overlay(self)


func setup(p_side: int, p_age: int, p_race: StringName = &"human") -> void:
	side = p_side
	age = p_age
	race = p_race
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("side", float(side))
	_mat.set_shader_parameter("dissolve", 1.0)
	material = _mat
	if has_layers():
		_sky = _layer(SKY, true, _draw_sky_rect)
		_ground = _layer(GROUND, false, _draw_ground_rect)
		_build_scenery()


## Only the backdrop proper has sky and ground (the front layer overrides this).
func has_layers() -> bool:
	return true


func _layer(shader: Shader, behind: bool, cb: Callable) -> Node2D:
	var n := Node2D.new()
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("side", float(side))
	n.material = m
	n.show_behind_parent = behind
	n.draw.connect(cb)
	add_child(n)
	return n


## The part of the view this side can show: its half of the screen plus the seam's soft margin,
## so neither side shades pixels the other side covers.
func _view_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var left := cam_x - vp.x * 0.5 - 80
	var right := cam_x + vp.x * 0.5 + 80
	var margin := vp.x * 0.12
	if side == 0:
		right = minf(right, seam_x + margin)
	else:
		left = maxf(left, seam_x - margin)
	return Rect2(left, -400, maxf(0.0, right - left), 2000)


func _draw_sky_rect() -> void:
	var r := _view_rect()
	_sky.draw_rect(Rect2(r.position, Vector2(r.size.x, Scenery.GROUND_Y + 400)), Color.WHITE)


func _draw_ground_rect() -> void:
	var r := _view_rect()
	_ground.draw_rect(Rect2(r.position.x, Scenery.GROUND_Y - 8, r.size.x, 700), Color.WHITE)


## Records the current age's scenery into cached nodes (see _roots). Runs at setup and when the age changes.
func _build_scenery() -> void:
	for n in _roots:
		n.queue_free()
	_roots.clear()
	_anim_nodes.clear()
	_layer_anims.clear()
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	var sc := Scenery.for_look(race, age)
	for li in sc.layers.size():
		var layer: Dictionary = sc.layers[li]
		var root := Node2D.new()
		root.use_parent_material = true
		add_child(root)
		var buckets := {}
		for sh in layer.shapes:
			var ci := 0 if not sh.has("x0") else maxi(0, int(floor((sh.x0 - Scenery.X0) / CHUNK)))
			if not buckets.has(ci):
				buckets[ci] = []
			buckets[ci].append(sh)
		for ci in buckets:
			var chunk := Node2D.new()
			chunk.use_parent_material = true
			var shapes: Array = buckets[ci]
			chunk.draw.connect(func() -> void:
				for sh in shapes:
					_draw_shape_on(chunk, sh))
			root.add_child(chunk)
		var mine: Array = []
		for a in sc.anims:
			if a.get("layer", -1) == li:
				mine.append(a)
		_layer_anims.append(mine)
		var an := AnimNode.new()
		an.back = self
		an.index = li
		an.use_parent_material = true
		root.add_child(an)
		_roots.append(root)
		_anim_nodes.append(an)
	var has_lightning := false
	for a in sc.anims:
		if a.type == "lightning":
			has_lightning = true
	if has_lightning:
		var ov := OverlayNode.new()
		ov.back = self
		ov.use_parent_material = true
		add_child(ov)
		_overlay = ov
	# Sky first (it is behind the parent), the ground last.
	if _ground != null:
		move_child(_ground, get_child_count() - 1)


func _update_layers(seam_uv: float) -> void:
	if _sky == null:
		return
	var sc := Scenery.for_look(race, age)
	var pal := sc.palette
	var cl: Dictionary = pal.clouds
	var starry: bool = pal.get("stars", false)
	var sm: ShaderMaterial = _sky.material
	var gm: ShaderMaterial = _ground.material
	var top: Color = pal.sky[0]
	var horizon: Color = pal.sky[1]
	var sun: Color = pal.sun
	var sun_uv := Vector2(pal.sun_pos.x, pal.sun_pos.y / 1080.0)
	var sun_size: float = pal.sun_r / 1080.0
	var moon := 0.0
	var star_a := 1.0 if starry else 0.0
	if dn != null:
		var k: float = pal.dn
		top = top.lerp(Color("0b1030"), (1.0 - dn.daylight) * k)
		horizon = horizon.lerp(Color("2a3358"), (1.0 - dn.daylight) * k).lerp(Color("f08a5a"), dn.twilight * 0.5 * k)
		if not starry:
			var bp := dn.body_pos()
			sun_uv = Vector2(bp.x, bp.y / 1080.0)
			star_a = dn.stars()
			if dn.is_night():
				sun = Color(0.9, 0.93, 1.0)
				sun_size = 30.0 / 1080.0
				moon = 1.0
			else:
				sun = sun.lerp(Color("ff9a5a"), dn.twilight * 0.6)
	if pal.sun_r <= 0.0 and moon < 0.5:
		sun_size = 0.0
	var night := 1.0 - dn.daylight if dn != null else 0.0
	for pair in [["top_color", top], ["horizon_color", horizon], ["sun_color", sun], ["sun_uv", sun_uv],
			["sun_size", sun_size], ["moon", moon], ["stars", star_a], ["cloud_cover", cl.cover], ["cloud_band", cl.band],
			["cloud_light", (cl.light as Color).lerp(Color("5a6488"), night * 0.7)], ["cloud_shadow", (cl.shadow as Color).lerp(Color("1c2138"), night * 0.7)],
			["drift", cam_x * 0.00012 + time * 0.004], ["time_s", time]]:
		sm.set_shader_parameter(pair[0], pair[1])
	gm.set_shader_parameter("top_color", pal.ground[0])
	gm.set_shader_parameter("bottom_color", pal.ground[1])
	gm.set_shader_parameter("road_color", pal.road)
	gm.set_shader_parameter("kind", int(pal.kind))
	gm.set_shader_parameter("ground_y", Scenery.GROUND_Y - 8.0)
	gm.set_shader_parameter("time_s", time)
	for m in [sm, gm]:
		m.set_shader_parameter("seam", seam_uv)
		m.set_shader_parameter("opaque_left", _mat.get_shader_parameter("opaque_left"))
		m.set_shader_parameter("dissolve", _mat.get_shader_parameter("dissolve"))
	_sky.queue_redraw()
	_ground.queue_redraw()


func set_age(new_age: int) -> void:
	if new_age == age:
		return
	if _old != null:
		_old.queue_free()
	_old = get_script().new()
	_old.setup(side, age, race)
	_old.show_behind_parent = true
	add_child(_old)
	# Draw the outgoing age first, underneath this one's sky, scenery and ground.
	move_child(_old, 0)
	age = new_age
	_dissolve = 0.0
	if has_layers():
		_build_scenery()


func _process(delta: float) -> void:
	var vp := get_viewport()
	var seam_screen := (vp.get_canvas_transform() * Vector2(seam_x, 0)).x
	var seam_uv := seam_screen / vp.get_visible_rect().size.x
	_mat.set_shader_parameter("seam", seam_uv)
	_update_layers(seam_uv)
	var sc := Scenery.for_look(race, age)
	for li in _roots.size():
		_roots[li].position.x = cam_x * (1.0 - float(sc.layers[li].factor))
		if not _layer_anims[li].is_empty():
			_anim_nodes[li].queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()
	if _old != null:
		_old.cam_x = cam_x
		_old.time = time
		_old.dn = dn
		_old.seam_x = seam_x
		_old._mat.set_shader_parameter("seam", seam_uv)
		_dissolve = minf(1.0, _dissolve + delta / 1.6)
		_mat.set_shader_parameter("dissolve", _dissolve)
		if _dissolve >= 1.0:
			_old.queue_free()
			_old = null
	if not has_layers():
		queue_redraw()


## The animations of one parallax layer, drawn on its animation node every frame (skipping those off screen).
func _draw_layer_anims(ci: CanvasItem, li: int) -> void:
	var sc := Scenery.for_look(race, age)
	var vp := get_viewport_rect().size
	var left := cam_x - vp.x * 0.5 - 60
	var right := cam_x + vp.x * 0.5 + 60
	var off: float = cam_x * (1.0 - float(sc.layers[li].factor))
	var lo: float = left - off
	var hi: float = right - off
	for a in _layer_anims[li]:
		if a.has("ax1") and (a.ax1 < lo or a.ax0 > hi):
			continue
		_draw_anim(ci, a, time, off, left, right)


## The flash of lightning over the whole scene.
func _draw_overlay(ci: CanvasItem) -> void:
	if GameSettings.get_value("flash_reduction"):
		return
	var vp := get_viewport_rect().size
	var left := cam_x - vp.x * 0.5 - 60
	var right := cam_x + vp.x * 0.5 + 60
	var k := fmod(time, 7.3)
	if k < 0.12 or (k > 0.2 and k < 0.27):
		ci.draw_rect(Rect2(left, -400, right - left, Scenery.GROUND_Y + 800), Color(0.85, 0.9, 1.0, 0.18))


func _draw_stars(left: float, right: float, a: float) -> void:
	if _stars.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 140:
			_stars.append(Vector3(rng.randf(), rng.randf_range(-200, 520), rng.randf_range(0.8, 2.0)))
	for st in _stars:
		var tw := 0.6 + 0.4 * sin(time * 2.0 + st.x * 90.0)
		draw_circle(Vector2(left + (right - left) * st.x, st.y), st.z, Color(1, 1, 1, a * tw * 0.8))


func _draw_shape(sh: Dictionary) -> void:
	_draw_shape_on(self, sh)


func _draw_shape_on(ci: CanvasItem, sh: Dictionary) -> void:
	if sh.has("cols"):
		ci.draw_polygon(sh.poly, sh.cols)
	elif sh.has("poly"):
		ci.draw_colored_polygon(sh.poly, sh.col)
	elif sh.has("circle"):
		ci.draw_circle(sh.circle, sh.r, sh.col)
	elif sh.has("line"):
		ci.draw_line(sh.line, sh.to, sh.col, sh.w)
	elif sh.has("polyline"):
		ci.draw_polyline(sh.polyline, sh.col, sh.w)
	elif sh.has("grad"):
		var r: Rect2 = sh.grad
		ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([sh.top, sh.top, sh.bottom, sh.bottom]))


func _draw_anim(ci: CanvasItem, a: Dictionary, t: float, off: float, left: float, right: float) -> void:
	match a.type:
		"smoke", "drift_smoke":
			var drift: bool = a.type == "drift_smoke"
			for i in 6:
				var ph := fmod(t * 0.25 + i / 6.0, 1.0)
				var p: Vector2 = a.pos + (Vector2(ph * 160.0, -ph * 20.0) if drift else Vector2(ph * 40.0 + sin(t + i) * 4.0, -ph * 140.0))
				var c: Color = a.col
				var r := 8.0 + ph * (40.0 if drift else 26.0)
				var fade := c.a * sin(ph * PI)
				# Soft puff: concentric layers instead of one hard disc.
				for k in 3:
					ci.draw_circle(p + Vector2(k * 3.0, -k * 2.0), r * (1.0 - k * 0.25), Color(c, fade * 0.4))
		"flag":
			var p: Vector2 = a.pos
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(p + Vector2(i * 6.0, sin(t * 4.0 - i * 0.8) * 2.5 * i / 5.0))
			for i in range(5, -1, -1):
				pts.append(p + Vector2(i * 6.0, 20.0 + sin(t * 4.0 - i * 0.8) * 2.5 * i / 5.0))
			ci.draw_colored_polygon(pts, a.col)
		"lamp":
			var fl := (0.85 + 0.15 * sin(t * 3.0 + a.pos.x)) * (1.0 + (1.0 - dn.daylight) * 1.2 if dn != null else 1.0)
			for i in 3:
				ci.draw_circle(a.pos, a.r * (0.4 + i * 0.3), Color(a.col, 0.08 * fl))
		"sign":
			var r: Rect2 = a.rect
			var on := fmod(t + r.position.x * 0.013, 5.0) > 0.18
			var c: Color = a.col
			ci.draw_rect(r.grow(8), Color(c, 0.08 if on else 0.02))
			ci.draw_rect(r, Color(c, 0.22 if on else 0.05))
			ci.draw_rect(r, Color(c, 0.9 if on else 0.2), false, 2.0)
			for i in 3:
				ci.draw_line(r.position + Vector2(10, 12 + i * 12), r.position + Vector2(r.size.x * (0.4 + 0.15 * i), 12 + i * 12), Color(c, 0.7 if on else 0.1), 3.0)
		"drone":
			var x: float = fposmod(a.pos.x + t * a.speed - Scenery.X0, Scenery.X1 - Scenery.X0) + Scenery.X0
			var p := Vector2(x, a.pos.y + sin(t * 2.0 + a.pos.x) * 6.0)
			ci.draw_rect(Rect2(p - Vector2(7, 2), Vector2(14, 4)), Color("30324a"))
			ci.draw_circle(p + Vector2(0, 3), 2.0, Color("ff4fd8") if fmod(t, 1.0) < 0.5 else Color("37e7ff"))
		"glow":
			var k := 0.75 + 0.25 * sin(t * 1.7 + a.pos.x * 0.01)
			var night := 1.0 - dn.daylight if dn != null else 0.3
			var c: Color = a.col
			for i in 3:
				ci.draw_circle(a.pos, a.r * (0.35 + i * 0.3), Color(c, (0.1 + 0.08 * night) * k))
		"rune":
			var k := 0.55 + 0.45 * sin(t * 1.3 + a.pts[0].x * 0.02)
			ci.draw_polyline(a.pts, Color(a.col, 0.25 * k), 6.0)
			ci.draw_polyline(a.pts, Color(a.col, 0.85 * k), 2.0)
		"airship":
			var x: float = fposmod(a.pos.x + t * a.speed - Scenery.X0, Scenery.X1 - Scenery.X0) + Scenery.X0
			var p := Vector2(x, a.pos.y + sin(t * 0.6 + a.pos.x) * 5.0)
			var hull := Color("3a2e48")
			var pts := PackedVector2Array()
			for i in 14:
				var ang := TAU * i / 14.0
				pts.append(p + Vector2(cos(ang) * 38.0, sin(ang) * 13.0))
			ci.draw_colored_polygon(pts, hull.lightened(0.1))
			ci.draw_line(p + Vector2(-30, 0), p + Vector2(30, 0), hull.darkened(0.2), 1.0)
			ci.draw_line(p + Vector2(-12, 12), p + Vector2(-10, 20), hull, 1.0)
			ci.draw_line(p + Vector2(12, 12), p + Vector2(10, 20), hull, 1.0)
			ci.draw_rect(Rect2(p + Vector2(-14, 20), Vector2(28, 7)), hull.darkened(0.2))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-36, -4), p + Vector2(-48, -14), p + Vector2(-46, 4)]), hull)
			ci.draw_circle(p + Vector2(0, 24), 1.5, Color("ffd6a0"))
		"sails":
			var c: Vector2 = a.pos
			var len: float = a.len
			var col: Color = a.col
			for k in 4:
				var ang := t * 0.5 + TAU * k / 4.0
				var d := Vector2(cos(ang), sin(ang))
				var n := d.orthogonal()
				ci.draw_line(c, c + d * len, col.darkened(0.45), 2.0)
				ci.draw_colored_polygon(PackedVector2Array([c + d * len * 0.25 + n * 1.0, c + d * len + n * 1.0, c + d * len + n * len * 0.24, c + d * len * 0.25 + n * len * 0.24]), Color(col, 0.85))
			ci.draw_circle(c, 4.0, col.darkened(0.5))
		"ship":
			var x: float = fposmod(a.pos.x + t * a.speed - Scenery.X0, Scenery.X1 - Scenery.X0) + Scenery.X0
			var s: float = a.s
			var p := Vector2(x, a.pos.y + sin(t * 0.9 + a.pos.x) * 1.6)
			var hull: Color = a.hull
			var sail: Color = a.sail
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-38, -6) * s, p + Vector2(38, -6) * s, p + Vector2(28, 8) * s, p + Vector2(-30, 8) * s]), hull)
			ci.draw_line(p + Vector2(-34, -2) * s, p + Vector2(34, -2) * s, hull.lightened(0.25), 1.6)
			ci.draw_line(p + Vector2(0, -6) * s, p + Vector2(0, -62) * s, hull.darkened(0.3), 2.0)
			if a.get("funnel", false):
				ci.draw_rect(Rect2(p + Vector2(-8, -30) * s, Vector2(10, 24) * s), hull.lightened(0.1))
				for i in 3:
					var ph := fmod(t * 0.3 + i / 3.0, 1.0)
					ci.draw_circle(p + Vector2(-3 - ph * 26, -34 - ph * 30) * s, (5.0 + ph * 12.0) * s, Color(0.5, 0.48, 0.46, 0.35 * (1.0 - ph)))
			else:
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-22, -58) * s, p + Vector2(22, -54) * s, p + Vector2(18, -18) * s, p + Vector2(-18, -16) * s]), sail)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -60) * s, p + Vector2(14, -66) * s, p + Vector2(0, -70) * s]), Color("b8503a"))
		"aurora":
			var cols: Array = a.cols
			for i in cols.size():
				var pts := PackedVector2Array()
				var x := left - off
				while x < right - off:
					pts.append(Vector2(x, 150.0 + i * 46.0 + 50.0 * sin(x * 0.0035 + t * 0.22 + i * 1.7) + 24.0 * sin(x * 0.011 + t * 0.4)))
					x += 48.0
				var c: Color = cols[i]
				ci.draw_polyline(pts, Color(c, 0.05), 46.0)
				ci.draw_polyline(pts, Color(c, 0.09), 22.0)
				ci.draw_polyline(pts, Color(c, 0.16), 8.0)
		"cart":
			var pts: PackedVector2Array = a.pts
			var a0: Vector2 = pts[0]
			var a1: Vector2 = pts[pts.size() - 1]
			var length := a0.distance_to(a1)
			var d := fposmod(a.phase * length + t * a.speed, length)
			var c: Vector2 = a0.lerp(a1, d / length) + Vector2(0, sin(t * 9.0 + a.phase * 20.0) * 0.4)
			var col: Color = a.col
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -11), c + Vector2(9, -11), c + Vector2(7, -3), c + Vector2(-7, -3)]), col)
			for k in 3:
				ci.draw_circle(c + Vector2(-5 + k * 5.0, -13 - (k % 2) * 2.0), 3.6, Color("3e3a3a").lightened(0.05 * k))
			ci.draw_circle(c + Vector2(-5, -1), 2.6, Color("2a2826"))
			ci.draw_circle(c + Vector2(5, -1), 2.6, Color("2a2826"))
		"wheel":
			var p: Vector2 = a.pos
			var r: float = a.r
			var col: Color = a.col
			ci.draw_arc(p, r, 0.0, TAU, 18, col, 2.5)
			for k in 6:
				var ang := t * 1.4 + TAU * k / 6.0
				ci.draw_line(p, p + Vector2(cos(ang), sin(ang)) * r, col, 1.6)
		"bucket":
			var u := fposmod(a.phase + t * a.speed, 1.0)
			var w := u * 2.0 if u < 0.5 else (1.0 - u) * 2.0
			var pa: Vector2 = a.a
			var pb: Vector2 = a.b
			var q := pa.lerp(pb, w)
			q.y += sin(w * PI) * float(a.sag)
			var col: Color = a.col
			ci.draw_line(q, q + Vector2(0, 9), col, 1.4)
			ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-8, 9), q + Vector2(8, 9), q + Vector2(6, 20), q + Vector2(-6, 20)]), col.darkened(0.2))
			ci.draw_circle(q + Vector2(0, 8), 4.5, Color("3e3a3a"))
		"fall":
			var top: Vector2 = a.top
			var length: float = a.length
			for i in 7:
				var ph := fmod(t * 0.55 + i / 7.0, 1.0)
				var y0 := top.y + ph * length * 0.85
				ci.draw_line(Vector2(top.x + sin(i * 2.3) * 4.0, y0), Vector2(top.x + sin(i * 2.3) * 4.0, y0 + length * 0.15), Color(1, 1, 1, 0.5 * sin(ph * PI)), 2.4)
		"shimmer":
			for i in 12:
				var x := left - off + fposmod(i * 173.0 + t * 20.0, right - left)
				ci.draw_line(Vector2(x, 580 + i * 9), Vector2(x + 40, 580 + i * 9), a.col, 1.5)
