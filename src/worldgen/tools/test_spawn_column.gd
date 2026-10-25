extends SceneTree

# Spawn column first: the dive rule. godot --headless --path . --script res://src/worldgen/tools/test_spawn_column.gd   Prints "Test done: N pass, N fail".

const Column := preload("res://src/client/ground_column.gd")

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	check(Column.dive(true, 70.0, 470.0), "400 m up, waiting for ground: dive")
	check(Column.dive(true, 70.0, 1570.0), "1500 m up, waiting for ground: dive")
	check(not Column.dive(true, 70.0, 98.0), "normal join at spawn + 28 m: no dive")
	check(not Column.dive(true, 70.0, 109.0), "39 m up: no dive")
	check(not Column.dive(true, 70.0, 20.0), "player in a cave 50 m under the surface: no dive")
	check(not Column.dive(true, 70.0, 65.0), "player in a tunnel 5 m under the surface: no dive")
	check(not Column.dive(false, 70.0, 470.0), "walking with ground (not waiting, not flying): no dive")
	check(not Column.dive(true, NAN, 470.0), "surface not answered yet: no dive")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
