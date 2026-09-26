extends SceneTree
## Renders every unit (rows = ages, columns = roles) three ways — colour, greyscale and flat black
## silhouette — for the PRD §11 check "role identifiable by shape alone, in greyscale".
## Needs a display (use Xvfb in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/unit_gallery.gd -- --out=reports/unit_gallery.png

const MODE_SHADER := preload("res://shaders/gallery_mode.gdshader")
const ROLES := ["vanguard", "ranged", "heavy", "siege"]

var out := "reports/unit_gallery.png"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var bg := ColorRect.new()
	bg.color = Color("c9c3b4")
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	for mode in 3:
		var n := Node2D.new()
		n.position = Vector2(mode * 640, 0)
		var m := ShaderMaterial.new()
		m.shader = MODE_SHADER
		m.set_shader_parameter("mode", mode)
		n.material = m
		n.draw.connect(_draw_panel.bind(n, mode))
		root.add_child(n)
	_capture.call_deferred()


func _draw_panel(n: Node2D, mode: int) -> void:
	var gd := GameData.get_default()
	var f := ThemeDB.fallback_font
	n.draw_string(f, Vector2(10, 28), ["Colour", "Greyscale", "Silhouette"][mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.1, 0.1, 0.1))
	for c in ROLES.size():
		n.draw_string(f, Vector2(24 + c * 152, 58), ROLES[c].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(0.2, 0.2, 0.2))
	for age in range(1, 7):
		for c in ROLES.size():
			var def := gd.unit_for_role(age, ROLES[c])
			if def == null:
				continue
			var base := Vector2(94 + c * 152, 56 + age * 160)
			UnitArt.begin(n, Transform2D(0.0, Vector2(1.15, 1.15), 0.0, base))
			UnitArt.draw_unit(n, def, MatchView.TEAM[0], {"walk": 0.6, "move": 0.0, "atk": -1.0, "t": 0.3, "flash": 0.0}, age * 4 + c)
			n.draw_set_transform(Vector2.ZERO)
			if mode == 0:
				n.draw_string(f, base + Vector2(-70, 20), def.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(0.15, 0.15, 0.15))


func _capture() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("gallery saved: ", out)
	quit()
