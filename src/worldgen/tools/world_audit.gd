extends SceneTree

# World audit: a repeatable, read-only check that the physical world is right where players walk (Dave's roadmap layer 1,
# "the physical world working perfectly"). It samples chunks across every land biome of the baked tiles, the starter area
# and the tile borders, and measures every placed thing against the ground the player really stands on: the LOD 0 Transvoxel
# mesh of the generator's own voxel blocks (the same blocks the server streams and the client's collision is built from).
#
#   godot --headless --path . --script res://src/worldgen/tools/world_audit.gd -- [options]
#     --per-biome=N    chunks per land biome (default 6)
#     --near=R         chunks within R chunks of the starter town chunk as well (default 2: a 5 x 5 block)
#     --border=N       chunks straddling tile borders (default 8)
#     --windows=N      32 m mesh windows per chunk (default 3; each window is one 32 m scatter cell)
#     --lods=0,1,2,3   levels to mesh (default 0,1,2: LOD 1 and up are only for the far-look counts)
#     --part=I/N       run every N-th chunk from I (several processes in parallel)
#     --out=NAME       JSON report, always under user:// (default world_audit.json); --merge=N1,N2,... merges those part reports, prints
#                      the total and writes user://world_audit_total.json
#     --examples=N     worst examples kept per fault (default 12)
#     --camps          instead of chunks: the starter town, the goblin camps and every bandit candidate site (trunks, boulders, tilt, water, overlaps)
#     --caves          instead of chunks: every cave of every baked tile (walking lines, dens, den mouths, goblin paths, floor items)
#
# Nothing is written to the world; the tool reads the tiles, the placer, the water grid and the server's scatter layout.
# Fault names and limits are in FAULTS below; the README is docs/design/WORLD_AUDIT.md.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CellReadsScript := preload("res://src/stream/cell_reads.gd")
const DrinkRulesScript := preload("res://src/shared/drink_rules.gd")

const WORLD := "res://worlds/base_world"
const TOWN := Vector2(58160.0, 71360.0)     # the starter town centre (data/npcs/camp.json): sampled because players are there, not used by any rule
const WINDOW_M := 32
const PLAYER_RADIUS_M := 0.35               # terrain_client _make_player capsule
const VISUAL_SINK_MAX := 0.15               # flora_view: models are sunk min(0.15, 0.08 x height)

# fault -> [what it means, limit]
const FAULTS := {
	"ground_mismatch": ["the height every placer uses (surface_height) is off the LOD 0 mesh by more than 0.10 m", 0.10],
	"ground_hole": ["a point in a window with no ground mesh under it (fall-through)", 0.0],
	"ground_overhang": ["a point with more than one ground surface (cave roof, overhang)", 0.0],
	"tree_base_floats": ["a tree trunk's downhill edge stands more than 0.10 m above the mesh (gap under the trunk)", 0.10],
	"tree_sunk": ["a tree root more than 0.5 m under the mesh", 0.5],
	"tree_on_cliff": ["the ground under a tree's trunk drops more than 1.0 m across it", 1.0],
	"shrub_floats": ["a shrub's base more than 0.10 m above the mesh", 0.10],
	"plant_floats": ["a small plant's base more than 0.10 m above the mesh", 0.10],
	"plant_buried": ["a plant or shrub sunk under the mesh by more than half its height (and 0.25 m)", 0.25],
	"flora_in_water": ["a non-water plant, shrub or tree standing in drawn water more than 0.15 m deep", 0.15],
	"sapling_collider": ["a sapling (under flora_placer.SAPLING_M) with a trunk collider: an invisible 3 m pole a player should push through", 0.0],
	"trunks_overlap": ["two tree trunk colliders inside each other", 0.0],
	"trunk_squeeze": ["two trunks closer than a player's width (0.70 m gap): not a fault alone, a trap if many", 0.0],
	"flora_in_trunk": ["a shrub or plant rooted inside a tree trunk", 0.0],
	"item_floats": ["a loose stone, stick or ore piece more than 0.10 m above the mesh", 0.10],
	"item_buried": ["a loose stone, stick or ore piece more than 0.15 m under the mesh", 0.15],
	"boulder_floats": ["a boulder's centre more than half its radius above the lowest mesh under it", 0.0],
	"boulder_overlap": ["two boulders inside each other, or a boulder through a tree trunk", 0.0],
	"item_in_trunk": ["a loose item lying inside a tree trunk", 0.0],
	"water_gap": ["a dry water-grid point, no lower than its wet neighbour's bed, 0.30 m or more under that neighbour's level (a hole or cut edge in the water sheet)", 0.30],
	"water_wall": ["water 0.30 m or more deep beside dry ground lower than its bed and 0.50 m under its level (water held up by nothing), no fall drawn there", 0.30],
	"water_step": ["two neighbouring wet points whose levels differ 1.0 m more than their beds do (water steeper than the ground), no fall drawn there", 1.0],
	"lake_tilted": ["neighbouring lake points more than 0.10 m apart (standing water on a slope)", 0.10],
	"water_dry_bed": ["a lake or river sample with no water drawn over it", 0.0],
	"cave_floor_off": ["a point on a cave's walking line (the skeleton floor goblin paths and den spots use) with the floor mesh more than 0.40 m above it, or no floor within 3 m under it", 0.40],
	"cave_squeeze": ["a cave's walking line with under 0.70 m between floor and roof: no player stance fits (crawl is 0.7 m)", 0.70],
	"cave_crawl": ["a cave's walking line with 0.70 to 1.20 m headroom: crawl only (not a fault alone)", 1.20],
	"cave_steep": ["a cave floor climbing more than 1.0 m in 1 m along its walking line", 1.0],
	"den_floor_off": ["a cave den or goblin den spot more than 0.30 m off the floor mesh", 0.30],
	"den_on_pool": ["a cave den spot over a spring pool's water (dens there are only for den sounds)", 0.0],
	"den_low": ["headroom at a den spot under the animal's height (goblin and bear 1.2 m, wolf 0.9, fox 0.5)", 0.0],
	"den_mouth_off": ["an animal den mouth where the server puts a new animal (surface_height) with no mesh ground within 0.30 m (in the air or in rock)", 0.30],
	"goblin_path_off": ["a point on a goblin den path (mouth to den, walked by its goblins) off the floor mesh by more than 0.40 m or under 1.2 m headroom", 0.40],
	"cave_item_floats": ["a cave stone, mine leftover or boulder above the floor mesh (stone 0.10 m, boulder its radius)", 0.10],
	"cave_item_on_pool": ["a cave stone or boulder laid over a spring pool's water (hangs over it or sits on it)", 0.0],
	"cave_prop_off": ["cave floor dressing (bones, goblin litter or fire, den droppings or bedding) more than 0.15 m off the floor mesh (looks)", 0.15],
	"cave_item_buried": ["a cave stone or mine leftover more than 0.15 m under the floor mesh", 0.15],
	"camp_in_trunk": ["a camp piece (town marker, camp fire, spawn, goblin camp prop, bandit Lean-to, seat or tether) overlapping a tree trunk collider", 0.05],
	"camp_on_boulder": ["a camp piece overlapping a boulder or ore rock", 0.05],
	"camp_tilted": ["ground rising across a camp piece's footprint more than a player may build on (PlacementRules.steep: a Lean-to 1.0 m, a fire 0.6 m) or, for furniture and NPC spots, 0.30 m", 0.30],
	"camp_in_water": ["a camp piece standing in drawn water more than 0.10 m deep", 0.10],
	"camp_overlap": ["two pieces of one camp inside each other", 0.05],
	"far_float_lod1": ["at LOD 1 (the view past the near ring), a plant or tree base more than 0.25 m off the mesh", 0.25],
	"far_float_lod2": ["at LOD 2, a plant or tree base more than 0.25 m off the mesh", 0.25],
	"far_float_lod3": ["at LOD 3, a plant or tree base more than 0.25 m off the mesh", 0.25],
}

var generator
var placer
var tables
var items
var mesher: VoxelMesherTransvoxel = VoxelMesherTransvoxel.new()
var biome_names: Dictionary = {}
var counts: Dictionary = {}            # fault -> count
var checked: Dictionary = {}           # what was checked -> count (the denominators)
var by_biome: Dictionary = {}          # biome -> fault -> count
var examples: Dictionary = {}          # fault -> [[severity, x, y, z, note]]
var keep_examples: int = 12
var lake_class: int = 2
var river_class: int = 3
var _biome_now: String = ""


class WaterStub:
	# The server's water hub stand-in for cell_reads: each tile's settled baked water (the generator's tiles carry it).
	var gen

	func data_of(tile: Vector2i):
		return gen.get_tile(tile)


func _init() -> void:
	var per_biome: int = 6
	var near: int = 2
	var border: int = 8
	var windows: int = 3
	var lods: PackedInt32Array = PackedInt32Array([0, 1, 2])
	var part: Vector2i = Vector2i(0, 1)
	var out: String = "user://world_audit.json"
	var probe: Vector2 = Vector2.INF
	var caves: bool = false
	var camps: bool = false

	for argument in OS.get_cmdline_user_args():
		var value: String = argument.get_slice("=", 1)

		if argument.begins_with("--per-biome="):
			per_biome = int(value)
		elif argument.begins_with("--near="):
			near = int(value)
		elif argument.begins_with("--border="):
			border = int(value)
		elif argument.begins_with("--windows="):
			windows = int(value)
		elif argument.begins_with("--lods="):
			lods = PackedInt32Array()

			for s in value.split(","):
				lods.append(int(s))
		elif argument.begins_with("--part="):
			part = Vector2i(int(value.get_slice("/", 0)), int(value.get_slice("/", 1)))
		elif argument.begins_with("--out="):
			out = "user://" + value.trim_prefix("user://").get_file()   # reports only under user:// (the tool writes nothing else)
		elif argument.begins_with("--examples="):
			keep_examples = int(value)
		elif argument.begins_with("--merge="):
			quit(_merge(value.split(",")))
			return
		elif argument == "--camps":
			camps = true
		elif argument == "--caves":
			caves = true
		elif argument.begins_with("--probe="):
			probe = Vector2(float(value.get_slice(",", 0)), float(value.get_slice(",", 1)))

	for fault in FAULTS:
		counts[fault] = 0
		examples[fault] = []

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD + "/tiles")
	placer = PlacerScript.new()
	placer.setup(generator, tables, rules)

	for entry in tables.get_entries("biomes"):
		biome_names[int(entry["id"])] = str(entry["name"])

	for entry in tables.get_entries("water_classes"):
		if str(entry["name"]) == "lake":
			lake_class = int(entry["id"])
		elif str(entry["name"]) == "river":
			river_class = int(entry["id"])

	if not errors.is_empty():
		push_error("world_audit: setup errors %s" % str(errors))
		quit(2)
		return

	if probe.is_finite():
		quit(_probe(probe))
		return

	var mine: Array = []
	var started: int = Time.get_ticks_msec()

	if camps:
		mine = _audit_camps(settings)
	elif caves:
		mine = _audit_caves(part)
	else:
		_setup_items(settings)
		var chunks: Array = _pick_chunks(per_biome, near, border)

		for n in range(chunks.size()):
			if n % part.y == part.x:
				mine.append(chunks[n])

		print("world_audit: %d chunks picked, %d in part %d/%d" % [chunks.size(), mine.size(), part.x, part.y])

	for n in range(0 if caves or camps else mine.size()):
		var c: Vector2i = mine[n][0]
		_biome_now = str(mine[n][1])
		_audit_chunk(c, windows, lods)
		print("world_audit: chunk %d/%d %s (%s) done, %.0f s" % [n + 1, mine.size(), str(c), _biome_now, float(Time.get_ticks_msec() - started) / 1000.0])

	var report: Dictionary = {"counts": counts, "checked": checked, "by_biome": by_biome, "examples": examples, "chunks": mine.size()}
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)

	if file == null:
		push_error("world_audit: cannot write " + out)
		quit(2)
		return

	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	_print_report(report)
	quit(0)


# ---------------------------------------------------------------- sampling

# [chunk, biome name] for: per_biome chunks of every land biome (by the biome at the chunk centre) across the baked tiles, the
# chunks round the starter town, and chunks on the tile borders. Seeded, so every run picks the same chunks.
func _pick_chunks(per_biome: int, near: int, border: int) -> Array:
	var by: Dictionary = {}
	var borders: Array = []
	var tile_m: float = float(generator.tile_size_m)
	var per_tile: int = int(round(tile_m / placer.chunk_m))
	var picked: Array = []
	var seen: Dictionary = {}

	for file_name in DirAccess.get_files_at(WORLD + "/tiles"):
		if not file_name.ends_with(".tile"):
			continue

		var parts: PackedStringArray = file_name.get_basename().split("_")
		var tile: Vector2i = Vector2i(int(parts[1]), int(parts[2]))
		var data = generator.get_tile(tile)

		if data.placeholder:
			continue

		for cz in range(per_tile):
			for cx in range(per_tile):
				var chunk: Vector2i = Vector2i(tile.x * per_tile + cx, tile.y * per_tile + cz)
				var o: Vector2 = placer.chunk_origin(chunk)
				var centre: Vector2 = o + Vector2(placer.chunk_m, placer.chunk_m) * 0.5
				var b: int = data.biome[data.nearest(centre.x, centre.y)]

				if biome_names.get(b, "") == "ocean":
					continue

				var name: String = biome_names.get(b, str(b))

				if not by.has(name):
					by[name] = []

				by[name].append(chunk)

				if cx == 0 or cz == 0:
					borders.append([chunk, name])

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261123
	var names: Array = by.keys()
	names.sort()

	for name in names:
		var list: Array = by[name]

		for n in range(mini(per_biome, list.size())):
			var k: int = rng.randi_range(0, list.size() - 1)
			var chunk: Vector2i = list[k]

			if not seen.has(chunk):
				seen[chunk] = true
				picked.append([chunk, name])

	var town: Vector2i = placer.chunk_of(TOWN.x, TOWN.y)

	for dz in range(-near, near + 1):
		for dx in range(-near, near + 1):
			var chunk: Vector2i = town + Vector2i(dx, dz)

			if not seen.has(chunk):
				seen[chunk] = true
				picked.append([chunk, "town_area"])

	for n in range(mini(border, borders.size())):
		var pick: Array = borders[rng.randi_range(0, borders.size() - 1)]

		if not seen.has(pick[0]):
			seen[pick[0]] = true
			picked.append([pick[0], "tile_border"])

	return picked


# ---------------------------------------------------------------- the ground mesh

# The LOD `lod` Transvoxel mesh of the generator's blocks over the square [x0, x0 + w) x [z0, z0 + w):
# {"tris": PackedVector3Array (3 world points a triangle), "grid": cell index -> PackedInt32Array of triangle numbers, "cell": m, "x0", "z0", "n"}.
# With y_lo and y_hi (a cave window) the blocks cover that height range instead of the surface's.
func _window_mesh(x0: int, z0: int, w: int, lod: int, y_lo: float = NAN, y_hi: float = NAN) -> Dictionary:
	var s: int = 1 << lod
	var n: int = int(float(w) / float(s))
	var lo: float = y_lo + 6.0 * float(s)
	var hi: float = y_hi - 6.0 * float(s)

	if is_nan(y_lo):
		lo = INF
		hi = -INF

		for k in range(0, w + 1, maxi(s, 2)):
			for i in range(0, w + 1, maxi(s, 2)):
				var h: float = generator.surface_height(float(x0 + i), float(z0 + k))
				lo = minf(lo, h)
				hi = maxf(hi, h)

	var y0: int = int(floor((lo - 6.0 * float(s)) / float(s))) * s
	var ny: int = mini(int(ceil((hi + 6.0 * float(s) - float(y0)) / float(s))) + 3, 400)
	var buffer: VoxelBuffer = Layout.make_buffer(1)
	buffer.create(n + 3, ny, n + 3)
	var origin: Vector3i = Vector3i(x0 - s, y0 - s, z0 - s)
	generator.generate(buffer, origin, lod)
	var mesh: Mesh = mesher.build_mesh(buffer, [])
	var tris: PackedVector3Array = PackedVector3Array()
	var grid: Dictionary = {}
	var result: Dictionary = {"tris": tris, "grid": grid, "cell": float(s), "x0": x0, "z0": z0, "n": n}

	if mesh == null or mesh.get_surface_count() == 0:
		return result

	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base: Vector3 = Vector3(origin)
	var count: int = 0

	for t in range(0, idx.size(), 3):
		var a: Vector3 = base + (v[idx[t]] + Vector3.ONE) * float(s)
		var b: Vector3 = base + (v[idx[t + 1]] + Vector3.ONE) * float(s)
		var c: Vector3 = base + (v[idx[t + 2]] + Vector3.ONE) * float(s)
		var area: float = absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z))

		if area < 1.0e-6:
			continue

		tris.append(a)
		tris.append(b)
		tris.append(c)
		var i0: int = int(floor((minf(a.x, minf(b.x, c.x)) - float(x0)) / float(s)))
		var i1: int = int(floor((maxf(a.x, maxf(b.x, c.x)) - float(x0)) / float(s)))
		var k0: int = int(floor((minf(a.z, minf(b.z, c.z)) - float(z0)) / float(s)))
		var k1: int = int(floor((maxf(a.z, maxf(b.z, c.z)) - float(z0)) / float(s)))

		for kk in range(k0, k1 + 1):
			for ii in range(i0, i1 + 1):
				var key: int = kk * 4096 + ii

				var list: PackedInt32Array = grid.get(key, PackedInt32Array())
				list.append(count)
				grid[key] = list   # a packed array is a value: write it back

		count += 1

	result["tris"] = tris
	return result


# Every mesh height straight down through (x, z), highest first; empty = no ground there.
func _mesh_hits(m: Dictionary, x: float, z: float) -> PackedFloat32Array:
	var s: float = m["cell"]
	var key: int = int(floor((z - float(m["z0"])) / s)) * 4096 + int(floor((x - float(m["x0"])) / s))
	var hits: PackedFloat32Array = PackedFloat32Array()
	var tris: PackedVector3Array = m["tris"]

	for t in (m["grid"] as Dictionary).get(key, PackedInt32Array()):
		var a: Vector3 = tris[t * 3]
		var b: Vector3 = tris[t * 3 + 1]
		var c: Vector3 = tris[t * 3 + 2]
		var d: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		var u: float = ((b.x - x) * (c.z - z) - (c.x - x) * (b.z - z)) / d
		var w: float = ((c.x - x) * (a.z - z) - (a.x - x) * (c.z - z)) / d
		var e: float = 1.0 - u - w

		if u < -1.0e-5 or w < -1.0e-5 or e < -1.0e-5:
			continue

		var y: float = u * a.y + w * b.y + e * c.y
		var dup: bool = false

		for h in hits:
			if absf(h - y) < 0.02:
				dup = true

		if not dup:
			hits.append(y)

	hits.sort()
	hits.reverse()
	return hits


# The top mesh height under (x, z), NAN when none.
func _mesh_top(m: Dictionary, x: float, z: float) -> float:
	var hits: PackedFloat32Array = _mesh_hits(m, x, z)
	return NAN if hits.is_empty() else hits[0]


# The mesh height under (x, z) nearest to y (a plant in a cave stands on the cave floor, not the hill above it), NAN when none.
func _mesh_near(m: Dictionary, x: float, z: float, y: float) -> float:
	var best: float = NAN

	for h in _mesh_hits(m, x, z):
		if is_nan(best) or absf(h - y) < absf(best - y):
			best = h

	return best


func _inside(m: Dictionary, x: float, z: float, margin: float) -> bool:
	var x0: float = float(m["x0"])
	var z0: float = float(m["z0"])
	var w: float = float(m["n"]) * float(m["cell"])
	return x >= x0 + margin and z >= z0 + margin and x < x0 + w - margin and z < z0 + w - margin


# ---------------------------------------------------------------- recording

func _fault(fault: String, severity: float, at: Vector3, note: String) -> void:
	counts[fault] = int(counts[fault]) + 1

	if not by_biome.has(_biome_now):
		by_biome[_biome_now] = {}

	by_biome[_biome_now][fault] = int(by_biome[_biome_now].get(fault, 0)) + 1
	var list: Array = examples[fault]
	list.append([snappedf(severity, 0.01), snappedf(at.x, 0.1), snappedf(at.y, 0.01), snappedf(at.z, 0.1), note])

	if list.size() > keep_examples * 4:
		_trim(list)


func _trim(list: Array) -> void:
	list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	list.resize(mini(list.size(), keep_examples))


func _checked(what: String, n: int = 1) -> void:
	checked[what] = int(checked.get(what, 0)) + n


# ---------------------------------------------------------------- one chunk

func _audit_chunk(chunk: Vector2i, windows: int, lods: PackedInt32Array) -> void:
	var o: Vector2 = placer.chunk_origin(chunk)
	var flora: Dictionary = placer.chunk_items(chunk)
	var trees: Array = _trees_of(flora)
	_check_trunks(flora, trees)
	_check_water(o)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(chunk)
	var cells: int = int(placer.chunk_m / float(WINDOW_M))

	for n in range(windows):
		var cell: Vector2i = Vector2i(int(floor(o.x / float(WINDOW_M))) + rng.randi_range(0, cells - 1), int(floor(o.y / float(WINDOW_M))) + rng.randi_range(0, cells - 1))
		var x0: int = cell.x * WINDOW_M
		var z0: int = cell.y * WINDOW_M
		var m0: Dictionary = _window_mesh(x0, z0, WINDOW_M, 0)
		_check_ground(m0)
		_check_flora(m0, flora)
		_check_scatter(m0, cell, trees)

		for lod in lods:
			if lod > 0:
				_check_far(_window_mesh(x0, z0, WINDOW_M, lod), flora, lod)


# [position, collider radius, species name] of every tree with a trunk collider (flora_view's rule: trunk x height / reference height).
func _trees_of(flora: Dictionary) -> Array:
	var out: Array = []
	var ids: PackedInt32Array = flora["ids"]

	for n in range(ids.size()):
		var sp: Dictionary = placer.species_of(ids[n])

		if sp.is_empty() or int(sp["kind"]) != PlacerScript.KIND_TREE:
			continue

		var r: float = PlacerScript.collider_radius(PlacerScript.KIND_TREE, float(sp["trunk"]), float(flora["heights"][n]) / float(sp["height_ref"]), float(flora["heights"][n]))

		if r > 0.0 and float(flora["heights"][n]) < PlacerScript.SAPLING_M:
			_fault("sapling_collider", PlacerScript.SAPLING_M - float(flora["heights"][n]), flora["positions"][n], "%s %.2f m tall, trunk collider r %.3f m" % [sp["name"], float(flora["heights"][n]), r])
		elif r > 0.0:
			out.append([flora["positions"][n], r, str(sp["name"])])

	return out


func _check_trunks(flora: Dictionary, trees: Array) -> void:
	_checked("trees", trees.size())
	var grid: Dictionary = {}

	for t in range(trees.size()):
		var p: Vector3 = trees[t][0]
		var key: Vector2i = Vector2i(int(floor(p.x / 4.0)), int(floor(p.z / 4.0)))

		if not grid.has(key):
			grid[key] = []

		grid[key].append(t)

	for t in range(trees.size()):
		var p: Vector3 = trees[t][0]
		var r: float = trees[t][1]
		var key: Vector2i = Vector2i(int(floor(p.x / 4.0)), int(floor(p.z / 4.0)))

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for u in grid.get(key + Vector2i(dx, dz), []):
					if u <= t:
						continue

					var q: Vector3 = trees[u][0]
					var gap: float = Vector2(p.x - q.x, p.z - q.z).length() - r - float(trees[u][1])

					if gap < 0.0:
						_fault("trunks_overlap", -gap, p, "%s and %s" % [trees[t][2], trees[u][2]])
					elif gap < 2.0 * PLAYER_RADIUS_M:
						_fault("trunk_squeeze", 2.0 * PLAYER_RADIUS_M - gap, p, "%s and %s, gap %.2f m" % [trees[t][2], trees[u][2], gap])

	# Shrubs and plants rooted inside a trunk.
	var ids: PackedInt32Array = flora["ids"]

	for n in range(ids.size()):
		var sp: Dictionary = placer.species_of(ids[n])

		if sp.is_empty() or int(sp["kind"]) == PlacerScript.KIND_TREE:
			continue

		var p: Vector3 = flora["positions"][n]
		var key: Vector2i = Vector2i(int(floor(p.x / 4.0)), int(floor(p.z / 4.0)))

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for u in grid.get(key + Vector2i(dx, dz), []):
					var q: Vector3 = trees[u][0]
					var inside: float = float(trees[u][1]) - Vector2(p.x - q.x, p.z - q.z).length()

					if inside > 0.02:
						_fault("flora_in_trunk", inside, p, "%s in %s" % [sp["name"], trees[u][2]])


func _check_ground(m: Dictionary) -> void:
	var x0: int = m["x0"]
	var z0: int = m["z0"]

	for k in range(1, WINDOW_M - 1):
		for i in range(1, WINDOW_M - 1):
			for half in [0.0, 0.5]:
				var x: float = float(x0 + i) + half
				var z: float = float(z0 + k) + half
				var hits: PackedFloat32Array = _mesh_hits(m, x, z)
				_checked("ground points")

				if hits.is_empty():
					_fault("ground_hole", 1.0, Vector3(x, NAN, z), "")
					continue

				var h: float = generator.surface_height(x, z)

				if hits.size() > 1:
					_fault("ground_overhang", float(hits.size()), Vector3(x, hits[0], z), "%d surfaces, surface_height %.2f" % [hits.size(), h])
					continue

				var d: float = h - hits[0]

				if absf(d) > float(FAULTS["ground_mismatch"][1]):
					_fault("ground_mismatch", absf(d), Vector3(x, hits[0], z), "surface_height %+.2f m off the mesh" % d)


func _check_flora(m: Dictionary, flora: Dictionary) -> void:
	var ids: PackedInt32Array = flora["ids"]

	for n in range(ids.size()):
		var p: Vector3 = flora["positions"][n]

		if not _inside(m, p.x, p.z, 1.5):
			continue

		var sp: Dictionary = placer.species_of(ids[n])

		if sp.is_empty():
			continue

		var height: float = float(flora["heights"][n])
		var kind: int = int(sp["kind"])
		var base: float = p.y - minf(VISUAL_SINK_MAX, 0.08 * height)
		var ground: float = _mesh_near(m, p.x, p.z, p.y)
		_checked(PlacerScript.KINDS[kind] + "s")

		if is_nan(ground):
			_fault("ground_hole", 1.0, p, "under %s" % sp["name"])
			continue

		var level: float = _water_level(p.x, p.z)

		if str(sp["shape"]) != "reed" and int(sp["water_mask"]) & (1 << lake_class) == 0 and not is_nan(level) and level - ground > float(FAULTS["flora_in_water"][1]):
			_fault("flora_in_water", level - ground, p, "%s, %.2f m deep" % [sp["name"], level - ground])

		if kind == PlacerScript.KIND_TREE:
			var r: float = maxf(PlacerScript.collider_radius(kind, float(sp["trunk"]), height / float(sp["height_ref"]), height), 0.15)
			var lo: float = ground
			var hi: float = ground

			for a in range(8):
				var ang: float = TAU * float(a) / 8.0
				var g: float = _mesh_near(m, p.x + cos(ang) * r, p.z + sin(ang) * r, p.y)

				if not is_nan(g):
					lo = minf(lo, g)
					hi = maxf(hi, g)

			if base - lo > float(FAULTS["tree_base_floats"][1]):
				_fault("tree_base_floats", base - lo, p, "%s, %.2f m gap under the trunk (r %.2f)" % [sp["name"], base - lo, r])

			if ground - p.y > float(FAULTS["tree_sunk"][1]):
				_fault("tree_sunk", ground - p.y, p, "%s %.2f m under" % [sp["name"], ground - p.y])

			if hi - lo > float(FAULTS["tree_on_cliff"][1]):
				_fault("tree_on_cliff", hi - lo, p, "%s, %.2f m drop across the trunk" % [sp["name"], hi - lo])
		else:
			if base - ground > float(FAULTS["plant_floats"][1]):
				_fault("shrub_floats" if kind == PlacerScript.KIND_SHRUB else "plant_floats", base - ground, p, "%s %.2f m up" % [sp["name"], base - ground])

			if ground - p.y > maxf(0.25, 0.5 * height):
				_fault("plant_buried", ground - p.y, p, "%s %.2f m under (height %.2f)" % [sp["name"], ground - p.y, height])


# The level of the drawn water at (x, z) from the chunk water grid (nearest 8 m point), NAN for none (the sea is drawn at 0 m).
var _water_cache: Dictionary = {}


func _water_grid(chunk: Vector2i) -> Dictionary:
	if not _water_cache.has(chunk):
		if _water_cache.size() > 16:
			_water_cache.clear()

		_water_cache[chunk] = WaterGridScript.chunk_levels(generator, placer.chunk_origin(chunk), placer.chunk_m)

	return _water_cache[chunk]


func _water_level(x: float, z: float) -> float:
	var chunk: Vector2i = placer.chunk_of(x, z)
	var grid: Dictionary = _water_grid(chunk)
	var o: Vector2 = placer.chunk_origin(chunk)
	var sp: float = grid["spacing"]
	var count: int = grid["count"]
	var i: int = clampi(int(round((x - o.x) / sp)), 0, count - 1)
	var j: int = clampi(int(round((z - o.y) / sp)), 0, count - 1)
	var level: float = (grid["levels"] as PackedFloat32Array)[j * count + i]

	if generator.surface_height(x, z) < 0.0:
		level = maxf(0.0, level) if not is_nan(level) else 0.0

	return level


func _check_water(o: Vector2) -> void:
	var chunk: Vector2i = placer.chunk_of(o.x + 1.0, o.y + 1.0)
	var grid: Dictionary = _water_grid(chunk)
	var data = generator.get_tile(generator.tile_of(o.x + 1.0, o.y + 1.0))
	var count: int = grid["count"]
	var sp: float = grid["spacing"]
	var levels: PackedFloat32Array = grid["levels"]
	var falls: Array = grid.get("falls", [])
	var ground: PackedFloat32Array = PackedFloat32Array()
	ground.resize(count * count)

	for j in range(count):
		for i in range(count):
			ground[j * count + i] = generator.surface_height(o.x + float(i) * sp, o.y + float(j) * sp)

	for j in range(count):
		for i in range(count):
			var k: int = j * count + i
			var x: float = o.x + float(i) * sp
			var z: float = o.y + float(j) * sp
			var cls: int = data.water_class[data.nearest(x, z)]
			_checked("water grid points")

			if is_nan(levels[k]):
				if (cls == lake_class or cls == river_class) and ground[k] > 0.0:
					var ws: float = data.water_surface[data.nearest(x, z)]

					if not is_nan(ws) and ws > ground[k] + 0.1:
						_fault("water_dry_bed", ws - ground[k], Vector3(x, ground[k], z), "class %d, painted %.2f over ground %.2f" % [cls, ws, ground[k]])

				# A dry point beside wet water that stands 0.30 m or more over the dry point's ground, which is no lower than the wet point's bed:
				# the water should cover it (a hole or a cut edge in the sheet). A dry point lower than the bed is the stream running on downhill.
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ii: int = i + d.x
					var jj: int = j + d.y

					if ii < 0 or jj < 0 or ii >= count or jj >= count or is_nan(levels[jj * count + ii]):
						continue

					var over: float = levels[jj * count + ii] - ground[k]

					if ground[k] > 0.0 and ground[k] >= ground[jj * count + ii] - 0.1 and over >= float(FAULTS["water_gap"][1]):
						_fault("water_gap", over, Vector3(x, ground[k], z), "water %.2f beside, ground here %.2f" % [levels[jj * count + ii], ground[k]])
						break

				continue

			_checked("wet points")

			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var ii: int = i + d.x
				var jj: int = j + d.y

				if ii >= count or jj >= count or is_nan(levels[jj * count + ii]):
					continue

				var step: float = absf(levels[k] - levels[jj * count + ii])
				var steeper: float = step - absf(ground[k] - ground[jj * count + ii])   # a brook on a steep bed falls with it; a step is water steeper than its bed

				if steeper >= float(FAULTS["water_step"][1]) and not _fall_near(falls, Vector2(x, z), 2.0 * sp):
					_fault("water_step", steeper, Vector3(x, levels[k], z), "to %.2f, bed %.2f to %.2f" % [levels[jj * count + ii], ground[k], ground[jj * count + ii]])

				var cls2: int = data.water_class[data.nearest(o.x + float(ii) * sp, o.y + float(jj) * sp)]

				if cls == lake_class and cls2 == lake_class and step > float(FAULTS["lake_tilted"][1]):
					_fault("lake_tilted", step, Vector3(x, levels[k], z), "to %.2f" % levels[jj * count + ii])

			# Water 0.30 m or more deep beside a dry point lower than its bed, and 0.50 m or more over that point's ground (or the sea): water held up by nothing.
			if levels[k] - ground[k] >= float(FAULTS["water_wall"][1]):
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ii: int = i + d.x
					var jj: int = j + d.y

					if ii < 0 or jj < 0 or ii >= count or jj >= count or not is_nan(levels[jj * count + ii]):
						continue

					var below: float = maxf(ground[jj * count + ii], 0.0)

					if ground[jj * count + ii] < ground[k] - 0.1 and levels[k] - below >= 0.5 and not _fall_near(falls, Vector2(x, z), 2.0 * sp):
						_fault("water_wall", levels[k] - below, Vector3(x, levels[k], z), "%.2f deep, beside dry ground %.2f" % [levels[k] - ground[k], ground[jj * count + ii]])
						break


func _fall_near(falls: Array, p: Vector2, reach: float) -> bool:
	for fall in falls:
		for q in (fall as Dictionary).get("points", []):
			if q is Vector3 and Vector2((q as Vector3).x, (q as Vector3).z).distance_to(p) <= reach:
				return true

	return false


func _check_far(m: Dictionary, flora: Dictionary, lod: int) -> void:
	var ids: PackedInt32Array = flora["ids"]
	var fault: String = "far_float_lod%d" % lod

	if not FAULTS.has(fault):
		return

	for n in range(ids.size()):
		var p: Vector3 = flora["positions"][n]

		if not _inside(m, p.x, p.z, 1.5 * float(1 << lod)):
			continue

		var g: float = _mesh_near(m, p.x, p.z, p.y)
		_checked("flora at lod %d" % lod)

		if not is_nan(g) and absf(p.y - g) > float(FAULTS[fault][1]):
			_fault(fault, absf(p.y - g), p, "%s %+.2f m" % [placer.species_of(ids[n]).get("name", "?"), p.y - g])


# ---------------------------------------------------------------- the server's scatter (stones, sticks, bank stones, boulders, ore rocks)

func _setup_items(settings) -> void:
	var dir: String = "user://world_audit_store"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p: int, _b: PackedByteArray) -> void: pass
	items.send_slots = func(_p: int, _b: PackedByteArray) -> void: pass
	items.send_world_items = func(_p: int, _a: Array, _r: PackedInt32Array) -> void: pass
	items.send_notice = func(_p: int, _t: String) -> void: pass
	items.send_reject = func(_p: int, _r: int) -> void: pass
	var gen = generator
	var water: WaterStub = WaterStub.new()
	water.gen = generator
	items.ground_height = func(x: float, z: float) -> float: return gen.surface_height(x, z)
	items.ground_ready = func(_x: float, _z: float) -> bool: return true
	items.world_seed = int(settings.master_seed)
	items.cave_scatter = func(cell: Vector2i, cell_m: float) -> PackedFloat32Array:
		var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * cell_m
		var cave_tile = gen.get_tile(gen.tile_of(centre.x, centre.y))
		var out: PackedFloat32Array = PackedFloat32Array()

		if cave_tile == null or cave_tile.placeholder:
			return out

		for n in cave_tile.cave_scatter_in(cell, cell_m):
			out.append_array(cave_tile.cave_scatter.slice(n * 5, n * 5 + 5))

		return out
	items.ore_near = func(pos: Vector3, reach: float, names: Dictionary, depth_m: float) -> String: return gen.get_tile(gen.tile_of(pos.x, pos.z)).ore_at(pos, reach, names, depth_m)
	items.rock_near = func(pos: Vector3) -> String: return gen.get_tile(gen.tile_of(pos.x, pos.z)).bedrock_name_at(pos)
	items.water_near = func(pos: Vector3, reach: float) -> bool: return DrinkRulesScript.water_near(gen.get_tile(gen.tile_of(pos.x, pos.z)), pos, reach, false)
	items.cell_reads = func(x: float, z: float) -> Dictionary: return CellReadsScript.bound(gen, water, x, z)
	items.water_depth_at = func(pos: Vector3) -> float: return float(CellReadsScript.bound(gen, water, pos.x, pos.z)["water_depth_at"].call(pos))
	items.setup(ItemTableScript.load_default(), dir)
	items.start_resources(WORLD + "/tiles", float(settings.tile_size_m), Vector3(TOWN.x, 0.0, TOWN.y))
	items.finish_resources()
	items._resources_ready()


func _check_scatter(m: Dictionary, cell: Vector2i, trees: Array) -> void:
	items._items.clear()
	items._cells_done.clear()
	items._lay_out_cell(cell, float(WINDOW_M), items._drops.get("ground_scatter", {}))
	var boulders: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]
		var p: Vector3 = it["pos"]

		if not _inside(m, p.x, p.z, 0.5):
			continue

		var ground: float = _mesh_near(m, p.x, p.z, p.y)
		var name: String = items.table.id_of(int(it["number"]))

		if it.has("boulder"):
			var r: float = float(it["boulder"].get("radius", 0.5))
			boulders.append([p, r, name])
			_checked("boulders")
			var lo: float = ground

			for a in range(8):
				var ang: float = TAU * float(a) / 8.0
				var g: float = _mesh_near(m, p.x + cos(ang) * r * 0.7, p.z + sin(ang) * r * 0.7, p.y)

				if not is_nan(g):
					lo = minf(lo, g)

			# A boulder's model is centred on its spot sunk into the ground; it floats when the ground under its body falls away by more than its radius.
			if not is_nan(lo) and p.y - lo > r:
				_fault("boulder_floats", p.y - lo - r, p, "%s r %.2f, ground falls %.2f m under it" % [name, r, p.y - lo])

			continue

		_checked("loose items")

		if is_nan(ground):
			_fault("ground_hole", 1.0, p, "under %s" % name)
			continue

		if p.y - ground > float(FAULTS["item_floats"][1]):
			_fault("item_floats", p.y - ground, p, "%s %.2f m up" % [name, p.y - ground])
		elif ground - p.y > float(FAULTS["item_buried"][1]):
			_fault("item_buried", ground - p.y, p, "%s %.2f m under" % [name, ground - p.y])

		for t in trees:
			var q: Vector3 = t[0]
			var inside: float = float(t[1]) - Vector2(p.x - q.x, p.z - q.z).length()

			if inside > 0.02:
				_fault("item_in_trunk", inside, p, "%s in %s" % [name, t[2]])

	for a in range(boulders.size()):
		var p: Vector3 = boulders[a][0]

		for b in range(a + 1, boulders.size()):
			var q: Vector3 = boulders[b][0]
			var over: float = float(boulders[a][1]) + float(boulders[b][1]) - p.distance_to(q)

			if over > 0.1:
				_fault("boulder_overlap", over, p, "%s and %s" % [boulders[a][2], boulders[b][2]])

		for t in trees:
			var q: Vector3 = t[0]
			var over: float = float(boulders[a][1]) * 0.8 + float(t[1]) - Vector2(p.x - q.x, p.z - q.z).length()

			if over > 0.05:
				_fault("boulder_overlap", over, p, "%s through %s trunk" % [boulders[a][2], t[2]])


# ---------------------------------------------------------------- caves

const CAVE_WINDOW_M := 16
const CAVE_BAND_M := 8
const CAVE_PROP_NAMES := ["animal bones", "human bones", "goblin litter", "goblin fire", "den droppings", "den bedding"]
const DEN_HEADROOM := {"goblin": 1.2, "bear": 1.2, "wolf": 0.9, "fox": 0.5, "den": 0.5}

var _cave_data = null                # the tile whose caves are being checked (its spring pools)
var _cave_meshes: Dictionary = {}   # Vector3i (16 m column, 8 m band) -> window mesh over that column, the band and 8 m either side


# The LOD 0 mesh round (x, y, z): a 16 m column window covering y - 8 to y + 16 at least, cached.
func _cave_mesh(x: float, y: float, z: float) -> Dictionary:
	var key: Vector3i = Vector3i(int(floor(x / CAVE_WINDOW_M)), int(floor(y / CAVE_BAND_M)), int(floor(z / CAVE_WINDOW_M)))

	if not _cave_meshes.has(key):
		if _cave_meshes.size() > 400:
			_cave_meshes.clear()

		_cave_meshes[key] = _window_mesh(key.x * CAVE_WINDOW_M, key.z * CAVE_WINDOW_M, CAVE_WINDOW_M, 0, float(key.y * CAVE_BAND_M - CAVE_BAND_M), float(key.y * CAVE_BAND_M + 2 * CAVE_BAND_M))
		_checked("cave mesh windows")

	return _cave_meshes[key]


# [floor height nearest to y (NAN: none within 3 m under it), headroom over that floor (INF: open above within the window), 1 when the floor is a
# spring pool's surface (tile_terrain_data.cave_pool_surface: the 20 m pool under a spring chamber) else 0]. A point under the pool's surface
# (a stone on the pool's bottom) is measured against the mesh.
# pool_margin: how far outside a pool's basin (and over its surface) a point still counts as on the pool (walking lines and dens 1 m: a
# player swims there; loose things 0.3 m).
func _cave_floor(x: float, y: float, z: float, pool_margin: float = 1.0) -> Vector3:
	var hits: PackedFloat32Array = _mesh_hits(_cave_mesh(x, y, z), x, z)
	var floor_y: float = NAN
	var pool: float = _cave_data.cave_pool_surface(Vector3(x, y, z), pool_margin) if _cave_data != null else NAN

	for h in hits:
		if h <= y + 1.0 and h >= y - 3.0 and (is_nan(floor_y) or absf(h - y) < absf(floor_y - y)):
			floor_y = h

	var on_pool: bool = not is_nan(pool) and y > pool - 0.05 and (is_nan(floor_y) or pool > floor_y)

	if on_pool:
		floor_y = pool

	if is_nan(floor_y):
		return Vector3(NAN, INF, 0.0)

	var roof: float = INF

	for h in hits:
		if h > floor_y + 0.05:
			roof = minf(roof, h)

	return Vector3(floor_y, roof - floor_y, 1.0 if on_pool else 0.0)


# Every cave of every baked tile in this part: the walking line of each passage, the den spots, the den mouths, the goblin paths and the floor items.
func _audit_caves(part: Vector2i) -> Array:
	var done: Array = []
	var n: int = 0

	for file_name in DirAccess.get_files_at(WORLD + "/tiles"):
		if not file_name.ends_with(".tile"):
			continue

		var parts: PackedStringArray = file_name.get_basename().split("_")
		var tile: Vector2i = Vector2i(int(parts[1]), int(parts[2]))
		var data = generator.get_tile(tile)

		if data.placeholder or data.caves.is_empty():
			continue

		n += 1

		if (n - 1) % part.y != part.x:
			continue

		_biome_now = "tile %d,%d" % [tile.x, tile.y]
		data.build_cave_scatter()
		_cave_data = data
		_cave_meshes.clear()

		for cave in data.caves:
			for capsule in cave["capsules"]:
				_walk_line(capsule["a"] - Vector3(0.0, capsule["rh"], 0.0), capsule["b"] - Vector3(0.0, capsule["rh"], 0.0), "", 0.0)   # cave shapes are in world metres

		for k in data.cave_dens.size():
			_check_den(data.cave_dens[k], "den")

		for k in data.goblin_dens.size():
			_check_den(data.goblin_dens[k], "goblin")

		for path in data.goblin_den_paths:
			for p in range(path.size() - 1):
				_walk_line(path[p], path[p + 1], "goblin_path_off", DEN_HEADROOM["goblin"])

		for sp in data.animal_den_mouths:
			for mouth in data.animal_den_mouths[sp]:
				var y: float = generator.surface_height(mouth.x, mouth.y)
				var f: Vector3 = _cave_floor(mouth.x, y, mouth.y)
				_checked("den mouths")

				if is_nan(f.x) or absf(f.x - y) > float(FAULTS["den_mouth_off"][1]):
					_fault("den_mouth_off", 9.0 if is_nan(f.x) else absf(f.x - y), Vector3(mouth.x, y, mouth.y), "%s mouth: spawn height %.2f, floor %s" % [sp, y, "none" if is_nan(f.x) else "%.2f" % f.x])
				elif f.y < float(DEN_HEADROOM.get(sp, 0.5)):
					_fault("den_low", f.y, Vector3(mouth.x, y, mouth.y), "%s mouth: %.2f m headroom" % [sp, f.y])

		_check_cave_scatter(data)

		@warning_ignore("integer_division")
		for k in range(data.cave_bones.size() / 5):   # the dressing on cave floors: bones, goblin litter and fire, den droppings and bedding, mine timbers
			var at: Vector3 = Vector3(data.cave_bones[k * 5], data.cave_bones[k * 5 + 1], data.cave_bones[k * 5 + 2])
			var kind: int = int(data.cave_bones[k * 5 + 3])
			var fb: Vector3 = _cave_floor(at.x, at.y, at.z, 0.3)
			_checked("cave props")

			if kind >= 6:
				continue   # mine timber sets stand on the floor by their own legs (CD-6); not measured here

			if is_nan(fb.x) or fb.z > 0.0 or absf(at.y - fb.x) > float(FAULTS["cave_prop_off"][1]):
				_fault("cave_prop_off", 9.0 if is_nan(fb.x) else absf(at.y - fb.x), at, "%s: %s" % [CAVE_PROP_NAMES[clampi(kind, 0, 5)], "no floor within 3 m" if is_nan(fb.x) else ("over a spring pool" if fb.z > 0.0 else "%+.2f m off the floor" % (at.y - fb.x))])

		done.append([tile, _biome_now])
		print("world_audit: caves of tile %s done (%d caves)" % [str(tile), data.caves.size()])

	return done


# A walking line from a to b (floor points), sampled every metre: floor where the skeleton says, headroom and slope.
func _walk_line(a: Vector3, b: Vector3, fault: String, need: float) -> void:
	var steps: int = maxi(1, int(ceil(Vector2(b.x - a.x, b.z - a.z).length())))
	var last: float = NAN

	for k in range(steps + 1):
		var p: Vector3 = a.lerp(b, float(k) / float(steps))

		if generator.surface_height(p.x, p.z) < p.y + 0.5:
			last = NAN
			continue   # open to the sky here (a mouth's cut): the surface checks cover it

		var f: Vector3 = _cave_floor(p.x, p.y, p.z)
		_checked("cave walk points" if fault == "" else "goblin path points")
		var off: float = 9.0 if is_nan(f.x) else f.x - p.y

		if fault != "":
			if off > float(FAULTS[fault][1]) or is_nan(f.x) or f.y < need:
				_fault(fault, off if f.y >= need else need - f.y, p, "floor %s, headroom %.2f" % ["none" if is_nan(f.x) else "%+.2f m" % off, f.y])

			continue

		if is_nan(f.x) or off > float(FAULTS["cave_floor_off"][1]):
			_fault("cave_floor_off", off, p, "floor %s" % ("none within 3 m" if is_nan(f.x) else "%+.2f m off the line" % off))
			last = NAN
			continue

		if f.y < float(FAULTS["cave_squeeze"][1]):
			_fault("cave_squeeze", FAULTS["cave_squeeze"][1] - f.y, p, "headroom %.2f m" % f.y)
		elif f.y < float(FAULTS["cave_crawl"][1]):
			_fault("cave_crawl", FAULTS["cave_crawl"][1] - f.y, p, "headroom %.2f m" % f.y)

		var run: float = Vector2(b.x - a.x, b.z - a.z).length() / float(steps)

		if not is_nan(last) and run > 0.2 and absf(f.x - last) / run > float(FAULTS["cave_steep"][1]):
			_fault("cave_steep", absf(f.x - last) / run, p, "floor climbs %.2f m in %.2f m" % [absf(f.x - last), run])

		last = f.x


func _check_den(at: Vector3, kind: String) -> void:
	var f: Vector3 = _cave_floor(at.x, at.y, at.z)
	_checked("den spots")

	if f.z > 0.0:
		_fault("den_on_pool", absf(f.x - at.y), at, "%s: over a spring pool, its surface %+.2f m" % [kind, f.x - at.y])
	elif is_nan(f.x) or absf(f.x - at.y) > float(FAULTS["den_floor_off"][1]):
		_fault("den_floor_off", 9.0 if is_nan(f.x) else absf(f.x - at.y), at, "%s: floor %s" % [kind, "none" if is_nan(f.x) else "%+.2f m" % (f.x - at.y)])
	elif f.y < float(DEN_HEADROOM[kind]):
		_fault("den_low", float(DEN_HEADROOM[kind]) - f.y, at, "%s: %.2f m headroom" % [kind, f.y])


# The cave floor stones, boulders and mine leftovers as the server lays them (server_items._lay_out_cave_items puts each at its cave_scatter spot).
func _check_cave_scatter(data) -> void:
	@warning_ignore("integer_division")
	for k in range(data.cave_scatter.size() / 5):
		var p: Vector3 = Vector3(data.cave_scatter[k * 5], data.cave_scatter[k * 5 + 1], data.cave_scatter[k * 5 + 2])
		var kind: int = int(data.cave_scatter[k * 5 + 3])
		var f: Vector3 = _cave_floor(p.x, p.y, p.z, 0.3)
		var name: String = ["stone", "boulder", "mine leftover"][clampi(kind, 0, 2)]
		_checked("cave items")

		var rest: float = data.cave_floor_under(p)

		if kind != 1 and not is_nan(f.x) and f.z == 0.0:
			_checked("cave items, resting floor within 0.10 m of the mesh" if not is_nan(rest) and absf(rest - f.x) <= 0.10 else "cave items, resting floor off the mesh")

		if f.z > 0.0:
			_fault("cave_item_on_pool", absf(p.y - f.x), p, "%s over a spring pool, %+.2f m from its surface" % [name, p.y - f.x])
		elif is_nan(f.x):
			_fault("cave_item_floats", 9.0, p, "%s: no floor within 3 m under it" % name)
		elif kind == 1:
			var r: float = data.cave_scatter[k * 5 + 4]

			if p.y - f.x > r:
				_fault("cave_item_floats", p.y - f.x - r, p, "boulder r %.2f, %.2f m over the floor" % [r, p.y - f.x])
		elif p.y - f.x > float(FAULTS["cave_item_floats"][1]):
			_fault("cave_item_floats", p.y - f.x, p, "%s %.2f m up" % [name, p.y - f.x])
		elif f.x - p.y > float(FAULTS["cave_item_buried"][1]):
			_fault("cave_item_buried", f.x - p.y, p, "%s %.2f m under" % [name, f.x - p.y])


# ---------------------------------------------------------------- camps

const BanditsScript := preload("res://src/stream/server_bandits.gd")
const NpcCampScript := preload("res://src/shared/npc_camp.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")
# A town marker's footprint radius (data/npcs/markers.json kinds; judged: a bed, a chair, a post, a table, the square's middle, a shelter).
const MARKER_R := {"bed": 1.0, "chair": 0.4, "post": 0.3, "table": 0.9, "square": 1.0, "shelter": 1.5}
const FIRE_R := 0.7
const TILT_LIMIT_M := 0.30   # ground falling more than this across a piece's footprint: one side floats or sinks

var _flora_trees: Dictionary = {}   # chunk -> trees with a trunk collider ([position, radius, name])
var _cell_boulders: Dictionary = {}   # 32 m scatter cell -> [[position, radius, name]] (boulders and ore rocks)


# Every fixed piece the server lays where testers start and live: Edda and Hob's camp (fire, their spots, the town markers, the spawn), the
# goblin tribes' camps (fire and props) and every bandit candidate site that passes the static wake tests (server_bandits.refusal: not near the
# start, a goblin camp, a cave mouth, water or a slope over 15 degrees), laid as server_bandits.layout lays it. Each one checked against
# trunks, boulders, ground tilt, water and the other pieces of its camp.
func _audit_camps(settings) -> Array:
	_setup_items(settings)
	var camps: Array = []
	var town: Array = []

	for m in _markers():
		town.append({"name": str(m.get("id", "marker")), "at": Vector2(float(m["x"]), float(m["z"])), "r": float(MARKER_R.get(str(m.get("kind", "")), 0.5))})

	var fire: Vector2 = NpcCampScript.fire_spot()

	if fire.x != INF:
		town.append({"name": "camp fire", "at": fire, "r": FIRE_R, "rise": 0.6})

	var spawn: Vector2 = SpawnPointScript.OVERRIDE
	town.append({"name": "spawn", "at": spawn, "r": PLAYER_RADIUS_M})

	camps.append(["starter town", town])
	var structures: Dictionary = _structure_rows()

	for camp in NpcCampScript.tribe_camps():
		var pieces: Array = [{"name": "fire", "at": Vector2(float(camp["fire"]["x"]), float(camp["fire"]["z"])), "r": FIRE_R, "rise": 0.6}]

		for prop in camp.get("props", []):
			var row: Dictionary = structures.get(str(prop["kind"]), {})
			pieces.append({"name": str(prop["kind"]), "at": Vector2(float(prop["x"]), float(prop["z"])), "half": Vector2(0.5 * float(row.get("footprint_x", 1.0)), 0.5 * float(row.get("footprint_z", 1.0))), "yaw": float(prop.get("yaw", 0.0))})

		camps.append(["goblin camp " + str(camp["tribe"]), pieces])

	camps.append_array(_bandit_sites(settings, structures))
	var done: Array = []

	for camp in camps:
		_biome_now = "bandit site" if str(camp[0]).begins_with("bandit") else str(camp[0])
		_check_camp(camp[1], str(camp[0]))
		done.append([Vector2i.ZERO, camp[0]])

	print("world_audit: %d camps checked (%d bandit candidate sites)" % [camps.size(), camps.size() - 1 - NpcCampScript.tribe_camps().size()])
	return done


func _markers() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/markers.json"))
	return parsed.get("markers", []) if typeof(parsed) == TYPE_DICTIONARY else []


func _structure_rows() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed.get("structures", parsed)


# The bandit candidate sites on the baked tiles that pass server_bandits.refusal's world tests (road and traffic tests left out: any could wake).
func _bandit_sites(settings, structures: Dictionary) -> Array:
	var bandits = BanditsScript.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/bandits.json"))
	bandits.cfg = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	bandits.world_seed = int(settings.master_seed)
	bandits.town = TOWN
	bandits.ground_height = func(x: float, z: float) -> float: return generator.surface_height(x, z)
	bandits.in_water = func(x: float, z: float) -> bool: return _water_level(x, z) > generator.surface_height(x, z) + 0.10
	bandits.trees_at = func(at: Vector2, reach: float) -> Array:   # as terrain_server gives it: every trunk with a collider round the fire
		var feet: Array = []

		for tree in _trees_round(at, reach):
			feet.append([Vector2(tree[0].x, tree[0].z), float(tree[1])])

		return feet
	var cell_m: float = float(bandits.cfg.get("cell_m", 1000.0))
	var tile_m: float = float(generator.tile_size_m)
	var lean: Dictionary = structures.get("lean_to", {})
	var half: Vector2 = Vector2(0.5 * float(lean.get("footprint_x", 4.16)), 0.5 * float(lean.get("footprint_z", 5.44)))
	var out: Array = []
	var why: Dictionary = {}

	for file_name in DirAccess.get_files_at(WORLD + "/tiles"):
		if not file_name.ends_with(".tile"):
			continue

		var parts: PackedStringArray = file_name.get_basename().split("_")
		var tile: Vector2i = Vector2i(int(parts[1]), int(parts[2]))
		var data = generator.get_tile(tile)

		if data.placeholder:
			continue

		var per: int = int(round(tile_m / cell_m))

		for cz in range(per):
			for cx in range(per):
				var cell: Vector2i = Vector2i(tile.x * per + cx, tile.y * per + cz)
				var spot: Vector2 = bandits.candidate(cell)
				var refused: String = "no candidate" if spot.x == INF else _bandit_refusal(bandits, data, spot)

				if refused == "" and bandits._fitting_turn(cell, spot, bandits.trees_at.call(spot, BanditsScript.CAMP_REACH_M)) == INF:
					refused = "cluttered"   # server_bandits.refusal: no turn of the camp fits among the trunks on level enough ground
				why[refused] = int(why.get(refused, 0)) + 1

				if refused != "":
					continue

				bandits.sites[cell] = {"x": spot.x, "z": spot.y, "levels": bandits.camp_levels(cell, spot)}
				var plan: Dictionary = bandits.layout(cell)
				var pieces: Array = [{"name": "fire", "at": plan["fire"], "r": FIRE_R, "rise": 0.6}]

				for row in plan["lean_tos"]:
					var yaw: float = deg_to_rad(float(row[1]))
					var roof_mid: float = 0.5 * (BanditsScript.LEAN_TO_RIDGE_Z - half.y)   # the roof from the back to the ridge (the open front has no body)
					pieces.append({"name": "lean-to", "at": (row[0] as Vector2) + Vector2(0.0, roof_mid).rotated(-yaw), "half": Vector2(half.x, 0.5 * (BanditsScript.LEAN_TO_RIDGE_Z + half.y)),
						"yaw": float(row[1]), "rise": 1.0, "ground_at": row[0], "ground_half": half})

				for seat in plan["seats"]:
					pieces.append({"name": "seat", "at": seat, "r": PLAYER_RADIUS_M, "npc": true})

				pieces.append({"name": "horse tether", "at": plan["tether"], "r": 0.5, "rise": 0.6})
				out.append(["bandit site %d,%d" % [cell.x, cell.y], pieces])

	print("world_audit: bandit candidates %s" % str(why))
	return out


func _bandit_refusal(bandits, data, spot: Vector2) -> String:
	var cfg: Dictionary = bandits.cfg

	if spot.distance_to(TOWN) < float(cfg.get("start_clear_m", 1500.0)):
		return "start area"

	for camp in NpcCampScript.tribe_camps():
		if spot.distance_to(Vector2(float(camp["fire"]["x"]), float(camp["fire"]["z"]))) < float(cfg.get("tribe_clear_m", 1500.0)):
			return "goblin camp near"

	for mouth in data.cave_mouths:
		if spot.distance_to(Vector2(mouth[0].x, mouth[0].z)) < float(cfg.get("cave_clear_m", 150.0)):
			return "cave near"

	var h: float = generator.surface_height(spot.x, spot.y)

	if is_nan(h) or _water_level(spot.x, spot.y) > h:
		return "water"

	var step: float = float(cfg.get("slope_step_m", 5.0))
	var most: float = tan(deg_to_rad(float(cfg.get("slope_max_deg", 15.0)))) * step

	for d in [Vector2(step, 0.0), Vector2(-step, 0.0), Vector2(0.0, step), Vector2(0.0, -step)]:
		if absf(generator.surface_height(spot.x + d.x, spot.y + d.y) - h) > most:
			return "steep"

	return ""


func _check_camp(pieces: Array, camp: String) -> void:
	for k in range(pieces.size()):
		var p: Dictionary = pieces[k]
		var at: Vector2 = p["at"]
		var name: String = "%s: %s" % [camp, p["name"]]
		var reach: float = float(p["r"]) if p.has("r") else (p["half"] as Vector2).length()
		_checked("camp pieces")

		for tree in _trees_round(at, reach + 4.0):
			var q: Vector3 = tree[0]
			var inside: float = _footprint_overlap(p, Vector2(q.x, q.z), float(tree[1]))

			if inside > 0.05:
				_fault("camp_in_trunk", inside, Vector3(at.x, generator.surface_height(at.x, at.y), at.y), "%s overlaps a %s trunk by %.2f m" % [name, tree[2], inside])

		for rock in _boulders_round(at, reach + 2.0):
			var q: Vector3 = rock[0]
			var inside: float = _footprint_overlap(p, Vector2(q.x, q.z), float(rock[1]) * 0.8)

			if inside > 0.05:
				_fault("camp_on_boulder", inside, Vector3(at.x, q.y, at.y), "%s overlaps a %s by %.2f m" % [name, rock[2], inside])

		var lo: float = INF
		var hi: float = -INF

		for corner in _footprint_ring(p):
			var h: float = generator.surface_height(corner.x, corner.y)
			lo = minf(lo, h)
			hi = maxf(hi, h)

		if hi - lo > float(p.get("rise", TILT_LIMIT_M)):
			_fault("camp_tilted", hi - lo, Vector3(at.x, generator.surface_height(at.x, at.y), at.y), "%s: ground falls %.2f m across it" % [name, hi - lo])

		var ground: float = generator.surface_height(at.x, at.y)
		var water: float = _water_level(at.x, at.y)

		if not is_nan(water) and water - ground > 0.10:
			_fault("camp_in_water", water - ground, Vector3(at.x, ground, at.y), "%s in %.2f m of water" % [name, water - ground])

		for j in range(k + 1, pieces.size()):
			var o: Dictionary = pieces[j]

			if p.has("npc") and o.has("npc"):
				continue   # two NPC spots may share ground (seats round a fire)

			var gap: float = _pieces_overlap(p, o)

			if gap > 0.05:
				_fault("camp_overlap", gap, Vector3(at.x, ground, at.y), "%s and %s overlap by %.2f m" % [name, o["name"], gap])


# How far a circle (centre c, radius r) reaches into a piece's footprint (a circle "r" or a turned rectangle "half"/"yaw"); <= 0 when clear.
func _footprint_overlap(p: Dictionary, c: Vector2, r: float) -> float:
	var at: Vector2 = p["at"]

	if p.has("r"):
		return float(p["r"]) + r - at.distance_to(c)

	var half: Vector2 = p["half"]
	var local: Vector2 = (c - at).rotated(deg_to_rad(float(p.get("yaw", 0.0))))   # into the piece's frame (PlacementRules.steep's turn)
	var nearest: Vector2 = Vector2(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y))
	return r - local.distance_to(nearest) if local != nearest else r + minf(half.x - absf(local.x), half.y - absf(local.y))


func _pieces_overlap(a: Dictionary, b: Dictionary) -> float:
	if b.has("r"):
		return _footprint_overlap(a, b["at"], float(b["r"]))

	if a.has("r"):
		return _footprint_overlap(b, a["at"], float(a["r"]))

	return _footprint_overlap(a, b["at"], minf((b["half"] as Vector2).x, (b["half"] as Vector2).y))   # two rectangles: the second as its inner circle


# Points round a piece's footprint edge and its middle, for the ground's tilt under it.
func _footprint_ring(p: Dictionary) -> Array:
	var at: Vector2 = p.get("ground_at", p["at"])
	var out: Array = [at]

	for k in range(8):
		var a: float = TAU * float(k) / 8.0

		if p.has("r"):
			out.append(at + Vector2.from_angle(a) * maxf(float(p["r"]), 0.3))
		else:
			if k % 2 == 1:   # a rectangle: its middle and four corners, as PlacementRules.steep samples a footprint
				var half: Vector2 = p.get("ground_half", p["half"])
				out.append(at + Vector2(signf(cos(a)) * half.x, signf(sin(a)) * half.y).rotated(-deg_to_rad(float(p.get("yaw", 0.0)))))

	return out


func _trees_round(at: Vector2, reach: float) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for d in [Vector2.ZERO, Vector2(reach, reach), Vector2(-reach, reach), Vector2(reach, -reach), Vector2(-reach, -reach)]:
		var chunk: Vector2i = placer.chunk_of(at.x + d.x, at.y + d.y)

		if seen.has(chunk):
			continue

		seen[chunk] = true

		if not _flora_trees.has(chunk):
			if _flora_trees.size() > 64:
				_flora_trees.clear()

			_flora_trees[chunk] = _trees_of(placer.chunk_items(chunk))

		for tree in _flora_trees[chunk]:
			var q: Vector3 = tree[0]

			if Vector2(q.x - at.x, q.z - at.y).length() < reach + float(tree[1]):
				out.append(tree)

	return out


func _boulders_round(at: Vector2, reach: float) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for d in [Vector2.ZERO, Vector2(reach, reach), Vector2(-reach, reach), Vector2(reach, -reach), Vector2(-reach, -reach)]:
		var cell: Vector2i = Vector2i(int(floor((at.x + d.x) / float(WINDOW_M))), int(floor((at.y + d.y) / float(WINDOW_M))))

		if seen.has(cell):
			continue

		seen[cell] = true

		if not _cell_boulders.has(cell):
			if _cell_boulders.size() > 256:
				_cell_boulders.clear()

			items._items.clear()
			items._cells_done.clear()
			items._lay_out_cell(cell, float(WINDOW_M), items._drops.get("ground_scatter", {}))
			var list: Array = []

			for id in items._items:
				var it: Dictionary = items._items[id]

				if it.has("boulder"):
					list.append([it["pos"], float(it["boulder"].get("radius", 0.5)), "boulder" if int(it["number"]) == 0 else items.table.id_of(int(it["number"]))])

			_cell_boulders[cell] = list

		for rock in _cell_boulders[cell]:
			var q: Vector3 = rock[0]

			if Vector2(q.x - at.x, q.z - at.y).length() < reach + float(rock[1]):
				out.append(rock)

	return out


# One spot (a place a player reported): the ground heights, the mesh at each level and the flora and water there.
func _probe(at: Vector2) -> int:
	var x0: int = int(floor(at.x - 0.5 * float(WINDOW_M)))
	var z0: int = int(floor(at.y - 0.5 * float(WINDOW_M)))
	print("probe x %.1f z %.1f: surface_height %.3f, water level %.3f" % [at.x, at.y, generator.surface_height(at.x, at.y), _water_level(at.x, at.y)])

	for lod in range(4):
		var m: Dictionary = _window_mesh(x0, z0, WINDOW_M, lod)
		print("  lod %d: %d triangles, mesh heights %s" % [lod, int(float((m["tris"] as PackedVector3Array).size()) / 3.0), str(_mesh_hits(m, at.x, at.y))])

	for lod in range(2):   # the column from 120 m under the surface up, as a cave window sees it (caves are carved at LOD 0 to 3)
		var s: float = generator.surface_height(at.x, at.y)
		var m: Dictionary = _window_mesh(x0, z0, WINDOW_M, lod, s - 120.0, s + 8.0)
		print("  lod %d column: mesh heights %s" % [lod, str(_mesh_hits(m, at.x, at.y))])

	var chunk: Vector2i = placer.chunk_of(at.x, at.y)
	var flora: Dictionary = placer.chunk_items(chunk)

	for n in range((flora["ids"] as PackedInt32Array).size()):
		var p: Vector3 = flora["positions"][n]

		if Vector2(p.x - at.x, p.z - at.y).length() < 4.0:
			print("  flora %s at %s height %.2f" % [placer.species_of(flora["ids"][n]).get("name", "?"), str(p), float(flora["heights"][n])])

	return 0


# ---------------------------------------------------------------- report

func _print_report(report: Dictionary) -> void:
	print("\nWORLD AUDIT: %d chunks" % int(report["chunks"]))
	print("checked: %s" % JSON.stringify(report["checked"]))
	var names: Array = FAULTS.keys()

	for fault in names:
		var n: int = int(report["counts"].get(fault, 0))
		print("  %-18s %7d  %s" % [fault, n, FAULTS[fault][0]])

		if n > 0:
			var list: Array = report["examples"].get(fault, [])
			_trim(list)

			for e in list.slice(0, 3):
				print("      worst %.2f at x %.1f z %.1f (y %.2f) %s" % [float(e[0]), float(e[1]), float(e[3]), float(e[2]) if e[2] != null else NAN, str(e[4])])


func _merge(files: PackedStringArray) -> int:
	var total: Dictionary = {"counts": {}, "checked": {}, "by_biome": {}, "examples": {}, "chunks": 0}

	for path in files:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://" + path.trim_prefix("user://").get_file()))

		if not parsed is Dictionary:
			push_error("world_audit: cannot read " + path)
			return 2

		var r: Dictionary = parsed
		total["chunks"] = int(total["chunks"]) + int(r["chunks"])

		for key in ["counts", "checked"]:
			for f in r[key]:
				total[key][f] = int(total[key].get(f, 0)) + int(r[key][f])

		for b in r["by_biome"]:
			if not total["by_biome"].has(b):
				total["by_biome"][b] = {}

			for f in r["by_biome"][b]:
				total["by_biome"][b][f] = int(total["by_biome"][b].get(f, 0)) + int(r["by_biome"][b][f])

		for f in r["examples"]:
			if not total["examples"].has(f):
				total["examples"][f] = []

			total["examples"][f].append_array(r["examples"][f])

	for f in total["examples"]:
		_trim(total["examples"][f])

	var out: FileAccess = FileAccess.open("user://world_audit_total.json", FileAccess.WRITE)

	if out != null:
		out.store_string(JSON.stringify(total, "\t"))
		out.close()
	_print_report(total)
	print("by biome: %s" % JSON.stringify(total["by_biome"]))
	return 0
