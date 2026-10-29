class_name ServerWorldRegions
extends RefCounted


const RegionCatalogScript := preload(
	"res://src/shared/region_catalog.gd"
)

const RegionMapperScript := preload(
	"res://src/shared/region_mapper.gd"
)

const RegionFormatScript := preload(
	"res://src/shared/baked_region_format.gd"
)


var _catalog = null
var _mapper = null
var _region_directory: String = ""
var _is_ready: bool = false


func initialize(world_path: String) -> bool:
	reset()
	_region_directory = world_path.path_join("regions")

	_catalog = RegionCatalogScript.new()
	if not _catalog.scan(_region_directory):
		push_error("Server rejected the baked region directory.")
		reset()
		return false

	if _catalog.get_generator_version() != AppConfig.GENERATOR_VERSION:
		push_error(
			"World generator version %d is incompatible with server version %d."
			% [
				_catalog.get_generator_version(),
				AppConfig.GENERATOR_VERSION
			]
		)
		reset()
		return false

	_mapper = RegionMapperScript.new()
	if not _mapper.configure(_catalog, true):
		push_error(
			"Server world must be one complete rectangular region set."
		)
		reset()
		return false

	_is_ready = true
	print(
		"Authoritative world rectangle: ",
		_mapper.get_minimum_source_region(),
		" -> ",
		_mapper.get_maximum_source_region(),
		" (",
		_mapper.get_source_width(),
		" x ",
		_mapper.get_source_depth(),
		")"
	)
	return true


func map_logical_region(logical_region: Vector2i) -> Dictionary:
	if not _is_ready:
		return {}
	return _mapper.map_logical_region(logical_region)


func get_manifest(
	current_logical_region: Vector2i,
	radius: int = 1
) -> Array[Dictionary]:
	if not _is_ready:
		return []
	return _mapper.get_manifest(current_logical_region, radius)


func get_canonical_position(
	world_x: float,
	world_y: float,
	world_z: float
) -> Dictionary:
	if not _is_ready:
		return {}

	var region_size: float = float(
		RegionFormatScript.REGION_SIZE_LOD0_VOXELS
	)
	var logical_region := Vector2i(
		floori(world_x / region_size),
		floori(world_z / region_size)
	)
	var mapping: Dictionary = _mapper.map_logical_region(logical_region)

	if mapping.is_empty():
		return {}

	var source_region: Vector2i = mapping["source_region"]
	var local_x: float = fposmod(world_x, region_size)
	var local_z: float = fposmod(world_z, region_size)

	# Persistent entities should store this source region and local
	# position. Their identity then survives later wrap-bound changes.
	return {
		"source_region": source_region,
		"local_position": Vector3(local_x, world_y, local_z)
	}


func get_minimum_region() -> Vector2i:
	return (
		_mapper.get_minimum_source_region()
		if _is_ready
		else Vector2i.ZERO
	)


func get_maximum_region() -> Vector2i:
	return (
		_mapper.get_maximum_source_region()
		if _is_ready
		else Vector2i.ZERO
	)


func get_generator_version() -> int:
	return _catalog.get_generator_version() if _is_ready else 0


func get_world_identity_seed() -> int:
	return _catalog.get_world_identity_seed() if _is_ready else 0


func is_ready() -> bool:
	return _is_ready


func reset() -> void:
	_catalog = null
	_mapper = null
	_region_directory = ""
	_is_ready = false
