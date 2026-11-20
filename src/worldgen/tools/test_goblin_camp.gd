extends SceneTree

# The Ragtooth goblin camp (Dave 19 Nov 2026: a goblin camp in a cave near a river, goblins "apprehensive but willing to communicate and trade/buy
# and sell", later tribes friendly, unfriendly, indifferent; data/creatures/goblin_tribes.json, src/stream/server_tribes.gd). Checks, on the real
# code and data:
# - every member has a dialogue file and a voice, the trader a shop of real items, and no member takes a townsperson's id;
# - the camp is at the mouth of a baked spring cave that holds no wild goblin band, a river runs near it, and every spot is dry, on ground of at
#   most 20 degrees and clear of the cave's opening (the baked tile, as island_checks.gd reads it);
# - the members stand at their spots; one backs off from a stranger who comes too close (never past its leash), holds still just outside, watches
#   a player inside watch_m, keeps further from a weapon carrier and lets a friend of the tribe closer;
# - standing is the tribe's: earned with one member it counts with every member, a deal earns it at most once a game day;
# - a blow at a member hurts nobody: the tribe refuses that character talk and trade, the members go into the cave mouth out of sight while that
#   character is near and come out when they go;
# - the server lays the tribe's camp fire beside Edda and Hob's, refuses every use of it in the tribe's name, and nothing is put down near it.
#   godot --headless --path . --script res://src/worldgen/tools/test_goblin_camp.gd

const NpcCamp := preload("res://src/shared/npc_camp.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const TribesScript := preload("res://src/stream/server_tribes.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")
const DialogueScript := preload("res://src/stream/server_dialogue.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const TILE_M := 15360.0          # worlds/base_world/world.json tile_size_m
const MAX_SLOPE_DEG := 20.0      # island_checks.gd marker_max_slope_deg
const RIVER_M := 80.0            # "near a river"
const OPENING_M := 5.0           # a spot stands at least this far from the cave mouth (the mouth's radius is about 4 m)

var failures: int = 0
var tribe: Dictionary = {}
var camp: Dictionary = {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TribesScript.PATH))
	check(data.get("tribes", {}).has("ragtooth"), "goblin_tribes.json has the Ragtooth tribe")
	tribe = data["tribes"]["ragtooth"]
	camp = tribe["camp"]
	check(data.get("attitudes", {}).has(str(tribe["attitude"])), "the tribe's attitude has a row")

	for att in ["friendly", "wary", "indifferent", "unfriendly", "hostile"]:
		check(data["attitudes"].has(att), "the %s attitude is ready for a later tribe" % att)

	_data()
	_tile()
	_npcs()
	_server()
	print("goblin camp: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _data() -> void:
	var town: Dictionary = {}

	for row in (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/npcs.json")) as Dictionary)["npcs"]:
		town[str(row["id"])] = true

	var voices: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/voices.json")) as Dictionary)["voices"]
	var shops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/shops.json"))
	var table = ItemTableScript.load_default()
	var traders: int = 0

	for m in tribe["members"]:
		var id: String = str(m["id"])
		check(not town.has(id), "%s is not a townsperson's id" % id)
		check(FileAccess.file_exists("res://data/npcs/dialogue/%s.json" % id), "%s has a dialogue file" % id)
		check(voices.has(str(m["voice"])), "%s's voice is in voices.json" % id)

		if bool(m.get("trader", false)):
			traders += 1
			check(shops.has(id), "the trader %s has a shop" % id)

			for item in shops.get(id, {}).get("stock", []):
				check(table.number_of(str(item)) > 0, "%s sells a real item (%s)" % [id, item])

	check(traders == 1, "the camp has one trader")


# The baked tile: the cave, the river, the ground under every spot.
func _tile() -> void:
	var mouth: Vector2 = Vector2(float(camp["mouth"]["x"]), float(camp["mouth"]["z"]))
	var tile: Vector2i = Vector2i(int(floor(mouth.x / TILE_M)), int(floor(mouth.y / TILE_M)))
	var path: String = "res://worlds/base_world/tiles/tile_%d_%d.tile" % [tile.x, tile.y]

	if not FileAccess.file_exists(path):
		print("goblin camp: %s is not baked here, the ground checks are skipped" % path)
		return

	var head: Dictionary = TileFileScript.read_header(path)
	var sites: Dictionary = TileFileScript.read_list(path, head["table"], "sites")["value"]
	var cave: Dictionary = {}

	for c in sites.get("caves", []):
		if str(c.get("id", "")) == str(camp["cave"]):
			cave = c

	check(not cave.is_empty(), "the camp's cave %s is in the tile" % camp["cave"])

	if cave.is_empty():
		return

	var entrance: Array = cave["nodes"][int(cave["entrances"][0])]
	check(Vector2(float(entrance[0]), float(entrance[2])).distance_to(mouth) < 1.5, "the camp's mouth is the cave's entrance (%s)" % str(entrance))
	check(str(cave.get("cave_kind", "")) == "spring_cave", "the cave is a spring cave, where a river starts")
	check(TileTerrainData.goblin_den_node(cave) < 0, "no wild goblin band lives in this cave")
	var n: int = int(head["header"]["samples"])
	var spacing: float = float(head["header"]["map_spacing_m"])
	var heights: PackedFloat32Array = TileFileScript.decode_height(TileFileScript.read_section(path, head["table"], "height")["raw"], TileFileScript.height_step_of(head["header"]))
	var water: PackedByteArray = TileFileScript.read_section(path, head["table"], "water_class")["raw"]
	var cell = func(at: Vector2) -> Vector2i: return Vector2i(int(round((at.x - float(tile.x) * TILE_M) / spacing)), int(round((at.y - float(tile.y) * TILE_M) / spacing)))
	var river: float = INF
	var c0: Vector2i = cell.call(mouth)
	var reach: int = int(ceil(RIVER_M / spacing))

	for j in range(c0.y - reach, c0.y + reach + 1):
		for i in range(c0.x - reach, c0.x + reach + 1):
			if water[j * n + i] == 3:   # water_classes.json: river
				river = minf(river, Vector2(float(tile.x) * TILE_M + i * spacing, float(tile.y) * TILE_M + j * spacing).distance_to(mouth))

	check(river <= RIVER_M, "a river runs %.0f m from the mouth" % river)
	var spots: Array = [["the fire", Vector2(float(camp["fire"]["x"]), float(camp["fire"]["z"]))]]

	for m in tribe["members"]:
		spots.append([str(m["id"]), Vector2(float(m["spot"]["x"]), float(m["spot"]["z"]))])

	for prop in camp.get("props", []):
		spots.append(["the %s" % str(prop["kind"]), Vector2(float(prop["x"]), float(prop["z"]))])

	for s in spots:
		var c: Vector2i = cell.call(s[1])
		var dx: float = (heights[c.y * n + c.x + 1] - heights[c.y * n + c.x - 1]) / (2.0 * spacing)
		var dz: float = (heights[(c.y + 1) * n + c.x] - heights[(c.y - 1) * n + c.x]) / (2.0 * spacing)
		var slope: float = rad_to_deg(atan(Vector2(dx, dz).length()))
		var wet: bool = false

		for b in range(-1, 2):
			for a in range(-1, 2):
				wet = wet or water[(c.y + b) * n + c.x + a] != 0

		check(not wet and slope <= MAX_SLOPE_DEG, "%s stands dry on ground of %.1f degrees" % [s[0], slope])
		check((s[1] as Vector2).distance_to(mouth) >= OPENING_M, "%s is clear of the cave's opening (%.1f m)" % [s[0], (s[1] as Vector2).distance_to(mouth)])


func _items(dir: String, said: Array):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true
	return items


# The members at their spots, keeping off, watching, standing per tribe and anger.
func _npcs() -> void:
	var said: Array = []
	var items = _items("user://test_goblin_camp", said)
	items.peer_connected_hello(1, "goblin-test-key1")
	var skritch: Dictionary = {}

	for m in tribe["members"]:
		if str(m["id"]) == "skritch":
			skritch = m

	var spot: Vector3 = Vector3(float(skritch["spot"]["x"]), 10.0, float(skritch["spot"]["z"]))
	var player: Array = [spot + Vector3(-30.0, 0.0, 0.0)]
	var npcs = NpcsScript.new()
	npcs.hour_now = func(): return 3.0   # the middle of the night: the town sleeps, the goblins keep their spots
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.player_positions = func(): return player
	npcs.setup("")
	var clock: Array = [0.0]
	var tribes = TribesScript.new()
	tribes.items = items
	tribes.npcs = npcs
	tribes.game_seconds = func(): return clock[0]
	tribes.players = func() -> Array: return [{"peer": 1, "key": "goblin-test-key1", "pos": player[0]}]
	tribes.setup("")
	npcs.wary = tribes.avoid
	items.rep_key = tribes.rep_id
	items.report_position(1, player[0])
	var run = func(seconds: float) -> void:
		for k in int(seconds * 10.0):
			tribes.tick(0.1)
			npcs.tick(0.1)

	run.call(1.0)

	for m in tribe["members"]:
		var npc: Dictionary = npcs.npcs[str(m["id"])]
		check(Vector2(npc["pos"].x, npc["pos"].z).distance_to(Vector2(float(m["spot"]["x"]), float(m["spot"]["z"]))) < 0.5, "%s stands at its spot by night" % m["id"])
		check(str(npc["tribe"]) == "ragtooth" and str(npc["outfit"]) == "goblin:%d" % int(m["body"]), "%s is a Ragtooth goblin with its look" % m["id"])

	# A stranger walks up slowly: the trader lets them to its trader keep distance (inside talking range), and backs off from closer.
	var att: Dictionary = data_att()
	var keep: float = float(att["trader_keep_m"]["Stranger"])
	check(keep < 3.0, "a stranger can come within the client's talk reach of the trader (dialogue_view.gd 3 m; keeps %.1f m)" % keep)
	var npc_s: Dictionary = npcs.npcs["skritch"]
	player[0] = spot + Vector3(-(keep - 1.5), 0.0, 0.0)
	items.report_position(1, player[0])
	run.call(6.0)   # the jump there reads as a rush at first (it backs off further), then it settles at the calm distance
	var d: float = Vector2(npc_s["pos"].x - player[0].x, npc_s["pos"].z - player[0].z).length()
	check(d >= keep - 0.3, "the trader backs off from a stranger too near (%.2f m, keeps %.1f)" % [d, keep])
	check(Vector2(npc_s["pos"].x - spot.x, npc_s["pos"].z - spot.z).length() <= float(tribes.cfg["leash_m"]) + 0.01, "never past its leash")
	var facing: Vector2 = Vector2(cos(float(npc_s["heading"])), sin(float(npc_s["heading"])))
	check(facing.dot(Vector2(player[0].x - npc_s["pos"].x, player[0].z - npc_s["pos"].z).normalized()) > 0.9, "and keeps its eyes on them")
	var held: Vector3 = npc_s["pos"]
	run.call(3.0)
	check(npc_s["pos"].distance_to(held) < 0.05, "it holds still with the player just outside its keep distance")
	check(tribes.refuse(1, "skritch") == "", "a calm stranger may talk to the trader")

	# Pressing it all the way: it stops at the end of its leash, cornered, and still faces the player.
	for k in 20:
		player[0] = npc_s["pos"] + Vector3(-1.0, 0.0, 0.0)
		run.call(0.5)

	check(Vector2(npc_s["pos"].x - spot.x, npc_s["pos"].z - spot.z).length() <= float(tribes.cfg["leash_m"]) + 0.01, "pushed, it stops at its leash (%.2f m from its spot)" % Vector2(npc_s["pos"].x - spot.x, npc_s["pos"].z - spot.z).length())

	# A weapon on the hotbar: it keeps further off and will not talk.
	player[0] = spot + Vector3(-30.0, 0.0, 0.0)
	run.call(20.0)
	var inv = items.inventory_of(1)
	var bag_from: int = inv.bag_from
	inv.bag_from = 0   # onto the hotbar, as server_items gives in hand
	inv.add(items.table.number_of("spear"), 1)
	inv.bag_from = bag_from
	check(tribes.armed(1), "a spear on the hotbar counts as a weapon carried")
	var near_p: Dictionary = {"peer": 1, "key": "goblin-test-key1", "pos": spot + Vector3(-5.0, 0.0, 0.0)}
	check(tribes.keep_from("skritch", near_p) >= keep + float(att["armed_keep_m"]) - 0.01, "a weapon carrier is kept further off")
	check(tribes.refuse(1, "skritch") != "", "and is refused talk (%s)" % tribes.refuse(1, "skritch"))
	check(tribes.refuse(1, "skritch", false) == "", "a deal already open goes on")
	inv.remove(items.table.number_of("spear"), 1)
	check(not tribes.armed(1), "the spear is gone")

	# Standing is the tribe's.
	check(tribes.rep_id("skritch") == tribes.rep_id("rukz") and tribes.rep_id("hob") == "hob", "one standing for the tribe, Hob keeps his own")
	items.add_rep(1, "skritch", 5)
	check(items.rep_points(1, "rukz") == 5 and items.rank_of(items.rep_points(1, "snag")) == "Friend", "standing earned with Skritch counts with Rukz and Snag")
	check(tribes.keep_from("skritch", near_p) <= float(att["trader_keep_m"]["Friend"]) + 0.01, "a friend of the tribe may come closer")
	check(tribes.name_of_rep(tribes.rep_id("skritch")) == str(tribe["name"]), "the standing is named for the tribe")
	tribes.note_deal(1, "skritch")
	tribes.note_deal(1, "rukz")
	check(items.rep_points(1, "skritch") == 6, "a deal earns standing once a game day (%d)" % items.rep_points(1, "skritch"))
	clock[0] += TribesScript.DAY_S
	tribes.note_deal(1, "skritch")
	check(items.rep_points(1, "skritch") == 7, "and again the next day")

	# A blow at a member: nobody is hurt, the tribe turns on that character, the members hide while they are near.
	var origin: Vector3 = npc_s["pos"] + Vector3(-1.5, 1.0, 0.0)
	check(tribes.member_along(origin, Vector3(1.0, 0.0, 0.0), 3.0) == "skritch", "a blow at Skritch finds Skritch")
	check(tribes.member_on_segment(origin, origin + Vector3(5.0, -0.4, 0.0)) == "skritch", "so does an arrow through it")
	said.clear()
	tribes.harm(1, "skritch")
	check(tribes.angry("ragtooth", "goblin-test-key1") and said.size() == 1, "the tribe turns on the striker, and says so (%s)" % str(said))
	check(tribes.refuse(1, "rukz") != "" and tribes.refuse(1, "skritch", false) != "", "every member refuses them talk and trade")
	player[0] = npc_s["pos"] + Vector3(-6.0, 0.0, 0.0)
	run.call(30.0)
	var mouth: Vector3 = Vector3(float(camp["mouth"]["x"]), 10.0, float(camp["mouth"]["z"]))
	check(bool(npc_s.get("hidden", false)) and npc_s["pos"].distance_to(mouth) <= 1.5, "Skritch goes into the cave mouth (%s)" % str(npc_s["pos"]))
	check(npcs.rows_near(player[0]).all(func(row): return str(row[0]) != "skritch"), "and is not seen")
	check(tribes.member_along(player[0], (mouth - player[0]).normalized(), 10.0) == "", "nobody in the cave can be struck")
	player[0] = mouth + Vector3(-80.0, 0.0, 0.0)
	run.call(30.0)
	check(not bool(npc_s.get("hidden", false)), "it comes out when they go")
	clock[0] += float(att["anger_game_days"]) * TribesScript.DAY_S + 1.0
	check(not tribes.angry("ragtooth", "goblin-test-key1") and tribes.refuse(1, "skritch") == "", "after anger_game_days they deal again")

	# The trade window and the talk go through the refusal.
	var trade = TradeScript.new()
	trade.items = items
	trade.npcs = npcs
	trade.setup("")
	var opened: Array = []
	trade.send_shop = func(_peer, npc, _t, _ids, _p, _g, _b, _ti, _tr, _st, _su, _pu): opened.append(npc)
	trade.refuse = tribes.refuse
	player[0] = npc_s["pos"] + Vector3(-float(att["trader_keep_m"]["Trusted"]) - 1.0, 0.0, 0.0)
	items.report_position(1, player[0])
	run.call(3.0)
	check(trade.open(1, "skritch") and opened == ["skritch"], "Skritch's trade pile opens for a calm player")
	tribes.harm(1, "skritch")
	check(not trade.open(1, "skritch") and opened.size() == 1, "and not for one the tribe is angry with")
	check(trade.deal(1, "skritch", 0, 0, 1) != "" and not str(trade.deal(1, "skritch", 0, 0, 1)).begins_with("Bought"), "a deal in an open window is refused too")
	var talk = DialogueScript.new()
	talk.items = items
	talk.npcs = npcs
	talk.trade = trade
	var lines: Array = []
	talk.send_say = func(_peer, _id, _n, text, _v, _c, ends): lines.append([text, ends])
	talk.setup("")
	talk.refuse = tribes.refuse
	talk.talk(1, "skritch", -1)
	check(lines.size() == 1 and bool(lines[0][1]) and str(lines[0][0]).contains("No talk"), "the talk ends at once with why (%s)" % str(lines))


func data_att() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string(TribesScript.PATH)) as Dictionary)["attitudes"][str(tribe["attitude"])]


# The camp fire beside Edda and Hob's, and the ground kept clear round it.
func _server() -> void:
	var said: Array = []
	var items = _items("user://test_goblin_camp_fire", said)
	items.peer_connected_hello(1, "goblin-test-key2")
	items.camp_fire_on = true
	items._camp_fire_tick()
	var fires: Array = NpcCamp.fires()
	check(fires.size() >= 2 and str(fires[0]["owner"]) == "Edda and Hob's", "Edda and Hob's fire comes first, the tribe's after")
	var at: Vector2 = Vector2(float(camp["fire"]["x"]), float(camp["fire"]["z"]))
	var id: int = 0

	for k in fires.size():
		if Vector2(float(fires[k]["x"]), float(fires[k]["z"])).distance_to(at) < 0.01:
			id = int(items._camp_fire_ids.get(k, 0))

	check(items._items.has(id) and ItemsScript.fire_is_lit(int(items._items[id]["fire"]["state"])), "the Ragtooth fire is laid and burning")
	check(items._items.has(int(items._camp_fire_ids.get(0, 0))), "Edda and Hob's fire is laid as before")

	if not items._items.has(id):
		return

	check(items._fire_extra(items._items[id]) == {"camp": 1}, "clients see it as a camp fire")
	items.report_position(1, Vector3(at.x + 1.5, 10.0, at.y))
	said.clear()
	items.action(1, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)
	check(said.any(func(t): return str(t).contains("Ragtooth")), "a use is refused in the tribe's name (%s)" % str(said))
	check(NpcCamp.owner_near(Vector3(at.x, 0.0, at.y)) == str(camp["fire_owner"]), "the client names it for the tribe")
	var cfg: Dictionary = PlacementRules.load_config()
	check(PlacementRules.blocked(cfg, "campfire_kit", Vector3(at.x + 2.0, 10.0, at.y), []) == "tribe_camp", "the ghost is red by the goblin camp")
	check(PlacementRules.reason_text("tribe_camp").contains("goblin camp"), "and says why")
	check(PlacementRules.blocked(cfg, "campfire_kit", Vector3(at.x - float(camp["keep_m"]) - 5.0, 10.0, at.y), []) == "", "and is free past keep_m (the props stand east)")
	_props(items, said, cfg)


# The camp's chest, racks and benches (camp life stage A, Dave 20 Nov 2026): laid once, never saved, and nobody takes, opens, loots, uses,
# sits on, locks, repairs or crafts at them.
func _props(items, said: Array, cfg: Dictionary) -> void:
	var rows: Array = camp.get("props", [])
	var kinds: Dictionary = {}

	for prop in rows:
		kinds[str(prop["kind"])] = true
		check(items._structures.has(str(prop["kind"])), "the %s is an existing structure kind" % str(prop["kind"]))

	check(kinds.has("crude_chest") and kinds.has("log_bench") and (kinds.has("drying_rack") or kinds.has("tanning_rack")), "a chest, benches and a rack (%s)" % str(kinds.keys()))
	items._tribe_props_tick()
	var laid: Array = []

	for prop in NpcCamp.props():
		if str(prop["tribe"]) != "ragtooth":
			continue

		var k: int = NpcCamp.props().find(prop)
		laid.append(int(items._tribe_prop_ids.get(k, 0)))

	check(laid.size() == rows.size() and laid.all(func(i): return items._items.has(i)), "every prop is laid (%s)" % str(laid))
	var count: int = items._items.size()
	items._tribe_props_tick()
	check(items._items.size() == count, "a second tick lays nothing more")

	for i in laid:
		var it: Dictionary = items._items.get(i, {})
		check(bool(it.get("struct", {}).get("transient", false)) and ItemsScript._not_in_area(it), "the %s is transient, never saved" % str(it.get("struct", {}).get("kind", "?")))
		items.report_position(1, it.get("pos", Vector3.ZERO) + Vector3(1.0, 0.0, 0.0))

		for act in [Net.ACT_USE_STRUCT, Net.ACT_CHEST_LOCK, Net.ACT_REPAIR_STRUCT]:
			said.clear()
			items.action(1, act, i, 0, 1, Vector3.ZERO)
			check(said.any(func(t): return str(t).contains("Ragtooth camp")), "action %d on the %s is refused (%s)" % [act, str(it["struct"]["kind"]), str(said)])

		said.clear()
		items._take_down(1, items._inventories[items._peer_key[1]], i)
		check(items._items.has(i) and said.any(func(t): return str(t).contains("Ragtooth camp")), "the %s cannot be taken down" % str(it["struct"]["kind"]))
		check(items._chest_of(1, i) == null, "the %s has no store to open or loot" % str(it["struct"]["kind"]))
		check(PlacementRules.blocked(cfg, "campfire_kit", it["pos"] + Vector3(1.0, 0.0, 0.0), []) == "tribe_camp", "nothing is put down by the %s" % str(it["struct"]["kind"]))

		if str(it["struct"]["kind"]).ends_with("_rack"):
			check(items.serving_station(1, str(it["struct"]["kind"]), 1) < 0, "nobody crafts at the camp's %s" % str(it["struct"]["kind"]))

