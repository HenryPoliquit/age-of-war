# Humanoid Body Rig Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the humanoid figure a 2.5D body rig: chest, neck, head, eye, hip roots and toe joints, and a depth per joint. Use that depth to layer the parts, which fixes the bow's "elbow behind the shoulder" and "string over the arm" artefacts. Add walk counter-rotation and a real toe bend. Every approved motion stays as it is.

**Architecture:** `FkSkeleton.solve()` keeps every existing key and adds new joints, `j.z` (depth per joint, + toward the viewer), `j.w`, `head_tilt`, `toe_bend_*` and `sockets`. The race proportions move into the bones through a new `look` argument. `FkFigure.humanoid()` stops drawing in fixed code order. It builds a list of `[depth, rank, name, draw]` parts from the joints, sorts it, and draws it. Ties keep today's order, so nothing moves until a pose really crosses.

**Tech Stack:** Godot 4.7-stable, GDScript. Custom headless test runner (`tests/run_tests.gd`, `TestCase` with `check`, `check_eq`, `check_near`).

**Spec:** `docs/superpowers/specs/2026-09-27-humanoid-body-rig-design.md`. Also read `docs/superpowers/specs/2026-09-27-unit-skeleton-design.md` §6 (the owner's motion briefs, which must not regress).

## Global Constraints

- Godot `../Godot_v4.7/Godot_v4.7-stable_win64_console.exe`, always wrapped in `timeout`. In bash, `G="../Godot_v4.7/Godot_v4.7-stable_win64_console.exe"`.
- Tests: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd`. The baseline is 121 tests, 0 failures.
- `addons/figure_kit/` must never name a game class, not even in comments (enforced by `tests/test_fk_boundary.gd`).
- Sim and balance are untouched. Only `addons/figure_kit/` and its tests change.
- Stats and stance numbers are not retuned. The one exception is that a test proves a number wrong; then the task says exactly which one.
- Screenshot runs segfault on quit (exit 139). That is known and not a failure.
- If `--import` runs, revert the line-ending churn: `git checkout -- assets/fonts/*.import reports/*.import`.
- Scratchpad (`$S`): `C:/Users/PERSONAL/AppData/Local/Temp/claude/E--Game-Drafts-Age-of-War/de2e4522-f256-4a88-ae25-1787b116e183/scratchpad`. It already holds `bowdiag.gd`, `bow_before.png` and `bow_zoom_before.png`.
- Animation review page: `https://claude.ai/artifact/NmKt5Dn4HPV7ArTeiv3RXm`. Republish to the same URL.
- Branch: `art/readable-arms`. Commit style: `figure kit: …`, ending with the `Co-Authored-By` line.

## Review Focus

1. **Dwarf and elf riders:** they must sit on the saddle, not sink into it. The seated hip is not scaled by `body.y`. Task 1: `test_rider_sits_on_the_saddle_whatever_the_race`.
2. **Marching shield wall:** the shield must never pop over the weapon arm at any walk phase or yaw. Task 2 `test_marching_shield_wall_keeps_the_weapon_arm_on_top`, re-run after Task 5 adds twist.
3. **Small and seated figures:** crews (scale 0.85), riders and chariot drivers must keep today's order. Task 2: `test_small_crew_and_riders_keep_the_order`.
4. **Unknown or missing weapons with a race look:** these must still solve and layer. Task 2 `test_standing_order_is_the_approved_order` includes `"no_such_weapon"` and `"none"` for all three races.
5. **Default look:** every pre-existing joint must stay unchanged at standing frames, so all approved motions survive. Task 1: `test_default_look_matches_the_pre_rig_skeleton`, checked against a golden captured before any change.

---

### Task 1: Rig joints and depth in `FkSkeleton.solve`

Spec §1. This task changes nothing visually: `figure.gd` doesn't pass `look` yet and still reads only the old keys.

**Files:**
- Create: `tests/fk_golden.txt` (generated snapshot)
- Modify: `addons/figure_kit/skeleton.gd` (constants, `boot`, `solve`, new `_fit`)
- Modify: `tests/test_fk_skeleton.gd`

**Interfaces:**
- Produces:
  - `FkSkeleton.solve(b: float, weapon: String, pose: Dictionary, shield := "", seated := false, look := {}) -> Dictionary`.
  - New keys:
    - `chest`, `neck`, `head`, `eye`, `hip_n`, `hip_f`, `toe_n`, `toe_f` (Vector2);
    - `head_tilt`, `w`, `toe_bend_n`, `toe_bend_f` (float, toe bend 0.0 until Task 4);
    - `z` (Dictionary: joint name → float, for `hip chest sh neck head eye hip_* knee_* foot_* toe_* sh_* elbow_* hand_*`);
    - `sockets` (`{grip_n, grip_f, back}`, each `{p: Vector2, a: float, z: float}`).
  - `FkSkeleton.boot(foot: Vector2, rot: float, b: float, toe := 0.0, body := Vector2.ONE) -> Array`.
  - Constants `FkSkeleton.HALF_W := 4.0` and `FkSkeleton.BALL := Vector2(4.5, 1.5)`.

- [ ] **Step 1: Capture the golden from the current code (before editing `skeleton.gd`)**

Write `$S/fk_golden.gd`:

```gdscript
extends SceneTree
## One-off: snapshot FkSkeleton.solve() at standing frames before the body-rig change.
const KEYS := ["hip", "sh", "sh_n", "sh_f", "elbow_n", "elbow_f", "hand_n", "hand_f", "knee_n", "knee_f", "foot_n",
	"foot_f", "rot_n", "rot_f", "dir", "lean", "lunge", "crouch", "zoom", "el_w"]


func _init() -> void:
	var out := []
	for w in ["sword", "axe", "spear", "halberd", "musket", "crossbow", "bow", "javelin", "throwing_axe", "sling", "staff",
			"crew", "none", "saber", "lance"]:
		for shield in ["", "round"]:
			for seated in [false, true]:
				for i in 12:
					var pose := {"walk": 0.6, "move": 0.0, "atk": -1.0 if i == 11 else i / 10.0, "t": 0.3}
					var j := FkSkeleton.solve(1.1, w, pose, shield, seated)
					var row := {"w": w, "shield": shield, "seated": seated, "pose": pose}
					for k in KEYS:
						row[k] = j[k]
					out.append(row)
	FileAccess.open("res://tests/fk_golden.txt", FileAccess.WRITE).store_string(var_to_str(out))
	quit()
```

Run: `timeout 60 "$G" --headless --path . -s "$S/fk_golden.gd"`
Expected: `tests/fk_golden.txt` exists (720 rows; check with `grep -c '"w":' tests/fk_golden.txt` → 720).

- [ ] **Step 2: Write the failing tests**

In `tests/test_fk_skeleton.gd`, make these edits.

(a) Replace `test_bones_never_stretch` entirely with:

```gdscript
func test_bones_never_stretch() -> void:
	var b := 1.16
	for w in ["sword", "axe", "spear", "halberd", "musket", "crossbow", "bow", "javelin", "sling", "staff", "crew", "none"]:
		_each_frame(w, func(j: Dictionary, f: Array) -> void:
			var tag := "%s %s" % [w, f]
			for bone in [["hip_n", "knee_n", FkSkeleton.THIGH], ["knee_n", "foot_n", FkSkeleton.SHIN],
					["hip_f", "knee_f", FkSkeleton.THIGH], ["knee_f", "foot_f", FkSkeleton.SHIN],
					["sh_n", "elbow_n", FkSkeleton.UPPER], ["elbow_n", "hand_n", FkSkeleton.FORE],
					["sh_f", "elbow_f", FkSkeleton.UPPER], ["elbow_f", "hand_f", FkSkeleton.FORE]]:
				# Measured in 3D: the bow's drawing arm swings toward the viewer and draws foreshortened.
				check_near(_d3(j, bone[0], bone[1]), bone[2] * b, 0.05, "%s %s-%s" % [tag, bone[0], bone[1]]))
```

(b) In `test_knees_forward_elbows_down_feet_grounded`, replace the two knee lines with:

```gdscript
			check(j.knee_n.x >= j.hip_n.lerp(j.foot_n, 0.5).x - 0.01, tag + " near knee forward")
			check(j.knee_f.x >= j.hip_f.lerp(j.foot_f, 0.5).x - 0.01, tag + " far knee forward")
```

(c) Eye checks now use the real eye joint:
- In `test_eyes_over_the_rim_for_every_shield`, replace `var eye: float = j.sh.y - 10.4` with `var eye: float = j.eye.y`.
- In `test_bow_draw_anchor_and_release`, replace `check(wind.hand_n.y > wind.sh.y - 10.4 + 3.0, …` with `check(wind.hand_n.y > wind.eye.y + 3.0, "arrow rests beneath the sighting eye")`.
- In `test_rifle_shouldered_at_eye_height_with_recoil`, replace `muzzle.y > j.sh.y - 10.4` with `muzzle.y > j.eye.y`.
- In `test_shield_wall_advance`, replace `fr[0].sh + Vector2(1.8, -9.5)` with `fr[0].head`.

(d) Append at the end of the file:

```gdscript
# --- Body rig (spec 2026-09-27-humanoid-body-rig-design) ---------------------------------------

const DWARF := {"body": Vector2(1.24, 0.76), "head": 1.1}
const ELF := {"body": Vector2(0.9, 1.1), "head": 0.93}
const GOLDEN_KEYS := ["hip", "sh", "sh_n", "sh_f", "elbow_n", "elbow_f", "hand_n", "hand_f", "knee_n", "knee_f", "foot_n",
	"foot_f", "rot_n", "rot_f", "dir", "lean", "lunge", "crouch", "zoom", "el_w"]


## Joint-to-joint distance in (x, y, z).
func _d3(j: Dictionary, a: String, c: String) -> float:
	var z: Dictionary = j.z
	return Vector3(j[a].x, j[a].y, z[a]).distance_to(Vector3(j[c].x, j[c].y, z[c]))


func test_default_look_matches_the_pre_rig_skeleton() -> void:
	var rows: Array = str_to_var(FileAccess.get_file_as_string("res://tests/fk_golden.txt"))
	check_eq(rows.size(), 720, "golden loaded")
	for row in rows:
		var j := FkSkeleton.solve(1.1, row.w, row.pose, row.shield, row.seated)
		for k in GOLDEN_KEYS:
			# A steered elbow (the bow draw) is now pulled within reach of both bones; its lengths are
			# checked in 3D instead.
			if k == "elbow_n" and row.el_w > 0.0:
				continue
			var d: float = (j[k] - row[k]).length() if row[k] is Vector2 else absf(j[k] - row[k])
			if d > 1e-3:
				check(false, "%s %s seated=%s atk=%.1f: %s moved %.4f" % [row.w, row.shield, row.seated, row.pose.atk, k, d])


func test_bones_keep_their_length_in_3d_for_every_race() -> void:
	var b := 1.16
	for lk in [{}, DWARF, ELF]:
		var body: Vector2 = lk.get("body", Vector2.ONE)
		var hb: float = b * lk.get("head", 1.0)
		var by: float = b * body.y
		for w in ["sword", "spear", "musket", "bow", "javelin", "sling", "none"]:
			for f in FRAMES:
				var j := FkSkeleton.solve(b, w, {"walk": f[0], "move": f[1], "atk": f[2]}, "", false, lk)
				var foot := (FkSkeleton.BALL * body * b).length()
				for bone in [["hip_n", "knee_n", FkSkeleton.THIGH * by], ["knee_n", "foot_n", FkSkeleton.SHIN * by],
						["hip_f", "knee_f", FkSkeleton.THIGH * by], ["knee_f", "foot_f", FkSkeleton.SHIN * by],
						["sh_n", "elbow_n", FkSkeleton.UPPER * b], ["elbow_n", "hand_n", FkSkeleton.FORE * b],
						["sh_f", "elbow_f", FkSkeleton.UPPER * b], ["elbow_f", "hand_f", FkSkeleton.FORE * b],
						["foot_n", "toe_n", foot], ["foot_f", "toe_f", foot],
						["hip", "sh", Vector2(1.5, -FkSkeleton.SPINE * body.y).length() * b],
						["sh", "neck", Vector2(0.8, -3.5).length() * hb], ["neck", "head", Vector2(1.0, -6.0).length() * hb],
						["hip", "hip_n", j.w], ["hip", "hip_f", j.w]]:
					check_near(_d3(j, bone[0], bone[1]), bone[2], 0.05, "%s %s %s: %s-%s" % [lk, w, f, bone[0], bone[1]])


func test_rider_sits_on_the_saddle_whatever_the_race() -> void:
	var human := FkSkeleton.solve(1.0, "saber", {"atk": -1.0}, "", true)
	var dwarf := FkSkeleton.solve(1.0, "saber", {"atk": -1.0}, "", true, DWARF)
	check_near(dwarf.hip.y, human.hip.y, 1e-4, "seat height is the saddle's, not the race's")
	check(dwarf.foot_n.y < human.foot_n.y - 2.0, "a dwarf's shorter legs hang higher in the stirrup")


func test_race_height_lives_in_the_legs() -> void:
	var human := FkSkeleton.solve(1.0, "none", {"atk": -1.0})
	var dwarf := FkSkeleton.solve(1.0, "none", {"atk": -1.0}, "", false, DWARF)
	check_near(dwarf.hip.y, human.hip.y * 0.76, 0.3, "dwarf hips stand at 0.76 of human height")
	var sole: float = FkSkeleton.boot(dwarf.foot_n, dwarf.rot_n, 1.0, 0.0, DWARF.body).map(func(q): return q.y).max()
	check_near(sole, 0.0, 0.05, "boot sole still on the ground")


func test_depth_near_side_toward_the_viewer() -> void:
	var j := FkSkeleton.solve(1.0, "sword", {"atk": -1.0})
	check(j.z.sh_n > 0.0 and j.z.sh_f < 0.0, "near shoulder toward the viewer, far shoulder away")
	check(j.z.hip_n > 0.0 and j.z.hip_f < 0.0, "near hip toward the viewer, far hip away")
	check_eq(j.z.elbow_n, j.z.sh_n, "an unsteered arm stays in its plane")
	check_eq(j.z.hand_n, j.z.sh_n, "…hand too")


func test_bow_elbow_swings_toward_the_viewer_mid_draw() -> void:
	var peak := 0.0
	for i in 36:
		var j := FkSkeleton.solve(1.0, "bow", {"atk": i / 100.0})
		peak = maxf(peak, j.z.elbow_n - j.z.sh_n)
	check(peak > 4.0, "mid-draw the upper arm points at the viewer (peak depth %.1f)" % peak)


func test_head_rides_the_neck_and_stays_level() -> void:
	var idle := FkSkeleton.solve(1.0, "none", {"atk": -1.0})
	check((idle.head - (idle.sh + Vector2(1.8, -9.5))).length() < 1e-3, "upright head where it always was")
	check((idle.eye - (idle.sh + Vector2(5.2, -10.4))).length() < 1e-3, "upright eye where it always was")
	for w in ["sword", "axe", "spear", "musket", "bow", "javelin", "sling", "saber"]:
		for atk in [-1.0, 0.2, 0.34, 0.45, 0.55, 0.8]:
			var j := FkSkeleton.solve(1.0, w, {"atk": atk}, "round" if w == "sword" else "")
			check(absf(j.head_tilt) < 0.1, "%s at %s: head level (tilt %.2f)" % [w, atk, j.head_tilt])
	var hit := FkSkeleton.solve(1.0, "sword", {"atk": 0.55}, "round")
	check(hit.head.x > hit.sh.x + 1.8, "the head follows a strong lean a little")


func test_sockets_sit_on_the_hands_and_back() -> void:
	var j := FkSkeleton.solve(1.0, "spear", {"atk": 0.5})
	check_eq(j.sockets.grip_n.p, j.hand_n)
	check_near(j.sockets.grip_n.a, j.dir.angle(), 1e-5)
	check_eq(j.sockets.grip_n.z, j.z.hand_n)
	check_eq(j.sockets.grip_f.p, j.hand_f)
	check_eq(j.sockets.back.p, j.chest)
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -30`
Expected: FAIL. The new tests error on the missing keys (`z`, `hip_n`, `eye`, …) and on the `solve()` call with 6 arguments. The golden test fails only on the missing `look` argument, or passes.

- [ ] **Step 4: Implement in `addons/figure_kit/skeleton.gd`**

(a) Under `const BOOT := …`, add:

```gdscript
## Half the body's width at shoulders and hips (× build × body.x): the near side stands this far toward
## the viewer in depth (z), the far side this far away.
const HALF_W := 4.0
## Ball of the foot in the boot's space (× build): the toe joint, where the boot bends.
const BALL := Vector2(4.5, 1.5)
```

(b) Replace `boot()` (and its doc comment) with:

```gdscript
## Boot outline points for an ankle at `foot`, rotated by `rot` (rad; − = toes up, + = heel up), the toe
## cap bent back by `toe` at the ball of the foot; `body` gives the race's proportions.
static func boot(foot: Vector2, rot: float, b: float, toe := 0.0, body := Vector2.ONE) -> Array:
	var ball := BALL * body * b
	return BOOT.map(func(p: Vector2) -> Vector2:
		var q := p * body * b
		if p.x > BALL.x:
			q = ball + (q - ball).rotated(-toe)
		return foot + q.rotated(rot))
```

(c) Replace `solve()` (and its doc comment) with the version below. Everything not mentioned in the comments is today's code, unchanged.

```gdscript
## All joints for one frame. b = build; pose = {walk, move, atk, t}; shield = the shield kind the far
## hand holds ("" = none); seated = rider (one leg in a stirrup, no walk cycle); look = the race preset:
## its `body` gives legs and spine their height (y) and the figure its width (x), its `head` the head's
## size. Every joint also has a depth in j.z (+ toward the viewer), and every bone keeps its length in 3D.
static func solve(b: float, weapon: String, pose: Dictionary, shield := "", seated := false, look := {}) -> Dictionary:
	var mv: float = pose.get("move", 1.0 if pose.get("moving", false) else 0.0)
	var walk: float = pose.get("walk", 0.0)
	var t: float = pose.get("t", 0.0)
	var body: Vector2 = look.get("body", Vector2.ONE)
	var hb: float = b * look.get("head", 1.0)
	var by := b * body.y
	var w := HALF_W * b * body.x
	var family: String = FAMILY.get(weapon, "idle")
	if seated:
		family = "ride_blade" if family in ["blade", "chop"] else ("ride_thrust" if family in ["thrust", "pole"] else family)
	elif shield != "" and family in ["blade", "chop"]:
		family = "shield"
	var g: Dictionary = GAITS[gait_for(weapon, shield)]
	var k := key(family, pose.get("atk", -1.0), {} if seated else g.get("carry", {}), mv)
	var bob := lerpf(sin(t * 2.1) * 0.7, absf(sin(walk)) * g.bob, mv)
	var lunge: float = k.lunge * b * (0.0 if seated else 1.0)
	var crouch: float = k.crouch * b * (0.0 if seated else 1.0)
	# On foot the hips stand at the race's leg height; a rider's seat is the saddle's whatever the race.
	var hip := Vector2(lunge * 0.6, (-HIP_Y * b + bob * 0.5 + crouch) * (1.0 if seated else body.y))
	# A rider's feet stay in the stirrups (relative to the saddle) while the hips rise off it; the hips
	# sway with the mount's gait and the spine absorbs its bob so the head stays level.
	var saddle_hip := hip
	if seated:
		hip.y -= k.rise * b
		hip.x += sin(pose.get("ride_walk", 0.0) * 2.0) * 0.8 * pose.get("ride_mv", 0.0) * b
	var sh := hip + Vector2(1.5 * b, -SPINE * by).rotated(k.lean)
	if seated:
		sh.y -= pose.get("ride_bob", 0.0)
	# Pelvis and chest turn against each other about the vertical axis as the figure walks.
	var yaw_p := 0.0
	var yaw_c := -0.8 * yaw_p
	var j := {"hip": hip, "sh": sh, "chest": hip.lerp(sh, 0.55), "lean": k.lean, "lunge": lunge, "crouch": k.crouch,
		"dir": Vector2.from_angle(k.a), "zoom": k.zoom, "gait": gait_for(weapon, shield), "w": w}
	var z := {"hip": 0.0, "chest": 0.0, "sh": 0.0, "neck": 0.0, "head": 0.0, "eye": 0.0}
	# Neck and head: the neck follows half the spine's lean and the head a quarter, so the gaze stays level.
	j["head_tilt"] = k.lean * 0.25
	j["neck"] = sh + Vector2(0.8, -3.5).rotated(k.lean * 0.5) * hb
	j["head"] = (j.neck as Vector2) + Vector2(1.0, -6.0).rotated(j.head_tilt) * hb
	j["eye"] = (j.head as Vector2) + Vector2(3.4, -0.9).rotated(j.head_tilt) * hb
	# Legs: from hip roots either side of the pelvis; feet on the ground line; the gait's stride, lift and
	# heel-to-toe roll while walking, the front foot planted forward on a lunge, the back foot swinging
	# through on a passing step.
	for i in 2:
		var tag := "n" if i == 0 else "f"
		var side := 1.0 if i == 0 else -1.0
		var root := hip + Vector2(side * w * sin(yaw_p), 0)
		j["hip_" + tag] = root
		z["hip_" + tag] = side * w * cos(yaw_p)
		var foot: Vector2
		var rot := 0.0
		var flex := 0.0
		var ph := walk + PI * i
		if seated:
			foot = saddle_hip + Vector2(5.0 - 3.0 * i, 16.0) * b * body
			rot = -0.3 - 0.05 * k.rise
		else:
			var fx := lerpf(2.8 if i == 0 else -3.6, g.stride * sin(ph), mv)
			var lift: float = g.lift * maxf(0.0, cos(ph)) * mv
			rot = _roll(ph, g.heel, g.toe) * mv
			fx += k.wide * (0.5 if i == 0 else -0.5)
			if i == 0:
				fx += lunge * 1.6 / b * (1.0 - k.step)
			else:
				fx = lerpf(fx, 2.8 + lunge * 1.6 / b, k.step)
				lift += 4.0 * k.step_lift
				rot -= 0.2 * k.step_lift
			foot = Vector2(fx, -lift) * by
			# Keep the boot's lowest point on (never under) the ground.
			var low := 0.0
			for p in boot(Vector2.ZERO, rot, b, flex, body):
				low = maxf(low, (p as Vector2).y)
			foot.y = minf(foot.y, -low)
		foot = reach(root, foot, THIGH * by, SHIN * by)
		j["foot_" + tag] = foot
		j["rot_" + tag] = rot
		j["toe_bend_" + tag] = flex
		j["toe_" + tag] = foot + (BALL * body * b).rotated(rot)
		j["knee_" + tag] = ik(root, foot, THIGH * by, SHIN * by, KNEE)
		j["dust_" + tag] = _bell(ph - PI / 2) * mv if g.get("dust", false) and not seated else 0.0
		for c in ["knee_", "foot_", "toe_"]:
			z[c + tag] = z["hip_" + tag]
	# Arms: shoulders ride on the chest (turned by its yaw) and move with the pose; near arm to the
	# stance's hand target; far arm to the shield (by its rim), the stance's far target, the weapon
	# (two-handed), or swinging with the gait.
	j["sh_n"] = sh + Vector2(2, 1) * b * body + (k.s as Vector2) * b + Vector2(w * sin(yaw_c), 0)
	j["sh_f"] = sh + Vector2(-3, 1) * b * body + (k.sf as Vector2) * b - Vector2(w * sin(yaw_c), 0)
	z["sh_n"] = w * cos(yaw_c)
	z["sh_f"] = -w * cos(yaw_c)
	var target_n := sh + (k.h as Vector2) * b
	if pose.get("atk", -1.0) < 0.0:
		target_n.x -= sin(walk) * g.get("hswing", 0.0) * mv * b
	var hand_n := reach(j.sh_n, target_n, UPPER * b, FORE * b)
	var bend: float = k.bend
	if absf(bend) < 1.0:
		# Changing which way the elbow folds: the arm straightens through the change, so it never snaps.
		var v := hand_n - (j.sh_n as Vector2)
		hand_n = j.sh_n + v.normalized() * lerpf((UPPER + FORE) * b - 0.01, v.length(), absf(bend))
	j["hand_n"] = hand_n
	j["bend_n"] = 1.0 if bend >= 0.0 else -1.0
	j["elbow_n"] = ik(j.sh_n, hand_n, UPPER * b, FORE * b, j.bend_n if absf(bend) > 1e-3 else 0.0)
	j["el_w"] = k.el_w
	z["elbow_n"] = z.sh_n
	z["hand_n"] = z.sh_n
	if k.el_w > 0.0:
		# A steered elbow sits where it shows on screen; its depth keeps both bones their length, so an
		# arm swinging round toward the viewer draws foreshortened.
		var el := _fit((j.elbow_n as Vector2).lerp(sh + (k.el as Vector2) * b, k.el_w), j.sh_n, hand_n, UPPER * b, FORE * b)
		j["elbow_n"] = el
		z["elbow_n"] = z.sh_n + sqrt(maxf(0.0, pow(UPPER * b, 2) - el.distance_squared_to(j.sh_n)))
		z["hand_n"] = z.elbow_n - sqrt(maxf(0.0, pow(FORE * b, 2) - el.distance_squared_to(hand_n)))
	if k.lock > 0.0:
		j["dir"] = (j.dir as Vector2).slerp((hand_n - (j.elbow_n as Vector2)).normalized(), k.lock)
	var ft: Vector2
	if k.has("rim") and shield != "":
		ft = sh + ((k.rim as Vector2) + Vector2(0, FkArmour.SHIELD_TOP.get(shield, 10.5))) * b
	elif k.has("f"):
		ft = sh + (k.f as Vector2) * b
	elif shield != "":
		ft = sh + SHIELD_GRIP * b
	elif k.two:
		ft = hand_n - (j.dir as Vector2) * 8.0 * b
	else:
		ft = j.sh_f + Vector2(0, 16.5 * b).rotated(sin(walk) * g.swing * mv - 0.1)
	var hand_f := reach(j.sh_f, ft, UPPER * b, FORE * b)
	j["hand_f"] = hand_f
	j["elbow_f"] = ik(j.sh_f, hand_f, UPPER * b, FORE * b, ELBOW)
	z["elbow_f"] = z.sh_f
	z["hand_f"] = z.sh_f
	j["z"] = z
	# Attachment points (weapons and shields are still drawn from the hands; these are the hook).
	j["sockets"] = {"grip_n": {"p": hand_n, "a": (j.dir as Vector2).angle(), "z": z.hand_n},
		"grip_f": {"p": hand_f, "a": (hand_f - (j.elbow_f as Vector2)).angle(), "z": z.hand_f},
		"back": {"p": j.chest, "a": (sh - hip).angle(), "z": 0.0}}
	return j


## `p` pulled within reach of both `a` (bone la) and `c` (bone lc): alternating projections onto the
## two discs, so a steered joint never stretches either bone.
static func _fit(p: Vector2, a: Vector2, c: Vector2, la: float, lc: float) -> Vector2:
	for i in 8:
		if p.distance_to(a) > la:
			p = a + (p - a).normalized() * la
		if p.distance_to(c) > lc:
			p = c + (p - c).normalized() * lc
	return p
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -30`
Expected: every test passes (121 existing, with the deliberate edits, plus 8 new).

If `test_default_look_matches_the_pre_rig_skeleton` reports a moved key, the new `solve()` differs from today's somewhere other than the steered elbow. Diff the two versions line by line. Do not loosen the tolerance.

If a bow test fails on the elbow (`test_bow_draw_elbow_travels_level_not_over_the_shoulder` or `test_bow_draw_anchor_and_release`), `_fit` moved a steered elbow that used to stretch a bone. Report the atk and the size of the move before changing anything; the owner approved those elbow paths.

- [ ] **Step 6: Commit**

```bash
git add addons/figure_kit/skeleton.gd tests/test_fk_skeleton.gd tests/fk_golden.txt
git commit -m "figure kit: body rig joints — chest, neck, head, eye, hip roots, toes, depth per joint, race proportions in the bones

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Depth-sorted layering in `FkFigure.humanoid`

Spec §2, plus bone-length proportions and drawing the head at its joint and tilt (spec §5 stage 2).

**Files:**
- Modify: `addons/figure_kit/figure.gd` (lines 7–228: `arm` stays, and `upper_arm`/`forearm` are added; `humanoid`, `_smear` and `_impact_accents` are rewritten; the rest is untouched)
- Modify: `addons/figure_kit/weapons.gd` (add `HELD_FAR`)
- Create: `tests/test_fk_figure.gd`

**Interfaces:**
- Consumes (from Task 1): `FkSkeleton.solve(..., look)`, `j.z`, `j.hip_n`/`j.hip_f`, `j.head`, `j.head_tilt`, `j.toe_bend_*`, `FkSkeleton.boot(foot, rot, b, toe, body)`.
- Produces:
  - `FkFigure.PARTS: Array` (17 part names);
  - `FkFigure.layers(st: Dictionary, pose: Dictionary, seed := 0, scale := 1.0, legs := true) -> Array`;
  - `FkFigure.upper_arm(...)` and `FkFigure.forearm(...)`;
  - `FkWeapons.HELD_FAR := ["bow", "starbow"]`.
- `humanoid(ci, st, pose, seed, scale := 1.0, legs := true)` keeps its signature.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_fk_figure.gd`:

```gdscript
extends TestCase
## FkFigure layering: parts drawn back to front by depth, in today's order wherever depths tie.


func _spec(weapon: String, shield := "", race := &"human") -> Dictionary:
	return {"rig": "humanoid", "weapon": weapon, "shield": shield, "look": FkLooks.BODIES[race],
		"palette": FkLooks.PALETTES[race][2], "team": Color.RED, "build": 1.0}


func test_standing_order_is_the_approved_order() -> void:
	for w in ["sword", "axe", "spear", "halberd", "musket", "bow", "javelin", "sling", "staff", "crew", "none", "no_such_weapon"]:
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
	for i in 101:
		var pose := {"atk": i / 100.0}
		var names := FkFigure.layers(_spec("bow"), pose)
		var bow := names.find("bow")
		check(bow < names.find("near upper arm") and bow < names.find("near forearm"), "bow under the drawing arm at atk %.2f" % (i / 100.0))
		var j := FkSkeleton.solve(1.0, "bow", pose, "", false, FkLooks.BODIES[&"human"])
		if j.z.elbow_n > j.z.sh_n + 1.0:
			crossed = true
			check(names.find("near upper arm") > names.find("shoulder cap"), "elbow toward the viewer: upper arm over the cap at atk %.2f" % (i / 100.0))
	check(crossed, "the drawing elbow swings toward the viewer during the draw")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -20`
Expected: `test_fk_figure.gd` fails. Either `layers` and `PARTS` don't exist (script errors), or the file doesn't compile.

- [ ] **Step 3: Add `HELD_FAR` to `addons/figure_kit/weapons.gd`**

Below `const CHOP := …`:

```gdscript
## Weapons held in the far hand (drawn at its depth, under the drawing arm).
const HELD_FAR := ["bow", "starbow"]
```

- [ ] **Step 4: Rewrite `addons/figure_kit/figure.gd` lines 7–228**

Keep `arm`, `fist` and `shoulder_cap` exactly as they are. Insert the two new helpers after `arm`, replace `humanoid`, `_smear` and `_impact_accents`, and leave `_dwarf_beard`, `offset_humanoid`, `crew` and `dress` untouched.

After `arm()`:

```gdscript
## The near arm's two halves, for an arm swinging out of the picture plane: each sorts by its own depth.
static func upper_arm(ci: CanvasItem, shoulder: Vector2, elbow: Vector2, b: float, sleeve: Color, ink_boost := 0.0) -> void:
	var k := 2.6 * ink_boost * b
	FkPaint.seg(ci, shoulder, elbow, 7.8 * b + k, 7.0 * b + k, Color(0.08, 0.06, 0.05))
	FkPaint.seg(ci, shoulder, elbow, 5.4 * b, 4.6 * b, sleeve)


static func forearm(ci: CanvasItem, elbow: Vector2, hand: Vector2, hand_angle: float, b: float, skin: Color, bracer: Color, ink_boost := 0.0) -> void:
	var k := 2.6 * ink_boost * b
	FkPaint.seg(ci, elbow, hand, 7.0 * b + k, 6.0 * b + k, Color(0.08, 0.06, 0.05))
	FkPaint.seg(ci, elbow, hand, 4.6 * b, 3.8 * b, bracer)
	fist(ci, hand, hand_angle, b, skin)
```

Replace `humanoid()` with:

```gdscript
## Figure parts in today's draw order, back to front. Each frame they are sorted by depth; a tie keeps
## this order, so parts only swap where the pose really puts one in front of another.
const PARTS := ["shadow", "far leg", "near leg", "cape", "pack", "far arm", "torso", "head", "bow", "shield", "smear",
	"near upper arm", "near forearm", "shoulder cap", "weapon", "impact", "dust"]


static func humanoid(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, scale := 1.0, legs := true) -> void:
	for p in _parts(ci, st, pose, seed, scale, legs):
		(p[3] as Callable).call()


## This frame's part names, back to front: what humanoid() draws, without drawing.
static func layers(st: Dictionary, pose: Dictionary, seed := 0, scale := 1.0, legs := true) -> Array:
	return _parts(null, st, pose, seed, scale, legs).map(func(p: Array) -> String: return p[2])


## [depth, rank, name, draw] per part, sorted back to front. Depth comes from the skeleton's joints
## (j.z, + toward the viewer); rank is the part's place in PARTS.
static func _parts(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, scale: float, legs: bool) -> Array:
	var pal: Array = st.palette
	var team: Color = st.team
	var lk: Dictionary = st.look
	var body: Vector2 = lk.body
	var build: float = st.get("build", 1.0) * scale
	var mv := FkPaint.move_amount(pose)
	var t: float = pose.get("t", 0.0)
	var atk: float = pose.get("atk", -1.0)
	var skins: Array = lk.skin
	var hairs: Array = lk.hair
	var skin: Color = FkPaint.tint(skins[seed % skins.size()], pose)
	var hair: Color = FkPaint.tint(hairs[(seed / 3) % hairs.size()], pose)
	var cloth: Color = FkPaint.tint(pal[0], pose)
	var trim: Color = FkPaint.tint(pal[1], pose)
	var metal: Color = FkPaint.tint(pal[2], pose)
	var tm: Color = FkPaint.tint(team, pose)
	var helmet: String = st.get("helmet", "")
	var armoured: bool = helmet in ["crest", "kettle", "greathelm", "morion", "visor", "galea", "conical", "leaf", "dwarf", "horned", "rune"]
	var leather := FkPaint.tint(Color("4a3322"), pose)
	var weapon: String = st.get("weapon", "none")
	var shield: String = st.get("shield", "")
	# One skeleton per frame, in the race's proportions; the idle-breath phase is offset per individual.
	var j := FkSkeleton.solve(build, weapon, pose.merged({"t": t + seed / 2.1}, true), shield, not legs, lk)
	var z: Dictionary = j.z
	var hip: Vector2 = j.hip
	var sh: Vector2 = j.sh
	var b := build
	# Outline offsets and limb widths take the race's proportions (the bones already have them).
	var bb := body * b
	var hb: float = b * lk.head
	var fam: String = FkSkeleton.FAMILY.get(weapon, "idle")
	var parts := []
	var add := func(name: String, depth: float, draw: Callable) -> void:
		parts.append([depth, PARTS.find(name), name, draw])
	var nothing := func() -> void:
		pass

	var draw_shadow := func() -> void:
		if legs:
			FkPaint.shadow(ci, 12 * bb.x)
	add.call("shadow", -100.0, draw_shadow)
	# Far leg (darker), then the near one; a rider shows only the near leg, its foot in the stirrup.
	var draw_leg := func(i: int) -> void:
		if i == 1 and not legs:
			return
		var tag := "n" if i == 0 else "f"
		var root: Vector2 = j["hip_" + tag]
		var knee: Vector2 = j["knee_" + tag]
		var foot: Vector2 = j["foot_" + tag]
		var back := 0.22 if i == 1 else 0.0
		FkPaint.seg(ci, root, knee, 7.2 * bb.x, 5.4 * bb.x, trim.darkened(back))
		FkPaint.seg(ci, knee, foot, 5.4 * bb.x, 4.2 * bb.x, trim.darkened(back + 0.08))
		if armoured:
			FkPaint.seg(ci, knee.lerp(foot, 0.1), foot + Vector2(0, -2) * bb, 5.8 * bb.x, 4.8 * bb.x, metal.darkened(back))
			ci.draw_circle(knee, 3.2 * bb.x, metal.darkened(back - 0.1))
		# Boot: heel, sole and toe — pointing forward, rolling heel to toe with the stride.
		var boot := FkSkeleton.boot(foot, j["rot_" + tag], b, j["toe_bend_" + tag], body)
		FkPaint.shade_poly(ci, boot, leather.darkened(back))
		ci.draw_line(boot[5], boot[4], Color(0.08, 0.06, 0.05), 1.2 * b)
	add.call("far leg", -50.0, draw_leg.bind(1))
	add.call("near leg", -49.0, draw_leg.bind(0))
	# Cape trails behind and lags the body (secondary motion).
	var draw_cape := func() -> void:
		if st.get("cape", false) or helmet == "greathelm":
			# Riders' cloaks whip in the wind of the gait and harder on the charge.
			var flap: float = sin(t * 3.0 + seed) * 2.0 + (mv + pose.get("ride_mv", 0.0)) * 3.0 + (4.0 if atk >= 0.3 and atk < 0.75 else 0.0)
			FkPaint.shade_poly(ci, [sh + Vector2(-6, 0) * bb, sh + Vector2(2, 1) * bb, hip + Vector2(-2, 8) * bb,
				hip + Vector2(-12 - flap, 10) * bb, hip + Vector2(-9 - flap * 0.5, -2) * bb], tm.darkened(0.35))
	add.call("cape", -40.0, draw_cape)
	# The pack is laid out around the shoulder line; scaling about it gives the race's proportions.
	var draw_pack := func() -> void:
		FkPaint.push(ci, Transform2D(0.0, sh) * Transform2D(0.0, body, 0.0, Vector2.ZERO) * Transform2D(0.0, -sh))
		FkArmour.pack(ci, st.get("pack", ""), sh, sh + (hip - sh) / body, build, pal, tm, pose, t, lk)
		FkPaint.pop(ci)
	add.call("pack", -39.0, draw_pack)
	# Far arm, behind the body: counter-swings, carries the shield, or holds the bow / the weapon's haft.
	var draw_far_arm := func() -> void:
		var fs: Vector2 = j.sh_f
		var fe: Vector2 = j.elbow_f
		var fh: Vector2 = j.hand_f
		FkPaint.seg(ci, fs, fe, 5.0 * bb.x, 4.2 * bb.x, cloth.darkened(0.3))
		FkPaint.seg(ci, fe, fh, 4.2 * bb.x, 3.4 * bb.x, cloth.darkened(0.34))
		fist(ci, fh, (fh - fe).angle(), b * 0.85, skin.darkened(0.25), false)
	add.call("far arm", (z.sh_f + z.elbow_f + z.hand_f) / 3.0, draw_far_arm)
	# Torso: hips, waist, chest, shoulders.
	var draw_torso := func() -> void:
		var torso := [hip + Vector2(-6.5, 3) * bb, hip + Vector2(7, 3) * bb, hip + Vector2(6, -8) * bb, sh + Vector2(8.5, 5) * bb,
			sh + Vector2(7.5, -1.5) * bb, sh + Vector2(-7.5, -1.5) * bb, sh + Vector2(-8, 5) * bb, hip + Vector2(-5.5, -8) * bb]
		FkPaint.shade_poly(ci, torso, cloth)
		if armoured:
			# Breastplate / hauberk; Roman plate reads as horizontal bands, the rest as mail rows.
			FkPaint.shade_poly(ci, [hip + Vector2(-5.5, -5) * bb, hip + Vector2(6.5, -5) * bb, sh + Vector2(8, 4) * bb, sh + Vector2(6, -0.5) * bb,
				sh + Vector2(-6, -0.5) * bb, sh + Vector2(-7, 4) * bb], metal)
			var bands := helmet == "galea"
			for r in 4:
				var y := -1.0 - r * 3.4
				ci.draw_line(hip + Vector2(-4.5, y) * bb, hip + Vector2(6, y) * bb, Color(metal.darkened(0.45), 0.8 if bands else 0.5), (1.4 if bands else 0.8) * b)
			if helmet == "leaf":
				# Elven scale: overlapping leaf plates.
				for r in 3:
					for c in 3:
						var p := hip + Vector2(-3 + c * 3.5, -4 - r * 4.5) * bb
						ci.draw_arc(p, 2.2 * b, 0.2, PI - 0.2, 6, metal.darkened(0.3), 0.8)
		# Team tabard with a hem, belt and buckle.
		FkPaint.shade_poly(ci, [sh + Vector2(-3, 2) * bb, sh + Vector2(5, 2) * bb, hip + Vector2(5.5, 8) * bb, hip + Vector2(2, 5.5) * bb,
			hip + Vector2(-1.5, 8.5) * bb, hip + Vector2(-3.5, 2) * bb], tm)
		ci.draw_line(hip + Vector2(5.5, 8) * bb, hip + Vector2(2, 5.5) * bb, tm.darkened(0.3), 1.0 * b)
		ci.draw_line(hip + Vector2(-6, -1) * bb, hip + Vector2(6.8, -1) * bb, leather, 2.4 * b)
		ci.draw_rect(Rect2(hip + Vector2(1.2, -2.4) * bb, Vector2(2.6, 2.8) * bb), FkPaint.tint(Color("c9a45c"), pose))
		if armoured:
			# Pauldron.
			FkPaint.shade_poly(ci, FkPaint.ellipse_pts(sh + Vector2(1, 1.5) * bb, Vector2(6, 4.2) * bb, -0.2), metal.lightened(0.05))
	add.call("torso", 0.0, draw_torso)
	# Head on its neck joint, turned by its (small) tilt: long hair, neck, face, beard, helmet, ears.
	var draw_head := func() -> void:
		var head: Vector2 = j.head
		FkPaint.push(ci, Transform2D(0.0, head) * Transform2D(j.head_tilt, Vector2.ZERO) * Transform2D(0.0, -head))
		# Long hair falls behind the neck (elves), under any open helmet.
		if lk.long_hair and helmet not in ["hood", "greathelm", "visor"]:
			var sway := sin(t * 2.0 + seed) * 1.2 + mv * 1.5
			FkPaint.shade_poly(ci, [head + Vector2(-5.5, -3) * hb, head + Vector2(1, -5) * hb, head + Vector2(-1, 6) * hb,
				sh + Vector2(-5 - sway, 8) * b, sh + Vector2(-9 - sway, 5) * b, head + Vector2(-7.5, 3) * hb], hair)
		# Neck and head: skull, jaw, ear, brow, eye, nose.
		ci.draw_rect(Rect2(sh + Vector2(-0.5, -4.5) * b, Vector2(4.5, 4.5) * b), skin.darkened(0.15))
		FkPaint.shade_poly(ci, FkPaint.ellipse_pts(head, Vector2(5.4, 6.0) * hb, 0.0), skin)
		FkPaint.shade_poly(ci, [head + Vector2(-2.5, 3) * hb, head + Vector2(4.8, 2.2) * hb, head + Vector2(4.2, 5.2) * hb, head + Vector2(0.5, 6.4) * hb], skin.darkened(0.06))
		if lk.ears == "round":
			ci.draw_circle(head + Vector2(-1.4, 0.6) * hb, 1.5 * hb, skin.darkened(0.2))
		ci.draw_colored_polygon(PackedVector2Array([head + Vector2(5.0, -0.8) * hb, head + Vector2(7.0, 1.6) * hb, head + Vector2(5.0, 2.2) * hb]), skin.darkened(0.05))
		ci.draw_line(head + Vector2(2.0, -2.2) * hb, head + Vector2(4.6, -2.0) * hb, Color(0.15, 0.1, 0.07, 0.8), 0.9 * hb)
		ci.draw_circle(head + Vector2(3.4, -0.9) * hb, 0.75 * hb, Color(0.08, 0.06, 0.05))
		ci.draw_line(head + Vector2(3.2, 3.6) * hb, head + Vector2(4.6, 3.4) * hb, Color(0.3, 0.15, 0.12, 0.7), 0.7 * hb)
		var open_face := helmet not in FkArmour.ENCLOSED
		match int(lk.beard):
			1:
				if helmet not in ["greathelm", "visor"]:
					_dwarf_beard(ci, head, hb, hair, t, seed)
			3:
				if seed % 3 == 0 and helmet in ["hair", "band", "cap", "kettle", "morion", "tricorne", "brodie", "galea", "conical", "goggles"]:
					FkPaint.shade_poly(ci, [head + Vector2(-2.5, 2) * hb, head + Vector2(4.8, 2.4) * hb, head + Vector2(3.5, 6.8) * hb, head + Vector2(0.5, 7.4) * hb, head + Vector2(-2, 5) * hb], hair)
		FkArmour.helmet(ci, helmet, head, hb * 0.84, pal, tm, pose, t, seed, hair, lk)
		# Pointed ears sweep up and back past the hair or an open helm.
		if lk.ears == "pointed" and open_face:
			FkPaint.poly(ci, [head + Vector2(-0.6, 2.2) * hb, head + Vector2(-2.4, -0.6) * hb, head + Vector2(-8.5, -6.5) * hb, head + Vector2(-2.6, 2.8) * hb], skin.darkened(0.08))
			ci.draw_line(head + Vector2(-2.2, 1.0) * hb, head + Vector2(-6.8, -4.8) * hb, skin.darkened(0.25), 0.7)
		FkPaint.pop(ci)
	add.call("head", 0.5, draw_head)
	# Weapons: a bow is held in the far hand, at its own layer under the drawing arm; the rest ride on
	# the near hand, over it.
	var draw_weapon := func() -> void:
		FkWeapons.weapon(ci, weapon, j, build, FkUnits.swing(atk), atk, pal, tm, skin, pose, t, lk)
	var held_far: bool = weapon in FkWeapons.HELD_FAR
	add.call("bow", 1.0, draw_weapon if held_far else nothing)
	# The shield rides on the far hand: its drawing is laid out around sh with the grip at SHIELD_GRIP.
	# It stands in front of the chest and head at the near shoulder's depth, so the weapon arm (same
	# depth, later rank) always strikes over it.
	var draw_shield := func() -> void:
		FkArmour.shield(ci, shield, (j.hand_f as Vector2) - FkSkeleton.SHIELD_GRIP * b, build, pal, tm, team, pose, t, lk, st.get("runes", false))
	add.call("shield", z.sh_n, draw_shield)
	var draw_smear := func() -> void:
		if fam in ["blade", "chop"]:
			_smear(ci, st, pose, seed, build, weapon, not legs, metal)
	add.call("smear", z.sh_n, draw_smear)
	# Near arm: whole while it stays in the picture plane (today's strokes); split at the elbow once it
	# swings toward the viewer, so the upper arm and forearm each sort by their own depth.
	var grip: float = (j.hand_n - j.elbow_n).angle() if fam in ["idle", "crew", "bow"] else (j.dir as Vector2).angle()
	var impact := clampf(1.0 - absf(atk - 0.52) / 0.08, 0.0, 1.0) if fam in ["blade", "chop"] else 0.0
	var sleeve := cloth.lightened(0.12)
	var bracer := metal if armoured else leather
	var planar: bool = absf(z.elbow_n - z.sh_n) < 1e-3 and absf(z.hand_n - z.sh_n) < 1e-3
	var draw_upper := func() -> void:
		if planar:
			arm(ci, j.sh_n, j.elbow_n, j.hand_n, grip, b, sleeve, skin, bracer, impact)
		else:
			upper_arm(ci, j.sh_n, j.elbow_n, b, sleeve, impact)
	var draw_fore := func() -> void:
		if not planar:
			forearm(ci, j.elbow_n, j.hand_n, grip, b, skin, bracer, impact)
	add.call("near upper arm", (z.sh_n + z.elbow_n) / 2.0, draw_upper)
	add.call("near forearm", (z.elbow_n + z.hand_n) / 2.0, draw_fore)
	var draw_cap := func() -> void:
		shoulder_cap(ci, j.sh_n, j.elbow_n, b, metal.lightened(0.05) if armoured else cloth.lightened(0.05))
	add.call("shoulder cap", z.sh_n, draw_cap)
	add.call("weapon", z.hand_n + 0.01, nothing if held_far else draw_weapon)
	var draw_impact := func() -> void:
		if fam in ["blade", "chop"] and legs:
			_impact_accents(ci, j, weapon, build, atk)
	add.call("impact", 100.0, draw_impact)
	# Heavy stride: small dust puffs kicked up where a heel lands.
	var draw_dust := func() -> void:
		for tag in ["n", "f"]:
			var d: float = j["dust_" + tag]
			if d > 0.05:
				var heel: Vector2 = (j["foot_" + tag] as Vector2) + Vector2(-2, 1) * b
				for i in 3:
					var r := (1.5 + i * 0.8 + (1.0 - d) * 2.5) * b
					ci.draw_circle(heel + Vector2(-3.5 + i * 3.5, -r * 0.6), r, Color(0.72, 0.64, 0.5, 0.35 * d))
	add.call("dust", 101.0, draw_dust)
	parts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
	return parts
```

Replace `_smear()` and `_impact_accents()` with:

```gdscript
## Motion smear behind a cutting weapon: the tip's actual path over the last part of the strike,
## sampled from the skeleton, fading in toward the blade.
static func _smear(ci: CanvasItem, st: Dictionary, pose: Dictionary, seed: int, b: float, weapon: String, seated: bool, metal: Color) -> void:
	var atk: float = pose.get("atk", -1.0)
	if atk < 0.35 or atk >= 0.62:
		return
	var fade := clampf((0.62 - atk) / 0.07, 0.0, 1.0)
	var length := FkWeapons.weapon_length(weapon) * b
	var shield: String = st.get("shield", "")
	var pts := PackedVector2Array()
	for i in 9:
		var p := pose.merged({"atk": lerpf(0.33, minf(atk, 0.55), i / 8.0), "t": pose.get("t", 0.0) + seed / 2.1}, true)
		var s := FkSkeleton.solve(b, weapon, p, shield, seated, st.look)
		pts.append((s.hand_n as Vector2) + (s.dir as Vector2) * length)
	for i in pts.size() - 1:
		var u := float(i + 1) / (pts.size() - 1)
		# A crescent: thin where the cut began, full and bright at the blade.
		ci.draw_line(pts[i], pts[i + 1], Color(metal.lightened(0.55).lerp(Color.WHITE, u), 0.6 * u * fade), (1.5 + 6.0 * u) * b)


## Impact accents at the lockout: slash lines bursting from the blade along the cutting edge, and dirt
## chips kicked out from under the braced front boot.
static func _impact_accents(ci: CanvasItem, j: Dictionary, weapon: String, b: float, atk: float) -> void:
	if atk >= 0.44 and atk < 0.64:
		var u := (atk - 0.44) / 0.2
		var dir: Vector2 = j.dir
		var p: Vector2 = (j.hand_n as Vector2) + dir * FkWeapons.weapon_length(weapon) * b * 0.7
		var edge := FkWeapons.edge_normal(dir)
		for i in 5:
			var d := edge.rotated(-0.8 + i * 0.4)
			ci.draw_line(p + d * (3.0 + 6.0 * u) * b, p + d * (6.0 + 14.0 * u) * b, Color(1, 1, 0.9, 0.9 * (1.0 - u)), 1.4 * b)
	if atk >= 0.48 and atk < 0.72:
		var u := (atk - 0.48) / 0.24
		var foot: Vector2 = j.foot_n
		for i in 5:
			var q := foot + Vector2(4.0 + i * 2.2 + u * (10.0 + i * 3.0), -u * (6.0 + i * 2.5) + u * u * 9.0) * b
			ci.draw_rect(Rect2(q, Vector2(1.6, 1.3) * b), Color(0.42, 0.32, 0.22, 1.0 - u))
```

Also update the file's doc comment (lines 3–4) to: `## Human figure rig: legs, torso, head (hair, beard, ears), arms and weapon, drawn back to front by the skeleton's depth; plus the offset/crew variants used by riders and machine crews. Local space: feet at y = 0, facing +x, up is −y.`

- [ ] **Step 5: Run the tests to verify they pass**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -20`
Expected: every test passes.

If `test_standing_order_is_the_approved_order` fails, print `FkFigure.layers(...)` for the failing case, find the part whose depth breaks the tie, and fix its depth expression as the spec's table defines it. Never reorder `PARTS` to make a test pass.

- [ ] **Step 6: Smoke-render the bow close-up and the whole roster**

Run:
```bash
S="C:/Users/PERSONAL/AppData/Local/Temp/claude/E--Game-Drafts-Age-of-War/de2e4522-f256-4a88-ae25-1787b116e183/scratchpad"
timeout 60 "$G" --path . --resolution 1280x720 -s "$S/bowdiag.gd" -- "$S/bow_after.png" 2>&1 | grep -i "error" | head
timeout 90 "$G" --path . --resolution 1920x1080 -s tools/unit_gallery.gd -- --race=all --out="$S/gallery_after.png" 2>&1 | grep -i "error" | head
```
Expected: no script errors (exit 139 on quit is fine).

Open `$S/bow_after.png` next to `$S/bow_before.png` and check two things:
- the string passes under the drawing arm;
- the elbow shows over the shoulder cap mid-draw.

Open `$S/gallery_after.png` and check that the dwarves and elves are proportioned and the boots sit on the ground.

- [ ] **Step 7: Commit**

```bash
git add addons/figure_kit/figure.gd addons/figure_kit/weapons.gd tests/test_fk_figure.gd
git commit -m "figure kit: parts drawn back to front by joint depth — bow under the drawing arm, elbow over the cap; race proportions in the bones

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Owner review, stage 2 (layering)

**Files:** none in the repo. Scratch output only.

- [ ] **Step 1: Build the bow before/after strip**

```bash
cd "$S"; python -c "
from PIL import Image
for tag in ['before','after']:
    im=Image.open(f'bow_{tag}.png')
    cells=[im.crop((i*160,30,i*160+160,130)).resize((320,200),Image.NEAREST) for i in [0,2,3,4,5,7]]
    out=Image.new('RGB',(320*6,200))
    for i,c in enumerate(cells): out.paste(c,(i*320,0))
    out.save(f'bow_zoom_{tag}.png')
a,b=Image.open('bow_zoom_before.png'),Image.open('bow_zoom_after.png')
out=Image.new('RGB',(a.width,a.height*2)); out.paste(a,(0,0)); out.paste(b,(0,a.height)); out.save('bow_strip.png')"
```
Expected: `$S/bow_strip.png`, with the old draw on the top row and the new draw below.

- [ ] **Step 2: Rebuild the animation page**

```bash
rm -rf "$S/anim"
timeout 200 "$G" --path . --resolution 1280x720 -s tools/unit_anim.gd -- --out="$S/anim/frames" --frames=24
python tools/anim_page.py "$S/anim/frames" "$S/anim" "Body rig stage 2: parts layered by joint depth (bow string under the drawing arm, elbow over the shoulder cap); race proportions in the bones"
ls "$S/anim/gif" | wc -l
```
Expected: 69 GIFs.

- [ ] **Step 3: Republish to the same URL**

1. Artifact `read` on `https://claude.ai/artifact/NmKt5Dn4HPV7ArTeiv3RXm`. A publish is refused until the artifact has been read in this conversation.
2. Artifact publish with:
   - `url` = that link;
   - `file_path` = `$S/anim/index.html`;
   - `root` = `$S/anim`;
   - `files` = every `gif/*.gif` as a list of `{path: "gif/<name>.gif"}`.
3. Show the owner `bow_strip.png` (Read it into the reply) and the page link.

- [ ] **Step 4: Wait for the owner's verdict before Task 4.** If they ask for changes, make them in `figure.gd`/`skeleton.gd` with a test, then repeat this task.

---

### Task 4: Toe joint: push-off bends at the ball of the foot

Spec §3, "Ankle and toe".

**Files:**
- Modify: `addons/figure_kit/skeleton.gd` (leg loop in `solve`)
- Modify: `tests/test_fk_skeleton.gd`

**Interfaces:**
- Consumes: `boot(foot, rot, b, toe, body)`, `BALL` (Task 1). `figure.gd` already passes `j["toe_bend_" + tag]` (Task 2).
- Produces: `j.toe_bend_n` / `j.toe_bend_f` > 0 at push-off.

- [ ] **Step 1: Write the failing test and extend the sole check**

In `test_feet_roll_heel_to_toe`, change the boot call to include the toe bend:

```gdscript
			for p in FkSkeleton.boot(j["foot_" + tag], j["rot_" + tag], 1.0, j["toe_bend_" + tag]):
```

Append:

```gdscript
func test_toe_stays_down_as_the_heel_lifts() -> void:
	var best := {}
	for i in 64:
		var j := FkSkeleton.solve(1.0, "none", {"walk": TAU * i / 64.0, "move": 1.0})
		if best.is_empty() or j.rot_n > best.rot_n:
			best = j
	var pts := FkSkeleton.boot(best.foot_n, best.rot_n, 1.0, best.toe_bend_n)
	check_near(best.toe_bend_n, best.rot_n, 0.02, "toe cap lies flat at push-off")
	check(absf((pts[4] as Vector2).y) < 0.1, "toe tip on the ground (y %.2f)" % (pts[4] as Vector2).y)
	check((pts[5] as Vector2).y < -2.0, "heel lifted (y %.2f)" % (pts[5] as Vector2).y)
	for i in 64:
		var j := FkSkeleton.solve(1.0, "none", {"walk": TAU * i / 64.0, "move": 1.0})
		check(j.toe_bend_n >= 0.0 and j.toe_bend_n <= maxf(j.rot_n, 0.0) + 1e-5, "bend only while the heel is up (phase %d)" % i)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -20`
Expected: FAIL on `toe cap lies flat at push-off`, because the bend is still 0.

- [ ] **Step 3: Implement**

In `solve()`'s walking branch, directly after the `if i == 0: … else: …` block that adjusts `fx`/`lift`/`rot` for the lunge and step, and before `foot = Vector2(fx, -lift) * by`, insert:

```gdscript
			# At push-off the heel lifts while the toe cap stays flat on the ground: the foot bends at the
			# ball, straightening again as it lifts into the swing.
			flex = clampf(maxf(rot, 0.0) * (1.0 - lift / 1.5), 0.0, maxf(rot, 0.0))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -20`
Expected: every test passes. The golden still passes because standing frames have `move` 0, so `rot` is 0 and the bend is 0.

- [ ] **Step 5: Commit**

```bash
git add addons/figure_kit/skeleton.gd tests/test_fk_skeleton.gd
git commit -m "figure kit: toe joint — the foot bends at the ball on push-off, toe cap flat on the ground

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Walk counter-rotation (pelvis against chest)

Spec §3, "Walk counter-rotation".

**Files:**
- Modify: `addons/figure_kit/skeleton.gd` (`GAITS`, `yaw_p` line in `solve`)
- Modify: `tests/test_fk_skeleton.gd`

**Interfaces:**
- Consumes: `yaw_p` / `yaw_c` already wired into the hip roots and shoulders (Task 1).
- Produces: each `GAITS[...]` has `"twist"`.

- [ ] **Step 1: Write the failing tests**

Append:

```gdscript
func _corr(a: Array, c: Array) -> float:
	var ma := 0.0
	var mc := 0.0
	for i in a.size():
		ma += a[i] / a.size()
		mc += c[i] / c.size()
	var sab := 0.0
	var saa := 0.0
	var scc := 0.0
	for i in a.size():
		sab += (a[i] - ma) * (c[i] - mc)
		saa += (a[i] - ma) * (a[i] - ma)
		scc += (c[i] - mc) * (c[i] - mc)
	return sab / sqrt(saa * scc) if saa > 0.0 and scc > 0.0 else 0.0


func test_walk_counter_rotates_chest_against_pelvis() -> void:
	var fr := _walk("none", "", 32)
	var foot: Array = fr.map(func(j): return j.foot_n.x)
	check(_corr(fr.map(func(j): return (j.hip_n - j.hip).x), foot) > 0.5, "near hip rides forward with its foot")
	check(_corr(fr.map(func(j): return (j.sh_n - j.sh).x), foot) < -0.5, "near shoulder swings back against it")
	check(_spread(fr, func(j): return (j.sh_n - j.sh).x) > 1.5, "the shoulder's travel reads")
	for g in FkSkeleton.GAITS:
		check(FkSkeleton.GAITS[g].has("twist"), "%s has a twist" % g)


func test_steady_gaits_barely_twist() -> void:
	for w in ["bow", "musket"]:
		check(_spread(_walk(w), func(j): return (j.sh_n - j.sh).x) < 1.0, "%s: carriage stays steady" % w)
	check(_spread(_walk("sword", "round"), func(j): return (j.sh_n - j.sh).x) < 1.0, "shield wall: steady")


func test_head_level_while_walking() -> void:
	for w in ["none", "spear", "throwing_axe", "sling", "bow", "musket", "sword"]:
		for j in _walk(w, "round" if w == "sword" else ""):
			check(absf(j.head_tilt) < 0.1, "%s: head level on the march" % w)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -20`
Expected: FAIL on the correlation and `has a twist` checks.

- [ ] **Step 3: Implement**

(a) In `GAITS`, add `"twist"` to each gait's first line:
- `default`: `"twist": 0.35`
- `glide`: `"twist": 0.25`
- `heavy`: `"twist": 0.25`
- `bounce`: `"twist": 0.35`
- `track`: `"twist": 0.1`
- `patrol`: `"twist": 0.1`
- `wall`: `"twist": 0.1`

For example: `"default": {"bob": 2.2, "stride": 13.0, "lift": 4.5, "heel": 0.35, "toe": 0.5, "swing": 0.5, "twist": 0.35},`.

(b) Extend the GAITS doc comment: `twist = pelvis yaw at full stride (rad); the chest turns against it at 0.8.`

(c) In `solve()`, replace `var yaw_p := 0.0` with:

```gdscript
	var yaw_p: float = 0.0 if seated else g.get("twist", 0.0) * sin(walk) * mv
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -20`
Expected: every test passes, including the earlier walk-carriage tests:
- `test_rifle_patrol_low_ready`;
- `test_shield_wall_advance`;
- `test_archer_walk_relaxed_carriage`;
- `test_marching_shield_wall_keeps_the_weapon_arm_on_top`.

If an earlier carriage test fails, report it with its numbers. Lower that gait's `twist` only after the owner agrees.

- [ ] **Step 5: Commit**

```bash
git add addons/figure_kit/skeleton.gd tests/test_fk_skeleton.gd
git commit -m "figure kit: walk counter-rotation — pelvis turns with the near foot, chest against it (per-gait twist)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Owner review, stage 3 (movement), and wrap-up

- [ ] **Step 1: Full test run**

Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | tail -5`
Expected: 0 failures. The count is 121 + 8 (Task 1) + 4 (Task 2) + 1 (Task 4) + 3 (Task 5) = 137.

- [ ] **Step 2: Rebuild and republish the animation page**

Repeat Task 3 Steps 2–3 with the build note `"Body rig stage 3: walk counter-rotation (pelvis vs chest) and toe joint at push-off"`.

- [ ] **Step 3: Update the handoff pointer**

Append to `docs/superpowers/handoffs/2026-09-27-unit-body-rig.md` under a new heading `## Done (humanoid)`: one line naming the spec, the plan and the final commit. Add one line saying the next cycle is the mount rig (brief §5), which reuses `FkSkeleton.ik`/`reach` and the sorted-parts pattern in `FkFigure._parts`.

```bash
git add docs/superpowers/handoffs/2026-09-27-unit-body-rig.md
git commit -m "docs: handoff — humanoid body rig done; mount rig next

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 4: Report to the owner.** Include the test count, the page link, the bow strip, and anything left out or deferred.
