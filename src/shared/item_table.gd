extends RefCounted

# The item table (data/items/items.json): item ids, numbers, stack sizes.
# Shared by server and client. Numbers are stable save ids; names are for code.

const PATH := "res://data/items/items.json"
const GATHERED_PATH := "res://data/items/gathered.json"   # one plain material per flora yield (tools/gen_gathered_items.py)

var _by_id: Dictionary = {}        # String id -> entry (with "id" added)
var _by_number: Dictionary = {}    # int number -> entry
var _merged: Dictionary = {}      # int number of a retired item -> its merge target {"into": id, "tag": int} (items.json merged_into, merge_tag)
var _species: Dictionary = {}     # species name -> tag value (data/items/species_tags.json), loaded on first use
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

		if str(entry.get("merged_into", "")) != "":
			_merged[entry["number"]] = {"into": str(entry["merged_into"]), "tag": int(entry.get("merge_tag", 0))}

	return true


# A retired item that was folded into another (items.json "merged_into"): {"number": target number, "tag": the target's tag value, 0 for none},
# or {} for an item that stands. Saves keep the old number; the server calls this where a number comes in from disk (inventories, chests, world items).
func merged(number: int) -> Dictionary:
	var hops: int = 0
	var tag: int = 0
	var current: int = number

	while _merged.has(current) and hops < 4:
		var step: Dictionary = _merged[current]
		current = number_of(str(step["into"]))
		tag = int(step["tag"]) if int(step["tag"]) > 0 else tag
		hops += 1

	if current == number or current == 0:
		return {}

	return {"number": current, "tag": tag}


# Species tag values (data/items/species_tags.json): the number a stack of lumber or beam keeps in its wear field. 0 is "no species" (old stacks).
func species_code(species: String) -> int:
	_load_species()
	return int(_species.get(species, 0))


func species_name(code: int) -> String:
	_load_species()

	for name in _species:
		if int(_species[name]) == code:
			return str(name)

	return ""


func _load_species() -> void:
	if not _species.is_empty():
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/species_tags.json"))

	if typeof(parsed) == TYPE_DICTIONARY:
		_species = parsed.get("species", {})


# Does this item carry a tag in its slot's wear number (items.json "tag", e.g. "species" on lumber and beam)? Tagged stacks merge only with equal tags.
func tag_kind(number: int) -> String:
	return str(_by_number.get(number, {}).get("tag", ""))


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
