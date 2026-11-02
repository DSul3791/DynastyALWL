extends RefCounted

# Gathering at the sea's edge, the rules both sides share (Sonny, 31 Oct 2026; the server half is Tyler's ACT_GATHER_EDGE in server_items.gd, data/items/shore_nodes.json).
# node_at is the tide-line node of a cell on a game day (the same on the server and in the client's prompt); prompt says what E would do right now, or "" when nothing can be gathered, so the
# client shows no prompt that the server would refuse. The client cannot know that a node was used up by someone else today: it knows only its own gathers (`used`).


# The node of the 8 m cell holding `pos` on a game day: {} when none, else the row of cfg["nodes"].
static func node_at(cfg: Dictionary, pos: Vector3, day: int, hour: float, season: String) -> Dictionary:
	var cell_m: float = float(cfg.get("cell_m", 8.0))
	var cell: Vector2i = Vector2i(int(floor(pos.x / cell_m)), int(floor(pos.z / cell_m)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cell.x, cell.y, day)) ^ 0x51ed270b

	if rng.randf() >= float(cfg.get("node_chance", 0.5)):   # luck-exempt: seeded world layout
		return {}

	var usable: Array = []
	var total: float = 0.0

	for node in cfg.get("nodes", []):
		var hours: Array = node.get("only_hours", [])

		if hours.size() == 2:
			var inside: bool = (hour >= float(hours[0]) and hour < float(hours[1])) if float(hours[0]) < float(hours[1]) else (hour >= float(hours[0]) or hour < float(hours[1]))

			if not inside:
				continue

		var seasons: Array = node.get("only_seasons", [])

		if not seasons.is_empty() and not seasons.has(season):
			continue

		usable.append(node)
		total += float(node.get("weight", 1))

	if usable.is_empty():
		return {}

	var pick: float = rng.randf() * total   # luck-exempt: seeded world layout

	for node in usable:
		pick -= float(node.get("weight", 1))

		if pick <= 0.0:
			return node

	return usable[usable.size() - 1]


# The key of the cell holding pos (the server's `_shore_taken` key).
static func cell_key(cfg: Dictionary, pos: Vector3) -> String:
	var cell_m: float = float(cfg.get("cell_m", 8.0))
	return "%d,%d" % [int(floor(pos.x / cell_m)), int(floor(pos.z / cell_m))]


# What E does at the water's edge for a player at `pos`: the prompt text, or "" for nothing.
#   sea_near: the sea within reach_m of the player;  container: id of the bucket, clay jug or waterskin in the pack ("" for none)
#   ground_m: the ground height under the player;  used: {cell key -> game day} of the nodes this client already gathered
static func prompt(cfg: Dictionary, pos: Vector3, sea_near: bool, container: String, ground_m: float, day: int, hour: float, season: String, used: Dictionary) -> String:
	if not sea_near:
		return ""

	if container != "":
		return "Press E to fill the %s" % container.replace("_", " ")

	if ground_m > float(cfg.get("beach_max_height_m", 4.0)):
		return ""

	var node: Dictionary = node_at(cfg, pos, day, hour, season)

	if node.is_empty() or int(used.get(cell_key(cfg, pos), -1)) == day:
		return ""

	return "Press E to gather %s" % str(node.get("item", "")).replace("_", " ")
