class_name ChannelGeometryModel
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


var _surface_field
var _flow_map
var _accumulation_map
var _channel_network
var _geology


func setup(
	world_definition: WorldDefinition,
	stratigraphy: StratigraphyProfile,
	surface_field,
	flow_map,
	accumulation_map,
	channel_network
) -> void:
	_surface_field = surface_field
	_flow_map = flow_map
	_accumulation_map = accumulation_map
	_channel_network = channel_network

	_geology = GeologySampler.new()
	_geology.setup(
		world_definition,
		stratigraphy
	)


func get_channel_bottom_half_width(
	grid_x: int,
	grid_z: int
) -> float:
	var channel_class: int = (
		_channel_network.get_channel_class(
			grid_x,
			grid_z
		)
	)

	if channel_class == Channels.CHANNEL_NONE:
		return 0.0

	var base_half_width: float = 0.0

	match channel_class:
		Channels.CHANNEL_HEADWATER:
			base_half_width = 0.4

		Channels.CHANNEL_SMALL_STREAM:
			base_half_width = 0.8

		Channels.CHANNEL_STREAM:
			base_half_width = 1.5

		Channels.CHANNEL_MAJOR:
			base_half_width = 2.5

	var drainage_multiplier: float = (
		_get_drainage_width_multiplier(
			grid_x,
			grid_z
		)
	)

	return (
		base_half_width
		* drainage_multiplier
	)


func get_valley_half_width(
	grid_x: int,
	grid_z: int
) -> float:
	var channel_class: int = (
		_channel_network.get_channel_class(
			grid_x,
			grid_z
		)
	)

	if channel_class == Channels.CHANNEL_NONE:
		return 0.0

	var base_half_width: float = 0.0

	match channel_class:
		Channels.CHANNEL_HEADWATER:
			base_half_width = 2.0

		Channels.CHANNEL_SMALL_STREAM:
			base_half_width = 4.0

		Channels.CHANNEL_STREAM:
			base_half_width = 7.0

		Channels.CHANNEL_MAJOR:
			base_half_width = 12.0

	var drainage_multiplier: float = (
		_get_drainage_width_multiplier(
			grid_x,
			grid_z
		)
	)

	var slope_multiplier: float = (
		_get_valley_slope_multiplier(
			grid_x,
			grid_z
		)
	)

	var rock_multiplier: float = (
		_get_valley_rock_multiplier(
			grid_x,
			grid_z
		)
	)

	var valley_half_width: float = (
		base_half_width
		* drainage_multiplier
		* slope_multiplier
		* rock_multiplier
	)

	return clampf(
		valley_half_width,
		1.5,
		28.0
	)


func get_bank_profile_exponent(
	grid_x: int,
	grid_z: int
) -> float:
	var geology_id: int = (
		_get_surface_geology_id(
			grid_x,
			grid_z
		)
	)

	var resistance: float = (
		GeologyProps.get_erosion_resistance(
			geology_id
		)
	)

	# Softer materials form smoother, broader banks.
	# Resistant rock tends toward tighter,
	# steeper-sided cuts.
	return lerpf(
		1.25,
		2.40,
		resistance
	)


func _get_drainage_width_multiplier(
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

	var multiplier: float = pow(
		normalized_area,
		0.16
	)

	return clampf(
		multiplier,
		1.0,
		1.8
	)


func _get_valley_slope_multiplier(
	grid_x: int,
	grid_z: int
) -> float:
	var slope: float = (
		_flow_map.get_slope(
			grid_x,
			grid_z
		)
	)

	# Low-gradient channels have more opportunity
	# for lateral erosion.
	#
	# Steep headwaters stay narrower and confined.

	var normalized_slope: float = clampf(
		slope / 1.5,
		0.0,
		1.0
	)

	return lerpf(
		1.20,
		0.78,
		normalized_slope
	)


func _get_valley_rock_multiplier(
	grid_x: int,
	grid_z: int
) -> float:
	var geology_id: int = (
		_get_surface_geology_id(
			grid_x,
			grid_z
		)
	)

	var resistance: float = (
		GeologyProps.get_erosion_resistance(
			geology_id
		)
	)

	# Weak rock permits more lateral erosion.
	# Resistant rock confines the valley.

	return lerpf(
		1.20,
		0.75,
		resistance
	)


func _get_surface_geology_id(
	grid_x: int,
	grid_z: int
) -> int:
	var world_position: Vector2 = (
		_surface_field.get_world_position(
			grid_x,
			grid_z
		)
	)

	var surface_y: float = (
		_surface_field.get_height_at_grid(
			grid_x,
			grid_z
		)
	)

	return _geology.get_geology_id(
		world_position.x,
		surface_y - 0.1,
		world_position.y
	)
