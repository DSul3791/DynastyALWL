class_name RegionBakeWorkerPool
extends RefCounted


const RegionBakeJobScript := preload(
	"res://src/builder/storage/region_bake_job.gd"
)

const WorldBakePlannerScript := preload(
	"res://src/builder/terrain/world_bake_planner.gd"
)

const RegionFormatScript := preload(
	"res://src/shared/baked_region_format.gd"
)

const BakedWorldScript := preload(
	"res://src/shared/baked_world_config.gd"
)


# The bakers report every 8192 blocks, but this prevents
# the console itself from being spammed.
const PROGRESS_PRINT_INTERVAL_MSEC := 10000


var _region_jobs: Array[Vector2i] = []

var _next_job_index: int = 0

var _completed_jobs: int = 0
var _failed_jobs: int = 0


var _total_blocks: int = 0
var _processed_blocks: int = 0

var _bake_start_msec: int = 0
var _last_progress_print_msec: int = 0
var _last_printed_percent: float = 0.0


var _queue_mutex := Mutex.new()
var _stats_mutex := Mutex.new()
var _progress_mutex := Mutex.new()


var _threads: Array[Thread] = []


# ==================================================
# SHARED READ-ONLY WORLD DATA
#
# Worker threads no longer share generator/sampler
# objects.
#
# Each RegionBakeJob creates its own:
#
# - DeformedGeologySampler
# - MineralDepositSampler
# - FinalTerrainSampler
# - BakedVoxelSampler
# - WorldBakePlanner
# - WorldBlockBaker
#
# The objects below are only read after workers begin.
# ==================================================

var _world_definition = null
var _stratigraphy = null
var _terrain_field = null
var _deposit_map = null

var _output_directory: String = ""


func run(
	region_jobs: Array[Vector2i],
	worker_count: int,
	world_definition,
	stratigraphy,
	terrain_field,
	deposit_map,
	output_directory: String
) -> bool:
	if region_jobs.is_empty():
		push_error(
			"Region bake worker pool received no jobs."
		)
		return false

	if worker_count <= 0:
		push_error(
			"Region bake worker count must be greater than zero."
		)
		return false

	if world_definition == null:
		push_error(
			"Region bake worker pool has no world definition."
		)
		return false

	if stratigraphy == null:
		push_error(
			"Region bake worker pool has no stratigraphy."
		)
		return false

	if terrain_field == null:
		push_error(
			"Region bake worker pool has no terrain field."
		)
		return false

	if deposit_map == null:
		push_error(
			"Region bake worker pool has no deposit map."
		)
		return false

	if output_directory.is_empty():
		push_error(
			"Region bake worker pool has no output directory."
		)
		return false

	_region_jobs.clear()

	for region_coord in region_jobs:
		_region_jobs.append(
			region_coord
		)

	_next_job_index = 0

	_completed_jobs = 0
	_failed_jobs = 0

	_processed_blocks = 0

	_world_definition = world_definition
	_stratigraphy = stratigraphy
	_terrain_field = terrain_field
	_deposit_map = deposit_map

	_output_directory = output_directory

	_threads.clear()

	# --------------------------------------------------
	# EXACT GLOBAL DENOMINATOR
	#
	# This calculates only block bounds. It does not
	# generate or classify any terrain.
	# --------------------------------------------------

	_total_blocks = (
		_calculate_total_logical_blocks(
			world_definition,
			terrain_field
		)
	)

	if _total_blocks <= 0:
		push_error(
			"Could not calculate total world bake blocks."
		)
		return false

	var actual_worker_count: int = mini(
		worker_count,
		_region_jobs.size()
	)

	_bake_start_msec = (
		Time.get_ticks_msec()
	)

	_last_progress_print_msec = (
		_bake_start_msec
	)

	_last_printed_percent = 0.0

	print(
		_format_progress_line(
			0.0,
			_bake_start_msec
		)
	)

	# --------------------------------------------------
	# START WORKERS
	# --------------------------------------------------

	for worker_index in range(
		actual_worker_count
	):
		var worker_thread := Thread.new()

		var start_error: Error = (
			worker_thread.start(
				_worker_loop.bind(
					worker_index
				)
			)
		)

		if start_error != OK:
			push_error(
				(
					"Failed to start region worker %d. "
					+ "Error: %d"
				)
				% [
					worker_index,
					int(
						start_error
					)
				]
			)

			continue

		_threads.append(
			worker_thread
		)

	if _threads.is_empty():
		push_error(
			"No region workers could be started."
		)
		return false

	# --------------------------------------------------
	# WAIT FOR ALL REGION JOBS
	# --------------------------------------------------

	for worker_thread in _threads:
		worker_thread.wait_to_finish()

	_threads.clear()

	var all_succeeded: bool = (
		_failed_jobs == 0
		and _completed_jobs
			== _region_jobs.size()
	)

	if all_succeeded:
		if _last_printed_percent < 100.0:
			_last_printed_percent = 100.0

			var now_msec: int = (
				Time.get_ticks_msec()
			)

			print(
				_format_progress_line(
					100.0,
					now_msec
				)
			)

	return all_succeeded


# ==================================================
# WORKER LOOP
# ==================================================

func _worker_loop(
	_worker_index: int
) -> void:
	while true:
		var job_index: int = (
			_claim_next_job()
		)

		if job_index < 0:
			break

		var region_coord: Vector2i = (
			_region_jobs[
				job_index
			]
		)

		var region_job := (
			RegionBakeJobScript.new()
		)

		region_job.setup(
			_world_definition,
			_stratigraphy,
			_terrain_field,
			_deposit_map,
			_output_directory,
			Callable(
				self,
				"_on_blocks_processed"
			)
		)

		var region_start_msec: int = Time.get_ticks_msec()

		var success: bool = (
			region_job.bake_region(
				region_coord
			)
		)

		var region_elapsed_seconds: float = (
			float(Time.get_ticks_msec() - region_start_msec) / 1000.0
		)

		print(
			"REGION ", region_coord,
			" | ", "complete" if success else "FAILED",
			" | ", snappedf(region_elapsed_seconds / 60.0, 0.01),
			" min"
		)

		_record_result(
			success
		)


# ==================================================
# QUEUE
# ==================================================

func _claim_next_job() -> int:
	_queue_mutex.lock()

	var job_index: int = -1

	if (
		_next_job_index
		< _region_jobs.size()
	):
		job_index = _next_job_index
		_next_job_index += 1

	_queue_mutex.unlock()

	return job_index


# ==================================================
# GLOBAL PROGRESS
# ==================================================

func _on_blocks_processed(
	block_delta: int
) -> void:
	if block_delta <= 0:
		return

	var should_print: bool = false
	var percent_complete: float = 0.0
	var print_msec: int = 0

	_progress_mutex.lock()

	_processed_blocks = mini(
		_processed_blocks
			+ block_delta,
		_total_blocks
	)

	var now_msec: int = (
		Time.get_ticks_msec()
	)

	var time_to_print: bool = (
		now_msec
			- _last_progress_print_msec
		>= PROGRESS_PRINT_INTERVAL_MSEC
	)

	var reached_end: bool = (
		_processed_blocks
		>= _total_blocks
	)

	if (
		time_to_print
		or reached_end
	):
		percent_complete = (
			float(
				_processed_blocks
			)
			/ float(
				_total_blocks
			)
			* 100.0
		)

		percent_complete = clampf(
			percent_complete,
			0.0,
			100.0
		)

		_last_progress_print_msec = (
			now_msec
		)

		_last_printed_percent = (
			percent_complete
		)

		print_msec = now_msec
		should_print = true

	_progress_mutex.unlock()

	if should_print:
		print(
			_format_progress_line(
				percent_complete,
				print_msec
			)
		)


# ==================================================
# PROGRESS DISPLAY
# ==================================================

func _format_progress_line(
	percent_complete: float,
	now_msec: int
) -> String:
	var elapsed_msec: int = maxi(
		now_msec - _bake_start_msec,
		0
	)

	var elapsed_seconds: float = (
		float(
			elapsed_msec
		)
		/ 1000.0
	)

	var elapsed_hours_total: float = (
		elapsed_seconds
		/ 3600.0
	)

	var elapsed_hours_display: int = int(
		floor(
			elapsed_hours_total
		)
	)

	var elapsed_minutes_display: int = int(
		floor(
			fmod(
				elapsed_seconds,
				3600.0
			)
			/ 60.0
		)
	)

	var percent_per_hour: float = 0.0

	if elapsed_hours_total > 0.0:
		percent_per_hour = (
			percent_complete
			/ elapsed_hours_total
		)

	return (
		"WORLD BAKE: %.2f%% | elapsed %02dh %02dm | %.2f%%/hr"
		% [
			percent_complete,
			elapsed_hours_display,
			elapsed_minutes_display,
			percent_per_hour
		]
	)


# ==================================================
# RESULTS
# ==================================================

func _record_result(
	success: bool
) -> void:
	_stats_mutex.lock()

	if success:
		_completed_jobs += 1
	else:
		_failed_jobs += 1

	_stats_mutex.unlock()


# ==================================================
# TOTAL BLOCK COUNT
# ==================================================

func _calculate_total_logical_blocks(
	world_definition,
	terrain_field
) -> int:
	var planner := (
		WorldBakePlannerScript.new()
	)

	planner.setup(
		world_definition,
		terrain_field
	)

	var total_blocks: int = 0

	for region_coord in _region_jobs:
		for lod_index in range(
			BakedWorldScript.LOD_COUNT
		):
			total_blocks += (
				_get_region_block_count(
					planner,
					region_coord,
					lod_index
				)
			)

	return total_blocks


func _get_region_block_count(
	planner,
	region_coord: Vector2i,
	lod_index: int
) -> int:
	var world_minimum: Vector3i = (
		planner.get_min_block(
			lod_index
		)
	)

	var world_maximum: Vector3i = (
		planner.get_max_block_exclusive(
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
		return 0

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

	if (
		maximum.x <= minimum.x
		or maximum.y <= minimum.y
		or maximum.z <= minimum.z
	):
		return 0

	return (
		(maximum.x - minimum.x)
		* (maximum.y - minimum.y)
		* (maximum.z - minimum.z)
	)
