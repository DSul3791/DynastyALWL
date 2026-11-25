extends SceneTree

# Midday rest (docs/design/ANIMAL_SCENARIOS.md gap 15): between rest.midday_hours a species' "midday" active value replaces its day value,
# so bears and the cats nap through the middle of the day (they rest), elk lie up, and the mountain grazers are mostly bedded; kinds
# with no midday value (deer) keep their day value.
#   godot --headless --path . --script res://src/worldgen/tools/test_midday_rest.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var hour: float = 13.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.hour_now = func(): return hour
	a.setup()

	for kind in ["bear", "black_bear", "lion", "puma", "lynx", "elk"]:
		hour = 13.0
		check(a.resting(a.species_def(kind)), "a %s rests at 13:00" % kind)
		hour = 9.5
		check(not a.resting(a.species_def(kind)) or kind in ["lion", "puma", "lynx"], "a %s is up at 09:30" % kind)

	for kind in ["bighorn", "chamois", "mountain_goat"]:
		check(absf(a.activity_at(a.species_def(kind), 13.0) - 0.3) < 0.001 and absf(a.activity_at(a.species_def(kind), 9.5) - 1.0) < 0.001, "a %s is mostly bedded at midday, up in the morning" % kind)

	var deer: float = a.activity_at(a.species_def("deer"), 13.0)
	check(absf(deer - float(a.species_def("deer")["active"]["day"])) < 0.001, "a deer keeps its day value at midday (%.2f)" % deer)
	print("test_midday_rest: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
