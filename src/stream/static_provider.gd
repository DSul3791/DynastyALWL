extends "res://src/stream/dialogue_provider.gd"

# Answers from data/npcs/dialogue/<npc>.json: barks and trees of nodes {text, choices, effects, end} with conditions on the
# player's flags with this NPC, the hour and the pack. No randomness except picking one of several texts, never one shown within
# the last five (ctx.recent). Everything it returns is data the server then applies.

const VOICE_RECENT := 5

var trees: Dictionary = {}    # npc id -> parsed file
var role_pools: Dictionary = {}   # role -> bark kind -> lines
var roles: Dictionary = {}        # npc id -> role


func load_dir(path: String = "res://data/npcs/dialogue") -> void:
	trees.clear()
	load_roles()

	for file in DirAccess.get_files_at(path):
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + "/" + file))

			if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("npc", "")) != "":
				trees[str(parsed["npc"])] = parsed


# Role pools (data/npcs/role_barks.json) and each NPC's role (data/npcs/npcs.json) for the barks a dialogue file does not have.
func load_roles() -> void:
	var pools: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/role_barks.json"))
	role_pools = pools.get("roles", {}) if typeof(pools) == TYPE_DICTIONARY else {}
	var npc_cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/npcs.json"))
	roles.clear()

	if typeof(npc_cfg) == TYPE_DICTIONARY:
		for npc in npc_cfg.get("npcs", []):
			roles[str(npc.get("id", ""))] = str(npc.get("role", ""))


func has_npc(npc_id: String) -> bool:
	return trees.has(npc_id)


func test(cond: Dictionary, ctx: Dictionary) -> bool:
	var flags: Dictionary = ctx.get("flags", {})

	for key in cond:
		var want: Variant = cond[key]

		if key == "flag":
			for f in (want if typeof(want) == TYPE_ARRAY else [want]):
				if not flags.has(str(f)):
					return false
		elif key == "flag_not":
			for f in (want if typeof(want) == TYPE_ARRAY else [want]):
				if flags.has(str(f)):
					return false
		elif key == "hour_between":
			var h: float = float(ctx.get("hour", 12.0))
			var a: float = float(want[0])
			var b: float = float(want[1])

			if not ((h >= a and h < b) if a <= b else (h >= a or h < b)):
				return false
		elif key == "has_item":
			var has: Callable = ctx.get("has_item", Callable())

			if not has.is_valid() or not bool(has.call(str(want[0]), int(want[1]))):
				return false
		elif key == "min_rep":
			if int(ctx.get("rep", 0)) < int(want):
				return false
		elif key == "rank":
			var reached: Callable = ctx.get("rank_reached", Callable())

			if not reached.is_valid() or not bool(reached.call(str(want))):
				return false
		elif key == "can_train":
			var can: Callable = ctx.get("can_train", Callable())

			if not can.is_valid() or not bool(can.call(str(want[0]), int(want[1]), str(want[2]) if want.size() > 3 else "", int(want[3]) if want.size() > 3 else 0)):
				return false
		else:
			return false   # an unknown condition never holds (the validator rejects it)

	return true


func _pick(options: Array, ctx: Dictionary) -> String:
	var recent: Array = ctx.get("recent", [])
	var fresh: Array = []

	for o in options:
		if not recent.has(hash(str(o))):
			fresh.append(str(o))

	var pool: Array = fresh if not fresh.is_empty() else options
	var text: String = str(pool[randi() % pool.size()])   # luck-exempt: which wording of a line, no outcome
	recent.append(hash(text))

	while recent.size() > VOICE_RECENT:
		recent.pop_front()

	ctx["recent"] = recent
	return text


func bark(npc_id: String, kind: String, ctx: Dictionary) -> String:
	# A rank-specific bark (greeting_friend) is preferred once the player has earned the rank.
	var ranked: Array = trees.get(npc_id, {}).get("barks", {}).get("%s_%s" % [kind, str(ctx.get("rank", "")).to_lower()], [])
	var options: Array = ranked if not ranked.is_empty() else trees.get(npc_id, {}).get("barks", {}).get(kind, [])

	if options.is_empty():
		options = role_pools.get(str(roles.get(npc_id, "")), {}).get(kind, [])

	if options.is_empty():
		options = role_pools.get("default", {}).get(kind, [])

	return _pick(options, ctx) if not options.is_empty() else ""


func _line(npc_id: String, node_id: String, ctx: Dictionary) -> Dictionary:
	var tree: Dictionary = trees.get(npc_id, {})
	var node: Dictionary = tree.get("nodes", {}).get(node_id, {})

	if node.is_empty():
		return {}

	var raw: Variant = node.get("text", "")
	var text: String = ""

	if typeof(raw) == TYPE_ARRAY:
		text = _pick(raw, ctx)
	elif str(raw).begins_with("$"):
		text = bark(npc_id, str(raw).substr(1), ctx)
	else:
		text = str(raw)

	var choices: Array = []
	var map: Array = []

	for c in node.get("choices", []):
		if c.has("if") and not test(c["if"], ctx):
			continue

		choices.append(str(c.get("text", "")))
		map.append(str(c.get("goto", "end")))

	var ends: bool = bool(node.get("end", false)) or choices.is_empty()
	return {"text": text, "source": "static", "voice_id": str(tree.get("voice", npc_id)), "choices": choices, "map": map, "node": node_id, "end": ends, "effects": node.get("effects", [])}


func open(npc_id: String, ctx: Dictionary) -> Dictionary:
	var tree: Dictionary = trees.get(npc_id, {})

	for root in tree.get("roots", []):
		if not root.has("if") or test(root["if"], ctx):
			return _line(npc_id, str(root["node"]), ctx)

	return {}


func choose(npc_id: String, _node: String, choice: int, map: Array, ctx: Dictionary) -> Dictionary:
	if choice < 0 or choice >= map.size() or str(map[choice]) == "end":
		return {}

	return _line(npc_id, str(map[choice]), ctx)
