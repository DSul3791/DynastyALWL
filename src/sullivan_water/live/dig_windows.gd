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
const MIN_POOL_CELLS := 16     # a separate piece under the 8 m level this big (one 8 m sample) is a pond, smaller is a bank hollow
const FOLLOW_EDGE_M := 24.0    # a player this far inside a running region keeps it; nearer its edge, a new region opens round them
const FOLLOW_EVERY_MS := 10000 # at most one follow open this often (each reads the ground of up to 4 tiles)
const MAX_SLEEPING := 32       # sleeping regions kept (each at most MAX_TILES tiles: about 0.7 MB)

var source = null
var windows: Array = []        # the running regions, oldest first: each {"grid", "adapter", "coordinator", "origin": Vector2, "tiles": Rect2i}
var sleeping: Array = []       # regions put to sleep for the tile budget, oldest first, same shape; not stepped, still drawn
var built: int = 0
var joined: int = 0            # regions that were joined into a bigger one
var closed_m3: float = 0.0     # water dropped with sleeping regions past MAX_SLEEPING
var dry_pieces: int = 0           # bank hollows under an 8 m level left dry when seeding (the log and the test)
var followed: int = 0             # regions opened to follow a player
var _follow_next_ms: int = 0
var _follow_dry_told: Rect2i = Rect2i()   # the dry tiles last logged, so the log says it once
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
			win["dug"] = true

			if answer["result"] != Coordinator.COMMITTED:
				refused += 1
				print("water live: edit at %s not taken: %s %s" % [str(center.round()), answer["result"], answer["reason"]])
			return

	_open(touched, level_at, true)


# On the water thread, every hub tick: a 2 m region follows the first player while there is water near them (docs/water/follow_players_2m.md).
# Opens the 2 x 2 tiles round the player when they are not well inside a running region (FOLLOW_EDGE_M) and the 8 m levels show water there.
# At most one open per FOLLOW_EVERY_MS. Such a region is not DUG: under the tile budget it closes (the 8 m field still holds that river)
# rather than sleeps; a dig inside it makes it dug, and then it sleeps with its water like any dug region.
func follow(points: PackedVector2Array, level_at: Callable) -> void:
	if source == null or points.is_empty():
		return

	var now: int = Time.get_ticks_msec()

	if now < _follow_next_ms:
		return

	var p: Vector2 = points[0]

	for win in windows:
		var inner: Rect2 = Rect2(win["origin"], Vector2(win["tiles"].size) * TILE_M).grow(-FOLLOW_EDGE_M)

		if inner.has_point(p):
			return

	var want: Rect2i = tiles_of(p - Vector2.ONE * TILE_M * 0.5, p + Vector2.ONE * TILE_M * 0.5)
	_follow_next_ms = now + FOLLOW_EVERY_MS

	if not _wet_in(want, level_at):
		if want != _follow_dry_told:
			_follow_dry_told = want
			print("water live: follow: no 8 m water in tiles %s round the player at %s, no 2 m region" % [str(want), str(p.round())])
		return

	followed += 1
	print("water live: follow: opening tiles %s round the player at %s" % [str(want), str(p.round())])
	_open(want, level_at, false)


# Any 8 m sample in the tiles wet?
func _wet_in(tiles: Rect2i, level_at: Callable) -> bool:
	var o: Vector2 = Vector2(tiles.position) * TILE_M
	var steps: int = int(TILE_M / 8.0)

	for sj in range(tiles.size.y * steps):
		for si in range(tiles.size.x * steps):
			if not is_nan(float(level_at.call(o.x + si * 8.0 + 4.0, o.y + sj * 8.0 + 4.0))):
				return true
	return false


# Opens `wanted` tiles, joined with every region that overlaps or borders them.
func _open(wanted: Rect2i, level_at: Callable, dug: bool) -> void:
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

	var t0: int = Time.get_ticks_msec()
	var blocks0: int = int(source.blocks_loaded) if "blocks_loaded" in source else 0
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

	# Water: copied exactly from the joining regions, from the 8 m levels elsewhere. An 8 m level is a mean surface: a 2 m hollow on the
	# bank beside a river sits under it too, and seeding it left soft puddles on dry grass (Dino's #513 picture, 7 Nov 2026). So the cells
	# under the level are grouped (4-neighbour pieces), and a piece gets its water only when it is real 8 m water: it reaches the region's
	# border (a river coming through), joins copied water, or is at least MIN_POOL_CELLS big (a pond inside the region). Small separate
	# hollows stay dry, as they are in the 8 m field's own reckoning.
	var copied: float = 0.0
	var seeded: float = 0.0
	var candidate: Dictionary = {}   # cell -> the 8 m level over it
	var wet_copy: Dictionary = {}

	for j in range(h):
		for i in range(w):
			var k: int = grid.index(i, j)
			var c: Vector2 = adapter.cell_centre(i, j)
			var old = _cell_of(joining, c)
			var border: bool = i == 0 or j == 0 or i == w - 1 or j == h - 1

			if old != null:
				grid.volume[k] = old[0].volume[old[1]]
				copied += grid.volume[k]

				if grid.volume[k] > 0.0:
					wet_copy[k] = true

				if border:
					var held: float = float(level_at.call(c.x, c.y))

					if not is_nan(held) and held > grid.bed[k] and adapter.classification[k] == Adapter.OPEN_SURFACE:
						grid.fixed[k] = held   # a copied cell on the new border is held at the 8 m level like any other
			elif adapter.classification[k] == Adapter.OPEN_SURFACE:
				var level: float = float(level_at.call(c.x, c.y))

				if not is_nan(level) and level > grid.bed[k]:
					candidate[k] = level

	var done: Dictionary = {}

	for start_k in candidate:
		if done.has(start_k):
			continue

		var piece: Array[int] = [start_k]
		var real: bool = false
		done[start_k] = true
		var head: int = 0

		while head < piece.size():
			var k: int = piece[head]
			head += 1
			var i: int = k % w
			var j: int = floori(k / float(w))

			if i == 0 or j == 0 or i == w - 1 or j == h - 1:
				real = true

			for n in [k - 1 if i > 0 else -1, k + 1 if i < w - 1 else -1, k - w if j > 0 else -1, k + w if j < h - 1 else -1]:
				if n < 0:
					continue

				if wet_copy.has(n):
					real = true
				elif candidate.has(n) and not done.has(n):
					done[n] = true
					piece.append(n)

		if not real and piece.size() < MIN_POOL_CELLS:
			dry_pieces += 1
			continue

		for k in piece:
			grid.volume[k] = (float(candidate[k]) - grid.bed[k]) * grid.area_m2
			seeded += grid.volume[k]
			var i: int = k % w
			var j: int = floori(k / float(w))

			if i == 0 or j == 0 or i == w - 1 or j == h - 1:
				grid.fixed[k] = float(candidate[k])

	grid.start_m3 = grid.total_volume()
	last_copied_m3 = copied

	for win in joining:
		windows.erase(win)
		sleeping.erase(win)
		joined += 1
		dug = dug or bool(win.get("dug", true))

	# The tile budget: a region nobody dug in closes first (the 8 m field holds its river); then the dug region nearest rest goes to sleep,
	# keeping its water.
	while _tiles_running() + rect.get_area() > MAX_TILES and not windows.is_empty():
		var plain = null

		for win in windows:
			if not bool(win.get("dug", true)):
				plain = win
				break

		if plain != null:
			windows.erase(plain)
			print("water live: region %s closes for the %d tile budget (nobody dug there; the 8 m levels show its river again)" % [str(plain["tiles"]), MAX_TILES])
			continue

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

	windows.append({"grid": grid, "adapter": adapter, "coordinator": coordinator, "origin": origin, "tiles": rect, "dug": dug})
	built += 1
	print("water live: window %d x %d at %s (tiles %s, %d joined), %.0f m3 of water (%.0f copied, %.0f from the 8 m levels), %d border cells held, built in %d ms (%d ground blocks loaded)" % [w, h, str(origin), str(rect), joining.size(), grid.total_volume(), copied, seeded, grid.fixed.size(), Time.get_ticks_msec() - t0, (int(source.blocks_loaded) if "blocks_loaded" in source else 0) - blocks0])


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


# The regions as texture packets for the clients' fine sheets (docs/water/fine_drawing_2m.md), in the 8 m window's form
# (water_flow_texture.gd, protocol 85: RGBAF per cell, R surface or bed where dry, G and B flow east and south, A depth; sea cells left out).
# {"keys": every drawn region, "packets": [[key, origin of cell (0, 0), w, h, cell_m, raw size, zstd bytes], ...]} with the running regions,
# and the sleeping ones too when `with_sleeping`. Water thread.
func fine_packets(with_sleeping: bool) -> Dictionary:
	var keys: PackedStringArray = PackedStringArray()
	var packets: Array = []

	for win in sleeping + windows:
		var t: Rect2i = win["tiles"]
		var key: String = "%d_%d_%d_%d" % [t.position.x, t.position.y, t.size.x, t.size.y]
		keys.append(key)

		if not with_sleeping and sleeping.has(win):
			continue

		var grid = win["grid"]
		var im: Image = Image.create(grid.w, grid.h, false, Image.FORMAT_RGBAF)

		for j in range(grid.h):
			for i in range(grid.w):
				var b: float = grid.bed[grid.index(i, j)]

				if b < 0.0:
					im.set_pixel(i, j, Color(0.0, 0.0, 0.0, 0.0))
					continue

				var d: float = grid.depth(i, j)

				# A film thinner than DRAW_M (the 2 m cells seeded from the 8 m level leave a few mm to cm on gentle banks) is not drawn,
				# as the 8 m drawing leaves out water under its WetMeters: drawn, the sheet's shore foam traced pale lines over the grass
				# (Dino's #513 picture over the pond, 7 Nov 2026).
				if d < DRAW_M:
					im.set_pixel(i, j, Color(b, 0.0, 0.0, 0.0))
					continue

				var v: Vector2 = grid.velocity(i, j)
				im.set_pixel(i, j, Color(b + d, v.x, v.y, d))

		var raw: PackedByteArray = im.get_data()
		var origin: Vector2 = win["origin"] + Vector2(0.5, 0.5) * CELL_M
		packets.append([key, origin, grid.w, grid.h, CELL_M, raw.size(), raw.compress(FileAccess.COMPRESSION_ZSTD)])

	return {"keys": keys, "packets": packets}


# The world rectangle (x, z) round the running regions (the only ones whose drawing changes), or an empty Rect2. Water thread.
func drawn_rect() -> Rect2:
	var out: Rect2 = Rect2()

	for win in windows:
		var r: Rect2 = Rect2(win["origin"], Vector2(win["tiles"].size) * TILE_M)
		out = r if not out.has_area() else out.merge(r)
	return out


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
