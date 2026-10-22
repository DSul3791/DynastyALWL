extends SceneTree

# The placement ghost's rules (src/shared/placement_rules.gd) against the server's real placement (job 69 and 76):
# for every kit and a spread of spots, the ghost says "free" exactly when the server accepts the placement.
#   godot --headless --path . --script res://src/worldgen/tools/test_placement_rules.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Rules := preload("res://src/shared/placement_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var cfg: Dictionary = Rules.load_config()
	check(Rules.footprint(cfg, "lean_to_kit") == Vector2(2.4, 2.1) and Rules.footprint(cfg, "campfire_kit") == Vector2.ZERO, "footprints come from structures.json (lean-to 2.4 x 2.1, fire none)")
	check(Rules.blocked(cfg, "chest_kit", Vector3(0, 10, 0), []) == "", "an empty world blocks nothing")
	var rows: Array = [{"pos": Vector3(0, 10, 0), "state": 1}]
	check(Rules.blocked(cfg, "chest_kit", Vector3(1.0, 10, 0), rows) == "close", "a chest too near a fire is blocked")
	check(Rules.blocked(cfg, "campfire_kit", Vector3(1.5, 10, 0), rows) == "close" and Rules.blocked(cfg, "campfire_kit", Vector3(2.5, 10, 0), rows) == "", "a fire needs 2 m from another fire")
	check(Rules.blocked(cfg, "campfire_kit", Vector3(2.2, 10, 0), [{"pos": Vector3(0, 10, 0), "state": 6}]) == "close", "a fire too near a structure is blocked")

	# Slope (design 10.1): the ghost is red until the ground is a reasonable shape.
	var flat: Callable = func(_x, _z): return 10.0
	var ramp: Callable = func(x, _z): return 10.0 + 0.5 * x   # rises 0.5 m per metre along x
	var hole: Callable = func(_x, _z): return NAN
	check(Rules.steep(cfg, "lean_to_kit", Vector3(0, 10, 0), 0.0, flat) == "", "flat ground takes a lean-to")
	check(Rules.steep(cfg, "lean_to_kit", Vector3(0, 10, 0), 0.0, ramp) == "steep", "a lean-to on a 50 percent slope is red (rise 1.2 m over 2.4 m)")
	check(Rules.steep(cfg, "campfire_kit", Vector3(0, 10, 0), 0.0, ramp) == "steep", "a campfire on the same slope is red (rise 0.8 m over 1.6 m, limit 0.6)")
	check(Rules.steep(cfg, "chest_kit", Vector3(0, 10, 0), 0.0, func(x, _z): return 10.0 + 0.2 * x) == "", "a gentle slope is fine")
	check(Rules.steep(cfg, "lean_to_kit", Vector3(0, 10, 0), PI * 0.5, func(_x, z): return 10.0 + 0.5 * z) == "steep", "turning the lean-to turns its footprint (the slope runs along z)")
	check(Rules.steep(cfg, "lean_to_kit", Vector3(0, 10, 0), 0.0, hole) == "", "unknown ground never blocks by itself")
	check(Rules.reason_text("steep") != "" and Rules.reason_text("open") == "", "red states have a reason in words")

	var crowded: Array = []

	for n in range(8):
		crowded.append({"pos": Vector3(float(n) * 10.0, 10, 100), "state": 6})

	check(Rules.blocked(cfg, "chest_kit", Vector3(100.0, 10, 100), crowded) == "crowded", "the chest cap per chunk blocks the ninth chest")
	check(Rules.blocked(cfg, "lean_to_kit", Vector3(100.0, 10, 100), crowded) == "", "a full chest chunk still takes a lean-to")

	# Same answer as the server, kit by kit and spot by spot.
	var dir: String = "user://test_placement_rules"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "placekey00001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var kits: Array = ["campfire_kit", "chest_kit", "lean_to_kit", "chopping_block_kit"]
	var agree: int = 0
	var total: int = 0
	var spots: Array = []

	for n in range(60):
		@warning_ignore("integer_division")
		spots.append(Vector3(float(n % 6) * 1.7 - 4.0, 10.0, float(n / 6) * 1.7 - 5.0))

	for n in range(spots.size()):
		if spots[n].distance_to(Vector3(0.0, 10.0, 0.0)) > ItemsScript.PLACE_REACH_M:
			continue

		var kit: String = kits[n % kits.size()]
		var kit_number: int = items.table.number_of(kit)
		items.action(1, Net.ACT_ADMIN_GIVE, kit_number, 0, 1, Vector3.ZERO)
		var rows_now: Array = []

		for id in items._items:
			var it: Dictionary = items._items[id]

			if it.has("fire"):
				rows_now.append({"pos": it["pos"], "state": int(it["fire"]["state"])})
			elif it.has("struct"):
				rows_now.append({"pos": it["pos"], "state": int(items._structures[str(it["struct"]["kind"])]["state"])})

		var says: String = Rules.blocked(cfg, kit, spots[n], rows_now)
		var before: int = items.world_item_count()
		items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(kit_number), 0, 0, spots[n])
		var placed: bool = items.world_item_count() > before
		total += 1
		agree += 1 if placed == (says == "") else 0

		if placed != (says == ""):
			print("DISAGREE ", kit, " at ", spots[n], " ghost says '", says, "' server placed ", placed)

	check(agree == total, "the ghost agrees with the server on %d of %d placements" % [agree, total])
	# Building pieces: they click to a 1 m grid and quarter turns and sit edge to edge, though other structures keep their gap.
	var on_grid: Array = Rules.snap(cfg, "wall_section_kit", Vector3(10.4, 10.0, 7.6), 133)
	check(on_grid[0] == Vector3(10.0, 10.0, 8.0) and int(on_grid[1]) == 90, "a wall snaps to the 1 m grid and a quarter turn (%s)" % str(on_grid))
	# A foundation: walls and floors near it click to its anchors and stand on its top; far from it they use the grid.
	var base_rows: Array = [{"pos": Vector3(50.0, 10.0, 50.0), "state": 25}]
	var on_base: Array = Rules.snap(cfg, "wall_section_kit", Vector3(48.9, 10.0, 47.6), 0, base_rows)
	check(bool(on_base[2]) and is_equal_approx(on_base[0].y, 10.3) and on_base[0].x == 49.0 and on_base[0].z == 48.0, "a wall near the foundation edge snaps to its anchor, on top (%s)" % str(on_base))
	var on_side: Array = Rules.snap(cfg, "wall_section_kit", Vector3(47.9, 10.0, 49.4), 0, base_rows)
	check(bool(on_side[2]) and int(on_side[1]) == 90, "a wall at the side anchor turns to run along that side (%s)" % str(on_side))
	check(bool(Rules.snap(cfg, "floor_section_kit", Vector3(50.9, 10.0, 49.2), 0, base_rows)[2]), "a floor snaps onto the foundation")
	check(not bool(Rules.snap(cfg, "wall_section_kit", Vector3(60.0, 10.0, 60.0), 0, base_rows)[2]), "far from the foundation a wall uses the plain grid")
	check(not bool(Rules.snap(cfg, "foundation_section_kit", Vector3(50.0, 10.0, 50.0), 0, base_rows)[2]), "a foundation does not snap onto a foundation")
	check(Rules.snap(cfg, "chest_kit", Vector3(10.4, 10.0, 7.6), 133)[0] == Vector3(10.4, 10.0, 7.6), "a chest keeps its own spot")
	items.report_position(1, Vector3(200.0, 10.0, 200.0))
	var walls_before: int = items.world_item_count()

	for spot in [Vector3(198.0, 10.0, 202.0), Vector3(200.0, 10.0, 202.0), Vector3(202.0, 10.0, 202.0), Vector3(200.0, 10.0, 203.0)]:
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("wall_section_kit"), 0, 1, Vector3.ZERO)
		items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("wall_section_kit")), 0, 0, spot)

	check(items.world_item_count() == walls_before + 4, "four wall sections stand edge to edge, 2 m and 1 m apart (%d placed)" % (items.world_item_count() - walls_before))
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("chest_kit"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("chest_kit")), 0, 0, Vector3(200.0, 10.0, 202.5))
	check(items.world_item_count() == walls_before + 4, "a chest is still kept 2.5 m from a wall")
	# Nothing is built in water (Dave 2026-10-22: floor sections lay on the pond): any corner wet blocks it, on the server too.
	var pond: Callable = func(x: float, _z: float) -> float: return 1.0 if x > 300.0 else 0.0
	check(Rules.over_water(cfg, "floor_section_kit", Vector3(301.0, 10.0, 0.0), 0.0, pond) and not Rules.over_water(cfg, "floor_section_kit", Vector3(298.0, 10.0, 0.0), 0.0, pond), "a floor with no wet corner is fine, one wet corner blocks it")
	check(Rules.over_water(cfg, "campfire_kit", Vector3(300.5, 10.0, 0.0), 0.0, pond) and Rules.reason_text("water") != "", "a campfire ring in water is blocked, with a reason in words")
	items.water_depth_at = func(pos: Vector3) -> float: return 1.0 if pos.x > 300.0 else 0.0
	items.report_position(1, Vector3(302.0, 10.0, 200.0))
	var wet_before: int = items.world_item_count()
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("floor_section_kit"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("floor_section_kit")), 0, 0, Vector3(302.0, 10.0, 202.0))
	check(items.world_item_count() == wet_before, "the server refuses a floor section over water")
	# Server: a foundation stands, then a wall near its edge sits on top of it at the anchor.
	items.peer_connected_hello(2, "foundkey0002")
	items.water_depth_at = func(_pos: Vector3) -> float: return 0.0
	items.report_position(2, Vector3(400.0, 10.0, 400.0))
	var base_before: int = items.world_item_count()
	items.action(2, Net.ACT_ADMIN_GIVE, items.table.number_of("foundation_section_kit"), 0, 1, Vector3.ZERO)
	items.action(2, Net.ACT_PLACE, items.inventory_of(2).numbers.find(items.table.number_of("foundation_section_kit")), 0, 0, Vector3(400.0, 10.0, 402.0))
	check(items.world_item_count() == base_before + 1, "a foundation is placed")
	items.action(2, Net.ACT_ADMIN_GIVE, items.table.number_of("wall_section_kit"), 0, 1, Vector3.ZERO)
	items.action(2, Net.ACT_PLACE, items.inventory_of(2).numbers.find(items.table.number_of("wall_section_kit")), 0, 0, Vector3(399.2, 10.0, 399.7))
	var wall_y: float = -1.0

	for id in items._items:
		if items._items[id].has("struct") and items._items[id]["struct"]["kind"] == "wall_section":
			wall_y = maxf(wall_y, items._items[id]["pos"].y)

	check(items.world_item_count() == base_before + 2 and is_equal_approx(wall_y, 10.3), "a wall beside it stands on the foundation top (y %.2f)" % wall_y)
	# A doorway and a window wall snap onto the foundation like a wall; the foundation stays while they stand on it.
	check(bool(Rules.snap(cfg, "doorway_section_kit", Vector3(48.9, 10.0, 47.6), 0, base_rows)[2]) and bool(Rules.snap(cfg, "window_section_kit", Vector3(48.9, 10.0, 47.6), 0, base_rows)[2]), "doorway and window walls snap to the foundation anchors")
	var base_id: int = 0

	for id in items._items:
		if items._items[id].has("struct") and items._items[id]["struct"]["kind"] == "foundation_section":
			base_id = id

	var found_before: int = items.world_item_count()
	items.action(2, Net.ACT_PICKUP, base_id, 0, 0, Vector3.ZERO)
	check(items.world_item_count() == found_before, "a foundation with a wall on it cannot be taken down")
	# A campfire's store: wood goes in and feeds the fire, an axe is refused.
	items.report_position(2, Vector3(450.0, 10.0, 450.0))
	items.action(2, Net.ACT_ADMIN_GIVE, items.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	items.action(2, Net.ACT_PLACE, items.inventory_of(2).numbers.find(items.table.number_of("campfire_kit")), 0, 0, Vector3(450.0, 10.0, 452.0))
	var fire_id: int = 0

	for id in items._items:
		if items._items[id].has("fire") and items._items[id]["pos"].distance_to(Vector3(450.0, 10.0, 452.0)) < 1.0:
			fire_id = id

	check(fire_id != 0, "a campfire is placed for the store test")
	items.action(2, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 3, Vector3.ZERO)
	items.action(2, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	items.action(2, Net.ACT_CHEST_OPEN, fire_id, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_CHEST_PUT, items.inventory_of(2).numbers.find(items.table.number_of("stone_axe")), fire_id, 1, Vector3.ZERO)
	items.action(2, Net.ACT_CHEST_PUT, items.inventory_of(2).numbers.find(items.table.number_of("stick")), fire_id, 3, Vector3.ZERO)
	var box = items._chests.get(int(items._items[fire_id]["fire"].get("uid", 0)))
	check(box != null and box.count_of(items.table.number_of("stick")) == 3 and box.count_of(items.table.number_of("stone_axe")) == 0, "a fire's store takes wood and refuses an axe")
	items._items[fire_id]["fire"]["burn_left"] = 5.0
	items._items[fire_id]["fire"]["tend"] = 0.0
	items._fires(0.1)
	check(float(items._items[fire_id]["fire"]["burn_left"]) > 5.0 and box.count_of(items.table.number_of("stick")) == 2, "wood in the store feeds a nearly-out fire")
	# Rest points: a lean-to you built and a fire you slept by are places to come back to, the nearest one wins; none left means the old rule.
	items.report_position(2, Vector3(500.0, 10.0, 500.0))
	items.action(2, Net.ACT_ADMIN_GIVE, items.table.number_of("lean_to_kit"), 0, 1, Vector3.ZERO)
	items.action(2, Net.ACT_PLACE, items.inventory_of(2).numbers.find(items.table.number_of("lean_to_kit")), 0, 0, Vector3(500.0, 10.0, 503.0))
	var rest_key: String = str(items._peer_key[2])
	check(items._characters[rest_key].get("rests", []).size() == 1, "building a lean-to records a rest point")
	var near_lean: Vector3 = items.rest_point_for(2, Vector3(500.0, 10.0, 520.0))
	check(near_lean.distance_to(Vector3(500.0, 10.0, 503.0)) < 5.0, "a dropped player comes back beside the lean-to (%s)" % str(near_lean))
	items._record_rest(rest_key, items._items[fire_id]["pos"], "fire")
	var fire_back: Vector3 = items.rest_point_for(2, Vector3(450.0, 10.0, 470.0))
	check(fire_back.distance_to(items._items[fire_id]["pos"]) < 3.0, "from beside the campfire the campfire is the nearest rest point (%s)" % str(fire_back))
	items.report_position(2, Vector3(450.0, 10.0, 450.0))
	# A dead branch on the forest floor gives one stick, only within reach.
	var sticks_had: int = items.inventory_of(2).count_of(items.table.number_of("stick"))
	items.action(2, Net.ACT_LITTER, 0, 0, 0, Vector3(451.0, 10.0, 450.0))
	check(items.inventory_of(2).count_of(items.table.number_of("stick")) == sticks_had + 1, "picking a branch from the forest floor gives a stick")
	OS.delay_msec(100)
	items.action(2, Net.ACT_LITTER, 0, 0, 0, Vector3(490.0, 10.0, 450.0))
	check(items.inventory_of(2).count_of(items.table.number_of("stick")) == sticks_had + 1, "a branch far away gives nothing")
	print("placement rules: %d failures" % failures)
	quit(1 if failures > 0 else 0)
