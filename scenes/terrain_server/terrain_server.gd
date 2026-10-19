extends Node

# Terrain server (plan step 16): answers clients' block requests from the
# edits store, the generated-block cache or the runtime generator.
#
#   godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=24600
#
# Options (after "--"):
#   --port=N        UDP port (default 24600)
#   --world=DIR     world folder (default res://worlds/base_world)
#   --clear-generated  throw away the generated ground at start (edits are kept);
#                     while running, creating the file clear_generated.now in the
#                     store folder does the same
#   --store=DIR     server store folder (default user://server_store/<world name>)
#   --threads=N     worker threads making blocks (default: processor count - 1)
#   --quit-after=S  stop after S seconds (headless checks)
#   --quit-when-empty  stop 10 s after the last player leaves, or after 5 min
#                      if nobody joins (the "play" launcher's own server)
#
# Clients start at the starter spawn point of tile (3,4).

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const StoreScript := preload("res://src/stream/server_block_store.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const FloraStoreScript := preload("res://src/stream/server_flora.gd")
const WaterLiveScript := preload("res://src/water/water_live.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")

const MAX_BATCH_BYTES := 192 * 1024
const MAX_QUEUE_PER_PEER := 20000
const WATER_BASE_RATE := 3.0            # meters of water per tick at each spring; the + and - keys scale it
const IDLE_LODS := 4                   # detail levels the idle builder keeps ahead of players
const IDLE_RADIUS_BLOCKS := 12         # circle around each player, in blocks of that level
const IDLE_MAX_DONE := 400000          # remembered built blocks (skips re-checking the store)

var generator
var store
var flora
var _water_updates: int = 0
var water_live                         # the starter tile's running water, tuned with + and - on the client
var _world_dir: String = ""
var settings
var spawn: Vector3 = Vector3.ZERO
var net
var _queue: Array = []                 # urgent [peer, key Vector4i], oldest first
var _prefetch: Array = []              # prefetch [peer, key], oldest first
var _queued: Dictionary = {}           # [peer, key] -> "u" urgent, "p" prefetch, "r" running
var _flora_queue: Array = []           # [peer, chunk Vector2i], oldest first
var _flora_queued: Dictionary = {}     # [peer, chunk] -> true
var _queue_mutex: Mutex = Mutex.new()  # guards the five above
var _work: Semaphore = Semaphore.new() # one post per queued item
var _workers: Array = []               # Threads making blocks
var _stopping: bool = false
var _max_running: int = 3
var _done: Array = []                  # [peer, key, bytes]
var _done_mutex: Mutex = Mutex.new()
var _peers: Dictionary = {}            # peer -> {"blocks": n, "bytes": n}
var _quit_at_msec: int = -1
var _quit_when_empty: bool = false
var _empty_since_msec: int = 0
var _quit_grace_msec: int = 10000
var _never_joined: bool = true
var _report_at_msec: int = 0
var _idle_threads: int = 2             # idle builder threads (--idle-threads=N, 0 turns it off)
var _idle_workers: Array = []
var _idle_offsets: Array = []          # [lod, dx, dz] nearest first, same for every player
var _idle_anchor: Dictionary = {}      # peer -> Vector3i LOD 0 block the player is at
var _idle_done: Dictionary = {}        # Vector4i -> true, built or found saved
var _idle_built: int = 0
var _aim: Dictionary = {}              # peer -> Vector2 ground point to make first (metres), from reported position and speed


var _clear_generated_at_start: bool = false
var _flag_check_msec: int = 0
var _store_path: String = ""


func _ready() -> void:
	net = $TerrainNet
	var port: int = 24600
	var world_dir: String = "res://worlds/base_world"
	var store_dir: String = ""
	_max_running = maxi(OS.get_processor_count() - 1, 1)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="):
			port = int(argument.trim_prefix("--port="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument == "--clear-generated":
			_clear_generated_at_start = true
		elif argument.begins_with("--store="):
			store_dir = argument.trim_prefix("--store=")
		elif argument.begins_with("--threads="):
			_max_running = maxi(int(argument.trim_prefix("--threads=")), 1)
		elif argument.begins_with("--idle-threads="):
			_idle_threads = maxi(int(argument.trim_prefix("--idle-threads=")), 0)
		elif argument == "--quit-when-empty":
			_quit_when_empty = true
		elif argument.begins_with("--quit-after="):
			_quit_at_msec = Time.get_ticks_msec() + int(float(argument.trim_prefix("--quit-after=")) * 1000.0)

	var errors: Array = []
	settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or rules.is_empty() or not errors.is_empty():
		push_error("Terrain server: %s" % "\n".join(errors))
		get_tree().quit(1)
		return

	generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world_dir + "/tiles")
	store = StoreScript.new()

	if store_dir == "":
		store_dir = "user://server_store/%s" % settings.world_name.validate_filename()

	_store_path = store_dir
	var problem: String = store.setup(generator, store_dir)

	if _clear_generated_at_start:
		store.clear_generated()
		print("server: cleared the generated ground as asked (--clear-generated)")

	if problem != "":
		push_error("Terrain server: %s" % problem)
		get_tree().quit(1)
		return

	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	flora = FloraStoreScript.new()
	flora.setup(placer, store_dir)
	spawn = _spawn_point(world_dir)
	_world_dir = world_dir
	_start_water()

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_server(port, 32)

	if error != OK:
		push_error("Terrain server: cannot listen on port %d (%s)" % [port, error_string(error)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	net.blocks_requested.connect(_on_blocks_requested)
	net.dig_requested.connect(_on_dig_requested)
	net.flora_requested.connect(_on_flora_requested)
	net.cut_flora_requested.connect(_on_cut_flora_requested)
	net.position_reported.connect(_on_position_reported)
	net.water_rate_requested.connect(_on_water_rate_requested)
	net.water_requested.connect(_on_water_requested)
	_report_at_msec = Time.get_ticks_msec() + 10000

	for n in range(_max_running):
		var thread: Thread = Thread.new()
		thread.start(_worker_loop)
		_workers.append(thread)

	if OS.has_environment("DYNASTY_IDLE_THREADS"):
		_idle_threads = maxi(int(OS.get_environment("DYNASTY_IDLE_THREADS")), 0)

	_make_idle_offsets()

	for n in range(_idle_threads):
		var idle: Thread = Thread.new()
		idle.start(_idle_loop)
		_idle_workers.append(idle)

	print("Terrain server listening on port %d with %d worker threads; store %s; spawn %s" % [port, _max_running, store_dir, str(spawn)])


func _spawn_point(world_dir: String) -> Vector3:
	var path: String = world_dir + "/tiles/tile_3_4.tile"
	var point: Vector3 = Vector3(3.5, 0.0, 4.5) * float(settings.tile_size_m)
	var head: Dictionary = TileFileScript.read_header(path)

	if head["ok"]:
		var starter: Dictionary = TileFileScript.read_list(path, head["table"], "starter")

		if starter["ok"] and typeof(starter["value"]) == TYPE_DICTIONARY and starter["value"].has("spawn_point"):
			var s: Array = starter["value"]["spawn_point"]
			point = Vector3(float(s[0]), 0.0, float(s[2]))

	point.y = maxf(generator.surface_height(point.x, point.z), 0.0) + 2.0
	return point


func _on_peer_connected(peer_id: int) -> void:
	_never_joined = false
	_peers[peer_id] = {"blocks": 0, "bytes": 0, "since": Time.get_ticks_msec()}
	print("Client %d connected" % peer_id)
	net.welcome.rpc_id(peer_id, {
		"protocol": NetScript.PROTOCOL_VERSION,
		"world_name": settings.world_name,
		"master_seed": settings.master_seed,
		"tile_size_m": settings.tile_size_m,
		"min_tile": settings.min_tile,
		"tiles_per_side": settings.tiles_x,
		"revisions": store.revisions(),
		"spawn": spawn,
		"terrain_version": Layout.TERRAIN_VERSION,
		"tiles_stamp": store.tiles_stamp,
		"starter_stamp": _starter_stamp(),
	})


# Starts the starter tile's running water on the tile as it is now loaded.
func _start_water() -> void:
	var water_tile: Vector2i = Vector2i(3, 4)
	var water_data = generator.get_tile(water_tile)

	if water_data.placeholder:
		return

	# Owner (2026-10-18): the world starts dry and the springs fill it, so the real water
	# paths show; --settled-water starts from the baked water file instead.
	var dry_start: bool = not OS.get_cmdline_user_args().has("--settled-water")

	if dry_start:
		water_data.sim_levels = PackedFloat32Array()
		water_data.sim_levels.resize(water_data.samples * water_data.samples)
		water_data.sim_levels.fill(NAN)

	water_live = WaterLiveScript.new()
	water_live.setup(water_data, "%s/water/tile_%d_%d.water" % [_world_dir, water_tile.x, water_tile.y], WATER_BASE_RATE, generator, dry_start)


# Which starter ground (shipped client cache) fits the tiles: terrain version and the spawn tile file.
func _starter_stamp() -> String:
	return "%d_%s" % [Layout.TERRAIN_VERSION, Layout.tile_stamp(generator.tiles_dir, Vector2i(3, 4))]


# Where the player will touch the ground: straight below if hovering, farther
# along their heading the higher and faster they are. Blocks nearest this
# point are made first.
func _on_position_reported(peer_id: int, position: Vector3, velocity: Vector3) -> void:
	var height: float = maxf(position.y - generator.surface_height(position.x, position.z), 0.0)
	var descent: float = maxf(-velocity.y, 10.0)
	var seconds: float = minf(height / descent, 8.0)
	var point: Vector2 = Vector2(position.x + velocity.x * seconds, position.z + velocity.z * seconds)
	_queue_mutex.lock()
	_aim[peer_id] = point
	_queue_mutex.unlock()


func _on_peer_disconnected(peer_id: int) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	print("Client %d left after %d blocks, %.1f MB; flora %.1f MB" % [
		peer_id, int(info.get("blocks", 0)), float(info.get("bytes", 0)) / 1048576.0, float(info.get("flora_bytes", 0)) / 1048576.0
	])
	_peers.erase(peer_id)
	_queue_mutex.lock()
	_idle_anchor.erase(peer_id)
	_aim.erase(peer_id)
	_queue = _queue.filter(func(item): return item[0] != peer_id)
	_prefetch = _prefetch.filter(func(item): return item[0] != peer_id)
	_flora_queue = _flora_queue.filter(func(item): return item[0] != peer_id)
	_queue_mutex.unlock()


# Urgent keys go before every prefetch key; a prefetch key asked for again
# as urgent moves up.
func _on_blocks_requested(peer_id: int, keys: PackedInt32Array, urgent: int) -> void:
	var added: int = 0
	_queue_mutex.lock()

	for n in range(keys.size() / 4):
		if _queue.size() + _prefetch.size() >= MAX_QUEUE_PER_PEER:
			break

		var key: Vector4i = Vector4i(keys[4 * n], keys[4 * n + 1], keys[4 * n + 2], clampi(keys[4 * n + 3], 0, 15))
		var id: Array = [peer_id, key]
		var state: String = _queued.get(id, "")

		if n < urgent:
			if key.w == 0:
				_idle_anchor[peer_id] = Vector3i(key.x, key.y, key.z)

			if state == "" or state == "p":
				_queued[id] = "u"
				_queue.append(id)
				added += 1
		elif state == "":
			_queued[id] = "p"
			_prefetch.append(id)
			added += 1

	_queue_mutex.unlock()

	for n in range(added):
		_work.post()


# Flora chunks wait behind urgent blocks and before prefetch blocks.
func _on_flora_requested(peer_id: int, chunks: PackedInt32Array) -> void:
	var added: int = 0
	_queue_mutex.lock()

	for n in range(chunks.size() / 2):
		var id: Array = [peer_id, Vector2i(chunks[2 * n], chunks[2 * n + 1])]

		if _flora_queue.size() < MAX_QUEUE_PER_PEER and not _flora_queued.has(id):
			_flora_queued[id] = true
			_flora_queue.append(id)
			added += 1

	_queue_mutex.unlock()

	for n in range(added):
		_work.post()


func _on_water_rate_requested(_peer_id: int, direction: int) -> void:
	if water_live == null:
		return

	var rate: float = water_live.step_rate(direction)
	print("server: water flow rate now x%.2f" % rate)
	net.water_rate.rpc(rate, true)


func _on_water_requested(peer_id: int, chunks: PackedInt32Array) -> void:
	for n in range(chunks.size() / 2):
		var chunk: Vector2i = Vector2i(chunks[2 * n], chunks[2 * n + 1])
		net.deliver_water.rpc_id(peer_id, chunk, flora.water_bytes(chunk))


# New levels from the water thread: swap them into the tile and tell clients.
func _poll_water() -> void:
	if water_live == null:
		return

	var levels: PackedFloat32Array = water_live.take_levels()

	if not levels.is_empty():
		water_live.data.sim_levels = levels
		_water_updates += 1

		if _water_updates == 1 or _water_updates % 10 == 0:
			var wet: int = 0

			for level in levels:
				if not is_nan(level):
					wet += 1

			print("server: water update %d, %d wet squares" % [_water_updates, wet])

		flora.clear_water()
		net.water_changed.rpc()

		if not water_live.busy:
			net.water_rate.rpc(water_live.rate, false)


func _on_cut_flora_requested(_peer_id: int, chunk: Vector2i, id: int) -> void:
	if flora.cut(chunk, id):
		net.flora_cut.rpc(chunk, id)
		print("Cut flora item %d in chunk %s" % [id, str(chunk)])


func _on_dig_requested(_peer_id: int, center: Vector3, radius: float) -> void:
	var tiles: Array = store.dig_sphere(center, radius)

	for tile in tiles:
		net.tile_changed.rpc(tile, store.revision_of(tile))

	net.dug.rpc(center, radius)

	print("Dug a %.1f m sphere at %s; tiles %s" % [radius, str(center), str(tiles)])


func _process(_delta: float) -> void:
	if store == null:
		return

	_poll_water()

	# Send what the workers made, batched per peer.
	_done_mutex.lock()
	var done: Array = _done
	_done = []
	_done_mutex.unlock()
	var batches: Dictionary = {}
	_queue_mutex.lock()

	for entry in done:
		if entry.size() > 3:
			_flora_queued.erase([entry[0], entry[1]])
		else:
			_queued.erase([entry[0], entry[1]])

	var queued: Array = [_queue.size(), _prefetch.size()]
	_queue_mutex.unlock()

	for entry in done:
		if not _peers.has(entry[0]):
			continue

		if entry.size() > 3:
			net.deliver_flora.rpc_id(entry[0], entry[1], entry[2], entry[4])
			_peers[entry[0]]["flora_bytes"] = int(_peers[entry[0]].get("flora_bytes", 0)) + (entry[2] as PackedByteArray).size()
			continue

		if not batches.has(entry[0]):
			batches[entry[0]] = [PackedInt32Array(), [], 0]

		var batch: Array = batches[entry[0]]
		var key: Vector4i = entry[1]
		batch[0].append_array(PackedInt32Array([key.x, key.y, key.z, key.w]))
		batch[1].append(entry[2])
		batch[2] += (entry[2] as PackedByteArray).size()

		if batch[2] >= MAX_BATCH_BYTES:
			_send(entry[0], batch)
			batches[entry[0]] = [PackedInt32Array(), [], 0]

	for peer_id in batches:
		if not batches[peer_id][1].is_empty():
			_send(peer_id, batches[peer_id])

	var now: int = Time.get_ticks_msec()

	var flag_path: String = _store_path + "/clear_generated.now"

	if now >= _flag_check_msec:
		_flag_check_msec = now + 3000

		if FileAccess.file_exists(flag_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(flag_path))
			store.clear_generated()
			print("server: cleared the generated ground as asked (clear_generated.now)")

		# A bake finished: the ground is made again from the new tiles, and clients reload.
		if store.check_tiles(now):
			generator.forget_tiles()
			flora.clear_memory()
			WaterGridScript.forget_ground()

			# The water ran on the old ground (owner, 2026-10-19: it stood as a dome where the
			# new bake had taken the pond away): start it again on the new tiles.
			if water_live != null:
				water_live.stop()
				water_live = null

			_start_water()

			net.ground_reset.rpc(store.tiles_stamp, _starter_stamp())
			print("server: the tile files changed (a bake finished); generated ground thrown away, players reload")

	if now >= _report_at_msec:
		_report_at_msec = now + 10000
		print("server: %d urgent and %d prefetch queued; generated %d, cache hits %d, edit hits %d; flora chunks %d made, %d from memory; idle-built %d columns; bad blocks %d, failed tile loads %d" % [
			queued[0], queued[1], store.blocks_generated, store.cache_hits, store.edit_hits, flora.chunks_made, flora.memory_hits, _idle_built, store.bad_blocks, generator.failed_tiles
		])

	if _quit_when_empty and _quit_at_msec < 0:
		if not _peers.is_empty():
			_empty_since_msec = 0
		elif _empty_since_msec == 0:
			_empty_since_msec = now
			_quit_grace_msec = 300000 if _never_joined else 10000
		elif now - _empty_since_msec >= _quit_grace_msec:
			print("server: no players left")
			_quit_at_msec = now

	if _quit_at_msec > 0 and now >= _quit_at_msec:
		_quit_at_msec = -1
		store.flush()
		print("server: done; generated %d, cache hits %d, edit hits %d" % [store.blocks_generated, store.cache_hits, store.edit_hits])
		get_tree().quit(0)


func _send(peer_id: int, batch: Array) -> void:
	net.deliver_blocks.rpc_id(peer_id, batch[0], batch[1])
	_peers[peer_id]["blocks"] += batch[1].size()
	_peers[peer_id]["bytes"] += int(batch[2])


# Worker thread: takes the next block, urgent ones first, and makes it.
func _worker_loop() -> void:
	while true:
		_work.wait()
		_queue_mutex.lock()
		var item: Array = []
		var flora_item: Array = []

		# Order: urgent blocks, flora chunks, prefetch blocks.
		if _queue.is_empty() and not _flora_queue.is_empty():
			flora_item = _flora_queue.pop_front()

		while flora_item.is_empty() and item.is_empty() and not (_queue.is_empty() and _prefetch.is_empty()):
			var urgent: bool = not _queue.is_empty()
			var next: Array = _pop_nearest_urgent() if urgent else _prefetch.pop_front()

			# A prefetch entry moved up to urgent, or already taken, is skipped.
			if _queued.get(next, "") == ("u" if urgent else "p"):
				_queued[next] = "r"
				item = next

		var stopping: bool = _stopping
		_queue_mutex.unlock()

		if stopping:
			return

		if not flora_item.is_empty():
			var chunk_bytes: PackedByteArray = flora.chunk_bytes(flora_item[1])
			var water_bytes: PackedByteArray = flora.water_bytes(flora_item[1])
			_done_mutex.lock()
			_done.append([flora_item[0], flora_item[1], chunk_bytes, "flora", water_bytes])
			_done_mutex.unlock()
			continue

		if item.is_empty():
			continue

		var key: Vector4i = item[1]
		var bytes: PackedByteArray = store.block_bytes(Vector3i(key.x, key.y, key.z), key.w)
		var check: PackedByteArray = PackedByteArray()
		check.resize(4)
		check.encode_u32(0, hash(bytes) & 0xffffffff)
		bytes.append_array(check)           # the client verifies this before using the block
		_done_mutex.lock()
		_done.append([item[0], key, bytes])
		_done_mutex.unlock()


# Takes the urgent block closest to where its player will land (queue mutex held).
# Looks at the oldest 400 only, so one pick stays cheap; blocks of players with
# no report yet go in arrival order.
func _pop_nearest_urgent() -> Array:
	var best: int = 0
	var best_score: float = INF

	for n in range(mini(_queue.size(), 400)):
		var item: Array = _queue[n]
		var aim: Variant = _aim.get(item[0], null)

		if aim == null:
			return _queue.pop_front() if n == 0 else _queue.pop_at(n)

		var key: Vector4i = item[1]
		var block_m: float = float(16 << key.w)
		var centre: Vector2 = Vector2((float(key.x) + 0.5) * block_m, (float(key.z) + 0.5) * block_m)
		# Finer detail first among equals: ground you stand on before far views.
		var score: float = centre.distance_to(aim) + 60.0 * float(key.w)

		if score < best_score:
			best_score = score
			best = n

	return _queue.pop_at(best)


# Block offsets around a player, nearest first; each detail level covers a
# circle of IDLE_RADIUS_BLOCKS blocks of its own size, so coarse levels reach
# farther. Levels are interleaved by how far out in their own circle they are.
func _make_idle_offsets() -> void:
	var list: Array = []

	for lod in range(IDLE_LODS):
		for dz in range(-IDLE_RADIUS_BLOCKS, IDLE_RADIUS_BLOCKS + 1):
			for dx in range(-IDLE_RADIUS_BLOCKS, IDLE_RADIUS_BLOCKS + 1):
				var d: float = sqrt(float(dx * dx + dz * dz)) / float(IDLE_RADIUS_BLOCKS)

				if d <= 1.0:
					list.append([d + 0.01 * float(lod), lod, dx, dz])

	list.sort_custom(func(a, b): return a[0] < b[0])
	_idle_offsets = list.map(func(item): return [item[1], item[2], item[3]])


# Idle thread: while no player is waiting for anything, makes and saves the
# blocks around each player, starting with the ones closest to them. Real
# requests always go first (checked before every block).
func _idle_loop() -> void:
	var cursors: Dictionary = {}       # peer -> [anchor, next offset index]

	while true:
		_queue_mutex.lock()
		var stopping: bool = _stopping
		var busy: bool = not (_queue.is_empty() and _prefetch.is_empty() and _flora_queue.is_empty())
		var anchors: Dictionary = _idle_anchor.duplicate()

		for peer in anchors:
			if _aim.has(peer):
				var aim: Vector2 = _aim[peer]
				anchors[peer] = Vector3i(int(floor(aim.x / 16.0)), anchors[peer].y, int(floor(aim.y / 16.0)))

		_queue_mutex.unlock()

		if stopping:
			return

		if busy or anchors.is_empty():
			OS.delay_msec(20)
			continue

		var worked: bool = false

		for peer in anchors:
			var anchor: Vector3i = anchors[peer]
			var cursor: Array = cursors.get(peer, [Vector3i(), 0])

			# Followed the player somewhere new: start again from the nearest blocks.
			if (cursor[0] - anchor).length() > 2.0:
				cursor = [anchor, 0]

			var offset: Array = []

			while cursor[1] < _idle_offsets.size():
				offset = _idle_offsets[cursor[1]]
				cursor[1] += 1

				if _idle_prebuild_column(anchor, offset):
					worked = true
					break

			cursors[peer] = cursor

			if worked:
				break

		if not worked:
			OS.delay_msec(100)


# Makes the surface blocks of one column (one block above and below the
# ground). True if it made anything.
func _idle_prebuild_column(anchor: Vector3i, offset: Array) -> bool:
	var lod: int = offset[0]
	var block_m: float = float(16 << lod)
	var bx: int = (anchor.x >> lod) + offset[1]
	var bz: int = (anchor.z >> lod) + offset[2]
	var key: Vector4i = Vector4i(bx, 0, bz, lod)

	_queue_mutex.lock()
	var seen: bool = _idle_done.has(key)

	if _idle_done.size() >= IDLE_MAX_DONE:
		_idle_done.clear()

	_idle_done[key] = true     # claimed, so no other idle thread repeats it
	_queue_mutex.unlock()

	if seen:
		return false

	var low: float = INF
	var high: float = -INF

	for k in range(5):
		var sx: float = (float(bx) + (0.5 if k == 4 else float(k % 2) * 0.99)) * block_m
		var sz: float = (float(bz) + (0.5 if k == 4 else float(k / 2 % 2) * 0.99)) * block_m
		var h: float = generator.surface_height(sx, sz)
		low = minf(low, h)
		high = maxf(high, h)

	var made: bool = false

	for by in range(int(floor(low / block_m)) - 1, int(floor(high / block_m)) + 2):
		if store.ensure_block(Vector3i(bx, by, bz), lod):
			made = true

	_queue_mutex.lock()

	if made:
		_idle_built += 1

	_queue_mutex.unlock()
	return made


func _exit_tree() -> void:
	_queue_mutex.lock()
	_stopping = true
	_queue_mutex.unlock()

	for thread in _workers:
		_work.post()

	for thread in _workers:
		thread.wait_to_finish()

	for thread in _idle_workers:
		thread.wait_to_finish()

	if water_live != null:
		water_live.stop()

	if store != null:
		store.flush()
