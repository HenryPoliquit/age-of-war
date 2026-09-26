class_name WorldLayer
extends Node2D
## Draws bases, turrets, units and corpses from MatchSim state, interpolated between sim ticks.
## Animation follows code-driven movement (GDD §13.3): stride phase comes from distance walked,
## attack poses from the sim's attack timestamps.

const GROUND_Y := 760.0
const UNIT_SCALE := 1.25
const STRIDE := {"humanoid": 0.16, "mounted": 0.11, "chariot": 0.12, "mech": 0.09}

var view: MatchView
var corpses: Array[Dictionary] = []
## Per-unit eased walk amount (0 idle … 1 walking): state changes blend over ~0.12 s (PRD §11).
var move_amt := {}
const BLEND_TIME := 0.12
var _font: Font


const OUTLINE := preload("res://shaders/unit_outline.gdshader")

## One CanvasGroup per side so each side's units get an ink outline with a team rim.
var _groups: Array[CanvasGroup] = []
var _drawers: Array[Node2D] = []
var _overlay: Node2D


const GRAIN := preload("res://shaders/split_backdrop.gdshader")


func _ready() -> void:
	_font = UiStyle.font("bold")
	# Bases and turrets get the same painterly surface grain as the scenery (no seam masking).
	var gm := ShaderMaterial.new()
	gm.shader = GRAIN
	gm.set_shader_parameter("side", 0.0)
	gm.set_shader_parameter("opaque_left", true)
	gm.set_shader_parameter("grain", 0.18)
	material = gm
	for side in 2:
		var g := CanvasGroup.new()
		g.fit_margin = 6.0
		g.clear_margin = 6.0
		var m := ShaderMaterial.new()
		m.shader = OUTLINE
		g.material = m
		add_child(g)
		var d := Node2D.new()
		d.draw.connect(_draw_side_units.bind(side, d))
		g.add_child(d)
		_groups.append(g)
		_drawers.append(d)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


static func jitter(id: int) -> float:
	return float((id * 37) % 13) - 6.0


static func anim_len(def: UnitDef) -> float:
	return clampf(def.attack_interval * 0.8, 0.35, 0.9)


func unit_pos(u: SimUnit) -> Vector2:
	var sim := view.sim
	var p: float = view.prev_progress.get(u.id, u.progress)
	var prog := lerpf(p, u.progress, view.alpha)
	return Vector2(sim.to_world(u.side, prog), GROUND_Y + jitter(u.id))


func _process(delta: float) -> void:
	var t := view.anim_time
	var step := delta * float(view.speeds[view.speed_index]) / BLEND_TIME
	var seen := {}
	for s in view.sim.sides:
		for u in s.units:
			var target := 1.0 if u.state == &"walk" else 0.0
			move_amt[u.id] = move_toward(move_amt.get(u.id, target), target, step)
			seen[u.id] = true
	if move_amt.size() > seen.size() + 64:
		for k in move_amt.keys():
			if not seen.has(k):
				move_amt.erase(k)
	corpses = corpses.filter(func(c): return t - c.born < 1.4)
	_update_corpse_nodes()
	var dn_l: DayNight = view.backdrops[0].dn
	BaseArt.night = 1.0 - dn_l.daylight if dn_l != null else 0.0
	queue_redraw()
	for side in 2:
		var m: ShaderMaterial = _groups[side].material
		m.set_shader_parameter("rim", view.team_color(side))
		m.set_shader_parameter("width", 2.0 * view.camera.zoom.x)
		# Key light follows the sun/moon of the side's backdrop; weaker and cooler at night.
		var dn: DayNight = view.backdrops[side].dn
		if dn != null:
			var bp := dn.body_pos()
			m.set_shader_parameter("light_dir", Vector2(bp.x - 0.5, 0.9 - bp.y / 1080.0))
			m.set_shader_parameter("light_color", Color(1.0, 0.93, 0.82).lerp(Color(0.6, 0.7, 1.0), 1.0 - dn.daylight).lerp(Color(1.0, 0.7, 0.5), dn.twilight * 0.6))
			m.set_shader_parameter("shade_strength", lerpf(0.35, 0.6, dn.daylight))
		_drawers[side].queue_redraw()
	_overlay.queue_redraw()


func _draw() -> void:
	var sim := view.sim
	var t := view.anim_time
	var rt := view.render_time()
	for s in sim.sides:
		_draw_base(s, t)
	# Hold rally line flags.
	for s in sim.sides:
		if s.stance == &"hold":
			var rx := sim.to_world(s.index, s.rally_progress)
			draw_line(Vector2(rx, GROUND_Y + 10), Vector2(rx, GROUND_Y - 70), Color(0.2, 0.15, 0.1), 3.0)
			BaseArt._banner(self, Vector2(rx, GROUND_Y - 70), view.team_color(s.index), t, 18)
			for k in 8:
				draw_line(Vector2(rx - 2, GROUND_Y + 14 + k * 0.0), Vector2(rx + 2, GROUND_Y + 14), view.team_color(s.index), 2.0)
	# Front-line marker: a small standard where the seam meets the ground.
	var fx := sim.front_x
	draw_line(Vector2(fx, GROUND_Y + 16), Vector2(fx, GROUND_Y - 34), Color(1, 1, 1, 0.35), 2.0)


## Units of one side, back-to-front by lane depth.
func _draw_side_units(side: int, n: Node2D) -> void:
	var units: Array[SimUnit] = view.sim.sides[side].units.duplicate()
	units.sort_custom(func(a, b): return jitter(a.id) < jitter(b.id) or (jitter(a.id) == jitter(b.id) and a.id < b.id))
	var rt := view.render_time()
	var t := view.anim_time
	for u in units:
		_draw_unit(n, u, rt, t)
	n.draw_set_transform(Vector2.ZERO)


## HP bars, veterancy chevrons and the ability aim marker, drawn over the outlined units.
func _draw_overlay() -> void:
	var sim := view.sim
	for s in sim.sides:
		for u in s.units:
			_draw_bars(_overlay, u)
	if view.aiming:
		var ov := _overlay
		var def := sim.data.age(sim.sides[0].age).ability
		var x := view.aim_x
		var c := view.team_color(0).lightened(0.5)
		ov.draw_rect(Rect2(x - def.width * 0.5, GROUND_Y - 6, def.width, 16), Color(c, 0.35))
		for k in int(def.width / 16):
			ov.draw_line(Vector2(x - def.width * 0.5 + k * 16, GROUND_Y - 130), Vector2(x - def.width * 0.5 + k * 16 + 8, GROUND_Y - 130), c, 2.0)
		ov.draw_line(Vector2(x - def.width * 0.5, GROUND_Y - 130), Vector2(x - def.width * 0.5, GROUND_Y + 10), c, 2.0)
		ov.draw_line(Vector2(x + def.width * 0.5, GROUND_Y - 130), Vector2(x + def.width * 0.5, GROUND_Y + 10), c, 2.0)
		ov.draw_string(_font, Vector2(x - 60, GROUND_Y - 140), def.display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, c)


func _draw_base(s: SimSide, t: float) -> void:
	var sim := view.sim
	var gate := sim.to_world(s.index, 0.0)
	var dir := 1.0 if s.index == 0 else -1.0
	var team := view.team_color(s.index)
	var build := clampf((t - view.base_rebuilt.get(s.index, -10.0)) / 1.1, 0.0, 1.0)
	var xf := Transform2D(0.0, Vector2(dir, 1), 0.0, Vector2(gate, GROUND_Y + 4))
	UnitArt.begin(self, xf)
	BaseArt.draw_base(self, s.age, team, s.base_hp / s.base_max_hp, t, build, s.turret_slots, self)
	# Doctrine banners hang on the base (GDD §9: shown so the player can counter-plan).
	for i in s.doctrines.size():
		var p := Vector2(-170 + i * 40, -60)
		draw_rect(Rect2(p, Vector2(28, 40)), team.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, 40), p + Vector2(28, 40), p + Vector2(14, 50)]), team.darkened(0.25))
		draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(dir, 1), 0.0, p + Vector2(14, 26)))
		draw_string(_font, Vector2(-12 if dir > 0 else -12, 0), String(s.doctrines[i].display_name).left(2), HORIZONTAL_ALIGNMENT_CENTER, 24, 14, Color.WHITE)
		draw_set_transform_matrix(xf)
	for i in s.turret_slots:
		var tur: SimTurret = s.turrets[i]
		if tur == null:
			continue
		var sp := BaseArt.slot_pos(i)
		var world := xf * sp
		var key := s.index * 10 + i
		var target_x: float = tur.last_target_x if tur.last_fire_time > -5.0 else gate + dir * 300.0
		var aim := atan2((GROUND_Y - 20) - world.y, absf(target_x - world.x))
		var kick := clampf(1.0 - (sim.time - tur.last_fire_time) / 0.25, 0.0, 1.0)
		draw_set_transform_matrix(xf * Transform2D(0.0, sp))
		BaseArt.draw_turret(self, tur.def, team, aim, kick, t, tur.def.age < s.age)
		if tur.hp < tur.max_hp:
			draw_rect(Rect2(-14, 16, 28, 3), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(-14, 16, 28 * tur.hp / tur.max_hp, 3), Color("e05050"))
		draw_set_transform_matrix(xf)
		if tur.def.kind == "support":
			draw_set_transform(Vector2.ZERO)
			var r := tur.def.aura_radius
			var x0 := gate if dir > 0 else gate - r
			draw_rect(Rect2(x0, GROUND_Y + 2, r, 10), Color(team.lightened(0.3), 0.12 + 0.05 * sin(t * 2.0)))
			draw_set_transform_matrix(xf)
	draw_set_transform(Vector2.ZERO)


func _pose(u: SimUnit, rt: float, t: float) -> Dictionary:
	var rig: String = UnitArt.style_for(u.def).rig
	var p: float = view.prev_progress.get(u.id, u.progress)
	var prog := lerpf(p, u.progress, view.alpha)
	var atk := -1.0
	var since := rt - u.last_attack_time
	var L := anim_len(u.def)
	if since >= 0.0 and since < L:
		atk = since / L
	var fl := clampf(1.0 - (t - view.flash_at.get(u.id, -10.0)) / 0.09, 0.0, 1.0) * view.fx.flash_scale
	return {"walk": prog * STRIDE.get(rig, 0.1), "move": move_amt.get(u.id, 1.0 if u.state == &"walk" else 0.0), "atk": atk, "t": t + u.id * 0.37, "flash": fl}


func _draw_unit(ci: CanvasItem, u: SimUnit, rt: float, t: float) -> void:
	var pos := unit_pos(u)
	var dir := 1.0 if u.side == 0 else -1.0
	var sc := UNIT_SCALE * (1.0 + 0.03 * (u.age - 1))
	UnitArt.begin(ci, Transform2D(0.0, Vector2(dir * sc, sc), 0.0, pos))
	UnitArt.draw_unit(ci, u.def, view.team_color(u.side), _pose(u, rt, t), u.id)
	ci.draw_set_transform(Vector2.ZERO)
	if u.armour_buff_until > view.sim.time:
		var h := UnitArt.height_for(u.def) * UNIT_SCALE
		ci.draw_arc(pos + Vector2(0, -h * 0.5), h * 0.6, 0, TAU, 24, Color(view.team_color(u.side).lightened(0.6), 0.55), 2.0)


func _draw_bars(ci: CanvasItem, u: SimUnit) -> void:
	var pos := unit_pos(u)
	var h := UnitArt.height_for(u.def) * UNIT_SCALE + 10.0
	if u.vet_rank > 0:
		for i in u.vet_rank:
			ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-8 + i * 7, -h - 8), pos + Vector2(-5 + i * 7, -h - 12), pos + Vector2(-2 + i * 7, -h - 8)]), Color("f2c14e"))
	if u.hp >= u.max_hp:
		return
	var w := 26.0 if u.def.role != "heavy" else 38.0
	ci.draw_rect(Rect2(pos + Vector2(-w * 0.5 - 1, -h - 1), Vector2(w + 2, 5)), Color(0, 0, 0, 0.65))
	ci.draw_rect(Rect2(pos + Vector2(-w * 0.5, -h), Vector2(w * u.hp / u.max_hp, 3)), view.team_color(u.side).lightened(0.35))


func add_corpse(def: UnitDef, x: float, side: int, id: int) -> void:
	if corpses.size() >= _corpse_nodes.size():
		corpses.pop_front()
	corpses.append({"def": def, "x": x, "side": side, "id": id, "born": view.anim_time})


## Corpses fade out, which needs per-corpse alpha: each is drawn by its own pooled child node
## (behind the living units) whose modulate carries the fade.
var _corpse_nodes: Array[Node2D] = []


func _enter_tree() -> void:
	for i in 24:
		var n := Node2D.new()
		n.show_behind_parent = true
		n.draw.connect(_draw_corpse_node.bind(i))
		add_child(n)
		_corpse_nodes.append(n)


func _update_corpse_nodes() -> void:
	var t := view.anim_time
	for i in _corpse_nodes.size():
		var n := _corpse_nodes[i]
		if i < corpses.size():
			var u: float = (t - corpses[i].born) / 1.4
			n.visible = true
			n.modulate.a = clampf((1.0 - u) * 2.5, 0.0, 1.0)
			n.queue_redraw()
		else:
			n.visible = false


func _draw_corpse_node(i: int) -> void:
	if i >= corpses.size():
		return
	var c: Dictionary = corpses[i]
	var n := _corpse_nodes[i]
	var u: float = (view.anim_time - c.born) / 1.4
	var def: UnitDef = c.def
	var rig: String = UnitArt.style_for(def).rig
	var dir := 1.0 if c.side == 0 else -1.0
	var pos := Vector2(c.x, GROUND_Y + jitter(c.id))
	var wreck := rig in ["car", "mech", "rail", "howitzer", "ram", "trebuchet", "mortar", "chariot"]
	var fall := 0.0 if wreck else -dir * ease(clampf(u / 0.25, 0.0, 1.0), 0.5) * PI * 0.5
	UnitArt.begin(n, Transform2D(fall, Vector2(dir, 1) * UNIT_SCALE, 0.0, pos + Vector2(0, -2)))
	var col := view.team_color(c.side).darkened(0.35)
	UnitArt.draw_unit(n, def, col, {"walk": 0.0, "moving": false, "atk": -1.0, "t": 0.0, "flash": 0.0}, c.id)
	n.draw_set_transform(Vector2.ZERO)
