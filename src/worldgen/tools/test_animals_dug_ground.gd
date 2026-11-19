extends SceneTree

# Animals stand on the ground as it is now (Dave 19 Nov 2026 play test: "they are floating in the air if I dig the dirt out under them").
# edited_ground.gd works out a column's top from the edit log; server_animals.ground_changed puts the animals near a dig or fill back on it.
#   godot --headless --path . --script res://src/worldgen/tools/test_animals_dug_ground.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const EditedGroundScript := preload("res://src/stream/edited_ground.gd")
const GroundOps := preload("res://src/stream/ground_ops.gd")
const Steering := preload("res://src/shared/steering.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.02


func _init() -> void:
	# The column sums.
	check(near(EditedGroundScript.column_top(10.0, [], 0.0, 0.0), 10.0), "no edit: the generated surface")
	check(near(EditedGroundScript.column_top(10.0, [[0, Vector3(0, 10, 0), 2.0]], 0.0, 0.0), 8.0), "a 2 m dig at the surface: 2 m lower in its middle")
	check(near(EditedGroundScript.column_top(10.0, [[0, Vector3(0, 10, 0), 2.0]], 3.0, 0.0), 10.0), "beside the dig: untouched")
	check(near(EditedGroundScript.column_top(10.0, [[0, Vector3(0, 6, 0), 2.0]], 0.0, 0.0), 10.0), "a tunnel under the surface: the surface stays the ground")
	check(near(EditedGroundScript.column_top(10.0, [[1, Vector3(0, 10, 0), 1.0]], 0.0, 0.0), 11.0), "a fill on the surface: 1 m higher")
	check(near(EditedGroundScript.column_top(10.0, [[0, Vector3(0, 10, 0), 2.0], [1, Vector3(0, 8, 0), 1.0]], 0.0, 0.0), 9.0), "a dig, then a fill in its bottom: oldest first")
	check(near(EditedGroundScript.column_top(10.0, [[1, Vector3(0, 10, 0), 1.0], [0, Vector3(0, 11, 0), 3.0]], 0.0, 0.0), 8.0), "a fill, then a bigger dig over it")

	# The edit log and the cache.
	var ops = GroundOps.new()
	var ground = EditedGroundScript.new()
	ground.ops = ops
	ground.surface = func(_x, _z): return 10.0
	check(near(ground.height(100.0, 100.0), 10.0), "an empty log: the surface")
	ops.add(GroundOps.KIND_DIG, 0, Vector3(100.0, 10.0, 100.0), 1.5)
	check(near(ground.height(100.0, 100.0), 10.0), "before it is told, the cell keeps its old answer (the server tells it on every dig)")
	ground.changed(Vector3(100.0, 10.0, 100.0), 1.5)
	check(near(ground.height(100.0, 100.0), 8.5), "told of the dig: 1.5 m lower in the hole")
	check(near(ground.height(104.0, 100.0), 10.0), "4 m off: untouched")
	ops.add(GroundOps.KIND_DIG, 0, Vector3(100.0, 8.5, 100.0), 1.5)
	ground.changed(Vector3(100.0, 8.5, 100.0), 1.5)
	check(near(ground.height(100.0, 100.0), 7.0), "dug again: 3 m down")
	ops.add(GroundOps.KIND_DIG, 0, Vector3(102.5, 10.0, 100.0), 1.0)   # 2.5 m east: a second hole across a cell line (cells are 4 m: 100 and 102.5 share 100..104; 103.9 too)
	ground.changed(Vector3(102.5, 10.0, 100.0), 1.0)
	check(near(ground.height(102.5, 100.0), 9.0), "a hole in the same cell")
	ops.add(GroundOps.KIND_DIG, 0, Vector3(95.5, 10.0, 100.0), 1.0)    # across the cell line at 96
	ground.changed(Vector3(95.5, 10.0, 100.0), 1.0)
	check(near(ground.height(95.5, 100.0), 9.0) and near(ground.height(96.2, 100.0), 10.0 - sqrt(1.0 - 0.49)), "a hole across a cell line, read on both sides")
	ground.forget()
	check(near(ground.height(100.0, 100.0), 7.0), "after forget: read again from the log")

	# Animals near a dig drop onto the new ground; the far one keeps its height.
	var a = AnimalsScript.new()
	a.ground_height = ground.height
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.setup()
	a.traits = false
	var over: int = a.spawn("deer", 100.0, 100.0)
	var far: int = a.spawn("deer", 120.0, 100.0)
	check(near(a.animals[over]["pos"].y, 7.0), "an animal made over the hole stands in it")
	a.animals[over]["pos"] = Vector3(100.0, 10.0, 100.0)   # stood here before the digs
	ops.add(GroundOps.KIND_DIG, 0, Vector3(100.0, 7.0, 100.0), 1.0)
	ground.changed(Vector3(100.0, 7.0, 100.0), 1.0)
	a.ground_changed(Vector3(100.0, 7.0, 100.0), 1.0)
	check(near(a.animals[over]["pos"].y, 6.0), "dug out from under: it drops to the bottom of the hole (y %.2f)" % a.animals[over]["pos"].y)
	check(near(a.animals[far]["pos"].y, 10.0), "the animal 20 m off is not touched")
	ops.add(GroundOps.KIND_FILL, 1, Vector3(120.0, 10.0, 100.0), 1.0)
	ground.changed(Vector3(120.0, 10.0, 100.0), 1.0)
	a.ground_changed(Vector3(120.0, 10.0, 100.0), 1.0)
	check(near(a.animals[far]["pos"].y, 11.0), "a fill under it: it stands on the fill")

	# A hole's steep rim: the slope rule alone made it a wall, so an animal never went in and one dropped in never came out. A walker now jumps
	# down at most ground_step.drop_m and scrambles up at most climb_m in one step (a 1 m ledge here: x < 0 is the bottom).
	var ledge: Callable = func(x, _z): return 9.0 if x < 0.0 else 10.0
	var bare_down: Dictionary = Steering.step(Vector3(0.05, 10.0, 0.0), Vector3(-5.0, 10.0, 0.0), 1.5, 0.1, ledge, a.blocked)
	var down: Dictionary = a.walk_step(Vector3(0.05, 10.0, 0.0), Vector3(-5.0, 10.0, 0.0), 1.5, 0.1, ledge, a.blocked)
	check(near(bare_down["pos"].y, 10.0) and down["moved"] and near(down["pos"].y, 9.0), "over the 1 m rim: the slope rule refuses it, an animal jumps down (y %.2f)" % down["pos"].y)
	var up: Dictionary = a.walk_step(Vector3(-0.05, 9.0, 0.0), Vector3(5.0, 9.0, 0.0), 1.5, 0.1, ledge, a.blocked)
	check(up["moved"] and near(up["pos"].y, 10.0), "and scrambles out again (y %.2f)" % up["pos"].y)
	var cliff: Callable = func(x, _z): return 7.0 if x < 0.0 else 10.0
	var no_up: Dictionary = a.walk_step(Vector3(-0.05, 7.0, 0.0), Vector3(5.0, 7.0, 0.0), 1.5, 0.1, cliff, a.blocked)
	check(not no_up["moved"] or no_up["pos"].x < 0.0, "a 3 m wall is too high to climb in one step")

	print("test_animals_dug_ground: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
