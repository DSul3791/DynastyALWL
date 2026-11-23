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


# One weight as a player reads it (Dave 23 Nov 2026: "typical seeds weigh 5-7mg"): kilograms from 1 kg, grams from 1 g, milligrams below that,
# with enough figures that a tiny weight never rounds to a wrong one; under 0.01 mg it says so.
static func weight_text(kg: float) -> String:
	if kg >= 1.0:
		return "%.2f kg" % kg

	if kg >= 0.001:
		return _figures(kg * 1000.0) + " g"

	if kg >= 0.00000001:
		return _figures(kg * 1000000.0) + " mg"

	return "under 0.01 mg" if kg > 0.0 else "0 g"


# A value of 1 to 999 with three figures at most and no trailing zeros: 640, 64, 6.4, 0.64.
static func _figures(v: float) -> String:
	var text: String = "%.0f" % v if v >= 100.0 else ("%.1f" % v if v >= 10.0 else "%.2f" % v)

	if text.contains("."):
		text = text.rstrip("0").rstrip(".")

	return text


# Kilograms an inventory holds, with what each bag in it holds (catalog Phase 5).
static func carried_kg(inventory, table, cfg: Dictionary) -> float:
	var total: float = 0.0

	for slot in range(inventory.usable):
		if inventory.numbers[slot] != 0:
			total += _stack_kg(inventory.numbers[slot], inventory.counts[slot], inventory.wear[slot], table, cfg) + bag_kg(inventory.inst[slot], table, cfg)

	return total


static func _stack_kg(number: int, count: int, wear: int, table, cfg: Dictionary) -> float:
	var id: String = table.id_of(number)
	var kg: float = weight_of(id, cfg) * float(count)

	# A container carries its water in the wear field (millilitres); a litre weighs a kilogram.
	if int(table.entry(id).get("capacity_ml", 0)) > 0:
		kg += float(wear) / 1000.0

	return kg


# Kilograms of what a bag holds (its instance data's `bag` rows, src/shared/bag_rules.gd): a bag's load counts in full wherever the bag is, worn or in the pack
# (a backpack's carry_bonus_kg raises the limit, not the load).
static func bag_kg(item_inst: Dictionary, table, cfg: Dictionary) -> float:
	var total: float = 0.0

	for row in item_inst.get("bag", []):
		if int(row[0]) != 0:
			total += _stack_kg(int(row[0]), int(row[1]), int(row[2]), table, cfg)

	return total


# Extra kilograms the worn pieces let the body carry (items.json carry_bonus_kg: a worn back pack spreads its load, a better one more; one back:base piece is worn at a time), 0 for none.
# Only the carry limit moves: the comfortable load is free_ratio of it, so both rise together.
static func carry_bonus_kg(numbers, table) -> float:
	var total: float = 0.0

	for number in numbers:
		if int(number) > 0:
			total += float(table.entry(table.id_of(int(number))).get("carry_bonus_kg", 0.0))

	return total


# The body weight the carry limit is worked out from, on the server and the client alike: the real weight plus what the worn pieces' weight
# spreading adds (cap = ratio x body, so the limit rises by the bonus itself).
static func carry_body_kg(weight_kg: float, worn_numbers, table, cfg: Dictionary) -> float:
	return weight_kg + carry_bonus_kg(worn_numbers, table) / maxf(float(cfg.get("carry_kg_per_body_kg", 0.7)), 0.01)


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


# No item weighs less than this when counting how many fit, so a weight of zero (or a typo) can never make a stack free to carry.
const MIN_EACH_KG := 0.0005
# Float sums drift by a few millionths of a kilo; a pick-up is only allowed if the total stays within the cap plus this.
const SLACK_KG := 0.000001


# How the load feels (carry feel, 23 Nov 2026), one set of thresholds for the pack window and anything on the HUD: 0 comfortable, 1 heavy (slower),
# 2 at the limit (within 2 percent: the slowest walk), 3 over it (past the client's rounding of the body, up to 35 g).
static func load_state(load_kg: float, body_kg: float, cfg: Dictionary) -> int:
	var limit: float = cap_kg(body_kg, cfg)

	if load_kg <= comfort_kg(body_kg, cfg):
		return 0

	if load_kg > limit + 0.05:
		return 3

	return 2 if load_kg >= limit * 0.98 else 1


# How many of `count` more of an item fit before the hard cap. Never more than fit: the floor of the division is checked
# against the real sum, so rounding in the division cannot push the pack past the limit.
static func fit_count(item_id: String, count: int, carried: float, body_kg: float, cfg: Dictionary) -> int:
	var each: float = maxf(weight_of(item_id, cfg), MIN_EACH_KG)
	var cap: float = cap_kg(body_kg, cfg)
	var room: float = cap - carried
	var fits: int = clampi(int(floorf(room / each + SLACK_KG)), 0, count)

	while fits > 0 and carried + float(fits) * each > cap + SLACK_KG:
		fits -= 1

	return fits


# --- Logs on the shoulder (TREE_WOOD_TOOLS_DESIGN.md s1.2, s5; Dave 15 Nov 2026: a character carries up to two logs) ---
# A shoulder log is any pack item whose items.json "carry" is "shoulder". weights.json "shoulder_logs_max" is how many one body carries (the server refuses a third,
# the client shows that many). Server and client count them in their own pack through the same helper.
const COUNT_WORDS := ["no", "one", "two", "three", "four"]


# What a refused extra log is told: "You can carry two logs at most. Put one down first (Q)." for the weights.json limit.
static func logs_full_say(cfg: Dictionary) -> String:
	var most: int = shoulder_max(cfg)
	return "You can carry %s log%s at most. Put one down first (Q)." % [COUNT_WORDS[most] if most < COUNT_WORDS.size() else str(most), "" if most == 1 else "s"]


static func shoulder_max(cfg: Dictionary) -> int:
	return maxi(int(cfg.get("shoulder_logs_max", 2)), 1)


# The item ids of the shoulder logs in an inventory, in slot order.
static func shoulder_logs(inventory, table) -> Array:
	var out: Array = []

	for slot in range(inventory.slot_count):
		if inventory.numbers[slot] != 0 and str(table.entry(table.id_of(inventory.numbers[slot])).get("carry", "")) == "shoulder":
			out.append(table.id_of(inventory.numbers[slot]))

	return out
