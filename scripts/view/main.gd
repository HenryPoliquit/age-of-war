extends Control
## Main menu and Skirmish setup (GDD §12.1). Hosts one MatchView at a time.

var _menu: VBoxContainer
var _personality: OptionButton
var _difficulty: OptionButton
var _start_age: OptionButton
var _race: OptionButton
var _enemy_race: OptionButton
var _r_ids: Array[StringName] = []
var _match: MatchView
var _p_ids: Array[StringName] = []
var _d_ids: Array[StringName] = []


var _bg_root: Control
var _backdrops: Array[Backdrop] = []
var _parade: MenuParade
var _t := 0.0


var _audio: AudioDirector


func _ready() -> void:
	GameSettings.load_settings()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = MatchHud.make_theme()
	# Background: the split battlefield itself — Stone Age dawn meets Arcane night at a drifting seam.
	_bg_root = Control.new()
	_bg_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_root)
	var holder := Node2D.new()
	holder.position = Vector2(0, -60)
	_bg_root.add_child(holder)
	for i in 2:
		var b := Backdrop.new()
		b.setup(i, 1 if i == 0 else 6, &"human" if i == 0 else &"elf")
		holder.add_child(b)
		_backdrops.append(b)
	_parade = MenuParade.new()
	holder.add_child(_parade)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -270
	panel.offset_bottom = 250
	add_child(panel)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	panel.add_child(_menu)
	var title := Label.new()
	title.text = "TIMEFRONT"
	title.add_theme_font_override("font", UiStyle.font("title"))
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", MatchHud.ACCENT)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(title)
	var sub := Label.new()
	sub.text = "Six ages. One lane. Hold the front."
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(sub)
	var sep := HSeparator.new()
	_menu.add_child(sep)
	var data := GameData.get_default()
	for id in RaceLook.IDS:
		if data.races.has(id):
			_r_ids.append(id)
	_race = _race_picker("You play: ", data, 0)
	_enemy_race = _race_picker("Enemy: ", data, _r_ids.size())
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
	_start_age = OptionButton.new()
	for a in data.ages:
		_start_age.add_item("Start in: %s Age" % a.display_name)
	_menu.add_child(_start_age)
	_update_parade()
	var settings := Button.new()
	settings.text = "Settings"
	settings.alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings.pressed.connect(func():
		_menu.get_parent().visible = false
		add_child(GameSettings.make_panel(func(): _menu.get_parent().visible = true)))
	_menu.add_child(settings)
	if "--settings" in OS.get_cmdline_user_args():
		settings.pressed.emit.call_deferred()
	var start := Button.new()
	start.text = "Start skirmish"
	start.custom_minimum_size = Vector2(0, 54)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_start)
	_menu.add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	_menu.add_child(quit)
	_start_menu_music()
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
	# `--shots=N --every=S` saves N frames (path_0.png …) S seconds apart.
	var shots := 1
	var every := 1.0
	for b in OS.get_cmdline_user_args():
		if b.begins_with("--shots="):
			shots = int(b.get_slice("=", 1))
		elif b.begins_with("--every="):
			every = float(b.get_slice("=", 1))
	await get_tree().create_timer(after).timeout
	for i in shots:
		await RenderingServer.frame_post_draw
		var out := path if shots == 1 else path.get_basename() + "_%d.png" % i
		get_viewport().get_texture().get_image().save_png(out)
		print("screenshot saved: ", out)
		if i < shots - 1:
			await get_tree().create_timer(every).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	if not _bg_root.visible:
		return
	_t += delta
	var vp := get_viewport_rect().size
	for b in _backdrops:
		b.cam_x = vp.x * 0.5
		b.seam_x = vp.x * (0.5 + 0.12 * sin(_t * 0.25))
		b.time = _t
	_parade.seam_x = _backdrops[0].seam_x
	_parade.t = _t
	_parade.queue_redraw()


func _start() -> void:
	_menu.get_parent().visible = false
	_bg_root.visible = false
	if _audio != null:
		_audio.queue_free()
		_audio = null
	_match = MatchView.new()
	_match.personality_id = _p_ids[_personality.selected]
	_match.difficulty_id = _d_ids[_difficulty.selected]
	_match.colourblind = GameSettings.get_value("colourblind")
	_match.start_age = _start_age.selected + 1
	_match.races = [_picked_race(_race), _picked_race(_enemy_race)]
	_match.exit_to_menu.connect(_end_match.bind(false))
	_match.rematch.connect(_end_match.bind(true))
	get_tree().root.add_child.call_deferred(_match)


func _end_match(again: bool) -> void:
	_match.queue_free()
	_match = null
	if again:
		_start()
	else:
		_menu.get_parent().visible = true
		_bg_root.visible = true
		_start_menu_music()


func _race_picker(prefix: String, data: GameData, selected: int) -> OptionButton:
	var ob := OptionButton.new()
	for id in _r_ids:
		ob.add_item(prefix + data.races[id].display_name)
		ob.set_item_tooltip(ob.item_count - 1, data.races[id].description)
	ob.add_item(prefix + "Random race")
	ob.select(clampi(selected, 0, ob.item_count - 1))
	ob.item_selected.connect(func(_i): _update_parade())
	_menu.add_child(ob)
	return ob


func _picked_race(ob: OptionButton) -> StringName:
	if ob.selected < _r_ids.size():
		return _r_ids[ob.selected]
	return _r_ids[randi() % _r_ids.size()]


func _update_parade() -> void:
	if _parade == null or _race == null or _enemy_race == null:
		return
	for i in 2:
		var ob := _race if i == 0 else _enemy_race
		_parade.races[i] = _r_ids[ob.selected] if ob.selected < _r_ids.size() else _r_ids[(i + 1) % _r_ids.size()]
		_backdrops[i].race = _parade.races[i]


## Units of the two ages marching toward the seam behind the menu.
class MenuParade extends Node2D:
	var seam_x := 960.0
	var t := 0.0
	var races: Array[StringName] = [&"human", &"elf"]
	var _defs: Array[UnitDef] = []

	func _ready() -> void:
		var gd := GameData.get_default()
		for role in ["vanguard", "ranged", "heavy"]:
			_defs.append(gd.unit_for_role(1, role))
		for role in ["vanguard", "ranged", "heavy"]:
			_defs.append(gd.unit_for_role(6, role))

	func _draw() -> void:
		for i in 6:
			var side := 0 if i < 3 else 1
			var dir := 1.0 if side == 0 else -1.0
			var def := _defs[i]
			var lane := fposmod(t * def.speed * 0.6 + i * 170.0, 520.0)
			var x := seam_x - dir * (560.0 - lane)
			var pos := Vector2(x, WorldLayer.GROUND_Y + (i % 3) * 5.0)
			UnitArt.begin(self, Transform2D(0.0, Vector2(dir, 1) * 1.25, 0.0, pos))
			UnitArt.draw_unit(self, def, MatchView.TEAM[side], {"walk": lane * 0.14, "moving": true, "atk": -1.0, "t": t + i, "flash": 0.0}, i, races[side])
			draw_set_transform(Vector2.ZERO)


func _start_menu_music() -> void:
	_audio = AudioDirector.new()
	add_child(_audio)
	_audio.start(1)
	_audio.target_intensity = 0.3
