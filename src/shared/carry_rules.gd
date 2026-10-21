extends RefCounted

# How much a pack weighs and what that does (data/items/weights.json). Shared: the server enforces the
# hard cap and counts the load as work, the client shows the load and slows the walk.

const PATH := "res://data/items/weights.json"


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# Kilograms of one item.
static func weight_of(item_id: String, cfg: Dictionary) -> float:
	if cfg.get("by_id", {}).has(item_id):
		return float(cfg["by_id"][item_id])

	for suffix in cfg.get("by_suffix", {}):
		if item_id.ends_with(str(suffix)):
			return float(cfg["by_suffix"][suffix])

	return float(cfg.get("default_kg", 0.1))


# Kilograms an inventory holds.
static func carried_kg(inventory, table, cfg: Dictionary) -> float:
	var total: float = 0.0

	for slot in range(inventory.usable):
		if inventory.numbers[slot] != 0:
			total += weight_of(table.id_of(inventory.numbers[slot]), cfg) * float(inventory.counts[slot])

	return total


# The most a body carries (the server refuses to pick up more).
static func cap_kg(body_kg: float, cfg: Dictionary) -> float:
	return body_kg * float(cfg.get("carry_kg_per_body_kg", 0.7))


# Up to this much (free_ratio of the limit, 80 percent) nothing hinders: full speed, no extra effort (Dave 2026-10-21).
# The carry-weight bar (Dave 2026-10-21): fills toward the gross weight you can carry, green, yellow from 70 percent of it,
# red from 80 percent (where being slowed begins).
static func bar_fraction(carried: float, body_kg: float, cfg: Dictionary) -> float:
	return clampf(carried / maxf(cap_kg(body_kg, cfg), 0.001), 0.0, 1.0)


static func bar_color(fraction: float) -> Color:
	if fraction >= 0.8:
		return Color(0.85, 0.2, 0.2)

	return Color(0.95, 0.8, 0.25) if fraction >= 0.7 else Color(0.35, 0.75, 0.3)


static func comfort_kg(body_kg: float, cfg: Dictionary) -> float:
	return cap_kg(body_kg, cfg) * float(cfg.get("free_ratio", 0.8))


# 0 up to the free load, rising smoothly (in a straight line) to 1 at the limit: how much of the hindering band is used.
static func load_fraction(carried: float, body_kg: float, cfg: Dictionary) -> float:
	var free: float = comfort_kg(body_kg, cfg)
	var cap: float = cap_kg(body_kg, cfg)

	if carried <= free or cap <= free:
		return 0.0

	return clampf((carried - free) / (cap - free), 0.0, 1.0)


# Walking speed multiplier: 1 up to the free load (80 percent of the limit), easing down to min_speed at the limit.
static func speed_factor(carried: float, body_kg: float, cfg: Dictionary) -> float:
	var comfort: float = comfort_kg(body_kg, cfg)
	var cap: float = cap_kg(body_kg, cfg)

	if carried <= comfort or cap <= comfort:
		return 1.0

	var t: float = smoothstep(0.0, 1.0, clampf((carried - comfort) / (cap - comfort), 0.0, 1.0))
	return lerpf(1.0, float(cfg.get("min_speed", 0.35)), t)


# How many of `count` more of an item fit before the hard cap.
static func fit_count(item_id: String, count: int, carried: float, body_kg: float, cfg: Dictionary) -> int:
	var each: float = weight_of(item_id, cfg)

	if each <= 0.0:
		return count

	var room: float = cap_kg(body_kg, cfg) - carried
	return clampi(int(floorf(room / each)), 0, count)
