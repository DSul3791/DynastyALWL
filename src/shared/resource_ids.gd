class_name ResourceIds
extends RefCounted


# IMPORTANT:
# These numeric IDs will eventually become part of the baked world format.
# Once a resource ID is used in published world data, do not renumber it.
# New resources should always be appended to the end.


const NONE := 0

# Fuels / major industrial resources
const COAL := 1

# Base and structural metals
const IRON := 2
const COPPER := 3
const TIN := 4
const LEAD := 5
const ZINC := 6
const NICKEL := 7

# Precious metals
const SILVER := 8
const GOLD := 9

# Industrial / geological resources
const SALT := 10
const SULFUR := 11
const CLAY := 12
const GYPSUM := 13
const GRAPHITE := 14

# Valuable minerals
const GEMSTONE := 15

# Surface / agricultural resources
const PEAT := 16


static func get_name_from_id(resource_id: int) -> String:
	match resource_id:
		NONE:
			return "None"

		COAL:
			return "Coal"

		IRON:
			return "Iron"

		COPPER:
			return "Copper"

		TIN:
			return "Tin"

		LEAD:
			return "Lead"

		ZINC:
			return "Zinc"

		NICKEL:
			return "Nickel"

		SILVER:
			return "Silver"

		GOLD:
			return "Gold"

		SALT:
			return "Salt"

		SULFUR:
			return "Sulfur"

		CLAY:
			return "Clay"

		GYPSUM:
			return "Gypsum"

		GRAPHITE:
			return "Graphite"

		GEMSTONE:
			return "Gemstone"

		PEAT:
			return "Peat"

		_:
			return "Unknown"
