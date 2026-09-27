# Figure Kit

Procedural 2D unit figures drawn with `CanvasItem` calls: human figures on rigs, their gear (helmets, shields, packs, hand weapons), mounts, chariots, siege engines and walkers. No textures and no dependencies beyond Godot 4.x built-ins.

Local space: the figure faces **+x**, its feet are at **y = 0**, and up is **−y**. To face left, mirror it with a negative x scale in the transform you pass to `FkPaint.begin`.

## Install

1. Copy `addons/figure_kit/` into your project.
2. Open the editor once, or run `godot --headless --path . --import`, so the `Fk*` classes register.

## Draw a unit

```gdscript
func _draw() -> void:
	FkPaint.begin(self, Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2(200, 300)))
	var spec := {"rig": "humanoid", "helmet": "kettle", "weapon": "sword", "shield": "kite",
		"look": FkLooks.BODIES[&"dwarf"], "palette": FkLooks.PALETTES[&"dwarf"][3], "team": Color("3a78d8")}
	FkUnits.draw(self, spec, {"walk": 0.0, "move": 0.0, "atk": -1.0, "t": 0.0, "flash": 0.0}, 7)
```

- **Transform.** `FkPaint.begin` sets the node-space transform for the next figure. Call it before every `FkUnits.draw`.
- **Seed.** The last argument (`seed`) picks per-individual variety: skin and hair from the look's pools, beards, idle phase.
- **Redrawing.** Call `queue_redraw()` every frame while animating.

## Spec keys

| Key | Rigs | Values |
|---|---|---|
| `rig` | all | `humanoid`, `mounted`, `chariot`, `ram`, `catapult`, `ballista`, `trebuchet`, `cannon`, `steamtank`, `golem`, `treant`, `skycannon`, `obelisk` |
| `look` | all | a race body preset, e.g. `FkLooks.BODIES[&"human" / &"elf" / &"dwarf"]`: body scale, head scale, beard, ears, long hair, skin and hair pools, glow colour |
| `palette` | all | `[main cloth, trim, metal]`, e.g. `FkLooks.PALETTES[race][era 0..5]` |
| `team` | all | team `Color`: tabards, banners, shield fields, caparisons |
| `helmet` | humanoid, mounted (rider) | `antler`, `band`, `brodie`, `cap`, `circlet`, `conical`, `crest`, `dwarf`, `galea`, `goggles`, `greathelm`, `hair`, `hood`, `horned`, `kettle`, `leaf`, `morion`, `rune`, `tricorne`, `visor` |
| `weapon` | humanoid, mounted, chariot | chopping: `club`, `sword`, `saber`, `gladius`, `axe`, `hammer`, `rune_hammer`, `leafblade`, `spellsword`, `baton`, `shovel`; polearm: `spear`, `lance`, `halberd`, `glaive`; thrown: `javelin`, `throwing_axe`, `sling`; `bow`, `starbow`, `staff`, `crossbow`; guns: `musket`, `rifle`, `arcane_rifle`, `rune_rifle`; `crew` (hands forward, for engine crews) |
| `shield` | humanoid, mounted | `round`, `kite`, `hide`, `scutum`, `leaf`, `moon`, `dwarf`, `plate`, `energy` |
| `runes` | humanoid with `shield: dwarf` | `true` adds a glowing rune ring |
| `pack` | humanoid | `quiver`, `javelins`, `axes`, `backpack`, `pouch`, `cell` |
| `cape` | humanoid | `true` for a team-coloured cape |
| `build` | humanoid | body scale multiplier (default 1.0) |
| `beast` | mounted, chariot | `horse`, `warhorse`, `barded`, `elfsteed`, `stag`, `elk`, `boar`, `warboar`, `ram`, `warram`, `bear` |
| `crew` | chariot, ram, catapult, ballista, trebuchet, cannon, obelisk | the crew's `helmet` value |
| `car` | chariot | `wood`, `bronze`, `iron` |
| `variant` | ram | `wood`, `iron`, `root` |
| | catapult | `onager`, `stone`, `moonfire` |
| | ballista | `light`, `great` |
| | cannon | `great`, `bombard`, `flame`, `rune` |
| `shot` | all | overrides the projectile name `FkUnits.shot` reports |
| `muzzle` | all | overrides the muzzle point `FkUnits.muzzle` reports |

## Pose keys

| Key | Meaning |
|---|---|
| `walk` | stride phase in radians (advance it with distance walked) |
| `move` | 0 (standing) … 1 (walking): the walk blend, eased by the caller. The legacy boolean `moving` is also read |
| `atk` | attack progress 0..1, or < 0 when not attacking. Contact happens at 0.35–0.55 (`FkUnits.swing`) |
| `t` | seconds, for idle motion (breathing, capes, flames) |
| `flash` | 0..1 hit flash (tints the figure toward white) |

## Queries

- `FkUnits.height(spec)`: the visual height in px, for health bars and selection.
- `FkUnits.muzzle(spec)`: where projectiles leave, in unit-local space.
- `FkUnits.shot(spec)`: the projectile kind (`arrow`, `bullet`, `bolt`, `ball`, `shell`, …), or `""` for melee.
- `FkUnits.wreck(spec)`: `"blast"`, `"siege"`, or `""` for a body that topples.
- `FkUnits.swing(atk)`: the attack curve (−1 at full wind-up, +1 at contact).
- `FkMounts.quadruped(ci, beast, team, pose, seed)`: a riderless beast.
- `FkPaint.*`: the drawing primitives (shaded polygons, tapered limbs, ellipses, halos, the transform stack). These are also useful for props.

## Rule

The kit depends on nothing outside this folder. Keep it that way: the origin project enforces this with `tests/test_fk_boundary.gd`.
