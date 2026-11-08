extends SceneTree

# Stage E, M0 (docs/water/stage_e_readers_design.md 6b): water_record.gd reads the island water record in the format Sonny's writer
# (tools/watershed/record.py, #622) writes. A tiny record of two tiles (3 x 3 samples each, sharing an edge) is written here and read
# back: the field-table decodings (f4 with NaN, log-coded discharge, scales, i4 no-data), the shared seam, the bake frame's margin from
# the neighbour and its gaps, a reach across the seam found from both tiles with one id, downstream to the sea, lakes by their _x/_z
# points, the climate default, and the refusals (incomplete, unknown version, a raster of the wrong length).
#   godot --headless --path . --script res://src/worldgen/tools/test_water_record_files.gd

const WaterRecordScript := preload("res://src/worldgen/record/water_record.gd")

const DIR := "user://test_water_record_files/record"
const S := 3          # samples per tile edge
const CELL := 8.0

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func write_json(path: String, value: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(value))
	f.close()


# Writes one raster of tile tx (tiles run along x): value_of(gx, gz) gives each sample, gx the island sample column.
func write_raster(tx: int, name: String, typ: String, value_of: Callable, count: int = S * S) -> void:
	var f := FileAccess.open("%s/tiles/%d_0/%s.%s" % [DIR, tx, name, typ], FileAccess.WRITE)

	for k in count:
		var v: float = float(value_of.call(tx * (S - 1) + k % S, floori(float(k) / float(S))))

		match typ:
			"f4":
				f.store_float(v)
			"u1":
				f.store_8(int(v))
			"u2":
				f.store_16(int(v))
			_:
				f.store_32(int(v) & 0xFFFFFFFF)

	f.close()


func write_record(version: int, complete: bool) -> void:
	for tx in 2:
		DirAccess.make_dir_recursive_absolute("%s/tiles/%d_0" % [DIR, tx])
		write_raster(tx, "ground", "f4", func(gx, gz): return gx * 10 + gz)
		write_raster(tx, "water_level", "f4", func(gx, gz): return NAN if gx == 0 else 5.5)
		write_raster(tx, "discharge", "u2", func(gx, _gz): return 0 if gx == 0 else roundi((log(2.0) / log(10.0) + 4.0) * 6553.5))
		write_raster(tx, "basin", "i4", func(gx, _gz): return -1 if gx == 0 else 7)
		write_raster(tx, "table_depth", "u1", func(_gx, _gz): return 8)
		write_raster(tx, "water_class", "u1", func(_gx, _gz): return 3, S * S - 1 if tx == 1 else S * S)   # tile 1's is one byte short

	write_json(DIR + "/manifest.json", {"version": version, "complete": complete, "cell_m": CELL, "origin_x": 0.0, "origin_z": 0.0, "tile_samples": S, "tiles": [0, 0, 1, 0],
		"fields": [{"name": "ground", "type": "f4", "file": "ground.f4", "units": "m"}, {"name": "water_level", "type": "f4", "file": "water_level.f4", "nodata": "NaN"},
			{"name": "water_class", "type": "u1", "file": "water_class.u1"}, {"name": "discharge", "type": "u2", "file": "discharge.u2", "codes_per_decade": 6553.5, "nodata": 0},
			{"name": "basin", "type": "i4", "file": "basin.i4", "nodata": -1}, {"name": "table_depth", "type": "u1", "file": "table_depth.u1", "scale": 0.25}],
		"summary": {"missing": [] if complete else ["rivers as water (R5)"]}})
	write_json(DIR + "/network.json", {"reaches": [{"id": 1, "polyline": [[10.0, 3.0, 5.0], [30.0, 2.0, 5.0]], "down": 2}, {"id": 2, "polyline": [[30.0, 2.0, 5.0], [31.0, 0.0, 15.0]], "down": -1}],
		"lakes": [{"id": 4, "level_m": 12.0, "deepest_x": 4.0, "deepest_z": 4.0, "spill_x": null, "spill_z": null}], "falls": [], "cold_air_pools": []})
	write_json(DIR + "/climate.json", {"default": {"sea_level_mean_c": 9.0, "seasonal_swing_c": 5.0}, "by_island": {"far": {"sea_level_mean_c": 4.0}}})


func at(values: PackedFloat32Array, i: int, j: int, n: int = S) -> float:
	return values[j * n + i]


func _init() -> void:
	# 1. Refusals: an incomplete record (unless asked), an unknown version.
	write_record(1, false)
	var rec = WaterRecordScript.new()
	check(rec.open(DIR) != "", "an incomplete record is refused")
	check(rec.open(DIR, true) == "", "a tool may open an incomplete record on purpose")
	write_record(9, true)
	check(WaterRecordScript.new().open(DIR) != "", "an unknown record version is refused")
	write_record(1, true)
	rec = WaterRecordScript.new()
	var err: String = rec.open(DIR)
	check(err == "", "a complete record opens (%s)" % err)

	# 2. Decodings by the field table, and the shared seam.
	var g0: PackedFloat32Array = rec.raster(0, 0, "ground")
	var g1: PackedFloat32Array = rec.raster(1, 0, "ground")
	check(g0.size() == S * S and is_equal_approx(at(g0, 2, 1), 21.0), "f4 ground decodes (%s)" % str(g0))
	check(g1.size() == S * S and is_equal_approx(at(g1, 0, 1), at(g0, 2, 1)), "the two tiles share their edge samples")
	var wl: PackedFloat32Array = rec.raster(0, 0, "water_level")
	check(is_nan(at(wl, 0, 0)) and is_equal_approx(at(wl, 1, 0), 5.5), "water level: NaN where there is none")
	var q: PackedFloat32Array = rec.raster(0, 0, "discharge")
	check(at(q, 0, 0) == 0.0 and absf(at(q, 1, 0) - 2.0) < 0.002, "log-coded discharge: 0 is no flow, the code reads back 2 m3/s (%.4f)" % at(q, 1, 0))
	var b: PackedFloat32Array = rec.raster(0, 0, "basin")
	check(is_nan(at(b, 0, 0)) and at(b, 1, 0) == 7.0, "i4 basin: -1 is no-data")
	check(is_equal_approx(at(rec.raster(0, 0, "table_depth"), 1, 1), 2.0), "u1 table depth x scale 0.25")
	check(rec.raster(1, 0, "water_class").is_empty() and rec.error_of != "", "a raster of the wrong length is refused (%s)" % rec.error_of)
	check(rec.raster(5, 0, "ground").is_empty(), "a tile outside the record has nothing")

	# 3. The bake frame: a margin from the neighbour across the seam, the edge repeated where there is no neighbour.
	var fr: PackedFloat32Array = rec.frame(Vector2i(0, 0), 1, "ground")
	var n: int = S + 2
	check(fr.size() == n * n and is_equal_approx(at(fr, 4, 2, n), 31.0), "the frame's margin comes from the neighbour (%.1f)" % at(fr, 4, 2, n))
	check(is_equal_approx(at(fr, 0, 2, n), 1.0) and rec.frame_gaps > 0, "beyond a missing neighbour the edge repeats, and the gaps are counted (%d)" % rec.frame_gaps)

	# 4. The network: one reach across the seam, found from both tiles; downstream to the sea; lakes by their _x/_z points.
	var left: Array = rec.reaches_in(Rect2(0.0, 0.0, 16.0, 16.0))
	var right: Array = rec.reaches_in(Rect2(16.0, 0.0, 16.0, 16.0))
	check(left.size() == 1 and int(left[0]["id"]) == 1, "the reach is found in the first tile")
	check(right.size() == 2 and right.any(func(r): return int(r["id"]) == 1), "the same reach, same id, is found in the second tile")
	check(rec.downstream(1) == [1, 2], "downstream follows down to the sea (%s)" % str(rec.downstream(1)))
	check(rec.lakes_in(Rect2(0.0, 0.0, 8.0, 8.0)).size() == 1 and rec.lakes_in(Rect2(16.0, 0.0, 16.0, 16.0)).is_empty(), "a lake is found by its deepest point")

	# 5. Climate: an island's row, else the default.
	check(float(rec.climate("far")["sea_level_mean_c"]) == 4.0 and float(rec.climate("starter")["sea_level_mean_c"]) == 9.0, "climate by island, falling back to the default")

	print("test_water_record_files: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
