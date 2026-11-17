extends SceneTree

# A station's own window lists only what that station makes (Dave 17 Nov 2026: "when you open an inventory other than yours like the
# workstation or the primative smithy it should only list the crafting recipes for stuff that station makes"). Your own inventory lists all.
#   godot --headless --path . --script res://src/worldgen/tools/test_station_recipe_list.gd

const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view = InventoryViewScript.new()
	view.table = ItemTableScript.load_default()
	view.inventory = InventoryScript.new(view.table)
	view._player_position = func() -> Vector3: return Vector3.ZERO
	var kinds: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	view._world = {}

	for at in [["workbench", 1], ["log_workbench", 2], ["stone_forge", 3], ["blacksmithy", 4], ["sawbuck", 5], ["chest", 6], ["clay_hearth", 7]]:
		view._world[at[1]] = {"node": null, "number": 0, "count": 1, "pos": Vector3(float(at[1]) * 20.0, 0.0, 0.0), "state": int(kinds[at[0]]["state"]), "light": null}

	view._world[8] = {"node": null, "number": 0, "count": 1, "pos": Vector3(200.0, 0.0, 0.0), "state": 1, "light": null}   # a lit campfire
	view._world[9] = {"node": null, "number": 0, "count": 1, "pos": Vector3(41.0, 0.0, 0.0), "state": int(kinds["vice"]["state"]), "light": null}   # beside the Carpenter's bench: +1 level
	view._world[10] = {"node": null, "number": 0, "count": 1, "pos": Vector3(81.0, 0.0, 0.0), "state": int(kinds["bellows"]["state"]), "light": null}   # beside the Improved smithy: adds_level false, as the server
	var hand: Dictionary = {"number": 1, "station": ""}
	var bench1: Dictionary = {"number": 2, "station": "workbench", "station_level": 1}
	var bench2: Dictionary = {"number": 3, "station": "workbench", "station_level": 2}
	var bench4: Dictionary = {"number": 9, "station": "workbench", "station_level": 4}
	var bench3: Dictionary = {"number": 10, "station": "workbench", "station_level": 3}
	var forge1: Dictionary = {"number": 4, "station": "forge", "station_level": 1}
	var brick2: Dictionary = {"number": 5, "station": "brick_forge", "station_level": 2}
	var brick3: Dictionary = {"number": 6, "station": "brick_forge", "station_level": 3}
	var fire: Dictionary = {"number": 7, "station": "campfire"}
	var block: Dictionary = {"number": 8, "station": "", "sawbuck": true}
	var all: Array = [hand, bench1, bench2, bench3, bench4, forge1, brick2, brick3, fire, block]

	check(all.all(func(r): return view.station_makes(r)), "your own inventory lists every recipe")
	_expect(view, 1, all, [bench1], "Workbench: its level 1 recipes only, no hand or other station recipes")
	_expect(view, 2, all, [bench1, bench2, bench3], "Carpenter's bench (workbench 2) with a vice beside it: up to level 3, not 4")
	_expect(view, 3, all, [forge1], "Primitive smithy (forge 1): forge recipes only")
	_expect(view, 4, all, [forge1, brick2], "Improved smithy (brick forge 2, also forge 1): what it serves, not the level 3 ones (the bellows beside it adds no level)")
	_expect(view, 5, all, [block], "Sawbuck: the recipe it speeds (Wooden block)")
	_expect(view, 6, all, all, "a plain chest (were it ever the screen): your own list")
	_expect(view, 7, all, [fire], "Clay hearth (also a campfire): campfire recipes")
	_expect(view, 8, all, [fire], "a campfire's window: campfire recipes")

	view._station_screen = 99   # taken down while open: the list falls back to your own
	check(view.station_makes(hand), "a station gone from the world lists everything")

	view._station_screen = 4
	view.open = true
	view._panel = PanelContainer.new()
	view.toggle()   # closing
	check(view._station_screen == 0, "closing the window forgets the station: I opens your own inventory next")
	print("test_station_recipe_list: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


func _expect(view, id: int, all: Array, want: Array, what: String) -> void:
	view._station_screen = id
	view._forget_near()
	var got: Array = all.filter(func(r): return view.station_makes(r))
	check(got == want, "%s (got %s)" % [what, str(got.map(func(r): return r["number"]))])
