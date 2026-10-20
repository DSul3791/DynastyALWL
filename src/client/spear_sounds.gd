extends Node

# Spear sounds (client only): hooks for a later weapon system. Nothing here knows a spear item.
#
#   sound.spear.jab(at)                        a thrust through the air
#   sound.spear.throw(from, to, speed_mps, material)   the heave, then the flight (a whistle that moves
#                                              along the path) and, on arrival, the hit; returns the
#                                              flight time in seconds
#   sound.spear.hit(material, at, strength)    the spear lands: "wood", "stone", "soil" or "flesh"
#
# Sounds: generated in assets/audio/spear/ (make_spear.py); recordings in assets/audio/recorded/spear/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/spear/"
const RECORDED_DIR := "res://assets/audio/recorded/spear/"

const MATERIALS := ["wood", "stone", "soil", "flesh"]
const JAB_DB := -9.0
const THROW_DB := -8.0
const FLIGHT_DB := -14.0
const HIT_DB := -4.0
const MAX_DISTANCE_M := 150.0

var played: Dictionary = {}             # sound name -> count
var last: String = ""

var _stage                              # SoundStage (voice budget)
var _streams: Dictionary = {}
var _flights: Array = []                # {"player", "from", "to", "t", "dur", "material", "strength"}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func jab(at: Vector3) -> bool:
	return _once("spear_jab", at, JAB_DB, 1.0)


# A throw from `from` toward `to` at `speed_mps`. Returns the flight time (0 when nothing played).
func throw(from: Vector3, to: Vector3, speed_mps: float = 28.0, material: String = "wood") -> float:
	if not _once("spear_throw", from, THROW_DB, 1.0):
		return 0.0

	var dur: float = maxf(from.distance_to(to) / maxf(speed_mps, 1.0), 0.05)
	var list: Array = _variants("spear_flight")
	var player: AudioStreamPlayer3D = null

	if not list.is_empty() and _stage.has_room():
		player = _make_player(list[_rng.randi_range(0, list.size() - 1)], FLIGHT_DB, 12.0)
		player.global_position = from
		player.play()
		_count("spear_flight")

	_flights.append({"player": player, "from": from, "to": to, "t": 0.0, "dur": dur, "material": material})

	return dur


# The spear lands in `material` at `at`; strength 0 to 1 sets loudness.
func hit(material: String, at: Vector3, strength: float = 1.0) -> bool:
	if material not in MATERIALS:
		return false

	return _once("spear_hit_" + material, at, HIT_DB, strength)


func update(delta: float) -> void:
	for n in range(_flights.size() - 1, -1, -1):
		var flight: Dictionary = _flights[n]
		flight["t"] = float(flight["t"]) + delta
		var k: float = clampf(float(flight["t"]) / float(flight["dur"]), 0.0, 1.0)
		var player = flight["player"]                              # untyped: it may already be freed

		if player != null and is_instance_valid(player):
			player.global_position = Vector3(flight["from"]).lerp(flight["to"], k)

		if k >= 1.0:
			if player != null and is_instance_valid(player):
				player.stop()
				player.queue_free()

			hit(str(flight["material"]), flight["to"], 1.0)
			_flights.remove_at(n)


func _once(name: String, at: Vector3, db: float, strength: float) -> bool:
	if not _stage.has_room() and not name.begins_with("spear_hit"):
		return false

	var list: Array = _variants(name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = _make_player(list[pick], db + linear_to_db(clampf(0.3 + 0.7 * strength, 0.05, 1.0)) + _rng.randf_range(-1.0, 1.0), 8.0)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_count(name)
	last = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]
	return true


func _make_player(stream: AudioStream, db: float, unit: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "Foley"
	player.volume_db = db
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = unit
	player.max_distance = MAX_DISTANCE_M
	add_child(player)
	player.add_to_group("world_sounds")
	return player


func _count(name: String) -> void:
	played[name] = int(played.get(name, 0)) + 1


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list
