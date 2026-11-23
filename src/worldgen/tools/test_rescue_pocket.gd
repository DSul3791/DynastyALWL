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
	var call: Callable = Callable(self, "sdf")
	var room_hill: float = gen.surface_height(ROOM.x, ROOM.y)

	# Under the room's floor, in the rock: back onto the floor.
	var room_floor: float = air_floor(ROOM.x, ROOM.y, 9)
	var under: Vector3 = Vector3(ROOM.x, room_floor - 1.5, ROOM.y)
	var p: Vector3 = Rescue.pocket_near(call, under, room_hill)
	check(not is_nan(p.y) and absf(p.y - (room_floor + 0.7)) < 0.8 and p.y < room_hill - 2.0, "stuck 1.5 m under the room floor (voxel %.0f): stood at %s, the hill at %.2f" % [room_floor, str(p), room_hill])

	for lift in [0.2, 0.9, 1.6]:
		check(sdf(Vector3i((p + Vector3(0.0, lift, 0.0)).floor())) > 0.0, "  %.1f m over those feet is air" % lift)

	# In the passage wall, beside the passage: onto its floor, within a few metres.
	var side: Vector3 = Vector3(PASSAGE.x, 7.6, PASSAGE.y) + Vector3(0.966, 0.0, -0.259) * 2.4
	check(sdf(Vector3i(side.floor())) < 0.0, "a spot 2.4 m from the passage's line is in its wall")
	var q: Vector3 = Rescue.pocket_near(call, side, gen.surface_height(side.x, side.z))
	check(not is_nan(q.y) and q.distance_to(side) < 3.5 and absf(q.y - 7.3) < 1.0, "stuck in the passage wall: stood on the passage floor at %s" % str(q))

	# Deep in the hill, no cave near: none (the rescue stands the player on the surface, as before).
	var deep: Vector3 = Vector3(58250.0, 2.0, 72120.0)
	check(sdf(Vector3i(deep.floor())) < 0.0, "a spot deep in the hill is in rock")
	check(is_nan(Rescue.pocket_near(call, deep, gen.surface_height(deep.x, deep.z)).y), "stuck deep in the hill with no air near: no pocket, the surface rescue stands")

	# Nothing loaded round the player: none.
	check(is_nan(Rescue.pocket_near(func(_c: Vector3i) -> float: return 0.0, under, room_hill).y), "nothing loaded: no pocket")

	print("test_rescue_pocket: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
