class_name BakedRegionWriter
extends RefCounted


const RegionFormatScript := preload(
	"res://src/shared/baked_region_format.gd"
)

const BakedWorldConfigScript := preload(
	"res://src/shared/baked_world_config.gd"
)

const BakedVoxelLayoutScript := preload(
	"res://src/shared/baked_voxel_layout.gd"
)

const BlockCodecScript := preload(
	"res://src/shared/baked_block_codec.gd"
)


const INDEX_COPY_CHUNK_BYTES := 1048576

# Large buffered writes instead of thousands of tiny
# FileAccess calls.
const WRITE_BUFFER_BYTES := 1048576

# Tiny compact blocks should never be sent through ZSTD.
const MIN_COMPRESS_PAYLOAD_BYTES := 256


var _file: FileAccess = null
var _index_file: FileAccess = null

var _path: String = ""
var _working_path: String = ""
var _index_temp_path: String = ""

var _region_coord: Vector2i = Vector2i.ZERO

var _index_count: int = 0

var _is_open: bool = false
var _generator_version: int = 0
var _world_identity_seed: int = 0


var _hash_context := HashingContext.new()


# ==================================================
# BUFFERED OUTPUT
# ==================================================

var _payload_buffer := PackedByteArray()
var _index_buffer := PackedByteArray()

var _next_payload_offset: int = 0


# Compact granite has only one possible payload per LOD.
# Cache its MD5-derived checksum instead of recalculating
# it millions of times.
var _compact_checksum_cache: Dictionary = {}


func create_new(
	path: String,
	region_coord: Vector2i,
	world_definition = null
) -> bool:
	close()

	var base_directory: String = (
		path.get_base_dir()
	)

	if not base_directory.is_empty():
		var absolute_directory: String = (
			ProjectSettings.globalize_path(
				base_directory
			)
		)

		var directory_error: Error = (
			DirAccess.make_dir_recursive_absolute(
				absolute_directory
			)
		)

		if (
			directory_error != OK
			and directory_error != ERR_ALREADY_EXISTS
		):
			push_error(
				"Failed to create region directory: %s"
				% base_directory
			)

			return false

	_path = path
	_working_path = path + ".partial"

	_index_temp_path = (
		_working_path + ".index.tmp"
	)

	_remove_index_temp_file()
	_remove_stale_working_file()

	if world_definition != null:
		_generator_version = int(world_definition.generator_version)
		_world_identity_seed = int(
			world_definition.get_world_identity_seed()
		)

	_file = FileAccess.open(
		_working_path,
		FileAccess.WRITE
	)

	if _file == null:
		push_error(
			"Failed to create region file: %s"
			% _working_path
		)

		_reset_state()

		return false

	_file.big_endian = false

	_index_file = FileAccess.open(
		_index_temp_path,
		FileAccess.WRITE
	)

	if _index_file == null:
		push_error(
			"Failed to create temporary region index."
		)

		_file.close()
		_file = null

		_reset_state()

		return false

	_index_file.big_endian = false

	_region_coord = region_coord

	_index_count = 0
	_is_open = true

	_payload_buffer.clear()
	_index_buffer.clear()

	_compact_checksum_cache.clear()

	_write_header(
		0,
		0
	)

	_file.seek(
		RegionFormatScript.HEADER_SIZE_BYTES
	)

	_next_payload_offset = (
		RegionFormatScript.HEADER_SIZE_BYTES
	)

	return true


func add_block(
	lod_index: int,
	block_position: Vector3i,
	payload: PackedByteArray
) -> bool:
	if not _is_open:
		push_error(
			"Region writer is not open."
		)

		return false

	if (
		_file == null
		or _index_file == null
	):
		return false

	if not RegionFormatScript.is_valid_lod(
		lod_index
	):
		push_error(
			"Invalid LOD index: %d"
			% lod_index
		)

		return false

	if payload.is_empty():
		push_error(
			"Cannot store an empty block payload."
		)

		return false


	# ==================================================
	# VALIDATE REGION WITHOUT EXTRA OBJECT WORK
	# ==================================================

	var blocks_per_axis: int = (
		RegionFormatScript
		.get_blocks_per_region_axis(
			lod_index
		)
	)

	var local_x: int = (
		block_position.x
		- _region_coord.x
		* blocks_per_axis
	)

	var local_z: int = (
		block_position.z
		- _region_coord.y
		* blocks_per_axis
	)

	if (
		local_x < 0
		or local_x >= blocks_per_axis
		or local_z < 0
		or local_z >= blocks_per_axis
	):
		push_error(
			(
				"Block %s at LOD%d does not belong "
				+ "to region %s."
			)
			% [
				str(
					block_position
				),
				lod_index,
				str(
					_region_coord
				)
			]
		)

		return false


	# ==================================================
	# COMPRESSION
	#
	# Never invoke ZSTD for tiny compact block markers.
	# ==================================================

	var stored_payload: PackedByteArray = (
		payload
	)

	var block_flags: int = (
		RegionFormatScript.BLOCK_FLAG_NONE
	)

	if (
		payload.size()
		>= MIN_COMPRESS_PAYLOAD_BYTES
	):
		var compressed_payload: PackedByteArray = (
			payload.compress(
				RegionFormatScript
					.BLOCK_COMPRESSION_MODE
			)
		)

		if (
			not compressed_payload.is_empty()
			and compressed_payload.size()
				< payload.size()
		):
			stored_payload = (
				compressed_payload
			)

			block_flags = (
				RegionFormatScript
					.BLOCK_FLAG_COMPRESSED
			)


	# ==================================================
	# CHECKSUM
	# ==================================================

	var checksum: int = (
		_get_payload_checksum(
			stored_payload,
			payload,
			block_flags,
			lod_index
		)
	)

	if checksum < 0:
		return false


	# ==================================================
	# PAYLOAD OFFSET
	#
	# Use a logical offset because bytes may still be
	# sitting in our memory buffer.
	# ==================================================

	var payload_offset: int = (
		_next_payload_offset
	)

	_next_payload_offset += (
		stored_payload.size()
	)


	# ==================================================
	# BUFFER PAYLOAD
	# ==================================================

	_payload_buffer.append_array(
		stored_payload
	)

	if (
		_payload_buffer.size()
		>= WRITE_BUFFER_BYTES
	):
		if not _flush_payload_buffer():
			return false


	# ==================================================
	# BUFFER INDEX ENTRY
	# ==================================================

	_append_index_entry(
		lod_index,
		local_x,
		local_z,
		block_position.y,
		block_flags,
		payload_offset,
		stored_payload.size(),
		payload.size(),
		checksum
	)

	if (
		_index_buffer.size()
		>= WRITE_BUFFER_BYTES
	):
		if not _flush_index_buffer():
			return false

	_index_count += 1

	return true


# ==================================================
# INDEX ENTRY
# ==================================================

func _append_index_entry(
	lod_index: int,
	local_x: int,
	local_z: int,
	block_y: int,
	block_flags: int,
	payload_offset: int,
	stored_size: int,
	uncompressed_size: int,
	checksum: int
) -> void:
	var entry := PackedByteArray()

	entry.resize(
		RegionFormatScript
			.INDEX_ENTRY_SIZE_BYTES
	)

	entry[0] = lod_index
	entry[1] = local_x
	entry[2] = local_z
	entry[3] = block_flags

	entry.encode_u32(
		4,
		_encode_i32(
			block_y
		)
	)

	entry.encode_u64(
		8,
		payload_offset
	)

	entry.encode_u32(
		16,
		stored_size
	)

	entry.encode_u32(
		20,
		uncompressed_size
	)

	entry.encode_u32(
		24,
		checksum
	)

	entry.encode_u32(
		28,
		0
	)

	_index_buffer.append_array(
		entry
	)


# ==================================================
# BUFFER FLUSHING
# ==================================================

func _flush_payload_buffer() -> bool:
	if _payload_buffer.is_empty():
		return true

	if _file == null:
		return false

	_file.store_buffer(
		_payload_buffer
	)

	if _file.get_error() != OK:
		push_error(
			"Failed writing buffered region payload."
		)

		return false

	_payload_buffer.clear()

	return true


func _flush_index_buffer() -> bool:
	if _index_buffer.is_empty():
		return true

	if _index_file == null:
		return false

	_index_file.store_buffer(
		_index_buffer
	)

	if _index_file.get_error() != OK:
		push_error(
			"Failed writing buffered region index."
		)

		return false

	_index_buffer.clear()

	return true


# ==================================================
# CHECKSUM
# ==================================================

func _get_payload_checksum(
	stored_payload: PackedByteArray,
	original_payload: PackedByteArray,
	block_flags: int,
	lod_index: int
) -> int:
	if (
		block_flags
		== RegionFormatScript.BLOCK_FLAG_NONE
		and BlockCodecScript
			.is_compact_uniform_deep_granite(
				original_payload
			)
	):
		if _compact_checksum_cache.has(
			lod_index
		):
			return int(
				_compact_checksum_cache[
					lod_index
				]
			)

		var compact_checksum: int = (
			_checksum32(
				stored_payload
			)
		)

		if compact_checksum >= 0:
			_compact_checksum_cache[
				lod_index
			] = compact_checksum

		return compact_checksum

	return _checksum32(
		stored_payload
	)


func _checksum32(
	data: PackedByteArray
) -> int:
	var start_error: Error = (
		_hash_context.start(
			HashingContext.HASH_MD5
		)
	)

	if start_error != OK:
		push_error(
			"Could not start block checksum."
		)

		return -1

	var update_error: Error = (
		_hash_context.update(
			data
		)
	)

	if update_error != OK:
		_hash_context.finish()

		push_error(
			"Could not update block checksum."
		)

		return -1

	var digest: PackedByteArray = (
		_hash_context.finish()
	)

	if digest.size() < 4:
		push_error(
			"Block checksum digest is invalid."
		)

		return -1

	return digest.decode_u32(0)


# ==================================================
# FINALIZE REGION
# ==================================================

func finalize() -> bool:
	if not _is_open:
		push_error(
			"Region writer is not open."
		)

		return false

	if (
		_file == null
		or _index_file == null
	):
		return false


	# Flush all buffered block data first.
	if not _flush_payload_buffer():
		return false

	if not _flush_index_buffer():
		return false


	# Verify payload stream reached the logical offset.
	if (
		_file.get_position()
		!= _next_payload_offset
	):
		push_error(
			(
				"Region payload position mismatch. "
				+ "Expected %d, found %d."
			)
			% [
				_next_payload_offset,
				_file.get_position()
			]
		)

		return false


	_index_file.flush()

	var index_length: int = (
		_index_file.get_length()
	)

	var expected_index_length: int = (
		_index_count
		* RegionFormatScript
			.INDEX_ENTRY_SIZE_BYTES
	)

	if index_length != expected_index_length:
		push_error(
			(
				"Temporary region index has unexpected size. "
				+ "Expected %d bytes, found %d bytes."
			)
			% [
				expected_index_length,
				index_length
			]
		)

		return false


	# --------------------------------------------------
	# CLOSE WRITE-ONLY INDEX
	# --------------------------------------------------

	_index_file.close()
	_index_file = null


	# --------------------------------------------------
	# REOPEN INDEX FOR READING
	# --------------------------------------------------

	_index_file = FileAccess.open(
		_index_temp_path,
		FileAccess.READ
	)

	if _index_file == null:
		push_error(
			(
				"Could not reopen temporary region index "
				+ "for reading: %s"
			)
			% _index_temp_path
		)

		return false

	_index_file.big_endian = false

	var reopened_length: int = (
		_index_file.get_length()
	)

	if reopened_length != index_length:
		push_error(
			(
				"Temporary region index length changed "
				+ "after reopening. Expected %d bytes, "
				+ "found %d bytes."
			)
			% [
				index_length,
				reopened_length
			]
		)

		return false


	# --------------------------------------------------
	# APPEND INDEX TO REGION FILE
	# --------------------------------------------------

	var index_offset: int = (
		_file.get_position()
	)

	_index_file.seek(0)

	var bytes_remaining: int = (
		index_length
	)

	while bytes_remaining > 0:
		var chunk_size: int = mini(
			bytes_remaining,
			INDEX_COPY_CHUNK_BYTES
		)

		var chunk: PackedByteArray = (
			_index_file.get_buffer(
				chunk_size
			)
		)

		if chunk.size() != chunk_size:
			push_error(
				(
					"Failed while copying temporary "
					+ "region index. Requested %d bytes, "
					+ "received %d bytes."
				)
				% [
					chunk_size,
					chunk.size()
				]
			)

			return false

		_file.store_buffer(
			chunk
		)

		bytes_remaining -= (
			chunk_size
		)


	# --------------------------------------------------
	# FINAL HEADER
	# --------------------------------------------------

	_file.seek(0)

	_write_header(
		index_offset,
		_index_count
	)

	_file.flush()

	_file.close()
	_index_file.close()

	_file = null
	_index_file = null

	_remove_index_temp_file()

	if not _promote_working_file():
		return false

	_is_open = false

	return true


func get_region_coord() -> Vector2i:
	return _region_coord


func get_block_count() -> int:
	return _index_count


func get_path() -> String:
	return _path


# ==================================================
# CLOSE / ABORT
# ==================================================

func close() -> void:
	if _file != null:
		_flush_payload_buffer()

	if _index_file != null:
		_flush_index_buffer()

	if _file != null:
		_file.close()

	if _index_file != null:
		_index_file.close()

	_file = null
	_index_file = null

	_reset_state()


# ==================================================
# HEADER
# ==================================================

func _write_header(
	index_offset: int,
	index_count: int
) -> void:
	if _file == null:
		return

	var magic_bytes: PackedByteArray = (
		RegionFormatScript.MAGIC
			.to_ascii_buffer()
	)

	_file.store_buffer(
		magic_bytes
	)

	_file.store_32(
		RegionFormatScript.FORMAT_VERSION
	)

	_file.store_32(
		RegionFormatScript.HEADER_SIZE_BYTES
	)

	_file.store_32(
		_encode_i32(
			_region_coord.x
		)
	)

	_file.store_32(
		_encode_i32(
			_region_coord.y
		)
	)

	_file.store_32(
		RegionFormatScript
			.REGION_SIZE_LOD0_VOXELS
	)

	_file.store_32(
		BakedWorldConfigScript
			.DATA_BLOCK_SIZE
	)

	_file.store_32(
		BakedWorldConfigScript
			.LOD_COUNT
	)

	_file.store_32(
		BakedVoxelLayoutScript
			.FORMAT_VERSION
	)

	_file.store_64(
		index_offset
	)

	_file.store_32(
		index_count
	)

	_file.store_32(
		RegionFormatScript.FILE_FLAG_NONE
	)

	_file.store_32(_generator_version)
	_file.store_32(
		_encode_i32(_world_identity_seed)
	)


# ==================================================
# TEMP INDEX CLEANUP
# ==================================================

func _remove_index_temp_file() -> void:
	if _index_temp_path.is_empty():
		return

	if not FileAccess.file_exists(_index_temp_path):
		return

	var absolute_path: String = (
		ProjectSettings.globalize_path(_index_temp_path)
	)

	var remove_error: Error = (
		DirAccess.remove_absolute(absolute_path)
	)

	if remove_error != OK:
		push_warning(
			"Could not remove temporary region index: %s"
			% _index_temp_path
		)


func _remove_stale_working_file() -> void:
	if _working_path.is_empty():
		return

	if not FileAccess.file_exists(_working_path):
		return

	var remove_error: Error = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(_working_path)
	)

	if remove_error != OK:
		push_warning(
			"Could not replace stale partial region: %s" % _working_path
		)


func _promote_working_file() -> bool:
	var absolute_working: String = ProjectSettings.globalize_path(
		_working_path
	)
	var absolute_final: String = ProjectSettings.globalize_path(_path)

	if FileAccess.file_exists(_path):
		var remove_error: Error = DirAccess.remove_absolute(absolute_final)
		if remove_error != OK:
			push_error("Could not replace finalized region: %s" % _path)
			return false

	var rename_error: Error = DirAccess.rename_absolute(
		absolute_working,
		absolute_final
	)

	if rename_error != OK:
		push_error(
			"Could not finalize partial region %s. Error: %d"
			% [_working_path, int(rename_error)]
		)
		return false

	return true


func _reset_state() -> void:
	_file = null
	_index_file = null

	_path = ""
	_working_path = ""
	_index_temp_path = ""

	_region_coord = Vector2i.ZERO

	_index_count = 0
	_is_open = false
	_generator_version = 0
	_world_identity_seed = 0

	_payload_buffer.clear()
	_index_buffer.clear()

	_next_payload_offset = 0

	_compact_checksum_cache.clear()


static func _encode_i32(
	value: int
) -> int:
	if value < 0:
		return (
			value
			+ 0x100000000
		)

	return value
