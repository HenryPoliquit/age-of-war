class_name AudioDirector
extends Node
## Plays synthesized SFX (pooled, rate-limited, positional) and streams the per-age music with an
## intensity layer, crossfading when the player's age changes (GDD §13.5 step 5, §13.8).

const POOL := 14
const MIN_GAP := 0.045

static var _sfx_cache: Dictionary = {}
static var _music_cache: Dictionary = {}
static var _music_pending: Dictionary = {}
static var _mutex := Mutex.new()

var _players: Array[AudioStreamPlayer2D] = []
var _ui: AudioStreamPlayer
var _next := 0
var _last_played := {}
var _music: AudioStreamPlayer
var _gen: AudioStreamGeneratorPlayback
var _age := 1
var _prev_age := 1
var _fade := 1.0
var _pos := 0
var _intensity := 0.0
var target_intensity := 0.0


static func ensure_buses() -> void:
	for name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, name)
			AudioServer.set_bus_send(i, "Master")


func _ready() -> void:
	ensure_buses()
	if _sfx_cache.is_empty():
		_sfx_cache = Synth.build_sfx()
	for i in POOL:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.max_distance = 2600.0
		p.attenuation = 1.2
		add_child(p)
		_players.append(p)
	_ui = AudioStreamPlayer.new()
	_ui.bus = "UI"
	add_child(_ui)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = Synth.RATE
	stream.buffer_length = 0.4
	_music.stream = stream
	add_child(_music)
	_music.play()
	_gen = _music.get_stream_playback()
	for a in range(1, 7):
		_request_music(a)


## Generates an age's loops on a worker thread so evolving never hitches.
static func _request_music(age: int) -> void:
	_mutex.lock()
	var busy := _music_cache.has(age) or _music_pending.has(age)
	if not busy:
		_music_pending[age] = true
	_mutex.unlock()
	if busy:
		return
	WorkerThreadPool.add_task(func():
		var m := Synth.build_music(age)
		_mutex.lock()
		_music_cache[age] = m
		_music_pending.erase(age)
		_mutex.unlock())


func play(name: String, pos := Vector2.INF, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	var stream: AudioStreamWAV = _sfx_cache.get(name)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -1.0)) < MIN_GAP:
		return
	_last_played[name] = now
	if pos == Vector2.INF:
		_ui.stream = stream
		_ui.volume_db = volume_db
		_ui.play()
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func start(age: int) -> void:
	_request_music(age)
	_age = age
	_prev_age = age
	_fade = 1.0


func set_age(age: int) -> void:
	if age == _age:
		return
	_request_music(age)
	_prev_age = _age
	_age = age
	_fade = 0.0


func _process(delta: float) -> void:
	_intensity = move_toward(_intensity, target_intensity, delta * 0.35)
	_fade = minf(1.0, _fade + delta / 2.5)
	if _gen == null:
		return
	_mutex.lock()
	var cur: Dictionary = _music_cache.get(_age, {})
	var old: Dictionary = _music_cache.get(_prev_age, {})
	_mutex.unlock()
	if cur.is_empty():
		cur = old
	if cur.is_empty():
		return
	var frames := _gen.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var base: PackedFloat32Array = cur.base
	var drums: PackedFloat32Array = cur.drums
	var obase: PackedFloat32Array = old.get("base", base)
	var odrums: PackedFloat32Array = old.get("drums", drums)
	var dv := 0.15 + 0.85 * _intensity
	var f := _fade
	for i in frames:
		var k := (_pos + i) % base.size()
		var v := (base[k] + drums[k] * dv) * f
		if f < 1.0:
			var ko := (_pos + i) % obase.size()
			v += (obase[ko] + odrums[ko] * dv) * (1.0 - f)
		buf[i] = Vector2(v, v) * 0.6
	_gen.push_buffer(buf)
	_pos = (_pos + frames) % base.size()
