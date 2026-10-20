extends Node

# The nature layer of the sound stage (client only; DESIGN_IDEAS "Nature ambience"):
# the occasional bird call, a cricket, a frog, a woodpecker, whatever suits the
# place the player is in. Cheap on purpose:
#
# - Every SCAN_SEC seconds it measures how much of each zone the player is in
#   (forest, meadow, water edge, highland) from the tree trunk colliders near
#   the player, the soil and grass under the feet, the water squares around
#   them and the height. Nothing else is looked at.
# - Each call in EVENTS has its own timer. When it comes due it plays only if
#   the zones it belongs to are present (chance = zone weight), the time of
#   day and season allow it, no other call played in the last MIN_GAP_SEC and
#   fewer than max_voices (the quality tier) and the whole sound stage is within its voice budget. Then it is placed in 3D: birds up in the
#   trees, crickets and frogs on the ground, frogs and fish at the water.
# - Running scares wildlife: calls come about half as often above RUN_SCARE_MS.
# - Crow alarm: a crow scolds from the trees when the player keeps running
#   through crow country (forest or highland, by day), at most once per
#   ALARM_COOLDOWN_SEC. alarm(at) is the hook a later danger system calls to
#   warn the player (a predator or bandits near): it plays even when other calls are busy.
# - Birds taking off: running through trees or grass by day sometimes flushes a bird
#   (wing_flap, the owner's recording at several speeds, flying away and fading), and a
#   crow alarm sends crows up too. flush(at) is the hook for other scares.
# - Optional loops `bed_<zone>.ogg` (a quiet forest or stream background) fade in
#   with the zone weight when a file exists; none ship yet.
#
# No day, season or weather clock exists yet: `conditions` holds the values it
# will take (hour 0 to 24, season, weather) and today stays on a fall afternoon.
# Sounds: generated placeholders in assets/audio/ambient/ (make_ambient.py),
# recordings in assets/audio/recorded/ambient/ win. Names are in EVENTS.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/ambient/"
const RECORDED_DIR := "res://assets/audio/recorded/ambient/"

const EVENT_TICK_SEC := 0.1          # the call timers tick at 10 Hz
const SCAN_SEC := 1.5
const MIN_GAP_SEC := 3.0               # no two calls closer than this
const RUN_SCARE_MS := 8.0
const TRUNK_RADIUS := 45.0
const TRUNKS_FOR_FOREST := 28.0        # collider shapes in that radius for a full forest
const WATER_RINGS := [6.0, 16.0, 32.0, 55.0]
const WATER_FULL_M := 8.0              # water this close counts as full water-edge weight
const WATER_NONE_M := 55.0
const HIGH_FROM_M := 60.0              # height where the highland starts to count
const HIGH_FULL_M := 130.0
const BED_DB := -26.0
# season -> [sunrise, sunset] in game hours (24 h day; a game day is one real hour)
const SUN := {"spring": [6.0, 19.5], "summer": [5.0, 21.0], "autumn": [6.5, 18.5], "winter": [7.5, 16.5]}
const CHORUS_BEFORE := 0.8             # the dawn chorus swells this long before sunrise...
const CHORUS_AFTER := 1.6              # ...and fades this long after it
const CHORUS_RATE := 3.5               # tries come this many times as often at the peak
const DUSK_BEFORE := 1.0               # dusk swell: this long before sunset...
const DUSK_AFTER := 0.75               # ...and after
const DARK_BEFORE := 0.5               # dark from this long before sunrise to this long after sunset
const GAME_HOURS_PER_SEC := 24.0 / 3600.0   # game clock: 24 game hours per real hour
const FLUSH_DB := -7.0
const FLUSH_CHANCE := 0.12             # per scan while running in forest or meadow by day
const FLUSH_COOLDOWN_SEC := 25.0
const FLUSH_FLY_SEC := [1.6, 3.2]
const FLUSH_FLY_M := [25.0, 60.0]
const ALARM_DB := -6.0
const ALARM_COOLDOWN_SEC := 90.0
const ALARM_RUN_SEC := 2.0             # running this long in crow country can set one off
const ALARM_CHANCE := 0.15             # per scan while that holds

# name: sound file base name (name_N.ogg). zones: zone -> how well the call fits it (0 to 1).
# every: seconds between tries. dist: metres from the player. height: metres above the ground
# (birds in the trees). water: placed at a water square. db: loudness at the source.
# hours: [from, to] fixed clock hours it may be heard (wraps past midnight). day: heard only
# between first light and nightfall; night: only in the dark (both follow the season's sunrise
# and sunset, SUN). chorus: how strongly the dawn chorus (and a little at dusk) speeds its
# tries. night_rate: tries come this many times as often at night. dusk: the same around
# sunset (crickets and frogs start up). seasons: season -> chance multiplier (default 1).
const EVENTS := [
	{"name": "bird_whistle", "zones": {"forest": 1.0, "meadow": 0.5, "highland": 0.3}, "every": [14, 34], "dist": [20, 75], "height": [4, 14], "db": -10.0, "day": true, "chorus": 1.0, "seasons": {"winter": 0.25, "spring": 1.0}},
	{"name": "bird_feebee", "zones": {"forest": 1.0, "meadow": 0.3}, "every": [18, 40], "dist": [20, 70], "height": [4, 12], "db": -11.0, "day": true, "chorus": 1.0, "seasons": {"winter": 0.25, "spring": 1.0}},
	{"name": "bird_trill", "zones": {"meadow": 1.0, "forest": 0.4}, "every": [20, 45], "dist": [15, 60], "height": [1, 8], "db": -12.0, "day": true, "chorus": 1.0, "seasons": {"winter": 0.25, "spring": 1.0}},
	{"name": "bird_chirp", "zones": {"meadow": 1.0, "water": 0.7, "forest": 0.5}, "every": [9, 22], "dist": [8, 45], "height": [0, 5], "db": -12.0, "day": true, "chorus": 1.0, "seasons": {"winter": 0.25, "spring": 1.0}},
	{"name": "crow_caw", "zones": {"forest": 0.6, "highland": 0.8, "meadow": 0.3}, "every": [45, 110], "dist": [60, 160], "height": [6, 18], "db": -8.0, "day": true, "chorus": 0.5},
	{"name": "woodpecker", "zones": {"forest": 1.0}, "every": [40, 100], "dist": [25, 80], "height": [2, 10], "db": -5.0, "day": true, "seasons": {"winter": 0.6}},
	{"name": "owl_hoot", "zones": {"forest": 1.0, "meadow": 0.3}, "every": [30, 70], "dist": [40, 110], "height": [5, 14], "db": -13.0, "night": true, "answer": 0.45, "seasons": {"winter": 1.2, "spring": 1.3, "summer": 0.7, "autumn": 1.0}},
	{"name": "hawk_screech", "zones": {"highland": 1.0}, "every": [60, 150], "dist": [120, 300], "height": [50, 110], "db": -4.0, "hours": [9, 17], "seasons": {"winter": 0.6}},
	{"name": "cricket_chirp", "zones": {"meadow": 1.0, "water": 0.4}, "every": [22, 55], "dist": [5, 28], "height": [0, 0], "db": -16.0, "night_rate": 5.0, "dusk": 2.0, "seasons": {"autumn": 0.9, "summer": 1.0, "spring": 0.3, "winter": 0.0}},
	{"name": "frog_croak", "zones": {"water": 1.0}, "every": [40, 90], "dist": [6, 24], "height": [0, 0], "db": -18.0, "wet": true, "water": true, "night_rate": 3.0, "dusk": 2.0, "seasons": {"autumn": 0.3, "summer": 1.0, "spring": 1.0, "winter": 0.0}},
	{"name": "tree_frog_peep", "zones": {"water": 0.8, "forest": 0.2}, "every": [16, 40], "dist": [4, 28], "height": [0, 3], "db": -14.0, "wet": true, "night_rate": 3.0, "dusk": 2.0, "seasons": {"autumn": 0.2, "summer": 1.0, "spring": 1.0, "winter": 0.0}},
	{"name": "fish_splash", "zones": {"water": 1.0}, "every": [60, 150], "dist": [6, 22], "height": [0, 0], "db": -10.0, "water": true},
]
const ZONES := ["forest", "meadow", "water", "highland"]

var conditions: Dictionary = {"hour": 14.0, "season": "autumn", "weather": "clear"}
var weights: Dictionary = {"forest": 0.0, "meadow": 0.0, "water": 0.0, "highland": 0.0}
var calls_played: Dictionary = {}       # call name -> count (for the headless check)
var last_call: String = ""
var last_file: String = ""              # the file last played, e.g. fish_splash_2
var _source: Dictionary = {}            # call name -> "recorded" or "generated"
var max_voices: int = 4                 # calls and flushes playing at once (the quality tier sets it)
var weather_calls: float = 1.0          # share of calls still made in this weather (weather_sounds.gd)
var weather_frogs: float = 1.0          # share of frog calls in this weather: more in light rain, none in storms
var clock_runs: bool = false            # true: this layer advances conditions["hour"] itself (no game clock yet)
var time_scale: float = 1.0             # >1 speeds the timers (--nature-fast, headless checks)

var _stage                              # SoundStage (ground lookup)
var _flora
var _terrain: Node3D
var _grass
var _rng := RandomNumberGenerator.new()
var _scan_left: float = 0.0
var _next: Dictionary = {}              # call name -> seconds until it is tried
var _event_acc: float = 0.0
var _since_call: float = MIN_GAP_SEC
var _voices: Array = []                 # AudioStreamPlayer3D now playing
var _streams: Dictionary = {}
var _wet_points: Array = []             # [Vector3] water squares found by the last scan
var _sphere: PhysicsShapeQueryParameters3D
var _beds: Dictionary = {}              # zone -> AudioStreamPlayer
var _speed: float = 0.0
var _running_sec: float = 0.0
var _flush_wait: float = 0.0
var _fliers: Array = []                 # [{player, from, to, t, dur}] birds flying off
var _alarm_wait: float = 0.0
var _answers: Array = []                # owl answers waiting: [{left, name, at, db}]
var answers_played: int = 0
const ANSWER_SEC := [3.0, 6.0]


func setup(stage, terrain: Node3D, flora, grass) -> void:
	_stage = stage
	_terrain = terrain
	_flora = flora
	_grass = grass
	_rng.randomize()

	for arg in OS.get_cmdline_user_args():
		if arg == "--nature-fast":
			time_scale = 25.0
		elif arg == "--clock":
			clock_runs = true
		elif arg.begins_with("--hour="):
			conditions["hour"] = float(arg.get_slice("=", 1))
		elif arg.begins_with("--season="):
			conditions["season"] = arg.get_slice("=", 1)

	for event in EVENTS:
		_next[event["name"]] = _rng.randf_range(float(event["every"][0]), float(event["every"][1])) * 0.5

	for zone in ZONES:
		var list: Array = _variants("bed_" + zone)

		if not list.is_empty() and list[0] is AudioStreamOggVorbis:
			list[0].loop = true
			var bed: AudioStreamPlayer = AudioStreamPlayer.new()
			bed.stream = list[0]
			bed.bus = "Nature"
			bed.volume_db = -80.0
			add_child(bed)
			bed.play()
			_beds[zone] = bed


func update(delta: float, body: CharacterBody3D, flying: bool) -> void:
	_speed = Vector2(body.velocity.x, body.velocity.z).length()
	_running_sec = _running_sec + delta if _speed > RUN_SCARE_MS and not flying else 0.0
	_alarm_wait -= delta * time_scale
	_flush_wait -= delta * time_scale
	_move_fliers(delta)
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC
		_scan(body)
		_maybe_scare_crows(body)
		_maybe_flush(body)

	for zone in _beds:
		var target: float = linear_to_db(maxf(float(weights[zone]), 0.0001)) + BED_DB
		_beds[zone].volume_db = lerpf(_beds[zone].volume_db, maxf(target, -80.0), clampf(delta * 1.5, 0.0, 1.0))

	if clock_runs:
		conditions["hour"] = fposmod(float(conditions["hour"]) + delta * GAME_HOURS_PER_SEC, 24.0)

	_since_call += delta
	_event_acc += delta

	if _event_acc < EVENT_TICK_SEC:
		return

	# The call timers run at 10 Hz on the time that passed (nothing here needs frame precision).
	var tick: float = _event_acc
	_event_acc = 0.0
	_voices = _voices.filter(func(v): return is_instance_valid(v) and v.playing)
	var step: float = tick * time_scale
	_play_answers(step)

	for event in EVENTS:
		var name: String = event["name"]
		_next[name] = float(_next[name]) - step * _rate(event)

		if float(_next[name]) > 0.0:
			continue

		_next[name] = _rng.randf_range(float(event["every"][0]), float(event["every"][1]))

		if _since_call * time_scale < MIN_GAP_SEC or _voices.size() >= max_voices or not _stage.has_room():
			continue

		_try(event, body)


func _play_answers(step: float) -> void:
	for n in range(_answers.size() - 1, -1, -1):
		_answers[n]["left"] = float(_answers[n]["left"]) - step

		if float(_answers[n]["left"]) > 0.0:
			continue

		var answer: Dictionary = _answers[n]
		_answers.remove_at(n)
		var list: Array = _variants(str(answer["name"]))

		if list.is_empty() or _voices.size() >= max_voices or not _stage.has_room():
			continue

		var player: AudioStreamPlayer3D = _play(str(answer["name"]), list, answer["at"], float(answer["db"]))
		player.pitch_scale *= 0.9
		answers_played += 1


# The share of each zone around the player, smoothed so the mix changes gently.
func _scan(body: CharacterBody3D) -> void:
	var position: Vector3 = body.global_position
	var feet: Vector3 = position - Vector3(0.0, 0.9, 0.0)
	var target: Dictionary = {"forest": 0.0, "meadow": 0.0, "water": 0.0, "highland": 0.0}

	target["forest"] = clampf(float(_trunks(body)) / TRUNKS_FOR_FOREST, 0.0, 1.0)
	var soil: int = _stage.ground_at(feet)
	var thick: float = 0.0

	if _grass != null and soil >= 0:
		thick = _grass.grass_at(feet.x, feet.z, soil).x

	target["meadow"] = (1.0 - target["forest"]) * clampf(0.2 + thick, 0.0, 1.0)
	target["highland"] = clampf((position.y - HIGH_FROM_M) / (HIGH_FULL_M - HIGH_FROM_M), 0.0, 1.0)
	_wet_points.clear()
	var nearest: float = WATER_NONE_M + 1.0

	for ring in WATER_RINGS:
		for k in range(8):
			var angle: float = TAU * float(k) / 8.0 + float(ring) * 0.3
			var x: float = feet.x + cos(angle) * ring
			var z: float = feet.z + sin(angle) * ring
			var level: float = _flora.water_surface_at(x, z)

			if not is_nan(level):
				_wet_points.append(Vector3(x, level, z))
				nearest = minf(nearest, ring)

	var here: float = _flora.water_surface_at(feet.x, feet.z)

	if not is_nan(here):
		nearest = 0.0

	target["water"] = clampf(1.0 - (nearest - WATER_FULL_M) / (WATER_NONE_M - WATER_FULL_M), 0.0, 1.0)

	for zone in ZONES:
		weights[zone] = lerpf(float(weights[zone]), float(target[zone]), 0.4)


func _trunks(body: CharacterBody3D) -> int:
	if _sphere == null:
		_sphere = PhysicsShapeQueryParameters3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = TRUNK_RADIUS
		_sphere.shape = shape

	_sphere.transform = Transform3D(Basis.IDENTITY, body.global_position)
	_sphere.exclude = [body.get_rid()]
	var count: int = 0

	for hit in body.get_world_3d().direct_space_state.intersect_shape(_sphere, 64):
		if hit["collider"] != null and hit["collider"].has_meta("species_ids"):
			count += 1

	return count


# Called by whatever owns the game clock (the single time source) when it exists.
func set_conditions(hour: float, season: String, weather: String = "clear") -> void:
	conditions["hour"] = hour
	conditions["season"] = season
	conditions["weather"] = weather
	clock_runs = false


func _sun() -> Array:
	return SUN.get(str(conditions["season"]), SUN["autumn"])


func _is_night() -> bool:
	var hour: float = float(conditions["hour"])
	var sun: Array = _sun()
	return hour < float(sun[0]) - DARK_BEFORE or hour >= float(sun[1]) + DARK_BEFORE


# 0 to 1 bump: rises over `before`, falls over `after`, around `at` (hours; wraps midnight).
func _swell(at: float, before: float, after: float) -> float:
	var d: float = fposmod(float(conditions["hour"]) - at + 12.0, 24.0) - 12.0

	if d < -before or d > after:
		return 0.0

	return smoothstep(0.0, 1.0, 1.0 + d / before) if d < 0.0 else smoothstep(0.0, 1.0, 1.0 - d / after)


# How many times faster than normal this call's timer runs right now.
func _rate(event: Dictionary) -> float:
	var sun: Array = _sun()
	var rate: float = 1.0
	var chorus: float = float(event.get("chorus", 0.0))

	if chorus > 0.0:
		rate += (CHORUS_RATE - 1.0) * chorus * _swell(float(sun[0]), CHORUS_BEFORE, CHORUS_AFTER)
		rate += (CHORUS_RATE - 1.0) * 0.4 * chorus * _swell(float(sun[1]), DUSK_BEFORE, DUSK_AFTER)

	if _is_night():
		rate *= float(event.get("night_rate", 1.0))

	var dusk: float = float(event.get("dusk", 1.0))

	if dusk > 1.0:
		rate *= 1.0 + (dusk - 1.0) * _swell(float(sun[1]), DUSK_BEFORE, DUSK_AFTER)

	return rate


func _hour_ok(event: Dictionary) -> bool:
	if event.get("day", false) and _is_night():
		return false

	if event.get("night", false) and not _is_night():
		return false

	if not event.has("hours"):
		return true

	var hour: float = float(conditions["hour"])
	var from: float = float(event["hours"][0])
	var to: float = float(event["hours"][1])
	return (hour >= from and hour < to) if from < to else (hour >= from or hour < to)


# A due call: plays when the zones, hour and season allow it.
func voices_playing() -> int:
	return _voices.size()


func _try(event: Dictionary, body: CharacterBody3D) -> void:
	if not _hour_ok(event):
		return

	var fit: float = 0.0

	for zone in event["zones"]:
		fit = maxf(fit, float(event["zones"][zone]) * float(weights[zone]))

	var season: float = float(event.get("seasons", {}).get(str(conditions["season"]), 1.0))
	var scare: float = 0.5 if _speed > RUN_SCARE_MS else 1.0

	var weather: float = weather_frogs if event.get("wet", false) else weather_calls

	if _rng.randf() > fit * season * scare * weather:
		return

	var list: Array = _variants(event["name"])

	if list.is_empty():
		return

	var at: Vector3 = _place(event, body)

	if is_nan(at.x):
		return

	_play(event["name"], list, at, float(event["db"]))
	last_call = "%s %.0f m (%s)" % [last_file, at.distance_to(body.global_position), _source.get(event["name"], "?")]
	calls_played[event["name"]] = int(calls_played.get(event["name"], 0)) + 1

	# An owl is sometimes answered a few seconds later from the other side, a little quieter and lower.
	if _rng.randf() < float(event.get("answer", 0.0)) * weather:
		var other: Vector3 = body.global_position + (body.global_position - at).limit_length(float(event["dist"][1]))
		_answers.append({"left": _rng.randf_range(ANSWER_SEC[0], ANSWER_SEC[1]), "name": event["name"], "at": Vector3(other.x, at.y, other.z), "db": float(event["db"]) - 4.0})


# A crow scolds from the trees near `at`: the warning hook for danger (and for a player
# crashing through crow country). Returns false when no alarm sound exists.
func alarm(at: Vector3) -> bool:
	var list: Array = _variants("crow_alarm")

	if list.is_empty():
		return false

	_play("crow_alarm", list, at, ALARM_DB).set_meta("keep", true)     # a danger cue: never shed
	flush(at + Vector3(0.0, 1.0, 0.0), 0.35)
	_alarm_wait = ALARM_COOLDOWN_SEC
	last_call = "crow_alarm"
	calls_played["crow_alarm"] = int(calls_played.get("crow_alarm", 0)) + 1
	return true


# Plays one of the calls in EVENTS at a place now (a hook: the creature system says a bird there called).
func call_named(name: String, at: Vector3) -> bool:
	var list: Array = _variants(name)

	if list.is_empty():
		return false

	var db: float = -10.0

	for event in EVENTS:
		if event["name"] == name:
			db = float(event["db"])

	_play(name, list, at, db)
	last_call = name
	calls_played[name] = int(calls_played.get(name, 0)) + 1
	return true


func _maybe_scare_crows(body: CharacterBody3D) -> void:
	var crows: float = maxf(float(weights["forest"]), float(weights["highland"]))

	if _alarm_wait > 0.0 or _running_sec < ALARM_RUN_SEC or _is_night() or crows < 0.4:
		return

	if _rng.randf() > ALARM_CHANCE * crows * time_scale:
		return

	var at: Vector3 = _place({"dist": [25, 50], "height": [6, 14]}, body)

	if not is_nan(at.x):
		alarm(at)


func _maybe_flush(body: CharacterBody3D) -> void:
	if _flush_wait > 0.0 or _running_sec < 1.0 or _is_night():
		return

	var cover: float = maxf(float(weights["forest"]), float(weights["meadow"]) * 0.6)

	if _rng.randf() > FLUSH_CHANCE * cover * weather_calls * time_scale:
		return

	var at: Vector3 = _place({"dist": [10, 30], "height": [0, 3]}, body)

	if not is_nan(at.x):
		flush(at, 0.0)


# A bird (or a few) bursts out of cover at `at` and flies off: wing beats that move and fade.
# `delay` waits before it starts (a crow takes off after it calls).
func flush(at: Vector3, delay: float = 0.0) -> bool:
	var list: Array = _variants("wing_flap")

	if list.is_empty():
		return false

	var player: AudioStreamPlayer3D = _play("wing_flap", list, at, FLUSH_DB)
	_flush_wait = FLUSH_COOLDOWN_SEC
	var angle: float = _rng.randf() * TAU
	var away: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf_range(float(FLUSH_FLY_M[0]), float(FLUSH_FLY_M[1]))
	var dur: float = _rng.randf_range(float(FLUSH_FLY_SEC[0]), float(FLUSH_FLY_SEC[1]))
	_fliers.append({"player": player, "from": at, "to": at + away + Vector3(0.0, _rng.randf_range(4.0, 12.0), 0.0), "t": -delay, "dur": dur})
	calls_played["wing_flap"] = int(calls_played.get("wing_flap", 0)) + 1

	if delay > 0.0:
		player.stream_paused = true

	return true


func _move_fliers(delta: float) -> void:
	for n in range(_fliers.size() - 1, -1, -1):
		var flier: Dictionary = _fliers[n]
		var player = flier["player"]                             # untyped: it may already be freed

		if not is_instance_valid(player) or not player.playing:
			_fliers.remove_at(n)
			continue

		flier["t"] = float(flier["t"]) + delta

		if float(flier["t"]) < 0.0:
			continue

		player.stream_paused = false
		var k: float = clampf(float(flier["t"]) / float(flier["dur"]), 0.0, 1.0)
		player.global_position = flier["from"].lerp(flier["to"], k)


func _play(name: String, list: Array, at: Vector3, db: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var pick: int = _rng.randi_range(0, list.size() - 1)
	player.stream = list[pick]
	last_file = "%s_%d" % [name, pick]
	player.bus = "Nature"
	player.volume_db = db + _rng.randf_range(-2.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 12.0
	player.max_distance = 400.0
	player.attenuation_filter_cutoff_hz = 9000.0
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_voices.append(player)
	_since_call = 0.0
	return player


# Where the call comes from: a water square for frogs and fish, else a random
# direction at the call's distance, on the ground plus the call's height.
func _place(event: Dictionary, body: CharacterBody3D) -> Vector3:
	if event.get("water", false):
		if _wet_points.is_empty():
			return Vector3(NAN, 0.0, 0.0)

		var p: Vector3 = _wet_points[_rng.randi_range(0, _wet_points.size() - 1)]
		return p + Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0))

	var distance: float = _rng.randf_range(float(event["dist"][0]), float(event["dist"][1]))
	var angle: float = _rng.randf() * TAU
	var origin: Vector3 = body.global_position
	var x: float = origin.x + cos(angle) * distance
	var z: float = origin.z + sin(angle) * distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, origin.y + 80.0, z), Vector3(x, origin.y - 120.0, z))
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		return Vector3(NAN, 0.0, 0.0)

	var height: float = _rng.randf_range(float(event["height"][0]), float(event["height"][1]))
	return Vector3(x, float(hit["position"].y) + height, z)


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)
	_source[name] = "recorded"

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)
		_source[name] = "generated"

	_streams[name] = list
	return list


func _exit_tree() -> void:
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

	for bed in _beds.values():
		bed.stop()
		bed.stream = null

	_streams.clear()
