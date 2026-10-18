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

const WrapNoiseScript := preload("res://src/worldgen/tile/wrap_noise.gd")
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
var _route_clock: int = 0
var _source_surface_m: float = 0.0
var starter_path: PackedVector2Array = PackedVector2Array()   # sample coordinates, source to mouth

var _settings
var _rules: Dictionary = {}
var _legacy_rivers: bool = true
var _ocean: PackedByteArray = PackedByteArray()
var _origin_sx: int = 0       # world sample index of sample 0 (set by build)
var _origin_sz: int = 0


func setup(settings, rules: Dictionary) -> void:
	_settings = settings
	_rules = rules["water"]
	spacing_m = float(settings.map_spacing_m)


# `guides` are the world's rivers crossing this frame, as returned by
# RiverNetwork.guides_in (world meters). With guides, rivers are cut along
# them, so a river is the same in every tile it passes through. Without
# (null), rivers come from this tile's own drainage, as before.
func build(height_map, starter: Dictionary = {}, guides: Variant = null) -> void:
	_legacy_rivers = guides == null
	samples = height_map.samples
	_origin_sx = int(height_map.origin_sx)
	_origin_sz = int(height_map.origin_sz)
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
	var clock: int = Time.get_ticks_msec()
	_hydrology({})
	_log("pass 1 done (%d lakes)" % lakes.size(), clock)

	if bool(river_rules.get("enabled", false)) and not starter.is_empty():
		var source: int = _pick_source(starter, float(river_rules["source_min_height_m"]))
		_log("source picked: %d" % source, clock)

		if source >= 0:
			heights = original.duplicate()
			extra = _cut_starter_river(source, starter, river_rules)
			_log("starter river cut (%d path points)" % starter_path.size(), clock)

			if not extra.is_empty():
				_hydrology(extra)
				_log("pass 2 done", clock)
				var probes: PackedStringArray = PackedStringArray()

				for k in [0, starter_path.size() / 4, starter_path.size() / 2, starter_path.size() * 3 / 4, starter_path.size() - 1]:
					var point: Vector2 = starter_path[k]
					var at: int = clampi(int(round(point.y)), 0, samples - 1) * samples + clampi(int(round(point.x)), 0, samples - 1)
					probes.append("%d:flow %.0f cls %d h %.1f" % [k, flow[at], water_class[at], heights[at]])

				print("  water: starter river probes ", ", ".join(probes))
			else:
				heights = original.duplicate()
				_hydrology({})

	if not _legacy_rivers:
		var rivers: Array = []

		for guide in guides:
			rivers.append(_guide_to_samples(guide["points"], guide["areas"], bool(guide.get("source", false))))

		if starter_path.size() > 1:
			rivers.append(_starter_guide())

		_carve_guides(rivers)


static func _log(message: String, since_ms: int) -> void:
	print("  water: %s at +%d ms" % [message, Time.get_ticks_msec() - since_ms])


func _hydrology(extra: Dictionary) -> void:
	var total: int = samples * samples
	water_class.fill(0)
	water_surface.fill(0.0)
	flow.fill(0.0)
	lakes = []
	river_cells = 0
	filled_cells = 0
	var routed: PackedInt32Array = _routing_heights()
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

	_ocean = ocean

	if _legacy_rivers:
		_carve_rivers(level, parent, ocean)


# Heights in tenths of a meter with a little noise, so flat ground drains
# in gentle bends instead of straight lines.
func _routing_heights() -> PackedInt32Array:
	var total: int = samples * samples
	var offset_field: PackedFloat32Array = PackedFloat32Array()
	offset_field.resize(total)
	var index_octave: int = 0

	for octave in _rules["route_noise"]:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = SeedUtil.purpose_seed(_settings.master_seed, "tile_route", index_octave)
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.frequency = spacing_m / float(octave["wavelength_m"])
		var tile_samples_w: int = int(_settings.tile_size_m / _settings.map_spacing_m)
		var data: PackedByteArray = WrapNoiseScript.bytes(
			noise, _origin_sx, _origin_sz, samples, samples, _settings.min_tile * tile_samples_w, _settings.min_tile * tile_samples_w,
			_settings.tiles_x * tile_samples_w, _settings.tiles_z * tile_samples_w, int(ceil(4.0 * float(octave["wavelength_m"]) / spacing_m))
		)
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

		if area >= lake_area and float(deepest) / 10.0 >= lake_depth and compact \
				and surface_m >= float(_rules["lake_min_surface_m"]):
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


# ---------------------------------------------------------------- guide rivers

# A river from the world network in sample coordinates of this frame.
func _guide_to_samples(points: PackedVector2Array, areas_km2: PackedFloat32Array, source: bool = false) -> Dictionary:
	var converted: PackedVector2Array = PackedVector2Array()
	converted.resize(points.size())

	for k in range(points.size()):
		converted[k] = Vector2(points[k].x / spacing_m - float(_origin_sx), points[k].y / spacing_m - float(_origin_sz))

	return {"points": converted, "areas": areas_km2, "source": source}


# The designed starter river as a guide: its path, with the water it carries
# taken from the drainage of the second pass (never shrinking downstream).
func _starter_guide() -> Dictionary:
	var areas: PackedFloat32Array = PackedFloat32Array()
	var cell_km2: float = spacing_m * spacing_m / 1.0e6
	var carried: float = 0.0

	for point in starter_path:
		var at: int = clampi(int(round(point.y)), 0, samples - 1) * samples + clampi(int(round(point.x)), 0, samples - 1)
		carried = maxf(carried, flow[at])
		areas.append(carried * cell_km2)

	return {"points": starter_path, "areas": areas}


# Cuts every river along its guide. The bed under a point is the lowest
# (ground minus channel depth) over the last `bed_window_m` of river, so
# the bed never climbs over a hill and the same window is seen by the
# neighbor tile (the window must be shorter than the frame margin).
func _carve_guides(rivers: Array) -> void:
	var cell_km2: float = spacing_m * spacing_m / 1.0e6
	var width_base: float = float(_rules["river_width_base_m"])
	var width_scale: float = float(_rules["river_width_per_sqrt_km2"])
	var depth_base: float = float(_rules["river_depth_base_m"])
	var depth_scale: float = float(_rules["river_depth_per_width"])
	var slope: float = float(_rules["bank_slope"])
	var start_km2: float = float(_rules["river_start_km2"])
	var window_m: float = float(_rules.get("bed_window_m", 500.0))
	var taper_m: float = float(_rules.get("head_taper_m", 140.0))
	var taper_min: float = float(_rules.get("head_taper_min", 0.4))
	var pond_radius: float = float(_rules.get("head_pond_diameter_m", 30.0)) * 0.5
	var pond_depth: float = float(_rules.get("head_pond_depth_m", 10.0))
	var pond_back: float = float(_rules.get("head_pond_back_m", 50.0))
	var widen_from: float = float(_rules.get("fall_widen_from_slope", 0.15))
	var widen_rate: float = float(_rules.get("fall_widen_rate", 3.0))
	var widen_max: float = float(_rules.get("fall_widen_max", 2.5))
	var fall_slope: float = float(_rules.get("fall_slope", 0.30))
	var fall_min_cells: float = float(_rules.get("fall_min_cells", 1.6))
	var fall_min_drop: float = float(_rules.get("fall_min_drop_m", 5.0))
	var pool_depth: float = float(_rules.get("pool_depth_m", 2.5))
	var total: int = samples * samples
	var best_flow: PackedFloat32Array = PackedFloat32Array()
	best_flow.resize(total)
	var carved: PackedFloat32Array = heights.duplicate()
	var longest: float = 0.0
	river_cells = 0

	for river in rivers:
		var points: PackedVector2Array = river["points"]
		var areas: PackedFloat32Array = river["areas"]
		var count: int = points.size()

		if count < 2:
			continue

		var low_values: PackedFloat32Array = PackedFloat32Array()
		var depths: PackedFloat32Array = PackedFloat32Array()
		var widths: PackedFloat32Array = PackedFloat32Array()
		var usable: PackedByteArray = PackedByteArray()
		var beds: PackedFloat32Array = PackedFloat32Array()
		var is_source: bool = bool(river.get("source", false))
		var along: float = 0.0
		low_values.resize(count)
		beds.resize(count)
		beds.fill(NAN)
		depths.resize(count)
		widths.resize(count)
		usable.resize(count)

		for k in range(count):
			var point: Vector2 = points[k]
			var width: float = width_base + width_scale * sqrt(maxf(areas[k], start_km2))
			var depth: float = depth_base + depth_scale * width

			if k > 0:
				along += points[k].distance_to(points[k - 1]) * spacing_m

			if is_source and along < taper_m:
				# The brook grows out of its spring pond instead of starting full size.
				var grow: float = lerpf(taper_min, 1.0, along / taper_m)
				width *= grow
				depth *= grow

			widths[k] = width
			depths[k] = depth

			# Ground is only known inside the frame, and only on land or lakes
			# that are not already sea.
			if point.x < 0.0 or point.y < 0.0 or point.x > float(samples - 1) or point.y > float(samples - 1):
				continue

			var at: int = int(round(point.y)) * samples + int(round(point.x))

			if _ocean[at] == 1 or water_class[at] == LAKE:
				continue

			usable[k] = 1
			low_values[k] = _bilinear(heights, point) - depth

		# Lowest value over a trailing window, taken only over usable points.
		var step_m: float = 4.0

		if count > 1:
			step_m = maxf(points[0].distance_to(points[1]) * spacing_m, 0.5)

		var window: int = maxi(int(round(window_m / step_m)), 1)
		var deque: PackedInt32Array = PackedInt32Array()
		var head_at: int = 0
		var run_length: float = 0.0

		for k in range(count):
			if k > 0:
				run_length += points[k].distance_to(points[k - 1]) * spacing_m

			if usable[k] == 0:
				continue

			# Window by position along the river, not by index, so gaps do not matter.
			while head_at < deque.size() and k - deque[head_at] > window:
				head_at += 1

			while deque.size() > head_at and low_values[deque[deque.size() - 1]] >= low_values[k]:
				deque.remove_at(deque.size() - 1)

			deque.append(k)
			var bed: float = low_values[deque[head_at]]
			var strength: float = areas[k] / cell_km2

			# Water falling steeply spreads into a wider, shallower sheet.
			if k + 2 < count and usable[k + 2] == 1:
				var drop_slope: float = (low_values[k] - low_values[k + 2]) / (2.0 * step_m)
				var widen: float = 1.0 + clampf((drop_slope - widen_from) * widen_rate, 0.0, widen_max - 1.0)
				widths[k] *= widen

				# A fall must fill whole grid cells or the baked water breaks into holes.
				if drop_slope > widen_from:
					widths[k] = maxf(widths[k], spacing_m * fall_min_cells)

			beds[k] = bed
			river_cells += 1
			_stamp_at(carved, points[k], widths[k], depths[k], bed, slope, strength, best_flow)

		longest = maxf(longest, run_length)

		if is_source:
			# The spring pond sits back in the hill above the head (owner, 2026-10-18): a
			# bowl cut into the slope, as deep as it is told below its lowest lip, so it
			# holds water and spills over that lip toward the brook.
			var head_point: Vector2 = points[0]

			if usable[0] == 1:
				var uphill: Vector2 = Vector2(
					_bilinear(heights, head_point + Vector2(1.0, 0.0)) - _bilinear(heights, head_point - Vector2(1.0, 0.0)),
					_bilinear(heights, head_point + Vector2(0.0, 1.0)) - _bilinear(heights, head_point - Vector2(0.0, 1.0))
				)

				if uphill.length() > 0.001:
					var centre: Vector2 = head_point + uphill.normalized() * pond_back / spacing_m
					var margin: float = pond_radius / spacing_m + 3.0

					if centre.x > margin and centre.y > margin and centre.x < float(samples - 1) - margin and centre.y < float(samples - 1) - margin:
						var rim_low: float = INF

						for r in range(16):
							var a_r: float = TAU * float(r) / 16.0
							rim_low = minf(rim_low, _bilinear(heights, centre + Vector2(cos(a_r), sin(a_r)) * pond_radius / spacing_m))

						_stamp_pond(carved, centre, pond_radius, rim_low - pond_depth, rim_low, areas[0] / cell_km2, best_flow)

		# A plunge pool at the foot of every steep drop (waterfall or cascade):
		# the water scours a basin where it lands.
		var run_start: int = -1

		for k in range(count - 2):
			if is_nan(beds[k]) or is_nan(beds[k + 2]):
				run_start = -1
				continue

			var steep: bool = (beds[k] - beds[k + 2]) / (2.0 * step_m) > fall_slope

			if steep and run_start < 0:
				run_start = k
			elif not steep and run_start >= 0:
				var drop: float = beds[run_start] - beds[k]

				if drop >= fall_min_drop:
					var pool_width: float = clampf(widths[k] * 1.8 + 6.0, 10.0, 26.0)
					_stamp_at(carved, points[k], pool_width, pool_depth, beds[k] - pool_depth * 0.9, slope, areas[k] / cell_km2, best_flow)

				run_start = -1

	heights = carved
	longest_river_m = longest


# Bilinear height at a position in sample coordinates (inside the frame).
func _bilinear(field: PackedFloat32Array, point: Vector2) -> float:
	var x0: int = clampi(int(floor(point.x)), 0, samples - 2)
	var z0: int = clampi(int(floor(point.y)), 0, samples - 2)
	var tx: float = clampf(point.x - float(x0), 0.0, 1.0)
	var tz: float = clampf(point.y - float(z0), 0.0, 1.0)
	var a: float = field[z0 * samples + x0]
	var b: float = field[z0 * samples + x0 + 1]
	var c: float = field[(z0 + 1) * samples + x0]
	var d: float = field[(z0 + 1) * samples + x0 + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


# Like _stamp, centered on any position (sample coordinates). The strongest
# river wins each cell's water class, surface and flow.
func _stamp_at(
	carved: PackedFloat32Array, center: Vector2, width: float, depth: float, bed: float, slope: float,
	strength: float, best_flow: PackedFloat32Array, bowl: float = 0.0
) -> void:
	var radius_m: float = width * 0.5 + (depth + 1.0) / slope
	var radius_cells: float = radius_m / spacing_m
	var first_x: int = maxi(int(ceil(center.x - radius_cells)), 0)
	var last_x: int = mini(int(floor(center.x + radius_cells)), samples - 1)
	var first_z: int = maxi(int(ceil(center.y - radius_cells)), 0)
	var last_z: int = mini(int(floor(center.y + radius_cells)), samples - 1)

	for nr in range(first_z, last_z + 1):
		var dz: float = float(nr) - center.y

		for nc in range(first_x, last_x + 1):
			var dx: float = float(nc) - center.x
			var distance: float = sqrt(dx * dx + dz * dz) * spacing_m

			if distance > radius_m:
				continue

			var target: int = nr * samples + nc

			if _ocean[target] == 1:
				continue

			var floor_height: float = bed + maxf(distance - width * 0.5, 0.0) * slope

			# A pond is a bowl: deepest in the middle, rising to the water level at its edge.
			if bowl > 0.0 and distance < width * 0.5:
				floor_height = bed + bowl * pow(distance / (width * 0.5), 2.0)

			carved[target] = minf(carved[target], floor_height)

			if distance <= width * 0.5 and strength >= best_flow[target]:
				best_flow[target] = strength
				flow[target] = strength
				water_class[target] = RIVER
				water_surface[target] = bed + 0.75 * depth


# A bowl-shaped spring pond: the floor is `bottom` in the middle and rises to the lowest
# lip (`rim_low`) at the edge, and the water stands just under that lip.
func _stamp_pond(
	carved: PackedFloat32Array, center: Vector2, radius_m: float, bottom: float, rim_low: float,
	strength: float, best_flow: PackedFloat32Array
) -> void:
	var reach_cells: float = radius_m / spacing_m
	var surface: float = rim_low - 1.0

	for nr in range(maxi(int(ceil(center.y - reach_cells)), 0), mini(int(floor(center.y + reach_cells)), samples - 1) + 1):
		for nc in range(maxi(int(ceil(center.x - reach_cells)), 0), mini(int(floor(center.x + reach_cells)), samples - 1) + 1):
			var distance: float = sqrt(pow(float(nc) - center.x, 2.0) + pow(float(nr) - center.y, 2.0)) * spacing_m

			if distance > radius_m:
				continue

			var target: int = nr * samples + nc

			if _ocean[target] == 1:
				continue

			var floor_height: float = bottom + (rim_low - bottom) * pow(distance / radius_m, 2.0)
			carved[target] = minf(carved[target], floor_height)

			if floor_height < surface and strength >= best_flow[target]:
				best_flow[target] = strength
				flow[target] = strength
				water_class[target] = RIVER
				water_surface[target] = surface


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


# The surface point of the highland lake nearest the bay head, so the river
# starts on the bay side of the mountains.
func _pick_source(starter: Dictionary, min_height: float) -> int:
	var head: Vector2 = _bay_head_samples(starter)
	var best: int = -1
	var best_distance: float = INF

	for lake in lakes:
		if float(lake["surface_m"]) < min_height:
			continue

		for member in lake["members"]:
			var distance: float = Vector2(float(member % samples), float(member / samples)).distance_to(head)

			if distance < best_distance:
				best_distance = distance
				best = member
				_source_surface_m = float(lake["surface_m"])

	return best


func _bay_head_samples(starter: Dictionary) -> Vector2:
	var center: Vector2 = starter["bay_center"]
	var direction: Vector2 = starter["beach_dir"]
	var radius: float = float(starter["bay_radius_m"])
	var head_m: Vector2 = center - direction * radius * 0.95
	return Vector2(
		head_m.x / spacing_m - float(_origin_sx),
		head_m.y / spacing_m - float(_origin_sz)
	)


# Finds the easiest valley route from the source to the bay head, cuts a
# guide channel along it (bed never rises downstream) and returns the extra
# water to feed in at the source: {cell index: extra catchment cells}.
func _cut_starter_river(source: int, starter: Dictionary, river_rules: Dictionary) -> Dictionary:
	var step: int = maxi(int(round(float(river_rules["route_cell_m"]) / spacing_m)), 1)
	var coarse: int = (samples - 1) / step + 1
	var climb_cost: float = float(river_rules["climb_cost"])
	var head: Vector2 = _bay_head_samples(starter)
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
	_route_clock = Time.get_ticks_msec()

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

	_log("route search finished", _route_clock)

	if came[goal_node] == -1 and goal_node != start_node:
		return {}

	var coarse_path: PackedVector2Array = PackedVector2Array()
	var walker: int = goal_node

	while walker != -1:
		coarse_path.append(Vector2(float((walker % coarse) * step), float((walker / coarse) * step)))
		walker = came[walker]

	coarse_path.reverse()
	var path: PackedVector2Array = _smooth_path(coarse_path, river_rules)
	# Start exactly at the lake's edge cell so the lake has to spill into the channel.
	path.insert(0, Vector2(float(source % samples), float(source / samples)))
	starter_path = path

	# Guide channel: the bed never rises downstream and stays under the ground.
	var guide_width: float = float(river_rules["guide_width_m"])
	var guide_depth: float = float(river_rules["guide_depth_m"])
	var slope: float = float(_rules["bank_slope"])
	var mouth: float = float(river_rules["mouth_height_m"])
	var bed: float = _source_surface_m - guide_depth
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
