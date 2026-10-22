extends Node

# Creature calls (client only): the voices of the wild animals, as hooks for a later creature
# system. Nothing here knows an animal; a caller says which kind called, where, and in what mood.
#
#   sound.creatures.call_at("wolf", position, "idle")     one call at a place
#   sound.creatures.call_in_zone("forest", "idle")        a call from a random kind that lives in that
#                                                         zone, at a distance that suits it
#   sound.creatures.kinds_in(zone)                        the kinds that live in a zone
#   sound.creatures.wild = true                           far, natural calls by zone, hour and weather
#                                                         (off by default: no animals exist yet)
#
# Kinds: deer, rabbit, fox, wolf, bear, and "bird" (a songbird by day, crow alarm when alert or
# threat, played by ambient_life.gd). Moods: "idle" (a normal call), "alert" (it noticed something),
# "threat" (angry or hurt: a danger cue, always allowed even when the voice budget is full).
# Sounds: generated in assets/audio/creatures/ (make_creatures.py); recordings in
# assets/audio/recorded/creatures/ win. Names: deer_grunt, deer_snort, rabbit_thump, rabbit_squeak,
# fox_bark, fox_scream, wolf_howl, wolf_growl, bear_growl, bear_roar (_N variants).

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/creatures/"
const RECORDED_DIR := "res://assets/audio/recorded/creatures/"

# calls: mood -> sound. db at the source, dist: how far a natural call sounds from the player,
# reach: furthest it is played at all, unit: attenuation size (bigger carries further),
# zones: weight of each zone the kind lives in, hours: when it calls by itself (from, to; wraps midnight),
# every: seconds between its natural calls, cutoff: far-distance muffling (Hz).
const KINDS := {
	"deer": {"calls": {"idle": "deer_grunt", "alert": "deer_snort", "threat": "deer_snort"}, "db": -8.0, "dist": [25.0, 110.0], "reach": 260.0, "unit": 10.0,
		"zones": {"meadow": 1.0, "forest": 0.6, "highland": 0.2, "water": 0.3}, "hours": [4.0, 22.0], "every": [160.0, 400.0], "cutoff": 7000.0},
	"rabbit": {"calls": {"idle": "rabbit_thump", "alert": "rabbit_thump", "threat": "rabbit_squeak"}, "db": -14.0, "dist": [6.0, 25.0], "reach": 45.0, "unit": 3.0,
		"zones": {"meadow": 1.0, "forest": 0.3}, "hours": [5.0, 21.0], "every": [300.0, 700.0], "cutoff": 6000.0},
	"fox": {"calls": {"idle": "fox_bark", "alert": "fox_bark", "threat": "fox_scream"}, "db": -8.0, "dist": [40.0, 170.0], "reach": 320.0, "unit": 12.0,
		"zones": {"forest": 1.0, "meadow": 0.6, "highland": 0.3}, "hours": [20.0, 5.0], "every": [200.0, 500.0], "cutoff": 8000.0, "seasons": {"winter": 1.3, "autumn": 1.0, "spring": 1.0, "summer": 0.8}},
	"wolf": {"calls": {"idle": "wolf_howl", "alert": "wolf_growl", "threat": "wolf_growl"}, "db": -5.0, "dist": [150.0, 520.0], "reach": 950.0, "unit": 40.0,
		"zones": {"highland": 1.0, "forest": 0.6, "meadow": 0.2}, "hours": [21.0, 5.0], "every": [240.0, 600.0], "cutoff": 6000.0, "seasons": {"winter": 1.6, "autumn": 1.0, "spring": 0.7, "summer": 0.4}},
	"bear": {"calls": {"idle": "bear_growl", "alert": "bear_growl", "threat": "bear_roar"}, "db": -4.0, "dist": [30.0, 130.0], "reach": 320.0, "unit": 15.0,
		"zones": {"forest": 1.0, "highland": 0.6}, "hours": [6.0, 20.0], "every": [420.0, 900.0], "cutoff": 5000.0},
}
const BIRD_IDLE := ["bird_whistle", "bird_feebee", "bird_trill", "bird_chirp"]

var tier: int = 2
var wild: bool = true                   # natural far calls on their own (Dave Q6: birds and small game plus wolf and bear); false silences them
var calls_played: Dictionary = {}       # kind -> count
var last: String = ""                   # kind, mood, file and distance for the HUD

var _stage                              # SoundStage (ambient weights, hour, weather, voice budget)
var _streams: Dictionary = {}
var _voices: Array = []
var _next: Dictionary = {}              # kind -> seconds until its next natural call
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func set_tier(new_tier: int) -> void:
	tier = new_tier


# The kinds that live in a zone (forest, meadow, water, highland), commonest first.
func kinds_in(zone: String) -> Array:
	var found: Array = []

	for kind in KINDS:
		var weight: float = float(KINDS[kind]["zones"].get(zone, 0.0))

		if weight > 0.0:
			found.append([weight, kind])

	found.sort_custom(func(a, b): return a[0] > b[0])
	return found.map(func(entry): return entry[1])


# One call by `kind` at `at` in `mood`. False when nothing played (unknown kind, no sound,
# too far to be heard, or the voice budget is full and the call is not a threat).
func call_at(kind: String, at: Vector3, mood: String = "idle") -> bool:
	var listener: Vector3 = get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() != null else Vector3.ZERO

	if kind == "bird":
		return _bird(at, mood)

	if not KINDS.has(kind):
		return false

	var info: Dictionary = KINDS[kind]
	var distance: float = listener.distance_to(at)

	if distance > float(info["reach"]):
		return false

	_prune()

	if mood != "threat" and (_voices.size() >= int(_stage.preset["creature_voices"]) or not _stage.has_room()):
		return false

	var sound_name: String = str(info["calls"].get(mood, info["calls"]["idle"]))
	var list: Array = _variants(sound_name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[pick]
	player.bus = "Nature"
	player.volume_db = float(info["db"]) + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = float(info["unit"])
	player.max_distance = float(info["reach"]) * 1.2
	player.attenuation_filter_cutoff_hz = float(info["cutoff"])
	add_child(player)
	player.add_to_group("world_sounds")

	if mood == "threat":
		player.set_meta("keep", true)                            # a danger cue: never shed

	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_voices.append(player)
	calls_played[kind] = int(calls_played.get(kind, 0)) + 1
	last = "%s %s %s_%d (%s) at %.0f m" % [kind, mood, sound_name, pick, SoundStage.tag(list[pick]), distance]
	return true


# A call from a random kind of the zone, at a distance that suits it, in a random direction.
func call_in_zone(zone: String, mood: String = "idle") -> bool:
	var kinds: Array = kinds_in(zone)

	if kinds.is_empty():
		return false

	var weights: Array = kinds.map(func(k): return float(KINDS[k]["zones"][zone]))
	var roll: float = _rng.randf() * weights.reduce(func(a, b): return a + b, 0.0)

	for n in range(kinds.size()):
		roll -= weights[n]

		if roll <= 0.0 or n == kinds.size() - 1:
			return call_nearby(kinds[n], mood)

	return false


# A call by `kind` somewhere around the player at the kind's natural distance.
func call_nearby(kind: String, mood: String = "idle", distance_m: float = -1.0) -> bool:
	if not KINDS.has(kind):
		return false

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return false

	var range_m: Array = KINDS[kind]["dist"]
	var distance: float = distance_m if distance_m >= 0.0 else _rng.randf_range(float(range_m[0]), float(range_m[1]))
	var angle: float = _rng.randf() * TAU
	var origin: Vector3 = camera.global_position
	var at: Vector3 = origin + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 80.0, 0.0), at - Vector3(0.0, 120.0, 0.0))
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	at.y = float(hit["position"].y) + 1.0 if not hit.is_empty() else origin.y

	return call_at(kind, at, mood)


func voices_playing() -> int:
	_prune()
	return _voices.size()


# Forgets voices that finished (their players free themselves).
func _prune() -> void:
	var live: Array = []

	for voice in _voices:
		if is_instance_valid(voice) and voice.playing:
			live.append(voice)

	_voices = live


func update(delta: float) -> void:
	if not wild:
		return

	var hour: float = float(_stage.ambient.conditions["hour"])
	var zone: String = _main_zone()

	for kind in KINDS:
		if not _next.has(kind):
			_next[kind] = _rng.randf_range(0.2, 1.0) * float(KINDS[kind]["every"][0])

		_next[kind] = float(_next[kind]) - delta * _stage.ambient.time_scale

		if float(_next[kind]) > 0.0:
			continue

		var every: Array = KINDS[kind]["every"]
		_next[kind] = _rng.randf_range(float(every[0]), float(every[1]))
		var hours: Array = KINDS[kind]["hours"]
		var open: bool = hour >= float(hours[0]) and hour < float(hours[1]) if float(hours[0]) < float(hours[1]) else hour >= float(hours[0]) or hour < float(hours[1])

		if open and _rng.randf() < float(KINDS[kind]["zones"].get(zone, 0.0)) * _stage.ambient.weather_calls * season_factor(kind):
			call_nearby(kind, "idle")


# How much the season favours this kind's natural calls (wolves howl most in winter), 1 when the table says nothing.
func season_factor(kind: String) -> float:
	return float(KINDS[kind].get("seasons", {}).get(str(_stage.ambient.conditions["season"]), 1.0))


func _main_zone() -> String:
	var best: String = "meadow"
	var top: float = -1.0

	for zone in _stage.ambient.weights:
		if float(_stage.ambient.weights[zone]) > top:
			top = float(_stage.ambient.weights[zone])
			best = str(zone)

	return best


func _bird(at: Vector3, mood: String) -> bool:
	if mood == "idle":
		return _stage.ambient.call_named(BIRD_IDLE[_rng.randi_range(0, BIRD_IDLE.size() - 1)], at)

	return _stage.ambient.alarm(at)


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list
