extends SceneTree

# Four players at once in one place (coordinator, 23 Nov 2026: "your tests so far are pairs"): the same chest open by all four, all four
# taking the same stack or the same pickup, one blueprint site hammered by four each holding part of its cost, a fight with four on one
# deer and its carcass worked by four knives of different metals, and four characters from the 9257 fixture (the live server's world)
# joining within the same moment. The server takes actions one at a time, so each case checks what can still go wrong with more hands:
# every item counted over packs, containers and the ground stays the same, what each player was last sent about a shared container is
# what it holds, one deer makes one carcass, and its parts are handed out once.
#   godot --headless --path . --script res://src/worldgen/tools/test_four_players.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const PlayersScript := preload("res://src/stream/server_players.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")

const HERE := Vector3(0.0, 10.0, 0.0)
const PEERS := [1, 2, 3, 4]
const AROUND := [Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0)]

var failures: int = 0
var seen: Dictionary = {}   # peer -> {container id: Inventory last sent}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _count(inv, number: int) -> int:
	var n: int = 0

	if inv == null:
		return 0

	for slot in range(inv.slot_count):
		if inv.numbers[slot] == number:
			n += int(inv.counts[slot])

	return n


func _slot_of(inv, number: int) -> int:
	for slot in range(inv.slot_count):
		if inv.numbers[slot] == number:
			return slot

	return -1


func _total(items, number: int) -> int:
	var n: int = 0

	for peer in items._peer_key:
		n += _count(items.inventory_of(peer), number)

	for uid in items._chests:
		n += _count(items._chests[uid], number)

	for id in items._items:
		if int(items._items[id].get("number", 0)) == number and not items._items[id].has("struct"):
			n += int(items._items[id].get("count", 1))

	return n


func _all_views_true(items, id: int, number: int) -> bool:
	var uid: int = int(items._items[id]["struct"]["uid"])

	for peer in PEERS:
		var box = seen.get(peer, {}).get(id, null)

		if box == null or _count(box, number) != _count(items._chests[uid], number):
			return false

	return true


func _init() -> void:
	var dir: String = "user://test_four_players"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	var table = ItemTableScript.load_default()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_chest = func(p, id, bytes):
		var box = InventoryScript.new(table)
		box.from_bytes(bytes)

		if not seen.has(p):
			seen[p] = {}

		seen[p][id] = box
	items.setup(table, dir)
	items.ground_height = func(_x, _z): return 10.0
	var stone: int = table.number_of("stone")

	for i in PEERS.size():
		items.peer_connected_hello(PEERS[i], "fourplayers_%d" % PEERS[i])
		items.report_position(PEERS[i], HERE + AROUND[i] * 1.2)
		items.give(PEERS[i], stone, 10)

	var all: int = _total(items, stone)

	# 1. One chest in the middle, open by all four: each puts 3 in turn; all four are shown the 12.
	var spot: Vector3 = HERE
	items.place_piece(1, "chest_kit", spot)
	var chest: int = -1

	for id in items._items:
		if items._items[id].has("struct") and items._items[id]["struct"].has("uid") and (items._items[id]["pos"] as Vector3).distance_to(spot) < 0.5:
			chest = int(id)

	check(chest >= 0, "a chest stands among the four")

	if chest < 0:
		quit(1)
		return

	var uid: int = int(items._items[chest]["struct"]["uid"])

	for peer in PEERS:
		items.action(peer, Net.ACT_CHEST_OPEN, chest, 0, 0, Vector3.ZERO)

	for peer in PEERS:
		items.action(peer, Net.ACT_CHEST_PUT, _slot_of(items.inventory_of(peer), stone), chest, 3, Vector3.ZERO)

	check(_count(items._chests[uid], stone) == 12 and _all_views_true(items, chest, stone), "all four put 3 in: 12 in the chest, and all four are shown 12")

	# 2. All four take the same stack in the same moment: 12 taken in all, the chest empty, nothing made or lost.
	var before: Dictionary = {}

	for peer in PEERS:
		before[peer] = _count(items.inventory_of(peer), stone)

	var slot: int = _slot_of(items._chests[uid], stone)

	for peer in PEERS:
		items.action(peer, Net.ACT_CHEST_TAKE, slot, chest, 12, Vector3.ZERO)

	var got: Array = PEERS.map(func(p): return _count(items.inventory_of(p), stone) - int(before[p]))
	check(got.reduce(func(a, b): return a + b, 0) == 12 and _count(items._chests[uid], stone) == 0, "all four take the 12 at once: 12 taken in all %s, the chest empty" % str(got))
	check(_total(items, stone) == all and _all_views_true(items, chest, stone), "no stone made or lost (%d, was %d), and all four are shown it empty" % [_total(items, stone), all])

	# 3. All four pick up the same dropped stack: one gets it.
	items.action(2, Net.ACT_DROP, _slot_of(items.inventory_of(2), stone), 0, 5, HERE + Vector3(0.4, 0.0, 0.4))
	var dropped: int = -1

	for id in items._items:
		if int(items._items[id].get("number", 0)) == stone and not items._items[id].has("struct"):
			dropped = int(id)

	for peer in PEERS:
		before[peer] = _count(items.inventory_of(peer), stone)

	for peer in PEERS:
		items.action(peer, Net.ACT_PICKUP, dropped, 0, 0, Vector3.ZERO)

	got = PEERS.map(func(p): return _count(items.inventory_of(p), stone) - int(before[p]))
	check(dropped >= 0 and got.count(5) == 1 and got.count(0) == 3 and not items._items.has(dropped), "all four pick up the same 5 at once: one gets them %s, none left" % str(got))
	check(_total(items, stone) == all, "no stone made or lost (%d, was %d)" % [_total(items, stone), all])

	# 4. One blueprint site hammered by four, each holding part of its cost (5 lumber, 8 copper nails): exactly the cost goes in.
	var crate_bp: Dictionary = {}

	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == "wooden_crate":
			crate_bp = items._blueprints[number]

	var lumber: int = table.number_of("lumber")
	var nails: int = table.number_of("copper_nails")

	for i in PEERS.size():
		items.give(PEERS[i], table.number_of("stone_hammer"), 1)
		items.give(PEERS[i], lumber, 2)   # 8 lumber among them for a cost of 5
		items.give(PEERS[i], nails, 3)    # 12 nails for a cost of 8

	var wood_all: int = _total(items, lumber)
	var nails_all: int = _total(items, nails)
	var site_spot: Vector3 = HERE + Vector3(0.0, 0.0, 2.5)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(crate_bp.get("number", -1)), 0, 0, site_spot)
	var site: int = HeldTool.site_of(items, "wooden_crate")
	check(site >= 0, "player 1 sets down a crate blueprint")

	for round_n in range(3):
		for peer in PEERS:
			HeldTool.hit_site(items, site, peer)

	check(site >= 0 and items._items.has(site) and not items._items[site]["struct"].has("site"), "the four hammers finish it: the crate stands")
	check(wood_all - _total(items, lumber) == 5 and nails_all - _total(items, nails) == 8, "exactly its cost went in, once: %d lumber of 5, %d nails of 8" % [wood_all - _total(items, lumber), nails_all - _total(items, nails)])

	# 5. A fight with four on one deer: struck from four sides, it dies once and leaves one carcass; blows after that hit nothing.
	var zoo = AnimalsScript.new()
	zoo.ground_height = func(_x, _z): return 10.0
	zoo.blocked = func(_x, _z): return false
	zoo.player_positions = func(): return PEERS.map(func(p): return items._peer_pos[p])
	zoo.setup()
	zoo.traits = false

	for sp in zoo.cfg["species"]:
		zoo.cfg["species"][sp]["target_per_player"] = 0

	zoo.rng.seed = 4
	var deaths: Array = []
	zoo.died = func(sp, pos, p): deaths.append(items.make_carcass(sp, pos, p))
	var struck: Dictionary = {}   # peer -> blows that landed on the deer
	items.hit_animal = func(peer, origin, aim, reach, amount) -> bool:
		var target: int = zoo.target_along(origin, aim, reach)

		if target != 0:
			struck[peer] = int(struck.get(peer, 0)) + 1

		return target != 0 and (zoo.damage(target, amount, peer, "spear") or true)
	var at: Vector3 = Vector3(30.0, 10.0, 0.0)

	for i in PEERS.size():
		items.report_position(PEERS[i], at + AROUND[i] * 1.5)
		items.give(PEERS[i], table.number_of("wooden_spear"), 1)

	var deer: int = zoo.spawn("deer", at.x, at.z)
	var blows: int = 0

	for round_n in range(30):
		for i in PEERS.size():
			items._last_strike.erase(PEERS[i])
			items.action(PEERS[i], Net.ACT_STRIKE, _slot_of(items.inventory_of(PEERS[i]), table.number_of("wooden_spear")), 0, 0, -AROUND[i])
			blows += 1 if zoo.animals.has(deer) else 0

		if not zoo.animals.has(deer):
			break

	check(deer != 0 and not zoo.animals.has(deer) and struck.size() >= 3, "spears from all sides bring the deer down (%d blows, %d of the four landed one)" % [blows, struck.size()])
	check(deaths.size() == 1 and int(deaths[0]) != 0 and items._items.has(int(deaths[0])), "it dies once and leaves one carcass (%d)" % deaths.size())

	for i in PEERS.size():
		items._last_strike.erase(PEERS[i])
		items.action(PEERS[i], Net.ACT_STRIKE, _slot_of(items.inventory_of(PEERS[i]), table.number_of("wooden_spear")), 0, 0, -AROUND[i])

	check(deaths.size() == 1, "blows after it fell make no second carcass")

	# 6. The carcass worked by four knives of different metals at once: its parts are handed out once, then it is gone.
	var carcass: int = int(deaths[0]) if not deaths.is_empty() else 0
	var knives: Array = ["iron_knife", "stone_knife", "copper_knife", "steel_knife"]   # a deer takes 4 blows by its knife's speed (carcass.json): iron 2, stone and copper 4, steel 2 (speed 2.5): in this order all four cut

	for i in PEERS.size():
		items.give(PEERS[i], table.number_of(knives[i]), 1)

	var part_ids: Array = []

	for row in items._carcass_cfg.get("species", {}).get("deer", {}).get("parts", []):
		part_ids.append(str(row[0]))

	var parts_before: Dictionary = {}

	for id in part_ids:
		parts_before[id] = _total(items, table.number_of(id))

	var rolled: Dictionary = {}
	var cut: Dictionary = {}   # peer -> its blow changed the carcass (or finished it)

	for round_n in range(12):
		for i in PEERS.size():
			if not items._items.has(carcass):
				break

			items._last_process.erase(PEERS[i])
			var was: String = str(items._items[carcass]["struct"])
			items.action(PEERS[i], Net.ACT_PROCESS, carcass, 0, 0, Vector3(float(_slot_of(items.inventory_of(PEERS[i]), table.number_of(knives[i])) + 1), 0.0, 0.0))

			if not items._items.has(carcass) or str(items._items[carcass]["struct"]) != was:
				cut[PEERS[i]] = true

			if rolled.is_empty() and items._items.has(carcass) and items._items[carcass]["struct"].has("parts"):
				for part in items._items[carcass]["struct"]["parts"]:   # what is left after the first blow, plus what it gave: the rolled parts
					rolled[str(part[0])] = int(part[1]) + _total(items, table.number_of(str(part[0]))) - int(parts_before[str(part[0])])

	check(carcass != 0 and not items._items.has(carcass) and cut.size() == 4, "four knives work the carcass and it is gone (%d of the four cut it)" % cut.size())
	var given_ok: bool = not rolled.is_empty()

	for id in rolled:
		given_ok = given_ok and _total(items, table.number_of(id)) - int(parts_before[id]) == int(rolled[id])

	check(given_ok, "its parts were handed out exactly once among the four %s" % str(rolled))

	# 7. Four characters from the 9257 fixture join in the same moment: each starts where it was (or as new), with its own pack, and
	# each of the four sees the other three.
	_fixture_join()
	print("test_four_players: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)


func _fixture_join() -> void:
	var fixture: String = "res://src/worldgen/tools/save_fixtures/build_9257"
	var dir: String = "user://test_four_players_9257"

	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(dir + sub)

		for file in DirAccess.get_files_at(dir + sub):
			DirAccess.remove_absolute(dir + sub + "/" + file)

	for sub in ["", "/world_items"]:
		for file in DirAccess.get_files_at(fixture + sub):
			if file.ends_with(".json") and file != "expected_snapshot.json":
				var f: FileAccess = FileAccess.open(dir + ("/" + ItemsScript.AREA_DIR if sub != "" else "") + "/" + file, FileAccess.WRITE)
				f.store_string(FileAccess.get_file_as_string(fixture + sub + "/" + file))
				f.close()

	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture + "/expected_snapshot.json"))
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture + "/characters.json"))["players"]
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 6.0
	items.setup(ItemTableScript.load_default(), dir)
	var table = items.table
	var keys: Array = ["fixture9257a01", "fixture9257b02", "loadbot_bot1", "loadbot_bot2"]
	var peers: Array = [801, 802, 803, 804]
	var starts: Array = []

	for i in keys.size():
		items.peer_connected_hello(peers[i], keys[i])   # all four hellos before any report: the same moment

	for i in keys.size():
		starts.append(items.start_position_for(peers[i]))

	for i in keys.size():
		var saved: Array = (stored[keys[i]] as Dictionary).get("last", {}).get("pos", [])
		var start: Array = starts[i]
		var spot_ok: bool = start.is_empty() if saved.size() != 3 else (start.size() == 3 and Vector3(float(start[0]), float(start[1]), float(start[2])).distance_to(Vector3(float(saved[0]), float(saved[1]), float(saved[2]))) < 8.0)
		items.report_position(peers[i], Vector3(float(start[0]), float(start[1]), float(start[2])) if start.size() == 3 else Vector3(58167.0 + i, 6.0, 71364.0))
		var pack: Array = []
		var inv = items.inventory_of(peers[i])

		for s in inv.slot_count:
			if inv.numbers[s] != 0:
				pack.append("%s x%d w%d" % [table.id_of(inv.numbers[s]) if table.id_of(inv.numbers[s]) != "" else "#%d" % inv.numbers[s], inv.counts[s], inv.wear[s]])

		pack.sort()
		check(spot_ok and pack == (expected["packs"] as Dictionary).get(keys[i], []), "9257 %s, joining with three others: its spot (%s) and its pack (%d stacks)" % [keys[i], str(start), pack.size()])

	items.tick(0.25)
	var players = PlayersScript.new()
	var clock: Array = [1000]
	var sent: Array = []
	players.items = items
	players.now_ms = func() -> int: return int(clock[0])
	players.send_rows = func(to, ids, _positions, _yaws, _states, _held, _times, _left, _more, _cast): sent.append([to, ids])
	players.send_flight = func(_p, _n, _f, _v, _b): pass
	players.send_look = func(_to, _about, _n, _b, _c, _w): pass

	for i in peers.size():
		players.set_look(peers[i], "P%d" % i, "body_1", "")

	for n in range(5):
		clock[0] += 200

		for p in peers:
			players.note_report(p, 0.0)

		players.tick(0.2)

	var all_see: bool = true

	for p in peers:
		var others: Array = peers.filter(func(q): return q != p)
		var rows: Array = sent.filter(func(r): return int(r[0]) == p)
		var last: PackedInt32Array = rows[rows.size() - 1][1] if not rows.is_empty() else PackedInt32Array()
		all_see = all_see and others.all(func(q): return last.has(q))

	check(all_see, "each of the four 9257 characters sees the other three")
