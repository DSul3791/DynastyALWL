extends Node

# Landing after a fall (client only): how hard the ground was hit, by how far the player dropped.
# sound_stage.update calls `land(body, drop_m)` once when the feet touch down after more than 0.45 s in the air.
#
#   under 2.5 m   the heavy step it always was (a jump, a hop off a ledge)
#   2.5 to 5 m    a heavier step and `land_thud` (body weight, breath knocked out)
#   5 m and more  the heaviest step, `land_hard` (double impact, pack rattle, a grunt) and worn gear jolts
#
# THE DAMAGE CALL POINT: from `HURT_M` (6 m for now) `hurt` is emitted with the drop and a severity 0..1. The Items
# thread's fall damage hooks in there (connect to `sound.landing.hurt`, or later replace HURT_M with the server's
# number); nothing else changes, the hard landing already sounds right. Skipped silently when flying (admin).
# Sounds: generated in assets/audio/landing/ (make_landing.py); recordings in assets/audio/recorded/landing/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/landing/"
const RECORDED_DIR := "res://assets/audio/recorded/landing/"

const THUD_FROM_M := 2.5
const HARD_FROM_M := 5.0
const HURT_M := 6.0                     # placeholder until the Items thread sends the real fall damage threshold
const FULL_HURT_M := 14.0               # severity 1.0
const STEP_BOOST_DB := [4.0, 8.0, 11.0] # light, thud, hard
const THUD_DB := -14.0
const HARD_DB := -8.0

signal hurt(drop_m: float, severity: float)

var landings: Dictionary = {}           # class name -> count
var last: String = ""                   # HUD
var _stage                              # SoundStage (footstep, gear, voice budget)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()


func land(body: CharacterBody3D, drop_m: float) -> void:
	var kind: int = 2 if drop_m >= HARD_FROM_M else (1 if drop_m >= THUD_FROM_M else 0)
	var names: Array = ["step", "thud", "hard"]
	landings[names[kind]] = int(landings.get(names[kind], 0)) + 1
	_stage.footstep(body, 2, float(STEP_BOOST_DB[kind]))
	last = "%s from %.1f m" % [names[kind], drop_m]

	if kind == 1:
		_play("land_thud", THUD_DB)
	elif kind == 2:
		_play("land_hard", HARD_DB)
		_stage.gear.shift(-8.0)

	if drop_m >= HURT_M:
		hurt.emit(drop_m, clampf((drop_m - HURT_M) / (FULL_HURT_M - HURT_M), 0.0, 1.0))


func _play(name: String, volume_db: float) -> bool:
	var list: Array = _variants(name)

	if list.is_empty():
		return false

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = volume_db + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = _rng.randf_range(0.96, 1.04)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	last += " %s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]
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
