extends SceneTree

# Measures the runtime terrain generator (plan step 14) on a baked tile and
# draws cross-sections. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/terrain_bench.gd -- --tile=3,4
#
# Options (after "--"):
#   --tile=X,Z     tile to measure (default 3,4; must be baked)
#   --world=DIR    world folder (default res://worlds/base_world)
#   --threads=N    also time N worker threads generating together (default 4)
#
# Writes <world>/plan/tile_X_Z_section_peak.png and _cave.png: vertical slices coloured by
# rock (cover brown, ore bright, caves black, air sky blue).

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const ROCK_COLORS := {
	0: Color(0.62, 0.78, 0.92), 1: Color(0.55, 0.42, 0.28), 2: Color(0.36, 0.38, 0.40),
	3: Color(0.80, 0.78, 0.68), 4: Color(0.10, 0.10, 0.10), 5: Color(0.85, 0.62, 0.62),
	6: Color(0.30, 0.33, 0.42), 7: Color(0.22, 0.22, 0.25), 8: Color(0.86, 0.72, 0.45),
	9: Color(0.95, 0.95, 0.97), 10: Color(0.97, 0.97, 0.90), 11: Color(0.70, 0.60, 0.55),
}

var generator


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var world_dir: String = "res://worlds/base_world"
	var threads: int = 4

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--threads="):
			threads = int(argument.trim_prefix("--threads="))

	quit(_run(world_dir, tile, threads))


func _run(world_dir: String, tile: Vector2i, threads: int) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		push_error("\n".join(errors))
		return 1

	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	var started: int = Time.get_ticks_usec()
	var data = generator.get_tile(tile)
	print("Tile %s loaded in %d ms (placeholder: %s); %d provinces, %d bodies, %d ore bodies, %d caves" % [
		str(tile), (Time.get_ticks_usec() - started) / 1000, str(data.placeholder),
		data.prov_datum.size(), data.bodies.size(), data.ores.size(), data.caves.size()
	])

	if data.placeholder:
		push_error("tile %s is not baked" % str(tile))
		return 1

	# Places to measure: the highest ground, the starter spawn (or the tile
	# middle), a cave and an ore body.
	var peak: Vector3 = _highest(data)
	var middle: Vector3 = Vector3(data.x0 + 7680.0, 0.0, data.z0 + 7680.0)
	middle.y = generator.surface_height(middle.x, middle.z)
	var cave_point: Vector3 = data.caves[0]["chambers"][0]["center"] if not data.caves.is_empty() and not data.caves[0]["chambers"].is_empty() else middle
	print("peak %s, middle %s, cave %s" % [str(peak), str(middle), str(cave_point)])

	# Surface blocks at LOD 0: an 8 by 8 patch of block columns at the
	# surface over the middle of the tile and over the peak.
	for place in [["middle", middle], ["peak", peak]]:
		var times: PackedFloat32Array = PackedFloat32Array()

		for bz in range(8):
			for bx in range(8):
				var x: int = int(floor(place[1].x / 32.0) + bx - 4) * 32
				var z: int = int(floor(place[1].z / 32.0) + bz - 4) * 32
				var h: float = generator.surface_height(float(x) + 16.0, float(z) + 16.0)
				var y: int = int(floor(h / 32.0)) * 32
				times.append(_time_block(Vector3i(x, y, z), 0))

		_report("LOD 0 surface blocks near the %s" % place[0], times)

	# Blocks straight down from the middle: underground and deep.
	var under: PackedFloat32Array = PackedFloat32Array()
	var deep: PackedFloat32Array = PackedFloat32Array()
	var mx: int = int(floor(middle.x / 32.0)) * 32
	var mz: int = int(floor(middle.z / 32.0)) * 32

	for n in range(1, 9):
		under.append(_time_block(Vector3i(mx + 32 * (n % 3), int(floor(middle.y / 32.0)) * 32 - 32 * n, mz), 0))
		deep.append(_time_block(Vector3i(mx, -1024 - 32 * n, mz + 32 * (n % 3)), 0))

	_report("LOD 0 blocks just under the surface", under)
	_report("LOD 0 blocks about 1 km down", deep)

	# Air above the ground.
	var air: PackedFloat32Array = PackedFloat32Array()

	for n in range(8):
		air.append(_time_block(Vector3i(mx + 32 * n, 1024, mz), 0))

	_report("LOD 0 air blocks", air)

	# Cave blocks.
	var cave: PackedFloat32Array = PackedFloat32Array()

	for n in range(8):
		var c: Vector3i = Vector3i(int(floor(cave_point.x / 32.0)) * 32 + 32 * (n % 2 - 1), int(floor(cave_point.y / 32.0)) * 32 + 32 * (n / 4 - 1), int(floor(cave_point.z / 32.0)) * 32 + 32 * ((n / 2) % 2 - 1))
		cave.append(_time_block(c, 0))

	_report("LOD 0 blocks around a cave chamber", cave)

	# Coarser LODs at the surface.
	for lod in range(1, 7):
		var times: PackedFloat32Array = PackedFloat32Array()
		var span: int = 32 << lod

		for n in range(6):
			var x: int = int(floor(middle.x / float(span)) + n % 3) * span
			var z: int = int(floor(middle.z / float(span)) + n / 3) * span
			var h: float = generator.surface_height(float(x) + 0.5 * span, float(z) + 0.5 * span)
			var y: int = int(floor(h / float(span))) * span
			times.append(_time_block(Vector3i(x, y, z), lod))

		_report("LOD %d surface blocks (%d m)" % [lod, span], times)

	if threads > 1:
		_time_threads(middle, threads)

	_graph_comparison(data, middle)
	_sections(world_dir, tile, data, peak, cave_point)
	return 0


func _time_block(origin: Vector3i, lod: int) -> float:
	var buffer: VoxelBuffer = Layout.make_buffer()
	var started: int = Time.get_ticks_usec()
	generator.generate(buffer, origin, lod)
	return float(Time.get_ticks_usec() - started) / 1000.0


func _report(label: String, times: PackedFloat32Array) -> void:
	var sorted: Array = Array(times)
	sorted.sort()
	var total: float = 0.0

	for t in sorted:
		total += t

	print("%-44s mean %6.1f ms  median %6.1f ms  max %6.1f ms  (%d blocks)" % [
		label, total / float(sorted.size()), sorted[sorted.size() / 2], sorted[sorted.size() - 1], sorted.size()
	])


func _highest(data) -> Vector3:
	var best: int = 0

	for index in range(data.heights.size()):
		if data.heights[index] > data.heights[best]:
			best = index

	var x: float = data.x0 + float(best % data.samples) * data.spacing_m
	var z: float = data.z0 + float(best / data.samples) * data.spacing_m
	return Vector3(x, data.heights[best], z)


# Many surface blocks on several threads at once, as the terrain would ask.
func _time_threads(middle: Vector3, count: int) -> void:
	var jobs: Array = []

	for bz in range(16):
		for bx in range(16):
			var x: int = int(floor(middle.x / 32.0) + bx - 8) * 32
			var z: int = int(floor(middle.z / 32.0) + bz - 8) * 32
			var h: float = generator.surface_height(float(x) + 16.0, float(z) + 16.0)
			jobs.append(Vector3i(x, int(floor(h / 32.0)) * 32, z))

	var started: int = Time.get_ticks_usec()
	var workers: Array = []

	for n in range(count):
		var thread: Thread = Thread.new()
		thread.start(_thread_work.bind(jobs, n, count))
		workers.append(thread)

	for thread in workers:
		thread.wait_to_finish()

	var seconds: float = float(Time.get_ticks_usec() - started) / 1.0e6
	print("%d surface blocks on %d threads: %.2f s, %.0f blocks per second" % [jobs.size(), count, seconds, float(jobs.size()) / seconds])


func _thread_work(jobs: Array, first: int, step: int) -> void:
	var buffer: VoxelBuffer = Layout.make_buffer()

	for n in range(first, jobs.size(), step):
		generator.generate(buffer, jobs[n], 0)


# The surface alone through Voxel Tools' graph generator: the tile's height
# map as an image (bilinear), one noise octave, SDF = y - height.
func _graph_comparison(data, middle: Vector3) -> void:
	var image: Image = Image.create_empty(data.samples, data.samples, false, Image.FORMAT_RF)

	for j in range(data.samples):
		for i in range(data.samples):
			image.set_pixel(i, j, Color(data.heights[j * data.samples + i], 0.0, 0.0))

	var graph: VoxelGeneratorGraph = VoxelGeneratorGraph.new()
	var f: VoxelGraphFunction = graph.get_main_function()
	var in_x: int = f.create_node(VoxelGraphFunction.NODE_INPUT_X, Vector2.ZERO)
	var in_y: int = f.create_node(VoxelGraphFunction.NODE_INPUT_Y, Vector2.ZERO)
	var in_z: int = f.create_node(VoxelGraphFunction.NODE_INPUT_Z, Vector2.ZERO)
	var shift_x: int = f.create_node(VoxelGraphFunction.NODE_ADD, Vector2.ZERO)
	var shift_z: int = f.create_node(VoxelGraphFunction.NODE_ADD, Vector2.ZERO)
	var scale_x: int = f.create_node(VoxelGraphFunction.NODE_MULTIPLY, Vector2.ZERO)
	var scale_z: int = f.create_node(VoxelGraphFunction.NODE_MULTIPLY, Vector2.ZERO)
	var img: int = f.create_node(VoxelGraphFunction.NODE_IMAGE_2D, Vector2.ZERO)
	var noise_node: int = f.create_node(VoxelGraphFunction.NODE_NOISE_2D, Vector2.ZERO)
	var noise_amp: int = f.create_node(VoxelGraphFunction.NODE_MULTIPLY, Vector2.ZERO)
	var height: int = f.create_node(VoxelGraphFunction.NODE_ADD, Vector2.ZERO)
	var sdf: int = f.create_node(VoxelGraphFunction.NODE_SUBTRACT, Vector2.ZERO)
	var out: int = f.create_node(VoxelGraphFunction.NODE_OUTPUT_SDF, Vector2.ZERO)
	f.add_connection(in_x, 0, shift_x, 0)
	f.set_node_default_input(shift_x, 1, -data.x0)
	f.add_connection(shift_x, 0, scale_x, 0)
	f.set_node_default_input(scale_x, 1, 1.0 / data.spacing_m)
	f.add_connection(in_z, 0, shift_z, 0)
	f.set_node_default_input(shift_z, 1, -data.z0)
	f.add_connection(shift_z, 0, scale_z, 0)
	f.set_node_default_input(scale_z, 1, 1.0 / data.spacing_m)
	f.add_connection(scale_x, 0, img, 0)
	f.add_connection(scale_z, 0, img, 1)
	f.set_node_param(img, 0, image)
	f.set_node_param(img, 1, 1)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 1.0 / 30.0
	f.set_node_param(noise_node, 0, noise)
	f.add_connection(in_x, 0, noise_node, 0)
	f.add_connection(in_z, 0, noise_node, 1)
	f.add_connection(noise_node, 0, noise_amp, 0)
	f.set_node_default_input(noise_amp, 1, 0.7)
	f.add_connection(img, 0, height, 0)
	f.add_connection(noise_amp, 0, height, 1)
	f.add_connection(in_y, 0, sdf, 0)
	f.add_connection(height, 0, sdf, 1)
	f.add_connection(sdf, 0, out, 0)
	var result: Dictionary = graph.compile()

	if not result.get("success", false):
		print("graph did not compile: %s" % str(result))
		return

	var times: PackedFloat32Array = PackedFloat32Array()
	var buffer: VoxelBuffer = Layout.make_buffer()

	for bz in range(8):
		for bx in range(8):
			var x: int = int(floor(middle.x / 32.0) + bx - 4) * 32
			var z: int = int(floor(middle.z / 32.0) + bz - 4) * 32
			var h: float = generator.surface_height(float(x) + 16.0, float(z) + 16.0)
			var started: int = Time.get_ticks_usec()
			graph.generate_block(buffer, Vector3i(x, int(floor(h / 32.0)) * 32, z), 0)
			times.append(float(Time.get_ticks_usec() - started) / 1000.0)

	_report("Graph generator, surface only (comparison)", times)


# Vertical slices: 1,024 m long, from 40 m above the highest ground to
# 400 m below the lowest, at 1 m (LOD 0) through the tile's highest point, and
# a 128 m slice through a cave.
func _sections(world_dir: String, tile: Vector2i, data, peak: Vector3, cave_point: Vector3) -> void:
	var base: String = "%s/plan/tile_%d_%d_section" % [world_dir, tile.x, tile.y]
	_section(base + "_peak.png", Vector2(peak.x - 512.0, peak.z), 1024, -400, 0, 2)
	_section(base + "_cave.png", Vector2(cave_point.x - 64.0, cave_point.z), 128, int(cave_point.y) - 64, 0, 1)


# A slice along +x at fixed z, `length` m long, drawn at LOD `lod`, scaled
# down by `step` per pixel.
func _section(path: String, start: Vector2, length: int, y_floor: int, lod: int, step: int) -> void:
	var s: int = 1 << lod
	var span: int = 32 * s
	var x0: int = int(floor(start.x / float(span))) * span
	var z: int = int(floor(start.y / float(span))) * span
	var tops: float = -INF
	var bottoms: float = INF

	for x in range(x0, x0 + length, 4):
		var h: float = generator.surface_height(float(x), float(z))
		tops = maxf(tops, h)
		bottoms = minf(bottoms, h)

	var y_low: int = int(floor(minf(float(y_floor), bottoms - 400.0) / float(span))) * span if y_floor <= -400 else int(floor(float(y_floor) / float(span))) * span
	var y_high: int = int(ceil((tops + 40.0) / float(span))) * span

	if y_floor > -400:
		y_high = y_low + length

	var width: int = length / step
	var height: int = (y_high - y_low) / step
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	var buffer: VoxelBuffer = Layout.make_buffer()
	var started: int = Time.get_ticks_usec()
	var blocks: int = 0

	for bx in range(x0, x0 + length, span):
		for by in range(y_low, y_high, span):
			generator.generate(buffer, Vector3i(bx, by, z), lod)
			blocks += 1

			for i in range(0, 32, maxi(step / s, 1)):
				for j in range(0, 32, maxi(step / s, 1)):
					var px: int = (bx - x0 + i * s) / step
					var py: int = height - 1 - (by - y_low + j * s) / step

					if px >= width or py < 0 or py >= height:
						continue

					var color: Color
					var sdf: float = buffer.get_voxel_f(i, j, 0, Layout.CHANNEL_SDF)
					var rock: int = buffer.get_voxel(i, j, 0, Layout.CHANNEL_ROCK)
					var ore: int = buffer.get_voxel(i, j, 0, Layout.CHANNEL_RESOURCE)

					if sdf > 0.0:
						color = Color(0.05, 0.05, 0.05) if rock == 0 and by + j * s < generator.surface_height(float(bx + i * s), float(z)) - 1.0 else ROCK_COLORS[0]
					elif ore != 0:
						color = Color.from_hsv(fmod(float(ore) * 0.137, 1.0), 0.9, 1.0)
					else:
						color = ROCK_COLORS.get(rock, Color.MAGENTA)

					image.set_pixel(px, py, color)

	image.save_png(path)
	print("Section %s: %d by %d m, %d blocks in %d ms" % [path, length, y_high - y_low, blocks, (Time.get_ticks_usec() - started) / 1000])
