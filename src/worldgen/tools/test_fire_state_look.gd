extends SceneTree

# A placed fire is never drawn as a felled trunk or a stump (Dave, build 826: a placed campfire kit showed a brown tree stump): every fire state the server can send
# (laid 9, burnt out 8, lit by wood tier) and every structure state resolves to a look other than the felled one (states 3 and 4 only).
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_state_look.gd

const InventoryView := preload("res://src/client/inventory_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


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

	# The server never gives a fire the state of a tree record.
	var server_src: String = FileAccess.get_file_as_string("res://src/stream/server_items.gd")
	check(server_src.find("\"fire\": {\"state\": 9") >= 0, "a laid campfire is state 9 (loaded, unlit)")

	print("fire state look tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
