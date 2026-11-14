extends SceneTree

# Client cost of the world-items list (bug 6): a join list of 282 loose items, then one log cut off a felled trunk
# (the trunk comes back shorter and a log is added). Pins: the cut stays under 50 ms, and a warm join under 250 ms.
# The trunk is long enough for its four cuts to leave a real trunk (logs are 3 m since 14 Nov 2026: a 12 m trunk was cut to 0 m, which the server
# never sends, and the 0 m drawing stalled 43 s on Windows); a 0 m row on its own must still build finite shapes.
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

	var log_m: float = float(JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))["trunk"]["log_length_m"])
	var full_m: float = log_m * 5.0   # four cuts, and a log's length still lying
	var trunk: Dictionary = {"species": "beech", "radius": 0.3, "length": full_m, "orig_length": full_m, "yaw": 0.0}
	view._on_world_items([[5000, 0, 1, Vector3(5.0, 0.0, 5.0), 3, trunk]], PackedInt32Array())
	var worst: float = 0.0

	for cut in range(4):
		var shorter: Dictionary = trunk.duplicate()
		shorter["length"] = full_m - log_m * float(cut + 1)
		t0 = Time.get_ticks_usec()
		view._on_world_items([[5000, 0, 1, Vector3(5.0, 0.0, 5.0), 3, shorter], [6000 + cut, table.number_of("log_beech"), 1, Vector3(6.0, 0.0, 5.0 + float(cut)), 0]], PackedInt32Array())
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		print("cut %d: %.1f ms" % [cut + 1, ms])

	if worst > 50.0:
		print("FAIL a log cut took %.0f ms on the client" % worst)
		failures += 1

	failures += _check_zero_trunk(view)
	view.free()
	root.queue_free()
	print("test_world_items_cost: %d failures" % failures)
	quit(failures)


# A trunk row of 0 m (a bad or old record) is drawn at the shortest length: a real capsule and finite transforms, no degenerate mesh.
func _check_zero_trunk(view) -> int:
	var node: Node3D = view._make_felled(true, {"species": "beech", "radius": 0.3, "length": 0.0, "orig_length": 12.0, "yaw": 0.0, "landed": true, "pitch": 0.0})
	var capsule_ok: bool = false
	var finite: bool = true

	for child in node.find_children("*", "", true, false):
		if child is CollisionShape3D:
			var capsule: CapsuleShape3D = (child as CollisionShape3D).shape as CapsuleShape3D
			capsule_ok = capsule != null and capsule.height > 0.0 and capsule.radius > 0.0

		if child is Node3D:
			finite = finite and (child as Node3D).transform.origin.is_finite() and (child as Node3D).transform.basis.x.is_finite()

	if not capsule_ok or not finite:
		print("FAIL a 0 m trunk row builds a capsule of no size or a non-finite transform (capsule ok %s, finite %s)" % [str(capsule_ok), str(finite)])

	node.free()
	return 0 if capsule_ok and finite else 1
