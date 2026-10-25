class_name WorldBlockBaker
extends RefCounted


const BakedWorld := preload(
	"res://src/shared/baked_world_config.gd"
)

const RegionFormatScript := preload(
	"res://src/shared/baked_region_format.gd"
)

const BlockCodecScript := preload(
	"res://src/shared/baked_block_codec.gd"
)

const RegionWriterScript := preload(
	"res://src/builder/storage/baked_region_writer.gd"
)


const PROGRESS_INTERVAL_BLOCKS := 8192


var _baked_sampler
var _planner = null
var _world_definition = null

var _progress_callback: Callable = Callable()
var _progress_reported_blocks: int = 0

var _verbose: bool = true


var _blocks_processed: int = 0
var _blocks_saved: int = 0
var _voxels_represented: int = 0

var _detailed_blocks_written: int = 0
var _air_blocks_skipped: int = 0
var _deep_blocks_skipped: int = 0

var _last_bake_seconds: float = 0.0


func setup(
	baked_sampler,
	planner = null,
	_skip_uniform_air_blocks: bool = true,
	world_definition = null
) -> void:
	_baked_sampler = baked_sampler
	_planner = planner
	_world_definition = world_definition

	_reset_statistics()


func set_progress_callback(
	progress_callback: Callable
) -> void:
	_progress_callback = progress_callback


func set_verbose(
	enabled: bool
) -> void:
	_verbose = enabled


# ==================================================
# BAKE REGION
# ==================================================

func bake_region(
	output_directory: String,
	region_coord: Vector2i
) -> bool:
	if _baked_sampler == null:
		push_error(
			"WorldBlockBaker has no baked voxel sampler."
		)
		return false

	if _planner == null:
		push_error(
			"WorldBlockBaker has no bake planner."
		)
		return false

	if not RegionFormatScript.validate_format():
		push_error(
			"Baked region format is invalid."
		)
		return false


	_reset_statistics()


	var total_blocks: int = (
		_get_total_blocks_for_region(
			region_coord
		)
	)

	if total_blocks <= 0:
		push_error(
			"Region %s does not overlap the world."
			% str(region_coord)
		)

		return false


	var region_path: String = (
		RegionFormatScript.get_region_path(
			output_directory,
			region_coord
		)
	)


	var writer := RegionWriterScript.new()

	if not writer.create_new(
		region_path,
		region_coord,
		_world_definition
	):
		return false


	var start_msec: int = (
		Time.get_ticks_msec()
	)


	for lod_index in range(
		BakedWorld.LOD_COUNT
	):
		var bounds: Dictionary = (
			_get_region_block_bounds(
				region_coord,
				lod_index
			)
		)

		if not bool(
			bounds["valid"]
		):
			continue


		var minimum: Vector3i = (
			bounds["min"]
		)

		var maximum: Vector3i = (
			bounds["max"]
		)


		for block_z in range(
			minimum.z,
			maximum.z
		):
			for block_x in range(
				minimum.x,
				maximum.x
			):
				if not _process_column(
					writer,
					block_x,
					block_z,
					lod_index,
					minimum.y,
					maximum.y
				):
					writer.close()

					return false


	if not writer.finalize():
		writer.close()

		push_error(
			"Failed to finalize region file."
		)

		return false


	_report_progress(
		true
	)


	var elapsed_msec: int = (
		Time.get_ticks_msec()
		- start_msec
	)

	_last_bake_seconds = (
		float(
			elapsed_msec
		)
		/ 1000.0
	)


	if _verbose:
		_print_completion(
			region_coord,
			region_path
		)


	return true


# ==================================================
# PROCESS COLUMN
#
# Only detailed ranges are looped.
# Air and ordinary deep granite are represented
# implicitly and skipped as whole ranges.
# ==================================================

func _process_column(
	writer,
	block_x: int,
	block_z: int,
	lod_index: int,
	minimum_y: int,
	maximum_y: int
) -> bool:
	var ranges: Array[Vector2i] = (
		_planner
		.get_detailed_y_ranges_for_column(
			block_x,
			block_z,
			lod_index
		)
	)


	var total_column_blocks: int = (
		maximum_y - minimum_y
	)

	var detailed_blocks: int = 0


	for current_range in ranges:
		var range_start: int = maxi(
			minimum_y,
			current_range.x
		)

		var range_end: int = mini(
			maximum_y,
			current_range.y
		)

		if range_end > range_start:
			detailed_blocks += (
				range_end
				- range_start
			)


	# The final detailed range ends at the point where
	# uniform air begins.
	var air_start: int = maximum_y

	if not ranges.is_empty():
		air_start = clampi(
			ranges[
				ranges.size() - 1
			].y,
			minimum_y,
			maximum_y
		)


	var air_blocks: int = maxi(
		0,
		maximum_y - air_start
	)


	var skipped_blocks: int = (
		total_column_blocks
		- detailed_blocks
	)


	var deep_blocks: int = maxi(
		0,
		skipped_blocks
		- air_blocks
	)


	_air_blocks_skipped += (
		air_blocks
	)

	_deep_blocks_skipped += (
		deep_blocks
	)


	# Account for every skipped block in one operation.
	_blocks_processed += (
		skipped_blocks
	)

	_voxels_represented += (
		skipped_blocks
		* BakedWorld.DATA_BLOCK_VOXEL_COUNT
	)


	_report_progress()


	# ==================================================
	# GENERATE ONLY REAL DETAILED BLOCKS
	# ==================================================

	for current_range in ranges:
		var range_start: int = maxi(
			minimum_y,
			current_range.x
		)

		var range_end: int = mini(
			maximum_y,
			current_range.y
		)

		if range_end <= range_start:
			continue


		for block_y in range(
			range_start,
			range_end
		):
			var block_position := Vector3i(
				block_x,
				block_y,
				block_z
			)


			if not _process_detailed_block(
				writer,
				block_position,
				lod_index
			):
				push_error(
					(
						"Region bake failed at "
						+ "LOD%d block %s."
					)
					% [
						lod_index,
						str(
							block_position
						)
					]
				)

				return false


	return true


# ==================================================
# DETAILED BLOCK
# ==================================================

func _process_detailed_block(
	writer,
	block_position: Vector3i,
	lod_index: int
) -> bool:
	_blocks_processed += 1

	_voxels_represented += (
		BakedWorld.DATA_BLOCK_VOXEL_COUNT
	)


	var voxel_origin: Vector3i = (
		_get_lod0_voxel_origin(
			block_position,
			lod_index
		)
	)


	var buffer: VoxelBuffer = (
		_baked_sampler.create_buffer(
			voxel_origin,
			BakedWorld
				.get_data_block_size_vector(),
			lod_index
		)
	)


	if buffer == null:
		push_error(
			"Voxel sampler returned a null buffer."
		)

		return false


	var payload: PackedByteArray = (
		BlockCodecScript.encode_buffer(
			buffer
		)
	)


	if payload.is_empty():
		push_error(
			(
				"Failed to encode LOD%d block %s."
			)
			% [
				lod_index,
				str(
					block_position
				)
			]
		)

		return false


	if not writer.add_block(
		lod_index,
		block_position,
		payload
	):
		return false


	_blocks_saved += 1
	_detailed_blocks_written += 1


	_report_progress()


	return true


# ==================================================
# PROGRESS
# ==================================================

func _report_progress(
	force: bool = false
) -> void:
	if not _progress_callback.is_valid():
		return


	var block_delta: int = (
		_blocks_processed
		- _progress_reported_blocks
	)


	if block_delta <= 0:
		return


	if (
		not force
		and block_delta
			< PROGRESS_INTERVAL_BLOCKS
	):
		return


	_progress_reported_blocks = (
		_blocks_processed
	)


	_progress_callback.call(
		block_delta
	)


# ==================================================
# REGION BOUNDS
# ==================================================

func _get_region_block_bounds(
	region_coord: Vector2i,
	lod_index: int
) -> Dictionary:
	var world_minimum: Vector3i = (
		_planner.get_min_block(
			lod_index
		)
	)

	var world_maximum: Vector3i = (
		_planner.get_max_block_exclusive(
			lod_index
		)
	)


	var blocks_per_axis: int = (
		RegionFormatScript
		.get_blocks_per_region_axis(
			lod_index
		)
	)


	if blocks_per_axis <= 0:
		return {
			"valid": false
		}


	var region_min_x: int = (
		region_coord.x
		* blocks_per_axis
	)

	var region_min_z: int = (
		region_coord.y
		* blocks_per_axis
	)

	var region_max_x: int = (
		region_min_x
		+ blocks_per_axis
	)

	var region_max_z: int = (
		region_min_z
		+ blocks_per_axis
	)


	var minimum := Vector3i(
		maxi(
			world_minimum.x,
			region_min_x
		),
		world_minimum.y,
		maxi(
			world_minimum.z,
			region_min_z
		)
	)


	var maximum := Vector3i(
		mini(
			world_maximum.x,
			region_max_x
		),
		world_maximum.y,
		mini(
			world_maximum.z,
			region_max_z
		)
	)


	var valid: bool = (
		maximum.x > minimum.x
		and maximum.y > minimum.y
		and maximum.z > minimum.z
	)


	return {
		"valid": valid,
		"min": minimum,
		"max": maximum
	}


func _get_total_blocks_for_region(
	region_coord: Vector2i
) -> int:
	var total_blocks: int = 0


	for lod_index in range(
		BakedWorld.LOD_COUNT
	):
		var bounds: Dictionary = (
			_get_region_block_bounds(
				region_coord,
				lod_index
			)
		)

		if not bool(
			bounds["valid"]
		):
			continue


		var minimum: Vector3i = (
			bounds["min"]
		)

		var maximum: Vector3i = (
			bounds["max"]
		)


		total_blocks += (
			(maximum.x - minimum.x)
			* (maximum.y - minimum.y)
			* (maximum.z - minimum.z)
		)


	return total_blocks


# ==================================================
# POSITION
# ==================================================

func _get_lod0_voxel_origin(
	block_position: Vector3i,
	lod_index: int
) -> Vector3i:
	var lod_scale: int = (
		1 << lod_index
	)

	var block_scale: int = (
		BakedWorld.DATA_BLOCK_SIZE
		* lod_scale
	)


	return Vector3i(
		block_position.x
			* block_scale,

		block_position.y
			* block_scale,

		block_position.z
			* block_scale
	)


# ==================================================
# COMPLETION
# ==================================================

func _print_completion(
	region_coord: Vector2i,
	region_path: String
) -> void:
	print(
		"Region ",
		region_coord,
		" complete."
	)

	print(
		"Detailed blocks saved: ",
		_detailed_blocks_written
	)

	print(
		"Deep granite skipped: ",
		_deep_blocks_skipped
	)

	print(
		"Air skipped: ",
		_air_blocks_skipped
	)

	print(
		"Elapsed seconds: ",
		snappedf(
			_last_bake_seconds,
			0.001
		)
	)


	var physical_file := FileAccess.open(
		region_path,
		FileAccess.READ
	)

	if physical_file != null:
		var file_size_bytes: int = (
			physical_file.get_length()
		)

		physical_file.close()

		print(
			"Region file MiB: ",
			snappedf(
				float(
					file_size_bytes
				)
				/ 1048576.0,
				0.001
			)
		)


# ==================================================
# STATS
# ==================================================

func _reset_statistics() -> void:
	_blocks_processed = 0
	_blocks_saved = 0
	_voxels_represented = 0

	_detailed_blocks_written = 0
	_air_blocks_skipped = 0
	_deep_blocks_skipped = 0

	_last_bake_seconds = 0.0

	_progress_reported_blocks = 0


func get_blocks_written() -> int:
	return _blocks_saved


func get_blocks_processed() -> int:
	return _blocks_processed


func get_blocks_saved() -> int:
	return _blocks_saved


func get_voxels_written() -> int:
	return _voxels_represented


func get_voxels_represented() -> int:
	return _voxels_represented


func get_detailed_blocks_written() -> int:
	return _detailed_blocks_written


func get_air_blocks_written() -> int:
	return 0


func get_air_blocks_skipped() -> int:
	return _air_blocks_skipped


func get_deep_blocks_written() -> int:
	return 0


func get_deep_blocks_skipped() -> int:
	return _deep_blocks_skipped


func get_last_bake_seconds() -> float:
	return _last_bake_seconds
