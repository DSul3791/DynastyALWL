extends SceneTree

# The shore net (ACT_NET, data/items/fishing.json "net"): needs water at the edge (5 m, 0.3 to 1.2 m deep, not frozen), holds 20 s,
# walking off or letting go cancels, 1 to 3 small fish never more than the cell's stock, the net wears, dawn beats noon.
#   godot --headless --path . --script res://src/worldgen/tools/test_shore_net.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func fish_count(items) -> int:
	var n: int = 0

	for fish in ["trout", "perch", "carp", "pike"]:
		n += items.inventory_of(1).count_of(items.table.number_of(fish))

	return n


func _init() -> void:
	var dir: String = "user://test_shore_net"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var clock: Array = [1.0e9]
	var game: Array = [12.0 * 3600.0]
	var depth: Array = [0.6]
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.unix_now = func(): return clock[0]
	items.game_seconds = func(): return game[0]
	items.ground_height = func(_x, _z): return 10.0
	items.water_near = func(_p, _r): return true
	items.water_depth_at = func(_p): return depth[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "net-key-0000001")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))
	var cfg: Dictionary = items._fishing_data()["net"]
	var net_no: int = items.table.number_of("shore_net")
	check(net_no > 0, "the shore_net item exists")
	items.action(1, Net.ACT_ADMIN_GIVE, net_no, 0, 1, Vector3.ZERO)
	var slot: int = items.inventory_of(1).numbers.find(net_no)
	var water: Vector3 = Vector3(8.0, 9.5, 5.0)

	# Refusals.
	items.water_near = func(_p, _r): return false
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	check(not items._fishing.has(1) and said.has(cfg["say_no_water"]), "no water, no net")
	items.water_near = func(_p, _r): return true
	items._last_fish.clear()
	items.action(1, Net.ACT_NET, slot, 0, 0, Vector3(30.0, 9.5, 5.0))
	check(not items._fishing.has(1), "water further than the reach is refused")
	items._last_fish.clear()
	depth[0] = 2.0
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	check(not items._fishing.has(1) and said.has(cfg["say_deep"]), "deep water is refused")
	items._last_fish.clear()
	depth[0] = 0.1
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	check(not items._fishing.has(1) and said.has(cfg["say_shallow"]), "a puddle is refused")

	# Start, let go.
	depth[0] = 0.6
	items._last_fish.clear()
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	check(items._fishing.has(1) and str(items._fishing[1]["phase"]) == "net", "the net goes out")
	var started: int = Time.get_ticks_msec()
	check(int(items._fishing[1]["at"]) - started >= 19000, "it takes about 20 s")
	items._fish_tick()
	check(items._fishing.has(1), "nothing happens early")
	items.action(1, Net.ACT_NET, slot, 1, 0, water)
	check(not items._fishing.has(1) and said.has(cfg["say_cancel"]), "letting go cancels")

	# Walking off cancels.
	items._last_fish.clear()
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	items.report_position(1, Vector3(9.0, 10.0, 5.0))
	items._fish_tick()
	check(not items._fishing.has(1), "walking off cancels")
	items.report_position(1, Vector3(5.0, 10.0, 5.0))

	# A haul: 1 to 3 fish, never more than the stock, stock drops, the net wears.
	var cell: Vector2i = items._fish_cell(Vector3(5.0, 10.0, 5.0))
	var most: int = 0

	for _haul in 12:
		items._last_fish.clear()
		var before_fish: int = fish_count(items)
		var before_stock: int = items.fish_stock(cell)
		var before_wear: int = items.inventory_of(1).wear[slot]
		items.action(1, Net.ACT_NET, slot, 0, 0, water)
		items._fishing[1]["at"] = Time.get_ticks_msec() - 1
		items._fish_tick()
		var got: int = fish_count(items) - before_fish
		most = maxi(most, got)
		check(not items._fishing.has(1), "the haul ends the netting")
		check(got <= 3 and got <= before_stock, "never more than 3 or the stock (%d of %d)" % [got, before_stock])
		check(items.fish_stock(cell) == before_stock - got, "the stock drops by what was caught")
		check(items.inventory_of(1).wear[slot] == before_wear + 1, "the net wears 1 per haul")
		clock[0] += 3.0 * float(items._fishing_data()["regrow_s"])

	check(most >= 1, "over 12 hauls something was caught")

	# Empty cell: nothing, but the net still wears.
	items._fish_stock["%d,%d" % [cell.x, cell.y]] = [0, clock[0]]
	items._last_fish.clear()
	var empty_before: int = fish_count(items)
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	items._fishing[1]["at"] = Time.get_ticks_msec() - 1
	items._fish_tick()
	check(fish_count(items) == empty_before and said.has(cfg["say_nothing"]), "an empty cell gives nothing")

	# Dawn beats noon.
	game[0] = 6.0 * 3600.0
	var dawn: float = items._fish_chance(1, cell, false)
	game[0] = 12.0 * 3600.0
	var noon: float = items._fish_chance(1, cell, false)
	check(dawn > noon, "dawn is better than noon (%.2f vs %.2f)" % [dawn, noon])

	# A rod click while netting drops the net state (one thing at a time).
	items._last_fish.clear()
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	check(items._fishing.has(1), "net out again")
	items.action(1, Net.ACT_NET, slot, 0, 0, water)
	check(str(items._fishing[1]["phase"]) == "net", "a second press while netting changes nothing")

	print("shore net tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
