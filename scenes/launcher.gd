extends Node

const GitStamp := preload("res://src/debug/git_stamp.gd")
const PlayServer := preload("res://src/shared/play_server.gd")
const RUN_NOTE := "user://server_run.json"
const STOP_NOTE := "user://server_stop.json"   # asks the server Play started to close (terrain_server._stop_if_asked)
const STOP_WAIT_MSEC := 60000                   # how long Play waits for that server to save and let go of the port


func _ready() -> void:
	var role := AppConfig.get_command_line_value("role", "play")

	print("Launcher role: ", role)

	call_deferred("_launch_role", role)


func _launch_role(role: String) -> void:
	match role:
		"terrain":
			get_tree().change_scene_to_file(
				"res://scenes/terrain_preview/terrain_preview.tscn"
			)

		"terrain_server":
			get_tree().change_scene_to_file(
				"res://scenes/terrain_server/terrain_server.tscn"
			)

		"play":
			# The title page (scenes/title, Dave's paintings) opens first, once per launch: New Game goes to the creator, Continue to the character select page.
			# After that (back here after a death) the character select page is the first page; it sends a player with no characters to the creator, and
			# both come back here with creator_done set once a character is chosen.
			# `--test` goes straight to play (no character pages): test builds, rigs and the PC test runs are not held up by the select screen. The game then
			# uses the machine key and no character, as headless runs do.
			if not Engine.has_meta("creator_done") and not AppConfig.has_flag("test"):
				if not Engine.has_meta("title_done"):
					get_tree().change_scene_to_file("res://scenes/title/title.tscn")
				else:
					get_tree().change_scene_to_file("res://scenes/character_select/character_select.tscn")
			else:
				_host_and_play()

		"terrain_client":
			get_tree().change_scene_to_file(
				"res://scenes/terrain_client/terrain_client.tscn"
			)

		_:
			push_error("Unknown launcher role: " + role)


# "play": starts a terrain server for this world in the background (no
# window; it stops when this game closes) and joins it.
func _host_and_play() -> void:
	var port: int = int(AppConfig.get_command_line_value("port", "24600"))

	if _port_is_taken(port):
		await _clear_old_server(port)

	if _port_is_taken(port):
		await _replace_other_build(port)

	if _port_is_taken(port):
		# A second server on the same UDP port would die at once and leave the player talking to the old one (maybe an older build).
		push_warning("Play: UDP port %d is already in use, probably a server from an earlier run; not starting another" % port)
		print("Play: port %d is busy, joining the server already there (the connect window names it if it is out of date)" % port)
		get_tree().change_scene_to_file("res://scenes/terrain_client/terrain_client.tscn")
		return

	var arguments: PackedStringArray = PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"res://scenes/terrain_server/terrain_server.tscn",
		"--",
		"--quit-when-empty",
		# The server shares this PC with the game: half the cores (it used all but one, 11 threads on 12 cores, and the game froze for seconds);
		# half of the CPUs this process may use when a container limits them (cpu_budget.gd; the same as before on a PC).
		"--threads=%d" % maxi(load("res://src/shared/cpu_budget.gd").usable() >> 1, 2),
	])

	var pid: int = OS.create_process(OS.get_executable_path(), arguments)

	if pid < 0:
		push_error("Play: cannot start the terrain server")
		get_tree().quit(1)
		return

	print("Play: started the terrain server (process %d), joining it" % pid)
	get_tree().change_scene_to_file("res://scenes/terrain_client/terrain_client.tscn")


# The port is held. Read the note the old server left (server_run.json): one that is closing is waited for (it stops answering
# blocks while it saves). Nothing is killed; a running server of other code is asked to close by _replace_other_build.
func _clear_old_server(port: int) -> void:
	var note: Dictionary = {}

	if FileAccess.file_exists(RUN_NOTE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RUN_NOTE))

		if parsed is Dictionary:
			note = parsed

	if note.is_empty() or int(note.get("port", 0)) != port or str(note.get("state", "")) != "closing":
		return

	var waited: int = 0

	while _port_is_taken(port) and waited < 30000:
		await get_tree().create_timer(0.5).timeout
		waited += 500

	print("Play: old server on port %d %s after %d ms" % [port, "gone" if not _port_is_taken(port) else "still there", waited])


# The port is held by a server Play started earlier from other code (Dave 17 Nov 2026: he pulled dev, pressed Play and joined the
# server from before the pull, so the camp was not there). Play asks that server to close (STOP_NOTE names its process; only that
# process obeys, and only a server Play started, "stop": 1 in its note), waits for it to save and let go of the port, then starts
# one on this code. Nothing is killed: a server that does not close is joined and the join screen says it is out of date.
func _replace_other_build(port: int) -> void:
	var note: Dictionary = _read_note(RUN_NOTE)
	var mine: String = GitStamp.short_commit()
	var theirs: String = str(note.get("commit", ""))

	if not PlayServer.should_ask_stop(note, port, mine, OS.is_process_running(int(note.get("pid", 0)))):
		return

	var file: FileAccess = FileAccess.open(STOP_NOTE, FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify({"pid": int(note["pid"]), "commit": mine}))
	file.close()
	print("Play: the server on port %d (process %d) runs commit %s, this game is %s; asking it to save and close" % [port, int(note["pid"]), theirs, mine])
	var waited: int = 0

	while _port_is_taken(port) and waited < STOP_WAIT_MSEC:
		if not FileAccess.file_exists(STOP_NOTE) and str(_read_note(RUN_NOTE).get("state", "")) == "running":
			break   # taken and refused (players are on it): join it, the join screen says it is out of date

		await get_tree().create_timer(0.5).timeout
		waited += 500

	DirAccess.remove_absolute(STOP_NOTE)   # a request left behind must never close a later server that gets the same process number
	print("Play: old server on port %d %s after %d ms" % [port, "closed" if not _port_is_taken(port) else "still there", waited])


func _read_note(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return parsed if parsed is Dictionary else {}


# True when something already holds this UDP port (the server's ENet host binds it).
func _port_is_taken(port: int) -> bool:
	var probe: PacketPeerUDP = PacketPeerUDP.new()
	var error: int = probe.bind(port, "*")

	if error == OK:
		probe.close()

	return error != OK
