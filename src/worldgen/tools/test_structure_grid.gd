extends SceneTree

# The server's solid footprints (src/stream/structure_grid.gd): a wall stops a point on it and a step through it, a turned wall is turned, a taken-down
# wall is forgotten, and structures.json marks the walls and heavy stations "blocks_walk" (floors and doorways stay walkable).
#   godot --headless --path . --script res://src/worldgen/tools/test_structure_grid.gd

const GridScript := preload("res://src/stream/structure_grid.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var grid = GridScript.new()
	var items: Dictionary = {1: {"struct": {"kind": "log_wall"}}, 2: {"struct": {"kind": "log_wall"}}}
	grid.add(1, "log_wall", 100.0, 100.0, 0.0, 2.0, 0.25)      # along x: 2 m wide, 0.25 m thick, centred at (100, 100)
	grid.add(2, "log_wall", 200.0, 100.0, 90.0, 2.0, 0.25)     # turned a quarter: now along z
	check(grid.blocks(100.0, 100.0, 0.0, items) and grid.blocks(100.9, 100.0, 0.0, items), "a point on the wall is blocked")
	check(not grid.blocks(101.2, 100.0, 0.0, items) and not grid.blocks(100.0, 100.4, 0.0, items), "beside the wall is open")
	check(grid.blocks(100.0, 100.4, 0.3, items), "an animal's body radius grows the wall")
	check(grid.blocks(200.0, 100.9, 0.0, items) and not grid.blocks(200.9, 100.0, 0.0, items), "the turned wall runs along z")
	check(grid.segment_blocked(100.0, 99.0, 100.0, 101.0, 0.0, items), "a stride across the wall is blocked, though both ends are clear")
	check(not grid.segment_blocked(100.0, 99.0, 101.5, 99.0, 0.0, items), "a stride beside the wall is not")
	check(not grid.blocks(5000.0, 5000.0, 0.0, items), "far from any wall is open")

	items.erase(1)
	check(not grid.blocks(100.0, 100.0, 0.0, items), "a wall taken down is forgotten")
	items[2]["struct"]["kind"] = "stone_wall"
	check(not grid.blocks(200.0, 100.0, 0.0, items), "a different kind in the same id is not the old wall")

	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var kinds: Dictionary = data["structures"]

	for solid in ["wall_section", "window_section", "thatch_wall", "log_wall", "stone_wall", "brick_wall", "stone_forge", "oven"]:
		check(bool(kinds[solid].get("blocks_walk", false)), "%s blocks walkers" % solid)

	for open in ["floor_section", "foundation_section", "doorway_section", "roof_section", "path_patch", "chest"]:
		check(not bool(kinds[open].get("blocks_walk", false)), "%s does not block walkers" % open)

	print("test_structure_grid: %d fail" % failures)
	quit(1 if failures > 0 else 0)
