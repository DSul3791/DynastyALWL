extends Node

# Town sounds (client only): the sounds of a place where people live, as hooks for a later
# town system. Nothing here knows what a town is; a caller says where sounds are and of what kind.
#
#   sound.town.set_sources([{"id": 7, "kind": "fire", "at": Vector3(...), "strength": 1.0}, ...])
#       the sound sources near the player, called whenever the list changes (once a second is plenty);
#       sources keep their loop while their id stays in the list, and fade out when it leaves.
#   sound.town.ring_bell(at, strikes)       the bell tolls `strikes` times, 2.5 s apart
#
# Kinds: "fire" (hearth, forge: a crackle loop), "hammering" (a smith or builder at work: strikes
# on an anvil), "crowd" (a busy square: murmur, no words) and "bell" (a tower; the source tolls
# the hour by the game clock: hour % 12 strikes, 12 at noon and midnight). Each kind has a reach
# beyond which it is not played; only the nearest MAX_LOOPS by tier get a loop (Low 3, Mid 5, High 8).
# Sounds: generated in assets/audio/town/ (make_town.py); recordings in assets/audio/recorded/town/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/town/"
const RECORDED_DIR := "res://assets/audio/recorded/town/"

const KINDS := {
	"fire": {"file": "town_fire", "db": -12.0, "reach": 30.0, "unit": 4.0},
	"hammering": {"file": "town_hammering", "db": -10.0, "reach": 70.0, "unit": 8.0},
	"crowd": {"file": "town_crowd", "db": -14.0, "reach": 50.0, "unit": 10.0},
}
const BELL_FILE := "town_bell"
const BELL_DB := -6.0
const BELL_REACH_M := 400.0
const BELL_GAP_SEC := 2.5
const SCAN_SEC := 0.5
const FADE_DB_PER_SEC := 30.0

var tier: int = 2
var loops_playing: int = 0              # HUD
var bells_rung: int = 0
var last_hour_tolled: int = -1

var _stage                              # SoundStage (ambient.conditions is the game clock mirror)
var _sources: Array = []                # the list the caller set
var _loops: Dictionary = {}             # source id -> {"player", "kind", "target_db"}
var _scan_left: float = 0.0
var _streams: Dictionary = {}
var _queue: Array = []                  # [seconds left, position] bell strikes waiting
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func set_tier(new_tier: int) -> void:
	tier = new_tier


func set_sources(sources: Array) -> void:
	_sources = sources


# The bell at `at` tolls `strikes` times.
func ring_bell(at: Vector3, strikes: int = 1) -> void:
	for n in range(maxi(strikes, 1)):
		_queue.append([BELL_GAP_SEC * float(n), at])


func update(delta: float, body: CharacterBody3D) -> void:
	for n in range(_queue.size() - 1, -1, -1):
		_queue[n][0] -= delta

		if _queue[n][0] <= 0.0:
			_strike(_queue[n][1], body)
			_queue.remove_at(n)

	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_scan(body)

	for id in _loops.keys():
		var loop: Dictionary = _loops[id]
		var player: AudioStreamPlayer3D = loop["player"]
		player.volume_db = move_toward(player.volume_db, float(loop["target_db"]), FADE_DB_PER_SEC * delta)

		if float(loop["target_db"]) <= -60.0 and player.volume_db <= -58.0:
			player.queue_free()
			_loops.erase(id)

	loops_playing = _loops.size()


func _scan(body: CharacterBody3D) -> void:
	var here: Vector3 = body.global_position
	var near: Array = []
	var hour: float = float(_stage.ambient.conditions["hour"])
	var hour_now: int = int(floor(hour))

	for source in _sources:
		var at: Vector3 = source["at"]
		var kind: String = str(source.get("kind", ""))
		var distance: float = at.distance_to(here)

		if kind == "bell":
			if distance <= BELL_REACH_M and hour_now != last_hour_tolled and last_hour_tolled >= 0:
				ring_bell(at, 12 if hour_now % 12 == 0 else hour_now % 12)

			continue

		if KINDS.has(kind) and distance <= float(KINDS[kind]["reach"]):
			near.append({"source": source, "distance": distance / float(KINDS[kind]["reach"])})

	last_hour_tolled = hour_now
	near.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var wanted: Dictionary = {}

	for entry in near.slice(0, int(_stage.preset["town_loops"])):
		wanted[entry["source"]["id"]] = entry["source"]

	for id in wanted:
		var source: Dictionary = wanted[id]
		var kind: String = source["kind"]

		if not _loops.has(id):
			var list: Array = _variants(str(KINDS[kind]["file"]))

			if list.is_empty():
				continue

			var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			player.stream = list[_rng.randi_range(0, list.size() - 1)]

			if player.stream is AudioStreamOggVorbis:
				player.stream.loop = true

			player.bus = "Foley"
			player.volume_db = -60.0
			player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			player.unit_size = float(KINDS[kind]["unit"])
			player.max_distance = float(KINDS[kind]["reach"]) * 1.5
			add_child(player)
			player.add_to_group("world_sounds")
			player.global_position = source["at"]
			player.play(_rng.randf() * 4.0)
			_loops[id] = {"player": player, "kind": kind, "target_db": 0.0}

		_loops[id]["target_db"] = float(KINDS[kind]["db"]) + 20.0 * log(maxf(float(source.get("strength", 1.0)), 0.05)) / log(10.0)
		_loops[id]["player"].global_position = source["at"]

	for id in _loops:
		if not wanted.has(id):
			_loops[id]["target_db"] = -80.0


func _strike(at: Vector3, body: CharacterBody3D) -> void:
	if at.distance_to(body.global_position) > BELL_REACH_M:
		return

	var list: Array = _variants(BELL_FILE)

	if list.is_empty():
		return

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]
	player.bus = "Foley"
	player.volume_db = BELL_DB + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.99, 1.01)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 20.0
	player.max_distance = BELL_REACH_M * 1.5
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	bells_rung += 1


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func _exit_tree() -> void:
	for id in _loops:
		_loops[id]["player"].stop()
		_loops[id]["player"].stream = null

	_streams.clear()
