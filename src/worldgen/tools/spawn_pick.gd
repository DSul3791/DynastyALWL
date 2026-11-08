extends SceneTree

# Where the spawn picker (Stage E M1 step 4, docs/water/stage_e_readers_design.md 6e; tile/spawn_picker.gd) would put the spawn on the baked
# starter tile, before the picker is switched on at R6. Reads the tile's height, water class, water surface and flow; the bay head is the
# tile's own beach spawn_point (beside the starter river mouth). Prints the pick, how many spots passed and how far it is from today's
# OVERRIDE. Read-only; run on the PC (headless), not in the cloud.
#   godot --headless --path . --script res://src/worldgen/tools/spawn_pick.gd -- [--world=res://worlds/base_world]

const PickerScript := preload("res://src/worldgen/tile/spawn_picker.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")

	var path: String = world + "/tiles/" + SpawnPointScript.STARTER_TILE
	var head: Dictionary = TileFileScript.read_header(path) if FileAccess.file_exists(path) else {"ok": false}

	if not head["ok"]:
		print("spawn_pick: no starter tile at ", path)
		quit(1)
		return

	var table: Array = head["table"]
	var header: Dictionary = head["header"]
	var heights: PackedFloat32Array = TileFileScript.decode_height(TileFileScript.read_section(path, table, "height")["raw"], TileFileScript.height_step_of(header))
	var water: PackedByteArray = TileFileScript.read_section(path, table, "water_class")["raw"]
	var surface: PackedFloat32Array = TileFileScript.decode_water_surface(TileFileScript.read_section(path, table, "water_surface")["raw"], TileFileScript.height_step_of(header))
	var flow: PackedFloat32Array = TileFileScript.decode_flow(TileFileScript.read_section(path, table, "flow")["raw"])
	var n: int = int(header["samples"])
	var spacing: float = float(header["map_spacing_m"])
	var starter: Dictionary = TileFileScript.read_list(path, table, "starter").get("value", {})
	var tile_m: float = spacing * float(n - 1)
	var parts: PackedStringArray = SpawnPointScript.STARTER_TILE.trim_prefix("tile_").trim_suffix(".tile").split("_")
	var origin: Vector2 = Vector2(float(parts[0]), float(parts[1])) * tile_m
	var target: Vector2 = SpawnPointScript.OVERRIDE

	if starter.has("spawn_point"):
		target = Vector2(float(starter["spawn_point"][0]), float(starter["spawn_point"][2]))

	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(world + "/plan/tile_rules.json"))
	var picker_rules: Dictionary = (rules as Dictionary).get("sites", {}).get("starter", {}).get("spawn_picker", {}) if typeof(rules) == TYPE_DICTIONARY else {}
	var started: int = Time.get_ticks_msec()
	var r: Dictionary = PickerScript.pick({"heights": heights, "water": water, "surface": surface, "flow": flow, "n": n, "spacing": spacing, "origin": origin}, target, picker_rules)
	var ms: int = Time.get_ticks_msec() - started

	if not bool(r["ok"]):
		print("spawn_pick: nothing passes near x %d z %d (%d ms)" % [int(target.x), int(target.y), ms])
		quit(1)
		return

	var at: Vector2 = Vector2(float(r["x"]), float(r["z"]))
	print("spawn_pick: x %d z %d ground %.1f m; %d spots passed; %.0f m from the bay head, %.0f m from OVERRIDE x %d z %d (%d ms)" % [int(at.x), int(at.y),
		float(r["ground"]), int(r["candidates"]), at.distance_to(target), at.distance_to(SpawnPointScript.OVERRIDE), int(SpawnPointScript.OVERRIDE.x),
		int(SpawnPointScript.OVERRIDE.y), ms])
	quit(0)
