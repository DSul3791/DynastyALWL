extends Node3D

# A placed piece from src/client/piece_look.gd for tools/shot_node.gd (Kathleen): four views of one piece, offline with the real meshes and textures.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/piece_view.gd --piece=rough_bed --out=C:/temp/bed.png --height=1.6 --pitch=-30

const PieceLook := preload("res://src/client/piece_look.gd")


func _init() -> void:
	var piece: String = "rough_bed"

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--piece="):
			piece = a.trim_prefix("--piece=")

	var looks: Object = PieceLook   # static builders are called by name

	if not looks.has_method(piece):
		push_error("piece_view: PieceLook has no function " + piece)
		return

	add_child(looks.call(piece))
