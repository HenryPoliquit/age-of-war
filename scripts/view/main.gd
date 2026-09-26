extends Control
## Main menu and Skirmish setup (GDD §12.1). Hosts one MatchView at a time.

var _menu: VBoxContainer
var _personality: OptionButton
var _difficulty: OptionButton
var _colourblind: CheckBox
var _match: MatchView
var _p_ids: Array[StringName] = []
var _d_ids: Array[StringName] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("15171d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.offset_left = -220
	_menu.offset_right = 220
	_menu.offset_top = -200
	_menu.add_theme_constant_override("separation", 12)
	add_child(_menu)
	var title := Label.new()
	title.text = "TIMEFRONT"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)
	var sub := Label.new()
	sub.text = "Skirmish · graybox build"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(sub)
	var data := GameData.get_default()
	_personality = OptionButton.new()
	for id in data.personalities:
		var p: AiPersonalityDef = data.personalities[id]
		if not p.sim_only:
			_p_ids.append(id)
			_personality.add_item("Opponent: " + p.display_name)
	_personality.select(maxi(0, _p_ids.find(&"tactician")))
	_menu.add_child(_personality)
	_difficulty = OptionButton.new()
	for id in [&"easy", &"normal", &"hard", &"brutal", &"nightmare"]:
		if data.difficulties.has(id):
			_d_ids.append(id)
			_difficulty.add_item("Difficulty: " + data.difficulties[id].display_name)
	_difficulty.select(maxi(0, _d_ids.find(&"normal")))
	_menu.add_child(_difficulty)
	_colourblind = CheckBox.new()
	_colourblind.text = "Colour-blind team palette"
	_menu.add_child(_colourblind)
	var start := Button.new()
	start.text = "Start skirmish"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(_start)
	_menu.add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	_menu.add_child(quit)
	var args := OS.get_cmdline_user_args()
	if "--autostart" in args or "--autoplay" in args:
		_start.call_deferred()
	for a in args:
		# Dev aid for cloud sessions: `-- --autoplay --screenshot=out.png --after=20`
		if a.begins_with("--screenshot="):
			var after := 5.0
			for b in args:
				if b.begins_with("--after="):
					after = float(b.get_slice("=", 1))
			_screenshot.call_deferred(a.get_slice("=", 1), after)


func _screenshot(path: String, after: float) -> void:
	await get_tree().create_timer(after).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()


func _start() -> void:
	_menu.visible = false
	_match = MatchView.new()
	_match.personality_id = _p_ids[_personality.selected]
	_match.difficulty_id = _d_ids[_difficulty.selected]
	_match.colourblind = _colourblind.button_pressed
	_match.exit_to_menu.connect(_end_match.bind(false))
	_match.rematch.connect(_end_match.bind(true))
	get_tree().root.add_child.call_deferred(_match)


func _end_match(again: bool) -> void:
	_match.queue_free()
	_match = null
	if again:
		_start()
	else:
		_menu.visible = true
