extends RefCounted

# One tile file loaded for the runtime terrain generator (plan step 14).
#
# Holds the maps the voxel generator reads (height, cover, province, layer
# offset, soil, water class) and the flora placer reads (biome, moisture)
# decoded into memory, and the lists (provinces,
# features, ore bodies, caves) turned into flat arrays with bounds, so a
# block only looks at the few items that touch it.
#
# Everything here is read-only once `load_file` returns, so worker threads
# can share one instance.
#
# Memory: about 62 MB per tile (height and layer offset as 4-byte values,
# the rest one byte per sample).

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const WaterStore := preload("res://src/water/water_store.gd")
const WetMeters := 0.12   # water drawn from this depth (the water simulation's WET_M)
const RIVER_CLASS := 3
const RIVER_FILM_M := 0.05   # a painted river cell thinner than WetMeters is still drawn, this deep (riffles between pools)

var tile: Vector2i = Vector2i.ZERO
var samples: int = 0
var spacing_m: float = 8.0
var x0: float = 0.0                # world position of sample (0, 0)
var z0: float = 0.0
var placeholder: bool = false      # no file: open ocean
var placeholder_depth_m: float = -200.0

var heights: PackedFloat32Array = PackedFloat32Array()
# Settled simulated water level per sample (NAN dry); empty when the tile has no
# settled water file, in which case the painted water classes are drawn instead.
var sim_levels: PackedFloat32Array = PackedFloat32Array()
# sim_levels plus the thin water on the baked channels that is not drawn (a film down a
# cliff face): only the fall finder (water_falls.gd) reads it. Empty when not running.
var fall_levels: PackedFloat32Array = PackedFloat32Array()
# The server's main thread replaces both arrays while worker threads read them (a whole-array assignment under a reader freed the old array: same crash family as the
# flora cache, 25 Oct). Once a tile is shared, write with set_sim() and read with sim_snapshot() / falls_snapshot(): the reader keeps its own copy for check and index.
var _sim_mutex: Mutex = Mutex.new()
var cover: PackedByteArray = PackedByteArray()          # raw x 0.25 m
var province: PackedByteArray = PackedByteArray()
var layer_offset: PackedInt32Array = PackedInt32Array()  # raw x 0.1 m
var soil: PackedByteArray = PackedByteArray()
var water_class: PackedByteArray = PackedByteArray()
var _near_water: PackedByteArray = PackedByteArray()
var _near_mutex: Mutex = Mutex.new()
var water_surface: PackedFloat32Array = PackedFloat32Array()   # NAN = no water above sea level
var biome: PackedByteArray = PackedByteArray()
var moisture: PackedByteArray = PackedByteArray()
var flora_seed: int = 0

# Provinces, one entry per index of the province map.
var prov_datum: PackedFloat32Array = PackedFloat32Array()
var prov_cycle: PackedFloat32Array = PackedFloat32Array()
var prov_repeat_to: PackedFloat32Array = PackedFloat32Array()
var prov_marble_depth: PackedFloat32Array = PackedFloat32Array()
var prov_base: PackedInt32Array = PackedInt32Array()
var prov_bottoms: Array = []        # PackedFloat32Array per province (layer bottoms below the datum, within one cycle)
var prov_rocks: Array = []          # PackedInt32Array per province
var prov_index_of: Dictionary = {}  # province id string -> index

# Bodies that replace the layered rock: intrusions (granite with a marble
# aureole in limestone) and volcanic vents and pipes (basalt).
var bodies: Array = []              # Dictionary per body, with "rect" (Rect2, world xz)

# Ore bodies with their resource id and xz bounds.
var ores: Array = []                # Dictionary per ore body, with "rect" and "resource_id"

# Caves: capsules (passages) and ellipsoids (chambers) with AABBs.
var caves: Array = []               # Dictionary per cave: "aabb", "capsules", "chambers"
var spring_mouths: PackedVector2Array = PackedVector2Array()   # world x, z of each spring cave's mouth (Dave 3 Nov 2026): the settle keeps a spring there even on steep ground
var cave_dens: PackedVector3Array = PackedVector3Array()   # every cave den: its node's floor point (world m), for den sounds (Sound thread #211)
# Cave dressing (Dave 4 Nov 2026; bake: tile_sites._dress_cave; drawn by Kathreen's client view). Flat lists:
var cave_bones: PackedFloat32Array = PackedFloat32Array()        # 5 floats each: x, y, z, kind (0 animal, 1 human), yaw
var cave_formations: PackedFloat32Array = PackedFloat32Array()   # 6 floats each: x, y, z, kind (0 stalagmite, 1 stalactite), height_m, radius_m (a stalactite's y is its root on the roof)
# Loose stones and boulders on cave floors (Dave 4 Nov 2026: "they should be riddled with rocks and collectable stones"): 5 floats each, x, y (the floor),
# z, kind (0 stone, 1 boulder), boulder radius m. Laid out by the server's item scatter (server_items._lay_out_cave_items) through cave_scatter_in.
var cave_scatter: PackedFloat32Array = PackedFloat32Array()
var _cave_scatter_cells: Dictionary = {}   # Vector2i scatter cell -> PackedInt32Array of entry numbers, built for _cave_scatter_cell_m
var _cave_scatter_cell_m: float = 0.0
var _cave_sources: Array = []           # the tile's baked caves, kept so the scatter is worked out only when the server first asks (the client never does)
var _cave_scatter_built: bool = false
const CAVE_STONE_EVERY_M := 2.5     # one loose stone per this many metres of passage
const CAVE_BOULDER_EVERY_M := 9.0   # one boulder per this many metres of passage
const CAVE_STONE_PER_M2 := 0.12     # stones per square metre of chamber floor
const CAVE_BOULDER_PER_M2 := 0.02
var cave_openings: Array = []         # [Vector2 a, Vector2 b, radius m, Rect2 box]: ground opened by a cave mouth (entrance node to its first node): no flora there
const CAVE_POOL_M := 0.4            # a spring cave pool's surface: this far above the bottom of its chamber as the chamber is carved
const CAVE_WATER_CELL_M := 16.0     # near_cave_water's index cell (build_cave_water_cells)
const CAVE_POOL_DEPTH_M := 20.0     # Dave's QA list BUG-008 (answer 4 Nov 2026): the pool goes 20 m down below that, in a natural shape; the chamber stays
var cave_streams: PackedFloat32Array = PackedFloat32Array()   # spring cave streams (Dave 3 Nov 2026): per piece x, y, z of the upper end, x, y, z of the lower end (floor heights, world m), width m; then per spring pool x, y, z, -radius (a negative width marks a pool)
var _cave_water_cells: Dictionary = {}   # Vector2i cell (CAVE_WATER_CELL_M) -> PackedInt32Array of cave_streams entry numbers near it
var cave_pool_shapes: PackedFloat32Array = PackedFloat32Array()   # BUG-008: per spring pool basin shape (spring_basin) x, y, z of its centre, r, rh, the pool's surface y (server only, not sent)


# Loads a tile file. `rock_ids` and `resource_ids` map names to table ids.
# Returns "" or an error.
func load_file(path: String, tile_coord: Vector2i, tile_size_m: float, rules: Dictionary, rock_ids: Dictionary, resource_ids: Dictionary) -> String:
	tile = tile_coord
	x0 = float(tile.x) * tile_size_m
	z0 = float(tile.y) * tile_size_m

	var head: Dictionary = TileFileScript.read_header(path)

	if not head["ok"]:
		return head["error"]

	var header: Dictionary = head["header"]
	var table: Array = head["table"]

	if int(header["tile_x"]) != tile.x or int(header["tile_z"]) != tile.y:
		return "%s holds tile (%d, %d), not (%d, %d)" % [path, int(header["tile_x"]), int(header["tile_z"]), tile.x, tile.y]

	samples = int(header["samples"])
	spacing_m = float(header["map_spacing_m"])
	var maps: Dictionary = {}

	flora_seed = int(header.get("flora_seed", 0))

	for name in ["height", "cover", "province", "layer_offset", "soil", "water_class", "water_surface", "biome", "moisture"]:
		var section: Dictionary = TileFileScript.read_section(path, table, name)

		if not section["ok"]:
			return section["error"]

		maps[name] = section["raw"]

	heights = TileFileScript.decode_height(maps["height"], TileFileScript.height_step_of(header))
	layer_offset = TileFileScript.decode_layer_offset(maps["layer_offset"])
	cover = maps["cover"]
	province = maps["province"]
	soil = maps["soil"]
	water_class = maps["water_class"]
	water_surface = TileFileScript.decode_water_surface(maps["water_surface"], TileFileScript.height_step_of(header))
	biome = maps["biome"]
	moisture = maps["moisture"]

	var lists: Dictionary = {}

	for name in ["provinces", "features", "ore_bodies", "sites"]:
		var list: Dictionary = TileFileScript.read_list(path, table, name)

		if not list["ok"]:
			return list["error"]

		lists[name] = list["value"]

	_load_provinces(lists["provinces"], rules, rock_ids)
	_load_bodies(lists["features"], rules)
	_load_ores(lists["ore_bodies"], resource_ids, rock_ids)
	_load_caves(lists["sites"].get("caves", []))
	_carve_beds(rules.get("runtime_terrain", {}).get("sim_water", {}))
	_load_sim_water(path)
	return ""


# Simulated-water tiles (rules runtime_terrain.sim_water.tiles) get real channels and
# bowls: the painted river cells are cut deeper, with sloping banks, and each lake
# cell is cut by its distance from the shore, so water can be held by the ground
# itself instead of by a flat painted bed. The same heights are drawn, walked on and
# used by the water, so nothing is out of step.
func _carve_beds(config: Dictionary) -> void:
	if not config.has("tiles") or not config["tiles"].has("%d,%d" % [tile.x, tile.y]):
		return

	var river_m: float = float(config.get("river_carve_m", 2.0))
	var bank_m: float = float(config.get("bank_carve_m", 0.8))
	var slope: float = float(config.get("lake_slope_m_per_cell", 0.5))
	var lake_max: float = float(config.get("lake_max_m", 3.0))

	# Owner (2026-10-18): the ground is what the generator baked; nothing reshapes it when loaded.
	if river_m <= 0.0 and bank_m <= 0.0 and lake_max <= 0.0:
		return

	var count: int = samples * samples
	var near: PackedFloat32Array = PackedFloat32Array()
	near.resize(count)
	near.fill(0.0)

	# Distance (in cells, chamfer) from the shore, inside lake cells only.
	for k in range(count):
		near[k] = 0.0 if water_class[k] != 2 else 1000.0

	for j in range(samples):
		for i in range(samples):
			var k: int = j * samples + i

			if near[k] == 0.0:
				continue

			var best: float = near[k]

			if i > 0:
				best = minf(best, near[k - 1] + 1.0)

			if j > 0:
				best = minf(best, near[k - samples] + 1.0)
				if i > 0:
					best = minf(best, near[k - samples - 1] + 1.4)
				if i < samples - 1:
					best = minf(best, near[k - samples + 1] + 1.4)

			near[k] = best

	for j in range(samples - 1, -1, -1):
		for i in range(samples - 1, -1, -1):
			var k: int = j * samples + i

			if near[k] == 0.0:
				continue

			var best: float = near[k]

			if i < samples - 1:
				best = minf(best, near[k + 1] + 1.0)

			if j < samples - 1:
				best = minf(best, near[k + samples] + 1.0)
				if i < samples - 1:
					best = minf(best, near[k + samples + 1] + 1.4)
				if i > 0:
					best = minf(best, near[k + samples - 1] + 1.4)

			near[k] = best

	var cut: PackedFloat32Array = PackedFloat32Array()
	cut.resize(count)

	for j in range(2, samples - 2):
		for i in range(2, samples - 2):
			var k: int = j * samples + i

			if heights[k] < 2.0:
				continue

			var kind: int = water_class[k]

			if kind == 3:
				cut[k] = maxf(cut[k], river_m)
			elif kind == 2:
				cut[k] = maxf(cut[k], minf(near[k] * slope, lake_max))

			if kind == 3 or kind == 2:
				for dj in range(-2, 3):
					for di in range(-2, 3):
						var n: int = k + dj * samples + di

						if water_class[n] == 0 and (j + dj) > 0 and (j + dj) < samples - 1 and (i + di) > 0 and (i + di) < samples - 1:
							cut[n] = maxf(cut[n], bank_m if absi(di) + absi(dj) <= 1 else bank_m * 0.45)

	for k in range(count):
		if cut[k] > 0.0:
			heights[k] -= cut[k]


# The tile's settled simulated water, saved beside the tiles (worlds/X/water/tile_A_B.water).
func _load_sim_water(path: String) -> void:
	var water_path: String = path.get_base_dir().get_base_dir() + "/water/" + path.get_file().get_basename() + ".water"
	var depth: PackedFloat32Array = WaterStore.load_depth(water_path, samples)

	if depth.is_empty():
		return

	sim_levels = PackedFloat32Array()
	sim_levels.resize(samples * samples)
	sim_levels.fill(NAN)

	for k in range(samples * samples):
		if depth[k] >= WetMeters:
			sim_levels[k] = heights[k] + depth[k]
		elif water_class.size() == samples * samples and water_class[k] == RIVER_CLASS and heights[k] > 0.0:
			# Dave 2 Nov 2026 (a river broken into pools with dry steps between): on a riffle the settled river runs fast and a few cm thin, under the 12 cm
			# draw line, so only the pools were drawn. A painted river cell is always drawn, at least RIVER_FILM_M deep; the liquid sheet shows it as one ribbon.
			sim_levels[k] = heights[k] + maxf(depth[k], RIVER_FILM_M)


func set_sim(levels: PackedFloat32Array, falls: PackedFloat32Array) -> void:
	_sim_mutex.lock()
	sim_levels = levels
	fall_levels = falls
	_sim_mutex.unlock()


func sim_snapshot() -> PackedFloat32Array:
	_sim_mutex.lock()
	var copy: PackedFloat32Array = sim_levels
	_sim_mutex.unlock()
	return copy


func falls_snapshot() -> PackedFloat32Array:
	_sim_mutex.lock()
	var copy: PackedFloat32Array = fall_levels
	_sim_mutex.unlock()
	return copy


# An ocean tile with no file: a flat sea floor.
func make_placeholder(tile_coord: Vector2i, tile_size_m: float, depth_m: float) -> void:
	tile = tile_coord
	x0 = float(tile.x) * tile_size_m
	z0 = float(tile.y) * tile_size_m
	placeholder = true
	placeholder_depth_m = depth_m


# ---------------------------------------------------------------- sampling

# Smooth (Catmull-Rom) height at a world position inside the tile.
func height_at(x: float, z: float) -> float:
	if placeholder:
		return placeholder_depth_m

	var u: float = (x - x0) / spacing_m
	var v: float = (z - z0) / spacing_m
	var i: int = clampi(int(floor(u)), 0, samples - 2)
	var j: int = clampi(int(floor(v)), 0, samples - 2)
	var tu: float = u - float(i)
	var tv: float = v - float(j)
	var last: int = samples - 1
	var r0: int = maxi(j - 1, 0) * samples
	var r1: int = j * samples
	var r2: int = (j + 1) * samples
	var r3: int = mini(j + 2, last) * samples
	var c0: int = maxi(i - 1, 0)
	var c1: int = i
	var c2: int = i + 1
	var c3: int = mini(i + 2, last)
	# Catmull-Rom weights.
	var tu2: float = tu * tu
	var tu3: float = tu2 * tu
	var wu0: float = 0.5 * (-tu3 + 2.0 * tu2 - tu)
	var wu1: float = 0.5 * (3.0 * tu3 - 5.0 * tu2 + 2.0)
	var wu2: float = 0.5 * (-3.0 * tu3 + 4.0 * tu2 + tu)
	var wu3: float = 0.5 * (tu3 - tu2)
	var a: float = wu0 * heights[r0 + c0] + wu1 * heights[r0 + c1] + wu2 * heights[r0 + c2] + wu3 * heights[r0 + c3]
	var b: float = wu0 * heights[r1 + c0] + wu1 * heights[r1 + c1] + wu2 * heights[r1 + c2] + wu3 * heights[r1 + c3]
	var c: float = wu0 * heights[r2 + c0] + wu1 * heights[r2 + c1] + wu2 * heights[r2 + c2] + wu3 * heights[r2 + c3]
	var d: float = wu0 * heights[r3 + c0] + wu1 * heights[r3 + c1] + wu2 * heights[r3 + c2] + wu3 * heights[r3 + c3]
	var tv2: float = tv * tv
	var tv3: float = tv2 * tv
	return (
		0.5 * (-tv3 + 2.0 * tv2 - tv) * a
		+ 0.5 * (3.0 * tv3 - 5.0 * tv2 + 2.0) * b
		+ 0.5 * (-3.0 * tv3 + 4.0 * tv2 + tv) * c
		+ 0.5 * (tv3 - tv2) * d
	)


# 1 where the sample or any of its eight neighbours is lake, pond or river water (built once).
func near_water() -> PackedByteArray:
	# Built once, under a lock: several server worker threads ask at the same time.
	_near_mutex.lock()

	if _near_water.size() == samples * samples:
		var ready: PackedByteArray = _near_water
		_near_mutex.unlock()
		return ready

	# Only lake, pond and river samples (class 2 and 3) mark their neighbours, found with the native PackedByteArray.find instead of a loop over all 3.7 million samples:
	# the nine reads per sample took 3.7 s a tile, the two row/column passes still seconds (Sonny, 1 Nov 2026).
	var built: PackedByteArray = PackedByteArray()
	built.resize(samples * samples)

	for kind in [2, 3]:
		var at: int = water_class.find(kind, 0)

		while at != -1:
			var column: int = at % samples
			var row: int = at / samples

			for dj in range(maxi(row - 1, 0), mini(row + 2, samples)):
				for di in range(maxi(column - 1, 0), mini(column + 2, samples)):
					built[dj * samples + di] = 1

			at = water_class.find(kind, at + 1)

	_near_water = built
	_near_mutex.unlock()
	return built


func nearest(x: float, z: float) -> int:
	var i: int = clampi(int(round((x - x0) / spacing_m)), 0, samples - 1)
	var j: int = clampi(int(round((z - z0) / spacing_m)), 0, samples - 1)
	return j * samples + i


# Bilinear cover depth in meters.
func cover_at(x: float, z: float) -> float:
	if placeholder:
		return 0.0

	var u: float = (x - x0) / spacing_m
	var v: float = (z - z0) / spacing_m
	var i: int = clampi(int(floor(u)), 0, samples - 2)
	var j: int = clampi(int(floor(v)), 0, samples - 2)
	var tu: float = clampf(u - float(i), 0.0, 1.0)
	var tv: float = clampf(v - float(j), 0.0, 1.0)
	var k: int = j * samples + i
	var top: float = lerpf(float(cover[k]), float(cover[k + 1]), tu)
	var bottom: float = lerpf(float(cover[k + samples]), float(cover[k + samples + 1]), tu)
	return lerpf(top, bottom, tv) * 0.25


# Bilinear layer offset in meters.
func offset_at(x: float, z: float) -> float:
	if placeholder:
		return 0.0

	var u: float = (x - x0) / spacing_m
	var v: float = (z - z0) / spacing_m
	var i: int = clampi(int(floor(u)), 0, samples - 2)
	var j: int = clampi(int(floor(v)), 0, samples - 2)
	var tu: float = clampf(u - float(i), 0.0, 1.0)
	var tv: float = clampf(v - float(j), 0.0, 1.0)
	var k: int = j * samples + i
	var top: float = lerpf(float(layer_offset[k]), float(layer_offset[k + 1]), tu)
	var bottom: float = lerpf(float(layer_offset[k + samples]), float(layer_offset[k + samples + 1]), tu)
	return lerpf(top, bottom, tv) * 0.1


# Share of the four surrounding samples that hold water (0 to 1).
func wet_at(x: float, z: float) -> float:
	if placeholder:
		return 1.0

	var u: float = (x - x0) / spacing_m
	var v: float = (z - z0) / spacing_m
	var i: int = clampi(int(floor(u)), 0, samples - 2)
	var j: int = clampi(int(floor(v)), 0, samples - 2)
	var tu: float = clampf(u - float(i), 0.0, 1.0)
	var tv: float = clampf(v - float(j), 0.0, 1.0)
	var k: int = j * samples + i
	var a: float = 1.0 if water_class[k] != 0 else 0.0
	var b: float = 1.0 if water_class[k + 1] != 0 else 0.0
	var c: float = 1.0 if water_class[k + samples] != 0 else 0.0
	var d: float = 1.0 if water_class[k + samples + 1] != 0 else 0.0
	return lerpf(lerpf(a, b, tu), lerpf(c, d, tu), tv)


# Layered rock at depth `depth` (meters below the province datum, after the
# layer offset) in province `p`. Matches TileGeology._compute_surface_rock.
func layered_rock(p: int, depth: float, limestone: int, marble: int) -> int:
	depth = maxf(depth, 0.0)
	var rock: int = prov_base[p]

	if depth < prov_repeat_to[p]:
		var in_cycle: float = fmod(depth, prov_cycle[p])
		var bottoms: PackedFloat32Array = prov_bottoms[p]

		for k in range(bottoms.size()):
			if in_cycle < bottoms[k]:
				rock = prov_rocks[p][k]
				break

	if rock == limestone and depth > prov_marble_depth[p]:
		rock = marble

	return rock


# Depth below `depth` at which the layered rock next changes (meters, > 0).
func next_boundary(p: int, depth: float) -> float:
	depth = maxf(depth, 0.0)

	if depth >= prov_repeat_to[p]:
		return INF

	var cycle: float = prov_cycle[p]
	var start: float = floor(depth / cycle) * cycle
	var in_cycle: float = depth - start
	var bottoms: PackedFloat32Array = prov_bottoms[p]
	var step: float = cycle - in_cycle

	for k in range(bottoms.size()):
		if in_cycle < bottoms[k]:
			step = bottoms[k] - in_cycle
			break

	step = minf(step, prov_repeat_to[p] - depth)

	if depth < prov_marble_depth[p]:
		step = minf(step, prov_marble_depth[p] - depth + 0.001)

	return maxf(step, 0.001)


# ---------------------------------------------------------------- lists

func _load_provinces(list: Array, rules: Dictionary, rock_ids: Dictionary) -> void:
	var meta: Dictionary = rules["geology"]["metamorphism"]

	for entry in list:
		prov_index_of[str(entry["id"])] = prov_datum.size()
		prov_datum.append(float(entry["datum_m"]))
		prov_cycle.append(maxf(float(entry["cycle_m"]), 1.0))
		prov_repeat_to.append(maxf(float(entry["repeat_to_m"]), float(entry["cycle_m"])))
		prov_marble_depth.append(float(meta["fold_belt_marble_depth_m"]) if str(entry["kind"]) == "fold_belt" else INF)
		prov_base.append(int(rock_ids[str(entry["base_rock"])]))
		var bottoms: PackedFloat32Array = PackedFloat32Array()
		var rocks: PackedInt32Array = PackedInt32Array()

		for layer in entry["layers"]:
			bottoms.append(float(layer["top_m"]) + float(layer["thickness_m"]))
			rocks.append(int(rock_ids[str(layer["rock"])]))

		prov_bottoms.append(bottoms)
		prov_rocks.append(rocks)


func _load_bodies(list: Array, rules: Dictionary) -> void:
	var meta: Dictionary = rules["geology"]["metamorphism"]

	for feature in list:
		var kind: String = str(feature["type"])

		if kind == "intrusion":
			var aureole: float = maxf(float(meta["aureole_share"]) * float(feature["radius_b_m"]), float(meta["aureole_min_m"]))
			var radius: float = maxf(float(feature["radius_a_m"]), float(feature["radius_b_m"])) + aureole
			var center: Vector2 = Vector2(float(feature["center"][0]), float(feature["center"][1]))
			bodies.append({
				"kind": 0,
				"center": center,
				"angle": float(feature["angle"]),
				"ra": float(feature["radius_a_m"]),
				"rb": float(feature["radius_b_m"]),
				"aureole": aureole,
				"top": float(feature["top_y"]),
				"roof_drop": float(feature["roof_drop_m"]),
				"bottom": float(feature["bottom_y"]),
				"aureole_top": float(feature["top_y"]) + float(meta["aureole_above_top_m"]),
				"rect": Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			})
		elif kind == "volcanic_vent" or kind == "volcanic_pipe":
			var center: Vector2 = Vector2(float(feature["center"][0]), float(feature["center"][1]))
			var radius: float = float(feature["radius_m"])
			bodies.append({
				"kind": 1,
				"center": center,
				"radius": radius,
				"top": float(feature["top_y"]),
				"bottom": float(feature["bottom_y"]),
				"rect": Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			})


func _load_ores(list: Array, resource_ids: Dictionary, rock_ids: Dictionary) -> void:
	for ore in list:
		var shape: String = str(ore["shape"])
		var entry: Dictionary = ore.duplicate()
		entry["resource_id"] = int(resource_ids.get(str(ore["resource"]), 0))

		if entry["resource_id"] == 0:
			continue

		entry["code"] = ["lens", "halo", "pipe", "vein", "placer", "layer", "scatter"].find(shape)

		if ore.has("host_rock"):
			entry["host_id"] = int(rock_ids.get(str(ore["host_rock"]), -1))

		match shape:
			"lens":
				var center: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][2]))
				var r: float = maxf(float(ore["radius_a_m"]), float(ore["radius_b_m"]))
				entry["rect"] = Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
				entry["y_min"] = float(ore["center"][1]) - 0.5 * float(ore["thickness_m"])
				entry["y_max"] = float(ore["center"][1]) + 0.5 * float(ore["thickness_m"])
			"halo":
				var center: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][1]))
				var r: float = maxf(float(ore["radius_a_m"]), float(ore["radius_b_m"]))
				entry["rect"] = Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
				entry["y_min"] = float(ore["top_y"]) - 2.0 * float(ore["thickness_m"])
				entry["y_max"] = float(ore["top_y"])
			"pipe":
				var center: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][1]))
				var r: float = float(ore["radius_m"])
				entry["rect"] = Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
				entry["y_min"] = float(ore["bottom_y"])
				entry["y_max"] = float(ore["top_y"])
			"vein":
				var a: Vector2 = Vector2(float(ore["points"][0][0]), float(ore["points"][0][1]))
				var b: Vector2 = Vector2(float(ore["points"][1][0]), float(ore["points"][1][1]))
				var reach: float = absf(float(ore["top_y"]) - float(ore["bottom_y"])) / maxf(tan(deg_to_rad(float(ore["dip_deg"]))), 0.05) + float(ore["width_m"])
				entry["rect"] = Rect2(a, Vector2.ZERO).expand(b).grow(reach)
				entry["y_min"] = float(ore["bottom_y"])
				entry["y_max"] = float(ore["top_y"])
			"layer", "scatter":
				if not prov_index_of.has(str(ore["province"])):
					continue

				entry["province_index"] = prov_index_of[str(ore["province"])]
				entry["rect"] = Rect2(x0, z0, float(samples - 1) * spacing_m, float(samples - 1) * spacing_m)
				entry["y_min"] = -INF
				entry["y_max"] = INF
			"placer":
				var points: PackedVector2Array = PackedVector2Array()

				for point in ore["points"]:
					points.append(Vector2(float(point[0]), float(point[1])))

				entry["polyline"] = points
				var rect: Rect2 = Rect2(points[0], Vector2.ZERO)

				for point in points:
					rect = rect.expand(point)

				entry["rect"] = rect.grow(float(ore.get("width_m", 10.0)))
				entry["y_min"] = -INF
				entry["y_max"] = INF
			_:
				continue

		ores.append(entry)


func _load_caves(list: Array) -> void:
	cave_streams = PackedFloat32Array()
	cave_pool_shapes = PackedFloat32Array()
	cave_openings = []
	cave_dens = PackedVector3Array()
	cave_bones = PackedFloat32Array()
	cave_formations = PackedFloat32Array()
	cave_scatter = PackedFloat32Array()
	_cave_scatter_cells = {}
	_cave_sources = []
	_cave_scatter_built = false
	_cave_water_cells = {}

	for cave in list:
		for bone in cave.get("bones", []):
			var at: Array = bone["pos"]
			cave_bones.append_array(PackedFloat32Array([float(at[0]), float(at[1]), float(at[2]), 1.0 if str(bone["kind"]) == "human" else 0.0, float(bone.get("yaw", 0.0))]))

		for form in cave.get("formations", []):
			var at: Array = form["pos"]
			cave_formations.append_array(PackedFloat32Array([float(at[0]), float(at[1]), float(at[2]), 1.0 if str(form["kind"]) == "stalactite" else 0.0, float(form["height_m"]), float(form["radius_m"])]))

		var nodes: Array = cave["nodes"]

		if str(cave.get("cave_kind", "")) == "spring_cave" and not nodes.is_empty():
			spring_mouths.append(Vector2(float(nodes[0][0]), float(nodes[0][2])))
		for entrance in cave.get("entrances", []):
			for segment in cave["segments"]:
				if int(segment[0]) == int(entrance) or int(segment[1]) == int(entrance):
					var na: Array = nodes[int(segment[0])]
					var nb: Array = nodes[int(segment[1])]
					var a: Vector2 = Vector2(float(na[0]), float(na[2]))
					var b: Vector2 = Vector2(float(nb[0]), float(nb[2]))
					var r: float = 0.5 * maxf(float(na[3]), float(nb[3])) + 2.0
					cave_openings.append([a, b, r, Rect2(a.min(b), (a.max(b) - a.min(b))).grow(r)])

		if str(cave.get("cave_kind", "")) == "spring_cave":
			_load_cave_stream(cave)

		for den in cave.get("dens", []):
			var dn: Array = nodes[int(den["node"])]
			cave_dens.append(Vector3(float(dn[0]), float(dn[1]) - 0.5 * float(dn[4]), float(dn[2])))
		var capsules: Array = []
		var chambers: Array = []
		var low: Vector3 = Vector3(INF, INF, INF)
		var high: Vector3 = Vector3(-INF, -INF, -INF)

		for segment in cave["segments"]:
			var na: Array = nodes[int(segment[0])]
			var nb: Array = nodes[int(segment[1])]
			var a: Vector3 = Vector3(float(na[0]), float(na[1]), float(na[2]))
			var b: Vector3 = Vector3(float(nb[0]), float(nb[1]), float(nb[2]))
			# Nodes hold full width and height; the capsule uses half of each.
			var rw: float = 0.5 * maxf(float(na[3]), float(nb[3]))
			var rh: float = 0.5 * maxf(float(na[4]), float(nb[4]))
			var reach: Vector3 = Vector3(rw, rh, rw) + Vector3.ONE
			var box: AABB = AABB(a.min(b) - reach, (a.max(b) - a.min(b)) + 2.0 * reach)
			capsules.append({"a": a, "b": b, "rw": rw, "rh": rh, "aabb": box})
			low = low.min(box.position)
			high = high.max(box.end)

		for chamber in cave["chambers"]:
			var node: Array = nodes[int(chamber["node"])]
			var center: Vector3 = Vector3(float(node[0]), float(node[1]), float(node[2]))
			var r: float = float(chamber["radius_m"])
			var rh: float = 0.5 * float(chamber["height_m"])
			var reach: Vector3 = Vector3(r, rh, r) + Vector3.ONE
			var box: AABB = AABB(center - reach, 2.0 * reach)
			chambers.append({"center": center, "r": r, "rh": rh, "aabb": box})
			low = low.min(box.position)
			high = high.max(box.end)

			if "spring" in chamber.get("features", []):
				for shape in spring_basin(str(cave.get("id", "")), node, chamber)["shapes"]:
					var basin_reach: Vector3 = Vector3(shape["r"], shape["rh"], shape["r"]) + Vector3.ONE
					var basin_box: AABB = AABB(shape["center"] - basin_reach, 2.0 * basin_reach)
					chambers.append({"center": shape["center"], "r": shape["r"], "rh": shape["rh"], "aabb": basin_box})
					low = low.min(basin_box.position)
					high = high.max(basin_box.end)

		if capsules.is_empty() and chambers.is_empty():
			continue

		_cave_sources.append(cave)

		caves.append({"id": str(cave["id"]), "aabb": AABB(low, high - low), "capsules": capsules, "chambers": chambers})

	build_cave_water_cells()


# Stones and boulders on one cave's floor, from a seed of the cave so they lie in the same places every time. Along each passage they lie on the floor of
# its section (an ellipse rw wide and rh tall round the middle line, as the cave is carved), to either side of a spring stream's ribbon (0.3 of the width
# each side, cave_streams.gd), boulders against the walls; in a chamber across its floor, never in a spring pool. A spot where the ground is below the
# cave's floor (the open cut at a mouth) gets nothing.
func _scatter_cave(cave: Dictionary) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s/scatter" % str(cave.get("id", "")))
	var nodes: Array = cave["nodes"]

	for segment in cave["segments"]:
		var na: Array = nodes[int(segment[0])]
		var nb: Array = nodes[int(segment[1])]
		var a: Vector3 = Vector3(float(na[0]), float(na[1]), float(na[2]))
		var b: Vector3 = Vector3(float(nb[0]), float(nb[1]), float(nb[2]))
		var rw: float = 0.5 * maxf(float(na[3]), float(nb[3]))
		var rh: float = 0.5 * maxf(float(na[4]), float(nb[4]))
		var flat: Vector2 = Vector2(b.x - a.x, b.z - a.z)
		var length: float = flat.length()

		if length < 0.5:
			continue

		var side_dir: Vector2 = Vector2(-flat.y, flat.x) / length
		var stream: bool = str(segment[2]) == "water"

		for k in range(int(length / CAVE_STONE_EVERY_M)):
			var t: float = (float(k) + rng.randf()) * CAVE_STONE_EVERY_M / length
			var side: float = (1.0 if rng.randf() < 0.5 else -1.0) * (rng.randf_range(0.36, 0.7) if stream else rng.randf_range(0.0, 0.7))
			_add_cave_floor_spot(a.lerp(b, t), side_dir, side, rw, rh, 0, 0.0)

		for k in range(int(length / CAVE_BOULDER_EVERY_M)):
			var t: float = (float(k) + rng.randf()) * CAVE_BOULDER_EVERY_M / length
			var radius: float = clampf(rng.randf_range(0.25, 0.7), 0.25, 0.3 * rw)
			_add_cave_floor_spot(a.lerp(b, t), side_dir, (1.0 if rng.randf() < 0.5 else -1.0) * maxf(0.75 - radius / rw, 0.4), rw, rh, 1, radius)

	for chamber in cave["chambers"]:
		var node: Array = nodes[int(chamber["node"])]
		var centre: Vector3 = Vector3(float(node[0]), float(node[1]), float(node[2]))
		var r: float = float(chamber["radius_m"])
		var rh: float = 0.5 * float(chamber["height_m"])
		var pool_r: float = -1.0

		if "spring" in chamber.get("features", []):
			pool_r = float(spring_basin(str(cave.get("id", "")), node, chamber)["open_r"]) + 0.5

		var area: float = PI * r * r
		var count: int = int(area * (CAVE_STONE_PER_M2 + CAVE_BOULDER_PER_M2))

		for k in range(count):
			var boulder: bool = rng.randf() < CAVE_BOULDER_PER_M2 / (CAVE_STONE_PER_M2 + CAVE_BOULDER_PER_M2)
			var angle: float = rng.randf_range(0.0, TAU)
			var d: float = r * sqrt(rng.randf_range(0.0, 0.6))
			var radius: float = rng.randf_range(0.3, 0.9) if boulder else 0.0

			if pool_r > 0.0 and d < pool_r + radius:
				continue

			_add_cave_floor_spot(centre, Vector2(cos(angle), sin(angle)), d / r, r, rh, 1 if boulder else 0, radius)


# A floor spot `side` (a share of the half width rw, either sign) out from `centre` along `side_dir` on a section rw wide and rh tall.
func _add_cave_floor_spot(centre: Vector3, side_dir: Vector2, side: float, rw: float, rh: float, kind: int, radius: float) -> void:
	var off: Vector2 = side_dir * side * rw
	var x: float = centre.x + off.x
	var z: float = centre.z + off.y
	var y: float = centre.y - rh * sqrt(maxf(1.0 - side * side, 0.0))

	if is_nan(height_at(x, z)) or height_at(x, z) < y + 0.5:
		return   # open to the sky here (a mouth's cut): the surface scatter covers it

	cave_scatter.append_array(PackedFloat32Array([x, y, z, float(kind), radius]))


# The cave floor stones and boulders of the whole tile. The tile loader calls it on its worker before the tile is published (Steve 5 Nov 2026:
# built by the first scatter cell that asked, it held the server main thread 345 ms in Dave's PC lag run, cell (1666, 2136)).
func build_cave_scatter() -> void:
	if _cave_scatter_built:
		return

	_cave_scatter_built = true

	for cave in _cave_sources:
		_scatter_cave(cave)


# The cave floor stones and boulders whose spot lies in one scatter cell (cell_m square, as the server lays its loose things out): entry numbers into
# cave_scatter (5 floats each). The index by cell is built the first time it is asked for.
func cave_scatter_in(cell: Vector2i, cell_m: float) -> PackedInt32Array:
	build_cave_scatter()

	if cave_scatter.is_empty():
		return PackedInt32Array()

	if _cave_scatter_cell_m != cell_m:
		_cave_scatter_cell_m = cell_m
		_cave_scatter_cells = {}

		@warning_ignore("integer_division")
		for n in range(cave_scatter.size() / 5):
			var key: Vector2i = Vector2i(int(floor(cave_scatter[n * 5] / cell_m)), int(floor(cave_scatter[n * 5 + 2] / cell_m)))

			if not _cave_scatter_cells.has(key):
				_cave_scatter_cells[key] = PackedInt32Array()

			_cave_scatter_cells[key].append(n)

	return _cave_scatter_cells.get(cell, PackedInt32Array())


# The stream along a spring cave's floor: its "water" segments run from the mouth (lower) up to a spring (higher); each piece is stored upper end
# first, so the water runs from the first point to the second. Every spring gets a pool in its chamber.
func _load_cave_stream(cave: Dictionary) -> void:
	var nodes: Array = cave["nodes"]

	for segment in cave["segments"]:
		if str(segment[2]) != "water":
			continue

		var na: Array = nodes[int(segment[0])]
		var nb: Array = nodes[int(segment[1])]
		var a: Vector3 = Vector3(float(na[0]), float(na[1]) - 0.5 * float(na[4]), float(na[2]))
		var b: Vector3 = Vector3(float(nb[0]), float(nb[1]) - 0.5 * float(nb[4]), float(nb[2]))
		var top: Vector3 = b if b.y >= a.y else a
		var low: Vector3 = a if b.y >= a.y else b
		cave_streams.append_array(PackedFloat32Array([top.x, top.y, top.z, low.x, low.y, low.z, minf(float(na[3]), float(nb[3]))]))

	for spring in cave.get("springs", []):
		var node: Array = nodes[int(spring["node"])]
		var floor_y: float = float(node[1]) - 0.5 * float(node[4])
		var radius: float = 1.5
		var deep: float = 0.0
		var shapes: Array = []

		# The chamber is carved as an ellipsoid round the node; the pool's basin goes CAVE_POOL_DEPTH_M down below its surface (spring_basin).
		for chamber in cave["chambers"]:
			if int(chamber["node"]) == int(spring["node"]):
				var basin: Dictionary = spring_basin(str(cave.get("id", "")), node, chamber)
				floor_y = float(basin["surface_y"])
				radius = float(basin["open_r"])
				deep = CAVE_POOL_DEPTH_M
				shapes = basin["shapes"]

		if shapes.is_empty():   # a spring with no chamber: a shallow pool round it
			shapes = [{"center": Vector3(float(node[0]), floor_y, float(node[2])), "r": radius, "rh": CAVE_POOL_M}]

		for shape in shapes:
			var c: Vector3 = shape["center"]
			cave_pool_shapes.append_array(PackedFloat32Array([c.x, c.y, c.z, float(shape["r"]), float(shape["rh"]), floor_y]))

		# The fourth float (unused before) carries the pool's depth below its surface, so the client can let the player swim in it.
		cave_streams.append_array(PackedFloat32Array([float(node[0]), floor_y, float(node[2]), deep, 0.0, 0.0, -radius]))


# A spring chamber's pool (Dave's QA list BUG-008; his answer 4 Nov 2026: keep the chamber as it is, make the pool 20 m deep, a varied natural shape).
# The surface lies CAVE_POOL_M above the chamber's carved bottom. Under it the basin is carved as a few ellipsoids from a seed of the cave and node: a main
# bowl that opens at the surface (at least half the chamber's radius across) and reaches CAVE_POOL_DEPTH_M down, swelling wider below the rim, and two
# lobes off to the sides lower down, so no two pools are the same shape. Returns {"surface_y", "open_r", "shapes": [{"center", "r", "rh"}]}.
static func spring_basin(cave_id: String, node: Array, chamber: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/pool" % [cave_id, int(chamber.get("node", 0))])
	var chamber_r: float = float(chamber.get("radius_m", 4.0))
	var rh: float = 0.5 * float(chamber.get("height_m", 4.0))
	var surface_y: float = float(node[1]) - rh + CAVE_POOL_M
	var up: float = clampf(1.0 - CAVE_POOL_M / maxf(rh, 0.5), 0.0, 1.0)
	var open_r: float = maxf(maxf(chamber_r * sqrt(1.0 - up * up), 0.5 * chamber_r) * rng.randf_range(0.9, 1.15), 1.5)
	# Main bowl: its top 0.1 x depth above the surface (inside the chamber's air), its bottom CAVE_POOL_DEPTH_M below; wide enough that it is open_r across at the surface.
	var bowl_rh: float = 0.55 * CAVE_POOL_DEPTH_M
	var bowl_y: float = surface_y - 0.45 * CAVE_POOL_DEPTH_M
	var bowl_r: float = open_r / sqrt(1.0 - pow(0.45 / 0.55, 2.0))
	var shapes: Array = [{"center": Vector3(float(node[0]), bowl_y, float(node[2])), "r": bowl_r, "rh": bowl_rh}]

	for lobe in range(2):
		var angle: float = rng.randf_range(0.0, TAU)
		var out: float = bowl_r * rng.randf_range(0.3, 0.6)
		var lobe_rh: float = CAVE_POOL_DEPTH_M * rng.randf_range(0.25, 0.4)
		var lobe_y: float = surface_y - CAVE_POOL_DEPTH_M * rng.randf_range(0.45, 0.75)
		lobe_y = minf(lobe_y, surface_y - 1.0 - lobe_rh)         # a lobe stays under the surface: the rim is the main bowl's
		lobe_y = maxf(lobe_y, surface_y - CAVE_POOL_DEPTH_M + lobe_rh)   # and above the bottom
		shapes.append({"center": Vector3(float(node[0]) + cos(angle) * out, lobe_y, float(node[2]) + sin(angle) * out), "r": bowl_r * rng.randf_range(0.5, 0.8), "rh": lobe_rh})

	return {"surface_y": surface_y, "open_r": open_r, "shapes": shapes}


# Whether a point is in ground a cave mouth opened (flora keeps out: the plants stand on the tile heights, which do not know the cave).
func in_cave_opening(x: float, z: float) -> bool:
	var p: Vector2 = Vector2(x, z)

	for opening in cave_openings:
		if not opening[3].has_point(p):
			continue

		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, opening[0], opening[1])) < float(opening[2]):
			return true

	return false


# Whether a point is in a spring cave pool (Dave 4 Nov, BUG-008: those pools are icy).
func in_cave_pool(p: Vector3, margin: float = 1.0) -> bool:
	return not is_nan(cave_pool_surface(p, margin))


# The surface height of the spring cave pool a point is in, else NAN. The water is the pool's basin as carved (spring_basin: a main bowl that swells
# wider below the rim and two lobes) up to its surface; the point must be inside one of those ellipsoids grown by `margin` m, and no more than
# `margin` above the surface. (BUG-008: the old test was a cylinder of the rim's radius, which left up to half the water out of the cold.)
func cave_pool_surface(p: Vector3, margin: float = 1.0) -> float:
	@warning_ignore("integer_division")
	for n in range(cave_pool_shapes.size() / 6):
		var o: int = n * 6
		var surface: float = cave_pool_shapes[o + 5]

		if p.y > surface + margin:
			continue

		var r: float = cave_pool_shapes[o + 3] + margin
		var rh: float = cave_pool_shapes[o + 4] + margin
		var dx: float = p.x - cave_pool_shapes[o]
		var dy: float = p.y - cave_pool_shapes[o + 1]
		var dz: float = p.z - cave_pool_shapes[o + 2]

		if (dx * dx + dz * dz) / (r * r) + dy * dy / (rh * rh) <= 1.0:
			return surface

	return NAN


# The stream pieces and pools of cave_streams by CAVE_WATER_CELL_M square (entry numbers), so near_cave_water looks only at the pieces near
# a point. It looked at every piece of the tile, and the server asks it up to 80 times for one scatter cell's bank stones (lag run 5 Nov: 67-105 ms a cell).
func build_cave_water_cells() -> void:
	_cave_water_cells = {}

	@warning_ignore("integer_division")
	for n in range(cave_streams.size() / 7):
		var o: int = n * 7
		var width: float = cave_streams[o + 6]
		var a: Vector2 = Vector2(cave_streams[o], cave_streams[o + 2])
		var b: Vector2 = a if width < 0.0 else Vector2(cave_streams[o + 3], cave_streams[o + 5])
		var grow: float = -width if width < 0.0 else 0.5 * width
		var lo: Vector2i = Vector2i(((a.min(b) - Vector2(grow, grow)) / CAVE_WATER_CELL_M).floor())
		var hi: Vector2i = Vector2i(((a.max(b) + Vector2(grow, grow)) / CAVE_WATER_CELL_M).floor())

		for cz in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var cell: Vector2i = Vector2i(cx, cz)

				if not _cave_water_cells.has(cell):
					_cave_water_cells[cell] = PackedInt32Array()

				_cave_water_cells[cell].append(n)


# Whether a point is within `reach` m of a spring cave's stream or pool (drinking and filling a container there, Dave 3 Nov 2026).
func near_cave_water(p: Vector3, reach: float) -> bool:
	if _cave_water_cells.is_empty():
		return false

	var lo: Vector2i = Vector2i((Vector2(p.x - reach, p.z - reach) / CAVE_WATER_CELL_M).floor())
	var hi: Vector2i = Vector2i((Vector2(p.x + reach, p.z + reach) / CAVE_WATER_CELL_M).floor())

	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			for n in _cave_water_cells.get(Vector2i(cx, cz), PackedInt32Array()):
				if _near_cave_piece(p, reach, n):
					return true

	return false


func _near_cave_piece(p: Vector3, reach: float, n: int) -> bool:
	var o: int = n * 7
	var a: Vector3 = Vector3(cave_streams[o], cave_streams[o + 1], cave_streams[o + 2])
	var width: float = cave_streams[o + 6]

	if width < 0.0:
		return p.distance_to(a) < reach - width

	var b: Vector3 = Vector3(cave_streams[o + 3], cave_streams[o + 4], cave_streams[o + 5])
	return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b)) < reach + 0.5 * width
