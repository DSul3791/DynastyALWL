class_name BakedRegionFormat
extends RefCounted


const BakedWorldConfigScript := preload(
	"res://src/shared/baked_world_config.gd"
)


const REGION_SIZE_LOD0_VOXELS := 1024


const FILE_EXTENSION := "dat"
const FILE_NAME_PREFIX := "myworld"

const MAGIC := "BVREGN01"

# Version 3:
#
# Header bytes 56..59 store the world-generator version and bytes
# 60..63 store the canonical world identity seed. A server can now
# reject a directory containing incompatible island bakes.
#
# Version 2:
#
# Index byte 24..27 is now a 32-bit checksum of the
# STORED payload bytes.
#
# The checksum is the first 32 bits of an MD5 digest
# produced by Godot's HashingContext.
#
# This replaces the old GDScript CRC32 loop.
const FORMAT_VERSION := 3

const LITTLE_ENDIAN := true


const HEADER_SIZE_BYTES := 64
const INDEX_ENTRY_SIZE_BYTES := 32


const FILE_FLAG_NONE := 0


const BLOCK_FLAG_NONE := 0
const BLOCK_FLAG_COMPRESSED := 1 << 0


const BLOCK_COMPRESSION_MODE := (
	FileAccess.COMPRESSION_ZSTD
)


static func get_region_coord_from_voxel(
	world_voxel_x: int,
	world_voxel_z: int
) -> Vector2i:
	return Vector2i(
		_floor_div(
			world_voxel_x,
			REGION_SIZE_LOD0_VOXELS
		),
		_floor_div(
			world_voxel_z,
			REGION_SIZE_LOD0_VOXELS
		)
	)


static func get_region_coord_from_block(
	block_position: Vector3i,
	lod_index: int
) -> Vector2i:
	var blocks_per_axis: int = (
		get_blocks_per_region_axis(
			lod_index
		)
	)

	if blocks_per_axis <= 0:
		return Vector2i.ZERO

	return Vector2i(
		_floor_div(
			block_position.x,
			blocks_per_axis
		),
		_floor_div(
			block_position.z,
			blocks_per_axis
		)
	)


static func get_local_block_position(
	block_position: Vector3i,
	lod_index: int
) -> Vector3i:
	var region_coord: Vector2i = (
		get_region_coord_from_block(
			block_position,
			lod_index
		)
	)

	var blocks_per_axis: int = (
		get_blocks_per_region_axis(
			lod_index
		)
	)

	return Vector3i(
		block_position.x
			- region_coord.x * blocks_per_axis,

		block_position.y,

		block_position.z
			- region_coord.y * blocks_per_axis
	)


static func get_region_origin_voxel(
	region_coord: Vector2i
) -> Vector3i:
	return Vector3i(
		region_coord.x
			* REGION_SIZE_LOD0_VOXELS,

		0,

		region_coord.y
			* REGION_SIZE_LOD0_VOXELS
	)


static func get_region_max_voxel_exclusive(
	region_coord: Vector2i
) -> Vector3i:
	var origin: Vector3i = (
		get_region_origin_voxel(
			region_coord
		)
	)

	return Vector3i(
		origin.x
			+ REGION_SIZE_LOD0_VOXELS,

		0,

		origin.z
			+ REGION_SIZE_LOD0_VOXELS
	)


static func get_lod_block_span_voxels(
	lod_index: int
) -> int:
	if not is_valid_lod(
		lod_index
	):
		return 0

	return (
		BakedWorldConfigScript.DATA_BLOCK_SIZE
		* (1 << lod_index)
	)


static func get_blocks_per_region_axis(
	lod_index: int
) -> int:
	var block_span: int = (
		get_lod_block_span_voxels(
			lod_index
		)
	)

	if block_span <= 0:
		return 0

	return int(
		float(
			REGION_SIZE_LOD0_VOXELS
		)
		/ float(
			block_span
		)
	)


static func get_region_filename(
	region_coord: Vector2i
) -> String:
	return (
		"%s_%d_%d.%s"
		% [
			FILE_NAME_PREFIX,
			region_coord.x,
			region_coord.y,
			FILE_EXTENSION
		]
	)


static func get_region_path(
	root_directory: String,
	region_coord: Vector2i
) -> String:
	return root_directory.path_join(
		get_region_filename(
			region_coord
		)
	)


static func is_valid_lod(
	lod_index: int
) -> bool:
	return (
		lod_index >= 0
		and lod_index
			< BakedWorldConfigScript.LOD_COUNT
	)


static func validate_format() -> bool:
	if (
		BakedWorldConfigScript.DATA_BLOCK_SIZE
		<= 0
	):
		return false

	if (
		BakedWorldConfigScript.LOD_COUNT
		<= 0
	):
		return false

	if (
		REGION_SIZE_LOD0_VOXELS
		<= 0
	):
		return false

	for lod_index in range(
		BakedWorldConfigScript.LOD_COUNT
	):
		var block_span: int = (
			get_lod_block_span_voxels(
				lod_index
			)
		)

		if block_span <= 0:
			return false

		if (
			REGION_SIZE_LOD0_VOXELS
			% block_span
			!= 0
		):
			return false

		var blocks_per_axis: int = (
			get_blocks_per_region_axis(
				lod_index
			)
		)

		if blocks_per_axis <= 0:
			return false

		if blocks_per_axis > 255:
			return false

	return true


static func _floor_div(
	value: int,
	divisor: int
) -> int:
	if divisor <= 0:
		return 0

	return floori(
		float(value)
		/ float(divisor)
	)
