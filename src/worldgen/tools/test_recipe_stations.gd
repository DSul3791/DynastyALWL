extends SceneTree

# Crafting rule (Dave 25 Oct): benches only for weapons and tools, cooking at cooking stations, everything else by hand.
# By-hand recipes queue with no station near; stone tools refuse without a bench; iron and steel tools refuse without a forge.
#   godot --headless --path . --script res://src/worldgen/tools/test_recipe_stations.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const BY_HAND := [166, 167, 168, 169, 17, 30, 39, 40, 43, 49, 119, 120, 121, 122, 123, 124, 126, 130]   # 49 is the log workbench itself: the first bench cannot need a bench
const BENCH := [26, 140, 156, 158, 47, 48, 50, 51, 153, 154, 155]   # stone tools and the processing station kits (tool rack, vice, stone forge, blacksmithy, water wheel, saw mill, woodworking table): made at a bench
const FORGE := [27, 28, 135, 136, 137, 138, 141, 142]   # iron and steel spades and hoes: made at a forge

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func fresh(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "stationkey001")
	items.report_position(1, Vector3(100.0, 10.0, 100.0))
	items.vitals_of(1)["weight"] = 120.0
	items._admin_mode_off[1] = true
	return items


# Queues one craft of a recipe with its ingredients in the pack and nothing standing near. True when the queue took it.
func queues(number: int) -> bool:
	var items = fresh("user://test_recipe_stations")
	var recipe: Dictionary = items.recipes.recipe(number)
	recipe["known"] = true   # the rule is about the station, not about what the player has learned yet

	for need in recipe["needs"] + recipe["keeps"]:
		items.inventory_of(1).add(need[0], need[1])

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, 1, Vector3.ZERO)
	return not items._craft_queues[items._peer_key[1]]["entries"].is_empty()


func _init() -> void:
	var table: Array = []

	for number in BY_HAND:
		var ok: bool = queues(number)
		table.append("hand   %3d  %s" % [number, "queues with no station" if ok else "REFUSED"])
		check(ok, "recipe %d is made by hand: it queues with no station near" % number)

	for number in BENCH:
		var ok: bool = not queues(number)
		table.append("bench  %3d  %s" % [number, "refused without a bench" if ok else "QUEUED WITHOUT A BENCH"])
		check(ok, "recipe %d (a stone tool or a station kit) refuses without a bench" % number)

	for number in FORGE:
		var ok: bool = not queues(number)
		table.append("forge  %3d  %s" % [number, "refused without a forge" if ok else "QUEUED WITHOUT A FORGE"])
		check(ok, "recipe %d (an iron or steel tool) refuses without a forge" % number)

	print("\n".join(table))
	print("recipe station tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
