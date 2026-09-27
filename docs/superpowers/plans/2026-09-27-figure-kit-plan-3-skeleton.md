# Figure Kit — Plan 3: Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every human figure (foot soldier, rider, chariot driver, siege crew) is posed from one skeleton, and the owner reviews it one role at a time. The skeleton has fixed bone lengths, knees that bend forward, elbows that bend down and back, feet and head facing the enemy, a body that leans and lunges into strikes, and weapons whose blades face the way they swing.

**Architecture:**
- **`FkSkeleton`** (new, pure math, headless-tested) solves joints: two-bone IK plus stance keyframes per weapon family, blended by the existing `FkUnits.swing(atk)` beats.
- **`FkFigure.humanoid`** draws legs, torso, head and both arms from those joints.
- **`FkWeapons.weapon`** only draws the weapon, attached to the solved hand and angle. It no longer places hands or draws arms.
- **Riders** get a seated leg. **Crews** use the `crew` stance.
- **Review:** a sheet tool renders each role across ages in walk, wind-up, strike and recover frames for the owner.

**Tech Stack:** Godot 4.7-stable, GDScript; everything under `addons/figure_kit/` (Fk* classes).

**Spec:** `docs/superpowers/specs/2026-09-27-unit-skeleton-design.md` (§1 Skeleton, §2 Renderer, §4 Review tooling, §5 Testing). Builds on Plan 1's kit and Plan 2's view-only spacing, which shift units by `FkUnits.depth`; that needs no change here.

## Global Constraints

- **Kit boundary:** no game class names under `addons/figure_kit/`, enforced by `tests/test_fk_boundary.gd`.
- **Bone lengths** (× `build`):

  | Bone | Length |
  |---|---|
  | thigh | 15 |
  | shin | 14 |
  | upper arm | 9 |
  | forearm | 8.5 |
  | spine (hip → shoulder line) | 20 |

  The hip sits `HIP_Y = 28` above the feet, so standing knees are slightly bent.
- **Invariants:**
  - knees bend forward (+x) and elbows bend down/back;
  - boots always point +x and the face always looks +x;
  - bone lengths never change between frames.
- **Timing:** keyframes blend by `s = FkUnits.swing(atk)`. For s < 0 the pose moves guard → wind; for s > 0, guard → hit. Contact stays at `atk` 0.35–0.55, so the sim's damage tick still matches the hit frame.
- **Sim and data are untouched.** This is presentation only.
- **Race proportions:** they still scale legs and torso about the feet (or about the hip for riders). Head and arms keep their own proportions.
- **Visual change is intended**, so goldens are no longer the gate. The gates are the tests and **owner approval of each role sheet**. Each role batch ends at an owner checkpoint, and execution stops there until the owner answers.
- **Godot (local):** `G="../Godot_v4.7/Godot_v4.7-stable_win64_console.exe"`, always under `timeout`. After `--import`, revert `.import` line-ending churn with `git checkout -- assets/fonts/*.import reports/*.import`.

## Review Focus

1. **Out-of-reach hand targets** (thrust hit, bow draw), especially for short dwarves with `body` 1.24×0.76. Expected: the arm straightens toward the target and the weapon stays attached to the hand; it never floats.
2. **`move` blending mid-attack.** A unit walks with `move` fading while `atk` starts. Expected: legs blend from stride to lunge without a knee snapping to the other side.
3. **Riders and crews** (`legs=false`, the crew scale 0.85, chariot drivers). Expected: the seated leg's foot sits in the stirrup below the saddle; crews still grip their engine.
4. **Mirrored units (team 2).** They are drawn with x-scale −1, so "forward" must still mean toward the enemy. The kit only works in local space, so this holds by construction. Covered by the in-game screenshot check.
5. **Unknown weapon kinds** (a spec with `weapon: "none"` or a typo). Expected: arms hang in the idle stance, no weapon, no script error.

---

### Task 1: `FkSkeleton` math (IK and reach)

**Files:**
- Create: `addons/figure_kit/skeleton.gd`
- Test: `tests/test_fk_skeleton.gd`

**Interfaces:**
- Produces:
  - `FkSkeleton.ik(root: Vector2, target: Vector2, l1: float, l2: float, side: Vector2) -> Vector2` returns the middle joint;
  - `FkSkeleton.reach(root: Vector2, target: Vector2, l1: float, l2: float) -> Vector2` returns the reachable end;
  - consts `THIGH`, `SHIN`, `UPPER`, `FORE`, `SPINE`, `HIP_Y`.

- [ ] **Step 1: Write the failing tests** `tests/test_fk_skeleton.gd`:
  ```gdscript
  extends TestCase
  ## FkSkeleton: fixed bones, IK bend sides, and the per-frame joint invariants the owner asked for.


  func test_ik_keeps_bone_lengths() -> void:
  	var root := Vector2(0, -28)
  	for target in [Vector2(0, 0), Vector2(10, -2), Vector2(-12, 0), Vector2(3, -20), Vector2(40, 0)]:
  		var end := FkSkeleton.reach(root, target, 15.0, 14.0)
  		var j := FkSkeleton.ik(root, end, 15.0, 14.0, Vector2.RIGHT)
  		check_near(root.distance_to(j), 15.0, 0.02, "thigh for %s" % target)
  		check_near(j.distance_to(end), 14.0, 0.02, "shin for %s" % target)


  func test_ik_bend_sides() -> void:
  	var knee := FkSkeleton.ik(Vector2(0, -28), Vector2(0, 0), 15.0, 14.0, Vector2.RIGHT)
  	check(knee.x > 0.0, "knee bends forward")
  	var elbow := FkSkeleton.ik(Vector2(0, 0), Vector2(14, 0), 9.0, 8.5, Vector2(-0.3, 1.0))
  	check(elbow.y > 0.0, "elbow bends down")


  func test_reach_clamps_far_targets() -> void:
  	var end := FkSkeleton.reach(Vector2.ZERO, Vector2(100, 0), 9.0, 8.5)
  	check(end.x < 17.5 and end.x > 17.4, "clamped to full extension")
  	check_eq(FkSkeleton.reach(Vector2.ZERO, Vector2(5, 5), 9.0, 8.5), Vector2(5, 5), "reachable target unchanged")
  ```

- [ ] **Step 2: Run the tests.** Expected: `test_fk_skeleton.gd does not compile` (`FkSkeleton` is not declared).

- [ ] **Step 3: Create `addons/figure_kit/skeleton.gd`:**
  ```gdscript
  class_name FkSkeleton
  extends RefCounted
  ## Joint math for the human figure: fixed bone lengths, two-bone IK and stance keyframes.
  ## Local space: feet at y = 0, facing +x, up is −y. Lengths are multiplied by the figure's build.

  const THIGH := 15.0
  const SHIN := 14.0
  const UPPER := 9.0
  const FORE := 8.5
  ## Hip to shoulder line.
  const SPINE := 20.0
  ## Standing hip height: a little under THIGH + SHIN so knees are soft.
  const HIP_Y := 28.0


  ## Middle joint (knee, elbow) of a two-bone limb from `root` to `target`. Of the two solutions it
  ## takes the one lying toward `side`. Call with a reachable target (see reach()).
  static func ik(root: Vector2, target: Vector2, l1: float, l2: float, side: Vector2) -> Vector2:
  	var v := target - root
  	var d := clampf(v.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
  	var dir := v.normalized() if v.length() > 1e-4 else Vector2.DOWN
  	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
  	var j1 := root + dir.rotated(a) * l1
  	var j2 := root + dir.rotated(-a) * l1
  	return j1 if (j1 - root).dot(side) >= (j2 - root).dot(side) else j2


  ## Where the limb's end actually gets to: `target` if reachable, else full extension toward it.
  static func reach(root: Vector2, target: Vector2, l1: float, l2: float) -> Vector2:
  	var v := target - root
  	var m := l1 + l2 - 0.01
  	return target if v.length() <= m else root + v.normalized() * m
  ```

- [ ] **Step 4: Import and run the tests.** Expected: `N tests, 0 failures`, with the 3 new tests passing and the boundary test still green.

- [ ] **Step 5: Commit** `figure kit: FkSkeleton two-bone IK`.

---

### Task 2: Stances and `FkSkeleton.solve`

**Files:**
- Modify: `addons/figure_kit/skeleton.gd`
- Test: `tests/test_fk_skeleton.gd`

**Interfaces:**
- Consumes: `FkUnits.swing(atk)`.
- Produces:
  - `FkSkeleton.STANCES: Dictionary` (family → keyframes) and `FkSkeleton.FAMILY: Dictionary` (weapon kind → family; missing = `"idle"`);
  - `FkSkeleton.solve(b: float, weapon: String, pose: Dictionary, shield := false, seated := false) -> Dictionary`, which returns Vector2 joints `hip`, `sh`, `sh_n`, `sh_f`, `elbow_n`, `hand_n`, `elbow_f`, `hand_f`, `knee_n`, `foot_n`, `knee_f`, `foot_f`, plus `dir` (the weapon's unit Vector2), `lean` and `lunge` (floats).
  - Keyframe positions are relative to `sh`, in build-scaled px.

- [ ] **Step 1: Write the failing tests.** Append:
  ```gdscript
  const FRAMES := [[0.0, 1.0, -1.0], [1.6, 1.0, -1.0], [3.1, 1.0, -1.0], [4.7, 1.0, -1.0],
  	[0.6, 0.0, -1.0], [0.6, 0.0, 0.2], [0.6, 0.0, 0.34], [0.6, 0.0, 0.45], [0.6, 0.0, 0.75], [2.0, 0.5, 0.4]]


  func _each_frame(weapon: String, fn: Callable, shield := false, seated := false) -> void:
  	for f in FRAMES:
  		fn.call(FkSkeleton.solve(1.16, weapon, {"walk": f[0], "move": f[1], "atk": f[2]}, shield, seated), f)


  func test_bones_never_stretch() -> void:
  	var b := 1.16
  	for w in ["sword", "axe", "spear", "halberd", "musket", "crossbow", "bow", "javelin", "sling", "staff", "crew", "none"]:
  		_each_frame(w, func(j: Dictionary, f: Array) -> void:
  			var tag := "%s %s" % [w, f]
  			check_near(j.hip.distance_to(j.knee_n), FkSkeleton.THIGH * b, 0.05, tag + " near thigh")
  			check_near(j.knee_n.distance_to(j.foot_n), FkSkeleton.SHIN * b, 0.05, tag + " near shin")
  			check_near(j.hip.distance_to(j.knee_f), FkSkeleton.THIGH * b, 0.05, tag + " far thigh")
  			check_near(j.sh_n.distance_to(j.elbow_n), FkSkeleton.UPPER * b, 0.05, tag + " upper arm")
  			check_near(j.elbow_n.distance_to(j.hand_n), FkSkeleton.FORE * b, 0.05, tag + " forearm")
  			check_near(j.sh_f.distance_to(j.elbow_f), FkSkeleton.UPPER * b, 0.05, tag + " far upper arm")
  			check_near(j.elbow_f.distance_to(j.hand_f), FkSkeleton.FORE * b, 0.05, tag + " far forearm"))


  func test_knees_forward_elbows_down_feet_grounded() -> void:
  	for w in ["sword", "spear", "musket", "bow", "none"]:
  		_each_frame(w, func(j: Dictionary, f: Array) -> void:
  			var tag := "%s %s" % [w, f]
  			# The knee lies forward (+x) of the hip→foot midpoint.
  			check(j.knee_n.x >= j.hip.lerp(j.foot_n, 0.5).x - 0.01, tag + " near knee forward")
  			check(j.knee_f.x >= j.hip.lerp(j.foot_f, 0.5).x - 0.01, tag + " far knee forward")
  			# The elbow lies on the down/back side of the shoulder→hand line (behind it when the arm is raised).
  			var d: Vector2 = j.hand_n - j.sh_n
  			var nrm := d.orthogonal() if d.orthogonal().dot(Vector2(-0.3, 1.0)) >= 0.0 else -d.orthogonal()
  			check((j.elbow_n - j.sh_n.lerp(j.hand_n, 0.5)).dot(nrm) >= -0.01, tag + " elbow bends down/back")
  			check(j.foot_n.y <= 0.01 and j.foot_f.y <= 0.01, tag + " feet not below ground")
  			check(j.foot_n.y >= -7.0 and j.foot_f.y >= -7.0, tag + " feet lift at most 7 px"))


  func test_strike_reaches_ahead_of_guard() -> void:
  	for w in ["sword", "axe", "spear"]:
  		var guard := FkSkeleton.solve(1.0, w, {"atk": -1.0})
  		var hit := FkSkeleton.solve(1.0, w, {"atk": 0.5})
  		check(hit.hand_n.x > guard.hand_n.x, "%s: strike hand ahead of guard" % w)
  		check(hit.lean > 0.0, "%s: leans into the strike" % w)


  func test_wind_up_is_overhead_for_chops() -> void:
  	var wind := FkSkeleton.solve(1.0, "axe", {"atk": 0.34})
  	check(wind.hand_n.y < wind.sh.y - 8.0, "hand above the shoulder at full wind-up")


  func test_seated_foot_hangs_forward_below_hip() -> void:
  	var j := FkSkeleton.solve(1.0, "lance", {"atk": -1.0}, false, true)
  	check(j.foot_n.x > j.hip.x and j.foot_n.y > j.hip.y + 10.0, "stirrup foot forward and below")
  	check(j.knee_n.x > j.hip.x, "thigh along the saddle")


  func test_unknown_weapon_idles() -> void:
  	var j := FkSkeleton.solve(1.0, "no_such_weapon", {"atk": 0.45})
  	check_eq(j.lean, 0.0, "no stance, no lean")
  ```

- [ ] **Step 2: Run the tests.** Expected: FAIL, because `solve` does not exist.

- [ ] **Step 3: Implement.** Append to `skeleton.gd`. The keyframe values reproduce today's hand spots at guard, taken from the current `FkWeapons.weapon` code, and add the missing body motion:
  ```gdscript
  ## Weapon kind → stance family.
  const FAMILY := {
  	"club": "chop", "sword": "chop", "saber": "chop", "gladius": "chop", "axe": "chop", "hammer": "chop",
  	"rune_hammer": "chop", "leafblade": "chop", "spellsword": "chop", "baton": "chop", "shovel": "chop",
  	"spear": "thrust", "lance": "thrust", "halberd": "pole", "glaive": "pole",
  	"musket": "aim", "rifle": "aim", "arcane_rifle": "aim", "rune_rifle": "aim", "crossbow": "aim",
  	"bow": "bow", "starbow": "bow", "javelin": "throw", "throwing_axe": "throw", "sling": "sling",
  	"staff": "staff", "crew": "crew",
  }

  ## Keyframes guard / wind / hit, relative to the shoulder line `sh`, in px × build:
  ## h = near-hand target, f = far-hand target (absent = hangs and counter-swings), a = weapon angle
  ## (rad; 0 = forward, −PI/2 = up), lean = torso lean (rad, + forward), lunge = body shift forward (px).
  ## arc = the near hand travels around the shoulder (overhead chops) instead of in a straight line.
  const STANCES := {
  	"idle": {"guard": {"h": Vector2(3, 16)}, "wind": {"h": Vector2(3, 16)}, "hit": {"h": Vector2(3, 16)}},
  	"chop": {"arc": true,
  		"guard": {"h": Vector2(14, 5), "a": -0.33},
  		"wind": {"h": Vector2(3.6, -14.5), "a": -2.03, "lean": -0.08, "lunge": -1.5},
  		"hit": {"h": Vector2(13, 9), "a": 0.1, "lean": 0.2, "lunge": 6.0}},
  	"thrust": {"two": true,
  		"guard": {"h": Vector2(12, 9), "a": -0.12},
  		"wind": {"h": Vector2(0, 9), "a": -0.12, "lean": -0.06, "lunge": -2.0},
  		"hit": {"h": Vector2(22, 8), "a": -0.12, "lean": 0.18, "lunge": 7.0}},
  	"pole": {"two": true,
  		"guard": {"h": Vector2(10, 8), "a": -PI / 2},
  		"wind": {"h": Vector2(0, 9), "a": -0.12, "lean": -0.06, "lunge": -2.0},
  		"hit": {"h": Vector2(22, 8), "a": -0.12, "lean": 0.18, "lunge": 7.0}},
  	"aim": {
  		"guard": {"h": Vector2(12, 1), "f": Vector2(17, 2), "a": 0.0},
  		"wind": {"h": Vector2(12, 1), "f": Vector2(17, 2), "a": 0.0},
  		"hit": {"h": Vector2(8.5, 1), "f": Vector2(13.5, 2), "a": -0.08, "lean": -0.06}},
  	"bow": {
  		"guard": {"h": Vector2(11, 1), "f": Vector2(15, 1), "a": 0.0},
  		"wind": {"h": Vector2(3, -3), "f": Vector2(16, 0), "a": 0.0, "lean": -0.03},
  		"hit": {"h": Vector2(11, 1), "f": Vector2(15, 1), "a": 0.0}},
  	"throw": {"arc": true,
  		"guard": {"h": Vector2(4, -9), "a": -0.23},
  		"wind": {"h": Vector2(-7, -10), "a": -0.35, "lean": -0.1, "lunge": -1.5},
  		"hit": {"h": Vector2(15, 0), "a": 0.1, "lean": 0.2, "lunge": 6.0}},
  	"sling": {"guard": {"h": Vector2(2, -14)}, "wind": {"h": Vector2(2, -14)}, "hit": {"h": Vector2(8, -10), "lean": 0.1}},
  	"staff": {
  		"guard": {"h": Vector2(10, 6), "f": Vector2(9, 13), "a": -1.456},
  		"wind": {"h": Vector2(8, 6), "f": Vector2(7, 13), "a": -1.5},
  		"hit": {"h": Vector2(15, 0), "f": Vector2(13, 8), "a": -1.2, "lean": 0.12, "lunge": 3.0}},
  	"crew": {"guard": {"h": Vector2(14, 8), "f": Vector2(12, 9)}, "wind": {"h": Vector2(14, 8), "f": Vector2(12, 9)},
  		"hit": {"h": Vector2(15, 8), "f": Vector2(13, 9), "lean": 0.1}},
  }

  ## Far-hand shield grip (relative to sh) for shield bearers: holds the shield in front of the chest.
  const SHIELD_GRIP := Vector2(6, 11)


  ## One frame's keyframe values: guard blended toward wind (s < 0) or hit (s > 0).
  static func key(family: String, atk: float) -> Dictionary:
  	var st: Dictionary = STANCES.get(family, STANCES.idle)
  	var s := FkUnits.swing(atk)
  	var a: Dictionary = st.guard
  	var z: Dictionary = st.wind if s < 0.0 else st.hit
  	var k := absf(s)
  	var out := {"lean": lerpf(a.get("lean", 0.0), z.get("lean", 0.0), k),
  		"lunge": lerpf(a.get("lunge", 0.0), z.get("lunge", 0.0), k),
  		"a": lerpf(a.get("a", 0.0), z.get("a", 0.0), k), "two": st.get("two", false)}
  	var h0: Vector2 = a.h
  	var h1: Vector2 = z.h
  	if st.get("arc", false):
  		out["h"] = Vector2.from_angle(lerpf(h0.angle(), h1.angle(), k)) * lerpf(h0.length(), h1.length(), k)
  	else:
  		out["h"] = h0.lerp(h1, k)
  	if a.has("f"):
  		out["f"] = (a.f as Vector2).lerp(z.f, k)
  	return out


  ## All joints for one frame. b = build; pose = {walk, move, atk}; shield = far hand holds a shield;
  ## seated = rider (one leg in a stirrup, no walk cycle).
  static func solve(b: float, weapon: String, pose: Dictionary, shield := false, seated := false) -> Dictionary:
  	var mv: float = pose.get("move", 1.0 if pose.get("moving", false) else 0.0)
  	var walk: float = pose.get("walk", 0.0)
  	var t: float = pose.get("t", 0.0)
  	var k := key(FAMILY.get(weapon, "idle"), pose.get("atk", -1.0))
  	var bob := lerpf(sin(t * 2.1) * 0.7, absf(sin(walk)) * 2.2, mv)
  	var lunge: float = k.lunge * b * (0.0 if seated else 1.0)
  	var hip := Vector2(lunge * 0.6, -HIP_Y * b + bob * 0.5)
  	var sh := hip + Vector2(1.5 * b, -SPINE * b).rotated(k.lean)
  	var j := {"hip": hip, "sh": sh, "lean": k.lean, "lunge": lunge, "dir": Vector2.from_angle(k.a)}
  	# Legs: feet on the ground line; a stride with lift while walking, the front foot planted forward on a lunge.
  	for i in 2:
  		var foot: Vector2
  		if seated:
  			foot = hip + Vector2(5.0 - 3.0 * i, 16.0) * b
  		else:
  			var ph := walk + PI * i
  			var fx := lerpf(2.8 if i == 0 else -3.6, 13.0 * sin(ph), mv) + (lunge * 1.6 / b if i == 0 else 0.0)
  			var lift := 5.0 * maxf(0.0, cos(ph)) * mv
  			foot = Vector2(fx * b, -lift * b)
  		foot = reach(hip, foot, THIGH * b, SHIN * b)
  		var tag := "n" if i == 0 else "f"
  		j["foot_" + tag] = foot
  		j["knee_" + tag] = ik(hip, foot, THIGH * b, SHIN * b, Vector2.RIGHT)
  	# Arms: near arm to the stance's hand target; far arm to the shield grip, the weapon (two-handed),
  	# the stance's far target, or hanging with a counter-swing.
  	j["sh_n"] = sh + Vector2(2, 1) * b
  	j["sh_f"] = sh + Vector2(-3, 1) * b
  	var elbow_side := Vector2(-0.3, 1.0)
  	var hand_n := reach(j.sh_n, sh + (k.h as Vector2) * b, UPPER * b, FORE * b)
  	j["hand_n"] = hand_n
  	j["elbow_n"] = ik(j.sh_n, hand_n, UPPER * b, FORE * b, elbow_side)
  	var ft: Vector2
  	if shield:
  		ft = sh + SHIELD_GRIP * b
  	elif k.has("f"):
  		ft = sh + (k.f as Vector2) * b
  	elif k.two:
  		ft = hand_n - (j.dir as Vector2) * 8.0 * b
  	else:
  		ft = j.sh_f + Vector2(0, 16.5 * b).rotated(sin(walk) * 0.5 * mv - 0.1)
  	var hand_f := reach(j.sh_f, ft, UPPER * b, FORE * b)
  	j["hand_f"] = hand_f
  	j["elbow_f"] = ik(j.sh_f, hand_f, UPPER * b, FORE * b, elbow_side)
  	return j
  ```

- [ ] **Step 4: Run the tests.** Expected: all pass. If a keyframe breaks an invariant, e.g. a far-hand target the reach clamp can't satisfy, or a knee side, adjust that keyframe value, not the invariant. Ledger each keyframe change as a ruling.

- [ ] **Step 5: Commit** `figure kit: stance keyframes and FkSkeleton.solve`.

---

### Task 3: Draw the figure from the skeleton

**Files:**
- Modify: `addons/figure_kit/figure.gd` (`humanoid`, `arm`), `addons/figure_kit/weapons.gd` (`weapon` signature and hand logic), `addons/figure_kit/mounts.gd` (`_rider`: drop the straddle line)
- Test: `tests/test_fk_skeleton.gd` (axe edge)

**Interfaces:**
- Consumes: `FkSkeleton.solve`.
- Produces:
  - `FkFigure.arm(ci, shoulder: Vector2, elbow: Vector2, hand: Vector2, b, sleeve, skin, bracer)`. It now takes the solved elbow.
  - `FkWeapons.weapon(ci, kind, j: Dictionary, b, s, atk, pal, tm, skin, pose, t, lk)`, where `j` is the solve result. It draws only the weapon.
  - `FkWeapons.edge_normal(dir: Vector2) -> Vector2`, the side a bladed head faces: the leading side of a downward/forward swing.

- [ ] **Step 1: Write the failing axe-edge test.** Append:
  ```gdscript
  func test_axe_edge_leads_the_swing() -> void:
  	# The blade's edge faces where the head is travelling at contact (the owner: "pointed end on the correct direction").
  	var before := FkSkeleton.solve(1.0, "axe", {"atk": 0.40})
  	var hit := FkSkeleton.solve(1.0, "axe", {"atk": 0.47})
  	var tip0: Vector2 = before.hand_n + (before.dir as Vector2) * 20.0
  	var tip1: Vector2 = hit.hand_n + (hit.dir as Vector2) * 20.0
  	check(FkWeapons.edge_normal(hit.dir).dot(tip1 - tip0) > 0.0, "edge faces the direction of travel")
  ```
  Run it. Expected: FAIL (`edge_normal` does not exist).

- [ ] **Step 2: Rework `FkWeapons.weapon`.**
  - New signature:
    `static func weapon(ci: CanvasItem, kind: String, j: Dictionary, b: float, s: float, atk: float, pal: Array, tm: Color, skin: Color, pose: Dictionary, t: float, lk: Dictionary) -> void:`
  - Delete the `sleeve`/`bracer` locals and every `FkFigure.arm(...)` line; arms are the figure's job now.
  - In every branch, replace the hand/direction computation:
    - **CHOP:** delete the `theta` block. `var hand: Vector2 = j.hand_n`, `var dirv: Vector2 = j.dir`. Keep the smear, but compute its start from the wind keyframe: `var w := FkSkeleton.key("chop", 0.349); var t0: Vector2 = (w.h as Vector2) * b + Vector2.from_angle(w.a) * length * b`, and draw the arc around `j.sh`.
    - **Upright polearm at rest** (`"halberd", "glaive" when atk < 0.0`): `var hand: Vector2 = j.hand_n`. The shaft stays vertical.
    - **Thrust:** `var hand: Vector2 = j.hand_n`, `var dirv: Vector2 = j.dir`.
    - **Javelin/throwing axe:** `var hand: Vector2 = j.hand_n`, and the javelin line follows `j.dir`: from `hand - dir * 14 * b` to `hand + dir * 16 * b`, with the head at the front.
    - **Sling:** `var hand: Vector2 = j.hand_n`.
    - **Bow:** the bow is held in the **far** hand, `var hand: Vector2 = j.hand_f`, and the string/nock is at the near hand, `var nock: Vector2 = j.hand_n`. Delete `draw_back` (the stance moves the near hand).
    - **Staff:** `var hand: Vector2 = j.hand_n`, and the staff runs along `j.dir`: from `hand - dir * 22 * b` to `hand + dir * 30 * b`.
    - **Crew:** no weapon; the branch becomes `pass`.
    - **Crossbow and guns:** `var hand: Vector2 = j.hand_n`, and `var stock := hand + Vector2(-13, -2) * b`, rotated by `j.dir.angle()` about the hand, so recoil tilt shows. Delete `kick` from the positions; the stance recoils the hand.
  - Keep every drawing detail otherwise: colours, glows, arrows, sparks.
  - Keep the final `ci.draw_circle(hand, 3.2 * b, skin)` grip redraws.
  - **Axe and halberd heads:** replace `orth` with `edge_normal(dirv)` wherever the blade polygon extends. Add:
    ```gdscript
    ## Side a bladed head's edge faces: the leading side of the figure's forward/downward strike.
    static func edge_normal(dir: Vector2) -> Vector2:
    	return -dir.orthogonal()
    ```
    If the Step 1 test still fails with `-dir.orthogonal()`, the sign convention is the other way: return `dir.orthogonal()` and flip the blade polygons to match. The test decides.

- [ ] **Step 3: Rework `FkFigure.arm` and `humanoid`.**
  - **`arm`:**
    `static func arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, hand: Vector2, b: float, sleeve: Color, skin: Color, bracer: Color) -> void:`
    Same body as today, but it uses the given `elbow` instead of computing one.
  - **`humanoid`:**
    1. Early on: `var j := FkSkeleton.solve(build, st.get("weapon", "none"), pose, st.get("shield", "") != "", not legs)`. Then `var hip: Vector2 = j.hip` and `var sh: Vector2 = j.sh`, which replace the old `hip`/`sh` lines, and drop the local `bob`. The seed-phase idle bob moves into `solve` via `pose.t` (a ruling if the per-unit desync matters: pass `t + seed` in the pose).
    2. Legs (inside the race-body transform, as today):
       - draw the far leg `(hip → knee_f → foot_f)` darkened, then the near leg `(hip → knee_n → foot_n)`, with the existing `seg` widths, armour greaves and boot polygon at each foot;
       - when `legs == false`, draw only the near leg: the seated one, whose boot sits in the stirrup;
       - no shadow when seated, as today.
    3. Cape, pack and torso: unchanged code. They use the leaned `sh` and the lunged `hip`, so they tilt and step with the body.
    4. Far arm: before the torso, `FkPaint.seg` × 2 from `j.sh_f → j.elbow_f → j.hand_f` in `cloth.darkened(0.3)`, plus the hand. This replaces the `arm_sw`/`back_hand` block.
    5. After `FkPaint.pop(ci)`, map the joints that live outside the race-body transform: `var m := func(p: Vector2) -> Vector2: return pivot + (p - pivot) * body`. Then:
       - `sh = m.call(j.sh)`;
       - for the arms, offset every arm joint by `m.call(j.sh_n) - j.sh_n`, so arms keep their length but follow the scaled shoulder;
       - do the same for the far hand before the shield grip.
    6. Head: as today, from the mapped `sh`.
    7. Shield: `FkArmour.shield(..., sh, ...)`, unchanged. Its centre already sits at the far-hand grip `SHIELD_GRIP`.
    8. Near arm: `FkFigure.arm(ci, jn.sh_n, jn.elbow_n, jn.hand_n, b, sleeve, skin, bracer)`, where `jn` is the offset joints. `sleeve` and `bracer` move here from `weapon`.
    9. Weapon: `FkWeapons.weapon(ci, st.get("weapon", "none"), jn, build, FkUnits.swing(atk), atk, pal, tm, skin, pose, t, lk)`.
  - **Rider** (`mounts.gd` `_rider`): delete the `ci.draw_line(at + Vector2(0, -2), at + Vector2(8, 10), cloth, 6.0)` straddle line and its now-unused `cloth` local. The seated leg replaces it.

- [ ] **Step 4: Run the tests.** Expected: all pass, including the axe edge and the boundary test.

- [ ] **Step 5: Smoke render.** Run `tools/unit_gallery.gd --race=all` at `--atk` −1, 0.25 and 0.45. Expected: no script errors and every unit drawn. Look at the three images; a missing weapon or a floating hand is a bug to fix now, before review.

- [ ] **Step 6: Commit** `figure kit: figures drawn from the skeleton; weapons attach to solved hands; axe edge leads`.

---

### Task 4: Review sheet tool

**Files:**
- Create: `tools/unit_sheet.gd`

- [ ] **Step 1: Write the tool.** It renders one role for one race: rows are ages 1–6, and columns are 4 walk phases (move 1), guard, wind-up (0.25), strike (0.45) and recover (0.75). It draws at 2.4× on a mid-grey background in a 1920×1440 SubViewport, and saves to `--out`. Arguments: `--role=vanguard|ranged|heavy|siege`, `--race=human|elf|dwarf`, `--out=…`. Add column captions ("walk", "walk", "walk", "walk", "guard", "wind-up", "strike", "recover") and row captions (unit names from `GameData.race(r).unit_name(def)`, using the same `UiStyle.font("bold")` the gallery uses).
  ```gdscript
  extends SceneTree
  ## Owner review sheet: one role for one race — rows = ages, columns = walk ×4, guard, wind-up, strike, recover.
  ##   godot --path . --resolution 1920x1080 -s tools/unit_sheet.gd -- --role=vanguard --race=elf --out=reports/sheet_vanguard_elf.png

  const COLS := [["walk", 0.0, 1.0, -1.0], ["walk", 1.6, 1.0, -1.0], ["walk", 3.1, 1.0, -1.0], ["walk", 4.7, 1.0, -1.0],
  	["guard", 0.6, 0.0, -1.0], ["wind-up", 0.6, 0.0, 0.25], ["strike", 0.6, 0.0, 0.45], ["recover", 0.6, 0.0, 0.75]]

  var out := "reports/unit_sheet.png"
  var race: StringName = &"human"
  var role := "vanguard"
  var vp := SubViewport.new()


  func _initialize() -> void:
  	for a in OS.get_cmdline_user_args():
  		if a.begins_with("--out="):
  			out = a.get_slice("=", 1)
  		elif a.begins_with("--race="):
  			race = StringName(a.get_slice("=", 1))
  		elif a.begins_with("--role="):
  			role = a.get_slice("=", 1)
  	vp.size = Vector2i(1920, 1440)
  	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
  	root.add_child(vp)
  	var bg := ColorRect.new()
  	bg.color = Color("8a8f98")
  	bg.size = Vector2(1920, 1440)
  	vp.add_child(bg)
  	var n := Node2D.new()
  	n.draw.connect(_draw.bind(n))
  	vp.add_child(n)
  	_capture.call_deferred()


  func _draw(n: Node2D) -> void:
  	var gd := GameData.get_default()
  	var f := UiStyle.font("bold")
  	for c in COLS.size():
  		n.draw_string(f, Vector2(150 + c * 220, 34), COLS[c][0], HORIZONTAL_ALIGNMENT_CENTER, 200, 18, Color(0.1, 0.1, 0.1))
  	for age in range(1, 7):
  		var def := gd.unit_for_role(age, role)
  		if def == null:
  			continue
  		var y := 60 + age * 225
  		n.draw_string(f, Vector2(8, y - 150), gd.race(race).unit_name(def), HORIZONTAL_ALIGNMENT_LEFT, 150, 16, Color(0.1, 0.1, 0.1))
  		for c in COLS.size():
  			var col: Array = COLS[c]
  			FkPaint.begin(n, Transform2D(0.0, Vector2(2.4, 2.4), 0.0, Vector2(250 + c * 220, y)))
  			UnitArt.draw_unit(n, def, Color("3a78d8"), {"walk": col[1], "move": col[2], "atk": col[3], "t": 0.3, "flash": 0.0}, age * 4, race)
  			n.draw_set_transform(Vector2.ZERO)


  func _capture() -> void:
  	for i in 3:
  		await process_frame
  	await RenderingServer.frame_post_draw
  	vp.get_texture().get_image().save_png(out)
  	print("sheet saved: ", out)
  	quit()
  ```

- [ ] **Step 2: Run it** for vanguard/human. Expected: `sheet saved`, no script errors, 6 rows × 8 figures.

- [ ] **Step 3: Commit** `tools: unit_sheet.gd role review sheets`. Also add the sheet command to CLAUDE.md's Commands block, next to the gallery line.

---

### Task 5: Vanguard batch — tune, then OWNER CHECKPOINT

- [ ] **Step 1: Render all Vanguard sheets.**
  Run `tools/unit_sheet.gd --role=vanguard --race=<r> --out=reports/sheet_vanguard_<r>.png` for human, elf and dwarf.

- [ ] **Step 2: Self-check each figure** against the invariants and the owner's complaints, and fix what fails before showing the owner. Check:
  - feet all point forward;
  - the weapon hand is in front and on top;
  - the weapon is attached to the hand;
  - the axe edge leads;
  - wind-up is clearly back or overhead, and the strike is clearly forward with lean and lunge;
  - no limb bends backward;
  - the shield doesn't hide the striking hand.

  Fix by adjusting `STANCES` values or per-weapon grip offsets, never by breaking a test. Ledger each change.

- [ ] **Step 3: Run the tests** (all green), then commit `art: vanguard skeleton pass` with the three sheets.

- [ ] **Step 4: OWNER CHECKPOINT.** Show the three sheets (published as one artifact page or described with crops). Ask the owner to approve, or flag units by name. **Stop until they answer.** Apply the flags in a follow-up commit, re-render and re-show. Continue only after approval.

### Task 6: Ranged batch — same loop as Task 5

Bow (far hand holds the bow, near hand draws to the chin), crossbow and guns (stock at the shoulder, recoil), javelin/throwing axe (overhead throw), sling, staff. **OWNER CHECKPOINT.**

### Task 7: Heavy batch (riders, chariot drivers, walkers) — same loop

Seated leg in the stirrup, lance couched (the thrust family), sabre riders (chop). Walkers (golem, treant, steam tank) are out of scope; flag anything odd to the owner. **OWNER CHECKPOINT.**

### Task 8: Siege crews — same loop

Crews grip their engine with both hands and push on the attack. **OWNER CHECKPOINT.**

### Task 9: Close out

- [ ] **Step 1: Regenerate** `reports/unit_gallery.png`, `reports/unit_gallery_races.png` and the silhouette check. Roles must still separate by shape.
- [ ] **Step 2: Take an in-game screenshot** at 1600×900 of a melee clash (both teams) and check mirrored facing. Owner reviews locally.
- [ ] **Step 3: Update the README.** Add `FkSkeleton` (the stance families and `solve`) to `addons/figure_kit/README.md`, and note that weapons attach to solved hands.
- [ ] **Step 4: Final tests and commit.**
