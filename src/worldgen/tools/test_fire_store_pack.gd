extends SceneTree

# Fire store pack side (Dave, 4 Nov 2026): with a fire's store open, the pack column shows only what the fire takes (wood and food, the
# server's _fire_takes rule), sorted by name A to Z and packed to the top; a click on button i puts the real pack slot behind it.
# A woven chest still shows every pack slot in place.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_store_pack.gd

const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var view = InventoryViewScript.new()
	view.table = ItemTableScript.load_default()
	view.inventory = InventoryScript.new(view.table)
	var t = view.table

	for id in ["stone", "stick", "raw_meat", "plant_fibre", "firewood", "roast_forage"]:
		check(t.has_id(id), "item %s exists" % id)

		if t.has_id(id):
			view.inventory.add(t.number_of(id), 2)

	check(view.fire_takes("stick") and view.fire_takes("firewood") and view.fire_takes("raw_meat"), "the fire takes stick, firewood and raw meat")
	check(not view.fire_takes("stone") and not view.fire_takes("plant_fibre"), "the fire refuses stone and plant fibre")
	check(not view.fire_takes("roast_forage"), "the fire refuses already cooked food (cooking.json gives)")

	var slots: Array = view._pack_view_slots(true)
	var names: Array = []

	for slot in slots:
		names.append(t.name_of(view.inventory.numbers[slot]))

	var sorted_names: Array = names.duplicate()
	sorted_names.sort_custom(func(a, b): return str(a).to_lower() < str(b).to_lower())
	check(slots.size() == 3, "fire view shows 3 stacks (stick, firewood, raw meat): %s" % str(names))
	check(names == sorted_names, "fire view is A to Z: %s" % str(names))

	var stone_slot: int = view.inventory.numbers.find(t.number_of("stone"))
	check(not slots.has(stone_slot), "stone is not shown on a fire")
	view._pack_view = slots
	check(view._pack_slot(0) == int(slots[0]) and view._pack_slot(slots.size()) == -1, "button index maps to the real slot; buttons past the list are empty")

	var chest: Array = view._pack_view_slots(false)
	check(chest.size() == InventoryScript.BASE_SLOTS and int(chest[stone_slot]) == stone_slot, "a chest shows every pack slot in place")

	view._world = {7: {"state": 1, "number": 0}}
	view.chest_id = 7
	check(view._chest_is_fire(), "world state 1 is a fire")
	view._world[7]["state"] = 0
	check(not view._chest_is_fire(), "state 0 is not a fire")
	print("test_fire_store_pack: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
