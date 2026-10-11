class_name RegionManifest
extends RefCounted


const KEY_LOGICAL_REGION := "logical_region"
const KEY_SOURCE_REGION := "source_region"

const KEY_WRAPPED_X := "wrapped_x"
const KEY_WRAPPED_Z := "wrapped_z"

const KEY_SOURCE_REVISION := "source_revision"


static func make_entry(
	logical_region: Vector2i,
	source_region: Vector2i,
	source_revision: String
) -> Dictionary:
	return {
		KEY_LOGICAL_REGION: logical_region,
		KEY_SOURCE_REGION: source_region,

		KEY_WRAPPED_X:
			logical_region.x != source_region.x,

		KEY_WRAPPED_Z:
			logical_region.y != source_region.y,

		KEY_SOURCE_REVISION:
			source_revision
	}


static func is_valid_entry(
	entry: Dictionary
) -> bool:
	if not entry.has(KEY_LOGICAL_REGION):
		return false

	if not entry.has(KEY_SOURCE_REGION):
		return false

	if not entry.has(KEY_WRAPPED_X):
		return false

	if not entry.has(KEY_WRAPPED_Z):
		return false

	if not entry.has(KEY_SOURCE_REVISION):
		return false


	if not (
		entry[KEY_LOGICAL_REGION]
		is Vector2i
	):
		return false

	if not (
		entry[KEY_SOURCE_REGION]
		is Vector2i
	):
		return false

	if not (
		entry[KEY_WRAPPED_X]
		is bool
	):
		return false

	if not (
		entry[KEY_WRAPPED_Z]
		is bool
	):
		return false

	if not (
		entry[KEY_SOURCE_REVISION]
		is String
	):
		return false


	return true


static func get_logical_region(
	entry: Dictionary
) -> Vector2i:
	return entry.get(
		KEY_LOGICAL_REGION,
		Vector2i.ZERO
	)


static func get_source_region(
	entry: Dictionary
) -> Vector2i:
	return entry.get(
		KEY_SOURCE_REGION,
		Vector2i.ZERO
	)


static func get_source_revision(
	entry: Dictionary
) -> String:
	return entry.get(
		KEY_SOURCE_REVISION,
		""
	)


static func is_wrapped_x(
	entry: Dictionary
) -> bool:
	return bool(
		entry.get(
			KEY_WRAPPED_X,
			false
		)
	)


static func is_wrapped_z(
	entry: Dictionary
) -> bool:
	return bool(
		entry.get(
			KEY_WRAPPED_Z,
			false
		)
	)
