class_name NaturalCaveSampler
extends RefCounted


const Geology := preload(
	"res://src/shared/geology_ids.gd"
)


var _world: WorldDefinition
var _geology: DeformedGeologySampler

var _karst_chamber_noise: FastNoiseLite
var _karst_tunnel_noise_a: FastNoiseLite
var _karst_tunnel_noise_b: FastNoiseLite
var _karst_detail_noise: FastNoiseLite

var _fault_cave_noise_a: FastNoiseLite
var _fault_cave_noise_b: FastNoiseLite


# ==================================================
# PREPARED 16x16 HORIZONTAL BLOCK CACHE
# ==================================================

var _prepared_valid: bool = false

var _prepared_origin_x: int = 0
var _prepared_origin_z: int = 0

var _prepared_size_x: int = 0
var _prepared_size_z: int = 0

var _prepared_lod_index: int = -1

var _prepared_master_x := PackedFloat64Array()
var _prepared_master_z := PackedFloat64Array()
var _prepared_fault_strength := PackedFloat64Array()


# ==================================================
# SCALAR FALLBACK CACHE
# ==================================================

var _scalar_cache_valid: bool = false

var _scalar_x: float = 0.0
var _scalar_z: float = 0.0

var _scalar_master_x: float = 0.0
var _scalar_master_z: float = 0.0

var _scalar_fault_strength: float = 0.0


func setup(
	world_definition: WorldDefinition,
	geology_sampler: DeformedGeologySampler
) -> void:
	_world = world_definition
	_geology = geology_sampler

	_karst_chamber_noise = FastNoiseLite.new()
	_karst_chamber_noise.seed = (
		_world.world_seed + 61001
	)
	_karst_chamber_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)
	_karst_chamber_noise.frequency = 0.0045

	_karst_tunnel_noise_a = FastNoiseLite.new()
	_karst_tunnel_noise_a.seed = (
		_world.world_seed + 61002
	)
	_karst_tunnel_noise_a.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX
	)
	_karst_tunnel_noise_a.frequency = 0.012

	_karst_tunnel_noise_b = FastNoiseLite.new()
	_karst_tunnel_noise_b.seed = (
		_world.world_seed + 61003
	)
	_karst_tunnel_noise_b.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX
	)
	_karst_tunnel_noise_b.frequency = 0.014

	_karst_detail_noise = FastNoiseLite.new()
	_karst_detail_noise.seed = (
		_world.world_seed + 61004
	)
	_karst_detail_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)
	_karst_detail_noise.frequency = 0.025

	_fault_cave_noise_a = FastNoiseLite.new()
	_fault_cave_noise_a.seed = (
		_world.world_seed + 62001
	)
	_fault_cave_noise_a.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX
	)
	_fault_cave_noise_a.frequency = 0.010

	_fault_cave_noise_b = FastNoiseLite.new()
	_fault_cave_noise_b.seed = (
		_world.world_seed + 62002
	)
	_fault_cave_noise_b.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX
	)
	_fault_cave_noise_b.frequency = 0.017

	clear_prepared_columns()


# ==================================================
# PREPARE HORIZONTAL BLOCK
#
# Called once for an X/Z block column and reused for
# every vertical 16x16x16 block in that column.
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

	_prepared_master_x.resize(
		column_count
	)

	_prepared_master_z.resize(
		column_count
	)

	_prepared_fault_strength.resize(
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

			_prepared_master_x[index] = (
				master.x
			)

			_prepared_master_z[index] = (
				master.y
			)

			_prepared_fault_strength[index] = (
				_get_fault_strength_master(
					master.x,
					master.y
				)
			)

	_prepared_origin_x = (
		world_voxel_origin.x
	)

	_prepared_origin_z = (
		world_voxel_origin.z
	)

	_prepared_size_x = size.x
	_prepared_size_z = size.z

	_prepared_lod_index = lod_index

	_prepared_valid = true


func clear_prepared_columns() -> void:
	_prepared_valid = false

	_prepared_origin_x = 0
	_prepared_origin_z = 0

	_prepared_size_x = 0
	_prepared_size_z = 0

	_prepared_lod_index = -1

	_prepared_master_x.clear()
	_prepared_master_z.clear()
	_prepared_fault_strength.clear()

	_scalar_cache_valid = false



# ==================================================
# SHARED COLUMN ENTRY POINT
#
# The main BakedVoxelSampler owns the horizontal cache. Caves receive
# the already-remapped master coordinates and fault strength directly,
# avoiding a duplicate 16x16 preparation pass for every block column.
# ==================================================

func is_cave_with_shared_column(
	master_x: float,
	master_z: float,
	fault_strength: float,
	y: float,
	geology_id: int,
	surface_y: float
) -> bool:
	if _world == null:
		return false

	if y > surface_y - 18.0:
		return false

	if y < float(_world.world_bottom_meters) + 24.0:
		return false

	if geology_id == Geology.AIR:
		return false

	if geology_id == Geology.LIMESTONE:
		if _is_karst_cave(master_x, y, master_z):
			return true

	if fault_strength < 0.42:
		return false

	return _is_fault_cave(
		master_x,
		y,
		master_z,
		fault_strength
	)

# ==================================================
# FAST PRECOMPUTED ENTRY POINT
# ==================================================

func is_cave_precomputed(
	local_x: int,
	local_z: int,
	y: float,
	geology_id: int,
	surface_y: float
) -> bool:
	if (
		not _prepared_valid
		or _world == null
	):
		return false

	if y > surface_y - 18.0:
		return false

	if (
		y
		< float(
			_world.world_bottom_meters
		) + 24.0
	):
		return false

	if geology_id == Geology.AIR:
		return false

	var index: int = (
		local_z * _prepared_size_x
		+ local_x
	)

	var master_x: float = (
		_prepared_master_x[index]
	)

	var master_z: float = (
		_prepared_master_z[index]
	)

	if geology_id == Geology.LIMESTONE:
		if _is_karst_cave(
			master_x,
			y,
			master_z
		):
			return true

	var fault_strength: float = (
		_prepared_fault_strength[index]
	)

	if fault_strength < 0.42:
		return false

	return _is_fault_cave(
		master_x,
		y,
		master_z,
		fault_strength
	)


# ==================================================
# NORMAL FALLBACK ENTRY POINT
# ==================================================

func is_cave(
	x: float,
	y: float,
	z: float,
	geology_id: int,
	surface_y: float
) -> bool:
	if _world == null or _geology == null:
		return false

	if y > surface_y - 18.0:
		return false

	if (
		y
		< float(
			_world.world_bottom_meters
		) + 24.0
	):
		return false

	if geology_id == Geology.AIR:
		return false

	_ensure_scalar_cache(
		x,
		z
	)

	if geology_id == Geology.LIMESTONE:
		if _is_karst_cave(
			_scalar_master_x,
			y,
			_scalar_master_z
		):
			return true

	if _scalar_fault_strength < 0.42:
		return false

	return _is_fault_cave(
		_scalar_master_x,
		y,
		_scalar_master_z,
		_scalar_fault_strength
	)


# ==================================================
# SCALAR CACHE
# ==================================================

func _ensure_scalar_cache(
	x: float,
	z: float
) -> void:
	if (
		_scalar_cache_valid
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

	_scalar_master_x = master.x
	_scalar_master_z = master.y

	_scalar_fault_strength = (
		_get_fault_strength_master(
			master.x,
			master.y
		)
	)

	_scalar_cache_valid = true


# ==================================================
# FAULT STRENGTH
# ==================================================

func _get_fault_strength_master(
	master_x: float,
	master_z: float
) -> float:
	var primary_distance: float = absf(
		master_x
		- master_z * 0.22
		- 95.0
	)

	var secondary_distance: float = absf(
		master_x
		+ master_z * 0.55
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


# ==================================================
# LIMESTONE KARST
# ==================================================

func _is_karst_cave(
	master_x: float,
	y: float,
	master_z: float
) -> bool:
	var chamber: float = (
		_karst_chamber_noise.get_noise_3d(
			master_x,
			y,
			master_z
		)
	)

	if chamber > 0.54:
		var detail: float = (
			_karst_detail_noise.get_noise_3d(
				master_x,
				y,
				master_z
			)
		)

		if detail > -0.28:
			return true

	var tunnel_a: float = absf(
		_karst_tunnel_noise_a.get_noise_3d(
			master_x,
			y,
			master_z
		)
	)

	# Avoid the second tunnel-noise sample unless the
	# first field is already close enough.
	if tunnel_a >= 0.105:
		return false

	var tunnel_b: float = absf(
		_karst_tunnel_noise_b.get_noise_3d(
			master_x,
			y,
			master_z
		)
	)

	return (
		tunnel_b < 0.125
	)


# ==================================================
# FAULT / FRACTURE CAVES
# ==================================================

func _is_fault_cave(
	master_x: float,
	y: float,
	master_z: float,
	fault_strength: float
) -> bool:
	var width: float = lerpf(
		0.035,
		0.095,
		fault_strength
	)

	var noise_a: float = absf(
		_fault_cave_noise_a.get_noise_3d(
			master_x,
			y,
			master_z
		)
	)

	# Most voxels fail here, so avoid noise B.
	if noise_a >= width:
		return false

	var noise_b: float = (
		_fault_cave_noise_b.get_noise_3d(
			master_x,
			y,
			master_z
		)
	)

	return (
		noise_b > -0.18
	)
