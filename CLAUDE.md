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
timeout 1500 tools/godot --headless --path . -s tools/sim/run_sim.gd -- --matches=20 # balance harness → reports/sim_report.md
timeout 60   tools/godot --headless --path . -s tools/export_csv.gd                 # data → reports/data.csv
# Screenshot of the running game (Xvfb is installed in cloud sessions):
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" tools/godot --path . --resolution 1920x1080 -- --autoplay --speed=12 --screenshot=/tmp/shot.png --after=20
```

After adding a new `class_name` script, run `timeout 100 tools/godot --headless --path . --import` once so the class is registered.

## Rules

- Stats live in `data/*.tres`, never hardcoded in scripts. `tools/bootstrap/gen_data.gd` was a one-shot; don't re-run it.
- After any balance change (anything under `data/`, or AI/sim logic), run the harness and include `reports/sim_report.md` in the PR. Record the change and why in `docs/balance_log.md`.
- `scripts/sim/` is the only place game rules live. The view (`scripts/view/`) and AI (`scripts/ai/`) act only through `MatchSim` commands. Keep the sim deterministic: no `randf()`/`Time` in sim code; use `sim.rng` or a seeded RNG.
- Visual and feel work can't be verified in the cloud. Tasks with visual output end with "owner reviews locally".
