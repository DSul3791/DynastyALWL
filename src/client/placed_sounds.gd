extends Node

# Placed-thing and tool sounds (client only): lean-tos, chests and the tools' wear. Nothing here knows
# how the Items thread builds them; the hooks below are called with a place, and `watch_world` hears
# the world rows by itself.
#
#   sound.placed.place("leanto", at)        "leanto", "chest" or "thump" (any other thing set down)
#   sound.placed.pick_up(at)                a placed thing taken up again
#   sound.placed.chest(true, at)            a chest opened (false: closed); the interior's chest sounds
#   sound.placed.container(true, at)        something put into a container (false: taken out)
#   sound.placed.tool_break(at)             a tool snaps with the last of its wear
#   sound.placed.tool_repair(at)            a tool mended (a 2 s work sound at the player)
#   sound.placed.watch_world(world, here)  about once a second: a world row of state 5 to 7 (lean-to, chest, chopping block)
#                                           that appears near the player plays place, one that vanishes near
#                                           the player plays pick_up (rows streamed in from afar are silent)
#
# Sounds: generated in assets/audio/placed/ (make_placed.py); recordings in assets/audio/recorded/placed/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/placed/"
const RECORDED_DIR := "res://assets/audio/recorded/placed/"

const NAMES := {
	"place_leanto": -7.0, "place_chest": -6.0, "place_thump": -10.0, "pickup_placed": -10.0,
	"container_put": -11.0, "container_take": -12.0, "tool_break": -4.0, "tool_repair": -12.0,
}
# World row states of placed structures (Items thread: 5 lean-to, 6 chest, 7 chopping block) and the place sound each makes.
const STATE_KIND := {5: "leanto", 6: "chest", 7: "thump"}
const NEAR_M := 40.0                    # rows closer than this are heard appearing or vanishing
const MAX_DISTANCE_M := 120.0

var played: Dictionary = {}             # sound name -> count
var last: String = ""

var _stage                              # SoundStage (voice budget, interior chests)
var _streams: Dictionary = {}
var _rows: Dictionary = {}              # world row id -> place sound kind, of the rows seen last time
var _primed: bool = false
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func place(kind: String, at: Vector3) -> bool:
	return _once("place_" + (kind if kind in ["leanto", "chest"] else "thump"), at)


func pick_up(at: Vector3) -> bool:
	return _once("pickup_placed", at)


func chest(opened: bool, at: Vector3) -> bool:
	return _stage.interior.object("chest_open" if opened else "chest_close", at)


func container(put: bool, at: Vector3) -> bool:
	return _once("container_put" if put else "container_take", at)


func tool_break(at: Vector3) -> bool:
	return _once("tool_break", at)


func tool_repair(at: Vector3) -> bool:
	return _once("tool_repair", at)


func watch_world(world: Dictionary, here: Vector3) -> void:
	var seen: Dictionary = {}

	for id in world:
		var row: Dictionary = world[id]

		if STATE_KIND.has(int(row["state"])):
			seen[id] = [STATE_KIND[int(row["state"])], row["pos"]]

	if _primed:
		for id in seen:
			if not _rows.has(id) and here.distance_to(seen[id][1]) <= NEAR_M:
				place(str(seen[id][0]), seen[id][1])

		for id in _rows:
			if not seen.has(id) and here.distance_to(_rows[id][1]) <= NEAR_M:
				pick_up(_rows[id][1])

	_rows = seen
	_primed = true


func _once(name: String, at: Vector3) -> bool:
	if not NAMES.has(name) or not _stage.has_room():
		return false

	var list: Array = _variants(name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = float(NAMES[name]) + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 7.0
	player.max_distance = MAX_DISTANCE_M
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	played[name] = int(played.get(name, 0)) + 1
	last = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]
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
	_streams.clear()
