extends SceneTree
## Owner review sheet: one role for one race — rows = ages, columns = walk ×4, guard, wind-up, strike, recover.
##   godot --path . --resolution 1920x1080 -s tools/unit_sheet.gd -- --role=vanguard --race=elf --out=reports/sheet_vanguard_elf.png

const COLS := [["walk", 0.0, 1.0, -1.0], ["walk", 1.6, 1.0, -1.0], ["walk", 3.1, 1.0, -1.0], ["walk", 4.7, 1.0, -1.0],
	["guard", 0.6, 0.0, -1.0], ["wind-up", 0.6, 0.0, 0.25], ["strike", 0.6, 0.0, 0.45], ["recover", 0.6, 0.0, 0.75]]

var out := "reports/unit_sheet.png"
var race: StringName = &"human"
var role := "vanguard"
var vp := SubViewport.new()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--race="):
			race = StringName(a.get_slice("=", 1))
		elif a.begins_with("--role="):
			role = a.get_slice("=", 1)
	vp.size = Vector2i(1920, 1440)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("8a8f98")
	bg.size = Vector2(1920, 1440)
	vp.add_child(bg)
	var n := Node2D.new()
	n.draw.connect(_draw.bind(n))
	vp.add_child(n)
	_capture.call_deferred()


func _draw(n: Node2D) -> void:
	var gd := GameData.get_default()
	var f := UiStyle.font("bold")
	for c in COLS.size():
		n.draw_string(f, Vector2(150 + c * 220, 34), COLS[c][0], HORIZONTAL_ALIGNMENT_CENTER, 200, 18, Color(0.1, 0.1, 0.1))
	for age in range(1, 7):
		var def := gd.unit_for_role(age, role)
		if def == null:
			continue
		var y := 60 + age * 225
		n.draw_string(f, Vector2(8, y - 150), gd.race(race).unit_name(def), HORIZONTAL_ALIGNMENT_LEFT, 150, 16, Color(0.1, 0.1, 0.1))
		for c in COLS.size():
			var col: Array = COLS[c]
			FkPaint.begin(n, Transform2D(0.0, Vector2(2.4, 2.4), 0.0, Vector2(250 + c * 220, y)))
			UnitArt.draw_unit(n, def, Color("3a78d8"), {"walk": col[1], "move": col[2], "atk": col[3], "t": 0.3, "flash": 0.0}, age * 4, race)
			n.draw_set_transform(Vector2.ZERO)


func _capture() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("sheet saved: ", out)
	quit()
