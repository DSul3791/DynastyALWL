extends SceneTree

# Installs a ground pack (src/stream/ground_pack.gd, built by prebuild_ground.gd) into a server store, with the server stopped:
#
#   godot --headless --path . --script res://src/worldgen/tools/install_ground.gd -- --pack=DIR --store=DIR [--server-stopped]
#
# The pack must have been made from the same tiles and terrain version as this game folder. A fresh store folder may be named: the
# server then starts its new world on the prebuilt ground. Player changes in an existing store are kept. Prints "install_ground: DONE".

const PackScript := preload("res://src/stream/ground_pack.gd")


func _init() -> void:
	var pack_dir: String = ""
	var store_dir: String = ""
	var server_stopped: bool = false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="):
			pack_dir = argument.trim_prefix("--pack=")
		elif argument.begins_with("--store="):
			store_dir = argument.trim_prefix("--store=")
		elif argument == "--server-stopped":
			server_stopped = true

	if pack_dir == "" or store_dir == "":
		push_error("install_ground: --pack=DIR and --store=DIR are needed")
		quit(1)
		return

	var started: int = Time.get_ticks_msec()
	var problem: String = PackScript.install(pack_dir, store_dir, PackScript.wanted_version("res://worlds/base_world/tiles"), server_stopped)

	if problem != "":
		push_error("install_ground: " + problem)
		print("install_ground: FAILED: " + problem)
		quit(1)
		return

	print("install_ground: DONE: %s now holds the pack's ground (generation %d) in %.0f s" % [store_dir, PackScript.generation_of(store_dir), float(Time.get_ticks_msec() - started) / 1000.0])
	quit(0)
