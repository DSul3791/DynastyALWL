class_name LakeBasinMap
extends RefCounted


const MIN_FILL_DEPTH: float = 0.10
const SPILL_LEVEL_TOLERANCE: float = 0.05


var _resolved_field

var _width: int = 0
var _depth: int = 0
var _spacing_meters: float = 1.0

var _basin_ids: PackedInt32Array

var _basin_cell_counts: Array[int] = []
var _basin_max_depths: Array[float] = []
var _basin_surface_levels: Array[float] = []
var _basin_min_terrain_levels: Array[float] = []

var _largest_basin_id: int = -1
var _deepest_basin_id: int = -1


func setup(
	resolved_field
) -> void:
	_resolved_field = resolved_field

	_width = (
		_resolved_field.get_width()
	)

	_depth = (
		_resolved_field.get_depth()
	)

	_spacing_meters = (
		_resolved_field.get_spacing_meters()
	)

	var cell_count: int = (
		_width * _depth
	)

	_basin_ids.resize(
		cell_count
	)

	_basin_ids.fill(
		-1
	)

	_basin_cell_counts.clear()
	_basin_max_depths.clear()
	_basin_surface_levels.clear()
	_basin_min_terrain_levels.clear()

	_largest_basin_id = -1
	_deepest_basin_id = -1

	_generate()


func _generate() -> void:
	# Lake basins are now entirely natural.
	#
	# A basin must exist because the hydrology resolver
	# had to fill a genuine terrain depression.
	#
	# There is no special central lake and no hard-coded
	# permanent water elevation.

	_generate_filled_depression_basins()

	_find_largest_and_deepest_basins()


# ==================================================
# NATURAL FILLED DEPRESSIONS
# ==================================================

func _generate_filled_depression_basins() -> void:
	for grid_z in range(
		_depth
	):
		for grid_x in range(
			_width
		):
			var index: int = _get_index(
				grid_x,
				grid_z
			)

			if _basin_ids[index] >= 0:
				continue

			var fill_depth: float = (
				_resolved_field
					.get_fill_depth_at_grid(
						grid_x,
						grid_z
					)
			)

			if (
				fill_depth
				< MIN_FILL_DEPTH
			):
				continue

			var basin_id: int = (
				_basin_cell_counts.size()
			)

			_create_filled_basin(
				basin_id,
				grid_x,
				grid_z
			)


func _create_filled_basin(
	basin_id: int,
	start_x: int,
	start_z: int
) -> void:
	var start_surface_level: float = (
		_resolved_field
			.get_filled_height_at_grid(
				start_x,
				start_z
			)
	)

	_begin_basin(
		start_surface_level
	)

	var maximum_queue_size: int = (
		_width * _depth
	)

	var queue: PackedInt32Array = (
		PackedInt32Array()
	)

	queue.resize(
		maximum_queue_size
	)

	var queue_read: int = 0
	var queue_write: int = 0

	var start_index: int = _get_index(
		start_x,
		start_z
	)

	_basin_ids[
		start_index
	] = basin_id

	queue[
		queue_write
	] = start_index

	queue_write += 1

	while queue_read < queue_write:
		var current_index: int = (
			queue[
				queue_read
			]
		)

		queue_read += 1

		var current_position: Vector2i = (
			_index_to_grid_position(
				current_index
			)
		)

		_process_filled_basin_cell(
			basin_id,
			current_position.x,
			current_position.y
		)

		for offset_z in range(
			-1,
			2
		):
			for offset_x in range(
				-1,
				2
			):
				if (
					offset_x == 0
					and offset_z == 0
				):
					continue

				var neighbor_x: int = (
					_wrap_x(
						current_position.x
							+ offset_x
					)
				)

				var neighbor_z: int = (
					_wrap_z(
						current_position.y
							+ offset_z
					)
				)

				var neighbor_index: int = (
					_get_index(
						neighbor_x,
						neighbor_z
					)
				)

				if (
					_basin_ids[
						neighbor_index
					] >= 0
				):
					continue

				var neighbor_fill_depth: float = (
					_resolved_field
						.get_fill_depth_at_grid(
							neighbor_x,
							neighbor_z
						)
				)

				if (
					neighbor_fill_depth
						< MIN_FILL_DEPTH
				):
					continue

				var neighbor_surface_level: float = (
					_resolved_field
						.get_filled_height_at_grid(
							neighbor_x,
							neighbor_z
						)
				)

				if (
					absf(
						neighbor_surface_level
							- start_surface_level
					)
					> SPILL_LEVEL_TOLERANCE
				):
					continue

				_basin_ids[
					neighbor_index
				] = basin_id

				queue[
					queue_write
				] = neighbor_index

				queue_write += 1


func _process_filled_basin_cell(
	basin_id: int,
	grid_x: int,
	grid_z: int
) -> void:
	_basin_cell_counts[
		basin_id
	] += 1

	var fill_depth: float = (
		_resolved_field
			.get_fill_depth_at_grid(
				grid_x,
				grid_z
			)
	)

	if (
		fill_depth
			> _basin_max_depths[
				basin_id
			]
	):
		_basin_max_depths[
			basin_id
		] = fill_depth

	var terrain_y: float = (
		_resolved_field
			.get_original_height_at_grid(
				grid_x,
				grid_z
			)
	)

	if (
		terrain_y
			< _basin_min_terrain_levels[
				basin_id
			]
	):
		_basin_min_terrain_levels[
			basin_id
		] = terrain_y


func _begin_basin(
	surface_level: float
) -> void:
	_basin_cell_counts.append(
		0
	)

	_basin_max_depths.append(
		0.0
	)

	_basin_surface_levels.append(
		surface_level
	)

	_basin_min_terrain_levels.append(
		INF
	)


# ==================================================
# BASIN STATISTICS
# ==================================================

func _find_largest_and_deepest_basins() -> void:
	var largest_cell_count: int = 0
	var deepest_depth: float = 0.0

	for basin_id in range(
		get_basin_count()
	):
		var cell_count: int = (
			_basin_cell_counts[
				basin_id
			]
		)

		if (
			cell_count
				> largest_cell_count
		):
			largest_cell_count = (
				cell_count
			)

			_largest_basin_id = (
				basin_id
			)

		var depth: float = (
			_basin_max_depths[
				basin_id
			]
		)

		if (
			depth
				> deepest_depth
		):
			deepest_depth = depth
			_deepest_basin_id = (
				basin_id
			)


# ==================================================
# PUBLIC INTERFACE
# ==================================================

func get_basin_count() -> int:
	return (
		_basin_cell_counts.size()
	)


func get_basin_id_at_grid(
	grid_x: int,
	grid_z: int
) -> int:
	if not _is_valid_grid_position(
		grid_x,
		grid_z
	):
		return -1

	return _basin_ids[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_basin_cell_count(
	basin_id: int
) -> int:
	if not _is_valid_basin_id(
		basin_id
	):
		return 0

	return _basin_cell_counts[
		basin_id
	]


func get_basin_area_square_meters(
	basin_id: int
) -> float:
	if not _is_valid_basin_id(
		basin_id
	):
		return 0.0

	var cell_area: float = (
		_spacing_meters
		* _spacing_meters
	)

	return (
		float(
			_basin_cell_counts[
				basin_id
			]
		)
		* cell_area
	)


func get_basin_area_hectares(
	basin_id: int
) -> float:
	return (
		get_basin_area_square_meters(
			basin_id
		)
		/ 10000.0
	)


func get_basin_max_depth(
	basin_id: int
) -> float:
	if not _is_valid_basin_id(
		basin_id
	):
		return 0.0

	return _basin_max_depths[
		basin_id
	]


func get_basin_surface_level(
	basin_id: int
) -> float:
	if not _is_valid_basin_id(
		basin_id
	):
		return 0.0

	return _basin_surface_levels[
		basin_id
	]


func get_basin_min_terrain_level(
	basin_id: int
) -> float:
	if not _is_valid_basin_id(
		basin_id
	):
		return 0.0

	return _basin_min_terrain_levels[
		basin_id
	]


func get_largest_basin_id() -> int:
	return _largest_basin_id


func get_deepest_basin_id() -> int:
	return _deepest_basin_id


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
# VALIDATION / GRID HELPERS
# ==================================================

func _is_valid_basin_id(
	basin_id: int
) -> bool:
	return (
		basin_id >= 0
		and basin_id
			< get_basin_count()
	)


func _is_valid_grid_position(
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
