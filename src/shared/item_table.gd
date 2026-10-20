extends RefCounted

# The item table (data/items/items.json): item ids, numbers, stack sizes.
# Shared by server and client. Numbers are stable save ids; names are for code.

const PATH := "res://data/items/items.json"
const GATHERED_PATH := "res://data/items/gathered.json"   # one plain material per flora yield (tools/gen_gathered_items.py)

var _by_id: Dictionary = {}        # String id -> entry (with "id" added)
var _by_number: Dictionary = {}    # int number -> entry


static func load_default():
	var table = load("res://src/shared/item_table.gd").new()
	table.load_file(PATH)
	table.load_file(GATHERED_PATH)
	return table


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


func ids() -> Array:
	return _by_id.keys()
