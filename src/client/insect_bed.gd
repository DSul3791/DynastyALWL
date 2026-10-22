extends Node

# Summer insect bed (client only): a quiet continuous chirring of insects over meadows and water edges on warm
# days. One looping sound (`insect_bed`), never positional, fading in and out with the conditions:
#
#   zone     meadow 1.0, water edge 0.5, forest 0.35 (from the ambient layer's zone weights)
#   season   summer 1.0, spring 0.35, autumn 0.35, winter 0 (nothing stirs)
#   hour     full by day (from half an hour after sunrise to sunset, easing over an hour at each end); at night a lower,
#            slower bed (NIGHT_SHARE by season, pitched down) under the crickets
#   weather  fades out with rain; thins in strong wind
#   places   hushed in caves and underwater
#
# Cost: one looping voice at all tiers (counted in the voice budget), stopped entirely when the level is under 1 percent.
# Sounds: generated in assets/audio/insects/ (make_insects.py); recordings in assets/audio/recorded/insects/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/insects/"
const RECORDED_DIR := "res://assets/audio/recorded/insects/"

const BED_DB := -24.0                   # at full level
const SEASON := {"summer": 1.0, "spring": 0.35, "autumn": 0.35, "winter": 0.0}
const ZONE := {"meadow": 1.0, "water": 0.5, "forest": 0.35, "highland": 0.0}
const WATER_DAY := 0.0                  # share of the water-edge hum kept by day (Dave: at a lake only leaves, wind, a fish, a bird)
const NIGHT_SHARE := {"summer": 0.5, "spring": 0.15, "autumn": 0.2, "winter": 0.0}   # warm nights keep a lower, slower chirring
const NIGHT_PITCH := 0.78
const EASE_HOURS := 1.0
const FADE_PER_SEC := 0.25              # level follows its target over about 4 s
const OFF_BELOW := 0.01

var level: float = 0.0                  # 0..1 now (HUD)
var _stage                              # SoundStage (ambient layer, weather, cave)
var _player: AudioStreamPlayer
var _day: float = 1.0                   # the daylight share at the last target (pitch)
var _forced: float = -1.0               # --insects=0..1 forces the level (headless checks)


func setup(stage) -> void:
	_stage = stage

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--insects="):
			_forced = float(arg.get_slice("=", 1))


func voices_playing() -> int:
	return 1 if _player != null and _player.playing else 0


# The level the conditions call for, 0..1.
func target(underwater: bool = false) -> float:
	if _forced >= 0.0:
		return _forced

	var ambient = _stage.ambient
	var zone: float = 0.0
	var season: float = float(SEASON.get(str(ambient.conditions["season"]), 0.0))
	var sun: Array = ambient._sun()
	var hour: float = float(ambient.conditions["hour"])
	var day: float = clampf((hour - (float(sun[0]) + 0.5)) / EASE_HOURS, 0.0, 1.0) * clampf((float(sun[1]) - hour) / EASE_HOURS, 0.0, 1.0)

	for sound_name in ZONE:
		var share: float = float(ZONE[sound_name]) * (lerpf(1.0, WATER_DAY, day) if sound_name == "water" else 1.0)
		zone = maxf(zone, float(ambient.weights.get(sound_name, 0.0)) * share)

	var weather: float = clampf(1.0 - float(_stage.weather.rain) * 1.6, 0.0, 1.0)
	var calm: float = clampf(1.0 - (float(_stage.wind_strength) - 0.6) * 1.2, 0.2, 1.0)
	var places: float = (1.0 - float(_stage.cave.enclosure)) * (0.1 if underwater else 1.0)
	var night: float = float(NIGHT_SHARE.get(str(ambient.conditions["season"]), 0.0))
	_day = day
	# warmth: the chirring builds through the morning to a peak at solar noon and eases again toward evening (0.55 at the edges)
	var span: float = maxf(float(sun[1]) - float(sun[0]), 1.0)
	var warm: float = 0.55 + 0.45 * sin(PI * clampf((hour - float(sun[0])) / span, 0.0, 1.0))
	return clampf(zone * season * (day * warm + (1.0 - day) * night / maxf(season, 0.01)) * weather * calm * places, 0.0, 1.0)


func update(delta: float, underwater: bool = false) -> void:
	level = move_toward(level, target(underwater), FADE_PER_SEC * delta)

	if level < OFF_BELOW:
		if _player != null and _player.playing:
			_player.stop()

		return

	if _player == null:
		var list: Array = SoundStage._find(RECORDED_DIR, "insect_bed")

		if list.is_empty():
			list = SoundStage._find(GENERATED_DIR, "insect_bed")

		if list.is_empty():
			level = 0.0
			return

		var stream: AudioStream = list[randi() % list.size()]

		if stream is AudioStreamOggVorbis:
			stream.loop = true

		_player = AudioStreamPlayer.new()
		_player.stream = stream
		_player.bus = "Nature"
		add_child(_player)

	_player.volume_db = BED_DB + linear_to_db(level)
	_player.pitch_scale = lerpf(NIGHT_PITCH, 1.0, _day)

	if not _player.playing and _stage.has_room():
		_player.play(randf() * 4.0)


func _exit_tree() -> void:
	if _player != null:
		_player.stop()
