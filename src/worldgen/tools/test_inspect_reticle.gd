extends SceneTree

# The inspection + (Dave 26 Nov 2026, src/client/inspect_reticle.gd): a red + at the middle of the screen only while inspection mode is on,
# never at the same time as the bow or spear cross, and not while a menu has the mouse; the client builds it on its HUD layer and the held
# item says when its cross is up.
#   godot --headless --path . --script res://src/worldgen/tools/test_inspect_reticle.gd

const InspectReticle := preload("res://src/client/inspect_reticle.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	check(InspectReticle.shown(true, false, true), "inspection on: the + shows")
	check(not InspectReticle.shown(false, false, true), "inspection off: no +")
	check(not InspectReticle.shown(true, true, true), "the bow or spear cross up: no + (never both)")
	check(not InspectReticle.shown(true, false, false), "a menu has the mouse or the photo camera is on: no +")
	var plus = InspectReticle.new()
	check(not plus.visible, "the + starts hidden")
	check(plus.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the + never takes a click")
	var red: Color = InspectReticle.RED
	check(red.r > 0.7 and red.g < 0.2 and red.b < 0.2, "the + is red (%s)" % str(red))
	check(InspectReticle.ARM_PX <= 10.0 and InspectReticle.WIDTH_PX <= 3.0, "the + is small (arms %d px, %d px wide)" % [int(InspectReticle.ARM_PX), int(InspectReticle.WIDTH_PX)])
	plus.free()
	var client: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(client.contains("InspectReticleScript.shown(inspecting, held != null and held.aim_cross_shown()"), "the client shows the + by inspection mode and hides it under the weapon cross")
	check(client.contains("layer.add_child(_inspect_plus)"), "the client puts the + on its HUD layer")
	var held: String = FileAccess.get_file_as_string("res://src/client/held_item.gd")
	check(held.contains("func aim_cross_shown() -> bool:"), "the held item says when its cross is up")
	print("Test done: %d failures" % failures)
	quit(1 if failures > 0 else 0)
