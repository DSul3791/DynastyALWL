extends RefCounted

# Voxel channels written by the runtime terrain generator (plan step 14).
# Do not change these assignments once worlds are played: saved edits and
# client caches store them.
#
#   SDF       16 bit  signed distance in meters, negative = solid
#   ROCK      8 bit   rock table id (0 = air or water, 1 = sediment for the
#                     loose cover above bedrock)
#   SOIL      8 bit   soil table id of cover voxels, 0 elsewhere
#   RESOURCE  8 bit   resource table id of ore voxels, 0 elsewhere
#
# The rendering channels (INDICES and WEIGHTS) stay free for the client.

const CHANNEL_SDF := VoxelBuffer.CHANNEL_SDF
const CHANNEL_ROCK := VoxelBuffer.CHANNEL_DATA5
const CHANNEL_SOIL := VoxelBuffer.CHANNEL_DATA6
const CHANNEL_RESOURCE := VoxelBuffer.CHANNEL_DATA7

const ROCK_SEDIMENT := 1


static func used_channels_mask() -> int:
	return (1 << CHANNEL_SDF) | (1 << CHANNEL_ROCK) | (1 << CHANNEL_SOIL) | (1 << CHANNEL_RESOURCE)


# A voxel format with the depths above, for VoxelTerrain, VoxelLodTerrain
# and test buffers.
static func make_format() -> VoxelFormat:
	var format: VoxelFormat = VoxelFormat.new()
	format.set_channel_depth(CHANNEL_SDF, VoxelBuffer.DEPTH_16_BIT)
	format.set_channel_depth(CHANNEL_ROCK, VoxelBuffer.DEPTH_8_BIT)
	format.set_channel_depth(CHANNEL_SOIL, VoxelBuffer.DEPTH_8_BIT)
	format.set_channel_depth(CHANNEL_RESOURCE, VoxelBuffer.DEPTH_8_BIT)
	return format


# A block buffer in that format.
static func make_buffer(size: int = 32) -> VoxelBuffer:
	var buffer: VoxelBuffer = VoxelBuffer.new()
	buffer.create(size, size, size)
	buffer.set_channel_depth(CHANNEL_SDF, VoxelBuffer.DEPTH_16_BIT)
	buffer.set_channel_depth(CHANNEL_ROCK, VoxelBuffer.DEPTH_8_BIT)
	buffer.set_channel_depth(CHANNEL_SOIL, VoxelBuffer.DEPTH_8_BIT)
	buffer.set_channel_depth(CHANNEL_RESOURCE, VoxelBuffer.DEPTH_8_BIT)
	return buffer
