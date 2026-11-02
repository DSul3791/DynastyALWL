extends SceneTree

# Bakes one tile in memory (nothing is saved to the world) and writes its ground and water maps for offline viewing. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/river_snapshot.gd -- --tile=3,4 --out=C:/some/folder
#
# Options: --tile=X,Z (default 3,4); --out=DIR (default user://river_snapshot); --routing-noise=M overrides water.drainage.routing_noise_m for this run;
# --world=DIR. Writes snapshot.json (samples, spacing) plus heights.f32 (m), water_class.u8 (0 dry, 1 ocean, 2 lake, 3 river) and flow.f32.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var out_dir: String = "user://river_snapshot"
	var world_dir: String = "res://worlds/base_world"
	var noise: float = -1.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--routing-noise="):
			noise = float(argument.trim_prefix("--routing-noise="))

	quit(_run(world_dir, tile, out_dir, noise))


func _run(world_dir: String, tile: Vector2i, out_dir: String, noise: float) -> int:
	var baker = TileBakerScript.new()
	var problem: String = baker.setup(world_dir, 0.0)

	if problem != "":
		push_error(problem)
		return 1

	if noise >= 0.0:
		baker.tile_rules["water"]["drainage"]["routing_noise_m"] = noise

	var result: Dictionary = baker.bake(tile)
	var water = result["water"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_write("%s/heights.f32" % out_dir, water.heights.to_byte_array())
	_write("%s/water_class.u8" % out_dir, water.water_class)
	_write("%s/flow.f32" % out_dir, water.flow.to_byte_array())
	var file := FileAccess.open("%s/snapshot.json" % out_dir, FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": int(water.samples), "spacing_m": float(water.spacing_m), "tile": [tile.x, tile.y], "routing_noise_m": noise}))
	file.close()
	print("snapshot written: %d samples" % int(water.samples))
	return 0


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
