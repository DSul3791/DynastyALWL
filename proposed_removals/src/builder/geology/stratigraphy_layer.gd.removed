class_name StratigraphyLayer
extends Resource


const Geology := preload("res://src/shared/geology_ids.gd")


@export var layer_name: String = "Unnamed Layer"
@export var geology_id: int = Geology.SHALE
@export var thickness_meters: float = 20.0


func is_valid() -> bool:
	if layer_name.is_empty():
		return false

	if geology_id < 0:
		return false

	if thickness_meters <= 0.0:
		return false

	return true
