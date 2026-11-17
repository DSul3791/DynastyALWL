extends SceneTree

# Edda and Hob's camp under the oak (Dave 17 Nov 2026; data/npcs/camp.json, src/shared/npc_camp.gd). Checks, on the real code and data:
# - the flora placer still stands a sheltering tree at the camp tree's foot, the fire spot is under its rain shelter (Cover index, as the server
#   fills it) and the two NPC spots are clear of trees and shrubs (the camp markers clear no wood);
# - Hob takes his own post and Edda her own chair there, facing the fire, and the town's middle does not move;
# - the server lays the large camp fire, keeps it lit in rain, never saves it, lays it again when it goes, and refuses every use of it;
# - nothing is put down within keep_m of the tree (the ghost and the server), and the server's tree hit refuses the camp tree.
#   godot --headless --path . --script res://src/worldgen/tools/test_npc_camp.gd

const NpcCamp := preload("res://src/shared/npc_camp.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var tree: Vector2 = NpcCamp.tree_spot()
	var fire: Vector2 = NpcCamp.fire_spot()
	var markers: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/markers.json")) as Dictionary)["markers"]
	var own: Dictionary = {}   # npc id -> marker row

	for m in markers:
		if m.has("npc"):
			own[str(m["npc"])] = m

	check(tree.x != INF and fire.x != INF, "camp.json gives the tree and the fire")
	check(own.has("hob") and own.has("edda"), "Hob and Edda each have their own camp marker")
	_flora(tree, fire, own)
	_npcs(fire, own)
	_server(tree, fire)
	print("npc camp: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# The real placer: the oak stands where camp.json says, shelters the fire, and the camp spots stand clear.
func _flora(tree: Vector2, fire: Vector2, own: Dictionary) -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var index = CoverScript.Index.new()
	var blockers: Array = []   # [Vector2 foot, name]
	var oak: Array = []
	var lo: Vector2i = placer.chunk_of(tree.x - 20.0, tree.y - 20.0)
	var hi: Vector2i = placer.chunk_of(tree.x + 20.0, tree.y + 20.0)

	for ci in range(lo.x, hi.x + 1):
		for cj in range(lo.y, hi.y + 1):
			var made: Dictionary = placer.chunk_items(Vector2i(ci, cj))
			CoverScript.add_chunk(index, Vector2i(ci, cj), made, func(species_id: int) -> Array:   # as server_flora._fill_cover
				var item: Dictionary = placer.species_by_id(species_id)
				return [] if item.is_empty() else [int(item["kind"]), float(item["crown"]), float(item["height_ref"]), CoverScript.is_deciduous(str(item.get("name", "")))])

			for n in range(made["ids"].size()):
				var row: Dictionary = placer.species_of(made["ids"][n])
				var p: Vector3 = made["positions"][n]

				if row.is_empty() or int(row["kind"]) > PlacerScript.KIND_SHRUB:
					continue

				blockers.append([Vector2(p.x, p.z), str(row["name"])])

				if int(row["kind"]) == PlacerScript.KIND_TREE and NpcCamp.is_camp_tree(p):
					oak = [str(row["name"]), p, float(made["heights"][n])]

	check(not oak.is_empty(), "a placer tree stands at the camp tree's foot %s" % str(tree))

	if oak.is_empty():
		return

	check(float(oak[2]) >= CoverScript.SHELTER_MIN_HEIGHT_M, "the camp tree (%s, %.1f m) is tall enough to shelter" % [oak[0], float(oak[2])])
	check(index.covers(Vector3(fire.x, float(oak[1].y) + 0.3, fire.y)), "the fire spot is inside the camp tree's rain shelter")
	var inside: float = float(NpcCamp.cfg()["fire"].get("inside_m", 1.0))
	var shelter_m: float = float(NpcCamp.cfg()["tree"].get("shelter_m", 0.0))
	check(absf(fire.distance_to(tree) - (shelter_m - inside)) < 0.1, "the fire is %.1f m inside the shelter line (%.2f m from the trunk)" % [inside, fire.distance_to(tree)])

	for id in own:
		var at: Vector2 = Vector2(float(own[id]["x"]), float(own[id]["z"]))

		for b in blockers:
			check((b[0] as Vector2).distance_to(at) >= 1.5, "%s's spot is 1.5 m clear of the %s at %s" % [id, b[1], str(b[0])])

	print("camp tree: %s at %.2f, %.2f, %.1f m tall" % [oak[0], oak[1].x, oak[1].z, float(oak[2])])


# Hob takes his post and Edda her chair at the camp, turned to the fire; the town's middle is the old markers' middle.
func _npcs(fire: Vector2, own: Dictionary) -> void:
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = false   # the shipped hold: Hob at work, Edda sitting, all day
	npcs.hour_now = func(): return 12.0
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.rain_now = func(): return 1.0   # rain does not send them off: they are under the oak
	npcs.player_positions = func(): return [Vector3(fire.x, 10.0, fire.y)]
	npcs.setup("")
	npcs.tick(0.2)

	for id in ["hob", "edda"]:
		var npc: Dictionary = npcs.npcs[id]
		var spot: Vector2 = Vector2(float(own[id]["x"]), float(own[id]["z"]))
		check(Vector2(npc["pos"].x, npc["pos"].z).distance_to(spot) < 0.01, "%s stands at the camp (%s)" % [id, str(npc["pos"])])
		var facing: Vector2 = Vector2(cos(float(npc["heading"])), sin(float(npc["heading"])))
		check(facing.dot((fire - spot).normalized()) > 0.99, "%s faces the fire" % id)

	check(int(npcs.npcs["hob"]["state"]) == npcs.STAND and int(npcs.npcs["edda"]["state"]) == npcs.SIT, "Hob stands, Edda sits")

	# Another NPC never takes a camp spot.
	npcs._add_npc({"id": "stranger", "name": "S", "schedule": []}, Vector3(fire.x, 0.0, fire.y))
	check(not str(npcs._claim(npcs.npcs["stranger"], "post")).begins_with("camp_"), "a stranger never takes Hob's post")
	var mid: Vector2 = Vector2.ZERO
	var n: int = 0

	for m in (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/markers.json")) as Dictionary)["markers"]:
		if not m.has("npc"):
			mid += Vector2(float(m["x"]), float(m["z"]))
			n += 1

	check(npcs.town_point().distance_to(mid / float(n)) < 0.01, "the town's middle leaves the camp spots out")
	NpcsScript.test_hold_off = false


# The server's camp fire and the ground kept clear round the tree.
func _server(tree: Vector2, fire: Vector2) -> void:
	var dir: String = "user://test_npc_camp"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var said: Array = []
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.rain_now = func(): return 1.0
	items.respawn_point = Vector3(fire.x + 30.0, 10.0, fire.y)
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true
	items.peer_connected_hello(1, "camp-test-key01")
	items._camp_fire_tick()
	check(not items._items.has(items._camp_fire_id) or items._camp_fire_id == 0, "no camp fire unless the server scene asks for it")
	items.camp_fire_on = true
	items._camp_fire_tick()
	var id: int = items._camp_fire_id
	check(items._items.has(id), "the camp fire is laid")

	if not items._items.has(id):
		return

	var it: Dictionary = items._items[id]
	check(int(it["fire"]["state"]) == items.FIRE_STATE_BONFIRE and items.fire_is_lit(int(it["fire"]["state"])), "it is a large fire, burning")
	check(items._fire_extra(it) == {"camp": 1}, "its row tells clients it is the camp fire, with no burn time")
	items._fires(600.0)
	check(int(it["fire"]["state"]) == items.FIRE_STATE_BONFIRE, "heavy rain and ten minutes leave it burning")
	check(items.lit_fire_near(Vector3(fire.x, 10.0, fire.y), 1.0), "it warms and keeps wolves off like any lit fire")

	# Every use is refused, beside it.
	items.report_position(1, Vector3(fire.x + 1.5, 10.0, fire.y))
	var inv = items.inventory_of(1)
	inv.add(items.table.number_of("stick"), 5)

	for act in [Net.ACT_USE_STRUCT, Net.ACT_PICKUP, Net.ACT_FUEL, Net.ACT_LIGHT, Net.ACT_COOK, Net.ACT_CHEST_OPEN]:
		said.clear()
		items.action(1, act, id, 0, 0, Vector3.ZERO)
		check(items._items.has(id) and int(items._items[id]["fire"]["state"]) == items.FIRE_STATE_BONFIRE, "action %d leaves the camp fire as it was" % act)
		check(said.any(func(t): return str(t).contains("Edda and Hob")), "action %d says whose fire it is (%s)" % [act, str(said)])

	check(inv.count_of(items.table.number_of("stick")) == 5, "no stick went into it")
	check(items.serving_station(1, "campfire") < 0, "nobody cooks at it")

	# Never saved; laid again when cleared.
	items._dirty = true
	items.save()
	items._finish_writer()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/world_items.json"))
	check(typeof(saved) == TYPE_DICTIONARY, "the world items were saved")
	var in_save: bool = false

	for row in (saved as Dictionary).get("items", []) if typeof(saved) == TYPE_DICTIONARY else []:
		in_save = in_save or Vector2(float(row[2]), float(row[4])).distance_to(fire) < 0.5

	check(not in_save, "the camp fire is not in the save")
	items._items.erase(id)
	items._camp_fire_tick()
	check(items._items.has(items._camp_fire_id) and items._camp_fire_id != id, "a cleared camp fire is laid again")

	# Nothing is put down near the tree: the ghost's rule and the server's.
	var cfg: Dictionary = PlacementRules.load_config()
	check(PlacementRules.blocked(cfg, "campfire_kit", Vector3(fire.x + 1.0, 10.0, fire.y + 1.0), []) == "camp", "the ghost is red by the camp")
	check(PlacementRules.blocked(cfg, "campfire_kit", Vector3(tree.x + 20.0, 10.0, tree.y), []) == "", "and free 20 m off")
	check(NpcCamp.within_keep(Vector3(tree.x, 0.0, tree.y + float(NpcCamp.cfg()["keep_m"]) - 0.1)) and not NpcCamp.within_keep(Vector3(tree.x, 0.0, tree.y + float(NpcCamp.cfg()["keep_m"]) + 0.1)), "keep_m is the edge")
	inv.add(items.table.number_of("campfire_kit"), 1)
	var fires_before: int = items._items.size()
	said.clear()
	items.report_position(1, Vector3(tree.x + 3.0, 10.0, tree.y + 3.0))
	items.action(1, Net.ACT_PLACE, inv.numbers.find(items.table.number_of("campfire_kit")), 0, 0, Vector3(tree.x + 3.5, 10.0, tree.y + 3.5))
	check(items._items.size() == fires_before and said.any(func(t): return str(t).contains("Edda and Hob's camp")), "the server refuses a fire by the camp (%s)" % str(said))

	# The tree: a blow on it is refused before any work is done.
	items.tree_info = func(_c, _i): return {"name": "oak", "position": Vector3(tree.x, 10.0, tree.y), "height": 12.7, "trunk": 0.6, "ref_height": 20.0, "broadleaf": true, "id": 1}
	items.cut_tree = func(_c, _i): return true
	var axe: int = items.table.number_of("stone_axe")
	inv.add(axe, 1)
	said.clear()
	items._last_hit.clear()
	items.report_position(1, Vector3(tree.x + 1.0, 10.0, tree.y))
	items.action(1, Net.ACT_HIT, 1, 0, 0, Vector3(float(inv.numbers.find(axe) + 1), 0.0, 0.0))
	check(items._chops.is_empty() and said.any(func(t): return str(t).contains("shelters Edda and Hob's camp")), "an axe on the camp tree does nothing (%s)" % str(said))
