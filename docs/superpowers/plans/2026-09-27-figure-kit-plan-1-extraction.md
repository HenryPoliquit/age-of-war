# Figure Kit — Plan 1: Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move everything that draws a unit out of `scripts/view/art/unit_art.gd` into a self-contained, copyable kit at `addons/figure_kit/`, with zero visual change.

**Architecture:** The move is mechanical and scripted, with call-site renames. It is proven by pixel-identical gallery renders before and after, plus the test suite. `UnitArt` becomes a thin adapter that maps `UnitDef` + race to a kit `spec` Dictionary. A boundary test keeps the kit free of game classes.

**Tech Stack:** Godot 4.7-stable, GDScript. Python 3 + Pillow (local) for the image diff.

**Spec:** `docs/superpowers/specs/2026-09-27-unit-skeleton-design.md` (§0 Figure kit). Plan 2 (melee spacing) and Plan 3 (skeleton) follow it.

## Global Constraints

- **Dependencies:** the kit depends only on Godot built-ins. No file under `addons/figure_kit/` may name a game `class_name`. This includes comments.
- **Naming:**
  - Every kit class is `Fk`-prefixed: `FkPaint`, `FkLooks`, `FkUnits`, `FkFigure`, `FkArmour`, `FkWeapons`, `FkMounts`, `FkMachines`.
  - Kit helpers used across files are public (no leading `_`). Helpers used only in their own file stay `_private`.
- **Spec contract:** the style keys plus `look` (race body preset Dictionary), `palette` (`[cloth, trim, metal]`) and `team` (Color). The pose contract is unchanged: `walk`, `move`/`moving`, `atk`, `t`, `flash`.
- **No visual change** in this plan. Every task ends with all 10 golden renders pixel-identical to the baseline.
- **Adapter API:** `UnitArt` keeps `style_for`, `draw_unit`, `height_for`, `muzzle_for`, `wreck_kind` and `RIGS` with the same signatures.
- **Godot binary (local):** `G="../Godot_v4.7/Godot_v4.7-stable_win64_console.exe"`. Always wrap it in `timeout`.
- **Class registration:** after adding a `class_name` script, run `timeout 100 "$G" --headless --path . --import` once.
- **Branch:** `art/readable-arms`.

## Review Focus

1. **Hidden static state across draws.**
   - Risk: `FkPaint`'s transform stack and `FkUnits.look` are statics.
   - Check: drawing an elf unit, then a human unit, in one frame gives the human its human look (the dwarf/elf proportions don't leak). Covered by golden `--race=all`, which draws three races in one pass.
2. **Callers outside the unit renderer.**
   - Risk: `base_art.gd`, `tower_art.gd` and `fx_layer.gd` use the primitives, and `fx_layer.gd` uses `quadruped` for stampede beasts.
   - Check: bases, towers and FX render unchanged. The base goldens cover the first two; an in-game screenshot smoke run covers FX.
3. **Specs built inside the kit.**
   - Risk: crews and chariot drivers build their own small spec.
   - Check: they still get the parent's race look and palette. Covered by the siege and chariot goldens.
4. **Dwarf Arcane shield glow.**
   - Risk: it was keyed on a palette comparison with a game class.
   - Check: it now comes from a style flag and still appears only on the dwarf Arcane Vanguard (golden `--race=dwarf`).
5. **Copyability.**
   - Risk: kit code depends on the game.
   - Check: the kit contains no game class name, not even in doc comments (boundary test).

---

### Task 0: Golden renders and diff tooling

**Files:**
- Modify: `tools/base_gallery.gd` (render into a 1920×1080 SubViewport, same pattern as `tools/unit_gallery.gd`)
- Create (workspace, git-ignored): `.superpowers/sdd/2026-09-27-figure-kit-plan-1-extraction/render_all.sh`, `imgdiff.py`, `baseline/*.png`

- [ ] **Step 1: Make the base gallery screen-size independent.** In `tools/base_gallery.gd`:
  - add `var vp := SubViewport.new()` after `var towers := false`;
  - at the top of `_initialize()`, add:
    ```gdscript
    	# Fixed-size offscreen canvas: the window gets clamped to smaller screens.
    	vp.size = Vector2i(1920, 1080)
    	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    	root.add_child(vp)
    ```
  - change `root.add_child(bg)` → `vp.add_child(bg)`, `root.add_child(n)` → `vp.add_child(n)`, and `root.get_texture()` → `vp.get_texture()`.

- [ ] **Step 2: Write the render script** `render_all.sh`:
  ```sh
  #!/bin/sh
  # Usage: render_all.sh OUTDIR — renders the 10 golden images.
  G="../Godot_v4.7/Godot_v4.7-stable_win64_console.exe"
  O="$1"; mkdir -p "$O"
  u() { timeout 90 "$G" --path . --resolution 1920x1080 -s tools/unit_gallery.gd -- "$@" 2>&1 | grep -iE "SCRIPT ERROR|error:" ; }
  b() { timeout 90 "$G" --path . --resolution 1920x1080 -s tools/base_gallery.gd -- "$@" 2>&1 | grep -iE "SCRIPT ERROR|error:" ; }
  u --out="$O/u_human.png"
  u --race=elf --out="$O/u_elf.png"
  u --race=dwarf --out="$O/u_dwarf.png"
  u --race=all --out="$O/u_all.png"
  u --race=all --atk=0.25 --out="$O/u_all_wind.png"
  u --race=all --atk=0.45 --out="$O/u_all_strike.png"
  u --race=all --atk=0.8 --out="$O/u_all_recover.png"
  b --out="$O/b_bases.png"
  b --towers --out="$O/b_towers.png"
  b --night=1 --out="$O/b_night.png"
  ls "$O" | wc -l
  ```

- [ ] **Step 3: Write the diff tool** `imgdiff.py`:
  ```python
  import sys, os
  from PIL import Image, ImageChops
  a_dir, b_dir = sys.argv[1], sys.argv[2]
  bad = 0
  for f in sorted(os.listdir(a_dir)):
      a = Image.open(os.path.join(a_dir, f)).convert("RGBA")
      b = Image.open(os.path.join(b_dir, f)).convert("RGBA")
      box = None if a.size != b.size else ImageChops.difference(a, b).getbbox()
      same = a.size == b.size and box is None
      bad += not same
      print(("IDENTICAL " if same else f"DIFF {box} ") + f)
  print(f"{bad} differing")
  sys.exit(1 if bad else 0)
  ```

- [ ] **Step 4: Render the baseline twice and prove rendering is deterministic.**
  Run: `W=.superpowers/sdd/2026-09-27-figure-kit-plan-1-extraction; sh $W/render_all.sh $W/baseline; sh $W/render_all.sh $W/check; python $W/imgdiff.py $W/baseline $W/check`
  Expected: `10`, `10`, then `0 differing`. If two runs of the same code differ, stop. The pixel-identity proof doesn't work on this machine; record a ruling and use a per-channel tolerance of ≤ 2 instead.

- [ ] **Step 5: Commit.**
  ```bash
  git add tools/base_gallery.gd
  git commit -m "tools: base gallery renders into a 1920x1080 SubViewport"
  ```

---

### Task 1: `FkPaint` primitives and the boundary test

**Files:**
- Create: `addons/figure_kit/paint.gd`, `tests/test_fk_boundary.gd`
- Modify: `scripts/view/art/unit_art.gd`, `scripts/view/art/base_art.gd`, `scripts/view/art/tower_art.gd`, `scripts/view/fx_layer.gd`, `scripts/view/world_layer.gd`, `scripts/view/main.gd`, `scripts/view/hud/lane_panel.gd`, `scripts/view/hud/unit_bar.gd`, `tools/unit_gallery.gd`, `tools/base_gallery.gd`

**Interfaces:**
- Produces:
  - `FkPaint.begin(ci, xf: Transform2D)`, `push(ci, local: Transform2D)`, `pop(ci)`
  - `move_amount(pose) -> float` (was `_mv`), `tint(col, pose) -> Color` (was `_c`)
  - `limb`, `ellipse`, `poly`, `shade_poly`, `ellipse_pts`, `seg`, `wheel`, `shadow`, `rivets`, `halo`

  All keep the same parameters as the `UnitArt._x` originals.

- [ ] **Step 1: Write the failing boundary test** `tests/test_fk_boundary.gd`:
  ```gdscript
  extends TestCase
  ## The figure kit must drop into another project: nothing under addons/figure_kit/ may name a class
  ## defined outside it (comments included — a copied kit must not point at code that isn't there).

  const KIT := "res://addons/figure_kit/"


  func test_kit_names_no_game_class() -> void:
  	var files := Array(DirAccess.get_files_at(KIT)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
  	check(files.size() >= 1, "the kit has scripts")
  	var game: Array[String] = []
  	for c in ProjectSettings.get_global_class_list():
  		if not String(c.path).begins_with(KIT):
  			game.append(String(c["class"]))
  	for f in files:
  		var src := FileAccess.get_file_as_string(KIT + f)
  		for name in game:
  			check(RegEx.create_from_string("\\b%s\\b" % name).search(src) == null, "%s names game class %s" % [f, name])
  ```

- [ ] **Step 2: Run it and watch it fail.**
  Run: `timeout 300 "$G" --headless --path . -s tests/run_tests.gd 2>&1 | grep -A2 test_fk_boundary`
  Expected: `FAIL test_fk_boundary::test_kit_names_no_game_class`, with `the kit has scripts`.

- [ ] **Step 3: Create `addons/figure_kit/paint.gd`.**
  - Header:
    ```gdscript
    class_name FkPaint
    extends RefCounted
    ## Canvas primitives shared by every figure-kit drawing: a transform stack over
    ## draw_set_transform_matrix, shaded polygons and tapered limbs. Local space: +x forward, up is −y.
    ```
  - Move these verbatim from `unit_art.gd`, renamed:

    | From `unit_art.gd` | To `FkPaint` |
    |---|---|
    | `_mv` | `move_amount` |
    | `_c` | `tint` |
    | `_limb` | `limb` |
    | `_ellipse` | `ellipse` |
    | `_poly` | `poly` |
    | `_shade_poly` | `shade_poly` |
    | `_ellipse_pts` | `ellipse_pts` |
    | `_seg` | `seg` |
    | `_wheel` | `wheel` |
    | `_shadow` | `shadow` |
    | `_rivets` | `rivets` |
    | `_halo` | `halo` |
    | `begin` | `begin` |
    | `_push` | `push` |
    | `_pop` | `pop` |

  - Also move `static var _stack` and `static var _current`, with their doc comments. They stay private.
  - Inside `paint.gd`, `shadow` calls `ellipse(`.
  - Delete these definitions from `unit_art.gd`.

- [ ] **Step 4: Re-point every caller** with the workspace script `rename_paint.py`:
  ```python
  import re, glob, io
  MAP = {"_mv": "move_amount", "_c": "tint", "_limb": "limb", "_ellipse": "ellipse", "_poly": "poly",
         "_shade_poly": "shade_poly", "_ellipse_pts": "ellipse_pts", "_seg": "seg", "_wheel": "wheel",
         "_shadow": "shadow", "_rivets": "rivets", "_halo": "halo", "begin": "begin", "_push": "push", "_pop": "pop"}
  files = ["scripts/view/art/unit_art.gd", "scripts/view/art/base_art.gd", "scripts/view/art/tower_art.gd",
           "scripts/view/fx_layer.gd", "scripts/view/world_layer.gd", "scripts/view/main.gd",
           "scripts/view/hud/lane_panel.gd", "scripts/view/hud/unit_bar.gd", "tools/unit_gallery.gd", "tools/base_gallery.gd"]
  for p in files:
      s = io.open(p, encoding="utf-8", newline="").read()
      o = s
      for old, new in MAP.items():
          # UnitArt._x( → FkPaint.x(  (other files)
          s = re.sub(r"\bUnitArt\." + re.escape(old) + r"\(", "FkPaint." + new + "(", s)
          if p.endswith("unit_art.gd"):
              # bare calls inside unit_art.gd; never touch "func _x(" (already moved) or strings
              s = re.sub(r"(?<![\w.])" + re.escape(old) + r"\(", "FkPaint." + new + "(", s)
      if s != o:
          io.open(p, "w", encoding="utf-8", newline="").write(s)
          print("updated", p)
  ```
  Run it. Then check that nothing is left behind:
  `grep -rnE "UnitArt\.(_mv|_c|_limb|_ellipse|_poly|_shade_poly|_ellipse_pts|_seg|_wheel|_shadow|_rivets|_halo|begin|_push|_pop)\(" scripts tools`
  Expected: no output.

- [ ] **Step 5: Register the class and run the tests.**
  Run: `timeout 100 "$G" --headless --path . --import > /dev/null 2>&1; timeout 300 "$G" --headless --path . -s tests/run_tests.gd > $W/t1.txt 2>&1; tail -1 $W/t1.txt`
  Expected: `71 tests, 0 failures`.

- [ ] **Step 6: Check the goldens.**
  Run: `sh $W/render_all.sh $W/now && python $W/imgdiff.py $W/baseline $W/now`
  Expected: no script errors and `0 differing`.

- [ ] **Step 7: Commit.**
  ```bash
  git add addons/figure_kit/paint.gd tests/test_fk_boundary.gd scripts tools
  git commit -m "figure kit: FkPaint primitives + kit boundary test"
  ```

---

### Task 2: `FkLooks` presets

**Files:**
- Create: `addons/figure_kit/looks.gd`
- Modify: `scripts/view/art/race_look.gd`, `scripts/view/art/unit_art.gd`

**Interfaces:**
- Produces:
  - `FkLooks.BODIES: Dictionary` (StringName race → body preset; the exact contents of today's `RaceLook.BODY`)
  - `FkLooks.PALETTES: Dictionary` (StringName race → Array of 6 era palettes; the exact contents of `RaceLook.CLOTH`)
- `RaceLook.look(race)` and `RaceLook.palette(race, age)` keep their signatures and return the same values.

- [ ] **Step 1: Write the failing test.** Append to `tests/test_fk_boundary.gd`:
  ```gdscript
  func test_race_look_reads_kit_presets() -> void:
  	for race in RaceLook.IDS:
  		check(RaceLook.look(race) == FkLooks.BODIES[race], "%s body from the kit" % race)
  		check(RaceLook.palette(race, 3) == FkLooks.PALETTES[race][2], "%s palette from the kit" % race)
  ```

- [ ] **Step 2: Run it.** Expected: the file fails to compile (`FkLooks` is not declared), so `test_fk_boundary.gd does not compile`.

- [ ] **Step 3: Create `addons/figure_kit/looks.gd`.**
  - Header:
    ```gdscript
    class_name FkLooks
    extends RefCounted
    ## Preset library. BODIES: per-race proportions (body scale x/y, head scale), beard style, ears,
    ## long hair, skin and hair colour pools, magic glow. PALETTES: per race, six era palettes of
    ## [main cloth, secondary/trim, metal] — Stone, Bronze, Iron, Medieval, Gunpowder, Arcane.
    ```
  - Move the `BODY` const body verbatim as `const BODIES := {...}`, and the `CLOTH` const body verbatim as `const PALETTES := {...}`, keeping their comments.
  - In `race_look.gd`:
    - delete `BODY` and `CLOTH`;
    - make `look()` return `FkLooks.BODIES.get(race, FkLooks.BODIES[&"human"])`, keeping the current fallback semantics exactly as written in `look()` today and only swapping `BODY` → `FkLooks.BODIES`;
    - make `palette()` index `FkLooks.PALETTES` the same way.
  - In `unit_art.gd`:
    - `RaceLook.CLOTH[&"human"]` → `FkLooks.PALETTES[&"human"]`;
    - `RaceLook.BODY[&"human"]` → `FkLooks.BODIES[&"human"]`.
  - Then run `grep -rn "RaceLook\.\(BODY\|CLOTH\)" scripts tools tests`. Expected: no output.

- [ ] **Step 4: Import and run the tests.** Expected: `72 tests, 0 failures`.

- [ ] **Step 5: Goldens.** Expected: `0 differing`.

- [ ] **Step 6: Commit.**
  ```bash
  git add addons/figure_kit/looks.gd scripts/view/art tests/test_fk_boundary.gd
  git commit -m "figure kit: FkLooks race body and era palette presets"
  ```

---

### Task 3: Move every rig into the kit (scripted split)

**Files:**
- Create: `addons/figure_kit/units.gd`, `figure.gd`, `armour.gd`, `weapons.gd`, `mounts.gd`, `machines.gd`; `tests/test_fk_units.gd`
- Modify: `scripts/view/art/unit_art.gd` (becomes the adapter), `scripts/view/art/race_look.gd` (one style flag), `scripts/view/fx_layer.gd`

**Interfaces:**
- Consumes: `FkPaint.*` (Task 1), `FkLooks.*` (Task 2).
- Produces:
  - `FkUnits.RIGS`
  - `FkUnits.swing(atk) -> float`
  - `FkUnits.draw(ci, spec: Dictionary, pose: Dictionary, seed := 0)`
  - `FkUnits.height(spec) -> float`, `muzzle(spec) -> Vector2`, `wreck(spec) -> String`, `shot(spec) -> String`
  - `static var FkUnits.look` (temporary; removed in Task 4)
  - `FkFigure.humanoid`, `arm`, `offset_humanoid`, `crew`
  - `FkArmour.ENCLOSED`, `pack`, `helmet`, `shield`
  - `FkWeapons.CHOP`, `SHOTS`, `weapon`
  - `FkMounts.BEASTS`, `quadruped`, `mounted`, `chariot`
  - `FkMachines.wood`, `ram`, `catapult`, `ballista`, `trebuchet`, `cannon`, `steamtank`, `golem`, `treant`, `skycannon`, `obelisk`

  Rig signatures are unchanged in this task.

- [ ] **Step 1: Write the failing kit API test** `tests/test_fk_units.gd`:
  ```gdscript
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
  ```

- [ ] **Step 2: Run it.** Expected: `test_fk_units.gd does not compile` (`FkUnits` is not declared).

- [ ] **Step 3: Write and run the split script** `$W/split_rigs.py`. It moves each function or const block verbatim into its kit file, then renames call sites. A function name is only renamed when followed by `(`, so string keys like `"ram"` are untouched. Constants are ALL-CAPS and never appear in strings.
  ```python
  import re, io
  P = "scripts/view/art/unit_art.gd"
  raw = io.open(P, encoding="utf-8", newline="").read()
  crlf = "\r\n" in raw
  src = raw.replace("\r\n", "\n")
  # symbol -> (kit class, new name); a new name starting with "_" stays private to its file
  HOME = {
      "RIGS": ("FkUnits", "RIGS"), "swing": ("FkUnits", "swing"),
      "humanoid": ("FkFigure", "humanoid"), "_dwarf_beard": ("FkFigure", "_dwarf_beard"), "_arm": ("FkFigure", "arm"),
      "_offset_humanoid": ("FkFigure", "offset_humanoid"), "_crew": ("FkFigure", "crew"),
      "ENCLOSED": ("FkArmour", "ENCLOSED"), "_pack": ("FkArmour", "pack"), "_helmet": ("FkArmour", "helmet"), "_shield": ("FkArmour", "shield"),
      "CHOP": ("FkWeapons", "CHOP"), "SHOTS": ("FkWeapons", "SHOTS"), "_weapon": ("FkWeapons", "weapon"),
      "BEASTS": ("FkMounts", "BEASTS"), "quadruped": ("FkMounts", "quadruped"), "_antlers": ("FkMounts", "_antlers"),
      "mounted": ("FkMounts", "mounted"), "_rider": ("FkMounts", "_rider"), "chariot": ("FkMounts", "chariot"),
      "_wood": ("FkMachines", "wood"), "ram": ("FkMachines", "ram"), "catapult": ("FkMachines", "catapult"),
      "ballista": ("FkMachines", "ballista"), "trebuchet": ("FkMachines", "trebuchet"), "cannon": ("FkMachines", "cannon"),
      "steamtank": ("FkMachines", "steamtank"), "golem": ("FkMachines", "golem"), "treant": ("FkMachines", "treant"),
      "skycannon": ("FkMachines", "skycannon"), "obelisk": ("FkMachines", "obelisk"),
  }
  FILES = {"FkUnits": "units", "FkFigure": "figure", "FkArmour": "armour", "FkWeapons": "weapons", "FkMounts": "mounts", "FkMachines": "machines"}
  # 1. cut blocks: a top-level block runs from its "static func"/"const" line (plus the ## doc lines
  #    directly above) to the next top-level line that is not indented/blank/comment-continuation.
  lines = src.split("\n")
  def block_span(name):
      pat = re.compile(r"^(static func %s\(|const %s\b)" % (re.escape(name), re.escape(name)))
      i = next(k for k, l in enumerate(lines) if pat.match(l))
      a = i
      while a > 0 and lines[a - 1].startswith("##"):
          a -= 1
      b = i + 1
      while b < len(lines) and (lines[b] == "" or lines[b][0] in "\t)]}" or lines[b].startswith("\t")):
          b += 1
      while lines[b - 1] == "":
          b -= 1
      return a, b
  out = {c: [] for c in FILES}
  spans = sorted((block_span(n), n) for n in HOME)
  for (a, b), n in spans:
      out[HOME[n][0]].append("\n".join(lines[a:b]))
  keep = [l for k, l in enumerate(lines) if not any(a <= k < b for (a, b), _ in spans)]
  adapter = re.sub(r"\n{3,}", "\n\n\n", "\n".join(keep))
  # 2. rename inside each kit file and in the adapter
  def rename(text, own):
      for n, (cls, new) in HOME.items():
          call = n not in ("RIGS", "ENCLOSED", "CHOP", "SHOTS", "BEASTS")
          pat = r"(?<![\w.])" + re.escape(n) + (r"(?=\()" if call else r"\b")
          text = re.sub(pat, new if cls == own else cls + "." + new, text)
      return re.sub(r"(?<![\w.])_look\b", "look" if own == "FkUnits" else "FkUnits.look", text)
  for cls, name in FILES.items():
      body = rename("\n\n\n".join(out[cls]), cls)
      body = body.replace("static func " + cls + ".", "static func ")  # never qualify a definition
      io.open(f"addons/figure_kit/{name}.gd", "w", encoding="utf-8", newline="").write(body + "\n")
  adapter = rename(adapter, "UnitArt")
  io.open(P, "w", encoding="utf-8", newline="").write(adapter.replace("\n", "\r\n") if crlf else adapter)
  print("ok")
  ```
  After running it, `git diff --stat` should show `unit_art.gd` shrinking by about 1,350 lines, and six new kit files.

- [ ] **Step 4: Hand-finish the kit files** (the script can't do these):
  - **Headers.** Give each file its header: `class_name FkX`, `extends RefCounted`, and a `##` doc line naming what it draws. The doc lines must not mention any game class.
  - **`units.gd` additions**, from the adapter's old code:
    ```gdscript
    ## Race body preset of the figure being drawn. Set by draw() from spec.look for the duration of one
    ## draw call (removed in the next refactor step — everything will read spec.look).
    static var look: Dictionary = FkLooks.BODIES[&"human"]


    ## Draws one unit at the current FkPaint transform. spec = style keys + look, palette, team.
    static func draw(ci: CanvasItem, spec: Dictionary, pose: Dictionary, seed: int = 0) -> void:
    	look = spec.get("look", FkLooks.BODIES[&"human"])
    	var pal: Array = spec.palette
    	var team: Color = spec.team
    	match spec.rig:
    		# … the exact match block from the old draw_unit, with st → spec and rig calls qualified
    		# (FkFigure.humanoid, FkMounts.mounted / chariot, FkMachines.ram / catapult / …)
    	look = FkLooks.BODIES[&"human"]


    static func height(spec: Dictionary) -> float:
    	var h: float = RIGS.get(spec.rig, {}).get("h", 50.0)
    	var body: Vector2 = spec.get("look", FkLooks.BODIES[&"human"]).body
    	if spec.rig == "humanoid":
    		return h * body.y
    	if spec.rig == "mounted":
    		return h + (body.y - 1.0) * 40.0
    	return h


    ## Muzzle in unit-local space (feet origin, facing +x).
    static func muzzle(spec: Dictionary) -> Vector2:
    	return spec.get("muzzle", RIGS.get(spec.rig, {}).get("muzzle", Vector2(22, -34)))


    ## "blast", "siege" or "" (a body that falls over).
    static func wreck(spec: Dictionary) -> String:
    	return RIGS.get(spec.rig, {}).get("wreck", "")


    ## Projectile the unit fires ("" = melee): an explicit spec.shot, else its hand weapon's, else its rig's.
    static func shot(spec: Dictionary) -> String:
    	if spec.has("shot"):
    		return spec.shot
    	var info: Dictionary = RIGS.get(spec.rig, {})
    	return FkWeapons.SHOTS.get(spec.get("weapon", ""), info.get("shot", "")) if spec.rig == "humanoid" else info.get("shot", "")
    ```
    Write the `match` block out in full; the comment above is only a pointer for this plan.
  - **Dwarf rune glow (`armour.gd`).** In `shield()`, replace `if pal == RaceLook.palette(&"dwarf", 6):` with `if runes:`, add a trailing parameter `runes := false`, and have `FkFigure.humanoid` pass `st.get("runes", false)`. In `race_look.gd`, add `"runes": true` to the dwarf `&"arcane_vanguard"` style entry.
  - **Leftover game references.** Run `grep -n "RaceLook\|UnitDef\|GameData\|UnitArt" addons/figure_kit/*.gd`. Expected: no output.

- [ ] **Step 5: Rewrite the adapter tail in `unit_art.gd`.** First delete the leftover `static var _look` line (the script turned it into invalid `static var FkUnits.look`) and the old `draw_unit` body. What's left after the script is the doc, `AGE_CLOTH`, `ROLE_FALLBACK`, `ROLE_BUILD`, `_style_cache` and the functions below. Make them delegate:
  ```gdscript
  ## Per-rig facts (visual height, projectile, muzzle, wreck) live in the kit.
  const RIGS := FkUnits.RIGS


  static func style_for(def: UnitDef, race: StringName = &"human") -> Dictionary:
  	# unchanged, except the shot line:
  	if not st.has("shot"):
  		st["shot"] = FkUnits.shot(st)


  static func height_for(def: UnitDef, race: StringName = &"human") -> float:
  	return FkUnits.height(style_for(def, race).merged({"look": RaceLook.look(race)}))


  static func muzzle_for(st: Dictionary) -> Vector2:
  	return FkUnits.muzzle(st)


  static func wreck_kind(st: Dictionary) -> String:
  	return FkUnits.wreck(st)


  static func draw_unit(ci: CanvasItem, def: UnitDef, team: Color, pose: Dictionary, seed: int = 0, race: StringName = &"human") -> void:
  	FkUnits.draw(ci, style_for(def, race).merged({"look": RaceLook.look(race), "palette": RaceLook.palette(race, def.age), "team": team}), pose, seed)
  ```
  - Update the file's doc comment: `UnitArt` is now the adapter from `UnitDef` + race to a figure-kit spec.
  - `AGE_CLOTH` has no callers (`grep -rn AGE_CLOTH`). Leave it pointing at `FkLooks.PALETTES[&"human"]` and mention it in the task report as dead code.

- [ ] **Step 6: Point `fx_layer.gd` at the kit.** Change `UnitArt.quadruped(` to `FkMounts.quadruped(`.

- [ ] **Step 7: Import and run the tests.**
  Run: `timeout 100 "$G" --headless --path . --import > /dev/null 2>&1; timeout 300 "$G" --headless --path . -s tests/run_tests.gd > $W/t3.txt 2>&1; grep FAIL $W/t3.txt; tail -1 $W/t3.txt`
  Expected: `75 tests, 0 failures`. The boundary test is included and must pass.

- [ ] **Step 8: Goldens and an in-game smoke run.**
  Run: `sh $W/render_all.sh $W/now && python $W/imgdiff.py $W/baseline $W/now`
  Expected: `0 differing`.
  Run: `timeout 150 "$G" --path . --resolution 1600x900 -- --autoplay --speed=3 --start-age=2 --screenshot=$W/smoke.png --after=30 2>&1 | grep -i "SCRIPT ERROR"`
  Expected: no output. The segfault on quit after `--screenshot` is known and pre-existing.

- [ ] **Step 9: Commit.**
  ```bash
  git add addons/figure_kit tests/test_fk_units.gd scripts
  git commit -m "figure kit: move every rig into addons/figure_kit; UnitArt becomes the adapter"
  ```

---

### Task 4: The race look travels in the spec (remove the `FkUnits.look` static)

**Files:**
- Modify: `addons/figure_kit/units.gd`, `figure.gd`, `armour.gd`, `weapons.gd`, `mounts.gd`, `machines.gd`; `tests/test_fk_units.gd`

**Interfaces:**
- Consumes: Task 3's kit.
- Produces:
  - Every rig is `func rig(ci: CanvasItem, spec: Dictionary, pose: Dictionary, seed: int)`, with `humanoid` adding `scale := 1.0, legs := true`.
  - Rigs read `spec.palette`, `spec.team` and `spec.look` themselves.
  - `FkFigure.dress(spec: Dictionary, extra: Dictionary) -> Dictionary` returns `extra` plus the parent's `look`/`palette`/`team`. It is used for crews and chariot drivers.
  - Helpers take the look explicitly:
    - `FkArmour.pack(..., t, lk)`;
    - `helmet(..., hair, lk)`;
    - `shield(..., t, lk, runes := false)`;
    - `FkWeapons.weapon(..., t, lk, armoured := false)`.
  - `FkUnits.draw` is a plain dispatch.

- [ ] **Step 1: Write the failing test.** Append to `tests/test_fk_units.gd`:
  ```gdscript
  func test_kit_has_no_hidden_draw_state() -> void:
  	var src := FileAccess.get_file_as_string("res://addons/figure_kit/units.gd")
  	check(not src.contains("static var look"), "the race look is passed in the spec, not held in a static")
  	var figure := FileAccess.get_file_as_string("res://addons/figure_kit/figure.gd")
  	check(figure.contains("static func dress("), "crews inherit the parent's look through dress()")
  ```
  Run it. Expected: `FAIL … test_kit_has_no_hidden_draw_state`.

- [ ] **Step 2: Normalise the rig signatures** and thread the look.

  | Function | Before | After |
  |---|---|---|
  | `FkFigure.humanoid` | `(ci, st, pal, team, pose, seed, scale, legs)` | `(ci, spec, pose, seed, scale := 1.0, legs := true)`; first lines `var pal: Array = spec.palette`, `var team: Color = spec.team`, `var lk: Dictionary = spec.look` (replaces `var lk := FkUnits.look`) |
  | `FkFigure.offset_humanoid` | `(ci, st, pal, team, pose, seed, offset)` | `(ci, spec, pose, seed, offset)` |
  | `FkFigure.crew` | `(ci, st, pal, team, pose, seed, at, weapon)` | `(ci, spec, pose, seed, at, weapon := "crew")`; calls `humanoid(ci, dress(spec, {"helmet": spec.get("crew", "cap"), "weapon": weapon}), pose, seed)` |
  | `FkMounts._rider` | `(ci, st, pal, team, pose, seed, at)` | `(ci, spec, pose, seed, at)` |
  | `FkMounts.chariot` | its `offset_humanoid(ci, {"helmet": …, "weapon": …}, pal, team, …)` | `offset_humanoid(ci, FkFigure.dress(spec, {"helmet": …, "weapon": …}), pose, seed, …)` |
  | `mounted`, `ram`, `catapult`, `ballista`, `trebuchet`, `cannon`, `obelisk` | `(ci, st, pal, team, pose, seed)` | `(ci, spec, pose, seed)`, deriving `pal`/`team` locally where used |
  | `steamtank`, `golem`, `skycannon` | `(ci, _pal, team, pose)` | `(ci, spec, pose, _seed)` |
  | `treant` | `(ci, team, pose, seed)` | `(ci, spec, pose, seed)` |

  Also:
  - replace every `FkUnits.look` with the local `lk` (humanoid helpers) or `spec.look` (machines);
  - `dress()`:
    ```gdscript
    ## A sub-figure (crew, driver) wearing `extra`'s gear in the parent's race look and colours.
    static func dress(spec: Dictionary, extra: Dictionary) -> Dictionary:
    	return extra.merged({"look": spec.look, "palette": spec.palette, "team": spec.team})
    ```
  - in `units.gd`:
    - delete `static var look` and both assignments;
    - `draw()` becomes `match spec.rig:` → `"humanoid": FkFigure.humanoid(ci, spec, pose, seed)`, and the same for every rig;
    - `height()` keeps reading `spec.get("look", FkLooks.BODIES[&"human"])`.
  - make sure the adapter always passes `look`, `palette` and `team`. It already does (Task 3, Step 5).

- [ ] **Step 3: Check nothing is left.** Run `grep -n "FkUnits.look\|static var" addons/figure_kit/*.gd`. Expected: only `paint.gd`'s `_stack`/`_current`.

- [ ] **Step 4: Tests.** Expected: `76 tests, 0 failures`.

- [ ] **Step 5: Goldens.** Expected: `0 differing`. The `--race=all` golden is what proves per-call looks don't leak between races.

- [ ] **Step 6: Commit.**
  ```bash
  git add addons/figure_kit tests/test_fk_units.gd
  git commit -m "figure kit: rigs take (ci, spec, pose, seed); race look travels in the spec"
  ```

---

### Task 5: Kit README and project docs

**Files:**
- Create: `addons/figure_kit/README.md`
- Modify: `CLAUDE.md` (Rules: one line on the kit boundary), `docs/PLAN.md` (a D-entry recording the kit decision)

- [ ] **Step 1: Write `addons/figure_kit/README.md`.** Use exactly these sections:
  - **What it is.** Procedural 2D unit figures drawn with CanvasItem calls. Human figures on rigs, gear, mounts and machines. Facing +x, feet at y = 0.
  - **Install.** Copy `addons/figure_kit/` into a Godot 4.x project, then run the editor or `--import` once so the `Fk*` classes register.
  - **Draw a unit.** A ~10-line example:
    ```gdscript
    func _draw() -> void:
    	FkPaint.begin(self, Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2(200, 300)))
    	var spec := {"rig": "humanoid", "helmet": "kettle", "weapon": "sword", "shield": "kite",
    		"look": FkLooks.BODIES[&"dwarf"], "palette": FkLooks.PALETTES[&"dwarf"][3], "team": Color("3a78d8")}
    	FkUnits.draw(self, spec, {"walk": 0.0, "move": 0.0, "atk": -1.0, "t": 0.0, "flash": 0.0}, 7)
    ```
  - **Spec keys.** A table of every key and its allowed values. Take the lists from the `match` statements in `figure.gd`, `armour.gd`, `weapons.gd`, `mounts.gd` and `machines.gd`: rig, helmet, weapon, shield, pack, cape, build, beast, crew, variant, car, shot, runes, look, palette, team.
  - **Pose keys.** `walk` (stride phase, rad), `move` (0..1 walk blend), `atk` (0..1 attack progress, <0 idle), `t` (seconds), `flash` (0..1 hit flash).
  - **Queries.** `FkUnits.height`, `muzzle`, `shot`, `wreck`, `swing`.
  - **Rule.** The kit depends on nothing outside itself. Keep it that way; see `tests/test_fk_boundary.gd` in the origin project.

- [ ] **Step 2: Update `CLAUDE.md`.** Under `## Rules`, add:
  `- `addons/figure_kit/` is a reusable, game-agnostic unit renderer: it must never reference a game class (enforced by `tests/test_fk_boundary.gd`). Game-specific mapping lives in `scripts/view/art/unit_art.gd`.`

- [ ] **Step 3: Update `docs/PLAN.md`.** Add a decision entry after the last D-number: the figure kit extraction (owner wants to reuse units in other games), with pointers to the spec and this plan.

- [ ] **Step 4: Full verification.**
  Run the tests (expected: `76 tests, 0 failures`), `timeout 60 "$G" --headless --path . -s tools/validate_data.gd` (expected: pass), and the goldens (expected: `0 differing`).
  Then regenerate the tracked reports: `reports/unit_gallery.png`, `reports/unit_gallery_races.png`, `reports/base_gallery.png`. Their bytes should be unchanged; `git status` shows them unmodified, or modified only in PNG metadata.

- [ ] **Step 5: Commit.**
  ```bash
  git add addons/figure_kit/README.md CLAUDE.md docs/PLAN.md
  git commit -m "figure kit: README + project rule for the kit boundary"
  ```
