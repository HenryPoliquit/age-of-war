extends TestCase
## HUD panels built headless (no match running): keyboard focus and the turret menu's input handling.


func _hud() -> MatchHud:
	var hud := MatchHud.new()
	hud.view = MatchView.new()
	hud.view.sim = new_sim()
	return hud


func _free(hud: MatchHud, nodes: Array) -> void:
	for n in nodes:
		n.free()
	hud.view.free()
	hud.free()


func _buttons(n: Node) -> Array[Node]:
	return n.find_children("*", "BaseButton", true, false)


func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.pressed = true
	e.button_index = button
	e.position = pos
	return e


## Space is the skill hotkey: a focused HUD button would swallow it (e.g. re-buying the last upgrade).
func test_hud_buttons_never_take_keyboard_focus() -> void:
	var hud := _hud()
	var panels: Array = [TopBar.new(hud), UpgradeGrid.new(hud), TurretBar.new(hud), UnitBar.new(hud)]
	for p in panels:
		var bs := _buttons(p)
		check(not bs.is_empty(), "%s has buttons" % p.get_script().get_global_name())
		for b in bs:
			check_eq(b.focus_mode, Control.FOCUS_NONE, "%s button '%s'" % [p.get_script().get_global_name(), b.text])
	_free(hud, panels)


## The build/sell menu must not be a Window: a Window takes all input (no panning, no hotkeys) until closed.
func test_turret_menu_does_not_block_the_battlefield() -> void:
	var hud := _hud()
	var bar := TurretBar.new(hud)
	check(bar.find_children("*", "Window", true, false).is_empty(), "no Window in the turret bar")
	bar.open_menu(0)
	check(bar.menu.visible, "menu opens")
	for b in _buttons(bar.menu):
		check_eq(b.focus_mode, Control.FOCUS_NONE, "menu option '%s'" % b.text)
	bar._input(_click(bar.menu.get_global_rect().get_center()))
	check(bar.menu.visible, "a click inside keeps it open")
	bar._input(_click(bar.menu.get_global_rect().position - Vector2(40, 40), MOUSE_BUTTON_RIGHT))
	check(not bar.menu.visible, "a right-click elsewhere (camera drag) closes it")
	bar.open_menu(0)
	bar.open_menu(1)
	check(bar.menu.visible or hud.view.sim.sides[0].turret_slots == 2, "opening another slot replaces the menu or unlocks it")
	_free(hud, [bar])


func test_matchup_button_shows_the_table_on_hover() -> void:
	var hud := _hud()
	var help := MatchupHelp.new(hud)
	check_eq(help.focus_mode, Control.FOCUS_NONE)
	check(help.tooltip_text != "", "a tooltip text is needed for the custom tooltip to appear")
	var tip: Control = help._make_custom_tooltip("")
	var t := HudModel.matchup_table(hud.sim, 0, hud.view.race_def(0), hud.view.race_def(1))
	var grids := tip.find_children("*", "GridContainer", true, false)
	check_eq(grids.size(), 1)
	check_eq(grids[0].get_child_count(), (t.cols.size() + 1) * (t.rows.size() + 1), "header row and column plus one cell per matchup")
	tip.free()
	_free(hud, [help])
