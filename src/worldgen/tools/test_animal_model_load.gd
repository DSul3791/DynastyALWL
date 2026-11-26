extends SceneTree

# The first animal of a kind waits, undrawn, while its model loads on a worker, at most SCENE_WAIT_MS (QA #12) (Lane A route plays, 23 Nov 2026: the first moose,
# black bear, horse or wildebeest drawn was a 0.6 to 1.4 s freeze, load() reading the model on the main thread). The files it waits
# for are the scenes of its row, variants and young model and their colour textures. A headless client (robots, tests) loads as
# before, on the main thread, because the dummy renderer's stores are not thread safe (test_worker_resources); the worker load itself
# is checked on a drawn client (Lane A).
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_model_load.gd

const AnimalViewScript := preload("res://src/client/animal_view.gd")
const SCENE := "user://test_animal_model_load.tscn"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	# A model file of its own: a box on a Node3D, saved where ResourceLoader finds it.
	var model: Node3D = Node3D.new()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	model.add_child(mesh)
	mesh.owner = model
	var packed: PackedScene = PackedScene.new()
	packed.pack(model)
	model.free()
	check(ResourceSaver.save(packed, SCENE) == OK, "the test model is saved")
	packed = null

	var v = AnimalViewScript.new()
	root.add_child(v)
	await process_frame
	v.set_process(false)
	v._models = {"deer": {"scene": SCENE, "length_m": 1.8, "materials": [{"match": "", "albedo": "res://no/such/texture.png"}]}, "wolf": {"scene": "res://no/such/wolf.tscn"}}

	check(v._species_scenes(2) == PackedStringArray([SCENE]), "the deer's model files are its scene (a texture that does not exist is left out): %s" % str(v._species_scenes(2)))
	check(v._species_scenes(3).is_empty(), "a model row whose file does not exist has no files to load")

	v._models["deer"]["variants"] = [{"scene": "res://no/such/doe.tscn"}, {"scene": SCENE}]      # ids 1 and 3 take the second
	v._models["deer"]["young_model"] = {"scene": "res://no/such/fawn.tscn", "materials": [{"albedo": SCENE}]}
	v._scenes_of.clear()
	check(v._species_scenes(2) == PackedStringArray([SCENE]), "variants, young model and their textures are looked at, each file once")

	# Headless: no worker load; the deer is drawn from its model at once, and the wolf from the code-built body.
	v.on_rows([[1, 2, Vector3.ZERO, 0.0, 0, 1000], [2, 3, Vector3(5.0, 0.0, 0.0), 0.0, 0, 1000]], 1000)
	check(v._bodies.has(1) and bool((v._bodies[1]["node"] as Node3D).get_meta("model", false)), "headless, the first deer is drawn from its model at once")
	check(v._bodies.has(2) and not bool((v._bodies[2]["node"] as Node3D).get_meta("model", false)), "a wolf with no model file is drawn from the code-built body")
	check(ResourceLoader.load_threaded_get_status(SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "headless, nothing is asked of a worker")

	# The box of a clip is kept per model file, model transform and clip: a second body of the file gets the first one's box.
	var rig_a: Node3D = ((v._bodies[1]["node"] as Node3D).get_node("Rig") as Node3D)
	v._clip_box(null, null, rig_a)   # the imported pose (no clip; the test model has no skeleton)
	var memo_key: String = v._box_key(null, rig_a)
	check(memo_key != "" and v._box_memo.has(memo_key), "a clip's box is kept under its model file and transform")
	v._box_memo[memo_key] = AABB(Vector3.ONE, Vector3.ONE)   # marked: a box worked out again would not be this one
	check(v._clip_box(null, null, rig_a) == AABB(Vector3.ONE, Vector3.ONE), "the kept box is given again, not worked out again")
	(rig_a.get_child(0) as Node3D).scale *= 2.0
	check(v._box_key(null, rig_a) != memo_key, "a model drawn at another size keeps its own box")
	(rig_a.get_child(0) as Node3D).scale /= 2.0
	v._box_memo.clear()
	var bare_rig: Node3D = Node3D.new()
	check(v._box_key(null, bare_rig) == "", "a rig with no model file keeps no box")
	bare_rig.free()

	# A colour texture's alpha test runs on a worker (_alpha_ready): false until the answer is in, then the answer _has_alpha would give.
	var see_through: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	see_through.fill(Color(1.0, 1.0, 1.0, 0.0))
	var solid: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	solid.fill(Color(0.5, 0.4, 0.3, 1.0))
	check(not v._alpha_ready("res://see_through.png", see_through), "the first ask for a texture's alpha starts the worker and waits")
	var asks: int = 1

	while not (v._alpha_ready("res://see_through.png", see_through) and v._alpha_ready("res://solid.png", solid)) and asks < 600:
		await process_frame
		asks += 1

	check(v._alpha_of.get("res://see_through.png", false) == true, "a see-through texture is found see-through (%d asks)" % asks)
	check(v._alpha_of.get("res://solid.png", true) == false, "a solid texture is found solid")
	check(v._alpha_tasks.is_empty() and v._alpha_done.is_empty(), "no worker task or answer is left over")
	check(v._alpha_ready("res://solid.png", null), "an answer in hand is not asked again (no texture needed)")

	# QA #12 (a tester on a slow PC saw no animals): a kind held for its files is drawn anyway after SCENE_WAIT_MS, with the code-built body.
	var clock: Array = [5000]
	v.clock_ms = func() -> int: return int(clock[0])
	check(not v._waited_out(2), "the first hold starts the wait")
	clock[0] = 5000 + v.SCENE_WAIT_MS - 1
	check(not v._waited_out(2), "still held just short of the limit")
	clock[0] = 5000 + v.SCENE_WAIT_MS
	check(v._waited_out(2), "drawn anyway at the limit")
	check(v._model_notes.keys().any(func(k): return str(k).contains("still loading after")), "the log says so once for the kind")
	v._wait_since.erase(2)
	check(not v._waited_out(2), "a kind whose files came in starts a fresh wait the next time it is held")
	v._code_body_only = true
	var stand_in: Node3D = v._make_for_species(2, 9)
	v._code_body_only = false
	check(stand_in != null and not bool(stand_in.get_meta("model", false)), "past the limit the deer is the code-built body, with no model load")
	if stand_in != null:
		stand_in.free()
	check(v._scenes_ready(2), "headless, a kind's files count as in, so the wait never starts there")

	# Through on_rows (files_ready stands in for _scenes_ready, which headless always answers yes): a deer held while its files load,
	# drawn with the code-built body once SCENE_WAIT_MS has passed, and the next deer drawn from its model once the files are in.
	var loaded: Array = [false]
	v.files_ready = func(_number: int) -> bool: return bool(loaded[0])
	v._wait_since.clear()
	clock[0] = 100000
	v.on_rows([[31, 2, Vector3(2.0, 0.0, 2.0), 0.0, 0, 1000]], 1000)
	check(not v._bodies.has(31), "a deer whose files are loading is held undrawn")
	clock[0] = 100000 + v.SCENE_WAIT_MS
	v.on_rows([[31, 2, Vector3(2.0, 0.0, 2.0), 0.0, 0, 1250]], 1250)
	check(v._bodies.has(31) and not bool((v._bodies[31]["node"] as Node3D).get_meta("model", false)), "past the limit it is drawn, with the code-built body")
	check(not v._code_body_only, "the code-built flag is down again after the body is made")
	loaded[0] = true
	v.on_rows([[31, 2, Vector3(2.0, 0.0, 2.0), 0.0, 0, 1500], [33, 2, Vector3(4.0, 0.0, 2.0), 0.0, 0, 1500]], 1500)   # an odd id: the variant with the test model (an even one takes the doe file that does not exist)
	check(v._bodies.has(33) and bool((v._bodies[33]["node"] as Node3D).get_meta("model", false)), "with its files in, the next deer is drawn from its model")
	v.files_ready = Callable()

	# Feet on the ground (Lane A 26 Nov 2026: 44 of 57 looks floated): a look's "ground_m" moves its body down by that much, and a clip in
	# "ground_clips" is moved by its own amount, found by its name after the armature.
	v._models["deer"].erase("variants")
	v._models["deer"].erase("ground_m")
	var plain: Node3D = v._make_model(2, 1)
	v._models["deer"]["ground_m"] = -0.25
	var grounded: Node3D = v._make_model(2, 1)
	var drop: float = ((grounded.get_node("Rig") as Node3D).get_child(0) as Node3D).position.y - ((plain.get_node("Rig") as Node3D).get_child(0) as Node3D).position.y
	check(absf(drop + 0.25) < 0.0001, "a look's ground_m moves its body down that much (%.3f m)" % drop)
	var young_row: Dictionary = (v._models["deer"] as Dictionary).duplicate(true)
	young_row.erase("ground_m")
	v._models["deer"]["young_model"] = young_row
	var young: Node3D = v._make_model(2, 1, true)
	var young_drop: float = ((young.get_node("Rig") as Node3D).get_child(0) as Node3D).position.y - ((plain.get_node("Rig") as Node3D).get_child(0) as Node3D).position.y
	check(absf(young_drop) < 0.0001, "a young model without its own ground_m is not moved by the adult's (%.3f m)" % young_drop)
	young_row["ground_m"] = -0.1
	var young_own: Node3D = v._make_model(2, 1, true)
	var own_drop: float = ((young_own.get_node("Rig") as Node3D).get_child(0) as Node3D).position.y - ((plain.get_node("Rig") as Node3D).get_child(0) as Node3D).position.y
	check(absf(own_drop + 0.1) < 0.0001, "a young model's own ground_m moves it (%.3f m)" % own_drop)
	v._models["deer"].erase("young_model")
	young.free()
	young_own.free()
	plain.free()
	grounded.free()
	check(is_equal_approx(AnimalViewScript.ground_lift({"WalkMedium_F": 0.049}, "Armature|WalkMedium_F"), 0.049) and AnimalViewScript.ground_lift({"WalkMedium_F": 0.049}, "Armature|Idle") == 0.0, "a clip's own ground move is found by its name after the armature, 0 for any other")
	var rows: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/models.json")) as Dictionary).get("species", {})   # the real rows, not this test's
	var missing: Array = []

	for kind in rows:
		var row: Dictionary = rows[kind]

		if row.has("height_m") or row.has("flock_of") or not ResourceLoader.exists(str(row.get("scene", ""))):
			continue   # sized by a rolled height (goblins: within 3 cm), a flock, or a model this machine lacks (the alligator's file)

		for look in (row.get("variants", []) as Array) if row.has("variants") else [row]:
			if bool((look as Dictionary).get("wild", true)) and not (look as Dictionary).has("ground_m"):
				missing.append(kind)

	check(missing.is_empty(), "every model look has its measured ground_m (missing: %s): run tools/ground_check.gd and tools/ground_offsets.py for a new model" % str(missing))

	# The animals line for the log (QA #12): it runs with bodies drawn and with none, and starts its counts again.
	v._report_batches = 3
	v._report_held = 2
	v._report(Vector3(1.0, 0.0, 1.0))
	check(v._report_batches == 0 and v._report_held == 0, "the animals line starts its counts again")
	var empty = AnimalViewScript.new()
	empty._report(Vector3.INF)
	empty.free()
	check(true, "the animals line with no bodies and no player does not stop the game")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE))
	print("test_animal_model_load: %d failures" % failures)
	quit(1 if failures > 0 else 0)
