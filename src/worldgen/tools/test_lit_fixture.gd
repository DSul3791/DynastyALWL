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
		var light: Light3D = model.get_node_or_null("Light")
		var flames: int = 0

		for child in model.get_children():
			if child is MeshInstance3D:
				flames += 1

		check(light != null and not light.visible and (kind == "fireplace" or not light.shadow_enabled) and flames >= 1, "%s: %d flame meshes and a warm light that starts off, no shadow" % [kind, flames])

	var torch_light: OmniLight3D = BuildingLook.lit_fixture("wall_torch").get_node("Light")
	check(torch_light.position.z > 0.35 and torch_light.position.y > 2.3, "the torch light is at the flame, a little out from the wall")

	# Short range with a real falloff and a base energy for the gentle flicker (Dave 31 Oct: the fireplace light was one huge even wash).
	var limits: Dictionary = {"wall_torch": 7.0, "chandelier": 6.0}

	for kind in limits:
		var l: OmniLight3D = BuildingLook.lit_fixture(kind).get_node("Light")
		check(l.omni_range <= float(limits[kind]) and l.omni_attenuation >= 2.0 and l.has_meta("base_energy"), "%s light: range %.1f m (max %.0f), falloff %.1f" % [kind, l.omni_range, float(limits[kind]), l.omni_attenuation])

	# The fireplace shines only out of its opening (Dave 31 Oct: light cannot go through the bricks): a shadow-casting spot cone facing +z, wide and soft, with a small dim glow inside.
	var place: Node3D = BuildingLook.lit_fixture("fireplace")
	var cone: SpotLight3D = place.get_node("Light")
	var facing: Vector3 = cone.transform.basis * Vector3(0.0, 0.0, -1.0)
	check(facing.z > 0.99 and cone.shadow_enabled and cone.spot_angle >= 50.0 and cone.spot_angle <= 60.0 and cone.spot_range <= 7.0 and cone.spot_attenuation >= 2.0, "the fireplace light is a shadowed spot facing the front (z %.2f), %.0f degrees half angle, range %.1f m" % [facing.z, cone.spot_angle, cone.spot_range])
	check(cone.position.z > 0.0 and cone.position.z < 0.6 and cone.has_meta("base_energy"), "placed at the hearth just inside the opening")
	var glow: OmniLight3D = cone.get_node("Glow")
	check(glow.omni_range <= 1.5 and glow.light_energy < 0.5 and not glow.shadow_enabled, "and only a small dim glow inside (range %.1f m)" % glow.omni_range)

	for tier in [1, 2, 3]:
		var camp: OmniLight3D = BuildingLook.fire(true, false, tier).get_node("Light")
		check(camp.omni_range <= 8.0 and camp.omni_attenuation >= 2.0 and camp.has_meta("base_energy"), "campfire tier %d light: range %.1f m, falloff %.1f" % [tier, camp.omni_range, camp.omni_attenuation])

	print("lit fixture: %d failures" % failures)
	quit(1 if failures > 0 else 0)
