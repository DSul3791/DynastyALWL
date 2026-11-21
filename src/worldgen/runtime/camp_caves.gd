extends RefCounted
# A goblin camp's own cave (Dave 21 Nov 2026: "couldn't we just make a new cave for the goblin camp like it would be part of the goblin camp only
# place it that way we can make it a lot closer or put it anywhere we want to"; "It could be a dry cave with no water source shallow, and it would
# just have to be placed anywhere near a river"). A camp whose data has a "dig" row (data/creatures/goblin_tribes.json) brings its cave: a short
# dry passage driven into the hillside from the camp's mouth, a room at its end where the tribe lives. Worked out from the camp row and the tile's
# heights when the tile loads, never baked, like the abandoned mines (mine_sites.gd), and handed back in the baked caves' skeleton form (nodes
# [x, y, z, width, height] with y the passage middle, segments, chambers, entrances), so TileTerrainData._load_caves carves it, scatters stones on its
# floor, counts it for shelter and cave air and keeps flora out of its mouth like any cave. cave_kind "camp_cave": no spring, no stream, never a
# wild goblin band or an animal den (GOBLIN_DEN_CAVES leaves it out).
#
# The shape: from 3 m outside the mouth, an open cut into the hill until the ground stands COVER_M over the roof (as a mine's adit), then the
# passage in a straight line, rising 1 in 100 so it drains out of the mouth, to depth_m from the mouth, and a round room past its end.

const COVER_M := 2.0           # rock over the roof where the open cut ends (mine_sites.gd COVER_M)
const OPEN_CUT_MIN_M := 4.0
const OPEN_CUT_MAX_M := 20.0
const RISE := 0.01             # 1 m up per 100 m in, so it drains out of the mouth
const STEP_M := 6.0            # a node every this far along the passage
const DEFAULT := {"dir_deg": 0.0, "depth_m": 20.0, "width_m": 2.2, "height_m": 2.4, "room_radius_m": 4.0, "room_height_m": 3.0}
const EDGE_MARGIN_M := 60.0    # the whole cave inside its tile (a neighbour tile does not carve it)
const PATH := "res://data/creatures/goblin_tribes.json"


# The camp caves on one tile: tile its coordinate, x0 / z0 its corner, size_m its side, height a Callable (x, z) -> ground height (NAN off the tile).
static func plan(tile: Vector2i, x0: float, z0: float, size_m: float, height: Callable) -> Array:
	var out: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null

	if not parsed is Dictionary:
		return out

	var rect: Rect2 = Rect2(x0 + EDGE_MARGIN_M, z0 + EDGE_MARGIN_M, size_m - 2.0 * EDGE_MARGIN_M, size_m - 2.0 * EDGE_MARGIN_M)
	var tribes: Dictionary = parsed.get("tribes", {})
	var ids: Array = tribes.keys()
	ids.sort()   # the same order everywhere

	for tribe_id in ids:
		var camp: Dictionary = (tribes[tribe_id] as Dictionary).get("camp", {}) if tribes[tribe_id] is Dictionary else {}

		if not camp.has("dig") or not camp.has("mouth"):
			continue

		var mouth: Vector2 = Vector2(float(camp["mouth"]["x"]), float(camp["mouth"]["z"]))

		if rect.has_point(mouth):
			var cave: Dictionary = build(tile, str(tribe_id), mouth, camp["dig"], height)

			if not cave.is_empty():
				out.append(cave)

	return out


# The cave's id on its tile, as goblin_tribes.json camp.cave names it.
static func cave_id(tile: Vector2i, tribe_id: String) -> String:
	return "%d,%d#camp_%s" % [tile.x, tile.y, tribe_id]


# One camp's cave from its mouth (world x, z) and its dig row. Empty when the ground at the mouth is not there.
static func build(tile: Vector2i, tribe_id: String, mouth: Vector2, dig: Dictionary, height: Callable) -> Dictionary:
	var row: Dictionary = DEFAULT.duplicate()
	row.merge(dig, true)
	var ground: float = float(height.call(mouth.x, mouth.y))

	if is_nan(ground):
		return {}

	var inward: Vector2 = Vector2.from_angle(deg_to_rad(float(row["dir_deg"])))   # x east, z south: 0 east, 90 south
	var width: float = float(row["width_m"])
	var tall: float = float(row["height_m"])
	var depth: float = float(row["depth_m"])
	var floor0: float = ground - 0.4
	var mid: float = 0.5 * tall
	var cut: float = OPEN_CUT_MAX_M

	for k in range(int(OPEN_CUT_MIN_M), int(OPEN_CUT_MAX_M) + 1):   # where the hill first stands COVER_M over the roof
		var p: Vector2 = mouth + inward * float(k)
		var h: float = float(height.call(p.x, p.y))

		if not is_nan(h) and h - (floor0 + RISE * float(k) + tall) >= COVER_M:
			cut = float(k)
			break

	cut = minf(cut, depth)
	var nodes: Array = []
	var segments: Array = []
	var outside: Vector2 = mouth - inward * 3.0
	nodes.append([outside.x, floor0 - RISE * 3.0 + mid, outside.y, width, tall])
	var d: float = cut   # the open cut is one straight piece from outside, so flora and stones are cleared all along it (cave_openings)

	while true:
		var at: Vector2 = mouth + inward * d
		nodes.append([at.x, floor0 + RISE * d + mid, at.y, width, tall])
		segments.append([nodes.size() - 2, nodes.size() - 1, "passage"])

		if d >= depth:
			break

		d = minf(d + STEP_M, depth)

	var radius: float = float(row["room_radius_m"])
	var room_tall: float = maxf(float(row["room_height_m"]), tall)
	var room_floor: float = floor0 + RISE * depth
	var centre: Vector2 = mouth + inward * (depth + 0.6 * radius)
	nodes.append([centre.x, room_floor + 0.5 * room_tall, centre.y, 2.0 * radius, room_tall])
	segments.append([nodes.size() - 2, nodes.size() - 1, "passage"])
	var chambers: Array = [{"node": nodes.size() - 1, "radius_m": radius, "height_m": room_tall, "features": ["camp_room"]}]

	return {"id": cave_id(tile, tribe_id), "cave_kind": "camp_cave", "size": "small", "tribe": tribe_id, "nodes": nodes, "segments": segments,
		"chambers": chambers, "entrances": [0], "dens": [], "cut_m": cut, "mouth": [mouth.x, floor0, mouth.y]}
