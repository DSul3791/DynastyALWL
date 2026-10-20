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
var cover: PackedByteArray = PackedByteArray()          # raw x 0.25 m
var province: PackedByteArray = PackedByteArray()
var layer_offset: PackedInt32Array = PackedInt32Array()  # raw x 0.1 m
var soil: PackedByteArray = PackedByteArray()
var water_class: PackedByteArray = PackedByteArray()
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

	heights = TileFileScript.decode_height(maps["height"])
	layer_offset = TileFileScript.decode_layer_offset(maps["layer_offset"])
	cover = maps["cover"]
	province = maps["province"]
	soil = maps["soil"]
	water_class = maps["water_class"]
	water_surface = TileFileScript.decode_water_surface(maps["water_surface"])
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


# Index of the nearest map sample.
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
	for cave in list:
		var nodes: Array = cave["nodes"]
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

		if capsules.is_empty() and chambers.is_empty():
			continue

		caves.append({"id": str(cave["id"]), "aabb": AABB(low, high - low), "capsules": capsules, "chambers": chambers})
