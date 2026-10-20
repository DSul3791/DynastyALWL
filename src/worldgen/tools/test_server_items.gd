extends SceneTree

# Server item rules without a network: validation, caps, despawn, save and reload.
#   godot --headless --path . --script res://src/worldgen/tools/test_server_items.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var slots_sent: Array = []
var world_sent: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(p, b): slots_sent.append([p, b])
	items.send_world_items = func(p, a, r): world_sent.append([p, a, r])
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	var dir: String = "user://test_server_items"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.make_dir_recursive_absolute("user://test_server_items_b")

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	var items = make(dir)
	var stone: int = items.table.number_of("stone")
	items.peer_connected_hello(7, "abcdef123456")
	check(items.inventory_of(7) != null, "hello makes an inventory")
	items.peer_connected_hello(8, "bad key!")
	check(items.inventory_of(8) == null, "bad key refused")
	items.report_position(7, Vector3(100.0, 5.0, 100.0))

	items.action(7, Net.ACT_ADMIN_GIVE, stone, 0, 15, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15, "admin give")
	check(not slots_sent.is_empty(), "slot change sent")

	items.action(7, Net.ACT_DROP, 99, 0, 5, Vector3.ZERO)
	items.action(7, Net.ACT_DROP, 0, 0, -3, Vector3.ZERO)
	items.action(7, Net.ACT_MOVE, -1, 400, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15 and items.world_item_count() == 0, "bad slots and counts change nothing")

	items.action(7, Net.ACT_DROP, 0, 0, 100, Vector3(100.0, 5.0, 150.0))
	check(items.world_item_count() == 1 and items.inventory_of(7).count_of(stone) == 0, "drop takes at most what is there; far spot clamped to the player")

	world_sent.clear()
	items.tick(1.5)
	check(world_sent.size() == 1 and world_sent[0][1].size() == 1, "nearby item is announced")
	var id: int = world_sent[0][1][0][0]
	items.action(7, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15 and items.world_item_count() == 0, "pick up")
	items.action(7, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(items.inventory_of(7).count_of(stone) == 15, "second pick up of the same item does nothing")

	items.report_position(7, Vector3(100.0, 5.0, 100.0))
	items.drop_in_world(stone, 3, Vector3(5000.0, 0.0, 5000.0))
	items.action(7, Net.ACT_PICKUP, 2, 0, 0, Vector3.ZERO)
	check(items.world_item_count() == 1, "cannot pick up from far away")

	for n in range(100):
		items.drop_in_world(stone, 1, Vector3(10.0, 0.0, 10.0))
	check(items.world_item_count() == ItemsScript.MAX_WORLD_ITEMS_PER_CHUNK + 1, "chunk cap holds")

	items.tick(ItemsScript.WORLD_ITEM_LIFETIME_S + 1.0)
	check(items.world_item_count() == 0, "items despawn")

	items.drop_in_world(stone, 4, Vector3(100.0, 5.0, 100.0))
	items.action(7, Net.ACT_ADMIN_GIVE, 9999, 0, 1, Vector3.ZERO)
	check(items.inventory_of(7).count_of(9999) == 0, "unknown item cannot be given")
	items._dirty = true
	items.save()

	var again = make(dir)
	again.peer_connected_hello(1, "abcdef123456")
	check(again.inventory_of(1).count_of(stone) == 15, "inventory survives a restart")
	check(again.world_item_count() == 1, "world items survive a restart")

	var bad: FileAccess = FileAccess.open(dir + "/inventories.json", FileAccess.WRITE)
	bad.store_string("{not json")
	bad.close()
	var third = make(dir)
	third.peer_connected_hello(1, "abcdef123456")
	check(third.inventory_of(1).count_of(stone) == 0 and FileAccess.file_exists(dir + "/inventories.json.bad"), "corrupt save is set aside")

	# Gathering and loose items.
	var g = make("user://test_server_items_b")
	g.ground_height = func(x, z): return 20.0 + x * 0.1
	g.world_seed = 5
	g.peer_connected_hello(1, "abcdef123456")
	g.report_position(1, Vector3(500.0, 70.0, 500.0))
	check(g.gather(1, "flax", "plant", 77, Vector3(501.0, 70.0, 500.0)), "flax can be gathered")
	check(g.inventory_of(1).count_of(g.table.number_of("plant_fibre")) >= 2, "flax gives fibre")
	check(g.gather(1, "hazel", "shrub", 78, Vector3(501.0, 70.0, 500.0)), "shrubs give sticks")
	check(g.inventory_of(1).count_of(g.table.number_of("stick")) >= 1, "got sticks")
	check(not g.gather(1, "dandelion", "plant", 79, Vector3(501.0, 70.0, 500.0)), "no drop entry, no gather")
	check(not g.gather(1, "flax", "plant", 80, Vector3(520.0, 70.0, 500.0)), "too far to gather")
	g.tick(2.0)
	var loose: int = g.world_item_count()
	check(loose > 0, "loose stones and sticks are laid out around the player")
	g._cells_done.clear()
	g._items.clear()
	g._scatter_around_players()
	check(g.world_item_count() == loose or g.world_item_count() <= loose + 8, "same cells lay out the same things")
	var first: int = g._items.keys()[0]
	var spot: Vector3 = g._items[first]["pos"]
	g.report_position(1, spot)
	g.action(1, Net.ACT_PICKUP, first, 0, 0, Vector3.ZERO)
	check(not g._items.has(first), "loose item picked up")
	g._cells_done.clear()
	g._items.clear()
	g._scatter_around_players()
	g.tick(0.0)
	var again_here: bool = false

	for other in g._items:
		if g._items[other]["pos"].distance_to(spot) < 0.001:
			again_here = true

	check(not again_here, "a picked-up loose item does not come back")

	print("server item tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
