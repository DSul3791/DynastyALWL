extends SceneTree

# Server item rules without a network: validation, caps, despawn, save and reload.
#   godot --headless --path . --script res://src/worldgen/tools/test_server_items.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const FloraLayoutScript := preload("res://src/worldgen/runtime/flora_layout.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const GatherRulesScript := preload("res://src/shared/gather_rules.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")   # the hand slot a craft holds its tool in (protocol 126)
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

	items.action(7, Net.ACT_ADMIN_GIVE, stone, 0, 40, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 40, "admin give")
	check(not slots_sent.is_empty(), "slot change sent")

	items.action(7, Net.ACT_DROP, 99, 0, 5, Vector3.ZERO)
	items.action(7, Net.ACT_DROP, 0, 0, -3, Vector3.ZERO)
	items.action(7, Net.ACT_MOVE, -1, 400, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 40 and items.world_item_count() == 0, "bad slots and counts change nothing")

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
	feed.action(9, Net.ACT_MOVE, feed.inventory_of(9).numbers.find(feed.table.number_of("stick")), 20, 0, Vector3.ZERO)
	check(gains.is_empty(), "moving a stack reports no gain (%s)" % str(gains))

	# Money and reputation: coins pay into the purse as copper, richest coin first in the feed; reputation ranks and discounts.
	var purse_seen: Array = []
	feed.send_purse = func(_p, c): purse_seen.append(c)
	gains.clear()
	feed.give_to(9, "coin_silver", 2)
	feed.give_to(9, "coin_copper", 7)
	check(feed.coins_of(9) == 207 and purse_seen.back() == PackedInt32Array([0, 2, 0, 7]), "coins go into the purse as they came, sent as counts gold..copper (%s)" % str(purse_seen.back()))
	check(gains.size() == 2 and gains[0][1] == "coin_silver" and gains[0][2] == 2 and gains[1][1] == "coin_copper", "coins show in the feed as coins (%s)" % str(gains))
	check(feed.purse_breakdown(1234) == [["coin_gold", 1], ["coin_silver", 2], ["coin_bronze", 3], ["coin_copper", 4]], "the purse shows gold, silver, bronze and copper")
	check(feed.take_coins(9, 100) and feed.coins_of(9) == 107 and not feed.take_coins(9, 1000) and feed.coins_of(9) == 107, "paying takes coins, too little pays nothing")
	check(feed.purse_of(9) == {"coin_silver": 1, "coin_copper": 7}, "the 7 copper went first, a silver was broken and its 7 copper change came back (%s)" % str(feed.purse_of(9)))
	# Dave 14 Nov 2026: coins keep their denomination until a trader changes them.
	feed.add_coins(9, 200, "goal")
	check(feed.purse_of(9) == {"coin_silver": 1, "coin_copper": 207}, "200 copper earned stays 200 copper coins (%s)" % str(feed.purse_of(9)))
	feed.redenominate(9)
	check(feed.purse_of(9) == {"coin_silver": 3, "coin_copper": 7} and feed.coins_of(9) == 307, "at a trader the purse becomes the fewest coins (%s)" % str(feed.purse_of(9)))
	check(feed.take_coins(9, 200) and feed.purse_of(9) == {"coin_silver": 1, "coin_copper": 7}, "200 paid: the 7 copper and two silver go, and the 7 copper change comes back (%s)" % str(feed.purse_of(9)))
	check(feed.take_coins(9, 0) and feed.purse_of(9) == {"coin_silver": 1, "coin_copper": 7}, "paying nothing changes nothing")
	feed.add_coins(9, 5, "goal")
	check(feed.take_coins(9, 12) and feed.coins_of(9) == 100 and feed.purse_of(9) == {"coin_silver": 1}, "12 copper paid from 12 copper coins (%s)" % str(feed.purse_of(9)))
	feed.give_to(9, "coin_copper", 7)
	feed.give_to(9, "coin_bronze", 0)
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
	check(feed2.purse_of(9) == {"coin_silver": 1, "coin_copper": 7} and feed2.rep_points(9, "hob") == 30, "the purse (as held) and reputation are saved with the character (%s)" % str(feed2.purse_of(9)))
	feed2._characters["feedfeed1234"]["purse"] = {"coin_gold": int(float(feed2._coins_cfg.get("max_copper", 100000000)) / 1000.0) - 1}
	feed2.add_coins(9, 5000, "goal")
	check(feed2.coins_of(9) == int(feed2._coins_cfg.get("max_copper", 100000000)), "the purse's worth stops at max_copper (%d)" % feed2.coins_of(9))

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
	check(items.inventory_of(7).count_of(stone) == ItemsScript.PILE_HANDFUL and items.world_item_count() == 1, "a pile of 40 gives one handful")
	items.action(7, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	items.action(7, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 40 and items.world_item_count() == 0, "pick up")
	items.action(7, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 40, "second pick up of the same item does nothing")
	items.inventory_of(7).remove(stone, 25)   # back to 15 (the rest of the test and the restart checks count 15): a 25 handful on top of 40 would pass the carry limit

	items.report_position(7, Vector3(100.0, 5.0, 100.0))
	items.drop_in_world(stone, 3, Vector3(5000.0, 0.0, 5000.0))
	items.action(7, Net.ACT_PICKUP, 2, 0, 0, Vector3.ZERO)
	check(items.world_item_count() == 1, "cannot pick up from far away")

	var axe_number: int = items.table.number_of("stone_axe")   # a tool: never merges, each lies as its own item
	var all_laid: bool = true

	for n in range(100):   # no limit on what lies on the ground (Dave 16 Nov 2026: "there should be no limit")
		all_laid = items.drop_in_world(axe_number, 1, Vector3(10.0, 0.0, 10.0), 1) and all_laid
	check(all_laid and items.world_item_count() == 100 + 1, "100 tools dropped on one spot all lie there (%d items)" % items.world_item_count())

	items.drop_in_world(stone, 1, Vector3(4000.0, 0.0, 4000.0))
	check(items.clear_dropped(Vector3(10.0, 0.0, 10.0), 50.0) == 100 and items.world_item_count() == 2, "clear dropped items removes the nearby loose ones only")
	check(items.drop_in_world(stone, 1, Vector3(10.0, 0.0, 10.0)), "and drops work afterwards")
	items.clear_dropped(Vector3(10.0, 0.0, 10.0), 50.0)
	items.clear_dropped(Vector3(4000.0, 0.0, 4000.0), 50.0)

	items.drop_in_world(stone, 1, Vector3(10.0, 0.0, 10.0))
	items.admin_ok = func(p: int) -> bool: return p == 7
	check(not items.free_craft_for(7) and not items.free_craft_for(9), "admin mode is off by default, even for an admin (Dave 11 Nov 2026)")
	items.action(9, Net.ACT_ADMIN_MODE, 1, 0, 0, Vector3.ZERO)
	items.action(7, Net.ACT_ADMIN_MODE, 1, 0, 0, Vector3.ZERO)
	check(items.free_craft_for(7) and not items.free_craft_for(9), "an admin can switch it on, a non-admin cannot")
	items.action(7, Net.ACT_ADMIN_MODE, 0, 0, 0, Vector3.ZERO)
	check(not items.free_craft_for(7), "and off again")
	items.admin_ok = Callable()

	# Loose things let go in the air come down to the ground (Dave 2026-10-23, mined soil floating over the hole).
	items.clear_dropped(Vector3.ZERO, 1.0e7)
	var ground_y: Array = [10.0]
	items.floor_below = func(_p: Vector3) -> float: return ground_y[0]
	items.drop_in_world(stone, 2, Vector3(3000.0, 11.0, 3000.0))
	check(is_equal_approx(items._items[items._items.keys()[0]]["pos"].y, 10.0), "a drop in the air comes down to the ground")
	ground_y[0] = 7.0
	items.settle_loose_near(Vector3(3000.0, 9.0, 3000.0), 1.0)
	check(is_equal_approx(items._items[items._items.keys()[0]]["pos"].y, 7.0), "a dig under it lets it fall into the hole")
	ground_y[0] = 12.0
	items.settle_loose_near(Vector3(3000.0, 9.0, 3000.0), 1.0)
	check(is_equal_approx(items._items[items._items.keys()[0]]["pos"].y, 7.0), "and ground that rises never lifts it")
	items.floor_below = Callable()
	items.clear_dropped(Vector3.ZERO, 1.0e7)

	# A drop whose sent height is under the ground lands on the server's ground (main gate 21 Nov 2026: the client sends its own ground, or the
	# feet less 1 m when it has none yet, and a stack dropped under the surface stayed buried). The fake floor answers the ground only from above.
	var drop_floor_y: Array = [20.0]
	items.floor_below = func(p: Vector3) -> float: return drop_floor_y[0] if p.y >= drop_floor_y[0] else NAN
	items.report_position(7, Vector3(4000.0, 20.0, 4000.0))
	items.give(7, stone, 3)
	var buried_stack: int = items.inventory_of(7).numbers.find(stone)
	items.action(7, Net.ACT_DROP, buried_stack, 0, 3, Vector3(4001.0, 19.0, 4000.0))
	var buried_landed: Array = items._items.values().filter(func(it: Dictionary) -> bool: return Vector2(it["pos"].x, it["pos"].z).distance_to(Vector2(4001.0, 4000.0)) < 0.5)
	check(buried_landed.size() == 1 and is_equal_approx(buried_landed[0]["pos"].y, 20.0), "a drop sent 1 m under the ground lands on the server's ground (%s)" % str(buried_landed))
	items.floor_below = Callable()
	items.clear_dropped(Vector3.ZERO, 1.0e7)

	# MikeW's rig (2026-10-23): drop a pile of stones 2.2 m ahead; the world must hold ONE item with all of them, and the player is told.
	items.clear_dropped(Vector3.ZERO, 1.0e7)
	items.report_position(7, Vector3(100.0, 5.0, 100.0))
	var rig_before: int = items.inventory_of(7).count_of(stone)
	items.action(7, Net.ACT_ADMIN_GIVE, stone, 0, 20, Vector3.ZERO)
	var rig_slot: int = items.inventory_of(7).numbers.find(stone)
	var rig_held: int = items.inventory_of(7).counts[rig_slot]
	world_sent.clear()
	items.action(7, Net.ACT_DROP, rig_slot, 0, 20, Vector3(102.2, 5.0, 100.0))
	items.tick(1.5)
	var rig_count: int = 0

	for k in items._items:
		rig_count += int(items._items[k]["count"])

	check(items.world_item_count() == 1 and rig_count == 20 and rig_held >= 6, "a dropped pile of stones lies as one item (%d items, %d of %d stones)" % [items.world_item_count(), rig_count, rig_held])
	check(not world_sent.is_empty() and world_sent[0][1].size() == 1 and int(world_sent[0][1][0][2]) == rig_count, "and the player is told about it with its count")
	items.inventory_of(7).remove(stone, items.inventory_of(7).count_of(stone) - rig_before)
	items.clear_dropped(Vector3.ZERO, 1.0e7)

	# Rock piles: stackable drops within a metre merge, a pile gives a handful and lives longer.
	items.clear_dropped(Vector3.ZERO, 1.0e7)
	var pile_at: Vector3 = Vector3(2000.0, 0.0, 2000.0)
	items.report_position(7, pile_at)

	for n in range(100):
		items.drop_in_world(stone, 1, pile_at + Vector3(0.1 * float(n % 5), 0.0, 0.0))
	check(items.world_item_count() == 1, "100 stones dropped together are one ground item")
	check(items.drop_in_world(stone, 5, pile_at), "and the pile takes more")
	items.drop_in_world(stone, 3, pile_at + Vector3(5.0, 0.0, 0.0))
	check(items.world_item_count() == 2, "a drop 5 m away is a separate item")
	items.tick(ItemsScript.WORLD_ITEM_LIFETIME_S + 1.0)
	check(items.world_item_count() == 1, "a pile outlives the loose 20 minutes")
	items.tick(ItemsScript.PILE_LIFETIME_S + 1.0)
	check(items.world_item_count() == 0, "and goes after its 2 hours")
	# Cone piles (Dave 19 Nov 2026, boulders PLAN.md 5b): a big pile takes in what lands beside it, however wide it grew, but stops at a building.
	items.drop_in_world(stone, 20000, pile_at)
	var cone_r: float = items._cone_radius_of(stone, 20000)
	check(cone_r > 1.5 and cone_r < 2.0, "20,000 stones of 0.5 kg make a solid cone about 1.75 m in radius (%f)" % cone_r)
	items._sync_world_items()   # the grid files the pile in its 100 m cell (x 2000 up); its foot at x 1998 lies in the next cell down
	items.drop_in_world(stone, 10, pile_at - Vector3(cone_r + 0.5, 0.0, 0.0))
	check(items.world_item_count() == 1 and int(items._items[items._items.keys()[0]]["count"]) == 20010, "a drop at the foot of a big pile joins it, across a grid cell's edge (the wide-pile list)")
	var pile_stop_id: int = items._next_id   # a real id: the server finds what may stop a pile through its sync grid, which files ids below _next_id
	items._next_id += 1
	items._items[pile_stop_id] = {"number": items.table.number_of("storage_chest") if items.table.number_of("storage_chest") > 0 else 1, "count": 1, "pos": pile_at + Vector3(-(cone_r + 0.3), 0.0, 0.0), "left": 1.0e9, "struct": {"kind": "chest", "yaw": 0.0}}
	if items._structures.has("chest"):
		items.drop_in_world(stone, 200000, pile_at + Vector3(0.5, 0.0, 0.0))
		var beside: Array = items._items.keys().filter(func(k): return int(items._items[k]["count"]) == 200000)
		check(items.world_item_count() == 3 and int(items._items[items._items.keys()[0]]["count"]) == 20010 and beside.size() == 1 and items._items[beside[0]]["pos"].x > pile_at.x + cone_r, "a pile that would grow into a building stops; the rest starts a new pile beside it, away from the building")
		items.drop_in_world(stone, 10, pile_at + Vector3(0.5, 0.0, 0.0))
		check(items.world_item_count() == 3 and int(items._items[beside[0]]["count"]) == 200010, "and the next drop there joins the pile beside, not a third cone on the first")
	items._items.erase(pile_stop_id)
	items.clear_dropped(Vector3.ZERO, 1.0e7)
	# A floor under a pile or a roof over it does not stop it (gate review, PR #1322): only what stands in the pile's own height range does.
	if items._structures.has("foundation_section"):
		items.drop_in_world(stone, 1000, pile_at)
		var floor_pile: int = items._items.keys()[0]
		var floor_y: float = float(items._items[floor_pile]["pos"].y)
		var floor_def: Dictionary = items._structures["foundation_section"]
		var floor_top: float = float(floor_def.get("top_m", 0.3))
		var floor_id: int = items._next_id   # real ids, so the grid lookup sees them (see the chest above)
		var roof_id: int = items._next_id + 1
		items._next_id += 2
		items._items[floor_id] = {"number": 1, "count": 1, "pos": Vector3(pile_at.x, floor_y - floor_top, pile_at.z), "left": 1.0e9, "struct": {"kind": "foundation_section", "yaw": 0.0}}
		items._items[roof_id] = {"number": 1, "count": 1, "pos": Vector3(pile_at.x, floor_y + 3.0, pile_at.z), "left": 1.0e9, "struct": {"kind": "foundation_section", "yaw": 0.0}}
		items.drop_in_world(stone, 1000, pile_at + Vector3(0.2, 0.0, 0.0))
		check(items.world_item_count() == 3 and int(items._items[floor_pile]["count"]) == 2000, "a pile on a floor and under a roof stays one pile (%d items)" % items.world_item_count())
		items._items.erase(floor_id)
		items._items.erase(roof_id)
		items.clear_dropped(Vector3.ZERO, 1.0e7)
	items.drop_in_world(stone, ItemsScript.PILE_CAP + 50, pile_at)
	check(items.world_item_count() == 2, "over the cap a second pile starts")
	var pile_id: int = -1

	for k in items._items:
		if int(items._items[k]["count"]) == ItemsScript.PILE_CAP:
			pile_id = k

	var before_stones: int = items.inventory_of(7).count_of(stone)
	items.action(7, Net.ACT_PICKUP, pile_id, 0, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) - before_stones == ItemsScript.PILE_HANDFUL and int(items._items[pile_id]["count"]) == ItemsScript.PILE_CAP - ItemsScript.PILE_HANDFUL, "E on a pile takes one handful")
	items.inventory_of(7).remove(stone, ItemsScript.PILE_HANDFUL)
	items.clear_dropped(Vector3.ZERO, 1.0e7)

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
	check(fourth.inventory_of(1).count_of(stone) == 0 and fourth.load_failures == ["inventories.json"], "with no earlier copy a corrupt save is named and nothing is loaded from it (terrain_server refuses to start)")

	# Gathering and loose items.
	var g = make("user://test_server_items_b")
	g.ground_height = func(x, z): return 20.0 + x * 0.1
	g.world_seed = 5
	g.gather_pace_ms = 0
	var clock: Array = [1000.0]
	g.game_seconds = func(): return clock[0]
	g.season_now = func(): return "summer"
	g.peer_connected_hello(1, "abcdef123456")
	g.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
	g.report_position(1, Vector3(500.0, 70.0, 500.0))
	check(g.gather(1, "flax", "plant", "0,0,77", 77, Vector3(501.0, 70.0, 500.0)), "flax can be gathered")
	check(g.inventory_of(1).count_of(g.table.number_of("plant_fibre")) >= 2, "flax gives fibre")
	check(g.gather(1, "gorse", "shrub", "0,0,78", 78, Vector3(501.0, 70.0, 500.0)), "a shrub with no harvest row still gives sticks")
	check(g.inventory_of(1).count_of(g.table.number_of("stick")) >= 1, "got sticks")
	check(g.gather(1, "dandelion", "plant", "0,0,79", 79, Vector3(501.0, 70.0, 500.0)), "dandelion gives its leaves, roots or flowers in season")
	check(g.inventory_of(1).count_of(g.table.number_of("dandelion_leaves")) + g.inventory_of(1).count_of(g.table.number_of("dandelion_roots")) + g.inventory_of(1).count_of(g.table.number_of("dandelion_flowers")) >= 1, "got a dandelion yield")
	var noticed: Array = []
	g.send_notice = func(_p, text): noticed.append(text)
	check(not g.gather(1, "wolfsbane", "plant", "0,0,90", 90, Vector3(501.0, 70.0, 500.0)) and noticed.size() == 1, "roots by hand give nothing and the player is told to get a shovel")
	g.action(1, Net.ACT_ADMIN_GIVE, g.table.number_of("wooden_shovel"), 0, 1, Vector3.ZERO)
	check(g.gather(1, "wolfsbane", "plant", "0,0,90", 90, Vector3(501.0, 70.0, 500.0)) and g.inventory_of(1).count_of(g.table.number_of("wolfsbane_roots")) >= 1, "with a shovel the roots come up")
	check(g.inventory_of(1).wear[g.inventory_of(1).numbers.find(g.table.number_of("wooden_shovel"))] == 1, "picking roots wears the shovel one use")
	check(g.gather(1, "comfrey", "plant", "0,0,91", 91, Vector3(501.0, 70.0, 500.0)), "comfrey still gives by hand")
	check(not g.gather(1, "flax", "plant", "0,0,77", 77, Vector3(501.0, 70.0, 500.0)), "a picked plant is bare until it regrows")
	clock[0] += ItemsScript.REGROW_GAME_S + 1.0
	check(g.gather(1, "flax", "plant", "0,0,77", 77, Vector3(501.0, 70.0, 500.0)), "and bears again after 3 game days")
	# HARVEST TABLE (TEST_RECIPE): one row per species with a harvest row (berry_yield or harvest_yield): product, count at 1x and 3x size, sticks given,
	# stays standing, second try the same season, and whether the client's label rule agrees with the server. All must be OK.
	var harvest_names: Array = (g._drops.get("berry_yield", {}) as Dictionary).keys() + (g._drops.get("harvest_yield", {}) as Dictionary).keys()
	var flora_json: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))
	var flora_rows: Dictionary = {}
	for flora_entry in flora_json["entries"]:
		flora_rows[str(flora_entry["name"])] = flora_entry

	g.season_stamp = func(): return 40
	var table_peer: int = 100
	var unstick: Array = ["stick", "thorny_canes", "log", "twine"]
	print("harvest table: species | product | count 1x | count 3x | sticks | stays | second try | label agrees")
	for species_name in harvest_names:
		if (g._drops.get("fruit_tree", {}) as Dictionary).has(str(species_name)):
			continue   # fruit trees have a real fruit store (a few pieces a press): test_fruit_tree.gd

		var entry: Dictionary = flora_rows.get(str(species_name), {})
		var seasons: Array = entry.get("season", [])
		var season_name: String = "summer" if seasons.is_empty() or seasons.has("all") or seasons.has("summer") else str(seasons[0])
		var row: Dictionary = GatherRulesScript.harvest_row(g._drops, str(species_name), season_name)
		if entry.is_empty() or row.is_empty():
			check(false, "%s has a harvest row and a flora row" % species_name)
			continue

		g.season_now = func(): return season_name
		table_peer += 1
		g.peer_connected_hello(table_peer, "tablepeer%03d" % table_peer)
		g.report_position(table_peer, Vector3(500.0, 70.0, 500.0))
		var item_number: int = g.table.number_of(str(row["item"]))
		var average: float = (float(entry["height_m"][0]) + float(entry["height_m"][1])) * 0.5
		var verdict: Dictionary = GatherRulesScript.check(entry, "shrub" if str(entry.get("shape", "")) == "shrub" else "plant", g._drops, season_name, func(_t): return true, func(_i): return true)
		var sticks_before: int = 0
		for unstick_id in unstick:
			sticks_before += g.inventory_of(table_peer).count_of(g.table.number_of(unstick_id))

		g._last_gather.clear()
		var got_1: bool = g.gather(table_peer, str(species_name), "shrub", "0,0,%d" % (1000 + table_peer), 1000 + table_peer, Vector3(501.0, 70.0, 500.0), average)
		var stays: bool = g.plant_stays
		var have_1: int = g.inventory_of(table_peer).count_of(item_number)
		g._last_gather.clear()
		var second_try: bool = g.gather(table_peer, str(species_name), "shrub", "0,0,%d" % (1000 + table_peer), 1000 + table_peer, Vector3(501.0, 70.0, 500.0), average)
		g._last_gather.clear()
		var got_3: bool = g.gather(table_peer, str(species_name), "shrub", "0,0,%d" % (2000 + table_peer), 2000 + table_peer, Vector3(501.0, 70.0, 500.0), average * 3.0)
		var have_3: int = g.inventory_of(table_peer).count_of(item_number) - have_1
		var sticks_after: int = 0
		for unstick_id in unstick:
			sticks_after += g.inventory_of(table_peer).count_of(g.table.number_of(unstick_id))

		var want_1: int = GatherRulesScript.harvest_count(row, 1.0)
		var want_3: int = GatherRulesScript.harvest_count(row, 3.0)
		var counted: bool = have_1 == want_1 and have_3 == want_3
		var ok: bool = got_1 and got_3 and stays and not second_try and sticks_after == sticks_before and bool(verdict["ok"]) and (counted or have_1 + have_3 > 0)
		print("  %s | %s | %d | %d | %d | %s | %s | %s" % [species_name, row["item"], have_1, have_3, sticks_after - sticks_before, "yes" if stays else "NO", "nothing" if not second_try else "GAVE MORE", "yes" if bool(verdict["ok"]) else "NO"])
		check(ok, "harvest row %s: product, counts, no sticks, stays, once a season, label agrees" % species_name)

	# Wild rose (D-ROSE-1): petals in summer, hips and plenty of seeds in autumn (drops.json seed_drops), nothing in spring though the bush is in leaf; the client's prompt agrees.
	var rose_flora: Dictionary = flora_rows["wild_rose"]
	var rose_avg: float = (float(rose_flora["height_m"][0]) + float(rose_flora["height_m"][1])) * 0.5
	var rose_got: Dictionary = {}
	for rose_season in ["spring", "summer", "autumn"]:
		g.season_now = func(): return rose_season
		table_peer += 1
		g.peer_connected_hello(table_peer, "rosepeer%03d" % table_peer)
		g.report_position(table_peer, Vector3(500.0, 70.0, 500.0))
		g._last_gather.clear()
		var picked: bool = g.gather(table_peer, "wild_rose", "shrub", "0,0,%d" % (3000 + table_peer), 3000 + table_peer, Vector3(501.0, 70.0, 500.0), rose_avg)
		var rose_inv = g.inventory_of(table_peer)
		var prompt_ok: bool = bool(GatherRulesScript.check(rose_flora, "shrub", g._drops, rose_season, func(_t): return true, func(_i): return true)["ok"])
		rose_got[rose_season] = [picked, rose_inv.count_of(g.table.number_of("rose_petals")), rose_inv.count_of(g.table.number_of("rose_hips")), rose_inv.count_of(g.table.number_of("wild_rose_seed")), prompt_ok]
	print("wild rose by season [picked, petals, hips, seeds, prompt]: %s" % str(rose_got))
	check(rose_got["spring"] == [false, 0, 0, 0, false], "a wild rose gives nothing in spring and the prompt says not in season")
	check(rose_got["summer"][0] and rose_got["summer"][1] >= 20 and rose_got["summer"][2] == 0 and rose_got["summer"][3] == 0 and rose_got["summer"][4], "a wild rose gives petals only in summer")
	check(rose_got["autumn"][0] and rose_got["autumn"][1] == 0 and rose_got["autumn"][2] >= 150 and rose_got["autumn"][3] >= int(g._drops["seed_drops"]["wild_rose"]["rows"][0][1]) and rose_got["autumn"][3] <= int(g._drops["seed_drops"]["wild_rose"]["rows"][0][2]) and rose_got["autumn"][4], "a wild rose gives hips and its seed row's seeds in autumn")
	check(str(GatherRulesScript.harvest_row(g._drops, "wild_rose").get("item", "")) == "rose_petals" and GatherRulesScript.harvest_row(g._drops, "wild_rose", "winter").is_empty(), "with no season the first row names the product; a season without a row has none")
	check(GatherRulesScript.harvest_count({"count": 10}, 0.01) == 1 and GatherRulesScript.harvest_count({"count": 0}, 0.5) == 1, "a harvest count is never 0")
	check(GatherRulesScript.harvest_count({"count": 10}, 3.0) == 30 and GatherRulesScript.harvest_count({"count": 7}, 1.2) == 9, "counts are the table number times size, rounded up")
	check(GatherRulesScript.harvest_scale(g._drops, 99.0, {"height_m": [1.0, 1.0]}) == 3.0 and GatherRulesScript.harvest_scale(g._drops, 0.1, {"height_m": [1.0, 1.0]}) == 1.0, "size scale stays between 1x and 3x")
	# The season boundary and a restart: picked at the last tick of one season, allowed again at the first of the next; bare through a restart.
	g.season_now = func(): return "summer"
	g.report_position(1, Vector3(500.0, 70.0, 500.0))
	g.season_stamp = func(): return 50
	g._last_gather.clear()
	check(g.gather(1, "wild_thyme", "plant", "0,0,60", 60, Vector3(501.0, 70.0, 500.0), 0.1), "thyme picked in season 50")
	g._last_gather.clear()
	check(not g.gather(1, "wild_thyme", "plant", "0,0,60", 60, Vector3(501.0, 70.0, 500.0), 0.1), "and not again in season 50")
	g.save()
	var restarted = make("user://test_server_items_b")
	restarted.season_stamp = func(): return 50
	check(restarted.stripped_ids("0,0").has(60), "a restart in the middle of the season keeps the plant bare")
	g.season_stamp = func(): return 51
	g._last_gather.clear()
	check(g.gather(1, "wild_thyme", "plant", "0,0,60", 60, Vector3(501.0, 70.0, 500.0), 0.1), "the first moment of season 51 allows it again")
	# Berry bushes (drops.json "berry_yield"): berries only, the plant stays, bare until the season changes; saved.
	var stamp: Array = [10]
	g.season_stamp = func(): return stamp[0]
	var raspberry: int = g.table.number_of("raspberries")
	check(g.gather(1, "raspberry", "shrub", "0,0,200", 200, Vector3(501.0, 70.0, 500.0), 2.0) and g.plant_stays, "a ripe raspberry bush gives berries and stays standing")
	check(g.inventory_of(1).count_of(raspberry) >= 1, "got raspberries")
	check(not g.gather(1, "raspberry", "shrub", "0,0,200", 200, Vector3(501.0, 70.0, 500.0), 2.0) and not g.plant_stays, "a bare bush gives nothing the same season")
	check(g.stripped_ids("0,0").has(200) and g.stripped_ids("0,1").is_empty(), "the bare bush is listed for its chunk")
	g.save()
	var again_b = make("user://test_server_items_b")
	again_b.season_stamp = func(): return stamp[0]
	check(again_b.stripped_ids("0,0").has(200), "the bare state survives a restart")
	stamp[0] = 11
	check(again_b.stripped_ids("0,0").is_empty(), "a new season clears it")
	# A save made under another flora layout names plants that no longer stand there: picked and bare marks start clean.
	var layout_path: String = "user://test_server_items_b/world_items.json"
	var layout_save: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	check(int(layout_save.get("layout", -1)) == FloraLayoutScript.VERSION, "the save carries the flora layout version")
	layout_save["layout"] = FloraLayoutScript.VERSION + 1
	var layout_file: FileAccess = FileAccess.open(layout_path, FileAccess.WRITE)
	layout_file.store_string(JSON.stringify(layout_save))
	layout_file.close()
	var other_layout = make("user://test_server_items_b")
	other_layout.season_stamp = func(): return 10     # the season the bush was picked in: without the clear it would still be bare
	check(other_layout.stripped_ids("0,0").is_empty(), "a save from another flora layout clears the bare marks")
	g.season_now = func(): return "winter"
	check(not g.gather(1, "raspberry", "shrub", "0,0,201", 201, Vector3(501.0, 70.0, 500.0), 2.0), "out of season gives nothing")
	# Picking never gives wood, canes or leaves from a berry species, in any season (Dave 2026-10-23: sticks from raspberries).
	var wood_ids: Array = ["stick", "thorny_canes", "leaves", "raspberry_leaves", "log", "twine"]
	var wood_start: Dictionary = {}
	for wood_id in wood_ids:
		wood_start[wood_id] = g.inventory_of(1).count_of(g.table.number_of(wood_id))

	var fresh: int = 300
	for species_name in (g._drops.get("berry_yield", {}) as Dictionary).keys():
		for season_name in ["spring", "summer", "autumn", "winter"]:
			g.season_now = func(): return season_name
			g.gather(1, str(species_name), "shrub", "0,0,%d" % fresh, fresh, Vector3(501.0, 70.0, 500.0), 2.0)
			fresh += 1
			g._last_gather.clear()

	var gave_wood: bool = false
	for wood_id in wood_ids:
		if g.table.number_of(wood_id) != 0 and g.inventory_of(1).count_of(g.table.number_of(wood_id)) != int(wood_start[wood_id]):
			gave_wood = true

	check(not gave_wood, "a berry bush never gives sticks, canes, leaves or wood in any season")
	g.season_now = func(): return "summer"
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
	var startled: Array = []
	t.animal_alarm = func(point, radius): startled.append([point, radius])
	t.action(1, Net.ACT_THROW, 0, 0, 0, Vector3(1.0, 0.3, 0.0))
	check(t.inventory_of(1).count_of(spear) == 0 and t._flights.size() == 1, "spear leaves the inventory")
	for n in range(400):
		t.tick(0.02)
	check(t._flights.is_empty() and t.world_item_count() >= 1, "spear came down as a world item")
	check(startled.size() == 1 and float(startled[0][1]) == float(t._bow.cfg["land_alarm_m"]) and float(startled[0][1]) > 0.0, "a spear that missed startles the animals where it came down (%s)" % str(startled))
	t.animal_alarm = Callable()
	var landed: Vector3 = Vector3.ZERO

	for k in t._items:
		if t._items[k]["number"] == spear:
			landed = t._items[k]["pos"]

	check(landed.x > 10.0 and absf(landed.y - 10.0) < 0.01, "spear landed ahead on the ground")

	# A thrown spear hits the first animal on its path for its throw_damage and drops there (MikeW, 3 Nov).
	var struck: Array = []
	var struck_lag: Array = []
	t.hit_animal_path = func(_peer, from, to, amount, lag) -> Dictionary:
		if from.x <= 6.0 and to.x >= 6.0:
			struck.append(amount)
			struck_lag.append(lag)
			return {"at": Vector3(6.0, 11.0, 0.0)}

		return {}
	t.action(1, Net.ACT_ADMIN_GIVE, spear, 0, 1, Vector3.ZERO)
	var before: int = t.world_item_count()
	t._last_throw.clear()
	var thrown_seen: int = Time.get_ticks_msec()
	t.action(1, Net.ACT_SEEN, 0, thrown_seen - 150, thrown_seen - 20, Vector3.ZERO)   # how far behind the thrower saw the animals goes with the spear
	t.action(1, Net.ACT_THROW, t.inventory_of(1).numbers.find(spear), 0, 0, Vector3(1.0, 0.1, 0.0))

	for n in range(100):
		t.tick(0.02)

	var want_damage: float = float(t.table.entry(t.table.id_of(spear)).get("throw_damage", 0.0))
	var by_animal: bool = false

	for k in t._items:
		if t._items[k]["number"] == spear and absf((t._items[k]["pos"] as Vector3).x - 6.0) < 0.01:
			by_animal = true

	check(struck.size() == 1 and is_equal_approx(float(struck[0]), want_damage) and want_damage > 0.0, "a thrown spear hurts the animal it hits for its throw_damage (%s)" % str(struck))
	check(by_animal and t._flights.is_empty() and t.world_item_count() == before + 1, "the spear drops where it struck the animal")
	check(struck_lag.size() == 1 and (struck_lag[0] as Array).size() == 2 and int(struck_lag[0][0]) >= 150 and int(struck_lag[0][1]) >= 20 and int(struck_lag[0][1]) < int(struck_lag[0][0]), "its hit is judged where the thrower saw the animals (%s)" % str(struck_lag))

	# Fires.
	var f = make("user://test_server_items_d")
	f.ground_height = func(x, z): return 10.0
	var rain: Array = [0.0]
	f.rain_now = func(): return rain[0]
	f.cover_at = func(p): return 1.0 if p.x > 100.0 else 0.0
	f.peer_connected_hello(1, "abcdef123456")
	f._characters[f._peer_key[1]]["grace_s"] = 0.0   # eat-once: the first-hour protection has its own test
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
	check(f._items[open_id]["fire"]["state"] == 9 and f._items[covered_id]["fire"]["state"] == 9, "a placed fire is laid, not lit")
	f.report_position(1, Vector3(2.0, 10.0, 0.0))
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("plant_fibre"), 0, 2, Vector3.ZERO)
	f.action(1, Net.ACT_LIGHT, open_id, 0, 0, Vector3.ZERO)
	f.report_position(1, Vector3(121.0, 10.0, 0.0))
	f.action(1, Net.ACT_LIGHT, covered_id, 0, 0, Vector3.ZERO)
	check(f._items[open_id]["fire"]["state"] == 40 and f._items[covered_id]["fire"]["state"] == 40, "lit by hand with fibre: four sticks make a survival fire")
	f.tick(10.0)
	check(ItemsScript.fire_is_lit(int(f._items[open_id]["fire"]["state"])) and ItemsScript.fire_is_lit(int(f._items[covered_id]["fire"]["state"])), "dry weather: both burn")
	rain[0] = 0.6
	f.tick(1.0)
	check(f._items[open_id]["fire"]["state"] == 9, "rain puts out the open fire (loaded, unlit)")
	check(ItemsScript.fire_is_lit(int(f._items[covered_id]["fire"]["state"])), "the covered fire survives rain")
	f.report_position(1, Vector3(2.0, 10.0, 0.0))
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("stick"), 0, 3, Vector3.ZERO)
	f.action(1, Net.ACT_FUEL, open_id, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("plant_fibre"), 0, 1, Vector3.ZERO)
	var fibre_held: int = f.inventory_of(1).count_of(f.table.number_of("plant_fibre"))   # no starter is used up any more (Dave 5 Nov 2026): lighting never changes it
	f.action(1, Net.ACT_LIGHT, open_id, 0, 0, Vector3.ZERO)
	check(ItemsScript.fire_is_lit(int(f._items[open_id]["fire"]["state"])) and f.inventory_of(1).count_of(f.table.number_of("plant_fibre")) == fibre_held, "an open fire lights in the rain (Dave 5 Nov 2026), and no starter is used up")
	f.tick(2.0)
	check(ItemsScript.fire_is_lit(int(f._items[open_id]["fire"]["state"])), "and it burns for a few seconds")
	f.tick(10.0)
	check(f._items[open_id]["fire"]["state"] == 9, "then the rain puts it out again (loaded, unlit)")
	rain[0] = 0.0
	# The rain wetted the sticks left in it (wet wood, fire design 5), so with no dry tinder in the fire each try lights about half the time
	# (wet_wood.light_x). The draw is seeded so the test always runs the same way, and it tries a few times, as a player would.
	check(int(f._items[open_id]["fire"].get("damp", 0)) > 0, "the rain has wetted the wood left in the fire")
	f._rain_rng.seed = 694
	var relight_tries: int = 0

	while relight_tries < 12 and not ItemsScript.fire_is_lit(int(f._items[open_id]["fire"]["state"])):
		f.action(1, Net.ACT_LIGHT, open_id, 0, 0, Vector3.ZERO)
		relight_tries += 1

	check(ItemsScript.fire_is_lit(int(f._items[open_id]["fire"]["state"])) and f.inventory_of(1).count_of(f.table.number_of("plant_fibre")) == fibre_held, "it lights once the rain stops (wet kindling: %d tries), and no starter is used up" % relight_tries)
	f.action(1, Net.ACT_FUEL, open_id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(f.table.number_of("stick")) == 1, "a lit fire takes another stick")
	# A campfire cooks only meat (Dave 31 Oct 2026): berries, nuts and roots do nothing on it (they are pot and hearth recipes).
	var berries: int = f.table.number_of("blueberries") if f.table.has_id("blueberries") else 0
	f.action(1, Net.ACT_ADMIN_GIVE, berries, 0, 2, Vector3.ZERO)
	f._last_cook.clear()
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(f.table.number_of("stewed_berries")) == 0 and f.inventory_of(1).count_of(f.table.number_of("roast_forage")) == 0 and f.inventory_of(1).count_of(berries) == 2, "a campfire does not cook berries")
	# Cooking: half-stale raw meat (half its life left) roasts into meat with twice that left (cooked_life_mult 2, never more than the roast's own life), and a hot meal warms.
	var ck_inv: Variant = f.inventory_of(1)
	var ck_meat: int = f.table.number_of("raw_meat")
	f.action(1, Net.ACT_ADMIN_GIVE, ck_meat, 0, 1, Vector3.ZERO)
	var ck_mslot: int = -1

	for sl in range(ck_inv.slot_count):
		if ck_inv.numbers[sl] == ck_meat:
			ck_mslot = sl

	ck_inv.wear[ck_mslot] = int(f.table.shelf_units(ck_meat) / 2)
	var ck_left: float = float(f.table.shelf_units(ck_meat) - int(ck_inv.wear[ck_mslot]))
	f._last_cook.clear()
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	var ck_roast_n: int = f.table.number_of("roast_meat")
	var ck_life: int = f.table.shelf_units(ck_roast_n)
	var ck_want: int = maxi(ck_life - int(minf(ck_left * 2.0, float(ck_life))), 0)
	var ck_aged: bool = false

	for sl in range(ck_inv.slot_count):
		if ck_inv.numbers[sl] == ck_roast_n:
			ck_aged = ck_aged or absi(int(ck_inv.wear[sl]) - ck_want) <= 1

	check(ck_aged, "a roast carries twice the raw life left (wear %d wanted)" % ck_want)
	# The same in the fire's store (it used to give a fresh roast, so meat near rotting came out with the roast's whole life).
	var ck_fire: Dictionary = f._items[open_id]["fire"]
	var ck_box = f._chests[int(ck_fire["uid"])]
	var ck_roasts_before: int = ck_box.count_of(ck_roast_n)
	ck_box.add(ck_meat, 1, int(f.table.shelf_units(ck_meat) / 2))

	for n in range(10):
		f._tend_fire(open_id, f._items[open_id], ck_fire, 2.0)

	var ck_box_aged: bool = false

	for sl in range(ck_box.slot_count):
		if ck_box.numbers[sl] == ck_roast_n:
			ck_box_aged = ck_box_aged or absi(int(ck_box.wear[sl]) - ck_want) <= 1

	check(ck_box.count_of(ck_roast_n) == ck_roasts_before + 1 and ck_box_aged, "the fire's store roasts half-stale meat with twice its life left, not a fresh roast (wear %d wanted, store %s)" % [ck_want, str(ck_box.wear)])

	for sl in range(ck_box.slot_count):
		if ck_box.numbers[sl] == ck_roast_n:
			ck_box.take_from_slot(sl, ck_box.counts[sl])
	f.vitals_of(1)["warmth"] = 50.0
	f._last_eat.clear()

	for sl in range(ck_inv.slot_count):
		if ck_inv.numbers[sl] == ck_roast_n:
			f.action(1, Net.ACT_EAT, sl, 0, 0, Vector3.ZERO)
			break

	check(float(f.vitals_of(1)["warmth"]) >= 59.0, "a hot meal lifts warmth")

	# Meat: raw meat cooks into roast meat and eating it raw makes you sick (Tyler: cook me). This checks the sickness at once, so the late
	# infection (sickness.json infection, on since 8 Nov; its own checks are in test_body_weather) is turned off for it.
	f._sick_cfg["infection"]["enabled"] = false
	var meat_n: int = f.table.number_of("raw_meat")
	f.action(1, Net.ACT_ADMIN_GIVE, meat_n, 0, 2, Vector3.ZERO)
	f._last_cook.clear()
	var roast_before: int = f.inventory_of(1).count_of(f.table.number_of("roast_meat"))
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	var made: int = f.inventory_of(1).count_of(f.table.number_of("roast_meat")) - roast_before
	check(made == 1, "a lit fire roasts one raw meat (%d roast)" % made)
	f._last_eat.clear()

	for sl in range(ck_inv.slot_count):
		if ck_inv.numbers[sl] == meat_n:
			f.action(1, Net.ACT_EAT, sl, 0, 0, Vector3.ZERO)
			break

	check(float(f.vitals_of(1).get("sick", 0.0)) > 0.0, "raw meat makes you sick")
	f._sick_cfg["infection"]["enabled"] = true
	f.report_position(1, Vector3(40.0, 10.0, 0.0))
	f._last_cook.clear()
	roast_before = f.inventory_of(1).count_of(f.table.number_of("roast_meat"))
	f.action(1, Net.ACT_COOK, open_id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(f.table.number_of("roast_meat")) == roast_before, "too far from the fire to cook")
	rain[0] = 0.6
	rain[0] = 0.0
	for n in range(int(ItemsScript.FIRE_BURN_S / 10.0) + 20):
		f.tick(10.0)

	check(f._items[covered_id]["fire"]["state"] == 8, "a fire burns out in time")
	# The open fire was fed two more sticks into its store (fire store, 2 Nov 2026), so it can still be burning here: let it burn out, then wait out FIRE_OUT_S.
	for n in range(200):
		if not f._items.has(open_id) or not ItemsScript.fire_is_lit(int(f._items[open_id]["fire"]["state"])):
			break

		f.tick(10.0)

	# A fire that burned past coals.coal_bed_s leaves coals (76), then warm ash (77), then cold ash (8; docs/design/fire_coals_design.md):
	# those real-time stages (2 h and 12 h) are run down by hand here, then cold ash is cleared after FIRE_OUT_S.
	for stage in range(2):
		for k in f._items:
			if f._items[k].has("fire") and int(f._items[k]["fire"]["state"]) in [ItemsScript.FIRE_STATE_COALS, ItemsScript.FIRE_STATE_ASH]:
				f._items[k]["left"] = 1.0

		f.tick(10.0)

	for n in range(int(ItemsScript.FIRE_OUT_S / 10.0) + 2):
		f.tick(10.0)

	var fires_left: int = 0

	for k in f._items:
		if f._items[k].has("fire"):
			fires_left += 1

	check(fires_left == 0, "a dead fire is cleared away")

	# Fire tiers (Dave 24 Oct): the biggest wood burns first, 3 pieces of a class set the tier and hold it until that wood is gone.
	var rate: float = ItemsScript.GAME_RATE
	var log_s: float = float(f._cooking["fuel"]["log"]) / rate
	var tf: Dictionary = {"state": 9, "burn_left": 0.0}

	for n in range(3):
		f._fire_add(tf, "log")

	f._fire_add(tf, "stick")
	tf["state"] = f._fire_best_state(tf)
	check(tf["state"] == ItemsScript.FIRE_STATE_BONFIRE, "three logs make a bonfire")
	f._fire_burn(tf, log_s + 1.0)
	check(tf["state"] == ItemsScript.FIRE_STATE_BONFIRE, "a bonfire keeps its size with two logs left")
	f._fire_burn(tf, 2.0 * log_s)
	check(tf["state"] == ItemsScript.FIRE_STATE_SURVIVAL and float(tf["burn_left"]) > 0.0, "with the logs gone it drops to the survival fire on its sticks")
	var tg: Dictionary = {"state": 9, "burn_left": 0.0}
	f._fire_add(tg, "log")
	f._fire_add(tg, "log")

	for n in range(3):
		f._fire_add(tg, "firewood")

	check(f._fire_best_state(tg) == 1, "two logs and three firewood make a campfire")
	f._fire_add(tg, "firewood")
	f._fire_burn(tg, log_s * 2.0)
	check(float(tg["wood"]["log"]) <= 0.001 and float(tg["wood"]["firewood"]) > 0.0, "logs burn before firewood")
	var tfw: Dictionary = {"state": 9, "burn_left": 0.0}
	f._fire_add(tfw, "firewood")
	f._fire_add(tfw, "stick")
	check(f._fire_best_state(tfw) == ItemsScript.FIRE_STATE_SURVIVAL, "one firewood is only a survival fire")

	# Campfire pot (Dave 24 Oct): a station that hangs over a fire and cooks only while that fire is lit.
	items.clear_dropped(Vector3.ZERO, 1.0e7)
	items.report_position(7, Vector3(300.0, 5.0, 300.0))
	var tri_id: int = 900801
	items._items[tri_id] = {"number": items.table.number_of("campfire_pot"), "count": 1, "pos": Vector3(301.0, 5.0, 300.0), "left": 1.0e9, "struct": {"kind": "campfire_pot", "yaw": 0.0, "uid": 0, "owner": "", "born": 0.0}}
	check(not items.station_near(7, "campfire_pot"), "a campfire pot with no fire under it is not a station")
	items._items[900802] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": Vector3(302.0, 5.0, 300.0), "left": 1.0e9, "fire": {"state": 40, "burn_left": 100.0, "covered": false, "recheck": 5.0}}
	check(not items.station_near(7, "campfire_pot"), "a lit fire 1 m beside the pot is not the pot's fire")
	items._items[900802]["pos"] = Vector3(301.0, 5.0, 300.0)
	check(items.station_near(7, "campfire_pot"), "a campfire pot over a lit fire is a station")
	items._items[900802]["fire"]["state"] = 9
	check(not items.station_near(7, "campfire_pot"), "a laid fire that is not lit does not cook")
	items._items.erase(tri_id)
	items._items.erase(900802)
	# No stack caps (Dave 24 Oct): weight is the limit, stone stacks without a cap, tools and kits stay one per slot.
	var capless: Variant = load("res://src/shared/inventory.gd").new(f.table)
	var big_stone: int = f.table.number_of("stone")
	check(f.table.stack_of(big_stone) == ItemTableScript.COUNT_MAX, "stone stacks to the count maximum (%d)" % f.table.stack_of(big_stone))
	check(f.table.stack_of(f.table.number_of("steel_shovel")) == 1 and f.table.stack_of(f.table.number_of("workbench_kit")) == 1, "a shovel and a kit stay one per slot")
	var left_over: int = capless.add(big_stone, 70000)
	check(capless.count_of(big_stone) == 70000 and left_over == 0 and capless.counts[capless.numbers.find(big_stone)] == 65535, "70,000 stones fill one slot and spill the rest into a second")
	capless.from_json_array([[big_stone, 99999999, 0]])
	check(capless.counts[0] == 65535, "an out-of-range count in a save is clamped on load")

	var fibre_n: int = items.table.number_of("plant_fibre")
	items.clear_dropped(Vector3.ZERO, 1.0e7)
	items.drop_in_world(fibre_n, 90000, Vector3(100.0, 5.0, 100.0))
	var fibre_pile: int = -1

	for k in items._items:
		if int(items._items[k]["number"]) == fibre_n and not items._items[k].has("fire"):
			fibre_pile = k

	var fibre_before: int = items.inventory_of(7).count_of(fibre_n)
	items.action(7, Net.ACT_PICKUP, fibre_pile, 0, 90000, Vector3.ZERO)
	check(items.inventory_of(7).count_of(fibre_n) - fibre_before <= ItemTableScript.COUNT_MAX and items._items.has(fibre_pile), "one pickup moves at most 65,535 and the rest stays on the ground")
	items.clear_dropped(Vector3.ZERO, 1.0e7)

	# Mining rock with the axe.
	var m = make("user://test_server_items_e")
	m.ground_height = func(x, z): return 10.0
	m.rock_at = func(x, z): return x > 0.0
	m.peer_connected_hello(1, "abcdef123456")
	m.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
	m.report_position(1, Vector3(5.0, 10.0, 0.0))
	var rock_stone: int = m.table.number_of("stone")
	m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == 0, "no axe, no stone")
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == 1, "axe on rock gives a stone")
	m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == 1, "blows too close together give nothing")

	for n in range(10):
		m._last_mine.clear()
		m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(6.0, 10.0, 0.0))

	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "a patch gives only a few stones")
	# Wear per use is data (drops.json tool_wear): three points a blow when the table says so.
	var axe_slot: int = m.inventory_of(1).numbers.find(m.table.number_of("stone_axe"))
	var wear_was: int = m.inventory_of(1).wear[axe_slot]
	m._drops["tool_wear"]["per_use"]["axe"]["rock"] = 3
	m._last_mine.clear()
	m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).wear[axe_slot] == wear_was, "a blow on the resting patch breaks nothing and wears nothing")
	m._last_mine.clear()
	m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(8.5, 10.0, 0.0))   # the next 8 m patch, still within reach
	check(m.inventory_of(1).wear[axe_slot] == wear_was + 3, "a blow on rock wears the axe by the table's number (%d to %d)" % [wear_was, m.inventory_of(1).wear[axe_slot]])
	m.inventory_of(1).remove(rock_stone, 1)   # that patch's stone back out: the counts below are the first patch's
	m._drops["tool_wear"]["per_use"]["axe"]["rock"] = 5

	m.report_position(1, Vector3(-5.0, 10.0, 0.0))
	m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(-6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "soil gives no stone")
	m.report_position(1, Vector3(5.0, 10.0, 0.0))
	m.action(1, Net.ACT_MINE, HeldTool.slot_of(m, "axe") + 1, 0, 0, Vector3(30.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL, "out of reach gives nothing")
	# Dave 13 Nov 2026: every swing uses the tool in hand. A pickaxe in hand, the axe still on the hotbar: the pick mines and wears, the axe does not.
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("stone_pickaxe"), 0, 1, Vector3.ZERO)
	var mine_pick: int = m.inventory_of(1).numbers.find(m.table.number_of("stone_pickaxe"))
	var axe_wear_now: int = m.inventory_of(1).wear[axe_slot]
	m._mined.clear()
	m._last_mine.clear()
	m.action(1, Net.ACT_MINE, mine_pick + 1, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL + 1 and int(m.inventory_of(1).wear[mine_pick]) == 1 and int(m.inventory_of(1).wear[axe_slot]) == axe_wear_now, "a pickaxe in hand mines bare rock and wears; the axe on the hotbar is not used")
	m._last_mine.clear()
	m.action(1, Net.ACT_MINE, 0, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(rock_stone) == ItemsScript.MINE_STONES_PER_CELL + 1, "nothing in hand (tools only on the hotbar): no stone")
	m.inventory_of(1).clear_slot(mine_pick)

	# Digging the ground with a shovel (ACT_DIG).
	var digs: Array = []
	m.dig_ground = func(centre, radius): digs.append([centre, radius])
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.is_empty(), "no shovel, no dig")
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("wooden_shovel"), 0, 1, Vector3.ZERO)
	m.action(1, Net.ACT_DIG, -1, 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.is_empty(), "the shovel on the hotbar but nothing in hand: no dig")
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(30.0, 10.0, 0.0))
	check(digs.is_empty(), "a dig out of reach does nothing")
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 1 and absf(float(digs[0][0].y) - (10.0 - ItemsScript.DIG_DEPTH_M)) < 0.001, "a shovel digs a hole a little below the point")
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 1, "digs too close together make one hole")
	m._last_dig.clear()
	var shovel_slot: int = m.inventory_of(1).numbers.find(m.table.number_of("wooden_shovel"))
	var shovel_wear: int = m.inventory_of(1).wear[shovel_slot]
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 2 and m.inventory_of(1).wear[shovel_slot] == shovel_wear + 1, "each dig wears the shovel by one")

	# Dig yields and fill (job 84): the ground's material decides what a dig brings up.
	var soil_n: int = m.table.number_of("soil")
	var clay_n: int = m.table.number_of("clay")
	var sand_n: int = m.table.number_of("sand")
	var held_stone: int = m.inventory_of(1).count_of(m.table.number_of("stone"))
	check(m.inventory_of(1).count_of(soil_n) == 0, "no soil before any dig yield is wired")
	var mat: Array = ["loam"]
	m.ground_material = func(_x, _z): return mat[0]
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(soil_n) >= 1 and m.inventory_of(1).count_of(soil_n) <= 3 and m.inventory_of(1).count_of(sand_n) == 0, "a dig in loam brings up soil, not sand")
	check(m.inventory_of(1).count_of(m.table.number_of("stone")) >= held_stone + 1, "a dig in loam always brings up a stone with the soil (Dave 28 Nov 2026, R-RES-DIG-STONES)")
	held_stone = m.inventory_of(1).count_of(m.table.number_of("stone"))
	mat[0] = "sand"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(sand_n) >= 1, "a dig in sand brings up sand")
	mat[0] = "rock"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(m.table.number_of("stone")) > held_stone, "a dig in bare rock gives stone")
	var have_fill: int = m.fill_units_of(1)
	check(have_fill >= 3, "the pack holds fill after digs")
	var took: int = m.take_fill(1, 2)
	check(took == 2 and m.fill_units_of(1) == have_fill - 2, "take_fill uses up what it reports")
	check(m.take_fill(1, 100000) == have_fill - 2 and m.fill_units_of(1) == 0, "take_fill never takes more than the pack holds")
	check(m.take_fill(2, 1) == 0, "a peer with no pack fills nothing")
	mat[0] = "clay"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(clay_n) >= 1, "a dig in clay brings up clay")
	var salt_n: int = m.table.number_of("sea_salt")   # the one live Salt (item "salt" 292 is retired)
	mat[0] = "salt_flat"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(salt_n) >= 1, "a dig in a salt flat brings up salt, the same Salt as sea salt")
	m.inventory_of(1).remove(salt_n, m.inventory_of(1).count_of(salt_n))
	m.inventory_of(1).remove(sand_n, m.inventory_of(1).count_of(sand_n))

	# digging.json under with an amount (crafting chain, 28 Nov 2026): [item, chance, min, max] brings up min..max of the layer below.
	var keep_under: Variant = m._dig_cfg.get("under", {})
	m._dig_cfg["under"] = {"loam": ["clay", 1.0, 2, 3]}
	m.inventory_of(1).remove(clay_n, m.inventory_of(1).count_of(clay_n))
	mat[0] = "loam"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	var under_clay: int = m.inventory_of(1).count_of(clay_n)
	check(under_clay >= 2 and under_clay <= 3, "a loam dig brings up 2 to 3 clay from the layer under it (%d)" % under_clay)
	m.inventory_of(1).remove(clay_n, under_clay)
	m._dig_cfg["under"] = keep_under

	# digging.json finds: a worm by chance in moist living soil (a stand-in item here, at chance 1, until Jamie's Worm row lands).
	check(str((m._dig_cfg.get("finds", [{}]) as Array)[0].get("item", "")) == "worm", "digging.json finds a worm in soil")
	var keep_finds: Variant = m._dig_cfg.get("finds", [])
	var find_n: int = m.table.number_of("rotten_food")
	m._dig_cfg["finds"] = [{"item": "rotten_food", "chance": 1.0, "soils": ["loam"]}]
	mat[0] = "loam"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(find_n) == 1, "a find comes up with a loam dig")
	mat[0] = "sand"
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(find_n) == 1, "but not in sand")
	m.inventory_of(1).remove(find_n, 1)
	m.inventory_of(1).remove(soil_n, m.inventory_of(1).count_of(soil_n))
	m.inventory_of(1).remove(sand_n, m.inventory_of(1).count_of(sand_n))
	m._dig_cfg["finds"] = keep_finds

	# Filling with the shovel (ACT_FILL, saved edits step 3): spends a shovelful, makes a fill, hands it back if refused.
	var fills: Array = []
	var accept: Array = [true]
	m.fill_ground = func(centre, radius, material): fills.append([centre, radius, material]); return accept[0]
	m.take_fill(1, 100000)
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.is_empty(), "an empty shovel raises nothing")
	m.action(1, Net.ACT_ADMIN_GIVE, soil_n, 0, 3, Vector3.ZERO)
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(30.0, 10.0, 0.0))
	check(fills.is_empty(), "a raise out of reach does nothing")
	m.action(1, Net.ACT_FILL, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 1 and int(fills[0][2]) == 5 and m.inventory_of(1).count_of(soil_n) == 2, "a raise takes one shovelful from the pack and makes loam ground")
	m._last_dig.clear()
	accept[0] = false
	m.action(1, Net.ACT_FILL, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 2 and m.inventory_of(1).count_of(soil_n) == 2, "a raise that changed nothing hands the shovelful back")
	accept[0] = true
	check(m.carried_kg_of(1) < 60.0, "digging cannot overfill the pack")

	# Shovel sizes (Dave 2026-10-22): a large shovel moves 8 pieces, a medium 4, a small 1.
	m.inventory_of(1).remove(m.table.number_of("wooden_shovel"), 1)
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("iron_shovel"), 0, 1, Vector3.ZERO)
	check(m._shovel_pieces(m.inventory_of(1), HeldTool.slot_of(m, "shovel")) == 8, "a large shovel moves 8 pieces (%d)" % m._shovel_pieces(m.inventory_of(1), HeldTool.slot_of(m, "shovel")))
	digs.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(digs.size() == 1 and is_equal_approx(float(digs[0][1]), 1.8), "a large shovel digs a sphere twice as wide (%s)" % str(digs))
	m.take_fill(1, 100000)
	m.action(1, Net.ACT_ADMIN_GIVE, soil_n, 0, 12, Vector3.ZERO)
	fills.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 1 and is_equal_approx(float(fills[0][1]), 1.8) and m.inventory_of(1).count_of(soil_n) == 4, "a large raise takes 8 shovelfuls from the pack")
	m.take_fill(1, 100000)
	m.action(1, Net.ACT_ADMIN_GIVE, soil_n, 0, 3, Vector3.ZERO)
	fills.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_FILL, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(fills.size() == 1 and fills[0][1] < 1.8 and m.inventory_of(1).count_of(soil_n) == 0, "a short pack raises a smaller heap")
	m.take_fill(1, 100000)
	m.inventory_of(1).remove(m.table.number_of("iron_shovel"), 1)
	m.action(1, Net.ACT_ADMIN_GIVE, m.table.number_of("wooden_shovel"), 0, 1, Vector3.ZERO)

	# The shovel tier adds to the top of the dig roll (digging.json tier_extra).
	check(m._shovel_tier(m.inventory_of(1), HeldTool.slot_of(m, "shovel")) >= 1, "the shovel tier is read from the tool in the pack")
	var most: int = 0
	mat[0] = "sand"

	for tries in 40:
		m._last_dig.clear()
		var before_sand: int = m.inventory_of(1).count_of(sand_n)
		m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
		most = maxi(most, m.inventory_of(1).count_of(sand_n) - before_sand)
		m.take_fill(1, 100000)

	check(most >= 1 and most <= 4, "a dig never exceeds the top of the roll plus the shovel extra (%d)" % most)

	# A dig the ground refuses (nothing changed) gives nothing.
	var refuse: Array = [false]
	m.dig_ground = func(centre, radius):
		digs.append([centre, radius])
		return not refuse[0]
	mat[0] = "loam"
	var soil_before: int = m.inventory_of(1).count_of(soil_n)
	refuse[0] = true
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(soil_n) == soil_before, "a dig that changes nothing brings up nothing")
	refuse[0] = false

	# The garden hoe: path patches and smoothing (no items, only wear).
	var hoe_n: int = m.table.number_of("wooden_hoe")
	m.action(1, Net.ACT_ADMIN_GIVE, hoe_n, 0, 1, Vector3.ZERO)
	m.ground_height = func(x, _z): return 10.0 + (0.4 if x > 6.5 else 0.0)
	var patches_of = func() -> int:
		var count: int = 0

		for it in m._items.values():
			if it.has("struct") and str(it["struct"]["kind"]) == "path_patch":
				count += 1

		return count
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(6.3, 10.0, 0.4))
	check(patches_of.call() == 1, "a hoe stroke treads a path patch")
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(6.6, 10.0, 0.6))
	check(patches_of.call() == 1, "a patch is not trodden twice within 0.7 m")
	var patch_pos: Vector3 = Vector3.ZERO

	for it in m._items.values():
		if it.has("struct") and str(it["struct"]["kind"]) == "path_patch":
			patch_pos = it["pos"]

	check(absf(patch_pos.x - 6.3) < 0.01 and absf(patch_pos.z - 0.4) < 0.01, "the patch lies exactly where the hoe pointed, not snapped to a metre grid")
	digs.clear()
	fills.clear()
	accept[0] = true
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(7.2, 10.0, 0.4))
	check(patches_of.call() == 2, "a second patch 0.9 m along is laid")
	# Dave 3 Nov: the path goes round a rock instead of painting on it.
	m._items[999001] = {"number": 0, "count": 4, "pos": Vector3(9.0, 10.0, 0.4), "left": 1.0e9, "scatter": 1, "boulder": {"radius": 0.5, "yaw": 0.0, "total": 4}}
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(8.2, 10.0, 0.4))
	check(patches_of.call() == 2, "no path patch is laid within a boulder's radius plus 1 m")
	m._items.erase(999001)
	check(digs.size() + fills.size() >= 1 and digs.size() + fills.size() <= ItemsScript.PATH_LEVEL_OPS, "Pathen: one click levels the spot to its average with at most %d edits (%d cuts, %d fills)" % [ItemsScript.PATH_LEVEL_OPS, digs.size(), fills.size()])
	digs.clear()
	fills.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(8.0, 10.0, 3.0))
	check(patches_of.call() == 3, "the next click lays its own level spot at once (no wait between clicks)")
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(30.0, 10.0, 0.0))
	check(patches_of.call() == 3, "a path out of reach does nothing")
	# Dave's play test 24 Nov 2026 (a Beech stood in the middle of a trodden path): no path on a standing tree; young trees under a path are trodden out;
	# nothing is planted on a path.
	var path_says: Array = []
	var was_notice: Callable = m.send_notice
	var was_near: Callable = m.trees_near
	var was_info: Callable = m.tree_info
	var was_cut: Callable = m.cut_tree
	var was_clock: Callable = m.game_seconds
	var beech_at: Array = [Vector3(5.5, 10.0, -1.5)]
	var cut_ids: Array = []
	m.send_notice = func(_p, text): path_says.append(text)
	m.trees_near = func(p, r): return [[Vector2i(0, 0), 4242]] if Vector2(p.x - beech_at[0].x, p.z - beech_at[0].z).length() <= r else []
	m.tree_info = func(_c, _id): return {"name": "Beech", "position": beech_at[0], "height": 20.0, "trunk": 0.5}
	m.cut_tree = func(c, tid): cut_ids.append(tid); return m.remove_dynamic(c, tid)
	m.game_seconds = func(): return 100.0 * 86400.0
	var before_tree: int = patches_of.call()
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(5.5, 10.0, -1.5))
	check(patches_of.call() == before_tree and path_says.size() == 1 and str(path_says[0]).begins_with("A beech stands there"), "no path patch is laid on a standing tree's trunk, and the player is told (%s)" % str(path_says))
	beech_at[0] = Vector3(5.5, 10.0, 1.6)   # 3.1 m off: the path goes past it
	var young_tree: Dictionary = {"slot": 0, "chunk": [0, 0], "species": 1, "pos": Vector3(5.3, 10.0, -0.8), "planted_at": 99.0 * 86400.0}   # 1 game day old, 0.73 m off the patch
	var grown_tree: Dictionary = {"slot": 1, "chunk": [0, 0], "species": 1, "pos": Vector3(4.0, 10.0, -3.5), "planted_at": 50.0 * 86400.0}   # grown full, 2.5 m off: stays
	var saplings_were: Array = m._saplings.duplicate()
	m._saplings.append(young_tree)
	m._saplings.append(grown_tree)
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(5.5, 10.0, -1.5))
	check(patches_of.call() == before_tree + 1, "a patch is laid beside a tree, clear of its trunk")
	check(not m._saplings.has(young_tree) and m._saplings.has(grown_tree) and cut_ids == [(1 << 16) | 0xFFFF], "the young tree under the new patch is trodden out (clients told), the grown one off the path stays (%s)" % str(cut_ids))
	grown_tree["pos"] = Vector3(4.6, 10.0, -3.0)
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_PATH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(4.7, 10.0, -2.9))
	check(patches_of.call() == before_tree + 1 and m._saplings.has(grown_tree), "a planted tree grown full stops a patch on its trunk too")
	var on_path: String = m._sapling_refusal("oak_seed", Vector3(5.9, 10.0, -1.0))
	check(on_path == "Nothing grows on a trodden path." or on_path.begins_with("The ground is frozen"), "a seed is not planted on a path patch (%s)" % on_path)
	check(m._spawn_zones.kind_near(5.9, -1.0, ItemsScript.PLANT_PATH_GAP_M, m._items, "path_patch") and not m._spawn_zones.kind_near(5.5, 3.0, ItemsScript.PLANT_PATH_GAP_M, m._items, "path_patch"), "the path lookup finds a patch 0.64 m off and none 3 m off")
	m._saplings = saplings_were
	m.send_notice = was_notice
	m.trees_near = was_near
	m.tree_info = was_info
	m.cut_tree = was_cut
	m.game_seconds = was_clock
	for patch_id in m._items.keys():
		if m._items[patch_id].has("struct") and str(m._items[patch_id]["struct"]["kind"]) == "path_patch" and Vector2(m._items[patch_id]["pos"].x - 5.5, m._items[patch_id]["pos"].z + 1.5).length() < 0.1:
			m._items.erase(patch_id)   # the checks below count the patches laid before
	var hoe_slot: int = m.inventory_of(1).numbers.find(hoe_n)
	var hoe_wear: int = m.inventory_of(1).wear[hoe_slot]
	digs.clear()
	fills.clear()
	accept[0] = true
	var soil_n1: int = m.table.number_of("soil")
	# A cut the ground refuses gives no Soil back (BugsList entry 1, Dave play test 19 Nov 2026).
	refuse[0] = true
	m._last_dig.clear()
	var soil_before_refused: int = m.inventory_of(1).count_of(soil_n1)
	m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(m.inventory_of(1).count_of(soil_n1) == soil_before_refused, "a refused Level cut gives no Soil")
	refuse[0] = false
	digs.clear()
	m._level_hold.clear()
	hoe_wear = m.inventory_of(1).wear[hoe_slot]
	m._last_dig.clear()
	var soil_before_cut: int = m.inventory_of(1).count_of(soil_n1)
	m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(6.0, 10.0, 0.0))
	# Levelling (Dave 14 Nov 2026): a 1 m grid of 29 spots within 3 m, toward the ground the player stands on (10.0 at x 5), at most LEVEL_MAX_OPS edits a stroke,
	# the spot farthest from level first. The 0.4 m step past x 6.5 is cut, nothing filled, and no cut goes below the player's ground.
	check(digs.size() >= 1 and digs.size() <= ItemsScript.LEVEL_MAX_OPS and fills.is_empty() and m.inventory_of(1).wear[hoe_slot] == hoe_wear + 1, "levelling cuts the high side toward the ground the player stands on, fills nothing, at most %d edits (%d cuts, %d fills)" % [ItemsScript.LEVEL_MAX_OPS, digs.size(), fills.size()])
	check(digs.all(func(cut): return absf(float(cut[1]) - ItemsScript.LEVEL_SPHERE_M) < 0.001 and float(cut[0].y) - ItemsScript.LEVEL_SPHERE_M >= 10.0 - 0.001), "no cut sphere reaches below the player's ground")
	# BugsList entry 1 (Dave play test 19 Nov 2026): the soil a cut takes away comes back, at least one Soil a cut, at the rate a fill of the same depth costs.
	var soil_from_cut: int = m.inventory_of(1).count_of(soil_n1) - soil_before_cut
	check(soil_from_cut >= digs.size() and not digs.is_empty(), "cutting gives the soil back (%d Soil from %d cuts)" % [soil_from_cut, digs.size()])
	check(ItemsScript._level_soil_units(ItemsScript.LEVEL_MAX_M, ItemsScript.LEVEL_SPHERE_M) > ItemsScript._level_soil_units(0.1, ItemsScript.LEVEL_SPHERE_M), "a deeper cut or fill moves more soil")
	check(patches_of.call() == 0, "levelled ground loses its path patches within 4 m (all three, the farthest 3.6 m away)")
	# Strokes add up: the heights are read through the edits made (the server's saved-edit log, here the digs and fills recorded), so held strokes level the whole circle and then stop.
	var level_ops = func(_point, _radius) -> Array:
		var ops: Array = []

		for cut in digs:
			ops.append([0, cut[0], cut[1]])

		for put in fills:
			ops.append([1, put[0], put[1]])

		return ops
	m.edits_near = level_ops
	var level_at: Vector3 = Vector3(6.0, 10.0, 0.0)
	var flat_after = func(height: float, slack: float) -> bool:
		var ops: Array = level_ops.call(level_at, 0.0)

		for cell_i in range(-3, 4):
			for cell_j in range(-3, 4):
				if cell_i * cell_i + cell_j * cell_j <= 9 and absf(m._edited_height(level_at.x + cell_i, level_at.z + cell_j, ops) - height) > slack:
					return false

		return true
	for stroke in 40:
		m._last_dig.clear()
		m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, level_at)
	var level_made: int = digs.size() + fills.size()
	check(fills.is_empty() and flat_after.call(10.0, ItemsScript.LEVEL_MIN_M), "held strokes level every spot of the 6 m circle to the player's ground (%d cuts)" % digs.size())
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, level_at)
	check(digs.size() + fills.size() == level_made, "once level, a stroke makes no more edits (the edit log does not grow)")
	# Standing on a foundation 0.5 m up: levelled to 0.1 m below the feet (10.4); fills top out there, and every fill is paid for in soil (BugsList entry 1).
	var cuts_before: int = digs.size()
	var soil_n2: int = m.table.number_of("soil")
	var notes_seen: Array = []
	m.send_notice = func(_p, text): notes_seen.append(text)
	m._items[999101] = {"number": m.table.number_of("wood_foundation"), "count": 1, "pos": Vector3(5.0, 10.4, 0.0), "left": 1.0e9, "struct": {"kind": "wood_foundation", "yaw": 0.0}}
	m.report_position(1, Vector3(5.0, 10.5, 0.0))
	m._level_hold.clear()
	m.inventory_of(1).remove(soil_n2, m.inventory_of(1).count_of(soil_n2))
	m._last_dig.clear()
	notes_seen.clear()
	m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, level_at)
	check(fills.is_empty() and notes_seen.any(func(n): return str(n).begins_with("Not enough soil")), "no soil: the low ground is not filled (no free fill) and the player is told (%s)" % str(notes_seen))
	m.action(1, Net.ACT_ADMIN_GIVE, soil_n2, 0, 400, Vector3.ZERO)
	m._level_hold.clear()

	for stroke in 40:
		m._last_dig.clear()
		m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, level_at)
	check(digs.size() == cuts_before and not fills.is_empty() and fills.all(func(put): return float(put[0].y) + ItemsScript.LEVEL_SPHERE_M <= 10.4 + 0.001), "on a foundation: the ground is filled up toward just under the feet, never above (%d fills)" % fills.size())
	check(m.inventory_of(1).count_of(soil_n2) < 400, "and the fill used up soil (%d of 400 left)" % m.inventory_of(1).count_of(soil_n2))
	check(fills.all(func(put): return Vector2(put[0].x - 5.0, put[0].z).length() >= ItemsScript.LEVEL_KEEP_M - 0.001), "no edit is centred under the player: the ground holding them up is kept")
	m._items.erase(999101)
	# Feet in the air with nothing built under them (a jump, a log): the target is the ground under the feet, not the feet; and while the button is held the target
	# stays where the action started, so ground it raised never lifts it (the creep Dave saw).
	m.report_position(1, Vector3(5.0, 14.0, 0.0))
	m._level_hold.clear()
	m._last_dig.clear()
	var fills_before: int = fills.size()
	var under_feet: float = m._edited_height(5.0, 0.0, level_ops.call(level_at, 0.0))
	m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, level_at)
	check(fills.slice(fills_before).all(func(put): return float(put[0].y) + ItemsScript.LEVEL_SPHERE_M <= under_feet + 0.001), "feet 3.6 m up, nothing built under them: nothing is filled above the ground under them")
	var held_target: float = float(m._level_hold[1][0])
	m.report_position(1, Vector3(5.0, 15.0, 0.0))
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_SMOOTH, HeldTool.slot_of(m, "hoe"), 0, 0, level_at)
	check(is_equal_approx(float(m._level_hold[1][0]), held_target), "a held stroke keeps the height the action started from")
	# A foundation on raised ground (BugsList entry 2): placement reads the saved fills, so a site built up 1.6 m above the generated ground takes a foundation on top.
	m.edits_near = func(_point, _radius) -> Array: return [[1, Vector3(-20.0, -18.4, 0.0), 30.0]]   # one wide fill: the ground round x -20 now stands about 11.6
	m.report_position(1, Vector3(-18.0, 11.7, 0.0))
	var raised_ids: Array = m._items.keys()
	m.place_piece(1, "wood_foundation_kit", Vector3(-20.0, 11.6, 0.0))
	var raised: Array = m._items.keys().filter(func(new_id): return not raised_ids.has(new_id) and m._items[new_id].has("struct") and str(m._items[new_id]["struct"]["kind"]) == "wood_foundation")
	check(raised.size() == 1 and absf(float(m._items[raised[0]]["pos"].y) - 11.6) < 0.1, "a foundation sits on hoe-raised ground 1.6 m above the generated surface (%s)" % str(raised.map(func(new_id): return m._items[new_id]["pos"])))

	for raised_id in raised:
		m._items.erase(raised_id)

	m.send_notice = Callable()
	m.edits_near = Callable()
	digs.clear()
	fills.clear()
	m.report_position(1, Vector3(5.0, 10.0, 0.0))
	# The grade line: nothing happens before both points are set; then a stroke brings the high side toward the ramp (A 10.0 at x 4 to B 10.2 at x 8).
	digs.clear()
	fills.clear()
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_GRADE, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(8.0, 10.0, 0.0))
	check(digs.is_empty() and fills.is_empty(), "a grade stroke without points A and B does nothing")
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 0, 0, Vector3(4.0, 10.0, 0.0))
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 1, 0, Vector3(8.0, 10.0, 0.0))
	var road_patches: int = patches_of.call()
	digs.clear()
	fills.clear()

	for step in 30:
		m._road_tick(0.6)

	check(patches_of.call() >= road_patches + 3, "setting point B lays a path along the A to B line by itself (%d patches more)" % (patches_of.call() - road_patches))
	check(digs.size() + fills.size() >= 1 and digs.size() + fills.size() <= 3 * 13, "and levels the ground along it, a few edits a station (%d cuts, %d fills)" % [digs.size(), fills.size()])
	check(m._roads.is_empty(), "the road job ends when the line is done")
	# Surveyor mode: the first marker of a job is the start; later markers wait and are built toward in the order set (the surveyor's line), then deleted.
	var flags_down: Array = []
	m.send_marker_done = func(_p, at): flags_down.append(at)
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 0, 0, Vector3(5.0, 10.0, -4.0))
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 1, 0, Vector3(5.0, 10.0, 4.0))
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 1, 0, Vector3(5.0, 10.0, 0.0))
	check(m._roads.has(1) and m._roads[1][0]["markers"].size() == 2, "markers set after the first wait for the builder")
	m._road_tick(0.6)
	check(m._roads[1][0]["seg"] != null and absf(m._roads[1][0]["seg"]["b"].z - 4.0) < 0.01, "the builder heads for the markers in the order set (the line the surveyor saw), not the nearest")
	check(m._roads[1][0]["markers"].size() == 1, "and that marker is off the list once it is being built toward")

	for step in 120:
		m._road_tick(0.6)

	check(m._roads.is_empty(), "the road has caught up when no markers are left")
	check(flags_down.size() >= 3, "each marker's flag is taken down once the builder reaches it (%d)" % flags_down.size())
	# BUG-007: a fresh survey is only the start marker; it is not "caught up" before a road is built. Surveying, building and caught up are distinct.
	var road_says: Array = []
	m.send_notice = func(_p, text): road_says.append(text)
	flags_down.clear()
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 0, 0, Vector3(4.0, 10.0, 0.0))

	for step in 20:
		m._road_tick(0.6)   # many ticks with only the start marker: early repeated ticks never finish it

	check(m._roads.has(1) and m._roads[1].size() == 1 and not m._roads[1][0]["built"] and m._roads[1][0]["seg"] == null, "a fresh survey stays a survey while only its start marker is set")
	check(road_says.size() == 1 and road_says[0].begins_with("Survey begun") and not road_says.any(func(said): return str(said).begins_with("The road has caught up")), "a fresh survey says it has begun, never that the road caught up (%s)" % str(road_says))
	check(flags_down.is_empty(), "and its start flag stays up")
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 0, 0, Vector3(8.0, 10.0, 0.0))
	check(m._roads.has(1) and m._roads[1].size() == 1 and Vector2(m._roads[1][0]["head"].x, m._roads[1][0]["head"].z).is_equal_approx(Vector2(8.0, 0.0)) and flags_down.size() == 1 and Vector2(flags_down[0].x, flags_down[0].z).is_equal_approx(Vector2(4.0, 0.0)), "a marker that starts a new road replaces a lone start marker (its flag comes down): the survey can be restarted")
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 1, 0, Vector3(5.0, 10.0, 2.0))
	check(m._roads[1][0]["markers"].size() == 1 and road_says[road_says.size() - 1].begins_with("Marker set"), "the next marker joins the survey")
	m._road_tick(0.6)
	check(m._roads[1][0]["built"] and m._roads[1][0]["seg"] != null, "with a marker to build toward the road is being built")
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 0, 0, Vector3(5.0, 10.0, -2.0))
	check(m._roads[1].size() == 2 and m._roads[1][0]["built"] and m._roads[1][0]["seg"] != null, "a road being built is not restarted by an unchained marker: the new survey waits its turn behind it")

	for step in 120:
		m._road_tick(0.6)

	check(m._roads.has(1) and m._roads[1].size() == 1 and not m._roads[1][0]["built"], "the first road is done and the new survey is next, still only its start marker")
	m._roads.clear()
	# Any distance (Dave 17 Nov 2026: past 40 m the second click started a new road): a marker 120 m on carries the road on, and once it caught up the next carries on from it.
	road_says.clear()
	m.report_position(1, Vector3(60.0, 10.0, 0.0))
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 0, 0, Vector3(0.0, 10.0, 0.0))
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 1, 0, Vector3(120.0, 10.0, 0.0))
	check(m._roads[1][0]["markers"].size() == 1 and road_says[road_says.size() - 1].begins_with("Marker set"), "a marker 120 m from the last joins the survey, not a new start (%s)" % str(road_says))
	m._road_tick(0.6)
	check(m._roads[1][0]["seg"] != null and int(m._roads[1][0]["seg"]["n"]) >= 170, "the road builds the whole 120 m stretch (%d stations)" % int(m._roads[1][0]["seg"]["n"]))
	m._roads[1][0]["seg"]["i"] = int(m._roads[1][0]["seg"]["n"])   # the long walk is not the point here: jump to its end

	for step in 6:
		m._road_tick(0.6)

	check(not m._roads.has(1) and road_says[road_says.size() - 1].begins_with("The road has caught up"), "the road caught up at the far marker")
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 1, 0, Vector3(120.0, 10.0, 30.0))
	check(m._roads.has(1) and m._roads[1][0]["built"] and Vector2(m._roads[1][0]["head"].x, m._roads[1][0]["head"].z).is_equal_approx(Vector2(120.0, 0.0)) and m._roads[1][0]["markers"].size() == 1, "the next marker of the same survey carries on from the last one, after it caught up")
	m._roads.clear()
	m._road_last.clear()
	m.report_position(1, Vector3(5.0, 10.0, 0.0))
	m.send_notice = Callable()
	m.send_notice = Callable()
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 0, 0, Vector3(4.0, 10.0, 0.0))
	m.action(1, Net.ACT_HOE_GRADE_POINT, hoe_slot, 1, 0, Vector3(8.0, 10.0, 0.0))

	for step in 30:
		m._road_tick(0.6)

	digs.clear()
	fills.clear()
	hoe_wear = m.inventory_of(1).wear[hoe_slot]
	m._last_dig.clear()
	m.action(1, Net.ACT_HOE_GRADE, HeldTool.slot_of(m, "hoe"), 0, 0, Vector3(7.0, 10.0, 0.0))
	check(digs.size() >= 1 and m.inventory_of(1).wear[hoe_slot] == hoe_wear + 1, "a grade stroke cuts ground above the A-B ramp (%d cuts, %d fills)" % [digs.size(), fills.size()])
	m.ground_height = Callable()

	# The admin showroom: the rows of showroom.json become real world items, filled by upsert, never saved or cleared as drops.
	m.ground_height = func(_x, _z): return 10.0
	var show_origin: Vector3 = Vector3(2000.0, 10.0, 2000.0)
	var show_of = func() -> Array:
		var found: Array = []

		for k in m._items:
			if m._items[k].has("showroom"):
				found.append(k)

		return found
	var show_rows: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/showroom.json"))
	var show_want: int = 0

	for row in show_rows["rows"]:
		for entry in row.get("items", []):
			if m.table.number_of(str(entry[0])) > 0:
				show_want += 1

	m.action(1, Net.ACT_SHOWROOM, 0, 0, 0, show_origin)
	check(show_want > 0 and show_of.call().size() == show_want, "the showroom fill places every row item as a real world item (%d of %d)" % [show_of.call().size(), show_want])
	m.action(1, Net.ACT_SHOWROOM, 0, 0, 0, show_origin)
	check(show_of.call().size() == show_want, "filling again does not duplicate them")
	var show_first: int = show_of.call()[0]
	var show_peer_was: Vector3 = m._peer_pos[1]
	m.report_position(1, m._items[show_first]["pos"])
	m.action(1, Net.ACT_PICKUP, show_first, 0, 0, Vector3.ZERO)
	check(not m._items.has(show_first) and show_of.call().size() == show_want - 1, "a showroom item can be picked up")
	m.action(1, Net.ACT_SHOWROOM, 0, 0, 0, show_origin)
	check(show_of.call().size() == show_want, "the next fill puts back only what was taken")
	check(m.clear_dropped(show_origin, 200.0) == 0 and show_of.call().size() == show_want, "clearing dropped items leaves the showroom alone")
	m.action(1, Net.ACT_SHOWROOM, 1, 0, 0, show_origin)
	check(show_of.call().size() == show_want, "respawn clears and fills again")
	m.ground_height = Callable()
	m.report_position(1, show_peer_was)

	for k in show_of.call():
		m._items.erase(k)

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
	var trunks_of = func() -> int:   # felled trees: their stumps (a tree comes down in its logs, Dave 16 Nov 2026)
		var n: int = 0

		for it in m._items.values():
			if it.has("tree") and int(it["tree"]["state"]) == 4:
				n += 1

		return n

	var base_trunks: int = trunks_of.call()
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(up[0] and trunks_of.call() == base_trunks, "a tree with half its ground left stays up")
	share[0] = 0.4
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(up[0], "a beech holds at 40 percent")
	species[0] = "spruce"
	species[1] = 0.35
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(not up[0] and trunks_of.call() == base_trunks + 1, "a spruce falls at 40 percent (shallow roots) and leaves a stump")
	up[0] = true
	species[0] = "oak"
	species[1] = 0.6
	share[0] = 0.3
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(up[0], "a big oak holds at 30 percent")
	share[0] = 0.2
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
	check(not up[0] and trunks_of.call() == base_trunks + 2, "a big oak falls at 20 percent")
	var trunk_dir: Dictionary = {}

	for it in m._items.values():
		if it.has("tree") and int(it["tree"]["state"]) == 4:
			trunk_dir = it["tree"]   # the last stump: the oak's

	check(absf(float(trunk_dir["yaw"]) - atan2(1.0, 0.0)) < 0.01, "it falls away from the hole")
	up[0] = true
	refuse[0] = true
	m._last_dig.clear()
	m.action(1, Net.ACT_DIG, HeldTool.slot_of(m, "shovel"), 0, 0, Vector3(6.0, 10.0, 0.0))
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
	w.tree_info = func(chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(chunk, id): standing.erase(id); felled_log.append(id); return true
	w.send_notice = func(peer, text): notices.append(text)
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))
	check(felled_log.is_empty() and w.inventory_of(1).count_of(w.table.number_of("stone_axe")) == 0, "no axe, no chopping")
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(20):   # TEST-013: the axe on the hotbar but nothing in hand fells nothing, however many blows
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	check(felled_log.is_empty(), "an axe on the hotbar but not in hand: the tree is not chopped")

	for n in range(3):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))

	check(felled_log.is_empty(), "a tree does not fall at the first blows")

	for n in range(10):
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))

	check(felled_log == [7], "enough blows fell it once")
	var trunks: int = 0
	var stumps: int = 0

	for k in w._items:
		if w._items[k].has("tree"):
			if int(w._items[k]["tree"]["state"]) == 4:
				stumps += 1
			else:
				trunks += 1

	var ground_count = func(item: String) -> int:
		var total: int = 0

		for k in w._items:
			if not w._items[k].has("tree") and not w._items[k].has("struct") and int(w._items[k]["number"]) == w.table.number_of(item):
				total += int(w._items[k]["count"])

		return total

	check(trunks == 0 and stumps == 1, "a stump stays where it stood, no whole trunk")
	check(ground_count.call("log_oak") >= 1 and w.shoulder_of(1) == "", "the oak comes down in oak logs on the ground, none in hand (%d logs)" % ground_count.call("log_oak"))
	check(ground_count.call("tree_roots") >= 1 and ground_count.call("stick") >= 1, "the root ball and the branches' sticks lie there too")

	# TEST-013 (Dave 12 Nov 2026): the tool in hand does the wood work. A held pickaxe (the axe still on the hotbar) only tears a fallen log up: kindling and
	# thatch, no sticks, and the axe on the hotbar is not used.
	var a_log: int = -1

	for k in w._items:
		if not w._items[k].has("tree") and int(w._items[k]["number"]) == w.table.number_of("log_oak"):
			a_log = k

	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_pickaxe"), 0, 1, Vector3.ZERO)
	var log_pick_slot: int = w.inventory_of(1).numbers.find(w.table.number_of("stone_pickaxe"))
	var axe_wear: int = int(w.inventory_of(1).wear[int(HeldTool.at_axe(w).x) - 1])
	var sticks_before: int = w.inventory_of(1).count_of(w.table.number_of("stick"))
	var splinters_before: int = w.inventory_of(1).count_of(w.table.number_of("kindling")) + w.inventory_of(1).count_of(w.table.number_of("thatch"))
	w.report_position(1, w._items[a_log]["pos"])
	w._last_process.clear()
	w.action(1, Net.ACT_PROCESS, a_log, 0, 0, Vector3(float(log_pick_slot + 1), 0.0, 0.0))
	check(w.inventory_of(1).count_of(w.table.number_of("stick")) == sticks_before and w.inventory_of(1).count_of(w.table.number_of("kindling")) + w.inventory_of(1).count_of(w.table.number_of("thatch")) > splinters_before, "a pickaxe in hand tears kindling and thatch off a fallen log, no sticks")
	check(int(w.inventory_of(1).wear[int(HeldTool.at_axe(w).x) - 1]) == axe_wear, "the axe on the hotbar is not used")
	w.inventory_of(1).remove(w.table.number_of("stone_pickaxe"), 1)
	w.report_position(1, Vector3(8.0, 10.0, 0.0))

	# A tree of a wood without its own log item (Dave 1 Nov: every tree gives logs) drops the plain Log.
	w._fell_record(Vector2i(0, 0), {"name": "wild_apple", "position": Vector3(40.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3}, Vector2(1.0, 0.0))
	check(ground_count.call("log") >= 1, "an apple tree comes down in plain logs (%d)" % ground_count.call("log"))
	check(w.table.number_of("log_wild_apple") > 0 and w.table.number_of("lumber_wild_cherry") > 0, "retired wood items stay in the item table, so old stock in saves and chests still loads")
	var stump_left: bool = false

	for k in w._items:
		if w._items[k].has("tree") and w._items[k]["tree"]["state"] == 4:
			stump_left = true

	check(stump_left, "the stump stays")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))

	w.report_position(1, Vector3(100.0, 10.0, 0.0))
	w._last_hit.clear()
	w.action(1, Net.ACT_HIT, 8, 0, 0, HeldTool.at_axe(w))
	check(felled_log == [7] and standing.has(8), "too far to chop")
	w.save()
	var w2 = make("user://test_server_items_f")
	var back: int = 0

	for k in w2._items:
		if w2._items[k].has("tree"):
			back += 1

	check(back == 2, "both stumps (the oak's and the apple's) survive a restart (%d)" % back)
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
	# Nothing regrows within no_spawn_m (20 m) of a placed structure (BUG-013; Dave 17 Nov 2026). 40 stumps, each its own roll; the saplings would land 2 to 6 m off 710..717, 710..714.
	q._items[q._next_id] = {"number": 0, "count": 1, "pos": Vector3(712.0, 10.0, 710.0), "left": 1.0e9, "struct": {"kind": "foundation_section", "yaw": 0.0}}
	q._grid_add(q._next_id, q._items[q._next_id])
	q._next_id += 1
	var before_ban: int = q._saplings.size()

	for n in range(40):
		q._maybe_sapling({"pos": Vector3(700.0 + float(n % 8), 10.0, 710.0 + floorf(float(n) / 8.0)), "tree": {"species": "oak", "chunk": [14, 14], "state": 4}})

	check(q._saplings.size() == before_ban, "no sapling is seeded within 20 m of a placed foundation")
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
	check(sp.inventory_of(1).counts[0] == 6 and sp.inventory_of(1).counts[10] == 4 and sp.inventory_of(1).numbers[10] == stone, "split moves a part to the first empty backpack slot (slot 10, after the hotbar)")
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
		wr.action(1, Net.ACT_MINE, HeldTool.slot_of(wr, "axe") + 1, 0, 0, Vector3(1.0, 10.0, 0.0))

	check(wr.inventory_of(1).wear[0] >= 13 and wr.inventory_of(1).wear[0] <= 16, "each effective blow on rock wears the axe five uses (drops.json tool_wear) (%d, care %.4f carry %.4f)" % [wr.inventory_of(1).wear[0], wr.skill_factor(1, "tool_care"), float(wr._wear_carry.get(1, 0.0))])
	wr.inventory_of(1).wear[0] = durability - 1
	wr._last_mine.clear()
	wr._mined.clear()
	wr.action(1, Net.ACT_MINE, HeldTool.slot_of(wr, "axe") + 1, 0, 0, Vector3(1.0, 10.0, 0.0))
	check(wr.inventory_of(1).count_of(axe_n) == 0, "the last use breaks the Stone - Axe and it is gone (no repair: master s2.2 rule 1; repair is test_tool_care)")
	var stones_before: int = wr.inventory_of(1).count_of(wr.table.number_of("stone"))
	wr._last_mine.clear()
	wr.action(1, Net.ACT_MINE, HeldTool.slot_of(wr, "axe") + 1, 0, 0, Vector3(1.0, 10.0, 0.0))
	check(wr.inventory_of(1).count_of(wr.table.number_of("stone")) == stones_before, "with no axe a blow on rock does nothing")
	wr.inventory_of(1).add(axe_n, 1, ceili(durability * 0.5))   # a fresh half-worn axe in the backpack (= durability - durability / 2, as the checks below expect)
	wr.action(1, Net.ACT_DROP, wr.inventory_of(1).numbers.find(axe_n), 0, 1, Vector3(0.5, 10.0, 0.0))
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
	lt.action(1, Net.ACT_ADMIN_GIVE, lean_kit, 0, 14, Vector3.ZERO)
	lt.place_item(1, lean_kit, Vector3(3.0, 10.0, 0.0), 0, 90)
	check(lt.world_item_count() == 1 and roofs.size() == 1 and lt.inventory_of(1).count_of(lean_kit) == 13, "a lean-to is placed and registers its roof")
	var roof: Array = roofs[1]
	check(absf(roof[5] - PI * 0.5) < 0.01 and roof[6] < 10.0 and roof[7] > 11.0, "the roof is a yawed box from just under the ground to 2 m up")
	lt.place_item(1, lean_kit, Vector3(4.0, 10.0, 0.0), 0)
	check(lt.world_item_count() == 1, "not within 2.5 m of another structure")

	for n in range(13):
		lt.report_position(1, Vector3(10.0 + float(n) * 4.0, 10.0, 0.0))
		lt.place_item(1, lean_kit, Vector3(10.0 + float(n) * 4.0 + 1.0, 10.0, 0.0), 0)
	check(lt.world_item_count() == 12, "twelve lean-tos fit in a chunk (cap_per_chunk, raised for groups 22 Nov 2026) (%d)" % lt.world_item_count())
	lt.save()
	var lt2 = make(ld)
	var roofs2: Array = []
	lt2.roof_add = func(r): roofs2.append(r); return roofs2.size()
	lt2.register_roofs()
	check(lt2.world_item_count() == 12 and roofs2.size() == 12, "lean-tos and their roofs come back after a restart")
	lt2.peer_connected_hello(1, "abcdef123456")
	lt2.report_position(1, Vector3(3.0, 10.0, 0.0))
	var shelter: int = 0

	for k in lt2._items:
		if lt2._items[k].has("struct") and absf(lt2._items[k]["pos"].x - 3.0) < 0.1:
			shelter = k

	lt2.roof_remove = func(key): roofs2.clear()
	lt2.action(1, Net.ACT_PICKUP, shelter, 0, 0, Vector3.ZERO)
	check(lt2.world_item_count() == 11 and lt2.inventory_of(1).count_of(lt2.table.number_of("stick")) >= 20, "taking it down gives its materials back (no kit)")   # the lean-to blueprint costs 20 sticks (items review stage 1; was 30)

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
	ch.action(1, Net.ACT_ADMIN_GIVE, stones_n, 0, 10, Vector3.ZERO)
	ch.place_item(1, chest_kit, Vector3(2.0, 10.0, 0.0), 0)
	var chest_id: int = 0

	for k in ch._items:
		if ch._items[k].has("struct"):
			chest_id = k

	check(chest_id != 0, "a chest is placed")
	ch.action(2, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
	check(sent.is_empty(), "too far from the chest to open it")
	ch.action(1, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
	check(sent.size() == 1 and sent[0][0] == 1, "opening sends the contents to the opener only")
	check(ch._chests[1].usable == 18, "the woven chest has 18 slots (3 rows)")
	ch.action(1, Net.ACT_ADMIN_GIVE, ch.table.number_of("plant_fibre"), 0, 1, Vector3.ZERO)

	for n in range(20):
		ch._chests[1].numbers[n] = 0

	for n in range(18):
		ch._chests[1].add(1000 + n, 1)

	check(ch._chests[1].add(ch.table.number_of("stone"), 1) == 1, "a full woven chest takes no more")

	for n in range(18):
		ch._chests[1].numbers[n] = 0
		ch._chests[1].counts[n] = 0

	var chest_stone_slot: int = ch.inventory_of(1).numbers.find(stones_n)
	ch.action(1, Net.ACT_CHEST_PUT, chest_stone_slot, chest_id, 6, Vector3.ZERO)
	check(ch.inventory_of(1).count_of(stones_n) == 4 and ch._chests[1].count_of(stones_n) == 6, "putting stones in moves them")
	ch._chests[1].add(stones_n, 14)   # 20 stones (10 kg) in the woven chest: a 22 kg oak log still goes in (Dave 19 Nov 2026: storage has no weight limit, only slots)
	var oak_n: int = ch.table.number_of("log_oak")
	ch.give(1, oak_n, 1)
	ch.action(1, Net.ACT_CHEST_PUT, -1, chest_id, 1, Vector3.ZERO)
	check(ch.shoulder_of(1) == "" and ch._chests[1].count_of(oak_n) == 1, "a 22 kg oak log goes into a woven chest already holding 20 stones (shoulder %s)" % ch.shoulder_of(1))
	ch._chests[1].remove(oak_n, 1)
	ch._chests[1].remove(stones_n, 14)
	var chest_log: int = ch.table.number_of("log_willow")
	ch.give(1, chest_log, 1)
	check(ch.shoulder_of(1) == "log_willow", "a willow log goes on the shoulder")
	ch.action(1, Net.ACT_CHEST_PUT, -1, chest_id, 1, Vector3.ZERO)
	check(ch.shoulder_of(1) == "" and ch._chests[1].count_of(chest_log) == 1, "the shoulder log goes into the chest (shoulder %s, chest %d)" % [ch.shoulder_of(1), ch._chests[1].count_of(chest_log)])
	ch.action(1, Net.ACT_CHEST_TAKE, ch._chests[1].numbers.find(chest_log), chest_id, 1, Vector3.ZERO)
	check(ch.shoulder_of(1) == "log_willow" and ch._chests[1].count_of(chest_log) == 0 and ch.inventory_of(1).count_of(chest_log) == 1, "taking it out puts it back in the pack (shown on the shoulder)")
	ch.lay_down_shoulder(1)
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
	check(not ch2._items.has(chest2) and ch2.inventory_of(1).count_of(ch2.table.number_of("chest_kit")) == 0 and ch2._chests.is_empty(), "an empty chest comes down and gives its materials, not a kit")

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
	cb.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
	cb.report_position(1, Vector3(0.0, 10.0, 0.0))
	cb.action(1, Net.ACT_ADMIN_GIVE, cb.table.number_of("chopping_block"), 0, 1, Vector3.ZERO)
	cb.place_item(1, cb.table.number_of("chopping_block"), Vector3(2.0, 10.0, 0.0), 0)
	var block_id: int = 0

	for k in cb._items:
		if cb._items[k].has("struct"):
			block_id = k

	check(block_id != 0, "a chopping block is placed")
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, HeldTool.slot_of(cb, "axe") + 1, Vector3.ZERO)
	check(notes.size() == 1, "no axe: told so")
	cb.action(1, Net.ACT_ADMIN_GIVE, cb.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	cb._last_use.clear()
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, 0, Vector3.ZERO)
	check(notes.size() == 2 and str(notes[-1]).contains("in hand"), "the axe on the hotbar but not in hand: told to hold it (%s)" % str(notes[-1]))
	notes.remove_at(notes.size() - 1)
	cb._last_use.clear()
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, HeldTool.slot_of(cb, "axe") + 1, Vector3.ZERO)
	check(notes.size() == 2, "no wooden block: told so")
	var firewood_n: int = cb.table.number_of("firewood")
	var block_n: int = cb.table.number_of("wooden_block")
	var loose_of = func(number: int) -> int:
		var total: int = 0

		for k in cb._items:
			if int(cb._items[k]["number"]) == number and not cb._items[k].has("struct"):
				total += int(cb._items[k]["count"])

		return total
	cb.action(1, Net.ACT_ADMIN_GIVE, block_n, 0, 2, Vector3.ZERO)
	var split_t0: int = Time.get_ticks_msec()
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, HeldTool.slot_of(cb, "axe") + 1, Vector3.ZERO)
	check(cb.inventory_of(1).count_of(block_n) == 1 and loose_of.call(firewood_n) == 4, "a wooden block splits into four firewood that falls beside the block")
	check(cb.inventory_of(1).wear[cb.inventory_of(1).numbers.find(cb.table.number_of("stone_axe"))] == 1, "and wears the axe one use")
	check(int(cb._last_use.get(1, -1)) >= split_t0, "the first request starts the pace")
	cb._last_use[1] = Time.get_ticks_msec()   # pin the clock: no time has passed since it (a loaded test PC can take longer than the pace between two lines)
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, HeldTool.slot_of(cb, "axe") + 1, Vector3.ZERO)
	check(cb.inventory_of(1).count_of(block_n) == 1, "the pace limit holds")
	cb._last_use.clear()
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, HeldTool.slot_of(cb, "axe") + 1, Vector3.ZERO)
	var heaps: int = 0

	for k in cb._items:
		if int(cb._items[k]["number"]) == firewood_n and not cb._items[k].has("struct"):
			heaps += 1

	check(loose_of.call(firewood_n) == 8 and heaps == 1, "the next piece joins the same heap beside the block (%d pieces in %d heaps)" % [loose_of.call(firewood_n), heaps])
	# Bug 3: the heap keeps growing past the 40 stack as one pile, and a pile lives the pile lifetime.
	cb.action(1, Net.ACT_ADMIN_GIVE, block_n, 0, 25, Vector3.ZERO)

	for n in range(25):
		cb._last_use.clear()
		cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, HeldTool.slot_of(cb, "axe") + 1, Vector3.ZERO)

	var big_heaps: int = 0
	var heap_left: float = 0.0

	for k in cb._items:
		if int(cb._items[k]["number"]) == firewood_n and not cb._items[k].has("struct"):
			big_heaps += 1
			heap_left = float(cb._items[k]["left"])

	check(loose_of.call(firewood_n) > 40 and big_heaps == 1 and heap_left >= ItemsScript.PILE_LIFETIME_S - 1.0, "the heap beside the block grows past 40 as one pile and lives as a pile (%d pieces, %d heaps, %.0f s)" % [loose_of.call(firewood_n), big_heaps, heap_left])

	# A log lying on the ground, struck with the axe, is not split: it is sawn into wooden blocks first (TREE_WOOD_TOOLS_DESIGN.md) and the player is told so.
	cb.drop_in_world(cb.table.number_of("log"), 1, Vector3(1.0, 10.0, 0.0))
	var lying: int = 0

	for k in cb._items:
		if int(cb._items[k]["number"]) == cb.table.number_of("log") and not cb._items[k].has("struct"):
			lying = k

	cb._last_process.clear()
	cb.action(1, Net.ACT_PROCESS, lying, 0, 0, Vector3.ZERO)
	check(cb._items.has(lying), "nothing in hand (the axe only on the hotbar): the log is not chopped (TEST-013)")
	var blocks_before: int = int(loose_of.call(block_n))
	var fire_before: int = int(loose_of.call(firewood_n))
	cb._last_process.clear()
	cb.action(1, Net.ACT_PROCESS, lying, 0, 0, HeldTool.at_axe(cb))
	check(cb._items.has(lying) and int(cb._items[lying]["count"]) == 1 and loose_of.call(block_n) == blocks_before and loose_of.call(firewood_n) == fire_before, "an axe on a plain log gives nothing and leaves the log")
	check(str(notes[-1]) == "Saw the log into wooden blocks first, then split the blocks.", "and says to saw it first (%s)" % str(notes[-1]))
	cb.drop_in_world(cb.table.number_of("log_spruce"), 1, Vector3(1.0, 10.0, 0.0))
	var spruce_lying: int = 0

	for k in cb._items:
		if int(cb._items[k]["number"]) == cb.table.number_of("log_spruce") and not cb._items[k].has("struct"):
			spruce_lying = k

	cb._last_process.clear()
	cb.action(1, Net.ACT_PROCESS, spruce_lying, 0, 0, HeldTool.at_axe(cb))
	check(cb._items.has(spruce_lying) and loose_of.call(block_n) == blocks_before and loose_of.call(firewood_n) == fire_before, "an axe on a large shoulder log gives nothing and leaves it too")

	# A wooden block lying on the ground: two axe blows split one block of the stack into four Firewood.
	cb.drop_in_world(block_n, 2, Vector3(1.0, 10.0, 0.5))
	blocks_before = int(loose_of.call(block_n))
	var ground_block: int = 0

	for k in cb._items:
		if int(cb._items[k]["number"]) == block_n and not cb._items[k].has("struct"):
			ground_block = k

	cb._last_process.clear()
	cb.action(1, Net.ACT_PROCESS, ground_block, 0, 0, HeldTool.at_axe(cb))
	check(cb._items.has(ground_block) and loose_of.call(block_n) == blocks_before and loose_of.call(firewood_n) == fire_before, "the first axe blow on a ground block splits nothing yet")
	cb._last_process.clear()
	cb.action(1, Net.ACT_PROCESS, ground_block, 0, 0, HeldTool.at_axe(cb))
	check(loose_of.call(block_n) == blocks_before - 1 and loose_of.call(firewood_n) == fire_before + 4, "the second blow uses one block and drops 4 Firewood (%d blocks, %d firewood)" % [loose_of.call(block_n), loose_of.call(firewood_n) - fire_before])

	# The chopping block takes the block from the ground when the pack has none (Dave 15 Nov 2026).
	cb.inventory_of(1).remove(block_n, cb.inventory_of(1).count_of(block_n))
	blocks_before = int(loose_of.call(block_n))
	fire_before = int(loose_of.call(firewood_n))
	cb._last_use.clear()
	cb.action(1, Net.ACT_USE_STRUCT, block_id, 0, HeldTool.slot_of(cb, "axe") + 1, Vector3.ZERO)
	check(blocks_before >= 1 and loose_of.call(block_n) == blocks_before - 1 and loose_of.call(firewood_n) == fire_before + 4 and cb.inventory_of(1).count_of(block_n) == 0, "E on the chopping block with an empty pack takes a block lying on the ground and drops 4 Firewood")

	# The large logs on the shoulder (Dave 2026-10-21; two at most since 15 Nov 2026): named for their tree, heavy, split at the block, fall with the body.
	var oak_log: int = cb.table.number_of("log_oak")
	var shoulder_sent: Array = []
	cb.send_carry = func(_p, id): shoulder_sent.append(id)
	check(oak_log > 0 and cb.is_shoulder_item(oak_log) and not cb.is_shoulder_item(cb.table.number_of("log")), "an oak log is a shoulder item, the short log is not")
	var kg_before: float = cb.carried_kg_of(1)
	cb.give(1, oak_log, 1)
	check(cb.shoulder_of(1) == "log_oak" and shoulder_sent.back() == "log_oak" and cb.inventory_of(1).count_of(oak_log) == 1, "an oak log is a pack item, shown on the shoulder")
	check(absf(cb.carried_kg_of(1) - kg_before - 22.0) < 0.01, "and its weight counts in the load, 22 kg for a hardwood log (%.1f kg more)" % (cb.carried_kg_of(1) - kg_before))
	var logs_said: Array = []
	cb.send_notice = func(_p, text): logs_said.append(text)
	cb.give(1, cb.table.number_of("log_beech"), 1)
	check(cb.shoulder_count(1) == 2 and cb.shoulder_of(1) == "log_oak" and cb.inventory_of(1).count_of(cb.table.number_of("log_beech")) == 1 and logs_said.is_empty(), "a second large log goes on the shoulder too")
	cb.give(1, cb.table.number_of("log_birch"), 1)
	var birch_id: int = 0

	for k in cb._items:
		if int(cb._items[k]["number"]) == cb.table.number_of("log_birch"):
			birch_id = k

	check(cb.shoulder_count(1) == 2 and birch_id != 0 and logs_said.has("You can carry two logs at most. Put one down first (Q)."), "a third large log lies on the ground and the player is told")
	logs_said.clear()
	cb.action(1, Net.ACT_PICKUP, birch_id, 0, 0, Vector3.ZERO)
	check(cb.shoulder_count(1) == 2 and cb._items.has(birch_id) and logs_said.has("You can carry two logs at most. Put one down first (Q)."), "it cannot be picked up while carrying two")
	check(cb.lay_down_shoulder(1) and cb.shoulder_count(1) == 1 and cb.shoulder_of(1) == "log_beech", "laying down puts one log on the ground and the other stays on the shoulder")
	cb.action(1, Net.ACT_PICKUP, birch_id, 0, 0, Vector3.ZERO)
	check(cb.shoulder_count(1) == 2 and not cb._items.has(birch_id), "with a hand free the birch log is picked up")
	check(cb.lay_down_shoulder(1) and cb.lay_down_shoulder(1) and cb.shoulder_count(1) == 0 and cb.shoulder_of(1) == "" and shoulder_sent.back() == "", "laying both down, one at a time, puts them on the ground")
	cb.give(1, oak_log, 1)
	cb.give(1, cb.table.number_of("log_beech"), 1)
	cb.kill(1, "test")
	check(cb.shoulder_count(1) == 0, "dying drops both shoulder logs")

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
	# BUG-029 (Dave 2026-11-04): out of air the swimmer stays under (no health drain): the heart races, then a faint, and a faint under water is drowning.
	var hearts: Array = []
	vt.send_body = func(_p, bpm, _eta, phase): hearts.append([bpm, phase])
	vt._breath[1] = 1.0
	vnotes.clear()

	for n in range(6):
		vt.tick(1.0)

	check(vnotes.has("You are out of air") and float(vt.vitals_of(1)["health"]) >= health_before - 0.5, "out of air says so and no longer drains health (%.1f)" % float(vt.vitals_of(1)["health"]))
	check(not hearts.is_empty() and hearts[-1][0] >= 110 and hearts[-1][0] <= 190 and hearts[-1][1] == 1, "suffocating races the heart (%s)" % str(hearts[-1] if not hearts.is_empty() else []))
	var bpm_early: int = int(hearts[-1][0])

	for n in range(5):
		vt.tick(1.0)

	check(int(hearts[-1][0]) > bpm_early and vt.remains_ids().size() == 0, "the heart keeps climbing and the swimmer is still alive and conscious (%d bpm)" % int(hearts[-1][0]))

	# Surfacing in time undoes it.
	vt.set_head_under(1, false)
	vt.tick(1.0)
	check(vt.breath_of(1) < 0.0 and vt.remains_ids().size() == 0 and int(vt._strain.get(1, {}).get("state", 0)) == 0, "surfacing before the faint ends it: air full, no faint, no death")
	vt.set_head_under(1, true)
	vt._breath[1] = 1.0
	vt.report_position(1, Vector3(50.0, 5.0, 50.0))
	var faint_seen: bool = false
	var lowest: float = 100.0

	for n in range(40):
		vt.tick(1.0)
		faint_seen = faint_seen or int(vt._strain.get(1, {}).get("state", 0)) == 2
		lowest = minf(lowest, float(vt.vitals_of(1)["health"]))

		if vt.remains_ids().size() > 0:
			break

	check(faint_seen and vt.remains_ids().is_empty() and lowest <= 2.0, "[%d remains, lowest health %.0f] fainting under water leaves 1 health, not dead (death.json stop_at_1; then the pass-out, test_cold_pass_out)" % [vt.remains_ids().size(), lowest])
	vt._death_cfg["stop_at_1"] = false
	vt._vitals[vt._peer_key[1]]["health"] = 100.0
	vt._suffocate.erase(1)
	vt._strain.erase(1)
	vt._cold_out.erase(1)   # the pass-out above (test_cold_pass_out) carried them out of the water: back under
	vt._out_water.erase(1)
	vt.set_head_under(1, true)
	vt._breath[1] = 1.0
	faint_seen = false

	for n in range(40):
		vt.tick(1.0)
		faint_seen = faint_seen or int(vt._strain.get(1, {}).get("state", 0)) == 2

		if vt.remains_ids().size() > 0:
			break

	check(faint_seen and vt.remains_ids().size() == 1 and float(vt.vitals_of(1)["health"]) > 90.0, "[%d remains, health %.0f] with stop_at_1 off fainting under water drowns: remains left, vitals start over" % [vt.remains_ids().size(), float(vt.vitals_of(1)["health"])])
	vt._death_cfg["stop_at_1"] = true
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
	vt.action(1, Net.ACT_ADMIN_GIVE, vt.table.number_of("herb_salve"), 0, 1, Vector3.ZERO)
	vt.action(1, Net.ACT_EAT, vt.inventory_of(1).numbers.find(vt.table.number_of("herb_salve")), 0, 0, Vector3.ZERO)
	check(vt.vitals_of(1)["health"] == 100.0, "a herb salve restores up to 25 health")
	vt.vitals_of(1)["limp"] = 300.0
	vt.action(1, Net.ACT_ADMIN_GIVE, vt.table.number_of("splint"), 0, 1, Vector3.ZERO)
	vt.action(1, Net.ACT_EAT, vt.inventory_of(1).numbers.find(vt.table.number_of("splint")), 0, 0, Vector3.ZERO)
	check(float(vt.vitals_of(1)["limp"]) == 0.0 and vt.inventory_of(1).count_of(vt.table.number_of("splint")) == 0, "a splint ends a limp and is used up")
	vt.save()
	var vt2 = make(vd)
	vt2.peer_connected_hello(1, "abcdef123456")
	check(absf(float(vt2.vitals_of(1)["weight"]) - float(vt.vitals_of(1)["weight"])) < 0.001, "weight survives a restart")

	# Why park_quiet_players is off outside the game's server (Lane A, 4 jobs, 26 Nov 2026): this test reports a position once and then
	# drives the clock by hand, and on a loaded machine more than ABSENT_MS of real time went by; the player was parked out of the world and
	# the thirst checks below failed ("no water within reach"). The control: on, the server's setting, the same quiet player is parked by
	# tick and cannot drink.
	var park_dir: String = "user://test_server_items_park"
	DirAccess.make_dir_recursive_absolute(park_dir)

	for file in DirAccess.get_files_at(park_dir):
		DirAccess.remove_absolute(park_dir + "/" + file)

	var park_items = make(park_dir)
	park_items.water_near = func(_pos, _reach): return true
	park_items.peer_connected_hello(1, "parkkey000001")
	park_items.report_position(1, Vector3(0.0, 10.0, 0.0))
	park_items._vitals_cfg["thirst"]["drink_pace_ms"] = 0
	park_items.vitals_of(1)["wet"] = 0.0
	park_items._heard_ms[1] = Time.get_ticks_msec() - ItemsScript.ABSENT_MS - 5000
	park_items._park_check_ms = 0
	park_items.tick(0.05)
	check(not park_items.is_absent(1), "off (the default): tick parks no player, whatever the real time since its report")
	park_items.park_quiet_players = true
	park_items._park_check_ms = 0
	park_items.tick(0.05)
	check(park_items.is_absent(1), "on (the game's setting): a player not heard from for ABSENT_MS of real time is parked by tick")
	park_items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(float(park_items.vitals_of(1)["wet"]) == 0.0, "and a parked player cannot drink: what failed the thirst checks below on a slow run")
	park_items.report_position(1, Vector3(0.0, 10.0, 0.0))
	park_items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(not park_items.is_absent(1) and float(park_items.vitals_of(1)["wet"]) > 0.0, "its next report puts it back and the same drink goes down (control)")

	# Thirst (job 67): one drink a game day, water at the edge, no regeneration when parched.
	var td: String = "user://test_server_items_thirst"
	DirAccess.make_dir_recursive_absolute(td)

	for file in DirAccess.get_files_at(td):
		DirAccess.remove_absolute(td + "/" + file)

	var th = make(td)
	th._comfort_data().erase("meter")   # the thirst arithmetic alone; the comfort meter's slower drain is test_comfort's
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

	# Carrying weight: stones weigh 0.5 kg (Dave 19 Nov 2026); a 75 kg player carries 52.5 kg at most and up to 80 percent of that (42 kg) with no hindrance.
	var cwd: String = "user://test_server_items_carry"
	DirAccess.make_dir_recursive_absolute(cwd)

	for file in DirAccess.get_files_at(cwd):
		DirAccess.remove_absolute(cwd + "/" + file)

	var cw = make(cwd)
	cw.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	cw.peer_connected_hello(1, "carrykey0001")
	cw.report_position(1, Vector3(0.0, 10.0, 0.0))
	cw.give(1, cw.table.number_of("stone"), 40)
	check(absf(cw.carried_kg_of(1) - 20.0) < 0.01, "forty stones weigh 20 kg (%.1f)" % cw.carried_kg_of(1))
	cw.give(1, cw.table.number_of("stone"), 200)
	check(cw.carried_kg_of(1) <= 52.51 and cw.carried_kg_of(1) > 50.0, "give stops at the hard cap, %.1f kg" % cw.carried_kg_of(1))
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

		for slot in range(inv_c.slot_count):
			inv_c.numbers[slot] = 0
			inv_c.counts[slot] = 0

		var stone_kg: float = CarryScript.weight_of("stone", ccfg)
		var whole: int = int(floor(load / stone_kg))
		inv_c.add(cw.table.number_of("stone"), whole)
		inv_c.add(cw.table.number_of("stick"), int(round((load - float(whole) * stone_kg) / CarryScript.weight_of("stick", ccfg))))
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
	# Dave 25 Nov 2026 (QA #19): the client is told the moment passing out starts (stance bit 16), and a faint wakes calm (not over-exerted).
	var going_sent: bool = false
	var after_wake: int = -1
	var last_state: int = 0

	for row in strains:
		going_sent = going_sent or ((int(row[3]) & 16) != 0 and int(row[1]) <= 1 and (int(row[3]) & 3) == 3)

		if last_state == 3 and int(row[1]) <= 1 and after_wake < 0:
			after_wake = int(row[1])

		last_state = int(row[1])

	check(going_sent, "passing out is sent to the client, already lying, before the faint itself (stance bit 16)")
	check(after_wake == 0, "a faint wakes calm, not over-exerted (wake_strain under over_off; woke to state %d)" % after_wake)
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

	for fit in [10, 50, 90]:   # 0 to 100, 50 an average adult (Dave 19 Nov 2026)
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

	check(winded[90] > winded[50] and winded[50] > winded[10] and winded[10] > 0.0, "fitter characters are winded later: %s" % str(winded))
	check(passed_out[90] > passed_out[50] and passed_out[50] > passed_out[10] and passed_out[10] > 0.0, "and black out later: %s" % str(passed_out))
	check(absf(winded[90] / winded[50] - 1.0 / 0.6) < 0.1, "fitness 90 raises exertion at 60%% of average (Dave 21 Nov: 100%% at 50 down to 50%% at 100), so the time to get winded stretches by 1/0.6 (%.2f)" % (winded[90] / winded[50]))
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
	sa.give(1, sa.table.number_of("stone"), 104)   # 52 kg, the carry limit, of 0.5 kg stones (Dave 19 Nov 2026)
	sa._strain[1] = {"s": 0.9, "state": 1, "t": 0.0}
	sa.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)

	for n in range(4 * 120):
		sa._vitals_tick(0.25)

	var floor_level: float = float(sa.strain_of(1)["s"])
	check(floor_level > 0.4 and floor_level < 0.6, "standing with a pack at the limit rests only to about half (%.2f)" % floor_level)
	# Fitness XP (fitness.json train, Dave 4 Nov): effort above 0.1 gives 1 + 2 x effort XP per 10 s into the day's bucket, which turns into points
	# at game midnight (200 XP a point on the 0 to 100 scale, the old 1,000 per 5 points; the same at every level); only true rest (under 0.02 for 10 minutes) takes it back, below the base too (Dave 21 Nov 2026), never under 0.
	var clk: Array = [100.0]   # game seconds, day 0
	var fit_gs: Callable = func(): return clk[0]
	var midnight: Callable = func(x): clk[0] += 86400.0; x._train_fitness(1, 0.0, 0.0)
	var tr = make(xd)
	tr.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	var training_sent: Array = []
	tr.send_training = func(_p, percent): training_sent.append(percent)
	tr.game_seconds = fit_gs
	tr.peer_connected_hello(1, "trainkey0001")
	tr.set_fitness(1, 60)
	check(tr.fitness_of(1) == 60, "fitness starts at its creation value")
	tr._train_fitness(1, 1.0, 660.0)
	midnight.call(tr)
	check(tr.fitness_of(1) == 60, "just under a point of running changes nothing")
	tr._train_fitness(1, 1.0, 400.0)
	check(tr.fitness_of(1) == 60, "XP earned today does not count until midnight")
	check(float(tr._characters[tr._peer_key[1]]["xp_today"]) > 100.0, "the day's XP waits in the character's bucket")
	check(not training_sent.is_empty() and int(training_sent[-1]) == tr.training_pm_of(1) and tr.training_pm_of(1) > 10, "today's training goes to the Tab screen as a percent of a point (%s)" % str(training_sent.slice(-1)))
	var sends_before: int = training_sent.size()
	tr._train_fitness(1, 1.0, 0.5)
	check(training_sent.size() == sends_before, "a tick that adds less than a whole percent sends nothing")
	midnight.call(tr)
	check(int(training_sent[-1]) == 0, "at midnight the Tab screen's training goes back to 0")
	check(tr.fitness_of(1) == 61, "the day's running tips a point over at midnight")
	var before_stroll: float = float(tr._characters[tr._peer_key[1]]["train"])
	tr._train_fitness(1, 0.05, 36000.0)
	midnight.call(tr)
	check(tr.fitness_of(1) == 61 and float(tr._characters[tr._peer_key[1]]["train"]) == before_stroll, "effort under the 10 percent line neither earns nor costs, even for hours")
	tr._train_fitness(1, 0.0, 300.0)
	check(float(tr._characters[tr._peer_key[1]]["train"]) == before_stroll, "a short rest under the grace time costs nothing")
	tr._asleep[1] = {"rested": 0.0, "t": 0.0}
	tr._train_fitness(1, 0.0, 1200.0)
	tr._train_fitness(1, 0.0, 1200.0)
	check(float(tr._characters[tr._peer_key[1]]["train"]) == before_stroll, "a night asleep (40 real minutes) costs no fitness")
	tr._asleep.erase(1)
	tr._train_fitness(1, 0.0, 300.0)
	check(float(tr._characters[tr._peer_key[1]]["train"]) == before_stroll, "after waking the rest grace starts again from 0")
	var ts = make(xd)
	ts.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	ts.game_seconds = fit_gs
	ts.peer_connected_hello(1, "trainkey0005")
	ts._train_fitness(1, 0.15, 3600.0)
	midnight.call(ts)
	check(float(ts._characters[ts._peer_key[1]]["train"]) > 0.0, "even a slow stroll over the 10 percent line earns a little")
	var tw = make(xd)
	tw.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	tw.game_seconds = fit_gs
	tw.peer_connected_hello(1, "trainkey0002")
	var tj = make(xd)
	tj.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	tj.game_seconds = fit_gs
	tj.peer_connected_hello(1, "trainkey0003")
	var tc = make(xd)
	tc.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	tc.game_seconds = fit_gs
	tc.peer_connected_hello(1, "trainkey0004")
	tw._train_fitness(1, 0.5, 3600.0)
	tj._train_fitness(1, 0.75, 3600.0)
	tc._train_fitness(1, 1.05, 3600.0)
	clk[0] += 86400.0
	tw._train_fitness(1, 0.0, 0.0)
	tj._train_fitness(1, 0.0, 0.0)
	tc._train_fitness(1, 0.0, 0.0)
	var gw: float = float(tw._characters[tw._peer_key[1]]["train"])
	var gj: float = float(tj._characters[tj._peer_key[1]]["train"])
	var gc: float = float(tc._characters[tc._peer_key[1]]["train"])
	check(gw > 0.0 and gw < gj and gj < gc, "an hour of walking trains less than jogging, less than hard tool work (%.2f %.2f %.2f)" % [gw, gj, gc])
	check(absf(gw - 3.6) < 0.01, "an hour of walking is 720 XP, 3.6 points (%.3f)" % gw)
	var t1 = make(xd)
	t1.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	t1.game_seconds = fit_gs
	t1.peer_connected_hello(1, "trainkey0007")
	t1.set_fitness(1, 50)
	t1._train_fitness(1, 1.0, 1800.0)
	midnight.call(t1)
	var first_pt: float = float(t1._characters[t1._peer_key[1]]["train"])
	t1._characters[t1._peer_key[1]]["train"] = 5.0
	t1._train_fitness(1, 1.0, 1800.0)
	midnight.call(t1)
	var gain_at_5: float = float(t1._characters[t1._peer_key[1]]["train"]) - 5.0
	check(absf(first_pt - gain_at_5) < 1.0e-6 and gain_at_5 > 0.0, "every point costs the same XP at any level (%.3f vs %.3f)" % [first_pt, gain_at_5])
	# Offline at midnight: the day's XP waits in the saved character and is paid at the next tick after login (one bucket only).
	var to = make(xd)
	to.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	to.game_seconds = fit_gs
	to.peer_connected_hello(1, "trainkey0008")
	to._train_fitness(1, 1.0, 3400.0)
	clk[0] += 86400.0 * 3.0
	to._train_fitness(1, 0.0, 1.0)
	check(to.fitness_of(1) == to._fitness_default() + 5, "a midnight that passed while away is paid at the next tick, once (%d)" % to.fitness_of(1))
	tr._train_fitness(1, 1.0, 1.0e7)
	midnight.call(tr)
	check(tr.fitness_of(1) == 100, "training stops at the top of the range")
	tr.set_fitness(1, 60)
	tr._train_fitness(1, 1.0, 1.0e7)
	midnight.call(tr)
	check(float(tr._characters[tr._peer_key[1]]["train"]) == 40.0 and tr.fitness_of(1) == 100, "training stops at the top of the range, no hidden points above it (base 60, 40 trained)")
	tr.set_fitness(1, 60)
	tr._characters[tr._peer_key[1]]["xp_today"] = 0.0
	tr._train_fitness(1, 1.0, 1800.0 * 3.0)
	midnight.call(tr)
	check(tr.fitness_of(1) > 60, "an hour and a half of running earns points")
	var earned: int = tr.fitness_of(1) - 60
	tr._train_fitness(1, 0.0, 600.0 + 8640.0 * float(earned + 5))
	check(tr.fitness_of(1) < 60 and tr.fitness_of(1) >= 54, "full rest takes points back, slowly, and below the creation value (Dave 21 Nov) (%d)" % tr.fitness_of(1))
	tr._train_fitness(1, 0.0, 1.0e7)
	check(tr.fitness_of(1) == 0, "but never below 0 (%d)" % tr.fitness_of(1))
	tr._train_fitness(1, 1.0, 1800.0)
	midnight.call(tr)
	check(tr.fitness_of(1) > 0, "a character idled to 0 trains back up")
	tr.set_fitness(1, 60)
	var rm_at: Callable = func(v): tr.set_fitness(1, v); return tr.fitness_rise_mult(1)
	check(absf(rm_at.call(50) - 1.0) < 1.0e-6 and absf(rm_at.call(75) - 0.75) < 1.0e-6 and absf(rm_at.call(100) - 0.5) < 1.0e-6, "exertion rises at 100% at fitness 50, 75% at 75, 50% at 100 (Dave 21 Nov)")
	check(absf(rm_at.call(0) - exp(0.5)) < 1.0e-6 and absf(rm_at.call(40) - exp(0.1)) < 1.0e-6, "under 50 the curve is kept: about 165% at 0, 110% at 40")
	tr.set_fitness(1, 60)
	# Saved: the training survives a restart (characters.json).
	tr._train_fitness(1, 1.0, 6700.0)
	midnight.call(tr)
	check(tr.fitness_of(1) == 70, "ten points earned (the old two)")
	tr.save()
	tr._finish_writer()
	var tr2 = make(xd)
	tr2.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	tr2.peer_connected_hello(1, "trainkey0001")
	check(tr2.fitness_of(1) == 70, "trained fitness is saved and read back (%d)" % tr2.fitness_of(1))

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
	check(en.energy_of(1) == 42.0 and en.inventory_of(1).count_of(bar) == 2, "a Nut cake gives 12 energy at once (master s3.16 [D17])")
	check(float(en._characters["energykey001"].get("train", 0.0)) == 0.0, "and costs no fitness training")
	en.vitals_of(1)["energy"] = 100.0
	en._last_eat.clear()
	en.action(1, Net.ACT_EAT, slot_bar, 0, 0, Vector3.ZERO)
	check(en.inventory_of(1).count_of(bar) == 1, "not tired: it is eaten all the same (no refusal)")

	for k in 40:
		en.vitals_of(1)["energy"] = 10.0
		en._last_eat.clear()
		en.action(1, Net.ACT_ADMIN_GIVE, bar, 0, 1, Vector3.ZERO)
		en.action(1, Net.ACT_EAT, en.inventory_of(1).numbers.find(bar), 0, 0, Vector3.ZERO)

	check(en.fitness_of(1) == fit_before and en.energy_of(1) == 10.0, "40 more while its Dessert slot runs: no energy and no fitness lost (%d to %d, energy %.0f)" % [fit_before, en.fitness_of(1), en.energy_of(1)])

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

	# Blackout is smooth and depends on the overshoot: right at the threshold it takes fall_s (2.5 s), a long way over it about fast_s.
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

	# Dave 25 Nov 2026 (QA #19): once passing out starts it is quick and cannot be run off: at most blackout.fall_s (2.5 s), faster far over.
	check(seconds_to_black[0] >= 2.0 and seconds_to_black[0] <= 3.0, "right at the threshold the blackout takes about fall_s, 2.5 s (%.1f)" % seconds_to_black[0])
	check(seconds_to_black[0] >= seconds_to_black[1] and seconds_to_black[1] >= seconds_to_black[2] and seconds_to_black[2] > seconds_to_black[3], "the further over the threshold the faster it comes on, never slower than fall_s (%s s)" % str(seconds_to_black))
	check(seconds_to_black[3] < 2.0, "a long way over it blacks out in about 1.5 s (%.2f)" % seconds_to_black[3])
	check(smooth, "the blackout level only climbs and never jumps")
	check(int(sa.strain_of(1)["state"]) == 2 and sa.stance_of(1) == 3, "fainting forces lying")
	sa.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	check(sa.stance_of(1) == 3, "a fainted player cannot choose a stance")

	# The moment the threshold is crossed the body is not the player's: lying at once, no stance choice, no effort, and resting
	# (strain falling back under the threshold) does not call it off; the black climbs on to the faint.
	sa._strain[1] = {"s": 1.45, "state": 1, "t": 0.0}
	sa._stance[1] = 0
	sa._exertion[1] = 1.0
	sa._strain_tick(1, 0.25)
	check(sa.strain_going(1) and sa.stance_of(1) == 3, "crossing the faint threshold drops the player to lying at once")
	sa.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	check(sa.stance_of(1) == 3, "a player passing out cannot stand up")
	check(sa.exertion_of(1) == 0.0, "a player passing out makes no effort")
	var went_out: bool = false

	for n in 20:
		sa._strain[1]["s"] = 0.5
		sa._strain_tick(1, 0.25)
		went_out = went_out or int(sa.strain_of(1)["state"]) == 2

	check(went_out and not sa.strain_going(1), "resting under the threshold does not call off passing out: it ends in the faint")

	# Tools batch 1: the hand saw turns a log into lumber by the balance row and wears; the hammer and adze recipes use live items.
	var hs_dir: String = "user://test_server_items_handsaw"
	DirAccess.make_dir_recursive_absolute(hs_dir)

	for file in DirAccess.get_files_at(hs_dir):
		DirAccess.remove_absolute(hs_dir + "/" + file)

	var hs = make(hs_dir)
	hs.send_craft_queue = func(_p, _e, _l): pass
	hs.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	hs.peer_connected_hello(1, "handsawkey01")
	hs.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
	var by_hand: Dictionary = {}

	for rn in hs.recipes.numbers():
		if hs.recipes.recipe(rn)["id"] == "lumber_by_hand":
			by_hand = hs.recipes.recipe(rn)

	check(not by_hand.is_empty() and by_hand["gives"][1] == 6 and by_hand["craft_s"] == 24.0, "the hand saw recipe matches the balance row (6 lumber, 24 s, master s2.3)")
	hs.give(1, hs.table.number_of("log"), 2)
	hs._last_queue_act.clear()
	hs.action(1, Net.ACT_CRAFT_QUEUE, int(by_hand.get("number", 0)), 0, 1, Vector3.ZERO)
	check(hs.craft_queue_of(1).is_empty() and hs.inventory_of(1).count_of(hs.table.number_of("log")) == 2, "no saw, no craft: the log stays")
	hs.give(1, hs.table.number_of("hand_saw"), 1)   # a tool new in the pack goes on the first empty hotbar key (inventory step 4)
	var saw_slot: int = hs.inventory_of(1).numbers.find(hs.table.number_of("hand_saw"))
	hs._last_queue_act.clear()
	hs.action(1, Net.ACT_CRAFT_QUEUE, int(by_hand.get("number", 0)), 0, 1, Vector3.ZERO)   # nothing in hand: the saw in the pack counts (Dave 24 Nov 2026)
	check(hs.craft_queue_of(1).size() == 1, "a saw in the pack, not in hand, still saws (Dave 24 Nov 2026: \"if you have a knife in you inventory or on your hotbar it should count\")")

	for n in 100:
		hs._craft_tick(0.25)

	check(hs.inventory_of(1).count_of(hs.table.number_of("lumber")) == 6 and hs.inventory_of(1).count_of(hs.table.number_of("log")) == 1, "one log sawn by hand gives 6 lumber")
	check(saw_slot >= 0 and hs.inventory_of(1).on_hotbar(saw_slot) and hs.inventory_of(1).wear[saw_slot] >= 1, "sawing wears the hand saw")
	var far_slot: int = hs.inventory_of(1).slot_count - 1
	hs.inventory_of(1).move(saw_slot, far_slot)   # off the hotbar, deep in the pack
	check(not hs.inventory_of(1).on_hotbar(far_slot) and hs._hand_tool_ok(1, hs.inventory_of(1), by_hand, -1) and hs._craft_tool_slot(hs.inventory_of(1), "saw") == far_slot, "a saw deep in the pack, off the hotbar, still counts for a craft and is the one it wears")
	var saw_wear: int = hs.inventory_of(1).wear[far_slot]
	hs.inventory_of(1).wear[far_slot] = hs.inventory_of(1).max_durability(far_slot)   # worn out
	check(not hs._hand_tool_ok(1, hs.inventory_of(1), by_hand, -1), "a broken saw in the pack does not count")
	hs.inventory_of(1).wear[far_slot] = saw_wear
	hs.inventory_of(1).move(far_slot, saw_slot)

	# Saw speed (TREE_WOOD_TOOLS_DESIGN.md s5): the first saw on the hotbar sets the pace of a craft that keeps a saw (Copper 0.5, Iron 1.0), a Sawbuck in reach halves the time.
	hs.ground_height = func(_x, _z): return 10.0
	hs.report_position(1, Vector3(0.0, 10.0, 0.0))
	check(is_equal_approx(hs._saw_slow(1, by_hand), 1.0), "an iron saw saws at the recipe's pace (x%.2f)" % hs._saw_slow(1, by_hand))
	check(is_equal_approx(hs._saw_slow(1, hs.recipes.recipe(1)), 1.0), "a craft that keeps no saw is never slowed")
	hs.inventory_of(1).remove(hs.table.number_of("hand_saw"), 1)
	hs.give(1, hs.table.number_of("copper_saw"), 1)
	check(is_equal_approx(hs._saw_slow(1, by_hand), 2.0), "a copper saw takes twice as long (x%.2f)" % hs._saw_slow(1, by_hand))
	hs._items[900901] = {"number": hs.table.number_of("sawbuck"), "count": 1, "pos": Vector3(1.0, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "sawbuck", "yaw": 0.0, "uid": 0, "owner": "", "born": 0.0}}
	var blocks_recipe: Dictionary = hs.recipes.recipe(728)   # saw_blocks: a log into 6 Wooden blocks (W-4)
	check(hs.serving_station(1, "sawbuck") == 900901 and is_equal_approx(hs._saw_slow(1, blocks_recipe), 1.0), "a Sawbuck in reach halves sawing blocks: the copper saw is back to the recipe's pace (x%.2f)" % hs._saw_slow(1, blocks_recipe))
	check(is_equal_approx(hs._saw_slow(1, by_hand), 1.0), "the Sawbuck speeds sawing planks too (W-33; x%.2f)" % hs._saw_slow(1, by_hand))
	hs._items.erase(900901)

	# A part sawn on the way needs the saw in hand too (W-32): a Chopping block (1 Wooden block) from the last log plans saw_blocks first.
	var chop_rec: Dictionary = {}

	for rn in hs.recipes.numbers():
		if hs.recipes.recipe(rn)["id"] == "chopping_block":
			chop_rec = hs.recipes.recipe(rn)

	var copper_slot: int = hs._tool_slot(hs.inventory_of(1), "saw")
	var chop_said: Array = []
	hs.send_notice = func(_p, text): chop_said.append(text)
	hs.vitals_of(1)["weight"] = 5000.0   # the six blocks the plan makes must fit; carrying is not under test here
	hs._last_queue_act.clear()
	hs.action(1, Net.ACT_CRAFT_QUEUE, int(chop_rec.get("number", 0)), 0, 1, Vector3.ZERO)
	check(copper_slot >= 0 and hs.craft_queue_of(1).size() == 2 and hs.inventory_of(1).count_of(hs.table.number_of("log")) == 0, "with the saw in the pack (nothing in hand) it queues the sawing, then the Chopping block (%d entries; said %s)" % [hs.craft_queue_of(1).size(), str(chop_said)])
	hs._cancel_craft(1, 1)
	hs._cancel_craft(1, 0)
	hs.send_notice = Callable()

	for rid in ["stone_hammer"]:
		var rec: Dictionary = {}

		for rn in hs.recipes.numbers():
			if hs.recipes.recipe(rn)["id"] == rid:
				rec = hs.recipes.recipe(rn)

		var live: bool = not rec.is_empty()

		for row in rec.get("needs", []):
			live = live and int(row[0]) > 0 and not bool(hs.table.entry(hs.table.id_of(int(row[0]))).get("retired", false))

		check(live and int(rec["gives"][0]) == hs.table.number_of(rid), "%s is made from live items (the Wooden - Hammer retired 18 Nov 2026: tools start at Stone)" % rid)

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
	var cord: int = cq.table.number_of("twine")
	cq.give(1, fibre, 30)
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 4, CraftHand.at(cq, 1, 1))
	check(cq.inventory_of(1).count_of(fibre) == 18, "queueing 4 twine takes 12 fibre now (%d left)" % cq.inventory_of(1).count_of(fibre))
	check(cq.craft_queue_of(1) == [[1, 4]], "queue holds one entry of 4")
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 2, CraftHand.at(cq, 1, 1))
	check(cq.craft_queue_of(1) == [[1, 6]], "queueing the same recipe again merges")
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 99, 0, 1, CraftHand.at(cq, 1, 99))
	cq._last_queue_act.clear()
	cq.action(1, Net.ACT_CRAFT_QUEUE, 16, 0, 1, CraftHand.at(cq, 1, 16))
	check(cq.craft_queue_of(1).size() == 1, "unknown recipes are refused")

	for n in range(4 * 2 + 1):
		cq._craft_tick(0.25)

	check(cq.inventory_of(1).count_of(cord) == 1 and cq.craft_queue_of(1) == [[1, 5]], "one twine after its 2 s (%d)" % cq.inventory_of(1).count_of(cord))
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
		cq.action(1, Net.ACT_CRAFT_QUEUE, 1 if n % 2 == 0 else 7, 0, 1, CraftHand.at(cq, 1, 1 if n % 2 == 0 else 7))

	check(cq.craft_queue_of(1).size() <= 10, "queue is capped at 10 entries (%d)" % cq.craft_queue_of(1).size())
	cq._last_queue_act.clear()
	var in_a_row: int = cq.craft_queue_of(1).size()
	var cancel_t0: int = Time.get_ticks_msec()
	cq.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(int(cq._last_queue_act.get(1, -1)) >= cancel_t0, "the first request starts the pace")
	cq._last_queue_act[1] = Time.get_ticks_msec()   # pin the clock: no time has passed since it (a loaded test PC can take longer than the pace between two lines)
	cq.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(cq.craft_queue_of(1).size() == in_a_row - 1, "queue requests faster than 100 ms apart are ignored")

	# Admin mode: an admin crafts any recipe free, locked or not, with no ingredients or station.
	DirAccess.make_dir_recursive_absolute(qd + "_admin")

	for file in DirAccess.get_files_at(qd + "_admin"):
		DirAccess.remove_absolute(qd + "_admin/" + file)

	var ad = make(qd + "_admin")
	ad.send_craft_queue = func(_p, _entries, _left_ms): pass
	ad.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	ad.peer_connected_hello(1, "adminkey0001")
	ad.admin_ok = func(_p): return true
	ad.action(1, Net.ACT_ADMIN_MODE, 1, 0, 0, Vector3.ZERO)   # off by default: switched on as in Esc > Admin
	ad._last_queue_act.clear()
	ad.action(1, Net.ACT_CRAFT_QUEUE, 18, 0, 1, CraftHand.at(ad, 1, 18))   # the iron pickaxe: not known, needs a forge and iron
	check(ad.craft_queue_of(1) == [[18, 1]], "an admin queues a locked recipe with nothing in the pack")

	for n in range(60):
		ad._craft_tick(0.25)

	check(ad.inventory_of(1).count_of(ad.table.number_of("iron_pickaxe")) == 1, "an admin's craft finishes without a station or ingredients")
	ad.admin_mode_on = func(_p): return false
	ad._last_queue_act.clear()
	ad.action(1, Net.ACT_CRAFT_QUEUE, 18, 0, 1, CraftHand.at(ad, 1, 18))
	check(ad.craft_queue_of(1).is_empty(), "with admin mode off the same craft is refused again")

	# Restart mid-craft keeps the progress; a refund into a pack at its carry limit drops the rest at the player's feet.
	DirAccess.make_dir_recursive_absolute(qd + "_full")

	for file in DirAccess.get_files_at(qd + "_full"):
		DirAccess.remove_absolute(qd + "_full/" + file)

	var rq = make(qd + "_full")
	rq.send_craft_queue = func(_p, _e, _l): pass
	rq.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	rq.peer_connected_hello(1, "queuekey0002")
	rq.report_position(1, Vector3(0.0, 10.0, 0.0))
	rq.give(1, fibre, 9)
	rq.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 3, CraftHand.at(rq, 1, 1))
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

	for k in range(5000):   # the pack grows (protocol 116): only its carry limit leaves no room
		if rq2._fit(1, rq2.inventory_of(1), fibre, 1) <= 0:
			break

		rq2.inventory_of(1).add(rq2.table.number_of("stone"), 1)

	rq2._last_queue_act.clear()
	rq2.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	var on_ground: int = 0

	for item_id in rq2._items:
		if rq2._items[item_id]["number"] == fibre:
			on_ground += int(rq2._items[item_id]["count"])

	check(rq2.craft_queue_of(1).is_empty() and on_ground == 6, "a refund into a pack at its carry limit lands at the player's feet (%d fibre)" % on_ground)
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
			var luck: int = [0, 50, 100][k]   # 0 to 100, 50 neutral (Dave 19 Nov 2026)
			hits[k] += 1 if Luck.chance(u, 0.5, luck, 0.04) else 0
			sums[k] += Luck.amount(u, 1, 3, luck, 0.04)

	check(hits[0] < hits[1] - 300 and hits[2] > hits[1] + 300 and absf(float(hits[1]) / 6000.0 - 0.5) < 0.02, "luck moves a 50 percent chance down and up and 50 is neutral (%s of 6000)" % str(hits))
	check(sums[0] < sums[1] and sums[1] < sums[2] and Luck.amount(0.0, 1, 3, 100, 0.04) == 1 and Luck.amount(0.999999, 1, 3, 0, 0.04) <= 3 and Luck.amount(0.999999, 1, 3, 250, 0.04) <= 3, "luck moves the average of a 1 to 3 yield and keeps it in range (%s)" % str(sums))
	check(not Luck.chance(0.99, 0.0, 100, 0.04) and Luck.chance(0.0, 1.0, 0, 0.04), "luck never makes the impossible possible or the certain doubtful")
	check(Luck.low(0.5, 150, 0.04) == Luck.low(0.5, 100, 0.04) and Luck.low(0.5, -40, 0.04) == Luck.low(0.5, 0, 0.04), "a luck outside 0 to 100 counts as the nearest end")

	# The 0 to 100 scale (Dave 19 Nov 2026, attributes.json): the bell-shaped creation roll and the conversion of old -10 to +10 values.
	var Attr = load("res://src/shared/attributes.gd")
	var acfg: Dictionary = Attr.load_config()
	var arng: RandomNumberGenerator = RandomNumberGenerator.new()
	arng.seed = 19
	var bands: Array = [0, 0, 0, 0, 0]
	var out_of_range: int = 0

	var npc_fit: Array = [101, -1]
	var player_fit: Array = [101, -1]

	for n in range(20000):
		var v: int = Attr.roll(arng, acfg["roll_bands"])
		out_of_range += 0 if v >= 0 and v <= 100 else 1
		bands[0 if v <= 19 else (1 if v <= 39 else (2 if v <= 60 else (3 if v <= 80 else 4)))] += 1

		if n < 2000:
			var pc: Dictionary = Attr.roll_character(arng, acfg, true)
			var npc: Dictionary = Attr.roll_character(arng, acfg, false)
			player_fit = [mini(player_fit[0], int(pc["fitness"])), maxi(player_fit[1], int(pc["fitness"]))]
			npc_fit = [mini(npc_fit[0], int(npc["fitness"])), maxi(npc_fit[1], int(npc["fitness"]))]
			out_of_range += 0 if pc.size() == 7 and pc.values().all(func(x): return int(x) >= 0 and int(x) <= 100) else 1

	var want: Array = [0.05, 0.20, 0.50, 0.20, 0.05]
	var close: bool = true

	for b in range(5):
		close = close and absf(float(bands[b]) / 20000.0 - float(want[b])) < 0.015

	check(out_of_range == 0 and close, "the roll stays in 0 to 100 and lands 5/20/50/20/5 percent in 0-19, 20-39, 40-60, 61-80, 81-100 (%s of 20000)" % str(bands))
	check(player_fit[0] >= 40 and player_fit[1] <= 60 and npc_fit[0] < 40 and npc_fit[1] > 60, "a player's fitness starts in the middle range (40 to 60), an NPC's anywhere (player %s, NPC %s)" % [str(player_fit), str(npc_fit)])
	check(Attr.roll(arng, []) == 50 and Attr.roll(arng, [{"from": 70, "to": 70, "weight": 1}, "bad"]) == 70, "no bands give an average 50; a broken band is skipped")
	check(Attr.from_old(-10) == 0 and Attr.from_old(0) == 50 and Attr.from_old(10) == 100 and Attr.from_old(-3) == 35 and Attr.from_old(40) == 100 and Attr.from_old("x") == 50, "an old -10 to +10 value moves to 0 to 100 (0 is 50), out-of-range and broken values are clamped")
	check(Attr.clamp_value(-7) == 0 and Attr.clamp_value(130) == 100 and Attr.clamp_value(64) == 64 and Attr.offset(50.0) == 0.0 and Attr.offset(100.0) == 10.0 and Attr.offset(0.0) == -10.0, "values are kept in 0 to 100 and 50 is neutral")
	var luck_dir: String = "user://test_server_items_luck"
	DirAccess.make_dir_recursive_absolute(luck_dir)

	for file in DirAccess.get_files_at(luck_dir):
		DirAccess.remove_absolute(luck_dir + "/" + file)

	var lk = make(luck_dir)
	lk.peer_connected_hello(3, "luckkey000003")
	check(lk.luck_of(3) == 50 and lk.fitness_of(3) == 50 and lk.attributes_of(3).values().all(func(x): return x == 50.0), "with rolling off (tools and tests) a new character is average in everything")
	lk.roll_new_characters = true   # as the game server sets it
	lk.peer_connected_hello(1, "luckkey000001")
	lk.peer_connected_hello(2, "luckkey000002")
	var rolled_row: Dictionary = lk._characters["luckkey000001"]
	check(lk.luck_of(1) >= 0 and lk.luck_of(1) <= 100 and lk.luck_of(99) == 50, "a character gets luck from 0 to 100 at first sight; an unknown peer is neutral (50)")
	check(lk.fitness_of(1) >= 40 and lk.fitness_of(1) <= 60 and ["strength", "memory", "dexterity", "perception", "charisma"].all(func(a): return rolled_row.has(a) and int(rolled_row[a]) >= 0 and int(rolled_row[a]) <= 100), "a new player character rolls every attribute, fitness in 40 to 60 (%s)" % str(rolled_row))
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
	lk2._characters["luckkey000001"]["luck"] = 50
	var agree: int = 0

	for n in range(200):
		agree += 1 if (plain.randf() < 0.3) == lk2.roll_chance(1, same, 0.3) else 0

	check(agree == 200, "with luck 50 a roll is exactly the plain random roll")
	lk2._luck_cfg["strength"] = 0.0
	lk2._characters["luckkey000001"]["luck"] = 100
	plain.seed = 4
	same.seed = 4
	agree = 0

	for n in range(200):
		agree += 1 if (plain.randf() < 0.3) == lk2.roll_chance(1, same, 0.3) else 0

	check(agree == 200, "strength 0 switches luck off")
	check(lk2.fate(1, "test", 1.0) and int(lk2.fate_counts["test"]) == 1, "the fate hook rolls and counts by kind")

	# Old saves (characters.json version 1, attributes -10 to +10) load converted to 0 to 100; out-of-range values are brought into range (Dave 19 Nov 2026).
	var scale_dir: String = "user://test_server_items_scale"
	DirAccess.make_dir_recursive_absolute(scale_dir)

	for file in DirAccess.get_files_at(scale_dir):
		DirAccess.remove_absolute(scale_dir + "/" + file)

	var old_file: FileAccess = FileAccess.open(scale_dir + "/characters.json", FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"version": 1, "players": {"scalekey00001": {"luck": -3, "fitness": 5, "train": 1.5, "charisma": -10}, "scalekey00002": {"luck": -14, "fitness": 22, "strength": 10}, "scalekey00003": {}}}))
	old_file.close()
	var sc1 = make(scale_dir)
	var r1: Dictionary = sc1._characters["scalekey00001"]
	var r2: Dictionary = sc1._characters["scalekey00002"]
	var r3: Dictionary = sc1._characters["scalekey00003"]
	check(int(r1["luck"]) == 35 and int(r1["fitness"]) == 75 and float(r1["train"]) == 7.5 and int(r1["charisma"]) == 0 and int(r1["strength"]) == 50, "an old save's attributes move to 0 to 100 (luck -3 is 35, fitness 5 is 75, training x5, a missing one is average) (%s)" % str(r1))
	check(int(r2["luck"]) == 0 and int(r2["fitness"]) == 100 and int(r2["strength"]) == 100, "an old save's out-of-range values are clamped into 0 to 100 (%s)" % str(r2))
	check(int(r3["luck"]) == 50 and int(r3["fitness"]) == sc1._fitness_default(), "an old row with no attributes is average, fitness its default")
	sc1._dirty = true
	sc1.save()
	sc1._finish_writer()
	check(int(JSON.parse_string(FileAccess.get_file_as_string(scale_dir + "/characters.json")).get("version", 0)) == 2, "the next save writes characters.json version 2")
	var sc2 = make(scale_dir)
	check(int(sc2._characters["scalekey00001"]["luck"]) == 35 and int(sc2._characters["scalekey00001"]["fitness"]) == 75 and float(sc2._characters["scalekey00001"]["train"]) == 7.5, "a version 2 save reads back unchanged (no second conversion)")
	var new_file: FileAccess = FileAccess.open(scale_dir + "/characters.json", FileAccess.WRITE)
	new_file.store_string(JSON.stringify({"version": 2, "players": {"scalekey00004": {"luck": -5, "fitness": 140, "perception": 300.0, "memory": "x"}}}))
	new_file.close()
	var sc3 = make(scale_dir)
	var r4: Dictionary = sc3._characters["scalekey00004"]
	check(int(r4["luck"]) == 0 and int(r4["fitness"]) == 100 and int(r4["perception"]) == 100 and int(r4["memory"]) == 50, "a new-scale save with values outside 0 to 100 loads clamped (%s)" % str(r4))
	sc3.peer_connected_hello(1, "scalekey00004")
	sc3.set_attribute(1, "charisma", 250)
	sc3.set_fitness(1, -20)
	check(int(sc3._characters["scalekey00004"]["charisma"]) == 100 and sc3.fitness_of(1) == 0 and sc3.attributes_of(1)["charisma"] == 100.0, "setting an attribute or fitness keeps it in 0 to 100")

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
	var ore_rocks: int = 0   # copper, tin and iron rocks by the stream (boulders.json ore_rocks, Dave 21 Nov 2026) are laid with the cell too, but they are not bank stones

	for bid in sc._items:
		var row: Dictionary = sc._items[bid]
		ore_rocks += 1 if row.has("scatter") and ((int(row["scatter"]) & (sc.ORE_KEY | sc.FIELD_KEY)) != 0 or str(row.get("boulder", {}).get("ore", "")) != "") else 0   # and the rocky ground's rounded river rocks (rock_fields), not bank stones either

	check(sc.world_item_count() - bank_before - ore_rocks <= 4 * (6 + int(bank_cfg["stones_max"]) + int(bank_cfg["sticks_max"])), "bank stones stay within the per-cell limit")

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
	check(float(sc._cooking["fuel"].get("driftwood", 0.0)) >= float(sc._cooking["fuel"]["stick"]) and sc._cooking["fuel_order"].has("driftwood"), "driftwood is fuel, as long as a stick")

	# Fall damage and refusal events (job 62).
	DirAccess.make_dir_recursive_absolute(qd + "_fall")

	for file in DirAccess.get_files_at(qd + "_fall"):
		DirAccess.remove_absolute(qd + "_fall/" + file)

	var fl = make(qd + "_fall")
	var rejects: Array = []
	fl.send_reject = func(_p, reason): rejects.append(reason)
	fl.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	fl.peer_connected_hello(1, "fallkey00001")
	fl.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
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
	fl.action(1, Net.ACT_MINE, HeldTool.slot_of(fl, "axe") + 1, 0, 0, Vector3(2.0, 10.0, 0.0))
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

	# Container rules as data (job 73): a woven chest takes stacks until its slots are full, whatever they weigh (Dave 19 Nov 2026), and full packs behave.
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
	bx.place_item(1, box_kit, Vector3(2.0, 10.0, 0.0), 0)
	var box_id: int = 0

	for k in bx._items:
		if bx._items[k].has("struct"):
			box_id = k

	bx.action(1, Net.ACT_CHEST_OPEN, box_id, 0, 0, Vector3.ZERO)
	var box = bx._chests[int(bx._items[box_id]["struct"]["uid"])]
	var in_pack: int = bx.inventory_of(1).count_of(box_stone)

	for slot_n in range(bx.inventory_of(1).slot_count):
		if bx.inventory_of(1).numbers[slot_n] == box_stone:
			bx.action(1, Net.ACT_CHEST_PUT, slot_n, box_id, 40, Vector3.ZERO)

	bx.action(1, Net.ACT_CHEST_PUT, bx.inventory_of(1).numbers.find(box_stone), box_id, 10, Vector3.ZERO)
	check(box.count_of(box_stone) == 50 and bx.inventory_of(1).count_of(box_stone) == in_pack - 50 and box_rejects.is_empty(), "a chest that is not full takes all 50 stones, never refused by weight (%d in the chest, rejects %s)" % [box.count_of(box_stone), str(box_rejects)])
	bx.give(1, box_stone, 500)
	var before_take: int = bx.inventory_of(1).count_of(box_stone)
	bx.action(1, Net.ACT_CHEST_TAKE, box.numbers.find(box_stone), box_id, 40, Vector3.ZERO)
	check(bx.inventory_of(1).count_of(box_stone) == before_take and box.count_of(box_stone) == 50, "a take into a pack at its weight cap moves nothing and loses nothing")

	# Skill hooks (job 70): factor 1.0 changes nothing; a stub skill of 2.0 doubles yield and halves craft time.
	DirAccess.make_dir_recursive_absolute(qd + "_skill")

	for file in DirAccess.get_files_at(qd + "_skill"):
		DirAccess.remove_absolute(qd + "_skill/" + file)

	var sk = make(qd + "_skill")
	sk.send_craft_queue = func(_p, _e, _l): pass
	sk.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sk.peer_connected_hello(1, "skillkey0001")
	sk.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
	check(sk.skill_factor(1, "craft") == 1.0 and sk.skill_factor(1, "no_such_action") == 1.0, "with no skill system every factor is 1.0")
	sk.skill_level = func(_peer, _skill): return 2.0
	check(sk.skill_factor(1, "craft") == 2.0 and sk.skill_factor(1, "no_such_action") == 1.0, "a skill level of 2 gives a factor of 2 for a listed action only")
	sk.give(1, sk.table.number_of("plant_fibre"), 9)
	sk.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 1, CraftHand.at(sk, 1, 1))

	for n in range(4 * 1 + 1):
		sk._craft_tick(0.25)

	check(sk.inventory_of(1).count_of(sk.table.number_of("twine")) == 1, "a skill of 2 makes the 2 s twine in 1 s")

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
	bo.set_fitness(1, 50)   # an average adult (50): on the game server a new player rolls fitness 40 to 60 (attributes.json), and fitness nudges fitness-weighted factors (tool care, jumping, crafting)
	bo.report_position(1, Vector3(5.0, 11.5, 5.0))
	bo.vitals_of(1)["weight"] = 5000.0   # a big body: the carry limit stays out of the stone counts below
	var big: int = bo._boulder_stones(1.0)
	check(big >= 860 and big <= 880, "a 1 m radius boulder makes about 870 stones at 0.85 height, 2600 kg/m3, 0.047 coming away as 0.5 kg stones (Dave 21 Nov 2026, BugsList 118: 3,200 from one rock was too many) (%d)" % big)
	check(bo._boulder_stones(0.3) >= 20 and bo._boulder_stones(0.3) <= 26 and bo._boulder_stones(1.2) >= 1450 and bo._boulder_stones(1.2) <= 1550, "stones go with the rock's volume: a 0.3 m one about 23, the biggest (1.2 m) about 1,500 (%d, %d)" % [bo._boulder_stones(0.3), bo._boulder_stones(1.2)])
	check(is_equal_approx(bo._boulder_per_kg(), 0.094), "0.094 stones of 0.5 kg per kg of plain rock (%f)" % bo._boulder_per_kg())
	# Ore rocks keep their amounts (Dave 21 Nov 2026: fewer stones from plain rocks only; copper and tin stay abundant).
	check(is_equal_approx(bo._boulder_per_kg(true), 1.4) and bo._boulder_stones(1.0, true) >= 12800 and bo._boulder_stones(1.0, true) <= 13100, "an ore rock still holds 1.4 stones per kg: about 12,960 at radius 1 (%d)" % bo._boulder_stones(1.0, true))
	var plain_row: Dictionary = {"radius": 1.0}
	var ore_row: Dictionary = {"radius": 1.0}
	bo._set_boulder_ore(plain_row, "", 76)
	bo._set_boulder_ore(ore_row, "iron", 75)
	check(int(plain_row["total"]) == bo._boulder_stones(1.0) and int(ore_row["total"]) == bo._boulder_stones(1.0, true), "a laid-out row's total is by its kind (%d plain, %d ore)" % [int(plain_row["total"]), int(ore_row["total"])])
	# A save from 19 Nov (one rate, 1.4 per kg, for every rock): a plain rock keeps its share, an ore rock its count.
	bo._load_boulders_left({"boulders": {"76": 10000, "75": 10000}, "boulder_per_kg": 1.4})
	check(bo._boulder_pending.size() == 2 and not bo._boulder_left.has(76), "saved at another rate: waits until the rock is laid out")
	check(bo._boulder_left_of(76, plain_row) == 671 and int(bo._boulder_left[76]) == 671 and not bo._boulder_pending.has(76), "a plain rock saved with 10,000 left at 1.4 per kg is 671 now (%d)" % int(bo._boulder_left.get(76, -1)))
	check(bo._boulder_left_of(75, ore_row) == 10000, "an ore rock saved with 10,000 left keeps 10,000 (%d)" % int(bo._boulder_left.get(75, -1)))
	bo._load_boulders_left({"boulders": {"77": 10}})
	check(bo._boulder_left_of(77, plain_row) == int(round(10.0 * bo._boulder_per_kg() / 0.04)), "a worked boulder in an older save (0.04 stones per kg) is scaled once to today's count (%d)" % int(bo._boulder_left[77]))
	bo._load_boulders_left({"boulders": {"74": 3}, "boulders_then": {"73": [100, 1.4, 1.4]}, "boulder_per_kg": 0.094, "ore_per_kg": 1.4})
	check(int(bo._boulder_left.get(74, -1)) == 3 and bo._boulder_pending.has(73), "a save at today's rates loads as it is; one not yet laid out keeps its old rates")
	var lime_row: Dictionary = {"radius": 1.0}
	bo._set_boulder_ore(lime_row, "limestone", 72)
	check(int(lime_row["total"]) == bo._boulder_stones(1.0) and str(lime_row.get("ore", "")) == "limestone", "a limestone rock is stone: the plain count (%d)" % int(lime_row["total"]))
	# A rock still waiting for its layout is saved with its old rates and loads the same way (no share lost across restarts).
	bo._dirty = true
	bo.save()
	var bo_again = make(bld)
	var waiting_rates: Array = bo_again._boulder_pending.get(73, [])
	check(waiting_rates.size() == 3 and int(waiting_rates[0]) == 100 and is_equal_approx(float(waiting_rates[1]), 1.4) and is_equal_approx(float(waiting_rates[2]), 1.4) and not bo_again._boulder_left.has(73), "a rock not yet laid out keeps its old rates through a save (%s)" % str(waiting_rates))
	check(int(bo_again._boulder_left.get(74, -1)) == 3 and bo_again._boulder_left_of(73, plain_row) == int(round(100.0 * 0.094 / 1.4)), "and is scaled when it is laid out (%d)" % int(bo_again._boulder_left.get(73, -1)))
	bo._boulder_pending.clear()
	bo._boulder_left.erase(73)
	bo._boulder_left.erase(74)
	bo._boulder_left.erase(75)
	bo._boulder_left.erase(76)
	bo._boulder_left.erase(77)
	bo._boulder_left.erase(78)
	bo._boulder_cfg["luck_extra"] = 0.0   # the exact-count checks below; luck's extra stone has its own check
	bo._boulder_cfg["flint"] = {}   # flint has its own test (test_flint); these checks count plain stones
	var small_total: int = bo._boulder_stones(0.6)   # about 190: enough for the blow counts below (36 stones)
	bo._items[900001] = {"number": 0, "count": small_total, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": bo.BOULDER_KEY | 7, "boulder": {"radius": 0.6, "yaw": 0.0, "total": small_total}}
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, 0, Vector3.ZERO)
	check(bo_rejects == [1] and int(bo._items[900001]["count"]) == small_total, "nothing in hand: refused (no tool), nothing taken (%s)" % str(bo_rejects))
	bo.action(1, Net.ACT_ADMIN_GIVE, bo.table.number_of("iron_pickaxe"), 0, 1, Vector3.ZERO)
	var stone_id: int = bo.table.number_of("stone")
	var pick_slot: int = bo.inventory_of(1).numbers.find(bo.table.number_of("iron_pickaxe"))

	for n in range(10):
		bo._last_hit.clear()
		bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, pick_slot + 1, Vector3.ZERO)   # count: the held pack slot + 1 (protocol 115)

	check(bo.inventory_of(1).count_of(stone_id) == 30 and int(bo._items[900001]["count"]) == small_total - 30, "an iron pick takes three stones a blow (boulders.json tools: stone 1, bronze 2, iron 3, steel 4): 10 blows, 30 stones (%d stones, %d left)" % [bo.inventory_of(1).count_of(stone_id), int(bo._items[900001]["count"])])
	check(int(bo.inventory_of(1).wear[pick_slot]) == 10, "every blow wears the pick one (%d)" % int(bo.inventory_of(1).wear[pick_slot]))
	# TEST-013 (Dave 12 Nov 2026): the tool IN HAND does the work, not the best one on the hotbar. With the iron pick still on the hotbar,
	# a held stone axe takes half a stone a blow (half a stone pick's one; Dave 12 Nov 2026) and wears five a blow (drops.json tool_wear axe rock: it dulls fast on stone).
	bo.action(1, Net.ACT_ADMIN_GIVE, bo.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	var boulder_axe_slot: int = bo.inventory_of(1).numbers.find(bo.table.number_of("stone_axe"))

	for n in range(12):
		bo._last_hit.clear()
		bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, boulder_axe_slot + 1, Vector3.ZERO)

	check(bo.inventory_of(1).count_of(stone_id) == 36, "a held stone axe takes a stone every two blows even with an iron pick on the hotbar: 12 blows, 6 stones (%d)" % (bo.inventory_of(1).count_of(stone_id) - 30))
	check(int(bo.inventory_of(1).wear[boulder_axe_slot]) == 60 and int(bo.inventory_of(1).wear[pick_slot]) == 10, "the held axe wears five a blow on rock and the pick on the hotbar not at all (axe %d, pick %d)" % [int(bo.inventory_of(1).wear[boulder_axe_slot]), int(bo.inventory_of(1).wear[pick_slot])])
	var left_before: int = int(bo._items[900001]["count"])
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, bo.inventory_of(1).numbers.find(stone_id) + 1, Vector3.ZERO)
	check(bo_rejects[-1] == 1 and int(bo._items[900001]["count"]) == left_before, "a stone in hand is no tool: refused, nothing taken")
	var spent_axe: Dictionary = bo.inventory_of(1).take_from_slot(boulder_axe_slot, 1)   # the axe goes to the backpack: off the hotbar it cannot be swung
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, boulder_axe_slot + 1, Vector3.ZERO)
	check(bo_rejects[-1] == 1 and int(bo._items[900001]["count"]) == left_before and not spent_axe.is_empty(), "an empty slot in hand: refused")
	bo.report_position(1, Vector3(40.0, 22.0, 40.0))
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, pick_slot + 1, Vector3.ZERO)
	check(bo_rejects[-1] == 0, "too far away: refused")
	bo.report_position(1, Vector3(5.0, 11.5, 5.0))
	bo._items[900001]["count"] = 1
	bo._items[900001]["boulder"]["progress"] = 0.0
	bo._last_hit.clear()
	bo.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, pick_slot + 1, Vector3.ZERO)
	check(not bo._items.has(900001) and int(bo._boulder_left[bo.BOULDER_KEY | 7]) == 0, "the last stone takes the boulder with it")
	bo.action(1, Net.ACT_PICKUP, 900001, 0, 0, Vector3.ZERO)
	check(bo.inventory_of(1).count_of(0) == 0, "a boulder cannot be picked up like a stone")
	# Luck: a lucky character gets more of the occasional double stone than an unlucky one.
	bo._boulder_cfg["luck_extra"] = 0.2
	var extras: Array = []

	for fortune in [100, 0]:
		bo._characters["boulderkey01"]["luck"] = fortune
		bo.action(1, Net.ACT_ADMIN_GIVE, bo.table.number_of("iron_pickaxe"), 0, 1, Vector3.ZERO)
		var luck_pick: int = bo.inventory_of(1).numbers.find(bo.table.number_of("iron_pickaxe"))
		bo._items[900002] = {"number": 0, "count": 3000, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": bo.BOULDER_KEY | 9, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 3000}}
		var taken: int = 0

		for n in range(400):
			bo._last_hit.clear()
			var before_count: int = int(bo._items[900002]["count"])
			bo.action(1, Net.ACT_HIT, 900002, Net.HIT_BOULDER, luck_pick + 1, Vector3.ZERO)
			taken += before_count - int(bo._items[900002]["count"])

			# keep the pack light so the weight limit does not interfere
			for slot in range(bo.inventory_of(1).slot_count):
				if bo.inventory_of(1).numbers[slot] == bo.table.number_of("stone"):
					bo.inventory_of(1).counts[slot] = 0
					bo.inventory_of(1).numbers[slot] = 0

		extras.append(taken - 1200)   # an iron pick: 3 stones a blow
		bo._items.erase(900002)
		bo.inventory_of(1).numbers[bo.inventory_of(1).numbers.find(bo.table.number_of("iron_pickaxe"))] = 0

	check(extras[0] > extras[1] and extras[1] >= 0, "luck nudges the double stones: luck 100 got %d extra, luck 0 got %d in 400 blows" % [extras[0], extras[1]])
	bo._boulder_cfg["luck_extra"] = 0.0
	# A full pack is never refused (Dave 19 Nov 2026, boulders PLAN.md 5): the stones go into one pile behind the miner, away from the rock,
	# the same pile however the miner moves round it.
	bo.action(1, Net.ACT_ADMIN_GIVE, bo.table.number_of("iron_pickaxe"), 0, 1, Vector3.ZERO)
	var full_pick: int = bo.inventory_of(1).numbers.find(bo.table.number_of("iron_pickaxe"))
	bo.vitals_of(1)["weight"] = 1.0   # a tiny body: nothing more fits in the pack
	bo._items[900003] = {"number": 0, "count": 500, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": bo.BOULDER_KEY | 10, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 500}}
	var full_rejects: int = bo_rejects.size()
	var bo_said: Array = []
	bo.send_notice = func(_p, text): bo_said.append(text)

	for n in range(6):
		bo._last_hit.clear()
		bo.report_position(1, Vector3(5.0 + 0.3 * float(n % 2), 11.5, 5.0))   # stepping about a little
		bo.action(1, Net.ACT_HIT, 900003, Net.HIT_BOULDER, full_pick + 1, Vector3.ZERO)

	var behind_piles: Array = []

	for k in bo._items:
		if int(bo._items[k]["number"]) == stone_id and not bo._items[k].has("scatter"):
			behind_piles.append(bo._items[k])

	check(bo_rejects.size() == full_rejects and int(bo._items[900003]["count"]) == 500 - 18, "a full pack is not refused: 6 blows of an iron pick still take 18 stones (%d left)" % int(bo._items[900003]["count"]))
	check(behind_piles.size() == 1 and int(behind_piles[0]["count"]) == 18 and behind_piles[0]["pos"].z < 5.0, "and they lie in one pile behind the miner, away from the rock (%s)" % str(behind_piles))
	check(bo_said.count("Too heavy to carry: what you break off piles up behind you.") == 1, "the miner is told once that the pieces pile up behind them (%s)" % str(bo_said))
	bo.send_notice = Callable()
	bo._items.erase(900003)
	bo.clear_dropped(Vector3.ZERO, 1.0e7)
	bo.vitals_of(1)["weight"] = 5000.0
	bo.inventory_of(1).numbers[full_pick] = 0
	# A boulder dug under comes down into the hole (Dave 19 Nov 2026, boulders PLAN.md stage 1), and a cave boulder is left alone.
	var dug_y: Array = [11.5]
	bo.floor_below = func(_p: Vector3) -> float: return dug_y[0]
	bo._items[900004] = {"number": 0, "count": 50, "pos": Vector3(30.0, 11.5, 30.0), "left": 1.0e9, "scatter": bo.BOULDER_KEY | 11, "boulder": {"radius": 0.6, "yaw": 0.0, "total": 50}}
	bo._items[900005] = {"number": 0, "count": 50, "pos": Vector3(30.0, 11.5, 31.0), "left": 1.0e9, "scatter": bo.CAVE_KEY | 1, "boulder": {"radius": 0.6, "yaw": 0.0, "total": 50}}
	dug_y[0] = 10.0
	bo.settle_loose_near(Vector3(30.0, 11.0, 30.0), 1.0)
	check(is_equal_approx(bo._items[900004]["pos"].y, 10.0) and is_equal_approx(bo._items[900005]["pos"].y, 11.5), "a boulder dug under settles into the hole; a cave boulder stays")
	bo._items.erase(900004)
	bo._items.erase(900005)
	bo.floor_below = Callable()
	# Layout: on a slope the cells hold boulders, the same ones every time, none on flat ground.
	var laid: Array = []

	for cell_x in range(0, 6):
		for cell_z in range(0, 4):
			bo._lay_out_boulders(Vector2i(cell_x, cell_z), 32.0)

	for bid in bo._items:
		if bo._items[bid].has("boulder"):
			laid.append([bid, bo._items[bid]["pos"], int(bo._items[bid]["count"])])

	check(laid.size() >= 3, "a slope is dotted with boulders (%d in 24 cells)" % laid.size())
	var replay = make(bld + "_replay")
	replay.ground_height = bo.ground_height
	var replay_count: int = 0

	for cell_x in range(0, 6):
		for cell_z in range(0, 4):
			replay._lay_out_boulders(Vector2i(cell_x, cell_z), 32.0)

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

	# The flora cover does not move boulders or bank stones (Sonny, 10 Nov 2026): cover_at reads 0 until a worker builds the flora chunk, and a
	# stick's spot takes more tries under open sky. The same cells laid out under open sky and under trees keep every boulder and bank stone,
	# with the same keys in the same places; only the sticks may move.
	var by_cover: Array = []
	var sticks_by_cover: Array = []

	for cover in [0.0, 1.0]:
		var cdir: String = bld + "_cover_%d" % int(cover)
		DirAccess.make_dir_recursive_absolute(cdir)

		for file in DirAccess.get_files_at(cdir):
			DirAccess.remove_absolute(cdir + "/" + file)

		var lay = make(cdir)
		lay.ground_height = func(x, _z): return 10.0 + x * 0.3
		lay.water_near = func(pos, reach): return pos.x + reach >= 100.0 and pos.x - reach <= 104.0
		lay.cover_at = func(_p): return cover
		var cover_cfg: Dictionary = lay._drops.get("ground_scatter", {})

		for cz in range(1, 9):
			lay._lay_out_cell(Vector2i(3, cz), 32.0, cover_cfg)

		var kept: Array = []
		var stick_spots: Array = []

		for lid in lay._items:
			var row: Array = [int(lay._items[lid]["scatter"]), lay._items[lid]["pos"], int(lay._items[lid]["number"])]

			if int(lay._items[lid]["number"]) == lay.table.number_of("stick"):
				stick_spots.append(row)
			else:
				kept.append(row)

		kept.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		stick_spots.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
		by_cover.append(kept)
		sticks_by_cover.append(stick_spots)

	var cover_boulders: int = 0

	for row in by_cover[0]:
		cover_boulders += 1 if (int(row[0]) & bo.BOULDER_KEY) != 0 else 0

	check(cover_boulders > 0 and by_cover[0].size() > cover_boulders, "the cover test lays out boulders and loose or bank stones (%d boulders of %d)" % [cover_boulders, by_cover[0].size()])
	check(str(by_cover[0]) == str(by_cover[1]), "boulders and bank stones lie where they did whether the flora cover is built or not")
	check(not sticks_by_cover[0].is_empty(), "the cover test has sticks drawn before the boulders (%d)" % sticks_by_cover[0].size())

	# A recipe with six ingredients works end to end (Dave: the more ingredients the better the item; the limit is one constant).
	var qd6: String = qd + "_six"
	DirAccess.make_dir_recursive_absolute(qd6)

	for file6 in DirAccess.get_files_at(qd6):
		DirAccess.remove_absolute(qd6 + "/" + file6)

	var sx6 = make(qd6)
	sx6.send_craft_queue = func(_p, _e, _l): pass
	sx6.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	sx6.peer_connected_hello(1, "sixkey000001")
	var cord6: int = sx6.table.number_of("twine")
	var six_file: String = qd6 + "/six.json"
	var six: FileAccess = FileAccess.open(six_file, FileAccess.WRITE)
	six.store_string(JSON.stringify({"recipes": {"six_test": {"number": 900, "name": "Six test", "needs": [["stone", 1], ["stick", 1], ["plant_fibre", 1], ["bark", 1], ["leaves", 1], ["firewood", 1]], "gives": ["twine", 1], "craft_s": 1.0, "known": true}}}))
	six.close()
	sx6.recipes.load_file(six_file, sx6.table)
	check(sx6.recipes.recipe(900).get("needs", []).size() == 6, "a six-ingredient recipe loads")

	for id6 in ["stone", "stick", "plant_fibre", "bark", "leaves", "firewood"]:
		sx6.give(1, sx6.table.number_of(id6), 2)

	var cord6b: int = sx6.inventory_of(1).count_of(cord6)
	sx6._last_queue_act.clear()
	sx6.action(1, Net.ACT_CRAFT_QUEUE, 900, 0, 1, CraftHand.at(sx6, 1, 900))
	check(sx6.inventory_of(1).count_of(sx6.table.number_of("bark")) == 1 and sx6.inventory_of(1).count_of(sx6.table.number_of("firewood")) == 1, "queueing it takes all six ingredients")

	for n in 40:
		sx6._craft_tick(0.25)

	check(sx6.inventory_of(1).count_of(cord6) > cord6b, "the six-ingredient craft completes")

	# The spawn boost never lowers a cell's own roll (Dino round 7: a sloped cell rolling 4 stones was cut to the cap of 2 near the spawn).
	check(ItemsScript.boosted(4, 2, 2) == 4, "a cell rolling more than the cap keeps its roll")
	check(ItemsScript.boosted(0, 2, 2) == 2 and ItemsScript.boosted(1, 2, 2) == 2, "a flat cell is lifted up to the cap")
	check(ItemsScript.boosted(0, 1, 4) == 1, "the boost adds only what it rolled")

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

	check(near_stones >= 8 and near_sticks >= 12, "within 48 m of spawn lie a campfire kit's worth (%d stones, %d sticks)" % [near_stones, near_sticks])
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

	# Zone (protocol 76): the biome under a player goes to the client at login, at once after a teleport or respawn, and after a change that reads the same
	# twice running (about 4 s); nothing is sent while it stays the same. Bytes and sample cost are printed.
	DirAccess.make_dir_recursive_absolute("user://test_server_items_zone")
	DirAccess.make_dir_recursive_absolute("user://test_server_items_zone2")
	var zi = make("user://test_server_items_zone")
	var zone_sent: Array = []
	var zone_now: Array = [0]
	var biome_here: Array = [8]
	zi.send_zone = func(peer, biome_id): zone_sent.append([peer, biome_id])
	zi.zone_at = func(_pos): return biome_here[0]
	zi.zone_clock = func(): return zone_now[0]
	zi.peer_connected_hello(1, "zonepeer001")
	zi.report_position(1, Vector3(100.0, 5.0, 100.0))
	check(zone_sent == [[1, 8]], "login: the biome is sent on the first report (%s)" % str(zone_sent))
	zone_now[0] = 1000
	zi.report_position(1, Vector3(101.0, 5.0, 100.0))
	zone_now[0] = 2000
	zi.report_position(1, Vector3(102.0, 5.0, 100.0))
	check(zone_sent.size() == 1, "standing in the same biome sends nothing more")
	biome_here[0] = 13
	zone_now[0] = 4000
	zi.report_position(1, Vector3(103.0, 5.0, 100.0))
	check(zone_sent.size() == 1, "a first read of a new biome is held back (no flicker on a border)")
	biome_here[0] = 8
	zone_now[0] = 6000
	zi.report_position(1, Vector3(104.0, 5.0, 100.0))
	biome_here[0] = 13
	zone_now[0] = 8000
	zi.report_position(1, Vector3(105.0, 5.0, 100.0))
	check(zone_sent.size() == 1, "stepping back and forth over a border sends nothing")
	zone_now[0] = 10000
	zi.report_position(1, Vector3(106.0, 5.0, 100.0))
	check(zone_sent.size() == 2 and zone_sent[1] == [1, 13], "the same new biome read twice running is sent (%s)" % str(zone_sent))
	biome_here[0] = 3
	zone_now[0] = 12000
	zi.report_position(1, Vector3(5000.0, 5.0, 100.0))
	check(zone_sent.size() == 3 and zone_sent[2] == [1, 3], "a teleport or respawn is sent at once")
	zi.peer_left(1)
	zi.peer_connected_hello(1, "zonepeer001")
	zone_now[0] = 14000
	zi.report_position(1, Vector3(5000.0, 5.0, 100.0))
	check(zone_sent.size() == 4 and zone_sent[3] == [1, 3], "a returning player gets the zone again")
	zone_now[0] = 14500
	zi.report_position(1, Vector3(5001.0, 5.0, 100.0))
	check(zi.zone_samples == 8 and zone_sent.size() == 4, "reports closer than 2 s apart read nothing")
	biome_here[0] = -1
	zone_now[0] = 17000
	zi.report_position(1, Vector3(5002.0, 5.0, 100.0))
	check(zone_sent.size() == 4, "an unknown biome (-1) sends nothing")
	# A tile not in memory yet (BugsList 108): the check never reads it on the tick, and looks again on the next 2 s check once it is in.
	var tile_in: Array = [false]
	var zone_reads: Array = [0]
	zi.ground_ready = func(_x, _z): return tile_in[0]
	zi.zone_at = func(_pos):
		zone_reads[0] += 1
		return 21
	zone_now[0] = 20000
	zi.report_position(1, Vector3(9000.0, 5.0, 100.0))
	check(zone_reads[0] == 0 and zone_sent.size() == 4, "an unread tile: no zone read and nothing sent (%d reads)" % zone_reads[0])
	tile_in[0] = true
	zone_now[0] = 20500
	zi.report_position(1, Vector3(9001.0, 5.0, 100.0))
	check(zone_reads[0] == 1 and zone_sent.size() == 5 and zone_sent[4] == [1, 21], "once the tile is in, the next report reads it (no 2 s wait after a skip) and the teleport sends it (%s)" % str(zone_sent))
	# The snow check: an unread tile reads no ground, keeps the last cell's answer (not snow before any), and reads once the tile is in.
	var ground_reads: Array = [0]
	zi.ground_material = func(_x, _z):
		ground_reads[0] += 1
		return "loam"
	tile_in[0] = false
	check(not zi._on_snow(7, Vector3(10.5, 5.0, 10.5)) and ground_reads[0] == 0, "an unread tile: no ground read, not snow")
	tile_in[0] = true
	check(not zi._on_snow(7, Vector3(10.5, 5.0, 10.5)) and ground_reads[0] == 1, "once in, the cell is read once")
	# One minute of a player walking over a border back and forth every 5 s: messages and bytes (a zone call is a reliable rpc with one int, about 12 bytes with its header).
	var walker = make("user://test_server_items_zone2")
	var walker_sent: Array = []
	var walker_now: Array = [0]
	var walker_biome: Array = [8]
	walker.send_zone = func(peer, biome_id): walker_sent.append([peer, biome_id])
	walker.zone_at = func(_pos): return walker_biome[0]
	walker.zone_clock = func(): return walker_now[0]
	walker.peer_connected_hello(2, "zonepeer002")

	for second in range(60):
		walker_now[0] = second * 1000
		walker_biome[0] = 8 if floori(float(second) / 10.0) % 2 == 0 else 13
		walker.report_position(2, Vector3(float(second) * 3.0, 5.0, 0.0))

	print("zone: 60 s of a player crossing a border every 10 s: %d messages (about %d bytes per minute), %d lookups, %.1f microseconds each" % [walker_sent.size(), walker_sent.size() * 12, walker.zone_samples, float(walker.zone_usec) / maxf(float(walker.zone_samples), 1.0)])
	check(walker_sent.size() <= 7 and walker.zone_samples <= 31, "a minute costs a handful of messages and at most one lookup per 2 s (%d messages, %d lookups)" % [walker_sent.size(), walker.zone_samples])

	# Vent anchor (protocol 77): sent at login when a vent is in range, then only when the nearest vent changes; nothing for a player with no vent near.
	DirAccess.make_dir_recursive_absolute("user://test_server_items_vent")
	var vi = make("user://test_server_items_vent")
	var vent_sent: Array = []
	var vent_now: Array = [0]
	var vent_here: Array = [Vector3.INF]
	vi.send_zone = func(_peer, _biome_id): pass
	vi.zone_at = func(_pos): return 8
	vi.zone_clock = func(): return vent_now[0]
	vi.send_vent = func(peer, at): vent_sent.append([peer, at])
	vi.vent_near = func(_pos): return vent_here[0]
	vi.peer_connected_hello(1, "ventpeer0001")
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent.is_empty(), "no vent in range: nothing is sent at login (%s)" % str(vent_sent))
	vent_now[0] = 2000
	vent_here[0] = Vector3(900.0, 300.0, 100.0)
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent == [[1, Vector3(900.0, 300.0, 100.0)]], "a vent comes in range: its anchor is sent (%s)" % str(vent_sent))
	vent_now[0] = 4000
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent.size() == 1, "the same vent sends nothing more")
	vent_now[0] = 5000
	vent_here[0] = Vector3(-700.0, 250.0, 0.0)
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent.size() == 1, "reads closer than 2 s apart look at nothing")
	vent_now[0] = 6500
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent.size() == 2 and vent_sent[1][1] == Vector3(-700.0, 250.0, 0.0), "a different nearest vent is sent")
	vent_now[0] = 9000
	vent_here[0] = Vector3.INF
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent.size() == 3 and not (vent_sent[2][1] as Vector3).is_finite(), "walking out of range sends INF (the client drops the bed)")
	vent_now[0] = 11500
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent.size() == 3, "still none: nothing more")
	vi.peer_connected_hello(1, "ventpeer0001")
	vent_now[0] = 14000
	vent_here[0] = Vector3(-700.0, 250.0, 0.0)
	vi.report_position(1, Vector3(0.0, 5.0, 0.0))
	check(vent_sent.size() == 4, "a returning player gets the vent again")

	# Bow, arrows and quiver (recipes 170-173): arrows and the quiver by hand, the bow only at the wood carving station (W-8)
	var bw_dir: String = "user://test_server_items_bow"
	DirAccess.make_dir_recursive_absolute(bw_dir)

	for file in DirAccess.get_files_at(bw_dir):
		DirAccess.remove_absolute(bw_dir + "/" + file)

	var bw = make(bw_dir)
	bw.send_craft_queue = func(_p, _e, _l): pass
	bw.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	bw.peer_connected_hello(1, "bowitemskey1")
	var bw_rec: Dictionary = {}

	for rn in bw.recipes.numbers():
		bw_rec[bw.recipes.recipe(rn)["id"]] = bw.recipes.recipe(rn)

	for rid in ["wooden_bow", "wooden_arrow", "stone_arrow", "quiver"]:
		check(bw_rec.has(rid) and bool(bw_rec[rid].get("known", false)), "%s is a recipe known from the start" % rid)

	check(int(bw.table.entry("wooden_arrow").get("damage", 0)) == 5 and str(bw.table.entry("stone_arrow").get("tip", "")) == "stone", "arrows carry damage and tip")
	bw.give(1, bw.table.number_of("stick"), 10)
	bw.give(1, bw.table.number_of("feather"), 10)
	bw.give(1, bw.table.number_of("stone"), 4)
	bw.give(1, bw.table.number_of("twine"), 10)
	bw.give(1, bw.table.number_of("hide"), 2)
	bw.give(1, bw.table.number_of("thread"), 2)   # needle work takes Thread, not Twine (master s3.4, Mission 001 phase 2b)
	bw.give(1, bw.table.number_of("sewing_needle"), 1)   # sewn things keep a Bone - Needle (item system, 10 Nov 2026); it stays for the hood below
	bw.give(1, bw.table.number_of("stone_knife"), 1)   # the knife in hand, so the refusal below is the missing station, not the missing knife (W-32)
	bw._last_queue_act.clear()
	bw.action(1, Net.ACT_CRAFT_QUEUE, int(bw_rec["wooden_bow"]["number"]), 0, 1, CraftHand.at(bw, 1, int(bw_rec["wooden_bow"]["number"])))
	check(bw.craft_queue_of(1).is_empty(), "the bow is refused away from a carving station (W-8)")

	for rid in ["wooden_arrow", "stone_arrow", "quiver"]:
		bw._last_queue_act.clear()
		bw.action(1, Net.ACT_CRAFT_QUEUE, int(bw_rec[rid]["number"]), 0, 1, CraftHand.at(bw, 1, int(bw_rec[rid]["number"])))

		for n in 80:
			bw._craft_tick(0.25)

	check(bw.inventory_of(1).count_of(bw.table.number_of("wooden_arrow")) == 4, "wooden arrows come four at a time by hand")
	check(bw.inventory_of(1).count_of(bw.table.number_of("stone_arrow")) == 4, "stone arrows come four at a time by hand")
	check(bw.inventory_of(1).count_of(bw.table.number_of("quiver")) == 1, "a quiver by hand")
	bw.give(1, bw.table.number_of("twine"), 3)
	bw.give(1, bw.table.number_of("stick"), 2)
	bw._last_queue_act.clear()
	bw.action(1, Net.ACT_CRAFT_QUEUE, int(bw.recipes.recipe(177)["number"]), 0, 1, CraftHand.at(bw, 1, int(bw.recipes.recipe(177)["number"])))

	for n in 40:
		bw._craft_tick(0.25)

	check(str(bw.recipes.recipe(177)["id"]) == "snare" and bool(bw.recipes.recipe(177).get("known", false)) and bw.inventory_of(1).count_of(bw.table.number_of("snare")) == 1, "a snare by hand from 3 twine and 2 sticks")
	for rid in ["hide_cloak", "hide_boots", "hide_hood", "hide_mittens", "hide_trousers", "simple_backpack"]:
		check(bw_rec.has(rid) and bool(bw.recipes.recipe(int(bw_rec[rid]["number"])).get("known", false)) and str(bw.recipes.recipe(int(bw_rec[rid]["number"])).get("station", "")) == "" and not bool(bw.table.entry(rid).get("future", false)), "%s is live, known from the start and made by hand" % rid)

	bw.give(1, bw.table.number_of("hide"), 1)
	bw.give(1, bw.table.number_of("thread"), 1)
	bw._last_queue_act.clear()
	bw.action(1, Net.ACT_CRAFT_QUEUE, int(bw_rec["hide_hood"]["number"]), 0, 1, CraftHand.at(bw, 1, int(bw_rec["hide_hood"]["number"])))

	for n in 40:
		bw._craft_tick(0.25)

	check(bw.inventory_of(1).count_of(bw.table.number_of("hide_hood")) == 1, "a hide hood by hand from a hide and thread")

	# Animal searches by grid (finding 8): before any sync every item is looked at; after one, the sync's cells round the point and anything made
	# since; a fox reads the piece it is after by id.
	DirAccess.make_dir_recursive_absolute("user://test_server_items_near")

	for file in DirAccess.get_files_at("user://test_server_items_near"):
		DirAccess.remove_absolute("user://test_server_items_near/" + file)

	var near_items = make("user://test_server_items_near")
	var near_forage: int = near_items.table.number_of("roast_forage")
	var food_a: int = near_items._next_id
	near_items._items[food_a] = {"number": near_forage, "count": 3, "pos": Vector3(1000.0, 5.0, 1000.0), "left": 1.0e9}
	near_items._next_id += 1
	check(near_items.loose_food_near(Vector3(1010.0, 5.0, 1000.0), 30.0).size() == 1, "before any sync, loose food is found")
	near_items._sync_world_items()
	var food_b: int = near_items._next_id
	near_items._items[food_b] = {"number": near_forage, "count": 1, "pos": Vector3(1205.0, 5.0, 1000.0), "left": 1.0e9}
	near_items._next_id += 1
	var near_found: Array = near_items.loose_food_near(Vector3(1190.0, 5.0, 1000.0), 30.0)
	check(near_found.size() == 1 and int(near_found[0][0]) == food_b, "food dropped since the last sync is found, far food is not (%s)" % str(near_found))
	near_items._sync_world_items()
	near_found = near_items.loose_food_near(Vector3(1190.0, 5.0, 1000.0), 30.0)
	check(near_found.size() == 1 and int(near_found[0][0]) == food_b, "after the next sync it is found from the grid, in the next cell over (%s)" % str(near_found))
	check(near_items.stealable_near(Vector3(1001.0, 5.0, 1000.0), 5.0).size() == 1 and near_items.stealable_near(Vector3(1050.0, 5.0, 1000.0), 5.0).is_empty(), "a goblin finds the loose stack within its reach only")
	check(near_items.loose_food_pos(food_a) == Vector3(1000.0, 5.0, 1000.0) and near_items.loose_food_pos(999999) == null, "a fox reads its food by id")
	near_items.take_loose(food_a)
	check(near_items.loose_food_pos(food_a) == null and near_items.loose_food_near(Vector3(1000.0, 5.0, 1000.0), 5.0).is_empty(), "food taken is gone, though the grid still files its id")

	print("server item tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
