extends SceneTree

# One-shot clips (Dave 23 Nov 2026: animals "like really bad animatronics"; docs/design/ANIMAL_GAIT.md): a hit, a bite or a death plays
# once and is cut at its cap; a lunge ending in the rows bites; while it plays the state's clip does not take over, then it does; a standing hit clip is not played on a
# running body, a hit taken on the run is; a killed animal with a death clip stays drawn until the clip ends; a model with no clip for
# the role plays nothing.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_once.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A drawn body with an AnimationPlayer whose roles name the clips given ({role: [clip, seconds]}).
func body(v, id: int, roles: Dictionary) -> Dictionary:
	var node: Node3D = Node3D.new()
	var player: AnimationPlayer = AnimationPlayer.new()
	var lib: AnimationLibrary = AnimationLibrary.new()
	var by_role: Dictionary = {}

	for role in roles:
		var anim: Animation = Animation.new()
		anim.length = float(roles[role][1])
		anim.loop_mode = Animation.LOOP_NONE if role in AnimalViewScript.ONCE_ROLES else Animation.LOOP_LINEAR
		lib.add_animation(StringName(roles[role][0]), anim)
		by_role[role] = str(roles[role][0])

	player.add_animation_library("", lib)
	player.set_meta("roles", by_role)
	node.add_child(player)
	node.set_meta("player", player)
	node.set_meta("model", true)
	node.set_meta("model_row", {"clips": {"0": by_role.get("0", "")}})
	v.add_child(node)
	var b: Dictionary = {"node": node, "state": 0, "spd": 0.0, "id": id, "target": Vector3.ZERO, "kind": "deer", "samples": [], "heading": 0.0, "phase": 0.0, "step_count": -1, "contact_m": 0.5, "turn_rad_s": 6.0}
	v._bodies[id] = b
	return b


func _initialize() -> void:   # nodes added to root enter the tree only after a frame (test_goal_ui); flinch and _die need the tree
	var v = AnimalViewScript.new()
	root.add_child(v)
	await process_frame
	v.set_process(false)      # the test calls the view's functions itself; its frame loop would draw the hand-made bodies
	check(v.is_inside_tree(), "the view is in the tree")

	# A hit on a standing body: the clip plays, cut at HIT_MAX_S (the clip is 2.9 s), and the state's clip waits until then.
	var b: Dictionary = body(v, 1, {"0": ["Idle", 4.0], "hit": ["Hit_Idle_F01_once", 2.9]})
	var player: AnimationPlayer = (b["node"] as Node3D).get_meta("player")
	v.flinch(1)
	check(absf(float(b.get("once_until", -1.0)) - (v._t + AnimalViewScript.HIT_MAX_S)) < 0.001, "a standing hit plays until its cap (%.2f s)" % (float(b.get("once_until", -1.0)) - v._t))
	check(player.assigned_animation == "Hit_Idle_F01_once", "the hit clip is the one playing (%s)" % player.assigned_animation)
	v._animate_model(b["node"], b, 0, 0.0, 0.016)
	check(player.assigned_animation == "Hit_Idle_F01_once", "while it plays, the state's clip does not take over")
	v._t += AnimalViewScript.HIT_MAX_S + 0.01
	v._animate_model(b["node"], b, 0, 0.0, 0.016)
	check(player.assigned_animation == "Idle", "after its cap the state's clip is back (%s)" % player.assigned_animation)

	# A running body: a standing hit clip is not played (it would slide), a hit taken on the run is.
	var runner: Dictionary = body(v, 2, {"0": ["Idle", 4.0], "hit": ["Hit_Idle_F01_once", 2.9]})
	runner["spd"] = 6.0
	v.flinch(2)
	check(not runner.has("once_until"), "a standing hit clip is not played on a body running 6 m/s")
	var on_run: Dictionary = body(v, 3, {"0": ["Idle", 4.0], "hit": ["HitInRunHead_F_once", 1.3]})
	on_run["spd"] = 6.0
	v.flinch(3)
	check(on_run.has("once_until"), "a hit taken on the run plays on a running body")

	# No clip for the role: nothing plays, nothing waits.
	var plain: Dictionary = body(v, 4, {"0": ["Idle", 4.0]})
	check(not v._play_once(plain, "bite", AnimalViewScript.BITE_MAX_S) and not plain.has("once_until"), "a model with no bite clip plays none")

	# A bite shorter than its cap plays its own length.
	var biter: Dictionary = body(v, 5, {"0": ["Idle", 4.0], "bite": ["attack_02_once", 0.4]})
	check(v._play_once(biter, "bite", AnimalViewScript.BITE_MAX_S) and absf(float(biter["once_until"]) - v._t - 0.4) < 0.001, "a 0.4 s bite plays 0.4 s")

	# A death (Dave 26 Nov 2026: dead animals became "strange low poly homemade models"): the body stays drawn as it falls and waits on
	# _fallen for its carcass row; with no death clip it tips onto its side about its edge instead. A code-built body goes at once.
	var dying: Dictionary = body(v, 6, {"0": ["Idle", 4.0], "die": ["Death_Idle_R01_once", 1.5]})
	(dying["node"] as Node3D).position = Vector3(10.0, 0.0, 0.0)
	check(v._die(dying) and is_instance_valid(dying["node"]) and not (dying["node"] as Node3D).is_queued_for_deletion(), "a killed body with a death clip is still drawn as it falls")
	check(((dying["node"] as Node3D).get_meta("player") as AnimationPlayer).assigned_animation == "Death_Idle_R01_once", "and plays its death clip")
	plain["node"].position = Vector3(20.0, 0.0, 0.0)
	plain["node"].rotation.y = 0.7
	check(v._die(plain) and (plain["node"] as Node3D).get_parent().name == "Fallen", "with no death clip the body is kept, on a pivot that tips it over")
	var pivot: Node3D = (plain["node"] as Node3D).get_parent()
	check(absf(pivot.rotation.y - 0.7) < 0.001 and (pivot.global_position - Vector3(20.0, 0.0, 0.0)).length() < 0.25, "the pivot keeps its turn, at the edge of its feet (%s)" % str(pivot.global_position))
	check(((plain["node"] as Node3D).global_position - Vector3(20.0, 0.0, 0.0)).length() < 0.001, "and the body has not moved yet: no jump")
	var code_built: Node3D = Node3D.new()
	v.add_child(code_built)
	check(not v._die({"node": code_built, "kind": "deer"}), "a code-built body goes at once (its carcass row draws the old body)")
	var flat: Node3D = Node3D.new()
	v.add_child(flat)
	var flat_pivot: Node3D = v._tip_over(flat, 0.0)
	check(absf(flat_pivot.rotation.z + PI * 0.5) < 0.001 and absf((flat_pivot.global_transform * flat.transform * Vector3(0.0, 1.0, 0.0)).y - 0.2) < 0.001, "tipped at once: on its side, its top out sideways and its edge on the ground")

	# The carcass row takes the fallen body of its kind lying near it: the same node, not a second body. Far or another kind: not taken.
	var taken: Node3D = v.dead_body("deer", 6, 2, Vector3(10.5, 0.0, 0.3))
	check(taken != null, "a carcass row near the fallen deer is drawn")
	v.add_child(taken)
	check(is_instance_valid(dying["node"]) and (dying["node"] as Node3D).get_parent() == taken and ((dying["node"] as Node3D).global_position - Vector3(10.0, 0.0, 0.0)).length() < 0.001, "with the fallen body itself, where it fell")
	check(v._fallen.size() == 1, "and it is off the waiting list (the tipped one waits)")
	check(v._take_fallen("wolf", Vector3(20.0, 0.0, 0.0)) == null, "a carcass of another kind does not take it")

	# A dead body drawn fresh (walked back to): one with no death clip lies tipped on its side once in the tree, one with a clip in its
	# clip's pose; nothing is moved while its parent is adding children (Lane A at 840c6068: "Parent node is busy", the bodies stood).
	var fresh_plain: Dictionary = body(v, 11, {"0": ["Idle", 4.0]})
	var fresh_clip: Dictionary = body(v, 12, {"0": ["Idle", 4.0], "die": ["Death_Stand_R01_once", 1.7]})
	var fresh_roots: Array = []

	for fresh in [fresh_plain, fresh_clip]:
		v._bodies.erase(int(fresh["id"]))
		v.remove_child(fresh["node"])
		((fresh["node"] as Node3D).get_meta("player") as AnimationPlayer).play("Idle")
		var fresh_root: Node3D = Node3D.new()
		v._lay_dead(fresh_root, fresh["node"])
		v.add_child(fresh_root)
		fresh_roots.append(fresh_root)

	await process_frame
	var plain_node: Node3D = fresh_plain["node"]
	check(plain_node.get_parent() != null and plain_node.get_parent().name == "Fallen" and plain_node.get_parent().get_parent() == fresh_roots[0] and absf((plain_node.get_parent() as Node3D).rotation.z + PI * 0.5) < 0.001, "a fresh dead body with no death clip lies on its side under its row")
	check(not (plain_node.get_meta("player") as AnimationPlayer).is_playing(), "and its clip is stopped (no grazing dead body)")
	var clip_player: AnimationPlayer = (fresh_clip["node"] as Node3D).get_meta("player")
	check((fresh_clip["node"] as Node3D).get_parent() == fresh_roots[1] and clip_player.assigned_animation == "Death_Stand_R01_once", "one with a death clip lies in that clip's pose (%s)" % clip_player.assigned_animation)

	# The path the game and the shot runner take (Lane A at c2643634: the rig read the node's name, which repeats as DeadBody2 ...): a real
	# moose (no death clip) from its model file, where the file is there (not on a lane without the bought models).
	var moose_scene: String = str((v._model_rows().get("moose", {}) as Dictionary).get("scene", ""))
	var moose: Node3D = v.dead_body("moose", 5, 4, Vector3.INF)
	check(moose != null or not ResourceLoader.exists(moose_scene), "a carcass row of a kind with a model file is drawn as that model (%s)" % moose_scene)

	if moose != null:
		var other: Node3D = v.dead_body("moose", 6, 4, Vector3.INF)
		v.add_child(moose)
		v.add_child(other)
		await process_frame
		check(moose.has_meta("dead_body") and other.has_meta("dead_body") and moose.name != other.name, "each is marked as a dead body whatever its name (%s, %s)" % [moose.name, other.name])
		var moose_pivot: Node3D = moose.get_child(0) as Node3D
		check(moose_pivot != null and moose_pivot.name == "Fallen" and absf(moose_pivot.rotation.z + PI * 0.5) < 0.001, "the moose (no death clip) lies on its side")
		print("dead moose: side %.2f m" % v._side_m(moose_pivot.get_child(0)))
		moose.queue_free()
		other.queue_free()

	for fresh_root in fresh_roots:
		(fresh_root as Node3D).queue_free()

	# Its side is measured on its body and legs, not its antlers (Lane A at c2643634: the moose lay up in the air on its antlers).
	var antlered: Node3D = Node3D.new()
	var antler_rig: Node3D = Node3D.new()
	antler_rig.name = "Rig"
	antlered.add_child(antler_rig)
	var sk: Skeleton3D = Skeleton3D.new()
	antler_rig.add_child(sk)

	for bone in [["foot", Vector3(0.15, 0.0, 0.0)], ["back", Vector3(0.0, 1.2, 0.0)], ["antler", Vector3(0.9, 2.0, 0.0)]]:
		var at: int = sk.add_bone(str(bone[0]))
		sk.set_bone_rest(at, Transform3D(Basis(), bone[1]))
		sk.set_bone_pose_position(at, bone[1])

	v.add_child(antlered)
	var side: float = v._side_m(antlered)
	check(absf(side - (0.15 + 2.0 * AnimalViewScript.SIDE_SKIN_SHARE)) < 0.01, "a body's side is its legs and body plus its flesh, not its antlers (%.2f m)" % side)
	check(v._side_m(code_built) == 0.2, "a body with no rig: 0.2 m")
	antlered.queue_free()

	# A fallen body no carcass row takes: kept while the player is far, gone once they are near after DEAD_WAIT_S.
	v._t += AnimalViewScript.DEAD_WAIT_S + 0.1
	v._clear_fallen(Vector3(500.0, 0.0, 0.0))
	check(v._fallen.size() == 1, "kept while the player is far (no carcass rows reach there)")
	v._clear_fallen(Vector3(25.0, 0.0, 0.0))
	check(v._fallen.is_empty() and pivot.is_queued_for_deletion(), "gone when the player is near and no carcass came")
	taken.queue_free()

	# Through the rows: a lunge (7) ending plays the bite; a body killed by a hit leaves the rows but stays drawn while it falls.
	var lunger: Dictionary = body(v, 7, {"0": ["Idle", 4.0], "bite": ["Attack_BiteForward_once", 2.4]})
	lunger["state"] = 7
	v.on_rows([[7, 3, Vector3.ZERO, 0.0, 6, 1000]], 1000)
	check(lunger.has("once_until"), "a lunge ending (7 to 6) plays the bite")
	var shot: Dictionary = body(v, 8, {"0": ["Idle", 4.0], "die": ["Death_Stand_R01_once", 1.7]})
	shot["target"] = Vector3(40.0, 0.0, 40.0)
	var shot_node: Node3D = shot["node"]
	v.note_hit(Vector3(40.0, 0.0, 40.0))
	v.on_rows([[7, 3, Vector3.ZERO, 0.0, 6, 1100]], 1100)
	check(not v._bodies.has(8) and is_instance_valid(shot_node) and not shot_node.is_queued_for_deletion(), "a body killed by a hit leaves the rows and is still drawn as it falls")
	check(not v._bodies.has(4) and not v._bodies.has(1), "a body that walks out of the rows goes")

	# A close blow (Dave 23 Nov 2026: "not all animals charge"): a bear warning (10) that turns to a strike (25) plays its strike clip once,
	# sped so the blow (HIT_AT of the clip) lands at the bear's windup_s; the next strike is its second clip. No bite plays as it ends.
	var striker: Dictionary = body(v, 9, {"0": ["Idle", 4.0], "strike": ["Attack_MeleeLeft_once", 2.0], "strike2": ["Attack_SwingForward_once", 1.6], "bite": ["Attack_BiteForward_once", 2.4]})
	striker["state"] = 10
	striker["kind"] = "bear"
	var s_player: AnimationPlayer = (striker["node"] as Node3D).get_meta("player")
	var windup: float = AnimalViewScript.windup_s("bear", "strike")
	v.on_rows([[9, 14, Vector3.ZERO, 0.0, 25, 1200]], 1200)
	check(s_player.assigned_animation == "Attack_MeleeLeft_once" and absf(s_player.speed_scale - AnimalViewScript.HIT_AT * 2.0 / windup) < 0.001, "a strike plays the strike clip sped to land at %.2f s (%s at %.2f)" % [windup, s_player.assigned_animation, s_player.speed_scale])
	check(striker.has("once_until") and float(striker["once_until"]) - v._t <= 2.0 / s_player.speed_scale + 0.001, "and holds the state's clip off until it ends")
	striker.erase("once_until")
	v.on_rows([[9, 14, Vector3.ZERO, 0.0, 12, 1300]], 1300)
	check(not striker.has("once_until"), "a strike ending plays no bite")
	v.on_rows([[9, 14, Vector3.ZERO, 0.0, 25, 1400]], 1400)
	check(s_player.assigned_animation == "Attack_SwingForward_once", "the next strike is the second clip (%s)" % s_player.assigned_animation)
	check(absf(windup - 0.7) < 0.001 and absf(AnimalViewScript.windup_s("donkey", "kick") - 0.8) < 0.001, "the wind-ups come from animals.json (bear strike %.2f s, donkey kick %.2f s)" % [windup, AnimalViewScript.windup_s("donkey", "kick")])

	check(AnimalViewScript.plan_of([1, 2, Vector3.ZERO, 0.0, 1, 100, Vector3.ONE, Vector2(3.0, 4.0), 0.5]) == Vector2(3.0, 4.0) and AnimalViewScript.plan_of([1, 2, Vector3.ZERO, 0.0, 1, 100, 0.5]) == null, "a row's plan is the Vector2 after its six fields (protocol 168), none without one")

	# An older row out of order (dropped by push_row) leaves the newer plan on the body (protocol 168).
	var walker: Dictionary = body(v, 10, {"0": ["Idle", 4.0]})
	v.on_rows([[10, 2, Vector3.ZERO, 0.0, 0, 2000, Vector2(5.0, 5.0)]], 2000)
	v.on_rows([[10, 2, Vector3.ZERO, 0.0, 0, 1900, Vector2(1.0, 1.0)]], 2100)   # a newer batch (2100) with an older row time: drawn, the row dropped
	check(walker.get("plan", null) == Vector2(5.0, 5.0), "an older row out of order leaves the newer plan (%s)" % str(walker.get("plan", null)))

	v.queue_free()
	print("test_animal_once: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
