extends Node

# Game idle timeout (Dave via the moderator, 31 Oct 2026): after IDLE minutes with no mouse movement, click or key press the game shows a centred warning with a 60 s
# countdown; any input cancels it; at zero the client quits cleanly (the owner's quit function disconnects, so the server saves). The minutes are a player setting
# (display_settings.gd idle_minutes: 5 to 120, default 20). Time is the REAL clock (Time.get_ticks_msec) and only real input events reset it, so a paused game or a debugger
# stop is not "idle". Never active in headless runs, with --no-idle-timeout, or when the client was started with any test, shot or rig switch (only the switches in
# PLAY_ARGS are allowed); --idle-minutes=N overrides the setting (and turns it on for a test).
#   The pure rules (Rules) are tested by test_idle_timeout.gd with a fake clock.

const MIN_MINUTES := 5
const MAX_MINUTES := 120
const DEFAULT_MINUTES := 20
const STEPS := [5, 10, 20, 30, 45, 60, 90, 120]
const COUNTDOWN_S := 60.0
const PLAY_ARGS := ["--server=", "--port=", "--name=", "--quality=", "--host", "--identity=", "--fullscreen", "--windowed"]

signal timed_out

var minutes: int = DEFAULT_MINUTES
var enabled: bool = false
var _last_input_ms: int = 0
var _warning_since_ms: int = -1
var _layer: CanvasLayer
var _label: Label
var _clock: Callable = Callable()      # tests: () -> msec; empty = the real clock


# ---- the rules, no scene needed --------------------------------------------------------------------------------------------

static func clamp_minutes(value: int) -> int:
	return clampi(value, MIN_MINUTES, MAX_MINUTES)


# The step of STEPS nearest to a value, for the settings button.
static func nearest_step(value: int) -> int:
	var best: int = STEPS[0]

	for step in STEPS:
		if absi(int(step) - value) < absi(best - value):
			best = int(step)

	return best


static func next_step(value: int) -> int:
	for step in STEPS:
		if int(step) > value:
			return int(step)

	return int(STEPS[0])


# Is the idle timeout allowed for this client at all? Headless runs, tests, shot runners and bots never get stuck on it.
static func allowed(args: PackedStringArray, headless: bool) -> bool:
	if headless or args.has("--no-idle-timeout"):
		return false

	for argument in args:
		if argument.begins_with("--idle-minutes="):
			continue

		var known: bool = false

		for prefix in PLAY_ARGS:
			if argument == prefix or argument.begins_with(prefix):
				known = true

		if not known:
			return false

	return true


# The minutes to use: the --idle-minutes=N argument when given, else the saved setting; always 5..120.
static func minutes_for(args: PackedStringArray, saved: int) -> int:
	for argument in args:
		if argument.begins_with("--idle-minutes="):
			return clamp_minutes(int(argument.trim_prefix("--idle-minutes=")))

	return clamp_minutes(saved)


# State at a time: 0 active, 1 warning (seconds left in `left`), 2 time is up.
static func state(idle_ms: int, limit_s: float, countdown_s: float) -> Dictionary:
	var idle_s: float = float(idle_ms) / 1000.0

	if idle_s < limit_s:
		return {"state": 0, "left": countdown_s}

	var left: float = limit_s + countdown_s - idle_s
	return {"state": 1, "left": left} if left > 0.0 else {"state": 2, "left": 0.0}


# ---- the node ------------------------------------------------------------------------------------------------------------------

func setup(args: PackedStringArray, saved_minutes: int, headless: bool, clock: Callable = Callable()) -> void:
	_clock = clock
	enabled = allowed(args, headless)
	minutes = minutes_for(args, saved_minutes)
	_last_input_ms = _now()
	set_process(enabled)
	set_process_input(enabled)
	process_mode = Node.PROCESS_MODE_ALWAYS   # a paused game still counts the idle time and still shows the warning


func _now() -> int:
	return int(_clock.call()) if _clock.is_valid() else Time.get_ticks_msec()


# Real input only: mouse movement, buttons, keys, touch.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch:
		note_input()


func note_input() -> void:
	_last_input_ms = _now()

	if _warning_since_ms >= 0:
		_warning_since_ms = -1
		_show(false, 0.0)


func set_minutes(value: int) -> void:
	minutes = clamp_minutes(value)
	_last_input_ms = _now()


func poll() -> int:
	if not enabled:
		return 0

	var result: Dictionary = state(_now() - _last_input_ms, float(minutes) * 60.0, COUNTDOWN_S)

	if int(result["state"]) == 1:
		_warning_since_ms = _now()
		_show(true, float(result["left"]))
	elif int(result["state"]) == 2:
		_show(false, 0.0)
		timed_out.emit()

	return int(result["state"])


func _process(_delta: float) -> void:
	poll()


func _show(on: bool, left: float) -> void:
	if _layer == null:
		if not on:
			return

		_layer = CanvasLayer.new()
		_layer.layer = 120
		add_child(_layer)
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_CENTER)
		_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 40)
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 12)
		_layer.add_child(_label)

	_layer.visible = on

	if on:
		_label.text = "Still there?\nThe game will close in %d s.\nMove the mouse to stay." % int(ceil(left))
