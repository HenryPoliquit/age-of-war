# Timefront — agent notes

Godot **4.7-stable** (pinned in `.godot-version`), GDScript, 2D. Design docs: `docs/PRD.md`, `docs/GDD.md`; plan and tasks: `docs/PLAN.md`, `docs/tasks/`.

## Setup (every fresh cloud session)

```sh
tools/setup_env.sh          # downloads pinned Godot, symlinks tools/godot, imports the project
```

Always wrap Godot in `timeout`: a script that fails to compile leaves headless Godot running forever.

## Commands

```sh
timeout 300  tools/godot --headless --path . -s tests/run_tests.gd                  # unit tests
timeout 60   tools/godot --headless --path . -s tools/validate_data.gd              # data schema check
timeout 1500 tools/godot --headless --path . -s tools/sim/run_sim.gd -- --matches=20 # balance harness → reports/sim_report.md (4 worker processes, ~1 min)
# What-if balance work (nothing is written to data/; overrides are --set=file.prop=v / --scale=units:role=heavy.hp=0.9):
timeout 600  tools/godot --headless --path . -s tools/sim/experiment.gd -- --a=tactician --b=spam_heavy --n=40 [--start-age=4] [--docs-a=horde,bastion]
python3 tools/sim/tune.py --matches=12 --passes=3 --log=/tmp/tune.jsonl       # coordinate-descent tuner over the harness
timeout 60   tools/godot --headless --path . -s tools/export_csv.gd                 # data → reports/data.csv
# Screenshots of the running game (Xvfb is installed in cloud sessions). --autoplay makes an AI play
# the left side and the camera follow the front; --start-age=N, --cam=X, --shots=N --every=S optional.
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -- --autoplay --speed=3 --start-age=3 --screenshot=/tmp/shot.png --after=20
# (--race=human|elf|dwarf and --enemy-race=… pick the sides' races; races are cosmetic.)
# Unit gallery (colour / greyscale / silhouette of every unit) for the PRD §11 silhouette check:
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/unit_gallery.gd -- --out=reports/unit_gallery.png
# (--race=elf for one race's three modes; --race=all for the three races side by side.)
# Role review sheet (rows = ages; walk ×4, guard, wind-up, strike, recover) for one race — the skeleton review loop.
# --yaw=DEG turns the camera toward the side the figures face (the game uses 25, UnitArt.VIEW_YAW_DEG; 0 = square-on); unit_gallery.gd and unit_anim.gd take it too:
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --rendering-method gl_compatibility --path . --resolution 1920x1080 -s tools/unit_sheet.gd -- --role=vanguard --race=human --out=reports/sheet_vanguard_human.png
# Walk sheet (eight phases of one stride for an age's vanguard, ranged and heavy unit; --race=human|elf|dwarf --age=1..6 --scale=N --yaw=DEG):
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/walk_sheet.gd -- --race=human --age=3 --out=reports/walk_human_3.png
# Skill gallery (fires one skill in a staged match and tiles frames; --races=human,elf,dwarf gives one row per race; --aim shows aim mode and the reticle; --enemy makes the enemy fire it; --times=a,b,c picks the frames; --aim-x=X aims an aimed skill):
timeout 200 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/skill_gallery.gd -- --skill=rockfall --races=human,elf,dwarf --times=0.75,1.0,1.3 --out=reports/skill_rockfall.png
# Base gallery (every race × age base with its turret towers in front; --towers for a close-up of the towers; --solo=elf:3 for one base big; --night=1 lights the windows; --yaw=DEG the camera, 25 by default):
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/base_gallery.gd -- --out=reports/base_gallery.png
# Backdrop gallery (sky, scenery, ground, foreground and the base at the gate; --race=human|elf|dwarf --ages=1,2,3,4 → a 2 × 2 sheet; --solo=elf:3 for one full-size; --cam=X):
timeout 120 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -s tools/backdrop_gallery.gd -- --race=elf --ages=1,2,3,4 --out=reports/backdrop_elf.png
```

After adding a new `class_name` script, run `timeout 100 tools/godot --headless --path . --import` once so the class is registered.

## Rules

- Stats live in `data/*.tres`, never hardcoded in scripts.
- After any balance change (anything under `data/`, or AI/sim logic), run the harness and include `reports/sim_report.md` in the PR. Record the change and why in `docs/balance_log.md`.
- `scripts/sim/` is the only place game rules live. The sim may emit presentation records (`sim.fx`, only when `record_fx` is on) but never reads them back. The view (`scripts/view/`) and AI (`scripts/ai/`) act only through `MatchSim` commands. Keep the sim deterministic: no `randf()`/`Time` in sim code; use `sim.rng` or a seeded RNG.
- Visual and feel work can't be verified in the cloud. Tasks with visual output end with "owner reviews locally".
- `addons/figure_kit/` is a reusable, game-agnostic unit renderer: it must never reference a game class (enforced by `tests/test_fk_boundary.gd`). Game-specific mapping lives in `scripts/view/art/unit_art.gd`.
