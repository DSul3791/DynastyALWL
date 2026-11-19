extends SceneTree

# Animal dens in caves (Dave 19 Nov 2026: natural caves become dens; bears, wolves and foxes may den in them, provisional CD-1..CD-3 in
# docs/design/CAVE_DENS_AND_MINES.md): which caves hold which animal, the den signs the client draws, and where the server makes the animal.
# Plain data, no world.
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_animal_dens.gd

const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A spring cave: mouth at x x0 (floor 10), a stream passage east, a dry branch north ending in a den.
func cave(id: String, size: String, kind: String = "spring_cave", x0: float = 0.0) -> Dictionary:
	return {
		"id": id, "cave_kind": kind, "size": size,
		"nodes": [[x0, 11.0, 0.0, 4.0, 2.0], [x0 + 8.0, 11.4, 0.0, 4.0, 2.0], [x0 + 16.0, 11.8, 0.0, 4.0, 2.0], [x0 + 8.0, 12.0, 10.0, 3.0, 2.0]],
		"segments": [[0, 1, "water"], [1, 2, "water"], [1, 3, "passage"]],
		"chambers": [], "entrances": [0], "dens": [{"node": 3, "where": "branch", "tier": 1}],
	}


# The first id from a prefix whose hashes give (or keep from) an animal den and keep goblins out: goblin_den_node is by its own hash.
func id_with(prefix: String, want_animal: bool) -> String:
	for n in 400:
		var id: String = "%s%d" % [prefix, n]
		var animal: bool = absi(hash(id + "/animal_den")) % 100 < TileTerrainData.ANIMAL_DEN_PERCENT
		var goblin: bool = absi(hash(id)) % 100 < TileTerrainData.GOBLIN_DEN_PERCENT

		if animal == want_animal and not goblin:
			return id

	return ""


func _init() -> void:
	# Which animal: by size, a lava tube as large; none for a rock shelter, a cave without passages, the goblin camp cave or a cave the share leaves out.
	var yes: String = id_with("den_", true)
	var no: String = id_with("none_", false)
	check(yes != "" and no != "", "test ids found (%s, %s)" % [yes, no])
	check(TileTerrainData.animal_den_species(cave(yes, "large")) == "bear", "a large cave is a bear's")
	check(TileTerrainData.animal_den_species(cave(yes, "medium")) == "wolf", "a medium cave is a wolf pack's")
	check(TileTerrainData.animal_den_species(cave(yes, "small")) == "fox", "a small cave is a fox's")
	check(TileTerrainData.animal_den_species(cave(yes, "", "lava_tube")) == "bear", "a lava tube counts as large")
	check(TileTerrainData.animal_den_species(cave(yes, "small", "rock_shelter")) == "", "never a rock shelter")
	check(TileTerrainData.animal_den_species(cave(no, "large")) == "", "a cave the share leaves out stays empty")
	check(TileTerrainData.animal_den_species(cave("3,4#8013", "small")) == "", "the goblin camp cave is kept free")

	var seen: int = 0

	for n in 200:
		seen += 1 if TileTerrainData.animal_den_species(cave("share_%d" % n, "small")) != "" else 0

	check(seen > 110 and seen < 170, "about %d %% of caves hold an animal den (%d of 200)" % [TileTerrainData.ANIMAL_DEN_PERCENT, seen])

	# Loading: the mouth is listed for the server, and the signs are in cave_bones; a cave with goblins gets no animal. A tile's first spring
	# cave with a dry branch always holds goblins (goblin_den_nodes), so each list starts with one far off at x 500.
	var floor_cave: Dictionary = cave(no, "small", "spring_cave", 500.0)
	var data = TileTerrainData.new()
	data._load_caves([floor_cave, cave(yes, "medium")])
	var mouths: PackedVector2Array = data.animal_den_mouths.get("wolf", PackedVector2Array())
	check(mouths.size() == 1 and mouths[0].is_equal_approx(Vector2(0.0, 0.0)), "the wolf cave's mouth is listed (%s)" % str(data.animal_den_mouths))
	var kinds: Dictionary = {}

	for n in range(0, data.cave_bones.size(), 5):
		kinds[int(data.cave_bones[n + 3])] = Vector3(data.cave_bones[n], data.cave_bones[n + 1], data.cave_bones[n + 2])

	check(kinds.has(4) and kinds.has(5) and kinds.has(0), "droppings, bedding and old bones at a wolf den (%s)" % str(kinds.keys()))

	if kinds.has(4):
		var drop: Vector3 = kinds[4]
		check(drop.x > 1.0 and drop.x < 8.0 and absf(drop.z) > 0.5 and drop.y < 11.4, "the droppings lie a few metres in, off the stream, on the floor (%s)" % str(drop))

	if kinds.has(5):
		check((kinds[5] as Vector3).is_equal_approx(Vector3(8.0, 11.0, 10.0)), "the bed lies at the dry den spot's floor (%s)" % str(kinds[5]))

	var fox = TileTerrainData.new()
	fox._load_caves([floor_cave, cave(yes, "small")])
	var fox_kinds: Array = []

	for n in range(0, fox.cave_bones.size(), 5):
		fox_kinds.append(int(fox.cave_bones[n + 3]))

	check(fox_kinds.count(4) == 1 and fox_kinds.count(5) == 1 and not fox_kinds.has(0), "a fox den has droppings and a bed but no kill bones (%s)" % str(fox_kinds))

	var goblin_id: String = ""

	for n in 400:
		if absi(hash("gob_%d" % n)) % 100 < TileTerrainData.GOBLIN_DEN_PERCENT and absi(hash("gob_%d/animal_den" % n)) % 100 < TileTerrainData.ANIMAL_DEN_PERCENT:
			goblin_id = "gob_%d" % n
			break

	var shared = TileTerrainData.new()
	shared._load_caves([floor_cave, cave(goblin_id, "large")])
	check(shared.goblin_den_mouths.size() == 2 and shared.animal_den_mouths.is_empty(), "a goblin cave holds no animal den (%s)" % goblin_id)

	# The server: a den mouth within reach and empty is where the animal is made; never near a player, never twice.
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.setup()
	a.traits = false
	a.cave_den_mouths = func(_x, _z, sp): return PackedVector2Array([Vector2(200.0, 0.0)]) if sp == "bear" else PackedVector2Array()
	var far: Vector2 = a.cave_den_spot("bear", Vector3(0.0, 10.0, 0.0), [Vector3(0.0, 10.0, 0.0)])
	check(far.is_equal_approx(Vector2(200.0, 0.0)), "a bear cave 200 m from the player is a spawn spot (%s)" % str(far))
	check(a.cave_den_spot("wolf", Vector3(0.0, 10.0, 0.0), [Vector3(0.0, 10.0, 0.0)]).x == INF, "no wolf cave, no spot")
	check(a.cave_den_spot("bear", Vector3(150.0, 10.0, 0.0), [Vector3(150.0, 10.0, 0.0), Vector3(180.0, 10.0, 0.0)]).x == INF, "never with a player beside the mouth")
	check(a.cave_den_spot("bear", Vector3(-200.0, 10.0, 0.0), [Vector3(-200.0, 10.0, 0.0)]).x == INF, "a mouth beyond spawn_max_m is too far")
	var id: int = a.spawn("bear", 200.0, 0.0)
	check(id != 0 and a.animals[id].get("den", Vector3.INF) == Vector3(200.0, 10.0, 0.0), "a bear made at the mouth has its den there")
	check(a.cave_den_spot("bear", Vector3(0.0, 10.0, 0.0), [Vector3(0.0, 10.0, 0.0)]).x == INF, "a den with its bear in it is taken")

	# A wolf pack's 2 km cell takes a wolf cave inside it as its den.
	a.cave_den_mouths = func(_x, _z, sp): return PackedVector2Array([Vector2(2500.0, 300.0)]) if sp == "wolf" else PackedVector2Array()
	check(a.cave_den_in(Rect2(2000.0, 0.0, 2000.0, 2000.0), "wolf").is_equal_approx(Vector2(2500.0, 300.0)), "the wolf cave in the cell is found")
	check(a.cave_den_in(Rect2(0.0, 0.0, 2000.0, 2000.0), "wolf").x == INF, "a cave outside the cell is not")

	print("test_cave_animal_dens: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
