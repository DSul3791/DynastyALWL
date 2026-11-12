extends SceneTree

const SkillWebCheck := preload("res://src/shared/skill_web.gd")
const RecipeFilter := preload("res://src/client/recipe_filter.gd")

# Item data validator: items.json, gathered.json, recipes.json, drops.json, cooking.json.
# Checks numbers, unknown ids, orphan core items and recipes that can never be made.
#   godot --headless --path . --script res://src/worldgen/tools/validate_items.gd
# Exit code 1 when there are errors (warnings do not fail it).

const DATA := "res://data/items/"
# Items the code itself hands out (a carcass is made when an animal dies; felling a trunk, the admin give, placing a fire) and so need no drop entry.
# Names of items and recipes are plain nouns (Dave 2026-10-20): "Basic torch", "Stone axe", never "Carve a ..." or "Make a ...".
const VERB_FIRST_WORDS := ["make", "carve", "chisel", "bind", "craft", "build", "tie", "knap", "twist", "weave", "split", "place", "roast", "cook", "dig", "cut", "sharpen", "light", "pick", "gather", "get", "use", "create", "forge", "fashion", "shape", "stack", "lay", "set", "form"]
const CODE_SOURCES := ["stone", "stick", "bark", "leaves", "seed_bundle", "firewood", "driftwood", "sea_water", "torch_doused", "wooden_lantern_dark", "iron_lantern_dark"]   # torch_doused: rain or water puts a lit torch out (#361); a lantern goes dark under water or when its fuel burns out (buildables plan B4)

const MAX_INGREDIENTS := 6   # the craft screen lists every ingredient in a scrolling detail area and the server crafts any count (test_server_items); raise further here only

const DAVE_NAMES := ["Roast beast", "Roast meat", "Roast fish", "Roast roots"]   # names Dave chose himself (2026-10-22): they read like a verb and are the real name
const ADJECTIVE_NAMES := ["Light crossbow", "Light draft harness", "Light cargo cart", "Roast platter"]   # "Light" and "Roast" here are adjectives, not verbs (catalog Draft 18, decision 71 forms)

const RECIPE_CATEGORIES := RecipeFilter.CATEGORIES
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

	if name in DAVE_NAMES or name in ADJECTIVE_NAMES:
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

	# items.json and gathered.json share one number space (Mission 001: new catalog rows from 1000 met the gathered materials): each file's
	# next_number must be above every number in either file, so neither can hand out a number the other uses.
	for pair in [[items_file, "items.json"], [gathered_file, "gathered.json"]]:
		if not numbers.is_empty() and int(pair[0].get("next_number", 0)) <= int(numbers.keys().max()):
			fail("%s: next_number %s is not above the highest number in items.json and gathered.json (%d)" % [pair[1], pair[0].get("next_number"), int(numbers.keys().max())])

	# Every structure has its own world-item state (the client finds the structure of a row by its state): two with the same state made the plank chest (6) shadow the
	# woven chest, so the chest could not be placed (31 Oct 2026, the chest client self-test).
	var states_seen: Dictionary = {}

	for sid in _read("structures.json").get("structures", {}):
		var srow: Variant = _read("structures.json")["structures"][sid]

		if typeof(srow) == TYPE_DICTIONARY and srow.has("state"):
			if states_seen.has(int(srow["state"])):
				fail("structures.json: state %d is used by '%s' and '%s'" % [int(srow["state"]), states_seen[int(srow["state"])], sid])

			states_seen[int(srow["state"])] = sid

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

	for gid in gathered_file.get("items", {}):   # gathered materials stack without limit, so every one needs a real weight
		var gweighed: bool = weights.get("by_id", {}).has(gid)

		for gsuffix in weights.get("by_suffix", {}):
			gweighed = gweighed or String(gid).ends_with(String(gsuffix))

		if not gweighed:
			fail("weights.json: stackable gathered item '%s' has no weight (by_id or by_suffix); stacks have no cap now, weight is the limit" % gid)


	# Every wood class names a firewood item and a block item that exist (wood_species.json class_items).
	var wood_file: Dictionary = _read("wood_species.json")

	for gid in wood_file.get("ingredient_groups", {}):   # a group (plain "log") is obtainable when a member is (F-16: no server fallback gives the plain item)
		if String(gid) != "note":
			obtainable[String(gid)] = true

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

		# Mission 001 (master s2.3 item 6): species lumber and beams are retired; a key wood keeps its live log, and its class's sawn product
		# (Plank for softwood, Hardwood board for hardwood) is live.
		var key_log: Dictionary = items_file.get("items", {}).get("log_" + str(key_wood), {})

		if key_log.is_empty() or bool(key_log.get("retired", false)):
			fail("wood_species.json: key wood %s needs a live log_%s item" % [key_wood, key_wood])

		var sawn: String = "hardwood_board" if String(wood_file.get("species", {}).get(String(key_wood), {}).get("class", "")) == "hardwood" else "lumber"
		var sawn_item: Dictionary = items_file.get("items", {}).get(sawn, {})

		if sawn_item.is_empty() or bool(sawn_item.get("retired", false)) or bool(sawn_item.get("future", false)):
			fail("wood_species.json: key wood %s needs its live sawn product %s" % [key_wood, sawn])

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

	for ref in JSON.stringify(_read("drops.json")).split("\""):
		if retired_ids.has(ref):
			fail("drops.json names the retired item %s" % ref)

	# A structure's "kit" is the id the code knows the piece by (placing, taking down, blueprint lookup, old saves),
	# so it may name a retired kit item: since #292 no kit is crafted and the hammer blueprints build the pieces.
	# Every other field of structures.json must name live items.
	var structures_top: Dictionary = _read("structures.json")
	var structure_defs: Dictionary = structures_top.get("structures", {})
	var top_no_defs: Dictionary = structures_top.duplicate(true)
	top_no_defs.erase("structures")

	for ref in JSON.stringify(top_no_defs).split("\""):
		if retired_ids.has(ref):
			fail("structures.json names the retired item %s" % ref)

	for kind in structure_defs:
		if bool(structure_defs[kind].get("retired", false)):   # a retired piece (the Woodworking table, Mission 001) keeps its row for its state number only
			continue

		var def_no_kit: Dictionary = structure_defs[kind].duplicate(true)
		def_no_kit.erase("kit")
		def_no_kit.erase("takes_kinds")   # items.json kinds, not item ids ("medicine" is also a retired item id); checked below

		for ref in JSON.stringify(def_no_kit).split("\""):
			if retired_ids.has(ref):
				fail("structures.json %s names the retired item %s" % [kind, ref])

	var no_key: Array = []

	for biome in biome_any:
		if not biome_key.has(biome):
			no_key.append(biome)

	no_key.sort()
	print("info: biomes whose trees include no key wood (they give firewood and sticks only): ", ", ".join(no_key))

	# The stations live structures serve (their own station or "also"): a repair_station must be one, or the tool could never be mended.
	var served: Dictionary = {}

	for kind in structure_defs:
		if not bool(structure_defs[kind].get("retired", false)):
			served[String(structure_defs[kind].get("station", ""))] = true

			for also in structure_defs[kind].get("also", {}):
				served[String(also)] = true

	for id in items_file.get("items", {}):
		var item: Dictionary = items_file["items"][id]
		var description: String = String(item.get("description", ""))

		if bool(item.get("offhand", false)) and (not ["tool", "weapon"].has(String(item.get("kind", ""))) or not ["torch", "torch_doused", "lantern", "lantern_dark", "shield"].has(String(item.get("tool_class", "")))):
			fail("items.json: '%s' is marked offhand but is not a tool or weapon of class torch, lantern or shield (the left-hand models)" % id)

		if item.has("pile"):   # bulk items drawn as a pile on the ground (PileLook) and taken by the handful
			var pile: Dictionary = item["pile"]
			var tint: Array = pile.get("color", [])

			if String(pile.get("shape", "")) == "logs":   # split firewood and wooden blocks: a stack of log pieces (PileLook._logs_mesh)
				if int(pile.get("handful", 0)) < 1 or tint.size() != 3 or float(pile.get("len", 0.0)) <= 0.0 or float(pile.get("radius", 0.0)) <= 0.0:
					fail("items.json: '%s' logs pile row needs handful 1 or more, color [r, g, b] (bark), len and radius above 0" % id)
			elif not ["pyramid", "mound"].has(String(pile.get("shape", ""))) or int(pile.get("handful", 0)) < 1 or tint.size() != 3 or float(pile.get("rock", 0.0)) <= 0.0 or float(pile.get("squash", 0.0)) <= 0.0:
				fail("items.json: '%s' pile row needs shape pyramid, mound or logs, handful 1 or more, color [r, g, b], rock and squash above 0 (logs: len and radius)" % id)

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

		# No stack caps (Dave 24 Oct): weight is the only limit, so a stackable item must have a real weight and tools, kits, structures, containers, clothing, gear and weapons must not stack.
		if int(item.get("stack", 1)) == 1 and not bool(item.get("unstackable", false)) and not bool(item.get("retired", false)):
			fail("items.json: '%s' has stack 1 but is not marked \"unstackable\": true" % id)

		if ["tool", "weapon", "placeable", "structure", "container", "clothing", "gear"].has(String(item.get("kind", ""))) and not bool(item.get("unstackable", false)):
			fail("items.json: '%s' is a %s and must be \"unstackable\": true" % [id, item.get("kind", "")])

		if item.has("durability") and int(item["durability"]) < 1:
			fail("items.json: '%s' has a durability below 1" % id)

		# Master s2.2: stone, wooden and primitive gear is disposable (no repair); a metal tool is repaired at the station type that makes it.
		if String(item.get("kind", "")) == "tool" and ["bronze", "iron", "steel"].has(String(item.get("material", ""))) and item.has("durability") and not bool(item.get("retired", false)) and (item.get("repair", []).is_empty() or String(item.get("repair_station", "")) == ""):
			fail("items.json: metal tool '%s' needs repair materials and a repair_station" % id)

		# Catalog Phase 2c code (src/shared/smithing_rules.gd): a row with durability and no repair is disposable, gone when it breaks; any
		# other is mended at its repair_station; an edge dulls against the row's durability and is sharpened, so it needs a repairable row (s2.2 rule 8).
		if String(item.get("repair_station", "")) != "" and not served.has(String(item["repair_station"])):
			fail("items.json: '%s' repair_station '%s' is no live structure's station" % [id, item["repair_station"]])

		if String(item.get("repair_station", "")) != "" and item.get("repair", []).is_empty():
			fail("items.json: '%s' has a repair_station but no repair materials" % id)

		if bool(item.get("edge", false)) and (int(item.get("durability", 0)) < 1 or item.get("repair", []).is_empty()):
			fail("items.json: '%s' has an edge but no durability or repair (only repairable tools are sharpened)" % id)

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
		obtainable[harvest_id] = true   # a harvest row (fruit trees included) is a source
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

	# Wild seeds: gathering a listed plant in season also gives seeds (drops.json seed_drops).
	var seed_drops: Dictionary = drops.get("seed_drops", {})

	for key in seed_drops:
		if typeof(seed_drops[key]) != TYPE_DICTIONARY:
			continue

		for row in seed_drops[key].get("rows", []):
			want_item.call(String(row[0]), "drops.json seed_drops.%s" % key)
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

	# Bushes and shrubs (Dave 2 Nov 2026): the axe chops them into axe_gives; the pickaxe digs each shrub species up whole as <species><dig_suffix>.
	var shrub_work: Dictionary = drops.get("shrub_work", {})

	for row in shrub_work.get("axe_gives", []):
		want_item.call(String(row[0]), "drops.json shrub_work.axe_gives")
		obtainable[String(row[0])] = true

	if shrub_work.has("dig_suffix"):
		for entry in _read("../tables/flora.json").get("entries", []):
			if String(entry.get("kind", "")) == "shrub":
				var dug: String = String(entry["name"]) + String(shrub_work["dig_suffix"])
				want_item.call(dug, "drops.json shrub_work.dig_suffix (%s)" % entry["name"])
				obtainable[dug] = true

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

		for find in digging.get("finds", []):   # a chance per dig stroke of a thing living in the soil (a worm in moist living soil)
			want_item.call(String(find.get("item", "")), "digging.json finds")
			obtainable[String(find.get("item", ""))] = true

			for material in find.get("soils", []):
				if not soil_names.has(String(material)):
					fail("digging.json finds %s: unknown ground material '%s'" % [find.get("item", ""), material])

		# Bog iron (Sonny s11, src/shared/bog_iron.gd): a spade dig on a deposit under a fen, marsh, swamp or bog sample gives this item.
		var bog: Dictionary = digging.get("bog_iron", {})

		if not bog.is_empty():
			want_item.call(String(bog.get("item", "")), "digging.json bog_iron")
			obtainable[String(bog.get("item", ""))] = true

			if float(bog.get("chance", 0.0)) <= 0.0 or float(bog.get("chance", 0.0)) * float(bog.get("edge_mult", 1.0)) > 1.0:
				fail("digging.json bog_iron: chance x edge_mult must be above 0 and at most 1")

			for cls in bog.get("classes", {}):
				if not String(cls) in ["4", "6", "7", "8"]:
					fail("digging.json bog_iron: class %s is not fen 7, marsh 4, swamp 6 or bog 8 (no iron under salt marsh, rivers, lakes, the sea or seasonal water)" % cls)

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

	# Felling (server_items.gd _log_number): a felled tree gives its own log_<species>, or the plain Log when that item is missing or retired.
	for entry in _read("../tables/flora.json").get("entries", []):
		if String(entry.get("kind", "")) == "tree":
			var felled_log: String = "log_" + String(entry["name"])

			if all.has(felled_log) and not bool(all[felled_log].get("retired", false)):
				obtainable[felled_log] = true
			else:
				obtainable["log"] = true

	# Farming (crops.json): a sown seed grows into its yields and gives seeds back (server_items.gd tilled beds).
	var crops_file: Dictionary = _read("crops.json")

	for crop_id in crops_file.get("crops", {}):
		var crop: Dictionary = crops_file["crops"][crop_id]

		for row in crop.get("yields", []):
			want_item.call(String(row[0]), "crops.json %s yields" % crop_id)
			obtainable[String(row[0])] = true

		if crop.has("seeds_back"):
			want_item.call(String(crop["seeds_back"][0]), "crops.json %s seeds_back" % crop_id)
			obtainable[String(crop["seeds_back"][0])] = true

	# Skill hooks: every action names a skill and an effect the code knows.
	for action in _read("skills.json").get("actions", {}):
		var def: Dictionary = _read("skills.json")["actions"][action]

		if String(def.get("skill", "")) == "" or not String(def.get("effect", "")) in ["yield", "speed", "toughness", "quiet"]:   # quiet: less noise (stalk, server_animals brush noise)
			fail("skills.json: action '%s' needs a skill name and an effect of yield, speed, toughness or quiet" % action)

	# smithing.json (catalog Phase 2c): its whetstone is an item, its grindstone, Master smithy and Smithy are stations and the temper add-on a structure.
	var smithing: Dictionary = _read("smithing.json")

	if not items_file.get("items", {}).has(String(smithing.get("whetstone", {}).get("item", ""))):
		fail("smithing.json whetstone.item is not an item")

	for station_ref in [smithing.get("grindstone", {}).get("station", ""), smithing.get("craft", {}).get("station", ""), smithing.get("temper", {}).get("station", "")]:
		if not served.has(String(station_ref)):
			fail("smithing.json names the station '%s' that no live structure serves" % station_ref)

	if not structure_defs.has(String(smithing.get("temper", {}).get("addon", ""))):
		fail("smithing.json temper.addon is not a structure")

	# Tempered (s4 item 15): every steel weapon and armour row (a "Steel - " weapon or clothing row, unstackable) is listed in temper.include,
	# since those rows carry no material; every listed id is an item.
	var temper_include: Array = smithing.get("temper", {}).get("include", [])

	for include_id in temper_include:
		if not items_file.get("items", {}).has(String(include_id)):
			fail("smithing.json temper.include names '%s', which is not an item" % include_id)

	for id in items_file.get("items", {}):
		var steel_row: Dictionary = items_file["items"][id]

		if String(steel_row.get("name", "")).begins_with("Steel - ") and ["weapon", "clothing"].has(String(steel_row.get("kind", ""))) and bool(steel_row.get("unstackable", false)) and not bool(steel_row.get("retired", false)) and not temper_include.has(id) and String(steel_row.get("material", "")) != "steel":
			fail("smithing.json temper.include lacks the steel weapon or armour row '%s' (s4 item 15)" % id)

	if (smithing.get("craft", {}).get("materials", []) as Array).size() != 3 or (smithing.get("craft", {}).get("time", []) as Array).size() != 3:
		fail("smithing.json craft.materials and craft.time need three factors (plain, +1, +2)")

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

	# Fish schools (fish_schools.json species_by_kind): river, lake, pond and sea fish that exist as items are caught from a school (Sal, 2026-10-31).
	var schools: Dictionary = _read("fish_schools.json")

	for kind in schools.get("species_by_kind", {}):
		for row in schools["species_by_kind"][kind]:
			if all.has(String(row[0])):
				obtainable[String(row[0])] = true

	# Boulders (boulders.json): ore and coal from outcrop boulders and flint nodules are picked up with a pick or an axe (guide F-02, F-23).
	var boulders: Dictionary = _read("boulders.json")

	for ore_name in boulders.get("ore", {}).get("items", {}):
		var ore_item: String = String(boulders["ore"]["items"][ore_name])

		if all.has(ore_item):
			obtainable[ore_item] = true

	# Bedrock boulders (Steve, #965): a boulder over a rock in ore.rocks (limestone, chalk, marble) gives that item to a pick.
	for rock_name in boulders.get("ore", {}).get("rocks", {}):
		var rock_item: String = String(boulders["ore"]["rocks"][rock_name])

		if all.has(rock_item):
			obtainable[rock_item] = true
		else:
			fail("boulders.json ore.rocks.%s: unknown item '%s'" % [rock_name, rock_item])

	if all.has(String(boulders.get("flint", {}).get("item", ""))):
		obtainable[String(boulders["flint"]["item"])] = true

	# Tide-line nodes (shore_nodes.json): seaweed, shellfish, crab meat and eggs are gathered at the shore; sea water fills a container (Tyler, WATER_GATHER_SPEC.md).
	var shore: Dictionary = _read("shore_nodes.json")

	for node in shore.get("nodes", []):
		if all.has(String(node.get("item", ""))):
			obtainable[String(node["item"])] = true

	if all.has(String(shore.get("sea_water_item", ""))):
		obtainable[String(shore["sea_water_item"])] = true

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

	# A stack's age is a u16 in tenths of a game hour (inventory.gd to_bytes): a shelf life past it never rots (master s3.14 wear cap).
	var shelf_cap_h: float = 65535.0 * float(spoilage.get("unit_h", 0.1)) / float(spoilage.get("gentle_mult", 1))

	for list in ["by_id", "by_suffix"]:
		for id in spoilage.get(list, {}):
			if float(spoilage[list][id]) > shelf_cap_h:
				fail("spoilage.json %s %s: %s game hours x gentle_mult %s passes the wear cap (at most %.1f)" % [list, id, str(spoilage[list][id]), str(spoilage.get("gentle_mult", 1)), shelf_cap_h])

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

		if not RECIPE_CATEGORIES.has(String(r.get("category", ""))):   # the craft menu's category tabs (Dave 25 Oct)
			fail("recipes.json: recipe '%s' has category '%s', not one of %s" % [rid, String(r.get("category", "")), str(RECIPE_CATEGORIES)])

		# Ingredients (DESIGN_IDEAS 5.3, Dave 2026-10-21): three-ingredient hand recipes stay, and later recipes take four or more;
		# the more ingredients, the better the item. So there is no rule below MAX_INGREDIENTS, only an info line.
		if String(r.get("station", "")) == "" and bool(r.get("known", false)) and r.get("needs", []).size() > 2:
			print("info: recipes.json %s: a hand recipe with %d ingredients" % [rid, r["needs"].size()])

		for id in r.get("identify", []):
			want_item.call(String(id), "recipe '%s' identify" % rid)

		# A sealed batch (master s3.14): its output spoils, and only after it is Ready (ready_age game hours, unscaled, under the stretched shelf life).
		if float(r.get("ready_age", 0.0)) > 0.0:
			var made_id: String = String(r.get("gives", [""])[0])
			var shelf_h: float = float(spoilage.get("by_id", {}).get(made_id, 0.0)) * float(spoilage.get("gentle_mult", 1))

			if float(r["ready_age"]) >= shelf_h:
				fail("recipes.json %s: ready_age %s must be under the shelf life of %s (%.0f game hours)" % [rid, str(r["ready_age"]), made_id, shelf_h])

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

		# Master s2.3 item 1 (Dave [D1]): the hand saw gives what the sawmill gives, much more slowly; Hardwood boards follow the same rule.
		if int(saw_row.get("lumber_per_log", 0)) != int(mill_row.get("lumber_per_log", 0)) or float(saw_row.get("craft_s", 0.0)) <= float(mill_row.get("craft_s", 0.0)):
			fail("recipes.json: the hand saw must give what the sawmill gives and take longer")

		for pair in [["hardwood_board", mill_row], ["hardwood_board_by_hand", saw_row]]:
			var board_recipe: Dictionary = recipes_file["recipes"].get(String(pair[0]), {})

			if board_recipe.is_empty() or int(board_recipe["gives"][1]) != int(pair[1].get("boards_per_log", -1)) or absf(float(board_recipe.get("craft_s", 0.0)) - float(pair[1].get("craft_s", -1.0))) > 0.001:
				fail("recipes.json: %s does not match hand_saw_balance" % pair[0])

	# No substitution [D4]: Planks come only from softwood logs and Hardwood boards only from hardwood logs, and no group mixes the two.
	var wood_groups: Dictionary = wood_file.get("ingredient_groups", {})
	var soft_logs: Array = [String("log_spruce")] + Array(wood_groups.get("log_spruce", []))
	var hard_logs: Array = [String("log_oak")] + Array(wood_groups.get("log_oak", []))

	for id in soft_logs:
		if hard_logs.has(id):
			fail("wood_species.json: %s is both a softwood and a hardwood log" % id)

	# Each log group's species chop and burn as their class (a species with no row takes the default class, softwood).
	var species_rows: Dictionary = wood_file.get("species", {})

	for pair in [[soft_logs, "softwood"], [hard_logs, "hardwood"]]:
		for id in pair[0]:
			var sp: String = String(id).trim_prefix("log_") if String(id) != "log" else ""
			var cls: String = String(species_rows.get(sp, wood_file.get("default", {})).get("class", ""))

			if cls != String(pair[1]):
				fail("wood_species.json: %s is in the %s log group but its class is %s" % [id, pair[1], cls])

	for gid in wood_groups:
		if typeof(wood_groups[gid]) == TYPE_ARRAY:
			var members: Array = [String(gid)] + Array(wood_groups[gid])

			if members.has("lumber") and members.has("hardwood_board"):
				fail("wood_species.json: group %s mixes Planks and Hardwood boards" % gid)

	for rid in recipes_file["recipes"]:
		var wt: String = String(recipes_file["recipes"][rid].get("wears_tool", ""))
		var wt_ok: bool = wt == ""

		for row in recipes_file["recipes"][rid].get("keeps", []):
			for kept in [String(row[0])] + Array(wood_file.get("ingredient_groups", {}).get(String(row[0]), [])):   # a kept group (saw) counts by its members
				wt_ok = wt_ok or String(items_file["items"].get(kept, {}).get("tool_class", "")) == wt

		if not wt_ok:
			fail("recipe '%s': wears_tool '%s' is not the tool_class of any kept tool" % [rid, wt])

	# Core materials marked "future": true (iron and steel ingots until smelting exists) count as sources for the recipe check.
	for id in items_file.get("items", {}):
		if bool(items_file["items"][id].get("future", false)) and String(items_file["items"][id].get("kind", "")) in ["material", "food"]:   # future foods (shore foods, crops) count too, so dishes built from them are checked
			obtainable[String(id)] = true

	# A log struck with an axe falls apart into wooden blocks (structures.json blocks_per_log), so blocks count as a source for recipes.
	for kind in _read("structures.json").get("structures", {}):
		if _read("structures.json")["structures"][kind].has("blocks_per_log"):
			obtainable["wooden_block"] = true

			for cls in wood_file.get("class_items", {}):   # softwood logs give softwood blocks, big logs large blocks (wood_species.json class_items)
				for step in wood_file["class_items"][cls]:
					obtainable[String(wood_file["class_items"][cls][step])] = true

	# What a fire cooks (cooking.json cooks_into) is obtainable when the raw item is.
	for raw_id in cooking.get("cooks_into", {}):
		if obtainable.has(String(raw_id)):
			obtainable[String(cooking["cooks_into"][raw_id])] = true

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

		# Storage rules (master s3.13, Mission 001 phase 9): a code lock only on a container, what it takes names real items or kinds, a view has a radius.
		if def.has("lockable") and (typeof(def["lockable"]) != TYPE_BOOL or int(def.get("slots", 0)) <= 0 or bool(def.get("take_only", false))):
			fail("structures.json %s: lockable must be true or false, and only on a container with slots" % kind)

		for take in def.get("takes", []):
			if not items_file["items"].has(String(take)) or bool(items_file["items"][String(take)].get("retired", false)):
				fail("structures.json %s: takes '%s', which is not a live item or group" % [kind, take])

		for take_kind in def.get("takes_kinds", []):
			if not String(take_kind) in ["tool", "weapon", "material", "clothing", "gear", "container", "medicine", "food", "coin", "placeable", "structure"]:
				fail("structures.json %s: takes_kinds '%s' is not an items.json kind" % [kind, take_kind])

		if String(def.get("use", "")) == "storage_view" and (float(def.get("view_m", 0.0)) <= 0.0 or int(def.get("slots", 0)) > 0):
			fail("structures.json %s: a storage view needs view_m above 0 and holds nothing itself" % kind)
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

	# Ingredient groups (wood_species.json ingredient_groups, guide F-16): an id like plain "log" is filled by any member (log_oak ...). Each group needs
	# members that exist, and no recipe or blueprint may ask for an id nothing yields: not gathered, not made, not a group, not marked future.
	var groups: Dictionary = wood_file.get("ingredient_groups", {})

	for gid in groups:
		if String(gid) == "note":
			continue

		var members: Array = groups[gid]

		if members.is_empty():
			fail("wood_species.json ingredient_groups.%s has no members" % gid)

		for member in members:
			if not all.has(String(member)):
				fail("wood_species.json ingredient_groups.%s: unknown item '%s'" % [gid, member])

	var sourceless: Dictionary = {}

	for rid in recipes:
		if bool(recipes[rid].get("retired", false)):
			continue

		for list in ["needs", "keeps"]:
			for row in recipes[rid].get(list, []):
				var need_id: String = String(row[0])

				if groups.has(need_id) or obtainable.has(need_id) or craftable.has(need_id) or bool(all.get(need_id, {}).get("future", false)):
					continue

				sourceless[need_id] = rid

	for need_id in sourceless:
		fail("recipe '%s' needs '%s', which nothing yields (not gathered, not made, not a group, not marked future)" % [sourceless[need_id], need_id])

	# A player can never be asked to craft with something the game calls "Unknown" (Dave 24 Oct): an ingredient of a kit or twine recipe known from the start,
	# must be fully familiar.
	var gathered_items: Dictionary = gathered_file.get("items", {})
	var must_know: Dictionary = {}

	for rid in recipes:
		if bool(recipes[rid].get("known", false)) and (String(recipes[rid].get("gives", [""])[0]).ends_with("_kit") or String(recipes[rid].get("gives", [""])[0]) == "twine"):   # kits and twine; herbs and dishes are what inspection mode is for
			for row in recipes[rid].get("needs", []):
				must_know[String(row[0])] = true

	for id in must_know:
		var g_entry: Dictionary = gathered_items.get(id, {})

		if not g_entry.is_empty() and not (g_entry.get("look_alikes", []) as Array).is_empty() and int(g_entry.get("familiarity", 100)) < 100:
			fail("gathered.json: '%s' is an ingredient of a recipe known from the start but its familiarity is %d (it would read Unknown); add it to ALWAYS_KNOWN in tools/gen_gathered_items.py" % [id, int(g_entry.get("familiarity", 100))])

	var used: Dictionary = {}

	for rid in recipes:
		for list in ["needs", "keeps"]:
			for row in recipes[rid].get(list, []):
				used[String(row[0])] = true

	for id in cooking.get("fuel", {}):
		used[String(id)] = true

	used[String(cooking.get("tinder", ""))] = true

	for id in cooking.get("tinder_also", []):
		used[String(id)] = true

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

			var body_slots: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/clothing.json"))
			var slot_names: Array = body_slots.get("slots", []) if typeof(body_slots) == TYPE_DICTIONARY else []

			for id in items_file.get("items", {}):
				var slot: String = String(items_file["items"][id].get("slot", ""))

				if slot in slot_names and not rows.has(id):
					fail("items.json: '%s' has body slot '%s' but no worn.json row" % [id, slot])

	# Clothing layers (M001-T11, data/items/clothing.json): every item slot is a body slot; every clothing row names a wear_layer of its slot; spans
	# name other slots that have that layer; every fabric is a warmth.json layers fabric; the worn positions are each a slot's layer, once.
	var clothing_cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/clothing.json"))
	var warmth_cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/warmth.json"))

	if typeof(clothing_cfg) != TYPE_DICTIONARY or typeof(warmth_cfg) != TYPE_DICTIONARY:
		fail("clothing.json or warmth.json is not an object")
	else:
		var layers: Dictionary = clothing_cfg.get("layers", {})
		var places: Array = clothing_cfg.get("worn", [])
		var fabrics: Dictionary = warmth_cfg.get("layers", {}).get("fabrics", {})

		for slot in clothing_cfg.get("slots", []):
			for layer in layers.get(slot, []):
				if places.count("%s:%s" % [slot, layer]) != 1:
					fail("clothing.json: worn must list %s:%s once" % [slot, layer])

		if places.size() != Dictionary(layers).values().reduce(func(n, list): return n + (list as Array).size(), 0):
			fail("clothing.json: worn lists a position that is no slot's layer")

		for id in items_file.get("items", {}):
			var row: Dictionary = items_file["items"][id]
			var slot: String = String(row.get("slot", ""))

			if slot == "":
				continue

			if not layers.has(slot):
				fail("items.json: '%s' has slot '%s', not a clothing.json slot" % [id, slot])
				continue

			var layer: String = String(row.get("wear_layer", layers[slot][0]))

			if String(row.get("kind", "")) == "clothing" and not row.has("wear_layer"):
				fail("items.json: clothing '%s' has no wear_layer" % id)
			elif not (layers[slot] as Array).has(layer):
				fail("items.json: '%s' wear_layer '%s' is not a layer of %s" % [id, layer, slot])

			for other in row.get("spans", []):
				if not (layers.get(other, []) as Array).has(layer) or other == slot:
					fail("items.json: '%s' spans '%s', which has no %s layer" % [id, other, layer])

			if row.has("fabric") and not fabrics.has(String(row["fabric"])):
				fail("items.json: '%s' fabric '%s' is not a warmth.json layers fabric" % [id, row["fabric"]])

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
