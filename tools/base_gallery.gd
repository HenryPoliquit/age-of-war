extends SceneTree
## Renders every base (rows = races, columns = ages) with its age's turrets mounted, for art review.
## Needs a display (use Xvfb in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/base_gallery.gd -- --out=reports/base_gallery.png

var out := "reports/base_gallery.png"
var night := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--night="):
			night = float(a.get_slice("=", 1))
	var bg := ColorRect.new()
	bg.color = Color("9aa4a8")
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var n := Node2D.new()
	n.draw.connect(_draw.bind(n))
	root.add_child(n)
	_capture.call_deferred()


func _draw(n: Node2D) -> void:
	var gd := GameData.get_default()
	var f := UiStyle.font("bold")
	BaseArt.night = night
	for r in RaceLook.IDS.size():
		var race: StringName = RaceLook.IDS[r]
		for age in range(1, 7):
			var gate := Vector2(40 + age * 312 - 20, 330 + r * 350)
			n.draw_rect(Rect2(gate.x - 312, gate.y, 312, 12), Color("5a4a3a"))
			UnitArt.begin(n, Transform2D(0.0, Vector2(0.62, 0.62), 0.0, gate))
			BaseArt.draw_base(n, age, MatchView.TEAM[0], 1.0, 0.7, 1.0, 5, null, race)
			var turrets: Array = gd.age(age).turrets
			for i in 5:
				var def: TurretDef = turrets[i % turrets.size()]
				UnitArt.begin(n, Transform2D(0.0, Vector2(0.62, 0.62), 0.0, gate) * Transform2D(0.0, BaseArt.slot_pos(i)))
				BaseArt.draw_turret(n, def, MatchView.TEAM[0], -0.2, 0.0, 0.7, false, race)
			n.draw_set_transform(Vector2.ZERO)
			n.draw_string(f, gate + Vector2(-300, 34), "%s · %s" % [gd.race(race).display_name, gd.age(age).display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.1))


func _capture() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("gallery saved: ", out)
	quit()
