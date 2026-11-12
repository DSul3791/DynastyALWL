extends RefCounted

# Tool care and smithing variants (catalog Phase 2c: master s2.2, s2.7 items 5-6, s2.9, s4 items 1, 2, 15, 16). Pure static rules shared by the
# server (server_items.gd, server_trade.gd) and the client (tooltips, the recipe card); every number is in data/items/smithing.json (s5 tuning).
# An instance is Inventory's per-slot Dictionary (sharp, max_d, temper, craft, magic; T04). A variant code is what a craft request carries:
# bit 0 Tempered, bits 1-2 the craftsmanship level (0, 1 or 2), so 0 is the plain item.

const InventoryScript := preload("res://src/shared/inventory.gd")
const PATH := "res://data/items/smithing.json"
const TEMPERED := 1

static var _cfg: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {"none": true}

	return _cfg


static func code(tempered: bool, craft: int) -> int:
	return (TEMPERED if tempered else 0) | (clampi(craft, 0, 2) << 1)


static func tempered_in(variant: int) -> bool:
	return (variant & TEMPERED) != 0


static func craft_in(variant: int) -> int:
	return mini((variant >> 1) & 3, 2)


# A code a client may send: 0 to 5, craftsmanship at most 2.
static func valid(variant: int) -> bool:
	return variant >= 0 and variant <= 5


# "Plain", "Tempered", "+1", "Tempered +2".
static func label(variant: int) -> String:
	var parts: PackedStringArray = PackedStringArray()

	if tempered_in(variant):
		parts.append("Tempered")

	if craft_in(variant) > 0:
		parts.append("+%d" % craft_in(variant))

	return "Plain" if parts.is_empty() else " ".join(parts)


# The item's current maximum durability: the instance's max_d, else the row's durability (0 for an item that does not wear).
static func max_of(entry: Dictionary, item_inst: Dictionary) -> int:
	return int(item_inst["max_d"]) if item_inst.has("max_d") else int(entry.get("durability", 0))


# A row that wears and has no repair materials is disposable (s2.2 rules 1-3): gone when it breaks.
static func disposable(entry: Dictionary) -> bool:
	return int(entry.get("durability", 0)) > 0 and (entry.get("repair", []) as Array).is_empty()


# Sharpness used at which an edge tool is fully dull (0 for a row without an edge). Tempered and craftsmanship dull more slowly.
static func dull_at(entry: Dictionary, item_inst: Dictionary) -> int:
	if not bool(entry.get("edge", false)) or int(entry.get("durability", 0)) <= 0:
		return 0

	var c: Dictionary = cfg()
	var slower: float = 1.0 + float(c.get("craft", {}).get("dull_slower", 0.0)) * float(item_inst.get("craft", 0))

	if int(item_inst.get("temper", 0)) == 1:
		slower += float(c.get("temper", {}).get("dull_slower", 0.0))

	return maxi(int(round(float(entry["durability"]) * float(c.get("dull_share", 0.1)) * slower)), 1)


# 1.0 sharp down to 0.0 fully dull; 1.0 for a row without an edge.
static func sharpness(entry: Dictionary, item_inst: Dictionary) -> float:
	var at: int = dull_at(entry, item_inst)
	return 1.0 if at <= 0 else clampf(1.0 - float(item_inst.get("sharp", 0)) / float(at), 0.0, 1.0)


static func is_dull(entry: Dictionary, item_inst: Dictionary) -> bool:
	var at: int = dull_at(entry, item_inst)
	return at > 0 and int(item_inst.get("sharp", 0)) >= at


# Seconds to sharpen this tool fully on a whetstone ("whetstone") or the grindstone ("grindstone"): full_s for a fully dull one, less in proportion.
static func sharpen_s(entry: Dictionary, item_inst: Dictionary, how: String) -> float:
	var at: int = dull_at(entry, item_inst)
	return 0.0 if at <= 0 else float(cfg().get(how, {}).get("full_s", 300.0)) * minf(float(item_inst.get("sharp", 0)) / float(at), 1.0)


# The maximum durability a sharpening that restored `restored` sharpness units costs: sharpen_cost of the row's durability for a full one.
static func sharpen_loss(entry: Dictionary, item_inst: Dictionary, restored: int) -> int:
	var at: int = dull_at(entry, item_inst)

	if at <= 0 or restored <= 0:
		return 0

	return int(ceil(float(entry["durability"]) * float(cfg().get("sharpen_cost", 0.02)) * minf(float(restored) / float(at), 1.0) - 0.0001))


# Craftsmanship eligibility (s2.9 item 7): one unstackable item of the eligible kinds per craft.
static func craft_ok(entry: Dictionary, gives_count: int) -> bool:
	return gives_count == 1 and bool(entry.get("unstackable", false)) and cfg().get("eligible_kinds", []).has(str(entry.get("kind", "")))


# Tempered eligibility (s4 item 15): a steel tool (its material) or a steel weapon or armour row listed in temper.include (those rows carry no
# material), not the excluded ones (the Steel - Striker); ammunition stacks and is out already.
static func temper_ok(item_id: String, entry: Dictionary, gives_count: int) -> bool:
	var t: Dictionary = cfg().get("temper", {})
	var steel: bool = str(entry.get("material", "")) == str(t.get("material", "steel")) or t.get("include", []).has(item_id)
	return steel and craft_ok(entry, gives_count) and not t.get("exclude", []).has(item_id)


# The variant codes a recipe's output may be made as here: 0 always; Tempered with a quenching trough beside a serving Smithy (`trough_here`);
# +1 and +2 at a Master smithy that serves the recipe (`master_here`); both together where both apply.
static func variants(item_id: String, entry: Dictionary, gives_count: int, master_here: bool, trough_here: bool) -> Array:
	var temper: bool = trough_here and temper_ok(item_id, entry, gives_count)
	var crafts: int = 2 if master_here and craft_ok(entry, gives_count) else 0
	var out: Array = []

	for t in ([false, true] if temper else [false]):
		for c in range(crafts + 1):
			out.append(code(t, c))

	return out


# The instance a craft makes: craftsmanship and Tempered fixed now, with the higher maximum durability set once (the bonuses add, never multiply).
static func made_inst(entry: Dictionary, variant: int) -> Dictionary:
	if variant == 0:
		return {}

	var c: Dictionary = cfg()
	var made: Dictionary = InventoryScript.make_inst(craft_in(variant), tempered_in(variant))
	var durability: int = int(entry.get("durability", 0))

	if durability > 0:
		var share: float = float(c.get("craft", {}).get("durability", 0.0)) * float(craft_in(variant))

		if tempered_in(variant):
			share += float(c.get("temper", {}).get("durability", 0.0))

		made["max_d"] = int(round(float(durability) * (1.0 + share)))

	return made


# A variant's needs: each count times the craftsmanship materials factor, rounded up. Kept tools are not scaled.
static func scaled_needs(needs: Array, variant: int) -> Array:
	var factor: float = float(cfg().get("craft", {}).get("materials", [1.0, 1.0, 1.0])[craft_in(variant)])
	var out: Array = []

	for need in needs:
		out.append([int(need[0]), int(ceil(float(need[1]) * factor - 0.0001))])

	return out


# A variant's craft time factor: craftsmanship's times Tempered's.
static func time_mult(variant: int) -> float:
	var c: Dictionary = cfg()
	var mult: float = float(c.get("craft", {}).get("time", [1.0, 1.0, 1.0])[craft_in(variant)])
	return mult * (float(c.get("temper", {}).get("time", 1.0)) if tempered_in(variant) else 1.0)


# What a craftsmanship level adds to a sale value (x1.5 at +1, x2 at +2 with value 0.5).
static func value_mult(item_inst: Dictionary) -> float:
	return 1.0 + float(cfg().get("craft", {}).get("value", 0.0)) * float(item_inst.get("craft", 0))


# Extra weapon damage per craftsmanship level (s2.9 item 4: "+2" is two more damage).
static func damage_bonus(item_inst: Dictionary) -> float:
	return float(cfg().get("craft", {}).get("damage", 0)) * float(item_inst.get("craft", 0))
