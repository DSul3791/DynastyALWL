extends RefCounted

# Sullivan water, live in the game (Sonny, 7 Nov 2026): fine water windows where players dig.
#
# The server's water (src/water2/water_hub2.gd) runs rivers and lakes on 8 m cells and, until now, ignored digs. A ditch is about 2 m wide,
# so it needs the guide's 2 m grid (Sullivan water M1 to M3). This keeps up to MAX_WINDOWS of them, each SIZE x SIZE cells (96 m), placed
# where the digs happen:
# - A dig or fill (already made by the server, in its edit log) goes to the window that holds it, through the edit coordinator: the beds
#   and crests are re-read from the server's ground and every cell keeps its water. A dig outside every window opens a new window there
#   (the oldest one closes when there are too many).
# - A new window reads its ground from the server (server_ground_source.gd) and takes its water from the 8 m levels the hub publishes
#   (`level_at`). Its border cells that are wet are held at that level (fixed-stage boundaries, booked in the ledger), so a river flows in
#   and out across the border, and a ditch cut from the river fills from it. Its dry border is the grid's closed edge.
# - publish(): the window's water drawn back into the hub's 8 m levels, so the existing client drawing shows it (an 8 m sample shows the
#   mean surface of its wet 2 m cells, or nothing when fewer than MIN_WET of its 16 cells are wet). Drawing at 2 m is milestone M6.
#
# Threads: dig() is called from the server frame and only queues; update() runs on the water thread (the hub's) and does all the work.

const Grid := preload("res://src/sullivan_water/freshwater/water_grid_2d.gd")
const Adapter := preload("res://src/sullivan_water/freshwater/terrain_adapter.gd")
const Coordinator := preload("res://src/sullivan_water/freshwater/terrain_water_edit_coordinator.gd")
const Source := preload("res://src/sullivan_water/freshwater/server_ground_source.gd")

const CELL_M := 2.0
const SIZE := 48               # cells a side: 96 m
const MAX_WINDOWS := 4
const MIN_WET := 4             # of the 16 cells under an 8 m sample, how many must be wet for the sample to show water
const DRAW_M := 0.05           # thinner 2 m water than this is not counted as wet
const PER := 4                 # 2 m cells along one 8 m sample
const SAMPLES_ACROSS := 12     # 8 m samples along a window (SIZE / PER)

var source = null
var windows: Array = []        # each {"grid", "adapter", "coordinator", "origin": Vector2}
var built: int = 0
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


# On the water thread, once per hub tick: apply queued edits, then run `seconds` of water in every window.
# `level_at(x, z) -> float` gives the hub's 8 m water level there (NAN where dry).
func update(seconds: float, level_at: Callable) -> void:
	_mutex.lock()
	var edits: Array = _queue
	_queue = []
	_mutex.unlock()

	# After a restart the server replays every saved dig. Only the newest matter here: a window reads the ground with all earlier edits
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


func _edit(center: Vector3, radius: float, add: bool, level_at: Callable) -> void:
	for win in windows:
		var o: Vector2 = win["origin"]
		var size_m: float = SIZE * CELL_M

		if center.x - radius > o.x + CELL_M and center.z - radius > o.y + CELL_M and center.x + radius < o.x + size_m - CELL_M and center.z + radius < o.y + size_m - CELL_M:
			var answer: Dictionary = win["coordinator"].edit_sphere(center, radius, add, true)

			if answer["result"] != Coordinator.COMMITTED:
				refused += 1
				print("water live: edit at %s not taken: %s %s" % [str(center.round()), answer["result"], answer["reason"]])
			return

	_open(Vector2(center.x, center.z), level_at)


func _open(at: Vector2, level_at: Callable) -> void:
	var origin: Vector2 = (at - Vector2(SIZE, SIZE) * CELL_M * 0.5).snapped(Vector2(8.0, 8.0))   # on the 8 m sample lattice, so publish lines up
	var grid = Grid.new(SIZE, SIZE, CELL_M)
	var adapter = Adapter.new(source, origin, CELL_M)
	adapter.scan_step_m = 0.5
	var coordinator = Coordinator.new(grid, adapter)
	var report: Dictionary = coordinator.build()

	if not bool(report["ok"]):
		refused += 1
		print("water live: no window at %s: %s" % [str(at.round()), report["reason"]])
		return

	for j in range(SIZE):
		for i in range(SIZE):
			var c: Vector2 = adapter.cell_centre(i, j)
			var level: float = float(level_at.call(c.x, c.y))
			var k: int = grid.index(i, j)

			if is_nan(level) or level <= grid.bed[k] or adapter.classification[k] != Adapter.OPEN_SURFACE:
				continue

			grid.volume[k] = (level - grid.bed[k]) * grid.area_m2

			if i == 0 or j == 0 or i == SIZE - 1 or j == SIZE - 1:
				grid.fixed[k] = level

	grid.start_m3 = grid.total_volume()

	if windows.size() >= MAX_WINDOWS:
		windows.pop_front()

	windows.append({"grid": grid, "adapter": adapter, "coordinator": coordinator, "origin": origin})
	built += 1
	print("water live: window %d x %d at %s, %.0f m3 of water, %d border cells held" % [SIZE, SIZE, str(origin), grid.total_volume(), grid.fixed.size()])


# Draws the windows into the hub's 8 m levels (a tile's `samples` x `samples`, first sample at x0, z0). Returns true when any sample changed.
func publish(levels: PackedFloat32Array, samples: int, x0: float, z0: float) -> bool:
	var changed: bool = false

	for win in windows:
		var grid = win["grid"]
		var o: Vector2 = win["origin"]
		var si0: int = int(round((o.x - x0) / 8.0))
		var sj0: int = int(round((o.y - z0) / 8.0))
		var per: int = PER

		for sj in range(SAMPLES_ACROSS):
			for si in range(SAMPLES_ACROSS):
				var gi: int = si0 + si
				var gj: int = sj0 + sj

				if gi < 0 or gj < 0 or gi >= samples or gj >= samples:
					continue

				var wet: int = 0
				var sum: float = 0.0

				for dj in range(per):
					for di in range(per):
						var i: int = si * per + di
						var j: int = sj * per + dj

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
