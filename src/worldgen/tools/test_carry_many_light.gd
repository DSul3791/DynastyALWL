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
	# Seeds weigh one real seed (Dave 23 Nov 2026: "typical seeds weigh 5-7mg so you really need to fix that for all seeds"; QA #5, #6).
	for id in ["flax_seeds", "linseed"]:
		check(CarryRules.weight_of(id, cfg) >= 0.000005 and CarryRules.weight_of(id, cfg) <= 0.000007, "%s weighs 5 to 7 mg (%s)" % [id, CarryRules.weight_text(CarryRules.weight_of(id, cfg))])

	var big_seeds: Array = ["oak_seed", "sweet_chestnut_seed", "walnut_seed", "date_palm_seed", "mango_seed", "coconut_palm_seed", "stillwater_seeds"]

	for id in cfg["by_id"]:
		if (str(id).ends_with("_seed") or str(id).ends_with("_seeds")) and not big_seeds.has(id) and str(id) != "seed_bundle":
			check(float(cfg["by_id"][id]) > 0.0 and float(cfg["by_id"][id]) < 0.001, "%s weighs under a gram (%s)" % [id, CarryRules.weight_text(float(cfg["by_id"][id]))])

	# The weight a player reads: never rounded to a wrong figure, and a stack's total adds up.
	var shown: Dictionary = {52.5: "52.50 kg", 1.0: "1.00 kg", 0.5: "500 g", 0.012: "12 g", 0.0025: "2.5 g", 0.001: "1 g", 0.000006: "6 mg",
		0.000018: "18 mg", 0.0000012: "1.2 mg", 0.00000025: "0.25 mg", 0.00000001: "0.01 mg", 0.000000005: "under 0.01 mg", 0.0: "0 g"}

	for kg in shown:
		check(CarryRules.weight_text(kg) == shown[kg], "%s kg shows as %s (got %s)" % [kg, shown[kg], CarryRules.weight_text(kg)])

	check(CarryRules.weight_text(CarryRules.weight_of("flax_seeds", cfg) * 3.0) == "18 mg", "three flax seeds show 18 mg in all")
	check(CarryRules.weight_text(CarryRules.weight_of("flax_seeds", cfg) * 150.0) == "900 mg", "150 flax seeds show 900 mg, about a gram")

	print("test_carry_many_light: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
