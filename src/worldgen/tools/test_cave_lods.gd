extends SceneTree

# BUG-007: every cave passage and chamber stays open at each detail level that carves caves (LOD 0 to cave_max_lod), so the seam between a fine and
# a coarse level never draws a wall across a tunnel. Samples the middle of passages and the centres of chambers in tile 3,4 at every such level.
# Fake cave wall (7 Nov 2026, docs/design/cave_lod_carving_design.md): caves are carved at every level that has collision, LOD 3 included, and
# where a level carves a shape at its own size the surfaces meet: every voxel near a sampled point is rock or air at that level as it is at LOD 0
# (checked at LOD 1; LOD 2, which still widens passages, is counted, not failed, until the cave bake sizes them).
# Needs the voxel engine (skips on stock Godot).
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_lods.gd

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const SAMPLES := 160
const SURFACE_POINTS := 40

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL " + what)
		failures += 1


func _initialize() -> void:
	if not ClassDB.class_exists("VoxelBuffer"):
		print("test_cave_lods: no voxel module in this engine, skipped")
		quit(0)
		return

	var generator_script: GDScript = load("res://src/worldgen/runtime/terrain_generator.gd")
	var layout: GDScript = load("res://src/worldgen/runtime/terrain_layout.gd")
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	tables.load_directory()
	var gen = generator_script.new()
	gen.setup(settings, rules, tables, world + "/tiles")
	var data = gen.get_tile(Vector2i(3, 4))
	check(data != null and not data.placeholder, "tile 3,4 loads")

	if failures > 0:
		quit(1)
		return

	var points: Array = []

	for cave in data.caves:
		for capsule in cave["capsules"]:
			points.append([0.5 * (capsule["a"] + capsule["b"]), [capsule["a"], capsule["b"]], float(capsule["rw"]), float(capsule["rh"])])

		for chamber in cave["chambers"]:
			points.append([chamber["center"], [chamber["center"]], float(chamber["r"]), float(chamber["rh"])])

	var step: int = maxi(1, int(float(points.size()) / float(SAMPLES)))
	var max_lod: int = generator_script.cave_carve_lods(int(rules.get("runtime_terrain", {}).get("cave_max_lod", 2)))
	check(max_lod >= layout.COLLISION_LODS - 1, "caves are carved at every collision level (to LOD %d, collision to LOD %d)" % [max_lod, layout.COLLISION_LODS - 1])
	var shapes: Array = []

	for cave in data.caves:
		for capsule in cave["capsules"]:
			shapes.append([capsule["a"], capsule["b"], float(capsule["rw"]), float(capsule["rh"])])

		for chamber in cave["chambers"]:
			shapes.append([chamber["center"], chamber["center"], float(chamber["r"]), float(chamber["rh"])])

	# The shapes LOD 1 carves at another size than LOD 0 (narrow ones widened), found once.
	var resized: Array = []

	for shape in shapes:
		var room: Vector2 = generator_script.cave_room(data, [shape[0]] if shape[0] == shape[1] else [shape[0], shape[1]], shape[2], shape[3], 1)

		if not (is_equal_approx(room.x, shape[2]) and is_equal_approx(room.y, shape[3])):
			resized.append([shape[0], shape[1], maxf(room.x, room.y)])

	var met: int = 0
	var unmet: Array = [0, 0, 0]
	var blocks: Dictionary = {}
	var tested: int = 0
	var closed_fine: int = 0
	var shallow: int = 0

	for n in range(0, points.size(), step):
		var p: Vector3 = points[n][0]
		tested += 1

		var fine_open: bool = true

		for lod in range(0, max_lod + 1):
			var sf: int = 1 << lod
			var span: int = 32 * sf
			# The voxel nearest the point, and the block that holds that voxel. Taking the block that holds the point and clamping the rounded index to 31
			# read a voxel a whole step away when the point lay in the last half voxel of a block (Sonny 5 Nov 2026: the PC gate on #375 failed two
			# points this way, one read 3.9 m off sideways at LOD 2, the other 3.2 m low).
			var g: Vector3i = Vector3i(roundi(p.x / float(sf)), roundi(p.y / float(sf)), roundi(p.z / float(sf)))
			var o: Vector3i = Vector3i(int(floor(float(g.x) / 32.0)) * span, int(floor(float(g.y) / 32.0)) * span, int(floor(float(g.z) / 32.0)) * span)
			var key: String = "%d %s" % [lod, str(o)]

			if not blocks.has(key):
				var buffer: Object = layout.make_buffer(32)
				gen.generate(buffer, o, lod)
				blocks[key] = buffer

			var local: Vector3i = g - Vector3i(o.x >> lod, o.y >> lod, o.z >> lod)   # o is a whole number of blocks, so the shift is exact
			var v: float = blocks[key].get_voxel_f(local.x, local.y, local.z, layout.CHANNEL_SDF)
			# A point the finest level does not have open (a chamber centre under a lake bed, or right on the wall) says nothing about the coarse ones.
			if lod == 0:
				fine_open = v > 0.0
				closed_fine += 0 if fine_open else 1
			elif fine_open:
				# Near the ground a passage is not widened (it would dent the hillside), so a shallow one may still close at a coarse level.
				var room: Vector2 = generator_script.cave_room(data, points[n][1], points[n][2], points[n][3], lod)

				if minf(room.x, room.y) < generator_script.CAVE_MIN_VOXELS * float(sf) - 0.01:
					shallow += 1
				else:
					check(v > 0.0, "cave point %s, open at LOD 0, is open at LOD %d (sdf %.2f)" % [str(p), lod, v])

			# The surfaces meet: near the point, this level is rock or air where LOD 0 is, unless a shape within reach is carved at another size here.
			# Deep under the ground only (the ground's own detail differs between levels), and on the first SURFACE_POINTS points (each needs LOD 0
			# blocks round it too).
			if lod in [1, 2] and fine_open and tested <= SURFACE_POINTS and data.height_at(p.x, p.z) - p.y > 6.0 * float(sf) + 4.0:
				for dk in range(-2, 3):
					for dj in range(-2, 3):
						for di in range(-2, 3):
							var w: Vector3i = (g + Vector3i(di, dj, dk)) * sf
							var at: Vector3 = Vector3(w)

							if lod == 1 and _resized_near(resized, at, 2.0 * float(sf)):
								continue

							var same: bool = (_sdf(gen, layout, blocks, lod, w) > 0.0) == (_sdf(gen, layout, blocks, 0, w) > 0.0)
							met += 1 if same else 0
							unmet[lod] += 0 if same else 1

	check(unmet[1] == 0, "the LOD 1 and LOD 0 surfaces meet: %d of %d voxels near cave points differ" % [unmet[1], met + unmet[1]])
	print("cave lods: LOD 2 voxels that differ from LOD 0 near cave points (the seam lip; 0 once the cave bake sizes passages): %d" % unmet[2])

	check(closed_fine * 10 < tested, "almost every sampled cave point is open at LOD 0 (%d of %d closed)" % [closed_fine, tested])
	print("cave lods: %d points at LOD 0 to %d (%d not open at LOD 0, %d coarse samples too near the ground to widen), %d failures" % [tested, max_lod, closed_fine, shallow, failures])
	quit(1 if failures > 0 else 0)


# The signed distance at a world voxel (a multiple of 2^lod) at one level, generating and keeping the block that holds it.
func _sdf(gen, layout, blocks: Dictionary, lod: int, w: Vector3i) -> float:
	var sf: int = 1 << lod
	var span: int = 32 * sf
	var g: Vector3i = Vector3i(w.x >> lod, w.y >> lod, w.z >> lod)   # w is a whole number of voxels at this level, so the shift is exact
	var o: Vector3i = Vector3i(int(floor(float(g.x) / 32.0)) * span, int(floor(float(g.y) / 32.0)) * span, int(floor(float(g.z) / 32.0)) * span)
	var key: String = "%d %s" % [lod, str(o)]

	if not blocks.has(key):
		var buffer: Object = layout.make_buffer(32)
		gen.generate(buffer, o, lod)
		blocks[key] = buffer

	var local: Vector3i = g - Vector3i(o.x >> lod, o.y >> lod, o.z >> lod)
	return blocks[key].get_voxel_f(local.x, local.y, local.z, layout.CHANNEL_SDF)


# True where a resized shape ([a, b, its largest radius at this level]) reaches within `reach` of the spot.
func _resized_near(resized: Array, at: Vector3, reach: float) -> bool:
	for shape in resized:
		if at.distance_to(Geometry3D.get_closest_point_to_segment(at, shape[0], shape[1])) < float(shape[2]) + reach:
			return true

	return false
