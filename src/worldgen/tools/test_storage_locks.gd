extends SceneTree

# Storage locks and views (catalog Phase 9, M001-T13; master s3.13 [D13], docs/design/STORAGE_WAREHOUSING_DESIGN.md s5 and s6): real server state with
# three players. An unlocked container opens for anyone; the owner sets the four-digit code 0042 (leading zeros) and opens without it; a stranger is
# refused, enters the code and gets in, for themselves only; wrong codes give 10/20/30/40 s waits that survive a reconnect and a restart; the right
# code resets the count; the owner lets a player in and a new code drops only the code-based access; nobody else changes the lock or takes a locked
# container down. The Warehouse desk lists only what the player may open, withdraws and deposits only through those containers, and takes priority
# over a Storage sign; containers refuse what they do not take. Every transfer keeps the item totals. Save and load keep owner, lock, grants and waits.
#   godot --headless --path . --script res://src/worldgen/tools/test_storage_locks.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const DIR := "user://test_storage_locks"

var failures: int = 0
var items
var clock: Array = [1.0e6]
var chest_sends: Dictionary = {}   # peer -> how many chest_contents they were sent
var locks: Dictionary = {}         # peer -> the last chest_lock [id, locked, mine, may_open, wait_s, allowed]
var views: Dictionary = {}         # peer -> the last storage_view [id, {number: total}, containers]
var keys: Dictionary = {1: "lockowner01", 2: "lockguest02", 3: "lockthird03"}
var stone: int = 0
var flint: int = 0
var stick: int = 0
var log_n: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_notice = func(_p, _t): pass
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(p, _id, _b): chest_sends[p] = int(chest_sends.get(p, 0)) + 1
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(p, id, locked, mine, may_open, wait_s, allowed): locks[p] = [id, locked, mine, may_open, wait_s, allowed]
	s.send_storage_view = func(p, id, numbers, counts, containers):
		var totals: Dictionary = {}
		for i in numbers.size():
			totals[int(numbers[i])] = int(counts[i])
		views[p] = [id, totals, containers]
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.ground_height = func(_x, _z): return 10.0
	s.unix_now = func(): return clock[0]
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	return s


func join(peer: int, key: String, at: Vector3) -> void:
	items.peer_connected_hello(peer, key)
	items.report_position(peer, at)
	items.vitals_of(peer)["weight"] = 2000.0


func act(peer: int, kind: int, a: int, b: int = 0, count: int = 0) -> void:
	items.action(peer, kind, a, b, count, Vector3.ZERO)


func lock(peer: int, id: int, op: int, code: int = 0) -> void:
	act(peer, Net.ACT_CHEST_LOCK, id, op, code)


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func place(spec: String, owner_peer: int) -> int:
	var id: int = items.dev_place(spec)

	if owner_peer > 0:
		items._items[id]["struct"]["owner"] = keys[owner_peer]

	return id


func opens(peer: int, id: int) -> bool:
	var before: int = int(chest_sends.get(peer, 0))
	act(peer, Net.ACT_CHEST_OPEN, id)
	return int(chest_sends.get(peer, 0)) > before


# The world id of the placed container with this persistent uid (world ids are handed out afresh at every load), 0 none.
func id_of_uid(uid: int) -> int:
	for id in items._items:
		if items._items[id].has("struct") and int(items._items[id]["struct"].get("uid", 0)) == uid:
			return id

	return 0


# The first pack slot holding an item, -1 none.
func slot_of(peer: int, number: int) -> int:
	for s in items.inventory_of(peer).slot_count:
		if items.inventory_of(peer).numbers[s] == number:
			return s

	return -1


# Every unit of an item in the packs of the given peers and in every container.
func total(number: int, peers: Array) -> int:
	var n: int = 0

	for p in peers:
		if items.inventory_of(p) != null:
			n += items.inventory_of(p).count_of(number)

	for uid in items._chests:
		n += items._chests[uid].count_of(number)

	return n


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	stone = items.table.number_of("stone")
	flint = items.table.number_of("flint")
	stick = items.table.number_of("stick")
	log_n = items.table.number_of("log")
	join(1, keys[1], Vector3(0.0, 10.0, 1.0))
	join(2, keys[2], Vector3(0.0, 10.0, 2.5))
	join(3, keys[3], Vector3(0.0, 10.0, 40.0))

	# The data: the sixteen rows are live, the chests and crates lockable, the views have radii and a desk outranks a sign.
	for kind in ["large_wooden_chest", "wardrobe", "dresser", "bookcase", "apothecary_cabinet", "bottle_and_jar_rack", "tool_cabinet", "open_storage_bin", "firewood_rack", "log_rack", "board_rack", "masons_pallet", "ore_and_metal_rack", "storage_sign", "warehouse_crate", "warehouse_desk"]:
		check(items._structures.has(kind) and not bool(items.table.entry(kind).get("future", false)), "%s is a live structure row" % kind)

	check(bool(items._structures["wooden_crate"].get("lockable", false)) and bool(items._structures["warehouse_crate"].get("lockable", false)) and not bool(items._structures.get("wooden_shelf", {}).get("lockable", false)), "crates and chests take a code lock, shelves do not")
	check(int(items._structures["large_wooden_chest"]["slots"]) <= 30 and float(items._structures["large_wooden_chest"]["max_kg"]) > float(items._structures["iron_chest"]["max_kg"]), "the Large wooden chest holds more weight than the Ornate - Chest within 30 slots [D17]")
	check(float(items._structures["warehouse_crate"]["max_kg"]) > float(items._structures["wooden_crate"]["max_kg"]), "the Warehouse crate carries more than the Crate (freight role)")
	check(ItemsScript.lock_code(42) == "0042" and ItemsScript.lock_code(0) == "0000" and ItemsScript.lock_code(9999) == "9999" and ItemsScript.lock_code(10000) == "" and ItemsScript.lock_code(-1) == "", "codes are four digit characters with leading zeros, 0000 to 9999")

	# 1. An open container: anyone beside it opens it and takes from it.
	var crate: int = place("warehouse_crate@0,0,0", 1)
	box(crate).add(stone, 10)
	check(opens(2, crate), "a stranger opens an unlocked crate")
	act(2, Net.ACT_CHEST_TAKE, 0, crate, 2)
	check(box(crate).count_of(stone) == 8 and items.inventory_of(2).count_of(stone) == 2, "and takes 2 stones from it")
	var stones: int = total(stone, [1, 2, 3])

	# 2. The owner sets 0042: the code is not stored, the owner opens without it.
	lock(2, crate, ItemsScript.LOCK_SET, 1111)
	check(not items._items[crate]["struct"].has("lock"), "only the owner sets a code")
	lock(1, crate, ItemsScript.LOCK_SET, 42)
	var saved_lock: String = JSON.stringify(items._items[crate]["struct"].get("lock", {}))
	check(items._items[crate]["struct"].has("lock") and not saved_lock.contains("0042") and not saved_lock.contains("\"42\""), "the owner locks it with 0042 and only a salted hash is kept")
	check(locks.get(1, []).size() == 6 and bool(locks[1][1]) and bool(locks[1][2]) and bool(locks[1][3]), "the owner is told it is locked, theirs and open to them")
	check(opens(1, crate), "the owner opens the locked crate without the code")

	# 3. A stranger is refused everything.
	check(not opens(2, crate) and not bool(locks[2][3]) and bool(locks[2][1]) and not bool(locks[2][2]), "a stranger is refused and told it is locked")
	items.inventory_of(2).add(stick, 3)
	act(2, Net.ACT_CHEST_PUT, slot_of(2, stick), crate, 3)
	act(2, Net.ACT_CHEST_TAKE, 0, crate, 8)
	check(box(crate).count_of(stone) == 8 and box(crate).count_of(stick) == 0 and items.inventory_of(2).count_of(stone) == 2, "a stranger can neither put into nor take from it")
	items._chest_viewer[2] = crate
	act(2, Net.ACT_BULK, 0)
	check(box(crate).count_of(stone) == 8, "Take all does not pass the lock")
	lock(2, crate, ItemsScript.LOCK_CLEAR)
	check(items._items[crate]["struct"].has("lock"), "a stranger cannot take the lock off")
	var empty_crate: int = place("wooden_crate@1,0,0", 1)
	lock(1, empty_crate, ItemsScript.LOCK_SET, 7)
	act(2, Net.ACT_PICKUP, empty_crate)
	check(items._items.has(empty_crate), "a stranger cannot take down an empty locked crate")

	# 4. Wrong codes: 10, 20, 30, 40 s; a try during the wait is refused and not counted; 0420 is not 0042.
	lock(2, crate, ItemsScript.LOCK_TRY, 420)
	check(int(locks[2][4]) == 10 and not bool(locks[2][3]), "the first wrong code (0420) means a 10 s wait")
	lock(2, crate, ItemsScript.LOCK_TRY, 42)
	check(not items._may_access(2, items._items[crate]) and int(items._items[crate]["struct"]["lock"]["tries"][keys[2]][0]) == 1, "the right code during the wait is refused and not counted")
	clock[0] += 10.0
	lock(2, crate, ItemsScript.LOCK_TRY, 1)
	check(int(locks[2][4]) == 20, "the second wrong code means 20 s")
	clock[0] += 20.0
	lock(2, crate, ItemsScript.LOCK_TRY, 2)
	check(int(locks[2][4]) == 30, "the third wrong code means 30 s")
	clock[0] += 30.0
	lock(2, crate, ItemsScript.LOCK_TRY, 3)
	check(int(locks[2][4]) == 40, "the fourth wrong code means 40 s")
	clock[0] += 5.0

	# 5. A reconnect keeps the wait (it is the character's, not the connection's).
	items.peer_left(2)
	join(5, keys[2], Vector3(0.0, 10.0, 2.5))
	act(5, Net.ACT_CHEST_OPEN, crate)
	check(locks.get(5, []).size() == 6 and int(locks[5][4]) == 35 and not bool(locks[5][3]), "after a reconnect the wait still has 35 s to run")
	lock(5, crate, ItemsScript.LOCK_TRY, 42)
	check(not items._may_access(5, items._items[crate]), "the right code is still refused while it runs")

	# 6. A restart keeps the wait, the owner and the lock.
	items.inventory_of(5).add(stone, 5)
	stones += 5
	items._dirty = true
	items.save()
	var crate_uid: int = int(items._items[crate]["struct"]["uid"])
	var empty_uid: int = int(items._items[empty_crate]["struct"]["uid"])
	items = make_server()
	crate = id_of_uid(crate_uid)
	empty_crate = id_of_uid(empty_uid)
	join(1, keys[1], Vector3(0.0, 10.0, 1.0))
	join(2, keys[2], Vector3(0.0, 10.0, 2.5))
	join(3, keys[3], Vector3(0.0, 10.0, 40.0))
	check(crate != 0 and str(items._items[crate]["struct"].get("owner", "")) == keys[1] and items._items[crate]["struct"].has("lock"), "after a restart the crate keeps its owner and its lock")
	check(box(crate).count_of(stone) == 8 and total(stone, [1, 2, 3]) == stones, "and its contents; no stone lost or made (%d)" % total(stone, [1, 2, 3]))
	act(2, Net.ACT_CHEST_OPEN, crate)
	check(int(locks[2][4]) == 35, "after a restart the wait still has 35 s to run (%d)" % int(locks[2][4]))
	check(opens(1, crate), "the owner still opens it without the code")
	clock[0] += 35.0
	check(not opens(3, crate), "the third player is refused")
	var sends: int = int(chest_sends.get(2, 0))
	lock(2, crate, ItemsScript.LOCK_TRY, 42)
	check(int(chest_sends.get(2, 0)) > sends and items._may_access(2, items._items[crate]), "the wait over, 0042 opens it for the stranger")
	check(not items._items[crate]["struct"]["lock"]["tries"].has(keys[2]), "the right code resets their failure count")
	check(not items._may_access(3, items._items[crate]), "a code opens it for that player only: it stays locked for others")
	act(2, Net.ACT_CHEST_TAKE, 0, crate, 3)
	check(box(crate).count_of(stone) == 5 and total(stone, [1, 2, 3]) == stones, "the stranger with the code takes 3 stones; totals kept")

	# 7. The owner lets a player in; a new code drops code-based access only.
	items.report_position(3, Vector3(0.5, 10.0, 0.5))
	items.report_position(2, Vector3(0.0, 10.0, 3.9))
	lock(1, crate, ItemsScript.LOCK_ALLOW)
	check(items._may_access(3, items._items[crate]) and int(locks[1][5]) == 2, "the owner lets in the player beside it (2 others have access)")
	lock(3, crate, ItemsScript.LOCK_ALLOW)
	check((items._items[crate]["struct"]["lock"]["allow"] as Array).size() == 1, "a let-in player cannot let others in")
	lock(1, crate, ItemsScript.LOCK_SET, 9000)
	check(not items._may_access(2, items._items[crate]) and items._may_access(3, items._items[crate]), "a new code drops the code-based access; the owner's grant stays")
	lock(1, crate, ItemsScript.LOCK_REVOKE)
	check(not items._may_access(3, items._items[crate]) and items._may_access(1, items._items[crate]), "withdrawing access leaves only the owner")
	lock(1, crate, ItemsScript.LOCK_ALLOW)
	items.report_position(2, Vector3(0.0, 10.0, 2.5))
	items.report_position(3, Vector3(0.0, 10.0, 40.0))

	# 8. The Warehouse desk: only what this player may open, nearest first; the desk outranks a sign.
	var open_crate: int = place("wooden_crate@3,0,0", 2)
	box(open_crate).add(stone, 4)
	stones += 4
	var secret: int = place("iron_chest@-3,0,0", 1)
	box(secret).add(flint, 6)
	lock(1, secret, ItemsScript.LOCK_SET, 1)   # the owner stands 3.2 m from it
	check(items._items[secret]["struct"].has("lock"), "the owner locks the chest holding flint")
	var desk: int = place("warehouse_desk@0,0,2", 1)
	var sign: int = place("storage_sign@4,0,1", 2)
	var far_crate: int = place("wooden_crate@10,0,0", 2)   # within both the sign's 8 m and the desk's 16 m
	box(far_crate).add(stick, 2)
	act(2, Net.ACT_VIEW_OPEN, desk)
	var seen: Dictionary = views.get(2, [0, {}, 0])[1]
	check(int(views.get(2, [0])[0]) == desk and int(seen.get(stone, 0)) == 4 and not seen.has(flint), "the desk shows a stranger the open crate's stones and nothing of the locked chest (%s)" % str(seen))
	check(int(views[2][2]) == 2, "two containers there are open to the stranger: the two unlocked crates, not the three locked ones (%d)" % int(views[2][2]))
	act(1, Net.ACT_VIEW_OPEN, desk)
	check(int(views[1][1].get(flint, 0)) == 6 and int(views[1][1].get(stone, 0)) == 4 + 5, "the owner sees the flint in their locked chest and the stones in their crate")
	items.report_position(2, Vector3(4.0, 10.0, 2.0))
	act(2, Net.ACT_VIEW_OPEN, sign)
	check(int(views[2][0]) == sign and views[2][1].is_empty() and int(views[2][2]) == 0, "the sign shows nothing the desk covers (one context a container: the desk first)")
	items.report_position(2, Vector3(0.0, 10.0, 2.5))

	# 9. Withdraw and deposit through the desk obey the locks and keep the totals.
	var flints: int = total(flint, [1, 2, 3])
	act(2, Net.ACT_VIEW_TAKE, desk, flint, 6)
	check(box(secret).count_of(flint) == 6 and items.inventory_of(2).count_of(flint) == 0, "the stranger cannot withdraw flint from the locked chest through the desk")
	var pack_stones: int = items.inventory_of(2).count_of(stone)
	act(2, Net.ACT_VIEW_TAKE, desk, stone, 3)
	check(items.inventory_of(2).count_of(stone) == pack_stones + 3 and box(open_crate).count_of(stone) == 1 and box(crate).count_of(stone) == 5 and total(stone, [1, 2, 3]) == stones, "the stranger withdraws 3 stones from the open crate only; totals kept (pack %d, open %d, crate %d, total %d of %d)" % [items.inventory_of(2).count_of(stone), box(open_crate).count_of(stone), box(crate).count_of(stone), total(stone, [1, 2, 3]), stones])
	act(2, Net.ACT_VIEW_PUT, desk, slot_of(2, stone), 2)
	check(box(open_crate).count_of(stone) == 3 and box(crate).count_of(stone) == 5 and box(secret).count_of(stone) == 0 and total(stone, [1, 2, 3]) == stones, "a deposit through the desk goes into the open crate, never a locked one; totals kept (open %d, crate %d, total %d of %d)" % [box(open_crate).count_of(stone), box(crate).count_of(stone), total(stone, [1, 2, 3]), stones])
	act(1, Net.ACT_VIEW_TAKE, desk, flint, 2)
	check(items.inventory_of(1).count_of(flint) == 2 and box(secret).count_of(flint) == 4 and total(flint, [1, 2, 3]) == flints, "the owner withdraws flint from their locked chest at the desk without a code")
	items.report_position(2, Vector3(0.0, 10.0, 30.0))
	act(2, Net.ACT_VIEW_TAKE, desk, stone, 1)
	check(box(open_crate).count_of(stone) == 3, "nothing moves from out of the desk's reach")
	items.report_position(2, Vector3(0.0, 10.0, 2.5))

	# 10. Containers take what they are for.
	var rack: int = place("log_rack@-1,0,3", 1)
	items.inventory_of(1).add(stone, 1)
	stones += 1
	act(1, Net.ACT_CHEST_PUT, slot_of(1, stone), rack, 1)
	check(box(rack).count_of(stone) == 0, "a log rack refuses a stone")
	check(items._box_takes("log_rack", items.table.number_of("log_oak")) and items._box_takes("log_rack", log_n) and not items._box_takes("log_rack", stone), "a log rack takes any log")
	check(items._box_takes("wardrobe", items.table.number_of("grass_skirt")) and not items._box_takes("wardrobe", stone), "a wardrobe takes clothing, not stone")
	check(items._box_takes("warehouse_crate", stone) and items._box_takes("large_wooden_chest", flint), "general containers take anything")

	# 11. Save and load keep grants and contents; no unit lost or made.
	items._dirty = true
	items.save()
	var uids: Array = [int(items._items[crate]["struct"]["uid"]), int(items._items[empty_crate]["struct"]["uid"]), int(items._items[secret]["struct"]["uid"]), int(items._items[open_crate]["struct"]["uid"])]
	items = make_server()
	crate = id_of_uid(uids[0])
	empty_crate = id_of_uid(uids[1])
	secret = id_of_uid(uids[2])
	open_crate = id_of_uid(uids[3])
	join(1, keys[1], Vector3(0.0, 10.0, 1.0))
	join(3, keys[3], Vector3(0.5, 10.0, 0.5))
	check((items._items[crate]["struct"]["lock"]["allow"] as Array).has(keys[3]) and items._may_access(3, items._items[crate]), "the owner's grant survives a restart")
	check(items._items[secret]["struct"].has("lock") and box(secret).count_of(flint) == 4 and box(open_crate).count_of(stone) == 3, "locks and contents survive a restart")
	lock(1, crate, ItemsScript.LOCK_CLEAR)
	check(not items._items[crate]["struct"].has("lock") and opens(3, crate), "the owner takes the lock off: anyone opens it again")
	act(1, Net.ACT_PICKUP, empty_crate)
	check(not items._items.has(empty_crate), "the owner takes the empty locked crate down")

	# 12. Hammer repair sourcing, live pushes, Store all and Stack to nearby obey the locks and the content rules (review M001-T13).
	check(not items._boxes_near(3).any(func(row): return int(row[0]) == secret) and items._boxes_near(1).any(func(row): return int(row[0]) == secret), "hammer repair draws on a locked chest for its owner only")
	items._chest_viewer[3] = secret
	items._chest_viewer[1] = secret
	var sent_3: int = int(chest_sends.get(3, 0))
	var sent_1: int = int(chest_sends.get(1, 0))
	items._push_box(secret, box(secret))
	check(int(chest_sends.get(3, 0)) == sent_3 and int(chest_sends.get(1, 0)) == sent_1 + 1, "a live push of a locked chest reaches its owner, not a stranger who had it open")
	items._chest_viewer.erase(3)
	var fw_rack: int = place("firewood_rack@-1,0,3", 1)
	var firewood: int = items.table.number_of("firewood")
	items.inventory_of(1).add(firewood, 3)
	items.inventory_of(1).add(stone, 2)
	var pack_stone: int = items.inventory_of(1).count_of(stone)
	act(1, Net.ACT_CHEST_OPEN, fw_rack)
	act(1, Net.ACT_BULK, 1)
	check(box(fw_rack).count_of(firewood) == 3 and box(fw_rack).count_of(stone) == 0 and items.inventory_of(1).count_of(stone) == pack_stone, "Store all puts the firewood in the firewood rack and keeps the stones")
	var clay: int = items.table.number_of("clay")
	box(fw_rack).add(clay, 1)   # a stack it would not take (as if the rule changed); no other container holds clay
	items.inventory_of(1).add(clay, 2)
	act(1, Net.ACT_BULK, 2)
	check(box(fw_rack).count_of(clay) == 1 and items.inventory_of(1).count_of(clay) == 2, "Stack to nearby does not add clay to a firewood rack that holds some (rack %d)" % box(fw_rack).count_of(clay))

	# 13. A damaged lock row on an owned container loads fail-closed: only the owner opens it, and the owner can set a new code.
	var secret_uid: int = int(items._items[secret]["struct"]["uid"])
	items._dirty = true
	items.save()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/world_items.json"))
	var broke: int = 0

	for row in saved["items"]:
		if row.size() > 17 and int(row[10]) == secret_uid:
			row[17] = "{\"salt\": 7, \"hash\": \"short\"}"
			broke += 1

	var f: FileAccess = FileAccess.open(DIR + "/world_items.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(saved))
	f.close()
	items = make_server()
	secret = id_of_uid(secret_uid)
	join(1, keys[1], Vector3(0.0, 10.0, 1.0))
	join(3, keys[3], Vector3(-2.5, 10.0, 0.5))
	check(broke == 1 and items._items[secret]["struct"].has("lock") and items._may_access(1, items._items[secret]) and not items._may_access(3, items._items[secret]), "a damaged lock loads fail-closed: the owner opens it, nobody else")
	lock(3, secret, ItemsScript.LOCK_TRY, 1)
	check(not items._may_access(3, items._items[secret]), "no code opens a damaged lock")
	lock(1, secret, ItemsScript.LOCK_SET, 5)
	clock[0] += 100.0
	lock(3, secret, ItemsScript.LOCK_TRY, 5)
	check(items._may_access(3, items._items[secret]), "the owner sets a new code and it works again")

	print("test_storage_locks: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
