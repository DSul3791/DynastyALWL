extends SceneTree

# First-hour thatch pieces (Sal, 24 Oct): a thatch floor (the tier 1 foundation), a wall, a roof and a doorway are placed on it,
# the world is saved and loaded again, and the same pieces stand in the same places with the same ids and snaps.
#   godot --headless --path . --script res://src/worldgen/tools/test_thatch_pieces.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func place(items, kit: String, spot: Vector3) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(kit), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of(kit)), 0, 0, spot)


# The structure rows of a world, as [kind, x, y, z, yaw] sorted so two worlds compare equal.
func pieces_of(items) -> Array:
	var out: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct"):
			out.append([str(it["struct"]["kind"]), snappedf(it["pos"].x, 0.01), snappedf(it["pos"].y, 0.01), snappedf(it["pos"].z, 0.01), snappedf(float(it["struct"]["yaw"]), 0.1)])

	out.sort()
	return out


func _init() -> void:
	var dir: String = "user://test_thatch_pieces"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	items.peer_connected_hello(1, "thatchkey0001")
	items.report_position(1, Vector3(400.0, 10.0, 400.0))
	place(items, "thatch_floor_kit", Vector3(400.0, 10.0, 402.0))
	place(items, "thatch_wall_kit", Vector3(399.2, 10.0, 399.7))
	place(items, "thatch_doorway_kit", Vector3(402.0, 10.0, 399.7))
	place(items, "thatch_roof_kit", Vector3(400.0, 10.0, 402.0))
	var before: Array = pieces_of(items)
	var kinds: Array = before.map(func(row): return row[0])
	check(kinds.has("thatch_floor") and kinds.has("thatch_wall") and kinds.has("thatch_doorway") and kinds.has("thatch_roof"), "floor, wall, doorway and roof are all placed (%s)" % str(kinds))

	for row in before:
		if row[0] == "thatch_wall" or row[0] == "thatch_doorway":
			check(is_equal_approx(row[2], 10.1), "a %s stands on the thatch floor top, 0.1 m up (y %.2f)" % [row[0], row[2]])

	var ids_before: Array = items._items.keys()
	items._dirty = true
	items.save()
	var again = make(dir)
	again.peer_connected_hello(1, "thatchkey0001")
	var after: Array = pieces_of(again)
	check(after == before, "the same pieces stand in the same places after save and reload (%d before, %d after)" % [before.size(), after.size()])
	check(again._items.keys().size() == ids_before.size(), "no piece is lost or doubled on reload (%d ids)" % again._items.keys().size())

	# A piece placed after the reload still snaps to the saved thatch floor and the ids keep counting up.
	again.report_position(1, Vector3(400.0, 10.0, 400.0))
	var walls_before: int = after.filter(func(row): return row[0] == "thatch_wall").size()
	again.action(1, Net.ACT_ADMIN_GIVE, again.table.number_of("thatch_wall_kit"), 0, 1, Vector3.ZERO)
	again.action(1, Net.ACT_PLACE, again.inventory_of(1).numbers.find(again.table.number_of("thatch_wall_kit")), 0, 0, Vector3(400.8, 10.0, 404.3))
	var walls_after: int = pieces_of(again).filter(func(row): return row[0] == "thatch_wall").size()
	check(walls_after == walls_before + 1, "a wall placed after the reload snaps on the saved floor and is added (%d to %d)" % [walls_before, walls_after])
	var top_id: int = 0

	for id in ids_before:
		top_id = maxi(top_id, int(id))

	var newest: int = 0

	for id in again._items:
		newest = maxi(newest, int(id))

	check(newest > top_id, "new ids keep counting up after the reload")
	# The thatch floor is made by hand (Dave 25 Oct): known from the start, no bench, 6 twine and 20 thatch.
	var hand = make("user://test_thatch_hand")
	hand.peer_connected_hello(1, "thatchhand001")
	var floor_recipe: Dictionary = hand.recipes.recipe(166)
	check(bool(floor_recipe["known"]) and str(floor_recipe["station"]) == "", "the thatch floor recipe is known from the start and needs no bench")

	for number in [166, 167, 168, 169]:   # floor, wall, roof, doorway: all made in the hand
		var piece: Dictionary = hand.recipes.recipe(number)
		check(bool(piece["known"]) and str(piece["station"]) == "", "thatch kit recipe %d (%s) is made in the hand, no bench" % [number, str(piece["name"])])
	hand.action(1, Net.ACT_ADMIN_GIVE, hand.table.number_of("twine"), 0, 6, Vector3.ZERO)
	hand.action(1, Net.ACT_ADMIN_GIVE, hand.table.number_of("thatch"), 0, 20, Vector3.ZERO)
	hand._admin_mode_off[1] = true
	hand._last_queue_act.clear()
	hand.action(1, Net.ACT_CRAFT_QUEUE, 166, 0, 1, Vector3.ZERO)
	check(not hand._craft_queues[hand._peer_key[1]]["entries"].is_empty(), "6 twine and 20 thatch queue a thatch floor with no bench nearby")

	print("thatch pieces tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
