# PRD: Timefront — An Age-Evolution Lane Battler

**Working title:** Timefront (placeholder — see §12 on naming)
**Author:** Paul
**Status:** Draft v2
**Last updated:** 2026-09-25
**Companion document:** `docs/GDD.md` — the Game Design Document. This PRD says *why* and *what counts as success*; the GDD says *how the game works*, with the numbers. In the spec-driven chain (PRD → spec → plan → tasks → implement), the GDD plays the role of the spec/SRD.

### What changed in v2

- **Economy fixed.** v1's flat income could not carry a match past Age 3–4 in the target time, and armies *shrank* each age. Income now rises on a shared match-wide "tide", and evolution costs were re-derived from a pacing model (GDD §4). Target: a balanced player reaches Age 6 around minute 11.
- **Systems trimmed for readability.** The front line now has one reward (momentum), not two; doctrine picks reduced from three to two.
- **Success metrics made measurable.** Vague targets replaced with checks the balance simulation can compute (§6).
- **New:** development workflow for cloud sessions and model routing (§10), a playtest protocol (§7), onboarding and post-match stats in scope (§9), a concrete presentation quality bar (§11).

---

## 1. Summary

Timefront is a 2D side-view lane battler in the "evolve through the ages" genre popularised by the Flash game Age of War and its sequel. Two bases sit at opposite ends of a single lane. Players spend gold to send units down the lane, build turrets to defend, and spend experience to advance their civilisation through six ages — Stone Age to Future — with every unit, turret, the base and the battlefield itself transforming at each evolution.

The goal is not to remake Age of War. It is to take the genre's proven core loop and fix what holds it back: **stalemates, blunt balance, shallow decisions, and dated presentation.** Timefront keeps the one-lane readability and "one more match" pacing, and adds a front line that rewards pushing, readable counters, a real evolve-now-or-strengthen-now tradeoff, doctrines for replayability, and hand-painted skeletal animation with modern VFX.

This starts as a personal project to answer one question: *can we make a better game than the best version of Age of War?* If the answer is yes, it gets published.

## 2. Background: The Reference Game

The reference is **Age of War 2**, treated as the best version of the series: it expanded the original's five ages to seven (Stone, Spartan, Egyptian, Medieval, Renaissance, Modern, Future), was noticeably more polished than its predecessor, and kept the core loop — spawn units with gold, earn XP from combat, evolve to the next age, build up to four turrets on the base, and fire a periodic special attack.

What it does well, and Timefront must keep:

- **Instant readability.** One lane, two bases, units walk and fight. Anyone understands it in ten seconds.
- **The evolution fantasy.** Watching cavemen give way to knights, then to tanks, then to laser troopers is the whole hook.
- **Escalating matches** with a clear win condition.
- **Low input, real decisions** — the player picks *what* and *when*, the units handle the rest.

What holds it back (from reviews and player feedback):

| Problem | What players experience |
| --- | --- |
| **Stalemates** | Late-game matches where neither side can break the other's base — reviewers report 40+ minute deadlocks. |
| **Difficulty spikes** | Easy is trivial, medium jumps sharply, hard and insane become near-impossible in later ages. |
| **Blunt balance** | Some unit types (anti-armour in particular) dominate; counters exist but aren't legible. |
| **Shallow decisions** | Evolving as soon as possible is almost always correct; the special attack is described as rarely essential. |
| **Low replayability** | Reviewers note it lacks depth and isn't something you keep coming back to. |
| **Dated presentation** | Flash-era sprites, stiff animation, minimal effects, plus CPU usage complaints. |

Genre benchmarks worth borrowing from: **Clash Royale** accelerates income late in a match so it resolves; **Stick War: Legacy** lets the player command the whole army (attack / hold); **Swords & Soldiers** shows a front line that swings back and forth and coordinated pushes that end matches — and was criticised mainly for bland environments, which is exactly where Timefront's per-age battlefields aim.

Every goal in §4 maps to a row in the problem table.

## 3. Problem Statement / Opportunity

The age-evolution lane battler has a strong, simple hook and an audience that remembers it fondly, but the genre's best-known entries are Flash-era games whose design never evolved past their first draft. The core loop is sound; the systems around it were never pushed. There is room for a version that feels as immediate as the original but plays deeper, resolves cleanly, and looks and moves like a modern game.

## 4. Goals & Non-Goals

### Goals

- **G1 — No stalemates.** Every match resolves. The front line rewards pushing, income rises through the match so late armies can break defences, and a late escalation phase guarantees an ending. *(Fixes: stalemates.)*
- **G2 — Legible counters.** A small damage-type × armour-type matrix, shown in unit tooltips, so the player knows *why* a unit won or lost. No hard counters that delete a unit type outright. *(Fixes: blunt balance.)*
- **G3 — Real decisions.** Experience buys *either* evolution *or* veterancy for the current age; a targeted, momentum-fuelled age ability matters; turrets get outclassed and must be replaced. *(Fixes: shallow decisions.)*
- **G4 — Replayability without grind.** Doctrines chosen at evolutions, AI opponents with distinct personalities, and a campaign of handcrafted battle modifiers. *(Fixes: low replayability.)*
- **G5 — Fair, smooth difficulty.** AI plays by the same economic rules on Hard and below; difficulty comes from decision quality first and resource bonuses only at the top two levels. *(Fixes: difficulty spikes.)*
- **G6 — Modern presentation.** Hand-painted 2D art, skeletal animation with blended transitions, 2D lighting, layered particle VFX, hit feedback, and an age-evolution moment that feels like an event — to the quality bar in §11. *(Fixes: dated presentation.)*
- **G7 — Data-driven and verifiable.** Every unit, turret, ability and age lives in editable data files, and a headless AI-vs-AI simulation proves the balance targets in §6 instead of guessing.

### Non-Goals (v1)

- **Online multiplayer.** Netcode is a project in itself. Single-player vs. AI only; PvP is a post-launch consideration.
- **Multiple lanes or base building.** One lane is the genre's identity.
- **Realistic art.** Stylised and hand-painted — better and smoother, not photoreal.
- **Monetisation design.** No shop, premium currencies or ads. If published, it's a premium game.
- **Online telemetry.** Match data is logged locally only (§7).
- **Using Age of War's name, characters, art, audio or UI.** Timefront is an original game in the same genre (§12).

## 5. Target Player

- **Primary:** Paul — wants to know whether a better version of this game is buildable, and to learn the full pipeline doing it.
- **Secondary (if published):** players who remember Age of War from Flash portals and would buy a modern take; and fans of lane battlers and light strategy (Stick War, Swords & Soldiers, The Battle Cats, tower-defence-adjacent players) who want 10–14 minute matches with real decisions.

## 6. Success Metrics

"Better than Age of War 2" has to be measured, not asserted. Sim metrics come from the balance harness (GDD §15) and are checked automatically; playtest metrics come from the protocol in §7.

### Simulation (automated, run after every balance change)

| Area | Metric | Target |
| --- | --- | --- |
| Stalemates | Share of AI-vs-AI matches reaching escalation (15:00) | < 10% |
| Match length | Median match duration, Tactician vs. Tactician | 10–14 min |
| Pacing | Median time a balanced AI reaches Age 6 | 10:00–12:00 |
| Balance | Each personality's aggregate win rate across all opponents, equal difficulty | 40–60% |
| Balance | Any single personality pairing | 30–70% (designed counters allowed, hard counters not) |
| Balance | Win rate of any doctrine (across all matchups) | 40–60% |
| Decisions | Fast-age AI vs. strong-age AI (GDD §11.3) | each wins 40–60% |
| Dominant units | Any single-role spam build vs. Tactician (Hard) | wins < 30% |
| Worst-case defence | Turtle vs. Turtle, both taking Bastion | < 25% reach escalation; no match exceeds 18:00 |

The "Dominant units" row directly tests Age of War 2's "one unit type dominates" problem, the "Decisions" row tests that evolving ASAP is not always right, and the "Worst-case defence" row tests the exact turret-deadlock that produced Age of War 2's 40-minute stalemates — an aggregate stalemate rate could otherwise hide it.

### Playtest and technical

| Area | Metric | Target |
| --- | --- | --- |
| Head-to-head | Blind side-by-side vs. Age of War 2 (§7) | ≥ 4 of 5 testers prefer Timefront |
| Feel | "Combat feels impactful" (1–5) | ≥ 4.0 average |
| Clarity | Testers can explain why they won or lost after one match | ≥ 4 of 5 testers |
| Performance | Reference PC: GTX 1060-class GPU, 4-core CPU, 1080p, 30 units per side, full VFX | Stable 60 fps |
| Performance | Integrated-graphics laptop, "Low" VFX preset | Stable 60 fps |
| Personal | You'd rather open Timefront than Age of War 2 | Yes |

## 7. Playtest Protocol

The blind head-to-head is the M2 go/no-go gate, so it needs a fixed method:

- **Testers:** at least 5 who haven't seen Timefront; ideally at least 2 who have played Age of War before.
- **Session:** 15 minutes of each game, order alternated between testers so neither game always goes first. Games are labelled "A" and "B", not by name.
- **Keep the comparison inside finished content.** At M2 only Ages 1–2 have final art, but a normal match reaches Age 3 by about 4:00. So the slice build uses a **slice ruleset**: evolution capped at Age 2, tide capped at level 3, escalation from 7:00 — each session plays roughly two complete matches entirely in finished ages. The gate therefore tests feel, clarity and the core systems, not full-game pacing (the sim covers that).
- **Questions after both:** which would you play again (A/B); combat impact (1–5) for each; "why did you win or lose your last match?" (free text, scored for whether the answer names a real cause — counters, front line, evolving timing); one thing you'd change.
- **Match logs:** Timefront writes a local JSON log per match (timeline of gold, XP, army value, front position, ages, abilities). Playtest logs are compared to sim logs — if real players see very different match lengths or stalemate rates than the AI does, the AI is wrong, not the players.

## 8. Product Pillars

1. **Readable at a glance.** If a system can't be understood from the lane itself, it doesn't ship.
2. **Every match ends well.** Comebacks are possible, stalemates are not.
3. **Decisions over clicks.** Fewer, weightier choices; no APM race.
4. **Every hit lands.** Animation, VFX, sound and hitstop work together so combat feels physical.
5. **Each age is a place.** Evolution changes the palette, lighting, music and battlefield, not just the unit sprites.

## 9. Scope

### Vertical slice (the go/no-go gate)

- Ages 1–2 fully finished: art, animation, VFX, audio — to the §11 quality bar.
- All core systems working across all six ages in graybox (placeholder art): economy tide, front line, momentum, evolution, veterancy, turrets, first doctrine pick, escalation.
- One AI personality (Tactician) at three difficulties; Skirmish mode; post-match stats screen; the slice ruleset used for the §7 blind test.
- Balance harness running headless and green on the §6 sim targets.

**Gate:** if the slice doesn't pass the §7 blind test, fix the design before producing more content. Content multiplies whatever is already there, good or bad.

### Full game (v1.0)

- Six ages (Stone, Bronze, Medieval, Gunpowder, Industrial, Future), four unit roles each (three in Age 1), turrets, one signature ability per age.
- Two doctrine picks per match, four AI personalities, five difficulties.
- **First-time experience:** Chronicle battles 1–5 each introduce one system (queueing & counters → turrets → evolving → front line & abilities → veterancy & doctrines), so no player meets everything at once.
- Skirmish, and a Campaign ("Chronicle") of ~18 handcrafted battles with modifiers.
- Post-match stats: graphs of gold, army value, front-line position and age over time, plus key moments (evolutions, abilities, biggest trades).
- Settings, campaign save, accessibility options, key rebinding, speed control.

### If behind schedule, cut in this order

1. Campaign to 12 battles (keep the five teaching battles).
2. Fourth AI personality (Economist).
3. Support turret type.
4. Age 6 doctrine-flavoured cosmetics, ability variants and other per-age extras beyond the core roster.

Never cut: the §11 quality bar on shipped ages, the balance harness, the teaching battles.

### Post-v1 candidates

Commander hero units, Endless/Survival mode, daily challenge seeds, mod support via the data files, a third doctrine pick, local or online PvP.

## 10. Platform, Technology & Development Workflow

### 10.1 Engine

**Godot 4 (current stable 4.7), GDScript, PC first.**

- **2D is first-class.** A dedicated 2D renderer with built-in 2D skeletons (bones, mesh deformation with vertex weights, 2D IK), animation blending, 2D lights with normal-mapped sprites, GPU and CPU particles, and canvas shaders — every piece the "smoother animation, better VFX" goal needs, with no plugins.
- **Free with no royalties.** MIT-licensed. If the game is published, nothing is owed on revenue.
- **Keeps "publish later" open.** Exports to Windows, macOS, Linux, web, Android and iOS from one project.
- **Fits AI-assisted development.** Scenes (`.tscn`) and data resources (`.tres`) are plain text and GDScript is Python-like, so a coding agent can read, edit and diff everything. Godot runs headless from the command line, so tests, the balance simulation and exports all run without an editor — which is what makes cloud-session development (§10.3) work.

**Animation tool:** start with Godot's built-in 2D skeletons. If animation volume or quality outgrows them after the vertical slice, move to **Spine** with its official Godot runtime — meshes, IK and weights require **Spine Professional** (currently $379); the $69 Essential edition excludes them. Decide at the M2 gate.

**Rejected alternatives:** Unity (capable, but heavier and more editor-bound for a solo 2D game), Phaser/web (you'd assemble lighting, particles and animation tooling yourself and likely still buy Spine), Unreal (3D-first, overkill for a stylised 2D lane).

**Renderer note:** web and mobile exports use Godot's Compatibility renderer, where some particle setups behave differently. PC is the primary target; if web or mobile becomes real, test an export during the vertical slice, not at release.

### 10.2 Model Routing

Development uses Claude Code with different models for different phases of the spec-driven flow. This is the owner's chosen routing:

| Phase / job | Model | Examples |
| --- | --- | --- |
| **Planning** | **Fable 5.1** | Technical plan from PRD + GDD; per-milestone task breakdowns; design reviews of proposed GDD changes; diagnosing *why* the balance sim fails when the fix isn't obvious; architecture decisions |
| **Implementation & authoring** | **Opus 5.5** | GDScript, scenes, shaders, data resources, the sim harness, bug fixing, updating PRD/GDD after decisions |
| **Research & verification** | Sonnet | Genre and technical research; writing and running verification scripts; fresh-context review of a diff against the plan and GDD; summarising playtest logs |
| **Mechanical checks** | Haiku | Validating `.tres` data against the schema; checking numbers and section references stay consistent between GDD and data; drafting changelogs and commit messages |

Rules that make the routing work:

- **Hand off through files, not chat history.** Every phase reads and writes artifacts in the repo (`docs/PLAN.md`, `docs/tasks/M1.md`, sim reports). A new session with a different model starts from those files, with clean context.
- **The implementer is never the only reviewer.** After Opus implements a task, a fresh Sonnet session reviews the diff against the task's done-condition before merge.
- **Fallback:** Fable 5.1 currently requires usage credits on this account. If it isn't available, Opus 5.5 does the planning and a fresh Sonnet session reviews the plan before implementation starts.
- **Revisit the routing** when models change; the table records roles, not permanent choices.

### 10.3 Cloud-Session Development

Development runs in Claude Code cloud sessions, with the owner's local machine used for playing and looking at the game.

- **Git is the sync point.** Each cloud session clones the repo, works on a branch, and opens a pull request. The owner pulls locally and opens the project in the Godot editor.
- **What runs in the cloud:** headless Godot for GDScript tests (with a test framework such as GUT or gdUnit4), the balance simulation, data validation, and builds via headless export.
- **What runs locally:** anything visual or felt — animation quality, VFX, camera, audio, the §7 playtests. Headless Godot doesn't render, so **visual and feel verification is always a human step.** Tasks with visual output end with "owner reviews locally" in their done-condition.
- **Environment setup (first M0 task):** confirm the cloud environment can download the pinned Godot 4.7 headless binary and export templates, and script that setup so every session starts identically. Pin the Godot version in the repo and in `CLAUDE.md`.
- **Art files:** exported PNG body parts live in the repo; layered source files (`.kra`, `.psd`) stay out of it or go in Git LFS, since large binaries bloat clones and each cloud session clones fresh.
- **`CLAUDE.md` in the repo** holds only what an agent can't infer: the commands to run tests, the sim and exports; "stats live in `data/*.tres`, never hardcoded"; "after any balance change, run the sim and include its report in the PR"; the Godot version.
- **Suggested layout:** `docs/` (PRD, GDD, PLAN, tasks), `data/` (units, turrets, ages, doctrines, AI), `scenes/`, `scripts/`, `shaders/`, `art/`, `audio/`, `tests/`, `tools/sim/`.

## 11. Art Direction & Presentation Quality Bar

**Hand-painted 2D, skeletal animation, stylised not realistic.** Characters are painted as separate body parts and rigged with bones, giving fluid, interpolated motion instead of Flash-era frame flipping.

**Modular rigs** make six ages feasible solo: a small set of skeletons (humanoid, mounted, vehicle, mech) is rigged and animated once; a new unit is mostly new painted parts on an existing rig plus one or two bespoke attack animations.

**Lighting approach:** paint parts with soft, neutral lighting and let normal maps plus the game's 2D lights supply the drama. Heavily painted-in shadows fight dynamic lights.

"Better, smoother graphics, animation and VFX" is defined as passing this checklist, per unit and per effect, reviewed locally by the owner:

| Area | Quality bar |
| --- | --- |
| Smoothness | 60 fps playback; state changes (walk → attack → hit → death) blend over ~0.1 s instead of snapping; no foot sliding |
| Motion | Every attack has visible anticipation, contact and follow-through; cloth, hair and plumes lag behind with secondary motion |
| Silhouette | Role identifiable by shape alone at 100% zoom, in greyscale |
| Impact | Every hit has a flash, a sound and a particle response; heavy hits add hitstop and shake |
| VFX layering | Big effects are built from layers (flash, core, sparks, smoke, lingering decal), not a single particle burst |
| Lighting | Muzzle flashes, explosions and abilities light nearby units; each age has its own light colour and direction |
| Clarity | In a 30-vs-30 fight, a tester can still point to each side's units and the front line |
| Evolution | The age change reads as an event — slow-motion, shockwave, battlefield transformation, music change |

Full specs are in GDD §13. **If AI image tools are used for painted parts:** budget time for style consistency across 24+ units, keep source files, and note that Steam requires disclosure of AI-generated content.

## 12. Legal & Originality

Genre mechanics — a single lane, spawning units, evolving through historical ages — are common across many games and aren't what makes Age of War *Age of War*. Its name, characters, unit designs, art, audio and UI are. Timefront uses none of them: all units, names, art and sound are original, and the store page must not present the game as an Age of War title. The working title is a placeholder; check the final name for existing trademarks and store listings before publishing. (General guidance, not legal advice.)

## 13. Milestones

| # | Milestone | Exit criteria |
| --- | --- | --- |
| M0 | **Setup, paper & graybox** | Cloud environment script working (§10.3); repo with `CLAUDE.md`; pacing spreadsheet matching GDD §4; coloured boxes fighting in a Godot lane with economy and a scripted AI. Question answered: is it fun with boxes? |
| M1 | **Systems prototype** | Every GDD system in graybox across all six ages; Tactician AI; headless sim reporting every §6 sim metric; match logs written. |
| M2 | **Vertical slice** | Ages 1–2 at the §11 quality bar; post-match stats; sim green. **§7 blind test — go/no-go.** |
| M3 | **Content production** | Ages 3–6, remaining turrets and abilities, both doctrine picks, four AI personalities. Sim re-run and green after each age lands. |
| M4 | **Modes & shell** | Chronicle with teaching battles, settings, saves, accessibility, rebinding. |
| M5 | **Release prep** *(only if publishing)* | Performance pass on both §6 reference machines, platform exports, store page, trailer, demo build. |

M0 and M1 matter most. Art is the expensive part of this game; systems are cheap to change in graybox and expensive to change once 24 units are animated around them. That's why M1 runs all six ages in graybox *before* any age beyond 2 gets art.

## 14. Risks

- **Art volume is the real cost.** Six ages × four roles, plus turrets, bases, backdrops, projectiles and effects. Modular rigs and the M2 gate are the mitigations; §9 lists what to cut.
- **"More systems" can bury the hook.** Pillar 1 is the veto. v2 already merged the front-line rewards and dropped a doctrine pick; the Chronicle teaching battles introduce systems one at a time.
- **Balance is combinatorial.** Six ages × doctrine picks × four personalities won't hand-tune. The headless sim is load-bearing, not optional.
- **The sim can be wrong.** An AI that plays badly produces misleading balance data. Compare playtest match logs with sim logs (§7) and treat big gaps as AI bugs.
- **Visual quality can't be verified in the cloud.** Agents can build the animation and VFX systems but can't judge them. Every visual task needs a local review step, or quality will drift.
- **Performance** with many skeletal units plus particles. Unit caps, pooling and animation LOD are designed in from M1 (GDD §16).
- **Model availability.** Planning depends on Fable 5.1, which currently needs usage credits; the fallback in §10.2 applies.
- **Scope creep toward multiplayer.** Explicitly a non-goal for v1.

## 15. Open Questions

- Should the Chronicle unlock doctrines progressively, or should everything be available in Skirmish from the start?
- Controller support on PC — worth it for a mouse-driven game?
- Final name.

## 16. Next Documents

1. **Technical plan** (`docs/PLAN.md`) — written by **Fable 5.1** in a cloud session from this PRD and the GDD: project structure, scene and resource layout, data schema for units/ages/doctrines, the sim harness and match-log design, the environment setup script.
2. **Task list for M0–M1** (`docs/tasks/`) — also Fable 5.1: ordered tasks, each with its own done-condition and which model implements it.
3. **Implementation** — **Opus 5.5**, one task per session where practical, with Sonnet review before merge and Haiku data checks in the loop.

## 17. Sources

- [Age of War 2 — Walkthrough, Tips, Review (Jay is Games)](https://jayisgames.com/review/age-of-war-2.php) — polish over the original; criticisms around depth, replayability, difficulty spikes, stalemates, dominant anti-tank units, CPU usage.
- [Guide and Walkthrough for Age of War 2 (Max Games)](https://www.maxgames.com/guides/age-of-war-2.html) — core mechanics: unit counters, up to four turret slots, XP-driven evolution, upgrades, XP-costing specials.
- [Age of War 2 (Age of War Wiki)](https://aowg.fandom.com/wiki/Age_of_War_2) — seven ages, customisable troop movements.
- [Clash Royale: Elixir (wiki)](https://clashroyale.fandom.com/wiki/Elixir) — income that accelerates late in a match.
- [The Battle Cats: Level-up (wiki)](https://battle-cats.fandom.com/wiki/Level-up) — income rate and wallet cap as separate levers.
- [Stick War: Shield Wall (wiki)](https://stick-war.fandom.com/wiki/Shield_Wall) — whole-army stances.
- [Swords & Soldiers review (GameSpot)](https://www.gamespot.com/reviews/swords-and-soldiers-review/1900-6280800/) — shifting front line, coordinated pushes, bland environments criticised.
- [Godot 4.7 release notes](https://godotengine.org/releases/4.7/) — current stable engine version.
- [Spine: Purchase](https://esotericsoftware.com/spine-purchase) and [spine-godot runtime docs](https://en.esotericsoftware.com/spine-godot) — editions, pricing, Professional-only features.
- [Godot 4.3 web export particle issue #96030](https://github.com/godotengine/godot/issues/96030) — why to test web exports early.