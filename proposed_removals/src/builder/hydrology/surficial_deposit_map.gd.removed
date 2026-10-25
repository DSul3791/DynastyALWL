class_name SurficialDepositMap
extends RefCounted


const Deposits := preload(
	"res://src/shared/surficial_deposit_ids.gd"
)

const Water := preload(
	"res://src/builder/hydrology/surface_water_map.gd"
)

const Channels := preload(
	"res://src/builder/hydrology/channel_network.gd"
)


var _terrain_field
var _world_definition: WorldDefinition
var _water_map
var _flow_map
var _accumulation_map
var _channel_network

var _width: int = 0
var _depth: int = 0
var _spacing_meters: float = 1.0

var _deposit_ids: PackedByteArray
var _deposit_thicknesses: PackedFloat32Array

var _deposit_counts: Array[int] = []

var _maximum_thickness: float = 0.0
var _maximum_thickness_index: int = -1


func setup(
	world_definition: WorldDefinition,
	terrain_field,
	water_map,
	flow_map,
	accumulation_map,
	channel_network
) -> void:
	_world_definition = world_definition
	_terrain_field = terrain_field
	_water_map = water_map
	_flow_map = flow_map
	_accumulation_map = accumulation_map
	_channel_network = channel_network

	_width = _terrain_field.get_width()
	_depth = _terrain_field.get_depth()

	_spacing_meters = (
		_terrain_field.get_spacing_meters()
	)

	var cell_count: int = (
		_width * _depth
	)

	_deposit_ids.resize(
		cell_count
	)

	_deposit_thicknesses.resize(
		cell_count
	)

	_deposit_ids.fill(
		Deposits.NONE
	)

	_deposit_thicknesses.fill(
		0.0
	)

	_deposit_counts.clear()

	for i in range(Deposits.PEAT + 1):
		_deposit_counts.append(0)

	_maximum_thickness = 0.0
	_maximum_thickness_index = -1

	_generate()


func _generate() -> void:
	for grid_z in range(_depth):
		for grid_x in range(_width):
			_generate_cell(
				grid_x,
				grid_z
			)


func _generate_cell(
	grid_x: int,
	grid_z: int
) -> void:
	var water_type: int = (
		_water_map.get_water_type(
			grid_x,
			grid_z
		)
	)

	# --------------------------------------------------
	# LAKES
	#
	# Fine mud, clay and organic sediment settle
	# on quiet lake bottoms.
	# --------------------------------------------------

	if water_type == Water.WATER_LAKE:
		var water_depth: float = (
			_water_map.get_water_depth(
				grid_x,
				grid_z
			)
		)

		var thickness: float = clampf(
			0.6
			+ water_depth * 0.12,
			0.6,
			3.0
		)

		_set_deposit(
			grid_x,
			grid_z,
			Deposits.LAKE_SEDIMENT,
			thickness
		)

		return

	# --------------------------------------------------
	# PONDS
	# --------------------------------------------------

	if water_type == Water.WATER_POND:
		var water_depth: float = (
			_water_map.get_water_depth(
				grid_x,
				grid_z
			)
		)

		var thickness: float = clampf(
			0.35
			+ water_depth * 0.10,
			0.35,
			1.5
		)

		_set_deposit(
			grid_x,
			grid_z,
			Deposits.LAKE_SEDIMENT,
			thickness
		)

		return

	# --------------------------------------------------
	# WETLANDS
	# --------------------------------------------------

	if water_type == Water.WATER_WETLAND:
		var drainage_area_km2: float = (
			_accumulation_map
			.get_drainage_area_square_kilometers(
				grid_x,
				grid_z
			)
		)

		var drainage_factor: float = clampf(
			drainage_area_km2 / 0.05,
			0.0,
			1.0
		)

		var thickness: float = (
			0.5
			+ drainage_factor * 1.5
		)

		_set_deposit(
			grid_x,
			grid_z,
			Deposits.PEAT,
			thickness
		)

		return

	# --------------------------------------------------
	# ACTIVE STREAM BEDS
	# --------------------------------------------------

	if water_type == Water.WATER_STREAM:
		var slope: float = (
			_flow_map.get_slope(
				grid_x,
				grid_z
			)
		)

		if slope >= 0.35:
			_set_deposit(
				grid_x,
				grid_z,
				Deposits.GRAVEL,
				0.8
			)

			return

		if slope >= 0.10:
			_set_deposit(
				grid_x,
				grid_z,
				Deposits.SAND,
				0.7
			)

			return

		_set_deposit(
			grid_x,
			grid_z,
			Deposits.ALLUVIUM,
			1.0
		)

		return

	# --------------------------------------------------
	# MARINE COAST
	#
	# The prevailing exposure bias is gradual: sheltered southern
	# shores accumulate sand, east/west shores mix sand and gravel,
	# and exposed northern slopes usually retain rock or cobble.
	# --------------------------------------------------

	if _try_generate_coastal_deposit(grid_x, grid_z):
		return

	# --------------------------------------------------
	# FLOODPLAINS
	#
	# Floodplain searches wrap across world boundaries.
	# --------------------------------------------------

	var local_slope: float = (
		_get_local_surface_slope(
			grid_x,
			grid_z
		)
	)

	if local_slope > 0.35:
		return

	var distance_to_channel: float = (
		_get_distance_to_large_channel(
			grid_x,
			grid_z
		)
	)

	if distance_to_channel < 0.0:
		return

	if distance_to_channel <= 12.0:
		_set_deposit(
			grid_x,
			grid_z,
			Deposits.ALLUVIUM,
			1.5
		)

		return

	if distance_to_channel <= 22.0:
		_set_deposit(
			grid_x,
			grid_z,
			Deposits.SILT,
			1.0
		)

		return

	if (
		distance_to_channel <= 32.0
		and local_slope <= 0.15
	):
		_set_deposit(
			grid_x,
			grid_z,
			Deposits.CLAY,
			0.7
		)


func _try_generate_coastal_deposit(
	grid_x: int,
	grid_z: int
) -> bool:
	if _world_definition == null or not _world_definition.coast_enabled:
		return false

	var world_position: Vector2 = _terrain_field.get_world_position(
		grid_x,
		grid_z
	)

	var local_x: float = _world_definition.to_island_local_x(
		world_position.x
	)
	var local_z: float = _world_definition.to_island_local_z(
		world_position.y
	)
	var half_x: float = float(_world_definition.size_x_meters) * 0.5
	var half_z: float = float(_world_definition.size_z_meters) * 0.5

	if half_x <= 0.0 or half_z <= 0.0:
		return false

	var normalized_x: float = absf(local_x) / half_x
	var normalized_z: float = absf(local_z) / half_z
	var exponent: float = 2.6
	var edge_radius: float = pow(
		pow(normalized_x, exponent)
		+ pow(normalized_z, exponent),
		1.0 / exponent
	)

	# Do not mistake an inland lake for the marine coast.
	if edge_radius < 0.52:
		return false

	var surface_y: float = _terrain_field.get_height_at_grid(
		grid_x,
		grid_z
	)
	var sea_level: float = float(_world_definition.sea_level_meters)

	if surface_y < sea_level - 14.0 or surface_y > sea_level + 22.0:
		return false

	var local_slope: float = _get_local_surface_slope(grid_x, grid_z)
	var southness: float = clampf(
		local_z / half_z * 0.5 + 0.5,
		0.0,
		1.0
	)

	if southness >= 0.58:
		if local_slope <= 0.42:
			var sand_thickness: float = lerpf(
				1.2,
				3.8,
				clampf((southness - 0.58) / 0.42, 0.0, 1.0)
			)
			_set_deposit(
				grid_x,
				grid_z,
				Deposits.SAND,
				sand_thickness
			)
			return true

		_set_deposit(grid_x, grid_z, Deposits.GRAVEL, 0.8)
		return true

	if southness <= 0.42:
		if local_slope <= 0.16:
			_set_deposit(grid_x, grid_z, Deposits.GRAVEL, 0.65)
		# Steeper northern cells deliberately remain exposed bedrock.
		return true

	if local_slope <= 0.24:
		_set_deposit(grid_x, grid_z, Deposits.SAND, 1.0)
	else:
		_set_deposit(grid_x, grid_z, Deposits.GRAVEL, 0.7)

	return true


# ==================================================
# LOCAL TERRAIN SLOPE
#
# Uses wrapped neighbors so terrain immediately
# across a world boundary is physically adjacent.
# ==================================================

func _get_local_surface_slope(
	grid_x: int,
	grid_z: int
) -> float:
	var left_x: int = _wrap_x(
		grid_x - 1
	)

	var right_x: int = _wrap_x(
		grid_x + 1
	)

	var lower_z: int = _wrap_z(
		grid_z - 1
	)

	var upper_z: int = _wrap_z(
		grid_z + 1
	)

	var left_height: float = (
		_terrain_field.get_height_at_grid(
			left_x,
			grid_z
		)
	)

	var right_height: float = (
		_terrain_field.get_height_at_grid(
			right_x,
			grid_z
		)
	)

	var lower_height: float = (
		_terrain_field.get_height_at_grid(
			grid_x,
			lower_z
		)
	)

	var upper_height: float = (
		_terrain_field.get_height_at_grid(
			grid_x,
			upper_z
		)
	)

	var sample_distance: float = (
		_spacing_meters * 2.0
	)

	var slope_x: float = (
		(right_height - left_height)
		/ sample_distance
	)

	var slope_z: float = (
		(upper_height - lower_height)
		/ sample_distance
	)

	return sqrt(
		slope_x * slope_x
		+ slope_z * slope_z
	)


# ==================================================
# FLOODPLAIN CHANNEL PROXIMITY
#
# Nearby rivers are searched across wrapped world
# boundaries as well.
# ==================================================

func _get_distance_to_large_channel(
	grid_x: int,
	grid_z: int
) -> float:
	var search_radius_cells: int = 3

	var nearest_distance: float = -1.0

	for offset_z in range(
		-search_radius_cells,
		search_radius_cells + 1
	):
		for offset_x in range(
			-search_radius_cells,
			search_radius_cells + 1
		):
			var neighbor_x: int = _wrap_x(
				grid_x + offset_x
			)

			var neighbor_z: int = _wrap_z(
				grid_z + offset_z
			)

			var channel_class: int = (
				_channel_network.get_channel_class(
					neighbor_x,
					neighbor_z
				)
			)

			if channel_class < Channels.CHANNEL_STREAM:
				continue

			var distance_x: float = (
				float(offset_x)
				* _spacing_meters
			)

			var distance_z: float = (
				float(offset_z)
				* _spacing_meters
			)

			var distance: float = sqrt(
				distance_x * distance_x
				+ distance_z * distance_z
			)

			if (
				nearest_distance < 0.0
				or distance < nearest_distance
			):
				nearest_distance = distance

	return nearest_distance


func _set_deposit(
	grid_x: int,
	grid_z: int,
	deposit_id: int,
	thickness: float
) -> void:
	var index: int = _get_index(
		grid_x,
		grid_z
	)

	_deposit_ids[index] = deposit_id

	_deposit_thicknesses[index] = maxf(
		thickness,
		0.0
	)

	if (
		deposit_id >= 0
		and deposit_id < _deposit_counts.size()
	):
		_deposit_counts[
			deposit_id
		] += 1

	if thickness > _maximum_thickness:
		_maximum_thickness = thickness
		_maximum_thickness_index = index


func get_deposit_id(
	grid_x: int,
	grid_z: int
) -> int:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return Deposits.NONE

	return _deposit_ids[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_deposit_thickness(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _deposit_thicknesses[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_deposit_count(
	deposit_id: int
) -> int:
	if (
		deposit_id < 0
		or deposit_id >= _deposit_counts.size()
	):
		return 0

	return _deposit_counts[
		deposit_id
	]


func get_maximum_thickness() -> float:
	return _maximum_thickness


func get_maximum_thickness_grid_position() -> Vector2i:
	if _maximum_thickness_index < 0:
		return Vector2i(
			-1,
			-1
		)

	return _index_to_grid_position(
		_maximum_thickness_index
	)


func get_width() -> int:
	return _width


func get_depth() -> int:
	return _depth


func get_spacing_meters() -> float:
	return _spacing_meters


func get_world_position(
	grid_x: int,
	grid_z: int
) -> Vector2:
	return _terrain_field.get_world_position(
		grid_x,
		grid_z
	)


func is_valid_grid_position(
	grid_x: int,
	grid_z: int
) -> bool:
	return (
		grid_x >= 0
		and grid_z >= 0
		and grid_x < _width
		and grid_z < _depth
	)


# ==================================================
# WORLD WRAPPING
# ==================================================

func _wrap_x(
	grid_x: int
) -> int:
	if _width <= 0:
		return 0

	return posmod(
		grid_x,
		_width
	)


func _wrap_z(
	grid_z: int
) -> int:
	if _depth <= 0:
		return 0

	return posmod(
		grid_z,
		_depth
	)


# ==================================================
# GRID HELPERS
# ==================================================

func _get_index(
	grid_x: int,
	grid_z: int
) -> int:
	return (
		grid_z * _width
		+ grid_x
	)


func _index_to_grid_position(
	index: int
) -> Vector2i:
	var grid_z: int = int(
		float(index)
		/ float(_width)
	)

	var grid_x: int = (
		index % _width
	)

	return Vector2i(
		grid_x,
		grid_z
	)
