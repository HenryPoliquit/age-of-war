class_name TestCase
extends RefCounted
## Minimal test base: subclasses define `test_*` methods; tests/run_tests.gd discovers and runs them.

var failures: Array[String] = []
var _current := ""


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s: %s" % [_current, msg])


func check_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s %s" % [_current, str(expected), str(actual), msg])


func check_near(actual: float, expected: float, tol: float, msg: String = "") -> void:
	if absf(actual - expected) > tol:
		failures.append("%s: expected %.4f ± %.4f, got %.4f %s" % [_current, expected, tol, actual, msg])


## A fresh match with no AI; 999 gold/XP so commands aren't blocked by cost unless a test wants that.
func new_sim(rich := true) -> MatchSim:
	var sim := MatchSim.new(GameData.get_default(), 1)
	if rich:
		for s in sim.sides:
			s.gold = 99999.0
			s.xp = 99999.0
	return sim


func run_for(sim: MatchSim, seconds: float) -> void:
	var n := roundi(seconds / sim.rules.tick_dt)
	for i in n:
		sim.step()


## Places a unit directly on the lane at `progress` (bypasses the queue).
func place(sim: MatchSim, side: int, role: String, progress: float, age := 1) -> SimUnit:
	var def := sim.data.unit_for_role(age, role)
	var u := sim._spawn(sim.sides[side], def, def.cost)
	u.progress = progress
	return u
