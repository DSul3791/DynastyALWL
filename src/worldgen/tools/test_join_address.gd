extends SceneTree

# Joining a remote server from a client-only build (join_address.gd; server/client split step A2): address parsing and its plain-words refusals,
# and the remembered address (in a temp file, never the player's own note). The server pick page has its own test (test_server_pick.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_join_address.gd

const JoinAddress := preload("res://src/client/join_address.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# _initialize, not _init: in _init the root is not in the tree yet, so the page's _ready (which fills the box) would not run.
func _initialize() -> void:
	var plain: Dictionary = JoinAddress.parse("  play.example.org ")
	check(plain.get("host") == "play.example.org" and int(plain.get("port", 0)) == 24600, "a name alone joins port 24600, spaces trimmed")
	var with_port: Dictionary = JoinAddress.parse("203.0.113.5:25000")
	check(with_port.get("host") == "203.0.113.5" and int(with_port.get("port", 0)) == 25000, "host:port is read")

	for bad in ["", "   ", ":24600", "a:b:c", "my server", "host:abc", "host:0", "host:65535"]:
		check(JoinAddress.parse(bad).has("error"), "\"%s\" is refused with a reason" % bad)

	check(not JoinAddress.client_only(), "a normal run is not client-only (Play keeps its own server)")
	var temp: String = OS.get_cache_dir().path_join("dynasty_test_join_%d.cfg" % OS.get_process_id())
	JoinAddress.saved_path = temp
	DirAccess.remove_absolute(temp)
	check(JoinAddress.current() == "", "nothing saved and no client_config.json: no address")
	JoinAddress.save(" 198.51.100.7:24610 ")
	check(JoinAddress.current() == "198.51.100.7:24610", "the typed address is remembered, trimmed")
	DirAccess.remove_absolute(temp)
	print("join address: %d failures" % failures)
	quit(1 if failures > 0 else 0)
