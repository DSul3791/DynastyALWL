extends SceneTree

# Client cost of the world-items list (bug 6): a join list of 282 loose items, then a felled tree arriving: its stump and the logs and crown litter it
# comes down as, each with its fall (16 Nov 2026). Pins: the tree's rows stay under 50 ms, and a warm join under 250 ms.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_world_items_cost.gd

const ViewScript := preload("res://src/client/inventory_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")


func _init() -> void:
	var failures: int = 0
	var root: Node3D = Node3D.new()
	get_root().add_child.call_deferred(root)
	var view: Node = ViewScript.new()
	view.table = ItemTableScript.load_default()
	view._root = root
	view._ground_below = func(at: Vector3) -> float: return 0.0
	view._player_position = func() -> Vector3: return Vector3.ZERO
	var t0: int = Time.get_ticks_usec()
	view._prewarm_loose_meshes()
	print("prewarm %.0f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))
	var table = view.table
	var kinds: Array = ["stone", "stick", "driftwood", "firewood", "log_beech", "plant_fibre"]
	var join: Array = []

	for k in range(282):
		var id: String = kinds[k % kinds.size()]
		join.append([1000 + k, table.number_of(id), 1, Vector3(float(k % 20) * 3.0, 0.0, float(k / 20) * 3.0), 0])

	t0 = Time.get_ticks_usec()
	view._on_world_items(join, PackedInt32Array())
	var join_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("join: 282 items %.0f ms" % join_ms)

	if join_ms > 250.0:
		print("FAIL join with warm meshes took %.0f ms" % join_ms)
		failures += 1

	# A felled 18 m beech: the stump (fresh while it falls), six logs end to end along +z, and four litter heaps, all swinging down from the stump.
	var fall: Array = [5.0, 0.3, 5.0, 0.0, 1.5]
	var rows: Array = [[5000, 0, 1, Vector3(5.0, 0.0, 5.0), 4, {"species": "beech", "radius": 0.3, "length": 18.0, "yaw": 0.0, "fresh": true, "crown": [5.0, 18.5, 4.0]}]]

	for k in range(6):
		rows.append([5001 + k, table.number_of("log_beech"), 1, Vector3(5.0, 0.3, 6.5 + 3.0 * float(k)), 0, {"rot_y": -PI * 0.5, "girth": 1.2, "fall": fall}])

	for k in range(4):
		rows.append([5010 + k, table.number_of("stick" if k % 2 == 0 else "leaves"), 12, Vector3(4.0 + float(k), 0.0, 17.0), 0, {"fall": fall}])

	t0 = Time.get_ticks_usec()
	view._on_world_items(rows, PackedInt32Array())
	var fell_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("a felled tree's rows: %.1f ms" % fell_ms)

	if fell_ms > 50.0:
		print("FAIL a felled tree's rows took %.0f ms on the client" % fell_ms)
		failures += 1

	view.free()
	root.queue_free()
	print("test_world_items_cost: %d failures" % failures)
	quit(failures)
