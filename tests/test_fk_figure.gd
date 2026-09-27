extends TestCase
## FkFigure layering: parts drawn back to front by depth, in today's order wherever depths tie.


func _spec(weapon: String, shield := "", race := &"human", build := 1.0) -> Dictionary:
	return {"rig": "humanoid", "weapon": weapon, "shield": shield, "look": FkLooks.BODIES[race],
		"palette": FkLooks.PALETTES[race][2], "team": Color.RED, "build": build}


func test_standing_order_is_the_approved_order() -> void:
	# (Not the bow: its guard is the pre-draw, the drawing elbow already swung out toward the viewer; the
	# bow test below covers it.)
	for w in ["sword", "axe", "spear", "halberd", "musket", "javelin", "sling", "staff", "crew", "none", "no_such_weapon"]:
		for shield in ["", "round"]:
			for race in [&"human", &"dwarf", &"elf"]:
				check_eq(FkFigure.layers(_spec(w, shield, race), {"atk": -1.0}), FkFigure.PARTS, "%s %s %s" % [w, shield, race])


func test_marching_shield_wall_keeps_the_weapon_arm_on_top() -> void:
	for i in 16:
		var pose := {"walk": TAU * i / 16.0, "move": 1.0, "atk": -1.0}
		check_eq(FkFigure.layers(_spec("sword", "round"), pose), FkFigure.PARTS, "shield wall, walk phase %d" % i)
		check_eq(FkFigure.layers(_spec("none"), pose), FkFigure.PARTS, "plain walk, phase %d" % i)


func test_small_crew_and_riders_keep_the_order() -> void:
	check_eq(FkFigure.layers(_spec("crew"), {"atk": -1.0}, 0, 0.85), FkFigure.PARTS, "crew at 0.85")
	for w in ["saber", "lance"]:
		for atk in [-1.0, 0.34, 0.55]:
			check_eq(FkFigure.layers(_spec(w), {"atk": atk}, 0, 1.0, false), FkFigure.PARTS, "rider %s at %s" % [w, atk])


func test_bow_sits_under_the_drawing_arm_and_the_elbow_over_the_cap() -> void:
	var crossed := false
	for i in 102:
		var pose := {"atk": -1.0 if i == 101 else i / 100.0}
		var names := FkFigure.layers(_spec("bow"), pose)
		var bow := names.find("bow")
		check(bow < names.find("near upper arm") and bow < names.find("near forearm"), "bow under the drawing arm at atk %.2f" % (i / 100.0))
		var j := FkSkeleton.solve(1.0, "bow", pose, "", false, FkLooks.BODIES[&"human"])
		if j.z.elbow_n > j.z.sh_n + 1.0:
			crossed = true
			check(names.find("near upper arm") > names.find("shoulder cap"), "elbow toward the viewer: upper arm over the cap at atk %.2f" % (i / 100.0))
	check(crossed, "the drawing elbow swings toward the viewer during the draw")


func test_drawing_hand_never_hides_under_its_own_upper_arm() -> void:
	# Owner: "the elbow and hand disappear when the hand releases the string" — folded back along the
	# neck, the forearm and fist sat under the upper arm and vanished.
	for race in [&"human", &"elf", &"dwarf"]:
		for build in [0.94, 1.0]:
			for i in 102:
				var pose := {"atk": -1.0 if i == 101 else i / 100.0}
				var names := FkFigure.layers(_spec("bow", "", race, build), pose)
				check(names.find("near forearm") > names.find("near upper arm"), "%s %.2f: hand over its arm at atk %.2f" % [race, build, pose.atk])
			for m in 10:
				var walk := {"walk": 0.7, "move": m / 10.0, "atk": -1.0}
				var names := FkFigure.layers(_spec("bow", "", race, build), walk)
				check(names.find("near forearm") > names.find("near upper arm"), "%s %.2f: hand over its arm at move %.1f" % [race, build, m / 10.0])
