extends Node

# Single rain drops landing near the player (client only), different on each ground: a tick on stone, a pat on grass, a
# soft hiss on sand, a plop in mud, a dry tick on leaves, a plip on water. They ride on top of the rain beds
# (weather_sounds.gd), which stay the bulk of the sound; these add the detail you hear close by.
#
# Rate: RATE_MAX drops a second at full rain, rising a little faster than the rain itself, none under a canopy or a roof
# (the leaf patter and drips take over there), none when snow lies, in a cave or under water. Each drop lands 1 to 7 m
# away (nearer more often). Drops over water (a pond or river within reach) are plips, the rest take the ground under the
# player, from stage.splash_ground(). One-shots in the group world_sounds on the Weather bus, so they are the first cut when the
# voice cap bites; the layer also keeps to nature_calls + 2 drops at once and asks has_room() before every drop.
# Sounds: assets/audio/splash/rain_splash_<ground>_N (make_splash.py); recordings in recorded/splash/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/splash/"
const RECORDED_DIR := "res://assets/audio/recorded/splash/"

const RATE_MAX := 6.0                   # drops a second at full rain
const RAIN_FROM := 0.12
const NEAR_M := 1.0
const FAR_M := 7.0
const BASE_DB := -27.0                  # at the source, full rain
const GROUND_DB := {"stone": 3.0, "gravel": 0.0, "grass": -3.0, "dirt": -2.0, "sand": -4.0, "mud": -1.0, "litter": 0.0, "water": 0.0}
const GROUND_SCAN_SEC := 0.5
const EXTRA_DROPS := 2                  # on top of the preset's nature_calls

var drops_played: int = 0
var by_ground: Dictionary = {}          # ground -> drops played (checks)
var last: String = ""                   # ground and file of the last drop
var ground: String = ""                 # what the player stands on at the last scan ("" none: snow lying)

var _stage                              # SoundStage (budget, ground, water)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _acc: float = 0.0
var _scan_left: float = 0.0
var _live: Array = []


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# Drops a second for this weather: none under cover, rising a little faster than the rain.
func rate(rain: float, covered: float, roofed: float, snow_lying: bool) -> float:
	if rain < RAIN_FROM or snow_lying:
		return 0.0

	return RATE_MAX * pow(clampf(rain, 0.0, 1.0), 1.3) * (1.0 - clampf(covered, 0.0, 1.0)) * (1.0 - clampf(roofed, 0.0, 1.0))


func cap() -> int:
	return int(_stage.preset["nature_calls"]) + EXTRA_DROPS


func update(delta: float, body: CharacterBody3D, underwater: bool) -> void:
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = GROUND_SCAN_SEC
		ground = _stage.splash_ground(body)

	var weather = _stage.weather
	var snow: bool = ground == "" or weather.ground_snow >= 0.35

	if underwater or _stage.cave.enclosure > 0.3:
		return

	_acc += rate(weather.rain, weather.covered, weather.roofed, snow) * delta * _stage.ambient.time_scale
	_acc = minf(_acc, 3.0)

	while _acc >= 1.0:
		_acc -= 1.0
		var angle: float = _rng.randf() * TAU
		var distance: float = lerpf(NEAR_M, FAR_M, pow(_rng.randf(), 1.6))
		var at: Vector3 = body.global_position + Vector3(cos(angle) * distance, -0.9, sin(angle) * distance)
		var surface: String = "water" if _stage.water_depth_at(at) > 0.0 else ground
		drop(surface, at, weather.rain)


# One drop of `surface` at `at`. False when over the budget or no sound exists.
func drop(surface: String, at: Vector3, rain: float = 1.0) -> bool:
	_live = _live.filter(func(p): return is_instance_valid(p))

	if _live.size() >= cap() or not _stage.has_room() or not GROUND_DB.has(surface):
		return false

	var name: String = "rain_splash_" + surface
	var list: Array = _variants(name)

	if list.is_empty():
		return false

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	var pick: int = _rng.randi_range(0, list.size() - 1)
	player.stream = list[pick]
	player.bus = "Weather"
	player.volume_db = BASE_DB + float(GROUND_DB[surface]) + 6.0 * clampf(rain, 0.0, 1.0) + _rng.randf_range(-3.0, 1.5)
	player.pitch_scale = _rng.randf_range(0.88, 1.15)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 2.5
	player.max_distance = 16.0
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	_live.append(player)
	drops_played += 1
	by_ground[surface] = int(by_ground.get(surface, 0)) + 1
	last = "%s %s_%d (%s)" % [surface, name, pick, SoundStage.tag(player.stream)]
	return true


# Headless checks: ends every live drop at once (the checks run faster than a drop lasts).
func test_release() -> void:
	for p in _live:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()

	_live.clear()


func voices_playing() -> int:
	_live = _live.filter(func(p): return is_instance_valid(p))
	return _live.size()


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
