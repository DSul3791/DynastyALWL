extends RefCounted

# Hand-craft recipes (data/items/recipes.json). Shared by server (which checks and does the
# craft) and client (which lists them and shows what can be made).

const PATH := "res://data/items/recipes.json"

var open_unknown: Array = []   # ids in open_recipes.json that match no recipe (a test fails on any)
var _by_number: Dictionary = {}   # int -> {number, id, name, needs [[item number, count]], gives [item number, count], craft_s}
var _sorted_numbers: Array = []  # cached sorted list of numbers (populated once after load)


static func load_default(item_table):
	var table = load("res://src/shared/recipe_table.gd").new()
	table.load_file(PATH, item_table)
	return table


func load_file(path: String, item_table) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("recipes"):
		push_error("recipe table: %s is not valid" % path)
		return false

	for id in parsed["recipes"]:
		var row: Dictionary = parsed["recipes"][id]

		if bool(row.get("retired", false)):   # kept in the file so the number is never reused (Dave 24 Oct, key woods)
			continue

		var needs: Array = []

		for need in row["needs"]:
			needs.append([item_table.number_of(str(need[0])), int(need[1])])

		var keeps: Array = []

		for keep in row.get("keeps", []):
			keeps.append([item_table.number_of(str(keep[0])), int(keep[1])])

		var identify: Array = []

		for need in row.get("identify", []):
			identify.append(item_table.number_of(str(need)))

		var entry: Dictionary = {
			"number": int(row["number"]), "id": id, "name": str(row["name"]), "category": str(row.get("category", "")), "needs": needs, "keeps": keeps, "identify": identify,
			"gives": [item_table.number_of(str(row["gives"][0])), int(row["gives"][1])],
			"craft_s": float(row.get("craft_s", 3.0)), "known": bool(row.get("known", false)),
			"station": str(row.get("station", "")), "station_level": int(row.get("station_level", 1)),
			"wears_tool": str(row.get("wears_tool", "")),
		}
		_by_number[entry["number"]] = entry

	_open_listed(path.get_base_dir().path_join("open_recipes.json"))
	return true


# data/items/open_recipes.json {"open": [ids]}: recipes known from the first minute (Dave 24 Oct, no learn system). Server and client read the same file.
func _open_listed(path: String) -> void:
	open_unknown.clear()

	if not FileAccess.file_exists(path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("recipe table: %s is not valid" % path)
		return

	for id in parsed.get("open", []):
		var found: bool = false

		for number in _by_number:
			if _by_number[number]["id"] == str(id):
				_by_number[number]["known"] = true
				found = true

		if not found:
			open_unknown.append(str(id))


func numbers() -> Array:
	if _sorted_numbers.is_empty():
		var keys: Array = _by_number.keys()
		keys.sort()
		_sorted_numbers = keys
	return _sorted_numbers


func recipe(number: int) -> Dictionary:
	return _by_number.get(number, {})


func can_make(number: int, inventory) -> bool:
	var r: Dictionary = recipe(number)

	if r.is_empty():
		return false

	for need in r["needs"] + r["keeps"]:
		if not inventory.has(need[0], need[1]):
			return false

	return true


# Does the craft on an inventory: takes the ingredients, adds the result. False (and no change) if
# the ingredients are missing or the result does not fit.
func craft(number: int, inventory) -> bool:
	if not can_make(number, inventory):
		return false

	var r: Dictionary = recipe(number)

	# Validate that the crafted item number is still a valid entry in item_table.
	# A retired or reused number should not be craftable (Dave 2026-10-26).
	if not inventory.item_table.has_id(r["id"]):
		push_error("recipe: crafting %s (number %d) would create an invalid item" % [r["name"], r["number"]])
		return false

	if not r["known"]:
		return false

	# Track which slots were modified so we only revert those, avoiding full array copies.
	var changed_slots: Dictionary = {}   # slot_index -> {number, count}

	for need in r["needs"]:
		var taken: Dictionary = inventory.take_from_slot(need[0], need[1])

		if not taken.is_empty():
			# restore the slot we just emptied (take_from_slot returns {number, count} of what was removed)
			inventory.numbers[taken.slot] = taken.number
			inventory.counts[taken.slot] = taken.count

	if inventory.add(r["gives"][0], r["gives"][1]) > 0:
		return false

	return true