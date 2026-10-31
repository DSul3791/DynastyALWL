extends SceneTree

# Playthrough probe 3: can a real felled log (log_oak, carried on the shoulder, one at a time) be used by the recipes that ask for "log"?
#   godot --headless --path . --script res://art/playthrough/probe_logs.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")


func _init() -> void:
	var dir: String = "user://probe_logs"
	DirAccess.make_dir_recursive_absolute(dir)

	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): print("probe3: notice: ", t)
	items.ground_height = func(_x, _z): return 10.0
	items.tree_info = func(_c, _i): return {}
	items.cut_tree = func(_c, _i): return false
	items.water_near = func(_pos, _reach): return false
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(2, "probe300000001")
	items.report_position(2, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(2)["weight"] = 900.0
	var n: Callable = func(id: String) -> int: return items.table.number_of(id)
	print("probe3: give 3 x log_oak -> ", items.give(2, n.call("log_oak"), 3), " (shoulder: ", items.shoulder_of(2), ")")
	print("probe3: pack has log_oak ", items.inventory_of(2).count_of(n.call("log_oak")), " plain log ", items.inventory_of(2).count_of(n.call("log")))
	items.action(2, Net.ACT_CRAFT_QUEUE, 15, 0, 1, Vector3.ZERO)

	for s in range(12):
		items.tick(1.0)

	print("probe3: chopping block crafted from an oak log on the shoulder: ", items.inventory_of(2).count_of(n.call("chopping_block")))
	items.give(2, n.call("log"), 2)
	items._last_queue_act.clear()
	items.action(2, Net.ACT_CRAFT_QUEUE, 15, 0, 1, Vector3.ZERO)

	for s in range(12):
		items.tick(1.0)

	print("probe3: chopping block crafted from 2 plain logs: ", items.inventory_of(2).count_of(n.call("chopping_block")))
	quit(0)
