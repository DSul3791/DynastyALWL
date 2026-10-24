extends SceneTree

# R1 land map and spring catch-basin check (design/WATER_LAND_TYPES.md, Plan 1 of WATER_ACTION_PLANS.md).
# Read only: reads a baked tile and its saved settled water, writes a report, a spring list and a land-type picture.
#
#   godot --headless --path . --script res://src/worldgen/tools/land_map.gd -- --tile=3,4 [--all] [--world=res://worlds/base_world] [--out=DIR] [--picture] [--run-hours=6] (dry start like the server, then run this many simulated hours instead of reading the saved water)
#
# Outputs in --out (default /mnt/project-files/water/land_map):
#   springs_X_Z.csv   one row per spring the settler would place: cell, world x z, ground, metres below its ring, basin ok, spread cells,
#                     and where it would slide to (world x z) when it fails. Sonny's failing-spring list.
#   land_X_Z.txt      counts of each land type and of failing springs
#   land_X_Z.png      the land types as colours (with --picture)

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")
const WaterStore := preload("res://src/water/water_store.gd")
const L := preload("res://src/water/land_type.gd")
const Sig := preload("res://src/water/land_signature.gd")

const PEAT_SOIL := 6
const MARSH_BIOME := 10
const MINERAL_SOILS := [3, 4, 5, 7]       # silt, clay, loam, alluvium

const COLOURS := [Color(0.35, 0.45, 0.28), Color(0.1, 0.25, 0.75), Color(0.2, 0.55, 0.9), Color(0.55, 0.75, 0.35), Color(0.1, 0.5, 0.3), Color(0.55, 0.35, 0.5), Color(0.85, 0.75, 0.35)]

var run_hours: float = 0.0


func _init() -> void:
	var tiles: Array = [Vector2i(3, 4)]
	var world: String = "res://worlds/base_world"
	var out_dir: String = "/mnt/project-files/water/land_map"
	var all: bool = false
	var picture: bool = false
	run_hours = 0.0

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tiles = [Vector2i(int(parts[0]), int(parts[1]))]
		elif argument == "--all":
			all = true
		elif argument.begins_with("--run-hours="):
			run_hours = float(argument.trim_prefix("--run-hours="))
		elif argument == "--picture":
			picture = true
		elif argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")

	if all:
		tiles = []

		for x in range(2, 5):
			for z in range(3, 6):
				tiles.append(Vector2i(x, z))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var total_springs: int = 0
	var total_fail: int = 0

	for tile in tiles:
		var result: Dictionary = _one_tile(generator, world, tile, out_dir, picture)
		total_springs += int(result.get("springs", 0))
		total_fail += int(result.get("fail", 0))

	print("land map done: %d tiles, %d springs, %d fail the basin rule" % [tiles.size(), total_springs, total_fail])
	quit(0)


func _one_tile(generator, world: String, tile: Vector2i, out_dir: String, picture: bool) -> Dictionary:
	var data = generator.get_tile(tile)

	if data.placeholder:
		print("tile %s: no baked tile, skipped" % tile)
		return {}

	var side: int = data.samples
	var started: int = Time.get_ticks_msec()
	var dry_run: bool = run_hours > 0.0
	var sim = WaterSettler.build(data, 3.0 if dry_run else 10.0, generator, not dry_run)       # the server: base 3 m3/s x10, dry start
	var ground: PackedFloat32Array = sim.ground
	var rows: PackedStringArray = PackedStringArray(["cell,i,j,world_x,world_z,ground_m,below_ring_m,basin_ok,fix_world_x,fix_world_z,spread_cells,spread_ok"])

	# Saved settled water if there is one; otherwise the painted water the settler starts from.
	var water_file: String = "%s/water/tile_%d_%d.water" % [world, tile.x, tile.y]
	var settled: PackedFloat32Array = PackedFloat32Array()

	if dry_run:
		sim.spring_multiplier = 10.0
		var every: int = 0

		while sim.seconds < run_hours * 3600.0:
			sim.step()
			every += 1

			if every % 2000 == 0:
				print("  simulated %.1f h, %d wet cells, %d ms" % [sim.seconds / 3600.0, sim.wet_cells(), Time.get_ticks_msec() - started])

		settled = sim.get_depth()
		print("ran %.1f simulated hours in %d ms" % [sim.seconds / 3600.0, Time.get_ticks_msec() - started])
	else:
		settled = WaterStore.load_depth(water_file, side)

	var have_settled: bool = not settled.is_empty()
	var depth: PackedFloat32Array = settled if have_settled else sim.get_depth()
	_wet_picture_near(depth, data, side, Vector2(53840.0, 68520.0), "%s/near_defect_%d_%d.png" % [out_dir, tile.x, tile.y])
	var fail: int = 0
	var spread_fail: int = 0

	for sp in sim.springs:
		var k: int = int(sp[0])
		var i: int = k % side
		@warning_ignore("integer_division")
		var j: int = k / side
		var report: Dictionary = L.basin_report(ground, data.water_class, side, k)
		var spread: int = L.spread_cells(depth, data.water_class, side, k) if have_settled else -1
		var fix: int = int(report["fix"])
		var fix_x: String = ""
		var fix_z: String = ""

		if fix >= 0:
			fix_x = "%.0f" % (data.x0 + float(fix % side) * data.spacing_m)
			@warning_ignore("integer_division")
			fix_z = "%.0f" % (data.z0 + float(fix / side) * data.spacing_m)

		if not bool(report["ok"]):
			fail += 1

		var spread_ok: bool = spread <= L.SPREAD_MAX_CELLS

		if have_settled and not spread_ok:
			spread_fail += 1

		rows.append("%d,%d,%d,%.0f,%.0f,%.2f,%.2f,%s,%s,%s,%d,%s" % [k, i, j, data.x0 + float(i) * data.spacing_m, data.z0 + float(j) * data.spacing_m, ground[k], float(report["below_m"]), "yes" if bool(report["ok"]) else "NO", fix_x, fix_z, spread, "yes" if spread_ok else "NO"])

	var csv: FileAccess = FileAccess.open("%s/springs_%d_%d.csv" % [out_dir, tile.x, tile.y], FileAccess.WRITE)
	csv.store_string("\n".join(rows) + "\n")
	csv.close()

	# Land types from the settled water (the signature starts at this state by design).
	var counts: Array = [0, 0, 0, 0, 0, 0, 0]

	if have_settled:
		var speed: PackedFloat32Array = L.speeds_from_levels(ground, depth, side, data.spacing_m)
		var sig = Sig.new()
		sig.setup(side)
		sig.init_from(depth, speed)
		var types: PackedByteArray = PackedByteArray()
		types.resize(side * side)

		for k in range(side * side):
			if sig.depth[k] < 0.01 and data.water_class[k] == 0:
				continue

			var peaty: bool = data.soil[k] == PEAT_SOIL
			var warm_fertile: bool = data.biome[k] == MARSH_BIOME and data.soil[k] in MINERAL_SOILS
			types[k] = sig.type_at(k, data.water_class[k], peaty, warm_fertile)

		types = L.filter_extent(types, side)

		for k in range(side * side):
			counts[types[k]] += 1

		if picture:
			_draw(types, side, "%s/land_%d_%d.png" % [out_dir, tile.x, tile.y], ground)

	var summary: PackedStringArray = PackedStringArray()
	summary.append("tile %d,%d  samples %d  settled water file: %s" % [tile.x, tile.y, side, "yes" if have_settled else "NO (painted water only)"])
	summary.append("springs %d, fail the basin rule %d, wide thin sheet %d" % [sim.springs.size(), fail, spread_fail])

	if have_settled:
		for t in range(L.NAMES.size()):
			summary.append("%s: %d cells" % [L.NAMES[t], counts[t]])

	var text: FileAccess = FileAccess.open("%s/land_%d_%d.txt" % [out_dir, tile.x, tile.y], FileAccess.WRITE)
	text.store_string("\n".join(summary) + "\n")
	text.close()
	print("\n".join(summary))
	print("  (%d ms)" % (Time.get_ticks_msec() - started))
	return {"springs": sim.springs.size(), "fail": fail}


func _draw(types: PackedByteArray, side: int, path: String, ground: PackedFloat32Array) -> void:
	var image: Image = Image.create(side, side, false, Image.FORMAT_RGB8)

	for j in range(side):
		for i in range(side):
			var k: int = j * side + i
			var t: int = types[k]
			var color: Color

			if t == L.DRY:
				var shade: float = 0.5 if ground[k] > 0.0 else 0.15
				color = Color(shade * 0.7, shade * 0.8, shade * 0.6) if ground[k] > 0.0 else Color(0.05, 0.1, 0.2)
			else:
				color = COLOURS[t]

			image.set_pixel(i, j, color)

	image.save_png(path)


# A 160 x 160 cell crop (1,280 m) of the wet cells round a world point, for looking at a reported spot.
func _wet_picture_near(depth: PackedFloat32Array, data, side: int, point: Vector2, path: String) -> void:
	var ci: int = int(round((point.x - data.x0) / data.spacing_m))
	var cj: int = int(round((point.y - data.z0) / data.spacing_m))

	if ci < 80 or cj < 80 or ci >= side - 80 or cj >= side - 80:
		return

	var image: Image = Image.create(160, 160, false, Image.FORMAT_RGB8)

	for j in range(160):
		for i in range(160):
			var k: int = (cj - 80 + j) * side + ci - 80 + i
			var g: float = clampf(0.3 + (data.heights[k] - data.heights[cj * side + ci]) * 0.01, 0.1, 0.9)
			var color: Color = Color(g * 0.7, g * 0.8, g * 0.6)

			if depth[k] >= 0.01:
				color = Color(0.4, 0.8, 1.0) if depth[k] < 0.15 else Color(0.1, 0.35, 0.85) if depth[k] < 0.6 else Color(0.0, 0.1, 0.5)

			if data.water_class[k] != 0:
				color = color.lerp(Color(1.0, 1.0, 0.2), 0.25)

			image.set_pixel(i, j, color)

	image.save_png(path)
