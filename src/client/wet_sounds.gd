extends Node
# Wet-tunnel sounds (Dave 2026-10-23; plan: art/WET_TUNNEL_PLAN.md). Water drips through the ceiling of a tunnel within 4 m of water above; no water
# accumulates. Not hooked up yet: Sonny/Steve own the "water above" query. Hook (about 4 times a second, from the client):
#   sound.wet.update(delta, here, gap_m)   gap_m = metres of rock between the tunnel ceiling and the water above (use 99 or more when dry or outdoors)
#   sound.wet.step(at)                     once per footstep while stage(gap_m) > 0, on top of the normal mud-like step
# Stages: 0 dry (over 4 m), 1 damp (4 to 2.5 m, rare drips), 2 dripping (2.5 to 1.2 m), 3 running (under 1.2 m, drips and a soft trickle loop).
#
# Sounds: generated in assets/audio/wet/ (make_wet.py); recordings in assets/audio/recorded/wet/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/wet/"
const RECORDED_DIR := "res://assets/audio/recorded/wet/"
const NAMES := {"drip_plink": -16.0, "drip_trickle": -22.0, "wet_step": -14.0}
const DRIP_SECONDS := {1: [4.0, 8.0], 2: [1.0, 3.0], 3: [0.3, 1.0]}     # the gap between two drips near the player, by stage
const DRIP_RADIUS_M := 5.0
const MAX_DISTANCE_M := 30.0

var played: Dictionary = {}             # sound name -> count
var stage_now: int = 0

var _stage                              # SoundStage (voice budget)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_drip: float = 0.0
var _clock: float = 0.0
var _loop: AudioStreamPlayer3D


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# 0 dry, 1 damp, 2 dripping, 3 running, from the metres of rock above the tunnel ceiling.
static func stage_of(gap_m: float) -> int:
	if gap_m > 4.0:
		return 0

	if gap_m > 2.5:
		return 1

	return 2 if gap_m > 1.2 else 3


func update(delta: float, here: Vector3, gap_m: float) -> void:
	_clock += delta
	stage_now = stage_of(gap_m)
	_set_trickle(stage_now == 3, here)

	if stage_now == 0 or _clock < _next_drip:
		return

	var span: Array = DRIP_SECONDS[stage_now]
	_next_drip = _clock + _rng.randf_range(float(span[0]), float(span[1]))
	var angle: float = _rng.randf_range(0.0, TAU)
	var reach: float = _rng.randf_range(1.0, DRIP_RADIUS_M)
	_once("drip_plink", here + Vector3(cos(angle) * reach, _rng.randf_range(-1.2, 0.0), sin(angle) * reach))


func step(at: Vector3) -> bool:
	return _once("wet_step", at)


func _set_trickle(on: bool, here: Vector3) -> void:
	if on and _loop == null:
		var list: Array = _variants("drip_trickle")

		if list.is_empty() or _stage == null:
			return

		_loop = AudioStreamPlayer3D.new()
		var looped = list[_rng.randi_range(0, list.size() - 1)].duplicate()

		if looped is AudioStreamOggVorbis:
			looped.loop = true

		_loop.stream = looped
		_loop.bus = "Foley"
		_loop.volume_db = float(NAMES["drip_trickle"])
		_loop.unit_size = 5.0
		_loop.max_distance = MAX_DISTANCE_M
		add_child(_loop)
		_loop.play()
		played["drip_trickle"] = int(played.get("drip_trickle", 0)) + 1      # counted when the loop starts (it is not a one-shot)

	if _loop != null:
		if on:
			_loop.global_position = here + Vector3(0.0, 0.6, 0.0)
		else:
			_loop.queue_free()
			_loop = null


func _once(sound_name: String, at: Vector3) -> bool:
	if _stage == null or not _stage.has_room():
		return false

	var list: Array = _variants(sound_name)

	if list.is_empty():
		return false

	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = list[_rng.randi_range(0, list.size() - 1)]
	player.bus = "Foley"
	player.volume_db = float(NAMES[sound_name]) + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.93, 1.07)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 4.0
	player.max_distance = MAX_DISTANCE_M
	add_child(player)
	player.add_to_group("world_sounds")
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	played[sound_name] = int(played.get(sound_name, 0)) + 1
	return true


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
