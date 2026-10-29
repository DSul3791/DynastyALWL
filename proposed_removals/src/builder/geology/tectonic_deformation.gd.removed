class_name TectonicDeformation
extends RefCounted


# ==================================================
# SCALABLE TECTONIC MOUNTAIN SYSTEM
#
# This system builds a mountain range from a series
# of localized uplift masses rather than applying one
# giant elliptical mountain province.
#
# The number of major mountain masses scales with the
# available island size.
#
# Each major mass has:
#
# - a broad uplift foundation
# - a primary summit
# - a secondary shoulder summit
#
# Neighboring masses are connected by finite curved
# ridges, while broad valleys are cut between them.
#
# There is deliberately NO global province clipping
# ellipse. That avoids the large diagonal boundary
# visible in previous previews.
# ==================================================


const INV_SQRT_2: float = 0.7071067811865476


# ==================================================
# GENERAL TERRAIN
# ==================================================

const PLAIN_BASE_ELEVATION_M: float = 35.0


# ==================================================
# MOUNTAIN RANGE SCALE
# ==================================================

const MAJOR_MOUNTAIN_SPACING_M: float = 1850.0

const MIN_MAJOR_MASSES: int = 2
const MAX_MAJOR_MASSES: int = 10

const RANGE_LENGTH_FRACTION: float = 0.72
const RANGE_CENTER_SPREAD_FRACTION: float = 0.18


# ==================================================
# MAJOR MOUNTAIN MASSES
# ==================================================

const MASS_BASE_UPLIFT_MIN_M: float = 400.0
const MASS_BASE_UPLIFT_MAX_M: float = 700.0

const MASS_PEAK_UPLIFT_MIN_M: float = 420.0
const MASS_PEAK_UPLIFT_MAX_M: float = 760.0

const MASS_LONG_RADIUS_MIN_FACTOR: float = 0.62
const MASS_LONG_RADIUS_MAX_FACTOR: float = 0.92

const MASS_CROSS_RADIUS_MIN_FACTOR: float = 0.46
const MASS_CROSS_RADIUS_MAX_FACTOR: float = 0.72


# Broad foundation under each mountain group.
const MASS_BASE_LONG_SCALE: float = 1.58
const MASS_BASE_CROSS_SCALE: float = 1.48


# Main summit inside each mountain group.
const MAIN_SUMMIT_LONG_SCALE: float = 0.62
const MAIN_SUMMIT_CROSS_SCALE: float = 0.58


# Secondary summit / shoulder.
const SHOULDER_SUMMIT_LONG_SCALE: float = 0.48
const SHOULDER_SUMMIT_CROSS_SCALE: float = 0.44

const SHOULDER_HEIGHT_MIN_FACTOR: float = 0.30
const SHOULDER_HEIGHT_MAX_FACTOR: float = 0.50


# Allow each mountain mass to rotate slightly instead
# of lining up as perfect ellipses.
const MASS_ROTATION_MAX_RADIANS: float = 0.30


# Local shape distortion.
const MASS_EDGE_WARP_A: float = 0.16
const MASS_EDGE_WARP_B: float = 0.07


# ==================================================
# RIDGE CONNECTORS
# ==================================================

const CONNECTOR_UPLIFT_MIN_M: float = 85.0
const CONNECTOR_UPLIFT_MAX_M: float = 155.0

const CONNECTOR_WIDTH_MIN_FACTOR: float = 0.30
const CONNECTOR_WIDTH_MAX_FACTOR: float = 0.46

const CONNECTOR_BEND_MAX_M: float = 260.0


# ==================================================
# VALLEYS BETWEEN MOUNTAIN GROUPS
# ==================================================

const INTERMASS_VALLEY_DEPTH_MIN_M: float = 120.0
const INTERMASS_VALLEY_DEPTH_MAX_M: float = 250.0

const INTERMASS_VALLEY_LONG_RADIUS_MIN_FACTOR: float = 0.30
const INTERMASS_VALLEY_LONG_RADIUS_MAX_FACTOR: float = 0.43

const INTERMASS_VALLEY_CROSS_RADIUS_MIN_FACTOR: float = 0.42
const INTERMASS_VALLEY_CROSS_RADIUS_MAX_FACTOR: float = 0.62

const INTERMASS_VALLEY_SIDE_OFFSET_FACTOR: float = 0.38


# ==================================================
# SECONDARY TERRAIN DETAIL
# ==================================================

const SECONDARY_RIDGE_AMPLITUDE_M: float = 165.0
const SPUR_AMPLITUDE_M: float = 95.0
const SADDLE_MAX_DEPTH_M: float = 105.0
const FOOTHILL_DETAIL_AMPLITUDE_M: float = 48.0


# ==================================================
# WORLD
# ==================================================

var _world: WorldDefinition


# ==================================================
# RANGE GEOMETRY
# ==================================================

var _range_length_m: float = 1.0

var _mass_long := PackedFloat64Array()
var _mass_cross := PackedFloat64Array()

var _mass_long_radius := PackedFloat64Array()
var _mass_cross_radius := PackedFloat64Array()

var _mass_base_height := PackedFloat64Array()
var _mass_peak_height := PackedFloat64Array()

var _mass_cos_rotation := PackedFloat64Array()
var _mass_sin_rotation := PackedFloat64Array()

var _summit_long := PackedFloat64Array()
var _summit_cross := PackedFloat64Array()

var _shoulder_long := PackedFloat64Array()
var _shoulder_cross := PackedFloat64Array()
var _shoulder_height_factor := PackedFloat64Array()


# ==================================================
# CONNECTORS
# ==================================================

var _connector_width := PackedFloat64Array()
var _connector_height := PackedFloat64Array()
var _connector_bend := PackedFloat64Array()


# ==================================================
# VALLEYS
# ==================================================

var _valley_long := PackedFloat64Array()
var _valley_cross := PackedFloat64Array()

var _valley_long_radius := PackedFloat64Array()
var _valley_cross_radius := PackedFloat64Array()

var _valley_depth := PackedFloat64Array()

var _valley_cos_rotation := PackedFloat64Array()
var _valley_sin_rotation := PackedFloat64Array()


# ==================================================
# NOISE
# ==================================================

var _regional_noise: FastNoiseLite
var _plain_detail_noise: FastNoiseLite

var _mass_shape_noise_a: FastNoiseLite
var _mass_shape_noise_b: FastNoiseLite

var _connector_shape_noise: FastNoiseLite

var _secondary_ridge_noise_a: FastNoiseLite
var _secondary_ridge_noise_b: FastNoiseLite

var _spur_noise: FastNoiseLite
var _saddle_noise: FastNoiseLite


# ==================================================
# SETUP
# ==================================================

func setup(
	world_definition: WorldDefinition
) -> void:
	_world = world_definition

	_regional_noise = FastNoiseLite.new()

	_regional_noise.seed = (
		_world.world_seed
		+ 3101
	)

	_regional_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_regional_noise.frequency = 0.00075


	_plain_detail_noise = FastNoiseLite.new()

	_plain_detail_noise.seed = (
		_world.world_seed
		+ 3102
	)

	_plain_detail_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_plain_detail_noise.frequency = 0.0030


	_mass_shape_noise_a = FastNoiseLite.new()

	_mass_shape_noise_a.seed = (
		_world.world_seed
		+ 3103
	)

	_mass_shape_noise_a.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_mass_shape_noise_a.frequency = 0.00062


	_mass_shape_noise_b = FastNoiseLite.new()

	_mass_shape_noise_b.seed = (
		_world.world_seed
		+ 3104
	)

	_mass_shape_noise_b.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_mass_shape_noise_b.frequency = 0.00105


	_connector_shape_noise = FastNoiseLite.new()

	_connector_shape_noise.seed = (
		_world.world_seed
		+ 3105
	)

	_connector_shape_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_connector_shape_noise.frequency = 0.00090


	_secondary_ridge_noise_a = FastNoiseLite.new()

	_secondary_ridge_noise_a.seed = (
		_world.world_seed
		+ 3111
	)

	_secondary_ridge_noise_a.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_secondary_ridge_noise_a.frequency = 0.00155


	_secondary_ridge_noise_b = FastNoiseLite.new()

	_secondary_ridge_noise_b.seed = (
		_world.world_seed
		+ 3112
	)

	_secondary_ridge_noise_b.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_secondary_ridge_noise_b.frequency = 0.00215


	_spur_noise = FastNoiseLite.new()

	_spur_noise.seed = (
		_world.world_seed
		+ 3113
	)

	_spur_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_spur_noise.frequency = 0.0035


	_saddle_noise = FastNoiseLite.new()

	_saddle_noise.seed = (
		_world.world_seed
		+ 3114
	)

	_saddle_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_saddle_noise.frequency = 0.00135

	_configure_scaled_mountain_system()


# ==================================================
# PRECOMPUTE MOUNTAIN SYSTEM
# ==================================================

func _configure_scaled_mountain_system() -> void:
	var island_span: float = maxf(
		1.0,
		minf(
			float(
				_world.size_x_meters
			),
			float(
				_world.size_z_meters
			)
		)
	)

	_range_length_m = (
		island_span
		* RANGE_LENGTH_FRACTION
	)

	var structural_length: float = (
		_range_length_m
	)

	var mass_count: int = clampi(
		int(
			round(
				structural_length
				/ MAJOR_MOUNTAIN_SPACING_M
			)
		),
		MIN_MAJOR_MASSES,
		MAX_MAJOR_MASSES
	)

	_mass_long.resize(
		mass_count
	)

	_mass_cross.resize(
		mass_count
	)

	_mass_long_radius.resize(
		mass_count
	)

	_mass_cross_radius.resize(
		mass_count
	)

	_mass_base_height.resize(
		mass_count
	)

	_mass_peak_height.resize(
		mass_count
	)

	_mass_cos_rotation.resize(
		mass_count
	)

	_mass_sin_rotation.resize(
		mass_count
	)

	_summit_long.resize(
		mass_count
	)

	_summit_cross.resize(
		mass_count
	)

	_shoulder_long.resize(
		mass_count
	)

	_shoulder_cross.resize(
		mass_count
	)

	_shoulder_height_factor.resize(
		mass_count
	)

	var nominal_spacing: float = (
		structural_length
		/ float(
			mass_count
		)
	)

	var first_position: float = (
		-0.5
		* structural_length
		+ nominal_spacing
			* 0.5
	)

	var center_spread: float = (
		island_span
		* RANGE_CENTER_SPREAD_FRACTION
		* 0.5
	)

	for i in range(
		mass_count
	):
		var spacing_jitter: float = (
			_hash01(
				i,
				101
			)
			- 0.5
		) * nominal_spacing * 0.30

		var cross_jitter: float = (
			_hash01(
				i,
				102
			)
			- 0.5
		) * center_spread * 2.0

		_mass_long[i] = (
			first_position
			+ float(i)
				* nominal_spacing
			+ spacing_jitter
		)

		_mass_cross[i] = (
			cross_jitter
		)

		_mass_long_radius[i] = (
			nominal_spacing
			* lerpf(
				MASS_LONG_RADIUS_MIN_FACTOR,
				MASS_LONG_RADIUS_MAX_FACTOR,
				_hash01(
					i,
					103
				)
			)
		)

		_mass_cross_radius[i] = (
			nominal_spacing
			* lerpf(
				MASS_CROSS_RADIUS_MIN_FACTOR,
				MASS_CROSS_RADIUS_MAX_FACTOR,
				_hash01(
					i,
					104
				)
			)
		)

		_mass_base_height[i] = lerpf(
			MASS_BASE_UPLIFT_MIN_M,
			MASS_BASE_UPLIFT_MAX_M,
			_hash01(
				i,
				105
			)
		)

		_mass_peak_height[i] = lerpf(
			MASS_PEAK_UPLIFT_MIN_M,
			MASS_PEAK_UPLIFT_MAX_M,
			_hash01(
				i,
				106
			)
		)

		var rotation: float = (
			(
				_hash01(
					i,
					107
				)
				- 0.5
			)
			* 2.0
			* MASS_ROTATION_MAX_RADIANS
		)

		_mass_cos_rotation[i] = cos(
			rotation
		)

		_mass_sin_rotation[i] = sin(
			rotation
		)

		var summit_long_offset: float = (
			(
				_hash01(
					i,
					108
				)
				- 0.5
			)
			* _mass_long_radius[i]
			* 0.48
		)

		var summit_cross_offset: float = (
			(
				_hash01(
					i,
					109
				)
				- 0.5
			)
			* _mass_cross_radius[i]
			* 0.52
		)

		_summit_long[i] = (
			_mass_long[i]
			+ summit_long_offset
		)

		_summit_cross[i] = (
			_mass_cross[i]
			+ summit_cross_offset
		)

		var shoulder_side: float = 1.0

		if (
			_hash01(
				i,
				110
			)
			< 0.5
		):
			shoulder_side = -1.0

		_shoulder_long[i] = (
			_mass_long[i]
			- summit_long_offset
				* 0.55
			+ (
				_hash01(
					i,
					111
				)
				- 0.5
			)
			* _mass_long_radius[i]
			* 0.22
		)

		_shoulder_cross[i] = (
			_mass_cross[i]
			+ shoulder_side
				* _mass_cross_radius[i]
				* lerpf(
					0.24,
					0.46,
					_hash01(
						i,
						112
					)
				)
		)

		_shoulder_height_factor[i] = lerpf(
			SHOULDER_HEIGHT_MIN_FACTOR,
			SHOULDER_HEIGHT_MAX_FACTOR,
			_hash01(
				i,
				113
			)
		)

	_configure_connectors_and_valleys(
		nominal_spacing
	)


func _configure_connectors_and_valleys(
	nominal_spacing: float
) -> void:
	var pair_count: int = maxi(
		0,
		_mass_long.size()
		- 1
	)

	_connector_width.resize(
		pair_count
	)

	_connector_height.resize(
		pair_count
	)

	_connector_bend.resize(
		pair_count
	)

	_valley_long.resize(
		pair_count
	)

	_valley_cross.resize(
		pair_count
	)

	_valley_long_radius.resize(
		pair_count
	)

	_valley_cross_radius.resize(
		pair_count
	)

	_valley_depth.resize(
		pair_count
	)

	_valley_cos_rotation.resize(
		pair_count
	)

	_valley_sin_rotation.resize(
		pair_count
	)

	for i in range(
		pair_count
	):
		_connector_width[i] = (
			nominal_spacing
			* lerpf(
				CONNECTOR_WIDTH_MIN_FACTOR,
				CONNECTOR_WIDTH_MAX_FACTOR,
				_hash01(
					i,
					201
				)
			)
		)

		_connector_height[i] = lerpf(
			CONNECTOR_UPLIFT_MIN_M,
			CONNECTOR_UPLIFT_MAX_M,
			_hash01(
				i,
				202
			)
		)

		_connector_bend[i] = (
			(
				_hash01(
					i,
					203
				)
				- 0.5
			)
			* 2.0
			* CONNECTOR_BEND_MAX_M
		)

		var midpoint_long: float = (
			(
				_mass_long[i]
				+ _mass_long[
					i + 1
				]
			)
			* 0.5
		)

		var midpoint_cross: float = (
			(
				_mass_cross[i]
				+ _mass_cross[
					i + 1
				]
			)
			* 0.5
		)

		var valley_side: float = 1.0

		if (
			_hash01(
				i,
				204
			)
			< 0.5
		):
			valley_side = -1.0

		var average_cross_radius: float = (
			(
				_mass_cross_radius[i]
				+ _mass_cross_radius[
					i + 1
				]
			)
			* 0.5
		)

		_valley_long[i] = (
			midpoint_long
			+ (
				_hash01(
					i,
					205
				)
				- 0.5
			)
			* nominal_spacing
			* 0.18
		)

		_valley_cross[i] = (
			midpoint_cross
			+ valley_side
				* average_cross_radius
				* INTERMASS_VALLEY_SIDE_OFFSET_FACTOR
		)

		_valley_long_radius[i] = (
			nominal_spacing
			* lerpf(
				INTERMASS_VALLEY_LONG_RADIUS_MIN_FACTOR,
				INTERMASS_VALLEY_LONG_RADIUS_MAX_FACTOR,
				_hash01(
					i,
					206
				)
			)
		)

		_valley_cross_radius[i] = (
			average_cross_radius
			* lerpf(
				INTERMASS_VALLEY_CROSS_RADIUS_MIN_FACTOR,
				INTERMASS_VALLEY_CROSS_RADIUS_MAX_FACTOR,
				_hash01(
					i,
					207
				)
			)
		)

		_valley_depth[i] = lerpf(
			INTERMASS_VALLEY_DEPTH_MIN_M,
			INTERMASS_VALLEY_DEPTH_MAX_M,
			_hash01(
				i,
				208
			)
		)

		var valley_rotation: float = (
			(
				_hash01(
					i,
					209
				)
				- 0.5
			)
			* 0.55
		)

		_valley_cos_rotation[i] = cos(
			valley_rotation
		)

		_valley_sin_rotation[i] = sin(
			valley_rotation
		)


# ==================================================
# PUBLIC INTERFACE
# ==================================================

func get_vertical_displacement(
	x: float,
	z: float
) -> float:
	if _world == null:
		return 0.0

	return (
		_get_regional_uplift(
			x,
			z
		)
		+ _get_mountain_belt_uplift(
			x,
			z
		)
	)


func get_deformed_column_top(
	x: float,
	z: float,
	original_top_y: float
) -> float:
	return (
		original_top_y
		+ get_vertical_displacement(
			x,
			z
		)
	)


# ==================================================
# REGIONAL TERRAIN
# ==================================================

func _get_regional_uplift(
	x: float,
	z: float
) -> float:
	var broad_roll: float = (
		_regional_noise.get_noise_2d(
			x,
			z
		)
		* 14.0
	)

	var local_roll: float = (
		_plain_detail_noise.get_noise_2d(
			x,
			z
		)
		* 6.0
	)

	return (
		PLAIN_BASE_ELEVATION_M
		+ broad_roll
		+ local_roll
	)


# ==================================================
# MOUNTAIN BELT
# ==================================================

func _get_mountain_belt_uplift(
	x: float,
	z: float
) -> float:
	var long_axis: float = (
		(x + z)
		* INV_SQRT_2
	)

	var cross_axis: float = (
		(x - z)
		* INV_SQRT_2
	)

	# Only three large-scale shape noise samples are
	# needed for the whole column. These are reused by
	# every mountain mass.

	var shape_a: float = (
		_mass_shape_noise_a.get_noise_2d(
			x,
			z
		)
	)

	var shape_b: float = (
		_mass_shape_noise_b.get_noise_2d(
			x,
			z
		)
	)

	var connector_shape: float = (
		_connector_shape_noise.get_noise_2d(
			x,
			z
		)
	)

	var broad_base_uplift: float = 0.0
	var summit_uplift: float = 0.0
	var shoulder_uplift: float = 0.0

	var mountain_core_weight: float = 0.0
	var mountain_halo_weight: float = 0.0

	for i in range(
		_mass_long.size()
	):
		var base_influence: float = (
			_get_ellipse_influence(
				long_axis,
				cross_axis,
				_mass_long[i],
				_mass_cross[i],
				_mass_long_radius[i]
					* MASS_BASE_LONG_SCALE,
				_mass_cross_radius[i]
					* MASS_BASE_CROSS_SCALE,
				_mass_cos_rotation[i],
				_mass_sin_rotation[i],
				shape_a,
				shape_b
			)
		)

		var core_influence: float = (
			_get_ellipse_influence(
				long_axis,
				cross_axis,
				_mass_long[i],
				_mass_cross[i],
				_mass_long_radius[i],
				_mass_cross_radius[i],
				_mass_cos_rotation[i],
				_mass_sin_rotation[i],
				shape_a,
				shape_b
			)
		)

		var main_peak_influence: float = (
			_get_ellipse_influence(
				long_axis,
				cross_axis,
				_summit_long[i],
				_summit_cross[i],
				_mass_long_radius[i]
					* MAIN_SUMMIT_LONG_SCALE,
				_mass_cross_radius[i]
					* MAIN_SUMMIT_CROSS_SCALE,
				_mass_cos_rotation[i],
				_mass_sin_rotation[i],
				shape_a,
				shape_b
			)
		)

		var shoulder_peak_influence: float = (
			_get_ellipse_influence(
				long_axis,
				cross_axis,
				_shoulder_long[i],
				_shoulder_cross[i],
				_mass_long_radius[i]
					* SHOULDER_SUMMIT_LONG_SCALE,
				_mass_cross_radius[i]
					* SHOULDER_SUMMIT_CROSS_SCALE,
				_mass_cos_rotation[i],
				_mass_sin_rotation[i],
				shape_a,
				shape_b
			)
		)

		# Max blending prevents overlapping mountain
		# foundations from becoming one enormous dome.

		broad_base_uplift = maxf(
			broad_base_uplift,
			base_influence
				* _mass_base_height[i]
		)

		summit_uplift = maxf(
			summit_uplift,
			main_peak_influence
				* _mass_peak_height[i]
		)

		shoulder_uplift = maxf(
			shoulder_uplift,
			shoulder_peak_influence
				* _mass_peak_height[i]
				* _shoulder_height_factor[i]
		)

		mountain_core_weight = maxf(
			mountain_core_weight,
			core_influence
		)

		mountain_halo_weight = maxf(
			mountain_halo_weight,
			base_influence
		)

	# --------------------------------------------------
	# FINITE CONNECTING RIDGES
	# --------------------------------------------------

	var connector_uplift: float = 0.0
	var connector_weight: float = 0.0

	for i in range(
		_connector_height.size()
	):
		var connector_influence: float = (
			_get_connector_influence(
				long_axis,
				cross_axis,
				i,
				connector_shape
			)
		)

		connector_uplift = maxf(
			connector_uplift,
			connector_influence
				* _connector_height[i]
		)

		connector_weight = maxf(
			connector_weight,
			connector_influence
		)

	# --------------------------------------------------
	# BROAD VALLEYS
	# --------------------------------------------------

	var valley_cut: float = 0.0

	for i in range(
		_valley_depth.size()
	):
		var valley_influence: float = (
			_get_ellipse_influence(
				long_axis,
				cross_axis,
				_valley_long[i],
				_valley_cross[i],
				_valley_long_radius[i],
				_valley_cross_radius[i],
				_valley_cos_rotation[i],
				_valley_sin_rotation[i],
				shape_a,
				shape_b
			)
		)

		valley_cut = maxf(
			valley_cut,
			valley_influence
				* _valley_depth[i]
		)

	# --------------------------------------------------
	# SECONDARY RIDGES / SPURS / SADDLES
	# --------------------------------------------------

	var secondary_relief: float = (
		_get_secondary_relief(
			x,
			z,
			long_axis,
			cross_axis,
			mountain_core_weight,
			mountain_halo_weight,
			connector_weight
		)
	)

	return maxf(
		broad_base_uplift
		+ summit_uplift
		+ shoulder_uplift
		+ connector_uplift
		+ secondary_relief
		- valley_cut,
		0.0
	)


# ==================================================
# LOCAL ELLIPSE
# ==================================================

func _get_ellipse_influence(
	long_axis: float,
	cross_axis: float,
	center_long: float,
	center_cross: float,
	long_radius: float,
	cross_radius: float,
	cos_rotation: float,
	sin_rotation: float,
	shape_a: float,
	shape_b: float
) -> float:
	var delta_long: float = (
		long_axis
		- center_long
	)

	var delta_cross: float = (
		cross_axis
		- center_cross
	)

	var rotated_long: float = (
		delta_long
			* cos_rotation
		+ delta_cross
			* sin_rotation
	)

	var rotated_cross: float = (
		-delta_long
			* sin_rotation
		+ delta_cross
			* cos_rotation
	)

	var warped_long_radius: float = (
		long_radius
		* (
			1.0
			+ shape_a
				* MASS_EDGE_WARP_A
			+ shape_b
				* MASS_EDGE_WARP_B
		)
	)

	var warped_cross_radius: float = (
		cross_radius
		* (
			1.0
			+ shape_b
				* MASS_EDGE_WARP_A
			- shape_a
				* MASS_EDGE_WARP_B
		)
	)

	warped_long_radius = maxf(
		warped_long_radius,
		1.0
	)

	warped_cross_radius = maxf(
		warped_cross_radius,
		1.0
	)

	var normalized_long: float = (
		rotated_long
		/ warped_long_radius
	)

	var normalized_cross: float = (
		rotated_cross
		/ warped_cross_radius
	)

	var distance: float = sqrt(
		normalized_long
			* normalized_long
		+ normalized_cross
			* normalized_cross
	)

	if distance >= 1.0:
		return 0.0

	return (
		_smoothstep01(
			1.0
			- distance
		)
	)


# ==================================================
# CURVED FINITE CONNECTOR
# ==================================================

func _get_connector_influence(
	long_axis: float,
	cross_axis: float,
	connector_index: int,
	shape_noise: float
) -> float:
	var start_long: float = (
		_mass_long[
			connector_index
		]
	)

	var start_cross: float = (
		_mass_cross[
			connector_index
		]
	)

	var end_long: float = (
		_mass_long[
			connector_index + 1
		]
	)

	var end_cross: float = (
		_mass_cross[
			connector_index + 1
		]
	)

	var segment_long: float = (
		end_long
		- start_long
	)

	var segment_cross: float = (
		end_cross
		- start_cross
	)

	var segment_length_squared: float = (
		segment_long
			* segment_long
		+ segment_cross
			* segment_cross
	)

	if segment_length_squared <= 1.0:
		return 0.0

	var relative_long: float = (
		long_axis
		- start_long
	)

	var relative_cross: float = (
		cross_axis
		- start_cross
	)

	var t: float = (
		(
			relative_long
				* segment_long
			+ relative_cross
				* segment_cross
		)
		/ segment_length_squared
	)

	if (
		t <= 0.0
		or t >= 1.0
	):
		return 0.0

	var segment_length: float = sqrt(
		segment_length_squared
	)

	var normal_long: float = (
		-segment_cross
		/ segment_length
	)

	var normal_cross: float = (
		segment_long
		/ segment_length
	)

	var bend: float = (
		sin(
			t * PI
		)
		* _connector_bend[
			connector_index
		]
	)

	var center_long: float = (
		lerpf(
			start_long,
			end_long,
			t
		)
		+ normal_long
			* bend
	)

	var center_cross: float = (
		lerpf(
			start_cross,
			end_cross,
			t
		)
		+ normal_cross
			* bend
	)

	var delta_long: float = (
		long_axis
		- center_long
	)

	var delta_cross: float = (
		cross_axis
		- center_cross
	)

	var cross_distance: float = absf(
		delta_long
			* normal_long
		+ delta_cross
			* normal_cross
	)

	var width: float = (
		_connector_width[
			connector_index
		]
		* (
			1.0
			+ shape_noise
				* 0.18
		)
	)

	width = maxf(
		width,
		1.0
	)

	if cross_distance >= width:
		return 0.0

	var cross_influence: float = (
		_smoothstep01(
			1.0
			- cross_distance
				/ width
		)
	)

	var longitudinal_influence: float = pow(
		sin(
			t * PI
		),
		0.72
	)

	return (
		cross_influence
		* longitudinal_influence
	)


# ==================================================
# SECONDARY STRUCTURE
# ==================================================

func _get_secondary_relief(
	x: float,
	z: float,
	long_axis: float,
	cross_axis: float,
	mountain_core_weight: float,
	mountain_halo_weight: float,
	connector_weight: float
) -> float:
	var ridge_noise_a: float = (
		_secondary_ridge_noise_a
			.get_noise_2d(
				long_axis
					* 0.82
					+ cross_axis
						* 0.24,
				cross_axis
					* 0.88
					- long_axis
						* 0.13
			)
	)

	var ridge_noise_b: float = (
		_secondary_ridge_noise_b
			.get_noise_2d(
				long_axis
					* 0.68
					- cross_axis
						* 0.31
					+ 731.0,
				cross_axis
					* 0.74
					+ long_axis
						* 0.19
					- 1189.0
			)
	)

	var ridge_a: float = (
		_get_ridge_value(
			ridge_noise_a,
			3.0
		)
	)

	var ridge_b: float = (
		_get_ridge_value(
			ridge_noise_b,
			3.6
		)
	)

	var combined_ridges: float = (
		ridge_a
			* 0.68
		+ ridge_b
			* 0.32
		- 0.40
	)

	var structural_weight: float = clampf(
		mountain_core_weight
			+ connector_weight
				* 0.80,
		0.0,
		1.0
	)

	var ridge_relief: float = (
		combined_ridges
		* SECONDARY_RIDGE_AMPLITUDE_M
		* structural_weight
	)

	var spur_noise_value: float = (
		_spur_noise.get_noise_2d(
			long_axis
				* 0.55
				+ cross_axis
					* 0.72
				- 417.0,
			cross_axis
				* 0.48
				- long_axis
					* 0.36
				+ 923.0
		)
	)

	var spur_ridge: float = (
		_get_ridge_value(
			spur_noise_value,
			4.0
		)
	)

	var centered_spur: float = (
		spur_ridge
		- 0.34
	)

	var spur_weight: float = clampf(
		mountain_core_weight
			+ mountain_halo_weight
				* 0.40,
		0.0,
		1.0
	)

	var spur_relief: float = (
		centered_spur
		* SPUR_AMPLITUDE_M
		* spur_weight
	)

	var saddle_noise_value: float = (
		_saddle_noise.get_noise_2d(
			long_axis
				* 0.80,
			cross_axis
				* 0.24
		)
	)

	var saddle_signal: float = (
		_smoothstep01(
			(
				saddle_noise_value
				- 0.18
			)
			/ 0.42
		)
	)

	var saddle_cut: float = (
		-saddle_signal
		* SADDLE_MAX_DEPTH_M
		* mountain_core_weight
	)

	var foothill_band: float = clampf(
		mountain_halo_weight
			- mountain_core_weight
				* 0.58,
		0.0,
		1.0
	)

	foothill_band = (
		_smoothstep01(
			foothill_band
		)
	)

	var foothill_relief: float = (
		spur_noise_value
		* FOOTHILL_DETAIL_AMPLITUDE_M
		* foothill_band
	)

	return (
		ridge_relief
		+ spur_relief
		+ saddle_cut
		+ foothill_relief
	)


# ==================================================
# HELPERS
# ==================================================

func _get_ridge_value(
	noise_value: float,
	sharpness: float
) -> float:
	var ridge: float = clampf(
		1.0
			- absf(
				noise_value
			),
		0.0,
		1.0
	)

	return pow(
		ridge,
		sharpness
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
			- 2.0
				* clamped
		)
	)


func _hash01(
	index: int,
	salt: int
) -> float:
	var value: int = (
		_world.world_seed
	)

	value = (
		value
		^ (
			index
			* 73856093
		)
	)

	value = (
		value
		^ (
			salt
			* 19349663
		)
	)

	value = (
		value
		^ (
			(index + salt)
			* 83492791
		)
	)

	value = (
		value
		& 0x7fffffff
	)

	return (
		float(
			value % 1000003
		)
		/ 1000002.0
	)
