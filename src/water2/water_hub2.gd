extends RefCounted

# Dynasty water stage d: the server's water behind the --water2 flag (Sonny, 31 Oct 2026). Same API as src/water/water_hub.gd (setup, set_centre, set_live, take_updates, data_of, sim_of, stats,
# step_rate, set_runoff, dig, fill, stop, rate, runoff, busy, centre, data), so terrain_server.gd swaps one constructor and nothing else changes: it still gives each tile's data the levels
# (`set_sim`), and the existing client draws them with the old shader (the swap boundary). The old system stays the default.
# One tile runs, the first of set_live; every other tile stays as baked. On that tile one WINDOW x WINDOW cell window (the wettest, from water_window.gd) is simulated by water_field.gd; the rest
# of the tile keeps its baked settled levels. Water that is wet on the window's border is held at its baked level there (rivers come in and leave, lakes stay), the dry border is a wall.

const Field := preload("res://src/water2/water_field.gd")
const WaterWindow := preload("res://src/water2/water_window.gd")
const FlowTexture := preload("res://src/water2/water_flow_texture.gd")

const SOURCES_PATH := "res://src/water2/water_sources.json"
const RAIN_PER_RUNOFF := 0.0001   # shortcut: metres of rain per second for each 1.0 the server's runoff is above 1.0 (the weather swell); tune with real storms
const WINDOW := 128
const TICK_S := 1.0
const PUBLISH_TICKS := 15
const CPU_DUTY := 0.5            # share of one core the water thread may use, as the old hub
const DRAW_M := 0.12             # water thinner than this is not drawn (TileTerrainData WetMeters)
const FILM_M := 0.14             # baked cells this thin are the 13 cm film of the settled files: drawn as film while the live water is thinner

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
var _stats: Dictionary = {"moved_m3": 0.0, "memory": 0, "loaded": 0}


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


func dig(_center: Vector3, _radius: float) -> void:
	pass   # shortcut: digs and fills do not reach the field yet (the bed would change under the window; stage e)


func fill(_center: Vector3, _radius: float) -> void:
	pass


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

			if _field != null:
				print("water2: tile %s window %d x %d cells at sample %d, %d" % [str(tile), WINDOW, WINDOW, window_origin.x, window_origin.y])

		if _field == null:
			busy = false
			OS.delay_msec(500)
			continue

		var start: int = Time.get_ticks_usec()
		_field.rain_mps = maxf(runoff - 1.0, 0.0) * RAIN_PER_RUNOFF
		_field.step(TICK_S)
		ticks += 1
		busy = _field.awake_blocks() > 0

		if ticks % PUBLISH_TICKS == 1:
			var levels: PackedFloat32Array = publish_levels(_base, tile_data.samples, _field, window_origin)
			var packet: Dictionary = FlowTexture.packet(_field, Vector2(tile_data.x0 + float(window_origin.x) * 8.0, tile_data.z0 + float(window_origin.y) * 8.0))
			_mutex.lock()
			_pending = levels
			_flow_pending = packet
			_mutex.unlock()

		var used: int = Time.get_ticks_usec() - start
		OS.delay_usec(int(float(used) * (1.0 / CPU_DUTY - 1.0)))
