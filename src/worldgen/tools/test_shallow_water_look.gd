extends SceneTree

# Shallow water reads as water (Dave's play-test, 24 Nov 2026, a reedy river at x 57864 z 71571 on Medium: "the graphical glitch in the river
# where it looks like I can see right under the water", "it shouldnt look like that"). Rivers, lakes and ponds are drawn by the liquid sheet
# (src/water2/liquid_surface.gd; flora_view LIQUID_CHUNKS). Its alpha was multiplied by a contact fade over the first 0.35 m of water along the
# view ray, meant for a bank; looking down on a shallow reach that ray is short, so the near water came out about 15 percent water colour and
# the bed showed almost bare, while far water, seen at a low angle, drew blue. Here the shader's own lines are checked and its numbers worked
# out as the shader does. And one drink prompt: the look label also said "Press E to drink" under the drink prompt.
#   godot --headless --path . --script res://src/worldgen/tools/test_shallow_water_look.gd

const LiquidSurface := preload("res://src/water2/liquid_surface.gd")

const CONTACT_LINE := "float contact = max(smoothstep(0.0, contact_m, through), smoothstep(0.03, 0.12, depth) * (1.0 - point_grid));"
const ALPHA_LINE := "ALPHA = clamp(max(max(0.45 + 0.5 * thick, running), max(foam, fall * 0.85)), 0.0, 1.0) * shore * edge * contact;"
const THICK_LINE := "float thick = 1.0 - exp(-min(through, depth * 3.0 + 0.2) / (clear_m * (1.0 - 0.6 * look_v2 * mud_here)));"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func uniform_default(name: String) -> float:
	var key: String = "uniform float %s = " % name
	var at: int = LiquidSurface.SHADER.find(key)
	return NAN if at < 0 else LiquidSurface.SHADER.substr(at + key.length(), LiquidSurface.SHADER.find(";", at) - at - key.length()).to_float()


# Still, clear water `depth` deep seen at `down` degrees below the level (through = depth / sin): the sheet's alpha as the shader works it out,
# away from a shore and a window edge (shore, edge 1). contact_rule: the live window (its depth is the water's own); false: a chunk sheet.
func still_alpha(depth: float, down: float, contact_rule: bool) -> float:
	var through: float = depth / sin(deg_to_rad(down))
	var thick: float = 1.0 - exp(-minf(through, depth * 3.0 + 0.2) / uniform_default("clear_m"))
	var contact: float = smoothstep(0.0, uniform_default("contact_m"), through)

	if contact_rule:
		contact = maxf(contact, smoothstep(0.03, 0.12, depth))

	return clampf(0.45 + 0.5 * thick, 0.0, 1.0) * contact


func _init() -> void:
	var shader: String = LiquidSurface.SHADER
	check(shader.contains(CONTACT_LINE) and shader.contains(ALPHA_LINE) and shader.contains(THICK_LINE), "the liquid sheet's contact, alpha and thickness lines are the ones worked out here")
	check(shader.contains("EMISSION = (foam_tint * foam * 0.15 + water * (1.0 - foam) * 0.2) * daylight;"), "the body gives a little of its own colour, so thin water over a brown bed does not read grey")

	# Dave's view: standing in it, eye 1.7 m up, the near water 2 to 6 m off: 20 to 60 degrees down.
	for row in [[0.1, 60.0, 0.4], [0.15, 40.0, 0.5], [0.3, 60.0, 0.55], [0.3, 25.0, 0.6]]:
		var now: float = still_alpha(float(row[0]), float(row[1]), true)
		check(now >= float(row[2]), "%.2f m of still water seen %d degrees down: %.0f %% water colour over the bed (at least %.0f)" % [float(row[0]), int(row[1]), now * 100.0, float(row[2]) * 100.0])

	check(still_alpha(0.03, 60.0, true) < 0.3, "a 3 cm film at the bank still fades into the ground (%.0f %%): no hard line" % (still_alpha(0.03, 60.0, true) * 100.0))
	check(still_alpha(0.3, 60.0, false) < still_alpha(0.3, 60.0, true) and still_alpha(1.0, 80.0, false) > 0.7, "a chunk sheet (its depth a stand-in) keeps the bank fade as before: a 0.3 m stand-in at the shore seen from above %.0f %%, a 1 m inside %.0f %%" % [still_alpha(0.3, 60.0, false) * 100.0, still_alpha(1.0, 80.0, false) * 100.0])
	check(still_alpha(2.0, 30.0, true) > 0.9, "deep water hides its bed (%.0f %%)" % (still_alpha(2.0, 30.0, true) * 100.0))

	var client: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(not client.contains("\"Water — Press E to drink\"") and client.contains("return {\"prompt\": \"Press E to drink\", \"tap\": items.drink}"), "looking at water names it once; the drink prompt alone says what E does")

	print("test_shallow_water_look: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
