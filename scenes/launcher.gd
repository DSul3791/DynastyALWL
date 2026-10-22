extends Node


func _ready() -> void:
	var role := AppConfig.get_command_line_value("role", "play")

	print("Launcher role: ", role)

	call_deferred("_launch_role", role)


func _launch_role(role: String) -> void:
	match role:
		"server":
			get_tree().change_scene_to_file(
				"res://scenes/server/server_main.tscn"
			)

		"client":
			get_tree().change_scene_to_file(
				"res://scenes/client/client_main.tscn"
			)

		"terrain":
			get_tree().change_scene_to_file(
				"res://scenes/terrain_preview/terrain_preview.tscn"
			)

		"terrain_server":
			get_tree().change_scene_to_file(
				"res://scenes/terrain_server/terrain_server.tscn"
			)

		"play":
			_host_and_play()

		"terrain_client":
			get_tree().change_scene_to_file(
				"res://scenes/terrain_client/terrain_client.tscn"
			)

		"builder":
			get_tree().change_scene_to_file(
				"res://scenes/builder/world_builder.tscn"
			)

		_:
			push_error("Unknown launcher role: " + role)


# "play": starts a terrain server for this world in the background (no
# window; it stops when this game closes) and joins it.
func _host_and_play() -> void:
	var port: int = int(AppConfig.get_command_line_value("port", "24600"))

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


# True when something already holds this UDP port (the server's ENet host binds it).
func _port_is_taken(port: int) -> bool:
	var probe: PacketPeerUDP = PacketPeerUDP.new()
	var error: int = probe.bind(port, "*")

	if error == OK:
		probe.close()

	return error != OK
