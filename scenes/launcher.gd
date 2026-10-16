extends Node


func _ready() -> void:
	var role := AppConfig.get_command_line_value("role", "client")

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
