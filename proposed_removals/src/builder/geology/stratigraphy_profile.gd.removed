class_name StratigraphyProfile
extends Resource


@export var profile_name: String = "Default Stratigraphy"

@export var layers: Array[StratigraphyLayer] = []


func is_valid() -> bool:
	if profile_name.is_empty():
		return false

	if layers.is_empty():
		return false

	for layer in layers:
		if layer == null:
			return false

		if not layer.is_valid():
			return false

	return true


func get_total_thickness_meters() -> float:
	var total := 0.0

	for layer in layers:
		total += layer.thickness_meters

	return total
