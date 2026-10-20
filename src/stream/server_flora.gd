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
const MEMORY_CHUNKS := 2048
const COVER_CHUNKS := 1500            # chunks kept in the cover index (oldest dropped first)

var placer
var dynamic: Callable                       # (home chunk) -> flora-style items of saplings and grown trees, {} when none (server_items.gd)
var chunks_made: int = 0
var memory_hits: int = 0

var _path: String = ""
var _removed: Dictionary = {}          # Vector2i chunk -> {item id: true}
var _memory: Dictionary = {}           # Vector3i (chunk x, z, 1 full / 0 trees only) -> PackedByteArray
var _water: Dictionary = {}            # Vector2i chunk -> PackedByteArray (cleared when the water moves)
var _mutex: Mutex = Mutex.new()
var cover = CoverScript.Index.new()    # tree crowns of the chunks made so far (Cover.at; read it under cover_lock)
var _cover_order: Array = []           # chunks in the index, oldest first


func setup(flora_placer, store_dir: String) -> void:
	placer = flora_placer
	_path = store_dir + "/flora_removed.json"

	if not FileAccess.file_exists(_path):
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("server flora: %s is not valid JSON" % _path)
		return

	for key in parsed:
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
	_mutex.lock()
	_fill_cover(home, items)
	chunks_made += 1
	_memory[key] = bytes

	while _memory.size() > MEMORY_CHUNKS:
		_memory.erase(_memory.keys()[0])

	_mutex.unlock()
	return bytes


# Puts a chunk's tree crowns in the cover index (called with the mutex held).
func _fill_cover(home: Vector2i, items: Dictionary) -> void:
	CoverScript.add_chunk(cover, home, items, func(species_id: int) -> Array:
		var item: Dictionary = placer.species_by_id(species_id)
		return [] if item.is_empty() else [int(item["kind"]), float(item["crown"]), float(item["height_ref"])])
	_cover_order.erase(home)
	_cover_order.append(home)

	while _cover_order.size() > COVER_CHUNKS:
		cover.remove_chunk(_cover_order.pop_front())


# Whether a spot is under a tree's canopy (Cover.at on the server's index).
func covered(pos: Vector3) -> bool:
	_mutex.lock()
	var yes: bool = CoverScript.at(pos, cover) > 0.0
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

	if already or placer.chunk_items(home)["ids"].find(id) < 0:
		return false

	_mutex.lock()

	if not _removed.has(home):
		_removed[home] = {}

	_removed[home][id] = true
	cover.remove_item(home, id)
	_memory.erase(Vector3i(home.x, home.y, 1))
	_memory.erase(Vector3i(home.x, home.y, 0))
	var copy: Dictionary = {}

	for key in _removed:
		copy["%d,%d" % [key.x, key.y]] = _removed[key].keys()

	_mutex.unlock()
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(copy, "\t", true))
		file.close()

	return true


func removed_in(chunk: Vector2i) -> Array:
	_mutex.lock()
	var ids: Array = _removed.get(placer.normalize(chunk), {}).keys()
	_mutex.unlock()
	return ids
