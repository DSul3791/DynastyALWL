extends SceneTree

# A player stuck in rock under the ground is stood on the nearest floor of air, a cave's or a tunnel's, not on the hill over it (physical world
# audit round 6, 23 Nov 2026: the rescue stood a player who slipped into the rock of the Ragtooth camp cave on the hillside 6 m over its room).
# rescue.gd pocket_near on the generated voxels of the real camp cave (camp_caves.gd, mouth 58264,72084).
#   godot --headless --path . --script res://src/worldgen/tools/test_rescue_pocket.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const Rescue := preload("res://src/client/rescue.gd")
const WORLD := "res://worlds/base_world"

const PASSAGE := Vector2(58269.4, 72104.3)   # the roofed passage, floor about 7.05, running north-north-east (75 degrees)
const ROOM := Vector2(58271.35, 72111.43)     # the room at its end, floor about 6.9, radius 4
const ORIGIN := Vector3i(58240, -4, 72070)
const SIZE := Vector3i(64, 48, 64)

var failures: int = 0
var gen
var buffer: VoxelBuffer


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func sdf(cell: Vector3i) -> float:
	var at: Vector3i = cell - ORIGIN

	if at.x < 0 or at.y < 0 or at.z < 0 or at.x >= SIZE.x or at.y >= SIZE.y or at.z >= SIZE.z:
		return 0.0   # not loaded

	return buffer.get_voxel_f(at.x, at.y, at.z, Layout.CHANNEL_SDF)


func air_floor(x: float, z: float, from_y: int) -> float:
	for y in range(from_y, from_y - 8, -1):
		if sdf(Vector3i(int(floor(x)), y, int(floor(z)))) < 0.0:
			return float(y)

	return NAN


# The first SDF zero going up the voxel column under (x, z) from voxel y0, linear between voxels: rock to air (`to_rock` false) or air to rock.
func zero_up(x: float, z: float, y0: int, to_rock: bool) -> float:
	var cell: Vector2i = Vector2i(int(floor(x)), int(floor(z)))

	for y in range(y0, y0 + 20):
		var a: float = sdf(Vector3i(cell.x, y, cell.y))
		var b: float = sdf(Vector3i(cell.x, y + 1, cell.y))

		if (not to_rock and a < 0.0 and b > 0.0) or (to_rock and a > 0.0 and b <= 0.0):
			return float(y) + a / (a - b)

	return NAN


func _init() -> void:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	gen = GeneratorScript.new()
	gen.setup(settings, rules, tables, WORLD + "/tiles")
	buffer = Layout.make_buffer(1)
	buffer.create(SIZE.x, SIZE.y, SIZE.z)
	gen.generate(buffer, ORIGIN, 0)
	var sdf_call: Callable = Callable(self, "sdf")
	var room_hill: float = gen.surface_height(ROOM.x, ROOM.y)

	# Under the room's floor, in the rock: back onto the floor, the body's middle 0.95 m over the floor's SDF zero (feet 5 cm over it), its
	# top (0.9 m over the middle) under the roof's zero.
	var room_floor: float = air_floor(ROOM.x, ROOM.y, 9)
	var under: Vector3 = Vector3(ROOM.x, room_floor - 1.5, ROOM.y)
	var p: Vector3 = Rescue.pocket_near(sdf_call, under, room_hill)
	check(not is_nan(p.y) and p.y < room_hill - 2.0, "stuck 1.5 m under the room floor: stood at %s, the hill at %.2f" % [str(p), room_hill])

	if not is_nan(p.y):
		var floor_zero: float = zero_up(p.x, p.z, int(floor(p.y)) - 3, false)
		var roof_zero: float = zero_up(p.x, p.z, int(floor(floor_zero)) + 1, true)
		check(absf((p.y - 0.9) - floor_zero - 0.05) < 0.02, "  its feet are 5 cm over the floor (floor %.2f, feet %.2f)" % [floor_zero, p.y - 0.9])
		check(p.y + 0.9 < roof_zero, "  its top %.2f is under the roof %.2f" % [p.y + 0.9, roof_zero])

	# In the passage wall, beside the passage: onto its floor, within a few metres.
	var side: Vector3 = Vector3(PASSAGE.x, 7.6, PASSAGE.y) + Vector3(0.966, 0.0, -0.259) * 2.4
	check(sdf(Vector3i(side.floor())) < 0.0, "a spot 2.4 m from the passage's line is in its wall")
	var q: Vector3 = Rescue.pocket_near(sdf_call, side, gen.surface_height(side.x, side.z))
	check(not is_nan(q.y) and q.distance_to(side) < 3.5 and absf(q.y - 8.0) < 0.6, "stuck in the passage wall: stood on the passage floor at %s" % str(q))

	if not is_nan(q.y):
		var passage_floor: float = zero_up(q.x, q.z, int(floor(q.y)) - 3, false)
		check(absf((q.y - 0.9) - passage_floor - 0.05) < 0.02 and q.y + 0.9 < zero_up(q.x, q.z, int(floor(passage_floor)) + 1, true), "  feet 5 cm over its floor %.2f, top under its roof" % passage_floor)

	# Deep in the hill, no cave near: none (the rescue stands the player on the surface, as before).
	var deep: Vector3 = Vector3(58250.0, 2.0, 72120.0)
	check(sdf(Vector3i(deep.floor())) < 0.0, "a spot deep in the hill is in rock")
	check(is_nan(Rescue.pocket_near(sdf_call, deep, gen.surface_height(deep.x, deep.z)).y), "stuck deep in the hill with no air near: no pocket, the surface rescue stands")

	# Nothing loaded round the player: none.
	check(is_nan(Rescue.pocket_near(func(_c: Vector3i) -> float: return 0.0, under, room_hill).y), "nothing loaded: no pocket")

	print("test_rescue_pocket: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
