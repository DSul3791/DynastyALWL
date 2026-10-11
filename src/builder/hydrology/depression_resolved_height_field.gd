class_name DepressionResolvedHeightField
extends RefCounted


const ROUTING_EPSILON: float = 0.001

# Sea level is currently Y = 0.
# Terrain at or below this elevation can act as a real hydrological
# sink instead of forcing water toward the outside of the map.
const DEFAULT_SINK_LEVEL_M: float = 0.0


var _source_height_field

var _width: int = 0
var _depth: int = 0
var _spacing_meters: float = 1.0

var _sink_level_meters: float = DEFAULT_SINK_LEVEL_M


# True depression-resolved elevation.
# This does NOT include the tiny drainage gradient.
var _filled_heights: PackedFloat32Array

# Hydrology-only surface containing a tiny gradient through
# otherwise flat resolved areas.
var _routing_heights: PackedFloat32Array

# Amount the routing algorithm had to raise a cell.
var _fill_depths: PackedFloat32Array

var _visited: PackedByteArray

# Binary minimum heap containing grid indexes.
var _heap: Array[int] = []

var _filled_cell_count: int = 0
var _maximum_fill_depth: float = 0.0
var _maximum_fill_index: int = -1


func setup(
	height_field,
	sink_level_meters: float = DEFAULT_SINK_LEVEL_M
) -> void:
	_source_height_field = height_field

	_width = _source_height_field.get_width()
	_depth = _source_height_field.get_depth()

	_spacing_meters = (
		_source_height_field.get_spacing_meters()
	)

	_sink_level_meters = sink_level_meters

	var cell_count: int = (
		_width * _depth
	)

	_filled_heights.resize(cell_count)
	_routing_heights.resize(cell_count)
	_fill_depths.resize(cell_count)
	_visited.resize(cell_count)

	_heap.clear()

	_filled_cell_count = 0
	_maximum_fill_depth = 0.0
	_maximum_fill_index = -1

	for index in range(cell_count):
		_visited[index] = 0
		_filled_heights[index] = 0.0
		_routing_heights[index] = 0.0
		_fill_depths[index] = 0.0

	_generate()


func _generate() -> void:
	# The playable world is topologically wrapped.
	#
	# Therefore the outer map boundary is NOT an outlet.
	# Instead, genuine low terrain at or below the configured
	# sink level acts as the starting point for drainage.
	var sink_count: int = _seed_lowland_sinks()

	# Safety fallback. The current world should always have the
	# deep central lake basin below sea level, but if future world
	# parameters change we still need at least one routing sink.
	if sink_count == 0:
		_seed_global_minimum()

	while not _heap.is_empty():
		var current_index: int = (
			_heap_pop_min()
		)

		var current_position: Vector2i = (
			_index_to_grid_position(
				current_index
			)
		)

		for offset_z in range(-1, 2):
			for offset_x in range(-1, 2):
				if (
					offset_x == 0
					and offset_z == 0
				):
					continue

				# Hydrology wraps across both horizontal world edges.
				var neighbor_x: int = _wrap_x(
					current_position.x
					+ offset_x
				)

				var neighbor_z: int = _wrap_z(
					current_position.y
					+ offset_z
				)

				var neighbor_index: int = _get_index(
					neighbor_x,
					neighbor_z
				)

				if _visited[neighbor_index] != 0:
					continue

				_process_neighbor(
					current_index,
					neighbor_index,
					neighbor_x,
					neighbor_z
				)


# ==================================================
# HYDROLOGICAL SINKS
# ==================================================

func _seed_lowland_sinks() -> int:
	var sink_count: int = 0

	for grid_z in range(_depth):
		for grid_x in range(_width):
			var original_height: float = (
				_source_height_field.get_height_at_grid(
					grid_x,
					grid_z
				)
			)

			if original_height > _sink_level_meters:
				continue

			_seed_sink_cell(
				grid_x,
				grid_z
			)

			sink_count += 1

	return sink_count


func _seed_global_minimum() -> void:
	var minimum_height: float = INF
	var minimum_x: int = 0
	var minimum_z: int = 0

	for grid_z in range(_depth):
		for grid_x in range(_width):
			var height: float = (
				_source_height_field.get_height_at_grid(
					grid_x,
					grid_z
				)
			)

			if height < minimum_height:
				minimum_height = height
				minimum_x = grid_x
				minimum_z = grid_z

	_seed_sink_cell(
		minimum_x,
		minimum_z
	)


func _seed_sink_cell(
	grid_x: int,
	grid_z: int
) -> void:
	var index: int = _get_index(
		grid_x,
		grid_z
	)

	if _visited[index] != 0:
		return

	_visited[index] = 1

	var original_height: float = (
		_source_height_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	_filled_heights[index] = original_height
	_routing_heights[index] = original_height
	_fill_depths[index] = 0.0

	_heap_push(index)


# ==================================================
# PRIORITY-FLOOD ROUTING
# ==================================================

func _process_neighbor(
	current_index: int,
	neighbor_index: int,
	neighbor_x: int,
	neighbor_z: int
) -> void:
	_visited[neighbor_index] = 1

	var original_height: float = (
		_source_height_field.get_height_at_grid(
			neighbor_x,
			neighbor_z
		)
	)

	var current_filled_height: float = (
		_filled_heights[current_index]
	)

	var current_routing_height: float = (
		_routing_heights[current_index]
	)

	var filled_height: float = maxf(
		original_height,
		current_filled_height
	)

	var routing_height: float = maxf(
		original_height,
		current_routing_height
		+ ROUTING_EPSILON
	)

	var fill_depth: float = maxf(
		0.0,
		filled_height
		- original_height
	)

	_filled_heights[neighbor_index] = filled_height
	_routing_heights[neighbor_index] = routing_height
	_fill_depths[neighbor_index] = fill_depth

	if fill_depth > 0.0:
		_filled_cell_count += 1

		if fill_depth > _maximum_fill_depth:
			_maximum_fill_depth = fill_depth
			_maximum_fill_index = neighbor_index

	_heap_push(neighbor_index)


# ==================================================
# PUBLIC INTERFACE
# ==================================================

func get_width() -> int:
	return _width


func get_depth() -> int:
	return _depth


func get_spacing_meters() -> float:
	return _spacing_meters


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


func get_world_position(
	grid_x: int,
	grid_z: int
) -> Vector2:
	return _source_height_field.get_world_position(
		grid_x,
		grid_z
	)


func get_original_height_at_grid(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _source_height_field.get_height_at_grid(
		grid_x,
		grid_z
	)


func get_filled_height_at_grid(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _filled_heights[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_height_at_grid(
	grid_x: int,
	grid_z: int
) -> float:
	# FlowDirectionMap can use this exactly like a normal
	# height field. This is the routing surface rather than
	# the actual visible terrain.

	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _routing_heights[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_fill_depth_at_grid(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _fill_depths[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_filled_cell_count() -> int:
	return _filled_cell_count


func get_maximum_fill_depth() -> float:
	return _maximum_fill_depth


func get_maximum_fill_grid_position() -> Vector2i:
	if _maximum_fill_index < 0:
		return Vector2i(
			-1,
			-1
		)

	return _index_to_grid_position(
		_maximum_fill_index
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
# MINIMUM HEAP
# ==================================================

func _heap_push(index: int) -> void:
	_heap.append(index)

	var child: int = (
		_heap.size() - 1
	)

	while child > 0:
		var parent: int = int(
			float(child - 1)
			/ 2.0
		)

		if not _heap_index_is_lower(
			_heap[child],
			_heap[parent]
		):
			break

		var temporary: int = _heap[parent]

		_heap[parent] = _heap[child]
		_heap[child] = temporary

		child = parent


func _heap_pop_min() -> int:
	var minimum_index: int = _heap[0]

	var last_index: int = (
		_heap.pop_back()
	)

	if _heap.is_empty():
		return minimum_index

	_heap[0] = last_index

	var parent: int = 0

	while true:
		var left_child: int = (
			parent * 2
			+ 1
		)

		var right_child: int = (
			left_child
			+ 1
		)

		var smallest: int = parent

		if (
			left_child < _heap.size()
			and _heap_index_is_lower(
				_heap[left_child],
				_heap[smallest]
			)
		):
			smallest = left_child

		if (
			right_child < _heap.size()
			and _heap_index_is_lower(
				_heap[right_child],
				_heap[smallest]
			)
		):
			smallest = right_child

		if smallest == parent:
			break

		var temporary: int = _heap[parent]

		_heap[parent] = _heap[smallest]
		_heap[smallest] = temporary

		parent = smallest

	return minimum_index


func _heap_index_is_lower(
	index_a: int,
	index_b: int
) -> bool:
	return (
		_routing_heights[index_a]
		< _routing_heights[index_b]
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
