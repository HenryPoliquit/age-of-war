class_name MatchHud
extends CanvasLayer
## Match HUD (GDD §13.9): top status bar with both bases, lane minimap, unit cards with portraits,
## command panel (economy, ability, evolve/veterancy, Forge, turrets, stance, speed), doctrine
## choice, event banners and the post-match screen. Reads MatchSim; acts only through its commands.

const ACCENT := UiStyle.ACCENT
const PANEL_BG := Color(0.06, 0.07, 0.1, 0.84)
const GOLD := Color("f2c14e")
const XP := Color("8fd0ff")

var view: MatchView
var sim: MatchSim:
	get:
		return view.sim
var shake_scale := 1.0

var _root: Control
var _theme: Theme
var _hp: Array[ProgressBar] = []
var _age_labels: Array[Label] = []
var _doc_labels: Array[Label] = []
var _clock: Label
var _tide: TidePips
var _minimap: Minimap
var _cards: Array[UnitCard] = []
var _queue: QueueStrip
var _gold: Label
var _xp: Label
var _momentum: Meter
var _ability: Button
var _evolve: Button
var _evolve_meter: Meter
var _vet: Button
var _forge: Button
var _slots: Array[Button] = []
var _stance: Button
var _speed_buttons: Array[Button] = []
var _slot_menu: PopupMenu
var _slot_menu_index := -1
var _doctrine_panel: PanelContainer
var _doctrine_box: HBoxContainer
var _banner: Label
var _banner_sub: Label
var _banner_t := -10.0
var _post: PanelContainer
var _flash := 0.0


func _ready() -> void:
	_theme = make_theme()
	_root = Control.new()
	_root.theme = _theme
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_top()
	_build_cards()
	_build_commands()
	_build_doctrine()
	_build_banner()
	_slot_menu = PopupMenu.new()
	_slot_menu.id_pressed.connect(_on_slot_menu)
	_root.add_child(_slot_menu)


# ---------------------------------------------------------------------------
# Theme and building blocks

static func _box(bg: Color, border := Color(0, 0, 0, 0), radius := 8, width := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(8)
	sb.anti_aliasing = true
	return sb


static func make_theme() -> Theme:
	return UiStyle.theme()


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


func _label(parent: Control, text := "", size := 16, col := UiStyle.TEXT, title := false) -> Label:
	var l := Label.new()
	l.text = text
	if title:
		l.add_theme_font_override("font", UiStyle.font("title"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_top() -> void:
	var bar := _panel(_root)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 8
	bar.offset_bottom = 70
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	bar.add_child(h)
	for i in 2:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.custom_minimum_size = Vector2(430, 0)
		var row := HBoxContainer.new()
		v.add_child(row)
		var name := _label(row, "You" if i == 0 else "Enemy", 15, view.team_color(i).lightened(0.35))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_age_labels.append(_label(row, "", 16, ACCENT, true))
		_doc_labels.append(_label(row, "", 13, Color(1, 1, 1, 0.7)))
		var bar_hp := ProgressBar.new()
		bar_hp.custom_minimum_size = Vector2(0, 16)
		bar_hp.show_percentage = false
		bar_hp.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		var fill := StyleBoxFlat.new()
		fill.bg_color = view.team_color(i)
		fill.border_color = view.team_color(i).lightened(0.4)
		fill.border_width_top = 2
		fill.border_width_bottom = 2
		bar_hp.add_theme_stylebox_override("fill", fill)
		v.add_child(bar_hp)
		_hp.append(bar_hp)
		if i == 1:
			row.move_child(name, 2)
			name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(v)
		if i == 0:
			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.alignment = BoxContainer.ALIGNMENT_CENTER
			_clock = _label(mid, "0:00", 26, UiStyle.TEXT, true)
			_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_tide = TidePips.new()
			_tide.hud = self
			_tide.custom_minimum_size = Vector2(0, 16)
			mid.add_child(_tide)
			h.add_child(mid)
			var gear := Button.new()
			gear.text = "⚙"
			gear.tooltip_text = "Settings (Esc)"
			gear.custom_minimum_size = Vector2(40, 40)
			gear.alignment = HORIZONTAL_ALIGNMENT_CENTER
			gear.pressed.connect(open_settings)
			h.add_child(gear)
	_minimap = Minimap.new()
	_minimap.hud = self
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_minimap.offset_left = -300
	_minimap.offset_right = 300
	_minimap.offset_top = 76
	_minimap.offset_bottom = 98
	_root.add_child(_minimap)


func _build_cards() -> void:
	var p := _panel(_root)
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	p.offset_left = 12
	p.offset_top = -196
	p.offset_bottom = -12
	p.offset_right = 12 + 4 * 176 + 60
	var v := VBoxContainer.new()
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	for i in 4:
		var c := UnitCard.new()
		c.hud = self
		c.index = i
		c.custom_minimum_size = Vector2(166, 132)
		c.pressed.connect(func(): feedback(sim.queue_unit(0, sim.roster(0)[i]) if i < sim.roster(0).size() else false))
		h.add_child(c)
		_cards.append(c)
	_queue = QueueStrip.new()
	_queue.hud = self
	_queue.custom_minimum_size = Vector2(0, 30)
	v.add_child(_queue)


func _build_commands() -> void:
	var p := _panel(_root)
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	p.offset_left = -560
	p.offset_right = -12
	p.offset_top = -268
	p.offset_bottom = -12
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 10)
	v.add_child(res)
	var gi := Icon.new()
	gi.kind = "gold"
	res.add_child(gi)
	_gold = _label(res, "", 20, GOLD)
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var xi := Icon.new()
	xi.kind = "xp"
	res.add_child(xi)
	_xp = _label(res, "", 20, XP)
	_xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row1 := HBoxContainer.new()
	v.add_child(row1)
	_momentum = Meter.new()
	_momentum.col = Color("ff7a5a")
	_momentum.custom_minimum_size = Vector2(180, 38)
	row1.add_child(_momentum)
	_ability = _btn(row1, "", func(): view.begin_aim())
	_ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability.custom_minimum_size = Vector2(0, 38)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	var ev := VBoxContainer.new()
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(ev)
	_evolve = _btn(ev, "", func(): feedback(sim.evolve(0)))
	_evolve.custom_minimum_size = Vector2(0, 36)
	_evolve_meter = Meter.new()
	_evolve_meter.col = XP
	_evolve_meter.custom_minimum_size = Vector2(0, 6)
	ev.add_child(_evolve_meter)
	_vet = _btn(row2, "", func(): feedback(sim.buy_veterancy(0)))
	_vet.custom_minimum_size = Vector2(160, 36)
	var row3 := HBoxContainer.new()
	v.add_child(row3)
	_forge = _btn(row3, "", func(): feedback(sim.buy_forge(0)))
	_forge.custom_minimum_size = Vector2(170, 34)
	_stance = _btn(row3, "", func(): view.toggle_stance())
	_stance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in 3:
		var b := Button.new()
		b.text = ["1×", "2×", "❚❚"][i]
		b.tooltip_text = ["Normal speed (F1)", "Double speed (F2)", "Pause (F3)"][i]
		b.custom_minimum_size = Vector2(38, 34)
		b.toggle_mode = true
		b.pressed.connect(func(): view.set_speed(i))
		row3.add_child(b)
		_speed_buttons.append(b)
	var tl := _label(v, "Turrets — click an empty slot to build, a turret to sell (Q W E R)", 13, Color(1, 1, 1, 0.6))
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 6)
	v.add_child(row4)
	for i in 5:
		var b := Button.new()
		b.custom_minimum_size = Vector2(98, 40)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func(): slot_pressed(i))
		row4.add_child(b)
		_slots.append(b)


func _build_doctrine() -> void:
	_doctrine_panel = _panel(_root)
	_doctrine_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_doctrine_panel.offset_left = -400
	_doctrine_panel.offset_right = 400
	_doctrine_panel.offset_top = -150
	_doctrine_panel.offset_bottom = 110
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_doctrine_panel.add_child(v)
	var l := _label(v, "Choose a doctrine", 28, ACCENT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := _label(v, "Kept for the rest of the match. Your evolution waits while you decide.", 14, Color(1, 1, 1, 0.7))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_doctrine_box = HBoxContainer.new()
	_doctrine_box.add_theme_constant_override("separation", 16)
	_doctrine_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_doctrine_box)
	_doctrine_panel.visible = false


func _build_banner() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	v.offset_left = -500
	v.offset_right = 500
	v.offset_top = 170
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(v)
	_banner = _label(v, "", 64, ACCENT, true)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner_sub = _label(v, "", 20)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.modulate.a = 0.0


func banner(text: String, col: Color, side: int, small := false) -> void:
	_banner.text = text.to_upper()
	_banner.add_theme_font_size_override("font_size", 34 if small else 64)
	_banner.add_theme_color_override("font_color", col.lightened(0.45))
	_banner_sub.text = ("" if small else ("You evolved" if side == 0 else "The enemy evolved"))
	_banner_t = view.anim_time


# ---------------------------------------------------------------------------
# Actions

func feedback(ok: bool) -> void:
	if not ok:
		_flash = 0.3
	if view.audio != null:
		view.audio.play("ui_click" if ok else "ui_error")


var _settings_open := false
var _speed_before := 0


## Opens the settings panel and pauses; closing restores the previous speed.
func open_settings() -> void:
	if _settings_open:
		return
	_settings_open = true
	_speed_before = view.speed_index
	view.set_speed(2)
	var panel := GameSettings.make_panel(func():
		_settings_open = false
		view.apply_settings()
		view.set_speed(_speed_before))
	_root.add_child(panel)


func slot_pressed(i: int) -> void:
	var s := sim.sides[0]
	if i >= s.turret_slots:
		if i == s.turret_slots:
			feedback(sim.unlock_slot(0))
		return
	if s.turrets[i] != null:
		feedback(sim.sell_turret(0, i))
		return
	_slot_menu.clear()
	var roster := sim.turret_roster(0)
	for j in roster.size():
		var t := roster[j]
		_slot_menu.add_item("%s (%s) — %d g" % [t.display_name, t.kind.capitalize(), t.cost], j)
		_slot_menu.set_item_disabled(j, s.gold < t.cost)
	_slot_menu_index = i
	_slot_menu.position = Vector2i(get_viewport().get_mouse_position()) - Vector2i(0, 40 + roster.size() * 28)
	_slot_menu.popup()


func _on_slot_menu(id: int) -> void:
	feedback(sim.build_turret(0, _slot_menu_index, sim.turret_roster(0)[id]))


# ---------------------------------------------------------------------------
# Per-frame refresh

func _process(delta: float) -> void:
	if sim == null:
		return
	var me := sim.sides[0]
	for i in 2:
		var s := sim.sides[i]
		_hp[i].max_value = s.base_max_hp
		_hp[i].value = s.base_hp
		_age_labels[i].text = "%s Age  " % sim.data.age(s.age).display_name if i == 0 else "  %s Age" % sim.data.age(s.age).display_name
		var names := []
		for d in s.doctrines:
			names.append(d.display_name)
		_doc_labels[i].text = " · ".join(names)
	_clock.text = "%d:%02d" % [int(sim.time) / 60, int(sim.time) % 60]
	for c in _cards:
		c.queue_redraw()
		c.refresh()
	_queue.queue_redraw()
	_minimap.queue_redraw()
	_tide.queue_redraw()
	_gold.text = "%d  +%.1f/s" % [me.gold, sim.income_rate(0)]
	_gold.modulate = Color(1, 0.45, 0.45) if _flash > 0.0 else Color.WHITE
	_flash = maxf(0.0, _flash - delta)
	_xp.text = "%d XP" % me.xp
	_momentum.value = me.momentum / sim.rules.momentum_cap
	_momentum.text = "Momentum %d" % me.momentum
	var ab := sim.data.age(me.age).ability
	_ability.text = "⚡ %s  [Space]%s" % [ab.display_name, "" if me.ability_cooldown <= 0 else "   %ds" % ceili(me.ability_cooldown)]
	_ability.disabled = not sim.can_fire_ability(0)
	if me.age >= GameData.AGE_COUNT:
		_evolve.text = "Final age"
		_evolve.disabled = true
		_evolve_meter.value = 1.0
	else:
		var cost := sim.evolve_cost(0)
		_evolve.text = "▲ Evolve → %s   %d XP  [T]" % [sim.data.age(me.age + 1).display_name, cost]
		if me.is_evolving():
			_evolve.text = "Evolving…" if me.awaiting_doctrine else "Evolving… %.1fs" % me.evolve_left
		_evolve.disabled = not sim.can_evolve(0)
		_evolve_meter.value = clampf(me.xp / cost, 0.0, 1.0)
	_vet.text = "★ Veteran %s  %s" % ["●".repeat(me.vet_ranks) + "○".repeat(3 - me.vet_ranks), "" if me.vet_ranks >= 3 else "%d" % sim.veterancy_cost(0)]
	_vet.tooltip_text = "Veterancy [V]: +10% HP and damage for this age's units per rank. Resets when you evolve."
	_vet.disabled = not sim.can_buy_veterancy(0)
	_forge.text = "⚒ Forge %s  %s" % ["●".repeat(me.forge_level) + "○".repeat(3 - me.forge_level), "" if me.forge_level >= 3 else "%dg" % sim.forge_cost(0)]
	_forge.tooltip_text = "Forge [F]: +20% passive income per level."
	_forge.disabled = me.gold < sim.forge_cost(0)
	_stance.text = "⚑ Hold the line [S]" if me.stance == &"hold" else "➜ Advance [S]"
	for i in 3:
		_speed_buttons[i].button_pressed = view.speed_index == i
	for i in 5:
		var b := _slots[i]
		b.visible = i < me.max_turret_slots()
		var key := "QWER"[i] if i < 4 else "–"
		if i < me.turret_slots:
			var t: SimTurret = me.turrets[i]
			if t == null:
				b.text = "%s  + Build" % key
				b.tooltip_text = "Empty slot — build a turret"
			else:
				b.text = "%s  %s" % [key, t.def.display_name]
				b.tooltip_text = "%s (Age %d) — click to sell for %d g%s" % [t.def.display_name, t.def.age, roundi(t.def.cost * sim.rules.sell_refund), "\nOutclassed: replace it" if t.def.age < me.age else ""]
			b.modulate = Color(1, 0.75, 0.6) if t != null and t.def.age < me.age else Color.WHITE
		elif i == me.turret_slots:
			b.text = "🔒 %dg" % sim.slot_cost(0)
			b.tooltip_text = "Unlock turret slot"
		else:
			b.text = "🔒"
	_update_doctrine()
	var bt := view.anim_time - _banner_t
	var bv: Control = _banner.get_parent()
	bv.modulate.a = clampf(minf(bt / 0.15, (2.6 - bt) / 0.6), 0.0, 1.0)
	bv.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - bt / 0.25))
	bv.pivot_offset = bv.size * 0.5


func _update_doctrine() -> void:
	var me := sim.sides[0]
	if not me.awaiting_doctrine:
		_doctrine_panel.visible = false
		return
	if _doctrine_panel.visible:
		return
	for c in _doctrine_box.get_children():
		c.queue_free()
	for d in sim.data.age(me.age + 1).doctrine_options:
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 130)
		b.text = "%s\n%s" % [d.display_name.to_upper(), d.description]
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func(): sim.choose_doctrine(0, d))
		_doctrine_box.add_child(b)
	_doctrine_panel.visible = true


func matrix_tooltip(u: UnitDef) -> String:
	var r := sim.rules
	return "%s — %s\n%s damage · %s armour\nvs Light ×%.2f   vs Heavy ×%.2f   vs Structures ×%.2f\n%d HP · %.0f dmg every %.1fs · range %d · speed %d" % [
		u.display_name, u.role.capitalize(), u.damage_type.capitalize(), u.armour.capitalize(),
		r.matrix(u.damage_type, "light"), r.matrix(u.damage_type, "heavy"), r.matrix(u.damage_type, "structure"),
		u.hp, u.damage, u.attack_interval, u.range, u.speed]


func show_post_match() -> void:
	_post = _panel(_root)
	_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post.offset_left = 160
	_post.offset_right = -160
	_post.offset_top = 110
	_post.offset_bottom = -110
	var v := VBoxContainer.new()
	_post.add_child(v)
	var won := sim.winner == MatchSim.LEFT
	var title := _label(v, {MatchSim.LEFT: "VICTORY", MatchSim.RIGHT: "DEFEAT", MatchSim.DRAW: "DRAW"}[sim.winner], 60, ACCENT if won else Color("e07a6a"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(v, "%d:%02d · %s Age vs %s Age" % [int(sim.time) / 60, int(sim.time) % 60, sim.data.age(sim.sides[0].age).display_name, sim.data.age(sim.sides[1].age).display_name], 18, Color(1, 1, 1, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var graphs := PostMatchGraphs.new()
	graphs.match_log = sim.match_log
	graphs.colors = [view.team_color(0), view.team_color(1)]
	graphs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(graphs)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	for pair in [["Rematch", func(): view.rematch.emit()], ["Main menu", func(): view.exit_to_menu.emit()]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(180, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(pair[1])
		h.add_child(b)


# ---------------------------------------------------------------------------
# Small custom controls

class Icon extends Control:
	var kind := "gold"

	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"gold":
				draw_circle(c, 9, Color("b8860b"))
				draw_circle(c, 7, MatchHud.GOLD)
				draw_line(c + Vector2(-2, -4), c + Vector2(-2, 4), Color("b8860b"), 2.0)
			"xp":
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI * 0.5 + TAU * i / 10.0
					pts.append(c + Vector2(cos(a), sin(a)) * (10.0 if i % 2 == 0 else 4.5))
				draw_colored_polygon(pts, MatchHud.XP)


class Meter extends Control:
	var value := 0.0
	var col := Color.WHITE
	var text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.55))
		var full := value >= 0.999
		var c := col.lightened(0.25 + 0.2 * sin(Time.get_ticks_msec() / 150.0)) if full else col
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0.0, 1.0), size.y)), c)
		draw_rect(r, Color(1, 1, 1, 0.18), false, 1.0)
		if text != "" and size.y > 14:
			var f := UiStyle.font("bold")
			draw_string_outline(f, Vector2(8, size.y * 0.5 + 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
			draw_string(f, Vector2(8, size.y * 0.5 + 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)


class TidePips extends Control:
	var hud: MatchHud

	func _draw() -> void:
		var sim := hud.sim
		var level := sim.rules.tide_level_at(sim.time)
		var n := sim.rules.tide_multipliers.size()
		var w := 16.0
		var x0 := size.x * 0.5 - (n * w) * 0.5 - 40
		var f := UiStyle.font("bold")
		draw_string(f, Vector2(x0 - 44, 13), "Tide", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
		for i in n:
			var c := Vector2(x0 + i * w + 6, 8)
			draw_circle(c, 5.5, Color("5fc6ff") if i < level else Color(1, 1, 1, 0.15))
		draw_string(f, Vector2(x0 + n * w + 6, 13), "×%.1f" % sim.rules.tide_multipliers[level - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5fc6ff"))
		if sim.escalation > 0:
			draw_string(f, Vector2(x0 + n * w + 52, 13), "ESCALATION %d/4" % sim.escalation, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff6a5a"))


class Minimap extends Control:
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
		for s in sim.sides:
			for u in s.units:
				var x := sim.to_world(u.side, u.progress) / lane * size.x
				var r := 3.5 if u.def.role == "heavy" else 2.5
				draw_circle(Vector2(x, size.y * 0.5 + (u.id % 3 - 1) * 4), r, hud.view.team_color(u.side).lightened(0.3))
		draw_line(Vector2(fx, 0), Vector2(fx, size.y), Color.WHITE, 2.0)
		var vp := hud.view.get_viewport_rect().size
		var cx := hud.view.camera.get_screen_center_position().x
		var a := (cx - vp.x * 0.5) / lane * size.x
		var b := (cx + vp.x * 0.5) / lane * size.x
		draw_rect(Rect2(a, 0, b - a, size.y), Color(1, 1, 1, 0.6), false, 1.0)


class UnitCard extends Button:
	var hud: MatchHud
	var index := 0

	func _init() -> void:
		alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM

	func refresh() -> void:
		var roster := hud.sim.roster(0)
		if index >= roster.size():
			disabled = true
			tooltip_text = "No %s this age" % ["Vanguard", "Ranged", "Heavy", "Siege"][index]
			return
		var u := roster[index]
		disabled = not hud.sim.can_queue(0, u)
		tooltip_text = hud.matrix_tooltip(u)

	func _draw() -> void:
		var sim := hud.sim
		var roster := sim.roster(0)
		var f := UiStyle.font("bold")
		draw_string(f, Vector2(8, 20), "%d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MatchHud.ACCENT)
		if index >= roster.size():
			draw_string(f, Vector2(0, size.y * 0.5), "Siege from Bronze", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(1, 1, 1, 0.3))
			return
		var u := roster[index]
		var h := UnitArt.height_for(u)
		var sc := clampf(62.0 / h, 0.5, 1.1)
		var t := Time.get_ticks_msec() / 1000.0
		UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(size.x * 0.5 + (h * 0.0), 92)))
		UnitArt.draw_unit(self, u, hud.view.team_color(0), {"walk": 0.0, "moving": false, "atk": -1.0, "t": t, "flash": 0.0}, index + 3)
		draw_set_transform(Vector2.ZERO)
		var col := Color.WHITE if not disabled else Color(1, 1, 1, 0.4)
		draw_string(f, Vector2(0, 112), u.display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, col)
		draw_string(f, Vector2(0, 128), "%d g" % sim.unit_price(0, u), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, MatchHud.GOLD if not disabled else Color(MatchHud.GOLD, 0.4))
		draw_string(f, Vector2(size.x - 70, 20), u.role.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 62, 11, Color(1, 1, 1, 0.5))


class QueueStrip extends Control:
	var hud: MatchHud

	func _draw() -> void:
		var sim := hud.sim
		var me := sim.sides[0]
		var f := UiStyle.font("bold")
		draw_string(f, Vector2(4, 20), "Queue", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
		for i in sim.rules.queue_slots:
			var r := Rect2(60 + i * 36, 2, 30, 26)
			draw_rect(r, Color(0, 0, 0, 0.4))
			if i < me.queue.size():
				var d := me.queue[i]
				var sc := 22.0 / UnitArt.height_for(d)
				UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, r.position + Vector2(15, 25)))
				UnitArt.draw_unit(self, d, hud.view.team_color(0), {"t": 0.0}, i)
				draw_set_transform(Vector2.ZERO)
				if i == 0 and not me.is_evolving():
					draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x * clampf(me.train_progress / d.train_time, 0, 1), 3), MatchHud.ACCENT)
			draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
		draw_string(f, Vector2(60 + sim.rules.queue_slots * 36 + 10, 20), "On field %d/%d" % [me.units.size(), sim.rules.field_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
