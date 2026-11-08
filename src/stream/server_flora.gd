extends RefCounted

# The server's flora (plan step 15): chunks worked out by the flora placer,
# minus the items players removed, packed for clients.
#
# Removals are the only flora state stored (design Section 4.3): "item N in
# chunk C is gone", kept in `flora_removed.json` in the server store folder.
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
const LAYOUT_KEY := "layout"        # flora_removed.json: the flora layout version the marks were made under (flora_layout.gd)
const MEMORY_CHUNKS := 2048
const ITEMS_CHUNKS := 160             # chunks of placed items kept by items_of
const COVER_CHUNKS := 1500            # chunks kept in the cover index (oldest dropped first)
const BRUSH_CELL_M := 2.0             # in_undergrowth: a shrub or tall plant marks the 2 m cell it stands in
const BRUSH_MIN_M := 0.5              # only shrubs and plants this tall or taller rustle (ferns, tall grass, bushes; not moss or berries)
const BRUSH_CHUNKS := 64              # chunks kept in the undergrowth index (oldest dropped first; a dropped one is made again on a worker)

var placer
var dynamic: Callable                       # (home chunk) -> flora-style items of saplings and grown trees, {} when none (server_items.gd)
var chunks_made: int = 0
var layout_cleared: bool = false            # true when setup dropped saved removals because the flora layout changed
var memory_hits: int = 0

var _path: String = ""
var _removed: Dictionary = {}          # Vector2i chunk -> {item id: true}
var _memory: Dictionary = {}           # Vector3i (chunk x, z, 1 full / 0 trees only) -> PackedByteArray
var _water: Dictionary = {}            # Vector2i chunk -> PackedByteArray (cleared when the water moves)
var _mutex: Mutex = Mutex.new()
var _items: Dictionary = {}            # Vector3i (chunk x, z, 1 full / 0 trees only) -> chunk_items result, shared read-only
var _items_mutex: Mutex = Mutex.new()
var _removed_dirty: bool = false       # removals not yet written to flora_removed.json
var _removed_saved_msec: int = 0
var cover = CoverScript.Index.new()    # tree crowns of the chunks made so far (Cover.at; read it under cover_lock)
var _cover_order: Array = []           # chunks in the index, oldest first
var _brush: Dictionary = {}            # home chunk -> {Vector2i 2 m cell: true}: where the undergrowth is (in_undergrowth; under _mutex)
var _brush_pending: Dictionary = {}    # home chunks whose index a worker is making (_make_brush)


# The chunk's placed items (FloraPlacer.chunk_items), kept for a while: placing a chunk takes seconds the first time and the
# server asks about the same nine chunks at every dig, chop and gather. Callers only read the result. Safe from any thread (the
# placer only reads); two threads missing at once both place it and the last result is kept.
func items_of(chunk: Vector2i, trees_only: bool = false) -> Dictionary:
	var home: Vector2i = placer.normalize(chunk)
	var full_key: Vector3i = Vector3i(home.x, home.y, 1)
	var key: Vector3i = Vector3i(home.x, home.y, 0 if trees_only else 1)
	_items_mutex.lock()
	var kept: Dictionary = _items.get(full_key, {}) if trees_only else {}

	if kept.is_empty():
		kept = _items.get(key, {})

	_items_mutex.unlock()

	if not kept.is_empty():
		return kept

	var made: Dictionary = placer.chunk_items(home, trees_only)
	_items_mutex.lock()

	while _items.size() >= ITEMS_CHUNKS:
		_items.erase(_items.keys()[0])

	_items[key] = made
	_items_mutex.unlock()
	return made


# The placed items of a chunk only when items_of has already made them (for this or the full list), else {}: for a look that must never make a chunk on the
# main thread (the hint triggers, 4 times a second: making the nine chunks round a new player took 3 to 11 s there; Steve, 4 Nov 2026).
func items_cached(chunk: Vector2i) -> Dictionary:
	var home: Vector2i = placer.normalize(chunk)
	_items_mutex.lock()
	var kept: Dictionary = _items.get(Vector3i(home.x, home.y, 1), {})

	if kept.is_empty():
		kept = _items.get(Vector3i(home.x, home.y, 0), {})

	_items_mutex.unlock()
	return kept


func has_items(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_items_mutex.lock()
	var has: bool = _items.has(Vector3i(home.x, home.y, 1))
	_items_mutex.unlock()
	return has


func setup(flora_placer, store_dir: String) -> void:
	placer = flora_placer
	_path = store_dir + "/flora_removed.json"

	if not FileAccess.file_exists(_path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("server flora: %s is not valid JSON" % _path)
		return

	# Removals made under another layout point at plants that no longer stand there: start clean (a file without a stamp is version 1).
	if int(parsed.get(LAYOUT_KEY, 1)) != LayoutScript.VERSION:
		layout_cleared = true
		_removed_dirty = true
		print("server flora: layout %d is not %d, saved removals cleared" % [int(parsed.get(LAYOUT_KEY, 1)), LayoutScript.VERSION])
		return

	for key in parsed:
		if str(key) == LAYOUT_KEY:
			continue

		var parts: PackedStringArray = str(key).split(",")
		var ids: Dictionary = {}

		for id in parsed[key]:
			ids[int(id)] = true

		_removed[Vector2i(int(parts[0]), int(parts[1]))] = ids


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

	var items: Dictionary = PlacerScript.without(placer.chunk_items(home, not full), removed)

	if dynamic.is_valid():
		var extra: Dictionary = dynamic.call(home)

		if not extra.is_empty():
			items = items.duplicate()

			for field in items:
				items[field] = items[field].duplicate()
				items[field].append_array(extra[field])
	bytes = PlacerScript.encode(items, placer.chunk_origin(home))
	var brush: Dictionary = _brush_cells(items) if full else {}
	_mutex.lock()

	# BUG-024 (Dave's QA list, 4 Nov 2026: felled trees came back after streaming): this runs on worker threads, and a tree cut while
	# the chunk was being made would be kept in the memory copy and sent to every later asker. Removals only grow, so a changed count
	# means a cut came in: make it again with it.
	if _removed.get(home, {}).size() != removed.size():
		_mutex.unlock()
		return chunk_bytes(chunk, full)

	_fill_cover(home, items)

	if full:
		_keep_brush(home, brush)

	chunks_made += 1
	_memory[key] = bytes

	while _memory.size() > MEMORY_CHUNKS:
		_memory.erase(_memory.keys()[0])

	_mutex.unlock()
	return bytes


# Whether a chunk's flora is already made (so a question about its cover does not have to place it).
func chunk_made(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_mutex.lock()
	var yes: bool = _memory.has(Vector3i(home.x, home.y, 1)) or _memory.has(Vector3i(home.x, home.y, 0))
	_mutex.unlock()
	return yes


# Puts a chunk's tree crowns in the cover index (called with the mutex held).
func _fill_cover(home: Vector2i, items: Dictionary) -> void:
	CoverScript.add_chunk(cover, home, items, func(species_id: int) -> Array:
		var item: Dictionary = placer.species_by_id(species_id)
		return [] if item.is_empty() else [int(item["kind"]), float(item["crown"]), float(item["height_ref"]), CoverScript.is_deciduous(str(item.get("name", "")))])
	_cover_order.erase(home)
	_cover_order.append(home)

	while _cover_order.size() > COVER_CHUNKS:
		cover.remove_chunk(_cover_order.pop_front())


# The game season, for bare winter broadleaves (Cover.leafless_for; docs/design/cover_by_season_design.md). Cheap to call every tick.
func set_season(season: String) -> void:
	var bare: bool = CoverScript.leafless_for(season)

	if bare == cover.leafless:
		return

	_mutex.lock()
	cover.leafless = bare
	_mutex.unlock()


# Whether a spot is under a tree's canopy (Cover.at on the server's index).
func covered(pos: Vector3) -> bool:
	_mutex.lock()
	var yes: bool = CoverScript.at(pos, cover) > 0.0
	_mutex.unlock()
	return yes


# True when a point stands in undergrowth: a shrub or a plant of BRUSH_MIN_M or more (fern, tall grass, bramble, hazel) in the same
# 2 m cell. Walking through it is noisy, so animals hear the player from farther off (server_animals senses.undergrowth_noise; Dave
# 5 Nov 2026: bushes and ferns never stop the player, they make you louder instead). Safe on the main thread: a chunk's index is
# made with its full flora (chunk_bytes, on a worker); one not known yet is started on a worker and reads false until it is done.
func in_undergrowth(pos: Vector3) -> bool:
	var x: float = placer.generator.wrap_x(pos.x)
	var z: float = placer.generator.wrap_x(pos.z)
	var home: Vector2i = placer.normalize(placer.chunk_of(x, z))
	_mutex.lock()
	var cells: Variant = _brush.get(home)

	if cells == null and not _brush_pending.has(home):
		_brush_pending[home] = true
		WorkerThreadPool.add_task(_make_brush.bind(home))

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
	var made: Dictionary = _brush_cells(PlacerScript.without(placer.chunk_items(home, false), removed))
	_mutex.lock()
	_keep_brush(home, made)
	_brush_pending.erase(home)
	_mutex.unlock()


func roofed(pos: Vector3) -> bool:
	_mutex.lock()
	var yes: bool = cover.roofed(pos)
	_mutex.unlock()
	return yes


# Roofs (lean-tos) live in the same cover index as the tree crowns.
func add_roof(roof: Array) -> int:
	_mutex.lock()
	var key: int = cover.add_roof(roof)
	_mutex.unlock()
	return key


func remove_roof(key: int) -> void:
	_mutex.lock()
	cover.remove_roof(key)
	_mutex.unlock()


# Forgets one chunk's packed flora (its saplings or trees changed); it is made again when asked for.
func invalidate(chunk: Vector2i) -> void:
	var home: Vector2i = placer.normalize(chunk)
	_mutex.lock()
	_memory.erase(Vector3i(home.x, home.y, 1))
	_memory.erase(Vector3i(home.x, home.y, 0))
	_mutex.unlock()


# Forgets every made chunk (the tile files changed).
func clear_memory() -> void:
	_mutex.lock()
	_memory.clear()
	_water.clear()
	_mutex.unlock()


# Forgets the packed water (the simulated water changed).
func clear_water() -> void:
	_mutex.lock()
	_water.clear()
	_mutex.unlock()


# Writes the removals when some are new, at most once a second (rewriting the whole file per cut stalled the server); `force` at exit.
func save_removed(force: bool = false) -> void:
	var now: int = Time.get_ticks_msec()
	_mutex.lock()

	if not _removed_dirty or (not force and now - _removed_saved_msec < 1000):
		_mutex.unlock()
		return

	_removed_dirty = false
	_removed_saved_msec = now
	var copy: Dictionary = {LAYOUT_KEY: LayoutScript.VERSION}

	for key in _removed:
		copy["%d,%d" % [key.x, key.y]] = _removed[key].keys()

	_mutex.unlock()
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(copy, "\t", true))
		file.close()


# True when the chunk's packed water is ready (water_bytes then costs nothing).
func water_ready(chunk: Vector2i) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_mutex.lock()
	var known: bool = _water.has(home)
	_mutex.unlock()
	return known


# A chunk's rivers and lakes for clients (empty when it has none).
func water_bytes(chunk: Vector2i) -> PackedByteArray:
	var home: Vector2i = placer.normalize(chunk)
	_mutex.lock()
	var known: bool = _water.has(home)
	var bytes: PackedByteArray = _water.get(home, PackedByteArray())
	_mutex.unlock()

	if known:
		return bytes

	bytes = WaterGridScript.encode(WaterGridScript.chunk_levels(placer.generator, placer.chunk_origin(home), placer.chunk_m))
	_mutex.lock()
	_water[home] = bytes

	while _water.size() > MEMORY_CHUNKS:
		_water.erase(_water.keys()[0])

	_mutex.unlock()
	return bytes


# Removes one item. False when the chunk has no such item (or it is gone).
func cut(chunk: Vector2i, id: int) -> bool:
	var home: Vector2i = placer.normalize(chunk)
	_mutex.lock()
	var already: bool = _removed.get(home, {}).has(id)
	_mutex.unlock()

	if already or items_of(home)["ids"].find(id) < 0:
		return false

	_mutex.lock()

	if not _removed.has(home):
		_removed[home] = {}

	_removed[home][id] = true
	cover.remove_item(home, id)
	_brush.erase(home)
	_memory.erase(Vector3i(home.x, home.y, 1))
	_memory.erase(Vector3i(home.x, home.y, 0))
	_removed_dirty = true
	_mutex.unlock()
	return true


func removed_in(chunk: Vector2i) -> Array:
	_mutex.lock()
	var ids: Array = _removed.get(placer.normalize(chunk), {}).keys()
	_mutex.unlock()
	return ids
