class_name MineralDepositSampler
extends RefCounted


const Geology := preload(
	"res://src/shared/geology_ids.gd"
)

const Resources := preload(
	"res://src/shared/resource_ids.gd"
)

const Intrusions := preload(
	"res://src/builder/geology/igneous_intrusions.gd"
)


const DEEP_CONTACT_WIDTH := 0.22
const DEEP_CONTACT_OUTER_DISTANCE := 1.22
const DEEP_CONTACT_OUTER_DISTANCE_SQUARED := (
	DEEP_CONTACT_OUTER_DISTANCE
	* DEEP_CONTACT_OUTER_DISTANCE
)

const DEEP_FEEDER_RESOURCE_HALF_WIDTH := 90.0


var _world: WorldDefinition
var _stratigraphy: StratigraphyProfile
var _geology: DeformedGeologySampler


var _deposit_noise: FastNoiseLite
var _vein_noise: FastNoiseLite
var _deep_noise: FastNoiseLite
var _rare_noise: FastNoiseLite


# ==================================================
# PREPARED HORIZONTAL BLOCK COLUMNS
# ==================================================

var _prepared_valid: bool = false

var _prepared_origin_x: int = 0
var _prepared_origin_z: int = 0

var _prepared_size_x: int = 0
var _prepared_size_z: int = 0

var _prepared_lod_index: int = -1


var _master_x := PackedFloat64Array()
var _master_z := PackedFloat64Array()

var _deformation := PackedFloat64Array()
var _fault_strength := PackedFloat64Array()

var _tin_xz_squared := PackedFloat64Array()
var _copper_xz_squared := PackedFloat64Array()

var _gold_dike_active := PackedByteArray()

var _deep_a_xz_squared := PackedFloat64Array()
var _deep_b_xz_squared := PackedFloat64Array()

var _deep_feeder_distance := PackedFloat64Array()
var _deep_possible := PackedByteArray()


# ==================================================
# FALLBACK SCALAR CACHE
# ==================================================

var _scalar_valid: bool = false

var _scalar_x: float = 0.0
var _scalar_z: float = 0.0

var _scalar_master_x: float = 0.0
var _scalar_master_z: float = 0.0

var _scalar_deformation: float = 0.0
var _scalar_fault_strength: float = 0.0

var _scalar_tin_xz_squared: float = 0.0
var _scalar_copper_xz_squared: float = 0.0

var _scalar_gold_dike_active: bool = false

var _scalar_deep_a_xz_squared: float = 0.0
var _scalar_deep_b_xz_squared: float = 0.0

var _scalar_deep_feeder_distance: float = 0.0
var _scalar_deep_possible: bool = false


func setup(
	world_definition: WorldDefinition,
	stratigraphy: StratigraphyProfile
) -> void:
	_world = world_definition
	_stratigraphy = stratigraphy

	_geology = DeformedGeologySampler.new()

	_geology.setup(
		_world,
		_stratigraphy
	)


	_deposit_noise = FastNoiseLite.new()
	_deposit_noise.seed = (
		_world.world_seed + 22037
	)
	_deposit_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)
	_deposit_noise.frequency = 0.018


	_vein_noise = FastNoiseLite.new()
	_vein_noise.seed = (
		_world.world_seed + 31013
	)
	_vein_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX
	)
	_vein_noise.frequency = 0.028


	_deep_noise = FastNoiseLite.new()
	_deep_noise.seed = (
		_world.world_seed + 41291
	)
	_deep_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)
	_deep_noise.frequency = 0.006


	_rare_noise = FastNoiseLite.new()
	_rare_noise.seed = (
		_world.world_seed + 51803
	)
	_rare_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX
	)
	_rare_noise.frequency = 0.011


	clear_prepared_columns()


# ==================================================
# PREPARE FROM SHARED MAIN COLUMN CACHE
#
# Master coordinates, total deformation, and fault strength are
# already computed by BakedVoxelSampler. Only mineral-specific X/Z
# facts are built here.
# ==================================================

func prepare_block_columns_from_shared(
	world_voxel_origin: Vector3i,
	size: Vector3i,
	lod_index: int,
	shared_master_x: PackedFloat64Array,
	shared_master_z: PackedFloat64Array,
	shared_deformation: PackedFloat64Array,
	shared_fault_strength: PackedFloat64Array
) -> void:
	var same_block: bool = (
		_prepared_valid
		and _prepared_origin_x == world_voxel_origin.x
		and _prepared_origin_z == world_voxel_origin.z
		and _prepared_size_x == size.x
		and _prepared_size_z == size.z
		and _prepared_lod_index == lod_index
	)

	if same_block:
		return

	var column_count: int = size.x * size.z

	if (
		shared_master_x.size() != column_count
		or shared_master_z.size() != column_count
		or shared_deformation.size() != column_count
		or shared_fault_strength.size() != column_count
	):
		_prepared_valid = false
		return

	# Shared geological arrays remain owned by BakedVoxelSampler.
	# This sampler stores only mineral-specific column facts.
	_tin_xz_squared.resize(column_count)
	_copper_xz_squared.resize(column_count)
	_gold_dike_active.resize(column_count)
	_deep_a_xz_squared.resize(column_count)
	_deep_b_xz_squared.resize(column_count)
	_deep_feeder_distance.resize(column_count)
	_deep_possible.resize(column_count)

	for index in range(column_count):
		var master_x: float = shared_master_x[index]
		var master_z: float = shared_master_z[index]

		_tin_xz_squared[index] = _get_tin_xz_squared(master_x, master_z)
		_copper_xz_squared[index] = _get_copper_xz_squared(master_x, master_z)
		_gold_dike_active[index] = (
			1 if _is_gold_dike_column(master_x, master_z) else 0
		)

		var deep_a_xz: float = _get_deep_a_xz_squared(master_x, master_z)
		var deep_b_xz: float = _get_deep_b_xz_squared(master_x, master_z)
		var feeder_distance: float = _get_deep_feeder_distance(master_x, master_z)

		_deep_a_xz_squared[index] = deep_a_xz
		_deep_b_xz_squared[index] = deep_b_xz
		_deep_feeder_distance[index] = feeder_distance
		_deep_possible[index] = (
			1
			if (
				deep_a_xz <= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
				or deep_b_xz <= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
				or feeder_distance <= DEEP_FEEDER_RESOURCE_HALF_WIDTH
			)
			else 0
		)

	_prepared_origin_x = world_voxel_origin.x
	_prepared_origin_z = world_voxel_origin.z
	_prepared_size_x = size.x
	_prepared_size_z = size.z
	_prepared_lod_index = lod_index
	_prepared_valid = true


# ==================================================
# PREPARE 16x16 HORIZONTAL COLUMNS
# ==================================================

func prepare_block_columns(
	world_voxel_origin: Vector3i,
	size: Vector3i,
	lod_index: int,
	voxel_size_meters: float
) -> void:
	var same_block: bool = (
		_prepared_valid
		and _prepared_origin_x
			== world_voxel_origin.x
		and _prepared_origin_z
			== world_voxel_origin.z
		and _prepared_size_x
			== size.x
		and _prepared_size_z
			== size.z
		and _prepared_lod_index
			== lod_index
	)

	if same_block:
		return


	var column_count: int = (
		size.x * size.z
	)


	_master_x.resize(
		column_count
	)

	_master_z.resize(
		column_count
	)

	_deformation.resize(
		column_count
	)

	_fault_strength.resize(
		column_count
	)

	_tin_xz_squared.resize(
		column_count
	)

	_copper_xz_squared.resize(
		column_count
	)

	_gold_dike_active.resize(
		column_count
	)

	_deep_a_xz_squared.resize(
		column_count
	)

	_deep_b_xz_squared.resize(
		column_count
	)

	_deep_feeder_distance.resize(
		column_count
	)

	_deep_possible.resize(
		column_count
	)


	var lod_scale: int = (
		1 << lod_index
	)


	for local_z in range(
		size.z
	):
		for local_x in range(
			size.x
		):
			var index: int = (
				local_z * size.x
				+ local_x
			)


			var world_x: float = (
				float(
					world_voxel_origin.x
					+ local_x * lod_scale
				)
				* voxel_size_meters
			)

			var world_z: float = (
				float(
					world_voxel_origin.z
					+ local_z * lod_scale
				)
				* voxel_size_meters
			)


			var master: Vector2 = (
				_geology.get_master_coordinates(
					world_x,
					world_z
				)
			)


			var master_x: float = (
				master.x
			)

			var master_z: float = (
				master.y
			)


			_master_x[
				index
			] = master_x

			_master_z[
				index
			] = master_z


			var column_top_y: float = (
				_geology.get_master_column_top_y(
					master_x,
					master_z
				)
			)


			_deformation[
				index
			] = (
				column_top_y
				- _world
					.stratigraphy_reference_y_meters
			)


			_fault_strength[
				index
			] = (
				_get_fault_strength_master(
					master_x,
					master_z
				)
			)


			_tin_xz_squared[
				index
			] = (
				_get_tin_xz_squared(
					master_x,
					master_z
				)
			)


			_copper_xz_squared[
				index
			] = (
				_get_copper_xz_squared(
					master_x,
					master_z
				)
			)


			_gold_dike_active[
				index
			] = (
				1
				if _is_gold_dike_column(
					master_x,
					master_z
				)
				else 0
			)


			var deep_a_xz: float = (
				_get_deep_a_xz_squared(
					master_x,
					master_z
				)
			)

			var deep_b_xz: float = (
				_get_deep_b_xz_squared(
					master_x,
					master_z
				)
			)

			var feeder_distance: float = (
				_get_deep_feeder_distance(
					master_x,
					master_z
				)
			)


			_deep_a_xz_squared[
				index
			] = deep_a_xz

			_deep_b_xz_squared[
				index
			] = deep_b_xz

			_deep_feeder_distance[
				index
			] = feeder_distance


			_deep_possible[
				index
			] = (
				1
				if (
					deep_a_xz
						<= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
					or deep_b_xz
						<= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
					or feeder_distance
						<= DEEP_FEEDER_RESOURCE_HALF_WIDTH
				)
				else 0
			)


	_prepared_origin_x = (
		world_voxel_origin.x
	)

	_prepared_origin_z = (
		world_voxel_origin.z
	)

	_prepared_size_x = (
		size.x
	)

	_prepared_size_z = (
		size.z
	)

	_prepared_lod_index = (
		lod_index
	)

	_prepared_valid = true


func clear_prepared_columns() -> void:
	_prepared_valid = false

	_prepared_origin_x = 0
	_prepared_origin_z = 0

	_prepared_size_x = 0
	_prepared_size_z = 0

	_prepared_lod_index = -1

	_master_x.clear()
	_master_z.clear()

	_deformation.clear()
	_fault_strength.clear()

	_tin_xz_squared.clear()
	_copper_xz_squared.clear()

	_gold_dike_active.clear()

	_deep_a_xz_squared.clear()
	_deep_b_xz_squared.clear()

	_deep_feeder_distance.clear()
	_deep_possible.clear()

	_scalar_valid = false


# ==================================================
# FAST ENTRY POINT USING THE SHARED MAIN COLUMN CACHE
# ==================================================

func get_resource_id_precomputed_shared(
	local_x: int,
	local_z: int,
	master_x: float,
	master_z: float,
	deformation: float,
	fault_strength: float,
	y: float,
	geology_id: int
) -> int:
	if not _prepared_valid:
		return Resources.NONE

	var index: int = local_z * _prepared_size_x + local_x

	return _get_resource_id_cached(
		master_x,
		master_z,
		deformation,
		fault_strength,
		_tin_xz_squared[index],
		_copper_xz_squared[index],
		_gold_dike_active[index] != 0,
		_deep_a_xz_squared[index],
		_deep_b_xz_squared[index],
		_deep_feeder_distance[index],
		_deep_possible[index] != 0,
		y,
		geology_id
	)


# ==================================================
# FAST PRECOMPUTED ENTRY POINT
# ==================================================

func get_resource_id_precomputed(
	local_x: int,
	local_z: int,
	y: float,
	geology_id: int
) -> int:
	if not _prepared_valid:
		return Resources.NONE


	var index: int = (
		local_z * _prepared_size_x
		+ local_x
	)


	return _get_resource_id_cached(
		_master_x[
			index
		],
		_master_z[
			index
		],
		_deformation[
			index
		],
		_fault_strength[
			index
		],
		_tin_xz_squared[
			index
		],
		_copper_xz_squared[
			index
		],
		_gold_dike_active[
			index
		] != 0,
		_deep_a_xz_squared[
			index
		],
		_deep_b_xz_squared[
			index
		],
		_deep_feeder_distance[
			index
		],
		_deep_possible[
			index
		] != 0,
		y,
		geology_id
	)


# ==================================================
# NORMAL ENTRY POINTS
# ==================================================

func get_resource_id(
	x: float,
	y: float,
	z: float
) -> int:
	if _geology == null:
		return Resources.NONE


	var geology_id: int = (
		_geology.get_geology_id(
			x,
			y,
			z
		)
	)


	return get_resource_id_for_geology(
		x,
		y,
		z,
		geology_id
	)


func get_resource_id_for_geology(
	x: float,
	y: float,
	z: float,
	geology_id: int
) -> int:
	_ensure_scalar_cache(
		x,
		z
	)


	return _get_resource_id_cached(
		_scalar_master_x,
		_scalar_master_z,
		_scalar_deformation,
		_scalar_fault_strength,
		_scalar_tin_xz_squared,
		_scalar_copper_xz_squared,
		_scalar_gold_dike_active,
		_scalar_deep_a_xz_squared,
		_scalar_deep_b_xz_squared,
		_scalar_deep_feeder_distance,
		_scalar_deep_possible,
		y,
		geology_id
	)


func get_resource_id_for_geology_reference(
	x: float,
	y: float,
	z: float,
	geology_id: int
) -> int:
	return get_resource_id_for_geology(
		x,
		y,
		z,
		geology_id
	)


# ==================================================
# COMMON RESOURCE PATH
# ==================================================

func _get_resource_id_cached(
	master_x: float,
	master_z: float,
	deformation: float,
	fault_strength: float,
	tin_xz_squared: float,
	copper_xz_squared: float,
	gold_dike_active: bool,
	deep_a_xz_squared: float,
	deep_b_xz_squared: float,
	deep_feeder_distance: float,
	deep_possible: bool,
	y: float,
	geology_id: int
) -> int:
	if geology_id == Geology.AIR:
		return Resources.NONE


	if geology_id == Geology.COAL:
		return Resources.COAL


	var original_y: float = (
		y - deformation
	)


	# ==================================================
	# SHALLOW TIN
	# ==================================================

	if (
		geology_id == Geology.GRANITE
		and tin_xz_squared <= 1.15
	):
		var tin_dy: float = (
			(original_y + 310.0)
			/ 390.0
		)

		var tin_distance_squared: float = (
			tin_xz_squared
			+ tin_dy * tin_dy
		)

		if tin_distance_squared <= 1.15:
			var tin_noise: float = (
				_deposit_noise.get_noise_3d(
					master_x,
					original_y,
					master_z
				)
			)

			if tin_noise > 0.34:
				return Resources.TIN


	# ==================================================
	# SHALLOW COPPER
	# ==================================================

	if (
		geology_id != Geology.COAL
		and copper_xz_squared < 1.45
	):
		var copper_dy: float = (
			(original_y + 310.0)
			/ 375.0
		)

		var copper_distance_squared: float = (
			copper_xz_squared
			+ copper_dy * copper_dy
		)

		if (
			copper_distance_squared
				>= 0.75
			and copper_distance_squared
				<= 1.45
		):
			var copper_noise: float = (
				_deposit_noise.get_noise_3d(
					master_x + 800.0,
					original_y,
					master_z - 500.0
				)
			)

			if copper_noise > 0.28:
				return Resources.COPPER


	# ==================================================
	# SHALLOW GOLD
	# ==================================================

	if (
		gold_dike_active
		and original_y >= -750.0
		and original_y <= 180.0
	):
		var vein_value: float = absf(
			_vein_noise.get_noise_3d(
				master_x,
				original_y,
				master_z
			)
		)

		if vein_value < 0.075:
			return Resources.GOLD


	# ==================================================
	# SEDIMENTARY IRON
	# ==================================================

	if (
		geology_id == Geology.SHALE
		or geology_id == Geology.SEDIMENT
	):
		var iron_noise: float = (
			_deposit_noise.get_noise_3d(
				master_x + 1400.0,
				original_y - 300.0,
				master_z + 1100.0
			)
		)

		if iron_noise > 0.57:
			return Resources.IRON


	# ==================================================
	# LIMESTONE FAULT MINERALIZATION
	# ==================================================

	if (
		geology_id == Geology.LIMESTONE
		and fault_strength > 0.10
	):
		var limestone_noise: float = (
			_deposit_noise.get_noise_3d(
				master_x - 600.0,
				y + 900.0,
				master_z + 300.0
			)
		)

		limestone_noise += (
			fault_strength * 0.12
		)

		if limestone_noise > 0.52:
			return Resources.SILVER

		if limestone_noise > 0.32:
			return Resources.LEAD

		if limestone_noise > 0.15:
			return Resources.ZINC


	# ==================================================
	# DEEP SYSTEM
	# ==================================================

	if (
		geology_id != Geology.GRANITE
		or not deep_possible
	):
		return Resources.NONE


	var feeder_strength: float = 0.0

	if (
		y >= Intrusions.DEEP_FEEDER_MIN_Y
		and y <= Intrusions.DEEP_FEEDER_MAX_Y
		and deep_feeder_distance
			<= DEEP_FEEDER_RESOURCE_HALF_WIDTH
	):
		feeder_strength = clampf(
			1.0
			- deep_feeder_distance
				/ DEEP_FEEDER_RESOURCE_HALF_WIDTH,
			0.0,
			1.0
		)


	var deep_a_distance_squared: float = INF

	if (
		deep_a_xz_squared
		<= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
	):
		var deep_a_dy: float = (
			(y - Intrusions.DEEP_A_CENTER_Y)
			/ Intrusions.DEEP_A_RADIUS_Y
		)

		deep_a_distance_squared = (
			deep_a_xz_squared
			+ deep_a_dy * deep_a_dy
		)


	var deep_b_distance_squared: float = INF

	if (
		deep_b_xz_squared
		<= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
	):
		var deep_b_dy: float = (
			(y - Intrusions.DEEP_B_CENTER_Y)
			/ Intrusions.DEEP_B_RADIUS_Y
		)

		deep_b_distance_squared = (
			deep_b_xz_squared
			+ deep_b_dy * deep_b_dy
		)


	var intrusion_strength: float = maxf(
		maxf(
			_distance_to_strength(
				deep_a_distance_squared
			),
			_distance_to_strength(
				deep_b_distance_squared
			)
		),
		feeder_strength
	)


	var contact_strength: float = maxf(
		_contact_strength(
			deep_a_distance_squared
		),
		_contact_strength(
			deep_b_distance_squared
		)
	)


	if (
		intrusion_strength <= 0.0
		and contact_strength <= 0.0
		and feeder_strength <= 0.0
	):
		return Resources.NONE


	# ==================================================
	# GEMSTONE
	# ==================================================

	if contact_strength > 0.58:
		var gemstone_noise: float = (
			_rare_noise.get_noise_3d(
				master_x + 3100.0,
				y - 1700.0,
				master_z - 2500.0
			)
		)

		if gemstone_noise > 0.67:
			return Resources.GEMSTONE


	# ==================================================
	# DEEP GOLD
	# ==================================================

	if (
		fault_strength > 0.28
		and (
			feeder_strength > 0.08
			or contact_strength > 0.10
		)
	):
		var deep_gold_value: float = absf(
			_vein_noise.get_noise_3d(
				master_x + 2400.0,
				y - 800.0,
				master_z + 1900.0
			)
		)

		if deep_gold_value < 0.060:
			return Resources.GOLD


	# ==================================================
	# NICKEL
	# ==================================================

	if intrusion_strength > 0.32:
		var nickel_noise: float = (
			_deep_noise.get_noise_3d(
				master_x - 2700.0,
				y + 1300.0,
				master_z + 3300.0
			)
		)

		if nickel_noise > 0.36:
			var nickel_detail: float = (
				_deposit_noise.get_noise_3d(
					master_x + 500.0,
					y - 2100.0,
					master_z - 900.0
				)
			)

			if nickel_detail > 0.16:
				return Resources.NICKEL


	# ==================================================
	# DEEP TIN
	# ==================================================

	if contact_strength > 0.32:
		var deep_tin_noise: float = (
			_deep_noise.get_noise_3d(
				master_x + 1700.0,
				y + 600.0,
				master_z - 2300.0
			)
		)

		if deep_tin_noise > 0.28:
			return Resources.TIN


	# ==================================================
	# DEEP COPPER
	# ==================================================

	if (
		contact_strength > 0.16
		or feeder_strength > 0.22
	):
		var deep_copper_noise: float = (
			_deep_noise.get_noise_3d(
				master_x - 900.0,
				y - 400.0,
				master_z + 1200.0
			)
		)

		var copper_bias: float = maxf(
			contact_strength,
			feeder_strength
		)

		if (
			deep_copper_noise
			+ copper_bias * 0.22
			> 0.20
		):
			return Resources.COPPER


	# ==================================================
	# SULFUR
	# ==================================================

	if feeder_strength > 0.48:
		var sulfur_noise: float = (
			_deposit_noise.get_noise_3d(
				master_x + 3900.0,
				y + 1200.0,
				master_z - 3100.0
			)
		)

		if sulfur_noise > 0.24:
			return Resources.SULFUR


	# ==================================================
	# GRAPHITE
	# ==================================================

	if fault_strength > 0.42:
		var graphite_noise: float = (
			_deep_noise.get_noise_3d(
				master_x + 700.0,
				y + 2700.0,
				master_z + 2600.0
			)
		)

		if graphite_noise < -0.30:
			return Resources.GRAPHITE


	return Resources.NONE


# ==================================================
# FALLBACK CACHE
# ==================================================

func _ensure_scalar_cache(
	x: float,
	z: float
) -> void:
	if (
		_scalar_valid
		and x == _scalar_x
		and z == _scalar_z
	):
		return


	_scalar_x = x
	_scalar_z = z


	var master: Vector2 = (
		_geology.get_master_coordinates(
			x,
			z
		)
	)


	_scalar_master_x = (
		master.x
	)

	_scalar_master_z = (
		master.y
	)


	var column_top_y: float = (
		_geology.get_master_column_top_y(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_deformation = (
		column_top_y
		- _world
			.stratigraphy_reference_y_meters
	)


	_scalar_fault_strength = (
		_get_fault_strength_master(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_tin_xz_squared = (
		_get_tin_xz_squared(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_copper_xz_squared = (
		_get_copper_xz_squared(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_gold_dike_active = (
		_is_gold_dike_column(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_deep_a_xz_squared = (
		_get_deep_a_xz_squared(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_deep_b_xz_squared = (
		_get_deep_b_xz_squared(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_deep_feeder_distance = (
		_get_deep_feeder_distance(
			_scalar_master_x,
			_scalar_master_z
		)
	)


	_scalar_deep_possible = (
		_scalar_deep_a_xz_squared
			<= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
		or _scalar_deep_b_xz_squared
			<= DEEP_CONTACT_OUTER_DISTANCE_SQUARED
		or _scalar_deep_feeder_distance
			<= DEEP_FEEDER_RESOURCE_HALF_WIDTH
	)


	_scalar_valid = true


# ==================================================
# COLUMN MATH
# ==================================================

func _get_fault_strength_master(
	x: float,
	z: float
) -> float:
	var primary_distance: float = absf(
		x
		- z * 0.22
		- 95.0
	)

	var secondary_distance: float = absf(
		x
		+ z * 0.55
		+ 265.0
	)


	var primary_strength: float = clampf(
		1.0
		- primary_distance / 70.0,
		0.0,
		1.0
	)

	var secondary_strength: float = clampf(
		1.0
		- secondary_distance / 50.0,
		0.0,
		1.0
	)


	return maxf(
		primary_strength,
		secondary_strength
	)


func _get_tin_xz_squared(
	x: float,
	z: float
) -> float:
	var dx: float = (
		(x + 170.0)
		/ 250.0
	)

	var dz: float = (
		(z - 170.0)
		/ 215.0
	)

	return (
		dx * dx
		+ dz * dz
	)


func _get_copper_xz_squared(
	x: float,
	z: float
) -> float:
	var dx: float = (
		(x + 170.0)
		/ 245.0
	)

	var dz: float = (
		(z - 170.0)
		/ 205.0
	)

	return (
		dx * dx
		+ dz * dz
	)


func _is_gold_dike_column(
	x: float,
	z: float
) -> bool:
	return (
		absf(
			x
			- z * 0.28
			+ 120.0
		)
		<= 28.0
	)


func _get_deep_a_xz_squared(
	x: float,
	z: float
) -> float:
	var dx: float = (
		(x - Intrusions.DEEP_A_CENTER_X)
		/ Intrusions.DEEP_A_RADIUS_X
	)

	var dz: float = (
		(z - Intrusions.DEEP_A_CENTER_Z)
		/ Intrusions.DEEP_A_RADIUS_Z
	)

	return (
		dx * dx
		+ dz * dz
	)


func _get_deep_b_xz_squared(
	x: float,
	z: float
) -> float:
	var dx: float = (
		(x - Intrusions.DEEP_B_CENTER_X)
		/ Intrusions.DEEP_B_RADIUS_X
	)

	var dz: float = (
		(z - Intrusions.DEEP_B_CENTER_Z)
		/ Intrusions.DEEP_B_RADIUS_Z
	)

	return (
		dx * dx
		+ dz * dz
	)


func _get_deep_feeder_distance(
	x: float,
	z: float
) -> float:
	return absf(
		x
		+ z * 0.42
		- 260.0
	)


# ==================================================
# DEEP STRENGTH
# ==================================================

func _distance_to_strength(
	distance_squared: float
) -> float:
	if distance_squared >= 1.0:
		return 0.0

	return clampf(
		1.0
		- sqrt(
			maxf(
				distance_squared,
				0.0
			)
		),
		0.0,
		1.0
	)


func _contact_strength(
	distance_squared: float
) -> float:
	if (
		distance_squared
		> DEEP_CONTACT_OUTER_DISTANCE_SQUARED
	):
		return 0.0


	var distance: float = sqrt(
		maxf(
			distance_squared,
			0.0
		)
	)


	return clampf(
		1.0
		- absf(
			distance - 1.0
		)
			/ DEEP_CONTACT_WIDTH,
		0.0,
		1.0
	)
