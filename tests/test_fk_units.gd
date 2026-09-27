extends TestCase
## Kit-level facts, independent of this game's unit data.


func test_height_scales_humanoids_by_race_body() -> void:
	var elf := {"rig": "humanoid", "look": FkLooks.BODIES[&"elf"]}
	check_near(FkUnits.height(elf), 66.0 * 1.1, 0.001)
	var dwarf_rider := {"rig": "mounted", "look": FkLooks.BODIES[&"dwarf"]}
	check_near(FkUnits.height(dwarf_rider), 82.0 + (0.76 - 1.0) * 40.0, 0.001)
	check_near(FkUnits.height({"rig": "golem"}), 90.0, 0.001, "non-humanoid rigs ignore the body")


func test_shot_muzzle_and_wreck() -> void:
	check_eq(FkUnits.shot({"rig": "humanoid", "weapon": "musket"}), "bullet")
	check_eq(FkUnits.shot({"rig": "humanoid", "weapon": "sword"}), "")
	check_eq(FkUnits.shot({"rig": "cannon"}), "ball")
	check_eq(FkUnits.shot({"rig": "humanoid", "weapon": "bow", "shot": "bolt"}), "bolt", "explicit shot wins")
	check_eq(FkUnits.muzzle({"rig": "cannon"}), Vector2(46, -34))
	check_eq(FkUnits.muzzle({"rig": "humanoid"}), Vector2(22, -34), "default muzzle")
	check_eq(FkUnits.wreck({"rig": "trebuchet"}), "siege")
	check_eq(FkUnits.wreck({"rig": "humanoid"}), "")


func test_swing_beats() -> void:
	check_near(FkUnits.swing(-1.0), 0.0, 1e-6, "idle")
	check_near(FkUnits.swing(0.35), -1.0, 1e-4, "full wind-up")
	check_near(FkUnits.swing(0.55), 1.0, 1e-4, "contact")


func test_kit_has_no_hidden_draw_state() -> void:
	var src := FileAccess.get_file_as_string("res://addons/figure_kit/units.gd")
	check(not src.contains("static var look"), "the race look is passed in the spec, not held in a static")
	var figure := FileAccess.get_file_as_string("res://addons/figure_kit/figure.gd")
	check(figure.contains("static func dress("), "crews inherit the parent's look through dress()")
