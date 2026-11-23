extends SceneTree

# The shovel's fill scoop sounds like what the server fills with (Jason 3, TODO piece 12a): the first of digging.json "fill" the pack holds;
# gravel and stone scoop with the stone sound, soil, sand and clay with the soil one.
#   godot --headless --path . --script res://src/worldgen/tools/test_shovel_fill_sound.gd

const HeldItem := preload("res://src/client/held_item.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func _init() -> void:
	var order: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/digging.json")) as Dictionary).get("fill", [])
	check(order == ["soil", "sand", "gravel", "clay", "stone"], "digging.json fills soil, sand, gravel, clay, stone (%s)" % str(order))
	var pack: Dictionary = {}   # a lambda keeps the Dictionary it saw: cleared and refilled, never reassigned
	var count_of: Callable = func(n: String) -> int: return int(pack.get(n, 0))
	pack.clear()
	pack.merge({"stone": 4})
	check(HeldItem.fill_is_stony(order, count_of), "stone only: the stone scoop")
	pack.clear()
	pack.merge({"stone": 4, "soil": 1})
	check(not HeldItem.fill_is_stony(order, count_of), "soil comes first: the soil scoop")
	pack.clear()
	pack.merge({"gravel": 2, "clay": 3})
	check(HeldItem.fill_is_stony(order, count_of), "gravel before clay: the stone scoop")
	pack.clear()
	pack.merge({"clay": 3, "stone": 1})
	check(not HeldItem.fill_is_stony(order, count_of), "clay before stone: the soil scoop")
	pack.clear()
	check(not HeldItem.fill_is_stony(order, count_of), "nothing to fill with: the soil scoop (the server refuses anyway)")
	print("shovel fill sound: %d failures" % failures)
	quit(1 if failures > 0 else 0)
