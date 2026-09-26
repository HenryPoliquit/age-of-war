class_name TurretBar
extends PanelContainer
## Bottom-right turret slots (GDD §6, §13.9). Clicking a slot opens, directly above it, either the
## era's turrets to build or a Sell option; clicking the next locked slot unlocks it.

var hud: MatchHud
## The build/sell menu. A plain panel, not a popup Window: a Window would take every click and key
## (no camera drag, no hotkeys) until closed. It closes on any click outside it.
var menu: PanelContainer
var _slots: Array[Button] = []
var _options: VBoxContainer


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = -12
	offset_right = -12
	offset_top = -12
	offset_bottom = -12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in 4:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(104, 96)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func(): open_menu(i))
		row.add_child(b)
		_slots.append(b)
	menu = PanelContainer.new()
	menu.top_level = true
	menu.visible = false
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	menu.add_child(_options)
	add_child(menu)


func open_menu(i: int) -> void:
	var sim := hud.sim
	var st := HudModel.slot_state(sim, 0, i, hud.view.race_def(0))
	match st.kind:
		"unlock":
			menu.visible = false
			hud.feedback(sim.unlock_slot(0))
			return
		"locked":
			menu.visible = false
			hud.feedback(false)
			return
	for c in _options.get_children():
		_options.remove_child(c)
		c.queue_free()
	if st.kind == "built":
		var t: SimTurret = sim.sides[0].turrets[i]
		_add_option("Sell for %d g" % HudModel.sell_value(sim, t), true, func(): hud.feedback(sim.sell_turret(0, i)))
	else:
		for o in HudModel.build_options(sim, 0, hud.view.race_def(0)):
			var def: TurretDef = o.def
			_add_option(o.text, o.enabled, func(): hud.feedback(sim.build_turret(0, i, def)))
	# Open like a drop-down, directly above the clicked slot, kept on screen.
	var r := _slots[i].get_global_rect()
	var sz := menu.get_combined_minimum_size()
	var pos := Vector2(r.position.x + r.size.x * 0.5 - sz.x * 0.5, r.position.y - sz.y - 6.0)
	if is_inside_tree():
		pos.x = clampf(pos.x, 4.0, get_viewport_rect().size.x - sz.x - 4.0)
	menu.size = sz
	menu.global_position = pos
	menu.visible = true


## Any mouse press outside the menu closes it; the press is not consumed, so it still pans the camera,
## hits a slot (which reopens the menu there) and so on.
func _input(e: InputEvent) -> void:
	if menu.visible and e is InputEventMouseButton and e.pressed and not menu.get_global_rect().has_point(e.position):
		menu.visible = false


func _add_option(text: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		menu.visible = false
		cb.call())
	_options.add_child(b)


func refresh() -> void:
	var race := hud.view.race_def(0)
	for i in 4:
		var st := HudModel.slot_state(hud.sim, 0, i, race)
		var b := _slots[i]
		b.text = "%s\n%s" % ["QWER"[i], st.text]
		b.tooltip_text = st.tooltip
		if st.get("outclassed", false):
			b.modulate = Color(1, 0.75, 0.6)
		elif st.kind == "locked":
			b.modulate = Color(1, 1, 1, 0.55)
		else:
			b.modulate = Color.WHITE
