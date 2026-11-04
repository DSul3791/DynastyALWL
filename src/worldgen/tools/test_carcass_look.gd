extends SceneTree

# The carcass parts keep their shape when turned (carcass_look.gd _part): a deer's legs lie out sideways as thin sticks and its neck reaches forward, instead of
# standing up as flat planks (Basis.scaled() scaled along the parent's axes after the turn, until 4 Nov 2026).
#   godot --headless --path . --script res://src/worldgen/tools/test_carcass_look.gd

const CarcassLook := preload("res://src/client/carcass_look.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _box(node: MeshInstance3D) -> AABB:
	return node.transform * node.mesh.get_aabb()


func _init() -> void:
	var deer: Node3D = CarcassLook.build("deer")
	var d: Dictionary = CarcassLook.row("deer")
	var parts: Array = deer.get_children()
	# children: body, belly, four legs, neck, head, then antlers and tail
	for i in range(2, 6):
		var leg: AABB = _box(parts[i])
		_check(leg.size.x > float(d["legs"]) * 0.8, "leg %d lies out sideways, about a leg long (%.2f)" % [i - 1, leg.size.x])
		_check(leg.size.y < float(d["legs"]) * 0.3, "leg %d is a stick, not standing up (%.2f tall)" % [i - 1, leg.size.y])
		_check(leg.size.z < float(d["legs"]) * 0.2, "leg %d is thin (%.2f deep)" % [i - 1, leg.size.z])

	var neck: AABB = _box(parts[6])
	_check(neck.size.z > float(d["neck"]) * 0.8, "neck reaches forward (%.2f)" % neck.size.z)
	_check(neck.size.y < float(d["width"]) * 0.7, "neck lies low (%.2f tall)" % neck.size.y)
	deer.free()
	print("carcass look tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
