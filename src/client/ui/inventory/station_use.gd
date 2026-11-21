extends RefCounted

# What the open store can take (Dave 10 Nov 2026: "it should work with every station of any type. only the stuff you can use in it go to
# the top with the yellow outline"; 17 Nov 2026: a campfire lit fiddleheads it would refuse). With the pack open, pack_grid sorts these to the
# top and item_slot draws the golden line round them (data/ui/station_highlight.json). Nothing is hand-listed, and what a store takes is the
# server's own rule (store_rules.gd), so the line never marks a thing the put would refuse:
#   a fire       what its store takes: cooking.json fuel (FUEL) and the food it cooks (INPUT). A campfire recipe's other ingredients
#                (herbs, eggs, clay) stay in the pack for the Craft button; the fire does not take them.
#   a container  that names what it takes (structures.json "takes" / "takes_kinds": kilns, smelters, racks, bins, the chopping block,
#                a sled): exactly those, wood a fire burns as FUEL
#   a station    that takes anything (a workbench's store): the ingredients of its recipes and of the stations it stands in for, as INPUT
#   its own fuel (a torch, a fireplace, a chandelier, a smithy's "fuel"): FUEL
# A thing that is both is FUEL. A plain chest that takes anything lights nothing.

const StoreRules := preload("res://src/shared/store_rules.gd")

const FUEL := 0
const INPUT := 1

static var _cache: Dictionary = {}


# number -> FUEL or INPUT for the open store: `stations` the station names (recipes.json "station"), `fire` whether it is a fire, `fuel_ids`
# its own fuel, `kind` a key for its structures.json row (its state) and `def` that row ({} for a fire). Cached by those, so the pack can ask on every refresh.
static func usable(stations: Array, fire: bool, fuel_ids: Array, recipes, table, cooking: Dictionary, kind: String = "", def: Dictionary = {}) -> Dictionary:
	var limited: bool = StoreRules.limited(def)

	if stations.is_empty() and not fire and fuel_ids.is_empty() and not limited:
		return {}

	var names: Array = stations.duplicate()
	names.sort()
	var fuels: Array = fuel_ids.duplicate()
	fuels.sort()
	var key: String = "%s|%s|%s|%s" % [",".join(names), str(fire), ",".join(fuels), kind if limited else ""]

	if _cache.has(key):
		return _cache[key]

	var out: Dictionary = {}

	for id in fuel_ids:
		_add(out, table.number_of(str(id)), FUEL)

		for member in table.group_members(table.number_of(str(id))):   # a group's members (a smithy's "fuel": Coal and Charcoal)
			_add(out, member, FUEL)

	if fire:
		for id in table.ids():
			if StoreRules.fire_takes(str(id), cooking):
				_add(out, table.number_of(str(id)), FUEL if cooking.get("fuel", {}).has(str(id)) else INPUT)
	elif limited:
		for id in table.ids():
			var number: int = table.number_of(str(id))

			if StoreRules.takes(def, number, table):
				_add(out, number, FUEL if cooking.get("fuel", {}).has(str(id)) else INPUT)
	elif recipes != null:
		for number in recipes.numbers():
			var r: Dictionary = recipes.recipe(number)

			if str(r.get("station", "")) == "" or not stations.has(str(r["station"])):
				continue

			for need in r.get("needs", []):
				var members: PackedInt32Array = table.group_members(int(need[0]))

				if members.is_empty():
					_add(out, int(need[0]), INPUT)
				else:
					for member in members:
						_add(out, int(member), INPUT)

	if _cache.size() > 64:
		_cache.clear()

	_cache[key] = out
	return out


# Food a fire cooks (store_rules.gd, the server's rule).
static func cookable(item_id: String, cooking: Dictionary) -> bool:
	return StoreRules.cookable(item_id, cooking)


static func _add(out: Dictionary, number: int, group: int) -> void:
	if number > 0 and (not out.has(number) or group < int(out[number])):
		out[number] = group
