extends Node

# Wind in structures (client only, job 89): the wind finds the gaps. Two quiet loops on the Wind bus, flat (not 3D):
#   wind_whistle  a thin wandering tone through a gap: under a lean-to roof with open sides, a door ajar, a window
#   wind_hollow   a low moan across a cave mouth or a big opening
# Level = wind gate x shape. Gate: nothing under a breeze, full in a gale (wind_strength 0.35 to 0.95). Shape by
# enclosure (cave.enclosure, 0 open air .. 1 a sealed tunnel or room): the moan peaks half enclosed, a cave mouth
# (sin(pi x enclosure)), and is gone in the open and deep inside; the whistle follows a roof overhead with the sides
# open (weather.roofed x (1 - enclosure)) plus half the mouth shape. Pitch rises a little with the wind. Both ease
# over about a second and stop (no voice) under 1 % level, under water, or when the world is muted.
# Cost: at most two loop players, none while the air is calm or open. Sounds: assets/audio/windhole/ (make_windhole.py),
# recordings in recorded/windhole/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/windhole/"
const RECORDED_DIR := "res://assets/audio/recorded/windhole/"

const GATE_FROM := 0.35
const GATE_FULL := 0.95
const WHISTLE_DB := -22.0
const HOLLOW_DB := -24.0
const EASE_PER_SEC := 1.0
const OFF_BELOW := 0.01

var whistle_level: float = 0.0          # 0..1 now (HUD, checks)
var hollow_level: float = 0.0
var test_inputs: Vector3 = Vector3(-1.0, 0.0, 0.0)   # --wind-hole: wind, roofed, enclosure (x < 0: use the real ones)

var _stage
var _whistle: AudioStreamPlayer
var _hollow: AudioStreamPlayer
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()
	_whistle = _loop_player("wind_whistle")
	_hollow = _loop_player("wind_hollow")


# Target levels (whistle, hollow), both 0..1, for a wind strength, roof overhead (0..1) and enclosure (0..1).
static func levels(wind: float, roofed: float, enclosure: float) -> Vector2:
	var gate: float = clampf((wind - GATE_FROM) / (GATE_FULL - GATE_FROM), 0.0, 1.0)
	var e: float = clampf(enclosure, 0.0, 1.0)
	var mouth: float = sin(PI * e)
	var lean: float = clampf(roofed, 0.0, 1.0) * (1.0 - e)
	return Vector2(gate * clampf(0.8 * lean + 0.5 * mouth, 0.0, 1.0), gate * mouth)


func update(delta: float, underwater: bool) -> void:
	var wind: float = _stage.wind_strength
	var roofed: float = _stage.weather.roofed
	var enclosure: float = _stage.cave.enclosure

	if test_inputs.x >= 0.0:
		wind = test_inputs.x
		roofed = test_inputs.y
		enclosure = test_inputs.z

	var target: Vector2 = levels(wind, roofed, enclosure)

	if underwater or _stage.breath.world_mute > 0.5:
		target = Vector2.ZERO

	whistle_level = move_toward(whistle_level, target.x, EASE_PER_SEC * delta)
	hollow_level = move_toward(hollow_level, target.y, EASE_PER_SEC * delta)
	var pitch: float = 0.88 + 0.25 * clampf(wind - 0.3, 0.0, 0.8)
	_apply(_whistle, whistle_level, WHISTLE_DB, pitch)
	_apply(_hollow, hollow_level, HOLLOW_DB, pitch)


# The level the player is set to now, -80 while stopped (checks).
func player_db(sound_name: String) -> float:
	var player: AudioStreamPlayer = _whistle if sound_name == "wind_whistle" else _hollow
	return player.volume_db if player.playing else -80.0


func _apply(player: AudioStreamPlayer, level: float, db: float, pitch: float) -> void:
	if player.stream == null:
		return

	if level < OFF_BELOW:
		if player.playing:
			player.stop()

		return

	if not player.playing:
		player.play(_rng.randf() * 10.0)

	player.volume_db = db + linear_to_db(level)
	player.pitch_scale = pitch


func _loop_player(sound_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = "Wind"
	var list: Array = _variants(sound_name)

	if not list.is_empty():
		player.stream = list[0]

		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true

	add_child(player)
	return player


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
