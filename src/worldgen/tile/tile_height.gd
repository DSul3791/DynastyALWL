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
var rock = null                      # optional TileGeology prepared for this frame (prepare_frame): ledges follow its rock layers
var defer_strata: bool = false       # build_frame leaves the rock beds for add_strata (the baker runs it after erosion)
var _detail_scale: PackedFloat32Array = PackedFloat32Array()
var _edge_cache: Dictionary = {}

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
	var clock: int = Time.get_ticks_msec()
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

	_lap("frame cubic", clock)
	clock = Time.get_ticks_msec()
	_detail_scale = _shape_valleys()
	_lap("shape valleys", clock)
	clock = Time.get_ticks_msec()
	_add_detail(_detail_scale)
	_lap("add detail", clock)

	if not defer_strata:
		add_strata()


# Rock beds: ledges and cliffs where hard beds crop out. With `rock` set (a TileGeology
# prepared for this frame) the beds are the real rock layers; without, synthetic beds.
# The baker defers this until after erosion, so ledges show where erosion left the rock.
# Timing line for the bake log.
static func _lap(stage: String, since_ms: int) -> void:
	print("  height timing: %s %d ms" % [stage, Time.get_ticks_msec() - since_ms])


func add_strata() -> void:
	if rock != null:
		_add_rock_beds(_detail_scale)
	else:
		_add_strata(_detail_scale)


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
	var fine: PackedFloat32Array = PackedFloat32Array()   # the octaves marked "hill_only": rolling farmland keeps only the broad swells
	fine.resize(total)
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

		var target: PackedFloat32Array = fine if bool(octave.get("hill_only", false)) else field

		for index in range(total):
			target[index] += amplitude * (float(data[index]) / 127.5 - 1.0)

		octave_index += 1

	var hill_from: float = float(detail.get("hill_from_m", 0.0))
	var hill_to: float = float(detail.get("hill_to_m", 0.0))
	var hill_min: float = float(detail.get("hill_min_share", 1.0))
	# Each island's own bumpiness (world map, so every tile agrees): flat prairie, rolling hills, rugged ridge.
	var island_texture: PackedFloat32Array = _island_texture_rows()

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

		strength *= island_texture[index]

		var hill: float = 1.0

		if hill_to > hill_from:
			hill = lerpf(hill_min, 1.0, smoothstep(hill_from, hill_to, h))

		var value: float = h + strength * (field[index] + hill * fine[index])

		# Rag the shoreline a little so the coast is not a smooth contour.
		if absf(h) < ragged:
			value += 0.5 * ragged * ((field[index] + fine[index]) / 20.0)

		heights[index] = value


# The island texture factor (WorldElevation.texture) for every sample of this frame.
func _island_texture_rows() -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(samples * samples)
	var cell: float = _elevation.cell_m
	var x0: float = float(origin_sx) * spacing_m
	var z0: float = float(origin_sz) * spacing_m
	var column_cell: PackedInt32Array = PackedInt32Array()
	var column_frac: PackedFloat32Array = PackedFloat32Array()
	column_cell.resize(samples)
	column_frac.resize(samples)

	for i in range(samples):
		var u: float = (x0 + float(i) * spacing_m - _elevation.origin_x) / cell - 0.5
		column_cell[i] = int(floor(u))
		column_frac[i] = u - floor(u)

	for j in range(samples):
		var v: float = (z0 + float(j) * spacing_m - _elevation.origin_z) / cell - 0.5
		var row: int = int(floor(v))
		var fv: float = v - floor(v)
		var out_base: int = j * samples

		for i in range(samples):
			var c: int = column_cell[i]
			var fu: float = column_frac[i]
			var top: float = lerpf(_elevation.texture[_elevation.index_of(c, row)], _elevation.texture[_elevation.index_of(c + 1, row)], fu)
			var bottom: float = lerpf(_elevation.texture[_elevation.index_of(c, row + 1)], _elevation.texture[_elevation.index_of(c + 1, row + 1)], fu)
			out[out_base + i] = lerpf(top, bottom, fv)

	return out


func height_at(i: int, j: int) -> float:
	return heights[j * samples + i]


# Owner (2026-10-20): "the terrain is way too smooth ... erosion was supposed to wear away
# the soft stuff leaving the hard stuff to create ledges, mountains, cliffs, plateaus".
# The rock under the land lies in beds (strata). Over time soft beds wear back into gentle
# slopes, while a hard bed stands as a cliff with a flat bench (its own top) behind it.
# Done as a remap of each sample's height, a function of world position only, so tiles
# still match along their edges: inside a hard bed the land is made steeper (the cliff),
# above it nearly flat (the bench), so every hillside that crosses the bed gets a ledge
# at the same height all around the hill, as real layered rock does. The beds tilt and
# bend gently over kilometers (dip), and some country is ledge country while elsewhere
# the hills stay rounded (hard_country). Valley floors, the coast and low land are left
# alone. Rivers are cut afterwards and fall over the ledges as waterfalls.
func _add_strata(detail_scale: PackedFloat32Array = PackedFloat32Array()) -> void:
	if not _rules.has("strata"):
		return

	var rules: Dictionary = _rules["strata"]
	var bed: float = float(rules["bed_m"])
	var hard_share: float = float(rules["hard_share"])
	var talus: float = float(rules["talus_part"])           # lower part of a hard bed: steep slope of fallen rock
	var cliff: float = float(rules["cliff_part"])           # then the cliff
	var talus_rate: float = float(rules["talus_steepen"])
	var bench_rate: float = float(rules["bench_flatten"])
	var cliff_rate: float = (1.0 - talus * talus_rate - (1.0 - talus - cliff) * bench_rate) / cliff
	var land_from: float = float(rules["land_from_m"])
	var land_full: float = float(rules["land_full_m"])
	var dip: PackedFloat32Array = _noise_field("strata_dip", float(rules["dip_wavelength_m"]))
	var country: PackedFloat32Array = _noise_field("strata_country", float(rules["country_wavelength_m"]))
	var dip_m: float = float(rules["dip_m"])
	var country_low: float = float(rules["country_from"])
	var country_high: float = float(rules["country_full"])
	var seed_value: int = SeedUtil.purpose_seed(_settings.master_seed, "strata_beds", 0)

	for index in range(samples * samples):
		var h: float = heights[index]

		if h <= land_from:
			continue

		var strength: float = smoothstep(land_from, land_full, h) * smoothstep(country_low, country_high, country[index])

		if not detail_scale.is_empty():
			strength *= detail_scale[index]

		if strength <= 0.0:
			continue

		# Position in the beds: tilted and bent a little.
		var depth: float = (h + dip_m * dip[index]) / bed
		var bed_index: int = int(floor(depth))
		var t: float = depth - float(bed_index)

		if _bed_hash(bed_index, seed_value) >= hard_share:
			continue

		# Each hard bed has its own strength: some are low ledges, some tall cliffs.
		strength *= 0.4 + 0.6 * _bed_hash(bed_index + 7919, seed_value)

		# Height gained within the bed, as a share of the bed (0..1 at t 0..1, like t).
		var rise: float

		if t < talus:
			rise = t * talus_rate
		elif t < talus + cliff:
			rise = talus * talus_rate + (t - talus) * cliff_rate
		else:
			rise = talus * talus_rate + cliff * cliff_rate + (t - talus - cliff) * bench_rate

		heights[index] = h + (rise - t) * bed * strength


static func _bed_hash(bed_index: int, seed_value: int) -> float:
	var x: int = (bed_index * 73856093) ^ seed_value
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0xFFFF) / 65535.0


# A smooth noise field over this frame, -1..1, world-aligned (the same in every tile).
func _noise_field(purpose: String, wavelength_m: float) -> PackedFloat32Array:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SeedUtil.purpose_seed(_settings.master_seed, purpose, 0)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.frequency = spacing_m / wavelength_m
	var tile_samples_w: int = int(_settings.tile_size_m / _settings.map_spacing_m)
	var data: PackedByteArray = WrapNoiseScript.bytes(
		noise, origin_sx, origin_sz, samples, samples, _settings.min_tile * tile_samples_w, _settings.min_tile * tile_samples_w,
		_settings.tiles_x * tile_samples_w, _settings.tiles_z * tile_samples_w, int(ceil(4.0 * wavelength_m / spacing_m))
	)
	var field: PackedFloat32Array = PackedFloat32Array()
	field.resize(samples * samples)

	for index in range(samples * samples):
		field[index] = float(data[index]) / 127.5 - 1.0

	return field


# Owner (2026-10-20): the land is made from its rock. Where a bed of hard rock (sandstone,
# limestone, basalt ...) crops out it stands as a ledge or cliff with a flat bench on top,
# and soft beds between wear into gentle slopes. Same remap as _add_strata, but the beds
# are the real layers of TileGeology at each sample's height: a thick hard layer is split
# into beds about bed_m thick, and how strongly a rock forms ledges comes from
# rock.ledges. Granite and other massive rock (bodies, base rock) stays rounded. Where
# provinces meet the layers jump, so the change is blended across the border.
func _add_rock_beds(detail_scale: PackedFloat32Array) -> void:
	if not _rules.has("strata") or not _rules.has("rock"):
		return

	var rules: Dictionary = _rules["strata"]
	var ledges: Dictionary = _rules["rock"]["ledges"]
	var bed: float = float(rules["bed_m"])
	var talus: float = float(rules["talus_part"])
	var cliff: float = float(rules["cliff_part"])
	var talus_rate: float = float(rules["talus_steepen"])
	var bench_rate: float = float(rules["bench_flatten"])
	var cliff_rate: float = (1.0 - talus * talus_rate - (1.0 - talus - cliff) * bench_rate) / cliff
	var land_from: float = float(rules["land_from_m"])
	var land_full: float = float(rules["land_full_m"])
	var seed_value: int = SeedUtil.purpose_seed(_settings.master_seed, "strata_beds", 0)
	var total: int = samples * samples
	var ledge_of: Dictionary = {}

	for name in ledges.keys():
		ledge_of[name] = float(ledges[name])

	var ledge_by_id: PackedFloat32Array = PackedFloat32Array()
	ledge_by_id.resize(256)

	for id in range(256):
		ledge_by_id[id] = float(ledge_of.get(rock.rock_name(id), 0.0))

	var delta: PackedFloat32Array = PackedFloat32Array()
	delta.resize(total)
	# The beds are found on a softened copy of the land: a cliff steepens the slope several
	# times over, so on the raw land every small bump of the detail noise near a bed's edge
	# would stand up as a spike.
	var clock: int = Time.get_ticks_msec()
	var smooth: PackedFloat32Array = _box_blur(heights, int(rules.get("bed_smooth_samples", 1)))
	_lap("beds: blur", clock)
	clock = Time.get_ticks_msec()

	for index in range(total):
		var h: float = smooth[index]

		if h <= land_from:
			continue

		var strength: float = smoothstep(land_from, land_full, h)

		if not detail_scale.is_empty():
			strength *= detail_scale[index]

		if strength <= 0.0:
			continue

		var layer: Vector4 = rock.layer_at(index, h)
		var ledge: float = ledge_by_id[int(layer.x)]
		var thickness: float = layer.z - layer.y

		if ledge <= 0.0 or thickness <= 1.0 or thickness > 600.0:
			continue

		var beds_in_layer: int = maxi(int(round(thickness / bed)), 1)
		# Tyler (2026-10-21): real beds differ in thickness (log-normal around bed_m, 0.4x to 2.5x) and
		# dip a few degrees, so benches are neither evenly spaced nor dead level.
		var edges: PackedFloat32Array = _bed_edges(int(layer.w), beds_in_layer, thickness, seed_value, rules)
		var fraction: float = clampf((h - layer.y) / thickness, 0.0, 0.99999)
		fraction = clampf(fraction - _dip_shift(int(layer.w), index, seed_value, rules, thickness) * 4.0 * fraction * (1.0 - fraction) / thickness, 0.0, 0.99999)
		var bed_index: int = 0

		while bed_index < beds_in_layer - 1 and fraction >= edges[bed_index + 1]:
			bed_index += 1

		var sub: float = (edges[bed_index + 1] - edges[bed_index]) * thickness
		var t: float = clampf((fraction - edges[bed_index]) / (edges[bed_index + 1] - edges[bed_index]), 0.0, 1.0)
		# Each bed its own strength: some low ledges, some tall cliffs.
		strength *= ledge * (0.4 + 0.6 * _bed_hash(int(layer.w) * 31 + bed_index, seed_value))
		var rise: float

		if t < talus:
			rise = t * talus_rate
		elif t < talus + cliff:
			rise = talus * talus_rate + (t - talus) * cliff_rate
		else:
			rise = talus * talus_rate + cliff * cliff_rate + (t - talus - cliff) * bench_rate

		delta[index] = (rise - t) * sub * strength

	_lap("beds: per-sample beds", clock)
	clock = Time.get_ticks_msec()
	# Blend across province borders (the layers jump there): a box blur of the change on
	# samples within `reach` of a border, in two passes.
	var reach: int = int(rules.get("border_blend_samples", 4))
	var province: PackedByteArray = rock.province
	var near_border: PackedByteArray = PackedByteArray()

	if not force_script and ClassDB.class_exists("GenCore") and ClassDB.instantiate("GenCore").has_method("near_border"):
		near_border = ClassDB.instantiate("GenCore").near_border(province, samples, reach)
	else:
		near_border = near_border_script(province, samples, reach)

	_lap("beds: border search", clock)
	clock = Time.get_ticks_msec()

	for axis in range(2):
		var before: PackedFloat32Array = delta.duplicate()

		for j in range(samples):
			for i in range(samples):
				var index: int = j * samples + i

				if near_border[index] == 0:
					continue

				var sum: float = 0.0
				var count: int = 0

				for k in range(-reach, reach + 1):
					var ni: int = i + (k if axis == 0 else 0)
					var nj: int = j + (k if axis == 1 else 0)

					if ni < 0 or nj < 0 or ni >= samples or nj >= samples:
						continue

					sum += before[nj * samples + ni]
					count += 1

				delta[index] = sum / float(count)

	_lap("beds: border blend", clock)

	for index in range(total):
		if delta[index] != 0.0:
			heights[index] += delta[index]


# 1 where a sample `reach` samples away on an axis (clamped to the frame) lies in another province: the cells whose bed change is blurred.
static func near_border_script(province: PackedByteArray, side: int, reach: int) -> PackedByteArray:
	var near_border: PackedByteArray = PackedByteArray()
	near_border.resize(side * side)
	var steps: Array = [Vector2i(reach, 0), Vector2i(-reach, 0), Vector2i(0, reach), Vector2i(0, -reach)]

	for j in range(side):
		for i in range(side):
			var index: int = j * side + i
			var p: int = province[index]

			for step in steps:
				var ni: int = clampi(i + step.x, 0, side - 1)
				var nj: int = clampi(j + step.y, 0, side - 1)

				if province[nj * side + ni] != p:
					near_border[index] = 1
					break

	return near_border


# Cumulative bed edges (0 to 1) of a rock layer split into `count` beds of uneven thickness; the same for every
# sample of the layer, drawn from the layer and the strata seed.
func _bed_edges(layer_number: int, count: int, thickness: float, seed_value: int, rules: Dictionary) -> PackedFloat32Array:
	var key: int = layer_number * 100003 + int(round(thickness * 10.0)) * 31 + count
	var cache: Dictionary = _edge_cache

	if cache.has(key):
		return cache[key]

	var edges: PackedFloat32Array = PackedFloat32Array()
	edges.append(0.0)
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total_w: float = 0.0
	var spread: float = float(rules.get("bed_sigma", 0.4))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(key) ^ seed_value

	for n in range(count):
		var w: float = 1.0 if spread <= 0.0 else clampf(exp(rng.randfn(0.0, spread)), 0.4, 2.5)
		weights.append(w)
		total_w += w

	var run: float = 0.0

	for n in range(count):
		run += weights[n] / total_w
		edges.append(run)

	edges[count] = 1.0
	cache[key] = edges
	return edges


# How far a bed plane is lifted at a sample by its dip: a slow wave across the country (world position along a
# direction per layer) whose steepest slope is the layer's dip of 1 to 5 degrees and whose height is a third of the
# layer, so neighbouring tiles agree and the layer's own top and bottom stay where they are (the caller fades it to
# zero there).
func _dip_shift(layer_number: int, index: int, seed_value: int, rules: Dictionary, thickness: float) -> float:
	var max_deg: float = float(rules.get("bed_dip_max_deg", 5.0))

	if max_deg <= 0.0:
		return 0.0

	var roll_a: float = _bed_hash(layer_number * 17 + 3, seed_value)
	var roll_b: float = _bed_hash(layer_number * 17 + 5, seed_value)
	var slope: float = tan(deg_to_rad(lerpf(float(rules.get("bed_dip_min_deg", 1.0)), max_deg, roll_a)))
	var angle: float = roll_b * TAU
	var amplitude: float = minf(thickness * 0.3, 12.0)
	var wavelength: float = TAU * amplitude / slope
	var i: int = index % samples
	var j: int = index / samples
	var wx: float = float(origin_sx + i) * spacing_m
	var wz: float = float(origin_sz + j) * spacing_m
	return amplitude * sin(TAU * (wx * cos(angle) + wz * sin(angle)) / wavelength)


# A box blur of `field` (samples x samples) over (2 radius + 1) squared, two passes.
func _box_blur(field: PackedFloat32Array, radius: int) -> PackedFloat32Array:
	if not force_script and ClassDB.class_exists("GenCore") and ClassDB.instantiate("GenCore").has_method("box_blur"):
		return ClassDB.instantiate("GenCore").box_blur(field, samples, radius)

	return box_blur_script(field, samples, radius)


# Tests set this to compare the GDScript loops here with GenCore's (test_gen_core.gd); false in the bake.
static var force_script: bool = false


# The two-pass box blur in GDScript: the reference GenCore.box_blur must match bit for bit.
static func box_blur_script(field: PackedFloat32Array, side: int, radius: int) -> PackedFloat32Array:
	if radius <= 0:
		return field.duplicate()

	var out: PackedFloat32Array = field.duplicate()

	for axis in range(2):
		var source: PackedFloat32Array = out.duplicate()

		for j in range(side):
			for i in range(side):
				var sum: float = 0.0
				var count: int = 0

				for k in range(-radius, radius + 1):
					var ni: int = i + (k if axis == 0 else 0)
					var nj: int = j + (k if axis == 1 else 0)

					if ni < 0 or nj < 0 or ni >= side or nj >= side:
						continue

					sum += source[nj * side + ni]
					count += 1

				out[j * side + i] = sum / float(count)

	return out
