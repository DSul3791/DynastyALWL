extends RefCounted

# The item table (data/items/items.json): item ids, numbers, stack sizes.
# Shared by server and client. Numbers are stable save ids; names are for code.

const PATH := "res://data/items/items.json"
# The most one slot holds (the u16 count on the wire and in the pack bytes). Weight, not a stack size, limits what a body carries (Dave 24 Oct).
const COUNT_MAX := 65535
const GATHERED_PATH := "res://data/items/gathered.json"   # one plain material per flora yield (tools/gen_gathered_items.py)
const GROUPS_PATH := "res://data/items/wood_species.json"   # "ingredient_groups": a plain id (log) that any listed item (log_oak ...) fills (guide finding F-16)
const RENAMES_PATH := "res://data/items/renames.json"   # a retired item -> the item that took its place, swapped in when a save loads

var _by_id: Dictionary = {}        # String id -> entry (with "id" added)
var _by_number: Dictionary = {}    # int number -> entry
var _spoil: Dictionary = {}
var _spoil_loaded: bool = false
var _groups: Dictionary = {}       # int number of a group id -> PackedInt32Array of the member item numbers (the group id itself first)
var _group_label: Dictionary = {}   # group key item number -> the label its costs read under (wood_species.json group_labels)
var _renamed: Dictionary = {}      # int number of a retired item -> int number of the item that replaced it


static func load_default():
	var table = load("res://src/shared/item_table.gd").new()
	table.load_file(PATH)
	table.load_file(GATHERED_PATH)
	table.load_groups(GROUPS_PATH)
	table.load_renames(RENAMES_PATH)
	return table


# Reads the renames: an old item id -> the id that replaced it (hide_leggings -> hide_trousers). A pair counts only while the old row is
# "retired": true and the new row exists, so the swap waits for the retirement to land and stops if the new item goes away.
func load_renames(path: String) -> void:
	_renamed = {}

	if not FileAccess.file_exists(path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("renames", {})) != TYPE_DICTIONARY:
		return

	var pairs: Dictionary = parsed.get("renames", {})

	for old_id in pairs:
		var new_id: String = str(pairs[old_id])

		if _by_id.has(old_id) and _by_id.has(new_id) and old_id != new_id and bool(_by_id[old_id].get("retired", false)):
			_renamed[number_of(old_id)] = number_of(new_id)


# The item number a saved number stands for now: the replacement of a retired item (following a chain of renames), else the number itself.
func current_number(number: int) -> int:
	var now: int = number

	for _hop in 8:
		if not _renamed.has(now):
			break

		now = int(_renamed[now])

	return now


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

	# A group cost reads under its label, not its key item's name (master s4 item 14): a softwood-log cost keyed by Spruce log reads
	# "Softwood log", and a firewood cost "Firewood" though the key item is Hard firewood.
	var labels: Dictionary = parsed.get("group_labels", {})

	for id in labels:
		if _groups.has(number_of(str(id))) and typeof(labels[id]) == TYPE_STRING:
			_group_label[number_of(str(id))] = str(labels[id])


# The name an ingredient reads under in a cost list: a labelled group's label, else the item's own name.
func cost_name(number: int) -> String:
	return String(_group_label.get(number, name_of(number)))


func cost_sentence(number: int) -> String:
	return in_sentence(cost_name(number))


func has_group_label(number: int) -> bool:
	return _group_label.has(number)


# The item numbers that fill an ingredient: [] when the number is not a group id.
func group_members(number: int) -> PackedInt32Array:
	return _groups.get(number, PackedInt32Array())


# The one ranking of a group's members, "lowest" first (coordinator 10 Nov 2026): the lowest items.json "tier", then the lowest material on SPEND_MATERIALS,
# then the lowest "value"; a member with none of these ranks last on that field, and a full tie keeps the group's own order (its own id first: plain logs for any log).
# A cost spends its lowest member first (Inventory.remove_fill, the ground and container takes in server_items.gd) and a taken-down piece gives it back (_refund_number),
# so Bronze nails go before iron Nails and come back as Bronze nails. [] when the number is not a group id.
const SPEND_MATERIALS := ["wood", "bone", "stone", "flint", "obsidian", "copper", "tin", "bronze", "iron", "steel"]


func spend_order(number: int) -> PackedInt32Array:
	var members: PackedInt32Array = group_members(number)
	var rows: Array = []

	for i in members.size():
		var row: Dictionary = entry(id_of(members[i]))
		var material_rank: int = SPEND_MATERIALS.find(str(row.get("material", "")))
		rows.append([int(row.get("tier", 99)), material_rank if material_rank >= 0 else 99, float(row.get("value", 1.0e9)), i])

	var order: Array = range(members.size())
	order.sort_custom(func(a, b): return rows[a] < rows[b])   # Array compares element by element; the group index last makes the order total
	var out: PackedInt32Array = PackedInt32Array()

	for i in order:
		out.append(members[i])

	return out


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


# An item's name inside a sentence: "Stone - Knife" (the UI label, item_system.md "Tier - Item") reads "stone knife" there
# ("You hone the stone knife."). Labels, lists and tooltips keep name_of.
func sentence_name(number: int) -> String:
	return in_sentence(name_of(number))


# Any name (an item's, a recipe's, a crop's) as it reads inside a sentence: lower case, the tier dash dropped.
func in_sentence(text: String) -> String:
	return text.replace(" - ", " ").to_lower()


# 1 for an item marked "unstackable" in items.json (tools, kits, structures, containers, clothing, shoulder logs), else COUNT_MAX. The old "stack"
# number stays in the file for one version and is ignored (rollback rule: never go back to a cap without Dave).
func stack_of(number: int) -> int:
	var row: Dictionary = _by_number.get(number, {})

	if row.is_empty() or bool(row.get("unstackable", false)):
		return 1

	return COUNT_MAX


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


# Wet wood (docs/design/fire_coals_design.md 5, cooking.json fuel_class and wet_wood): the wood class of an item (log, firewood, weak), "" for
# anything that is not wood. A wood slot's wear is its drying left in tenths of a game hour (0 = dry).
var _wood_loaded: bool = false
var _wood_class: Dictionary = {}    # item number -> wood class
var _wet_wood: Dictionary = {}


func _load_wood() -> void:
	_wood_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var classes: Dictionary = parsed.get("fuel_class", {})

	for id in classes:
		var number: int = number_of(str(id))

		if number > 0:
			_wood_class[number] = str(classes[id])

	_wet_wood = parsed.get("wet_wood", {})


func wood_class(number: int) -> String:
	if not _wood_loaded:
		_load_wood()

	return str(_wood_class.get(number, ""))


func wet_wood() -> Dictionary:
	if not _wood_loaded:
		_load_wood()

	return _wet_wood


# The drying left a fully wetted piece of this wood gets (wet_wood.wet_h of its class), in wear units; 0 for anything else.
func wet_units(number: int) -> int:
	var cls: String = wood_class(number)
	return 0 if cls == "" else int(round(float((wet_wood().get("wet_h", {}) as Dictionary).get(cls, 0.0)) * 10.0))


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


# Passive maturing (master s3.14 [D14], Mission 001 phase 6): the age in wear units at which a sealed food is Ready, from the "ready_age" (game
# hours, not stretched by gentle_mult) of the recipe that makes it, which recipe_table.gd load_file sets here; 0 for food that is ready when made.
# Below it the stack is Maturing: it is not eaten, used, sold or merged with a stack of another age (Inventory._mergeable).
var _ready: Dictionary = {}   # item number -> ready age in wear units


func set_ready_age(number: int, hours: float) -> void:
	if number > 0 and hours > 0.0:
		_ready[number] = maxi(int(_ready.get(number, 0)), int(round(hours / float(spoilage().get("unit_h", 0.1)))))


func ready_units(number: int) -> int:
	return int(_ready.get(number, 0))


func maturing(number: int, age_units: int) -> bool:
	return age_units < ready_units(number)


# Game hours until a Maturing stack is Ready at the pack's pace, rounded up (0 once Ready): what the player is told and shown.
func ready_hours_left(number: int, age_units: int) -> int:
	return ceili(float(maxi(ready_units(number) - age_units, 0)) * float(spoilage().get("unit_h", 0.1)))


# 1.0 fresh down to 0.0 rotten for a stack of `number` with the age `age_units`; 1.0 for anything that does not spoil.
func freshness(number: int, age_units: int) -> float:
	var life: int = shelf_units(number)
	return 1.0 if life <= 0 else clampf(1.0 - float(age_units) / float(life), 0.0, 1.0)


func ids() -> Array:
	return _by_id.keys()
