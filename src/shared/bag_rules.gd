extends RefCounted

# Bags (catalog Phase 5, master DYNASTY_MASTER_ITEMS.md s3.9 rules 1-5). A bag is an item whose items.json row has `bag_slots` (its organized
# volume: slots of its own) and `bag_takes` (what goes in it, below). What it holds rides in its instance data as `bag`: rows in the pack's save
# shape ([number, count, wear] and [.., 0, inst] with an instance; Inventory.clean_inst). So every path that keeps an instance (worn on and off,
# drop and pick-up, chest put and take, throw, death) carries the contents with the bag, and the save and the wire carry them where the instance
# data goes. A bag never holds a bag. Shared: the server enforces it, the client shows the open bag beside the pack.

const InventoryScript := preload("res://src/shared/inventory.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")


# The bag's own slots (0 for anything that is not a bag).
static func slots_of(table, number: int) -> int:
	return clampi(int(table.entry(table.id_of(number)).get("bag_slots", 0)), 0, InventoryScript.BASE_SLOTS) if number > 0 else 0


# What the bag holds, as an inventory of its own slots. A bag whose rows run past its slots (bag_slots lowered in the data) shows them all, so
# nothing in it is hidden or lost (CATALOG_SAVE_MIGRATION.md rule 9).
static func open(table, number: int, item_inst: Dictionary):
	var inv = InventoryScript.new(table)
	var rows: Array = item_inst.get("bag", [])
	inv.usable = clampi(maxi(slots_of(table, number), rows.size()), 1, inv.slot_count)
	inv.from_json_array(rows)
	return inv


# The bag's instance data with `inv` written back as its contents (no `bag` key once it is empty, so an empty bag is plain again).
static func store(inv, item_inst: Dictionary) -> Dictionary:
	var out: Dictionary = item_inst.duplicate(true)
	out.erase("bag")
	return InventoryScript.clean_inst(out.merged({"bag": inv.to_json_array()}))


# How many more of an item a quiver takes: its items.json ammo_capacity (40, 60 arrows) less what it holds; any number for other bags.
static func room(table, bag_number: int, inv) -> int:
	var cap: int = int(table.entry(table.id_of(bag_number)).get("ammo_capacity", 0))

	if cap <= 0:
		return 1 << 30

	var held: int = 0

	for i in inv.usable:
		held += inv.counts[i] if inv.numbers[i] != 0 else 0

	return maxi(cap - held, 0)


# Why the bag does not take an item ("" when it does). `rules` is clothing.json `bags`: small_kg, small_tool_kg, blade_classes, consumable_kinds.
# bag_takes: any (anything that is not too big for a pack), small (each at most small_kg: coins, herbs, potions), small_tool (a tool of at most
# small_tool_kg), consumable (food or medicine of at most small_kg), arrow (ammo_class arrow), blade (a weapon of a blade class).
static func refusal(table, carry_cfg: Dictionary, rules: Dictionary, bag_number: int, number: int) -> String:
	var bag: Dictionary = table.entry(table.id_of(bag_number))
	var entry: Dictionary = table.entry(table.id_of(number))
	var takes: String = str(bag.get("bag_takes", "any"))
	var kg: float = CarryRules.weight_of(table.id_of(number), carry_cfg)
	var kind: String = str(entry.get("kind", ""))

	if slots_of(table, number) > 0:
		return "A bag cannot go inside another bag."

	if takes == "arrow":
		return "" if str(entry.get("ammo_class", "")) == "arrow" else "Only arrows go in a quiver."

	if takes == "blade":
		return "" if kind == "weapon" and (rules.get("blade_classes", []) as Array).has(str(entry.get("weapon_class", ""))) else "Only a sword fits the scabbard."

	if str(entry.get("carry", "")) == "shoulder":
		return "That is too big for a bag."

	if takes == "small" and kg > float(rules.get("small_kg", 0.5)):
		return "Only small things go in the %s." % str(bag.get("name", "bag")).to_lower()

	if takes == "small_tool" and (kind != "tool" or kg > float(rules.get("small_tool_kg", 1.5))):
		return "Only small tools go in the tool roll."

	if takes == "consumable" and (not (rules.get("consumable_kinds", []) as Array).has(kind) or kg > float(rules.get("small_kg", 0.5))):
		return "Only small food and medicine go in the bandolier."

	return ""
