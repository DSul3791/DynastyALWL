extends SceneTree
# Container self test: do the voxel classes and the water core load, and does a tiny voxel job work? Prints SELFTEST_PASS or SELFTEST_FAIL.
func _init():
	var bad: Array = []
	for c in ["VoxelTerrain", "VoxelBuffer", "VoxelGenerator", "VoxelStream", "VoxelTool"]:
		if not ClassDB.class_exists(c):
			bad.append("class missing: " + c)
	if not (ClassDB.class_exists("WaterCore") or ClassDB.class_exists("WaterSimCore")):
		bad.append("water core did not load (run the import step first)")
	if bad.is_empty():
		var buf = ClassDB.instantiate("VoxelBuffer")
		buf.create(8, 8, 8)
		buf.set_voxel(5, 1, 2, 3, 0)
		if buf.get_voxel(1, 2, 3, 0) != 5:
			bad.append("VoxelBuffer write/read gave the wrong value")
		var t = ClassDB.instantiate("VoxelTerrain")
		if t == null:
			bad.append("VoxelTerrain cannot be created")
		else:
			t.free()
	print("Godot ", Engine.get_version_info().string)
	if bad.is_empty():
		print("SELFTEST_PASS voxel classes, water core and a tiny voxel job work")
	else:
		print("SELFTEST_FAIL ", "; ".join(bad))
	quit(0 if bad.is_empty() else 1)
