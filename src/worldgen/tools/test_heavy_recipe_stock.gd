extends SceneTree

# A recipe heavier than a pack can hold is still made (tools/carry_audit.py "OVER CAP"): a craft takes from the player's own chests within 12 m
# (craft_stock.gd; Dave 10 Nov 2026: "or they are within 12m of you"), so the Water wheel's 20 lumber (60 kg, over a 75 kg body's 52.5 kg cap)
# come over in trips into a chest by the Stone workbench, and the wheel is made with the nails and tar from the pack.
#   godot --headless --path . --script res://src/worldgen/tools/test_heavy_recipe_stock.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")

const DIR := "user://test_heavy_recipe_stock"

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.send_chest = func(_p, _id, _b): pass
	items.send_step_to = func(_p, _s, _y): pass
	items.ground_height = func(_x, _z): return 10.0
	items.admin_mode_on = func(_p): return false
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "heavyrecipe0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json"))["recipes"]
	var wheel: Dictionary = recipes["water_wheel"]
	var number: int = int(wheel["number"])
	var cap: float = CarryRules.cap_kg(75.0, items._carry_cfg)
	var lumber_kg: float = 0.0
	var all_kg: float = 0.0

	for need in wheel["needs"]:
		all_kg += CarryRules.weight_of(str(need[0]), items._carry_cfg) * float(need[1])

		if str(need[0]) == "lumber":
			lumber_kg = CarryRules.weight_of("lumber", items._carry_cfg) * float(need[1])

	check(all_kg > cap, "the Water wheel needs %.1f kg (%.1f kg of it lumber), over the %.1f kg a 75 kg body carries" % [all_kg, lumber_kg, cap])

	var bench: int = items.dev_place("stone_workbench@3,0,0")
	var chest: int = items.dev_place("chest@-3,0,0")
	items._items[chest]["struct"]["owner"] = str(items._peer_key[1])
	check(bench != 0 and chest != 0, "a Stone workbench and the player's own chest stand by")

	# Trip one: the lumber into the chest. Trip two: the nails and tar stay in the pack.
	for need in wheel["needs"]:
		var id: String = str(need[0])
		var k: int = int(need[1])

		if id == "lumber":
			var box = items._chest_of(1, chest)
			box.add(n(id), k)
		else:
			items.inventory_of(1).add(n(id), k)

	items._learned_of(1)[str(number)] = true
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, 1, CraftHand.at(items, 1, number))
	items._craft_tick(float(wheel["craft_s"]) * 4.0 + 1.0)
	var on_ground: int = 0

	for id in items._items:
		if int(items._items[id].get("number", 0)) == n("water_wheel") and not items._items[id].has("struct"):
			on_ground += int(items._items[id]["count"])

	check(on_ground == 1 and said.any(func(t): return str(t).begins_with("Too heavy to carry")), "the wheel is made from the chest's lumber; at %.0f kg it is too heavy for a bare back, so it is put down at the bench (%s)" % [CarryRules.weight_of("water_wheel", items._carry_cfg), str(said)])
	check(items._chest_of(1, chest).count_of(n("lumber")) == 0 and items.inventory_of(1).count_of(n("nails")) == 0, "every ingredient used once")
	check(items._stock_of(1)["near"].size() >= 1, "and it is crafting stock where it lies, for the Sawmill built beside it")

	# An Improved backpack (carry_bonus_kg) lifts the limit past the wheel's weight: the wheel can be carried to a river.
	items.inventory_of(1).add(n("improved_backpack"), 1)
	var inv = items.inventory_of(1)
	items.action(1, Net.ACT_WEAR, inv.numbers.find(n("improved_backpack")), 0, 0, Vector3.ZERO)
	var limit: float = CarryRules.cap_kg(items._carry_body(1), items._carry_cfg)
	check(CarryRules.weight_of("water_wheel", items._carry_cfg) < limit, "with an Improved backpack on, the %.1f kg limit carries the wheel" % limit)

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
