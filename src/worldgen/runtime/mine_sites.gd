extends RefCounted

# Abandoned mines (Dave 19 Nov 2026: "abandoned mines that already have bracing", sized from how medieval mines were built; provisional CD-5, CD-6 in
# docs/design/CAVE_DENS_AND_MINES.md, research in the Library caves-mines/PLAN.md). Worked out from the tile's own ore bodies and heights when the tile
# loads, never baked, so the same world seed gives the same mines and nothing in the tile files changes. Each mine comes back in the baked caves'
# skeleton form (nodes [x, y, z, width, height] with y the passage middle, segments, chambers, entrances), so TileTerrainData._load_caves carves it,
# scatters stones on its floor, counts it for shelter and cave air and keeps flora out of its mouth like any cave. On top of a cave it carries:
#   "timbers"  [x, y, z, kind, yaw] dressing rows (cave_bones kinds 6 timber set, 7 post, 8 fallen set; protocol 142), looks only (CD-6)
#   "extra"    [x, y, z, kind, value] scatter rows: kind 0 stone, 1 boulder (value its radius), 2 a leftover item (value its index in LEFTOVERS)
#
# The shape (Agricola, De re metallica V; medieval galleries in Metalla 22.2): an adit driven into a hillside low down, rising 1 in 100 toward the
# ore so water drains out of the mouth; at the ore, drifts along the body and rooms (stopes) where it was taken out; on a large mine an air shaft up
# toward the surface, fallen in near the top. Timber sets every 1.5 fathoms (2.7 m) through the mouth, the rest bare rock; props in the stopes.
# Outside, a spoil heap of broken rock fanned downhill. The adit is 1.8 m wide and 2.4 m tall: Agricola's 1.15 m x 2.3 m, widened to the
# 0.9-voxel carve minimum (terrain_generator.gd CAVE_MIN_VOXELS) so the 1 m voxels never close it.

const ADIT_W := 1.8
const ADIT_H := 2.4
const RISE := 0.01                 # 1 m up per 100 m in (Agricola: "for every one hundred fathoms of length, rises in grade one fathom")
const ORES := {"copper": "copper_ore", "tin": "tin_ore", "iron": "iron_ore"}   # mined ore bodies and the item a broken piece of each is
const SHAPES := ["lens", "halo", "pipe"]   # compact bodies with a centre (veins are parked; coal and salt layers wait for bell pits, CD-7)
const PER_TILE := Vector2i(2, 4)
const MIN_SPACING_M := 400.0       # between two mines' ore targets
const CAVE_CLEAR_M := 150.0        # a mouth this far from any baked cave's
const START_CLEAR_M := 400.0       # and from the start area (Edda and Hob's camp beside the spawn), where players build first
const EDGE_MARGIN_M := 300.0       # whole mine inside its tile, like the baked caves
const RINGS_M := [40.0, 60.0, 85.0, 115.0, 150.0, 200.0, 260.0, 330.0]   # how far out from the ore a mouth is looked for, nearest first
const DIRECTIONS := 24
const SLOPE := Vector2(0.18, 0.7)  # a mouth on ground from 10 to 35 degrees
const COVER_M := 2.0               # rock over the roof past the open cut
const OPEN_CUT_M := 6.0
const SET_EVERY_M := 2.7
const SIZES := {
	"small": {"max_len": 80.0, "drift": [10.0, 25.0], "sides": 1, "stopes": [1, 1], "timbered": 6.0, "shaft": false, "fallen": 0.0},
	"medium": {"max_len": 160.0, "drift": [15.0, 40.0], "sides": 2, "stopes": [2, 2], "timbered": 10.0, "shaft": false, "fallen": 0.5},
	"large": {"max_len": INF, "drift": [25.0, 60.0], "sides": 2, "stopes": [3, 4], "timbered": 15.0, "shaft": true, "fallen": 1.0},
}
const LEFTOVERS := ["stone_pickaxe", "copper_pickaxe", "bucket", "rope", "wooden_lantern_dark", "copper_ore", "tin_ore", "iron_ore"]
const OLD_WEAR := 0.75             # a leftover tool has spent this share of its durability
const TIMBER_SET := 6.0            # cave_bones kinds (protocol 142)
const TIMBER_POST := 7.0
const TIMBER_FALLEN := 8.0


# The tile's mines. data: a loaded TileTerrainData (heights, water); ore_list: the tile's ore_bodies list as baked; cave_mouths: Vector2 of every baked
# cave mouth; start: the start area's centre (Vector2(INF, INF) for none). Nearest the start first on a starter tile (Dave: one about 1 km from the
# spawn), else in the order of the bodies' id hashes.
static func plan(data, ore_list: Array, cave_mouths: Array, start: Vector2) -> Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%d/%d,%d/mines" % [int(data.flora_seed), data.tile.x, data.tile.y])
	var wanted: int = rng.randi_range(PER_TILE.x, PER_TILE.y)
	var size_m: float = float(data.samples - 1) * float(data.spacing_m)
	var inner: Rect2 = Rect2(data.x0 + EDGE_MARGIN_M, data.z0 + EDGE_MARGIN_M, size_m - 2.0 * EDGE_MARGIN_M, size_m - 2.0 * EDGE_MARGIN_M)
	var bodies: Array = []

	for ore in ore_list:
		if ORES.has(str(ore.get("resource", ""))) and SHAPES.has(str(ore.get("shape", ""))) and ore.has("center"):
			var c: Array = ore["center"]

			if inner.has_point(Vector2(float(c[0]), float(c[2]))):
				bodies.append(ore)

	var near_start: bool = inner.grow(EDGE_MARGIN_M).has_point(start)
	bodies.sort_custom(func(p, q):
		var cp: Vector2 = Vector2(float(p["center"][0]), float(p["center"][2]))
		var cq: Vector2 = Vector2(float(q["center"][0]), float(q["center"][2]))
		return cp.distance_to(start) < cq.distance_to(start) if near_start else absi(hash(str(p["id"]))) < absi(hash(str(q["id"]))))
	var mines: Array = []
	var targets: Array = []

	for ore in bodies:
		if mines.size() >= wanted:
			break

		var t: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][2]))

		if targets.any(func(o): return (o as Vector2).distance_to(t) < MIN_SPACING_M):
			continue

		var portal: Dictionary = find_portal(data, ore, inner, cave_mouths, start)

		if portal.is_empty():
			continue

		targets.append(t)
		mines.append(build(data, ore, portal, mines.size()))

	return mines


# The vertical span [low, high] of an ore body's top part, where an adit can meet it.
static func span(ore: Dictionary) -> Vector2:
	var c: Array = ore["center"]
	var thick: float = float(ore.get("thickness_m", 20.0))

	match str(ore.get("shape", "")):
		"lens":
			return Vector2(float(c[1]) - 0.5 * thick, float(c[1]) + 0.5 * thick)
		"halo":
			return Vector2(float(ore.get("top_y", c[1])) - thick, float(ore.get("top_y", c[1])))
		_:
			return Vector2(float(ore.get("bottom_y", float(c[1]) - thick)), float(ore.get("top_y", c[1])))


# Where to drive the adit for an ore body: {"mouth" Vector2, "dir" (unit, inward), "length" m, "floor" m at the mouth}, empty for nowhere. The mouth
# is on a dry hillside of the right slope whose ground rises toward the ore, at a level where the adit's 1 % climb meets the body, with rock over the
# roof all the way past the open cut, away from caves and the start area.
static func find_portal(data, ore: Dictionary, inner: Rect2, cave_mouths: Array, start: Vector2) -> Dictionary:
	var t: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][2]))
	var band: Vector2 = span(ore)
	var reach: float = float(ore.get("radius_a_m", ore.get("radius_m", 30.0)))
	var turn: float = float(absi(hash(str(ore["id"]))) % 1000) / 1000.0 * TAU

	for ring in RINGS_M:
		for k in DIRECTIONS:
			var out: Vector2 = Vector2.from_angle(turn + TAU * float(k) / float(DIRECTIONS))
			var mouth: Vector2 = t + out * float(ring)

			if not inner.has_point(mouth) or mouth.distance_to(start) < START_CLEAR_M:
				continue

			var h: float = data.height_at(mouth.x, mouth.y)

			if is_nan(h) or h < 2.0 or int(data.water_class[data.nearest(mouth.x, mouth.y)]) != 0:
				continue

			var inward: Vector2 = -out
			var rise: float = (data.height_at(mouth.x + inward.x * 4.0, mouth.y + inward.y * 4.0) - data.height_at(mouth.x - inward.x * 4.0, mouth.y - inward.y * 4.0)) / 8.0

			if rise < SLOPE.x or rise > SLOPE.y:
				continue

			var floor_y: float = h - 0.4
			var length: float = maxf(float(ring) - minf(0.4 * reach, float(ring) - 20.0), 20.0)
			var end_floor: float = floor_y + RISE * length

			if end_floor < band.x - 0.5 or end_floor + ADIT_H > band.y + 1.0:
				continue

			if cave_mouths.any(func(m): return (m as Vector2).distance_to(mouth) < CAVE_CLEAR_M):
				continue

			if _covered(data, mouth, inward, length, floor_y):
				return {"mouth": mouth, "dir": inward, "length": length, "floor": floor_y}

	return {}


# Rock over the roof (COVER_M) every 4 m from the open cut to the far end, and no water over it.
static func _covered(data, mouth: Vector2, inward: Vector2, length: float, floor_y: float) -> bool:
	var d: float = OPEN_CUT_M

	while d <= length:
		var p: Vector2 = mouth + inward * d
		var h: float = data.height_at(p.x, p.y)

		if is_nan(h) or h - (floor_y + RISE * d + ADIT_H) < COVER_M or int(data.water_class[data.nearest(p.x, p.y)]) != 0:
			return false

		d += 4.0

	return true


# One mine from its portal: the skeleton, its timbers and its extra scatter. index: its place in the tile's list (its id).
static func build(data, ore: Dictionary, portal: Dictionary, index: int) -> Dictionary:
	var id: String = "%d,%d#mine%d" % [data.tile.x, data.tile.y, index]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id + "/" + str(ore["id"]))
	var length: float = float(portal["length"])
	var size: String = "small" if length <= float(SIZES["small"]["max_len"]) else ("medium" if length <= float(SIZES["medium"]["max_len"]) else "large")
	var rule: Dictionary = SIZES[size]
	var mouth: Vector2 = portal["mouth"]
	var inward: Vector2 = portal["dir"]
	var side: Vector2 = Vector2(-inward.y, inward.x)
	var floor0: float = float(portal["floor"])
	var nodes: Array = []
	var segments: Array = []
	var chambers: Array = []
	var timbers: Array = []
	var extra: Array = []
	var mid: float = 0.5 * ADIT_H

	# The adit: a node 3 m out in the open, the mouth, then every 12 m or so, hand-cut so a little off the line.
	var outside: Vector2 = mouth - inward * 3.0
	nodes.append([outside.x, floor0 + mid, outside.y, ADIT_W, ADIT_H])
	var d: float = 0.0

	while true:
		var wobble: float = 0.0 if d < OPEN_CUT_M or d >= length else rng.randf_range(-0.6, 0.6)
		var at: Vector2 = mouth + inward * d + side * wobble
		nodes.append([at.x, floor0 + RISE * d + mid, at.y, ADIT_W, ADIT_H])
		segments.append([nodes.size() - 2, nodes.size() - 1, "passage"])

		if d >= length:
			break

		d = minf(d + rng.randf_range(10.0, 14.0), length)

	var end_node: int = nodes.size() - 1
	var end_floor: float = floor0 + RISE * length

	# Timber sets across the adit from the mouth in, every 2.7 m; the deepest one of a mine that has stood longest has fallen.
	var sets: int = int(float(rule["timbered"]) / SET_EVERY_M) + 1
	var yaw: float = atan2(inward.x, inward.y)

	for n in sets:
		var at: Vector2 = mouth + inward * (float(n) * SET_EVERY_M + 0.5)
		var fallen: bool = n == sets - 1 and rng.randf() < float(rule["fallen"])
		timbers.append([at.x, floor0 + RISE * (float(n) * SET_EVERY_M + 0.5), at.y, TIMBER_FALLEN if fallen else TIMBER_SET, yaw])

		if fallen:
			for k in 2:
				var stone_at: Vector2 = at + side * (0.35 if k == 0 else -0.3) + inward * (0.6 * float(k))
				extra.append([stone_at.x, floor0 + RISE * float(n) * SET_EVERY_M, stone_at.y, 1.0, rng.randf_range(0.3, 0.4)])

	# Drifts along the body (a lens or halo has a long axis; else a turn from the seed), with stopes where the ore was taken.
	var axis: Vector2 = Vector2.from_angle(float(ore.get("angle", rng.randf_range(0.0, TAU))))

	if absf(axis.dot(inward)) > 0.8:
		axis = side
	var drift_ends: Array = []

	for s in int(rule["sides"]):
		var way: Vector2 = axis if s == 0 else -axis
		var drift_len: float = rng.randf_range(float(rule["drift"][0]), float(rule["drift"][1]))
		var last: int = end_node
		var run: float = 0.0
		var base: Vector2 = Vector2(float(nodes[end_node][0]), float(nodes[end_node][2]))

		while run < drift_len:
			run = minf(run + 10.0, drift_len)
			var at: Vector2 = base + way * run + inward * rng.randf_range(-0.8, 0.8)
			nodes.append([at.x, end_floor + RISE * run + mid, at.y, ADIT_W, ADIT_H])
			segments.append([last, nodes.size() - 1, "passage"])
			last = nodes.size() - 1

		drift_ends.append(last)

	# Stopes: rooms off the drifts at floor level (their own node at the room's middle), propped by posts, a few ore pieces left on the floor.
	var drift_nodes: Array = range(end_node + 1, nodes.size())
	var stopes: int = mini(rng.randi_range(int(rule["stopes"][0]), int(rule["stopes"][1])), drift_nodes.size())
	var ore_item: int = LEFTOVERS.find(str(ORES[str(ore["resource"])]))

	for n in stopes:
		var host: Array = nodes[int(drift_nodes[(n * drift_nodes.size()) / maxi(stopes, 1)])]
		var radius: float = rng.randf_range(2.5, 4.0)
		var tall: float = rng.randf_range(3.2, 3.8)
		var floor_y: float = float(host[1]) - mid
		var centre: Vector2 = Vector2(float(host[0]), float(host[2])) + side.rotated(rng.randf_range(-0.5, 0.5)) * (radius * 0.5) * (1.0 if n % 2 == 0 else -1.0)
		nodes.append([centre.x, floor_y + 0.5 * tall, centre.y, 2.0 * radius, tall])
		chambers.append({"node": nodes.size() - 1, "radius_m": radius, "height_m": tall, "features": ["stope"]})

		for k in 2:
			var post: Vector2 = centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius * 0.55
			timbers.append([post.x, floor_y, post.y, TIMBER_POST, rng.randf_range(0.0, TAU)])

		for k in rng.randi_range(2, 4):
			var piece: Vector2 = centre + Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius * rng.randf_range(0.1, 0.5)
			extra.append([piece.x, floor_y, piece.y, 2.0, float(ore_item)])

	# Left behind: a worn pick, and maybe a bucket, a rope or a burnt-out lantern, in the deepest stope or at the adit's end.
	var left_at: Array = nodes[nodes.size() - 1] if stopes > 0 else nodes[end_node]
	var left_floor: float = float(left_at[1]) - 0.5 * float(left_at[4])
	extra.append([float(left_at[0]) + 0.6, left_floor, float(left_at[2]), 2.0, float(LEFTOVERS.find("copper_pickaxe" if rng.randf() < 0.3 else "stone_pickaxe"))])

	for item in ["bucket", "rope", "wooden_lantern_dark"]:
		if rng.randf() < 0.4:
			extra.append([float(left_at[0]) + rng.randf_range(-1.0, 1.0), left_floor, float(left_at[2]) + rng.randf_range(-1.0, 1.0), 2.0, float(LEFTOVERS.find(item))])

	# A large mine's air shaft from the end of its first drift up toward the surface, fallen in 3 m under it: a hollow on the hill marks it.
	if bool(rule["shaft"]) and not drift_ends.is_empty():
		var foot: Array = nodes[int(drift_ends[0])]
		var top_ground: float = data.height_at(float(foot[0]), float(foot[2]))

		if not is_nan(top_ground) and top_ground - float(foot[1]) > 8.0:
			nodes.append([float(foot[0]), top_ground - 3.0, float(foot[2]), 1.6, 1.6])
			segments.append([int(drift_ends[0]), nodes.size() - 1, "shaft"])
			nodes.append([float(foot[0]), top_ground + 0.2, float(foot[2]), 3.0, 1.4])
			chambers.append({"node": nodes.size() - 1, "radius_m": 1.8, "height_m": 1.4, "features": ["shaft_hollow"]})

	# The spoil heap: broken rock fanned out downhill of the mouth, boulders and loose stones on the ground.
	var heap: Vector2 = mouth - inward * 6.0

	for k in 30:
		var at: Vector2 = heap + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 6.0 * sqrt(rng.randf()) * Vector2(1.0, 0.7).rotated(atan2(inward.y, inward.x))
		var ground: float = data.height_at(at.x, at.y)

		if is_nan(ground) or int(data.water_class[data.nearest(at.x, at.y)]) != 0:
			continue

		var boulder: bool = k % 4 == 0
		extra.append([at.x, ground, at.y, 1.0 if boulder else 0.0, rng.randf_range(0.3, 0.6) if boulder else 0.0])

	return {"id": id, "cave_kind": "mine", "size": size, "ore": str(ore["id"]), "resource": str(ore["resource"]), "nodes": nodes, "segments": segments,
		"chambers": chambers, "entrances": [0], "dens": [], "timbers": timbers, "extra": extra}
