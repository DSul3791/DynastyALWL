extends SceneTree

# The local player's feet stay in view in third person: the grass shader lowers blades within PLAYER_CLEAR_M of the player and _push_player hands it the player's spot.
#   godot --headless --path . --script res://src/worldgen/tools/test_player_clear.gd

const GrassScript := preload("res://src/client/grass_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var shader: Shader = Shader.new()
	shader.code = GrassScript.SHADER
	var names: Array = []

	for u in shader.get_shader_uniform_list():
		names.append(str(u["name"]))

	check(names.has("player_clear"), "the grass shader has the player_clear uniform")
	check(GrassScript.PLAYER_CLEAR_M >= 1.0 and GrassScript.PLAYER_CLEAR_M <= 3.0, "clear radius is 1 to 3 m")
	check(GrassScript.PLAYER_KEEP > 0.0 and GrassScript.PLAYER_KEEP < 0.5, "the player's patch keeps a low stubble (0 to 0.5 of the height)")
	var grass = GrassScript.new()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	grass._materials.append(material)
	grass.third_person = true      # the cut round the feet only exists in third person (Dave 2 Nov QA: a carpet in first person)
	grass._push_player(Vector3(12.0, 3.0, 34.0))
	var v: Vector4 = material.get_shader_parameter("player_clear")
	check(is_equal_approx(v.x, 12.0) and is_equal_approx(v.y, 34.0), "the shader gets the player's x and z")
	check(is_equal_approx(v.z, GrassScript.PLAYER_CLEAR_M) and is_equal_approx(v.w, GrassScript.PLAYER_KEEP), "the shader gets the radius and the share kept")
	grass.third_person = false
	grass._push_player(Vector3(12.0, 3.0, 34.0))
	var first: Vector4 = material.get_shader_parameter("player_clear")
	check(is_equal_approx(first.z, 0.0), "in first person the radius is 0 (the grass stays whole)")
	print("test_player_clear: ", "FAIL" if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
