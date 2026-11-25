extends SceneTree

# Animal voices by state (docs/design/ANIMAL_SCENARIOS.md gap 4): flight is silent for every kind; a look-up calls only for kinds with an
# alarm of their own, and only on that animal's first look (animal_view); a kind that borrows a voice looks up in silence; cats and bears
# warn with the low growl, boar with a snort; the black bear, lynx and puma never roar.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_voices.gd

const CreatureSounds := preload("res://src/client/creature_sounds.gd")
const AnimalView := preload("res://src/client/animal_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	var s = CreatureSounds.new()

	for kind in AnimalView.KIND_OF_SPECIES.values():
		check(s.mood_for(kind, 2) == "", "a %s runs in silence" % kind)

	for kind in ["deer", "rabbit", "fox", "horse", "duck", "wolf"]:
		check(s.mood_for(kind, 3) == "alert", "a %s gives its own alarm call when it looks up" % kind)

	for kind in s.CALL_AS:
		check(s.mood_for(kind, 3) == "", "a %s (a borrowed voice) looks up in silence" % kind)

	for kind in ["lion", "tiger", "leopard", "puma", "lynx", "bear", "black_bear", "boar", "warthog"]:
		check(s.mood_for(kind, 10) == "alert", "a %s warns low (growl or snort), no roar or bellow" % kind)

	for kind in ["black_bear", "lynx", "puma"]:
		for state in [11, 25, 26]:
			check(s.mood_for(kind, state) == "alert", "a %s never roars (state %d)" % [kind, state])

	for kind in ["lion", "bear", "moose", "boar"]:
		check(s.mood_for(kind, 11) == "threat", "a %s still gives its threat call charging" % kind)

	s.free()

	# The first look only: a rabbit looking up a second time gives no second alarm.
	var view = AnimalView.new()
	root.add_child(view)
	var heard: Array = []
	view.state_changed.connect(func(kind, state, _at): heard.append([kind, state]))
	var node: Node3D = Node3D.new()
	view.add_child(node)
	view._bodies[5] = {"node": node, "state": 0, "spd": 0.0, "id": 5, "target": Vector3.ZERO, "kind": "rabbit", "samples": [], "heading": 0.0, "phase": 0.0, "step_count": -1, "contact_m": 0.3, "turn_rad_s": 6.0}
	var ms: int = 1000

	for state in [3, 0, 3, 2, 0, 3]:
		ms += 100
		view.on_rows([[5, 1, Vector3.ZERO, 0.0, state, ms]], ms)

	var looks: int = heard.filter(func(h): return int(h[1]) == 3).size()
	check(looks == 1, "a rabbit that looks up three times calls once (%s)" % str(heard))
	check(heard.any(func(h): return int(h[1]) == 2), "its flight is still told to the listeners (they choose silence)")
	view.queue_free()

	print("test_animal_voices: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
