extends SceneTree

# BUG-007: every cave passage and chamber stays open at each detail level that carves caves (LOD 0 to cave_max_lod), so the seam between a fine and
# a coarse level never draws a wall across a tunnel. Samples the middle of passages and the centres of chambers in tile 3,4 at every such level.
# Needs the voxel engine (skips on stock Godot).
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_lods.gd

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const SAMPLES := 160

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
	var max_lod: int = int(rules.get("runtime_terrain", {}).get("cave_max_lod", 2))
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

			var local: Vector3i = g - o / sf
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

	check(closed_fine * 10 < tested, "almost every sampled cave point is open at LOD 0 (%d of %d closed)" % [closed_fine, tested])
	print("cave lods: %d points at LOD 0 to %d (%d not open at LOD 0, %d coarse samples too near the ground to widen), %d failures" % [tested, max_lod, closed_fine, shallow, failures])
	quit(1 if failures > 0 else 0)
