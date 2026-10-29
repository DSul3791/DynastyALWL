class_name FoldDeformation
extends RefCounted


# -------------------------------------------------------------------
# Master-world folding
#
# The main mountain province runs NW <-> SE.
#
# Folding creates long ridges and valleys broadly parallel to the
# mountain range. It is strongest through the mountain province and
# fades smoothly through the foothills into the plains.
#
# TectonicDeformation creates the large-scale mountain mass.
# This class adds geological folding and a modest regional dip.
# -------------------------------------------------------------------


const INV_SQRT_2: float = 0.7071067811865476

# These match the broad mountain province used by
# TectonicDeformation.
const RANGE_HALF_LENGTH_M: float = 2200.0
const RANGE_HALF_WIDTH_M: float = 1800.0

# Major folds produce the broad parallel ridges that make up much
# of the mountain and foothill structure.
const PRIMARY_WAVELENGTH_M: float = 760.0
const PRIMARY_AMPLITUDE_M: float = 72.0

# Secondary folds keep the terrain from becoming a sequence of
# perfectly regular parallel ridges.
const SECONDARY_WAVELENGTH_M: float = 340.0
const SECONDARY_AMPLITUDE_M: float = 24.0

# Very broad variation along the length of the mountain range.
# This makes individual ridges strengthen and weaken rather than
# remaining identical from NW to SE.
const LONGITUDINAL_WAVELENGTH_M: float = 1700.0
const LONGITUDINAL_MODULATION: float = 0.22

# Gentle structural dip through the mountain province.
#
# These are deliberately small because the plains already receive
# their low-relief variation from TectonicDeformation.
const CROSS_AXIS_TILT: float = 0.014
const LONG_AXIS_TILT: float = 0.004


var _world: WorldDefinition

var _amplitude_noise: FastNoiseLite
var _phase_noise: FastNoiseLite


func setup(world_definition: WorldDefinition) -> void:
	_world = world_definition

	# Broad variation in fold strength.
	_amplitude_noise = FastNoiseLite.new()
	_amplitude_noise.seed = _world.world_seed + 9419
	_amplitude_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_amplitude_noise.frequency = 0.00055

	# Slowly bends and offsets the fold system so the ridges do not
	# appear mathematically straight.
	_phase_noise = FastNoiseLite.new()
	_phase_noise.seed = _world.world_seed + 9420
	_phase_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_phase_noise.frequency = 0.0008


func get_vertical_displacement(x: float, z: float) -> float:
	if _world == null:
		return 0.0

	var folding: float = _get_fold_displacement(x, z)
	var tilt: float = _get_regional_tilt(x, z)

	return folding + tilt


func _get_fold_displacement(x: float, z: float) -> float:
	# Rotate into coordinates aligned with the mountain range.
	#
	# long_axis:
	#     NW <-> SE, running along the mountain chain.
	#
	# cross_axis:
	#     NE <-> SW, running across the mountain chain.
	#
	# Fold crests therefore run broadly NW <-> SE.

	var long_axis: float = (
		(x + z)
		* INV_SQRT_2
	)

	var cross_axis: float = (
		(x - z)
		* INV_SQRT_2
	)

	var province_influence: float = (
		_get_province_influence(
			long_axis,
			cross_axis
		)
	)

	if province_influence <= 0.0:
		return 0.0

	# Slowly bend the folds sideways.
	#
	# At this scale we only want a few major ridge systems,
	# not dozens of tightly repeated waves.
	var phase_noise_value: float = (
		_phase_noise.get_noise_2d(
			x,
			z
		)
	)

	var phase_offset_m: float = (
		phase_noise_value
		* 120.0
	)

	var warped_cross_axis: float = (
		cross_axis
		+ phase_offset_m
	)

	# --------------------------------------------------
	# PRIMARY FOLD SYSTEM
	# --------------------------------------------------

	var primary_phase: float = (
		warped_cross_axis
		/ PRIMARY_WAVELENGTH_M
		* TAU
	)

	var primary_fold: float = (
		sin(primary_phase)
		* PRIMARY_AMPLITUDE_M
	)

	# --------------------------------------------------
	# SECONDARY FOLD SYSTEM
	# --------------------------------------------------

	# Give the smaller folds a different phase so they do not
	# simply trace the primary waves.
	var secondary_phase: float = (
		(
			warped_cross_axis
			+ 85.0
		)
		/ SECONDARY_WAVELENGTH_M
		* TAU
	)

	var secondary_fold: float = (
		sin(secondary_phase)
		* SECONDARY_AMPLITUDE_M
	)

	# --------------------------------------------------
	# LONGITUDINAL VARIATION
	# --------------------------------------------------

	var longitudinal_phase: float = (
		long_axis
		/ LONGITUDINAL_WAVELENGTH_M
		* TAU
	)

	var longitudinal_multiplier: float = (
		1.0
		+ sin(longitudinal_phase)
		* LONGITUDINAL_MODULATION
	)

	# --------------------------------------------------
	# NATURAL AMPLITUDE VARIATION
	# --------------------------------------------------

	var amplitude_noise_value: float = (
		_amplitude_noise.get_noise_2d(
			x,
			z
		)
	)

	var amplitude_multiplier: float = (
		0.85
		+ (
			(amplitude_noise_value + 1.0)
			* 0.15
		)
	)

	# Keep significant folds through the mountains and foothills,
	# but fade them smoothly before reaching the true plains.
	var fold_influence: float = pow(
		province_influence,
		0.80
	)

	return (
		(primary_fold + secondary_fold)
		* longitudinal_multiplier
		* amplitude_multiplier
		* fold_influence
	)


func _get_regional_tilt(x: float, z: float) -> float:
	var long_axis: float = (
		(x + z)
		* INV_SQRT_2
	)

	var cross_axis: float = (
		(x - z)
		* INV_SQRT_2
	)

	var province_influence: float = (
		_get_province_influence(
			long_axis,
			cross_axis
		)
	)

	if province_influence <= 0.0:
		return 0.0

	# Give the formations a broad geological dip without allowing
	# the old large-scale linear tilt to distort the lowland plains.
	var cross_tilt: float = (
		cross_axis
		* CROSS_AXIS_TILT
	)

	var long_tilt: float = (
		long_axis
		* LONG_AXIS_TILT
	)

	return (
		(cross_tilt + long_tilt)
		* province_influence
	)


func _get_province_influence(
	long_axis: float,
	cross_axis: float
) -> float:
	var normalized_long: float = (
		long_axis
		/ RANGE_HALF_LENGTH_M
	)

	var normalized_cross: float = (
		cross_axis
		/ RANGE_HALF_WIDTH_M
	)

	var normalized_radius: float = sqrt(
		normalized_long * normalized_long
		+ normalized_cross * normalized_cross
	)

	if normalized_radius >= 1.0:
		return 0.0

	var influence: float = (
		1.0
		- normalized_radius
	)

	return _smoothstep01(
		influence
	)


func _smoothstep01(value: float) -> float:
	var clamped: float = clampf(
		value,
		0.0,
		1.0
	)

	return (
		clamped
		* clamped
		* (3.0 - 2.0 * clamped)
	)
