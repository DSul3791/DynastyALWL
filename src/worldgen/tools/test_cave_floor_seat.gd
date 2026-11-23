extends SceneTree

# Cave stones and mine leftovers lie on the floor (world audit, 23 Nov 2026: 12% of the cave stones floated, up to 3 m, and 4% were buried,
# because each was laid on its own shape's floor where a junction, a deeper chamber or a spring pool cuts lower, and the voxel floor sits off
# the exact shape). tile_terrain_data._seat_cave_scatter moves only the height: every entry keeps its number, x, z, kind and value (the server's
# item keys), and boulders keep their spot (their ore is read there). Measured against the LOD 0 Transvoxel mesh the player stands on.
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_floor_seat.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

var failures: int = 0
var generator
var mesher: VoxelMesherTransvoxel = VoxelMesherTransvoxel.new()
var meshes: Dictionary = {}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file("res://worlds/base_world/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, "res://worlds/base_world/tiles")
	var data = generator.get_tile(Vector2i(4, 5))   # spring caves with pools, karst caves and a mine: 772 entries
	var seated: PackedFloat32Array = data.cave_scatter.duplicate()
	data.cave_scatter = PackedFloat32Array()

	for cave in data._cave_sources:
		data._scatter_cave(cave)

	var raw: PackedFloat32Array = data.cave_scatter
	check(raw.size() == seated.size() and raw.size() > 500, "same entries in the same order (%d)" % int(float(seated.size()) / 5.0))
	var same: bool = true
	var boulders_kept: bool = true
	var off_before: int = 0
	var off_after: int = 0
	var measured: int = 0

	@warning_ignore("integer_division")
	for n in range(mini(raw.size(), seated.size()) / 5):
		for k in [0, 2, 3, 4]:
			same = same and raw[n * 5 + k] == seated[n * 5 + k]

		if int(raw[n * 5 + 3]) == 1:
			boulders_kept = boulders_kept and raw[n * 5 + 1] == seated[n * 5 + 1]
			continue

		if n % 3 != 0:
			continue   # a third of them against the mesh keeps the test short

		var floor_was: float = _floor_near(raw[n * 5], raw[n * 5 + 1], raw[n * 5 + 2])
		var floor_now: float = _floor_near(seated[n * 5], seated[n * 5 + 1], seated[n * 5 + 2])
		measured += 1
		off_before += 1 if is_nan(floor_was) or raw[n * 5 + 1] - floor_was > 0.10 or floor_was - raw[n * 5 + 1] > 0.15 else 0
		off_after += 1 if is_nan(floor_now) or seated[n * 5 + 1] - floor_now > 0.10 or floor_now - seated[n * 5 + 1] > 0.15 else 0

	check(same, "every entry keeps x, z, kind and value")
	check(boulders_kept, "every boulder keeps its height")
	print("     %d stones and leftovers measured: %d off the floor before, %d after" % [measured, off_before, off_after])
	check(off_before > 20, "the unseated layout has floating or buried stones (the fault is measured)")
	check(off_after * 20 <= measured, "seated: at most 5% more than 0.10 m over or 0.15 m under the mesh floor")
	check(off_after * 5 < off_before, "seated: under a fifth of the faults left")
	print("test_cave_floor_seat: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)


# The LOD 0 mesh floor nearest to y in [y - 3 m, y + 1 m] at (x, z), NAN for none (as world_audit._cave_floor measures it).
func _floor_near(x: float, y: float, z: float) -> float:
	var key: Vector3i = Vector3i(int(floor(x / 16.0)), int(floor(y / 8.0)), int(floor(z / 16.0)))

	if not meshes.has(key):
		meshes[key] = _mesh(key.x * 16, key.y * 8 - 8, key.z * 16)

	var tris: PackedVector3Array = meshes[key]
	var best: float = NAN

	for t in range(0, tris.size(), 3):
		var a: Vector3 = tris[t]
		var b: Vector3 = tris[t + 1]
		var c: Vector3 = tris[t + 2]
		var d: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)

		if absf(d) < 1.0e-6:
			continue

		var u: float = ((b.x - x) * (c.z - z) - (c.x - x) * (b.z - z)) / d
		var w: float = ((c.x - x) * (a.z - z) - (a.x - x) * (c.z - z)) / d

		if u < -1.0e-5 or w < -1.0e-5 or 1.0 - u - w < -1.0e-5:
			continue

		var h: float = u * a.y + w * b.y + (1.0 - u - w) * c.y

		if h <= y + 1.0 and h >= y - 3.0 and (is_nan(best) or absf(h - y) < absf(best - y)):
			best = h

	return best


# The LOD 0 Transvoxel triangles (world points) of the 16 m column at x0, z0 from y0 up 24 m.
func _mesh(x0: int, y0: int, z0: int) -> PackedVector3Array:
	var buffer: VoxelBuffer = Layout.make_buffer(1)
	buffer.create(19, 27, 19)
	var origin: Vector3i = Vector3i(x0 - 1, y0 - 1, z0 - 1)
	generator.generate(buffer, origin, 0)
	var mesh: Mesh = mesher.build_mesh(buffer, [])
	var out: PackedVector3Array = PackedVector3Array()

	if mesh == null or mesh.get_surface_count() == 0:
		return out

	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	for i in arrays[Mesh.ARRAY_INDEX]:
		out.append(Vector3(origin) + v[i] + Vector3.ONE)

	return out
