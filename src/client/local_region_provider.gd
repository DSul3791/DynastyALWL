class_name LocalRegionProvider extends BakedWorldInit


const RegionCatalogScript := preload(
	"res://src/shared/region_catalog.gd"
)

const RegionMapperScript := preload(
	"res://src/shared/region_mapper.gd"
)


var _catalog: Object = null
var _mapper: Object = null

var _region_directory: String = ""
var _is_ready: bool = false


func set_dependency(world_path: String = AppConfig.DEFAULT_WORLD_PATH) -> void:
	_region_directory = world_path.path_join("regions")

	_catalog = RegionCatalogScript.new()

	if not _catalog.scan(_region_directory):
		push_error(
			"LocalRegionProvider could not scan baked regions."
		)

		reset()
		return false


	_mapper = RegionMapperScript.new()

	if not _mapper.configure(_catalog):
		push_error(
			"LocalRegionProvider could not configure region mapper."
		)

		reset()
		return false


	_is_ready = true


	print(
		"LocalRegionProvider ready. ",
		"Source regions: ",
		_catalog.get_region_count(),
		" | Bounds: ",
		_mapper.get_minimum_source_region(),
		" -> ",
		_mapper.get_maximum_source_region()
	)


	return true


func initialize(
	world_path: String = AppConfig.DEFAULT_WORLD_PATH
) -> bool:
	return super.initialize(self, "region provider", false)


# ==================================================
# REGION MANIFEST
# ==================================================

func get_region_manifest(
	current_logical_region: Vector2i,
	radius: int = 1
) -> Array[Dictionary]:
	if not _is_ready:
		push_error(
			"LocalRegionProvider is not ready."
		)

		return []


	return _mapper.get_manifest(
		current_logical_region,
		radius
	)


func get_region_mapping(
	logical_region: Vector2i
) -> Dictionary:
	if not _is_ready:
		push_error(
			"LocalRegionProvider is not ready."
		)

		return {}


	return _mapper.map_logical_region(
		logical_region
	)


# ==================================================
# BLOCK MAPPING
# ==================================================

func get_block_mapping(
	logical_block_position: Vector3i,
	lod_index: int
) -> Dictionary:
	if not _is_ready:
		push_error(
			"LocalRegionProvider is not ready."
		)

		return {}


	return _mapper.map_logical_block(
		logical_block_position,
		lod_index
	)


# ==================================================
# LOCAL SOURCE ACCESS
# ==================================================

func get_source_region_path(
	source_region: Vector2i
) -> String:
	if not _is_ready:
		return ""


	return _catalog.get_region_path(
		source_region
	)


func get_source_region_revision(
	source_region: Vector2i
) -> String:
	if not _is_ready:
		return ""


	return _catalog.get_region_revision(
		source_region
	)


func has_source_region(
	source_region: Vector2i
) -> bool:
	if not _is_ready:
		return false


	return _catalog.has_region(
		source_region
	)


# ==================================================
# INFORMATION
# ==================================================

func is_ready() -> bool:
	return _is_ready


func get_source_region_count() -> int:
	if not _is_ready:
		return 0

	return _catalog.get_region_count()


func get_minimum_source_region() -> Vector2i:
	if not _is_ready:
		return Vector2i.ZERO

	return _mapper.get_minimum_source_region()


func get_maximum_source_region() -> Vector2i:
	if not _is_ready:
		return Vector2i.ZERO

	return _mapper.get_maximum_source_region()


func get_region_directory() -> String:
	return _region_directory


# ==================================================
# RESET
# ==================================================

func reset() -> void:
	super.reset()

	_catalog = null
	_mapper = null

	_region_directory = ""
