# M1b — Simplify systems (post-playtest)

Spec: `docs/superpowers/specs/2026-09-26-simplify-systems-and-hud-design.md`. Plan 1: `docs/superpowers/plans/2026-09-26-simplify-systems-plan-1-rules.md`.

| # | Task | Done-condition | Status |
| --- | --- | --- | --- |
| M1b-1 | Docs to v3 | GDD/PRD/PLAN describe the v3 rules | ✅ |
| M1b-2 | Remove doctrines, stances, veterancy, momentum | Tests green; data validates; game runs | ✅ |
| M1b-3 | XP skills with auto-targeted shapes; Rockfall | `test_skills` green | ✅ |
| M1b-4 | All units attack turrets; 1 free slot + 3 to unlock | `test_combat`, `test_evolution` green | ✅ |
| M1b-5 | Gold upgrades (units, turrets, income) | `test_upgrades` green | ✅ |
| M1b-6 | AI buys upgrades and fires skills | Full-match tests green | ✅ |
| M1b-7 | Balance to green | `run_sim.gd --matches=20` exits 0 on seeds 1 and 2, or findings recorded | ❌ — 3/8 (seed 1), 2/8 (seed 2); see `docs/balance_log.md` v3 findings |
| M1b-8 | HUD rebuild (Plan 2) | Owner reviews locally | ⏳ |
