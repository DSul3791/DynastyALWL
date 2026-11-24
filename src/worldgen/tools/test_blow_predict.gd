extends SceneTree

# The player's own blow shows as it lands (Dave 24 Nov 2026: "give as much control to the client as it takes to make them feel natural and fight
# like they should in a real great video game"; docs/design/ANIMAL_NETCODE.md "Plans" step 3). A blow at an animal drawn in reach emits
# blow_landing with its id and where it is drawn (the nearest), at most once per the item's recover_ms (the server's pace) with some slack, only
# well inside the reach, never through a wall, never for a rope; the animal flinches at once, and the server's hit for that blow then plays no second flinch or thud. Any other hit plays as before.
#   godot --headless --path . --script res://src/worldgen/tools/test_blow_predict.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const HeldScript := preload("res://src/client/held_item.gd")
const AnimalViewScript := preload("res://src/client/animal_view.gd")
const MeleeRules := preload("res://src/shared/melee_rules.gd")

var failures: int = 0
var rows: Array = []   # the animals drawn near (held.animal_aim_rows); a member, as a lambda keeps a copy of a local it is given


class Rec:
	extends RefCounted
	var calls: Array = []

	func rpc_id(_peer, kind, slot, _a, _b, _dir) -> void:
		calls.append([kind, slot])


class NetStub:
	extends RefCounted
	var inventory_action: Rec = Rec.new()


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:   # the camera and the animal view need the tree (global_position, flinch's tween)
	var table = ItemTableScript.load_default()
	var view = ViewScript.new()
	view.table = table
	view.inventory = load("res://src/shared/inventory.gd").pack(table)
	var held = HeldScript.new()
	held._inv = view
	held._net = NetStub.new()
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	var animals = AnimalViewScript.new()
	root.add_child(animals)
	await process_frame
	animals.set_process(false)
	camera.global_position = Vector3(0.0, 1.6, 0.0)   # looking down -z
	held._camera = camera
	held.animal_aim_rows = func() -> Array: return rows
	var landed: Array = []
	held.blow_landing.connect(func(id: int, at: Vector3) -> void: landed.append([id, at]))
	var reach: float = float(MeleeRules.load_config()["bare_hand"]["reach_m"])
	var recover: int = int(MeleeRules.load_config()["bare_hand"]["recover_ms"])

	# Bare hands, a deer 1 m ahead: the blow is seen to land on it, and still goes to the server.
	rows = [[Vector3(0.0, 1.0, -1.0), 0.0, 0.3, 7]]
	held._melee_strike()
	check(landed.size() == 1 and int(landed[0][0]) == 7 and (landed[0][1] as Vector3).is_equal_approx(Vector3(0.0, 1.0, -1.0)), "a punch at a deer 1 m ahead lands on it at once (%s)" % str(landed))
	check(held._net.inventory_action.calls.size() == 1, "and is sent to the server, which decides the damage")

	# Faster than the server takes blows: sent, not shown (the server drops it unheard).
	held._melee_strike()
	check(landed.size() == 1 and held._net.inventory_action.calls.size() == 2, "a second punch inside %d ms is sent but not shown" % recover)

	# A blow the server would drop still keeps the pace: one swung at the air restarts it only when the server takes it.
	held._paced_ms -= recover + HeldScript.PREDICT_SLACK_MS
	rows = []
	held._melee_strike()
	check(landed.size() == 1, "a punch at nothing shows nothing")
	rows = [[Vector3(0.0, 1.0, -1.0), 0.0, 0.3, 7]]
	held._melee_strike()
	check(landed.size() == 1, "and the server's pace runs from it: a punch at the deer just after is not shown")

	# Only well inside the reach: at the reach's edge the server may judge it short, so nothing is shown before it answers.
	held._paced_ms -= recover + HeldScript.PREDICT_SLACK_MS
	rows = [[Vector3(0.0, 1.0, -(reach + 0.3 - HeldScript.PREDICT_MARGIN_M * 0.5)), 0.0, 0.3, 8]]
	held._melee_strike()
	check(landed.size() == 1, "a deer at the edge of the reach is not shown hit before the server says")
	held._paced_ms -= recover + HeldScript.PREDICT_SLACK_MS
	rows = [[Vector3(1.0, 1.0, -1.0), 0.0, 0.3, 8]]
	held._melee_strike()
	check(landed.size() == 1, "nor one in reach but off to the side of the look")

	# Just past the pace, a blow may reach the server just inside it after jitter: sent, not shown.
	held._paced_ms = Time.get_ticks_msec() - recover - int(HeldScript.PREDICT_SLACK_MS * 0.5)
	rows = [[Vector3(0.0, 1.0, -1.0), 0.0, 0.3, 7]]
	held._melee_strike()
	check(landed.size() == 1, "a punch %d ms past the last is not shown (the server may judge it too soon)" % (recover + int(HeldScript.PREDICT_SLACK_MS * 0.5)))

	# Two in front: the nearer takes it, as on the server, whatever order the rows come in.
	held._paced_ms -= recover + HeldScript.PREDICT_SLACK_MS
	rows = [[Vector3(0.0, 1.0, -1.4), 0.0, 0.3, 11], [Vector3(0.1, 1.0, -0.9), 0.0, 0.3, 12]]
	held._melee_strike()
	check(landed.size() == 2 and int(landed[1][0]) == 12, "of two deer ahead the nearer is shown hit (%s)" % str(landed.back()))

	# A wall between: the server drops the blow, so nothing is shown.
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.global_position = Vector3(0.0, 1.0, -0.6)
	await physics_frame
	await physics_frame
	held._paced_ms -= recover + HeldScript.PREDICT_SLACK_MS
	rows = [[Vector3(0.0, 1.0, -1.2), 0.0, 0.3, 7]]
	held._melee_strike()
	check(landed.size() == 2, "a deer behind a wall is not shown hit")
	root.remove_child(wall)
	wall.free()
	await physics_frame
	held._paced_ms -= recover + HeldScript.PREDICT_SLACK_MS
	held._melee_strike()
	check(landed.size() == 3, "and with the wall gone it is")

	# A rope binds a bandit, it does not strike: nothing shown.
	view.inventory.numbers[0] = table.number_of("rope")
	view.inventory.counts[0] = 1
	held.holding = true
	held.held_key = 0
	held._paced_ms -= 100000
	rows = [[Vector3(0.0, 1.0, -1.0), 0.0, 0.3, 7]]
	held._melee_strike()
	check(table.number_of("rope") > 0 and landed.size() == 3, "a rope at a bandit shows no hit")

	# The view: the shown blow flinches the body now; the server's hit for it plays nothing twice; any later hit plays as before.
	var node: Node3D = Node3D.new()
	animals.add_child(node)
	animals._bodies[7] = {"node": node, "state": 0, "spd": 0.0, "kind": "deer", "heading": 0.0}
	check(not animals.predict_hit(99), "a blow on an animal no longer drawn shows nothing")
	check(animals.predict_hit(7) and node.has_meta("rest_scale"), "a blow seen to land flinches the body at once")
	check(animals.confirm_hit(7), "the server's hit for it is already shown")
	check(not animals.confirm_hit(7), "a second hit on it (another player's) plays as before")
	animals.predict_hit(7)
	animals._t += AnimalViewScript.PREDICT_KEEP_S + 0.1
	check(not animals.confirm_hit(7), "a hit long after the shown blow is a new hit")
	animals.predict_hit(7)
	animals._t += AnimalViewScript.PREDICT_KEEP_S + 0.1
	animals._bodies[5] = animals._bodies[7]
	animals.predict_hit(5)
	check(not animals._predicted.has(7) and animals._predicted.has(5), "a shown blow the server never confirmed is let go at the next")

	# Wire: aim rows carry the id, the client scene plays the thud for a shown blow and skips the server's echo of it.
	check((animals.aim_rows(Vector3.ZERO, 80.0)[0] as Array).size() == 4 and int(animals.aim_rows(Vector3.ZERO, 80.0)[0][3]) == 7, "an aim row ends with the animal's id")
	var client: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(client.contains("held.blow_landing.connect") and client.contains("_animal_view_node.predict_hit(id)") and client.contains("if animal_view.confirm_hit(id):"), "the client scene shows the blow and plays the server's hit once")

	animals.queue_free()
	camera.queue_free()
	print("test_blow_predict: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
