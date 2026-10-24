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


# The harvest row of a species: {"item", "count"} from drops.json "berry_yield" (berries) or "harvest_yield" (herbs, flowers, roots, mushrooms, other fruit);
# {} when it has none. One field for both: E gives that product only, once a season, and the plant stays standing and bare until the season changes.
static func harvest_row(drops: Dictionary, species_name: String) -> Dictionary:
	var berry: Dictionary = (drops.get("berry_yield", {}) as Dictionary).get(species_name, {})

	if not berry.is_empty():
		return berry

	return (drops.get("harvest_yield", {}) as Dictionary).get(species_name, {})


# Can this plant be picked now? {"ok": bool, "reason": String}. `flora_row` is the flora table row,
# `has_tool` a Callable(tool class) -> bool, `item_exists` a Callable(item id) -> bool.
static func check(flora_row: Dictionary, kind: String, drops: Dictionary, season: String, has_tool: Callable, item_exists: Callable) -> Dictionary:
	var name: String = str(flora_row.get("name", ""))
	var rows: Array = drops.get("by_species", {}).get(name, drops.get("by_kind", {}).get(kind, []))

	# A harvest plant (drops.json "berry_yield" or "harvest_yield"): E picks its product, in the plant's season only.
	if not harvest_row(drops, name).is_empty():
		var berry_seasons: Array = flora_row.get("season", [])
		return {"ok": true, "reason": ""} if berry_seasons.is_empty() or berry_seasons.has("all") or berry_seasons.has(season) else {"ok": false, "reason": "not in season"}

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
