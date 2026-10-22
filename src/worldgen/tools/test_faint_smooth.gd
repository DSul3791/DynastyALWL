extends SceneTree

# The faint and sleep picture is smooth (Mandy, Dave 2026-10-21): no frame changes the black by a step, the vignette stays slight, a faint
# reaches full black, sleep takes about four seconds in and out. And the heart in the ears follows the server's rate without steps.
#   godot --headless --path . --script res://src/worldgen/tools/test_faint_smooth.gd

const FaintScript := preload("res://src/client/faint_effect.gd")
const BreathScript := preload("res://src/client/breath_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	get_root().add_child(layer)
	var faint: Node = FaintScript.new()
	get_root().add_child(faint)
	faint.setup(layer)

	# A faint: the server's progress climbs in 1/200 steps over 5 s (60 frames a second, a step every 1.5 frames or so).
	var worst: float = 0.0
	var worst_tunnel: float = 0.0
	var before: float = 0.0

	for frame in range(300):
		var p: float = floorf(float(frame) / 300.0 * 200.0) / 200.0
		faint.set_state("fainting", 1.4, p)
		faint._process_body(1.0 / 60.0)
		worst = maxf(worst, absf(faint.blackout - before))
		worst_tunnel = maxf(worst_tunnel, faint.tunnel)
		before = faint.blackout

	check(worst < 0.02, "faint: the black never jumps (largest frame step %.4f)" % worst)
	check(worst_tunnel <= 0.31, "faint: only a slight vignette (%.2f)" % worst_tunnel)

	for frame in range(120):
		faint.set_state("fainted", 1.4, 1.0)
		faint._process_body(1.0 / 60.0)

	check(faint.blackout > 0.97, "fainted: black (%.2f)" % faint.blackout)

	# Waking from a faint: the same smooth way back.
	worst = 0.0
	before = faint.blackout

	for frame in range(300):
		faint.set_state("waking", 1.0, 1.0 - float(frame) / 300.0)
		faint._process_body(1.0 / 60.0)
		worst = maxf(worst, absf(faint.blackout - before))
		before = faint.blackout

	check(worst < 0.02, "waking: the black never jumps (%.4f)" % worst)
	check(faint.blackout < 0.05, "waking: clear again (%.3f)" % faint.blackout)

	# Sleep: lying down takes about four seconds to black; waking about four to clear.
	for frame in range(60):
		faint.set_state("sleeping", 0.0, 1.0)
		faint._process_body(1.0 / 60.0)

	check(faint.blackout < 0.7, "sleep: not black after one second (%.2f)" % faint.blackout)

	for frame in range(300):
		faint.set_state("sleeping", 0.0, 1.0)
		faint._process_body(1.0 / 60.0)

	check(faint.blackout > 0.95, "sleep: black after six seconds (%.2f)" % faint.blackout)

	for frame in range(60):
		faint.set_state("normal", 0.0, 0.0)
		faint._process_body(1.0 / 60.0)

	check(faint.blackout > 0.2, "waking from sleep: still dark after one second (%.2f)" % faint.blackout)

	for frame in range(480):
		faint.set_state("normal", 0.0, 0.0)
		faint._process_body(1.0 / 60.0)

	check(faint.blackout == 0.0 and faint.tunnel == 0.0, "waking from sleep: everything back as it was")
	check(not faint._rect.visible, "the overlay is hidden again (nothing drawn)")

	# The heart: the server's rate, eased, and slower than 60 allowed.
	var breath: Node = BreathScript.new()
	get_root().add_child(breath)
	breath.setup(null)
	await process_frame
	breath.set_server_heart(172.0, 2)
	breath.set_body(0.0, "fainted", 1.0)

	for i in range(120):
		breath.update(1.0 / 60.0, false)

	check(absf(breath.bpm_now - 172.0) < 3.0, "faint: the heart is at the server's 172 (%.0f)" % breath.bpm_now)
	var step: float = 0.0
	var last: float = breath.bpm_now
	breath.set_server_heart(140.0, 3)

	for i in range(180):
		breath.update(1.0 / 60.0, false)
		step = maxf(step, absf(breath.bpm_now - last))
		last = breath.bpm_now

	check(absf(breath.bpm_now - 140.0) < 3.0, "waking: the heart drops to 140 (%.0f)" % breath.bpm_now)
	check(step < 1.5, "the heart rate never steps (%.2f per frame)" % step)
	breath.set_server_heart(44.0, 2)
	breath.set_body(0.0, "sleeping", 1.0)

	for i in range(300):
		breath.update(1.0 / 60.0, false)

	check(absf(breath.bpm_now - 44.0) < 3.0, "asleep: a slow heart at the server's rate (%.0f)" % breath.bpm_now)
	print("test_faint_smooth: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
