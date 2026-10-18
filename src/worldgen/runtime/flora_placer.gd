extends RefCounted

# Trees and plants at runtime (plan step 15, design Section 4.3).
#
# Flora is never baked. For any 256 m chunk it is worked out from the
# tile's biome and moisture maps, the ground shape and the tile's flora
# seed, so the server and anything else with the tile files get the same
# answer every time. Only removals are stored (by the server).
#
# Each species (data/tables/flora.json) is placed on its own jittered grid:
# one candidate per grid cell, kept with a probability set by the species'
# density for the biome under it, then checked against moisture, slope,
# altitude and water. A smooth world-wide noise field makes the woods
# patchy: trees thin out into glades, where shrubs grow thicker (and the
# other way round), so forests are not an even spread. Trees and shrubs
# keep their crowns apart; species
# with lower IDs place first. Every species draws from its own random
# stream, seeded by the flora seed, the chunk and the species ID, and every
# cell draws the same numbers whether or not it is kept, so adding a
# species later or removing a tree never moves anything else.
#
# Grove species (flora.json "grove", the everember) ignore the per-hectare
# figure: they grow only in groves, packed spacing_m apart on their own grid.
# Groves sit on a world grid every_km across; each grid square holds one with
# the given chance, at a jittered spot, with a radius from radius_m. Inside a
# grove every candidate whose biome lists the species is kept (moisture,
# slope, altitude and water still apply). "young_share" and "young_height_m"
# make that share of a species young, with heights from the young range.
#
# Item ID: species ID << 16 | grid cell index, unique within its chunk and
# stable: "item N in chunk C" is what a removal records.
#
# Thread safe: chunk_items only reads.

const KIND_TREE := 0
const TREE_DENSITY := 2.0   # trees twice as many as the table's per-hectare figures
const KIND_SHRUB := 1
const KIND_PLANT := 2
const KINDS := ["tree", "shrub", "plant"]
const OCCUPANCY_CELL := 8.0
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

var generator
var chunk_m: float = 256.0
var density: float = 1.0
var species: Array = []              # Dictionary per table row (retired rows skipped)
var _by_id: Dictionary = {}          # species id -> Dictionary
var _by_biome: Array = []            # biome id -> Array of species Dictionaries (sorted by id)
var patchiness: float = 0.0
var _soil_growth: PackedFloat32Array = PackedFloat32Array()   # soil id -> tree and shrub growth factor
var _patches: FastNoiseLite
var _grove_seed: int = 0


# `tables` is a TableSet, `tile_rules` the parsed tile_rules.json.
func setup(terrain_generator, tables, tile_rules: Dictionary) -> void:
	generator = terrain_generator
	var rules: Dictionary = tile_rules.get("runtime_flora", {})
	chunk_m = float(rules.get("chunk_m", 256.0))
	density = float(rules.get("density", 1.0))
	patchiness = float(rules.get("patchiness", 0.0))
	_patches = FastNoiseLite.new()
	_patches.seed = SeedUtil.purpose_seed(int(generator.master_seed), "flora_patches")
	_patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patches.fractal_type = FastNoiseLite.FRACTAL_FBM
	_patches.fractal_octaves = 2
	_patches.frequency = 1.0 / float(rules.get("patch_m", 150.0))
	_grove_seed = SeedUtil.purpose_seed(int(generator.master_seed), "flora_groves")
	var biome_ids: Dictionary = {}
	var water_ids: Dictionary = {}
	_soil_growth.resize(256)
	_soil_growth.fill(1.0)

	for entry in tables.get_entries("soils"):
		_soil_growth[int(entry["id"])] = float(entry.get("tree_growth", 1.0))


	for entry in tables.get_entries("biomes"):
		biome_ids[str(entry["name"])] = int(entry["id"])

	for entry in tables.get_entries("water_classes"):
		water_ids[str(entry["name"])] = int(entry["id"])

	_by_biome = []
	_by_biome.resize(256)

	for n in range(256):
		_by_biome[n] = []

	for entry in tables.get_entries("flora"):
		if entry.get("retired", false):
			continue

		var per_biome: PackedFloat32Array = PackedFloat32Array()
		per_biome.resize(256)
		var peak: float = 0.0

		for name in entry["per_hectare"]:
			if biome_ids.has(name):
				var value: float = float(entry["per_hectare"][name]) * density * (TREE_DENSITY if str(entry["kind"]) == "tree" else 1.0)
				per_biome[biome_ids[name]] = value
				peak = maxf(peak, value)

		if peak <= 0.0:
			continue

		var water_mask: int = 0

		for name in entry.get("water", []):
			if water_ids.has(name):
				water_mask |= 1 << int(water_ids[name])

		var height: Array = entry["height_m"]
		var altitude: Array = entry["altitude_m"]
		var item: Dictionary = {
			"id": int(entry["id"]),
			"name": str(entry["name"]),
			"kind": KINDS.find(str(entry["kind"])),
			"shape": str(entry["shape"]),
			"color": entry["color"],
			"height_min": float(height[0]),
			"height_max": float(height[1]),
			"crown": float(entry["crown_m"]),
			"trunk": float(entry["trunk_m"]),
			"per_biome": per_biome,
			"peak": peak,
			# One candidate per cell; at least 1 m so cell indices fit 16 bits.
			"cell": maxf(sqrt(10000.0 / peak), maxf(chunk_m / 256.0, 1.0)),
			"moisture_min": int(entry["moisture"][0]),
			"moisture_max": int(entry["moisture"][1]),
			"max_slope": tan(deg_to_rad(float(entry["max_slope_deg"]))),
			"altitude_min": float(altitude[0]),
			"altitude_max": float(altitude[1]),
			"water_mask": water_mask,
		}

		if entry.has("grove"):
			var grove: Dictionary = entry["grove"]
			item["grove"] = {
				"every_m": float(grove.get("every_km", 4.0)) * 1000.0,
				"chance": float(grove.get("chance", 0.5)),
				"radius_min": float(grove["radius_m"][0]),
				"radius_max": float(grove["radius_m"][1]),
			}
			item["cell"] = maxf(float(grove.get("spacing_m", 11.0)), 1.0)

		if entry.has("young_height_m"):
			item["young_share"] = float(entry.get("young_share", 0.0))
			item["young_min"] = float(entry["young_height_m"][0])
			item["young_max"] = float(entry["young_height_m"][1])
		species.append(item)
		_by_id[item["id"]] = item

		for b in range(256):
			if per_biome[b] > 0.0:
				_by_biome[b].append(item)

	for list in _by_biome:
		list.sort_custom(func(a, b): return a["id"] < b["id"])


func species_of(id: int) -> Dictionary:
	return _by_id.get(id >> 16, {})


func species_by_id(species_id: int) -> Dictionary:
	return _by_id.get(species_id, {})


# The chunk holding a world position (wrapped).
func chunk_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(generator.wrap_x(x) / chunk_m)), int(floor(generator.wrap_x(z) / chunk_m)))


# The same chunk in wrapped coordinates.
func normalize(chunk: Vector2i) -> Vector2i:
	var first: int = int(round(generator.world_min_m / chunk_m))
	var count: int = int(round(generator.period_m / chunk_m))
	return Vector2i(first + posmod(chunk.x - first, count), first + posmod(chunk.y - first, count))


# World position of a chunk's corner (wrapped coordinates).
func chunk_origin(chunk: Vector2i) -> Vector2:
	return Vector2(float(chunk.x) * chunk_m, float(chunk.y) * chunk_m)


# The flora of one chunk: ids (PackedInt32Array), positions
# (PackedVector3Array, the base of each item on the ground) and
# heights and yaws (PackedFloat32Array each).
func chunk_items(chunk: Vector2i) -> Dictionary:
	var result: Dictionary = {
		"ids": PackedInt32Array(), "positions": PackedVector3Array(),
		"heights": PackedFloat32Array(), "yaws": PackedFloat32Array(),
	}
	var origin: Vector2 = chunk_origin(chunk)
	var data = generator.get_tile(generator.tile_of(origin.x + 1.0, origin.y + 1.0))

	if data.placeholder:
		return result

	# Species that can grow here: those of the biomes in the chunk.
	var present: Dictionary = {}
	var step: int = maxi(int(data.spacing_m), 1)

	for z in range(0, int(chunk_m) + 1, step):
		for x in range(0, int(chunk_m) + 1, step):
			present[data.biome[data.nearest(origin.x + float(x), origin.y + float(z))]] = true

	var candidates: Dictionary = {}

	for b in present:
		for item in _by_biome[b]:
			candidates[item["id"]] = item

	var order: Array = candidates.keys()
	order.sort()
	var occupied: Dictionary = {}       # occupancy cell -> Array of [x, z, crown]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	for species_id in order:
		var item: Dictionary = candidates[species_id]
		var cell: float = item["cell"]
		var count: int = int(ceil(chunk_m / cell))
		var peak: float = item["peak"]
		var per_biome: PackedFloat32Array = item["per_biome"]
		var woody: bool = item["kind"] != KIND_PLANT
		var crown: float = item["crown"]
		# Trees follow the patch field, shrubs the opposite, plants ignore it.
		var patch_sign: float = [1.0, -1.0, 0.0][item["kind"]] * patchiness
		var groves: Array = _groves_near(item, species_id, origin) if item.has("grove") else []

		if item.has("grove") and groves.is_empty():
			continue

		if item.has("grove"):
			patch_sign = 0.0
		rng.seed = _mix(data.flora_seed, chunk.x, chunk.y, species_id)

		for cz in range(count):
			for cx in range(count):
				# Always the same five draws per cell, kept or not.
				var x: float = origin.x + (float(cx) + rng.randf()) * cell
				var z: float = origin.y + (float(cz) + rng.randf()) * cell
				var roll: float = rng.randf() * peak
				var size: float = rng.randf()
				var yaw: float = rng.randf() * TAU

				if x >= origin.x + chunk_m or z >= origin.y + chunk_m:
					continue

				var k: int = data.nearest(x, z)

				var chance: float = per_biome[data.biome[k]]

				if chance <= 0.0:
					continue

				if not groves.is_empty():
					if not _in_grove(groves, x, z):
						continue
					chance = peak + 1.0

				# Trees and shrubs thin out on clay, peat, sand and other poor ground.
				if woody:
					chance *= _soil_growth[data.soil[k]]

				if patch_sign != 0.0:
					chance *= clampf(1.0 + patch_sign * patch_at(x, z), 0.0, 2.0)

				if roll >= chance:
					continue

				var wet: int = data.moisture[k]

				if wet < item["moisture_min"] or wet > item["moisture_max"]:
					continue

				var water: int = data.water_class[k]

				if water != 0 and (item["water_mask"] & (1 << water)) == 0:
					continue

				# Trees and shrubs never stand in water, only at its edge: no inland water
				# at the spot or within a few meters around it.
				if woody and _near_water(data, x, z):
					continue

				var slope: float = Vector2(data.height_at(x + 2.0, z) - data.height_at(x - 2.0, z), data.height_at(x, z + 2.0) - data.height_at(x, z - 2.0)).length() / 4.0

				if slope > item["max_slope"]:
					continue

				var y: float = generator.surface_height(x, z)

				if y < item["altitude_min"] or y > item["altitude_max"]:
					continue

				# Evergreens hold the ridges and dry heights; hardwoods take the valleys
				# and fields and crowd the evergreens out (80/20 either way).
				if item["kind"] == KIND_TREE and item["shape"] in ["conifer", "broadleaf"] and groves.is_empty():
					var ridge: float = _ridge_factor(data, x, z, y)
					var mult: float = lerpf(0.25, 1.0, ridge) if item["shape"] == "conifer" else lerpf(1.0, 0.25, ridge)

					if rng_pick(x, z, species_id) >= mult:
						continue

				if woody and not _make_room(occupied, x, z, crown):
					continue

				result["ids"].append((species_id << 16) | (cz * count + cx))
				result["positions"].append(Vector3(x, y, z))
				# Trees get an extra stable height spread (young and stunted to veteran) on top of the table's range.
				var spread: float = lerpf(0.62, 1.12, rng_pick(x + 7.0, z + 3.0, species_id)) if item["kind"] == KIND_TREE else 1.0
				if item.has("young_share") and rng_pick(x + 11.0, z + 5.0, species_id) < float(item["young_share"]):
					result["heights"].append(lerpf(item["young_min"], item["young_max"], size))
				else:
					result["heights"].append(lerpf(item["height_min"], item["height_max"], size) * spread)
				result["yaws"].append(yaw)

	return result


# The groves of a grove species that can reach the chunk at `origin`: [center, radius] pairs.
func _groves_near(item: Dictionary, species_id: int, origin: Vector2) -> Array:
	var grove: Dictionary = item["grove"]
	var every: float = grove["every_m"]
	var reach: float = grove["radius_max"]
	var found: Array = []

	for gj in range(int(floor((origin.y - reach) / every)), int(floor((origin.y + chunk_m + reach) / every)) + 1):
		for gi in range(int(floor((origin.x - reach) / every)), int(floor((origin.x + chunk_m + reach) / every)) + 1):
			var h: int = _mix(_grove_seed, gi, gj, species_id)

			if float(h % 10007) / 10007.0 >= float(grove["chance"]):
				continue

			# Kept off the square's edges so groves never run together.
			var fx: float = float((h >> 14) % 1000) / 1000.0
			var fz: float = float((h >> 24) % 1000) / 1000.0
			var fr: float = float((h >> 34) % 1000) / 1000.0
			var radius: float = lerpf(grove["radius_min"], grove["radius_max"], fr)
			var margin: float = minf(radius / every, 0.45)
			var center: Vector2 = Vector2((float(gi) + lerpf(margin, 1.0 - margin, fx)) * every, (float(gj) + lerpf(margin, 1.0 - margin, fz)) * every)

			if center.x + radius < origin.x or center.x - radius > origin.x + chunk_m or center.y + radius < origin.y or center.y - radius > origin.y + chunk_m:
				continue

			found.append([center, radius])

	return found


func _in_grove(groves: Array, x: float, z: float) -> bool:
	for g in groves:
		# A ragged edge: the radius wobbles around the grove.
		var off: Vector2 = Vector2(x, z) - g[0]
		var wobble: float = 1.0 + 0.15 * sin(atan2(off.y, off.x) * 5.0 + g[0].x)

		if off.length() < g[1] * wobble:
			return true

	return false


# The patch field, about -1 to 1, the same across the wrap seam.
const WATER_MARGIN_M := 4.0


func _near_water(data, x: float, z: float) -> bool:
	for offset in [Vector2.ZERO, Vector2(WATER_MARGIN_M, 0.0), Vector2(-WATER_MARGIN_M, 0.0), Vector2(0.0, WATER_MARGIN_M), Vector2(0.0, -WATER_MARGIN_M)]:
		var k: int = data.nearest(x + offset.x, z + offset.y)

		if data.water_class[k] > 1 and not is_nan(data.water_surface[k]):
			return true

		if not data.sim_levels.is_empty() and not is_nan(data.sim_levels[k]):
			return true

	return false


# 0 in a valley or field, 1 on a ridge top: how far the ground stands above the
# average of the ground 90 m around it.
func _ridge_factor(data, x: float, z: float, y: float) -> float:
	var total: float = 0.0

	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		total += data.height_at(x + cos(a) * 90.0, z + sin(a) * 90.0)

	return smoothstep(-6.0, 14.0, y - total / 8.0)


# A stable 0..1 number per spot and species, so the woods look the same every visit.
func rng_pick(x: float, z: float, species_id: int) -> float:
	return float(_mix(int(x * 4.0), int(z * 4.0), species_id, 7919) % 10000) / 10000.0


func patch_at(x: float, z: float) -> float:
	return clampf(1.6 * generator._wrapped_noise(_patches, x, z, 600.0), -1.0, 1.0)


# Keeps crowns apart: false when another tree or shrub is too close,
# else records this one.
func _make_room(occupied: Dictionary, x: float, z: float, crown: float) -> bool:
	var ci: int = int(floor(x / OCCUPANCY_CELL))
	var cj: int = int(floor(z / OCCUPANCY_CELL))

	for dj in range(-1, 2):
		for di in range(-1, 2):
			for other in occupied.get(Vector2i(ci + di, cj + dj), []):
				var gap: float = minf(0.6 * (crown + float(other[2])), OCCUPANCY_CELL)

				if Vector2(x - other[0], z - other[1]).length_squared() < gap * gap:
					return false

	var key: Vector2i = Vector2i(ci, cj)

	if not occupied.has(key):
		occupied[key] = []

	occupied[key].append([x, z, crown])
	return true


# A seed from four integers (SplitMix64 steps), the same on every machine.
static func _mix(a: int, b: int, c: int, d: int) -> int:
	var h: int = 0x1234567
	for v in [a, b, c, d]:
		h = (h ^ v) * -7046029254386353131
		h = h ^ ((h >> 31) & 0x1ffffffff)
		h = h * -4658895280553007687
		h = h ^ ((h >> 29) & 0x7ffffffff)
	return h & 0x7fffffffffffffff


# ---------------------------------------------------------------- transfer

# Packs a chunk's items (after removals) for sending: per item the id, the
# position inside the chunk to 4 mm, the ground height, the plant's height
# in cm and its yaw; Zstandard-compressed.
static func encode(items: Dictionary, origin: Vector2) -> PackedByteArray:
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	var ids: PackedInt32Array = items["ids"]
	buffer.put_u32(ids.size())

	for n in range(ids.size()):
		var p: Vector3 = items["positions"][n]
		buffer.put_u32(ids[n])
		buffer.put_u16(clampi(int(round((p.x - origin.x) * 256.0)), 0, 65535))
		buffer.put_u16(clampi(int(round((p.z - origin.y) * 256.0)), 0, 65535))
		buffer.put_float(p.y)
		buffer.put_u16(clampi(int(round(float(items["heights"][n]) * 100.0)), 0, 65535))
		buffer.put_u8(int(fposmod(float(items["yaws"][n]), TAU) / TAU * 256.0) & 255)

	var raw: PackedByteArray = buffer.data_array
	var packed: PackedByteArray = PackedByteArray()
	packed.resize(4)
	packed.encode_u32(0, raw.size())
	packed.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return packed


static func decode(bytes: PackedByteArray, origin: Vector2) -> Dictionary:
	var result: Dictionary = {
		"ids": PackedInt32Array(), "positions": PackedVector3Array(),
		"heights": PackedFloat32Array(), "yaws": PackedFloat32Array(),
	}

	if bytes.size() < 4:
		return result

	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = bytes.slice(4).decompress(bytes.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	var count: int = buffer.get_u32()

	for n in range(count):
		result["ids"].append(buffer.get_u32())
		var x: float = origin.x + float(buffer.get_u16()) / 256.0
		var z: float = origin.y + float(buffer.get_u16()) / 256.0
		result["positions"].append(Vector3(x, buffer.get_float(), z))
		result["heights"].append(float(buffer.get_u16()) / 100.0)
		result["yaws"].append(float(buffer.get_u8()) / 256.0 * TAU)

	return result


# Drops removed items. `removed` holds item ids as keys.
static func without(items: Dictionary, removed: Dictionary) -> Dictionary:
	if removed.is_empty():
		return items

	var result: Dictionary = {
		"ids": PackedInt32Array(), "positions": PackedVector3Array(),
		"heights": PackedFloat32Array(), "yaws": PackedFloat32Array(),
	}

	for n in range(items["ids"].size()):
		if removed.has(items["ids"][n]):
			continue

		for key in result:
			result[key].append(items[key][n])

	return result
