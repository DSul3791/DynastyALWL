extends SceneTree

# BugsList 108 (D-TODO-1): FrameProbe.first_shown names each mesh or look once a session, keeps it for the next few frames' FREEZE and HITCH lines,
# then lets it go, and caps how many it holds. D-LAG-1: the print queue prints every line on a worker and drain() waits for them all.
#   godot --headless --path . --script res://src/worldgen/tools/test_first_shown.gd

const Probe := preload("res://src/debug/frame_probe.gd")
const PrintQueueScript := preload("res://src/shared/print_queue.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	Probe.frame(0.016)
	check(Probe.is_new("m1"), "a mesh not shown yet is new")
	Probe.first_shown("flora oak tier 1", "m1")
	check(not Probe.is_new("m1") and Probe._shown_text() == "; first shown: flora oak tier 1", "named once, then no longer new (%s)" % Probe._shown_text())
	Probe.frame(0.016)
	Probe.frame(0.016)
	check(Probe._shown_text().contains("flora oak tier 1"), "still named two frames later, for a drawing drawn a frame or two after it was made")
	Probe.frame(0.016)
	check(Probe._shown_text() == "", "gone after %d frames (%s)" % [Probe.SHOWN_FRAMES, Probe._shown_text()])
	check(not Probe.is_new("m1"), "a mesh already shown this session stays seen, so its callers do not name it again")

	for k in Probe.SHOWN_MAX + 5:
		Probe.first_shown("item %d" % k, "i%d" % k)

	check(Probe._shown.size() == Probe.SHOWN_MAX and Probe._shown_text().ends_with(" and %d more" % (Probe.SHOWN_MAX + 5 - Probe.SHOWN_PRINT)), "capped at %d held, %d printed, the rest counted (%s)" % [Probe.SHOWN_MAX, Probe.SHOWN_PRINT, Probe._shown_text()])

	for k in Probe.SHOWN_FRAMES + 1:
		Probe.frame(0.016)

	check(Probe._shown.is_empty() and Probe._shown_dropped == 0, "the window empties and the dropped count starts again")

	Probe._this_frame = {"flora": 3000, "items": 9000, "sky": 1000}
	check(Probe._top_text(2) == "items 9, flora 3", "the PHYSICS and HITCH lines name the biggest timed pieces first (%s)" % Probe._top_text(2))
	Probe._this_frame = {}
	check(Probe._top_text(5) == "", "nothing timed gives an empty list, each line says so in its own words")

	var queue = PrintQueueScript.new()

	for k in 50:
		queue.line("print queue test line %d" % k)

	queue.drain()
	check(queue._queue.is_empty() and not queue._busy and queue._task == -1, "drain() waits until every queued line is printed")
	queue.line("print queue test line after a drain")   # a new task after a drain, never a wait on the drained one
	queue.drain()
	check(queue._queue.is_empty() and not queue._busy, "a line after a drain is printed too")
	quit(1 if failures > 0 else 0)
