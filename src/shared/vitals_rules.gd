extends RefCounted

# What eating or applying an item does (data/items/vitals.json). Shared so the client's Eat button
# and right click offer only what the server will accept.

const PATH := "res://data/items/vitals.json"


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# Hunger points one item gives (0 = not food).
static func food_value(item_id: String, cfg: Dictionary) -> int:
	var food: Dictionary = cfg.get("food", {})

	if food.get("by_id", {}).has(item_id):
		return int(food["by_id"][item_id])

	for suffix in food.get("by_suffix", {}):
		if item_id.ends_with(str(suffix)):
			return int(food["by_suffix"][suffix])

	return 0


# Health points one item restores (0 = not medicine).
static func heal_value(item_id: String, cfg: Dictionary) -> int:
	return int(cfg.get("heal", {}).get(item_id, 0))


static func edible(item_id: String, cfg: Dictionary) -> bool:
	return food_value(item_id, cfg) > 0 or heal_value(item_id, cfg) > 0
