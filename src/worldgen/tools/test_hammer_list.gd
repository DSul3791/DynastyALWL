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
	list.setup(table, pack)
	var rows: Array = list.rows(1)
	check(rows.size() == 4, "a wooden hammer lists the four heavy station blueprints (%d)" % rows.size())
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
	list.choose(1)
	check(not list.is_open and list.picked > 0 and list.name_of(list.picked) == str(list.rows(1)[list.rows(1).size() - 1]["name"]), "the wheel wraps round and a click picks (%s)" % list.name_of(list.picked))
	check(list.kit_of(list.picked) != "", "the picked blueprint names its structure's kit for the ghost")
	list.clear()
	check(list.picked == 0 and not list.is_open, "putting the hammer away clears the pick")
	var strict_list = ListScript.new()
	strict_list.setup(table, pack)
	strict_list._book[0]["hammer"] = 2
	check(strict_list.rows(1).size() == 3 and strict_list.rows(2).size() == 4, "a row with hammer 2 hides from a wooden hammer")
	print("test_hammer_list: %d fail" % failures)
	quit(1 if failures > 0 else 0)
