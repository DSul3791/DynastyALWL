class_name WorldDefinition
extends Resource


@export_category("Identity")

@export var world_name: String = "Modular Island World"

# The world's master seed, written as a phrase. It is turned into a
# number with SHA-256, which gives the same result on every machine
# and every Godot version. Changing it reshapes every tile, so it is
# fixed once tiles are kept.
@export var world_seed_text: String = "This1is2the3greatest4game5of6all7time"

# Numeric seed. Used as the master seed only when world_seed_text is
# empty. After configure_island_tile() it holds the tile's own seed,
# which is what the generator stages read.
@export var world_seed: int = 123456

# Version 4: master seed from text and SHA-256 tile seeds.
@export var generator_version: int = 4


@export_category("Island Address")

# One island occupies exactly ten 1,024-voxel storage regions on
# each horizontal axis. The tile coordinate is permanent: tile
# (1, 0) starts at region (10, 0), for example.
@export var island_tile_x: int = 0
@export var island_tile_z: int = 0


@export_category("Horizontal Size")

@export var size_x_meters: int = 10240
@export var size_z_meters: int = 10240


@export_category("Vertical Size")

@export var world_bottom_meters: int = -4000
@export var world_top_meters: int = 4000
@export var sea_level_meters: int = 0


@export_category("Geology")

@export var stratigraphy_reference_y_meters: float = 0.0


@export_category("Voxel Settings")

@export var voxel_size_meters: float = 1.0


@export_category("Island Coast")

@export var coast_enabled: bool = true
@export var coast_land_radius: float = 0.72
@export var coast_transition_width: float = 0.16
@export var coast_floor_margin_meters: float = 1.0


var _world_identity_seed: int = 0
var _world_identity_seed_initialized: bool = false


func get_min_x() -> float:
	return float(island_tile_x * size_x_meters)


func get_max_x() -> float:
	return get_min_x() + float(size_x_meters)


func get_min_z() -> float:
	return float(island_tile_z * size_z_meters)


func get_max_z() -> float:
	return get_min_z() + float(size_z_meters)


func get_center_x() -> float:
	return (get_min_x() + get_max_x()) * 0.5


func get_center_z() -> float:
	return (get_min_z() + get_max_z()) * 0.5


func to_island_local_x(world_x: float) -> float:
	return world_x - get_center_x()


func to_island_local_z(world_z: float) -> float:
	return world_z - get_center_z()


func get_island_tile_coord() -> Vector2i:
	return Vector2i(island_tile_x, island_tile_z)


func configure_island_tile(tile_x: int, tile_z: int) -> void:
	if not _world_identity_seed_initialized:
		_world_identity_seed = _compute_world_identity_seed()
		_world_identity_seed_initialized = true

	island_tile_x = tile_x
	island_tile_z = tile_z
	world_seed = _derive_tile_seed(
		_world_identity_seed,
		tile_x,
		tile_z
	)


func get_world_identity_seed() -> int:
	if _world_identity_seed_initialized:
		return _world_identity_seed

	return _compute_world_identity_seed()


func _compute_world_identity_seed() -> int:
	if world_seed_text.is_empty():
		return world_seed & 0x7fffffff

	return seed_from_text(world_seed_text)


# Turns a phrase into the master seed. The region file header stores
# the master seed as a 32-bit integer, so it is kept positive and
# below 2^31.
static func seed_from_text(text: String) -> int:
	return _digest_to_int(text.sha256_buffer()) & 0x7fffffff


# Each tile's seed comes from SHA-256 of the master seed and the tile
# coordinate, so neighboring tiles get unrelated seeds.
#
# Generator stages add offsets of up to about 75,000 to the tile seed
# before handing it to FastNoiseLite, which takes a 32-bit seed.
# Keeping the tile seed below 2^30 leaves room for those offsets.
static func _derive_tile_seed(
	base_seed: int,
	tile_x: int,
	tile_z: int
) -> int:
	var key: String = "tile:%d:%d:%d" % [base_seed, tile_x, tile_z]
	return _digest_to_int(key.sha256_buffer()) & 0x3fffffff


static func _digest_to_int(digest: PackedByteArray) -> int:
	return (
		(digest[0] << 24)
		| (digest[1] << 16)
		| (digest[2] << 8)
		| digest[3]
	)


func get_world_height_meters() -> int:
	return world_top_meters - world_bottom_meters


func is_valid() -> bool:
	if world_name.is_empty():
		return false

	if size_x_meters <= 0:
		return false

	if size_z_meters <= 0:
		return false

	if world_top_meters <= world_bottom_meters:
		return false

	if sea_level_meters < world_bottom_meters:
		return false

	if sea_level_meters > world_top_meters:
		return false

	if stratigraphy_reference_y_meters < float(world_bottom_meters):
		return false

	if stratigraphy_reference_y_meters > float(world_top_meters):
		return false

	if voxel_size_meters <= 0.0:
		return false

	if generator_version <= 0:
		return false

	if coast_enabled:
		if coast_land_radius <= 0.1 or coast_land_radius >= 0.95:
			return false

		if coast_transition_width <= 0.01:
			return false

		if coast_floor_margin_meters < 0.0:
			return false

		if coast_floor_margin_meters >= get_world_height_meters():
			return false

	return true
