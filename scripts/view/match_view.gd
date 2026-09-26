class_name MatchView
extends Node2D
## Match presentation: steps MatchSim at its fixed tick, interpolates between ticks, and turns sim
## FX records and events into visuals (projectiles, impacts, corpses, evolution moment).
## Contains no rules — every action goes through MatchSim commands, exactly like the AI's.

signal exit_to_menu
signal rematch

const GROUND_Y := 760.0
const TEAM := [Color("3f86e0"), Color("ec8a2c")]
const TEAM_ALT := [Color("2fb3a3"), Color("d1497f")]
const VIGNETTE := preload("res://shaders/vignette.gdshader")

var personality_id: StringName = &"tactician"
var difficulty_id: StringName = &"normal"
var colourblind := false
var start_age := 1

var sim: MatchSim
var ai: UtilityAI
## Debug/demo: `-- --autoplay` lets a Tactician play the left side too.
var left_ai: UtilityAI
var hud: MatchHud
var camera: Camera2D
var backdrops: Array[Backdrop] = []
var world: WorldLayer
var fx: FxLayer
var lights: LightPool
var audio: AudioDirector
var _last_tide := 1
var _ability_ready := false

var speeds := [1.0, 2.0, 0.0]
var speed_index := 0
var aiming := false
var aim_x := 0.0

## Presentation clock: advances with game speed, freezes on hitstop and pause.
var anim_time := 0.0
## Interpolation factor between the previous and current sim tick.
var alpha := 1.0
var prev_progress := {}
var flash_at := {}
var base_rebuilt := {}

var _accum := 0.0
var _freeze := 0.0
var _shake := 0.0
var _punch := 0.0
var _slowmo_until := -1.0
var _cam_x := 900.0
var _drag_pan := false
var _logged := false
## Demo/autoplay: the camera tracks the front line.
var _follow_front := false


func _ready() -> void:
	var seed := int(Time.get_unix_time_from_system()) % 1000003
	sim = MatchSim.new(GameData.get_default(), seed)
	sim.record_fx = true
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--speed="):
			speeds[0] = float(a.get_slice("=", 1))
		elif a.begins_with("--start-age="):
			start_age = int(a.get_slice("=", 1))
	if start_age > 1:
		sim.set_start_age(start_age)
	ai = UtilityAI.make(sim.data, personality_id, difficulty_id, MatchSim.RIGHT, seed + 17)
	ai.setup(sim)
	sim.sides[0].controller_name = "Player"
	if "--autoplay" in args:
		left_ai = UtilityAI.make(sim.data, &"tactician", &"hard", MatchSim.LEFT, seed + 3)
		left_ai.setup(sim)
	sim.event_emitted.connect(_on_event)
	colourblind = GameSettings.get_value("colourblind")
	audio = AudioDirector.new()
	add_child(audio)
	audio.start(sim.sides[0].age)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	for i in 2:
		var b := Backdrop.new()
		b.setup(i, sim.sides[i].age)
		add_child(b)
		backdrops.append(b)
	world = WorldLayer.new()
	world.view = self
	add_child(world)
	lights = LightPool.new()
	add_child(lights)
	fx = FxLayer.new()
	fx.view = self
	fx.lights = lights
	add_child(fx)
	apply_settings()
	var post := CanvasLayer.new()
	post.layer = 1
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = VIGNETTE
	vig.material = vm
	post.add_child(vig)
	add_child(post)
	hud = MatchHud.new()
	hud.view = self
	hud.layer = 5
	add_child(hud)
	apply_settings()
	_cam_x = get_viewport_rect().size.x * 0.5 - 140.0
	_follow_front = left_ai != null
	for a in args:
		if a.begins_with("--cam="):
			_cam_x = float(a.get_slice("=", 1))
			_follow_front = false
	_place_camera(0.0)


func apply_settings() -> void:
	colourblind = GameSettings.get_value("colourblind")
	fx.intensity = GameSettings.particle_scale()
	fx.flash_scale = 0.5 if GameSettings.get_value("flash_reduction") else 1.0
	lights.enabled = GameSettings.lights_enabled()
	if hud != null:
		hud.shake_scale = GameSettings.get_value("shake")


func team_color(side: int) -> Color:
	return (TEAM_ALT if colourblind else TEAM)[side]


func set_speed(i: int) -> void:
	speed_index = i


func begin_aim() -> void:
	if sim.can_fire_ability(0):
		aiming = true


func render_time() -> float:
	return sim.time - sim.rules.tick_dt * (1.0 - alpha)


func add_shake(amount: float) -> void:
	_shake = minf(18.0, _shake + amount)


func hitstop(seconds: float) -> void:
	_freeze = maxf(_freeze, seconds)


func zoom_punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var spd: float = speeds[speed_index]
	if anim_time < _slowmo_until:
		spd *= 0.5  # Evolution moment: time slows to 50% (GDD §13.5).
	if _freeze > 0.0:
		_freeze -= delta
		spd = 0.0
	var dt := sim.rules.tick_dt
	_accum += delta * spd
	var steps := 0
	while _accum >= dt and steps < 400 and not sim.is_over():
		for s in sim.sides:
			for u in s.units:
				prev_progress[u.id] = u.progress
		ai.update(sim, dt)
		if left_ai != null:
			left_ai.update(sim, dt)
		sim.step()
		_accum -= dt
		steps += 1
		_consume_fx()
	if sim.is_over():
		_accum = 0.0
	alpha = clampf(_accum / dt, 0.0, 1.0)
	var adt := delta * spd
	anim_time += adt
	fx.step(adt)
	if prev_progress.size() > 400:
		_prune_prev()
	_pan(delta)
	_place_camera(delta)
	var cam_x := camera.get_screen_center_position().x
	for b in backdrops:
		b.cam_x = cam_x
		b.seam_x = sim.front_x
		b.time = anim_time
	_audio_state()
	# Ambient tint follows whichever age fills most of the screen.
	var w := smoothstep(-500.0, 500.0, cam_x - sim.front_x)
	lights.update(anim_time, LightPool.AMBIENT[sim.sides[0].age - 1].lerp(LightPool.AMBIENT[sim.sides[1].age - 1], w))
	if aiming:
		aim_x = clampf(get_global_mouse_position().x, 0.0, sim.rules.lane_length)
	if sim.is_over() and not _logged:
		_logged = true
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		sim.match_log.meta = {"left": "player", "right": String(personality_id), "right_difficulty": String(difficulty_id), "winner": sim.winner, "duration": sim.time}
		sim.match_log.save_json("user://logs/match_%s.json" % stamp)
		hud.show_post_match()


## Music intensity from lane pressure, plus tide / escalation / ability-ready cues (GDD §13.8).
func _audio_state() -> void:
	var fighting := 0
	for s in sim.sides:
		for u in s.units:
			if u.state == &"attack":
				fighting += 1
	var pressure := clampf(fighting / 10.0, 0.0, 1.0)
	if sim.time - sim.sides[0].last_base_hit_time < 5.0:
		pressure = maxf(pressure, 0.8)
	if sim.escalation > 0:
		pressure = maxf(pressure, 0.7)
	audio.target_intensity = pressure
	var tide := sim.rules.tide_level_at(sim.time)
	if tide != _last_tide:
		_last_tide = tide
		audio.play("tide")
	var ready := sim.can_fire_ability(0)
	if ready and not _ability_ready:
		audio.play("ability_ready")
	_ability_ready = ready


func _prune_prev() -> void:
	var alive := {}
	for s in sim.sides:
		for u in s.units:
			alive[u.id] = true
	for k in prev_progress.keys():
		if not alive.has(k):
			prev_progress.erase(k)
			flash_at.erase(k)


func _pan(delta: float) -> void:
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	var vp := get_viewport_rect().size
	var m := get_viewport().get_mouse_position()
	if not _drag_pan and m.y > 80 and m.y < vp.y - 200 and DisplayServer.window_is_focused():
		if m.x < 12:
			dir -= 1.0
		elif m.x > vp.x - 12:
			dir += 1.0
	_cam_x += dir * 1000.0 * delta
	if _follow_front:
		_cam_x = lerpf(_cam_x, sim.front_x, 1.0 - exp(-2.0 * delta))


func _place_camera(delta: float) -> void:
	var vp := get_viewport_rect().size
	var half := vp.x * 0.5
	_cam_x = clampf(_cam_x, half - 260.0, sim.rules.lane_length - half + 260.0)
	_shake = maxf(0.0, _shake - 40.0 * delta)
	_punch = maxf(0.0, _punch - 0.25 * delta)
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * hud.shake_scale
	camera.position = Vector2(_cam_x, vp.y * 0.5) + shake
	camera.zoom = Vector2.ONE * (1.0 + _punch)


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
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_x -= 120.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_x += 120.0
	elif event is InputEventMouseMotion and _drag_pan:
		_cam_x -= event.relative.x
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
			if aiming:
				aiming = false
			else:
				hud.open_settings()


func toggle_stance() -> void:
	if sim.sides[0].stance == &"advance":
		var x := get_global_mouse_position().x
		if x < 100.0 or x > sim.rules.lane_length - 100.0:
			x = sim.rules.lane_length * 0.35
		sim.set_stance(0, &"hold", x)
	else:
		sim.set_stance(0, &"advance")


# ---------------------------------------------------------------------------
# Sim → visuals

func _on_event(ev: Dictionary) -> void:
	match ev.type:
		"evolve_start":
			var side: int = ev.side
			audio.play("evolve", Vector2.INF if side == 0 else Vector2(sim.to_world(side, 0.0), GROUND_Y), 0.0 if side == 0 else -4.0)
			fx.evolution_wave(sim.to_world(side, 0.0) + (-90.0 if side == 0 else 90.0), team_color(side))
			if side == 0 or left_ai == null:
				_slowmo_until = anim_time + 0.5
		"evolve":
			var side: int = ev.side
			backdrops[side].set_age(ev.age)
			if side == 0:
				audio.set_age(ev.age)
			base_rebuilt[side] = anim_time
			hud.banner("%s Age" % sim.data.age(ev.age).display_name, team_color(side), side)
		"ability":
			fx.ability_cast(ev.ability, ev.x, ev.side)
			audio.play("ability_cast", Vector2(ev.x, GROUND_Y - 100))
			hud.banner(sim.data.age(sim.sides[ev.side].age).ability.display_name + "!", team_color(ev.side), ev.side, true)
		"match_end":
			audio.target_intensity = 0.0
		"turret_destroyed":
			var gate := sim.to_world(ev.side, 0.0)
			fx.impact("blast", Vector2(gate + (-80.0 if ev.side == 0 else 80.0), GROUND_Y - 140), true, true)


func _consume_fx() -> void:
	for f in sim.fx:
		match f.type:
			"shot":
				_on_shot(f)
			"turret_shot":
				_on_turret_shot(f)
			"death":
				_on_death(f)
			"ability_pulse":
				fx.ability_pulse(f.ability, f.lo, f.hi, f.side, team_color(f.side))
				if f.ability != "shieldwall":
					for u in sim.sides[1 - f.side].units:
						var x := sim.to_world(u.side, u.progress)
						if x >= f.lo and x <= f.hi:
							flash_at[u.id] = anim_time + 0.1
	sim.fx.clear()


const RANGED_KIND := {"sling": "stone", "javelin": "javelin", "bow": "arrow", "musket": "bullet", "rifle": "tracer", "pulse": "bolt"}
const SIEGE_KIND := {"trebuchet": "shell", "mortar": "shell", "howitzer": "shell", "rail": "bolt", "mech": "bolt", "car": "bullet"}


func _on_shot(f: Dictionary) -> void:
	var def: UnitDef = f.def
	var u: SimUnit = f.unit
	var st := UnitArt.style_for(def)
	var dir := 1.0 if f.side == 0 else -1.0
	var L := WorldLayer.anim_len(def)
	var target: SimUnit = f.target
	var origin := Vector2(f.from_x, GROUND_Y + WorldLayer.jitter(u.id))
	var to: Vector2
	if target != null:
		to = Vector2(f.to_x, GROUND_Y + WorldLayer.jitter(target.id) - UnitArt.height_for(target.def) * WorldLayer.UNIT_SCALE * 0.5)
	else:
		to = Vector2(f.to_x + dir * 40.0, GROUND_Y - 70.0)
	var dtype: String = def.damage_type
	var heavy: bool = def.role in ["heavy", "siege"]
	var structure: bool = f.structure
	var rig: String = st.rig
	var weapon: String = st.get("weapon", "")
	var kind: String = RANGED_KIND.get(weapon, SIEGE_KIND.get(rig, ""))
	var target_id := target.id if target != null else -1
	var hit := func():
		var vis := dtype
		# Cavalry hits read as heavy blows, not explosions.
		if dtype == "blast" and rig in ["mounted", "chariot"]:
			vis = "slash"
		fx.impact("siege" if structure and heavy else vis, to, heavy, structure)
		if target_id >= 0:
			flash_at[target_id] = anim_time
	if kind == "":
		# Melee: the hit lands on the contact frame of the swing (GDD §13.3).
		fx.later(L * 0.42, hit)
		return
	var muzzle := origin + Vector2(dir * 28.0, -42.0) * WorldLayer.UNIT_SCALE
	var big := false
	match rig:
		"trebuchet":
			muzzle = origin + Vector2(dir * 40.0, -110.0)
		"mortar":
			muzzle = origin + Vector2(dir * 22.0, -32.0)
			big = true
		"howitzer":
			muzzle = origin + Vector2(dir * 46.0, -42.0)
			big = true
		"rail", "mech":
			muzzle = origin + Vector2(dir * 56.0, -56.0)
			big = true
		"car":
			muzzle = origin + Vector2(dir * 34.0, -50.0)
	var gun := kind in ["bullet", "tracer", "bolt"] or rig in ["mortar", "howitzer"]
	var col := team_color(f.side).lightened(0.5)
	fx.later(L * 0.35, func():
		if gun:
			fx.muzzle(muzzle, 0.0 if dir > 0 else PI, big, col if kind == "bolt" else Color(1.0, 0.8, 0.4),
				"zap" if kind == "bolt" else ("cannon" if big else "gun"))
		fx.shoot(kind, muzzle, to, dtype, hit, heavy)
		if kind == "bolt":
			fx.projectiles[-1]["col"] = col)


const TURRET_KIND := {
	"sentry": ["stone", "arrow", "javelin", "bullet", "tracer", "bolt"],
	"artillery": ["shell", "shell", "shell", "ball", "shell", "bolt"],
}


func _on_turret_shot(f: Dictionary) -> void:
	var def: TurretDef = f.def
	var side: int = f.side
	var dir := 1.0 if side == 0 else -1.0
	var gate := sim.to_world(side, 0.0)
	var sp := BaseArt.slot_pos(f.slot)
	var from := Vector2(gate + dir * sp.x, GROUND_Y + 4 + sp.y - 8)
	var target: SimUnit = f.target
	var to := Vector2(f.to_x, GROUND_Y - (UnitArt.height_for(target.def) * 0.5 if target != null else 6.0))
	var kind: String = TURRET_KIND.get(def.kind, ["stone"])[clampi(def.age - 1, 0, 5)]
	var tid := target.id if target != null else -1
	var splash := def.kind == "artillery"
	var col := team_color(side).lightened(0.5)
	if kind in ["bullet", "tracer", "ball", "bolt"] or (splash and def.age >= 4):
		fx.muzzle(from + Vector2(dir * 18.0, 0), 0.0 if dir > 0 else PI, splash, col if kind == "bolt" else Color(1.0, 0.8, 0.4),
			"zap" if kind == "bolt" else ("cannon" if splash else "gun"))
	var enemy := 1 - side
	var radius := def.splash
	fx.shoot(kind, from, to, def.damage_type, func():
		fx.impact(def.damage_type, to, splash)
		if tid >= 0:
			flash_at[tid] = anim_time
		if splash:
			for v in sim.sides[enemy].units:
				if absf(sim.to_world(v.side, v.progress) - to.x) <= radius:
					flash_at[v.id] = anim_time, splash)
	if kind == "bolt":
		fx.projectiles[-1]["col"] = col


func _on_death(f: Dictionary) -> void:
	var def: UnitDef = f.def
	world.add_corpse(def, f.x, f.side, f.unit_id)
	audio.play("death", Vector2(f.x, GROUND_Y), -4.0)
	var rig: String = UnitArt.style_for(def).rig
	if rig in ["car", "mech", "rail", "howitzer"]:
		fx.impact("blast", Vector2(f.x, GROUND_Y - 24), true)
	elif rig in ["ram", "trebuchet", "mortar", "chariot"]:
		fx.impact("siege", Vector2(f.x, GROUND_Y - 20))
	else:
		fx.burst("smoke", Vector2(f.x, GROUND_Y - 4), 4, Color(0.7, 0.62, 0.5, 0.5), Vector2(10, 40), Vector2(0.4, 0.8), Vector2(6, 12), -10.0)
