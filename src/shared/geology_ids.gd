class_name GeologyIds
extends RefCounted


const AIR := 0
const SEDIMENT := 1
const SHALE := 2
const LIMESTONE := 3
const COAL := 4
const GRANITE := 5


static func get_name_from_id(geology_id: int) -> String:
	match geology_id:
		AIR:
			return "Air"

		SEDIMENT:
			return "Sediment"

		SHALE:
			return "Shale"

		LIMESTONE:
			return "Limestone"

		COAL:
			return "Coal"

		GRANITE:
			return "Granite"

		_:
			return "Unknown"
