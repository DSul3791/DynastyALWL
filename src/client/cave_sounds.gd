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
# Cave air (Dave 24 Oct, Steve_cave_air.md): the outside air is heard for a while after entering, less the further in. DEPTH is the metres walked inside rock
# (grows while rock_enclosure is 0.5 or more, falls 3x as fast walking out below 0.3, holds between); data/sound/cave_air.json turns it into dB per air bus and a
# low-pass; deep inside only Foley is heard (silent base). The older enclosure cut stays on top for half-open places. WET caves (the server's leak message, held
# 20 s) have drips and a full reverb; DRY caves play no drips and half the reverb. Drips are on the Foley bus.

const SoundStage := preload("res://src/client/sound_stage.gd")
const AIR_PATH := "res://data/sound/cave_air.json"
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
var depth_m: float = 0.0                # metres walked inside rock (see above)
var wet: float = 0.0                    # 0 dry cave to 1 dripping ceiling overhead, held wet_hold_s after the last leak message
var air: Dictionary = {}                # data/sound/cave_air.json
var forced_depth: float = -1.0          # --cave-depth=M
var forced_wet: float = -1.0            # --cave-wet=0..1

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
var _last_pos: Vector3 = Vector3.INF
var _applied_depth: float = -1.0
var _applied_wet: float = -1.0
var _wet_left: float = 0.0
var _gap_m: float = 99.0


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cave="):
			forced = float(arg.get_slice("=", 1))
		elif arg.begins_with("--cave-depth="):
			forced_depth = float(arg.get_slice("=", 1))
		elif arg.begins_with("--cave-wet="):
			forced_wet = float(arg.get_slice("=", 1))

	air = load_air(AIR_PATH)

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
	_step_depth(body.global_position)
	_step_wet(delta)

	if absf(enclosure - _applied) > 0.002 or _tier != _applied_tier or absf(depth_m - _applied_depth) > 0.25 or absf(wet - _applied_wet) > 0.05:
		_applied = enclosure
		_applied_tier = _tier
		_applied_depth = depth_m
		_applied_wet = wet
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


# The server's leak message (drip_view.gap_m, 99 when none) goes in here every frame.
func note_gap(gap_m: float) -> void:
	_gap_m = gap_m


func _step_depth(pos: Vector3) -> void:
	if forced_depth >= 0.0:
		depth_m = forced_depth
		return

	var moved: float = Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() if _last_pos.is_finite() else INF
	_last_pos = pos
	depth_m = advance_depth(air, depth_m, moved, rock_enclosure)


func _step_wet(delta: float) -> void:
	if forced_wet >= 0.0:
		wet = forced_wet
		return

	var now: float = wet_from_gap(air, _gap_m)

	if now > 0.0:
		wet = now
		_wet_left = float(air.get("wet_hold_s", 20.0))
	else:
		_wet_left = maxf(_wet_left - delta, 0.0)

		if _wet_left <= 0.0:
			wet = 0.0


# --- the table (static, so the headless test needs no audio) ---

static func load_air(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# Linear interpolation of a row of the table over depth (clamped at both ends).
static func table_value(depths: Array, values: Array, depth: float) -> float:
	if depths.is_empty() or values.size() != depths.size():
		return 0.0

	if depth <= float(depths[0]):
		return float(values[0])

	for k in range(1, depths.size()):
		if depth <= float(depths[k]):
			var span: float = float(depths[k]) - float(depths[k - 1])
			return lerpf(float(values[k - 1]), float(values[k]), (depth - float(depths[k - 1])) / maxf(span, 0.001))

	return float(values[values.size() - 1])


static func air_db(table: Dictionary, bus_name: String, depth: float) -> float:
	return table_value(table.get("depth_m", []), (table.get("db", {}) as Dictionary).get(bus_name, []), depth)


static func air_lowpass(table: Dictionary, depth: float) -> float:
	return table_value(table.get("depth_m", []), table.get("lowpass_hz", []), depth)


# Walked metres inside rock. `moved` is the horizontal metres since the last call (INF = the first call or a teleport).
static func advance_depth(table: Dictionary, depth: float, moved: float, rock: float) -> float:
	var depths: Array = table.get("depth_m", [0, 40])
	var cap: float = float(depths[depths.size() - 1])
	var deep_from: float = float(table.get("deep_from_enclosure", 0.5))
	var shallow_below: float = float(table.get("shallow_below_enclosure", 0.3))

	if is_inf(moved) or moved > 20.0:
		return cap if rock >= deep_from else 0.0

	if rock >= deep_from:
		return minf(depth + moved, cap)

	if rock < shallow_below:
		return maxf(depth - moved * float(table.get("walk_out_factor", 3.0)), 0.0)

	return depth


# 0 dry to 1 for the leak message's closest ceiling gap (metres of rock between a dripping ceiling and the water above it).
static func wet_from_gap(table: Dictionary, gap_m: float) -> float:
	var limit: float = float(table.get("wet_gap_m", 4.0))
	return clampf(1.0 - gap_m / limit, 0.0, 1.0) if gap_m < limit else 0.0


# Drips only in a wet cave (the enclosure must also be there).
static func drips_allowed(table: Dictionary, enclosure_now: float, wet_now: float) -> bool:
	return enclosure_now >= DRIP_FROM and wet_now >= float(table.get("drip_wet_from", 0.2))


func _apply() -> void:
	for bus_name in _lowpass:
		var db: float = minf(air_db(air, bus_name, depth_m), float(DROP_DB[bus_name]) * enclosure)
		var hz: float = minf(air_lowpass(air, depth_m), lerpf(20000.0, MUFFLE_HZ, enclosure))
		_lowpass[bus_name].cutoff_hz = maxf(hz, 500.0)
		_amplify[bus_name].volume_db = maxf(db, -80.0) if db > float(air.get("mute_below_db", -60.0)) else -80.0

	var on: bool = bool(_stage.preset["cave_reverb"]) and enclosure > REVERB_FROM
	var world: int = AudioServer.get_bus_index(WORLD_BUS)

	if world >= 0:
		AudioServer.set_bus_effect_enabled(world, 0, on)
		_reverb.wet = float(_stage.preset["cave_wet"]) * enclosure * lerpf(float(air.get("dry_reverb_mult", 0.5)), 1.0, wet)
		_reverb.room_size = lerpf(float(_stage.preset["cave_room"]) * 0.5, float(_stage.preset["cave_room"]), enclosure)


func _drip(delta: float, body: CharacterBody3D) -> void:
	if not drips_allowed(air, enclosure, wet):
		return

	_next_drip -= delta

	if _next_drip > 0.0:
		return

	_next_drip = _rng.randf_range(float(DRIP_EVERY[0]), float(DRIP_EVERY[1])) / (enclosure * maxf(wet, 0.2))

	if not _stage.has_room():
		return

	var list: Array = _variants("cave_drip")

	if list.is_empty():
		return

	var angle: float = _rng.randf() * TAU
	var distance: float = _rng.randf_range(3.0, 12.0)
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]
	player.bus = "Foley"           # the air buses fade with depth; the drips must stay (and Foley has the cave reverb)
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
