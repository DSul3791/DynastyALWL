extends SceneTree

# Checks how well the drawn water lies on the real ground (stripes over running water).
# Runs tile (3,4)'s water a little from the painted water, then for the chunks with the
# most running water compares the old flat 8 m surface and the new fine surface with
# the real ground at 1 m points inside running-water cells.
#
#   godot --headless --path . --script res://src/worldgen/tools/water_surface_check.gd -- [--ticks=200] [--chunks=8]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")


func _init() -> void:
	var ticks: int = 200
	var chunks_wanted: int = 8

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ticks="):
			ticks = int(argument.trim_prefix("--ticks="))
		elif argument.begins_with("--chunks="):
			chunks_wanted = int(argument.trim_prefix("--chunks="))

	var world_dir: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var data = generator.get_tile(Vector2i(3, 4))

	if data.placeholder:
		print("FAIL: tile 3,4 missing")
		quit(1)
		return

	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var sim = WaterSettler.build(data, 10.0, generator, not dry)
	var tick_start: int = Time.get_ticks_msec()

	for t in range(ticks):
		sim.step()

	print("%d ticks in %d ms, %d wet squares" % [ticks, Time.get_ticks_msec() - tick_start, sim.wet_cells()])
	data.sim_levels = sim.level_map()
	var chunk_m: float = 256.0
	var per_side: int = int(round(float(data.samples - 1) * data.spacing_m / chunk_m))
	var picks: Array = []

	# Chunks ranked by running-water cells (wet corners not level).
	for cj in range(per_side):
		for ci in range(per_side):
			var running: int = 0
			var cells: int = int(chunk_m / data.spacing_m)

			for j in range(cells):
				for i in range(cells):
					var k: int = (cj * cells + j) * data.samples + ci * cells + i
					var a: float = data.sim_levels[k]
					var b: float = data.sim_levels[k + 1]

					if not is_nan(a) and not is_nan(b) and data.heights[k] > 0.0 and data.heights[k + 1] > 0.0 and absf(a - b) > WaterGridScript.FINE_SLOPE_M:
						running += 1

			if running > 0:
				picks.append([running, ci, cj])

	picks.sort_custom(func(x, y): return x[0] > y[0])
	print("%d chunks with running water" % picks.size())
	var old_under: int = 0
	var old_over: int = 0
	var new_under: int = 0
	var samples: int = 0
	var total_ms: int = 0
	var total_bytes: int = 0

	for pick in picks.slice(0, chunks_wanted):
		var origin: Vector2 = Vector2(data.x0 + float(pick[1]) * chunk_m, data.z0 + float(pick[2]) * chunk_m)
		var started: int = Time.get_ticks_msec()
		var grid: Dictionary = WaterGridScript.chunk_levels(generator, origin, chunk_m)
		var cold_ms: int = Time.get_ticks_msec() - started
		started = Time.get_ticks_msec()
		var bytes: PackedByteArray = WaterGridScript.encode(WaterGridScript.chunk_levels(generator, origin, chunk_m))
		var warm_ms: int = Time.get_ticks_msec() - started
		var back: Dictionary = WaterGridScript.decode(bytes)
		var mesh: ArrayMesh = WaterGridScript.build_mesh(back, StandardMaterial3D.new())
		total_ms += warm_ms
		total_bytes += bytes.size()
		var count: int = int(grid["count"])
		var levels: PackedFloat32Array = grid["levels"]
		if not back.has("fine"):
			print("chunk %d,%d: grid wet %d, %d bytes" % [pick[1], pick[2], int(grid["wet"]), bytes.size()])
			continue

		var fine: Dictionary = back["fine"]

		for cell in fine:
			var i: int = cell % count
			@warning_ignore("integer_division")
			var j: int = cell / count
			var corners: Array = [levels[cell], levels[cell + 1], levels[cell + count], levels[cell + count + 1]]
			var all_wet: bool = corners.all(func(c): return not is_nan(c))

			# Fully wet cells only: there the water should cover the ground everywhere.
			if not all_wet:
				continue

			for b in range(8):
				for a in range(8):
					var u: float = (float(a) + 0.5) / 8.0
					var v: float = (float(b) + 0.5) / 8.0
					var x: float = origin.x + (float(i) + u) * 8.0
					var z: float = origin.y + (float(j) + v) * 8.0
					var ground: float = generator.surface_height(x, z, 0)
					var flat: float = lerpf(lerpf(corners[0], corners[1], u), lerpf(corners[2], corners[3], u), v)
					var surface: float = _fine_at(fine[cell], u, v)
					samples += 1
					old_under += 1 if flat < ground else 0
					old_over += 1 if flat > ground + 1.0 else 0
					new_under += 1 if surface < ground else 0

		@warning_ignore("integer_division")
		print("chunk %d,%d: %d running cells, %d fine, levels %d ms cold / %d ms warm, %d bytes, %d triangles" % [
			pick[1], pick[2], pick[0], fine.size(), cold_ms, warm_ms, bytes.size(), mesh.surface_get_array_index_len(0) / 3 if mesh.get_surface_count() > 0 else 0])

	print("points inside wet running cells: %d" % samples)
	print("old flat surface: %.1f%% under the ground (stripes), %.1f%% over 1 m above it" % [100.0 * old_under / maxf(samples, 1), 100.0 * old_over / maxf(samples, 1)])
	print("new fine surface: %.1f%% under the ground" % [100.0 * new_under / maxf(samples, 1)])
	@warning_ignore("integer_division")
	print("average %d ms and %d bytes per chunk" % [total_ms / maxi(chunks_wanted, 1), total_bytes / maxi(chunks_wanted, 1)])
	quit(0)


func _fine_at(heights: PackedFloat32Array, u: float, v: float) -> float:
	var sub: int = WaterGridScript.FINE_SUB
	var side: int = sub + 1
	var fu: float = u * float(sub)
	var fv: float = v * float(sub)
	var a: int = mini(int(fu), sub - 1)
	var b: int = mini(int(fv), sub - 1)
	var tu: float = fu - float(a)
	var tv: float = fv - float(b)
	var h00: float = heights[b * side + a]
	var h10: float = heights[b * side + a + 1]
	var h01: float = heights[(b + 1) * side + a]
	var h11: float = heights[(b + 1) * side + a + 1]

	# The mesh splits each square along the (0,0)-(1,1) diagonal.
	if tu >= tv:
		return h00 + tu * (h10 - h00) + tv * (h11 - h10)

	return h00 + tv * (h01 - h00) + tu * (h11 - h01)
