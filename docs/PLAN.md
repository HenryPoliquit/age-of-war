# Timefront — Technical Plan

**Status:** v1, written with M0/M1 implementation (Opus 5.5 did planning as well, per the PRD §10.2 fallback — a fresh Sonnet review of this plan is still owed).
**Inputs:** `docs/PRD.md` (v2), `docs/GDD.md` (v2).

## 1. Architecture

```
data/*.tres ──► GameData (loader) ──► MatchSim (rules, deterministic) ◄── commands ── UtilityAI
                                          │  ▲                                    ▲
                                          │  └────────── commands ── MatchView/MatchHud (player)
                                          ▼
                                      MatchLog (JSON) ──► post-match screen, balance harness
```

- **One rules engine.** `scripts/sim/match_sim.gd` owns every game rule. It is a `RefCounted` with no nodes, no rendering and no wall-clock access, stepped at a fixed `rules.tick_dt` (0.1 s). The graybox view, the future art view, the AI and the harness all drive this same class, so the sim and what the player sees can't disagree (GDD §13.3 "movement is code-driven").
- **Commands are the only input.** `queue_unit`, `evolve`, `buy_veterancy`, `buy_forge`, `unlock_slot`, `build_turret`, `sell_turret`, `choose_doctrine`, `set_stance`, `fire_ability`. Each validates and returns `bool`. The player HUD and the AI call the same functions, which enforces GDD §11.1 ("AI plays by the same rules").
- **Presentation hooks.** The sim writes cosmetic fields (`SimUnit.state`, `last_hit_time`, `last_attack_time`) and, when `record_fx` is on, short-lived `fx` records (hits, deaths, ability pulses). Views consume and clear them. The sim never reads them back.
- **Determinism.** No unseeded randomness in the sim. Units act in spawn order, and both sides read the same snapshot of front units each tick, so neither side moves first. Ties break by unit id. The AI uses its own seeded RNG. `test_match::test_determinism` asserts byte-identical logs for a repeated seed.

## 2. Repository layout

| Path | Contents |
| --- | --- |
| `data/` | `rules.tres`; `ages/age_N.tres` (roster, turrets, ability, doctrine offer, palette); `units/`, `turrets/`, `abilities/`, `doctrines/`; `ai/personalities/`, `ai/difficulties/` |
| `scripts/data/` | Resource classes (`UnitDef`, `TurretDef`, `AbilityDef`, `AgeDef`, `DoctrineDef`, `RulesDef`, `AiPersonalityDef`, `AiDifficultyDef`) and `GameData` loader |
| `scripts/sim/` | `MatchSim`, `SimSide`, `SimUnit`, `SimTurret`, `MatchLog`, `MatchRunner` |
| `scripts/ai/` | `UtilityAI` |
| `scripts/view/` | `main.gd` (menu/Skirmish), `MatchView` (lane drawing, input, camera), `MatchHud`, `PostMatchGraphs` |
| `scenes/` | `Main.tscn` (everything else is built in code for the graybox; real scenes arrive with art in M2) |
| `tests/` | `run_tests.gd` runner, `TestCase` base, `test_*.gd` |
| `tools/` | `setup_env.sh`, `validate_data.gd`, `export_csv.gd`, `sim/run_sim.gd`, `bootstrap/gen_data.gd` (one-shot, historical) |
| `reports/` | `sim_report.md` (committed with balance PRs); JSON and CSV are gitignored |

## 3. Data schema

All stats are per-age final values; the ×1.7 cost / ×1.9 HP-damage scaling was baked in once by the bootstrap generator, so each file can be tuned individually. `tools/validate_data.gd` enforces: six ages; one unit per role per age; Siege from Age 2; all combat stats > 0; `min_range < range`; matrix completeness; doctrine `pick_age` consistency; unique ids; income bonuses only on Brutal/Nightmare. Script defaults for combat stats are 0, so a value missing from a file fails validation rather than silently using a default.

## 4. Decisions filling GDD gaps

| # | Decision | Why |
| --- | --- | --- |
| D1 | Positions are **progress from own gate**; world x = progress (left) or lane − progress (right) | Symmetric code for both sides |
| D2 | "Nearest enemy" = the enemy's most-advanced unit | On one lane, enemies can't pass each other, so the nearest enemy is always that side's front unit. That makes targeting O(1) per unit |
| D3 | **Only Siege damages turrets.** Siege hits turrets (lowest slot first) before the base; other roles hit the base | Makes Siege the structure investment GDD §5.1 asks for; turrets otherwise need no HP UI |
| D4 | Damage applies when the attack starts; the contact-keyframe delay (GDD §13.3) comes with rigs in M2 | No animation data exists yet; the delay shifts every unit equally |
| D5 | Melee (range ≤ 45) keeps pressing in to 8 px while it fights; ranged units hold at their range | Without this only one melee unit can ever reach a target (next ally is out of range), which made single big units dominate and bases unbreakable (see balance log B4) |
| D6 | Age 6 veterancy ranks price off 6,000 XP | GDD prices ranks off "the next evolution", which Age 6 doesn't have |
| D7 | Shieldwall "+40% armour" = incoming damage ÷ 1.4 | Needs a concrete formula |
| D8 | Abilities hit units only, never structures | Keeps abilities about the lane fight; bases fall to armies and Siege |
| D9 | Bastion's 5th slot costs 700 g × age multiplier | GDD gives slots 3–4 only |
| D10 | Turret HP baselines: Sentry 400, Artillery 500, Support 500, ×1.9 per age | Needed once Siege can damage turrets (D3) |
| D11 | The doctrine choice pauses only the player's evolution timer, not the match | GDD §13.5 wording |
| D12 | Veterancy is stored per unit; units keep their rank after the side evolves | GDD says ranks reset on evolving; this reads that as the side's ranks, not the units already fielded |
| D13 | Doctrines affect units spawned after the pick; Siegecraft's structure bonus applies to all the side's Siege | Doctrine price/HP is baked in at spawn |
| D14 | Units queued before evolving still train as old-age units | They were paid for |
| D15 | Sim time limit 30:00 = draw | Safety net; any match that long already fails §6 |
| D16 | In-repo test runner instead of GUT/gdUnit4 | Zero dependencies in fresh cloud sessions; 60 lines |
| D17 | Compatibility renderer for the graybox | Runs under Xvfb for screenshots. **Revisit at M2**: 2D lights and glow behave differently between renderers (GDD §13.4, PRD §10.1) |

## 5. AI (GDD §11.4)

`UtilityAI` runs a decision every `difficulty.decision_interval`, in this order:

1. **Ability:** Easy aims at a random enemy; Normal at the most units in the zone; Hard+ at the most gold, and only when worth ≥ 20 s of income or under pressure. Shieldwall covers our own densest group.
2. **XP:** follow the personality's `age_plan` (fast / strong / balanced). Hard+ won't start a 5 s transition under pressure unless the enemy is already an age ahead.
3. **Stance:** personalities with `uses_hold` mass at 35% of the lane and release at `hold_release_seconds` of income.
4. **Gold:** first a structural want (replace a turret two ages old → turret target → slot → Forge), saving for it while keeping a minimum army. Then units by deficit against a target role mix. Counter-play reshapes the mix: Normal counters the enemy's majority role; Hard is matrix-aware (offence into the enemy's armour mix ÷ exposure to their damage mix, cubed); Nightmare also counters doctrines. The mix always keeps a Vanguard/Heavy screen in front of the backline.

All weights are in `data/ai/personalities/*.tres`. The sim-only archetypes (fast-age, strong-age, four spam bots) are ordinary personality files flagged `sim_only`.

## 6. Balance harness (GDD §15.2)

`tools/sim/run_sim.gd -- --matches=N` runs, at Hard vs. Hard:

| Suite | Matches | Feeds |
| --- | --- | --- |
| Round robin of the 4 personalities | 6 pairs × N | aggregate and pairing win rates |
| Tactician mirror, random doctrines | 3N | match length, Age 6 arrival, doctrine win rates |
| Fast-age vs. strong-age | 2N | decisions check |
| Each spam bot vs. Tactician | 4 × N | dominant-unit check |
| Turtle mirror (both Bastion by preference) | N | worst-case defence |

Sides alternate every match. Draws score 0.5. The escalation share is measured over round robin + mirror + fast/strong. Jobs run across `--workers` headless Godot processes (`scripts/sim/sim_jobs.gd`, `tools/sim/sim_worker.gd`), with results identical to a single process for the same seed. Output: `reports/sim_report.md` (targets table, length histogram, age arrival, where units die along the lane, per-unit damage dealt/absorbed per gold) and `.json` (the same plus numeric `metrics`). It exits 1 if any target fails. N=20 takes about a minute on 4 cores.

Balance tooling on top of it:

- **Overrides** (`--set=doctrines/horde.unit_cost_mult=0.75`, `--scale=units:role=heavy.hp=0.9`, `--scale=ages:index=*.base_max_hp=1.5`) change data in memory for one run; the report lists them. Nothing is written to `data/`.
- **`tools/sim/experiment.gd`**: any matchup, forced doctrines, start age, win rate / length / escalation / death locations. Used for targeted questions (e.g. the role duel matrix, balance log B11).
- **`tools/sim/tune.py`**: coordinate descent over ~19 data and AI knobs, minimising distance outside every PRD §6 band, on fixed seeds (common random numbers). It proposes overrides; a human applies them to `data/` and records them in the balance log. Always validate the result on a different seed.

## 7. Match logs (GDD §15.4)

`MatchLog.to_dict()` → `{version, seed, meta, timeline[1 s samples: t, front, tide, esc, sides[gold, xp, xp_earned, gold_earned, momentum, army, units, age, base_hp, base_max]], events[...], unit_stats[side][unit id: spawned, gold, dealt, absorbed], base_damage}`. The Skirmish writes one to `user://logs/` per match. The post-match screen draws from the in-memory log.

## 8. Performance plan (GDD §16)

The sim is O(units) per tick, except Artillery cluster search and AI ability aiming, which are O(n²) on ≤ 30 units when they fire. A full 15-minute match runs in about 1 s headless. For the art view (M2): pool projectiles/particles/lights, cap lights per frame, update bones at half rate for units mid-crowd, and profile on the two PRD §6 machines. None of this exists yet.

## 9. Open risks for M2

- **Balance is not green** (see `reports/sim_report.md` and `docs/balance_log.md`). The harness says why, which is its job, but M2's gate needs it green.
- **Small armies.** The GDD economy (income-limited, unit cost ×1.7 per age) produces armies of about 2–10 units per side, not the 30-vs-30 fights PRD §6/§11 budget for. Decide whether that's the intended feel or whether costs/income should shift so crowds happen. It affects performance budgets, readability, and how strong turrets feel.
- Renderer choice (D17), contact-keyframe damage (D4), Spine vs. built-in skeletons (PRD §10.1).

## 10. Presentation layer (interim procedural art)

Until painted parts exist (M2), everything is drawn procedurally with canvas calls. The structure is meant to survive the swap to real art: each piece has one job, and a skeleton-based renderer can replace it without touching the others.

| File | Job |
| --- | --- |
| `scripts/view/match_view.gd` | Steps the sim, interpolates between 10 Hz ticks (`prev_progress`, `alpha`), keeps the presentation clock (`anim_time`: follows game speed, freezes on hitstop), camera shake / zoom punch / evolution slow-mo, and turns `sim.fx` records and sim events into visuals |
| `scripts/view/world_layer.gd` | Bases, turrets, units, corpses (pooled nodes for per-corpse fade), HP bars, rally and front markers |
| `scripts/view/art/race_look.gd` | Races (GDD §5.7): body proportions, skin/hair, magic colour, clothing palettes per age and the style of every unit slot per race. Names come from `data/races/*.tres` (`RaceDef`); the sim only carries the race id on `SimSide` |
| `scripts/view/art/unit_art.gd` | Modular rigs (humanoid with race proportions, rider on boar/horse/stag/elk/ram/bear, chariot, ram, catapult, ballista, trebuchet, cannon, steam tank, golem, treant, sky cannon, obelisk) dressed per race and unit slot; walk phase from distance walked (no foot sliding), attack poses with anticipation → contact → recovery, hit flash, secondary motion on plumes/manes |
| `scripts/view/art/base_art.gd` | Bases drawn in two passes: static architecture (masonry courses, planks, roofs, slits) rendered once per race, age and team into a cached SubViewport texture; banners, fire, smoke and night-lit windows drawn live. One base per race and age (human forts, elven tree-halls, dwarven mountain holds; `tools/base_gallery.gd`) with turret mounts, damage states (cracks, fire), rebuild-on-evolve; turrets per kind and age with aim and recoil |
| `scripts/view/art/scenery.gd`, `backdrop.gd`, `shaders/split_backdrop.gdshader` | Parallax scenery per race and age (GDD §4.1: human lands, elven forests, dwarven mountains), the split battlefield blended at the front line with a ragged brush seam, and the painterly dissolve when a side evolves |
| `scripts/view/art/front_layer.gd` | In front of the lane, split at the seam like the backdrop: weather per race and age (dust motes, fireflies, gulls, petals and falling leaves, drizzle, storm rain with splashes, snow, ash and rising embers, arcane sparks) as stateless time-driven particles, plus foreground props on a faster parallax for depth |
| `shaders/unit_outline.gdshader` | Each side's units render inside a `CanvasGroup`: dark ink outline with a faint team-coloured rim for clarity in crowds |
| `tools/unit_gallery.gd` | Renders every unit in colour, greyscale and flat silhouette (`reports/unit_gallery.png`) for the "role identifiable by shape alone" check. Role rules it enforces: Vanguards broad and shielded (or an upright polearm), Ranged slimmer with a pack on the back, Heavies mounted or vehicles, Siege engines |
| `scripts/view/fx_layer.gd` | Pooled particles, projectiles (arrows, stones, javelins, bullets/tracers, cannonballs, shells, energy bolts), per-damage-type impacts (GDD §13.4), muzzle flashes, scorch decals, ability visuals and telegraphs, evolution shockwave. Additive "glow" pass stands in for 2D lights |
| `scripts/view/art/day_night.gd` | Purely visual day/night cycle on match time (4-minute day, opens mid-morning): sky gradient, sun arc then moon and stars, warm twilight and cool night ambient, lamps and flash lights stronger at night. Scaled per race and age (strong in the daylit looks, gentle in stormy and night ones) so each keeps its GDD §4.1 look. The sim never reads it; toggle in Settings |
| `scripts/view/light_pool.gd` | Pooled `PointLight2D`s (cap 10, oldest reused) for muzzle flashes, explosions, abilities and evolution, plus a per-age ambient `CanvasModulate` that follows whichever age fills the screen |
| `scripts/view/audio/synth.gd`, `audio_director.gd` | Placeholder audio synthesized at startup (no asset files): SFX per damage type, gunshots/cannons/zaps, UI cues, evolution fanfare, escalation horn; per-age music loops in two stems (base + percussion) generated on worker threads and streamed through an `AudioStreamGenerator`, with the percussion stem following lane pressure and a crossfade on evolving |
| `scripts/view/settings.gd` | GDD §14 settings persisted to `user://settings.cfg`: music/effects/interface volume buses, screen-shake slider, reduce flashing, VFX preset (Low halves particles and turns lights off), colour-blind palette. Opened from the menu, the ⚙ button or Esc (pauses the match) |
| `shaders/sky.gdshader`, `shaders/ground.gdshader`, `shaders/common.gdshaderinc` | Painted sky per age (gradient, sun glare and haze, domain-warped fbm clouds lit from the sun, stars) and ground materials per age (dirt, sand, grass, wet rock, mud with puddles, metal deck) with a worn lane road; both carry the seam mask and are clipped to their half of the screen |
| `scripts/view/ui_style.gd` | Classic strategy UI: generated 9-slice bronze-and-iron frames with bevels and rivets, Cinzel titles and Alegreya Sans body text (OFL, `assets/fonts/`) |
| `scripts/view/match_hud.gd` | Themed HUD: base bars, tide pips, minimap, unit cards with live portraits, queue strip, command panel, doctrine choice, event banners, post-match |

Timing rules that keep visuals honest to the sim: melee impacts land on the swing's contact frame (≈0.42 of the attack animation); ranged units release their projectile at the end of anticipation and the target flashes when it arrives. The sim still applies damage at attack start (D4), so the visual lag is at most ~0.4 s. Moving damage to the contact frame in the sim is still M1-12.

**Quality bar (PRD §11) status with procedural art:** in place: walk/idle/attack poses blend over ~0.12 s, impact flashes, hitstop and shake on heavy hits, layered blast effects, short-lived 2D lights on muzzles, explosions and abilities, the evolution event (slow-mo, shockwave, backdrop dissolve, base rebuild, banner, fanfare, music crossfade), the split battlefield with brush-grain shading, weather per age, unit outlines, damage-type sounds, and a silhouette/greyscale gallery showing each role is readable by shape. Still missing: normal-mapped painted parts, recorded audio and composed music. **All of it needs the owner's local review; the cloud only checks screenshots.**
