extends RefCounted

# Hand-craft recipes (data/items/recipes.json). Shared by server (which checks and does the
# craft) and client (which lists them and shows what can be made).

const PATH := "res://data/items/recipes.json"

var open_unknown: Array = []   # ids in open_recipes.json that match no recipe (a test fails on any)
var _by_number: Dictionary = {}   # int -> {number, id, name, needs [[item number, count]], gives [item number, count], craft_s}


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
			"craft_s": float(row.get("craft_s", 3.0)), "known": bool(row.get("known", false)), "locked": bool(row.get("locked", false)),
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
	var out: Array = _by_number.keys()
	out.sort()
	return out


func recipe(number: int) -> Dictionary:
	return _by_number.get(number, {})


func can_make(number: int, inventory) -> bool:
	var r: Dictionary = recipe(number)

	if r.is_empty():
		return false

	for need in r["needs"]:
		if not inventory.has_fill(need[0], need[1]):   # a group id (log) is filled by any member (item_table.gd load_groups)
			return false

	for need in r["keeps"]:
		if not inventory.has(need[0], need[1]):
			return false

	return true


# Does the craft on an inventory: takes the ingredients, adds the result. False (and no change) if
# the ingredients are missing or the result does not fit.
func craft(number: int, inventory) -> bool:
	if not can_make(number, inventory):
		return false

	var r: Dictionary = recipe(number)

	if not r["known"]:
		return false

	var backup: Array = [inventory.numbers.duplicate(), inventory.counts.duplicate()]

	for need in r["needs"]:
		inventory.remove_fill(need[0], need[1])

	if inventory.add(r["gives"][0], r["gives"][1]) > 0:
		inventory.numbers = backup[0]
		inventory.counts = backup[1]
		return false

	return true
