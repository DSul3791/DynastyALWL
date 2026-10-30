extends Node

const RUN_NOTE := "user://server_run.json"


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
			# The character creator is the first page (until there are accounts); its "Save and play" button comes back here with creator_done set.
			if not Engine.has_meta("creator_done"):
				get_tree().change_scene_to_file("res://scenes/creator_proto/creator_proto.tscn")
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
	])
	var pid: int = OS.create_process(OS.get_executable_path(), arguments)

	if pid < 0:
		push_error("Play: cannot start the terrain server")
		get_tree().quit(1)
		return

	print("Play: started the terrain server (process %d), joining it" % pid)
	get_tree().change_scene_to_file("res://scenes/terrain_client/terrain_client.tscn")


# The port is held. Read the note the old server left (server_run.json): one that is closing is waited for (it stops answering
# blocks while it saves). Nothing is killed: a server from another checkout is named by the join screen (the welcome carries
# its build id) and the player closes the game and presses Play again.
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


# True when something already holds this UDP port (the server's ENet host binds it).
func _port_is_taken(port: int) -> bool:
	var probe: PacketPeerUDP = PacketPeerUDP.new()
	var error: int = probe.bind(port, "*")

	if error == OK:
		probe.close()

	return error != OK
