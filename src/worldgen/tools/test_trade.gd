extends SceneTree

# Shop trading (Radar, 2026-10-21): traders sell at a markup and buy at a discount moved by reputation, charisma and luck.
#   godot --headless --path . --script res://src/worldgen/tools/test_trade.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_trade"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "tradekey0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._characters["tradekey0001"]["luck"] = 0
	var npcs := {"npcs": {"hob": {"dormant": false, "placed": true, "pos": Vector3(1.0, 10.0, 0.0)}}}
	var trade = TradeScript.new()
	trade.items = items
	trade.npcs = npcs
	trade.setup(dir)
	var opened: Array = []
	var clock: Array = [1000.0]
	trade.now = func(): return clock[0]
	var gclock: Array = [0.0]
	trade.game_seconds = func(): return gclock[0]
	trade.send_shop = func(_peer, npc, _title, ids, pay, got, _buys, _tired_ids, _tired, stock, supply, till): opened.append([npc, ids, pay, got, stock, supply, till])
	check(trade.open(1, "hob") and opened.size() == 1, "Hob's shop opens beside him")
	check(not trade.open(1, "edda"), "an NPC without a shop has no window")
	var pay: int = int(opened[0][2])
	var got: int = int(opened[0][3])
	check(pay == 1300 and got == 550, "a plain stranger pays 130 percent and is paid 55 percent (%d, %d)" % [pay, got])
	check(pay > got and got <= 900 and pay >= 1050, "buying always costs more than selling back")

	# Buying and selling with coins.
	var axe: int = items.table.number_of("stone_axe")
	items.add_coins(1, 100)
	var idx: int = (opened[0][1] as PackedStringArray).find("stone_axe")
	var said: String = trade.deal(1, "hob", 0, idx, 1)
	check(items.inventory_of(1).count_of(axe) == 1 and items.coins_of(1) == 100 - 23, "an axe (value 20) costs 23 copper (130 percent, full shelf 85 percent) (%d left, %s)" % [items.coins_of(1), said])
	var purse_then: int = items.coins_of(1)
	items.take_coins(1, items.coins_of(1) - 10)
	purse_then = items.coins_of(1)
	check(trade.deal(1, "hob", 0, idx, 99) == "You cannot afford that." and items.coins_of(1) == purse_then, "you cannot buy what you cannot afford")
	var slot: int = items.inventory_of(1).numbers.find(axe)
	var before_coins: int = items.coins_of(1)
	trade.deal(1, "hob", 1, slot, 1)
	check(items.coins_of(1) == before_coins + 11 and items.inventory_of(1).count_of(axe) >= 0, "selling an axe back pays 11 copper (55 percent of 20) (%d to %d)" % [before_coins, items.coins_of(1)])
	check(trade.deal(1, "hob", 1, 29, 1) == "", "an empty slot sells nothing")

	# Reputation, charisma and luck move the prices both ways, never past the floors.
	var m_rep0: Dictionary = trade.multipliers(1, "hob")
	items.add_rep(1, "hob", 30)
	items._characters["tradekey0001"]["luck"] = 10
	var m_luck: Dictionary = trade.multipliers(1, "hob")
	items._characters["tradekey0001"]["luck"] = 0
	check(float(m_luck["pay"]) < float(m_rep0["pay"]), "luck helps")
	var m_rep: Dictionary = trade.multipliers(1, "hob")
	check(float(m_rep["pay"]) < 1.3 and float(m_rep["get"]) > 0.55, "a Trusted friend pays less and is paid more (%.2f, %.2f)" % [m_rep["pay"], m_rep["get"]])
	items.set_attribute(1, "charisma", 10)
	var m_cha: Dictionary = trade.multipliers(1, "hob")
	check(float(m_cha["pay"]) < float(m_rep["pay"]) and float(m_cha["get"]) > float(m_rep["get"]), "charisma helps too")
	check(float(m_cha["pay"]) >= 1.05 and float(m_cha["get"]) <= 0.9, "but never past the floors (%.2f, %.2f)" % [m_cha["pay"], m_cha["get"]])
	items.set_attribute(1, "charisma", -10)
	var m_bad: Dictionary = trade.multipliers(1, "hob")
	check(float(m_bad["pay"]) > float(m_rep["pay"]), "poor charisma costs more")

	# Demand: selling the same thing over and over pays less each time and recovers with time.
	items._characters["tradekey0001"]["luck"] = 0
	items.set_attribute(1, "charisma", 0)
	items.add_rep(1, "hob", -30)
	var stone: int = items.table.number_of("stone")
	items.give_to(1, "stone", 60)
	var slot_s: int = items.inventory_of(1).numbers.find(stone)
	var purse0: int = items.coins_of(1)
	trade.deal(1, "hob", 1, slot_s, 1)
	var first: int = items.coins_of(1) - purse0
	var purse1: int = items.coins_of(1)
	trade.deal(1, "hob", 1, slot_s, 40)
	var rest: int = items.coins_of(1) - purse1
	check(first >= 1 and rest < 40, "selling forty stones at once pays less than a copper each in the end (%d for 40)" % rest)
	check(trade.demand("hob", "stone") <= 0.5, "and the trader is tired of stones (%.2f)" % trade.demand("hob", "stone"))
	clock[0] += 600.0
	check(trade.demand("hob", "stone") > 0.9, "ten minutes later the demand has come back (%.2f)" % trade.demand("hob", "stone"))

	# Worthless and rotten things are not bought; damaged tools pay less.
	check(trade.price_to_get(0, 0.55) == 0 and trade.price_to_get(20, 0.55, 0.5) == 5 and trade.price_to_get(1, 0.55) == 1, "worthless pays nothing, half-worn pays half, a copper item pays at least 1")
	# Stock: the shelf is finite, buying lowers it, supply moves the price, game days restock it.
	items.add_coins(1, 5000)
	check(trade.stock_of("hob", "stone_axe") == 3 and trade.stock_of("hob", "wooden_spade") == 2, "the axe sold back is on the shelf again (3), 2 spades")
	var price_full: float = trade.supply("hob", "wooden_spade")
	trade.deal(1, "hob", 0, (opened[0][1] as PackedStringArray).find("wooden_spade"), 1)
	check(trade.supply("hob", "wooden_spade") > price_full, "a thinner shelf costs more (%.3f > %.3f)" % [trade.supply("hob", "wooden_spade"), price_full])
	var said2: String = trade.deal(1, "hob", 0, (opened[0][1] as PackedStringArray).find("wooden_spade"), 5)
	check(trade.stock_of("hob", "wooden_spade") == 0, "he sells the last one (%s)" % said2)
	check(trade.deal(1, "hob", 0, (opened[0][1] as PackedStringArray).find("wooden_spade"), 1) == "He has none left.", "and has none left")
	gclock[0] += 86400.0 * 1.2
	check(trade.stock_of("hob", "wooden_spade") == 1, "a game day later one spade is back")
	gclock[0] += 86400.0 * 10.0
	check(trade.stock_of("hob", "wooden_spade") == 2, "the shelf never passes its maximum")
	trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(items.table.number_of("wooden_spade")), 1)
	check(trade.stock_of("hob", "wooden_spade") == 2, "a spade sold back goes on a full shelf only up to the max")

	# Purse: he can only pay what he has, and it refills by game days.
	trade._state["hob"]["purse"] = 3.0
	items.give_to(1, "stone_axe", 1)
	var coins_a: int = items.coins_of(1)
	var said3: String = trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(items.table.number_of("stone_axe")), 1)
	check(items.coins_of(1) == coins_a and said3 != "", "with 3 copper in his purse he cannot buy an axe (%s)" % said3)
	gclock[0] += 86400.0 * 5.0
	check(trade.purse_of("hob") >= 300, "his purse refills over game days (%d)" % trade.purse_of("hob"))

	# Persistence: shelf and purse survive a restart.
	trade._state["hob"]["stock"]["stone"] = 7.0
	trade.save()
	var trade2 = TradeScript.new()
	trade2.items = items
	trade2.npcs = npcs
	trade2.game_seconds = trade.game_seconds
	trade2.setup(dir)
	check(trade2.stock_of("hob", "stone") == 7, "the shelf is kept across a restart")
	print("trade: %d failures" % failures)
	quit(failures)
