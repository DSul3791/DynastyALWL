extends Node

# Breathing and heartbeat (client only), tied to physical EXERTION only (owner, 2026-10-17 and
# DESIGN_IDEAS 6.16): no fear, pain or adrenaline triggers yet. Low exertion is silent, rising
# exertion brings audible breathing that gets faster and heavier, severe exertion brings gasping
# and a strong heartbeat.
#
#   sound.breath.set_exertion(value)         the real exertion value, 0 to EXERTION_MAX (no cap at 1: past 1 is over-exerted)
#   sound.breath.set_body(value, state, faint)   the Items exertion system: state normal, over_exerted ("over"), fainting
#                                            (vision going), fainted or waking; faint 0..1 is client.faint.blackout (Art's fade)
#   sound.breath.clear_exertion()            go back to the stand-in
#
# Stages (Dave, 2026-10-20): exertion keeps climbing past 1.0: the heart races very loud and fast and breathing becomes
# great loud chest heaves (`breath_heave`); when forced to slow down it stays that intense while exertion drains slowly.
# Fainted: all other sound fades with the faint progress (`world_mute` dips the Wind, Nature, Weather, Foley and
# Interface buses, see sound_stage), only the heartbeat remains, then it fades out over HEART_GONE_SEC once the
# vision is gone. Waking: heart still racing at the real exertion, the world sound returns slowly over WAKE_SEC,
# breathing heaves ease as exertion comes down.
#
# Until then a stand-in estimates exertion from how the body moves (walk rests, jog and run build it
# up, swimming holds it high, resting lets it drain); `follow_body` runs it. A set_exertion call
# switches the stand-in off while it keeps being called (EXTERNAL_MSEC).
#
#   exertion 0 to QUIET:  nothing            QUIET to 0.5: soft breaths, slow
#   heartbeat from HEART_FROM: 60 bpm rising smoothly to 175 at the blackout threshold, 200 at the biggest overshoot
#
# Plays on its own "Body" bus (the Effects slider; it stays when the other buses fade for a faint), 2D (it is inside the player's head), not while the
# eyes are under water. Sounds: assets/audio/body/ (make_body.py); recordings in recorded/body/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/body/"
const RECORDED_DIR := "res://assets/audio/recorded/body/"

const QUIET := 0.25
const HEART_FROM := 0.55
const EXTERNAL_MSEC := 1500
const RISE_PER_SEC := {"walk": 0.0, "jog": 0.045, "run": 0.07, "swim": 0.05}   # toward the pace's ceiling
const CEILING := {"walk": 0.2, "jog": 0.62, "run": 2.0, "swim": 0.75}   # running never plateaus: it keeps climbing past 1 (over-exerted)
const EXERTION_MAX := 2.0
const OVER := 1.0                       # from here: racing heart, chest heaves
const FAINT_AT := 1.4                   # the blackout threshold (data/items/exertion.json faint_at)
const BPM_REST := 60.0                  # at HEART_FROM
const BPM_FAINT := 175.0                # right at the blackout threshold (Dave 2026-10-21)
const BPM_PEAK := 200.0                 # at the biggest overshoot (EXERTION_MAX)
const BPM_EASE := 40.0                  # beats per minute the rate may change per second: never a step
const OVER_SPAN := 0.4                  # over to fainting (data/items/exertion.json faint_at 1.4): the intensity climbs over this much
const HEART_GONE_SEC := 3.0             # the heartbeat after the vision is gone
const WAKE_SEC := 4.0                   # the world sound returns this slowly after a faint
const MUTE_RATE := 0.8                  # world_mute follows its target at this much per second (fade out about 1.3 s)
const DRAIN_PER_SEC := 0.05
const JOG_MPS := 7.0
const RUN_MPS := 9.8

var exertion: float = 0.0               # 0 to EXERTION_MAX (HUD); past 1 is over-exerted
var state: String = "normal"            # normal, over, fainted, waking (HUD)
var world_mute: float = 0.0             # 0 normal .. 1 everything but the heart is silent (sound_stage reads it)
var heaves_played: int = 0
var breaths_played: int = 0
var beats_played: int = 0
var bpm_now: float = 0.0                # the heart rate now, eased (HUD, checks)
var server_bpm: float = 0.0             # the server's heart rate for a faint or sleep (0: use the exertion curve)
var server_phase: int = 0
var bpm_max: float = 0.0
var bpm_step_max: float = 0.0           # the biggest change between two frames, bpm
var last: String = ""

var _stage                              # SoundStage
var _player: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _breath_left: float = 1.0
var _out_pending: float = -1.0
var _beat_left: float = 1.0
var _external_until: int = 0
var _faint: float = 0.0                 # vision lost, 0..1
var _gone_t: float = 0.0                # seconds since the vision went (fainted)
var _heart_gain: float = 1.0
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_ensure_bus()
	_player.bus = "Body"
	add_child(_player)
	_heart = AudioStreamPlayer.new()
	_heart.bus = "Body"
	add_child(_heart)


# The body's own bus: the Effects slider sets it, and a faint leaves it alone while the rest fades.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index("Body") < 0:
		AudioServer.add_bus()
		var at: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(at, "Body")
		AudioServer.set_bus_send(at, "Master")


func set_exertion(value: float) -> void:
	exertion = clampf(value, 0.0, EXERTION_MAX)
	_external_until = Time.get_ticks_msec() + EXTERNAL_MSEC
	state = "over" if exertion >= OVER else "normal"
	_faint = 0.0


# The real exertion system (Items): value, state and faint progress, called while it holds (like set_exertion).
func set_body(value: float, new_state: String, faint_progress: float = 0.0) -> void:
	exertion = clampf(value, 0.0, EXERTION_MAX)
	_external_until = Time.get_ticks_msec() + EXTERNAL_MSEC
	state = {"over_exerted": "over"}.get(new_state, new_state)    # Items and Art say over_exerted
	state = state if state in ["normal", "over", "fainting", "fainted", "waking", "sleeping"] else "normal"
	_faint = clampf(faint_progress, 0.0, 1.0)

	if state == "fainted" or state == "fainting":
		exertion = maxf(exertion, 1.2)       # the heart is still racing in a faint, whatever strain the server holds


# The heart the server sets in the ears (protocol 59 body(bpm, eta, phase), Dave 2026-10-21): 0 awake; in a faint a rapid beat a little
# higher in pitch that drops to a brisk 140 as you are about to wake; asleep a slow beat that keeps slowing. phase: 0 awake, 1 falling
# asleep, 2 out, 3 waking. While out the rest of the world is muted and the heart stays heard (it does not fade away).
func set_server_heart(bpm: float, phase: int) -> void:
	server_bpm = bpm
	server_phase = phase


func clear_exertion() -> void:
	_external_until = 0


# The stand-in: exertion from the body's own motion. Called each frame by the sound stage.
func follow_body(delta: float, body: CharacterBody3D, flying: bool, swimming: bool) -> void:
	if Time.get_ticks_msec() < _external_until:
		return

	state = "over" if exertion >= OVER else "normal"

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


# A scripted run of the stages for the sound test and --faint: over-exertion climbs to 1.4, forced slow-down
# (held), faint with the vision going over 2.5 s, 3 s of heartbeat alone then silence, waking with the heart racing
# and settling over 10 s. 25 s in all; peak_mute and demo_min_gain record what was reached.
var _demo_t: float = -1.0
var peak_mute: float = 0.0
var demo_min_gain: float = 1.0
var demo_done: bool = false
var breaths_at_faint: int = 0
var _demo_prev: String = ""
var fainted_breaths: int = 0             # breaths heard while fainted (must stay 0)
var wake_mute_mid: float = -1.0          # the world mute halfway through waking (between 0 and 1: the world returns with the vision)


func demo() -> void:
	_demo_t = 0.0
	peak_mute = 0.0
	demo_min_gain = 1.0
	demo_done = false


func _run_demo(delta: float) -> void:
	_demo_t += delta
	var t: float = _demo_t

	if t < 6.0:
		set_body(lerpf(0.9, 1.4, t / 6.0), "over_exerted")
	elif t < 9.0:
		set_body(1.4 - 0.02 * (t - 6.0), "over_exerted")
	elif t < 11.5:
		set_body(1.0, "fainting", (t - 9.0) / 2.5)
	elif t < 17.0:
		set_body(1.0, "fainted", 1.0)
	elif t < 27.0:
		set_body(lerpf(1.1, 0.3, (t - 17.0) / 10.0), "waking", 1.0 - (t - 17.0) / 10.0)
		if t > 21.9 and t < 22.1:
			wake_mute_mid = world_mute
	else:
		_demo_t = -1.0
		demo_done = true
		clear_exertion()
		exertion = 0.0
		state = "normal"

	if state == "fainted" and _demo_prev != "fainted":
		breaths_at_faint = breaths_played

	_demo_prev = state

	if state == "fainted":
		fainted_breaths = breaths_played - breaths_at_faint

	peak_mute = maxf(peak_mute, world_mute)
	demo_min_gain = minf(demo_min_gain, _heart_gain)


func update(delta: float, underwater: bool) -> void:
	if _demo_t >= 0.0:
		_run_demo(delta)

	_fade_world(delta)
	var fainted: bool = state == "fainted"

	if fainted and _faint >= 0.999:
		_gone_t += delta
	elif not fainted:
		_gone_t = 0.0

	var out_phase: bool = server_phase >= 1 and server_bpm > 0.0
	var gain_target: float = clampf(1.0 - _gone_t / HEART_GONE_SEC, 0.0, 1.0) if fainted and not out_phase else 1.0
	_heart_gain = move_toward(_heart_gain, gain_target, delta / (HEART_GONE_SEC if fainted and not out_phase else 1.5))

	# Under water the body is silent, except in a faint (the heart is inside the head).
	var silent: bool = (underwater and not fainted and not out_phase) or (exertion < QUIET and state != "waking" and not fainted and not out_phase)

	if silent:
		_breath_left = minf(_breath_left, 0.5)
		_beat_left = minf(_beat_left, 0.5)
		_out_pending = -1.0
		return

	if not fainted:
		_breathe(delta)

	if (exertion >= HEART_FROM or fainted or state == "waking" or out_phase) and _heart_gain > 0.01:
		_beat_left -= delta
		var before: float = bpm_now
		bpm_now = _bpm() if bpm_now <= 0.0 else move_toward(bpm_now, _bpm(), BPM_EASE * delta)
		bpm_max = maxf(bpm_max, bpm_now)
		bpm_step_max = maxf(bpm_step_max, absf(bpm_now - before) if before > 0.0 else 0.0)

		if _beat_left <= 0.0:
			_beat_left = 60.0 / maxf(bpm_now, 30.0)
			var over: float = _over()
			var level: float = lerpf(-34.0, -20.0, clampf((exertion - HEART_FROM) / (OVER - HEART_FROM), 0.0, 1.0)) + 12.0 * over
			var pitch: float = 1.0 + 0.1 * clampf(exertion, 0.0, EXERTION_MAX)

			if out_phase:
				# Faster means a little higher: 44 bpm asleep is a deep slow thud, 172 in a faint is quicker and brighter.
				var fast: float = clampf((bpm_now - 44.0) / 128.0, 0.0, 1.0)
				pitch = lerpf(0.92, 1.16, fast)
				level = lerpf(-28.0, -19.0, fast)

			_play(_heart, "heartbeat", level + linear_to_db(maxf(_heart_gain, 0.001)), pitch)
			beats_played += 1


# 0 at the start of over-exertion to 1 at the faint point.
func _over() -> float:
	return clampf((exertion - OVER) / OVER_SPAN, 0.0, 1.0)


# Beats per minute, one smooth curve of exertion (Dave 2026-10-21): 60 at HEART_FROM up to 175 right at the blackout
# threshold (FAINT_AT), on to 200 at the biggest overshoot (EXERTION_MAX). Fainting or fainted counts as at least the
# threshold, so passing out never starts below 175. update() eases the heart toward this, so there are no steps.
func _bpm() -> float:
	if server_bpm > 0.0:
		return server_bpm

	var e: float = exertion

	if state == "fainting" or state == "fainted":
		e = maxf(e, FAINT_AT)

	if e <= FAINT_AT:
		return lerpf(BPM_REST, BPM_FAINT, clampf((e - HEART_FROM) / (FAINT_AT - HEART_FROM), 0.0, 1.0))

	return lerpf(BPM_FAINT, BPM_PEAK, clampf((e - FAINT_AT) / (EXERTION_MAX - FAINT_AT), 0.0, 1.0))


# Dave 2026-10-21: no heavy breathing on exertion (breath_in, breath_out, breath_gasp, breath_heave); the heartbeat stays.
const BREATHING := false


func _breathe(delta: float) -> void:
	if not BREATHING:
		return

	_breath_left -= delta

	if _out_pending >= 0.0:
		_out_pending -= delta

		if _out_pending < 0.0:
			_play(_player, "breath_out", _level_db(), 1.0)

	if _breath_left > 0.0:
		return

	var t: float = clampf((exertion - QUIET) / (OVER - QUIET), 0.0, 1.0)
	var cycle: float = lerpf(4.2, 0.9, t) - 0.25 * _over()
	_breath_left = cycle * _rng.randf_range(0.92, 1.08)

	if exertion >= OVER:
		_play(_player, "breath_heave", _level_db(), _rng.randf_range(0.92, 1.0))
		heaves_played += 1
		_out_pending = -1.0
	elif exertion > 0.8:
		_play(_player, "breath_gasp", _level_db(), _rng.randf_range(0.95, 1.1))
		_out_pending = -1.0
	else:
		_play(_player, "breath_in", _level_db(), 1.0)
		_out_pending = cycle * 0.4


# The rest of the world's sound follows the faint: out with the vision, back slowly on waking.
func _fade_world(delta: float) -> void:
	var target: float = 0.0

	if state == "fainted" or state == "fainting" or state == "sleeping":
		target = maxf(_faint, 0.0)                                          # out with the vision (client.faint.blackout)
	elif state == "waking":
		target = _faint                                                     # the blackness still left (Items strain_fade, Art's fade)

	var rate: float = MUTE_RATE if target > world_mute else 1.0 / WAKE_SEC
	world_mute = move_toward(world_mute, target, rate * delta)


func _level_db() -> float:
	var db: float = lerpf(-38.0, -14.0, clampf((exertion - QUIET) / (OVER - QUIET), 0.0, 1.0))
	return db + 10.0 * _over()                # heaves reach -4 dB at the limit


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
