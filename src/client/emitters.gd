extends Node

# Sound emitters for things the server owns (creatures, carts, forges, NPCs): the client half of
# sound/EMITTER_API.md. Nothing here knows an entity; a caller says what kind it is, what it did
# and where, and for continuous sounds which loop an entity row carries.
#
#   sound.emitters.emit("wolf", "call_threat", position, power, entity_id)    one-shot event
#   sound.emitters.sync(rows)        loops: rows = [{id, kind, loop, at: Vector3, power}], every 0.25 s
#   sound.emitters.register_event(kind, event, spec)   add or replace a table row (data, no code)
#   sound.emitters.register_loop(loop, spec)
#
# Creature kinds (deer, rabbit, fox, wolf, bear, bird) with events call_idle, call_alert and
# call_threat go straight to creature_sounds.gd. Any other event plays its table row: spec =
# {folder, name, db, reach, unit, bus, keep}. Recordings in recorded/<folder>/ win over generated.
#
# Limits (same numbers the server will use): 4 events per entity per second, 60 per second in all.
# Events obey the voice cap and shed priority; spec.keep marks a danger cue. Far loops of the same
# kind within CLUSTER_M of each other share one voice, louder with the count (a herd, a town).
# Unknown kinds and events are logged once and stay silent.

const SoundStage := preload("res://src/client/sound_stage.gd")

const CREATURE_KINDS := ["deer", "rabbit", "fox", "wolf", "bear", "bird"]
const CREATURE_MOODS := {"call_idle": "idle", "call_alert": "alert", "call_threat": "threat"}
const PER_ENTITY_PER_SEC := 4
const PER_CLIENT_PER_SEC := 60
const MERGE_M := 18.0                   # loops nearer than this are never merged
const CLUSTER_M := 15.0
const LOOP_REACH_M := 120.0
const LOW_POWER := 0.3                  # Low tier: quieter events beyond FAR_LOW_M are skipped
const FAR_LOW_M := 40.0

# kind -> event -> spec. Rows for server-owned things are added here as they appear.
var events: Dictionary = {
	"hum": {"tick": {"folder": "fire", "name": "fire_light", "db": -14.0, "reach": 60.0, "unit": 4.0, "bus": "Foley"}},
}
# loop id -> spec.
var loops: Dictionary = {
	"hum": {"folder": "fire", "name": "fire_small", "db": -14.0, "reach": 60.0, "unit": 4.0, "bus": "Foley"},
}

var played: int = 0                     # events played (HUD, tests)
var dropped_rate: int = 0               # events dropped by the rate limits
var dropped_far: int = 0                # events skipped as too faint at Low
var unknown: Dictionary = {}            # "kind/event" -> count (logged once)
var merged_loops: int = 0               # voices saved by merging, last sync
var last: String = ""

var _stage                              # SoundStage
var _tier: int = 2
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _entity_log: Dictionary = {}        # entity id -> [msec of recent events]
var _client_log: Array = []
var _loop_players: Dictionary = {}      # key -> {player, loop, gone}


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func set_tier(tier: int) -> void:
	_tier = tier


func register_event(kind: String, event: String, spec: Dictionary) -> void:
	if not events.has(kind):
		events[kind] = {}

	events[kind][event] = spec


func register_loop(loop: String, spec: Dictionary) -> void:
	loops[loop] = spec


# One event. False when nothing played (rate limit, out of reach, no room, unknown, no sound).
func emit(kind: String, event: String, at: Vector3, power: float = 1.0, entity_id: int = 0) -> bool:
	if not _rate_ok(entity_id):
		dropped_rate += 1
		return false

	if kind in CREATURE_KINDS and CREATURE_MOODS.has(event):
		var ok: bool = _stage.creatures.call_at(kind, at, CREATURE_MOODS[event])

		if ok:
			played += 1
			last = "%s %s (creature)" % [kind, event]

		return ok

	if not events.has(kind) or not events[kind].has(event):
		var key: String = "%s/%s" % [kind, event]

		if not unknown.has(key):
			push_warning("emitters: no sound for " + key)

		unknown[key] = int(unknown.get(key, 0)) + 1
		return false

	var spec: Dictionary = events[kind][event]
	var listener: Vector3 = _listener()
	var distance: float = listener.distance_to(at)

	if distance > float(spec["reach"]):
		return false

	if _tier == 0 and power < LOW_POWER and distance > FAR_LOW_M:
		dropped_far += 1
		return false

	if not bool(spec.get("keep", false)) and not _stage.has_room():
		return false

	var list: Array = _variants(str(spec["folder"]), str(spec["name"]))

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = _player(spec, list[pick], at)
	player.volume_db = float(spec["db"]) + linear_to_db(clampf(power, 0.05, 1.0)) + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.finished.connect(player.queue_free)

	if bool(spec.get("keep", false)):
		player.set_meta("keep", true)

	player.play()
	played += 1
	last = "%s %s %s_%d (%s) at %.0f m" % [kind, event, spec["name"], pick, SoundStage.tag(list[pick]), distance]
	return true


# Loops from entity rows: starts, moves and stops one voice per entity (or per far cluster).
func sync(rows: Array) -> void:
	var listener: Vector3 = _listener()
	var near: Array = []
	var far: Array = []

	for row in rows:
		var loop: String = str(row.get("loop", ""))

		if loop == "" or not loops.has(loop):
			continue

		var spec: Dictionary = loops[loop]
		var distance: float = listener.distance_to(row["at"])

		if distance > minf(float(spec["reach"]), LOOP_REACH_M):
			continue

		if distance <= MERGE_M:
			near.append({"key": "e%s" % str(row["id"]), "loop": loop, "at": row["at"], "power": float(row.get("power", 1.0)), "count": 1, "distance": distance})
		else:
			far.append({"id": row["id"], "loop": loop, "kind": str(row.get("kind", "")), "at": row["at"], "power": float(row.get("power", 1.0)), "distance": distance})

	var wanted: Array = near + _cluster(far)
	var cap: int = int(_stage.preset["town_loops"])
	wanted.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var keys: Dictionary = {}

	for entry in wanted.slice(0, cap):
		keys[entry["key"]] = entry
		_loop(entry)

	for key in _loop_players:
		if not keys.has(key):
			_loop_players[key]["gone"] = true

	_prune_loops()


func loops_playing() -> int:
	var count: int = 0

	for key in _loop_players:
		if not _loop_players[key]["gone"]:
			count += 1

	return count


func _cluster(far: Array) -> Array:
	merged_loops = 0
	var clusters: Array = []

	for entry in far:
		var joined: bool = false

		for cluster in clusters:
			if cluster["loop"] == entry["loop"] and cluster["seed"].distance_to(entry["at"]) <= CLUSTER_M:
				cluster["members"].append(entry)
				joined = true
				break

		if not joined:
			clusters.append({"loop": entry["loop"], "seed": entry["at"], "members": [entry]})

	var out: Array = []

	for cluster in clusters:
		var members: Array = cluster["members"]
		var centre: Vector3 = Vector3.ZERO
		var nearest: float = INF
		var power: float = 0.0

		for entry in members:
			centre += entry["at"]
			nearest = minf(nearest, float(entry["distance"]))
			power = maxf(power, float(entry["power"]))

		centre /= float(members.size())
		merged_loops += members.size() - 1
		out.append({"key": "c%s_%d_%d" % [cluster["loop"], roundi(cluster["seed"].x / CLUSTER_M), roundi(cluster["seed"].z / CLUSTER_M)],
			"loop": cluster["loop"], "at": centre, "power": power, "count": members.size(), "distance": nearest})

	return out


func _loop(entry: Dictionary) -> void:
	var key: String = entry["key"]
	var spec: Dictionary = loops[entry["loop"]]

	if not _loop_players.has(key):
		var list: Array = _variants(str(spec["folder"]), str(spec["name"]))

		if list.is_empty():
			return

		var stream: AudioStream = list[_rng.randi_range(0, list.size() - 1)]

		if stream is AudioStreamOggVorbis:
			stream.loop = true

		var player: AudioStreamPlayer3D = _player(spec, stream, entry["at"])
		player.volume_db = -80.0
		player.play(_rng.randf() * 3.0)
		_loop_players[key] = {"player": player, "loop": entry["loop"], "gone": false, "gain": 0.0}

	var state: Dictionary = _loop_players[key]
	state["gone"] = false
	state["target"] = float(spec["db"]) + linear_to_db(clampf(float(entry["power"]), 0.05, 1.0)) + 3.0 * log(float(entry["count"])) / log(2.0)
	state["player"].global_position = entry["at"]


func _process(delta: float) -> void:
	for key in _loop_players:
		var state: Dictionary = _loop_players[key]
		var player: AudioStreamPlayer3D = state["player"]
		var target: float = -80.0 if state["gone"] else float(state.get("target", -80.0))
		player.volume_db = move_toward(player.volume_db, target, 60.0 * delta)

	_prune_loops()


func _prune_loops() -> void:
	for key in _loop_players.keys():
		var state: Dictionary = _loop_players[key]

		if state["gone"] and state["player"].volume_db <= -79.0:
			state["player"].queue_free()
			_loop_players.erase(key)


func _player(spec: Dictionary, stream: AudioStream, at: Vector3) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = str(spec.get("bus", "Foley"))
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = float(spec["unit"])
	player.max_distance = float(spec["reach"]) * 1.2
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	return player


func _rate_ok(entity_id: int) -> bool:
	var now: int = Time.get_ticks_msec()
	_client_log = _client_log.filter(func(t): return now - t < 1000)

	if _client_log.size() >= PER_CLIENT_PER_SEC:
		return false

	if entity_id != 0:
		var log: Array = _entity_log.get(entity_id, []).filter(func(t): return now - t < 1000)

		if log.size() >= PER_ENTITY_PER_SEC:
			_entity_log[entity_id] = log
			return false

		log.append(now)
		_entity_log[entity_id] = log

	_client_log.append(now)
	return true


func _listener() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_position if camera != null else Vector3.ZERO


func _variants(folder: String, name: String) -> Array:
	var id: String = folder + "/" + name

	if _streams.has(id):
		return _streams[id]

	var list: Array = SoundStage._find("res://assets/audio/recorded/%s/" % folder, name)

	if list.is_empty():
		list = SoundStage._find("res://assets/audio/%s/" % folder, name)

	_streams[id] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
