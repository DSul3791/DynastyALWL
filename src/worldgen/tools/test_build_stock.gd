extends SceneTree

# Building on the spot (Dave 2 Nov 2026): a hammer blueprint takes its heavy materials from loose stacks lying within BUILD_STOCK_M
# of the builder first, then the pack, so a stone wall (12 blocks of 25 kg) can be carried over in trips and stacked beside the site.
#   godot --headless --path . --script res://src/worldgen/tools/test_build_stock.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _give(id: String, count: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, count, Vector3.ZERO)


func _have(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func _on_ground(id: String) -> int:
	var n: int = 0

	for k in items._items:
		var it: Dictionary = items._items[k]

		if not it.has("struct") and not it.has("tree") and int(it.get("number", 0)) == items.table.number_of(id):
			n += int(it["count"])

	return n


func _walls() -> int:
	var n: int = 0

	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "stone_wall" and not items._items[k]["struct"].has("site"):   # a blueprint site is not a wall yet
			n += 1

	return n


func _init() -> void:
	var dir: String = "user://test_build_stock"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "buildstockkey1")
	var here: Vector3 = Vector3(300.0, 10.0, 300.0)
	items.report_position(1, here)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))
	var wall: Dictionary = parsed["blueprints"]["stone_wall"]
	var blocks: int = 0
	var mortar: int = 0

	for need in wall["cost"]:
		if str(need[0]) == "cut_stone_block":
			blocks = int(need[1])
		elif str(need[0]) == "mortar":
			mortar = int(need[1])

	check(blocks > 0 and mortar > 0, "the stone wall blueprint costs blocks and mortar")
	_give("wooden_hammer", 1)
	_give("mortar", mortar)

	# Blocks stacked 2 m away, none in the pack: the wall goes up and the stack is used.
	check(items.drop_in_world(items.table.number_of("cut_stone_block"), blocks, here + Vector3(2.0, 0.0, 0.0)), "blocks laid on the ground")
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, here + Vector3(0.0, 0.0, 3.0))
	check(_walls() == 1, "the wall is built from the ground stack")
	check(_on_ground("cut_stone_block") == 0, "the ground blocks were used")
	check(_have("mortar") == 0, "the mortar came out of the pack")

	# Half on the ground, half in the pack: both are used, the ground first. The builder walks to a new site (placing has a 6 m reach).
	var site2: Vector3 = here + Vector3(16.0, 0.0, 0.0)
	items.report_position(1, site2)
	_give("mortar", mortar)
	_give("cut_stone_block", blocks)
	items.drop_in_world(items.table.number_of("cut_stone_block"), blocks / 2, site2 + Vector3(-2.0, 0.0, 0.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, site2 + Vector3(0.0, 0.0, 3.0))
	check(_walls() == 2, "a wall from ground and pack")
	check(_on_ground("cut_stone_block") == 0 and _have("cut_stone_block") == blocks / 2, "ground stack used first, the rest from the pack (%d left)" % _have("cut_stone_block"))

	# Stock too far away does not count, and nothing is taken.
	items.inventory_of(1).remove(items.table.number_of("cut_stone_block"), _have("cut_stone_block"))
	_give("mortar", mortar)
	var site3: Vector3 = here + Vector3(-16.0, 0.0, 0.0)
	items.report_position(1, site3)
	items.drop_in_world(items.table.number_of("cut_stone_block"), blocks, site3 + Vector3(-20.0, 0.0, 0.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(wall["number"]), 0, 0, site3 + Vector3(0.0, 0.0, 3.0))
	check(_walls() == 2, "blocks 20 m away do not build a wall")
	check(_on_ground("cut_stone_block") == blocks and _have("mortar") == mortar, "a refused wall takes nothing")

	print("test_build_stock: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
