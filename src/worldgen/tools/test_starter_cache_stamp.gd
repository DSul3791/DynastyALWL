extends SceneTree

# The shipped starter ground must match the committed tiles, or seed_starter skips it and every first-time player streams the
# spawn ground from the server (about 40 s of gliding on Dave's PC; stamp was 25_... against TERRAIN_VERSION 76, 15 Nov 2026).
# Rebuild with tools/rebuild_starter_cache.sh after any TERRAIN_VERSION bump or re-bake of tile 3,4.
#   godot --headless --path . --script res://src/worldgen/tools/test_starter_cache_stamp.gd

const LayoutScript := preload("res://src/worldgen/runtime/terrain_layout.gd")
const STAMP_PATH := "res://worlds/base_world/starter_cache/tiles_stamp.txt"
const STARTER_PATH := "res://worlds/base_world/starter_cache/tile_3_4_r1.sqlite.gz"
const TILES_DIR := "res://worlds/base_world/tiles"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var built_for: String = FileAccess.get_file_as_string(STAMP_PATH).strip_edges()
	var want: String = "%d_%s" % [LayoutScript.TERRAIN_VERSION, LayoutScript.tile_stamp(TILES_DIR, Vector2i(3, 4))]
	check(built_for == want, "starter ground built for %s, the server asks for %s (run tools/rebuild_starter_cache.sh)" % [built_for, want])
	var packed: PackedByteArray = FileAccess.get_file_as_bytes(STARTER_PATH)
	check(not packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).is_empty(), "the starter tile file unpacks")
	print("starter cache stamp: %d failures" % failures)
	quit(1 if failures > 0 else 0)
