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
var _mutex: Mutex = Mutex.new()
var _detail: Array = []               # [FastNoiseLite, amplitude_m, wavelength_m]
var _band: float = 3.0
var _detail_max: float = 0.0          # largest possible detail offset (m)
var _placeholder_depth: float = -200.0
var _cave_max_lod: int = 2
var _ore_max_lod: int = 0
var _limestone: int = 3
var _marble: int = 9
var _granite: int = 5
var _basalt: int = 7


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
		var error: String = data.load_file(path, coord, tile_size_m, _rules, _rock_ids, _resource_ids)

		if error != "":
			push_error("terrain: %s" % error)
			data = DataScript.new()
			data.make_placeholder(coord, tile_size_m, _placeholder_depth)
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

			# Nothing solid in this column of the block.
			if h < oy:
				continue

			_fill_rock_column(buffer, data, block_bodies.get(data.tile, []), i, k, wx[i + 1], wz[k + 1], h, oy, sf, ny)

			if has_ore:
				_fill_ore_column(buffer, data, ore_set, i, k, wx[i + 1], wz[k + 1], h, oy, sf, ny, origin)

	if not shapes.is_empty():
		_carve_caves(buffer, shapes, origin, sf, size)


# Rock and soil of one column: cover on top, layered bedrock below, then
# the bodies that cut through the layers.
func _fill_rock_column(buffer: VoxelBuffer, data, bodies: Array, i: int, k: int, x: float, z: float, h: float, oy: float, sf: float, ny: int) -> void:
	var j_surface: int = mini(int(floor((h - oy) / sf)), ny - 1)

	if data.placeholder:
		buffer.fill_area(Layout.ROCK_SEDIMENT, Vector3i(i, 0, k), Vector3i(i + 1, j_surface + 1, k + 1), Layout.CHANNEL_ROCK)
		return

	var cover_m: float = data.cover_at(x, z)
	var yb: float = h - cover_m
	var j_bed: int = mini(int(floor((yb - oy) / sf)), ny - 1)
	var sample: int = data.nearest(x, z)

	if j_surface > j_bed:
		var lo: int = maxi(j_bed + 1, 0)
		buffer.fill_area(Layout.ROCK_SEDIMENT, Vector3i(i, lo, k), Vector3i(i + 1, j_surface + 1, k + 1), Layout.CHANNEL_ROCK)
		buffer.fill_area(data.soil[sample], Vector3i(i, lo, k), Vector3i(i + 1, j_surface + 1, k + 1), Layout.CHANNEL_SOIL)

	if j_bed < 0:
		return

	var p: int = data.province[sample]
	var top: float = data.prov_datum[p] + data.offset_at(x, z)
	var j: int = j_bed

	while j >= 0:
		var y: float = oy + float(j) * sf
		var depth: float = top - y
		var rock: int = data.layered_rock(p, depth, _limestone, _marble)
		var step: float = data.next_boundary(p, depth)
		var count: int = j + 1 if step == INF else clampi(int(ceil(step / sf)), 1, j + 1)
		buffer.fill_area(rock, Vector3i(i, j - count + 1, k), Vector3i(i + 1, j + 1, k + 1), Layout.CHANNEL_ROCK)
		j -= count

	var point: Vector2 = Vector2(x, z)

	for body in bodies:
		if not body["rect"].has_point(point):
			continue

		if int(body["kind"]) == 1:
			if point.distance_squared_to(body["center"]) <= float(body["radius"]) * float(body["radius"]):
				_fill_run(buffer, _basalt, float(body["bottom"]), minf(float(body["top"]), yb), i, k, oy, sf, ny, Layout.CHANNEL_ROCK)

			continue

		var local: Vector2 = (point - body["center"]).rotated(-float(body["angle"]))
		var q: float = pow(local.x / float(body["ra"]), 2.0) + pow(local.y / float(body["rb"]), 2.0)

		if q <= 1.0:
			_fill_run(buffer, _granite, float(body["bottom"]), minf(float(body["top"]) - float(body["roof_drop"]) * q, yb), i, k, oy, sf, ny, Layout.CHANNEL_ROCK)
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
				list.append(body)

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
func _fill_ore_column(buffer: VoxelBuffer, data, ore_set: Dictionary, i: int, k: int, x: float, z: float, h: float, oy: float, sf: float, ny: int, origin: Vector3i) -> void:
	var point: Vector2 = Vector2(x, z)

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
					_fill_run(buffer, id, h - float(ore.get("thickness_m", 1.0)), h, i, k, oy, sf, ny, Layout.CHANNEL_RESOURCE)
					break

	var by_province: Dictionary = ore_set["layers"].get(data.tile, {})

	if by_province.is_empty():
		return

	var p: int = data.province[data.nearest(x, z)]

	if not by_province.has(p):
		return

	var top: float = data.prov_datum[p] + data.offset_at(x, z)
	var yb: float = h - data.cover_at(x, z)

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
