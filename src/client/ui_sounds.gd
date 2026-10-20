extends Node

# Interface sounds (client only): quiet clicks for the menus and short cues for toggles. Own
# "Interface" bus, a little below the footsteps, never muted by the world mixer.
#
#   sound.ui.play("ui_click")      a menu button pressed (every menu button does this)
#   sound.ui.play("ui_on")         a toggle switched on (inspection mode)
#   sound.ui.play("ui_off")        a toggle switched off
#   sound.ui.play("ui_quality")    the quality tier changed
#
# A click right after another cue (the quality button plays its own cue) is skipped, and nothing
# repeats faster than MIN_GAP_MSEC. Sounds: generated in assets/audio/ui/ (make_ui.py);
# recordings in assets/audio/recorded/ui/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/ui/"
const RECORDED_DIR := "res://assets/audio/recorded/ui/"
const NAMES := {"ui_click": -20.0, "ui_on": -18.0, "ui_off": -18.0, "ui_quality": -17.0}
const MIN_GAP_MSEC := 40
const CLICK_SKIP_MSEC := 80

var played: int = 0
var last: String = ""

var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _last_msec: int = -1000
var _last_cue_msec: int = -1000
var _rng := RandomNumberGenerator.new()


func setup(_stage) -> void:
	_rng.randomize()
	SoundStage._make_bus("Interface")
	_player = AudioStreamPlayer.new()
	_player.bus = "Interface"
	add_child(_player)


func play(name: String) -> bool:
	if not NAMES.has(name):
		return false

	var now: int = Time.get_ticks_msec()

	if now - _last_msec < MIN_GAP_MSEC or (name == "ui_click" and now - _last_cue_msec < CLICK_SKIP_MSEC):
		return false

	var list: Array = _variants(name)

	if list.is_empty():
		return false

	_last_msec = now

	if name != "ui_click":
		_last_cue_msec = now

	var pick: int = _rng.randi_range(0, list.size() - 1)
	_player.stream = list[pick]
	_player.volume_db = float(NAMES[name]) + _rng.randf_range(-1.0, 1.0)
	_player.pitch_scale = _rng.randf_range(0.97, 1.03)
	_player.play()
	played += 1
	last = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]
	return true


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list
