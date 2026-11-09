extends SceneTree

# The liquid sheet's chunk image (Sonny, 2 Nov 2026; written without being run).
#   godot --headless --path . --script res://src/worldgen/tools/test_liquid_surface.gd

const LiquidSurface := preload("res://src/water2/liquid_surface.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# A 5 x 5 chunk grid: a pond at 10 m on the middle 3 x 3, a shore point at (0, 2), the rest dry.
	var count: int = 5
	var levels: PackedFloat32Array = PackedFloat32Array()
	levels.resize(count * count)
	levels.fill(NAN)
	var edge: PackedFloat32Array = PackedFloat32Array()
	edge.resize(count * count)
	edge.fill(NAN)
	var vel: PackedFloat32Array = PackedFloat32Array()
	vel.resize(count * count * 2)

	for j in range(1, 4):
		for i in range(1, 4):
			levels[j * count + i] = 10.0

	edge[2 * count + 0] = 10.2
	vel[(2 * count + 2) * 2] = 0.5
	var grid: Dictionary = {"count": count, "spacing": 8.0, "levels": levels, "wet": 9, "edge": edge, "vel": vel}
	var im: Image = LiquidSurface.image_from_grid(grid)
	_check(im != null and im.get_width() == count and im.get_format() == Image.FORMAT_RGBAF, "a wet chunk gives a count x count float image")

	if im != null:
		var middle: Color = im.get_pixel(2, 2)
		_check(is_equal_approx(middle.r, 10.0) and is_equal_approx(middle.a, LiquidSurface.OPEN_DEPTH_M), "the pond's middle: its level, open depth")
		_check(is_equal_approx(middle.g, 0.5), "the current is carried")
		_check(is_equal_approx(im.get_pixel(1, 1).a, LiquidSurface.SHORE_DEPTH_M), "a wet point next to dry ground is shallow")
		_check(is_equal_approx(im.get_pixel(0, 2).r, 10.2) and im.get_pixel(0, 2).a == 0.0, "a shore point keeps its own level, depth 0")
		_check(im.get_pixel(4, 4).a == 0.0 and im.get_pixel(4, 4).r < 10.0, "a dry point by the pond tucks under its level")

	_check(LiquidSurface.image_from_grid({"count": count, "spacing": 8.0, "levels": levels, "wet": 0}) == null, "a dry chunk gives no image")
	_check_blend_band()
	print("liquid surface test: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _shader_part(source: String, start: String) -> String:
	# A Windows checkout (git's text=auto) gives the shader text CRLF line ends:
	# compare the text, not the line ends.
	var code: String = source.replace("\r\n", "\n")
	var at: int = code.find(start)

	if at < 0:
		return ""

	return code.substr(at, code.find("\n}\n", at) + 3 - at)


# BUG-006 (Dave's QA list, 3 Nov 2026): the live window and the water around it crossfade over one band. Both shaders must work the band out the
# same way, or the two shares stop adding up and a line shows again.
func _check_blend_band() -> void:
	for part in ["float blend_hash(", "float live_blend("]:
		var a: String = _shader_part(LiquidSurface.SHADER, part)
		_check(a != "" and a == _shader_part(WaterMaterial.SHADER, part), "%s...) is the same text in liquid_surface.gd and water_material.gd" % part)

	# The band's width and wander are uniforms in both shaders and must be the same numbers (#465 widened it to 64 and 24 in liquid_surface.gd only).
	for line in ["uniform float blend_m = 64.0;", "uniform float blend_wander_m = 24.0;"]:
		_check(LiquidSurface.SHADER.contains(line) and WaterMaterial.SHADER.contains(line), "both shaders: " + line)

	_check(not LiquidSurface.SHADER.contains("< hole.z - hole_inset"), "a chunk sheet no longer stops on a straight line one cell into the window")
