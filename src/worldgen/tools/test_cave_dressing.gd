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
