class_name LocalBakedBlockStore
extends RefCounted


const RegionReaderScript = preload(
	"res://src/shared/baked_region_reader.gd"
)

const BakedBlockCodecScript = preload(
	"res://src/shared/baked_block_codec.gd"
)

const ImplicitBlockFactoryScript = preload(
	"res://src/shared/baked_implicit_block_factory.gd"
)

const BakedWorldConfigScript = preload(
	"res://src/shared/baked_world_config.gd"
)


const COLUMN_SEARCH_RADIUS := 8
const COLUMN_MIN_EVIDENCE := 4


var _region_provider = null


# source_region -> {
#     "reader": BakedRegionReader,
#     "mutex": Mutex
# }
var _reader_bundles: Dictionary = {}

var _reader_bundles_mutex := Mutex.new()


# Key:
#     "lod:block_x:block_z"
#
# Value:
#     first block Y classified as air
var _column_air_start_cache: Dictionary = {}

var _column_air_start_cache_mutex := Mutex.new()


var _is_ready: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func initialize(
	region_provider
) -> bool:
	close()


	if region_provider == null:
		push_error(
			"LocalBakedBlockStore received a null region provider."
		)

		return false


	if not region_provider.is_ready():
		push_error(
			"LocalBakedBlockStore received a region provider that is not ready."
		)

		return false


	_region_provider = region_provider
	_is_ready = true


	print(
		"LocalBakedBlockStore ready."
	)


	return true


# ==================================================
# READ LOGICAL BLOCK
# ==================================================

func read_block(
	logical_block_position: Vector3i,
	lod_index: int
) -> VoxelBuffer:
	if not _is_ready:
		push_error(
			"LocalBakedBlockStore is not ready."
		)

		return null


	var mapping: Dictionary = (
		_region_provider.get_block_mapping(
			logical_block_position,
			lod_index
		)
	)


	if mapping.is_empty():
		return null


	var source_region: Vector2i = (
		mapping["source_region"]
	)


	var source_block_position: Vector3i = (
		mapping["source_block_position"]
	)


	var bundle: Dictionary = (
		_get_or_open_reader_bundle(
			source_region
		)
	)


	if bundle.is_empty():
		return null


	var reader = bundle["reader"]
	var mutex: Mutex = bundle["mutex"]


	# --------------------------------------------------
	# STORED BLOCK
	# --------------------------------------------------

	mutex.lock()


	var is_stored: bool = (
		reader.has_block(
			lod_index,
			source_block_position
		)
	)


	var payload := PackedByteArray()


	if is_stored:
		payload = reader.read_block(
			lod_index,
			source_block_position
		)


	mutex.unlock()


	if is_stored:
		if payload.is_empty():
			push_error(
				(
					"Stored block returned an empty payload. "
					+ "LOD%d block %s"
				)
				% [
					lod_index,
					str(
						source_block_position
					)
				]
			)

			return null


		return (
			BakedBlockCodecScript.decode_buffer(
				payload
			)
		)


	# --------------------------------------------------
	# OMITTED BLOCK
	#
	# Resolve one air boundary for this entire X/Z
	# column and use it consistently for every missing
	# block in the column.
	# --------------------------------------------------

	var air_start_block_y: int = (
		_resolve_column_air_start(
			lod_index,
			source_block_position.x,
			source_block_position.z
		)
	)


	if (
		source_block_position.y
		>= air_start_block_y
	):
		return (
			ImplicitBlockFactoryScript.create_air(
				lod_index
			)
		)


	return (
		ImplicitBlockFactoryScript
			.create_deep_granite(
				lod_index
			)
	)


# ==================================================
# COLUMN AIR BOUNDARY
# ==================================================

func _resolve_column_air_start(
	lod_index: int,
	world_block_x: int,
	world_block_z: int
) -> int:
	var cache_key: String = (
		_make_column_key(
			lod_index,
			world_block_x,
			world_block_z
		)
	)


	_column_air_start_cache_mutex.lock()


	if _column_air_start_cache.has(
		cache_key
	):
		var cached_value: int = int(
			_column_air_start_cache[
				cache_key
			]
		)


		_column_air_start_cache_mutex.unlock()


		return cached_value


	_column_air_start_cache_mutex.unlock()


	# --------------------------------------------------
	# 1. EXACT BOUNDARY FROM THIS COLUMN
	# --------------------------------------------------

	var direct_air_start: Variant = (
		_try_get_known_column_air_start(
			lod_index,
			world_block_x,
			world_block_z
		)
	)


	if direct_air_start != null:
		var direct_value: int = int(
			direct_air_start
		)


		_store_column_air_start_cache(
			cache_key,
			direct_value
		)


		return direct_value


	# --------------------------------------------------
	# 2. NEAREST SAME-LOD COLUMNS WITH KNOWN BOUNDARIES
	# --------------------------------------------------

	var evidence: Array[int] = []


	for radius in range(
		1,
		COLUMN_SEARCH_RADIUS + 1
	):
		for dz in range(
			-radius,
			radius + 1
		):
			for dx in range(
				-radius,
				radius + 1
			):
				if (
					dx == 0
					and dz == 0
				):
					continue


				# Search only this ring's perimeter.
				if (
					abs(dx) != radius
					and abs(dz) != radius
				):
					continue


				var neighbor_air_start: Variant = (
					_try_get_known_column_air_start(
						lod_index,
						world_block_x + dx,
						world_block_z + dz
					)
				)


				if neighbor_air_start != null:
					evidence.append(
						int(
							neighbor_air_start
						)
					)


		if (
			evidence.size()
			>= COLUMN_MIN_EVIDENCE
		):
			break


	if not evidence.is_empty():
		evidence.sort()


		var median_air_start: int = (
			evidence[
				evidence.size() >> 1
			]
		)


		_store_column_air_start_cache(
			cache_key,
			median_air_start
		)


		return median_air_start


	# --------------------------------------------------
	# 3. COARSER LOD FALLBACK
	# --------------------------------------------------

	if (
		lod_index + 1
		< BakedWorldConfigScript.LOD_COUNT
	):
		var parent_air_start: int = (
			_resolve_column_air_start(
				lod_index + 1,
				world_block_x >> 1,
				world_block_z >> 1
			)
		)


		var derived_air_start: int = (
			parent_air_start << 1
		)


		_store_column_air_start_cache(
			cache_key,
			derived_air_start
		)


		return derived_air_start


	# --------------------------------------------------
	# 4. FINAL FALLBACK
	# --------------------------------------------------

	_store_column_air_start_cache(
		cache_key,
		0
	)


	return 0


# ==================================================
# KNOWN COLUMN LOOKUP
# ==================================================

func _try_get_known_column_air_start(
	lod_index: int,
	world_block_x: int,
	world_block_z: int
) -> Variant:
	var mapping: Dictionary = (
		_region_provider.get_block_mapping(
			Vector3i(
				world_block_x,
				0,
				world_block_z
			),
			lod_index
		)
	)


	if mapping.is_empty():
		return null


	var source_region: Vector2i = (
		mapping["source_region"]
	)


	var source_block_position: Vector3i = (
		mapping["source_block_position"]
	)


	var bundle: Dictionary = (
		_get_or_open_reader_bundle(
			source_region
		)
	)


	if bundle.is_empty():
		return null


	var reader = bundle["reader"]
	var mutex: Mutex = bundle["mutex"]


	mutex.lock()


	var air_start_y: int = (
		reader.get_known_air_start_block_y(
			lod_index,
			source_block_position.x,
			source_block_position.z
		)
	)


	mutex.unlock()


	if (
		air_start_y
		== RegionReaderScript.AIR_START_UNKNOWN
	):
		return null


	return air_start_y


# ==================================================
# COLUMN CACHE
# ==================================================

func _store_column_air_start_cache(
	cache_key: String,
	air_start_y: int
) -> void:
	_column_air_start_cache_mutex.lock()


	_column_air_start_cache[
		cache_key
	] = air_start_y


	_column_air_start_cache_mutex.unlock()


# ==================================================
# REGION READERS
# ==================================================

func _get_or_open_reader_bundle(
	source_region: Vector2i
) -> Dictionary:
	_reader_bundles_mutex.lock()


	if _reader_bundles.has(
		source_region
	):
		var existing_bundle: Dictionary = (
			_reader_bundles[
				source_region
			]
		)


		_reader_bundles_mutex.unlock()


		return existing_bundle


	var region_path: String = (
		_region_provider.get_source_region_path(
			source_region
		)
	)


	if region_path.is_empty():
		_reader_bundles_mutex.unlock()


		push_error(
			(
				"No local baked region path exists for "
				+ "source region %s."
			)
			% str(
				source_region
			)
		)


		return {}


	var reader = (
		RegionReaderScript.new()
	)


	if not reader.open_region(
		region_path
	):
		_reader_bundles_mutex.unlock()


		push_error(
			(
				"Could not open baked source region %s at %s."
			)
			% [
				str(
					source_region
				),
				region_path
			]
		)


		return {}


	var bundle: Dictionary = {
		"reader": reader,
		"mutex": Mutex.new()
	}


	_reader_bundles[
		source_region
	] = bundle


	_reader_bundles_mutex.unlock()


	return bundle


# ==================================================
# INFORMATION
# ==================================================

func is_ready() -> bool:
	return _is_ready


func get_open_reader_count() -> int:
	_reader_bundles_mutex.lock()


	var count: int = (
		_reader_bundles.size()
	)


	_reader_bundles_mutex.unlock()


	return count


# ==================================================
# CLOSE
# ==================================================

func close() -> void:
	_reader_bundles_mutex.lock()


	for bundle_variant in _reader_bundles.values():
		var bundle: Dictionary = (
			bundle_variant
		)


		var reader = (
			bundle.get(
				"reader",
				null
			)
		)


		if reader != null:
			reader.close()


	_reader_bundles.clear()


	_reader_bundles_mutex.unlock()


	_column_air_start_cache_mutex.lock()

	_column_air_start_cache.clear()

	_column_air_start_cache_mutex.unlock()


	_region_provider = null
	_is_ready = false


# ==================================================
# KEYS
# ==================================================

static func _make_column_key(
	lod_index: int,
	block_x: int,
	block_z: int
) -> String:
	return (
		"%d:%d:%d"
		% [
			lod_index,
			block_x,
			block_z
		]
	)
