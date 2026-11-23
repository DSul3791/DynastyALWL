extends SceneTree

# The town people and trade, end to end (coordinator 23 Nov 2026: "the same way" as cooking and farming), through the real ServerItems,
# ServerNpcs, ServerDialogue and ServerTrade, with restarts:
#   1. no buy and sell straight back at a gain, for every good every trader stocks, any stack size, from a full or an empty shelf, at the
#      best standing a character can reach (rank, charisma, luck), with the rounding (coordinator ruling for Dave, 23 Nov 2026);
#   2. goods sold by the lot are bought by the lot too: a stack of stones off Hob's shelf costs its share of a lot's price, not a copper a stone;
#   3. what the shop window shows (TradePrices, the sums dialogue_view.gd uses) is what the server charges and pays;
#   4. every deal moves coin and goods between the player and the trader and nothing else: no copper or item made or lost, a full pack refused
#      before anything moves, a spent purse refused, a sold out shelf refused;
#   5. two players at one trader: the last axe goes to one of them, the other is told, nothing doubled;
#   6. a line dropped mid-trade and mid-talk: no deal is left half done, the player comes back to the same purse and pack;
#   7. a restart keeps the trader's shelf and purse and the player's pack and coin;
#   8. training (Dave: 1 to 24 by use, a trainer for 25 to 49, training before 25 jumps to 25): Hob's lesson takes its stones once and lifts
#      Trades to 25; it is not offered again until it can be given; it is not offered without the stones; Edda's sword lesson waits for Fighting 15;
#      two players train at once; a restart keeps the lesson and its cooldown. The skill rules themselves are the survival thread's (test_skills).
#   godot --headless --path . --script res://src/worldgen/tools/test_town_trade_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const DialogueScript := preload("res://src/stream/server_dialogue.gd")
const TradePrices := preload("res://src/shared/trade_prices.gd")
const SkillWeb := preload("res://src/shared/skill_web.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_town_trade_loop"
const KEYS := ["townloop-key-01", "townloop-key-02"]

var failures: int = 0
var items
var npcs
var talk
var trade
var gclock: Array = [100000.0]
var said: Dictionary = {}   # peer -> the last line said to them
var notes: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make() -> void:
	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): notes.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return gclock[0]
	items.setup(ItemTableScript.load_default(), DIR)
	items._goals_loaded = true   # no goal rewards: they would move the coin this test counts
	items.gather_pace_ms = 0

	for k in KEYS.size():
		items.peer_connected_hello(k + 1, KEYS[k])
		items.report_position(k + 1, Vector3(0.0, 10.0, 0.0))

	npcs = NpcsScript.new()
	npcs.hour_now = func(): return 12.5
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.player_positions = func(): return items.peer_positions()
	npcs.setup(DIR)

	for i in 4:
		npcs.tick(0.2)

	talk = DialogueScript.new()
	talk.items = items
	talk.npcs = npcs
	talk.hour_now = func(): return 12.5
	talk.send_say = func(peer, _id, _name, text, _voice, choices, ends): said[peer] = {"text": str(text), "choices": Array(choices), "ends": ends}
	trade = TradeScript.new()
	trade.items = items
	trade.npcs = npcs
	trade.game_seconds = func(): return gclock[0]
	trade.send_shop = func(_p, _n, _t, _ids, _pay, _get, _buys, _ti, _tm, _st, _su, _tp): pass
	trade.setup(DIR)
	talk.trade = trade
	talk.setup(DIR)


func save_all() -> void:
	items._dirty = true
	items.save()
	items._finish_writer()
	trade.save()


func restart() -> void:
	save_all()
	make()


func near(peer: int, npc_id: String) -> void:
	for i in 6:   # an NPC is placed when a player comes close (ServerNpcs wakes what players are near)
		var at: Vector3 = npcs._anchor(npcs.npcs[npc_id])   # where he stands, or will be placed
		items.report_position(peer, Vector3(at.x + 1.0, 10.0, at.z))

		if bool(npcs.npcs[npc_id]["placed"]) and not bool(npcs.npcs[npc_id]["dormant"]):
			return

		npcs.tick(0.2)


func coins(peer: int = 1) -> int:
	return items.coins_of(peer)


func count(id: String, peer: int = 1) -> int:
	return items.count_for(peer, id)


func empty_pack(peer: int = 1) -> void:
	var inv = items.inventory_of(peer)

	for s in inv.slot_count:
		inv.clear_slot(s)


func entry(id: String) -> Dictionary:
	return items.table.entry(id)


func stock_index(npc_id: String, id: String) -> int:
	var ids: Array = []

	for s in trade._shops[npc_id].get("stock", []):
		if items.table.number_of(str(s)) > 0:
			ids.append(str(s))

	return ids.find(id)


func buy(peer: int, npc_id: String, id: String, n: int) -> String:
	return trade.deal(peer, npc_id, 0, stock_index(npc_id, id), n)


func sell(peer: int, npc_id: String, id: String, n: int) -> String:
	return trade.deal(peer, npc_id, 1, items.inventory_of(peer).numbers.find(items.table.number_of(id)), n)


# Open the talk with an NPC and pick the choice labelled `label` ("" opens only); -> whether that choice was there.
func choose(peer: int, npc_id: String, label: String) -> bool:
	near(peer, npc_id)
	talk._last_msec.clear()
	talk.talk(peer, npc_id, -1)

	if label == "":
		return true

	var at: int = (said.get(peer, {}).get("choices", []) as Array).find(label)

	if at < 0:
		return false

	talk._last_msec.clear()
	talk.talk(peer, npc_id, at)
	return true


func offered(peer: int, npc_id: String, label: String) -> bool:
	near(peer, npc_id)
	talk._last_msec.clear()
	talk.talk(peer, npc_id, -1)
	var there: bool = (said.get(peer, {}).get("choices", []) as Array).has(label)
	talk.peer_left(peer)   # walk away without choosing
	return there


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	make()
	near(1, "hob")
	check(npcs.npcs.has("hob") and bool(npcs.npcs["hob"]["placed"]), "Hob is at his stall")
	no_gain_part()
	lots_part()
	conservation_part()
	two_players_part()
	dropped_line_part()
	training_part()
	print("test_town_trade_loop: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


# 1. At the best standing anyone reaches and the cheapest shelf, what a stack costs is never under what the same stack sells back for.
func no_gain_part() -> void:
	var key: String = KEYS[0]
	items._characters[key]["luck"] = 100
	items._characters[key]["attributes"] = {"charisma": 100}

	for npc_id in trade._shops:
		if typeof(trade._shops[npc_id]) != TYPE_DICTIONARY:
			continue

		items.add_rep(1, str(npc_id), 1000)   # Trusted, the top rank

	var cfg: Dictionary = trade._cfg()
	var supply_min: float = float(cfg.get("stock", {}).get("supply_min", 0.85))
	var checked: int = 0
	var gains: Array = []

	for npc_id in trade._shops:
		if typeof(trade._shops[npc_id]) != TYPE_DICTIONARY:
			continue

		var m: Dictionary = trade.multipliers(1, str(npc_id))
		check(float(m["get"]) <= float(cfg.get("max_buy", 0.9)) and float(m["pay"]) >= float(cfg.get("min_sell", 1.05)), "%s at the top standing pays %.3f and charges %.3f, within max_buy and min_sell" % [npc_id, float(m["get"]), float(m["pay"])])

		for id in trade._shops[npc_id].get("stock", []):
			var row: Dictionary = entry(str(id))

			if row.is_empty():
				continue

			var lot: int = TradePrices.shelf_lot(row)
			var each_buy: int = trade.price_to_pay(int(row.get("value", 0)), float(m["pay"]) * supply_min)
			var terms: Array = TradePrices.sell_terms(row, trade._buy_rule(str(npc_id), str(id)))
			var each_sell: int = trade.price_to_get(int(terms[1]), float(m["get"]))

			for n in [1, 2, lot - 1, lot, lot + 1, 2 * lot - 1, 2 * lot, 3 * lot + 7, 999]:
				if n <= 0:
					continue

				checked += 1
				var cost: int = TradePrices.total_to_pay(each_buy, lot, n)
				var back: int = each_sell * floori(float(n) / float(int(terms[0])))

				if back > cost:
					gains.append("%s %s x%d: costs %d, sells for %d" % [npc_id, id, n, cost, back])

	check(checked > 100 and gains.is_empty(), "no stack of any stocked good sells back for more than it cost (%d stacks; gains: %s)" % [checked, str(gains.slice(0, 5))])

	# And for real at Hob: buy a lot of stones from a full shelf at the top standing and sell it straight back.
	near(1, "hob")
	items.add_coins(1, 500)
	var before: int = coins()
	var got_said: String = buy(1, "hob", "stone", 40)
	check(count("stone") > 0, "at the top standing a stack of stones is bought (%s)" % got_said)
	sell(1, "hob", "stone", count("stone"))
	check(coins() <= before, "bought and sold straight back, the purse is not fuller (%d -> %d)" % [before, coins()])
	empty_pack()
	items.take_coins(1, coins())
	items._characters[key]["luck"] = 50
	items._characters[key]["attributes"] = {"charisma": 50}
	items._characters[key]["rep"] = {}


# 2. Hob's stones, sticks and plant fibre go by the lot both ways.
func lots_part() -> void:
	near(1, "hob")
	items.add_coins(1, 100)
	var m: Dictionary = trade.multipliers(1, "hob")

	for id in ["stone", "stick", "plant_fibre"]:
		if stock_index("hob", id) < 0:
			continue

		var lot: int = TradePrices.shelf_lot(entry(id))
		trade._refresh("hob")["stock"][id] = trade._rule("hob", id)[0]   # a full shelf
		var shelf: int = trade.stock_of("hob", id)
		var each: int = trade.price_to_pay(int(entry(id).get("value", 0)), float(m["pay"]) * trade.supply("hob", id))
		var want: int = mini(shelf - 1, lot)
		var had: int = coins()
		var said_buy: String = buy(1, "hob", id, want)
		var paid: int = had - coins()
		check(want > 1 and count(id) == want and paid == TradePrices.total_to_pay(each, lot, want), "%d %s off Hob's shelf cost %d copper, their share of %d for %d (%s)" % [want, id, paid, each, lot, said_buy])
		check(paid <= 2, "a stack of %s costs a copper or two, not one a piece (%d)" % [id, paid])
		var one_had: int = coins()
		buy(1, "hob", id, 1)
		check(one_had - coins() == 1, "a single %s still costs the smallest coin, 1 copper" % id)
		empty_pack()

	items.take_coins(1, coins())


# 3, 4 and 7. Deals move coin and goods between the player and the trader only; the window's sums are the server's; a restart keeps both sides.
func conservation_part() -> void:
	near(1, "hob")
	items.add_coins(1, 300)
	var m: Dictionary = trade.multipliers(1, "hob")

	# Buy an axe: the window's price is what is taken; the coin goes into his purse; the axe off his shelf into the pack.
	var axe_shelf: int = trade.stock_of("hob", "stone_axe")
	var shown: int = TradePrices.total_to_pay(TradePrices.lot_to_pay(int(entry("stone_axe").get("value", 0)), float(m["pay"]) * trade.supply("hob", "stone_axe")), TradePrices.shelf_lot(entry("stone_axe")), 1)
	var purse_before: int = trade.purse_of("hob")
	var had: int = coins()
	buy(1, "hob", "stone_axe", 1)
	var paid: int = had - coins()
	check(paid == shown and paid > 0, "the axe costs what the window shows (%d, shown %d)" % [paid, shown])
	check(count("stone_axe") == 1 and trade.stock_of("hob", "stone_axe") == axe_shelf - 1, "the axe leaves his shelf for the pack")
	check(trade.purse_of("hob") - purse_before == mini(paid, trade._purse_cap("hob") - purse_before), "the copper goes into his purse (up to its cap)")

	# Sell it back: the window's price for it is what is paid, out of his purse.
	var slot: int = items.inventory_of(1).numbers.find(items.table.number_of("stone_axe"))
	var quote: int = TradePrices.lot_to_get(TradePrices.sell_terms(entry("stone_axe"), {})[1], float(m["get"]) * trade.demand("hob", "stone_axe"), 1.0 - float(items.inventory_of(1).wear[slot]) / float(maxi(items.inventory_of(1).max_durability(slot), 1)))
	purse_before = trade.purse_of("hob")
	had = coins()
	sell(1, "hob", "stone_axe", 1)
	check(coins() - had == quote and purse_before - trade.purse_of("hob") == quote, "sold back it pays what the window shows (%d, shown %d), out of his purse" % [coins() - had, quote])
	check(count("stone_axe") == 0, "and the axe is gone from the pack")

	# A pack too heavy to carry more (a pack grows, so weight is what fills it): refused before any copper moves or the shelf changes.
	var inv = items.inventory_of(1)
	inv.add(items.table.number_of("iron_ingot"), 5000)
	check(items._fit(1, inv, items.table.number_of("stone_knife"), 1) == 0, "the pack is loaded past what the player can carry")

	var full_shelf: int = trade.stock_of("hob", "stone_knife")
	had = coins()
	var full_said: String = buy(1, "hob", "stone_knife", 1)
	check(full_said == "You cannot carry any more." and coins() == had and trade.stock_of("hob", "stone_knife") == full_shelf, "a full pack is told it cannot carry more; nothing moves (%s)" % full_said)
	empty_pack()

	# Too poor: refused, nothing moves.
	items.take_coins(1, coins())
	var poor_said: String = buy(1, "hob", "stone_knife", 1)
	check(poor_said == "You cannot afford that." and count("stone_knife") == 0 and trade.stock_of("hob", "stone_knife") == full_shelf, "with no copper the knife stays on the shelf (%s)" % poor_said)

	# A spent purse: refused, the goods stay in the pack.
	trade._refresh("hob")["purse"] = 0.0
	items.give_to(1, "stone_knife", 1)
	var spent_said: String = sell(1, "hob", "stone_knife", 1)
	check(spent_said == TradeScript.PURSE_EMPTY_SAY and count("stone_knife") == 1 and coins() == 0, "a spent purse buys nothing and says so (%s)" % spent_said)

	# Sold out: refused.
	trade._refresh("hob")["stock"]["stone_axe"] = 0.0
	items.add_coins(1, 100)
	had = coins()
	check(buy(1, "hob", "stone_axe", 1) == "He has none left." and coins() == had, "a sold out shelf sells nothing")

	# A restart: both sides kept, to the copper.
	gclock[0] += 600.0   # a game hour's restock and purse refill comes back the same either side of the restart
	var keep: Array = [trade.stock_of("hob", "stone_knife"), trade.stock_of("hob", "stone_axe"), trade.purse_of("hob"), coins(), count("stone_knife")]
	restart()
	var back: Array = [trade.stock_of("hob", "stone_knife"), trade.stock_of("hob", "stone_axe"), trade.purse_of("hob"), coins(), count("stone_knife")]
	check(back == keep, "a restart keeps his shelf and purse and the player's coin and pack (%s -> %s)" % [str(keep), str(back)])
	empty_pack()
	items.take_coins(1, coins())


# 5. Two players and one axe left.
func two_players_part() -> void:
	trade._refresh("hob")["stock"]["stone_axe"] = 1.0
	near(1, "hob")
	near(2, "hob")
	items.add_coins(1, 100)
	items.add_coins(2, 100)
	var total_before: int = coins(1) + coins(2) + trade.purse_of("hob")
	var a: String = buy(1, "hob", "stone_axe", 1)
	var b: String = buy(2, "hob", "stone_axe", 1)
	check(count("stone_axe", 1) + count("stone_axe", 2) == 1 and trade.stock_of("hob", "stone_axe") == 0, "the last axe goes to one of them (%s / %s)" % [a, b])
	check(b == "He has none left." and coins(2) == 100, "the other is told and keeps their copper")
	check(coins(1) + coins(2) + trade.purse_of("hob") == total_before, "no copper made or lost between them and Hob")
	empty_pack(1)
	empty_pack(2)
	items.take_coins(1, coins(1))
	items.take_coins(2, coins(2))


# 6. A line dropped mid-trade and mid-talk.
func dropped_line_part() -> void:
	near(1, "hob")
	items.add_coins(1, 100)
	choose(1, "hob", "")   # the talk is open
	var keep: Array = [coins(), count("stone_knife"), trade.stock_of("hob", "stone_knife"), trade.purse_of("hob")]
	talk.peer_left(1)
	trade_peer_left(1)
	items.peer_left(1)
	items.peer_connected_hello(1, KEYS[0])
	near(1, "hob")
	check([coins(), count("stone_knife"), trade.stock_of("hob", "stone_knife"), trade.purse_of("hob")] == keep, "back on a new line: the same purse, pack, shelf and his purse")
	talk._last_msec.clear()
	said.erase(1)
	talk.talk(1, "hob", 0)   # a choice from the old talk, never reopened
	check(not said.has(1), "a choice from the talk before the drop is ignored")
	check(buy(1, "hob", "stone_knife", 1).begins_with("Bought"), "and trading goes on as before")
	empty_pack()
	items.take_coins(1, coins())

	# What he says against what happens: Hob's firewood job pays only for firewood still in the pack when the player says "I have your firewood."
	check(choose(1, "hob", "Can I help with anything?") and str(said[1]["text"]).contains("three bolts of firewood"), "Hob asks for three bolts of firewood")
	items.give_to(1, "firewood", 3)
	near(1, "hob")
	talk._last_msec.clear()
	talk.talk(1, "hob", -1)
	var at: int = (said[1]["choices"] as Array).find("I have your firewood.")
	check(at >= 0, "with the firewood in the pack he offers to take it")
	items.take_from(1, "firewood", 3)   # dropped or sold while the talk stands open
	talk._last_msec.clear()
	talk.talk(1, "hob", at)
	check(coins() == 0 and count("roast_forage") == 0, "picked after the firewood is gone, nothing is paid (%d copper, %d roasts)" % [coins(), count("roast_forage")])
	items.give_to(1, "firewood", 3)
	check(choose(1, "hob", "I have your firewood.") and count("firewood") == 0 and coins() == 5 and count("roast_forage") == 2, "with it in the pack: the three bolts taken, five copper and two roasts paid, as he says (%s)" % str(said[1]["text"]))
	empty_pack()
	items.take_coins(1, coins())


func trade_peer_left(_peer: int) -> void:
	pass   # ServerTrade keeps nothing per connection: a deal is one request, all or nothing


# 8. Training at Hob and Edda.
func training_part() -> void:
	var cfg: Dictionary = items._skills_cfg
	var lesson: String = "Teach me the trade."
	var trades: Callable = func(peer: int) -> float: return SkillWeb.effective(cfg, "trades", items._skill_records(peer))
	empty_pack(1)
	check(trades.call(1) < 25.0, "a new player's Trades is under 25 (%.1f)" % trades.call(1))
	check(not offered(1, "hob", lesson), "without the stones Hob does not offer the lesson")
	items.give_to(1, "stone", 3)
	items.give_to(2, "stone", 3)
	check(offered(1, "hob", lesson), "with three stones he offers it")
	check(choose(1, "hob", lesson) and str(said[1]["text"]).contains("stones"), "the player takes the lesson (%s)" % str(said.get(1, {}).get("text", "")))
	check(count("stone") == 0, "the three stones are taken, once")
	check(absf(trades.call(1) - 25.0) < 0.01, "Trades jumps to 25 (%.2f)" % trades.call(1))
	check(SkillWeb.cap_of(cfg, "trades", items._skill_records(1)) == 50, "and can now rise by use to 49")
	offered(2, "hob", lesson)   # the first talk is Hob's greeting to a stranger; the lesson is on his usual list after it
	var second: bool = choose(2, "hob", lesson)
	check(second and count("stone", 2) == 0 and absf(trades.call(2) - 25.0) < 0.01, "a second player takes the same lesson at once and gets the same")
	items.give_to(1, "stone", 3)
	check(not offered(1, "hob", lesson), "Hob does not offer a second lesson: he teaches only to 25")
	check(count("stone") == 3, "and takes nothing")
	var rec: Dictionary = (items._skill_records(1).get("trades", {}) as Dictionary).duplicate()
	restart()
	var rec2: Dictionary = items._skill_records(1).get("trades", {})
	check(int(rec2.get("t", 0)) == int(rec.get("t", -1)) and is_equal_approx(float(rec2.get("tlast", 0.0)), float(rec.get("tlast", 1.0))) and absf(trades.call(1) - 25.0) < 0.01, "a restart keeps the lesson, its time and Trades at 25")

	# Edda's sword lesson waits for Fighting 15 (swordplay is locked till then).
	var sword: String = "Teach me the sword."
	check(not offered(1, "edda", sword), "Edda does not offer the sword to a new player")
	var recs: Dictionary = items._skill_records(1)
	var fighting: Dictionary = recs.get("fighting", {})
	fighting["p"] = SkillWeb.units_for(cfg, "fighting", 16.0)
	fighting["peak"] = fighting["p"]
	recs["fighting"] = fighting
	check(SkillWeb.unlocked(cfg, "swordplay", recs), "Fighting 16 unlocks Swordplay")
	check(offered(1, "edda", sword), "now she offers the lesson")
	check(choose(1, "edda", sword) and absf(SkillWeb.effective(cfg, "swordplay", items._skill_records(1)) - 25.0) < 0.01, "and Swordplay jumps to 25 (%.2f)" % SkillWeb.effective(cfg, "swordplay", items._skill_records(1)))
	check(not offered(1, "edda", sword), "she does not offer it again")
