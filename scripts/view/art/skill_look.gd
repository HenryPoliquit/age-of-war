class_name SkillLook
extends RefCounted
## How each skill looks for each race (GDD §5.7, §7). Every race fields the same six skills with the same
## footprint, timing and damage: only what falls, what it leaves and how it glows differ. SkillFx reads
## these tables; nothing here touches the sim.
##
## Keys used by SkillFx:
##   shot   what flies: rock crystal runestone | pilum arrow axe | fireball thorn boulder | ball moon runeshell |
##          lance star bolt. (Stampede uses `beast`/`body` instead.)
##   from   sky (steep drop) | home (lobbed from the caster's base) | diag (a slant from behind the caster)
##   body / lit / glow   the object's shade, its highlight, and the additive glow it gives off
##   trail  ember | smoke | leaf | petal | spark | none, spawned behind the object as it flies
##   land   what the impact throws up: dust | shards | embers | leaves | sparks | smoke
##   r      size (px radius, or shaft length for arrows)

const LOOKS := {
	&"human": {
		# A herd of boars kicking up road dust.
		"stampede": {"beast": "boar", "body": Color("6a4a34"), "glow": Color(1.0, 0.8, 0.5), "trail": "smoke", "land": "dust",
			"dust": Color(0.74, 0.62, 0.46, 0.6)},
		# Quarried boulders thrown down from above, burning at the edges.
		"rockfall": {"shot": "rock", "from": "sky", "body": Color("8b857a"), "lit": Color("d2cab6"), "glow": Color(1.0, 0.62, 0.3),
			"trail": "ember", "land": "dust", "r": 34.0},
		"volley": {"shot": "pilum", "from": "diag", "body": Color("5a4630"), "lit": Color("d6dbe2"), "glow": Color(1.0, 0.95, 0.8),
			"trail": "none", "land": "dust", "r": 60.0},
		# Trebuchet stones, alight, lobbed from the caster's walls.
		"bombardment": {"shot": "fireball", "from": "home", "body": Color("5d4a3c"), "lit": Color("ffcf80"), "glow": Color(1.0, 0.5, 0.18),
			"trail": "ember", "land": "embers", "r": 23.0},
		# Iron round shot with a smoke trail and a muzzle flash at the gate.
		"cannonade": {"shot": "ball", "from": "home", "body": Color("1c1c20"), "lit": Color("d9dadd"), "glow": Color(1.0, 0.7, 0.3),
			"trail": "smoke", "land": "embers", "r": 19.0},
		# A lance of light hurled down from the sky.
		"starfall": {"shot": "lance", "from": "sky", "body": Color("ffe9a8"), "lit": Color("ffffff"), "glow": Color("ffd06b"),
			"trail": "spark", "land": "sparks", "r": 36.0},
	},
	&"elf": {
		# A herd of stags trailing petals and light.
		"stampede": {"beast": "stag", "body": Color("b39d74"), "glow": Color(0.62, 1.0, 0.7), "trail": "petal", "land": "leaves",
			"dust": Color(0.85, 0.95, 0.75, 0.5)},
		# Stone Rain: living crystal shards streaking in slantwise, leaving green motes.
		"rockfall": {"shot": "crystal", "from": "diag", "body": Color("4fae83"), "lit": Color("dcffec"), "glow": Color(0.5, 1.0, 0.75),
			"trail": "leaf", "land": "shards", "r": 31.0},
		"volley": {"shot": "arrow", "from": "diag", "body": Color("9c7a4c"), "lit": Color("e8f6df"), "glow": Color(0.62, 1.0, 0.72),
			"trail": "spark", "land": "leaves", "r": 52.0},
		# Hail of Thorns: great briar spikes raining down.
		"bombardment": {"shot": "thorn", "from": "sky", "body": Color("5b4a2a"), "lit": Color("a8e070"), "glow": Color(0.55, 0.95, 0.4),
			"trail": "leaf", "land": "leaves", "r": 56.0},
		# Moonfire: silver orbs falling in pillars of moonlight.
		"cannonade": {"shot": "moon", "from": "sky", "body": Color("c9e6ff"), "lit": Color("ffffff"), "glow": Color(0.62, 0.86, 1.0),
			"trail": "spark", "land": "sparks", "r": 21.0},
		# Stars falling from the night.
		"starfall": {"shot": "star", "from": "diag", "body": Color("fff3b0"), "lit": Color("ffffff"), "glow": Color(0.7, 0.9, 1.0),
			"trail": "spark", "land": "sparks", "r": 27.0},
	},
	&"dwarf": {
		# A herd of rams, sparks off the hooves.
		"stampede": {"beast": "ram", "body": Color("6b625a"), "glow": Color(1.0, 0.7, 0.3), "trail": "spark", "land": "shards",
			"dust": Color(0.6, 0.55, 0.5, 0.55)},
		# Boulder Toss: rune-carved boulders lobbed from behind the lines.
		"rockfall": {"shot": "runestone", "from": "home", "body": Color("4c4640"), "lit": Color("9a9086"), "glow": Color(1.0, 0.55, 0.18),
			"trail": "ember", "land": "embers", "r": 36.0},
		"volley": {"shot": "axe", "from": "diag", "body": Color("8a6a42"), "lit": Color("e4e8ed"), "glow": Color(1.0, 0.65, 0.25),
			"trail": "spark", "land": "shards", "r": 24.0},
		# Rockslide: an avalanche of boulders tumbling in.
		"bombardment": {"shot": "boulder", "from": "diag", "body": Color("6d655c"), "lit": Color("b5aa9a"), "glow": Color(1.0, 0.7, 0.35),
			"trail": "smoke", "land": "dust", "r": 26.0},
		# Grand Cannonade: rune-forged shells trailing furnace fire.
		"cannonade": {"shot": "runeshell", "from": "home", "body": Color("34302c"), "lit": Color("ffb45a"), "glow": Color(1.0, 0.5, 0.15),
			"trail": "ember", "land": "embers", "r": 21.0},
		# Thunder Rune: a rune circle wakes and the storm strikes it.
		"starfall": {"shot": "bolt", "from": "sky", "body": Color("bfe3ff"), "lit": Color("ffffff"), "glow": Color(0.55, 0.78, 1.0),
			"trail": "none", "land": "sparks", "r": 24.0},
	},
}

## The colour of an enemy skill's warning marker, whatever the enemy's team colour.
const DANGER := Color(1.0, 0.36, 0.28)

## The mark a skill puts on the ground, for the aim reticle and the warning. A **circle** is a small round
## target (Rockfall, Starfall); a **field** is a piece of land (Volley, Cannonade). A sweep (Stampede,
## Bombardment) runs from the caster's gate to the enemy's and needs no mark at all.
const FOOTPRINT := {"rockfall": "circle", "starfall": "circle", "volley": "field", "cannonade": "field"}


## "circle", "field", or "" for a skill with no mark.
static func footprint(ability_id: Variant) -> String:
	return FOOTPRINT.get(String(ability_id), "")


static func for_skill(race: StringName, ability_id: String) -> Dictionary:
	var table: Dictionary = LOOKS.get(race, LOOKS[&"human"])
	return table.get(ability_id, LOOKS[&"human"].get(ability_id, {}))
