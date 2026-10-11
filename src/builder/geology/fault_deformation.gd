class_name FaultDeformation
extends RefCounted


# ==================================================
# MOUNTAIN-BELT FAULT SYSTEM
#
# These faults belong to the same tectonic framework
# as TectonicDeformation.
#
# The mountain belt uses:
#
#   long_axis  = (x + z) / sqrt(2)
#   cross_axis = (x - z) / sqrt(2)
#
# Therefore the major faults run approximately
# parallel to the mountain belt instead of cutting
# across it at arbitrary angles.
#
#
# Layout:
#
#            outer lowlands
#
#     PRIMARY FLANK / THRUST FAULT
#              \\\\\\\\\
#
#         mountains / folds / peaks
#          /\       /\       /\
#
#              /////////
#     SECONDARY / BACK-THRUST FAULT
#
#            outer lowlands
#
#
# Important:
#
# - Faults are finite.
# - Faults wander naturally.
# - Surface displacement is localized.
# - Fault proximity remains available to caves,
#   minerals, fractures, etc.
# - We do NOT shift entire halves of the island.
# ==================================================


const INV_SQRT_2: float = 0.7071067811865476


# ==================================================
# STRUCTURAL PLACEMENT
# ==================================================

# Distance of the two major faults from the centerline
# of the mountain province.
#
# For a 10.24 km island:
#
#   10240 * 0.12 = ~1229 m
#
# This places the faults approximately along opposite
# flanks of the mountain system rather than underneath
# the exact ridge crest.
const FLANK_OFFSET_FRACTION: float = 0.12


# Faults occupy most of the mountain belt length, but
# taper before reaching the ends.
const PRIMARY_HALF_LENGTH_FRACTION: float = 0.31
const SECONDARY_HALF_LENGTH_FRACTION: float = 0.28


# Slight offset along the mountain axis prevents both
# fault tips from lining up unnaturally.
const PRIMARY_LONG_OFFSET_FRACTION: float = -0.025
const SECONDARY_LONG_OFFSET_FRACTION: float = 0.035


# ==================================================
# PRIMARY THRUST FAULT
# ==================================================

# Surface displacement remains modest compared with
# mountain uplift.
const PRIMARY_SURFACE_HALF_THROW_M: float = 11.0

# Only terrain near the fault trace is displaced.
const PRIMARY_SURFACE_WIDTH_M: float = 240.0

# Width over which displacement changes smoothly from
# one side of the fault to the other.
const PRIMARY_TRANSITION_HALF_WIDTH_M: float = 38.0

# Geological fracture/fault zone used by caves and
# mineral generation.
const PRIMARY_ZONE_WIDTH_M: float = 95.0

# Fault trace wandering.
const PRIMARY_WANDER_AMPLITUDE_M: float = 190.0

# Additional broad curvature.
const PRIMARY_CURVE_AMPLITUDE_M: float = 85.0


# ==================================================
# SECONDARY / BACK-THRUST FAULT
# ==================================================

const SECONDARY_SURFACE_HALF_THROW_M: float = 7.0

const SECONDARY_SURFACE_WIDTH_M: float = 210.0

const SECONDARY_TRANSITION_HALF_WIDTH_M: float = 34.0

const SECONDARY_ZONE_WIDTH_M: float = 75.0

const SECONDARY_WANDER_AMPLITUDE_M: float = 165.0

const SECONDARY_CURVE_AMPLITUDE_M: float = 70.0


# ==================================================
# TIP TAPER
# ==================================================

# Final portion of each fault fades toward its tips.
const TIP_TAPER_FRACTION: float = 0.30


# ==================================================
# RUNTIME DATA
# ==================================================

var _world: WorldDefinition


var _island_span_m: float = 10240.0

var _flank_offset_m: float = 1200.0

var _primary_half_length_m: float = 3000.0
var _secondary_half_length_m: float = 2700.0

var _primary_long_center_m: float = 0.0
var _secondary_long_center_m: float = 0.0


var _primary_wander_noise: FastNoiseLite
var _secondary_wander_noise: FastNoiseLite

var _primary_strength_noise: FastNoiseLite
var _secondary_strength_noise: FastNoiseLite


# ==================================================
# SETUP
# ==================================================

func setup(
	world_definition: WorldDefinition
) -> void:
	_world = world_definition

	_island_span_m = maxf(
		1.0,
		minf(
			float(_world.size_x_meters),
			float(_world.size_z_meters)
		)
	)

	_flank_offset_m = (
		_island_span_m
		* FLANK_OFFSET_FRACTION
	)

	_primary_half_length_m = clampf(
		_island_span_m
			* PRIMARY_HALF_LENGTH_FRACTION,
		1600.0,
		4200.0
	)

	_secondary_half_length_m = clampf(
		_island_span_m
			* SECONDARY_HALF_LENGTH_FRACTION,
		1400.0,
		3800.0
	)

	_primary_long_center_m = (
		_island_span_m
		* PRIMARY_LONG_OFFSET_FRACTION
	)

	_secondary_long_center_m = (
		_island_span_m
		* SECONDARY_LONG_OFFSET_FRACTION
	)


	# --------------------------------------------------
	# PRIMARY FAULT WANDER
	# --------------------------------------------------

	_primary_wander_noise = FastNoiseLite.new()

	_primary_wander_noise.seed = (
		_world.world_seed
		+ 52001
	)

	_primary_wander_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_primary_wander_noise.frequency = 0.00062


	# --------------------------------------------------
	# SECONDARY FAULT WANDER
	# --------------------------------------------------

	_secondary_wander_noise = FastNoiseLite.new()

	_secondary_wander_noise.seed = (
		_world.world_seed
		+ 52002
	)

	_secondary_wander_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_secondary_wander_noise.frequency = 0.00071


	# --------------------------------------------------
	# SURFACE THROW VARIATION
	# --------------------------------------------------

	_primary_strength_noise = FastNoiseLite.new()

	_primary_strength_noise.seed = (
		_world.world_seed
		+ 52003
	)

	_primary_strength_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_primary_strength_noise.frequency = 0.00092


	_secondary_strength_noise = FastNoiseLite.new()

	_secondary_strength_noise.seed = (
		_world.world_seed
		+ 52004
	)

	_secondary_strength_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_secondary_strength_noise.frequency = 0.00108


# ==================================================
# TOTAL SURFACE DISPLACEMENT
# ==================================================

func get_vertical_displacement(
	x: float,
	z: float
) -> float:
	if _world == null:
		return 0.0

	return (
		_get_primary_fault_displacement(
			x,
			z
		)
		+ _get_secondary_fault_displacement(
			x,
			z
		)
	)


# ==================================================
# FAULT ZONE STRENGTH
#
# Used by caves, minerals and other geology systems.
# ==================================================

func get_fault_zone_strength(
	x: float,
	z: float
) -> float:
	return maxf(
		get_primary_fault_zone_strength(
			x,
			z
		),
		get_secondary_fault_zone_strength(
			x,
			z
		)
	)


func get_primary_fault_zone_strength(
	x: float,
	z: float
) -> float:
	var frame: Vector2 = (
		_get_primary_fault_frame(
			x,
			z
		)
	)

	return _get_zone_strength(
		frame,
		_primary_half_length_m,
		PRIMARY_ZONE_WIDTH_M
	)


func get_secondary_fault_zone_strength(
	x: float,
	z: float
) -> float:
	var frame: Vector2 = (
		_get_secondary_fault_frame(
			x,
			z
		)
	)

	return _get_zone_strength(
		frame,
		_secondary_half_length_m,
		SECONDARY_ZONE_WIDTH_M
	)


# ==================================================
# FAULT DISTANCE
# ==================================================

func get_primary_fault_distance(
	x: float,
	z: float
) -> float:
	var frame: Vector2 = (
		_get_primary_fault_frame(
			x,
			z
		)
	)

	return _get_distance_to_finite_fault(
		frame,
		_primary_half_length_m
	)


func get_secondary_fault_distance(
	x: float,
	z: float
) -> float:
	var frame: Vector2 = (
		_get_secondary_fault_frame(
			x,
			z
		)
	)

	return _get_distance_to_finite_fault(
		frame,
		_secondary_half_length_m
	)


# ==================================================
# PRIMARY THRUST DISPLACEMENT
# ==================================================

func _get_primary_fault_displacement(
	x: float,
	z: float
) -> float:
	var frame: Vector2 = (
		_get_primary_fault_frame(
			x,
			z
		)
	)

	var strength_multiplier: float = 1.0

	if _primary_strength_noise != null:
		var noise_value: float = (
			_primary_strength_noise.get_noise_2d(
				frame.x,
				337.0
			)
		)

		strength_multiplier = clampf(
			0.90
				+ noise_value * 0.18,
			0.70,
			1.10
		)

	# Primary fault sits on the negative-cross side of
	# the mountain belt.
	#
	# Positive cross direction points inward toward the
	# mountain core, so +1 makes the mountain-facing
	# side the uplifted side.

	return _get_surface_displacement(
		frame,
		_primary_half_length_m,
		PRIMARY_SURFACE_WIDTH_M,
		PRIMARY_TRANSITION_HALF_WIDTH_M,
		PRIMARY_SURFACE_HALF_THROW_M
			* strength_multiplier,
		1.0
	)


# ==================================================
# SECONDARY / BACK-THRUST DISPLACEMENT
# ==================================================

func _get_secondary_fault_displacement(
	x: float,
	z: float
) -> float:
	var frame: Vector2 = (
		_get_secondary_fault_frame(
			x,
			z
		)
	)

	var strength_multiplier: float = 1.0

	if _secondary_strength_noise != null:
		var noise_value: float = (
			_secondary_strength_noise.get_noise_2d(
				frame.x,
				-713.0
			)
		)

		strength_multiplier = clampf(
			0.88
				+ noise_value * 0.16,
			0.72,
			1.06
		)

	# Secondary fault lies on the positive-cross side.
	#
	# Negative cross direction points back inward toward
	# the mountain core, so -1 reverses the throw.

	return _get_surface_displacement(
		frame,
		_secondary_half_length_m,
		SECONDARY_SURFACE_WIDTH_M,
		SECONDARY_TRANSITION_HALF_WIDTH_M,
		SECONDARY_SURFACE_HALF_THROW_M
			* strength_multiplier,
		-1.0
	)


# ==================================================
# PRIMARY FAULT FRAME
# ==================================================

func _get_primary_fault_frame(
	x: float,
	z: float
) -> Vector2:
	var structural: Vector2 = (
		_get_structural_coordinates(
			x,
			z
		)
	)

	var along_fault: float = (
		structural.x
		- _primary_long_center_m
	)

	# Primary fault is on one flank of the range.
	var target_cross: float = (
		-_flank_offset_m
	)

	var wander: float = 0.0

	if _primary_wander_noise != null:
		wander += (
			_primary_wander_noise.get_noise_2d(
				along_fault,
				911.0
			)
			* PRIMARY_WANDER_AMPLITUDE_M
		)

	# Broad curvature makes the fault trace bow and bend
	# with the mountain province rather than remaining a
	# perfect straight diagonal.

	wander += (
		sin(
			along_fault
				* 0.00115
			+ 0.65
		)
		* PRIMARY_CURVE_AMPLITUDE_M
	)

	var across_fault: float = (
		structural.y
		- (
			target_cross
			+ wander
		)
	)

	return Vector2(
		along_fault,
		across_fault
	)


# ==================================================
# SECONDARY FAULT FRAME
# ==================================================

func _get_secondary_fault_frame(
	x: float,
	z: float
) -> Vector2:
	var structural: Vector2 = (
		_get_structural_coordinates(
			x,
			z
		)
	)

	var along_fault: float = (
		structural.x
		- _secondary_long_center_m
	)

	# Secondary fault is on the opposite flank.
	var target_cross: float = (
		_flank_offset_m
	)

	var wander: float = 0.0

	if _secondary_wander_noise != null:
		wander += (
			_secondary_wander_noise.get_noise_2d(
				along_fault,
				-421.0
			)
			* SECONDARY_WANDER_AMPLITUDE_M
		)

	wander += (
		sin(
			along_fault
				* 0.00142
			- 0.95
		)
		* SECONDARY_CURVE_AMPLITUDE_M
	)

	var across_fault: float = (
		structural.y
		- (
			target_cross
			+ wander
		)
	)

	return Vector2(
		along_fault,
		across_fault
	)


# ==================================================
# SHARED TECTONIC COORDINATE SYSTEM
#
# This is deliberately identical to the coordinate
# system used by TectonicDeformation.
#
# Vector2.x = distance along mountain belt
# Vector2.y = distance across mountain belt
# ==================================================

func _get_structural_coordinates(
	x: float,
	z: float
) -> Vector2:
	var long_axis: float = (
		(x + z)
		* INV_SQRT_2
	)

	var cross_axis: float = (
		(x - z)
		* INV_SQRT_2
	)

	return Vector2(
		long_axis,
		cross_axis
	)


# ==================================================
# LOCALIZED SURFACE THROW
# ==================================================

func _get_surface_displacement(
	frame: Vector2,
	half_length_m: float,
	surface_width_m: float,
	transition_half_width_m: float,
	half_throw_m: float,
	mountain_side_sign: float
) -> float:
	var length_weight: float = (
		_get_length_weight(
			frame.x,
			half_length_m
		)
	)

	if length_weight <= 0.0:
		return 0.0

	var cross_distance: float = absf(
		frame.y
	)

	if cross_distance >= surface_width_m:
		return 0.0

	# Fade displacement away from the actual fault trace.

	var surface_weight: float = (
		1.0
		- _smoothstep01(
			cross_distance
			/ maxf(
				surface_width_m,
				1.0
			)
		)
	)

	# Smooth signed transition from one side of the fault
	# to the other.

	var signed_side: float = (
		_smoothstep01(
			(
				frame.y
				+ transition_half_width_m
			)
			/ maxf(
				transition_half_width_m
					* 2.0,
				0.001
			)
		)
		* 2.0
		- 1.0
	)

	# Both faults are arranged so their mountain-facing
	# sides receive the positive part of their throw.

	signed_side *= mountain_side_sign

	return (
		signed_side
		* half_throw_m
		* surface_weight
		* length_weight
	)


# ==================================================
# GEOLOGICAL FAULT ZONE
# ==================================================

func _get_zone_strength(
	frame: Vector2,
	half_length_m: float,
	zone_width_m: float
) -> float:
	var length_weight: float = (
		_get_length_weight(
			frame.x,
			half_length_m
		)
	)

	if length_weight <= 0.0:
		return 0.0

	var cross_strength: float = clampf(
		1.0
		- absf(frame.y)
			/ maxf(
				zone_width_m,
				1.0
			),
		0.0,
		1.0
	)

	cross_strength = _smoothstep01(
		cross_strength
	)

	return (
		cross_strength
		* length_weight
	)


# ==================================================
# FINITE FAULT LENGTH
# ==================================================

func _get_length_weight(
	along_fault: float,
	half_length_m: float
) -> float:
	if half_length_m <= 0.0:
		return 0.0

	var normalized_length: float = (
		absf(along_fault)
		/ half_length_m
	)

	if normalized_length >= 1.0:
		return 0.0

	var taper_start: float = clampf(
		1.0
		- TIP_TAPER_FRACTION,
		0.0,
		0.99
	)

	if normalized_length <= taper_start:
		return 1.0

	var taper_phase: float = (
		normalized_length
		- taper_start
	) / maxf(
		1.0
			- taper_start,
		0.001
	)

	return (
		1.0
		- _smoothstep01(
			taper_phase
		)
	)


# ==================================================
# DISTANCE TO FINITE FAULT
# ==================================================

func _get_distance_to_finite_fault(
	frame: Vector2,
	half_length_m: float
) -> float:
	var end_overrun: float = maxf(
		0.0,
		absf(frame.x)
			- half_length_m
	)

	if end_overrun <= 0.0:
		return absf(
			frame.y
		)

	return sqrt(
		frame.y * frame.y
		+ end_overrun * end_overrun
	)


# ==================================================
# HELPERS
# ==================================================

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
