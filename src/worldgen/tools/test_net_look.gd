extends SceneTree

# The shore net looks like a net (Dave 25 Oct: it looked like a small hammer): the hand_net shape builds a pole with a hoop and a hanging bag, it is a normal
# tool length, and it is held through the look path (HELD_LOOK_TURN) instead of the generic fallback block.
#   godot --headless --path . --script res://src/worldgen/tools/test_net_look.gd

const BasicLook := preload("res://src/client/basic_look.gd")
const Held := preload("res://src/client/held_item.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var def: Dictionary = BasicLook.entry("shore_net")
	check(str(def.get("shape", "")) == "hand_net", "the shore net's look shape is net (%s)" % str(def.get("shape", "")))
	var mesh: Mesh = BasicLook.mesh_for("shore_net")
	check(mesh != null and mesh.get_surface_count() > 0, "the net mesh builds")
	var box: AABB = mesh.get_aabb()
	check(box.size.x >= 0.9 and box.size.x <= 1.4, "the net is a pole-length tool along its handle axis (%.2f m)" % box.size.x)
	check(box.size.y >= 0.25 and box.size.y <= 0.4 and box.size.z >= 0.25 and box.size.z <= 0.4, "the hoop is about 30 cm across (%.2f x %.2f)" % [box.size.y, box.size.z])
	var hammer: AABB = BasicLook.mesh_for("stone_hammer").get_aabb() if not BasicLook.entry("stone_hammer").is_empty() else AABB()
	check(hammer.size == Vector3.ZERO or mesh.get_surface_count() != BasicLook.mesh_for("stone_hammer").get_surface_count() or box.size != hammer.size, "the net is not the hammer's mesh")
	check(Held.HELD_LOOK_TURN.has("hand_net"), "a net in hand goes through the look path, not the generic block")
	print("net look tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
