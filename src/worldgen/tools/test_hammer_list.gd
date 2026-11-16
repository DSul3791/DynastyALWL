extends SceneTree

# The hammer's blueprint list (src/client/hammer_blueprints.gd): rows with have/need counts, the hammer tier filter, the Item - Tier order, the search, the groups, the one-click pick and the build screen.
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
	check(rows.size() == 214, "a wooden hammer lists every known blueprint (214 with the Small log sled and Small wagon, TREE_WOOD_TOOLS_DESIGN.md W-14; 212 once the 16 knife rows of W-9 left its list, TREE_WOOD_TOOLS_DESIGN.md; 228 with the Sawbuck of TREE_WOOD_TOOLS_DESIGN.md W-4; 227 with the Small, Medium and Large gardening plots for the four tier plots, Dave 14 Nov 2026; 228 with the stone channels, Stone - Trough and Cistern unlocked, plumbing PR 3, the three clay pipes retired (Dave 14 Nov 2026); 223 with the six wooden water pieces unlocked and the three log pipes of plumbing PR 2; 214 with the three well tiers of plumbing PR 1; 211 with the Engineered fence and gate of GOALS-REPAIR A-40, the four new Fortified pieces need a metal hammer; 209 with the Medium and Large resource bins of GOALS-REPAIR R6; 207 with the five tier Roof 65 panels of GOALS-REPAIR A-36; 202 without the standalone Quenching trough, no longer built, GOALS-REPAIR R5; 203 with the Advanced smithy of GOALS-REPAIR R4; 202 without the standalone Bellows, no longer built, GOALS-REPAIR R3; 203 with the Improved smelter of GOALS-REPAIR R2a; 202 with the 20 empty doorway frames and 28 doors of BUGLIST-002, 7 of them need an iron hammer; 161 with Crude - Roof 65 of BUGLIST-001 BUG-011; 160 with the Handcart of phase 10; 159 with the Food preparation table and Fireplace cooking crane of phase 6; 157 with the 15 storage rows of phase 9 a wooden hammer builds; 142 with the Grindstone of phase 2c; 141 with the Leatherworking table, Tailor's table and Loom of phase 2b part 2; 138 with the Crude chest, chair and table of phase 3; 135 after Mission 001 phase 2b: Smelter, Blast furnace, Bellows and Quenching trough in, Clay bloomery and Anvil out; 133 after the Woodworking table retired; 134 after the building tiers: the Mixer and nine Engineered pieces in, Log - Bench, Table and Shelf out; Fortified and iron pieces need an iron hammer): the rough bed is a pack craft; the wool rug, compost bin, cold frame and the water pieces other than the wells are locked (%d)" % rows.size())
	var ordered: bool = true

	for k in range(rows.size() - 1):
		ordered = ordered and not ListScript.book_before(str(rows[k + 1]["name"]), str(rows[k]["name"]), ListScript.TIER_ORDER)

	check(ordered, "the list goes by item name, then each item's tiers up the ladder (Dave 16 Nov 2026)")
	check(ListScript.book_before("Crude - Wall", "Rustic - Wall", ListScript.TIER_ORDER) and ListScript.book_before("Superior - Wall", "Engineered - Wall", ListScript.TIER_ORDER) and ListScript.book_before("Engineered - Wall", "Fortified - Wall", ListScript.TIER_ORDER), "one item's tiers lowest to highest: Crude, Rustic, ... Superior, Engineered, Fortified (Dave 16 Nov 2026: \"lowest to highest is best\"), not alphabetical")
	check(ListScript.book_before("Fortified - Doorway", "Crude - Wall", ListScript.TIER_ORDER) and ListScript.book_before("Kiln", "Mixer", ListScript.TIER_ORDER) and ListScript.book_before("Bench", "Crude - Chair", ListScript.TIER_ORDER), "items go alphabetically by item name, whatever the tier")
	check(ListScript.book_before("Primitive smelter", "Improved smelter", ListScript.TIER_ORDER) and ListScript.book_before("Improved smelter", "Advanced smelter", ListScript.TIER_ORDER), "the smelters sit together, Primitive, Improved, Advanced")
	check(ListScript.display_name("Sturdy - Wall") == "Wall - Sturdy" and ListScript.display_name("Primitive smelter") == "Smelter - Primitive" and ListScript.display_name("Kiln") == "Kiln" and ListScript.display_name("Log rack") == "Log rack", "the screen shows Item - Tier (Dave 16 Nov 2026); the catalog name stays Tier - Item")
	var smelters: Array = rows.filter(func(r): return str(r["shown"]).begins_with("Smelter - ")).map(func(r): return str(r["shown"]))
	var at: int = rows.map(func(r): return str(r["shown"])).find("Smelter - Primitive")
	check(smelters == ["Smelter - Primitive", "Smelter - Improved", "Smelter - Advanced"] or smelters.size() < 3, "the smelters a wooden hammer lists are together (%s)" % str(smelters))
	check(at < 0 or str(rows[at + 1]["shown"]).begins_with("Smelter - ") or smelters.size() == 1, "nothing comes between the smelters")
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
	check(list.mode == "repair" and list.actions()[0]["kind"] == "repair" and list.actions()[1]["kind"] == "save", "a hammer starts on Repair, the first line above its list (Dave 10 Nov 2026), Save building plan beside it")
	var all_count: int = list.entries(1).size()
	check(all_count == 214, "All lists every blueprint (%d)" % all_count)
	# The search box (Dave 16 Nov 2026: "smel" shows every smelter), whatever group is chosen.
	list.category = "Walls and doors"
	list.search = "smel"
	var found: Array = list.entries(1)
	check(not found.is_empty() and found.all(func(e): return str(e["name"]).to_lower().contains("smel")), "smel lists the smelters, searched in every group (%s)" % str(found.map(func(e): return e["shown"])))
	list.search = "wall sturdy"
	check(list.entries(1).any(func(e): return str(e["name"]) == "Sturdy - Wall"), "every word typed must match, in either order")
	list.search = ""
	check(list.entries(1).size() < all_count and list.entries(1).all(func(e): return str(list.rows(1).filter(func(r): return int(r["number"]) == int(e["number"]))[0]["category"]) == "Walls and doors"), "a group shows only its blueprints")
	# One click picks and shuts the screen (Dave 16 Nov 2026: no confirm step).
	var wall_entry: Dictionary = list.entries(1)[0]
	list.pick(wall_entry)
	check(not list.is_open and list.picked == int(wall_entry["number"]) and list.mode == "place", "a click on a row picks it and shuts the screen (%s)" % list.name_of(list.picked))
	check(list.kit_of(list.picked) != "", "the picked blueprint names its structure's kit for the ghost")
	list.set_open(true, 1)
	check(list.category == "Walls and doors" and list.search == "", "the screen remembers the last group, not the words typed")
	list.pick(list.actions()[0])
	check(not list.is_open and list.picked == 0 and list.mode == "repair", "the Hammer/Repair Tool line goes back to Repair")
	list.clear()
	check(list.picked == 0 and not list.is_open and list.mode == "repair", "putting the hammer away clears the pick and puts it back on Repair")
	# Groups (Dave 5 Nov 2026): every blueprint has a group; the side tabs follow CATEGORY_ORDER.
	var groups: Array = list.categories(1)
	check(groups.size() >= 5 and list.rows(1).all(func(r): return str(r["category"]) != "Other") and groups[0] == "Walls and doors", "every blueprint is in a named group, walls first (%s)" % str(groups))
	list.category = ""
	# The screen itself (built once when there is a HUD layer): opening shows rows, a click picks, the detail shows the materials.
	var hud_layer: CanvasLayer = CanvasLayer.new()
	var shown = ListScript.new()
	shown.setup(table, pack, hud_layer, "user://test_hammer_list_none.json")
	shown.set_open(true, 1)
	var visible_rows: int = shown._row_buttons.values().filter(func(b): return b.visible).size()
	check(shown._screen.visible and visible_rows == 214, "the open screen shows every row of All (%d)" % visible_rows)
	shown._search_box.text_changed.emit("smel")
	visible_rows = shown._row_buttons.values().filter(func(b): return b.visible).size()
	check(visible_rows == found.size(), "typing filters the rows on screen (%d)" % visible_rows)
	var crate_no: int = int(shown.rows(1).filter(func(r): return r["name"] == "Crate")[0]["number"])
	shown._hover({"kind": "bp", "number": crate_no})
	check(shown.detail_text().contains("Plank  5 / 5") and shown.detail_text().contains("Nails"), "pointing at a row shows its materials, have / need (%s)" % shown.detail_text().left(80))
	# Esc empties the search box first, then shuts the screen; a tab click empties the search; right click shuts it (BS-4).
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	check(shown._screen_input(esc) and shown.is_open and shown.search == "" and shown._search_box.text == "", "Esc with words typed empties the search box and keeps the screen open")
	check(shown._screen_input(esc) and not shown.is_open, "Esc again shuts the screen")
	shown.set_open(true, 1)
	shown._search_box.text_changed.emit("wall")
	(shown._tab_buttons["Garden"] as Button).pressed.emit()
	check(shown.search == "" and shown.category == "Garden" and shown._row_buttons.values().filter(func(b): return b.visible).size() == shown.rows(1).filter(func(r): return r["category"] == "Garden").size(), "a tab click empties the search and shows that group whole")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	check(shown._screen_input(right) and not shown.is_open and shown.picked == 0, "right click shuts the screen without a pick")
	shown.category = ""
	shown.set_open(true, 1)
	(shown._row_buttons[crate_no] as Button).pressed.emit()
	check(not shown.is_open and not shown._screen.visible and shown.picked == crate_no, "a click on a row picks it and shuts the screen")
	hud_layer.free()
	var strict_list = ListScript.new()
	strict_list.setup(table, pack, null, "user://test_hammer_list_none.json")
	var first_hammer_row: Dictionary = strict_list._book.filter(func(r): return str(r["tool"]) == "hammer")[0]   # the first row may be a knife row now (Crude - Chair): the hammer's list is what is tested
	first_hammer_row["hammer"] = 2
	check(strict_list.rows(1).size() == 213 and strict_list.rows(2).size() == 214, "a row with hammer 2 hides from a wooden hammer")
	print("test_hammer_list: %d fail" % failures)
	quit(1 if failures > 0 else 0)
