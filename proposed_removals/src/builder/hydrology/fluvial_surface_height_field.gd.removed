class_name FluvialSurfaceHeightField
extends RefCounted


const IncisionModel := preload(
	"res://src/builder/hydrology/channel_incision_model.gd"
)

const GeometryModel := preload(
	"res://src/builder/hydrology/channel_geometry_model.gd"
)


var _source_height_field

var _width: int = 0
var _depth: int = 0
var _spacing_meters: float = 1.0

var _heights: PackedFloat32Array
var _lowering: PackedFloat32Array

var _incision
var _geometry

var _modified_cell_count: int = 0

var _maximum_lowering: float = 0.0
var _maximum_lowering_index: int = -1


func setup(
	world_definition: WorldDefinition,
	stratigraphy: StratigraphyProfile,
	surface_field,
	flow_map,
	accumulation_map,
	channel_network
) -> void:
	_source_height_field = surface_field

	_width = _source_height_field.get_width()
	_depth = _source_height_field.get_depth()

	_spacing_meters = (
		_source_height_field.get_spacing_meters()
	)

	var cell_count: int = (
		_width * _depth
	)

	_heights.resize(cell_count)
	_lowering.resize(cell_count)

	_incision = IncisionModel.new()

	_incision.setup(
		world_definition,
		stratigraphy,
		surface_field,
		flow_map,
		accumulation_map,
		channel_network
	)

	_geometry = GeometryModel.new()

	_geometry.setup(
		world_definition,
		stratigraphy,
		surface_field,
		flow_map,
		accumulation_map,
		channel_network
	)

	_copy_source_surface()

	_apply_channel_network(
		channel_network
	)

	_calculate_statistics()


func _copy_source_surface() -> void:
	for grid_z in range(_depth):
		for grid_x in range(_width):
			var index: int = _get_index(
				grid_x,
				grid_z
			)

			var height: float = (
				_source_height_field.get_height_at_grid(
					grid_x,
					grid_z
				)
			)

			_heights[index] = height
			_lowering[index] = 0.0


func _apply_channel_network(
	channel_network
) -> void:
	for channel_z in range(_depth):
		for channel_x in range(_width):
			if not channel_network.is_channel(
				channel_x,
				channel_z
			):
				continue

			_apply_channel_cell(
				channel_x,
				channel_z
			)


func _apply_channel_cell(
	channel_x: int,
	channel_z: int
) -> void:
	var incision_depth: float = (
		_incision.get_incision_depth(
			channel_x,
			channel_z
		)
	)

	if incision_depth <= 0.0:
		return

	var bottom_half_width: float = (
		_geometry.get_channel_bottom_half_width(
			channel_x,
			channel_z
		)
	)

	var valley_half_width: float = (
		_geometry.get_valley_half_width(
			channel_x,
			channel_z
		)
	)

	if valley_half_width <= 0.0:
		return

	var profile_exponent: float = (
		_geometry.get_bank_profile_exponent(
			channel_x,
			channel_z
		)
	)

	var radius_cells: int = int(
		ceil(
			valley_half_width
			/ _spacing_meters
		)
	)

	for offset_z in range(
		-radius_cells,
		radius_cells + 1
	):
		for offset_x in range(
			-radius_cells,
			radius_cells + 1
		):
			# River valleys wrap with the world.
			var target_x: int = _wrap_x(
				channel_x + offset_x
			)

			var target_z: int = _wrap_z(
				channel_z + offset_z
			)

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

			if distance > valley_half_width:
				continue

			var influence: float = (
				_get_valley_influence(
					distance,
					bottom_half_width,
					valley_half_width,
					profile_exponent
				)
			)

			if influence <= 0.0:
				continue

			var carve_depth: float = (
				incision_depth
				* influence
			)

			_lower_target_cell(
				target_x,
				target_z,
				carve_depth
			)


func _get_valley_influence(
	distance: float,
	bottom_half_width: float,
	valley_half_width: float,
	profile_exponent: float
) -> float:
	if distance <= bottom_half_width:
		return 1.0

	var bank_width: float = (
		valley_half_width
		- bottom_half_width
	)

	if bank_width <= 0.0:
		return 0.0

	var normalized_distance: float = (
		(distance - bottom_half_width)
		/ bank_width
	)

	normalized_distance = clampf(
		normalized_distance,
		0.0,
		1.0
	)

	var remaining: float = (
		1.0 - normalized_distance
	)

	return pow(
		remaining,
		profile_exponent
	)


func _lower_target_cell(
	grid_x: int,
	grid_z: int,
	carve_depth: float
) -> void:
	var index: int = _get_index(
		grid_x,
		grid_z
	)

	var original_height: float = (
		_source_height_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	var candidate_height: float = (
		original_height
		- carve_depth
	)

	# Multiple nearby channel segments may influence
	# the same terrain cell.
	#
	# Keep the lowest resulting terrain instead of
	# repeatedly subtracting erosion.
	if candidate_height < _heights[index]:
		_heights[index] = candidate_height


func _calculate_statistics() -> void:
	_modified_cell_count = 0

	_maximum_lowering = 0.0
	_maximum_lowering_index = -1

	for grid_z in range(_depth):
		for grid_x in range(_width):
			var index: int = _get_index(
				grid_x,
				grid_z
			)

			var original_height: float = (
				_source_height_field.get_height_at_grid(
					grid_x,
					grid_z
				)
			)

			var final_height: float = (
				_heights[index]
			)

			var lowering: float = maxf(
				0.0,
				original_height - final_height
			)

			_lowering[index] = lowering

			if lowering > 0.001:
				_modified_cell_count += 1

			if lowering > _maximum_lowering:
				_maximum_lowering = lowering
				_maximum_lowering_index = index


func get_width() -> int:
	return _width


func get_depth() -> int:
	return _depth


func get_spacing_meters() -> float:
	return _spacing_meters


func get_height_at_grid(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _heights[
		_get_index(
			grid_x,
			grid_z
		)
	]


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


func get_lowering_at_grid(
	grid_x: int,
	grid_z: int
) -> float:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return 0.0

	return _lowering[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_world_position(
	grid_x: int,
	grid_z: int
) -> Vector2:
	return _source_height_field.get_world_position(
		grid_x,
		grid_z
	)


func get_modified_cell_count() -> int:
	return _modified_cell_count


func get_maximum_lowering() -> float:
	return _maximum_lowering


func get_maximum_lowering_grid_position() -> Vector2i:
	if _maximum_lowering_index < 0:
		return Vector2i(
			-1,
			-1
		)

	return _index_to_grid_position(
		_maximum_lowering_index
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
