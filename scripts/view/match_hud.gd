class_name MatchHud
extends CanvasLayer
## Graybox HUD (GDD §13.9): top status bar, bottom unit cards, right-hand economy/age panel,
## doctrine choice, and the post-match screen. Reads MatchSim; acts only through its commands.

var view: MatchView
var sim: MatchSim:
	get:
		return view.sim

var _top: Label
var _hp: Array[ProgressBar] = []
var _unit_buttons: Array[Button] = []
var _queue_label: Label
var _gold: Label
var _momentum: ProgressBar
var _ability: Button
var _evolve: Button
var _vet: Button
var _forge: Button
var _stance: Button
var _slots: Array[Button] = []
var _slot_menu: PopupMenu
var _slot_menu_index := -1
var _doctrine_panel: PanelContainer
var _doctrine_box: HBoxContainer
var _post: PanelContainer
var _flash := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top(root)
	_build_bottom(root)
	_build_right(root)
	_build_doctrine(root)
	_slot_menu = PopupMenu.new()
	_slot_menu.id_pressed.connect(_on_slot_menu)
	root.add_child(_slot_menu)


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.82)
	sb.set_content_margin_all(8)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _build_top(root: Control) -> void:
	var p := _panel(root)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p.offset_bottom = 48
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	for i in 2:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(360, 24)
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = view.team_color(i)
		bar.add_theme_stylebox_override("fill", fill)
		_hp.append(bar)
	h.add_child(_hp[0])
	_top = Label.new()
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(_top)
	h.add_child(_hp[1])


func _build_bottom(root: Control) -> void:
	var p := _panel(root)
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_top = -120
	p.offset_right = -380
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 96)
		b.pressed.connect(func(): feedback(sim.queue_unit(0, sim.roster(0)[i]) if i < sim.roster(0).size() else false))
		h.add_child(b)
		_unit_buttons.append(b)
	_queue_label = Label.new()
	_queue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_queue_label)


func _build_right(root: Control) -> void:
	var p := _panel(root)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	p.offset_left = -370
	p.offset_top = 56
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_gold = Label.new()
	v.add_child(_gold)
	_momentum = ProgressBar.new()
	_momentum.custom_minimum_size = Vector2(0, 18)
	_momentum.show_percentage = false
	v.add_child(_momentum)
	_ability = _btn(v, "", func(): view.begin_aim())
	_evolve = _btn(v, "", func(): feedback(sim.evolve(0)))
	_vet = _btn(v, "", func(): feedback(sim.buy_veterancy(0)))
	_forge = _btn(v, "", func(): feedback(sim.buy_forge(0)))
	var tl := Label.new()
	tl.text = "Turrets  (Q W E R — click empty to build, filled to sell)"
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(tl)
	var grid := GridContainer.new()
	grid.columns = 1
	v.add_child(grid)
	for i in 5:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): slot_pressed(i))
		grid.add_child(b)
		_slots.append(b)
	_stance = _btn(v, "", func(): view.toggle_stance())
	var sp := HBoxContainer.new()
	v.add_child(sp)
	for i in 3:
		var b := Button.new()
		b.text = ["1× (F1)", "2× (F2)", "Pause (F3)"][i]
		b.pressed.connect(func(): view.set_speed(i))
		sp.add_child(b)
	var help := Label.new()
	help.text = "Space: aim ability, release to fire · S: Hold/Advance (Shift+click moves the rally line) · A/D or right-drag: pan"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.add_theme_font_size_override("font_size", 12)
	v.add_child(help)


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_doctrine(root: Control) -> void:
	_doctrine_panel = _panel(root)
	_doctrine_panel.set_anchors_preset(Control.PRESET_CENTER)
	_doctrine_panel.offset_left = -380
	_doctrine_panel.offset_right = 380
	_doctrine_panel.offset_top = -120
	_doctrine_panel.offset_bottom = 120
	var v := VBoxContainer.new()
	_doctrine_panel.add_child(v)
	var l := Label.new()
	l.text = "Choose a doctrine — kept for the rest of the match"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_doctrine_box = HBoxContainer.new()
	_doctrine_box.add_theme_constant_override("separation", 16)
	v.add_child(_doctrine_box)
	_doctrine_panel.visible = false


func feedback(ok: bool) -> void:
	if not ok:
		_flash = 0.25


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
		_slot_menu.add_item("%s (%s) — %d g" % [t.display_name, t.kind, t.cost], j)
	_slot_menu_index = i
	_slot_menu.position = Vector2i(get_viewport().get_mouse_position())
	_slot_menu.popup()


func _on_slot_menu(id: int) -> void:
	feedback(sim.build_turret(0, _slot_menu_index, sim.turret_roster(0)[id]))


func _process(delta: float) -> void:
	if sim == null:
		return
	var me := sim.sides[0]
	var foe := sim.sides[1]
	for i in 2:
		_hp[i].max_value = sim.sides[i].base_max_hp
		_hp[i].value = sim.sides[i].base_hp
	var tide := sim.rules.tide_level_at(sim.time)
	var esc := "  ·  ESCALATION %d/4" % sim.escalation if sim.escalation > 0 else ""
	_top.text = "%s  %s   %d:%02d   Tide %d (×%.1f)%s   %s  %s" % [
		_doctrine_text(me), sim.data.age(me.age).display_name, int(sim.time) / 60, int(sim.time) % 60,
		tide, sim.rules.tide_multipliers[tide - 1], esc, sim.data.age(foe.age).display_name, _doctrine_text(foe)]
	var roster := sim.roster(0)
	for i in 4:
		var b := _unit_buttons[i]
		if i >= roster.size():
			b.text = "—"
			b.disabled = true
			continue
		var u := roster[i]
		b.disabled = not sim.can_queue(0, u)
		b.text = "[%d] %s\n%s · %d g\n%d HP · %s/%s" % [i + 1, u.display_name, u.role.capitalize(), sim.unit_price(0, u), u.hp, u.damage_type, u.armour]
		b.tooltip_text = _matrix_tooltip(u)
	var q := []
	for d in me.queue:
		q.append(d.display_name)
	_queue_label.text = "Queue %d/%d: %s\nOn field %d/%d" % [me.queue.size(), sim.rules.queue_slots, ", ".join(q), me.units.size(), sim.rules.field_cap]
	_gold.text = "Gold %d  (+%.1f/s)\nXP %d\nMomentum %d/100" % [me.gold, sim.income_rate(0), me.xp, me.momentum]
	_gold.modulate = Color(1, 0.5, 0.5) if _flash > 0.0 else Color.WHITE
	_flash = maxf(0.0, _flash - delta)
	_momentum.value = me.momentum
	var ab := sim.data.age(me.age).ability
	_ability.text = "Ability: %s (Space)%s" % [ab.display_name, "" if me.ability_cooldown <= 0 else "  cd %ds" % ceili(me.ability_cooldown)]
	_ability.disabled = not sim.can_fire_ability(0)
	if me.age >= GameData.AGE_COUNT:
		_evolve.text = "Final age reached"
		_evolve.disabled = true
	else:
		_evolve.text = "Evolve → %s (T): %d XP" % [sim.data.age(me.age + 1).display_name, sim.evolve_cost(0)]
		if me.is_evolving():
			_evolve.text = "Evolving… %.1fs" % me.evolve_left
		_evolve.disabled = not sim.can_evolve(0)
	_vet.text = "Veterancy rank %d/3 (V): %s" % [me.vet_ranks, "max" if me.vet_ranks >= 3 else "%d XP" % sim.veterancy_cost(0)]
	_vet.disabled = not sim.can_buy_veterancy(0)
	_forge.text = "Forge level %d/3 (F): %s" % [me.forge_level, "max" if me.forge_level >= 3 else "%d g" % sim.forge_cost(0)]
	_forge.disabled = me.gold < sim.forge_cost(0)
	for i in 5:
		var b := _slots[i]
		b.visible = i < me.max_turret_slots()
		if i < me.turret_slots:
			var t: SimTurret = me.turrets[i]
			b.text = "%s  %s" % ["QWER"[i] if i < 4 else " ", "empty — build" if t == null else "%s (age %d) — sell %d g" % [t.def.display_name, t.def.age, roundi(t.def.cost * sim.rules.sell_refund)]]
		elif i == me.turret_slots:
			b.text = "%s  unlock slot: %d g" % ["QWER"[i] if i < 4 else " ", sim.slot_cost(0)]
		else:
			b.text = "   locked"
	_stance.text = "Stance: %s (S)" % ("HOLD" if me.stance == &"hold" else "Advance")
	_update_doctrine()


func _doctrine_text(s: SimSide) -> String:
	var names := []
	for d in s.doctrines:
		names.append(d.display_name)
	return "[%s]" % "/".join(names) if not names.is_empty() else ""


func _matrix_tooltip(u: UnitDef) -> String:
	var r := sim.rules
	return "%s — %s damage, %s armour\nDamage vs Light ×%.2f · Heavy ×%.2f · Structure ×%.2f\nRange %d  Speed %d  Attack every %.1fs" % [
		u.display_name, u.damage_type.capitalize(), u.armour.capitalize(),
		r.matrix(u.damage_type, "light"), r.matrix(u.damage_type, "heavy"), r.matrix(u.damage_type, "structure"),
		u.range, u.speed, u.attack_interval]


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
		b.custom_minimum_size = Vector2(340, 140)
		b.text = "%s\n\n%s" % [d.display_name, d.description]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.pressed.connect(func(): sim.choose_doctrine(0, d))
		_doctrine_box.add_child(b)
	_doctrine_panel.visible = true


func show_post_match() -> void:
	_post = _panel(get_child(0))
	_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post.offset_left = 160
	_post.offset_right = -160
	_post.offset_top = 90
	_post.offset_bottom = -90
	var v := VBoxContainer.new()
	_post.add_child(v)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = {MatchSim.LEFT: "Victory", MatchSim.RIGHT: "Defeat", MatchSim.DRAW: "Draw"}[sim.winner] + "  —  %d:%02d" % [int(sim.time) / 60, int(sim.time) % 60]
	v.add_child(title)
	var graphs := PostMatchGraphs.new()
	graphs.match_log = sim.match_log
	graphs.colors = [view.team_color(0), view.team_color(1)]
	graphs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(graphs)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var re := Button.new()
	re.text = "Rematch"
	re.pressed.connect(func(): view.rematch.emit())
	h.add_child(re)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.pressed.connect(func(): view.exit_to_menu.emit())
	h.add_child(menu)
