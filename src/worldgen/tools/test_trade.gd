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
	trade.setup()
	var opened: Array = []
	trade.send_shop = func(peer, npc, title, ids, pay, got, buys): opened.append([npc, ids, pay, got])
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
	check(items.inventory_of(1).count_of(axe) == 1 and items.coins_of(1) == 100 - 26, "an axe (value 20) costs 26 copper at 130 percent (%d left, %s)" % [items.coins_of(1), said])
	var purse_then: int = items.coins_of(1)
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

	# Worthless and rotten things are not bought; damaged tools pay less.
	check(trade.price_to_get(0, 0.55) == 0 and trade.price_to_get(20, 0.55, 0.5) == 5 and trade.price_to_get(1, 0.55) == 1, "worthless pays nothing, half-worn pays half, a copper item pays at least 1")
	print("trade: %d failures" % failures)
	quit(failures)
