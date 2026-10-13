class_name TileWater
extends RefCounted

# Hydrology for one tile's 8 m height map. Water drains downhill; pits
# are filled or become lakes; rivers start where enough rain collects and
# are carved into the ground so they always run downhill to the sea.
#
# Outputs (one entry per sample, same layout as the height map):
#   heights        the height map after filling pits and carving rivers
#   water_class    0 none, 1 ocean, 2 lake, 3 river
#   water_surface  height of the water surface (only where water_class > 0)
#   flow           catchment area drained through the cell, in cells
#
# Tile edges: land cells on the tile border count as outlets, so rivers
# end at the edge. Joining rivers across tile borders is a later step.

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const NONE := 0
const OCEAN := 1
const LAKE := 2
const RIVER := 3

var samples: int = 0
var spacing_m: float = 8.0
var heights: PackedFloat32Array = PackedFloat32Array()
var water_class: PackedByteArray = PackedByteArray()
var water_surface: PackedFloat32Array = PackedFloat32Array()
var flow: PackedFloat32Array = PackedFloat32Array()

# Report after build().
var river_cells: int = 0
var lakes: Array = []            # {"cells", "area_m2", "surface_m", "depth_m"}
var filled_cells: int = 0
var longest_river_m: float = 0.0
var starter_path: PackedVector2Array = PackedVector2Array()   # sample coordinates, source to mouth

var _settings
var _rules: Dictionary = {}


func setup(settings, rules: Dictionary) -> void:
	_settings = settings
	_rules = rules["water"]
	spacing_m = float(settings.map_spacing_m)


func build(height_map, tile: Vector2i, starter: Dictionary = {}) -> void:
	samples = height_map.samples
	var total: int = samples * samples
	heights = height_map.heights.duplicate()
	water_class = PackedByteArray()
	water_class.resize(total)
	water_surface = PackedFloat32Array()
	water_surface.resize(total)
	flow = PackedFloat32Array()
	flow.resize(total)
	lakes = []
	river_cells = 0
	filled_cells = 0
	starter_path = PackedVector2Array()
	var extra: Dictionary = {}
	var river_rules: Dictionary = _rules.get("starter_river", {})

	# Pass 1 finds the lakes; the starter river is then cut from the biggest
	# highland lake to the bay head and the whole thing is run again.
	var original: PackedFloat32Array = heights.duplicate()
	_hydrology(tile, {})

	if bool(river_rules.get("enabled", false)) and not starter.is_empty():
		var source: int = _pick_source(starter, tile, float(river_rules["source_min_height_m"]))

		if source >= 0:
			heights = original.duplicate()
			extra = _cut_starter_river(source, starter, tile, river_rules)

			if not extra.is_empty():
				_hydrology(tile, extra)
			else:
				heights = original.duplicate()
				_hydrology(tile, {})


func _hydrology(tile: Vector2i, extra: Dictionary) -> void:
	var total: int = samples * samples
	water_class.fill(0)
	water_surface.fill(0.0)
	flow.fill(0.0)
	lakes = []
	river_cells = 0
	filled_cells = 0
	var routed: PackedInt32Array = _routing_heights(tile)
	var ocean: PackedByteArray = _find_ocean()
	var level: PackedInt32Array = PackedInt32Array()
	var parent: PackedInt32Array = PackedInt32Array()
	var order: PackedInt32Array = _flood(routed, ocean, level, parent)
	_accumulate(order, parent, ocean, extra)
	_resolve_pits(routed, level, ocean)

	for index in range(total):
		if ocean[index] == 1:
			water_class[index] = OCEAN
			water_surface[index] = 0.0

	_carve_rivers(level, parent, ocean)


# Heights in tenths of a meter with a little noise, so flat ground drains
# in gentle bends instead of straight lines.
func _routing_heights(tile: Vector2i) -> PackedInt32Array:
	var total: int = samples * samples
	var tile_samples: int = samples - 1
	var offset_field: PackedFloat32Array = PackedFloat32Array()
	offset_field.resize(total)
	var index_octave: int = 0

	for octave in _rules["route_noise"]:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = SeedUtil.purpose_seed(_settings.master_seed, "tile_route", index_octave)
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.frequency = spacing_m / float(octave["wavelength_m"])
		noise.offset = Vector3(float(tile.x * tile_samples), float(tile.y * tile_samples), 0.0)
		var image: Image = noise.get_image(samples, samples, false, false, false)

		if image.get_format() != Image.FORMAT_L8:
			image.convert(Image.FORMAT_L8)

		var data: PackedByteArray = image.get_data()
		var amplitude: float = float(octave["amplitude_m"])

		for index in range(total):
			offset_field[index] += amplitude * (float(data[index]) / 127.5 - 1.0)

		index_octave += 1

	var routed: PackedInt32Array = PackedInt32Array()
	routed.resize(total)

	for index in range(total):
		var h: float = heights[index]
		routed[index] = maxi(int(round((h + offset_field[index]) * 10.0)), -50) if h > 0.0 else clampi(int(round(h * 10.0)), -50, 0)

	return routed


# Sea cells (at or below sea level) joined to the tile border.
func _find_ocean() -> PackedByteArray:
	var total: int = samples * samples
	var ocean: PackedByteArray = PackedByteArray()
	ocean.resize(total)
	var stack: PackedInt32Array = PackedInt32Array()

	for k in range(samples):
		for index in [k, (samples - 1) * samples + k, k * samples, k * samples + samples - 1]:
			if heights[index] <= 0.0 and ocean[index] == 0:
				ocean[index] = 1
				stack.append(index)

	while not stack.is_empty():
		var index: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var row: int = index / samples
		var column: int = index % samples

		if column > 0 and ocean[index - 1] == 0 and heights[index - 1] <= 0.0:
			ocean[index - 1] = 1
			stack.append(index - 1)

		if column < samples - 1 and ocean[index + 1] == 0 and heights[index + 1] <= 0.0:
			ocean[index + 1] = 1
			stack.append(index + 1)

		if row > 0 and ocean[index - samples] == 0 and heights[index - samples] <= 0.0:
			ocean[index - samples] = 1
			stack.append(index - samples)

		if row < samples - 1 and ocean[index + samples] == 0 and heights[index + samples] <= 0.0:
			ocean[index + samples] = 1
			stack.append(index + samples)

	return ocean


# Priority flood from the sea and the tile border. level = the height each
# cell is filled up to, parent = the neighbor water leaves toward. Returns
# land cells in the order they were reached (parents before children).
func _flood(routed: PackedInt32Array, ocean: PackedByteArray, level: PackedInt32Array, parent: PackedInt32Array) -> PackedInt32Array:
	var total: int = samples * samples
	var low: int = -50
	var high: int = 0

	for value in routed:
		high = maxi(high, value)

	var head: PackedInt32Array = PackedInt32Array()
	head.resize(high - low + 1)
	head.fill(-1)
	var next: PackedInt32Array = PackedInt32Array()
	next.resize(total)
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(total)
	level.resize(total)
	parent.resize(total)
	parent.fill(-1)
	var offsets: Array = [-1, 1, -samples, samples, -samples - 1, -samples + 1, samples - 1, samples + 1]

	# Sea cells are done from the start; shore cells and border land are seeds.
	for index in range(total):
		if ocean[index] == 1:
			seen[index] = 1
			level[index] = 0

	for index in range(total):
		var row: int = index / samples
		var column: int = index % samples
		var on_border: bool = row == 0 or column == 0 or row == samples - 1 or column == samples - 1

		if ocean[index] == 1:
			continue

		var seed_it: bool = on_border

		if not seed_it:
			for step in offsets:
				if ocean[index + step] == 1:
					seed_it = true
					break

		if seed_it:
			seen[index] = 1
			level[index] = routed[index]
			next[index] = head[routed[index] - low]
			head[routed[index] - low] = index

	var order: PackedInt32Array = PackedInt32Array()

	for slot in range(head.size()):
		while head[slot] != -1:
			var index: int = head[slot]
			head[slot] = next[index]
			order.append(index)
			var row: int = index / samples
			var column: int = index % samples
			var here: int = level[index]

			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue

					var nr: int = row + dz
					var nc: int = column + dx

					if nr < 0 or nc < 0 or nr >= samples or nc >= samples:
						continue

					var neighbor: int = nr * samples + nc

					if seen[neighbor] == 1:
						continue

					seen[neighbor] = 1
					parent[neighbor] = index
					var filled: int = maxi(routed[neighbor], here)
					level[neighbor] = filled
					next[neighbor] = head[filled - low]
					head[filled - low] = neighbor

	return order


func _accumulate(order: PackedInt32Array, parent: PackedInt32Array, ocean: PackedByteArray, extra: Dictionary = {}) -> void:
	for index in order:
		flow[index] = 1.0 + float(extra.get(index, 0.0))

	for k in range(order.size() - 1, -1, -1):
		var index: int = order[k]
		var up: int = parent[index]

		if up >= 0 and ocean[up] == 0:
			flow[up] += flow[index]


# Pits: big deep ones become lakes, the rest are filled in.
func _resolve_pits(routed: PackedInt32Array, level: PackedInt32Array, ocean: PackedByteArray) -> void:
	var total: int = samples * samples
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(total)
	var fill_min: int = int(round(float(_rules["fill_min_depth_m"]) * 10.0))
	var lake_depth: float = float(_rules["lake_min_depth_m"])
	var lake_area: float = float(_rules["lake_min_area_m2"])
	var cell_m2: float = spacing_m * spacing_m

	for start in range(total):
		if visited[start] == 1 or ocean[start] == 1 or level[start] - routed[start] < fill_min:
			continue

		# One pit: connected cells sharing a fill level.
		var surface: int = level[start]
		var members: PackedInt32Array = PackedInt32Array([start])
		visited[start] = 1
		var cursor: int = 0
		var deepest: int = 0
		var min_column: int = samples
		var max_column: int = 0
		var min_row: int = samples
		var max_row: int = 0

		while cursor < members.size():
			var index: int = members[cursor]
			cursor += 1
			deepest = maxi(deepest, level[index] - routed[index])
			var row: int = index / samples
			var column: int = index % samples
			min_column = mini(min_column, column)
			max_column = maxi(max_column, column)
			min_row = mini(min_row, row)
			max_row = maxi(max_row, row)

			for neighbor in [
				index - 1 if column > 0 else -1, index + 1 if column < samples - 1 else -1,
				index - samples if row > 0 else -1, index + samples if row < samples - 1 else -1,
			]:
				if neighbor >= 0 and visited[neighbor] == 0 and ocean[neighbor] == 0 \
						and level[neighbor] == surface and level[neighbor] - routed[neighbor] >= fill_min:
					visited[neighbor] = 1
					members.append(neighbor)

		var area: float = float(members.size()) * cell_m2
		var surface_m: float = float(surface) / 10.0

		var box_w: float = float(max_column - min_column + 1) * spacing_m
		var box_h: float = float(max_row - min_row + 1) * spacing_m
		var compact: bool = (
			area / (box_w * box_h) >= float(_rules["lake_min_fill_ratio"])
			and minf(box_w, box_h) >= float(_rules["lake_min_width_m"])
		)

		if area >= lake_area and float(deepest) / 10.0 >= lake_depth and compact:
			for index in members:
				water_class[index] = LAKE
				water_surface[index] = surface_m

			lakes.append({
				"cells": members.size(), "area_m2": area,
				"surface_m": surface_m, "depth_m": float(deepest) / 10.0,
				"members": members,
			})
		else:
			for index in members:
				heights[index] = maxf(heights[index], surface_m)

			filled_cells += members.size()


# Rivers follow the flow directions from every cell whose catchment passes
# the start size. Each river cell lowers the ground around it.
func _carve_rivers(level: PackedInt32Array, parent: PackedInt32Array, ocean: PackedByteArray) -> void:
	var cell_km2: float = spacing_m * spacing_m / 1.0e6
	var start_cells: float = float(_rules["river_start_km2"]) / cell_km2
	var width_base: float = float(_rules["river_width_base_m"])
	var width_scale: float = float(_rules["river_width_per_sqrt_km2"])
	var depth_base: float = float(_rules["river_depth_base_m"])
	var depth_scale: float = float(_rules["river_depth_per_width"])
	var slope: float = float(_rules["bank_slope"])
	var total: int = samples * samples
	var best_flow: PackedFloat32Array = PackedFloat32Array()
	best_flow.resize(total)
	var bed_map: PackedFloat32Array = PackedFloat32Array()
	bed_map.resize(total)
	bed_map.fill(1.0e9)
	var carved: PackedFloat32Array = heights.duplicate()
	var longest: float = 0.0

	for index in range(total):
		if ocean[index] == 1 or flow[index] < start_cells or water_class[index] == LAKE:
			continue

		var area_km2: float = flow[index] * cell_km2
		var width: float = width_base + width_scale * sqrt(area_km2)
		var depth: float = depth_base + depth_scale * width
		var surface_here: float = float(level[index]) / 10.0
		var bed: float = minf(surface_here, heights[index]) - depth
		river_cells += 1
		_stamp(carved, ocean, index, width, depth, bed, slope, flow[index], best_flow, true)

	heights = carved

	# Longest chain of river cells down to the sea, for the report.
	var length: PackedFloat32Array = PackedFloat32Array()
	length.resize(total)

	for index in range(total):
		if water_class[index] != RIVER or flow[index] < start_cells:
			continue

		var count: float = 0.0
		var walker: int = index

		while walker >= 0 and ocean[walker] == 0 and flow[walker] >= start_cells and count < 4000.0:
			count += 1.0
			walker = parent[walker]

		longest = maxf(longest, count)

	longest_river_m = longest * spacing_m


# Lowers the ground around one river cell: a channel of the given width
# with banks rising at bank_slope. With mark_water, cells inside the
# channel become river water (the one with the bigger flow wins).
func _stamp(
	carved: PackedFloat32Array, ocean: PackedByteArray, index: int, width: float, depth: float,
	bed: float, slope: float, strength: float, best_flow: PackedFloat32Array, mark_water: bool
) -> void:
	var radius_m: float = width * 0.5 + (depth + 1.0) / slope
	var radius_cells: int = int(ceil(radius_m / spacing_m))
	var row: int = index / samples
	var column: int = index % samples

	for dz in range(-radius_cells, radius_cells + 1):
		var nr: int = row + dz

		if nr < 0 or nr >= samples:
			continue

		for dx in range(-radius_cells, radius_cells + 1):
			var nc: int = column + dx

			if nc < 0 or nc >= samples:
				continue

			var distance: float = sqrt(float(dx * dx + dz * dz)) * spacing_m

			if distance > radius_m:
				continue

			var target: int = nr * samples + nc

			if ocean[target] == 1:
				continue

			var floor_height: float = bed + maxf(distance - width * 0.5, 0.0) * slope
			carved[target] = minf(carved[target], floor_height)

			if mark_water and distance <= width * 0.5 and strength >= best_flow[target]:
				best_flow[target] = strength
				water_class[target] = RIVER
				water_surface[target] = bed + 0.75 * depth


# The surface point of the biggest highland lake nearest the bay.
func _pick_source(starter: Dictionary, tile: Vector2i, min_height: float) -> int:
	var head: Vector2 = _bay_head_samples(starter, tile)
	var best: int = -1
	var best_area: float = 0.0

	for lake in lakes:
		if float(lake["surface_m"]) < min_height or float(lake["area_m2"]) < best_area:
			continue

		best_area = float(lake["area_m2"])
		var nearest: int = -1
		var nearest_distance: float = INF

		for member in lake["members"]:
			var distance: float = Vector2(float(member % samples), float(member / samples)).distance_to(head)

			if distance < nearest_distance:
				nearest_distance = distance
				nearest = member

		best = nearest

	return best


func _bay_head_samples(starter: Dictionary, tile: Vector2i) -> Vector2:
	var tile_m: float = float(_settings.tile_size_m)
	var center: Vector2 = starter["bay_center"]
	var direction: Vector2 = starter["beach_dir"]
	var radius: float = float(starter["bay_radius_m"])
	var head_m: Vector2 = center - direction * radius * 0.95
	return Vector2(
		(head_m.x - float(tile.x) * tile_m) / spacing_m,
		(head_m.y - float(tile.y) * tile_m) / spacing_m
	)


# Finds the easiest valley route from the source to the bay head, cuts a
# guide channel along it (bed never rises downstream) and returns the extra
# water to feed in at the source: {cell index: extra catchment cells}.
func _cut_starter_river(source: int, starter: Dictionary, tile: Vector2i, river_rules: Dictionary) -> Dictionary:
	var step: int = maxi(int(round(float(river_rules["route_cell_m"]) / spacing_m)), 1)
	var coarse: int = (samples - 1) / step + 1
	var climb_cost: float = float(river_rules["climb_cost"])
	var head: Vector2 = _bay_head_samples(starter, tile)
	var goal: Vector2i = Vector2i(int(round(head.x / float(step))), int(round(head.y / float(step))))
	goal = Vector2i(clampi(goal.x, 0, coarse - 1), clampi(goal.y, 0, coarse - 1))
	var start: Vector2i = Vector2i((source % samples) / step, (source / samples) / step)

	# Walk the nearest land cell to the goal if the head sits in water.
	var best_goal: Vector2i = goal
	var best_distance: float = INF

	for dz in range(-8, 9):
		for dx in range(-8, 9):
			var probe: Vector2i = goal + Vector2i(dx, dz)

			if probe.x < 0 or probe.y < 0 or probe.x >= coarse or probe.y >= coarse:
				continue

			if heights[probe.y * step * samples + probe.x * step] > 0.8 and Vector2(dx, dz).length() < best_distance:
				best_distance = Vector2(dx, dz).length()
				best_goal = probe

	goal = best_goal

	# Dijkstra on the coarse grid. Climbing costs extra; sea is a wall.
	var cost: PackedFloat32Array = PackedFloat32Array()
	cost.resize(coarse * coarse)
	cost.fill(INF)
	var came: PackedInt32Array = PackedInt32Array()
	came.resize(coarse * coarse)
	came.fill(-1)
	var heap_keys: PackedFloat32Array = PackedFloat32Array()
	var heap_nodes: PackedInt32Array = PackedInt32Array()
	var start_node: int = start.y * coarse + start.x
	var goal_node: int = goal.y * coarse + goal.x
	cost[start_node] = 0.0
	_heap_push(heap_keys, heap_nodes, 0.0, start_node)

	while not heap_nodes.is_empty():
		var popped: Vector2 = _heap_pop(heap_keys, heap_nodes)
		var node: int = int(popped.y)

		if popped.x > cost[node]:
			continue

		if node == goal_node:
			break

		var row: int = node / coarse
		var column: int = node % coarse
		var here: float = heights[row * step * samples + column * step]

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue

				var nr: int = row + dz
				var nc: int = column + dx

				if nr < 0 or nc < 0 or nr >= coarse or nc >= coarse:
					continue

				var there: float = heights[nr * step * samples + nc * step]

				if there <= 0.8:
					continue

				var length: float = float(step) * spacing_m * (1.4142 if dx != 0 and dz != 0 else 1.0)
				var climb: float = maxf(there - here, 0.0)
				var next_cost: float = cost[node] + length * 0.2 + climb * climb_cost
				var next_node: int = nr * coarse + nc

				if next_cost < cost[next_node]:
					cost[next_node] = next_cost
					came[next_node] = node
					_heap_push(heap_keys, heap_nodes, next_cost, next_node)

	if came[goal_node] == -1 and goal_node != start_node:
		return {}

	var coarse_path: PackedVector2Array = PackedVector2Array()
	var walker: int = goal_node

	while walker != -1:
		coarse_path.append(Vector2(float((walker % coarse) * step), float((walker / coarse) * step)))
		walker = came[walker]

	coarse_path.reverse()
	var path: PackedVector2Array = _smooth_path(coarse_path, river_rules)
	starter_path = path

	# Guide channel: the bed never rises downstream and stays under the ground.
	var guide_width: float = float(river_rules["guide_width_m"])
	var guide_depth: float = float(river_rules["guide_depth_m"])
	var slope: float = float(_rules["bank_slope"])
	var mouth: float = float(river_rules["mouth_height_m"])
	var bed: float = INF
	var ocean: PackedByteArray = PackedByteArray()
	ocean.resize(samples * samples)
	var unused: PackedFloat32Array = PackedFloat32Array()
	unused.resize(samples * samples)
	var carved: PackedFloat32Array = heights.duplicate()

	for point in path:
		var column: int = clampi(int(round(point.x)), 0, samples - 1)
		var row: int = clampi(int(round(point.y)), 0, samples - 1)
		var index: int = row * samples + column
		bed = maxf(minf(bed, heights[index] - guide_depth), mouth)
		_stamp(carved, ocean, index, guide_width, guide_depth, bed, slope, 0.0, unused, false)

	heights = carved
	var extra_cells: float = float(river_rules["source_flow_km2"]) * 1.0e6 / (spacing_m * spacing_m)
	return {source: extra_cells}


# Chaikin smoothing, then dense 1-sample points with a small meander on
# flat ground.
func _smooth_path(coarse_path: PackedVector2Array, river_rules: Dictionary) -> PackedVector2Array:
	var smooth: PackedVector2Array = coarse_path

	for _round in range(3):
		var refined: PackedVector2Array = PackedVector2Array()
		refined.append(smooth[0])

		for k in range(smooth.size() - 1):
			refined.append(smooth[k] * 0.75 + smooth[k + 1] * 0.25)
			refined.append(smooth[k] * 0.25 + smooth[k + 1] * 0.75)

		refined.append(smooth[smooth.size() - 1])
		smooth = refined

	var dense: PackedVector2Array = PackedVector2Array()
	var travelled: float = 0.0
	var meander: float = float(river_rules["meander_m"]) / spacing_m
	var wavelength: float = float(river_rules["meander_wavelength_m"]) / spacing_m

	for k in range(smooth.size() - 1):
		var from: Vector2 = smooth[k]
		var to: Vector2 = smooth[k + 1]
		var length: float = from.distance_to(to)
		var steps: int = maxi(int(ceil(length)), 1)
		var side: Vector2 = Vector2(-(to - from).y, (to - from).x).normalized()

		for i in range(steps):
			var point: Vector2 = from.lerp(to, float(i) / float(steps))
			var column: int = clampi(int(round(point.x)), 0, samples - 1)
			var row: int = clampi(int(round(point.y)), 0, samples - 1)
			var flat: float = 1.0 - smoothstep(10.0, 60.0, heights[row * samples + column])
			dense.append(point + side * meander * flat * sin(travelled / wavelength * TAU))
			travelled += length / float(steps)

	dense.append(smooth[smooth.size() - 1])
	return dense


static func _heap_push(keys: PackedFloat32Array, nodes: PackedInt32Array, key: float, node: int) -> void:
	keys.append(key)
	nodes.append(node)
	var child: int = keys.size() - 1

	while child > 0:
		var parent: int = (child - 1) / 2

		if keys[parent] <= keys[child]:
			break

		var key_swap: float = keys[parent]
		keys[parent] = keys[child]
		keys[child] = key_swap
		var node_swap: int = nodes[parent]
		nodes[parent] = nodes[child]
		nodes[child] = node_swap
		child = parent


static func _heap_pop(keys: PackedFloat32Array, nodes: PackedInt32Array) -> Vector2:
	var top: Vector2 = Vector2(keys[0], float(nodes[0]))
	var last: int = keys.size() - 1
	keys[0] = keys[last]
	nodes[0] = nodes[last]
	keys.resize(last)
	nodes.resize(last)
	var parent: int = 0

	while true:
		var left: int = parent * 2 + 1
		var right: int = left + 1
		var smallest: int = parent

		if left < last and keys[left] < keys[smallest]:
			smallest = left

		if right < last and keys[right] < keys[smallest]:
			smallest = right

		if smallest == parent:
			break

		var key_swap: float = keys[parent]
		keys[parent] = keys[smallest]
		keys[smallest] = key_swap
		var node_swap: int = nodes[parent]
		nodes[parent] = nodes[smallest]
		nodes[smallest] = node_swap
		parent = smallest

	return top
