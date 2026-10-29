class_name FlowDirectionMap
extends RefCounted


const NO_FLOW := -1

# Retained for compatibility with code which may still reference it.
# Wrapped worlds no longer create edge outlets.
const OUTLET := -2


var _height_field

var _width: int = 0
var _depth: int = 0
var _spacing_meters: float = 1.0

var _downstream: PackedInt32Array
var _slope: PackedFloat32Array

var _sink_count: int = 0
var _outlet_count: int = 0


func setup(height_field) -> void:
	_height_field = height_field

	_width = _height_field.get_width()
	_depth = _height_field.get_depth()
	_spacing_meters = _height_field.get_spacing_meters()

	_downstream.resize(
		_width * _depth
	)

	_slope.resize(
		_width * _depth
	)

	_generate()


func _generate() -> void:
	_sink_count = 0

	# A wrapped world has no map-edge outlets.
	_outlet_count = 0

	for grid_z in range(_depth):
		for grid_x in range(_width):
			_calculate_flow_for_cell(
				grid_x,
				grid_z
			)


func _calculate_flow_for_cell(
	grid_x: int,
	grid_z: int
) -> void:
	var index: int = _get_index(
		grid_x,
		grid_z
	)

	var current_height: float = (
		_height_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	var best_downstream: int = NO_FLOW
	var best_slope: float = 0.0

	for offset_z in range(-1, 2):
		for offset_x in range(-1, 2):
			if (
				offset_x == 0
				and offset_z == 0
			):
				continue

			# The playable world wraps.
			#
			# Walking off one horizontal edge continues directly
			# onto the opposite edge, so hydrology must do the same.
			var neighbor_x: int = _wrap_x(
				grid_x + offset_x
			)

			var neighbor_z: int = _wrap_z(
				grid_z + offset_z
			)

			# Defensive guard for extremely small grids where
			# wrapping could map a neighbor back onto this cell.
			if (
				neighbor_x == grid_x
				and neighbor_z == grid_z
			):
				continue

			var neighbor_height: float = (
				_height_field.get_height_at_grid(
					neighbor_x,
					neighbor_z
				)
			)

			var elevation_drop: float = (
				current_height
				- neighbor_height
			)

			if elevation_drop <= 0.0:
				continue

			var horizontal_distance: float = (
				_spacing_meters
			)

			if (
				offset_x != 0
				and offset_z != 0
			):
				horizontal_distance *= sqrt(2.0)

			var candidate_slope: float = (
				elevation_drop
				/ horizontal_distance
			)

			if candidate_slope > best_slope:
				best_slope = candidate_slope

				best_downstream = _get_index(
					neighbor_x,
					neighbor_z
				)

	if best_downstream != NO_FLOW:
		_downstream[index] = best_downstream
		_slope[index] = best_slope
		return

	# No lower neighbor means this is an actual sink.
	#
	# With the depression-resolved routing surface, these should
	# primarily occur in legitimate low areas such as the central
	# lake system rather than at arbitrary map boundaries.
	_downstream[index] = NO_FLOW
	_slope[index] = 0.0
	_sink_count += 1


func get_downstream_index(
	grid_x: int,
	grid_z: int
) -> int:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return NO_FLOW

	return _downstream[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_downstream_grid_position(
	grid_x: int,
	grid_z: int
) -> Vector2i:
	var downstream_index: int = (
		get_downstream_index(
			grid_x,
			grid_z
		)
	)

	if downstream_index < 0:
		return Vector2i(
			-1,
			-1
		)

	return _index_to_grid_position(
		downstream_index
	)


func get_flow_direction(
	grid_x: int,
	grid_z: int
) -> Vector2i:
	var downstream_position: Vector2i = (
		get_downstream_grid_position(
			grid_x,
			grid_z
		)
	)

	if downstream_position.x < 0:
		return Vector2i.ZERO

	# Return the local one-cell direction even when the downstream
	# cell lies across a wrapped world boundary.
	var delta_x: int = _get_wrapped_step_delta(
		grid_x,
		downstream_position.x,
		_width
	)

	var delta_z: int = _get_wrapped_step_delta(
		grid_z,
		downstream_position.y,
		_depth
	)

	return Vector2i(
		delta_x,
		delta_z
	)


func get_slope(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _slope[
		_get_index(
			grid_x,
			grid_z
		)
	]


func is_sink(
	grid_x: int,
	grid_z: int
) -> bool:
	return (
		get_downstream_index(
			grid_x,
			grid_z
		)
		== NO_FLOW
	)


func is_outlet(
	grid_x: int,
	grid_z: int
) -> bool:
	# Kept for compatibility.
	#
	# A wrapped world has no horizontal edge outlets.
	return (
		get_downstream_index(
			grid_x,
			grid_z
		)
		== OUTLET
	)


func get_sink_count() -> int:
	return _sink_count


func get_outlet_count() -> int:
	return _outlet_count


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


func _get_wrapped_step_delta(
	from_coordinate: int,
	to_coordinate: int,
	size: int
) -> int:
	var delta: int = (
		to_coordinate
		- from_coordinate
	)

	if size <= 1:
		return 0

	var half_size: float = (
		float(size)
		* 0.5
	)

	if float(delta) > half_size:
		delta -= size
	elif float(delta) < -half_size:
		delta += size

	return delta


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
