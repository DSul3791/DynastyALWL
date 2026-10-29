class_name RegionBakeJob
extends RefCounted


const GeologySamplerScript := preload(
	"res://src/builder/geology/deformed_geology_sampler.gd"
)

const MineralSamplerScript := preload(
	"res://src/builder/geology/mineral_deposit_sampler.gd"
)

const FinalTerrainSamplerScript := preload(
	"res://src/builder/terrain/final_terrain_sampler.gd"
)

const BakedVoxelSamplerScript := preload(
	"res://src/builder/terrain/baked_voxel_sampler.gd"
)

const WorldBakePlannerScript := preload(
	"res://src/builder/terrain/world_bake_planner.gd"
)

const WorldBlockBakerScript := preload(
	"res://src/builder/terrain/world_block_baker.gd"
)


var _world_definition = null
var _stratigraphy = null

var _terrain_field = null
var _deposit_map = null

var _output_directory: String = ""

var _progress_callback: Callable = Callable()


func setup(
	world_definition,
	stratigraphy,
	terrain_field,
	deposit_map,
	output_directory: String,
	progress_callback: Callable
) -> void:
	_world_definition = world_definition
	_stratigraphy = stratigraphy

	_terrain_field = terrain_field
	_deposit_map = deposit_map

	_output_directory = output_directory

	_progress_callback = progress_callback


func bake_region(
	region_coord: Vector2i
) -> bool:
	if _world_definition == null:
		push_error(
			"RegionBakeJob has no world definition."
		)
		return false

	if _stratigraphy == null:
		push_error(
			"RegionBakeJob has no stratigraphy."
		)
		return false

	if _terrain_field == null:
		push_error(
			"RegionBakeJob has no terrain field."
		)
		return false

	if _deposit_map == null:
		push_error(
			"RegionBakeJob has no deposit map."
		)
		return false

	if _output_directory.is_empty():
		push_error(
			"RegionBakeJob has no output directory."
		)
		return false


	# ==================================================
	# WORKER-LOCAL GEOLOGY
	# ==================================================

	var geology_sampler := (
		GeologySamplerScript.new()
	)

	geology_sampler.setup(
		_world_definition,
		_stratigraphy
	)


	# ==================================================
	# WORKER-LOCAL FINAL TERRAIN SAMPLER
	# ==================================================

	var final_terrain_sampler := (
		FinalTerrainSamplerScript.new()
	)

	final_terrain_sampler.setup(
		_world_definition,
		geology_sampler,
		_terrain_field,
		_deposit_map
	)


	# ==================================================
	# WORKER-LOCAL MINERALIZATION
	# ==================================================

	var mineral_sampler := (
		MineralSamplerScript.new()
	)

	mineral_sampler.setup(
		_world_definition,
		_stratigraphy
	)


	# ==================================================
	# WORKER-LOCAL VOXEL SAMPLER
	# ==================================================

	var baked_sampler := (
		BakedVoxelSamplerScript.new()
	)

	baked_sampler.setup(
		_world_definition,
		final_terrain_sampler,
		mineral_sampler
	)


	# ==================================================
	# WORKER-LOCAL BAKE PLANNER
	# ==================================================

	var planner := (
		WorldBakePlannerScript.new()
	)

	planner.setup(
		_world_definition,
		_terrain_field,
		geology_sampler,
		_stratigraphy
	)


	# ==================================================
	# WORKER-LOCAL BLOCK BAKER
	# ==================================================

	var baker := (
		WorldBlockBakerScript.new()
	)

	baker.setup(
		baked_sampler,
		planner,
		true,
		_world_definition
	)

	baker.set_progress_callback(
		_progress_callback
	)

	baker.set_verbose(
		false
	)

	return baker.bake_region(
		_output_directory,
		region_coord
	)
