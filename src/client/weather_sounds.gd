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
#   `calls`, frogs get `frogs`).
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
const THUNDER_MAX_DELAY_SEC := 4.0       # the light-to-sound wait is shortened so a far strike still feels connected
const THUNDER_DELAY_SCALE := 0.5         # of the real travel time, then capped
# Distant thunder is dulled by the air and by cover: air_bands.gd puts it on a low-passed child of Weather (one filter per band).
const AirBands := preload("res://src/client/air_bands.gd")
const SPEED_OF_SOUND := 343.0

# kind: rain (0 to 1), wind (0 to 1), hush (0 to 1, quiets the nature layer), thunder (0 or 1),
# calls (share of the birds and insects still calling), frogs (share of frog calls: more than 1 in
# light rain, which they like, none in storms, snow and blizzards; owner 2026-10-20).
const TICK_SEC := 0.05                 # the whole weather mix runs at 20 Hz on the accumulated time
const KINDS := {
	"clear": {"rain": 0.0, "wind": 0.0, "hush": 0.0, "thunder": 0.0, "calls": 1.0, "frogs": 1.0},
	"drizzle": {"rain": 0.3, "wind": 0.1, "hush": 0.1, "thunder": 0.0, "calls": 0.5, "frogs": 1.6},
	"rain": {"rain": 0.65, "wind": 0.25, "hush": 0.25, "thunder": 0.0, "calls": 0.15, "frogs": 1.2},
	"storm": {"rain": 1.0, "wind": 0.75, "hush": 0.4, "thunder": 1.0, "calls": 0.0, "frogs": 0.0},
	"snow": {"rain": 0.0, "wind": 0.05, "hush": 0.5, "thunder": 0.0, "calls": 0.4, "frogs": 0.0},
	"blizzard": {"rain": 0.0, "wind": 1.0, "hush": 0.3, "thunder": 0.0, "calls": 0.0, "frogs": 0.0},
	"fog": {"rain": 0.0, "wind": 0.0, "hush": 0.2, "thunder": 0.0, "calls": 0.8, "frogs": 0.8},
}
const LOOP_DB := {"rain_light": -14.0, "rain_heavy": -13.0, "rain_leaves": -15.0, "rain_roof": -14.0, "rain_water": -17.0, "wind_storm": -18.0,
	"rain_stone": -14.0, "rain_mud": -15.0, "rain_litter": -16.0, "rain_snow": -23.0}
# Rain on the ground under the player (open sky only; under a canopy the leaves take it): how much of the plain
# open-ground bed (rain_light / rain_heavy) stays when that ground has its own loop.
const GROUND_BED_KEEP := {"stone": 0.35, "mud": 0.4, "litter": 0.5, "snow": 0.2}
const GROUND_EASE_SEC := 1.5
const THUNDER_DB := -4.0
# The ground remembers the weather (owner's job 17): it soaks in rain and dries slowly, snow settles
# while it snows and melts above freezing. The footsteps read ground_wet and ground_snow.
const WET_RISE_SEC := 25.0              # rain from 0.25: dry to soaked in this long
const WET_DRY_SEC := 240.0
const SNOW_RISE_SEC := 60.0
const SNOW_MELT_SEC := 120.0            # above MELT_C
const HUSH_EASE_SEC := 4.0              # the snow hush follows the snow over this long
const SNOW_STAY_SEC := 900.0            # below it, snow stays a long while
const MELT_C := 1.0
const ICE_C := -2.0                     # air this cold freezes still water
const ICE_RISE_SEC := 900.0             # freezing over (real seconds, at that cold)
const ICE_MELT_SEC := 300.0             # open again above MELT_C
const COVER_EVERY_SEC := 0.4
const DRY_UNDER_SEC := 4.0               # under a canopy the ground dries this fast
const DRIP_DB := -22.0
const DRIP_EVERY := [0.5, 2.2]          # seconds between drips under trees at full rain

var forced_cover: bool = false          # --covered on the command line: always under a canopy (headless check)
var forced_ground: String = ""          # --rain-ground=NAME on the command line: the rain falls on that ground (headless check)
var forced: bool = false                # --weather=KIND on the command line: the world weather is ignored
var kind: String = "clear"
var intensity: float = 1.0
var rain: float = 0.0                   # smoothed levels the sound stage and HUD read
var wind: float = 0.0
var hush: float = 0.0
var calls: float = 1.0
var frogs: float = 1.0                  # share of frog calls in this weather (can top 1 in light rain)
var thunders_played: int = 0
var ground_wet: float = 0.0             # 0 dry .. 1 soaked: puddle splashes, mud
var snow_hush: float = 0.0             # 0..1 the quiet of snow: lying snow 0.8, plus 0.2 while it falls; eased over 4 s (sound_stage dulls wind, nature and steps by it)
var ground_snow: float = 0.0            # 0 bare .. 1 snow lies: footsteps crunch
var drips_played: int = 0
var temp_c: float = 10.0
var ice_cover: float = 0.0              # 0 open water .. 1 still water frozen over (ice_sounds.gd)
var roofed: float = 0.0                 # 0 no roof overhead, 1 under a roof (lean-to and the like; smoothed): its rain is the roof patter, not leaves
var covered: float = 0.0                # 0 open, 1 under a canopy (smoothed); the ground there stays dry
var last_thunder: String = ""
var world_wind: float = 0.35            # the world's wind (0.15 calm to 1 storm), smoothed: sets the wind sound
var storm_level: float = 1.0            # the world's storm value (0 to 1) behind the current kind

var _wind_target: float = 0.35
var _stage                              # SoundStage
var _ambient                            # AmbientLife (zone weights)
var _rng := RandomNumberGenerator.new()
var _loops: Dictionary = {}             # name -> AudioStreamPlayer
var _streams: Dictionary = {}
var _thunder_in: float = 20.0
var ground_class: String = "soft"       # what the rain falls on under the player (HUD): stone, mud, litter, snow or soft
var _ground_w: Dictionary = {"stone": 0.0, "mud": 0.0, "litter": 0.0, "snow": 0.0}
var _pending: Array = []                # [seconds left, AudioStreamPlayer, stream] thunder waiting for its delay
var _cover_in: float = 0.0
var _tick_acc: float = 0.0
var _cover_target: float = 0.0
var _roof_target: float = 0.0
var forced_roof: bool = false           # --roofed: a roof overhead (headless check)
var _drip_in: float = 1.0
var _under: float = 1.0                 # 0 underwater, 1 in the air, smoothed


func setup(stage, ambient) -> void:
	_stage = stage
	_ambient = ambient
	_rng.randomize()
	SoundStage._make_bus("Weather")

	for arg in OS.get_cmdline_user_args():
		if arg == "--covered":
			forced_cover = true
		elif arg == "--roofed":
			forced_cover = true
			forced_roof = true

		if arg.begins_with("--rain-ground="):
			forced_ground = arg.get_slice("=", 1)

		if arg.begins_with("--weather="):
			forced = true
			set_weather(arg.get_slice("=", 1), 1.0)
			rain = float(KINDS[kind]["rain"]) * intensity
			wind = float(KINDS[kind]["wind"]) * intensity
			calls = float(KINDS[kind]["calls"])
			ground_wet = 1.0 if float(KINDS[kind]["rain"]) > 0.0 else 0.0
			ground_snow = 1.0 if kind in ["snow", "blizzard"] else 0.0
			frogs = float(KINDS[kind]["frogs"])

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
	_wind_target = float(state.get("wind", 0.35))
	temp_c = float(state.get("temp_c", temp_c))
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


# Looping weather beds that are audible: [[name, volume_db]] (for the "what is that sound" list).
func active_loops() -> Array:
	var list: Array = []

	for name in _loops:
		if _loops[name].playing and not _loops[name].stream_paused and _loops[name].volume_db > -60.0:
			list.append([name, _loops[name].volume_db])

	return list


func voices_playing() -> int:
	var count: int = _pending.size()

	for name in _loops:
		if _loops[name].playing and not _loops[name].stream_paused:
			count += 1

	return count


func update(frame_delta: float, body: CharacterBody3D, underwater: bool) -> void:
	_tick_acc += frame_delta

	if _tick_acc < TICK_SEC:
		return

	var delta: float = _tick_acc
	_tick_acc = 0.0
	var target: Dictionary = KINDS[kind]
	var step: float = FADE_PER_SEC * delta
	world_wind = move_toward(world_wind, maxf(_wind_target, wind) if forced else _wind_target, 0.1 * delta)
	rain = move_toward(rain, float(target["rain"]) * intensity, step)
	wind = move_toward(wind, float(target["wind"]) * intensity, step)
	hush = move_toward(hush, float(target["hush"]) * intensity, step)
	calls = move_toward(calls, lerpf(1.0, float(target["calls"]), intensity), step)
	frogs = move_toward(frogs, lerpf(1.0, float(target["frogs"]), intensity), step)
	_under = move_toward(_under, 0.12 if underwater else 1.0, delta * 3.0)
	_ambient.weather_calls = calls
	_ambient.weather_frogs = frogs
	_cover_in -= delta

	if _cover_in <= 0.0:
		_cover_in = COVER_EVERY_SEC
		_cover_target = 1.0 if forced_cover or _stage.interior.amount > 0.5 else _stage.under_cover(body)
		_roof_target = 1.0 if forced_roof or _roof_over(body.global_position) else 0.0
		ground_class = forced_ground if forced_ground != "" else _stage.rain_ground(body)

	covered = move_toward(covered, _cover_target, delta / 1.5)
	roofed = move_toward(roofed, _roof_target, delta / 1.5)
	var cover: float = covered
	var roof: float = minf(roofed, cover)
	var water: float = float(_ambient.weights["water"])
	var heavy: float = smoothstep(0.4, 0.9, rain)
	var light: float = minf(rain * 2.0, 1.0) * (1.0 - 0.6 * heavy)
	var keep: float = 1.0

	for key in _ground_w:
		_ground_w[key] = move_toward(_ground_w[key], 1.0 if ground_class == key else 0.0, delta / GROUND_EASE_SEC)
		keep -= (1.0 - float(GROUND_BED_KEEP[key])) * float(_ground_w[key])
		_loop("rain_" + key, minf(rain * 1.6, 1.0) * float(_ground_w[key]) * (1.0 - cover))

	_loop("rain_light", light * (1.0 - 0.7 * cover) * (1.0 - roof) * keep)
	_loop("rain_heavy", heavy * (1.0 - 0.7 * cover) * (1.0 - roof) * keep)
	_loop("rain_leaves", minf(rain * 1.6, 1.0) * (cover - roof))
	_loop("rain_roof", minf(rain * 1.6, 1.0) * roof)
	_loop("rain_water", minf(rain * 1.6, 1.0) * water)
	_loop("wind_storm", clampf(wind - 0.2, 0.0, 1.0) / 0.8)
	_thunder(delta)
	_ground(delta)
	_drips(delta, body, cover)


# Is a roof (a lean-to and the like, Cover roofs) directly over this point? Trees do not count here (leaves, not a roof).
func _roof_over(pos: Vector3) -> bool:
	var flora = _stage._flora

	if flora == null or flora.get("cover") == null or not flora.cover.has_method("roofs_near"):
		return false

	for roof in flora.cover.roofs_near(pos.x, pos.z, 1.0):
		if pos.y < float(roof[6]) or pos.y > float(roof[7]):
			continue

		var dx: float = pos.x - float(roof[1])
		var dz: float = pos.z - float(roof[2])

		if int(roof[0]) == 1:
			if dx * dx + dz * dz <= float(roof[3]) * float(roof[3]):
				return true
		else:
			var c: float = cos(float(roof[5]))
			var sn: float = sin(float(roof[5]))

			if absf(dx * c + dz * sn) <= float(roof[3]) and absf(-dx * sn + dz * c) <= float(roof[4]):
				return true

	return false


# The ground soaks and dries, snow settles and melts (slowly; a test kind forces temperature to cold).
func _ground(delta: float) -> void:
	if covered > 0.5:
		ground_wet = move_toward(ground_wet, 0.0, delta / DRY_UNDER_SEC)         # the canopy keeps the ground dry
	elif rain >= 0.25:
		ground_wet = move_toward(ground_wet, minf(rain * 1.5, 1.0), delta / WET_RISE_SEC)
	else:
		ground_wet = move_toward(ground_wet, 0.0, delta / WET_DRY_SEC)

	if kind == "snow" or kind == "blizzard":
		ground_snow = move_toward(ground_snow, 1.0, delta / SNOW_RISE_SEC)
	else:
		ground_snow = move_toward(ground_snow, 0.0, delta / (SNOW_MELT_SEC if temp_c > MELT_C else SNOW_STAY_SEC))

	if temp_c <= ICE_C:
		ice_cover = move_toward(ice_cover, 1.0, delta / ICE_RISE_SEC)
	elif temp_c > MELT_C:
		ice_cover = move_toward(ice_cover, 0.0, delta / ICE_MELT_SEC)

	var falling: float = 0.2 if kind == "snow" or kind == "blizzard" else 0.0
	snow_hush = move_toward(snow_hush, minf(0.8 * ground_snow + falling, 1.0), delta / HUSH_EASE_SEC)


# Under trees in rain: now and then a drop falls from a leaf nearby.
func _drips(delta: float, body: CharacterBody3D, cover: float) -> void:
	if rain < 0.15 or cover < 0.5 or not _stage.has_room():
		return

	_drip_in -= delta * _ambient.time_scale

	if _drip_in > 0.0:
		return

	_drip_in = lerpf(DRIP_EVERY[1], DRIP_EVERY[0], clampf(rain, 0.0, 1.0)) * _rng.randf_range(0.6, 1.4) / maxf(cover, 0.3)
	var list: Array = _variants("rain_drip")

	if list.is_empty():
		return

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]
	player.bus = "Weather"
	player.volume_db = DRIP_DB + _rng.randf_range(-4.0, 2.0) + linear_to_db(clampf(cover, 0.3, 1.0))
	player.pitch_scale = _rng.randf_range(0.85, 1.2)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 3.0
	player.max_distance = 20.0
	add_child(player)
	player.add_to_group("world_sounds")
	var angle: float = _rng.randf() * TAU
	player.global_position = body.global_position + Vector3(cos(angle), _rng.randf_range(-0.8, 1.5), sin(angle)) * _rng.randf_range(1.5, 7.0)
	player.finished.connect(player.queue_free)
	player.play()
	drips_played += 1


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
	voice.bus = _thunder_bus(distance_m)
	voice.volume_db = THUNDER_DB - distance_m / 400.0 + (3.0 if distance_m < THUNDER_NEAR_M else 0.0) + _rng.randf_range(-2.0, 1.0)
	voice.pitch_scale = _rng.randf_range(0.9, 1.1)
	add_child(voice)
	voice.finished.connect(voice.queue_free)

	if angle < 0.0:
		angle = _rng.randf() * TAU

	lightning.emit(Vector3(cos(angle) * distance_m, 0.0, sin(angle) * distance_m), distance_m)
	_pending.append([thunder_delay(distance_m), voice])
	thunders_played += 1
	last_thunder = "%s %.0f m, %s, heard in %.1f s" % [sound_name, distance_m, voice.bus, thunder_delay(distance_m)]
	return true


# Seconds between the flash and the thunder for a strike this far away.
func thunder_delay(distance_m: float) -> float:
	return minf(distance_m / SPEED_OF_SOUND * THUNDER_DELAY_SCALE, THUNDER_MAX_DELAY_SEC)


# The bus a strike this far away plays on: the farther, and the more forest, roof or cave around, the darker the band.
func _thunder_bus(distance_m: float) -> String:
	var forest: float = float(_ambient.weights["forest"]) if _ambient != null else 0.0
	var enclosure: float = float(_stage.cave.enclosure) if _stage != null and _stage.get("cave") != null else 0.0
	var effective: float = distance_m * AirBands.stretch(distance_m, forest, false, roofed, enclosure)
	return AirBands.bus_for("thunder", AirBands.band_for("thunder", effective, 0))


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
