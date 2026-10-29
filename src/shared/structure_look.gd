extends RefCounted
# What each world-item state looks, sounds and clears like (Sal_Crafts, 2026-10-22), read from data/items/structures.json so a new piece is data plus
# its model function, not edits in four files. States 1, 8 and 9 are the campfire (lit, cold, loaded); 12 is old remains. States are never renumbered.

const PATH := "res://data/items/structures.json"
const CAMPFIRE_STATES := [1, 8, 9, 40, 41]

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if not _table.is_empty():
		return _table

	for state in CAMPFIRE_STATES:
		_table[state] = {"look": "campfire", "sound": "thump", "clears_grass": true}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))

	if typeof(parsed) == TYPE_DICTIONARY:
		var defs: Dictionary = parsed.get("structures", {})

		for kind in defs:
			var def: Dictionary = defs[kind]
			var state: int = int(def.get("state", -1))

			if state >= 0 and not _table.has(state) and def.has("look"):
				_table[state] = {"look": str(def["look"]), "sound": str(def.get("sound", "thump")), "clears_grass": bool(def.get("clears_grass", true)), "material": str(def.get("material", ""))}

	_table[12] = _table.get(11, {"look": "remains", "sound": "thump", "clears_grass": true})
	return _table


static func look_of(state: int) -> String:
	return str(table().get(state, {}).get("look", "chopping_block"))


# The placed-sound kind of a state, "" when it makes none.
static func sound_of(state: int) -> String:
	return str(table().get(state, {}).get("sound", ""))


# The material the piece is made of (structures.json "material": wood, iron, steel ...), "" when it has none. Never inferred from a name.
static func material_of(state: int) -> String:
	return str(table().get(state, {}).get("material", ""))


# True when a placed thing of this state clears grass around it.
static func clears_grass(state: int) -> bool:
	return bool(table().get(state, {}).get("clears_grass", false))
