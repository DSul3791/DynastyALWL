extends SceneTree

# Where does settled water stop short of the sea, and why? For a tile and its settled .water file: every body of settled water that touches no sea, no
# tile edge and no lower water gets one line with its end (world x z, ground, water), the pit it sits in (spill height and cell, basin area, the volume
# that would fill it, the water already in it, what is missing and how long a base spring takes to bring it) and whether the painted river carries on
# downhill from the end. The class says whose job it is: PIT (terrain, Sonny), NOT FULL (the water never reached the spill: settler), DOWNHILL OPEN
# (no pit, the ground runs on: the water ran out, settler), SEAM (tile border).
# Priority-flood (minimax path) from the end cell, within WINDOW cells so a tile takes seconds, not minutes.
#   godot --headless --path . --script res://src/worldgen/tools/river_settle_report.gd -- --tile=3,4 [--world=DIR] [--window=150] [--min-cells=60] [--spring=10]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterStore := preload("res://src/water/water_store.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")

const DEFAULT_WORLD_DIR := "res://worlds/base_world"
const WET_M := 0.12             # settled water counts as water from this depth (the sim's WET_M)
const GAP := 2                  # samples bridged when joining wet cells into one body
const SEAM_CELLS := 3           # an end this close to the tile edge is a seam case
const CONTINUES_SEARCH := 40    # samples searched below the end for painted river that the water does not reach

var world_dir: String = DEFAULT_WORLD_DIR
var _spring_cells: PackedInt32Array = PackedInt32Array()   # where the settler puts springs for this tile (src/water/water_settler.gd build)
var _spring_rates: PackedFloat32Array = PackedFloat32Array()
var _flow: PackedFloat32Array = PackedFloat32Array()        # the tile file's flow map: drained cells per sample (rivers only), decoded


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var window: int = 150
	var min_cells: int = 60
	var spring: float = 10.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--window="):
			window = int(argument.trim_prefix("--window="))
		elif argument.begins_with("--min-cells="):
			min_cells = int(argument.trim_prefix("--min-cells="))
		elif argument.begins_with("--spring="):
			spring = float(argument.trim_prefix("--spring="))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		push_error("no baked tile %s" % tile)
		quit(1)
		return

	var side: int = data.samples
	var depth: PackedFloat32Array = WaterStore.load_depth("%s/water/tile_%d_%d.water" % [world_dir, tile.x, tile.y], side)

	if depth.is_empty():
		push_error("no settled water file for tile %s" % tile)
		quit(1)
		return

	var spacing: float = data.spacing_m
	var sim = WaterSettler.build(data, spring, generator)

	for sp in sim.springs:
		_spring_cells.append(int(sp[0]))
		_spring_rates.append(float(sp[1]))

	var tile_path: String = "%s/tiles/tile_%d_%d.tile" % [world_dir, tile.x, tile.y]
	var head: Dictionary = TileFileScript.read_header(tile_path)

	if bool(head.get("ok", false)):
		_flow = TileFileScript.decode_flow(TileFileScript.read_section(tile_path, head["table"], "flow")["raw"])

	print("settler places %d springs on tile %d,%d; flow map %s" % [_spring_cells.size(), tile.x, tile.y, "read" if not _flow.is_empty() else "NOT read"])
	var flow_max: float = 0.0

	for value in _flow:
		flow_max = maxf(flow_max, value)

	print("flow map: %d values, biggest %.0f drained cells" % [_flow.size(), flow_max])
	var body: PackedInt32Array = PackedInt32Array()
	body.resize(side * side)
	body.fill(-1)
	var bodies: int = 0
	var inland: int = 0

	for start in range(side * side):
		if body[start] >= 0 or depth[start] < WET_M or data.heights[start] <= 0.0:
			continue

		var members: PackedInt32Array = _collect(data, depth, side, start, body)

		if members.size() < min_cells:
			continue

		bodies += 1
		var reaches: bool = false
		var end: int = members[0]

		for k in members:
			if data.heights[k] < data.heights[end]:
				end = k

		for k in members:
			if _touches_outlet(data, side, k):
				reaches = true
				break

		if reaches:
			continue

		inland += 1
		print(_describe(data, depth, side, spacing, members, end, window, spring))

	print("river_settle_report tile %d,%d: %d water bodies of %d+ cells, %d end inland" % [tile.x, tile.y, bodies, min_cells, inland])
	quit(0)


# The cells of the wet body that `start` belongs to (gaps up to GAP samples bridged); marks them in `body`.
func _collect(data, depth: PackedFloat32Array, side: int, start: int, body: PackedInt32Array) -> PackedInt32Array:
	var members: PackedInt32Array = PackedInt32Array([start])
	body[start] = start
	var head: int = 0

	while head < members.size():
		var k: int = members[head]
		head += 1
		var ci: int = k % side
		var cj: int = floori(float(k) / float(side))

		for dj in range(-GAP, GAP + 1):
			for di in range(-GAP, GAP + 1):
				var ni: int = ci + di
				var nj: int = cj + dj

				if ni < 0 or nj < 0 or ni >= side or nj >= side:
					continue

				var n: int = nj * side + ni

				if body[n] < 0 and depth[n] >= WET_M and data.heights[n] > 0.0:
					body[n] = start
					members.append(n)

	return members


# True when the cell is at the tile edge or has sea (ground at or under 0) within GAP samples: the water reaches an outlet.
func _touches_outlet(data, side: int, k: int) -> bool:
	var ci: int = k % side
	var cj: int = floori(float(k) / float(side))

	if ci <= 1 or cj <= 1 or ci >= side - 2 or cj >= side - 2:
		return true

	for dj in range(-GAP, GAP + 1):
		for di in range(-GAP, GAP + 1):
			if data.heights[(cj + dj) * side + ci + di] <= 0.0:
				return true

	return false


func _describe(data, depth: PackedFloat32Array, side: int, spacing: float, members: PackedInt32Array, end: int, window: int, spring: float) -> String:
	var ei: int = end % side
	var ej: int = floori(float(end) / float(side))
	var x: float = data.x0 + float(ei) * spacing
	var z: float = data.z0 + float(ej) * spacing
	var ground_end: float = data.heights[end]
	var water_end: float = ground_end + depth[end]
	var cells: int = members.size()
	var flood: Dictionary = _spill(data, side, end, window)
	var rim: float = float(flood["rim"])
	var area: float = 0.0
	var fill: float = 0.0
	var stored: float = 0.0
	var cell_m2: float = spacing * spacing

	for k in flood["basin"]:
		if data.heights[k] < rim:
			area += cell_m2
			fill += (rim - data.heights[k]) * cell_m2

		if depth[k] > 0.0:
			stored += depth[k] * cell_m2

	var missing: float = maxf(fill - stored, 0.0)
	var hours: float = missing / maxf(spring, 0.001) / 3600.0
	var carries: String = _continues(data, side, ei, ej)
	var fed: String = _fed(data, side, spacing, members)
	var kind: String = ""

	if ei <= SEAM_CELLS or ej <= SEAM_CELLS or ei >= side - 1 - SEAM_CELLS or ej >= side - 1 - SEAM_CELLS:
		kind = "SEAM"
	elif not bool(flood["closed"]) and rim - ground_end < 0.3:
		kind = "DOWNHILL OPEN (the ground runs on downhill from the end, no pit: the water ran out or was lost; settler volume)"
	elif bool(flood["closed"]) and carries == "no painted river below":
		kind = "PIT (terrain: no spill route inside the window, no painted river below)"
	elif missing > 0.5 * fill and fill > 0.0:
		kind = "NOT FULL (basin %.0f%% full: water never reached the spill)" % (100.0 * stored / maxf(fill, 1.0))
	else:
		kind = "FULL BUT STOPPED (spill %.1f m above the end, water level %.1f vs rim %.1f: check the spill cell)" % [rim - ground_end, water_end, rim]

	return "INLAND end x %.0f z %.0f (sample %d,%d): %d wet cells, ground %.1f m, water %.1f m; spill %.1f m at x %.0f z %.0f%s; basin %.0f m2, fill volume %.0f m3, stored %.0f m3, missing %.0f m3 (%.1f h of one %.0f m3/s spring); painted river: %s; %s; CLASS %s" % [
			x, z, ei, ej, cells, ground_end, water_end, rim, data.x0 + float(int(flood["spill"]) % side) * spacing, data.z0 + floorf(float(int(flood["spill"])) / float(side)) * spacing,
			" (no outlet found, window edge)" if bool(flood["closed"]) else "", area, fill, stored, missing, hours, spring, carries, fed, kind]


# Is the body fed? The distance from its nearest cell to the nearest settler spring and that spring's rate, and the drainage the tile file records
# at the body's highest cell (the catchment the river brings in, in km2): a body with no spring near it and a big catchment is a river that is
# painted but never gets its water in the settle (the cause of "full but stopped").
func _fed(data, side: int, spacing: float, members: PackedInt32Array) -> String:
	var head_cell: int = members[0]
	var nearest: float = INF
	var nearest_rate: float = 0.0

	for k in members:
		if data.heights[k] > data.heights[head_cell]:
			head_cell = k

		var ki: int = k % side
		var kj: int = floori(float(k) / float(side))

		for n in range(_spring_cells.size()):
			var d: float = sqrt(float((_spring_cells[n] % side - ki) * (_spring_cells[n] % side - ki) + (floori(float(_spring_cells[n]) / float(side)) - kj) * (floori(float(_spring_cells[n]) / float(side)) - kj))) * spacing

			if d < nearest:
				nearest = d
				nearest_rate = _spring_rates[n]

	# The highest wet cell is often not a painted river cell (flow 0 there), so take the biggest drainage on the body and within 2 cells of it.
	var drained: float = 0.0

	if _flow.size() == data.heights.size():
		for k in members:
			var ki2: int = k % side
			var kj2: int = floori(float(k) / float(side))

			for dj in range(-2, 3):
				for di in range(-2, 3):
					var ni: int = ki2 + di
					var nj: int = kj2 + dj

					if ni >= 0 and ni < side and nj >= 0 and nj < side:
						drained = maxf(drained, _flow[nj * side + ni])

	var catchment: float = drained * spacing * spacing / 1.0e6 if _flow.size() == data.heights.size() else -1.0
	return "nearest spring %s, head x %.0f z %.0f ground %.1f m, biggest catchment on body %s" % [("none" if nearest == INF else "%.0f m (%.1f m3/s)" % [nearest, nearest_rate]), data.x0 + float(head_cell % side) * spacing, data.z0 + floorf(float(head_cell) / float(side)) * spacing, data.heights[head_cell], ("unknown (flow map size %d vs %d samples)" % [_flow.size(), data.heights.size()] if catchment < 0.0 else "%.1f km2" % catchment)]


# Minimax path (priority flood) from `start` out to the window's rim: `rim` is the lowest height the water has to climb to to leave
# (the spill elevation), `spill` the cell where it leaves, `basin` the cells reachable from start below that height, `closed` true when the
# window edge was reached only over higher ground than everything inside (no lower outlet seen).
func _spill(data, side: int, start: int, window: int) -> Dictionary:
	var si: int = start % side
	var sj: int = floori(float(start) / float(side))
	var lo_i: int = maxi(si - window, 0)
	var lo_j: int = maxi(sj - window, 0)
	var hi_i: int = mini(si + window, side - 1)
	var hi_j: int = mini(sj + window, side - 1)
	var width: int = hi_i - lo_i + 1
	var height: int = hi_j - lo_j + 1
	var best: PackedFloat32Array = PackedFloat32Array()
	best.resize(width * height)
	best.fill(INF)
	var heap_key: PackedFloat32Array = PackedFloat32Array()
	var heap_cell: PackedInt32Array = PackedInt32Array()
	var origin: int = (sj - lo_j) * width + (si - lo_i)
	best[origin] = data.heights[start]
	_push(heap_key, heap_cell, data.heights[start], origin)
	var rim: float = INF
	var spill: int = start
	var closed: bool = true
	var below_start: float = data.heights[start]

	while not heap_cell.is_empty():
		var popped: Array = _pop(heap_key, heap_cell)
		var key: float = float(popped[0])
		var cell: int = int(popped[1])

		if key > best[cell]:
			continue

		var ci: int = cell % width
		var cj: int = floori(float(cell) / float(width))
		var world: int = (lo_j + cj) * side + lo_i + ci
		var ground: float = data.heights[world]

		# An outlet: the sea, or ground lower than where we started (the water can run on downhill from here).
		if ground <= 0.0 or (ground < below_start - 0.5 and key <= rim):
			rim = minf(rim, key)
			spill = world
			closed = false
			break

		if ci == 0 or cj == 0 or ci == width - 1 or cj == height - 1:
			continue

		for dj in range(-1, 2):
			for di in range(-1, 2):
				if di == 0 and dj == 0:
					continue

				var n: int = (cj + dj) * width + ci + di
				var raised: float = maxf(key, data.heights[(lo_j + cj + dj) * side + lo_i + ci + di])

				if raised < best[n]:
					best[n] = raised
					_push(heap_key, heap_cell, raised, n)

	if rim == INF:
		rim = _highest_inside(best)

	var basin: PackedInt32Array = PackedInt32Array()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(width * height)
	var queue: PackedInt32Array = PackedInt32Array([origin])
	seen[origin] = 1
	var head: int = 0

	while head < queue.size():
		var cell_now: int = queue[head]
		head += 1
		var bi: int = cell_now % width
		var bj: int = floori(float(cell_now) / float(width))
		basin.append((lo_j + bj) * side + lo_i + bi)

		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ni: int = bi + di
				var nj: int = bj + dj

				if ni < 0 or nj < 0 or ni >= width or nj >= height or seen[nj * width + ni] == 1:
					continue

				if data.heights[(lo_j + nj) * side + lo_i + ni] < rim:
					seen[nj * width + ni] = 1
					queue.append(nj * width + ni)

	return {"rim": rim, "spill": spill, "basin": basin, "closed": closed}


# With no outlet found the window is a closed bowl: its rim is the lowest height reached on the window edge.
func _highest_inside(best: PackedFloat32Array) -> float:
	var top: float = 0.0

	for value in best:
		if value != INF:
			top = maxf(top, value)

	return top


# Painted river (water class river or lake) lower than the end within CONTINUES_SEARCH samples that holds no settled water.
func _continues(data, side: int, ei: int, ej: int) -> String:
	var ground: float = data.heights[ej * side + ei]
	var closest: float = INF
	var drop: float = 0.0

	for dj in range(-CONTINUES_SEARCH, CONTINUES_SEARCH + 1):
		for di in range(-CONTINUES_SEARCH, CONTINUES_SEARCH + 1):
			var ni: int = ei + di
			var nj: int = ej + dj

			if ni < 0 or nj < 0 or ni >= side or nj >= side:
				continue

			var k: int = nj * side + ni
			var painted: int = data.water_class[k]

			if (painted == 2 or painted == 3) and data.heights[k] < ground - 0.3:
				var d: float = sqrt(float(di * di + dj * dj))

				if d < closest:
					closest = d
					drop = ground - data.heights[k]

	if closest == INF:
		return "no painted river below"

	return "carries on %.0f m away, %.1f m lower" % [closest * data.spacing_m, drop]


static func _push(keys: PackedFloat32Array, cells: PackedInt32Array, key: float, cell: int) -> void:
	keys.append(key)
	cells.append(cell)
	var n: int = keys.size() - 1

	while n > 0:
		@warning_ignore("integer_division")
		var parent: int = (n - 1) / 2

		if keys[parent] <= keys[n]:
			break

		var swap_key: float = keys[parent]
		var swap_cell: int = cells[parent]
		keys[parent] = keys[n]
		cells[parent] = cells[n]
		keys[n] = swap_key
		cells[n] = swap_cell
		n = parent


static func _pop(keys: PackedFloat32Array, cells: PackedInt32Array) -> Array:
	var top_key: float = keys[0]
	var top_cell: int = cells[0]
	var last: int = keys.size() - 1
	keys[0] = keys[last]
	cells[0] = cells[last]
	keys.resize(last)
	cells.resize(last)
	var n: int = 0

	while true:
		var left: int = 2 * n + 1
		var right: int = left + 1
		var smallest: int = n

		if left < last and keys[left] < keys[smallest]:
			smallest = left

		if right < last and keys[right] < keys[smallest]:
			smallest = right

		if smallest == n:
			break

		var swap_key: float = keys[smallest]
		var swap_cell: int = cells[smallest]
		keys[smallest] = keys[n]
		cells[smallest] = cells[n]
		keys[n] = swap_key
		cells[n] = swap_cell
		n = smallest

	return [top_key, top_cell]
