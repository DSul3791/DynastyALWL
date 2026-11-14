extends SceneTree

# Hob's daily wanted order (Sal, 3 Nov 2026; Dave QA sal-wanted-orders: one order a day, a poor wage), on the real server code: he says what
# he wants, takes it and pays once, refuses a second fill the same game day, and has a new order the next day.
#   godot --headless --path . --script res://src/worldgen/tools/test_wanted_order.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")

var failures: int = 0
var game_s: float = 100.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func give_order(items, order: Dictionary) -> void:
	for need in order["needs"]:
		items.give_to(1, str(need[0]), int(need[1]))


func _init() -> void:
	var dir: String = "user://test_wanted_order"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true   # no goals here: the order goal's own 3 copper would land inside the fill this test measures; test_goals covers goals (protocol 119 lifted the `after` lock)
	items.peer_connected_hello(1, "wantedkey0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var trade = TradeScript.new()
	trade.items = items
	trade.npcs = {"npcs": {"hob": {"dormant": false, "placed": true, "pos": Vector3(1.0, 10.0, 0.0)}}}
	trade.setup(dir)
	trade.now = func(): return 1000.0
	trade.game_seconds = func(): return game_s

	var order: Dictionary = trade.order_of_day("hob")
	check(not order.is_empty(), "Hob has an order today")

	for need in order.get("needs", []):
		check(items.table.number_of(str(need[0])) > 0, "the order asks for a real item (%s)" % str(need[0]))

	var pay: int = int(order.get("pay", 0))
	check(pay >= 5 and pay <= 15, "the order pays a poor wage (%d copper)" % pay)

	# Empty pack: he only says what he wants.
	var start: int = items.coins_of(1)
	var said: String = trade.wanted_order(1, "hob")
	check(said.begins_with("Today I want"), "an empty pack hears the order (%s)" % said)
	check(items.coins_of(1) == start, "and is not paid")

	# Full pack: he takes it and pays once.
	give_order(items, order)
	said = trade.wanted_order(1, "hob")
	check(items.coins_of(1) == start + pay, "the filled order pays %d copper (%s)" % [pay, said])

	for need in order["needs"]:
		check(items.count_for(1, str(need[0])) == 0, "he takes the %s" % str(need[0]))

	# Same day: no second pay.
	give_order(items, order)
	said = trade.wanted_order(1, "hob")
	check(items.coins_of(1) == start + pay, "a second fill the same day is refused (%s)" % said)

	for need in order["needs"]:   # clear the refused fill's items, so no starter goal (12 plant fibre ...) pays its own reward inside the next check
		items.take_from(1, str(need[0]), items.count_for(1, str(need[0])))

	# Next day: a new order, and it pays again.
	game_s += 86400.0
	var order2: Dictionary = trade.order_of_day("hob")
	check(str(order2) != str(order), "the next day has a different order")
	give_order(items, order2)
	var before2: int = items.coins_of(1)   # measured here: a starter goal finished by the picked items may have paid its own small reward meanwhile
	said = trade.wanted_order(1, "hob")
	check(items.coins_of(1) - before2 == int(order2.get("pay", 0)), "the next day's order pays again, once (%d copper, %s)" % [items.coins_of(1) - before2, said])

	items._finish_writer()
	print("test_wanted_order: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
