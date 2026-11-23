extends SceneTree

# In a cave the server's ground is the cave floor (physical world audit round 6, 23 Nov 2026): the generated surface is the hill over the cave,
# so a stack dropped in the Ragtooth camp cave hung 1.1 m over its floor, a laid fire, a chest or a torch was refused there ("too far above or
# below the ground", "Push it into the ground") while the ghost showed it fits, and a handcart pulled in rode on the hill's height.
# Real tiles: the Ragtooth camp cave (camp_caves.gd, mouth 58264,72084): its open cut, its passage and its room.
# terrain_generator.floor_below / cave_floor_at; server_items _place, _place_torch, _drop_height; server_carts _rest_y, _grade, _blocked.
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_ground.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const WORLD := "res://worlds/base_world"

# Spots in the camp cave (x, z) with the floor roughly there, and one in the open by the town.
const CUT := Vector2(58265.0, 72087.9)
const PASSAGE := Vector2(58269.4, 72104.3)
const ROOM := Vector2(58271.35, 72111.43)
const OPEN := Vector2(58190.0, 71400.0)

var failures: int = 0
var gen
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# The cave floor at (x, z), from a metre over the floor near `guess`.
func floor_at(at: Vector2, guess: float) -> float:
	return float(gen.cave_floor_at(Vector3(at.x, guess + 1.0, at.y)))


func newest() -> Dictionary:
	return items._items[items._next_id - 1] if items._items.has(items._next_id - 1) else {}


func _init() -> void:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	gen = GeneratorScript.new()
	gen.setup(settings, rules, tables, WORLD + "/tiles")
	gen.get_tile(gen.tile_of(ROOM.x, ROOM.y))
	gen.get_tile(gen.tile_of(OPEN.x, OPEN.y))

	# The floors: in the cave's air, well under the hill (the open cut: under the tile's ground, which does not know the cut).
	var floors: Dictionary = {}

	for spot in [[CUT, 6.6, 0.5], [PASSAGE, 7.5, 2.5], [ROOM, 7.0, 2.5]]:
		var f: float = floor_at(spot[0], spot[1])
		floors[spot[0]] = f
		var hill: float = gen.surface_height(spot[0].x, spot[0].y)
		check(not is_nan(f) and absf(f - float(spot[1])) < 1.0 and hill - f > float(spot[2]), "cave floor at %s is %.2f, the surface over it %.2f" % [str(spot[0]), f, hill])
		var rest: float = gen.floor_below(Vector3(spot[0].x, f + 1.0, spot[0].y), [])
		check(absf(rest - f) < 0.15, "a stack let go a metre over that floor comes to rest on it (%.2f)" % rest)

	check(is_nan(float(gen.cave_floor_at(Vector3(ROOM.x, floors[ROOM] + 4.9, ROOM.y)))), "in the rock over the room there is no cave floor")
	var open_ground: float = gen.surface_height(OPEN.x, OPEN.y)
	check(is_nan(float(gen.cave_floor_at(Vector3(OPEN.x, open_ground + 1.0, OPEN.y)))), "in the open there is no cave floor")
	check(absf(gen.floor_below(Vector3(OPEN.x, open_ground + 1.0, OPEN.y), []) - open_ground) <= 0.1, "in the open a stack comes to rest on the surface, as before")
	var hill_over: float = gen.surface_height(ROOM.x, ROOM.y)

	for into in [0.1, 0.3, 0.45]:
		check(is_nan(float(gen.cave_floor_at(Vector3(ROOM.x, hill_over - into, ROOM.y)))), "on the hill over the room, %.2f m into its ground: no cave floor (the hill's own ground stands)" % into)

	for over in [ROOM, PASSAGE, Vector2(58275.0, 72118.0), Vector2(58262.0, 72110.0)]:
		var top: float = gen.surface_height(over.x, over.y)
		check(is_nan(float(gen.cave_floor_at(Vector3(over.x, top + 1.0, over.y)))) and absf(gen.floor_below(Vector3(over.x, top + 1.0, over.y), []) - top) <= 0.1, "a stack let go over the hill above the cave at %s rests on the hill %.2f (%.2f), not on the ground without its detail" % [str(over), top, gen.floor_below(Vector3(over.x, top + 1.0, over.y), [])])

	check(is_nan(float(gen.cave_floor_at(Vector3(20000.0, 5.0, 20000.0)))), "a tile not in memory: no cave floor, and none is loaded")
	check(absf(gen.floor_below(Vector3(ROOM.x, floors[ROOM] + 1.0, ROOM.y), [[0, Vector3(ROOM.x, floors[ROOM], ROOM.y), 0.6]]) - (floors[ROOM] - 0.6)) < 0.15, "a dig in the cave floor: a stack falls into its hole")

	# The server: drops, a laid fire, a chest and a torch in the room and the passage.
	var dir: String = "user://test_cave_ground"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(x, z): return gen.surface_height(x, z)
	items.floor_below = func(p: Vector3) -> float: return gen.floor_below(p, [])
	items.cave_floor = gen.cave_floor_at
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "caveground001")
	var feet: Vector3 = Vector3(ROOM.x, floors[ROOM], ROOM.y)
	items.report_position(1, feet)

	items.give_to(1, "stone", 3)
	var inv = items.inventory_of(1)
	items.action(1, Net.ACT_DROP, inv.numbers.find(items.table.number_of("stone")), 0, 1, feet + Vector3(0.8, 0.0, 0.0))
	var dropped: Dictionary = newest()
	var drop_floor: float = floor_at(Vector2(ROOM.x + 0.8, ROOM.y), floors[ROOM])
	check(not dropped.is_empty() and absf(float(dropped["pos"].y) - drop_floor) < 0.15, "a stone dropped in the room lies on its floor %.2f (%s)" % [drop_floor, str(dropped.get("pos", "none"))])

	for kit in ["campfire_kit", "chest_kit"]:
		said.clear()
		var at: Vector3 = Vector3(ROOM.x + (-1.2 if kit == "campfire_kit" else 1.4), 0.0, ROOM.y - 0.6)
		at.y = floor_at(Vector2(at.x, at.z), floors[ROOM])
		var before: int = items._next_id
		items.give_to(1, kit, 1)
		items.place_item(1, items.table.number_of(kit), at, 0, 0)
		var placed: Dictionary = {}

		for id in range(before, items._next_id):
			if items._items.has(id) and (items._items[id].has("struct") or items._items[id].has("fire")):
				placed = items._items[id]

		check(not placed.is_empty() and absf(float(placed["pos"].y) - at.y) < 0.3, "a %s set down in the room stands on its floor %.2f (%s, said %s)" % [kit, at.y, str(placed.get("pos", "none")), str(said)])

	said.clear()
	var torch_at: Vector3 = Vector3(PASSAGE.x, floors[PASSAGE], PASSAGE.y)
	items.report_position(1, torch_at + Vector3(0.0, 0.0, 1.0))
	items.give_to(1, "torch", 1)
	var torch_before: int = items._next_id
	items._place_torch(1, items.inventory_of(1), items.inventory_of(1).numbers.find(items.table.number_of("torch")), false, 0, torch_at)
	var torch: Dictionary = items._items.get(torch_before, {})
	check(not torch.is_empty() and absf(float(torch["pos"].y) - torch_at.y) < 0.1, "a torch pushed into the passage floor stands there (%s, said %s)" % [str(torch.get("pos", "none")), str(said)])

	said.clear()
	var cut_at: Vector3 = Vector3(CUT.x, floors[CUT], CUT.y)
	items.report_position(1, cut_at + Vector3(0.0, 0.0, -1.0))
	items.give_to(1, "torch", 1)
	var cut_before: int = items._next_id
	items._place_torch(1, items.inventory_of(1), items.inventory_of(1).numbers.find(items.table.number_of("torch")), false, 0, cut_at)
	check(items._items.has(cut_before) and absf(float(items._items[cut_before]["pos"].y) - cut_at.y) < 0.1, "a torch pushed into the floor of the mouth's open cut stands there (said %s)" % str(said))

	# Pressed into the rock over the cave: still refused.
	said.clear()
	var hill_at: Vector3 = Vector3(ROOM.x, floors[ROOM] + 2.0, ROOM.y + 8.0)
	items.report_position(1, Vector3(ROOM.x, floors[ROOM], ROOM.y + 4.0))
	items.give_to(1, "campfire_kit", 1)
	var refused_before: int = items._next_id
	items.place_item(1, items.table.number_of("campfire_kit"), hill_at, 0, 0)
	check(items._next_id == refused_before or not items._items.has(refused_before), "a laid fire aimed inside the rock beyond the room is refused (%s)" % str(said))

	# A handcart in the passage rests on the cave floor, its grade is the floor's, and the rock beside the passage stops it.
	var carts = items._carts
	var cart_at: Vector3 = Vector3(PASSAGE.x, floors[PASSAGE], PASSAGE.y)
	var step_to: Vector3 = cart_at + Vector3(0.26, 0.0, 0.97) * 0.5
	check(absf(carts._rest_y(step_to, cart_at.y) - floor_at(Vector2(step_to.x, step_to.z), cart_at.y)) < 0.15, "a cart stepping along the passage rests on its floor (%.2f, the hill %.2f)" % [carts._rest_y(step_to, cart_at.y), gen.surface_height(step_to.x, step_to.z)])
	check(carts._grade(cart_at, Vector2(0.26, 0.97)) < 0.36, "the passage floor's grade under the cart is the floor's (%.2f), not the hill's" % carts._grade(cart_at, Vector2(0.26, 0.97)))
	var side: Vector3 = cart_at + Vector3(0.966, 0.0, -0.259) * 3.0   # across the 2.2 m passage: into its wall
	check(carts._blocked(cart_at, side, Vector2(0.966, -0.259), {"fit_m": 0.6}) != "", "the cart cannot be pulled into the passage wall")

	# Pulled out along the passage, through the open cut and past the mouth: never stopped (the end of the cut rises to the surface, where the
	# cave floor reads as none within 0.5 m of it), and on the floor or the ground all the way.
	var out_dir: Vector3 = Vector3(-0.259, 0.0, -0.966)
	var pos: Vector3 = cart_at
	var stopped: String = ""
	var worst_gap: float = 0.0

	for n in 120:
		var to: Vector3 = pos + out_dir * 0.3
		var why: String = carts._blocked(pos, to, Vector2(out_dir.x, out_dir.z), {"fit_m": 0.6})

		if why != "":
			stopped = "%s at %s" % [why, str(pos)]
			break

		to.y = carts._rest_y(to, pos.y)
		var under: float = gen.cave_floor_at(Vector3(to.x, to.y + 0.5, to.z))
		worst_gap = maxf(worst_gap, absf(to.y - (under if not is_nan(under) else gen.surface_height(to.x, to.z))))
		pos = to

	check(stopped == "" and Vector2(pos.x - 58264.0, pos.z - 72084.0).dot(Vector2(out_dir.x, out_dir.z)) > 3.0, "a cart pulled out of the passage leaves by the open cut and goes past the mouth (%s, ends at %s)" % [stopped, str(pos)])
	check(worst_gap < 0.6, "on its way out it rests on the cave floor or the ground (worst %.2f m off)" % worst_gap)

	print("test_cave_ground: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
