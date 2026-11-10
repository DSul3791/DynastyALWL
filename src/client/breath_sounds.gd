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
#   The heartbeat (Dave 9 Nov 2026, docs/design/heartbeat_design.md, data/sound/heartbeat.json): always heard, the Daggorath pulse
#   (assets/audio/heartbeat/) played whole at pitch 1 every 60 / bpm seconds. 55 bpm at rest rising in a straight line of strain to 175 at
#   the blackout threshold and 200 at the biggest overshoot; louder in proportion to the rate. `beat` is emitted on each pulse (the
#   pulse bar over the hotbar, heart_pulse.gd).
#
# Plays on its own "Body" bus (the Effects slider; it stays when the other buses fade for a faint), 2D (it is inside the player's head,
# heard under water too).

signal beat(bpm: float)                  # one heart pulse, at this rate (heart_pulse.gd draws it)

const HEART_PATH := "res://data/sound/heartbeat.json"

const EXTERNAL_MSEC := 1500
const RISE_PER_SEC := {"walk": 0.0, "jog": 0.045, "run": 0.07, "swim": 0.05}   # toward the pace's ceiling
const CEILING := {"walk": 0.2, "jog": 0.62, "run": 2.0, "swim": 0.75}   # running never plateaus: it keeps climbing past 1 (over-exerted)
const EXERTION_MAX := 2.0
const OVER := 1.0                       # from here: racing heart, chest heaves
const FAINT_AT := 1.4                   # the blackout threshold (data/items/exertion.json faint_at)
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
var heart: Dictionary = {}              # data/sound/heartbeat.json
var heart_plays: int = 0                # pulses actually played (a muted bus counts beats but plays none)

var _stage                              # SoundStage
var _heart: AudioStreamPlayer
var _beat_left: float = 1.0
var _external_until: int = 0
var _faint: float = 0.0                 # vision lost, 0..1
var _gone_t: float = 0.0                # seconds since the vision went (fainted)
var _heart_gain: float = 1.0
var _body_bus: int = -1


func setup(stage) -> void:
	_stage = stage
	heart = load_heart()
	_ensure_bus()
	_body_bus = AudioServer.get_bus_index("Body")
	_heart = AudioStreamPlayer.new()
	_heart.bus = "Body"
	var sound_path: String = str(heart.get("sound", ""))
	_heart.stream = load(sound_path) if sound_path != "" and ResourceLoader.exists(sound_path) else null
	add_child(_heart)


static func load_heart() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HEART_PATH))
	return parsed if parsed is Dictionary else {}


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


func update(delta: float, _underwater: bool) -> void:   # the heart is heard under water too (inside the head)
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

	# No breathing sounds on exertion (Dave 2026-10-21); only the heartbeat, always heard (Dave 9 Nov 2026), until a faint takes it.
	if _heart_gain <= 0.01:
		_beat_left = minf(_beat_left, 0.5)
		return

	_beat_left -= delta
	var before: float = bpm_now
	bpm_now = _bpm() if bpm_now <= 0.0 else move_toward(bpm_now, _bpm(), float(heart.get("ease_bpm_per_s", 40.0)) * delta)
	bpm_max = maxf(bpm_max, bpm_now)
	bpm_step_max = maxf(bpm_step_max, absf(bpm_now - before) if before > 0.0 else 0.0)

	if _beat_left <= 0.0:
		_beat_left = 60.0 / maxf(bpm_now, 30.0)
		beats_played += 1
		beat.emit(bpm_now)

		if _heart != null and _heart.stream != null and _audible():
			_heart.volume_db = heart_db(bpm_now) + linear_to_db(maxf(_heart_gain, 0.001))
			_heart.pitch_scale = 1.0          # the pulse as recorded: only the time between pulses changes
			_heart.play()
			heart_plays += 1


# The pulse's level for a heart rate: rest_db at rest_bpm to peak_db at peak_bpm, in a straight line (Dave: "as it gets faster it gets
# louder. very proportional"); a sleeping heart slower than rest stays at rest_db.
func heart_db(bpm: float) -> float:
	var rest: float = float(heart.get("rest_bpm", 55.0))
	var peak: float = float(heart.get("peak_bpm", 200.0))
	return lerpf(float(heart.get("rest_db", -30.0)), float(heart.get("peak_db", -8.0)), clampf((bpm - rest) / maxf(peak - rest, 1.0), 0.0, 1.0))


# Nothing is played into a muted or silent bus (the beat still counts, so the pulse bar keeps time).
func _audible() -> bool:
	var master: int = AudioServer.get_bus_index("Master")

	for bus in [_body_bus, master]:
		if bus >= 0 and (AudioServer.is_bus_mute(bus) or AudioServer.get_bus_volume_db(bus) <= -79.0):
			return false

	return true


# Beats per minute, a straight line of strain (Dave 9 Nov 2026): rest_bpm (55) at rest up to faint_bpm (175) right at the blackout
# threshold (FAINT_AT), on to peak_bpm (200) at the biggest overshoot (EXERTION_MAX). Fainting or fainted counts as at least the
# threshold, so passing out never starts below 175; the server's own rate (asleep, fainted, waking) wins while it sends one. update()
# eases the heart toward this, so there are no steps.
func _bpm() -> float:
	if server_bpm > 0.0:
		return server_bpm

	var e: float = exertion

	if state == "fainting" or state == "fainted":
		e = maxf(e, FAINT_AT)

	var faint_bpm: float = float(heart.get("faint_bpm", 175.0))

	if e <= FAINT_AT:
		return lerpf(float(heart.get("rest_bpm", 55.0)), faint_bpm, clampf(e / FAINT_AT, 0.0, 1.0))

	return lerpf(faint_bpm, float(heart.get("peak_bpm", 200.0)), clampf((e - FAINT_AT) / (EXERTION_MAX - FAINT_AT), 0.0, 1.0))


# The rest of the world's sound follows the faint: out with the vision, back slowly on waking.
func _fade_world(delta: float) -> void:
	var target: float = 0.0

	if state == "fainted" or state == "fainting" or state == "sleeping":
		target = maxf(_faint, 0.0)                                          # out with the vision (client.faint.blackout)
	elif state == "waking":
		target = _faint                                                     # the blackness still left (Items strain_fade, Art's fade)

	var rate: float = MUTE_RATE if target > world_mute else 1.0 / WAKE_SEC
	world_mute = move_toward(world_mute, target, rate * delta)
