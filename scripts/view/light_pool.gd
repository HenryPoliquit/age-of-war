class_name LightPool
extends Node2D
## Short-lived 2D lights (GDD §13.4 "Lights", §16 "pooled, per-frame cap, oldest culled first") and
## the per-age ambient tint. Muzzle flashes, explosions and abilities light nearby units and ground.

const MAX_LIGHTS := 10
## Ambient multiplier per age: night and storm ages sit darker so lights read.
const AMBIENT := [Color(1.0, 0.97, 0.93), Color(1.0, 1.0, 1.0), Color(0.93, 0.95, 0.95),
	Color(0.8, 0.83, 0.92), Color(0.9, 0.84, 0.8), Color(0.76, 0.74, 0.9)]

var enabled := true
var _lights: Array[PointLight2D] = []
var _state: Array[Dictionary] = []
var _next := 0
var _ambient: CanvasModulate


func _ready() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	tex.gradient = g
	for i in MAX_LIGHTS:
		var l := PointLight2D.new()
		l.texture = tex
		l.enabled = false
		l.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(l)
		_lights.append(l)
		_state.append({"born": 0.0, "life": 0.0, "energy": 0.0})
	_ambient = CanvasModulate.new()
	add_child(_ambient)


## Lights up a radius around `pos` for `life` seconds (decays from `energy`).
func flash(pos: Vector2, col: Color, energy: float, radius: float, life: float, now: float) -> void:
	if not enabled:
		return
	var i := _next
	_next = (_next + 1) % MAX_LIGHTS
	var l := _lights[i]
	l.position = pos
	l.color = col
	l.texture_scale = radius / 128.0
	l.energy = energy
	l.enabled = true
	_state[i] = {"born": now, "life": life, "energy": energy}


func update(now: float, ambient: Color) -> void:
	_ambient.color = ambient
	for i in MAX_LIGHTS:
		var l := _lights[i]
		if not l.enabled:
			continue
		var st: Dictionary = _state[i]
		var u: float = (now - st.born) / maxf(0.001, st.life)
		if u >= 1.0 or not enabled:
			l.enabled = false
		else:
			l.energy = st.energy * (1.0 - u) * (1.0 - u)
