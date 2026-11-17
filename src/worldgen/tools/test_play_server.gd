extends SceneTree

# Play gets onto the code on disk (Dave 17 Nov 2026: he pulled dev, pressed Play, and joined the server from before the pull, so Edda and
# Hob's camp and fire were not there). Play asks a server it started, running other code, to close; only the process the request names
# obeys; the server names the commit it started on, not the checkout now on disk (it read the disk at every join, so the old server
# said it was the new commit and the join screen's out-of-date check passed).
#   godot --headless --path . --script res://src/worldgen/tools/test_play_server.gd

const PlayServer := preload("res://src/shared/play_server.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var note: Dictionary = {"pid": 23544, "port": 24600, "commit": "3f1e6be", "state": "running", "stop": 1}
	check(PlayServer.should_ask_stop(note, 24600, "290a40f", true), "a Play server of other code on Play's port is asked to close")
	check(not PlayServer.should_ask_stop(note, 24600, "3f1e6be", true), "one of the same code is joined")
	check(not PlayServer.should_ask_stop(note, 24601, "290a40f", true), "one on another port is left alone")
	check(not PlayServer.should_ask_stop(note, 24600, "290a40f", false), "a note whose process is gone asks nothing")
	check(not PlayServer.should_ask_stop(note.merged({"stop": 0}, true), 24600, "290a40f", true), "a server Play did not start is left alone")
	check(not PlayServer.should_ask_stop(note.merged({"state": "closing"}, true), 24600, "290a40f", true), "a server already closing is waited for, not asked")
	check(not PlayServer.should_ask_stop(note.merged({"commit": ""}, true), 24600, "290a40f", true), "no commit on the server side (an export) asks nothing")
	check(not PlayServer.should_ask_stop(note, 24600, "", true), "no commit on Play's side asks nothing")
	check(not PlayServer.should_ask_stop({}, 24600, "290a40f", true), "no note asks nothing")
	check(PlayServer.stop_is_for({"pid": 23544, "commit": "290a40f"}, 23544), "the server named by the request obeys")
	check(not PlayServer.stop_is_for({"pid": 23544}, 14376), "any other process ignores it")
	check(not PlayServer.stop_is_for({"pid": 0}, 0) and not PlayServer.stop_is_for(null, 23544) and not PlayServer.stop_is_for([], 23544), "an empty or broken request is ignored")

	# Source checks: the server reads its commit once at start and uses that everywhere; the launcher really asks; the server really obeys.
	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	var launcher: String = FileAccess.get_file_as_string("res://scenes/launcher.gd")
	check(server.count("GitStamp.short_commit()") == 1 and server.contains("var _commit: String = GitStamp.short_commit()"), "the server reads its commit once, at start")
	check(server.contains("\"server_commit\": _commit"), "the welcome names that commit")
	check(server.contains("PlayServerScript.stop_is_for(asked, OS.get_process_id())") and server.contains("_stop_if_asked(now)"), "the server checks for a request naming itself")
	check(server.contains("\"stop\": 1 if _quit_when_empty else 0"), "only a server Play started (--quit-when-empty) says it obeys")
	check(launcher.contains("await _replace_other_build(port)") and launcher.contains("PlayServer.should_ask_stop("), "Play asks before joining a busy port")
	check(not launcher.contains("OS.kill(") and not server.contains("OS.kill("), "nothing is killed")
	print("test_play_server: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
