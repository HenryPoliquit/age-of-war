class_name FrontLayer
extends Backdrop
## In front of the lane: the age's weather and foreground props, split at the front line with the
## same seam as the backdrop (each side keeps its own weather). Inherits the seam/dissolve plumbing.


func has_layers() -> bool:
	return false


func setup(p_side: int, p_age: int) -> void:
	super.setup(p_side, p_age)
	_mat.set_shader_parameter("opaque_left", false)
	_mat.set_shader_parameter("grain", 0.0)


func _draw() -> void:
	var sc := Scenery.for_age(age)
	var vp := get_viewport_rect().size
	var left := cam_x - vp.x * 0.5 - 40
	var right := cam_x + vp.x * 0.5 + 40
	var t := time
	_draw_weather(sc.weather, left, right, vp, t)
	draw_set_transform(Vector2(cam_x * (1.0 - Scenery.FRONT_FACTOR), 0))
	for sh in sc.front:
		_draw_shape(sh)
	draw_set_transform(Vector2.ZERO)


## Stateless particles: positions are a function of time and index, so nothing to simulate or pool.
func _draw_weather(w: Dictionary, left: float, right: float, vp: Vector2, t: float) -> void:
	if w.is_empty():
		return
	var width := right - left
	var col: Color = w.col
	var n: int = w.n
	if GameSettings.particle_scale() < 1.0:
		n = int(n * GameSettings.particle_scale())
	for i in n:
		var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(i * 78.233) * 12543.123, 1.0)
		var h3 := fposmod(sin(i * 39.425) * 9631.77, 1.0)
		match w.kind:
			"motes":
				var x := left + fposmod(h1 * width + t * (8.0 + h3 * 14.0), width)
				var y := 560.0 + fposmod(h2 * 320.0 - t * (4.0 + h3 * 6.0), 320.0) + sin(t * 0.8 + i) * 10.0
				draw_circle(Vector2(x, y), 0.8 + h3 * 1.0, Color(col, col.a * 0.6 * (0.4 + 0.6 * sin(t * 1.3 + i * 2.1) ** 2)))
			"gulls":
				var x := left + fposmod(h1 * width + t * (30.0 + h3 * 30.0), width + 200) - 100
				var y := 140.0 + h2 * 260.0 + sin(t * 0.7 + i) * 18.0
				var flap := sin(t * 6.0 + i * 1.7) * 5.0
				draw_polyline(PackedVector2Array([Vector2(x - 9, y - flap), Vector2(x, y), Vector2(x + 9, y - flap)]), col, 2.0)
			"drizzle", "rain", "neon_rain":
				var speed := 900.0 if w.kind == "rain" else 520.0
				var len := 26.0 if w.kind == "rain" else 16.0
				var x := left + fposmod(h1 * width - t * speed * 0.18, width)
				var y := -60.0 + fposmod(h2 * 1100.0 + t * speed * (0.8 + h3 * 0.4), 1100.0)
				var c := col
				if w.kind == "neon_rain" and i % 3 == 0:
					c = Color("ff4fd8", col.a)
				draw_line(Vector2(x, y), Vector2(x - len * 0.18, y + len), c, 1.2 if w.kind != "rain" else 1.5)
				if y > Scenery.GROUND_Y and y < Scenery.GROUND_Y + 60 and w.kind == "rain":
					draw_arc(Vector2(x, Scenery.GROUND_Y + 30.0 + h3 * 20.0), 3.0 + fposmod(t * 8.0 + i, 5.0), PI, TAU, 6, Color(c, 0.25), 1.0)
			"ash":
				var x := left + fposmod(h1 * width + sin(t * 0.6 + i) * 30.0 + t * 12.0, width)
				var y := fposmod(h2 * 1000.0 + t * (18.0 + h3 * 20.0), 1000.0) - 100.0
				if i % 5 == 0:
					# Embers rise instead of falling.
					y = 900.0 - fposmod(h2 * 1000.0 + t * (30.0 + h3 * 30.0), 1000.0)
					draw_circle(Vector2(x, y), 1.6, Color(1.0, 0.55 + 0.3 * h3, 0.2, 0.8 * (0.5 + 0.5 * sin(t * 5.0 + i))))
				else:
					draw_rect(Rect2(Vector2(x, y), Vector2(2.5, 2.0)), col)
