extends SceneTree

# Bushes and shrubs (Dave 2 Nov 2026, hazel too): an axe chops one up into leaves and sticks; a pickaxe digs it up whole as <species>_bush;
# the dug bush plants again elsewhere as a full-size bush (dynamic flora), which is a shrub, never a tree to fell.
#   godot --headless --path . --script res://src/worldgen/tools/test_shrub_work.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_shrub_work"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	var said: Array = []
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return 5000000.0
	var standing: Dictionary = {11: Vector3(12.0, 10.0, 10.0), 12: Vector3(14.0, 10.0, 10.0)}   # flora id -> position of a hazel
	var cut: Array = []
	items.shrub_info = func(_chunk, id) -> Dictionary: return {"name": "hazel", "position": standing[id], "height": 2.0} if standing.has(id) else {}
	items.cut_tree = func(_chunk, id) -> bool:
		cut.append(id)
		return standing.erase(id)
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "shrub-work-key-01")
	items.report_position(1, Vector3(10.0, 10.0, 10.0))
	var inv = items.inventory_of(1)
	var leaves: int = items.table.number_of("leaves")
	var stick: int = items.table.number_of("stick")
	var hazel_bush: int = items.table.number_of("hazel_bush")
	check(hazel_bush != 0, "hazel_bush is an item")

	# No tool: nothing happens.
	items.action(1, Net.ACT_HIT_SHRUB, 11, 0, 0, Vector3(float(HeldTool.slot_of(items, "axe") + 1), 0.0, 0.0))
	items._last_hit.clear()
	items.action(1, Net.ACT_HIT_SHRUB, 11, 0, 0, Vector3(float(HeldTool.slot_of(items, "axe") + 1), 0.0, 0.0))
	check(cut.is_empty(), "with no axe the bush stays")

	# The axe: two blows chop it into leaves and sticks.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	var leaves_before: int = inv.count_of(leaves)
	var sticks_before: int = inv.count_of(stick)
	items._last_hit.clear()
	items.action(1, Net.ACT_HIT_SHRUB, 11, 0, 0, Vector3(float(HeldTool.slot_of(items, "axe") + 1), 0.0, 0.0))
	check(cut.is_empty(), "one axe blow does not finish it")
	items._last_hit.clear()
	items.action(1, Net.ACT_HIT_SHRUB, 11, 0, 0, Vector3(float(HeldTool.slot_of(items, "axe") + 1), 0.0, 0.0))
	check(cut == [11], "the second axe blow chops the bush away (%s)" % str(cut))
	check(inv.count_of(leaves) > leaves_before and inv.count_of(stick) > sticks_before, "and gives leaves and sticks (%d leaves, %d sticks)" % [inv.count_of(leaves) - leaves_before, inv.count_of(stick) - sticks_before])
	check(inv.count_of(hazel_bush) == 0, "an axe never gives the bush whole")

	# No pickaxe, nothing in hand (at.x = 0; the axe stays on the hotbar): refused, the axe is not used.
	items._last_hit.clear()
	items.action(1, Net.ACT_HIT_SHRUB, 12, 0, 0, Vector3(float(HeldTool.slot_of(items, "pick") + 1), 0.0, 0.0))
	items._last_hit.clear()
	items.action(1, Net.ACT_HIT_SHRUB, 12, 0, 0, Vector3(float(HeldTool.slot_of(items, "pick") + 1), 0.0, 0.0))
	check(cut == [11], "no pickaxe: the second bush stays")

	# The pickaxe: two blows dig it up whole.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_pickaxe"), 0, 1, Vector3.ZERO)
	items._last_hit.clear()
	items.action(1, Net.ACT_HIT_SHRUB, 12, 0, 0, Vector3(float(HeldTool.slot_of(items, "pick") + 1), 0.0, 0.0))
	items._last_hit.clear()
	items.action(1, Net.ACT_HIT_SHRUB, 12, 0, 0, Vector3(float(HeldTool.slot_of(items, "pick") + 1), 0.0, 0.0))
	check(cut == [11, 12] and inv.count_of(hazel_bush) == 1, "a pickaxe digs the hazel up whole into the pack (%s, %d)" % [str(cut), inv.count_of(hazel_bush)])

	# Planting it: a full-size hazel stands where the player aimed, as a shrub.
	var spot: Vector3 = Vector3(11.0, 10.0, 12.0)
	items.action(1, Net.ACT_PLANT_BUSH, inv.numbers.find(hazel_bush), 0, 0, spot)
	check(inv.count_of(hazel_bush) == 0 and items._saplings.size() == 1, "planting takes the bush from the pack and plants it (%d planted)" % items._saplings.size())

	if items._saplings.size() == 1:
		var planted: Dictionary = items._saplings[0]
		var home: Vector2i = Vector2i(planted["chunk"][0], planted["chunk"][1])
		var id: int = (int(planted["species"]) << 16) | (0xFFFF - int(planted["slot"]))
		var info: Dictionary = items.dynamic_shrub_info(home, id)
		check(str(info.get("name", "")) == "hazel" and (info["position"] as Vector3).distance_to(spot) < 0.01, "it is a hazel where the player aimed (%s)" % str(info))
		check(float(info.get("height", 0.0)) > 0.5, "full size at once (%.2f m)" % float(info.get("height", 0.0)))
		check(items.dynamic_tree_info(home, id).is_empty(), "a planted bush is not a tree to fell")
		check(items.dynamic_items(home)["ids"].has(id), "it is sent with the chunk's flora")

	# Too far, or in water: refused, the bush stays in the pack.
	items.action(1, Net.ACT_ADMIN_GIVE, hazel_bush, 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLANT_BUSH, inv.numbers.find(hazel_bush), 0, 0, Vector3(40.0, 10.0, 40.0))
	check(inv.count_of(hazel_bush) == 1, "too far away: not planted")
	items.water_depth_at = func(_p): return 0.3
	items.action(1, Net.ACT_PLANT_BUSH, inv.numbers.find(hazel_bush), 0, 0, Vector3(9.0, 10.0, 8.0))
	check(inv.count_of(hazel_bush) == 1 and said.has("You cannot plant it in water."), "in water: not planted, and told why")
	items.water_depth_at = Callable()
	items.action(1, Net.ACT_PLANT_BUSH, inv.numbers.find(hazel_bush), 0, 0, spot + Vector3(0.3, 0.0, 0.0))
	check(inv.count_of(hazel_bush) == 1 and said.has("Too close to another plant."), "right beside the first: not planted")

	# A tree's seed (gardening, Dave 14 Nov 2026): an acorn goes in as an oak sapling that grows like wild regrowth (planted now, not full size), 2 m from other plants.
	var acorns: int = items.table.number_of("acorns")
	check(items.tree_seed_species("acorns") == "oak" and items.tree_seed_species("maple_keys") == "maple" and items.tree_seed_species("stone") == "", "acorns are the oak's seed, maple keys the maple's; a stone is no seed")
	items.action(1, Net.ACT_ADMIN_GIVE, acorns, 0, 2, Vector3.ZERO)
	said.clear()
	items.action(1, Net.ACT_PLANT_BUSH, inv.numbers.find(acorns), 0, 0, spot + Vector3(0.0, 0.0, -1.5))
	check(inv.count_of(acorns) == 2 and said.has("Too close to another plant."), "a tree seed 1.5 m from the hazel: not planted (trees keep 2 m)")
	items.action(1, Net.ACT_PLANT_BUSH, inv.numbers.find(acorns), 0, 0, spot + Vector3(0.0, 0.0, -2.5))
	check(inv.count_of(acorns) == 1 and items._saplings.size() == 2, "an acorn 2.5 m away is planted from the pack (%d planted)" % items._saplings.size())

	if items._saplings.size() == 2:
		var oak: Dictionary = items._saplings[1]
		check(int(oak["species"]) == int(items._flora_by_name["oak"]["id"]) and is_equal_approx(float(oak["planted_at"]), 5000000.0), "it is an oak sapling planted now, to grow (%s)" % str(oak))
		var oak_home: Vector2i = Vector2i(oak["chunk"][0], oak["chunk"][1])
		var oak_id: int = (int(oak["species"]) << 16) | (0xFFFF - int(oak["slot"]))
		check(items.dynamic_tree_info(oak_home, oak_id).is_empty() and items.dynamic_shrub_info(oak_home, oak_id).is_empty(), "a new sapling is not yet a tree to fell")
		items.game_seconds = func(): return 5000000.0 + ItemsScript.SAPLING_GROWN_S
		check(str(items.dynamic_tree_info(oak_home, oak_id).get("name", "")) == "oak", "grown, it is an oak to fell (%s)" % str(items.dynamic_tree_info(oak_home, oak_id)))
		items.game_seconds = func(): return 5000000.0

	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("crab_apples"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLANT_BUSH, inv.numbers.find(items.table.number_of("crab_apples")), 0, 0, spot + Vector3(-2.5, 0.0, 0.0))
	check(items._saplings.size() == 3 and int(items._saplings[-1]["species"]) == int(items._flora_by_name["wild_apple"]["id"]), "a crab apple grows a wild apple tree")

	items._finish_writer()
	print("test_shrub_work: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
