class_name BakedVoxelLayout
extends RefCounted


# --------------------------------------------------
# BAKED WORLD FORMAT
#
# Do not casually change these channel assignments
# after worlds have been baked and distributed.
#
# Increasing WORLD_FORMAT_VERSION will eventually be
# required if the stored voxel format changes.
# --------------------------------------------------

const FORMAT_VERSION := 1


# --------------------------------------------------
# TERRAIN SHAPE
#
# Negative SDF = solid
# Positive SDF = air
#
# Used directly by VoxelMesherTransvoxel.
# --------------------------------------------------

const CHANNEL_SDF := VoxelBuffer.CHANNEL_SDF


# --------------------------------------------------
# RENDERING MATERIALS
#
# Reserved for Voxel Tools smooth material blending.
#
# These are intentionally separate from gameplay
# geology/resource information.
# --------------------------------------------------

const CHANNEL_MATERIAL_INDICES := (
	VoxelBuffer.CHANNEL_INDICES
)

const CHANNEL_MATERIAL_WEIGHTS := (
	VoxelBuffer.CHANNEL_WEIGHTS
)


# --------------------------------------------------
# GAMEPLAY GEOLOGY
#
# Ancient underlying geological formation:
#
#   AIR
#   SEDIMENT
#   SHALE
#   LIMESTONE
#   COAL
#   GRANITE
#
# Stored even when rendering materials are different.
# --------------------------------------------------

const CHANNEL_GEOLOGY := (
	VoxelBuffer.CHANNEL_DATA5
)


# --------------------------------------------------
# SURFICIAL DEPOSIT
#
# Young material replacing the upper part of the
# geological column:
#
#   NONE
#   ALLUVIUM
#   GRAVEL
#   SAND
#   SILT
#   CLAY
#   LAKE_SEDIMENT
#   PEAT
# --------------------------------------------------

const CHANNEL_SURFICIAL_DEPOSIT := (
	VoxelBuffer.CHANNEL_DATA6
)


# --------------------------------------------------
# GAMEPLAY RESOURCE
#
# Resource occurrence at this voxel:
#
#   NONE
#   COAL
#   IRON
#   COPPER
#   TIN
#   LEAD
#   ZINC
#   NICKEL
#   SILVER
#   GOLD
#   SALT
#   SULFUR
#   CLAY
#   GYPSUM
#   GRAPHITE
#   GEMSTONE
#   PEAT
#
# Mineralization will feed this channel later.
# --------------------------------------------------

const CHANNEL_RESOURCE := (
	VoxelBuffer.CHANNEL_DATA7
)


# --------------------------------------------------
# CHANNEL STORAGE DEPTHS
# --------------------------------------------------

const SDF_DEPTH := (
	VoxelBuffer.DEPTH_16_BIT
)

const GEOLOGY_DEPTH := (
	VoxelBuffer.DEPTH_8_BIT
)

const SURFICIAL_DEPOSIT_DEPTH := (
	VoxelBuffer.DEPTH_8_BIT
)

const RESOURCE_DEPTH := (
	VoxelBuffer.DEPTH_8_BIT
)


static func configure_buffer(
	buffer: VoxelBuffer
) -> void:
	buffer.set_channel_depth(
		CHANNEL_SDF,
		SDF_DEPTH
	)

	buffer.set_channel_depth(
		CHANNEL_GEOLOGY,
		GEOLOGY_DEPTH
	)

	buffer.set_channel_depth(
		CHANNEL_SURFICIAL_DEPOSIT,
		SURFICIAL_DEPOSIT_DEPTH
	)

	buffer.set_channel_depth(
		CHANNEL_RESOURCE,
		RESOURCE_DEPTH
	)


static func get_channel_name(
	channel: int
) -> String:
	match channel:
		CHANNEL_SDF:
			return "SDF"

		CHANNEL_MATERIAL_INDICES:
			return "Material Indices"

		CHANNEL_MATERIAL_WEIGHTS:
			return "Material Weights"

		CHANNEL_GEOLOGY:
			return "Geology"

		CHANNEL_SURFICIAL_DEPOSIT:
			return "Surficial Deposit"

		CHANNEL_RESOURCE:
			return "Resource"

		_:
			return "Unknown"
