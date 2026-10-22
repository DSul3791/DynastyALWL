extends RefCounted

# What picking a plant by hand gives and needs (data/items/drops.json). Shared so the client's
# "Press E to harvest" prompt says the same thing the server will do.


# The tool class a natural yield needs ("" = by hand), from drops.json tool_rules.
static func tool_for(item_id: String, drops: Dictionary) -> String:
	var suffixes: Dictionary = drops.get("tool_rules", {}).get("suffixes", {})

	for tool_class in suffixes:
		for suffix in suffixes[tool_class]:
			if item_id.ends_with(str(suffix)):
				return str(tool_class)

	return ""


static func tool_name(tool_class: String, drops: Dictionary) -> String:
	return str(drops.get("tool_rules", {}).get("tool_names", {}).get(tool_class, tool_class))


# Can this plant be picked now? {"ok": bool, "reason": String}. `flora_row` is the flora table row,
# `has_tool` a Callable(tool class) -> bool, `item_exists` a Callable(item id) -> bool.
static func check(flora_row: Dictionary, kind: String, drops: Dictionary, season: String, has_tool: Callable, item_exists: Callable) -> Dictionary:
	var name: String = str(flora_row.get("name", ""))
	var rows: Array = drops.get("by_species", {}).get(name, drops.get("by_kind", {}).get(kind, []))

	if not rows.is_empty():
		return {"ok": true, "reason": ""}

	var yields: Array = flora_row.get("yields", [])
	var seasons: Array = flora_row.get("season", [])

	if yields.is_empty():
		return {"ok": false, "reason": "nothing to pick"}

	if not (seasons.has("all") or seasons.has(season)):
		return {"ok": false, "reason": "nothing to pick this season"}

	var missing: String = ""

	for candidate in yields:
		if not item_exists.call(str(candidate)):
			continue

		var needed: String = tool_for(str(candidate), drops)

		if needed == "" or has_tool.call(needed):
			return {"ok": true, "reason": ""}

		missing = needed

	if missing != "":
		return {"ok": false, "reason": "needs %s" % tool_name(missing, drops)}

	return {"ok": false, "reason": "nothing to pick"}
