extends RefCounted

# A trader's prices, the same sums on the server (server_trade.gd prices every deal) and in the shop window (dialogue_view.gd shows them), so
# the window says what the server will really charge and pay (coordinator ruling for Dave, 23 Nov 2026). Cheap goods go by the lot (items.json
# sell_lot: 60 stones pay 1 copper, Dave 1 and 19 Nov 2026), both ways: the trader sells them by the lot too, so a stack bought off his shelf
# costs its share of the lot's price, never a copper a stone. A trader's own buy rule (shops.json buy_rules: lot, lot_value) sets the lot and
# its value for what he buys. Charged prices round up and paid prices down, and what is charged is never under what is paid for the same
# goods: the cheapest a shelf charges (min_sell x supply_min, 0.8925 of value) stays above the most any reachable standing is paid (top rank,
# charisma and luck: 0.87), so nothing is bought and sold straight back at a gain. The margin is small; test_town_trade_loop guards it.


# The lot and the value of one lot for the trader buying `entry` (an items.json row) under his buy rule `rule` (shops.json buy_rules, or {}),
# the value raised by craftsmanship `value_mult`. -> [lot, value of a lot].
static func sell_terms(entry: Dictionary, rule: Dictionary, value_mult: float = 1.0) -> Array:
	var lot: int = maxi(int(entry.get("sell_lot", 1)), 1)
	var value: int = int(round(float(entry.get("value", 0)) * value_mult))

	if not rule.is_empty():
		lot = maxi(int(rule.get("lot", lot)), 1)
		value = int(rule.get("lot_value", value))

	return [lot, value]


# The lot `entry` is sold from the trader's shelf in (items.json sell_lot; 1 for anything not cheap).
static func shelf_lot(entry: Dictionary) -> int:
	return maxi(int(entry.get("sell_lot", 1)), 1)


# What the trader charges for one lot worth `value` at `mult` (his markup times the shelf's supply): rounded up, at least 1 copper.
static func lot_to_pay(value: int, mult: float) -> int:
	return maxi(int(ceil(float(value) * mult - 0.0001)), 1) if value > 0 else 0


# What `count` units cost when a lot of `lot` costs `each`: their share of the lot price, rounded up, at least 1 copper for anything priced.
static func total_to_pay(each: int, lot: int, count: int) -> int:
	if each <= 0 or count <= 0:
		return 0

	return maxi(int(ceil(float(each) * float(count) / float(maxi(lot, 1)) - 0.0001)), 1)


# What the trader pays for one lot worth `value` at `mult` (his discount times his demand) and `life` (a worn tool, old food): rounded down,
# at least 1 copper for anything with life left.
static func lot_to_get(value: int, mult: float, life: float = 1.0) -> int:
	if value <= 0 or life <= 0.0:
		return 0

	return maxi(int(floor(float(value) * mult * life + 0.0001)), 1)


# One sale of `count` units of a thing the trader pays `value` a lot for (lots of `lot`), as the server makes it and the window estimates it
# (Dave 24 Nov 2026: the sell-all line said "about 9 silver" and the purse held far less). Each unit sold lowers the next one's price by
# `drop` of the base, from `base_demand` down to `floor_d` (coins.json trade.demand); a lot's copper is paid with its last unit; and the trader
# stops once the next price would take more than `till`, his purse. -> [units bought, copper paid]: units he cannot pay for stay with the seller.
static func sale(value: int, lot: int, count: int, get_mult: float, base_demand: float, drop: float, floor_d: float, life: float, till: int) -> Array:
	var total: int = 0
	var paid_for: int = 0
	lot = maxi(lot, 1)

	for k in count:
		var each_k: int = lot_to_get(value, get_mult * maxf(base_demand - drop * float(k), floor_d), life)

		if each_k <= 0 or total + each_k > till:
			break

		if (k + 1) % lot == 0:   # the lot's copper is paid with its last unit
			total += each_k

		paid_for += 1

	return [paid_for - paid_for % lot, total]
