extends TestCase


func _race() -> RaceDef:
	return GameData.get_default().race(&"human")


func test_pips() -> void:
	check_eq(HudModel.pips(0, 3), "○○○")
	check_eq(HudModel.pips(2, 3), "●●○")


func test_clock_shows_escalation() -> void:
	var sim := new_sim()
	sim.time = 228.0
	check_eq(HudModel.clock(sim), "3:48")
	sim.time = 935.0
	sim.escalation = 2
	check_eq(HudModel.clock(sim), "15:35  ·  Escalation 2/4")


func test_era_and_gold_text() -> void:
	var sim := new_sim(false)
	check_eq(HudModel.era_name(sim, 0), "%s Age" % sim.data.age(1).display_name)
	check_eq(HudModel.gold_text(sim, 0), "150  +2.0/s")


func test_upgrade_cell_shows_price_and_effect() -> void:
	var sim := new_sim()
	var price := roundi(0.6 * sim.data.unit_for_role(1, "ranged").cost)
	var cell := HudModel.upgrade_cell(sim, 0, "ranged", "attack")
	check_eq(cell.text, "○○○  %dg" % price)
	check(cell.enabled, "affordable")
	check(not cell.maxed)
	check(cell.tooltip.contains("+15% damage for all Ranged units, every era"), cell.tooltip)
	check(cell.tooltip.ends_with("%d g" % price), cell.tooltip)


func test_maxed_cell() -> void:
	var sim := new_sim()
	for i in 3:
		sim.buy_upgrade(0, "vanguard", "health")
	var cell := HudModel.upgrade_cell(sim, 0, "vanguard", "health")
	check_eq(cell.text, "●●●  MAX")
	check(cell.maxed and not cell.enabled)
	check(cell.tooltip.contains("+45% health"), cell.tooltip)


func test_unaffordable_cell_is_disabled() -> void:
	var sim := new_sim(false)
	sim.sides[0].gold = 0.0
	var cell := HudModel.upgrade_cell(sim, 0, "heavy", "attack")
	check(not cell.enabled and not cell.maxed)


func test_siege_row_unavailable_in_age_1() -> void:
	var sim := new_sim()
	var cell := HudModel.upgrade_cell(sim, 0, "siege", "attack")
	check(not cell.enabled)
	check_eq(cell.text, "○○○")
	check(cell.tooltip.contains("No Siege unit"), cell.tooltip)
	check_eq(HudModel.row_label(sim, 0, "siege", _race()), "Siege")


func test_row_label_follows_the_era() -> void:
	var sim := new_sim()
	var race := _race()
	check_eq(HudModel.row_label(sim, 0, "ranged", race), race.unit_name(sim.data.unit_for_role(1, "ranged")))
	sim.sides[0].age = 3
	check_eq(HudModel.row_label(sim, 0, "ranged", race), race.unit_name(sim.data.unit_for_role(3, "ranged")))
	check_eq(HudModel.row_label(sim, 0, "turret", race), "Turrets")
	check_eq(HudModel.row_label(sim, 0, "income", race), "Income")


func test_income_and_range_cells() -> void:
	var sim := new_sim()
	var inc := HudModel.upgrade_cell(sim, 0, "income", "income")
	check_eq(inc.text, "○○○  100g")
	check(inc.tooltip.contains("+20% passive income"), inc.tooltip)
	check(HudModel.upgrade_cell(sim, 0, "turret", "range").tooltip.contains("Support auras"))


func test_skill_needs_a_target() -> void:
	var sim := new_sim()
	var st := HudModel.skill_state(sim, 0, _race())
	check(not st.enabled, "no enemy on the lane")
	check(st.tooltip.contains("No enemy units"), st.tooltip)
	place(sim, 1, "vanguard", 1000.0)
	st = HudModel.skill_state(sim, 0, _race())
	check(st.enabled)
	check(st.tooltip.contains("sweeps the whole lane"), st.tooltip)
	sim.fire_ability(0)
	st = HudModel.skill_state(sim, 0, _race())
	check(not st.enabled, "cooldown")
	check(st.text.ends_with("· %ds" % roundi(sim.rules.ability_cooldown)), st.text)


func test_evolve_state() -> void:
	var sim := new_sim()
	var st := HudModel.evolve_state(sim, 0)
	check(st.enabled)
	check_eq(st.text, "▲ Evolve · %d XP" % sim.data.age(2).evolve_cost)
	sim.sides[0].age = GameData.AGE_COUNT
	st = HudModel.evolve_state(sim, 0)
	check(not st.enabled)
	check_eq(st.text, "Final era")


func test_slot_states() -> void:
	var sim := new_sim()
	var race := _race()
	check_eq(HudModel.slot_state(sim, 0, 0, race).kind, "empty")
	var unlock := HudModel.slot_state(sim, 0, 1, race)
	check_eq(unlock.kind, "unlock")
	check_eq(unlock.text, "🔒 150g")
	var locked := HudModel.slot_state(sim, 0, 2, race)
	check_eq(locked.kind, "locked")
	check(locked.tooltip.contains("Unlock slot 2 first"), locked.tooltip)
	var def := sim.data.turret_for_kind(1, "sentry")
	sim.build_turret(0, 0, def)
	var built := HudModel.slot_state(sim, 0, 0, race)
	check_eq(built.kind, "built")
	check_eq(built.text, race.turret_name(def))
	check(built.tooltip.contains("sell for %d g" % roundi(def.cost * 0.5)), built.tooltip)


func test_build_options_follow_gold() -> void:
	var sim := new_sim(false)
	sim.sides[0].gold = 0.0
	var opts := HudModel.build_options(sim, 0, _race())
	check_eq(opts.size(), sim.turret_roster(0).size())
	check(not opts[0].enabled)
	sim.sides[0].gold = 9999.0
	check(HudModel.build_options(sim, 0, _race())[0].enabled)


func test_unit_tooltip_includes_upgrades() -> void:
	var sim := new_sim()
	var def := sim.data.unit_for_role(1, "heavy")
	sim.buy_upgrade(0, "heavy", "health")
	var tip := HudModel.unit_tooltip(sim, 0, def, _race())
	check(tip.contains("%d HP" % roundi(def.hp * 1.15)), tip)
	check(tip.contains("Upgrades: ♥ 1"), tip)


func test_matchup_table_rows_are_mine_columns_are_theirs() -> void:
	var sim := new_sim()
	var race := _race()
	sim.sides[1].age = 2
	var t := HudModel.matchup_table(sim, 0, race, race)
	check_eq(t.rows.size(), sim.roster(0).size(), "one row per unit I can train")
	check_eq(t.cols.size(), sim.roster(1).size() + 1, "enemy units plus Structures")
	check_eq(t.cols[-1], "Structures")
	var mine := sim.roster(0)[1]
	var theirs := sim.roster(1)[2]
	check(t.rows[1].name.begins_with(race.unit_name(mine)), t.rows[1].name)
	check(t.cols[2].begins_with(race.unit_name(theirs)), t.cols[2])
	check_near(t.rows[1].mults[2], sim.rules.matrix(mine.damage_type, theirs.armour), 1e-6)
	check_near(t.rows[1].mults[-1], sim.rules.matrix(mine.damage_type, "structure"), 1e-6)
