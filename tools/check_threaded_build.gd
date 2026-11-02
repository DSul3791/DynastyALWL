extends SceneTree

# Headless check (Sonny, plan 17): the worker-thread build gives exactly the same mesh data as the synchronous build, several jobs can run together, and a baked mesh
# saved to disk loads back with the same data. Prints the timings.
#   godot --headless --path . --script res://tools/check_threaded_build.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_same_result()
	_check_eight_in_parallel()
	_check_disk_round_trip()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _check_same_result() -> void:
	var g: Dictionary = Generator.genome_from_seed(3)
	var direct: Dictionary = Generator.build(g, 0.06, false)
	var job: Dictionary = Generator.start_build(g, 0.06, false)
	var threaded: Dictionary = Generator.finish_build(job)
	_ok(Generator.build_done(job), "a finished job reports done")
	_ok(not threaded.is_empty(), "the threaded build returns a result")
	var a: Array = direct["arrays"]
	var b: Array = threaded["arrays"]

	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_COLOR]:
		_ok(a[slot] == b[slot], "the threaded build equals the direct build in array slot %d" % slot)

	_ok(int(direct["triangle_count"]) == int(threaded["triangle_count"]), "same triangle count (%d)" % int(direct["triangle_count"]))


func _check_eight_in_parallel() -> void:
	var t0: int = Time.get_ticks_usec()
	var jobs: Array = []

	for i in range(8):
		jobs.append(Generator.start_build(Generator.genome_from_seed(i), 0.045, false))

	var launched_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var results: Array = []

	for job in jobs:
		results.append(Generator.finish_build(job))

	var all_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var t1: int = Time.get_ticks_usec()

	for i in range(8):
		Generator.build(Generator.genome_from_seed(i), 0.045, false)

	var serial_ms: float = float(Time.get_ticks_usec() - t1) / 1000.0
	print("8 NPC body types at 4.5 cm without fingers: starting the 8 jobs took %.1f ms on the main thread; all 8 done after %.0f ms; one after another on the main thread %.0f ms" % [launched_ms, all_ms, serial_ms])
	_ok(launched_ms < 50.0, "starting 8 jobs costs the main thread under 50 ms (%.1f ms)" % launched_ms)

	for i in range(8):
		_ok(not (results[i] as Dictionary).is_empty() and int((results[i] as Dictionary)["triangle_count"]) > 1000, "job %d returned a body" % i)

	_ok(all_ms < serial_ms, "running the 8 builds on worker threads is faster than one after another (%.0f vs %.0f ms)" % [all_ms, serial_ms])


func _check_disk_round_trip() -> void:
	var g: Dictionary = Generator.genome_from_seed(4)
	var made: Dictionary = Generator.make_node(g, 0.06, false, false)
	var mesh: ArrayMesh = (made["skeleton"].get_node("Body") as MeshInstance3D).mesh
	var path: String = "user://check_body_%d.res" % g.hash()
	var save_t: int = Time.get_ticks_usec()
	var err: int = ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	var save_ms: float = float(Time.get_ticks_usec() - save_t) / 1000.0
	var load_t: int = Time.get_ticks_usec()
	var loaded: Mesh = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Mesh
	var load_ms: float = float(Time.get_ticks_usec() - load_t) / 1000.0
	_ok(err == OK and loaded != null, "a baked body mesh saves and loads")
	var a: Array = mesh.surface_get_arrays(0)
	var b: Array = loaded.surface_get_arrays(0)
	_ok((a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "the loaded mesh has the same vertex count")
	_ok((a[Mesh.ARRAY_INDEX] as PackedInt32Array) == (b[Mesh.ARRAY_INDEX] as PackedInt32Array), "and the same triangles")
	var bones_a: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var bones_b: PackedInt32Array = b[Mesh.ARRAY_BONES]
	_ok(bones_a == bones_b, "and the same bone indices")
	var weights_a: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var weights_b: PackedFloat32Array = b[Mesh.ARRAY_WEIGHTS]
	var worst: float = 0.0

	for i in range(weights_a.size()):
		worst = maxf(worst, absf(weights_a[i] - weights_b[i]))

	_ok(worst < 0.01, "and the same skin weights (largest difference %.4f)" % worst)
	print("saved in %.1f ms, loaded in %.1f ms, file %d bytes" % [save_ms, load_ms, FileAccess.get_file_as_bytes(path).size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	made["node"].free()
