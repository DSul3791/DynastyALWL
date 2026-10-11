class_name SurfaceHeightField
extends RefCounted


const GeologySamplerScript := preload(
	"res://src/builder/geology/deformed_geology_sampler.gd"
)

const ErosionModelScript := preload(
	"res://src/builder/terrain/erosion_model.gd"
)

const IslandCoastModelScript := preload(
	"res://src/builder/terrain/island_coast_model.gd"
)


# ==================================================
# POST-SWAP LOWLAND SEAM RECONCILIATION
# ==================================================

const SEAM_HALF_WIDTH_M: float = 240.0

const FULL_LEVEL_HEIGHT_M: float = 100.0
const NO_LEVEL_HEIGHT_M: float = 1200.0


var _world: WorldDefinition
var _geology_sampler: DeformedGeologySampler
var _erosion_model: ErosionModel
var _island_coast_model: IslandCoastModel


# The production builder uses an 8 meter planning grid.
#
# For the current 10,240 m world:
#
# 10240 / 8 = 1280
#
# giving us one unique 1280 x 1280 toroidal planning
# grid with no duplicated outer boundary row or column.
var _spacing_meters: float = 8.0

var _width: int = 0
var _depth: int = 0

var _min_x: float = 0.0
var _min_z: float = 0.0

var _heights: PackedFloat32Array


func setup(
	world_definition: WorldDefinition,
	stratigraphy: StratigraphyProfile,
	spacing_meters: float = 8.0
) -> void:
	_world = world_definition

	_spacing_meters = maxf(
		spacing_meters,
		1.0
	)

	_min_x = float(
		_world.get_min_x()
	)

	_min_z = float(
		_world.get_min_z()
	)

	var world_width_m: float = (
		float(
			_world.get_max_x()
		)
		- _min_x
	)

	var world_depth_m: float = (
		float(
			_world.get_max_z()
		)
		- _min_z
	)

	var width_cells_float: float = (
		world_width_m
		/ _spacing_meters
	)

	var depth_cells_float: float = (
		world_depth_m
		/ _spacing_meters
	)

	_width = int(
		round(
			width_cells_float
		)
	)

	_depth = int(
		round(
			depth_cells_float
		)
	)

	# A wrapped planning grid must divide the world
	# exactly. Otherwise the hydrology period would not
	# match the actual world period.
	var width_error: float = absf(
		float(_width)
			* _spacing_meters
			- world_width_m
	)

	var depth_error: float = absf(
		float(_depth)
			* _spacing_meters
			- world_depth_m
	)

	if (
		width_error > 0.001
		or depth_error > 0.001
	):
		push_error(
			(
				"SurfaceHeightField spacing %.3f m does not "
				+ "divide the %.3f x %.3f m world exactly."
			)
			% [
				_spacing_meters,
				world_width_m,
				world_depth_m
			]
		)

		_width = 0
		_depth = 0
		_heights = PackedFloat32Array()
		return

	if (
		_width <= 0
		or _depth <= 0
	):
		push_error(
			"SurfaceHeightField produced an invalid grid size."
		)
		return

	_geology_sampler = GeologySamplerScript.new()

	_geology_sampler.setup(
		world_definition,
		stratigraphy
	)

	_erosion_model = ErosionModelScript.new()

	_erosion_model.setup(
		world_definition,
		stratigraphy
	)

	_island_coast_model = IslandCoastModelScript.new()

	_island_coast_model.setup(
		world_definition
	)

	var cell_count: int = (
		_width * _depth
	)

	_heights = PackedFloat32Array()

	_heights.resize(
		cell_count
	)

	if (
		_heights.size()
		!= cell_count
	):
		push_error(
			(
				"SurfaceHeightField allocation failed. "
				+ "Expected %d cells but received %d."
			)
			% [
				cell_count,
				_heights.size()
			]
		)

		_width = 0
		_depth = 0
		_heights = PackedFloat32Array()
		return

	# Current finished-island sequence:
	#
	# 1. Island-local tectonic geology
	# 2. Broad geological erosion/weathering
	# 3. Coast, beach platform, continental slope,
	#    and abyssal edge
	#
	# There is deliberately NO central-lake carve.
	#
	# Lakes are discovered later from genuine terrain
	# depressions by the hydrology system.

	_generate_raw_surface()
	_apply_broad_erosion()
	_apply_island_coast()


# ==================================================
# RAW POST-SWAP SURFACE
# ==================================================

func _generate_raw_surface() -> void:
	for grid_z in range(
		_depth
	):
		for grid_x in range(
			_width
		):
			var world_x: float = (
				_min_x
				+ float(grid_x)
					* _spacing_meters
			)

			var world_z: float = (
				_min_z
				+ float(grid_z)
					* _spacing_meters
			)

			var height: float = (
				_geology_sampler.get_column_top_y(
					world_x,
					world_z
				)
			)

			_heights[
				_get_index(
					grid_x,
					grid_z
				)
			] = height


# ==================================================
# LOWLAND SEAM LEVELING
#
# The quadrant swap creates its internal joins at
# world X=0 and Z=0.
#
# With the 8 m grid, zero lies exactly on a grid
# sample. We therefore compare the samples immediately
# to either side of the seam and smoothly reconcile
# the surrounding low terrain.
# ==================================================

func _reconcile_lowland_seams() -> void:
	_reconcile_x_seam()
	_reconcile_z_seam()


func _reconcile_x_seam() -> void:
	if _width < 3:
		return

	var seam_x: int = int(
		round(
			(0.0 - _min_x)
			/ _spacing_meters
		)
	)

	if (
		seam_x < 0
		or seam_x >= _width
	):
		return

	var left_x: int = posmod(
		seam_x - 1,
		_width
	)

	var right_x: int = posmod(
		seam_x + 1,
		_width
	)

	for grid_z in range(
		_depth
	):
		var left_height: float = (
			get_height_at_grid(
				left_x,
				grid_z
			)
		)

		var right_height: float = (
			get_height_at_grid(
				right_x,
				grid_z
			)
		)

		# Low-low joins are fully reconciled.
		#
		# Mixed low/high joins such as mountain passes
		# and foothill saddles are partially reconciled.
		#
		# High-high mountain joins remain untouched and
		# can stay rugged.
		var seam_weight: float = (
			_get_leveling_weight(
				left_height
			)
			+ _get_leveling_weight(
				right_height
			)
		) * 0.5

		if seam_weight <= 0.0:
			continue

		var target_height: float = (
			(left_height + right_height)
			* 0.5
		)

		for grid_x in range(
			_width
		):
			var world_x: float = (
				_min_x
				+ float(grid_x)
					* _spacing_meters
			)

			var distance_from_seam: float = absf(
				world_x
			)

			if (
				distance_from_seam
				> SEAM_HALF_WIDTH_M
			):
				continue

			var index: int = _get_index(
				grid_x,
				grid_z
			)

			var current_height: float = (
				_heights[index]
			)

			var distance_weight: float = (
				1.0
				- _smoothstep01(
					distance_from_seam
					/ SEAM_HALF_WIDTH_M
				)
			)

			var correction: float

			if world_x < 0.0:
				correction = (
					target_height
					- left_height
				)

			elif world_x > 0.0:
				correction = (
					target_height
					- right_height
				)

			else:
				correction = (
					target_height
					- current_height
				)

			var final_weight: float = (
				seam_weight
				* distance_weight
			)

			_heights[index] = (
				current_height
				+ correction
					* final_weight
			)


func _reconcile_z_seam() -> void:
	if _depth < 3:
		return

	var seam_z: int = int(
		round(
			(0.0 - _min_z)
			/ _spacing_meters
		)
	)

	if (
		seam_z < 0
		or seam_z >= _depth
	):
		return

	var near_z: int = posmod(
		seam_z - 1,
		_depth
	)

	var far_z: int = posmod(
		seam_z + 1,
		_depth
	)

	for grid_x in range(
		_width
	):
		var near_height: float = (
			get_height_at_grid(
				grid_x,
				near_z
			)
		)

		var far_height: float = (
			get_height_at_grid(
				grid_x,
				far_z
			)
		)

		var seam_weight: float = (
			_get_leveling_weight(
				near_height
			)
			+ _get_leveling_weight(
				far_height
			)
		) * 0.5

		if seam_weight <= 0.0:
			continue

		var target_height: float = (
			(near_height + far_height)
			* 0.5
		)

		for grid_z in range(
			_depth
		):
			var world_z: float = (
				_min_z
				+ float(grid_z)
					* _spacing_meters
			)

			var distance_from_seam: float = absf(
				world_z
			)

			if (
				distance_from_seam
				> SEAM_HALF_WIDTH_M
			):
				continue

			var index: int = _get_index(
				grid_x,
				grid_z
			)

			var current_height: float = (
				_heights[index]
			)

			var distance_weight: float = (
				1.0
				- _smoothstep01(
					distance_from_seam
					/ SEAM_HALF_WIDTH_M
				)
			)

			var correction: float

			if world_z < 0.0:
				correction = (
					target_height
					- near_height
				)

			elif world_z > 0.0:
				correction = (
					target_height
					- far_height
				)

			else:
				correction = (
					target_height
					- current_height
				)

			var final_weight: float = (
				seam_weight
					* distance_weight
			)

			_heights[index] = (
				current_height
					+ correction
						* final_weight
			)


func _get_leveling_weight(
	height: float
) -> float:
	if height <= FULL_LEVEL_HEIGHT_M:
		return 1.0

	if height >= NO_LEVEL_HEIGHT_M:
		return 0.0

	var normalized_height: float = (
		(height - FULL_LEVEL_HEIGHT_M)
		/ (
			NO_LEVEL_HEIGHT_M
				- FULL_LEVEL_HEIGHT_M
		)
	)

	return (
		1.0
			- _smoothstep01(
				normalized_height
			)
	)


# ==================================================
# BROAD EROSION / WEATHERING
# ==================================================

func _apply_broad_erosion() -> void:
	if _erosion_model == null:
		return

	for grid_z in range(
		_depth
	):
		for grid_x in range(
			_width
		):
			var index: int = (
				_get_index(
					grid_x,
					grid_z
				)
			)

			var world_x: float = (
				_min_x
					+ float(grid_x)
						* _spacing_meters
			)

			var world_z: float = (
				_min_z
					+ float(grid_z)
						* _spacing_meters
			)

			var current_height: float = (
				_heights[index]
			)

			_heights[index] = (
				_erosion_model
					.get_eroded_surface_y_from_height(
						world_x,
						world_z,
						current_height
					)
			)


# ==================================================
# MODULAR ISLAND COAST
# ==================================================

func _apply_island_coast() -> void:
	if _island_coast_model == null:
		return

	for grid_z in range(
		_depth
	):
		for grid_x in range(
			_width
		):
			var index: int = (
				_get_index(
					grid_x,
					grid_z
				)
			)

			var world_x: float = (
				_min_x
					+ float(grid_x)
						* _spacing_meters
			)

			var world_z: float = (
				_min_z
					+ float(grid_z)
						* _spacing_meters
			)

			_heights[index] = (
				_island_coast_model
					.get_shaped_height(
						world_x,
						world_z,
						_heights[index]
					)
			)


func _smoothstep01(
	value: float
) -> float:
	var clamped: float = clampf(
		value,
		0.0,
		1.0
	)

	return (
		clamped
			* clamped
			* (
				3.0
					- 2.0 * clamped
			)
	)


# ==================================================
# PUBLIC HEIGHT-FIELD INTERFACE
#
# IMPORTANT:
#
# This grid contains UNIQUE toroidal samples.
#
# For the current 10,240 m world at 8 m spacing:
#
# width  = 1280
# depth  = 1280
#
# The positive outer boundary is the same wrapped
# location as the negative boundary and therefore
# is deliberately not stored a second time.
# ==================================================

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

	var index: int = (
		_get_index(
			grid_x,
			grid_z
		)
	)

	# This should never occur if _width, _depth and
	# _heights remain synchronized. Keeping this guard
	# prevents a malformed field from flooding Godot
	# with millions of array exceptions.
	if (
		index < 0
		or index >= _heights.size()
	):
		return 0.0

	return _heights[
		index
	]


func get_world_position(
	grid_x: int,
	grid_z: int
) -> Vector2:
	return Vector2(
		_min_x
			+ float(grid_x)
				* _spacing_meters,

		_min_z
			+ float(grid_z)
				* _spacing_meters
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


func get_minimum_height() -> float:
	if _heights.is_empty():
		return 0.0

	var minimum_height: float = (
		_heights[0]
	)

	for height in _heights:
		minimum_height = minf(
			minimum_height,
			height
		)

	return minimum_height


func get_maximum_height() -> float:
	if _heights.is_empty():
		return 0.0

	var maximum_height: float = (
		_heights[0]
	)

	for height in _heights:
		maximum_height = maxf(
			maximum_height,
			height
		)

	return maximum_height


func _get_index(
	grid_x: int,
	grid_z: int
) -> int:
	return (
		grid_z * _width
			+ grid_x
	)
