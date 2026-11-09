extends SceneTree

# The settled water's save format (src/water/water_store.gd) on its own (Sonny, 9 Nov 2026; under a second). Moved here from test_water_hub_small when the old
# water hub was deleted: the settle writes every tile's water/tile_X_Z.water with it and the server reads them back, so the format must keep centimetres
# (a depth written as decimetres was the mutation it caught), drop films under 4 mm, and refuse a file saved at another tile size.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_store.gd

const WS := preload("res://src/water/water_store.gd")

const SIDE := 33

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = ProjectSettings.globalize_path("user://test_water_store")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir + "/format.water"

	# A pond of known depths comes back within half a centimetre; a film under 4 mm is dropped; a dry cell stays dry.
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(SIDE * SIDE)
	depth[100] = 1.234
	depth[101] = 0.002
	depth[102] = 0.0449
	_check(WS.save(path, SIDE, depth) == 2, "the file is written with the two depths over 4 mm")
	var back: PackedFloat32Array = WS.load_depth(path, SIDE)
	_check(back.size() == SIDE * SIDE, "it loads at full size (%d cells)" % back.size())

	if back.size() == SIDE * SIDE:
		_check(absf(back[100] - 1.23) < 0.006 and back[101] == 0.0 and absf(back[102] - 0.04) < 0.006,
			"the save format keeps centimetres and drops films (%.3f, %.3f, %.3f)" % [back[100], back[101], back[102]])
		_check(back[0] == 0.0 and back[SIDE * SIDE - 1] == 0.0, "dry cells stay dry")

	_check(WS.load_depth(path, SIDE + 1).is_empty(), "a file saved at another size is refused")
	DirAccess.remove_absolute(path)
	print("water store: %d failures" % failures)
	quit(1 if failures > 0 else 0)
