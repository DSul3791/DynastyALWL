extends Node

# Breathing and heartbeat (client only), tied to physical EXERTION only (owner, 2026-10-17 and
# DESIGN_IDEAS 6.16): no fear, pain or adrenaline triggers yet. Low exertion is silent, rising
# exertion brings audible breathing that gets faster and heavier, severe exertion brings gasping
# and a strong heartbeat.
#
#   sound.breath.set_exertion(0.0 .. 1.0)    the real exertion value, once an exertion system exists
#   sound.breath.clear_exertion()            go back to the stand-in
#
# Until then a stand-in estimates exertion from how the body moves (walk rests, jog and run build it
# up, swimming holds it high, resting lets it drain); `follow_body` runs it. A set_exertion call
# switches the stand-in off while it keeps being called (EXTERNAL_MSEC).
#
#   exertion 0 to QUIET:  nothing            QUIET to 0.5: soft breaths, slow
#   0.5 to 0.8: clear breaths, quicker       over 0.8: gasps; heartbeat from HEART_FROM, 60 to 170 bpm
#
# Plays on the Foley bus (the Effects slider), 2D (it is inside the player's head), not while the
# eyes are under water. Sounds: assets/audio/body/ (make_body.py); recordings in recorded/body/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/body/"
const RECORDED_DIR := "res://assets/audio/recorded/body/"

const QUIET := 0.25
const HEART_FROM := 0.55
const EXTERNAL_MSEC := 1500
const RISE_PER_SEC := {"walk": 0.0, "jog": 0.045, "run": 0.07, "swim": 0.05}   # toward the pace's ceiling
const CEILING := {"walk": 0.2, "jog": 0.62, "run": 1.0, "swim": 0.75}
const DRAIN_PER_SEC := 0.05
const JOG_MPS := 7.0
const RUN_MPS := 9.8

var exertion: float = 0.0               # 0 to 1 (HUD)
var breaths_played: int = 0
var beats_played: int = 0
var last: String = ""

var _stage                              # SoundStage
var _player: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _breath_left: float = 1.0
var _out_pending: float = -1.0
var _beat_left: float = 1.0
var _external_until: int = 0
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.bus = "Foley"
	add_child(_player)
	_heart = AudioStreamPlayer.new()
	_heart.bus = "Foley"
	add_child(_heart)


func set_exertion(value: float) -> void:
	exertion = clampf(value, 0.0, 1.0)
	_external_until = Time.get_ticks_msec() + EXTERNAL_MSEC


func clear_exertion() -> void:
	_external_until = 0


# The stand-in: exertion from the body's own motion. Called each frame by the sound stage.
func follow_body(delta: float, body: CharacterBody3D, flying: bool, swimming: bool) -> void:
	if Time.get_ticks_msec() < _external_until:
		return

	var speed: float = Vector2(body.velocity.x, body.velocity.z).length()
	var pace: String = ""

	if flying or not body.is_on_floor() and not swimming:
		pace = ""
	elif swimming and speed > 0.3:
		pace = "swim"
	elif speed >= RUN_MPS:
		pace = "run"
	elif speed >= JOG_MPS:
		pace = "jog"
	elif speed > 0.5:
		pace = "walk"

	if pace != "" and exertion < float(CEILING[pace]):
		exertion = minf(exertion + float(RISE_PER_SEC[pace]) * delta, float(CEILING[pace]))
	elif pace == "" or exertion > float(CEILING[pace]) + 0.02:
		exertion = maxf(exertion - DRAIN_PER_SEC * delta, 0.0)


func update(delta: float, underwater: bool) -> void:
	if underwater or exertion < QUIET:
		_breath_left = minf(_breath_left, 0.5)
		_beat_left = minf(_beat_left, 0.5)
		_out_pending = -1.0
		return

	_breath_left -= delta

	if _out_pending >= 0.0:
		_out_pending -= delta

		if _out_pending < 0.0:
			_play(_player, "breath_out", _level_db(), 1.0)

	if _breath_left <= 0.0:
		var cycle: float = lerpf(4.2, 0.9, clampf((exertion - QUIET) / (1.0 - QUIET), 0.0, 1.0))
		_breath_left = cycle * _rng.randf_range(0.92, 1.08)

		if exertion > 0.8:
			_play(_player, "breath_gasp", _level_db(), _rng.randf_range(0.95, 1.1))
			_out_pending = -1.0
		else:
			_play(_player, "breath_in", _level_db(), 1.0)
			_out_pending = cycle * 0.4

	if exertion >= HEART_FROM:
		_beat_left -= delta

		if _beat_left <= 0.0:
			var bpm: float = lerpf(60.0, 170.0, clampf((exertion - HEART_FROM) / (1.0 - HEART_FROM), 0.0, 1.0))
			_beat_left = 60.0 / bpm
			_play(_heart, "heartbeat", lerpf(-34.0, -20.0, clampf((exertion - HEART_FROM) / (1.0 - HEART_FROM), 0.0, 1.0)), 1.0)
			beats_played += 1


func _level_db() -> float:
	return lerpf(-38.0, -14.0, clampf((exertion - QUIET) / (1.0 - QUIET), 0.0, 1.0))


func _play(player: AudioStreamPlayer, name: String, db: float, pitch: float) -> void:
	var list: Array = _variants(name)

	if list.is_empty():
		return

	var pick: int = _rng.randi_range(0, list.size() - 1)
	player.stream = list[pick]
	player.volume_db = db + _rng.randf_range(-1.0, 1.0)
	player.pitch_scale = pitch * _rng.randf_range(0.97, 1.03)
	player.play()

	if name != "heartbeat":
		breaths_played += 1
		last = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]


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
