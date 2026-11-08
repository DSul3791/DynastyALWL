extends SceneTree

# Swimmers (docs/design/ALLIGATOR_SWIMMING.md, Dave 8 Nov 2026): a species whose row has "water": {"swim": true} lives in fresh water
# and on the bank, rides the surface surface_sink_m low, and crosses water no other animal enters. A world: water west of x = 0
# (surface 9.5 m), a bank rising gently east of it and a lake bed falling west of it, marsh biome.
#   godot --headless --path . --script res://src/worldgen/tools/test_swimmers.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const Steering := preload("res://src/shared/steering.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(x, _z): return 9.5 + 0.05 * x      # the lake bed deepens westward, the bank rises eastward
	a.water_level = func(x, _z): return 9.5 if x < 0.0 else NAN
	a.blocked = func(x, _z): return x < 0.0
	a.biome_at = func(_x, _z): return "marsh"
	a.player_positions = func(): return [Vector3(200.0, 10.0, 0.0)]
	a.setup()
	a.traits = false

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0      # only what this test puts down

	return a


func _init() -> void:
	var a = make()
	var gator: Dictionary = a.species_def("alligator")
	var deer: Dictionary = a.species_def("deer")
	check(a.swims(gator), "the alligator row swims")
	check(not a.swims(deer), "the deer row does not swim")

	# Where it may live: water and the bank, never inland; a non-swimmer is unchanged.
	check(a._habitat_score(gator, -10.0, 0.0, 10.0) == 2.0, "water suits the alligator")
	check(a._habitat_score(gator, 3.0, 0.0, 10.0) == 1.0, "the bank (3 m from water) suits it")
	check(a._habitat_score(gator, 60.0, 0.0, 10.0) == -1.0, "60 m inland does not")
	check(a._habitat_score(deer, -10.0, 0.0, 10.0) != 2.0, "water never scores 2 for a deer")

	# Put down in water it rides the surface, surface_sink_m low.
	var id: int = a.spawn("alligator", -10.0, 0.0)
	check(id > 0, "an alligator can be put down in water")
	var sink: float = float(gator["water"].get("surface_sink_m", 0.25))
	check(id > 0 and absf(float(a.animals[id]["pos"].y) - (9.5 - sink)) < 0.001, "it sits at the water surface less %.2f m (y %.2f)" % [sink, float(a.animals[id]["pos"].y) if id > 0 else NAN])

	# It walks from the bank into the water (nothing blocks it), and the water blocks a deer the same way it always did.
	var ground_for: Callable = func(x: float, z: float) -> float: return a.swim_height(gator, x, z)
	var pos: Vector3 = Vector3(2.0, 9.6, 0.0)

	for _n in 200:
		var r: Dictionary = Steering.step(pos, Vector3(-8.0, 0.0, 0.0), 2.0, 0.05, ground_for, Callable(), 0.4, PI)

		if not r["moved"]:
			break

		pos = r["pos"]

	check(pos.x < -5.0, "the alligator swims out from the bank (x %.1f)" % pos.x)
	check(absf(pos.y - (9.5 - sink)) < 0.001, "in the water it rides the surface (y %.2f)" % pos.y)
	var deer_r: Dictionary = Steering.step(Vector3(0.5, 9.525, 0.0), Vector3(-8.0, 0.0, 0.0), 2.0, 0.5, a.ground_height, a.blocked, 0.4, PI)
	check(not deer_r["moved"] or float(deer_r["pos"].x) >= 0.0, "a deer still cannot step into deep water")

	# Beaver, goose and moose swim too; the moose and goose keep their land habitat (lives_on_land), the beaver stays near the bank.
	for sp in ["beaver", "goose", "moose"]:
		check(a.swims(a.species_def(sp)), "%s swims" % sp)

	check(a._habitat_score(a.species_def("beaver"), 60.0, 0.0, 10.0) == -1.0, "a beaver never lives 60 m from water")
	check(a._habitat_score(a.species_def("moose"), -10.0, 0.0, 10.0) == 1.0, "water is open to a moose (score 1)")
	check(a._habitat_score(a.species_def("moose"), 60.0, 0.0, 10.0) != -1.0 or not a.swims(a.species_def("moose")), "a moose still lives inland by its own rules")

	print("swimmers: %d checks failed" % failures)
	print("Test done: ", "FAIL" if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)
