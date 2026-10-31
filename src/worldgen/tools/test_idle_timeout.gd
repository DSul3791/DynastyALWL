extends SceneTree

# Game idle timeout (idle_timeout.gd; Dave via the moderator, 31 Oct 2026), with a fake clock and fake input: nothing happens before the minutes are up; then a 60 s warning
# counts down; any input cancels it and starts the minutes again; at zero the timed_out signal fires once; real-clock settings: the minutes are clamped to 5..120 and persist in
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
	check(IdleScript.clamp_minutes(2) == 5 and IdleScript.clamp_minutes(500) == 120 and IdleScript.clamp_minutes(45) == 45, "minutes are clamped to 5..120")
	check(IdleScript.next_step(20) == 30 and IdleScript.next_step(120) == 5 and IdleScript.nearest_step(33) == 30, "the settings button steps 5, 10, 20, 30, 45, 60, 90, 120 and wraps")
	check(int(IdleScript.state(19 * 60 * 1000, 1200.0, 60.0)["state"]) == 0, "19 minutes idle: still active")
	var warn: Dictionary = IdleScript.state(1200 * 1000 + 15000, 1200.0, 60.0)
	check(int(warn["state"]) == 1 and absf(float(warn["left"]) - 45.0) < 0.01, "20 minutes and 15 s idle: warning with 45 s left")
	check(int(IdleScript.state(1260 * 1000, 1200.0, 60.0)["state"]) == 2, "after the 60 s: time is up")
	check(IdleScript.allowed(PackedStringArray(["--server=127.0.0.1", "--port=7777", "--name=Dave"]), false), "a normal player launch gets the timeout")
	check(not IdleScript.allowed(PackedStringArray([]), true), "a headless run never does")
	check(not IdleScript.allowed(PackedStringArray(["--no-idle-timeout"]), false), "--no-idle-timeout turns it off")
	check(not IdleScript.allowed(PackedStringArray(["--server=x", "--shots=out"]), false) and not IdleScript.allowed(PackedStringArray(["--gather"]), false) and not IdleScript.allowed(PackedStringArray(["--frames=100"]), false), "any test, shot or rig switch turns it off")
	check(IdleScript.allowed(PackedStringArray(["--idle-minutes=5"]), false) and IdleScript.minutes_for(PackedStringArray(["--idle-minutes=7"]), 20) == 7 and IdleScript.minutes_for(PackedStringArray(["--idle-minutes=1"]), 20) == 5 and IdleScript.minutes_for(PackedStringArray([]), 45) == 45, "--idle-minutes=N overrides the setting, still within 5..120")

	# The node with a fake clock.
	var node = IdleScript.new()
	root.add_child(node)
	node.timed_out.connect(func(): fired[0] += 1)
	node.setup(PackedStringArray(["--idle-minutes=5"]), 20, false, func(): return now_ms[0])
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
	check(back.idle_minutes == 5, "and below 5 as 5")
	settings.reset()
	check(settings.idle_minutes == 20, "reset gives 20")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_idle_display.cfg"))
	print("idle timeout: %d failures" % failures)
	quit(1 if failures > 0 else 0)
