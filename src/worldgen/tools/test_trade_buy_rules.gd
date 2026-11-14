extends SceneTree

# Hob's board limit (Dave 2 Nov 2026, QA sal-lumber-vs-picking C): data/npcs/shops.json buy_rules. Hob pays about a copper for three
# softwood boards, takes at most per_day boards a game day, and wants more again the next day. Items without a rule are unchanged.
#   godot --headless --path . --script res://src/worldgen/tools/test_trade_buy_rules.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_trade_buy_rules"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true   # no goals here: a goal's own reward (coins, or 4 sticks for twine) would change the amounts this test checks; test_goals covers goals (protocol 119 lifted the `after` lock)
	items.peer_connected_hello(1, "buyruleskey01")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._characters["buyruleskey01"]["luck"] = 0
	items.set_attribute(1, "charisma", 0)
	var trade = TradeScript.new()
	trade.items = items
	trade.npcs = {"npcs": {"hob": {"dormant": false, "placed": true, "pos": Vector3(1.0, 10.0, 0.0)}}}
	trade.setup(dir)
	var game: Array = [0.0]
	trade.now = func(): return 1000.0
	trade.game_seconds = func(): return game[0]
	trade.send_shop = func(_peer, _npc, _title, _ids, _pay, _got, _buys, _tired_ids, _tired, _stock, _supply, _till): pass
	check(trade.open(1, "hob"), "Hob's stall opens")
	var rule: Dictionary = trade._buy_rule("hob", "lumber")
	check(int(rule.get("lot", 0)) == 3 and int(rule.get("per_day", 0)) > 0, "Planks have a rule: 3 a lot (%s)" % str(rule))
	var per_day: int = int(rule["per_day"])
	var board: int = items.table.number_of("lumber")

	# A whole day's limit and more: he takes per_day, pays about per_day / 3 copper.
	items.give_to(1, "lumber", per_day + 12)
	var start: int = items.coins_of(1)
	var said: String = trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(board), per_day + 12)
	var paid: int = items.coins_of(1) - start
	check(items.count_for(1, "lumber") == 12, "he takes only per_day boards (%d left; %s)" % [items.count_for(1, "lumber"), said])
	check(paid >= per_day / 3 - 2 and paid <= per_day / 3, "about a copper for three boards (%d copper for %d)" % [paid, per_day])

	# The same day: no more.
	said = trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(board), 12)
	check(items.count_for(1, "lumber") == 12 and said.find("all the") >= 0, "the same day he wants no more (%s)" % said)

	# Next game day: he buys again.
	game[0] += 86400.0
	said = trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(board), 12)
	check(items.count_for(1, "lumber") == 0, "a day later he buys again (%s)" % said)

	# Stones (no rule) still sell in their lots.
	check(trade._buy_rule("hob", "stone").is_empty(), "stones have no board rule")
	items._finish_writer()
	print("test_trade_buy_rules: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
