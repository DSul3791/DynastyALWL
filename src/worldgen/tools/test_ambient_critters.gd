extends SceneTree

# Ambient critters (src/client/ambient_critters.gd, client only): butterflies and bees by day over meadows, dragonflies at water, birds in forest,
# fireflies on warm nights; nothing in winter (except a few birds) or in rain; the update costs microseconds.
#   godot --headless --path . --script res://src/worldgen/tools/test_ambient_critters.gd

const Critters := preload("res://src/client/ambient_critters.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var meadow: Dictionary = {"forest": 0.0, "meadow": 1.0, "water": 0.0, "highland": 0.0}
	var lake: Dictionary = {"forest": 0.0, "meadow": 0.2, "water": 1.0, "highland": 0.0}
	var wood: Dictionary = {"forest": 1.0, "meadow": 0.0, "water": 0.0, "highland": 0.0}
	var noon: Dictionary = Critters.density(meadow, "summer", 13.0, 0.0)
	check(noon["butterfly"] >= 10 and noon["bee"] >= 8, "a summer noon meadow has butterflies and bees (%d, %d)" % [noon["butterfly"], noon["bee"]])
	check(noon["firefly"] == 0, "no fireflies at noon")
	var night: Dictionary = Critters.density(meadow, "summer", 23.0, 0.0)
	check(night["butterfly"] == 0 and night["bee"] == 0 and night["firefly"] >= 8, "a summer night meadow has fireflies, no butterflies or bees (%d fireflies)" % night["firefly"])
	check(Critters.density(lake, "summer", 12.0, 0.0)["dragonfly"] >= 4, "dragonflies hover over a lake at noon")
	check(Critters.density(wood, "summer", 12.0, 0.0)["bird"] >= 3, "birds are out in the forest by day")
	var winter: Dictionary = Critters.density(meadow, "winter", 13.0, 0.0)
	check(winter["butterfly"] == 0 and winter["bee"] == 0 and winter["dragonfly"] == 0 and winter["firefly"] == 0, "no insects in winter")
	var rain: Dictionary = Critters.density(meadow, "summer", 13.0, 0.5)
	check(rain["butterfly"] == 0 and rain["bee"] == 0, "no butterflies or bees in rain")
	check(Critters.density(meadow, "autumn", 13.0, 0.0)["butterfly"] < noon["butterfly"], "fewer butterflies in autumn than in summer")
	var empty: Dictionary = Critters.density({"forest": 0.0, "meadow": 0.0, "water": 0.0, "highland": 1.0}, "summer", 13.0, 0.0)
	var total: int = 0

	for kind in Critters.KINDS:
		total += int(empty[kind])

	check(total == 0, "nothing flies over bare highland")

	# The node: builds, shows the wanted counts and costs little per frame.
	var node = Critters.new()
	node._ready()   # built directly: a node added in _init is readied only once the main loop runs
	node.update(0.016, Vector3(100.0, 30.0, 100.0), meadow, "summer", 13.0, 0.0)
	check(int(node.counts["butterfly"]) == noon["butterfly"] and node.get_node("butterfly").multimesh.visible_instance_count == noon["butterfly"], "the node shows the wanted number of butterflies")
	var worst: int = 0
	var started: int = Time.get_ticks_usec()

	for frame in range(2000):
		node.update(0.016, Vector3(100.0 + float(frame) * 0.05, 30.0, 100.0), lake, "summer", 13.0, 0.0)

	var per_frame_us: float = float(Time.get_ticks_usec() - started) / 2000.0
	print("update cost %.1f microseconds per frame with %d critters" % [per_frame_us, int(node.counts["butterfly"]) + int(node.counts["dragonfly"]) + int(node.counts["bee"])])
	check(per_frame_us < 300.0, "the update costs under 0.3 ms per frame (%.0f us)" % per_frame_us)
	node.quality = 0.5
	node.update(0.016, Vector3.ZERO, meadow, "summer", 13.0, 0.0)
	check(int(node.counts["butterfly"]) == int(round(float(noon["butterfly"]) * 0.5)), "the quality share halves the counts")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
