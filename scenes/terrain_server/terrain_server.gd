extends Node

# Terrain server (plan step 16): answers clients' block requests from the
# edits store, the generated-block cache or the runtime generator.
#
#   godot --headless --path . res://scenes/terrain_server/terrain_server.tscn -- --port=24600
#
# Options (after "--"):
#   --port=N        UDP port (default 24600)
#   --world=DIR     world folder (default res://worlds/base_world)
#   --store=DIR     server store folder (default user://server_store/<world name>)
#   --threads=N     worker threads making blocks (default: processor count - 1)
#   --quit-after=S  stop after S seconds (headless checks)
#
# Clients start at the starter spawn point of tile (3,4).

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const StoreScript := preload("res://src/stream/server_block_store.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const FloraStoreScript := preload("res://src/stream/server_flora.gd")

const MAX_BATCH_BYTES := 192 * 1024
const MAX_QUEUE_PER_PEER := 20000

var generator
var store
var flora
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
var _report_at_msec: int = 0


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
		elif argument.begins_with("--store="):
			store_dir = argument.trim_prefix("--store=")
		elif argument.begins_with("--threads="):
			_max_running = maxi(int(argument.trim_prefix("--threads=")), 1)
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

	var problem: String = store.setup(generator, store_dir)

	if problem != "":
		push_error("Terrain server: %s" % problem)
		get_tree().quit(1)
		return

	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	flora = FloraStoreScript.new()
	flora.setup(placer, store_dir)
	spawn = _spawn_point(world_dir)
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
	_report_at_msec = Time.get_ticks_msec() + 10000

	for n in range(_max_running):
		var thread: Thread = Thread.new()
		thread.start(_worker_loop)
		_workers.append(thread)

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
	})


func _on_peer_disconnected(peer_id: int) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	print("Client %d left after %d blocks, %.1f MB; flora %.1f MB" % [
		peer_id, int(info.get("blocks", 0)), float(info.get("bytes", 0)) / 1048576.0, float(info.get("flora_bytes", 0)) / 1048576.0
	])
	_peers.erase(peer_id)
	_queue_mutex.lock()
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
			net.deliver_flora.rpc_id(entry[0], entry[1], entry[2])
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

	if now >= _report_at_msec:
		_report_at_msec = now + 10000
		print("server: %d urgent and %d prefetch queued; generated %d, cache hits %d, edit hits %d; flora chunks %d made, %d from memory" % [
			queued[0], queued[1], store.blocks_generated, store.cache_hits, store.edit_hits, flora.chunks_made, flora.memory_hits
		])

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
			var next: Array = _queue.pop_front() if urgent else _prefetch.pop_front()

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
			_done_mutex.lock()
			_done.append([flora_item[0], flora_item[1], chunk_bytes, "flora"])
			_done_mutex.unlock()
			continue

		if item.is_empty():
			continue

		var key: Vector4i = item[1]
		var bytes: PackedByteArray = store.block_bytes(Vector3i(key.x, key.y, key.z), key.w)
		_done_mutex.lock()
		_done.append([item[0], key, bytes])
		_done_mutex.unlock()


func _exit_tree() -> void:
	_queue_mutex.lock()
	_stopping = true
	_queue_mutex.unlock()

	for thread in _workers:
		_work.post()

	for thread in _workers:
		thread.wait_to_finish()

	if store != null:
		store.flush()
