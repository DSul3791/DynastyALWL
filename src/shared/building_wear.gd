extends RefCounted

# Building wear and repair rules (DESIGN_IDEAS.md Section 8.13, data/items/building_wear.json). Pure functions on the config so a test can run them.

const PATH := "res://data/items/building_wear.json"
const GAME_DAY_S := 3600.0


static func load_config(path: String = PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# {"T_s", "floor"} for a structure kind, or {} when it does not wear.
static func rule_for(cfg: Dictionary, kind: String) -> Dictionary:
	var material: String = str(cfg.get("kinds", {}).get(kind, ""))
	var row: Dictionary = cfg.get("materials", {}).get(material, {})

	if row.is_empty():
		return {}

	return {"T_s": float(row["T_game_days"]) * GAME_DAY_S, "floor": float(row["floor"])}


# 1.0 when new or just repaired, falling by the square of time since care over T to the material's floor.
static func condition(rule: Dictionary, cared_at_s: float, now_s: float) -> float:
	var share: float = clampf((now_s - cared_at_s) / maxf(float(rule["T_s"]), 1.0), 0.0, 1.0)
	return 1.0 - (1.0 - float(rule["floor"])) * share * share


# What a repair costs: [[item id, count], ...] from the blueprint's cost [[id, n], ...]; repair_share of each times the condition lost, rounded up, at least 1.
static func repair_needs(cost: Array, cond: float, repair_share: float) -> Array:
	var out: Array = []

	for need in cost:
		out.append([str(need[0]), maxi(1, int(ceil(float(need[1]) * (1.0 - cond) * repair_share)))])

	return out
