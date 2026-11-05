class_name TileSites
extends RefCounted

# Sites for one tile (design Sections 4.4 and 8.1, format spec Section 6b):
# natural cave systems, dormant lair sites, the harbor and, on starter
# tiles, the spawn point and suggested town block.
#
# Caves follow the rock (Section 4.4, decided 2026-10-13):
#   karst        branching passages dissolved along a limestone bed, so they
#                follow its folds; chambers, a rare large cavern, tight
#                squeezes (often with a drop on the far side), chasms with
#                thin rock bridges, ledges, flooded low passages, and side
#                passages steered into nearby ore so it shows in the walls
#   lava_tube    a wide, shallow tunnel running downhill from a volcanic
#                vent, with collapsed skylights as extra entrances
#   sea_cave     a short cave cut into a sea cliff, ending in a chamber
#   rock_shelter a shallow overhang in a steep rock face
#   spring_cave  where a brook starts on a hillside (Dave 3 Nov 2026): a
#                tunnel about 100 m into the hill rising gently, the spring
#                in a chamber at the very back and the stream running out
#                along the floor, side branches where animals den; a brook
#                that needs more water gets two or three spring passages
#                joining the main one
#
# A cave is stored as a skeleton: nodes [x, y, z, width, height] (y is the
# passage center), segments [from, to, type] and chambers. The runtime
# terrain generator carves voxels from it. Caves stay inside their tile
# (with a margin) so a tile never needs its neighbor's caves.
#
# Creature dens sit in chambers, dead ends and near entrances. Each den has
# a tier from 1 (the starter islands: bats, snakes, the odd bear) upward,
# from the regional danger and the depth below the entrance. The server
# decides what lives there.

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const OCEAN := 1
const LAKE := 2
const RIVER := 3

# Site local ids sit apart from geology ids (cell x 100 + n, below 1600)
# and placers (from 9001), so every id in a tile is unique.
const LOCAL_ID_BASE := 8000
const HEAD_CLEAR_CELLS := 5   # a brook head for a spring cave has no river cell over 1 m higher within this many samples (40 m)

var caves: Array = []
var lairs: Array = []
var harbor: Dictionary = {}
var starter: Dictionary = {}

var _settings
var _rules: Dictionary = {}
var _tables
var _master: int = 0
var _tile: Vector2i
var _samples: int = 0
var _spacing: float = 8.0
var _x0: float = 0.0
var _z0: float = 0.0
var _tile_m: float = 0.0
var _heights: PackedFloat32Array
var _water: PackedByteArray
var _soil: PackedByteArray
var _flow: PackedFloat32Array
var _geology
var _limestone: int = -1
var _local: int = 0
var _keep_clear: Array = []      # [center Vector2, radius] where no entrance may open
var _ore_by_id: Dictionary = {}
var ore_report: Dictionary = {"near": 0, "level": 0, "blocked": 0, "reached": 0}


func setup(settings, rules: Dictionary, tables) -> void:
	_settings = settings
	_rules = rules["sites"]
	_tables = tables
	_master = settings.master_seed
	_spacing = float(settings.map_spacing_m)
	_tile_m = float(settings.tile_size_m)


# starter_info: bay details for starter tiles ({} otherwise), as build_tile passes to TileWater.
# river_mouth: world position where the starter river meets the bay (starter tiles).
# flow: upstream cells per sample (TileWater.flow); sizes the spring caves (empty: one spring passage each).
func build(tile: Vector2i, heights: PackedFloat32Array, water_class: PackedByteArray, soil: PackedByteArray, geology, starter_info: Dictionary = {}, river_mouth: Vector2 = Vector2(NAN, NAN), flow: PackedFloat32Array = PackedFloat32Array()) -> void:
	_tile = tile
	_flow = flow
	_heights = heights
	_water = water_class
	_soil = soil
	_geology = geology
	_samples = int(round(sqrt(float(heights.size()))))
	_x0 = float(tile.x) * _tile_m
	_z0 = float(tile.y) * _tile_m
	_limestone = _tables.id_of("rocks", "limestone")
	_local = LOCAL_ID_BASE
	caves = []
	lairs = []
	ore_report = {"near": 0, "level": 0, "blocked": 0, "reached": 0}
	harbor = {}
	starter = {}
	_keep_clear = []
	_ore_by_id = {}

	for ore in geology.ore_bodies:
		_ore_by_id[ore["id"]] = ore

	if not starter_info.is_empty():
		_make_starter(starter_info, river_mouth)

	# Spring caves first: water comes first (Dave 3 Nov 2026), and the other caves keep away from their mouths.
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "sites_spring", tile.x, tile.y)
	_make_spring_caves(rng)
	rng = SeedUtil.rng_for(_master, "sites_karst", tile.x, tile.y)
	_make_karst(rng)
	rng = SeedUtil.rng_for(_master, "sites_lava", tile.x, tile.y)
	_make_lava_tubes(rng)
	rng = SeedUtil.rng_for(_master, "sites_sea", tile.x, tile.y)
	_make_sea_caves(rng)
	rng = SeedUtil.rng_for(_master, "sites_shelter", tile.x, tile.y)
	_make_shelters(rng)
	rng = SeedUtil.rng_for(_master, "sites_dens", tile.x, tile.y)

	for cave in caves:
		_finish_cave(cave, rng)

	_make_lairs()


# ==================================================
# KARST CAVES
# ==================================================

func _make_karst(rng: RandomNumberGenerator) -> void:
	var rules: Dictionary = _rules["karst"]
	var candidates: Array = []
	var step: int = maxi(int(float(rules["candidate_step_m"]) / _spacing), 1)
	var margin: int = int(float(_rules["edge_margin_m"]) / _spacing)

	# Limestone at the bedrock surface on a hillside: a spring or a hole in the slope.
	for j in range(margin, _samples - margin, step):
		for i in range(margin, _samples - margin, step):
			var index: int = j * _samples + i

			if _water[index] != 0 or _heights[index] < 5.0 or _geology.surface_rock[index] != _limestone:
				continue

			var slope: float = _slope(index)

			if slope < 0.15 or slope > 1.5:
				continue

			candidates.append(index)

	_shuffle(candidates, rng)
	var wanted: int = rng.randi_range(int(rules["count"][0]), int(rules["count"][1]))

	# Up to a share of the caves start near ore, so delving pays off.
	var targets: Array = []

	for ore in _geology.ore_bodies:
		var target: Vector3 = _ore_target(ore)

		if not is_nan(target.x) and _index_at(Vector2(target.x, target.z), float(_rules["edge_margin_m"])) >= 0:
			targets.append(Vector2(target.x, target.z))

	var near_ore: Array = []
	var others: Array = []

	for index in candidates:
		var point: Vector2 = _point_of(index)
		var close: bool = false

		for target in targets:
			if point.distance_to(target) < float(rules["ore_reach_m"]):
				close = true
				break

		if close and near_ore.size() < int(ceil(float(wanted) * float(rules["ore_first_share"]))) * 4:
			near_ore.append(index)
		else:
			others.append(index)

	var placed: Array = []
	var ore_caves: int = 0
	var ore_wanted: int = int(ceil(float(wanted) * float(rules["ore_first_share"])))

	for index in near_ore + others:
		if placed.size() >= wanted:
			break

		if near_ore.has(index) and ore_caves >= ore_wanted:
			continue

		var point: Vector2 = _point_of(index)

		if _too_close(point, placed, float(rules["min_spacing_m"])) or _kept_clear(point):
			continue

		var cave: Dictionary = _karst_cave(index, rng)

		if not cave.is_empty() and near_ore.has(index):
			ore_caves += 1

		if cave.is_empty():
			continue

		placed.append(point)
		caves.append(cave)


func _karst_cave(entrance: int, rng: RandomNumberGenerator) -> Dictionary:
	var rules: Dictionary = _rules["karst"]
	var bed: float = _limestone_bed_depth(entrance)

	if bed < 0.0:
		return {}

	var cave: Dictionary = _new_cave("karst", rng)
	var p: Vector2 = _point_of(entrance)
	var ground: float = _heights[entrance]
	var width: float = rng.randf_range(float(rules["passage_width_m"][0]), float(rules["passage_width_m"][1]))
	var height: float = rng.randf_range(float(rules["passage_height_m"][0]), float(rules["passage_height_m"][1]))
	cave["nodes"].append([p.x, ground - 0.5 * height + 0.3, p.y, width, height])
	cave["entrances"].append(0)

	# Head into the hill.
	var heading: float = _uphill_angle(entrance) + rng.randf_range(-0.7, 0.7)
	var length: float = rng.randf_range(float(rules["length_m"][0]), float(rules["length_m"][1]))
	var province: int = _geology.province[entrance]
	var queue: Array = [[0, heading, length, bed]]
	var branches: int = 0

	while not queue.is_empty():
		var job: Array = queue.pop_front()
		var made: Array = _karst_walk(cave, int(job[0]), float(job[1]), float(job[2]), float(job[3]), province, rng)

		for k in range(made.size()):
			if branches < int(rules["max_branches"]) and k > 4 and rng.randf() < float(rules["branch_chance"]):
				branches += 1
				var side: float = 1.0 if rng.randf() < 0.5 else -1.0
				queue.append([
					made[k][0], made[k][1] + side * rng.randf_range(1.2, 1.9),
					rng.randf_range(float(rules["branch_length_m"][0]), float(rules["branch_length_m"][1])), made[k][2]
				])

	if cave["nodes"].size() < 6:
		return {}

	_steer_to_ore(cave, province, rng)
	return cave


# One passage from a node. Returns [node index, heading, bed depth] for
# every node it made, for branching.
func _karst_walk(cave: Dictionary, from_node: int, heading: float, length: float, bed: float, province: int, rng: RandomNumberGenerator) -> Array:
	var rules: Dictionary = _rules["karst"]
	var step: float = float(_rules["step_m"])
	var min_roof: float = float(_rules["min_roof_m"])
	var nodes: Array = cave["nodes"]
	var made: Array = []
	var previous: int = from_node
	var squeeze_left: int = 0
	var drop_next: bool = false
	var base_width: float = float(nodes[from_node][3])
	var base_height: float = float(nodes[from_node][4])
	var travelled: float = 0.0
	var count: int = 0

	while travelled < length:
		var here: Vector2 = Vector2(float(nodes[previous][0]), float(nodes[previous][2]))
		var placed: bool = false

		for attempt in range(4):
			var turn: float = 0.0 if attempt == 0 else (0.6 if attempt % 2 == 1 else -0.6) * float((attempt + 1) / 2)

			# Passages wander gently, with an occasional sharper bend.
			if attempt == 0 and rng.randf() < float(rules["bend_chance"]):
				turn = rng.randf_range(-float(rules["bend_rad"]), float(rules["bend_rad"]))

			var try_heading: float = heading + turn + rng.randf_range(-float(rules["turn_rad"]), float(rules["turn_rad"]))
			var next: Vector2 = here + Vector2(cos(try_heading), sin(try_heading)) * step
			var index: int = _index_at(next, float(_rules["edge_margin_m"]))

			if index < 0 or _geology.province[index] != province:
				continue

			var width: float = base_width * rng.randf_range(0.8, 1.2)
			var height: float = base_height * rng.randf_range(0.8, 1.2)
			var kind: String = "passage"

			if squeeze_left > 0:
				width = float(rules["squeeze_width_m"])
				height = float(rules["squeeze_height_m"])
				kind = "squeeze"
			elif drop_next:
				bed += rng.randf_range(float(rules["drop_m"][0]), float(rules["drop_m"][1]))
				kind = "shaft"

			var y: float = _bed_y(index, bed)
			var ground: float = _heights[index]

			# Ease down from the entrance toward the bed.
			if count < 4 and from_node == 0:
				y = lerpf(float(nodes[0][1]), y, float(count + 1) / 5.0)

			if y + 0.5 * height > ground - (min_roof if count >= 2 or from_node != 0 else 1.0):
				continue

			# Below the water table the cave is flooded; only shallow sumps are kept.
			if y < float(rules["lowest_y_m"]):
				continue

			if y < 0.5 and kind == "passage":
				kind = "water"
			elif kind == "passage" and count > 3 and rng.randf() < float(rules["ledge_chance"]):
				kind = "ledge"

			nodes.append([snappedf(next.x, 0.1), snappedf(y, 0.1), snappedf(next.y, 0.1), snappedf(width, 0.1), snappedf(height, 0.1)])
			var node: int = nodes.size() - 1
			cave["segments"].append([previous, node, kind])
			made.append([node, try_heading, bed])
			heading = try_heading
			previous = node
			placed = true
			break

		if not placed:
			break

		travelled += step
		count += 1

		if squeeze_left > 0:
			squeeze_left -= 1
			drop_next = squeeze_left == 0 and rng.randf() < float(rules["drop_after_squeeze_chance"])
		elif drop_next:
			drop_next = false
		elif count > 5 and rng.randf() < float(rules["squeeze_chance"]):
			squeeze_left = rng.randi_range(int(rules["squeeze_segments"][0]), int(rules["squeeze_segments"][1]))
		elif count > 5 and rng.randf() < float(rules["drop_chance"]):
			drop_next = true

		# Chambers along the way, and once in a while a large cavern deep in.
		if count > 6 and squeeze_left == 0 and rng.randf() < float(rules["chamber_chance"]):
			var depth: float = _heights[_index_at(Vector2(float(nodes[previous][0]), float(nodes[previous][2])), 0.0)] - float(nodes[previous][1])
			var big: bool = depth > float(rules["cavern_min_depth_m"]) and not cave.get("has_cavern", false) \
					and rng.randf() < float(rules["cavern_chance"])
			var radius: float = rng.randf_range(float(rules["cavern_radius_m" if big else "chamber_radius_m"][0]), float(rules["cavern_radius_m" if big else "chamber_radius_m"][1]))
			var room_height: float = rng.randf_range(float(rules["cavern_height_m" if big else "chamber_height_m"][0]), float(rules["cavern_height_m" if big else "chamber_height_m"][1]))
			# Keep the roof under the ground.
			room_height = minf(room_height, maxf(depth - min_roof, 3.0) * 1.6)
			var chamber: Dictionary = {"node": previous, "radius_m": snappedf(radius, 0.1), "height_m": snappedf(room_height, 0.1), "features": []}

			if big:
				cave["has_cavern"] = true
				chamber["features"].append("cavern")

			if rng.randf() < float(rules["bridge_chance"]):
				chamber["features"].append("chasm")
				chamber["chasm_depth_m"] = snappedf(rng.randf_range(float(rules["chasm_depth_m"][0]), float(rules["chasm_depth_m"][1])), 0.1)
				chamber["bridge_width_m"] = snappedf(rng.randf_range(float(rules["bridge_width_m"][0]), float(rules["bridge_width_m"][1])), 0.1)

			cave["chambers"].append(chamber)

	return made


# Side passages that reach ore bodies near the cave, so ore shows in the walls.
func _steer_to_ore(cave: Dictionary, province: int, rng: RandomNumberGenerator) -> void:
	var rules: Dictionary = _rules["karst"]
	var reach: float = float(rules["ore_reach_m"])
	var nodes: Array = cave["nodes"]
	var step: float = float(_rules["step_m"])
	# Ore side passages may run closer under the surface than main passages (river gorges thin the roof over shallow ore).
	var min_roof: float = minf(float(_rules["min_roof_m"]), float(rules.get("ore_min_roof_m", 2.0)))

	for ore in _geology.ore_bodies:
		var target: Vector3 = _ore_target(ore)

		if is_nan(target.x):
			continue

		# A target above the ground is sunk into the rock (an outcropping vein is cut where the ground is still thick enough);
		# a target that would need sinking more than ore_sink_max_m is not an ore this cave can reach.
		var target_index: int = _index_at(Vector2(target.x, target.z), float(_rules["edge_margin_m"]))

		if target_index >= 0:
			var deepest_ok: float = _heights[target_index] - min_roof - 3.0

			if target.y > deepest_ok:
				if target.y - deepest_ok > float(rules.get("ore_sink_max_m", 25.0)):
					ore_report["above"] = int(ore_report.get("above", 0)) + 1
					continue

				target.y = deepest_ok

		var target_2d: Vector2 = Vector2(target.x, target.z)
		var best: int = -1
		var best_distance: float = reach
		var near: bool = false

		for n in range(1, nodes.size()):
			var node: Array = nodes[n]
			var distance: float = Vector2(float(node[0]), float(node[2])).distance_to(target_2d)
			near = near or distance < reach

			if distance < best_distance and absf(float(node[1]) - target.y) < float(rules["ore_vertical_m"]):
				best_distance = distance
				best = n

		if near:
			ore_report["near"] += 1

		if best < 0:
			continue

		ore_report["level"] += 1

		# Walk toward the ore, easing the height from the node to the ore.
		var start: Vector3 = Vector3(float(nodes[best][0]), float(nodes[best][1]), float(nodes[best][2]))
		var steps: int = maxi(int(best_distance / step), 1)
		var previous: int = best
		var added: Array = []
		var ok: bool = true
		var why: String = ""

		for k in range(1, steps + 1):
			var t: float = float(k) / float(steps)
			var wobble: Vector2 = Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0)) * (1.0 - absf(2.0 * t - 1.0))
			var p: Vector2 = Vector2(lerpf(start.x, target.x, t), lerpf(start.z, target.z, t)) + wobble
			var index: int = _index_at(p, float(_rules["edge_margin_m"]))

			if index < 0:
				ok = false
				why = "outside the tile margin at step %d of %d, p %.0f,%.0f" % [k, steps, p.x, p.y]
				break

			var y: float = lerpf(start.y, target.y, t)

			# Follow the ground: where it dips (valley, gorge) the passage dips with it and stays under the roof limit;
			# only the ore end itself must be deep enough.
			var ceiling: float = _heights[index] - min_roof - 1.5

			if y > ceiling:
				if k == steps:
					ok = false
					why = "ore end too shallow: y %.1f needs %.1f or lower (ground %.1f)" % [y, ceiling, _heights[index]]
					break

				y = ceiling

			added.append([snappedf(p.x, 0.1), snappedf(y, 0.1), snappedf(p.y, 0.1), 2.5, 2.5])

		if not ok or added.is_empty():
			ore_report["blocked"] += 1

			if OS.has_environment("ORE_STEER_LOG"):
				print("  ore blocked: id %s shape %s target %.0f,%.0f,%.0f from node %d (%.0f,%.0f,%.0f) %.0f m, %d steps: %s" % [str(ore["id"]), str(ore["shape"]), target.x, target.y, target.z, best, start.x, start.y, start.z, best_distance, steps, why])
			continue

		ore_report["reached"] += 1

		for node in added:
			nodes.append(node)
			var index: int = nodes.size() - 1
			var kind: String = "shaft" if absf(float(node[1]) - float(nodes[previous][1])) > step * 0.8 else "passage"
			cave["segments"].append([previous, index, kind])
			previous = index

		cave["exposes"].append(ore["id"])


# Where a passage should end to cut an ore body, or NAN.
func _ore_target(ore: Dictionary) -> Vector3:
	var shape: String = str(ore["shape"])

	match shape:
		"lens":
			return Vector3(float(ore["center"][0]), float(ore["center"][1]), float(ore["center"][2]))
		"halo":
			return Vector3(float(ore["center"][0]), float(ore["top_y"]) - 0.5 * float(ore["thickness_m"]), float(ore["center"][1]))
		"pipe":
			return Vector3(float(ore["center"][0]), float(ore["top_y"]) - 15.0, float(ore["center"][1]))
		"vein":
			var a: Vector2 = Vector2(float(ore["points"][0][0]), float(ore["points"][0][1]))
			var b: Vector2 = Vector2(float(ore["points"][1][0]), float(ore["points"][1][1]))
			var middle: Vector2 = (a + b) * 0.5
			return Vector3(middle.x, float(ore["top_y"]) - 20.0, middle.y)

	return Vector3(NAN, NAN, NAN)


# Depth below the province datum of the middle of the limestone layer the
# entrance cuts (layers repeat every cycle), or -1.
func _limestone_bed_depth(index: int) -> float:
	var entry: Dictionary = _geology.provinces[_geology.province[index]]
	var depth: float = float(entry["datum_m"]) + float(_geology.layer_offset[index]) * 0.1 - _heights[index]
	var cycle: float = float(entry["cycle_m"])

	if cycle <= 0.0 or depth < 0.0 or depth > float(entry["repeat_to_m"]):
		return -1.0

	var base: float = floor(depth / cycle) * cycle
	var best: float = -1.0
	var best_gap: float = INF

	for layer in entry["layers"]:
		if str(layer["rock"]) != "limestone":
			continue

		for k in [-1.0, 0.0, 1.0]:
			# A little below the outcrop so the passage dips under the hill.
			var middle: float = base + k * cycle + float(layer["top_m"]) + 0.6 * float(layer["thickness_m"])
			var gap: float = absf(middle - depth)

			if middle > 0.0 and gap < best_gap:
				best_gap = gap
				best = middle

	return best


func _bed_y(index: int, bed_depth: float) -> float:
	var entry: Dictionary = _geology.provinces[_geology.province[index]]
	return float(entry["datum_m"]) + float(_geology.layer_offset[index]) * 0.1 - bed_depth


# ==================================================
# LAVA TUBES, SEA CAVES, ROCK SHELTERS
# ==================================================

func _make_lava_tubes(rng: RandomNumberGenerator) -> void:
	var rules: Dictionary = _rules["lava_tube"]
	var step: float = float(_rules["step_m"])

	for feature in _geology.features:
		if str(feature["type"]) != "volcanic_vent":
			continue

		var center: Vector2 = Vector2(float(feature["center"][0]), float(feature["center"][1]))
		var radius: float = float(feature["radius_m"])
		var start_index: int = _index_at(center, float(_rules["edge_margin_m"]))

		if start_index < 0 or _water[start_index] != 0 or _heights[start_index] < 10.0:
			continue

		var cave: Dictionary = _new_cave("lava_tube", rng)
		var depth: float = rng.randf_range(float(rules["depth_m"][0]), float(rules["depth_m"][1]))
		var width: float = rng.randf_range(float(rules["width_m"][0]), float(rules["width_m"][1]))
		var height: float = rng.randf_range(float(rules["height_m"][0]), float(rules["height_m"][1]))
		var length: float = rng.randf_range(float(rules["length_m"][0]), float(rules["length_m"][1]))
		var heading: float = _uphill_angle(start_index) + PI + rng.randf_range(-0.4, 0.4)
		var p: Vector2 = center + Vector2(cos(heading), sin(heading)) * radius
		var travelled: float = 0.0
		var next_skylight: float = rng.randf_range(float(rules["skylight_every_m"][0]), float(rules["skylight_every_m"][1]))
		var nodes: Array = cave["nodes"]

		while travelled < length:
			var index: int = _index_at(p, float(_rules["edge_margin_m"]))

			if index < 0 or _water[index] != 0 or _heights[index] < depth + height:
				break

			var y: float = _heights[index] - depth - 0.5 * height
			nodes.append([snappedf(p.x, 0.1), snappedf(y, 0.1), snappedf(p.y, 0.1), snappedf(width * rng.randf_range(0.85, 1.15), 0.1), snappedf(height, 0.1)])

			if nodes.size() > 1:
				cave["segments"].append([nodes.size() - 2, nodes.size() - 1, "passage"])

			if travelled >= next_skylight:
				cave["entrances"].append(nodes.size() - 1)
				cave["skylights"].append(nodes.size() - 1)
				next_skylight += rng.randf_range(float(rules["skylight_every_m"][0]), float(rules["skylight_every_m"][1]))

			# Lava runs downhill.
			heading = lerp_angle(heading, _uphill_angle(index) + PI, 0.3) + rng.randf_range(-0.2, 0.2)
			p += Vector2(cos(heading), sin(heading)) * step
			travelled += step

		if nodes.size() < 10:
			continue

		# The lower end is open where the tube reaches the surface.
		cave["entrances"].append(nodes.size() - 1)
		caves.append(cave)


func _make_sea_caves(rng: RandomNumberGenerator) -> void:
	var rules: Dictionary = _rules["sea_cave"]
	var candidates: Array = []
	var margin: int = int(float(_rules["edge_margin_m"]) / _spacing)
	var sand: Array = [_tables.id_of("soils", "beach_sand"), _tables.id_of("soils", "sand")]

	for j in range(margin, _samples - margin, 3):
		for i in range(margin, _samples - margin, 3):
			var index: int = j * _samples + i

			if _water[index] != 0 or _heights[index] < 1.0 or sand.has(int(_soil[index])):
				continue

			# Ocean right next to it and the ground rising steeply inland.
			var sea: Vector2 = Vector2.ZERO

			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: int = (j + offset.y * 2) * _samples + i + offset.x * 2

				if _water[n] == OCEAN:
					sea = Vector2(offset)

			if sea == Vector2.ZERO:
				continue

			var inland: int = (j - int(sea.y) * 4) * _samples + i - int(sea.x) * 4

			if _heights[inland] - _heights[index] < float(rules["cliff_rise_m"]):
				continue

			candidates.append([index, -sea])

	_shuffle(candidates, rng)
	var wanted: int = rng.randi_range(int(rules["count"][0]), int(rules["count"][1]))
	var placed: Array = []
	var step: float = float(_rules["step_m"]) * 0.5

	for candidate in candidates:
		if placed.size() >= wanted:
			break

		var index: int = candidate[0]
		var point: Vector2 = _point_of(index)

		if _too_close(point, placed, float(rules["min_spacing_m"])) or _kept_clear(point):
			continue

		var direction: Vector2 = candidate[1]
		var cave: Dictionary = _new_cave("sea_cave", rng)
		var width: float = rng.randf_range(float(rules["width_m"][0]), float(rules["width_m"][1]))
		var height: float = rng.randf_range(float(rules["height_m"][0]), float(rules["height_m"][1]))
		var length: float = rng.randf_range(float(rules["length_m"][0]), float(rules["length_m"][1]))
		var y: float = 0.5 * height + 0.2
		var nodes: Array = cave["nodes"]
		var heading: float = direction.angle()
		var p: Vector2 = point
		var travelled: float = 0.0

		while travelled <= length:
			var at: int = _index_at(p, float(_rules["edge_margin_m"]))

			if at < 0 or (travelled > 0.0 and y + 0.5 * height > _heights[at] - 3.0):
				break

			nodes.append([snappedf(p.x, 0.1), snappedf(y, 0.1), snappedf(p.y, 0.1), snappedf(width, 0.1), snappedf(height, 0.1)])

			if nodes.size() > 1:
				cave["segments"].append([nodes.size() - 2, nodes.size() - 1, "water" if nodes.size() == 2 else "passage"])

			heading += rng.randf_range(-0.25, 0.25)
			p += Vector2(cos(heading), sin(heading)) * step
			travelled += step

		if nodes.size() < 3:
			continue

		cave["entrances"].append(0)
		cave["chambers"].append({
			"node": nodes.size() - 1, "features": [],
			"radius_m": snappedf(rng.randf_range(float(rules["chamber_radius_m"][0]), float(rules["chamber_radius_m"][1])), 0.1),
			"height_m": snappedf(height * 1.5, 0.1),
		})
		placed.append(point)
		caves.append(cave)


func _make_shelters(rng: RandomNumberGenerator) -> void:
	var rules: Dictionary = _rules["rock_shelter"]
	var min_slope: float = tan(deg_to_rad(float(rules["min_slope_deg"])))
	var candidates: Array = []
	var margin: int = int(float(_rules["edge_margin_m"]) / _spacing)

	for j in range(margin, _samples - margin, 4):
		for i in range(margin, _samples - margin, 4):
			var index: int = j * _samples + i

			if _water[index] == 0 and _heights[index] > 3.0 and _geology.cover[index] < 4 and _slope(index) > min_slope:
				candidates.append(index)

	_shuffle(candidates, rng)
	var wanted: int = rng.randi_range(int(rules["count"][0]), int(rules["count"][1]))
	var placed: Array = []

	for index in candidates:
		if placed.size() >= wanted:
			break

		var point: Vector2 = _point_of(index)

		if _too_close(point, placed, float(rules["min_spacing_m"])) or _kept_clear(point):
			continue

		var heading: float = _uphill_angle(index)
		var depth: float = rng.randf_range(float(rules["depth_m"][0]), float(rules["depth_m"][1]))
		var width: float = rng.randf_range(float(rules["width_m"][0]), float(rules["width_m"][1]))
		var height: float = rng.randf_range(float(rules["height_m"][0]), float(rules["height_m"][1]))
		var y: float = _heights[index] + 0.5 * height - 0.5
		var back: Vector2 = point + Vector2(cos(heading), sin(heading)) * depth
		var back_index: int = _index_at(back, 0.0)

		if back_index < 0 or _heights[back_index] < y + 0.5 * height + 2.0:
			continue

		var cave: Dictionary = _new_cave("rock_shelter", rng)
		cave["nodes"].append([snappedf(point.x, 0.1), snappedf(y, 0.1), snappedf(point.y, 0.1), snappedf(width, 0.1), snappedf(height, 0.1)])
		cave["nodes"].append([snappedf(back.x, 0.1), snappedf(y - 0.3, 0.1), snappedf(back.y, 0.1), snappedf(width * 0.6, 0.1), snappedf(height * 0.7, 0.1)])
		cave["segments"].append([0, 1, "passage"])
		cave["entrances"].append(0)
		placed.append(point)
		caves.append(cave)


# ==================================================
# SPRING CAVES
# ==================================================

# Dave 3 Nov 2026: "I really dont like the spring starting in the middle of the mountain thing. that might work if we make some sort of a natural cave
# that drills in about 100 meters at an uphill slope gently ... maybe put some branches off the main tunnel that creatures and animals like to live in",
# "then put the spring way at the back of the cave", "you could even put two or three caves in there with springs in each if that would increase the
# flow of water". So every brook head on a hillside (a river cell with no water above it and no pond round it) gets a cave: the mouth at the head, a
# passage rising gently into the hill, a spring chamber at the far end, the stream along the floor ("water" segments) and side branches ending in dens.
# Some caves (spring_cave.extra_passage_chance) get a second and a third spring passage fanning off the main one, each with its own spring at the back;
# their flows add up (every spring gives the head's spring flow). A brook head's catchment is small (the bake measured about 0.01 m3/s at every head on
# tile 3,4), so the flow cannot pick which brooks get more: chance does. cave["springs"] = [{node, m3_s}]. A main passage shorter than min_length_m
# (no room under the hill) gives no cave.
const SPRING_CAVE_DEFAULTS := {
	"min_slope_deg": 10.0, "min_spacing_m": 120.0, "max_count": 96, "length_m": [90.0, 115.0], "rise": [0.02, 0.05],
	"width_m": [3.0, 5.0], "height_m": [2.5, 4.0], "min_cover_m": 2.5, "open_cut_m": 64.0, "chamber_radius_m": [4.0, 7.0],
	"branches": [1, 3], "branch_length_m": [15.0, 40.0], "extra_passage_chance": [0.4, 0.15], "spring_m3_s_per_km2": 0.1, "min_length_m": 60.0,
	# Dave 4 Nov 2026: mouths match the river, small / medium / large caves, den tunnels climbing to a hollow, bones, stalagmites and stalactites.
	"size_odds": {"small": 0.45, "medium": 0.35, "large": 0.2}, "sizes": {}, "big_chambers": [0, 0], "big_chamber_radius_m": [5.0, 9.0],
	"big_chamber_height_m": [8.0, 14.0], "mouth_width_max_m": 30.0, "mouth_height_max_m": 12.0, "taper_min_m": 25.0, "taper_cover_m": 1.5,
	"den_rise": [0.1, 0.2], "den_radius_m": [3.0, 5.0], "den_height_m": [3.0, 4.0],
	# Dave 5 Nov 2026: a wide river needs many springs; the cave's size sets how many branches end in spring pools.
	"spring_per_mouth_m": 0.0, "max_springs": 3, "size_by_mouth_m": {},
	"bones": {"entrance_chance": 0.35, "end_chance": 0.35, "human_share": 0.2},
	"formations": {"per_chamber": [8, 20], "passage_min_width_m": 5.0, "passage_chance": 0.3},
}


func _spring_rule(key: String) -> Variant:
	return _rules.get("spring_cave", {}).get(key, SPRING_CAVE_DEFAULTS[key])


func _spring_range(key: String, rng: RandomNumberGenerator) -> float:
	var pair: Array = _spring_rule(key)
	return rng.randf_range(float(pair[0]), float(pair[1]))


# Brook heads on slopes: a RIVER sample with no RIVER or LAKE sample above it among its 8 neighbours, no LAKE within 3 samples (that head has its pond)
# and no river over 1 m higher within HEAD_CLEAR_CELLS.
func _brook_heads() -> Array:
	var heads: Array = []
	var margin: int = int(float(_rules["edge_margin_m"]) / _spacing) + 2
	var min_slope: float = tan(deg_to_rad(float(_spring_rule("min_slope_deg"))))

	for j in range(margin, _samples - margin):
		for i in range(margin, _samples - margin):
			var index: int = j * _samples + i

			if _water[index] != RIVER or _heights[index] < 2.0 or _slope(index) < min_slope:
				continue

			var head: bool = true

			for dj in range(-3, 4):
				for di in range(-3, 4):
					var n: int = (j + dj) * _samples + i + di

					if n == index:
						continue

					if _water[n] == LAKE or (absi(di) <= 1 and absi(dj) <= 1 and _water[n] == RIVER and _heights[n] > _heights[index]):
						head = false

			# And no river higher up within HEAD_CLEAR_CELLS: a sample at the edge of a wide channel has no higher river neighbour either, and the first
			# bake put 23 of its 41 cave mouths beside a brook that carried on above them.
			if head:
				for dj in range(-HEAD_CLEAR_CELLS, HEAD_CLEAR_CELLS + 1):
					for di in range(-HEAD_CLEAR_CELLS, HEAD_CLEAR_CELLS + 1):
						var n: int = (j + dj) * _samples + i + di

						if _water[n] == RIVER and _heights[n] > _heights[index] + 1.0:
							head = false

			if head:
				heads.append(index)

	return heads


func _spring_m3_s(index: int) -> float:
	if _flow.is_empty():
		return 0.01

	return clampf(float(_spring_rule("spring_m3_s_per_km2")) * _flow[index] * _spacing * _spacing / 1000000.0, 0.01, 2.0)


func _make_spring_caves(rng: RandomNumberGenerator) -> void:
	var heads: Array = _brook_heads()
	var placed: Array = []
	var made: int = 0
	var passages: int = 0
	var refused: int = 0
	# Biggest brooks first (they matter most when two heads are closer than min_spacing_m), then by place, so it is reproducible.
	heads.sort_custom(func(a: int, b: int) -> bool: return _spring_m3_s(a) > _spring_m3_s(b) or (_spring_m3_s(a) == _spring_m3_s(b) and a < b))

	for index in heads:
		if made >= int(_spring_rule("max_count")):
			break

		var point: Vector2 = _point_of(index)

		if _too_close(point, placed, float(_spring_rule("min_spacing_m"))) or _kept_clear(point):
			continue

		var cave: Dictionary = _spring_cave(index, rng)

		if cave.is_empty():
			refused += 1
			continue

		placed.append(point)
		caves.append(cave)
		made += 1
		passages += cave["springs"].size()

	print("  spring caves (Dave 3 Nov): %d brook heads on slopes, %d caves with %d spring passages, %d heads with no room for a cave" % [heads.size(), made, passages, refused])


# Dave 4 Nov: small, medium and large caves. A size the hill has no room for falls back to the next smaller one.
func _spring_cave(index: int, rng: RandomNumberGenerator) -> Dictionary:
	var sizes: Array = ["small", "medium", "large"]

	var wanted_size: String = _pick_size(rng)
	# The river sets the size (Dave 5 Nov 2026: "depending on the initial cave size determines how far in it goes and how many branches end in spring
	# pools"): a river at least size_by_mouth_m.large wide at the mouth gets a large cave, at least .medium a medium one, whatever the odds rolled;
	# a cave with no room for that size still steps down.
	var by_mouth: Dictionary = _spring_rule("size_by_mouth_m")

	if not by_mouth.is_empty():
		var mouth_w: float = _river_width(index, _uphill_angle(index))

		for key in ["large", "medium"]:
			if by_mouth.has(key) and mouth_w >= float(by_mouth[key]) and sizes.find(key) > sizes.find(wanted_size):
				wanted_size = key
				break

	for k in range(sizes.find(wanted_size), -1, -1):
		var local_before: int = _local
		var cave: Dictionary = _spring_cave_of(index, sizes[k], rng)

		if not cave.is_empty():
			return cave

		_local = local_before

	return {}


func _spring_cave_of(index: int, size: String, rng: RandomNumberGenerator) -> Dictionary:
	var m3_s: float = _spring_m3_s(index)
	var extra: Array = _size_rule(size, "extra_passage_chance")
	var wanted: int = 1
	var roll: float = rng.randf()

	if roll < float(extra[0]):
		wanted = 3 if roll < float(extra[1]) else 2

	# A wide river needs many springs (Dave 5 Nov 2026: "if its this wide it will need many pools to create that much water. so depending on the initial
	# cave size determines how far in it goes and how many branches end in spring pools"): one spring passage per spring_per_mouth_m of the river's width
	# at the mouth, up to the size's max_springs; the flows join on the way out.
	var per_m: float = float(_spring_rule("spring_per_mouth_m"))
	var water_m3_s: float = m3_s * float(wanted)   # as before: the chance passages each brought a spring's worth; now shared by all the springs

	if per_m > 0.0:
		var mouth_w: float = clampf(_river_width(index, _uphill_angle(index)), 0.0, float(_spring_rule("mouth_width_max_m")))
		wanted = maxi(wanted, mini(int(round(mouth_w / per_m)), int(_size_rule(size, "max_springs"))))

	var cave: Dictionary = _new_cave("spring_cave", rng)
	cave["size"] = size
	var width: float = _size_range(size, "width_m", rng)
	var height: float = _size_range(size, "height_m", rng)
	var point: Vector2 = _point_of(index)
	# The mouth: the floor half a metre under the head, so the stream runs straight out onto it.
	cave["nodes"].append([snappedf(point.x, 0.1), snappedf(_heights[index] + 0.5 * height - 0.5, 0.1), snappedf(point.y, 0.1), snappedf(width, 0.1), snappedf(height, 0.1)])
	cave["entrances"].append(0)
	var heading: float = _uphill_angle(index)
	var main: Array = _spring_passage(cave, 0, heading, _size_range(size, "length_m", rng), width, height, rng)

	if main.size() < 3 or _node_distance(cave, 0, main[main.size() - 1]) < float(_size_rule(size, "min_length_m")):
		return {}

	var springs: Array = [main[main.size() - 1]]

	# More water: extra spring passages leave the main one 15 to 60 percent of the way in (spread out when there are many), turned 30 to 50 degrees,
	# to alternate sides.
	var first_side: float = 1.0 if rng.randf() < 0.5 else -1.0

	for k in range(wanted - 1):
		var share: float = lerpf(0.15, 0.6, (float(k) + rng.randf()) / float(maxi(wanted - 1, 1)))
		var from: int = main[clampi(int(round(float(main.size() - 1) * share)), 1, main.size() - 2)]
		var side: float = (1.0 if k % 2 == 0 else -1.0) * first_side * deg_to_rad(rng.randf_range(30.0, 50.0))
		var arm: Array = _spring_passage(cave, from, heading + side, _size_range(size, "length_m", rng) * 0.8, width * 0.85, height * 0.9, rng)

		if arm.size() >= 3:
			springs.append(arm[arm.size() - 1])

	cave["springs"] = []

	for node in springs:
		cave["chambers"].append({
			"node": int(node), "features": ["spring"],
			"radius_m": snappedf(_size_range(size, "chamber_radius_m", rng), 0.1), "height_m": snappedf(height * 1.4, 0.1),
		})
		cave["springs"].append({"node": int(node), "m3_s": snappedf(water_m3_s / float(springs.size()), 0.001)})   # the cave's water, shared by its springs

	# Large caves: big chambers along the main passage, roomy enough for stalagmites and stalactites (Dave 4 Nov).
	var big: Array = []

	for k in range(rng.randi_range(int(_size_rule(size, "big_chambers")[0]), int(_size_rule(size, "big_chambers")[1]))):
		var at: int = main[clampi(int(round(float(main.size() - 1) * rng.randf_range(0.35, 0.75))), 1, main.size() - 2)]
		var chamber: Dictionary = _hollow(cave, at, _size_range(size, "big_chamber_radius_m", rng), _size_range(size, "big_chamber_height_m", rng), "big", 4.0)

		if not chamber.is_empty():
			big.append(chamber)

	# Den tunnels off the spring passages: they climb (so the stream never runs up them) and end in a dry den hollow (Dave 4 Nov).
	var stream: Array = []

	for segment in cave["segments"]:
		if str(segment[2]) == "water" and int(segment[0]) > 0:
			stream.append(int(segment[0]))

	cave["den_nodes"] = []
	var hollows: Array = []
	var branches: int = rng.randi_range(int(_size_rule(size, "branches")[0]), int(_size_rule(size, "branches")[1]))

	for k in range(branches):
		if stream.is_empty():
			break

		var from: int = stream[rng.randi_range(0, stream.size() - 1)]
		var turn: float = (1.0 if rng.randf() < 0.5 else -1.0) * deg_to_rad(rng.randf_range(60.0, 110.0))
		var nodes_before: int = cave["nodes"].size()
		var segments_before: int = cave["segments"].size()
		var arm: Array = _cave_arm(cave, from, heading + turn, _spring_range("branch_length_m", rng), width * 0.7, height * 0.8, _spring_range("den_rise", rng), "passage", rng)
		var hollow: Dictionary = {}

		if arm.size() >= 3:
			hollow = _hollow(cave, arm[arm.size() - 1], _spring_range("den_radius_m", rng), _spring_range("den_height_m", rng), "den", 2.2)

		if hollow.is_empty():
			cave["nodes"].resize(nodes_before)
			cave["segments"].resize(segments_before)
			continue

		cave["den_nodes"].append(int(hollow["node"]))
		hollows.append(hollow)

	# Dave 4 Nov: the mouth is as wide as the river it feeds and narrows going in (after the rooms and tunnels, which are set from the passage floor).
	_taper_mouth(cave, main, index, heading, width, height)
	_dress_cave(cave, main, springs, big, hollows, rng)
	return cave


func _size_rule(size: String, key: String) -> Variant:
	var sizes: Dictionary = _spring_rule("sizes")
	return sizes.get(size, {}).get(key, _spring_rule(key))


func _size_range(size: String, key: String, rng: RandomNumberGenerator) -> float:
	var pair: Array = _size_rule(size, key)
	return rng.randf_range(float(pair[0]), float(pair[1]))


# Small, medium or large (Dave 4 Nov), by spring_cave.size_odds.
func _pick_size(rng: RandomNumberGenerator) -> String:
	var odds: Dictionary = _spring_rule("size_odds")
	var total: float = 0.0

	for key in odds:
		total += float(odds[key])

	var roll: float = rng.randf() * total

	for key in ["small", "medium", "large"]:
		roll -= float(odds.get(key, 0.0))

		if roll < 0.0:
			return key

	return "medium"


func _ground_at(p: Vector2) -> float:
	var at: int = _index_at(p, 0.0)
	return _heights[at] if at >= 0 else -INF


# Width of the river at a brook head: water samples counted across the flow at the head and a few samples downstream, the widest.
func _river_width(index: int, uphill: float) -> float:
	var down: Vector2 = -Vector2(cos(uphill), sin(uphill))
	var across: Vector2 = Vector2(-down.y, down.x)
	var step: float = 0.5 * _spacing
	var head: Vector2 = _point_of(index)
	var widest: float = 0.0

	for k in range(4):
		var at: Vector2 = head + down * _spacing * float(k)
		var run: float = step

		for side in [-1.0, 1.0]:
			for n in range(1, 16):
				var i: int = _index_at(at + across * step * float(n) * side, 0.0)

				if i < 0 or _water[i] != RIVER:
					break

				run += step

		widest = maxf(widest, run)

	return widest


# The mouth matches the river (Dave 4 Nov): its width is the river's, its height half that (within the passage height and mouth_height_max_m), and both
# narrow to the passage's over taper_m (at least a third of the passage). The floor stays where it was; the roof keeps taper_cover_m of ground over it
# (where the hill is thinner the opening is lower, as a real one would be).
func _taper_mouth(cave: Dictionary, main: Array, head: int, uphill: float, width: float, height: float) -> void:
	var nodes: Array = cave["nodes"]
	var mouth_w: float = clampf(_river_width(head, uphill), width, float(_spring_rule("mouth_width_max_m")))
	var mouth_h: float = clampf(0.5 * mouth_w, height, float(_spring_rule("mouth_height_max_m")))
	var length: float = 0.0

	for k in range(1, main.size()):
		length += _node_distance(cave, main[k - 1], main[k])

	var taper: float = maxf(float(_spring_rule("taper_min_m")), length / 3.0)
	var along: float = 0.0
	cave["mouth_width_m"] = snappedf(mouth_w, 0.1)

	for k in range(main.size()):
		if k > 0:
			along += _node_distance(cave, main[k - 1], main[k])

		var node: Array = nodes[main[k]]
		var t: float = smoothstep(0.0, taper, along)
		var w: float = lerpf(mouth_w, float(node[3]), t)
		var h: float = lerpf(mouth_h, float(node[4]), t)
		var floor_y: float = float(node[1]) - 0.5 * float(node[4])

		if k > 0:
			var room: float = _ground_at(Vector2(float(node[0]), float(node[2]))) - float(_spring_rule("taper_cover_m")) - floor_y
			h = clampf(h, float(node[4]), maxf(float(node[4]), room))

		node[1] = snappedf(floor_y + 0.5 * h, 0.1)
		node[3] = snappedf(w, 0.1)
		node[4] = snappedf(h, 0.1)


# A round room at the end or along a passage (a den hollow, or a large cave's big chamber): a node of its own, unlinked, set so the room's floor is level
# with the passage floor at `at` (the room is carved as an ellipsoid round its node). It is made lower to keep min_cover_m of ground over it, and not at all
# if under `lowest` m fits. Returns the chamber, or {} when no room fits.
func _hollow(cave: Dictionary, at: int, radius: float, height: float, feature: String, lowest: float) -> Dictionary:
	var nodes: Array = cave["nodes"]
	var node: Array = nodes[at]
	var floor_y: float = float(node[1]) - 0.5 * float(node[4])
	var p: Vector2 = Vector2(float(node[0]), float(node[2]))
	var room: float = INF

	for k in range(9):
		var reach: Vector2 = Vector2.ZERO if k == 0 else Vector2(cos(TAU * float(k) / 8.0), sin(TAU * float(k) / 8.0)) * radius * 0.6
		room = minf(room, _ground_at(p + reach) - float(_spring_rule("min_cover_m")) - floor_y)

	height = minf(height, room)

	if height < lowest:
		return {}

	nodes.append([snappedf(p.x, 0.1), snappedf(floor_y + 0.5 * height - 0.2, 0.1), snappedf(p.y, 0.1), snappedf(2.0 * radius, 0.1), snappedf(height, 0.1)])
	var chamber: Dictionary = {"node": nodes.size() - 1, "features": [feature], "radius_m": snappedf(radius, 0.1), "height_m": snappedf(height, 0.1)}
	cave["chambers"].append(chamber)
	return chamber


# Bones at the entrance and at far ends, stalagmites and stalactites in large caves (Dave 4 Nov). The client draws them (Kathreen); here only the spots.
# cave["bones"] = [{pos, kind: animal|human, yaw}], cave["formations"] = [{pos, kind: stalagmite|stalactite, height_m, radius_m}] (a stalactite's pos is
# its root on the roof). Nothing lies on the stream: spots keep to the sides of a passage (the stream ribbon is 0.3 of its width either side).
func _dress_cave(cave: Dictionary, main: Array, springs: Array, big: Array, hollows: Array, rng: RandomNumberGenerator) -> void:
	var nodes: Array = cave["nodes"]
	var bones_rule: Dictionary = _spring_rule("bones")
	cave["bones"] = []
	cave["formations"] = []

	# Just inside the entrance: beside the stream, on the first node 8 m or more in.
	if rng.randf() < float(bones_rule["entrance_chance"]):
		for k in range(1, main.size()):
			if _node_distance(cave, 0, main[k]) >= 8.0:
				_add_bones(cave, _beside_stream(nodes[main[k]], rng), rng)
				break

	# At a far end: in a den hollow, or beside the last stretch of passage before a spring pool.
	if rng.randf() < float(bones_rule["end_chance"]):
		var ends: Array = []

		for hollow in hollows:
			var n: Array = nodes[int(hollow["node"])]
			var a: float = rng.randf_range(0.0, TAU)
			var d: float = float(hollow["radius_m"]) * rng.randf_range(0.0, 0.5)
			ends.append(Vector3(float(n[0]) + cos(a) * d, float(n[1]) - 0.5 * float(n[4]) + 0.2, float(n[2]) + sin(a) * d))

		for spring in springs:
			for segment in cave["segments"]:
				if int(segment[1]) == int(spring):
					ends.append(_beside_stream(nodes[int(segment[0])], rng))

		if not ends.is_empty():
			_add_bones(cave, ends[rng.randi_range(0, ends.size() - 1)], rng)

	# Large caves: a spread of stalagmites and stalactites in each big chamber, and now and then at the side of a wide passage.
	var forms: Dictionary = _spring_rule("formations")

	for chamber in big:
		var n: Array = nodes[int(chamber["node"])]
		var r: float = float(chamber["radius_m"])
		var rh: float = 0.5 * float(chamber["height_m"])

		for k in range(rng.randi_range(int(forms["per_chamber"][0]), int(forms["per_chamber"][1]))):
			var a: float = rng.randf_range(0.0, TAU)
			var d: float = r * sqrt(rng.randf_range(0.04, 0.7))
			var curve: float = sqrt(maxf(1.0 - pow(d / r, 2.0), 0.0))
			var floor_y: float = float(n[1]) - rh * curve
			var roof_y: float = float(n[1]) + rh * curve
			var at: Vector3 = Vector3(float(n[0]) + cos(a) * d, 0.0, float(n[2]) + sin(a) * d)

			if _near_stream(cave, at, 1.5):
				continue

			_add_formation(cave, at, floor_y, roof_y, rng)

	if str(cave.get("size", "")) == "large":
		for k in range(1, main.size()):
			var n: Array = nodes[main[k]]

			if float(n[3]) < float(forms["passage_min_width_m"]) or rng.randf() > float(forms["passage_chance"]):
				continue

			var side: float = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.36, 0.42) * float(n[3])
			var dir: Vector2 = _passage_dir(cave, main[k])
			var off: Vector2 = Vector2(-dir.y, dir.x) * side
			var rh: float = 0.5 * float(n[4])
			var curve: float = sqrt(maxf(1.0 - pow(side / (0.5 * float(n[3])), 2.0), 0.0))
			_add_formation(cave, Vector3(float(n[0]) + off.x, 0.0, float(n[2]) + off.y), float(n[1]) - rh * curve, float(n[1]) + rh * curve, rng)


func _add_bones(cave: Dictionary, at: Vector3, rng: RandomNumberGenerator) -> void:
	var kind: String = "human" if rng.randf() < float(_spring_rule("bones")["human_share"]) else "animal"
	cave["bones"].append({"pos": [snappedf(at.x, 0.1), snappedf(at.y, 0.1), snappedf(at.z, 0.1)], "kind": kind, "yaw": snappedf(rng.randf_range(0.0, TAU), 0.01)})


# A stalagmite on the floor or a stalactite from the roof, its height a share of the clear height there (so the two never meet).
func _add_formation(cave: Dictionary, at: Vector3, floor_y: float, roof_y: float, rng: RandomNumberGenerator) -> void:
	var clear: float = roof_y - floor_y

	if clear < 2.5:
		return

	var up: bool = rng.randf() < 0.5
	var tall: float = clampf(clear * rng.randf_range(0.12, 0.35), 0.4, 4.0)
	var radius: float = clampf(tall * rng.randf_range(0.12, 0.25), 0.08, 0.8)
	var y: float = floor_y if up else roof_y
	cave["formations"].append({
		"pos": [snappedf(at.x, 0.1), snappedf(y, 0.1), snappedf(at.z, 0.1)], "kind": "stalagmite" if up else "stalactite",
		"height_m": snappedf(tall, 0.1), "radius_m": snappedf(radius, 0.01),
	})


# A floor spot at the side of a passage node, clear of the stream ribbon.
func _beside_stream(node: Array, rng: RandomNumberGenerator) -> Vector3:
	var w: float = float(node[3])
	var side: float = (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(0.34, 0.4) * w
	var rh: float = 0.5 * float(node[4])
	var curve: float = sqrt(maxf(1.0 - pow(side / (0.5 * w), 2.0), 0.0))
	var a: float = rng.randf_range(0.0, TAU)
	return Vector3(float(node[0]) + cos(a) * side, float(node[1]) - rh * curve + 0.1, float(node[2]) + sin(a) * side)


func _passage_dir(cave: Dictionary, n: int) -> Vector2:
	for segment in cave["segments"]:
		if int(segment[1]) == n:
			var a: Array = cave["nodes"][int(segment[0])]
			var b: Array = cave["nodes"][n]
			return Vector2(float(b[0]) - float(a[0]), float(b[2]) - float(a[2])).normalized()

	return Vector2.RIGHT


func _near_stream(cave: Dictionary, at: Vector3, margin: float) -> bool:
	var p: Vector2 = Vector2(at.x, at.z)

	for segment in cave["segments"]:
		if str(segment[2]) != "water":
			continue

		var a: Array = cave["nodes"][int(segment[0])]
		var b: Array = cave["nodes"][int(segment[1])]
		var pa: Vector2 = Vector2(float(a[0]), float(a[2]))
		var pb: Vector2 = Vector2(float(b[0]), float(b[2]))

		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pa, pb)) < 0.3 * minf(float(a[3]), float(b[3])) + margin:
			return true

	return false


func _node_distance(cave: Dictionary, a: int, b: int) -> float:
	var na: Array = cave["nodes"][a]
	var nb: Array = cave["nodes"][b]
	return Vector2(float(na[0]), float(na[2])).distance_to(Vector2(float(nb[0]), float(nb[2])))


# A spring passage from node `from`: first an open cut (no cover needed, up to open_cut_m), then under cover, rising gently. Segments are "water" (the
# stream runs down them to the mouth). Returns the node indices of the passage, `from` first; under 3 means it found no room (and adds nothing).
func _spring_passage(cave: Dictionary, from: int, heading: float, length: float, width: float, height: float, rng: RandomNumberGenerator) -> Array:
	var nodes_before: int = cave["nodes"].size()
	var segments_before: int = cave["segments"].size()
	var path: Array = _cave_arm(cave, from, heading, length, width, height, _spring_range("rise", rng), "water", rng)

	if path.size() < 3:
		cave["nodes"].resize(nodes_before)
		cave["segments"].resize(segments_before)
		return []

	return path


# Walks a passage from node `from` along `heading` (with a gentle wander) for `length` m, the floor rising `rise` per metre. Nodes are only kept where the
# roof has min_cover_m of ground over it; until the first such node (within open_cut_m) the passage is an open cut into the slope, after that a shallow
# roof ends the passage. Only a passage from the mouth (node 0) starts with a cut. Returns [from, new nodes...].
func _cave_arm(cave: Dictionary, from: int, heading: float, length: float, width: float, height: float, rise: float, kind: String, rng: RandomNumberGenerator) -> Array:
	var nodes: Array = cave["nodes"]
	var start: Array = nodes[from]
	var p: Vector2 = Vector2(float(start[0]), float(start[2]))
	var y: float = float(start[1])
	var step: float = float(_rules["step_m"]) * 0.5
	var cover: float = float(_spring_rule("min_cover_m"))
	var open_cut: float = float(_spring_rule("open_cut_m"))
	var travelled: float = 0.0
	var last: int = from
	var path: Array = [from]

	while travelled < length:
		heading += rng.randf_range(-0.12, 0.12)
		p += Vector2(cos(heading), sin(heading)) * step
		y += rise * step
		travelled += step
		var at: int = _index_at(p, float(_rules["edge_margin_m"]))

		if at < 0 or _water[at] == OCEAN:
			break

		if y + 0.5 * height > _heights[at] - cover:
			if path.size() == 1 and from == 0 and travelled <= open_cut:
				continue   # still in the cut: no node here yet

			break

		nodes.append([snappedf(p.x, 0.1), snappedf(y, 0.1), snappedf(p.y, 0.1), snappedf(width, 0.1), snappedf(height, 0.1)])
		cave["segments"].append([last, nodes.size() - 1, kind])
		last = nodes.size() - 1
		path.append(last)

	return path


# ==================================================
# DENS, SUMMARY AND LAIRS
# ==================================================

func _finish_cave(cave: Dictionary, rng: RandomNumberGenerator) -> void:
	var rules: Dictionary = _rules["dens"]
	var nodes: Array = cave["nodes"]
	var entrance: Array = nodes[int(cave["entrances"][0])]
	var entrance_y: float = float(entrance[1])
	var lowest: float = INF
	var length: float = 0.0
	var bounds_min: Vector3 = Vector3(INF, INF, INF)
	var bounds_max: Vector3 = Vector3(-INF, -INF, -INF)
	var links: PackedInt32Array = PackedInt32Array()
	links.resize(nodes.size())

	for node in nodes:
		var half: float = 0.5 * maxf(float(node[3]), float(node[4]))
		bounds_min = bounds_min.min(Vector3(float(node[0]) - half, float(node[1]) - half, float(node[2]) - half))
		bounds_max = bounds_max.max(Vector3(float(node[0]) + half, float(node[1]) + half, float(node[2]) + half))
		lowest = minf(lowest, float(node[1]))

	for chamber in cave["chambers"]:
		var node: Array = nodes[int(chamber["node"])]
		var r: float = float(chamber["radius_m"])
		var below: float = float(chamber.get("chasm_depth_m", 0.0))
		bounds_min = bounds_min.min(Vector3(float(node[0]) - r, float(node[1]) - below - 2.0, float(node[2]) - r))
		bounds_max = bounds_max.max(Vector3(float(node[0]) + r, float(node[1]) + float(chamber["height_m"]), float(node[2]) + r))

	for segment in cave["segments"]:
		var a: Array = nodes[int(segment[0])]
		var b: Array = nodes[int(segment[1])]
		length += Vector3(float(a[0]), float(a[1]), float(a[2])).distance_to(Vector3(float(b[0]), float(b[1]), float(b[2])))
		links[int(segment[0])] += 1
		links[int(segment[1])] += 1

	cave["bounds"] = [snappedf(bounds_min.x, 0.1), snappedf(bounds_min.y, 0.1), snappedf(bounds_min.z, 0.1),
		snappedf(bounds_max.x, 0.1), snappedf(bounds_max.y, 0.1), snappedf(bounds_max.z, 0.1)]
	cave["length_m"] = snappedf(length, 0.1)
	cave["depth_m"] = snappedf(maxf(entrance_y - lowest, 0.0), 0.1)
	cave.erase("has_cavern")

	# Dens: chambers, dead ends, and just inside the entrance.
	var danger: float = _settings.danger_at(float(entrance[0]), float(entrance[2]))
	var spots: Array = []

	for chamber in cave["chambers"]:
		if rng.randf() < float(rules["chamber_chance"]):
			spots.append([int(chamber["node"]), "chamber"])

	# Spring cave side branches: animals live at their ends (Dave 3 Nov 2026).
	var branch_ends: Array = cave.get("den_nodes", [])

	for n in branch_ends:
		spots.append([int(n), "branch"])

	cave.erase("den_nodes")

	for n in range(1, nodes.size()):
		if links[n] == 1 and not cave["entrances"].has(n) and not branch_ends.has(n) and rng.randf() < float(rules["dead_end_chance"]):
			spots.append([n, "dead_end"])

	if str(cave["cave_kind"]) != "rock_shelter":
		for n in range(1, nodes.size()):
			var node: Array = nodes[n]

			if Vector2(float(node[0]), float(node[2])).distance_to(Vector2(float(entrance[0]), float(entrance[2]))) > float(rules["near_entrance_m"]):
				spots.append([n - 1, "near_entrance"])
				break
	elif rng.randf() < 0.5:
		spots.append([1, "shelter"])

	for spot in spots:
		var node: Array = nodes[int(spot[0])]
		var depth: float = maxf(entrance_y - float(node[1]), 0.0)
		var tier: int = clampi(1 + int(floor(danger * 4.0)) + int(floor(depth / float(rules["depth_per_tier_m"]))), 1, 5)
		cave["dens"].append({"node": int(spot[0]), "where": spot[1], "tier": tier})


func _make_lairs() -> void:
	for cave in caves:
		if cave["chambers"].is_empty() or cave["dens"].is_empty():
			continue

		var biggest: Dictionary = cave["chambers"][0]

		for chamber in cave["chambers"]:
			if float(chamber["radius_m"]) > float(biggest["radius_m"]):
				biggest = chamber

		_local += 1
		# Defensible and hidden: one way in, room inside, out of sight.
		var score: float = clampf(float(biggest["radius_m"]) / 30.0, 0.0, 1.0) * 0.5 \
			+ (0.3 if cave["entrances"].size() == 1 else 0.1) + clampf(float(cave["depth_m"]) / 100.0, 0.0, 0.2)
		lairs.append({
			"id": "%d,%d#%d" % [_tile.x, _tile.y, _local], "home_tile": [_tile.x, _tile.y], "local_id": _local,
			"kind": "dormant_lair", "cave": cave["id"], "node": biggest["node"],
			"score": snappedf(score, 0.01), "state": "empty",
		})


# ==================================================
# STARTER DATA AND HARBOR
# ==================================================

func _make_starter(info: Dictionary, river_mouth: Vector2) -> void:
	var rules: Dictionary = _rules["starter"]
	var bay: Vector2 = info["bay_center"]
	var radius: float = float(info["bay_radius_m"])
	_local += 1
	harbor = {
		"id": "%d,%d#%d" % [_tile.x, _tile.y, _local], "home_tile": [_tile.x, _tile.y], "local_id": _local,
		"kind": "harbor", "center": [snappedf(bay.x, 0.1), snappedf(bay.y, 0.1)], "radius_m": snappedf(radius, 0.1),
	}

	# Spawn on the beach at the bay head, beside the starter river mouth
	# (or the low land nearest the bay center when there is no river).
	var target: Vector2 = bay if is_nan(river_mouth.x) else river_mouth
	var best: int = -1
	var best_distance: float = INF

	for j in range(0, _samples, 2):
		for i in range(0, _samples, 2):
			var index: int = j * _samples + i
			var h: float = _heights[index]

			if _water[index] != 0 or h < float(rules["spawn_height_m"][0]) or h > float(rules["spawn_height_m"][1]):
				continue

			var distance: float = _point_of(index).distance_to(target)

			if distance < best_distance:
				best_distance = distance
				best = index

	if best < 0:
		return

	var spawn: Vector2 = _point_of(best)

	# Town block: the flattest dry ground a short walk inland from the spawn.
	var town: int = -1
	var town_score: float = INF

	for j in range(0, _samples, 4):
		for i in range(0, _samples, 4):
			var index: int = j * _samples + i
			var h: float = _heights[index]
			var distance: float = _point_of(index).distance_to(spawn)

			if _water[index] != 0 or h < float(rules["town_height_m"][0]) or h > float(rules["town_height_m"][1]) \
					or distance < float(rules["town_search_m"][0]) or distance > float(rules["town_search_m"][1]):
				continue

			var roughness: float = 0.0

			for dz in range(-4, 5, 2):
				for dx in range(-4, 5, 2):
					var n: int = clampi(j + dz, 0, _samples - 1) * _samples + clampi(i + dx, 0, _samples - 1)
					roughness = maxf(roughness, absf(_heights[n] - h))

			var score: float = roughness + distance * 0.004

			if score < town_score:
				town_score = score
				town = index

	starter = {
		"spawn_point": [snappedf(spawn.x, 0.1), snappedf(_heights[best] + 1.0, 0.1), snappedf(spawn.y, 0.1)],
	}

	if town >= 0:
		var block: Vector2 = _point_of(town)
		starter["town_block"] = [snappedf(block.x, 0.1), snappedf(_heights[town], 0.1), snappedf(block.y, 0.1)]
		_keep_clear.append([block, float(_rules["town_clear_m"])])

	_keep_clear.append([spawn, float(_rules["town_clear_m"])])


# ==================================================
# HELPERS
# ==================================================

func _new_cave(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	_local += 1
	return {
		"id": "%d,%d#%d" % [_tile.x, _tile.y, _local], "home_tile": [_tile.x, _tile.y], "local_id": _local,
		"kind": "cave_system", "cave_kind": kind, "seed": rng.randi() & 0x3fffffff,
		"nodes": [], "segments": [], "chambers": [], "entrances": [], "skylights": [], "dens": [], "exposes": [],
	}


func _point_of(index: int) -> Vector2:
	return Vector2(_x0 + float(index % _samples) * _spacing, _z0 + float(index / _samples) * _spacing)


# Sample index at a world point at least `margin` meters inside the tile, or -1.
func _index_at(p: Vector2, margin: float) -> int:
	if p.x < _x0 + margin or p.y < _z0 + margin or p.x > _x0 + _tile_m - margin or p.y > _z0 + _tile_m - margin:
		return -1

	var i: int = clampi(int(round((p.x - _x0) / _spacing)), 0, _samples - 1)
	var j: int = clampi(int(round((p.y - _z0) / _spacing)), 0, _samples - 1)
	return j * _samples + i


func _gradient(index: int) -> Vector2:
	var i: int = index % _samples
	var j: int = index / _samples
	var east: float = _heights[j * _samples + mini(i + 2, _samples - 1)]
	var west: float = _heights[j * _samples + maxi(i - 2, 0)]
	var south: float = _heights[mini(j + 2, _samples - 1) * _samples + i]
	var north: float = _heights[maxi(j - 2, 0) * _samples + i]
	return Vector2(east - west, south - north) / (4.0 * _spacing)


func _slope(index: int) -> float:
	return _gradient(index).length()


func _uphill_angle(index: int) -> float:
	var g: Vector2 = _gradient(index)
	return g.angle() if g.length() > 0.0001 else 0.0


func _too_close(point: Vector2, placed: Array, spacing: float) -> bool:
	for other in placed:
		if point.distance_to(other) < spacing:
			return true

	for cave in caves:
		var entrance: Array = cave["nodes"][int(cave["entrances"][0])]

		if point.distance_to(Vector2(float(entrance[0]), float(entrance[2]))) < 120.0:
			return true

	return false


func _kept_clear(point: Vector2) -> bool:
	for area in _keep_clear:
		if point.distance_to(area[0]) < float(area[1]):
			return true

	return false


func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for k in range(list.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, k)
		var swap: Variant = list[k]
		list[k] = list[other]
		list[other] = swap
