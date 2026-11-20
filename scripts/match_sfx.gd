extends Node
## Client-only, bounded one-shot mixer. Replace assets/sfx/<cue>.wav to
## override the original synthesized fallback without touching gameplay.
const SAMPLE_RATE: int = 22050
const WORLD_VOICES: int = 20
const UI_VOICES: int = 4
# duration, nominal gain, max simultaneous voices, priority
const CUES: Dictionary = {
	"laser": [0.22, 0.20, 4, 2],
	"blaster": [0.12, 0.15, 4, 1],
	"missile": [0.62, 0.23, 3, 3],
	"explosion": [0.55, 0.27, 4, 4],
	"heavy_explosion": [1.0, 0.32, 2, 5],
	"mining": [0.28, 0.085, 2, 0],
	"repair": [0.25, 0.085, 2, 0],
	"tractor": [0.22, 0.075, 2, 0],
	"select": [0.075, 0.21, 2, 1],
	"click": [0.07, 0.18, 2, 1],
	"order": [0.13, 0.23, 2, 2],
	"queue": [0.19, 0.24, 2, 2],
	"complete": [0.36, 0.28, 2, 3],
	"notice": [0.26, 0.22, 2, 3],
}
var streams: Dictionary = {}
var world_pool: Array[Dictionary] = []
var ui_pool: Array[Dictionary] = []
var candidates: Dictionary = {}
var last_played: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for kind in CUES:
		var path: String = "res://assets/sfx/%s.wav" % kind
		var variants: Array[AudioStream] = []
		if ResourceLoader.exists(path, "AudioStream"):
			var replacement := load(path) as AudioStream
			if replacement != null:
				variants.append(replacement)
		if variants.is_empty():
			for variant in range(3 if kind in ["laser", "blaster", "missile", "explosion", "heavy_explosion"] else 1):
				variants.append(_synthesize(kind, variant))
		streams[kind] = variants
	for i in range(WORLD_VOICES + UI_VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		var voice: Dictionary = {"player": player, "kind": "", "gain": 0.0, "priority": 0}
		if i < WORLD_VOICES:
			world_pool.append(voice)
		else:
			ui_pool.append(voice)

static func spatial_gain(distance: float, radius: float, zoom_level: float) -> float:
	# Distance from camera center plus camera altitude. At overview the
	# battlefield is audible but quiet; beyond the audible radius it is silent.
	var relative: float = distance / maxf(1.0, radius)
	if relative >= 1.8:
		return 0.0
	var edge: float = 1.0 - smoothstep(1.0, 1.8, relative)
	return edge * sqrt(clampf(zoom_level / 8.0, 0.04, 1.0)) / (1.0 + 3.0 * relative * relative)

func offer(kind: String, gain: float) -> void:
	# Keep only the loudest candidates for each cue during a snapshot.
	if gain < 0.035:
		return
	var values: Array = candidates.get(kind, [])
	var limit: int = int(CUES[kind][2])
	if values.size() < limit:
		values.append(gain)
	else:
		var weakest: int = 0
		for i in range(1, values.size()):
			if float(values[i]) < float(values[weakest]):
				weakest = i
		if gain > float(values[weakest]):
			values[weakest] = gain
	candidates[kind] = values

func flush() -> void:
	for kind in ["heavy_explosion", "explosion", "missile", "laser", "blaster", "mining", "repair", "tractor"]:
		var values: Array = candidates.get(kind, [])
		if values.is_empty():
			continue
		# Real time, not simulation speed. Collapse dense volleys into a few
		# voices and leave room for explosions / UI even at 5x.
		var now: int = Time.get_ticks_msec()
		var gap: int = 350 if kind in ["mining", "repair", "tractor"] else 85
		if now - int(last_played.get(kind, -100000)) < gap:
			continue
		last_played[kind] = now
		values.sort()
		values.reverse()
		for gain in values:
			play_cue(kind, float(gain), true)
	candidates.clear()

func play_cue(kind: String, gain: float = 1.0, spatial: bool = false) -> void:
	if not streams.has(kind) or gain <= 0.0:
		return
	var bus_index: int = AudioServer.get_bus_index("SFX")
	if bus_index >= 0 and AudioServer.is_bus_mute(bus_index):
		return
	if not spatial:
		var now: int = Time.get_ticks_msec()
		if now - int(last_played.get(kind, -100000)) < 65:
			return
		last_played[kind] = now
	var spec: Array = CUES[kind]
	var loudness: float = clampf(gain, 0.0, 1.0) * float(spec[1])
	var priority: int = int(spec[3])
	var pool: Array[Dictionary] = world_pool if spatial else ui_pool
	var free: Dictionary = {}
	var weakest: Dictionary = {}
	var same: Dictionary = {}
	var active: int = 0
	for voice in pool:
		var player: AudioStreamPlayer = voice["player"]
		if not player.playing:
			if free.is_empty():
				free = voice
			continue
		if voice["kind"] == kind:
			active += 1
			if same.is_empty() or float(voice["gain"]) < float(same["gain"]):
				same = voice
		if weakest.is_empty() or _score(voice) < _score(weakest):
			weakest = voice
	var chosen: Dictionary = free
	if active >= int(spec[2]):
		chosen = same
		if loudness <= float(same["gain"]) * 1.15:
			return
	elif chosen.is_empty():
		chosen = weakest
		if chosen.is_empty() or float(priority) * 0.07 + loudness <= _score(chosen):
			return
	var player: AudioStreamPlayer = chosen["player"]
	var variants: Array = streams[kind]
	player.stop()
	player.stream = variants[rng.randi_range(0, variants.size() - 1)]
	player.volume_db = linear_to_db(maxf(0.0001, loudness))
	player.pitch_scale = rng.randf_range(0.90, 1.10) if spatial else rng.randf_range(0.98, 1.02)
	chosen["kind"] = kind
	chosen["gain"] = loudness
	chosen["priority"] = priority
	player.play()

func _score(voice: Dictionary) -> float:
	return float(voice["priority"]) * 0.07 + float(voice["gain"])

func _synthesize(kind: String, variant: int) -> AudioStreamWAV:
	var duration: float = float(CUES[kind][0])
	var count: int = ceili(duration * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 90210 + int(kind.hash()) + variant * 7919
	var low: float = 0.0
	var phase: float = 0.0
	var detune: float = 1.0 + float(variant - 1) * 0.08
	for i in range(count):
		var t: float = float(i) / SAMPLE_RATE
		var u: float = t / duration
		var noise: float = noise_rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.045 if kind == "heavy_explosion" else 0.12)
		var frequency: float = 440.0
		var sample: float = 0.0
		match kind:
			"laser":
				frequency = lerpf(1900.0, 190.0, pow(u, 0.55))
				sample = (sin(phase) * 0.65 + sin(phase * 1.51) * 0.18 + noise * 0.15) * exp(-4.0 * u)
			"blaster":
				frequency = lerpf(690.0, 110.0, u)
				sample = (sin(phase) * 0.50 + noise * 0.42) * exp(-7.0 * u)
			"missile":
				frequency = lerpf(180.0, 380.0, u)
				var launch: float = (low * 1.8 + sin(phase) * 0.28 + noise * 0.16) * exp(-3.5 * u)
				var impact: float = (low * 1.5 + sin(TAU * 70.0 * t) * 0.36) * exp(-12.0 * maxf(0.0, u - 0.63)) if u >= 0.63 else 0.0
				sample = launch + impact
			"explosion", "heavy_explosion":
				var heavy: bool = kind == "heavy_explosion"
				frequency = lerpf(100.0 if heavy else 160.0, 32.0 if heavy else 55.0, u)
				sample = (sin(phase) * 0.36 + low * 1.8 + noise * 0.28 * exp(-10.0 * u)) * exp(-4.6 * u)
			"mining", "repair", "tractor":
				frequency = 120.0 + 90.0 * u if kind == "mining" else (520.0 + 250.0 * u if kind == "repair" else 280.0 - 100.0 * u)
				sample = (sin(phase) * 0.48 + sin(phase * 2.01) * 0.18 + low * 0.35) * (0.75 + 0.25 * sin(TAU * 19.0 * t))
			"click", "select":
				frequency = 850.0 if kind == "click" else 1200.0
				sample = (sin(phase) * 0.65 + noise * 0.2) * exp(-6.0 * u)
			"order", "queue", "complete", "notice":
				frequency = 440.0 if kind == "order" else 520.0
				if u > 0.38:
					frequency *= 1.5
				if kind == "complete" and u > 0.68:
					frequency *= 1.33
				var local: float = fmod(u, 0.38)
				sample = (sin(phase) * 0.65 + sin(phase * 2.0) * 0.12) * exp(-4.0 * local)
		phase += TAU * frequency * detune / SAMPLE_RATE
		var envelope: float = minf(1.0, t / 0.004) * minf(1.0, (duration - t) / 0.025)
		pcm.encode_s16(i * 2, roundi(clampf(sample * envelope, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav
