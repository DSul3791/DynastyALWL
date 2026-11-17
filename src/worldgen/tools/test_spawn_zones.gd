extends SceneTree

# No-spawn zones (Dave 17 Nov 2026): nothing wild spawns or regrows within no_spawn_m of anything a player put down; what stood there
# stays; once the piece is gone spawning comes back; the zones come back after a save and a load.
#   godot --headless --path . --script res://src/worldgen/tools/test_spawn_zones.gd

const ZonesScript := preload("res://src/stream/spawn_zones.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.ground_height = func(_x, _z): return 10.0
	return items


func _init() -> void:
	# The grid alone.
	var zones = ZonesScript.new()
	var rows: Dictionary = {1: {"pos": Vector3(100.0, 0.0, 100.0), "struct": {"kind": "workbench", "yaw": 0.0}}, 2: {"pos": Vector3(300.0, 0.0, 300.0), "fire": {}},
		3: {"pos": Vector3(500.0, 0.0, 500.0), "struct": {"kind": "remains", "yaw": 0.0}}, 4: {"pos": Vector3(700.0, 0.0, 700.0), "number": 5, "count": 1}}

	for id in rows:
		if ZonesScript.counts(rows[id]):
			zones.add(id, rows[id]["pos"].x, rows[id]["pos"].z)

	check(zones.blocked(119.0, 100.0, rows) and zones.blocked(100.0, 81.5, rows) and zones.blocked(114.0, 114.0, rows), "a structure blocks out to 20 m all round")
	check(not zones.blocked(121.0, 100.0, rows) and not zones.blocked(115.0, 115.0, rows), "past 20 m it does not")
	check(zones.blocked(310.0, 300.0, rows), "a fire blocks too")
	check(not zones.blocked(500.0, 500.0, rows) and not zones.blocked(700.0, 700.0, rows), "remains and a dropped item do not")
	rows.erase(1)
	check(not zones.blocked(110.0, 100.0, rows), "once the piece is gone, spawning comes back")
	rows[2]["pos"] = Vector3(400.0, 0.0, 400.0)
	check(not zones.blocked(300.0, 300.0, rows), "a piece moved away no longer blocks its old spot")

	# The server: a placed station, a save, a load.
	var dir: String = "user://test_spawn_zones"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var bench: int = items.dev_place("workbench@1000,1000,0")
	check(bench != 0, "a workbench is placed")
	check(items.spawn_blocked(1015.0, 1000.0) and not items.spawn_blocked(1025.0, 1000.0), "the server blocks 20 m round it")
	var fire: int = items.dev_place("campfire@2000,2000,0")
	check(fire != 0 and items.spawn_blocked(2000.0, 2010.0), "a laid campfire blocks too")
	items._dirty = true
	items.save()
	items._finish_writer()
	var again = make(dir)
	check(again.spawn_blocked(1015.0, 1000.0), "after a save and a load the workbench still blocks")
	check(again.spawn_blocked(2000.0, 2010.0), "and so does the fire")

	# Saplings: none seeded within 20 m of the bench, one may be 20 m away or more.
	again.world_seed = 3
	again.game_seconds = func(): return 0.0
	again.standing_near = func(name, pos, _radius): return [pos] if name == "oak" else []
	var before: int = again._saplings.size()

	for n in range(40):
		again._maybe_sapling({"pos": Vector3(1000.0 + float(n % 8), 10.0, 1000.0 + float(n / 8)), "tree": {"species": "oak", "chunk": [3, 3], "state": 4}})

	check(again._saplings.size() == before, "no sapling is seeded within 20 m of a placed workbench")

	for id in again._items.keys():
		if again._items[id].has("struct") and str(again._items[id]["struct"]["kind"]) == "workbench":
			again._items.erase(id)

	check(not again.spawn_blocked(1015.0, 1000.0), "the bench taken down: the spot is free again")

	for n in range(40):
		again._maybe_sapling({"pos": Vector3(1000.0 + float(n % 8), 10.0, 1000.0 + float(n / 8)), "tree": {"species": "oak", "chunk": [3, 3], "state": 4}})

	check(again._saplings.size() > before, "and saplings come back there")

	# Animals: a top-up never puts one down where no_spawn says no.
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.setup()
	a.traits = false

	for sp in a.cfg["species"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.cfg["species"]["rabbit"]["target_per_player"] = 6
	a.cfg["species"]["rabbit"].erase("spawn_share")
	a.cfg["species"]["rabbit"]["burrow_m"] = 0.0
	a.biome_at = func(_x, _z): return "temperate_grassland"
	a.rng.seed = 5
	a.no_spawn = func(_x, _z): return true

	for n in 800:
		a.tick(0.05)

	check(a.animals.is_empty(), "no animal spawns where every spot is blocked (%d)" % a.animals.size())
	a.no_spawn = func(x, _z): return x < 0.0
	var made_at: Dictionary = {}   # id -> where it was first seen (the tick it was made)

	for n in 800:
		a.tick(0.05)

		for id in a.animals:
			if not made_at.has(id):
				made_at[id] = a.animals[id]["pos"]

	var west: int = 0

	for id in made_at:
		west += 1 if made_at[id].x < -1.0 else 0   # a metre of slack: one tick of walking after it was made

	check(made_at.size() > 0 and west == 0, "with half blocked they are made only on the free half (%d, %d west)" % [made_at.size(), west])

	print("test_spawn_zones: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
