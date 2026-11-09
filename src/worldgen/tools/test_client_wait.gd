extends SceneTree

# The client waits up to 120 s for its server when the launcher plays (role "play") and on a plain editor run (no role, which
# launcher.gd defaults to play): Dave's F6 test play on 9 Nov 2026 failed with "connection failed" while the server was still
# starting. Joining a server by address ("terrain_client") does not wait.
#   godot --headless --path . --script res://src/worldgen/tools/test_client_wait.gd

const Client := preload("res://scenes/terrain_client/terrain_client.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	check(Client.waits_for_server("play"), "the play launcher waits for its server")
	check(Client.waits_for_server(""), "a plain editor run (no role) waits too")
	check(not Client.waits_for_server("terrain_client"), "joining a server by address does not")
	print("test_client_wait: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
