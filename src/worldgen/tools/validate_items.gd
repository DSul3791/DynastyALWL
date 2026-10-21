extends SceneTree

# Item data validator: items.json, gathered.json, recipes.json, drops.json, cooking.json.
# Checks numbers, unknown ids, orphan core items and recipes that can never be made.
#   godot --headless --path . --script res://src/worldgen/tools/validate_items.gd
# Exit code 1 when there are errors (warnings do not fail it).

const DATA := "res://data/items/"
# Items the code itself hands out (felling a trunk, the admin give, placing a fire) and so need no drop entry.
# Names of items and recipes are plain nouns (Dave 2026-10-20): "Basic torch", "Stone axe", never "Carve a ..." or "Make a ...".
const VERB_FIRST_WORDS := ["make", "carve", "chisel", "bind", "craft", "build", "tie", "knap", "twist", "weave", "split", "place", "roast", "cook", "dig", "cut", "sharpen", "light", "pick", "gather", "get", "use", "create", "forge", "fashion", "shape", "stack", "lay", "set", "form"]
const CODE_SOURCES := ["stone", "stick", "log", "bark", "leaves", "seed_bundle", "firewood", "driftwood"]

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


# Depth-first walk of the "made from" graph; a way back to an item on the current path is a cycle.
func _walk(id: String, path: Array, edges: Dictionary, state: Dictionary) -> void:
	if int(state.get(id, 0)) == 2:
		return

	if int(state.get(id, 0)) == 1:
		fail("recipe cycle: %s" % " -> ".join(path + [id]))
		return

	state[id] = 1

	for next in edges.get(id, []):
		_walk(String(next), path + [id], edges, state)

	state[id] = 2


# Every name in the data must be a plain noun phrase: no leading verb, no article, at most four words, capital first letter.
func _check_name(name: String, where: String) -> void:
	var words: PackedStringArray = name.strip_edges().split(" ", false)

	if words.is_empty():
		return

	var first: String = words[0].to_lower()

	if first in VERB_FIRST_WORDS or first in ["a", "an", "the"]:
		fail("%s: name '%s' starts with a verb or an article (names are plain nouns)" % [where, name])

	if words.size() > 4:
		fail("%s: name '%s' is longer than four words" % [where, name])

	if words[0].substr(0, 1) != words[0].substr(0, 1).to_upper():
		fail("%s: name '%s' does not start with a capital letter" % [where, name])


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

			if entry.has("value") and int(entry["value"]) < 0:
				fail("%s: '%s' has a negative value" % [pair[1], id])

			if String(entry.get("name", "")) == "":
				fail("%s: '%s' has no name" % [pair[1], id])
			_check_name(String(entry.get("name", "")), "%s: item '%s'" % [pair[1], id])

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

	var weights: Dictionary = _read("weights.json")

	for id in items_file.get("items", {}):
		var item: Dictionary = items_file["items"][id]
		var description: String = String(item.get("description", ""))

		# Every core item has a one-line description, a value and (unless it is a placed structure) its own weight.
		if description == "" or description.length() > 110 or not description.ends_with("."):
			fail("items.json: '%s' needs a one-line description of up to 110 characters ending in a full stop" % id)

		if String(item.get("kind", "")) != "structure":
			if not item.has("value"):
				fail("items.json: '%s' has no value" % id)

			var weighed: bool = weights.get("by_id", {}).has(id)

			for suffix in weights.get("by_suffix", {}):
				weighed = weighed or String(id).ends_with(String(suffix))

			if not weighed:
				fail("weights.json: '%s' has no weight (by_id or by_suffix); the default is not a real weight" % id)

		if item.has("durability") and (int(item["durability"]) < 1 or item.get("repair", []).is_empty()):
			fail("items.json: '%s' has durability but no repair materials" % id)

		for row in item.get("repair", []):
			want_item.call(String(row[0]), "items.json %s repair" % id)

	for group in ["by_species", "by_kind"]:
		for key in drops.get(group, {}):
			if group == "by_species" and not species.has(key):
				fail("drops.json by_species: unknown flora species '%s'" % key)

			for row in drops[group][key]:
				want_item.call(String(row[0]), "drops.json %s.%s" % [group, key])

				if int(row[1]) < 1 or int(row[2]) < int(row[1]):
					fail("drops.json %s.%s: bad amounts for %s" % [group, key, row[0]])

				obtainable[String(row[0])] = true

	var trunk: Dictionary = drops.get("trunk", {})

	if trunk.has("roots"):
		want_item.call(String(trunk["roots"][0]), "drops.json trunk.roots")
		obtainable[String(trunk["roots"][0])] = true

	for species_name in trunk.get("by_species", {}):
		if not species.has(species_name):
			fail("drops.json trunk.by_species: unknown flora species '%s'" % species_name)

		for row in trunk["by_species"][species_name]:
			want_item.call(String(row[0]), "drops.json trunk.by_species.%s" % species_name)
			obtainable[String(row[0])] = true

	for row in drops.get("trunk", {}).get("branch", []):
		want_item.call(String(row[0]), "drops.json trunk.branch")
		obtainable[String(row[0])] = true

	# Dig yields (job 84): every item named in digging.json exists and counts as obtainable; every material is a soil or "rock".
	var digging: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/digging.json"))

	if typeof(digging) == TYPE_DICTIONARY:
		var soil_names: Dictionary = {"rock": true}
		var soils_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/soils.json"))

		for soil_entry in soils_parsed.get("entries", []):
			soil_names[String(soil_entry["name"])] = true

		for material in digging.get("yield", {}):
			if not soil_names.has(String(material)):
				fail("digging.json yield: unknown ground material '%s'" % material)

			for row in digging["yield"][material]:
				want_item.call(String(row[0]), "digging.json yield.%s" % material)
				obtainable[String(row[0])] = true

		for row in digging.get("default", []):
			want_item.call(String(row[0]), "digging.json default")
			obtainable[String(row[0])] = true

		for name in digging.get("fill", []):
			want_item.call(String(name), "digging.json fill")

		for material in digging.get("under", {}):
			want_item.call(String(digging["under"][material][0]), "digging.json under.%s" % material)
			obtainable[String(digging["under"][material][0])] = true

	# Flora yields that the generated gathered items stand for (plain materials any gatherer may find in time).
	var yields: Dictionary = {}

	for entry in _read("../tables/flora.json").get("entries", []):
		for y in entry.get("yields", []):
			yields[String(y)] = true

	var gatherable: Dictionary = {}   # plain materials a gatherer finds on flora (gathered.json items that are still a flora yield)

	for id in gathered_file.get("items", {}):
		if not yields.has(id):
			warn("gathered.json: '%s' is no longer a flora yield" % id)
		else:
			gatherable[id] = true
			obtainable[id] = true

	# Skill hooks: every action names a skill and an effect the code knows.
	for action in _read("skills.json").get("actions", {}):
		var def: Dictionary = _read("skills.json")["actions"][action]

		if String(def.get("skill", "")) == "" or not String(def.get("effect", "")) in ["yield", "speed", "toughness"]:
			fail("skills.json: action '%s' needs a skill name and an effect of yield, speed or toughness" % action)

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
		_check_name(String(r.get("name", "")), "recipes.json: recipe '%s'" % rid)

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

	# Core materials marked "future": true (iron and steel ingots until smelting exists) count as sources for the recipe check.
	for id in items_file.get("items", {}):
		if bool(items_file["items"][id].get("future", false)) and String(items_file["items"][id].get("kind", "")) == "material":
			obtainable[String(id)] = true

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

	# Placed forms of structures come from taking the kit out (structures.json).
	var structures: Dictionary = _read("structures.json").get("structures", {})

	for kind in structures:
		var def: Dictionary = structures[kind]

		if not bool(def.get("take_only", false)):   # remains have no kit: nobody takes them down
			want_item.call(String(def.get("kit", "")), "structures.json %s kit" % kind)


		want_item.call(String(def.get("item", "")), "structures.json %s item" % kind)

		if float(def.get("footprint_x", 0.0)) <= 0.0 or float(def.get("footprint_z", 0.0)) <= 0.0:
			fail("structures.json %s: footprint_x and footprint_z (the ghost's size in metres) are required" % kind)

		if def.has("slots") and (int(def.get("slots", 0)) < 1 or int(def.get("slots", 0)) > 30):
			fail("structures.json %s: slots must be 1 to 30" % kind)

		if def.has("max_kg") and float(def.get("max_kg", 0.0)) <= 0.0:
			fail("structures.json %s: max_kg must be above 0" % kind)

		if String(def.get("who", "anyone")) != "anyone" and not (bool(def.get("take_only", false)) and String(def.get("who")) == "owner"):   # remains: owner first day
			fail("structures.json %s: who is '%s' but only \"anyone\" is built (owner and town wait for ownership)" % [kind, def.get("who")])
		obtainable[String(def.get("item", ""))] = true

	# Recipe graph (job 72): every core item is gatherable, craftable from gatherables, or marked "future": true in items.json;
	# no cycles; dead ends (obtainable materials nothing uses) are listed so Dave can see what still has no purpose.
	var craftable: Dictionary = {}
	var edges: Dictionary = {}   # item id -> the item ids it is made from (needs and keeps)

	for rid in recipes:
		var out: String = String(recipes[rid].get("gives", [""])[0])
		craftable[out] = true

		if not edges.has(out):
			edges[out] = []

		for list in ["needs", "keeps"]:
			for row in recipes[rid].get(list, []):
				edges[out].append(String(row[0]))

	var state: Dictionary = {}   # id -> 1 on the walk, 2 done

	for id in edges:
		_walk(id, [], edges, state)

	var future: Array = []
	var placed_forms: Dictionary = {}

	for kind in structures:
		placed_forms[String(structures[kind].get("item", ""))] = true

	for id in items_file.get("items", {}):
		var entry: Dictionary = items_file["items"][id]
		var is_future: bool = bool(entry.get("future", false))

		if is_future:
			future.append(id)

		if not obtainable.has(id) and not String(id).ends_with("_kit") and not is_future:
			fail("core item '%s' is not gatherable, not craftable and not marked \"future\": true" % id)
		elif obtainable.has(id) and is_future:
			warn("core item '%s' is marked future but can be obtained" % id)

	var used: Dictionary = {}

	for rid in recipes:
		for list in ["needs", "keeps"]:
			for row in recipes[rid].get(list, []):
				used[String(row[0])] = true

	for id in cooking.get("fuel", {}):
		used[String(id)] = true

	used[String(cooking.get("tinder", ""))] = true

	for id in items_file.get("items", {}):
		for row in items_file["items"][id].get("repair", []):
			used[String(row[0])] = true

	var food: Dictionary = _read("vitals.json").get("food", {})

	for id in food.get("by_id", {}):
		used[String(id)] = true

	var dead_core: Array = []

	for id in items_file.get("items", {}):
		var entry: Dictionary = items_file["items"][id]

		if String(entry.get("kind", "")) == "material" and obtainable.has(id) and not used.has(id):
			dead_core.append(id)

	if not dead_core.is_empty():
		warn("dead-end materials (obtainable, no recipe, fuel or repair uses them): %s" % ", ".join(dead_core))

	var edible_suffixes: Array = []

	for suffix in food.get("by_suffix", {}):
		edible_suffixes.append(String(suffix))

	var gathered_unused: int = 0

	for id in gatherable:
		var eaten: bool = false

		for suffix in edible_suffixes:
			eaten = eaten or String(id).ends_with(suffix)

		if not used.has(id) and not eaten:
			gathered_unused += 1

	print("graph: %d core items: %d gatherable plain materials feed %d craftable items; %d marked future (%s); %d gathered materials have no use yet" % [items_file.get("items", {}).size(), gatherable.size(), craftable.size(), future.size(), ", ".join(future), gathered_unused])

	print("items: %d core, %d gathered, %d recipes" % [items_file.get("items", {}).size(), gathered_file.get("items", {}).size(), recipes.size()])
	print("item validator: %d errors, %d warnings" % [errors, warnings])
	quit(1 if errors > 0 else 0)
