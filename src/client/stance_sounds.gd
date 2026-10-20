extends Node

# Stance and cloth sounds (client only): crouching, sitting, lying down, getting up and settling, plus a softer
# step while crouched. A hook for the stance system (Ground thread, CONTROLS.md: C crouch, X sit, Z lie, toggles):
#
#   sound.stance.set_stance("stand" | "crouch" | "sit" | "lie")    call whenever the stance may have changed (every
#                                                                  frame is fine); the change itself is what plays
#
# Changes play: stand to crouch `stance_crouch`, to sit `stance_sit`, to lie `stance_lie`, anything back up
# `stance_rise` (crouch to sit or lie plays the new posture). While sitting or lying, a tiny `stance_settle` shifts
# in every 9 to 22 s. Worn armour adds its own clink to each change (`gear.shift`). No loops, one-shots only, skipped
# when the voice budget is full. Crouching makes footsteps 6 dB softer (`step_db`, read by sound_stage.footstep) and the
# body gear with them; sitting and lying have no steps.
# Sounds: generated in assets/audio/stance/ (make_stance.py); recordings in assets/audio/recorded/stance/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/stance/"
const RECORDED_DIR := "res://assets/audio/recorded/stance/"

const DB := {"crouch": -26.0, "sit": -24.0, "lie": -23.0, "rise": -26.0, "settle": -36.0}
const CROUCH_STEP_DB := -6.0
const SETTLE_EVERY := [9.0, 22.0]

var stance: String = "stand"
var changes_played: int = 0
var settles_played: int = 0
var last: String = ""                   # HUD

var _stage                              # SoundStage (voice budget, gear)
var _settle_left: float = 12.0
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


# How much softer a step is at this stance (sound_stage.footstep adds it to the step's boost).
func step_db() -> float:
	return CROUCH_STEP_DB if stance == "crouch" else 0.0


func set_stance(new_stance: String) -> void:
	if not new_stance in ["stand", "crouch", "sit", "lie"] or new_stance == stance:
		return

	var sound_name: String = "rise" if new_stance == "stand" else new_stance
	stance = new_stance
	_settle_left = _rng.randf_range(float(SETTLE_EVERY[0]), float(SETTLE_EVERY[1]))
	_play(sound_name, float(DB[sound_name]))
	_stage.gear.shift(float(DB[sound_name]) + 6.0)
	changes_played += 1


func update(delta: float) -> void:
	if stance != "sit" and stance != "lie":
		return

	_settle_left -= delta

	if _settle_left > 0.0:
		return

	_settle_left = _rng.randf_range(float(SETTLE_EVERY[0]), float(SETTLE_EVERY[1]))

	if _play("settle", float(DB["settle"])):
		settles_played += 1


func _play(name: String, volume_db: float) -> bool:
	if not _stage.has_room():
		return false

	var list: Array = _variants("stance_" + name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = volume_db + _rng.randf_range(-1.5, 1.0)
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	last = "stance_%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]
	return true


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
