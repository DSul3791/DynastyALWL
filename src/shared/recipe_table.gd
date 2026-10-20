extends RefCounted

# Hand-craft recipes (data/items/recipes.json). Shared by server (which checks and does the
# craft) and client (which lists them and shows what can be made).

const PATH := "res://data/items/recipes.json"

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
		var needs: Array = []

		for need in row["needs"]:
			needs.append([item_table.number_of(str(need[0])), int(need[1])])

		var keeps: Array = []

		for keep in row.get("keeps", []):
			keeps.append([item_table.number_of(str(keep[0])), int(keep[1])])

		var entry: Dictionary = {
			"number": int(row["number"]), "id": id, "name": str(row["name"]), "needs": needs, "keeps": keeps,
			"gives": [item_table.number_of(str(row["gives"][0])), int(row["gives"][1])],
			"craft_s": float(row.get("craft_s", 3.0)), "known": bool(row.get("known", false)),
		}
		_by_number[entry["number"]] = entry

	return true


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

	if not r["known"]:
		return false

	var backup: Array = [inventory.numbers.duplicate(), inventory.counts.duplicate()]

	for need in r["needs"]:
		inventory.remove(need[0], need[1])

	if inventory.add(r["gives"][0], r["gives"][1]) > 0:
		inventory.numbers = backup[0]
		inventory.counts = backup[1]
		return false

	return true
