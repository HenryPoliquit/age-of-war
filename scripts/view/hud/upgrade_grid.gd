class_name UpgradeGrid
extends PanelContainer
## Drop-down upgrade grid under the top bar (GDD §6.1, §13.9): a row per unit slot (named after the
## current era's unit), Turrets and Income; columns ⚔ ♥ 🛡 (➶ Range for turrets). Mouse only; the game
## keeps running while it is open.

const ROWS := ["vanguard", "ranged", "heavy", "siege", "turret", "income"]

var hud: MatchHud
var _labels := {}   # row -> Label
var _cells := {}    # "row:stat" -> Button
var _max_box: StyleBox


func _init(p_hud: MatchHud) -> void:
	hud = p_hud
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -12
	offset_left = -12
	offset_top = 72
	offset_bottom = 72
	_max_box = UiStyle.box(Color(0.33, 0.26, 0.1), UiStyle.ACCENT)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	hud._label(grid, "")
	for head in ["⚔ Attack", "♥ Health", "🛡 Defence · ➶ Range"]:
		var l := hud._label(grid, head, 14, UiStyle.ACCENT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for row in ROWS:
		var name_label := hud._label(grid, "", 15)
		name_label.custom_minimum_size = Vector2(130, 0)
		_labels[row] = name_label
		var stats: Array = MatchSim.UPGRADES[row]
		for c in 3:
			if c >= stats.size():
				hud._label(grid, "")
				continue
			var stat: String = stats[c]
			var b := Button.new()
			b.custom_minimum_size = Vector2(150, 32)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_font_size_override("font_size", 14)
			b.pressed.connect(func(): hud.feedback(hud.sim.buy_upgrade(0, row, stat)))
			grid.add_child(b)
			_cells["%s:%s" % [row, stat]] = b


func refresh() -> void:
	if not visible:
		return
	var sim := hud.sim
	var race := hud.view.race_def(0)
	for row in ROWS:
		(_labels[row] as Label).text = HudModel.row_label(sim, 0, row, race)
		for stat in MatchSim.UPGRADES[row]:
			var b: Button = _cells["%s:%s" % [row, stat]]
			var cell := HudModel.upgrade_cell(sim, 0, row, stat)
			b.text = cell.text
			b.tooltip_text = cell.tooltip
			b.disabled = not cell.enabled
			if cell.maxed:
				b.add_theme_stylebox_override("disabled", _max_box)
			else:
				b.remove_theme_stylebox_override("disabled")
