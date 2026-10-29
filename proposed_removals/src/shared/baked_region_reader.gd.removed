class_name BakedRegionReader
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


# ==================================================
# BLOCK STORAGE TYPES
# ==================================================

const BLOCK_STORED := 0
const BLOCK_IMPLICIT_AIR := 1
const BLOCK_IMPLICIT_DEEP_GRANITE := 2
const BLOCK_INVALID := 3
const BLOCK_IMPLICIT_UNKNOWN := 4

# Sentinel returned when this file does not contain enough
# information to determine an air boundary for a column.
const AIR_START_UNKNOWN := -2147483648


var _file: FileAccess = null

var _path: String = ""
var _region_coord: Vector2i = Vector2i.ZERO
var _generator_version: int = 0
var _world_identity_seed: int = 0

var _index: Dictionary = {}

var _is_open: bool = false


# Built lazily. RegionCatalog only needs file/header/index validation,
# so it should not pay the cost of building this table for every file.
#
# Key:   "lod:block_x:block_z"
# Value: first block Y that is implicit air
var _air_start_by_column: Dictionary = {}
var _classification_ready: bool = false


var _hash_context := HashingContext.new()


func open_region(
	path: String
) -> bool:
	close()

	_file = FileAccess.open(
		path,
		FileAccess.READ
	)

	if _file == null:
		push_error(
			"Failed to open region file: %s"
			% path
		)
		return false

	_file.big_endian = false

	_path = path

	var header: Dictionary = (
		_read_header()
	)

	if not bool(
		header.get(
			"valid",
			false
		)
	):
		close()
		return false

	var index_offset: int = int(
		header["index_offset"]
	)

	var index_count: int = int(
		header["index_count"]
	)

	if not _read_index(
		index_offset,
		index_count
	):
		close()
		return false

	_is_open = true

	return true


func has_block(
	lod_index: int,
	block_position: Vector3i
) -> bool:
	if not _is_open:
		return false

	var key: String = (
		_make_block_key(
			lod_index,
			block_position
		)
	)

	return _index.has(
		key
	)


# ==================================================
# BLOCK CLASSIFICATION
# ==================================================

func get_block_storage_kind(
	lod_index: int,
	block_position: Vector3i
) -> int:
	if not _is_open:
		return BLOCK_INVALID

	if not RegionFormatScript.is_valid_lod(
		lod_index
	):
		return BLOCK_INVALID

	var requested_region: Vector2i = (
		RegionFormatScript.get_region_coord_from_block(
			block_position,
			lod_index
		)
	)

	if requested_region != _region_coord:
		return BLOCK_INVALID

	if has_block(
		lod_index,
		block_position
	):
		return BLOCK_STORED

	var air_start_y: int = (
		get_known_air_start_block_y(
			lod_index,
			block_position.x,
			block_position.z
		)
	)

	# A completely omitted column is intentionally left
	# unresolved here. The higher-level block store can use
	# neighboring columns (including across region edges) to
	# infer whether the omitted block belongs to air or granite.
	if air_start_y == AIR_START_UNKNOWN:
		return BLOCK_IMPLICIT_UNKNOWN

	if block_position.y >= air_start_y:
		return BLOCK_IMPLICIT_AIR

	return BLOCK_IMPLICIT_DEEP_GRANITE


func has_known_air_start(
	lod_index: int,
	block_x: int,
	block_z: int
) -> bool:
	if not _is_open:
		return false

	_ensure_column_classification()

	return _air_start_by_column.has(
		_make_column_key(
			lod_index,
			block_x,
			block_z
		)
	)


func get_known_air_start_block_y(
	lod_index: int,
	block_x: int,
	block_z: int
) -> int:
	if not _is_open:
		return AIR_START_UNKNOWN

	if not RegionFormatScript.is_valid_lod(
		lod_index
	):
		return AIR_START_UNKNOWN

	var requested_region: Vector2i = (
		RegionFormatScript.get_region_coord_from_block(
			Vector3i(
				block_x,
				0,
				block_z
			),
			lod_index
		)
	)

	if requested_region != _region_coord:
		return AIR_START_UNKNOWN

	_ensure_column_classification()

	var column_key: String = (
		_make_column_key(
			lod_index,
			block_x,
			block_z
		)
	)

	if not _air_start_by_column.has(
		column_key
	):
		return AIR_START_UNKNOWN

	return int(
		_air_start_by_column[column_key]
	)


func _ensure_column_classification() -> void:
	if _classification_ready:
		return

	_air_start_by_column.clear()

	# For ordinary columns the highest stored detailed block is
	# immediately below the omitted-air range. This gives an exact
	# air boundary for those columns. Columns with no stored blocks
	# remain unknown and are resolved topologically by their
	# neighbors in LocalBakedBlockStore.
	for entry_variant in _index.values():
		var entry: Dictionary = entry_variant
		var lod_index: int = int(entry["lod"])
		var block_position: Vector3i = entry["block_position"]

		var column_key: String = (
			_make_column_key(
				lod_index,
				block_position.x,
				block_position.z
			)
		)

		var candidate_air_start: int = (
			block_position.y + 1
		)

		if not _air_start_by_column.has(
			column_key
		):
			_air_start_by_column[column_key] = (
				candidate_air_start
			)
			continue

		if candidate_air_start > int(
			_air_start_by_column[column_key]
		):
			_air_start_by_column[column_key] = (
				candidate_air_start
			)

	_classification_ready = true


func read_block(
	lod_index: int,
	block_position: Vector3i
) -> PackedByteArray:
	var empty_payload := PackedByteArray()

	if not _is_open:
		return empty_payload

	if _file == null:
		return empty_payload

	var key: String = (
		_make_block_key(
			lod_index,
			block_position
		)
	)

	if not _index.has(
		key
	):
		return empty_payload

	var entry: Dictionary = (
		_index[key]
	)

	var flags: int = int(
		entry["flags"]
	)

	var payload_offset: int = int(
		entry["payload_offset"]
	)

	var stored_size: int = int(
		entry["stored_size"]
	)

	var uncompressed_size: int = int(
		entry["uncompressed_size"]
	)

	_file.seek(
		payload_offset
	)

	var stored_payload: PackedByteArray = (
		_file.get_buffer(
			stored_size
		)
	)

	if stored_payload.size() != stored_size:
		push_error(
			"Could not read complete region block payload."
		)
		return empty_payload

	# --------------------------------------------------
	# VERIFY THE BYTES ACTUALLY STORED ON DISK
	#
	# This happens before decompression.
	# --------------------------------------------------

	var expected_checksum: int = int(
		entry["checksum32"]
	)

	var actual_checksum: int = (
		_checksum32(
			stored_payload
		)
	)

	if actual_checksum < 0:
		return empty_payload

	if actual_checksum != expected_checksum:
		push_error(
			(
				"Checksum mismatch for LOD%d block %s."
			)
			% [
				lod_index,
				str(
					block_position
				)
			]
		)

		return empty_payload

	var payload := PackedByteArray()

	if (
		flags
		== RegionFormatScript
			.BLOCK_FLAG_COMPRESSED
	):
		payload = (
			stored_payload.decompress(
				uncompressed_size,
				RegionFormatScript
					.BLOCK_COMPRESSION_MODE
			)
		)

		if (
			payload.size()
			!= uncompressed_size
		):
			push_error(
				"Region block decompression failed."
			)

			return empty_payload

	elif (
		flags
		== RegionFormatScript
			.BLOCK_FLAG_NONE
	):
		if stored_size != uncompressed_size:
			push_error(
				(
					"Uncompressed region block has "
					+ "inconsistent payload sizes."
				)
			)

			return empty_payload

		payload = stored_payload

	else:
		push_error(
			"Unsupported region block flags."
		)

		return empty_payload

	return payload


func get_region_coord() -> Vector2i:
	return _region_coord


func get_block_count() -> int:
	return _index.size()


func get_path() -> String:
	return _path


func get_generator_version() -> int:
	return _generator_version


func get_world_identity_seed() -> int:
	return _world_identity_seed


func is_open() -> bool:
	return _is_open


func close() -> void:
	if _file != null:
		_file.close()

	_file = null

	_path = ""
	_region_coord = Vector2i.ZERO
	_generator_version = 0
	_world_identity_seed = 0

	_index.clear()
	_air_start_by_column.clear()

	_classification_ready = false
	_is_open = false


func _read_header() -> Dictionary:
	if _file == null:
		return {
			"valid": false
		}

	var file_length: int = (
		_file.get_length()
	)

	if (
		file_length
		< RegionFormatScript.HEADER_SIZE_BYTES
	):
		push_error(
			"Region file is smaller than its header."
		)

		return {
			"valid": false
		}

	_file.seek(0)

	var magic_bytes: PackedByteArray = (
		_file.get_buffer(8)
	)

	var magic: String = (
		magic_bytes.get_string_from_ascii()
	)

	if magic != RegionFormatScript.MAGIC:
		push_error(
			"Invalid region file magic."
		)

		return {
			"valid": false
		}

	var region_format_version: int = (
		_file.get_32()
	)

	var header_size: int = (
		_file.get_32()
	)

	var region_x: int = (
		_decode_i32(
			_file.get_32()
		)
	)

	var region_z: int = (
		_decode_i32(
			_file.get_32()
		)
	)

	var region_size: int = (
		_file.get_32()
	)

	var block_size: int = (
		_file.get_32()
	)

	var lod_count: int = (
		_file.get_32()
	)

	var voxel_format_version: int = (
		_file.get_32()
	)

	var index_offset: int = (
		_file.get_64()
	)

	var index_count: int = (
		_file.get_32()
	)

	var file_flags: int = (
		_file.get_32()
	)

	var generator_version: int = _file.get_32()
	var world_identity_seed: int = _decode_i32(_file.get_32())

	if (
		region_format_version
		!= RegionFormatScript.FORMAT_VERSION
	):
		push_error(
			"Unsupported region format version."
		)

		return {
			"valid": false
		}

	if generator_version <= 0:
		push_error("Invalid world generator version.")
		return {"valid": false}

	if (
		header_size
		!= RegionFormatScript.HEADER_SIZE_BYTES
	):
		push_error(
			"Invalid region header size."
		)

		return {
			"valid": false
		}

	if (
		region_size
		!= RegionFormatScript
			.REGION_SIZE_LOD0_VOXELS
	):
		push_error(
			"Unexpected region size."
		)

		return {
			"valid": false
		}

	if (
		block_size
		!= BakedWorldConfigScript.DATA_BLOCK_SIZE
	):
		push_error(
			"Unexpected voxel block size."
		)

		return {
			"valid": false
		}

	if (
		lod_count
		!= BakedWorldConfigScript.LOD_COUNT
	):
		push_error(
			"Unexpected LOD count."
		)

		return {
			"valid": false
		}

	if (
		voxel_format_version
		!= BakedVoxelLayoutScript.FORMAT_VERSION
	):
		push_error(
			"Unexpected baked voxel format version."
		)

		return {
			"valid": false
		}

	if (
		file_flags
		!= RegionFormatScript.FILE_FLAG_NONE
	):
		push_error(
			"Unsupported region file flags."
		)

		return {
			"valid": false
		}

	if (
		index_offset
		< RegionFormatScript.HEADER_SIZE_BYTES
	):
		push_error(
			"Invalid region index offset."
		)

		return {
			"valid": false
		}

	var index_size: int = (
		index_count
		* RegionFormatScript
			.INDEX_ENTRY_SIZE_BYTES
	)

	if (
		index_offset + index_size
		> file_length
	):
		push_error(
			"Region index extends beyond file length."
		)

		return {
			"valid": false
		}

	_region_coord = Vector2i(
		region_x,
		region_z
	)
	_generator_version = generator_version
	_world_identity_seed = world_identity_seed

	return {
		"valid": true,
		"index_offset": index_offset,
		"index_count": index_count
	}


func _read_index(
	index_offset: int,
	index_count: int
) -> bool:
	if _file == null:
		return false

	_index.clear()

	_file.seek(
		index_offset
	)

	for _entry_index in range(
		index_count
	):
		var lod_index: int = (
			_file.get_8()
		)

		var local_x: int = (
			_file.get_8()
		)

		var local_z: int = (
			_file.get_8()
		)

		var flags: int = (
			_file.get_8()
		)

		var global_y: int = (
			_decode_i32(
				_file.get_32()
			)
		)

		var payload_offset: int = (
			_file.get_64()
		)

		var stored_size: int = (
			_file.get_32()
		)

		var uncompressed_size: int = (
			_file.get_32()
		)

		var checksum32: int = (
			_file.get_32()
		)

		_file.get_32()

		if not RegionFormatScript.is_valid_lod(
			lod_index
		):
			push_error(
				"Region index contains invalid LOD."
			)

			return false

		var blocks_per_axis: int = (
			RegionFormatScript
			.get_blocks_per_region_axis(
				lod_index
			)
		)

		if (
			local_x >= blocks_per_axis
			or local_z >= blocks_per_axis
		):
			push_error(
				"Region index contains invalid local block coordinates."
			)

			return false

		if (
			flags
			!= RegionFormatScript.BLOCK_FLAG_NONE
			and flags
			!= RegionFormatScript
				.BLOCK_FLAG_COMPRESSED
		):
			push_error(
				"Region index contains unsupported block flags."
			)

			return false

		if stored_size <= 0:
			push_error(
				"Region index contains invalid stored payload size."
			)

			return false

		if uncompressed_size <= 0:
			push_error(
				"Region index contains invalid uncompressed payload size."
			)

			return false

		if (
			payload_offset
			< RegionFormatScript.HEADER_SIZE_BYTES
			or payload_offset + stored_size
			> index_offset
		):
			push_error(
				"Region payload lies outside the payload area."
			)

			return false

		var global_x: int = (
			_region_coord.x
			* blocks_per_axis
			+ local_x
		)

		var global_z: int = (
			_region_coord.y
			* blocks_per_axis
			+ local_z
		)

		var block_position := Vector3i(
			global_x,
			global_y,
			global_z
		)

		var key: String = (
			_make_block_key(
				lod_index,
				block_position
			)
		)

		if _index.has(
			key
		):
			push_error(
				"Duplicate block in region index."
			)

			return false

		_index[key] = {
			"lod": lod_index,
			"block_position": block_position,
			"flags": flags,
			"payload_offset": payload_offset,
			"stored_size": stored_size,
			"uncompressed_size": uncompressed_size,
			"checksum32": checksum32
		}

	return true


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


static func _make_block_key(
	lod_index: int,
	block_position: Vector3i
) -> String:
	return (
		"%d:%d:%d:%d"
		% [
			lod_index,
			block_position.x,
			block_position.y,
			block_position.z
		]
	)


static func _make_column_key(
	lod_index: int,
	block_x: int,
	block_z: int
) -> String:
	return (
		"%d:%d:%d"
		% [
			lod_index,
			block_x,
			block_z
		]
	)


static func _decode_i32(
	value: int
) -> int:
	if value >= 0x80000000:
		return (
			value
			- 0x100000000
		)

	return value
