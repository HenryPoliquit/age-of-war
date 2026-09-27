extends TestCase
## The view-only melee gap (spec §3): units are drawn back by their body depth; everything the view
## places at a unit — flashes, death effects — must agree with that, and the sim decides who is hit.


func _view() -> MatchView:
	var view := MatchView.new()
	view.sim = new_sim()
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


func test_drawn_x_includes_the_age_draw_scale() -> void:
	# Units are drawn at UNIT_SCALE × (1 + 0.03 × (age − 1)); the shift must use the same scale or
	# late-age cavalry overlap again.
	var view := _view()
	var def := view.sim.data.unit_for_role(6, "heavy")
	var race := view.race_of(0)
	var want := 1000.0 - UnitArt.depth_for(def, race) * WorldLayer.UNIT_SCALE * (1.0 + 0.03 * 5)
	check_near(view.world.drawn_x(def, 0, 1000.0), want, 0.01)
	check_near(view.world.drawn_x(def, 1, 1000.0), 2000.0 - want, 0.01, "mirrored for the right side")
	_free(view)


func test_splash_flash_follows_the_sim() -> void:
	# The artillery shell's target is recorded at its sim x; the sim decided who took splash damage.
	var view := _view()
	var sim := view.sim
	var mount := place(sim, 1, "heavy", 800.0)
	var far := place(sim, 1, "vanguard", 800.0 - 70.0)
	view._splash_flash(1, sim.to_world(1, mount.progress), 60.0)
	check(view.flash_at.has(mount.id), "the unit at the impact point flashes")
	check(not view.flash_at.has(far.id), "a unit 70 px away (sim) does not")
	_free(view)


func test_death_effects_play_at_the_corpse() -> void:
	var view := _view()
	var node := Node2D.new()
	view.world._corpse_nodes.append(node)
	for role in ["vanguard", "heavy"]:
		var def := view.sim.data.unit_for_role(2, role)
		view.fx.particles.clear()
		view._on_death({"def": def, "x": 1000.0, "side": 0, "unit_id": 7})
		var cx: float = view.world.corpses[-1].x
		check_near(cx, view.world.drawn_x(def, 0, 1000.0), 0.01, "%s corpse at the drawn x" % role)
		check(not view.fx.particles.is_empty(), "%s death spawns effects" % role)
		for p in view.fx.particles:
			check(absf((p.pos as Vector2).x - cx) < 1.0, "%s effect at the corpse, not the sim x" % role)
	_free(view)
