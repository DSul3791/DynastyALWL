extends RefCounted

# The island resource landscape (docs/handoff/RESOURCE_DISTRIBUTION_ARCHITECTURE.md, Dave 21 Nov 2026; implementation notes and provisional
# values in docs/design/RESOURCE_DISTRIBUTION.md). Built once per server run from the baked tiles' coarse maps (32 m height and water class,
# read every second sample: a 64 m grid), on a worker thread, before any scatter cell is laid out, so every cell of a world sees the same
# landscape whatever order players walk in. Nothing here is saved: it is worked out again from the same tiles and seed, the same every run.
#
# What it holds, per 64 m cell of land:
# - island: the land mass the cell belongs to (8-connected land; lakes, rivers and wetland count as land), with its widest inland distance and peak;
# - journey 0..1: how far into the island's landscape the cell is, from the shore (0) to the headwaters under the high ground (1): the
#   distance from the sea over the island's own widest distance, the height over the island's peak, and the highest ground within
#   hill_reach_m (the mountains a cell lies under). Not absolute height alone, not distance from the world's origin.
# - field 0..1 for iron, copper and tin: the "paint" of the handoff. journey plus a smooth warped noise of its own per metal, cut at the
#   island's own quantile so each island is covered to its share (iron most, copper less, tin less again), blended over a narrow band so no
#   hard line shows. Different noise per metal, so the areas overlap without being rings. Small islands get smaller shares.
# - receiver: the next cell downhill (priority flood from the sea, so every cell drains to the sea through basins) and drain, the cells
#   draining through it. A cell with drain >= river_cells is a channel.
# - deposits: finite sources of each metal, deterministic from a world grid (deposit_grid_m) and the seed, likelier in the metal's field and
#   farther in; each has a place, a size 0..1, a radius and an id. The starting island is checked: if no source of a metal lies within its
#   route budget from spawn (walking cost over the grid, steep ground refused, the route kept under the high ground), the best reachable
#   candidate in its field becomes an assured source (handoff 13). Then the quantity: the ore in the outcrops of the sources within the
#   budget must cover the first bronze (first_bronze, from the live recipes) times ore_margin, and known_sources of each metal must lie
#   within it (several iron locations known before iron smelting); else up to three more assured sources.
# - clue per metal: rounded river finds below each source, strongest at the source and fading down its own drainage (river cells fade over
#   transport_m, hillside cells over hillslope_m; a lake ends it), so a find points up its own tributary and never up another.
# - coal 0..1: coal districts, hillsides and mountain edges with wet ground (lake, marsh, swamp, fen, bog) a short way off, where a noise of
#   its own says so (not every such slope); rivers count, since streams cut down through coal beds and show them in their banks. Seams: in a district, a coal layer at one height running along the hillside (along the contour)
#   for 60 to 200 m and back into the hill; the server works out its height from the real ground at its centre, lays dark outcrops where it
#   shows and gives coal to a shovel that digs inside its band, so a player can follow it into the hill.
# - veins: gold and silver veins from the deeper iron and tin sources, far apart, uphill under the mountain, as rows of pockets (the first
#   shown on the ground), gems deeper down by chance (boulders.json distribution veins, R-RES-PRECIOUS).
# - pockets: per source, a small chance of each find in the association table (boulders.json distribution pockets: which sources, how far
#   inland, near the source or down its river gravels, how deep); most sources have none. Deterministic from the source's id; the server
#   reveals one when a dig reaches it.
#
# All values from boulders.json "distribution" (PROVISIONAL, RD-1..).

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")

const METALS := ["iron", "copper", "tin"]
const SEA := 1            # water_classes.json ocean
const LAKE := 2
const RIVER := 3
const N8X := [-1, 0, 1, -1, 1, -1, 0, 1]
const N8Z := [-1, -1, -1, 0, 0, 1, 1, 1]

var cell_m: float = 64.0
var origin: Vector2 = Vector2.ZERO     # world x, z of cell (0, 0)'s sample point
var nx: int = 0
var nz: int = 0
var height: PackedFloat32Array = PackedFloat32Array()
var water: PackedByteArray = PackedByteArray()
var island: PackedInt32Array = PackedInt32Array()      # 0 sea, else 1.. island number
var journey: PackedFloat32Array = PackedFloat32Array()
var rich: PackedFloat32Array = PackedFloat32Array()    # 0..1, how rich the ground is in ore (_journey): highest at the mountain foot and first plateau
var field: PackedFloat32Array = PackedFloat32Array()   # 3 per cell: iron, copper, tin
var clue: PackedFloat32Array = PackedFloat32Array()    # 3 per cell
var coal: PackedFloat32Array = PackedFloat32Array()
var receiver: PackedInt32Array = PackedInt32Array()
var drain: PackedFloat32Array = PackedFloat32Array()
var deposits: Array = []          # {"metal", "x", "z", "size" 0..1, "radius" m, "id" int, "assured" bool}
var seams: Array = []             # {"id", "x", "z", "along" Vector2 (the contour), "up" Vector2 (into the hill), "length" m, "thick" m, "into" m, "out" m}
var pockets: Array = []           # {"id", "find", "x", "z", "depth" m under the generated ground, "r" m, "source" deposit id; a vein's: "vein" id, "show" on the ground}
var dangers: Array = []           # [x, z, radius m] of known dangers (hostile camps, bandit camps) the starting-island routes keep out of; set before building
var first_bronze: Dictionary = {}   # copper and tin ore the starting island's sources must hold within their route budgets (supply_inputs; set before building)
var ore_per_m3: float = 0.0       # stones a cubic metre of ore rock holds (the server's boulder rule; supply_inputs); 0 skips the quantity check
var ore_cost: Dictionary = {}     # metal -> stones one ore piece takes out of a rock (its weight in stones, server_items._ore_cost; supply_inputs)
var report: PackedStringArray = PackedStringArray()   # what the build found (the server log; the diagnostics tool)
var build_ms: float = 0.0
var built: bool = false           # every step of build finished

var _cfg: Dictionary = {}
var _seed: int = 0
var _bins: Dictionary = {}        # Vector2i (bin_m squares) -> PackedInt32Array of deposit indexes
var _bin_m: float = 512.0
var _seam_bins: Dictionary = {}   # the same squares -> seam indexes
var _pocket_bins: Dictionary = {} # the same squares -> pocket indexes
var _pocket_of: Dictionary = {}   # pocket id -> index in pockets
var _island_dmax: PackedFloat32Array = PackedFloat32Array()
var _island_peak: PackedFloat32Array = PackedFloat32Array()
var _spawn_cost: PackedFloat32Array = PackedFloat32Array()   # route costs from spawn over the starting island (_assure), for the look lines


# Reads every tile of `dir` (tile_<x>_<z>.tile: its low_height and low_water_class) into a grid of cell_m over their bounds, then builds.
# Stays empty (nx 0, ready() false) when the folder holds no readable tile.
func load_tiles(dir: String, tile_size_m: float, seed_value: int, cfg: Dictionary, spawn: Vector3) -> void:
	var started: int = Time.get_ticks_usec()
	var found: Array = []
	var lo: Vector2i = Vector2i(1 << 30, 1 << 30)
	var hi: Vector2i = Vector2i(-(1 << 30), -(1 << 30))

	for file in DirAccess.get_files_at(dir):
		if not file.begins_with("tile_") or not file.ends_with(".tile"):
			continue

		var parts: PackedStringArray = file.trim_prefix("tile_").trim_suffix(".tile").split("_")

		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue

		var t: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		found.append(t)
		lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))

	if found.is_empty():
		return

	var step_m: float = float(cfg.get("cell_m", 64.0))
	var per_tile: int = int(round(tile_size_m / step_m))
	var n_x: int = (hi.x - lo.x + 1) * per_tile + 1
	var n_z: int = (hi.y - lo.y + 1) * per_tile + 1
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n_x * n_z)
	heights.fill(NAN)
	var classes: PackedByteArray = PackedByteArray()
	classes.resize(n_x * n_z)
	classes.fill(SEA)
	found.sort()

	for t in found:
		var path: String = "%s/tile_%d_%d.tile" % [dir, t.x, t.y]
		var head: Dictionary = TileFileScript.read_header(path)

		if not head["ok"]:
			continue

		var header: Dictionary = head["header"]
		var low_n: int = int(header.get("low_res_samples", 0))
		var low_step: float = float(header.get("low_res_spacing_m", 32))
		var low_h: Dictionary = TileFileScript.read_section(path, head["table"], "low_height")
		var low_w: Dictionary = TileFileScript.read_section(path, head["table"], "low_water_class")

		if not low_h["ok"] or not low_w["ok"] or low_n < 2:
			continue

		var h: PackedFloat32Array = TileFileScript.decode_height(low_h["raw"], TileFileScript.height_step_of(header))
		var w: PackedByteArray = low_w["raw"]

		if h.size() != low_n * low_n or w.size() != low_n * low_n:
			continue

		var every: int = maxi(int(round(step_m / low_step)), 1)
		var base_x: int = (t.x - lo.x) * per_tile
		var base_z: int = (t.y - lo.y) * per_tile

		for j in range(per_tile + 1):
			var lj: int = mini(j * every, low_n - 1)

			for i in range(per_tile + 1):
				var li: int = mini(i * every, low_n - 1)
				var k: int = (base_z + j) * n_x + base_x + i
				heights[k] = h[lj * low_n + li]
				classes[k] = w[lj * low_n + li]

	build(heights, classes, n_x, n_z, Vector2(float(lo.x), float(lo.y)) * tile_size_m, step_m, seed_value, cfg, spawn)
	build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	report.append("resources: %d tiles read and built in %.0f ms" % [found.size(), build_ms])


# Builds everything from a height grid (NAN = no ground: sea) and water classes, n_x by n_z cells of step_m from world point `at`.
func build(heights: PackedFloat32Array, classes: PackedByteArray, n_x: int, n_z: int, at: Vector2, step_m: float, seed_value: int, cfg: Dictionary, spawn: Vector3) -> void:
	nx = n_x
	nz = n_z
	origin = at
	cell_m = step_m
	_cfg = cfg
	_seed = seed_value
	height = heights
	water = classes
	var count: int = nx * nz

	for k in range(count):
		if is_nan(height[k]):
			height[k] = -100.0
			water[k] = SEA

	_islands()
	var to_sea: PackedFloat32Array = _distance_to_sea()
	_journey(to_sea)
	_fields()
	_drainage()
	_coal()
	_deposits(spawn)
	_clues()
	_seams()
	_pockets()
	_look_lines()
	built = true   # last: a build that stopped part-way (a script error on the worker) is never published


func ready() -> bool:
	return built


# What the starting island's quantity check needs from the live game (handoff 13, "Bronze progression": accessible copper and tin cover
# the intended first bronze equipment and required construction costs; minimum quantities established from the actual game): read from
# recipes.json, blueprints.json, structures.json smelting and the boulder rule, so a change of any of them changes the check.
# Returns {"first_bronze": {"ingots", "copper", "tin", "players", "per_player": {...}}, "ore_per_m3"}.
static func supply_inputs(boulders: Dictionary) -> Dictionary:
	var read: Callable = func(path: String, key: String) -> Dictionary:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		return parsed.get(key, {}) if typeof(parsed) == TYPE_DICTIONARY else {}

	var kit: Dictionary = (boulders.get("distribution", {}) as Dictionary).get("first_bronze", {})
	var need: Dictionary = first_bronze_need(kit, read.call("res://data/items/recipes.json", "recipes"), read.call("res://data/items/blueprints.json", "blueprints"), read.call("res://data/items/structures.json", "smelting"))
	var carry: Dictionary = CarryRules.load_config()
	var stone_kg: float = maxf(CarryRules.weight_of("stone", carry), 0.05)
	var per_m3: float = float(boulders.get("height_ratio", 0.85)) * float(boulders.get("density_kg_m3", 2600)) * float(boulders.get("ore_yield", boulders.get("yield", 0.5))) / stone_kg
	var costs: Dictionary = {}   # ore is mined by weight: a piece takes its own weight out of the rock in stones (server_items._ore_cost)

	for metal in METALS:
		var item: String = str(((boulders.get("ore", {}) as Dictionary).get("items", {}) as Dictionary).get(metal, metal + "_ore"))
		costs[metal] = maxi(int(round(CarryRules.weight_of(item, carry) / stone_kg)), 1)

	return {"first_bronze": need, "ore_per_m3": per_m3, "ore_cost": costs}


# The copper and tin ore one player's first bronze takes (boulders.json distribution first_bronze: the tools, and the stations whose costs
# the way to iron requires), times the players a starting island serves. Every amount from the live recipes and blueprints: a tool's or a
# station's Bronze ingots, and the bronze fittings (nails, hinges) in whole forge batches at their recipe's own yield; then the smelter's
# bronze job (its copper and tin ore to its Bronze ingots). {} when the kit or the bronze job is missing.
static func first_bronze_need(kit: Dictionary, recipes: Dictionary, blueprints: Dictionary, smelting: Dictionary) -> Dictionary:
	var job: Dictionary = (smelting.get("jobs", {}) as Dictionary).get("bronze", {})

	if kit.is_empty() or job.is_empty():
		return {}

	var wants: Dictionary = {}   # item -> count, before the fittings are turned into ingots

	for piece in kit.get("tools", []):
		for need in (recipes.get(str(piece), {}) as Dictionary).get("needs", []):
			wants[str(need[0])] = int(wants.get(str(need[0]), 0)) + int(need[1])

	for bp in kit.get("builds", []):
		for need in (blueprints.get(str(bp), {}) as Dictionary).get("cost", []):
			wants[str(need[0])] = int(wants.get(str(need[0]), 0)) + int(need[1])

	var ingots: int = int(wants.get("bronze_ingot", 0))

	for item in wants:
		var recipe: Dictionary = recipes.get(str(item), {})
		var gives: Array = recipe.get("gives", [])

		if str(item) == "bronze_ingot" or gives.size() < 2 or int(gives[1]) <= 0:
			continue

		for need in recipe.get("needs", []):
			if str(need[0]) == "bronze_ingot":   # a bronze fitting: whole batches of its forge recipe
				ingots += ceili(float(wants[item]) / float(gives[1])) * int(need[1])

	var out: Array = job.get("out", [])
	var runs: int = ceili(float(ingots) / float(maxi(int(out[1]) if out.size() > 1 else 1, 1)))
	var per_player: Dictionary = {"copper": 0, "tin": 0}

	for put in job.get("in", []):
		var metal: String = str(put[0]).trim_suffix("_ore")

		if per_player.has(metal):
			per_player[metal] = runs * int(put[1])

	var players: int = maxi(int(kit.get("players", 1)), 1)
	return {"ingots": ingots, "copper": int(per_player["copper"]) * players, "tin": int(per_player["tin"]) * players, "players": players, "per_player": per_player}


# About how many ore pieces a source's outcrops hold (the server lays them out the same way, server_items._lay_out_sources: outcrop count
# and radius by size and the rock's own roll, stones by volume; the grade is the share of the rock's weight that comes out as ore, and a
# piece takes ore_cost stones of it, server_items._hit_boulder; fragments and loose pieces not counted).
func source_ore(d: Dictionary) -> float:
	var size: float = float(d["size"])
	var id: int = int(d["id"])
	var outcrops: int = int(round(lerpf(float(_cfg.get("source_outcrops_min", 2)), float(_cfg.get("source_outcrops_max", 8)), size)))
	var grades: Array = _cfg.get("source_grade", [0.4, 0.8])
	var grade: float = snappedf(lerpf(float(grades[0]), float(grades[1]), size), 0.01)
	var total: float = 0.0

	for k in range(outcrops):
		var r: float = lerpf(float(_cfg.get("source_outcrop_radius_min", 0.5)), float(_cfg.get("source_outcrop_radius_max", 1.4)), size) * lerpf(0.7, 1.0, unit(id, k, 3))
		total += float(maxi(int(4.0 / 3.0 * PI * r * r * r * ore_per_m3), 1)) * grade

	return total / float(maxi(int(ore_cost.get(str(d["metal"]), 1)), 1))


func cell_at(x: float, z: float) -> int:
	var i: int = int(round((x - origin.x) / cell_m))
	var j: int = int(round((z - origin.y) / cell_m))

	if i < 0 or j < 0 or i >= nx or j >= nz:
		return -1

	return j * nx + i


# Journey at a point, bilinear between the four cells round it (sea cells count as 0).
func journey_at(x: float, z: float) -> float:
	return _bilinear(journey, 1, 0, x, z)


# How rich the ground is at a point (0 at the shore, 1 at the mountain foot and on the first plateau, easing off up the mountain), bilinear.
func rich_at(x: float, z: float) -> float:
	return _bilinear(rich, 1, 0, x, z)


# A metal's field (0 iron, 1 copper, 2 tin) at a point, bilinear.
func field_at(metal: int, x: float, z: float) -> float:
	return _bilinear(field, 3, metal, x, z)


# A metal's river clue at a point: the strongest of the 3 x 3 cells round it (a river 8 m wide may lie in the next 64 m cell's sample).
func clue_at(metal: int, x: float, z: float) -> float:
	var c: int = cell_at(x, z)

	if c < 0:
		return 0.0

	var best: float = 0.0
	var ci: int = c % nx
	var cj: int = _div(c, nx)

	for dj in range(-1, 2):
		for di in range(-1, 2):
			var i: int = ci + di
			var j: int = cj + dj

			if i >= 0 and j >= 0 and i < nx and j < nz:
				best = maxf(best, clue[(j * nx + i) * 3 + metal])

	return best


func coal_at(x: float, z: float) -> float:
	return _bilinear(coal, 1, 0, x, z)


# The way downhill at a point (unit vector in x, z): toward the cell's receiver; ZERO at the sea or a cell without one.
func downhill_at(x: float, z: float) -> Vector2:
	var c: int = cell_at(x, z)

	if c < 0 or receiver[c] < 0:
		return Vector2.ZERO

	var r: int = receiver[c]
	return Vector2(float(r % nx - c % nx), float(_div(r, nx) - _div(c, nx))).normalized()


# Deposits whose centre lies within `reach` of (x, z): indexes into deposits, in their stable order.
func deposits_near(x: float, z: float, reach: float) -> PackedInt32Array:
	return _near(_bins, deposits, x, z, reach)


# Seams whose centre lies within `reach` of (x, z) (indexes into seams, in order).
func seams_near(x: float, z: float, reach: float) -> PackedInt32Array:
	return _near(_seam_bins, seams, x, z, reach)


# Pockets within `reach` of (x, z) (indexes into pockets, in order).
func pockets_near(x: float, z: float, reach: float) -> PackedInt32Array:
	return _near(_pocket_bins, pockets, x, z, reach)


# The pocket with this id, or {}.
func pocket(id: int) -> Dictionary:
	return pockets[int(_pocket_of[id])] if _pocket_of.has(id) else {}


func _near(bins: Dictionary, rows: Array, x: float, z: float, reach: float) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var b0: Vector2i = Vector2i(floori((x - reach) / _bin_m), floori((z - reach) / _bin_m))
	var b1: Vector2i = Vector2i(floori((x + reach) / _bin_m), floori((z + reach) / _bin_m))

	for bz in range(b0.y, b1.y + 1):
		for bx in range(b0.x, b1.x + 1):
			for n in bins.get(Vector2i(bx, bz), PackedInt32Array()):
				var d: Dictionary = rows[n]

				if Vector2(float(d["x"]) - x, float(d["z"]) - z).length() <= reach:
					out.append(n)

	out.sort()
	return out


func _bin_add(bins: Dictionary, x: float, z: float, n: int) -> void:
	var bin: Vector2i = Vector2i(floori(x / _bin_m), floori(z / _bin_m))

	if not bins.has(bin):
		bins[bin] = PackedInt32Array()

	var list: PackedInt32Array = bins[bin]
	list.append(n)
	bins[bin] = list   # a packed array copies on write: put it back


func _bilinear(values: PackedFloat32Array, stride: int, offset: int, x: float, z: float) -> float:
	var fx: float = (x - origin.x) / cell_m
	var fz: float = (z - origin.y) / cell_m
	var i: int = floori(fx)
	var j: int = floori(fz)
	var tx: float = fx - float(i)
	var tz: float = fz - float(j)
	var v: Array = [0.0, 0.0, 0.0, 0.0]

	for n in 4:
		var ii: int = i + (n & 1)
		var jj: int = j + (n >> 1)

		if ii >= 0 and jj >= 0 and ii < nx and jj < nz:
			v[n] = values[(jj * nx + ii) * stride + offset]

	return lerpf(lerpf(float(v[0]), float(v[1]), tx), lerpf(float(v[2]), float(v[3]), tx), tz)


# --- the build steps -------------------------------------------------------------------------------------------------------------------

func _land(k: int) -> bool:
	return water[k] != SEA


func _islands() -> void:
	island = PackedInt32Array()
	island.resize(nx * nz)
	var count: int = 0
	var stack: PackedInt32Array = PackedInt32Array()

	for k in range(nx * nz):
		if not _land(k) or island[k] != 0:
			continue

		count += 1
		island[k] = count
		stack.append(k)

		while not stack.is_empty():
			var c: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var ci: int = c % nx
			var cj: int = _div(c, nx)

			for n in 8:
				var i: int = ci + int(N8X[n])
				var j: int = cj + int(N8Z[n])

				if i < 0 or j < 0 or i >= nx or j >= nz:
					continue

				var o: int = j * nx + i

				if _land(o) and island[o] == 0:
					island[o] = count
					stack.append(o)

	_island_dmax = PackedFloat32Array()
	_island_dmax.resize(count + 1)
	_island_peak = PackedFloat32Array()
	_island_peak.resize(count + 1)


# Two-pass chamfer distance (m) to the nearest sea cell; also fills each island's widest distance and peak.
func _distance_to_sea() -> PackedFloat32Array:
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(nx * nz)

	for k in range(nx * nz):
		d[k] = 0.0 if not _land(k) else 1.0e9

	d = _chamfer(d)

	for k in range(nx * nz):
		var n: int = island[k]

		if n > 0:
			_island_dmax[n] = maxf(_island_dmax[n], d[k])
			_island_peak[n] = maxf(_island_peak[n], height[k])

	return d


# Two-pass chamfer distance (cell_m straight, cell_m x sqrt 2 diagonal): cells at 0 are the sources, the rest start large. Returns the distances.
func _chamfer(d: PackedFloat32Array) -> PackedFloat32Array:
	var a: float = cell_m
	var b: float = cell_m * sqrt(2.0)

	for j in range(nz):
		for i in range(nx):
			var k: int = j * nx + i

			if d[k] == 0.0:
				continue

			var v: float = d[k]

			if i > 0:
				v = minf(v, d[k - 1] + a)

			if j > 0:
				v = minf(v, d[k - nx] + a)

				if i > 0:
					v = minf(v, d[k - nx - 1] + b)

				if i < nx - 1:
					v = minf(v, d[k - nx + 1] + b)

			d[k] = v

	for j in range(nz - 1, -1, -1):
		for i in range(nx - 1, -1, -1):
			var k: int = j * nx + i

			if d[k] == 0.0:
				continue

			var v: float = d[k]

			if i < nx - 1:
				v = minf(v, d[k + 1] + a)

			if j < nz - 1:
				v = minf(v, d[k + nx] + a)

				if i < nx - 1:
					v = minf(v, d[k + nx + 1] + b)

				if i > 0:
					v = minf(v, d[k + nx - 1] + b)

			d[k] = v

	return d


# journey = w_inland x inland + w_height x height share + w_hill x hill share, each 0..1 against the island's own widest distance and peak
# (with floors, so a low islet is not all "mountain"). The hill is the highest ground within hill_reach_m, on a coarse grid (block_cells).
func _journey(to_sea: PackedFloat32Array) -> void:
	journey = PackedFloat32Array()
	journey.resize(nx * nz)
	var block: int = maxi(int(_cfg.get("hill_block_cells", 4)), 1)
	var bx: int = _div(nx + block - 1, block)
	var bz: int = _div(nz + block - 1, block)
	var block_max: PackedFloat32Array = PackedFloat32Array()
	block_max.resize(bx * bz)
	block_max.fill(0.0)

	for k in range(nx * nz):
		if _land(k):
			var b: int = _div(_div(k, nx), block) * bx + _div(k % nx, block)
			block_max[b] = maxf(block_max[b], height[k])

	var reach: int = maxi(int(round(float(_cfg.get("hill_reach_m", 768.0)) / (cell_m * float(block)))), 1)
	var hill: PackedFloat32Array = PackedFloat32Array()
	hill.resize(bx * bz)

	for j in range(bz):
		for i in range(bx):
			var best: float = 0.0

			for dj in range(-reach, reach + 1):
				for di in range(-reach, reach + 1):
					var ii: int = i + di
					var jj: int = j + dj

					if ii >= 0 and jj >= 0 and ii < bx and jj < bz:
						best = maxf(best, block_max[jj * bx + ii])

			hill[j * bx + i] = best

	var w_in: float = float(_cfg.get("journey_inland", 0.5))
	var w_h: float = float(_cfg.get("journey_height", 0.25))
	var w_hill: float = float(_cfg.get("journey_hill", 0.25))
	var dmin: float = float(_cfg.get("inland_floor_m", 1500.0))
	var pmin: float = float(_cfg.get("peak_floor_m", 150.0))
	# The rich layer (Dave 27 Nov 2026, the layered cake: "we need to make sure that super rich layer is right around the bottom of the mountain
	# or on the first plateau"): rich rises with the journey to 1 at rich_journey_full, then eases a little (rich_ease_up) above rich_foot_up of the peak
	# (over rich_band_up), so the mountain stays good but its foot is richest. Ore rocks and sources read it for their chances and sizes.
	var full_j: float = maxf(float(_cfg.get("rich_journey_full", 0.55)), 0.01)
	var foot_up: float = float(_cfg.get("rich_foot_up", 0.25))
	var band: float = maxf(float(_cfg.get("rich_band_up", 0.25)), 0.01)
	var ease_up: float = float(_cfg.get("rich_ease_up", 0.25))
	rich = PackedFloat32Array()
	rich.resize(nx * nz)

	for k in range(nx * nz):
		var n: int = island[k]

		if n == 0:
			continue

		var peak: float = maxf(_island_peak[n], pmin)
		var inland: float = clampf(to_sea[k] / maxf(_island_dmax[n], dmin), 0.0, 1.0)
		var up: float = clampf(height[k] / peak, 0.0, 1.0)
		var under: float = clampf(hill[_div(_div(k, nx), block) * bx + _div(k % nx, block)] / peak, 0.0, 1.0)
		journey[k] = clampf(w_in * inland + w_h * up + w_hill * under, 0.0, 1.0)
		rich[k] = _smooth(0.0, full_j, journey[k]) * (1.0 - ease_up * _smooth(foot_up, foot_up + band, up))


# The paint: per metal, score = journey + noise_amp x (warped noise - 0.5); the island's land is covered where the score passes its
# (1 - share) quantile, blended over +-edge. share = cover[metal] x the island's size factor (widest distance small_island_m..+span: 0..1;
# iron never under iron_floor of its cover).
func _fields() -> void:
	field = PackedFloat32Array()
	field.resize(nx * nz * 3)
	var covers: Dictionary = _cfg.get("cover", {"iron": 0.9, "copper": 0.6, "tin": 0.4})
	var amp: float = float(_cfg.get("noise_amp", 0.55))
	var edge: float = float(_cfg.get("edge", 0.05))
	var small_m: float = float(_cfg.get("small_island_m", 400.0))
	var span_m: float = maxf(float(_cfg.get("small_island_span_m", 1600.0)), 1.0)
	var iron_floor: float = float(_cfg.get("iron_floor", 0.6))
	var islands: int = _island_dmax.size()
	var members: Array = []

	for n in range(islands):
		members.append(PackedInt32Array())

	for k in range(nx * nz):
		if island[k] > 0:
			var list_of: PackedInt32Array = members[island[k]]
			list_of.append(k)
			members[island[k]] = list_of   # a packed array copies on write: put it back

	for m in 3:
		var score: PackedFloat32Array = _noise_grid(String(METALS[m]))

		for k in range(nx * nz):
			if island[k] > 0:
				score[k] = journey[k] + amp * (score[k] - 0.5)

		for n in range(1, islands):
			var list: PackedInt32Array = members[n]

			if list.is_empty():
				continue

			var size: float = clampf((_island_dmax[n] - small_m) / span_m, 0.0, 1.0)

			if m == 0:
				size = maxf(size, iron_floor)

			var share: float = float(covers.get(METALS[m], 0.0)) * size

			if share <= 0.01:
				continue

			var sorted: PackedFloat32Array = PackedFloat32Array()
			sorted.resize(list.size())

			for q in range(list.size()):
				sorted[q] = score[list[q]]

			sorted.sort()
			var cut: float = sorted[clampi(int(float(list.size()) * (1.0 - share)), 0, list.size() - 1)]

			for k in list:
				field[k * 3 + m] = _smooth(cut - edge, cut + edge, score[k])


# Whole-number division without the integer_division warning (exact: every value here is far under 2^52).
static func _div(a: int, b: int) -> int:
	return floori(float(a) / float(b))


static func _smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# A metal's warped value noise (0..1) over the grid, worked on a coarse lattice (noise_block_cells) and read bilinearly: the waves are
# kilometres long, so the 64 m cells need no noise of their own.
func _noise_grid(purpose: String, wave_m: float = 0.0) -> PackedFloat32Array:
	var block: int = maxi(int(_cfg.get("noise_block_cells", 4)), 1)
	var bx: int = _div(nx + block - 1, block) + 1
	var bz: int = _div(nz + block - 1, block) + 1
	var base: int = _hash(_seed, purpose.hash())
	var wave: float = wave_m if wave_m > 0.0 else float(_cfg.get("noise_wave_m", 3200.0))
	var warp_wave: float = float(_cfg.get("warp_wave_m", 2400.0))
	var warp: float = float(_cfg.get("warp_m", 1600.0))
	var coarse: PackedFloat32Array = PackedFloat32Array()
	coarse.resize(bx * bz)

	for j in range(bz):
		for i in range(bx):
			var x: float = origin.x + float(i * block) * cell_m
			var z: float = origin.y + float(j * block) * cell_m
			var wx: float = (fbm(x, z, warp_wave, base + 11, 2) - 0.5) * warp
			var wz: float = (fbm(x, z, warp_wave, base + 13, 2) - 0.5) * warp
			coarse[j * bx + i] = fbm(x + wx, z + wz, wave, base, 3)

	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(nx * nz)

	for j in range(nz):
		var cj: int = _div(j, block)
		var tz: float = float(j % block) / float(block)

		for i in range(nx):
			var ci: int = _div(i, block)
			var tx: float = float(i % block) / float(block)
			var a: float = lerpf(coarse[cj * bx + ci], coarse[cj * bx + ci + 1], tx)
			var c: float = lerpf(coarse[(cj + 1) * bx + ci], coarse[(cj + 1) * bx + ci + 1], tx)
			out[j * nx + i] = lerpf(a, c, tz)

	return out


# 32-bit integer hash (lowbias32): the same on every machine, unlike hash() of a Variant.
static func _hash(a: int, b: int) -> int:
	var x: int = (a ^ (b * 0x9e3779b1)) & 0xffffffff
	x ^= x >> 16
	x = (x * 0x7feb352d) & 0xffffffff
	x ^= x >> 15
	x = (x * 0x846ca68b) & 0xffffffff
	x ^= x >> 16
	return x


static func unit(a: int, b: int, c: int = 0, d: int = 0) -> float:
	return float(_hash(_hash(_hash(a, b), c), d)) / 4294967296.0


static func value_noise(x: float, z: float, wave: float, seed_value: int) -> float:
	var fx: float = x / wave
	var fz: float = z / wave
	var ix: int = floori(fx)
	var iz: int = floori(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	tx = tx * tx * (3.0 - 2.0 * tx)
	tz = tz * tz * (3.0 - 2.0 * tz)
	var a: float = lerpf(unit(seed_value, ix, iz), unit(seed_value, ix + 1, iz), tx)
	var b: float = lerpf(unit(seed_value, ix, iz + 1), unit(seed_value, ix + 1, iz + 1), tx)
	return lerpf(a, b, tz)


static func fbm(x: float, z: float, wave: float, seed_value: int, octaves: int) -> float:
	var total: float = 0.0
	var weight: float = 1.0
	var sum: float = 0.0
	var w: float = wave

	for o in range(octaves):
		total += weight * value_noise(x, z, w, seed_value + o * 7919)
		sum += weight
		weight *= 0.5
		w *= 0.5

	return total / sum


# Priority flood from the sea (a bucket queue by height in flood_step_m steps; ties first in, first out): every land cell's receiver is the
# cell the flood reached it from, so water runs to the sea through every basin, then drain counts the cells above each.
func _drainage() -> void:
	var count: int = nx * nz
	receiver = PackedInt32Array()
	receiver.resize(count)
	receiver.fill(-1)
	drain = PackedFloat32Array()
	drain.resize(count)
	drain.fill(1.0)
	var step: float = maxf(float(_cfg.get("flood_step_m", 0.5)), 0.01)
	var buckets: Dictionary = {}     # level -> PackedInt32Array, filled in order
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(count)
	var popped: PackedInt32Array = PackedInt32Array()
	var lowest: int = 1 << 30
	var highest: int = -(1 << 30)

	for k in range(count):
		if not _land(k):
			continue

		var ci: int = k % nx
		var cj: int = _div(k, nx)

		for n in 8:
			var i: int = ci + int(N8X[n])
			var j: int = cj + int(N8Z[n])

			if i >= 0 and j >= 0 and i < nx and j < nz and not _land(j * nx + i):
				var level: int = int(floor(maxf(height[k], 0.0) / step))
				_push(buckets, level, k)
				lowest = mini(lowest, level)
				highest = maxi(highest, level)
				seen[k] = 1
				break

	var level_now: int = lowest

	while level_now <= highest:
		if not buckets.has(level_now):
			level_now += 1
			continue

		var queue: PackedInt32Array = buckets[level_now]
		var at: int = 0

		while at < queue.size():
			var c: int = queue[at]
			at += 1
			popped.append(c)
			var ci: int = c % nx
			var cj: int = _div(c, nx)

			for n in 8:
				var i: int = ci + int(N8X[n])
				var j: int = cj + int(N8Z[n])

				if i < 0 or j < 0 or i >= nx or j >= nz:
					continue

				var o: int = j * nx + i

				if seen[o] == 1 or not _land(o):
					continue

				seen[o] = 1
				receiver[o] = c
				var level: int = maxi(int(floor(maxf(height[o], 0.0) / step)), level_now)

				if level == level_now:
					queue.append(o)
				else:
					_push(buckets, level, o)
					highest = maxi(highest, level)

		buckets.erase(level_now)
		level_now += 1

	for q in range(popped.size() - 1, -1, -1):
		var c: int = popped[q]

		if receiver[c] >= 0:
			drain[receiver[c]] += drain[c]


static func _push(buckets: Dictionary, level: int, k: int) -> void:
	if not buckets.has(level):
		buckets[level] = PackedInt32Array()

	var list: PackedInt32Array = buckets[level]
	list.append(k)
	buckets[level] = list


# Coal districts (distribution coal): dry land on a hillside (slope over slope_min, full at slope_full) with water (wet_classes: lake, river,
# marsh, swamp, fen, bog) within wet_reach_m, where the district noise (wave_m) passes its cut. 0..1 per cell, smooth at the edges.
func _coal() -> void:
	coal = PackedFloat32Array()
	coal.resize(nx * nz)
	var cfg: Dictionary = _cfg.get("coal", {})

	if cfg.is_empty():
		return

	var wet: Dictionary = {}   # the classes as int keys: JSON gives floats, and Array.has(2) never matches a 2.0

	for c in cfg.get("wet_classes", [2, 3, 4, 6, 7, 8]):
		wet[int(c)] = true

	var to_wet: PackedFloat32Array = PackedFloat32Array()
	to_wet.resize(nx * nz)

	for k in range(nx * nz):
		to_wet[k] = 0.0 if wet.has(int(water[k])) else 1.0e9

	to_wet = _chamfer(to_wet)
	var noise: PackedFloat32Array = _noise_grid("coal", float(cfg.get("wave_m", 1600.0)))
	var cut: float = float(cfg.get("noise_cut", 0.5))
	var edge: float = float(cfg.get("noise_edge", 0.05))
	var reach: float = float(cfg.get("wet_reach_m", 400.0))
	var s0: float = float(cfg.get("slope_min", 0.08))
	var s1: float = float(cfg.get("slope_full", 0.25))

	for j in range(1, nz - 1):
		for i in range(1, nx - 1):
			var k: int = j * nx + i

			if water[k] != 0 or island[k] == 0 or to_wet[k] > reach:
				continue

			var slope: float = 0.0

			for o in [k - 1, k + 1, k - nx, k + nx]:
				slope = maxf(slope, absf(height[k] - height[o]) / cell_m)

			coal[k] = _smooth(s0, s1, slope) * (1.0 - _smooth(reach * 0.5, reach, to_wet[k])) * _smooth(cut - edge, cut + edge, noise[k])


# Deposits on a world grid of deposit_grid_m: each grid square, per metal, one candidate point (jittered inside the square) that becomes a
# source with chance base x field x (1 - farther + farther x journey). Sources never sit in a lake, a river cell or the sea. Then the
# starting island's check (_assure).
func _deposits(spawn: Vector3) -> void:
	deposits = []
	_bins = {}
	_bin_m = float(_cfg.get("bin_m", 512.0))
	var grid_m: float = float(_cfg.get("deposit_grid_m", 384.0))
	var bases: Dictionary = _cfg.get("deposit_chance", {"iron": 0.1, "copper": 0.22, "tin": 0.22})
	var farther: float = float(_cfg.get("deposit_farther", 0.6))
	var r_min: float = float(_cfg.get("deposit_radius_min_m", 8.0))
	var r_max: float = float(_cfg.get("deposit_radius_max_m", 30.0))
	var g0: Vector2i = Vector2i(floori(origin.x / grid_m), floori(origin.y / grid_m))
	var g1: Vector2i = Vector2i(floori((origin.x + float(nx) * cell_m) / grid_m), floori((origin.y + float(nz) * cell_m) / grid_m))

	for gz in range(g0.y, g1.y + 1):
		for gx in range(g0.x, g1.x + 1):
			for m in 3:
				var x: float = (float(gx) + 0.15 + 0.7 * unit(_seed ^ 0x5eed, gx, gz, m * 8 + 1)) * grid_m
				var z: float = (float(gz) + 0.15 + 0.7 * unit(_seed ^ 0x5eed, gx, gz, m * 8 + 2)) * grid_m
				var k: int = cell_at(x, z)

				if k < 0 or not _land(k) or water[k] == LAKE or water[k] == RIVER:
					continue

				var f: float = field[k * 3 + m]

				if f <= 0.02:
					continue

				var p: float = float(bases.get(METALS[m], 0.0)) * f * (1.0 - farther + farther * rich[k])

				if unit(_seed ^ 0x5eed, gx, gz, m * 8 + 3) >= p:
					continue

				var size: float = clampf(rich[k] * 0.7 + 0.3 * unit(_seed ^ 0x5eed, gx, gz, m * 8 + 4), 0.0, 1.0)
				_add_deposit(m, x, z, size, lerpf(r_min, r_max, size), _hash(_hash(gx, gz), m), false)

	_assure(spawn)


func _add_deposit(m: int, x: float, z: float, size: float, radius: float, id: int, assured: bool) -> void:
	deposits.append({"metal": METALS[m], "m": m, "x": x, "z": z, "size": size, "radius": radius, "id": id, "assured": assured})
	_bin_add(_bins, x, z, deposits.size() - 1)


# The starting island (handoff 13): route costs from spawn over its land (cell length x (1 + slope_cost x slope^2), a river cell adds
# river_cost_m, ground steeper than max_slope refused, cells over high_share of the island's peak refused: the hardest mountain ground;
# cells within a known danger's radius refused: existing danger information, so early tin is not only behind an encounter).
# Per metal, if no source lies within route_budget_m[metal], the reachable land cell of best field (then nearest) becomes an assured source
# of size assured_size. Each finding goes into `report`.
func _assure(spawn: Vector3) -> void:
	var start: int = -1
	var start_m: float = INF

	for dz in range(-3, 4):   # spawn stands on the shore: the nearest land cell within three cells
		for dx in range(-3, 4):
			var k: int = cell_at(spawn.x + float(dx) * cell_m, spawn.z + float(dz) * cell_m)

			if k >= 0 and island[k] != 0 and Vector2(float(dx), float(dz)).length() < start_m:
				start = k
				start_m = Vector2(float(dx), float(dz)).length()

	if start < 0:
		report.append("resources: spawn %s is not on a land cell of the tiles; no starting-island check" % str(spawn))
		return

	var home: int = island[start]
	var cost: PackedFloat32Array = _route_costs(start, home)
	_spawn_cost = cost
	var budgets: Dictionary = _cfg.get("route_budget_m", {"iron": 3000.0, "copper": 3000.0, "tin": 6000.0})

	var margin: float = float(_cfg.get("ore_margin", 2.0))

	for m in 3:
		var best_route: float = INF

		for d in deposits:
			if int(d["m"]) == m:
				var k: int = cell_at(float(d["x"]), float(d["z"]))
				best_route = minf(best_route, cost[k] if k >= 0 else INF)

		var budget: float = float(budgets.get(METALS[m], 3000.0))

		if best_route <= budget:
			report.append("resources: nearest %s source %.0f m by route from spawn (budget %.0f)" % [METALS[m], best_route, budget])
		elif _assure_one(m, cost, home, budget, "nearest drawn one %.0f m" % best_route) < 0:
			report.append("resources: NO reachable %s ground within %.0f m of spawn (nearest source %.0f m): the starting island fails for %s" % [METALS[m], budget, best_route, METALS[m]])
			continue

		# Enough of it (handoff 13, bronze progression): the outcrops of the sources within the budget against the first bronze, times
		# ore_margin (outcrops lost to water or steep ground, ore spent on other things); and known_sources of it within the budget
		# (iron: "players may already know several iron locations before they can process it"). Short: one more assured source, up to three.
		var need: float = float(first_bronze.get(METALS[m], 0)) * margin if ore_per_m3 > 0.0 else 0.0
		var known: int = int((_cfg.get("known_sources", {}) as Dictionary).get(METALS[m], 1))

		if need <= 0.0 and known <= 1:
			continue

		var held: float = 0.0
		var count: int = 0

		for d in deposits:
			var k: int = cell_at(float(d["x"]), float(d["z"]))

			if int(d["m"]) == m and k >= 0 and cost[k] <= budget:
				held += source_ore(d) if ore_per_m3 > 0.0 else 0.0
				count += 1

		var added: int = 0

		while (held < need or count < known) and added < 3:
			var n: int = _assure_one(m, cost, home, budget, "%d of %d sources, about %.0f ore of %.0f wanted" % [count, known, held, need])

			if n < 0:
				break

			held += source_ore(deposits[n]) if ore_per_m3 > 0.0 else 0.0
			count += 1
			added += 1

		var ok: bool = held >= need and count >= known
		report.append("resources: %s within %.0f m of spawn: %d sources (%d wanted), about %.0f ore in their outcrops; first bronze for %d players takes %d (x%.1f margin): %s" % [METALS[m], budget, count, known, held, int(first_bronze.get("players", 1)), int(first_bronze.get(METALS[m], 0)), margin, "enough" if ok else "SHORT"])


# One assured source of metal m: the reachable land cell of best field (then nearest) within the budget that holds no source of it yet.
# Returns its index in deposits, or -1 when the island has no such ground.
func _assure_one(m: int, cost: PackedFloat32Array, home: int, budget: float, why: String) -> int:
	var taken: Dictionary = {}

	for d in deposits:
		if int(d["m"]) == m:
			taken[cell_at(float(d["x"]), float(d["z"]))] = true

	var pick: int = -1
	var pick_score: float = -INF

	for k in range(nx * nz):
		if island[k] != home or cost[k] > budget or water[k] == LAKE or water[k] == RIVER or field[k * 3 + m] < 0.5 or taken.has(k):
			continue

		var score: float = field[k * 3 + m] - cost[k] / budget * 0.25   # the best paint, nearer breaking ties

		if score > pick_score:
			pick_score = score
			pick = k

	if pick < 0:
		return -1

	var x: float = origin.x + float(pick % nx) * cell_m
	var z: float = origin.y + float(_div(pick, nx)) * cell_m
	var size: float = float(_cfg.get("assured_size", 0.5))
	_add_deposit(m, x, z, size, lerpf(float(_cfg.get("deposit_radius_min_m", 8.0)), float(_cfg.get("deposit_radius_max_m", 30.0)), size), _hash(_hash(pick, 0xa55), m), true)
	report.append("resources: assured %s source at %.0f, %.0f, %.0f m by route from spawn (%s)" % [METALS[m], x, z, cost[pick], why])
	return deposits.size() - 1


# Where to look (the server log and resource_report.txt; Lane A's pictures, 22 Nov 2026: estimated spots showed nothing): world positions
# of the nearest sources of each metal by route from spawn with their biggest outcrop (the server lays outcrops exactly so:
# server_items._lay_out_sources; one under deep water is left out there), the nearest coal seams (their middle outcrop sits about at the
# centre, the rest every outcrop_every_m along the contour; a seam in non-sedimentary rock shows nothing, decided in game), and the
# nearest pocket of each find (buried, opened by a dig). Lines "resources: look ...". Off the starting island: nothing.
func _look_lines() -> void:
	if _spawn_cost.size() != nx * nz:
		return

	var dist: Callable = func(x: float, z: float) -> float:
		var at: int = cell_at(x, z)
		return _spawn_cost[at] if at >= 0 else INF

	var per_metal: int = int(_cfg.get("look_sources", 3))

	for m in 3:
		var rows: Array = []

		for d in deposits:
			var to_d: float = float(dist.call(float(d["x"]), float(d["z"])))

			if int(d["m"]) == m and is_finite(to_d):
				rows.append([to_d, d])

		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])

		for row in rows.slice(0, per_metal):
			var src: Dictionary = row[1]
			var size: float = float(src["size"])
			var outcrops: int = int(round(lerpf(float(_cfg.get("source_outcrops_min", 2)), float(_cfg.get("source_outcrops_max", 8)), size)))
			var best: Vector2 = Vector2(float(src["x"]), float(src["z"]))
			var best_u: float = -1.0

			for k in range(outcrops):
				var u3: float = unit(int(src["id"]), k, 3)

				if u3 > best_u:
					best_u = u3
					best = Vector2(float(src["x"]), float(src["z"])) + Vector2(sqrt(unit(int(src["id"]), k, 1)) * float(src["radius"]), 0.0).rotated(unit(int(src["id"]), k, 2) * TAU)

			var r: float = lerpf(float(_cfg.get("source_outcrop_radius_min", 0.5)), float(_cfg.get("source_outcrop_radius_max", 1.4)), size) * lerpf(0.7, 1.0, best_u)
			report.append("resources: look %s source at %.1f, %.1f (%d outcrops within %.0f m%s), biggest outcrop at %.1f, %.1f (radius %.1f m), %.0f m by route" % [METALS[m], float(src["x"]), float(src["z"]), outcrops, float(src["radius"]), ", assured" if bool(src["assured"]) else "", best.x, best.y, r, row[0]])

	var seam_rows: Array = []

	for seam in seams:
		var to_seam: float = float(dist.call(float(seam["x"]), float(seam["z"])))

		if is_finite(to_seam):
			seam_rows.append([to_seam, seam])

	seam_rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var coal_cfg: Dictionary = (_cfg.get("coal", {}) as Dictionary)

	for row in seam_rows.slice(0, int(_cfg.get("look_seams", 6))):
		var near: Dictionary = row[1]
		var along: Vector2 = near["along"]
		var up: Vector2 = near["up"]
		report.append("resources: look coal seam at %.1f, %.1f, %.0f m long along %.2f, %.2f (uphill %.2f, %.2f), outcrops every %.0f m, %.0f m by route" % [float(near["x"]), float(near["z"]), float(near["length"]), along.x, along.y, up.x, up.y, float(coal_cfg.get("outcrop_every_m", 14.0)), row[0]])

	var by_find: Dictionary = {}

	for p in pockets:
		var route: float = float(dist.call(float(p["x"]), float(p["z"])))

		var kind: String = str(p["find"]) + (" vein outcrop" if p.has("show") else " vein" if p.has("vein") else " pocket")

		if is_finite(route) and (not by_find.has(kind) or route < float(by_find[kind][0])):
			by_find[kind] = [route, p]

	for f in by_find:
		var found: Dictionary = by_find[f][1]
		report.append("resources: look %s at %.1f, %.1f, %.1f m down, %.0f m by route" % [str(f), float(found["x"]), float(found["z"]), float(found["depth"]), float(by_find[f][0])])

	_spawn_cost = PackedFloat32Array()   # only the look lines read it


# Dijkstra over one island from cell `start` (binary heap of [cost, cell]).
func _route_costs(start: int, home: int) -> PackedFloat32Array:
	var cost: PackedFloat32Array = PackedFloat32Array()
	cost.resize(nx * nz)
	cost.fill(INF)
	cost[start] = 0.0
	var heap: Array = [[0.0, start]]
	var slope_cost: float = float(_cfg.get("slope_cost", 8.0))
	var max_slope: float = float(_cfg.get("max_slope", 0.7))
	var river_cost: float = float(_cfg.get("river_cost_m", 150.0))
	var high: float = _island_peak[home] * float(_cfg.get("high_share", 0.6))
	var unsafe: PackedByteArray = _danger_cells()

	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var c: int = int(top[1])

		if float(top[0]) > cost[c]:
			continue

		var ci: int = c % nx
		var cj: int = _div(c, nx)

		for n in 8:
			var i: int = ci + int(N8X[n])
			var j: int = cj + int(N8Z[n])

			if i < 0 or j < 0 or i >= nx or j >= nz:
				continue

			var o: int = j * nx + i

			if island[o] != home or height[o] > high or unsafe[o] == 1:
				continue

			var step: float = cell_m * (1.4142 if int(N8X[n]) != 0 and int(N8Z[n]) != 0 else 1.0)
			var slope: float = absf(height[o] - height[c]) / step

			if slope > max_slope:
				continue

			var next: float = cost[c] + step * (1.0 + slope_cost * slope * slope) + (river_cost if water[o] == RIVER else 0.0)

			if next < cost[o]:
				cost[o] = next
				_heap_push(heap, [cost[o], o])   # the stored (float32) cost: pushing the float64 one would make the pop above see it as stale and skip the cell

	return cost


# The cells within a danger's radius (dangers), 1; the rest 0. Their count goes into `report`.
func _danger_cells() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(nx * nz)
	var marked: int = 0

	for d in dangers:
		var at: Vector2 = Vector2(float(d[0]), float(d[1]))
		var r: float = float(d[2])
		var i0: int = floori((at.x - r - origin.x) / cell_m)
		var j0: int = floori((at.y - r - origin.y) / cell_m)

		for j in range(maxi(j0, 0), mini(j0 + int(ceil(2.0 * r / cell_m)) + 2, nz)):
			for i in range(maxi(i0, 0), mini(i0 + int(ceil(2.0 * r / cell_m)) + 2, nx)):
				if out[j * nx + i] == 0 and (origin + Vector2(float(i), float(j)) * cell_m).distance_to(at) <= r:
					out[j * nx + i] = 1
					marked += 1

	report.append("resources: %d known dangers keep %d cells off the starting-island routes" % [dangers.size(), marked])
	return out


static func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i: int = heap.size() - 1

	while i > 0:
		var p: int = _div(i - 1, 2)

		if float(heap[p][0]) <= float(item[0]):
			break

		heap[i] = heap[p]
		i = p

	heap[i] = item


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()

	if heap.is_empty():
		return top

	var i: int = 0
	var size: int = heap.size()

	while true:
		var l: int = i * 2 + 1

		if l >= size:
			break

		var r: int = l + 1
		var c: int = r if r < size and float(heap[r][0]) < float(heap[l][0]) else l

		if float(heap[c][0]) >= float(last[0]):
			break

		heap[i] = heap[c]
		i = c

	heap[i] = last
	return top


# River clues: from each source down its receivers, strength 1 at the source, x exp(-step / transport_m[metal]) along a channel
# (drain >= river_cells), x exp(-step / hillslope_m) on the way down a hillside to the first channel; ends in a lake, at the sea or under
# clue_floor. Each cell keeps the strongest clue of each metal.
func _clues() -> void:
	clue = PackedFloat32Array()
	clue.resize(nx * nz * 3)
	var transport: Dictionary = _cfg.get("transport_m", {"iron": 3000.0, "copper": 1800.0, "tin": 1200.0})
	var hillslope: float = float(_cfg.get("hillslope_m", 300.0))
	var river_cells: float = float(_cfg.get("river_cells", 85.0))
	var floor_s: float = float(_cfg.get("clue_floor", 0.08))

	for d in deposits:
		var m: int = int(d["m"])
		var reach: float = float(transport.get(METALS[m], 1500.0))
		var c: int = cell_at(float(d["x"]), float(d["z"]))
		var s: float = 1.0

		while c >= 0:
			if water[c] == LAKE:
				break

			clue[c * 3 + m] = maxf(clue[c * 3 + m], s)
			var r: int = receiver[c]

			if r < 0:
				break

			var step: float = cell_m * (1.4142 if (r % nx != c % nx and _div(r, nx) != _div(c, nx)) else 1.0)
			s *= exp(-step / (reach if drain[c] >= river_cells else hillslope))

			if s < floor_s:
				break

			c = r


# Seams (distribution coal): one candidate per seam_grid_m square (jittered), a seam with chance seam_chance x coal there where coal passes
# seam_min. It runs along the contour (across the slope of the coarse ground), length_m and thick_m by a draw, and reaches into_m into the
# hill (out_m out of it, where the hillside drops below it). Its height is not here: the server reads the real ground at its centre.
func _seams() -> void:
	seams = []
	_seam_bins = {}
	var cfg: Dictionary = _cfg.get("coal", {})

	if cfg.is_empty() or coal.is_empty():
		return

	var grid_m: float = float(cfg.get("seam_grid_m", 256.0))
	var lengths: Array = cfg.get("length_m", [60.0, 200.0])
	var thicks: Array = cfg.get("thick_m", [1.2, 2.5])
	var g0: Vector2i = Vector2i(floori(origin.x / grid_m), floori(origin.y / grid_m))
	var g1: Vector2i = Vector2i(floori((origin.x + float(nx) * cell_m) / grid_m), floori((origin.y + float(nz) * cell_m) / grid_m))
	var salt: int = _seed ^ 0xc0a1

	for gz in range(g0.y, g1.y + 1):
		for gx in range(g0.x, g1.x + 1):
			var x: float = (float(gx) + 0.1 + 0.8 * unit(salt, gx, gz, 1)) * grid_m
			var z: float = (float(gz) + 0.1 + 0.8 * unit(salt, gx, gz, 2)) * grid_m
			var c: float = coal_at(x, z)

			if c < float(cfg.get("seam_min", 0.2)) or unit(salt, gx, gz, 3) >= float(cfg.get("seam_chance", 0.6)) * c:
				continue

			var up: Vector2 = _uphill(x, z)

			if up == Vector2.ZERO:
				continue

			var u: float = unit(salt, gx, gz, 4)
			seams.append({"id": _hash(_hash(gx, gz), 0xc0a1), "x": x, "z": z, "along": up.orthogonal(), "up": up,
				"length": lerpf(float(lengths[0]), float(lengths[1]), u), "thick": lerpf(float(thicks[0]), float(thicks[1]), unit(salt, gx, gz, 5)),
				"into": float(cfg.get("into_m", 80.0)), "out": float(cfg.get("out_m", 12.0))})
			_bin_add(_seam_bins, x, z, seams.size() - 1)

	report.append("resources: %d coal seams" % seams.size())


# The way uphill at a point (unit x, z) from the coarse ground's slope round its cell; ZERO on the flat or off the grid.
func _uphill(x: float, z: float) -> Vector2:
	var k: int = cell_at(x, z)

	if k < 0 or k % nx == 0 or k % nx == nx - 1 or k < nx or k >= nx * (nz - 1):
		return Vector2.ZERO

	var g: Vector2 = Vector2(height[k + 1] - height[k - 1], height[k + nx] - height[k - nx])
	return g.normalized() if g.length() > 0.5 else Vector2.ZERO


# Pockets (distribution pockets): for every source, each table row whose metals and journey band it fits rolls per_source times with
# chance x (0.5 + the source's size); a pocket lies near the source (within its radius x 1.2) or, for place "gravel", in the river gravels
# 1..gravel_cells cells down its drainage. depth_m under the generated ground; found by a dig within r_m of it.
func _pockets() -> void:
	pockets = []
	_pocket_bins = {}
	_pocket_of = {}
	var table: Array = _cfg.get("pockets", [])

	for d in deposits:
		var id: int = int(d["id"])
		var c: int = cell_at(float(d["x"]), float(d["z"]))
		var j: float = journey[c] if c >= 0 else 0.0

		for e in range(table.size()):
			var row: Dictionary = table[e]

			if not (row.get("metals", []) as Array).has(str(d["metal"])) or j < float(row.get("journey_min", 0.0)) or j > float(row.get("journey_max", 1.0)):
				continue

			for q in int(row.get("per_source", 1)):
				var salt: int = _hash(id, 0x90c + e * 16 + q)

				if unit(salt, 1) >= float(row.get("chance", 0.0)) * (0.5 + float(d["size"])):
					continue

				var at: Vector2 = Vector2(float(d["x"]), float(d["z"])) + Vector2(sqrt(unit(salt, 2)) * float(d["radius"]) * 1.2, 0.0).rotated(unit(salt, 3) * TAU)

				if str(row.get("place", "source")) == "gravel":
					var cell: int = c
					var steps: int = 1 + int(unit(salt, 4) * float(row.get("gravel_cells", 6)))

					for _s in steps:
						if cell < 0 or receiver[cell] < 0 or water[receiver[cell]] == LAKE or not _land(receiver[cell]):
							break

						cell = receiver[cell]

					if cell < 0 or cell == c:
						continue

					at = origin + Vector2(float(cell % nx), float(_div(cell, nx))) * cell_m + Vector2(unit(salt, 5) - 0.5, unit(salt, 6) - 0.5) * cell_m * 0.6

				var depths: Array = row.get("depth_m", [0.6, 1.8])
				var pid: int = salt & 0x3fffffff

				if _pocket_of.has(pid):
					continue

				_pocket_of[pid] = pockets.size()
				pockets.append({"id": pid, "find": str(row.get("find", "")), "x": at.x, "z": at.y, "depth": lerpf(float(depths[0]), float(depths[1]), unit(salt, 7)),
					"r": float(row.get("r_m", 1.5)), "source": id})
				_bin_add(_pocket_bins, at.x, at.y, pockets.size() - 1)

	_veins()
	var by_find: Dictionary = {}

	for p in pockets:
		by_find[p["find"]] = int(by_find.get(p["find"], 0)) + 1

	report.append("resources: %d pockets %s" % [pockets.size(), str(by_find)])


# Gold and silver veins (distribution veins, R-RES-PRECIOUS, Dave 27 Nov 2026: "in veins along side the deeper iron, tin veins under the
# mountains or up in the mountains ... spread so as to entice the players to travel"). An iron or tin source at journey_min or farther in
# starts one with chance x (0.5 + its size), unless another vein starts within gap_m (so they lie far apart). It runs uphill from the
# source's edge, under the mountain, for length_m: a row of pockets every step_m, the first outcrop_points shown on the ground ("show":
# the server lays them as rocks with no dig), the rest buried ever deeper (depth_m along it). Under each buried pocket a gem lies a
# little deeper with chance gem_per_m x its depth: the deeper the dig, the likelier a gem (gems: kind by journey).
func _veins() -> void:
	var cfg: Dictionary = _cfg.get("veins", {})

	if cfg.is_empty():
		return

	var starts: Array = []
	var metals: Array = cfg.get("metals", ["iron", "tin"])
	var finds: Array = cfg.get("finds", [["silver", 0.55], ["gold", 0.45]])
	var lengths: Array = cfg.get("length_m", [120.0, 300.0])
	var depths: Array = cfg.get("depth_m", [0.6, 3.5])
	var step: float = maxf(float(cfg.get("step_m", 10.0)), 2.0)
	var shown: int = int(cfg.get("outcrop_points", 3))
	var gap: float = float(cfg.get("gap_m", 1500.0))

	for d in deposits:
		var c: int = cell_at(float(d["x"]), float(d["z"]))

		if not metals.has(str(d["metal"])) or c < 0 or journey[c] < float(cfg.get("journey_min", 0.5)):
			continue

		var id: int = int(d["id"])
		var salt: int = _hash(id, 0x7e1a)

		if unit(salt, 1) >= float(cfg.get("chance", 0.3)) * (0.5 + float(d["size"])):
			continue

		var from: Vector2 = Vector2(float(d["x"]), float(d["z"]))
		var near: bool = false

		for s in starts:
			near = near or from.distance_to(s) < gap

		if near:
			continue

		starts.append(from)
		var up: Vector2 = _uphill(from.x, from.y)
		up = up if up != Vector2.ZERO else Vector2(1.0, 0.0).rotated(unit(salt, 2) * TAU)
		var pick: float = unit(salt, 3)
		var find: String = str(finds[finds.size() - 1][0])

		for f in finds:
			pick -= float(f[1])

			if pick < 0.0:
				find = str(f[0])
				break

		var length: float = lerpf(float(lengths[0]), float(lengths[1]), unit(salt, 4))
		var points: int = maxi(int(length / step), shown + 1)
		var head: Vector2 = from + up * float(d["radius"])

		for i in points:
			var t: float = float(i - shown) / float(maxi(points - shown - 1, 1))
			var at: Vector2 = head + up * (float(i) * step) + up.orthogonal() * (unit(salt, 10 + i) - 0.5) * 3.0
			var depth: float = 0.0 if i < shown else lerpf(float(depths[0]), float(depths[1]), t)
			var row: Dictionary = {"id": _hash(salt, 0x100 + i) & 0x3fffffff, "find": find, "x": at.x, "z": at.y, "depth": depth,
				"r": float(cfg.get("r_m", 2.0)), "source": id, "vein": salt}

			if i < shown:
				row["show"] = true

			_add_pocket(row)

			if i >= shown and unit(salt, 0x200 + i) < float(cfg.get("gem_per_m", 0.06)) * depth:
				_add_pocket({"id": _hash(salt, 0x300 + i) & 0x3fffffff, "find": _gem_at(cfg, journey[c], unit(salt, 0x400 + i)), "x": at.x, "z": at.y,
					"depth": depth + float(cfg.get("gem_below_m", 0.8)), "r": float(cfg.get("r_m", 2.0)), "source": id, "vein": salt})

	report.append("resources: %d gold and silver veins" % starts.size())


# A gem for a vein at journey j: one of the gems rows (find, journey_min) it fits, picked by u.
func _gem_at(cfg: Dictionary, j: float, u: float) -> String:
	var fits: Array = []

	for g in cfg.get("gems", [["amethyst", 0.0]]):
		if j >= float(g[1]):
			fits.append(str(g[0]))

	return str(fits[mini(int(u * float(fits.size())), fits.size() - 1)]) if not fits.is_empty() else "amethyst"


func _add_pocket(row: Dictionary) -> void:
	var pid: int = int(row["id"])

	if _pocket_of.has(pid):
		return

	_pocket_of[pid] = pockets.size()
	pockets.append(row)
	_bin_add(_pocket_bins, float(row["x"]), float(row["z"]), pockets.size() - 1)
