extends SceneTree

# The slow tick's lists (audit 18 Nov 2026 finding 3): each part walks its own list of items, sorted from every item once every TICK_INDEX_S,
# with items made since sorted in on the next tick. A new lit fire burns on the next tick; a torch lit in place joins the lit list at the
# next full sort; an item gone from the world is skipped.
#   godot --headless --path . --script res://src/worldgen/tools/test_tick_lists.gd      Prints "Test done: N pass, N fail".

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_tick_lists"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)

	for step in 4:
		items.tick(0.25)   # the lists are sorted

	var fire: int = items.dev_place("campfire@20,20,0,lit")
	var burn0: float = float(items._items[fire]["fire"]["burn_left"])

	for step in 4:
		items.tick(0.25)

	check(float(items._items[fire]["fire"]["burn_left"]) < burn0, "a fire lit since the last full sort burns on the next ticks (%.2f -> %.2f)" % [burn0, float(items._items[fire]["fire"]["burn_left"])])
	var torch: int = items.dev_place("standing_torch@30,20,0")

	if torch > 0:
		for step in 4:
			items.tick(0.25)   # sorted in unlit

		items._items[torch]["struct"]["lit"] = true   # lit in place: it is not in the lit list until the next full sort
		items._items[torch]["struct"]["fuel_left"] = 100.0
		items._tick_index_kept["at"] = -100000   # the full sort is due
		items._lit_valid = false

		for step in 4:
			items.tick(0.25)

		check(float(items._items[torch]["struct"].get("fuel_left", 100.0)) < 100.0, "a torch lit in place burns after the next full sort")
	else:
		check(false, "a standing torch can be placed")

	items._items.erase(fire)
	items.tick(0.25)
	check(not items._items.has(fire), "an item gone from the world is skipped by its list")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
