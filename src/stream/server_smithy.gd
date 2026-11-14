extends RefCounted

# The Smithies' own state (master s2.7 items 5-8, CATALOG_IMPLEMENTATION_PLAN R3/R5; GOALS-REPAIR WP-METAL): server_items.gd calls in here.
# Use wear: every craft finished at a smithy (a structures.json row with "anvil") adds smithing.json station_wear.per_craft to the station's
# wear; iron or steel worked on a bronze anvil (the Improved smithy) adds iron_on_bronze times that (master s2.7 item 5: "iron accelerates
# anvil/station wear"). At station_wear.durability (by the smithy's anvil; R5, master s2.2 item 9) it is broken: it stays placed, and crafting
# at it, opening its store and taking it down say exactly "Needs repair" (server_items.gd). A hammer on Repair mends it (server_items.gd
# _repair_struct, repair_needs here): use wear back to 0, station, store, add-ons and fire state untouched.
# struct["use_wear"] = the wear so far, never above the durability; saved in smithies.json by the station's uid.
# shortcut: use_wear is not sent to clients, so a recipe card beside a worn-out smithy still looks craftable; the server refuses the craft
# with "Needs repair" (server_items.gd _queue_craft / _broken_station_near), which is the guard. Send a broken flag on the station row if
# players find the card misleading.

const SmithingRules := preload("res://src/shared/smithing_rules.gd")

var host = null   # the items module (server_items.gd)


func is_smithy(def: Dictionary) -> bool:
	return str(def.get("anvil", "")) != ""


# A craft finished at station `id` (the station whose store took the product) by `peer` (told when it wears out; 0 for nobody).
func crafted(id: int, recipe: Dictionary, peer: int = 0) -> void:
	var it: Dictionary = host._items.get(id, {})
	var def: Dictionary = host._structures.get(str(it.get("struct", {}).get("kind", "")), {}) if it.has("struct") else {}

	if not is_smithy(def):
		return

	var cfg: Dictionary = SmithingRules.cfg().get("station_wear", {})
	var add: float = float(cfg.get("per_craft", 1.0))

	if str(def["anvil"]) == "bronze" and _works_iron(recipe):
		add *= float(cfg.get("iron_on_bronze", 1.0))

	var most: float = durability(def)
	var was: float = float(it["struct"].get("use_wear", 0.0))
	it["struct"]["use_wear"] = minf(was + add, most) if most > 0.0 else was + add
	host._dirty = true

	if most > 0.0 and was < most and float(it["struct"]["use_wear"]) >= most and peer > 0:
		host._say(peer, "The %s is worn out. Needs repair: take a hammer on Repair to it." % str(host.table.entry(str(def.get("item", ""))).get("name", "smithy")))


func wear_of(id: int) -> float:
	return float(host._items.get(id, {}).get("struct", {}).get("use_wear", 0.0))


# The use wear a smithy of this kind takes before it breaks (station_wear.durability by its anvil); 0 for a structure that is not a smithy.
func durability(def: Dictionary) -> float:
	return float(SmithingRules.cfg().get("station_wear", {}).get("durability", {}).get(str(def.get("anvil", "")), 0.0)) if is_smithy(def) else 0.0


# Broken: a smithy whose use wear has reached its durability. Built sites are never broken (a site is not a smithy yet).
func broken(id: int) -> bool:
	return broken_row(host._items.get(id, {}))


# The same for a world row: its store is shut to every use (server_items.gd _is_storage, _chest_of) until it is repaired.
func broken_row(it: Dictionary) -> bool:
	if not it.has("struct") or it["struct"].has("site"):
		return false

	var most: float = durability(host._structures.get(str(it["struct"]["kind"]), {}))
	return most > 0.0 and float(it["struct"].get("use_wear", 0.0)) >= most


# Its condition from use, 1 (new) to 0 (broken); 1 for a structure that is not a smithy.
func condition(id: int) -> float:
	var it: Dictionary = host._items.get(id, {})
	var most: float = durability(host._structures.get(str(it.get("struct", {}).get("kind", "")), {})) if it.has("struct") else 0.0
	return clampf(1.0 - float(it["struct"].get("use_wear", 0.0)) / most, 0.0, 1.0) if most > 0.0 else 1.0


# The blueprint cost a repair is worked out from: the smithy's own cost without the repair_skip rows (its anvil is mended, not paid again).
func repair_cost(cost: Array) -> Array:
	var skip: Array = SmithingRules.cfg().get("station_wear", {}).get("repair_skip", [])
	return cost.filter(func(need): return not skip.has(str(need[0])))


# A repair succeeded: the use wear goes back to 0; nothing else about the station changes.
func repaired(id: int) -> void:
	var it: Dictionary = host._items.get(id, {})

	if it.has("struct") and it["struct"].has("use_wear"):
		it["struct"].erase("use_wear")
		host._dirty = true


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
			var most: float = durability(host._structures[str(it["struct"]["kind"])])
			var wear: float = maxf(float(rows[str(it["struct"]["uid"])]), 0.0)
			it["struct"]["use_wear"] = minf(wear, most) if most > 0.0 else wear
