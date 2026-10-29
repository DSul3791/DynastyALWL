class_name BakedBlockCodec
extends RefCounted


const BakedWorldConfigScript := preload(
	"res://src/shared/baked_world_config.gd"
)

const BakedVoxelLayoutScript := preload(
	"res://src/shared/baked_voxel_layout.gd"
)

const Geology := preload(
	"res://src/shared/geology_ids.gd"
)

const Deposits := preload(
	"res://src/shared/surficial_deposit_ids.gd"
)

const Resources := preload(
	"res://src/shared/resource_ids.gd"
)


const FORMAT_VERSION := 2


const SDF_BYTES_PER_VOXEL := 2
const DATA_BYTES_PER_VOXEL := 1


const SDF_BASE_MAX_DISTANCE := 64.0
const SDF_STORAGE_MAX_DISTANCE := 500.0


# Compact payload:
#
# byte 0 = marker
# byte 1 = LOD
#
# Normal voxel payloads remain 20480 bytes.
const COMPACT_UNIFORM_GRANITE_MARKER := 0xA1
const COMPACT_PAYLOAD_SIZE := 2


static func get_voxel_count() -> int:
	var block_size: int = (
		BakedWorldConfigScript.DATA_BLOCK_SIZE
	)

	return (
		block_size
		* block_size
		* block_size
	)


static func get_sdf_byte_count() -> int:
	return (
		get_voxel_count()
		* SDF_BYTES_PER_VOXEL
	)


static func get_data_channel_byte_count() -> int:
	return (
		get_voxel_count()
		* DATA_BYTES_PER_VOXEL
	)


static func get_payload_size_bytes() -> int:
	return (
		get_sdf_byte_count()
		+ get_data_channel_byte_count() * 3
	)


# ==================================================
# COMPACT UNIFORM GRANITE
# ==================================================

static func encode_uniform_deep_granite(
	lod_index: int
) -> PackedByteArray:
	var payload := PackedByteArray()

	payload.resize(
		COMPACT_PAYLOAD_SIZE
	)

	payload[0] = (
		COMPACT_UNIFORM_GRANITE_MARKER
	)

	payload[1] = clampi(
		lod_index,
		0,
		255
	)

	return payload


static func is_compact_uniform_deep_granite(
	payload: PackedByteArray
) -> bool:
	return (
		payload.size()
			== COMPACT_PAYLOAD_SIZE
		and payload[0]
			== COMPACT_UNIFORM_GRANITE_MARKER
	)


# ==================================================
# NORMAL VOXEL BUFFER ENCODING
# ==================================================

static func encode_buffer(
	voxel_buffer: VoxelBuffer
) -> PackedByteArray:
	var empty_payload := PackedByteArray()

	if voxel_buffer == null:
		push_error(
			"Cannot encode a null VoxelBuffer."
		)
		return empty_payload

	var block_size: int = (
		BakedWorldConfigScript.DATA_BLOCK_SIZE
	)

	var expected_size := Vector3i(
		block_size,
		block_size,
		block_size
	)

	if voxel_buffer.get_size() != expected_size:
		push_error(
			(
				"Cannot encode VoxelBuffer of size %s. "
				+ "Expected %s."
			)
			% [
				str(
					voxel_buffer.get_size()
				),
				str(
					expected_size
				)
			]
		)

		return empty_payload

	if (
		voxel_buffer.get_channel_depth(
			BakedVoxelLayoutScript.CHANNEL_SDF
		)
		!= VoxelBuffer.DEPTH_16_BIT
	):
		push_error(
			"Baked SDF channel is not 16-bit."
		)

		return empty_payload

	if (
		voxel_buffer.get_channel_depth(
			BakedVoxelLayoutScript.CHANNEL_GEOLOGY
		)
		!= VoxelBuffer.DEPTH_8_BIT
	):
		push_error(
			"Baked geology channel is not 8-bit."
		)

		return empty_payload

	if (
		voxel_buffer.get_channel_depth(
			BakedVoxelLayoutScript
				.CHANNEL_SURFICIAL_DEPOSIT
		)
		!= VoxelBuffer.DEPTH_8_BIT
	):
		push_error(
			"Baked deposit channel is not 8-bit."
		)

		return empty_payload

	if (
		voxel_buffer.get_channel_depth(
			BakedVoxelLayoutScript.CHANNEL_RESOURCE
		)
		!= VoxelBuffer.DEPTH_8_BIT
	):
		push_error(
			"Baked resource channel is not 8-bit."
		)

		return empty_payload

	var sdf_bytes: PackedByteArray = (
		voxel_buffer.get_channel_as_byte_array(
			BakedVoxelLayoutScript.CHANNEL_SDF
		)
	)

	var geology_bytes: PackedByteArray = (
		voxel_buffer.get_channel_as_byte_array(
			BakedVoxelLayoutScript.CHANNEL_GEOLOGY
		)
	)

	var deposit_bytes: PackedByteArray = (
		voxel_buffer.get_channel_as_byte_array(
			BakedVoxelLayoutScript
				.CHANNEL_SURFICIAL_DEPOSIT
		)
	)

	var resource_bytes: PackedByteArray = (
		voxel_buffer.get_channel_as_byte_array(
			BakedVoxelLayoutScript.CHANNEL_RESOURCE
		)
	)

	if (
		sdf_bytes.size()
		!= get_sdf_byte_count()
	):
		push_error(
			"Unexpected SDF byte count."
		)

		return empty_payload

	if (
		geology_bytes.size()
		!= get_data_channel_byte_count()
	):
		push_error(
			"Unexpected geology byte count."
		)

		return empty_payload

	if (
		deposit_bytes.size()
		!= get_data_channel_byte_count()
	):
		push_error(
			"Unexpected deposit byte count."
		)

		return empty_payload

	if (
		resource_bytes.size()
		!= get_data_channel_byte_count()
	):
		push_error(
			"Unexpected resource byte count."
		)

		return empty_payload

	var payload := PackedByteArray()

	payload.append_array(
		sdf_bytes
	)

	payload.append_array(
		geology_bytes
	)

	payload.append_array(
		deposit_bytes
	)

	payload.append_array(
		resource_bytes
	)

	if (
		payload.size()
		!= get_payload_size_bytes()
	):
		push_error(
			"Final baked block payload has unexpected size."
		)

		return empty_payload

	return payload


# ==================================================
# DECODING
# ==================================================

static func decode_buffer(
	payload: PackedByteArray
) -> VoxelBuffer:
	if is_compact_uniform_deep_granite(
		payload
	):
		return _decode_uniform_deep_granite(
			int(payload[1])
		)

	if (
		payload.size()
		!= get_payload_size_bytes()
	):
		push_error(
			(
				"Cannot decode baked block payload of "
				+ "%d bytes. Expected %d or compact block."
			)
			% [
				payload.size(),
				get_payload_size_bytes()
			]
		)

		return null

	var sdf_size: int = (
		get_sdf_byte_count()
	)

	var data_size: int = (
		get_data_channel_byte_count()
	)

	var sdf_begin: int = 0

	var geology_begin: int = (
		sdf_begin + sdf_size
	)

	var deposit_begin: int = (
		geology_begin + data_size
	)

	var resource_begin: int = (
		deposit_begin + data_size
	)

	var payload_end: int = (
		resource_begin + data_size
	)

	var sdf_bytes: PackedByteArray = (
		payload.slice(
			sdf_begin,
			geology_begin
		)
	)

	var geology_bytes: PackedByteArray = (
		payload.slice(
			geology_begin,
			deposit_begin
		)
	)

	var deposit_bytes: PackedByteArray = (
		payload.slice(
			deposit_begin,
			resource_begin
		)
	)

	var resource_bytes: PackedByteArray = (
		payload.slice(
			resource_begin,
			payload_end
		)
	)

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

	voxel_buffer.set_channel_from_byte_array(
		BakedVoxelLayoutScript.CHANNEL_SDF,
		sdf_bytes
	)

	voxel_buffer.set_channel_from_byte_array(
		BakedVoxelLayoutScript.CHANNEL_GEOLOGY,
		geology_bytes
	)

	voxel_buffer.set_channel_from_byte_array(
		BakedVoxelLayoutScript
			.CHANNEL_SURFICIAL_DEPOSIT,
		deposit_bytes
	)

	voxel_buffer.set_channel_from_byte_array(
		BakedVoxelLayoutScript.CHANNEL_RESOURCE,
		resource_bytes
	)

	voxel_buffer.compress_uniform_channels()

	return voxel_buffer


static func _decode_uniform_deep_granite(
	lod_index: int
) -> VoxelBuffer:
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

	var sdf_max_distance: float = (
		_get_sdf_max_distance(
			lod_index
		)
	)

	voxel_buffer.fill_f(
		-sdf_max_distance,
		BakedVoxelLayoutScript.CHANNEL_SDF
	)

	voxel_buffer.fill(
		Geology.GRANITE,
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


static func _get_sdf_max_distance(
	lod_index: int
) -> float:
	var lod_scale: float = float(
		1 << lod_index
	)

	return minf(
		SDF_BASE_MAX_DISTANCE
			* lod_scale,
		SDF_STORAGE_MAX_DISTANCE
	)
