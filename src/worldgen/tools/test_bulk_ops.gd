extends SceneTree

# Bulk buttons and favourites (docs/design/INVENTORY_CRAFTING_REPORT.md step 3; decisions in docs/design/OVERNIGHT_DECISIONS_8NOV.md row 23, 8 Nov 2026).
# Take all fills the pack up to its space and the carry limit. Store all empties the pack past the hotbar into the open container (a fire takes only
# wood and food, a chest only up to its kilograms). Stack to nearby needs no open container: it adds to the player's own chests within 12 m that
# already hold the item, keep out or not. Sort reorders the pack (and an open chest) by the chosen key, empty slots last. Favourites and pack slots
# 1 to 10 never move. A favourite rides with its stack and is saved. Each button answers with bulk_done (stacks moved, containers, their ids).
#   godot --headless --path . --script res://src/worldgen/tools/test_bulk_ops.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var done: Array = []          # the last bulk_done: [peer, kind, stacks, containers, ids]
var favs_sent: Dictionary = {}   # peer -> the last favourites flags
var clay: int = 0
var stone: int = 0
var stick: int = 0
var fibre: int = 0
var flint: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func pack():
	return items.inventory_of(1)


func chest_at(x: float, owner_peer: int, z: float = 0.0) -> int:
	var id: int = items.dev_place("chest@%s,%s,0" % [str(x), str(z)])

	if owner_peer > 0:
		items._items[id]["struct"]["owner"] = str(items._peer_key[owner_peer])

	return id


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func put(slot: int, number: int, count: int) -> void:
	pack().numbers[slot] = number
	pack().counts[slot] = count
	pack().wear[slot] = 0
	pack().fav[slot] = 0


func reset() -> void:
	for k in items._items.keys():
		var it: Dictionary = items._items[k]

		if it.has("struct") or it.has("fire") or (not it.has("scatter") and not it.has("tree") and not it.has("boulder")):
			items._items.erase(k)

	for slot in pack().SLOTS:
		put(slot, 0, 0)

	items._chest_viewer.erase(1)
	items.vitals_of(1)["weight"] = 2000.0
	done.clear()


func act(kind: int, a: int, b: int = 0, count: int = 0) -> void:
	items.action(1, kind, a, b, count, Vector3.ZERO)


func open(id: int) -> void:
	act(Net.ACT_CHEST_OPEN, id)


func bulk(kind: int, sort_key: int = 0) -> void:
	act(Net.ACT_BULK, kind, sort_key)


func total(inv, number: int) -> int:
	return inv.count_of(number)


func ids_of_done() -> Array:
	return Array(done[4]) if done.size() == 5 else []


# Whether the non-favourite stacks of slots [from, to) run in order by `order_key` with every empty slot after them.
func in_order(inv, from: int, to: int, keep_favs: bool, order_key: Callable) -> bool:
	var seen_empty: bool = false
	var last: Variant = null

	for i in range(from, to):
		if keep_favs and inv.is_fav(i):
			continue

		if inv.numbers[i] == 0:
			seen_empty = true
			continue

		if seen_empty:
			return false

		var here: Variant = order_key.call(inv, i)

		if last != null and here < last:
			return false

		last = here

	return true


func _init() -> void:
	var dir: String = "user://test_bulk_ops"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.send_carry = func(_p, _id): pass
	items.send_chest = func(_p, _id, _b): pass
	items.send_chest_info = func(_p, _id, _k, _m): pass
	items.send_craft_stock = func(_p, _n, _c): pass
	items.send_favourites = func(p, flags): favs_sent[p] = flags
	items.send_bulk_done = func(p, kind, stacks, containers, ids): done = [p, kind, stacks, containers, ids]
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "bulkops001")
	items.peer_connected_hello(2, "bulkops002")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.report_position(2, Vector3(0.0, 10.0, 40.0))
	items.admin_mode_on = func(_p): return false
	items._admin_mode_off[1] = true
	clay = items.table.number_of("clay")
	stone = items.table.number_of("stone")
	stick = items.table.number_of("stick")
	fibre = items.table.number_of("fibre")
	flint = items.table.number_of("flint")
	check(clay > 0 and stone > 0 and stick > 0 and fibre > 0 and flint > 0, "the test items are in the table")
	check(Net.PROTOCOL_VERSION >= 99 and Net.ACT_BULK == 66 and Net.ACT_FAVOURITE == 67, "protocol 99: ACT_BULK 66, ACT_FAVOURITE 67")

	# 1. The favourite flag: set by ACT_FAVOURITE, told to the client, rides with a move and a split, saved, gone when the stack is.
	reset()
	put(12, clay, 4)
	act(Net.ACT_FAVOURITE, 12, 1)
	check(pack().is_fav(12) and favs_sent.has(1) and int(favs_sent[1][12]) == 1, "ACT_FAVOURITE marks the stack and the client is sent the flags")
	act(Net.ACT_MOVE, 12, 15)
	check(pack().is_fav(15) and not pack().is_fav(12) and int(favs_sent[1][15]) == 1 and int(favs_sent[1][12]) == 0, "a favourite moves with its stack")
	put(20, stone, 10)
	act(Net.ACT_FAVOURITE, 20, 1)
	act(Net.ACT_SPLIT, 20, 0, 4)
	var split_slot: int = -1

	for slot in pack().SLOTS:
		if slot != 20 and pack().numbers[slot] == stone and pack().counts[slot] == 4:
			split_slot = slot

	check(split_slot >= 0 and pack().is_fav(split_slot) and pack().is_fav(20), "a split stack keeps the favourite on both halves (new slot %d)" % split_slot)
	var copy = InventoryScript.new(items.table)
	copy.from_json_array(pack().to_json_array())
	check(copy.is_fav(15) and copy.is_fav(20) and not copy.is_fav(0), "favourites are saved and loaded with the pack")
	var old_row: Array = [[clay, 4, 0]]
	var old = InventoryScript.new(items.table)
	old_row.resize(InventoryScript.SLOTS)

	for i in range(1, InventoryScript.SLOTS):
		old_row[i] = [0, 0, 0]

	old.from_json_array(old_row)
	check(old.numbers[0] == clay and not old.is_fav(0), "a pack saved before favourites loads with none")
	pack().take_from_slot(15, 4)
	pack().numbers[15] = clay   # the same item back in the same slot by a direct write: still not a favourite
	pack().counts[15] = 2
	check(not pack().is_fav(15), "a favourite slot that empties forgets the flag")
	act(Net.ACT_FAVOURITE, 20, 0)
	check(not pack().is_fav(20), "ACT_FAVOURITE with b = 0 clears it")

	# 2. Store all: everything past the hotbar into the open chest, except favourites; kind 1 in bulk_done with the chest's id.
	reset()
	var store_chest: int = chest_at(2.0, 1)
	put(0, stick, 5)
	put(10, clay, 4)
	put(11, fibre, 3)
	pack().set_fav(11, true)
	put(12, stone, 2)
	bulk(1)
	check(done.is_empty(), "Store all with no container open does nothing")
	open(store_chest)
	bulk(1)
	check(total(box(store_chest), clay) == 4 and total(box(store_chest), stone) == 2 and total(box(store_chest), fibre) == 0 and total(box(store_chest), stick) == 0, "Store all moves clay and stone, not the favourite fibre nor the hotbar sticks")
	check(pack().numbers[0] == stick and pack().counts[0] == 5 and pack().numbers[11] == fibre and pack().counts[11] == 3, "the hotbar slot and the favourite stay put")
	check(done.size() == 5 and int(done[1]) == 1 and int(done[2]) == 2 and int(done[3]) == 1 and ids_of_done() == [store_chest], "bulk_done: Store all, 2 stacks, 1 container, its id (got %s)" % str(done))

	# A chest takes only its kilograms (structures.json chest max_kg 40): a lighter stack still goes in after a heavy one is cut short.
	reset()
	var heavy_chest: int = chest_at(2.0, 1)
	open(heavy_chest)
	put(10, stone, 30)
	put(11, clay, 4)
	put(12, stone, 15)
	bulk(1)
	var max_kg: float = float(items._structures.get("chest", {}).get("max_kg", 0.0))
	var chest_kg: float = CarryRules.carried_kg(box(heavy_chest), items.table, items._carry_cfg)
	check(max_kg > 0.0 and chest_kg <= max_kg + 0.001 and total(box(heavy_chest), clay) == 4 and total(pack(), stone) == 45 - total(box(heavy_chest), stone) and total(pack(), stone) > 0, "Store all stops at the chest's %.0f kg (chest %.1f kg, %d stone left in the pack)" % [max_kg, chest_kg, total(pack(), stone)])

	# A fire takes only what it takes today (wood and food).
	reset()
	var fire: int = items.dev_place("campfire@2,0,0")
	open(fire)
	put(10, stick, 3)
	put(11, clay, 2)
	bulk(1)
	check(total(pack(), stick) == 0 and total(pack(), clay) == 2, "Store all at a fire puts in the sticks and keeps the clay")

	# 3. Take all: up to the carry limit.
	reset()
	var take_chest: int = chest_at(2.0, 1)
	box(take_chest).add(stone, 20)
	box(take_chest).add(clay, 5)
	items.vitals_of(1)["weight"] = 10.0   # a 7 kg limit
	open(take_chest)
	bulk(0)
	var cap: float = CarryRules.cap_kg(10.0, items._carry_cfg)
	check(items.carried_kg_of(1) <= cap + 0.01 and total(pack(), stone) > 0 and total(box(take_chest), stone) > 0, "Take all stops at the carry limit (%.1f of %.1f kg; %d stone left in the chest)" % [items.carried_kg_of(1), cap, total(box(take_chest), stone)])
	check(done.size() == 5 and int(done[1]) == 0 and ids_of_done() == [take_chest], "bulk_done: Take all, the chest's id")
	items.vitals_of(1)["weight"] = 2000.0
	bulk(0)
	check(total(box(take_chest), stone) == 0 and total(box(take_chest), clay) == 0 and total(pack(), stone) == 20 and total(pack(), clay) == 5, "with room to carry, Take all empties the chest")

	# 4. Stack to nearby: own chests within 12 m that already hold the item, keep out or not; no container open.
	reset()
	var with_clay: int = chest_at(6.0, 1)
	box(with_clay).add(clay, 1)
	var kept_out: int = chest_at(10.0, 1)
	box(kept_out).add(stone, 1)
	items._items[kept_out]["struct"]["keep_out"] = true
	var strangers: int = chest_at(3.0, 2)
	box(strangers).add(clay, 1)
	var too_far: int = chest_at(14.0, 1)
	box(too_far).add(fibre, 1)
	put(1, clay, 3)
	put(10, clay, 5)
	put(11, stone, 4)
	put(12, fibre, 3)
	put(13, flint, 2)
	put(14, clay, 2)
	pack().set_fav(14, true)
	bulk(2)
	check(total(box(with_clay), clay) == 6 and total(box(kept_out), stone) == 5, "clay joins your clay chest 6 m away, stone your keep-out chest 10 m away")
	check(total(box(strangers), clay) == 1 and total(box(too_far), fibre) == 1, "a stranger's chest and one 14 m away get nothing")
	check(pack().counts[1] == 3 and pack().counts[14] == 2 and pack().numbers[12] == fibre and pack().numbers[13] == flint, "the hotbar clay, the favourite clay, the fibre and the flint (no chest holds it) stay")
	var nearby_ids: Array = ids_of_done()
	nearby_ids.sort()
	var want_ids: Array = [with_clay, kept_out]
	want_ids.sort()
	check(done.size() == 5 and int(done[1]) == 2 and int(done[2]) == 2 and int(done[3]) == 2 and nearby_ids == want_ids, "bulk_done: Stack to nearby, 2 stacks into 2 chests, their ids (got %s)" % str(done))

	# 5. Sort: the pack past the hotbar by the key, favourites fixed, empty slots last; an open chest too.
	reset()
	put(0, stone, 1)
	put(10, stone, 3)
	put(11, flint, 1)
	pack().set_fav(11, true)
	put(13, clay, 2)
	put(16, fibre, 5)
	put(20, stick, 2)
	var sort_chest: int = chest_at(2.0, 1)
	box(sort_chest).numbers[0] = stone
	box(sort_chest).counts[0] = 1
	box(sort_chest).numbers[3] = clay
	box(sort_chest).counts[3] = 1
	box(sort_chest).numbers[5] = fibre
	box(sort_chest).counts[5] = 1
	open(sort_chest)
	var by_name: Callable = func(inv, i: int) -> Variant: return items.table.name_of(inv.numbers[i]).to_lower()
	bulk(3, 1)
	check(pack().numbers[0] == stone and pack().counts[0] == 1 and pack().numbers[11] == flint and pack().is_fav(11), "Sort leaves the hotbar and the favourite where they are")
	check(in_order(pack(), 10, pack().SLOTS, true, by_name) and total(pack(), stone) == 4 and total(pack(), clay) == 2 and total(pack(), fibre) == 5 and total(pack(), stick) == 2, "Sort by name: the rest in name order, empties last, nothing lost")
	check(in_order(box(sort_chest), 0, box(sort_chest).usable, false, by_name) and box(sort_chest).numbers[2] != 0 and box(sort_chest).numbers[3] == 0, "the open chest is sorted too, its stacks first")
	check(done.size() == 5 and int(done[1]) == 3 and ids_of_done() == [sort_chest], "bulk_done: Sort, with the chest's id")
	var heavy_first: Callable = func(inv, i: int) -> Variant: return -CarryRules.weight_of(items.table.id_of(inv.numbers[i]), items._carry_cfg) * float(inv.counts[i])
	bulk(3, 3)
	check(in_order(pack(), 10, pack().SLOTS, true, heavy_first) and pack().numbers[11] == flint, "Sort by weight, heaviest first, round the favourite")

	print("bulk ops: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
