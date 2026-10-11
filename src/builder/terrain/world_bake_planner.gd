class_name WorldBakePlanner
extends RefCounted


const BakedWorld := preload(
	"res://src/shared/baked_world_config.gd"
)

const Intrusions := preload(
	"res://src/builder/geology/igneous_intrusions.gd"
)


const BLOCK_DETAILED := 0
const BLOCK_UNIFORM_AIR := 1
const BLOCK_DEEP_GRANITE := 2


const SDF_BASE_MAX_DISTANCE := 64.0
const SDF_STORAGE_MAX_DISTANCE := 500.0

const FALLBACK_DEEP_GRANITE_LIMIT_METERS := -1000.0

const PRIMARY_FAULT_HALF_WIDTH := 50.0
const SECONDARY_FAULT_HALF_WIDTH := 40.0

const DEEP_CONTACT_RADIUS_FACTOR := 1.22
const DEEP_FEEDER_HALF_WIDTH := 90.0


var _world_definition
var _terrain_field
var _geology_sampler = null

var _stratigraphy_thickness_meters: float = 0.0


var _surface_range_cache: Dictionary = {}
var _geology_top_range_cache: Dictionary = {}
var _range_cache: Dictionary = {}


func setup(
	world_definition,
	terrain_field,
	geology_sampler = null,
	stratigraphy = null
) -> void:
	_world_definition = world_definition
	_terrain_field = terrain_field
	_geology_sampler = geology_sampler

	_stratigraphy_thickness_meters = 0.0

	if stratigraphy != null:
		for layer in stratigraphy.layers:
			_stratigraphy_thickness_meters += (
				layer.thickness_meters
			)

	clear_caches()


# ==================================================
# WORLD BLOCK BOUNDS
# ==================================================

func get_min_block(
	lod_index: int = 0
) -> Vector3i:
	var block_world_size: float = (
		_get_block_world_size(
			lod_index
		)
	)

	return Vector3i(
		int(
			floor(
				_world_definition.get_min_x()
				/ block_world_size
			)
		),
		int(
			floor(
				float(
					_world_definition.world_bottom_meters
				)
				/ block_world_size
			)
		),
		int(
			floor(
				_world_definition.get_min_z()
				/ block_world_size
			)
		)
	)


func get_max_block_exclusive(
	lod_index: int = 0
) -> Vector3i:
	var block_world_size: float = (
		_get_block_world_size(
			lod_index
		)
	)

	return Vector3i(
		int(
			ceil(
				_world_definition.get_max_x()
				/ block_world_size
			)
		),
		int(
			ceil(
				float(
					_world_definition.world_top_meters
				)
				/ block_world_size
			)
		),
		int(
			ceil(
				_world_definition.get_max_z()
				/ block_world_size
			)
		)
	)


func get_total_blocks(
	lod_index: int = 0
) -> int:
	var minimum: Vector3i = (
		get_min_block(
			lod_index
		)
	)

	var maximum: Vector3i = (
		get_max_block_exclusive(
			lod_index
		)
	)

	var dimensions: Vector3i = (
		maximum - minimum
	)

	return (
		dimensions.x
		* dimensions.y
		* dimensions.z
	)


# ==================================================
# DETAILED Y RANGES
# ==================================================

func get_detailed_y_ranges_for_column(
	block_x: int,
	block_z: int,
	lod_index: int = 0
) -> Array[Vector2i]:
	var cache_key := Vector3i(
		block_x,
		lod_index,
		block_z
	)

	if _range_cache.has(
		cache_key
	):
		return _range_cache[
			cache_key
		].duplicate()


	var world_minimum: Vector3i = (
		get_min_block(
			lod_index
		)
	)

	var world_maximum: Vector3i = (
		get_max_block_exclusive(
			lod_index
		)
	)


	var surface_range: Vector2 = (
		get_surface_range_for_block(
			block_x,
			block_z,
			lod_index
		)
	)


	var top_detail_end: int = clampi(
		_get_air_start_block_y(
			surface_range.y,
			lod_index
		),
		world_minimum.y,
		world_maximum.y
	)


	var main_detail_start: int = (
		_get_main_detail_start_block_y(
			block_x,
			block_z,
			lod_index,
			surface_range.x
		)
	)

	main_detail_start = clampi(
		main_detail_start,
		world_minimum.y,
		top_detail_end
	)


	var ranges: Array[Vector2i] = []


	# ==================================================
	# NORMAL STRATIGRAPHY + SURFACE
	# ==================================================

	_add_range(
		ranges,
		main_detail_start,
		top_detail_end,
		world_minimum.y,
		top_detail_end
	)


	# ==================================================
	# DEEP FEATURES
	# ==================================================

	var column_bounds: Dictionary = (
		_get_master_column_bounds(
			block_x,
			block_z,
			lod_index
		)
	)


	# A seam-crossing block is rare. Keep it conservative.
	if bool(
		column_bounds["wrap_seam"]
	):
		_add_range(
			ranges,
			world_minimum.y,
			main_detail_start,
			world_minimum.y,
			top_detail_end
		)

	else:

		# Fault caves can extend throughout basement.
		if _column_intersects_fault(
			column_bounds
		):
			_add_range(
				ranges,
				world_minimum.y,
				main_detail_start,
				world_minimum.y,
				top_detail_end
			)


		# Deep intrusive body A.
		if _column_intersects_deep_body(
			column_bounds,
			Intrusions.DEEP_A_CENTER_X,
			Intrusions.DEEP_A_CENTER_Z,
			Intrusions.DEEP_A_RADIUS_X,
			Intrusions.DEEP_A_RADIUS_Z
		):
			_add_world_y_feature_range(
				ranges,
				Intrusions.DEEP_A_CENTER_Y
					- Intrusions.DEEP_A_RADIUS_Y
					* DEEP_CONTACT_RADIUS_FACTOR,
				Intrusions.DEEP_A_CENTER_Y
					+ Intrusions.DEEP_A_RADIUS_Y
					* DEEP_CONTACT_RADIUS_FACTOR,
				lod_index,
				world_minimum.y,
				top_detail_end
			)


		# Deep intrusive body B.
		if _column_intersects_deep_body(
			column_bounds,
			Intrusions.DEEP_B_CENTER_X,
			Intrusions.DEEP_B_CENTER_Z,
			Intrusions.DEEP_B_RADIUS_X,
			Intrusions.DEEP_B_RADIUS_Z
		):
			_add_world_y_feature_range(
				ranges,
				Intrusions.DEEP_B_CENTER_Y
					- Intrusions.DEEP_B_RADIUS_Y
					* DEEP_CONTACT_RADIUS_FACTOR,
				Intrusions.DEEP_B_CENTER_Y
					+ Intrusions.DEEP_B_RADIUS_Y
					* DEEP_CONTACT_RADIUS_FACTOR,
				lod_index,
				world_minimum.y,
				top_detail_end
			)


		# Deep hydrothermal feeder.
		if _column_intersects_feeder(
			column_bounds
		):
			_add_world_y_feature_range(
				ranges,
				Intrusions.DEEP_FEEDER_MIN_Y,
				Intrusions.DEEP_FEEDER_MAX_Y,
				lod_index,
				world_minimum.y,
				top_detail_end
			)


	var merged: Array[Vector2i] = (
		_merge_ranges(
			ranges
		)
	)

	_range_cache[
		cache_key
	] = merged.duplicate()

	return merged


# ==================================================
# MAIN GEOLOGY RANGE START
# ==================================================

func _get_main_detail_start_block_y(
	block_x: int,
	block_z: int,
	lod_index: int,
	column_min_surface: float
) -> int:
	var block_world_size: float = (
		_get_block_world_size(
			lod_index
		)
	)

	var lod_scale: float = float(
		1 << lod_index
	)

	var sample_span: float = (
		float(
			BakedWorld.DATA_BLOCK_SIZE - 1
		)
		* lod_scale
		* _world_definition.voxel_size_meters
	)


	# ==================================================
	# ACCURATE BASEMENT BOUNDARY
	# ==================================================

	if (
		_geology_sampler != null
		and _stratigraphy_thickness_meters > 0.0
	):
		var geology_top_range: Vector2 = (
			_get_geology_top_range_for_block(
				block_x,
				block_z,
				lod_index
			)
		)

		var deepest_basement_boundary: float = (
			geology_top_range.x
			- _stratigraphy_thickness_meters
		)

		return (
			int(
				floor(
					(
						deepest_basement_boundary
						- sample_span
					)
					/ block_world_size
				)
			)
			+ 1
		)


	# ==================================================
	# FALLBACK
	# ==================================================

	var safe_ceiling: float = minf(
		FALLBACK_DEEP_GRANITE_LIMIT_METERS,
		column_min_surface
			- _get_sdf_max_distance(
				lod_index
			)
	)

	return (
		int(
			floor(
				(
					safe_ceiling
						- sample_span
				)
				/ block_world_size
			)
		)
		+ 1
	)


# ==================================================
# BLOCK CLASS
# ==================================================

func get_block_class(
	block_position: Vector3i,
	lod_index: int = 0
) -> int:
	var ranges: Array[Vector2i] = (
		get_detailed_y_ranges_for_column(
			block_position.x,
			block_position.z,
			lod_index
		)
	)

	for current_range in ranges:
		if (
			block_position.y >= current_range.x
			and block_position.y < current_range.y
		):
			return BLOCK_DETAILED


	var surface_range: Vector2 = (
		get_surface_range_for_block(
			block_position.x,
			block_position.z,
			lod_index
		)
	)

	var air_start: int = (
		_get_air_start_block_y(
			surface_range.y,
			lod_index
		)
	)

	if block_position.y >= air_start:
		return BLOCK_UNIFORM_AIR

	return BLOCK_DEEP_GRANITE


# ==================================================
# COUNTS
# ==================================================

func get_air_blocks(
	lod_index: int = 0
) -> int:
	return _count_block_class(
		BLOCK_UNIFORM_AIR,
		lod_index
	)


func get_surface_blocks(
	lod_index: int = 0
) -> int:
	return _count_block_class(
		BLOCK_DETAILED,
		lod_index
	)


func get_deep_blocks(
	lod_index: int = 0
) -> int:
	return _count_block_class(
		BLOCK_DEEP_GRANITE,
		lod_index
	)


func _count_block_class(
	target_class: int,
	lod_index: int
) -> int:
	var minimum: Vector3i = (
		get_min_block(
			lod_index
		)
	)

	var maximum: Vector3i = (
		get_max_block_exclusive(
			lod_index
		)
	)

	var count: int = 0


	for block_z in range(
		minimum.z,
		maximum.z
	):
		for block_x in range(
			minimum.x,
			maximum.x
		):
			var ranges: Array[Vector2i] = (
				get_detailed_y_ranges_for_column(
					block_x,
					block_z,
					lod_index
				)
			)

			var detailed_count: int = 0

			for current_range in ranges:
				detailed_count += (
					current_range.y
					- current_range.x
				)


			var surface_range: Vector2 = (
				get_surface_range_for_block(
					block_x,
					block_z,
					lod_index
				)
			)

			var air_start: int = clampi(
				_get_air_start_block_y(
					surface_range.y,
					lod_index
				),
				minimum.y,
				maximum.y
			)

			var air_count: int = (
				maximum.y
				- air_start
			)

			var total_column: int = (
				maximum.y
				- minimum.y
			)

			var deep_count: int = maxi(
				0,
				total_column
					- detailed_count
					- air_count
			)


			match target_class:
				BLOCK_DETAILED:
					count += detailed_count

				BLOCK_UNIFORM_AIR:
					count += air_count

				BLOCK_DEEP_GRANITE:
					count += deep_count


	return count


# ==================================================
# AIR START
# ==================================================

func _get_air_start_block_y(
	column_max_surface: float,
	lod_index: int
) -> int:
	var block_world_size: float = (
		_get_block_world_size(
			lod_index
		)
	)

	var highest_detailed_y: float = (
		column_max_surface
		+ _get_sdf_max_distance(
			lod_index
		)
	)

	return (
		int(
			floor(
				highest_detailed_y
				/ block_world_size
			)
		)
		+ 1
	)


# ==================================================
# RANGE HELPERS
# ==================================================

func _add_world_y_feature_range(
	ranges: Array[Vector2i],
	min_world_y: float,
	max_world_y: float,
	lod_index: int,
	min_block_y: int,
	max_block_y: int
) -> void:
	var block_world_size: float = (
		_get_block_world_size(
			lod_index
		)
	)

	var lod_scale: float = float(
		1 << lod_index
	)

	var sample_span: float = (
		float(
			BakedWorld.DATA_BLOCK_SIZE - 1
		)
		* lod_scale
		* _world_definition.voxel_size_meters
	)

	var first_block: int = int(
		ceil(
			(
				min_world_y
					- sample_span
			)
			/ block_world_size
		)
	)

	var last_block_exclusive: int = (
		int(
			floor(
				max_world_y
					/ block_world_size
			)
		)
		+ 1
	)

	_add_range(
		ranges,
		first_block,
		last_block_exclusive,
		min_block_y,
		max_block_y
	)


func _add_range(
	ranges: Array[Vector2i],
	start_y: int,
	end_y: int,
	min_y: int,
	max_y: int
) -> void:
	start_y = clampi(
		start_y,
		min_y,
		max_y
	)

	end_y = clampi(
		end_y,
		min_y,
		max_y
	)

	if end_y <= start_y:
		return

	ranges.append(
		Vector2i(
			start_y,
			end_y
		)
	)


func _merge_ranges(
	ranges: Array[Vector2i]
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if ranges.is_empty():
		return result

	ranges.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x
	)

	var current: Vector2i = (
		ranges[0]
	)

	for index in range(
		1,
		ranges.size()
	):
		var next_range: Vector2i = (
			ranges[index]
		)

		if next_range.x <= current.y:
			current.y = maxi(
				current.y,
				next_range.y
			)

		else:
			result.append(
				current
			)

			current = next_range

	result.append(
		current
	)

	return result


# ==================================================
# FEATURE COLUMN BOUNDS
# ==================================================

func _get_master_column_bounds(
	block_x: int,
	block_z: int,
	lod_index: int
) -> Dictionary:
	var lod_scale: int = (
		1 << lod_index
	)

	var voxel_size: float = (
		_world_definition.voxel_size_meters
	)

	var first_voxel_x: int = (
		block_x
		* BakedWorld.DATA_BLOCK_SIZE
		* lod_scale
	)

	var first_voxel_z: int = (
		block_z
		* BakedWorld.DATA_BLOCK_SIZE
		* lod_scale
	)

	var last_voxel_x: int = (
		first_voxel_x
		+ (
			BakedWorld.DATA_BLOCK_SIZE - 1
		)
		* lod_scale
	)

	var last_voxel_z: int = (
		first_voxel_z
		+ (
			BakedWorld.DATA_BLOCK_SIZE - 1
		)
		* lod_scale
	)

	var x0: float = (
		float(first_voxel_x)
		* voxel_size
	)

	var x1: float = (
		float(last_voxel_x)
		* voxel_size
	)

	var z0: float = (
		float(first_voxel_z)
		* voxel_size
	)

	var z1: float = (
		float(last_voxel_z)
		* voxel_size
	)


	var p00 := Vector2(
		_map_x_to_master(x0),
		_map_z_to_master(z0)
	)

	var p10 := Vector2(
		_map_x_to_master(x1),
		_map_z_to_master(z0)
	)

	var p01 := Vector2(
		_map_x_to_master(x0),
		_map_z_to_master(z1)
	)

	var p11 := Vector2(
		_map_x_to_master(x1),
		_map_z_to_master(z1)
	)


	var min_x: float = minf(
		minf(
			p00.x,
			p10.x
		),
		minf(
			p01.x,
			p11.x
		)
	)

	var max_x: float = maxf(
		maxf(
			p00.x,
			p10.x
		),
		maxf(
			p01.x,
			p11.x
		)
	)

	var min_z: float = minf(
		minf(
			p00.y,
			p10.y
		),
		minf(
			p01.y,
			p11.y
		)
	)

	var max_z: float = maxf(
		maxf(
			p00.y,
			p10.y
		),
		maxf(
			p01.y,
			p11.y
		)
	)


	var expected_span: float = (
		float(
			BakedWorld.DATA_BLOCK_SIZE
		)
		* float(lod_scale)
		* voxel_size
	)

	var wrap_seam: bool = (
		max_x - min_x
			> expected_span * 2.0
		or max_z - min_z
			> expected_span * 2.0
	)

	return {
		"p00": p00,
		"p10": p10,
		"p01": p01,
		"p11": p11,
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z,
		"wrap_seam": wrap_seam
	}


func _column_intersects_fault(
	bounds: Dictionary
) -> bool:
	var points: Array[Vector2] = [
		bounds["p00"],
		bounds["p10"],
		bounds["p01"],
		bounds["p11"]
	]

	var primary_min: float = INF
	var primary_max: float = -INF

	var secondary_min: float = INF
	var secondary_max: float = -INF


	for point in points:
		var primary: float = (
			point.x
			- point.y * 0.22
			- 95.0
		)

		var secondary: float = (
			point.x
			+ point.y * 0.55
			+ 265.0
		)

		primary_min = minf(
			primary_min,
			primary
		)

		primary_max = maxf(
			primary_max,
			primary
		)

		secondary_min = minf(
			secondary_min,
			secondary
		)

		secondary_max = maxf(
			secondary_max,
			secondary
		)


	if (
		primary_min
			<= PRIMARY_FAULT_HALF_WIDTH
		and primary_max
			>= -PRIMARY_FAULT_HALF_WIDTH
	):
		return true

	if (
		secondary_min
			<= SECONDARY_FAULT_HALF_WIDTH
		and secondary_max
			>= -SECONDARY_FAULT_HALF_WIDTH
	):
		return true

	return false


func _column_intersects_deep_body(
	bounds: Dictionary,
	center_x: float,
	center_z: float,
	radius_x: float,
	radius_z: float
) -> bool:
	var expanded_x: float = (
		radius_x
		* DEEP_CONTACT_RADIUS_FACTOR
	)

	var expanded_z: float = (
		radius_z
		* DEEP_CONTACT_RADIUS_FACTOR
	)

	if (
		float(bounds["max_x"])
		< center_x - expanded_x
	):
		return false

	if (
		float(bounds["min_x"])
		> center_x + expanded_x
	):
		return false

	if (
		float(bounds["max_z"])
		< center_z - expanded_z
	):
		return false

	if (
		float(bounds["min_z"])
		> center_z + expanded_z
	):
		return false

	return true


func _column_intersects_feeder(
	bounds: Dictionary
) -> bool:
	var points: Array[Vector2] = [
		bounds["p00"],
		bounds["p10"],
		bounds["p01"],
		bounds["p11"]
	]

	var minimum: float = INF
	var maximum: float = -INF

	for point in points:
		var coordinate: float = (
			point.x
			+ point.y * 0.42
			- 260.0
		)

		minimum = minf(
			minimum,
			coordinate
		)

		maximum = maxf(
			maximum,
			coordinate
		)

	return (
		minimum
			<= DEEP_FEEDER_HALF_WIDTH
		and maximum
			>= -DEEP_FEEDER_HALF_WIDTH
	)


# ==================================================
# SURFACE RANGE
# ==================================================

func get_surface_range_for_block(
	block_x: int,
	block_z: int,
	lod_index: int = 0
) -> Vector2:
	var cache_key := Vector3i(
		block_x,
		lod_index,
		block_z
	)

	if _surface_range_cache.has(
		cache_key
	):
		return _surface_range_cache[
			cache_key
		]


	var lod_scale: int = (
		1 << lod_index
	)

	var voxel_size: float = (
		_world_definition.voxel_size_meters
	)

	var origin_voxel_x: int = (
		block_x
		* BakedWorld.DATA_BLOCK_SIZE
		* lod_scale
	)

	var origin_voxel_z: int = (
		block_z
		* BakedWorld.DATA_BLOCK_SIZE
		* lod_scale
	)


	var minimum_surface: float = INF
	var maximum_surface: float = -INF


	for local_z in range(
		BakedWorld.DATA_BLOCK_SIZE
	):
		for local_x in range(
			BakedWorld.DATA_BLOCK_SIZE
		):
			var world_x: float = (
				float(
					origin_voxel_x
					+ local_x * lod_scale
				)
				* voxel_size
			)

			var world_z: float = (
				float(
					origin_voxel_z
					+ local_z * lod_scale
				)
				* voxel_size
			)

			var surface_y: float = (
				_get_surface_y(
					world_x,
					world_z
				)
			)

			minimum_surface = minf(
				minimum_surface,
				surface_y
			)

			maximum_surface = maxf(
				maximum_surface,
				surface_y
			)


	var result := Vector2(
		minimum_surface,
		maximum_surface
	)

	_surface_range_cache[
		cache_key
	] = result

	return result


# ==================================================
# GEOLOGY TOP RANGE
# ==================================================

func _get_geology_top_range_for_block(
	block_x: int,
	block_z: int,
	lod_index: int
) -> Vector2:
	var cache_key := Vector3i(
		block_x,
		lod_index,
		block_z
	)

	if _geology_top_range_cache.has(
		cache_key
	):
		return _geology_top_range_cache[
			cache_key
		]


	var lod_scale: int = (
		1 << lod_index
	)

	var voxel_size: float = (
		_world_definition.voxel_size_meters
	)

	var origin_voxel_x: int = (
		block_x
		* BakedWorld.DATA_BLOCK_SIZE
		* lod_scale
	)

	var origin_voxel_z: int = (
		block_z
		* BakedWorld.DATA_BLOCK_SIZE
		* lod_scale
	)


	var minimum_top: float = INF
	var maximum_top: float = -INF


	for local_z in range(
		BakedWorld.DATA_BLOCK_SIZE
	):
		for local_x in range(
			BakedWorld.DATA_BLOCK_SIZE
		):
			var world_x: float = (
				float(
					origin_voxel_x
					+ local_x * lod_scale
				)
				* voxel_size
			)

			var world_z: float = (
				float(
					origin_voxel_z
					+ local_z * lod_scale
				)
				* voxel_size
			)

			var top_y: float = (
				_geology_sampler.get_column_top_y(
					world_x,
					world_z
				)
			)

			minimum_top = minf(
				minimum_top,
				top_y
			)

			maximum_top = maxf(
				maximum_top,
				top_y
			)


	var result := Vector2(
		minimum_top,
		maximum_top
	)

	_geology_top_range_cache[
		cache_key
	] = result

	return result


# ==================================================
# CACHES
# ==================================================

func get_surface_range_cache_size() -> int:
	return _surface_range_cache.size()


func clear_surface_range_cache() -> void:
	clear_caches()


func clear_caches() -> void:
	_surface_range_cache.clear()
	_geology_top_range_cache.clear()
	_range_cache.clear()


# ==================================================
# TERRAIN LOOKUP
# ==================================================

func _get_surface_y(
	world_x: float,
	world_z: float
) -> float:
	var spacing: float = (
		_terrain_field.get_spacing_meters()
	)

	var width: int = (
		_terrain_field.get_width()
	)

	var depth: int = (
		_terrain_field.get_depth()
	)

	if (
		spacing <= 0.0
		or width <= 0
		or depth <= 0
	):
		return 0.0


	var minimum_x: float = (
		_world_definition.get_min_x()
	)

	var minimum_z: float = (
		_world_definition.get_min_z()
	)

	var maximum_x: float = (
		_world_definition.get_max_x()
	)

	var maximum_z: float = (
		_world_definition.get_max_z()
	)

	var world_width: float = (
		maximum_x - minimum_x
	)

	var world_depth: float = (
		maximum_z - minimum_z
	)


	var wrapped_x: float = minimum_x

	if world_width > 0.0:
		wrapped_x = (
			minimum_x
			+ fposmod(
				world_x - minimum_x,
				world_width
			)
		)


	var wrapped_z: float = minimum_z

	if world_depth > 0.0:
		wrapped_z = (
			minimum_z
			+ fposmod(
				world_z - minimum_z,
				world_depth
			)
		)


	var grid_x_float: float = (
		(wrapped_x - minimum_x)
		/ spacing
	)

	var grid_z_float: float = (
		(wrapped_z - minimum_z)
		/ spacing
	)


	var grid_x_floor: float = floor(
		grid_x_float
	)

	var grid_z_floor: float = floor(
		grid_z_float
	)


	var grid_x0: int = posmod(
		int(grid_x_floor),
		width
	)

	var grid_z0: int = posmod(
		int(grid_z_floor),
		depth
	)

	var grid_x1: int = posmod(
		grid_x0 + 1,
		width
	)

	var grid_z1: int = posmod(
		grid_z0 + 1,
		depth
	)


	var fraction_x: float = (
		grid_x_float
		- grid_x_floor
	)

	var fraction_z: float = (
		grid_z_float
		- grid_z_floor
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


	var lower: float = lerpf(
		height_00,
		height_10,
		fraction_x
	)

	var upper: float = lerpf(
		height_01,
		height_11,
		fraction_x
	)

	return lerpf(
		lower,
		upper,
		fraction_z
	)


# ==================================================
# MASTER COORDINATES
# ==================================================

func _map_x_to_master(
	x: float
) -> float:
	if _world_definition == null:
		return x

	return _world_definition.to_island_local_x(x)


func _map_z_to_master(
	z: float
) -> float:
	if _world_definition == null:
		return z

	return _world_definition.to_island_local_z(z)


# ==================================================
# BLOCK SIZE / SDF
# ==================================================

func _get_block_world_size(
	lod_index: int
) -> float:
	return (
		float(
			BakedWorld.DATA_BLOCK_SIZE
		)
		* float(
			1 << lod_index
		)
		* _world_definition.voxel_size_meters
	)


func _get_sdf_max_distance(
	lod_index: int
) -> float:
	return minf(
		SDF_BASE_MAX_DISTANCE
			* float(
				1 << lod_index
			),
		SDF_STORAGE_MAX_DISTANCE
	)
