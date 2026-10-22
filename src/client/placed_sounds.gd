extends Node

# Placed-thing and tool sounds (client only): lean-tos, chests and the tools' wear. Nothing here knows
# how the Items thread builds them; the hooks below are called with a place, and `watch_world` hears
# the world rows by itself.
#
#   sound.placed.place("leanto", at)        "leanto", "chest", "timber" (wall, floor, roof piece) or "thump" (any other thing set down)
#   sound.placed.pick_up(at)                a placed thing taken up again
#   sound.placed.chest(true, at)            a chest opened (false: closed); the interior's chest sounds
#   sound.placed.container(true, at)        something put into a container (false: taken out)
#   sound.placed.use("door", true, at)     any openable structure opened (false: closed): "door", "gate", "hatch", "chest"
#   sound.placed.lock(true, at)             a latch locked or unlocked (a small click)
#   sound.placed.knock(at)                  a knock on a door
#   sound.placed.watch_open(world, here)    about once a second: a world row of a kind in `open_kinds` whose "open" field flips
#                                           near the player plays use() (nothing is listed yet: Items adds doors later, see
#                                           /mnt/project-files/sound/STRUCTURE_EVENTS.md); rows first seen are silent
#   sound.placed.tool_break(at)             a tool snaps with the last of its wear
#   sound.placed.tool_warn(at)              a tool in the pack drops under 20 percent condition (item_sounds.watch hears it)
#   sound.placed.tool_repair(at)            a tool mended (a 2 s work sound at the player)
#   sound.placed.watch_world(world, here)  about once a second: a world row of state 5 to 7 (lean-to, chest, chopping block) or a fire (1, 8, 9)
#                                           that appears near the player plays place, one that vanishes near
#                                           the player plays pick_up (rows streamed in from afar are silent)
#
# Sounds: generated in assets/audio/placed/ (make_placed.py); recordings in assets/audio/recorded/placed/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/placed/"
const RECORDED_DIR := "res://assets/audio/recorded/placed/"

const NAMES := {
	"place_leanto": -7.0, "place_chest": -6.0, "place_thump": -10.0, "pickup_placed": -10.0,
	"place_timber": -7.0, "container_put": -11.0, "container_take": -12.0, "tool_break": -4.0, "tool_repair": -12.0, "tool_warn": -10.0,
}
# World row states of placed structures (Items thread: 5 lean-to, 6 chest, 7 chopping block) and the place sound each makes.
const STATE_KIND := {5: "leanto", 6: "chest", 7: "thump", 1: "thump", 8: "thump", 9: "thump", 22: "timber", 23: "timber", 24: "timber", 25: "thump"}   # 1, 8, 9: a campfire set down (lit, empty or loaded)
const OPENABLES := {"door": ["door_open", "door_close"], "gate": ["gate_open", "gate_close"], "hatch": ["hatch_open", "hatch_close"], "chest": ["chest_open", "chest_close"]}
var open_kinds: Dictionary = {}         # world row state -> openable kind; filled when Items has doors (rows carry "open" 0 or 1)
const NEAR_M := 40.0                    # rows closer than this are heard appearing or vanishing
const MAX_DISTANCE_M := 120.0

var played: Dictionary = {}             # sound name -> count
var last: String = ""

var _stage                              # SoundStage (voice budget, interior chests)
var _streams: Dictionary = {}
var _rows: Dictionary = {}              # world row id -> place sound kind, of the rows seen last time
var _primed: bool = false
var _open_rows: Dictionary = {}         # world row id -> [kind, open, pos] seen last time
var _open_primed: bool = false
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func place(kind: String, at: Vector3) -> bool:
	return _once("place_" + (kind if kind in ["leanto", "chest", "timber"] else "thump"), at)


func pick_up(at: Vector3) -> bool:
	return _once("pickup_placed", at)


func chest(opened: bool, at: Vector3) -> bool:
	return _stage.interior.object("chest_open" if opened else "chest_close", at)


# Open or close an openable structure: kind "door", "gate", "hatch" or "chest" (a lid). `strength` 0 to 1 (a gentle touch, a slam).
func use(kind: String, opened: bool, at: Vector3, strength: float = 1.0) -> bool:
	if not OPENABLES.has(kind):
		return false

	return _stage.interior.object(OPENABLES[kind][0 if opened else 1], at, strength)


func lock(locked: bool, at: Vector3) -> bool:
	return _stage.interior.object("latch_click", at, 1.0 if locked else 0.7)


func knock(at: Vector3) -> bool:
	return _stage.interior.object("door_knock", at)


func container(put: bool, at: Vector3) -> bool:
	return _once("container_put" if put else "container_take", at)


func tool_break(at: Vector3) -> bool:
	return _once("tool_break", at)


func tool_warn(at: Vector3) -> bool:
	return _once("tool_warn", at)


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


func watch_open(world: Dictionary, here: Vector3) -> void:
	var seen: Dictionary = {}

	for id in world:
		var row: Dictionary = world[id]

		if open_kinds.has(int(row["state"])) and row.has("open"):
			seen[id] = [str(open_kinds[int(row["state"])]), bool(row["open"]), row["pos"]]

	for id in seen:
		if _open_primed and _open_rows.has(id) and bool(_open_rows[id][1]) != bool(seen[id][1]) and here.distance_to(seen[id][2]) <= NEAR_M:
			use(str(seen[id][0]), bool(seen[id][1]), seen[id][2])

	_open_rows = seen
	_open_primed = true


func _once(sound_name: String, at: Vector3) -> bool:
	if not NAMES.has(sound_name) or not _stage.has_room():
		return false

	var list: Array = _variants(sound_name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = float(NAMES[sound_name]) + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 7.0
	player.max_distance = MAX_DISTANCE_M
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	played[sound_name] = int(played.get(sound_name, 0)) + 1
	last = "%s_%d (%s)" % [sound_name, pick, SoundStage.tag(list[pick])]
	return true


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
