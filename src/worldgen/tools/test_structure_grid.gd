extends SceneTree

# The server's solid footprints (src/stream/structure_grid.gd): a wall stops a point on it and a step through it, a turned wall is turned, a taken-down
# wall is forgotten, and structures.json marks the walls, heavy stations and shut doors and gates "blocks_walk" (floors and open doorways stay walkable).
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

	# Doors and gates (Steve 10 Nov 2026): the shut one of each pair blocks, the open one ("_open", its toggle) does not, so a wolf cannot walk
	# through a shut gate in a palisade nor a fox through the shut door of a hut.
	var pairs: int = 0

	for kind in kinds:
		var row: Dictionary = kinds[kind]

		if str(row.get("use", "")) != "door" or not row.has("toggle") or str(kind).ends_with("_open"):
			continue

		pairs += 1
		var twin: String = str(row["toggle"])
		check(bool(row.get("blocks_walk", false)) and not bool(kinds.get(twin, {}).get("blocks_walk", false)) and kinds.has(twin), "%s blocks walkers shut, %s does not" % [kind, twin])

	check(pairs >= 36, "every door and gate pair is checked: 28 doors and the gates (%d)" % pairs)

	# A doorway frame is an open framed passage with no door of its own (BUGLIST-002; Crude: BUG-010): never solid, never a door pair; the old open twin is
	# gone and a saved one reads as the frame.
	var crude: Dictionary = kinds["thatch_doorway"]
	check(not kinds.has("thatch_doorway_open") and (crude.get("legacy_kinds", []) as Array).has("thatch_doorway_open"), "the old open twin is retired into the doorway")
	check(not bool(crude.get("blocks_walk", false)) and not crude.has("use") and not crude.has("toggle"), "the Crude doorway has no door to shut and does not block walkers")

	# A shut door stops walkers across its whole frame (grid_x: 2 m single, 4 m double, so the frame's jambs block too) and 0.1 m thick, and shutting it again
	# after it was open keeps one rectangle (the grid forgets a stale kind only when asked).
	var shut: Dictionary = {7: {"struct": {"kind": "rustic_door"}}}
	var door = GridScript.new()
	var single: Dictionary = kinds["rustic_door"]
	door.add(7, "rustic_door", 100.0, 100.0, 0.0, float(single["grid_x"]), float(single["footprint_z"]))
	check(door.blocks(100.4, 100.0, 0.0, shut) and door.blocks(100.9, 100.0, 0.0, shut) and not door.blocks(101.2, 100.0, 0.0, shut) and not door.blocks(100.0, 100.2, 0.0, shut), "a shut single door blocks its 2 m frame, jambs too, and nothing beside or in front of it")
	door.add(7, "rustic_door", 100.0, 100.0, 0.0, float(single["grid_x"]), float(single["footprint_z"]))
	var rects: int = 0

	for bucket in door._buckets.values():
		rects += (bucket as Array).size()

	check(rects == 1, "a door shut again keeps one rectangle (%d)" % rects)
	var wide: Dictionary = kinds["rustic_double_door"]
	var leaves: Dictionary = {8: {"struct": {"kind": "rustic_double_door"}}}
	door.add(8, "rustic_double_door", 120.0, 100.0, 90.0, float(wide["grid_x"]), float(wide["footprint_z"]))
	check(door.blocks(120.0, 100.9, 0.0, leaves) and door.blocks(120.0, 101.9, 0.0, leaves) and not door.blocks(120.0, 102.2, 0.0, leaves), "a double door turned a quarter blocks its 4 m frame along z, jambs too")

	print("test_structure_grid: %d fail" % failures)
	quit(1 if failures > 0 else 0)
