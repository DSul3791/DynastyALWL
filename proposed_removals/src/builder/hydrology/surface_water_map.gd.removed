class_name SurfaceWaterMap
extends RefCounted


const WATER_NONE := 0
const WATER_WETLAND := 1
const WATER_POND := 2
const WATER_LAKE := 3
const WATER_STREAM := 4
const WATER_OCEAN := 5


var _terrain_field
var _channel_network
var _accumulation_map
var _lake_basins
var _lake_water
var _ocean_mask

var _width: int = 0
var _depth: int = 0

var _water_types: PackedByteArray
var _water_surface_y: PackedFloat32Array
var _water_depths: PackedFloat32Array

var _wetland_cell_count: int = 0
var _pond_cell_count: int = 0
var _lake_cell_count: int = 0
var _stream_cell_count: int = 0


func setup(
	terrain_field,
	channel_network,
	accumulation_map,
	lake_basins,
	lake_water,
	ocean_mask = null
) -> void:
	_terrain_field = terrain_field
	_channel_network = channel_network
	_accumulation_map = accumulation_map
	_lake_basins = lake_basins
	_lake_water = lake_water
	_ocean_mask = ocean_mask

	_width = _terrain_field.get_width()
	_depth = _terrain_field.get_depth()

	var cell_count: int = (
		_width * _depth
	)

	_water_types.resize(cell_count)
	_water_surface_y.resize(cell_count)
	_water_depths.resize(cell_count)

	_water_types.fill(WATER_NONE)
	_water_surface_y.fill(0.0)
	_water_depths.fill(0.0)

	_wetland_cell_count = 0
	_pond_cell_count = 0
	_lake_cell_count = 0
	_stream_cell_count = 0

	_generate()


func _generate() -> void:
	_apply_ocean_water()
	_apply_lakes_and_wetlands()
	_apply_stream_water()


func _apply_ocean_water() -> void:
	if _ocean_mask == null:
		return

	for grid_z in range(_depth):
		for grid_x in range(_width):
			if not _ocean_mask.is_ocean(grid_x, grid_z):
				continue

			var index: int = _get_index(grid_x, grid_z)
			_water_types[index] = WATER_OCEAN
			_water_surface_y[index] = (
				_ocean_mask.get_ocean_water_surface_y()
			)
			_water_depths[index] = (
				_ocean_mask.get_ocean_water_depth(grid_x, grid_z)
			)


func _apply_lakes_and_wetlands() -> void:
	for grid_z in range(_depth):
		for grid_x in range(_width):
			var index: int = _get_index(grid_x, grid_z)

			if _water_types[index] == WATER_OCEAN:
				continue

			var basin_id: int = (
				_lake_basins.get_basin_id_at_grid(
					grid_x,
					grid_z
				)
			)

			if basin_id < 0:
				continue

			var basin_class: int = (
				_lake_water.get_water_class(
					basin_id
				)
			)

			if basin_class == 0:
				continue

			var terrain_y: float = (
				_terrain_field.get_height_at_grid(
					grid_x,
					grid_z
				)
			)

			var basin_surface_y: float = (
				_lake_basins.get_basin_surface_level(
					basin_id
				)
			)

			var water_depth: float = maxf(
				0.0,
				basin_surface_y - terrain_y
			)

			match basin_class:
				1:
					_water_types[index] = WATER_WETLAND

					# Wetlands are treated as saturated /
					# seasonally flooded ground rather than
					# guaranteed open water.
					_water_surface_y[index] = terrain_y
					_water_depths[index] = 0.0

					_wetland_cell_count += 1

				2:
					_water_types[index] = WATER_POND
					_water_surface_y[index] = basin_surface_y
					_water_depths[index] = water_depth

					_pond_cell_count += 1

				3:
					_water_types[index] = WATER_LAKE
					_water_surface_y[index] = basin_surface_y
					_water_depths[index] = water_depth

					_lake_cell_count += 1


func _apply_stream_water() -> void:
	for grid_z in range(_depth):
		for grid_x in range(_width):
			var channel_class: int = (
				_channel_network.get_channel_class(
					grid_x,
					grid_z
				)
			)

			# Headwaters remain drainage channels for now.
			# They may be seasonal rather than permanently wet.
			if channel_class < 2:
				continue

			var index: int = _get_index(
				grid_x,
				grid_z
			)

			# Permanent ponds and lakes take priority.
			if (
				_water_types[index] == WATER_POND
				or _water_types[index] == WATER_LAKE
				or _water_types[index] == WATER_OCEAN
			):
				continue

			var terrain_y: float = (
				_terrain_field.get_height_at_grid(
					grid_x,
					grid_z
				)
			)

			var water_depth: float = (
				_get_stream_water_depth(
					grid_x,
					grid_z,
					channel_class
				)
			)

			_water_types[index] = WATER_STREAM

			_water_surface_y[index] = (
				terrain_y
				+ water_depth
			)

			_water_depths[index] = water_depth

			_stream_cell_count += 1


func _get_stream_water_depth(
	grid_x: int,
	grid_z: int,
	channel_class: int
) -> float:
	var base_depth: float = 0.0

	match channel_class:
		2:
			base_depth = 0.20

		3:
			base_depth = 0.45

		4:
			base_depth = 0.80

		_:
			return 0.0

	var drainage_area_km2: float = (
		_accumulation_map
		.get_drainage_area_square_kilometers(
			grid_x,
			grid_z
		)
	)

	var area_multiplier: float = pow(
		maxf(
			drainage_area_km2 / 0.025,
			1.0
		),
		0.18
	)

	area_multiplier = clampf(
		area_multiplier,
		1.0,
		1.7
	)

	return (
		base_depth
		* area_multiplier
	)


func get_water_type(
	grid_x: int,
	grid_z: int
) -> int:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return WATER_NONE

	return _water_types[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_water_type_name(
	water_type: int
) -> String:
	match water_type:
		WATER_NONE:
			return "Dry"

		WATER_WETLAND:
			return "Wetland"

		WATER_POND:
			return "Pond"

		WATER_LAKE:
			return "Lake"

		WATER_STREAM:
			return "Stream"

		WATER_OCEAN:
			return "Ocean"

		_:
			return "Unknown"


func has_open_water(
	grid_x: int,
	grid_z: int
) -> bool:
	var water_type: int = get_water_type(
		grid_x,
		grid_z
	)

	return (
		water_type == WATER_POND
		or water_type == WATER_LAKE
		or water_type == WATER_STREAM
		or water_type == WATER_OCEAN
	)


func get_water_surface_y(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _water_surface_y[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_water_depth(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _water_depths[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_wetland_cell_count() -> int:
	return _wetland_cell_count


func get_pond_cell_count() -> int:
	return _pond_cell_count


func get_lake_cell_count() -> int:
	return _lake_cell_count


func get_stream_cell_count() -> int:
	return _stream_cell_count


func get_open_water_cell_count() -> int:
	return (
		_pond_cell_count
		+ _lake_cell_count
		+ _stream_cell_count
	)


func get_width() -> int:
	return _width


func get_depth() -> int:
	return _depth


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


func _get_index(
	grid_x: int,
	grid_z: int
) -> int:
	return (
		grid_z * _width
		+ grid_x
	)
