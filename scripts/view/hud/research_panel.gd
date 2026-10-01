class_name ResearchPanel
extends PanelContainer
## Drop-down XP research panel under the top bar (GDD §6.2, §13.9): a row per group (Fortifications,
## Logistics, Skills, Ascension) with a button per perk. It shows the perk, its level pips and the XP price;
## a perk that opens in a later era shows that era. Mouse only; the game keeps running while it is open.

var hud: MatchHud
var _cells := {}    # research id -> Button
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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var title := hud._label(col, "Research — spend XP; each level costs a share of your next evolution", 15, MatchHud.XP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	var by_group := {}
	for def in hud.sim.data.research:
		if not by_group.has(def.group):
			by_group[def.group] = []
		by_group[def.group].append(def)
	for group in HudModel.RESEARCH_GROUPS:
		var name_label := hud._label(grid, HudModel.RESEARCH_GROUPS[group], 16, UiStyle.ACCENT)
		name_label.custom_minimum_size = Vector2(130, 0)
		var defs: Array = by_group.get(group, [])
		for c in 4:
			if c >= defs.size():
				hud._label(grid, "")
				continue
			var def: ResearchDef = defs[c]
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(170, 50)
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_font_size_override("font_size", 15)
			b.pressed.connect(func(): hud.feedback(hud.sim.buy_research(0, def.id)))
			grid.add_child(b)
			_cells[def.id] = b


func refresh() -> void:
	if not visible:
		return
	var sim := hud.sim
	for id in _cells:
		var b: Button = _cells[id]
		var cell := HudModel.research_cell(sim, 0, id)
		b.text = cell.text
		b.tooltip_text = cell.tooltip
		b.disabled = not cell.enabled
		if cell.maxed:
			b.add_theme_stylebox_override("disabled", _max_box)
		else:
			b.remove_theme_stylebox_override("disabled")
