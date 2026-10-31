extends SceneTree

# Anything the server can eat can be taken in hand and eaten on the client (Dave 31 Oct 2026: crab apples could not be eaten). The server decides by the vitals rules (food kcal,
# drink, medicine, energy aids); the client's hotbar hold (held_item.gd is_holdable) must agree for EVERY item kind, "material" included. Lists the edible items and checks the
# hold offer for each, with nothing edible in hand, and checks that a non-food material is not offered.
#   godot --headless --path . --script res://src/worldgen/tools/test_edible_offer.gd

const HeldScript := preload("res://src/client/held_item.gd")
const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


class FakeInv:
	extends RefCounted
	var table
	var _vitals_cfg: Dictionary = {}

	func is_edible_item(number: int) -> bool:
		return number > 0 and load("res://src/shared/vitals_rules.gd").edible(table.id_of(number), _vitals_cfg)

	func edible_slot(_slot: int) -> bool:
		return false   # nothing edible is in hand: the old code asked this and so refused every food that is not a tool-like kind


func _init() -> void:
	var table = ItemTableScript.load_default()
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/vitals.json"))
	var inv = FakeInv.new()
	inv.table = table
	inv._vitals_cfg = cfg
	var held = HeldScript.new()
	held._inv = inv
	var edible: Array = []
	var refused: Array = []

	for id in table.ids():
		var number: int = table.number_of(str(id))
		var server_says: bool = VitalsRules.food_value(str(id), cfg) > 0 or VitalsRules.drink_value(str(id), cfg) > 0 or VitalsRules.heal_value(str(id), cfg) > 0

		if server_says:
			edible.append(id)

			if not held.is_holdable(number):
				refused.append(id)

	check(edible.size() > 20, "the vitals rules make %d items edible, drinkable or healing" % edible.size())
	check(refused.is_empty(), "every one of them can be taken in hand with nothing edible held; refused: %s" % str(refused.slice(0, 10)))
	for id in ["crab_apples", "wild_apples", "apple_early", "roast_forage"]:
		check(table.has_id(id) and held.is_holdable(table.number_of(id)), "%s can be held and eaten" % id)

	check(not held.is_holdable(table.number_of("stone")) and not held.is_holdable(0), "a stone and an empty slot are not offered")
	print("edible offer: %d failures" % failures)
	quit(1 if failures > 0 else 0)
