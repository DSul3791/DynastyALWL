extends RefCounted

# Sullivan water, live in the game (Sonny, 7 Nov 2026): fine water where players dig.
#
# The server's water (src/water2/water_hub2.gd) runs rivers and lakes on 8 m cells. A ditch is about 3 m wide, so it needs the guide's
# 2 m grid (Sullivan water M1 to M3). The world is cut into 96 m TILES on a fixed lattice (TILE_CELLS x TILE_CELLS cells of 2 m). Water
# runs in REGIONS: a region is a rectangle of tiles with one grid over all of them. At most MAX_TILES tiles run at once.
# - A dig or fill (already made by the server, in its edit log) that lies inside a region, with its one-cell halo, goes through that
#   region's edit coordinator: beds and crests are re-read from the server's ground and every cell keeps its water.
# - Otherwise the tiles it touches are opened. Every region that overlaps or borders them joins them in one new grid (guide 26.1: every
#   face has one owner, so a ditch crossing a tile edge flows across it like any other face; there is no seam). The joined grid reads its
#   ground once and copies each old cell's water exactly; only the new tiles take water from the hub's 8 m levels (`level_at`).
# - A region's border cells that are wet in the 8 m levels are held at that level (fixed-stage boundaries, booked in the ledger), so a
#   river flows in and out. Its dry border is closed: guide 26.2 FROZEN_CLOSED, a labelled limitation until the 8 m field takes 2 m
#   water back (later in M4).
# - When the tiles would pass MAX_TILES, the region nearest rest (smallest head across any wet face) goes to SLEEP: it stops stepping
#   but keeps every cell's water and is still drawn (guide 26.2: never discard a sleeping region's inventory). A dig that reaches a
#   sleeping region wakes it: it joins the new grid like a running one, its water copied exactly. At most MAX_SLEEPING sleep; past that
#   the oldest is dropped (labelled limitation until saving, M8; the log says how much). When the join alone would pass MAX_TILES, only
#   the new tiles open, beside the others, unjoined.
# - publish(): each region's water drawn back into the hub's 8 m levels, so the existing client drawing shows it (an 8 m sample shows the
#   mean surface of its wet 2 m cells, or nothing when fewer than MIN_WET of its 16 cells are wet). Drawing at 2 m is milestone M6.
#
# Threads: dig() is called from the server frame and only queues; update() runs on the water thread (the hub's) and does all the work.

const Grid := preload("res://src/sullivan_water/freshwater/water_grid_2d.gd")
const Adapter := preload("res://src/sullivan_water/freshwater/terrain_adapter.gd")
const Coordinator := preload("res://src/sullivan_water/freshwater/terrain_water_edit_coordinator.gd")
const Source := preload("res://src/sullivan_water/freshwater/server_ground_source.gd")

const CELL_M := 2.0
const TILE_CELLS := 48         # cells along a tile: 96 m, a whole number of 8 m samples
const TILE_M := 96.0
const MAX_TILES := 4           # tiles running at once, over all regions (the same 9216 cells as four 48 x 48 windows)
const MIN_WET := 4             # of the 16 cells under an 8 m sample, how many must be wet for the sample to show water
const DRAW_M := 0.05           # thinner 2 m water than this is not counted as wet
const PER := 4                 # 2 m cells along one 8 m sample
const MAX_SLEEPING := 32       # sleeping regions kept (each at most MAX_TILES tiles: about 0.7 MB)

var source = null
var windows: Array = []        # the running regions, oldest first: each {"grid", "adapter", "coordinator", "origin": Vector2, "tiles": Rect2i}
var sleeping: Array = []       # regions put to sleep for the tile budget, oldest first, same shape; not stepped, still drawn
var built: int = 0
var joined: int = 0            # regions that were joined into a bigger one
var closed_m3: float = 0.0     # water dropped with sleeping regions past MAX_SLEEPING
var last_copied_m3: float = 0.0   # water the newest region copied from the regions it joined
var refused: int = 0
var _queue: Array = []         # [center: Vector3, radius: float, add: bool]
var _mutex: Mutex = Mutex.new()


func set_store(store) -> void:
	source = Source.new(store)


# From the server frame: a dig or fill the server has already made. Queued for the water thread.
func dig(center: Vector3, radius: float, add: bool) -> void:
	if source == null:
		return

	_mutex.lock()
	_queue.append([center, radius, add])
	_mutex.unlock()


# On the water thread, once per hub tick: apply queued edits, then run `seconds` of water in every region.
# `level_at(x, z) -> float` gives the hub's 8 m water level there (NAN where dry).
func update(seconds: float, level_at: Callable) -> void:
	_mutex.lock()
	var edits: Array = _queue
	_queue = []
	_mutex.unlock()

	# After a restart the server replays every saved dig. Only the newest matter here: a region reads the ground with all earlier edits
	# already in it, so the older ones need no work of their own.
	if edits.size() > 16:
		edits = edits.slice(edits.size() - 16)

	for edit in edits:
		_edit(edit[0], float(edit[1]), bool(edit[2]), level_at)

	for win in windows:
		var grid = win["grid"]
		var ticks: int = int(round(seconds / grid.dt))

		for _t in range(ticks):
			grid.step()


# The tiles a world rectangle touches.
static func tiles_of(lo: Vector2, hi: Vector2) -> Rect2i:
	var a: Vector2i = Vector2i(floori(lo.x / TILE_M), floori(lo.y / TILE_M))
	var b: Vector2i = Vector2i(floori(hi.x / TILE_M), floori(hi.y / TILE_M))
	return Rect2i(a, b - a + Vector2i.ONE)


func _edit(center: Vector3, radius: float, add: bool, level_at: Callable) -> void:
	var reach: float = radius + CELL_M   # the edit and its one-cell halo
	var lo: Vector2 = Vector2(center.x - reach, center.z - reach)
	var hi: Vector2 = Vector2(center.x + reach, center.z + reach)
	var touched: Rect2i = tiles_of(lo, hi)

	for win in windows:
		var o: Vector2 = win["origin"]
		var t: Rect2i = win["tiles"]
		var far: Vector2 = o + Vector2(t.size) * TILE_M

		if lo.x >= o.x and lo.y >= o.y and hi.x < far.x and hi.y < far.y:
			var answer: Dictionary = win["coordinator"].edit_sphere(center, radius, add, true)

			if answer["result"] != Coordinator.COMMITTED:
				refused += 1
				print("water live: edit at %s not taken: %s %s" % [str(center.round()), answer["result"], answer["reason"]])
			return

	_open(touched, level_at)


# Opens `wanted` tiles, joined with every region that overlaps or borders them.
func _open(wanted: Rect2i, level_at: Callable) -> void:
	var rect: Rect2i = wanted
	var joining: Array = []

	for win in windows:
		if _touches(win["tiles"], rect):
			joining.append(win)

	for win in sleeping:
		if win["tiles"].intersects(rect):
			joining.append(win)   # woken: its cells cannot be held twice

	for win in joining:
		rect = rect.merge(win["tiles"])

	if rect.get_area() > MAX_TILES:
		print("water live: joining %d regions into %s would pass %d tiles; the new tiles open on their own (closed edge between)" % [joining.size(), str(rect), MAX_TILES])
		rect = wanted
		joining = []

		for win in windows + sleeping:
			if win["tiles"].intersects(rect):
				joining.append(win)   # overlapping tiles cannot be held twice; whatever overlaps must join
				rect = rect.merge(win["tiles"])

		if rect.get_area() > MAX_TILES:
			refused += 1
			print("water live: no region at %s: %d tiles needed, %d allowed" % [str(wanted), rect.get_area(), MAX_TILES])
			return

	var origin: Vector2 = Vector2(rect.position) * TILE_M
	var w: int = rect.size.x * TILE_CELLS
	var h: int = rect.size.y * TILE_CELLS
	var grid = Grid.new(w, h, CELL_M)
	var adapter = Adapter.new(source, origin, CELL_M)
	adapter.scan_step_m = 0.5
	var coordinator = Coordinator.new(grid, adapter)
	var report: Dictionary = coordinator.build()

	if not bool(report["ok"]):
		refused += 1
		print("water live: no region at %s: %s" % [str(rect), report["reason"]])
		return

	# Water: copied exactly from the joining regions, from the 8 m levels elsewhere.
	var copied: float = 0.0
	var seeded: float = 0.0

	for j in range(h):
		for i in range(w):
			var k: int = grid.index(i, j)
			var c: Vector2 = adapter.cell_centre(i, j)
			var old = _cell_of(joining, c)

			if old != null:
				grid.volume[k] = old[0].volume[old[1]]
				copied += grid.volume[k]
			elif adapter.classification[k] == Adapter.OPEN_SURFACE:
				var level: float = float(level_at.call(c.x, c.y))

				if not is_nan(level) and level > grid.bed[k]:
					grid.volume[k] = (level - grid.bed[k]) * grid.area_m2
					seeded += grid.volume[k]

			if i == 0 or j == 0 or i == w - 1 or j == h - 1:
				var held: float = float(level_at.call(c.x, c.y))

				if not is_nan(held) and held > grid.bed[k] and adapter.classification[k] == Adapter.OPEN_SURFACE:
					grid.fixed[k] = held

	grid.start_m3 = grid.total_volume()
	last_copied_m3 = copied

	for win in joining:
		windows.erase(win)
		sleeping.erase(win)
		joined += 1

	# The tile budget: the running region nearest rest goes to sleep, keeping its water.
	while _tiles_running() + rect.get_area() > MAX_TILES and not windows.is_empty():
		var calm = windows[0]

		for win in windows:
			if win["grid"].max_wet_head() < calm["grid"].max_wet_head():
				calm = win

		windows.erase(calm)
		sleeping.append(calm)
		print("water live: region %s sleeps for the %d tile budget, keeping %.0f m3 (head %.3f m)" % [str(calm["tiles"]), MAX_TILES, calm["grid"].total_volume(), calm["grid"].max_wet_head()])

	while sleeping.size() > MAX_SLEEPING:
		var gone = sleeping.pop_front()
		closed_m3 += gone["grid"].total_volume()
		print("water live: sleeping region %s dropped past %d sleeping, %.0f m3 of 2 m water lost (the 8 m levels show again)" % [str(gone["tiles"]), MAX_SLEEPING, gone["grid"].total_volume()])

	windows.append({"grid": grid, "adapter": adapter, "coordinator": coordinator, "origin": origin, "tiles": rect})
	built += 1
	print("water live: window %d x %d at %s (tiles %s, %d joined), %.0f m3 of water (%.0f copied, %.0f from the 8 m levels), %d border cells held" % [w, h, str(origin), str(rect), joining.size(), grid.total_volume(), copied, seeded, grid.fixed.size()])


# Two tile rectangles overlap or share an edge (not just a corner).
static func _touches(a: Rect2i, b: Rect2i) -> bool:
	var gap_x: int = maxi(a.position.x, b.position.x) - mini(a.end.x, b.end.x)
	var gap_y: int = maxi(a.position.y, b.position.y) - mini(a.end.y, b.end.y)
	return (gap_x <= 0 and gap_y < 0) or (gap_x < 0 and gap_y <= 0)


# The [grid, index] of the joining region's cell centred at `c`, or null.
func _cell_of(regions: Array, c: Vector2):
	for win in regions:
		var rel: Vector2 = (c - win["origin"]) / CELL_M
		var i: int = floori(rel.x)
		var j: int = floori(rel.y)
		var grid = win["grid"]

		if grid.inside(i, j):
			return [grid, grid.index(i, j)]
	return null


func _tiles_running() -> int:
	var n: int = 0

	for win in windows:
		n += win["tiles"].get_area()
	return n


# Draws the regions into the hub's 8 m levels (a tile's `samples` x `samples`, first sample at x0, z0). Returns true when any sample changed.
func publish(levels: PackedFloat32Array, samples: int, x0: float, z0: float) -> bool:
	var changed: bool = false

	for win in sleeping + windows:
		var grid = win["grid"]
		var o: Vector2 = win["origin"]
		var si0: int = int(round((o.x - x0) / 8.0))
		var sj0: int = int(round((o.y - z0) / 8.0))

		for sj in range(floori(grid.h / float(PER))):
			for si in range(floori(grid.w / float(PER))):
				var gi: int = si0 + si
				var gj: int = sj0 + sj

				if gi < 0 or gj < 0 or gi >= samples or gj >= samples:
					continue

				var wet: int = 0
				var sum: float = 0.0

				for dj in range(PER):
					for di in range(PER):
						var i: int = si * PER + di
						var j: int = sj * PER + dj

						if grid.depth(i, j) >= DRAW_M:
							wet += 1
							sum += grid.surface(i, j)

				var value: float = sum / wet if wet >= MIN_WET else NAN
				var k: int = gj * samples + gi
				var old: float = levels[k]

				if is_nan(old) != is_nan(value) or (not is_nan(value) and absf(old - value) >= 0.01):
					changed = true

				levels[k] = value

	return changed
