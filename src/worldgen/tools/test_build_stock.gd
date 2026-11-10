extends SceneTree

# Building on the spot (Dave 2 Nov 2026): a hammer blueprint takes its heavy materials from loose stacks lying within BUILD_STOCK_M
# of the builder first, then the pack, so a stone wall (12 blocks of 25 kg) can be carried over in trips and stacked beside the site.
#   godot --headless --path . --script res://src/worldgen/tools/test_build_stock.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []


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
	items.send_notice = func(_p, text): said.append(text)
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

	_check_site_gather(wall, blocks, mortar, site3)

	print("test_build_stock: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)



func _site_at(at: Vector3) -> int:
	for k in items._items:
		var it: Dictionary = items._items[k]

		if it.has("struct") and it["struct"].has("site") and (it["pos"] as Vector3).distance_to(at) < 1.0:
			return int(k)

	return 0


# The hammer in Repair mode on a blueprint site (Dave 10 Nov 2026, craft from containers built in): it pulls what the site still needs from within
# building_wear.json site_gather_m (12 m) of the builder, the pack first, then the ground and the builder's own containers nearest first; never more than
# it needs, never from a stranger's chest; one line says what came and what is missing.
func _check_site_gather(wall: Dictionary, blocks: int, mortar: int, site3: Vector3) -> void:
	var site: int = _site_at(site3 + Vector3(0.0, 0.0, 3.0))
	check(site != 0, "the refused wall left a blue site")

	if site == 0:
		return

	check(float(items._wear_cfg.get("site_gather_m", 0.0)) == 12.0, "the gather reach is 12 m, from the json")
	var block_n: int = items.table.number_of("cut_stone_block")
	# The 20 m stack is out of reach: nothing comes, and the line says what is missing.
	items.inventory_of(1).remove(items.table.number_of("mortar"), _have("mortar"))
	said.clear()
	items.action(1, Net.ACT_REPAIR_STRUCT, site, 0, 0, Vector3.ZERO)
	check(_on_ground("cut_stone_block") == blocks and said.size() == 1 and str(said[0]).begins_with("Nothing within 12 m"), "stock 20 m away is not taken (%s)" % str(said))
	# Half the blocks 8 m away on the ground, a few in the pack, the mortar in the builder's own chest 6 m away, more mortar in a stranger's chest.
	items.drop_in_world(block_n, blocks / 2, site3 + Vector3(8.0, 0.0, 0.0))
	_give("cut_stone_block", 2)
	var own: int = items.dev_place("chest@%s,%s,0" % [str(site3.x - 6.0), str(site3.z)])
	items._items[own]["struct"]["owner"] = str(items._peer_key[1])
	var stranger: int = items.dev_place("chest@%s,%s,0" % [str(site3.x), str(site3.z - 5.0)])
	items._items[stranger]["struct"]["owner"] = "someoneelse99"
	var own_box = items._chests[int(items._items[own]["struct"]["uid"])]
	var stranger_box = items._chests[int(items._items[stranger]["struct"]["uid"])]
	own_box.add(items.table.number_of("mortar"), mortar + 3)
	stranger_box.add(items.table.number_of("mortar"), mortar)
	said.clear()
	items.action(1, Net.ACT_REPAIR_STRUCT, site, 0, 0, Vector3.ZERO)
	var have: Dictionary = items._site_of(items._items[site])["have"]
	check(int(have.get("cut_stone_block", 0)) == 2 + blocks / 2, "the pack's 2 blocks and the 8 m stack went in (%s)" % str(have))
	check(_have("cut_stone_block") == 0 and _on_ground("cut_stone_block") == blocks, "the pack first, then the near stack; the 20 m stack untouched")
	check(int(have.get("mortar", 0)) == mortar and own_box.count_of(items.table.number_of("mortar")) == 3, "only the mortar it needs, from the builder's own chest")
	check(stranger_box.count_of(items.table.number_of("mortar")) == mortar, "a stranger's chest is never used")
	check(said.size() == 1 and str(said[0]).begins_with("Pulled ") and str(said[0]).contains("Still needed: %d " % (blocks - 2 - blocks / 2)), "one line: what came and what is still missing (%s)" % str(said))
	# The rest carried to within reach: the next hit finishes it.
	items.drop_in_world(block_n, blocks, site3 + Vector3(-3.0, 0.0, 2.0))
	said.clear()
	items.action(1, Net.ACT_REPAIR_STRUCT, site, 0, 0, Vector3.ZERO)
	check(items._items.has(site) and not items._items[site]["struct"].has("site"), "with nothing missing the wall is built")
	check(said.size() == 1 and str(said[0]).ends_with("Built."), "and the line says so (%s)" % str(said))
	check(_on_ground("cut_stone_block") == blocks + blocks - (blocks - 2 - blocks / 2), "only what was missing came off the new stack (%d on the ground)" % _on_ground("cut_stone_block"))
