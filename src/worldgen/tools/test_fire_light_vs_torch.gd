extends SceneTree

# BUG-002: the large campfire must give at least 4 times the held torch's light OUTPUT (not 4 times its radius), reach further, flicker with its flame and be dark past its range.
# Godot's omni light at distance d: energy * (1 - (d / range)^4)^2 / d^attenuation (scene shader get_omni_attenuation). The torch and the fire are both shadowless omnis, so the ratio of any
# integral of that curve is independent of Godot's global light scale. Three comparisons, each with the torch's hand light added, against its mean energy and its flicker peak:
#   source intensity (energy at 1 m), flux through spheres round the light (what it emits), light delivered to flat ground under it (what lights terrain, trees and bushes).
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_light_vs_torch.gd

const BuildingLook := preload("res://src/client/building_look.gd")
const FlameRules := preload("res://src/shared/flame_rules.gd")

const TORCH_HEIGHT_M := 1.3        # the main light about at head-and-hand height
const HAND_HEIGHT_M := 0.9
const FIRE_HEIGHT_M := 0.8         # the fire's Light node position y in BuildingLook.fire
const STEPS := 4000

var failures: int = 0
var torch_range_m: float = 12.0     # items.json torch light_m, read in _init


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


# Light intensity at distance d of an omni with this energy, range and attenuation.
func omni(d: float, energy: float, range_m: float, attenuation: float) -> float:
	if d >= range_m:
		return 0.0

	var n: float = pow(d / range_m, 4.0)
	var w: float = (1.0 - n) * (1.0 - n)
	return energy * w * pow(maxf(d, 0.0001), -attenuation)


# Flux through spheres round the light: the integral of intensity over the sphere's area, summed out to the range.
func sphere_flux(energy: float, range_m: float, attenuation: float) -> float:
	var total: float = 0.0
	var step: float = range_m / float(STEPS)

	for i in STEPS:
		var d: float = (float(i) + 0.5) * step
		total += omni(d, energy, range_m, attenuation) * 4.0 * PI * d * d * step

	return total


# Light landing on flat ground below a light `height` up: intensity times the cosine of the angle of incidence, summed over the ground out to the range.
func ground_flux(energy: float, range_m: float, attenuation: float, height: float) -> float:
	var total: float = 0.0
	var reach: float = sqrt(maxf(range_m * range_m - height * height, 0.0))
	var step: float = reach / float(STEPS)

	for i in STEPS:
		var r: float = (float(i) + 0.5) * step
		var d: float = sqrt(r * r + height * height)
		total += omni(d, energy, range_m, attenuation) * (height / d) * 2.0 * PI * r * step

	return total


# The torch's light at `energy` (its mean FlameRules.TORCH_LIGHT_ENERGY, or its flicker peak) plus its hand light.
func torch_sphere(energy: float) -> float:
	return sphere_flux(energy, torch_range_m, FlameRules.TORCH_LIGHT_ATTENUATION) + sphere_flux(FlameRules.TORCH_HAND_ENERGY, FlameRules.TORCH_HAND_RANGE_M, FlameRules.TORCH_LIGHT_ATTENUATION)


func torch_ground(energy: float) -> float:
	return ground_flux(energy, torch_range_m, FlameRules.TORCH_LIGHT_ATTENUATION, TORCH_HEIGHT_M) + ground_flux(FlameRules.TORCH_HAND_ENERGY, FlameRules.TORCH_HAND_RANGE_M, FlameRules.TORCH_LIGHT_ATTENUATION, HAND_HEIGHT_M)


func _init() -> void:
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	torch_range_m = float(items["items"]["torch"]["light_m"])
	var peak: float = FlameRules.TORCH_LIGHT_ENERGY + FlameRules.TORCH_LIGHT_FLICKER
	var tier: Array = BuildingLook.FIRE_LIGHT[3]
	var fire_range: float = float(tier[0])
	var fire_energy: float = float(tier[1])
	var fire_atten: float = float(tier[2])

	# The data row agrees with the client table (the server does not read it for fires; the docs do).
	var row: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))["fire_tiers"]["log"]
	check(is_equal_approx(float(row["light_m"]), fire_range) and is_equal_approx(float(row["light_energy"]), fire_energy), "cooking.json fire_tiers.log light_m / light_energy equal FIRE_LIGHT[3]")

	# The old large fire (14 m, 4, attenuation 2) is the regression: it lit less than the torch.
	var old_sphere: float = sphere_flux(4.0, 14.0, 2.0) / torch_sphere(FlameRules.TORCH_LIGHT_ENERGY)
	check(old_sphere < 1.0, "the old large fire emitted %.2f of a torch: the bug" % old_sphere)

	# "Output" four times over, against the torch's mean and against its flicker peak (the torch's best case, hand light included). The ground measure depends on the lights' heights; it is
	# held too, so the larger fire lights the terrain, trees and bushes around it, not only the air.
	for torch_energy in [FlameRules.TORCH_LIGHT_ENERGY, peak]:
		var source: float = fire_energy / torch_energy
		var sphere: float = sphere_flux(fire_energy, fire_range, fire_atten) / torch_sphere(torch_energy)
		var ground: float = ground_flux(fire_energy, fire_range, fire_atten, FIRE_HEIGHT_M) / torch_ground(torch_energy)
		print("large fire / torch at energy %.1f: source x%.2f, emitted flux x%.2f, light on the ground x%.2f" % [torch_energy, source, sphere, ground])
		check(source >= 4.0, "torch %.1f: source intensity at least 4x (x%.2f)" % [torch_energy, source])
		check(sphere >= 4.0, "torch %.1f: emitted flux at least 4x (x%.2f)" % [torch_energy, sphere])
		check(ground >= 4.0, "torch %.1f: light delivered to the ground at least 4x (x%.2f)" % [torch_energy, ground])

	check(fire_range > torch_range_m, "the large fire reaches further than the torch (%.0f m against %.0f m)" % [fire_range, torch_range_m])
	check(fire_range / torch_range_m < 4.0, "and it is not a 4x radius fix (%.2fx)" % (fire_range / torch_range_m))

	# At every distance the large fire is brighter than the torch (main light), so no ring of the ground is darker than a torch lights it, and it is dark at its range.
	var brighter: bool = true

	for tenth in range(10, int(fire_range * 10.0) - 10):
		var d: float = float(tenth) * 0.1

		if d < torch_range_m and omni(d, fire_energy, fire_range, fire_atten) <= omni(d, FlameRules.TORCH_LIGHT_ENERGY, torch_range_m, FlameRules.TORCH_LIGHT_ATTENUATION):
			brighter = false

	check(brighter, "from 1 m out the large fire is brighter than the torch at every distance both reach")
	check(omni(fire_range, fire_energy, fire_range, fire_atten) == 0.0, "no light at its range: darkness beyond")
	check(omni(fire_range - 1.0, fire_energy, fire_range, fire_atten) < 0.05 * omni(2.0, fire_energy, fire_range, fire_atten), "a natural falloff: 1 m inside its range is under 5 % of the light at 2 m")

	# Medium and small fires are as they were; the tiers still step up in output.
	check(BuildingLook.FIRE_LIGHT[2] == [7.0, 2.0, 2.0] and BuildingLook.FIRE_LIGHT[1] == [3.5, 1.0, 2.0], "the small and medium fires are unchanged")
	check(sphere_flux(fire_energy, fire_range, fire_atten) > sphere_flux(2.0, 7.0, 2.0) and sphere_flux(2.0, 7.0, 2.0) > sphere_flux(1.0, 3.5, 2.0), "the tiers step up in output")

	# The built light carries the values and has no shadows (a shadow-casting omni is too dear at three fires on a GTX 1050).
	var fire: Node3D = BuildingLook.fire(true, false, 3)
	var light: OmniLight3D = fire.get_node("Light") as OmniLight3D
	check(is_equal_approx(light.omni_range, fire_range) and is_equal_approx(light.light_energy, fire_energy) and is_equal_approx(light.omni_attenuation, fire_atten), "the built large fire's light carries FIRE_LIGHT")
	check(not light.shadow_enabled, "no shadows on the fire light")
	check(light.has_meta("flame_flicker") and is_equal_approx(float(light.get_meta("base_energy")), fire_energy), "the large fire light is marked for the flame flicker with its base energy")
	fire.free()

	for small in [1, 2]:
		var other_fire: Node3D = BuildingLook.fire(true, false, small)
		check(not other_fire.get_node("Light").has_meta("flame_flicker"), "tier %d keeps the gentle flicker (BUG-002 is the large fire)" % small)
		other_fire.free()

	# The flame flicker: mean 1, never more than 15 % off, it moves (not a constant), and a different phase gives a different curve.
	var sum: float = 0.0
	var low: float = 9.0
	var high: float = 0.0
	var other: float = 0.0
	var samples: int = 20000

	for i in samples:
		var t: float = float(i) * 0.005
		var f: float = BuildingLook.flame_flicker(t, 0.0)
		sum += f
		low = minf(low, f)
		high = maxf(high, f)
		other += absf(f - BuildingLook.flame_flicker(t, 2.0))

	check(absf(sum / float(samples) - 1.0) < 0.02, "the flicker averages 1 (%.3f), so the fire is as bright as configured" % (sum / float(samples)))
	check(low >= 0.85 and high <= 1.15, "the flicker stays within 15 %% (%.3f to %.3f)" % [low, high])
	check(high - low > 0.15, "and it really moves (%.3f to %.3f)" % [low, high])
	check(other / float(samples) > 0.02, "two fires do not pulse together")
	var base: Color = BuildingLook.FIRE_LIGHT_COLOR[3]
	var warm: Color = BuildingLook.flame_flicker_color(base, 1.15)
	var cool: Color = BuildingLook.flame_flicker_color(base, 0.85)
	check(warm.g > base.g and cool.g < base.g and warm.r == base.r and cool.b == base.b, "brighter is a shade yellower, dimmer a shade redder, red and blue untouched")

	print("fire light vs torch: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
