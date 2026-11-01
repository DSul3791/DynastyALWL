extends RefCounted

# Shop trading (Radar, 2026-10-21, Dave: traders buy at a discount and sell at a markup moved by reputation, charisma and luck).
# data/npcs/shops.json says who trades what; data/items/coins.json "trade" holds every number. The prices are the same number
# for every item (a multiple of its value), so the server sends two multipliers and the client prices what it shows; the server
# prices every deal itself.

const TALK_RANGE_M := 4.5

var items                       # ServerItems
var npcs                        # ServerNpcs
var send_shop: Callable         # (peer, npc id, title, stock ids, buy_milli, sell_milli, buys kinds, demand ids, demand_milli, stock counts, supply_milli, trader purse)
var game_seconds: Callable      # () -> game clock seconds (restocking runs on game days); unset: the real clock x 24
var now: Callable               # () -> seconds; tests set it
var _shops: Dictionary = {}
var _sold: Dictionary = {}      # "npc|item" -> [sales (float), time] the trader's weariness of that item
var _state: Dictionary = {}     # npc id -> {"stock": {item id: float on the shelf}, "purse": float copper, "t": game seconds of the last refresh}
var _path: String = ""


func setup(store_dir: String = "") -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/shops.json"))
	_shops = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_path = store_dir.path_join("trade_state.json") if store_dir != "" else ""

	if _path != "" and FileAccess.file_exists(_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
		_state = saved.get("traders", {}) if typeof(saved) == TYPE_DICTIONARY else {}


# Shelves and purses are saved after every deal (a few hundred bytes).
func save() -> void:
	if _path == "":
		return

	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify({"version": 1, "traders": _state}))
		file.close()


func _game_s() -> float:
	return float(game_seconds.call()) if game_seconds.is_valid() else Time.get_unix_time_from_system() * 24.0


func _stock_cfg() -> Dictionary:
	return _cfg().get("stock", {})


# [most on the shelf, restock per game day] for one stocked item.
func _rule(npc_id: String, item_id: String) -> Array:
	var rules: Dictionary = _shops.get(npc_id, {}).get("stock_rules", {})
	var rule: Array = rules.get(item_id, [])
	var c: Dictionary = _stock_cfg()
	return [float(rule[0]), float(rule[1])] if rule.size() == 2 else [float(c.get("default_max", 8)), float(c.get("default_per_day", 3))]


func _purse_cap(npc_id: String) -> float:
	return float(_shops.get(npc_id, {}).get("purse_cap", _stock_cfg().get("purse_cap_default", 300)))


# Brings a trader's shelf and purse up to date: a full shelf and purse at first sight, then restocking by game days.
func _refresh(npc_id: String) -> Dictionary:
	var now_s: float = _game_s()

	if not _state.has(npc_id):
		var stock: Dictionary = {}

		for id in _shops[npc_id].get("stock", []):
			stock[str(id)] = _rule(npc_id, str(id))[0]

		_state[npc_id] = {"stock": stock, "purse": _purse_cap(npc_id), "t": now_s}

	var st: Dictionary = _state[npc_id]
	var days: float = maxf((now_s - float(st["t"])) / 86400.0, 0.0)

	if days > 0.0:
		for id in st["stock"]:
			var rule: Array = _rule(npc_id, str(id))
			st["stock"][id] = minf(float(st["stock"][id]) + rule[1] * days, rule[0])

		st["purse"] = minf(float(st["purse"]) + float(_shops[npc_id].get("purse_regen_per_day", _stock_cfg().get("purse_regen_default", 100))) * days, _purse_cap(npc_id))
		st["t"] = now_s

	return st


func stock_of(npc_id: String, item_id: String) -> int:
	return int(floor(float(_refresh(npc_id)["stock"].get(item_id, 0.0)) + 0.0001))


func purse_of(npc_id: String) -> int:
	return int(floor(float(_refresh(npc_id)["purse"])))


# What the player pays moves with supply: a full shelf is cheaper, an empty one dearer.
func supply(npc_id: String, item_id: String) -> float:
	var c: Dictionary = _stock_cfg()
	var rule: Array = _rule(npc_id, item_id)
	var fill: float = float(_refresh(npc_id)["stock"].get(item_id, 0.0)) / maxf(rule[0], 1.0)
	return clampf(1.0 + (0.5 - fill) * float(c.get("supply_strength", 0.3)), float(c.get("supply_min", 0.85)), float(c.get("supply_max", 1.2)))


func has_shop(npc_id: String) -> bool:
	return typeof(_shops.get(npc_id, null)) == TYPE_DICTIONARY


func _cfg() -> Dictionary:
	return items._coins_cfg.get("trade", {})


# What the player pays per unit of value (>= min_sell) and what the trader pays per unit of value (<= max_buy), as multiples.
func multipliers(peer: int, npc_id: String) -> Dictionary:
	var c: Dictionary = _cfg()
	var rank_index: int = 0
	var ranks: Array = items._rep_cfg.get("ranks", [])
	var word: String = items.rank_of(items.rep_points(peer, npc_id))

	for i in ranks.size():
		if str(ranks[i]["name"]) == word:
			rank_index = i

	var charisma: float = float(items.attributes_of(peer).get("charisma", 0.0))
	var shift: float = float(rank_index) * float(c.get("rep_step", 0.04)) + charisma * float(c.get("charisma_step", 0.01)) + float(items.luck_of(peer)) * float(c.get("luck_strength", 0.04)) * float(c.get("luck_share", 0.25))
	var sell: float = maxf(float(c.get("sell_markup", 1.3)) - shift, float(c.get("min_sell", 1.05)))
	var buy: float = minf(float(c.get("buy_discount", 0.55)) + shift, float(c.get("max_buy", 0.9)))
	return {"pay": sell, "get": buy, "shift": shift}


func _clock() -> float:
	return float(now.call()) if now.is_valid() else Time.get_unix_time_from_system()


# 1.0 for an item the trader has not been selling lately, falling with each unit you sell, to the floor.
func demand(npc_id: String, item_id: String) -> float:
	var c: Dictionary = _cfg().get("demand", {})
	var rec: Array = _sold.get("%s|%s" % [npc_id, item_id], [0.0, 0.0])
	var n: float = maxf(float(rec[0]) - float(c.get("recover_per_min", 4.0)) * (_clock() - float(rec[1])) / 60.0, 0.0)
	return clampf(1.0 - n * float(c.get("drop_per_sale", 0.03)), float(c.get("floor", 0.3)), 1.0)


func _note_sale(npc_id: String, item_id: String, count: int) -> void:
	var c: Dictionary = _cfg().get("demand", {})
	var key: String = "%s|%s" % [npc_id, item_id]
	var rec: Array = _sold.get(key, [0.0, 0.0])
	var n: float = maxf(float(rec[0]) - float(c.get("recover_per_min", 4.0)) * (_clock() - float(rec[1])) / 60.0, 0.0)
	_sold[key] = [n + float(count), _clock()]


func price_to_pay(value: int, mult: float) -> int:
	return maxi(int(ceil(float(value) * mult - 0.0001)), 1) if value > 0 else 0


func price_to_get(value: int, mult: float, life: float = 1.0) -> int:
	if value <= 0 or life <= 0.0:
		return 0

	return maxi(int(floor(float(value) * mult * life + 0.0001)), 1)


# The trader's window: the player is close enough to talk and the NPC trades.
func open(peer: int, npc_id: String) -> bool:
	if not has_shop(npc_id) or not _near(peer, npc_id) or not send_shop.is_valid():
		return false

	var m: Dictionary = multipliers(peer, npc_id)
	var shop: Dictionary = _shops[npc_id]
	var ids: PackedStringArray = PackedStringArray()

	for id in shop.get("stock", []):
		if items.table.number_of(str(id)) > 0:
			ids.append(str(id))

	var kinds: PackedStringArray = PackedStringArray()

	for k in shop.get("buys", []):
		kinds.append(str(k))

	var tired_ids: PackedStringArray = PackedStringArray()
	var tired: PackedInt32Array = PackedInt32Array()

	for key in _sold:
		var parts: PackedStringArray = str(key).split("|")

		if parts[0] == npc_id and demand(npc_id, parts[1]) < 0.999:
			tired_ids.append(parts[1])
			tired.append(int(round(demand(npc_id, parts[1]) * 1000.0)))

	var counts: PackedInt32Array = PackedInt32Array()
	var supply_milli: PackedInt32Array = PackedInt32Array()

	for id in ids:
		counts.append(stock_of(npc_id, id))
		supply_milli.append(int(round(supply(npc_id, id) * 1000.0)))

	send_shop.call(peer, npc_id, str(shop.get("title", "Trade")), ids, int(round(float(m["pay"]) * 1000.0)), int(round(float(m["get"]) * 1000.0)), kinds, tired_ids, tired, counts, supply_milli, purse_of(npc_id))
	return true


func _near(peer: int, npc_id: String) -> bool:
	var at: Variant = items.position_of(peer)

	if at == null or not npcs.npcs.has(npc_id):
		return false

	var npc: Dictionary = npcs.npcs[npc_id]
	return not npc["dormant"] and npc["placed"] and Vector2(npc["pos"].x - at.x, npc["pos"].z - at.z).length() <= TALK_RANGE_M


# kind 0 buy: a = index into the shop's stock list as opened; kind 1 sell: a = pack slot. Returns a short text for the player.
func deal(peer: int, npc_id: String, kind: int, a: int, count: int) -> String:
	if not has_shop(npc_id) or not _near(peer, npc_id):
		return ""

	count = clampi(count, 1, 999)
	var inv = items.inventory_of(peer)

	if inv == null:
		return ""

	var m: Dictionary = multipliers(peer, npc_id)
	var shop: Dictionary = _shops[npc_id]

	if kind == 3:
		return _sell_extras(peer, npc_id, inv)

	if kind == 0:
		var ids: Array = []

		for id in shop.get("stock", []):
			if items.table.number_of(str(id)) > 0:
				ids.append(str(id))

		if a < 0 or a >= ids.size():
			return ""

		var number: int = items.table.number_of(str(ids[a]))
		var each: int = price_to_pay(int(items.table.entry(str(ids[a])).get("value", 0)), float(m["pay"]) * supply(npc_id, str(ids[a])))
		var shelf: int = stock_of(npc_id, str(ids[a]))

		if shelf <= 0:
			return "He has none left."

		count = mini(count, shelf)
		count = mini(count, items._fit(peer, inv, number, count))

		if count <= 0:
			return "You cannot carry any more."

		if items.coins_of(peer) < each * count:
			return "You cannot afford that."

		items.take_coins(peer, each * count)
		var st: Dictionary = _refresh(npc_id)
		st["stock"][str(ids[a])] = float(st["stock"][str(ids[a])]) - float(count)
		st["purse"] = minf(float(st["purse"]) + float(each * count), _purse_cap(npc_id))   # the coin goes into his till
		save()
		items._gain_source = "trade"
		items.give(peer, number, count)
		items._gain_source = items.SRC_PICKUP
		return "Bought %d %s for %s." % [count, items.table.name_of(number).to_lower(), items._coin_words(each * count)]

	if a < 0 or a >= inv.SLOTS or inv.numbers[a] == 0:
		return ""

	if kind == 2:
		return _repair_deal(peer, npc_id, inv, a, float(m["pay"]))

	var number2: int = inv.numbers[a]
	var entry: Dictionary = items.table.entry(items.table.id_of(number2))
	var kinds: Array = shop.get("buys", [])

	if not kinds.has("all") and not kinds.has(str(entry.get("kind", ""))):
		return "The trader does not buy that."

	var life: float = 1.0
	var durability: int = int(entry.get("durability", 0))

	if durability > 0:
		life = clampf(1.0 - float(inv.wear[a]) / float(durability), 0.0, 1.0)

	if items.table.shelf_units(number2) > 0:
		life = minf(life, items.table.freshness(number2, inv.wear[a]))

	count = mini(count, inv.counts[a])
	var item_id: String = items.table.id_of(number2)
	var value: int = int(entry.get("value", 0))
	var total: int = 0
	var paid_for: int = 0
	var base_demand: float = demand(npc_id, item_id)
	var drop: float = float(_cfg().get("demand", {}).get("drop_per_sale", 0.03))
	var floor_d: float = float(_cfg().get("demand", {}).get("floor", 0.3))

	var st2: Dictionary = _refresh(npc_id)
	var till: int = int(floor(float(st2["purse"])))

	# Each unit sold lowers the price of the next; the trader can only pay what is in his purse.
	for k in count:
		var each_k: int = price_to_get(value, float(m["get"]) * maxf(base_demand - drop * float(k), floor_d), life)

		if each_k <= 0 or total + each_k > till:
			break

		total += each_k
		paid_for += 1

	if paid_for <= 0:
		return "He cannot pay for that just now." if till < price_to_get(value, float(m["get"]), life) else "That is worth nothing."

	count = paid_for
	st2["purse"] = float(st2["purse"]) - float(total)

	if st2["stock"].has(item_id):   # what he stocks goes back on the shelf
		st2["stock"][item_id] = minf(float(st2["stock"][item_id]) + float(count), _rule(npc_id, item_id)[0])

	save()
	_note_sale(npc_id, item_id, count)
	var before: Array = items._snapshot(inv)
	inv.counts[a] -= count

	if inv.counts[a] <= 0:
		inv.numbers[a] = 0
		inv.counts[a] = 0
		inv.wear[a] = 0

	items._gain_quiet = true
	items._send_changes(peer, inv, before)
	items._gain_quiet = false
	items._dirty = true
	items.add_coins(peer, total, "trade")
	return "Sold %d %s for %s." % [count, items.table.name_of(number2).to_lower(), items._coin_words(total)]


# kind 3, "Would you like to buy my extra stuff?" (Dave 2026-10-22): one click sells every pack stack of the kinds coins.json
# trade.sell_extras lists that the trader buys and that is worth less than valuable_from copper each. Tools, weapons, coins, gear,
# clothing, kits and anything worth more are never swept. Each stack is an ordinary sale (same prices, demand and purse limits).
func _sell_extras(peer: int, npc_id: String, inv) -> String:
	var rule: Dictionary = _cfg().get("sell_extras", {})
	var kinds: Array = rule.get("kinds", ["material", "food", "medicine"])
	var below: int = int(rule.get("valuable_from", 50))
	var buys: Array = _shops[npc_id].get("buys", [])
	var before_coins: int = items.coins_of(peer)
	var sold: int = 0

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] == 0:
			continue

		var entry: Dictionary = items.table.entry(items.table.id_of(inv.numbers[slot]))
		var item_kind: String = str(entry.get("kind", ""))

		if not kinds.has(item_kind) or str(entry.get("tool_class", "")) != "" or int(entry.get("value", 0)) >= below:
			continue

		if not buys.has("all") and not buys.has(item_kind):
			continue

		var number_before: int = inv.counts[slot]

		if deal(peer, npc_id, 1, slot, 999) != "" and (inv.numbers[slot] == 0 or inv.counts[slot] < number_before):
			sold += 1

	if sold == 0:
		return "You have no extra stuff he will buy."

	return "Sold %d kinds of extra stuff for %s." % [sold, items._coin_words(items.coins_of(peer) - before_coins)]


# What a smith asks to mend the tool in a pack slot (0 = nothing to mend).
func repair_cost(number: int, item_wear: int, pay_mult: float) -> int:
	var entry: Dictionary = items.table.entry(items.table.id_of(number))
	var durability: int = int(entry.get("durability", 0))
	var value: int = int(entry.get("value", 0))

	if durability <= 0 or item_wear <= 0 or value <= 0:
		return 0

	var used: float = clampf(float(item_wear) / float(durability), 0.0, 1.0)
	return maxi(int(ceil(float(value) * float(_cfg().get("repair", {}).get("rate", 0.4)) * used * pay_mult - 0.0001)), 1)


func _repair_deal(peer: int, npc_id: String, inv, slot: int, pay_mult: float) -> String:
	if not bool(_shops[npc_id].get("repairs", false)):
		return "He does not mend tools."

	var cost: int = repair_cost(inv.numbers[slot], inv.wear[slot], pay_mult)

	if cost <= 0:
		return "That needs no mending."

	if items.coins_of(peer) < cost:
		return "You cannot afford that."

	var name_of: String = items.table.name_of(inv.numbers[slot]).to_lower()
	items.take_coins(peer, cost)
	var before: Array = items._snapshot(inv)
	inv.wear[slot] = 0
	items._send_changes(peer, inv, before)
	items._dirty = true
	var st: Dictionary = _refresh(npc_id)
	st["purse"] = minf(float(st["purse"]) + float(cost), _purse_cap(npc_id))
	save()
	return "%s Your %s is as good as new for %s." % [str(_cfg().get("repair", {}).get("say_done", "Mended.")), name_of, items._coin_words(cost)]
