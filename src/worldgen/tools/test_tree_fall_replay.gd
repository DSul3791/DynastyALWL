extends SceneTree

# BUG-024: a felled tree that leaves the draw range and comes back must not fall again.
#   godot --headless --path . --script res://src/worldgen/tools/test_tree_fall_replay.gd

const TreeSounds := preload("res://src/client/tree_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var trees: Node = TreeSounds.new()
	root.add_child(trees)
	trees._first_msec = Time.get_ticks_msec() - TreeSounds.SETTLE_MSEC - 1000      # the world has settled
	var row: Dictionary = {7: {"state": 3, "pos": Vector3(10, 0, 10), "extra": {"length": 8.0, "radius": 0.3}}}
	trees.watch(row)
	check(trees.falls_played == 1, "a new felled trunk falls once (%d)" % trees.falls_played)
	trees.watch({})
	trees.watch(row)
	check(trees.falls_played == 1, "back in range after leaving: no second fall (%d)" % trees.falls_played)
	trees.forget()
	trees._first_msec = Time.get_ticks_msec() - TreeSounds.SETTLE_MSEC - 1000
	trees.watch(row)
	check(trees.falls_played == 2, "after the ground is made again the id is new (%d)" % trees.falls_played)
	print("tree fall replay: %d failures" % failures)
	quit(1 if failures > 0 else 0)
