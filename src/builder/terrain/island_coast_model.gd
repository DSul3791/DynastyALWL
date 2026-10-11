class_name IslandCoastModel
extends RefCounted


# The coast is evaluated on the shared 8-meter height field. It
# shapes only the island margin; the tectonic mountain, folds,
# faults, erosion, lakes, and rivers remain responsible inland.

const SHORE_VARIATION: float = 0.055
const NORTH_SHORE_OFFSET: float = -0.018
const SOUTH_SHORE_OFFSET: float = 0.030

const COAST_TOP_PHASE: float = 0.30
const WATERLINE_PHASE: float = 0.38


var _world: WorldDefinition
var _shore_noise := FastNoiseLite.new()
var _shelf_noise := FastNoiseLite.new()


func setup(world_definition: WorldDefinition) -> void:
	_world = world_definition

	_shore_noise.seed = _world.world_seed + 73001
	_shore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shore_noise.frequency = 0.00055

	_shelf_noise.seed = _world.world_seed + 73002
	_shelf_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shelf_noise.frequency = 0.0014


func get_shaped_height(
	world_x: float,
	world_z: float,
	original_height: float
) -> float:
	if _world == null or not _world.coast_enabled:
		return original_height

	var local_x: float = _world.to_island_local_x(world_x)
	var local_z: float = _world.to_island_local_z(world_z)
	var half_x: float = float(_world.size_x_meters) * 0.5
	var half_z: float = float(_world.size_z_meters) * 0.5

	if half_x <= 0.0 or half_z <= 0.0:
		return original_height

	var normalized_x: float = absf(local_x) / half_x
	var normalized_z: float = absf(local_z) / half_z

	# A rounded-square distance produces bays and headlands without
	# leaving land in a tile corner. Every tile edge is guaranteed to
	# reach the same abyssal floor elevation.
	var exponent: float = 2.6
	var island_radius: float = pow(
		pow(normalized_x, exponent)
		+ pow(normalized_z, exponent),
		1.0 / exponent
	)

	var southness: float = clampf(
		local_z / maxf(half_z, 1.0) * 0.5 + 0.5,
		0.0,
		1.0
	)

	var shore_noise_value: float = _shore_noise.get_noise_2d(
		local_x,
		local_z
	)

	var directional_offset: float = lerpf(
		NORTH_SHORE_OFFSET,
		SOUTH_SHORE_OFFSET,
		southness
	)

	var shoreline_radius: float = clampf(
		_world.coast_land_radius
		+ shore_noise_value * SHORE_VARIATION
		+ directional_offset,
		0.56,
		0.84
	)

	var coast_start: float = maxf(
		0.1,
		shoreline_radius - _world.coast_transition_width
	)

	if island_radius <= coast_start:
		return original_height

	var coast_phase: float = clampf(
		(island_radius - coast_start)
		/ maxf(1.0 - coast_start, 0.001),
		0.0,
		1.0
	)

	var sea_level: float = float(_world.sea_level_meters)
	var deep_ocean_y: float = (
		float(_world.world_bottom_meters)
		+ _world.coast_floor_margin_meters
	)

	# Exposed northern shores keep a taller rocky lip. Sheltered
	# southern shores approach sea level gradually and form a wider
	# beach platform.
	var coast_top_y: float = sea_level + lerpf(
		18.0,
		4.0,
		southness
	)

	var shelf_noise_value: float = _shelf_noise.get_noise_2d(
		local_x,
		local_z
	)

	var waterline_y: float = sea_level - lerpf(
		10.0,
		2.0,
		southness
	) + shelf_noise_value * 2.0

	if coast_phase <= COAST_TOP_PHASE:
		var top_blend: float = _smoothstep01(
			coast_phase / COAST_TOP_PHASE
		)
		return lerpf(original_height, coast_top_y, top_blend)

	if coast_phase <= WATERLINE_PHASE:
		var waterline_blend: float = _smoothstep01(
			(coast_phase - COAST_TOP_PHASE)
			/ (WATERLINE_PHASE - COAST_TOP_PHASE)
		)
		return lerpf(coast_top_y, waterline_y, waterline_blend)

	var slope_phase: float = clampf(
		(coast_phase - WATERLINE_PHASE)
		/ (1.0 - WATERLINE_PHASE),
		0.0,
		1.0
	)

	# A gentle shelf becomes a long continental slope. Smoothstep has
	# zero slope at the shared tile edge, which prevents a visible
	# crease when separately generated ocean borders meet.
	var slope_blend: float = _smoothstep01(slope_phase)
	return lerpf(waterline_y, deep_ocean_y, slope_blend)


func _smoothstep01(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
