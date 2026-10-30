extends SceneTree

# Headless check and measurement for generated NPC bodies (Sonny, plan 13): seeds give the same genome every time, the mesh cache shares one mesh between bodies of the
# same type, the no-fingers level is lighter, npc_view.gd still compiles, and the time to make 20 NPC bodies (8 types, cached) is printed.
#   godot --headless --path . --script res://tools/check_npc_bodies.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_seeds()
	_check_cache_and_fingers()
	_check_twenty()
	_check_compiles()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _check_seeds() -> void:
	for s in range(40):
		var a: Dictionary = Generator.genome_from_seed(s)
		var b: Dictionary = Generator.genome_from_seed(s)
		_ok(a.hash() == b.hash(), "seed %d gives the same genome twice" % s)

		for key in Generator.SLIDERS:
			_ok(float(a[key]) >= -0.9 and float(a[key]) <= 0.9, "seed %d slider %s in range" % [s, key])

	_ok(Generator.genome_from_seed(1).hash() != Generator.genome_from_seed(2).hash(), "different seeds give different genomes")


func _check_cache_and_fingers() -> void:
	var g: Dictionary = Generator.genome_from_seed(5)
	var a: Dictionary = Generator.make_node(g, 0.05, true, true)
	var b: Dictionary = Generator.make_node(g, 0.05, true, true)
	_ok(not bool((a["built"] as Dictionary).get("from_cache", false)), "the first body of a type is built")
	_ok(bool((b["built"] as Dictionary).get("from_cache", false)), "the second body of the same type comes from the cache")
	_ok((a["skeleton"].get_node("Body") as MeshInstance3D).mesh == (b["skeleton"].get_node("Body") as MeshInstance3D).mesh, "the two bodies share one mesh")
	_ok((a["skeleton"].get_node("Body") as MeshInstance3D).skeleton == NodePath(".."), "the cached body still binds to its own skeleton")
	var with: Dictionary = Generator.build(g, 0.05, true)
	var without: Dictionary = Generator.build(g, 0.05, false)
	_ok(int(without["triangle_count"]) < int(with["triangle_count"]), "no fingers is lighter (%d vs %d triangles)" % [int(without["triangle_count"]), int(with["triangle_count"])])
	a["node"].free()
	b["node"].free()


func _check_twenty() -> void:
	var t0: int = Time.get_ticks_usec()
	var bodies: Array = []

	for i in range(20):
		var body: Node3D = GeneratedBody.new(Generator.genome_from_seed(i % 8), 0.045, false, true)
		root.add_child(body)
		bodies.append(body)

	var made_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var t1: int = Time.get_ticks_usec()
	var again: Array = []

	for i in range(20):
		var body2: Node3D = GeneratedBody.new(Generator.genome_from_seed(i % 8), 0.045, false, true)
		root.add_child(body2)
		again.append(body2)

	var cached_ms: float = float(Time.get_ticks_usec() - t1) / 1000.0
	print("20 NPC bodies, 8 types, 4.5 cm, no fingers: first 20 took %.0f ms (8 meshes built, 12 shared); the next 20 took %.0f ms (all cached)" % [made_ms, cached_ms])
	_ok(cached_ms < made_ms * 0.5, "cached bodies are much cheaper to make (%.0f ms vs %.0f ms)" % [cached_ms, made_ms])

	for body3 in bodies:
		var player: AnimationPlayer = (body3 as Node3D).get("animation_player")
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("walk")

	var t2: int = Time.get_ticks_usec()

	for _f in range(300):
		for body4 in bodies:
			((body4 as Node3D).get("animation_player") as AnimationPlayer).advance(1.0 / 60.0)

	print("animating those 20 bodies: %.3f ms per frame for all (headless, evaluation only)" % [float(Time.get_ticks_usec() - t2) / 1000.0 / 300.0])

	for b in bodies + again:
		(b as Node).queue_free()


func _check_compiles() -> void:
	var script: GDScript = load("res://src/client/npc_view.gd") as GDScript
	_ok(script != null and script.can_instantiate(), "src/client/npc_view.gd compiles")
