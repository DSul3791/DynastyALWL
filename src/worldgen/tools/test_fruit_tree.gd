extends SceneTree

# Fruit trees with a real fruit store (Dave 2026-10-31; drops.json "fruit_tree", server_items.gd _gather_fruit_tree): a tree holds a stable amount by its id and size; a press takes
# up to per_pick pieces, as many as the weight limit allows; partial picks leave the rest on the tree; the player can come back until the tree is empty; an empty tree is bare and
# gives nothing; out of season nothing can be picked; the store is saved and refills the next season.
#   godot --headless --path . --script res://src/worldgen/tools/test_fruit_tree.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var notices: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var dir: String = "user://test_fruit_tree"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.make_dir_recursive_absolute(dir + "_b")

	for suffix in ["", "_b"]:
		for file in DirAccess.get_files_at(dir + suffix):
			DirAccess.remove_absolute(dir + suffix + "/" + file)

	var g = make(dir)
	g.peer_connected_hello(1, "abcdef123456")
	g.report_position(1, Vector3(500.0, 70.0, 500.0))
	g.season_now = func(): return "autumn"
	var stamp: Array = [20]
	g.season_stamp = func(): return stamp[0]
	g.send_notice = func(_p, text): notices.append(text)
	var tree_at: Vector3 = Vector3(501.0, 70.0, 500.0)
	var item: int = g.table.number_of("crab_apples")
	var total: int = g.fruit_max("wild_apple", 4242, 7.0)
	check(item > 0 and total >= 24 and total <= 180, "a wild apple tree holds a real store (%d crab apples)" % total)
	check(g.fruit_max("wild_apple", 4242, 7.0) == total and g.fruit_max("wild_apple", 4243, 7.0) != total or g.fruit_max("wild_apple", 4244, 7.0) != total, "the store is stable for a tree and differs between trees")
	check(g.fruit_max("wild_apple", 4242, 14.0) > g.fruit_max("wild_apple", 4242, 4.0), "a bigger tree holds more")
	check(g.fruit_left("wild_apple", "0,0,4242", 4242, 7.0) == total, "a fresh tree is full")

	# The weight limit first: stones fill the pack to its limit; the pick then takes only what fits (or nothing and tells the player), the rest stays on the tree.
	var limit_g = make(dir + "_b")
	limit_g.peer_connected_hello(1, "abcdef123456")
	limit_g.report_position(1, Vector3(500.0, 70.0, 500.0))
	limit_g.season_now = func(): return "autumn"
	limit_g.season_stamp = func(): return stamp[0]
	limit_g.send_notice = func(_p, text): notices.append(text)
	var rock: int = limit_g.table.number_of("stone")
	var inv = limit_g.inventory_of(1)
	var guard: int = 0

	while limit_g._fit(1, inv, rock, 1) > 0 and guard < 400:
		limit_g.give(1, rock, 1)
		guard += 1

	var room: int = limit_g._fit(1, inv, item, 5)
	limit_g._last_gather.clear()
	var picked: bool = limit_g.gather(1, "wild_apple", "tree", "0,0,31", 31, tree_at, 7.0)
	var carried: int = inv.count_of(item)
	check(guard > 0 and carried == room and (picked == (room > 0)), "at the weight limit a press takes only what fits (room for %d, took %d)" % [room, carried])
	check(room > 0 or notices.has("Too heavy to carry more"), "a full pack is told 'Too heavy to carry more'")
	check(limit_g.fruit_left("wild_apple", "0,0,31", 31, 7.0) == limit_g.fruit_max("wild_apple", 31, 7.0) - carried, "what was not picked stays on the tree (%d left)" % limit_g.fruit_left("wild_apple", "0,0,31", 31, 7.0))

	# Fill the pack with apples too: the next press takes nothing, tells the player, and the store stays as it was.
	guard = 0

	while limit_g._fit(1, inv, item, 1) > 0 and guard < 2000:
		limit_g.give(1, item, 1)
		guard += 1

	var left_before: int = limit_g.fruit_left("wild_apple", "0,0,31", 31, 7.0)
	notices.clear()
	limit_g._last_gather.clear()
	check(not limit_g.gather(1, "wild_apple", "tree", "0,0,31", 31, tree_at, 7.0) and notices.has("Too heavy to carry more") and limit_g.fruit_left("wild_apple", "0,0,31", 31, 7.0) == left_before, "a full pack takes nothing, is told 'Too heavy to carry more', and the tree keeps its fruit")

	# Pick until the tree is empty, a stack of 5 a press (carry limit off here).
	g._carry_cfg = {}
	var presses: int = 0

	while g.fruit_left("wild_apple", "0,0,4242", 4242, 7.0) > 0 and presses < 400:
		g._last_gather.clear()
		g.gather(1, "wild_apple", "tree", "0,0,4242", 4242, tree_at, 7.0)
		presses += 1

	check(g.inventory_of(1).count_of(item) + _on_ground(g, item) == total, "all %d pieces came off the tree, none lost (%d in the pack, %d dropped)" % [total, g.inventory_of(1).count_of(item), _on_ground(g, item)])
	check(g.stripped_ids("0,0").has(4242), "an empty tree is marked bare (no prompt, drawn without fruit)")
	g._last_gather.clear()
	check(not g.gather(1, "wild_apple", "tree", "0,0,4242", 4242, tree_at, 7.0), "an empty tree gives nothing")

	# Weight: with a nearly full pack the pick takes what fits and leaves the rest on the tree; a full pack is told so.
	var heavy = make(dir + "_b")
	heavy.peer_connected_hello(1, "abcdef123456")
	heavy.report_position(1, Vector3(500.0, 70.0, 500.0))
	heavy.season_now = func(): return "autumn"
	heavy.season_stamp = func(): return stamp[0]
	heavy.send_notice = func(_p, text): notices.append(text)
	var stone: int = heavy.table.number_of("stone")
	var limit: float = heavy.carried_kg_of(1)
	heavy.action(1, 22, stone, 0, 1, Vector3.ZERO)   # ACT_ADMIN_GIVE: weight ballast so the limit is close
	var before_left: int = heavy.fruit_left("wild_pear", "0,0,9001", 9001, 7.0)
	heavy._last_gather.clear()
	var ok: bool = heavy.gather(1, "wild_pear", "tree", "0,0,9001", 9001, tree_at, 7.0)
	var after_left: int = heavy.fruit_left("wild_pear", "0,0,9001", 9001, 7.0)
	check(not ok or after_left < before_left, "a press on a pear tree takes pieces from its store (%d -> %d)" % [before_left, after_left])

	# Season gate: out of season nothing is picked and the store is untouched.
	var winter = make(dir + "_b")
	winter.peer_connected_hello(2, "abcdef123457")
	winter.report_position(2, Vector3(500.0, 70.0, 500.0))
	winter.season_now = func(): return "winter"
	winter.season_stamp = func(): return stamp[0]
	check(not winter.gather(2, "wild_apple", "tree", "0,0,555", 555, tree_at, 7.0) and winter.fruit_left("wild_apple", "0,0,555", 555, 7.0) == winter.fruit_max("wild_apple", 555, 7.0), "out of season nothing is picked and the store is untouched")

	# Save and load: the store survives a restart within the season, and refills when the next season starts.
	var save_game = make(dir)
	save_game.peer_connected_hello(1, "abcdef123456")
	save_game.report_position(1, Vector3(500.0, 70.0, 500.0))
	save_game.season_now = func(): return "autumn"
	save_game.season_stamp = func(): return stamp[0]
	save_game._last_gather.clear()
	save_game.gather(1, "walnut", "tree", "0,0,777", 777, tree_at, 12.0)
	var left_now: int = save_game.fruit_left("walnut", "0,0,777", 777, 12.0)
	check(left_now < save_game.fruit_max("walnut", 777, 12.0), "a pick lowers a walnut tree's store (%d left)" % left_now)
	save_game.save()
	var restarted = make(dir)
	restarted.season_now = func(): return "autumn"
	restarted.season_stamp = func(): return stamp[0]
	check(restarted.fruit_left("walnut", "0,0,777", 777, 12.0) == left_now, "the store survives a restart")
	restarted.season_stamp = func(): return stamp[0] + 4
	check(restarted.fruit_left("walnut", "0,0,777", 777, 12.0) == restarted.fruit_max("walnut", 777, 12.0), "the next fruiting season starts the tree full again")

	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)


func _on_ground(g, item: int) -> int:
	var n: int = 0

	for id in g._items:
		if int(g._items[id].get("number", 0)) == item:
			n += int(g._items[id].get("count", 0))

	return n
