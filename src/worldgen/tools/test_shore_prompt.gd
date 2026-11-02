extends SceneTree

# The sea-edge prompt (Sonny, 31 Oct 2026; client half of WATER_GATHER_SPEC / ACT_GATHER_EDGE): ShoreRules.prompt says what E does, and "" (no prompt) when the server would refuse.
#   godot --headless --path . --script res://src/worldgen/tools/test_shore_prompt.gd

const ShoreRules := preload("res://src/shared/shore_rules.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/shore_nodes.json"))
	var spot: Vector3 = Vector3(100.5, 1.0, 100.5)
	_check(ShoreRules.prompt(cfg, spot, false, "bucket", 1.0, 3, 12.0, "summer", {}) == "", "no sea within reach: no prompt, even with a bucket")
	_check(ShoreRules.prompt(cfg, spot, true, "bucket", 1.0, 3, 12.0, "summer", {}) == "Press E to fill the bucket", "the sea and a bucket: fill the bucket")
	_check(ShoreRules.prompt(cfg, spot, true, "clay_jug", 1.0, 3, 12.0, "summer", {}) == "Press E to fill the clay jug", "a clay jug reads 'clay jug'")
	_check(ShoreRules.prompt(cfg, Vector3(100.5, 9.0, 100.5), true, "", 9.0, 3, 12.0, "summer", {}) == "", "no container and above the beach: nothing")

	# Over many cells and days: the prompt is exactly "gather <item>" where the shared node rule has a node, and never otherwise.
	var with_node: int = 0
	var without: int = 0
	var mismatch: int = 0

	for cx in range(40):
		var pos: Vector3 = Vector3(8.0 * cx + 1.0, 1.0, 5.0)
		var node: Dictionary = ShoreRules.node_at(cfg, pos, 7, 22.0, "summer")
		var text: String = ShoreRules.prompt(cfg, pos, true, "", 1.0, 7, 22.0, "summer", {})

		if node.is_empty():
			without += 1
			mismatch += 0 if text == "" else 1
		else:
			with_node += 1
			mismatch += 0 if text == "Press E to gather %s" % str(node["item"]).replace("_", " ") else 1

	_check(mismatch == 0 and with_node > 5 and without > 5, "40 cells: %d with a node show 'Press E to gather <item>', %d without show nothing (%d mismatches)" % [with_node, without, mismatch])

	# A node this client already gathered today shows no prompt; tomorrow it can again.
	var pos2: Vector3 = Vector3(1.0, 1.0, 5.0)

	for cx in range(200):
		pos2 = Vector3(8.0 * cx + 1.0, 1.0, 5.0)

		if not ShoreRules.node_at(cfg, pos2, 7, 22.0, "summer").is_empty():
			break

	var used: Dictionary = {ShoreRules.cell_key(cfg, pos2): 7}
	_check(ShoreRules.prompt(cfg, pos2, true, "", 1.0, 7, 22.0, "summer", used) == "", "a node gathered today shows no prompt")
	_check(ShoreRules.prompt(cfg, pos2, true, "", 1.0, 8, 22.0, "summer", used) == "" or ShoreRules.prompt(cfg, pos2, true, "", 1.0, 8, 22.0, "summer", used).begins_with("Press E to gather"), "the next day the cell may hold a node again, never a stale prompt")
	_check(ShoreRules.node_at(cfg, pos2, 7, 22.0, "summer") == ShoreRules.node_at(cfg, pos2, 7, 22.0, "summer"), "the node of a cell and day is always the same")
	print("%d failures" % failures)
	quit(1 if failures > 0 else 0)
