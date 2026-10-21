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
# patchy: trees thin out into glades, so forests are not an even spread.
#
# Spacing and shade (owner, 2026-10-18): every spot that passes is then kept
# or dropped in a fixed order: landmark trees (grove species, place_first),
# grown trees, young trees, shrubs, plants. A tree keeps others off by its
# crown grown with its height, so big old trees stand apart while young ones
# crowd, never closer than 6 ft. Some species also grow in dense stands
# ("stand": birch in groups of hundreds about 10 ft apart, alder and young
# firs in thickets, hazel in groups of clumps and the odd thicket). Young
# trees need light: none grow under a dense crown, and under a light one
# only shade-tolerant ones (firs, beech) grow freely.
# Shrubs are three times the table figures and tuck in under the trees,
# keeping only clear of trunks. Every species draws from its own random
# stream, seeded by the flora seed, the chunk and the species ID, and every
# cell draws the same numbers whether or not it is kept, so adding a
# species later or removing a tree never moves anything else.
#
# Grove species (flora.json "grove", the everember) ignore the per-hectare
# figure: they grow only in groves, packed spacing_m apart on their own grid.
# Groves sit on a world grid every_km across; each grid square holds one with
# the given chance, at a jittered spot, with a radius from radius_m. Inside a
# grove every candidate whose biome lists the species is kept (moisture,
# slope, altitude and water still apply). "fixed" adds groves by hand. "young_share" and "young_height_m"
# make that share of a species young, with heights from the young range.
#
# Slopes (owner, 2026-10-20, ART_DIRECTION.md section 8): hardwoods thin out gradually as the
# ground steepens toward hills and mountains; conifers there grow lower; species with "montane"
# (the firs) add dense low patches on steep and ridge ground (stand cells that no circle uses);
# species with "ledge" may stand, stunted, on a flat ledge (fine surface slope under 0.3) of ground
# steeper than their limit. Cell numbers and species ids are unchanged, so removals stay valid.
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
const OCCUPANCY_CELL := 12.0   # also the widest gap kept between two trees
const SHRUB_DENSITY := 3.0   # shrubs three times the table figures: ground cover under the woods (owner, 2026-10-18)
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
var _stand_seed: int = 0


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
	_stand_seed = SeedUtil.purpose_seed(int(generator.master_seed), "flora_stands")
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
				var value: float = float(entry["per_hectare"][name]) * density * {"tree": TREE_DENSITY, "shrub": SHRUB_DENSITY}.get(str(entry["kind"]), 1.0)
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
			"first": bool(entry.get("place_first", false)) or entry.has("grove"),
			"height_ref": 0.5 * (float(height[0]) + float(height[1])),
			# Shorter than this a tree is young: it needs light and crowds close.
			"young_below": float(entry.get("young_below_m", float(height[0]))),
			# Crowns that let little light through (most hardwoods and firs) or
			# much (birch, alder, pines, fruit trees): canopy "dense" or "light".
			"dense": str(entry.get("canopy", "dense")) == "dense",
			"tolerant": bool(entry.get("shade_tolerant", false)),
			# Hardy species that may grow, stunted, on the flat ledges of ground too steep for them (owner, 2026-10-20).
			"ledge": bool(entry.get("ledge", false)),
			# Species whose low, dense evergreen patches take over toward hill and mountain slopes (needs "stand").
			"montane": bool(entry.get("montane", false)),
		}

		if entry.has("stand"):
			var stand: Dictionary = entry["stand"]
			item["stand"] = {
				"every_m": float(stand.get("every_m", 300.0)),
				"chance": float(stand.get("chance", 0.4)),
				"radius_min": float(stand["radius_m"][0]),
				"radius_max": float(stand["radius_m"][1]),
				"fixed": [],
				"spacing_m": maxf(float(stand.get("spacing_m", 3.0)), MIN_TREE_GAP),
				"fill": float(stand.get("fill", 0.8)),
				# A share of the circles are thickets, filled fuller (hazel).
				"thicket_chance": float(stand.get("thicket_chance", 0.0)),
				"thicket_fill": float(stand.get("thicket_fill", 0.9)),
				"height_min": float(stand.get("height", [0.5, 1.0])[0]),
				"height_max": float(stand.get("height", [0.5, 1.0])[1]),
			}

		if entry.has("grove"):
			var grove: Dictionary = entry["grove"]
			item["grove"] = {
				"every_m": float(grove.get("every_km", 4.0)) * 1000.0,
				"chance": float(grove.get("chance", 0.5)),
				"radius_min": float(grove["radius_m"][0]),
				"radius_max": float(grove["radius_m"][1]),
				"fixed": [],
			}

			# Groves placed by hand (x, z, radius in world meters), e.g. one near the starter town.
			for f in grove.get("fixed", []):
				item["grove"]["fixed"].append([Vector2(float(f[0]), float(f[1])), float(f[2])])
				item["grove"]["radius_max"] = maxf(item["grove"]["radius_max"], float(f[2]))
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
# heights and yaws (PackedFloat32Array each). `trees_only` leaves out shrubs
# and plants for chunks seen only from afar (owner, 2026-10-19: draw the big
# trees far, the small stuff near). Trees are placed before shrubs and plants
# and never make room for them, so the trees come out the same either way.
func chunk_items(chunk: Vector2i, trees_only: bool = false) -> Dictionary:
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
			if not trees_only or item["kind"] == KIND_TREE:
				candidates[item["id"]] = item

	var order: Array = candidates.keys()
	order.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	# Every spot that passes the ground checks, before spacing and shade:
	# [tier, species, cell, x, y, z, height, yaw, stand spacing].
	var found: Array = []

	for species_id in order:
		var item: Dictionary = candidates[species_id]
		var cell: float = item["cell"]
		var count: int = int(ceil(chunk_m / cell))
		var peak: float = item["peak"]
		var per_biome: PackedFloat32Array = item["per_biome"]
		var woody: bool = item["kind"] != KIND_PLANT
		# Trees follow the patch field; shrubs and plants ignore it (shrubs grow
		# under the trees too, owner 2026-10-18).
		var patch_sign: float = patchiness if item["kind"] == KIND_TREE else 0.0
		var groves: Array = _groves_near(item, item["grove"], _grove_seed, species_id, origin) if item.has("grove") else []

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

				var y: float = _ground_ok(item, data, k, x, z)

				if is_nan(y):
					continue

				# Evergreens hold the ridges and dry heights; hardwoods take the valleys
				# and fields and crowd the evergreens out (80/20 either way).
				var slope: float = _slope_at(data, x, z)
				var steep: float = smoothstep(STEEP_FROM, STEEP_TO, slope)

				if item["kind"] == KIND_TREE and item["shape"] in ["conifer", "broadleaf"] and groves.is_empty():
					# Firs hold the ridges and the ground below a mountain, hardwoods the lowlands, with a
					# smooth change between (owner, 2026-10-20: 80 to 90% firs below the mountain,
					# reversing gradually toward the fertile low ground).
					var mountain: float = maxf(_ridge_factor(data, x, z, y), _mountain_near(data, x, z, y))
					var mult: float = lerpf(MIX_MINOR, 1.0, mountain) if item["shape"] == "conifer" else lerpf(1.0, MIX_HARD_AT_MOUNTAIN, mountain)

					if item["shape"] == "broadleaf":
						mult = minf(mult, lerpf(1.0, 0.05, steep))      # hardwoods give way on the slopes

					if rng_pick(x, z, species_id) >= mult:
						continue

				# Trees get an extra stable height spread (young and stunted to veteran) on top of the table's range.
				# Species with their own young range (everember, witness tree) keep the table heights as given.
				var height: float
				if item.has("young_share") and rng_pick(x + 11.0, z + 5.0, species_id) < float(item["young_share"]):
					height = lerpf(item["young_min"], item["young_max"], size)
				else:
					var spread: float = lerpf(0.62, 1.12, rng_pick(x + 7.0, z + 3.0, species_id)) if item["kind"] == KIND_TREE and not item.has("young_share") else 1.0
					height = lerpf(item["height_min"], item["height_max"], size) * spread

				if slope > item["max_slope"]:
					# A ledge on ground too steep for the species: stunted.
					height = lerpf(item["height_min"] * 0.2, item["height_min"] * 0.6, size) if item["kind"] == KIND_TREE else height * 0.7
				elif item["kind"] == KIND_TREE and item["shape"] == "conifer":
					height *= lerpf(1.0, 0.4, steep)       # evergreens grow lower toward the slopes

				found.append([_tier(item, height), species_id, cz * count + cx, x, y, z, height, yaw, 0.0])

		# Dense stands (birch, alder, young firs, hazel clumps): extra plants packed close
		# inside stand circles, each cell drawn from its own stable numbers.
		if item.has("stand"):
			var stand: Dictionary = item["stand"]
			var spacing: float = stand["spacing_m"]
			var per_row: int = int(ceil(chunk_m / spacing))
			var stand_used: Dictionary = {}     # stand cell index -> true, so the slope patches below never repeat one

			for st in _groves_near(item, stand, _stand_seed, species_id, origin):
				var c: Vector2 = st[0]
				var r: float = st[1] * 1.15
				var fill: float = float(stand["fill"])

				if float(_mix(_stand_seed, int(c.x), int(c.y), species_id + 7) % 10007) / 10007.0 < float(stand["thicket_chance"]):
					fill = float(stand["thicket_fill"])
				var z0: int = maxi(int(floor((c.y - r - origin.y) / spacing)), 0)
				var z1: int = mini(int(floor((c.y + r - origin.y) / spacing)), per_row - 1)
				var x0: int = maxi(int(floor((c.x - r - origin.x) / spacing)), 0)
				var x1: int = mini(int(floor((c.x + r - origin.x) / spacing)), per_row - 1)

				for cz in range(z0, z1 + 1):
					for cx in range(x0, x1 + 1):
						var index: int = cz * per_row + cx
						rng.seed = _mix(data.flora_seed, chunk.x * 65536 + chunk.y, species_id, STAND_BASE + index)
						var x: float = origin.x + (float(cx) + rng.randf_range(0.15, 0.85)) * spacing
						var z: float = origin.y + (float(cz) + rng.randf_range(0.15, 0.85)) * spacing
						var keep: float = rng.randf()
						var size: float = rng.randf()
						var yaw: float = rng.randf() * TAU

						if x >= origin.x + chunk_m or z >= origin.y + chunk_m or not _in_grove([st], x, z):
							continue

						var k: int = data.nearest(x, z)

						if per_biome[data.biome[k]] <= 0.0 or keep >= fill * _soil_growth[data.soil[k]]:
							continue

						var y: float = _ground_ok(item, data, k, x, z)

						if is_nan(y):
							continue

						var height: float = lerpf(item["height_min"], item["height_max"], size) * lerpf(stand["height_min"], stand["height_max"], rng.randf())
						stand_used[index] = true
						found.append([_tier(item, height), species_id, STAND_BASE + index, x, y, z, height, yaw, spacing])

			if item["montane"]:
				_montane_cells(item, data, chunk, origin, species_id, rng, found, stand_used)

	# Landmark trees first, then grown trees, young trees, shrubs and plants;
	# within a tier by species and cell, so the result never changes.
	found.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))))
	var occupied: Dictionary = {}       # occupancy cell -> Array of [x, z, spacing radius, stand spacing, species]
	var canopies: Dictionary = {}       # occupancy cell -> Array of [x, z, canopy radius, dense]

	for f in found:
		var item: Dictionary = _by_id[f[1]]
		var x: float = f[3]
		var z: float = f[5]
		var height: float = f[6]

		if item["kind"] != KIND_PLANT:
			# Young trees need light: none under a dense crown; under a light one
			# shade-tolerant young (firs, beech) grow, others only now and then.
			if f[0] == TIER_YOUNG:
				var shade: int = _shade_at(canopies, x, z)

				if shade == 2 or (shade == 1 and not item["tolerant"] and rng_pick(x + 3.0, z + 9.0, f[1]) >= 0.4):
					continue

			if not _make_room(occupied, x, z, spacing_radius(item, height), f[8], f[1], item["kind"]):
				continue

			if f[0] <= TIER_GROWN and item["kind"] == KIND_TREE:
				var key: Vector2i = Vector2i(int(floor(x / OCCUPANCY_CELL)), int(floor(z / OCCUPANCY_CELL)))

				if not canopies.has(key):
					canopies[key] = []

				canopies[key].append([x, z, spacing_radius(item, height), 2 if item["dense"] else 1])

		result["ids"].append((f[1] << 16) | f[2])
		result["positions"].append(Vector3(x, f[4], z))
		result["heights"].append(height)
		result["yaws"].append(f[7])

	return result


const TIER_FIRST := 0
const TIER_GROWN := 1
const TIER_YOUNG := 2
const TIER_SHRUB := 3
const TIER_PLANT := 4
const STAND_BASE := 49152   # stand cells' item numbers start here (main grid cells stay below)
const STEEP_FROM := 0.20    # ground slope (rise over run) where hardwoods start to thin
const STEEP_TO := 0.60      # and where they are nearly gone
const MIX_MINOR := 0.12     # the evergreens' chance multiplier in the lowlands (tables give about 86% hardwoods there)
const MIX_HARD_AT_MOUNTAIN := 0.05   # the hardwoods' chance multiplier below a mountain (about 88% firs there)
const MOUNTAIN_RISE_FROM := 25.0    # high ground within MOUNTAIN_RING_M standing this far above the spot starts to count as "below a mountain"
const MOUNTAIN_RISE_TO := 120.0     # and this far above counts fully
const MOUNTAIN_RING_M := [200.0, 450.0]
const LEDGE_MAX_SLOPE := 0.30   # a ledge: the surface within 1.5 m is flatter than this
const LEDGE_CHANCE := 0.3       # share of ledge spots that grow something
const MONTANE_PATCH_M := 30.0   # size of the squares that are or are not a low evergreen patch
const MONTANE_PATCH_SHARE := 0.4
const MIN_TREE_GAP := 1.8   # trees never closer than 6 ft (owner, 2026-10-18)
const SHRUB_TRUNK_GAP := 1.0   # a shrub tucks in under a tree, but not against its trunk


func _tier(item: Dictionary, height: float) -> int:
	if item["kind"] == KIND_PLANT:
		return TIER_PLANT

	if item["kind"] == KIND_SHRUB:
		return TIER_SHRUB

	if item["first"]:
		return TIER_FIRST

	return TIER_YOUNG if height < float(item["young_below"]) else TIER_GROWN


# Low, dense evergreen patches on steep and ridge ground (see the header): walks the species'
# stand cells in 12 m squares, skipping squares that are not hilly, and adds the cells that no
# stand circle already used. Heights 1 to 3 m ("low to the ground").
func _montane_cells(item: Dictionary, data, chunk: Vector2i, origin: Vector2, species_id: int, rng: RandomNumberGenerator, found: Array, stand_used: Dictionary) -> void:
	var stand: Dictionary = item["stand"]
	var spacing: float = stand["spacing_m"]
	var per_row: int = int(ceil(chunk_m / spacing))
	var block: int = maxi(int(ceil(12.0 / spacing)), 1)
	var fill: float = float(stand["fill"])
	var per_biome: PackedFloat32Array = item["per_biome"]

	for bz in range(0, per_row, block):
		for bx in range(0, per_row, block):
			var mx: float = origin.x + (float(bx) + float(block) * 0.5) * spacing
			var mz: float = origin.y + (float(bz) + float(block) * 0.5) * spacing
			var steep: float = smoothstep(STEEP_FROM, STEEP_TO, _slope_at(data, mx, mz))
			var hill: float = maxf(steep, 0.5 * _ridge_factor(data, mx, mz, data.height_at(mx, mz)))

			if hill < 0.12:
				continue

			var patch: float = rng_pick(floorf(mx / MONTANE_PATCH_M) * MONTANE_PATCH_M, floorf(mz / MONTANE_PATCH_M) * MONTANE_PATCH_M, species_id + 31)

			if patch >= MONTANE_PATCH_SHARE:
				continue

			var share: float = 0.5 * fill * smoothstep(0.12, 0.45, hill)

			for cz in range(bz, mini(bz + block, per_row)):
				for cx in range(bx, mini(bx + block, per_row)):
					var index: int = cz * per_row + cx

					if stand_used.has(index):
						continue

					rng.seed = _mix(data.flora_seed, chunk.x * 65536 + chunk.y, species_id, STAND_BASE + index)
					var x: float = origin.x + (float(cx) + rng.randf_range(0.15, 0.85)) * spacing
					var z: float = origin.y + (float(cz) + rng.randf_range(0.15, 0.85)) * spacing
					var keep: float = rng.randf()
					var size: float = rng.randf()
					var yaw: float = rng.randf() * TAU

					if x >= origin.x + chunk_m or z >= origin.y + chunk_m or keep >= share:
						continue

					var k: int = data.nearest(x, z)

					if per_biome[data.biome[k]] <= 0.0 or keep >= share * _soil_growth[data.soil[k]]:
						continue

					var y: float = _ground_ok(item, data, k, x, z)

					if is_nan(y):
						continue

					var height: float = lerpf(0.9, 3.2, size)
					found.append([_tier(item, height), species_id, STAND_BASE + index, x, y, z, height, yaw, spacing])


# Ground slope (rise over run) from the tile's height map, over 4 m.
func _slope_at(data, x: float, z: float) -> float:
	return Vector2(data.height_at(x + 2.0, z) - data.height_at(x - 2.0, z), data.height_at(x, z + 2.0) - data.height_at(x, z - 2.0)).length() / 4.0


# Slope of the real surface within 1.5 m: small on a ledge or outcrop top even on a steep face.
func _fine_slope(x: float, z: float) -> float:
	return Vector2(generator.surface_height(x + 1.5, z) - generator.surface_height(x - 1.5, z), generator.surface_height(x, z + 1.5) - generator.surface_height(x, z - 1.5)).length() / 3.0


# The ground checks every spot must pass; the ground height, or NAN.
func _ground_ok(item: Dictionary, data, k: int, x: float, z: float) -> float:
	var wet: int = data.moisture[k]

	if wet < item["moisture_min"] or wet > item["moisture_max"]:
		return NAN

	var water: int = data.water_class[k]

	if water != 0 and (item["water_mask"] & (1 << water)) == 0:
		return NAN

	# Trees and shrubs never stand in water, only at its edge: no inland water
	# at the spot or within a few meters around it.
	if item["kind"] != KIND_PLANT and _near_water(data, x, z):
		return NAN

	var slope: float = _slope_at(data, x, z)

	if slope > item["max_slope"]:
		# Only hardy species, only on a flat ledge, and only some of the spots.
		if not item["ledge"] or rng_pick(x + 17.0, z + 23.0, item["id"]) >= LEDGE_CHANCE or _fine_slope(x, z) > LEDGE_MAX_SLOPE:
			return NAN

	var y: float = generator.surface_height(x, z)

	if y < item["altitude_min"] or y > item["altitude_max"]:
		return NAN

	# Nothing grows under water: ground within WET_FOOT_M of the sea or a lake or river level stays bare, except reeds.
	if item["shape"] != "reed":
		var level: float = SEA_LEVEL_M

		if not is_nan(data.water_surface[k]):
			level = maxf(level, data.water_surface[k])

		if not data.sim_levels.is_empty() and not is_nan(data.sim_levels[k]):
			level = maxf(level, data.sim_levels[k])

		if y < level + WET_FOOT_M:
			return NAN

	return y


# How far a tree or shrub keeps others off: its table crown, grown with its
# height (young trees are small and crowd close; big old ones stand apart).
static func spacing_radius(item: Dictionary, height: float) -> float:
	if item["kind"] != KIND_TREE:
		return float(item["crown"])

	return float(item["crown"]) * clampf(height / float(item["height_ref"]), 0.3, 1.2)


# The least distance between two woody items: trees by their spacing radii
# (capped at OCCUPANCY_CELL, never under 6 ft); trees of one stand by the
# stand's spacing (shrub stands too: hazel clumps); a shrub keeps only clear
# of trunks under a tree.
static func min_gap(kind_a: int, radius_a: float, stand_a: float, species_a: int, kind_b: int, radius_b: float, stand_b: float, species_b: int) -> float:
	if stand_a > 0.0 and stand_b > 0.0 and species_a == species_b:
		return maxf(minf(stand_a, stand_b), MIN_TREE_GAP)

	if kind_a == KIND_SHRUB and kind_b == KIND_SHRUB:
		return minf(0.6 * (radius_a + radius_b), OCCUPANCY_CELL)

	if kind_a == KIND_SHRUB or kind_b == KIND_SHRUB:
		return SHRUB_TRUNK_GAP

	return maxf(minf(0.6 * (radius_a + radius_b), OCCUPANCY_CELL), MIN_TREE_GAP)


# 2 under a dense crown, 1 under a light one, 0 in the open.
func _shade_at(canopies: Dictionary, x: float, z: float) -> int:
	var ci: int = int(floor(x / OCCUPANCY_CELL))
	var cj: int = int(floor(z / OCCUPANCY_CELL))
	var shade: int = 0

	for dj in range(-1, 2):
		for di in range(-1, 2):
			for c in canopies.get(Vector2i(ci + di, cj + dj), []):
				if Vector2(x - c[0], z - c[1]).length_squared() < c[2] * c[2] * 0.7:
					shade = maxi(shade, c[3])

	return shade


# The groves of a grove species that can reach the chunk at `origin`: [center, radius] pairs.
func _groves_near(item: Dictionary, grove: Dictionary, seed: int, species_id: int, origin: Vector2) -> Array:
	var every: float = grove["every_m"]
	var reach: float = grove["radius_max"]
	var found: Array = []

	for gj in range(int(floor((origin.y - reach) / every)), int(floor((origin.y + chunk_m + reach) / every)) + 1):
		for gi in range(int(floor((origin.x - reach) / every)), int(floor((origin.x + chunk_m + reach) / every)) + 1):
			var h: int = _mix(seed, gi, gj, species_id)

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

	for g in grove["fixed"]:
		if g[0].x + g[1] >= origin.x and g[0].x - g[1] <= origin.x + chunk_m and g[0].y + g[1] >= origin.y and g[0].y - g[1] <= origin.y + chunk_m:
			found.append(g)

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
const SEA_LEVEL_M := 0.0
const WET_FOOT_M := 0.3


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


# 0 in the lowlands, 1 on the ground below a mountain: how far the highest ground on rings 200 and
# 450 m around the spot stands above it, so the mix changes gradually with distance from the mountain.
func _mountain_near(data, x: float, z: float, y: float) -> float:
	var top: float = y

	for r in MOUNTAIN_RING_M:
		for k in range(8):
			var a: float = TAU * float(k) / 8.0
			top = maxf(top, data.height_at(x + cos(a) * r, z + sin(a) * r))

	return smoothstep(MOUNTAIN_RISE_FROM, MOUNTAIN_RISE_TO, top - y)


# A stable 0..1 number per spot and species, so the woods look the same every visit.
func rng_pick(x: float, z: float, species_id: int) -> float:
	return float(_mix(int(x * 4.0), int(z * 4.0), species_id, 7919) % 10000) / 10000.0


func patch_at(x: float, z: float) -> float:
	return clampf(1.6 * generator._wrapped_noise(_patches, x, z, 600.0), -1.0, 1.0)


# Keeps crowns apart: false when another tree or shrub is too close,
# else records this one.
func _make_room(occupied: Dictionary, x: float, z: float, radius: float, stand: float, species_id: int, kind: int) -> bool:
	var ci: int = int(floor(x / OCCUPANCY_CELL))
	var cj: int = int(floor(z / OCCUPANCY_CELL))

	for dj in range(-1, 2):
		for di in range(-1, 2):
			for other in occupied.get(Vector2i(ci + di, cj + dj), []):
				var gap: float = min_gap(kind, radius, stand, species_id, other[5], other[2], other[3], other[4])

				if Vector2(x - other[0], z - other[1]).length_squared() < gap * gap:
					return false

	var key: Vector2i = Vector2i(ci, cj)

	if not occupied.has(key):
		occupied[key] = []

	occupied[key].append([x, z, radius, stand, species_id, kind])
	return true


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
