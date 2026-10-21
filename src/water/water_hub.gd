extends RefCounted

# The server's water across tile borders (stage A of tools in /mnt/project-files/tech/TILE_BORDER_WATER_DESIGN.md,
# approved by Technical direction 2026-10-21). One water thread steps every active tile in turn
# (round robin, always the tile furthest behind in simulated time, under the one CPU duty cap), and
# water crosses a tile border where a river or lake crosses it.
#
# A border is one row or column of samples that both tiles hold (the last of one is the first of
# the next, same ground). At each shared pair of wet cells the two depths are drawn level after
# every tick: water moves from the higher surface to the lower, never faster than the sim's own
# speed ceiling lets a face carry it, so the pair behaves like one cell and a river flows on into
# the next tile. Water is moved as depth between equal cells, so no volume is lost or made and the
# two tiles' time steps need not match. A neighbour that receives water is woken to run it.
#
# Which tiles run: the centre tile (where the players are) plus the neighbours a river or lake
# crosses into, at most MAX_ACTIVE, and the loaded sims stay under MEMORY_LIMIT_BYTES (the least
# recently stepped neighbour is saved to the world's water folder and dropped first). A tile with
# no neighbour data starts dry, like every tile on a new session. Saved files are per tile
# (water_store.gd, versioned); no protocol change: clients draw neighbours from the same
# `sim_levels` the server fills for each tile.
#
# The API of the server's old single-tile WaterLive is kept (rate, runoff, busy, step_rate,
# set_runoff, dig, fill, stop) and applies to every tile.

const WaterLive := preload("res://src/water/water_live.gd")
const WaterSim := preload("res://src/water/water_sim.gd")

const MAX_ACTIVE := 4                    # live tiles at most (Technical direction: 4)
const MEMORY_LIMIT_BYTES := 1288490188   # 1.2 GB of water memory in all (Technical direction)
const PAD := 3                           # cells either side of a wet crossing that are coupled too
const WET_CLASSES := [2, 3]              # lake, river
const SETTLE_SECONDS := 600.0            # a neighbour woken by inflow runs this long after the last of it
const WAKE_DEPTH_M := 0.002              # moving more than this much depth into a resting tile wakes it

var data                                  # the centre tile's TileTerrainData (the server's water_live.data)
var rate: float = WaterLive.DEFAULT_RATE
var runoff: float = 1.0
var busy: bool = false
var centre: Vector2i = Vector2i.ZERO

var _generator
var _water_dir: String = ""
var _base_rate: float = 3.0
var _dry_start: bool = false
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _quit: bool = false
var _tiles: Dictionary = {}                # tile -> WaterLive (a built sim), touched only by the water thread
var _data: Dictionary = {}                 # tile -> terrain data of every wanted tile (fetched on the main thread)
var _wanted: Array = []                    # tiles that should be loaded, centre first
var _links: Array = []                     # {a, b, ka, kb}: shared border cell pairs of two wanted tiles
var _edits: Array = []                     # [center, radius, filled] of every dig and fill, replayed into tiles as they load
var _used: Dictionary = {}                 # tile -> msec of its last tick (least recently used goes first)
var _saved: Dictionary = {}                # tile -> true when depths were saved by an unload this session
var _published: Dictionary = {}            # tile -> {levels, falls} waiting for the main thread
var _baseline: int = 0                    # process memory before any water sim (the limit counts what the water adds)
var _stats: Dictionary = {"moved_m3": 0.0, "memory": 0, "loaded": 0}


func setup(centre_tile: Vector2i, water_dir: String, base_rate: float, tile_generator, dry_start: bool = false) -> void:
	_generator = tile_generator
	_baseline = OS.get_static_memory_usage()
	_water_dir = water_dir
	_base_rate = base_rate
	_dry_start = dry_start
	set_centre(centre_tile)
	data = _data.get(centre_tile)
	_thread = Thread.new()
	_thread.start(_run)


func stop() -> void:
	_mutex.lock()
	_quit = true
	_mutex.unlock()

	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# Moves the centre (where the players are): the wanted tiles are the new centre and the neighbours a
# wet crossing leads into. Called on the main thread; the water thread loads and unloads to match.
func set_centre(tile: Vector2i) -> void:
	set_live([tile])


# The live set (tech/WATER_NINE_TILES_PLAN.md): the tiles players stand in come first (the first is the
# centre), then, up to MAX_ACTIVE in all, the neighbours that share the most wet border with a live
# tile. Tiles outside it are saved and unloaded by the water thread, so a sleeping tile holds no per-cell
# arrays. Calling it again with the same tiles changes nothing.
func set_live(tiles: Array) -> void:
	var wanted: Array = []
	var found: Dictionary = {}

	for tile in tiles:
		if wanted.size() >= MAX_ACTIVE:
			break

		if tile in wanted:
			continue

		var tile_data = _tile_data(tile)

		if tile_data == null:
			continue

		wanted.append(tile)
		found[tile] = tile_data

	if wanted.is_empty():
		return

	var candidates: Array = []

	for tile in wanted.duplicate():
		for step in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var other: Vector2i = tile + step

			if other in wanted:
				continue

			var other_data = _tile_data(other)

			if other_data == null:
				continue

			var pairs: Array = border_pairs(found[tile], other_data, step)

			if not pairs[0].is_empty():
				candidates.append({"tile": other, "data": other_data, "pairs": pairs})

	candidates.sort_custom(func(x, y): return x["pairs"][0].size() > y["pairs"][0].size())

	for candidate in candidates:
		if wanted.size() >= MAX_ACTIVE:
			break

		if candidate["tile"] in wanted:
			continue

		wanted.append(candidate["tile"])
		found[candidate["tile"]] = candidate["data"]

	# Every pair of live tiles that touch is coupled.
	var links: Array = []

	for a in range(wanted.size()):
		for b in range(a + 1, wanted.size()):
			var step: Vector2i = wanted[b] - wanted[a]

			if absi(step.x) + absi(step.y) != 1:
				continue

			var pairs: Array = border_pairs(found[wanted[a]], found[wanted[b]], step)

			if not pairs[0].is_empty():
				links.append({"a": wanted[a], "b": wanted[b], "ka": pairs[0], "kb": pairs[1]})

	_mutex.lock()
	centre = wanted[0]
	_wanted = wanted
	_links = links

	for t in wanted:
		_data[t] = found[t]

	data = _data.get(centre)
	_mutex.unlock()


func _tile_data(tile: Vector2i):
	var tile_data = _generator.get_tile(tile)

	if tile_data == null or tile_data.placeholder:
		return null

	if _dry_start and not _data.has(tile):
		tile_data.sim_levels = PackedFloat32Array()
		tile_data.sim_levels.resize(tile_data.samples * tile_data.samples)
		tile_data.sim_levels.fill(NAN)

	return tile_data


# The pairs of sample indices [in a, in b] along the border of `b` (the neighbour at `step`, one tile
# east (1, 0), south (0, 1), west or north of `a`) where water can cross: wherever a river or lake
# cell is on either side of the line, and PAD cells either side of it. Both lists are empty when
# nothing crosses.
static func border_pairs(a, b, step: Vector2i) -> Array:
	var n: int = a.samples
	var ka: PackedInt32Array = PackedInt32Array()
	var kb: PackedInt32Array = PackedInt32Array()
	var wet: PackedByteArray = PackedByteArray()
	wet.resize(n)

	for i in range(n):
		var ia: int
		var ib: int

		if step == Vector2i(1, 0):
			ia = i * n + n - 1
			ib = i * n
		elif step == Vector2i(-1, 0):
			ia = i * n
			ib = i * n + n - 1
		elif step == Vector2i(0, 1):
			ia = (n - 1) * n + i
			ib = i
		else:
			ia = i
			ib = (n - 1) * n + i

		if (a.water_class[ia] in WET_CLASSES and a.heights[ia] > 0.0) or (b.water_class[ib] in WET_CLASSES and b.heights[ib] > 0.0):
			for near in range(maxi(i - PAD, 0), mini(i + PAD, n - 1) + 1):
				wet[near] = 1

	for i in range(n):
		if wet[i] == 0:
			continue

		if step == Vector2i(1, 0):
			ka.append(i * n + n - 1)
			kb.append(i * n)
		elif step == Vector2i(-1, 0):
			ka.append(i * n)
			kb.append(i * n + n - 1)
		elif step == Vector2i(0, 1):
			ka.append((n - 1) * n + i)
			kb.append(i)
		else:
			ka.append(i)
			kb.append((n - 1) * n + i)

	return [ka, kb]


# Steps the rate up (+1) or down (-1) and sets the water running toward it.
func step_rate(direction: int) -> float:
	_mutex.lock()
	rate = clampf(rate * (WaterLive.RATE_STEP if direction > 0 else 1.0 / WaterLive.RATE_STEP), WaterLive.RATE_MIN, WaterLive.RATE_MAX)
	var now: float = rate
	var live: Array = _tiles.values()
	_mutex.unlock()

	for tile_live in live:
		tile_live.wake()

	return now


# Rain swells the rivers: the springs run `value` times stronger (1 is dry weather).
func set_runoff(value: float) -> void:
	_mutex.lock()
	var changed: bool = absf(value - runoff) > 0.02
	runoff = value
	var live: Array = _tiles.values()
	_mutex.unlock()

	if changed:
		for tile_live in live:
			tile_live.wake()


# A player dug a hole or filled ground in: the tile that holds the spot runs it (and every tile that
# loads later replays it).
func dig(center: Vector3, radius: float) -> void:
	_edit(center, radius, false)


func fill(center: Vector3, radius: float) -> void:
	_edit(center, radius, true)


func _edit(center: Vector3, radius: float, filled: bool) -> void:
	var tile: Vector2i = _generator.tile_of(center.x, center.z)
	_mutex.lock()
	_edits.append([center, radius, filled])
	var live = _tiles.get(tile)
	_mutex.unlock()

	if live != null:
		if filled:
			live.fill(center, radius)
		else:
			live.dig(center, radius)


# New drawing levels of every tile that has some: [[tile, levels, fall levels], ...].
func take_updates() -> Array:
	var out: Array = []
	_mutex.lock()
	var live: Dictionary = _tiles.duplicate()
	_mutex.unlock()

	for tile in live:
		var levels: PackedFloat32Array = live[tile].take_levels()

		if not levels.is_empty():
			out.append([tile, levels, live[tile].fall_levels])

	return out


# The terrain data of a tile the hub runs (the centre and its wanted neighbours), or null.
func data_of(tile: Vector2i):
	_mutex.lock()
	var found = _data.get(tile)
	var wanted: bool = tile in _wanted
	_mutex.unlock()
	return found if wanted else null


# The simulation of a tile, for tests and the status line.
func sim_of(tile: Vector2i):
	_mutex.lock()
	var live = _tiles.get(tile)
	_mutex.unlock()
	return live.sim if live != null else null


func stats() -> Dictionary:
	_mutex.lock()
	var copy: Dictionary = _stats.duplicate()
	_mutex.unlock()
	return copy


# --- the water thread ---

func _run() -> void:
	while true:
		_mutex.lock()
		var quit: bool = _quit
		var wanted: Array = _wanted.duplicate()
		var links: Array = _links.duplicate()
		var multiplier: float = rate * runoff
		_mutex.unlock()

		if quit:
			return

		_sync_tiles(wanted)

		# The tile furthest behind in simulated time (and with something to run) goes next.
		var pick = null
		var pick_tile: Vector2i = Vector2i.ZERO
		var behind: float = INF
		var any: bool = false

		_mutex.lock()
		var live: Dictionary = _tiles.duplicate()
		_mutex.unlock()

		for tile in live:
			if live[tile].sim == null:
				continue

			var wants: bool = live[tile].wants_run()
			any = any or wants

			if wants and live[tile].seconds() < behind:
				behind = live[tile].seconds()
				pick = live[tile]
				pick_tile = tile

		busy = any

		if pick == null:
			OS.delay_msec(100)
			continue

		var tick_start: int = Time.get_ticks_usec()
		pick.rate = rate
		pick.runoff = runoff
		var dt: float = pick.tick(multiplier)
		_used[pick_tile] = Time.get_ticks_msec()

		for link in links:
			if link["a"] == pick_tile or link["b"] == pick_tile:
				var a = live.get(link["a"])
				var b = live.get(link["b"])

				if a != null and b != null and a.sim != null and b.sim != null:
					_couple(a, b, link["ka"], link["kb"], dt)

		# Technical direction (2026-10-20): the water thread shares the PC with the client, so
		# it sleeps in proportion to the work it did and uses at most CPU_DUTY of one core
		# (CPU_DUTY_STORM at the x20 storm), running slower than real time when it must.
		var duty: float = lerpf(WaterLive.CPU_DUTY, WaterLive.CPU_DUTY_STORM, clampf((multiplier / WaterLive.DEFAULT_RATE - 1.0), 0.0, 1.0))
		var busy_us: int = Time.get_ticks_usec() - tick_start
		OS.delay_usec(int(float(busy_us) * (1.0 / duty - 1.0)))


# Loads one wanted tile that is not loaded yet (it takes seconds), and drops loaded tiles that are not
# wanted or that overrun the memory limit, least recently stepped first (their water is saved).
func _sync_tiles(wanted: Array) -> void:
	_mutex.lock()
	var loaded: Array = _tiles.keys()
	_mutex.unlock()

	for tile in loaded:
		if not (tile in wanted):
			_drop(tile)

	for tile in wanted:
		_mutex.lock()
		var have: bool = _tiles.has(tile)
		var tile_data = _data.get(tile)
		var saved: bool = _saved.has(tile)
		_mutex.unlock()

		if have or tile_data == null:
			continue

		var live = WaterLive.new()
		live.setup(tile, tile_data, "%s/tile_%d_%d.water" % [_water_dir, tile.x, tile.y], _base_rate, _generator, _dry_start)
		live.rate = rate
		live.runoff = runoff
		var depth: PackedFloat32Array = PackedFloat32Array()

		if saved:
			depth = WaterLive.WaterStore.load_depth(live._path, tile_data.samples)

		live.begin(depth)

		if saved and not depth.is_empty():
			live.wake(SETTLE_SECONDS)

		_mutex.lock()
		var replay: Array = _edits.duplicate()
		_mutex.unlock()

		for edit in replay:
			if _generator.tile_of(edit[0].x, edit[0].z) == tile:
				if edit[2]:
					live.fill(edit[0], edit[1])
				else:
					live.dig(edit[0], edit[1])

		_mutex.lock()
		_tiles[tile] = live
		_used[tile] = Time.get_ticks_msec()
		_mutex.unlock()
		_trim()
		print("water: loaded tile %s (%d active, %.0f MB of water memory)" % [str(tile), _tiles.size(), float(OS.get_static_memory_usage() - _baseline) / 1048576.0])
		break      # one load per pass, so the others keep running


# Over the memory limit: drops the least recently stepped tile that is not the centre.
func _trim() -> void:
	while OS.get_static_memory_usage() - _baseline > MEMORY_LIMIT_BYTES and _tiles.size() > 1:
		var oldest: Vector2i = centre
		var oldest_msec: int = 1 << 60

		for tile in _tiles:
			if tile != centre and int(_used.get(tile, 0)) < oldest_msec:
				oldest = tile
				oldest_msec = int(_used.get(tile, 0))

		if oldest == centre:
			return

		print("water: over the memory limit, dropping tile %s" % str(oldest))
		_drop(oldest)

	_mutex.lock()
	_stats["memory"] = OS.get_static_memory_usage() - _baseline
	_stats["loaded"] = _tiles.size()
	_mutex.unlock()


func _drop(tile: Vector2i) -> void:
	_mutex.lock()
	var live = _tiles.get(tile)
	_mutex.unlock()

	if live == null:
		return

	live.unload()
	_mutex.lock()
	_tiles.erase(tile)
	_saved[tile] = true
	_mutex.unlock()
	print("water: tile %s saved and unloaded" % str(tile))


# Draws the depths of every shared border pair level, moving water from the higher surface to the
# lower. A cell on a sea (ground at or under 0) is held by its own tile and left alone.
func _couple(a, b, ka: PackedInt32Array, kb: PackedInt32Array, dt: float) -> void:
	var sa = a.sim
	var sb = b.sim
	var side: int = sa.side
	var width: float = sa.spacing_m
	var moved_a: float = 0.0
	var moved_b: float = 0.0
	var crossed: float = 0.0

	for n in range(ka.size()):
		var da: float = sa.depth_at(ka[n])
		var db: float = sb.depth_at(kb[n])

		if da <= 0.0 and db <= 0.0:
			continue

		var ga: float = sa.ground[ka[n]]
		var gb: float = sb.ground[kb[n]]

		if ga <= 0.0 or gb <= 0.0:
			continue

		var la: float = ga + da
		var lb: float = gb + db
		var face: float = maxf(la, lb) - maxf(ga, gb)

		if face <= WaterSim.FACE_MIN_M:
			continue

		var move: float = (la - lb) * 0.5
		var cap: float = WaterSim.SPEED_MAX_M_S * face * dt / width
		move = clampf(move, -cap, cap)
		move = minf(move, da) if move > 0.0 else maxf(move, -db)

		if absf(move) < 0.00001:
			continue

		@warning_ignore("integer_division")
		sa.add_water(ka[n] % side, ka[n] / side, -move)
		@warning_ignore("integer_division")
		sb.add_water(kb[n] % side, kb[n] / side, move)

		crossed += absf(move) * width * width

		if move > 0.0:
			moved_b += move
		else:
			moved_a -= move

	_mutex.lock()
	_stats["moved_m3"] = float(_stats["moved_m3"]) + crossed
	_mutex.unlock()

	if moved_b > WAKE_DEPTH_M and not b.wants_run():
		b.wake(SETTLE_SECONDS)

	if moved_a > WAKE_DEPTH_M and not a.wants_run():
		a.wake(SETTLE_SECONDS)
