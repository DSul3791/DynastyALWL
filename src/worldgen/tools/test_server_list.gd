extends SceneTree

# The saved server list behind the server pick page (server_list.gd; docs/design/SERVER_PICK_PAGE.md): addresses as typed or pasted, one row per
# server whatever its spelling, names kept as names, remove/rename, last played first, the older join page's address carried over, and a lookup of
# an IP that needs no network. Works in a temp folder, never the player's own list.
#   godot --headless --path . --script res://src/worldgen/tools/test_server_list.gd

const ServerList := preload("res://src/client/server_list.gd")
const JoinAddress := preload("res://src/client/join_address.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var typed: Dictionary = ServerList.normalise("  HannibalsHouse.DuckDNS.org ")
	check(typed.get("address") == "hannibalshouse.duckdns.org" and int(typed.get("port", 0)) == 24600, "a name is kept as a name, lower case, standard port hidden")
	check(ServerList.normalise("https://hannibalshouse.duckdns.org/").get("key") == typed["key"], "http(s):// and a trailing / pasted from a browser are dropped")
	check(ServerList.normalise("hannibalshouse.duckdns.org:24600").get("key") == typed["key"], ":24600 written out is the same server")
	check(ServerList.normalise("203.0.113.5:24610").get("address") == "203.0.113.5:24610", "another port is kept")

	for bad in ["", "my server", "host:0", "a:b:c"]:
		check(ServerList.normalise(bad).has("error"), "\"%s\" is refused with a reason" % bad)

	var rows: Array = []
	var added: Dictionary = ServerList.add(rows, "hannibalshouse.duckdns.org", "Hannibal's House")
	check(added.get("index") == 0 and rows.size() == 1, "a new server is added")
	added = ServerList.add(rows, "HANNIBALSHOUSE.duckdns.org:24600")
	check(added.get("index") == 0 and rows.size() == 1 and rows[0]["name"] == "Hannibal's House", "the same server typed again is the same row, its name kept")
	check(ServerList.add(rows, "bad address here").has("error") and rows.size() == 1, "a bad address adds nothing")
	ServerList.add(rows, "203.0.113.5:24610")
	check(ServerList.shown_name(rows[1]) == "203.0.113.5:24610", "with no name the address is shown")
	rows[1]["server_name"] = "Sam's world"
	check(ServerList.shown_name(rows[1]) == "Sam's world", "the server's own name is shown when the player gave none")
	ServerList.rename(rows, "203.0.113.5:24610", " Sam ")
	check(ServerList.shown_name(rows[1]) == "Sam", "rename sets the name shown, trimmed")
	rows[0]["added"] = 100
	rows[1]["added"] = 200
	check(ServerList.sorted(rows)[0]["address"] == "203.0.113.5:24610", "never played: newest added first")
	ServerList.mark_played(rows, "hannibalshouse.duckdns.org", "char_7")
	var order: Array = ServerList.sorted(rows)
	check(order[0]["address"] == "hannibalshouse.duckdns.org" and order[0]["last_character"] == "char_7", "last played comes first and remembers its character")

	var temp_dir: String = OS.get_cache_dir().path_join("dynasty_test_servers_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(temp_dir)
	ServerList.saved_path = temp_dir.path_join("servers.json")
	JoinAddress.saved_path = temp_dir.path_join("join_address.cfg")
	check(ServerList.load_rows().is_empty(), "no list and no older address: empty")
	JoinAddress.save("198.51.100.7:24610")
	var carried: Array = ServerList.load_rows()
	check(carried.size() == 1 and carried[0]["address"] == "198.51.100.7:24610", "the older join page's address becomes the first row")
	check(ServerList.save_rows(rows), "the list saves")
	var back: Array = ServerList.load_rows()
	check(back.size() == 2 and ServerList.find(back, "https://HannibalsHouse.duckdns.org") >= 0, "the saved list reads back, found by any spelling")
	ServerList.remove(back, "203.0.113.5:24610")
	check(back.size() == 1 and ServerList.find(back, "203.0.113.5:24610") < 0, "remove takes the row off")

	var lookup: int = ServerList.lookup_start("203.0.113.5")
	check(lookup == -1 and ServerList.lookup_result("203.0.113.5", lookup).get("ip") == "203.0.113.5", "an IP needs no lookup")

	for file in ["servers.json", "join_address.cfg"]:
		DirAccess.remove_absolute(temp_dir.path_join(file))

	DirAccess.remove_absolute(temp_dir)
	print("server list: %d failures" % failures)
	quit(1 if failures > 0 else 0)
