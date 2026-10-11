class_name LakeWaterModel
extends RefCounted


const WATER_NONE := 0
const WATER_WETLAND := 1
const WATER_POND := 2
const WATER_LAKE := 3


# ==================================================
# NATURAL WATER CLASSIFICATION
#
# There is no hard-coded guaranteed central lake.
#
# Basins are classified from:
#
# - basin area
# - basin depth
# - contributing catchment
#
# This allows naturally occurring mountain lakes,
# valley lakes, ponds and wetlands without forcing
# any specific lake location into the world.
# ==================================================


var _lake_basins
var _accumulation_map

var _width: int = 0
var _depth: int = 0

var _basin_water_classes: Array[int] = []
var _basin_catchment_km2: Array[float] = []

var _wetland_count: int = 0
var _pond_count: int = 0
var _lake_count: int = 0


func setup(
	lake_basins,
	accumulation_map
) -> void:
	_lake_basins = lake_basins
	_accumulation_map = accumulation_map

	_width = (
		_accumulation_map.get_width()
	)

	_depth = (
		_accumulation_map.get_depth()
	)

	_basin_water_classes.clear()
	_basin_catchment_km2.clear()

	_wetland_count = 0
	_pond_count = 0
	_lake_count = 0

	for basin_id in range(
		_lake_basins.get_basin_count()
	):
		_basin_water_classes.append(
			WATER_NONE
		)

		_basin_catchment_km2.append(
			0.0
		)

	_measure_basin_catchments()
	_classify_basins()


func _measure_basin_catchments() -> void:
	for grid_z in range(
		_depth
	):
		for grid_x in range(
			_width
		):
			var basin_id: int = (
				_lake_basins
					.get_basin_id_at_grid(
						grid_x,
						grid_z
					)
			)

			if basin_id < 0:
				continue

			var drainage_area_km2: float = (
				_accumulation_map
					.get_drainage_area_square_kilometers(
						grid_x,
						grid_z
					)
			)

			if (
				drainage_area_km2
					> _basin_catchment_km2[
						basin_id
					]
			):
				_basin_catchment_km2[
					basin_id
				] = drainage_area_km2


func _classify_basins() -> void:
	for basin_id in range(
		_lake_basins.get_basin_count()
	):
		var water_class: int = (
			_classify_basin(
				basin_id
			)
		)

		_basin_water_classes[
			basin_id
		] = water_class

		match water_class:
			WATER_WETLAND:
				_wetland_count += 1

			WATER_POND:
				_pond_count += 1

			WATER_LAKE:
				_lake_count += 1


func _classify_basin(
	basin_id: int
) -> int:
	var area_hectares: float = (
		_lake_basins
			.get_basin_area_hectares(
				basin_id
			)
	)

	var max_depth: float = (
		_lake_basins
			.get_basin_max_depth(
				basin_id
			)
	)

	var catchment_km2: float = (
		_basin_catchment_km2[
			basin_id
		]
	)

	# --------------------------------------------------
	# NATURAL PERMANENT LAKE
	# --------------------------------------------------

	var broad_lake: bool = (
		area_hectares >= 1.0
		and max_depth >= 3.0
	)

	var deep_lake: bool = (
		area_hectares >= 0.50
		and max_depth >= 6.0
	)

	if (
		(
			broad_lake
			or deep_lake
		)
		and catchment_km2 >= 0.03
	):
		return WATER_LAKE

	# --------------------------------------------------
	# PERMANENT POND
	# --------------------------------------------------

	if (
		area_hectares >= 0.25
		and max_depth >= 1.5
		and catchment_km2 >= 0.01
	):
		return WATER_POND

	# --------------------------------------------------
	# WETLAND / SEASONALLY WET GROUND
	# --------------------------------------------------

	if (
		area_hectares >= 0.05
		and catchment_km2 >= 0.005
	):
		return WATER_WETLAND

	return WATER_NONE


func get_water_class(
	basin_id: int
) -> int:
	if not _is_valid_basin_id(
		basin_id
	):
		return WATER_NONE

	return _basin_water_classes[
		basin_id
	]


func get_water_class_name(
	water_class: int
) -> String:
	match water_class:
		WATER_NONE:
			return "Dry Depression"

		WATER_WETLAND:
			return "Wetland"

		WATER_POND:
			return "Pond"

		WATER_LAKE:
			return "Lake"

		_:
			return "Unknown"


func get_basin_catchment_km2(
	basin_id: int
) -> float:
	if not _is_valid_basin_id(
		basin_id
	):
		return 0.0

	return _basin_catchment_km2[
		basin_id
	]


func get_wetland_count() -> int:
	return _wetland_count


func get_pond_count() -> int:
	return _pond_count


func get_lake_count() -> int:
	return _lake_count


func get_permanent_water_count() -> int:
	return (
		_pond_count
		+ _lake_count
	)


func _is_valid_basin_id(
	basin_id: int
) -> bool:
	return (
		basin_id >= 0
		and basin_id
			< _basin_water_classes.size()
	)
