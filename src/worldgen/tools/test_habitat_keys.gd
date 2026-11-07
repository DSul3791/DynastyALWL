extends SceneTree

# The guiding document's optional habitat keys (altitude_m, slope_deg, rock, water_kind, cave, canopy, sea_depth_m, sky, lair,
# season; MikeW 7 Nov 2026) are accepted in animals.json and change nothing yet: every species, given all of them, scores every
# spot and weighs every biome exactly as before.
#   godot --headless --path . --script res://src/worldgen/tools/test_habitat_keys.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(with_keys: bool):
	var a = AnimalsScript.new()
	a.ground_height = func(x, z): return 10.0 + 0.3 * sin(x * 0.05) * 20.0 + 0.01 * z
	a.blocked = func(x, _z): return x > 400.0 and x < 420.0
	a.water_level = func(_x, _z): return 9.0
	a.biome_at = func(x, z): return ["temperate_forest", "alpine_meadow", "marsh", "bare_rock", "temperate_grassland"][int(absf(x + z) / 50.0) % 5]
	a.player_positions = func(): return [Vector3.ZERO]
	a.setup()

	if with_keys:
		for sp in a.cfg["species"]:
			var def: Dictionary = a.cfg["species"][sp]
			var hab: Dictionary = def.get("habitat", {})
			hab.merge({"altitude_m": [0, 3000], "slope_deg": [0, 90], "rock": true, "water_kind": "river", "cave": false, "canopy": "under", "sea_depth_m": [0, 10], "sky": false, "lair": "den", "season": ["breed"]})
			def["habitat"] = hab

	return a


func _init() -> void:
	var plain = make(false)
	var keyed = make(true)
	check(AnimalsScript.HABITAT_KEYS_LATER.size() == 10, "ten optional habitat keys are listed")
	var compared: int = 0

	for sp in plain.cfg["species"]:
		var d0: Dictionary = plain.cfg["species"][sp]
		var d1: Dictionary = keyed.cfg["species"][sp]

		for i in 40:
			var x: float = float(i * 37 % 600) - 100.0
			var z: float = float(i * 53 % 500) - 200.0
			compared += 1

			if plain._habitat_score(d0, x, z, 10.0) != keyed._habitat_score(d1, x, z, 10.0) or plain.biome_weight(d0, x, z) != keyed.biome_weight(d1, x, z):
				check(false, "%s scores %.1f, %.1f the same with the new keys" % [sp, x, z])
				break

	print("habitat keys: %d spots compared over %d species" % [compared, plain.cfg["species"].size()])
	check(compared > 1000, "every species was compared")
	print("Test done: ", "FAIL" if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)
