class_name TileHeight
extends RefCounted

# Builds one tile's 8 m surface height map from the 160 m world elevation
# map: Catmull-Rom cubic upsampling of the world map plus fine detail
# noise. Everything is a function of world position, so two tiles agree on
# the samples along their shared edge exactly (the edge samples belong to
# both tiles).

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

var samples: int = 0                 # samples per side (1921)
var spacing_m: float = 8.0
var heights: PackedFloat32Array = PackedFloat32Array()

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


func build(tile: Vector2i) -> void:
	var x0: float = float(tile.x) * float(_settings.tile_size_m)
	var z0: float = float(tile.y) * float(_settings.tile_size_m)
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
	var last_row: int = int(floor((z0 + float(_settings.tile_size_m) - _elevation.origin_z) / cell - 0.5)) + 2
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

	_add_detail(tile)


static func _cubic_weights(t: float, out: PackedFloat32Array, offset: int) -> void:
	var t2: float = t * t
	var t3: float = t2 * t
	out[offset] = -0.5 * t3 + t2 - 0.5 * t
	out[offset + 1] = 1.5 * t3 - 2.5 * t2 + 1.0
	out[offset + 2] = -1.5 * t3 + 2.0 * t2 + 0.5 * t
	out[offset + 3] = 0.5 * t3 - 0.5 * t2


# Fine noise, faded by height. Noise octaves are generated for the whole
# tile in one call at world-aligned offsets, so they match across tiles.
func _add_detail(tile: Vector2i) -> void:
	var detail: Dictionary = _rules["detail"]
	var calm_below: float = float(detail["calm_below_m"])
	var full_above: float = float(detail["full_above_m"])
	var calm: float = float(detail["calm_strength"])
	var sea: float = float(detail["sea_strength"])
	var ragged: float = float(detail["coast_ragged_m"])
	var tile_samples: int = int(_settings.tile_size_m / _settings.map_spacing_m)
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
		noise.offset = Vector3(float(tile.x * tile_samples), float(tile.y * tile_samples), 0.0)
		var image: Image = noise.get_image(samples, samples, false, false, false)

		if image.get_format() != Image.FORMAT_L8:
			image.convert(Image.FORMAT_L8)

		var data: PackedByteArray = image.get_data()
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

		var value: float = h + strength * field[index]

		# Rag the shoreline a little so the coast is not a smooth contour.
		if absf(h) < ragged:
			value += 0.5 * ragged * (field[index] / 20.0)

		heights[index] = value


func height_at(i: int, j: int) -> float:
	return heights[j * samples + i]
