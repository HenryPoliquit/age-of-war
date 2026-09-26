extends SceneTree
## Renders every base (rows = races, columns = ages) with its age's turret towers in front, for art review.
## Needs a display (use Xvfb in the cloud):
##   xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/base_gallery.gd -- --out=reports/base_gallery.png

var out := "reports/base_gallery.png"
var night := 0.0
## --towers: close-up of every race × age turret tower instead of the bases.
var towers := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a == "--towers":
			towers = true
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
	if towers:
		_draw_towers(n, gd, f)
		return
	for r in RaceLook.IDS.size():
		var race: StringName = RaceLook.IDS[r]
		for age in range(1, 7):
			var col_x := (age - 1) * 320.0
			var gate := Vector2(col_x + 150, 330 + r * 350)
			var k := 0.5
			n.draw_rect(Rect2(col_x, gate.y, 320, 12), Color("5a4a3a"))
			var xf := Transform2D(0.0, Vector2(k, k), 0.0, gate)
			UnitArt.begin(n, xf)
			BaseArt.draw_base(n, age, MatchView.TEAM[0], 1.0, 0.7, 1.0, null, race)
			# Five towers: this age's sentry, artillery and support, then two empty pads.
			var turrets: Array = gd.age(age).turrets
			for row in [1, 0]:
				for i in 5:
					if i % 2 != row:
						continue
					var foot := BaseArt.slot_pos(i)
					UnitArt.begin(n, xf * Transform2D(0.0, Vector2.ONE * BaseArt.TOWER_SCALE, 0.0, foot))
					if i >= turrets.size():
						BaseArt.draw_pad(n, race)
						continue
					BaseArt.draw_tower(n, race, age, MatchView.TEAM[0], 0.7)
					UnitArt.begin(n, xf * Transform2D(0.0, BaseArt.mount_pos(i, race, age)))
					BaseArt.draw_turret(n, turrets[i], MatchView.TEAM[0], -0.2, 0.0, 0.7, false, race)
			n.draw_set_transform(Vector2.ZERO)
			n.draw_string(f, Vector2(col_x + 10, gate.y + 34), "%s · %s" % [gd.race(race).display_name, gd.age(age).display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.1))

func _draw_towers(n: Node2D, gd: GameData, f: Font) -> void:
	var sentries := {}
	for age in range(1, 7):
		for td in gd.age(age).turrets:
			if td.kind == "sentry":
				sentries[age] = td
	for r in RaceLook.IDS.size():
		var race: StringName = RaceLook.IDS[r]
		for age in range(1, 7):
			var foot := Vector2(160 + (age - 1) * 320, 320 + r * 350)
			n.draw_rect(Rect2(foot.x - 150, foot.y, 300, 10), Color("5a4a3a"))
			var k := 2.6
			var xf := Transform2D(0.0, Vector2(k, k), 0.0, foot)
			UnitArt.begin(n, xf)
			BaseArt.draw_tower(n, race, age, MatchView.TEAM[0], 0.7)
			UnitArt.begin(n, xf * Transform2D(0.0, Vector2(0, -BaseArt.tower_height(race, age))))
			BaseArt.draw_turret(n, sentries[age], MatchView.TEAM[0], -0.2, 0.0, 0.7, false, race)
			n.draw_set_transform(Vector2.ZERO)
			n.draw_string(f, foot + Vector2(-140, 30), "%s · %s" % [gd.race(race).display_name, gd.age(age).display_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.1, 0.1, 0.1))


func _capture() -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("gallery saved: ", out)
	quit()
