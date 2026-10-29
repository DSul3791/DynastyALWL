class_name ChannelNetwork
extends RefCounted


const CHANNEL_NONE := 0
const CHANNEL_HEADWATER := 1
const CHANNEL_SMALL_STREAM := 2
const CHANNEL_STREAM := 3
const CHANNEL_MAJOR := 4


# Drainage-area thresholds.
#
# These are expressed in square kilometers rather than raw
# grid-cell counts so the classification remains usable if
# hydrology grid resolution changes later.
const HEADWATER_AREA_KM2 := 0.010
const SMALL_STREAM_AREA_KM2 := 0.025
const STREAM_AREA_KM2 := 0.050
const MAJOR_CHANNEL_AREA_KM2 := 0.100


var _accumulation_map

var _width: int = 0
var _depth: int = 0

var _channel_classes: PackedByteArray

var _class_counts: Array[int] = []


func setup(accumulation_map) -> void:
	_accumulation_map = accumulation_map

	_width = _accumulation_map.get_width()
	_depth = _accumulation_map.get_depth()

	_channel_classes.resize(
		_width * _depth
	)

	_class_counts.clear()

	for i in range(CHANNEL_MAJOR + 1):
		_class_counts.append(0)

	_generate()


func _generate() -> void:
	for grid_z in range(_depth):
		for grid_x in range(_width):
			var channel_class: int = (
				_classify_cell(
					grid_x,
					grid_z
				)
			)

			_channel_classes[
				_get_index(
					grid_x,
					grid_z
				)
			] = channel_class

			_class_counts[channel_class] += 1


func _classify_cell(
	grid_x: int,
	grid_z: int
) -> int:
	var drainage_area_km2: float = (
		_accumulation_map
		.get_drainage_area_square_kilometers(
			grid_x,
			grid_z
		)
	)

	if drainage_area_km2 >= MAJOR_CHANNEL_AREA_KM2:
		return CHANNEL_MAJOR

	if drainage_area_km2 >= STREAM_AREA_KM2:
		return CHANNEL_STREAM

	if drainage_area_km2 >= SMALL_STREAM_AREA_KM2:
		return CHANNEL_SMALL_STREAM

	if drainage_area_km2 >= HEADWATER_AREA_KM2:
		return CHANNEL_HEADWATER

	return CHANNEL_NONE


func get_channel_class(
	grid_x: int,
	grid_z: int
) -> int:
	if not is_valid_grid_position(
		grid_x,
		grid_z
	):
		return CHANNEL_NONE

	return _channel_classes[
		_get_index(
			grid_x,
			grid_z
		)
	]


func get_channel_class_name(
	channel_class: int
) -> String:
	match channel_class:
		CHANNEL_NONE:
			return "None"

		CHANNEL_HEADWATER:
			return "Headwater Channel"

		CHANNEL_SMALL_STREAM:
			return "Small Stream"

		CHANNEL_STREAM:
			return "Established Stream"

		CHANNEL_MAJOR:
			return "Major Channel"

		_:
			return "Unknown"


func get_class_count(
	channel_class: int
) -> int:
	if (
		channel_class < 0
		or channel_class >= _class_counts.size()
	):
		return 0

	return _class_counts[channel_class]


func is_channel(
	grid_x: int,
	grid_z: int
) -> bool:
	return (
		get_channel_class(
			grid_x,
			grid_z
		)
		!= CHANNEL_NONE
	)


func get_total_channel_cell_count() -> int:
	var total: int = 0

	for channel_class in range(
		CHANNEL_HEADWATER,
		CHANNEL_MAJOR + 1
	):
		total += _class_counts[channel_class]

	return total


func get_width() -> int:
	return _width


func get_depth() -> int:
	return _depth


func is_valid_grid_position(
	grid_x: int,
	grid_z: int
) -> bool:
	return (
		grid_x >= 0
		and grid_z >= 0
		and grid_x < _width
		and grid_z < _depth
	)


func _get_index(
	grid_x: int,
	grid_z: int
) -> int:
	return (
		grid_z * _width
		+ grid_x
	)
