class_name CentralLakeBasin
extends RefCounted


const INV_SQRT_2: float = 0.7071067811865476


# ==================================================
# BROAD LAKE BASIN
# ==================================================

const BASIN_HALF_LENGTH_M: float = 800.0
const BASIN_HALF_WIDTH_M: float = 325.0

const BASIN_MAX_DEPTH_M: float = 220.0


# ==================================================
# DEEP TRENCH
# ==================================================

const TRENCH_HALF_LENGTH_M: float = 520.0
const TRENCH_BASE_HALF_WIDTH_M: float = 95.0

const TRENCH_EXTRA_DEPTH_M: float = 720.0

const TRENCH_LONG_OFFSET_M: float = 90.0
const TRENCH_CROSS_OFFSET_M: float = -35.0


var _world_definition = null

var _shore_macro_noise := FastNoiseLite.new()
var _shore_detail_noise := FastNoiseLite.new()

var _trench_wander_noise := FastNoiseLite.new()
var _trench_detail_noise := FastNoiseLite.new()


func setup(
	world_definition
) -> void:
	_world_definition = world_definition

	var world_seed: int = int(
		_world_definition.world_seed
	)

	# --------------------------------------------------
	# LARGE SHORELINE DISTORTION
	#
	# Hundreds-of-metres scale.
	# --------------------------------------------------

	_shore_macro_noise.seed = (
		world_seed + 17101
	)

	_shore_macro_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_shore_macro_noise.frequency = 0.0016

	# --------------------------------------------------
	# SMALLER SHORELINE DETAIL
	#
	# Adds coves, points and irregular banks without
	# making the lake edge noisy at voxel scale.
	# --------------------------------------------------

	_shore_detail_noise.seed = (
		world_seed + 17102
	)

	_shore_detail_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_shore_detail_noise.frequency = 0.0048

	# --------------------------------------------------
	# TRENCH CENTERLINE WANDER
	# --------------------------------------------------

	_trench_wander_noise.seed = (
		world_seed + 17103
	)

	_trench_wander_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_trench_wander_noise.frequency = 0.0022

	# --------------------------------------------------
	# TRENCH WIDTH / DEPTH DETAIL
	# --------------------------------------------------

	_trench_detail_noise.seed = (
		world_seed + 17104
	)

	_trench_detail_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_trench_detail_noise.frequency = 0.0060


# ==================================================
# TERRAIN CARVE
# ==================================================

func get_carved_height(
	world_x: float,
	world_z: float,
	original_height: float
) -> float:
	# Rotated coordinates.
	#
	# This preserves the same diagonal orientation as
	# the previous lake.
	var long_axis: float = (
		(world_x - world_z)
		* INV_SQRT_2
	)

	var cross_axis: float = (
		(world_x + world_z)
		* INV_SQRT_2
	)

	# ==================================================
	# NATURALIZE THE BROAD BASIN
	# ==================================================

	var macro_a: float = (
		_shore_macro_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var macro_b: float = (
		_shore_macro_noise.get_noise_2d(
			world_x + 1377.0,
			world_z - 891.0
		)
	)

	var detail_a: float = (
		_shore_detail_noise.get_noise_2d(
			world_x,
			world_z
		)
	)

	var detail_b: float = (
		_shore_detail_noise.get_noise_2d(
			world_x - 733.0,
			world_z + 1149.0
		)
	)

	# Instead of testing a perfect ellipse, bend the
	# coordinate field itself.
	var warped_long: float = (
		long_axis
		+ macro_a * 52.0
		+ detail_a * 18.0
	)

	var warped_cross: float = (
		cross_axis
		+ macro_b * 72.0
		+ detail_b * 24.0
	)

	# Make the two ends somewhat different in width.
	# One end broadens into a larger basin while the
	# other necks down.
	var normalized_long: float = clampf(
		(
			warped_long
			/ BASIN_HALF_LENGTH_M
			+ 1.0
		)
		* 0.5,
		0.0,
		1.0
	)

	var end_asymmetry: float = lerpf(
		0.84,
		1.12,
		_smoothstep01(
			normalized_long
		)
	)

	var width_noise_factor: float = (
		1.0
		+ macro_b * 0.16
		+ detail_a * 0.06
	)

	var effective_half_width: float = (
		BASIN_HALF_WIDTH_M
		* end_asymmetry
		* width_noise_factor
	)

	effective_half_width = clampf(
		effective_half_width,
		230.0,
		410.0
	)

	var effective_half_length: float = (
		BASIN_HALF_LENGTH_M
		* (
			1.0
			+ macro_a * 0.045
		)
	)

	effective_half_length = clampf(
		effective_half_length,
		740.0,
		860.0
	)

	var long_normalized: float = (
		warped_long
		/ effective_half_length
	)

	var cross_normalized: float = (
		warped_cross
		/ effective_half_width
	)

	var basin_radius: float = sqrt(
		long_normalized * long_normalized
		+ cross_normalized * cross_normalized
	)

	var basin_shape: float = (
		1.0
		- _smoothstep(
			0.58,
			1.0,
			basin_radius
		)
	)

	if basin_shape <= 0.0:
		return original_height

	# Depth varies gradually across the lake floor.
	var broad_depth_factor: float = (
		0.88
		+ macro_a * 0.10
		+ detail_b * 0.04
	)

	broad_depth_factor = clampf(
		broad_depth_factor,
		0.72,
		1.08
	)

	var broad_depth: float = (
		BASIN_MAX_DEPTH_M
		* basin_shape
		* broad_depth_factor
	)

	# ==================================================
	# MEANDERING DEEP TRENCH
	# ==================================================

	var trench_long: float = (
		long_axis
		- TRENCH_LONG_OFFSET_M
	)

	var trench_long_normalized: float = (
		absf(trench_long)
		/ TRENCH_HALF_LENGTH_M
	)

	var trench_depth: float = 0.0

	if trench_long_normalized < 1.0:
		var wander_noise: float = (
			_trench_wander_noise.get_noise_2d(
				world_x,
				world_z
			)
		)

		var trench_detail: float = (
			_trench_detail_noise.get_noise_2d(
				world_x,
				world_z
			)
		)

		# Broad sine bend plus geological noise makes
		# the centerline wander rather than cutting a
		# ruler-straight slash through the lake.
		var centerline_wander: float = (
			sin(
				(trench_long + 80.0)
				* 0.0105
			)
			* 42.0
			+ wander_noise * 62.0
			+ trench_detail * 15.0
		)

		var trench_center_cross: float = (
			TRENCH_CROSS_OFFSET_M
			+ centerline_wander
		)

		var trench_cross_distance: float = absf(
			cross_axis
			- trench_center_cross
		)

		# The trench narrows and widens along its course.
		var trench_width_factor: float = (
			0.86
			+ wander_noise * 0.16
			+ trench_detail * 0.10
		)

		trench_width_factor = clampf(
			trench_width_factor,
			0.62,
			1.18
		)

		var trench_half_width: float = (
			TRENCH_BASE_HALF_WIDTH_M
			* trench_width_factor
		)

		var trench_cross_normalized: float = (
			trench_cross_distance
			/ trench_half_width
		)

		var along_shape: float = (
			1.0
			- _smoothstep(
				0.68,
				1.0,
				trench_long_normalized
			)
		)

		var across_shape: float = (
			1.0
			- _smoothstep(
				0.18,
				1.0,
				trench_cross_normalized
			)
		)

		var trench_shape: float = (
			along_shape
			* across_shape
		)

		# Create irregular deep pockets instead of one
		# trench with exactly the same depth everywhere.
		var depth_pockets: float = (
			0.88
			+ wander_noise * 0.11
			+ trench_detail * 0.12
			+ sin(
				trench_long * 0.018
			) * 0.06
		)

		depth_pockets = clampf(
			depth_pockets,
			0.68,
			1.12
		)

		trench_depth = (
			TRENCH_EXTRA_DEPTH_M
			* trench_shape
			* depth_pockets
		)

	return (
		original_height
		- broad_depth
		- trench_depth
	)


# ==================================================
# HELPERS
# ==================================================

func _smoothstep(
	edge_start: float,
	edge_end: float,
	value: float
) -> float:
	if edge_end <= edge_start:
		return 0.0

	var normalized: float = clampf(
		(
			value - edge_start
		)
		/ (
			edge_end - edge_start
		),
		0.0,
		1.0
	)

	return (
		normalized
		* normalized
		* (
			3.0
			- 2.0 * normalized
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
