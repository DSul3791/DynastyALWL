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
	items.ground_height = func(x, z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "placekey00001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var kits: Array = ["campfire_kit", "chest_kit", "lean_to_kit", "chopping_block_kit"]
	var agree: int = 0
	var total: int = 0
	var spots: Array = []

	for n in range(60):
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
	print("placement rules: %d failures" % failures)
	quit(1 if failures > 0 else 0)
