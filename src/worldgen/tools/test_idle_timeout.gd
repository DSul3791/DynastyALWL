extends SceneTree

# Game idle timeout (idle_timeout.gd; Dave via the moderator, 31 Oct 2026), with a fake clock and fake input: nothing happens before the minutes are up; then a 60 s warning
# counts down; any input cancels it and starts the minutes again; at zero the timed_out signal fires once; real-clock settings: the minutes are clamped to 60..120 (one hour at least, sleep is no special case) and persist in
# the display settings file; headless runs, --no-idle-timeout and any test, shot or rig switch turn it off; --idle-minutes=N overrides the setting.
#   godot --headless --path . --script res://src/worldgen/tools/test_idle_timeout.gd

const IdleScript := preload("res://src/client/idle_timeout.gd")
const DisplayScript := preload("res://src/client/display_settings.gd")

var failures: int = 0
var now_ms: Array = [0]
var fired: Array = [0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# Rules.
	check(IdleScript.clamp_minutes(2) == 60 and IdleScript.clamp_minutes(500) == 120 and IdleScript.clamp_minutes(45) == 60 and IdleScript.DEFAULT_MINUTES == 60, "minutes are clamped to 60..120, default one hour")
	check(IdleScript.next_step(60) == 90 and IdleScript.next_step(120) == 60 and IdleScript.nearest_step(70) == 60, "the settings button steps 60, 90, 120 and wraps")
	check(int(IdleScript.state(19 * 60 * 1000, 1200.0, 60.0)["state"]) == 0, "19 minutes idle: still active")
	var warn: Dictionary = IdleScript.state(1200 * 1000 + 15000, 1200.0, 60.0)
	check(int(warn["state"]) == 1 and absf(float(warn["left"]) - 45.0) < 0.01, "20 minutes and 15 s idle: warning with 45 s left")
	check(int(IdleScript.state(1260 * 1000, 1200.0, 60.0)["state"]) == 2, "after the 60 s: time is up")
	check(IdleScript.allowed(PackedStringArray(["--server=127.0.0.1", "--port=7777", "--name=Dave"]), false), "a normal player launch gets the timeout")
	check(not IdleScript.allowed(PackedStringArray([]), true), "a headless run never does")
	check(not IdleScript.allowed(PackedStringArray(["--no-idle-timeout"]), false), "--no-idle-timeout turns it off")
	check(not IdleScript.allowed(PackedStringArray(["--server=x", "--shots=out"]), false) and not IdleScript.allowed(PackedStringArray(["--gather"]), false) and not IdleScript.allowed(PackedStringArray(["--frames=100"]), false), "any test, shot or rig switch turns it off")
	check(IdleScript.allowed(PackedStringArray(["--idle-minutes=5"]), false) and IdleScript.minutes_for(PackedStringArray(["--idle-minutes=7"]), 60) == 7 and IdleScript.minutes_for(PackedStringArray(["--idle-minutes=0"]), 60) == 1 and IdleScript.minutes_for(PackedStringArray([]), 45) == 60 and IdleScript.minutes_for(PackedStringArray([]), 90) == 90, "--idle-minutes=N overrides the setting (test aid, 1..120); the saved setting is never under an hour")

	# The node with a fake clock.
	var node = IdleScript.new()
	root.add_child(node)
	node.timed_out.connect(func(): fired[0] += 1)
	node.setup(PackedStringArray(["--idle-minutes=5"]), 60, false, func(): return now_ms[0])
	check(node.enabled and node.minutes == 5, "the node is enabled with 5 minutes")
	now_ms[0] = 4 * 60 * 1000
	check(node.poll() == 0, "4 minutes: active")
	now_ms[0] = 5 * 60 * 1000 + 10000
	check(node.poll() == 1 and fired[0] == 0, "5 minutes and 10 s: warning shown, not closed")
	node.note_input()
	check(node.poll() == 0, "any input cancels the warning and starts the minutes again")
	now_ms[0] += 5 * 60 * 1000 + 61000
	check(node.poll() == 2 and fired[0] == 1, "after minutes plus 60 s with no input: timed_out fires")
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	node._input(ev)
	check(node.poll() == 0, "a mouse movement event counts as input")
	node._input(InputEventKey.new())
	node.set_minutes(200)
	check(node.minutes == 120, "set_minutes clamps to 120")
	# One simple rule (Dave 2 Nov 2026): an hour with no key or mouse and the character times out; being asleep changes nothing.
	node.set_minutes(60)
	now_ms[0] += 59 * 60 * 1000
	check(node.poll() == 0, "59 minutes with no input: still in the game")
	now_ms[0] += 2 * 60 * 1000
	check(node.poll() >= 1, "an hour with no input: the warning comes (then the quit)")

	# Settings file.
	var settings = DisplayScript.new()
	settings.path = "user://test_idle_display.cfg"
	settings.idle_minutes = 90
	settings.save()
	var back = DisplayScript.new()
	back.path = "user://test_idle_display.cfg"
	back.load_saved()
	check(back.idle_minutes == 90, "the idle minutes persist in the settings file")
	settings.idle_minutes = 999
	settings.save()
	back.load_saved()
	check(back.idle_minutes == 120, "a saved value above 120 is read back as 120")
	settings.idle_minutes = 1
	settings.save()
	back.load_saved()
	check(back.idle_minutes == 60, "and below 60 as 60 (never less than an hour)")
	settings.reset()
	check(settings.idle_minutes == 60, "reset gives 60")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_idle_display.cfg"))
	print("idle timeout: %d failures" % failures)
	quit(1 if failures > 0 else 0)
