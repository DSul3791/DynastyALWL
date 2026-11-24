extends RefCounted

# The air table of a ground pack (Dave 24 Nov 2026: "so we just have to generate the actual land blocks"): for every block column of a tile
# at every level, the first row from which every block is all air, and the two heights an air block's distance is measured from
# (terrain_generator.gd air_column). The generator (prebuild_ground.gd) writes one file a tile into the pack's air_table/ folder and leaves
# those air blocks out of the pack; the server fills them from the table exactly as the generator would make them, without working
# anything out or saving them (server_block_store.gd _load_base). A file made from other tiles or another terrain version is not used,
# and a block it does not cover is made as before.
#
# File (little-endian): "DAIR", format, the stamp (terrain version and tile fingerprint, as terrain_version.txt), tile x, tile z, level
# count; then per level: level, first block x, first block z, side (blocks a side), side*side first rows (int32), side*side highest
# heights and side*side highest heights with the detail noise (float64, row by row in z, x along each row).

const FOLDER := "air_table"
const MAGIC := "DAIR"
const FORMAT := 1
const NONE := 2147483647                # terrain_generator.gd AIR_NONE: no entry for this column
const MAX_SIDE := 4096                  # blocks a side of one level (a 15,360 m tile has 960 at the finest): more is a damaged file

var tile_size_m: float = 15360.0
var block_size: int = 16
var loaded: int = 0                     # tile files read and used
var refused: int = 0                    # tile files read but not used (other tiles, another version, short)
var _dir: String = ""
var _stamp: String = ""
var _tiles: Dictionary = {}             # Vector2i -> {lod: [bx0, bz0, side, first, plain, detail]}, or {} when the tile has no usable file
var _reading: Dictionary = {}           # Vector2i -> true while one worker reads that tile's file
var _mutex: Mutex = Mutex.new()


# dir: the store or pack folder; stamp: "<terrain version> <tile fingerprint>" the files must carry.
func open(dir: String, stamp: String, tile_m: float, block_voxels: int) -> void:
	_mutex.lock()
	_dir = dir + "/" + FOLDER if dir != "" else ""   # "" reads no table
	_stamp = stamp
	tile_size_m = tile_m
	block_size = block_voxels
	_tiles.clear()
	_mutex.unlock()


# The tile files changed (a bake): forget what was read, and read again under the new stamp.
func set_stamp(stamp: String) -> void:
	_mutex.lock()
	_stamp = stamp
	_tiles.clear()
	_mutex.unlock()


static func file_name(tile: Vector2i) -> String:
	return "tile_%d_%d.air" % [tile.x, tile.y]


# The entry of block column (bx, bz) at this level ([first row, highest height, highest height with detail]), or an empty array.
func entry(bx: int, bz: int, lod: int) -> PackedFloat64Array:
	var block_m: float = float(block_size << lod)
	var tile: Vector2i = Vector2i(int(floor(float(bx) * block_m / tile_size_m)), int(floor(float(bz) * block_m / tile_size_m)))
	_mutex.lock()
	var known: bool = _tiles.has(tile)
	var levels: Dictionary = _tiles.get(tile, {})
	var stamp: String = _stamp
	var reading: bool = _reading.has(tile)

	if not known and not reading:
		_reading[tile] = true

	_mutex.unlock()

	if not known and reading:
		return PackedFloat64Array()   # another worker is reading this tile's file: this block is made as before, this once

	if not known:
		# Read outside the lock (a tile's file is about 25 MB), by one worker; the others go on meanwhile.
		var path: String = _dir + "/" + file_name(tile)
		var present: bool = _dir != "" and FileAccess.file_exists(path)
		levels = read_file(path, stamp, tile) if present else {}
		_mutex.lock()
		_reading.erase(tile)

		if _stamp != stamp:
			_mutex.unlock()
			return PackedFloat64Array()   # the tile files changed while it was read: read again under the new stamp next time

		if not _tiles.has(tile):
			_tiles[tile] = levels
			loaded += 1 if not levels.is_empty() else 0
			refused += 1 if present and levels.is_empty() else 0

			if present and levels.is_empty():
				print("server: air table %s not used (made from other tiles or another terrain version, or cut short); those air blocks are made as before" % path)

		_mutex.unlock()

	var level = levels.get(lod, null)

	if level == null:
		return PackedFloat64Array()

	var x: int = bx - int(level[0])
	var z: int = bz - int(level[1])
	var side: int = level[2]

	if x < 0 or z < 0 or x >= side or z >= side:
		return PackedFloat64Array()

	var index: int = z * side + x
	var first: int = (level[3] as PackedInt32Array)[index]

	if first == NONE:
		return PackedFloat64Array()

	return PackedFloat64Array([first, (level[4] as PackedFloat64Array)[index], (level[5] as PackedFloat64Array)[index]])


# {lod: [bx0, bz0, side, first, plain, detail]} of a file, or {} when it is missing, short or carries another stamp or tile.
static func read_file(path: String, stamp: String, tile: Vector2i) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null or file.get_length() < 16 or file.get_buffer(4).get_string_from_ascii() != MAGIC or file.get_32() != FORMAT:
		return {}

	if file.get_pascal_string() != stamp or _signed(file.get_32()) != tile.x or _signed(file.get_32()) != tile.y:
		return {}

	var levels: Dictionary = {}
	var count: int = file.get_32()

	for n in range(count):
		var lod: int = file.get_32()
		var bx0: int = _signed(file.get_32())
		var bz0: int = _signed(file.get_32())
		var side: int = file.get_32()

		if side <= 0 or side > MAX_SIDE:
			return {}

		var cells: int = side * side
		var first: PackedInt32Array = file.get_buffer(cells * 4).to_int32_array()
		var plain: PackedFloat64Array = file.get_buffer(cells * 8).to_float64_array()
		var detail: PackedFloat64Array = file.get_buffer(cells * 8).to_float64_array()

		if file.get_error() != OK or first.size() != cells or plain.size() != cells or detail.size() != cells:
			return {}

		levels[lod] = [bx0, bz0, side, first, plain, detail]

	return levels if file.get_position() == file.get_length() else {}


static func _signed(value: int) -> int:
	return value - (1 << 32) if value >= (1 << 31) else value


# Writes a tile's file beside and renames it over (a stop never leaves half a file under the real name). levels: as read_file returns.
static func write_file(path: String, stamp: String, tile: Vector2i, levels: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path + ".part", FileAccess.WRITE)

	if file == null:
		return false

	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(FORMAT)
	file.store_pascal_string(stamp)
	file.store_32(tile.x)
	file.store_32(tile.y)
	var lods: Array = levels.keys()
	lods.sort()
	file.store_32(lods.size())

	for lod in lods:
		var level: Array = levels[lod]
		file.store_32(int(lod))
		file.store_32(int(level[0]))
		file.store_32(int(level[1]))
		file.store_32(int(level[2]))
		file.store_buffer((level[3] as PackedInt32Array).to_byte_array())
		file.store_buffer((level[4] as PackedFloat64Array).to_byte_array())
		file.store_buffer((level[5] as PackedFloat64Array).to_byte_array())

	var whole: bool = file.get_error() == OK
	file.close()
	var full: String = ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(full)   # a rename onto a file fails on Windows
	return whole and DirAccess.rename_absolute(full + ".part", full) == OK


# An empty level for a tile: every column without an entry.
static func empty_level(bx0: int, bz0: int, side: int) -> Array:
	var first: PackedInt32Array = PackedInt32Array()
	first.resize(side * side)
	first.fill(NONE)
	var plain: PackedFloat64Array = PackedFloat64Array()
	plain.resize(side * side)
	var detail: PackedFloat64Array = PackedFloat64Array()
	detail.resize(side * side)
	return [bx0, bz0, side, first, plain, detail]
