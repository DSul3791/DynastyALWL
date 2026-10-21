extends Node

# Step layers (client only): two quiet extras under every footstep.
#
# Wet shoes: wading in water sets `wetness` to 1 (a damp, muddy waterline step to 0.4); it dries over DRY_SEC
# on land, and while it lasts a squelch (`wet_squelch`) joins a share of the steps, softer as the shoes dry.
# Cloth: each step also carries a soft rustle of clothes (`cloth_walk`) 9 dB under the footstep, so it follows the gait
# (walk quietest, run loudest) with it. Not in water, softer still when crouched.
# Both are skipped when the voice budget is full; they are not in the group world_sounds, so they are never shed.
# Called by sound_stage.footstep: `sound.stepfx.step(gait, step_db, surface, depth_m)`.
# Sounds: generated in assets/audio/stepfx/ (make_stepfx.py); recordings in assets/audio/recorded/stepfx/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/stepfx/"
const RECORDED_DIR := "res://assets/audio/recorded/stepfx/"

const DRY_SEC := 20.0
const WET_FROM := 0.12                  # water above the soles that wets the shoes (matches WATER_STEP_M)
const DAMP_WETNESS := 0.4
const SQUELCH_DB := -4.0                # at full wetness, relative to the footstep itself
const CLOTH_DB := -9.0                  # under the footstep's own level, whatever the gait and ground

var wetness: float = 0.0
var squelches: int = 0
var cloth_steps: int = 0
var last: String = ""                   # HUD

var _stage                              # SoundStage (budget, step level)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func update(delta: float) -> void:
	wetness = maxf(wetness - delta / DRY_SEC, 0.0)


# One footstep: `step_db` is the level the footstep itself plays at (gait, ground and boost included).
func step(_gait: int, step_db: float, surface: String, depth_m: float) -> void:
	if depth_m > WET_FROM:
		wetness = 1.0
	elif depth_m > 0.03:
		wetness = maxf(wetness, DAMP_WETNESS)

	if surface == "water" or not _stage.has_room():
		return

	if wetness > 0.05 and _rng.randf() < 0.35 + 0.65 * wetness:
		if _play("wet_squelch", SQUELCH_DB + linear_to_db(wetness) + step_db):
			squelches += 1

	if _play("cloth_walk", step_db + CLOTH_DB):
		cloth_steps += 1


func _play(sound_name: String, volume_db: float) -> bool:
	var list: Array = _variants(sound_name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = volume_db + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.93, 1.07)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	last = "%s_%d (%s), wetness %.2f" % [sound_name, pick, SoundStage.tag(list[pick]), wetness]
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
