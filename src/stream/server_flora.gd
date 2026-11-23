extends RefCounted

# The server's flora (plan step 15): chunks worked out by the flora placer,
# minus the items players removed, packed for clients.
#
# Removals are the only flora state stored (design Section 4.3): "item N in
# chunk C is gone", kept in the server store folder, one file per chunk in `flora_removed/` (REMOVED_DIR).
# Regrowth comes later.
#
# Packed chunks are kept in memory (up to MEMORY_CHUNKS, oldest dropped
# first) so a chunk asked for by several players is worked out once. A chunk
# comes in two forms: full, or trees only for chunks seen from afar.
#
# Thread safe: chunk_bytes may run on many worker threads at once.

const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const LayoutScript := preload("res://src/worldgen/runtime/flora_layout.gd")
const LAYOUT_KEY := "layout"        # a removals file: the flora layout version the marks were made under (flora_layout.gd)
const REMOVED_DIR := "flora_removed"    # one file per chunk with removals, <cx>_<cz>.json: {"layout", "ids"} (audit 18 Nov 2026 finding 6)
const LEGACY_FILE := "flora_removed.json"   # the one file of every chunk before 18 Nov 2026: read once, written out per chunk, kept as .migrated
const MEMORY_CHUNKS := 2048
const ITEMS_CHUNKS := 400             # chunks of placed items kept by items_of, the least recently asked dropped first: every player warms the 9 round them
                                      # (terrain_server _warm_flora), so 160 thrashed at 32 players spread out and a blow on a tree placed its chunk again on
                                      # the main thread, 0.5 to 2 s each (server load test 23 Nov 2026)
const TREES_CHUNKS := 512             # trees-only placed lists kept (_placed; about 30 KB each)
const COVER_CHUNKS := 1500            # chunks kept in the cover index (oldest dropped first)
const SLOW_LOCK_MS := 20.0            # a chunk holding the flora lock longer prints a "server flora:" line (the main thread's shelter checks wait for it)
const BRUSH_CELL_M := 2.0             # in_undergrowth: a shrub or tall plant marks the 2 m cell it stands in
const BRUSH_MIN_M := 0.5              # only shrubs and plants this tall or taller rustle (ferns, tall grass, bushes; not moss or berries)
const BRUSH_CHUNKS := 64              # chunks kept in the undergrowth index (oldest dropped first; a dropped one is made again on a worker)

var placer
var dynamic: Callable                       # (home chunk) -> flora-style items of saplings and grown trees, {} when none (server_items.gd)
var chunks_made: int = 0
var layout_cleared: bool = false            # true when setup dropped saved removals because the flora layout changed
var memory_hits: int = 0

var _dir: String = ""                 # the removals folder (REMOVED_DIR in the store)
var _legacy: String = ""              # LEGACY_FILE in the store, while it waits to be written out per chunk
var _removed: Dictionary = {}          # Vector2i chunk -> {item id: true}
var _memory: Dictionary = {}           # Vector3i (chunk x, z, 1 full / 0 trees only) -> PackedByteArray
var _water: Dictionary = {}            # Vector2i chunk -> PackedByteArray (cleared when the water moves)
var _mutex: Mutex = Mutex.new()
var _items: Dictionary = {}            # Vector3i (chunk x, z, 1 full / 0 trees only) -> chunk_items result, shared read-only
var _items_mutex: Mutex = Mutex.new()
var _trees_kept: Dictionary = {}       # Vector3i (chunk x, z, 0) -> chunk_items(trees only) result, shared read-only (_placed; under _items_mutex)
var _placing: Dictionary = {}          # Vector3i keys being placed now (_placed; under _items_mutex)
var _ground_age: int = 0               # bumped by clear_memory: a placement begun on the old ground is not kept (under _items_mutex)
var _dirty_chunks: Dictionary = {}    # Vector2i chunk -> true: its removals file is out of date (written, or deleted when it has none)
var _removed_saved_msec: int = 0
var cover = CoverScript.Index.new()    # tree crowns of the chunks made so far (Cover.at; read it under cover_lock)
var _cover_order: Array = []           # chunks in the index, oldest first
var _brush: Dictionary = {}            # home chunk -> {Vector2i 2 m cell: true}: where the undergrowth is (in_undergrowth; under _mutex)
var _brush_pending: Dictionary = {}    # home chunks whose index a worker is making (_make_brush)


# The chunk's placed items (FloraPlacer.chunk_items), kept for a while: placing a chunk takes seconds the first time and the
# server asks about the same nine chunks at every dig, chop and gather. Callers only read the result. Safe from any thread. Trees only
# gives the full list when that is kept (callers then skip what is not a tree).
func items_of(chunk: Vector2i, trees_only: bool = false) -> Dictionary:
	var home: Vector2i = placer.normalize(chunk)

	if trees_only:
		_items_mutex.lock()
		var full: Dictionary = _items.get(Vector3i(home.x, home.y, 1), {})
		_items_mutex.unlock()

		if not full.is_empty():
			return full

	return _placed(home, trees_only)


# The placer's own list for a chunk in exactly the asked form (no removals, no saplings), for items_of, chunk_bytes and the undergrowth index:
# kept, so a planted bush, a new sapling or a felled tree re-packs the chunk without placing it again (Dave 15 Nov 2026: that re-placing paused
# the server's main thread for seconds). Full lists in _items; trees-only lists in their own store (a trees-only list is not the trees of the
# full one: spring cover shrubs make room before trees in the full list), so far chunks streamed past do not push near ones out.
# One placement per chunk and form at a time: a second asker waits for the first instead of placing it again (a join at the spawn placed
# 11 to 13 of its 36 chunk lists twice side by side, Dave's PC and David4, 15 Nov 2026; flora_pool_profile.gd).
# shortcut: a kept list does not follow later live water (sim_snapshot) until new tiles clear it, as items_of already did; a chunk dropped
# from a store is placed again on its next change, as before. Revisit if either shows in play.
func _placed(home: Vector2i, trees_only: bool) -> Dictionary:
	var key: Vector3i = Vector3i(home.x, home.y, 0 if trees_only else 1)
	var age: int = 0

	while true:
		_items_mutex.lock()
		var store: Dictionary = _trees_kept if trees_only else _items
		var kept: Dictionary = store.get(key, {})
		var start: bool = kept.is_empty() and not _placing.has(key)

		if not kept.is_empty():
			store.erase(key)
			store[key] = kept   # asked again: last in the drop order (least recently used first)

		if start:
			_placing[key] = true
			age = _ground_age

		_items_mutex.unlock()

		if not kept.is_empty():
			return kept

		if start:
			break

		OS.delay_msec(5)

	# Taken untyped: a script error inside the placer returns null, and the key must still be freed or every later asker would wait forever.
	var got = placer.chunk_items(home, trees_only)
	var made: Dictionary = got if got is Dictionary else {}
	_items_mutex.lock()

	if made.is_empty() or age != _ground_age:
		pass   # a failed placement is not kept (the next asker tries again); nor one begun before clear_memory (it stands on the old ground)
	elif trees_only:
		while _trees_kept.size() >= TREES_CHUNKS:
			_trees_kept.erase(_trees_kept.keys()[0])

		_trees_kept[key] = made
	else:
		while _items.size() >= ITEMS_CHUNKS:
			_items.erase(_items.keys()[0])

		_items[key] = made

	if age == _ground_age:
		_placing.erase(key)   # else clear_memory already freed it, and an asker on the new ground may hold it now

	_items_mutex.unlock()
	return made


# The placed items of a chunk only when items_of has already made them (for this or the full list), else {}: for a look that must never make a chunk on the
# main thread (the hint triggers, 4 times a second: making the nine chunks round a new player took 3 to 11 s there; Steve, 4 Nov 2026).
func items_cached(chunk: Vector2i) -> Dictionary:
	var home: Vector2i = placer.normalize(chunk)
	_items_mutex.lock()
	var kept: Dictionary = _items.get(Vector3i(home.x, home.y, 1), {})

	if kept.is_empty():
		kept = _trees_kept.get(Vector3i(home.x, home.y, 0), {})

	_items_mutex.unlock()
	return kept


# Whether a chunk's items are in memory, an empty chunk (open sea, bare rock) too: items_cached gives {} for both an empty chunk and one not
# made yet, so a look that must know the difference (the Map's landmarks, terrain_server _map_landmarks) asks here.
func chunk_cached(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_items_mutex.lock()
	var cached: bool = _items.has(Vector3i(home.x, home.y, 1)) or _trees_kept.has(Vector3i(home.x, home.y, 0))
	_items_mutex.unlock()
	return cached


# Whether the chunk's full list is kept or being placed now: asking for the full form then costs no placement of its own (_placed waits).
func full_known(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	var key: Vector3i = Vector3i(home.x, home.y, 1)
	_items_mutex.lock()
	var known: bool = _items.has(key) or _placing.has(key)
	_items_mutex.unlock()
	return known


func has_items(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_items_mutex.lock()
	var has: bool = _items.has(Vector3i(home.x, home.y, 1))
	_items_mutex.unlock()
	return has


func setup(flora_placer, store_dir: String) -> void:
	placer = flora_placer
	_dir = store_dir + "/" + REMOVED_DIR
	var legacy: String = store_dir + "/" + LEGACY_FILE

	# A one-file save (an older server, or a store seeded that way) is the newest record when it is there: it is read, and the chunk files are
	# made from it at the first save (a chunk file it does not name is removed then).
	# An unreadable one-file save is left where it is and the chunk files are read instead, so a broken file never wipes good ones.
	if FileAccess.file_exists(legacy):
		var whole: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy))

		if typeof(whole) == TYPE_DICTIONARY:
			_legacy = legacy

			for file in _chunk_files():
				_dirty_chunks[file[0]] = true

			if not _read_removals(whole, true):
				print("server flora: layout %d is not %d, saved removals cleared (%s)" % [int(whole.get(LAYOUT_KEY, 1)), LayoutScript.VERSION, legacy])

			return

		push_error("server flora: %s is not valid JSON; it is left in place and the chunk files are read" % legacy)

	var stale: int = 0

	for file in _chunk_files():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir + "/" + str(file[1])))

		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("ids"):
			if not _read_removals({LAYOUT_KEY: parsed.get(LAYOUT_KEY, 1), "%d,%d" % [file[0].x, file[0].y]: parsed["ids"]}, false):
				stale += 1
		else:
			push_error("server flora: %s/%s is not a removals file" % [_dir, str(file[1])])

	if stale > 0:
		print("server flora: %d chunk removal files were made under another flora layout (now %d), cleared" % [stale, LayoutScript.VERSION])


# [[chunk, file name], ...] of the removals folder.
func _chunk_files() -> Array:
	var out: Array = []

	if not DirAccess.dir_exists_absolute(_dir):
		return out

	for file in DirAccess.get_files_at(_dir):
		var parts: PackedStringArray = file.trim_suffix(".json").split("_")

		if file.ends_with(".json") and parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			out.append([Vector2i(int(parts[0]), int(parts[1])), file])

	return out


# Reads {"layout": V, "cx,cz": [ids], ...}. Removals made under another layout point at plants that no longer stand there: they are dropped
# (a file without a stamp is version 1), and their files go at the next save. False when the layout did not match.
func _read_removals(parsed: Dictionary, whole: bool) -> bool:
	var keys: Array = []

	for key in parsed:
		if str(key) != LAYOUT_KEY:
			var parts: PackedStringArray = str(key).split(",")
			keys.append(Vector2i(int(parts[0]), int(parts[1])))

	if int(parsed.get(LAYOUT_KEY, 1)) != LayoutScript.VERSION:
		layout_cleared = true

		for chunk in keys:
			_dirty_chunks[chunk] = true

		return false

	for chunk in keys:
		var ids: Dictionary = {}

		for id in parsed["%d,%d" % [chunk.x, chunk.y]]:
			ids[int(id)] = true

		_removed[chunk] = ids

		if whole:
			_dirty_chunks[chunk] = true

	return true


# A chunk's flora for clients, with removals applied, packed relative to
# the chunk as asked for (so a client across the wrap seam gets positions
# in its own coordinates). `full` false: trees only.
func chunk_bytes(chunk: Vector2i, full: bool = true) -> PackedByteArray:
	var home: Vector2i = placer.normalize(chunk)
	var key: Vector3i = Vector3i(home.x, home.y, 1 if full else 0)
	_mutex.lock()
	var bytes: PackedByteArray = _memory.get(key, PackedByteArray())

	if not bytes.is_empty():
		memory_hits += 1

	var removed: Dictionary = _removed.get(home, {}).duplicate()
	_mutex.unlock()

	if not bytes.is_empty():
		return bytes

	var items: Dictionary = PlacerScript.without(_placed(home, not full), removed)

	if dynamic.is_valid():
		var extra: Dictionary = dynamic.call(home)

		if not extra.is_empty():
			items = items.duplicate()

			for field in items:
				items[field] = items[field].duplicate()
				items[field].append_array(extra[field])
	bytes = PlacerScript.encode(items, placer.chunk_origin(home))
	var brush: Dictionary = _brush_cells(items) if full else {}
	var crowns: Dictionary = CoverScript.Index.pack(home, CoverScript.tree_rows(items, _cover_info))   # before the lock: the main thread's shelter checks wait for it
	var wait_start: int = Time.get_ticks_usec()
	_mutex.lock()
	var held_start: int = Time.get_ticks_usec()

	# BUG-024 (Dave's QA list, 4 Nov 2026: felled trees came back after streaming): this runs on worker threads, and a tree cut while
	# the chunk was being made would be kept in the memory copy and sent to every later asker. Removals only grow, so a changed count
	# means a cut came in: make it again with it.
	if _removed.get(home, {}).size() != removed.size():
		_mutex.unlock()
		return chunk_bytes(chunk, full)

	_fill_cover(home, crowns)

	if full:
		_keep_brush(home, brush)

	chunks_made += 1
	_memory[key] = bytes

	while _memory.size() > MEMORY_CHUNKS:
		_memory.erase(_memory.keys()[0])

	_mutex.unlock()
	var held_ms: float = float(Time.get_ticks_usec() - held_start) / 1000.0

	if held_ms > SLOW_LOCK_MS:   # names a chunk that kept the shelter checks waiting
		print("server flora: chunk %s held the flora lock %.0f ms (%d crowns; waited %.0f ms for it)" % [str(home), held_ms, int(crowns["trees"]), float(held_start - wait_start) / 1000.0])

	return bytes


# Whether a chunk's flora is already made (so a question about its cover does not have to place it).
func chunk_made(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_lock_noting("chunk_made")
	var yes: bool = _memory.has(Vector3i(home.x, home.y, 1)) or _memory.has(Vector3i(home.x, home.y, 0))
	_mutex.unlock()
	return yes


# A species' row for the cover index (Cover.tree_rows): [kind, crown m, reference height m, deciduous]; empty for an unknown species.
func _cover_info(species_id: int) -> Array:
	var item: Dictionary = placer.species_by_id(species_id)
	return [] if item.is_empty() else [int(item["kind"]), float(item["crown"]), float(item["height_ref"]), CoverScript.is_deciduous(str(item.get("name", "")))]


# Puts a chunk's tree crowns (Cover.tree_rows and Index.pack, worked out before the lock) in the cover index (called with the mutex held).
func _fill_cover(home: Vector2i, crowns: Dictionary) -> void:
	cover.set_packed(home, crowns)
	_cover_order.erase(home)
	_cover_order.append(home)

	while _cover_order.size() > COVER_CHUNKS:
		cover.remove_chunk(_cover_order.pop_front())


var season_at: Callable   # (position) -> the season there (Weather.season_at); unset: the broadleaves stay in leaf
var _bare_bands: Dictionary = {}   # 1 km band of z -> [msec read, bare]: the spot's season read once a band every 5 s (under _mutex)
const BARE_BAND_M := 1000.0
const BARE_KEEP_MSEC := 5000


# Whether a spot is under a tree's canopy (Cover.at on the server's index). With season_at the broadleaves are bare by the spot's own season
# (half a year on across the equator; docs/design/cover_by_season_design.md). Cost: the season is read once a 1 km band every 5 s, so an
# animal's sight line (up to 12 calls) costs no more than before.
func covered(pos: Vector3) -> bool:
	_lock_noting("covered")

	if season_at.is_valid():
		var band: int = floori(pos.z / BARE_BAND_M)   # shortcut: a season changes only at the equator's row edge, a band edge while equator_tile_row is 0
		var kept: Array = _bare_bands.get(band, [-BARE_KEEP_MSEC - 1, false])
		var now: int = Time.get_ticks_msec()

		if now - int(kept[0]) > BARE_KEEP_MSEC:
			kept = [now, CoverScript.leafless_for(str(season_at.call(pos)))]
			_bare_bands[band] = kept

		cover.leafless = bool(kept[1])

	var yes: bool = CoverScript.at(pos, cover) > 0.0
	_mutex.unlock()
	return yes


# _mutex.lock() for the checks the server's main thread makes every tick (shelter, undergrowth): a main-thread wait over SLOW_LOCK_MS is
# added up and printed at most once a second as a "server flora:" line (lag while running, 21 Nov 2026).
var _main_wait_usec: int = 0
var _main_waits: int = 0
var _main_wait_note_msec: int = 0
var _log_tasks: Array = []          # worker tasks printing log lines (_log_off_main), main thread only
var _brush_tasks = preload("res://src/shared/pool_tasks.gd").new()   # _make_brush tasks, waited for by finish_tasks() at exit


# Waits for this store's worker tasks (undergrowth chunks, log lines); later ones start nothing. The server's _exit_tree, before the engine
# shuts its worker pool down.
func finish_tasks() -> void:
	_brush_tasks.finish()

	for task in _log_tasks:
		WorkerThreadPool.wait_for_task_completion(task)

	_log_tasks = []


func _lock_noting(what: String) -> void:
	var wait_start: int = Time.get_ticks_usec()
	_mutex.lock()
	var waited: int = Time.get_ticks_usec() - wait_start

	if waited <= int(SLOW_LOCK_MS * 1000.0) or OS.get_thread_caller_id() != OS.get_main_thread_id():
		return

	_main_wait_usec += waited
	_main_waits += 1
	var now: int = Time.get_ticks_msec()

	if now - _main_wait_note_msec >= 1000:
		_log_off_main("server flora: the main thread waited %.0f ms for the flora lock in %d checks (last in %s)" % [float(_main_wait_usec) / 1000.0, _main_waits, what])
		_main_wait_note_msec = now
		_main_wait_usec = 0
		_main_waits = 0


# Prints a line on a worker: a print on the server's main thread can itself stall it (server_items #397).
func _log_off_main(line: String) -> void:
	var still: Array = []

	for task in _log_tasks:
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
		else:
			still.append(task)

	still.append(WorkerThreadPool.add_task(func() -> void: print(line), true, "flora log line"))
	_log_tasks = still


# True when a point stands in undergrowth: a shrub or a plant of BRUSH_MIN_M or more (fern, tall grass, bramble, hazel) in the same
# 2 m cell. Walking through it is noisy, so animals hear the player from farther off (server_animals senses.undergrowth_noise; Dave
# 5 Nov 2026: bushes and ferns never stop the player, they make you louder instead). Safe on the main thread: a chunk's index is
# made with its full flora (chunk_bytes, on a worker); one not known yet is started on a worker and reads false until it is done.
func in_undergrowth(pos: Vector3) -> bool:
	var x: float = placer.generator.wrap_x(pos.x)
	var z: float = placer.generator.wrap_x(pos.z)
	var home: Vector2i = placer.normalize(placer.chunk_of(x, z))
	_lock_noting("in_undergrowth")
	var cells: Variant = _brush.get(home)

	if cells == null and not _brush_pending.has(home):
		_brush_pending[home] = true
		if not _brush_tasks.add(_make_brush.bind(home), "undergrowth chunk"):
			_brush_pending.erase(home)   # shutting down (finish_tasks)

	_mutex.unlock()
	return cells != null and (cells as Dictionary).has(Vector2i(int(floor(x / BRUSH_CELL_M)), int(floor(z / BRUSH_CELL_M))))


# The 2 m cells of a chunk's items that hold a shrub or plant of BRUSH_MIN_M or more (removals already taken out).
func _brush_cells(items: Dictionary) -> Dictionary:
	var made: Dictionary = {}
	var ids: PackedInt32Array = items["ids"]
	var positions: PackedVector3Array = items["positions"]
	var heights: PackedFloat32Array = items["heights"]

	for n in range(mini(ids.size(), mini(positions.size(), heights.size()))):
		if heights[n] >= BRUSH_MIN_M and int(placer.species_of(ids[n]).get("kind", PlacerScript.KIND_TREE)) != PlacerScript.KIND_TREE:
			made[Vector2i(int(floor(positions[n].x / BRUSH_CELL_M)), int(floor(positions[n].z / BRUSH_CELL_M)))] = true

	return made


# Keeps a chunk's undergrowth index (called with the mutex held).
func _keep_brush(home: Vector2i, made: Dictionary) -> void:
	_brush.erase(home)

	while _brush.size() >= BRUSH_CHUNKS:
		_brush.erase(_brush.keys()[0])

	_brush[home] = made


# Worker task: places a chunk whose undergrowth index was asked for before its flora was made (or after it was dropped).
func _make_brush(home: Vector2i) -> void:
	_mutex.lock()
	var removed: Dictionary = _removed.get(home, {}).duplicate()
	_mutex.unlock()
	var made: Dictionary = _brush_cells(PlacerScript.without(_placed(home, false), removed))
	_mutex.lock()
	_keep_brush(home, made)
	_brush_pending.erase(home)
	_mutex.unlock()


func roofed(pos: Vector3) -> bool:
	_lock_noting("roofed")
	var yes: bool = cover.roofed(pos)
	_mutex.unlock()
	return yes


# Roofs (lean-tos) live in the same cover index as the tree crowns.
func add_roof(roof: Array) -> int:
	_lock_noting("add_roof")
	var key: int = cover.add_roof(roof)
	_mutex.unlock()
	return key


func remove_roof(key: int) -> void:
	_lock_noting("remove_roof")
	cover.remove_roof(key)
	_mutex.unlock()


# Forgets one chunk's packed flora (its saplings or trees changed); it is made again when asked for.
func invalidate(chunk: Vector2i) -> void:
	var home: Vector2i = placer.normalize(chunk)
	_lock_noting("invalidate")
	_memory.erase(Vector3i(home.x, home.y, 1))
	_memory.erase(Vector3i(home.x, home.y, 0))
	_mutex.unlock()


# The admin world reset (server_items.reset_world): every felled tree and removed plant stands again, saved at once. The clients reload their
# plants with the ground reset that follows.
func restore_all() -> void:
	_lock_noting("restore_all")

	for chunk in _removed:
		_dirty_chunks[chunk] = true

	for file in _chunk_files():
		_dirty_chunks[file[0]] = true

	_removed.clear()
	_brush.clear()
	_memory.clear()
	_mutex.unlock()
	save_removed(true)


# Forgets every made chunk (the tile files changed).
func clear_memory() -> void:
	_lock_noting("clear_memory")
	_memory.clear()
	_water.clear()
	_mutex.unlock()
	_items_mutex.lock()
	_items.clear()   # the placed lists stand on the old ground too
	_trees_kept.clear()
	_placing.clear()   # askers waiting on a placement begun on the old ground place afresh; that placement is not kept (_ground_age)
	_ground_age += 1
	_items_mutex.unlock()


# Forgets the packed water (the simulated water changed, and where is not known).
func clear_water() -> void:
	_lock_noting("clear_water")
	_water.clear()
	_mutex.unlock()


# Forgets the packed water of the chunks touching any of `areas` (Rect2, world x, z), grown by a chunk as the clients' re-ask is: the rest still
# holds the right water (finding 12, docs/ai-team/audits/2026-11-18_oversized_reactions_audit.md). The chunks are named by the wrapped home
# chunk the packed water is kept under, so an area past the world's edge clears the same chunks.
func clear_water_in(areas: Array) -> void:
	var m: float = placer.chunk_m
	var homes: Dictionary = {}

	for r in areas:
		var g: Rect2 = (r as Rect2).grow(m)

		for cx in range(floori(g.position.x / m), floori(g.end.x / m) + 1):
			for cz in range(floori(g.position.y / m), floori(g.end.y / m) + 1):
				homes[placer.normalize(Vector2i(cx, cz))] = true

	_lock_noting("clear_water_in")

	for home in homes:
		_water.erase(home)

	_mutex.unlock()


# Writes the removals files of the chunks cut in since the last write, at most once a second; `force` at exit. Only those chunks are written,
# so felling or clearing costs the chunks it touches, not every removal since the world began (audit 18 Nov 2026 finding 6: the one file was
# rewritten in full, pretty-printed, every second while anything was cut).
func save_removed(force: bool = false) -> void:
	var now: int = Time.get_ticks_msec()
	_lock_noting("save_removed")

	if (_dirty_chunks.is_empty() and _legacy == "") or (not force and now - _removed_saved_msec < 1000):
		_mutex.unlock()
		return

	_removed_saved_msec = now
	var writes: Dictionary = {}

	for chunk in _dirty_chunks:
		writes[chunk] = _removed[chunk].keys() if _removed.has(chunk) and not (_removed[chunk] as Dictionary).is_empty() else []

	_dirty_chunks = {}
	var legacy: String = _legacy
	_legacy = ""
	_mutex.unlock()
	DirAccess.make_dir_recursive_absolute(_dir)
	var failed: Array = []

	for chunk in writes:
		var path: String = "%s/%d_%d.json" % [_dir, chunk.x, chunk.y]

		if (writes[chunk] as Array).is_empty():
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)

			continue

		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

		if file == null:
			failed.append(chunk)
			continue

		file.store_string(JSON.stringify({LAYOUT_KEY: LayoutScript.VERSION, "ids": writes[chunk]}))
		file.close()

	if not failed.is_empty():
		# Tried again at the next save; the one-file save is kept until every chunk it held is written.
		push_error("server flora: %d chunk removal files could not be written in %s" % [failed.size(), _dir])
		_lock_noting("save_removed")

		for chunk in failed:
			_dirty_chunks[chunk] = true

		if legacy != "":
			_legacy = legacy

		_mutex.unlock()
	elif legacy != "":
		if FileAccess.file_exists(legacy + ".migrated"):
			DirAccess.remove_absolute(legacy + ".migrated")   # an earlier migration's copy (rename does not overwrite on Windows)

		DirAccess.rename_absolute(legacy, legacy + ".migrated")   # kept, not deleted: the chunk files now hold what it held


# True when the chunk's packed water is ready (water_bytes then costs nothing).
func water_ready(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_lock_noting("water_ready")
	var known: bool = _water.has(home)
	_mutex.unlock()
	return known


# A chunk's rivers and lakes for clients (empty when it has none).
func water_bytes(chunk: Vector2i) -> PackedByteArray:
	var home: Vector2i = placer.normalize(chunk)
	_lock_noting("water_bytes")
	var known: bool = _water.has(home)
	var bytes: PackedByteArray = _water.get(home, PackedByteArray())
	_mutex.unlock()

	if known:
		return bytes

	bytes = WaterGridScript.encode(WaterGridScript.chunk_levels(placer.generator, placer.chunk_origin(home), placer.chunk_m))
	_lock_noting("water_bytes")
	_water[home] = bytes

	while _water.size() > MEMORY_CHUNKS:
		_water.erase(_water.keys()[0])

	_mutex.unlock()
	return bytes


# Removes one item. False when the chunk has no such item (or it is gone).
func cut(chunk: Vector2i, id: int) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_lock_noting("cut")
	var already: bool = _removed.get(home, {}).has(id)
	_mutex.unlock()

	if already or items_of(home)["ids"].find(id) < 0:
		return false

	_lock_noting("cut")

	if not _removed.has(home):
		_removed[home] = {}

	_removed[home][id] = true
	cover.remove_item(home, id)
	_brush.erase(home)
	_memory.erase(Vector3i(home.x, home.y, 1))
	_memory.erase(Vector3i(home.x, home.y, 0))
	_dirty_chunks[home] = true
	_mutex.unlock()
	return true


func removed_in(chunk: Vector2i) -> Array:
	_lock_noting("removed_in")
	var ids: Array = _removed.get(placer.normalize(chunk), {}).keys()
	_mutex.unlock()
	return ids
