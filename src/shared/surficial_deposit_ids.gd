class_name SurficialDepositIds
extends RefCounted


# These IDs describe young material sitting on top of the older geology.
#
# They are separate from GeologyIds because:
#
#   shale / limestone / granite / coal
#       = ancient geological formations
#
#   gravel / clay / peat / lake mud
#       = recent surface deposits
#
# Once these IDs are used in a published baked world,
# do not renumber them.

const NONE := 0

const ALLUVIUM := 1
const GRAVEL := 2
const SAND := 3
const SILT := 4
const CLAY := 5
const LAKE_SEDIMENT := 6
const PEAT := 7


static func get_name_from_id(
	deposit_id: int
) -> String:
	match deposit_id:
		NONE:
			return "None"

		ALLUVIUM:
			return "Alluvium"

		GRAVEL:
			return "Gravel"

		SAND:
			return "Sand"

		SILT:
			return "Silt"

		CLAY:
			return "Clay"

		LAKE_SEDIMENT:
			return "Lake Sediment"

		PEAT:
			return "Peat"

		_:
			return "Unknown"
