extends TestCase
## FkFigure layering: parts drawn back to front by depth, in today's order wherever depths tie.


func _spec(weapon: String, shield := "", race := &"human", build := 1.0, view := {}) -> Dictionary:
	return {"rig": "humanoid", "weapon": weapon, "shield": shield, "look": FkLooks.BODIES[race],
		"palette": FkLooks.PALETTES[race][2], "team": Color.RED, "build": build, "view": view}


## The near arm's parts: they sort by depth, so an elbow swung out toward the viewer puts the upper arm and forearm
## over the shoulder cap and the weapon. Everything else keeps its approved place.
const ARM_PARTS := ["near upper arm", "near forearm", "shoulder cap", "weapon"]


func _without_arm(names: Array) -> Array:
	return names.filter(func(n: String) -> bool: return n not in ARM_PARTS)


## The approved order exactly while the near arm stays in its plane; while it swings out, the body's order
## (everything but the arm's parts) is still the approved one.
func _check_order(names: Array, spec: Dictionary, pose: Dictionary, tag: String, scale := 1.0, legs := true) -> void:
	var j := FkSkeleton.solve(spec.build * scale, spec.weapon, pose, spec.shield, not legs, spec.look, spec.view)
	var planar: bool = absf(j.z.elbow_n - j.z.sh_n) < 0.75 and absf(j.z.hand_n - j.z.sh_n) < 0.75
	if planar:
		check_eq(names, FkFigure.PARTS, tag + " (arm in its plane)")
	else:
		check_eq(_without_arm(names), _without_arm(FkFigure.PARTS), tag + " (arm swung out: the body's order)")


func test_standing_order_is_the_approved_order() -> void:
	# (Not the bow: its guard is the pre-draw, the drawing elbow already swung out toward the viewer; the
	# bow test below covers it.)
	for w in ["sword", "axe", "spear", "halberd", "musket", "javelin", "sling", "staff", "crew", "none", "no_such_weapon"]:
		for shield in ["", "round"]:
			for race in [&"human", &"dwarf", &"elf"]:
				_check_order(FkFigure.layers(_spec(w, shield, race), {"atk": -1.0}), _spec(w, shield, race), {"atk": -1.0}, "%s %s %s" % [w, shield, race])


func test_marching_shield_wall_keeps_the_weapon_arm_on_top() -> void:
	for i in 16:
		var pose := {"walk": TAU * i / 16.0, "move": 1.0, "atk": -1.0}
		check_eq(FkFigure.layers(_spec("sword", "round"), pose), FkFigure.PARTS, "shield wall, walk phase %d" % i)
		_check_order(FkFigure.layers(_spec("none"), pose), _spec("none"), pose, "plain walk, phase %d" % i)


func test_small_crew_and_riders_keep_the_order() -> void:
	_check_order(FkFigure.layers(_spec("crew"), {"atk": -1.0}, 0, 0.85), _spec("crew"), {"atk": -1.0}, "crew at 0.85", 0.85)
	for w in ["saber", "lance"]:
		for atk in [-1.0, 0.34, 0.55]:
			_check_order(FkFigure.layers(_spec(w), {"atk": atk}, 0, 1.0, false), _spec(w), {"atk": atk}, "rider %s at %s" % [w, atk], 1.0, false)


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


# --- The enemy army: the same right-handed body seen from its other side (owner, 2026-09-27) ----

func _before(names: Array, a: String, c: String) -> bool:
	return names.find(a) < names.find(c)


func test_mirrored_figure_is_turned_around_not_left_handed() -> void:
	for race in [&"human", &"dwarf", &"elf"]:
		for pose in [{"atk": -1.0}, {"walk": 1.3, "move": 1.0, "atk": -1.0}, {"atk": 0.34}, {"atk": 0.5}]:
			var tag := "%s %s" % [race, pose]
			var names := FkFigure.layers(_spec("sword", "round", race), pose.merged({"mirrored": true}))
			check(_before(names, "near upper arm", "torso") and _before(names, "near forearm", "torso"), tag + ": weapon arm behind the body")
			check(_before(names, "weapon", "torso"), tag + ": weapon held on the far side")
			check(_before(names, "head", "shield") and _before(names, "torso", "far arm"), tag + ": shield arm and shield in front")
			check(_before(names, "near leg", "far leg"), tag + ": the left leg is the near one")
			# Our own army is unchanged.
			if pose.atk < 0.0 and not pose.has("move"):
				_check_order(FkFigure.layers(_spec("sword", "round", race), pose), _spec("sword", "round", race), pose, tag)


func test_mirrored_archer_holds_the_bow_in_front_and_draws_behind_the_head() -> void:
	for atk in [-1.0, 0.2, 0.34, 0.5]:
		var names := FkFigure.layers(_spec("bow"), {"atk": atk, "mirrored": true})
		check(_before(names, "head", "bow") and _before(names, "bow", "far arm"), "bow in the near hand, over the face (atk %s)" % atk)
		check(_before(names, "near upper arm", "torso"), "drawing arm on the far side (atk %s)" % atk)


func test_mirrored_rider_shows_its_left_leg() -> void:
	var names := FkFigure.layers(_spec("saber"), {"atk": -1.0, "mirrored": true}, 0, 1.0, false)
	check(_before(names, "near upper arm", "torso"), "sabre arm on the far side of the rider")


func test_marching_archer_carries_the_bow_on_the_far_side() -> void:
	# Owner: the bow is in the other (far) hand, so on the march it is behind the body.
	for i in 8:
		var walk := {"walk": TAU * i / 8.0, "move": 1.0, "atk": -1.0}
		var names := FkFigure.layers(_spec("bow"), walk)
		check(_before(names, "bow", "torso"), "bow behind the body, walk phase %d" % i)
		check(_before(names, "bow", "far leg") and _before(names, "bow", "near leg"), "held beside the outside of the left leg, walk phase %d" % i)
		names = FkFigure.layers(_spec("bow"), walk.merged({"mirrored": true}))
		check(_before(names, "torso", "bow"), "turned around, the bow hand is the near one, walk phase %d" % i)
	for atk in [-1.0, 0.34]:
		check(_before(FkFigure.layers(_spec("bow"), {"atk": atk}), "head", "bow"), "standing to shoot, the bow is in front (atk %s)" % atk)


func test_turning_the_camera_keeps_the_approved_layering() -> void:
	# The order comes from which side of the body a part is on, so the camera can't reorder it.
	for yaw in [0.2618, 0.4363, -0.2618]:
		var view := {"yaw": yaw}
		for w in ["sword", "axe", "spear", "halberd", "musket", "javelin", "sling", "staff", "none"]:
			for shield in ["", "round"]:
				for pose in [{"atk": -1.0}, {"walk": 1.0, "move": 1.0, "atk": -1.0}, {"atk": 0.3}, {"atk": 0.5}, {"atk": 0.8}]:
					check_eq(FkFigure.layers(_spec(w, shield, &"human", 1.0, view), pose), FkFigure.layers(_spec(w, shield), pose), "%s %s yaw %.2f %s" % [w, shield, yaw, pose])
		for i in 102:
			var pose := {"atk": -1.0 if i == 101 else i / 100.0}
			check_eq(FkFigure.layers(_spec("bow", "", &"human", 1.0, view), pose), FkFigure.layers(_spec("bow"), pose), "bow yaw %.2f atk %.2f" % [yaw, pose.atk])


func test_a_swung_out_elbow_puts_the_arm_over_the_cap() -> void:
	# The coiled guard of a sword and shield: the elbow stands out toward the viewer, so the upper arm sorts over the cap.
	var names := FkFigure.layers(_spec("sword", "round"), {"atk": -1.0})
	check(names.find("near upper arm") > names.find("shoulder cap") and names.find("near forearm") > names.find("near upper arm"), "upper arm over the cap, hand over its arm")
	check(names.find("near forearm") > names.find("weapon"), "the hand wraps the grip: the forearm over the weapon")


func test_the_arm_order_does_not_flicker_through_a_swing() -> void:
	# The arm's parts change places only where their depths really cross, a handful of times over a whole attack.
	for spec in [["sword", ""], ["sword", "round"], ["axe", ""], ["spear", ""], ["bow", ""], ["staff", ""]]:
		var flips := 0
		var prev := []
		for i in 201:
			var names := FkFigure.layers(_spec(spec[0], spec[1], &"human", 1.0, {"yaw": 0.4363}), {"atk": i / 200.0})
			if not prev.is_empty() and names != prev:
				flips += 1
			prev = names
		check(flips <= 6, "%s %s: the order changed %d times" % [spec[0], spec[1], flips])


func test_a_two_handed_weapon_stays_over_the_head_and_body() -> void:
	# The grip is on the centreline, but the weapon still sorts at its shoulder's depth: over the face and chest.
	for w in ["spear", "halberd", "staff"]:
		for atk in [-1.0, 0.2, 0.5, 0.8]:
			var names := FkFigure.layers(_spec(w), {"atk": atk})
			check(names.find("weapon") > names.find("head") and names.find("weapon") > names.find("torso"), "%s over head and torso at atk %.1f" % [w, atk])
