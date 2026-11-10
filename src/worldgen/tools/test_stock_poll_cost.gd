extends SceneTree

# What the hammer list's stock poll costs the server (#1006 follow-up, coordinator 10 Nov 2026): with the list open each player asks for the craft
# stock (pack aside: loose stacks within 12 m, their own chests within 12 m) as they walk. Twenty players at a dense base, 60 chests and 300 loose
# stacks among 6000 other records: the exact scan (every record, as crafting and building use) against the poll's sync-grid scan, and the poll's
# rules (twice a second at most, nothing sent when the stock is unchanged). Prints "stock_poll:" lines; fails only when the grid scan disagrees
# with the exact one or costs more than POLL_BUDGET_MS per player.
#   godot --headless --path . --script res://src/worldgen/tools/test_stock_poll_cost.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

const PLAYERS := 20
const POLL_BUDGET_MS := 2.0
const BASE := Vector3(5000.0, 10.0, 5000.0)

var failures: int = 0
var sent: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _ids(stock: Dictionary) -> Array:
	var out: Array = []

	for row in stock["near"]:
		out.append(int(row[0]))

	for box in stock["boxes"]:
		out.append(-int(box[0]))

	out.sort()
	return out


func _init() -> void:
	var dir: String = "user://test_stock_poll_cost"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_craft_stock = func(p, numbers, _amounts): sent.append([p, numbers.size()])
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var stone: int = items.table.number_of("stone")
	var plank: int = items.table.number_of("lumber")

	for p in range(1, PLAYERS + 1):
		items.peer_connected_hello(p, "stockpoll%04d" % p)
		items.report_position(p, BASE + Vector3(rng.randf_range(-25.0, 25.0), 0.0, rng.randf_range(-25.0, 25.0)))   # luck-exempt: test layout

	for n in 60:
		var spot: Vector3 = BASE + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0))   # luck-exempt: test layout
		var chest: int = items.dev_place("chest@%s,%s,0" % [str(spot.x), str(spot.z)])

		if chest > 0:
			items._items[chest]["struct"]["owner"] = str(items._peer_key[1 + n % PLAYERS])
			items._chests[int(items._items[chest]["struct"]["uid"])].add(plank, 20)

	for n in 300:
		items.drop_in_world(plank, 5, BASE + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0)))   # luck-exempt: test layout

	for n in 6000:   # the rest of the world's records: far loose things
		items._items[items._next_id] = {"number": stone, "count": 1, "pos": Vector3(rng.randf_range(0.0, 4000.0), 10.0, rng.randf_range(0.0, 4000.0)), "left": 1.0e9}   # luck-exempt: test layout
		items._next_id += 1

	items._sync_world_items()
	print("stock_poll: %d records, %d players" % [items._items.size(), PLAYERS])
	var agree: bool = true
	var t0: int = Time.get_ticks_usec()

	for p in range(1, PLAYERS + 1):
		items._stock_of(p)

	var exact_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(PLAYERS)
	t0 = Time.get_ticks_usec()

	for p in range(1, PLAYERS + 1):
		items._stock_of(p, true)

	var grid_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(PLAYERS)

	for p in range(1, PLAYERS + 1):
		agree = agree and _ids(items._stock_of(p)) == _ids(items._stock_of(p, true))

	print("stock_poll: exact scan %.3f ms a player (%.1f ms a second for %d players asking once a second), grid scan %.3f ms a player (%.1f ms a second)" % [exact_ms, exact_ms * PLAYERS, PLAYERS, grid_ms, grid_ms * PLAYERS])
	check(agree, "the grid scan finds the same stacks and chests as the exact scan")
	check(grid_ms <= POLL_BUDGET_MS, "a poll's scan costs at most %.1f ms a player (%.3f)" % [POLL_BUDGET_MS, grid_ms])
	# The poll's rules: the first poll answers, a second within STOCK_POLL_MS is not even looked at, and once the window has passed an unchanged
	# stock sends nothing while a changed one is sent.
	sent.clear()
	items._send_stock(1, true)
	items._send_stock(1, true)
	check(sent.size() == 1, "two polls within half a second: one answer (%d)" % sent.size())
	items._stock_poll_ms.erase(1)
	items._send_stock(1, true)
	check(sent.size() == 1, "an unchanged stock is not sent again (%d)" % sent.size())
	items.drop_in_world(stone, 3, items._peer_pos[1] + Vector3(1.0, 0.0, 0.0))
	items._sync_world_items()
	items._stock_poll_ms.erase(1)
	items._send_stock(1, true)
	check(sent.size() == 2, "a new stack beside the player is sent on the next poll (%d)" % sent.size())
	items._send_stock(1)
	check(sent.size() == 3, "the crafting window's ask is always answered (%d)" % sent.size())
	print("stock_poll: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
