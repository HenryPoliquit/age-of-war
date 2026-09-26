class_name Synth
extends RefCounted
## Procedural placeholder audio: every sound is synthesized at startup from noise, oscillators,
## one-pole filters and Karplus-Strong plucks, so the repo carries no audio assets until real
## recordings replace them. Sounds are grouped by damage type so counters are audible (GDD §13.8).

const RATE := 22050


static func _to_wav(buf: PackedFloat32Array, rate := RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


# ---------------------------------------------------------------------------
# Building blocks (in place on a buffer)

## Filtered noise burst. lp/hp are one-pole coefficients (0..1, higher = brighter); decay in seconds.
static func noise(b: PackedFloat32Array, rng: RandomNumberGenerator, amp: float, decay: float, lp := 1.0, hp := 0.0, start := 0.0, attack := 0.002) -> void:
	var y := 0.0
	var low := 0.0
	var i0 := int(start * RATE)
	for i in range(i0, b.size()):
		var t := float(i - i0) / RATE
		var env := minf(1.0, t / attack) * exp(-t / decay)
		if env < 0.0005 and t > attack:
			break
		y += lp * (rng.randf_range(-1.0, 1.0) - y)
		low += hp * (y - low)
		b[i] += (y - low) * amp * env


## Sine with exponential pitch glide f0 → f1 over its decay.
static func tone(b: PackedFloat32Array, amp: float, f0: float, f1: float, decay: float, start := 0.0, attack := 0.003, shape := "sine") -> void:
	var ph := 0.0
	var i0 := int(start * RATE)
	for i in range(i0, b.size()):
		var t := float(i - i0) / RATE
		var env := minf(1.0, t / attack) * exp(-t / decay)
		if env < 0.0005 and t > attack:
			break
		var f := f1 + (f0 - f1) * exp(-t / (decay * 0.5))
		ph += TAU * f / RATE
		var v := sin(ph)
		match shape:
			"square":
				v = signf(v) * 0.6
			"saw":
				v = fposmod(ph / TAU, 1.0) * 2.0 - 1.0
			"tri":
				v = absf(fposmod(ph / TAU, 1.0) * 4.0 - 2.0) - 1.0
		b[i] += v * amp * env


## Karplus-Strong plucked string.
static func pluck(b: PackedFloat32Array, rng: RandomNumberGenerator, amp: float, freq: float, start: float, length: float, damp := 0.996) -> void:
	var n := maxi(2, int(RATE / freq))
	var ring := PackedFloat32Array()
	ring.resize(n)
	for k in n:
		ring[k] = rng.randf_range(-1.0, 1.0)
	var i0 := int(start * RATE)
	var i1 := mini(b.size(), i0 + int(length * RATE))
	var idx := 0
	for i in range(i0, i1):
		var nxt := (idx + 1) % n
		var v := ring[idx]
		ring[idx] = (v + ring[nxt]) * 0.5 * damp
		idx = nxt
		b[i] += v * amp


static func _normalize(b: PackedFloat32Array, peak := 0.9) -> void:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k


# ---------------------------------------------------------------------------
# Sound effects

static func build_sfx() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var out := {}
	var b: PackedFloat32Array
	# Slash: bright noise crack + metallic ring.
	b = _buf(0.22)
	noise(b, rng, 0.8, 0.03, 0.9, 0.35)
	tone(b, 0.25, 2600, 2400, 0.06)
	tone(b, 0.18, 3900, 3700, 0.05)
	_normalize(b, 0.7); out["slash"] = _to_wav(b)
	# Pierce hit: dull thock.
	b = _buf(0.15)
	noise(b, rng, 0.9, 0.025, 0.35)
	tone(b, 0.5, 420, 180, 0.04)
	_normalize(b, 0.6); out["pierce"] = _to_wav(b)
	# Bow / sling / javelin release: short whoosh.
	b = _buf(0.22)
	noise(b, rng, 0.6, 0.06, 0.5, 0.2, 0.0, 0.03)
	tone(b, 0.25, 700, 250, 0.05)
	_normalize(b, 0.45); out["bow"] = _to_wav(b)
	# Musket / rifle shot.
	b = _buf(0.45)
	noise(b, rng, 1.0, 0.035, 0.95, 0.05)
	noise(b, rng, 0.6, 0.18, 0.12)
	tone(b, 0.5, 160, 70, 0.08)
	_normalize(b, 0.8); out["gun"] = _to_wav(b)
	# Cannon / howitzer / mortar.
	b = _buf(1.1)
	noise(b, rng, 1.0, 0.05, 0.8)
	noise(b, rng, 0.9, 0.4, 0.05)
	tone(b, 0.9, 90, 38, 0.35)
	_normalize(b, 0.9); out["cannon"] = _to_wav(b)
	# Blast (explosion).
	b = _buf(1.4)
	noise(b, rng, 1.0, 0.08, 0.6)
	noise(b, rng, 1.0, 0.55, 0.04)
	tone(b, 0.8, 70, 30, 0.45)
	for k in 8:
		noise(b, rng, 0.25, 0.01, 0.9, 0.3, 0.15 + rng.randf() * 0.6)
	_normalize(b, 0.9); out["blast"] = _to_wav(b)
	# Siege impact: heavy thud + crumble.
	b = _buf(1.0)
	tone(b, 1.0, 110, 45, 0.18)
	noise(b, rng, 0.7, 0.3, 0.15)
	for k in 12:
		noise(b, rng, 0.2, 0.015, 0.6, 0.2, 0.08 + rng.randf() * 0.6)
	_normalize(b, 0.9); out["siege"] = _to_wav(b)
	# Energy bolt.
	b = _buf(0.3)
	tone(b, 0.6, 1800, 380, 0.09, 0.0, 0.002, "square")
	tone(b, 0.3, 2400, 900, 0.07, 0.0, 0.002, "saw")
	_normalize(b, 0.5); out["zap"] = _to_wav(b)
	# Death: soft body fall.
	b = _buf(0.25)
	noise(b, rng, 0.9, 0.06, 0.12)
	tone(b, 0.5, 160, 90, 0.06)
	_normalize(b, 0.45); out["death"] = _to_wav(b)
	# Stampede rumble.
	b = _buf(1.6)
	for k in 22:
		tone(b, 0.35, 80 + rng.randf() * 40, 50, 0.06, k * 0.065 + rng.randf() * 0.02)
		noise(b, rng, 0.25, 0.05, 0.1, 0.0, k * 0.065)
	_normalize(b, 0.8); out["stampede"] = _to_wav(b)
	# Ability cast: rising whoosh.
	b = _buf(0.9)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += (0.02 + t * 0.4) * (rng.randf_range(-1, 1) - y)
		b[i] = y * sin(PI * t / 0.9)
	tone(b, 0.3, 300, 900, 0.5, 0.2)
	_normalize(b, 0.6); out["ability_cast"] = _to_wav(b)
	# UI.
	b = _buf(0.06)
	tone(b, 0.8, 1500, 1200, 0.012)
	_normalize(b, 0.35); out["ui_click"] = _to_wav(b)
	b = _buf(0.22)
	tone(b, 0.6, 140, 120, 0.08, 0.0, 0.003, "square")
	tone(b, 0.4, 147, 125, 0.08, 0.0, 0.003, "square")
	_normalize(b, 0.35); out["ui_error"] = _to_wav(b)
	b = _buf(0.8)
	tone(b, 0.5, 880, 880, 0.25)
	tone(b, 0.5, 1320, 1320, 0.3, 0.09)
	_normalize(b, 0.4); out["ability_ready"] = _to_wav(b)
	b = _buf(1.0)
	tone(b, 0.5, 660, 660, 0.35, 0.0, 0.003, "tri")
	tone(b, 0.35, 990, 990, 0.4, 0.0, 0.003, "tri")
	_normalize(b, 0.4); out["tide"] = _to_wav(b)
	# Evolution fanfare: rising major arpeggio with shimmer.
	b = _buf(2.2)
	var notes := [261.6, 329.6, 392.0, 523.3, 659.3]
	for k in notes.size():
		tone(b, 0.5, notes[k], notes[k], 0.9, k * 0.11, 0.01, "tri")
		tone(b, 0.2, notes[k] * 2.0, notes[k] * 2.0, 0.6, k * 0.11)
	noise(b, rng, 0.15, 0.8, 0.9, 0.6, 0.5, 0.3)
	_normalize(b, 0.7); out["evolve"] = _to_wav(b)
	# Escalation horn.
	b = _buf(1.8)
	tone(b, 0.6, 110, 110, 1.0, 0.0, 0.15, "saw")
	tone(b, 0.4, 165, 165, 1.0, 0.0, 0.15, "saw")
	var lp := 0.0
	for i in b.size():
		lp += 0.08 * (b[i] - lp)
		b[i] = lp
	_normalize(b, 0.7); out["escalation"] = _to_wav(b)
	return out


# ---------------------------------------------------------------------------
# Music: per-age loops in two layers (GDD §13.8 "one theme per age, in stems; an intensity layer
# rises with lane pressure"). Returns {"base": PackedFloat32Array, "drums": PackedFloat32Array}.

const AGE_MUSIC := [
	{"bpm": 88, "root": 146.8, "scale": [0, 3, 5, 7, 10], "voice": "flute", "drum": "tom"},
	{"bpm": 100, "root": 146.8, "scale": [0, 2, 3, 5, 7, 9, 10], "voice": "lyre", "drum": "frame"},
	{"bpm": 96, "root": 130.8, "scale": [0, 2, 3, 5, 7, 8, 10], "voice": "lute", "drum": "frame"},
	{"bpm": 112, "root": 123.5, "scale": [0, 2, 3, 5, 7, 8, 11], "voice": "strings", "drum": "snare"},
	{"bpm": 120, "root": 110.0, "scale": [0, 1, 3, 5, 7, 8, 10], "voice": "brass", "drum": "clank"},
	{"bpm": 124, "root": 110.0, "scale": [0, 3, 5, 7, 10], "voice": "synth", "drum": "electro"},
]


static func build_music(age: int) -> Dictionary:
	var spec: Dictionary = AGE_MUSIC[age - 1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 + age
	var beat := 60.0 / float(spec.bpm)
	var bars := 4
	var length := beat * 4.0 * bars
	var base := _buf(length)
	var drums := _buf(length)
	var root: float = spec.root
	var scale: Array = spec.scale
	var prog := [0, 3, 4, 0] if age != 6 else [0, 5, 3, 4]
	# Drone / pad per bar.
	for bar in bars:
		var deg: int = prog[bar]
		var f := root * pow(2.0, scale[deg % scale.size()] / 12.0)
		var t0 := bar * beat * 4.0
		match spec.voice:
			"strings", "brass", "synth":
				for mult in [0.5, 1.0, 1.5]:
					_pad(base, 0.16, f * mult, t0, beat * 4.0, "saw" if spec.voice != "strings" else "tri")
			_:
				_pad(base, 0.2, f * 0.5, t0, beat * 4.0, "sine")
				_pad(base, 0.1, f * 0.75, t0, beat * 4.0, "sine")
	# Melody: plucked or blown notes on eighths, seeded pattern repeated each two bars.
	var pattern := []
	for k in 16:
		pattern.append(-1 if rng.randf() < 0.35 else rng.randi_range(0, scale.size() - 1))
	for bar in bars:
		for k in 8:
			var d: int = pattern[(bar % 2) * 8 + k]
			if d < 0:
				continue
			var f := root * 2.0 * pow(2.0, (scale[d] + scale[prog[bar] % scale.size()]) / 12.0)
			var t := (bar * 8 + k) * beat * 0.5
			match spec.voice:
				"lyre", "lute":
					pluck(base, rng, 0.35, f, t, beat * 1.5, 0.995 if spec.voice == "lyre" else 0.992)
				"flute":
					tone(base, 0.18, f, f, beat * 0.5, t, 0.04)
				"synth":
					tone(base, 0.12, f * 2.0, f * 2.0, beat * 0.2, t, 0.003, "saw")
				_:
					tone(base, 0.12, f, f, beat * 0.4, t, 0.02, "tri")
	# Percussion layer.
	for step in bars * 16:
		var t := step * beat * 0.25
		var on_beat := step % 4 == 0
		match spec.drum:
			"tom":
				if on_beat or step % 16 == 10:
					tone(drums, 0.8, 140, 70, 0.12, t)
			"frame":
				if on_beat:
					tone(drums, 0.7, 110, 60, 0.12, t)
				if step % 2 == 1 and rng.randf() < 0.7:
					noise(drums, rng, 0.2, 0.03, 0.6, 0.3, t)
			"snare":
				if on_beat:
					tone(drums, 0.7, 90, 50, 0.1, t)
				if step % 8 == 4:
					noise(drums, rng, 0.6, 0.08, 0.7, 0.2, t)
				if step % 2 == 1:
					noise(drums, rng, 0.15, 0.02, 0.7, 0.3, t)
			"clank":
				if on_beat:
					tone(drums, 0.8, 80, 45, 0.1, t)
				if step % 4 == 2:
					tone(drums, 0.25, 900, 850, 0.04, t, 0.001, "square")
				if step % 8 == 4:
					noise(drums, rng, 0.5, 0.06, 0.8, 0.3, t)
			"electro":
				if on_beat:
					tone(drums, 0.9, 120, 45, 0.14, t)
				if step % 2 == 1:
					noise(drums, rng, 0.15, 0.015, 0.95, 0.6, t)
				if step % 8 == 4:
					noise(drums, rng, 0.5, 0.07, 0.7, 0.2, t)
	_normalize(base, 0.55)
	_normalize(drums, 0.6)
	return {"base": base, "drums": drums}


static func _pad(b: PackedFloat32Array, amp: float, f: float, start: float, length: float, shape: String) -> void:
	var i0 := int(start * RATE)
	var n := int(length * RATE)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		if i0 + i >= b.size():
			break
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.4) * minf(1.0, (length - t) / 0.4)
		ph += TAU * f * (1.0 + 0.003 * sin(t * 5.0)) / RATE
		var v := sin(ph)
		if shape == "saw":
			v = fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		elif shape == "tri":
			v = absf(fposmod(ph / TAU, 1.0) * 4.0 - 2.0) - 1.0
		lp += 0.12 * (v - lp)
		b[i0 + i] += lp * amp * env
