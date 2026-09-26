class_name MatchHud
extends CanvasLayer
## Match HUD (GDD §13.9): top bar, upgrade grid, unit cards, lane map with training queue, turret slots,
## event banners and the post-match screen. Panels render HudModel values; actions go through MatchSim.

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
var _top: TopBar
var _minimap: Minimap
var _cards: Array[UnitCard] = []
var _queue: QueueStrip
var _income: Button
var _slots: Array[Button] = []
var _slot_menu: PopupMenu
var _slot_menu_index := -1
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
	_top = TopBar.new(self)
	_root.add_child(_top)
	_build_minimap()
	_build_cards()
	_build_commands()
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


func _build_minimap() -> void:
	_minimap = Minimap.new()
	_minimap.hud = self
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_minimap.offset_left = -300
	_minimap.offset_right = 300
	_minimap.offset_top = 62
	_minimap.offset_bottom = 84
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
	p.offset_top = -150
	p.offset_bottom = -12
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var row3 := HBoxContainer.new()
	v.add_child(row3)
	_income = _btn(row3, "", func(): feedback(sim.buy_upgrade(0, "income", "income")))
	_income.custom_minimum_size = Vector2(170, 34)
	var tl := _label(v, "Turrets — click an empty slot to build, a turret to sell (Q W E R)", 13, Color(1, 1, 1, 0.6))
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 6)
	v.add_child(row4)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(98, 40)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func(): slot_pressed(i))
		row4.add_child(b)
		_slots.append(b)


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
		_slot_menu.add_item("%s (%s) — %d g" % [view.race_def(0).turret_name(t), t.kind.capitalize(), t.cost], j)
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
	_top.refresh()
	_flash = maxf(0.0, _flash - delta)
	for c in _cards:
		c.queue_redraw()
		c.refresh()
	_queue.queue_redraw()
	_minimap.queue_redraw()
	var inc := sim.upgrade_level(0, "income", "income")
	_income.text = "💰 Income %s  %s" % ["●".repeat(inc) + "○".repeat(3 - inc), "" if inc >= 3 else "%dg" % sim.upgrade_cost(0, "income", "income")]
	_income.tooltip_text = "Income: +20% passive income per level. Unit and turret upgrades arrive with the new HUD."
	_income.disabled = not sim.can_buy_upgrade(0, "income", "income")
	for i in 4:
		var b := _slots[i]
		var key := "QWER"[i]
		if i < me.turret_slots:
			var t: SimTurret = me.turrets[i]
			if t == null:
				b.text = "%s  + Build" % key
				b.tooltip_text = "Empty slot — build a turret"
			else:
				b.text = "%s  %s" % [key, view.race_def(0).turret_name(t.def)]
				b.tooltip_text = "%s (Age %d) — click to sell for %d g%s" % [view.race_def(0).turret_name(t.def), t.def.age, roundi(t.def.cost * sim.rules.sell_refund), "\nOutclassed: replace it" if t.def.age < me.age else ""]
			b.modulate = Color(1, 0.75, 0.6) if t != null and t.def.age < me.age else Color.WHITE
		elif i == me.turret_slots:
			b.text = "🔒 %dg" % sim.slot_cost(0)
			b.tooltip_text = "Unlock turret slot"
		else:
			b.text = "🔒"
	var bt := view.anim_time - _banner_t
	var bv: Control = _banner.get_parent()
	bv.modulate.a = clampf(minf(bt / 0.15, (2.6 - bt) / 0.6), 0.0, 1.0)
	bv.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - bt / 0.25))
	bv.pivot_offset = bv.size * 0.5


func matrix_tooltip(u: UnitDef) -> String:
	var r := sim.rules
	return "%s — %s\n%s damage · %s armour\nvs Light ×%.2f   vs Heavy ×%.2f   vs Structures ×%.2f\n%d HP · %.0f dmg every %.1fs · range %d · speed %d" % [
		view.race_def(0).unit_name(u), u.role.capitalize(), u.damage_type.capitalize(), u.armour.capitalize(),
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
	var sub := _label(v, "%d:%02d · %s, %s Age vs %s, %s Age" % [int(sim.time) / 60, int(sim.time) % 60, view.race_def(0).display_name, sim.data.age(sim.sides[0].age).display_name, view.race_def(1).display_name, sim.data.age(sim.sides[1].age).display_name], 18, Color(1, 1, 1, 0.7))
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
		var race := hud.view.race_of(0)
		var h := UnitArt.height_for(u, race)
		var sc := clampf(62.0 / h, 0.5, 1.1)
		var t := Time.get_ticks_msec() / 1000.0
		UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(size.x * 0.5 + (h * 0.0), 92)))
		UnitArt.draw_unit(self, u, hud.view.team_color(0), {"walk": 0.0, "moving": false, "atk": -1.0, "t": t, "flash": 0.0}, index + 3, race)
		draw_set_transform(Vector2.ZERO)
		var col := Color.WHITE if not disabled else Color(1, 1, 1, 0.4)
		draw_string(f, Vector2(0, 112), hud.view.race_def(0).unit_name(u), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, col)
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
				var sc := 22.0 / UnitArt.height_for(d, hud.view.race_of(0))
				UnitArt.begin(self, Transform2D(0.0, Vector2(sc, sc), 0.0, r.position + Vector2(15, 25)))
				UnitArt.draw_unit(self, d, hud.view.team_color(0), {"t": 0.0}, i, hud.view.race_of(0))
				draw_set_transform(Vector2.ZERO)
				if i == 0 and not me.is_evolving():
					draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x * clampf(me.train_progress / d.train_time, 0, 1), 3), MatchHud.ACCENT)
			draw_rect(r, Color(1, 1, 1, 0.15), false, 1.0)
		draw_string(f, Vector2(60 + sim.rules.queue_slots * 36 + 10, 20), "On field %d/%d" % [me.units.size(), sim.rules.field_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.55))
