extends RefCounted

# Saved ground edits as an operation log (River start thread, tech/SAVED_GROUND_EDITS_DESIGN.md,
# approved by Technical direction 2026-10-21).
#
# Players' digs and fills are kept as operations in global coordinates, not as whole blocks. A
# block is made as: the generated block, then its operations in order. A re-bake throws the
# generated ground away and the operations replay over the new ground, so a hole stays at the same
# world place and the ground around it is the new ground. An operation touches every block it
# overlaps, so tile borders do not matter.
#
# File `digs.dat` in the store folder (the one ground edit log; Ground's DIGS1 is read and upgraded):
# "DIGS2", then fixed 24 byte records appended as they happen: seq u32, kind u8, shape u8,
# material u16, x y z radius float32. A torn last record (server killed mid-write) is ignored.
#
# Thread safe: add() and apply() may be called from different threads.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const MAGIC := "DIGS2"
const MAGIC_V1 := "DIGS1"
const RECORD_BYTES := 24
const BLOCK_SIZE := 16
const KIND_DIG := 0
const KIND_FILL := 1
const SHAPE_SPHERE := 0
const MAX_PER_BLOCK := 200       # Technical direction: replay cap per block; a block this busy takes no more
const MAX_RADIUS_M := 3.0        # Technical direction: widest hole one operation makes

var count: int = 0
var rejected: int = 0            # operations refused for a full block
var coalesced: int = 0           # operations dropped because an earlier one already covered them

var _kinds: PackedByteArray = PackedByteArray()
var _materials: PackedInt32Array = PackedInt32Array()
var _centres: PackedVector3Array = PackedVector3Array()
var _radii: PackedFloat32Array = PackedFloat32Array()
var _by_block: Dictionary = {}   # Vector3i -> PackedInt32Array of operation numbers, oldest first
var _path: String = ""
var _file: FileAccess
var _mutex: Mutex = Mutex.new()


# Opens (or starts) the log and reads it in; a version 1 log (DIGS1, x y z radius per dig, written
# by the first spade digging) is read as digs and rewritten as DIGS2, the old file kept beside it as
# digs.dat.v1. Returns "" or an error.
func open(path: String) -> String:
	_path = path
	var head: int = MAGIC.length()

	if FileAccess.file_exists(path):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)

		if bytes.size() >= head and bytes.slice(0, head).get_string_from_ascii() == MAGIC_V1:
			for n in range((bytes.size() - head) / 16):
				var at: int = head + n * 16
				_append(KIND_DIG, 0, Vector3(bytes.decode_float(at), bytes.decode_float(at + 4), bytes.decode_float(at + 8)), bytes.decode_float(at + 12))

			DirAccess.rename_absolute(path, path + ".v1")
			var error: String = _rewrite()

			if error != "":
				return error
		elif bytes.size() >= head and bytes.slice(0, head).get_string_from_ascii() == MAGIC:
			for n in range((bytes.size() - head) / RECORD_BYTES):
				var at: int = head + n * RECORD_BYTES
				_append(bytes.decode_u8(at + 4), bytes.decode_u16(at + 6), Vector3(bytes.decode_float(at + 8), bytes.decode_float(at + 12), bytes.decode_float(at + 16)), bytes.decode_float(at + 20))

			# Reopen for appending, cutting off a torn last record.
			_file = FileAccess.open(path, FileAccess.READ_WRITE)

			if _file == null:
				return "cannot append to %s" % path

			_file.seek(head + count * RECORD_BYTES)
			return ""
		elif bytes.size() > 0 and bytes.size() < head and MAGIC.to_ascii_buffer().slice(0, bytes.size()) == bytes:
			pass   # killed while the header of a brand-new log was being written: nothing in it, start the log afresh
		elif bytes.size() > 0:
			return "%s is not a ground operations log (DIGS1 or DIGS2)" % path

	return _rewrite()


# Writes the whole log afresh (header and every record) and keeps it open for appending.
func _rewrite() -> String:
	var file: FileAccess = FileAccess.open(_path, FileAccess.WRITE)

	if file == null:
		return "cannot create %s" % _path

	file.store_buffer(MAGIC.to_ascii_buffer())

	for n in range(count):
		_store(file, n)

	file.flush()
	_file = file
	return ""


func _store(file: FileAccess, n: int) -> void:
	file.store_32(n)
	file.store_8(_kinds[n])
	file.store_8(SHAPE_SPHERE)
	file.store_16(_materials[n])
	file.store_float(_centres[n].x)
	file.store_float(_centres[n].y)
	file.store_float(_centres[n].z)
	file.store_float(_radii[n])


# The blocks (LOD 0) a sphere of ground at `centre` reaches.
static func blocks_of(centre: Vector3, radius: float) -> Array:
	var low: Vector3i = Vector3i(((centre - Vector3.ONE * (radius + 2.0)) / float(BLOCK_SIZE)).floor())
	var high: Vector3i = Vector3i(((centre + Vector3.ONE * (radius + 2.0)) / float(BLOCK_SIZE)).floor())
	var blocks: Array = []

	for bz in range(low.z, high.z + 1):
		for by in range(low.y, high.y + 1):
			for bx in range(low.x, high.x + 1):
				var origin: Vector3 = Vector3(Vector3i(bx, by, bz) * BLOCK_SIZE)
				var nearest: Vector3 = Vector3(clampf(centre.x, origin.x, origin.x + BLOCK_SIZE), clampf(centre.y, origin.y, origin.y + BLOCK_SIZE), clampf(centre.z, origin.z, origin.z + BLOCK_SIZE))

				if nearest.distance_to(centre) <= radius + 2.0:
					blocks.append(Vector3i(bx, by, bz))

	return blocks


# Saves one operation. Returns the blocks it changes: [] when it was refused (a block already holds
# MAX_PER_BLOCK) or dropped as already covered by an earlier dig.
func add(kind: int, material: int, centre: Vector3, radius: float) -> Array:
	radius = clampf(radius, 0.5, MAX_RADIUS_M)
	var blocks: Array = blocks_of(centre, radius)
	_mutex.lock()

	for block in blocks:
		if _by_block.has(block) and (_by_block[block] as PackedInt32Array).size() >= MAX_PER_BLOCK:
			rejected += 1
			_mutex.unlock()
			return []

	if kind == KIND_DIG and _covered(blocks, centre, radius):
		coalesced += 1
		_mutex.unlock()
		return []

	_append(kind, material, centre, radius)

	if _file != null:
		_store(_file, count - 1)
		_file.flush()

	_mutex.unlock()
	return blocks


func blocks_with_ops() -> int:
	return _by_block.size()


func has_ops(block: Vector3i) -> bool:
	return _by_block.has(block)


func ops_in(block: Vector3i) -> int:
	_mutex.lock()
	var n: int = (_by_block[block] as PackedInt32Array).size() if _by_block.has(block) else 0
	_mutex.unlock()
	return n


# Every operation, oldest first, as [kind, centre, radius] (the water thread replays them at start).
func edits() -> Array:
	var list: Array = []
	_mutex.lock()

	for n in range(count):
		list.append([int(_kinds[n]), _centres[n], _radii[n]])

	_mutex.unlock()
	return list


# The operations whose sphere comes within `radius` of a point, oldest first, as [kind, centre, radius] (tree support, job 85).
func edits_near(point: Vector3, radius: float) -> Array:
	var list: Array = []
	_mutex.lock()

	for n in range(count):
		if _centres[n].distance_to(point) <= radius + _radii[n]:
			list.append([int(_kinds[n]), _centres[n], _radii[n]])

	_mutex.unlock()
	return list


# Applies the block's operations, oldest first, to `buffer` (the generated block).
func apply(buffer: VoxelBuffer, block: Vector3i) -> void:
	_mutex.lock()

	if not _by_block.has(block):
		_mutex.unlock()
		return

	var list: PackedInt32Array = (_by_block[block] as PackedInt32Array).duplicate()
	var kinds: PackedByteArray = _kinds
	var materials: PackedInt32Array = _materials
	var centres: PackedVector3Array = _centres
	var radii: PackedFloat32Array = _radii
	_mutex.unlock()
	var origin: Vector3 = Vector3(block * BLOCK_SIZE)

	for n in list:
		apply_op(buffer, origin, int(kinds[n]), int(materials[n]), centres[n], radii[n])


# One sphere into a block whose corner is `origin`. A dig empties the sphere (ground distance
# field positive = air), a fill makes it ground of `material` (a soil number).
static func apply_op(buffer: VoxelBuffer, origin: Vector3, kind: int, material: int, centre: Vector3, radius: float) -> void:
	var reach: float = radius + 2.0
	var lo: Vector3i = Vector3i(maxi(0, int(floor(centre.x - reach - origin.x))), maxi(0, int(floor(centre.y - reach - origin.y))), maxi(0, int(floor(centre.z - reach - origin.z))))
	var hi: Vector3i = Vector3i(mini(BLOCK_SIZE - 1, int(ceil(centre.x + reach - origin.x))), mini(BLOCK_SIZE - 1, int(ceil(centre.y + reach - origin.y))), mini(BLOCK_SIZE - 1, int(ceil(centre.z + reach - origin.z))))

	for z in range(lo.z, hi.z + 1):
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var d: float = (origin + Vector3(x, y, z)).distance_to(centre) - radius

				if d > 2.0:
					continue

				var sdf: float = buffer.get_voxel_f(x, y, z, Layout.CHANNEL_SDF)

				if kind == KIND_DIG:
					if -d > sdf:
						buffer.set_voxel_f(-d, x, y, z, Layout.CHANNEL_SDF)

					if d < 0.0:
						buffer.set_voxel(0, x, y, z, Layout.CHANNEL_ROCK)
						buffer.set_voxel(0, x, y, z, Layout.CHANNEL_SOIL)
						buffer.set_voxel(0, x, y, z, Layout.CHANNEL_RESOURCE)
				else:
					if d < sdf:
						buffer.set_voxel_f(d, x, y, z, Layout.CHANNEL_SDF)

					if d < 0.0:
						buffer.set_voxel(0, x, y, z, Layout.CHANNEL_ROCK)
						buffer.set_voxel(material, x, y, z, Layout.CHANNEL_SOIL)
						buffer.set_voxel(0, x, y, z, Layout.CHANNEL_RESOURCE)


func _append(kind: int, material: int, centre: Vector3, radius: float) -> void:
	var n: int = count
	count += 1
	_kinds.append(kind)
	_materials.append(material)
	_centres.append(centre)
	_radii.append(radius)

	for block in blocks_of(centre, radius):
		var list: PackedInt32Array = _by_block.get(block, PackedInt32Array())
		list.append(n)
		_by_block[block] = list


# True when an earlier dig holds this one entirely and no fill has touched the place since.
func _covered(blocks: Array, centre: Vector3, radius: float) -> bool:
	var block: Vector3i = Vector3i((centre / float(BLOCK_SIZE)).floor())

	if not _by_block.has(block):
		return false

	var list: PackedInt32Array = _by_block[block]

	for at in range(list.size() - 1, -1, -1):
		var n: int = list[at]
		var gap: float = centre.distance_to(_centres[n])

		if _kinds[n] == KIND_FILL:
			if gap < radius + _radii[n]:
				return false
		elif gap + radius <= _radii[n]:
			return true

	return false
