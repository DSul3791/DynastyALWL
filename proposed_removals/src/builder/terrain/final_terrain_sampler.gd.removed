class_name FinalTerrainSampler
extends RefCounted


const Geology := preload(
	"res://src/shared/geology_ids.gd"
)

const Deposits := preload(
	"res://src/shared/surficial_deposit_ids.gd"
)


var _world_definition
var _geology_sampler
var _terrain_field
var _deposit_map

var _width: int = 0
var _depth: int = 0
var _spacing_meters: float = 1.0

var _min_x: float = 0.0
var _max_x: float = 0.0
var _min_z: float = 0.0
var _max_z: float = 0.0

var _world_width_meters: float = 0.0
var _world_depth_meters: float = 0.0


func setup(
	world_definition,
	geology_sampler,
	terrain_field,
	deposit_map
) -> void:
	_world_definition = world_definition
	_geology_sampler = geology_sampler
	_terrain_field = terrain_field
	_deposit_map = deposit_map

	_width = _terrain_field.get_width()
	_depth = _terrain_field.get_depth()

	_spacing_meters = (
		_terrain_field.get_spacing_meters()
	)

	_min_x = float(
		_world_definition.get_min_x()
	)

	_max_x = float(
		_world_definition.get_max_x()
	)

	_min_z = float(
		_world_definition.get_min_z()
	)

	_max_z = float(
		_world_definition.get_max_z()
	)

	_world_width_meters = (
		_max_x - _min_x
	)

	_world_depth_meters = (
		_max_z - _min_z
	)


# ==================================================
# FINAL TERRAIN SURFACE
#
# _terrain_field is the finished fluvial surface:
#
# swapped geology
# -> seam reconciliation
# -> central lake carve
# -> broad erosion
# -> river incision
#
# Coordinates wrap horizontally.
#
# The planning grid contains unique toroidal samples.
# There is no duplicated +X/+Z boundary sample.
# ==================================================

func get_surface_y(
	world_x: float,
	world_z: float
) -> float:
	if (
		_width <= 0
		or _depth <= 0
		or _spacing_meters <= 0.0
	):
		return 0.0

	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	var grid_x_float: float = (
		(wrapped_x - _min_x)
		/ _spacing_meters
	)

	var grid_z_float: float = (
		(wrapped_z - _min_z)
		/ _spacing_meters
	)

	var grid_x0: int = posmod(
		int(
			floor(
				grid_x_float
			)
		),
		_width
	)

	var grid_z0: int = posmod(
		int(
			floor(
				grid_z_float
			)
		),
		_depth
	)

	# Toroidal interpolation:
	#
	# 510 -> 511
	# 511 -> 0
	var grid_x1: int = posmod(
		grid_x0 + 1,
		_width
	)

	var grid_z1: int = posmod(
		grid_z0 + 1,
		_depth
	)

	var fraction_x: float = (
		grid_x_float
		- floor(
			grid_x_float
		)
	)

	var fraction_z: float = (
		grid_z_float
		- floor(
			grid_z_float
		)
	)

	var height_00: float = (
		_terrain_field.get_height_at_grid(
			grid_x0,
			grid_z0
		)
	)

	var height_10: float = (
		_terrain_field.get_height_at_grid(
			grid_x1,
			grid_z0
		)
	)

	var height_01: float = (
		_terrain_field.get_height_at_grid(
			grid_x0,
			grid_z1
		)
	)

	var height_11: float = (
		_terrain_field.get_height_at_grid(
			grid_x1,
			grid_z1
		)
	)

	var lower_height: float = lerpf(
		height_00,
		height_10,
		fraction_x
	)

	var upper_height: float = lerpf(
		height_01,
		height_11,
		fraction_x
	)

	return lerpf(
		lower_height,
		upper_height,
		fraction_z
	)


# ==================================================
# SURFICIAL DEPOSITS
# ==================================================

func get_deposit_id(
	world_x: float,
	world_z: float
) -> int:
	var grid_position: Vector2i = (
		_get_nearest_grid_position(
			world_x,
			world_z
		)
	)

	return (
		_deposit_map.get_deposit_id(
			grid_position.x,
			grid_position.y
		)
	)


func get_deposit_thickness(
	world_x: float,
	world_z: float
) -> float:
	var grid_position: Vector2i = (
		_get_nearest_grid_position(
			world_x,
			world_z
		)
	)

	return (
		_deposit_map.get_deposit_thickness(
			grid_position.x,
			grid_position.y
		)
	)


func get_deposit_column(
	world_x: float,
	world_z: float
) -> Vector2:
	var grid_position: Vector2i = (
		_get_nearest_grid_position(
			world_x,
			world_z
		)
	)

	var deposit_id: int = (
		_deposit_map.get_deposit_id(
			grid_position.x,
			grid_position.y
		)
	)

	var thickness: float = (
		_deposit_map.get_deposit_thickness(
			grid_position.x,
			grid_position.y
		)
	)

	return Vector2(
		float(deposit_id),
		thickness
	)


func get_deposit_base_y(
	world_x: float,
	world_z: float
) -> float:
	return (
		get_surface_y(
			world_x,
			world_z
		)
		- get_deposit_thickness(
			world_x,
			world_z
		)
	)


# ==================================================
# SOLID TERRAIN
# ==================================================

func is_solid(
	world_x: float,
	world_y: float,
	world_z: float
) -> bool:
	return (
		world_y
		<= get_surface_y(
			world_x,
			world_z
		)
	)


func is_surficial_deposit(
	world_x: float,
	world_y: float,
	world_z: float
) -> bool:
	if not is_solid(
		world_x,
		world_y,
		world_z
	):
		return false

	var deposit_id: int = (
		get_deposit_id(
			world_x,
			world_z
		)
	)

	if deposit_id == Deposits.NONE:
		return false

	var thickness: float = (
		get_deposit_thickness(
			world_x,
			world_z
		)
	)

	if thickness <= 0.0:
		return false

	var surface_y: float = (
		get_surface_y(
			world_x,
			world_z
		)
	)

	return (
		world_y
		>= surface_y - thickness
	)


func get_surficial_deposit_id_at(
	world_x: float,
	world_y: float,
	world_z: float
) -> int:
	if not is_surficial_deposit(
		world_x,
		world_y,
		world_z
	):
		return Deposits.NONE

	return get_deposit_id(
		world_x,
		world_z
	)


# ==================================================
# GEOLOGY
# ==================================================

func get_geology_id_at(
	world_x: float,
	world_y: float,
	world_z: float
) -> int:
	if not is_solid(
		world_x,
		world_y,
		world_z
	):
		return Geology.AIR

	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	return (
		_geology_sampler.get_geology_id(
			wrapped_x,
			world_y,
			wrapped_z
		)
	)


func get_solid_geology_id_at(
	world_x: float,
	world_y: float,
	world_z: float
) -> int:
	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	return (
		_geology_sampler.get_geology_id(
			wrapped_x,
			world_y,
			wrapped_z
		)
	)


func get_geology_column_top_y(
	world_x: float,
	world_z: float
) -> float:
	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	return (
		_geology_sampler.get_column_top_y(
			wrapped_x,
			wrapped_z
		)
	)


func get_solid_geology_id_with_column_top(
	world_x: float,
	world_y: float,
	world_z: float,
	column_top_y: float
) -> int:
	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	return (
		_geology_sampler
		.get_geology_id_with_column_top(
			wrapped_x,
			world_y,
			wrapped_z,
			column_top_y
		)
	)


# ==================================================
# PRECOMPUTED INTRUSION COLUMN DATA
# ==================================================

func get_geology_pluton_dx_squared(
	world_x: float
) -> float:
	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	return (
		_geology_sampler
		.get_pluton_dx_squared(
			wrapped_x
		)
	)


func get_geology_pluton_dz_squared(
	world_z: float
) -> float:
	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	return (
		_geology_sampler
		.get_pluton_dz_squared(
			wrapped_z
		)
	)


func is_geology_dike_column_active(
	world_x: float,
	world_z: float
) -> bool:
	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	return (
		_geology_sampler
		.is_dike_column_active(
			wrapped_x,
			wrapped_z
		)
	)


func get_solid_geology_id_with_column_data(
	world_y: float,
	column_top_y: float,
	pluton_dx_squared: float,
	pluton_dz_squared: float,
	dike_active: bool
) -> int:
	return (
		_geology_sampler
		.get_geology_id_with_column_data(
			world_y,
			column_top_y,
			pluton_dx_squared,
			pluton_dz_squared,
			dike_active
		)
	)


func get_exposed_geology_id(
	world_x: float,
	world_z: float
) -> int:
	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	var surface_y: float = (
		get_surface_y(
			wrapped_x,
			wrapped_z
		)
	)

	return (
		_geology_sampler.get_geology_id(
			wrapped_x,
			surface_y - 0.1,
			wrapped_z
		)
	)


# ==================================================
# WORLD WRAPPING
# ==================================================

func _wrap_world_x(
	world_x: float
) -> float:
	if _world_width_meters <= 0.0:
		return _min_x

	return (
		_min_x
		+ fposmod(
			world_x - _min_x,
			_world_width_meters
		)
	)


func _wrap_world_z(
	world_z: float
) -> float:
	if _world_depth_meters <= 0.0:
		return _min_z

	return (
		_min_z
		+ fposmod(
			world_z - _min_z,
			_world_depth_meters
		)
	)


# ==================================================
# GRID LOOKUP
#
# Nearest-neighbor lookup must wrap as well.
#
# Near the +X/+Z edge, rounding can legitimately
# produce index 512. On the torus, index 512 is index 0.
# ==================================================

func _get_nearest_grid_position(
	world_x: float,
	world_z: float
) -> Vector2i:
	if (
		_width <= 0
		or _depth <= 0
		or _spacing_meters <= 0.0
	):
		return Vector2i.ZERO

	var wrapped_x: float = (
		_wrap_world_x(
			world_x
		)
	)

	var wrapped_z: float = (
		_wrap_world_z(
			world_z
		)
	)

	var grid_x_float: float = (
		(wrapped_x - _min_x)
		/ _spacing_meters
	)

	var grid_z_float: float = (
		(wrapped_z - _min_z)
		/ _spacing_meters
	)

	var grid_x: int = posmod(
		int(
			floor(
				grid_x_float + 0.5
			)
		),
		_width
	)

	var grid_z: int = posmod(
		int(
			floor(
				grid_z_float + 0.5
			)
		),
		_depth
	)

	return Vector2i(
		grid_x,
		grid_z
	)
