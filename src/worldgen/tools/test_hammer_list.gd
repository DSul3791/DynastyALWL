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
	check(rows.size() == 51, "a wooden hammer lists every known blueprint: the rough bed is a pack craft and the wool rug is locked (%d)" % rows.size())
	check(str(rows[0]["name"]) <= str(rows[1]["name"]), "the list is alphabetical")
	check(not bool(rows[0]["can"]), "an empty pack covers nothing")

	var wall: Dictionary = {}

	for row in rows:
		if str(row["name"]) == "Woodworking table":
			wall = row

	check(wall.get("kit", "") == "woodworking_table_kit" and str(wall["text"]) == "lumber 0/12, nails 0/60", "table row: kit and have/need text (%s)" % str(wall.get("text", "")))
	pack.add(table.number_of("lumber"), 11)
	pack.add(table.number_of("nails"), 60)
	check(not list.rows(1).filter(func(r): return r["name"] == "Woodworking table")[0]["can"], "11 of 12 lumber is short")
	pack.add(table.number_of("lumber"), 1)
	var wall_now: Dictionary = list.rows(1).filter(func(r): return r["name"] == "Woodworking table")[0]
	check(bool(wall_now["can"]) and str(wall_now["text"]) == "lumber 12/12, nails 60/60", "12 lumber and 60 nails cover the table (%s)" % str(wall_now["text"]))

	list.set_open(true, 1)
	check(list.is_open and list.picked == 0, "R opens the list with nothing picked")
	list.move(true, 1)
	list.move(false, 1)
	list.move(false, 1)
	check(list.list_text(1).contains(">"), "the highlight shows in the text")
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
	check(list.picked == 0 and not list.is_open, "putting the hammer away clears the pick")
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
	check(strict_list.rows(1).size() == 50 and strict_list.rows(2).size() == 51, "a row with hammer 2 hides from a wooden hammer")
	print("test_hammer_list: %d fail" % failures)
	quit(1 if failures > 0 else 0)
