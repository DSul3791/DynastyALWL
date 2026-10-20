extends Node

# The weather layer of the sound stage (client only; DESIGN_IDEAS "Weather sounds"):
# rain on the ground, on leaves and on water, a gale, thunder, and the hush of snow
# and fog. It only PLAYS a weather state; it does not decide the weather.
#
# Hooks (nothing drives them yet but the Esc > Settings "Sound test weather" button):
# - set_weather(kind, intensity): a later server/world weather system calls this.
#   Kinds: clear, drizzle, rain, storm, snow, blizzard, fog. Intensity 0 to 1 scales it.
#   Sounds fade over several seconds as the state changes.
# - `wind` (0 to 1) is read by sound_stage.gd and adds to the wind strength, which also
#   drives the grass sway; `hush` and `calls` quiet the nature layer (ambient_life.gd reads
#   `calls`, frogs get `wet`).
# - signal lightning(at, distance_m): fired with each thunder roll, for a later sky flash.
#
# How the weather is meant to be chosen (owner, 2026-10-20, not built): by zone north to
# south, then season (dry zones stay dry, polar zones snow instead of rain), then the town
# spirit modifier (high spirit: mostly sun and light, warm nightly rain; low spirit: heavy
# storms, lightning, blizzards, days of rain, little sun), all in src/shared/weather.gd, a
# constant. The world's own weather (src/shared/weather.gd) now decides it; the client passes it to apply_state().
#
# Rain is quieter and duller where trees shelter you, with a patter on leaves instead; the
# water loop swells near ponds and rivers. Sounds: generated in assets/audio/weather/
# (make_weather.py); recordings in assets/audio/recorded/weather/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/weather/"
const RECORDED_DIR := "res://assets/audio/recorded/weather/"

# The strike event for the sky (Art direction): `lightning(at, distance_m)` fires at the moment of
# the flash, `at` being the strike's place relative to the player; the thunder sounds after
# distance / 343 m/s. strike(distance_m) makes one on demand (a script, a test, the weather system).
signal lightning(at: Vector3, distance_m: float)

const FADE_PER_SEC := 0.15              # about 7 s from none to full
const THUNDER_EVERY := [14.0, 45.0]     # at the full storm value; a weaker storm waits longer
const THUNDER_NEAR_M := 500.0           # closer than this: sharp crack and thud
const THUNDER_FAR_M := 1800.0           # farther than this: a low grumble
const THUNDER_MAX_DELAY_SEC := 10.0
const SPEED_OF_SOUND := 343.0

# kind: rain (0 to 1), wind (0 to 1), hush (0 to 1, quiets the nature layer), thunder (0 or 1),
# calls (share of the birds and insects still calling), wet (frogs like it).
const KINDS := {
	"clear": {"rain": 0.0, "wind": 0.0, "hush": 0.0, "thunder": 0.0, "calls": 1.0, "wet": 0.0},
	"drizzle": {"rain": 0.3, "wind": 0.1, "hush": 0.1, "thunder": 0.0, "calls": 0.6, "wet": 0.6},
	"rain": {"rain": 0.65, "wind": 0.25, "hush": 0.25, "thunder": 0.0, "calls": 0.3, "wet": 1.0},
	"storm": {"rain": 1.0, "wind": 0.75, "hush": 0.4, "thunder": 1.0, "calls": 0.05, "wet": 0.5},
	"snow": {"rain": 0.0, "wind": 0.05, "hush": 0.5, "thunder": 0.0, "calls": 0.5, "wet": 0.0},
	"blizzard": {"rain": 0.0, "wind": 1.0, "hush": 0.3, "thunder": 0.0, "calls": 0.0, "wet": 0.0},
	"fog": {"rain": 0.0, "wind": 0.0, "hush": 0.2, "thunder": 0.0, "calls": 0.8, "wet": 0.0},
}
const LOOP_DB := {"rain_light": -14.0, "rain_heavy": -13.0, "rain_leaves": -15.0, "rain_water": -17.0, "wind_storm": -18.0}
const THUNDER_DB := -4.0

var forced: bool = false                # --weather=KIND on the command line: the world weather is ignored
var kind: String = "clear"
var intensity: float = 1.0
var rain: float = 0.0                   # smoothed levels the sound stage and HUD read
var wind: float = 0.0
var hush: float = 0.0
var calls: float = 1.0
var wet: float = 0.0
var thunders_played: int = 0
var last_thunder: String = ""
var storm_level: float = 1.0            # the world's storm value (0 to 1) behind the current kind

var _stage                              # SoundStage
var _ambient                            # AmbientLife (zone weights)
var _rng := RandomNumberGenerator.new()
var _loops: Dictionary = {}             # name -> AudioStreamPlayer
var _streams: Dictionary = {}
var _thunder_in: float = 20.0
var _pending: Array = []                # [seconds left, AudioStreamPlayer, stream] thunder waiting for its delay
var _under: float = 1.0                 # 0 underwater, 1 in the air, smoothed


func setup(stage, ambient) -> void:
	_stage = stage
	_ambient = ambient
	_rng.randomize()
	SoundStage._make_bus("Weather")

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weather="):
			forced = true
			set_weather(arg.get_slice("=", 1), 1.0)
			rain = float(KINDS[kind]["rain"]) * intensity
			wind = float(KINDS[kind]["wind"]) * intensity
			calls = float(KINDS[kind]["calls"])

	for name in LOOP_DB:
		var list: Array = _variants(name)

		if list.is_empty():
			continue

		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = list[0]
		player.bus = "Weather"
		player.volume_db = -80.0
		add_child(player)

		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true

		_loops[name] = player


# The one hook a weather system calls. Unknown kinds are ignored.
func set_weather(new_kind: String, new_intensity: float = 1.0) -> void:
	if not KINDS.has(new_kind):
		return

	kind = new_kind
	intensity = clampf(new_intensity, 0.0, 1.0)


# Plays the world's weather state (src/shared/weather.gd: rain, snow, storm, wind, each 0 to 1).
func apply_state(state: Dictionary) -> void:
	if forced:
		return

	storm_level = float(state.get("storm", 0.0))
	var snow: float = float(state.get("snow", 0.0))
	var storm: float = float(state.get("storm", 0.0))
	var rain_level: float = float(state.get("rain", 0.0))
	var gale: float = float(state.get("wind", 0.0))

	if snow > 0.1:
		set_weather("blizzard" if snow > 0.5 and gale > 0.7 else "snow", clampf(snow * 1.5, 0.3, 1.0))
	elif storm > 0.4 and rain_level > 0.3:
		set_weather("storm", clampf(storm, 0.4, 1.0))
	elif rain_level > 0.5:
		set_weather("rain", clampf(rain_level, 0.5, 1.0))
	elif rain_level > 0.08:
		set_weather("drizzle", clampf(rain_level * 2.5, 0.3, 1.0))
	else:
		set_weather("clear", 1.0)


func voices_playing() -> int:
	var count: int = _pending.size()

	for name in _loops:
		if _loops[name].playing and not _loops[name].stream_paused:
			count += 1

	return count


func update(delta: float, body: CharacterBody3D, underwater: bool) -> void:
	var target: Dictionary = KINDS[kind]
	var step: float = FADE_PER_SEC * delta
	rain = move_toward(rain, float(target["rain"]) * intensity, step)
	wind = move_toward(wind, float(target["wind"]) * intensity, step)
	hush = move_toward(hush, float(target["hush"]) * intensity, step)
	calls = move_toward(calls, lerpf(1.0, float(target["calls"]), intensity), step)
	wet = move_toward(wet, float(target["wet"]) * intensity, step)
	_under = move_toward(_under, 0.12 if underwater else 1.0, delta * 3.0)
	_ambient.weather_calls = calls
	_ambient.weather_wet = wet
	var cover: float = float(_ambient.weights["forest"])
	var water: float = float(_ambient.weights["water"])
	var heavy: float = smoothstep(0.4, 0.9, rain)
	var light: float = minf(rain * 2.0, 1.0) * (1.0 - 0.6 * heavy)
	_loop("rain_light", light * (1.0 - 0.5 * cover))
	_loop("rain_heavy", heavy * (1.0 - 0.5 * cover))
	_loop("rain_leaves", minf(rain * 1.6, 1.0) * cover)
	_loop("rain_water", minf(rain * 1.6, 1.0) * water)
	_loop("wind_storm", clampf(wind - 0.2, 0.0, 1.0) / 0.8)
	_thunder(delta)


func _loop(name: String, level: float) -> void:
	if not _loops.has(name):
		return

	var player: AudioStreamPlayer = _loops[name]
	level *= _under

	if level < 0.005:
		if player.playing:
			player.stream_paused = true

		player.volume_db = -80.0
		return

	player.stream_paused = false

	if not player.playing:
		player.play(_rng.randf() * 10.0)

	player.volume_db = float(LOOP_DB[name]) + linear_to_db(level)


# Thunder in a storm: a roll now and then, from far to near, heard after the light.
func _thunder(delta: float) -> void:
	for n in range(_pending.size() - 1, -1, -1):
		_pending[n][0] -= delta

		if _pending[n][0] <= 0.0:
			var voice: AudioStreamPlayer = _pending[n][1]
			voice.play()
			_pending.remove_at(n)

	if float(KINDS[kind]["thunder"]) * intensity <= 0.0 or rain < 0.5:
		return

	_thunder_in -= delta * _ambient.time_scale

	if _thunder_in > 0.0:
		return

	var strength: float = clampf(1.0 if forced else storm_level, 0.2, 1.0) * maxf(intensity, 0.3)
	_thunder_in = _rng.randf_range(float(THUNDER_EVERY[0]), float(THUNDER_EVERY[1])) / strength
	# More strikes land close in a fierce storm: distance leans nearer as the storm grows.
	strike(_rng.randf_range(250.0, 2800.0) * pow(_rng.randf(), 0.5 + 0.5 * (1.0 - strength)))


# One lightning strike `distance_m` away (in a random direction unless `angle` is given):
# emits `lightning` now and plays the thunder after the sound has travelled. Near strikes crack,
# far ones grumble. Returns false when no thunder sound exists.
func strike(distance_m: float, angle: float = -1.0) -> bool:
	var sound_name: String = "thunder_near" if distance_m < THUNDER_NEAR_M else ("thunder_far" if distance_m > THUNDER_FAR_M else "thunder")
	var list: Array = _variants(sound_name)

	if list.is_empty():
		list = _variants("thunder")

	if list.is_empty():
		return false

	var voice: AudioStreamPlayer = AudioStreamPlayer.new()
	voice.stream = list[_rng.randi_range(0, list.size() - 1)]
	voice.bus = "Weather"
	voice.volume_db = THUNDER_DB - distance_m / 400.0 + (3.0 if distance_m < THUNDER_NEAR_M else 0.0) + _rng.randf_range(-2.0, 1.0)
	voice.pitch_scale = _rng.randf_range(0.9, 1.1)
	add_child(voice)
	voice.finished.connect(voice.queue_free)

	if angle < 0.0:
		angle = _rng.randf() * TAU

	lightning.emit(Vector3(cos(angle) * distance_m, 0.0, sin(angle) * distance_m), distance_m)
	_pending.append([minf(distance_m / SPEED_OF_SOUND, THUNDER_MAX_DELAY_SEC), voice])
	thunders_played += 1
	last_thunder = "%s %.0f m" % [sound_name, distance_m]
	return true


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list


func _exit_tree() -> void:
	for name in _loops:
		_loops[name].stop()
		_loops[name].stream = null

	_streams.clear()
