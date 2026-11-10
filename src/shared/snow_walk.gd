extends RefCounted

# Walking on snow (Part C plan 7, coordinator's yes 10 Nov 2026; data/items/snow_walk.json): on ground whose surface material is one of
# `soils` (snow, glacial ice) the walk is pace_mult as fast and exertion effort_mult as hard; worn Snowshoes (a worn item with
# "snow_walk": true) bring that to shod_pace_mult and shod_effort_mult. The client moves the body, so it applies the pace; the server's
# exertion follows the same rule. No snow depth exists yet (the lying weather snow is a 0..1 look, not metres), so the rule takes the
# surface material alone; with a depth, the multipliers would scale up from nothing to full at full_depth_m (coordinator, 10 Nov 2026).

const PATH := "res://data/items/snow_walk.json"
const SOILS_PATH := "res://data/tables/soils.json"

static var _cfg: Dictionary = {}
static var _soil_ids: Dictionary = {}     # soil id -> true for the snowy surfaces


static func config() -> Dictionary:
	if _cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"none": true}
		var soils: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOILS_PATH))

		if typeof(soils) == TYPE_DICTIONARY:
			for entry in soils.get("entries", []):
				if (_cfg.get("soils", []) as Array).has(str(entry.get("name", ""))):
					_soil_ids[int(entry["id"])] = true

	return _cfg


# The surface material by soil id (the client's voxel material) or by name (the server's ground_material).
static func soil_is_snow(soil_id: int) -> bool:
	config()
	return _soil_ids.has(soil_id)


static func name_is_snow(material: String) -> bool:
	return (config().get("soils", []) as Array).has(material)


# Snowshoes on: any worn item number whose row has "snow_walk": true.
static func shod(worn_numbers, table) -> bool:
	for number in worn_numbers:
		if int(number) > 0 and bool(table.entry(table.id_of(int(number))).get("snow_walk", false)):
			return true

	return false


static func pace_mult(on_snow: bool, wearing: bool) -> float:
	if not on_snow:
		return 1.0

	return float(config().get("shod_pace_mult" if wearing else "pace_mult", 1.0))


static func effort_mult(on_snow: bool, wearing: bool) -> float:
	if not on_snow:
		return 1.0

	return float(config().get("shod_effort_mult" if wearing else "effort_mult", 1.0))
