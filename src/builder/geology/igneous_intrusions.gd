class_name IgneousIntrusions
extends RefCounted


# ==================================================
# EXISTING SHALLOW PLUTON
# ==================================================

const PLUTON_CENTER_X: float = -170.0
const PLUTON_CENTER_Y: float = -310.0
const PLUTON_CENTER_Z: float = 170.0

const PLUTON_RADIUS_X: float = 230.0
const PLUTON_RADIUS_Y: float = 360.0
const PLUTON_RADIUS_Z: float = 190.0

const PLUTON_MIN_Y: float = (
	PLUTON_CENTER_Y
	- PLUTON_RADIUS_Y
)

const PLUTON_MAX_Y: float = (
	PLUTON_CENTER_Y
	+ PLUTON_RADIUS_Y
)


# ==================================================
# EXISTING SHALLOW DIKE
# ==================================================

const DIKE_Z_FACTOR: float = 0.28
const DIKE_OFFSET: float = 120.0
const DIKE_HALF_WIDTH: float = 5.0

const DIKE_MIN_Y: float = -900.0
const DIKE_MAX_Y: float = 220.0


# ==================================================
# DEEP INTRUSIVE SYSTEM A
#
# Large felsic batholith.
#
# This gives copper/tin/gold systems a real geological
# structure well below 1000 m.
# ==================================================

const DEEP_A_CENTER_X: float = 620.0
const DEEP_A_CENTER_Y: float = -2200.0
const DEEP_A_CENTER_Z: float = -480.0

const DEEP_A_RADIUS_X: float = 520.0
const DEEP_A_RADIUS_Y: float = 1050.0
const DEEP_A_RADIUS_Z: float = 440.0


# ==================================================
# DEEP INTRUSIVE SYSTEM B
#
# Separate older deep intrusive center.
# ==================================================

const DEEP_B_CENTER_X: float = -980.0
const DEEP_B_CENTER_Y: float = -3050.0
const DEEP_B_CENTER_Z: float = 760.0

const DEEP_B_RADIUS_X: float = 420.0
const DEEP_B_RADIUS_Y: float = 720.0
const DEEP_B_RADIUS_Z: float = 360.0


# ==================================================
# DEEP FEEDER / FRACTURE ZONE
#
# Narrow structural corridor connecting deep crustal
# levels upward.
# ==================================================

const DEEP_FEEDER_HALF_WIDTH: float = 14.0
const DEEP_FEEDER_MIN_Y: float = -3600.0
const DEEP_FEEDER_MAX_Y: float = -650.0


var _world: WorldDefinition


func setup(
	world_definition: WorldDefinition
) -> void:
	_world = world_definition


# ==================================================
# NORMAL ENTRY POINT
# ==================================================

func is_intrusive_granite(
	x: float,
	y: float,
	z: float
) -> bool:
	if _world == null:
		return false

	var pluton_dx_squared: float = (
		get_pluton_dx_squared(
			x
		)
	)

	var pluton_dz_squared: float = (
		get_pluton_dz_squared(
			z
		)
	)

	var dike_active: bool = (
		is_dike_column_active(
			x,
			z
		)
	)

	if is_intrusive_granite_with_column_data(
		y,
		pluton_dx_squared,
		pluton_dz_squared,
		dike_active
	):
		return true

	if is_deep_intrusion(
		x,
		y,
		z
	):
		return true

	return false


# ==================================================
# EXISTING X/Z COLUMN DATA
# ==================================================

func get_pluton_dx_squared(
	x: float
) -> float:
	var dx: float = (
		(x - PLUTON_CENTER_X)
		/ PLUTON_RADIUS_X
	)

	return dx * dx


func get_pluton_dz_squared(
	z: float
) -> float:
	var dz: float = (
		(z - PLUTON_CENTER_Z)
		/ PLUTON_RADIUS_Z
	)

	return dz * dz


func is_dike_column_active(
	x: float,
	z: float
) -> bool:
	var dike_coordinate: float = (
		x
		- z * DIKE_Z_FACTOR
		+ DIKE_OFFSET
	)

	return (
		absf(
			dike_coordinate
		)
		<= DIKE_HALF_WIDTH
	)


# ==================================================
# EXISTING PRECOMPUTED COLUMN ENTRY POINT
# ==================================================

func is_intrusive_granite_with_column_data(
	y: float,
	pluton_dx_squared: float,
	pluton_dz_squared: float,
	dike_active: bool
) -> bool:
	if _world == null:
		return false

	if (
		y >= PLUTON_MIN_Y
		and y <= PLUTON_MAX_Y
		and pluton_dx_squared <= 1.0
		and pluton_dz_squared <= 1.0
	):
		var dy: float = (
			(y - PLUTON_CENTER_Y)
			/ PLUTON_RADIUS_Y
		)

		var ellipsoid_distance: float = (
			pluton_dx_squared
			+ dy * dy
			+ pluton_dz_squared
		)

		if ellipsoid_distance <= 1.0:
			return true

	if (
		dike_active
		and y >= DIKE_MIN_Y
		and y <= DIKE_MAX_Y
	):
		return true

	return false


# ==================================================
# DEEP INTRUSIONS
# ==================================================

func is_deep_intrusion(
	x: float,
	y: float,
	z: float
) -> bool:
	if _world == null:
		return false

	if _get_deep_a_distance_squared(
		x,
		y,
		z
	) <= 1.0:
		return true

	if _get_deep_b_distance_squared(
		x,
		y,
		z
	) <= 1.0:
		return true

	if is_deep_feeder(
		x,
		y,
		z
	):
		return true

	return false


func is_deep_feeder(
	x: float,
	y: float,
	z: float
) -> bool:
	if (
		y < DEEP_FEEDER_MIN_Y
		or y > DEEP_FEEDER_MAX_Y
	):
		return false

	var feeder_coordinate: float = (
		x
		+ z * 0.42
		- 260.0
	)

	return (
		absf(
			feeder_coordinate
		)
		<= DEEP_FEEDER_HALF_WIDTH
	)


# ==================================================
# INTRUSION STRENGTH
#
# 1.0 near the center of an intrusive system.
# Falls toward zero at the edge.
#
# Mineral generation will use this later.
# ==================================================

func get_deep_intrusion_strength(
	x: float,
	y: float,
	z: float
) -> float:
	var strength_a: float = (
		_distance_to_strength(
			_get_deep_a_distance_squared(
				x,
				y,
				z
			)
		)
	)

	var strength_b: float = (
		_distance_to_strength(
			_get_deep_b_distance_squared(
				x,
				y,
				z
			)
		)
	)

	var feeder_strength: float = (
		get_deep_feeder_strength(
			x,
			y,
			z
		)
	)

	return maxf(
		maxf(
			strength_a,
			strength_b
		),
		feeder_strength
	)


func get_deep_feeder_strength(
	x: float,
	y: float,
	z: float
) -> float:
	if (
		y < DEEP_FEEDER_MIN_Y
		or y > DEEP_FEEDER_MAX_Y
	):
		return 0.0

	var feeder_coordinate: float = absf(
		x
		+ z * 0.42
		- 260.0
	)

	var influence_width: float = 90.0

	return clampf(
		1.0
		- feeder_coordinate
			/ influence_width,
		0.0,
		1.0
	)


# ==================================================
# CONTACT ZONE
#
# Highest near the outside edge of the deep plutons.
#
# Useful for hydrothermal copper/tin/gold deposits.
# ==================================================

func get_deep_contact_strength(
	x: float,
	y: float,
	z: float
) -> float:
	var contact_a: float = (
		_get_contact_strength_from_distance(
			_get_deep_a_distance_squared(
				x,
				y,
				z
			)
		)
	)

	var contact_b: float = (
		_get_contact_strength_from_distance(
			_get_deep_b_distance_squared(
				x,
				y,
				z
			)
		)
	)

	return maxf(
		contact_a,
		contact_b
	)


# ==================================================
# DEEP BODY GEOMETRY
# ==================================================

func _get_deep_a_distance_squared(
	x: float,
	y: float,
	z: float
) -> float:
	var dx: float = (
		(x - DEEP_A_CENTER_X)
		/ DEEP_A_RADIUS_X
	)

	var dy: float = (
		(y - DEEP_A_CENTER_Y)
		/ DEEP_A_RADIUS_Y
	)

	var dz: float = (
		(z - DEEP_A_CENTER_Z)
		/ DEEP_A_RADIUS_Z
	)

	return (
		dx * dx
		+ dy * dy
		+ dz * dz
	)


func _get_deep_b_distance_squared(
	x: float,
	y: float,
	z: float
) -> float:
	var dx: float = (
		(x - DEEP_B_CENTER_X)
		/ DEEP_B_RADIUS_X
	)

	var dy: float = (
		(y - DEEP_B_CENTER_Y)
		/ DEEP_B_RADIUS_Y
	)

	var dz: float = (
		(z - DEEP_B_CENTER_Z)
		/ DEEP_B_RADIUS_Z
	)

	return (
		dx * dx
		+ dy * dy
		+ dz * dz
	)


func _distance_to_strength(
	distance_squared: float
) -> float:
	if distance_squared >= 1.0:
		return 0.0

	var distance: float = sqrt(
		maxf(
			distance_squared,
			0.0
		)
	)

	return clampf(
		1.0 - distance,
		0.0,
		1.0
	)


func _get_contact_strength_from_distance(
	distance_squared: float
) -> float:
	var distance: float = sqrt(
		maxf(
			distance_squared,
			0.0
		)
	)

	var distance_from_contact: float = absf(
		distance - 1.0
	)

	var contact_width: float = 0.22

	return clampf(
		1.0
		- distance_from_contact
			/ contact_width,
		0.0,
		1.0
	)


# ==================================================
# ORIGINAL REFERENCE ENTRY POINT
#
# Kept so existing validation/reference code still
# has the original shallow implementation available.
# ==================================================

func is_intrusive_granite_reference(
	x: float,
	y: float,
	z: float
) -> bool:
	if _world == null:
		return false

	if _is_main_pluton_reference(
		x,
		y,
		z
	):
		return true

	if _is_granite_dike_reference(
		x,
		y,
		z
	):
		return true

	return false


func _is_main_pluton_reference(
	x: float,
	y: float,
	z: float
) -> bool:
	var center_x: float = -170.0
	var center_y: float = -310.0
	var center_z: float = 170.0

	var radius_x: float = 230.0
	var radius_y: float = 360.0
	var radius_z: float = 190.0

	var dx: float = (
		(x - center_x)
		/ radius_x
	)

	var dy: float = (
		(y - center_y)
		/ radius_y
	)

	var dz: float = (
		(z - center_z)
		/ radius_z
	)

	var ellipsoid_distance: float = (
		dx * dx
		+ dy * dy
		+ dz * dz
	)

	return (
		ellipsoid_distance
		<= 1.0
	)


func _is_granite_dike_reference(
	x: float,
	y: float,
	z: float
) -> bool:
	var dike_coordinate: float = (
		x
		- z * 0.28
		+ 120.0
	)

	var half_width: float = 5.0

	if (
		absf(
			dike_coordinate
		)
		> half_width
	):
		return false

	if y < -900.0:
		return false

	if y > 220.0:
		return false

	return true
