class_name BakedWorldConfig
extends RefCounted


# --------------------------------------------------
# BAKED WORLD STORAGE
# --------------------------------------------------

# Voxel Tools stores terrain data in 16^3 voxel blocks.
const DATA_BLOCK_SIZE := 16

const DATA_BLOCK_SIZE_PO2 := 4

const DATA_BLOCK_VOXEL_COUNT := (
	DATA_BLOCK_SIZE
	* DATA_BLOCK_SIZE
	* DATA_BLOCK_SIZE
)


# --------------------------------------------------
# RENDERING
#
# Mesh blocks may span several data blocks.
# 32 m gives us 2x2x2 data blocks per mesh block.
# --------------------------------------------------

const MESH_BLOCK_SIZE := 32


# --------------------------------------------------
# LOD
#
# Our terrain tests already established seven LODs
# as a good target for the larger world.
# --------------------------------------------------

const LOD_COUNT := 7


# --------------------------------------------------
# BASE WORLD REGIONS
#
# This is the immutable baked terrain database.
#
# During development it lives under the project.
# Export/server packaging can place the same file
# beside the executable or inside the container.
# --------------------------------------------------

const BASE_WORLD_REGIONS_PATH := (
	"res://worlds/base_world/regions"
)


# --------------------------------------------------
# MUTABLE DATA
#
# Player/server changes do NOT get written back into
# the immutable baked base-world database.
# They will eventually live in the external save
# data system.
# --------------------------------------------------

const BASE_WORLD_IS_IMMUTABLE := true


static func get_data_block_size_vector() -> Vector3i:
	return Vector3i(
		DATA_BLOCK_SIZE,
		DATA_BLOCK_SIZE,
		DATA_BLOCK_SIZE
	)


static func voxel_to_block_position(
	voxel_position: Vector3i
) -> Vector3i:
	return Vector3i(
		_floor_divide(
			voxel_position.x,
			DATA_BLOCK_SIZE
		),
		_floor_divide(
			voxel_position.y,
			DATA_BLOCK_SIZE
		),
		_floor_divide(
			voxel_position.z,
			DATA_BLOCK_SIZE
		)
	)


static func block_to_voxel_origin(
	block_position: Vector3i
) -> Vector3i:
	return (
		block_position
		* DATA_BLOCK_SIZE
	)


static func _floor_divide(
	value: int,
	divisor: int
) -> int:
	return int(
		floor(
			float(value)
			/ float(divisor)
		)
	)
