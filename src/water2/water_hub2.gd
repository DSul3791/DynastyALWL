extends RefCounted

# Dynasty water stage d: the server's water behind the --water2 flag (Sonny, 31 Oct 2026). Same API as src/water/water_hub.gd (setup, set_centre, set_live, take_updates, data_of, sim_of, stats,
# step_rate, set_runoff, dig, fill, stop, rate, runoff, busy, centre, data), so terrain_server.gd swaps one constructor and nothing else changes: it still gives each tile's data the levels
# (`set_sim`), and the existing client draws them with the old shader (the swap boundary). The old system stays the default.
# One tile runs, the first of set_live; every other tile stays as baked. On that tile one WINDOW x WINDOW cell window (the wettest, from water_window.gd) is simulated by water_field.gd; the rest
# of the tile keeps its baked settled levels. Water that is wet on the window's border is held at its baked level there (rivers come in and leave, lakes stay), the dry border is a wall.

const Field := preload("res://src/water2/water_field.gd")
const WaterWindow := preload("res://src/water2/water_window.gd")
const FlowTexture := preload("res://src/water2/water_flow_texture.gd")
const DigWindows := preload("res://src/sullivan_water/live/dig_windows.gd")

const SOURCES_PATH := "res://src/water2/water_sources.json"
const RAIN_PER_RUNOFF := 0.0001   # shortcut: metres of rain per second for each 1.0 the server's runoff is above 1.0 (the weather swell); tune with real storms
const WINDOW := 128
const TICK_S := 1.0
const PUBLISH_TICKS := 15
const CPU_DUTY := 0.5            # share of one core the water thread may use, as the old hub
const DRAW_M := 0.12             # water thinner than this is not drawn (TileTerrainData WetMeters)
const FILM_M := 0.14             # baked cells this thin are the 13 cm film of the settled files: drawn as film while the live water is thinner
const NOTIFY_M := 0.01           # lag (rank 2, 4 Nov 2026): levels are published to clients only when a window cell moved this much since the last publish

var data
var rate: float = 10.0
var runoff: float = 1.0
var busy: bool = false
var centre: Vector2i = Vector2i.ZERO
var window_origin: Vector2i = Vector2i.ZERO   # sample (i, j) of the window's first cell, for pictures and logs

var _generator
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _quit: bool = false
var _data: Dictionary = {}
var _wanted: Array = []
var _pending: PackedFloat32Array = PackedFloat32Array()
var _flow_pending: Dictionary = {}   # the newest render texture packet (water_flow_texture.packet), taken once by take_flow
var _field = null
var _base: PackedFloat32Array = PackedFloat32Array()
var _sim_tile: Vector2i = Vector2i(-9999, -9999)
var _told: PackedFloat32Array = PackedFloat32Array()   # the levels last put in _pending (water thread only); empty = publish the next one
var _stats: Dictionary = {"moved_m3": 0.0, "memory": 0, "loaded": 0}
var _live = DigWindows.new()   # Sullivan water (7 Nov 2026): fine 2 m windows where players dig, so ditches and dams change the flow
var _last_levels: PackedFloat32Array = PackedFloat32Array()   # the levels last built on the water thread (what a new dig window starts from)
var _fine_pending: Dictionary = {}   # the newest fine sheet packets (dig_windows.fine_packets), taken once by take_fine
var _players: PackedVector2Array = PackedVector2Array()   # player x, z, newest first (set_players): a 2 m region follows the first
var _fine_built: int = 0          # 2 m water packet sets built (the log line for the PC check)
var _fine_sent: bool = false      # the last fine packets named any region (so one more, empty, tells clients to drop them)
var _live_rect: Rect2 = Rect2()   # world x, z the dig windows draw into, as of the last publish (clients must re-ask chunks there too)


func setup(centre_tile: Vector2i, _water_dir: String, _base_rate: float, tile_generator, _dry_start: bool = false) -> void:
	_generator = tile_generator
	set_live([centre_tile])
	_thread = Thread.new()
	_thread.start(_run)


func stop() -> void:
	_mutex.lock()
	_quit = true
	_mutex.unlock()

	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func set_centre(tile: Vector2i) -> void:
	set_live([tile])


func set_live(tiles: Array) -> void:
	var wanted: Array = []
	var found: Dictionary = {}

	for tile in tiles:
		if wanted.size() >= 4 or tile in wanted:
			continue

		var tile_data = _generator.get_tile(tile)

		if tile_data == null or tile_data.placeholder:
			continue

		wanted.append(tile)
		found[tile] = tile_data

	if wanted.is_empty():
		return

	_mutex.lock()
	_wanted = wanted
	_data = found
	centre = wanted[0]
	data = found[centre]
	_mutex.unlock()


func step_rate(direction: int) -> float:
	rate = clampf(rate * pow(1.1, float(direction)), 0.5, 40.0)   # shortcut: the rate does not change the new sim yet (stage e: it scales springs and rain)
	return rate


func set_runoff(value: float) -> void:
	runoff = value


# The server's ground store, so the dig windows read the same ground the players get (src/sullivan_water/live/dig_windows.gd).
func set_store(store) -> void:
	_live.set_store(store)


# Digs and fills reach the water through the Sullivan dig windows; the 8 m field around them keeps its baked bed.
func dig(center: Vector3, radius: float) -> void:
	_live.dig(center, radius, false)


func fill(center: Vector3, radius: float) -> void:
	_live.dig(center, radius, true)


func take_updates() -> Array:
	_mutex.lock()
	var levels: PackedFloat32Array = _pending
	_pending = PackedFloat32Array()
	var tile: Vector2i = _sim_tile
	_mutex.unlock()

	if levels.is_empty():
		return []

	return [[tile, levels, levels]]


# The newest render texture packet for clients ({} when nothing new since the last call): see water_flow_texture.gd packet / unpack.
func take_flow() -> Dictionary:
	_mutex.lock()
	var packet: Dictionary = _flow_pending
	_flow_pending = {}
	_mutex.unlock()
	return packet


# The newest fine sheet packets for clients ({} when nothing new): see dig_windows.fine_packets.
func take_fine() -> Dictionary:
	_mutex.lock()
	var packet: Dictionary = _fine_pending
	_fine_pending = {}
	_mutex.unlock()
	return packet


# The players' x, z (the server, every 2 s): a 2 m water region follows the first while there is water near them (dig_windows.follow).
func set_players(points: PackedVector2Array) -> void:
	_mutex.lock()
	_players = points
	_mutex.unlock()


# Where the dig windows draw (world x, z), so the server tells clients to re-ask those chunks as well as the 8 m window's. Empty when none.
func live_rect() -> Rect2:
	_mutex.lock()
	var r: Rect2 = _live_rect
	_mutex.unlock()
	return r


func data_of(tile: Vector2i):
	_mutex.lock()
	var found = _data.get(tile)
	_mutex.unlock()
	return found


func sim_of(_tile: Vector2i):
	return null


func stats() -> Dictionary:
	_mutex.lock()
	var copy: Dictionary = _stats.duplicate()
	_mutex.unlock()
	return copy


# The field of the wettest window of a tile, with the wet border held at its baked level: {field, origin (Vector2i), base (the baked levels)} or {} for a tile without settled water.
static func build(tile_data):
	var levels: PackedFloat32Array = tile_data.sim_snapshot()

	if levels.is_empty():
		return {}

	var tile: Dictionary = {"heights": tile_data.heights, "levels": levels, "samples": tile_data.samples, "cell_m": 8.0}
	var spot: Dictionary = WaterWindow.wettest(tile, WINDOW)
	var f = WaterWindow.window(tile, int(spot["i0"]), int(spot["j0"]), WINDOW)

	for j in range(WINDOW):
		for i in range(WINDOW):
			if (i == 0 or j == 0 or i == WINDOW - 1 or j == WINDOW - 1) and f.depth[j * WINDOW + i] > 0.0:
				f.fix_level(i, j, f.bed[j * WINDOW + i] + f.depth[j * WINDOW + i])

	for k in range(WINDOW * WINDOW):
		if f.bed[k] < 0.0 and not f.fixed.has(k):
			f.fix_level(k % WINDOW, k / WINDOW, 0.0)   # the sea is held at level 0 (it is drawn by the sea plane, not by these levels), so rivers end in it instead of filling the sea bed

	var allowed: PackedByteArray = PackedByteArray()
	allowed.resize(WINDOW * WINDOW)

	for j in range(WINDOW):
		for i in range(WINDOW):
			var m: int = j * WINDOW + i

			if f.depth[m] > 0.0 or f.bed[m] < 0.0:
				allowed[m] = 1

	f.set_channel_mask(allowed)
	f.hold_steady()
	apply_sources(f, Vector2i(int(spot["i0"]), int(spot["j0"])), tile_data.x0, tile_data.z0, JSON.parse_string(FileAccess.get_file_as_string(SOURCES_PATH)).get("%d_%d" % [tile_data.tile.x, tile_data.tile.y], {}))
	return {"field": f, "origin": Vector2i(int(spot["i0"]), int(spot["j0"])), "base": levels}


# Springs and sinks from data: cfg = {springs: [{x, z, m3_s}], sinks: [...]} in world metres; points outside the window are ignored (and counted by the return value, the number placed).
static func apply_sources(f, origin: Vector2i, x0: float, z0: float, cfg: Dictionary) -> int:
	var placed: int = 0

	for kind in ["springs", "sinks"]:
		for row in cfg.get(kind, []):
			var i: int = int(round((float(row["x"]) - x0) / f.cell_m)) - origin.x
			var j: int = int(round((float(row["z"]) - z0) / f.cell_m)) - origin.y

			if i < 0 or j < 0 or i >= f.w or j >= f.h:
				continue

			if kind == "springs":
				f.add_spring(i, j, float(row["m3_s"]))
			else:
				f.add_sink(i, j, float(row["m3_s"]))

			placed += 1

	return placed


# The drawn levels of a tile: the baked ones outside the window, inside it bed + depth where the water is thick enough to draw, and a film on the bed of every baked wet cell where the live water is thinner.
static func publish_levels(base: PackedFloat32Array, samples: int, f, origin: Vector2i) -> PackedFloat32Array:
	var out: PackedFloat32Array = base.duplicate()

	for j in range(f.h):
		for i in range(f.w):
			var k: int = (origin.y + j) * samples + origin.x + i
			var m: int = j * f.w + i
			var d: float = f.depth[m]

			if f.bed[m] < 0.0:
				out[k] = base[k]
			elif d >= DRAW_M:
				out[k] = f.bed[m] + d
			elif not is_nan(base[k]) and base[k] - f.bed[m] <= FILM_M:
				out[k] = base[k]
			elif not is_nan(base[k]):
				# Dave 2 Nov 2026 ("streams break into puddle blobs"): a baked wet cell where the live water ran thin was dropped, so a stream broke into
				# separate pools along its bed. It keeps a film on its bed instead (the 13 cm of the settled files), so the channel stays one body of water.
				out[k] = f.bed[m] + FILM_M - 0.01
			else:
				out[k] = NAN

	return out


# Lag (rank 2, Jason with Sonny, 4 Nov 2026): settled water was published every PUBLISH_TICKS anyway, so the server swapped the levels in, cleared the
# packed water and told every client "the water moved" about twice a second for nothing. Whether any window cell moved NOTIFY_M or more since the levels
# last sent (not since the last tick, so a slow drift still goes out once it adds up), or turned wet or dry (any amount, so shore edges never go stale).
static func levels_moved(old: PackedFloat32Array, new: PackedFloat32Array, samples: int, origin: Vector2i, w: int, h: int, min_m: float = NOTIFY_M) -> bool:
	if old.size() != new.size():
		return true

	for j in range(h):
		var row: int = (origin.y + j) * samples + origin.x

		for i in range(w):
			var a: float = old[row + i]
			var b: float = new[row + i]

			if is_nan(a) != is_nan(b):
				return true

			if not is_nan(a) and absf(b - a) >= min_m:
				return true

	return false


func _run() -> void:
	var ticks: int = 0

	while true:
		_mutex.lock()
		var quit: bool = _quit
		var tile: Vector2i = _wanted[0] if not _wanted.is_empty() else Vector2i(-9999, -9999)
		var tile_data = _data.get(tile)
		_mutex.unlock()

		if quit:
			return

		if tile_data == null:
			OS.delay_msec(100)
			continue

		if tile != _sim_tile:
			var built: Dictionary = build(tile_data)
			_mutex.lock()
			_sim_tile = tile
			_field = built.get("field")
			window_origin = built.get("origin", Vector2i.ZERO)
			_base = built.get("base", PackedFloat32Array())
			_mutex.unlock()
			_told = PackedFloat32Array()

			if _field != null:
				print("water2: tile %s window %d x %d cells at sample %d, %d" % [str(tile), WINDOW, WINDOW, window_origin.x, window_origin.y])

		if _field == null:
			busy = false
			OS.delay_msec(500)
			continue

		var start: int = Time.get_ticks_usec()
		_field.rain_mps = maxf(runoff - 1.0, 0.0) * RAIN_PER_RUNOFF
		_field.step(TICK_S)
		var levels_now: PackedFloat32Array = _last_levels if not _last_levels.is_empty() else _base
		var samples: int = tile_data.samples
		var x0: float = tile_data.x0
		var z0: float = tile_data.z0
		var level_at: Callable = func(x: float, z: float) -> float:
			var si: int = int(round((x - x0) / 8.0))
			var sj: int = int(round((z - z0) / 8.0))
			if si < 0 or sj < 0 or si >= samples or sj >= samples or levels_now.is_empty():
				return NAN
			return levels_now[sj * samples + si]
		_mutex.lock()
		var players: PackedVector2Array = _players
		_mutex.unlock()
		_live.follow(players, level_at)
		_live.update(TICK_S, level_at)
		ticks += 1
		busy = _field.awake_blocks() > 0

		if ticks % PUBLISH_TICKS == 1:
			var levels: PackedFloat32Array = publish_levels(_base, tile_data.samples, _field, window_origin)
			var packet: Dictionary = FlowTexture.packet(_field, Vector2(tile_data.x0 + float(window_origin.x) * 8.0, tile_data.z0 + float(window_origin.y) * 8.0))
			var moved: bool = levels_moved(_told, levels, tile_data.samples, window_origin, _field.w, _field.h)
			_last_levels = levels.duplicate()   # before the dig windows draw in: a new window starts from the 8 m water, not from itself
			moved = _live.publish(levels, tile_data.samples, tile_data.x0, tile_data.z0) or moved

			if moved:
				_told = levels

			_mutex.lock()

			if moved:
				_pending = levels

			_flow_pending = packet
			_live_rect = _live.drawn_rect()
			_mutex.unlock()
			# Outside the lock: building the 2 m textures takes a few ms. Sleeping regions every 4th publish (late joiners get them within a minute).
			var fine: Dictionary = _live.fine_packets(ticks % (PUBLISH_TICKS * 4) == 1)

			if not fine["keys"].is_empty() or _fine_sent:
				_fine_sent = not fine["keys"].is_empty()
				_fine_built += 1

				if _fine_built == 1 or _fine_built % 20 == 0:
					print("water live: 2 m water packets %d: %d regions, %d textures (tick %d)" % [_fine_built, fine["keys"].size(), fine["packets"].size(), ticks])
				_mutex.lock()
				_fine_pending = fine
				_mutex.unlock()

		# Bug 7 (lag, 2 Nov 2026): the window cost about 110 ms per simulated second, so with only the CPU_DUTY sleep the thread ran about 4.5 simulated seconds per
		# real second, held half a core all the time and published levels and the flow texture to every client about every 3 s. It now never runs ahead of real
		# time (TICK_S of sim per TICK_S of wall clock), still sleeps at least the duty share, and wakes every 100 ms to see a stop.
		var used: int = Time.get_ticks_usec() - start
		var rest_us: int = maxi(int(TICK_S * 1000000.0) - used, int(float(used) * (1.0 / CPU_DUTY - 1.0)))

		while rest_us > 0:
			OS.delay_usec(mini(rest_us, 100000))
			rest_us -= 100000
			_mutex.lock()
			var stopping: bool = _quit
			_mutex.unlock()

			if stopping:
				return
