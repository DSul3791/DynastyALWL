extends SceneTree

# Watershed rebuild R6 (docs/water/watershed_rebuild_design.md R6 item 5): a tile inside the island water record's window is baked from
# the record. A made-up record of tile 3,4 alone (1,921 samples a side, as record.py writes) holds a slope with a sea strip, a round lake,
# a straight river and a marsh square. The bake must take the ground, the water level, the water class (record codes through the table's
# record_code), the drainage (km2 to 8 m cells) and the distance to fresh water from it, sample for sample, and pack a tile file. It must
# refuse a water code the table lacks and a missing field, and an export bake (raw_only) must still read the world function. It places no
# rule spring cave (the design retires them): R5's spring head becomes a ground spring with bushes over it, its seep does not, and on this
# gentle slope (far under spring_cave.min_slope_deg, no hill behind) the head is never tried as a cave (design R6 as built, "Brooks and caves").
# Drinking water step 2b (docs/design/drinking_water_step2b_design.md): the record's channel rasters (regime, width_m, below_spring_m,
# spring_q, spring_y) on the river, perennial in its upper part with the spring 400 samples above, intermittent below, come through the
# bake into the tile's drink_* sections, and TileTerrainData.drink_row reads them back as brook rows; a record without them has no drink.
#   godot --headless --path . --script res://src/worldgen/tools/test_bake_from_record.gd

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")
const WaterRecordScript := preload("res://src/worldgen/record/water_record.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")

const DIR := "user://test_bake_from_record/record"
const TILE := Vector2i(3, 4)
const S := 1921
const SPRING := Vector2i(1500, 800)                  # R5's spring head, on the open slope
const SEEP := Vector2i(1700, 300)                    # a seep head: no ground spring
const PERENNIAL_I := 1000                            # the river is perennial from here up (i at least this), intermittent below
const BELOW_I := 1400                                # the spring's reach: from here up the river has a governing spring at i = 1900
const SPRING_Q := 0.004                              # that spring's flow, m3/s
const SPRING_Y := 61.5                               # and its height, m
const Q_CPD := 6553.5
const TileTerrainDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func write_json(path: String, value: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(value))
	f.close()


func write_bytes(name: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open("%s/tiles/%d_%d/%s" % [DIR, TILE.x, TILE.y, name], FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


# The made-up island: i along x, j along z, both 0 to S - 1 inside the tile.
func ground_at(i: int, j: int) -> float:
	if i < 100:
		return -5.0                                   # sea
	if (i - 960) * (i - 960) + (j - 400) * (j - 400) <= 3600:
		return 30.0                                   # lake floor
	if absi(j - 1200) <= 2:
		return 38.0                                   # river bed
	return 40.0 + 0.02 * float(j)


func code_at(i: int, j: int) -> int:
	if i < 100:
		return 1
	if (i - 960) * (i - 960) + (j - 400) * (j - 400) <= 3600:
		return 2
	if absi(j - 1200) <= 2:
		return 3
	if i >= 1500 and i <= 1540 and j >= 1600 and j <= 1640:
		return 4                                      # marsh: wet, with no level of its own
	return 0


# The record's drink rasters at a sample, decoded: [regime, width_m, below_spring_m (NAN none), spring_q m3/s (0 none), spring_y m].
func drink_at(i: int, j: int) -> Array:
	if code_at(i, j) != 3 or i < 100:
		return [0, 0.0, NAN, 0.0, 0.0]

	var regime: int = 1 if i >= PERENNIAL_I else 2

	if i < BELOW_I or i > 1900:   # above the spring (i past 1900) nothing feeds it: a negative distance would wrap in the u2 raster
		return [regime, 1.5, NAN, 0.0, 0.0]

	return [regime, 1.5, float(1900 - i) * 8.0, SPRING_Q, SPRING_Y]


func level_at(i: int, j: int) -> float:
	match code_at(i, j):
		1:
			return 0.0
		2:
			return 35.0
		3:
			return 39.0
	return NAN


func write_record() -> void:
	DirAccess.make_dir_recursive_absolute("%s/tiles/%d_%d" % [DIR, TILE.x, TILE.y])
	var ground := PackedFloat32Array()
	var level := PackedFloat32Array()
	var area := PackedFloat32Array()
	var fresh := PackedFloat32Array()
	var codes := PackedByteArray()
	ground.resize(S * S)
	level.resize(S * S)
	area.resize(S * S)
	fresh.resize(S * S)
	codes.resize(S * S)
	var regime := PackedByteArray()
	var width := PackedByteArray()
	var below := PackedByteArray()
	var spring_q := PackedByteArray()
	var spring_y := PackedByteArray()
	regime.resize(S * S)
	width.resize(S * S)
	below.resize(S * S * 2)
	spring_q.resize(S * S * 2)
	spring_y.resize(S * S * 2)
	var q_code: int = roundi((log(SPRING_Q) / log(10.0) + 4.0) * Q_CPD)

	for j in S:
		for i in S:
			var k: int = j * S + i
			var drink: Array = drink_at(i, j)
			regime[k] = int(drink[0])
			width[k] = roundi(float(drink[1]) / 0.1)
			below.encode_u16(k * 2, 65535 if is_nan(float(drink[2])) else roundi(float(drink[2]) / 2.0))
			spring_q.encode_u16(k * 2, q_code if float(drink[3]) > 0.0 else 0)
			spring_y.encode_s16(k * 2, roundi(float(drink[4]) / 0.1))
			ground[k] = ground_at(i, j)
			level[k] = level_at(i, j)
			codes[k] = code_at(i, j)
			area[k] = 0.5 + 0.001 * float(i)
			fresh[k] = 8.0 * float(absi(j - 1200))

	write_bytes("ground.f4", ground.to_byte_array())
	write_bytes("water_level.f4", level.to_byte_array())
	write_bytes("water_class.u1", codes)
	write_bytes("area_km2.f4", area.to_byte_array())
	write_bytes("fresh_m.f4", fresh.to_byte_array())
	write_bytes("regime.u1", regime)
	write_bytes("width_m.u1", width)
	write_bytes("below_spring_m.u2", below)
	write_bytes("spring_q.u2", spring_q)
	write_bytes("spring_y.i2", spring_y)
	write_manifest(true)


# The manifest, with the drink rasters in its field table or without them (a record from before step 2b).
func write_manifest(with_drink: bool) -> void:
	var drink_fields: Array = [{"name": "regime", "type": "u1", "file": "regime.u1"},
		{"name": "width_m", "type": "u1", "file": "width_m.u1", "scale": 0.1, "units": "m"},
		{"name": "below_spring_m", "type": "u2", "file": "below_spring_m.u2", "scale": 2.0, "nodata": 65535, "units": "m"},
		{"name": "spring_q", "type": "u2", "file": "spring_q.u2", "codes_per_decade": Q_CPD, "nodata": 0, "units": "m3/s"},
		{"name": "spring_y", "type": "i2", "file": "spring_y.i2", "scale": 0.1, "units": "m"}]
	var x0: float = float(TILE.x) * 15360.0
	write_json(DIR + "/manifest.json", {"version": 1, "complete": true, "cell_m": 8.0, "origin_x": x0, "origin_z": float(TILE.y) * 15360.0,
		"tile_samples": S, "tiles": [TILE.x, TILE.y, TILE.x, TILE.y], "record_sha": "test",
		"fields": [{"name": "ground", "type": "f4", "file": "ground.f4", "units": "m"},
			{"name": "water_level", "type": "f4", "file": "water_level.f4", "nodata": "NaN"},
			{"name": "water_class", "type": "u1", "file": "water_class.u1"},
			{"name": "area_km2", "type": "f4", "file": "area_km2.f4", "units": "km2"},
			{"name": "fresh_m", "type": "f4", "file": "fresh_m.f4", "units": "m"}] + (drink_fields if with_drink else []),
		"summary": {"missing": [], "later": ["snow window"]}})


func write_network() -> void:
	var x0: float = float(TILE.x) * 15360.0
	var z: float = float(TILE.y) * 15360.0 + 1200.0 * 8.0
	var z0: float = float(TILE.y) * 15360.0
	write_json(DIR + "/network.json", {"reaches": [{"id": 0, "down": -1, "ends": "sea", "area_km2": 50.0,
		"polyline": [[x0 + 1900.0 * 8.0, 39.0, z], [x0 + 100.0 * 8.0, 39.0, z]]}], "lakes": [], "falls": [], "cold_air_pools": [],
		"heads": [{"reach": 0, "kind": "spring", "pos": [x0 + float(SPRING.x) * 8.0, ground_at(SPRING.x, SPRING.y), z0 + float(SPRING.y) * 8.0],
				"lake": -1, "area_km2": 0.4, "q_wet_m3_s": 0.01, "groundwater_m3_s": 0.004, "q_base_dry_m3_s": 0.0015},
			{"reach": 0, "kind": "seep or damp hollow", "pos": [x0 + float(SEEP.x) * 8.0, ground_at(SEEP.x, SEEP.y), z0 + float(SEEP.y) * 8.0],
				"lake": -1, "area_km2": 0.3, "q_wet_m3_s": 0.005, "groundwater_m3_s": 0.001}]})
	write_json(DIR + "/climate.json", {"default": {}, "by_island": {}})


# The baked drink rasters are the record's, sample for sample; the packed drink_* sections, read back by TileTerrainData, give brook rows.
func check_drink(water, packed: Dictionary) -> void:
	var bad: int = 0

	for field in ["regime", "width_m", "below_spring_m", "spring_q", "spring_y"]:
		check(water.drink.get(field, PackedFloat32Array()).size() == S * S, "the bake holds the record's %s" % field)

	if water.drink.get("spring_y", PackedFloat32Array()).size() != S * S:
		return

	for j in range(1190, 1211):
		for i in range(0, S, 3):
			var k: int = j * S + i
			var want: Array = drink_at(i, j)
			var got_below: float = water.drink["below_spring_m"][k]

			if int(water.drink["regime"][k]) != int(want[0]) or (int(want[0]) > 0 and absf(water.drink["width_m"][k] - float(want[1])) > 0.01):
				bad += 1
			elif is_nan(float(want[2])) != is_nan(got_below) or (not is_nan(got_below) and absf(got_below - float(want[2])) > 0.01):
				bad += 1
			elif float(want[3]) > 0.0 and (absf(water.drink["spring_q"][k] - SPRING_Q) > 1.0e-6 or absf(water.drink["spring_y"][k] - SPRING_Y) > 0.01):
				bad += 1

	check(bad == 0, "the drink rasters are the record's (%d samples differ)" % bad)
	var raw: Dictionary = {}

	for section in packed["sections"]:
		if str(section["name"]).begins_with("drink_"):
			raw[str(section["name"])] = section["raw"]

	check(raw.size() == 5, "the tile packs five drink sections (%s)" % str(raw.keys()))
	var tile = TileTerrainDataScript.new()
	tile.samples = S
	tile.load_drink_sections(raw)
	var mean_c: Callable = func(height: float) -> float: return 10.0 - 0.0065 * height
	var near: Dictionary = tile.drink_row(1200 * S + 1500, mean_c)
	check(str(near.get("kind", "")) == "brook" and int(near.get("regime", 0)) == 1 and bool(near.get("dry_ok", false)), "a perennial brook below the spring (%s)" % str(near))
	check(absf(float(near.get("below_spring_m", INF)) - 3200.0) < 0.01 and absf(float(near.get("q_m3_s", 0.0)) - SPRING_Q) < 1.0e-6, "3,200 m below a 4 L/s spring (%s)" % str(near))
	check(absf(float(near.get("width_m", 0.0)) - 1.5) < 0.01 and absf(float(near.get("spring_c", NAN)) - mean_c.call(SPRING_Y)) < 0.001, "1.5 m wide, the spring's water the year mean at its height (%s)" % str(near))
	var low: Dictionary = tile.drink_row(1200 * S + 500, mean_c)
	check(int(low.get("regime", 0)) == 2 and not bool(low.get("dry_ok", true)) and is_inf(float(low.get("below_spring_m", 0.0))) and not low.has("spring_c"),
		"an intermittent brook with no spring above it (%s)" % str(low))
	check(tile.drink_row(500 * S + 500, mean_c).is_empty() and tile.drink_row(1200 * S + 50, mean_c).is_empty(), "no brook off the channels or in the sea")


func open_record(baker) -> String:
	baker.record = WaterRecordScript.new()
	return baker.record.open(DIR)


func _init() -> void:
	var baker = TileBakerScript.new()
	var problem: String = baker.setup("res://worlds/base_world")
	check(problem == "", "setup: " + problem)
	write_record()
	write_network()
	check(open_record(baker) == "", "the made-up record opens")
	check(baker.record_has_drink(), "the record has the drink rasters")
	var ids: PackedByteArray = WaterRecordScript.code_map()
	var result: Dictionary = baker.bake(TILE)
	check(not result.has("error"), "bake from the record: %s" % str(result.get("error", "")))

	if not result.has("error"):
		var water = result["water"]
		check(water.samples == S, "the tile is %d samples a side (got %d)" % [S, water.samples])
		var bad_ground: int = 0
		var bad_class: int = 0
		var bad_surface: int = 0
		var bad_flow: int = 0
		var bad_fresh: int = 0
		var cells_per_km2: float = 1.0e6 / 64.0

		for j in range(0, S, 7):
			for i in range(0, S, 7):
				var k: int = j * S + i

				if absf(water.heights[k] - ground_at(i, j)) > 0.001:
					bad_ground += 1

				if int(water.water_class[k]) != int(ids[code_at(i, j)]):
					bad_class += 1

				var want: float = level_at(i, j) if code_at(i, j) in [1, 2, 3] else ground_at(i, j)

				if code_at(i, j) != 0 and absf(water.water_surface[k] - want) > 0.001:
					bad_surface += 1

				if absf(water.flow[k] - (0.5 + 0.001 * float(i)) * cells_per_km2) > 0.5:
					bad_flow += 1

				if absf(water.fresh_m[k] - 8.0 * float(absi(j - 1200))) > 0.01:
					bad_fresh += 1

		check(bad_ground == 0, "ground is the record's (%d samples differ)" % bad_ground)
		check(bad_class == 0, "water class is the record's code through record_code (%d differ)" % bad_class)
		check(bad_surface == 0, "water surface is the record's level, a marsh at its ground (%d differ)" % bad_surface)
		check(bad_flow == 0, "flow is the drainage area in 8 m cells (%d differ)" % bad_flow)
		check(bad_fresh == 0, "distance to fresh water is the record's (%d differ)" % bad_fresh)
		# The design retires rule-placed spring caves (section 6): a tile from the record places none.
		var spring_caves: int = 0

		for cave in result["sites"].caves:
			if str(cave.get("cave_kind", "")) == "spring_cave":
				spring_caves += 1

		check(not result["sites"].spring_caves and spring_caves == 0, "a tile from the record places no spring cave on gentle ground (%d)" % spring_caves)
		# R5's spring head is a ground spring, where the head is, with bushes over it; the seep is not a spring.
		var springs: Array = result["sites"].ground_springs
		var x_want: float = float(TILE.x) * 15360.0 + float(SPRING.x) * 8.0
		var z_want: float = float(TILE.y) * 15360.0 + float(SPRING.y) * 8.0
		check(springs.size() == 1, "one ground spring from R5's one spring head (%d)" % springs.size())

		if springs.size() == 1:
			var pos: Array = springs[0]["pos"]
			check(absf(float(pos[0]) - x_want) < 0.2 and absf(float(pos[2]) - z_want) < 0.2 and absf(float(pos[1]) - ground_at(SPRING.x, SPRING.y)) < 0.2,
				"the ground spring is at the head (%s)" % str(pos))
			check(str(springs[0]["cover"]) == "bushes" and absf(float(springs[0]["m3_s"]) - 0.004) < 0.0001, "bushes over it, R5's groundwater flow (%s)" % str(springs[0]))
			check(absf(float(springs[0].get("dry_m3_s", -1.0)) - 0.0015) < 0.0001, "and R5's dry-quarter base flow at the head (%s)" % str(springs[0]))

		var packed: Dictionary = TileFileScript.pack_tile(baker.settings, TILE, baker.plan_cell(TILE), water, result["climate"], result["geology"], result["sites"], baker.river_start_cells())
		check(not packed.is_empty(), "the tile packs into a tile file")
		check_drink(water, packed)

	# A record from before step 2b (no drink rasters in its field table) bakes no drink.
	write_manifest(false)
	check(open_record(baker) == "" and not baker.record_has_drink(), "a record without the drink rasters opens and has no drink")
	write_manifest(true)

	# A water code the table lacks stops the bake.
	var codes := PackedByteArray()
	codes.resize(S * S)
	codes.fill(0)
	codes[S * 960 + 960] = 200
	write_bytes("water_class.u1", codes)
	check(open_record(baker) == "", "the record reopens")
	result = baker.bake(TILE)
	check(str(result.get("error", "")).contains("code"), "an unknown water code is refused (%s)" % str(result.get("error", "none")))

	# A missing field stops the bake.
	DirAccess.remove_absolute("%s/tiles/%d_%d/area_km2.f4" % [DIR, TILE.x, TILE.y])
	check(open_record(baker) == "", "the record reopens without area_km2")
	result = baker.bake(TILE)
	check(str(result.get("error", "")).contains("area_km2"), "a missing field is refused (%s)" % str(result.get("error", "none")))

	# An export bake reads the world function, never the record.
	result = baker.bake(TILE, true)
	var raw: PackedFloat32Array = result.get("raw_heights", PackedFloat32Array())
	check(raw.size() == S * S and absf(raw[S * 1500 + 1500] - ground_at(1500, 1500)) > 0.001, "raw_only bakes ignore the record")

	print("test_bake_from_record: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
