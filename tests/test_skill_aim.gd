extends TestCase
## The player's aim mode (SkillAim) and the HUD text around it. Runs against a bare MatchSim.


## A match where side 0 is in the Bronze Age (an aimed skill) facing a pack at x = 1500 and a lone unit.
func _aimed_sim() -> MatchSim:
	var sim := new_sim()
	sim.sides[0].age = 2
	place(sim, 1, "vanguard", 900.0, 2)
	place(sim, 1, "vanguard", 906.0, 2)
	place(sim, 1, "vanguard", 1900.0, 2)
	return sim


func test_an_auto_skill_fires_on_one_press() -> void:
	var sim := new_sim()
	place(sim, 1, "vanguard", 1000.0)
	var aim := SkillAim.new(sim)
	check(aim.press())
	check(not aim.active, "no aim mode for an auto skill")
	check_eq(sim.effects.size(), 1, "it fired")


func test_an_aimed_skill_opens_aim_mode_without_spending_anything() -> void:
	var sim := _aimed_sim()
	var xp := sim.sides[0].xp
	var aim := SkillAim.new(sim)
	check(aim.press())
	check(aim.active)
	check_near(sim.sides[0].xp, xp, 0.001, "nothing spent yet")
	check(sim.effects.is_empty(), "nothing fired yet")


func test_a_click_fires_the_skill_where_it_was_aimed() -> void:
	var sim := _aimed_sim()
	var aim := SkillAim.new(sim)
	aim.press()
	check(aim.confirm(sim.to_world(1, 1900.0)), "aimed at the lone unit")
	check(not aim.active, "aim mode ends")
	check_eq(sim.effects.size(), 1)
	var ev: Dictionary = sim.match_log.events.filter(func(e): return e.type == "ability")[0]
	check_near(ev.x, sim.to_world(1, 1900.0), 0.01, "centred on the click")


func test_a_click_on_empty_ground_costs_nothing_and_keeps_aiming() -> void:
	var sim := _aimed_sim()
	var xp := sim.sides[0].xp
	var aim := SkillAim.new(sim)
	aim.press()
	check(not aim.confirm(50.0), "nothing near x = 50")
	check(aim.active, "still aiming")
	check_near(sim.sides[0].xp, xp, 0.001)
	check(aim.confirm(sim.to_world(1, 900.0)), "a second click on the pack works")


func test_pressing_again_cancels() -> void:
	var sim := _aimed_sim()
	var xp := sim.sides[0].xp
	var aim := SkillAim.new(sim)
	aim.press()
	check(aim.press(), "cancelling is not an error")
	check(not aim.active)
	check_near(sim.sides[0].xp, xp, 0.001)


func test_space_twice_lets_the_game_aim() -> void:
	var sim := _aimed_sim()
	var aim := SkillAim.new(sim)
	check(aim.hotkey())
	check(aim.active, "first press aims")
	check(aim.hotkey(), "second press fires")
	check(not aim.active)
	var ev: Dictionary = sim.match_log.events.filter(func(e): return e.type == "ability")[0]
	check_near(ev.x, sim.ability_default_aim(0), 0.5 + sim.data.age(2).ability.width, "on the densest group")
	check(absf(ev.x - sim.to_world(1, 903.0)) < 10.0, "the pack, not the lone unit")


func test_aim_mode_ends_when_the_skill_is_no_longer_available() -> void:
	var sim := _aimed_sim()
	var aim := SkillAim.new(sim)
	aim.press()
	sim.sides[0].xp = 0.0
	aim.tick()
	check(not aim.active, "not enough XP any more")
	sim.sides[0].xp = 99999.0
	aim.press()
	sim.sides[0].age = 3
	aim.tick()
	check(not aim.active, "the new era's skill is not aimed")
	sim.sides[0].age = 2
	aim.press()
	sim.sides[1].units.clear()
	aim.tick()
	check(not aim.active, "no enemy left")


func test_press_fails_when_the_skill_cannot_fire() -> void:
	var sim := _aimed_sim()
	var aim := SkillAim.new(sim)
	sim.sides[0].xp = 0.0
	check(not aim.press(), "no XP")
	check(not aim.active)
	sim.sides[0].xp = 99999.0
	sim.sides[0].ability_cooldown = 5.0
	check(not aim.press(), "cooldown")
	sim.sides[0].ability_cooldown = 0.0
	sim.sides[1].units.clear()
	check(not aim.press(), "nothing to hit")


func test_preview_follows_the_cursor_only_while_aiming() -> void:
	var sim := _aimed_sim()
	var aim := SkillAim.new(sim)
	aim.cursor_x = sim.to_world(1, 900.0)
	check(aim.preview().is_empty(), "not aiming")
	aim.press()
	check(aim.preview().is_empty(), "cursor off the battlefield")
	aim.cursor_x = sim.to_world(1, 900.0)
	check_eq(aim.preview().count, 2)
	aim.cursor_x = 20.0
	check_eq(aim.preview().count, 0)
	aim.cancel()
	check(aim.preview().is_empty())


# ---------------------------------------------------------------------------
# HUD text

func _race() -> RaceDef:
	return GameData.get_default().race(&"human")


func test_the_skill_button_tells_aimed_from_auto() -> void:
	var sim := _aimed_sim()
	var st := HudModel.skill_state(sim, 0, _race())
	check(st.text.begins_with("◎ Rockfall"), st.text)
	check(st.tooltip.contains("click a spot on the lane"), st.tooltip)
	check(st.enabled)
	st = HudModel.skill_state(sim, 0, _race(), true)
	check_eq(st.text, "✕ Cancel aim")
	check(st.enabled, "the button cancels while aiming")
	sim.sides[0].age = 1
	st = HudModel.skill_state(sim, 0, _race())
	check(st.text.begins_with("☄ Stampede"), st.text)


func test_the_skill_tooltip_says_what_the_damage_does() -> void:
	var sim := new_sim()
	place(sim, 1, "vanguard", 1000.0)
	var expect := {1: "slash damage", 2: "blast damage", 3: "true damage", 4: "% of each unit's max health", 5: "blast damage", 6: "% of each unit's max health"}
	for age in expect:
		sim.sides[0].age = age
		var tip: String = HudModel.skill_state(sim, 0, _race()).tooltip
		check(tip.contains(expect[age]), "age %d: %s" % [age, tip])
	sim.sides[0].age = 3
	check(HudModel.skill_state(sim, 0, _race()).tooltip.contains("ignoring armour"), "true damage says so")
	sim.sides[0].age = 2
	check(HudModel.skill_state(sim, 0, _race()).tooltip.contains("slowed 40%"), "Rockfall says it slows")


func test_the_aim_hint_reports_targets() -> void:
	var sim := _aimed_sim()
	var aim := SkillAim.new(sim)
	aim.press()
	var off := HudModel.aim_hint(sim, 0, _race(), aim.preview())
	check(off.contains("AIM ROCKFALL") and off.contains("Move the cursor"), off)
	aim.cursor_x = sim.to_world(1, 900.0)
	var on := HudModel.aim_hint(sim, 0, _race(), aim.preview())
	check(on.contains("2 enemy units in the zone"), on)
	aim.cursor_x = 20.0
	check(HudModel.aim_hint(sim, 0, _race(), aim.preview()).contains("No enemy units in the zone"))
