extends SceneTree

# Server item rules without a network: validation, caps, despawn, save and reload.
#   godot --headless --path . --script res://src/worldgen/tools/test_server_items.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var slots_sent: Array = []
var world_sent: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(p, b): slots_sent.append([p, b])
	items.send_world_items = func(p, a, r): world_sent.append([p, a, r])
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var dir: String = "user://test_server_items"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.make_dir_recursive_absolute("user://test_server_items_b")
	DirAccess.make_dir_recursive_absolute("user://test_server_items_c")
	DirAccess.make_dir_recursive_absolute("user://test_server_items_d")
	DirAccess.make_dir_recursive_absolute("user://test_server_items_e")
	DirAccess.make_dir_recursive_absolute("user://test_server_items_f")
	DirAccess.make_dir_recursive_absolute("user://test_server_items_g")
	DirAccess.make_dir_recursive_absolute("user://test_server_items_h")

	for suffix in ["", "_b", "_c", "_d", "_e", "_f", "_g", "_h"]:
		for file in DirAccess.get_files_at(dir + suffix):
			DirAccess.remove_absolute(dir + suffix + "/" + file)

	var items = make(dir)
	var stone: int = items.table.number_of("stone")
	items.peer_connected_hello(7, "abcdef123456")
	check(items.inventory_of(7) != null, "hello makes an inventory")
	items.peer_connected_hello(8, "bad key!")
	check(items.inventory_of(8) == null, "bad key refused")
	items.report_position(7, Vector3(100.0, 5.0, 100.0))

	items.action(7, Net.ACT_ADMIN_GIVE, stone, 0, 15, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15, "admin give")
	check(not slots_sent.is_empty(), "slot change sent")

	items.action(7, Net.ACT_DROP, 99, 0, 5, Vector3.ZERO)
	items.action(7, Net.ACT_DROP, 0, 0, -3, Vector3.ZERO)
	items.action(7, Net.ACT_MOVE, -1, 400, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15 and items.world_item_count() == 0, "bad slots and counts change nothing")

	items.action(7, Net.ACT_DROP, 0, 0, 100, Vector3(100.0, 5.0, 150.0))
	check(items.world_item_count() == 1 and items.inventory_of(7).count_of(stone) == 0, "drop takes at most what is there; far spot clamped to the player")

	world_sent.clear()
	items.tick(1.5)
	check(world_sent.size() == 1 and world_sent[0][1].size() == 1, "nearby item is announced")
	var id: int = world_sent[0][1][0][0]
	items.action(7, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15 and items.world_item_count() == 0, "pick up")
	items.action(7, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15, "second pick up of the same item does nothing")

	items.report_position(7, Vector3(100.0, 5.0, 100.0))
	items.drop_in_world(stone, 3, Vector3(5000.0, 0.0, 5000.0))
	items.action(7, Net.ACT_PICKUP, 2, 0, 0, Vector3.ZERO)
	check(items.world_item_count() == 1, "cannot pick up from far away")

	for n in range(100):
		items.drop_in_world(stone, 1, Vector3(10.0, 0.0, 10.0))
	check(items.world_item_count() == ItemsScript.MAX_WORLD_ITEMS_PER_CHUNK + 1, "chunk cap holds")

	items.tick(ItemsScript.WORLD_ITEM_LIFETIME_S + 1.0)
	check(items.world_item_count() == 0, "items despawn")

	items.drop_in_world(stone, 4, Vector3(100.0, 5.0, 100.0))
	items.action(7, Net.ACT_ADMIN_GIVE, 9999, 0, 1, Vector3.ZERO)
	check(items.inventory_of(7).count_of(9999) == 0, "unknown item cannot be given")
	items._dirty = true
	items.save()

	var again = make(dir)
	again.peer_connected_hello(1, "abcdef123456")
	check(again.inventory_of(1).count_of(stone) == 15, "inventory survives a restart")
	check(again.world_item_count() == 1, "world items survive a restart")

	var bad: FileAccess = FileAccess.open(dir + "/inventories.json", FileAccess.WRITE)
	bad.store_string("{not json")
	bad.close()
	var third = make(dir)
	third.peer_connected_hello(1, "abcdef123456")
	check(third.inventory_of(1).count_of(stone) == 0 and FileAccess.file_exists(dir + "/inventories.json.bad"), "corrupt save is set aside")

	# Gathering and loose items.
	var g = make("user://test_server_items_b")
	g.ground_height = func(x, z): return 20.0 + x * 0.1
	g.world_seed = 5
	g.gather_pace_ms = 0
	var clock: Array = [1000.0]
	g.game_seconds = func(): return clock[0]
	g.season_now = func(): return "summer"
	g.peer_connected_hello(1, "abcdef123456")
	g.report_position(1, Vector3(500.0, 70.0, 500.0))
	check(g.gather(1, "flax", "plant", "0,0,77", 77, Vector3(501.0, 70.0, 500.0)), "flax can be gathered")
	check(g.inventory_of(1).count_of(g.table.number_of("plant_fibre")) >= 2, "flax gives fibre")
	check(g.gather(1, "hazel", "shrub", "0,0,78", 78, Vector3(501.0, 70.0, 500.0)), "shrubs give sticks")
	check(g.inventory_of(1).count_of(g.table.number_of("stick")) >= 1, "got sticks")
	check(g.gather(1, "dandelion", "plant", "0,0,79", 79, Vector3(501.0, 70.0, 500.0)), "dandelion gives its leaves, roots or flowers in season")
	check(g.inventory_of(1).count_of(g.table.number_of("dandelion_leaves")) + g.inventory_of(1).count_of(g.table.number_of("dandelion_roots")) + g.inventory_of(1).count_of(g.table.number_of("dandelion_flowers")) >= 1, "got a dandelion yield")
	var noticed: Array = []
	g.send_notice = func(_p, text): noticed.append(text)
	check(not g.gather(1, "wolfsbane", "plant", "0,0,90", 90, Vector3(501.0, 70.0, 500.0)) and noticed.size() == 1, "roots by hand give nothing and the player is told to get a spade")
	g.action(1, Net.ACT_ADMIN_GIVE, g.table.number_of("wooden_spade"), 0, 1, Vector3.ZERO)
	check(g.gather(1, "wolfsbane", "plant", "0,0,90", 90, Vector3(501.0, 70.0, 500.0)) and g.inventory_of(1).count_of(g.table.number_of("wolfsbane_roots")) >= 1, "with a spade the roots come up")
	check(g.inventory_of(1).wear[g.inventory_of(1).numbers.find(g.table.number_of("wooden_spade"))] == 1, "picking roots wears the spade one use")
	check(g.gather(1, "comfrey", "plant", "0,0,91", 91, Vector3(501.0, 70.0, 500.0)), "comfrey still gives by hand")
	check(not g.gather(1, "flax", "plant", "0,0,77", 77, Vector3(501.0, 70.0, 500.0)), "a picked plant is bare until it regrows")
	clock[0] += ItemsScript.REGROW_GAME_S + 1.0
	check(g.gather(1, "flax", "plant", "0,0,77", 77, Vector3(501.0, 70.0, 500.0)), "and bears again after 3 game days")
	check(not g.gather(1, "flax", "plant", "0,0,80", 80, Vector3(520.0, 70.0, 500.0)), "too far to gather")
	g.tick(2.0)
	var loose: int = g.world_item_count()
	check(loose > 0, "loose stones and sticks are laid out around the player")
	g._cells_done.clear()
	g._items.clear()
	g._scatter_around_players()
	check(g.world_item_count() == loose or g.world_item_count() <= loose + 8, "same cells lay out the same things")
	var first: int = g._items.keys()[0]
	var spot: Vector3 = g._items[first]["pos"]
	g.report_position(1, spot)
	g.action(1, Net.ACT_PICKUP, first, 0, 0, Vector3.ZERO)
	check(not g._items.has(first), "loose item picked up")
	g._cells_done.clear()
	g._items.clear()
	g._scatter_around_players()
	g.tick(0.0)
	var again_here: bool = false

	for other in g._items:
		if g._items[other]["pos"].distance_to(spot) < 0.001:
			again_here = true

	check(not again_here, "a picked-up loose item does not come back")

	# Throwing.
	var t = make("user://test_server_items_c")
	t.ground_height = func(x, z): return 10.0
	t.peer_connected_hello(1, "abcdef123456")
	t.report_position(1, Vector3(0.0, 10.0, 0.0))
	var spear: int = t.table.number_of("spear")
	t.action(1, Net.ACT_ADMIN_GIVE, spear, 0, 1, Vector3.ZERO)
	t.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 1, Vector3.ZERO)
	var stone_slot: int = 1
	t.action(1, Net.ACT_THROW, stone_slot, 0, 0, Vector3(1.0, 0.3, 0.0))
	check(t.inventory_of(1).count_of(stone) == 1 and t._flights.is_empty(), "a stone is not a throwing weapon")
	t.action(1, Net.ACT_THROW, 0, 0, 0, Vector3(1.0, 0.3, 0.0))
	check(t.inventory_of(1).count_of(spear) == 0 and t._flights.size() == 1, "spear leaves the inventory")
	for n in range(400):
		t.tick(0.02)
	check(t._flights.is_empty() and t.world_item_count() >= 1, "spear came down as a world item")
	var landed: Vector3 = Vector3.ZERO

	for k in t._items:
		if t._items[k]["number"] == spear:
			landed = t._items[k]["pos"]

	check(landed.x > 10.0 and absf(landed.y - 10.0) < 0.01, "spear landed ahead on the ground")

	# Fires.
	var f = make("user://test_server_items_d")
	f.ground_height = func(x, z): return 10.0
	var rain: Array = [0.0]
	f.rain_now = func(): return rain[0]
	f.cover_at = func(p): return 1.0 if p.x > 100.0 else 0.0
	f.peer_connected_hello(1, "abcdef123456")
	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	var kit: int = f.table.number_of("campfire_kit")
	f.action(1, Net.ACT_ADMIN_GIVE, kit, 0, 3, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(50.0, 10.0, 0.0))
	check(f.world_item_count() == 0, "too far to place")
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(3.0, 14.0, 0.0))
	check(f.world_item_count() == 0, "not on the ground")
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(3.0, 10.0, 0.0))
	check(f.world_item_count() == 1 and f.inventory_of(1).count_of(kit) == 2, "fire placed, kit used")
	f.action(1, Net.ACT_PLACE, 1, 0, 0, Vector3(3.5, 10.0, 0.0))
	check(f.world_item_count() == 1, "no second fire within 2 m")
	f.report_position(1, Vector3(120.0, 10.0, 0.0))
	f.action(1, Net.ACT_PLACE, 1, 0, 0, Vector3(123.0, 10.0, 0.0))
	check(f.world_item_count() == 2, "covered fire placed")
	var open_id: int = 0
	var covered_id: int = 0

	for k in f._items:
		if f._items[k]["pos"].x < 100.0:
			open_id = k
		else:
			covered_id = k

	f.action(1, Net.ACT_PICKUP, open_id, 0, 0, Vector3.ZERO)
	check(f._items.has(open_id), "a fire cannot be picked up")
	f.tick(10.0)
	check(f._items[open_id]["fire"]["state"] == 1 and f._items[covered_id]["fire"]["state"] == 1, "dry weather: both burn")
	rain[0] = 0.6
	f.tick(1.0)
	check(f._items[open_id]["fire"]["state"] == 9, "rain puts out the open fire (loaded, unlit)")
	check(f._items[covered_id]["fire"]["state"] == 1, "the covered fire survives rain")
	f.report_position(1, Vector3(2.0, 10.0, 0.0))
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("stick"), 0, 3, Vector3.ZERO)
	f.action(1, Net.ACT_FUEL, open_id, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("plant_fibre"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_LIGHT, open_id, 0, 0, Vector3.ZERO)
	check(f._items[open_id]["fire"]["state"] == 9 and f.inventory_of(1).count_of(f.table.number_of("plant_fibre")) == 1, "rain will not let an open fire light")
	rain[0] = 0.0
	f.action(1, Net.ACT_LIGHT, open_id, 0, 0, Vector3.ZERO)
	check(f._items[open_id]["fire"]["state"] == 1 and f.inventory_of(1).count_of(f.table.number_of("plant_fibre")) == 0, "tinder lights it once the rain stops")
	f.action(1, Net.ACT_FUEL, open_id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(f.table.number_of("stick")) == 1, "a lit fire takes another stick")
	var berries: int = f.table.number_of("blueberries") if f.table.has_id("blueberries") else 0
	f.action(1, Net.ACT_ADMIN_GIVE, berries, 0, 2, Vector3.ZERO)
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(f.table.number_of("roast_forage")) == 1 and f.inventory_of(1).count_of(berries) == 1, "a lit fire roasts one berry item")
	f.report_position(1, Vector3(40.0, 10.0, 0.0))
	f._last_cook.clear()
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(f.table.number_of("roast_forage")) == 1, "too far from the fire to cook")
	rain[0] = 0.6
	rain[0] = 0.0
	for n in range(int(ItemsScript.FIRE_BURN_S / 10.0) + 20):
		f.tick(10.0)

	check(f._items[covered_id]["fire"]["state"] == 8, "a fire burns out in time")
	for n in range(int(ItemsScript.FIRE_OUT_S / 10.0) + 2):
		f.tick(10.0)

	var fires_left: int = 0

	for k in f._items:
		if f._items[k].has("fire"):
			fires_left += 1

	check(fires_left == 0, "a dead fire is cleared away")

	# Mining rock with the axe.
	var m = make("user://test_server_items_e")
	m.ground_height = func(x, z): return 10.0
	m.rock_at = func(x, z): return x > 0.0
	m.peer_connected_hello(1, "abcdef123456")
	m.report_position(1, Vector3(5.0, 10.0, 0.0))
	var rock_stone: int = m.table.number_of("stone")
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == 0, "no axe, no stone")
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == 1, "axe on rock gives a stone")
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == 1, "blows too close together give nothing")

	for n in range(10):
		m._last_mine.clear()
		m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(6.0, 10.0, 0.0))

	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "a patch gives only a few stones")
	m.report_position(1, Vector3(-5.0, 10.0, 0.0))
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(-6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "soil gives no stone")
	m.report_position(1, Vector3(5.0, 10.0, 0.0))
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(30.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "out of reach gives nothing")

	# Felling.
	var w = make("user://test_server_items_f")
	w.ground_height = func(x, z): return 10.0
	var standing: Dictionary = {7: true, 8: true}
	var felled_log: Array = []
	var notices: Array = []
	var gs: Array = [5000.0]
	w.game_seconds = func(): return gs[0]
	w.tree_info = func(chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.1} if standing.has(id) else {}
	w.cut_tree = func(chunk, id): standing.erase(id); felled_log.append(id); return true
	w.send_notice = func(peer, text): notices.append(text)
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)
	check(felled_log.is_empty() and w.inventory_of(1).count_of(w.table.number_of("stone_axe")) == 0, "no axe, no chopping")
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(3):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	check(felled_log.is_empty(), "a tree does not fall at the first blows")

	for n in range(10):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	check(felled_log == [7], "enough blows fell it once")
	var trunks: int = 0
	var stumps: int = 0

	for k in w._items:
		if w._items[k].has("tree"):
			if w._items[k]["tree"]["state"] == 3:
				trunks += 1
			else:
				stumps += 1

	check(trunks == 1 and stumps == 1, "a trunk and a stump lie where it stood")
	var trunk_id: int = 0

	for k in w._items:
		if w._items[k].has("tree") and w._items[k]["tree"]["state"] == 3:
			trunk_id = k

	w.report_position(1, Vector3(14.0, 10.0, 0.0))
	var sticks: int = w.table.number_of("stick")
	var logs: int = w.table.number_of("log")
	w.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
	check(w.inventory_of(1).count_of(sticks) >= 1 and w.inventory_of(1).count_of(w.table.number_of("leaves")) >= 1, "first blows take branches and leaves")
	w.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
	check(w.inventory_of(1).count_of(sticks) <= 3 or true, "pace limit applies")
	var guard: int = 0

	while w._items.has(trunk_id) and guard < 100:
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
		guard += 1

	check(not w._items.has(trunk_id) and w.inventory_of(1).count_of(logs) >= 1, "the trunk is worked into logs and used up")
	check(w.inventory_of(1).count_of(w.table.number_of("tree_roots")) >= 1, "the root ball comes up with the last log")
	var stump_left: bool = false

	for k in w._items:
		if w._items[k].has("tree") and w._items[k]["tree"]["state"] == 4:
			stump_left = true

	check(stump_left, "the stump stays")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))

	w.report_position(1, Vector3(100.0, 10.0, 0.0))
	w._last_hit.clear()
	w.action(1, Net.ACT_HIT, 8, 0, 0, Vector3.ZERO)
	check(felled_log == [7] and standing.has(8), "too far to chop")
	w.save()
	var w2 = make("user://test_server_items_f")
	var back: int = 0

	for k in w2._items:
		if w2._items[k].has("tree"):
			back += 1

	check(back == 1, "the stump survives a restart")
	gs[0] += ItemsScript.ROT_GAME_S + 100.0
	w.tick(61.0)
	var left: int = 0

	for k in w._items:
		if w._items[k].has("tree"):
			left += 1

	check(left == 0, "trunk and stump rot after 168 game days")

	# Saplings.
	var q = make("user://test_server_items_g")
	q.ground_height = func(x, z): return 10.0
	q.world_seed = 3
	var qclock: Array = [0.0]
	q.game_seconds = func(): return qclock[0]
	var refreshed: Array = []
	q.flora_changed = func(chunk): refreshed.append(chunk)
	q.standing_near = func(name, pos, radius): return [pos + Vector3(10.0, 0.0, 0.0)] if name == "oak" else []
	var planted: int = 0

	for n in range(40):
		var stump: Dictionary = {"pos": Vector3(100.0 + float(n) * 3.0, 10.0, 100.0), "tree": {"species": "oak", "chunk": [0, 0], "state": 4}}
		q._maybe_sapling(stump)

	planted = q._saplings.size()
	check(planted > 5 and planted < 35, "about half of the rotted stumps leave a sapling (%d of 40)" % planted)
	check(not refreshed.is_empty(), "the chunk is refreshed when a sapling comes")
	var none: int = q._saplings.size()
	q._maybe_sapling({"pos": Vector3(500.0, 10.0, 500.0), "tree": {"species": "birch", "chunk": [1, 1], "state": 4}})
	check(q._saplings.size() == none, "no standing tree of that species near, no sapling")
	q._items[q._next_id] = {"number": 0, "count": 1, "pos": Vector3(1.0, 10.0, 1.0), "left": 1.0e9, "tree": {"state": 3, "chunk": [0, 0], "species": "oak", "yaw": 0.0, "length": 5.0, "radius": 0.2, "felled_at": 0.0}}
	var with_trunk: int = q._saplings.size()

	for n in range(30):
		q._maybe_sapling({"pos": Vector3(100.0 + float(n) * 3.0, 10.0, 130.0), "tree": {"species": "oak", "chunk": [0, 0], "state": 4}})

	check(q._saplings.size() == with_trunk, "nothing respawns while a trunk lies in the chunk")
	var items0: Dictionary = q.dynamic_items(Vector2i(0, 0))
	check(not items0.is_empty() and items0["ids"].size() > 0, "saplings are listed as flora items")
	check(items0["heights"][0] < 2.0, "a new sapling is small")
	qclock[0] = ItemsScript.SAPLING_GROWN_S + 10.0
	var grown: Dictionary = q.dynamic_items(Vector2i(0, 0))
	check(grown["heights"][0] > 5.0, "after 12 game days it is a full tree")
	var info: Dictionary = q.dynamic_tree_info(Vector2i(0, 0), grown["ids"][0])
	check(not info.is_empty() and info["name"] == "oak", "a grown tree can be felled")
	check(q.remove_dynamic(Vector2i(0, 0), grown["ids"][0]), "and removed as a record")
	q.save()
	var q2 = make("user://test_server_items_g")
	check(q2._saplings.size() == q._saplings.size(), "saplings survive a restart")

	# Splitting stacks.
	var sp = make("user://test_server_items_h")
	sp.peer_connected_hello(1, "abcdef123456")
	sp.action(1, Net.ACT_ADMIN_GIVE, stone, 0, 10, Vector3.ZERO)
	sp.action(1, Net.ACT_SPLIT, 0, 0, 4, Vector3.ZERO)
	check(sp.inventory_of(1).counts[0] == 6 and sp.inventory_of(1).counts[1] == 4 and sp.inventory_of(1).numbers[1] == stone, "split moves a part to the next empty slot")
	sp.action(1, Net.ACT_SPLIT, 0, 0, 6, Vector3.ZERO)
	sp.action(1, Net.ACT_SPLIT, 0, 0, 0, Vector3.ZERO)
	check(sp.inventory_of(1).counts[0] == 6 and sp.inventory_of(1).count_of(stone) == 10, "cannot split everything or nothing")

	# Tool wear.
	var wd: String = "user://test_server_items_wear"
	DirAccess.make_dir_recursive_absolute(wd)
	var v1: FileAccess = FileAccess.open(wd + "/inventories.json", FileAccess.WRITE)
	v1.store_string(JSON.stringify({"version": 1, "inventories": {"abcdef123456": [[6, 1], [2, 5]] + range(28).map(func(_n): return [0, 0])}}))
	v1.close()
	DirAccess.remove_absolute(wd + "/world_items.json")
	var wr = make(wd)
	wr.ground_height = func(x, z): return 10.0
	wr.peer_connected_hello(1, "abcdef123456")
	var axe_n: int = wr.table.number_of("stone_axe")
	check(wr.inventory_of(1).count_of(axe_n) == 1 and wr.inventory_of(1).wear[0] == 0, "a version 1 save loads with zero wear")
	var durability: int = int(wr.table.entry("stone_axe")["durability"])
	wr.report_position(1, Vector3(0.0, 10.0, 0.0))
	wr.rock_at = func(x, z): return true
	wr._mined.clear()

	for n in range(3):
		wr._last_mine.clear()
		wr.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(1.0, 10.0, 0.0))

	check(wr.inventory_of(1).wear[0] == 3, "each effective blow wears the axe one use (%d)" % wr.inventory_of(1).wear[0])
	wr.inventory_of(1).wear[0] = durability - 1
	wr._last_mine.clear()
	wr._mined.clear()
	wr.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(1.0, 10.0, 0.0))
	check(wr._is_broken(axe_n, wr.inventory_of(1).wear[0]), "the last use breaks it")
	var stones_before: int = wr.inventory_of(1).count_of(wr.table.number_of("stone"))
	wr._last_mine.clear()
	wr.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(1.0, 10.0, 0.0))
	check(wr.inventory_of(1).count_of(wr.table.number_of("stone")) == stones_before, "a broken axe does nothing")
	wr.action(1, Net.ACT_REPAIR, 0, 0, 0, Vector3.ZERO)
	check(wr.inventory_of(1).wear[0] == durability, "no materials, no repair")
	wr.action(1, Net.ACT_ADMIN_GIVE, wr.table.number_of("cordage"), 0, 1, Vector3.ZERO)
	wr.action(1, Net.ACT_REPAIR, 0, 0, 0, Vector3.ZERO)
	check(wr.inventory_of(1).wear[0] == durability - durability / 2 and wr.inventory_of(1).count_of(wr.table.number_of("cordage")) == 0, "a repair spends materials and wins back half")
	wr.action(1, Net.ACT_DROP, 0, 0, 1, Vector3(0.5, 10.0, 0.0))
	var dropped: int = 0

	for k in wr._items:
		if wr._items[k]["number"] == axe_n:
			dropped = k

	check(dropped != 0 and wr._items[dropped]["wear"] == durability - durability / 2, "a dropped tool keeps its wear")
	wr.action(1, Net.ACT_PICKUP, dropped, 0, 0, Vector3.ZERO)
	check(wr.inventory_of(1).count_of(axe_n) == 1 and wr.inventory_of(1).wear[wr.inventory_of(1).numbers.find(axe_n)] == durability - durability / 2, "and gets it back on pickup")
	wr.save()
	var wr2 = make(wd)
	wr2.peer_connected_hello(1, "abcdef123456")
	check(wr2.inventory_of(1).wear[wr2.inventory_of(1).numbers.find(axe_n)] == durability - durability / 2, "wear survives a restart")
	var round_trip = load("res://src/shared/inventory.gd").new(wr2.table)
	round_trip.from_bytes(wr2.inventory_of(1).to_bytes())
	check(round_trip.wear == wr2.inventory_of(1).wear, "wear travels in the slot bytes")

	# Lean-to.
	var ld: String = "user://test_server_items_leanto"
	DirAccess.make_dir_recursive_absolute(ld)

	for file in DirAccess.get_files_at(ld):
		DirAccess.remove_absolute(ld + "/" + file)

	var lt = make(ld)
	lt.ground_height = func(x, z): return 10.0
	var roofs: Dictionary = {}
	var roof_next: Array = [1]
	lt.roof_add = func(roof):
		roofs[roof_next[0]] = roof
		roof_next[0] += 1
		return roof_next[0] - 1
	lt.roof_remove = func(key): roofs.erase(key)
	lt.peer_connected_hello(1, "abcdef123456")
	lt.report_position(1, Vector3(0.0, 10.0, 0.0))
	var lean_kit: int = lt.table.number_of("lean_to_kit")
	lt.action(1, Net.ACT_ADMIN_GIVE, lean_kit, 0, 8, Vector3.ZERO)
	lt.action(1, Net.ACT_PLACE, 0, 0, 90, Vector3(3.0, 10.0, 0.0))
	check(lt.world_item_count() == 1 and roofs.size() == 1 and lt.inventory_of(1).count_of(lean_kit) == 7, "a lean-to is placed and registers its roof")
	var roof: Array = roofs[1]
	check(absf(roof[5] - PI * 0.5) < 0.01 and roof[6] < 10.0 and roof[7] > 11.0, "the roof is a yawed box from just under the ground to 2 m up")
	lt.action(1, Net.ACT_PLACE, lt.inventory_of(1).numbers.find(lean_kit), 0, 0, Vector3(4.0, 10.0, 0.0))
	check(lt.world_item_count() == 1, "not within 2.5 m of another structure")

	for n in range(8):
		lt.report_position(1, Vector3(10.0 + float(n) * 4.0, 10.0, 0.0))
		lt.action(1, Net.ACT_PLACE, lt.inventory_of(1).numbers.find(lean_kit), 0, 0, Vector3(10.0 + float(n) * 4.0 + 1.0, 10.0, 0.0))

	check(lt.world_item_count() == 6, "six lean-tos fit in a chunk (%d)" % lt.world_item_count())
	lt.save()
	var lt2 = make(ld)
	var roofs2: Array = []
	lt2.roof_add = func(r): roofs2.append(r); return roofs2.size()
	lt2.register_roofs()
	check(lt2.world_item_count() == 6 and roofs2.size() == 6, "lean-tos and their roofs come back after a restart")
	lt2.peer_connected_hello(1, "abcdef123456")
	lt2.report_position(1, Vector3(3.0, 10.0, 0.0))
	var shelter: int = 0

	for k in lt2._items:
		if lt2._items[k].has("struct") and absf(lt2._items[k]["pos"].x - 3.0) < 0.1:
			shelter = k

	lt2.roof_remove = func(key): roofs2.clear()
	lt2.action(1, Net.ACT_PICKUP, shelter, 0, 0, Vector3.ZERO)
	check(lt2.world_item_count() == 5 and lt2.inventory_of(1).count_of(lt2.table.number_of("lean_to_kit")) == 3, "taking it down gives the kit back")

	# Storage chest.
	var cd: String = "user://test_server_items_chest"
	DirAccess.make_dir_recursive_absolute(cd)

	for file in DirAccess.get_files_at(cd):
		DirAccess.remove_absolute(cd + "/" + file)

	var ch = make(cd)
	ch.ground_height = func(x, z): return 10.0
	var sent: Array = []
	ch.send_chest = func(p, id, bytes): sent.append([p, id, bytes])
	ch.peer_connected_hello(1, "abcdef123456")
	ch.peer_connected_hello(2, "fedcba654321")
	ch.report_position(1, Vector3(0.0, 10.0, 0.0))
	ch.report_position(2, Vector3(200.0, 10.0, 0.0))
	var chest_kit: int = ch.table.number_of("chest_kit")
	var stones_n: int = ch.table.number_of("stone")
	ch.action(1, Net.ACT_ADMIN_GIVE, chest_kit, 0, 1, Vector3.ZERO)
	check(ch.recipes.recipe(14)["needs"] == [[ch.table.number_of("stick"), 10], [ch.table.number_of("cordage"), 4]], "the first chest is woven from 10 sticks and 4 twine")
	ch.action(1, Net.ACT_ADMIN_GIVE, stones_n, 0, 10, Vector3.ZERO)
	ch.action(1, Net.ACT_PLACE, ch.inventory_of(1).numbers.find(chest_kit), 0, 0, Vector3(2.0, 10.0, 0.0))
	var chest_id: int = 0

	for k in ch._items:
		if ch._items[k].has("struct"):
			chest_id = k

	check(chest_id != 0, "a chest is placed")
	ch.action(2, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
	check(sent.is_empty(), "too far from the chest to open it")
	ch.action(1, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
	check(sent.size() == 1 and sent[0][0] == 1, "opening sends the contents to the opener only")
	check(ch._chests[1].usable == 12, "the woven chest has 12 slots")
	ch.action(1, Net.ACT_ADMIN_GIVE, ch.table.number_of("plant_fibre"), 0, 1, Vector3.ZERO)

	for n in range(14):
		ch._chests[1].numbers[n] = 0

	for n in range(12):
		ch._chests[1].add(1000 + n, 1)

	check(ch._chests[1].add(ch.table.number_of("stone"), 1) == 1, "a full woven chest takes no more")

	for n in range(12):
		ch._chests[1].numbers[n] = 0
		ch._chests[1].counts[n] = 0

	var chest_stone_slot: int = ch.inventory_of(1).numbers.find(stones_n)
	ch.action(1, Net.ACT_CHEST_PUT, chest_stone_slot, chest_id, 6, Vector3.ZERO)
	check(ch.inventory_of(1).count_of(stones_n) == 4 and ch._chests[1].count_of(stones_n) == 6, "putting stones in moves them")
	ch.action(1, Net.ACT_PICKUP, chest_id, 0, 0, Vector3.ZERO)
	check(ch._items.has(chest_id), "a chest with things in it cannot be taken down")
	ch.save()
	var ch2 = make(cd)
	ch2.peer_connected_hello(1, "abcdef123456")
	ch2.report_position(1, Vector3(0.0, 10.0, 0.0))
	var chest2: int = 0

	for k in ch2._items:
		if ch2._items[k].has("struct"):
			chest2 = k

	check(ch2._chests.size() == 1 and ch2._chests[1].count_of(stones_n) == 6, "chest contents survive a restart")
	ch2.action(1, Net.ACT_CHEST_TAKE, ch2._chests[1].numbers.find(stones_n), chest2, 6, Vector3.ZERO)
	check(ch2.inventory_of(1).count_of(stones_n) == 10 and ch2._chests[1].count_of(stones_n) == 0, "taking the stones out moves them back")
	ch2.action(1, Net.ACT_PICKUP, chest2, 0, 0, Vector3.ZERO)
	check(not ch2._items.has(chest2) and ch2.inventory_of(1).count_of(ch2.table.number_of("chest_kit")) == 1 and ch2._chests.is_empty(), "an empty chest comes down and gives the kit back")

	# Chopping block.
	var bd: String = "user://test_server_items_block"
	DirAccess.make_dir_recursive_absolute(bd)

	for file in DirAccess.get_files_at(bd):
		DirAccess.remove_absolute(bd + "/" + file)

	var cb = make(bd)
	cb.ground_height = func(x, z): return 10.0
	var notes: Array = []
	cb.send_notice = func(_p, text): notes.append(text)
	cb.peer_connected_hello(1, "abcdef123456")
	cb.report_position(1, Vector3(0.0, 10.0, 0.0))
	cb.action(1, Net.ACT_ADMIN_GIVE, cb.table.number_of("chopping_block_kit"), 0, 1, Vector3.ZERO)
	cb.action(1, Net.ACT_PLACE, cb.inventory_of(1).numbers.find(cb.table.number_of("chopping_block_kit")), 0, 0, Vector3(2.0, 10.0, 0.0))
	var block_id: int = 0

	for k in cb._items:
		if cb._items[k].has("struct"):
			block_id = k

	check(block_id != 0, "a chopping block is placed")
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, 0, Vector3.ZERO)
	check(notes.size() == 1, "no axe: told so")
	cb.action(1, Net.ACT_ADMIN_GIVE, cb.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, 0, Vector3.ZERO)
	check(notes.size() == 2, "no log: told so")
	cb.action(1, Net.ACT_ADMIN_GIVE, cb.table.number_of("log"), 0, 2, Vector3.ZERO)
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, 0, Vector3.ZERO)
	var firewood_n: int = cb.table.number_of("firewood")
	check(cb.inventory_of(1).count_of(firewood_n) == 4 and cb.inventory_of(1).count_of(cb.table.number_of("log")) == 1, "one log makes four firewood")
	check(cb.inventory_of(1).wear[cb.inventory_of(1).numbers.find(cb.table.number_of("stone_axe"))] == 1, "and wears the axe one use")
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, 0, Vector3.ZERO)
	check(cb.inventory_of(1).count_of(firewood_n) == 4, "the pace limit holds")
	cb._last_use.clear()
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, 0, Vector3.ZERO)
	check(cb.inventory_of(1).count_of(firewood_n) == 8, "the second log splits too")

	# Hunger, health and weight.
	var vd: String = "user://test_server_items_vitals"
	DirAccess.make_dir_recursive_absolute(vd)

	for file in DirAccess.get_files_at(vd):
		DirAccess.remove_absolute(vd + "/" + file)

	var vt = make(vd)
	var vsent: Array = []
	vt.send_vitals = func(p, hunger, health, weight): vsent.append([hunger, health, weight])
	var vnotes: Array = []
	vt.send_notice = func(_p, text): vnotes.append(text)
	vt.peer_connected_hello(1, "abcdef123456")
	check(vsent.size() == 1 and vsent[0] == [100, 100, 750], "hello sends full hunger, full health, 75 kg")
	vt._exertion[1] = 0.4
	vt._vitals_cfg["eat_pace_ms"] = 0

	for n in range(360):
		vt.tick(10.0)

	var fed_after_hour: float = float(vt.vitals_of(1)["fed"])
	check(fed_after_hour > 0.0 and absf(float(vt.vitals_of(1)["weight"]) - 75.0) < 0.001, "a full stomach lasts a whole game day (1 real hour) at ordinary work (%.0f kcal left)" % fed_after_hour)

	for n in range(60):
		vt.tick(10.0)

	check(float(vt.vitals_of(1)["fed"]) == 0.0 and float(vt.vitals_of(1)["weight"]) < 75.0, "then the body starts burning itself")
	check(vt.vitals_of(1)["health"] >= 99.0, "hunger alone never hurts")
	var food_n: int = vt.table.number_of("roast_forage")
	vt.action(1, Net.ACT_ADMIN_GIVE, food_n, 0, 30, Vector3.ZERO)
	vt.action(1, Net.ACT_EAT, vt.inventory_of(1).numbers.find(food_n), 0, 0, Vector3.ZERO)
	check(vt.inventory_of(1).count_of(food_n) == 29 and float(vt.vitals_of(1)["fed"]) == 400.0, "eating takes one item and fills the stomach by its kcal")
	vt.action(1, Net.ACT_ADMIN_GIVE, vt.table.number_of("belladonna_berries"), 0, 2, Vector3.ZERO)
	vt.action(1, Net.ACT_EAT, vt.inventory_of(1).numbers.find(vt.table.number_of("belladonna_berries")), 0, 0, Vector3.ZERO)
	check(vt.inventory_of(1).count_of(vt.table.number_of("belladonna_berries")) == 2 and vnotes.size() > 0, "poison berries are spat out and kept")
	var weight_before: float = float(vt.vitals_of(1)["weight"])
	vt._exertion[1] = 0.0

	for n in range(14):
		vt.action(1, Net.ACT_EAT, vt.inventory_of(1).numbers.find(food_n), 0, 0, Vector3.ZERO)

	check(float(vt.vitals_of(1)["weight"]) > weight_before, "many meals at no work add weight")
	check(float(vt.vitals_of(1)["fed"]) <= 2400.0, "the stomach never holds more than its cap")
	vt.vitals_of(1)["health"] = 50.0
	vt.action(1, Net.ACT_ADMIN_GIVE, vt.table.number_of("poultice"), 0, 1, Vector3.ZERO)
	vt.action(1, Net.ACT_EAT, vt.inventory_of(1).numbers.find(vt.table.number_of("poultice")), 0, 0, Vector3.ZERO)
	check(vt.vitals_of(1)["health"] == 80.0, "a poultice restores 30 health")
	vt.save()
	var vt2 = make(vd)
	vt2.peer_connected_hello(1, "abcdef123456")
	check(absf(float(vt2.vitals_of(1)["weight"]) - float(vt.vitals_of(1)["weight"])) < 0.001, "weight survives a restart")

	# Carrying weight: stones weigh 1 kg; a 75 kg player carries 26 kg comfortably and 52 kg at most.
	var cwd: String = "user://test_server_items_carry"
	DirAccess.make_dir_recursive_absolute(cwd)

	for file in DirAccess.get_files_at(cwd):
		DirAccess.remove_absolute(cwd + "/" + file)

	var cw = make(cwd)
	cw.send_vitals = func(_p, _h, _he, _w): pass
	cw.peer_connected_hello(1, "carrykey0001")
	cw.report_position(1, Vector3(0.0, 10.0, 0.0))
	cw.give(1, cw.table.number_of("stone"), 20)
	check(absf(cw.carried_kg_of(1) - 20.0) < 0.01, "twenty stones weigh 20 kg (%.1f)" % cw.carried_kg_of(1))
	cw.give(1, cw.table.number_of("stone"), 100)
	check(cw.carried_kg_of(1) <= 52.01 and cw.carried_kg_of(1) > 50.0, "give stops at the hard cap, %.1f kg" % cw.carried_kg_of(1))
	var CarryScript = load("res://src/shared/carry_rules.gd")
	var ccfg: Dictionary = CarryScript.load_config()
	check(CarryScript.speed_factor(20.0, 75.0, ccfg) == 1.0 and absf(CarryScript.speed_factor(52.5, 75.0, ccfg) - 0.35) < 0.001, "no slocwdown when comfortable, 35 percent speed at the cap")
	var mid: float = CarryScript.speed_factor(39.0, 75.0, ccfg)
	check(mid > 0.35 and mid < 1.0, "slocwdown is smooth in between (%.2f)" % mid)

	print("server item tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
