extends TestCase
## The sling: a whirl over the head that lets the stone go in the middle of the whip, and the shot leaving from the sling.

const B := 1.0
const KX := 0.9


func _pose(atk: float, hand := Vector2(10, -60)) -> Dictionary:
	return FkWeapons.sling_pose(atk, hand, hand.lerp(Vector2(25, -50), 0.5) + Vector2(0, 6), B, KX)


func test_the_slinger_lets_go_late_and_everyone_else_as_the_windup_ends() -> void:
	check_near(FkWeapons.release("sling"), 0.46, 1e-6)
	check_near(FkWeapons.release("bow"), FkWeapons.RELEASE_DEFAULT, 1e-6)
	check_near(FkUnits.release({"rig": "humanoid", "weapon": "sling"}), 0.46, 1e-6)
	check_near(FkUnits.release({"rig": "humanoid", "weapon": "musket"}), FkWeapons.RELEASE_DEFAULT, 1e-6)
	check_near(FkUnits.release({"rig": "cannon"}), FkWeapons.RELEASE_DEFAULT, 1e-6, "only a humanoid's hand weapon sets it")


func test_the_pouch_moves_smoothly_through_the_whole_attack() -> void:
	var prev: Vector2 = _pose(0.0).pouch
	for i in range(1, 401):
		var p: Vector2 = _pose(i / 400.0).pouch
		# Fastest at the release: 15 px of cord × ~35 rad per unit of attack, in 1/400 of it.
		check(p.distance_to(prev) < 3.0, "the pouch jumps %.1f px at atk %.3f" % [p.distance_to(prev), i / 400.0])
		prev = p


func test_the_sling_starts_and_ends_in_the_carried_pose() -> void:
	var hand := Vector2(10, -60)
	var carried := hand.lerp(Vector2(25, -50), 0.5) + Vector2(0, 6)
	check((_pose(0.0).pouch as Vector2).distance_to(carried) < 0.01, "the whirl starts from where the pouch hangs")
	check((_pose(1.0).pouch as Vector2).distance_to(carried) < 0.01, "and the sling settles back to it")
	check(_pose(0.2).loaded and not _pose(0.6).loaded, "the stone is in the pouch until the release")


func test_the_whirl_speeds_up_to_the_release_and_lets_go_going_forward_and_up() -> void:
	var prev := 0.0
	for i in range(1, 46):
		var sp: float = _pose(i / 100.0).speed
		check(sp >= prev - 1e-6, "the whirl slows at atk %.2f" % (i / 100.0))
		prev = sp
	var rel: float = FkWeapons.release("sling")
	var t0: Vector2 = _pose(rel - 0.001).pouch
	var t1: Vector2 = _pose(rel).pouch
	var v := t1 - t0
	check(v.x > 0.0 and v.y < 0.0, "the stone leaves going forward and up (%s)" % v)
	var sp: float = _pose(rel - 0.001).speed
	check(sp * 0.045 > 1.2, "a long blur at the release")
	check_near(wrapf(_pose(rel - 0.0001).theta - FkWeapons.SLING_LET_GO, -PI, PI), 0.0, 0.01, "let go at the set angle")


func test_the_shot_leaves_from_where_the_stone_was() -> void:
	for race in [&"human", &"dwarf"]:
		var look := RaceLook.look(race)
		var yaw := deg_to_rad(25.0)
		var spec := {"rig": "humanoid", "weapon": "sling", "build": 0.94, "look": look, "view": {"yaw": yaw}}
		var rel: float = FkWeapons.release("sling")
		var j := FkSkeleton.solve(0.94, "sling", {"walk": 0.0, "move": 0.0, "atk": rel, "t": 0.0}, "", false, look, {"yaw": yaw})
		var hand: Vector2 = j.hand_n
		var stone: Vector2 = FkWeapons.sling_pose(rel, hand, hand, 0.94, cos(yaw)).pouch
		check((FkUnits.muzzle(spec) as Vector2).distance_to(stone) < 0.01, "%s: the muzzle is the stone at the release" % race)
	var human: Vector2 = FkUnits.muzzle({"rig": "humanoid", "weapon": "sling", "build": 0.94, "look": RaceLook.look(&"human"), "view": {"yaw": 0.4}})
	var dwarf: Vector2 = FkUnits.muzzle({"rig": "humanoid", "weapon": "sling", "build": 0.94, "look": RaceLook.look(&"dwarf"), "view": {"yaw": 0.4}})
	check(dwarf.y > human.y + 3.0, "a shorter slinger lets go lower (%s, %s)" % [dwarf, human])
