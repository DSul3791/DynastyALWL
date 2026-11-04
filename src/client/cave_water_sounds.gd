extends Node

# Spring cave water (client only; Sonny's spring caves #170 and the in-cave streams #183, 3 Nov 2026). The server's list of cave streams (protocol 87, one flat
# float array per tile: pieces of 7 floats) is the map of the water: a stream piece is upper end x y z, lower end x y z, passage width; a spring pool is centre
# x y z, 0, -radius. This module plays what that water would sound like:
#   - a stream loop (water_brook) placed on the nearest point of the nearest stream, so it runs along the player down the passage, louder inside the rock than outside
#   - a pool loop (water_pond) at the nearest spring pool, a trickle and lap at the back of the cave
#   - more springs feeding the passage means more water: the flows of the springs in the same cave add, so the stream gets FLOW_STEP_DB louder for each doubling of the
#     springs within SAME_CAVE_M of the nearest point, and the river loop joins at two springs or more (a fuller, deeper sound)
# Echo and the fade from the mouth to the inside come from the cave module: these players are on the Foley bus, which sends to the World reverb (its size and
# wetness follow the enclosure) and is the one bus still heard deep inside; the 3D falloff does the rest. Nothing plays when there is no cave water within REACH_M.
#   sound.cavewater.set_tile(tile, floats)   the list for a tile (replaces that tile's)
#   sound.cavewater.drop_tile(tile)

const SoundStage := preload("res://src/client/sound_stage.gd")
const Sound3D := preload("res://src/client/sound_3d.gd")
const RECORDED_DIR := "res://assets/audio/recorded/water/"
const GENERATED_DIR := "res://assets/audio/water/"

const REACH_M := 45.0                   # no cave water is heard from farther than this
const STREAM_UNIT_M := 3.0
const POOL_UNIT_M := 2.0
const POOL_REACH_M := 30.0
const STREAM_DB := -14.0
const RIVER_DB := -18.0
const POOL_DB := -17.0
const FLOW_STEP_DB := 3.0               # per doubling of the springs feeding the passage
const SAME_CAVE_M := 160.0              # springs this near the stream point feed the same passage
const INSIDE_CUT_DB := -6.0             # in the open the water is this much quieter than inside the rock
const SCAN_SEC := 0.25
const FADE_DB_PER_SEC := 24.0

var streams_heard: int = 0              # loops playing (HUD, checks)
var springs_near: int = 0               # springs counted for the flow at the last scan
var last: String = ""

var _stage
var _tiles: Dictionary = {}             # tile -> PackedFloat32Array
var _players: Dictionary = {}           # "stream", "river", "pool" -> AudioStreamPlayer3D
var _target_db: Dictionary = {"stream": -80.0, "river": -80.0, "pool": -80.0}
var _scan_left: float = 0.0
var _streams: Dictionary = {}


func setup(stage) -> void:
	_stage = stage
	# The players start with no stream: setup runs in the welcome and must not load files. The warm list fills _streams in the background and
	# _attach (from _scan) gives a player its stream the first time it is wanted.
	_players["stream"] = _loop_player(STREAM_UNIT_M, REACH_M)
	_players["river"] = _loop_player(STREAM_UNIT_M * 1.5, REACH_M)
	_players["pool"] = _loop_player(POOL_UNIT_M, POOL_REACH_M)


func set_tile(tile: Vector2i, floats: PackedFloat32Array) -> void:
	_tiles[tile] = floats


func drop_tile(tile: Vector2i) -> void:
	_tiles.erase(tile)


func clear() -> void:
	_tiles.clear()


func update(delta: float, body: CharacterBody3D) -> void:
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_scan(body.global_position)

	streams_heard = 0

	for key in _players:
		var player: AudioStreamPlayer3D = _players[key]

		if player == null or player.stream == null:
			continue

		player.volume_db = move_toward(player.volume_db, float(_target_db[key]), FADE_DB_PER_SEC * delta)

		if player.volume_db > -70.0:
			streams_heard += 1

			if not player.playing:
				player.play(randf() * 5.0)
		elif player.playing and float(_target_db[key]) <= -70.0:
			player.stop()


# Nearest point on any stream piece to `at`: {"point": Vector3, "distance": m}; distance INF when there is none. Static, checked on its own.
static func nearest_stream(pieces: Array, at: Vector3) -> Dictionary:
	var best: Dictionary = {"point": Vector3.ZERO, "distance": INF}

	for piece in pieces:
		var a: Vector3 = piece[0]
		var b: Vector3 = piece[1]
		var ab: Vector3 = b - a
		var t: float = clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var p: Vector3 = a + ab * t
		var d: float = p.distance_to(at)

		if d < float(best["distance"]):
			best = {"point": p, "distance": d}

	return best


# dB added for `springs` feeding the passage: 0 for one, FLOW_STEP_DB for each doubling (two +3, four +6).
static func flow_db(springs: int) -> float:
	return FLOW_STEP_DB * log(float(maxi(springs, 1))) / log(2.0)


# Splits a tile's float list into stream pieces [[upper, lower, width]] and pools [[centre, radius]].
static func parse(floats: PackedFloat32Array, pieces: Array, pools: Array) -> void:
	@warning_ignore("integer_division")
	for n in range(floats.size() / 7):
		var o: int = n * 7

		if floats[o + 6] < 0.0:
			pools.append([Vector3(floats[o], floats[o + 1], floats[o + 2]), -floats[o + 6]])
		else:
			pieces.append([Vector3(floats[o], floats[o + 1], floats[o + 2]), Vector3(floats[o + 3], floats[o + 4], floats[o + 5]), floats[o + 6]])


func _scan(at: Vector3) -> void:
	var pieces: Array = []
	var pools: Array = []

	for tile in _tiles:
		parse(_tiles[tile], pieces, pools)

	var enclosure: float = float(_stage.cave.enclosure)
	var inside: float = lerpf(INSIDE_CUT_DB, 0.0, clampf(enclosure, 0.0, 1.0))
	var hit: Dictionary = nearest_stream(pieces, at)
	var muted: bool = _stage.breath.world_mute > 0.5
	_target_db["stream"] = -80.0
	_target_db["river"] = -80.0
	_target_db["pool"] = -80.0

	if float(hit["distance"]) <= REACH_M and not muted:
		var springs: int = 0

		for pool in pools:
			if pool[0].distance_to(hit["point"]) <= SAME_CAVE_M:
				springs += 1

		springs_near = springs
		var boost: float = flow_db(springs)
		_players["stream"].global_position = hit["point"]
		_players["river"].global_position = hit["point"]
		_target_db["stream"] = STREAM_DB + boost + inside if _attach("stream") else -80.0
		_target_db["river"] = RIVER_DB + inside + boost if springs >= 2 and _attach("river") else -80.0
		last = "stream %.0f m, %d spring(s)" % [float(hit["distance"]), springs]

	var near_pool: Vector3 = Vector3.INF
	var near_d: float = INF

	for pool in pools:
		var d: float = pool[0].distance_to(at)

		if d < near_d:
			near_d = d
			near_pool = pool[0]

	if near_d <= POOL_REACH_M and not muted:
		_players["pool"].global_position = near_pool
		_target_db["pool"] = POOL_DB + inside if _attach("pool") else -80.0


func _loop_player(unit: float, reach: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = Sound3D.make(self, "Foley", unit, reach)
	player.volume_db = -80.0
	return player


# Gives the player its looping stream once the warm loader has it; false until then (the sound simply starts a little later).
func _attach(key: String) -> bool:
	var player: AudioStreamPlayer3D = _players[key]

	if player.stream != null:
		return true

	var name_of: String = {"stream": "water_brook", "river": "water_river", "pool": "water_pond"}[key]

	if not _streams.has(name_of) or _streams[name_of].is_empty():
		return false

	var stream: AudioStream = _streams[name_of][0]

	if stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		stream.loop = true

	player.stream = stream
	return true


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func voices_playing() -> int:
	return streams_heard
