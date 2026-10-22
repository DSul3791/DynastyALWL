extends SceneTree

# Option B stage 1: depressions become lakes with the outlet at the lowest rim.
#   godot --headless --path . --script res://src/worldgen/tools/test_drainage_fill.gd [-- --tile=3,4]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const DrainageFillScript := preload("res://src/worldgen/tile/drainage_fill.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# 21 x 21 slope falling to the south with a bowl in rows 6-10, columns 8-12; the south wall is a ridge with one notch, the lowest rim.
func _synthetic() -> void:
	var size: int = 21
	var h: PackedFloat32Array = PackedFloat32Array()
	h.resize(size * size)
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(size * size)

	for row in range(size):
		for column in range(size):
			h[row * size + column] = 30.0 - float(row) * 1.0

	for row in range(6, 11):
		for column in range(8, 13):
			h[row * size + column] -= 6.0

	for column in range(7, 14):
		h[11 * size + column] = 25.0

	h[11 * size + 10] = 16.5
	for row in range(12, size):
		h[row * size + 10] = 16.0 - float(row - 12)
	var fill = DrainageFillScript.new()
	fill.build(h, sea, size, 1.0)
	_check(fill.lakes.size() == 1, "synthetic bowl is one lake (%d)" % fill.lakes.size())

	if fill.lakes.size() == 1:
		var lake: Dictionary = fill.lakes[0]
		_check(int(lake["outlet"]) == 11 * size + 10, "outlet is the lowest rim cell (%d)" % int(lake["outlet"]))
		_check(lake["depth"] > 1.0, "lake depth %.1f m" % lake["depth"])

	for index in range(size * size):
		if fill.lake_id[index] != 0:
			_check(fill.filled[index] >= h[index], "filled never below ground")
			break


func _tile(tile: Vector2i) -> void:
	var errors: Array = []
	var world: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		print("no baked tile, skipping real tile")
		return

	var step: int = 2
	var side: int = (data.samples - 1) / step + 1
	var h: PackedFloat32Array = PackedFloat32Array()
	h.resize(side * side)
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(side * side)

	for row in range(side):
		for column in range(side):
			var k: int = row * step * data.samples + column * step
			h[row * side + column] = data.heights[k]
			sea[row * side + column] = 1 if data.heights[k] < 0.0 else 0

	var begun: int = Time.get_ticks_msec()
	var fill = DrainageFillScript.new()
	fill.build(h, sea, side, 2.0)
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	var worst: float = 0.0
	var no_outlet: int = 0

	for lake in fill.lakes:
		worst = maxf(worst, lake["depth"])

		if int(lake["outlet"]) < 0:
			no_outlet += 1
			print("  no outlet: level %.1f depth %.1f cells %d" % [lake["level"], lake["depth"], lake["cells"]])
			var seed: int = -1

			for index in range(side * side):
				if fill.lake_id[index] == fill.lakes.find(lake) + 1:
					seed = index
					break

			print("   at row %d col %d of %d" % [seed / side, seed % side, side])

	print("tile %s at %d m: %d lakes deeper than 2 m, deepest %.1f m, %.1f s" % [tile, int(data.spacing_m) * step, fill.lakes.size(), worst, took])
	_check(no_outlet == 0, "every lake has an outlet")
	_check(took < 30.0, "fill takes under 30 s per tile (%.1f s)" % took)


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))

	_synthetic()
	_tile(tile)
	print("drainage fill: %d failures" % failures)
	quit(1 if failures > 0 else 0)
