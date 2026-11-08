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
#   INDICES   8 bit   ground material for drawing (Voxel Tools "Single"
#                     texturing): in the cover and the air above, the soil
#                     id of the column's top (MATERIAL_ROCK + rock id where
#                     no soil covers it); below the cover, MATERIAL_ROCK +
#                     the voxel's own rock
#
# TERRAIN_VERSION rises whenever generated blocks change meaning, so
# server block caches and client caches made before are thrown away. The
# same happens when the tile files change (a re-bake): see tiles_stamp.

const CHANNEL_SDF := VoxelBuffer.CHANNEL_SDF
const CHANNEL_ROCK := VoxelBuffer.CHANNEL_DATA5
const CHANNEL_SOIL := VoxelBuffer.CHANNEL_DATA6
const CHANNEL_RESOURCE := VoxelBuffer.CHANNEL_DATA7
const CHANNEL_MATERIAL := VoxelBuffer.CHANNEL_INDICES
const MATERIAL_ROCK := 32
const COLLISION_LODS := 4          # the client's collision_lod_count; caves are carved at least this deep in levels (terrain_generator.gd cave_carve_lods)
const TERRAIN_VERSION := 64         # 64 (8 Nov 2026): the summits are not round: the sketch summit top has spurs and faces and blends smoothly into the flanks, the summit tent reaches farther along the spurs, and the granite under each tall summit is a core plus lobes along the spurs instead of one disc (docs/water/watershed_rebuild_design.md A1); 63 (8 Nov 2026): peaks that can stand (docs/water/watershed_rebuild_design.md A1): the sketch raises the ground round steep peaks to cones of slope 0.32 (summits keep their height, bases widen), the summit tent is gentler (power 1.3, radius 4x), and every summit at or above 900 m stands on a granite intrusion; 62 (7 Nov 2026): caves are carved at every level that has collision (LOD 0 to 3, COLLISION_LODS), so an LOD 3 block over a cave is no longer solid rock while the finer blocks load (fake cave wall, Dave's bug list); 61 (7 Nov 2026): under water the ground takes the water's straight-line shape between samples (tile_terrain_data.gd height_at), so it no longer bulges over a fall's lip or a steep stream and buries the water (Dave x 54358 z 68702); 60 (6 Nov 2026): no spawn pad (no heights pinned), the spawn moved to x 53296 z 68080 (Dave: move the spawn, do not adjust heights); 59 (6 Nov 2026): rivers routed over the finished ground (the real valley floor), cut 5 m deeper, and the dry land beside them that lay lower than the water raised to slope up from it, so it drains to the river, not into wetlands (Dave); 58 was the closed #469; 57 (6 Nov 2026): river mouths up to 32 m behind a sand bar and rivers the sea reaches through another estuary get their own estuary, through dunes too (Dave x 52798 z 68114); cave mouths as wide as the bed outside; spring caves only at the heads of brooks, none beside a river already running (Dave x 52441 z 68924); river banks 0.8 m over the water on every dry cell beside it, so the settled water stays in the bed (Dave x 52935 z 69453); 56 (5 Nov 2026): a spring cave's size follows its river: 10 m wide at the mouth or more is at least medium, 18 m or more large (Dave); 55 (5 Nov 2026): steeper, smaller hills between the big ones (rolling hills octave 130 m wide, up to 19 m, scattered; Dave); spring caves get one spring passage per 6 m of river width at the mouth (Dave); 54 (5 Nov 2026): rivers deepen (up to 2 m) and widen (to 1.6 times) over their last 3 km to the sea (Dave); rivers that touched only corner to corner run through cells that share a side (tile_river_mend.gd join_corners; Dave x 53182 z 68505: "the grass is still there"); 53 (4 Nov 2026): rolling hills about twice as frequent and up to ~60 m, within 20 m of the rivers and up into the foothills (Dave: "they are not evident"); rivers no longer stop dead where a dried lake left them at a ridge, and each is dug on until it reaches water that drains, not a landlocked pond (tile_river_mend.gd, Dave 5 Nov x 53206 z 68502); rivers widen into the sea through a sunk estuary and the sea comes up the mouth (tile_river_mouth.gd, Dave 5 Nov x 52164 z 68570); spring caves small, medium or large, mouths as wide as their river, den tunnels climbing to a hollow, bones and stalagmites; 52 (4 Nov 2026): BUG-007, caves are carved at least 0.9 voxels wide at the coarse levels, so a narrow passage no longer closes at LOD 2 and the level seam no longer draws a wall across it; 51 (4 Nov 2026): rolling hills and vales on the island plains (tile_rolling.gd hills, Dave: "way too flat"); 50 (3 Nov 2026): river banks: a dry cell beside river water higher than its ground is raised to the water plus 0.2 m (at most 1.5 m), so channels across hillsides hold their water; 49 (3 Nov 2026): spring caves: a brook head on a hillside comes out of a cave about 100 m into the hill, rising gently, the spring at the back, side branches with dens, some with 2 or 3 spring passages, and such a head keeps its brook instead of the spring moving down and the reach above drying; 48 (3 Nov 2026): river gullies are kept near the spawn (only the 60 m round the spawn point loses them), so the brooks on the hillside by the spawn run in a cut, not as a painted film over the grass; 47 (2 Nov 2026): river sources only on flats set back from edges or at the bottom, each in a pond (a raised pond cuts a brook down to the old head, a lowered one dries the reach above); 46 (2 Nov 2026): pond levels no higher than their spill (tile_pond_level.gd), no bowls over ground under 0.5 m, bowls never cut below 0.5 m (coastal ponds drained to the sea through their own beds); 45 (1 Nov 2026): land types (marsh, treeline, evergreen belt, farmland fields), lake lip 4 m, pond notch, settle rules v10; 44 (30 Oct 2026): tiles baked with 0.1 m height steps are read at that step; older generated ground is thrown away

const ROCK_SEDIMENT := 1


# A short fingerprint of the tile files in a folder (their contents, not their
# dates). A re-bake changes it, so ground generated from the old tiles is
# thrown away on the server and in client caches (owner, 2026-10-18: stale
# ground from before a bake kept coming back after clearing the client cache).
static func tiles_stamp(tiles_dir: String) -> String:
	var files: Array = Array(DirAccess.get_files_at(tiles_dir)).filter(func(f): return f.ends_with(".tile"))
	files.sort()
	var parts: PackedStringArray = PackedStringArray()

	for file in files:
		parts.append("%s=%s" % [file, FileAccess.get_md5(tiles_dir + "/" + file)])

	# The pre-carve file the tiles were baked from (next to world.json) is part of the fingerprint.
	var delta_path: String = tiles_dir.get_base_dir() + "/erosion_delta_v2.bin"

	if FileAccess.file_exists(delta_path):
		parts.append("erosion_delta_v2.bin=%s" % FileAccess.get_sha256(delta_path))

	return ",".join(parts).md5_text().substr(0, 10)


# Fingerprint of one tile file ("" when it is missing).
static func tile_stamp(tiles_dir: String, tile: Vector2i) -> String:
	var path: String = "%s/tile_%d_%d.tile" % [tiles_dir, tile.x, tile.y]
	return FileAccess.get_md5(path).substr(0, 10) if FileAccess.file_exists(path) else ""


static func used_channels_mask() -> int:
	return (1 << CHANNEL_SDF) | (1 << CHANNEL_ROCK) | (1 << CHANNEL_SOIL) | (1 << CHANNEL_RESOURCE) | (1 << CHANNEL_MATERIAL)


# A voxel format with the depths above, for VoxelTerrain, VoxelLodTerrain
# and test buffers.
static func make_format() -> VoxelFormat:
	var format: VoxelFormat = VoxelFormat.new()
	format.set_channel_depth(CHANNEL_SDF, VoxelBuffer.DEPTH_16_BIT)
	format.set_channel_depth(CHANNEL_ROCK, VoxelBuffer.DEPTH_8_BIT)
	format.set_channel_depth(CHANNEL_SOIL, VoxelBuffer.DEPTH_8_BIT)
	format.set_channel_depth(CHANNEL_RESOURCE, VoxelBuffer.DEPTH_8_BIT)
	format.set_channel_depth(CHANNEL_MATERIAL, VoxelBuffer.DEPTH_8_BIT)
	return format


# A block buffer in that format.
static func make_buffer(size: int = 32) -> VoxelBuffer:
	var buffer: VoxelBuffer = VoxelBuffer.new()
	buffer.create(size, size, size)
	buffer.set_channel_depth(CHANNEL_SDF, VoxelBuffer.DEPTH_16_BIT)
	buffer.set_channel_depth(CHANNEL_ROCK, VoxelBuffer.DEPTH_8_BIT)
	buffer.set_channel_depth(CHANNEL_SOIL, VoxelBuffer.DEPTH_8_BIT)
	buffer.set_channel_depth(CHANNEL_RESOURCE, VoxelBuffer.DEPTH_8_BIT)
	buffer.set_channel_depth(CHANNEL_MATERIAL, VoxelBuffer.DEPTH_8_BIT)
	return buffer
