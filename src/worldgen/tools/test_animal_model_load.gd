extends SceneTree

# The first animal of a kind waits, undrawn, while its model loads on a worker (Lane A route plays, 23 Nov 2026: the first moose,
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

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCENE))
	print("test_animal_model_load: %d failures" % failures)
	quit(1 if failures > 0 else 0)
