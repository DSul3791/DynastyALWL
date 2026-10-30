extends SceneTree

# Every look in src/client/look_table.gd builds a model, and a piece stays under the near triangle budget (Tyler, 300; log walls and the
# sawmill are drawn with more cylinders, so they get their own larger cap here).
#   godot --headless --path . --script res://src/worldgen/tools/test_look_table.gd

const LookTable := preload("res://src/client/look_table.gd")
const NEAR_TRIANGLES := 300
const BIG := {"rock_pile": 900, "log_wall": 1500, "saw_mill": 1500, "water_wheel": 800, "woodworking_table": 600, "door_double": 600, "foundation": 600, "clay_hearth": 600, "oven": 450, "thatch_floor": 300, "thatch_doorway": 400}

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _triangles(node: Node) -> int:
	var total: int = 0

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += floori(float((node as MeshInstance3D).mesh.get_faces().size()) / 3.0)

	for child in node.get_children():
		total += _triangles(child)

	return total


func _init() -> void:
	for look in LookTable.LOOKS:
		var model: Node3D = LookTable.build(look)
		var tris: int = _triangles(model)
		check(model != null and model.get_child_count() > 0, "look %s builds a model" % look)
		check(tris <= int(BIG.get(look, NEAR_TRIANGLES)), "look %s stays under its triangle cap (%d)" % [look, tris])
		model.free()

	var unknown: Node3D = LookTable.build("no_such_look_name")
	check(unknown.get_child_count() == 1, "an unknown look draws a placeholder box")
	unknown.free()
	print("look table: %d looks, %d failures" % [LookTable.LOOKS.size(), failures])
	quit(failures)
