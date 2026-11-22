extends SceneTree

# Every water container a player can hold works through the real server (Dave 22 Nov 2026 roadmap: the physical world first, water included).
# For every item with items.json capacity_ml that is not retired:
#   1. at fresh water, the drink action with it in hand fills it (vitals.json thirst.fill_ml a press) up to its capacity, and a full one drinks instead;
#   2. its water is the "water" a recipe needs, one for each 500 mL it holds (gathered.json water unit_ml) (inventory count_fill pools the containers' mL, GOALS-REPAIR GA-04), and a craft takes it from it;
#   3. used (ACT_EAT) it gives the player a mouthful;
#   4. at the sea, the gather action gives Sea water when it holds at least one water (500 mL): every such container is in shore_nodes.json "containers".
# The rules of each step (salt, frozen, dry beds, tanks) are test_drinking_water, test_camp_bench_drink and test_water_pieces.
#   godot --headless --path . --script res://src/worldgen/tools/test_every_water.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var checks: int = 0
var items
var notes: Array = []
var sea: Array = [false]


func check(ok: bool, what: String) -> void:
	checks += 1

	if not ok:
		print("FAIL " + what + ("  (told: %s)" % str(notes.slice(-2)) if not notes.is_empty() else ""))
		failures += 1


func _init() -> void:
	var dir: String = "user://test_every_water"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): notes.append(t)
	items.ground_height = func(_x, _z): return 2.0
	items.water_near = func(_p, _r): return not sea[0]
	items.water_kind_at = func(_x, _z): return {"kind": "sea_shallow"} if sea[0] else {"kind": "river"}
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "everywater00001")
	items.report_position(1, Vector3(0.0, 2.0, 0.0))
	items.vitals_of(1)["weight"] = 1.0e6
	var inv = items.inventory_of(1)
	var cap_ml: float = float(items._vitals_cfg["thirst"].get("cap_ml", 2400))
	var water_n: int = items.table.number_of("water")
	var unit_ml: int = items.table.liquid_unit_ml(water_n)
	var sea_n: int = items.table.number_of("sea_water")
	var shore: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/shore_nodes.json")).get("containers", [])
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))["items"]
	var n: int = 0

	for id in all:
		var row: Dictionary = all[id]

		if int(row.get("capacity_ml", 0)) <= 0 or bool(row.get("retired", false)):
			continue

		n += 1
		var cap: int = int(row["capacity_ml"])

		for i in range(inv.slot_count):
			if inv.numbers[i] != 0:
				inv.remove(inv.numbers[i], inv.counts[i])

		inv.add(items.table.number_of(id), 1)
		var slot: int = inv.numbers.find(items.table.number_of(id))
		sea[0] = false
		notes.clear()

		for press in range(int(ceil(float(cap) / 100.0)) + 2):
			items._last_drink.clear()
			items.action(1, Net.ACT_DRINK, slot, 0, 0, Vector3.ZERO)

		check(inv.wear[slot] == cap, "%s: filled at fresh water it holds %d mL, not its %d" % [id, inv.wear[slot], cap])
		items.vitals_of(1)["wet"] = 0.0
		items._last_drink.clear()
		items.action(1, Net.ACT_DRINK, slot, 0, 0, Vector3.ZERO)
		check(float(items.vitals_of(1)["wet"]) > 0.0 and inv.wear[slot] == cap, "%s: full, the drink action drinks from the water instead" % id)

		var units: int = inv.count_fill(water_n, false)
		check(units == floori(float(cap) / float(unit_ml)), "%s: its %d mL is %d water for a recipe, not %d" % [id, cap, units, floori(float(cap) / float(unit_ml))])   # a bowl or mug alone is less than one (500 mL)

		if units > 0:
			var taken: Array = []
			check(inv.remove_fill(water_n, 1, taken, false) and inv.wear[slot] < cap, "%s: a recipe's water is not taken from it" % id)

		items.vitals_of(1)["wet"] = 0.0
		var held: int = inv.wear[slot]
		items._last_drink.clear()
		items.action(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
		check(held <= 0 or (float(items.vitals_of(1)["wet"]) > 0.0 and inv.wear[slot] < held), "%s: drunk from, it gives no mouthful (%d mL held)" % [id, held])
		check(float(items.vitals_of(1)["wet"]) <= cap_ml, "%s: a mouthful stays under the thirst cap" % id)

		sea[0] = true
		var sea_before: int = inv.count_of(sea_n)
		notes.clear()
		var got: bool = items.gather_edge(1, inv)

		if cap >= unit_ml:
			check(shore.has(id) and got and inv.count_of(sea_n) == sea_before + 1, "%s (%d mL): at the sea it takes no Sea water (shore_nodes.json containers %s)" % [id, cap, str(shore)])

	print("%d water containers played: %d checks" % [n, checks])
	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
