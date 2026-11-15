extends SceneTree

# Where the flora placer's time goes (Dave 15 Nov 2026: why test_flora_density runs past 300 s). Read only.
#
#   godot --headless --path . --script res://src/worldgen/tools/flora_profile.gd -- [--part=sections|functions|all]
#
# sections:  the chunk windows test_flora_density placed up to 15 Nov 2026 (it now places the grove window by stand circle and the spawn
#            window trees only), each timed with the plain placer (ms per chunk, items per chunk),
#            plus the test's own loops between them. Prints "SECTION <name> chunks=<n> ms=<total> ms_per_chunk=<x> items=<n>".
# functions: a few full and trees-only chunks through a placer whose inner helpers are wrapped with timers (inclusive time; the
#            wrapping adds its own cost, so use the shares, not the sums). Prints "FUNC <name> calls=<n> ms=<total> us_per_call=<x>".

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

var generator
var tables
var rules: Dictionary


class Timed extends "res://src/worldgen/runtime/flora_placer.gd":
	var stats: Dictionary = {}   # name -> [calls, usec]

	func _add(name: String, t0: int) -> void:
		var row: Array = stats.get(name, [0, 0])
		row[0] += 1
		row[1] += Time.get_ticks_usec() - t0
		stats[name] = row

	func _wet_samples(data, origin: Vector2, brooks: Dictionary = {}) -> Dictionary:
		var t0: int = Time.get_ticks_usec()
		var r: Dictionary = super._wet_samples(data, origin, brooks)
		_add("_wet_samples", t0)
		return r

	func _place_patches(item: Dictionary, data, chunk: Vector2i, origin: Vector2, species_id: int, found: Array) -> void:
		var t0: int = Time.get_ticks_usec()
		super._place_patches(item, data, chunk, origin, species_id, found)
		_add("_place_patches", t0)

	func _ground_ok(item: Dictionary, data, k: int, x: float, z: float, in_belt: bool = false, near_water: float = 0.0) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super._ground_ok(item, data, k, x, z, in_belt, near_water)
		_add("_ground_ok", t0)
		return r

	func _spring_cover(origin: Vector2, data, found: Array) -> void:
		var t0: int = Time.get_ticks_usec()
		super._spring_cover(origin, data, found)
		_add("_spring_cover", t0)

	func _riparian_shrubs(chunk: Vector2i, origin: Vector2, data, wet: Dictionary, brooks: Dictionary, found: Array) -> void:
		var t0: int = Time.get_ticks_usec()
		super._riparian_shrubs(chunk, origin, data, wet, brooks, found)
		_add("_riparian_shrubs", t0)

	func _montane_cells(item: Dictionary, data, chunk: Vector2i, origin: Vector2, species_id: int, rng: RandomNumberGenerator, found: Array, stand_used: Dictionary) -> void:
		var t0: int = Time.get_ticks_usec()
		super._montane_cells(item, data, chunk, origin, species_id, rng, found, stand_used)
		_add("_montane_cells", t0)

	func _edge_m(data, x: float, z: float, cache: Dictionary) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super._edge_m(data, x, z, cache)
		_add("_edge_m", t0)
		return r

	func _beach_rules_ok(item: Dictionary, data, x: float, z: float, cache: Dictionary) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._beach_rules_ok(item, data, x, z, cache)
		_add("_beach_rules_ok", t0)
		return r

	func _wetness(data, wet: Dictionary, x: float, z: float, cache: Dictionary) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super._wetness(data, wet, x, z, cache)
		_add("_wetness", t0)
		return r

	func _wet_extra(item: Dictionary, data, origin: Vector2, species_id: int, cell: float, count: int, cx: int, cz: int, rng_wet: RandomNumberGenerator,
			wet: Dictionary, wet_cache: Dictionary, found: Array) -> void:
		var t0: int = Time.get_ticks_usec()
		super._wet_extra(item, data, origin, species_id, cell, count, cx, cz, rng_wet, wet, wet_cache, found)
		_add("_wet_extra", t0)

	func _shore_ok(item: Dictionary, data, k: int, x: float, z: float) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._shore_ok(item, data, k, x, z)
		_add("_shore_ok", t0)
		return r

	func _slope_at(data, x: float, z: float) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super._slope_at(data, x, z)
		_add("_slope_at", t0)
		return r

	func _near_water(data, x: float, z: float) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._near_water(data, x, z)
		_add("_near_water", t0)
		return r

	func _near_river(data, x: float, z: float) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._near_river(data, x, z)
		_add("_near_river", t0)
		return r

	func _under_water(data, x: float, z: float) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._under_water(data, x, z)
		_add("_under_water", t0)
		return r

	func _ridge_factor(data, x: float, z: float, y: float) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super._ridge_factor(data, x, z, y)
		_add("_ridge_factor", t0)
		return r

	func _mountain_near(data, x: float, z: float, y: float) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super._mountain_near(data, x, z, y)
		_add("_mountain_near", t0)
		return r

	func _plateau(data, x: float, z: float) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super._plateau(data, x, z)
		_add("_plateau", t0)
		return r

	func _groves_near(item: Dictionary, grove: Dictionary, seed: int, species_id: int, origin: Vector2) -> Array:
		var t0: int = Time.get_ticks_usec()
		var r: Array = super._groves_near(item, grove, seed, species_id, origin)
		_add("_groves_near", t0)
		return r

	func _make_room(occupied: Dictionary, x: float, z: float, radius: float, stand: float, species_id: int, kind: int) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._make_room(occupied, x, z, radius, stand, species_id, kind)
		_add("_make_room", t0)
		return r

	func _cleared_at(x: float, z: float, species_id: int) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._cleared_at(x, z, species_id)
		_add("_cleared_at", t0)
		return r

	func _on_sand(data, x: float, z: float) -> bool:
		var t0: int = Time.get_ticks_usec()
		var r: bool = super._on_sand(data, x, z)
		_add("_on_sand", t0)
		return r

	func patch_at(x: float, z: float) -> float:
		var t0: int = Time.get_ticks_usec()
		var r: float = super.patch_at(x, z)
		_add("patch_at", t0)
		return r

	func chunk_items(chunk: Vector2i, trees_only: bool = false) -> Dictionary:
		var t0: int = Time.get_ticks_usec()
		var r: Dictionary = super.chunk_items(chunk, trees_only)
		_add("chunk_items_trees" if trees_only else "chunk_items_full", t0)
		return r


func _init() -> void:
	var part: String = "all"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--part="):
			part = argument.trim_prefix("--part=")

	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var t0: int = Time.get_ticks_msec()
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	rules = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	print("SECTION setup ms=%d errors=%d" % [Time.get_ticks_msec() - t0, errors.size()])
	t0 = Time.get_ticks_msec()
	var data = generator.get_tile(Vector2i(3, 4))
	print("SECTION first_tile ms=%d" % (Time.get_ticks_msec() - t0))

	if part in ["sections", "all"]:
		_sections(data)

	if part in ["functions", "all"]:
		_functions(data)

	print("PROFILE DONE")
	quit(0)


func _window(placer, name: String, chunks: Array, trees_only: bool) -> Array:
	var t0: int = Time.get_ticks_msec()
	var items: int = 0
	var slowest: int = 0
	var made_all: Array = []

	for c in chunks:
		var t1: int = Time.get_ticks_msec()
		var made: Dictionary = placer.chunk_items(c, trees_only)
		slowest = maxi(slowest, Time.get_ticks_msec() - t1)
		items += made["ids"].size()
		made_all.append(made)

	var ms: int = Time.get_ticks_msec() - t0
	print("SECTION %s chunks=%d ms=%d ms_per_chunk=%.1f slowest_ms=%d items=%d items_per_chunk=%.0f" % [name, chunks.size(), ms, float(ms) / float(maxi(chunks.size(), 1)), slowest, items, float(items) / float(maxi(chunks.size(), 1))])
	return made_all


func _sections(data) -> void:
	var placer = PlacerScript.new()
	var t0: int = Time.get_ticks_msec()
	placer.setup(generator, tables, rules)
	print("SECTION placer_setup ms=%d" % (Time.get_ticks_msec() - t0))

	# 1. test_flora_density's density sample: every 7th chunk of the starter tile (9 x 9).
	var sample: Array = []

	for cz in range(0, 60, 7):
		for cx in range(0, 60, 7):
			sample.append(placer.chunk_of(data.x0 + float(cx) * 256.0 + 1.0, data.z0 + float(cz) * 256.0 + 1.0))

	_window(placer, "density_sample_full", sample, false)

	# 2. The thicket window (5 x 5 full).
	var thicket: Array = []
	var origin_chunk: Vector2i = placer.chunk_of(53301.0, 68427.0)

	for cj in range(-2, 3):
		for ci in range(-2, 3):
			thicket.append(Vector2i(origin_chunk.x + ci, origin_chunk.y + cj))

	_window(placer, "thicket_full", thicket, false)

	# 3. The fruit grove window (24 x 24 trees only).
	var groves: Array = []
	var corner: Vector2i = placer.chunk_of(3.0 * 15360.0 + 2000.0, 4.0 * 15360.0 + 2000.0)

	for cz in range(24):
		for cx in range(24):
			groves.append(Vector2i(corner.x + cx, corner.y + cz))

	var held: Array = _window(placer, "groves_trees_only", groves, true)
	t0 = Time.get_ticks_msec()
	var fruit: int = 0

	for made in held:
		for n in range(made["ids"].size()):
			if str(placer.species_of(made["ids"][n]).get("name", "")) in ["apple_early", "apple_summer", "pear_summer", "sour_cherry"]:
				fruit += 1

	print("SECTION groves_scan ms=%d fruit_trees=%d" % [Time.get_ticks_msec() - t0, fruit])

	# 4. The young-conifer window round the spawn (7 x 7 full).
	var spawn_xz: Vector2 = load("res://src/shared/spawn_point.gd").OVERRIDE
	var spawn_chunk: Vector2i = placer.chunk_of(spawn_xz.x, spawn_xz.y)
	var near: Array = []

	for dz in range(-3, 4):
		for dx in range(-3, 4):
			near.append(Vector2i(spawn_chunk.x + dx, spawn_chunk.y + dz))

	_window(placer, "spawn_full", near, false)

	# The same 49 spawn chunks again, trees only, and the grove window's first 49 chunks in full: what the two forms cost on the same ground.
	_window(placer, "spawn_trees_only", near, true)
	_window(placer, "groves_first49_full", groves.slice(0, 49), false)


func _functions(data) -> void:
	var placer = Timed.new()
	placer.setup(generator, tables, rules)
	var spawn_xz: Vector2 = load("res://src/shared/spawn_point.gd").OVERRIDE
	var spawn_chunk: Vector2i = placer.chunk_of(spawn_xz.x, spawn_xz.y)
	var t0: int = Time.get_ticks_msec()

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			placer.chunk_items(Vector2i(spawn_chunk.x + dx, spawn_chunk.y + dz), false)

	var corner: Vector2i = placer.chunk_of(3.0 * 15360.0 + 2000.0, 4.0 * 15360.0 + 2000.0)

	for cz in range(4):
		for cx in range(6):
			placer.chunk_items(Vector2i(corner.x + cx, corner.y + cz), true)

	print("SECTION functions_run ms=%d (9 full spawn chunks, 24 trees-only grove chunks, timers on)" % (Time.get_ticks_msec() - t0))
	var names: Array = placer.stats.keys()
	names.sort_custom(func(a, b): return int(placer.stats[a][1]) > int(placer.stats[b][1]))

	for name in names:
		var row: Array = placer.stats[name]
		print("FUNC %s calls=%d ms=%.1f us_per_call=%.1f" % [name, row[0], float(row[1]) / 1000.0, float(row[1]) / float(maxi(row[0], 1))])
