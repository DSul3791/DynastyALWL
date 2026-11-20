extends SceneTree

# Wood system phase 4, the carving station, the knife's blueprints and the bows and benches (docs/design/TREE_WOOD_TOOLS_DESIGN.md s1.4, s1.6, s1.7, s6 W-6 to W-11, W-17; Dave 15 Nov 2026):
#   1. the Wood carving station is an item, a structure with station "carving_station" and a knife blueprint of 2 Wooden blocks, with a look under 300 triangles;
#   2. the bowl, Serving platter, Wooden - Quarterstaff, Wooden - Club, the Shortbow and the Longbow are carved at it keeping a knife, and are refused without it;
#   3. the Primitive bow is a by-hand craft (2 sticks, 2 plant fibre) with a weaker bow.json row and a lower durability than the Shortbow;
#   4. a blueprint row with "tool": "knife" is built with a knife in the hand bar and refused with only a hammer, and a hammer row the other way round;
#   5. the knife's list (hammer_blueprints.gd tool "knife") holds exactly the knife rows, the hammer's list none of them, and the knife list has no Save or plan lines;
#   6. the three log benches seat 1, 2 and 2 for their logs and twine, and the Log - Table costs 3 Logs and 2 Twine.
#   godot --headless --path . --script res://src/worldgen/tools/test_wood_phase4.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const BowScript := preload("res://src/stream/server_bow.gd")
const BowAim := preload("res://src/shared/bow_aim.gd")
const ListScript := preload("res://src/client/hammer_blueprints.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const LookTable := preload("res://src/client/look_table.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")   # the hand slot a craft holds its tool in (protocol 126)
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")

const NEAR_TRIANGLES := 300
# The blueprints a knife builds (W-9 and the three new benches and the station), by structure id.
const KNIFE_ROWS := ["log_seat", "stool", "bench", "crude_chair", "crude_table", "crude_chest", "wooden_shelf", "drying_rack", "tool_rack", "firewood_rack", "log_rack", "tanning_rack",
	"tailors_table", "food_preparation_table", "chest", "wicker_basket", "log_bench", "log_table", "log_double_bench", "log_backed_bench", "carving_station"]
# The recipes carved at the station (the Shortbow is wooden_bow, the Quarterstaff has no wooden prefix).
const CARVED := ["wooden_bowl", "serving_platter", "quarterstaff", "wooden_club", "wooden_bow", "wooden_longbow"]

var failures: int = 0
var said: Array = []
var items
var bp_rows: Dictionary = {}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return items.inventory_of(1).count_of(n(id))


func recipe_of(id: String) -> Dictionary:
	for number in items.recipes.numbers():
		if str(items.recipes.recipe(int(number)).get("id", "")) == id:
			return items.recipes.recipe(int(number))

	return {}


# [id, count] pairs of a recipe's needs or keeps, for comparing with what the design says.
func pairs_of(rows: Array) -> Array:
	return rows.map(func(r): return [items.table.id_of(int(r[0])), int(r[1])])


func clear_pack() -> void:
	var inv = items.inventory_of(1)

	for slot in range(inv.slot_count):
		if inv.numbers[slot] != 0:
			inv.remove(inv.numbers[slot], inv.counts[slot])


# One tool in a hotbar slot (the server reads the hammer and the knife from the hand bar).
func hold(id: String) -> void:
	var inv = items.inventory_of(1)
	items.give(1, n(id), 1)
	var at: int = inv.numbers.find(n(id))

	if not inv.on_hotbar(at):
		inv.move(at, 0)


func put_needs(recipe: Dictionary) -> void:
	for need in recipe.get("needs", []):
		items.inventory_of(1).add(int(need[0]), int(need[1]))


func standing(kind: String) -> Array:
	var found: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == kind and not it["struct"].has("site"):
			found.append(id)

	return found


func queue(recipe_id: String) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(recipe_of(recipe_id)["number"]), 0, 1, CraftHand.at(items, 1, int(recipe_of(recipe_id)["number"])))

	for _s in range(60):
		items.tick(1.0)


func triangles(node: Node) -> int:
	var total: int = 0

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += floori(float((node as MeshInstance3D).mesh.get_faces().size()) / 3.0)

	for child in node.get_children():
		total += triangles(child)

	return total


func _init() -> void:
	var dir: String = "user://test_wood_phase4"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "woodphase4key01")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 150.0
	bp_rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]
	station_data()
	recipe_data()
	primitive_bow()
	carving()
	knife_vs_hammer()
	menus()
	benches()
	print("test_wood_phase4: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# --- 1. The station ---
func station_data() -> void:
	var def: Dictionary = items._structures.get("carving_station", {})
	check(not def.is_empty() and str(def.get("station", "")) == "carving_station" and bool(def.get("blocks_walk", false)) and str(def.get("look", "")) == "carving_station", "the carving station is a structure serving the station carving_station")
	var entry: Dictionary = items.table.entry("carving_station")
	check(not entry.is_empty() and str(entry.get("name", "")) == "Wood carving station" and str(entry.get("kind", "")) == "structure", "and an item named Wood carving station")
	var states: Dictionary = {}
	var unique: bool = true

	for kind in items._structures:
		var state: int = int(items._structures[kind].get("state", -1))

		if state >= 0:
			unique = unique and not states.has(state)
			states[state] = kind

	check(unique and int(def.get("state", 0)) == 443 and int(items._structures["log_double_bench"]["state"]) == 444 and int(items._structures["log_backed_bench"]["state"]) == 445, "the new structure states are unique (443, 444, 445)")
	var bp: Dictionary = bp_rows.get("carving_station", {})
	check(_cost(bp.get("cost", [])) == _cost([["wooden_block", 2]]) and str(bp.get("tool", "")) == "knife" and str(bp.get("station", "")) == "", "its blueprint costs two Wooden blocks, is built with a knife and needs no station")

	for look in ["carving_station", "log_bench", "log_double_bench", "log_backed_bench"]:
		check(LookTable.has_look(look), "%s has a look" % look)
		var node: Node3D = LookTable.build(look)
		var tris: int = triangles(node)
		check(tris > 0 and tris < NEAR_TRIANGLES, "%s: under 300 triangles (%d)" % [look, tris])
		node.free()


# --- 2. The recipes ---
func recipe_data() -> void:
	for id in CARVED:
		var r: Dictionary = recipe_of(id)
		check(not r.is_empty() and str(r.get("station", "")) == "carving_station" and pairs_of(r.get("keeps", [])) == ([["knife", 1], ["copper_chisel", 1]] if ["wooden_bowl", "serving_platter"].has(id) else [["knife", 1]]), "%s is made at the carving station, keeping a knife (the bowl and platter also a Copper chisel or better, Dave 18 Nov 2026)" % id)

	check(pairs_of(recipe_of("wooden_bow")["needs"]) == [["wooden_block", 1], ["twine", 2]], "the Shortbow is 1 Wooden block and 2 Twine")
	check(pairs_of(recipe_of("wooden_longbow")["needs"]) == [["log", 1], ["twine", 3]], "the Longbow is 1 Log and 3 Twine")
	check(pairs_of(recipe_of("wooden_bowl")["needs"]) == [["wooden_block", 1]] and pairs_of(recipe_of("serving_platter")["needs"]) == [["wooden_block", 2]], "the bowl is 1 block and the platter 2, as before")


# --- 3. The Primitive bow ---
func primitive_bow() -> void:
	var r: Dictionary = recipe_of("primitive_bow")
	check(not r.is_empty() and pairs_of(r["needs"]) == [["stick", 2], ["plant_fibre", 2]] and str(r.get("station", "")) == "" and r.get("keeps", []).is_empty() and bool(r.get("known", false)), "the Primitive bow is 2 Stick and 2 Plant fibre by hand, known from the start")
	var entry: Dictionary = items.table.entry("primitive_bow")
	var short: Dictionary = items.table.entry("wooden_bow")
	check(BowAim.shoots(entry) and str(entry.get("weapon_class", "")) == "bow" and int(entry["durability"]) < int(short["durability"]), "it is a bow that wears out faster than the Shortbow (%d against %d)" % [int(entry["durability"]), int(short["durability"])])
	var bow = BowScript.new()
	var row: Dictionary = bow.cfg["bows"].get("primitive_bow", {})
	check(is_equal_approx(float(row.get("speed_mult", 0.0)), 0.7) and is_equal_approx(float(row.get("damage_mult", 0.0)), 0.7) and is_equal_approx(float(row.get("range_mult", 0.0)), 0.6), "its bow.json row is 0.7 speed, 0.7 damage and 0.6 range")
	check(bow.speed(1.0, "primitive_bow") < bow.speed(1.0, "wooden_bow") and bow.range_m("primitive_bow") < bow.range_m("wooden_bow") and bow.damage(8.0, 1.0, 0.0, "primitive_bow") < bow.damage(8.0, 1.0, 0.0, "wooden_bow"), "so its arrow is slower, flies less far and hits softer than the Shortbow's")
	items.report_position(1, Vector3(100.0, 10.0, 100.0))
	clear_pack()
	put_needs(r)
	queue("primitive_bow")
	check(have("primitive_bow") == 1 and have("stick") == 0 and have("plant_fibre") == 0, "made by hand with no station and no knife")


# --- 2. continued: carving through the craft queue ---
func carving() -> void:
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	for id in CARVED:
		var r: Dictionary = recipe_of(id)
		clear_pack()
		hold("stone_knife")
		put_needs(r)
		queue(id)
		check(items.inventory_of(1).count_of(int(r["gives"][0])) == 0 and have("stone_knife") == 1, "%s: away from a carving station nothing is carved" % id)

	check(items.dev_place("carving_station@2,0,0") != 0 and not standing("carving_station").is_empty(), "a carving station stands 2 m from the player")

	for id in CARVED:
		var r: Dictionary = recipe_of(id)
		clear_pack()
		hold("stone_knife")

		if ["wooden_bowl", "serving_platter"].has(id):
			hold("copper_chisel")   # carved with a Copper chisel or better in hand, the knife kept in the pack (Dave 18 Nov 2026)

		put_needs(r)
		queue(id)
		var gives: Array = r["gives"]
		check(items.inventory_of(1).count_of(int(gives[0])) == int(gives[1]) and have("stone_knife") == 1, "%s: carved at the station, the knife kept" % id)

	clear_pack()
	put_needs(recipe_of("wooden_bowl"))
	queue("wooden_bowl")
	check(have("wooden_bowl") == 0 and have("wooden_block") == 1, "with no knife in the pack nothing is carved and the block stays")


# --- 4. Knife and hammer ---
func knife_vs_hammer() -> void:
	items.report_position(1, Vector3(40.0, 10.0, 0.0))
	var station_bp: int = int(bp_rows["carving_station"]["number"])
	clear_pack()
	hold("stone_hammer")
	items.inventory_of(1).add(n("wooden_block"), 2)
	said.clear()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, station_bp, 0, 0, Vector3(40.0, 10.0, 3.0))
	check(standing("carving_station").size() == 1 and have("wooden_block") == 2 and said.any(func(t): return str(t).contains("knife")), "a hammer cannot build the carving station (only the dev-placed one stands): nothing is placed or taken, and it says to use a knife")
	clear_pack()
	hold("stone_knife")
	items.inventory_of(1).add(n("wooden_block"), 2)
	said.clear()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, station_bp, 0, 0, Vector3(40.0, 10.0, 3.0))
	var carving_site: int = HeldTool.site_of(items, "carving_station")
	check(carving_site >= 0 and standing("carving_station").size() == 1 and have("wooden_block") == 2, "a knife in the hand bar sets the carving station down as a site, taking nothing (Dave 18 Nov 2026)")
	hold("stone_hammer")   # a knife row is filled by a hammer hit too (provisional BP-3)
	HeldTool.hit_site(items, carving_site)
	check(standing("carving_station").size() == 2 and have("wooden_block") == 0, "a hammer hit fills it from two Wooden blocks and it stands")

	# A hammer row (the Lean-to, blueprint 25) the other way round: a knife is no hammer.
	var lean: int = int(bp_rows["lean_to"]["number"])
	clear_pack()
	hold("stone_knife")

	for need in bp_rows["lean_to"]["cost"]:
		items.inventory_of(1).add(n(str(need[0])), int(need[1]))

	said.clear()
	items.report_position(1, Vector3(80.0, 10.0, 0.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, lean, 0, 0, Vector3(80.0, 10.0, 3.0))
	check(standing("lean_to").is_empty() and have("stick") == 20 and said.any(func(t): return str(t).contains("hammer")), "a knife cannot build a hammer blueprint: nothing placed or taken, and it says to use a hammer")
	hold("stone_hammer")
	items.action(1, Net.ACT_PLACE_BLUEPRINT, lean, 0, 0, Vector3(80.0, 10.0, 3.0))
	HeldTool.hit_site(items, HeldTool.site_of(items, "lean_to"))   # placing sets down a site; the hammer hit fills it
	check(standing("lean_to").size() == 1 and have("stick") == 0, "a hammer places it and fills it")


# --- 5. The menus ---
func menus() -> void:
	var table = items.table
	var pack = InventoryScript.new(table)
	var hammer_list = ListScript.new()
	hammer_list.setup(table, pack, null, "user://test_wood_phase4_none.json")
	var knife_list = ListScript.new()
	knife_list.setup(table, pack, null, "user://test_wood_phase4_none.json")
	knife_list.tool = "knife"
	var knife_names: Array = knife_list.rows(1).map(func(r): return str(r["name"]))
	var knife_structures: Array = KNIFE_ROWS.map(func(k): return str(bp_rows[k]["name"]))
	check(knife_list.rows(1).size() == KNIFE_ROWS.size() and knife_names.size() == knife_structures.size() and knife_structures.all(func(s): return knife_names.has(s)), "the knife's list holds exactly its %d rows (%d listed)" % [KNIFE_ROWS.size(), knife_names.size()])
	check(knife_names.has("Wood carving station") and knife_names.has("Log - Bench") and knife_names.has("Log - Double bench") and knife_names.has("Log - Backed bench") and knife_names.has("Log - Table"), "among them the station, the three benches and the table")
	var hammer_names: Array = hammer_list.rows(1).map(func(r): return str(r["name"]))   # 216 hammer rows without the Wooden - Hand pump (retired, Dave 20 Nov 2026); 217 without the three Wooden - Pipe blueprints (Dave 19 Nov 2026, laid from the hand); 220 with the Grill, Cooking pot, Griddle and Hand mill (Dave 17 Nov 2026 cooking stations); 216 with the Improved and Advanced kilns (Dave 17 Nov 2026); 214 since phase 5 added the Small log sled and Small wagon (hammer blueprints, W-14) + 21 knife rows
	check(not knife_structures.any(func(s): return hammer_names.has(s)) and hammer_names.size() + knife_names.size() == 237, "the hammer's list has none of them (%d hammer rows, %d knife rows)" % [hammer_names.size(), knife_names.size()])
	var first: Dictionary = knife_list.actions()[0]
	check(knife_list.actions().size() == 1 and str(first["kind"]) == "repair" and str(first["name"]) == "Knife" and knife_list.entries(1).all(func(e): return str(e["kind"]) == "bp") and not knife_list.categories(1).has(knife_list.PLANS_TAB), "the knife's screen has a plain Knife line above the list and no Save or plan lines")
	check(str(hammer_list.actions()[0]["name"]) == "Hammer/Repair Tool" and str(hammer_list.actions()[1]["kind"]) == "save", "the hammer's screen still has Repair and Save")
	var hud_layer: CanvasLayer = CanvasLayer.new()
	var knife_screen = ListScript.new()
	knife_screen.setup(table, pack, hud_layer, "user://test_wood_phase4_none.json")
	knife_screen.tool = "knife"
	knife_screen.set_open(true, 1)
	check(knife_screen._title.text.begins_with("Knife"), "the knife's screen is titled Knife")
	hud_layer.free()
	var station_state: int = int(items._structures["carving_station"]["state"])
	# An older saved plan holding a knife piece (the Wicker - Chest, blueprint 26) and a hammer piece (the Lean-to, 25): the hammer's cost and placing skip the knife piece.
	var lean_no: int = int(bp_rows["lean_to"]["number"])
	var chest_no: int = int(bp_rows["chest"]["number"])
	hammer_list.plans.plans.append({"name": "Old camp", "pieces": [{"bp": chest_no, "dx": 0.0, "dy": 0.0, "dz": 0.0, "yaw": 0}, {"bp": lean_no, "dx": 3.0, "dy": 0.0, "dz": 0.0, "yaw": 0}]})
	var plan: Dictionary = hammer_list.plans.plans[hammer_list.plans.plans.size() - 1]
	var placed: Array = hammer_list.placements_of(hammer_list.plans.plans.size() - 1, Vector3.ZERO, 0.0)
	check(hammer_list.is_knife_bp(chest_no) and not hammer_list.is_knife_bp(lean_no) and hammer_list.hammer_pieces(plan).size() == 1 and placed.size() == 1 and int(placed[0]["bp"]) == lean_no, "an old plan's knife piece is left out of the hammer's placing")
	var lean_cost: Dictionary = {}

	for need in bp_rows["lean_to"]["cost"]:
		lean_cost[str(need[0])] = int(need[1])

	check(JSON.stringify(hammer_list.plan_cost(plan)) == JSON.stringify(lean_cost) and hammer_list.plan_text(plan).begins_with("1 pieces:"), "and out of its cost and its line in the menu")
	check(not hammer_list.bp_of_state().has(station_state) and not knife_list.bp_of_state().has(station_state) and hammer_list.bp_of_state().has(int(items._structures["lean_to"]["state"])), "a saved building plan holds hammer pieces only")


# --- 6. The benches ---
func benches() -> void:
	var rows: Dictionary = {"log_bench": [1, 1.2, [["log", 1]]], "log_double_bench": [2, 2.2, [["log", 2]]], "log_backed_bench": [2, 1.5, [["log", 3], ["twine", 2]]]}

	for kind in rows:
		var def: Dictionary = items._structures[kind]
		var want: Array = rows[kind]
		check((def.get("sit_spots_x", []) as Array).size() == int(want[0]) and is_equal_approx(float(def["footprint_x"]), float(want[1])) and str(def.get("use", "")) == "sit", "%s seats %d and is %.1f m long" % [kind, int(want[0]), float(want[1])])
		check(_cost(bp_rows[kind]["cost"]) == _cost(want[2]) and str(bp_rows[kind]["tool"]) == "knife" and not bool(bp_rows[kind].get("retired", false)), "%s costs %s with a knife" % [kind, str(want[2])])

	check(str(items._structures["log_backed_bench"]["sit_face"]) == "front" and str(items._structures["log_bench"]["sit_face"]) == "sides", "the backed bench is sat facing out from its back, the plain ones from either side")
	check(_cost(bp_rows["log_table"]["cost"]) == _cost([["log", 3], ["twine", 2]]) and str(bp_rows["log_table"]["tool"]) == "knife", "the Log - Table costs 3 Logs and 2 Twine with a knife")
	check(rows.keys().all(func(k): return str(items._structures[k]["comfort"]) == "bench"), "every bench counts as a bench for comfort")


# A blueprint cost as text with whole counts: JSON loads 2 as 2.0, so JSON.stringify of a loaded cost never equals an int literal's.
func _cost(cost: Array) -> String:
	var parts: PackedStringArray = []

	for c in cost:
		parts.append("%s x%d" % [str(c[0]), int(c[1])])

	return ", ".join(parts)
