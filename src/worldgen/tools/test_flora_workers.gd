extends SceneTree

# Flora worker threads make plain data only (14 Nov 2026: an ArrayMesh made on the "flora models" worker crashed the play client at join,
# signal 11 after "The caller thread can't call the function propagate_notification()", David4 smoke of #1113).
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_workers.gd
# 1. Every function flora_view.gd hands to WorkerThreadPool.add_task, and every function of the file those call, has no mesh, node or
#    material making, scene tree use or mesh read-back in it.
# 2. In tree_builder.gd only to_mesh makes a mesh; build_surfaces returns plain [arrays, material] pairs, also when run on a worker, and
#    to_mesh of them is the same model build gives.

const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const VIEW := "res://src/flora/flora_view.gd"
const BUILDER := "res://src/flora/tree_builder.gd"
# Anything that makes or reads a mesh, node or material, or touches the scene tree. A worker may hold a Material handed to it; it must not make one.
const FORBIDDEN := ["ArrayMesh", "MeshInstance", "MultiMesh", "add_child", "get_tree", "get_node", "add_surface_from_arrays", "surface_set_material",
	"surface_get_arrays", "surface_get_material", "GLTFDocument", "generate_scene", "Material.new", "Material3D.new", "TreeBuilder.build(", "to_mesh",
	"call_group", "propagate_notification", "queue_free", ".free()"]

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	_failures += 0 if ok else 1


# name -> body text (comments stripped) of each top-level and inner func of a script's source.
func _bodies(path: String) -> Dictionary:
	var out: Dictionary = {}
	var current: String = ""

	for line in FileAccess.get_file_as_string(path).split("\n"):
		var code: String = line.split("#")[0] if not line.strip_edges().begins_with("#") else ""
		var stripped: String = code.strip_edges()

		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			current = stripped.trim_prefix("static ").trim_prefix("func ").split("(")[0]
			out[current] = ""
		elif not line.is_empty() and not line.begins_with("\t") and not line.begins_with(" ") and not stripped.is_empty():
			current = ""      # a top-level var, const or class line ends the function

		if current != "":
			out[current] += code + "\n"

	return out


func _init() -> void:
	var view: Dictionary = _bodies(VIEW)
	var source: String = FileAccess.get_file_as_string(VIEW)
	var roots: Array = []
	var find: RegEx = RegEx.create_from_string("WorkerThreadPool\\.add_task\\((\\w+)")

	for found in find.search_all(source):
		if found.get_string(1) != "func" and not roots.has(found.get_string(1)):
			roots.append(found.get_string(1))

	for expected in ["_models_task", "_seasonal_models_task", "_decimate_task", "_plan_task"]:
		_check(roots.has(expected), "%s runs on a worker (found by its add_task)" % expected)

	# Follow the calls inside flora_view.gd from each worker function.
	var reached: Dictionary = {}
	var queue: Array = roots.duplicate()
	var calls_re: RegEx = RegEx.create_from_string("\\b(\\w+)\\(")

	while not queue.is_empty():
		var name: String = queue.pop_back()

		if reached.has(name) or not view.has(name):
			continue

		reached[name] = true

		for found in calls_re.search_all(str(view[name])):
			if view.has(found.get_string(1)):
				queue.append(found.get_string(1))

	_check(reached.has("_plan") and reached.size() >= 5, "the worker call graph reaches _plan and the tint helpers (%d functions)" % reached.size())

	for name in reached:
		var bad: Array = FORBIDDEN.filter(func(word: String) -> bool: return str(view[name]).contains(word))
		_check(bad.is_empty(), "worker function %s makes or touches no mesh, node or material %s" % [name, str(bad)])

	var builder: Dictionary = _bodies(BUILDER)
	var making: Array = builder.keys().filter(func(fn: String) -> bool: return str(builder[fn]).contains("ArrayMesh.new") or str(builder[fn]).contains("add_surface_from_arrays") or str(builder[fn]).contains("surface_set_material"))
	_check(making == ["to_mesh"], "in tree_builder.gd only to_mesh makes a mesh (%s)" % str(making))

	# build_surfaces on a worker gives plain pairs, and to_mesh of them is build's model.
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json")).get("entries", [])
	var picked: Array = rows.filter(func(row: Dictionary) -> bool: return str(row.get("name", "")) in ["oak", "blueberry", "wild_apple"])
	_check(picked.size() == 3, "oak, blueberry and wild_apple rows found")
	var bark: StandardMaterial3D = StandardMaterial3D.new()
	var leaf: StandardMaterial3D = StandardMaterial3D.new()
	var materials: Dictionary = {"bark": bark, "broad": leaf, "conifer": leaf, "palm": leaf}
	var results: Array = []
	results.resize(picked.size())
	var task: int = WorkerThreadPool.add_task(func() -> void:
		for n in range(picked.size()):
			results[n] = TreeBuilder.build_surfaces(picked[n], 6.0 if str(picked[n]["kind"]) == "tree" else 0.5, 0, false, materials), false, "test flora surfaces")
	WorkerThreadPool.wait_for_task_completion(task)

	for n in range(picked.size()):
		var surfaces: Array = results[n]
		var plain: bool = not surfaces.is_empty()

		for surface in surfaces:
			plain = plain and surface is Array and surface.size() == 2 and surface[0] is Array and surface[1] is Material

		var mesh: ArrayMesh = TreeBuilder.to_mesh(surfaces)
		var same: ArrayMesh = TreeBuilder.build(picked[n], 6.0 if str(picked[n]["kind"]) == "tree" else 0.5, 0, false, materials)
		var verts: Array = []

		for m in [mesh, same]:
			var total: int = 0

			for s in range(m.get_surface_count()):
				total += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

			verts.append(total)

		_check(plain, "%s: build_surfaces on a worker gives plain [arrays, material] pairs (%d)" % [picked[n]["name"], surfaces.size()])
		_check(mesh.get_surface_count() == same.get_surface_count() and verts[0] == verts[1] and verts[0] > 0, "%s: to_mesh of them is build's model (%s vertices)" % [picked[n]["name"], str(verts)])

	print("test_flora_workers: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)
