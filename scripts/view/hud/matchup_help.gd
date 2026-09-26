class_name MatchupHelp
extends Button
## Small ⚔ button under the top bar. Hovering it shows how hard each of your current units hits each of
## the enemy's current units and structures (damage type × armour, GDD §5.2).

const GOOD := Color("8fd98f")
const BAD := Color("e8867a")

var hud: MatchHud


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	text = "⚔"
	# Must be non-empty for Godot to ask for the custom tooltip below.
	tooltip_text = "Matchups"
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 20)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offset_left = 16
	offset_top = 74
	offset_right = 60
	offset_bottom = 114


func _make_custom_tooltip(_for_text: String) -> Object:
	var t := HudModel.matchup_table(hud.sim, 0, hud.view.race_def(0), hud.view.race_def(1))
	var panel := PanelContainer.new()
	panel.theme = UiStyle.theme()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_label(v, "Damage your units deal against theirs", UiStyle.ACCENT, 18)
	var grid := GridContainer.new()
	grid.columns = t.cols.size() + 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	_label(grid, "", UiStyle.TEXT)
	for c in t.cols:
		_label(grid, c, UiStyle.ACCENT)
	for r in t.rows:
		_label(grid, r.name, UiStyle.TEXT)
		for m in r.mults:
			_label(grid, "×%.2f" % m, GOOD if m > 1.001 else (BAD if m < 0.999 else UiStyle.TEXT)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(v, "Above ×1 hits harder, below ×1 hits softer.", Color(UiStyle.TEXT, 0.7), 14)
	return panel


func _label(parent: Control, text: String, col: Color, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l
