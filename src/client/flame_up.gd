extends Node3D

# A flame rig that always rises (Tyler's torch review: a flame points up, never where the stick points). Hang it under the torch model; each
# frame it stands at `head_local` (the top of the torch head, in the torch's own space) with the world's up as its up.

var head_local: Vector3 = Vector3.ZERO


func _ready() -> void:
	top_level = true


func _process(_delta: float) -> void:
	var torch: Node3D = get_parent() as Node3D

	if torch != null and torch.is_inside_tree():
		global_position = torch.to_global(head_local)
		global_basis = Basis.IDENTITY
