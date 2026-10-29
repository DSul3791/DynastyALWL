extends Node

# Wind in the trees (client only): the wind sounds different through the trees around the player.
# Pine needles hiss, summer leaves rustle, autumn leaves crackle dry, bare winter branches creak.
#
# Every SCAN_SEC the trees within RADIUS_M are counted (the flora chunks' tree lists, a few hundred
# a frame, never all at once): conifers and broadleaf trees, each weighted by nearness. The loops
# `treewind_pine`, `treewind_leaves`, `treewind_dry` and `treewind_bare` run on the Wind bus; their level
# follows the wind (sound.wind_strength, so gusts swell them and a calm day is silent), how many trees
# there are of that kind and the season. Standing under a canopy makes them a little louder. Nothing
# plays in open country; Low plays only the loudest one.
#
# Directional (Dave 2026-10-23): each loop is a positional player sitting at the middle of the trees of its kind (conifers for the pine
# loop, broadleaf trees for the others) found by the scan, so a tree line on your left sounds on your left and a forest all around
# you sounds all around. The positions change only when a scan ends.
#
# Season weights (spring and summer leaves, autumn dry leaves, winter bare branches) come from the
# ambient layer's conditions["season"]. Sounds: generated in assets/audio/treewind/ (make_treewind.py),
# recordings in assets/audio/recorded/treewind/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const Sound3D := preload("res://src/client/sound_3d.gd")
const GENERATED_DIR := "res://assets/audio/treewind/"
const RECORDED_DIR := "res://assets/audio/recorded/treewind/"

const SCAN_SEC := 4.0
const RADIUS_M := 45.0
const ITEMS_PER_FRAME := 300
const DENSE := 22.0                     # nearness-weighted trees of one kind that count as a full stand
const BASE_DB := -24.0                  # a full stand in a full wind
const CANOPY_DB := 3.0
const FADE_DB_PER_SEC := 12.0
const LOOPS := ["pine", "leaves", "dry", "bare"]
const SEASON_WEIGHT := {
	"spring": {"leaves": 1.0, "dry": 0.0, "bare": 0.0},
	"summer": {"leaves": 1.0, "dry": 0.0, "bare": 0.0},
	"autumn": {"leaves": 0.3, "dry": 1.0, "bare": 0.15},
	"winter": {"leaves": 0.0, "dry": 0.1, "bare": 1.0},
}

var levels: Dictionary = {"pine": -80.0, "leaves": -80.0, "dry": -80.0, "bare": -80.0}   # dB now (HUD)
var summary: String = ""
var loops_playing: int = 0

var _stage                              # SoundStage (wind_strength, season, flora, tier)
var _players: Dictionary = {}           # loop name -> AudioStreamPlayer3D
var _pos_sum: Dictionary = {"conifer": Vector2.ZERO, "broadleaf": Vector2.ZERO}   # nearness-weighted offsets from _scan_origin, this scan
var _scan_origin: Vector3 = Vector3.ZERO
var _centre: Dictionary = {"conifer": Vector3.ZERO, "broadleaf": Vector3.ZERO}    # world point of each kind's stand (the player itself until a scan finds one)
var _streams: Dictionary = {}
var _density: Dictionary = {"conifer": 0.0, "broadleaf": 0.0}      # 0 to 1 (smoothed)
var _target: Dictionary = {"conifer": 0.0, "broadleaf": 0.0}
var _scan_left: float = 0.0
var _queue: Array = []                  # [chunk entry items, from index] still to read
var _sum: Dictionary = {"conifer": 0.0, "broadleaf": 0.0}
var _here: Vector3 = Vector3.ZERO
var forced_season: String = ""          # --tree-season=NAME (headless checks)


func setup(stage) -> void:
	_stage = stage

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-season="):
			forced_season = arg.get_slice("=", 1)

	for sound_name in LOOPS:
		var player: AudioStreamPlayer3D = Sound3D.make(self, "Wind", 12.0, 0.0)
		player.volume_db = -80.0
		var list: Array = _variants("treewind_" + sound_name)

		if not list.is_empty():
			player.stream = list[0]

		_players[sound_name] = player


func update(delta: float, body: CharacterBody3D) -> void:
	_here = body.global_position
	_scan_left -= delta

	if _scan_left <= 0.0 and _queue.is_empty():
		_scan_left = SCAN_SEC
		_start_scan()

	_read_some()
	var under: float = _stage.under_cover(body)
	var season: String = forced_season if forced_season != "" else str(_stage.ambient.conditions.get("season", "autumn"))
	var weight: Dictionary = SEASON_WEIGHT.get(season, SEASON_WEIGHT["summer"])
	var wind: float = clampf(pow(clampf(float(_stage.wind_strength), 0.0, 1.6) / 1.0, 1.3), 0.0, 1.5)
	var want: Dictionary = {}

	for key in _density:
		_density[key] = move_toward(_density[key], _target[key], delta * 0.15)

	want["pine"] = float(_density["conifer"])
	want["leaves"] = float(_density["broadleaf"]) * float(weight["leaves"])
	want["dry"] = float(_density["broadleaf"]) * float(weight["dry"])
	want["bare"] = float(_density["broadleaf"]) * float(weight["bare"])
	var best: String = ""
	var best_level: float = 0.0

	for sound_name in LOOPS:
		if float(want[sound_name]) > best_level:
			best_level = float(want[sound_name])
			best = sound_name

	var parts: PackedStringArray = PackedStringArray()
	loops_playing = 0

	for sound_name in LOOPS:
		var player: AudioStreamPlayer3D = _players[sound_name]
		var amount: float = float(want[sound_name]) * wind
		var target: float = BASE_DB + 20.0 * log(maxf(amount, 0.001)) / log(10.0) + CANOPY_DB * under if amount > 0.01 else -80.0

		if int(_stage.tier) == 0 and sound_name != best:
			target = -80.0                                       # Low: only the loudest

		levels[sound_name] = move_toward(float(levels[sound_name]), target, FADE_DB_PER_SEC * delta)
		player.volume_db = levels[sound_name]

		if player.stream == null:
			continue

		if levels[sound_name] > -60.0:
			if not player.playing:
				player.play()

			player.stream_paused = false
			loops_playing += 1
			parts.append("%s %.0f dB" % [sound_name, levels[sound_name]])
		elif player.playing and levels[sound_name] <= -75.0:
			player.stream_paused = true

	summary = ", ".join(parts) if not parts.is_empty() else "none"


func voices_playing() -> int:
	return loops_playing


# Queues the player's flora chunk and its neighbours that reach within RADIUS_M.
func _start_scan() -> void:
	var flora = _stage._flora

	if flora == null:
		return

	_sum = {"conifer": 0.0, "broadleaf": 0.0}
	_pos_sum = {"conifer": Vector2.ZERO, "broadleaf": Vector2.ZERO}
	_scan_origin = _here
	var chunk_m: float = float(flora.chunk_m)
	var cx: int = int(floor(_here.x / chunk_m))
	var cz: int = int(floor(_here.z / chunk_m))

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var chunk := Vector2i(cx + dx, cz + dz)

			if not flora._chunks.has(chunk):
				continue

			var low := Vector2(chunk.x * chunk_m, chunk.y * chunk_m)
			var nearest := Vector2(clampf(_here.x, low.x, low.x + chunk_m), clampf(_here.z, low.y, low.y + chunk_m))

			if nearest.distance_to(Vector2(_here.x, _here.z)) <= RADIUS_M:
				_queue.append([flora._chunks[chunk]["items"], 0])


func _read_some() -> void:
	if _queue.is_empty():
		return

	var flora = _stage._flora
	var budget: int = ITEMS_PER_FRAME

	while budget > 0 and not _queue.is_empty():
		var job: Array = _queue[0]
		var items: Dictionary = job[0]
		var positions: PackedVector3Array = items["positions"]
		var ids: PackedInt32Array = items["ids"]
		var n: int = int(job[1])
		var end: int = mini(n + budget, positions.size())

		for k in range(n, end):
			var d: float = Vector2(positions[k].x - _here.x, positions[k].z - _here.z).length()

			if d >= RADIUS_M:
				continue

			var info: Dictionary = flora._species.get(ids[k] >> 16, {})

			if info.is_empty() or int(info.get("kind", -1)) != flora.KIND_TREE:
				continue

			var key: String = "broadleaf" if bool(info.get("hardwood", false)) else "conifer"
			var near: float = 1.0 - d / RADIUS_M
			_sum[key] = float(_sum[key]) + near
			_pos_sum[key] = (_pos_sum[key] as Vector2) + Vector2(positions[k].x - _scan_origin.x, positions[k].z - _scan_origin.z) * near

		budget -= end - n
		job[1] = end

		if end >= positions.size():
			_queue.pop_front()

	if _queue.is_empty():
		for key in _sum:
			_target[key] = clampf(float(_sum[key]) / DENSE, 0.0, 1.0)
			var middle: Vector2 = (_pos_sum[key] as Vector2) / float(_sum[key]) if float(_sum[key]) > 0.001 else Vector2.ZERO
			_centre[key] = Vector3(_scan_origin.x + middle.x, _scan_origin.y + 2.0, _scan_origin.z + middle.y)

		for sound_name in LOOPS:
			(_players[sound_name] as AudioStreamPlayer3D).global_position = _centre["conifer" if sound_name == "pine" else "broadleaf"]


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	for stream in list:
		if stream is AudioStreamOggVorbis:
			stream.loop = true

	_streams[sound_name] = list
	return list


func _exit_tree() -> void:
	for sound_name in _players:
		_players[sound_name].stop()
		_players[sound_name].stream = null

	_streams.clear()
