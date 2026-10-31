extends SceneTree

# A placed fire is never drawn as a felled trunk or a stump (Dave, build 826: a placed campfire kit showed a brown tree stump): every fire state the server can send
# (laid 9, burnt out 8, lit by wood tier) and every structure state resolves to a look other than the felled one (states 3 and 4 only).
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_state_look.gd

const InventoryView := preload("res://src/client/inventory_view.gd")
const BuildingLook := preload("res://src/client/building_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _first_mesh(node: Node) -> Mesh:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		return (child as MeshInstance3D).mesh

	return null


func _triangles(node: Node) -> int:
	var total: int = 0

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (child as MeshInstance3D).mesh

		if mesh != null:
			for surface in mesh.get_surface_count():
				total += mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size() / 3

	return total


func _init() -> void:
	var cooking: Dictionary = _json("res://data/items/cooking.json")
	var fire_states: Array = [1, 8, 9]

	for tier in (cooking.get("fire_tiers", {}) as Dictionary).values():
		fire_states.append(int(tier["state"]))

	for state in fire_states:
		check(not InventoryView.is_felled_state(int(state)), "fire state %d is not drawn as a trunk or stump" % int(state))

	check(InventoryView.is_felled_state(3) and InventoryView.is_felled_state(4), "states 3 and 4 are the trunk and the stump")

	for state in range(0, 80):
		check(InventoryView.is_felled_state(state) == (state == 3 or state == 4), "state %d: only 3 and 4 are felled" % state)

	var structures: Dictionary = _json("res://data/items/structures.json")

	for kind in structures:
		var row: Variant = structures[kind]

		if row is Dictionary and (row as Dictionary).has("state"):
			check(not InventoryView.is_felled_state(int(row["state"])), "structure %s (state %d) is not drawn as a trunk or stump" % [kind, int(row["state"])])


	# The fire looks: laid (unlit, loaded), lit and burnt out, tiers 1 to 3: built, cheap, cached, and the laid one is bigger the higher the tier.
	var tris: Dictionary = {}

	for tier in range(1, 4):
		for state_name in ["laid", "lit", "burnt"]:
			var fire: Node3D = BuildingLook.fire(state_name == "lit", state_name == "laid", tier)
			var count: int = _triangles(fire)
			tris["%s_%d" % [state_name, tier]] = count
			check(count > 40 and count < 3000, "fire %s tier %d is built and cheap (%d triangles)" % [state_name, tier, count])
			check((fire.get_node_or_null("Light") != null) == (state_name == "lit"), "fire %s tier %d: a light only when lit" % [state_name, tier])
			var again: Node3D = BuildingLook.fire(state_name == "lit", state_name == "laid", tier)
			check(_first_mesh(again) == _first_mesh(fire), "fire %s tier %d: the mesh is cached, not rebuilt" % [state_name, tier])
			fire.free()
			again.free()

	check(int(tris["laid_1"]) < int(tris["laid_2"]) and int(tris["laid_2"]) < int(tris["laid_3"]), "the laid fire has more sticks the higher the tier (%d, %d, %d)" % [tris["laid_1"], tris["laid_2"], tris["laid_3"]])
	check(int(tris["laid_2"]) > int(tris["burnt_2"]), "a laid fire is more built-up than a burnt-out one")

	# The server never gives a fire the state of a tree record.
	var server_src: String = FileAccess.get_file_as_string("res://src/stream/server_items.gd")
	check(server_src.find("\"fire\": {\"state\": 9") >= 0, "a laid campfire is state 9 (loaded, unlit)")

	print("fire state look tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
