extends SceneTree

# Worn earth (TR-14, data/look/worn_earth.json): a run or deer trail across ground with no meadow turf is drawn by the ground shader as
# bared, packed soil, from the grass's own run map; off until the first routes are laid round the player, off with the trails switch.
#   godot --headless --path . --script res://src/worldgen/tools/test_worn_earth.gd

const GroundMaterial := preload("res://src/client/ground_material.gd")
const GrassViewScript := preload("res://src/client/grass_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var code: String = GroundMaterial.SHADER
	check(code.find("uniform sampler2D run_map") >= 0 and code.find("uniform vec4 worn_earth = vec4(0.0,") >= 0, "the ground shader reads the run map, off until bound")
	check(code.find("(1.0 - lw[0] * cover)") >= 0 and code.find("(1.0 - lying)") >= 0, "worn earth only off the meadow turf and not under lying snow")
	check(code.find("if (worn_earth.x > 0.5 && dist < worn_earth.y)") >= 0, "one run map read, only near the eye")

	var cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/look/worn_earth.json"))
	check(typeof(cfg) == TYPE_DICTIONARY and float(cfg.get("draw_m", 0.0)) > 0.0 and (cfg.get("soil_color", []) as Array).size() == 3, "the data file has draw_m and a soil colour")

	var shader: Shader = Shader.new()
	shader.code = code
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	var view = GrassViewScript.new()
	check(not view.has_runs(), "no routes yet: not bound (nothing in the first-join window)")
	view.set_ground_material(mat)
	var on: Variant = mat.get_shader_parameter("worn_earth")
	check(on is Vector4 and is_equal_approx((on as Vector4).x, 1.0) and is_equal_approx((on as Vector4).y, float(cfg["draw_m"])), "bound: on, drawn within draw_m (%s)" % str(on))
	var soil: Variant = mat.get_shader_parameter("worn_soil")
	check(soil is Vector4 and is_equal_approx((soil as Vector4).x, float(cfg["soil_color"][0])) and is_equal_approx((soil as Vector4).w, float(cfg["smooth"])), "the soil colour and smoothing from the data file")
	check(is_equal_approx(float(mat.get_shader_parameter("run_size")), float(GrassViewScript.RUN_TEXELS) * GrassViewScript.RUN_TEXEL_M), "the run map's size is the grass's")
	view.set_trails_on(false)
	check(is_zero_approx((mat.get_shader_parameter("worn_earth") as Vector4).x), "the trails switch turns the worn earth off too")

	var puddles_src: String = FileAccess.get_file_as_string("res://src/client/puddles.gd")
	check(puddles_src.find("_client.grass.has_runs()") >= 0 and puddles_src.find("_client.grass.set_ground_material(material)") >= 0, "the ground material is handed over once the runs are laid")

	view.free()
	print("test_worn_earth: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
