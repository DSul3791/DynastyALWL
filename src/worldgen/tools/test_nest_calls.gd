extends SceneTree

# Nest calls (ambient_life.gd set_nests / nearest_nest, Jason 5 Nov 2026): only songbird nests are kept (kind 1; grouse has no clip), and the
# nearest one within hearing range is the one that calls.
#   godot --headless --path . --script res://src/worldgen/tools/test_nest_calls.gd

const AmbientLife := preload("res://src/client/ambient_life.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var life = AmbientLife.new()
	var points: PackedVector3Array = PackedVector3Array([Vector3(10.0, 2.0, 0.0), Vector3(5.0, 1.0, 0.0), Vector3(30.0, 3.0, 0.0), Vector3(100.0, 2.0, 0.0)])
	var kinds: PackedByteArray = PackedByteArray([1, 0, 1, 1])   # songbird, grouse, songbird, songbird (far)
	life.set_nests(points, kinds)
	check(life._nests.size() == 3, "the grouse nest is dropped, the three songbird nests kept (%d)" % life._nests.size())
	var near: Vector3 = AmbientLife.nearest_nest(life._nests, Vector3.ZERO, AmbientLife.NEST_HEAR_M)
	check(near.is_equal_approx(Vector3(10.0, 2.0, 0.0)), "the nearest songbird nest calls, not the nearer grouse nest (%s)" % str(near))
	check(is_nan(AmbientLife.nearest_nest(life._nests, Vector3(200.0, 0.0, 0.0), AmbientLife.NEST_HEAR_M).x), "no nest within hearing range: none calls")
	life.set_nests(PackedVector3Array(), PackedByteArray())
	check(life._nests.is_empty(), "an empty nest set from the server clears the calls")
	life.free()
	print("test_nest_calls: %d failures" % failures)
	quit(1 if failures > 0 else 0)
