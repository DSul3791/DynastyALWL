extends SceneTree

# The shore net looks like a net (Dave 25 Oct: it looked like a small hammer; BUG-022: a throw net on a long rope, not a dip net on a pole): the hand_net
# shape builds a rope coil, a line and a round bell of twine with sinkers round the mouth, held through the look path (HELD_LOOK_TURN).
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
	check(box.size.x >= 0.55 and box.size.x <= 1.0, "the coil, line and net together are well under a metre long (%.2f m)" % box.size.x)
	# Lying loose the net slumps (picture check 4 Nov 2026: a 30 cm standing bell read as a birdcage); the full bell is checked on the hanging net below.
	check(box.size.y >= 0.08 and box.size.y <= 0.2 and box.size.z >= 0.3 and box.size.z <= 0.45, "the dropped net lies slumped, 8 to 20 cm high, its round mouth about 37 cm across (%.2f x %.2f)" % [box.size.y, box.size.z])
	var hammer: AABB = BasicLook.mesh_for("stone_hammer").get_aabb() if not BasicLook.entry("stone_hammer").is_empty() else AABB()
	check(hammer.size == Vector3.ZERO or mesh.get_surface_count() != BasicLook.mesh_for("stone_hammer").get_surface_count() or box.size != hammer.size, "the net is not the hammer's mesh")
	check(Held.HELD_LOOK_TURN.has("hand_net"), "a net in hand goes through the look path, not the generic block")
	# In the hand (Kathleen's check 4 Nov: it was held sideways and looked small): the coil at the origin where the hand closes, the bell hanging below it on its
	# line, mouth down, its real size, centred under the hand.
	var hang: Mesh = BasicLook.mesh("hand_net_hanging", Color.html(str(def.get("color", "#8a8a8a"))), float(def.get("size", 1.0)), def.get("bits", []))
	var h: AABB = hang.get_aabb()
	check(h.end.y <= 0.02 and h.position.y <= -0.4 and h.position.y >= -0.55, "the held net hangs below the hand, its mouth about 45 cm down (top %.2f, bottom %.2f)" % [h.end.y, h.position.y])
	check(absf(h.get_center().x) < 0.03 and absf(h.get_center().z) < 0.03, "the held net hangs straight under the hand (centre %.2f, %.2f)" % [h.get_center().x, h.get_center().z])
	check(h.size.x >= 0.34 and h.size.z >= 0.34, "the held net keeps its real 37 cm mouth (%.2f x %.2f)" % [h.size.x, h.size.z])
	print("net look tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
