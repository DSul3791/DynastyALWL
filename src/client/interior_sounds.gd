extends Node

# Interior sounds (client only): the sound of being inside a building, and of its doors, chests and
# furniture, as hooks for a later building system. Nothing here knows a building.
#
#   sound.interior.set_inside(1.0, "house")        the player is inside (0 outside, 1 fully inside; ease it
#                                                  with a door), kind "house", "hall" or "cellar"
#   sound.interior.object("door_open", at)         a door, chest or piece of furniture was used at a place
#
# Inside: wind, weather and nature dull (the cave filters at a mild floor), a small-room reverb at Mid
# and High, a quiet room tone, rain on the roof instead of rain on the ground, the ground counts as
# covered (dry), and the timbers creak now and then. Objects: door_open, door_close, door_knock,
# chest_open, chest_close, furniture_drag.
# Sounds: generated in assets/audio/interior/ (make_interior.py); recordings in
# assets/audio/recorded/interior/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/interior/"
const RECORDED_DIR := "res://assets/audio/recorded/interior/"

const OBJECTS := {"door_open": -8.0, "door_close": -7.0, "door_knock": -8.0, "chest_open": -9.0, "chest_close": -8.0, "furniture_drag": -10.0}
# kind: how closed in it feels (the cave enclosure floor, under the 0.45 where drips start), the
# seconds between creaks.
const KINDS := {
	"house": {"floor": 0.3, "creak": [25.0, 70.0]},
	"hall": {"floor": 0.4, "creak": [40.0, 110.0]},
	"cellar": {"floor": 0.4, "creak": [60.0, 160.0]},
}
const ROOM_DB := -30.0
const ROOF_DB := -17.0
const CREAK_DB := -22.0
const EASE_PER_SEC := 0.7
const OBJECT_MAX_M := 60.0

var amount: float = 0.0                 # smoothed 0 outside .. 1 inside (the HUD, weather and cave read it)
var kind: String = "house"
var objects_played: int = 0
var creaks_played: int = 0
var last: String = ""

var _stage                              # SoundStage (cave, weather, voice room)
var _target: float = 0.0
var _streams: Dictionary = {}
var _room: AudioStreamPlayer
var _roof: AudioStreamPlayer
var _creak_in: float = 20.0
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()
	_room = _loop_player("interior_room")
	_roof = _loop_player("interior_rain_roof")


func set_inside(inside: float, new_kind: String = "house") -> void:
	_target = clampf(inside, 0.0, 1.0)

	if KINDS.has(new_kind):
		kind = new_kind


# A door, chest or furniture sound at `at`.
func object(name: String, at: Vector3, strength: float = 1.0) -> bool:
	if not OBJECTS.has(name):
		return false

	var list: Array = _variants(name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = float(OBJECTS[name]) + linear_to_db(clampf(0.3 + 0.7 * strength, 0.05, 1.0)) + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 6.0
	player.max_distance = OBJECT_MAX_M
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	objects_played += 1
	last = "%s_%d" % [name, pick]
	return true


func update(delta: float) -> void:
	amount = move_toward(amount, _target, EASE_PER_SEC * delta)
	_stage.cave.interior_floor = amount * float(KINDS[kind]["floor"])
	_level(_room, ROOM_DB, amount)
	var rain: float = clampf(_stage.weather.rain * 1.4, 0.0, 1.0)
	_level(_roof, ROOF_DB, amount * rain)

	if amount < 0.5:
		return

	_creak_in -= delta

	if _creak_in > 0.0:
		return

	var every: Array = KINDS[kind]["creak"]
	_creak_in = _rng.randf_range(float(every[0]), float(every[1]))
	var list: Array = _variants("interior_creak")

	if list.is_empty() or not _stage.has_room():
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]
	player.bus = "Foley"
	player.volume_db = CREAK_DB + _rng.randf_range(-3.0, 2.0)
	player.pitch_scale = _rng.randf_range(0.9, 1.1)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	creaks_played += 1


func voices_playing() -> int:
	return int(_room != null and _room.playing) + int(_roof != null and _roof.playing)


func _level(player: AudioStreamPlayer, db: float, level: float) -> void:
	if player == null or player.stream == null:
		return

	if level < 0.01:
		if player.playing:
			player.stop()

		return

	if not player.playing:
		player.play(_rng.randf() * 8.0)

	player.volume_db = db + linear_to_db(level)


func _loop_player(name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = "Foley"
	var list: Array = _variants(name)

	if not list.is_empty():
		player.stream = list[0]

		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true

	add_child(player)
	return player


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list
