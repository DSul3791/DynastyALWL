extends RefCounted

# What a store takes: a fire's store, a container's (structures.json "takes" / "takes_kinds") and a station's. One rule for both sides
# (Dave 17 Nov 2026: a campfire's window lit fiddleheads it would refuse): the server's put checks it (server_items._fire_takes, _box_takes)
# and the pack's golden line at an open store asks it (station_use.gd), so the two cannot drift apart again.


# Food a fire cooks: cooking.json cooks_into, or an id ending with one of cookable_suffixes; never the roast it gives.
static func cookable(item_id: String, cooking: Dictionary) -> bool:
	if item_id == "" or item_id == str(cooking.get("gives", "")):
		return false

	if cooking.get("cooks_into", {}).has(item_id):
		return true

	for suffix in cooking.get("cookable_suffixes", []):
		if item_id.ends_with(str(suffix)):
			return true

	return false


# Wood a fire burns (cooking.json fuel) or food it cooks: all a fire's store takes.
static func fire_takes(item_id: String, cooking: Dictionary) -> bool:
	return item_id != "" and (cooking.get("fuel", {}).has(item_id) or cookable(item_id, cooking))


# Whether the structure kind's def names what it takes. A def with neither "takes" nor "takes_kinds" takes anything.
static func limited(def: Dictionary) -> bool:
	return not (def.get("takes", []) as Array).is_empty() or not (def.get("takes_kinds", []) as Array).is_empty()


# Whether a container (its structures.json def) takes an item number: "takes_kinds" items.json kinds, "takes" item ids or ingredient groups (any member).
static func takes(def: Dictionary, number: int, table) -> bool:
	if not limited(def):
		return true

	if (def.get("takes_kinds", []) as Array).has(str(table.entry(table.id_of(number)).get("kind", ""))):
		return true

	for id in def.get("takes", []):
		var n: int = table.number_of(str(id))

		if n == number or table.group_members(n).has(number):
			return true

	return false
