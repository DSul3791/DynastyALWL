extends RefCounted

# The item table (data/items/items.json): item ids, numbers, stack sizes.
# Shared by server and client. Numbers are stable save ids; names are for code.

const PATH := "res://data/items/items.json"
const GATHERED_PATH := "res://data/items/gathered.json"   # one plain material per flora yield (tools/gen_gathered_items.py)

var _by_id: Dictionary = {}        # String id -> entry (with "id" added)
var _by_number: Dictionary = {}    # int number -> entry
var _spoil: Dictionary = {}
var _spoil_loaded: bool = false


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

	# Populate the suffix cache for shelf_units lookup.
	# This is a class variable so it's shared across all instances and only computed once.
	if _spoil.has("by_suffix") and not _suffix_cfg.is_empty():
		var by_suffix: Dictionary = _spoil["by_suffix"]
		for suffix in by_suffix:
			_suffix_cfg[suffix] = float(by_suffix[suffix])

	return _spoil


@class_var static var _suffix_cfg: Dictionary = {}  # parsed once at load time from spoilage.json.by_suffix
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

	# Check the specific id first; fall through to suffix only if not found.
	var hours: float = -1.0
	if _suffix_cfg.has(id):
		hours = float(_suffix_cfg[id])
	elif cfg.has("by_id") and cfg["by_id"].has(id) and not cfg["by_id"][id] == null:
		hours = float(cfg["by_id"][id])

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
