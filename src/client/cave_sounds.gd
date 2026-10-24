extends Node

# Caves and tunnels (client only): when rock closes in over the player the world sounds
# change: wind, rain and bird calls dull and fade, steps and water echo, and water drips now
# and then from the dark.
#
# Enclosure (0 open air to 1 a tunnel) is measured every SCAN_SEC with a few physics rays from the
# head: straight up (the ceiling) and level all round (the walls). Tree trunks do not count as rock.
# A ceiling alone (an overhang, a cliff ledge) gives a little; ceiling and near walls together
# give the full effect. It eases in and out over a couple of seconds.
#
# Reverb: ONE reverb effect, on a bus "World" that Foley and Nature (and the band buses under them) send to; steps, tools, calls
# and drips echo, the wind/weather/interface/body buses do not. Its size and wetness follow the enclosure: a hollow under a
# ledge is a small dry room, a tunnel a long wet one. Cost by tier: Low runs the same single reverb lighter (small room, wet
# capped at 0.15, 4 rays); Mid and High run it fully (wet up to 0.35 / 0.45, larger room) with 8 rays. Off while open air
# (enclosure under 0.05).
# Drips: assets/audio/cave/cave_drip_N.ogg (make_cave.py), recordings in recorded/cave/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/cave/"
const RECORDED_DIR := "res://assets/audio/recorded/cave/"

const WORLD_BUS := "World"
const SCAN_SEC := 0.25
const UP_M := 30.0                      # ceiling this high counts for nothing beyond it
const WALL_M := 20.0
const HEAD_M := 0.6                     # rays leave from this far above the player origin
const REVERB_FROM := 0.05               # enclosure from which the reverb runs
const EASE_PER_SEC := 0.5               # enclosure follows the measurement over about 2 s
const DRIP_DB := -22.0
const DRIP_EVERY := [2.5, 7.0]
const DRIP_FROM := 0.45                 # enclosure from which drips are heard
const MUFFLE_HZ := 1800.0               # low-pass on wind, weather and nature in a cave
const DROP_DB := {"Wind": -18.0, "Weather": -14.0, "Nature": -8.0}

var enclosure: float = 0.0              # smoothed 0 to 1 (HUD)
var rock_enclosure: float = 0.0         # the same, rock only (no building floor): drives the light (weather_look.gd), smoothed alike
var drips_played: int = 0
var interior_floor: float = 0.0        # a building sets this (interior_sounds.gd): enclosure never below it, no drips from it
var forced: float = -1.0                # --cave=0..1 forces it (headless checks), -1 measures

var _stage                              # SoundStage (tier, voice room)
var _tier: int = 2
var _target: float = 0.0
var _applied: float = -1.0              # the enclosure the bus effects were last set to
var _applied_tier: int = -1
var _scan_left: float = 0.0
var _next_drip: float = 3.0
var _lowpass: Dictionary = {}           # bus name -> AudioEffectLowPassFilter
var _amplify: Dictionary = {}           # bus name -> AudioEffectAmplify
var _reverb: AudioEffectReverb
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cave="):
			forced = float(arg.get_slice("=", 1))

	for bus_name in DROP_DB:
		var bus: int = AudioServer.get_bus_index(bus_name)

		if bus < 0:
			continue

		var low: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		low.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(bus, low)
		_lowpass[bus_name] = low
		var amp: AudioEffectAmplify = AudioEffectAmplify.new()
		amp.volume_db = 0.0
		AudioServer.add_bus_effect(bus, amp)
		_amplify[bus_name] = amp

	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.8
	_reverb.damping = 0.45
	_reverb.spread = 0.8
	_reverb.dry = 1.0
	_reverb.wet = 0.0
	var world: int = SoundStage._make_bus(WORLD_BUS)
	AudioServer.move_bus(world, 1)                      # a bus sends only to buses before it: World goes ahead of Foley and Nature
	world = AudioServer.get_bus_index(WORLD_BUS)
	AudioServer.add_bus_effect(world, _reverb)
	AudioServer.set_bus_effect_enabled(world, 0, false)

	for bus_name in ["Foley", "Nature"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name), WORLD_BUS)


# The quality tier: Low has no reverb and fewer rays.
func set_tier(tier: int) -> void:
	_tier = tier


func update(delta: float, body: CharacterBody3D, flying: bool = false) -> void:
	_scan_left -= delta

	if _scan_left <= 0.0:
		_scan_left = SCAN_SEC

		if forced >= 0.0:
			_target = forced
		elif flying:
			_target = 0.0                                       # no rays while flying (admin look-around)
		else:
			_target = _measure(body)

	enclosure = move_toward(enclosure, maxf(_target, interior_floor), EASE_PER_SEC * delta)
	rock_enclosure = move_toward(rock_enclosure, _target, EASE_PER_SEC * delta)

	if absf(enclosure - _applied) > 0.002 or _tier != _applied_tier:
		_applied = enclosure
		_applied_tier = _tier
		_apply()

	_drip(delta, body)


func _measure(body: CharacterBody3D) -> float:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var head: Vector3 = body.global_position + Vector3(0.0, HEAD_M, 0.0)
	var up: float = _rock_hit(space, body, head, Vector3.UP, UP_M)

	if up < 0.0:
		return 0.0                                               # open sky (or trees only)

	var ceiling: float = clampf(1.0 - (up - 2.0) / (UP_M - 2.0), 0.0, 1.0)
	var rays: int = int(_stage.preset["cave_rays"])
	var near: float = 0.0

	for k in range(rays):
		var angle: float = TAU * float(k) / float(rays)
		var hit: float = _rock_hit(space, body, head, Vector3(cos(angle), 0.0, sin(angle)), WALL_M)

		if hit >= 0.0:
			near += 1.0 - hit / WALL_M

	return clampf(ceiling * (0.35 + 0.65 * near / float(rays) * 1.6), 0.0, 1.0)


# Distance to the first rock along a ray, -1 when none (tree trunks and the player are skipped).
func _rock_hit(space: PhysicsDirectSpaceState3D, body: CharacterBody3D, from: Vector3, direction: Vector3, length: float) -> float:
	var skip: Array = [body.get_rid()]

	for attempt in range(3):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * length)
		query.exclude = skip
		var hit: Dictionary = space.intersect_ray(query)

		if hit.is_empty():
			return -1.0

		if hit["collider"] != null and hit["collider"].has_meta("species_ids"):
			skip.append(hit["rid"])
			continue

		return from.distance_to(hit["position"])

	return -1.0


func _apply() -> void:
	for bus_name in _lowpass:
		_lowpass[bus_name].cutoff_hz = lerpf(20000.0, MUFFLE_HZ, enclosure)
		_amplify[bus_name].volume_db = float(DROP_DB[bus_name]) * enclosure

	var on: bool = bool(_stage.preset["cave_reverb"]) and enclosure > REVERB_FROM
	var world: int = AudioServer.get_bus_index(WORLD_BUS)

	if world >= 0:
		AudioServer.set_bus_effect_enabled(world, 0, on)
		_reverb.wet = float(_stage.preset["cave_wet"]) * enclosure
		_reverb.room_size = lerpf(float(_stage.preset["cave_room"]) * 0.5, float(_stage.preset["cave_room"]), enclosure)


func _drip(delta: float, body: CharacterBody3D) -> void:
	if enclosure < DRIP_FROM:
		return

	_next_drip -= delta

	if _next_drip > 0.0:
		return

	_next_drip = _rng.randf_range(float(DRIP_EVERY[0]), float(DRIP_EVERY[1])) / enclosure

	if not _stage.has_room():
		return

	var list: Array = _variants("cave_drip")

	if list.is_empty():
		return

	var angle: float = _rng.randf() * TAU
	var distance: float = _rng.randf_range(3.0, 12.0)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]
	player.bus = "Nature"
	player.volume_db = DRIP_DB + _rng.randf_range(-4.0, 2.0)
	player.pitch_scale = _rng.randf_range(0.9, 1.1)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 5.0
	player.max_distance = 60.0
	add_child(player)
	player.global_position = body.global_position + Vector3(cos(angle) * distance, _rng.randf_range(-1.0, 1.0), sin(angle) * distance)
	player.finished.connect(player.queue_free)
	player.play()
	drips_played += 1


func _variants(sound_name: String) -> Array:
	if _streams.has(sound_name):
		return _streams[sound_name]

	var list: Array = SoundStage._find(RECORDED_DIR, sound_name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, sound_name)

	_streams[sound_name] = list
	return list


func _exit_tree() -> void:
	_streams.clear()
