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

	_check_site_gather(blocks, mortar, site3)
	_check_group_stock(blocks, mortar, int(wall["number"]), here + Vector3(0.0, 0.0, 40.0))
	_check_group_refund()
	_check_chest_build(blocks, mortar, int(wall["number"]), here + Vector3(0.0, 0.0, -60.0))

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
func _check_site_gather(blocks: int, mortar: int, site3: Vector3) -> void:
	var half: int = floori(float(blocks) / 2.0)
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
	items.drop_in_world(block_n, half, site3 + Vector3(8.0, 0.0, 0.0))
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
	check(int(have.get("cut_stone_block", 0)) == 2 + half, "the pack's 2 blocks and the 8 m stack went in (%s)" % str(have))
	check(_have("cut_stone_block") == 0 and _on_ground("cut_stone_block") == blocks, "the pack first, then the near stack; the 20 m stack untouched")
	check(int(have.get("mortar", 0)) == mortar and own_box.count_of(items.table.number_of("mortar")) == 3, "only the mortar it needs, from the builder's own chest")
	check(stranger_box.count_of(items.table.number_of("mortar")) == mortar, "a stranger's chest is never used")
	check(said.size() == 1 and str(said[0]).begins_with("Pulled ") and str(said[0]).contains("Still needed: %d " % (blocks - 2 - half)), "one line: what came and what is still missing (%s)" % str(said))
	# The rest carried to within reach: the next hit finishes it.
	items.drop_in_world(block_n, blocks, site3 + Vector3(-3.0, 0.0, 2.0))
	said.clear()
	items.action(1, Net.ACT_REPAIR_STRUCT, site, 0, 0, Vector3.ZERO)
	check(items._items.has(site) and not items._items[site]["struct"].has("site"), "with nothing missing the wall is built")
	check(said.size() == 1 and str(said[0]).ends_with("Built."), "and the line says so (%s)" % str(said))
	check(_on_ground("cut_stone_block") == blocks + blocks - (blocks - 2 - half), "only what was missing came off the new stack (%d on the ground)" % _on_ground("cut_stone_block"))


# A group cost (Jamie 10 Nov 2026: Bronze nails and Bronze hinges fill any blueprint asking for nails or hinges, through wood_species.json
# ingredient_groups) is filled by any member: from the ground stock beside the builder and on a blueprint site's deposit, as from the pack. A stand-in
# group here: clay fills mortar.
func _check_group_stock(blocks: int, mortar: int, wall_number: int, spot: Vector3) -> void:
	var mortar_n: int = items.table.number_of("mortar")
	var clay_n: int = items.table.number_of("clay")
	items.table._groups[mortar_n] = PackedInt32Array([mortar_n, clay_n])
	var block_n: int = items.table.number_of("cut_stone_block")
	var inv = items.inventory_of(1)
	inv.remove(block_n, inv.count_of(block_n))
	inv.remove(mortar_n, inv.count_of(mortar_n))
	inv.remove(clay_n, inv.count_of(clay_n))
	var walls_before: int = _walls()
	items.report_position(1, spot)
	_give("cut_stone_block", blocks)
	items.drop_in_world(clay_n, mortar, spot + Vector3(2.0, 0.0, 0.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, wall_number, 0, 0, spot + Vector3(0.0, 0.0, 3.0))
	check(_walls() == walls_before + 1 and _on_ground("clay") == 0, "clay on the ground fills the wall's mortar (a group member in the ground stock)")
	# A site that needs mortar takes clay from the pack and from the ground on a deposit.
	var site_spot: Vector3 = spot + Vector3(12.0, 0.0, 0.0)
	items.report_position(1, site_spot)
	_give("cut_stone_block", blocks)
	items.action(1, Net.ACT_PLACE_BLUEPRINT, wall_number, 0, 0, site_spot + Vector3(0.0, 0.0, 3.0))
	var site: int = _site_at(site_spot + Vector3(0.0, 0.0, 3.0))
	check(site != 0, "with no mortar or clay to hand the wall is set down as a site")

	if site == 0:
		return

	var view: Array = items._site_view(1, items._items[site])
	_give("clay", 1)
	items.drop_in_world(clay_n, mortar - 1, site_spot + Vector3(-2.0, 0.0, 0.0))
	var view_after: Array = items._site_view(1, items._items[site])
	var on_hand: int = 0

	for row in view_after:
		on_hand += int(row[2]) if str(row[0]) == "mortar" else 0

	check(not view.is_empty() and on_hand == mortar, "the site's list counts clay in the pack and on the ground as mortar on hand (%d)" % on_hand)
	items._deposit_site(1, inv, site)
	check(items._items.has(site) and not items._items[site]["struct"].has("site"), "the deposit takes the clay and the wall is built")
	check(inv.count_of(clay_n) == 0 and _on_ground("clay") == 0, "all the clay went in")
	items.table._groups.erase(mortar_n)


# A group cost gives back its lowest member (coordinator 10 Nov 2026: a wall built with Bronze nails must not give back iron Nails), since which member
# was paid in is not recorded: the lowest tier, then material, then value; a full tie keeps the group's own id (plain logs for any log).
func _check_group_refund() -> void:
	var t = items.table
	check(items._refund_number(t.number_of("knife")) == t.number_of("stone_knife"), "a knife cost gives back the stone knife (tier 1)")
	check(items._refund_number(t.number_of("wooden_block")) == t.number_of("wooden_block_soft"), "a wooden block cost gives back the cheaper softwood block")
	check(items._refund_number(t.number_of("log")) == t.number_of("log"), "a log cost still gives back plain logs")
	check(items._refund_number(t.number_of("mortar")) == t.number_of("mortar"), "a cost that is no group gives back itself")
	# A stand-in pair like Nails and Bronze nails: the bronze member ranks below one with no material.
	var nails_n: int = t.number_of("nails")
	var bronze_n: int = t.number_of("bronze_ingot")
	t._groups[nails_n] = PackedInt32Array([nails_n, bronze_n])
	var bronze_entry: Dictionary = t.entry("bronze_ingot")
	var had_material: bool = bronze_entry.has("material")
	bronze_entry["material"] = "bronze"   # stands in for Bronze nails' material (the stand-in has none of its own)
	check(items._refund_number(nails_n) == bronze_n, "a bronze member is given back before a member with no material")
	var inv = items.inventory_of(1)
	inv.remove(bronze_n, inv.count_of(bronze_n))
	inv.remove(nails_n, inv.count_of(nails_n))
	check(items._refund_blueprint(1, inv, {"cost": [["nails", 4]]}, true) and inv.count_of(bronze_n) == 4 and inv.count_of(nails_n) == 0, "a taken-down piece gives back the lowest member")
	inv.remove(bronze_n, 4)
	items._refund_entry(1, [0, 2, [[nails_n, 3]]])
	check(inv.count_of(bronze_n) == 6 and inv.count_of(nails_n) == 0, "a cancelled craft gives back the lowest member too")
	inv.remove(bronze_n, 6)
	t._groups.erase(nails_n)

	if not had_material:
		bronze_entry.erase("material")


# A blueprint draws on what a craft draws on (CraftStock, coordinator 10 Nov 2026): the pack, loose stacks within 12 m and the builder's own containers
# within 12 m that are not kept out. The hammer list counts the same stock, so a piece it shows as covered is built at once, never set down as a site.
func _check_chest_build(blocks: int, mortar: int, wall_number: int, spot: Vector3) -> void:
	var inv = items.inventory_of(1)
	var block_n: int = items.table.number_of("cut_stone_block")
	var mortar_n: int = items.table.number_of("mortar")
	inv.remove(block_n, inv.count_of(block_n))
	inv.remove(mortar_n, inv.count_of(mortar_n))
	items.report_position(1, spot)
	var own: int = items.dev_place("chest@%s,%s,0" % [str(spot.x + 7.0), str(spot.z)])
	items._items[own]["struct"]["owner"] = str(items._peer_key[1])
	var own_box = items._chests[int(items._items[own]["struct"]["uid"])]
	own_box.add(mortar_n, mortar)
	var stranger: int = items.dev_place("chest@%s,%s,0" % [str(spot.x - 7.0), str(spot.z)])
	items._items[stranger]["struct"]["owner"] = "someoneelse99"
	var stranger_box = items._chests[int(items._items[stranger]["struct"]["uid"])]
	stranger_box.add(block_n, blocks)
	var walls_before: int = _walls()
	items.action(1, Net.ACT_PLACE_BLUEPRINT, wall_number, 0, 0, spot + Vector3(0.0, 0.0, 3.0))
	check(_walls() == walls_before and _site_at(spot + Vector3(0.0, 0.0, 3.0)) != 0, "a stranger's chest of blocks does not count: the wall is set down as a site")
	check(stranger_box.count_of(block_n) == blocks and own_box.count_of(mortar_n) == mortar, "setting down a site takes nothing from either chest")
	# Blocks lying 9 m away (past the 4 m ground stock, inside the 12 m craft stock) and the mortar in the builder's own chest: built at once.
	var spot2: Vector3 = spot + Vector3(0.0, 0.0, -8.0)
	items.report_position(1, spot2)
	items.drop_in_world(block_n, blocks, spot2 + Vector3(0.0, 0.0, -9.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, wall_number, 0, 0, spot2 + Vector3(0.0, 0.0, -3.0))
	check(_walls() == walls_before + 1, "blocks 9 m away and mortar in the builder's own chest build the wall at once")
	check(own_box.count_of(mortar_n) == 0 and stranger_box.count_of(block_n) == blocks, "the mortar came out of the builder's chest; the stranger's blocks are untouched")
	var far_blocks: int = 0

	for k in items._items:
		var it: Dictionary = items._items[k]
		far_blocks += int(it["count"]) if not it.has("struct") and int(it.get("number", 0)) == block_n and (it["pos"] as Vector3).distance_to(spot2) < 10.0 else 0

	check(far_blocks == 0, "the blocks 9 m away were used")

