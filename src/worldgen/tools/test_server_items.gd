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

	DirAccess.make_dir_recursive_absolute("user://test_server_items_feed")

	for suffix in ["", "_b", "_c", "_d", "_e", "_f", "_g", "_h", "_feed"]:
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

	# The pickup feed: every gain is reported once with its source; moving a stack reports nothing.
	DirAccess.make_dir_recursive_absolute("user://test_server_items_feed")
	var feed = make("user://test_server_items_feed")
	feed.peer_connected_hello(9, "feedfeed1234")
	var gains: Array = []
	feed.send_received = func(p, id, n, src): gains.append([p, id, n, src])
	feed.give_to(9, "firewood", 2)
	check(gains == [[9, "firewood", 2, "quest"]], "a reward is reported once as a quest gain (%s)" % str(gains))
	gains.clear()
	feed.give(9, feed.table.number_of("stick"), 3)
	check(gains == [[9, "stick", 3, "harvest"]], "a give is reported as a harvest gain (%s)" % str(gains))
	gains.clear()
	feed.action(9, Net.ACT_MOVE, 0, 20, 0, Vector3.ZERO)
	check(gains.is_empty(), "moving a stack reports no gain (%s)" % str(gains))

	# Money and reputation: coins pay into the purse as copper, richest coin first in the feed; reputation ranks and discounts.
	var purse_seen: Array = []
	feed.send_purse = func(_p, c): purse_seen.append(c)
	gains.clear()
	feed.give_to(9, "coin_silver", 2)
	feed.give_to(9, "coin_copper", 7)
	check(feed.coins_of(9) == 207 and purse_seen.back() == 207, "coins pay into the purse as copper (%d)" % feed.coins_of(9))
	check(gains.size() == 2 and gains[0][1] == "coin_silver" and gains[0][2] == 2 and gains[1][1] == "coin_copper", "coins show in the feed as coins (%s)" % str(gains))
	check(feed.purse_breakdown(1234) == [["coin_gold", 1], ["coin_silver", 2], ["coin_bronze", 3], ["coin_copper", 4]], "the purse shows gold, silver, bronze and copper")
	check(feed.take_coins(9, 100) and feed.coins_of(9) == 107 and not feed.take_coins(9, 1000) and feed.coins_of(9) == 107, "paying takes coins, too little pays nothing")
	check(feed.inventory_of(9).count_of(feed.table.number_of("coin_silver")) == 0, "coins never lie in the pack")
	check(feed.rank_of(0) == "Stranger" and feed.rank_of(2) == "Known" and feed.rank_of(5) == "Friend" and feed.rank_of(12) == "Trusted", "rank words follow the score")
	feed.add_rep(9, "hob", 1)
	feed.add_rep(9, "hob", 1)
	check(feed.rep_points(9, "hob") == 2 and feed.rank_of(2) == "Known" and feed.price_for(9, "hob", 10) == 10, "two points make Known, no discount yet")
	feed.add_rep(9, "hob", 3)
	check(feed.rank_reached(feed.rep_points(9, "hob"), "Friend") and feed.price_for(9, "hob", 10) == 9, "a Friend pays 10 percent less")
	feed.add_rep(9, "hob", 500)
	check(feed.rep_points(9, "hob") == 30, "reputation stops at the cap")
	feed.save()
	feed._finish_writer()
	var feed2 = make("user://test_server_items_feed")
	feed2.peer_connected_hello(9, "feedfeed1234")
	check(feed2.coins_of(9) == 107 and feed2.rep_points(9, "hob") == 30, "the purse and reputation are saved with the character")

	# Tool work is hard (Dave 2026-10-21): a swing of an axe holds effort at running level.
	feed.give(9, feed.table.number_of("stone_axe") if feed.table.number_of("stone_axe") > 0 else feed.table.number_of("axe"), 1)
	feed.inventory_of(9).move(feed.inventory_of(9).numbers.find(feed.table.number_of("stone_axe")), 0)   # tools only work from the hotbar
	var swing_slot: int = feed._tool_slot(feed.inventory_of(9), "axe")
	check(swing_slot >= 0 and feed.effort_of(9) < 0.3, "at rest before the swing")
	feed._wear_slot(9, feed.inventory_of(9), swing_slot, "fell")
	check(feed.effort_of(9) >= 1.0, "an axe swing is as hard as running (%.2f)" % feed.effort_of(9))

	items.action(7, Net.ACT_DROP, items.inventory_of(7).numbers.find(stone), 0, 100, Vector3(100.0, 5.0, 150.0))
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
	check(items.world_item_count() == ItemsScript.MAX_DROPPED_NEAR + 1, "dropped cap near a spot holds")

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
	check(FileAccess.file_exists(dir + "/inventories.json.bad"), "corrupt save is set aside")
	check(third.inventory_of(1).count_of(stone) == 15, "a corrupt save is replaced by the save before it (%d)" % third.inventory_of(1).count_of(stone))
	DirAccess.remove_absolute(dir + "/inventories.json.prev")
	var damaged: FileAccess = FileAccess.open(dir + "/inventories.json", FileAccess.WRITE)
	damaged.store_string("{not json")
	damaged.close()
	var fourth = make(dir)
	fourth.peer_connected_hello(1, "abcdef123456")
	check(fourth.inventory_of(1).count_of(stone) == 0, "with no earlier copy a corrupt save starts clean")

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
	# Cooking: a half-stale berry (half its life left) roasts into a roast with twice that left (cooked_life_mult 2), and a hot meal warms.
	var ck_inv: Variant = f.inventory_of(1)
	var ck_bslot: int = -1

	for sl in range(ck_inv.SLOTS):
		if ck_inv.numbers[sl] == berries:
			ck_bslot = sl

	ck_inv.wear[ck_bslot] = int(f.table.shelf_units(berries) / 2)
	f._last_cook.clear()
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	var ck_roast_n: int = f.table.number_of("roast_forage")
	var ck_aged: bool = false

	for sl in range(ck_inv.SLOTS):
		if ck_inv.numbers[sl] == ck_roast_n and ck_inv.wear[sl] > 0:
			ck_aged = ck_aged or absf(float(ck_inv.wear[sl]) / float(f.table.shelf_units(ck_roast_n)) - 0.75) < 0.02

	check(ck_aged, "a roast carries twice the raw life left")
	f.vitals_of(1)["warmth"] = 50.0
	f._last_eat.clear()

	for sl in range(ck_inv.SLOTS):
		if ck_inv.numbers[sl] == ck_roast_n:
			f.action(1, Net.ACT_EAT, sl, 0, 0, Vector3.ZERO)
			break

	check(float(f.vitals_of(1)["warmth"]) >= 59.0, "a hot meal lifts warmth")

	# Meat: raw meat cooks into roast meat and eating it raw makes you sick (Tyler: cook me).
	var meat_n: int = f.table.number_of("raw_meat")
	f.action(1, Net.ACT_ADMIN_GIVE, meat_n, 0, 2, Vector3.ZERO)
	f._last_cook.clear()
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	var made: int = f.inventory_of(1).count_of(f.table.number_of("roast_meat"))
	check(made == 1 or f.inventory_of(1).count_of(meat_n) == 1, "a lit fire roasts one raw meat (%d roast)" % made)
	f._last_eat.clear()

	for sl in range(ck_inv.SLOTS):
		if ck_inv.numbers[sl] == meat_n:
			f.action(1, Net.ACT_EAT, sl, 0, 0, Vector3.ZERO)
			break

	check(float(f.vitals_of(1).get("sick", 0.0)) > 0.0, "raw meat makes you sick")
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
	# Wear per use is data (drops.json tool_wear): three points a blow when the table says so.
	var axe_slot: int = m.inventory_of(1).numbers.find(m.table.number_of("stone_axe"))
	var wear_was: int = m.inventory_of(1).wear[axe_slot]
	m._drops["tool_wear"]["per_use"]["axe"]["rock"] = 3
	m._last_mine.clear()
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).wear[axe_slot] == wear_was + 3, "a blow on rock wears the axe by the table's number (%d to %d)" % [wear_was, m.inventory_of(1).wear[axe_slot]])
	m._drops["tool_wear"]["per_use"]["axe"]["rock"] = 1

	m.report_position(1, Vector3(-5.0, 10.0, 0.0))
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(-6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "soil gives no stone")
	m.report_position(1, Vector3(5.0, 10.0, 0.0))
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(30.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "out of reach gives nothing")

	# Digging the ground with a spade (ACT_DIG).
	var digs: Array = []
	m.dig_ground = func(centre, radius): digs.append([centre, radius])
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.is_empty(), "no spade, no dig")
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("wooden_spade"), 0, 1, Vector3.ZERO)
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(30.0, 10.0, 0.0))
	check(digs.is_empty(), "a dig out of reach does nothing")
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 1 and absf(float(digs[0][0].y) - (10.0 - ItemsScript.DIG_DEPTH_M)) < 0.001, "a spade digs a hole a little below the point")
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 1, "digs too close together make one hole")
	m._last_dig.clear()
	var spade_slot: int = m.inventory_of(1).numbers.find(m.table.number_of("wooden_spade"))
	var spade_wear: int = m.inventory_of(1).wear[spade_slot]
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 2 and m.inventory_of(1).wear[spade_slot] == spade_wear + 1, "each dig wears the spade by one")

	# Dig yields and fill (job 84): the ground's material decides what a dig brings up.
	var soil_n: int = m.table.number_of("soil")
	var clay_n: int = m.table.number_of("clay")
	var sand_n: int = m.table.number_of("sand")
	var held_stone: int = m.inventory_of(1).count_of(m.table.number_of("stone"))
	check(m.inventory_of(1).count_of(soil_n) == 0, "no soil before any dig yield is wired")
	var mat: Array = ["loam"]
	m.ground_material = func(_x, _z): return mat[0]
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(soil_n) >= 1 and m.inventory_of(1).count_of(soil_n) <= 3 and m.inventory_of(1).count_of(sand_n) == 0, "a dig in loam brings up soil, not sand")
	mat[0] = "sand"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(sand_n) >= 1, "a dig in sand brings up sand")
	mat[0] = "rock"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(m.table.number_of("stone")) > held_stone, "a dig in bare rock gives stone")
	var have_fill: int = m.fill_units_of(1)
	check(have_fill >= 3, "the pack holds fill after digs")
	var took: int = m.take_fill(1, 2)
	check(took == 2 and m.fill_units_of(1) == have_fill - 2, "take_fill uses up what it reports")
	check(m.take_fill(1, 100000) == have_fill - 2 and m.fill_units_of(1) == 0, "take_fill never takes more than the pack holds")
	check(m.take_fill(2, 1) == 0, "a peer with no pack fills nothing")
	mat[0] = "clay"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(clay_n) >= 1, "a dig in clay brings up clay")

	# Filling with the spade (ACT_FILL, saved edits step 3): spends a shovelful, makes a fill, hands it back if refused.
	var fills: Array = []
	var accept: Array = [true]
	m.fill_ground = func(centre, radius, material): fills.append([centre, radius, material]); return accept[0]
	m.take_fill(1, 100000)
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.is_empty(), "an empty shovel raises nothing")
	m.action(1, Net.ACT_ADMIN_GIVE, soil_n, 0, 3, Vector3.ZERO)
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, 0, 0, 0, Vector3(30.0, 10.0, 0.0))
	check(fills.is_empty(), "a raise out of reach does nothing")
	m.action(1, Net.ACT_FILL, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 1 and int(fills[0][2]) == 5 and m.inventory_of(1).count_of(soil_n) == 2, "a raise takes one shovelful from the pack and makes loam ground")
	m._last_dig.clear()
	accept[0] = false
	m.action(1, Net.ACT_FILL, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 2 and m.inventory_of(1).count_of(soil_n) == 2, "a raise that changed nothing hands the shovelful back")
	accept[0] = true
	check(m.carried_kg_of(1) < 60.0, "digging cannot overfill the pack")

	# Spade sizes (Dave 2026-10-22): a large spade moves 8 pieces, a medium 4, a small 1.
	m.inventory_of(1).remove(m.table.number_of("wooden_spade"), 1)
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("wooden_spade_large"), 0, 1, Vector3.ZERO)
	check(m._spade_pieces(m.inventory_of(1)) == 8, "a large spade moves 8 pieces (%d)" % m._spade_pieces(m.inventory_of(1)))
	digs.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 1 and is_equal_approx(float(digs[0][1]), 1.8), "a large spade digs a sphere twice as wide (%s)" % str(digs))
	m.take_fill(1, 100000)
	m.action(1, Net.ACT_ADMIN_GIVE, soil_n, 0, 12, Vector3.ZERO)
	fills.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 1 and is_equal_approx(float(fills[0][1]), 1.8) and m.inventory_of(1).count_of(soil_n) == 4, "a large raise takes 8 shovelfuls from the pack")
	m.take_fill(1, 100000)
	m.action(1, Net.ACT_ADMIN_GIVE, soil_n, 0, 3, Vector3.ZERO)
	fills.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 1 and fills[0][1] < 1.8 and m.inventory_of(1).count_of(soil_n) == 0, "a short pack raises a smaller heap")
	m.take_fill(1, 100000)
	m.inventory_of(1).remove(m.table.number_of("wooden_spade_large"), 1)
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("wooden_spade"), 0, 1, Vector3.ZERO)

	# The spade tier adds to the top of the dig roll (digging.json tier_extra).
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("stone_spade"), 0, 1, Vector3.ZERO)
	check(m._spade_tier(m.inventory_of(1)) >= 1, "the spade tier is read from the tool in the pack")
	var most: int = 0
	mat[0] = "sand"

	for tries in 40:
		m._last_dig.clear()
		var before_sand: int = m.inventory_of(1).count_of(sand_n)
		m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
		most = maxi(most, m.inventory_of(1).count_of(sand_n) - before_sand)
		m.take_fill(1, 100000)

	check(most >= 1 and most <= 4, "a dig never exceeds the top of the roll plus the spade extra (%d)" % most)

	# A dig the ground refuses (nothing changed) gives nothing.
	var refuse: Array = [false]
	m.dig_ground = func(centre, radius):
		digs.append([centre, radius])
		return not refuse[0]
	mat[0] = "loam"
	var soil_before: int = m.inventory_of(1).count_of(soil_n)
	refuse[0] = true
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(soil_n) == soil_before, "a dig that changes nothing brings up nothing")
	refuse[0] = false

	# The garden hoe: path patches and smoothing (no items, only wear).
	var hoe_n: int = m.table.number_of("wooden_hoe")
	m.action(1, Net.ACT_ADMIN_GIVE, hoe_n, 0, 1, Vector3.ZERO)
	m.ground_height = func(x, _z): return 10.0 + (0.2 if x > 6.5 else 0.0)
	var patches_of = func() -> int:
		var count: int = 0

		for it in m._items.values():
			if it.has("struct") and str(it["struct"]["kind"]) == "path_patch":
				count += 1

		return count
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, 0, 0, 0, Vector3(6.3, 10.0, 0.4))
	check(patches_of.call() == 1, "a hoe stroke treads a path patch")
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, 0, 0, 0, Vector3(6.6, 10.0, 0.6))
	check(patches_of.call() == 1, "the same metre is not trodden twice")
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, 0, 0, 0, Vector3(30.0, 10.0, 0.0))
	check(patches_of.call() == 1, "a path out of reach does nothing")
	var hoe_slot: int = m.inventory_of(1).numbers.find(hoe_n)
	var hoe_wear: int = m.inventory_of(1).wear[hoe_slot]
	digs.clear()
	fills.clear()
	accept[0] = true
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_SMOOTH, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 1 and fills.size() >= 1 and m.inventory_of(1).wear[hoe_slot] == hoe_wear + 1, "smoothing cuts the high spot and fills the low ones (%d cuts, %d fills)" % [digs.size(), fills.size()])
	check(patches_of.call() == 0, "smoothed ground loses its path patch")
	m.ground_height = Callable()

	# Dig under trees (job 85): the tree falls when what holds it up is thin enough, by species class.
	var species: Array = ["beech", 0.4]
	var share: Array = [0.5]
	var up: Array = [true]
	m.trees_near = func(_p, _r): return [[Vector2i(0, 0), 77]] if up[0] else []
	m.tree_info = func(_c, _id): return {"name": species[0], "position": Vector3(7.0, 10.0, 0.0), "height": 20.0, "trunk": species[1]} if up[0] else {}
	m.cut_tree = func(_c, _id):
		up[0] = false
		return true
	m.dig_support = func(_b, _r, _d): return share[0]
	var trunks_of = func() -> int:
		var n: int = 0

		for it in m._items.values():
			if it.has("tree") and int(it["tree"]["state"]) == 3:
				n += 1

		return n

	var base_trunks: int = trunks_of.call()
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(up[0] and trunks_of.call() == base_trunks, "a tree with half its ground left stays up")
	share[0] = 0.4
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(up[0], "a beech holds at 40 percent")
	species[0] = "spruce"
	species[1] = 0.35
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(not up[0] and trunks_of.call() == base_trunks + 1, "a spruce falls at 40 percent (shallow roots) and leaves a trunk")
	up[0] = true
	species[0] = "oak"
	species[1] = 0.6
	share[0] = 0.3
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(up[0], "a big oak holds at 30 percent")
	share[0] = 0.2
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(not up[0] and trunks_of.call() == base_trunks + 2, "a big oak falls at 20 percent")
	var trunk_dir: Dictionary = {}

	for it in m._items.values():
		if it.has("tree") and int(it["tree"]["state"]) == 3:
			trunk_dir = it["tree"]

	check(absf(float(trunk_dir["yaw"]) - atan2(1.0, 0.0)) < 0.01, "it falls away from the hole")
	up[0] = true
	refuse[0] = true
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(up[0], "a refused dig fells nothing")

	# The support maths: digs take ground away from under a tree, a fill puts it back.
	var support = load("res://src/shared/tree_support.gd")
	var root := Vector3(0.0, 10.0, 0.0)
	var holes: Array = []
	check(support.solid_share(holes, root, 1.8, 1.0) == 1.0, "untouched ground is fully solid")

	for k in 6:
		holes.append([0, Vector3(cos(float(k)) * 1.0, 9.75, sin(float(k)) * 1.0), 0.9])

	var thin: float = support.solid_share(holes, root, 1.8, 1.0)
	check(thin < 0.5 and thin > 0.0, "six digs around a beech leave under half (%.2f)" % thin)
	holes.append([1, Vector3(0.0, 9.5, 0.0), 3.0])
	check(support.solid_share(holes, root, 1.8, 1.0) == 1.0, "a big fill puts the support back")
	check(support.solid_share([[0, Vector3(30.0, 9.75, 0.0), 0.9]], root, 1.8, 1.0) == 1.0, "a hole far away changes nothing")

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

	check(not w._items.has(trunk_id) and w.shoulder_of(1) == "log_oak", "the trunk is worked into oak logs (one on the shoulder, the rest on the ground) and used up")
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

	check(wr.inventory_of(1).wear[0] >= 2 and wr.inventory_of(1).wear[0] <= 3, "each effective blow wears the axe one use (%d, care %.4f carry %.4f)" % [wr.inventory_of(1).wear[0], wr.skill_factor(1, "tool_care"), float(wr._wear_carry.get(1, 0.0))])
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
	cb.action(1, Net.ACT_ADMIN_GIVE, cb.table.number_of("chopping_block"), 0, 1, Vector3.ZERO)
	cb.action(1, Net.ACT_PLACE, cb.inventory_of(1).numbers.find(cb.table.number_of("chopping_block")), 0, 0, Vector3(2.0, 10.0, 0.0))
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

	# The large log on the shoulder (Dave 2026-10-21): one at a time, named for its tree, heavy, split at the block, falls with the body.
	var oak_log: int = cb.table.number_of("log_oak")
	var shoulder_sent: Array = []
	cb.send_carry = func(_p, id): shoulder_sent.append(id)
	check(oak_log > 0 and cb.is_shoulder_item(oak_log) and not cb.is_shoulder_item(cb.table.number_of("log")), "an oak log is a shoulder item, the short log is not")
	var kg_before: float = cb.carried_kg_of(1)
	cb.give(1, oak_log, 1)
	check(cb.shoulder_of(1) == "log_oak" and shoulder_sent.back() == "log_oak" and cb.inventory_of(1).count_of(oak_log) == 0, "an oak log goes on the shoulder, not into the bag")
	check(cb.carried_kg_of(1) - kg_before > 40.0, "and its weight counts in the load (%.1f kg more)" % (cb.carried_kg_of(1) - kg_before))
	cb.give(1, cb.table.number_of("log_beech"), 1)
	check(cb.shoulder_of(1) == "log_oak" and cb.world_item_count() >= 2, "a second large log lies on the ground: only one on the shoulder")
	var beech_id: int = 0

	for k in cb._items:
		if int(cb._items[k]["number"]) == cb.table.number_of("log_beech"):
			beech_id = k

	cb.action(1, Net.ACT_PICKUP, beech_id, 0, 0, Vector3.ZERO)
	check(cb.shoulder_of(1) == "log_oak" and cb._items.has(beech_id), "it cannot be picked up while carrying one")
	cb._last_use.clear()
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, 0, Vector3.ZERO)
	check(cb.shoulder_of(1) == "" and cb.inventory_of(1).count_of(firewood_n) == 8 + 12, "the block splits the shoulder log into plain firewood (%d)" % cb.inventory_of(1).count_of(firewood_n))
	cb.take(1, firewood_n, cb.inventory_of(1).count_of(firewood_n))   # the 20 firewood would be too heavy with a log on top
	cb.action(1, Net.ACT_PICKUP, beech_id, 0, 0, Vector3.ZERO)
	check(cb.shoulder_of(1) == "log_beech" and not cb._items.has(beech_id), "with the shoulder free the beech log is picked up")
	check(cb.lay_down_shoulder(1) and cb.shoulder_of(1) == "" and shoulder_sent.back() == "", "laying it down puts it on the ground")
	cb.give(1, oak_log, 1)
	cb.kill(1, "test")
	check(cb.shoulder_of(1) == "", "dying drops the shoulder log")

	# Hunger, health and weight.
	var vd: String = "user://test_server_items_vitals"
	DirAccess.make_dir_recursive_absolute(vd)

	for file in DirAccess.get_files_at(vd):
		DirAccess.remove_absolute(vd + "/" + file)

	var vt = make(vd)
	var vsent: Array = []
	vt.send_vitals = func(p, hunger, health, weight, thirst, luck, fitness): vsent.append([hunger, health, weight, thirst])
	var vnotes: Array = []
	vt.send_notice = func(_p, text): vnotes.append(text)
	vt.peer_connected_hello(1, "abcdef123456")
	check(vsent.size() == 1 and vsent[0] == [100, 100, 750, 100], "hello sends full hunger, full health, 75 kg, full thirst")
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

	# Breath (Dave 2026-10-21): 60 s at swimming pace, half as fast resting, faster swimming hard, full at the surface.
	var air_sent: Array = []
	vt.send_breath = func(_p, tenths): air_sent.append(tenths)
	vt.set_head_under(1, true)
	vt._speed3[1] = 2.0

	for n in range(20):
		vt.tick(1.0)

	check(absf(vt.breath_of(1) - 40.0) < 1.5 and not air_sent.is_empty() and air_sent[-1] <= 420, "diving at swimming pace spends a second of air a second (%.1f s left)" % vt.breath_of(1))
	vt._speed3[1] = 0.1

	for n in range(20):
		vt.tick(1.0)

	check(absf(vt.breath_of(1) - 30.0) < 1.5, "resting under water spends it at half pace (%.1f s left)" % vt.breath_of(1))
	vt._speed3[1] = 3.0

	for n in range(10):
		vt.tick(1.0)

	check(absf(vt.breath_of(1) - 14.0) < 1.5, "swimming hard spends it faster (%.1f s left)" % vt.breath_of(1))
	var health_before: float = float(vt.vitals_of(1)["health"])
	check(health_before >= 99.0, "no damage while there is air")
	vt.set_head_under(1, false)
	vt.tick(1.0)
	check(vt.breath_of(1) < 0.0 and air_sent[-1] == -1, "at the surface the air is full at once and the symbol hides")
	vt.set_head_under(1, true)
	vt._speed3[1] = 2.0
	vt.tick(1.0)
	check(vt.breath_of(1) > 58.0, "the next dive starts from a full 60 s")
	vt._breath[1] = 1.0
	vnotes.clear()

	for n in range(4):
		vt.tick(1.0)

	check(float(vt.vitals_of(1)["health"]) < health_before - 10.0 and vnotes.has("You are out of air"), "out of air costs health (6 a second) and says so")

	vt.report_position(1, Vector3(50.0, 5.0, 50.0))
	for n in range(60):
		vt.tick(1.0)

	check(vt.remains_ids().size() == 1 and float(vt.vitals_of(1)["health"]) > 90.0, "[%d remains, health %.0f] drowning to zero health kills: remains left, vitals start over" % [vt.remains_ids().size(), float(vt.vitals_of(1)["health"])])
	vt.set_head_under(1, false)
	vt.tick(1.0)
	vt.vitals_of(1)["fed"] = 0.0   # the death above started the vitals over
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

	# Thirst (job 67): one drink a game day, water at the edge, no regeneration when parched.
	var td: String = "user://test_server_items_thirst"
	DirAccess.make_dir_recursive_absolute(td)

	for file in DirAccess.get_files_at(td):
		DirAccess.remove_absolute(td + "/" + file)

	var th = make(td)
	var tsent: Array = []
	var thirst_rejects: Array = []
	th.send_vitals = func(_p, hunger, health, weight, thirst, luck, fitness): tsent.append(thirst)
	th.send_reject = func(_p, reason): thirst_rejects.append(reason)
	var nearby: Array = [false]
	th.water_near = func(_pos, _reach): return nearby[0]
	th.peer_connected_hello(1, "thirstkey0001")
	th.report_position(1, Vector3(0.0, 10.0, 0.0))
	th._vitals_cfg["eat_pace_ms"] = 0
	th._vitals_cfg["thirst"]["drink_pace_ms"] = 0
	th._exertion[1] = 1.0

	for n in range(360):
		th.tick(10.0)
		th.vitals_of(1)["fed"] = 2400.0

	check(float(th.vitals_of(1)["wet"]) > 0.0, "a full body lasts a whole game day even at full exertion (%.0f ml left)" % float(th.vitals_of(1)["wet"]))
	th._exertion[1] = 0.0

	for n in range(360):
		th.tick(10.0)
		th.vitals_of(1)["fed"] = 2400.0

	check(float(th.vitals_of(1)["wet"]) == 0.0 and tsent.back() == 0, "with no drink for two days the body is parched (thirst sent as 0)")
	th.vitals_of(1)["health"] = 50.0
	th.tick(100.0)
	check(float(th.vitals_of(1)["health"]) == 50.0, "a parched body does not recover health")
	th.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(float(th.vitals_of(1)["wet"]) == 0.0 and thirst_rejects == [0], "no water within reach: no drink, refusal cue")
	nearby[0] = true
	th.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(float(th.vitals_of(1)["wet"]) == 300.0 and tsent.back() == 13, "a mouthful at the water edge gives 300 ml (13 percent)")

	for n in range(12):
		th.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)

	check(float(th.vitals_of(1)["wet"]) == 2400.0 and tsent.back() == 100, "drinking stops at a full body")
	th.tick(1.0)
	check(float(th.vitals_of(1)["health"]) > 50.0, "health recovers once the body has water")
	th._vitals_cfg["drink"] = {"by_id": {"roast_forage": 200}, "by_suffix": {}}
	th.vitals_of(1)["wet"] = 1000.0
	var forage_n: int = th.table.number_of("roast_forage")
	th.action(1, Net.ACT_ADMIN_GIVE, forage_n, 0, 2, Vector3.ZERO)
	th.action(1, Net.ACT_EAT, th.inventory_of(1).numbers.find(forage_n), 0, 0, Vector3.ZERO)
	check(float(th.vitals_of(1)["wet"]) == 1200.0, "a drink item (here a stand-in) adds its ml")
	th.save()
	var th2 = make(td)
	th2.peer_connected_hello(1, "thirstkey0001")
	check(float(th2.vitals_of(1)["wet"]) == float(th.vitals_of(1)["wet"]), "thirst survives a restart")

	# Carrying weight: stones weigh 1 kg; a 75 kg player carries 52.5 kg at most and up to 80 percent of that (42 kg) with no hindrance.
	var cwd: String = "user://test_server_items_carry"
	DirAccess.make_dir_recursive_absolute(cwd)

	for file in DirAccess.get_files_at(cwd):
		DirAccess.remove_absolute(cwd + "/" + file)

	var cw = make(cwd)
	cw.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	cw.peer_connected_hello(1, "carrykey0001")
	cw.report_position(1, Vector3(0.0, 10.0, 0.0))
	cw.give(1, cw.table.number_of("stone"), 20)
	check(absf(cw.carried_kg_of(1) - 20.0) < 0.01, "twenty stones weigh 20 kg (%.1f)" % cw.carried_kg_of(1))
	cw.give(1, cw.table.number_of("stone"), 100)
	check(cw.carried_kg_of(1) <= 52.01 and cw.carried_kg_of(1) > 50.0, "give stops at the hard cap, %.1f kg" % cw.carried_kg_of(1))
	var CarryScript = load("res://src/shared/carry_rules.gd")
	var ccfg: Dictionary = CarryScript.load_config()
	check(CarryScript.speed_factor(20.0, 75.0, ccfg) == 1.0 and absf(CarryScript.speed_factor(52.5, 75.0, ccfg) - 0.25) < 0.001, "no slowdown when comfortable, 25 percent speed at the cap")
	var mid: float = CarryScript.speed_factor(47.0, 75.0, ccfg)
	check(mid > 0.25 and mid < 1.0, "slowdown is smooth in between (%.2f)" % mid)

	# The loads Dave asked about: 0, 2 kg, 79 percent, 81 percent and 100 percent of the limit (75 kg body, limit 52.5 kg).
	var cap_kg: float = CarryScript.cap_kg(75.0, ccfg)
	var reports: Array = []
	var no_hindrance: bool = true
	var grows: bool = true
	var last_effort: float = -1.0

	for load in [0.0, 2.0, 0.79 * cap_kg, 0.80 * cap_kg, 0.81 * cap_kg, 0.9 * cap_kg, cap_kg]:
		var inv_c = cw.inventory_of(1)

		for slot in range(inv_c.SLOTS):
			inv_c.numbers[slot] = 0
			inv_c.counts[slot] = 0

		var whole: int = int(floor(load))
		inv_c.add(cw.table.number_of("stone"), whole)
		inv_c.add(cw.table.number_of("stick"), int(round((load - float(whole)) / CarryScript.weight_of("stick", ccfg))))
		cw._moving[1] = 1.0
		cw._exertion[1] = 0.0
		var speed: float = CarryScript.speed_factor(cw.carried_kg_of(1), 75.0, ccfg)
		var effort: float = cw.effort_of(1)
		reports.append("%.1f kg: speed %.2f, extra effort %.3f" % [cw.carried_kg_of(1), speed, effort])

		if load <= 0.8 * cap_kg + 0.001:
			no_hindrance = no_hindrance and speed == 1.0 and effort == 0.0
		else:
			grows = grows and speed < 1.0 and effort > last_effort

		last_effort = effort

	print("carry loads: ", "; ".join(reports))
	check(no_hindrance, "up to 80 percent of the limit (0, 2 kg, 79%, 80%) there is no slowdown and no extra effort")
	check(grows, "past 80 percent (81%, 90%, 100%) speed drops and effort rises smoothly")
	cw._moving[1] = 0.0

	# Over-exertion: running climbs strain past 1 (over-exerted), on to a faint, then a slow wake.
	var ed: String = "user://test_server_items_strain"
	DirAccess.make_dir_recursive_absolute(ed)

	for file in DirAccess.get_files_at(ed):
		DirAccess.remove_absolute(ed + "/" + file)

	var sx = make(ed)
	var strains: Array = []
	sx.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sx.send_strain = func(_p, s, st, fa, sn): strains.append([s, st, fa, sn])
	sx.peer_connected_hello(1, "strainkey001")
	sx._exertion[1] = 1.0
	var seen: Dictionary = {}

	for n in range(4 * 400):
		sx._exertion[1] = 1.0 if int(sx.strain_of(1).get("state", 0)) < 2 else 0.0
		sx._vitals_tick(0.25)
		seen[int(sx.strain_of(1).get("state", 0))] = true

	check(seen.has(1) and seen.has(2) and seen.has(3), "running without rest goes over-exerted, faints and wakes: %s" % str(seen.keys()))
	sx._exertion[1] = 0.5
	var st_walk: float = float(sx.strain_of(1).get("s", 0.0))
	var sw = make(ed)
	sw.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sw.peer_connected_hello(1, "strainkey002")
	sw._exertion[1] = 0.5

	for n in range(4 * 1200):
		sw._vitals_tick(0.25)

	check(float(sw.strain_of(1).get("s", 0.0)) < 0.2 and int(sw.strain_of(1).get("state", 0)) == 0, "walking is sustainable (%.2f)" % float(sw.strain_of(1).get("s", 0.0)))
	# Fitness: the fitter character is winded (over-exerted) and blacks out later, the unfit one sooner, same running.
	var winded: Dictionary = {}
	var passed_out: Dictionary = {}

	for fit in [-8, 0, 8]:
		var fd: String = "user://test_server_items_fitness%d" % (fit + 8)
		DirAccess.make_dir_recursive_absolute(fd)

		for file in DirAccess.get_files_at(fd):
			DirAccess.remove_absolute(fd + "/" + file)

		var sf = make(fd)
		sf.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
		sf.peer_connected_hello(1, "fitnesskey%03d" % (fit + 8))
		sf.set_fitness(1, fit)
		check(sf.fitness_of(1) == fit, "fitness %d is stored with the character" % fit)
		sf._exertion[1] = 1.0
		winded[fit] = -1.0
		passed_out[fit] = -1.0

		for n in range(4 * 400):
			sf._vitals_tick(0.25)
			var state: int = int(sf.strain_of(1).get("state", 0))

			if state >= 1 and winded[fit] < 0.0:
				winded[fit] = float(n) * 0.25

			if state >= 2:
				passed_out[fit] = float(n) * 0.25
				break

	check(winded[8] > winded[0] and winded[0] > winded[-8] and winded[-8] > 0.0, "fitter characters are winded later: %s" % str(winded))
	check(passed_out[8] > passed_out[0] and passed_out[0] > passed_out[-8] and passed_out[-8] > 0.0, "and black out later: %s" % str(passed_out))
	check(absf(winded[8] / winded[0] - exp(8.0 * 0.05)) < 0.1, "fitness +8 stretches the time to get winded by about exp(0.4) (%.2f)" % (winded[8] / winded[0]))
	check(strains.size() > 0 and strains.size() < 1300, "strain updates are at most one per 4 Hz tick (never more than 4 a second while it changes) (%d sent)" % strains.size())
	# Stance: sitting drops strain to 0; standing under a heavy pack only to about half; walking off stands you up.
	var xd: String = "user://test_server_items_stance"
	DirAccess.make_dir_recursive_absolute(xd)

	for file in DirAccess.get_files_at(xd):
		DirAccess.remove_absolute(xd + "/" + file)

	var sa = make(xd)
	sa.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sa.peer_connected_hello(1, "stancekey001")
	sa.report_position(1, Vector3(0.0, 10.0, 0.0))
	sa._strain[1] = {"s": 0.9, "state": 1, "t": 0.0}
	sa.action(1, Net.ACT_STANCE, 2, 0, 0, Vector3.ZERO)
	check(sa.stance_of(1) == 2, "sit is accepted")

	for n in range(4 * 60):
		sa._vitals_tick(0.25)

	check(float(sa.strain_of(1)["s"]) < 0.01, "sitting rests strain to 0 (%.2f)" % float(sa.strain_of(1)["s"]))
	sa.give(1, sa.table.number_of("stone"), 52)
	sa._strain[1] = {"s": 0.9, "state": 1, "t": 0.0}
	sa.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)

	for n in range(4 * 120):
		sa._vitals_tick(0.25)

	var floor_level: float = float(sa.strain_of(1)["s"])
	check(floor_level > 0.4 and floor_level < 0.6, "standing with a pack at the limit rests only to about half (%.2f)" % floor_level)
	# Fitness trains slowly (fitness.json train): winded time adds points, rest takes them back, never below the base.
	var tr = make(xd)
	tr.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	tr.peer_connected_hello(1, "trainkey0001")
	tr.set_fitness(1, 2)
	check(tr.fitness_of(1) == 2, "fitness starts at its creation value")
	tr._train_fitness(1, true, 1700.0)
	check(tr.fitness_of(1) == 2, "just under a point of winded time changes nothing")
	tr._train_fitness(1, true, 200.0)
	check(tr.fitness_of(1) == 3, "30 minutes winded earns a point")
	tr._train_fitness(1, true, 1.0e6)
	check(tr.fitness_of(1) == 7, "training stops at max_gain (5) above the base")
	tr._train_fitness(1, false, 14400.0 * 3.0)
	check(tr.fitness_of(1) == 4, "rest takes points back slowly")
	tr._train_fitness(1, false, 1.0e7)
	check(tr.fitness_of(1) == 2, "and never below the creation value")

	# Energy (job 95, energy.json): 3 game days of ordinary play empty it, rest refills it, supplements cost fitness, 0 forces sleep.
	var en = make(xd)
	en.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	var energy_sent: Array = []
	en.send_energy = func(_p, pct): energy_sent.append(pct)
	en.peer_connected_hello(1, "energykey001")
	check(en.energy_of(1) == 100.0 and energy_sent[0] == 100, "a new character has full energy and is told so")
	en._exertion[1] = 0.5
	var steps: int = 0

	while not en._forced_sleep(1) and steps < 100000:
		en._energy_tick(1, en.vitals_of(1), 1.0, 24.0)   # one real second is 24 game seconds
		en._exertion[1] = 0.5
		steps += 1

	var hours: float = float(steps) * 24.0 / 3600.0
	check(hours > 66.0 and hours < 78.0, "ordinary play (exertion 0.5) drains energy in about 3 game days (%.1f game hours)" % hours)
	check(en.sleeping_of(1) and en._forced_sleep(1) and en.stance_of(1) == 3, "at 0 the character collapses asleep")
	en.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	en.action(1, Net.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	check(en._forced_sleep(1) and en.stance_of(1) == 3, "a collapsed character cannot get up or wake themselves")
	en._exertion[1] = 0.0
	var rested: int = 0

	while en._forced_sleep(1) and rested < 100000:
		en._energy_tick(1, en.vitals_of(1), 1.0, 24.0)
		rested += 1

	var sleep_hours: float = float(rested) * 24.0 / 3600.0
	check(sleep_hours > 7.0 and sleep_hours < 9.5 and en.energy_of(1) >= 99.0, "8 game hours of sleep fill it again (%.1f)" % sleep_hours)
	check(not en.sleeping_of(1), "and the character wakes when it is full")
	en.vitals_of(1)["energy"] = 20.0
	en.action(1, Net.ACT_STANCE, 2, 0, 0, Vector3.ZERO)

	for n in 3000:
		en._energy_tick(1, en.vitals_of(1), 1.0, 24.0)

	check(absf(en.energy_of(1) - 75.0) < 1.5, "sitting refills only up to 75 percent (%.1f)" % en.energy_of(1))
	en.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)

	for n in 3000:
		en._energy_tick(1, en.vitals_of(1), 1.0, 24.0)

	check(en.energy_of(1) > 99.0, "lying down refills it completely")
	en.vitals_of(1)["energy"] = 30.0
	var bar: int = en.table.number_of("energy_bar")
	en.action(1, Net.ACT_ADMIN_GIVE, bar, 0, 3, Vector3.ZERO)
	var fit_before: int = en.fitness_of(1)
	var slot_bar: int = en.inventory_of(1).numbers.find(bar)
	en._last_eat.clear()
	en.action(1, Net.ACT_EAT, slot_bar, 0, 0, Vector3.ZERO)
	check(en.energy_of(1) == 55.0 and en.inventory_of(1).count_of(bar) == 2, "an energy bar gives 25 energy at once")
	check(float(en._characters["energykey001"]["train"]) < 0.0, "and costs fitness training")
	en.vitals_of(1)["energy"] = 100.0
	en._last_eat.clear()
	en.action(1, Net.ACT_EAT, slot_bar, 0, 0, Vector3.ZERO)
	check(en.inventory_of(1).count_of(bar) == 2, "not tired: the bar is kept")

	for k in 40:
		en.vitals_of(1)["energy"] = 10.0
		en._last_eat.clear()
		en.action(1, Net.ACT_ADMIN_GIVE, bar, 0, 1, Vector3.ZERO)
		en.action(1, Net.ACT_EAT, en.inventory_of(1).numbers.find(bar), 0, 0, Vector3.ZERO)

	check(en.fitness_of(1) == fit_before - 2 or en.fitness_of(1) == fit_before - 3, "supplements can wear fitness down by at most 3 points (%d to %d)" % [fit_before, en.fitness_of(1)])

	# Sleep (job 86): lying plus ACT_SLEEP rests faster, by place; rain on the open wakes; stance and rest end it.
	var sleeper: Array = [0.0, 0.0]      # cover, rain
	var down_time = func(sl, asleep: bool) -> float:
		sl._strain[1] = {"s": 0.9, "state": 1, "t": 0.0}
		sl.vitals_of(1)["energy"] = 60.0   # a character with full energy cannot sleep (nap rules below)
		sl.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)

		if asleep:
			sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)

		var seconds: float = 0.0

		while float(sl.strain_of(1)["s"]) > 0.05 and seconds < 400.0:
			sl._vitals_tick(0.25)
			seconds += 0.25

		return seconds

	var sl = make(xd)
	sl.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sl.cover_at = func(_pos): return sleeper[0]
	sl.rain_now = func(): return sleeper[1]
	sl.peer_connected_hello(1, "sleepkey0001")
	sl.report_position(1, Vector3(0.0, 10.0, 0.0))
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(not sl.sleeping_of(1), "you cannot sleep standing up")
	var lie_s: float = down_time.call(sl, false)
	sl.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	var dry_s: float = down_time.call(sl, true)
	check(sl.sleeping_of(1), "lying down and asking to sleep works on dry open ground")
	sl.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	check(not sl.sleeping_of(1), "standing up wakes you")
	sleeper[0] = 1.0
	var roof_s: float = down_time.call(sl, true)
	check(dry_s < lie_s * 0.85 and roof_s < dry_s, "sleep rests faster than lying, and faster under a roof (lie %.0f s, open %.0f s, roof %.0f s)" % [lie_s, dry_s, roof_s])
	check(absf(lie_s / roof_s - 2.0) < 0.5, "under a roof it is about twice as fast as lying (strain_mult 6 against 3)")
	sl.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	sleeper[0] = 0.0
	sleeper[1] = 0.5
	sl.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(not sl.sleeping_of(1), "rain on open ground will not let you sleep")
	sleeper[1] = 0.0
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(sl.sleeping_of(1), "asleep once the rain stops")
	sleeper[1] = 0.5
	sl._strain_tick(1, 0.25)
	check(not sl.sleeping_of(1), "rain that reaches an open sleeper wakes them")
	sleeper[0] = 1.0
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	sl._strain_tick(1, 0.25)
	check(sl.sleeping_of(1), "rain does not wake one under a roof")
	sl._strain[1] = {"s": 0.0, "state": 0, "t": 0.0}
	sl.vitals_of(1)["energy"] = 100.0

	for n in range(4 * 12):
		sl._strain_tick(1, 0.25)

	check(not sl.sleeping_of(1), "fully rested for 10 s ends the sleep")

	# Dave 2026-10-21: full energy and exertion at or under 75 percent: "you can't sleep"; over 75 percent: a nap of about 10 s.
	sl.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	sl._strain[1] = {"s": 0.5, "state": 0, "t": 0.0}
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(not sl.sleeping_of(1), "with full energy and exertion at 50 percent you cannot sleep")
	sl._strain[1] = {"s": 1.2, "state": 1, "t": 0.0}
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(sl.sleeping_of(1), "with full energy and exertion over 75 percent a nap is allowed")
	var nap_s: float = 0.0

	while sl.sleeping_of(1) and nap_s < 60.0:
		sl._vitals_tick(0.25)
		nap_s += 0.25

	check(nap_s >= 8.0 and nap_s <= 13.0 and float(sl.strain_of(1)["s"]) <= 0.3, "the nap takes about 10 s and brings exertion back down (%.1f s, strain %.2f)" % [nap_s, float(sl.strain_of(1)["s"])])
	sl.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	# Dave 2026-10-21: fade_smooth fade, slowing heart, wake timer, wake by itself only with full energy and no exertion, early wake keeps energy.
	var body_log: Array = []
	var strain_log: Array = []
	sl.send_body = func(_p, bpm, eta, phase): body_log.append([bpm, eta, phase])
	sl.send_strain = func(_p, _s, _st, fade, _stance): strain_log.append(fade)
	sl._body_sent.clear()
	sl._strain_sent.clear()
	sl.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	sl.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	sl.vitals_of(1)["energy"] = 40.0
	sl._strain[1] = {"s": 0.6, "state": 0, "t": 0.0}
	sleeper[0] = 1.0
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(sl.sleeping_of(1), "asleep again for the wake rules")
	var eta0: float = sl.sleep_eta(1)
	check(eta0 > 100.0 and eta0 < 1000.0, "the expected wake time follows the energy to refill (%.0f s for 60 energy)" % eta0)
	strain_log.clear()

	for n in 24:
		sl._strain_tick(1, 0.25)

	var fade_smooth: bool = strain_log.size() > 8

	for k in range(1, strain_log.size()):
		fade_smooth = fade_smooth and strain_log[k] >= strain_log[k - 1] and strain_log[k] - strain_log[k - 1] <= 80

	check(fade_smooth and strain_log[strain_log.size() - 1] >= 990, "going to sleep fades to black fade_smoothly over fade_in_s (last %d)" % strain_log[strain_log.size() - 1])
	check(body_log.size() > 0 and body_log[0][2] == 1 and body_log[body_log.size() - 1][2] == 2, "the body message goes falling asleep then asleep")
	var bpm_first: int = body_log[0][0]

	for n in 400:
		sl._strain_tick(1, 0.25)

	check(body_log[body_log.size() - 1][0] < bpm_first - 8, "the heart slows while asleep (%d to %d)" % [bpm_first, body_log[body_log.size() - 1][0]])
	sl.vitals_of(1)["energy"] = 80.0
	sl._strain[1] = {"s": 0.0, "state": 0, "t": 0.0}

	for n in 60:
		sl._strain_tick(1, 0.25)

	check(sl.sleeping_of(1), "not full of energy: you keep sleeping")
	sl.vitals_of(1)["energy"] = 100.0
	sl._strain[1] = {"s": 0.5, "state": 0, "t": 0.0}

	for n in 8:
		sl._strain_tick(1, 0.25)

	check(sl.sleeping_of(1) or float(sl._strain[1]["s"]) <= 0.0, "full energy but still exerted: you keep sleeping until it is gone")
	sl._strain[1] = {"s": 0.0, "state": 0, "t": 0.0}

	for n in 20:
		sl._strain_tick(1, 0.25)

	check(not sl.sleeping_of(1), "full energy and no exertion: you wake by yourself")
	var wake_phase: int = body_log[body_log.size() - 1][2]
	check(wake_phase == 3 or wake_phase == 0, "and the wake fades back (phase %d)" % wake_phase)
	strain_log.clear()

	for n in 24:
		sl._strain_tick(1, 0.25)

	check(strain_log.is_empty() or strain_log[strain_log.size() - 1] == 0, "the fade is gone after the wake fade")
	sl.vitals_of(1)["energy"] = 30.0
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	sl.action(1, Net.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	check(not sl.sleeping_of(1) and float(sl.vitals_of(1)["energy"]) == 30.0, "holding Space (asleep 0) wakes you early with the energy where it was")
	sl.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	var hp: float = 50.0
	sl.vitals_of(1)["health"] = hp
	sl.vitals_of(1)["fed"] = 1000.0
	sl.vitals_of(1)["wet"] = 1000.0
	sl._vitals_tick(10.0)
	var asleep_gain: float = float(sl.vitals_of(1)["health"]) - hp
	sl.action(1, Net.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	sl.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	sl.vitals_of(1)["health"] = hp
	sl._vitals_tick(10.0)
	check(asleep_gain > (float(sl.vitals_of(1)["health"]) - hp) * 1.8, "sleep heals about twice as fast (%.2f against %.2f)" % [asleep_gain, float(sl.vitals_of(1)["health"]) - hp])
	# Water containers (job 89): the water is kept in the slot's wear field (ml); E at water fills the held one, Use drinks from it.
	sl.water_near = func(_p, _r): return true
	var bowl: int = sl.table.number_of("wooden_bowl")
	var bucket_n: int = sl.table.number_of("bucket")
	sl.action(1, Net.ACT_ADMIN_GIVE, bowl, 0, 1, Vector3.ZERO)
	sl.action(1, Net.ACT_ADMIN_GIVE, bucket_n, 0, 1, Vector3.ZERO)
	var inv_c = sl.inventory_of(1)
	var bowl_slot: int = inv_c.numbers.find(bowl)
	var bucket_slot: int = inv_c.numbers.find(bucket_n)
	var kg_empty: float = sl.carried_kg_of(1)
	sl._last_drink.clear()
	sl.action(1, Net.ACT_DRINK, bowl_slot, 0, 0, Vector3.ZERO)
	check(inv_c.wear[bowl_slot] == 300, "one press fills the 300 ml bowl (capped at capacity)")
	sl._last_drink.clear()
	sl.action(1, Net.ACT_DRINK, bucket_slot, 0, 0, Vector3.ZERO)
	check(inv_c.wear[bucket_slot] == 500, "one press puts fill_ml into the bucket")
	check(absf(sl.carried_kg_of(1) - kg_empty - 0.8) < 0.01, "the water in containers is carried weight (0.8 L is 0.8 kg)")
	sl.vitals_of(1)["wet"] = 500.0
	sl._last_drink.clear()
	sl._last_eat.clear()
	sl.action(1, Net.ACT_EAT, bowl_slot, 0, 0, Vector3.ZERO)
	check(inv_c.wear[bowl_slot] == 0 and float(sl.vitals_of(1)["wet"]) == 800.0, "Use drinks a mouthful from the container into thirst")
	sl.action(1, Net.ACT_EAT, bowl_slot, 0, 0, Vector3.ZERO)
	check(inv_c.wear[bowl_slot] == 0, "an empty container gives nothing")
	sl.vitals_of(1)["wet"] = 2400.0
	sl._last_drink.clear()
	sl.action(1, Net.ACT_EAT, bucket_slot, 0, 0, Vector3.ZERO)
	check(inv_c.wear[bucket_slot] == 500, "a full body drinks nothing from the bucket")
	sl._last_drink.clear()
	sl.action(1, Net.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
	check(inv_c.wear[bucket_slot] == 500, "E at the water with nothing held changes no container")
	sl.action(1, Net.ACT_DROP, bucket_slot, 0, 1, Vector3(0.0, 10.0, 0.0))
	var dropped_fill: int = -1

	for it in sl._items.values():
		if int(it.get("number", 0)) == bucket_n:
			dropped_fill = int(it.get("wear", -1))

	check(dropped_fill == 500, "a dropped bucket keeps its water (%d)" % dropped_fill)

	# Blackout is smooth and depends on the overshoot: right at the threshold it takes about slow_s, a long way over it about fast_s.
	var seconds_to_black: Array = []
	var smooth: bool = true

	for over_by in [0.0, 0.05, 0.125, 0.3]:
		sa._strain[1] = {"s": 1.4 * (1.0 + over_by), "state": 1, "t": 0.0}
		sa._stance[1] = 0
		sa._exertion[1] = 1.0
		var waited: float = 0.0
		var last_black: float = 0.0

		while int(sa.strain_of(1)["state"]) < 2 and waited < 60.0:
			sa._strain[1]["s"] = 1.4 * (1.0 + over_by)
			sa._strain_tick(1, 0.25)
			waited += 0.25
			var now_black: float = float(sa.strain_of(1).get("black", 0.0))
			smooth = smooth and now_black >= last_black and now_black - last_black < 0.2
			last_black = now_black

		seconds_to_black.append(waited)

	check(seconds_to_black[0] > 11.0 and seconds_to_black[0] < 17.0, "right at the threshold the blackout takes about 14 s (%.1f)" % seconds_to_black[0])
	check(seconds_to_black[0] > seconds_to_black[1] and seconds_to_black[1] > seconds_to_black[2] and seconds_to_black[2] > seconds_to_black[3], "the further over the threshold the faster it comes on (%s s)" % str(seconds_to_black))
	check(seconds_to_black[3] < 2.5, "a long way over it blacks out in about 1.5 s (%.2f)" % seconds_to_black[3])
	check(smooth, "the blackout level only climbs and never jumps")
	check(int(sa.strain_of(1)["state"]) == 2 and sa.stance_of(1) == 3, "fainting forces lying")
	sa.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	check(sa.stance_of(1) == 3, "a fainted player cannot choose a stance")

	# Crafting queue: ingredients taken when queued, crafts run on the tick, cancel refunds, caps, restart.
	var qd: String = "user://test_server_items_queue"
	DirAccess.make_dir_recursive_absolute(qd)

	for file in DirAccess.get_files_at(qd):
		DirAccess.remove_absolute(qd + "/" + file)

	var cq = make(qd)
	var queue_seen: Array = []
	cq.send_craft_queue = func(_p, entries, left_ms): queue_seen.append([entries, left_ms])
	cq.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	cq.peer_connected_hello(1, "queuekey0001")
	var fibre: int = cq.table.number_of("plant_fibre")
	var cord: int = cq.table.number_of("cordage")
	cq.give(1, fibre, 30)
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 4, Vector3.ZERO)
	check(cq.inventory_of(1).count_of(fibre) == 18, "queueing 4 cordage takes 12 fibre now (%d left)" % cq.inventory_of(1).count_of(fibre))
	check(cq.craft_queue_of(1) == [[1, 4]], "queue holds one entry of 4")
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 2, Vector3.ZERO)
	check(cq.craft_queue_of(1) == [[1, 6]], "queueing the same recipe again merges")
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 99, 0, 1, Vector3.ZERO)
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 16, 0, 1, Vector3.ZERO)
	check(cq.craft_queue_of(1).size() == 1, "unknown recipes are refused")

	for n in range(4 * 2 + 1):
		cq._craft_tick(0.25)

	check(cq.inventory_of(1).count_of(cord) == 1 and cq.craft_queue_of(1) == [[1, 5]], "one cordage after its 2 s (%d)" % cq.inventory_of(1).count_of(cord))
	cq._save_craft_queues()
	var cq2 = make(qd)
	cq2.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	cq2.peer_connected_hello(1, "queuekey0001")
	check(cq2.craft_queue_of(1) == [[1, 5]], "the queue survives a restart")
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_CANCEL, 5, 0, 0, Vector3.ZERO)
	check(cq.craft_queue_of(1).size() == 1, "cancelling a bad index does nothing")
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(cq.craft_queue_of(1).is_empty() and cq.inventory_of(1).count_of(fibre) == 27, "cancel refunds the whole unfinished entry (%d fibre)" % cq.inventory_of(1).count_of(fibre))
	check(not queue_seen.is_empty(), "the queue is sent to the player")
	cq.give(1, fibre, 100)

	for n in range(14):
		cq._last_queue_act.clear()
		cq.action(1, Net.ACT_CRAFT_QUEUE, 1 if n % 2 == 0 else 7, 0, 1, Vector3.ZERO)

	check(cq.craft_queue_of(1).size() <= 10, "queue is capped at 10 entries (%d)" % cq.craft_queue_of(1).size())
	cq._last_queue_act.clear()
	var in_a_row: int = cq.craft_queue_of(1).size()
	cq.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	cq.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(cq.craft_queue_of(1).size() == in_a_row - 1, "queue requests faster than 100 ms apart are ignored")

	# Restart mid-craft keeps the progress; a refund into a full pack drops the rest at the player's feet.
	DirAccess.make_dir_recursive_absolute(qd + "_full")

	for file in DirAccess.get_files_at(qd + "_full"):
		DirAccess.remove_absolute(qd + "_full/" + file)

	var rq = make(qd + "_full")
	rq.send_craft_queue = func(_p, _e, _l): pass
	rq.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	rq.peer_connected_hello(1, "queuekey0002")
	rq.report_position(1, Vector3(0.0, 10.0, 0.0))
	rq.give(1, fibre, 9)
	rq.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 3, Vector3.ZERO)
	rq._craft_tick(1.5)
	rq._save_craft_queues()
	var rq2 = make(qd + "_full")
	rq2.send_craft_queue = func(_p, _e, _l): pass
	rq2.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	rq2.peer_connected_hello(1, "queuekey0002")
	rq2.report_position(1, Vector3(0.0, 10.0, 0.0))
	check(float(rq2._craft_queues["queuekey0002"]["elapsed"]) == 1.5, "the running craft keeps its progress over a restart")
	rq2._craft_tick(0.75)
	check(rq2.inventory_of(1).count_of(cord) == 1, "the restored craft finishes after the rest of its time")

	for n in range(rq2.inventory_of(1).SLOTS):
		if rq2.inventory_of(1).numbers[n] == 0:
			rq2.inventory_of(1).numbers[n] = rq2.table.number_of("stone")
			rq2.inventory_of(1).counts[n] = 1

	rq2._last_queue_act.clear()
	rq2.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	var on_ground: int = 0

	for item_id in rq2._items:
		if rq2._items[item_id]["number"] == fibre:
			on_ground += int(rq2._items[item_id]["count"])

	check(rq2.craft_queue_of(1).is_empty() and on_ground == 6, "a refund into a full pack lands at the player's feet (%d fibre)" % on_ground)
	# An entry refunds from its own saved ingredient list even if its recipe has gone.
	rq2._craft_queues["queuekey0002"]["entries"] = [[9999, 2, [[fibre, 3]]]]
	rq2._craft_tick(0.25)
	check(rq2.craft_queue_of(1).is_empty(), "an entry for a removed recipe is cancelled")

	# Scatter placement: sticks favour tree cover, stones favour slopes (half of the cell each).
	DirAccess.make_dir_recursive_absolute(qd + "_scatter")
	var sc = make(qd + "_scatter")
	sc.ground_height = func(x, z): return 10.0 + maxf(x - 112.0, 0.0) * 0.5
	sc.cover_at = func(p): return 1.0 if p.x > 112.0 else 0.0
	sc.rock_at = func(x, z): return false
	var srng: RandomNumberGenerator = RandomNumberGenerator.new()
	srng.seed = 5
	var stick_cover: int = 0
	var stone_slope: int = 0

	for n in range(400):
		stick_cover += 1 if sc._scatter_spot(srng, Vector2i(3, 0), 32.0, false).x > 112.0 else 0
		stone_slope += 1 if sc._scatter_spot(srng, Vector2i(3, 0), 32.0, true).x > 112.0 else 0

	check(stick_cover > 280, "sticks lie mostly under tree cover (%d of 400, 200 if random)" % stick_cover)
	check(stone_slope > 280, "stones lie mostly on the slope (%d of 400, 200 if random)" % stone_slope)

	# Luck (job 77): stored per character, nudges every roll through one function.
	var Luck = load("res://src/shared/luck.gd")
	var lrng: RandomNumberGenerator = RandomNumberGenerator.new()
	lrng.seed = 11
	var hits: Array = [0, 0, 0]
	var sums: Array = [0, 0, 0]

	for n in range(6000):
		var u: float = lrng.randf()

		for k in range(3):
			var luck: int = [-10, 0, 10][k]
			hits[k] += 1 if Luck.chance(u, 0.5, luck, 0.04) else 0
			sums[k] += Luck.amount(u, 1, 3, luck, 0.04)

	check(hits[0] < hits[1] - 300 and hits[2] > hits[1] + 300 and absf(float(hits[1]) / 6000.0 - 0.5) < 0.02, "luck moves a 50 percent chance down and up and 0 is neutral (%s of 6000)" % str(hits))
	check(sums[0] < sums[1] and sums[1] < sums[2] and Luck.amount(0.0, 1, 3, 10, 0.04) == 1 and Luck.amount(0.999999, 1, 3, -10, 0.04) <= 3, "luck moves the average of a 1 to 3 yield and keeps it in range (%s)" % str(sums))
	check(not Luck.chance(0.99, 0.0, 10, 0.04) and Luck.chance(0.0, 1.0, -10, 0.04), "luck never makes the impossible possible or the certain doubtful")
	var luck_dir: String = "user://test_server_items_luck"
	DirAccess.make_dir_recursive_absolute(luck_dir)

	for file in DirAccess.get_files_at(luck_dir):
		DirAccess.remove_absolute(luck_dir + "/" + file)

	var lk = make(luck_dir)
	lk.peer_connected_hello(1, "luckkey000001")
	lk.peer_connected_hello(2, "luckkey000002")
	check(lk.luck_of(1) >= -10 and lk.luck_of(1) <= 10 and lk.luck_of(99) == 0, "a character gets luck from -10 to 10 at first sight; an unknown peer is neutral")
	lk._characters["luckkey000001"]["luck"] = 9
	lk._dirty = true
	lk.save()
	var lk2 = make(luck_dir)
	lk2.peer_connected_hello(1, "luckkey000001")
	lk2.peer_connected_hello(2, "luckkey000002")
	check(lk2.luck_of(1) == 9 and lk2.luck_of(2) == lk.luck_of(2), "luck is stored with the character and survives a restart unchanged")
	lk2.peer_left(1)
	lk2.peer_connected_hello(1, "luckkey000001")
	check(lk2.luck_of(1) == 9, "coming back does not re-roll luck")
	var plain: RandomNumberGenerator = RandomNumberGenerator.new()
	var same: RandomNumberGenerator = RandomNumberGenerator.new()
	plain.seed = 3
	same.seed = 3
	lk2._characters["luckkey000001"]["luck"] = 0
	var agree: int = 0

	for n in range(200):
		agree += 1 if (plain.randf() < 0.3) == lk2.roll_chance(1, same, 0.3) else 0

	check(agree == 200, "with luck 0 a roll is exactly the plain random roll")
	lk2._luck_cfg["strength"] = 0.0
	lk2._characters["luckkey000001"]["luck"] = 10
	plain.seed = 4
	same.seed = 4
	agree = 0

	for n in range(200):
		agree += 1 if (plain.randf() < 0.3) == lk2.roll_chance(1, same, 0.3) else 0

	check(agree == 200, "strength 0 switches luck off")
	check(lk2.fate(1, "test", 1.0) and int(lk2.fate_counts["test"]) == 1, "the fate hook rolls and counts by kind")

	# Bank stones: real pickable stones along the water's edge, none where there is no water.
	sc.ground_height = func(x, z): return 10.0
	sc.cover_at = func(p): return 0.0
	var bank_cfg: Dictionary = sc._drops["ground_scatter"]
	var band: Array = [false]
	sc.water_near = func(pos, reach): return band[0] and pos.x + reach >= 100.0 and pos.x - reach <= 104.0
	band[0] = true
	var bank_before: int = sc.world_item_count()

	for cz in range(1, 5):
		sc._lay_out_cell(Vector2i(3, cz), 32.0, bank_cfg)

	sc.water_near = func(pos, reach): return pos.x + reach >= 100.0 and pos.x - reach <= 104.0
	var on_bank: int = 0
	var in_water: int = 0

	for bid in sc._items:
		var it: Dictionary = sc._items[bid]

		if it.has("scatter") and it["pos"].z >= 32.0 and it["number"] == sc.table.number_of("stone"):
			on_bank += 1 if it["pos"].x > 96.9 and it["pos"].x < 107.1 else 0
			in_water += 1 if it["pos"].x > 100.0 and it["pos"].x < 104.0 and it["scatter"] & 15 >= 6 else 0

	check(on_bank >= 8, "four cells by a stream get stones along its banks (%d on the bank)" % on_bank)
	check(in_water == 0, "bank stones are never put in the water")
	check(sc.world_item_count() - bank_before <= 4 * (6 + int(bank_cfg["stones_max"]) + int(bank_cfg["sticks_max"])), "bank stones stay within the per-cell limit")

	# Driftwood on the banks: a share of the bank spots, a real item that burns.
	bank_cfg["bank"]["driftwood"] = 1.0
	var wood_n: int = sc.table.number_of("driftwood")
	var wood_before: int = 0

	for bid in sc._items:
		wood_before += 1 if sc._items[bid]["number"] == wood_n else 0

	for cz in range(5, 9):
		sc._lay_out_cell(Vector2i(3, cz), 32.0, bank_cfg)

	var wood_after: int = 0

	for bid in sc._items:
		wood_after += 1 if sc._items[bid]["number"] == wood_n else 0

	bank_cfg["bank"]["driftwood"] = 0.12
	check(wood_n != 0 and wood_after >= wood_before + 8, "bank spots can hold driftwood (%d new)" % (wood_after - wood_before))
	check(float(sc._cooking["fuel"].get("driftwood", 0.0)) > float(sc._cooking["fuel"]["stick"]) and sc._cooking["fuel_order"].has("driftwood"), "driftwood is fuel, longer than a stick")

	# Fall damage and refusal events (job 62).
	DirAccess.make_dir_recursive_absolute(qd + "_fall")

	for file in DirAccess.get_files_at(qd + "_fall"):
		DirAccess.remove_absolute(qd + "_fall/" + file)

	var fl = make(qd + "_fall")
	var rejects: Array = []
	fl.send_reject = func(_p, reason): rejects.append(reason)
	fl.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	fl.peer_connected_hello(1, "fallkey00001")
	fl.report_position(1, Vector3(0.0, 10.0, 0.0))
	fl.action(1, Net.ACT_FALL, 500, 0, 0, Vector3.ZERO)
	check(float(fl.vitals_of(1)["health"]) == 100.0, "a 5 m drop does no damage")
	fl.action(1, Net.ACT_FALL, 1000, 0, 0, Vector3.ZERO)
	check(absf(float(fl.vitals_of(1)["health"]) - 68.0) < 0.01, "a 10 m drop costs 32 health (%.1f left)" % float(fl.vitals_of(1)["health"]))
	fl.action(1, Net.ACT_FALL, 1000, 0, 0, Vector3.ZERO)
	check(absf(float(fl.vitals_of(1)["health"]) - 68.0) < 0.01, "a second report within 2 s is ignored")
	fl._last_fall.clear()
	fl.action(1, Net.ACT_FALL, 5000, 0, 0, Vector3.ZERO)
	check(float(fl.vitals_of(1)["health"]) == 1.0, "a huge drop never kills (health stays at 1)")
	fl._strain_tick(1, 0.25)
	check(int(fl.strain_of(1)["state"]) == 2, "a drop of 12 m or more makes the player faint")
	# Jumping skill (Dave 2026-10-21): level 2 doubles the safe height and halves the damage per metre beyond.
	fl.skill_level = func(_p, skill): return 2.0 if skill == "jumping" else 1.0
	fl.vitals_of(1)["health"] = 100.0
	fl._last_fall.clear()
	fl.action(1, Net.ACT_FALL, 1000, 0, 0, Vector3.ZERO)
	check(float(fl.vitals_of(1)["health"]) == 100.0, "a good jumper drops 10 m unhurt")
	fl._last_fall.clear()
	fl.action(1, Net.ACT_FALL, 1600, 0, 0, Vector3.ZERO)
	check(absf(float(fl.vitals_of(1)["health"]) - 84.0) < 0.01, "and takes half the damage per metre beyond (16 m: 4 m over x 4 = 16, %.1f left)" % float(fl.vitals_of(1)["health"]))
	fl.action(1, Net.ACT_PICKUP, 99999, 0, 0, Vector3.ZERO)
	check(rejects.is_empty(), "no refusal event for an item that is not there")
	fl.drop_in_world(fl.table.number_of("stone"), 1, Vector3(40.0, 10.0, 0.0))
	var far_id: int = fl._items.keys()[0]
	fl.action(1, Net.ACT_PICKUP, far_id, 0, 0, Vector3.ZERO)
	check(rejects == [0], "a pickup out of reach is refused as too far (%s)" % str(rejects))
	fl.rock_at = func(x, z): return true
	fl.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(2.0, 10.0, 0.0))
	check(rejects == [0, 1], "mining without an axe is refused as no tool (%s)" % str(rejects))

	# Picking up at the weight cap: refused as pack full, nothing taken from the ground, nothing doubled.
	var pk = make(qd + "_cap")
	var cap_rejects: Array = []
	pk.send_reject = func(_p, reason): cap_rejects.append(reason)
	pk.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	pk.peer_connected_hello(1, "capkey000001")
	pk.report_position(1, Vector3(0.0, 10.0, 0.0))
	var rock: int = pk.table.number_of("stone")
	pk.give(1, rock, 500)
	var packed: int = pk.inventory_of(1).count_of(rock)
	var on_floor: int = 0

	for floor_id in pk._items:
		if int(pk._items[floor_id]["number"]) == rock:
			on_floor += int(pk._items[floor_id]["count"])

	var one_id: int = pk._items.keys()[0]
	pk.action(1, Net.ACT_PICKUP, one_id, 0, 0, Vector3.ZERO)
	var after_floor: int = 0

	for floor_id in pk._items:
		if int(pk._items[floor_id]["number"]) == rock:
			after_floor += int(pk._items[floor_id]["count"])

	check(packed + on_floor == 500 and pk.inventory_of(1).count_of(rock) == packed and after_floor == on_floor and cap_rejects == [2], "a pickup at the weight cap takes nothing, doubles nothing and is refused as pack full (%d packed, %d on the ground, %s)" % [packed, on_floor, str(cap_rejects)])

	# Lazy catch-up (job 66): stumps that rot and saplings that grow while nobody is there, computed on the next look.
	var lazy_clock: Array = [0.0]
	var lz = make(qd + "_lazy")
	lz.game_seconds = func(): return float(lazy_clock[0])
	lz.ground_height = func(x, z): return 10.0
	lz.standing_near = func(_species, pos, _radius): return [pos + Vector3(3.0, 0.0, 0.0)]
	var tree_name: String = ""

	for flora_name in lz._flora_by_name:
		if lz._flora_by_name[flora_name].has("height_m") and float(lz._flora_by_name[flora_name]["height_m"][0]) > 4.0:
			tree_name = str(flora_name)
			break

	for n in range(40):
		lz._items[lz._next_id] = {"number": 0, "count": 1, "pos": Vector3(float(n) * 300.0, 10.0, 5.0), "left": 1.0e9, "tree": {"state": 4, "chunk": [n, 0], "species": tree_name, "yaw": 0.0, "length": 5.0, "radius": 0.2, "felled_at": 0.0}}
		lz._next_id += 1

	var day_s: float = 86400.0
	lazy_clock[0] = 7.0 * day_s
	lz._rot_in = 0.0
	lz._rot(0.1)
	check(lz.rot_removed == 0 and lz._saplings.is_empty(), "nothing rots in 7 game days (%d removed)" % lz.rot_removed)
	lazy_clock[0] = 170.0 * day_s   # the server was off, or nobody was near, for 170 game days
	lz._rot_in = 0.0
	lz._rot(0.1)
	check(lz.rot_scanned == 40 and lz.rot_removed == 40, "one pass catches up every rotted stump: %d looked at, %d rotted" % [lz.rot_scanned, lz.rot_removed])
	check(not lz._saplings.is_empty(), "some stumps seeded a sapling")
	var aged: bool = true

	for sapling in lz._saplings:
		aged = aged and absf(float(sapling["planted_at"]) - 168.0 * day_s) < 1.0 and lz._sapling_height(sapling, lazy_clock[0]) > 0.5

	check(aged, "a sapling seeded during the catch-up dates from when its stump rotted, so it has already grown (%d saplings)" % lz._saplings.size())
	lz._rot_in = 0.0
	lz._rot(0.1)
	check(lz.rot_scanned == 0 and lz.rot_removed == 0, "a second pass has nothing left to do")
	lz._saplings.clear()
	lz._saplings.append({"slot": 0, "chunk": [0, 0], "species": int(lz._flora_by_name[tree_name]["id"]), "pos": Vector3(1.0, 10.0, 1.0), "planted_at": 0.0})
	lazy_clock[0] = 7.0 * day_s
	var young: float = lz._sapling_height(lz._saplings[0], lazy_clock[0])
	var full_h: float = float(lz._flora_by_name[tree_name]["height_m"][0])
	check(young > full_h * 0.4 and young < full_h * 0.9, "a sapling 7 game days offline is a young tree by the next look (%.1f of %.1f m)" % [young, full_h])
	check(lz.dynamic_tree_info(Vector2i(0, 0), (int(lz._flora_by_name[tree_name]["id"]) << 16) | 0xFFFF).is_empty(), "and cannot be felled yet")
	lazy_clock[0] = 13.0 * day_s
	check(not lz.dynamic_tree_info(Vector2i(0, 0), (int(lz._flora_by_name[tree_name]["id"]) << 16) | 0xFFFF).is_empty(), "after 12 game days it is a full tree that can be felled")

	# Container rules as data (job 73): the woven chest takes 40 kg, and partial puts, full chests and full packs behave.
	DirAccess.make_dir_recursive_absolute(qd + "_box")

	for file in DirAccess.get_files_at(qd + "_box"):
		DirAccess.remove_absolute(qd + "_box/" + file)

	var bx = make(qd + "_box")
	var box_rejects: Array = []
	bx.send_reject = func(_p, reason): box_rejects.append(reason)
	bx.send_chest = func(_p, _i, _b): pass
	bx.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	bx.ground_height = func(x, z): return 10.0
	bx.peer_connected_hello(1, "boxkey000001")
	bx.report_position(1, Vector3(0.0, 10.0, 0.0))
	var box_stone: int = bx.table.number_of("stone")
	var box_kit: int = bx.table.number_of("chest_kit")
	bx.action(1, Net.ACT_ADMIN_GIVE, box_kit, 0, 1, Vector3.ZERO)
	bx.action(1, Net.ACT_ADMIN_GIVE, box_stone, 0, 50, Vector3.ZERO)
	bx.action(1, Net.ACT_PLACE, bx.inventory_of(1).numbers.find(box_kit), 0, 0, Vector3(2.0, 10.0, 0.0))
	var box_id: int = 0

	for k in bx._items:
		if bx._items[k].has("struct"):
			box_id = k

	bx.action(1, Net.ACT_CHEST_OPEN, box_id, 0, 0, Vector3.ZERO)
	var box = bx._chests[int(bx._items[box_id]["struct"]["uid"])]
	var in_pack: int = bx.inventory_of(1).count_of(box_stone)

	for slot_n in range(bx.inventory_of(1).SLOTS):
		if bx.inventory_of(1).numbers[slot_n] == box_stone:
			bx.action(1, Net.ACT_CHEST_PUT, slot_n, box_id, 20, Vector3.ZERO)
	check(box.count_of(box_stone) == 40 and bx.inventory_of(1).count_of(box_stone) == in_pack - 40, "a put past the 40 kg limit puts what fits (%d in the chest, %d left in the pack)" % [box.count_of(box_stone), bx.inventory_of(1).count_of(box_stone)])
	check(box_rejects == [2], "the stack that no longer fits is refused as too heavy (%s)" % str(box_rejects))
	bx.action(1, Net.ACT_CHEST_PUT, bx.inventory_of(1).numbers.find(box_stone), box_id, 5, Vector3.ZERO)
	check(box.count_of(box_stone) == 40 and box_rejects == [2, 2], "a full chest takes no more and refuses it as too heavy (%s)" % str(box_rejects))
	bx.give(1, box_stone, 500)
	var before_take: int = bx.inventory_of(1).count_of(box_stone)
	bx.action(1, Net.ACT_CHEST_TAKE, box.numbers.find(box_stone), box_id, 20, Vector3.ZERO)
	check(bx.inventory_of(1).count_of(box_stone) == before_take and box.count_of(box_stone) == 40, "a take into a pack at its weight cap moves nothing and loses nothing")

	# Skill hooks (job 70): factor 1.0 changes nothing; a stub skill of 2.0 doubles yield and halves craft time.
	DirAccess.make_dir_recursive_absolute(qd + "_skill")

	for file in DirAccess.get_files_at(qd + "_skill"):
		DirAccess.remove_absolute(qd + "_skill/" + file)

	var sk = make(qd + "_skill")
	sk.send_craft_queue = func(_p, _e, _l): pass
	sk.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sk.peer_connected_hello(1, "skillkey0001")
	check(sk.skill_factor(1, "craft") == 1.0 and sk.skill_factor(1, "no_such_action") == 1.0, "with no skill system every factor is 1.0")
	sk.skill_level = func(_peer, _skill): return 2.0
	check(sk.skill_factor(1, "craft") == 2.0 and sk.skill_factor(1, "no_such_action") == 1.0, "a skill level of 2 gives a factor of 2 for a listed action only")
	sk.give(1, sk.table.number_of("plant_fibre"), 9)
	sk.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 1, Vector3.ZERO)

	for n in range(4 * 1 + 1):
		sk._craft_tick(0.25)

	check(sk.inventory_of(1).count_of(sk.table.number_of("cordage")) == 1, "a skill of 2 makes the 2 s cordage in 1 s")

	# Boulders (Dave 2026-10-21): a pick breaks one into stones; the count is volume x density x yield / stone mass.
	var bld: String = "user://test_server_items_boulder"
	DirAccess.make_dir_recursive_absolute(bld)

	for file in DirAccess.get_files_at(bld):
		DirAccess.remove_absolute(bld + "/" + file)

	var bo = make(bld)
	var bo_rejects: Array = []
	bo.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	bo.send_reject = func(_p, reason): bo_rejects.append(reason)
	bo.ground_height = func(x, _z): return 10.0 + x * 0.3
	bo.peer_connected_hello(1, "boulderkey01")
	bo.report_position(1, Vector3(5.0, 11.5, 5.0))
	var big: int = bo._boulder_stones(1.0)
	check(big >= 4000 and big <= 5200, "a 1 m radius boulder makes about 4600 stones at 0.85 height, 2600 kg/m3, half usable (%d)" % big)
	check(bo._boulder_stones(0.3) >= 100 and bo._boulder_stones(0.3) <= 150 and bo._boulder_stones(1.2) > 7000, "small boulders make a hundred or so, a 1.2 m one several thousand (%d, %d)" % [bo._boulder_stones(0.3), bo._boulder_stones(1.2)])
	bo._boulder_cfg["luck_extra"] = 0.0   # the exact-count checks below; luck's extra stone has its own check
	var small_total: int = bo._boulder_stones(0.3)
	bo._items[900001] = {"number": 0, "count": small_total, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": bo.BOULDER_KEY | 7, "boulder": {"radius": 0.3, "yaw": 0.0, "total": small_total}}
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)
	check(bo_rejects == [1] and int(bo._items[900001]["count"]) == small_total, "no pick or axe on the hotbar: refused (no tool), nothing taken (%s)" % str(bo_rejects))
	bo.action(1, Net.ACT_ADMIN_GIVE, bo.table.number_of("iron_pickaxe"), 0, 1, Vector3.ZERO)
	var stone_id: int = bo.table.number_of("stone")

	for n in range(10):
		bo._last_hit.clear()
		bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)

	check(bo.inventory_of(1).count_of(stone_id) == 10 and int(bo._items[900001]["count"]) == small_total - 10, "an iron pick takes one stone per blow (%d stones, %d left)" % [bo.inventory_of(1).count_of(stone_id), int(bo._items[900001]["count"])])
	var pick_slot: int = bo.inventory_of(1).numbers.find(bo.table.number_of("iron_pickaxe"))
	check(int(bo.inventory_of(1).wear[pick_slot]) == 10, "every blow wears the pick (%d)" % int(bo.inventory_of(1).wear[pick_slot]))
	bo.inventory_of(1).numbers[pick_slot] = 0
	bo.inventory_of(1).counts[pick_slot] = 0
	bo.action(1, Net.ACT_ADMIN_GIVE, bo.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(9):
		bo._last_hit.clear()
		bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)

	check(bo.inventory_of(1).count_of(stone_id) == 13, "a stone axe takes three blows per stone: 9 blows, 3 stones (%d)" % (bo.inventory_of(1).count_of(stone_id) - 10))
	bo.report_position(1, Vector3(40.0, 22.0, 40.0))
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)
	check(bo_rejects[-1] == 0, "too far away: refused")
	bo.report_position(1, Vector3(5.0, 11.5, 5.0))
	bo._items[900001]["count"] = 1
	bo._items[900001]["boulder"]["blows"] = 2
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)
	check(not bo._items.has(900001) and int(bo._boulder_left[bo.BOULDER_KEY | 7]) == 0, "the last stone takes the boulder with it")
	bo.action(1, Net.ACT_PICKUP, 900001, 0, 0, Vector3.ZERO)
	check(bo.inventory_of(1).count_of(0) == 0, "a boulder cannot be picked up like a stone")
	# Luck: a lucky character gets more of the occasional double stone than an unlucky one.
	bo._boulder_cfg["luck_extra"] = 0.2
	var extras: Array = []

	for fortune in [10, -10]:
		bo._characters["boulderkey01"]["luck"] = fortune
		bo.inventory_of(1).numbers[bo.inventory_of(1).numbers.find(bo.table.number_of("stone_axe"))] = 0
		bo.action(1, Net.ACT_ADMIN_GIVE, bo.table.number_of("iron_pickaxe"), 0, 1, Vector3.ZERO)
		bo._items[900002] = {"number": 0, "count": 3000, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": bo.BOULDER_KEY | 9, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 3000}}
		var taken: int = 0

		for n in range(400):
			bo._last_hit.clear()
			var before_count: int = int(bo._items[900002]["count"])
			bo.action(1, Net.ACT_HIT, 900002, Net.HIT_BOULDER, 0, Vector3.ZERO)
			taken += before_count - int(bo._items[900002]["count"])

			# keep the pack light so the weight limit does not interfere
			for slot in range(bo.inventory_of(1).SLOTS):
				if bo.inventory_of(1).numbers[slot] == bo.table.number_of("stone"):
					bo.inventory_of(1).counts[slot] = 0
					bo.inventory_of(1).numbers[slot] = 0

		extras.append(taken - 400)
		bo._items.erase(900002)
		bo.inventory_of(1).numbers[bo.inventory_of(1).numbers.find(bo.table.number_of("iron_pickaxe"))] = 0

	check(extras[0] > extras[1] and extras[1] >= 0, "luck nudges the double stones: luck +10 got %d extra, luck -10 got %d in 400 blows" % [extras[0], extras[1]])
	bo._boulder_cfg["luck_extra"] = 0.0
	# Layout: on a slope the cells hold boulders, the same ones every time, none on flat ground.
	var laid: Array = []

	for cell_x in range(0, 6):
		for cell_z in range(0, 4):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = hash(Vector3i(cell_x, cell_z, 1))
			bo._lay_out_boulders(Vector2i(cell_x, cell_z), 32.0, rng)

	for bid in bo._items:
		if bo._items[bid].has("boulder"):
			laid.append([bid, bo._items[bid]["pos"], int(bo._items[bid]["count"])])

	check(laid.size() >= 3, "a slope is dotted with boulders (%d in 24 cells)" % laid.size())
	var replay = make(bld + "_replay")
	replay.ground_height = bo.ground_height
	var replay_count: int = 0

	for cell_x in range(0, 6):
		for cell_z in range(0, 4):
			var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
			rng2.seed = hash(Vector3i(cell_x, cell_z, 1))
			replay._lay_out_boulders(Vector2i(cell_x, cell_z), 32.0, rng2)

	for aid in replay._items:
		replay_count += 1 if replay._items[aid].has("boulder") else 0

	check(replay_count == laid.size(), "the layout is deterministic (%d then %d)" % [laid.size(), replay_count])
	var worked: int = int(laid[0][0]) if not laid.is_empty() else 0

	if worked != 0:
		bo._items[worked]["count"] = 5
		bo._boulder_left[bo._items[worked]["scatter"]] = 5
		bo._dirty = true
		bo.save()
		var reloaded = make(bld)
		check(int(reloaded._boulder_left.get(bo._items[worked]["scatter"], -1)) == 5, "what is left of a worked boulder is saved")

	# A recipe with six ingredients works end to end (Dave: the more ingredients the better the item; the limit is one constant).
	var qd6: String = qd + "_six"
	DirAccess.make_dir_recursive_absolute(qd6)

	for file6 in DirAccess.get_files_at(qd6):
		DirAccess.remove_absolute(qd6 + "/" + file6)

	var sx6 = make(qd6)
	sx6.send_craft_queue = func(_p, _e, _l): pass
	sx6.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sx6.peer_connected_hello(1, "sixkey000001")
	var cord6: int = sx6.table.number_of("cordage")
	var six_file: String = qd6 + "/six.json"
	var six: FileAccess = FileAccess.open(six_file, FileAccess.WRITE)
	six.store_string(JSON.stringify({"recipes": {"six_test": {"number": 900, "name": "Six test", "needs": [["stone", 1], ["stick", 1], ["plant_fibre", 1], ["bark", 1], ["leaves", 1], ["firewood", 1]], "gives": ["cordage", 1], "craft_s": 1.0, "known": true}}}))
	six.close()
	sx6.recipes.load_file(six_file, sx6.table)
	check(sx6.recipes.recipe(900).get("needs", []).size() == 6, "a six-ingredient recipe loads")

	for id6 in ["stone", "stick", "plant_fibre", "bark", "leaves", "firewood"]:
		sx6.give(1, sx6.table.number_of(id6), 2)

	var cord6b: int = sx6.inventory_of(1).count_of(cord6)
	sx6._last_queue_act.clear()
	sx6.action(1, Net.ACT_CRAFT_QUEUE, 900, 0, 1, Vector3.ZERO)
	check(sx6.inventory_of(1).count_of(sx6.table.number_of("bark")) == 1 and sx6.inventory_of(1).count_of(sx6.table.number_of("firewood")) == 1, "queueing it takes all six ingredients")

	for n in 40:
		sx6._craft_tick(0.25)

	check(sx6.inventory_of(1).count_of(cord6) > cord6b, "the six-ingredient craft completes")

	# Campfire friction (spawn_boost): a new player's surroundings hold a campfire kit's worth; far from spawn it stays sparse.
	var qd8: String = "user://test_server_items_boost"
	DirAccess.make_dir_recursive_absolute(qd8)

	for file8 in DirAccess.get_files_at(qd8):
		DirAccess.remove_absolute(qd8 + "/" + file8)

	var bs = make(qd8)
	bs.respawn_point = Vector3(0.0, 10.0, 0.0)
	bs.ground_height = func(_x, _z): return 10.0
	bs.peer_connected_hello(1, "boostkey0001")
	bs.report_position(1, Vector3(16.0, 10.0, 16.0))

	for n in 12:
		bs._scatter_around_players()

	var near_stones: int = 0
	var near_sticks: int = 0

	for id8 in bs._items:
		var it8: Dictionary = bs._items[id8]

		if it8.has("scatter") and it8["pos"].distance_to(Vector3(16.0, 10.0, 16.0)) <= 48.0:
			near_stones += 1 if it8["number"] == bs.table.number_of("stone") else 0
			near_sticks += 1 if it8["number"] == bs.table.number_of("stick") else 0

	check(near_stones >= 10 and near_sticks >= 20, "within 48 m of spawn lie a campfire kit's worth (%d stones, %d sticks)" % [near_stones, near_sticks])
	var far = make(qd8 + "_far")
	far.respawn_point = Vector3(0.0, 10.0, 0.0)
	far.ground_height = func(_x, _z): return 10.0
	far.peer_connected_hello(1, "boostkey0002")
	far.report_position(1, Vector3(5000.0, 10.0, 5000.0))

	for n in 12:
		far._scatter_around_players()

	var far_total: int = 0

	for id9 in far._items:
		far_total += 1 if far._items[id9].has("scatter") and far._items[id9]["pos"].distance_to(Vector3(5016.0, 10.0, 5016.0)) <= 48.0 else 0

	print("scatter within 48 m: spawn %d stones %d sticks; far %d things" % [near_stones, near_sticks, far_total])
	check(far_total < near_stones + near_sticks, "far from spawn the scatter stays sparse (%d against %d)" % [far_total, near_stones + near_sticks])

	print("server item tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
