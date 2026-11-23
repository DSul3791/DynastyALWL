extends SceneTree

# A placed piece a player must walk round is solid on the client (physical world audit round 5, 23 Nov 2026): the Workbench and Grindstone are
# "blocks_walk" on the server but had no solid, and chests, the chopping block, the tool rack, the vice and the bellows were walked through.
# inventory_view _add_missing_solid gives such a model one box of its drawn size inside its footprint; pieces that hang on something keep none.
#   godot --headless --path . --script res://src/worldgen/tools/test_piece_solids.gd

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# The solid boxes of a model in its own space, merged; null when it has none.
func solid_box(node: Node, xf: Transform3D = Transform3D.IDENTITY) -> Variant:
	var here: Transform3D = xf * ((node as Node3D).transform if node is Node3D else Transform3D.IDENTITY)
	var found: Variant = null

	if node is CollisionShape3D and (node as CollisionShape3D).shape is BoxShape3D:
		var size: Vector3 = ((node as CollisionShape3D).shape as BoxShape3D).size
		found = here * AABB(-size * 0.5, size)

	for child in node.get_children():
		var sub: Variant = solid_box(child, here)

		if sub != null:
			found = sub if found == null else (found as AABB).merge(sub)

	return found


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var view = load("res://src/client/inventory_view.gd").new()
	var bare: PackedStringArray = PackedStringArray()

	for kind in cfg["structures"]:
		var def: Dictionary = cfg["structures"][kind]

		if not def.has("state") or not bool(def.get("blocks_walk", false)):
			continue

		var model: Node3D = view._model_for_state(int(def["state"]), {})

		if model != null and not view._has_solid(model):
			bare.append(kind)

		if model != null:
			model.free()

	check(bare.is_empty(), "every piece that blocks the way on the server is solid on the client (%s)" % ", ".join(bare))

	for kind in ["workbench", "grindstone", "chest", "small_chest", "fine_chest", "plank_chest", "chopping_block", "tool_rack", "vice", "bellows"]:
		var def: Dictionary = cfg["structures"][kind]
		var model: Node3D = view._model_for_state(int(def["state"]), {})
		var box: Variant = solid_box(model)
		var fits: bool = box != null

		if fits:
			var b: AABB = box
			fits = b.size.x <= float(def["footprint_x"]) + 0.01 and b.size.z <= float(def["footprint_z"]) + 0.01 and b.size.y > 0.3 and b.position.y >= -0.01   # solid_box carries the model's own scale

		check(fits, "%s: solid, inside its footprint (%s)" % [kind, str(box)])
		model.free()

	var crane: Node3D = view._model_for_state(int(cfg["structures"]["fireplace_cooking_crane"]["state"]), {})
	check(not view._has_solid(crane), "a piece that hangs in a fireplace gets no box (it would fill the hearth)")
	crane.free()
	view.free()
	print("piece solids test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
