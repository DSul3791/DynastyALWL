extends SceneTree

# What a growing cone pile costs per blow (boulders stage 1, PR #1322; coordinator 19 Nov 2026 on Dave's oversized-reactions rule: a small
# action must not have a huge cost). A full pack sends each stone a blow breaks to drop_in_world, which walks the world's records to find
# the pile and then _pile_blocked to see whether it may grow; the client then rebuilds the pile's mesh for the new count.
# Prints pile_cost: lines with both times; fails only past generous budgets (a measurement first, a ceiling second).
#   godot --headless --path . --script res://src/worldgen/tools/test_pile_cost.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const PileLookScript := preload("res://src/client/pile_look.gd")
const PileRules := preload("res://src/shared/pile_rules.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")

const OTHER_RECORDS := 6000
const DROPS := 400
const SERVER_BUDGET_MS := 2.0    # per stone dropped on a big pile among 6000 other records
const CLIENT_BUDGET_MS := 50.0   # per mesh rebuild of a 20,000-stone cone
const BASE := Vector3(5000.0, 10.0, 5000.0)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var dir: String = "user://test_pile_cost"
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
	var stone: int = items.table.number_of("stone")
	var stick: int = items.table.number_of("stick")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11

	for k in range(OTHER_RECORDS):   # other loose records about the base, none of them stone, so none is a pile to join
		items._items[items._next_id] = {"number": stick, "count": 1, "pos": BASE + Vector3(rng.randf_range(-400.0, 400.0), 0.0, rng.randf_range(-400.0, 400.0)), "left": 1.0e9, "wear": 0}
		items._next_id += 1

	items._sync_world_items()   # the world sync files the records in its grid, as a running server does every few seconds
	items.drop_in_world(stone, 20000, BASE)
	var foot: Vector3 = BASE + Vector3(items._cone_radius_of(stone, 20000) + 0.4, 0.0, 0.0)
	var start: int = Time.get_ticks_usec()

	for k in range(DROPS):
		items.drop_in_world(stone, 1, foot)

	var server_ms: float = float(Time.get_ticks_usec() - start) / 1000.0 / float(DROPS)
	var piles: Array = items._items.keys().filter(func(id): return int(items._items[id]["number"]) == stone)
	check(piles.size() == 1 and int(items._items[piles[0]]["count"]) == 20000 + DROPS, "every stone joined the one pile (%d piles)" % piles.size())
	print("pile_cost: server %.3f ms a stone onto a 20,000-stone pile among %d records" % [server_ms, items._items.size()])
	check(server_ms < SERVER_BUDGET_MS, "a dropped stone costs the server under %.1f ms (%.3f)" % [SERVER_BUDGET_MS, server_ms])

	var entry: Dictionary = items.table.entry("stone")
	var unit_kg: float = 0.5
	start = Time.get_ticks_usec()

	for k in range(20):   # each blow changes the count, so each is a fresh mesh
		var mesh: Mesh = PileLookScript.mesh_for("stone", entry, 20000 + k, 3, unit_kg)
		check(mesh != null, "a cone mesh is built for %d stones" % (20000 + k))

	var client_ms: float = float(Time.get_ticks_usec() - start) / 1000.0 / 20.0
	print("pile_cost: client %.2f ms a mesh rebuild of a 20,000-stone cone" % client_ms)
	check(client_ms < CLIENT_BUDGET_MS, "a cone mesh rebuild costs the client under %.0f ms (%.2f)" % [CLIENT_BUDGET_MS, client_ms])

	# Ore piles (Dave 21 Nov 2026: "ore piles should stackup like stone piles do just with different colors and lumps"): every ore item is a
	# cone pile, its drops join one pile, and its mesh has as many points as the stone cone and costs about the same to rebuild (lumpy pieces are
	# built once, not per pile).
	var stone_verts: int = PileLookScript.mesh_for("stone", entry, 20000, 5, unit_kg).surface_get_array_len(0)
	var ores: PackedStringArray = PackedStringArray()

	for id in items.table.ids():
		var row: Dictionary = items.table.entry(id)

		if id.ends_with("_ore") and str(row.get("kind", "")) == "material" and not bool(row.get("retired", false)):
			ores.append(id)

	check(ores.size() >= 4, "the item list has the ores (%s)" % ", ".join(ores))

	for id in ores:
		var ore_entry: Dictionary = items.table.entry(id)
		var ore: int = items.table.number_of(id)
		check(PileRules.is_cone(ore_entry.get("pile", {})), "%s has a cone pile row like stone" % id)
		var ore_base: Vector3 = BASE + Vector3(0.0, 0.0, 60.0 + 20.0 * float(ores.find(id)))
		items.drop_in_world(ore, 2000, ore_base)
		var ore_foot: Vector3 = ore_base + Vector3(items._cone_radius_of(ore, 2000) + 0.4, 0.0, 0.0)

		for k in range(50):
			items.drop_in_world(ore, 1, ore_foot)

		var ore_piles: Array = items._items.keys().filter(func(gid): return int(items._items[gid]["number"]) == ore)
		check(ore_piles.size() == 1 and int(items._items[ore_piles[0]]["count"]) == 2050, "every %s dropped joined the one pile (%d piles)" % [id, ore_piles.size()])
		var ore_kg: float = CarryRules.weight_of(id, items._carry_cfg)
		start = Time.get_ticks_usec()

		for k in range(20):
			var ore_mesh: Mesh = PileLookScript.mesh_for(id, ore_entry, 20000 + k, 3, ore_kg)
			check(ore_mesh != null and ore_mesh.surface_get_array_len(0) == stone_verts, "a %s cone of %d has the stone cone's size of mesh" % [id, 20000 + k])

		var ore_ms: float = float(Time.get_ticks_usec() - start) / 1000.0 / 20.0
		print("pile_cost: client %.2f ms a mesh rebuild of a 20,000-piece %s cone" % [ore_ms, id])
		check(ore_ms < CLIENT_BUDGET_MS, "a %s cone mesh rebuild costs the client under %.0f ms (%.2f)" % [id, CLIENT_BUDGET_MS, ore_ms])

	print("pile cost tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
