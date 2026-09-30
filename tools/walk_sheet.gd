extends SceneTree
## Walk-cycle review sheet: rows = an age's vanguard, ranged and heavy unit, columns = eight phases of one stride, so the
## legs' bend (and any stretch where they are straight) can be read at a glance. Needs a display (Xvfb in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/walk_sheet.gd -- --race=human --age=3 --out=reports/walk_human_3.png
## --race=human|elf|dwarf   --age=1..6   --yaw=DEG   --scale=N (default 3.2)
## --role=vanguard|ranged|heavy   one role only, its row drawn taller   --phases=N   phases across the sheet (default 8)
## --atk=sweep   draw the attack instead of the walk, its progress running 0..1 across the columns (the stance and lean)

var roles := ["vanguard", "ranged", "heavy"]
var phases := 8
var sweep := false

var out := "reports/walk_sheet.png"
var race: StringName = &"human"
var age := 3
var zoom := 3.2
var vp := SubViewport.new()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--race="):
			race = StringName(a.get_slice("=", 1))
		elif a.begins_with("--age="):
			age = int(a.get_slice("=", 1))
		elif a.begins_with("--scale="):
			zoom = float(a.get_slice("=", 1))
		elif a.begins_with("--role="):
			roles = [a.get_slice("=", 1)]
		elif a.begins_with("--phases="):
			phases = int(a.get_slice("=", 1))
		elif a.begins_with("--atk="):
			sweep = true
		elif a.begins_with("--yaw="):
			UnitArt.view_yaw = deg_to_rad(float(a.get_slice("=", 1)))
	vp.size = Vector2i(1920, 1000)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("8a8f98")
	bg.size = Vector2(1920, 1000)
	vp.add_child(bg)
	var n := Node2D.new()
	n.draw.connect(_draw.bind(n))
	vp.add_child(n)
	_capture.call_deferred()


func _draw(n: Node2D) -> void:
	var gd := GameData.get_default()
	var f := UiStyle.font("bold")
	var cell := 1880.0 / phases
	for c in phases:
		n.draw_string(f, Vector2(20 + c * cell, 24), ("atk %.2f" % (float(c) / maxf(1.0, phases - 1.0))) if sweep else "%d/%d" % [c, phases], HORIZONTAL_ALIGNMENT_CENTER, cell, 16, Color(0.1, 0.1, 0.1))
	var row_h := 310.0 if roles.size() > 1 else 900.0
	for r in roles.size():
		var def := gd.unit_for_role(age, roles[r])
		if def == null:
			continue
		var y := (300.0 if roles.size() > 1 else 640.0) + r * row_h
		n.draw_string(f, Vector2(8, 24), gd.race(race).unit_name(def), HORIZONTAL_ALIGNMENT_LEFT, 200, 16, Color(0.1, 0.1, 0.1))
		for c in phases:
			FkPaint.begin(n, Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2(20 + (c + 0.5) * cell, y)))
			var pose := {"walk": TAU * c / phases, "move": 1.0, "atk": -1.0, "t": 0.3, "flash": 0.0}
			if sweep:
				pose = {"walk": 0.6, "move": 0.0, "atk": float(c) / maxf(1.0, phases - 1.0), "t": 0.3, "flash": 0.0}
			UnitArt.draw_unit(n, def, Color("3a78d8"), pose, age * 4, race)
			n.draw_set_transform(Vector2.ZERO)


func _capture() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("sheet saved: ", out)
	quit()
