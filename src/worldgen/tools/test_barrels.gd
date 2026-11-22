extends SceneTree

# The two barrels (Dave 22 Nov 2026 20:24Z: "one will be called a water barrel and one will be called a storage barrel ... if it's a water barrel it
# will have an inventory also, but it can only have three slots, and it can only accept water containers, and when you put a water container in it,
# it will fill it up if the barrel has water in it, you can also take a drink from a water barrel"):
#   1. the Storage barrel (storage_barrel) is a blueprint, a store of 12 slots that takes food by the thousand, and holds no water;
#   2. the Water barrel (wooden_barrel) has 3 slots that take only water containers, keeps its water while it holds them, fills them from its water,
#      and gives a drink;
#   3. a Barrel saved before the split holding goods loads as a Storage barrel with its goods; an empty one, or one of water containers, stays a Water barrel.
#   godot --headless --path . --script res://src/worldgen/tools/test_barrels.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const StoreRules := preload("res://src/shared/store_rules.gd")

const DIR := "user://test_barrels"

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


func slot_of(id: String) -> int:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] == n(id):
			return s

	return -1


func place(kind: String, x: float) -> int:
	var id: int = items.dev_place("%s@%s,0,0" % [kind, str(x)])
	items._items[id]["pos"] = Vector3(x, 10.0, 0.0)
	items._water_add(id)
	return id


func box_of(id: int):
	items.report_position(1, items._items[id]["pos"])
	return items._chest_of(1, id)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "barrels00000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var inv = items.inventory_of(1)
	var storage_def: Dictionary = items._structures.get("storage_barrel", {})
	var water_def: Dictionary = items._structures.get("wooden_barrel", {})
	var bps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))["blueprints"]

	# 1. The Storage barrel.
	check(bps.has("storage_barrel") and str(bps["storage_barrel"]["structure"]) == "storage_barrel" and bool(bps["storage_barrel"].get("known", false)), "the Storage barrel is a known blueprint")
	check(items.table.name_of(n("storage_barrel")) == "Storage barrel" and items.table.name_of(n("wooden_barrel")) == "Water barrel", "the two are named Storage barrel and Water barrel")
	check(int(storage_def.get("slots", 0)) == 12 and not storage_def.has("water") and StoreRules.autoloads(storage_def), "a Storage barrel has 12 slots, holds no water and autoloads like a crate")
	var store: int = place("storage_barrel", 0.0)
	var sbox = box_of(store)
	check(sbox != null and sbox.usable == 12, "it opens with 12 slots")
	items.vitals_of(1)["weight"] = 1.0e6   # the pack's carry limit is not what is tested
	items.give(1, n("apple_keeping"), 3000)
	items._box_put(1, inv, store, sbox, slot_of("apple_keeping"), 3000)
	check(sbox != null and sbox.count_of(n("apple_keeping")) == 3000 and sbox.numbers.count(n("apple_keeping")) == 1, "3,000 keeping apples go into one of its slots (a winter's food for one: about 2,000)")
	check(not items._water_kind.has(store), "and it is no water tank")

	# 2. The Water barrel.
	check(int(water_def.get("slots", 0)) == 3 and bool(water_def.get("fills_containers", false)) and water_def.has("water") and not StoreRules.autoloads(water_def), "a Water barrel has 3 slots, holds water, fills containers and does not autoload")
	var barrel: int = place("wooden_barrel", 4.0)
	var wbox = box_of(barrel)
	check(wbox != null and wbox.usable == 3, "it opens with 3 slots")
	items.give(1, n("stick"), 1)
	said.clear()
	items._box_put(1, inv, barrel, wbox, slot_of("stick"), 1)
	check(inv.count_of(n("stick")) == 1 and wbox.count_of(n("stick")) == 0, "a stick does not go in (%s)" % str(said))
	items._water.set_litres(barrel, 40.0)
	items._water_dirty = true
	items.give(1, n("waterskin"), 1)
	inv.wear[slot_of("waterskin")] = 0
	said.clear()
	items._box_put(1, inv, barrel, wbox, slot_of("waterskin"), 1)
	var skin: int = wbox.numbers.find(n("waterskin"))
	check(skin >= 0, "a waterskin goes in while it holds water (%s)" % str(said))
	var cap: int = items._container_cap(n("waterskin"))

	for tick in range(40):
		items._barrel_next_s = 0.0
		items._barrels_tick()

	var left: float = items._water.litres(barrel, items._water_now_s())
	check(skin >= 0 and wbox.wear[skin] == cap, "the waterskin fills from the barrel (%d of %d mL)" % [wbox.wear[skin] if skin >= 0 else -1, cap])
	check(absf(left - (40.0 - float(cap) / 1000.0)) < 0.05, "and the water comes out of the barrel (%.2f L left)" % left)
	check(float(items._water.pieces[barrel].get("litres_max", 0.0)) == 60.0, "holding it, the barrel still holds its 60 L")
	var v: Dictionary = items.vitals_of(1)
	v["wet"] = 0.0
	items._last_drink.clear()
	items._drink_from_tank(1, -1, inv, barrel, v, items._vitals_cfg.get("thirst", {}), Time.get_ticks_msec())
	check(float(v["wet"]) > 0.0 and items._water.litres(barrel, items._water_now_s()) < left, "a drink from the barrel")

	# 3. A Barrel saved before the split.
	var old_goods: int = place("wooden_barrel", 8.0)
	box_of(old_goods).add(n("apple_keeping"), 50)
	var old_skins: int = place("wooden_barrel", 12.0)
	box_of(old_skins).add(n("waterskin"), 1)
	var old_empty: int = place("wooden_barrel", 16.0)
	box_of(old_empty)
	items._split_old_barrels()
	check(str(items._items[old_goods]["struct"]["kind"]) == "storage_barrel" and int(items._items[old_goods]["number"]) == n("storage_barrel") and box_of(old_goods).count_of(n("apple_keeping")) == 50, "an old barrel of apples loads as a Storage barrel, its apples kept")
	check(str(items._items[old_skins]["struct"]["kind"]) == "wooden_barrel" and str(items._items[old_empty]["struct"]["kind"]) == "wooden_barrel", "an old barrel of water containers, or an empty one, stays a Water barrel")
	items._water_prune()
	check(not items._water_kind.has(old_goods) and items._water_kind.has(old_skins), "the new Storage barrel leaves the water network, the Water barrel stays in it")

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
