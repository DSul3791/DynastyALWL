extends Node

# Fire sounds (client only): hooks for the campfire and any later fire. Nothing here knows how a
# fire is built; a caller says where fires are, how big, whether lit and whether open to the sky.
#
#   sound.fire.set_fires([{"id": 3, "at": Vector3(...), "size": 0.4, "lit": true, "open": true}, ...])
#       the fires near the player, called whenever the list changes (once a second is plenty).
#       size 0 (embers) to 1 (bonfire) crossfades a small and a large crackle loop. A fire whose
#       "lit" turns on while it stays in the list plays the lighting sound; turning off plays the
#       put-out hiss. A fire that leaves the list just fades (it went out of range, not out).
#       "open" true plays a sizzle loop on top while it rains (weather.rain), louder with more rain.
#   sound.fire.light(at)        the lighting sound once, at a position
#   sound.fire.put_out(at)      the put-out hiss once (rain or water on a fire)
#
# Only the nearest preset["town_loops"] fires play (Low 3, Mid 5, High 8), none beyond REACH_M.
# Sounds: generated in assets/audio/fire/ (make_fire.py); recordings in assets/audio/recorded/fire/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/fire/"
const RECORDED_DIR := "res://assets/audio/recorded/fire/"

const REACH_M := 35.0
const UNIT_SIZE := 4.0
const SMALL_DB := -13.0
const LARGE_DB := -10.0
const RAIN_DB := -16.0
const ONE_SHOT_DB := -8.0
const SCAN_SEC := 0.5
const NEW_FIRE_SETTLE_MSEC := 6000      # fires seen in the first seconds were loaded with the world, not just lit
const NEW_FIRE_NEAR_M := 6.0
const FIRE_SIZE := 0.5                  # size of a world campfire until fires have a burn time
const FADE_DB_PER_SEC := 30.0

var loops_playing: int = 0              # HUD
var lit_played: int = 0
var out_played: int = 0
var last: String = ""

var _stage                              # SoundStage (weather.rain)
var _fires: Array = []
var _loops: Dictionary = {}             # id -> {"small", "large", "rain": players, "lit": bool, "size", "rain_on", "gone"}
var _was_lit: Dictionary = {}           # id -> lit last time
var _scan_left: float = 0.0
var _manual_until_msec: int = 0
var _first_set_msec: int = -1
var _here: Vector3 = Vector3.ZERO       # the player, from the last update
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# The sound test places its own fire: the world sync keeps off for a while.
func hold_manual(seconds: float) -> void:
	_manual_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


func manual_active() -> bool:
	return Time.get_ticks_msec() < _manual_until_msec


func set_fires(fires: Array) -> void:
	var first_list: bool = _first_set_msec < 0

	if first_list:
		_first_set_msec = Time.get_ticks_msec()

	var settled: bool = Time.get_ticks_msec() - _first_set_msec > NEW_FIRE_SETTLE_MSEC

	for fire in fires:
		var id = fire["id"]
		var lit: bool = bool(fire.get("lit", true))

		# A lit fire first seen right beside the player, once the world has settled, was just made: it catches.
		if settled and not _was_lit.has(id) and lit and fire["at"].distance_to(_here) <= NEW_FIRE_NEAR_M:
			light(fire["at"])

		if _was_lit.has(id) and _was_lit[id] != lit:
			if lit:
				light(fire["at"])
			else:
				put_out(fire["at"])

		_was_lit[id] = lit

	_fires = fires


# The campfires the Items thread keeps (inventory_view `_world`: rows with state 0 item, 1 lit fire,
# 2 burnt-out fire): call about once a second. Size is a fixed middle value until fires have a burn
# time; a fire is "open" when the cover query says the sky reaches it.
func sync_world(world: Dictionary, cover_at: Callable = Callable()) -> void:
	var fires: Array = []

	for id in world:
		var row: Dictionary = world[id]

		if int(row["state"]) == 0:
			continue

		var at: Vector3 = row["pos"]
		fires.append({"id": id, "at": at, "size": FIRE_SIZE, "lit": int(row["state"]) == 1,
			"open": not (cover_at.is_valid() and bool(cover_at.call(at)))})

	set_fires(fires)


func light(at: Vector3) -> void:
	_one_shot("fire_light", at)
	lit_played += 1


func put_out(at: Vector3) -> void:
	_one_shot("fire_out", at)
	out_played += 1


func update(delta: float, body: CharacterBody3D) -> void:
	_here = body.global_position
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_scan(body)

	var rain: float = float(_stage.weather.rain)

	for id in _loops.keys():
		var loop: Dictionary = _loops[id]
		var gone: bool = bool(loop["gone"])
		var size: float = float(loop["size"])
		var lit: bool = bool(loop["lit"]) and not gone
		var targets: Dictionary = {
			"small": SMALL_DB + 20.0 * log(maxf(1.0 - size, 0.02)) / log(10.0) if lit else -80.0,
			"large": LARGE_DB + 20.0 * log(maxf(size, 0.02)) / log(10.0) if lit else -80.0,
			"rain": RAIN_DB + 20.0 * log(maxf(rain, 0.02)) / log(10.0) + 6.0 * size if lit and bool(loop["rain_on"]) and rain > 0.05 else -80.0,
		}
		var alive: bool = false

		for name in ["small", "large", "rain"]:
			var player: AudioStreamPlayer3D = loop[name]

			if player == null:
				continue

			player.volume_db = move_toward(player.volume_db, float(targets[name]), FADE_DB_PER_SEC * delta)

			if player.volume_db > -70.0 or float(targets[name]) > -70.0:
				alive = true

		if gone and not alive:
			for name in ["small", "large", "rain"]:
				if loop[name] != null:
					loop[name].queue_free()

			_loops.erase(id)

	loops_playing = _loops.size()


func _scan(body: CharacterBody3D) -> void:
	var here: Vector3 = body.global_position
	var near: Array = []

	for fire in _fires:
		var distance: float = fire["at"].distance_to(here)

		if distance <= REACH_M:
			near.append({"fire": fire, "distance": distance})

	near.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var wanted: Dictionary = {}

	for entry in near.slice(0, int(_stage.preset["town_loops"])):
		wanted[entry["fire"]["id"]] = entry["fire"]

	for id in wanted:
		var fire: Dictionary = wanted[id]

		if not _loops.has(id):
			var made: Dictionary = {"small": _loop_player("fire_small", fire["at"]), "large": _loop_player("fire_large", fire["at"]),
				"rain": _loop_player("fire_rain", fire["at"]), "lit": true, "size": 0.5, "rain_on": false, "gone": false}

			if made["small"] == null and made["large"] == null:
				continue

			_loops[id] = made

		var loop: Dictionary = _loops[id]
		loop["lit"] = bool(fire.get("lit", true))
		loop["size"] = clampf(float(fire.get("size", 0.5)), 0.0, 1.0)
		loop["rain_on"] = bool(fire.get("open", true))
		loop["gone"] = false

		for name in ["small", "large", "rain"]:
			if loop[name] != null:
				loop[name].global_position = fire["at"]

	for id in _loops:
		if not wanted.has(id):
			_loops[id]["gone"] = true


func _loop_player(name: String, at: Vector3) -> AudioStreamPlayer3D:
	var list: Array = _variants(name)

	if list.is_empty():
		return null

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]

	if player.stream is AudioStreamOggVorbis:
		player.stream.loop = true

	player.bus = "Foley"
	player.volume_db = -80.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = UNIT_SIZE
	player.max_distance = REACH_M * 1.5
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.play(_rng.randf() * 4.0)
	return player


func _one_shot(name: String, at: Vector3) -> void:
	var list: Array = _variants(name)

	if list.is_empty() or not _stage.has_room():
		return

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = ONE_SHOT_DB + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.97, 1.03)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = UNIT_SIZE
	player.max_distance = REACH_M * 2.0
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	last = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list


func _exit_tree() -> void:
	for id in _loops:
		for name in ["small", "large", "rain"]:
			if _loops[id][name] != null:
				_loops[id][name].stop()
				_loops[id][name].stream = null

	_streams.clear()
