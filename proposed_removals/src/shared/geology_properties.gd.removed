class_name GeologyProperties
extends RefCounted


# All values are gameplay-relative scales from 0.0 to 1.0.
#
# These are NOT Mohs hardness values.
#
# Excavation resistance:
#   How difficult the material is to dig, cut, drill or break.
#
# Erosion resistance:
#   How strongly the material resists ordinary mechanical erosion.
#
# Fracture tendency:
#   How readily the material develops or follows cracks and joints.
#
# Chemical weathering:
#   How susceptible the material is to dissolution or chemical attack.
#
# Cave stability:
#   How well unsupported underground openings tend to remain intact.


static func get_excavation_resistance(
	geology_id: int
) -> float:
	match geology_id:
		GeologyIds.AIR:
			return 0.0

		GeologyIds.SEDIMENT:
			return 0.15

		GeologyIds.SHALE:
			return 0.40

		GeologyIds.LIMESTONE:
			return 0.65

		GeologyIds.COAL:
			return 0.30

		GeologyIds.GRANITE:
			return 1.00

		_:
			return 0.50


static func get_erosion_resistance(
	geology_id: int
) -> float:
	match geology_id:
		GeologyIds.AIR:
			return 0.0

		GeologyIds.SEDIMENT:
			return 0.15

		GeologyIds.SHALE:
			return 0.30

		GeologyIds.LIMESTONE:
			return 0.60

		GeologyIds.COAL:
			return 0.35

		GeologyIds.GRANITE:
			return 0.90

		_:
			return 0.50


static func get_fracture_tendency(
	geology_id: int
) -> float:
	match geology_id:
		GeologyIds.AIR:
			return 0.0

		GeologyIds.SEDIMENT:
			return 0.20

		GeologyIds.SHALE:
			return 0.75

		GeologyIds.LIMESTONE:
			return 0.60

		GeologyIds.COAL:
			return 0.70

		GeologyIds.GRANITE:
			return 0.45

		_:
			return 0.50


static func get_chemical_weathering(
	geology_id: int
) -> float:
	match geology_id:
		GeologyIds.AIR:
			return 0.0

		GeologyIds.SEDIMENT:
			return 0.35

		GeologyIds.SHALE:
			return 0.45

		GeologyIds.LIMESTONE:
			return 1.00

		GeologyIds.COAL:
			return 0.45

		GeologyIds.GRANITE:
			return 0.20

		_:
			return 0.50


static func get_cave_stability(
	geology_id: int
) -> float:
	match geology_id:
		GeologyIds.AIR:
			return 0.0

		GeologyIds.SEDIMENT:
			return 0.10

		GeologyIds.SHALE:
			return 0.35

		GeologyIds.LIMESTONE:
			return 0.75

		GeologyIds.COAL:
			return 0.30

		GeologyIds.GRANITE:
			return 0.95

		_:
			return 0.50
