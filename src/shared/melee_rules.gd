extends RefCounted

# Anything in hand is a weapon (Dave 19 Nov 2026; data/items/melee.json). Shared: the server rules on the blow (server_items.gd _strike), the
# client uses the reach to know a left click is aimed at an animal (held_item.gd).

const PATH := "res://data/items/melee.json"


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# One blow of the item `entry` (an items.json row) when it has no damage of its own: {"damage", "mode", "reach_m"}. A row with damage (a spear, a
# sword) keeps its own numbers (server_items.weapon_blow; its reach is its reach_m, else 3 m), so its damage here is 0.
static func blow(entry: Dictionary, cfg: Dictionary) -> Dictionary:
	var reach: float = float(cfg.get("reach_m", 2.5))

	if float(entry.get("damage", 0.0)) > 0.0:
		return {"damage": 0.0, "mode": str(entry.get("damage_mode", "blunt")), "reach_m": float(entry.get("reach_m", 3.0))}

	var row: Dictionary = {}
	var tiered: bool = false
	var kind: String = str(entry.get("kind", ""))

	if kind == "tool":
		row = (cfg.get("tool", {}) as Dictionary).get("tool_" + str(entry.get("tool_class", "")), cfg.get("tool_default", {}))
		tiered = true
	elif kind == "weapon":
		row = cfg.get("weapon_no_damage", {})
		tiered = true
	else:
		row = cfg.get("other", {})

	var damage: float = float(row.get("damage", 1.0))

	if tiered:
		damage += float(cfg.get("tier_step", 1.0)) * maxf(0.0, float(entry.get("tier", cfg.get("base_tier", 2))) - float(cfg.get("base_tier", 2)))

	return {"damage": maxf(damage, 1.0), "mode": str(row.get("mode", "blunt")), "reach_m": float(row.get("reach_m", reach))}
