extends SceneTree

# Shop trading (Radar, 2026-10-21): traders sell at a markup and buy at a discount moved by reputation, charisma and luck.
#   godot --headless --path . --script res://src/worldgen/tools/test_trade.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const TradePrices := preload("res://src/shared/trade_prices.gd")

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
	items._goals_loaded = true   # no goals here: a goal's own reward (coins) would change the amounts this test checks; test_goals covers goals (protocol 119 lifted the `after` lock)
	items.peer_connected_hello(1, "tradekey0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._characters["tradekey0001"]["luck"] = 50   # neutral (0 to 100)
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
	trade.send_shop = func(_peer, npc, _title, ids, pay_milli, got_milli, _buys, _tired_ids, _tired, stock, supply, till): opened.append([npc, ids, pay_milli, got_milli, stock, supply, till])
	check(trade.open(1, "hob") and opened.size() == 1, "Hob's shop opens beside him")
	check(not trade.open(1, "edda"), "an NPC without a shop has no window")
	var pay: int = int(opened[0][2])
	var got: int = int(opened[0][3])
	check(pay == 1300 and got == 550, "a plain stranger pays 130 percent and is paid 55 percent (%d, %d)" % [pay, got])
	check(pay > got and got <= 900 and pay >= 1050, "buying always costs more than selling back")

	# Buying and selling with coins.
	var axe: int = items.table.number_of("stone_axe")
	items.add_coins(1, 100)
	check(items.purse_of(1) == {"coin_copper": 100}, "100 copper paid in stays 100 copper coins away from a trader (%s)" % str(items.purse_of(1)))
	trade.open(1, "hob")
	check(items.purse_of(1) == {"coin_silver": 1} and items.coins_of(1) == 100, "opening Hob's window changes them into the fewest coins (%s)" % str(items.purse_of(1)))
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

	# "Would you like to buy my extra stuff?" (kind 3): materials sold, tools, coins and valuables kept.
	items.add_coins(1, 5)
	var kept_axe: int = items.table.number_of("stone_axe")
	items.action(1, Net.ACT_ADMIN_GIVE, kept_axe, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 60, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("steel_ingot"), 0, 1, Vector3.ZERO)
	var sticks_before: int = items.inventory_of(1).count_of(items.table.number_of("stick"))
	var coins_before: int = items.coins_of(1)
	var extras_said: String = trade.deal(1, "hob", 3, 0, 1)
	check(items.inventory_of(1).count_of(items.table.number_of("stick")) == 0 and sticks_before > 0, "the extras sale sells the sticks (%s)" % extras_said)
	check(items.inventory_of(1).count_of(kept_axe) >= 1 and items.inventory_of(1).count_of(items.table.number_of("steel_ingot")) == 1, "it keeps the axe and the valuable steel ingot")
	check(items.coins_of(1) >= coins_before, "the sale pays coin (%d to %d)" % [coins_before, items.coins_of(1)])

	# Reputation, charisma and luck move the prices both ways, never past the floors.
	var m_rep0: Dictionary = trade.multipliers(1, "hob")
	items.add_rep(1, "hob", 30)
	items._characters["tradekey0001"]["luck"] = 100
	var m_luck: Dictionary = trade.multipliers(1, "hob")
	items._characters["tradekey0001"]["luck"] = 50   # neutral (0 to 100)
	check(float(m_luck["pay"]) < float(m_rep0["pay"]), "luck helps")
	var m_rep: Dictionary = trade.multipliers(1, "hob")
	check(float(m_rep["pay"]) < 1.3 and float(m_rep["get"]) > 0.55, "a Trusted friend pays less and is paid more (%.2f, %.2f)" % [m_rep["pay"], m_rep["get"]])
	items.set_attribute(1, "charisma", 100)
	var m_cha: Dictionary = trade.multipliers(1, "hob")
	check(float(m_cha["pay"]) < float(m_rep["pay"]) and float(m_cha["get"]) > float(m_rep["get"]), "charisma helps too")
	check(float(m_cha["pay"]) >= 1.05 and float(m_cha["get"]) <= 0.9, "but never past the floors (%.2f, %.2f)" % [m_cha["pay"], m_cha["get"]])
	items.set_attribute(1, "charisma", 0)
	var m_bad: Dictionary = trade.multipliers(1, "hob")
	check(float(m_bad["pay"]) > float(m_rep["pay"]), "poor charisma costs more")

	# Demand: selling the same thing over and over pays less each time and recovers with time.
	items._characters["tradekey0001"]["luck"] = 50   # neutral (0 to 100)
	items.set_attribute(1, "charisma", 50)
	items.add_rep(1, "hob", -30)
	var stone: int = items.table.number_of("stone")
	items.give_to(1, "stone", 120)
	var slot_s: int = items.inventory_of(1).numbers.find(stone)
	var purse0: int = items.coins_of(1)
	trade.deal(1, "hob", 1, slot_s, 1)
	var first: int = items.coins_of(1) - purse0
	check(first == 0 and items.count_for(1, "stone") == 120, "a single stone pays nothing and is kept (a sixtieth of a copper, sold in lots of 60: 0.5 kg stones, Dave 19 Nov 2026)")
	trade.deal(1, "hob", 1, slot_s, 59)
	check(items.coins_of(1) == purse0 and items.count_for(1, "stone") == 120, "fifty-nine stones are less than a lot: no copper, all kept")
	var seven_msg: String = trade.deal(1, "hob", 1, slot_s, 67)
	first = items.coins_of(1) - purse0
	check(seven_msg.contains("7 left") and seven_msg.contains("60 at a time"), "the sold message says seven stones were left and the lot size (%s)" % seven_msg)
	check(first == 1 and items.count_for(1, "stone") == 60, "sixty-seven stones: one lot of 60 pays 1 copper, the seven odd stones are kept (%d)" % first)
	var purse1: int = items.coins_of(1)
	trade.deal(1, "hob", 1, slot_s, 60)
	var rest: int = items.coins_of(1) - purse1
	check(first >= 1 and rest == 1, "selling sixty more stones pays one copper, a sixtieth of a copper each (%d for 60)" % rest)
	check(trade.demand("hob", "stone") <= 0.5, "and the trader is tired of stones (%.2f)" % trade.demand("hob", "stone"))
	clock[0] += 1800.0   # demand comes back 4 pieces a minute (coins.json demand); the 120 stones sold are 60 kg of 0.5 kg stones (Dave 19 Nov 2026), twice the pieces the 60 kg was before
	check(trade.demand("hob", "stone") > 0.9, "thirty minutes later the demand has come back (%.2f)" % trade.demand("hob", "stone"))

	# Worthless and rotten things are not bought; damaged tools pay less.
	check(trade.price_to_get(0, 0.55) == 0 and trade.price_to_get(20, 0.55, 0.5) == 5 and trade.price_to_get(1, 0.55) == 1, "worthless pays nothing, half-worn pays half, a copper item pays at least 1")
	# Stock: the shelf is finite, buying lowers it, supply moves the price, game days restock it.
	items.add_coins(1, 5000)
	check(trade.stock_of("hob", "stone_axe") == 3 and trade.stock_of("hob", "wooden_shovel") == 2, "the axe sold back is on the shelf again (3), 2 shovels")
	var price_full: float = trade.supply("hob", "wooden_shovel")
	trade.deal(1, "hob", 0, (opened[0][1] as PackedStringArray).find("wooden_shovel"), 1)
	check(trade.supply("hob", "wooden_shovel") > price_full, "a thinner shelf costs more (%.3f > %.3f)" % [trade.supply("hob", "wooden_shovel"), price_full])
	var said2: String = trade.deal(1, "hob", 0, (opened[0][1] as PackedStringArray).find("wooden_shovel"), 5)
	check(trade.stock_of("hob", "wooden_shovel") == 0, "he sells the last one (%s)" % said2)
	check(trade.deal(1, "hob", 0, (opened[0][1] as PackedStringArray).find("wooden_shovel"), 1) == "He has none left.", "and has none left")
	gclock[0] += 86400.0 * 1.2
	check(trade.stock_of("hob", "wooden_shovel") == 1, "a game day later one shovel is back")
	gclock[0] += 86400.0 * 10.0
	check(trade.stock_of("hob", "wooden_shovel") == 2, "the shelf never passes its maximum")
	trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(items.table.number_of("wooden_shovel")), 1)
	check(trade.stock_of("hob", "wooden_shovel") == 2, "a shovel sold back goes on a full shelf only up to the max")

	# Purse: he can only pay what he has, and it refills by game days.
	trade._state["hob"]["purse"] = 3.0
	items.give_to(1, "stone_axe", 1)
	var coins_a: int = items.coins_of(1)
	var said3: String = trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(items.table.number_of("stone_axe")), 1)
	check(items.coins_of(1) == coins_a and said3 != "", "with 3 copper in his purse he cannot buy an axe (%s)" % said3)
	gclock[0] += 86400.0 * 5.0
	check(trade.purse_of("hob") >= 300, "his purse refills over game days (%d)" % trade.purse_of("hob"))

	# Repairs: a smith mends worn tools for coin; iron tools need a forge when mended by hand.
	var inv_r = items.inventory_of(1)
	items.give_to(1, "bronze_knife", 1)
	var axe_slot: int = inv_r.numbers.find(items.table.number_of("bronze_knife"))
	inv_r.wear[axe_slot] = 100
	var smith_cost: int = trade.repair_cost(inv_r.numbers[axe_slot], 100, 1.0)
	check(smith_cost >= 1 and smith_cost < 20, "a worn bronze knife: a few coppers to mend (%d)" % smith_cost)
	check(items.table.entry("stone_axe").get("repair", []).is_empty() and trade.repair_cost(items.table.number_of("stone_axe"), 100, 1.0) == 0, "a disposable Stone - Axe (no repair, master s2.2 rule 1) is never mended")
	var coins_r: int = items.coins_of(1)
	var said4: String = trade.deal(1, "hob", 2, axe_slot, 1)
	check(inv_r.wear[axe_slot] == 0 and items.coins_of(1) == coins_r - trade.repair_cost(inv_r.numbers[axe_slot], 100, float(trade.multipliers(1, "hob")["pay"])), "Hob mends it as new for coin (%s)" % said4)
	check(trade.deal(1, "hob", 2, axe_slot, 1) == "That needs no mending.", "an unworn tool needs no mending")
	items.give_to(1, "iron_pickaxe", 1)
	items.give_to(1, "iron_ingot", 1)
	items.give_to(1, "stick", 1)
	var pick_slot: int = inv_r.numbers.find(items.table.number_of("iron_pickaxe"))
	inv_r.wear[pick_slot] = 1000
	items._repair(1, inv_r, pick_slot)
	check(inv_r.wear[pick_slot] == 1000, "an iron pickaxe cannot be mended by hand without a forge")

	# Playtest 12 Nov 2026 TEST-003: a spent purse says so in Dave's words, refills over game time, and a player out of talk range is told so.
	items.give_to(1, "stone_axe", 1)
	var sell_axe: int = inv_r.numbers.find(items.table.number_of("stone_axe"))
	trade._refresh("hob")["purse"] = 0.0
	var broke_msg: String = trade.deal(1, "hob", 1, sell_axe, 1)
	check(broke_msg == trade.PURSE_EMPTY_SAY and inv_r.count_of(items.table.number_of("stone_axe")) >= 1, "a spent purse buys nothing and says to come back later (%s)" % broke_msg)
	items.give_to(1, "stone", 30)
	var extras_broke: String = trade.deal(1, "hob", 3, 0, 1)
	check(extras_broke == trade.PURSE_EMPTY_SAY, "the extra-stuff button also says the purse is spent (%s)" % extras_broke)
	# Dave 24 Nov 2026: "why does it say I sold stuff for about x amount but I dont have that amount in my coins". The window's figure and the
	# server's sale are one sum (TradePrices.sale: the price falls with each unit, and he stops at his purse); what he cannot pay for stays.
	var fur: int = items.table.number_of("fur")
	items.give_to(1, "fur", 20)
	var fur_slot: int = inv_r.numbers.find(fur)
	trade._refresh("hob")["purse"] = 30.0
	var fur_terms: Array = TradePrices.sell_terms(items.table.entry("fur"), {}, 1.0)
	var fur_cfg: Dictionary = items._coins_cfg["trade"]["demand"]
	var guess: Array = TradePrices.sale(int(fur_terms[1]), int(fur_terms[0]), 20, float(trade.multipliers(1, "hob")["get"]), trade.demand("hob", "fur"), float(fur_cfg["drop_per_sale"]), float(fur_cfg["floor"]), 1.0, 30)
	var coins_fur: int = items.coins_of(1)
	var fur_said: String = trade.deal(1, "hob", 1, fur_slot, 20)
	check(items.coins_of(1) - coins_fur == int(guess[1]) and inv_r.count_of(fur) == 20 - int(guess[0]) and int(guess[0]) > 0 and int(guess[0]) < 20, "the window's sum is what he pays: %d fur for %d copper of a 30 copper purse, the rest kept (%s)" % [int(guess[0]), int(guess[1]), fur_said])
	check(fur_said.contains(items._coin_words(int(guess[1]))), "and the line says the copper really paid (%s)" % fur_said)
	trade._refresh("hob")["purse"] = 30.0
	coins_fur = items.coins_of(1)
	var fur_left: int = inv_r.count_of(fur)
	var extras_short: String = trade.deal(1, "hob", 3, 0, 1)
	var paid_extras: int = items.coins_of(1) - coins_fur
	check(paid_extras > 0 and paid_extras <= 30 and extras_short.contains("for %s." % items._coin_words(paid_extras)) and extras_short.contains("the rest stays in your pack") and inv_r.count_of(fur) > 0 and inv_r.count_of(fur) < fur_left, "the extra-stuff sale says what it really paid, and that what he could not pay for stays (%s)" % extras_short)
	if inv_r.numbers.find(fur) >= 0:
		inv_r.clear_slot(inv_r.numbers.find(fur))
	trade._refresh("hob")["purse"] = 0.0
	gclock[0] += 86400.0
	check(trade.purse_of("hob") == 100, "one game day later (an hour of play) his purse has 100 copper again (%d)" % trade.purse_of("hob"))
	check(trade.deal(1, "hob", 1, sell_axe, 1).begins_with("Sold"), "and he buys again")
	npcs["npcs"]["hob"]["pos"] = Vector3(30.0, 10.0, 0.0)
	var away_msg: String = trade.deal(1, "hob", 1, 0, 1)
	check(away_msg.begins_with("You are too far from"), "out of talk range the deal says so instead of nothing (%s)" % away_msg)
	npcs["npcs"]["hob"]["pos"] = Vector3(1.0, 10.0, 0.0)

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
