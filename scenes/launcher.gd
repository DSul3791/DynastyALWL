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

		"builder":
			get_tree().change_scene_to_file(
				"res://scenes/builder/world_builder.tscn"
			)

		_:
			push_error("Unknown launcher role: " + role)
