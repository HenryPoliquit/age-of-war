class_name TopBar
extends PanelContainer
## Slim top bar (GDD §13.9): XP · Evolve · Skill | your era · clock · enemy era | Upgrades · gold ·
## speed · pause · settings. Renders HudModel values; acts only through MatchSim commands.

## Left and right groups share one minimum width so the centre group sits in the middle of the screen.
const SIDE_WIDTH := 620.0

var hud: MatchHud
var upgrades_button: Button
var _xp: Label
var _evolve: Button
var _evolve_meter: MatchHud.Meter
var _skill: Button
var _eras: Array[Label] = []
var _clock: Label
var _gold: Label
var _speed: Button
var _pause: Button
var _speed_before_pause := 0


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_left = 12
	offset_right = -12
	offset_top = 6
	offset_bottom = 54
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var left := HBoxContainer.new()
	left.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var xi := MatchHud.Icon.new()
	xi.kind = "xp"
	left.add_child(xi)
	_xp = hud._label(left, "", 18, MatchHud.XP)
	_xp.custom_minimum_size = Vector2(84, 0)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 2)
	left.add_child(ev)
	_evolve = hud._btn(ev, "", func(): hud.feedback(hud.sim.evolve(0)))
	_evolve.custom_minimum_size = Vector2(180, 30)
	_evolve_meter = MatchHud.Meter.new()
	_evolve_meter.col = MatchHud.XP
	_evolve_meter.custom_minimum_size = Vector2(0, 4)
	ev.add_child(_evolve_meter)
	_skill = hud._btn(left, "", func(): hud.feedback(hud.sim.fire_ability(0)))
	_skill.custom_minimum_size = Vector2(250, 34)

	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 18)
	row.add_child(mid)
	for i in 2:
		var era := hud._label(mid, "", 16, hud.view.team_color(i).lightened(0.4), true)
		_eras.append(era)
		if i == 0:
			_clock = hud._label(mid, "0:00", 22, UiStyle.TEXT, true)

	var right := HBoxContainer.new()
	right.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	upgrades_button = Button.new()
	upgrades_button.focus_mode = Control.FOCUS_NONE
	upgrades_button.text = "⬆ Upgrades"
	upgrades_button.toggle_mode = true
	upgrades_button.tooltip_text = "Show or hide the upgrade grid"
	upgrades_button.custom_minimum_size = Vector2(140, 34)
	right.add_child(upgrades_button)
	var gi := MatchHud.Icon.new()
	gi.kind = "gold"
	right.add_child(gi)
	_gold = hud._label(right, "", 18, MatchHud.GOLD)
	_gold.custom_minimum_size = Vector2(130, 0)
	_speed = _small(right, "1×", "Game speed: 1× / 2×", _toggle_speed)
	_pause = _small(right, "❚❚", "Pause", _toggle_pause)
	_pause.toggle_mode = true
	_small(right, "⚙", "Settings (Esc)", hud.open_settings)


func _small(parent: Control, text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.tooltip_text = tip
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(40, 34)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _toggle_speed() -> void:
	var v := hud.view
	if v.speed_index == 2:
		return
	v.set_speed(1 - v.speed_index)


func _toggle_pause() -> void:
	var v := hud.view
	if v.speed_index == 2:
		v.set_speed(_speed_before_pause)
	else:
		_speed_before_pause = v.speed_index
		v.set_speed(2)


func refresh() -> void:
	var sim := hud.sim
	var race := hud.view.race_def(0)
	_xp.text = "%d XP" % sim.sides[0].xp
	var ev := HudModel.evolve_state(sim, 0)
	_evolve.text = ev.text
	_evolve.tooltip_text = ev.tooltip
	_evolve.disabled = not ev.enabled
	_evolve_meter.value = ev.progress
	var sk := HudModel.skill_state(sim, 0, race)
	_skill.text = sk.text
	_skill.tooltip_text = sk.tooltip
	_skill.disabled = not sk.enabled
	for i in 2:
		_eras[i].text = HudModel.era_name(sim, i)
	_clock.text = HudModel.clock(sim)
	_gold.text = HudModel.gold_text(sim, 0)
	_gold.modulate = Color(1, 0.45, 0.45) if hud._flash > 0.0 else Color.WHITE
	_speed.text = "2×" if hud.view.speed_index == 1 else "1×"
	_pause.set_pressed_no_signal(hud.view.speed_index == 2)
