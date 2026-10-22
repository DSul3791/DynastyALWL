extends SceneTree

# Fall columns (water_falls.gd): finding them in a level grid, the wire format and the mesh.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_falls.gd

const FallsScript := preload("res://src/worldgen/runtime/water_falls.gd")
const GridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const WaterSim := preload("res://src/water/water_sim.gd")
const WaterLive := preload("res://src/water/water_live.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var count: int = 12
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)
	var vel: PackedFloat32Array = PackedFloat32Array()
	vel.resize(count * count * 2)

	# A channel along row 5: flat at 100 m, a 24 m drop over three points, flat at 76 m.
	for i in range(count):
		var level: float = 100.0 if i < 4 else (100.0 - float(i - 3) * 8.0 if i < 7 else 76.0)
		levels[5 * count + i] = level
		vel[(5 * count + i) * 2] = 6.0

	var bed: Callable = func(x: float, _z: float) -> float: return levels[5 * 12 + clampi(int(round(x / 8.0)), 0, 11)] - 0.5
	var falls: Array = FallsScript.find(null, Vector2.ZERO, count, 8.0, levels, vel, bed)
	_check(falls.size() == 1, "one fall found (%d)" % falls.size())

	if falls.size() == 1:
		var fall: Dictionary = falls[0]
		var points: PackedVector3Array = fall["points"]
		_check(points.size() >= 6, "resampled polyline (%d points)" % points.size())
		_check(float(fall["drop"]) > 0.5, "the fall drops")
		_check(float(fall["width"]) >= FallsScript.WIDTH_MIN_M and float(fall["width"]) <= FallsScript.WIDTH_MAX_M, "width in limits (%.1f)" % float(fall["width"]))

		for n in range(1, points.size()):
			_check(points[n].y <= points[n - 1].y + 0.0001, "never rises (%d)" % n)

		# Wire round trip.
		var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
		FallsScript.encode_into(buffer, falls)
		buffer.seek(0)
		_check(buffer.get_u8() == FallsScript.FALL_MARK, "mark byte")
		var back: Array = FallsScript.decode_from(buffer)
		_check(back.size() == 1 and back[0]["points"].size() == points.size(), "round trip count")
		_check(absf(back[0]["points"][0].x - points[0].x) < 0.06 and absf(back[0]["points"][0].y - points[0].y) < 0.03, "round trip position")
		_check(absf(float(back[0]["width"]) - float(fall["width"])) < 0.06, "round trip width")

		var mesh: ArrayMesh = FallsScript.build_mesh(back, 4)
		_check(mesh.get_surface_count() == 3, "ribbon, splash and foam surfaces (%d)" % mesh.get_surface_count())
		_check(FallsScript.build_mesh(back, 0).get_surface_count() == 0, "cap 0 draws nothing")

	# More flow, a wider ribbon.
	var wide_vel: PackedFloat32Array = vel.duplicate()

	for n in range(wide_vel.size()):
		wide_vel[n] *= 1.0

	var strong: Array = FallsScript.find(null, Vector2.ZERO, count, 8.0, levels, vel, func(x: float, _z: float) -> float: return levels[5 * 12 + clampi(int(round(x / 8.0)), 0, 11)] - 1.5)
	var weak: Array = FallsScript.find(null, Vector2.ZERO, count, 8.0, levels, vel, func(x: float, _z: float) -> float: return levels[5 * 12 + clampi(int(round(x / 8.0)), 0, 11)] - 0.1)
	_check(strong.size() == 1 and weak.size() == 1 and float(strong[0]["flow"]) > float(weak[0]["flow"]), "deeper water carries more flow")

	# A chunk grid with falls survives encode and decode with its levels.
	var grid: Dictionary = {"count": count, "spacing": 8.0, "levels": levels, "wet": 20, "vel": vel, "falls": falls}
	var decoded: Dictionary = GridScript.decode(GridScript.encode(grid))
	_check(decoded["falls"].size() == falls.size(), "grid carries its falls")
	_check(decoded["vel"].size() == vel.size(), "grid still carries the current")
	var plain: Dictionary = {"count": count, "spacing": 8.0, "levels": levels, "wet": 20, "vel": vel}
	_check(GridScript.decode(GridScript.encode(plain))["falls"].is_empty(), "no falls trailer when none")

	# Owner report (2026-10-20, build 232): a ribbon ran down the sloping ground above a cliff.
	# A run falling 4 m every 8 m (about 27 degrees) is a cascade, not a fall.
	var cascade: PackedFloat32Array = levels.duplicate()

	for i in range(count):
		cascade[5 * count + i] = 100.0 - float(i) * 4.0

	_check(FallsScript.find(null, Vector2.ZERO, count, 8.0, cascade, vel, bed).is_empty(), "a cascade is no fall")

	_test_thin_fall()

	print("water falls: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Owner report (2026-10-20, build 200): no water went over pond B's cliff. A spring's flow down
# a cliff is a film about 10 cm thick, hidden by the steep draw rule, so the drawn levels have
# no fall. The fall finder's levels (WaterLive._fall_levels) count that film.
func _test_river_width() -> void:
	# A river three cells across feeding a lip: the fall is as wide as the river (2.5 cells = 20 m), not the flow formula.
	var count: int = 12
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)

	for j in range(4, 7):
		for i in range(0, 5):
			levels[j * count + i] = 50.0

	var chain: PackedInt32Array = PackedInt32Array([5 * count + 4, 5 * count + 5, 5 * count + 6])
	_check(absf(FallsScript._river_width(chain, count, 8.0, levels) - 20.0) < 0.01, "the fall width is the river's: three wet cells across make 20 m (%.1f)" % FallsScript._river_width(chain, count, 8.0, levels))
	_check(FallsScript._river_width(PackedInt32Array([0]), count, 8.0, levels) == 0.0, "a lone point cannot be measured")


func _test_thin_fall() -> void:
	_test_river_width()
	var count: int = 12
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(count * count)
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(count * count)
	var channel: PackedInt32Array = PackedInt32Array()

	for j in range(count):
		for i in range(count):
			var k: int = j * count + i
			ground[k] = 100.0 if i < 4 else (100.0 - float(i - 3) * 10.0 if i < 7 else 70.0)
			ground[k] += 0.0 if j == 5 else 2.0

			if j == 5:
				depth[k] = 0.3 if i < 3 or i > 7 else 0.1
				channel.append(k)

	var sim = WaterSim.new()
	sim.setup(count, 8.0, ground)
	sim.set_depth(depth)
	var levels: PackedFloat32Array = sim.level_map()
	var bed: Callable = func(x: float, z: float) -> float: return ground[clampi(int(round(z / 8.0)), 0, count - 1) * count + clampi(int(round(x / 8.0)), 0, count - 1)]
	var vel: PackedFloat32Array = PackedFloat32Array()
	vel.resize(count * count * 2)
	_check(is_nan(levels[5 * count + 5]), "thin water on the cliff face is not drawn")
	_check(FallsScript.find(null, Vector2.ZERO, count, 8.0, levels, vel, bed).is_empty(), "the drawn levels alone make no fall")
	var fall_levels: PackedFloat32Array = WaterLive._fall_levels(sim, levels, channel)
	var still: PackedFloat32Array = vel.duplicate()

	for i in range(count):
		vel[(5 * count + i) * 2] = 2.0

	_check(FallsScript.find(null, Vector2.ZERO, count, 8.0, fall_levels, vel, bed, levels, vel).size() == 1, "a film down a cliff below a running river makes a fall")
	_check(FallsScript.find(null, Vector2.ZERO, count, 8.0, fall_levels, vel, bed, levels, still).is_empty(), "no fall out of still water (a pond's bank)")

	# Owner report (2026-10-20, build 232): films left on a pond's bank made rows of fall ribbons.
	# Thin water down a bank with no drawn water at its top is no fall.
	var bank: PackedFloat32Array = fall_levels.duplicate()
	var bank_drawn: PackedFloat32Array = levels.duplicate()

	for i in range(3):
		bank_drawn[5 * count + i] = NAN

	_check(FallsScript.find(null, Vector2.ZERO, count, 8.0, bank, vel, bed, bank_drawn, vel).is_empty(), "thin water down a bank with nothing drawn above it is no fall")
