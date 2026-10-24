extends SceneTree

const SkillWebCheck := preload("res://src/shared/skill_web.gd")

# Item data validator: items.json, gathered.json, recipes.json, drops.json, cooking.json.
# Checks numbers, unknown ids, orphan core items and recipes that can never be made.
#   godot --headless --path . --script res://src/worldgen/tools/validate_items.gd
# Exit code 1 when there are errors (warnings do not fail it).

const DATA := "res://data/items/"
# Items the code itself hands out (a carcass is made when an animal dies; felling a trunk, the admin give, placing a fire) and so need no drop entry.
# Names of items and recipes are plain nouns (Dave 2026-10-20): "Basic torch", "Stone axe", never "Carve a ..." or "Make a ...".
const VERB_FIRST_WORDS := ["make", "carve", "chisel", "bind", "craft", "build", "tie", "knap", "twist", "weave", "split", "place", "roast", "cook", "dig", "cut", "sharpen", "light", "pick", "gather", "get", "use", "create", "forge", "fashion", "shape", "stack", "lay", "set", "form"]
const CODE_SOURCES := ["stone", "stick", "log", "bark", "leaves", "seed_bundle", "firewood", "driftwood"]

const MAX_INGREDIENTS := 6   # the craft screen lists every ingredient in a scrolling detail area and the server crafts any count (test_server_items); raise further here only

const DAVE_NAMES := ["Roast Beast", "Roast Meat", "Roast Fish", "Roast Roots"]   # names Dave chose himself (2026-10-22): they read like a verb and are the real name

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

	if name in DAVE_NAMES:
		return

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

	# Every wood class names a firewood item and a block item that exist (wood_species.json class_items).
	var wood_file: Dictionary = _read("wood_species.json")

	for cls in wood_file.get("class_items", {}):
		for step in ["firewood", "block"]:
			if not items_file.get("items", {}).has(String(wood_file["class_items"][cls].get(step, ""))):
				fail("wood_species.json: class %s needs an existing %s item" % [cls, step])

	for sp in wood_file.get("species", {}):
		if not wood_file.get("class_items", {}).has(String(wood_file["species"][sp].get("class", ""))):
			fail("wood_species.json: species %s has a class without class_items" % sp)

	# Key woods (Dave 24 Oct): each is a tree with live log, lumber and beam items; no live recipe, drop table or building cost names a retired item.
	var trees: Dictionary = {}
	var biome_key: Dictionary = {}
	var biome_any: Dictionary = {}

	for entry in _read("../tables/flora.json").get("entries", []):
		if str(entry.get("kind", "")) != "tree":
			continue

		trees[str(entry["name"])] = true

		for biome in entry.get("per_hectare", {}):
			biome_any[biome] = true

			if (wood_file.get("key_woods", []) as Array).has(str(entry["name"])):
				biome_key[biome] = true

	for key_wood in wood_file.get("key_woods", []):
		if not trees.has(str(key_wood)):
			fail("wood_species.json: key wood %s is not a tree in flora.json" % key_wood)

		for prefix in ["log_", "lumber_", "beam_"]:
			var key_item: Dictionary = items_file.get("items", {}).get(prefix + str(key_wood), {})

			if key_item.is_empty() or bool(key_item.get("retired", false)):
				fail("wood_species.json: key wood %s needs a live %s%s item" % [key_wood, prefix, key_wood])

	var retired_ids: Array = []

	for id in items_file.get("items", {}):
		if bool(items_file["items"][id].get("retired", false)):
			retired_ids.append(str(id))

	for rid in recipes_file.get("recipes", {}):
		var recipe: Dictionary = recipes_file["recipes"][rid]

		if bool(recipe.get("retired", false)):
			continue

		for ref in JSON.stringify(recipe).split("\""):
			if retired_ids.has(ref):
				fail("recipes.json: live recipe %s names the retired item %s" % [rid, ref])

	for file_name in ["drops.json", "structures.json"]:
		for ref in JSON.stringify(_read(file_name)).split("\""):
			if retired_ids.has(ref):
				fail("%s names the retired item %s" % [file_name, ref])

	var no_key: Array = []

	for biome in biome_any:
		if not biome_key.has(biome):
			no_key.append(biome)

	no_key.sort()
	print("info: biomes whose trees include no key wood (they give firewood and sticks only): ", ", ".join(no_key))

	for id in items_file.get("items", {}):
		var item: Dictionary = items_file["items"][id]
		var description: String = String(item.get("description", ""))

		if bool(item.get("offhand", false)) and (not ["tool", "weapon"].has(String(item.get("kind", ""))) or not ["torch", "shield"].has(String(item.get("tool_class", "")))):
			fail("items.json: '%s' is marked offhand but is not a tool or weapon of class torch or shield (the left-hand models)" % id)

		if item.has("pile"):   # bulk items drawn as a pile on the ground (PileLook) and taken by the handful
			var pile: Dictionary = item["pile"]
			var tint: Array = pile.get("color", [])

			if not ["pyramid", "mound"].has(String(pile.get("shape", ""))) or int(pile.get("handful", 0)) < 1 or tint.size() != 3 or float(pile.get("rock", 0.0)) <= 0.0 or float(pile.get("squash", 0.0)) <= 0.0:
				fail("items.json: '%s' pile row needs shape pyramid or mound, handful 1 or more, color [r, g, b], rock and squash above 0" % id)

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

	var yield_scale: Dictionary = drops.get("yield_scale", {})

	if not yield_scale.is_empty() and (float(yield_scale.get("min", 1.0)) < 0.1 or float(yield_scale.get("max", 1.0)) < float(yield_scale.get("min", 1.0)) or float(yield_scale.get("max", 1.0)) > 5.0):
		fail("drops.json yield_scale: min 0.1 or more, max at least min and at most 5")

	# The showroom (data/items/showroom.json) fills the world with REAL items: every row entry must be an existing item with a description to inspect.
	for row in _read("showroom.json").get("rows", []):
		for entry in row.get("items", []):
			var show_id: String = String(entry[0])
			var show_item: Dictionary = items_file.get("items", {}).get(show_id, gathered_file.get("items", {}).get(show_id, {}))

			if show_item.is_empty():
				fail("showroom.json row %s: unknown item '%s'" % [String(row.get("label", "")), show_id])
			elif String(show_item.get("kind", "")) == "structure":
				fail("showroom.json row %s: '%s' is a placed structure, use its kit" % [String(row.get("label", "")), show_id])

	# Berries per plant (drops.json berry_yield): a flora species, one of its yields, a count of at least 1 and a berry stack of 100.
	for key in drops.get("berry_yield", {}):
		var berry: Dictionary = drops["berry_yield"][key]
		var berry_id: String = String(berry.get("item", ""))

		if not species.has(key):
			fail("drops.json berry_yield: unknown flora species '%s'" % key)

		want_item.call(berry_id, "drops.json berry_yield.%s" % key)

		if int(berry.get("count", 0)) < 1:
			fail("drops.json berry_yield.%s: count must be 1 or more" % key)

		if int(gathered_file.get("items", {}).get(berry_id, items_file.get("items", {}).get(berry_id, {})).get("stack", 1)) < 100:
			fail("drops.json berry_yield.%s: %s needs a stack of 100 or more" % [key, berry_id])

	# One source of truth: a species is in berry_yield or harvest_yield, never both (the helper would silently pick the berry row).
	for key in drops.get("berry_yield", {}):
		if (drops.get("harvest_yield", {}) as Dictionary).has(key):
			fail("drops.json: '%s' is in both berry_yield and harvest_yield" % key)

	# Harvest per plant beyond berries (drops.json harvest_yield): same shape, and a harvest takes at most 3 pack slots.
	for key in drops.get("harvest_yield", {}):
		var harvest: Dictionary = drops["harvest_yield"][key]
		var harvest_id: String = String(harvest.get("item", ""))

		if not species.has(key):
			fail("drops.json harvest_yield: unknown flora species '%s'" % key)

		want_item.call(harvest_id, "drops.json harvest_yield.%s" % key)
		var harvest_stack: int = maxi(1, int(gathered_file.get("items", {}).get(harvest_id, items_file.get("items", {}).get(harvest_id, {})).get("stack", 1)))

		if int(harvest.get("count", 0)) < 1 or ceili(float(harvest.get("count", 0)) / float(harvest_stack)) > 3:
			fail("drops.json harvest_yield.%s: count must be 1 or more and fit 3 slots (%s stacks to %d)" % [key, harvest_id, harvest_stack])

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

	# Stations: a recipe's station is a placed structure with that station, or one of the stations still to be built.
	var stations: Dictionary = {"saw_mill": true, "forge": true, "campfire": true}   # a lit campfire is a station for dishes

	for kind in _read("structures.json").get("structures", {}):
		if String(_read("structures.json")["structures"][kind].get("station", "")) != "":
			stations[String(_read("structures.json")["structures"][kind]["station"])] = true

	for recipe_id in recipes_file.get("recipes", {}):
		var station: String = String(recipes_file["recipes"][recipe_id].get("station", ""))

		if station != "" and not stations.has(station):
			fail("recipes.json %s: unknown station '%s'" % [recipe_id, station])

	# Fishing: every catch and bait is an item, and the catches are obtainable (by fishing).
	var fishing: Dictionary = _read("fishing.json")

	for water in fishing.get("species", {}):
		for row in fishing["species"][water]:
			want_item.call(String(row[0]), "fishing.json %s" % water)
			obtainable[String(row[0])] = true

	# Hunting: every part a carcass can give is obtainable (by hunting and working the carcass).
	for species_id in _read("carcass.json").get("species", {}):
		for row in _read("carcass.json")["species"][species_id].get("parts", []):
			want_item.call(String(row[0]), "carcass.json %s" % species_id)
			obtainable[String(row[0])] = true

	# Cooking.
	want_item.call(String(cooking.get("gives", "")), "cooking.json gives")
	obtainable[String(cooking.get("gives", ""))] = true

	for raw_id in cooking.get("cooks_into", {}):
		want_item.call(String(raw_id), "cooking.json cooks_into")
		want_item.call(String(cooking["cooks_into"][raw_id]), "cooking.json cooks_into")

	for raw_id in cooking.get("raw_sick", {}).get("by_id", {}):
		want_item.call(String(raw_id), "cooking.json raw_sick")

	var carcass: Dictionary = _read("carcass.json")

	for animal in carcass.get("species", {}):
		for part in carcass["species"][animal].get("parts", []):
			want_item.call(String(part[0]), "carcass.json %s" % animal)

			if int(part[1]) < 0 or int(part[2]) < int(part[1]):
				fail("carcass.json %s: %s has a bad range" % [animal, part[0]])

	# Skills: every action names a skill, every skill's parent and attributes exist.
	var skills_cfg: Dictionary = _read("skills.json")
	var skill_defs: Dictionary = skills_cfg.get("skills", {})

	for action in skills_cfg.get("actions", {}):
		if not skill_defs.has(String(skills_cfg["actions"][action].get("skill", ""))):
			fail("skills.json: action '%s' names an unknown skill" % action)

	for problem in SkillWebCheck.validate(skills_cfg):
		fail("skills.json: %s" % str(problem))

	# Spoilage: every perishable name exists, and the rotten item is what rot makes.
	var spoilage: Dictionary = _read("spoilage.json")
	want_item.call(String(spoilage.get("rotten_item", "")), "spoilage.json rotten_item")
	obtainable[String(spoilage.get("rotten_item", ""))] = true

	for id in spoilage.get("by_id", {}):
		want_item.call(String(id), "spoilage.json by_id")

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

		# Ingredients (DESIGN_IDEAS 5.3, Dave 2026-10-21): three-ingredient hand recipes stay, and later recipes take four or more;
		# the more ingredients, the better the item. So there is no rule below MAX_INGREDIENTS, only an info line.
		if String(r.get("station", "")) == "" and bool(r.get("known", false)) and r.get("needs", []).size() > 2:
			print("info: recipes.json %s: a hand recipe with %d ingredients" % [rid, r["needs"].size()])

		for id in r.get("identify", []):
			want_item.call(String(id), "recipe '%s' identify" % rid)

		for list in ["needs", "keeps"]:
			for row in r.get(list, []):
				want_item.call(String(row[0]), "recipe '%s' %s" % [rid, list])

				if int(row[1]) < 1:
					fail("recipe '%s' %s: amount below 1" % [rid, list])

		if (r.get("needs", []) as Array).size() > MAX_INGREDIENTS:
			fail("recipe '%s': recipes have at most %d ingredient kinds (raise MAX_INGREDIENTS and the craft screen's rows together)" % [rid, MAX_INGREDIENTS])

		want_item.call(String(r.get("gives", [""])[0]), "recipe '%s' gives" % rid)

	if int(recipes_file.get("next_number", 0)) <= highest_recipe:
		fail("recipes.json: next_number is not above the highest recipe number")

	# The hand saw sits between the axe and the sawmill (Tyler, tools batch 1): its recipe must match the balance row at the top of recipes.json.
	var balance: Dictionary = recipes_file.get("hand_saw_balance", {})

	if not balance.is_empty():
		var by_hand: Dictionary = recipes_file["recipes"].get("lumber_by_hand", {})
		var saw_row: Dictionary = balance.get("hand_saw", {})
		var mill_row: Dictionary = balance.get("sawmill", {})
		var mill_recipe: Dictionary = recipes_file["recipes"].get("lumber", {})

		if by_hand.is_empty() or int(by_hand["gives"][1]) != int(saw_row.get("lumber_per_log", -1)) or absf(float(by_hand.get("craft_s", 0.0)) - float(saw_row.get("craft_s", -1.0))) > 0.001:
			fail("recipes.json: lumber_by_hand does not match hand_saw_balance.hand_saw")

		if int(mill_recipe.get("gives", ["", 0])[1]) != int(mill_row.get("lumber_per_log", -1)) or absf(float(mill_recipe.get("craft_s", 0.0)) - float(mill_row.get("craft_s", -1.0))) > 0.001:
			fail("recipes.json: lumber does not match hand_saw_balance.sawmill")

		if int(saw_row.get("lumber_per_log", 0)) >= int(mill_row.get("lumber_per_log", 0)) or float(saw_row.get("craft_s", 0.0)) <= float(mill_row.get("craft_s", 0.0)):
			fail("recipes.json: the hand saw must give less and take longer than the sawmill")

	for rid in recipes_file["recipes"]:
		var wt: String = String(recipes_file["recipes"][rid].get("wears_tool", ""))
		var wt_ok: bool = wt == ""

		for row in recipes_file["recipes"][rid].get("keeps", []):
			wt_ok = wt_ok or String(items_file["items"].get(String(row[0]), {}).get("tool_class", "")) == wt

		if not wt_ok:
			fail("recipe '%s': wears_tool '%s' is not the tool_class of any kept tool" % [rid, wt])

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
			if String(def.get("kit", "")) != "" or not bool(def.get("walkover", false)):
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

		if def.has("blocks_per_log"):   # a log struck with an axe falls apart into wooden blocks
			obtainable["wooden_block"] = true

		if def.has("blocks_per_log"):   # softwood logs give the softwood block and its firewood (wood_species.json class_items)
			for cls in wood_file.get("class_items", {}):
				for step in wood_file["class_items"][cls]:
					obtainable[String(wood_file["class_items"][cls][step])] = true

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

	# data/items/looks.json (client-only, Kathleen's data-driven item models): every key is a real item and every look has shape, colour and size.
	if FileAccess.file_exists("res://data/items/looks.json"):
		var looks: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/looks.json"))
		var basic_source: String = FileAccess.get_file_as_string("res://src/client/basic_look.gd")

		if typeof(looks) != TYPE_DICTIONARY:
			fail("looks.json is not a JSON object")
		else:
			var entries: Dictionary = looks.get("items", looks) if looks.get("items") is Dictionary else looks

			for id in entries:
				if String(id).begins_with("_") or String(id) == "note":
					continue

				if not items_file.get("items", {}).has(id) and not gathered_file.get("items", {}).has(id):
					fail("looks.json: '%s' is not an item in items.json or gathered.json" % id)
					continue

				var look: Variant = entries[id]

				if typeof(look) != TYPE_DICTIONARY or typeof(look.get("shape", null)) != TYPE_STRING or not look.has("color") or float(look.get("size", 0.0)) <= 0.0:
					fail("looks.json: '%s' needs shape (text), color and size (a number above 0)" % id)
				elif basic_source.find("\t\t\"%s\":" % String(look["shape"])) < 0:
					fail("looks.json: '%s' names an unknown shape '%s' (not in basic_look.gd)" % [id, look["shape"]])

			# Goal 1c: the GENERIC count. Every loose material, food, medicine, clothing, gear, coin or weapon item has a look unless it is drawn by its own model (logs, stone, stick, driftwood).
			var generic: Array = []

			for table_file in [items_file, gathered_file]:
				for id in table_file.get("items", {}):
					var kind: String = String(table_file["items"][id].get("kind", ""))
					var own_model: bool = String(id) in ["stone", "stick", "log", "driftwood"] or String(id).begins_with("log_")

					if kind in ["material", "food", "medicine", "clothing", "gear", "coin", "weapon"] and not own_model and not entries.has(id):
						generic.append(String(id))

			print("looks: %d GENERIC items remaining%s" % [generic.size(), (" (" + ", ".join(generic) + ")") if generic.size() > 0 else ""])

			if generic.size() > 0:
				fail("%d items have no looks.json row (run tools/gen_looks.py): %s" % [generic.size(), ", ".join(generic)])

	# data/items/worn.json (goal 1f): every item with a body slot has a row, every row names a real item and a known builder.
	if FileAccess.file_exists("res://data/items/worn.json"):
		var worn: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/worn.json"))
		var worn_source: String = FileAccess.get_file_as_string("res://src/client/worn_look.gd")

		if typeof(worn) != TYPE_DICTIONARY or not (worn.get("items") is Dictionary):
			fail("worn.json is not an object with items")
		else:
			var rows: Dictionary = worn["items"]

			for id in rows:
				if not items_file.get("items", {}).has(id):
					fail("worn.json: '%s' is not an item in items.json" % id)
				elif worn_source.find("\t\t\"%s\":" % String(rows[id].get("builder", ""))) < 0:
					fail("worn.json: '%s' names an unknown builder '%s'" % [id, rows[id].get("builder", "")])

			for id in items_file.get("items", {}):
				var slot: String = String(items_file["items"][id].get("slot", ""))

				if slot in ["head", "body", "legs", "feet", "hands", "back"] and not rows.has(id):
					fail("items.json: '%s' has body slot '%s' but no worn.json row" % [id, slot])

	# data/npcs/outfits.json: every id an NPC outfit names has a worn.json row (worn_sync skips unknown ones, this catches the typo).
	if FileAccess.file_exists("res://data/npcs/outfits.json") and FileAccess.file_exists("res://data/items/worn.json"):
		var outfits: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/outfits.json"))
		var worn_rows: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/worn.json"))
		var wearable: Dictionary = worn_rows.get("items", {}) if typeof(worn_rows) == TYPE_DICTIONARY else {}

		if typeof(outfits) != TYPE_DICTIONARY:
			fail("outfits.json is not an object")
		else:
			for outfit in outfits:
				if str(outfit).begins_with("_"):
					continue

				for id in outfits[outfit]:
					if not wearable.has(id):
						fail("outfits.json: outfit '%s' wears '%s', which has no worn.json row" % [outfit, id])

	print("items: %d core, %d gathered, %d recipes" % [items_file.get("items", {}).size(), gathered_file.get("items", {}).size(), recipes.size()])
	print("item validator: %d errors, %d warnings" % [errors, warnings])
	quit(1 if errors > 0 else 0)
