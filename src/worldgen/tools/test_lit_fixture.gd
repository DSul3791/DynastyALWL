extends SceneTree

# Lit fixtures are drawn (Tyler 31 Oct 2026): the server tells the client "lit" in a fixture's world-item row (and sends it again when it changes), and the client's flame model for
# a wall torch, a chandelier and a fireplace has flame meshes and a light named "Light", which stays off until the nearest-lights pass switches it on.
#   godot --headless --path . --script res://src/worldgen/tools/test_lit_fixture.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const BuildingLook := preload("res://src/client/building_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = "user://test_lit_fixture"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	var sent: Array = []
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, a, _r): sent.append_array(a)
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "litfixture0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var id: int = items.dev_place("fireplace@3,0,0")
	items._sync_world_items()
	var row: Array = sent.filter(func(r): return r[0] == id)[-1]
	check(not bool((row[5] as Dictionary).get("lit", false)), "an unlit fireplace is sent without lit")
	sent.clear()
	items._items[id]["struct"]["lit"] = true
	items._items[id]["struct"]["fuel_left"] = 100.0
	items._sync_world_items()
	check(sent.size() == 1 and bool((sent[0][5] as Dictionary).get("lit", false)), "lighting it sends the row again with lit")
	sent.clear()
	items._items[id]["struct"]["lit"] = false
	items._sync_world_items()
	check(sent.size() == 1 and not bool((sent[0][5] as Dictionary).get("lit", false)), "putting it out sends the row again without lit")

	for kind in ["wall_torch", "chandelier", "fireplace"]:
		var model: Node3D = BuildingLook.lit_fixture(kind)
		var light: OmniLight3D = model.get_node_or_null("Light")
		var flames: int = 0

		for child in model.get_children():
			if child is MeshInstance3D:
				flames += 1

		check(light != null and not light.visible and not light.shadow_enabled and flames >= 1, "%s: %d flame meshes and a warm light that starts off, no shadow" % [kind, flames])

	var torch_light: OmniLight3D = BuildingLook.lit_fixture("wall_torch").get_node("Light")
	check(torch_light.position.z > 0.5 and torch_light.position.y > 2.3, "the torch light sits above and in front of the head (no hard shadow cone on the wall)")
	print("lit fixture: %d failures" % failures)
	quit(1 if failures > 0 else 0)
