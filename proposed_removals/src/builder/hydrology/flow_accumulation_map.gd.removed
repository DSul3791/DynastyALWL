class_name FlowAccumulationMap
extends RefCounted


var _flow_map

var _width: int = 0
var _depth: int = 0

var _spacing_meters: float = 1.0

var _accumulation_cells: PackedInt32Array
var _upstream_counts: PackedInt32Array

var _maximum_accumulation: int = 0
var _maximum_accumulation_index: int = -1

var _processed_cell_count: int = 0


func setup(
	flow_map,
	spacing_meters: float
) -> void:
	_flow_map = flow_map

	_width = _flow_map.get_width()
	_depth = _flow_map.get_depth()

	_spacing_meters = maxf(
		spacing_meters,
		1.0
	)

	var cell_count: int = (
		_width * _depth
	)

	_accumulation_cells.resize(
		cell_count
	)

	_upstream_counts.resize(
		cell_count
	)

	_generate()


func _generate() -> void:
	var cell_count: int = (
		_width * _depth
	)

	_maximum_accumulation = 0
	_maximum_accumulation_index = -1
	_processed_cell_count = 0

	# Every cell initially contributes itself.
	for index in range(cell_count):
		_accumulation_cells[index] = 1
		_upstream_counts[index] = 0

	# Count how many cells flow directly into each cell.
	for index in range(cell_count):
		var grid_position: Vector2i = (
			_index_to_grid_position(
				index
			)
		)

		var downstream_index: int = (
			_flow_map.get_downstream_index(
				grid_position.x,
				grid_position.y
			)
		)

		if downstream_index >= 0:
			_upstream_counts[
				downstream_index
			] += 1

	# Fixed-size queue avoids expensive pop_front()
	# operations when this eventually scales to large maps.
	var queue: PackedInt32Array = (
		PackedInt32Array()
	)

	queue.resize(cell_count)

	var queue_read: int = 0
	var queue_write: int = 0

	# Headwater cells have nothing flowing into them.
	for index in range(cell_count):
		if _upstream_counts[index] == 0:
			queue[queue_write] = index
			queue_write += 1

	# Process cells from upstream toward downstream.
	while queue_read < queue_write:
		var current_index: int = (
			queue[queue_read]
		)

		queue_read += 1
		_processed_cell_count += 1

		var current_position: Vector2i = (
			_index_to_grid_position(
				current_index
			)
		)

		var downstream_index: int = (
			_flow_map.get_downstream_index(
				current_position.x,
				current_position.y
			)
		)

		if downstream_index >= 0:
			_accumulation_cells[
				downstream_index
			] += _accumulation_cells[
				current_index
			]

			_upstream_counts[
				downstream_index
			] -= 1

			if (
				_upstream_counts[
					downstream_index
				]
				== 0
			):
				queue[queue_write] = downstream_index
				queue_write += 1

	if _processed_cell_count != cell_count:
		push_error(
			"Flow accumulation failed: "
			+ "flow graph contains a cycle."
		)

	_find_maximum_accumulation()


func _find_maximum_accumulation() -> void:
	var cell_count: int = (
		_width * _depth
	)

	for index in range(cell_count):
		var accumulation: int = (
			_accumulation_cells[index]
		)

		if accumulation > _maximum_accumulation:
			_maximum_accumulation = accumulation
			_maximum_accumulation_index = index


func get_accumulation_cells(
	grid_x: int,
	grid_z: int
) -> int:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0

	return _accumulation_cells[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_drainage_area_square_meters(
	grid_x: int,
	grid_z: int
) -> float:
	var contributing_cells: int = (
		get_accumulation_cells(
			grid_x,
			grid_z
		)
	)

	var cell_area: float = (
		_spacing_meters
		* _spacing_meters
	)

	return (
		float(contributing_cells)
		* cell_area
	)


func get_drainage_area_hectares(
	grid_x: int,
	grid_z: int
) -> float:
	return (
		get_drainage_area_square_meters(
			grid_x,
			grid_z
		)
		/ 10000.0
	)


func get_drainage_area_square_kilometers(
	grid_x: int,
	grid_z: int
) -> float:
	return (
		get_drainage_area_square_meters(
			grid_x,
			grid_z
		)
		/ 1000000.0
	)


func get_maximum_accumulation() -> int:
	return _maximum_accumulation


func get_maximum_accumulation_grid_position() -> Vector2i:
	if _maximum_accumulation_index < 0:
		return Vector2i(-1, -1)

	return _index_to_grid_position(
		_maximum_accumulation_index
	)


func get_processed_cell_count() -> int:
	return _processed_cell_count


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
