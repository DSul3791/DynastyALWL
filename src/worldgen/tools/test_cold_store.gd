extends SceneTree

# Cold store (root cellar, item_system.md D1): a storage piece whose structures.json row has "cold_store" keeps the site's year-mean air, or the
# cave air in a cave cell, and its food ages by spoilage.json cold_store (q10 below ref_c), with no season.
#   godot --headless --path . --script res://src/worldgen/tools/test_cold_store.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const CELLAR_UID := 9901
const CHEST_UID := 9902
const CELLAR_POS := Vector3(10.0, 40.0, 10.0)
const CAVE_POS := Vector3(80.0, 40.0, 10.0)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _place(items, uid: int, kind: String, pos: Vector3, number: int) -> Variant:
	var chest = InventoryScript.new(items.table)
	chest.add(number, 1, 0)
	items._chests[uid] = chest
	items._items[items._next_id] = {"number": items.table.number_of("chest"), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": uid}}
	items._next_id += 1
	return chest


func _init() -> void:
	var cfg: Dictionary = ItemTableScript.load_default().spoilage().get("cold_store", {})
	check(not cfg.is_empty(), "spoilage.json has a cold_store block")
	check(absf(ItemsScript.cold_store_mult(cfg, 20.0) - 1.0) < 1e-6, "at ref_c a cold store ages like a pack")
	check(absf(ItemsScript.cold_store_mult(cfg, 30.0) - 1.0) < 1e-6, "a warm cellar is never worse than a pack")
	check(absf(ItemsScript.cold_store_mult(cfg, 10.0) - 1.0 / 3.0) < 1e-4, "10 C below ref_c is a third of the rate (q10 3)")
	check(absf(ItemsScript.cold_store_mult(cfg, -40.0) - 0.1) < 1e-6, "never under min_mult")

	var dir: String = "user://test_cold_store"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var said: Array = []
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.season_now = func(): return "summer"   # summer speeds a chest up 1.5 times; the cellar does not feel it
	items.year_mean_at = func(_p): return 10.0
	items.cave_mean_c = func(p): return 5.5 if p.x > 50.0 else NAN
	items.setup(ItemTableScript.load_default(), dir)
	items._structures["test_cold_store"] = {"slots": 12, "cold_store": true, "item": "chest", "who": "anyone"}
	var roast: int = items.table.number_of("roast_forage")

	check(absf(items.cold_store_c(CELLAR_POS) - 10.0) < 1e-6, "outside a cave the cellar is at the year mean")
	check(absf(items.cold_store_c(CAVE_POS) - 5.5) < 1e-6, "in a cave cell the cellar is at the cave air")

	var cellar = _place(items, CELLAR_UID, "test_cold_store", CELLAR_POS, roast)
	var cave_cellar = _place(items, CELLAR_UID + 10, "test_cold_store", CAVE_POS, roast)
	var chest = _place(items, CHEST_UID, "chest", CELLAR_POS, roast)

	for n in 300:
		items._spoil_tick(15.0)   # one tenth of a game hour each

	check(absi(chest.wear[0] - 360) <= 1, "a woven chest in summer ages 0.8 x 1.5 (got %d)" % chest.wear[0])
	check(absi(cellar.wear[0] - 100) <= 1, "a 10 C cellar ages a third of a pack, with no season (got %d)" % cellar.wear[0])
	var cave_want: int = int(300.0 * ItemsScript.cold_store_mult(cfg, 5.5))
	check(absi(cave_cellar.wear[0] - cave_want) <= 1, "a cave cellar ages at the 5.5 C rate (got %d, want %d)" % [cave_cellar.wear[0], cave_want])

	# Without the callables (no world) a cold store spoils like a plain store, at its place multiplier (none: 1) and the season.
	var bare = ItemsScript.new()
	bare.send_full = func(_p, _b): pass
	bare.send_slots = func(_p, _b): pass
	bare.send_world_items = func(_p, _a, _r): pass
	bare.season_now = func(): return "spring"
	bare.setup(ItemTableScript.load_default(), dir)
	bare._structures["test_cold_store"] = {"slots": 12, "cold_store": true, "item": "chest", "who": "anyone"}
	var plain = _place(bare, CELLAR_UID, "test_cold_store", CELLAR_POS, roast)

	for n in 20:
		bare._spoil_tick(15.0)

	check(is_nan(bare.cold_store_c(CELLAR_POS)) and absi(plain.wear[0] - 20) <= 1, "no temperature known: ages like a pack (got %d)" % plain.wear[0])

	# Opening one says how cool it is and how much longer food keeps.
	items.peer_connected_hello(1, "cold-key-0001")
	items.report_position(1, CELLAR_POS + Vector3(1.0, 0.0, 0.0))
	var cellar_id: int = 0

	for id in items._items:
		if items._items[id].has("struct") and int(items._items[id]["struct"].get("uid", 0)) == CELLAR_UID:
			cellar_id = id

	said.clear()
	items.action(1, Net.ACT_CHEST_OPEN, cellar_id, 0, 0, Vector3.ZERO)
	check(said.has("It is 10 C in here all year. Food keeps about 3 times as long as in a pack."), "opening says the temperature (got %s)" % [said])

	print("cold store tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
