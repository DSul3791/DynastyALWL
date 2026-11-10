extends SceneTree

# The outer and waist clothing slots (the item review, 10 Nov 2026; data/items/clothing.json): a cloak goes over the body piece, a belt, quiver or
# pouch at the waist, each in its own slot at the end of the list, so a save from before them reads them empty and keeps the rest; a cloak worn
# outer leaves the tunic on. The cloak row is moved to "outer" here; Jamie's item batch moves the real rows.
#   godot --headless --path . --script res://src/worldgen/tools/test_clothing_slots.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = "user://test_clothing_slots"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), dir)
	var slots: Array = items._clothing_slots()
	check(slots == ["head", "body", "legs", "feet", "hands", "back", "outer", "waist"], "eight slots, outer and waist last (%s)" % str(slots))

	items.peer_connected_hello(1, "dresser00001")
	var tunic: int = items.table.number_of("hide_tunic")
	var key: String = str(items._peer_key[1])
	items._characters[key]["worn"] = [0, tunic, 0, 0, 0, 0]   # a save from before the new slots
	var worn: Array = items.worn_of(1)
	check(worn.size() == 8 and int(worn[1]) == tunic and int(worn[6]) == 0 and int(worn[7]) == 0, "an old save keeps its tunic and reads outer and waist empty (%s)" % str(worn))
	check(items._clean_worn([0, tunic, 0, 0, 0, 0]).size() == 8, "and loads cleaned to eight")

	items.table.entry("hide_cloak")["slot"] = "outer"
	var cloak: int = items.table.number_of("hide_cloak")
	items.action(1, Net.ACT_ADMIN_GIVE, cloak, 0, 1, Vector3.ZERO)
	var inv = items.inventory_of(1)
	items.action(1, Net.ACT_WEAR, inv.numbers.find(cloak), 0, 0, Vector3.ZERO)
	worn = items.worn_of(1)
	check(int(worn[6]) == cloak and int(worn[1]) == tunic, "a cloak goes on over the tunic, which stays on (%s)" % str(worn))
	check(items.insulation_worn(1) > float(items.table.entry("hide_tunic").get("warmth", 0.0)), "and both keep warm")
	items.action(1, Net.ACT_UNWEAR, 6, 0, 0, Vector3.ZERO)
	check(int(items.worn_of(1)[6]) == 0 and inv.count_of(cloak) == 1, "taking off the outer slot gives the cloak back")

	print("clothing slots: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
