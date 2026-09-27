class_name RaceLook
extends RefCounted
## Per-race presentation (GDD §5.7): the unit style table keyed by the neutral per-slot unit ids.
## Body proportions, skin, hair, glow and era palettes are figure-kit presets (FkLooks). Races never differ in
## stats — only in how a slot looks (this file) and what it is called (data/races/*.tres).


## Style per race and unit slot. Humanoid keys: helmet, weapon, shield, pack, cape, build.
## Other rigs: mounted (beast), chariot (beast, crew, weapon, car), ram / catapult / ballista /
## cannon (variant, crew), trebuchet, steamtank, golem, treant, skycannon, obelisk.
## `shot` overrides the projectile the rig or weapon would fire.
const STYLES := {
	&"human": {
		&"stone_vanguard": {"rig": "humanoid", "helmet": "hair", "weapon": "club", "shield": "hide"},
		&"stone_ranged": {"rig": "humanoid", "helmet": "band", "weapon": "sling", "pack": "pouch"},
		&"stone_heavy": {"rig": "mounted", "beast": "boar", "helmet": "hair", "weapon": "spear"},
		&"bronze_vanguard": {"rig": "humanoid", "helmet": "crest", "weapon": "spear", "shield": "round"},
		&"bronze_ranged": {"rig": "humanoid", "helmet": "cap", "weapon": "javelin", "pack": "javelins"},
		&"bronze_heavy": {"rig": "chariot", "beast": "horse", "crew": "crest", "weapon": "spear", "car": "bronze"},
		&"bronze_siege": {"rig": "ram", "variant": "wood", "crew": "hair"},
		&"iron_vanguard": {"rig": "humanoid", "helmet": "galea", "weapon": "gladius", "shield": "scutum"},
		&"iron_ranged": {"rig": "humanoid", "helmet": "conical", "weapon": "bow", "pack": "quiver"},
		&"iron_heavy": {"rig": "mounted", "beast": "barded", "helmet": "conical", "weapon": "lance"},
		&"iron_siege": {"rig": "catapult", "variant": "onager", "crew": "galea"},
		&"medieval_vanguard": {"rig": "humanoid", "helmet": "kettle", "weapon": "sword", "shield": "kite"},
		&"medieval_ranged": {"rig": "humanoid", "helmet": "hood", "weapon": "bow", "pack": "quiver"},
		&"medieval_heavy": {"rig": "mounted", "beast": "warhorse", "helmet": "greathelm", "weapon": "lance"},
		&"medieval_siege": {"rig": "trebuchet", "crew": "kettle"},
		&"gunpowder_vanguard": {"rig": "humanoid", "helmet": "morion", "weapon": "halberd"},
		&"gunpowder_ranged": {"rig": "humanoid", "helmet": "tricorne", "weapon": "musket", "pack": "backpack"},
		&"gunpowder_heavy": {"rig": "mounted", "beast": "horse", "helmet": "morion", "weapon": "saber"},
		&"gunpowder_siege": {"rig": "cannon", "variant": "great", "crew": "tricorne"},
		&"arcane_vanguard": {"rig": "humanoid", "helmet": "visor", "weapon": "spellsword", "shield": "energy", "cape": true},
		&"arcane_ranged": {"rig": "humanoid", "helmet": "goggles", "weapon": "arcane_rifle", "pack": "cell"},
		&"arcane_heavy": {"rig": "steamtank"},
		&"arcane_siege": {"rig": "skycannon"},
	},
	&"elf": {
		&"stone_vanguard": {"rig": "humanoid", "helmet": "antler", "weapon": "leafblade", "shield": "leaf"},
		&"stone_ranged": {"rig": "humanoid", "helmet": "hair", "weapon": "bow", "pack": "quiver"},
		&"stone_heavy": {"rig": "mounted", "beast": "stag", "helmet": "antler", "weapon": "spear"},
		&"bronze_vanguard": {"rig": "humanoid", "helmet": "leaf", "weapon": "spear", "shield": "leaf"},
		&"bronze_ranged": {"rig": "humanoid", "helmet": "circlet", "weapon": "javelin", "pack": "javelins"},
		&"bronze_heavy": {"rig": "chariot", "beast": "elk", "crew": "leaf", "weapon": "bow", "car": "wood"},
		&"bronze_siege": {"rig": "ram", "variant": "root", "crew": "circlet"},
		&"iron_vanguard": {"rig": "humanoid", "helmet": "leaf", "weapon": "glaive", "shield": "leaf"},
		&"iron_ranged": {"rig": "humanoid", "helmet": "hood", "weapon": "bow", "pack": "quiver", "cape": true},
		&"iron_heavy": {"rig": "mounted", "beast": "elk", "helmet": "leaf", "weapon": "lance"},
		&"iron_siege": {"rig": "ballista", "variant": "light", "crew": "leaf"},
		&"medieval_vanguard": {"rig": "humanoid", "helmet": "circlet", "weapon": "leafblade", "shield": "leaf", "cape": true},
		&"medieval_ranged": {"rig": "humanoid", "helmet": "hood", "weapon": "bow", "pack": "quiver", "cape": true},
		&"medieval_heavy": {"rig": "mounted", "beast": "elfsteed", "helmet": "leaf", "weapon": "lance"},
		&"medieval_siege": {"rig": "ballista", "variant": "great", "crew": "leaf"},
		&"gunpowder_vanguard": {"rig": "humanoid", "helmet": "leaf", "weapon": "glaive", "shield": "leaf", "cape": true},
		&"gunpowder_ranged": {"rig": "humanoid", "helmet": "circlet", "weapon": "starbow", "pack": "quiver", "cape": true},
		&"gunpowder_heavy": {"rig": "mounted", "beast": "stag", "helmet": "antler", "weapon": "spear"},
		&"gunpowder_siege": {"rig": "catapult", "variant": "moonfire", "crew": "circlet", "shot": "orb"},
		&"arcane_vanguard": {"rig": "humanoid", "helmet": "leaf", "weapon": "spellsword", "shield": "moon", "cape": true},
		&"arcane_ranged": {"rig": "humanoid", "helmet": "circlet", "weapon": "staff", "cape": true},
		&"arcane_heavy": {"rig": "treant"},
		&"arcane_siege": {"rig": "obelisk", "crew": "circlet"},
	},
	&"dwarf": {
		&"stone_vanguard": {"rig": "humanoid", "helmet": "hair", "weapon": "hammer", "shield": "hide"},
		&"stone_ranged": {"rig": "humanoid", "helmet": "band", "weapon": "sling", "pack": "pouch"},
		&"stone_heavy": {"rig": "mounted", "beast": "ram", "helmet": "hair", "weapon": "axe"},
		&"bronze_vanguard": {"rig": "humanoid", "helmet": "dwarf", "weapon": "axe", "shield": "dwarf"},
		&"bronze_ranged": {"rig": "humanoid", "helmet": "cap", "weapon": "throwing_axe", "pack": "axes"},
		&"bronze_heavy": {"rig": "chariot", "beast": "ram", "crew": "dwarf", "weapon": "axe", "car": "iron"},
		&"bronze_siege": {"rig": "ram", "variant": "iron", "crew": "dwarf"},
		&"iron_vanguard": {"rig": "humanoid", "helmet": "dwarf", "weapon": "hammer", "shield": "dwarf"},
		&"iron_ranged": {"rig": "humanoid", "helmet": "dwarf", "weapon": "crossbow", "pack": "quiver"},
		&"iron_heavy": {"rig": "mounted", "beast": "warboar", "helmet": "horned", "weapon": "axe"},
		&"iron_siege": {"rig": "catapult", "variant": "stone", "crew": "dwarf"},
		&"medieval_vanguard": {"rig": "humanoid", "helmet": "horned", "weapon": "axe", "shield": "dwarf"},
		&"medieval_ranged": {"rig": "humanoid", "helmet": "dwarf", "weapon": "crossbow", "pack": "quiver"},
		&"medieval_heavy": {"rig": "mounted", "beast": "bear", "helmet": "horned", "weapon": "hammer"},
		&"medieval_siege": {"rig": "cannon", "variant": "bombard", "crew": "dwarf", "shot": "shell"},
		&"gunpowder_vanguard": {"rig": "humanoid", "helmet": "horned", "weapon": "axe", "shield": "dwarf"},
		&"gunpowder_ranged": {"rig": "humanoid", "helmet": "dwarf", "weapon": "musket", "pack": "backpack"},
		&"gunpowder_heavy": {"rig": "mounted", "beast": "warram", "helmet": "horned", "weapon": "axe"},
		&"gunpowder_siege": {"rig": "cannon", "variant": "flame", "crew": "dwarf", "shot": "orb"},
		&"arcane_vanguard": {"rig": "humanoid", "helmet": "rune", "weapon": "rune_hammer", "shield": "dwarf"},
		&"arcane_ranged": {"rig": "humanoid", "helmet": "rune", "weapon": "rune_rifle", "pack": "cell"},
		&"arcane_heavy": {"rig": "golem"},
		&"arcane_siege": {"rig": "cannon", "variant": "rune", "crew": "rune", "shot": "bolt"},
	},
}

const IDS := [&"human", &"elf", &"dwarf"]


static func look(race: StringName) -> Dictionary:
	return FkLooks.BODIES.get(race, FkLooks.BODIES[&"human"])


static func palette(race: StringName, age: int) -> Array:
	return FkLooks.PALETTES.get(race, FkLooks.PALETTES[&"human"])[clampi(age - 1, 0, 5)]


static func style(race: StringName, unit_id: StringName) -> Dictionary:
	var table: Dictionary = STYLES.get(race, STYLES[&"human"])
	return table.get(unit_id, STYLES[&"human"].get(unit_id, {}))
