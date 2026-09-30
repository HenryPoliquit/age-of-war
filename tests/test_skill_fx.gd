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
			if def.id == &"starfall":
				check_eq(latest_landing, 0.0, "Starfall throws nothing at the ground: its strikes come from the units it hits")
			elif def.id != &"stampede":
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


# ---------------------------------------------------------------------------
# Starfall hits units only

## Runs the sim and the view together for `seconds`, feeding the sim's records to the skill visuals, and returns
## the world x of every strike the visuals drew.
func _strike_targets(view: MatchView, seconds: float, pinned: Array = []) -> Array[float]:
	var sim := view.sim
	var out: Array[float] = []
	var at := pinned.map(func(u): return u.progress)
	for i in roundi(seconds / 0.1):
		sim.step()
		for k in pinned.size():
			pinned[k].progress = at[k]
		view.anim_time = sim.time
		for f in sim.fx:
			if f.type == "ability_pulse":
				view.fx.skills.pulse(f)
			elif f.type == "skill_hit":
				view.fx.skills.hit(f)
		sim.fx.clear()
		for it in view.fx.skills.items:
			if it.get("struck", false):
				continue
			it["struck"] = true
			match it.k:
				"column":
					out.append(it.x)
				"bolt":
					out.append((it.main as PackedVector2Array)[-1].x)
				"proj":
					out.append((it.to as Vector2).x)
		view.fx.step(0.1)
	return out


func test_starfall_strikes_land_on_the_units_inside_the_circle_and_nowhere_else() -> void:
	for race in RACES:
		var view := _view(6)
		var sim := view.sim
		sim.sides[0].race = race
		var inside: Array[SimUnit] = []
		for p in [880.0, 900.0, 925.0]:
			var u := place(sim, 1, "vanguard", p, 6)
			u.hp = 1e9
			u.max_hp = 1e9
			inside.append(u)
		var outside := place(sim, 1, "vanguard", 400.0, 6)  # x = 2000, far from the circle
		outside.hp = 1e9
		outside.max_hp = 1e9
		var aim := sim.to_world(1, 900.0)
		check(sim.fire_ability(0, aim), "%s fires" % race)
		var xs := _strike_targets(view, 5.0, inside + [outside])
		check(xs.size() >= inside.size(), "%s: a strike for every unit in the circle, every pulse (got %d)" % [race, xs.size()])
		var unit_xs: Array[float] = []
		for u in inside:
			unit_xs.append(view.world.drawn_x(u.def, 1, sim.to_world(1, u.progress)))
		for x in xs:
			check(unit_xs.any(func(ux): return absf(ux - x) < 60.0), "%s: a strike at x=%.0f lands on a unit" % [race, x])
		var far_x := view.world.drawn_x(outside.def, 1, sim.to_world(1, outside.progress))
		check(not xs.any(func(x): return absf(x - far_x) < 120.0), "%s: nothing falls on the unit outside the circle" % race)
		check(view.fx.decals.is_empty(), "%s: no scorch or crater on the ground" % race)
		check(not view.fx.particles.any(func(p): return p.kind == "ring"), "%s: no blast ring" % race)
		_free(view)


func test_starfall_draws_strikes_only_on_the_unit_it_hits() -> void:
	var view := _view(6)
	var sim := view.sim
	var far := place(sim, 1, "vanguard", 400.0, 6)
	far.hp = 1e9
	far.max_hp = 1e9
	# One unit in the circle: every strike drawn is on it.
	check(sim.fire_ability(0, sim.to_world(1, 400.0)))
	var xs := _strike_targets(view, 5.0, [far])
	var far_x := view.world.drawn_x(far.def, 1, sim.to_world(1, far.progress))
	check(not xs.is_empty(), "the unit in the circle is struck")
	for x in xs:
		check(absf(x - far_x) < 130.0, "strike at %.0f stays with the unit (%.0f)" % [x, far_x])
	_free(view)


# ---------------------------------------------------------------------------
# The marks on the ground (SkillGround)

func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_a_warning_glows_in_its_race_colour_and_the_enemys_leans_red() -> void:
	var view := _view(2)
	var sim := view.sim
	sim.sides[0].race = &"elf"
	sim.sides[1].race = &"elf"
	place(sim, 1, "vanguard", 1000.0, 2)
	place(sim, 0, "vanguard", 1000.0, 2)
	var glow: Color = SkillLook.for_skill(&"elf", "rockfall").glow
	check(sim.fire_ability(0, sim.to_world(1, 1000.0)), "ours fires")
	sim.sides[1].xp = 99999.0
	check(sim.fire_ability(1, sim.to_world(0, 1000.0)), "theirs fires")
	var marks: Array[Dictionary] = view.fx.skills._marks()
	check_eq(marks.size(), 2)
	var ours: Dictionary = marks.filter(func(m): return m.lo < 1500.0 and m.hi > 900.0 and not m.reticle)[0]
	check(_distance(ours.col, glow) < 0.001, "our mark is the skill's own colour")
	var theirs: Dictionary = marks.filter(func(m): return m != ours)[0]
	check(_distance(theirs.col, SkillLook.DANGER) < _distance(glow, SkillLook.DANGER), "the enemy's mark is pushed toward red")
	check_eq(theirs.kind, "circle")
	_free(view)


func test_the_reticle_is_a_mark_too_gold_when_it_would_hit_and_red_when_it_would_not() -> void:
	var view := _view(3)
	var sim := view.sim
	place(sim, 1, "vanguard", 900.0, 3)
	view.aim.press()
	view.aim.cursor_x = sim.to_world(1, 900.0)
	var marks: Array[Dictionary] = view.fx.skills._marks()
	check_eq(marks.size(), 1)
	check(marks[0].reticle and marks[0].kind == "field", "Volley's reticle is a field")
	check_near(marks[0].lo, view.aim.cursor_x - sim.data.age(3).ability.width * 0.5, 0.01, "centred on the cursor")
	check_eq(marks[0].col, Color("ffc61a"), "gold over units")
	view.aim.cursor_x = 50.0
	marks = view.fx.skills._marks()
	check_eq(marks[0].col, Color("ff5a4a"), "red over nothing")
	view.aim.cancel()
	check(view.fx.skills._marks().is_empty(), "nothing once aiming ends")
	_free(view)


func test_a_warning_fills_as_it_runs_out() -> void:
	var view := _view(2)
	var sim := view.sim
	place(sim, 1, "vanguard", 1000.0, 2)
	check(sim.fire_ability(0, sim.to_world(1, 1000.0)))
	var first: float = view.fx.skills._marks()[0].progress
	for i in 4:
		sim.step()
	var later: float = view.fx.skills._marks()[0].progress
	check(first < 0.1 and later > first, "progress grows (%.2f -> %.2f)" % [first, later])
	_free(view)
