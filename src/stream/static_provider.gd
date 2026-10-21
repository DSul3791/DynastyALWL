extends "res://src/stream/dialogue_provider.gd"

# Answers from data/npcs/dialogue/<npc>.json: barks and trees of nodes {text, choices, effects, end} with conditions on the
# player's flags with this NPC, the hour and the pack. No randomness except picking one of several texts, never one shown within
# the last five (ctx.recent). Everything it returns is data the server then applies.

const VOICE_RECENT := 5

var trees: Dictionary = {}    # npc id -> parsed file


func load_dir(path: String = "res://data/npcs/dialogue") -> void:
	trees.clear()

	for file in DirAccess.get_files_at(path):
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + "/" + file))

			if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("npc", "")) != "":
				trees[str(parsed["npc"])] = parsed


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
	var text: String = str(pool[randi() % pool.size()])
	recent.append(hash(text))

	while recent.size() > VOICE_RECENT:
		recent.pop_front()

	ctx["recent"] = recent
	return text


func bark(npc_id: String, kind: String, ctx: Dictionary) -> String:
	var options: Array = trees.get(npc_id, {}).get("barks", {}).get(kind, [])
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
