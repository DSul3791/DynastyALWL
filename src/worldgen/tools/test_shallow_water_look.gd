extends SceneTree

# Shallow water reads as water (Dave's play-test, 24 Nov 2026, a reedy river at x 57864 z 71571 on Medium: "the graphical glitch in the river
# where it looks like I can see right under the water", "it shouldnt look like that"). The surface's body over its bed is
# mix(edge_alpha, 0.97, 1 - exp(-through / clarity_m)) (water_material.gd): with edge_alpha 0.34 and clarity_m 1.1 a 10 cm film was 37 %
# water colour and 30 cm was 49 %, so seen from above the bed showed almost untinted. Now at least half is water colour, and the bed shows
# softly. And one drink prompt: the look label named the water and repeated "Press E to drink" under the drink prompt itself.
#   godot --headless --path . --script res://src/worldgen/tools/test_shallow_water_look.gd

const WaterMaterial := preload("res://src/client/water_material.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func uniform_default(name: String) -> float:
	var at: int = WaterMaterial.SHADER.find("uniform float %s = " % name)

	if at < 0:
		return NAN

	var start: int = at + ("uniform float %s = " % name).length()
	return WaterMaterial.SHADER.substr(start, WaterMaterial.SHADER.find(";", start) - start).to_float()


# The body's share of water colour over the bed, for `through` metres of water along the look (water_material.gd body_alpha, clear water).
func body(through: float) -> float:
	var murk: float = 1.0 - exp(-through / uniform_default("clarity_m"))
	return lerpf(uniform_default("edge_alpha"), 0.97, murk)


func _init() -> void:
	check(WaterMaterial.SHADER.contains("float body_alpha = max(mix(edge_alpha, 0.97, murk), face * 0.85);") and WaterMaterial.SHADER.contains("float murk = 1.0 - exp(-through / (clarity_m"), "the shader still mixes water colour over the bed as this test reckons it")

	for row in [[0.05, 0.5, 0.6], [0.1, 0.5, 0.65], [0.3, 0.6, 0.8], [0.8, 0.75, 0.9]]:
		var b: float = body(float(row[0]))
		check(b >= float(row[1]) and b <= float(row[2]), "%.2f m of water along the look: %.0f %% water colour over the bed (between %.0f and %.0f)" % [float(row[0]), b * 100.0, float(row[1]) * 100.0, float(row[2]) * 100.0])

	check(body(3.0) > 0.95, "deep water hides its bed (%.0f %%)" % (body(3.0) * 100.0))

	var client: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(not client.contains("\"Water — Press E to drink\"") and client.contains("return {\"prompt\": \"Press E to drink\", \"tap\": items.drink}"), "looking at water names it once; the drink prompt alone says what E does")

	print("test_shallow_water_look: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
