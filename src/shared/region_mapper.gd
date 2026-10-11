class_name RegionMapper
extends RefCounted


const RegionManifestScript := preload(
	"res://src/shared/region_manifest.gd"
)

const RegionFormatScript := preload(
	"res://src/shared/baked_region_format.gd"
)


var _catalog = null

var _minimum_source_region := Vector2i.ZERO
var _maximum_source_region := Vector2i.ZERO

var _is_ready: bool = false


# ==================================================
# CONFIGURATION
# ==================================================

func configure(
	catalog,
	require_complete_rectangle: bool = true
) -> bool:
	reset()

	if catalog == null:
		push_error(
			"RegionMapper received a null RegionCatalog."
		)

		return false


	if not catalog.is_ready():
		push_error(
			"RegionCatalog is not ready."
		)

		return false


	_catalog = catalog

	_minimum_source_region = (
		catalog.get_minimum_region()
	)

	_maximum_source_region = (
		catalog.get_maximum_region()
	)


	var bounds_valid: bool = (
		_validate_complete_rectangle()
		if require_complete_rectangle
		else _find_complete_bounds()
	)

	if not bounds_valid:
		reset()
		return false


	_is_ready = true


	print(
		"RegionMapper: usable source bounds ",
		_minimum_source_region,
		" -> ",
		_maximum_source_region,
		" | size ",
		get_source_width(),
		" x ",
		get_source_depth()
	)


	return true


# ==================================================
# REGION MAPPING
# ==================================================

func map_logical_region(
	logical_region: Vector2i
) -> Dictionary:
	if not _is_ready:
		push_error(
			"RegionMapper is not ready."
		)

		return {}


	var source_region := Vector2i(
		_wrap_axis(
			logical_region.x,
			_minimum_source_region.x,
			_maximum_source_region.x
		),

		_wrap_axis(
			logical_region.y,
			_minimum_source_region.y,
			_maximum_source_region.y
		)
	)


	if not _catalog.has_region(
		source_region
	):
		push_error(
			(
				"Logical region %s mapped to missing "
				+ "source region %s."
			)
			% [
				str(logical_region),
				str(source_region)
			]
		)

		return {}


	var revision: String = (
		_catalog.get_region_revision(
			source_region
		)
	)


	return RegionManifestScript.make_entry(
		logical_region,
		source_region,
		revision
	)


# ==================================================
# BLOCK MAPPING
# ==================================================

func map_logical_block(
	logical_block_position: Vector3i,
	lod_index: int
) -> Dictionary:
	if not _is_ready:
		push_error(
			"RegionMapper is not ready."
		)

		return {}


	if not RegionFormatScript.is_valid_lod(
		lod_index
	):
		push_error(
			"Invalid LOD index: %d"
			% lod_index
		)

		return {}


	# Which temporary/logical region contains this
	# requested voxel-data block?

	var logical_region: Vector2i = (
		RegionFormatScript
			.get_region_coord_from_block(
				logical_block_position,
				lod_index
			)
	)


	# Find its canonical source region.

	var region_mapping: Dictionary = (
		map_logical_region(
			logical_region
		)
	)


	if region_mapping.is_empty():
		return {}


	var source_region: Vector2i = (
		region_mapping[
			RegionManifestScript.KEY_SOURCE_REGION
		]
	)


	# Find the block's X/Z position within its region.
	#
	# Y does not wrap.

	var local_block_position: Vector3i = (
		RegionFormatScript
			.get_local_block_position(
				logical_block_position,
				lod_index
			)
	)


	var blocks_per_axis: int = (
		RegionFormatScript
			.get_blocks_per_region_axis(
				lod_index
			)
	)


	var source_block_position := Vector3i(
		source_region.x
			* blocks_per_axis
			+ local_block_position.x,

		logical_block_position.y,

		source_region.y
			* blocks_per_axis
			+ local_block_position.z
	)


	return {
		"logical_block_position":
			logical_block_position,

		"source_block_position":
			source_block_position,

		"logical_region":
			logical_region,

		"source_region":
			source_region,

		"wrapped_x":
			region_mapping[
				RegionManifestScript.KEY_WRAPPED_X
			],

		"wrapped_z":
			region_mapping[
				RegionManifestScript.KEY_WRAPPED_Z
			],

		"source_revision":
			region_mapping[
				RegionManifestScript.KEY_SOURCE_REVISION
			],

		"lod":
			lod_index
	}


# ==================================================
# MANIFEST
# ==================================================

func get_manifest(
	current_logical_region: Vector2i,
	radius: int = 1
) -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []


	if not _is_ready:
		push_error(
			"RegionMapper is not ready."
		)

		return manifest


	radius = maxi(
		radius,
		0
	)


	for offset_z in range(
		-radius,
		radius + 1
	):
		for offset_x in range(
			-radius,
			radius + 1
		):
			var logical_region := (
				current_logical_region
				+ Vector2i(
					offset_x,
					offset_z
				)
			)


			var entry: Dictionary = (
				map_logical_region(
					logical_region
				)
			)


			if not entry.is_empty():
				manifest.append(
					entry
				)


	return manifest


# ==================================================
# COMPLETE SOURCE BOUNDS
# ==================================================

func _validate_complete_rectangle() -> bool:
	for region_z in range(
		_minimum_source_region.y,
		_maximum_source_region.y + 1
	):
		for region_x in range(
			_minimum_source_region.x,
			_maximum_source_region.x + 1
		):
			var source_region := Vector2i(region_x, region_z)

			if not _catalog.has_region(source_region):
				push_error(
					"Incomplete world rectangle: missing source region %s."
					% str(source_region)
				)
				return false

	var expected_count: int = (
		(_maximum_source_region.x - _minimum_source_region.x + 1)
		* (_maximum_source_region.y - _minimum_source_region.y + 1)
	)

	if _catalog.get_region_count() != expected_count:
		push_error(
			"Region count does not match the discovered rectangular bounds."
		)
		return false

	return true

func _find_complete_bounds() -> bool:
	while true:
		if not _is_column_complete(
			_minimum_source_region.x
		):
			if _minimum_source_region.x >= 0:
				return _bounds_error()

			_minimum_source_region.x += 1
			continue


		if not _is_column_complete(
			_maximum_source_region.x
		):
			if _maximum_source_region.x <= 0:
				return _bounds_error()

			_maximum_source_region.x -= 1
			continue


		if not _is_row_complete(
			_minimum_source_region.y
		):
			if _minimum_source_region.y >= 0:
				return _bounds_error()

			_minimum_source_region.y += 1
			continue


		if not _is_row_complete(
			_maximum_source_region.y
		):
			if _maximum_source_region.y <= 0:
				return _bounds_error()

			_maximum_source_region.y -= 1
			continue


		break


	for region_z in range(
		_minimum_source_region.y,
		_maximum_source_region.y + 1
	):
		for region_x in range(
			_minimum_source_region.x,
			_maximum_source_region.x + 1
		):
			var source_region := Vector2i(
				region_x,
				region_z
			)


			if not _catalog.has_region(
				source_region
			):
				push_error(
					(
						"RegionCatalog contains an internal "
						+ "hole at source region %s."
					)
					% str(source_region)
				)

				return false


	return true


func _is_column_complete(
	region_x: int
) -> bool:
	for region_z in range(
		_minimum_source_region.y,
		_maximum_source_region.y + 1
	):
		if not _catalog.has_region(
			Vector2i(
				region_x,
				region_z
			)
		):
			return false


	return true


func _is_row_complete(
	region_z: int
) -> bool:
	for region_x in range(
		_minimum_source_region.x,
		_maximum_source_region.x + 1
	):
		if not _catalog.has_region(
			Vector2i(
				region_x,
				region_z
			)
		):
			return false


	return true


func _bounds_error() -> bool:
	push_error(
		(
			"Could not establish complete usable region "
			+ "bounds containing source region (0, 0)."
		)
	)

	return false


# ==================================================
# WRAPPING
# ==================================================

static func _wrap_axis(
	value: int,
	minimum: int,
	maximum: int
) -> int:
	var span: int = (
		maximum
		- minimum
		+ 1
	)


	if span <= 0:
		return minimum


	var relative: int = (
		value
		- minimum
	)


	var wrapped: int = (
		(
			relative % span
			+ span
		)
		% span
	)


	return (
		minimum
		+ wrapped
	)


# ==================================================
# INFORMATION
# ==================================================

func is_ready() -> bool:
	return _is_ready


func get_minimum_source_region() -> Vector2i:
	return _minimum_source_region


func get_maximum_source_region() -> Vector2i:
	return _maximum_source_region


func get_source_width() -> int:
	if not _is_ready:
		return 0

	return (
		_maximum_source_region.x
		- _minimum_source_region.x
		+ 1
	)


func get_source_depth() -> int:
	if not _is_ready:
		return 0

	return (
		_maximum_source_region.y
		- _minimum_source_region.y
		+ 1
	)


func reset() -> void:
	_catalog = null

	_minimum_source_region = Vector2i.ZERO
	_maximum_source_region = Vector2i.ZERO

	_is_ready = false
