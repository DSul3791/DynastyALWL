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


# Dave's count rule, once: the table count scaled by the plant's size against an average one of its species (patch scale 1 to 3 from drops.json
# "yield_scale", never below the table number, never above 3x), rounded up, never 0. Berries and every other harvest plant call this.
static func harvest_scale(drops: Dictionary, plant_height: float, flora_entry: Dictionary) -> float:
	var limits: Dictionary = drops.get("yield_scale", {})
	var low: float = float(limits.get("min", 1.0))
	var high: float = float(limits.get("max", 3.0))

	if plant_height <= 0.0 or not flora_entry.has("height_m"):
		return low

	var range_m: Array = flora_entry["height_m"]
	return clampf(plant_height / maxf((float(range_m[0]) + float(range_m[1])) * 0.5, 0.01), low, high)


static func harvest_count(row: Dictionary, scale: float) -> int:
	return maxi(1, int(ceil(float(row.get("count", 1)) * scale - 0.0001)))


# Can this plant be picked now? {"ok": bool, "reason": String}. `flora_row` is the flora table row,
# `has_tool` a Callable(tool class) -> bool, `item_exists` a Callable(item id) -> bool.
# True when the plant's flora.json "season" list allows the season now (an empty list or "all" always does).
static func in_season(flora_row: Dictionary, season: String) -> bool:
	var seasons: Array = flora_row.get("season", [])
	return seasons.is_empty() or seasons.has("all") or season == "" or seasons.has(season)


# Out of season, a herb, flower or mushroom is not drawn at all (FloraView) and offers nothing; woody plants and berry bushes stay drawn but offer nothing either.
# Plants of the shapes below stay drawn all year (ground cover that is not a seasonal product).
const ALWAYS_DRAWN_SHAPES := ["grass", "fern", "reed"]


static func hidden_out_of_season(flora_row: Dictionary, season: String, berry_bush: bool) -> bool:
	if str(flora_row.get("kind", "")) != "plant" or berry_bush or ALWAYS_DRAWN_SHAPES.has(str(flora_row.get("shape", ""))):
		return false

	return not in_season(flora_row, season)


static func check(flora_row: Dictionary, kind: String, drops: Dictionary, season: String, has_tool: Callable, item_exists: Callable) -> Dictionary:
	var name: String = str(flora_row.get("name", ""))
	var rows: Array = drops.get("by_species", {}).get(name, drops.get("by_kind", {}).get(kind, []))

	# A harvest plant (drops.json "berry_yield" or "harvest_yield"): E picks its product, in the plant's season only.
	if not harvest_row(drops, name).is_empty():
		var berry_seasons: Array = flora_row.get("season", [])
		return {"ok": true, "reason": ""} if berry_seasons.is_empty() or berry_seasons.has("all") or berry_seasons.has(season) else {"ok": false, "reason": "not in season"}

	if not rows.is_empty():
		return {"ok": true, "reason": ""} if in_season(flora_row, season) else {"ok": false, "reason": "not in season"}

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
