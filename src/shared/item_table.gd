extends RefCounted

# The item table (data/items/items.json): item ids, numbers, stack sizes.
# Shared by server and client. Numbers are stable save ids; names are for code.

const PATH := "res://data/items/items.json"
const GATHERED_PATH := "res://data/items/gathered.json"   # one plain material per flora yield (tools/gen_gathered_items.py)
const GROUPS_PATH := "res://data/items/wood_species.json"   # "ingredient_groups": a plain id (log) that any listed item (log_oak ...) fills (guide finding F-16)

var _by_id: Dictionary = {}        # String id -> entry (with "id" added)
var _by_number: Dictionary = {}    # int number -> entry
var _spoil: Dictionary = {}
var _spoil_loaded: bool = false
var _groups: Dictionary = {}       # int number of a group id -> PackedInt32Array of the member item numbers (the group id itself first)


static func load_default():
	var table = load("res://src/shared/item_table.gd").new()
	table.load_file(PATH)
	table.load_file(GATHERED_PATH)
	table.load_groups(GROUPS_PATH)
	return table


# Reads the ingredient groups: a recipe that asks for the group id (log) is filled by the group id itself or any member (log_oak ...).
# Inventory.count_of / has / remove follow it, so every place that counts or takes an ingredient (server, craft planner, client list) agrees.
func load_groups(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var groups: Dictionary = parsed.get("ingredient_groups", {})

	for id in groups:
		if not _by_id.has(id) or typeof(groups[id]) != TYPE_ARRAY:
			continue

		var members: PackedInt32Array = PackedInt32Array([number_of(id)])

		for member in groups[id]:
			var n: int = number_of(str(member))

			if n > 0 and not members.has(n):
				members.append(n)

		_groups[number_of(id)] = members


# The item numbers that fill an ingredient: [] when the number is not a group id.
func group_members(number: int) -> PackedInt32Array:
	return _groups.get(number, PackedInt32Array())


func load_file(path: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("items"):
		push_error("item table: %s is not valid" % path)
		return false

	for id in parsed["items"]:
		var entry: Dictionary = parsed["items"][id].duplicate()
		entry["id"] = id
		entry["number"] = int(entry["number"])
		entry["stack"] = int(entry.get("stack", 1))
		_by_id[id] = entry
		_by_number[entry["number"]] = entry

	return true


func has_id(id: String) -> bool:
	return _by_id.has(id)


func entry(id: String) -> Dictionary:
	return _by_id.get(id, {})


func number_of(id: String) -> int:
	return int(_by_id.get(id, {}).get("number", 0))


func id_of(number: int) -> String:
	return String(_by_number.get(number, {}).get("id", ""))


func stack_of(number: int) -> int:
	return int(_by_number.get(number, {}).get("stack", 1))


func name_of(number: int) -> String:
	return String(_by_number.get(number, {}).get("name", "Unknown"))


# Placeholder price of one item (items.json "value"; 2 when it has none).
func value_of(number: int) -> int:
	return int(_by_number.get(number, {}).get("value", 2))


# Food spoilage (data/items/spoilage.json): the age a perishable stack keeps in its slot's wear field (tenths of a game hour)
# at which it is rotten, or 0 when the item does not spoil.
func spoilage() -> Dictionary:
	if not _spoil_loaded:
		_spoil_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/spoilage.json"))
		_spoil = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	return _spoil


var _shelf_cache: Dictionary = {}   # item number -> shelf life in units (the spoilage tick asks for every slot of every pack)


func shelf_units(number: int) -> int:
	if _shelf_cache.has(number):
		return int(_shelf_cache[number])

	var units: int = _shelf_units_uncached(number)
	_shelf_cache[number] = units
	return units


func _shelf_units_uncached(number: int) -> int:
	var cfg: Dictionary = spoilage()

	if cfg.is_empty():
		return 0

	var id: String = id_of(number)
	var hours: float = float(cfg.get("by_id", {}).get(id, 0.0))

	if hours <= 0.0:
		for suffix in cfg.get("by_suffix", {}):
			if id.ends_with(str(suffix)):
				hours = float(cfg["by_suffix"][suffix])
				break

	return 0 if hours <= 0.0 else maxi(int(round(hours * float(cfg.get("gentle_mult", 1)) / float(cfg.get("unit_h", 0.1)))), 1)


# 1.0 fresh down to 0.0 rotten for a stack of `number` with the age `age_units`; 1.0 for anything that does not spoil.
func freshness(number: int, age_units: int) -> float:
	var life: int = shelf_units(number)
	return 1.0 if life <= 0 else clampf(1.0 - float(age_units) / float(life), 0.0, 1.0)


func ids() -> Array:
	return _by_id.keys()
