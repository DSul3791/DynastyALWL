extends RefCounted

# What the station you stand at can use (Dave 10 Nov 2026: "it should work with every station of any type. only the stuff you can use in it go to
# the top with the yellow outline"). With the pack open, pack_grid sorts these to the top and item_slot draws the golden line round them
# (data/ui/station_highlight.json). Nothing is hand-listed: it comes from the same data the server uses.
#   FUEL   what it burns: a fire's cooking.json fuel; a torch's, fireplace's or chandelier's own structures.json "fuel"
#   INPUT  what it takes in: every ingredient (or ingredient group member) of a recipe made at one of the stations here; for a fire also the food
#          it cooks (server_items._fire_takes: cooking.json cooks_into and cookable_suffixes)
# A thing that is both (a stick: a fire's fuel and a campfire recipe's ingredient) is FUEL.

const FUEL := 0
const INPUT := 1

static var _cache: Dictionary = {}


# number -> FUEL or INPUT for the stations here: `stations` the station names (recipes.json "station"), `fire` whether a fire is here, `fuel_ids`
# the structures' own fuel. Cached by those, so the pack can ask on every refresh.
static func usable(stations: Array, fire: bool, fuel_ids: Array, recipes, table, cooking: Dictionary) -> Dictionary:
	if stations.is_empty() and not fire and fuel_ids.is_empty():
		return {}

	var names: Array = stations.duplicate()
	names.sort()
	var fuels: Array = fuel_ids.duplicate()
	fuels.sort()
	var key: String = "%s|%s|%s" % [",".join(names), str(fire), ",".join(fuels)]

	if _cache.has(key):
		return _cache[key]

	var out: Dictionary = {}

	if fire:
		for id in cooking.get("fuel", {}):
			_add(out, table.number_of(str(id)), FUEL)

	for id in fuel_ids:
		_add(out, table.number_of(str(id)), FUEL)

	if recipes != null:
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

	if fire:
		for id in table.ids():
			if cookable(str(id), cooking):
				_add(out, table.number_of(str(id)), INPUT)

	if _cache.size() > 64:
		_cache.clear()

	_cache[key] = out
	return out


# Food a fire cooks (the same rule as server_items._cookable and container_panel.fire_takes).
static func cookable(item_id: String, cooking: Dictionary) -> bool:
	if item_id == "" or item_id == str(cooking.get("gives", "")):
		return false

	if cooking.get("cooks_into", {}).has(item_id):
		return true

	for suffix in cooking.get("cookable_suffixes", []):
		if item_id.ends_with(str(suffix)):
			return true

	return false


static func _add(out: Dictionary, number: int, group: int) -> void:
	if number > 0 and (not out.has(number) or group < int(out[number])):
		out[number] = group
