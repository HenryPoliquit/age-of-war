class_name GameSettings
extends RefCounted
## Player settings (GDD §14), persisted to user://settings.cfg and applied live.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"ui_volume": 0.7,
	"shake": 1.0,
	"flash_reduction": false,
	"vfx_preset": 2,  # 0 Low, 1 Medium, 2 High (GDD §16)
	"colourblind": false,
	"day_night": true,
}

static var values: Dictionary = {}
static var _loaded := false


static func get_value(key: String) -> Variant:
	if not _loaded:
		load_settings()
	return values.get(key, DEFAULTS[key])


static func set_value(key: String, v: Variant) -> void:
	if not _loaded:
		load_settings()
	values[key] = v
	apply_audio()
	save_settings()


static func load_settings() -> void:
	_loaded = true
	values = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = cf.get_value("settings", k, DEFAULTS[k])
	apply_audio()


static func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)


static func apply_audio() -> void:
	AudioDirector.ensure_buses()
	for pair in [["Music", "music_volume"], ["SFX", "sfx_volume"], ["UI", "ui_volume"]]:
		var i := AudioServer.get_bus_index(pair[0])
		var v: float = values.get(pair[1], DEFAULTS[pair[1]])
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


## Particle count multiplier for the VFX preset.
static func particle_scale() -> float:
	return [0.5, 0.75, 1.0][int(get_value("vfx_preset"))]


static func lights_enabled() -> bool:
	return int(get_value("vfx_preset")) >= 1


## A settings panel usable from the menu and in-match. `on_close` runs when it's dismissed.
static func make_panel(on_close: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -260
	p.offset_right = 260
	p.offset_top = -220
	p.offset_bottom = 210
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_override("font", UiStyle.font("title"))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", MatchHud.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	for spec in [["Music volume", "music_volume"], ["Effects volume", "sfx_volume"], ["Interface volume", "ui_volume"], ["Screen shake", "shake"]]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = spec[0]
		l.custom_minimum_size = Vector2(190, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = get_value(spec[1])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value_changed.connect(func(x): set_value(spec[1], x))
		row.add_child(s)
		v.add_child(row)
	var vfx := OptionButton.new()
	for n in ["Effects: Low", "Effects: Medium", "Effects: High"]:
		vfx.add_item(n)
	vfx.select(int(get_value("vfx_preset")))
	vfx.item_selected.connect(func(i): set_value("vfx_preset", i))
	v.add_child(vfx)
	for spec in [["Day/night cycle", "day_night"], ["Reduce flashing", "flash_reduction"], ["Colour-blind team palette", "colourblind"]]:
		var c := CheckBox.new()
		c.text = spec[0]
		c.button_pressed = get_value(spec[1])
		c.toggled.connect(func(on): set_value(spec[1], on))
		v.add_child(c)
	var close := Button.new()
	close.text = "Done"
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func():
		p.queue_free()
		on_close.call())
	v.add_child(close)
	return p
