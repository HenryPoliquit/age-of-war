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
var _grid: UpgradeGrid
var _turrets: TurretBar
var _units: UnitBar
var _lane: LanePanel
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
	_units = UnitBar.new(self)
	_root.add_child(_units)
	_lane = LanePanel.new(self)
	_root.add_child(_lane)
	_turrets = TurretBar.new(self)
	_root.add_child(_turrets)
	_build_banner()
	_grid = UpgradeGrid.new(self)
	_root.add_child(_grid)
	_top.upgrades_button.toggled.connect(func(on: bool): _grid.visible = on)
	# Dev aid for screenshots: open the HUD's pop-ups without clicking.
	if "--hud-demo-settings" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(open_settings)
	if "--hud-demo" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(func():
			_top.upgrades_button.button_pressed = true
			_turrets.open_menu(0))


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
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


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
		view.set_speed(_speed_before), _match_actions())
	_root.add_child(panel)


## Restart / End game row for the in-match settings panel; each asks for confirmation first.
func _match_actions() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for spec in [["↻ Restart match", "Restart this match? The current match is lost.", view.rematch],
			["✕ End game", "End this match and return to the main menu?", view.exit_to_menu]]:
		var b := Button.new()
		b.text = spec[0]
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		var ask := ConfirmationDialog.new()
		ask.dialog_text = spec[1]
		ask.ok_button_text = "Yes"
		ask.cancel_button_text = "No"
		var sig: Signal = spec[2]
		ask.confirmed.connect(func(): sig.emit())
		b.add_child(ask)
		b.pressed.connect(func(): ask.popup_centered())
		row.add_child(b)
	return row


func slot_pressed(i: int) -> void:
	_turrets.open_menu(i)


# ---------------------------------------------------------------------------
# Per-frame refresh

func _process(delta: float) -> void:
	if sim == null:
		return
	var me := sim.sides[0]
	_top.refresh()
	_grid.refresh()
	_turrets.refresh()
	_units.refresh()
	_lane.refresh()
	_flash = maxf(0.0, _flash - delta)
	var bt := view.anim_time - _banner_t
	var bv: Control = _banner.get_parent()
	bv.modulate.a = clampf(minf(bt / 0.15, (2.6 - bt) / 0.6), 0.0, 1.0)
	bv.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - bt / 0.25))
	bv.pivot_offset = bv.size * 0.5


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
