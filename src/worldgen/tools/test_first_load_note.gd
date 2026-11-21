extends SceneTree

# BugsList 93 (Dave 21 Nov 2026: the first-load pause is expected; "we should have a message that is clear that tells people that"): the join
# window shows the first-load note until a join on this engine, driver, graphics card and build has reached the ground, and again after an update.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_first_load_note.gd

const ConnectWindowScript := preload("res://src/client/connect_window.gd")

var failures: int = 0


func check(ok: bool, text: String) -> void:
	if not ok:
		print("FAIL " + text)
		failures += 1


func _init() -> void:
	ConnectWindowScript.first_load_mark = "user://test_first_load_note_%d.txt" % OS.get_process_id()   # never the game's own mark
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ConnectWindowScript.first_load_mark))

	var window = ConnectWindowScript.new()
	window.setup(root)
	window.show_first_load_note(900)
	check(window._note.visible and window.first_load_note_shown(), "the note shows on a first start (and the client keeps the window until landing)")
	check("half a minute" in window._note.text and "Not responding" in window._note.text and "not stuck" in window._note.text, "the note says how long, what it looks like, and to wait")

	ConnectWindowScript.mark_first_load_done(900)
	window.show_first_load_note(900)
	check(not window._note.visible and not window.first_load_note_shown(), "no note once a join on this build reached the ground")

	window.show_first_load_note(901)
	check(window._note.visible, "the note shows again after an update (another build)")

	window.fail("The server is not answering this game", "text", func() -> void: pass)
	check(not window._note.visible, "a failure hides the note")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ConnectWindowScript.first_load_mark))
	window.close()
	print("test_first_load_note: %d failures" % failures)
	quit(failures)
