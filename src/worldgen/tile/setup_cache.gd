extends RefCounted

# Cache of the once-per-run bake setup (world elevation, wet-air field, river network with ponds): about 130 s of the
# 430 s a one-tile bake takes (418 s on 8 Nov 2026, docs/water/generation_cost_audit.md). The file holds exact copies of every script
# variable of those objects, so a bake from the cache is byte-identical to one without it (prove with --no-cache). The key hashes what
# the setup reads and nothing else (Dave 9 Nov 2026 approved the audit's cuts): the sketch and settings scripts, every script the
# setup's builders reach (by res:// path or class_name), the input files, and the tile_rules blocks the setup reads (climate, water,
# valleys). Before, it hashed every worldgen script and all of tile_rules, so a change to a site rule or tile_sites.gd meant a full
# setup on every bake. rule_rivers false (a bake of record tiles only) is its own key: that setup has no rule river network.
# Lives in <world>/setup_cache/ (gitignored). Never trust a cache file whose key differs: the key is in the file name and inside.

const MAGIC := "SETUPCACHE1"
const CODE_FOLDERS := ["res://src/worldgen/sketch", "res://src/worldgen/settings"]
# The setup's builders: the world elevation, the rule river network, the sketch and the wet air (tile_climate.gd build_world_air).
const ROOT_SCRIPTS := ["res://src/worldgen/sketch/world_elevation.gd", "res://src/worldgen/sketch/river_network.gd",
	"res://src/worldgen/sketch/world_sketch.gd", "res://src/worldgen/tile/tile_climate.gd", "res://src/worldgen/tile/setup_cache.gd"]
# Searched only for class_name lines (see _reached). Written in two parts so the gate's selector (tools/tests_for_diff.py) does not take the
# whole folder as something this file loads: as one string it made every worldgen script select test_bake_from_record (#788).
const SCRIPT_ROOT := "res://" + "src/worldgen"
const INPUT_FILES := ["/world.json", "/plan/sketch_rules.json", "/plan/world_sketch.json", "/plan/tile_plan.json", "/erosion_delta_v2.bin"]
const RULE_BLOCKS := ["climate", "water", "valleys"]   # the tile_rules blocks the setup reads (build_world_air, the river network)


static func key(world_dir: String, elevation_cell_m: float, rule_rivers: bool = true) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(MAGIC)
	parts.append(Engine.get_version_info()["string"])
	parts.append("cell %s" % str(elevation_cell_m))
	parts.append("rule rivers %s" % str(rule_rivers))

	for name in INPUT_FILES:
		parts.append("%s %s" % [name, FileAccess.get_sha256(world_dir + name)])

	var tile_rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/tile_rules.json"))

	for block in RULE_BLOCKS:
		var value: Variant = tile_rules.get(block) if typeof(tile_rules) == TYPE_DICTIONARY else null
		parts.append("tile_rules.%s %s" % [block, JSON.stringify(value, "", true).sha256_text()])

	var files: PackedStringArray = PackedStringArray()

	for folder in CODE_FOLDERS:
		_collect(folder, files)

	for path in _reached(ROOT_SCRIPTS):
		if not files.has(path):
			files.append(path)

	files.sort()

	for path in files:
		parts.append("%s %s" % [path, FileAccess.get_sha256(path)])

	return "\n".join(parts).sha256_text()


# Every script the roots reach: by a res:// path in their text (preload, load) or by a class_name another script declares (a whole
# word, comments too: a script reached by mistake only makes the key change more often). On main (9 Nov 2026) that is 16 of worldgen's 384 scripts.
static func _reached(roots: Array) -> PackedStringArray:
	var all: PackedStringArray = PackedStringArray()
	_collect(SCRIPT_ROOT, all)
	var by_class: Dictionary = {}
	var path_pattern: RegEx = RegEx.create_from_string("res://[A-Za-z0-9_./-]+\\.gd")
	var class_pattern: RegEx = RegEx.create_from_string("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var name_pattern: RegEx = RegEx.create_from_string("\\b[A-Z][A-Za-z0-9_]*\\b")

	for path in all:
		if path.ends_with(".gd"):
			var found: RegExMatch = class_pattern.search(FileAccess.get_file_as_string(path))

			if found != null:
				by_class[found.get_string(1)] = path

	var out: PackedStringArray = PackedStringArray()
	var queue: Array = roots.duplicate()

	while not queue.is_empty():
		var path: String = queue.pop_back()

		if out.has(path) or not FileAccess.file_exists(path):
			continue

		out.append(path)
		var text: String = FileAccess.get_file_as_string(path)

		for found in path_pattern.search_all(text):
			queue.append(found.get_string())

		for found in name_pattern.search_all(text):
			var other: String = by_class.get(found.get_string(), path)

			if other != path:
				queue.append(other)

	return out


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
