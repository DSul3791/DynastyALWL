extends RefCounted

# The server's flora (plan step 15): chunks worked out by the flora placer,
# minus the items players removed, packed for clients.
#
# Removals are the only flora state stored (design Section 4.3): "item N in
# chunk C is gone", kept in `flora_removed.json` in the server store folder.
# Regrowth comes later.
#
# Packed chunks are kept in memory (up to MEMORY_CHUNKS, oldest dropped
# first) so a chunk asked for by several players is worked out once.
#
# Thread safe: chunk_bytes may run on many worker threads at once.

const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const MEMORY_CHUNKS := 2048

var placer
var chunks_made: int = 0
var memory_hits: int = 0

var _path: String = ""
var _removed: Dictionary = {}          # Vector2i chunk -> {item id: true}
var _memory: Dictionary = {}           # Vector2i chunk -> PackedByteArray
var _water: Dictionary = {}            # Vector2i chunk -> PackedByteArray (water never changes)
var _mutex: Mutex = Mutex.new()


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
# in its own coordinates).
func chunk_bytes(chunk: Vector2i) -> PackedByteArray:
	var home: Vector2i = placer.normalize(chunk)
	_mutex.lock()
	var bytes: PackedByteArray = _memory.get(home, PackedByteArray())

	if not bytes.is_empty():
		memory_hits += 1

	var removed: Dictionary = _removed.get(home, {}).duplicate()
	_mutex.unlock()

	if not bytes.is_empty():
		return bytes

	var items: Dictionary = PlacerScript.without(placer.chunk_items(home), removed)
	bytes = PlacerScript.encode(items, placer.chunk_origin(home))
	_mutex.lock()
	chunks_made += 1
	_memory[home] = bytes

	while _memory.size() > MEMORY_CHUNKS:
		_memory.erase(_memory.keys()[0])

	_mutex.unlock()
	return bytes


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
	_memory.erase(home)
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
