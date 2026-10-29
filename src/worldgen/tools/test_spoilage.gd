extends SceneTree

# Food spoilage (data/items/spoilage.json): age in the slot's wear field, place multipliers, merging, rot, eating.
#   godot --headless --path . --script res://src/worldgen/tools/test_spoilage.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var roast: int = table.number_of("roast_forage")
	var life: int = table.shelf_units(roast)
	check(life == 5760, "Campfire Stew lasts 144 h x 4 (gentle) = 5760 tenths (got %d)" % life)
	check(table.shelf_units(table.number_of("stone")) == 0 and table.freshness(table.number_of("stone"), 500) == 1.0, "stone does not spoil")
	var berries: int = table.number_of("belladonna_berries")
	check(table.shelf_units(berries) == 1440, "gathered berries match by suffix (36 h x 4)")
	check(absf(table.freshness(roast, life / 2) - 0.5) < 0.01, "half the shelf life is half fresh")

	# Merging.
	var inv = InventoryScript.new(table)
	inv.add(roast, 3, 0)
	inv.add(roast, 3, 100)
	check(inv.count_of(roast) == 6 and inv.counts[0] == 6 and inv.wear[0] == 50, "close ages merge and average (%d)" % inv.wear[0])
	inv.add(roast, 2, 1500)
	check(inv.counts[0] == 6 and inv.counts[1] == 2 and inv.wear[1] == 1500, "far ages stay in separate stacks")
	inv.move(1, 0)
	check(inv.counts[0] == 2 and inv.counts[1] == 6, "a move of far ages swaps instead of merging")

	# Server: ageing by place.
	var dir: String = "user://test_spoilage"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.season_now = func(): return "spring"
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "spoil-key-0001")
	items._characters[items._peer_key[1]]["grace_s"] = 0.0   # eat-once: the first-hour protection has its own test
	items.report_position(1, Vector3(10.0, 5.0, 10.0))
	items.action(1, Net.ACT_ADMIN_GIVE, roast, 0, 4, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 4, Vector3.ZERO)
	var pack = items.inventory_of(1)
	var slot: int = pack.numbers.find(roast)

	for n in 10:
		items._spoil_tick(15.0)

	check(pack.wear[slot] == 10, "a pack ages one tenth of an hour per 15 s (got %d)" % pack.wear[slot])

	var chest = InventoryScript.new(items.table)
	chest.add(roast, 1, 0)
	items._chests[999] = chest

	for n in 10:
		items._spoil_tick(15.0)

	check(chest.wear[0] == 8, "a woven chest ages at 0.8 of the pack (got %d)" % chest.wear[0])

	items.drop_in_world(roast, 2, Vector3(50.0, 5.0, 50.0), 0)
	var ground_id: int = 0

	for id in items._items:
		if int(items._items[id]["number"]) == roast and not items._items[id].has("scatter"):
			ground_id = id

	for n in 10:
		items._spoil_tick(15.0)

	check(ground_id != 0 and int(items._items[ground_id].get("wear", 0)) == 15, "loose food ages at 1.5 on the ground")

	# Eating: stale gives less, rotten hurts.
	items.vitals_of(1)["fed"] = 0.0
	pack.wear[slot] = life / 2
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
	var fed: float = float(items.vitals_of(1)["fed"])
	check(absf(fed - 400.0 * 0.75) < 2.0, "half-fresh food gives 75 percent of its kcal (got %.0f)" % fed)

	pack.wear[slot] = life - 2

	for n in 4:
		items._spoil_tick(15.0)

	var rotten: int = items.table.number_of("rotten_food")
	check(pack.numbers[slot] == rotten and pack.wear[slot] == 0, "a stack at its shelf life becomes rotten food")
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
	check(items.is_sick(1) and pack.count_of(rotten) == 2, "eating rotten food makes you sick and costs one item")

	# A save keeps the age; an old save (no wear column) reads fresh.
	items.inventory_of(1).add(roast, 1, 777)
	items._dirty = true
	items.save()
	var again = ItemsScript.new()
	again.send_full = func(_p, _b): pass
	again.send_slots = func(_p, _b): pass
	again.send_world_items = func(_p, _a, _r): pass
	again.setup(ItemTableScript.load_default(), dir)
	again.peer_connected_hello(1, "spoil-key-0001")
	check(again.inventory_of(1).wear.has(777), "a saved age reloads")
	var legacy = InventoryScript.new(items.table)
	legacy.from_json_array([[roast, 5]])
	check(legacy.wear[0] == 0 and items.table.freshness(roast, legacy.wear[0]) == 1.0, "an old save without ages reads fresh")

	print("spoilage tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
