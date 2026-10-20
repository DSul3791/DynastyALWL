extends Node

# Chopping block and saw mill sounds (client only): hooks for workshops that do not exist yet. Nothing here
# knows how a block or a mill is built; a caller says where they are and when they work.
#
#   sound.workshop.chop(at, split)       an axe stroke on the chopping block; split true = the log splits in two
#   sound.workshop.plank_drop(at)        a sawn plank lands on its stack
#   sound.workshop.set_saws([{"id": 4, "at": Vector3(...), "running": true}, ...])
#                                        the saw mills near the player, called whenever the list changes (about
#                                        once a second); a running mill plays its blade-and-frame loop, a mill
#                                        that stops fades out. A mill that leaves the list just fades (out of range).
#
# Only the nearest preset["town_loops"] running mills play (Low 3, Mid 5, High 8), none beyond REACH_M.
# Sounds: generated in assets/audio/workshop/ (make_workshop.py); recordings in assets/audio/recorded/workshop/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/workshop/"
const RECORDED_DIR := "res://assets/audio/recorded/workshop/"

const REACH_M := 70.0
const UNIT_SIZE := 6.0
const SAW_DB := -14.0
const CHOP_DB := {"chop_split": -6.0, "chop_thock": -8.0, "plank_drop": -10.0}
const FADE_DB_PER_SEC := 24.0
const SCAN_SEC := 0.5

var loops_playing: int = 0              # HUD
var played: Dictionary = {}             # one-shot name -> count
var last: String = ""

var _stage                              # SoundStage (voice budget, tier)
var _saws: Array = []
var _loops: Dictionary = {}             # id -> {"player": AudioStreamPlayer3D, "on": bool}
var _scan_left: float = 0.0
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func chop(at: Vector3, split: bool = false) -> bool:
	return _once("chop_split" if split else "chop_thock", at)


func plank_drop(at: Vector3) -> bool:
	return _once("plank_drop", at)


func set_saws(saws: Array) -> void:
	_saws = saws


func update(delta: float, body: CharacterBody3D) -> void:
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_scan(body.global_position)

	loops_playing = 0

	for id in _loops.keys():
		var loop: Dictionary = _loops[id]
		var player: AudioStreamPlayer3D = loop["player"]
		var target: float = SAW_DB if bool(loop["on"]) else -80.0
		player.volume_db = move_toward(player.volume_db, target, FADE_DB_PER_SEC * delta)

		if not bool(loop["on"]) and player.volume_db <= -78.0:
			player.stop()
			player.queue_free()
			_loops.erase(id)
		else:
			loops_playing += 1


func _scan(here: Vector3) -> void:
	var wanted: Array = []

	for saw in _saws:
		if bool(saw.get("running", false)):
			var d: float = here.distance_to(saw["at"])

			if d <= REACH_M:
				wanted.append([d, saw])

	wanted.sort_custom(func(a, b): return a[0] < b[0])
	var keep: Array = []

	for n in range(mini(wanted.size(), int(_stage.preset["town_loops"]))):
		keep.append(wanted[n][1])

	for id in _loops:
		_loops[id]["on"] = false

	for saw in keep:
		var id = saw["id"]

		if _loops.has(id):
			_loops[id]["on"] = true
			_loops[id]["player"].global_position = saw["at"]
			continue

		var list: Array = _variants("saw_mill")

		if list.is_empty() or not _stage.has_room():
			continue

		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.stream = list[0]
		player.bus = "Foley"
		player.volume_db = -80.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = UNIT_SIZE
		player.max_distance = REACH_M * 2.0
		add_child(player)
		player.add_to_group("world_sounds")
		player.global_position = saw["at"]
		player.play(_rng.randf() * 10.0)
		_loops[id] = {"player": player, "on": true}


func _once(name: String, at: Vector3) -> bool:
	var list: Array = _variants(name)

	if list.is_empty() or not _stage.has_room():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = float(CHOP_DB[name]) + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = UNIT_SIZE
	player.max_distance = REACH_M * 1.5
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

	for stream in list:
		if name == "saw_mill" and stream is AudioStreamOggVorbis:
			stream.loop = true

	_streams[name] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
