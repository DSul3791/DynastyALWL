extends SceneTree

# Crafting stock (docs/design/INVENTORY_CRAFTING_REPORT.md step 2; decisions in docs/design/OVERNIGHT_DECISIONS_8NOV.md, 8 Nov 2026): a craft draws on the
# pack, loose stacks within 3 m and the player's own storage containers within CraftStock.CRAFT_REACH_M (12 m) that are not ticked "keep out", pack first,
# then the ground, then the nearest container. A stranger's chest and a fire's store never count. A container saved before owners belongs to its first
# opener; the owner and the tick survive a save and load. Blueprint sites use the same containers. The client is told the stock (craft_stock).
#   godot --headless --path . --script res://src/worldgen/tools/test_craft_stock.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CraftStock := preload("res://src/shared/craft_stock.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []
var stock_sent: Dictionary = {}     # peer -> {number: count} from the last craft_stock
var info_sent: Array = []           # [peer, id, keep_out, may_set] from the last chest_info
var clay: int = 0
var pot_recipe: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func pack_clay() -> int:
	return items.inventory_of(1).count_of(clay)


func pots() -> int:
	return items.inventory_of(1).count_of(items.table.number_of("clay_pot"))


func chest_at(x: float, owner_peer: int, z: float = 0.0) -> int:
	var id: int = items.dev_place("chest@%s,%s,0" % [str(x), str(z)])

	if owner_peer > 0:
		items._items[id]["struct"]["owner"] = str(items._peer_key[owner_peer])

	return id


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func craft_pot() -> void:
	items.action(1, Net.ACT_CRAFT_QUEUE, pot_recipe, 0, 1, Vector3.ZERO)


func reset() -> void:
	for k in items._items.keys():
		var it: Dictionary = items._items[k]

		if it.has("struct") or (not it.has("scatter") and not it.has("tree") and not it.has("boulder")):
			items._items.erase(k)

	items.inventory_of(1).remove(clay, pack_clay())
	items._craft_queues[items._peer_key[1]] = {"entries": [], "elapsed": 0.0}
	said.clear()


func _init() -> void:
	var dir: String = "user://test_craft_stock"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	# The rule itself.
	check(CraftStock.CRAFT_REACH_M == 12.0 and CraftStock.LOOSE_STOCK_M == 3.0, "one crafting distance, 12 m, and loose stock within 3 m")
	check(CraftStock.box_counts("a", false, "a", 11.9) and not CraftStock.box_counts("a", false, "a", 12.1), "own chest at 11.9 m counts, at 12.1 m it does not")
	check(not CraftStock.box_counts("a", true, "a", 2.0) and not CraftStock.box_counts("b", false, "a", 2.0) and not CraftStock.box_counts("", false, "a", 2.0), "keep out, a stranger's and an unowned chest never count")
	check(CraftStock.take_plan(7, [2, 1, 5, 5]) == [2, 1, 4, 0] and CraftStock.take_plan(3, [0, 0, 1]) == [0, 0, 1], "take_plan splits in order: pack, ground, nearest container")

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.send_carry = func(_p, _id): pass
	items.send_chest = func(_p, _id, _b): pass
	items.send_chest_info = func(p, id, keep_out, may_set): info_sent = [p, id, keep_out, may_set]
	items.send_craft_stock = func(p, numbers, counts):
		var rows: Dictionary = {}

		for i in numbers.size():
			rows[int(numbers[i])] = int(counts[i])

		stock_sent[p] = rows
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "craftstock001")
	items.peer_connected_hello(2, "craftstock002")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.report_position(2, Vector3(0.0, 10.0, 40.0))
	items.vitals_of(1)["weight"] = 2000.0
	items.admin_mode_on = func(_p): return false
	items._admin_mode_off[1] = true
	clay = items.table.number_of("clay")

	for k in items.recipes.numbers():
		if str(items.recipes.recipe(int(k)).get("id", "")) == "clay_pot":
			pot_recipe = int(k)

	check(clay > 0 and pot_recipe > 0, "the clay pot recipe (6 clay) is in the table")
	reset()

	# 1. In range: the clay is in the player's own chest 8 m away.
	var near_chest: int = chest_at(8.0, 1)
	box(near_chest).add(clay, 6)
	craft_pot()
	check(box(near_chest).count_of(clay) == 0 and items.craft_queue_of(1).size() == 1, "clay in your own chest 8 m away makes the pot (chest now holds %d)" % box(near_chest).count_of(clay))

	# 2. Out of range: 14 m.
	reset()
	var far_chest: int = chest_at(14.0, 1)
	box(far_chest).add(clay, 6)
	craft_pot()
	check(box(far_chest).count_of(clay) == 6 and items.craft_queue_of(1).is_empty(), "a chest 14 m away is out of reach: nothing is taken")

	# 3. Keep out: the owner ticks it; a stranger may not change it.
	reset()
	var kept_chest: int = chest_at(2.0, 1)
	box(kept_chest).add(clay, 6)
	items.report_position(2, Vector3(1.0, 10.0, 0.0))
	items.action(2, Net.ACT_CHEST_KEEP_OUT, kept_chest, 1, 0, Vector3.ZERO)
	check(not bool(items._items[kept_chest]["struct"].get("keep_out", false)), "a stranger cannot tick keep out on your chest")
	items.report_position(2, Vector3(0.0, 10.0, 40.0))
	items.action(1, Net.ACT_CHEST_KEEP_OUT, kept_chest, 1, 0, Vector3.ZERO)
	check(bool(items._items[kept_chest]["struct"].get("keep_out", false)) and info_sent.size() == 4 and int(info_sent[1]) == kept_chest and bool(info_sent[2]) and bool(info_sent[3]), "the owner ticks keep out and is told (chest_info)")
	craft_pot()
	check(box(kept_chest).count_of(clay) == 6 and items.craft_queue_of(1).is_empty(), "a chest ticked keep out is left alone")
	items.action(1, Net.ACT_CHEST_KEEP_OUT, kept_chest, 0, 0, Vector3.ZERO)
	craft_pot()
	check(box(kept_chest).count_of(clay) == 0 and items.craft_queue_of(1).size() == 1, "the tick cleared, the same chest is used")

	# 4. A stranger's chest beside you never counts.
	reset()
	var their_chest: int = chest_at(2.0, 2)
	box(their_chest).add(clay, 6)
	craft_pot()
	check(box(their_chest).count_of(clay) == 6 and items.craft_queue_of(1).is_empty(), "a stranger's chest 2 m away is never used")

	# 5. A fire's store never counts (fires are fuel, not storage).
	check(items._is_storage({"fire": {"uid": 1}, "struct": {"kind": "chest", "uid": 1}}) == false, "a fire is not a storage container")

	# 6. Order: pack first, then the ground within 3 m, then the nearest chest, then the next.
	reset()
	items.inventory_of(1).add(clay, 1)
	items.drop_in_world(clay, 1, Vector3(2.0, 10.0, 0.0))
	items.drop_in_world(clay, 5, Vector3(0.0, 10.0, 6.0))   # 6 m: not loose stock
	var first: int = chest_at(5.0, 1)
	var second: int = chest_at(9.0, 1)
	box(first).add(clay, 3)
	box(second).add(clay, 5)
	items.action(1, Net.ACT_CRAFT_STOCK, 0, 0, 0, Vector3.ZERO)
	check(int(stock_sent.get(1, {}).get(clay, 0)) == 9, "craft_stock tells the client 9 clay besides the pack (1 on the ground, 3 + 5 in own chests; got %d)" % int(stock_sent.get(1, {}).get(clay, 0)))
	craft_pot()
	var ground_near: int = items._ground_count(clay, Vector3(0.0, 10.0, 0.0), 3.0)
	check(pack_clay() == 0 and ground_near == 0 and box(first).count_of(clay) == 0 and box(second).count_of(clay) == 4, "6 clay: 1 from the pack, 1 from the ground, 3 from the nearer chest, 1 from the farther (pack %d, ground %d, chests %d and %d)" % [pack_clay(), ground_near, box(first).count_of(clay), box(second).count_of(clay)])
	check(int(stock_sent.get(1, {}).get(clay, 0)) == 4, "after the craft the client is sent the new stock (4)")

	# 7. A chest from before owners belongs to the first player who opens it; owner and keep out survive a save and load.
	reset()
	var old_chest: int = chest_at(2.0, 0)
	check(str(items._items[old_chest]["struct"].get("owner", "")) == "", "a chest placed without an owner (an old save) has none")
	items.action(1, Net.ACT_CHEST_OPEN, old_chest, 0, 0, Vector3.ZERO)
	check(str(items._items[old_chest]["struct"].get("owner", "")) == str(items._peer_key[1]), "the first player to open it owns it")
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_KEEP_OUT, old_chest, 1, 0, Vector3.ZERO)
	var where: Vector3 = items._items[old_chest]["pos"]
	items.save()
	var again = ItemsScript.new()
	again.ground_height = func(_x, _z): return 10.0
	again.setup(ItemTableScript.load_default(), dir)
	var found: Dictionary = {}

	for k in again._items:
		var it: Dictionary = again._items[k]

		if it.has("struct") and str(it["struct"]["kind"]) == "chest" and (it["pos"] as Vector3).distance_to(where) < 0.01:
			found = it["struct"]

	check(str(found.get("owner", "")) == str(items._peer_key[1]) and bool(found.get("keep_out", false)), "the owner and the keep-out tick are saved with the chest")

	# 8. Blueprint sites use the same containers: own, within 12 m, not kept out.
	reset()
	var mine: int = chest_at(10.0, 1)
	chest_at(0.0, 2, 10.0)
	chest_at(-13.0, 1)
	var site_boxes: Array = items._craft_boxes(1)
	check(site_boxes.size() == 1 and int(site_boxes[0][0]) == mine, "a blueprint site sees only your own chest within 12 m (got %d)" % site_boxes.size())

	print("craft stock: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
