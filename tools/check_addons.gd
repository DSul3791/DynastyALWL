extends SceneTree
# Headless proof that the native addons load: run with --script (never a bare launch).
func _init():
	var ok = ClassDB.class_exists("VoxelTerrain") and (ClassDB.class_exists("WaterCore") or ClassDB.class_exists("WaterSimCore"))
	print("ADDON_OK" if ok else "ADDON_FAIL")
	quit(0 if ok else 1)
