extends SceneTree

# Reads baked tile files and writes their height and water class maps as raw arrays for offline viewing. Read-only. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/export_tile_maps.gd -- --out=C:/some/folder
#
# Options: --world=DIR (default res://worlds/base_world); --tiles=X0,Z0,X1,Z1 (default 2,3,4,5); --out=DIR.
# Per tile writes h_X_Z.f32 (metres, 1921 x 1921), c_X_Z.u8 (0 dry, 1 ocean, 2 lake, 3 river), m_X_Z.u8 (moisture 0..255) and b_X_Z.u8 (biome id);
# biomes.json (id to name) is written once.

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")


func _init() -> void:
	var world_dir: String = "res://worlds/base_world"
	var out_dir: String = "user://tile_maps"
	var rect: Array = [2, 3, 4, 5]

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument.begins_with("--tiles="):
			rect = []

			for part in argument.trim_prefix("--tiles=").split(","):
				rect.append(int(part))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var names: Dictionary = {}
	var tables = load("res://src/worldgen/tables/table_set.gd").new()
	tables.load_directory()

	for entry in tables.get_entries("biomes"):
		names[str(int(entry["id"]))] = str(entry["name"])

	var names_file := FileAccess.open("%s/biomes.json" % out_dir, FileAccess.WRITE)
	names_file.store_string(JSON.stringify(names))
	names_file.close()

	for z in range(int(rect[1]), int(rect[3]) + 1):
		for x in range(int(rect[0]), int(rect[2]) + 1):
			var path: String = "%s/tiles/tile_%d_%d.tile" % [world_dir, x, z]
			var head: Dictionary = TileFileScript.read_header(path)

			if not bool(head.get("ok", false)):
				print("no tile %d,%d" % [x, z])
				continue

			var heights: PackedFloat32Array = TileFileScript.decode_height(TileFileScript.read_section(path, head["table"], "height")["raw"], TileFileScript.height_step_of(head["header"]))
			var classes: PackedByteArray = TileFileScript.read_section(path, head["table"], "water_class")["raw"]
			_write("%s/h_%d_%d.f32" % [out_dir, x, z], heights.to_byte_array())
			_write("%s/c_%d_%d.u8" % [out_dir, x, z], classes)
			_write("%s/m_%d_%d.u8" % [out_dir, x, z], TileFileScript.read_section(path, head["table"], "moisture")["raw"])
			_write("%s/b_%d_%d.u8" % [out_dir, x, z], TileFileScript.read_section(path, head["table"], "biome")["raw"])
			print("exported %d,%d" % [x, z])

	quit()


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
