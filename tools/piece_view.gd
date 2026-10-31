extends Node3D

# A placed piece from src/client/piece_look.gd for tools/shot_node.gd (Kathleen): four views of one piece, offline with the real meshes and textures.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/piece_view.gd --piece=rough_bed   (add --building for a function of building_look.gd, e.g. --piece=leanto --building) --out=C:/temp/bed.png --height=1.6 --pitch=-30

const PieceLook := preload("res://src/client/piece_look.gd")
const BuildingLook := preload("res://src/client/building_look.gd")


func _init() -> void:
	var piece: String = "rough_bed"
	var from_building: bool = false

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--piece="):
			piece = a.trim_prefix("--piece=")
		elif a == "--building":
			from_building = true      # the function is in building_look.gd (lean-to, forges, chest, bed...) and not in piece_look.gd

	var looks: Object = BuildingLook if from_building else PieceLook   # static builders are called by name

	if not looks.has_method(piece):
		push_error("piece_view: PieceLook has no function " + piece)
		return

	add_child(looks.call(piece))
