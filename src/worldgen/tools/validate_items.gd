extends SceneTree

# Item data validator: items.json, gathered.json, recipes.json, drops.json, cooking.json.
# Checks numbers, unknown ids, orphan core items and recipes that can never be made.
#   godot --headless --path . --script res://src/worldgen/tools/validate_items.gd
# Exit code 1 when there are errors (warnings do not fail it).

const DATA := "res://data/items/"
# Items the code itself hands out (felling a trunk, the admin give, placing a fire) and so need no drop entry.
const CODE_SOURCES := ["stone", "stick", "log", "bark", "leaves", "seed_bundle"]

var errors: int = 0
var warnings: int = 0


func fail(what: String) -> void:
	errors += 1
	print("ERROR ", what)


func warn(what: String) -> void:
	warnings += 1
	print("WARN  ", what)


func _read(file: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA + file))

	if typeof(parsed) != TYPE_DICTIONARY:
		fail("%s is not valid JSON" % file)
		return {}

	return parsed


func _init() -> void:
	var items_file: Dictionary = _read("items.json")
	var gathered_file: Dictionary = _read("gathered.json")
	var recipes_file: Dictionary = _read("recipes.json")
	var drops: Dictionary = _read("drops.json")
	var cooking: Dictionary = _read("cooking.json")
	var all: Dictionary = {}        # id -> entry
	var numbers: Dictionary = {}    # number -> id

	for pair in [[items_file, "items.json"], [gathered_file, "gathered.json"]]:
		var file: Dictionary = pair[0]
		var highest: int = 0

		for id in file.get("items", {}):
			var entry: Dictionary = file["items"][id]
			var number: int = int(entry.get("number", 0))
			highest = maxi(highest, number)

			if all.has(id):
				fail("%s: item id '%s' defined twice" % [pair[1], id])

			if number < 1:
				fail("%s: '%s' has no valid number" % [pair[1], id])
			elif numbers.has(number):
				fail("%s: number %d used by '%s' and '%s'" % [pair[1], number, numbers[number], id])

			if int(entry.get("stack", 1)) < 1:
				fail("%s: '%s' stack below 1" % [pair[1], id])

			if String(entry.get("name", "")) == "":
				fail("%s: '%s' has no name" % [pair[1], id])

			all[id] = entry
			numbers[number] = id

		if int(file.get("next_number", 0)) <= highest:
			fail("%s: next_number %s is not above the highest number %d" % [pair[1], file.get("next_number"), highest])

	var species: Dictionary = {}

	for entry in _read("../tables/flora.json").get("entries", []):
		species[String(entry.get("name", ""))] = true

	# Where items can come from.
	var obtainable: Dictionary = {}

	for id in CODE_SOURCES:
		obtainable[id] = true

	var want_item := func(id: String, where: String) -> void:
		if not all.has(id):
			fail("%s: unknown item '%s'" % [where, id])

	for group in ["by_species", "by_kind"]:
		for key in drops.get(group, {}):
			if group == "by_species" and not species.has(key):
				fail("drops.json by_species: unknown flora species '%s'" % key)

			for row in drops[group][key]:
				want_item.call(String(row[0]), "drops.json %s.%s" % [group, key])

				if int(row[1]) < 1 or int(row[2]) < int(row[1]):
					fail("drops.json %s.%s: bad amounts for %s" % [group, key, row[0]])

				obtainable[String(row[0])] = true

	for row in drops.get("trunk", {}).get("branch", []):
		want_item.call(String(row[0]), "drops.json trunk.branch")
		obtainable[String(row[0])] = true

	# Flora yields that the generated gathered items stand for (plain materials any gatherer may find in time).
	var yields: Dictionary = {}

	for entry in _read("../tables/flora.json").get("entries", []):
		for y in entry.get("yields", []):
			yields[String(y)] = true

	for id in gathered_file.get("items", {}):
		if not yields.has(id):
			warn("gathered.json: '%s' is no longer a flora yield" % id)

	# Cooking.
	want_item.call(String(cooking.get("gives", "")), "cooking.json gives")
	obtainable[String(cooking.get("gives", ""))] = true

	for id in cooking.get("fuel", {}):
		want_item.call(String(id), "cooking.json fuel")

	for suffix in cooking.get("cookable_suffixes", []):
		var any: bool = false

		for id in all:
			if String(id).ends_with(String(suffix)):
				any = true

		if not any:
			warn("cooking.json: suffix '%s' matches no item" % suffix)

	# Recipes: ids exist, numbers unique, then which can ever be made.
	var recipes: Dictionary = recipes_file.get("recipes", {})
	var recipe_numbers: Dictionary = {}
	var highest_recipe: int = 0

	for rid in recipes:
		var r: Dictionary = recipes[rid]
		var n: int = int(r.get("number", 0))
		highest_recipe = maxi(highest_recipe, n)

		if recipe_numbers.has(n):
			fail("recipes.json: number %d used by '%s' and '%s'" % [n, recipe_numbers[n], rid])

		recipe_numbers[n] = rid

		for id in r.get("identify", []):
			want_item.call(String(id), "recipe '%s' identify" % rid)

		for list in ["needs", "keeps"]:
			for row in r.get(list, []):
				want_item.call(String(row[0]), "recipe '%s' %s" % [rid, list])

				if int(row[1]) < 1:
					fail("recipe '%s' %s: amount below 1" % [rid, list])

		if (r.get("needs", []) as Array).size() > 3:
			fail("recipe '%s': hand recipes have at most three ingredient kinds" % rid)

		want_item.call(String(r.get("gives", [""])[0]), "recipe '%s' gives" % rid)

	if int(recipes_file.get("next_number", 0)) <= highest_recipe:
		fail("recipes.json: next_number is not above the highest recipe number")

	var changed: bool = true

	while changed:
		changed = false

		for rid in recipes:
			var r: Dictionary = recipes[rid]
			var gives: String = String(r.get("gives", [""])[0])

			if obtainable.has(gives):
				continue

			var ok: bool = true

			for list in ["needs", "keeps"]:
				for row in r.get(list, []):
					if not obtainable.has(String(row[0])):
						ok = false

			if ok:
				obtainable[gives] = true
				changed = true

	for rid in recipes:
		if not obtainable.has(String(recipes[rid].get("gives", [""])[0])):
			fail("recipe '%s' can never be made (an ingredient has no source)" % rid)

	# Core items nothing produces or uses; the campfire kit is placed, not found.
	for id in items_file.get("items", {}):
		if not obtainable.has(id) and not String(id).ends_with("_kit"):
			warn("orphan core item '%s' (no drop, no recipe gives it)" % id)

	var unused: int = 0

	for id in gathered_file.get("items", {}):
		if not obtainable.has(id):
			unused += 1

	print("items: %d core, %d gathered (%d not yet obtainable, waiting on herb and food systems), %d recipes" % [items_file.get("items", {}).size(), gathered_file.get("items", {}).size(), unused, recipes.size()])
	print("item validator: %d errors, %d warnings" % [errors, warnings])
	quit(1 if errors > 0 else 0)
