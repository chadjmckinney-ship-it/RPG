extends Node
## Procedural sound: effects and music are synthesised at startup, no audio files needed.
## Music: a plucked-lute (Karplus-Strong) loop over a drone for day, a sparser one at
## night, and drums for combat. Tracks are built on a worker thread and crossfaded.

const RATE := 22050
const TRACKS := ["day", "night", "combat"]

var volume := {"master": 0.8, "music": 0.6, "sfx": 0.8}
var sfx: Dictionary = {}         # name -> AudioStreamWAV
var music: Dictionary = {}       # name -> AudioStreamWAV (filled when ready)
var _players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _wanted := ""
var _task := -1
var _built := {}
var _mutex := Mutex.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	_build_sfx()
	Settings.load_and_apply.call_deferred()
	_task = WorkerThreadPool.add_task(_build_music_all, false, "ashgrave music")

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for p in _players + [_music_a, _music_b]:
		p.stop()
		p.stream = null
	sfx.clear()
	music.clear()

# ---------------------------------------------------------------- playback

## Headless runs (tests, servers) use a dummy driver that never mixes, so skip playback.
var _silent := DisplayServer.get_name() == "headless"

func play(name: String, pitch_jitter := 0.08) -> void:
	if _silent or not sfx.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = sfx[name]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.volume_db = linear_to_db(maxf(0.0001, volume.master * volume.sfx))
			p.play()
			return

func set_music(name: String) -> void:
	_wanted = name

func _process(delta: float) -> void:
	_mutex.lock()
	for k in _built:
		music[k] = _built[k]
	_built.clear()
	_mutex.unlock()
	if _wanted != _current and music.has(_wanted) and not _silent:
		var swap := _music_a
		_music_a = _music_b
		_music_b = swap
		_music_a.stream = music[_wanted]
		_music_a.volume_db = -60.0
		_music_a.play()
		_current = _wanted
	var target := linear_to_db(maxf(0.0001, volume.master * volume.music * 0.7))
	_music_a.volume_db = move_toward(_music_a.volume_db, target, delta * 30.0)
	_music_b.volume_db = move_toward(_music_b.volume_db, -60.0, delta * 30.0)
	if _music_b.playing and _music_b.volume_db <= -59.0:
		_music_b.stop()

func is_music_ready(name: String) -> bool:
	return music.has(name)

# ---------------------------------------------------------------- synthesis helpers

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w

static func _env(i: int, n: int, attack := 0.01) -> float:
	var t := float(i) / RATE
	var a := minf(1.0, t / attack)
	return a * (1.0 - float(i) / n)

func _build_sfx() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# hit: noise burst over a low thump
	sfx.hit = _wav(_gen(0.16, func(i, n, t): return (rng.randf_range(-1, 1) * 0.5 + sin(TAU * 90.0 * t) * 0.6) * pow(1.0 - float(i) / n, 3.0)))
	# swing: filtered noise whoosh
	var lp := [0.0]
	sfx.swing = _wav(_gen(0.14, func(i, n, t):
		lp[0] += (rng.randf_range(-1, 1) - lp[0]) * 0.15
		return lp[0] * sin(PI * float(i) / n) * 1.4))
	# bow: plucked twang falling in pitch
	sfx.bow = _wav(_gen(0.22, func(i, n, t): return (fmod(t * (420.0 - t * 700.0), 1.0) * 2.0 - 1.0) * 0.35 * pow(1.0 - float(i) / n, 2.0)))
	# heal: rising chime
	sfx.heal = _wav(_gen(0.5, func(i, n, t): return (sin(TAU * (520.0 + t * 500.0) * t) * 0.3 + sin(TAU * 1040.0 * t) * 0.1) * _env(i, n, 0.02)))
	# coin: two bright pings
	sfx.coin = _wav(_gen(0.25, func(i, n, t): return sin(TAU * (1320.0 if t < 0.08 else 1760.0) * t) * 0.3 * pow(1.0 - float(i) / n, 2.0)))
	# click: short UI tick
	sfx.click = _wav(_gen(0.035, func(i, n, t): return sin(TAU * 900.0 * t) * 0.3 * (1.0 - float(i) / n)))
	# death: low descending moan
	sfx.death = _wav(_gen(0.6, func(i, n, t): return sin(TAU * (160.0 - t * 150.0) * t) * 0.45 * _env(i, n, 0.03)))
	# gather: rustle
	sfx.gather = _wav(_gen(0.25, func(i, n, t): return rng.randf_range(-1, 1) * 0.25 * absf(sin(t * 60.0)) * (1.0 - float(i) / n)))
	# alarm: two low horn notes (enemy spotted)
	sfx.alarm = _wav(_gen(0.7, func(i, n, t): return (fmod(t * (110.0 if t < 0.3 else 98.0), 1.0) * 2.0 - 1.0) * 0.18 * _env(i, n, 0.04)))
	# quest: a small fanfare
	sfx.quest = _wav(_gen(0.7, func(i, n, t):
		var f := 392.0 if t < 0.15 else (523.0 if t < 0.3 else 659.0)
		return (sin(TAU * f * t) * 0.25 + sin(TAU * f * 2.0 * t) * 0.08) * _env(i, n, 0.01)))

func _gen(seconds: float, f: Callable) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = f.call(i, n, float(i) / RATE)
	return out

# ---------------------------------------------------------------- music (worker thread)

func _build_music_all() -> void:
	for name in TRACKS:
		var w := build_track(name)
		_mutex.lock()
		_built[name] = w
		_mutex.unlock()

## D dorian-ish minor. Returns a looping stream.
static func build_track(name: String) -> AudioStreamWAV:
	var bpm := 66.0 if name == "day" else (52.0 if name == "night" else 112.0)
	var beats := 32 if name != "combat" else 32
	var beat := 60.0 / bpm
	var n := int(beats * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	# drone: root + fifth, slow swell
	var root := 73.42  # D2
	for i in n:
		var t := float(i) / RATE
		var swell := 0.6 + 0.4 * sin(TAU * t / (beats * beat) * 2.0)
		buf[i] = (sin(TAU * root * t) * 0.10 + sin(TAU * root * 1.5 * t) * 0.05 + sin(TAU * root * 2.0 * t) * 0.03) * swell * (0.6 if name == "combat" else 1.0)
	# melody: plucked notes from a minor pentatonic over a chord cycle
	var scale := [0, 3, 5, 7, 10, 12, 15]
	var chords := [0, -2, -4, -5] if name != "night" else [0, -4, -2, 0]
	var density := 0.8 if name == "day" else (0.45 if name == "night" else 0.9)
	var step := 0.5 if name != "night" else 1.0
	var pos := 0.0
	while pos < beats:
		var bar := int(pos / 8.0) % chords.size()
		if rng.randf() < density:
			var deg: int = scale[rng.randi_range(0, scale.size() - 1)]
			var semis: int = deg + chords[bar] + 12 + (12 if rng.randf() < 0.3 else 0)
			var f := 146.83 * pow(2.0, semis / 12.0)
			_pluck(buf, int(pos * beat * RATE), f, 0.22 if name != "combat" else 0.16, rng)
		pos += step
	if name == "combat":
		for b in beats:
			var at := int(b * beat * RATE)
			_drum(buf, at, 70.0 if b % 2 == 0 else 110.0, 0.5 if b % 4 == 0 else 0.3, rng)
			if b % 2 == 1:
				_drum(buf, at + int(beat * 0.5 * RATE), 180.0, 0.15, rng)
	# soft-limit
	for i in n:
		buf[i] = tanh(buf[i] * 1.2) * 0.8
	return _wav(buf, true)

## Karplus-Strong plucked string.
static func _pluck(buf: PackedFloat32Array, start: int, freq: float, amp: float, rng: RandomNumberGenerator) -> void:
	var period := maxi(2, int(RATE / freq))
	var ring := PackedFloat32Array()
	ring.resize(period)
	for k in period:
		ring[k] = rng.randf_range(-1.0, 1.0)
	var length := mini(int(RATE * 2.2), buf.size() - start)
	var idx := 0
	for i in length:
		var a := ring[idx]
		var b := ring[(idx + 1) % period]
		ring[idx] = (a + b) * 0.4965
		buf[start + i] += a * amp
		idx = (idx + 1) % period

static func _drum(buf: PackedFloat32Array, start: int, freq: float, amp: float, rng: RandomNumberGenerator) -> void:
	var length := mini(int(RATE * 0.35), buf.size() - start)
	for i in length:
		var t := float(i) / RATE
		var e := exp(-t * 14.0)
		buf[start + i] += (sin(TAU * freq * t * (1.0 - t * 0.8)) * 0.8 + rng.randf_range(-1, 1) * 0.15 * exp(-t * 40.0)) * e * amp
