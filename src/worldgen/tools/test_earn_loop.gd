extends SceneTree

# The first-day money loop (Sal, 2 Nov 2026), on the real server code: a new player picks and sells stones in lots at Hob, earns about a
# poor day's wage (Dave: barely a meal and a bed), buys a meal and a rough bed from the same stall, then PLACES the bed. Fails when any link
# is impossible: nothing to buy a bed with, no bed on the shelf, the day pays too much, or the bought bed will not stand.
#   godot --headless --path . --script res://src/worldgen/tools/test_earn_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_earn_loop"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "earnloopkey01")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._characters["earnloopkey01"]["luck"] = 0
	items.set_attribute(1, "charisma", 0)
	var npcs := {"npcs": {"hob": {"dormant": false, "placed": true, "pos": Vector3(1.0, 10.0, 0.0)}}}
	var trade = TradeScript.new()
	trade.items = items
	trade.npcs = npcs
	trade.setup(dir)
	var shop: Array = []
	trade.now = func(): return 1000.0
	trade.game_seconds = func(): return 0.0
	trade.send_shop = func(_peer, _npc, _title, ids, _pay, _got, _buys, _tired_ids, _tired, _stock, _supply, _till): shop.assign(Array(ids))
	check(trade.open(1, "hob"), "Hob's stall opens")
	var stone: int = items.table.number_of("stone")
	var start: int = items.coins_of(1)

	# One day of picking: stones carried to Hob in 30-stone lots (a lot weighs 30 kg, inside the free carry), 1 copper a lot.
	var lots: int = 48

	for n in lots:
		items.give_to(1, "stone", 30)
		var slot: int = items.inventory_of(1).numbers.find(stone)
		trade.deal(1, "hob", 1, slot, 30)

	var wage: int = items.coins_of(1) - start
	check(wage >= 40 and wage <= 60, "a long day of picking pays a poor wage, about 48 copper (%d)" % wage)
	check(items.count_for(1, "stone") == 0, "every whole lot sold, nothing left over")

	# The same wage buys a meal and a place to sleep, and no more.
	var meal_i: int = shop.find("roast_forage")
	var bed_i: int = shop.find("rough_bed_kit")
	check(meal_i >= 0 and bed_i >= 0, "Hob sells a meal and a rough bed (%s)" % str(shop))
	var coins_before: int = items.coins_of(1)
	var bed_said: String = trade.deal(1, "hob", 0, bed_i, 1)
	var meal_said: String = trade.deal(1, "hob", 0, meal_i, 1)
	check(items.count_for(1, "rough_bed_kit") == 1 and items.count_for(1, "roast_forage") == 1, "a day's wage buys one bed and one meal (%s / %s)" % [bed_said, meal_said])
	var left: int = items.coins_of(1)
	check(left < 15, "and not much more than that (%d copper left of %d)" % [left, coins_before])

	# The bought bed stands.
	var kit: int = items.table.number_of("rough_bed_kit")
	var placed_before: int = items.world_item_count()
	items.report_position(1, Vector3(200.0, 10.0, 198.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(kit), 0, 0, Vector3(200.0, 10.0, 200.0))
	check(items.count_for(1, "rough_bed_kit") == 0, "the bought bed is placed out of the pack")
	check(items.world_item_count() > placed_before, "a bed stands in the world")
	items._finish_writer()
	print("test_earn_loop: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
