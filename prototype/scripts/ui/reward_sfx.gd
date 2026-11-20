class_name FTRewardSfx
extends RefCounted

## Placeholder chiptune blips for the reward screen, synthesized in code the
## first time each is played (no files to import). Swap any of them for a real
## sound by returning a preloaded stream from `stream()`.
##   tick    reel tick while a card spins
##   hover   aiming at a card
##   lock    a card's reel stops
##   thud    the cache lands
##   crack   a shot on the cache (pitch rises per hit)
##   open    the cache bursts open
##   coin    one coin reaches the wallet
##   shine   an uncommon card locks
##   rare    a rare card locks
##   pickup  a picked item lands in the loadout
##   scrap   a round is removed from the arsenal
##   whoosh  cards dismissed

const RATE := 22050
static var _cache := {}

static func play(parent: Node, sound: StringName, pitch := 1.0, volume_db := -9.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream(sound)
	player.pitch_scale = pitch
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

static func stream(sound: StringName) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _to_wav(_build(sound))
	return _cache[sound]

## Builds every sound now, so the first crack doesn't hitch.
static func prewarm() -> void:
	for sound in [&"tick", &"hover", &"lock", &"thud", &"crack", &"open", &"coin", &"shine", &"rare", &"pickup", &"scrap", &"whoosh"]:
		stream(sound)

static func _build(sound: StringName) -> PackedFloat32Array:
	match sound:
		&"tick":
			return _tone(1500, 1150, 0.03, &"square", 0.25)
		&"hover":
			return _tone(880, 880, 0.025, &"square", 0.18)
		&"lock":
			return _mix(_tone(330, 150, 0.09, &"square", 0.4), _noise(0.05, 0.35), 0.0)
		&"thud":
			return _mix(_tone(110, 45, 0.18, &"sine", 0.9), _noise(0.12, 0.45, true), 0.0)
		&"crack":
			return _mix(_noise(0.1, 0.6), _tone(200, 80, 0.12, &"square", 0.4), 0.0)
		&"open":
			var out := _noise(0.28, 0.5, false, true)
			var t := 0.12
			for note in [523.0, 659.0, 784.0, 1047.0, 1319.0]:
				out = _mix(out, _tone(note, note, 0.07, &"square", 0.3), t)
				t += 0.055
			return _mix(out, _tone(1568, 1568, 0.45, &"triangle", 0.4, 0.25), t)
		&"coin":
			return _mix(_tone(988, 988, 0.05, &"square", 0.25, 1.0), _tone(1319, 1319, 0.16, &"square", 0.25), 0.05)
		&"shine":
			return _arpeggio([784.0, 988.0, 1175.0, 1568.0], 0.05, &"triangle", 0.4, 0.3)
		&"rare":
			var fanfare := _arpeggio([523.0, 659.0, 784.0, 988.0, 1047.0, 1319.0, 1568.0, 2093.0], 0.045, &"square", 0.22, 0.6)
			return _mix(fanfare, _tone(1047, 1047, 0.7, &"triangle", 0.3, 0.3), 0.36)
		&"pickup":
			return _arpeggio([659.0, 880.0, 1109.0, 1319.0, 1760.0], 0.035, &"triangle", 0.45, 0.25)
		&"scrap":
			return _mix(_noise(0.16, 0.5), _tone(260, 55, 0.28, &"square", 0.35), 0.0)
		&"whoosh":
			return _noise(0.18, 0.25, true, true)
	return PackedFloat32Array()

# One note sliding from `from_hz` to `to_hz`. `sustain` holds the volume for
# that share of the note before it decays.
static func _tone(from_hz: float, to_hz: float, seconds: float, wave: StringName, volume: float, sustain := 0.0) -> PackedFloat32Array:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += lerpf(from_hz, to_hz, t) / RATE
		var cycle := fposmod(phase, 1.0)
		var value := 0.0
		match wave:
			&"square": value = 1.0 if cycle < 0.5 else -1.0
			&"triangle": value = 4.0 * absf(cycle - 0.5) - 1.0
			_: value = sin(phase * TAU)
		var envelope := 1.0 if t < sustain else pow(1.0 - (t - sustain) / (1.0 - sustain + 0.0001), 2.0)
		envelope *= minf(1.0, i / 40.0)  # no click at the start
		out[i] = value * envelope * volume
	return out

# White noise; `dull` averages it (lower, thuddier), `swell` ramps it up
# before it decays (a whoosh).
static func _noise(seconds: float, volume: float, dull := false, swell := false) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var last := 0.0
	for i in count:
		var t := float(i) / count
		var value := rng.randf_range(-1.0, 1.0)
		if dull:
			last = lerpf(last, value, 0.15)
			value = last * 2.5
		var envelope := sin(t * PI) if swell else pow(1.0 - t, 2.0)
		out[i] = value * envelope * volume
	return out

static func _arpeggio(notes: Array, step: float, wave: StringName, volume: float, tail: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in notes.size():
		var last := i == notes.size() - 1
		out = _mix(out, _tone(notes[i], notes[i], tail if last else step * 1.6, wave, volume, 0.3), i * step)
	return out

# `b` added into `a`, starting `offset` seconds in; grows `a` as needed.
static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: float) -> PackedFloat32Array:
	var start := int(offset * RATE)
	if a.size() < start + b.size():
		a.resize(start + b.size())
	for i in b.size():
		a[start + i] += b[i]
	return a

static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
