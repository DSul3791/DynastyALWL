extends RefCounted

# The Smithies' own state (master s2.7 items 5-8, CATALOG_IMPLEMENTATION_PLAN R3/R5; GOALS-REPAIR WP-METAL): server_items.gd calls in here.
# Use wear: every craft finished at a smithy (a structures.json row with "anvil") adds smithing.json station_wear.per_craft to the station's
# wear; iron or steel worked on a bronze anvil (the Improved smithy) adds iron_on_bronze times that (master s2.7 item 5: "iron accelerates
# anvil/station wear"). Station durability and "Needs repair" (R5) read this wear; until then it only counts.
# struct["use_wear"] = the wear so far; saved in smithies.json by the station's uid.

const SmithingRules := preload("res://src/shared/smithing_rules.gd")

var host = null   # the items module (server_items.gd)


func is_smithy(def: Dictionary) -> bool:
	return str(def.get("anvil", "")) != ""


# A craft finished at station `id` (the station whose store took the product).
func crafted(id: int, recipe: Dictionary) -> void:
	var it: Dictionary = host._items.get(id, {})
	var def: Dictionary = host._structures.get(str(it.get("struct", {}).get("kind", "")), {}) if it.has("struct") else {}

	if not is_smithy(def):
		return

	var cfg: Dictionary = SmithingRules.cfg().get("station_wear", {})
	var add: float = float(cfg.get("per_craft", 1.0))

	if str(def["anvil"]) == "bronze" and _works_iron(recipe):
		add *= float(cfg.get("iron_on_bronze", 1.0))

	it["struct"]["use_wear"] = float(it["struct"].get("use_wear", 0.0)) + add
	host._dirty = true


func wear_of(id: int) -> float:
	return float(host._items.get(id, {}).get("struct", {}).get("use_wear", 0.0))


# Iron or steel worked: an iron or steel ingot among the needs, or a product of iron or steel.
func _works_iron(recipe: Dictionary) -> bool:
	var metals: Array = SmithingRules.cfg().get("station_wear", {}).get("hard_metals", ["iron", "steel"])

	for need in recipe.get("needs", []):
		if metals.has(host.table.id_of(int(need[0])).trim_suffix("_ingot")):
			return true

	var made: Dictionary = host.table.entry(host.table.id_of(int(recipe.get("gives", [0, 0])[0])))
	return metals.has(str(made.get("material", "")))


func save_rows() -> Dictionary:
	var rows: Dictionary = {}

	for id in host._items:
		var it: Dictionary = host._items[id]

		if it.has("struct") and it["struct"].has("uid") and float(it["struct"].get("use_wear", 0.0)) > 0.0:
			rows[str(it["struct"]["uid"])] = float(it["struct"]["use_wear"])

	return rows


func load_rows(parsed: Variant) -> void:
	var rows: Dictionary = parsed.get("smithies", {}) if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("smithies", null)) == TYPE_DICTIONARY else {}

	if rows.is_empty():
		return

	for id in host._items:
		var it: Dictionary = host._items[id]

		if it.has("struct") and it["struct"].has("uid") and rows.has(str(it["struct"]["uid"])) and is_smithy(host._structures.get(str(it["struct"]["kind"]), {})):
			it["struct"]["use_wear"] = maxf(float(rows[str(it["struct"]["uid"])]), 0.0)
