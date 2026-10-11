class_name BakedImplicitBlockFactory
extends RefCounted


const BakedWorldConfigScript = preload(
	"res://src/shared/baked_world_config.gd"
)

const BakedVoxelLayoutScript = preload(
	"res://src/shared/baked_voxel_layout.gd"
)

const BakedBlockCodecScript = preload(
	"res://src/shared/baked_block_codec.gd"
)

const Geology = preload(
	"res://src/shared/geology_ids.gd"
)

const Deposits = preload(
	"res://src/shared/surficial_deposit_ids.gd"
)

const Resources = preload(
	"res://src/shared/resource_ids.gd"
)


# ==================================================
# DEEP GRANITE
# ==================================================

static func create_deep_granite(
	lod_index: int
) -> VoxelBuffer:
	var payload: PackedByteArray = (
		BakedBlockCodecScript
			.encode_uniform_deep_granite(
				lod_index
			)
	)


	return (
		BakedBlockCodecScript.decode_buffer(
			payload
		)
	)


# ==================================================
# AIR
# ==================================================

static func create_air(
	lod_index: int
) -> VoxelBuffer:
	if (
		lod_index < 0
		or lod_index
			>= BakedWorldConfigScript.LOD_COUNT
	):
		push_error(
			"Invalid LOD for implicit air block: %d"
			% lod_index
		)

		return null


	var voxel_buffer := VoxelBuffer.new()


	BakedVoxelLayoutScript.configure_buffer(
		voxel_buffer
	)


	var block_size: int = (
		BakedWorldConfigScript.DATA_BLOCK_SIZE
	)


	voxel_buffer.create(
		block_size,
		block_size,
		block_size
	)


	# Same SDF distance convention used by the
	# existing baked block codec.
	#
	# Positive SDF = air.

	var lod_scale: float = float(
		1 << lod_index
	)


	var sdf_max_distance: float = minf(
		BakedBlockCodecScript.SDF_BASE_MAX_DISTANCE
			* lod_scale,
		BakedBlockCodecScript.SDF_STORAGE_MAX_DISTANCE
	)


	voxel_buffer.fill_f(
		sdf_max_distance,
		BakedVoxelLayoutScript.CHANNEL_SDF
	)


	voxel_buffer.fill(
		Geology.AIR,
		BakedVoxelLayoutScript.CHANNEL_GEOLOGY
	)


	voxel_buffer.fill(
		Deposits.NONE,
		BakedVoxelLayoutScript
			.CHANNEL_SURFICIAL_DEPOSIT
	)


	voxel_buffer.fill(
		Resources.NONE,
		BakedVoxelLayoutScript.CHANNEL_RESOURCE
	)


	voxel_buffer.compress_uniform_channels()


	return voxel_buffer
