extends Node

# Tree felling sounds (client only). The Items thread makes a felled tree appear as a trunk row (state 3)
# that tips over in 1.5 s plus a stump row (state 4); this module hears those rows appear:
#
#   sound.trees.watch(items._world)           call about 4 times a second (terrain_client does)
#   sound.trees.fall(at, length_m, radius_m)  the whole fall by hand: creak, leaves, crash at 1.5 s
#   sound.trees.chips(at, radius_m)           the stump spray (last blow)
#
# A trunk or stump present when the world first settles (SETTLE_MSEC) was already lying there and
# makes no sound. The axe blows on the standing tree are `sound.hits` (held_item.gd). Bigger trees
# (length, radius) are louder, lower and heard farther; the crash lands when the trunk reaches the
# ground (FALL_S matches the tween in inventory_view._make_felled).
# Sounds: generated in assets/audio/trees/ (make_trees.py); recordings in assets/audio/recorded/trees/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/trees/"
const RECORDED_DIR := "res://assets/audio/recorded/trees/"

const FALL_S := 1.5
const SETTLE_MSEC := 6000
const BASE_DB := {"tree_creak": -9.0, "tree_leaves": -14.0, "tree_crash": -2.0, "stump_chips": -10.0}
const MAX_DISTANCE_M := 260.0
const REF_HEIGHT_M := 20.0

var falls_played: int = 0
var chips_played: int = 0
var last: String = ""

var _stage                              # SoundStage (voice budget)
var _seen: Dictionary = {}              # row id -> true
var _first_msec: int = -1
var _queue: Array = []                  # [seconds left, name, position, size 0..1]
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# Rows of inventory_view._world: state 3 a felled trunk, 4 a stump (extra: radius, length, yaw).
func watch(world: Dictionary) -> void:
	if _first_msec < 0:
		_first_msec = Time.get_ticks_msec()

	var settled: bool = Time.get_ticks_msec() - _first_msec > SETTLE_MSEC
	var present: Dictionary = {}

	for id in world:
		var row: Dictionary = world[id]
		var state: int = int(row["state"])

		if state < 3:
			continue

		present[id] = true

		if _seen.has(id):
			continue

		_seen[id] = true

		if not settled:
			continue

		var extra: Dictionary = row.get("extra", {})
		var radius: float = float(extra.get("radius", 0.3))

		if state == 3:
			fall(row["pos"], float(extra.get("length", 8.0)), radius)
		else:
			chips(row["pos"], radius)

	for id in _seen.keys():
		if not present.has(id):
			_seen.erase(id)


func fall(at: Vector3, length_m: float, radius_m: float) -> void:
	var size: float = clampf(length_m / REF_HEIGHT_M, 0.2, 1.6)
	_queue.append([0.0, "tree_creak", at, size])
	_queue.append([FALL_S * 0.55, "tree_leaves", at + Vector3(0.0, length_m * 0.4, 0.0), size])
	_queue.append([FALL_S, "tree_crash", at + Vector3(0.0, 0.5, 0.0), clampf(size * (0.6 + radius_m), 0.2, 1.6)])
	falls_played += 1


func chips(at: Vector3, radius_m: float = 0.3) -> void:
	_queue.append([0.0, "stump_chips", at + Vector3(0.0, 0.3, 0.0), clampf(0.4 + radius_m, 0.3, 1.2)])
	chips_played += 1


func update(delta: float) -> void:
	for n in range(_queue.size() - 1, -1, -1):
		_queue[n][0] -= delta

		if _queue[n][0] <= 0.0:
			_play(_queue[n][1], _queue[n][2], _queue[n][3])
			_queue.remove_at(n)


func _play(sound_name: String, at: Vector3, size: float) -> void:
	var list: Array = _variants(sound_name)

	if list.is_empty() or (not _stage.has_room() and sound_name != "tree_crash"):
		return

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = float(BASE_DB[sound_name]) + linear_to_db(clampf(0.3 + 0.7 * size, 0.1, 1.5)) + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.96, 1.04) * clampf(1.15 - 0.2 * size, 0.8, 1.15)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 10.0 + 8.0 * size
	player.max_distance = MAX_DISTANCE_M
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	last = "%s_%d (%s)" % [sound_name, pick, SoundStage.tag(list[pick])]


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
