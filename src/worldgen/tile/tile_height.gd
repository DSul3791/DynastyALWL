class_name TileHeight
extends RefCounted

# Builds one tile's 8 m surface height map from the 160 m world elevation
# map: Catmull-Rom cubic upsampling of the world map plus fine detail
# noise. Everything is a function of world position, so two tiles agree on
# the samples along their shared edge exactly (the edge samples belong to
# both tiles).

const WrapNoiseScript := preload("res://src/worldgen/tile/wrap_noise.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

var samples: int = 0                 # samples per side (1921 for a plain tile, more with a margin)
var spacing_m: float = 8.0
var origin_sx: int = 0               # world sample index of sample 0 (east) and
var origin_sz: int = 0               # of row 0 (south), in 8 m samples
var heights: PackedFloat32Array = PackedFloat32Array()
var valley_guides: Array = []        # world rivers near the frame (RiverNetwork.guides_in): the land is shaped into valleys around them

var _settings
var _elevation
var _rules: Dictionary = {}


static func load_rules(path: String, errors: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Tile rules not found: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Tile rules are not valid JSON: %s" % path)
		return {}

	return parsed


func setup(settings, elevation, rules: Dictionary) -> void:
	_settings = settings
	_elevation = elevation
	_rules = rules
	spacing_m = float(settings.map_spacing_m)
	samples = int(settings.tile_size_m / settings.map_spacing_m) + 1


# A tile's own 1,921 by 1,921 samples.
func build(tile: Vector2i) -> void:
	var tile_samples: int = int(_settings.tile_size_m / _settings.map_spacing_m)
	build_frame(tile.x * tile_samples, tile.y * tile_samples, tile_samples + 1)


# Any square of the world grid: `count` samples per side whose first sample
# is world sample (origin_x, origin_z). A tile with a margin is built this
# way, so its edge samples see the same inputs as the neighbor's.
func build_frame(origin_x: int, origin_z: int, count: int) -> void:
	samples = count
	origin_sx = origin_x
	origin_sz = origin_z
	var x0: float = float(origin_x) * spacing_m
	var z0: float = float(origin_z) * spacing_m
	var cell: float = _elevation.cell_m
	heights = PackedFloat32Array()
	heights.resize(samples * samples)

	# Horizontal cubic weights are the same for every row.
	var column_base: PackedInt32Array = PackedInt32Array()
	var column_weights: PackedFloat32Array = PackedFloat32Array()
	column_base.resize(samples)
	column_weights.resize(samples * 4)

	for i in range(samples):
		var u: float = (x0 + float(i) * spacing_m - _elevation.origin_x) / cell - 0.5
		var base: int = int(floor(u))
		column_base[i] = base
		_cubic_weights(u - float(base), column_weights, i * 4)

	# Source rows needed, with the horizontal pass done once per source row.
	var first_row: int = int(floor((z0 - _elevation.origin_z) / cell - 0.5)) - 1
	var last_row: int = int(floor((z0 + float(samples - 1) * spacing_m - _elevation.origin_z) / cell - 0.5)) + 2
	var horizontal: Array = []

	for source_row in range(first_row, last_row + 1):
		var line: PackedFloat32Array = PackedFloat32Array()
		line.resize(samples)

		for i in range(samples):
			var base: int = column_base[i]
			var value: float = 0.0

			for tap in range(4):
				value += column_weights[i * 4 + tap] * _elevation.heights[
					_elevation.index_of(base - 1 + tap, source_row)
				]

			line[i] = value

		horizontal.append(line)

	var weights: PackedFloat32Array = PackedFloat32Array()
	weights.resize(4)

	for j in range(samples):
		var v: float = (z0 + float(j) * spacing_m - _elevation.origin_z) / cell - 0.5
		var base_row: int = int(floor(v))
		_cubic_weights(v - float(base_row), weights, 0)
		var line_0: PackedFloat32Array = horizontal[base_row - 1 - first_row]
		var line_1: PackedFloat32Array = horizontal[base_row - first_row]
		var line_2: PackedFloat32Array = horizontal[base_row + 1 - first_row]
		var line_3: PackedFloat32Array = horizontal[base_row + 2 - first_row]
		var w0: float = weights[0]
		var w1: float = weights[1]
		var w2: float = weights[2]
		var w3: float = weights[3]
		var out: int = j * samples

		for i in range(samples):
			heights[out + i] = w0 * line_0[i] + w1 * line_1[i] + w2 * line_2[i] + w3 * line_3[i]

	_add_detail(_shape_valleys())


# Owner (2026-10-19): rivers run at the bottom of real valleys. Around every world river
# the land is lowered toward the river's water level: a flat floor along the river, then
# walls that rise smoothly into the hills, wider for bigger rivers. Where the land beside
# the river lies a little lower than the water (a river along a slope) the floor is lifted
# a few meters so the water stays in its bed. Worked out on a 32 m grid of world-aligned
# points (the same in every tile) and blended down to 8 m. Returns how much of the fine
# detail noise to keep at each sample (little on valley floors), or empty without rivers.
func _shape_valleys() -> PackedFloat32Array:
	if valley_guides.is_empty() or not _rules.has("valleys"):
		return PackedFloat32Array()

	var rules: Dictionary = _rules["valleys"]
	var step: int = maxi(int(round(float(rules.get("grid_m", 32.0)) / spacing_m)), 1)
	var grid_m: float = float(step) * spacing_m
	var floor_base: float = float(rules["floor_half_m"])
	var floor_scale: float = float(rules["floor_half_per_sqrt_km2"])
	var wall_base: float = float(rules["half_width_m"])
	var wall_scale: float = float(rules["half_width_per_sqrt_km2"])
	var wall_max: float = float(rules["half_width_max_m"])
	var lift_max: float = float(rules["lift_max_m"])
	var detail_floor: float = float(rules["detail_on_floor"])
	var nodes: int = int(ceil(float(samples - 1) / float(step))) + 1
	var x0: float = float(origin_sx) * spacing_m
	var z0: float = float(origin_sz) * spacing_m
	var best_d2: PackedFloat32Array = PackedFloat32Array()
	best_d2.resize(nodes * nodes)
	best_d2.fill(INF)
	var node_level: PackedFloat32Array = PackedFloat32Array()
	node_level.resize(nodes * nodes)
	var node_floor: PackedFloat32Array = PackedFloat32Array()
	node_floor.resize(nodes * nodes)
	var node_wall: PackedFloat32Array = PackedFloat32Array()
	node_wall.resize(nodes * nodes)

	for guide in valley_guides:
		var points: PackedVector2Array = guide["points"]
		var areas: PackedFloat32Array = guide["areas"]
		var levels: PackedFloat32Array = guide["levels"]
		var marks: PackedByteArray = guide["marks"]

		for k in range(points.size()):
			if marks[k] == 0:
				continue

			# The river's level: the 160 m land under its cells, never rising downstream,
			# and lower still where the smooth land between the cells dips below that.
			var level_here: float = minf(levels[k], _smooth_height(points[k].x, points[k].y))
			var root: float = sqrt(maxf(areas[k], 0.0))
			var wall: float = minf(wall_base + wall_scale * root, wall_max)
			var floor_half: float = minf(floor_base + floor_scale * root, wall * 0.5)
			var cu: float = (points[k].x - x0) / grid_m
			var cv: float = (points[k].y - z0) / grid_m
			var reach: int = int(ceil(wall / grid_m))
			var wall2: float = wall * wall

			for nj in range(maxi(int(floor(cv)) - reach, 0), mini(int(ceil(cv)) + reach, nodes - 1) + 1):
				var dz: float = (float(nj) - cv) * grid_m

				for ni in range(maxi(int(floor(cu)) - reach, 0), mini(int(ceil(cu)) + reach, nodes - 1) + 1):
					var dx: float = (float(ni) - cu) * grid_m
					var d2: float = dx * dx + dz * dz
					var node: int = nj * nodes + ni

					if d2 < wall2 and d2 < best_d2[node]:
						best_d2[node] = d2
						node_level[node] = level_here
						node_floor[node] = floor_half
						node_wall[node] = wall

	# Per node: how much of the land's height above the water stays (0 on the floor, 1 past the wall).
	var node_keep: PackedFloat32Array = PackedFloat32Array()
	node_keep.resize(nodes * nodes)
	node_keep.fill(1.0)

	for node in range(nodes * nodes):
		if best_d2[node] < INF:
			node_keep[node] = smoothstep(node_floor[node], node_wall[node], sqrt(best_d2[node]))

	var detail_scale: PackedFloat32Array = PackedFloat32Array()
	detail_scale.resize(samples * samples)
	detail_scale.fill(1.0)

	for j in range(samples):
		var nv: float = float(j) / float(step)
		var nj: int = mini(int(nv), nodes - 2)
		var tv: float = nv - float(nj)

		for i in range(samples):
			var nu: float = float(i) / float(step)
			var ni: int = mini(int(nu), nodes - 2)
			var tu: float = nu - float(ni)
			var a: int = nj * nodes + ni
			var k00: float = node_keep[a]
			var k10: float = node_keep[a + 1]
			var k01: float = node_keep[a + nodes]
			var k11: float = node_keep[a + nodes + 1]

			if k00 >= 1.0 and k10 >= 1.0 and k01 >= 1.0 and k11 >= 1.0:
				continue

			var w00: float = (1.0 - tu) * (1.0 - tv)
			var w10: float = tu * (1.0 - tv)
			var w01: float = (1.0 - tu) * tv
			var w11: float = tu * tv
			var keep: float = w00 * k00 + w10 * k10 + w01 * k01 + w11 * k11
			var level: float = 0.0
			var level_weight: float = 0.0

			# Only nodes near a river know its level.
			if best_d2[a] < INF:
				level += w00 * node_level[a]
				level_weight += w00

			if best_d2[a + 1] < INF:
				level += w10 * node_level[a + 1]
				level_weight += w10

			if best_d2[a + nodes] < INF:
				level += w01 * node_level[a + nodes]
				level_weight += w01

			if best_d2[a + nodes + 1] < INF:
				level += w11 * node_level[a + nodes + 1]
				level_weight += w11

			if level_weight <= 0.0:
				continue

			level /= level_weight
			var index: int = j * samples + i
			var h: float = heights[index]

			if h > level:
				heights[index] = level + (h - level) * keep
			elif h > 0.0:
				heights[index] = h + minf(level - h, lift_max) * (1.0 - keep)

			detail_scale[index] = lerpf(detail_floor, 1.0, keep)

	return detail_scale


# The smooth (cubic) land height at a world position, before detail: the same surface
# build_frame makes, for any point.
func _smooth_height(x: float, z: float) -> float:
	var cell: float = _elevation.cell_m
	var u: float = (x - _elevation.origin_x) / cell - 0.5
	var v: float = (z - _elevation.origin_z) / cell - 0.5
	var base_u: int = int(floor(u))
	var base_v: int = int(floor(v))
	var wu: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var wv: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	_cubic_weights(u - float(base_u), wu, 0)
	_cubic_weights(v - float(base_v), wv, 0)
	var value: float = 0.0

	for b in range(4):
		for a in range(4):
			value += wu[a] * wv[b] * _elevation.heights[_elevation.index_of(base_u - 1 + a, base_v - 1 + b)]

	return value


static func _cubic_weights(t: float, out: PackedFloat32Array, offset: int) -> void:
	var t2: float = t * t
	var t3: float = t2 * t
	out[offset] = -0.5 * t3 + t2 - 0.5 * t
	out[offset + 1] = 1.5 * t3 - 2.5 * t2 + 1.0
	out[offset + 2] = -1.5 * t3 + 2.0 * t2 + 0.5 * t
	out[offset + 3] = 0.5 * t3 - 0.5 * t2


# Fine noise, faded by height. Noise octaves are generated for the whole
# tile in one call at world-aligned offsets, so they match across tiles.
func _add_detail(detail_scale: PackedFloat32Array = PackedFloat32Array()) -> void:
	var detail: Dictionary = _rules["detail"]
	var calm_below: float = float(detail["calm_below_m"])
	var full_above: float = float(detail["full_above_m"])
	var calm: float = float(detail["calm_strength"])
	var sea: float = float(detail["sea_strength"])
	var ragged: float = float(detail["coast_ragged_m"])
	var total: int = samples * samples
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(total)
	var octave_index: int = 0

	for octave in detail["octaves"]:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = SeedUtil.purpose_seed(_settings.master_seed, "tile_detail", octave_index)
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.frequency = spacing_m / float(octave["wavelength_m"])
		# The image is sampled in sample units, so shift by whole tiles.
		var tile_samples_w: int = int(_settings.tile_size_m / _settings.map_spacing_m)
		var data: PackedByteArray = WrapNoiseScript.bytes(
			noise, origin_sx, origin_sz, samples, samples, _settings.min_tile * tile_samples_w, _settings.min_tile * tile_samples_w,
			_settings.tiles_x * tile_samples_w, _settings.tiles_z * tile_samples_w, int(ceil(4.0 * float(octave["wavelength_m"]) / spacing_m))
		)
		var amplitude: float = float(octave["amplitude_m"])

		for index in range(total):
			field[index] += amplitude * (float(data[index]) / 127.5 - 1.0)

		octave_index += 1

	for index in range(total):
		var h: float = heights[index]
		var strength: float

		if h > 0.0:
			var t: float = clampf((h - calm_below) / (full_above - calm_below), 0.0, 1.0)
			strength = lerpf(calm, 1.0, t * t * (3.0 - 2.0 * t))
		else:
			strength = sea

		if not detail_scale.is_empty():
			strength *= detail_scale[index]

		var value: float = h + strength * field[index]

		# Rag the shoreline a little so the coast is not a smooth contour.
		if absf(h) < ragged:
			value += 0.5 * ragged * (field[index] / 20.0)

		heights[index] = value


func height_at(i: int, j: int) -> float:
	return heights[j * samples + i]
