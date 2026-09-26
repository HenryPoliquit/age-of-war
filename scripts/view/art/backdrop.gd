class_name Backdrop
extends Node2D
## One side's half of the split battlefield (GDD §13.6). Draws that side's age scenery across the
## whole view; a shader keeps only its half, cut at the front line with a painterly noisy seam.
## On evolution the previous age stays underneath while the new one dissolves in (GDD §13.5 step 3).

const SHADER := preload("res://shaders/split_backdrop.gdshader")

var side := 0
var age := 1
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


func setup(p_side: int, p_age: int) -> void:
	side = p_side
	age = p_age
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("side", float(side))
	_mat.set_shader_parameter("dissolve", 1.0)
	material = _mat


func set_age(new_age: int) -> void:
	if new_age == age:
		return
	if _old != null:
		_old.queue_free()
	_old = get_script().new()
	_old.setup(side, age)
	_old.show_behind_parent = true
	add_child(_old)
	age = new_age
	_dissolve = 0.0


func _process(delta: float) -> void:
	var vp := get_viewport()
	var seam_screen := (vp.get_canvas_transform() * Vector2(seam_x, 0)).x
	var seam_uv := seam_screen / vp.get_visible_rect().size.x
	_mat.set_shader_parameter("seam", seam_uv)
	if _old != null:
		_old.cam_x = cam_x
		_old.time = time
		_old._mat.set_shader_parameter("seam", seam_uv)
		_dissolve = minf(1.0, _dissolve + delta / 1.6)
		_mat.set_shader_parameter("dissolve", _dissolve)
		if _dissolve >= 1.0:
			_old.queue_free()
			_old = null
	queue_redraw()


func _draw() -> void:
	var sc := Scenery.for_age(age)
	var pal := sc.palette
	var cam := Vector2(cam_x, 0)
	var vp := get_viewport_rect().size
	var left := cam.x - vp.x * 0.5 - 60
	var right := cam.x + vp.x * 0.5 + 60
	var t := time
	# Sky gradient in view space.
	var sky: Array = pal.sky
	var top: Color = sky[0]
	var horizon: Color = sky[1]
	if dn != null:
		var k: float = DayNight.STRENGTH[age - 1]
		top = top.lerp(Color("0b1030"), (1.0 - dn.daylight) * k)
		horizon = horizon.lerp(Color("2a3358"), (1.0 - dn.daylight) * k).lerp(Color("f08a5a"), dn.twilight * 0.5 * k)
	draw_polygon(PackedVector2Array([Vector2(left, -400), Vector2(right, -400), Vector2(right, Scenery.GROUND_Y), Vector2(left, Scenery.GROUND_Y)]),
		PackedColorArray([top, top, horizon, horizon]))
	if dn != null and age != 6 and dn.stars() > 0.0:
		_draw_stars(left, right, dn.stars())
	if pal.sun_r > 0.0:
		var sp := Vector2(left + (right - left) * pal.sun_pos.x, pal.sun_pos.y)
		var body: Color = pal.sun
		var r: float = pal.sun_r
		if dn != null and age != 6:
			var bp := dn.body_pos()
			sp = Vector2(left + (right - left) * bp.x, bp.y)
			if dn.is_night():
				body = Color(0.9, 0.93, 1.0)
				r = 30.0
			else:
				body = body.lerp(Color("ff9a5a"), dn.twilight * 0.6)
		for i in 5:
			draw_circle(sp, r * (1.0 + i * 0.6), Color(body, 0.12 - i * 0.02))
		draw_circle(sp, r, body)
	for li in sc.layers.size():
		var layer: Dictionary = sc.layers[li]
		var off: float = cam.x * (1.0 - layer.factor)
		draw_set_transform(Vector2(off, 0))
		for sh in layer.shapes:
			_draw_shape(sh)
		for a in sc.anims:
			if a.get("layer", -1) == li:
				_draw_anim(a, t, off, left, right)
	draw_set_transform(Vector2.ZERO)
	for a in sc.anims:
		if a.type == "lightning" and not GameSettings.get_value("flash_reduction"):
			var k := fmod(t, 7.3)
			if k < 0.12 or (k > 0.2 and k < 0.27):
				draw_rect(Rect2(left, -400, right - left, Scenery.GROUND_Y + 800), Color(0.85, 0.9, 1.0, 0.18))


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
	if sh.has("cols"):
		draw_polygon(sh.poly, sh.cols)
	elif sh.has("poly"):
		draw_colored_polygon(sh.poly, sh.col)
	elif sh.has("circle"):
		draw_circle(sh.circle, sh.r, sh.col)
	elif sh.has("line"):
		draw_line(sh.line, sh.to, sh.col, sh.w)
	elif sh.has("polyline"):
		draw_polyline(sh.polyline, sh.col, sh.w)
	elif sh.has("grad"):
		var r: Rect2 = sh.grad
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([sh.top, sh.top, sh.bottom, sh.bottom]))


func _draw_anim(a: Dictionary, t: float, off: float, left: float, right: float) -> void:
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
					draw_circle(p + Vector2(k * 3.0, -k * 2.0), r * (1.0 - k * 0.25), Color(c, fade * 0.4))
		"flag":
			var p: Vector2 = a.pos
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(p + Vector2(i * 6.0, sin(t * 4.0 - i * 0.8) * 2.5 * i / 5.0))
			for i in range(5, -1, -1):
				pts.append(p + Vector2(i * 6.0, 20.0 + sin(t * 4.0 - i * 0.8) * 2.5 * i / 5.0))
			draw_colored_polygon(pts, a.col)
		"lamp":
			var fl := (0.85 + 0.15 * sin(t * 3.0 + a.pos.x)) * (1.0 + (1.0 - dn.daylight) * 1.2 if dn != null else 1.0)
			for i in 3:
				draw_circle(a.pos, a.r * (0.4 + i * 0.3), Color(a.col, 0.08 * fl))
		"sign":
			var r: Rect2 = a.rect
			var on := fmod(t + r.position.x * 0.013, 5.0) > 0.18
			var c: Color = a.col
			draw_rect(r.grow(8), Color(c, 0.08 if on else 0.02))
			draw_rect(r, Color(c, 0.22 if on else 0.05))
			draw_rect(r, Color(c, 0.9 if on else 0.2), false, 2.0)
			for i in 3:
				draw_line(r.position + Vector2(10, 12 + i * 12), r.position + Vector2(r.size.x * (0.4 + 0.15 * i), 12 + i * 12), Color(c, 0.7 if on else 0.1), 3.0)
		"drone":
			var x: float = fposmod(a.pos.x + t * a.speed - Scenery.X0, Scenery.X1 - Scenery.X0) + Scenery.X0
			var p := Vector2(x, a.pos.y + sin(t * 2.0 + a.pos.x) * 6.0)
			draw_rect(Rect2(p - Vector2(7, 2), Vector2(14, 4)), Color("30324a"))
			draw_circle(p + Vector2(0, 3), 2.0, Color("ff4fd8") if fmod(t, 1.0) < 0.5 else Color("37e7ff"))
		"shimmer":
			for i in 12:
				var x := left - off + fposmod(i * 173.0 + t * 20.0, right - left)
				draw_line(Vector2(x, 580 + i * 9), Vector2(x + 40, 580 + i * 9), a.col, 1.5)
