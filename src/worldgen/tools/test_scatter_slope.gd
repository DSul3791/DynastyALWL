extends SceneTree

# Loose stones and sticks are not laid on ground steeper than a player stands on (world audit round 4, 23 Nov 2026: 1 in 5 lay on faces over
# 45 degrees, 376 of them out of every player's reach). server_items _scatter_spot.
#   godot --headless --path . --script res://src/worldgen/tools/test_scatter_slope.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func laid(ground: Callable) -> int:
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), "user://test_scatter_slope")
	items.ground_height = ground
	var cfg: Dictionary = items._drops.get("ground_scatter", {})
	var count: int = 0

	for cx in range(40):
		items._items.clear()
		items._lay_out_cell(Vector2i(100 + cx, 100), 32.0, cfg)

		for id in items._items:
			if items._items[id].has("scatter") and not items._items[id].has("boulder") and items.table.id_of(int(items._items[id]["number"])) in ["stone", "stick"]:
				count += 1

	return count


func _init() -> void:
	var gentle: int = laid(func(x, _z): return 50.0 + 0.4 * x)
	var cliff: int = laid(func(x, _z): return 50.0 + 1.3 * x)
	check(gentle > 20, "on a 22 degree slope stones and sticks are laid (%d in 40 cells)" % gentle)
	check(cliff == 0, "on a 52 degree face none are (%d)" % cliff)
	print("scatter slope test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
