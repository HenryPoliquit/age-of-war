extends TestCase
## Skill visuals (SkillFx / SkillLook): a look for every race and skill, races that differ, and shots that
## land on the pulse they belong to. Drawing needs a canvas, so this covers choreography and stepping only.

const RACES: Array[StringName] = [&"human", &"elf", &"dwarf"]


func _view(age: int) -> MatchView:
	var view := MatchView.new()
	view.sim = new_sim()
	view.sim.record_fx = true
	view.sim.sides[0].age = age
	view.sim.sides[1].age = age
	view.world = WorldLayer.new()
	view.world.view = view
	view.fx = FxLayer.new()
	view.fx.view = view
	view.audio = AudioDirector.new()
	return view


func _free(view: MatchView) -> void:
	for n in view.world._corpse_nodes:
		n.free()
	view.world.free()
	view.fx.free()
	view.audio.free()
	view.free()


func test_every_skill_has_a_look_for_every_race() -> void:
	for a in GameData.get_default().ages:
		for race in RACES:
			var look := SkillLook.for_skill(race, String(a.ability.id))
			check(not look.is_empty(), "%s / %s" % [race, a.ability.id])
			check(look.get("glow") is Color, "%s / %s glow" % [race, a.ability.id])
			if a.ability.id == &"stampede":
				check(look.has("beast") and look.has("dust"), "%s herd" % race)
			else:
				check(look.has("shot") and look.has("from") and look.has("r"), "%s / %s shot" % [race, a.ability.id])
	check(not SkillLook.for_skill(&"orc", "rockfall").is_empty(), "an unknown race falls back to the human look")


func test_the_three_races_look_different_for_the_same_skill() -> void:
	for a in GameData.get_default().ages:
		var seen := {}
		for race in RACES:
			var look := SkillLook.for_skill(race, String(a.ability.id))
			seen[look.get("beast", look.get("shot", ""))] = true
		check_eq(seen.size(), 3, "%s has three different shots" % a.ability.id)


func test_races_never_change_what_a_skill_does() -> void:
	# The look table holds nothing the sim reads: the same ability data serves every race.
	for a in GameData.get_default().ages:
		for race in RACES:
			var look := SkillLook.for_skill(race, String(a.ability.id))
			for k in ["damage", "damage_pct", "width", "pulses", "xp_cost", "telegraph"]:
				check(not look.has(k), "%s / %s carries %s" % [race, a.ability.id, k])


func test_every_skill_choreographs_and_lands_on_time_for_every_race() -> void:
	for a in GameData.get_default().ages:
		var def: AbilityDef = a.ability
		for race in RACES:
			var view := _view(a.index)
			var sim := view.sim
			place(sim, 1, "vanguard", 900.0, a.index)
			place(sim, 1, "heavy", 940.0, a.index)
			check(sim.fire_ability(0, sim.to_world(1, 920.0)), "%s fires" % def.id)
			var ev: Dictionary = sim.match_log.events.filter(func(e): return e.type == "ability")[0]
			view.fx.skills.cast(ev, def, race)
			var last_pulse := def.telegraph + (def.pulses - 1) * def.pulse_interval
			var latest_landing := 0.0
			var t := 0.0
			var seen_items := 0
			while t < last_pulse + 1.5:
				view.anim_time = t
				view.fx.step(0.05)
				for it in view.fx.skills.items:
					seen_items += 1
					if it.k == "proj":
						latest_landing = maxf(latest_landing, it.born + it.dur)
				t += 0.05
			check(seen_items > 0, "%s / %s produced effects" % [def.id, race])
			if def.id != &"stampede":
				check(latest_landing <= last_pulse + 0.06, "%s / %s: last shot lands at %.2f, pulse at %.2f" % [def.id, race, latest_landing, last_pulse])
				check(latest_landing >= last_pulse - 0.35, "%s / %s: shots arrive with the last pulse (%.2f vs %.2f)" % [def.id, race, latest_landing, last_pulse])
			check(view.fx.scheduled.is_empty(), "%s / %s: nothing left scheduled" % [def.id, race])
			var live := view.fx.skills.items.filter(func(it): return it.k == "proj")
			check(live.is_empty(), "%s / %s: every shot has landed" % [def.id, race])
			_free(view)


func test_skill_hits_become_numbers_coloured_by_mode() -> void:
	var view := _view(4)
	var u := place(view.sim, 1, "vanguard", 900.0, 4)
	var cases := {"flat": Color("ffb45e"), "true": Color("8fe4ff"), "percent": Color("9df08a")}
	for mode in cases:
		view.fx.skills.hit({"type": "skill_hit", "x": 1500.0, "side": 1, "dealt": 123.4, "killed": false, "mode": mode, "pct": 0.18,
			"ability": "x", "unit_id": u.id, "def": u.def})
	check_eq(view.fx.skills.popups.size(), 3)
	for p in view.fx.skills.popups:
		check_eq(p.col, cases[p.mode], p.mode)
	check_eq(view.fx.skills.popups[0].text, "−123")
	check_eq(view.fx.skills.popups[2].text, "−18%")
	_free(view)


# ---------------------------------------------------------------------------
# Ground marks: circle, field, or nothing for a sweep

func test_aimed_skills_mark_the_ground_and_sweeps_do_not() -> void:
	var gd := GameData.get_default()
	var widths := {"circle": [], "field": []}
	for a in gd.ages:
		var kind := SkillLook.footprint(a.ability.id)
		if a.ability.aim == "target":
			check(kind in ["circle", "field"], "%s is aimed, so it needs a mark" % a.ability.id)
			widths[kind].append(a.ability.width)
		elif a.ability.shape == "sweep":
			check_eq(kind, "", "%s runs gate to gate: no warning" % a.ability.id)
	check_eq(SkillLook.footprint(&"rockfall"), "circle")
	check_eq(SkillLook.footprint(&"volley"), "field")
	for c in widths.circle:
		for f in widths.field:
			check(c < f, "a circle (%d px) is smaller than a field of land (%d px)" % [c, f])


func test_only_marked_skills_get_a_warning_on_the_ground() -> void:
	var view := _view(1)
	var sim := view.sim
	place(sim, 1, "vanguard", 1000.0)
	check(sim.fire_ability(0), "Stampede fires")
	check(view.fx.skills._marked_effects().is_empty(), "a sweep has no warning")
	_free(view)
	view = _view(2)
	place(view.sim, 1, "vanguard", 1000.0, 2)
	check(view.sim.fire_ability(0, view.sim.to_world(1, 1000.0)), "Rockfall fires")
	check_eq(view.fx.skills._marked_effects().size(), 1)
	_free(view)


func test_landing_spots_stay_inside_the_mark() -> void:
	var view := _view(2)
	var sk := view.fx.skills
	var c := {"lo": 1000.0, "hi": 1260.0}
	var mid := 1130.0
	var half := 130.0
	for i in 40:
		var p: Vector2 = sk._in_circle(c, i % 4, 4)
		var nx := (p.x - mid) / half
		var ny := (p.y - (SkillFx.GROUND_Y + 10.0)) / (half * SkillFx.CIRCLE_SQUASH)
		check(nx * nx + ny * ny <= 1.0, "boulder %d lands inside the circle (%s)" % [i, p])
	var f := {"lo": 1000.0, "hi": 1420.0}
	for i in 60:
		var p: Vector2 = sk._in_field(f, i % 6, 6)
		check(p.x >= 1000.0 and p.x <= 1420.0, "arrow %d lands inside the field's width" % i)
		check(p.y >= SkillFx.GROUND_Y + SkillFx.FIELD_BACK and p.y <= SkillFx.GROUND_Y + SkillFx.FIELD_FRONT, "and its depth (%s)" % p.y)
	_free(view)
