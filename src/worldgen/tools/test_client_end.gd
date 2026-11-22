extends SceneTree

# The exported Windows game ends its own process at the end of terrain_client's _exit_tree (release check build 9193, 22 Nov 2026: the
# engine's teardown crashed with 0xC0000005 in ntdll.dll about 6 s after the game had closed). Checks the guard and the order: only an
# exported Windows game ends early, and only after the crash report is marked clean, the cache is flushed and the links are closed.
#   godot --headless --path . --script res://src/worldgen/tools/test_client_end.gd

const ClientScript := "res://scenes/terrain_client/terrain_client.gd"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var src: String = FileAccess.get_file_as_string(ClientScript)
	var exit_tree: int = src.find("func _exit_tree() -> void:")
	var end_now: int = src.find("func _end_now() -> void:")
	check(exit_tree >= 0 and end_now > exit_tree, "_exit_tree and _end_now are there")
	var body: String = src.substr(exit_tree, end_now - exit_tree)
	var clean: int = body.find("crash_report.mark_clean()")
	var drain: int = body.rfind("_telemetry.drain()")
	var early: int = body.find("if _ends_at_exit_tree():")
	check(clean >= 0 and drain > clean and early > drain, "the early end comes after the clean mark and the last telemetry drain")
	check(src.contains("return OS.has_feature(\"template\") and OS.get_name() == \"Windows\""), "only an exported Windows game ends early")
	check(not OS.has_feature("template"), "this run (editor binary) keeps the normal quit")
	var tail: String = src.substr(end_now, src.find("\nfunc ", end_now + 10) - end_now)
	var kill: int = tail.find("OS.kill(OS.get_process_id())")
	check(kill > tail.find("cache.flush()") and kill > tail.find("link.close()") and kill > tail.find("multiplayer.multiplayer_peer.close()")
		and tail.find("cache.flush()") > 0, "the cache is flushed and the links closed before the process ends")
	check(src.count("OS.kill(") == 1, "the client kills nothing else")
	print("client end: %d failures" % failures)
	quit(1 if failures > 0 else 0)
