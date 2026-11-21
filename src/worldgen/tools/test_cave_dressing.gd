extends SceneTree

# Cave dressing (Dave 4 Nov 2026: bone piles, stalagmites and stalactites): the client draws a tile's lists (src/client/cave_dressing.gd) the way the
# bake writes them: bones x, y, z, kind, yaw; formations x, y, z, kind, height m, radius m (a stalactite hangs down from its root on the roof).
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_dressing.gd

const Dressing := preload("res://src/client/cave_dressing.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var d = Dressing.new()
	get_root().add_child(d)
	var bones: PackedFloat32Array = PackedFloat32Array([10.0, 5.0, 20.0, 0.0, 0.3, 12.0, 5.0, 21.0, 1.0, 1.0, 13.0, 5.0, 22.0, 1.0, 2.0])
	var formations: PackedFloat32Array = PackedFloat32Array([15.0, 5.0, 25.0, 0.0, 2.0, 0.4, 16.0, 5.0, 25.0, 0.0, 0.8, 0.1, 15.5, 9.0, 24.0, 1.0, 1.5, 0.3])
	d.set_tile(Vector2i(3, 4), bones, formations)
	var tile: Node3D = d.tile_node(Vector2i(3, 4))
	check(tile != null, "the tile's dressing is drawn")
	var counts: Dictionary = {}
	var solids: Array = []

	for child in tile.get_children():
		if child is MultiMeshInstance3D:
			counts[child.name] = (child as MultiMeshInstance3D).multimesh.instance_count
		elif child is StaticBody3D:
			solids.append(child)

	check(counts.get("bones_animal", 0) == 1 and counts.get("bones_human", 0) == 2, "one animal pile and two human piles (%s)" % str(counts))
	check(counts.get("stalagmite", 0) == 2 and counts.get("stalactite", 0) == 1, "two stalagmites and one stalactite")
	check(solids.size() == 1 and (solids[0] as StaticBody3D).position.distance_to(Vector3(15.0, 6.0, 25.0)) < 0.01, "only the wide stalagmite is solid, centred on its column")

	# The unit looks: a pile lies low and about a metre across; a stalagmite rises from its foot, a stalactite hangs from its root.
	for look in ["bones_animal", "bones_human"]:
		var box: AABB = Dressing.look_mesh(look).get_aabb()
		check(box.size.y < 0.45 and box.size.x < 1.3 and box.size.z < 1.3 and box.position.y > -0.05, "%s lies on the floor, low and about 1 m across (%s)" % [look, str(box)])

	# Den signs (protocol 141): droppings and a bed, each its own look, low on the floor.
	d.set_tile(Vector2i(2, 4), PackedFloat32Array([1.0, 5.0, 1.0, 4.0, 0.0, 2.0, 5.0, 2.0, 5.0, 1.0]), PackedFloat32Array())
	var den_rows: Dictionary = d.tile_node(Vector2i(2, 4)).get_meta("rows")
	check((den_rows["den_droppings"] as Array).size() == 1 and (den_rows["den_bedding"] as Array).size() == 1, "kinds 4 and 5 are droppings and a bed")

	for look in ["den_droppings", "den_bedding"]:
		var box: AABB = Dressing.look_mesh(look).get_aabb()
		check(box.size.y < 0.2 and box.size.x < 1.8 and box.position.y > -0.08, "%s lies flat on the floor (%s)" % [look, str(box)])

	# Abandoned mines (protocol 142): kinds 6 to 8 are a timber set, a stope prop and a fallen set. A set fits inside the adit's 1.8 m by 2.4 m
	# ellipse (mine_sites.gd ADIT_W, ADIT_H): its top corners stay in it, and it stands about 2.1 m tall.
	d.set_tile(Vector2i(1, 4), PackedFloat32Array([1.0, 5.0, 1.0, 6.0, 0.0, 2.0, 5.0, 2.0, 7.0, 1.0, 3.0, 5.0, 3.0, 8.0, 2.0]), PackedFloat32Array())
	var mine_rows: Dictionary = d.tile_node(Vector2i(1, 4)).get_meta("rows")
	check(["mine_set", "mine_post", "mine_fallen"].all(func(look): return (mine_rows[look] as Array).size() == 1), "kinds 6, 7 and 8 are a timber set, a prop and a fallen set")
	var mine_set: AABB = Dressing.look_mesh("mine_set").get_aabb()
	var outside: int = 0
	var set_mesh: ArrayMesh = Dressing.look_mesh("mine_set")

	for surface in set_mesh.get_surface_count():
		for v in set_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if v.y > 1.2 and Vector2(v.x / 0.9, (v.y - 1.2) / 1.2).length_squared() > 1.0:
				outside += 1

	check(outside == 0 and absf(mine_set.end.y - 2.1) < 0.1 and mine_set.size.z < 0.8, "a timber set fits inside the adit's roof (%d corners out, %s)" % [outside, str(mine_set)])
	var prop: AABB = Dressing.look_mesh("mine_post").get_aabb()
	check(prop.size.y > 2.8 and prop.size.y < 3.2 and prop.position.y > -0.05, "a stope prop stands about 3 m (%s)" % str(prop))
	var fallen: AABB = Dressing.look_mesh("mine_fallen").get_aabb()
	check(fallen.end.y < 1.95 and fallen.position.y > -0.1, "a fallen set has no cap up at the roof (%s)" % str(fallen))

	var up: AABB = Dressing.look_mesh("stalagmite").get_aabb()
	var down: AABB = Dressing.look_mesh("stalactite").get_aabb()
	check(up.position.y > -0.1 and absf(up.end.y - 1.0) < 0.12, "a stalagmite stands from y 0 to about 1 (%s)" % str(up))
	check(down.end.y < 0.1 and absf(down.position.y + 1.0) < 0.12, "a stalactite hangs from y 0 to about -1 (%s)" % str(down))
	var placed: Transform3D = tile.get_meta("rows")["stalactite"][0]
	check(placed.origin.distance_to(Vector3(15.5, 9.0, 24.0)) < 0.01 and absf(placed.basis.y.length() - 1.5) < 0.01, "the stalactite sits at its root, 1.5 m long (%s)" % str(placed))

	d.set_tile(Vector2i(3, 4), PackedFloat32Array(), PackedFloat32Array())
	check(d.tile_node(Vector2i(3, 4)) == null, "empty lists take the tile's dressing away")
	d.set_tile(Vector2i(3, 4), bones, PackedFloat32Array())
	d.clear()
	check(d.tile_node(Vector2i(3, 4)) == null, "clear takes everything away")
	print("cave dressing: %d failures" % failures)
	quit(1 if failures > 0 else 0)
