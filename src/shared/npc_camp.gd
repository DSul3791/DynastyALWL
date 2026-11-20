extends RefCounted

# Edda and Hob's camp (Dave 17 Nov 2026: "move EDDA and Hob under the nearest big tree and give them a large campfire that players cannot access and
# its just inside the shelter line of the tree so the rain doesnt effect it"; he picked the tree and the layout). data/npcs/camp.json holds the
# tree, the fire and how far round the tree nothing may be put down; data/npcs/markers.json holds the two NPC spots (rows with "npc").
# Client and server read the same file, so the ghost is red exactly where the server refuses. tools/npc_camp_spot.gd measures the tree.

const PATH := "res://data/npcs/camp.json"
const TRIBES_PATH := "res://data/creatures/goblin_tribes.json"   # the goblin tribes' camps: their fires are camp fires too (Dave 19 Nov 2026)
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


# True when nothing is put down here (a building piece, station, fire or torch): within keep_m of the camp tree, or of a goblin tribe's camp fire.
static func within_keep(spot: Vector3) -> bool:
	return keep_reason(spot) != ""


# Why nothing is put down here (PlacementRules.reason_text): "camp" round Edda and Hob's camp tree, "tribe_camp" round a goblin tribe's camp fire, "" when free.
static func keep_reason(spot: Vector3) -> String:
	if Vector2(spot.x, spot.z).distance_to(tree_spot()) <= float(cfg().get("keep_m", 0.0)):
		return "camp"

	for camp in tribe_camps():
		var fire: Dictionary = camp["fire"]

		if Vector2(spot.x, spot.z).distance_to(Vector2(float(fire["x"]), float(fire["z"]))) <= float(camp.get("keep_m", 0.0)):
			return "tribe_camp"

		for prop in camp.get("props", []):   # the camp's chest, racks and benches keep their own ground clear too (camp life stage A, Dave 20 Nov 2026)
			if Vector2(spot.x, spot.z).distance_to(Vector2(float(prop["x"]), float(prop["z"]))) <= float(camp.get("prop_keep_m", 0.0)):
				return "tribe_camp"

	return ""


# The goblin tribes' camps that have a fire (data/creatures/goblin_tribes.json "camp" rows, Dave 19 Nov 2026), read once.
static var _tribe_camps: Array = []
static var _tribe_read: bool = false


static func tribe_camps() -> Array:
	if not _tribe_read:
		_tribe_read = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRIBES_PATH)) if FileAccess.file_exists(TRIBES_PATH) else null
		var rows: Dictionary = parsed.get("tribes", {}) if typeof(parsed) == TYPE_DICTIONARY else {}

		for tribe in rows:
			var camp: Dictionary = (rows[tribe] as Dictionary).get("camp", {})

			if (camp.get("fire", {}) as Dictionary).has("x"):
				var row: Dictionary = camp.duplicate()
				row["tribe"] = str(tribe)
				_tribe_camps.append(row)

	return _tribe_camps


# Every camp fire the server keeps lit, in a steady order (Edda and Hob's first): [{"x", "z", "wood", "owner"}], owner as in "<owner> fire".
static func fires() -> Array:
	var out: Array = []

	if fire_spot().x != INF:
		out.append({"x": fire_spot().x, "z": fire_spot().y, "wood": fire_wood(), "owner": "Edda and Hob's"})

	for camp in tribe_camps():
		var fire: Dictionary = camp["fire"]
		out.append({"x": float(fire["x"]), "z": float(fire["z"]), "wood": str(fire.get("wood", "log")), "owner": str(camp.get("fire_owner", "the goblins'"))})

	return out


# Whose camp fire stands nearest a point ("Edda and Hob's", "the Ragtooth goblins'"): for the line that refuses it and the name the client shows.
static func owner_near(at: Vector3) -> String:
	var best: String = "Edda and Hob's"
	var best_d: float = INF

	for fire in fires():
		var d: float = Vector2(at.x, at.z).distance_to(Vector2(float(fire["x"]), float(fire["z"])))

		if d < best_d:
			best_d = d
			best = str(fire["owner"])

	return best


# Every piece a goblin tribe's camp has round its fire (goblin_tribes.json camp "props": Dave 20 Nov 2026, "a small chest of some sort, probably a
# few drying racks or tanning racks ... maybe some wooden benches around the fire"), in a steady order: [{"tribe", "kind", "x", "z", "yaw"}].
# The server lays them as transient pieces of that tribe (server_items.gd _tribe_props_tick); nobody takes, opens, uses or repairs them.
static func props() -> Array:
	var out: Array = []

	for camp in tribe_camps():
		for prop in camp.get("props", []):
			out.append({"tribe": str(camp["tribe"]), "kind": str(prop["kind"]), "x": float(prop["x"]), "z": float(prop["z"]), "yaw": float(prop.get("yaw", 0.0))})

	return out


# A tribe's camp by name ("the Ragtooth camp"), for the line that turns a player away from its pieces.
static func camp_name_of(tribe: String) -> String:
	for camp in tribe_camps():
		if str(camp["tribe"]) == tribe:
			return str(camp.get("name", "the goblins' camp"))

	return "the goblins' camp"
