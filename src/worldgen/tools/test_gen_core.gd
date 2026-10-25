extends SceneTree

# GenCore (C++, native/water_core) must give the same bytes as the GDScript it replaces. Run with:
#   godot --headless --path . --script res://src/worldgen/tools/test_gen_core.gd
# Exits 1 on any difference.

const ChannelsScript := preload("res://src/worldgen/tile/drainage_channels.gd")
const HeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const ClimateScript := preload("res://src/worldgen/tile/tile_climate.gd")
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
	failures += _stamp(31, 150, 400)
	failures += _stamp(32, 90, 150)
	failures += _climate(41, 129)
	failures += _climate(42, 73)
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


# Random river stamps (radius, sideways shift, depth) on random ground, the GDScript against C++.
func _stamp(seed_value: int, size: int, jobs: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var h: PackedFloat32Array = PackedFloat32Array()
	var bed: PackedFloat32Array = PackedFloat32Array()
	var surface: PackedFloat32Array = PackedFloat32Array()
	var centre: PackedFloat32Array = PackedFloat32Array()
	h.resize(size * size)
	bed.resize(size * size)
	surface.resize(size * size)
	centre.resize(size * size)

	for k in range(size * size):
		h[k] = rng.randf_range(0.0, 300.0)
		bed[k] = h[k]
		surface[k] = NAN if rng.randf() < 0.7 else h[k] - rng.randf_range(0.0, 5.0)
		centre[k] = h[k] - rng.randf_range(0.0, 6.0)

	var jobs_i: PackedInt32Array = PackedInt32Array()
	var jobs_f: PackedFloat64Array = PackedFloat64Array()

	for job in range(jobs):
		var radius_m: float = rng.randf_range(5.0, 60.0)
		var shift_x: float = rng.randf_range(-30.0, 30.0)
		var shift_z: float = rng.randf_range(-30.0, 30.0)
		jobs_i.append(rng.randi_range(0, size * size - 1))
		jobs_i.append(int(ceil(radius_m / 8.0)) + 2 + int(ceil(sqrt(shift_x * shift_x + shift_z * shift_z) / 8.0)))
		jobs_f.append_array(PackedFloat64Array([radius_m, shift_x, shift_z, rng.randf_range(0.2, 8.0)]))

	var script_out: Dictionary = ChannelsScript.stamp_channels_script(bed, surface, h, centre, size, 8.0, jobs_i, jobs_f)
	var native_out: Dictionary = ClassDB.instantiate("GenCore").stamp_channels(bed, surface, h, centre, size, 8.0, jobs_i, jobs_f)
	var same: bool = script_out["bed"].to_byte_array() == native_out["bed"].to_byte_array() and script_out["surface"].to_byte_array() == native_out["surface"].to_byte_array()
	var changed: int = 0

	for k in range(size * size):
		if script_out["bed"][k] != bed[k]:
			changed += 1

	print("channel stamps seed %d: %d cells lowered, %s" % [seed_value, changed, "identical" if same else "DIFFERENT"])
	return 0 if same and changed > 0 else 1


# Random terrain, water and climate inputs with the real rule numbers (data/tile_rules.json): the per-sample climate loop in GDScript against C++.
func _climate(seed_value: int, side: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var step: int = 8
	@warning_ignore("integer_division")
	var coarse: int = (side - 1) / step + 1
	var biome_names: Array = ["ocean", "beach", "hot_desert", "dry_scrub", "savanna", "tropical_forest", "mangrove", "temperate_grassland", "temperate_forest", "mixed_forest", "marsh", "heath", "boreal_forest", "tundra", "alpine_meadow", "bare_rock", "snowfield", "glacier"]
	var soil_names: Array = ["bare_rock", "sand", "gravel", "silt", "clay", "loam", "peat", "alluvium", "forest_humus", "stony_soil", "permafrost", "snow", "glacial_ice", "beach_sand"]
	var ids: Dictionary = {}
	var soil_ids: Dictionary = {}

	for k in range(biome_names.size()):
		ids[biome_names[k]] = k + 1

	for k in range(soil_names.size()):
		soil_ids[soil_names[k]] = k + 3

	var soil_base: PackedFloat64Array = PackedFloat64Array()
	soil_base.resize(256)

	for k in range(256):
		soil_base[k] = float(rng.randi_range(150, 255))

	var heights: PackedFloat32Array = PackedFloat32Array()
	var water_class: PackedByteArray = PackedByteArray()
	var moisture_noise: PackedByteArray = PackedByteArray()
	var temperature_noise: PackedByteArray = PackedByteArray()
	heights.resize(side * side)
	water_class.resize(side * side)
	moisture_noise.resize(side * side)
	temperature_noise.resize(side * side)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.004

	for k in range(side * side):
		heights[k] = 450.0 + noise.get_noise_2d(float(k % side), float(floori(float(k) / float(side)))) * 1000.0 + rng.randf() * 0.4
		water_class[k] = 0 if rng.randf() < 0.9 else rng.randi_range(1, 3)
		moisture_noise[k] = rng.randi_range(0, 255)
		temperature_noise[k] = rng.randi_range(0, 255)

	var air: PackedFloat32Array = PackedFloat32Array()
	var fresh: PackedFloat32Array = PackedFloat32Array()
	var ocean: PackedFloat32Array = PackedFloat32Array()
	air.resize(coarse * coarse)
	fresh.resize(coarse * coarse)
	ocean.resize(coarse * coarse)

	for k in range(coarse * coarse):
		air[k] = rng.randf()
		fresh[k] = rng.randf_range(0.0, 900.0)
		ocean[k] = rng.randf_range(0.0, 3000.0)

	var sea_temperature: PackedFloat32Array = PackedFloat32Array()
	var row_wetness: PackedFloat32Array = PackedFloat32Array()
	sea_temperature.resize(side)
	row_wetness.resize(side)

	for j in range(side):
		sea_temperature[j] = rng.randf_range(-12.0, 38.0)
		row_wetness[j] = rng.randf_range(0.2, 0.9)

	var consts: Dictionary = {
		"samples": side, "step": step, "coarse": coarse, "ocean_kind": 1, "lake_kind": 2,
		"lapse": 6.5 / 1000.0, "temperature_amplitude": 1.5, "fresh_bonus": 0.25, "near_fresh": 400.0, "moisture_amplitude": 0.12, "inv_two_spacing": 1.0 / 16.0,
		"rock_tan": tan(deg_to_rad(38.0)), "scree_tan": tan(deg_to_rad(26.0)), "marsh_tan": tan(deg_to_rad(3.0)), "flood_tan": tan(deg_to_rad(6.0)),
		"stony_tan": tan(deg_to_rad(20.0)), "zero_tan": tan(deg_to_rad(34.0)),
		"hot_min": 24.0, "warm_min": 5.0, "cold_min": -3.0, "snow_max": -8.0, "glacier_max": -14.0,
		"peak": 0.55, "width": 0.45, "best_low": 8.0, "best_high": 26.0, "zero_low": -4.0, "zero_high": 38.0,
		"beach_height_m": 2.5, "beach_distance_m": 110.0, "marsh_height_m": 4.0, "marsh_moisture": 0.62, "alpine_min_height_m": 900.0, "boreal_moisture": 0.38,
		"desert_moisture": 0.25, "scrub_moisture": 0.4, "savanna_moisture": 0.58, "grassland_moisture": 0.42, "mixed_moisture": 0.7, "cool_forest_below_c": 12.0,
		"floodplain_distance_m": 110.0, "sand_moisture": 0.3, "clay_moisture": 0.78, "clay_edge_m": 160.0,
	}
	var script_out: Dictionary = ClimateScript.classify_script(consts, ids, soil_ids, soil_base, heights, water_class, air, fresh, ocean, moisture_noise, temperature_noise, sea_temperature, row_wetness)
	var native_out: Dictionary = ClassDB.instantiate("GenCore").classify_climate(consts, ids, soil_ids, soil_base, heights, water_class, air, fresh, ocean, moisture_noise, temperature_noise, sea_temperature, row_wetness)
	var same: bool = true

	for key in ["temperature_c", "moisture", "biome", "soil", "fertility"]:
		same = same and script_out[key] == native_out[key]

	same = same and script_out["biome_counts"] == native_out["biome_counts"] and script_out["soil_counts"] == native_out["soil_counts"] and script_out["fertile_cells"] == native_out["fertile_cells"]
	var kinds: int = 0

	for count in script_out["biome_counts"]:
		if count > 0:
			kinds += 1

	print("climate seed %d: %d biomes hit, %d fertile cells, %s" % [seed_value, kinds, script_out["fertile_cells"], "identical" if same else "DIFFERENT"])
	return 0 if same and kinds >= 7 and script_out["fertile_cells"] > 0 else 1
