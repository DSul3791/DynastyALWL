extends RefCounted

# Shop trading (Radar, 2026-10-21, Dave: traders buy at a discount and sell at a markup moved by reputation, charisma and luck).
# data/npcs/shops.json says who trades what; data/items/coins.json "trade" holds every number. The prices are the same number
# for every item (a multiple of its value), so the server sends two multipliers and the client prices what it shows; the server
# prices every deal itself.

const TALK_RANGE_M := 4.5

var items                       # ServerItems
var npcs                        # ServerNpcs
var send_shop: Callable         # (peer, npc id, title, stock ids, buy_milli, sell_milli, buys kinds)
var _shops: Dictionary = {}


func setup() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/shops.json"))
	_shops = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


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

	send_shop.call(peer, npc_id, str(shop.get("title", "Trade")), ids, int(round(float(m["pay"]) * 1000.0)), int(round(float(m["get"]) * 1000.0)), kinds)
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

	if kind == 0:
		var ids: Array = []

		for id in shop.get("stock", []):
			if items.table.number_of(str(id)) > 0:
				ids.append(str(id))

		if a < 0 or a >= ids.size():
			return ""

		var number: int = items.table.number_of(str(ids[a]))
		var each: int = price_to_pay(int(items.table.entry(str(ids[a])).get("value", 0)), float(m["pay"]))
		count = mini(count, items._fit(peer, inv, number, count))

		if count <= 0:
			return "You cannot carry any more."

		if items.coins_of(peer) < each * count:
			return "You cannot afford that."

		items.take_coins(peer, each * count)
		items._gain_source = "trade"
		items.give(peer, number, count)
		items._gain_source = items.SRC_PICKUP
		return "Bought %d %s for %s." % [count, items.table.name_of(number).to_lower(), items._coin_words(each * count)]

	if a < 0 or a >= inv.SLOTS or inv.numbers[a] == 0:
		return ""

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

	var each2: int = price_to_get(int(entry.get("value", 0)), float(m["get"]), life)

	if each2 <= 0:
		return "That is worth nothing."

	count = mini(count, inv.counts[a])
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
	items.add_coins(peer, each2 * count, "trade")
	return "Sold %d %s for %s." % [count, items.table.name_of(number2).to_lower(), items._coin_words(each2 * count)]
