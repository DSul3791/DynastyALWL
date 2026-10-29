class_name OceanMask
extends RefCounted


var _world_definition
var _terrain_field

var _width: int = 0
var _depth: int = 0

var _sea_level_y: float = 0.0

var _ocean_cells: PackedByteArray

var _ocean_cell_count: int = 0
var _deepest_ocean_depth: float = 0.0
var _deepest_ocean_index: int = -1


func setup(
	world_definition,
	terrain_field
) -> void:
	_world_definition = world_definition
	_terrain_field = terrain_field

	_width = _terrain_field.get_width()
	_depth = _terrain_field.get_depth()

	_sea_level_y = float(
		_world_definition.sea_level_meters
	)

	var cell_count: int = (
		_width * _depth
	)

	_ocean_cells.resize(
		cell_count
	)

	_ocean_cells.fill(0)

	_ocean_cell_count = 0
	_deepest_ocean_depth = 0.0
	_deepest_ocean_index = -1

	_generate()


func _generate() -> void:
	var cell_count: int = (
		_width * _depth
	)

	var queue := PackedInt32Array()

	queue.resize(
		cell_count
	)

	var queue_read: int = 0
	var queue_write: int = 0

	# --------------------------------------------------
	# Seed the flood fill from world-edge cells that
	# lie at or below sea level.
	#
	# Low ground in the middle of the map is NOT ocean
	# unless water can reach it from the world boundary.
	# --------------------------------------------------

	for grid_z in range(_depth):
		for grid_x in range(_width):
			if not _is_boundary_cell(
				grid_x,
				grid_z
			):
				continue

			if not _is_below_sea_level(
				grid_x,
				grid_z
			):
				continue

			var index: int = _get_index(
				grid_x,
				grid_z
			)

			if _ocean_cells[index] != 0:
				continue

			_ocean_cells[index] = 1

			queue[queue_write] = index
			queue_write += 1

	# --------------------------------------------------
	# Flood inward through connected terrain that is
	# also at or below sea level.
	#
	# Four-way connectivity is intentional here.
	# Two low areas touching only at a diagonal corner
	# do not automatically allow the ocean through.
	# --------------------------------------------------

	while queue_read < queue_write:
		var current_index: int = (
			queue[queue_read]
		)

		queue_read += 1

		var current_position: Vector2i = (
			_index_to_grid_position(
				current_index
			)
		)

		_try_add_ocean_neighbor(
			current_position.x - 1,
			current_position.y,
			queue,
			queue_write
		)

		if _neighbor_was_added:
			queue_write += 1

		_try_add_ocean_neighbor(
			current_position.x + 1,
			current_position.y,
			queue,
			queue_write
		)

		if _neighbor_was_added:
			queue_write += 1

		_try_add_ocean_neighbor(
			current_position.x,
			current_position.y - 1,
			queue,
			queue_write
		)

		if _neighbor_was_added:
			queue_write += 1

		_try_add_ocean_neighbor(
			current_position.x,
			current_position.y + 1,
			queue,
			queue_write
		)

		if _neighbor_was_added:
			queue_write += 1

	_calculate_statistics()


var _neighbor_was_added: bool = false


func _try_add_ocean_neighbor(
	grid_x: int,
	grid_z: int,
	queue: PackedInt32Array,
	queue_write: int
) -> void:
	_neighbor_was_added = false

	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return

	if not _is_below_sea_level(
		grid_x,
		grid_z
	):
		return

	var index: int = _get_index(
		grid_x,
		grid_z
	)

	if _ocean_cells[index] != 0:
		return

	_ocean_cells[index] = 1

	queue[queue_write] = index

	_neighbor_was_added = true


func _calculate_statistics() -> void:
	for grid_z in range(_depth):
		for grid_x in range(_width):
			if not is_ocean(
				grid_x,
				grid_z
			):
				continue

			_ocean_cell_count += 1

			var terrain_y: float = (
				_terrain_field.get_height_at_grid(
					grid_x,
					grid_z
				)
			)

			var water_depth: float = maxf(
				0.0,
				_sea_level_y - terrain_y
			)

			if (
				water_depth
				> _deepest_ocean_depth
			):
				_deepest_ocean_depth = water_depth

				_deepest_ocean_index = _get_index(
					grid_x,
					grid_z
				)


func _is_boundary_cell(
	grid_x: int,
	grid_z: int
) -> bool:
	return (
		grid_x == 0
		or grid_z == 0
		or grid_x == _width - 1
		or grid_z == _depth - 1
	)


func _is_below_sea_level(
	grid_x: int,
	grid_z: int
) -> bool:
	var terrain_y: float = (
		_terrain_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	return terrain_y <= _sea_level_y


func is_ocean(
	grid_x: int,
	grid_z: int
) -> bool:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return false

	return (
		_ocean_cells[
			_get_index(
				grid_x,
				grid_z
			)
		]
		!= 0
	)


func get_ocean_water_surface_y() -> float:
	return _sea_level_y


func get_ocean_water_depth(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_ocean(
		grid_x,
		grid_z
	):
		return 0.0

	var terrain_y: float = (
		_terrain_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	return maxf(
		0.0,
		_sea_level_y - terrain_y
	)


func get_ocean_cell_count() -> int:
	return _ocean_cell_count


func get_deepest_ocean_depth() -> float:
	return _deepest_ocean_depth


func get_deepest_ocean_grid_position() -> Vector2i:
	if _deepest_ocean_index < 0:
		return Vector2i(
			-1,
			-1
		)

	return _index_to_grid_position(
		_deepest_ocean_index
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
