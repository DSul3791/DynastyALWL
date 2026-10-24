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
const TileDrainageScript := preload("res://src/worldgen/tile/tile_drainage.gd")

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
var max_bed_rise_m: float = 0.0       # largest climb of any river bed toward the sea (0: none)
var ponds_made: int = 0               # head ponds stamped
var largest_pond_m: float = 0.0       # widest head pond stamped (meters across)
var _guard: PackedFloat32Array = PackedFloat32Array()   # per sample: no river or brook cuts below this (pond shores)
var _joined_heads: Dictionary = {}     # Vector2i(pond, head) whose brook is cut as the start of its river
var _world_ponds: Array = []          # head ponds from the world river network (RiverNetwork.ponds_in), world meters
var ponds_moved: int = 0              # of those, ponds moved up off a steep head onto flat ground
var heads_straightened: int = 0       # steep river heads re-routed straight down the slope
var pond_cut_max_m: float = 0.0       # deepest cut a head pond made into the ground
var _route_clock: int = 0
var _source_surface_m: float = 0.0
var starter_path: PackedVector2Array = PackedVector2Array()   # sample coordinates, source to mouth

var _settings
var _rules: Dictionary = {}
var _legacy_rivers: bool = true
var _ocean: PackedByteArray = PackedByteArray()
var _chute_feet: Array = []   # per river: where each clean chute lands ({point, bed, width}), for its plunge pool
var world_network = null      # RiverNetwork: catchments beyond the frame (drainage mode seeds the frame edge with them)
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
func build(height_map, starter: Dictionary = {}, guides: Variant = null, world_ponds: Array = []) -> void:
	_world_ponds = world_ponds
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
	if bool(_rules.get("drainage_mode", false)):
		var summary: Dictionary = TileDrainageScript.apply(self, _rules.get("drainage", {}))
		print("  water: drainage mode, %d lakes, %d river cells in %d ms" % [summary["lakes"], summary["river_cells"], summary["ms"]])
		return

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

				@warning_ignore("integer_division")
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
		print("  water: %d head ponds (%d moved up to flat ground), %d steep heads straightened, widest %.0f m, deepest pond cut %.1f m, largest river bed climb %.2f m" % [ponds_made, ponds_moved, heads_straightened, largest_pond_m, pond_cut_max_m, max_bed_rise_m])


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
		@warning_ignore("integer_division")
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
		@warning_ignore("integer_division")
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
			@warning_ignore("integer_division")
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
			@warning_ignore("integer_division")
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
		var depth: float = _stream_depth(depth_base + depth_scale * width, width)
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
	var min_fall: float = float(_rules.get("river_min_fall", 0.001))
	var taper_m: float = float(_rules.get("head_taper_m", 140.0))
	var taper_min: float = float(_rules.get("head_taper_min", 0.4))
	var pond_radius: float = float(_rules.get("head_pond_diameter_m", 30.0)) * 0.5
	var pond_radius_max: float = maxf(float(_rules.get("head_pond_diameter_max_m", 70.0)) * 0.5, pond_radius)
	var pond_depth: float = float(_rules.get("head_pond_depth_m", 10.0))
	var pond_back: float = float(_rules.get("head_pond_back_m", 50.0))
	var max_rim_range: float = float(_rules.get("head_pond_max_rim_range_m", 15.0))
	var wall_fade: float = float(_rules.get("head_pond_wall_fade_m", 60.0))
	var pond_search_m: float = float(_rules.get("head_pond_search_m", 1200.0))
	var pond_shore: float = float(_rules.get("head_pond_shore_m", 12.0))
	var pond_setback: float = float(_rules.get("head_pond_setback_m", 60.0))
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

	# Owner (2026-10-19): every river starts at its head pond, placed for the whole world
	# (the same in every tile that touches it), on a plateau built where the land has none.
	# Made first, so the rivers and brooks then cut their way out of it.
	for pond in _world_ponds:
		var centre: Vector2 = Vector2(pond["centre"]) / spacing_m - Vector2(float(_origin_sx), float(_origin_sz))
		var level: float = float(pond["level"])
		var radius_here: float = float(pond.get("radius", pond_radius))
		ponds_made += 1
		largest_pond_m = maxf(largest_pond_m, radius_here * 2.0)
		_bench(carved, centre, radius_here + pond_shore, level, wall_fade)
		_stamp_pond(carved, centre, radius_here, level - pond_depth, level, start_km2 / cell_km2, best_flow, max_rim_range + 4.0, wall_fade, pond_shore)

	# The land with its pond benches, before any river or brook is cut (brooks follow it,
	# pond rims are restored no higher than it).
	var bench_land: PackedFloat32Array = carved.duplicate()

	# Owner (2026-10-20): the ponds are made first and the rivers cut last, but a river may
	# never reshape a pond. Across each pond's shore the ground is guarded: rivers and
	# brooks cut through it no lower than just under the pond's lip (the outlet notch), so
	# the pond keeps its own outline and holds its water.
	_guard = PackedFloat32Array()
	_guard.resize(samples * samples)
	_guard.fill(-INF)

	for pond in _world_ponds:
		var centre: Vector2 = Vector2(pond["centre"]) / spacing_m - Vector2(float(_origin_sx), float(_origin_sz))
		_guard_shore(centre, float(pond.get("radius", pond_radius)), float(pond["level"]) - float(_rules.get("head_pond_outlet_drop_m", 3.0)), pond_shore)

	_joined_heads = {}
	var outlets: Array = []              # [pond centre, radius m, first river point, width m] of rivers from a pond
	var ponds_placed: Array = []          # [centre, rim height] of every head pond so far
	river_cells = 0

	for river in rivers:
		var points: PackedVector2Array = river["points"]
		var areas: PackedFloat32Array = river["areas"]

		# Owner (2026-10-19): a brook coming down a mountainside runs straight down it, not
		# sideways across the face the way the coarse world river path goes.
		if bool(river.get("source", false)):
			var straight: Array = _straighten_head(points, areas)
			points = straight[0]
			areas = straight[1]

		# Owner (2026-10-20, Dave): "place the ponds first, then place the rivers and start
		# them from the middle of the ponds." A river with a world head pond runs as one path
		# from the pond's middle along its brook's line to the head and on, so it is cut as
		# one channel with one bed that leaves the pond at its sill, instead of a brook and a
		# river cut separately that met in a jumble of cuts and a pool beside the pond.
		var from_pond: Vector2 = Vector2(INF, INF)
		var from_pond_radius: float = 0.0

		if bool(river.get("source", false)) and points.size() > 0:
			var joined: Array = _join_pond(points[0])

			if not joined.is_empty():
				from_pond = joined[0]
				from_pond_radius = joined[1]
				var lead: PackedVector2Array = joined[2]
				var lead_areas: PackedFloat32Array = PackedFloat32Array()
				lead_areas.resize(lead.size())
				lead_areas.fill(areas[0])
				lead.append_array(points)
				lead_areas.append_array(areas)
				points = lead
				areas = lead_areas
				var straightened: Array = _straight_to_lip(points, areas, from_pond, from_pond_radius, float(joined[3]), bench_land)
				points = straightened[0]
				areas = straightened[1]

		var count: int = points.size()

		if count < 2:
			continue

		var low_values: PackedFloat32Array = PackedFloat32Array()
		var depths: PackedFloat32Array = PackedFloat32Array()
		var widths: PackedFloat32Array = PackedFloat32Array()
		var usable: PackedByteArray = PackedByteArray()
		var beds: PackedFloat32Array = PackedFloat32Array()
		var banks: PackedFloat32Array = PackedFloat32Array()
		var is_source: bool = bool(river.get("source", false))
		var along: float = 0.0
		# Owner (2026-10-19): the stream out of a bigger pond starts bigger (a lake's outlet
		# is a stream, a small pond's is a brook).
		var pond_size: float = clampf((float(river.get("pond_radius", pond_radius)) - pond_radius) / maxf(pond_radius_max - pond_radius, 1.0), 0.0, 1.0)
		var taper_here: float = lerpf(taper_min, 1.0, pond_size)
		# Owner (2026-10-20): the river out of a pond is sized for the pond's spring flow
		# (bigger pond, more water), easing back to the catchment's size downstream.
		var pond_flow: float = _pond_flow(float(river.get("pond_radius", pond_radius))) if is_source else 1.0
		low_values.resize(count)
		beds.resize(count)
		beds.fill(NAN)
		banks.resize(count)
		banks.fill(slope)
		depths.resize(count)
		widths.resize(count)
		usable.resize(count)

		for k in range(count):
			var point: Vector2 = points[k]
			var width: float = width_base + width_scale * sqrt(maxf(areas[k], start_km2))
			var carry: float = lerpf(pond_flow, 1.0, clampf(along / (maxf(taper_m, 1.0) * 3.0), 0.0, 1.0))
			width *= sqrt(carry)
			var depth: float = _stream_depth(depth_base + depth_scale * width, width, carry)

			if k > 0:
				along += points[k].distance_to(points[k - 1]) * spacing_m

			if is_source and along < taper_m:
				# The brook grows out of its spring pond instead of starting full size.
				var grow: float = lerpf(taper_here, 1.0, along / taper_m)
				width *= grow
				depth *= grow

			# Dave (2026-10-21, build 483): at the x10 spring flow a channel one or two cells wide piled the water up
			# 2 m above its own banks. A river is never narrower than river_min_width_m (3 cells).
			width = maxf(width, float(_rules.get("river_min_width_m", 0.0)))
			widths[k] = width
			depths[k] = depth

			# Ground is only known inside the frame, and only on land or lakes
			# that are not already sea.
			if point.x < 0.0 or point.y < 0.0 or point.x > float(samples - 1) or point.y > float(samples - 1):
				continue

			var at: int = int(round(point.y)) * samples + int(round(point.x))

			if _ocean[at] == 1 or water_class[at] == LAKE:
				continue

			# Inside its pond the bowl is deeper than the river: the bed starts at the pond's edge.
			if from_pond.x != INF and point.distance_to(from_pond) * spacing_m < from_pond_radius:
				continue

			usable[k] = 1
			# Measured on the land with its pond benches (owner report 2026-10-20: a river
			# measured on the ground under a bench cut a slot back through the bench, so the
			# pond's stream ran in a trench instead of over the edge).
			low_values[k] = _bilinear(bench_land, point) - depth

		# Lowest value over a trailing window, taken only over usable points.
		var step_m: float = 4.0

		if count > 1:
			step_m = maxf(points[0].distance_to(points[1]) * spacing_m, 0.5)

		var window: int = maxi(int(round(window_m / step_m)), 1)
		var deque: PackedInt32Array = PackedInt32Array()
		var head_at: int = 0
		var run_length: float = 0.0
		var last_bed: float = INF
		var last_along: float = 0.0
		var lip_drop: float = float(_rules.get("brook_lip_drop_m", 5.0))
		var held: float = INF             # the bed at the lip of the drop the river is going over

		# Owner (2026-10-20, Dave): "they should run right into the water so they look like one
		# thing." A river that ends in the sea has an estuary: over its last estuary_m the bed
		# sinks to estuary_depth_m under sea level and the channel widens by estuary_widen, so
		# the sea comes up the channel and the water meets it at one level, with no step.
		var estuary_m: float = float(_rules.get("estuary_m", 160.0))
		var estuary_end: float = -1.0     # distance along the river where its usable stretch meets the sea
		var cumulative: PackedFloat32Array = PackedFloat32Array()
		cumulative.resize(count)
		var estuary_here: PackedFloat32Array = PackedFloat32Array()
		estuary_here.resize(count)

		for k in range(1, count):
			cumulative[k] = cumulative[k - 1] + points[k].distance_to(points[k - 1]) * spacing_m

		for k in range(count - 1, -1, -1):
			if usable[k] == 1:
				if k + 1 < count:
					var next: Vector2 = points[k + 1]
					var next_at: int = clampi(int(round(next.y)), 0, samples - 1) * samples + clampi(int(round(next.x)), 0, samples - 1)

					if _ocean[next_at] == 1:
						estuary_end = cumulative[k]

				break

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

			# Owner (2026-10-18): a river only ever runs downhill, falling at least min_fall
			# per meter from its source to the sea. Where the ground rises the river cuts
			# through it instead of climbing.
			if last_bed < INF:
				bed = minf(bed, last_bed - min_fall * (run_length - last_along))
				max_bed_rise_m = maxf(max_bed_rise_m, bed - last_bed)

			var to_sea: float = (estuary_end - cumulative[k]) if estuary_end >= 0.0 else INF
			var estuary: float = clampf(1.0 - to_sea / maxf(estuary_m, 1.0), 0.0, 1.0)

			if estuary > 0.0:
				var sunk: float = -float(_rules.get("estuary_depth_m", 1.5))
				var bar: float = maxf(1.0 - absf(to_sea - float(_rules.get("estuary_bar_at_m", 60.0))) / maxf(float(_rules.get("estuary_bar_half_m", 30.0)), 1.0), 0.0)
				# Tyler (2026-10-21): a submerged bar a little inside the mouth, the channel deeper beyond it.
				sunk = lerpf(sunk, float(_rules.get("estuary_bar_bed_m", -0.6)), bar)
				# Only where the river already runs near sea level: a river that meets the sea over a
				# cliff or a hill is not drowned (it would cut a deep slot through the headland).
				estuary *= clampf(1.0 - (bed - float(_rules.get("estuary_max_bed_m", 4.0))) / 6.0, 0.0, 1.0)
				bed = minf(bed, lerpf(bed, sunk, estuary))
				widths[k] *= lerpf(1.0, float(_rules.get("estuary_widen", 1.6)), estuary)
				estuary_here[k] = estuary

			last_bed = bed
			last_along = run_length

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

			# Owner (2026-10-19): where the river runs down a steep face its banks are at least
			# as steep as the river itself, so the bank of a point lower down never cuts a notch
			# into the face above it.
			var bank_here: float = slope
			var up_k: int = maxi(k - 3, 0)
			var down_k: int = mini(k + 3, count - 1)

			if usable[up_k] == 1 and usable[down_k] == 1 and down_k > up_k:
				var face: float = (low_values[up_k] - low_values[down_k]) / (float(down_k - up_k) * step_m)

				# Owner report (2026-10-20): a stream leaving a pond on a cliff top ran in a slot cut
				# into the top instead of going over the edge, because the face measured over
				# six steps was gentler than the cliff itself. The steepest single step counts too.
				for near_k in range(maxi(k - 1, 0), mini(k + 1, count - 1)):
					if usable[near_k] == 1 and usable[near_k + 1] == 1:
						face = maxf(face, (low_values[near_k] - low_values[near_k + 1]) / step_m)

				bank_here = maxf(slope, face * 1.25)

			# Gentle banks (estuary_bank, 1 in 8) where the river widens into the sea.
			bank_here = lerpf(bank_here, minf(bank_here, float(_rules.get("estuary_bank", 0.125))), estuary_here[k])
			banks[k] = bank_here

		# Owner (2026-10-21, Dave): "we will have to fix the generator to make waterfalls flat
		# and straight down until they hit the ground, and if there are cascading waterfalls it
		# will require more than one." Steep stretches of bed become a staircase of flat treads
		# and one-sample vertical faces (the water is drawn from the sim, no ribbon meshes).
		_chute_feet = []
		var terraced: PackedByteArray = _terrace(points, usable, cumulative, beds, widths, banks)



		for k in range(count):
			if usable[k] == 0:
				continue

			var bed: float = beds[k]
			var strength: float = areas[k] / cell_km2
			var bank_here: float = banks[k]

			# Owner (2026-10-20): a river stays cut to its full depth right to the edge of a ledge
			# and pours over it; owner report (build 232/257): the river cut a chute down pond B's
			# cliff from a rounded lip, the water spread there to a few cm and the fall started
			# halfway down. From the lip (the land drops lip_drop within two steps) the bed holds
			# the lip's height while the land keeps dropping: only ground above it is cut, so the
			# face stands as it is and the water leaves the channel over a sharp edge.
			var drop_ahead: bool = k + 2 < count and usable[k + 2] == 1 and low_values[k] - low_values[k + 2] > lip_drop
			var drop_behind: bool = k >= 2 and usable[k - 2] == 1 and low_values[k - 2] - low_values[k] > lip_drop

			if (drop_ahead or drop_behind) and terraced[k] == 0:
				if held == INF:
					held = bed

				_stamp_at(carved, points[k], widths[k], depths[k], maxf(bed, held), bank_here, strength, best_flow)
			else:
				held = INF
				_stamp_at(carved, points[k], widths[k], depths[k], bed, bank_here, strength, best_flow)

		longest = maxf(longest, run_length)

		if from_pond.x != INF:
			for k in range(count):
				if usable[k] == 1:
					outlets.append([from_pond, from_pond_radius, points[k], widths[k]])
					break

		if is_source:
			# The spring pond sits back in the hill above the head (owner, 2026-10-18): a
			# bowl cut into the slope, as deep as it is told below its lowest lip, so it
			# holds water and spills over that lip toward the brook.
			var head_point: Vector2 = points[0]

			var keep_out: float = _pond_keep_out() + 4.0
			var head_clear: bool = head_point.x > keep_out and head_point.y > keep_out and head_point.x < float(samples - 1) - keep_out and head_point.y < float(samples - 1) - keep_out

			if usable[0] == 1 and head_clear and _world_ponds.is_empty():
				var uphill: Vector2 = Vector2(
					_bilinear(heights, head_point + Vector2(1.0, 0.0)) - _bilinear(heights, head_point - Vector2(1.0, 0.0)),
					_bilinear(heights, head_point + Vector2(0.0, 1.0)) - _bilinear(heights, head_point - Vector2(0.0, 1.0))
				)

				if uphill.length() > 0.001:
					var centre: Vector2 = head_point + uphill.normalized() * pond_back / spacing_m
					var fit: Dictionary = _pond_fit(carved, centre, pond_radius, wall_fade, max_rim_range, pond_shore)

					# Owner (2026-10-19): with no flat ground just above the head (a steep mountain
					# face), the pond goes up on the first flat ground above it (a plateau or the top
					# of the rise) and a straight brook runs from it down to the head.
					var climbed: float = 0.0

					while fit.is_empty() and climbed < pond_search_m:
						var rise: Vector2 = _gradient(heights, centre, 4.0)

						if rise.length() < 0.002:
							break

						centre += rise.normalized() * 3.0
						climbed += 3.0 * spacing_m
						fit = _pond_fit(carved, centre, pond_radius, wall_fade, max_rim_range, pond_shore)

					# Owner (2026-10-19): the pond sits back from the edge of the flat ground, so
					# its stream crosses the flat before it drops: move it on, away from the head,
					# while it still fits, up to pond_setback.
					if not fit.is_empty():
						var away: Vector2 = (centre - head_point).normalized()
						var moved_m: float = 0.0

						while moved_m < pond_setback:
							var further: Vector2 = centre + away
							var fit_further: Dictionary = _pond_fit(carved, further, pond_radius, wall_fade, max_rim_range, pond_shore)

							if fit_further.is_empty():
								break

							centre = further
							fit = fit_further
							moved_m += spacing_m

					if not fit.is_empty():
						var radius_here: float = fit["radius"]
						# Owner (2026-10-19): the pond sits on a small flat bench with a shore, the land
						# sloping gently away from it, so it never looks like a crater in a hillside.
						var rim_low: float = fit["bench"]
						var shared: bool = false

						# Two heads close together share one pond (no overlapping ponds).
						for other in ponds_placed:
							if centre.distance_to(other[0]) * spacing_m < 2.0 * radius_here + pond_shore:
								centre = other[0]
								rim_low = other[1]
								shared = true
								break

						if not shared:
							ponds_placed.append([centre, rim_low, radius_here])
							_bench(carved, centre, radius_here + pond_shore, rim_low, wall_fade)
							ponds_made += 1
							ponds_moved += 1 if climbed > 0.0 else 0
							_stamp_pond(carved, centre, radius_here, rim_low - pond_depth, rim_low, areas[0] / cell_km2, best_flow, max_rim_range + 4.0, wall_fade, pond_shore)

						# The brook is cut last: where it leaves the pond is the pond's one low lip.
						if centre.distance_to(head_point) * spacing_m > radius_here:
							_cut_brook(carved, centre, radius_here, rim_low, head_point, beds[0], widths[0], depths[0], min_fall, slope, areas[0] / cell_km2, best_flow)

		# A plunge pool at the foot of every clean chute: the water scours a basin where it lands.
		for foot in _chute_feet:
			# Tyler: pool depth 0.3 to 0.5 of the drop (capped at 4 m), about as wide as the drop is high.
			var chute_pool: float = clampf(float(foot["height"]), float(foot["width"]) * 1.8 + 6.0, 40.0)
			var chute_depth: float = clampf(float(foot["height"]) * 0.4, pool_depth, 4.0)
			_stamp_at(carved, foot["point"], chute_pool, chute_depth, float(foot["bed"]) - chute_depth * 0.9, float(_rules.get("terrace_bank", 2.0)), areas[0] / cell_km2, best_flow)
			_wash_foot(carved, foot["point"], chute_pool * 0.5 + float(_rules.get("fall_wash_m", 24.0)))

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

				# A terraced step has its own flat tread below the face: no pool basin there (its banks
				# reach back up the face and cut it into a slope).
				var staircase: bool = false

				for near in range(maxi(run_start - 2, 0), mini(k + 4, count)):
					staircase = staircase or terraced[near] == 1

				if drop >= fall_min_drop and not staircase and not bool(_rules.get("terrace_single_chute", false)):
					var pool_width: float = clampf(widths[k] * 1.8 + 6.0, 10.0, 26.0)
					_stamp_at(carved, points[k], pool_width, pool_depth, beds[k] - pool_depth * 0.9, slope, areas[k] / cell_km2, best_flow)
					_wash_foot(carved, points[k], pool_width * 0.5 + float(_rules.get("fall_wash_m", 24.0)))

				run_start = -1

	# The brooks from the head ponds (made before the rivers, below) down to their heads.
	for pond in _world_ponds:
		var centre: Vector2 = Vector2(pond["centre"]) / spacing_m - Vector2(float(_origin_sx), float(_origin_sz))
		var heads: Array = pond["heads"]
		var head_levels: Array = pond["head_levels"]
		var brook_width: float = width_base + width_scale * sqrt(start_km2)
		var brook_depth: float = depth_base + depth_scale * brook_width

		var paths: Array = pond["paths"]
		var brook_size: float = clampf((float(pond.get("radius", pond_radius)) - pond_radius) / maxf(pond_radius_max - pond_radius, 1.0), 0.0, 1.0)
		var brook_scale: float = lerpf(maxf(taper_min, 0.6), 1.0, brook_size)
		# Owner (2026-10-20): a pond's spring flow grows with its size (water_settler.flow_factor).
		var pond_flow: float = _pond_flow(float(pond.get("radius", pond_radius)))
		brook_width *= sqrt(pond_flow)
		brook_depth = _stream_depth(depth_base + depth_scale * brook_width, brook_width * brook_scale, pond_flow)

		for h in range(heads.size()):
			# Cut with its river (_join_pond).
			if _joined_heads.has(Vector2i(_world_ponds.find(pond), h)):
				continue

			var path: PackedVector2Array = PackedVector2Array()

			for point in paths[h]:
				path.append(Vector2(point) / spacing_m - Vector2(float(_origin_sx), float(_origin_sz)))

			_cut_brook_path(carved, bench_land, centre, float(pond.get("radius", pond_radius)), float(pond["level"]), path, float(head_levels[h]) - brook_depth, brook_width * brook_scale, brook_depth, slope, start_km2 / cell_km2, best_flow)

	for outlet in outlets:
		_spillway(carved, outlet[0], outlet[1], outlet[2], outlet[3])

	# Owner report (2026-10-20): gorges end in odd protruding edges: knobs and spurs of the
	# old ground left standing between the stamps of the bed and the banks. On cut ground
	# beside the water a spur is worn down to the average of its neighbours, never raised,
	# so the river and the walls stay as cut. Done before the pond rims are restored.
	for pass_n in range(2):
		var before: PackedFloat32Array = carved.duplicate()

		for nr in range(1, samples - 1):
			for nc in range(1, samples - 1):
				var k: int = nr * samples + nc

				if water_class[k] != 0 or _ocean[k] == 1 or _guard[k] > -INF:
					continue

				var sum_h: float = 0.0
				var next_to_cut: bool = false

				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var n: int = k + dz * samples + dx
						sum_h += before[n]
						next_to_cut = next_to_cut or before[n] < heights[n] - 3.0

				if next_to_cut:
					carved[k] = minf(before[k], sum_h / 9.0)

	# Owner report (2026-10-20, an empty head pond): the rivers are cut after their ponds,
	# and a river bed passing by (or leaving at the head's depth) cut the pond's rim down to
	# its floor, so it drained. The shore ring is raised back to just under the lip, the
	# brook's own starting bed, so every way out leaves at that height.
	for placed in ponds_placed:
		_seal_pond_rim(carved, PackedFloat32Array(), placed[0], placed[2], placed[1] - 1.5, pond_shore)

	heights = carved
	longest_river_m = longest


# Marks a pond's shore (from its edge out across the shore) so no cut goes below `lip` at
# the water's edge, and below a gentle fall from there outward: a river leaving the pond
# starts at the pond's sill and runs smoothly down from it, never behind a ridge.
func _guard_shore(centre: Vector2, radius_m: float, lip: float, shore_m: float) -> void:
	var fall: float = float(_rules.get("head_pond_outlet_fall", 0.25))
	var reach_cells: float = (radius_m + shore_m) / spacing_m + 1.0

	for nr in range(maxi(int(ceil(centre.y - reach_cells)), 0), mini(int(floor(centre.y + reach_cells)), samples - 1) + 1):
		for nc in range(maxi(int(ceil(centre.x - reach_cells)), 0), mini(int(floor(centre.x + reach_cells)), samples - 1) + 1):
			var distance: float = Vector2(float(nc), float(nr)).distance_to(centre) * spacing_m

			if distance >= radius_m and distance <= radius_m + shore_m:
				var k: int = nr * samples + nc
				_guard[k] = maxf(_guard[k], lip - (distance - radius_m) * fall)


# Raises the ground from a pond's edge out across its shore to at least `lip`, but never
# above the land before the rivers were cut (`land`): ground past the edge of the pond's
# flat, over a cliff, is left alone instead of being built up into a wall (owner report
# 2026-10-20: green fingers standing up around the top of a waterfall).
func _seal_pond_rim(carved: PackedFloat32Array, land: PackedFloat32Array, centre: Vector2, radius_m: float, lip: float, shore_m: float) -> void:
	var reach_cells: float = (radius_m + shore_m) / spacing_m + 1.0

	for nr in range(maxi(int(ceil(centre.y - reach_cells)), 0), mini(int(floor(centre.y + reach_cells)), samples - 1) + 1):
		for nc in range(maxi(int(ceil(centre.x - reach_cells)), 0), mini(int(floor(centre.x + reach_cells)), samples - 1) + 1):
			var distance: float = Vector2(float(nc), float(nr)).distance_to(centre) * spacing_m

			if distance >= radius_m and distance <= radius_m + shore_m and _ocean[nr * samples + nc] != 1:
				var k: int = nr * samples + nc
				carved[k] = maxf(carved[k], lip if land.is_empty() else minf(lip, land[k]))


# Where a head pond fits around `centre` (sample coordinates): a pond whose rim varies by at most max_rim_range on the natural ground
# (owner, 2026-10-18/19: ponds sit on flat ground, never cut deep into a hillside), as
# {"radius", "bench"} (bench: the height of the flat ground the pond is set in, the middle
# of its rim), or empty when none fits.
func _pond_fit(_carved: PackedFloat32Array, centre: Vector2, pond_radius: float, wall_fade: float, max_rim_range: float, shore_m: float) -> Dictionary:
	for scale in [1.0]:
		var radius_here: float = pond_radius * scale
		# Kept clear of the strip a neighbor tile also bakes (see _pond_keep_out), so a pond is
		# made by exactly one tile and the edges still match.
		var margin: float = (radius_here + shore_m + 4.0 * wall_fade) / spacing_m + 3.0 + _pond_keep_out()

		if centre.x <= margin or centre.y <= margin or centre.x >= float(samples - 1) - margin or centre.y >= float(samples - 1) - margin:
			continue

		var natural_low: float = INF
		var natural_high: float = -INF
		var rim: Array = []

		for r in range(16):
			var on_rim: Vector2 = centre + Vector2(cos(TAU * float(r) / 16.0), sin(TAU * float(r) / 16.0)) * radius_here / spacing_m
			var natural: float = _bilinear(heights, on_rim)
			natural_low = minf(natural_low, natural)
			natural_high = maxf(natural_high, natural)
			rim.append(natural)

		# Owner (2026-10-19): the flat around the pond is big enough to hold it with room for
		# the stream to run across: the ground a shore's width out may vary twice as much
		# (the bench levels it).
		var outer_low: float = INF
		var outer_high: float = -INF

		for r in range(24):
			var on_outer: Vector2 = centre + Vector2(cos(TAU * float(r) / 24.0), sin(TAU * float(r) / 24.0)) * (radius_here + shore_m) / spacing_m
			var outer: float = _bilinear(heights, on_outer)
			outer_low = minf(outer_low, outer)
			outer_high = maxf(outer_high, outer)

		if natural_high - natural_low <= max_rim_range and outer_high - outer_low <= 2.0 * max_rim_range:
			rim.sort()
			return {"radius": radius_here, "bench": (float(rim[7]) + float(rim[8])) * 0.5}

	return {}


# Owner (2026-10-20): no stream is shallower than its own water. Depth is at least the
# flow depth over a crest of this width at the spring's greatest flow (base rate times the
# top flow key, Q = 1.7 W h^1.5), plus a freeboard, and never under a minimum.
func _pond_flow(radius_m: float) -> float:
	return maxf(2.0 * radius_m / float(_rules.get("spring_full_pond_diameter_m", 125.0)), 1.0)


func _stream_depth(depth: float, width: float, flow_factor: float = 1.0) -> float:
	var q_max: float = float(_rules.get("spring_base_m3s", 3.0)) * float(_rules.get("spring_rate_max", 20.0)) * flow_factor
	var flow_depth: float = pow(q_max / (1.7 * maxf(width, 1.0)), 2.0 / 3.0)
	return maxf(depth, maxf(float(_rules.get("stream_min_depth_m", 3.0)), flow_depth + float(_rules.get("stream_freeboard_m", 1.5))))


# A brook from a world head pond's lip down to its river head, along `path` (pond end
# first, sample coordinates: the fall line the pond was found along). Its bed is its depth
# under the land (it depends only on the path and the land, so every tile cuts the same
# brook) and falls to the ledge edge, where the water pours over.
func _cut_brook_path(
	carved: PackedFloat32Array, land: PackedFloat32Array, pond_centre: Vector2, radius_m: float, rim: float, path: PackedVector2Array,
	head_bed: float, width: float, depth: float, slope: float, strength: float, best_flow: PackedFloat32Array
) -> void:
	var start_bed: float = rim - float(_rules.get("head_pond_outlet_drop_m", 3.0))
	var end_bed: float = minf(head_bed, start_bed)
	var outlet_min_width: float = float(_rules.get("head_pond_outlet_width_m", 24.0))
	var outlet_blend: float = maxf(float(_rules.get("head_pond_outlet_blend_m", 60.0)), 1.0)
	var reach: float = (width * 0.5 + (depth + 1.0) / slope) / spacing_m + 1.0
	var lip_drop: float = float(_rules.get("brook_lip_drop_m", 5.0))
	var points: PackedVector2Array = PackedVector2Array()
	var lands: PackedFloat32Array = PackedFloat32Array()

	# The points along the path, one sample apart, outside the pond bowl and inside the frame.
	for k in range(path.size() - 1):
		var a: Vector2 = path[k]
		var b: Vector2 = path[k + 1]
		var steps: int = maxi(int(ceil(a.distance_to(b))), 1)

		for n in range(steps + 1):
			var point: Vector2 = a.lerp(b, float(n) / float(steps))

			# Inside the pond the bowl is deeper than the brook anyway.
			if point.distance_to(pond_centre) * spacing_m < radius_m * 0.8:
				continue

			if point.x < -reach or point.y < -reach or point.x > float(samples - 1) + reach or point.y > float(samples - 1) + reach:
				continue

			points.append(point)
			lands.append(_bilinear(land, point))

	# Owner (2026-10-20): the brook is cut deep (its full depth under the land, never above the
	# river it feeds) all the way to the ledge edge, then drops over it as a waterfall. Its bed
	# only falls. A ledge is where the land drops lip_drop_m within two steps; from there the
	# bed holds its height, so it is carved only where land stands above it and the water
	# pours off the lip (the river below carries it down). Rock hardness plays no part: the
	# brook is cut after the land is made, wherever its path goes.
	var last_bed: float = start_bed
	var past_lip: bool = false
	var brook_fall: float = float(_rules.get("brook_min_fall", 0.004))
	var remaining: PackedFloat32Array = PackedFloat32Array()
	remaining.resize(points.size())
	var run: float = 0.0

	for k in range(points.size() - 1, -1, -1):
		remaining[k] = run

		if k > 0:
			run += points[k].distance_to(points[k - 1]) * spacing_m

	for k in range(points.size()):
		var bed: float = last_bed

		if k > 0:
			# The bed always falls, at least min fall per metre and at least the share of the
			# drop still to come over the length still to go, so it reaches the river head's
			# bed at the end with no level stretch before a steep drop.
			var step_m: float = points[k].distance_to(points[k - 1]) * spacing_m
			var share: float = (last_bed - end_bed) * step_m / maxf(remaining[k - 1], step_m)
			bed = maxf(last_bed - maxf(brook_fall * step_m, share), end_bed)

		# Owner report (2026-10-20, build 200): inside the pond the land is the pond's own bowl,
		# so "depth under the land" dug a hole below the bowl next to the guarded sill: a 3 m step
		# at the pond's edge, where the water over the sill is too thin to draw on a steep drop.
		# Inside the pond the channel holds the sill's height; the bowl stays deeper.
		if points[k].distance_to(pond_centre) * spacing_m < radius_m:
			bed = start_bed
		elif not past_lip:
			if k + 2 < points.size() and lands[k] - lands[k + 2] > lip_drop:
				past_lip = true
			else:
				bed = minf(bed, maxf(lands[k] - depth, end_bed))

		last_bed = bed
		var point: Vector2 = points[k]

		# Owner report (2026-10-20): the outlet showed a half bridge of land across it.
		# Leaving the pond the channel is at least outlet_min_width_m across (a whole
		# river's width, not a one-cell trickle), narrowing to the brook's own width
		# over outlet_blend_m.
		var from_edge: float = maxf(point.distance_to(pond_centre) * spacing_m - radius_m, 0.0)
		var open_width: float = lerpf(maxf(width, outlet_min_width), width, clampf(from_edge / outlet_blend, 0.0, 1.0))
		_stamp_at(carved, point, open_width, depth, bed, slope, strength, best_flow)


# Levels the ground to `height` out to `radius_m` from `centre` (sample coordinates), then
# blends back to the land around over at least fade_m, longer where the land is far above
# or below, so the slope away from the flat stays gentle (at most about 1 in 3).
func _bench(carved: PackedFloat32Array, centre: Vector2, radius_m: float, height: float, fade_m: float) -> void:
	var reach_m: float = radius_m + fade_m * 4.0
	var reach_cells: float = reach_m / spacing_m + 1.0

	for nr in range(maxi(int(ceil(centre.y - reach_cells)), 0), mini(int(floor(centre.y + reach_cells)), samples - 1) + 1):
		for nc in range(maxi(int(ceil(centre.x - reach_cells)), 0), mini(int(floor(centre.x + reach_cells)), samples - 1) + 1):
			var target: int = nr * samples + nc

			if _ocean[target] == 1:
				continue

			var distance: float = Vector2(float(nc), float(nr)).distance_to(centre) * spacing_m
			var here: float = carved[target]
			var blend_m: float = clampf(absf(here - height) / 0.3, fade_m, fade_m * 4.0)
			var weight: float = 1.0 - smoothstep(radius_m, radius_m + blend_m, distance)

			if weight > 0.0:
				carved[target] = lerpf(here, height, weight)



# Samples from the frame edge where a neighbor tile's frame also reaches (twice the frame
# margin: the neighbor's margin overlaps this tile's own samples by one margin). Ponds and
# their brooks stay out of it.
func _pond_keep_out() -> float:
	return float(_rules.get("head_straighten_edge_samples", 180.0))


# Uphill direction of a field at a point, measured `reach` samples either side
# (sample coordinates; meters up per sample).
func _gradient(field: PackedFloat32Array, point: Vector2, reach: float) -> Vector2:
	return Vector2(
		_bilinear(field, point + Vector2(reach, 0.0)) - _bilinear(field, point - Vector2(reach, 0.0)),
		_bilinear(field, point + Vector2(0.0, reach)) - _bilinear(field, point - Vector2(0.0, reach))
	) / (2.0 * reach)


# A straight brook from a pond's lip down to a river head: it leaves the pond just under
# the lip (so the pond spills into it) and only ever falls, cutting in where the ground
# rises, until it meets the river's bed at the head.
func _cut_brook(
	carved: PackedFloat32Array, pond_centre: Vector2, radius_m: float, rim_low: float, head: Vector2,
	head_bed: float, width: float, depth: float, min_fall: float, slope: float, strength: float,
	best_flow: PackedFloat32Array
) -> void:
	var direction: Vector2 = (head - pond_centre).normalized()
	var start: Vector2 = pond_centre + direction * (radius_m * 0.8 / spacing_m)
	var length: float = start.distance_to(head)
	var steps: int = maxi(int(ceil(length)), 1)
	var bed: float = rim_low - 1.5
	var floor_bed: float = minf(head_bed, bed)

	for k in range(steps + 1):
		var point: Vector2 = start.lerp(head, float(k) / float(steps))
		bed = minf(bed - min_fall * spacing_m, _bilinear(heights, point) - depth)
		bed = maxf(bed, floor_bed)
		_stamp_at(carved, point, width, depth, bed, slope, strength, best_flow)


# The head of a source river, re-routed straight down a steep slope: from the head the path
# follows the steepest way down the (uncarved) ground until it is back on the river below
# the steep stretch. Left as it was when there is no steep stretch, when the new way does
# not meet the river again, or near the tile's edge (where the neighbor tile, which carves
# the same river, would not see the change).
func _straighten_head(points: PackedVector2Array, areas: PackedFloat32Array) -> Array:
	var steep_slope: float = float(_rules.get("head_straighten_slope", 0.25))
	var keep_out: float = float(_rules.get("head_straighten_edge_samples", 180.0))
	var count: int = points.size()
	var unchanged: Array = [points, areas]

	if count < 3:
		return unchanged

	var inside: Callable = func(point: Vector2) -> bool:
		return point.x > keep_out and point.y > keep_out and point.x < float(samples - 1) - keep_out and point.y < float(samples - 1) - keep_out

	# The steep stretch: from the head down to the first point on gentle ground.
	var end_at: int = -1
	var seen_steep: bool = false

	for k in range(mini(count, 400)):
		if not inside.call(points[k]):
			return unchanged

		var steep: bool = _gradient(heights, points[k], 8.0).length() > steep_slope
		seen_steep = seen_steep or steep

		if seen_steep and not steep:
			end_at = k
			break

	if end_at < 2:
		return unchanged

	# Steepest way down from the head, in 1-sample steps.
	var path: PackedVector2Array = PackedVector2Array([points[0]])
	var here: Vector2 = points[0]
	var limit: int = end_at * 3 + 20
	var rejoin: int = -1
	var foot_height: float = _bilinear(heights, points[end_at])

	for step in range(limit):
		var fall: Vector2 = -_gradient(heights, here, 4.0)

		# Down at the foot of the slope (or in a hollow): join the river from here.
		if fall.length() < 0.001 or _bilinear(heights, here) < foot_height - 2.0:
			break

		here += fall.normalized()

		if not inside.call(here):
			return unchanged

		path.append(here)

		for k in range(end_at, mini(count, end_at + 60)):
			if points[k].distance_to(here) < 1.5:
				rejoin = k
				break

		if rejoin >= 0:
			break

	# Not on the river yet: a short straight piece to the nearest river point below.
	if rejoin < 0:
		var nearest: float = 20.0

		for k in range(end_at, mini(count, end_at + 100)):
			if points[k].distance_to(here) < nearest:
				nearest = points[k].distance_to(here)
				rejoin = k

		if rejoin < 0:
			return unchanged

		var pieces: int = int(ceil(nearest))

		for n in range(1, pieces):
			path.append(here.lerp(points[rejoin], float(n) / float(pieces)))

	var new_points: PackedVector2Array = path
	var new_areas: PackedFloat32Array = PackedFloat32Array()

	for k in range(path.size()):
		new_areas.append(lerpf(areas[0], areas[rejoin], float(k) / float(path.size())))

	for k in range(rejoin, count):
		new_points.append(points[k])
		new_areas.append(areas[k])

	heads_straightened += 1
	return [new_points, new_areas]


# Owner (2026-10-21, Dave): waterfalls are flat, straight-down faces, and a cascade is several
# of them. Where the bed falls faster than terrace_slope (30 cm per m) over terrace_window_m,
# the stretch becomes a staircase: flat treads (the bed, cut level), and a vertical face at
# the start of each step, one 8 m sample thick (the next tread's discs begin half a width
# below the face, so the cut itself makes the wall). Steps are about terrace_drop_m high, and
# never shorter than terrace_step_min_m (16 m of tread and the face), so a very steep slope
# gets taller falls rather than none. The channel is a multiple of 8 m wide, 16 to 24 m, and
# its banks stand near vertical beside the faces. `beds`, `widths` and `banks` are changed in
# place; returns 1 for every point in a staircase. The tread bed is the lowest ground-cut of its
# step (never above the river's own bed), so the staircase only ever cuts deeper.
func _terrace(
	points: PackedVector2Array, usable: PackedByteArray, along: PackedFloat32Array,
	beds: PackedFloat32Array, widths: PackedFloat32Array, banks: PackedFloat32Array
) -> PackedByteArray:
	var flags: PackedByteArray = PackedByteArray()
	flags.resize(points.size())
	var slope_min: float = float(_rules.get("terrace_slope", 0.30))
	var window_m: float = float(_rules.get("terrace_window_m", 32.0))
	var drop_target: float = float(_rules.get("terrace_drop_m", 20.0))
	var single: bool = bool(_rules.get("terrace_single_chute", false))
	var step_min: float = float(_rules.get("terrace_step_min_m", 24.0))
	var run_min: float = float(_rules.get("terrace_run_min_m", 40.0))
	var drop_min: float = float(_rules.get("terrace_drop_min_m", 8.0))
	var wall_slope: float = float(_rules.get("terrace_bank", 2.0))
	var face_slope: float = float(_rules.get("terrace_face_bank", 30.0))
	var width_min: float = float(_rules.get("terrace_width_min_m", 16.0))
	var width_max: float = float(_rules.get("terrace_width_max_m", 24.0))
	var used: PackedInt32Array = PackedInt32Array()

	for k in range(points.size()):
		if usable[k] == 1 and not is_nan(beds[k]):
			used.append(k)

	var count: int = used.size()

	if count < 3:
		return flags

	# Steepness of the bed over the next window_m at each used point, and where that window ends.
	var steep: PackedByteArray = PackedByteArray()
	steep.resize(count)
	var ends: PackedInt32Array = PackedInt32Array()
	ends.resize(count)
	var far: int = 0

	for a in range(count):
		far = maxi(far, a)

		while far < count - 1 and along[used[far]] - along[used[a]] < window_m:
			far += 1

		ends[a] = far
		var run: float = along[used[far]] - along[used[a]]

		if run >= window_m * 0.5 and (beds[used[a]] - beds[used[far]]) / run >= slope_min:
			steep[a] = 1

	var a: int = 0

	while a < count:
		if steep[a] == 0:
			a += 1
			continue

		var b: int = a

		while b + 1 < count and steep[b + 1] == 1:
			b += 1

		var last: int = ends[b]
		var length: float = along[used[last]] - along[used[a]]
		var drop: float = beds[used[a]] - beds[used[last]]
		var from_a: int = a
		a = b + 1

		if length < run_min or drop < drop_min:
			continue

		var steps: int = maxi(int(round(drop / drop_target)), 1)

		while steps > 1 and length / float(steps) < step_min:
			steps -= 1

		# Owner (2026-10-21, Dave): never steps. One clean chute per steep run; where the land
		# levels out onto a plateau the run ends, the plunge pool and a river follow, and the next
		# drop is its own chute.
		if single:
			steps = 1

		var period: float = length / float(steps)
		var s0: float = along[used[from_a]]
		var top_bed: float = beds[used[from_a]]
		# The lowest bed of each step: the river's own bed where the step ends.
		var tread: PackedFloat32Array = PackedFloat32Array()

		# Dave (2026-10-21): the fall is as wide as the river that feeds it. One width for the whole chute, the river's own
		# width at its lip rounded to whole cells (no longer cut down to 24 m, which pinched a 40 m river into a 24 m chute).
		var chute_width: float = clampf(round(widths[used[from_a]] / spacing_m) * spacing_m, width_min, width_max)
		var half_run: float = chute_width * 0.5

		var foot_set: bool = false
		var ramp: bool = single and top_bed - beds[used[last]] > float(_rules.get("chute_face_max_m", 90.0))

		for j in range(steps):
			var end_s: float = s0 + float(j + 1) * period + half_run
			var end_bed: float = beds[used[last]]

			for q in range(from_a, last + 1):
				if along[used[q]] >= end_s - 0.01:
					end_bed = beds[used[q]]
					break

			tread.append(minf(end_bed, top_bed))

		for q in range(from_a, last + 1):
			var k: int = used[q]
			var width: float = chute_width
			widths[k] = width
			var half: float = width * 0.5
			var rel: float = along[k] - s0
			flags[k] = 1

			# The plunge pool sits at the foot of the face, one pool radius downstream of it.
			if single and not foot_set and rel >= half + width * 0.6 and _bilinear(heights, points[k]) - tread[0] < float(_rules.get("chute_foot_land_m", 10.0)):
				foot_set = true
				_chute_feet.append({"point": points[k], "bed": tread[0], "width": width, "height": top_bed - tread[0]})
			banks[k] = maxf(banks[k], wall_slope)

			if rel < half:
				beds[k] = minf(beds[k], top_bed)
			elif ramp:
				# A very tall drop on a mountain side is one long chute at a constant gradient, not a
				# wall (a 300 m wall would be a slot canyon): straight line from the lip to the foot.
				var t: float = clampf((rel - half) / maxf(length - half, 1.0), 0.0, 1.0)
				beds[k] = minf(beds[k], lerpf(top_bed, tread[0], t))
			else:
				var j: int = clampi(int(floor((rel - half) / period)), 0, steps - 1)
				beds[k] = minf(beds[k], tread[j])

			# Near any face the walls beside the water stand almost straight up.
			var to_face: float = fposmod(rel, period)

			if to_face > period * 0.5:
				to_face = period - to_face

			if to_face <= half + spacing_m and not ramp:
				banks[k] = maxf(banks[k], face_slope)

	return flags


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

	# Owner (2026-10-19): where the bed is cut well below the ground the banks slope back
	# far enough to reach it (a valley), instead of ending in a cliff.
	if bowl <= 0.0:
		var cut: float = _bilinear(heights, center) - bed
		radius_m = minf(maxf(radius_m, width * 0.5 + (cut + 1.0) / slope), maxf(float(_rules.get("bank_reach_max_m", 150.0)), radius_m))

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

			if not _guard.is_empty():
				floor_height = maxf(floor_height, _guard[target])

			# Owner report (2026-10-20, build 200): no river left the head ponds. The water did,
			# but across the flat 18 to 40 m bed a spring's flow spread into a sheet 2 to 12 cm
			# thick, under the 12 cm the water is drawn from, so the outlet looked like dry dirt.
			# The bed is a shallow V: lowest along the middle, rising to `bed` at the bank toe,
			# so normal flow gathers in the middle cells and runs deep enough to show. Cut past
			# the shore guard too, so a pond's sill is a notch in the middle, not a wide flat lip.
			if bowl <= 0.0 and distance < width * 0.5:
				floor_height -= _notch_m(width) * (1.0 - distance / (width * 0.5))

			carved[target] = minf(carved[target], floor_height)

			if distance <= width * 0.5 and strength >= best_flow[target]:
				best_flow[target] = strength
				flow[target] = strength
				water_class[target] = RIVER
				water_surface[target] = bed + 0.75 * depth


# Owner report (2026-10-20, build 200): at the foot of a fall the plunge pool met the cliff
# in an odd pocket, a knob of ground left between the pool and the face. The water wears the
# foot smooth: around the pool the ground is averaged a few times, only ever lowered, so
# knobs and ledges go and the foot is washed rock running into the pool.
func _wash_foot(carved: PackedFloat32Array, centre: Vector2, radius_m: float) -> void:
	var reach: float = radius_m / spacing_m
	var first_x: int = maxi(int(ceil(centre.x - reach)), 1)
	var last_x: int = mini(int(floor(centre.x + reach)), samples - 2)
	var first_z: int = maxi(int(ceil(centre.y - reach)), 1)
	var last_z: int = mini(int(floor(centre.y + reach)), samples - 2)

	for pass_n in range(3):
		var before: PackedFloat32Array = carved.duplicate()

		for nr in range(first_z, last_z + 1):
			for nc in range(first_x, last_x + 1):
				var k: int = nr * samples + nc

				if _ocean[k] == 1 or Vector2(float(nc), float(nr)).distance_to(centre) > reach:
					continue

				var sum_h: float = 0.0

				for dz in range(-1, 2):
					for dx in range(-1, 2):
						sum_h += before[k + dz * samples + dx]

				carved[k] = minf(before[k], sum_h / 9.0)


# Owner report (2026-10-20, build 200): a pond's bowl is steepest at its rim, so the river's
# sill stood 3 to 7 m above the bowl just inside it, and the water spilling over the sill (a
# few tens of cm) counted as thin water on a steep drop and was not drawn: a dry strip
# between the pond and its river. Inside the pond, along the river's line, the bowl is
# raised to a ramp falling from the sill at spillway_slope, so the sill runs gently into
# the pond. The pond keeps its outline and its level; only the floor at its outlet is
# shallower.
func _spillway(carved: PackedFloat32Array, centre: Vector2, radius_m: float, first: Vector2, width: float) -> void:
	# The sill: the ground on the river's line just outside the pond's edge.
	var direction: Vector2 = (first - centre).normalized()
	var edge: Vector2 = centre + direction * radius_m / spacing_m
	var crest: Vector2 = (edge + direction * 0.75).round()
	var sill: float = carved[clampi(int(crest.y), 0, samples - 1) * samples + clampi(int(crest.x), 0, samples - 1)]
	var fall: float = float(_rules.get("spillway_slope", 0.3))
	var half: float = maxf(width * 0.5, spacing_m) / spacing_m
	var reach: float = radius_m / spacing_m + half

	for nr in range(maxi(int(floor(centre.y - reach)), 0), mini(int(ceil(centre.y + reach)), samples - 1) + 1):
		for nc in range(maxi(int(floor(centre.x - reach)), 0), mini(int(ceil(centre.x + reach)), samples - 1) + 1):
			var cell: Vector2 = Vector2(float(nc), float(nr))

			if cell.distance_to(centre) * spacing_m >= radius_m:
				continue

			var inward: float = (edge - cell).dot(direction)
			var side: float = absf((cell - edge).cross(direction))

			# The middle of the pond (where its spring is) stays as it is.
			if inward < 0.0 or side > half or inward * spacing_m > radius_m * 0.6:
				continue

			var k: int = nr * samples + nc
			carved[k] = maxf(carved[k], sill - inward * spacing_m * fall)


# The world head pond whose brook ends at this river head (sample coordinates), as
# [pond centre, pond radius m, brook points from the pond's middle up to (not including) the
# head, about half a sample apart], or [] when none. The head is marked joined, so the brook
# is not cut again on its own.
func _join_pond(head: Vector2) -> Array:
	for p in range(_world_ponds.size()):
		var pond: Dictionary = _world_ponds[p]
		var heads: Array = pond["heads"]

		for h in range(heads.size()):
			var head_here: Vector2 = Vector2(heads[h]) / spacing_m - Vector2(float(_origin_sx), float(_origin_sz))

			if head_here.distance_to(head) > 3.0:
				continue

			var path: PackedVector2Array = PackedVector2Array()

			for point in pond["paths"][h]:
				path.append(Vector2(point) / spacing_m - Vector2(float(_origin_sx), float(_origin_sz)))

			path[path.size() - 1] = head
			var lead: PackedVector2Array = PackedVector2Array()

			for k in range(path.size() - 1):
				var steps: int = maxi(int(ceil(path[k].distance_to(path[k + 1]) * 2.0)), 1)

				for n in range(steps):
					lead.append(path[k].lerp(path[k + 1], float(n) / float(steps)))

			_joined_heads[Vector2i(p, h)] = true
			var centre: Vector2 = Vector2(pond["centre"]) / spacing_m - Vector2(float(_origin_sx), float(_origin_sz))
			return [centre, float(pond.get("radius", 35.0)), lead, float(pond.get("level", 0.0))]

	return []


# Owner report (2026-10-21, Dave, build 3xx): "a lump of dirt blocking the river's path" between
# pond B and its first fall. The pond's brook follows the fall line it was found along, which
# hooked around a hill tip at the pond's shore, so the water had to go round the spur. The river
# leaves the pond for its first lip (the first point where the ground falls lip_drop_m below the
# pond's water) by the straight way, cut through whatever stands in between (the river ignores
# the ground's hardness). Not done when the lip is further than straight_lip_max_m, or when
# the straight line would cross ground more than straight_lip_rise_m above the pond.
# Returns [points, areas].
func _straight_to_lip(
	points: PackedVector2Array, areas: PackedFloat32Array, centre: Vector2, radius_m: float, level: float, land: PackedFloat32Array
) -> Array:
	var drop: float = float(_rules.get("straight_lip_drop_m", 25.0))
	var reach: float = float(_rules.get("straight_lip_max_m", 500.0))
	var rise: float = float(_rules.get("straight_lip_rise_m", 14.0))
	var lip_at: int = -1

	# The pond's outlet sill: the ground where the river first leaves the pond (not the world's
	# nominal level, nor the bench round the pond, which the tile's land can differ from by
	# many metres). The lip is where the ground falls `drop` below that.
	var sill: float = NAN

	for k in range(points.size()):
		var distance: float = points[k].distance_to(centre) * spacing_m

		if distance < radius_m + 8.0:
			continue

		if distance > radius_m + reach:
			break

		var p: Vector2 = points[k]

		if p.x < 1.0 or p.y < 1.0 or p.x > float(samples - 2) or p.y > float(samples - 2):
			break

		if is_nan(sill):
			sill = _bilinear(land, p)
			level = sill
			continue

		if _bilinear(land, p) < sill - drop:
			lip_at = k
			break


	if lip_at < 1:
		return [points, areas]

	var target: Vector2 = points[lip_at]
	var steps: int = maxi(int(ceil(centre.distance_to(target) * 2.0)), 1)

	for n in range(steps + 1):
		var on_line: Vector2 = centre.lerp(target, float(n) / float(steps))

		if on_line.distance_to(centre) * spacing_m > radius_m and _bilinear(land, on_line) > level + rise:
			return [points, areas]

	var line: PackedVector2Array = PackedVector2Array()
	var line_areas: PackedFloat32Array = PackedFloat32Array()

	for n in range(steps):
		line.append(centre.lerp(target, float(n) / float(steps)))
		line_areas.append(areas[0])

	for k in range(lip_at, points.size()):
		line.append(points[k])
		line_areas.append(areas[k])

	return [line, line_areas]


# How far the middle of a channel this wide is cut below its bank toes (see _stamp_at).
func _notch_m(width: float) -> float:
	return maxf(float(_rules.get("channel_notch_m", 1.0)), width * float(_rules.get("channel_notch_per_width", 0.05)))


# A bowl-shaped spring pond: the floor is `bottom` in the middle and rises to the lowest
# lip (`rim_low`) at the edge, and the water stands just under that lip. The bowl keeps
# rising past its edge like a crater wall, and the rim is then rounded off (no raised lip
# or knife edge, owner 2026-10-18).
func _stamp_pond(
	carved: PackedFloat32Array, center: Vector2, radius_m: float, bottom: float, rim_low: float,
	strength: float, best_flow: PackedFloat32Array, max_cut: float, fade_m: float, shore_m: float = 0.0
) -> void:
	var reach_cells: float = (radius_m + fade_m) / spacing_m + 2.0
	var first_x: int = maxi(int(ceil(center.x - reach_cells)), 1)
	var last_x: int = mini(int(floor(center.x + reach_cells)), samples - 2)
	var first_z: int = maxi(int(ceil(center.y - reach_cells)), 1)
	var last_z: int = mini(int(floor(center.y + reach_cells)), samples - 2)

	for nr in range(first_z, last_z + 1):
		for nc in range(first_x, last_x + 1):
			var distance: float = sqrt(pow(float(nc) - center.x, 2.0) + pow(float(nr) - center.y, 2.0)) * spacing_m

			if distance > radius_m + fade_m or _ocean[nr * samples + nc] == 1:
				continue

			# A bowl inside the edge, then a walkable ramp (0.4, about 22 degrees) up and out.
			# Outside the edge the cut fades out over fade_m (owner, 2026-10-19: on a hillside the
			# ramp carved a deep cone ending in a cliff).
			var floor_height: float = bottom + (rim_low - bottom) * pow(distance / radius_m, 2.0)

			if distance > radius_m:
				var fade: float = 1.0 - (distance - radius_m) / fade_m
				floor_height = maxf(rim_low + (distance - radius_m) * 0.4, carved[nr * samples + nc] - max_cut * fade)

			pond_cut_max_m = maxf(pond_cut_max_m, heights[nr * samples + nc] - floor_height)
			carved[nr * samples + nc] = minf(carved[nr * samples + nc], floor_height)

	# Round off the rim and the wall (not the floor): repeated 3 x 3 averaging. Then the
	# shore stays at the lip's height all round (owner, 2026-10-19: smoothing a small pond
	# had worn its rim below the water, so it spilled on every side).
	for pass_n in range(12 if shore_m <= 0.0 else 3):
		var before: PackedFloat32Array = carved.duplicate()

		for nr in range(first_z, last_z + 1):
			for nc in range(first_x, last_x + 1):
				var distance: float = sqrt(pow(float(nc) - center.x, 2.0) + pow(float(nr) - center.y, 2.0)) * spacing_m

				if distance < 0.75 * radius_m or distance > radius_m + 0.8 * fade_m or _ocean[nr * samples + nc] == 1:
					continue

				var total: float = 0.0

				for dz in range(-1, 2):
					for dx in range(-1, 2):
						total += before[(nr + dz) * samples + nc + dx]

				carved[nr * samples + nc] = total / 9.0

	if shore_m > 0.0:
		for nr in range(first_z, last_z + 1):
			for nc in range(first_x, last_x + 1):
				var distance: float = sqrt(pow(float(nc) - center.x, 2.0) + pow(float(nr) - center.y, 2.0)) * spacing_m

				if distance >= radius_m and distance <= radius_m + shore_m and _ocean[nr * samples + nc] != 1:
					carved[nr * samples + nc] = maxf(carved[nr * samples + nc], rim_low)

	var surface: float = rim_low - 1.0

	for nr in range(first_z, last_z + 1):
		for nc in range(first_x, last_x + 1):
			var target: int = nr * samples + nc
			var distance: float = sqrt(pow(float(nc) - center.x, 2.0) + pow(float(nr) - center.y, 2.0)) * spacing_m

			if distance <= radius_m and _ocean[target] != 1 and carved[target] < surface and strength >= best_flow[target]:
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
	@warning_ignore("integer_division")
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
	@warning_ignore("integer_division")
	var coarse: int = (samples - 1) / step + 1
	var climb_cost: float = float(river_rules["climb_cost"])
	var head: Vector2 = _bay_head_samples(starter)
	var goal: Vector2i = Vector2i(int(round(head.x / float(step))), int(round(head.y / float(step))))
	goal = Vector2i(clampi(goal.x, 0, coarse - 1), clampi(goal.y, 0, coarse - 1))
	@warning_ignore("integer_division")
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

		@warning_ignore("integer_division")
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
		@warning_ignore("integer_division")
		coarse_path.append(Vector2(float((walker % coarse) * step), float((walker / coarse) * step)))
		walker = came[walker]

	coarse_path.reverse()
	var path: PackedVector2Array = _smooth_path(coarse_path, river_rules)
	# Start exactly at the lake's edge cell so the lake has to spill into the channel.
	@warning_ignore("integer_division")
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
		@warning_ignore("integer_division")
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
