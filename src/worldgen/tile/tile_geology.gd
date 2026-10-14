class_name TileGeology
extends RefCounted

# Geology and ore for one tile (design Section 4.9, format spec Section 6b).
#
# Provinces are irregular regions about 3.8 km across. The world is cut
# into a grid of cells (four per tile edge), each cell has one jittered
# seed point, and every place belongs to the nearest seed after a gentle
# warp. Everything about a cell (kind, rock layers, folds, features, ore)
# comes from a random generator seeded by the cell alone, so neighboring
# tiles agree exactly and a tile can be rebuilt on its own.
#
# A province's kind comes from the geology of the sketch feature under it
# (shelves: granite, basin, fold belt; arcs: volcanic, granite; hotspots
# and open ocean: volcanic). A smooth noise picks among those kinds so
# neighboring cells often share a kind.
#
# Per-sample maps (8 m grid, same as the height map):
#   province      index into `provinces`
#   cover         loose material above bedrock, raw x 0.25 m
#   layer_offset  vertical shift of the rock layers, raw x 0.1 m (folds, basin sag)
#   surface_rock  rock id at the bedrock surface (reports and previews only)
#
# Lists: provinces, features (intrusions, faults, vents, pipes, salt
# domes) and ore bodies. Features and ore bodies carry a home tile and a
# local id that never change; placer deposits are found per tile from the
# rivers and belong to the tile they lie in.

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const OCEAN := 1
const LAKE := 2
const RIVER := 3

const KIND_CODES := {"granite": 0, "basin": 1, "fold_belt": 2, "volcanic": 3}
const ROCK_DENSITY_T_M3 := 2.7

var samples: int = 0
var tile_origin: Vector2 = Vector2.ZERO
var spacing_m: float = 8.0
var province: PackedByteArray = PackedByteArray()
var cover: PackedByteArray = PackedByteArray()
var layer_offset: PackedInt32Array = PackedInt32Array()
var surface_rock: PackedByteArray = PackedByteArray()
var provinces: Array = []
var features: Array = []
var ore_bodies: Array = []
var timings: Dictionary = {}
var placer_sources: int = 0      # gold and tin bodies that reach the ground in this tile
var outcrop_cells: Dictionary = {}      # rock name -> cells at the bedrock surface

var _settings
var _rules: Dictionary = {}
var _tables
var _elevation
var _master: int = 0
var _per_tile: int = 4
var _cell_m: float = 3840.0
var _world_cells_x: int = 84
var _world_cells_z: int = 84
var _min_cell: int = -40
var _cells: Dictionary = {}
var _seeds: Dictionary = {}
var _rock_ids: Dictionary = {}
var _rock_names: Dictionary = {}
var _feature_geology: Array = []        # per elevation owner index: Array of kinds

# Seamless world noise (bytes on a coarse grid) for the warp and the kind choice.
var _noise_cell_m: float = 320.0
var _noise_size_x: int = 0
var _noise_size_z: int = 0
var _warp_x: PackedByteArray
var _warp_z: PackedByteArray
var _kind_field: PackedByteArray


func setup(settings, rules: Dictionary, tables, elevation, sketch: Dictionary) -> void:
	_settings = settings
	_rules = rules["geology"]
	_tables = tables
	_elevation = elevation
	_master = settings.master_seed
	spacing_m = float(settings.map_spacing_m)
	_per_tile = int(_rules["province_cells_per_tile"])
	_cell_m = float(settings.tile_size_m) / float(_per_tile)
	_world_cells_x = settings.tiles_x * _per_tile
	_world_cells_z = settings.tiles_z * _per_tile
	_min_cell = settings.min_tile * _per_tile
	_cells = {}

	for entry in tables.get_entries("rocks"):
		_rock_ids[str(entry["name"])] = int(entry["id"])
		_rock_names[int(entry["id"])] = str(entry["name"])

	# Geology kinds for each elevation owner (feature) index.
	_feature_geology = []

	for feature_id in elevation.feature_ids:
		var kinds: Array = ["volcanic"]

		for feature in sketch.get("features", []):
			if str(feature["id"]) == str(feature_id) and feature.has("geology") and not feature["geology"].is_empty():
				kinds = feature["geology"].duplicate()

		_feature_geology.append(kinds)

	_noise_cell_m = float(_rules["noise_cell_m"])
	_noise_size_x = int(round(float(settings.tiles_x * settings.tile_size_m) / _noise_cell_m))
	_noise_size_z = int(round(float(settings.tiles_z * settings.tile_size_m) / _noise_cell_m))
	var warp_wavelength: float = float(_rules["province_warp_wavelength_m"])
	_warp_x = _seamless("geology_warp_x", warp_wavelength, 2)
	_warp_z = _seamless("geology_warp_z", warp_wavelength, 2)
	_kind_field = _seamless("geology_kind", float(_rules["kind_wavelength_m"]), 2)


# heights: finished 8 m height map. water_class, flow: from TileWater.
# soil: soil ids from TileClimate (for cover depth).
func build(tile: Vector2i, heights: PackedFloat32Array, water_class: PackedByteArray, flow: PackedFloat32Array, soil: PackedByteArray) -> void:
	samples = int(round(sqrt(float(heights.size()))))
	var total: int = samples * samples
	var tile_m: float = float(_settings.tile_size_m)
	var x0: float = float(tile.x) * tile_m
	var z0: float = float(tile.y) * tile_m
	tile_origin = Vector2(x0, z0)

	var clock: int = Time.get_ticks_msec()
	_assign_provinces(tile, x0, z0)
	timings["provinces"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	_collect_lists(tile, x0, z0)
	timings["lists"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	_compute_offsets(x0, z0)
	timings["offsets"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	_compute_cover(heights, water_class, soil, tile)
	timings["cover"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	_compute_surface_rock(heights, x0, z0)
	timings["surface_rock"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	_find_placers(tile, heights, water_class, flow, x0, z0)
	timings["placers"] = Time.get_ticks_msec() - clock

	outcrop_cells = {}
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(256)

	for index in range(total):
		counts[surface_rock[index]] += 1

	for rock_id in _rock_names.keys():
		if counts[rock_id] > 0:
			outcrop_cells[_rock_names[rock_id]] = counts[rock_id]


# ==================================================
# PROVINCES
# ==================================================

func _assign_provinces(_tile: Vector2i, x0: float, z0: float) -> void:
	var step: int = maxi(int(round(float(_rules["compute_cell_m"]) / spacing_m)), 1)
	var coarse: int = (samples - 1) / step + 1
	var coarse_m: float = float(step) * spacing_m
	var warp_m: float = float(_rules["province_warp_m"])
	var tile_m: float = float(_settings.tile_size_m)

	# Warp on a 64 m grid, read back bilinearly.
	var warp_step: float = 64.0
	var warp_size: int = int(tile_m / warp_step) + 2
	var warp_x: PackedFloat32Array = PackedFloat32Array()
	var warp_z: PackedFloat32Array = PackedFloat32Array()
	warp_x.resize(warp_size * warp_size)
	warp_z.resize(warp_size * warp_size)

	for row in range(warp_size):
		for column in range(warp_size):
			var x: float = x0 + float(column) * warp_step
			var z: float = z0 + float(row) * warp_step
			warp_x[row * warp_size + column] = warp_m * _noise_value(_warp_x, x, z)
			warp_z[row * warp_size + column] = warp_m * _noise_value(_warp_z, x, z)

	# Seed points of every cell the warped samples can reach.
	var reach: float = warp_m + _cell_m
	var cx0: int = int(floor((x0 - reach) / _cell_m)) - 1
	var cz0: int = int(floor((z0 - reach) / _cell_m)) - 1
	var span: int = int(ceil((tile_m + 2.0 * reach) / _cell_m)) + 3
	var seed_x: PackedFloat32Array = PackedFloat32Array()
	var seed_z: PackedFloat32Array = PackedFloat32Array()
	seed_x.resize(span * span)
	seed_z.resize(span * span)

	for b in range(span):
		for a in range(span):
			var point: Vector2 = _seed_point(cx0 + a, cz0 + b)
			seed_x[b * span + a] = point.x
			seed_z[b * span + a] = point.y

	var cell_of: PackedInt32Array = PackedInt32Array()
	cell_of.resize(span * span)
	cell_of.fill(-1)
	var coarse_province: PackedInt32Array = PackedInt32Array()
	coarse_province.resize(coarse * coarse)
	provinces = []
	var inv_cell: float = 1.0 / _cell_m
	var inv_warp: float = 1.0 / warp_step

	for row in range(coarse):
		var z: float = z0 + float(row) * coarse_m
		var wv: float = (z - z0) * inv_warp
		var wr: int = mini(int(wv), warp_size - 2)
		var tv: float = wv - float(wr)

		for column in range(coarse):
			var x: float = x0 + float(column) * coarse_m
			var wu: float = (x - x0) * inv_warp
			var wc: int = mini(int(wu), warp_size - 2)
			var tu: float = wu - float(wc)
			var w: int = wr * warp_size + wc
			var wx: float = x + lerpf(lerpf(warp_x[w], warp_x[w + 1], tu), lerpf(warp_x[w + warp_size], warp_x[w + warp_size + 1], tu), tv)
			var wz: float = z + lerpf(lerpf(warp_z[w], warp_z[w + 1], tu), lerpf(warp_z[w + warp_size], warp_z[w + warp_size + 1], tu), tv)
			var a0: int = int(floor(wx * inv_cell)) - cx0
			var b0: int = int(floor(wz * inv_cell)) - cz0
			var best: int = -1
			var best_distance: float = INF

			for b in range(b0 - 1, b0 + 2):
				for a in range(a0 - 1, a0 + 2):
					var k: int = b * span + a
					var dx: float = seed_x[k] - wx
					var dz: float = seed_z[k] - wz
					var distance: float = dx * dx + dz * dz

					if distance < best_distance:
						best_distance = distance
						best = k

			if cell_of[best] < 0:
				cell_of[best] = provinces.size()
				provinces.append(_cell(cx0 + best % span, cz0 + best / span))

			coarse_province[row * coarse + column] = cell_of[best]

	# 8 m map: each sample takes the 16 m sample at or just before it in
	# world terms, which is the same choice on both sides of a tile edge.
	province.resize(samples * samples)

	for j in range(samples):
		var row: int = mini(j / step, coarse - 1)

		for i in range(samples):
			province[j * samples + i] = coarse_province[row * coarse + mini(i / step, coarse - 1)]


func _canonical(cx: int, cz: int) -> Vector2i:
	return Vector2i(
		posmod(cx - _min_cell, _world_cells_x) + _min_cell,
		posmod(cz - _min_cell, _world_cells_z) + _min_cell
	)


func _seed_point(cx: int, cz: int) -> Vector2:
	var cache_key: Vector2i = Vector2i(cx, cz)

	if _seeds.has(cache_key):
		return _seeds[cache_key]

	var canonical: Vector2i = _canonical(cx, cz)
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "geology_seed", canonical.x, canonical.y)
	var jitter: float = float(_rules["province_jitter"])
	var point: Vector2 = Vector2(
		(float(cx) + 0.5 + (rng.randf() - 0.5) * jitter) * _cell_m,
		(float(cz) + 0.5 + (rng.randf() - 0.5) * jitter) * _cell_m
	)
	_seeds[cache_key] = point
	return point


# Everything about one province cell. Positions are in world meters for
# this (possibly unwrapped) cell index.
func _cell(cx: int, cz: int) -> Dictionary:
	var cache_key: Vector2i = Vector2i(cx, cz)

	if _cells.has(cache_key):
		return _cells[cache_key]

	var canonical: Vector2i = _canonical(cx, cz)
	var home: Vector2i = Vector2i(floori(float(canonical.x) / float(_per_tile)), floori(float(canonical.y) / float(_per_tile)))
	var local_cell: int = posmod(canonical.x, _per_tile) * _per_tile + posmod(canonical.y, _per_tile)
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "geology_cell", canonical.x, canonical.y)
	var seed_point: Vector2 = _seed_point(cx, cz)
	var hints: Array = _cell_hints(cx, cz)
	var pick: float = clampf((_noise01(_kind_field, seed_point.x, seed_point.y) - 0.3) / 0.4, 0.0, 0.999)
	var kind: String = str(hints[int(pick * float(hints.size()))])

	var stack_rules: Dictionary = _rules["stacks"][kind]
	var layers: Array = []
	var depth: float = 0.0

	for layer in stack_rules["layers"]:
		var thickness: float = rng.randf_range(float(layer[1]), float(layer[2]))

		# Optional layers (minimum 0) are left out when thin.
		if float(layer[1]) <= 0.0 and thickness < float(_rules["min_layer_m"]):
			continue

		layers.append({"rock": str(layer[0]), "top_m": depth, "thickness_m": snappedf(thickness, 0.1)})
		depth += thickness

	# The layers start just above the highest ground in the cell (the rock
	# above has been worn away), so valleys and coasts cut into deeper layers.
	var highest: float = -INF

	for b in range(5):
		for a in range(5):
			highest = maxf(highest, _elevation.height_at_m(
				(float(cx) + (float(a) + 0.5) / 5.0) * _cell_m, (float(cz) + (float(b) + 0.5) / 5.0) * _cell_m
			))

	var datum: float = maxf(highest, 0.0) + rng.randf_range(float(_rules["datum_above_m"][0]), float(_rules["datum_above_m"][1]))
	var fold: Dictionary = {}
	var fold_rules: Dictionary = _rules["folds"]

	if kind == "basin":
		fold = {"sag_m": rng.randf_range(float(fold_rules["basin"]["sag_m"][0]), float(fold_rules["basin"]["sag_m"][1]))}
	elif fold_rules.has(kind):
		var angle: float = rng.randf() * TAU
		fold = {
			"amplitude_m": rng.randf_range(float(fold_rules[kind]["amplitude_m"][0]), float(fold_rules[kind]["amplitude_m"][1])),
			"wavelength_m": rng.randf_range(float(fold_rules[kind]["wavelength_m"][0]), float(fold_rules[kind]["wavelength_m"][1])),
			"direction": [cos(angle), sin(angle)],
			"phase": rng.randf() * TAU,
		}

	var cell: Dictionary = {
		"id": "%d,%d#%d" % [home.x, home.y, local_cell],
		"home_tile": [home.x, home.y],
		"local_id": local_cell,
		"cell": [canonical.x, canonical.y],
		"kind": kind,
		"hints": hints,
		"seed_point": [snappedf(seed_point.x, 0.1), snappedf(seed_point.y, 0.1)],
		"datum_m": snappedf(datum, 0.1),
		"layers": layers,
		"cycle_m": snappedf(depth, 0.1),
		"repeat_to_m": float(stack_rules.get("repeat_to_m", 0.0)),
		"base_rock": str(stack_rules["base"]),
		"fold": fold,
	}

	var made: Dictionary = _make_features(cell, rng, seed_point, home, local_cell)
	cell["features"] = made["features"]
	cell["ores"] = made["ores"]
	_cells[cache_key] = cell
	return cell


# Geology kinds of the sketch feature that covers most of the cell.
func _cell_hints(cx: int, cz: int) -> Array:
	var counts: Dictionary = {}

	for b in range(3):
		for a in range(3):
			var x: float = (float(cx) + (float(a) + 0.5) / 3.0) * _cell_m
			var z: float = (float(cz) + (float(b) + 0.5) / 3.0) * _cell_m
			var column: int = int(floor((x - _elevation.origin_x) / _elevation.cell_m))
			var row: int = int(floor((z - _elevation.origin_z) / _elevation.cell_m))
			var owner: int = _elevation.owners[_elevation.index_of(column, row)]

			if owner >= 0:
				counts[owner] = int(counts.get(owner, 0)) + 1

	var best_owner: int = -1
	var best_count: int = 0
	var owners: Array = counts.keys()
	owners.sort()

	for owner in owners:
		if int(counts[owner]) > best_count:
			best_count = int(counts[owner])
			best_owner = int(owner)

	if best_owner < 0 or best_owner >= _feature_geology.size():
		return ["volcanic"]

	return _feature_geology[best_owner]


# ==================================================
# FEATURES AND ORE BODIES
# ==================================================

func _make_features(cell: Dictionary, rng: RandomNumberGenerator, seed_point: Vector2, home: Vector2i, local_cell: int) -> Dictionary:
	var kind: String = cell["kind"]
	var rules: Dictionary = _rules["features"]
	var ore_rules: Dictionary = _rules["ores"]
	var made_features: Array = []
	var ores: Array = []
	var counter: Array = [0]
	var ore_counter: Array = [0]
	var arc: bool = kind == "volcanic" and cell["hints"].has("granite")

	var new_id = func(list_counter: Array) -> Dictionary:
		list_counter[0] += 1
		var local: int = local_cell * 100 + list_counter[0]
		return {"id": "%d,%d#%d" % [home.x, home.y, local], "home_tile": [home.x, home.y], "local_id": local}

	var random_point = func(spread: float) -> Vector2:
		var angle: float = rng.randf() * TAU
		var distance: float = sqrt(rng.randf()) * spread * _cell_m
		return seed_point + Vector2(cos(angle), sin(angle)) * distance

	# Intrusions: plutons and smaller stocks.
	var intrusions: Array = []
	var pluton_count: int = _count(rng, rules["pluton"], kind)
	var stock_count: int = _count(rng, rules["stock"], kind)

	if kind == "volcanic":
		stock_count = 1 if rng.randf() < float(rules["stock"]["volcanic_arc_chance" if arc else "volcanic_chance"]) else 0

	for n in range(pluton_count + stock_count):
		var size_name: String = "pluton" if n < pluton_count else "stock"
		var r: Dictionary = rules[size_name]
		var center: Vector2 = random_point.call(0.25 if size_name == "pluton" else 0.4)
		var radius: float = rng.randf_range(float(r["radius_m"][0]), float(r["radius_m"][1]))
		var surface: float = _elevation.height_at_m(center.x, center.y)
		var top: float = surface - _burial(rng, surface)
		var feature: Dictionary = new_id.call(counter)
		feature.merge({
			"type": "intrusion",
			"size": size_name,
			"rock": "granite",
			"center": [snappedf(center.x, 0.1), snappedf(center.y, 0.1)],
			"radius_a_m": snappedf(radius, 0.1),
			"radius_b_m": snappedf(radius * rng.randf_range(float(r["aspect"][0]), float(r["aspect"][1])), 0.1),
			"angle": snappedf(rng.randf() * PI, 0.001),
			"top_y": snappedf(top, 0.1),
			"roof_drop_m": snappedf(rng.randf_range(float(r["roof_drop_m"][0]), float(r["roof_drop_m"][1])), 0.1),
			"bottom_y": snappedf(top - rng.randf_range(float(r["depth_m"][0]), float(r["depth_m"][1])), 0.1),
		})
		made_features.append(feature)
		intrusions.append(feature)

	# Faults.
	for n in range(_count(rng, rules["fault"], kind)):
		var r: Dictionary = rules["fault"]
		var center: Vector2 = random_point.call(0.45)
		var angle: float = rng.randf() * PI
		var half: float = 0.5 * rng.randf_range(float(r["length_m"][0]), float(r["length_m"][1]))
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var a: Vector2 = center - direction * half
		var b: Vector2 = center + direction * half
		var surface: float = maxf(_elevation.height_at_m(center.x, center.y), 0.0)
		var feature: Dictionary = new_id.call(counter)
		feature.merge({
			"type": "fault",
			"points": [[snappedf(a.x, 0.1), snappedf(a.y, 0.1)], [snappedf(b.x, 0.1), snappedf(b.y, 0.1)]],
			"dip_deg": snappedf(rng.randf_range(float(r["dip_deg"][0]), float(r["dip_deg"][1])), 0.1),
			"dip_side": 1 if rng.randf() < 0.5 else -1,
			"width_m": snappedf(rng.randf_range(float(r["width_m"][0]), float(r["width_m"][1])), 0.1),
			"bottom_y": snappedf(surface - rng.randf_range(float(r["depth_m"][0]), float(r["depth_m"][1])), 0.1),
		})
		made_features.append(feature)

		# Gold or silver vein along part of the fault.
		if rng.randf() < float(ore_rules["vein_chance"]):
			var length: float = minf(rng.randf_range(float(ore_rules["vein_length_m"][0]), float(ore_rules["vein_length_m"][1])), half * 2.0)
			var start: float = rng.randf_range(0.0, half * 2.0 - length)
			var p: Vector2 = a + direction * start
			var q: Vector2 = p + direction * length
			var middle: Vector2 = (p + q) * 0.5
			var vein_surface: float = _elevation.height_at_m(middle.x, middle.y)
			var top: float = vein_surface - _burial(rng, vein_surface)
			var width: float = rng.randf_range(float(ore_rules["vein_width_m"][0]), float(ore_rules["vein_width_m"][1]))
			var extent: float = rng.randf_range(float(ore_rules["vein_depth_m"][0]), float(ore_rules["vein_depth_m"][1]))
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": _weighted(rng, ore_rules["vein_resources"]),
				"shape": "vein",
				"feature": feature["id"],
				"points": [[snappedf(p.x, 0.1), snappedf(p.y, 0.1)], [snappedf(q.x, 0.1), snappedf(q.y, 0.1)]],
				"dip_deg": feature["dip_deg"],
				"dip_side": feature["dip_side"],
				"width_m": snappedf(width, 0.01),
				"top_y": snappedf(top, 0.1),
				"bottom_y": snappedf(top - extent, 0.1),
				"grade": snappedf(rng.randf_range(0.3, 1.0), 0.01),
				"tonnes": int(length * width * extent * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

	# Volcanic vents and pipes.
	for n in range(_count(rng, rules["vent"], kind)):
		var r: Dictionary = rules["vent"]
		var center: Vector2 = random_point.call(0.45)
		var surface: float = _elevation.height_at_m(center.x, center.y)
		var radius: float = rng.randf_range(float(r["radius_m"][0]), float(r["radius_m"][1]))
		var feature: Dictionary = new_id.call(counter)
		feature.merge({
			"type": "volcanic_vent",
			"rock": "basalt",
			"center": [snappedf(center.x, 0.1), snappedf(center.y, 0.1)],
			"radius_m": snappedf(radius, 0.1),
			"top_y": snappedf(surface, 0.1),
			"bottom_y": snappedf(surface - rng.randf_range(float(r["depth_m"][0]), float(r["depth_m"][1])), 0.1),
		})
		made_features.append(feature)

		if rng.randf() < float(ore_rules["sulfur_chance"]):
			var thickness: float = rng.randf_range(float(ore_rules["sulfur_thickness_m"][0]), float(ore_rules["sulfur_thickness_m"][1]))
			var halo_radius: float = radius * 1.6
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": "sulfur", "shape": "halo", "feature": feature["id"],
				"center": feature["center"], "radius_a_m": snappedf(halo_radius, 0.1), "radius_b_m": snappedf(halo_radius, 0.1),
				"angle": 0.0, "top_y": feature["top_y"], "thickness_m": snappedf(thickness, 0.1),
				"grade": snappedf(rng.randf_range(0.3, 0.9), 0.01),
				"tonnes": int(PI * (halo_radius * halo_radius - radius * radius) * thickness * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

	# Lenses in the volcanic rock around a vent: opal, and alum where hot
	# gases have altered the rock.
	for feature in made_features:
		if str(feature["type"]) != "volcanic_vent":
			continue

		for lens in ore_rules["vent_lenses"]:
			if rng.randf() >= float(lens["chance"]):
				continue

			var angle: float = rng.randf() * TAU
			var spot: Vector2 = Vector2(float(feature["center"][0]), float(feature["center"][1])) \
				+ Vector2(cos(angle), sin(angle)) * float(feature["radius_m"]) * rng.randf_range(1.5, 3.0)
			var size: float = rng.randf_range(float(lens["size_m"][0]), float(lens["size_m"][1]))
			var y: float = _elevation.height_at_m(spot.x, spot.y) - rng.randf_range(10.0, 120.0)
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": str(lens["resource"]), "shape": "lens", "feature": feature["id"],
				"center": [snappedf(spot.x, 0.1), snappedf(y, 0.1), snappedf(spot.y, 0.1)],
				"radius_a_m": snappedf(size, 0.1), "radius_b_m": snappedf(size * 0.6, 0.1), "angle": snappedf(angle, 0.001),
				"thickness_m": snappedf(size * 0.15, 0.1),
				"grade": snappedf(rng.randf_range(0.1, 0.5), 0.01),
				"tonnes": int(PI * size * size * 0.6 * size * 0.15 * 0.66 * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

	for n in range(_count(rng, rules["pipe"], kind)):
		var r: Dictionary = rules["pipe"]
		var center: Vector2 = random_point.call(0.45)
		var surface: float = _elevation.height_at_m(center.x, center.y)
		var radius: float = rng.randf_range(float(r["radius_m"][0]), float(r["radius_m"][1]))
		var top: float = surface - rng.randf_range(float(r["burial_m"][0]), float(r["burial_m"][1]))
		var bottom: float = top - rng.randf_range(float(r["depth_m"][0]), float(r["depth_m"][1]))
		var feature: Dictionary = new_id.call(counter)
		feature.merge({
			"type": "volcanic_pipe", "rock": "basalt",
			"center": [snappedf(center.x, 0.1), snappedf(center.y, 0.1)],
			"radius_m": snappedf(radius, 0.1), "top_y": snappedf(top, 0.1), "bottom_y": snappedf(bottom, 0.1),
		})
		made_features.append(feature)

		if rng.randf() < float(ore_rules["pipe_gem_chance"]):
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": _weighted(rng, ore_rules["pipe_gems"]), "shape": "pipe", "feature": feature["id"],
				"center": feature["center"], "radius_m": feature["radius_m"],
				"top_y": feature["top_y"], "bottom_y": feature["bottom_y"],
				"grade": snappedf(rng.randf_range(0.1, 0.6), 0.01),
				"tonnes": int(PI * radius * radius * (top - bottom) * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

	# Salt domes.
	for n in range(_count(rng, rules["salt_dome"], kind)):
		var r: Dictionary = rules["salt_dome"]
		var center: Vector2 = random_point.call(0.4)
		var surface: float = _elevation.height_at_m(center.x, center.y)
		var radius: float = rng.randf_range(float(r["radius_m"][0]), float(r["radius_m"][1]))
		var top: float = surface - rng.randf_range(float(r["burial_m"][0]), float(r["burial_m"][1]))
		var feature: Dictionary = new_id.call(counter)
		feature.merge({
			"type": "salt_dome",
			"center": [snappedf(center.x, 0.1), snappedf(center.y, 0.1)],
			"radius_m": snappedf(radius, 0.1), "top_y": snappedf(top, 0.1),
		})
		made_features.append(feature)
		var ore: Dictionary = new_id.call(ore_counter)
		ore.merge({
			"resource": str(ore_rules["salt_dome_resource"]), "shape": "pipe", "feature": feature["id"],
			"center": feature["center"], "radius_m": feature["radius_m"],
			"top_y": feature["top_y"], "bottom_y": snappedf(top - 1500.0, 0.1),
			"grade": snappedf(rng.randf_range(0.6, 1.0), 0.01),
			"tonnes": int(PI * radius * radius * 1500.0 * 2.2),
		})
		ores.append(ore)

	# Bitumen (natural tar) seeps up beside salt domes and here and there in
	# basins, reaching the surface as a tar pit.
	if kind == "basin":
		var seep_rules: Dictionary = ore_rules["seep"]
		var seeps: Array = []

		for feature in made_features:
			if str(feature["type"]) == "salt_dome" and rng.randf() < float(seep_rules["dome_chance"]):
				var angle: float = rng.randf() * TAU
				seeps.append([Vector2(float(feature["center"][0]), float(feature["center"][1]))
					+ Vector2(cos(angle), sin(angle)) * float(feature["radius_m"]) * 1.2, feature["id"]])

		if rng.randf() < float(seep_rules["basin_chance"]):
			seeps.append([random_point.call(0.45), ""])

		for seep in seeps:
			var spot: Vector2 = seep[0]
			var radius: float = rng.randf_range(float(seep_rules["radius_m"][0]), float(seep_rules["radius_m"][1]))
			var surface: float = _elevation.height_at_m(spot.x, spot.y)
			var depth: float = rng.randf_range(float(seep_rules["depth_m"][0]), float(seep_rules["depth_m"][1]))
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": "bitumen", "shape": "pipe", "feature": seep[1],
				"center": [snappedf(spot.x, 0.1), snappedf(spot.y, 0.1)], "radius_m": snappedf(radius, 0.1),
				"top_y": snappedf(surface + 5.0, 0.1), "bottom_y": snappedf(surface - depth, 0.1),
				"grade": snappedf(rng.randf_range(0.3, 0.9), 0.01),
				"tonnes": int(PI * radius * radius * depth * 1.1),
			})
			ores.append(ore)

	# Ore around the intrusions.
	var limestone: Dictionary = {}

	for layer in cell["layers"]:
		if str(layer["rock"]) == "limestone" and limestone.is_empty():
			limestone = layer

	for feature in intrusions:
		var center: Vector2 = Vector2(float(feature["center"][0]), float(feature["center"][1]))
		var ra: float = float(feature["radius_a_m"])
		var rb: float = float(feature["radius_b_m"])
		var top: float = float(feature["top_y"])

		# Tin on the roof of plutons.
		if str(feature["size"]) == "pluton" and rng.randf() < float(ore_rules["tin_roof_chance"]):
			var thickness: float = rng.randf_range(float(ore_rules["tin_thickness_m"][0]), float(ore_rules["tin_thickness_m"][1]))
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": "tin", "shape": "halo", "feature": feature["id"],
				"center": feature["center"], "radius_a_m": snappedf(ra * 0.8, 0.1), "radius_b_m": snappedf(rb * 0.8, 0.1),
				"angle": feature["angle"], "top_y": snappedf(top + thickness * 0.5, 0.1), "thickness_m": snappedf(thickness, 0.1),
				"grade": snappedf(rng.randf_range(0.3, 0.8), 0.01),
				"tonnes": int(PI * ra * rb * 0.64 * thickness * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

		# Copper halo around stocks (and some gold in volcanic arcs).
		if str(feature["size"]) == "stock" and rng.randf() < float(ore_rules["copper_halo_chance"]):
			var scale: float = float(ore_rules["copper_halo_scale"])
			var thickness: float = rng.randf_range(float(ore_rules["copper_thickness_m"][0]), float(ore_rules["copper_thickness_m"][1]))
			var resource: String = "gold" if arc and rng.randf() < float(ore_rules["arc_gold_chance"]) else "copper"
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": resource, "shape": "halo", "feature": feature["id"],
				"center": feature["center"], "radius_a_m": snappedf(ra * scale, 0.1), "radius_b_m": snappedf(rb * scale, 0.1),
				"angle": feature["angle"], "top_y": snappedf(top + 100.0, 0.1), "thickness_m": snappedf(thickness, 0.1),
				"grade": snappedf(rng.randf_range(0.1, 0.4), 0.01),
				"tonnes": int(PI * ra * rb * (scale * scale - 1.0) * thickness * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

		# Skarn where the intrusion reaches a limestone layer.
		if not limestone.is_empty():
			var lime_y: float = float(cell["datum_m"]) - float(limestone["top_m"]) - 0.5 * float(limestone["thickness_m"])

			if lime_y < top and lime_y > float(feature["bottom_y"]) and rng.randf() < float(ore_rules["skarn_chance"]):
				var angle: float = rng.randf() * TAU
				var edge: Vector2 = center + Vector2(cos(angle) * ra, sin(angle) * rb).rotated(float(feature["angle"]))
				var size: float = rng.randf_range(float(ore_rules["skarn_size_m"][0]), float(ore_rules["skarn_size_m"][1]))
				var thickness: float = minf(float(limestone["thickness_m"]), size * 0.5)
				var ore: Dictionary = new_id.call(ore_counter)
				ore.merge({
					"resource": _weighted(rng, ore_rules["skarn_resources"]), "shape": "lens", "feature": feature["id"],
					"center": [snappedf(edge.x, 0.1), snappedf(lime_y, 0.1), snappedf(edge.y, 0.1)],
					"radius_a_m": snappedf(size, 0.1), "radius_b_m": snappedf(size * 0.6, 0.1), "angle": snappedf(angle, 0.001),
					"thickness_m": snappedf(thickness, 0.1),
					"grade": snappedf(rng.randf_range(0.3, 0.9), 0.01),
					"tonnes": int(PI * size * size * 0.6 * thickness * 0.66 * ROCK_DENSITY_T_M3),
				})
				ores.append(ore)

				# Ruby or sapphire in the marble the heat made from the limestone.
				if rng.randf() < float(ore_rules["corundum_chance"]):
					var spin: float = angle + rng.randf_range(-0.6, 0.6)
					var spot: Vector2 = center + Vector2(cos(spin) * ra, sin(spin) * rb).rotated(float(feature["angle"])) * 1.1
					var gem_size: float = rng.randf_range(float(ore_rules["corundum_size_m"][0]), float(ore_rules["corundum_size_m"][1]))
					var gem: Dictionary = new_id.call(ore_counter)
					gem.merge({
						"resource": _weighted(rng, ore_rules["corundum_gems"]), "shape": "lens", "feature": feature["id"],
						"center": [snappedf(spot.x, 0.1), snappedf(lime_y, 0.1), snappedf(spot.y, 0.1)],
						"radius_a_m": snappedf(gem_size, 0.1), "radius_b_m": snappedf(gem_size * 0.5, 0.1), "angle": snappedf(spin, 0.001),
						"thickness_m": snappedf(minf(float(limestone["thickness_m"]), gem_size * 0.3), 0.1),
						"grade": snappedf(rng.randf_range(0.1, 0.5), 0.01),
						"tonnes": int(PI * gem_size * gem_size * 0.5 * gem_size * 0.3 * 0.66 * ROCK_DENSITY_T_M3),
					})
					ores.append(gem)

		# Gem pegmatite at pluton edges.
		if str(feature["size"]) == "pluton" and rng.randf() < float(ore_rules["pegmatite_gem_chance"]):
			var angle: float = rng.randf() * TAU
			var edge: Vector2 = center + Vector2(cos(angle) * ra, sin(angle) * rb).rotated(float(feature["angle"])) * 0.95
			var y: float = top - float(feature["roof_drop_m"]) - rng.randf_range(50.0, 300.0)
			var ore: Dictionary = new_id.call(ore_counter)
			var pegmatite_gems: Array = []
			var has_shale: bool = false

			for layer in cell["layers"]:
				has_shale = has_shale or str(layer["rock"]) == str(ore_rules["pegmatite_emerald_needs"])

			for choice in ore_rules["pegmatite_gems"]:
				if str(choice[0]) != "emerald" or has_shale:
					pegmatite_gems.append(choice)

			ore.merge({
				"resource": _weighted(rng, pegmatite_gems), "shape": "lens", "feature": feature["id"],
				"center": [snappedf(edge.x, 0.1), snappedf(y, 0.1), snappedf(edge.y, 0.1)],
				"radius_a_m": 30.0, "radius_b_m": 12.0, "angle": snappedf(angle, 0.001), "thickness_m": 4.0,
				"grade": snappedf(rng.randf_range(0.2, 0.7), 0.01),
				"tonnes": int(PI * 30.0 * 12.0 * 4.0 * 0.66 * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

	# Lead and zinc lenses in limestone.
	if not limestone.is_empty():
		var lens_count: int = rng.randi_range(int(ore_rules["limestone_lens_count"][0]), int(ore_rules["limestone_lens_count"][1]))

		for n in range(lens_count):
			if rng.randf() >= float(ore_rules["limestone_lens_chance"]):
				continue

			var point: Vector2 = random_point.call(0.4)
			var y: float = float(cell["datum_m"]) - float(limestone["top_m"]) - rng.randf() * float(limestone["thickness_m"])
			var size: float = rng.randf_range(float(ore_rules["limestone_lens_size_m"][0]), float(ore_rules["limestone_lens_size_m"][1]))
			var thickness: float = minf(size * 0.3, float(limestone["thickness_m"]))
			var ore: Dictionary = new_id.call(ore_counter)
			ore.merge({
				"resource": _weighted(rng, ore_rules["limestone_lens_resources"]), "shape": "lens", "feature": "",
				"center": [snappedf(point.x, 0.1), snappedf(y, 0.1), snappedf(point.y, 0.1)],
				"radius_a_m": snappedf(size, 0.1), "radius_b_m": snappedf(size * 0.7, 0.1),
				"angle": snappedf(rng.randf() * PI, 0.001), "thickness_m": snappedf(thickness, 0.1),
				"grade": snappedf(rng.randf_range(0.3, 0.8), 0.01),
				"tonnes": int(PI * size * size * 0.7 * thickness * 0.66 * ROCK_DENSITY_T_M3),
			})
			ores.append(ore)

	# Coal seams and evaporites in basins: layers that cover the whole province.
	if kind == "basin":
		var area: float = _cell_m * _cell_m

		for layer in cell["layers"]:
			if str(layer["rock"]) == "coal":
				var ore: Dictionary = new_id.call(ore_counter)
				ore.merge({
					"resource": "coal", "shape": "layer", "feature": "", "province": cell["id"],
					"depth_below_datum_m": layer["top_m"], "thickness_m": layer["thickness_m"],
					"cycle_m": cell["cycle_m"], "repeat_to_m": cell["repeat_to_m"],
					"grade": snappedf(rng.randf_range(0.5, 1.0), 0.01),
					"tonnes": int(area * float(layer["thickness_m"]) * 1.4),
				})
				ores.append(ore)

		if rng.randf() < float(ore_rules["evaporite_chance"]):
			var host: Dictionary = {}

			for layer in cell["layers"]:
				if str(layer["rock"]) == "shale":
					host = layer

			if not host.is_empty():
				var thickness: float = rng.randf_range(float(ore_rules["evaporite_thickness_m"][0]), float(ore_rules["evaporite_thickness_m"][1]))
				thickness = minf(thickness, float(host["thickness_m"]) * 0.5)
				var ore: Dictionary = new_id.call(ore_counter)
				ore.merge({
					"resource": _weighted(rng, ore_rules["evaporite_resources"]), "shape": "layer", "feature": "",
					"province": cell["id"],
					"depth_below_datum_m": snappedf(float(host["top_m"]) + rng.randf() * (float(host["thickness_m"]) - thickness), 0.1),
					"thickness_m": snappedf(thickness, 0.1),
					"cycle_m": cell["cycle_m"], "repeat_to_m": cell["repeat_to_m"],
					"grade": snappedf(rng.randf_range(0.5, 1.0), 0.01),
					"tonnes": int(area * thickness * 2.2),
				})
				ores.append(ore)

	# Things scattered through a band of one layer across the province:
	# geodes in basalt lava, garnets in folded slate, flint in chalk (and
	# chert in limestone), alum in shale.
	for scatter in ore_rules["scatters"]:
		if not scatter["kinds"].has(kind) or rng.randf() >= float(scatter["chance"]):
			continue

		var host: Dictionary = {}

		for layer in cell["layers"]:
			if str(layer["rock"]) == str(scatter["host"]) and host.is_empty():
				host = layer

		if host.is_empty():
			continue

		var band: float = minf(rng.randf_range(float(scatter["band_m"][0]), float(scatter["band_m"][1])), float(host["thickness_m"]))
		var ore: Dictionary = new_id.call(ore_counter)
		ore.merge({
			"resource": _weighted(rng, scatter["resources"]), "shape": "scatter", "feature": "", "province": cell["id"],
			"host_rock": str(scatter["host"]),
			"depth_below_datum_m": snappedf(float(host["top_m"]) + rng.randf() * (float(host["thickness_m"]) - band), 0.1),
			"thickness_m": snappedf(band, 0.1), "density": float(scatter["density"]),
			"cycle_m": cell["cycle_m"], "repeat_to_m": cell["repeat_to_m"],
			"grade": snappedf(rng.randf_range(0.1, 0.5), 0.01),
			"tonnes": int(_cell_m * _cell_m * band * float(scatter["density"]) * ROCK_DENSITY_T_M3),
		})
		ores.append(ore)

	# Ore ids live in the same numbering space as features, offset by 50.
	for ore in ores:
		ore["local_id"] = int(ore["local_id"]) + 50
		ore["id"] = "%d,%d#%d" % [home.x, home.y, int(ore["local_id"])]

	return {"features": made_features, "ores": ores}


func _count(rng: RandomNumberGenerator, rule: Dictionary, kind: String) -> int:
	if not rule.has(kind) or typeof(rule[kind]) != TYPE_ARRAY:
		return 0

	return rng.randi_range(int(rule[kind][0]), int(rule[kind][1]))


# How far below the surface a body starts. Shallower under high ground,
# where erosion has cut deeper into the rock; negative means it reaches the surface.
func _burial(rng: RandomNumberGenerator, surface: float) -> float:
	var r: Dictionary = _rules["burial"]
	var t: float = pow(rng.randf(), float(r["power"]))
	var depth: float = lerpf(float(r["min_m"]), float(r["max_m"]), t)
	var mountain: float = clampf(surface / float(r["mountain_height_m"]), 0.0, 1.0)
	return depth * (1.0 - float(r["mountain_reduction"]) * mountain) if depth > 0.0 else depth


func _weighted(rng: RandomNumberGenerator, choices: Array) -> String:
	var total: float = 0.0

	for choice in choices:
		total += float(choice[1])

	var pick: float = rng.randf() * total

	for choice in choices:
		pick -= float(choice[1])

		if pick <= 0.0:
			return str(choice[0])

	return str(choices[choices.size() - 1][0])


# Features and ore bodies from cells near the tile that reach into it.
func _collect_lists(tile: Vector2i, x0: float, z0: float) -> void:
	features = []
	ore_bodies = []
	var tile_m: float = float(_settings.tile_size_m)
	var rect: Rect2 = Rect2(x0, z0, tile_m, tile_m)
	var province_ids: Dictionary = {}

	for entry in provinces:
		province_ids[entry["id"]] = true

	var first_x: int = int(floor(x0 / _cell_m)) - 2
	var first_z: int = int(floor(z0 / _cell_m)) - 2

	for cz in range(first_z, first_z + _per_tile + 5):
		for cx in range(first_x, first_x + _per_tile + 5):
			var cell: Dictionary = _cell(cx, cz)

			for feature in cell["features"]:
				if _bounds_of(feature).intersects(rect):
					features.append(feature)

			for ore in cell["ores"]:
				if str(ore["shape"]) == "layer" or str(ore["shape"]) == "scatter":
					if province_ids.has(ore["province"]):
						ore_bodies.append(ore)
				elif _bounds_of(ore).intersects(rect):
					ore_bodies.append(ore)


func _bounds_of(item: Dictionary) -> Rect2:
	if item.has("points"):
		var a: Vector2 = Vector2(float(item["points"][0][0]), float(item["points"][0][1]))
		var rect: Rect2 = Rect2(a, Vector2.ZERO)

		for point in item["points"]:
			rect = rect.expand(Vector2(float(point[0]), float(point[1])))

		return rect.grow(float(item.get("width_m", 10.0)) + 50.0)

	var center: Vector2 = Vector2(float(item["center"][0]), float(item["center"][item["center"].size() - 1]))
	var radius: float = float(item.get("radius_m", maxf(float(item.get("radius_a_m", 0.0)), float(item.get("radius_b_m", 0.0)))))
	return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


# ==================================================
# PER-SAMPLE MAPS
# ==================================================

func _compute_offsets(x0: float, z0: float) -> void:
	# Flat per-province parameters: mode (0 none, 1 sag, 2 fold), a, b, c, d, e.
	var mode: PackedInt32Array = PackedInt32Array()
	var p1: PackedFloat32Array = PackedFloat32Array()
	var p2: PackedFloat32Array = PackedFloat32Array()
	var p3: PackedFloat32Array = PackedFloat32Array()
	var p4: PackedFloat32Array = PackedFloat32Array()
	var p5: PackedFloat32Array = PackedFloat32Array()
	var sag_radius: float = _cell_m * 0.9

	for entry in provinces:
		var fold: Dictionary = entry["fold"]

		if fold.has("sag_m"):
			mode.append(1)
			p1.append(float(fold["sag_m"]))
			p2.append(float(entry["seed_point"][0]))
			p3.append(float(entry["seed_point"][1]))
			p4.append(0.0)
			p5.append(0.0)
		elif fold.has("amplitude_m"):
			var k: float = TAU / float(fold["wavelength_m"])
			mode.append(2)
			p1.append(float(fold["amplitude_m"]))
			p2.append(float(fold["direction"][0]) * k)
			p3.append(float(fold["direction"][1]) * k)
			p4.append(float(fold["phase"]))
			p5.append(0.0)
		else:
			mode.append(0)
			p1.append(0.0)
			p2.append(0.0)
			p3.append(0.0)
			p4.append(0.0)
			p5.append(0.0)

	layer_offset.resize(samples * samples)
	var inv_sag: float = 1.0 / (sag_radius * sag_radius)

	for j in range(samples):
		var z: float = z0 + float(j) * spacing_m

		for i in range(samples):
			var index: int = j * samples + i
			var p: int = province[index]
			var m: int = mode[p]

			if m == 0:
				layer_offset[index] = 0
				continue

			var x: float = x0 + float(i) * spacing_m
			var value: float = 0.0

			if m == 1:
				var dx: float = x - p2[p]
				var dz: float = z - p3[p]
				value = -p1[p] * maxf(1.0 - (dx * dx + dz * dz) * inv_sag, 0.0)
			else:
				value = p1[p] * sin(x * p2[p] + z * p3[p] + p4[p])

			layer_offset[index] = clampi(int(round(value * 10.0)), -32768, 32767)


func _compute_cover(heights: PackedFloat32Array, water_class: PackedByteArray, soil: PackedByteArray, tile: Vector2i) -> void:
	var rules: Dictionary = _rules["cover"]
	var zero_tan: float = tan(deg_to_rad(float(rules["zero_slope_deg"])))
	var flat: float = float(rules["flat_m"])
	var noise_share: float = float(rules["noise"])
	var extra: Dictionary = {}

	for pair in [["alluvium", "alluvium_m"], ["beach_sand", "beach_m"], ["peat", "peat_m"], ["sand", "sand_m"]]:
		extra[_tables.id_of("soils", pair[0])] = float(rules[pair[1]])

	var bare: int = _tables.id_of("soils", "bare_rock")
	var water_depth: Dictionary = {OCEAN: float(rules["ocean_m"]), LAKE: float(rules["lake_m"]), RIVER: float(rules["river_m"])}
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SeedUtil.purpose_seed(_master, "geology_cover")
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = spacing_m / 180.0
	var tile_samples: int = samples - 1
	noise.offset = Vector3(float(tile.x * tile_samples), float(tile.y * tile_samples), 0.0)
	var image: Image = noise.get_image(samples, samples, false, false, false)

	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)

	var jitter: PackedByteArray = image.get_data()
	cover.resize(samples * samples)
	var inv: float = 1.0 / (2.0 * spacing_m)

	for j in range(samples):
		for i in range(samples):
			var index: int = j * samples + i
			var kind: int = water_class[index]
			var depth: float = 0.0

			if kind != 0:
				depth = water_depth.get(kind, 2.0)
			elif soil[index] != bare:
				var gx: float = (heights[index + (1 if i < samples - 1 else 0)] - heights[index - (1 if i > 0 else 0)]) * inv
				var gz: float = (heights[index + (samples if j < samples - 1 else 0)] - heights[index - (samples if j > 0 else 0)]) * inv
				var share: float = clampf(1.0 - sqrt(gx * gx + gz * gz) / zero_tan, 0.0, 1.0)
				depth = flat * pow(share, 1.5) + float(extra.get(soil[index], 0.0)) * share

			depth *= 1.0 + noise_share * (float(jitter[index]) / 127.5 - 1.0)
			cover[index] = clampi(int(round(depth * 4.0)), 0, 255)


# The rock at the bedrock surface (ground minus cover).
func _compute_surface_rock(heights: PackedFloat32Array, x0: float, z0: float) -> void:
	var total: int = samples * samples
	surface_rock.resize(total)

	# Per province: datum, layer bottoms and rock ids.
	var datums: PackedFloat32Array = PackedFloat32Array()
	var bottoms: Array = []
	var rocks: Array = []
	var bases: PackedInt32Array = PackedInt32Array()

	var cycles: PackedFloat32Array = PackedFloat32Array()
	var repeat_to: PackedFloat32Array = PackedFloat32Array()

	for entry in provinces:
		datums.append(float(entry["datum_m"]))
		cycles.append(maxf(float(entry["cycle_m"]), 1.0))
		repeat_to.append(maxf(float(entry["repeat_to_m"]), float(entry["cycle_m"])))
		var b: PackedFloat32Array = PackedFloat32Array()
		var r: PackedInt32Array = PackedInt32Array()

		for layer in entry["layers"]:
			b.append(float(layer["top_m"]) + float(layer["thickness_m"]))
			r.append(_rock_ids[str(layer["rock"])])

		bottoms.append(b)
		rocks.append(r)
		bases.append(_rock_ids[str(entry["base_rock"])])

	# Limestone turns to marble deep in fold belts (heat and pressure) and
	# around granite intrusions (their heat), the contact aureole.
	var meta: Dictionary = _rules["metamorphism"]
	var marble: int = _rock_ids["marble"]
	var limestone: int = _rock_ids["limestone"]
	var marble_depth: PackedFloat32Array = PackedFloat32Array()

	for entry in provinces:
		marble_depth.append(float(meta["fold_belt_marble_depth_m"]) if str(entry["kind"]) == "fold_belt" else INF)

	var bedrock: PackedFloat32Array = PackedFloat32Array()
	bedrock.resize(total)

	for index in range(total):
		var y: float = heights[index] - float(cover[index]) * 0.25
		bedrock[index] = y
		var p: int = province[index]
		var depth: float = maxf(datums[p] + float(layer_offset[index]) * 0.1 - y, 0.0)
		var layer_bottoms: PackedFloat32Array = bottoms[p]
		var rock: int = bases[p]

		# The layer cycle repeats down to repeat_to_m, then base rock.
		if depth < repeat_to[p]:
			var in_cycle: float = fmod(depth, cycles[p])

			for k in range(layer_bottoms.size()):
				if in_cycle < layer_bottoms[k]:
					rock = rocks[p][k]
					break

		if rock == limestone and depth > marble_depth[p]:
			rock = marble

		surface_rock[index] = rock

	# Bodies that cut through the layers, drawn only inside their bounds.
	var granite: int = _rock_ids["granite"]
	var basalt: int = _rock_ids["basalt"]

	for feature in features:
		var kind: String = str(feature["type"])

		if kind != "intrusion" and kind != "volcanic_vent" and kind != "volcanic_pipe":
			continue

		var aureole: float = 0.0

		if kind == "intrusion":
			aureole = maxf(float(meta["aureole_share"]) * float(feature["radius_b_m"]), float(meta["aureole_min_m"]))

		var rect: Rect2 = _bounds_of(feature).grow(aureole)
		var i0: int = clampi(int(floor((rect.position.x - x0) / spacing_m)), 0, samples - 1)
		var i1: int = clampi(int(ceil((rect.end.x - x0) / spacing_m)), 0, samples - 1)
		var j0: int = clampi(int(floor((rect.position.y - z0) / spacing_m)), 0, samples - 1)
		var j1: int = clampi(int(ceil((rect.end.y - z0) / spacing_m)), 0, samples - 1)
		var center: Vector2 = Vector2(float(feature["center"][0]), float(feature["center"][1]))

		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var index: int = j * samples + i
				var offset: Vector2 = Vector2(x0 + float(i) * spacing_m, z0 + float(j) * spacing_m) - center

				if kind == "intrusion":
					var local: Vector2 = offset.rotated(-float(feature["angle"]))
					var q: float = pow(local.x / float(feature["radius_a_m"]), 2.0) + pow(local.y / float(feature["radius_b_m"]), 2.0)

					if q <= 1.0 and bedrock[index] <= float(feature["top_y"]) - float(feature["roof_drop_m"]) * q:
						surface_rock[index] = granite
					elif surface_rock[index] == limestone and bedrock[index] <= float(feature["top_y"]) + float(meta["aureole_above_top_m"]):
						var outer: Vector2 = Vector2(float(feature["radius_a_m"]) + aureole, float(feature["radius_b_m"]) + aureole)

						if pow(local.x / outer.x, 2.0) + pow(local.y / outer.y, 2.0) <= 1.0:
							surface_rock[index] = marble
				elif offset.length() <= float(feature["radius_m"]) and bedrock[index] <= float(feature["top_y"]):
					surface_rock[index] = basalt


# ==================================================
# PLACER DEPOSITS
# ==================================================

# Gold and tin worn out of bodies that reach the surface collect in the
# gravels of the river below them.
func _find_placers(tile: Vector2i, heights: PackedFloat32Array, water_class: PackedByteArray, flow: PackedFloat32Array, x0: float, z0: float) -> void:
	var ore_rules: Dictionary = _rules["ores"]
	var max_steps: int = int(float(ore_rules["placer_length_m"]) / spacing_m)
	var record_every: int = maxi(int(float(ore_rules["placer_step_m"]) / spacing_m), 1)
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "geology_placer", tile.x, tile.y)
	var local: int = 9000
	var placers: Array = []
	var used_rivers: Dictionary = {}
	placer_sources = 0

	for ore in ore_bodies:
		var resource: String = str(ore["resource"])

		if not ore_rules["placer_resources"].has(resource):
			continue

		var outcrop: int = _outcrop_sample(ore, heights, x0, z0)

		if outcrop < 0:
			continue

		placer_sources += 1

		# Walk downhill to a river, then down the river.
		var at: int = outcrop
		var points: Array = []
		var on_river: bool = false
		var steps: int = 0
		var river_steps: int = 0

		while steps < max_steps * 3 and river_steps < max_steps:
			steps += 1
			var i: int = at % samples
			var j: int = at / samples

			if water_class[at] == OCEAN:
				break

			if water_class[at] == RIVER:
				on_river = true

			if on_river:
				if river_steps % record_every == 0:
					points.append([snappedf(x0 + float(i) * spacing_m, 0.1), snappedf(z0 + float(j) * spacing_m, 0.1)])

				river_steps += 1

			# Water goes where the drainage grows: the neighbor with the most
			# flow above our own (this also crosses flats left by pit filling).
			var next: int = -1
			var best_flow: float = flow[at]

			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue

					var ni: int = i + dx
					var nj: int = j + dz

					if ni < 0 or nj < 0 or ni >= samples or nj >= samples:
						continue

					var n: int = nj * samples + ni

					if flow[n] > best_flow:
						best_flow = flow[n]
						next = n

			if next < 0:
				break

			at = next

		if points.size() < 3 or used_rivers.has(str(points[0])):
			continue

		used_rivers[str(points[0])] = true
		local += 1
		var width: float = 4.0
		var thickness: float = rng.randf_range(float(ore_rules["placer_thickness_m"][0]), float(ore_rules["placer_thickness_m"][1]))
		var length: float = float(points.size() * record_every) * spacing_m
		placers.append({
			"id": "%d,%d#%d" % [tile.x, tile.y, local],
			"home_tile": [tile.x, tile.y],
			"local_id": local,
			"resource": resource,
			"shape": "placer",
			"feature": ore["id"],
			"points": points,
			"width_m": width,
			"thickness_m": snappedf(thickness, 0.1),
			"grade": snappedf(float(ore["grade"]) * 0.5, 0.01),
			"tonnes": int(length * width * thickness * 1.8),
		})

	ore_bodies.append_array(placers)


# A sample inside the tile where the body reaches the ground, or -1.
func _outcrop_sample(ore: Dictionary, heights: PackedFloat32Array, x0: float, z0: float) -> int:
	var tile_m: float = float(_settings.tile_size_m)
	var candidates: Array = []

	if str(ore["shape"]) == "vein":
		var a: Vector2 = Vector2(float(ore["points"][0][0]), float(ore["points"][0][1]))
		var b: Vector2 = Vector2(float(ore["points"][1][0]), float(ore["points"][1][1]))
		var steps: int = maxi(int(a.distance_to(b) / 16.0), 1)

		for k in range(steps + 1):
			candidates.append([a.lerp(b, float(k) / float(steps)), float(ore["top_y"])])
	elif str(ore["shape"]) == "lens":
		candidates.append([Vector2(float(ore["center"][0]), float(ore["center"][2])), float(ore["center"][1]) + 0.5 * float(ore["thickness_m"])])
	elif str(ore["shape"]) == "pipe":
		candidates.append([Vector2(float(ore["center"][0]), float(ore["center"][1])), float(ore["top_y"])])
	elif str(ore["shape"]) == "halo":
		var center: Vector2 = Vector2(float(ore["center"][0]), float(ore["center"][1]))
		candidates.append([center, float(ore["top_y"])])

		for k in range(8):
			var angle: float = float(k) * TAU / 8.0
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * float(ore["radius_a_m"]) * 0.6
			candidates.append([point, float(ore["top_y"]) - 0.36 * float(ore.get("thickness_m", 0.0))])
	else:
		return -1

	for candidate in candidates:
		var point: Vector2 = candidate[0]

		if point.x < x0 or point.y < z0 or point.x > x0 + tile_m or point.y > z0 + tile_m:
			continue

		var i: int = int(round((point.x - x0) / spacing_m))
		var j: int = int(round((point.y - z0) / spacing_m))
		var index: int = j * samples + i

		if heights[index] > 0.0 and float(candidate[1]) >= heights[index]:
			return index

	return -1


# ==================================================
# NOISE
# ==================================================

func _seamless(purpose: String, wavelength_m: float, octaves: int) -> PackedByteArray:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SeedUtil.purpose_seed(_master, purpose)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.frequency = _noise_cell_m / wavelength_m
	var image: Image = noise.get_seamless_image(_noise_size_x, _noise_size_z, false, false, 0.12, true)

	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)

	return image.get_data()


# Bilinear 0..1 value of a seamless world field at a world position.
func _noise01(field: PackedByteArray, x: float, z: float) -> float:
	var world_x: float = float(_settings.min_tile * _settings.tile_size_m)
	var u: float = (x - world_x) / _noise_cell_m
	var v: float = (z - world_x) / _noise_cell_m
	var c0: int = int(floor(u))
	var r0: int = int(floor(v))
	var tu: float = u - float(c0)
	var tv: float = v - float(r0)
	var a: float = float(field[posmod(r0, _noise_size_z) * _noise_size_x + posmod(c0, _noise_size_x)])
	var b: float = float(field[posmod(r0, _noise_size_z) * _noise_size_x + posmod(c0 + 1, _noise_size_x)])
	var c: float = float(field[posmod(r0 + 1, _noise_size_z) * _noise_size_x + posmod(c0, _noise_size_x)])
	var d: float = float(field[posmod(r0 + 1, _noise_size_z) * _noise_size_x + posmod(c0 + 1, _noise_size_x)])
	return lerpf(lerpf(a, b, tu), lerpf(c, d, tu), tv) / 255.0


func _noise_value(field: PackedByteArray, x: float, z: float) -> float:
	return _noise01(field, x, z) * 2.0 - 1.0
