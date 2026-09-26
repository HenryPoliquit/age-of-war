class_name MatchView
extends Node2D
## Graybox match presentation (M0/M1): draws MatchSim state as coloured boxes and hosts the HUD.
## Contains no rules — every action goes through MatchSim commands, exactly like the AI's.

signal exit_to_menu
signal rematch

const GROUND_Y := 760.0
const TEAM := [Color("3b7dd8"), Color("e8862a")]
const TEAM_ALT := [Color("2f9e8f"), Color("c8457a")]
const ROLE_SIZE := {"vanguard": Vector2(18, 34), "ranged": Vector2(13, 30), "heavy": Vector2(34, 42), "siege": Vector2(32, 24)}
var SPEEDS := [1.0, 2.0, 0.0]

var personality_id: StringName = &"tactician"
var difficulty_id: StringName = &"normal"
var colourblind := false

var sim: MatchSim
var ai: UtilityAI
## Debug/demo: `-- --autoplay` lets a Tactician play the left side too.
var left_ai: UtilityAI
var hud: MatchHud
var camera: Camera2D
var speed_index := 0
var aiming := false
var aim_x := 0.0
var _accum := 0.0
var _fx: Array[Dictionary] = []
var _drag_pan := false
var _logged := false
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var seed := int(Time.get_unix_time_from_system()) % 1000003
	sim = MatchSim.new(GameData.get_default(), seed)
	sim.record_fx = true
	ai = UtilityAI.make(sim.data, personality_id, difficulty_id, MatchSim.RIGHT, seed + 17)
	ai.setup(sim)
	sim.sides[0].controller_name = "Player"
	var args := OS.get_cmdline_user_args()
	if "--autoplay" in args:
		left_ai = UtilityAI.make(sim.data, &"tactician", &"hard", MatchSim.LEFT, seed + 3)
		left_ai.setup(sim)
	for a in args:
		if a.begins_with("--speed="):
			SPEEDS[0] = float(a.get_slice("=", 1))
	camera = Camera2D.new()
	camera.position = Vector2(640, 540)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()
	hud = MatchHud.new()
	hud.view = self
	add_child(hud)


func team_color(side: int) -> Color:
	return (TEAM_ALT if colourblind else TEAM)[side]


func set_speed(i: int) -> void:
	speed_index = i


func begin_aim() -> void:
	if sim.can_fire_ability(0):
		aiming = true


func _process(delta: float) -> void:
	var spd: float = SPEEDS[speed_index]
	_accum += delta * spd
	var dt := sim.rules.tick_dt
	var steps := 0
	while _accum >= dt and steps < 400 and not sim.is_over():
		ai.update(sim, dt)
		if left_ai != null:
			left_ai.update(sim, dt)
		sim.step()
		_accum -= dt
		steps += 1
	for f in sim.fx:
		f["born"] = sim.time
		_fx.append(f)
	sim.fx.clear()
	_fx = _fx.filter(func(f): return sim.time - f.born < 0.35)
	_pan(delta)
	if aiming:
		aim_x = clampf(get_global_mouse_position().x, 0.0, sim.rules.lane_length)
	if sim.is_over() and not _logged:
		_logged = true
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		sim.match_log.meta = {"left": "player", "right": String(personality_id), "right_difficulty": String(difficulty_id), "winner": sim.winner, "duration": sim.time}
		sim.match_log.save_json("user://logs/match_%s.json" % stamp)
		hud.show_post_match()
	queue_redraw()


func _pan(delta: float) -> void:
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	var vp := get_viewport_rect().size
	var m := get_viewport().get_mouse_position()
	if not _drag_pan and m.y > 80 and m.y < vp.y - 200:
		if m.x < 12:
			dir -= 1.0
		elif m.x > vp.x - 12:
			dir += 1.0
	var half := vp.x * 0.5
	camera.position.x = clampf(camera.position.x + dir * 900.0 * delta, half - 160.0, sim.rules.lane_length - half + 160.0)
	camera.position.y = vp.y * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_drag_pan = event.pressed
			if event.pressed and aiming:
				aiming = false
		elif event.button_index == MOUSE_BUTTON_LEFT and aiming and not event.pressed:
			# Drag the marker on the lane, release to fire (GDD §10).
			sim.fire_ability(0, aim_x)
			aiming = false
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and sim.sides[0].stance == &"hold" and event.shift_pressed:
			sim.set_stance(0, &"hold", get_global_mouse_position().x)
	elif event is InputEventMouseMotion and _drag_pan:
		camera.position.x -= event.relative.x
	elif event is InputEventKey and event.pressed and not event.echo:
		_hotkey(event.physical_keycode)


func _hotkey(k: Key) -> void:
	match k:
		KEY_1, KEY_2, KEY_3, KEY_4:
			var i := k - KEY_1
			var roster := sim.roster(0)
			if i < roster.size():
				hud.feedback(sim.queue_unit(0, roster[i]))
		KEY_Q, KEY_W, KEY_E, KEY_R:
			hud.slot_pressed([KEY_Q, KEY_W, KEY_E, KEY_R].find(k))
		KEY_T:
			hud.feedback(sim.evolve(0))
		KEY_V:
			hud.feedback(sim.buy_veterancy(0))
		KEY_F:
			hud.feedback(sim.buy_forge(0))
		KEY_SPACE:
			begin_aim()
		KEY_S:
			toggle_stance()
		KEY_F1:
			set_speed(0)
		KEY_F2:
			set_speed(1)
		KEY_F3:
			set_speed(2)
		KEY_ESCAPE:
			aiming = false


func toggle_stance() -> void:
	if sim.sides[0].stance == &"advance":
		var x := get_global_mouse_position().x
		if x < 100.0 or x > sim.rules.lane_length - 100.0:
			x = sim.rules.lane_length * 0.35
		sim.set_stance(0, &"hold", x)
	else:
		sim.set_stance(0, &"advance")


# ---------------------------------------------------------------------------
# Drawing

func _draw() -> void:
	var lane := sim.rules.lane_length
	var l_age := sim.data.age(sim.sides[0].age)
	var r_age := sim.data.age(sim.sides[1].age)
	var top := -200.0
	var bottom := 1300.0
	var seam := 90.0
	var fx_ := sim.front_x
	# Split battlefield (GDD §13.6): each half shows that side's age, blended at the front line.
	draw_rect(Rect2(-600, top, fx_ - seam + 600, GROUND_Y - top), l_age.sky_color)
	draw_rect(Rect2(fx_ + seam, top, lane + 600 - fx_ - seam, GROUND_Y - top), r_age.sky_color)
	draw_polygon(PackedVector2Array([Vector2(fx_ - seam, top), Vector2(fx_ + seam, top), Vector2(fx_ + seam, GROUND_Y), Vector2(fx_ - seam, GROUND_Y)]),
		PackedColorArray([l_age.sky_color, r_age.sky_color, r_age.sky_color, l_age.sky_color]))
	draw_rect(Rect2(-600, GROUND_Y, fx_ + 600, bottom - GROUND_Y), l_age.ground_color)
	draw_rect(Rect2(fx_, GROUND_Y, lane + 600 - fx_, bottom - GROUND_Y), r_age.ground_color)
	draw_line(Vector2(lane * 0.5, GROUND_Y + 6), Vector2(lane * 0.5, GROUND_Y + 30), Color(1, 1, 1, 0.35), 2.0)
	# Front marker
	draw_line(Vector2(fx_, GROUND_Y - 150), Vector2(fx_, GROUND_Y), Color(1, 1, 1, 0.5), 2.0)
	draw_rect(Rect2(fx_, GROUND_Y - 150, 26, 16), Color(1, 1, 1, 0.6))
	for s in sim.sides:
		_draw_base(s)
	# Hold rally line
	var me := sim.sides[0]
	if me.stance == &"hold":
		var rx := sim.to_world(0, me.rally_progress)
		for y in range(int(GROUND_Y - 120), int(GROUND_Y), 16):
			draw_line(Vector2(rx, y), Vector2(rx, y + 8), team_color(0), 3.0)
	for s in sim.sides:
		for u in s.units:
			_draw_unit(u)
	for e in sim.effects:
		var def: AbilityDef = e.def
		var c := team_color(e.side)
		c.a = 0.22
		draw_rect(Rect2(e.center - def.width * 0.5, GROUND_Y - 160, def.width, 170), c)
	for f in _fx:
		var age_t: float = sim.time - f.born
		var a := 1.0 - age_t / 0.35
		match f.type:
			"hit":
				var col := {"slash": Color.WHITE, "pierce": Color("ffe28a"), "blast": Color("ff7b3a"), "siege": Color("c9b08a")}.get(f.dtype, Color.WHITE) as Color
				col.a = a
				var y := GROUND_Y - (80.0 if f.get("structure", false) else 22.0)
				draw_circle(Vector2(f.x, y), 4.0 + age_t * (40.0 if f.dtype == "blast" else 14.0), col)
			"death":
				draw_rect(Rect2(f.x - 12, GROUND_Y - 30 * a, 24, 30 * a), Color(0.1, 0.1, 0.1, a * 0.6))
			"ability_pulse":
				draw_rect(Rect2(f.lo, GROUND_Y - 180, f.hi - f.lo, 190), Color(1, 1, 1, a * 0.35))
	if aiming:
		var def := sim.data.age(me.age).ability
		draw_rect(Rect2(aim_x - def.width * 0.5, GROUND_Y - 160, def.width, 170), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(aim_x - def.width * 0.5, GROUND_Y - 160, def.width, 170), Color.WHITE, false, 2.0)


func _draw_base(s: SimSide) -> void:
	var lane := sim.rules.lane_length
	var w := 110.0
	var h := 150.0 + 18.0 * s.age
	var x := -w if s.index == 0 else lane
	var c := team_color(s.index).darkened(0.35)
	draw_rect(Rect2(x, GROUND_Y - h, w, h), c)
	draw_rect(Rect2(x, GROUND_Y - h, w, h), Color.BLACK, false, 2.0)
	draw_string(_font, Vector2(x + 8, GROUND_Y - h + 22), sim.data.age(s.age).display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if s.is_evolving():
		draw_string(_font, Vector2(x + 8, GROUND_Y - h + 42), "Evolving…", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)
	for d in s.doctrines.size():
		draw_rect(Rect2(x + 10 + d * 34, GROUND_Y - h - 36, 28, 36), team_color(s.index))
		draw_string(_font, Vector2(x + 13 + d * 34, GROUND_Y - h - 12), String(s.doctrines[d].display_name).left(2), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for i in s.turret_slots:
		var tx := x + 8 + (i % 3) * 34
		var ty := GROUND_Y - h + 56 + (i / 3) * 34
		var t: SimTurret = s.turrets[i]
		if t == null:
			draw_rect(Rect2(tx, ty, 28, 28), Color(1, 1, 1, 0.25), false, 1.5)
			continue
		var tc := {"sentry": Color("d9d9d9"), "artillery": Color("8c8c8c"), "support": Color("7fbf7f")}[t.def.kind] as Color
		if t.def.age < s.age:
			tc = tc.darkened(0.4)
		draw_rect(Rect2(tx, ty, 28, 28), tc)
		draw_string(_font, Vector2(tx + 8, ty + 20), str(t.def.age), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		if sim.time - t.last_fire_time < 0.1:
			draw_line(Vector2(tx + 14, ty + 14), Vector2(t.last_target_x, GROUND_Y - 20), Color(1, 1, 0.6, 0.7), 2.0)
		if t.hp < t.max_hp:
			draw_rect(Rect2(tx, ty - 5, 28 * t.hp / t.max_hp, 3), Color.RED)


func _draw_unit(u: SimUnit) -> void:
	var sz: Vector2 = ROLE_SIZE[u.def.role]
	var x := sim.to_world(u.side, u.progress)
	var dir := 1.0 if u.side == 0 else -1.0
	if u.state == &"attack":
		var since := sim.time - u.last_attack_time
		if since < 0.15:
			x += dir * 5.0 * (1.0 - since / 0.15)
	var jitter := float((u.id * 37) % 11) - 5.0
	var base := GROUND_Y + jitter
	var col := team_color(u.side)
	col = col.lerp(Color.WHITE, 0.08 * (u.age - 1))
	if sim.time - u.last_hit_time < 0.06:
		col = col.lerp(Color.WHITE, 0.8)
	var r := Rect2(x - sz.x * 0.5, base - sz.y, sz.x, sz.y)
	draw_rect(r, col)
	draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
	# Role glyph: ranged gets a bow line, heavy a band, siege a wheel pair.
	match u.def.role:
		"ranged":
			draw_line(Vector2(x + dir * 7, base - sz.y + 4), Vector2(x + dir * 7, base - 8), Color.BLACK, 2.0)
		"heavy":
			draw_rect(Rect2(r.position.x, base - sz.y * 0.55, sz.x, 5), Color(0, 0, 0, 0.5))
		"siege":
			draw_circle(Vector2(x - 9, base - 2), 5, Color.BLACK)
			draw_circle(Vector2(x + 9, base - 2), 5, Color.BLACK)
	if u.vet_rank > 0:
		for i in u.vet_rank:
			draw_rect(Rect2(x - 7 + i * 5, base - sz.y - 12, 3, 4), Color.GOLD)
	if u.armour_buff_until > sim.time:
		draw_rect(r.grow(3), Color(0.6, 0.85, 1, 0.8), false, 2.0)
	if u.hp < u.max_hp:
		draw_rect(Rect2(x - 12, base - sz.y - 7, 24, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(x - 12, base - sz.y - 7, 24 * u.hp / u.max_hp, 3), Color("5fd35f"))
