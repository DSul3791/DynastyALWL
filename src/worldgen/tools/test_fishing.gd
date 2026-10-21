extends SceneTree

# Fishing (Items refill 12, data/items/fishing.json): a cast needs water, a bite opens a short window, a second click lands the fish,
# the hidden stock of the cell runs down and comes back, raw fish is raw_sick.
#   godot --headless --path . --script res://src/worldgen/tools/test_fishing.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_fishing"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var clock: Array = [1.0e9]
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.unix_now = func(): return clock[0]
	items.ground_height = func(_x, _z): return 10.0
	items.water_near = func(_p, _r): return false
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "fish-key-000001")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	var rod: int = items.table.number_of("fishing_rod")
	items.action(1, Net.ACT_ADMIN_GIVE, rod, 0, 1, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(rod)
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3.ZERO)
	check(not items._fishing.has(1) and said.has(items._fishing_data()["say_no_water"]), "no water, no cast")

	items.water_near = func(_p, _r): return true
	items._last_fish.clear()
	var cell: Vector2i = items._fish_cell(Vector3(5.0, 10.0, 5.0))
	var stock: int = items.fish_stock(cell)
	check(stock >= 4 and stock <= 12, "a cell holds a few fish (%d)" % stock)
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3.ZERO)
	check(items._fishing.has(1) and str(items._fishing[1]["phase"]) == "wait", "a cast waits for a bite")
	check(items.inventory_of(1).wear[slot] >= 1, "a cast wears the rod")

	# The bite opens a window; the second click lands the fish and uses up stock.
	items._fishing[1]["bites"] = true
	items._fishing[1]["at"] = Time.get_ticks_msec() - 1
	items._fish_tick()
	check(str(items._fishing[1]["phase"]) == "bite" and said.has(items._fishing_data()["say_bite"]), "something bites")
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3.ZERO)
	var caught: int = 0

	for fish in ["trout", "perch", "carp", "pike"]:
		caught += items.inventory_of(1).count_of(items.table.number_of(fish))

	check(caught == 1 and items.fish_stock(cell) == stock - 1, "the click lands one fish and the stock drops")

	# Too slow: the fish gets away.
	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3.ZERO)
	items._fishing[1]["bites"] = true
	items._fishing[1]["at"] = Time.get_ticks_msec() - 1
	items._fish_tick()
	items._fishing[1]["at"] = Time.get_ticks_msec() - 1
	items._fish_tick()
	check(not items._fishing.has(1), "a bite left alone gets away")

	# Walking off cancels the cast.
	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3.ZERO)
	items.report_position(1, Vector3(80.0, 10.0, 5.0))
	items._fish_tick()
	check(not items._fishing.has(1), "walking away reels in")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))

	# The stock runs dry and regrows one fish per regrow_s.
	items._fish_stock.clear()
	items._fish_stock["%d,%d" % [cell.x, cell.y]] = [0, clock[0]]
	check(items.fish_stock(cell) == 0, "an empty cell stays empty")
	clock[0] += 2.0 * float(items._fishing_data()["regrow_s"]) + 5.0
	check(items.fish_stock(cell) == 2, "two regrow periods bring two fish back (%d)" % items.fish_stock(cell))

	# Raw fish makes you sick; cooked fish is a different item.
	check(items._cooking["raw_sick"]["by_id"].has("trout") and str(items._cooking["cooks_into"]["trout"]) == "roast_fish", "raw fish is raw_sick and cooks into roast fish")
	print("fishing tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
