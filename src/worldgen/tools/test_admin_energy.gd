extends SceneTree

# ACT_ADMIN_ENERGY (56, Tyler 2 Nov 2026): an admin peer sets its own energy (count, clamped 0..100); a non-admin peer changes nothing;
# no admin check set (unset admin_ok) changes nothing either.
#   godot --headless --path . --script res://src/worldgen/tools/test_admin_energy.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = "user://test_admin_energy"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "adminenergy001")
	items.peer_connected_hello(2, "adminenergy002")
	items.report_position(1, Vector3.ZERO)
	items.report_position(2, Vector3.ZERO)
	check(Net.ACT_ADMIN_ENERGY == 56, "the action number is 56")
	var before1: float = float(items.vitals_of(1)["energy"])
	var before2: float = float(items.vitals_of(2)["energy"])

	# No admin check wired: nobody may set energy.
	items.action(1, Net.ACT_ADMIN_ENERGY, 0, 0, 20, Vector3.ZERO)
	check(float(items.vitals_of(1)["energy"]) == before1, "with no admin check set, energy is unchanged")

	items.admin_ok = func(peer: int) -> bool: return peer == 1
	items.action(1, Net.ACT_ADMIN_ENERGY, 0, 0, 20, Vector3.ZERO)
	check(is_equal_approx(float(items.vitals_of(1)["energy"]), 20.0), "an admin peer sets its energy to 20 (%s)" % str(items.vitals_of(1)["energy"]))
	items.action(2, Net.ACT_ADMIN_ENERGY, 0, 0, 20, Vector3.ZERO)
	check(float(items.vitals_of(2)["energy"]) == before2, "a non-admin peer changes nothing")
	items.action(1, Net.ACT_ADMIN_ENERGY, 0, 0, 500, Vector3.ZERO)
	check(is_equal_approx(float(items.vitals_of(1)["energy"]), 100.0), "above 100 is clamped to 100")
	items.action(1, Net.ACT_ADMIN_ENERGY, 0, 0, -5, Vector3.ZERO)
	check(is_equal_approx(float(items.vitals_of(1)["energy"]), 0.0), "below 0 is clamped to 0")
	items.action(1, Net.ACT_ADMIN_ENERGY, 0, 0, 60, Vector3.ZERO)
	check(float(items.vitals_of(2)["energy"]) == before2, "the admin's call never touches another peer")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
