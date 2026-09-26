class_name LanePanel
extends PanelContainer
## Bottom-centre panel (GDD §13.9): the lane map (both gates, a dot per unit, the camera window; click to
## move the camera) and under it the unit in training with its progress and the 5-slot queue.

## Horizontal room left for the unit cards and the turret slots at 1920 px.
const LEFT := 512.0
const RIGHT := 486.0

var hud: MatchHud
var _map: LaneMap
var _train: TrainRow


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = LEFT
	offset_right = -RIGHT
	offset_top = -12
	offset_bottom = -12
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_map = LaneMap.new()
	_map.hud = hud
	_map.custom_minimum_size = Vector2(0, 30)
	v.add_child(_map)
	_train = TrainRow.new()
	_train.hud = hud
	_train.custom_minimum_size = Vector2(0, 40)
	v.add_child(_train)


func refresh() -> void:
	_map.queue_redraw()
	_train.queue_redraw()


class LaneMap extends Control:
	var hud: MatchHud

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			hud.view._cam_x = e.position.x / size.x * hud.sim.rules.lane_length

	func _draw() -> void:
		var sim := hud.sim
		var lane := sim.rules.lane_length
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		var fx := sim.front_x / lane * size.x
		draw_rect(Rect2(0, 0, fx, size.y), Color(hud.view.team_color(0), 0.18))
		draw_rect(Rect2(fx, 0, size.x - fx, size.y), Color(hud.view.team_color(1), 0.18))
		for i in 2:
			draw_rect(Rect2(0.0 if i == 0 else size.x - 5.0, 0, 5, size.y), hud.view.team_color(i))
		for s in sim.sides:
			for u in s.units:
				var x := sim.to_world(u.side, u.progress) / lane * size.x
				var r := 3.5 if u.def.role == "heavy" else 2.5
				draw_circle(Vector2(x, size.y * 0.5 + (u.id % 3 - 1) * 4), r, hud.view.team_color(u.side).lightened(0.3))
		draw_line(Vector2(fx, 0), Vector2(fx, size.y), Color.WHITE, 2.0)
		var vp := hud.view.get_viewport_rect().size
		var cx := hud.view.camera.get_screen_center_position().x
		# The camera may show a little beyond the gates; keep its window inside the map.
		var a := clampf((cx - vp.x * 0.5) / lane * size.x, 0.0, size.x)
		var b := clampf((cx + vp.x * 0.5) / lane * size.x, 0.0, size.x)
		draw_rect(Rect2(a, 0, b - a, size.y), Color(1, 1, 1, 0.6), false, 1.0)


class TrainRow extends Control:
	var hud: MatchHud

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sim := hud.sim
		var me := sim.sides[0]
		var race := hud.view.race_of(0)
		var f := UiStyle.font("bold")
		var dim := Color(1, 1, 1, 0.75)
		var y := size.y * 0.5 + 5.0
		draw_string(f, Vector2(4, y), "Training", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
		var bar := Rect2(170, size.y * 0.5 - 5.0, 150, 10)
		draw_rect(bar, Color(0, 0, 0, 0.5))
		if me.queue.is_empty():
			draw_string(f, Vector2(80, y), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
		else:
			var d := me.queue[0]
			draw_string(f, Vector2(80, y), hud.view.race_def(0).unit_name(d), HORIZONTAL_ALIGNMENT_LEFT, 86, 16, UiStyle.TEXT)
			var p := 0.0 if me.is_evolving() else clampf(me.train_progress / d.train_time, 0.0, 1.0)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), MatchHud.ACCENT)
		draw_rect(bar, Color(1, 1, 1, 0.2), false, 1.0)
		draw_string(f, Vector2(336, y), "Queue", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
		for i in sim.rules.queue_slots:
			var r := Rect2(390 + i * 36, size.y * 0.5 - 15.0, 30, 30)
			draw_rect(r, Color(0, 0, 0, 0.4))
			if i < me.queue.size():
				var q := me.queue[i]
				var sc := 24.0 / UnitArt.height_for(q, race)
				UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, r.position + Vector2(15, 28)))
				UnitArt.draw_unit(self, q, hud.view.team_color(0), {"t": 0.0}, i, race)
				draw_set_transform(Vector2.ZERO)
			draw_rect(r, MatchHud.ACCENT if i == 0 and not me.queue.is_empty() else Color(1, 1, 1, 0.15), false, 1.0)
		draw_string(f, Vector2(390 + sim.rules.queue_slots * 36 + 12, y), "On field %d/%d" % [me.units.size(), sim.rules.field_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, dim)
