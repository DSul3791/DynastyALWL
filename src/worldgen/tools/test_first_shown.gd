extends SceneTree

# BugsList 108 (D-TODO-1): FrameProbe.first_shown names each mesh or look once a session, keeps it for the next few frames' FREEZE and HITCH lines,
# then lets it go, and caps how many it holds.
#   godot --headless --path . --script res://src/worldgen/tools/test_first_shown.gd

const Probe := preload("res://src/debug/frame_probe.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	Probe.frame(0.016)
	Probe.first_shown("flora oak tier 1", "m1")
	Probe.first_shown("flora oak tier 1", "m1")
	check(Probe._shown_text() == "; first shown: flora oak tier 1", "named once (%s)" % Probe._shown_text())
	Probe.frame(0.016)
	Probe.frame(0.016)
	check(Probe._shown_text().contains("flora oak tier 1"), "still named two frames later, for a drawing drawn a frame or two after it was made")
	Probe.frame(0.016)
	check(Probe._shown_text() == "", "gone after %d frames (%s)" % [Probe.SHOWN_FRAMES, Probe._shown_text()])
	Probe.first_shown("flora oak tier 1", "m1")
	check(Probe._shown_text() == "", "a mesh already shown this session is not named again")

	for k in Probe.SHOWN_MAX + 5:
		Probe.first_shown("item %d" % k, "i%d" % k)

	check(Probe._shown.size() == Probe.SHOWN_MAX and Probe._shown_text().ends_with(" and %d more" % (Probe.SHOWN_MAX - Probe.SHOWN_PRINT)), "capped at %d held, %d printed (%s)" % [Probe.SHOWN_MAX, Probe.SHOWN_PRINT, Probe._shown_text()])
	quit(1 if failures > 0 else 0)
