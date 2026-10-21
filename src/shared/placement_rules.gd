extends RefCounted

# Where a kit may be set down (data/items/structures.json), shared by the client's ghost and the server's check so
# both say the same thing. The server still decides; the ghost only shows it early: red when blocked.
# rows: world items as {"pos": Vector3, "state": int} (fires are states 1, 8, 9; structures 5, 6, 7).

const PATH := "res://data/items/structures.json"
const CHUNK_M := 256.0
const FIRE_STATES := [1, 8, 9]
const STRUCTURE_STATES := [5, 6, 7]


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# The structure a kit places (its row with "kind" added), {} for the campfire kit and for anything else.
static func structure_of_kit(cfg: Dictionary, kit_id: String) -> Dictionary:
	for kind in cfg.get("structures", {}):
		var def: Dictionary = cfg["structures"][kind]

		if str(def.get("kit", "")) == kit_id:
			var out: Dictionary = def.duplicate()
			out["kind"] = kind
			return out

	return {}


# The ghost's footprint in metres: zero for a campfire (drawn as a ring).
static func footprint(cfg: Dictionary, kit_id: String) -> Vector2:
	var def: Dictionary = structure_of_kit(cfg, kit_id)
	return Vector2(float(def.get("footprint_x", 0.0)), float(def.get("footprint_z", 0.0))) if not def.is_empty() else Vector2.ZERO


static func fire_gap_m(cfg: Dictionary) -> float:
	return float(cfg.get("campfire", {}).get("gap_m", 2.0))


static func fires_per_chunk(cfg: Dictionary) -> int:
	return int(cfg.get("campfire", {}).get("cap_per_chunk", 8))


static func _chunk(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CHUNK_M)), int(floor(p.z / CHUNK_M)))


# "" when the spot is free, else why not: "close" (too near a fire or a structure) or "crowded" (the chunk's cap).
static func blocked(cfg: Dictionary, kit_id: String, spot: Vector3, rows: Array) -> String:
	var gap: float = float(cfg.get("gap_m", 2.5))
	var def: Dictionary = structure_of_kit(cfg, kit_id)
	var same: int = 0

	for row in rows:
		var state: int = int(row["state"])

		if def.is_empty():
			# A campfire: not within its own gap of another fire, nor within a structure's gap.
			if FIRE_STATES.has(state):
				if row["pos"].distance_to(spot) < fire_gap_m(cfg):
					return "close"

				if _chunk(row["pos"]) == _chunk(spot):
					same += 1
			elif STRUCTURE_STATES.has(state) and row["pos"].distance_to(spot) < gap:
				return "close"
		else:
			if (FIRE_STATES.has(state) or STRUCTURE_STATES.has(state)) and row["pos"].distance_to(spot) < gap:
				return "close"

			if int(def.get("state", -1)) == state and _chunk(row["pos"]) == _chunk(spot):
				same += 1

	var cap: int = fires_per_chunk(cfg) if def.is_empty() else int(def.get("cap_per_chunk", 99))
	return "crowded" if same >= cap else ""
