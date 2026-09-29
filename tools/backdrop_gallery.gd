extends SceneTree
## Renders backdrops (sky, scenery layers, ground, foreground props and weather, plus the base at the gate) for art
## review. Needs a display (use Xvfb in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/backdrop_gallery.gd -- --race=elf --ages=1,2,3,4 --out=reports/backdrop_elf.png
## --race=human|elf|dwarf   the race (default elf)
## --ages=1,2,3,4           which ages, up to four, laid out 2 × 2 (default 1,2,3,4)
## --solo=elf:3             one backdrop at full size instead of a grid
## --cam=X                  camera centre x in world units (the game keeps it between 700 and 1700; default 900)
## --time=S                 animation time (default 3)

var out := "reports/backdrop_gallery.png"
var race := &"elf"
var ages: Array = [1, 2, 3, 4]
var solo := ""
var cam := 900.0
var anim_time := 3.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--race="):
			race = StringName(a.get_slice("=", 1))
		elif a.begins_with("--ages="):
			ages = []
			for s in a.get_slice("=", 1).split(","):
				ages.append(int(s))
		elif a.begins_with("--solo="):
			solo = a.get_slice("=", 1)
		elif a.begins_with("--cam="):
			cam = float(a.get_slice("=", 1))
		elif a.begins_with("--time="):
			anim_time = float(a.get_slice("=", 1))
	_run.call_deferred()


func _run() -> void:
	if solo != "":
		var img := await _render(StringName(solo.get_slice(":", 0)), int(solo.get_slice(":", 1)))
		img.save_png(out)
	else:
		var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
		for i in mini(ages.size(), 4):
			var img := await _render(race, ages[i])
			img.convert(Image.FORMAT_RGB8)
			img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
		sheet.save_png(out)
	print("gallery saved: ", out)
	quit()


func _render(p_race: StringName, age: int) -> Image:
	UnitArt.view_yaw = deg_to_rad(UnitArt.VIEW_YAW_DEG)
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera := Camera2D.new()
	camera.position = Vector2(cam, 540)
	vp.add_child(camera)
	camera.make_current()
	var back := Backdrop.new()
	back.setup(0, age, p_race)
	vp.add_child(back)
	var base := Node2D.new()
	base.draw.connect(func() -> void:
		FkPaint.begin(base, Transform2D(0.0, Vector2.ONE, 0.0, Vector2(0, 760)))
		BaseArt.draw_base(base, age, Color("3b8de0"), 1.0, anim_time, 1.0, null, p_race)
		base.draw_set_transform(Vector2.ZERO))
	vp.add_child(base)
	var front := FrontLayer.new()
	front.setup(0, age, p_race)
	vp.add_child(front)
	for b in [back, front]:
		b.cam_x = cam
		b.seam_x = cam + 6000.0
		b.time = anim_time
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
