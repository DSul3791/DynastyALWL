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
# Cost by tier: Low is filters only (a low-pass and a level drop on the Wind, Weather and Nature
# buses) with 5 rays a scan; Mid and High also run a reverb on the Foley and Nature buses and cast 9 rays.
# Drips: assets/audio/cave/cave_drip_N.ogg (make_cave.py), recordings in recorded/cave/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/cave/"
const RECORDED_DIR := "res://assets/audio/recorded/cave/"

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
var drips_played: int = 0
var forced: float = -1.0                # --cave=0..1 forces it (headless checks), -1 measures

var _stage                              # SoundStage (tier, voice room)
var _tier: int = 2
var _target: float = 0.0
var _scan_left: float = 0.0
var _next_drip: float = 3.0
var _lowpass: Dictionary = {}           # bus name -> AudioEffectLowPassFilter
var _amplify: Dictionary = {}           # bus name -> AudioEffectAmplify
var _reverb: AudioEffectReverb
var _reverb_bus: Array = []             # [bus index, effect index] pairs
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

	for bus_name in ["Foley", "Nature"]:
		var bus: int = AudioServer.get_bus_index(bus_name)

		if bus >= 0:
			var effect: AudioEffectReverb = _reverb.duplicate()
			AudioServer.add_bus_effect(bus, effect)
			var at: int = AudioServer.get_bus_effect_count(bus) - 1
			AudioServer.set_bus_effect_enabled(bus, at, false)
			_reverb_bus.append([bus, at, effect])


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

	enclosure = move_toward(enclosure, _target, EASE_PER_SEC * delta)
	_apply()
	_drip(delta, body)


func _measure(body: CharacterBody3D) -> float:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var head: Vector3 = body.global_position + Vector3(0.0, HEAD_M, 0.0)
	var up: float = _rock_hit(space, body, head, Vector3.UP, UP_M)

	if up < 0.0:
		return 0.0                                               # open sky (or trees only)

	var ceiling: float = clampf(1.0 - (up - 2.0) / (UP_M - 2.0), 0.0, 1.0)
	var rays: int = 4 if _tier == 0 else 8
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

	var on: bool = _tier > 0 and enclosure > REVERB_FROM

	for entry in _reverb_bus:
		AudioServer.set_bus_effect_enabled(entry[0], entry[1], on)
		entry[2].wet = 0.45 * enclosure


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
