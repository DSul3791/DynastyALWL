class_name BakedVoxelSampler
extends RefCounted


const Layout := preload(
	"res://src/shared/baked_voxel_layout.gd"
)

const Geology := preload(
	"res://src/shared/geology_ids.gd"
)

const Deposits := preload(
	"res://src/shared/surficial_deposit_ids.gd"
)

const Resources := preload(
	"res://src/shared/resource_ids.gd"
)

const NaturalCaveSamplerScript := preload(
	"res://src/builder/geology/natural_cave_sampler.gd"
)


const SDF_SIGN_EPSILON := 0.02
const SDF_BASE_MAX_DISTANCE := 64.0
const SDF_STORAGE_MAX_DISTANCE := 500.0


var _world_definition
var _terrain_sampler
var _mineral_sampler
var _cave_sampler

var _voxel_size_meters: float = 1.0


# ==================================================
# HORIZONTAL COLUMN CACHE
# ==================================================

var _column_cache_valid: bool = false

var _column_cache_origin_x: int = 0
var _column_cache_origin_z: int = 0

var _column_cache_size_x: int = 0
var _column_cache_size_z: int = 0

var _column_cache_lod_index: int = -1


var _column_surface_y := PackedFloat64Array()

var _column_deposit_id := PackedInt32Array()
var _column_deposit_base_y := PackedFloat64Array()

var _column_geology_top_y := PackedFloat64Array()

# Shared geological X/Z facts computed once per horizontal column.
var _column_master_x := PackedFloat64Array()
var _column_master_z := PackedFloat64Array()
var _column_deformation := PackedFloat64Array()
var _column_fault_strength := PackedFloat64Array()

var _column_pluton_dx_squared := PackedFloat64Array()
var _column_pluton_dz_squared := PackedFloat64Array()

var _column_dike_active := PackedByteArray()


var _column_min_surface_y: float = 0.0
var _column_max_surface_y: float = 0.0


var _column_cache_build_count: int = 0
var _column_cache_hit_count: int = 0


func setup(
	world_definition,
	terrain_sampler,
	mineral_sampler
) -> void:
	_world_definition = world_definition
	_terrain_sampler = terrain_sampler
	_mineral_sampler = mineral_sampler

	_cave_sampler = (
		NaturalCaveSamplerScript.new()
	)

	_cave_sampler.setup(
		_world_definition,
		_terrain_sampler._geology_sampler
	)

	_voxel_size_meters = (
		_world_definition.voxel_size_meters
	)

	clear_column_cache()

	_column_cache_build_count = 0
	_column_cache_hit_count = 0


# ==================================================
# BUFFER CREATION
# ==================================================

func create_buffer(
	world_voxel_origin: Vector3i,
	size: Vector3i,
	lod_index: int = 0
) -> VoxelBuffer:
	var buffer := _create_empty_buffer(
		size
	)

	buffer.fill(
		Geology.AIR,
		Layout.CHANNEL_GEOLOGY
	)

	buffer.fill(
		Deposits.NONE,
		Layout.CHANNEL_SURFICIAL_DEPOSIT
	)

	buffer.fill(
		Resources.NONE,
		Layout.CHANNEL_RESOURCE
	)

	_fill_buffer(
		buffer,
		world_voxel_origin,
		lod_index
	)

	return buffer


func create_uniform_air_buffer(
	world_voxel_origin: Vector3i,
	size: Vector3i,
	lod_index: int = 0
) -> VoxelBuffer:
	var buffer := _create_empty_buffer(
		size
	)

	var sdf_max_distance: float = (
		_get_sdf_max_distance(
			lod_index
		)
	)

	buffer.fill_f(
		sdf_max_distance,
		Layout.CHANNEL_SDF
	)

	buffer.fill(
		Geology.AIR,
		Layout.CHANNEL_GEOLOGY
	)

	buffer.fill(
		Deposits.NONE,
		Layout.CHANNEL_SURFICIAL_DEPOSIT
	)

	buffer.fill(
		Resources.NONE,
		Layout.CHANNEL_RESOURCE
	)

	_apply_metadata(
		buffer,
		world_voxel_origin
	)

	buffer.compress_uniform_channels()

	return buffer


func create_uniform_deep_granite_buffer(
	world_voxel_origin: Vector3i,
	size: Vector3i,
	lod_index: int = 0
) -> VoxelBuffer:
	var buffer := _create_empty_buffer(
		size
	)

	var sdf_max_distance: float = (
		_get_sdf_max_distance(
			lod_index
		)
	)

	buffer.fill_f(
		-sdf_max_distance,
		Layout.CHANNEL_SDF
	)

	buffer.fill(
		Geology.GRANITE,
		Layout.CHANNEL_GEOLOGY
	)

	buffer.fill(
		Deposits.NONE,
		Layout.CHANNEL_SURFICIAL_DEPOSIT
	)

	buffer.fill(
		Resources.NONE,
		Layout.CHANNEL_RESOURCE
	)

	_apply_metadata(
		buffer,
		world_voxel_origin
	)

	buffer.compress_uniform_channels()

	return buffer


func _create_empty_buffer(
	size: Vector3i
) -> VoxelBuffer:
	var buffer := VoxelBuffer.new()

	Layout.configure_buffer(
		buffer
	)

	buffer.create(
		size.x,
		size.y,
		size.z
	)

	return buffer


func _apply_metadata(
	buffer: VoxelBuffer,
	world_voxel_origin: Vector3i
) -> void:
	buffer.set_block_metadata(
		{
			"format_version":
				Layout.FORMAT_VERSION,

			"origin_x":
				world_voxel_origin.x,

			"origin_y":
				world_voxel_origin.y,

			"origin_z":
				world_voxel_origin.z
		}
	)


# ==================================================
# FILL BUFFER
# ==================================================

func _fill_buffer(
	buffer: VoxelBuffer,
	world_voxel_origin: Vector3i,
	lod_index: int
) -> void:
	var size: Vector3i = (
		buffer.get_size()
	)

	var lod_scale: int = (
		1 << lod_index
	)

	var sdf_max_distance: float = (
		_get_sdf_max_distance(
			lod_index
		)
	)

	var world_y_step: float = (
		float(lod_scale)
		* _voxel_size_meters
	)

	var first_world_y: float = (
		float(
			world_voxel_origin.y
		)
		* _voxel_size_meters
	)

	var last_world_y: float = (
		first_world_y
		+ float(
			size.y - 1
		)
		* world_y_step
	)


	# --------------------------------------------------
	# PREPARE HORIZONTAL DATA
	# --------------------------------------------------

	_ensure_column_cache(
		world_voxel_origin,
		size,
		lod_index
	)


	# Caves consume the shared main column cache directly.


	# Gameplay resources only need to exist at LOD0.
	var sample_resources: bool = (
		lod_index == 0
		and _mineral_sampler != null
	)


	if sample_resources:
		_mineral_sampler.prepare_block_columns_from_shared(
			world_voxel_origin,
			size,
			lod_index,
			_column_master_x,
			_column_master_z,
			_column_deformation,
			_column_fault_strength
		)


	# --------------------------------------------------
	# FAST SDF PATH
	#
	# Most underground detailed blocks are already
	# farther than the SDF storage distance from the
	# terrain surface.
	#
	# Fill the entire SDF channel once in native code.
	# Only caves need to overwrite individual voxels.
	# --------------------------------------------------

	var uniform_solid_sdf: bool = (
		last_world_y
		< (
			_column_min_surface_y
			- sdf_max_distance
		)
	)


	if uniform_solid_sdf:
		buffer.fill_f(
			-sdf_max_distance,
			Layout.CHANNEL_SDF
		)


	# --------------------------------------------------
	# VOXELS
	# --------------------------------------------------

	for local_z in range(
		size.z
	):
		for local_x in range(
			size.x
		):
			var column_index: int = (
				local_z * size.x
				+ local_x
			)


			var surface_y: float = (
				_column_surface_y[
					column_index
				]
			)


			var column_deposit_id: int = (
				_column_deposit_id[
					column_index
				]
			)


			var deposit_base_y: float = (
				_column_deposit_base_y[
					column_index
				]
			)


			var geology_column_top_y: float = (
				_column_geology_top_y[
					column_index
				]
			)


			var pluton_dx_squared: float = (
				_column_pluton_dx_squared[
					column_index
				]
			)


			var pluton_dz_squared: float = (
				_column_pluton_dz_squared[
					column_index
				]
			)


			var dike_active: bool = (
				_column_dike_active[
					column_index
				]
				!= 0
			)


			var world_y: float = (
				first_world_y
			)


			for local_y in range(
				size.y
			):

				# ==================================================
				# SDF
				# ==================================================

				if not uniform_solid_sdf:
					var raw_sdf: float = (
						world_y
						- surface_y
					)

					var sdf: float


					if raw_sdf > 0.0:
						sdf = minf(
							raw_sdf,
							sdf_max_distance
						)

						sdf = maxf(
							sdf,
							SDF_SIGN_EPSILON
						)

					else:
						sdf = maxf(
							raw_sdf,
							-sdf_max_distance
						)

						sdf = minf(
							sdf,
							-SDF_SIGN_EPSILON
						)


					buffer.set_voxel_f(
						sdf,
						local_x,
						local_y,
						local_z,
						Layout.CHANNEL_SDF
					)


				# ==================================================
				# AIR
				# ==================================================

				if world_y > surface_y:
					world_y += world_y_step
					continue


				# ==================================================
				# GEOLOGY
				# ==================================================

				var geology_id: int = (
					_terrain_sampler
					.get_solid_geology_id_with_column_data(
						world_y,
						geology_column_top_y,
						pluton_dx_squared,
						pluton_dz_squared,
						dike_active
					)
				)


				# ==================================================
				# CAVES
				# ==================================================

				if (
					_cave_sampler != null
					and _cave_sampler.is_cave_with_shared_column(
						_column_master_x[column_index],
						_column_master_z[column_index],
						_column_fault_strength[column_index],
						world_y,
						geology_id,
						surface_y
					)
				):
					buffer.set_voxel_f(
						sdf_max_distance,
						local_x,
						local_y,
						local_z,
						Layout.CHANNEL_SDF
					)

					world_y += world_y_step
					continue


				# ==================================================
				# GEOLOGY CHANNEL
				# ==================================================

				buffer.set_voxel(
					geology_id,
					local_x,
					local_y,
					local_z,
					Layout.CHANNEL_GEOLOGY
				)


				# ==================================================
				# SURFICIAL DEPOSITS
				# ==================================================

				var deposit_id: int = (
					Deposits.NONE
				)


				if (
					column_deposit_id
						!= Deposits.NONE
					and world_y
						>= deposit_base_y
				):
					deposit_id = (
						column_deposit_id
					)

					buffer.set_voxel(
						deposit_id,
						local_x,
						local_y,
						local_z,
						Layout
							.CHANNEL_SURFICIAL_DEPOSIT
					)


				# ==================================================
				# GAMEPLAY RESOURCE CHANNEL
				#
				# Only LOD0 contains gameplay resources.
				# Higher LODs retain geology/terrain but avoid
				# expensive mineral-noise evaluation.
				# ==================================================

				if sample_resources:
					var resource_id: int = (
						Resources.NONE
					)


					if deposit_id != Deposits.NONE:
						match deposit_id:
							Deposits.CLAY:
								resource_id = (
									Resources.CLAY
								)

							Deposits.PEAT:
								resource_id = (
									Resources.PEAT
								)


					else:
						resource_id = (
							_mineral_sampler
							.get_resource_id_precomputed_shared(
								local_x,
								local_z,
								_column_master_x[column_index],
								_column_master_z[column_index],
								_column_deformation[column_index],
								_column_fault_strength[column_index],
								world_y,
								geology_id
							)
						)


					if resource_id != Resources.NONE:
						buffer.set_voxel(
							resource_id,
							local_x,
							local_y,
							local_z,
							Layout.CHANNEL_RESOURCE
						)


				world_y += world_y_step


# ==================================================
# COLUMN CACHE
# ==================================================

func _ensure_column_cache(
	world_voxel_origin: Vector3i,
	size: Vector3i,
	lod_index: int
) -> void:
	var same_column: bool = (
		_column_cache_valid
		and _column_cache_origin_x
			== world_voxel_origin.x
		and _column_cache_origin_z
			== world_voxel_origin.z
		and _column_cache_size_x
			== size.x
		and _column_cache_size_z
			== size.z
		and _column_cache_lod_index
			== lod_index
	)


	if same_column:
		_column_cache_hit_count += 1
		return


	_build_column_cache(
		world_voxel_origin,
		size,
		lod_index
	)


func _build_column_cache(
	world_voxel_origin: Vector3i,
	size: Vector3i,
	lod_index: int
) -> void:
	var lod_scale: int = (
		1 << lod_index
	)


	var column_count: int = (
		size.x * size.z
	)


	_column_surface_y.resize(
		column_count
	)

	_column_deposit_id.resize(
		column_count
	)

	_column_deposit_base_y.resize(
		column_count
	)

	_column_geology_top_y.resize(
		column_count
	)

	_column_master_x.resize(column_count)
	_column_master_z.resize(column_count)
	_column_deformation.resize(column_count)
	_column_fault_strength.resize(column_count)

	_column_pluton_dx_squared.resize(
		column_count
	)

	_column_pluton_dz_squared.resize(
		column_count
	)

	_column_dike_active.resize(
		column_count
	)


	_column_min_surface_y = INF
	_column_max_surface_y = -INF


	for local_z in range(
		size.z
	):
		for local_x in range(
			size.x
		):
			var column_index: int = (
				local_z * size.x
				+ local_x
			)


			var world_voxel_x: int = (
				world_voxel_origin.x
				+ local_x * lod_scale
			)

			var world_voxel_z: int = (
				world_voxel_origin.z
				+ local_z * lod_scale
			)


			var world_x: float = (
				float(
					world_voxel_x
				)
				* _voxel_size_meters
			)

			var world_z: float = (
				float(
					world_voxel_z
				)
				* _voxel_size_meters
			)


			var surface_y: float = (
				_terrain_sampler.get_surface_y(
					world_x,
					world_z
				)
			)


			_column_surface_y[
				column_index
			] = surface_y


			_column_min_surface_y = minf(
				_column_min_surface_y,
				surface_y
			)

			_column_max_surface_y = maxf(
				_column_max_surface_y,
				surface_y
			)


			var deposit_column: Vector2 = (
				_terrain_sampler.get_deposit_column(
					world_x,
					world_z
				)
			)


			var deposit_id: int = int(
				deposit_column.x
			)

			var deposit_thickness: float = (
				deposit_column.y
			)


			_column_deposit_id[
				column_index
			] = deposit_id


			_column_deposit_base_y[
				column_index
			] = (
				surface_y
				- deposit_thickness
			)


			var geology_sampler = _terrain_sampler._geology_sampler

			var master: Vector2 = geology_sampler.get_master_coordinates(
				world_x,
				world_z
			)

			_column_master_x[column_index] = master.x
			_column_master_z[column_index] = master.y

			var geology_top_y: float = geology_sampler.get_master_column_top_y(
				master.x,
				master.y
			)

			_column_geology_top_y[column_index] = geology_top_y
			_column_deformation[column_index] = (
				geology_top_y
				- _world_definition.stratigraphy_reference_y_meters
			)
			_column_fault_strength[column_index] = (
				geology_sampler.get_master_fault_zone_strength(
					master.x,
					master.y
				)
			)

			_column_pluton_dx_squared[
				column_index
			] = (
				_terrain_sampler
				.get_geology_pluton_dx_squared(
					world_x
				)
			)


			_column_pluton_dz_squared[
				column_index
			] = (
				_terrain_sampler
				.get_geology_pluton_dz_squared(
					world_z
				)
			)


			var dike_active: bool = (
				_terrain_sampler
				.is_geology_dike_column_active(
					world_x,
					world_z
				)
			)


			_column_dike_active[
				column_index
			] = (
				1
				if dike_active
				else 0
			)


	_column_cache_origin_x = (
		world_voxel_origin.x
	)

	_column_cache_origin_z = (
		world_voxel_origin.z
	)

	_column_cache_size_x = size.x
	_column_cache_size_z = size.z

	_column_cache_lod_index = lod_index

	_column_cache_valid = true

	_column_cache_build_count += 1


func clear_column_cache() -> void:
	_column_cache_valid = false

	_column_cache_origin_x = 0
	_column_cache_origin_z = 0

	_column_cache_size_x = 0
	_column_cache_size_z = 0

	_column_cache_lod_index = -1


	_column_surface_y.clear()

	_column_deposit_id.clear()
	_column_deposit_base_y.clear()

	_column_geology_top_y.clear()

	_column_master_x.clear()
	_column_master_z.clear()
	_column_deformation.clear()
	_column_fault_strength.clear()

	_column_pluton_dx_squared.clear()
	_column_pluton_dz_squared.clear()

	_column_dike_active.clear()


	_column_min_surface_y = 0.0
	_column_max_surface_y = 0.0



	if _mineral_sampler != null:
		_mineral_sampler.clear_prepared_columns()


func get_column_cache_build_count() -> int:
	return _column_cache_build_count


func get_column_cache_hit_count() -> int:
	return _column_cache_hit_count


# ==================================================
# SDF
# ==================================================

func _get_sdf_max_distance(
	lod_index: int
) -> float:
	var lod_scale: float = float(
		1 << lod_index
	)

	return minf(
		SDF_BASE_MAX_DISTANCE
			* lod_scale,
		SDF_STORAGE_MAX_DISTANCE
	)
