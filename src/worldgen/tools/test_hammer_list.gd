extends SceneTree

# The hammer's blueprint list (src/client/hammer_blueprints.gd): rows with have/need counts, the hammer tier filter, the pick, the wheel.
#   godot --headless --path . --script res://src/worldgen/tools/test_hammer_list.gd

const ListScript := preload("res://src/client/hammer_blueprints.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var pack = InventoryScript.new(table)
	var list = ListScript.new()
	list.setup(table, pack, null, "user://test_hammer_list_none.json")
	var rows: Array = list.rows(1)
	check(rows.size() == 135, "a wooden hammer lists every known blueprint (135 after Mission 001 phase 2b: Smelter, Blast furnace, Bellows and Quenching trough in, Clay bloomery and Anvil out; 133 after the Woodworking table retired; 134 after the building tiers: the Mixer and nine Engineered pieces in, Log - Bench, Table and Shelf out; Fortified and iron pieces need an iron hammer): the rough bed is a pack craft; the wool rug, compost bin, cold frame and the water pieces are locked (%d)" % rows.size())
	var ordered: bool = true

	for k in range(rows.size() - 1):
		ordered = ordered and not ListScript.book_before(str(rows[k + 1]["name"]), str(rows[k]["name"]), ListScript.TIER_ORDER)

	check(ordered, "the list goes up the tier ladder, each tier's pieces by name, then the rest by name")
	check(ListScript.book_before("Crude - Wall", "Rustic - Doorway", ListScript.TIER_ORDER) and ListScript.book_before("Superior - Wall", "Engineered - Doorway", ListScript.TIER_ORDER) and ListScript.book_before("Engineered - Wall", "Fortified - Doorway", ListScript.TIER_ORDER), "Crude, Rustic, ... Superior, Engineered, Fortified (Dave 10 Nov 2026), not alphabetical")
	check(ListScript.book_before("Fortified - Wall top", "Kiln", ListScript.TIER_ORDER) and ListScript.book_before("Kiln", "Mixer", ListScript.TIER_ORDER), "names with no tier word come after the tiers, by name")
	check(not bool(rows[0]["can"]), "an empty pack covers nothing")

	var wall: Dictionary = {}

	for row in rows:
		if str(row["name"]) == "Crate":
			wall = row

	check(wall.get("kit", "") == "wooden_crate_kit" and str(wall["text"]) == "plank 0/5, nails 0/8", "crate row: kit and have/need text (%s)" % str(wall.get("text", "")))
	pack.add(table.number_of("lumber"), 4)
	pack.add(table.number_of("nails"), 8)
	check(not list.rows(1).filter(func(r): return r["name"] == "Crate")[0]["can"], "4 of 5 planks is short")
	pack.add(table.number_of("lumber"), 1)
	var wall_now: Dictionary = list.rows(1).filter(func(r): return r["name"] == "Crate")[0]
	check(bool(wall_now["can"]) and str(wall_now["text"]) == "plank 5/5, nails 8/8", "5 planks (lumber, shown as Plank since the item system renames 10 Nov 2026) and 8 nails cover the crate (%s)" % str(wall_now["text"]))
	# A group cost counts every member in the pack, as the server does (Inventory.count_fill): oak logs cover a blueprint asking for logs.
	var log_row: Dictionary = {}

	for book_row in list._book:
		for need in book_row["cost"]:
			if str(need[0]) == "log" and log_row.is_empty() and int(book_row.get("hammer", 1)) <= 1:
				log_row = {"number": int(book_row["number"]), "count": int(need[1])}

	pack.add(table.number_of("log_oak"), int(log_row.get("count", 0)))
	var log_text: String = ""

	for row in list.rows(1):
		if int(row["number"]) == int(log_row.get("number", -1)):
			log_text = str(row["text"])

	var log_part: String = "%s %d/%d" % [table.in_sentence(str(table.entry("log").get("name", "log"))), int(log_row.get("count", 0)), int(log_row.get("count", 0))]
	check(not log_row.is_empty() and log_text.contains(log_part), "oak logs in the pack count for a log cost (%s, wanted %s)" % [log_text, log_part])
	pack.remove(table.number_of("log_oak"), int(log_row.get("count", 0)))
	# The list counts what a build draws on, the pack and the craft stock in reach (held_item.gd sets stock_count to InventoryView.stock_fill).
	pack.remove(table.number_of("nails"), pack.count_of(table.number_of("nails")))
	var nails_n: int = table.number_of("nails")
	var in_chest: Dictionary = {nails_n: 8}
	list.stock_count = func(number: int) -> int:
		return pack.count_fill(number) + int(in_chest.get(number, 0))
	var stocked: Dictionary = list.rows(1).filter(func(r): return r["name"] == "Crate")[0]
	check(bool(stocked["can"]) and str(stocked["text"]) == "plank 5/5, nails 8/8", "8 nails in a chest in reach cover the crate with none in the pack (%s)" % str(stocked["text"]))
	list.stock_count = Callable()
	pack.add(nails_n, 60)

	list.set_open(true, 1)
	check(list.is_open and list.picked == 0, "R opens the list with nothing picked")
	check(list.mode == "repair" and list.entries(1)[0]["kind"] == "repair", "a hammer starts on Repair, the first line of its list (Dave 10 Nov 2026)")
	list.move(true, 1)
	list.move(false, 1)
	list.move(false, 1)
	check(list.list_text(1).contains(">"), "the highlight shows in the text")
	# The panel is a fixed 75% of the screen width and its text wraps (Dave 10 Nov 2026: the Repair line ran off both edges of the screen).
	var hud_layer: CanvasLayer = CanvasLayer.new()
	var shown = ListScript.new()
	shown.setup(table, pack, hud_layer, "user://test_hammer_list_none.json")
	shown.set_open(true, 1)
	check(is_equal_approx(shown._panel.anchor_left, 0.125) and is_equal_approx(shown._panel.anchor_right, 0.875) and shown._panel.offset_left == 0.0 and shown._panel.offset_right == 0.0, "the hammer panel spans the middle 75% of the screen width")
	check(shown._detail.autowrap_mode != TextServer.AUTOWRAP_OFF and shown._label.autowrap_mode != TextServer.AUTOWRAP_OFF, "the panel's lines wrap instead of widening it")
	check(str(shown._detail.text).begins_with("then left click a worn piece"), "the open panel shows the long Repair text (%s)" % str(shown._detail.text).left(40))
	hud_layer.free()
	check(not list.list_text(1).contains("(short)"), "no \"(short)\" after a name the pack cannot cover (Dave 10 Nov 2026): the have/need line says it")
	check(list.list_text(1).contains("Sturdy - Foundation") and list.list_text(1).contains("Refined - Wall"), "building pieces read Tier - Item on the quality ladder (Dave 10 Nov 2026)")
	# A long list scrolls past the highlight (Dave 5 Nov 2026): 7 lines show, the highlighted one in the middle, blank lines pad the ends so the first and last entry can reach it.
	list.set_open(true, 1)
	var total: int = list.entries(1).size()
	var windowed: PackedStringArray = list.list_text(1, 7).split("\n")
	check(windowed.size() == 2 + 7 and windowed[2 + 3].begins_with(">"), "the highlight sits on the middle of a seven line window (%d lines)" % windowed.size())
	check(windowed[2] == "" and windowed[3] == "" and windowed[4] == "", "at the top of the list the lines above the first entry are blank")
	check(list.list_text(1, 0).split("\n").size() == 2 + total, "no window shows the whole list")
	list.move(false, 1)   # up from the first entry wraps to the last, as the moves above had left it
	list.choose(1)
	check(not list.is_open and list.picked > 0 and list.name_of(list.picked) == str(list.rows(1)[list.rows(1).size() - 1]["name"]), "the wheel wraps round and a click picks (%s)" % list.name_of(list.picked))
	check(list.kit_of(list.picked) != "", "the picked blueprint names its structure's kit for the ghost")
	list.clear()
	check(list.picked == 0 and not list.is_open and list.mode == "repair", "putting the hammer away clears the pick and puts it back on Repair")
	# Groups (Dave 5 Nov 2026): the menu can show one group of blueprints at a time; every blueprint has a group.
	var groups: Array = list.categories(1)
	check(groups.size() >= 5 and list.rows(1).all(func(r): return str(r["category"]) != "Other"), "every blueprint is in a named group (%s)" % str(groups))
	list.set_open(true, 1)
	var all_count: int = list.entries(1).size()
	list.cycle_category(true, 1)
	check(list.category == str(groups[0]) and list.entries(1).size() < all_count and list.entries(1).size() > 2, "the right arrow shows the first group only")
	check(list.entries(1).all(func(e): return e["kind"] != "bp" or str(list.rows(1).filter(func(r): return int(r["number"]) == int(e["number"]))[0]["category"]) == list.category), "only that group's blueprints are listed")
	list.cycle_category(false, 1)
	check(list.category == "" and list.entries(1).size() == all_count, "the left arrow goes back to all of them")
	list.cycle_category(false, 1)
	check(list.category == str(groups[groups.size() - 1]), "left from All wraps to the last group")
	list.category = ""
	list.clear()
	var strict_list = ListScript.new()
	strict_list.setup(table, pack, null, "user://test_hammer_list_none.json")
	strict_list._book[0]["hammer"] = 2
	check(strict_list.rows(1).size() == 134 and strict_list.rows(2).size() == 135, "a row with hammer 2 hides from a wooden hammer")
	print("test_hammer_list: %d fail" % failures)
	quit(1 if failures > 0 else 0)
