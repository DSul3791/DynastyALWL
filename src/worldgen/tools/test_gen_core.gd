extends SceneTree

# GenCore (C++, native/water_core) must give the same bytes as the GDScript it replaces. Run with:
#   godot --headless --path . --script res://src/worldgen/tools/test_gen_core.gd
# Exits 1 on any difference.

const ChannelsScript := preload("res://src/worldgen/tile/drainage_channels.gd")
const HeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const FillScript := preload("res://src/worldgen/tile/drainage_fill.gd")


func _init() -> void:
	if not ClassDB.class_exists("GenCore"):
		push_error("GenCore is not loaded (addons/water_core)")
		quit(1)
		return

	var failures: int = 0
	failures += _valleys(1, 220, 8.0, 60)
	failures += _valleys(2, 150, 8.0, 200)
	failures += _valleys(3, 97, 8.0, 40)
	failures += _fill(11, 200)
	failures += _fill(12, 130)
	failures += _fill(13, 311)
	failures += _height(21, 97)
	failures += _height(22, 160)
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)


# Random ground and random valley stamps (some near and over the edge), the script loop against the C++ one.
func _valleys(seed_value: int, size: int, cell_m: float, jobs: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var h: PackedFloat32Array = PackedFloat32Array()
	var cut: PackedFloat32Array = PackedFloat32Array()
	h.resize(size * size)
	cut.resize(size * size)

	for k in range(size * size):
		h[k] = rng.randf_range(-5.0, 400.0)
		cut[k] = h[k] - rng.randf_range(0.0, 3.0)

	var jobs_i: PackedInt32Array = PackedInt32Array()
	var jobs_f: PackedFloat64Array = PackedFloat64Array()

	for job in range(jobs):
		var rim_m: float = rng.randf_range(20.0, 300.0)
		jobs_i.append(rng.randi_range(0, size * size - 1))
		jobs_i.append(int(ceil(rim_m / cell_m)))
		jobs_f.append_array(PackedFloat64Array([rng.randf_range(0.0, 400.0), rng.randf_range(0.02, 0.2), rng.randf_range(2.0, 40.0), rim_m, rng.randf(), rng.randf_range(1.0, 25.0)]))

	var script_out: PackedFloat32Array = ChannelsScript.carve_valleys_script(cut, h, size, cell_m, jobs_i, jobs_f)
	var native_out: PackedFloat32Array = ClassDB.instantiate("GenCore").carve_valleys(cut, h, size, cell_m, jobs_i, jobs_f)
	var changed: int = 0

	for k in range(size * size):
		if script_out[k] != cut[k]:
			changed += 1

	var same: bool = script_out.to_byte_array() == native_out.to_byte_array()
	print("valleys seed %d: %d cells carved, %s" % [seed_value, changed, "identical" if same else "DIFFERENT"])
	return 0 if same and changed > 0 else 1


# Random hilly ground with a sea on one side and flat patches (ties and plateaus), the GDScript flood and route against C++.
func _fill(seed_value: int, size: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.02
	var h: PackedFloat32Array = PackedFloat32Array()
	var sea: PackedByteArray = PackedByteArray()
	h.resize(size * size)
	sea.resize(size * size)

	for j in range(size):
		for i in range(size):
			var k: int = j * size + i
			var value: float = noise.get_noise_2d(float(i), float(j)) * 60.0 + float(i) * 0.15 - 8.0
			value = snappedf(value, 0.5) if (floori(float(i) / 20.0) + floori(float(j) / 20.0)) % 3 == 0 else value + rng.randf() * 0.2   # flat terraces and noise
			h[k] = value
			sea[k] = 1 if value <= 0.0 and i < floori(float(size) / 4.0) else 0

	FillScript.force_script = true
	var script_fill = FillScript.new()
	script_fill.build(h, sea, size, 0.5)
	FillScript.force_script = false
	var native_fill = FillScript.new()
	native_fill.build(h, sea, size, 0.5)
	var same: bool = script_fill.filled.to_byte_array() == native_fill.filled.to_byte_array() \
		and script_fill._parent == native_fill._parent and script_fill.receiver == native_fill.receiver and script_fill.order == native_fill.order \
		and script_fill.lake_id == native_fill.lake_id
	print("fill seed %d: %d cells in order, %d lakes, %s" % [seed_value, native_fill.order.size(), native_fill.lakes.size(), "identical" if same else "DIFFERENT"])
	return 0 if same else 1


# Box blur and the province-border search of the ledges code, the GDScript against C++.
func _height(seed_value: int, side: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var field: PackedFloat32Array = PackedFloat32Array()
	var province: PackedByteArray = PackedByteArray()
	field.resize(side * side)
	province.resize(side * side)

	for j in range(side):
		for i in range(side):
			field[j * side + i] = rng.randf_range(-20.0, 900.0)
			province[j * side + i] = (floori(float(i) / 17.0) + 2 * floori(float(j) / 23.0)) % 4

	var core = ClassDB.instantiate("GenCore")
	var same: bool = true

	for radius in [0, 1, 3]:
		same = same and HeightScript.box_blur_script(field, side, radius).to_byte_array() == core.box_blur(field, side, radius).to_byte_array()

	for reach in [1, 4]:
		same = same and HeightScript.near_border_script(province, side, reach) == core.near_border(province, side, reach)

	print("height loops seed %d: %s" % [seed_value, "identical" if same else "DIFFERENT"])
	return 0 if same else 1
