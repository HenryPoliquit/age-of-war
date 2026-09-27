class_name FkLooks
extends RefCounted
## Preset library. BODIES: per-race proportions (body scale x/y, head scale), beard style, ears,
## long hair, skin and hair colour pools, magic glow. PALETTES: per race, six era palettes of
## [main cloth, secondary/trim, metal] — Stone, Bronze, Iron, Medieval, Gunpowder, Arcane.

const BODIES := {
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

## Per race, six era palettes: [main cloth, secondary/trim, metal].
const PALETTES := {
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
