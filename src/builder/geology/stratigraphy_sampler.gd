class_name StratigraphySampler
extends RefCounted


const Geology := preload(
	"res://src/shared/geology_ids.gd"
)


var _profile: StratigraphyProfile

var _layer_bottoms := PackedFloat64Array()
var _layer_geology_ids := PackedInt32Array()
var _layer_names: Array[String] = []

var _layer_count: int = 0
var _total_thickness_meters: float = 0.0


func setup(
	profile: StratigraphyProfile
) -> void:
	_profile = profile
	_build_layer_cache()


func _build_layer_cache() -> void:
	_layer_bottoms.clear()
	_layer_geology_ids.clear()
	_layer_names.clear()

	_layer_count = 0
	_total_thickness_meters = 0.0

	if _profile == null:
		return

	_layer_count = _profile.layers.size()

	_layer_bottoms.resize(
		_layer_count
	)

	_layer_geology_ids.resize(
		_layer_count
	)

	_layer_names.resize(
		_layer_count
	)

	var current_depth: float = 0.0

	for index in range(
		_layer_count
	):
		var layer: StratigraphyLayer = (
			_profile.layers[index]
		)

		current_depth += (
			layer.thickness_meters
		)

		_layer_bottoms[index] = (
			current_depth
		)

		_layer_geology_ids[index] = (
			layer.geology_id
		)

		_layer_names[index] = (
			layer.layer_name
		)

	_total_thickness_meters = (
		current_depth
	)


func get_total_thickness_meters() -> float:
	return _total_thickness_meters


func get_geology_id_at_depth(
	depth_meters: float
) -> int:
	if _profile == null:
		return Geology.AIR

	if depth_meters < 0.0:
		return Geology.AIR

	if (
		depth_meters
		>= _total_thickness_meters
	):
		return Geology.GRANITE

	var index: int = (
		_find_layer_index(
			depth_meters
		)
	)

	if index < 0:
		return Geology.GRANITE

	return _layer_geology_ids[
		index
	]


func get_geology_id_at_elevation(
	y: float,
	column_top_y: float
) -> int:
	return get_geology_id_at_depth(
		column_top_y - y
	)


func get_layer_name_at_depth(
	depth_meters: float
) -> String:
	if _profile == null:
		return "Invalid"

	if depth_meters < 0.0:
		return "Air"

	if (
		depth_meters
		>= _total_thickness_meters
	):
		return "Granite Basement"

	var index: int = (
		_find_layer_index(
			depth_meters
		)
	)

	if index < 0:
		return "Granite Basement"

	return _layer_names[
		index
	]


func _find_layer_index(
	depth_meters: float
) -> int:
	var low: int = 0
	var high: int = (
		_layer_count - 1
	)

	while low <= high:
		var middle: int = (
			(low + high) >> 1
		)

		if (
			depth_meters
			< _layer_bottoms[middle]
		):
			if (
				middle == 0
				or depth_meters
					>= _layer_bottoms[
						middle - 1
					]
			):
				return middle

			high = middle - 1

		else:
			low = middle + 1

	return -1


func get_geology_id_at_depth_reference(
	depth_meters: float
) -> int:
	if _profile == null:
		return Geology.AIR

	if depth_meters < 0.0:
		return Geology.AIR

	var current_depth: float = 0.0

	for index in range(
		_profile.layers.size()
	):
		var layer: StratigraphyLayer = (
			_profile.layers[index]
		)

		var layer_bottom: float = (
			current_depth
			+ layer.thickness_meters
		)

		if depth_meters < layer_bottom:
			return layer.geology_id

		current_depth = layer_bottom

	return Geology.GRANITE


func get_geology_id_at_elevation_reference(
	y: float,
	column_top_y: float
) -> int:
	return (
		get_geology_id_at_depth_reference(
			column_top_y - y
		)
	)


func get_layer_name_at_depth_reference(
	depth_meters: float
) -> String:
	if _profile == null:
		return "Invalid"

	if depth_meters < 0.0:
		return "Air"

	var current_depth: float = 0.0

	for index in range(
		_profile.layers.size()
	):
		var layer: StratigraphyLayer = (
			_profile.layers[index]
		)

		var layer_bottom: float = (
			current_depth
			+ layer.thickness_meters
		)

		if depth_meters < layer_bottom:
			return layer.layer_name

		current_depth = layer_bottom

	return "Granite Basement"
