# Figure Kit — Plan 2: Melee Spacing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Opposing units stop with a visible gap between their bodies, while the same number of ranks still fight (owner's choice: "gap + same reach").

**Architecture:**
- Each `UnitDef` gets a `footprint`: the half-depth of its body in px, from centre to front edge, weapon excluded.
- The sim measures every unit-to-unit distance, and the distance to the enemy gate, from front edge instead of centre.
- `melee_contact` keeps its value (8) but now means the gap between fronts.
- Ranges are unchanged. In edge terms, who can reach whom is exactly as before.

**Tech Stack:** Godot 4.7-stable, GDScript; `data/*.tres`; balance harness `tools/sim/run_sim.gd`.

**Spec:** `docs/superpowers/specs/2026-09-27-unit-skeleton-design.md` (§3 Melee spacing). Runs after Plan 1 (`docs/superpowers/plans/2026-09-27-figure-kit-plan-1-extraction.md`); the two share no code.

## Global Constraints

- **Where things live.**
  - Stats live in `data/*.tres`, never hardcoded in scripts. Every unit `.tres` gets an explicit `footprint`.
  - `scripts/sim/` is the only place game rules live. The view only reads sim positions.
  - The sim stays deterministic.
- **Footprints (px):**

  | Units | Footprint |
  |---|---|
  | vanguard, ranged | 10 |
  | heavy (mounts, chariots, steam tank, golem, treant) | 26 |
  | siege machines | 22 |

  Races are cosmetic, so one value covers all three races' art.
- **`melee_contact` stays 8.0**, now meaning the edge gap. **`unit_spacing` (allied stacking) is unchanged.**
- **Balance rules.**
  - A balance-affecting change needs a harness run before and after.
  - Record it in `docs/balance_log.md` as row **B20**.
  - Commit `reports/sim_report.md`.
- **Godot binary (local):** `G="../Godot_v4.7/Godot_v4.7-stable_win64_console.exe"`, always under `timeout`.
- **Workspace:** `W=.superpowers/sdd/2026-09-27-figure-kit-plan-2-melee-spacing`.

## Review Focus

1. **A unit spawned right at the gate while an enemy stands at the other gate.**
   - Expected: nothing jumps backward.
   - Why it's safe: movement uses `maxf(u.progress, …)`, so a unit is never pushed back, even when its new edge limit sits behind it. Covered by the existing `test_base_damage_gives_xp`, which places a unit 10 px from the gate (inside its new stop line).
2. **Ranged units measure to the enemy's front edge.**
   - Expected: they fire up to `footprint_a + footprint_b` px sooner, which is 20 px for foot units against a range of 200+. That's a small buff.
   - Check: the harness before/after shows it. Ranged spam is already a failing target (42–55%, target < 30%), so the number is watched in B20.
3. **Ranged siege `min_range`.**
   - Expected: siege min-range checks use the same edge distance, so a catapult's dead zone shrinks by the footprints.
   - Check: the harness shows it. It's acceptable because of the "same reach" semantics.
4. **Skills, turrets and the AI are untouched.**
   - Skill zones and turret reach still use unit centres. Only unit-vs-unit and unit-vs-gate movement and targeting change.
   - Check: grep during Task 1 confirms no other unit-to-unit distance code exists.
5. **Cavalry against foot soldiers.**
   - Expected: the gap uses both footprints (26 + 10), so a horse stops short of a Vanguard's body. Covered by the mixed-pair test.

---

### Task 0: Baseline harness run

**Files:**
- Create (workspace): `$W/sim_report_before.md`

- [ ] **Step 1: Run the harness on the unchanged code.**
  Run: `timeout 1500 "$G" --headless --path . -s tools/sim/run_sim.gd -- --matches=20 > $W/harness_before.txt 2>&1; cp reports/sim_report.md $W/sim_report_before.md; git checkout reports/sim_report.md; tail -5 $W/harness_before.txt`
  Expected: the report is written. Keep the pass count (e.g. `3/8`) for B20.

---

### Task 1: Edge-to-edge distances in the sim

**Files:**
- Modify: `scripts/data/unit_def.gd`, `scripts/data/rules_def.gd` (doc only), `scripts/sim/match_sim.gd:505-545`, all 23 `data/units/*.tres`
- Test: `tests/test_combat.gd`

**Interfaces:**
- Produces: `UnitDef.footprint: float` (px, default 10.0).
- Sim semantics:
  - `dist_unit = lane − u.progress − enemy_front.progress − u.def.footprint − enemy_front.def.footprint`;
  - `dist_struct = lane − u.progress − u.def.footprint`;
  - melee press-in limits subtract the same footprints.

- [ ] **Step 1: Write the failing tests.** Append to `tests/test_combat.gd`:
  ```gdscript
  ## Front-edge gap between two opposing units (bodies, not weapons).
  func _gap(sim: MatchSim, a: SimUnit, b: SimUnit) -> float:
  	return sim.rules.lane_length - a.progress - b.progress - a.def.footprint - b.def.footprint


  func test_melee_fronts_keep_a_gap() -> void:
  	var sim := new_sim()
  	var a := place(sim, 0, "vanguard", 1100.0)
  	var b := place(sim, 1, "vanguard", 1100.0)
  	run_for(sim, 3.0)
  	check_near(_gap(sim, a, b), sim.rules.melee_contact, 0.1, "bodies stop melee_contact apart")
  	check(sim.rules.lane_length - a.progress - b.progress > a.def.footprint + b.def.footprint, "centres farther apart than the two half-bodies")
  	check(a.hp < a.max_hp and b.hp < b.max_hp, "they still fight across the gap")


  func test_cavalry_do_not_overlap() -> void:
  	var sim := new_sim()
  	var a := place(sim, 0, "heavy", 1100.0)
  	var b := place(sim, 1, "heavy", 1100.0)
  	run_for(sim, 4.0)
  	check(a.def.footprint > 20.0, "mounts are deep")
  	check_near(_gap(sim, a, b), sim.rules.melee_contact, 0.1)


  func test_mixed_pair_uses_both_footprints() -> void:
  	var sim := new_sim()
  	var a := place(sim, 0, "heavy", 1100.0)
  	var b := place(sim, 1, "vanguard", 1100.0)
  	b.hp = 1e9
  	b.max_hp = 1e9
  	run_for(sim, 4.0)
  	check_near(_gap(sim, a, b), sim.rules.melee_contact, 0.1)


  func test_ranks_in_reach_unchanged() -> void:
  	# Guard: the refactor keeps the old reach in edge terms — 4 Vanguard ranks (gap 8, spacing 6, range 30).
  	var sim := new_sim()
  	var wall := place(sim, 1, "vanguard", 1100.0)
  	wall.def = wall.def.duplicate()
  	wall.def.speed = 0.0
  	wall.hp = 1e9
  	wall.max_hp = 1e9
  	var ours: Array = []
  	for k in 6:
  		ours.append(place(sim, 0, "vanguard", 1000.0 - k * 10.0))
  	for u in ours:
  		u.hp = 1e9
  		u.max_hp = 1e9
  	run_for(sim, 6.0)
  	check_eq(ours.filter(func(u): return u.state == &"attack").size(), 4)


  func test_melee_stops_short_of_the_gate() -> void:
  	var sim := new_sim(false)
  	var v := place(sim, 0, "vanguard", sim.rules.lane_length - 200.0)
  	v.hp = 1e9
  	v.max_hp = 1e9
  	run_for(sim, 6.0)
  	check_near(sim.rules.lane_length - v.progress - v.def.footprint, sim.rules.melee_contact, 0.1, "front edge stops melee_contact from the gate")
  	check(sim.sides[1].base_hp < sim.sides[1].base_max_hp, "and hits it")
  ```

- [ ] **Step 2: Run them and watch them fail.**
  Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd > $W/t1.txt 2>&1; grep -E "FAIL|tests," $W/t1.txt`
  Expected: `test_combat.gd does not compile` (`footprint` is not a `UnitDef` member). After Step 3 adds only the field, the expected result changes:
  - `test_melee_fronts_keep_a_gap`, `test_cavalry_do_not_overlap`, `test_mixed_pair_uses_both_footprints` and `test_melee_stops_short_of_the_gate` FAIL: the bodies overlap, so the gap is negative;
  - `test_ranks_in_reach_unchanged` passes. It is a guard on existing behaviour. Record this in the ledger so it isn't mistaken for a bad test.

- [ ] **Step 3: Add the field.** In `scripts/data/unit_def.gd`, after `min_range`:
  ```gdscript
  ## Half-depth of the body in px, centre to front edge (weapon excluded). Distances between units and
  ## to the enemy gate are measured edge to edge, so bodies never overlap and ranges mean "reach".
  @export var footprint: float = 10.0
  ```
  In `scripts/data/rules_def.gd`, replace the `melee_range_max` doc line with:
  `## Units with range at or below this are melee: they press in until their front is melee_contact px from the enemy front (or gate).`
  Re-run the tests. Expected: the four failures listed in Step 2.

- [ ] **Step 4: Make the distances edge-to-edge.** In `scripts/sim/match_sim.gd`, the per-unit loop:
  ```gdscript
  		var dist_unit := INF
  		if enemy_front != null and enemy_front.alive():
  			dist_unit = lane - u.progress - enemy_front.progress - u.def.footprint - enemy_front.def.footprint
  		var dist_struct := lane - u.progress - u.def.footprint
  ```
  Movement limits in the same loop:
  ```gdscript
  			var limit := lane - rules.melee_contact - def.footprint
  			if ahead != null:
  				limit = minf(limit, ahead.progress - rules.unit_spacing)
  			if enemy_front != null and enemy_front.alive():
  				limit = minf(limit, lane - enemy_front.progress - rules.melee_contact - def.footprint - enemy_front.def.footprint)
  ```
  Update the comment above: "Melee presses in until its front is `melee_contact` from the enemy front; ranged units hold at their range."

- [ ] **Step 5: Confirm there is no other unit-to-unit distance code.**
  Run: `grep -n "lane - .*progress - .*progress\|lane_length - .*progress - .*progress" scripts/sim/*.gd scripts/ai/*.gd`
  Expected: only the two edited lines. If the AI computes a unit-vs-unit reach anywhere, rule on it in the ledger: leave threat estimates on centres, and give the reason.

- [ ] **Step 6: Set footprints in the data.**
  - Every `data/units/*.tres` gets `footprint = <value>` on the line after `min_range = …`:
    - 10.0 for `*_vanguard.tres` and `*_ranged.tres`;
    - 26.0 for `*_heavy.tres`;
    - 22.0 for `*_siege.tres`.
  - Run from `$W`:
    ```python
    import glob, io, re
    VAL = {"vanguard": 10.0, "ranged": 10.0, "heavy": 26.0, "siege": 22.0}
    for p in glob.glob("data/units/*.tres"):
        s = io.open(p, encoding="utf-8", newline="").read()
        nl = "\r\n" if "\r\n" in s else "\n"
        role = p.rsplit("_", 1)[1][:-5]
        assert "footprint" not in s, p
        s = re.sub(r"(min_range = [^\r\n]*)", r"\1" + nl + "footprint = %.1f" % VAL[role], s, count=1)
        io.open(p, "w", encoding="utf-8", newline="").write(s)
    print("ok")
    ```
  - Run: `grep -c "^footprint" data/units/*.tres | grep -v ":1"`. Expected: no output.

- [ ] **Step 7: Run the tests and the data check.**
  Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd > $W/t1.txt 2>&1; grep FAIL $W/t1.txt; tail -1 $W/t1.txt; timeout 60 "$G" --headless --path . -s tools/validate_data.gd`
  Expected: `N tests, 0 failures`, where N is the previous total + 5, and the validator passes.
  If an older combat test assumed centre distances (e.g. `test_units_meet_and_fight` "stopped in range"), check it against the spec's semantics. A test asserting `centre distance ≤ range` still holds for foot units (gap 8 + 20 ≤ 30). Any other breakage gets a ledger ruling.

- [ ] **Step 8: Commit.**
  ```bash
  git add scripts/data/unit_def.gd scripts/data/rules_def.gd scripts/sim/match_sim.gd data/units tests/test_combat.gd
  git commit -m "sim: unit footprints — melee stops a visible gap apart, reach measured edge to edge"
  ```

---

### Task 2: Balance check, log and visual confirmation

**Files:**
- Modify: `docs/balance_log.md` (row B20), `reports/sim_report.md`, and `docs/GDD.md` only if it describes contact distance.

- [ ] **Step 1: Run the harness after the change.**
  Run: `timeout 1500 "$G" --headless --path . -s tools/sim/run_sim.gd -- --matches=20 > $W/harness_after.txt 2>&1; tail -5 $W/harness_after.txt`
  Then compare these lines of `$W/sim_report_before.md` and `reports/sim_report.md`: pass count, mirror length, escalation %, Age 6 time, and the Ranged, Heavy and Vanguard spam win rates.
  Expected: within noise, about ±5 points per target. If Ranged spam rises more than 5 points, stop and report it. The spec assumed "balance should barely move", so a real shift is the owner's call.

- [ ] **Step 2: Log B20.** Add a row after B19 in `docs/balance_log.md`:
  `| B20 | Unit footprints (foot 10, heavy 26, siege 22 px); unit-to-unit and unit-to-gate distances measured edge to edge; melee_contact 8 = gap between fronts | Owner: units should not touch so the swing-and-hit reads. Ranges unchanged, so the same ranks fight (guard test: 4 Vanguard ranks). Harness 20 matches seed 1: <before> → <after> pass; <list the moved targets with before → after> |`
  Fill in the real numbers.

- [ ] **Step 3: Check the GDD.** Run `grep -n "contact\|press in\|touch" docs/GDD.md`. If it states melee stops at contact, add one sentence: units stop with a small gap between their fronts, and footprint is data. Otherwise change nothing.

- [ ] **Step 4: Visual confirmation.**
  Run: `timeout 150 "$G" --path . --resolution 1600x900 -- --autoplay --speed=3 --start-age=4 --screenshot=$W/clash.png --after=40`. The segfault on quit is known.
  Crop the melee clash with Pillow at 4× nearest-neighbour and look at it.
  Expected: opposing bodies don't overlap, and there's a visible sliver of gap. The owner reviews locally.

- [ ] **Step 5: Commit.**
  ```bash
  git add docs/balance_log.md reports/sim_report.md docs/GDD.md
  git commit -m "balance: B20 unit footprints — harness before/after"
  ```
