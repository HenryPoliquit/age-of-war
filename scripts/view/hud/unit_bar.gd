class_name UnitBar
extends PanelContainer
## Bottom-left unit cards (GDD §13.9): portrait, name, price and hotkey 1–4; click to queue.

const CARD := Vector2(112, 100)

var hud: MatchHud
var _cards: Array[UnitCard] = []


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 12
	offset_right = 12
	offset_top = -12
	offset_bottom = -12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in 4:
		var c := UnitCard.new()
		c.hud = hud
		c.index = i
		c.custom_minimum_size = CARD
		c.pressed.connect(func(): hud.feedback(hud.sim.queue_unit(0, hud.sim.roster(0)[i]) if i < hud.sim.roster(0).size() else false))
		row.add_child(c)
		_cards.append(c)


func refresh() -> void:
	for c in _cards:
		c.refresh()
		c.queue_redraw()


class UnitCard extends Button:
	var hud: MatchHud
	var index := 0

	func refresh() -> void:
		var roster := hud.sim.roster(0)
		if index >= roster.size():
			disabled = true
			tooltip_text = "No %s this era" % HudModel.ROLE_NAME[MatchSim.ROLES[index]]
			return
		var u := roster[index]
		disabled = not hud.sim.can_queue(0, u)
		tooltip_text = HudModel.unit_tooltip(hud.sim, 0, u, hud.view.race_def(0))

	func _draw() -> void:
		var sim := hud.sim
		var roster := sim.roster(0)
		var f := UiStyle.font("bold")
		draw_string(f, Vector2(6, 16), "%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MatchHud.ACCENT)
		if index >= roster.size():
			draw_string(f, Vector2(0, size.y * 0.5), "Siege from %s" % sim.data.age(2).display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(1, 1, 1, 0.3))
			return
		var u := roster[index]
		var race := hud.view.race_of(0)
		var h := UnitArt.height_for(u, race)
		var sc := clampf((size.y - 46.0) / h, 0.35, 1.0)
		UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(size.x * 0.5, size.y - 36.0)))
		UnitArt.draw_unit(self, u, hud.view.team_color(0), {"walk": 0.0, "moving": false, "atk": -1.0, "t": Time.get_ticks_msec() / 1000.0, "flash": 0.0}, index + 3, race)
		draw_set_transform(Vector2.ZERO)
		var col := Color.WHITE if not disabled else Color(1, 1, 1, 0.4)
		draw_string(f, Vector2(0, size.y - 20.0), hud.view.race_def(0).unit_name(u), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, col)
		draw_string(f, Vector2(0, size.y - 5.0), "%d g" % sim.unit_price(0, u), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, MatchHud.GOLD if not disabled else Color(MatchHud.GOLD, 0.4))
