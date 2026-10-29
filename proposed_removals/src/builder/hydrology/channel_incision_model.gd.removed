class_name ChannelIncisionModel
extends RefCounted


const Channels := preload(
	"res://src/builder/hydrology/channel_network.gd"
)

const GeologyProps := preload(
	"res://src/shared/geology_properties.gd"
)

const GeologySampler := preload(
	"res://src/builder/geology/deformed_geology_sampler.gd"
)


# ==================================================
# LOCAL CHANNEL MORPHOLOGY
#
# River beds should not have a uniform depth.
#
# Local deepening can be caused by:
#
# - bends
# - tributary confluences
# - soft / easily eroded material
# - ordinary pool/riffle sequences
#
# IMPORTANT:
#
# A persistent watering/swimming pool requires a
# reasonably gentle local reach.
#
# Steep channels may still erode strongly through the
# normal incision model, but they do not receive the
# extra local pool/scour excavation used to create
# persistent deep holes.
# ==================================================


const MAX_TOTAL_INCISION_M: float = 18.0


# ==================================================
# POOL-SITE SLOPE LIMITS
#
# FlowDirectionMap slope is rise/run:
#
# 0.01 = 1 percent grade
# 0.03 = 3 percent grade
#
# Full pool formation is allowed on terrain up to
# about a 3 percent grade.
#
# Between 3 and 8 percent it fades rapidly.
#
# At 8 percent or steeper, persistent pool excavation
# is disabled.
#
# Normal river incision still occurs there.
# ==================================================

const POOL_FULL_SLOPE_GRADE: float = 0.03
const POOL_MAX_SLOPE_GRADE: float = 0.08


# ==================================================
# BEND SCOUR
# ==================================================

const BEND_STRENGTH_NORMALIZER: float = 0.65


# ==================================================
# POOL / RIFFLE SEQUENCES
# ==================================================

const POOL_NOISE_FREQUENCY: float = 0.0065

const POOL_NOISE_START: float = 0.56
const POOL_NOISE_FULL: float = 0.86


# ==================================================
# LOCAL DEPTH VARIATION
# ==================================================

const LOCAL_DEPTH_MIN_FACTOR: float = 0.90
const LOCAL_DEPTH_MAX_FACTOR: float = 1.08


var _world: WorldDefinition
var _surface_field
var _flow_map
var _accumulation_map
var _channel_network

var _geology

var _width: int = 0
var _depth: int = 0

var _pool_noise: FastNoiseLite


func setup(
	world_definition: WorldDefinition,
	stratigraphy: StratigraphyProfile,
	surface_field,
	flow_map,
	accumulation_map,
	channel_network
) -> void:
	_world = world_definition
	_surface_field = surface_field
	_flow_map = flow_map
	_accumulation_map = accumulation_map
	_channel_network = channel_network

	_width = _surface_field.get_width()
	_depth = _surface_field.get_depth()

	_geology = GeologySampler.new()

	_geology.setup(
		world_definition,
		stratigraphy
	)

	_pool_noise = FastNoiseLite.new()

	_pool_noise.seed = (
		_world.world_seed
		+ 42117
	)

	_pool_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	_pool_noise.frequency = (
		POOL_NOISE_FREQUENCY
	)


# ==================================================
# PUBLIC INCISION
# ==================================================

func get_incision_depth(
	grid_x: int,
	grid_z: int
) -> float:
	if _channel_network == null:
		return 0.0

	var channel_class: int = (
		_channel_network.get_channel_class(
			grid_x,
			grid_z
		)
	)

	if channel_class == Channels.CHANNEL_NONE:
		return 0.0

	var base_depth: float = (
		_get_base_incision_depth(
			channel_class
		)
	)

	var drainage_multiplier: float = (
		_get_drainage_multiplier(
			grid_x,
			grid_z
		)
	)

	var slope_multiplier: float = (
		_get_slope_multiplier(
			grid_x,
			grid_z
		)
	)

	var rock_multiplier: float = (
		_get_rock_resistance_multiplier(
			grid_x,
			grid_z
		)
	)

	var local_depth_factor: float = (
		_get_local_depth_variation(
			grid_x,
			grid_z
		)
	)

	var normal_incision: float = (
		base_depth
		* drainage_multiplier
		* slope_multiplier
		* rock_multiplier
		* local_depth_factor
	)

	var local_scour_depth: float = (
		_get_local_scour_depth(
			grid_x,
			grid_z,
			channel_class
		)
	)

	var incision_depth: float = (
		normal_incision
		+ local_scour_depth
	)

	return clampf(
		incision_depth,
		0.0,
		MAX_TOTAL_INCISION_M
	)


func get_channel_bed_y(
	grid_x: int,
	grid_z: int
) -> float:
	var terrain_y: float = (
		_surface_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	return (
		terrain_y
		- get_incision_depth(
			grid_x,
			grid_z
		)
	)


# ==================================================
# NORMAL CHANNEL DEPTH
# ==================================================

func _get_base_incision_depth(
	channel_class: int
) -> float:
	match channel_class:
		Channels.CHANNEL_HEADWATER:
			return 0.6

		Channels.CHANNEL_SMALL_STREAM:
			return 1.4

		Channels.CHANNEL_STREAM:
			return 2.8

		Channels.CHANNEL_MAJOR:
			return 4.5

		_:
			return 0.0


func _get_drainage_multiplier(
	grid_x: int,
	grid_z: int
) -> float:
	var drainage_area_km2: float = (
		_accumulation_map
			.get_drainage_area_square_kilometers(
				grid_x,
				grid_z
			)
	)

	var normalized_area: float = (
		drainage_area_km2
		/ Channels.HEADWATER_AREA_KM2
	)

	normalized_area = maxf(
		normalized_area,
		1.0
	)

	var area_multiplier: float = pow(
		normalized_area,
		0.22
	)

	return clampf(
		area_multiplier,
		1.0,
		2.2
	)


func _get_slope_multiplier(
	grid_x: int,
	grid_z: int
) -> float:
	var slope: float = (
		_flow_map.get_slope(
			grid_x,
			grid_z
		)
	)

	var slope_effect: float = sqrt(
		maxf(
			slope,
			0.0
		)
	)

	var multiplier: float = (
		0.70
		+ slope_effect
			* 0.35
	)

	return clampf(
		multiplier,
		0.70,
		1.60
	)


func _get_rock_resistance_multiplier(
	grid_x: int,
	grid_z: int
) -> float:
	var resistance: float = (
		_get_rock_resistance(
			grid_x,
			grid_z
		)
	)

	var multiplier: float = lerpf(
		1.35,
		0.60,
		resistance
	)

	return clampf(
		multiplier,
		0.60,
		1.35
	)


# ==================================================
# POOL-SITE SLOPE SUITABILITY
#
# We examine the current cell and the next downstream
# cell.
#
# This prevents a pool from being carved in the
# middle of a steep descent merely because that cell
# also happens to contain a bend or confluence.
#
# A pool can still occur immediately AFTER a steep
# descent if the downstream reach itself flattens.
# That gives us natural places for future plunge
# pools without treating the steep face as a pool.
# ==================================================

func _get_pool_slope_suitability(
	grid_x: int,
	grid_z: int
) -> float:
	var current_slope: float = maxf(
		_flow_map.get_slope(
			grid_x,
			grid_z
		),
		0.0
	)

	var downstream_slope: float = (
		current_slope
	)

	var downstream_position: Vector2i = (
		_flow_map.get_downstream_grid_position(
			grid_x,
			grid_z
		)
	)

	if downstream_position.x >= 0:
		downstream_slope = maxf(
			_flow_map.get_slope(
				downstream_position.x,
				downstream_position.y
			),
			0.0
		)

	# Require the reach itself to remain reasonably
	# gentle, not merely the single current cell.
	var local_grade: float = maxf(
		current_slope,
		downstream_slope
	)

	if local_grade <= POOL_FULL_SLOPE_GRADE:
		return 1.0

	if local_grade >= POOL_MAX_SLOPE_GRADE:
		return 0.0

	var fade: float = (
		_smoothstep(
			POOL_FULL_SLOPE_GRADE,
			POOL_MAX_SLOPE_GRADE,
			local_grade
		)
	)

	return (
		1.0
		- fade
	)


# ==================================================
# LOCAL POOLS / SCOUR HOLES
# ==================================================

func _get_local_scour_depth(
	grid_x: int,
	grid_z: int,
	channel_class: int
) -> float:
	var slope_suitability: float = (
		_get_pool_slope_suitability(
			grid_x,
			grid_z
		)
	)

	if slope_suitability <= 0.0:
		return 0.0

	var bend_strength: float = (
		_get_raw_bend_strength(
			grid_x,
			grid_z
		)
	)

	var confluence_strength: float = (
		_get_raw_confluence_strength(
			grid_x,
			grid_z
		)
	)

	var ordinary_pool_strength: float = (
		_get_raw_pool_sequence_strength(
			grid_x,
			grid_z
		)
	)

	var combined_strength: float = (
		1.0
		- (
			1.0
			- bend_strength
				* 0.95
		)
		* (
			1.0
			- confluence_strength
				* 0.90
		)
		* (
			1.0
			- ordinary_pool_strength
				* 0.48
		)
	)

	combined_strength = clampf(
		combined_strength,
		0.0,
		1.0
	)

	combined_strength *= (
		slope_suitability
	)

	if combined_strength <= 0.0:
		return 0.0

	var resistance: float = (
		_get_rock_resistance(
			grid_x,
			grid_z
		)
	)

	var softness: float = clampf(
		1.0
		- resistance,
		0.0,
		1.0
	)

	var material_multiplier: float = lerpf(
		0.55,
		1.45,
		softness
	)

	var maximum_extra_depth: float = (
		_get_maximum_local_pool_depth(
			channel_class
		)
	)

	return (
		maximum_extra_depth
		* combined_strength
		* material_multiplier
	)


func _get_maximum_local_pool_depth(
	channel_class: int
) -> float:
	match channel_class:
		Channels.CHANNEL_HEADWATER:
			return 0.65

		Channels.CHANNEL_SMALL_STREAM:
			return 1.40

		Channels.CHANNEL_STREAM:
			return 2.80

		Channels.CHANNEL_MAJOR:
			return 4.50

		_:
			return 0.0


# ==================================================
# DIAGNOSTIC STRENGTHS
#
# These are the functions world_preview.gd currently
# uses.
#
# They now include the same slope suitability rule as
# the real pool excavation.
#
# Therefore the diagnostic will no longer mark steep
# bends as potential swimming holes.
# ==================================================

func _get_bend_strength(
	grid_x: int,
	grid_z: int
) -> float:
	return (
		_get_raw_bend_strength(
			grid_x,
			grid_z
		)
		* _get_pool_slope_suitability(
			grid_x,
			grid_z
		)
	)


func _get_confluence_strength(
	grid_x: int,
	grid_z: int
) -> float:
	return (
		_get_raw_confluence_strength(
			grid_x,
			grid_z
		)
		* _get_pool_slope_suitability(
			grid_x,
			grid_z
		)
	)


func _get_pool_sequence_strength(
	grid_x: int,
	grid_z: int
) -> float:
	return (
		_get_raw_pool_sequence_strength(
			grid_x,
			grid_z
		)
		* _get_pool_slope_suitability(
			grid_x,
			grid_z
		)
	)


# ==================================================
# RAW BEND SCOUR
# ==================================================

func _get_raw_bend_strength(
	grid_x: int,
	grid_z: int
) -> float:
	var outgoing: Vector2 = (
		_get_flow_direction_unit(
			grid_x,
			grid_z
		)
	)

	if outgoing == Vector2.ZERO:
		return 0.0

	var bend_strength: float = 0.0

	var incoming: Vector2 = (
		_get_dominant_upstream_direction(
			grid_x,
			grid_z
		)
	)

	if incoming != Vector2.ZERO:
		bend_strength = maxf(
			bend_strength,
			_get_turn_strength(
				incoming,
				outgoing
			)
		)

	var downstream_position: Vector2i = (
		_flow_map.get_downstream_grid_position(
			grid_x,
			grid_z
		)
	)

	if downstream_position.x >= 0:
		var next_direction: Vector2 = (
			_get_flow_direction_unit(
				downstream_position.x,
				downstream_position.y
			)
		)

		if next_direction != Vector2.ZERO:
			bend_strength = maxf(
				bend_strength,
				_get_turn_strength(
					outgoing,
					next_direction
				)
			)

	return clampf(
		bend_strength,
		0.0,
		1.0
	)


func _get_turn_strength(
	direction_a: Vector2,
	direction_b: Vector2
) -> float:
	if (
		direction_a == Vector2.ZERO
		or direction_b == Vector2.ZERO
	):
		return 0.0

	var alignment: float = clampf(
		direction_a.dot(
			direction_b
		),
		-1.0,
		1.0
	)

	var raw_turn: float = (
		1.0
		- alignment
	)

	return clampf(
		raw_turn
		/ BEND_STRENGTH_NORMALIZER,
		0.0,
		1.0
	)


func _get_dominant_upstream_direction(
	grid_x: int,
	grid_z: int
) -> Vector2:
	var best_direction := Vector2.ZERO
	var best_accumulation: int = -1

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
					grid_x
					+ offset_x
				)
			)

			var neighbor_z: int = (
				_wrap_z(
					grid_z
					+ offset_z
				)
			)

			if (
				not _channel_network.is_channel(
					neighbor_x,
					neighbor_z
				)
			):
				continue

			var downstream: Vector2i = (
				_flow_map
					.get_downstream_grid_position(
						neighbor_x,
						neighbor_z
					)
			)

			if (
				downstream.x != grid_x
				or downstream.y != grid_z
			):
				continue

			var accumulation: int = (
				_accumulation_map
					.get_accumulation_cells(
						neighbor_x,
						neighbor_z
					)
			)

			if accumulation <= best_accumulation:
				continue

			var direction: Vector2i = (
				_flow_map.get_flow_direction(
					neighbor_x,
					neighbor_z
				)
			)

			if direction == Vector2i.ZERO:
				continue

			best_accumulation = (
				accumulation
			)

			best_direction = Vector2(
				float(direction.x),
				float(direction.y)
			).normalized()

	return best_direction


func _get_flow_direction_unit(
	grid_x: int,
	grid_z: int
) -> Vector2:
	var direction: Vector2i = (
		_flow_map.get_flow_direction(
			grid_x,
			grid_z
		)
	)

	if direction == Vector2i.ZERO:
		return Vector2.ZERO

	return Vector2(
		float(direction.x),
		float(direction.y)
	).normalized()


# ==================================================
# RAW CONFLUENCE SCOUR
# ==================================================

func _get_raw_confluence_strength(
	grid_x: int,
	grid_z: int
) -> float:
	var largest_upstream_area: float = 0.0
	var second_upstream_area: float = 0.0

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
					grid_x
					+ offset_x
				)
			)

			var neighbor_z: int = (
				_wrap_z(
					grid_z
					+ offset_z
				)
			)

			if (
				not _channel_network.is_channel(
					neighbor_x,
					neighbor_z
				)
			):
				continue

			var downstream: Vector2i = (
				_flow_map
					.get_downstream_grid_position(
						neighbor_x,
						neighbor_z
					)
			)

			if (
				downstream.x != grid_x
				or downstream.y != grid_z
			):
				continue

			var upstream_area: float = (
				_accumulation_map
					.get_drainage_area_square_kilometers(
						neighbor_x,
						neighbor_z
					)
			)

			if upstream_area > largest_upstream_area:
				second_upstream_area = (
					largest_upstream_area
				)

				largest_upstream_area = (
					upstream_area
				)

			elif upstream_area > second_upstream_area:
				second_upstream_area = (
					upstream_area
				)

	if second_upstream_area <= 0.0:
		return 0.0

	var current_area: float = (
		_accumulation_map
			.get_drainage_area_square_kilometers(
				grid_x,
				grid_z
			)
	)

	if current_area <= 0.0:
		return 0.0

	var tributary_ratio: float = (
		second_upstream_area
		/ current_area
	)

	return clampf(
		tributary_ratio
		/ 0.35,
		0.0,
		1.0
	)


# ==================================================
# RAW POOL / RIFFLE SEQUENCE
# ==================================================

func _get_raw_pool_sequence_strength(
	grid_x: int,
	grid_z: int
) -> float:
	if _pool_noise == null:
		return 0.0

	var world_position: Vector2 = (
		_surface_field.get_world_position(
			grid_x,
			grid_z
		)
	)

	var noise_value: float = (
		_pool_noise.get_noise_2d(
			world_position.x,
			world_position.y
		)
	)

	var normalized_noise: float = clampf(
		(
			noise_value
			+ 1.0
		)
		* 0.5,
		0.0,
		1.0
	)

	return _smoothstep(
		POOL_NOISE_START,
		POOL_NOISE_FULL,
		normalized_noise
	)


func _get_local_depth_variation(
	grid_x: int,
	grid_z: int
) -> float:
	if _pool_noise == null:
		return 1.0

	var world_position: Vector2 = (
		_surface_field.get_world_position(
			grid_x,
			grid_z
		)
	)

	var noise_value: float = (
		_pool_noise.get_noise_2d(
			world_position.x
				+ 1783.0,
			world_position.y
				- 941.0
		)
	)

	var normalized_noise: float = clampf(
		(
			noise_value
			+ 1.0
		)
		* 0.5,
		0.0,
		1.0
	)

	return lerpf(
		LOCAL_DEPTH_MIN_FACTOR,
		LOCAL_DEPTH_MAX_FACTOR,
		normalized_noise
	)


# ==================================================
# GEOLOGY
# ==================================================

func _get_rock_resistance(
	grid_x: int,
	grid_z: int
) -> float:
	var terrain_y: float = (
		_surface_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	var world_position: Vector2 = (
		_surface_field.get_world_position(
			grid_x,
			grid_z
		)
	)

	var geology_id: int = (
		_geology.get_geology_id(
			world_position.x,
			terrain_y - 0.1,
			world_position.y
		)
	)

	var resistance: float = (
		GeologyProps.get_erosion_resistance(
			geology_id
		)
	)

	return clampf(
		resistance,
		0.0,
		1.0
	)


# ==================================================
# WRAPPING
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
			value
			- edge_start
		)
		/ (
			edge_end
			- edge_start
		),
		0.0,
		1.0
	)

	return (
		normalized
		* normalized
		* (
			3.0
			- 2.0
				* normalized
		)
	)
