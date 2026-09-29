extends SceneTree
## Renders animation frames of every unit (3 races × 6 ages × 4 roles) for review: each frame is one
## grid image where every cell holds the unit three times — walking, attacking in place, and the same attack
## mirrored as the enemy army draws it.
## tools/anim_page.py slices the frames into one looping GIF per unit and writes a browsable page.
##   godot --path . --resolution 1280x720 -s tools/unit_anim.gd -- --out=reports/anim/frames --frames=24

const CELL := Vector2(600, 260)
const COLS := 6
const SCALE := 2.0

var out := "reports/anim/frames"
var frames := 24
var frame := 0
var vp := SubViewport.new()
var node := Node2D.new()
var units: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--yaw="):
			UnitArt.view_yaw = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--frames="):
			frames = int(a.get_slice("=", 1))
	var gd := GameData.get_default()
	for r in RaceLook.IDS:
		for age in gd.ages:
			for def in age.units:
				units.append({"race": r, "def": def, "name": gd.race(r).unit_name(def)})
	var rows := ceili(units.size() / float(COLS))
	vp.size = Vector2i(int(CELL.x) * COLS, int(CELL.y) * rows)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("8a8f98")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	node.draw.connect(_draw)
	vp.add_child(node)
	DirAccess.make_dir_recursive_absolute(out)
	var lines: Array[String] = []
	for i in units.size():
		var u: Dictionary = units[i]
		lines.append("%d\t%s\t%s\t%s\t%d\t%s" % [i, u.race, u.def.id, u.def.role, u.def.age, u.name])
	FileAccess.open(out.path_join("units.tsv"), FileAccess.WRITE).store_string("\n".join(lines))
	_run.call_deferred()


func _draw() -> void:
	var u := float(frame) / frames
	for i in units.size():
		var cell := Vector2(i % COLS, i / COLS) * CELL
		var def: UnitDef = units[i].def
		var race: StringName = units[i].race
		var walk := {"walk": u * TAU, "move": 1.0, "atk": -1.0, "t": u * 2.0, "flash": 0.0}
		# Attack: the whole 0..1 swing, then a short guard hold so the loop reads.
		var a := u * 1.25
		var attack := {"walk": 0.6, "move": 0.0, "atk": a if a <= 1.0 else -1.0, "t": u * 2.0, "flash": 0.0}
		# Walking, attacking, and the same attack as the enemy army sees it (mirrored, facing left).
		for p in 3:
			var enemy := p == 2
			FkPaint.begin(node, Transform2D(0.0, Vector2(-SCALE if enemy else SCALE, SCALE), 0.0, cell + Vector2(100 + p * 200, CELL.y - 18)))
			UnitArt.draw_unit(node, def, Color("c8423a") if enemy else Color("3a78d8"), walk if p == 0 else (attack.merged({"mirrored": true}) if enemy else attack), 5, race)
		node.draw_set_transform(Vector2.ZERO)


func _run() -> void:
	for f in frames:
		frame = f
		node.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out.path_join("f%03d.png" % f))
	print("frames saved: ", frames, " × ", units.size(), " units → ", out)
	quit()
