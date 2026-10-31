extends SceneTree

# Admin tool (Sonny, 31 Oct 2026): fills the sides of the settled rivers. The painted river is several cells wide, but the drainage map follows one line down it, so the settle tool's film
# (a painted river cell that drains at least film.min_km2 and holds some water, raised to 13 cm) reaches only the cells on that line and leaves the rest of the width a dry bed
# ("broken patches", 48 percent of the painted cells wet). This tool works on the SAVED settled water of every tile (no simulation, no tile bake): a dry painted river cell takes the
# water LEVEL of the wet painted river cells within --reach cells (default 3, about the half width), so the surface stays flat across the channel and the water stops where the bank
# rises above it (never deeper than --max-depth, default 1.5 m). Old files are copied to worlds/<world>/water_archive/ first (never overwritten).
# --film (31 Oct 2026, the choice for the committed files): instead of the level-fill, apply the settle tool's own film floor to every painted river cell whatever its catchment and whether
# or not it holds water (min_seen 0, min_km2 --min-km2, default 0): every painted channel holds 13 cm from head to sea, so a headwater reach is a thin sheet, not a dry bed.
#   godot --headless --path . --script res://src/worldgen/tools/refilm_water.gd -- [--tile=3,4] [--film [--min-km2=0] [--depth=0.13]] [--reach=3] [--max-depth=1.5] [--dry-run] [--world=DIR]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")
const WaterStore := preload("res://src/water/water_store.gd")


func _initialize() -> void:
	var world: String = "res://worlds/base_world"
	var only: Vector2i = Vector2i(-99, -99)
	var film: bool = false
	var min_km2: float = 0.0
	var film_depth: float = 0.13
	var reach: int = 3
	var max_depth: float = 1.5
	var dry: bool = false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			only = Vector2i(int(parts[0]), int(parts[1]))
		elif argument == "--film":
			film = true
		elif argument.begins_with("--min-km2="):
			min_km2 = float(argument.trim_prefix("--min-km2="))
		elif argument.begins_with("--depth="):
			film_depth = float(argument.trim_prefix("--depth="))
		elif argument.begins_with("--reach="):
			reach = int(argument.trim_prefix("--reach="))
		elif argument.begins_with("--max-depth="):
			max_depth = float(argument.trim_prefix("--max-depth="))
		elif argument == "--dry-run":
			dry = true

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	for file in DirAccess.get_files_at(world + "/water"):
		if not file.ends_with(".water"):
			continue

		var parts: PackedStringArray = file.get_basename().trim_prefix("tile_").split("_")
		var tile: Vector2i = Vector2i(int(parts[0]), int(parts[1]))

		if only.x != -99 and tile != only:
			continue

		var data = generator.get_tile(tile)

		if data == null or data.placeholder:
			print("tile %s: placeholder, skipped" % str(tile))
			continue

		var path: String = "%s/water/%s" % [world, file]
		var depth: PackedFloat32Array = WaterStore.load_depth(path, data.samples)

		if depth.is_empty():
			print("tile %s: no usable water file" % str(tile))
			continue

		var wet_before: int = 0

		for k in range(depth.size()):
			if data.water_class[k] == 3 and depth[k] >= 0.12:
				wet_before += 1

		var result: Dictionary = {}

		if film:
			result = WaterSettler.film_floor(depth, data.water_class, WaterSettler.flow_of(data, generator), data.spacing_m, {"enabled": true, "depth_m": film_depth, "min_seen_m": 0.0, "min_km2": min_km2})
		else:
			result = _fill_sides(depth, data.heights, data.water_class, data.samples, reach, max_depth)
		var wet_after: int = 0
		var painted: int = 0

		for k in range(depth.size()):
			if data.water_class[k] == 3:
				painted += 1

				if depth[k] >= 0.12:
					wet_after += 1

		print("tile %s: painted river cells %d, with 12 cm or more %d before and %d after; %d cells raised, %.0f m3 added%s" % [str(tile), painted, wet_before, wet_after, int(result["cells"]), float(result["volume_m3"]), " (dry run)" if dry else ""])

		if dry or int(result["cells"]) == 0:
			continue

		var archive: String = world + "/water_archive"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(archive))
		var copy: String = "%s/%s" % [archive, file]

		if not FileAccess.file_exists(copy):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))

		print("  saved %d wet cells to %s" % [WaterStore.save(path, data.samples, depth), path])

	quit(0)


# Every dry painted river cell takes the highest water surface of the wet painted river cells within `reach` cells, when that lies above its ground (and not more than `max_depth`).
static func _fill_sides(depth: PackedFloat32Array, heights: PackedFloat32Array, water_class: PackedByteArray, side: int, reach: int, max_depth: float) -> Dictionary:
	var level: PackedFloat32Array = PackedFloat32Array()
	level.resize(side * side)
	level.fill(-1.0e9)

	for k in range(side * side):
		if water_class[k] == 3 and depth[k] >= 0.12:
			level[k] = heights[k] + depth[k]

	var raised: int = 0
	var volume: float = 0.0
	var spacing_area: float = 64.0
	var result: PackedFloat32Array = depth.duplicate()

	for j in range(side):
		for i in range(side):
			var k: int = j * side + i

			if water_class[k] != 3 or depth[k] >= 0.12:
				continue

			var best: float = -1.0e9

			for dj in range(-reach, reach + 1):
				var nj: int = j + dj

				if nj < 0 or nj >= side:
					continue

				for di in range(-reach, reach + 1):
					var ni: int = i + di

					if ni < 0 or ni >= side:
						continue

					best = maxf(best, level[nj * side + ni])

			if best > -1.0e8 and best - heights[k] >= 0.12 and best - heights[k] <= max_depth:
				result[k] = best - heights[k]
				raised += 1
				volume += (result[k] - depth[k]) * spacing_area

	for k in range(side * side):
		depth[k] = result[k]

	return {"cells": raised, "volume_m3": volume}
