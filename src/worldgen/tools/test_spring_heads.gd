extends SceneTree

# Spring heads, the damp patch (spring_heads.gd; docs/design/spring_head_damp_patch.md): which way the runnel runs and how far from the
# record's brook cells, the heads a chunk brings and drops, the textures made in code, and the trickle's nearest head (cave_water_sounds.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_spring_heads.gd

const SpringHeads := preload("res://src/client/spring_heads.gd")
const CaveWater := preload("res://src/client/cave_water_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_runnel()
	_chunks()
	_images()
	_trickle()
	print("spring heads: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _runnel() -> void:
	# A head at (100, 200) and a brook running from it toward +x on the 8 m grid: cells at x 104 (4 m out, just past the clump), 112 and 120 (past the 16 m it looks).
	var head: Vector2 = Vector2(100.0, 200.0)
	var cells: Dictionary = {Vector2i(13, 25): 2, Vector2i(14, 25): 2, Vector2i(15, 25): 2}
	var way: Array = SpringHeads.runnel_from_cells(head, cells, 8.0)
	var dir: Vector2 = way[0]
	check(dir.x > 0.99 and absf(dir.y) < 0.01, "the runnel runs the way the brook cells lie (+x: %s)" % str(dir))
	check(absf(float(way[1]) - SpringHeads.RUNNEL_MIN_M) < 0.001, "the nearest cell past the clump is 4 m out, so the runnel shows its least, %.1f m (%.2f)" % [SpringHeads.RUNNEL_MIN_M, float(way[1])])
	# Only a far cell, 16 m out along -z: the runnel runs that way, as far as it may.
	way = SpringHeads.runnel_from_cells(Vector2(0.0, 0.0), {Vector2i(0, -2): 1}, 8.0)
	check((way[0] as Vector2).is_equal_approx(Vector2(0.0, -1.0)) and absf(float(way[1]) - SpringHeads.RUNNEL_MAX_M) < 0.001,
		"a lone cell 16 m along -z: the runnel runs -z, cut to its longest, %.0f m (%.2f)" % [SpringHeads.RUNNEL_MAX_M, float(way[1])])
	way = SpringHeads.runnel_from_cells(Vector2(0.0, 0.0), {Vector2i(5, 5): 1}, 8.0)
	check((way[0] as Vector2) == Vector2.ZERO and float(way[1]) == 0.0, "no brook cell within %.0f m: no way from the cells (falls back to downhill)" % SpringHeads.BROOK_LOOK_M)
	check(SpringHeads.key_of(12.34, -5.66) == Vector2i(123, -57), "a head's key is its place in decimetres")


func _chunks() -> void:
	var heads = SpringHeads.new()
	heads.set_chunk(Vector2i(1, 2), 8.0, PackedInt32Array([13, 25, 2, 14, 25, 3]), PackedFloat32Array([100.0, 200.0, 140.0, 210.0]))
	check(heads.heads_known() == 2, "a chunk with two spring heads: two heads known (%d)" % heads.heads_known())
	heads.set_chunk(Vector2i(1, 2), 8.0, PackedInt32Array(), PackedFloat32Array([100.0, 200.0]))
	check(heads.heads_known() == 1, "the chunk sent again with one head replaces the two (%d)" % heads.heads_known())
	heads.set_chunk(Vector2i(2, 2), 8.0, PackedInt32Array(), PackedFloat32Array([300.0, 200.0]))
	heads.drop_chunk(Vector2i(1, 2))
	check(heads.heads_known() == 1, "dropping a chunk drops its heads only (%d)" % heads.heads_known())
	heads.clear()
	check(heads.heads_known() == 0 and heads.heads_built().is_empty(), "clear drops every head")
	heads.free()


func _images() -> void:
	var patch: Image = SpringHeads.patch_image()
	check(patch.get_width() == 96 and patch.get_height() == 144, "the patch is 96 x 144 px, 4 x 6 m")
	var middle: Color = patch.get_pixel(48, 72)
	check(middle.a > 0.75 and middle.r < 0.2 and middle.g < 0.2, "its middle is dark wet soil, nearly opaque (%s)" % str(middle))
	check(patch.get_pixel(0, 0).a < 0.01 and patch.get_pixel(95, 143).a < 0.01, "its corners are clear, so it fades into the ground")
	var runnel: Image = SpringHeads.runnel_image(false)
	var glint: Image = SpringHeads.runnel_image(true)
	check(runnel.get_pixel(0, 64).a < 0.05 and runnel.get_pixel(8, 64).a > 0.5, "the runnel is a narrow line: clear at its sides, wet in the middle")
	check(glint.get_pixel(0, 64).r < 0.05 and (glint.get_pixel(7, 64).r + glint.get_pixel(8, 64).r) > 0.3, "the glint is only its bright middle")
	check(SpringHeads.ice_image().get_pixel(8, 16).a > 0.5, "the frozen end is pale ice")


func _trickle() -> void:
	var heads: Array = [Vector3(10.0, 0.0, 0.0), Vector3(3.0, 1.0, 0.0)]
	check(CaveWater.nearest_head(heads, Vector3.ZERO) == Vector3(3.0, 1.0, 0.0), "the trickle plays at the nearest head")
	check(CaveWater.nearest_head([], Vector3.ZERO) == Vector3.INF, "no heads: none (Vector3.INF)")
	check(CaveWater.TRICKLE_DB < CaveWater.STREAM_DB and CaveWater.TRICKLE_REACH_M <= 8.0, "the trickle is quieter than the cave stream and heard only close by")
