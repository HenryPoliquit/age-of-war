extends SceneTree
## Fires one skill in a staged match and saves a contact sheet of frames, for the skill-look review (GDD §7).
## Needs a display (use Xvfb in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/skill_gallery.gd -- --skill=rockfall --race=elf --out=reports/skill_rockfall_elf.png
## --skill=ID      stampede | rockfall | volley | bombardment | cannonade | starfall (default rockfall)
## --race=R        the caster's race: human | elf | dwarf (default human);  --enemy-race=R for the target's
## --races=a,b,c   one row per race in a single sheet (each row: the same skill, that race's look)
## --times=a,b,c   seconds after firing to grab a frame (default 0.2,0.7,1.0,1.4,1.9,2.6)
## --aim           don't fire: hold aim mode with the reticle over the enemy pack (one frame)
## --cols=N        sheet columns (default 3; each frame is scaled to fit 1920 px)
## --cam=X         camera centre x in world units (default 1500, over the enemy pack)
## --aim-x=X       where an aimed skill is aimed, in world x (default: the densest group)
## --enemy         the ENEMY fires at you instead (shows the warning marker as you would see it)

var out := "reports/skill_gallery.png"
var skill := "rockfall"
var race := &"human"
var races_list: Array[StringName] = []
var enemy_race := &"elf"
var times := PackedFloat32Array([0.2, 0.7, 1.0, 1.4, 1.9, 2.6])
var hold_aim := false
var enemy_fires := false
var cols := 3
var cam := 1500.0
var aim_x := NAN


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--skill="):
			skill = a.get_slice("=", 1)
		elif a.begins_with("--race="):
			race = StringName(a.get_slice("=", 1))
		elif a.begins_with("--races="):
			for r in a.get_slice("=", 1).split(","):
				races_list.append(StringName(r))
		elif a.begins_with("--enemy-race="):
			enemy_race = StringName(a.get_slice("=", 1))
		elif a.begins_with("--times="):
			times = PackedFloat32Array()
			for s in a.get_slice("=", 1).split(","):
				times.append(float(s))
		elif a.begins_with("--cols="):
			cols = int(a.get_slice("=", 1))
		elif a.begins_with("--cam="):
			cam = float(a.get_slice("=", 1))
		elif a.begins_with("--aim-x="):
			aim_x = float(a.get_slice("=", 1))
		elif a == "--aim":
			hold_aim = true
		elif a == "--enemy":
			enemy_fires = true
	_run.call_deferred()


func _run() -> void:
	var gd := GameData.get_default()
	var age := 0
	for a in gd.ages:
		if String(a.ability.id) == skill:
			age = a.index
	if age == 0:
		push_error("unknown skill %s" % skill)
		quit(1)
		return
	UnitArt.view_yaw = deg_to_rad(UnitArt.VIEW_YAW_DEG)
	if races_list.is_empty():
		races_list.append(race)
	if hold_aim:
		cols = 1
	var rows: Array = []
	for r in races_list:
		var frames: Array[Image] = await _capture(age, r)
		rows.append(frames)
	var n := (rows[0] as Array).size()
	var w := 1920 / (n if rows.size() > 1 else cols)
	var h := 1080 * w / 1920
	var per_row := n if rows.size() > 1 else cols
	var grid_rows := rows.size() if rows.size() > 1 else ceili(float(n) / cols)
	var sheet := Image.create(w * per_row, h * grid_rows, false, Image.FORMAT_RGB8)
	for ri in rows.size():
		for i in n:
			var img: Image = rows[ri][i]
			img.resize(w, h, Image.INTERPOLATE_LANCZOS)
			var cell := Vector2i((i % per_row) * w, (ri if rows.size() > 1 else i / cols) * h)
			sheet.blit_rect(img, Rect2i(0, 0, w, h), cell)
	sheet.save_png(out)
	print("skill gallery saved: ", out)
	quit()


## Builds a staged match with `caster_race` firing, fires (or holds aim mode) and returns the frames.
func _capture(age: int, caster_race: StringName) -> Array[Image]:
	var view := MatchView.new()
	view.start_age = age
	var races: Array[StringName] = []
	races.append(enemy_race if enemy_fires else caster_race)
	races.append(caster_race if enemy_fires else enemy_race)
	view.races = races
	root.add_child(view)
	await process_frame
	var sim := view.sim
	view.ai._timer = 1e9
	view._follow_front = false
	view._cam_x = cam
	_stage(sim, age)
	var caster := 1 if enemy_fires else 0
	sim.sides[caster].xp = 99999.0
	await process_frame
	await process_frame
	var frames: Array[Image] = []
	if hold_aim:
		view.aim.press()
		var pos := Vector2(1920.0 * 0.5, 700.0)
		root.warp_mouse(pos)
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		frames.append(img)
		print("aim mode ", view.aim.active, " cursor ", view.aim.cursor_x)
	else:
		var ok := sim.fire_ability(caster, aim_x)
		print("fired ", skill, " (", caster_race, "): ", ok)
		var t0 := view.anim_time
		for t in times:
			while view.anim_time - t0 < t:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			frames.append(img)
	view.queue_free()
	await process_frame
	return frames


## An enemy pack in front of the camera (world x 1400–1900) and our own line further back.
func _stage(sim: MatchSim, age: int) -> void:
	var lane := sim.rules.lane_length
	var pack := [["vanguard", 1420.0], ["vanguard", 1470.0], ["ranged", 1520.0], ["vanguard", 1575.0], ["heavy", 1650.0], ["ranged", 1740.0], ["vanguard", 1860.0]]
	for spec in pack:
		var def := sim.data.unit_for_role(age, spec[0])
		# The side that is not firing is the target; unit progress is measured from its own gate.
		var u := sim._spawn(sim.sides[1], def, def.cost)
		u.progress = lane - spec[1]
		u.hp = u.max_hp * 20.0
		u.max_hp = u.hp
	for spec in [["vanguard", 700.0], ["ranged", 640.0], ["heavy", 780.0]]:
		var def := sim.data.unit_for_role(age, spec[0])
		var u := sim._spawn(sim.sides[0], def, def.cost)
		u.progress = spec[1]
		u.hp = u.max_hp * 20.0
		u.max_hp = u.hp
