extends SceneTree

# Playthrough probe 8 (read-only): what a lit campfire cooks (Dave 2026-10-31: meat only) and what a nettle gives
# The real server_items.gd with the real baked ground heights (terrain_generator.surface_height) as ground_height; water depth from the same heights (sea at 0).
#   godot --headless --path . --script res://art/playthrough/probe_cook.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var generator
var items
var last_notice: String = ""
var next_peer: int = 2


func h(x: float, z: float) -> float:
	return generator.surface_height(x, z)


func n(id: String) -> int:
	return items.table.number_of(id)


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var dir: String = "user://probe_place"
	DirAccess.make_dir_recursive_absolute(dir)

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): last_notice = t
	items.ground_height = func(x, z): return h(x, z)
	items.water_depth_at = func(pos: Vector3): return maxf(0.0 - h(pos.x, pos.z), 0.0)
	items.tree_info = func(_c, _i): return {}
	items.cut_tree = func(_c, _i): return false
	items.water_near = func(_pos, _reach): return false
	items.setup(ItemTableScript.load_default(), dir)
	var spawn: Vector2 = Vector2(53316.0, 68476.0)
	var ground: float = h(spawn.x, spawn.y)
	var peer: int = 2
	items.peer_connected_hello(peer, "probe800000002")
	items.report_position(peer, Vector3(spawn.x - 1.5, ground, spawn.y))
	items.vitals_of(peer)["weight"] = 900.0
	items.give(peer, n("campfire_kit"), 1)
	items.action(peer, Net.ACT_PLACE, items.inventory_of(peer).numbers.find(n("campfire_kit")), 0, 0, Vector3(spawn.x, ground, spawn.y))
	var fire_id: int = items._items.keys().back()
	items.give(peer, n("plant_fibre"), 1)
	items.action(peer, Net.ACT_LIGHT, fire_id, 0, 0, Vector3.ZERO)
	print("probe8: fire state ", items._items[fire_id]["fire"]["state"], " (lit when not 9)")

	for raw in ["raspberries", "hazelnuts", "morel", "wild_garlic_bulbs", "fiddleheads", "raw_meat", "carp", "shellfish", "crab_meat", "seal_meat"]:
		if n(raw) == 0:
			print("probe8: ", raw, " is not an item")
			continue

		var inv = items.inventory_of(peer)

		for s in range(inv.SLOTS):
			if inv.numbers[s] != 0:
				inv.take_from_slot(s, 999)

		items.give(peer, n(raw), 1)
		items._last_cook.clear()
		last_notice = ""
		items.action(peer, Net.ACT_COOK, fire_id, 0, 0, Vector3.ZERO)
		var left: int = inv.count_of(n(raw))
		var got: String = ""

		for s in range(inv.SLOTS):
			if inv.numbers[s] != 0:
				got += items.table.id_of(inv.numbers[s]) + " "

		var verdict: String = "COOKED -> " + got if left == 0 else "REFUSED (still raw), pack: " + got
		print("probe8: ", raw, ": ", verdict, "| notice '", last_notice, "'")

	var drops: Dictionary = items.table.number_of("nettles") if false else {}
	print("probe8: nettle item 'nettles' exists: ", n("nettles") != 0, ", 'nettle' exists: ", n("nettle") != 0)
	quit()
