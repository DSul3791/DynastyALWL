extends SceneTree

# Dave's four forge meshes as the game draws them (inventory_view._forge_glb): upright, centred, base on the ground, solid, the fire
# opening toward +Z (the front of every building here) and the sizes agreeing with the placement footprints in structures.json.
#   godot --headless --path . --script res://src/worldgen/tools/test_forge_models.gd

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view = load("res://src/client/inventory_view.gd").new()
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var tiers: Dictionary = {"basic": "stone_forge", "medium": "blacksmithy", "large": "large_forge", "master": "master_forge"}

	for tier in tiers:
		var m: Node3D = view._forge_glb("forge_" + tier)
		check(m != null, "%s model loads" % tier)

		if m == null:
			continue

		var meshes: Node3D = m.get_child(0)
		var b: AABB = view._bounds_in(meshes, m)
		var def: Dictionary = structures[tiers[tier]]
		check(absf(b.size.x - float(def["footprint_x"])) <= 0.35 and absf(b.size.z - float(def["footprint_z"])) <= 0.35, "%s footprint %.2f x %.2f matches the mesh %.2f x %.2f" % [tier, def["footprint_x"], def["footprint_z"], b.size.x, b.size.z])
		check(absf(b.position.y) < 0.02 and b.size.y > 2.0 and b.size.y > b.size.x * 0.6, "%s stands upright with its base on the ground (height %.2f)" % [tier, b.size.y])
		check(absf(b.position.x + b.size.x * 0.5) < 0.02 and absf(b.position.z + b.size.z * 0.5) < 0.02, "%s footprint is centred on the pivot" % tier)
		var light: Node3D = m.get_node_or_null("Light")
		var plume: Node3D = null

		for c in m.get_children():
			if c is GPUParticles3D:
				plume = c

		check(light != null and plume != null, "%s has its flame light and smoke" % tier)

		if light != null and plume != null:
			check(light.position.z > plume.position.z, "%s: the fire is in front of the chimney, opening toward +Z (fire z %.2f, smoke z %.2f)" % [tier, light.position.z, plume.position.z])
			check(light.position.y < 1.2 and plume.position.y > 2.0, "%s: fire low, smoke at the top" % tier)

		var solid: CollisionShape3D = null

		for c in m.get_children():
			if c is StaticBody3D:
				solid = c.get_child(0)

		check(solid != null and (solid.shape as BoxShape3D).size.x > 2.0, "%s is solid" % tier)

	print("forge models: %d failures" % failures)
	quit(1 if failures > 0 else 0)
