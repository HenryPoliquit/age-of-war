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


func test_depth_per_rig() -> void:
	# Half-depth of the body (centre to front edge, weapon excluded), measured from the renders: the view
	# draws each unit this far back toward its own base, so opposing bodies stand apart while the sim
	# measures centre to centre.
	check_near(FkUnits.depth({"rig": "humanoid"}), 10.0, 1e-4, "foot")
	check_near(FkUnits.depth({"rig": "humanoid", "shield": "kite"}), 18.0, 1e-4, "shield bearer")
	var measured := {"mounted": 50.0, "chariot": 50.0, "ram": 45.0, "catapult": 34.0, "trebuchet": 34.0, "cannon": 48.0,
		"steamtank": 43.0, "golem": 33.0, "treant": 30.0, "skycannon": 50.0, "ballista": 46.0, "obelisk": 36.0}
	for rig in measured:
		check_near(FkUnits.depth({"rig": rig}), measured[rig], 1e-4, rig)


func test_giant_contact_fires_just_after_landing() -> void:
	# A giant's foot lands at stride phase PI/2; the crush, shockwave and dust play out right after.
	check_eq(FkMachines.giant_contact(PI / 2 - 0.1), -1.0, "not before landing")
	var u := FkMachines.giant_contact(PI / 2 + 0.1)
	check(u > 0.0 and u < 0.2, "starts on landing")
	check_eq(FkMachines.giant_contact(PI / 2 + 2.0), -1.0, "over while the foot is planted")


func test_giants_are_right_handed_from_both_sides() -> void:
	# Owner: "mine use the right hand to attack but enemies use the left" — a mirrored giant is the same
	# right-handed body turned around: its right (attacking) arm and leg go behind, its left ones in front.
	var ours := FkMachines.giant_order({})
	check_eq(ours, ["left leg", "right leg", "left arm", "body", "right arm"], "ours: left side far, right side near")
	var theirs := FkMachines.giant_order({"mirrored": true})
	check_eq(theirs, ["right leg", "left leg", "right arm", "body", "left arm"], "theirs: turned around")


func test_rider_bob_matches_the_beast() -> void:
	# The rider's spine absorbs the beast's real bob, so the head stays level.
	for w in [0.3, 1.1, 2.4]:
		var pose := {"walk": w, "move": 1.0, "t": 0.0}
		var j := FkQuadruped.solve(FkMounts.BEASTS["horse"], pose)
		var p := FkMounts.rider_pose(j, pose)
		check_near(p.ride_bob, j.bob, 1e-5, "walk %.1f" % w)
		check_eq(p.move, 0.0, "the rider doesn't walk")


func test_chariot_wheel_rolls_without_slipping() -> void:
	var a := FkMounts.chariot_joints({"walk": 0.0})
	check_near(a.bottom.y, 0.0, 1e-4, "wheel on the ground")
	check_near(a.center.y, -FkMounts.WHEEL_R, 1e-4, "axle one radius up")
	check_near(a.top.y, -2.0 * FkMounts.WHEEL_R, 1e-4, "top of the wheel")
	var b := FkMounts.chariot_joints({"walk": 1.0, "move": 1.0})
	check_near(b.angle - a.angle, FkMounts.CHARIOT_PACE / FkMounts.WHEEL_R, 1e-4, "turns by ground covered / radius")
	check_near(FkMounts.chariot_joints({"walk": 1.0, "move": 0.0}).angle, b.angle, 1e-6, "the spin depends only on distance travelled")


func test_chariot_wheel_rolls_without_slipping_seen_from_the_game_camera() -> void:
	# A wheel is a disc in the vertical plane: from a turned camera it is squeezed by cos(yaw), so it must spin
	# that much more per px for its rim to keep pace with the ground on the screen.
	var view := {"yaw": 0.4363}
	var a := FkMounts.chariot_joints({"walk": 0.0}, view)
	var b := FkMounts.chariot_joints({"walk": 1.0, "move": 1.0}, view)
	var on_screen: float = (b.angle - a.angle) * FkMounts.WHEEL_R * cos(0.4363)
	check_near(on_screen, FkMounts.CHARIOT_PACE, 1e-3, "the rim's speed on the screen is the ground's")


func test_chariot_driver_stands_on_the_floor_inside_the_car() -> void:
	var cj := FkMounts.chariot_joints({"atk": -1.0})
	check_eq(cj.driver, Vector2(FkMounts.DRIVER_X, cj.floor), "feet on the car floor")
	check(cj.floor > cj.center.y - 5.0 and cj.floor < 0.0, "floor at axle height")
	var order: Array = FkMounts.CHARIOT_ORDER
	check(order.find("driver") < order.find("car front") and order.find("car front") < order.find("near wheel"),
		"the near panel covers the driver's legs, the near wheel over the panel")
	check(order.find("far wheel") < order.find("car back") and order.find("car back") < order.find("driver"), "the far side is behind the driver")


func test_chariot_planes_spread_with_the_camera() -> void:
	var flat := FkMounts._plane({}, FkMounts.WHEEL_Z)
	var turned := FkMounts._plane({"yaw": 0.4363}, FkMounts.WHEEL_Z)
	check_eq(flat, Transform2D.IDENTITY.translated(Vector2.ZERO), "square-on, a plane is the picture itself")
	var near_x: float = (turned * Vector2(0, 0)).x
	var far_x: float = (FkMounts._plane({"yaw": 0.4363}, -FkMounts.WHEEL_Z) * Vector2(0, 0)).x
	check_near(far_x - near_x, 2.0 * FkMounts.WHEEL_Z * sin(0.4363), 1e-4, "the far wheel stands further forward on the screen than the near one")
	check_near(turned.x.x, cos(0.4363), 1e-5, "a plane is squeezed by cos(yaw)")
