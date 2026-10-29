extends SceneTree

# Painted river beds that do not run downhill: pits (a painted river cell with no lower painted, ocean or edge neighbour) hold water until it
# fills to the rim, so a river with pits is a chain of lakes, not a channel to the sea (Dave 24 Oct, flooded valley at x 54683 z 75053).
# Read only: counts pits per tile and writes pits_X_Z.csv (world x z, ground, climb to the lowest painted neighbour = how deep a lake it makes).
#
#   godot --headless --path . --script res://src/worldgen/tools/river_pits.gd -- [--tile=3,4 | --all] [--world=res://worlds/base_world] [--out=DIR]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")


func _init() -> void:
	var tiles: Array = [Vector2i(3, 4)]
	var world: String = "res://worlds/base_world"
	var out_dir: String = "/mnt/project-files/water/land_map"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tiles = [Vector2i(int(parts[0]), int(parts[1]))]
		elif argument == "--all":
			tiles = []

			for x in range(2, 5):
				for z in range(3, 6):
					tiles.append(Vector2i(x, z))
		elif argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	DirAccess.make_dir_recursive_absolute(out_dir)

	for tile in tiles:
		var data = generator.get_tile(tile)

		if data.placeholder:
			continue

		var side: int = data.samples
		var rows: PackedStringArray = PackedStringArray(["world_x,world_z,ground_m,climb_m,dead_end"])
		var painted: int = 0
		var pits: int = 0
		var dead_ends: int = 0
		var climb_total: float = 0.0

		for j in range(1, side - 1):
			for i in range(1, side - 1):
				var k: int = j * side + i

				if data.water_class[k] != 3 or data.heights[k] <= 0.0:
					continue

				painted += 1
				var here: float = data.heights[k]
				var lowest_up: float = INF
				var has_down: bool = false

				for dj in range(-1, 2):
					for di in range(-1, 2):
						if di == 0 and dj == 0:
							continue

						var n: int = k + dj * side + di
						var kind: int = data.water_class[n]

						if kind == 1 or data.heights[n] <= 0.0 or i + di <= 0 or j + dj <= 0 or i + di >= side - 1 or j + dj >= side - 1:
							has_down = true      # the sea or the tile edge
						elif (kind == 2 or kind == 3) and data.heights[n] < here:
							has_down = true
						elif kind == 2 or kind == 3:
							lowest_up = minf(lowest_up, data.heights[n] - here)

				if not has_down:
					pits += 1
					climb_total += lowest_up if lowest_up < INF else 0.0
					var dead: bool = here > 2.0 and not _lower_painted_near(data, side, i, j, 3)
					dead_ends += 1 if dead else 0
					rows.append("%.0f,%.0f,%.2f,%.2f,%s" % [data.x0 + float(i) * data.spacing_m, data.z0 + float(j) * data.spacing_m, here, lowest_up if lowest_up < INF else -1.0, "DEAD END" if dead else ""])

		var file: FileAccess = FileAccess.open("%s/pits_%d_%d.csv" % [out_dir, tile.x, tile.y], FileAccess.WRITE)
		file.store_string("\n".join(rows) + "\n")
		file.close()
		print("tile %s: %d painted river cells, %d pits (painted cells with no lower painted/sea/edge neighbour), %d of them dead ends (nothing lower within 3 cells, above 2 m), mean climb to the rim %.2f m" % [str(tile), painted, pits, dead_ends, climb_total / maxf(float(pits), 1.0)])

	quit(0)


# Any painted river or lake cell within `reach` cells that is lower than (i, j), or the sea.
func _lower_painted_near(data, side: int, i: int, j: int, reach: int) -> bool:
	var here: float = data.heights[j * side + i]

	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var ni: int = i + di
			var nj: int = j + dj

			if ni < 0 or nj < 0 or ni >= side or nj >= side:
				return true

			var n: int = nj * side + ni
			var kind: int = data.water_class[n]

			if kind == 1 or data.heights[n] <= 0.0 or ((kind == 2 or kind == 3) and data.heights[n] < here):
				return true

	return false
