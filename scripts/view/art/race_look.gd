class_name RaceLook
extends RefCounted
## Per-race presentation (GDD §5.7): body proportions, skin and hair, magic glow, clothing palettes
## per age and the unit style table keyed by the neutral per-slot unit ids. Races never differ in
## stats — only in how a slot looks (this file) and what it is called (data/races/*.tres).

const BODY := {
	&"human": {"body": Vector2(1.0, 1.0), "head": 1.0, "beard": 3, "ears": "round", "long_hair": false,
		"skin": [Color("e0b48c"), Color("c68e62"), Color("8d5a3b"), Color("f1cfae"), Color("a86e48")],
		"hair": [Color("2a1d14"), Color("5a3a1f"), Color("1a1a1a"), Color("8a5a2b")],
		"glow": Color("c49bff")},
	# Elves: taller and slighter, long hair, pointed ears, no beards.
	&"elf": {"body": Vector2(0.9, 1.1), "head": 0.93, "beard": 0, "ears": "pointed", "long_hair": true,
		"skin": [Color("f3dcc4"), Color("e8c9a8"), Color("d9b89a"), Color("f6e4d2")],
		"hair": [Color("eadba0"), Color("c9ccd2"), Color("3a2a1a"), Color("9a5a30"), Color("f2ecd8")],
		"glow": Color("9fe4ff")},
	# Dwarves: short and broad, big heads and braided beards on everyone.
	&"dwarf": {"body": Vector2(1.24, 0.76), "head": 1.1, "beard": 1, "ears": "round", "long_hair": false,
		"skin": [Color("e8ae8a"), Color("d6946e"), Color("c47f5c"), Color("edbd9c")],
		"hair": [Color("9a3c1a"), Color("5a3a1f"), Color("cfc6b6"), Color("2a1d14"), Color("d49a4c")],
		"glow": Color("ffb347")},
}

## Clothing per race and age: [main cloth, secondary/trim, metal].
const CLOTH := {
	&"human": [
		[Color("8a6a45"), Color("5e4630"), Color("9a9080")],  # Stone: hides
		[Color("e6dcc6"), Color("b07a3a"), Color("c28c3e")],  # Bronze: linen + bronze
		[Color("9a4f3e"), Color("5a3b2c"), Color("b8bcc2")],  # Iron: legion red + steel
		[Color("7d7f85"), Color("4c4a48"), Color("b5b9bf")],  # Medieval: mail + steel
		[Color("3b3f58"), Color("c9b27a"), Color("a5a9ae")],  # Gunpowder: coats + brass
		[Color("4a3b62"), Color("b8914a"), Color("c9a45c")],  # Arcane: violet coats + brass
	],
	&"elf": [
		[Color("6f7a45"), Color("4a5230"), Color("c2b89a")],  # Stone: moss and bone
		[Color("d8d2a8"), Color("7a8a4a"), Color("d0aa52")],  # Bronze: pale linen + gold
		[Color("5d7a50"), Color("3e5236"), Color("c8ccc4")],  # Iron: forest green + silver
		[Color("3e6b52"), Color("d6d0b8"), Color("dfe3e8")],  # Medieval: green and ivory
		[Color("2f4f5f"), Color("c9c0a0"), Color("cfd6dc")],  # Gunpowder: teal + pale silver
		[Color("2c3a66"), Color("bfc8ff"), Color("e0e4f5")],  # Arcane: midnight + moonsilver
	],
	&"dwarf": [
		[Color("7a5a3e"), Color("4d3a28"), Color("8a8078")],  # Stone: furs + flint
		[Color("8a5a36"), Color("5a3a22"), Color("c07a36")],  # Bronze: leather + copper
		[Color("6a4a38"), Color("3e2e24"), Color("8e939a")],  # Iron: leather + iron
		[Color("6a3434"), Color("3a2a24"), Color("a0a4aa")],  # Medieval: oxblood + steel
		[Color("4a4a52"), Color("b8913a"), Color("9aa0a6")],  # Gunpowder: slate + brass
		[Color("3a3440"), Color("d09a3a"), Color("7a8090")],  # Arcane: soot + gold, rune-iron
	],
}

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
	return BODY.get(race, BODY[&"human"])


static func palette(race: StringName, age: int) -> Array:
	return CLOTH.get(race, CLOTH[&"human"])[clampi(age - 1, 0, 5)]


static func style(race: StringName, unit_id: StringName) -> Dictionary:
	var table: Dictionary = STYLES.get(race, STYLES[&"human"])
	return table.get(unit_id, STYLES[&"human"].get(unit_id, {}))
