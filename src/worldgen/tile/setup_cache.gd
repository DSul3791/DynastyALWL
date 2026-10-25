extends RefCounted

# Cache of the once-per-run bake setup (world elevation, wet-air field, river network with ponds): about 130 s of the
# 430 s a one-tile bake takes. The file holds exact copies of every script variable of those objects, so a bake from the cache
# is byte-identical to one without it (prove with --no-cache). The key hashes every input and every worldgen source file,
# so any change to a rule, a script, the erosion file or TERRAIN_VERSION means a new key and a full setup.
# Lives in <world>/setup_cache/ (gitignored). Never trust a cache file whose key differs: the key is in the file name and inside.

const MAGIC := "SETUPCACHE1"
const CODE_FOLDERS := ["res://src/worldgen/sketch", "res://src/worldgen/settings", "res://src/worldgen/tile", "res://src/worldgen/tables", "res://src/worldgen/runtime"]
const INPUT_FILES := ["/world.json", "/plan/sketch_rules.json", "/plan/world_sketch.json", "/plan/tile_rules.json", "/plan/tile_plan.json", "/erosion_delta_v2.bin"]


static func key(world_dir: String, elevation_cell_m: float) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(MAGIC)
	parts.append(Engine.get_version_info()["string"])
	parts.append("cell %s" % str(elevation_cell_m))

	for name in INPUT_FILES:
		parts.append("%s %s" % [name, FileAccess.get_sha256(world_dir + name)])

	var files: PackedStringArray = PackedStringArray()

	for folder in CODE_FOLDERS:
		_collect(folder, files)

	files.sort()

	for path in files:
		parts.append("%s %s" % [path, FileAccess.get_sha256(path)])

	return "\n".join(parts).sha256_text()


static func _collect(folder: String, out: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd") or file.ends_with(".json"):
			out.append(folder + "/" + file)

	for sub in DirAccess.get_directories_at(folder):
		_collect(folder + "/" + sub, out)


static func path_for(world_dir: String, cache_key: String) -> String:
	return ProjectSettings.globalize_path(world_dir) + "/setup_cache/setup_" + cache_key.substr(0, 16) + ".bin"


# Every script variable of an object except object references (the caller sets those).
static func _state(object: Object) -> Dictionary:
	var state: Dictionary = {}

	for property in object.get_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue

		var value: Variant = object.get(property["name"])

		if typeof(value) != TYPE_OBJECT:   # untyped variables (settings) report TYPE_NIL, so test the value
			state[property["name"]] = value

	return state


# True when `path` held a cache with this key and the state was put back into the objects; `world_air` and `sketch` (as the setup leaves it) come back in the dictionaries.
static func load_into(path: String, cache_key: String, elevation: Object, river_network: Object, world_air: Dictionary, sketch: Dictionary) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var parsed: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))

	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("key", "") != cache_key:
		return false

	for name in parsed["elevation"]:
		elevation.set(name, parsed["elevation"][name])

	for name in parsed["river_network"]:
		river_network.set(name, parsed["river_network"][name])

	world_air.clear()
	world_air.merge(parsed["world_air"])
	# elevation.build writes into the sketch (the starter mounts get bay_center and bay_radius_m), and tile bakes read it back.
	sketch.clear()
	sketch.merge(parsed["sketch"])
	return true


static func save(path: String, cache_key: String, elevation: Object, river_network: Object, world_air: Dictionary, sketch: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)

	if file == null:
		push_warning("setup cache not written: %s" % temp)
		return

	file.store_buffer(var_to_bytes({"key": cache_key, "elevation": _state(elevation), "river_network": _state(river_network), "world_air": world_air, "sketch": sketch}))
	file.close()
	DirAccess.rename_absolute(temp, path)
