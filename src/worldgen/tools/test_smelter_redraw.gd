extends SceneTree

# A Smelter lit or put out is drawn again on the client (Dave 17 Nov 2026: "it needs to show no fire when its not lit"): the same placed row
# sent cold, then lit, then cold again, as the server re-sends it when E lights or puts it out (inventory_view._on_world_items, _smelter_fire).
# Every tier: Primitive, Improved, Advanced.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_smelter_redraw.gd

const ViewScript := preload("res://src/client/inventory_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var root: Node3D = Node3D.new()
	get_root().add_child.call_deferred(root)
	var view: Node = ViewScript.new()
	view.table = ItemTableScript.load_default()
	view._root = root
	view._ground_below = func(_at: Vector3) -> float: return 0.0
	view._player_position = func() -> Vector3: return Vector3.ZERO
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))["structures"]
	var id: int = 7000

	for kind in ["smelter", "improved_smelter", "large_forge"]:
		var state: int = int(structures[kind]["state"])
		var number: int = view.table.number_of(str(structures[kind].get("item", kind)))
		var at: Vector3 = Vector3(float(id - 7000) * 6.0, 0.0, 4.0)

		for lit in [false, true, false]:
			view._on_world_items([[id, number, 1, at, state, {"yaw": 0.0, "age": 0.0, "sp": "", "lit": lit, "fill": 1}]], PackedInt32Array())
			var entry: Dictionary = view._world.get(id, {})
			var node: Node3D = entry.get("node") as Node3D
			var flames: Node3D = node.get_node_or_null("Flames") as Node3D if node != null else null
			check(flames != null and flames.visible == lit and (entry.get("light") != null) == lit and bool(entry.get("lit", false)) == lit, "%s sent %s: fire %s, light %s" % [kind, "lit" if lit else "cold", "shown" if flames != null and flames.visible else "hidden", "on the list" if entry.get("light") != null else "off"])

		id += 1

	print("test_smelter_redraw: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	view.free()
	root.queue_free()
	quit(1 if failures > 0 else 0)
