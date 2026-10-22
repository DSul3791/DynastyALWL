extends SceneTree

# Per-state look, sound and grass clearing come from data/items/structures.json (Sal_Crafts, 2026-10-22).
#   godot --headless --path . --script res://src/worldgen/tools/test_structure_look.gd

const StructureLook := preload("res://src/shared/structure_look.gd")
const InventoryViewScript := preload("res://src/client/inventory_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var defs: Dictionary = parsed["structures"]
	var states: Dictionary = {}

	for kind in defs:
		check(defs[kind].has("look") and defs[kind].has("sound") and defs[kind].has("clears_grass"), "%s has look, sound and clears_grass" % kind)
		states[int(defs[kind]["state"])] = true

	check(StructureLook.look_of(25) == "foundation" and StructureLook.sound_of(25) == "foundation" and StructureLook.clears_grass(25), "the foundation looks, sounds and clears")
	check(not StructureLook.clears_grass(22) and not StructureLook.clears_grass(24) and not StructureLook.clears_grass(26), "walls, doorways and roofs do not clear grass")
	check(StructureLook.clears_grass(1) and StructureLook.clears_grass(8) and StructureLook.clears_grass(9) and StructureLook.sound_of(8) == "thump", "the campfire states clear and thump")
	check(StructureLook.look_of(12) == "remains" and not StructureLook.clears_grass(12), "old remains look like remains and do not clear grass")
	check(StructureLook.sound_of(13) == "" and StructureLook.sound_of(5) == "leanto", "stations make no placed sound, the lean-to its own")
	var view = InventoryViewScript.new()

	for state in states.keys() + [1, 8, 9, 12]:
		var model: Node3D = view.ghost_model(int(state))
		check(model != null and model.get_child_count() > 0, "state %d builds a model" % int(state))

	print("structure look: %d failures" % failures)
	quit(failures)
