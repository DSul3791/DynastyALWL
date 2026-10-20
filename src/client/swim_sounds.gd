extends Node

# Swimming and diving sounds (client only): entering the water by speed, strokes, going under,
# breaking the surface, and the muffled hum under the water. Driven by the player's own body,
# so nothing else has to call it. Wading in shallows stays with the footsteps (step_water).
#
#   splash: the feet go into deep water, or a fast drop into any depth (small under 4 m/s, big above)
#   stroke: while swimming (deeper than SWIM_M), one pull every 0.6 to 1.4 s by speed
#   dive:   the eyes go under; surface: the eyes come out; hum: loop while the eyes are under
# Sounds: generated in assets/audio/swim/ (make_swim.py); recordings in assets/audio/recorded/swim/ win.

const SoundStage := preload("res://src/client/sound_stage.gd")
const GENERATED_DIR := "res://assets/audio/swim/"
const RECORDED_DIR := "res://assets/audio/recorded/swim/"

const LOOK_SEC := 0.1                  # the water and ground are read at 10 Hz; between reads the depth follows the feet
const SWIM_M := 1.3                     # feet this far under the surface: swimming (same as the footsteps)
const ENTER_M := 0.8                    # feet this far under: counts as having jumped in
const FALL_SPLASH_MPS := 2.5            # a drop this fast splashes in any depth
const BIG_SPLASH_MPS := 4.0
const STROKE_MIN_MPS := 0.5
const SPLASH_DB := -9.0
const STROKE_DB := -17.0
const DIVE_DB := -13.0
const SURFACE_DB := -11.0
const HUM_DB := -24.0
const HUM_FADE_DB_PER_SEC := 30.0

var splashes: int = 0
var strokes: int = 0
var dives: int = 0
var surfaces: int = 0
var last: String = ""                   # HUD: the last event and file
var swimming: bool = false
var _look_left: float = 0.0
var _cached_immersion: float = -2.0      # the last water reading (metres over the soles); -2 none yet
var _cached_feet_y: float = 0.0
var demo_runs: int = 0

var _stage                              # SoundStage (water level, voice budget)
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _was_immersion: float = -1.0
var _primed: bool = false              # the first reading only sets the baseline (no splash on loading in)
var _was_eye_under: bool = false
var _stroke_left: float = 0.0
var _hum: AudioStreamPlayer
var _demo_time: float = -1.0
var _fall_mps: float = 0.0              # fastest recent downward speed (kept for the splash)


func setup(stage) -> void:
	_stage = stage
	_rng.randomize()
	_hum = AudioStreamPlayer.new()
	_hum.bus = "Nature"
	_hum.volume_db = -60.0
	add_child(_hum)
	var list: Array = _variants("swim_under")

	if not list.is_empty():
		_hum.stream = list[0]

		if _hum.stream is AudioStreamOggVorbis:
			_hum.stream.loop = true


# Reads the player's body: how deep the soles are under the water, and how fast it moves.
func update(delta: float, body: CharacterBody3D, flying: bool, underwater: bool) -> void:
	if _demo_time >= 0.0:
		_run_demo(delta)
		return

	if flying:
		_step(delta, -1.0, 0.0, 0.0, false)
		return

	_look_left -= delta

	if _look_left > 0.0 and _cached_immersion != -2.0:
		_step(delta, _cached_immersion + (_cached_feet_y - (body.global_position.y - SoundStage.FEET_M)) if _cached_immersion > 0.0 else _cached_immersion, Vector2(body.velocity.x, body.velocity.z).length(), body.velocity.y, underwater)
		return

	_look_left = LOOK_SEC
	var feet: Vector3 = body.global_position - Vector3(0.0, SoundStage.FEET_M, 0.0)
	var level: float = _stage.water_level_at(feet)

	if feet.y < 0.0 and (is_nan(level) or level < 0.0):
		level = 0.0                                              # the sea

	var immersion: float = level - feet.y if not is_nan(level) else -1.0

	# A film of water is wet ground, not a pool (the shared WaterVolume rule, same as the drawing).
	if immersion > 0.0 and feet.y >= 0.0 and _stage.water_depth_at(feet) <= 0.0:
		immersion = -1.0

	_cached_immersion = immersion
	_cached_feet_y = feet.y
	_step(delta, immersion, Vector2(body.velocity.x, body.velocity.z).length(), body.velocity.y, underwater)


# A scripted swim (Esc > Settings test button and the --swim check): jump in, swim, dive, surface,
# climb out, about 10 s. The body is ignored while it runs.
func demo() -> void:
	_demo_time = 0.0
	_primed = false
	_was_eye_under = false


func _run_demo(delta: float) -> void:
	_demo_time += delta
	var t: float = _demo_time
	var immersion: float = -1.0
	var horizontal: float = 0.0
	var vertical: float = 0.0
	var eye_under: bool = false

	if t >= 1.0 and t < 9.0:
		immersion = 2.0
		horizontal = 2.0 if t >= 1.5 else 0.0
		vertical = -6.0 if t < 1.1 else 0.0
		eye_under = t >= 5.0 and t < 7.0
	elif t >= 9.0:
		_demo_time = -1.0

	_step(delta, immersion, horizontal, vertical, eye_under)

	if _demo_time < 0.0:
		demo_runs += 1


# The state machine, fed by update() (and by the headless check with a scripted swim).
# `immersion` is metres of water over the soles (negative: dry), `eye_under` whether the eyes are under.
func _step(delta: float, immersion: float, horizontal: float, vertical: float, eye_under: bool) -> void:
	_fall_mps = maxf(_fall_mps - delta * 4.0, -vertical)          # remembers the fall for a moment
	var was: float = _was_immersion
	_was_immersion = immersion
	swimming = immersion > SWIM_M

	# Into the water: the feet reach deep water, or a fast drop lands in any depth.
	if _primed:
		var crossed_deep: bool = was <= ENTER_M and immersion > ENTER_M
		var crossed_wet: bool = was <= 0.05 and immersion > 0.3 and _fall_mps >= FALL_SPLASH_MPS

		if crossed_deep or crossed_wet:
			splash(maxf(_fall_mps, horizontal * 0.6))
			_fall_mps = 0.0

	_primed = true

	if eye_under and not _was_eye_under:
		_event("swim_dive", DIVE_DB + linear_to_db(clampf(0.4 + _fall_mps / 6.0, 0.4, 1.0)))
		dives += 1
	elif _was_eye_under and not eye_under and immersion > 0.0:
		_event("swim_surface", SURFACE_DB)
		surfaces += 1

	_was_eye_under = eye_under

	# Strokes while swimming, quicker when faster.
	if swimming and horizontal >= STROKE_MIN_MPS:
		_stroke_left -= delta

		if _stroke_left <= 0.0:
			_stroke_left = lerpf(1.4, 0.6, clampf(horizontal / 4.0, 0.0, 1.0))
			_event("swim_stroke", STROKE_DB + (-3.0 if eye_under else 0.0) + _rng.randf_range(-1.5, 1.0))
			strokes += 1
	else:
		_stroke_left = minf(_stroke_left, 0.2)

	# The hum under the water fades in and out.
	if _hum.stream != null:
		_hum.volume_db = move_toward(_hum.volume_db, HUM_DB if eye_under else -60.0, HUM_FADE_DB_PER_SEC * delta)

		if eye_under and not _hum.playing:
			_hum.play(_rng.randf() * 10.0)
		elif not eye_under and _hum.playing and _hum.volume_db <= -58.0:
			_hum.stop()


# An entry splash, small or big by how fast the body hit the water (m/s).
func splash(speed: float) -> void:
	var name: String = "swim_splash_big" if speed >= BIG_SPLASH_MPS else "swim_splash_small"
	var power: float = clampf(speed / 8.0, 0.0, 1.0)
	_event(name, SPLASH_DB + linear_to_db(0.45 + 0.55 * power))
	splashes += 1


func voices_playing() -> int:
	return 1 if _hum != null and _hum.playing else 0


func _event(name: String, volume_db: float) -> void:
	if not _stage.has_room():
		return

	var list: Array = _variants(name)

	if list.is_empty():
		return

	var pick: int = _rng.randi_range(0, list.size() - 1)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = list[pick]
	player.bus = "Foley"
	player.volume_db = volume_db
	player.pitch_scale = _rng.randf_range(0.95, 1.05)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	last = "%s_%d (%s)" % [name, pick, SoundStage.tag(list[pick])]


func _variants(name: String) -> Array:
	if _streams.has(name):
		return _streams[name]

	var list: Array = SoundStage._find(RECORDED_DIR, name)

	if list.is_empty():
		list = SoundStage._find(GENERATED_DIR, name)

	_streams[name] = list
	return list
