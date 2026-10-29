extends Node


const WORLD_DEFINITION_PATH := (
	"res://worlds/base_world/world_definition.tres"
)

const STRATIGRAPHY_PATH := (
	"res://worlds/base_world/base_stratigraphy.tres"
)

const DEFAULT_OUTPUT_DIRECTORY := (
	"res://worlds/base_world/regions"
)


const DEFAULT_WORKER_RESERVE := 2
const MAX_AUTOMATIC_WORKERS := 16


const SurfaceFieldScript := preload(
	"res://src/builder/terrain/surface_height_field.gd"
)

const DepressionFieldScript := preload(
	"res://src/builder/hydrology/depression_resolved_height_field.gd"
)

const FlowMapScript := preload(
	"res://src/builder/hydrology/flow_direction_map.gd"
)

const AccumulationMapScript := preload(
	"res://src/builder/hydrology/flow_accumulation_map.gd"
)

const ChannelNetworkScript := preload(
	"res://src/builder/hydrology/channel_network.gd"
)

const FluvialSurfaceScript := preload(
	"res://src/builder/hydrology/fluvial_surface_height_field.gd"
)

const LakeBasinsScript := preload(
	"res://src/builder/hydrology/lake_basin_map.gd"
)

const LakeWaterScript := preload(
	"res://src/builder/hydrology/lake_water_model.gd"
)

const SurfaceWaterScript := preload(
	"res://src/builder/hydrology/surface_water_map.gd"
)

const OceanMaskScript := preload(
	"res://src/builder/hydrology/ocean_mask.gd"
)

const SurficialDepositsScript := preload(
	"res://src/builder/hydrology/surficial_deposit_map.gd"
)

const RegionFormatScript := preload(
	"res://src/shared/baked_region_format.gd"
)

const RegionWorkerPoolScript := preload(
	"res://src/builder/storage/region_bake_worker_pool.gd"
)


const BakedWorldConfigScript := preload(
	"res://src/shared/baked_world_config.gd"
)

const BakedVoxelLayoutScript := preload(
	"res://src/shared/baked_voxel_layout.gd"
)


var _worker_pool = null
var _bake_thread := Thread.new()

var _bake_started: bool = false
var _bake_start_usec: int = 0

var _output_directory: String = DEFAULT_OUTPUT_DIRECTORY
var _worker_limit: int = 1
var _island_tile_x: int = 0
var _island_tile_z: int = 0
var _force_rebuild: bool = false
var _quit_when_finished: bool = false
var _expected_generator_version: int = 0
var _expected_world_identity_seed: int = 0


func _configure_runtime_options() -> void:
	var processor_count: int = maxi(OS.get_processor_count(), 1)
	_worker_limit = clampi(
		processor_count - DEFAULT_WORKER_RESERVE,
		1,
		MAX_AUTOMATIC_WORKERS
	)

	_island_tile_x = _get_integer_option("island-x", 0)
	_island_tile_z = _get_integer_option("island-z", 0)
	_worker_limit = maxi(
		1,
		_get_integer_option("workers", _worker_limit)
	)
	_output_directory = AppConfig.get_command_line_value(
		"output",
		DEFAULT_OUTPUT_DIRECTORY
	)
	_force_rebuild = _get_boolean_option("rebuild", false)
	_quit_when_finished = _get_boolean_option(
		"quit-on-finish",
		OS.has_feature("headless")
	)


func _get_integer_option(key: String, default_value: int) -> int:
	var raw_value: String = AppConfig.get_command_line_value(
		key,
		str(default_value)
	)

	if not raw_value.is_valid_int():
		push_warning(
			"Ignoring invalid integer --%s=%s" % [key, raw_value]
		)
		return default_value

	return raw_value.to_int()


func _get_boolean_option(key: String, default_value: bool) -> bool:
	var fallback: String = "true" if default_value else "false"
	var raw_value: String = AppConfig.get_command_line_value(
		key,
		fallback
	).to_lower()

	return raw_value in ["1", "true", "yes", "on"]


func _ready() -> void:
	set_process(false)
	_configure_runtime_options()

	print("")
	print(
		"Island tile: ",
		Vector2i(_island_tile_x, _island_tile_z),
		" | meter offset: ",
		Vector2i(_island_tile_x * 10240, _island_tile_z * 10240)
	)
	print("")
	print("======================================")
	print(AppConfig.GAME_NAME)
	print("WORLD BUILDER")
	print("======================================")
	print("")
	var shared_data_start_usec: int = Time.get_ticks_usec()

	var world_definition: WorldDefinition = (
		_load_world_definition()
	)

	if world_definition == null:
		return

	_expected_generator_version = world_definition.generator_version
	_expected_world_identity_seed = (
		world_definition.get_world_identity_seed()
	)

	var stratigraphy: StratigraphyProfile = (
		_load_stratigraphy()
	)

	if stratigraphy == null:
		return

	if not _ensure_output_directory():
		return

	print("======================================")
	print("BUILDING SHARED WORLD DATA")
	print("======================================")
	print("")

	print(
		"Building surface height field..."
	)

	var surface_field := (
		SurfaceFieldScript.new()
	)

	surface_field.setup(
		world_definition,
		stratigraphy,
		8.0
	)

	print(
		"Resolving initial depressions..."
	)

	var initial_resolved := (
		DepressionFieldScript.new()
	)

	initial_resolved.setup(
		surface_field
	)

	print(
		"Building initial flow directions..."
	)

	var initial_flow := (
		FlowMapScript.new()
	)

	initial_flow.setup(
		initial_resolved
	)

	print(
		"Building initial flow accumulation..."
	)

	var initial_accumulation := (
		AccumulationMapScript.new()
	)

	initial_accumulation.setup(
		initial_flow,
		initial_resolved.get_spacing_meters()
	)

	print(
		"Building initial channel network..."
	)

	var initial_channel_network := (
		ChannelNetworkScript.new()
	)

	initial_channel_network.setup(
		initial_accumulation
	)

	print(
		"Building fluvial terrain..."
	)

	var fluvial_surface := (
		FluvialSurfaceScript.new()
	)

	fluvial_surface.setup(
		world_definition,
		stratigraphy,
		surface_field,
		initial_flow,
		initial_accumulation,
		initial_channel_network
	)

	print(
		"Resolving final depressions..."
	)

	var final_resolved := (
		DepressionFieldScript.new()
	)

	final_resolved.setup(
		fluvial_surface
	)

	print(
		"Building final flow directions..."
	)

	var final_flow := (
		FlowMapScript.new()
	)

	final_flow.setup(
		final_resolved
	)

	print(
		"Building final flow accumulation..."
	)

	var final_accumulation := (
		AccumulationMapScript.new()
	)

	final_accumulation.setup(
		final_flow,
		final_resolved.get_spacing_meters()
	)

	print(
		"Building final channel network..."
	)

	var final_channel_network := (
		ChannelNetworkScript.new()
	)

	final_channel_network.setup(
		final_accumulation
	)

	print(
		"Building lake basins..."
	)

	var lake_basins := (
		LakeBasinsScript.new()
	)

	lake_basins.setup(
		final_resolved
	)

	print(
		"Building lake water model..."
	)

	var lake_water := (
		LakeWaterScript.new()
	)

	lake_water.setup(
		lake_basins,
		final_accumulation
	)

	print(
		"Building surface water map..."
	)

	var ocean_mask := OceanMaskScript.new()
	ocean_mask.setup(world_definition, fluvial_surface)

	var surface_water := (
		SurfaceWaterScript.new()
	)

	surface_water.setup(
		fluvial_surface,
		final_channel_network,
		final_accumulation,
		lake_basins,
		lake_water,
		ocean_mask
	)

	print(
		"Building surficial deposits..."
	)

	var deposit_map := (
		SurficialDepositsScript.new()
	)

	deposit_map.setup(
		world_definition,
		fluvial_surface,
		surface_water,
		final_flow,
		final_accumulation,
		final_channel_network
	)

	print("")
	print(
		"Shared world data ready in ",
		snappedf(
			float(Time.get_ticks_usec() - shared_data_start_usec)
			/ 1000000.0,
			0.01
		),
		" seconds."
	)
	print("")

	var requested_region_jobs: Array[Vector2i] = (
		_build_region_jobs(
			world_definition
		)
	)

	if requested_region_jobs.is_empty():
		push_error(
			"No storage regions overlap the world."
		)
		return


	var region_jobs: Array[Vector2i] = []
	var completed_region_jobs: Array[Vector2i] = []
	var partial_region_jobs: Array[Vector2i] = []


	for region_coord in requested_region_jobs:
		if (
			not _force_rebuild
			and _is_finalized_region_file(
			region_coord
			)
		):
			completed_region_jobs.append(
				region_coord
			)
		else:
			region_jobs.append(
				region_coord
			)

			if _has_partial_region_files(
				region_coord
			):
				partial_region_jobs.append(
					region_coord
				)


	print("======================================")
	print("PRODUCTION REGION BAKE")
	print("======================================")
	print("")

	print(
		"World: ",
		snappedf(
			world_definition.get_max_x()
			- world_definition.get_min_x(),
			0.001
		),
		" x ",
		snappedf(
			world_definition.get_max_z()
			- world_definition.get_min_z(),
			0.001
		),
		" meters"
	)

	print(
		"Storage region size: ",
		RegionFormatScript
			.REGION_SIZE_LOD0_VOXELS,
		" meters"
	)

	print(
		"Requested regions: ",
		requested_region_jobs.size()
	)

	print(
		"Already finalized: ",
		completed_region_jobs.size()
	)

	print(
		"Regions to bake: ",
		region_jobs.size()
	)

	print(
		"Partial regions to rebuild: ",
		partial_region_jobs.size()
	)

	print(
		"Configured worker limit: ",
		_worker_limit
	)

	print(
		"Workers used this run: ",
		mini(
			_worker_limit,
			region_jobs.size()
		)
	)

	print(
		"Output: ",
		ProjectSettings.globalize_path(
			_output_directory
		)
	)

	print("")


	if not completed_region_jobs.is_empty():
		print(
			"Keeping completed region files:"
		)

		for region_coord in completed_region_jobs:
			print(
				"  COMPLETE ",
				region_coord,
				" -> ",
				RegionFormatScript
					.get_region_filename(
						region_coord
					)
			)

		print("")


	if not partial_region_jobs.is_empty():
		print(
			"Interrupted/partial regions detected."
		)

		print(
			"They will be rebuilt from scratch; completed regions are untouched."
		)

		for region_coord in partial_region_jobs:
			print(
				"  PARTIAL ",
				region_coord
			)

		print("")


	if region_jobs.is_empty():
		print("======================================")
		print("WORLD BAKE ALREADY COMPLETE")
		print("======================================")
		print("")
		print(
			"All ",
			requested_region_jobs.size(),
			" requested regions are finalized."
		)
		print("")
		if _quit_when_finished:
			get_tree().quit(0)
		return


	for job_index in range(
		region_jobs.size()
	):
		var region_coord: Vector2i = (
			region_jobs[
				job_index
			]
		)

		print(
			"Job ",
			job_index + 1,
			": ",
			region_coord,
			" -> ",
			RegionFormatScript
				.get_region_filename(
					region_coord
				)
		)

	print("")


	_worker_pool = (
		RegionWorkerPoolScript.new()
	)

	_bake_start_usec = (
		Time.get_ticks_usec()
	)


	var start_error: Error = (
		_bake_thread.start(
			_worker_pool.run.bind(
				region_jobs,
				_worker_limit,
				world_definition,
				stratigraphy,
				fluvial_surface,
				deposit_map,
				_output_directory
			)
		)
	)


	if start_error != OK:
		push_error(
			"Could not start background world bake thread. Error: %d"
			% int(
				start_error
			)
		)

		_worker_pool = null

		return


	_bake_started = true
	set_process(
		true
	)

	print(
		"World bake is running in the background."
	)

	print(
		"The Godot window should remain responsive."
	)

	print("")


func _process(
	_delta: float
) -> void:
	if not _bake_started:
		return

	if _bake_thread.is_alive():
		return


	var thread_result = (
		_bake_thread.wait_to_finish()
	)

	var bake_success: bool = bool(
		thread_result
	)

	_bake_started = false

	set_process(
		false
	)


	var bake_seconds: float = (
		float(
			Time.get_ticks_usec()
			- _bake_start_usec
		)
		/ 1000000.0
	)


	print("")
	print("======================================")
	print("WORLD BAKE COMPLETE")
	print("======================================")
	print("")

	print(
		"Elapsed seconds: ",
		snappedf(
			bake_seconds,
			0.01
		)
	)

	print(
		"Elapsed minutes: ",
		snappedf(
			bake_seconds
			/ 60.0,
			0.01
		)
	)

	print(
		"World bake succeeded: ",
		bake_success
	)

	print("")

	_worker_pool = null

	if _quit_when_finished:
		get_tree().quit(0 if bake_success else 1)


func _is_finalized_region_file(
	region_coord: Vector2i
) -> bool:
	var region_path: String = (
		RegionFormatScript.get_region_path(
			_output_directory,
			region_coord
		)
	)

	if not FileAccess.file_exists(
		region_path
	):
		return false


	var file: FileAccess = FileAccess.open(
		region_path,
		FileAccess.READ
	)

	if file == null:
		return false


	file.big_endian = false


	var file_length: int = (
		file.get_length()
	)

	if (
		file_length
		< RegionFormatScript.HEADER_SIZE_BYTES
	):
		file.close()
		return false


	file.seek(0)


	var magic: String = (
		file.get_buffer(8)
			.get_string_from_ascii()
	)

	var region_format_version: int = (
		file.get_32()
	)

	var header_size: int = (
		file.get_32()
	)

	var stored_region_x: int = (
		_decode_i32(
			file.get_32()
		)
	)

	var stored_region_z: int = (
		_decode_i32(
			file.get_32()
		)
	)

	var region_size: int = (
		file.get_32()
	)

	var block_size: int = (
		file.get_32()
	)

	var lod_count: int = (
		file.get_32()
	)

	var voxel_format_version: int = (
		file.get_32()
	)

	var index_offset: int = (
		file.get_64()
	)

	var index_count: int = (
		file.get_32()
	)

	var file_flags: int = (
		file.get_32()
	)

	var generator_version: int = file.get_32()
	var world_identity_seed: int = _decode_i32(file.get_32())


	var valid: bool = true


	if magic != RegionFormatScript.MAGIC:
		valid = false

	if (
		region_format_version
		!= RegionFormatScript.FORMAT_VERSION
	):
		valid = false

	if (
		header_size
		!= RegionFormatScript.HEADER_SIZE_BYTES
	):
		valid = false

	if (
		stored_region_x
		!= region_coord.x
		or stored_region_z
			!= region_coord.y
	):
		valid = false

	if (
		region_size
		!= RegionFormatScript
			.REGION_SIZE_LOD0_VOXELS
	):
		valid = false

	if (
		block_size
		!= BakedWorldConfigScript
			.DATA_BLOCK_SIZE
	):
		valid = false

	if (
		lod_count
		!= BakedWorldConfigScript
			.LOD_COUNT
	):
		valid = false

	if (
		voxel_format_version
		!= BakedVoxelLayoutScript
			.FORMAT_VERSION
	):
		valid = false

	if (
		file_flags
		!= RegionFormatScript.FILE_FLAG_NONE
	):
		valid = false

	if generator_version != _expected_generator_version:
		valid = false

	if world_identity_seed != _expected_world_identity_seed:
		valid = false


	var index_size: int = (
		index_count
		* RegionFormatScript
			.INDEX_ENTRY_SIZE_BYTES
	)


	if (
		index_offset
		< RegionFormatScript.HEADER_SIZE_BYTES
	):
		valid = false

	if (
		index_offset + index_size
		!= file_length
	):
		valid = false


	file.close()

	return valid


func _has_partial_region_files(
	region_coord: Vector2i
) -> bool:
	var region_path: String = (
		RegionFormatScript.get_region_path(
			_output_directory,
			region_coord
		)
	)

	if FileAccess.file_exists(
		region_path + ".index.tmp"
	):
		return true

	if FileAccess.file_exists(region_path + ".partial"):
		return true

	if FileAccess.file_exists(region_path + ".partial.index.tmp"):
		return true

	return (
		FileAccess.file_exists(region_path)
		and not _is_finalized_region_file(region_coord)
	)


static func _decode_i32(
	value: int
) -> int:
	if value >= 0x80000000:
		return (
			value
			- 0x100000000
		)

	return value


func _load_world_definition() -> WorldDefinition:
	if not ResourceLoader.exists(
		WORLD_DEFINITION_PATH
	):
		push_error(
			"World definition not found: %s"
			% WORLD_DEFINITION_PATH
		)
		return null

	var resource: Resource = (
		ResourceLoader.load(
			WORLD_DEFINITION_PATH
		)
	)

	if resource == null:
		push_error(
			"Failed to load world definition."
		)
		return null

	if not resource is WorldDefinition:
		push_error(
			"Resource is not a WorldDefinition."
		)
		return null

	var duplicate_resource: Resource = resource.duplicate(true)
	var world_definition: WorldDefinition = (
		duplicate_resource as WorldDefinition
	)

	if world_definition == null:
		push_error("Could not duplicate the world definition.")
		return null

	world_definition.configure_island_tile(
		_island_tile_x,
		_island_tile_z
	)

	if not world_definition.is_valid():
		push_error(
			"World definition contains invalid settings."
		)
		return null

	var expected_tile_size: int = (
		RegionFormatScript.REGION_SIZE_LOD0_VOXELS * 10
	)

	if (
		world_definition.size_x_meters != expected_tile_size
		or world_definition.size_z_meters != expected_tile_size
	):
		push_error(
			"Island tiles must be %d x %d meters (10 x 10 regions)."
			% [expected_tile_size, expected_tile_size]
		)
		return null

	return world_definition


func _load_stratigraphy() -> StratigraphyProfile:
	if not ResourceLoader.exists(
		STRATIGRAPHY_PATH
	):
		push_error(
			"Stratigraphy profile not found: %s"
			% STRATIGRAPHY_PATH
		)
		return null

	var resource: Resource = (
		ResourceLoader.load(
			STRATIGRAPHY_PATH
		)
	)

	if resource == null:
		push_error(
			"Failed to load stratigraphy."
		)
		return null

	if not resource is StratigraphyProfile:
		push_error(
			"Resource is not a StratigraphyProfile."
		)
		return null

	var stratigraphy: StratigraphyProfile = (
		resource as StratigraphyProfile
	)

	if not stratigraphy.is_valid():
		push_error(
			"Stratigraphy contains invalid settings."
		)
		return null

	return stratigraphy


func _ensure_output_directory() -> bool:
	var absolute_directory: String = (
		ProjectSettings.globalize_path(
			_output_directory
		)
	)

	var directory_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			absolute_directory
		)
	)

	if (
		directory_error != OK
		and directory_error
			!= ERR_ALREADY_EXISTS
	):
		push_error(
			(
				"Could not create baked-region "
				+ "output directory: %s"
			)
			% _output_directory
		)

		return false

	return true


func _build_region_jobs(
	world_definition: WorldDefinition
) -> Array[Vector2i]:
	var region_jobs: Array[Vector2i] = []

	var voxel_size: float = (
		world_definition.voxel_size_meters
	)

	if voxel_size <= 0.0:
		return region_jobs

	var world_min_voxel_x: int = floori(
		world_definition.get_min_x()
		/ voxel_size
	)

	var world_min_voxel_z: int = floori(
		world_definition.get_min_z()
		/ voxel_size
	)

	var world_max_voxel_x_exclusive: int = ceili(
		world_definition.get_max_x()
		/ voxel_size
	)

	var world_max_voxel_z_exclusive: int = ceili(
		world_definition.get_max_z()
		/ voxel_size
	)

	var minimum_region: Vector2i = (
		RegionFormatScript
			.get_region_coord_from_voxel(
				world_min_voxel_x,
				world_min_voxel_z
			)
	)

	var maximum_region: Vector2i = (
		RegionFormatScript
			.get_region_coord_from_voxel(
				world_max_voxel_x_exclusive - 1,
				world_max_voxel_z_exclusive - 1
			)
	)

	for region_z in range(
		minimum_region.y,
		maximum_region.y + 1
	):
		for region_x in range(
			minimum_region.x,
			maximum_region.x + 1
		):
			region_jobs.append(
				Vector2i(
					region_x,
					region_z
				)
			)

	return region_jobs
