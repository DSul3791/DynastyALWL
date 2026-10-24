extends SceneTree

# Basin census (Dave 24 Oct 2026: "why are there no real, normally deep catch basins to make lakes and ponds? they should be sizable").
# Finds every natural depression in the baked ground (priority flood: the level water would fill each hollow to before it spills) and compares it
# with the water the sim settled into. Read only. Ground is sampled every 2nd cell (16 m) to keep it quick.
#
#   godot --headless --path . --script res://src/worldgen/tools/basin_census.gd -- [--tile=3,4 | --all] [--world=res://worlds/base_world] [--out=DIR]
#
# Classes (depth = spill level minus the lowest ground of the hollow): pond 0.5 m+ and 1,000 m2+, lake 1.5 m+ and 5,000 m2+, big lake 3 m+ and 20,000 m2+.
# Writes basins_X_Z.csv (every hollow of 0.5 m+ and 1,000 m2+) and prints one summary line per tile, plus the settled water's own deep pools.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterStore := preload("res://src/water/water_store.gd")

const STEP := 2                      # every 2nd cell
const MIN_DEPTH_M := 0.3
const POND_DEPTH_M := 0.5
const POND_AREA_M2 := 1000.0
const LAKE_DEPTH_M := 1.5
const LAKE_AREA_M2 := 5000.0
const BIG_DEPTH_M := 3.0
const BIG_AREA_M2 := 20000.0


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

		_census(data, WaterStore.load_depth("%s/water/tile_%d_%d.water" % [world, tile.x, tile.y], data.samples), out_dir, tile)

	quit(0)


func _census(data, saved: PackedFloat32Array, out_dir: String, tile: Vector2i) -> void:
	var started: int = Time.get_ticks_msec()
	var full: int = data.samples
	var side: int = full / STEP
	var cell_m2: float = pow(data.spacing_m * float(STEP), 2.0)
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(side * side)

	for j in range(side):
		for i in range(side):
			ground[j * side + i] = data.heights[j * STEP * full + i * STEP]

	# Priority flood from the sea (ground at or under 0) and the tile edge: filled = the level each cell's water would stand at.
	var filled: PackedFloat32Array = ground.duplicate()
	var closed: PackedByteArray = PackedByteArray()
	closed.resize(side * side)
	var heap_key: PackedFloat32Array = PackedFloat32Array()
	var heap_idx: PackedInt32Array = PackedInt32Array()

	for j in range(side):
		for i in range(side):
			var k: int = j * side + i

			if ground[k] <= 0.0 or i == 0 or j == 0 or i == side - 1 or j == side - 1:
				closed[k] = 1
				_push(heap_key, heap_idx, ground[k], k)

	while not heap_idx.is_empty():
		var top: Array = _pop(heap_key, heap_idx)
		var level: float = top[0]
		var k: int = top[1]
		var ki: int = k % side
		@warning_ignore("integer_division")
		var kj: int = k / side

		for n in [k - 1 if ki > 0 else -1, k + 1 if ki < side - 1 else -1, k - side if kj > 0 else -1, k + side if kj < side - 1 else -1]:
			if n < 0 or closed[n] != 0:
				continue

			closed[n] = 1
			filled[n] = maxf(ground[n], level)
			_push(heap_key, heap_idx, filled[n], n)

	# Hollows: connected cells whose fill is MIN_DEPTH_M or more above the ground.
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(side * side)
	var rows: PackedStringArray = PackedStringArray(["world_x,world_z,area_m2,max_depth_m,volume_m3,spill_level_m,wet_share_in_saved_water,class"])
	var counts: Dictionary = {"pond": 0, "lake": 0, "big": 0, "small": 0}
	var wet_counts: Dictionary = {"pond": 0, "lake": 0, "big": 0, "small": 0}
	var total_volume: float = 0.0

	for start in range(side * side):
		if label[start] != 0 or filled[start] - ground[start] < MIN_DEPTH_M:
			continue

		var queue: PackedInt32Array = PackedInt32Array([start])
		label[start] = 1
		var count: int = 0
		var max_depth: float = 0.0
		var volume: float = 0.0
		var spill: float = filled[start]
		var wet: int = 0
		var deepest: int = start

		while not queue.is_empty():
			var k: int = queue[queue.size() - 1]
			queue.resize(queue.size() - 1)
			count += 1
			var d: float = filled[k] - ground[k]
			volume += d * cell_m2

			if d > max_depth:
				max_depth = d
				deepest = k

			var fi: int = (k % side) * STEP
			@warning_ignore("integer_division")
			var fj: int = (k / side) * STEP

			if not saved.is_empty() and saved[fj * full + fi] >= 0.1:
				wet += 1

			var ki: int = k % side
			@warning_ignore("integer_division")
			var kj: int = k / side

			for n in [k - 1 if ki > 0 else -1, k + 1 if ki < side - 1 else -1, k - side if kj > 0 else -1, k + side if kj < side - 1 else -1]:
				if n >= 0 and label[n] == 0 and filled[n] - ground[n] >= MIN_DEPTH_M:
					label[n] = 1
					queue.append(n)

		var area: float = float(count) * cell_m2
		var kind: String = "small"

		if max_depth >= BIG_DEPTH_M and area >= BIG_AREA_M2:
			kind = "big"
		elif max_depth >= LAKE_DEPTH_M and area >= LAKE_AREA_M2:
			kind = "lake"
		elif max_depth >= POND_DEPTH_M and area >= POND_AREA_M2:
			kind = "pond"

		counts[kind] += 1
		wet_counts[kind] += 1 if float(wet) / float(count) >= 0.5 else 0
		total_volume += volume

		if kind != "small":
			var dx: float = data.x0 + float((deepest % side) * STEP) * data.spacing_m
			@warning_ignore("integer_division")
			var dz: float = data.z0 + float((deepest / side) * STEP) * data.spacing_m
			rows.append("%.0f,%.0f,%.0f,%.2f,%.0f,%.1f,%.2f,%s" % [dx, dz, area, max_depth, volume, spill, float(wet) / float(count), kind])

	var file: FileAccess = FileAccess.open("%s/basins_%d_%d.csv" % [out_dir, tile.x, tile.y], FileAccess.WRITE)
	file.store_string("\n".join(rows) + "\n")
	file.close()

	# The settled water's own deep pools: wet cells 0.6 m or deeper, joined; area and deepest.
	var pools: int = 0
	var pool_cells: int = 0
	var big_pools: int = 0

	if not saved.is_empty():
		var seen: PackedByteArray = PackedByteArray()
		seen.resize(saved.size())

		for start in range(0, saved.size(), 1):
			if seen[start] != 0 or saved[start] < 0.6 or data.water_surface.size() == 0:
				continue

			var queue: PackedInt32Array = PackedInt32Array([start])
			seen[start] = 1
			var n_cells: int = 0

			while not queue.is_empty():
				var k: int = queue[queue.size() - 1]
				queue.resize(queue.size() - 1)
				n_cells += 1

				for n in [k - 1, k + 1, k - full, k + full]:
					if n >= 0 and n < saved.size() and seen[n] == 0 and saved[n] >= 0.6:
						seen[n] = 1
						queue.append(n)

			if n_cells >= 16:
				pools += 1
				pool_cells += n_cells
				big_pools += 1 if float(n_cells) * data.spacing_m * data.spacing_m >= LAKE_AREA_M2 else 0

	print("tile %s: hollows 0.3 m+ of the baked ground: %d small, %d ponds (0.5 m, 1,000 m2), %d lakes (1.5 m, 5,000 m2), %d big lakes (3 m, 20,000 m2); of these hold water in the settled water: ponds %d, lakes %d, big %d; total hollow volume %.0f m3. Settled water: %d deep pools (0.6 m+, 1,000 m2+), %d of them 5,000 m2+, %d ms" % [str(tile), counts["small"], counts["pond"], counts["lake"], counts["big"], wet_counts["pond"], wet_counts["lake"], wet_counts["big"], total_volume, pools, big_pools, Time.get_ticks_msec() - started])


func _push(keys: PackedFloat32Array, idx: PackedInt32Array, key: float, value: int) -> void:
	keys.append(key)
	idx.append(value)
	var c: int = keys.size() - 1

	while c > 0:
		@warning_ignore("integer_division")
		var p: int = (c - 1) / 2

		if keys[p] <= keys[c]:
			break

		var tk: float = keys[p]
		keys[p] = keys[c]
		keys[c] = tk
		var tv: int = idx[p]
		idx[p] = idx[c]
		idx[c] = tv
		c = p


func _pop(keys: PackedFloat32Array, idx: PackedInt32Array) -> Array:
	var result: Array = [keys[0], idx[0]]
	var last: int = keys.size() - 1
	keys[0] = keys[last]
	idx[0] = idx[last]
	keys.resize(last)
	idx.resize(last)
	var c: int = 0

	while true:
		var l: int = c * 2 + 1
		var r: int = l + 1
		var m: int = c

		if l < last and keys[l] < keys[m]:
			m = l

		if r < last and keys[r] < keys[m]:
			m = r

		if m == c:
			break

		var tk: float = keys[m]
		keys[m] = keys[c]
		keys[c] = tk
		var tv: int = idx[m]
		idx[m] = idx[c]
		idx[c] = tv
		c = m

	return result
