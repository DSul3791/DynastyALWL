class_name ErosionModel
extends RefCounted


const Geology := preload(
	"res://src/shared/geology_ids.gd"
)

const GeologyProps := preload(
	"res://src/shared/geology_properties.gd"
)


# ==================================================
# BROAD GEOLOGICAL EROSION
#
# This pass happens AFTER:
#
#     quadrant swap
#     seam reconciliation
#     central lake-basin carve
#
# It represents long-term weathering and general
# landscape erosion.
#
# It does NOT create rivers.
#
# River/drainage erosion happens later once flow
# direction and accumulation have been calculated.
# ==================================================


const BASE_EROSION_BUDGET: float = 8.0

# Higher terrain has experienced more exposure and
# therefore receives a larger erosion budget.
const HIGHLAND_EROSION_PER_METER: float = 0.11

# Keep this broad erosion pass restrained.
# River erosion will add the sharper valleys later.
const MAX_EROSION_BUDGET: float = 120.0

# Never allow this general erosion pass to chew
# hundreds of meters vertically through one column.
const MAX_EROSION_DEPTH_M: float = 90.0

const SAMPLE_STEP_M: float = 2.0


var _world: WorldDefinition
var _geology: DeformedGeologySampler

var _erosion_noise: FastNoiseLite


func setup(
	world_definition: WorldDefinition,
	stratigraphy: StratigraphyProfile
) -> void:
	_world = world_definition

	_geology = DeformedGeologySampler.new()

	_geology.setup(
		world_definition,
		stratigraphy
	)

	_erosion_noise = FastNoiseLite.new()
	_erosion_noise.seed = (
		_world.world_seed
		+ 41021
	)

	_erosion_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	# Broad variation rather than small noisy pits.
	_erosion_noise.frequency = 0.0012


# ==================================================
# ORIGINAL GEOLOGICAL SURFACE
#
# These functions remain available for compatibility
# with any existing tests or tools.
# ==================================================

func get_pre_erosion_surface_y(
	x: float,
	z: float
) -> float:
	if _geology == null:
		return 0.0

	return _geology.get_column_top_y(
		x,
		z
	)


func get_erosion_depth(
	x: float,
	z: float
) -> float:
	var original_y: float = (
		get_pre_erosion_surface_y(
			x,
			z
		)
	)

	return get_erosion_depth_from_surface(
		x,
		z,
		original_y
	)


func get_eroded_surface_y(
	x: float,
	z: float
) -> float:
	var original_y: float = (
		get_pre_erosion_surface_y(
			x,
			z
		)
	)

	return get_eroded_surface_y_from_height(
		x,
		z,
		original_y
	)


# ==================================================
# POST-SWAP SURFACE ENTRY POINT
#
# SurfaceHeightField will use these functions.
#
# supplied_surface_y may already include:
#
#     seam smoothing
#     lake-basin carving
#
# We therefore erode downward from that supplied
# surface rather than starting again from the raw
# geological column top.
# ==================================================

func get_eroded_surface_y_from_height(
	x: float,
	z: float,
	supplied_surface_y: float
) -> float:
	var erosion_depth: float = (
		get_erosion_depth_from_surface(
			x,
			z,
			supplied_surface_y
		)
	)

	return (
		supplied_surface_y
		- erosion_depth
	)


func get_erosion_depth_from_surface(
	x: float,
	z: float,
	supplied_surface_y: float
) -> float:
	if (
		_world == null
		or _geology == null
	):
		return 0.0

	var erosion_budget: float = (
		_get_erosion_budget(
			x,
			z,
			supplied_surface_y
		)
	)

	return _consume_rock_with_erosion(
		x,
		z,
		supplied_surface_y,
		erosion_budget
	)


# ==================================================
# EROSION BUDGET
# ==================================================

func _get_erosion_budget(
	x: float,
	z: float,
	surface_y: float
) -> float:
	var sea_level: float = float(
		_world.sea_level_meters
	)

	var elevation_above_sea: float = maxf(
		0.0,
		surface_y - sea_level
	)

	var highland_budget: float = minf(
		elevation_above_sea
		* HIGHLAND_EROSION_PER_METER,
		MAX_EROSION_BUDGET
	)

	var noise_value: float = (
		_erosion_noise.get_noise_2d(
			x,
			z
		)
	)

	# Roughly 80% to 120%.
	var regional_multiplier: float = (
		1.0
		+ noise_value * 0.20
	)

	var budget: float = (
		(
			BASE_EROSION_BUDGET
			+ highland_budget
		)
		* regional_multiplier
	)

	return maxf(
		budget,
		0.0
	)


# ==================================================
# ROCK REMOVAL
# ==================================================

func _consume_rock_with_erosion(
	x: float,
	z: float,
	start_y: float,
	erosion_budget: float
) -> float:
	var remaining_budget: float = (
		erosion_budget
	)

	var eroded_depth: float = 0.0

	while (
		remaining_budget > 0.0
		and eroded_depth
			< MAX_EROSION_DEPTH_M
	):
		var remaining_depth: float = (
			MAX_EROSION_DEPTH_M
			- eroded_depth
		)

		var step_depth: float = minf(
			SAMPLE_STEP_M,
			remaining_depth
		)

		var sample_depth: float = (
			eroded_depth
			+ step_depth * 0.5
		)

		var sample_y: float = (
			start_y
			- sample_depth
		)

		var geology_id: int = (
			_geology.get_geology_id(
				x,
				sample_y,
				z
			)
		)

		# This can occur where a carved surface lies
		# above the actual geological surface.
		if geology_id == Geology.AIR:
			eroded_depth += step_depth
			continue

		var resistance: float = (
			GeologyProps.get_erosion_resistance(
				geology_id
			)
		)

		var fracture_tendency: float = (
			GeologyProps.get_fracture_tendency(
				geology_id
			)
		)

		# Highly fractured rock is easier to weather.
		var effective_resistance: float = (
			resistance
			* (
				1.0
				- fracture_tendency
				* 0.25
			)
		)

		effective_resistance = clampf(
			effective_resistance,
			0.05,
			1.0
		)

		var cost_per_meter: float = lerpf(
			0.75,
			3.25,
			effective_resistance
		)

		var full_step_cost: float = (
			cost_per_meter
			* step_depth
		)

		if (
			remaining_budget
			>= full_step_cost
		):
			remaining_budget -= (
				full_step_cost
			)

			eroded_depth += (
				step_depth
			)
		else:
			var partial_depth: float = (
				remaining_budget
				/ cost_per_meter
			)

			eroded_depth += minf(
				partial_depth,
				step_depth
			)

			remaining_budget = 0.0

	return minf(
		eroded_depth,
		MAX_EROSION_DEPTH_M
	)
