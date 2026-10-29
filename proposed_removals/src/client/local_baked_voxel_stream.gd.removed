class_name LocalBakedVoxelStream
extends VoxelStreamScript


const Layout = preload(
	"res://src/shared/baked_voxel_layout.gd"
)


var _block_store = null
var _is_ready: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func initialize(
	block_store
) -> bool:
	if block_store == null:
		push_error(
			"LocalBakedVoxelStream received a null block store."
		)

		return false


	if not block_store.is_ready():
		push_error(
			"LocalBakedVoxelStream received a block store that is not ready."
		)

		return false


	_block_store = block_store
	_is_ready = true


	print(
		"LocalBakedVoxelStream ready."
	)


	return true


# ==================================================
# VOXEL TOOLS STREAM API
# ==================================================

func _get_used_channels_mask() -> int:
	return (
		(1 << Layout.CHANNEL_SDF)
		| (1 << Layout.CHANNEL_GEOLOGY)
		| (1 << Layout.CHANNEL_SURFICIAL_DEPOSIT)
		| (1 << Layout.CHANNEL_RESOURCE)
	)


func _load_voxel_block(
	out_buffer: VoxelBuffer,
	position_in_blocks: Vector3i,
	lod: int
) -> int:
	if not _is_ready:
		return RESULT_ERROR


	var source_buffer: VoxelBuffer = (
		_block_store.read_block(
			position_in_blocks,
			lod
		)
	)


	if source_buffer == null:
		return RESULT_ERROR


	if (
		source_buffer.get_size()
		!= out_buffer.get_size()
	):
		push_error(
			(
				"Voxel stream block size mismatch. "
				+ "Requested %s but baked block is %s."
			)
			% [
				str(
					out_buffer.get_size()
				),
				str(
					source_buffer.get_size()
				)
			]
		)

		return RESULT_ERROR


	out_buffer.copy_channel_from(
		source_buffer,
		Layout.CHANNEL_SDF
	)


	out_buffer.copy_channel_from(
		source_buffer,
		Layout.CHANNEL_GEOLOGY
	)


	out_buffer.copy_channel_from(
		source_buffer,
		Layout.CHANNEL_SURFICIAL_DEPOSIT
	)


	out_buffer.copy_channel_from(
		source_buffer,
		Layout.CHANNEL_RESOURCE
	)


	out_buffer.compress_uniform_channels()


	return RESULT_BLOCK_FOUND


func _save_voxel_block(
	_buffer: VoxelBuffer,
	_position_in_blocks: Vector3i,
	_lod: int
) -> void:
	# Client v1 is intentionally read-only.
	pass


# ==================================================
# INFORMATION
# ==================================================

func is_ready() -> bool:
	return _is_ready
