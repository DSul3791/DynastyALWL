extends VoxelGeneratorScript

# Runtime terrain generator, first version (plan step 14).
#
# Turns the 8 m tile maps and lists into voxels on demand. Works for any
# block of any LOD (voxel spacing 1 m at LOD 0, doubling per LOD).
#
#   Surface   Catmull-Rom interpolation of the 8 m height map plus small
#             detail noise (faded out on water, wrap-seamless). The SDF is
#             the vertical distance scaled by the slope, written voxel by
#             voxel only in a thin band around the surface; above and
#             below it the block is filled in runs.
#   Rock      Province layer stacks bent by the layer offset, cover
#             (sediment, with the soil id) on top, granite intrusions with
#             their marble aureole and basalt vents and pipes cutting
#             through. The same rules as the baked surface-rock preview,
#             written as vertical runs per column.
#   Ore       Each ore body shape (lens, halo, pipe, vein, layer, scatter,
#             placer) as vertical runs per column; only near the player
#             (LOD 0 by default).
#   Caves     Passages as capsules and chambers as ellipsoids, carved out
#             of the SDF and emptied of rock, soil and ore.
#
# Tiles are loaded on first use and kept. A tile with no file is open
# ocean (a flat sea floor). Coordinates outside the world wrap around.
# Water is not written into voxels: lakes, rivers and the sea are drawn
# from the water maps.
#
# Thread safety: `_generate_block` runs on worker threads. Loaded tiles are
# read-only; only the tile cache itself is guarded.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const DataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const TOPSOIL_M := 0.4                 # topsoil layer over a clay subsoil
const CLAY_UNDER_MOISTURE := 165       # wet air (0 to 255) from which loam and humus lie on clay
const MUD_DEPTH_M := 3.0               # lake and river beds this far below the water line are mud
const BANK_SOIL_M := 1.0               # banks within this of the water line (or above it) are soil, between is clay
const ORE_LENS := 0
const ORE_HALO := 1
const ORE_PIPE := 2
const ORE_VEIN := 3
const ORE_PLACER := 4
const ORE_LAYER := 5
const ORE_SCATTER := 6

var tiles_dir: String = ""
var tile_size_m: float = 15360.0
var period_m: float = 322560.0
var world_min_m: float = -153600.0
var min_tile: int = -10
var master_seed: int = 0
var tile_count: int = 21
var blocks_generated: int = 0         # blocks made through _generate_block
var generation_usec: int = 0          # time spent on them, summed over threads

var _rules: Dictionary = {}           # tile rules (geology metamorphism)
var _terrain: Dictionary = {}         # tile rules "runtime_terrain"
var _rock_ids: Dictionary = {}
var _resource_ids: Dictionary = {}
var _tiles: Dictionary = {}           # Vector2i -> tile data
var failed_tiles: int = 0              # times a tile file existed but failed to load (a stand-in was used)
var _mutex: Mutex = Mutex.new()
var _prefetching: Dictionary = {}       # Vector2i -> true while a worker thread reads that tile
var _detail: Array = []               # [FastNoiseLite, amplitude_m, wavelength_m]
var _band: float = 3.0
var _detail_max: float = 0.0          # largest possible detail offset (m)
var _placeholder_depth: float = -200.0
var _cave_max_lod: int = 2
var _ore_max_lod: int = 0
var _limestone: int = 3
var _clay: int = -1
var _loam: int = -1
var _humus: int = -1
var _silt: int = -1
var _alluvium: int = -1
var _mud: int = -1
var _marble: int = 9
var _granite: int = 5
var _basalt: int = 7
var _crossfade_cache: Dictionary = {}   # (ix * 256 + iz) -> [cx, sx, cz, sz] precomputed crossfade weights

# `tables` is a TableSet, `tile_rules` the parsed tile_rules.json.
func setup(settings, tile_rules: Dictionary, tables, tiles_directory: String) -> void:
	tiles_dir = tiles_directory
	master_seed = int(settings.master_seed)
	tile_size_m = float(settings.tile_size_m)
	min_tile = int(settings.min_tile)
	tile_count = int(settings.tiles_x)
	world_min_m = float(min_tile) * tile_size_m
	period_m = float(tile_count) * tile_size_m
	_rules = tile_rules
	_terrain = tile_rules.get("runtime_terrain", {})
	_band = float(_terrain.get("sdf_band_voxels", 3))
	_placeholder_depth = float(_terrain.get("placeholder_depth_m", -200.0))
	_cave_max_lod = int(_terrain.get("cave_max_lod", 2))
	_ore_max_lod = int(_terrain.get("ore_max_lod", 0))

	for entry in tables.get_entries("rocks"):
		_rock_ids[str(entry["name"])] = int(entry["id"])

	for entry in tables.get_entries("soils"):
		match str(entry["name"]):
			"clay": _clay = int(entry["id"])
			"loam": _loam = int(entry["id"])
			"forest_humus": _humus = int(entry["id"])
			"silt": _silt = int(entry["id"])
			"alluvium": _alluvium = int(entry["id"])
			"mud": _mud = int(entry["id"])

	for entry in tables.get_entries("resources"):
		_resource_ids[str(entry["name"])] = int(entry["id"])

	_limestone = _rock_ids["limestone"]
	_marble = _rock_ids["marble"]
	_granite = _rock_ids["granite"]
	_basalt = _rock_ids["basalt"]
	_detail = []
	_detail_max = 0.0
	var octave: int = 0

	for entry in _terrain.get("detail", []):
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = SeedUtil.purpose_seed(int(settings.master_seed), "terrain_detail", octave)
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.frequency = 1.0 / float(entry["wavelength_m"])
		_detail.append([noise, float(entry["amplitude_m"]), float(entry["wavelength_m"])])
		_detail_max += float(entry["amplitude_m"])
		octave += 1


func _get_used_channels_mask() -> int:
	return Layout.used_channels_mask()


func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	var started: int = Time.get_ticks_usec()
	generate(out_buffer, origin_in_voxels, lod)
	var spent: int = Time.get_ticks_usec() - started

	# Single voxels asked for by voxel tools are not blocks.
	if out_buffer.get_size().x < 2:
		return

	_mutex.lock()
	blocks_generated += 1
	generation_usec += spent
	_mutex.unlock()


# ---------------------------------------------------------------- tiles

func wrap_x(x: float) -> float:
	return world_min_m + fposmod(x - world_min_m, period_m)


func tile_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(wrap_x(x) / tile_size_m)), int(floor(wrap_x(z) / tile_size_m)))


func get_tile(coord: Vector2i):
	_mutex.lock()
	var data = _tiles.get(coord)
	_mutex.unlock()

	if data != null:
		return data

	data = DataScript.new()
	var path: String = "%s/tile_%d_%d.tile" % [tiles_dir, coord.x, coord.y]

	if FileAccess.file_exists(path):
		# The tile file is read in several passes; a bake that replaces it in between would
		# mix two versions. Reload until the file is the same before and after the read.
		var error: String = ""

		for attempt in range(4):
			var stamp: int = FileAccess.get_modified_time(path)
			var length: int = _file_length(path)
			data = DataScript.new()
			error = data.load_file(path, coord, tile_size_m, _rules, _rock_ids, _resource_ids)

			if FileAccess.get_modified_time(path) == stamp and _file_length(path) == length:
				break

			error = "%s changed while it was being read" % path
			OS.delay_msec(500)

		if error != "":
			# A tile file that exists but would not load (for example while a bake is
			# rewriting it) gets a stand-in for this call only, so it is read again next
			# time; blocks built from a stand-in are not saved (see failed_tiles).
			push_error("terrain: %s (using a stand-in tile for now; blocks built from it are not saved)" % error)
			data = DataScript.new()
			data.make_placeholder(coord, tile_size_m, _placeholder_depth)
			_mutex.lock()
			failed_tiles += 1
			_mutex.unlock()
			return data
	else:
		data.make_placeholder(coord, tile_size_m, _placeholder_depth)

	_mutex.lock()

	# Another thread may have loaded it meanwhile; keep the first.
	if _tiles.has(coord):
		data = _tiles[coord]
	else:
		_tiles[coord] = data

	_mutex.unlock()
	return data


# Is the tile under a world position already in memory? A first look at a tile reads its file (over a second on the main thread).
func tile_cached(x: float, z: float) -> bool:
	var coord: Vector2i = Vector2i(int(floor(wrap_x(x) / tile_size_m)), int(floor(wrap_x(z) / tile_size_m)))
	_mutex.lock()
	var cached: bool = _tiles.has(coord)
	_mutex.unlock()
	return cached


# Reads the tile under a world position on a worker thread so a later surface_height call on the main thread finds it cached.
func prefetch_tile(x: float, z: float) -> void:
	var coord: Vector2i = Vector2i(int(floor(wrap_x(x) / tile_size_m)), int(floor(wrap_x(z) / tile_size_m)))
	_mutex.lock()
	var busy: bool = _tiles.has(coord) or _prefetching.has(coord)

	if not busy:
		_prefetching[coord] = true

	_mutex.unlock()

	if busy:
		return

	WorkerThreadPool.add_task(func():
		get_tile(coord)
		_mutex.lock()
		_prefetching.erase(coord)
		_mutex.unlock())


# Prefetches the tile under a position and any neighbour tile within `margin` metres, so main-thread height lookups near a tile edge never read a file.
func prefetch_around(x: float, z: float, margin: float = 2000.0) -> void:
	prefetch_tile(x, z)

	for dx in [-1.0, 0.0, 1.0]:
		for dz in [-1.0, 0.0, 1.0]:
			if dx == 0.0 and dz == 0.0:
				continue

			var nx: float = x + dx * margin
			var nz: float = z + dz * margin
			prefetch_tile(nx, nz)


# Drops every loaded tile so the next use reads the files again (a bake replaced them).
func forget_tiles() -> void:
	_mutex.lock()
	_tiles.clear()
	_crossfade_cache.clear()
	_mutex.unlock()


func _file_length(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null:
		return -1

	var length: int = file.get_length()
	file.close()
	return length


# ---------------------------------------------------------------- surface

# Ground height at a world position (any position; wraps).
func surface_height(x: float, z: float, lod: int = 0):
	var xw: float = wrap_x(x)
	var zw: float = wrap_x(z)
	var data = get_tile(Vector2i(int(floor(xw / tile_size_m)), int(floor(zw / tile_size_m))))
	return _height(data, xw, zw, float(1 << lod))


func _height(data, xw: float, zw: float, spacing: float) -> float:
	return data.height_at(xw, zw) + _detail_at(data, xw, zw, spacing)


# The detail noise added to the interpolated height.
func _detail_at(data, xw: float, zw: float, spacing: float) -> float:
	if _detail.is_empty() or data.placeholder:
		return 0.0

	var dry: float = 1.0 - data.wet_at(xw, zw)

	if dry <= 0.0:
		return 0.0

	var extra: float = 0.0

	for octave in _detail:
		var wavelength: float = octave[2]

		# Detail finer than two voxels would only alias.
		if wavelength < 2.0 * spacing:
			continue

		extra += float(octave[1]) * _wrapped_noise(octave[0], xw, zw, 4.0 * wavelength)

	return extra * dry


# Detail noise (before the water fade) for a grid of columns starting at
# world (x, z), `spacing` apart, made as noise images in one call per
# octave. Empty near the wrap seam, where the column-by-column path does the
# crossfade.
func _detail_grid(x: float, z: float, count_x: int, count_z: int, spacing: float) -> PackedFloat32Array:
	var end: float = world_min_m + period_m
	var reach: float = float(maxi(count_x, count_z)) * spacing

	for octave in _detail:
		var band: float = 4.0 * float(octave[2])

		if x + reach > end - band or z + reach > end - band:
			return PackedFloat32Array()

	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count_x * count_z)

	for octave in _detail:
		var wavelength: float = octave[2]

		if wavelength < 2.0 * spacing:
			continue

		# A private copy: the offset and frequency are changed per call.
		var noise: FastNoiseLite = (octave[0] as FastNoiseLite).duplicate()
		noise.frequency = spacing / wavelength
		noise.offset = Vector3(x / spacing, z / spacing, 0.0)
		var image: Image = noise.get_image(count_x, count_z, false, false, false)

		if image.get_format() != Image.FORMAT_L8:
			image.convert(Image.FORMAT_L8)

		var bytes: PackedByteArray = image.get_data()
		var amplitude: float = octave[1]

		for n in range(out.size()):
			out[n] += amplitude * (float(bytes[n]) / 127.5 - 1.0)

	return out


# Noise that repeats exactly across the world wrap: inside a band before
# the seam it crossfades with the noise one world width back.
func _wrapped_noise(noise: FastNoiseLite, x: float, z: float, band: float) -> float:
	var end: float = world_min_m + period_m
	var tx: float = clampf((x - (end - band)) / band, 0.0, 1.0)
	var tz: float = clampf((z - (end - band)) / band, 0.0, 1.0)

	if tx == 0.0 and tz == 0.0:
		return noise.get_noise_2d(x, z)

	# Precomputed crossfade weights in a 16x16 grid per octave.
	# Index = (floor(tx * 16), floor(tz * 16)), value = [cx, sx, cz, sz].
	var cache_key: int = int(floor(tx * 16.0)) * 256 + int(floor(tz * 16.0))

	# Build the global crossfade cache once per tile load.
	if not _crossfade_cache.has(cache_key):
		var ix: int = int(floor(tx * 16.0)) % 16
		var iz: int = int(floor(tz * 16.0)) % 16
		_crossfade_cache[cache_key] = [cos(tx * PI * 0.5), sin(tx * PI * 0.5), cos(tz * PI * 0.5), sin(tz * PI * 0.5)]
	else:
		var entry: Array = _crossfade_cache[cache_key]
		if entry != null and entry.size() >= 4:
			return entry[2] * noise.get_noise_2d(x, z) + entry[3] * noise.get_noise_2d(x - period_m, z)
			+ entry[0] * noise.get_noise_2d(x, z - period_m) + entry[1] * noise.get_noise_2d(x - period_m, z - period_m)

	var cx: float = cos(tx * PI * 0.5)
	var sx: float = sin(tx * PI * 0.5)
	var cz: float = cos(tz * PI * 0.5)
	var sz: float = sin(tz * PI * 0.5)
	var near: float = cx * noise.get_noise_2d(x, z) + sx * noise.get_noise_2d(x - period_m, z)
	var far: float = cx * noise.get_noise_2d(x, z - period_m) + sx * noise.get_noise_2d(x - period_m, z - period_m)
	return cz * near + sz * far


# ---------------------------------------------------------------- blocks

func generate(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var size: Vector3i = buffer.get_size()
	var s: int = 1 << lod
	var sf: float = float(s)
	var nx: int = size.x
	var ny: int = size.y
	var nz: int = size.z
	var oy: float = float(origin.y)
	var y_top: float = oy + float(ny - 1) * sf

	buffer.fill(0, Layout.CHANNEL_ROCK)
	buffer.fill(0, Layout.CHANNEL_SOIL)
	buffer.fill(0, Layout.CHANNEL_RESOURCE)
	buffer.fill(Layout.MATERIAL_ROCK + Layout.ROCK_SEDIMENT, Layout.CHANNEL_MATERIAL)

	# Heights on the block's columns plus a one-column ring for slopes.
	var wx: PackedFloat32Array = PackedFloat32Array()
	var wz: PackedFloat32Array = PackedFloat32Array()
	wx.resize(nx + 2)
	wz.resize(nz + 2)

	for i in range(nx + 2):
		wx[i] = wrap_x(float(origin.x) + float(i - 1) * sf)

	for k in range(nz + 2):
		wz[k] = wrap_x(float(origin.z) + float(k - 1) * sf)

	var row: int = nx + 2
	var hs: PackedFloat32Array = PackedFloat32Array()
	hs.resize(row * (nz + 2))
	var column_tile: Array = []
	column_tile.resize(row * (nz + 2))
	var last_coord: Vector2i = Vector2i(1 << 30, 0)
	var last_data = null
	var h_min: float = INF
	var h_max: float = -INF

	for k in range(nz + 2):
		var tz: int = int(floor(wz[k] / tile_size_m))

		for i in range(nx + 2):
			var coord: Vector2i = Vector2i(int(floor(wx[i] / tile_size_m)), tz)

			if coord != last_coord:
				last_coord = coord
				last_data = get_tile(coord)

			var index: int = k * row + i
			column_tile[index] = last_data
			var h: float = last_data.height_at(wx[i], wz[k])
			hs[index] = h

			if i > 0 and k > 0 and i <= nx and k <= nz:
				h_min = minf(h_min, h)
				h_max = maxf(h_max, h)

	# Detail noise only matters near the surface: skip it for blocks well
	# above or below the ground.
	var near_ground: bool = oy - _detail_max <= h_max + 4.0 * _band * sf and y_top + _detail_max >= h_min - 4.0 * _band * sf

	if near_ground and _detail_max > 0.0:
		h_min = INF
		h_max = -INF

		var grid: PackedFloat32Array = _detail_grid(wx[0], wz[0], row, nz + 2, sf)

		for k in range(nz + 2):
			for i in range(nx + 2):
				var index: int = k * row + i
				var data = column_tile[index]
				var extra: float = 0.0

				if grid.is_empty():
					extra = _detail_at(data, wx[i], wz[k], sf)
				elif not data.placeholder:
					extra = grid[index] * (1.0 - data.wet_at(wx[i], wz[k]))

				var h: float = hs[index] + extra
				hs[index] = h

				if i > 0 and k > 0 and i <= nx and k <= nz:
					h_min = minf(h_min, h)
					h_max = maxf(h_max, h)

	# Caves and ore bodies that touch this block.
	var block_box: AABB = AABB(Vector3(float(origin.x), oy, float(origin.z)), Vector3(float(nx - 1), float(ny - 1), float(nz - 1)) * sf)
	var shapes: Array = _cave_shapes(column_tile, block_box, origin, lod) if lod <= _cave_max_lod else []

	# All air above the ground.
	if oy > h_max + _band * sf and shapes.is_empty():
		buffer.fill_f(minf(oy - h_max, 500.0), Layout.CHANNEL_SDF)
		return

	var ore_set: Dictionary = _ores_touching(column_tile, block_box) if lod <= _ore_max_lod else {}
	var has_ore: bool = not ore_set.is_empty() and (not ore_set["shapes"].is_empty() or _any_layers(ore_set))
	var block_bodies: Dictionary = _bodies_touching(column_tile, block_box)

	for k in range(nz):
		for i in range(nx):
			var index: int = (k + 1) * row + (i + 1)
			var data = column_tile[index]
			var h: float = hs[index]
			var gx: float = (hs[index + 1] - hs[index - 1]) / (2.0 * sf)
			var gz: float = (hs[index + row] - hs[index - row]) / (2.0 * sf)
			var norm: float = 1.0 / sqrt(1.0 + gx * gx + gz * gz)
			# The band reaches far enough to meet the neighbors' surfaces.
			var reach: float = (_band + maxf(absf(gx), absf(gz))) * sf
			var j_lo: int = clampi(int(ceil((h - reach - oy) / sf)), 0, ny)
			var j_hi: int = clampi(int(floor((h + reach - oy) / sf)) + 1, 0, ny)

			if j_lo > 0:
				buffer.fill_area_f(-reach * norm, Vector3i(i, 0, k), Vector3i(i + 1, j_lo, k + 1), Layout.CHANNEL_SDF)

			if j_hi < ny:
				buffer.fill_area_f(reach * norm, Vector3i(i, j_hi, k), Vector3i(i + 1, ny, k + 1), Layout.CHANNEL_SDF)

			for j in range(j_lo, j_hi):
				buffer.set_voxel_f((oy + float(j) * sf - h) * norm, i, j, k, Layout.CHANNEL_SDF)

			# The ground material of the column's top; the rock fill below
			# replaces it under the cover.
			var sample: int = -1
			var soil_id: int = -1
			var cover_m: float = NAN
			var offset_m: float = NAN

			if lookups_shared and not data.placeholder:
				sample = data.nearest(wx[i + 1], wz[k + 1])
				soil_id = _ground_soil(data, sample, h, wx[i + 1], wz[k + 1])

				if soil_id <= 0 or h >= oy:
					cover_m = data.cover_at(wx[i + 1], wz[k + 1])
					offset_m = data.offset_at(wx[i + 1], wz[k + 1])

				buffer.fill_area(_surface_material_known(data, sample, soil_id, cover_m, offset_m, h), Vector3i(i, 0, k), Vector3i(i + 1, ny, k + 1), Layout.CHANNEL_MATERIAL)
			else:
				buffer.fill_area(_surface_material(data, wx[i + 1], wz[k + 1], h), Vector3i(i, 0, k), Vector3i(i + 1, ny, k + 1), Layout.CHANNEL_MATERIAL)

			# Nothing solid in this column of the block.
			if h < oy:
				continue

			_fill_rock_column(buffer, data, block_bodies.get(data.tile, []), i, k, wx[i + 1], wz[k + 1], h, oy, sf, ny, sample, soil_id, cover_m, offset_m)

			if has_ore:
				_fill_ore_column(buffer, data, ore_set, i, k, wx[i + 1], wz[k + 1], h, oy, sf, ny, origin, sample, cover_m, offset_m)

	if not shapes.is_empty():
		_carve_caves(buffer, shapes, origin, sf, size)


# True where the soil at the surface sits on a clay subsoil.
func _clay_under(soil: int, moisture: int) -> bool:
	return _clay >= 0 and moisture >= CLAY_UNDER_MOISTURE and (soil == _loam or soil == _humus or soil == _silt or soil == _alluvium)


# The soil of a lake, pond or river cell, chosen by how far the ground lies
# below the water line (owner, 2026-10-19: the baked gravel and silt drew the
# beds and banks grey): mud on the bed, wet clay on the lower bank, alluvium
# near and above the water line. Other cells keep their baked soil.
func _ground_soil(data, sample: int, h: float, x: float, z: float) -> int:
	var soil: int = data.soil[sample]

	if _mud < 0 or data.placeholder:
		return soil

	# Owner (2026-10-21, Tyler's finding): the bank bands followed the 8 m cells (square patches of
	# baked bank soil, stepped mud/clay lines). The water line and the nearness of water are read
	# bilinearly from the four samples around the column and the depth is jittered a little, so the
	# bands run as soft, wandering curves.
	var side: int = data.samples
	var fx: float = clampf((x - data.x0) / data.spacing_m, 0.0, float(side - 1) - 0.001)
	var fz: float = clampf((z - data.z0) / data.spacing_m, 0.0, float(side - 1) - 0.001)
	var i0: int = int(fx)
	var j0: int = int(fz)
	var tx: float = fx - float(i0)
	var tz: float = fz - float(j0)
	var near: PackedByteArray = data.near_water()
	var water_w: float = 0.0
	var level_sum: float = 0.0
	var near_w: float = 0.0

	for c in 4:
		var wgt: float = (tx if (c & 1) == 1 else 1.0 - tx) * (tz if (c & 2) == 2 else 1.0 - tz)
		var k: int = (j0 + (c >> 1)) * side + i0 + (c & 1)
		near_w += wgt * float(near[k])
		var kind: int = data.water_class[k]

		if (kind == 2 or kind == 3) and not is_nan(data.water_surface[k]):
			water_w += wgt
			level_sum += wgt * data.water_surface[k]

	if near_w <= 0.0:
		return soil

	var jitter: float = _value_noise(x / 2.5, z / 2.5)

	if water_w <= 0.02:
		# Dry bank beside the water: grassy, broken up along its edge.
		return _alluvium if near_w > 0.9 * jitter else soil

	var depth: float = level_sum / water_w - h + (jitter - 0.5) * 0.8

	if depth > MUD_DEPTH_M:
		return _mud

	return _clay if depth > BANK_SOIL_M else _alluvium


# Smooth value noise in 0..1 on a unit grid (deterministic, no seed needed for looks).
static func _value_noise(x: float, z: float) -> float:
	var xi: float = floorf(x)
	var zi: float = floorf(z)
	var u: float = x - xi
	var v: float = z - zi
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var a: float = _hash01(int(xi), 0, int(zi), 7)
	var b: float = _hash01(int(xi) + 1, 0, int(zi), 7)
	var c: float = _hash01(int(xi), 0, int(zi) + 1, 7)
	var d: float = _hash01(int(xi) + 1, 0, int(zi) + 1, 7)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


# What the top of a column looks like: its soil, else the rock at the
# bedrock surface (intrusions and vents are not looked at).
func _surface_material(data, x: float, z: float, h: float) -> int:
	if data.placeholder:
		return Layout.MATERIAL_ROCK + Layout.ROCK_SEDIMENT

	var sample: int = data.nearest(x, z)
	var soil: int = _ground_soil(data, sample, h, x, z)

	if soil > 0:
		return soil

	var p: int = data.province[sample]
	var depth: float = data.prov_datum[p] + data.offset_at(x, z) - (h - data.cover_at(x, z))
	return Layout.MATERIAL_ROCK + data.layered_rock(p, maxf(depth, 0.0), _limestone, _marble)


# _surface_material from lookups already made for the column (not a placeholder tile): the nearest sample,
# its ground soil, and (needed when there is no soil) the cover and layer offset at the column.
func _surface_material_known(data, sample: int, soil: int, cover_m: float, offset_m: float, h: float) -> int:
	if soil > 0:
		return soil

	var p: int = data.province[sample]
	var depth: float = data.prov_datum[p] + offset_m - (h - cover_m)
	return Layout.MATERIAL_ROCK + data.layered_rock(p, maxf(depth, 0.0), _limestone, _marble)


# Rock and soil of one column: cover on top, layered bedrock below, then
# the bodies that cut through the layers.
func _fill_rock_column(buffer: VoxelBuffer, data, bodies: Array, i: int, k: int, x: float, z: float, h: float, oy: float, sf: float, ny: int, known_sample: int = -1, known_soil: int = -1, known_cover: float = NAN, known_offset: float = NAN) -> void:
	var j_surface: int = mini(int(floor((h - oy) / sf)), ny - 1)

	if data.placeholder:
		buffer.fill_area(Layout.ROCK_SEDIMENT, Vector3i(i, 0, k), Vector3i(i + 1, j_surface + 1, k + 1), Layout.CHANNEL_ROCK)
		return

	# Ground material below the cover is the rock itself, so cave walls and
	# dug holes show their stone (the cover band keeps the surface material).

	var cover_m: float = known_cover if not is_nan(known_cover) else data.cover_at(x, z)
	var yb: float = h - cover_m
	var j_bed: int = mini(int(floor((yb - oy) / sf)), ny - 1)
	var sample: int = known_sample if known_sample >= 0 else data.nearest(x, z)

	if j_surface > j_bed:
		var lo: int = maxi(j_bed + 1, 0)
		var soil: int = known_soil if known_soil >= 0 else _ground_soil(data, sample, h, x, z)
		buffer.fill_area(Layout.ROCK_SEDIMENT, Vector3i(i, lo, k), Vector3i(i + 1, j_surface + 1, k + 1), Layout.CHANNEL_ROCK)
		buffer.fill_area(soil, Vector3i(i, lo, k), Vector3i(i + 1, j_surface + 1, k + 1), Layout.CHANNEL_SOIL)

		# Wet lowland loam, humus, silt and alluvium lies on clay: a topsoil
		# layer on the surface and clay below it (owner, 2026-10-17).
		if _clay_under(soil, data.moisture[sample]):
			var j_clay: int = mini(int(floor((h - TOPSOIL_M - oy) / sf)), j_surface)

			if j_clay >= lo:
				buffer.fill_area(_clay, Vector3i(i, lo, k), Vector3i(i + 1, j_clay + 1, k + 1), Layout.CHANNEL_SOIL)
				buffer.fill_area(_clay, Vector3i(i, lo, k), Vector3i(i + 1, j_clay + 1, k + 1), Layout.CHANNEL_MATERIAL)

	if j_bed < 0:
		return

	var p: int = data.province[sample]
	var top: float = data.prov_datum[p] + (known_offset if not is_nan(known_offset) else data.offset_at(x, z))
	var j: int = j_bed

	while j >= 0:
		var y: float = oy + float(j) * sf
		var depth: float = top - y
		var rock: int = data.layered_rock(p, depth, _limestone, _marble)
		var step: float = data.next_boundary(p, depth)
		var count: int = j + 1 if step == INF else clampi(int(ceil(step / sf)), 1, j + 1)
		buffer.fill_area(rock, Vector3i(i, j - count + 1, k), Vector3i(i + 1, j + 1, k + 1), Layout.CHANNEL_ROCK)
		buffer.fill_area(Layout.MATERIAL_ROCK + rock, Vector3i(i, j - count + 1, k), Vector3i(i + 1, j + 1, k + 1), Layout.CHANNEL_MATERIAL)
		j -= count

	var point: Vector2 = Vector2(x, z)

	if bodies_prepared:
		_fill_bodies(buffer, bodies, point, yb, i, k, oy, sf, ny)
		return

	for body in bodies:
		if not body["rect"].has_point(point):
			continue

		if int(body["kind"]) == 1:
			if point.distance_squared_to(body["center"]) <= float(body["radius"]) * float(body["radius"]):
				_fill_run(buffer, _basalt, float(body["bottom"]), minf(float(body["top"]), yb), i, k, oy, sf, ny, Layout.CHANNEL_ROCK)
				_fill_run(buffer, Layout.MATERIAL_ROCK + _basalt, float(body["bottom"]), minf(float(body["top"]), yb), i, k, oy, sf, ny, Layout.CHANNEL_MATERIAL)

			continue

		var local: Vector2 = (point - body["center"]).rotated(-float(body["angle"]))
		var q: float = pow(local.x / float(body["ra"]), 2.0) + pow(local.y / float(body["rb"]), 2.0)

		if q <= 1.0:
			_fill_run(buffer, _granite, float(body["bottom"]), minf(float(body["top"]) - float(body["roof_drop"]) * q, yb), i, k, oy, sf, ny, Layout.CHANNEL_ROCK)
			_fill_run(buffer, Layout.MATERIAL_ROCK + _granite, float(body["bottom"]), minf(float(body["top"]) - float(body["roof_drop"]) * q, yb), i, k, oy, sf, ny, Layout.CHANNEL_MATERIAL)
			continue

		var outer_a: float = float(body["ra"]) + float(body["aureole"])
		var outer_b: float = float(body["rb"]) + float(body["aureole"])

		if pow(local.x / outer_a, 2.0) + pow(local.y / outer_b, 2.0) > 1.0:
			continue

		# Contact aureole: limestone turns to marble.
		var lo: int = maxi(int(ceil((float(body["bottom"]) - oy) / sf)), 0)
		var hi: int = mini(int(floor((minf(float(body["aureole_top"]), yb) - oy) / sf)), ny - 1)

		for jj in range(lo, hi + 1):
			if buffer.get_voxel(i, jj, k, Layout.CHANNEL_ROCK) == _limestone:
				buffer.set_voxel(_marble, i, jj, k, Layout.CHANNEL_ROCK)
				buffer.set_voxel(Layout.MATERIAL_ROCK + _marble, i, jj, k, Layout.CHANNEL_MATERIAL)


# The intrusions, vents and pipes over one column, from _prepared_body arrays: the same voxels as the
# dictionary loop it replaced, with the keys read once per block and each run's range worked out once
# for both channels.
func _fill_bodies(buffer: VoxelBuffer, bodies: Array, point: Vector2, yb: float, i: int, k: int, oy: float, sf: float, ny: int) -> void:
	for body in bodies:
		if not body[B_RECT].has_point(point):
			continue

		if body[B_KIND] == 1:
			if point.distance_squared_to(body[B_CENTER]) <= body[B_RADIUS] * body[B_RADIUS]:
				_fill_rock_run(buffer, _basalt, body[B_BOTTOM], minf(body[B_TOP], yb), i, k, oy, sf, ny)

			continue

		var local: Vector2 = (point - body[B_CENTER]).rotated(body[B_NEG_ANGLE])
		var q: float = pow(local.x / body[B_RA], 2.0) + pow(local.y / body[B_RB], 2.0)

		if q <= 1.0:
			_fill_rock_run(buffer, _granite, body[B_BOTTOM], minf(body[B_TOP] - body[B_ROOF_DROP] * q, yb), i, k, oy, sf, ny)
			continue

		if pow(local.x / body[B_OUTER_A], 2.0) + pow(local.y / body[B_OUTER_B], 2.0) > 1.0:
			continue

		# Contact aureole: limestone turns to marble.
		var lo: int = maxi(int(ceil((body[B_BOTTOM] - oy) / sf)), 0)
		var hi: int = mini(int(floor((minf(body[B_AUREOLE_TOP], yb) - oy) / sf)), ny - 1)

		for jj in range(lo, hi + 1):
			if buffer.get_voxel(i, jj, k, Layout.CHANNEL_ROCK) == _limestone:
				buffer.set_voxel(_marble, i, jj, k, Layout.CHANNEL_ROCK)
				buffer.set_voxel(Layout.MATERIAL_ROCK + _marble, i, jj, k, Layout.CHANNEL_MATERIAL)


# A rock between two heights in one column: the rock id and its material, the range worked out once.
func _fill_rock_run(buffer: VoxelBuffer, rock: int, y_lo: float, y_hi: float, i: int, k: int, oy: float, sf: float, ny: int) -> void:
	var lo: int = maxi(int(ceil((y_lo - oy) / sf)), 0)
	var hi: int = mini(int(floor((y_hi - oy) / sf)), ny - 1)

	if hi >= lo:
		buffer.fill_area(rock, Vector3i(i, lo, k), Vector3i(i + 1, hi + 1, k + 1), Layout.CHANNEL_ROCK)
		buffer.fill_area(Layout.MATERIAL_ROCK + rock, Vector3i(i, lo, k), Vector3i(i + 1, hi + 1, k + 1), Layout.CHANNEL_MATERIAL)



# Cold generation speed (owner queue, 2026-10-21): off, bodies buried under a block are tested anyway
# (the reference run of test_generation_speed.gd, which checks the output is byte identical).
var buried_bodies_skipped: bool = true
var ore_columns_skipped: bool = true
var bodies_prepared: bool = true
var lookups_shared: bool = true       # a column's cover, layer offset, nearest sample and ground soil are read once, not once per fill step

# A body's numbers read once for the block as an array (indices B_*): the per-column loop in
# _fill_rock_column was reading a dozen dictionary keys per column and body.
const B_RECT := 0
const B_KIND := 1
const B_CENTER := 2
const B_NEG_ANGLE := 3
const B_RA := 4
const B_RB := 5
const B_BOTTOM := 6
const B_TOP := 7
const B_ROOF_DROP := 8
const B_AUREOLE_TOP := 9
const B_OUTER_A := 10
const B_OUTER_B := 11
const B_RADIUS := 12


static func _prepared_body(body: Dictionary) -> Array:
	if int(body["kind"]) == 1:
		return [body["rect"], 1, body["center"], 0.0, 0.0, 0.0, float(body["bottom"]), float(body["top"]), 0.0, 0.0, 0.0, 0.0, float(body["radius"])]

	return [
		body["rect"], 0, body["center"], -float(body["angle"]), float(body["ra"]), float(body["rb"]), float(body["bottom"]),
		float(body["top"]), float(body["roof_drop"]), float(body["aureole_top"]), float(body["ra"]) + float(body["aureole"]),
		float(body["rb"]) + float(body["aureole"]), 0.0,
	]



# Intrusions, vents and pipes whose bounds touch the block, per tile.
func _bodies_touching(column_tile: Array, box: AABB) -> Dictionary:
	var out: Dictionary = {}
	var rect: Rect2 = Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
	var shift: Vector2 = Vector2(wrap_x(rect.position.x) - rect.position.x, wrap_x(rect.position.y) - rect.position.y)
	var local_rect: Rect2 = Rect2(rect.position + shift, rect.size)

	for data in column_tile:
		if data == null or data.placeholder or out.has(data.tile):
			continue

		var list: Array = []

		for body in data.bodies:
			if body["rect"].intersects(local_rect, true) and float(body["bottom"]) <= box.end.y:
				# A body whose top (its aureole's top for an intrusion) is under the block's bottom
				# changes no voxel in it: left out, the columns of a surface block do not test it.
				if buried_bodies_skipped and maxf(float(body["top"]), float(body.get("aureole_top", -INF))) < box.position.y:
					continue

				list.append(_prepared_body(body) if bodies_prepared else body)

		out[data.tile] = list

	return out


static func _any_layers(ore_set: Dictionary) -> bool:
	for by_province in ore_set["layers"].values():
		if not by_province.is_empty():
			return true

	return false


# Fills voxels with y in [y_lo, y_hi] of one column.
static func _fill_run(buffer: VoxelBuffer, value: int, y_lo: float, y_hi: float, i: int, k: int, oy: float, sf: float, ny: int, channel: int) -> void:
	var lo: int = maxi(int(ceil((y_lo - oy) / sf)), 0)
	var hi: int = mini(int(floor((y_hi - oy) / sf)), ny - 1)

	if hi >= lo:
		buffer.fill_area(value, Vector3i(i, lo, k), Vector3i(i + 1, hi + 1, k + 1), channel)


# Ore bodies that can touch the block: {"shapes": [[tile data, ore], ...],
# "layers": {tile coord: {province index: [ore, ...]}}}. Layer and scatter
# bodies are looked up by the province under each column.
func _ores_touching(column_tile: Array, box: AABB) -> Dictionary:
	var seen: Dictionary = {}
	var shapes: Array = []
	var layers: Dictionary = {}
	var rect: Rect2 = Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))

	for data in column_tile:
		if data == null or data.placeholder or seen.has(data.tile):
			continue

		seen[data.tile] = true
		# The block may sit one world width away from the tile's own coordinates.
		var shift: Vector2 = Vector2(wrap_x(rect.position.x) - rect.position.x, wrap_x(rect.position.y) - rect.position.y)
		var local_rect: Rect2 = Rect2(rect.position + shift, rect.size)
		var by_province: Dictionary = {}

		for ore in data.ores:
			if not ore["rect"].intersects(local_rect, true):
				continue

			if float(ore["y_max"]) < box.position.y or float(ore["y_min"]) > box.end.y:
				continue

			if int(ore["code"]) >= ORE_LAYER:
				var p: int = int(ore["province_index"])

				if not by_province.has(p):
					by_province[p] = []

				by_province[p].append(ore)
			else:
				shapes.append([data, ore])

		layers[data.tile] = by_province

	return {"shapes": shapes, "layers": layers}


# Ore runs of one column. Ore only replaces solid voxels.
func _fill_ore_column(buffer: VoxelBuffer, data, ore_set: Dictionary, i: int, k: int, x: float, z: float, h_ground: float, oy: float, sf: float, ny: int, origin: Vector3i, known_sample: int = -1, known_cover: float = NAN, known_offset: float = NAN) -> void:
	var point: Vector2 = Vector2(x, z)

	# Cold generation speed (owner queue, 2026-10-21): most columns of an ore block have no ore of any
	# kind in them (no shape's outline over the column, no layer ore in its province), and then
	# nothing below writes a voxel, so the cover and node work is skipped.
	if ore_columns_skipped:
		var touched: bool = false

		for pair in ore_set["shapes"]:
			if pair[0] == data and pair[1]["rect"].has_point(point):
				touched = true
				break

		if not touched:
			var layers_here: Dictionary = ore_set["layers"].get(data.tile, {})

			if layers_here.is_empty() or not layers_here.has(data.province[known_sample if known_sample >= 0 else data.nearest(x, z)]):
				return

	# Owner (2026-10-20): ore under soil stays hidden. Where loose cover (dirt, mud, humus) lies
	# over the rock, ore stops a cap below the surface (at least ore_cap.min_m, and the full
	# cover); bare rock keeps its ore showing, and in a small hashed share of small cells
	# (ore_cap.node_share) the ore is left exposed as a node, its top voxels turned to rock so
	# what is seen matches the label.
	var cap_rules: Dictionary = _rules.get("ore_cap", {})
	var cover: float = known_cover if not is_nan(known_cover) else data.cover_at(x, z)
	var node_cell: float = maxf(float(cap_rules.get("node_cell_m", 24.0)), 1.0)
	var exposed: bool = cover <= 0.0 or _hash01(int(floor(x / node_cell)), 0, int(floor(z / node_cell)), 7121) < float(cap_rules.get("node_share", 0.04))
	var h: float = h_ground

	if not exposed:
		h = h_ground - maxf(maxf(cover, float(cap_rules.get("min_m", 1.5))), sf)

	for pair in ore_set["shapes"]:
		if pair[0] != data:
			continue

		var ore: Dictionary = pair[1]

		if not ore["rect"].has_point(point):
			continue

		var id: int = ore["resource_id"]
		var code: int = ore["code"]

		if code == ORE_LENS:
			var center: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][2]))
			var local: Vector2 = (point - center).rotated(-float(ore["angle"]))
			var q: float = pow(local.x / float(ore["radius_a_m"]), 2.0) + pow(local.y / float(ore["radius_b_m"]), 2.0)

			if q < 1.0:
				var half: float = 0.5 * float(ore["thickness_m"]) * sqrt(1.0 - q)
				_fill_run(buffer, id, float(ore["center"][1]) - half, minf(float(ore["center"][1]) + half, h), i, k, oy, sf, ny, Layout.CHANNEL_RESOURCE)
		elif code == ORE_HALO:
			# A dome-shaped shell over its feature: the top drops by the
			# thickness at the rim (as the baked outcrop check assumes).
			var center: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][1]))
			var local: Vector2 = (point - center).rotated(-float(ore.get("angle", 0.0)))
			var q: float = pow(local.x / float(ore["radius_a_m"]), 2.0) + pow(local.y / float(ore["radius_b_m"]), 2.0)

			if q < 1.0:
				var thickness: float = float(ore["thickness_m"])
				var top: float = float(ore["top_y"]) - thickness * q
				_fill_run(buffer, id, top - thickness, minf(top, h), i, k, oy, sf, ny, Layout.CHANNEL_RESOURCE)
		elif code == ORE_PIPE:
			var center: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][1]))

			if point.distance_to(center) <= float(ore["radius_m"]):
				_fill_run(buffer, id, float(ore["bottom_y"]), minf(float(ore["top_y"]), h), i, k, oy, sf, ny, Layout.CHANNEL_RESOURCE)
		elif code == ORE_VEIN:
			_vein_column(buffer, ore, id, point, h, i, k, oy, sf, ny)
		elif code == ORE_PLACER:
			var polyline: PackedVector2Array = ore["polyline"]
			var width: float = float(ore.get("width_m", 4.0))

			for n in range(polyline.size() - 1):
				if Geometry2D.get_closest_point_to_segment(point, polyline[n], polyline[n + 1]).distance_to(point) <= 0.5 * width:
					_fill_run(buffer, id, h_ground - float(ore.get("thickness_m", 1.0)), h_ground, i, k, oy, sf, ny, Layout.CHANNEL_RESOURCE)
					break

	# An exposed node on covered ground: the ore's top voxels turn to rock (the host rock
	# below the cover), so the ground shows an outcrop instead of grass over ore.
	if exposed and cover > 0.0:
		var j_top: int = mini(int(floor((h_ground - oy) / sf)), ny - 1)

		if j_top >= 0 and buffer.get_voxel(i, j_top, k, Layout.CHANNEL_RESOURCE) > 0:
			var j_bed: int = clampi(int(floor((h_ground - cover - oy) / sf)), 0, ny - 1)
			var host_rock: int = buffer.get_voxel(i, j_bed, k, Layout.CHANNEL_ROCK)
			buffer.fill_area(Layout.MATERIAL_ROCK + host_rock, Vector3i(i, maxi(j_bed, 0), k), Vector3i(i + 1, j_top + 1, k + 1), Layout.CHANNEL_MATERIAL)

	var by_province: Dictionary = ore_set["layers"].get(data.tile, {})

	if by_province.is_empty():
		return

	var p: int = data.province[known_sample if known_sample >= 0 else data.nearest(x, z)]

	if not by_province.has(p):
		return

	var top: float = data.prov_datum[p] + (known_offset if not is_nan(known_offset) else data.offset_at(x, z))
	var yb: float = h_ground - cover

	for ore in by_province[p]:
		_layer_column(buffer, ore, top, yb, i, k, oy, sf, ny, origin)


# A steep sheet along a fault trace: at height y the sheet sits
# (top - y) / tan(dip) away from the trace on its dip side.
func _vein_column(buffer: VoxelBuffer, ore: Dictionary, id: int, point: Vector2, h: float, i: int, k: int, oy: float, sf: float, ny: int) -> void:
	var a: Vector2 = Vector2(float(ore["points"][0][0]), float(ore["points"][0][1]))
	var b: Vector2 = Vector2(float(ore["points"][1][0]), float(ore["points"][1][1]))
	var along: Vector2 = b - a
	var length: float = along.length()

	if length <= 0.0:
		return

	along /= length
	var t: float = (point - a).dot(along)

	if t < 0.0 or t > length:
		return

	var normal: Vector2 = Vector2(-along.y, along.x) * float(ore["dip_side"])
	var d: float = (point - a).dot(normal)
	var slope: float = tan(deg_to_rad(float(ore["dip_deg"])))
	var half: float = 0.5 * maxf(float(ore["width_m"]), sf)
	# offset(y) = (top - y) / slope must lie in [d - half, d + half].
	var top: float = float(ore["top_y"])
	var y_hi: float = top - (d - half) * slope
	var y_lo: float = top - (d + half) * slope
	_fill_run(buffer, id, maxf(y_lo, float(ore["bottom_y"])), minf(minf(y_hi, top), h), i, k, oy, sf, ny, Layout.CHANNEL_RESOURCE)


# A band at a fixed depth in every layer cycle of one province (coal seams,
# salt layers), or a thin random scatter in such a band (gems in their
# host rock). `top` is the province datum plus the layer offset here, `yb`
# the bedrock surface.
func _layer_column(buffer: VoxelBuffer, ore: Dictionary, top: float, yb: float, i: int, k: int, oy: float, sf: float, ny: int, origin: Vector3i) -> void:
	var id: int = ore["resource_id"]
	var cycle: float = float(ore["cycle_m"])
	var start: float = float(ore["depth_below_datum_m"])
	var thickness: float = float(ore["thickness_m"])
	var repeat_to: float = float(ore["repeat_to_m"])
	var scatter: bool = int(ore["code"]) == ORE_SCATTER
	var host: int = int(ore.get("host_id", -1))
	var density: float = float(ore.get("density", 1.0))
	var block_top: float = oy + float(ny - 1) * sf
	# Cycles whose band can reach this block.
	var first: int = maxi(int(floor((top - block_top - start - thickness) / cycle)), 0)
	var last: int = int(floor((top - oy - start) / cycle))

	for n in range(first, last + 1):
		var depth_top: float = start + float(n) * cycle

		if depth_top >= repeat_to:
			break

		var y_hi: float = minf(top - depth_top, yb)
		var y_lo: float = top - depth_top - thickness

		if not scatter:
			_fill_run(buffer, id, y_lo, y_hi, i, k, oy, sf, ny, Layout.CHANNEL_RESOURCE)
			continue

		var lo: int = maxi(int(ceil((y_lo - oy) / sf)), 0)
		var hi: int = mini(int(floor((y_hi - oy) / sf)), ny - 1)

		for j in range(lo, hi + 1):
			if host >= 0 and buffer.get_voxel(i, j, k, Layout.CHANNEL_ROCK) != host:
				continue

			if _hash01(origin.x + i, origin.y + j, origin.z + k, int(ore["local_id"])) < density:
				buffer.set_voxel(id, i, j, k, Layout.CHANNEL_RESOURCE)


static func _hash01(x: int, y: int, z: int, salt: int) -> float:
	var v: int = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (salt * 2654435761)
	v = (v ^ (v >> 13)) * 1274126177
	v = v ^ (v >> 16)
	return float(v & 0xffffff) / 16777216.0


# ---------------------------------------------------------------- caves

# Cave shapes (capsules and chambers) whose boxes touch the block, moved
# into the block's own coordinates when it sits across the wrap.
func _cave_shapes(column_tile: Array, box: AABB, origin: Vector3i, lod: int) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	var shift: Vector3 = Vector3(wrap_x(float(origin.x)) - float(origin.x), 0.0, wrap_x(float(origin.z)) - float(origin.z))
	var local_box: AABB = AABB(box.position + shift, box.size)

	for data in column_tile:
		if data == null or data.placeholder or seen.has(data.tile):
			continue

		seen[data.tile] = true

		for cave in data.caves:
			if not cave["aabb"].intersects(local_box):
				continue

			for capsule in cave["capsules"]:
				if capsule["aabb"].intersects(local_box):
					out.append([0, capsule["a"] - shift, capsule["b"] - shift, float(capsule["rw"]), float(capsule["rh"]), AABB(capsule["aabb"].position - shift, capsule["aabb"].size)])

			for chamber in cave["chambers"]:
				if chamber["aabb"].intersects(local_box):
					out.append([1, chamber["center"] - shift, Vector3.ZERO, float(chamber["r"]), float(chamber["rh"]), AABB(chamber["aabb"].position - shift, chamber["aabb"].size)])

	return out


func _carve_caves(buffer: VoxelBuffer, shapes: Array, origin: Vector3i, sf: float, size: Vector3i) -> void:
	var o: Vector3 = Vector3(origin)

	for shape in shapes:
		var box: AABB = shape[5]
		var i0: int = maxi(int(ceil((box.position.x - o.x) / sf)), 0)
		var i1: int = mini(int(floor((box.end.x - o.x) / sf)), size.x - 1)
		var j0: int = maxi(int(ceil((box.position.y - o.y) / sf)), 0)
		var j1: int = mini(int(floor((box.end.y - o.y) / sf)), size.y - 1)
		var k0: int = maxi(int(ceil((box.position.z - o.z) / sf)), 0)
		var k1: int = mini(int(floor((box.end.z - o.z) / sf)), size.z - 1)
		var rw: float = shape[3]
		var squash: float = rw / maxf(float(shape[4]), 0.1)
		var a: Vector3 = shape[1]
		var b: Vector3 = shape[2]
		a.y *= squash
		b.y *= squash

		for k in range(k0, k1 + 1):
			for i in range(i0, i1 + 1):
				for j in range(j0, j1 + 1):
					var p: Vector3 = Vector3(o.x + float(i) * sf, (o.y + float(j) * sf) * squash, o.z + float(k) * sf)
					var d: float

					if int(shape[0]) == 0:
						d = p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)) - rw
					else:
						d = p.distance_to(a) - rw

					if d >= 2.0 * sf:
						continue

					var current: float = buffer.get_voxel_f(i, j, k, Layout.CHANNEL_SDF)

					if -d > current:
						buffer.set_voxel_f(-d, i, j, k, Layout.CHANNEL_SDF)

					if d < 0.0:
						buffer.set_voxel(0, i, j, k, Layout.CHANNEL_ROCK)
						buffer.set_voxel(0, i, j, k, Layout.CHANNEL_SOIL)
						buffer.set_voxel(0, i, j, k, Layout.CHANNEL_RESOURCE)
