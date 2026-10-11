class_name RegionCatalog
extends RefCounted


const RegionFormatScript = preload(
	"res://src/shared/baked_region_format.gd"
)

const BakedWorldConfigScript = preload(
	"res://src/shared/baked_world_config.gd"
)

const BakedVoxelLayoutScript = preload(
	"res://src/shared/baked_voxel_layout.gd"
)


var _directory_path: String = ""

var _regions: Dictionary = {}

var _minimum_region := Vector2i.ZERO
var _maximum_region := Vector2i.ZERO

var _is_ready: bool = false
var _generator_version: int = 0
var _world_identity_seed: int = 0


# ==================================================
# SCAN
# ==================================================

func scan(
	directory_path: String
) -> bool:
	reset()

	_directory_path = directory_path

	var directory := DirAccess.open(
		directory_path
	)

	if directory == null:
		push_error(
			"Could not open region directory: %s"
			% directory_path
		)

		return false


	var found_any: bool = false
	var scan_failed: bool = false

	var expected_prefix: String = (
		RegionFormatScript.FILE_NAME_PREFIX
		+ "_"
	)

	var expected_suffix: String = (
		"."
		+ RegionFormatScript.FILE_EXTENSION
	)


	directory.list_dir_begin()

	while true:
		var file_name: String = (
			directory.get_next()
		)

		if file_name.is_empty():
			break


		if directory.current_is_dir():
			continue


		if not file_name.begins_with(
			expected_prefix
		):
			continue


		if not file_name.ends_with(
			expected_suffix
		):
			continue


		# --------------------------------------------------
		# FAST CATALOG SCAN
		#
		# Do NOT open BakedRegionReader here.
		#
		# Opening a full reader builds the complete block
		# index. Doing that for all region files before the
		# first frame caused the long blank startup delay.
		#
		# The catalog only inventories finalized region files.
		# The authoritative BakedRegionReader still validates
		# each file when that source region is actually used.
		# --------------------------------------------------

		var stem_length: int = (
			file_name.length()
			- expected_prefix.length()
			- expected_suffix.length()
		)

		if stem_length <= 0:
			continue


		var coordinate_text: String = (
			file_name.substr(
				expected_prefix.length(),
				stem_length
			)
		)


		var parts: PackedStringArray = (
			coordinate_text.split(
				"_",
				false
			)
		)


		if parts.size() != 2:
			continue


		if not parts[0].is_valid_int():
			continue


		if not parts[1].is_valid_int():
			continue


		var region_coord := Vector2i(
			parts[0].to_int(),
			parts[1].to_int()
		)


		# Require the exact canonical filename.
		if (
			file_name
			!= RegionFormatScript.get_region_filename(
				region_coord
			)
		):
			continue


		var file_path: String = (
			directory_path.path_join(
				file_name
			)
		)


		var file_size: int = (
			FileAccess.get_size(
				file_path
			)
		)


		if (
			file_size
			< RegionFormatScript.HEADER_SIZE_BYTES
		):
			push_warning(
				"Skipping region file smaller than header: %s"
				% file_path
			)

			continue

		var header: Dictionary = _read_region_header(
			file_path,
			region_coord,
			file_size
		)

		if header.is_empty():
			scan_failed = true
			continue

		var file_generator_version: int = int(
			header["generator_version"]
		)
		var file_world_identity_seed: int = int(
			header["world_identity_seed"]
		)

		if not found_any:
			_generator_version = file_generator_version
			_world_identity_seed = file_world_identity_seed
		elif (
			file_generator_version != _generator_version
			or file_world_identity_seed != _world_identity_seed
		):
			push_error(
				"Region directory mixes incompatible generator versions or seeds: %s"
				% file_path
			)
			scan_failed = true
			continue


		if _regions.has(
			region_coord
		):
			push_warning(
				"Duplicate baked region coordinate: %s"
				% str(region_coord)
			)

			continue


		var modified_time: int = (
			FileAccess.get_modified_time(
				file_path
			)
		)


		var revision: String = (
			"%d:%d"
			% [
				modified_time,
				file_size
			]
		)


		_regions[
			region_coord
		] = {
			"region_coord": region_coord,
			"path": file_path,
			"revision": revision,
			"modified_time": modified_time,
			"file_size": file_size
		}


		if not found_any:
			_minimum_region = region_coord
			_maximum_region = region_coord

			found_any = true

		else:
			_minimum_region.x = mini(
				_minimum_region.x,
				region_coord.x
			)

			_minimum_region.y = mini(
				_minimum_region.y,
				region_coord.y
			)

			_maximum_region.x = maxi(
				_maximum_region.x,
				region_coord.x
			)

			_maximum_region.y = maxi(
				_maximum_region.y,
				region_coord.y
			)


	directory.list_dir_end()

	if scan_failed:
		push_error(
			"Region catalog rejected one or more invalid or incompatible files."
		)
		reset()
		return false


	if not found_any:
		push_error(
			"No baked region files found in: %s"
			% directory_path
		)

		return false


	_is_ready = true


	print(
		"RegionCatalog: discovered ",
		_regions.size(),
		" source regions using fast inventory scan. Raw bounds ",
		_minimum_region,
		" -> ",
		_maximum_region
	)


	return true


# ==================================================
# ACCESS
# ==================================================

func has_region(
	region_coord: Vector2i
) -> bool:
	return _regions.has(
		region_coord
	)


func get_region_info(
	region_coord: Vector2i
) -> Dictionary:
	if not _regions.has(
		region_coord
	):
		return {}


	return (
		_regions[
			region_coord
		].duplicate(true)
	)


func get_region_path(
	region_coord: Vector2i
) -> String:
	if not _regions.has(
		region_coord
	):
		return ""


	return str(
		_regions[
			region_coord
		]["path"]
	)


func get_region_revision(
	region_coord: Vector2i
) -> String:
	if not _regions.has(
		region_coord
	):
		return ""


	return str(
		_regions[
			region_coord
		]["revision"]
	)


func get_region_coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []


	for key in _regions.keys():
		result.append(
			key as Vector2i
		)


	return result


func get_region_count() -> int:
	return _regions.size()


func get_minimum_region() -> Vector2i:
	return _minimum_region


func get_maximum_region() -> Vector2i:
	return _maximum_region


func get_directory_path() -> String:
	return _directory_path


func get_generator_version() -> int:
	return _generator_version


func get_world_identity_seed() -> int:
	return _world_identity_seed


func is_ready() -> bool:
	return _is_ready


# ==================================================
# RESET
# ==================================================

func reset() -> void:
	_regions.clear()

	_directory_path = ""

	_minimum_region = Vector2i.ZERO
	_maximum_region = Vector2i.ZERO

	_is_ready = false
	_generator_version = 0
	_world_identity_seed = 0


func _read_region_header(
	file_path: String,
	expected_region: Vector2i,
	file_size: int
) -> Dictionary:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)

	if file == null:
		push_error("Could not read region header: %s" % file_path)
		return {}

	file.big_endian = false
	var magic: String = file.get_buffer(8).get_string_from_ascii()
	var format_version: int = file.get_32()
	var header_size: int = file.get_32()
	var region_x: int = _decode_i32(file.get_32())
	var region_z: int = _decode_i32(file.get_32())
	var region_size: int = file.get_32()
	var block_size: int = file.get_32()
	var lod_count: int = file.get_32()
	var voxel_format_version: int = file.get_32()
	var index_offset: int = file.get_64()
	var index_count: int = file.get_32()
	var file_flags: int = file.get_32()
	var generator_version: int = file.get_32()
	var world_identity_seed: int = _decode_i32(file.get_32())
	file.close()

	var index_size: int = (
		index_count * RegionFormatScript.INDEX_ENTRY_SIZE_BYTES
	)

	var valid: bool = (
		magic == RegionFormatScript.MAGIC
		and format_version == RegionFormatScript.FORMAT_VERSION
		and header_size == RegionFormatScript.HEADER_SIZE_BYTES
		and region_x == expected_region.x
		and region_z == expected_region.y
		and region_size == RegionFormatScript.REGION_SIZE_LOD0_VOXELS
		and block_size == BakedWorldConfigScript.DATA_BLOCK_SIZE
		and lod_count == BakedWorldConfigScript.LOD_COUNT
		and voxel_format_version == BakedVoxelLayoutScript.FORMAT_VERSION
		and file_flags == RegionFormatScript.FILE_FLAG_NONE
		and generator_version > 0
		and index_offset >= RegionFormatScript.HEADER_SIZE_BYTES
		and index_offset + index_size == file_size
	)

	if not valid:
		push_error("Invalid or unfinished region file: %s" % file_path)
		return {}

	return {
		"generator_version": generator_version,
		"world_identity_seed": world_identity_seed
	}


static func _decode_i32(value: int) -> int:
	if value >= 0x80000000:
		return value - 0x100000000

	return value
