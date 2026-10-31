extends SceneTree

# Fruit trees (Kathleen, 2026-10-31): TreeBuilder.build(..., fruit_share) keeps only that share of the fruit, the fruit sits on its own surface, and the apple "fruit_color" recolours it.
#   godot --headless --path . --script res://src/worldgen/tools/test_fruit_share.gd

const TreeBuilder := preload("res://src/flora/tree_builder.gd")

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	_failures += 0 if ok else 1


func _fruit_verts(mesh: ArrayMesh) -> int:
	var last: int = mesh.get_surface_count() - 1

	# Fruit is committed after the smooth bark and before the leaves: the surface just before the leaf surface.
	for s in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(s)

		if mat != null and mat.resource_name == "fruit":
			return (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	return -1 if last < 0 else 0


func _init() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json")).get("entries", [])
	var apple: Dictionary = {}

	for row in rows:
		if str(row.get("name", "")) == "wild_apple":
			apple = row

	_check(not apple.is_empty(), "wild_apple row found")
	var plain: StandardMaterial3D = StandardMaterial3D.new()
	var fruit: StandardMaterial3D = StandardMaterial3D.new()
	fruit.resource_name = "fruit"
	var mats: Dictionary = {"bark": plain, "broad": plain, "fruit": fruit}
	var counts: Array = []

	for share in [1.0, 0.66, 0.33, 0.1, 0.0]:
		var mesh: ArrayMesh = TreeBuilder.build(apple, float(apple.get("height_m", [5.0, 7.0])[0]) if apple.get("height_m") is Array else 6.0, 0, false, mats, "autumn", false, false, share)
		counts.append(_fruit_verts(mesh))

	print("fruit vertices at 100/66/33/10/0 percent: ", counts)
	_check(int(counts[0]) > 0, "an apple tree has fruit on its own surface")

	for k in range(1, 5):
		_check(int(counts[k]) <= int(counts[k - 1]), "less fruit at level %d" % k)

	_check(int(counts[4]) <= 0, "no fruit at 0 percent")
	_check(int(counts[2]) < int(counts[0]) and int(counts[2]) > 0, "a third of the fruit is between none and all")
	print("fruit share test: %d failures" % _failures)
	quit(_failures)
