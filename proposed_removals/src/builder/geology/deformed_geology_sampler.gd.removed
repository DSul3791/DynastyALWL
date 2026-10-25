class_name DeformedGeologySampler
extends RefCounted


const Geology := preload(
	"res://src/shared/geology_ids.gd"
)

const StratigraphySamplerScript := preload(
	"res://src/builder/geology/stratigraphy_sampler.gd"
)

const TectonicDeformationScript := preload(
	"res://src/builder/geology/tectonic_deformation.gd"
)

const FoldDeformationScript := preload(
	"res://src/builder/geology/fold_deformation.gd"
)

const FaultDeformationScript := preload(
	"res://src/builder/geology/fault_deformation.gd"
)

const IgneousIntrusionsScript := preload(
	"res://src/builder/geology/igneous_intrusions.gd"
)


var _world: WorldDefinition
var _stratigraphy: StratigraphyProfile

var _stratigraphy_sampler
var _tectonics
var _folding
var _faulting
var _intrusions


func setup(
	world_definition: WorldDefinition,
	stratigraphy: StratigraphyProfile
) -> void:
	_world = world_definition
	_stratigraphy = stratigraphy

	_stratigraphy_sampler = (
		StratigraphySamplerScript.new()
	)

	_stratigraphy_sampler.setup(
		_stratigraphy
	)

	_tectonics = (
		TectonicDeformationScript.new()
	)

	_tectonics.setup(
		_world
	)

	_folding = (
		FoldDeformationScript.new()
	)

	_folding.setup(
		_world
	)

	_faulting = (
		FaultDeformationScript.new()
	)

	_faulting.setup(
		_world
	)

	_intrusions = (
		IgneousIntrusionsScript.new()
	)

	_intrusions.setup(
		_world
	)


# ==================================================
# ISLAND-LOCAL GEOLOGY
#
# The original 4 km test world shifted the master
# terrain by half a world, placing one mountain across
# four wrapped corners.
#
# Modular islands keep the same geology centered
# inside every tile instead.
# ==================================================

func get_master_coordinates(
	x: float,
	z: float
) -> Vector2:
	return Vector2(
		_map_x_to_master(
			x
		),
		_map_z_to_master(
			z
		)
	)


func _map_x_to_master(
	x: float
) -> float:
	if _world == null:
		return x

	return (
		_world.to_island_local_x(
			x
		)
	)


func _map_z_to_master(
	z: float
) -> float:
	if _world == null:
		return z

	return (
		_world.to_island_local_z(
			z
		)
	)


# ==================================================
# DEFORMATION
# ==================================================

func get_regional_uplift(
	x: float,
	z: float
) -> float:
	if _tectonics == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_tectonics
			.get_vertical_displacement(
				master.x,
				master.y
			)
	)


func get_fold_displacement(
	x: float,
	z: float
) -> float:
	if _folding == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_folding
			.get_vertical_displacement(
				master.x,
				master.y
			)
	)


func get_fault_displacement(
	x: float,
	z: float
) -> float:
	if _faulting == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_faulting
			.get_vertical_displacement(
				master.x,
				master.y
			)
	)


func get_total_deformation(
	x: float,
	z: float
) -> float:
	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_get_master_total_deformation(
			master.x,
			master.y
		)
	)


func _get_master_total_deformation(
	master_x: float,
	master_z: float
) -> float:
	var regional: float = 0.0
	var folding: float = 0.0
	var faulting: float = 0.0

	if _tectonics != null:
		regional = (
			_tectonics
				.get_vertical_displacement(
					master_x,
					master_z
				)
		)

	if _folding != null:
		folding = (
			_folding
				.get_vertical_displacement(
					master_x,
					master_z
				)
		)

	if _faulting != null:
		faulting = (
			_faulting
				.get_vertical_displacement(
					master_x,
					master_z
				)
		)

	return (
		regional
		+ folding
		+ faulting
	)


# ==================================================
# PRE-DEFORMATION Y
#
# Existing strata, coal, shallow pluton and shallow
# dike existed before uplift/folding/fault movement.
#
# To sample them we undo the total vertical
# deformation.
# ==================================================

func get_pre_deformation_y(
	x: float,
	y: float,
	z: float
) -> float:
	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	var deformation: float = (
		_get_master_total_deformation(
			master.x,
			master.y
		)
	)

	return (
		y
		- deformation
	)


# ==================================================
# GEOLOGICAL COLUMN TOP
# ==================================================

func get_column_top_y(
	x: float,
	z: float
) -> float:
	if _world == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		get_master_column_top_y(
			master.x,
			master.y
		)
	)


func get_master_column_top_y(
	master_x: float,
	master_z: float
) -> float:
	if _world == null:
		return 0.0

	return (
		_world.stratigraphy_reference_y_meters
		+ _get_master_total_deformation(
			master_x,
			master_z
		)
	)


# ==================================================
# FAULT INFORMATION
# ==================================================

func get_fault_zone_strength(
	x: float,
	z: float
) -> float:
	if _faulting == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_faulting
			.get_fault_zone_strength(
				master.x,
				master.y
			)
	)


# ==================================================
# DEEP INTRUSION INFORMATION
#
# These are later tectonic structures.
# Their Y coordinate is therefore the final world Y,
# not the pre-deformation Y.
# ==================================================

func is_deep_intrusion(
	x: float,
	y: float,
	z: float
) -> bool:
	if _intrusions == null:
		return false

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_intrusions
			.is_deep_intrusion(
				master.x,
				y,
				master.y
			)
	)


func get_deep_intrusion_strength(
	x: float,
	y: float,
	z: float
) -> float:
	if _intrusions == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_intrusions
			.get_deep_intrusion_strength(
				master.x,
				y,
				master.y
			)
	)


func get_deep_contact_strength(
	x: float,
	y: float,
	z: float
) -> float:
	if _intrusions == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_intrusions
			.get_deep_contact_strength(
				master.x,
				y,
				master.y
			)
	)


func get_deep_feeder_strength(
	x: float,
	y: float,
	z: float
) -> float:
	if _intrusions == null:
		return 0.0

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_intrusions
			.get_deep_feeder_strength(
				master.x,
				y,
				master.y
			)
	)


# ==================================================
# SHALLOW INTRUSION COLUMN DATA
# ==================================================

func get_pluton_dx_squared(
	x: float
) -> float:
	if _intrusions == null:
		return 0.0

	var master_x: float = (
		_map_x_to_master(
			x
		)
	)

	return (
		_intrusions
			.get_pluton_dx_squared(
				master_x
			)
	)


func get_pluton_dz_squared(
	z: float
) -> float:
	if _intrusions == null:
		return 0.0

	var master_z: float = (
		_map_z_to_master(
			z
		)
	)

	return (
		_intrusions
			.get_pluton_dz_squared(
				master_z
			)
	)


func is_dike_column_active(
	x: float,
	z: float
) -> bool:
	if _intrusions == null:
		return false

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	return (
		_intrusions
			.is_dike_column_active(
				master.x,
				master.y
			)
	)


# ==================================================
# NORMAL GEOLOGY ENTRY POINT
# ==================================================

func get_geology_id(
	x: float,
	y: float,
	z: float
) -> int:
	if (
		_stratigraphy_sampler == null
		or _world == null
	):
		return Geology.AIR

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	var deformation: float = (
		_get_master_total_deformation(
			master.x,
			master.y
		)
	)

	var original_y: float = (
		y
		- deformation
	)

	return (
		_get_geology_id_master(
			master.x,
			original_y,
			master.y
		)
	)


func get_geology_id_with_column_top(
	x: float,
	y: float,
	z: float,
	column_top_y: float
) -> int:
	if (
		_stratigraphy_sampler == null
		or _world == null
	):
		return Geology.AIR

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	var deformation: float = (
		column_top_y
		- _world.stratigraphy_reference_y_meters
	)

	var original_y: float = (
		y
		- deformation
	)

	return (
		_get_geology_id_master(
			master.x,
			original_y,
			master.y
		)
	)


func _get_geology_id_master(
	master_x: float,
	original_y: float,
	master_z: float
) -> int:
	var reference_top_y: float = (
		_world.stratigraphy_reference_y_meters
	)

	var base_geology_id: int = (
		_stratigraphy_sampler
			.get_geology_id_at_elevation(
				original_y,
				reference_top_y
			)
	)

	if base_geology_id == Geology.AIR:
		return Geology.AIR

	if base_geology_id == Geology.GRANITE:
		return Geology.GRANITE

	if _intrusions != null:
		var pluton_dx_squared: float = (
			_intrusions
				.get_pluton_dx_squared(
					master_x
				)
		)

		var pluton_dz_squared: float = (
			_intrusions
				.get_pluton_dz_squared(
					master_z
				)
		)

		var dike_active: bool = (
			_intrusions
				.is_dike_column_active(
					master_x,
					master_z
				)
		)

		if (
			_intrusions
				.is_intrusive_granite_with_column_data(
					original_y,
					pluton_dx_squared,
					pluton_dz_squared,
					dike_active
				)
		):
			return Geology.GRANITE

	return base_geology_id


# ==================================================
# PRECOMPUTED-COLUMN GEOLOGY PATH
#
# Used by the voxel baker.
# ==================================================

func get_geology_id_with_column_data(
	y: float,
	column_top_y: float,
	pluton_dx_squared: float,
	pluton_dz_squared: float,
	dike_active: bool
) -> int:
	if (
		_stratigraphy_sampler == null
		or _world == null
	):
		return Geology.AIR

	var deformation: float = (
		column_top_y
		- _world.stratigraphy_reference_y_meters
	)

	var original_y: float = (
		y
		- deformation
	)

	var reference_top_y: float = (
		_world.stratigraphy_reference_y_meters
	)

	var base_geology_id: int = (
		_stratigraphy_sampler
			.get_geology_id_at_elevation(
				original_y,
				reference_top_y
			)
	)

	if base_geology_id == Geology.AIR:
		return Geology.AIR

	if base_geology_id == Geology.GRANITE:
		return Geology.GRANITE

	if (
		_intrusions != null
		and _intrusions
			.is_intrusive_granite_with_column_data(
				original_y,
				pluton_dx_squared,
				pluton_dz_squared,
				dike_active
			)
	):
		return Geology.GRANITE

	return base_geology_id


# ==================================================
# REFERENCE GEOLOGY PATH
# ==================================================

func get_geology_id_with_column_top_reference(
	x: float,
	y: float,
	z: float,
	column_top_y: float
) -> int:
	if (
		_stratigraphy_sampler == null
		or _world == null
	):
		return Geology.AIR

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	var deformation: float = (
		column_top_y
		- _world.stratigraphy_reference_y_meters
	)

	var original_y: float = (
		y
		- deformation
	)

	var reference_top_y: float = (
		_world.stratigraphy_reference_y_meters
	)

	var base_geology_id: int = (
		_stratigraphy_sampler
			.get_geology_id_at_elevation_reference(
				original_y,
				reference_top_y
			)
	)

	if base_geology_id == Geology.AIR:
		return Geology.AIR

	if (
		_intrusions != null
		and _intrusions
			.is_intrusive_granite_reference(
				master.x,
				original_y,
				master.y
			)
	):
		return Geology.GRANITE

	return base_geology_id


# ==================================================
# LAYER NAME
# ==================================================

func get_layer_name(
	x: float,
	y: float,
	z: float
) -> String:
	if (
		_stratigraphy_sampler == null
		or _world == null
	):
		return "Invalid"

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	var deformation: float = (
		_get_master_total_deformation(
			master.x,
			master.y
		)
	)

	var original_y: float = (
		y
		- deformation
	)

	var reference_top_y: float = (
		_world.stratigraphy_reference_y_meters
	)

	var depth_meters: float = (
		reference_top_y
		- original_y
	)

	if depth_meters < 0.0:
		return "Air"

	if _intrusions != null:
		var pluton_dx_squared: float = (
			_intrusions
				.get_pluton_dx_squared(
					master.x
				)
		)

		var pluton_dz_squared: float = (
			_intrusions
				.get_pluton_dz_squared(
					master.y
				)
		)

		var dike_active: bool = (
			_intrusions
				.is_dike_column_active(
					master.x,
					master.y
				)
		)

		if (
			_intrusions
				.is_intrusive_granite_with_column_data(
					original_y,
					pluton_dx_squared,
					pluton_dz_squared,
					dike_active
				)
		):
			return "Granite Intrusion"

		if (
			_intrusions
				.is_deep_intrusion(
					master.x,
					y,
					master.y
				)
		):
			return "Deep Intrusive System"

	return (
		_stratigraphy_sampler
			.get_layer_name_at_depth(
				depth_meters
			)
	)


func get_layer_elevation_at_depth(
	x: float,
	z: float,
	depth_meters: float
) -> float:
	return (
		get_column_top_y(
			x,
			z
		)
		- depth_meters
	)


# ==================================================
# INTRUSION QUERY
# ==================================================

func is_intrusive_granite(
	x: float,
	y: float,
	z: float
) -> bool:
	if (
		_intrusions == null
		or _world == null
	):
		return false

	var master: Vector2 = (
		get_master_coordinates(
			x,
			z
		)
	)

	var deformation: float = (
		_get_master_total_deformation(
			master.x,
			master.y
		)
	)

	var original_y: float = (
		y
		- deformation
	)

	var pluton_dx_squared: float = (
		_intrusions
			.get_pluton_dx_squared(
				master.x
			)
	)

	var pluton_dz_squared: float = (
		_intrusions
			.get_pluton_dz_squared(
				master.y
			)
	)

	var dike_active: bool = (
		_intrusions
			.is_dike_column_active(
				master.x,
				master.y
			)
	)

	var shallow_intrusion: bool = (
		_intrusions
			.is_intrusive_granite_with_column_data(
				original_y,
				pluton_dx_squared,
				pluton_dz_squared,
				dike_active
			)
	)

	if shallow_intrusion:
		return true

	return (
		_intrusions
			.is_deep_intrusion(
				master.x,
				y,
				master.y
			)
	)
