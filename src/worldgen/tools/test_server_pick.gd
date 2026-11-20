extends SceneTree

# The server pick page (scenes/server_pick; docs/design/SERVER_PICK_PAGE.md): the official server first and not removable, added servers below,
# a bad address refused in the Add box with nothing saved, Remove with Undo, Rename, and the status column: a server that does not answer stays
# on the list in red, one that answers shows its players and padlock. Join remembers the pick (and does not leave the page here: go_on off).
# Temp files only, never the player's own list; one local status line on ports 7900-7999.
#   godot --headless --path . --script res://src/worldgen/tools/test_server_pick.gd

const ServerList := preload("res://src/client/server_list.gd")
const ServerStatus := preload("res://src/client/server_status.gd")
const JoinAddress := preload("res://src/client/join_address.gd")
const BlockLinkServer := preload("res://src/stream/block_link_server.gd")
const PAGE := "res://scenes/server_pick/server_pick.tscn"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A status that has answered with this info (for the words rules without a server).
func _fake(info: Dictionary):
	var status = ServerStatus.new("127.0.0.1")
	status.state = "online"
	status.info = info
	return status


func _words(info: Dictionary, my_build: int, my_protocol: int) -> Array:
	return ServerStatus.words(_fake(info), my_build, my_protocol)


func _initialize() -> void:
	var dir: String = OS.get_cache_dir().path_join("dynasty_test_pick_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	ServerList.saved_path = dir.path_join("servers.json")
	JoinAddress.saved_path = dir.path_join("join_address.cfg")
	var port: int = 7900 + randi() % 90
	var link = BlockLinkServer.new()
	link.is_peer = func(_peer: int) -> bool: return false
	link.on_request = func(_peer: int, _keys: PackedInt32Array, _urgent: int) -> void: pass
	check(link.start(port + 1) == port + 1, "a local status line listens")
	link.set_status({"name": "Hannibal's House", "players": 2, "max_players": 32, "locked": true, "protocol": load("res://src/stream/terrain_net.gd").PROTOCOL_VERSION})
	ServerList.save_rows([])
	var page = load(PAGE).instantiate()
	page.go_on = false
	root.add_child(page)
	await process_frame
	check(page.rows.is_empty() or page.rows.all(func(row): return bool(row.get("official", false))), "a new player's list holds no servers of their own")
	check(page.add_server("my server here") != "" and ServerList.load_rows().is_empty(), "a bad address is named in the Add box and nothing is saved")
	check(page.add_server("127.0.0.1:%d" % port) == "", "a working server is added")
	check(page.add_server("127.0.0.1:%d" % (port + 50), "Old LAN box") == "", "a server with nothing on it is added, with a name")
	check(ServerList.load_rows().size() == 2 and page.selected == "127.0.0.1:%d" % (port + 50), "both are saved and the new one is chosen")

	var waited_from: int = Time.get_ticks_msec()

	while Time.get_ticks_msec() - waited_from < 6000:   # up to 6 s by the clock (headless frames are fast): the status asks run in the background
		await process_frame

		if page.statuses.values().all(func(status): return status.done()):
			break

	var up = page.statuses.get("127.0.0.1:%d" % port)
	var down = page.statuses.get("127.0.0.1:%d" % (port + 50))
	check(up != null and up.state == "online" and int(up.info.get("players", 0)) == 2 and bool(up.info.get("locked", false)), "the working server answers: 2 players and a padlock")
	check(up != null and ServerStatus.words(up, 0, load("res://src/stream/terrain_net.gd").PROTOCOL_VERSION) == ["Online", "ok"], "it reads Online in normal text")
	check(down != null and down.state == "no_answer" and ServerStatus.words(down, 0, 0)[1] == "down", "the other does not answer: red")
	check(ServerList.find(page.rows, "127.0.0.1:%d" % (port + 50)) >= 0, "a server that does not answer stays on the list")
	check(str(page.rows[ServerList.find(page.rows, "127.0.0.1:%d" % port)].get("server_name", "")) == "Hannibal's House", "the server's own name is kept for its row")
	var proto: int = load("res://src/stream/terrain_net.gd").PROTOCOL_VERSION
	check(_words({"stamped": true, "build": 12, "protocol": proto}, 10, proto)[0].begins_with("Needs update") and _words({"stamped": true, "build": 12}, 10, proto)[1] == "warn", "a newer stamped server: Needs update, amber")
	check(_words({"stamped": true, "build": 8, "protocol": proto}, 10, proto)[0].begins_with("Server is older"), "an older stamped server: its owner must update it")
	check(_words({"stamped": false, "build": 99, "protocol": proto}, 10, proto) == ["Online", "ok"], "an unstamped build number is not compared")
	check(_words({"protocol": proto + 1}, 0, proto)[0].begins_with("Needs update") and _words({"protocol": proto - 1}, 0, proto)[0].begins_with("Server is older"), "another protocol: Needs update or Server is older")
	check(_words({"protocol": proto, "players": 32, "max_players": 32}, 0, proto) == ["Full", "warn"], "a full server reads Full")
	var lost = ServerStatus.new("127.0.0.1")
	lost.state = "not_found"
	check(ServerStatus.words(lost, 0, proto)[1] == "down", "a name that is not found is red")
	page.statuses["127.0.0.1:%d" % port] = _fake({"protocol": proto + 1})
	page.select("127.0.0.1:%d" % port)
	check(not page.join_selected(), "Join refuses a server this game must update for")
	page.statuses["127.0.0.1:%d" % port] = up
	page.select("127.0.0.1:%d" % (port + 50))
	page.rename_selected("Basement")
	check(ServerList.shown_name(ServerList.load_rows()[ServerList.find(ServerList.load_rows(), "127.0.0.1:%d" % (port + 50))]) == "Basement", "Rename saves the new name")
	page.remove_selected()
	check(ServerList.find(ServerList.load_rows(), "127.0.0.1:%d" % (port + 50)) < 0, "Remove takes it off at once")
	page.undo_remove()
	check(ServerList.find(ServerList.load_rows(), "127.0.0.1:%d" % (port + 50)) >= 0, "Undo puts it back")
	page.select("127.0.0.1:%d" % port)
	check(page.join_selected() and str(Engine.get_meta("server_picked", "")) == "127.0.0.1:%d" % port and JoinAddress.current() == "127.0.0.1:%d" % port, "Join remembers the server for the game")
	check(page.when_text(0) == "Never" and page.when_text(int(Time.get_unix_time_from_system())) == "Today", "Last played words")
	page.free()
	link.stop()

	for file in ["servers.json", "join_address.cfg"]:
		DirAccess.remove_absolute(dir.path_join(file))

	DirAccess.remove_absolute(dir)
	print("server pick: %d failures" % failures)
	quit(1 if failures > 0 else 0)
