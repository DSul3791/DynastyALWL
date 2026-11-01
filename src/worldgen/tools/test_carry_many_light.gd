extends SceneTree

# Picking many light things one at a time, or in handfuls, can never push the pack past the carry limit
# (float drift, tiny weights, a zero weight), and a stack of the lightest item is still bounded.
#   godot --headless --path . --script res://src/worldgen/tools/test_carry_many_light.gd

const CarryRules := preload("res://src/shared/carry_rules.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var cfg: Dictionary = CarryRules.load_config()
	var body: float = 75.0
	var cap: float = CarryRules.cap_kg(body, cfg)

	for id in ["fibre", "plant_fibre", "fiddleheads", "thatch", "juniper_berries", "petals", "stone", "unlisted_thing"]:
		for chunk in [1, 3, 7, 50]:
			var carried: float = 0.0
			var each: float = CarryRules.weight_of(id, cfg)
			var guard: int = 0

			while guard < 200000:
				guard += 1
				var fit: int = CarryRules.fit_count(id, chunk, carried, body, cfg)

				if fit <= 0:
					break

				carried += float(fit) * each

			check(guard < 200000, "%s in handfuls of %d reaches the limit" % [id, chunk])
			check(carried <= cap + 0.00001, "%s in handfuls of %d stays within the limit (%.6f of %.2f)" % [id, chunk, carried, cap])
			check(cap - carried < maxf(each, CarryRules.MIN_EACH_KG) * float(chunk) + 0.00001, "%s in handfuls of %d fills the pack (%.4f left)" % [id, chunk, cap - carried])

	# A weight of zero or less does not make a free stack.
	var zero_cfg: Dictionary = cfg.duplicate(true)
	zero_cfg["by_id"]["weightless"] = 0.0
	check(CarryRules.fit_count("weightless", 1000000, 0.0, body, zero_cfg) < 1000000, "a zero-weight item still has a limit")
	check(CarryRules.fit_count("stone", 5, cap + 1.0, body, cfg) == 0, "over the limit nothing more fits")
	print("test_carry_many_light: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
