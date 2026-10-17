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
# Item ID: species ID << 16 | grid cell index, unique within its chunk and
# stable: "item N in chunk C" is what a removal records.
#
# Thread safe: chunk_items only reads.

const KIND_TREE := 0
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
				var value: float = float(entry["per_hectare"][name]) * density
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

				var slope: float = Vector2(data.height_at(x + 2.0, z) - data.height_at(x - 2.0, z), data.height_at(x, z + 2.0) - data.height_at(x, z - 2.0)).length() / 4.0

				if slope > item["max_slope"]:
					continue

				var y: float = generator.surface_height(x, z)

				if y < item["altitude_min"] or y > item["altitude_max"]:
					continue

				# Evergreens hold the ridges and dry heights; hardwoods take the valleys
				# and fields and crowd the evergreens out (80/20 either way).
				if item["kind"] == KIND_TREE and item["shape"] in ["conifer", "broadleaf"]:
					var ridge: float = _ridge_factor(data, x, z, y)
					var mult: float = lerpf(0.25, 1.0, ridge) if item["shape"] == "conifer" else lerpf(1.0, 0.25, ridge)

					if rng_pick(x, z, species_id) >= mult:
						continue

				if woody and not _make_room(occupied, x, z, crown):
					continue

				result["ids"].append((species_id << 16) | (cz * count + cx))
				result["positions"].append(Vector3(x, y, z))
				result["heights"].append(lerpf(item["height_min"], item["height_max"], size))
				result["yaws"].append(yaw)

	return result


# The patch field, about -1 to 1, the same across the wrap seam.
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
