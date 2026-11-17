extends RefCounted

# Edda and Hob's camp (Dave 17 Nov 2026: "move EDDA and Hob under the nearest big tree and give them a large campfire that players cannot access and
# its just inside the shelter line of the tree so the rain doesnt effect it"; he picked the tree and the layout). data/npcs/camp.json holds the
# tree, the fire and how far round the tree nothing may be put down; data/npcs/markers.json holds the two NPC spots (rows with "npc").
# Client and server read the same file, so the ghost is red exactly where the server refuses. tools/npc_camp_spot.gd measures the tree.

const PATH := "res://data/npcs/camp.json"
const TREE_MATCH_M := 0.5   # a standing tree whose foot is this near the camp tree's is the camp tree

static var _cfg: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"tree": {}}

	return _cfg


static func tree_spot() -> Vector2:
	var tree: Dictionary = cfg().get("tree", {})
	return Vector2(float(tree["x"]), float(tree["z"])) if tree.has("x") else Vector2(INF, INF)


# Where the camp fire burns (x, z; the ground gives y), Vector2(INF, INF) with no camp.
static func fire_spot() -> Vector2:
	var fire: Dictionary = cfg().get("fire", {})
	return Vector2(float(fire["x"]), float(fire["z"])) if fire.has("x") else Vector2(INF, INF)


# The wood class the camp fire burns as (cooking.json fire_tiers: "log" is the large fire).
static func fire_wood() -> String:
	return str(cfg().get("fire", {}).get("wood", "log"))


# True for the camp tree: no axe, dig or road may bring it down.
static func is_camp_tree(foot: Vector3) -> bool:
	return Vector2(foot.x, foot.z).distance_to(tree_spot()) <= TREE_MATCH_M


# True when nothing may be put down here (a building piece, station, fire or torch): within keep_m of the camp tree.
static func within_keep(spot: Vector3) -> bool:
	return Vector2(spot.x, spot.z).distance_to(tree_spot()) <= float(cfg().get("keep_m", 0.0))
