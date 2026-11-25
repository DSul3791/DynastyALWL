extends SceneTree

# Weights, end to end (coordinator, 23 Nov 2026; data/items/weights.json, src/shared/carry_rules.gd; Dave: seeds weigh real milligrams #1628,
# storage has no weight limit, the carry limit goes by body weight):
#   1. the data: every item a player can hold has its own weight (none falls to the default, none is zero), a seed is a few milligrams;
#   2. a stack weighs count x one, and the load is the pack plus what worn bags hold;
#   3. the limit: a pick-up stops at the limit ("Too heavy: you took k of n") and never goes over; the load reads the same fraction and speed the
#      client's CarryRules gives; going over by a craft or a trade says so once;
#   4. dropping, crafting by hand, eating and water in a waterskin move the load by exactly their weight; a worn backpack raises the limit by its
#      carry_bonus_kg and its contents count in full;
#   5. shoulder logs weigh what weights.json says and a third is refused; a chest takes any weight;
#   6. two players keep their own loads, and a restart and a dropped line keep them;
#   7. each character in the build 9257 save fixture carries, on today's code, what its 9257 pack (expected_snapshot.json) weighs by today's weights.
#   godot --headless --path . --script res://src/worldgen/tools/test_weights_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")

const DIR := "user://test_weights_loop"
const HERE := Vector3(5.0, 10.0, 0.0)
const DAVE := "weights-dave"
const ANNA := "weights-anna"
const EPS := 0.0001

var failures: int = 0
var items
var said: Array = []
var cfg: Dictionary = {}


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_reject = func(_p, _r): pass
	s.send_notice = func(_p, text): said.append(str(text))
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(_p, _id, _b): pass
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_craft_queue = func(_p, _q, _ms): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.ground_height = func(_x, _z): return 10.0
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	s.game_seconds = func(): return 1000.0 * 86400.0
	s.skill_level = func(_p, _s): return 1.0
	s.peer_connected_hello(1, DAVE)
	s.report_position(1, HERE)
	s.peer_connected_hello(2, ANNA)
	s.report_position(2, HERE + Vector3(1.0, 0.0, 1.0))
	return s


func restart() -> void:
	items._dirty = true
	items.save()
	items._finish_writer()
	items = make_server()


func n(id: String) -> int:
	return items.table.number_of(id)


func kg(id: String) -> float:
	return CarryRules.weight_of(id, cfg)


func load_of(peer: int) -> float:
	items._kg_cache.clear()
	return items.carried_kg_of(peer)


func act(kind: int, a: int, b: int = 0, count: int = 0, peer: int = 1, at: Vector3 = Vector3.ZERO) -> void:
	items.action(peer, kind, a, b, count, at)


func clear_pack(peer: int) -> void:
	var inv = items.inventory_of(peer)

	for s in inv.slot_count:
		inv.clear_slot(s)


# Lays `count` of an item on the ground at `at` and returns that ground item's id.
func lay(id: String, count: int, at: Vector3) -> int:
	items.drop_in_world(n(id), count, at)

	for gid in items._items:
		var it: Dictionary = items._items[gid]

		if not it.has("struct") and int(it.get("number", 0)) == n(id) and (it["pos"] as Vector3).distance_to(at) < 0.5:
			return int(gid)

	return 0


func near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _init() -> void:
	for sub in [DIR, DIR + "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(sub)

		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)

	cfg = CarryRules.load_config()
	items = make_server()
	_data()
	_stack_and_limit()
	_moves()
	_logs_and_chests()
	_two_players_restart()
	items._finish_writer()
	_save_9257()
	print("weights loop: %s" % ("all pass" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)


# 1. Every live item that is not a placed structure has its own weight row (by id or a suffix), none is zero, and seeds are milligrams.
func _data() -> void:
	var defaulted: Array = []
	var zero: Array = []
	var heavy_seed: Array = []

	for id in items.table.ids():
		var e: Dictionary = items.table.entry(id)

		if bool(e.get("retired", false)) or bool(e.get("future", false)) or str(e.get("kind", "")) == "structure":
			continue

		var own: bool = cfg["by_id"].has(id)

		for suffix in cfg["by_suffix"]:
			own = own or id.ends_with(str(suffix))

		if not own:
			defaulted.append(id)

		if kg(id) <= 0.0:
			zero.append(id)

		if str(e.get("kind", "")) == "seed" and not id.contains("bundle") and kg(id) > 0.05:
			heavy_seed.append("%s %s" % [id, CarryRules.weight_text(kg(id))])

	check(defaulted.is_empty(), "every item a player holds has its own weight, none falls to the default (%s)" % str(defaulted))
	check(zero.is_empty(), "no item weighs nothing (%s)" % str(zero))
	check(heavy_seed.is_empty(), "no plain seed weighs more than 50 g (%s)" % str(heavy_seed))
	var kiln_yield: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json")) as Dictionary)["kilns"]["yield"]
	check(kg("charcoal") <= 0.05 + EPS and float(kiln_yield["log"]) * kg("charcoal") < kg("log"), "a log's charcoal weighs less than the log (coordinator 23 Nov: about 0.05 kg a piece; %d x %s against %s)" % [int(kiln_yield["log"]), CarryRules.weight_text(kg("charcoal")), CarryRules.weight_text(kg("log"))])
	check(CarryRules.weight_text(0.000006) == "6 mg" and CarryRules.weight_text(0.25) == "250 g" and CarryRules.weight_text(3.5) == "3.50 kg", "weights read in kg, g and mg (6 mg reads \"%s\")" % CarryRules.weight_text(0.000006))


# 2 and 3. A stack, the limit, and the same reading as the client's.
func _stack_and_limit() -> void:
	clear_pack(1)
	items.vitals_of(1)["weight"] = 75.0
	items.give(1, n("stone"), 7)
	check(near(load_of(1), 7.0 * kg("stone")), "7 stones weigh 7 x %s (%.3f kg)" % [CarryRules.weight_text(kg("stone")), load_of(1)])
	var body: float = items._carry_body(1)
	var cap: float = CarryRules.cap_kg(body, cfg)
	check(near(cap, 75.0 * float(cfg["carry_kg_per_body_kg"])), "a 75 kg body carries %.1f kg" % cap)
	# Fill to just under the limit with stones, then try to pick up 20 more from the ground.
	var room: int = int(floor((cap - load_of(1)) / kg("stone"))) - 3
	items.give(1, n("stone"), room)
	var before: float = load_of(1)
	var pile: int = lay("stone", 20, HERE + Vector3(0.5, 0.0, 0.0))
	said.clear()
	act(Net.ACT_PICKUP, pile)
	var took: int = int(round((load_of(1) - before) / kg("stone")))
	check(load_of(1) <= cap + CarryRules.SLACK_KG and took == 3, "picking up 20 stones at the limit takes only what fits (%d)" % took)
	check(said.any(func(t): return str(t) == "Too heavy: you took %d of 20" % took), "and says how many it took (%s)" % str(said))
	said.clear()
	act(Net.ACT_PICKUP, pile)
	check(said.has("Too heavy to carry any more"), "at the limit it takes none and says so (%s)" % str(said))
	check(near(items._load_ratio(1), CarryRules.load_fraction(load_of(1), body, cfg)) and CarryRules.speed_factor(load_of(1), body, cfg) <= float(cfg["min_speed"]) + EPS, "at the limit the server's load share is the client's, and the walk is at its slowest (%.2f)" % CarryRules.speed_factor(load_of(1), body, cfg))
	# Held E on sticks (a batch of 10 from the heaps around, pickup_batch.json) at the limit says so too.
	act(Net.ACT_DROP, items.inventory_of(1).numbers.find(n("stone")), 0, 1, 1, HERE + Vector3(-0.5, 0.0, -0.5))   # room for a few sticks, never none
	var stick_pile: int = lay("stick", 20, HERE + Vector3(0.0, 0.0, 0.6))
	var spare: int = int(floor((cap - load_of(1)) / kg("stick")))
	said.clear()
	before = load_of(1)
	act(Net.ACT_PICKUP, stick_pile)
	var sticks: int = int(round((load_of(1) - before) / kg("stick")))
	check(sticks == spare and spare > 0 and spare < 10 and said.any(func(t): return str(t) == "Too heavy: you took %d of 10" % sticks), "a batch of sticks at the limit takes %d and says so (%s)" % [sticks, str(said)])
	# How the load reads (CarryRules.load_state: the pack window's words; carry feel, 23 Nov 2026).
	var comfort: float = CarryRules.comfort_kg(body, cfg)
	check(CarryRules.load_state(comfort, body, cfg) == 0 and CarryRules.speed_factor(comfort, body, cfg) == 1.0, "up to the comfortable load: full pace, nothing said")
	check(CarryRules.load_state(comfort + 1.0, body, cfg) == 1 and CarryRules.speed_factor(comfort + 1.0, body, cfg) < 1.0, "past it: slower, and it reads heavy")
	check(CarryRules.load_state(load_of(1), body, cfg) == 2, "filled by pick-ups, it reads at the limit")
	check(CarryRules.load_state(cap + 2.0, body, cfg) == 3, "over the limit, it reads over")
	var steps: Array = []
	var worst: float = 0.0

	for i in 101:   # the slowdown ramps: no step of 1 percent of the slowing band (comfort to limit) cuts the pace by more than 2 percent of full pace
		steps.append(CarryRules.speed_factor(comfort + (cap - comfort) * float(i) / 100.0, body, cfg))

	for i in range(1, steps.size()):
		worst = maxf(worst, float(steps[i - 1]) - float(steps[i]))

	check(worst <= 0.02 and near(float(steps[100]), float(cfg["min_speed"])) and CarryRules.speed_factor(cap + 5.0, body, cfg) == float(steps[100]), "the slowdown eases from full pace to %.2f with no jump (worst step %.3f), and stays there past the limit" % [float(cfg["min_speed"]), worst])
	# Over the limit without picking anything up (the body grows lighter, a backpack comes off): told once.
	said.clear()
	items.vitals_of(1)["weight"] = 60.0
	items._carry_notice(1)
	items._carry_notice(1)
	check(said.filter(func(t): return str(t).begins_with("You carry more than you can")).size() == 1, "going over the limit is said once (%s)" % str(said))
	clear_pack(1)
	items.vitals_of(1)["weight"] = 75.0
	items._carry_notice(1)
	check(not items._over_cap.has(1), "and forgotten once under it again")


# 4. What moves the load.
func _moves() -> void:
	clear_pack(1)
	items.give(1, n("stone"), 10)
	var inv = items.inventory_of(1)
	var before: float = load_of(1)
	act(Net.ACT_DROP, inv.numbers.find(n("stone")), 0, 4, 1, HERE + Vector3(0.5, 0.0, 0.5))
	check(near(before - load_of(1), 4.0 * kg("stone")), "dropping 4 stones takes off %.3f kg" % (before - load_of(1)))
	# A craft by hand: 2 sticks into 6 Kindling.
	clear_pack(1)
	items.give(1, n("stick"), 2)
	before = load_of(1)
	var recipe: int = -1

	for r in items.recipes.makers_of(n("kindling")):
		if not bool(items.recipes.recipe(int(r)).get("retired", false)) and str(items.recipes.recipe(int(r)).get("station", "")) == "":
			recipe = int(r)

	var rec: Dictionary = items.recipes.recipe(recipe)
	items._craft_queues[DAVE] = {"entries": [], "elapsed": 0.0}
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe, 0, 2, CraftHand.at(items, 1, recipe))
	check(near(load_of(1), before - 2.0 * kg("stick")), "queued, the sticks leave the pack (%.3f kg)" % load_of(1))

	for i in 3:
		items._craft_tick(float(rec.get("craft_s", 2.0)) + 0.1)

	var kindling: int = inv.count_of(n("kindling"))
	check(kindling == 2 * int(rec["gives"][1]) and near(load_of(1), float(kindling) * kg("kindling")), "made, %d Kindling weigh %.3f kg" % [kindling, load_of(1)])
	# Eating.
	clear_pack(1)
	items.vitals_of(1)["fed"] = 0.0   # an empty stomach, so the eat is never refused
	var food: String = "dried_berries"
	items.give(1, n(food), 3)
	before = load_of(1)
	act(Net.ACT_EAT, inv.numbers.find(n(food)))
	check(near(before - load_of(1), kg(food)), "eating one %s takes off %s" % [items.table.sentence_name(n(food)), CarryRules.weight_text(before - load_of(1))])
	# Water: a waterskin weighs itself plus a kilo a litre.
	clear_pack(1)
	items.give(1, n("waterskin"), 1)
	var slot: int = inv.numbers.find(n("waterskin"))
	inv.wear[slot] = 1500
	check(near(load_of(1), kg("waterskin") + 1.5), "a full waterskin (1.5 l) weighs itself and 1.5 kg (%.3f kg)" % load_of(1))
	# A worn backpack: the limit rises by its carry_bonus_kg, and what it holds counts in full.
	clear_pack(1)
	var pack_id: String = "simple_backpack"
	var body0: float = items._carry_body(1)
	items.give(1, n(pack_id), 1)
	act(Net.ACT_WEAR, inv.numbers.find(n(pack_id)))
	var bonus: float = float(items.table.entry(pack_id).get("carry_bonus_kg", 0.0))
	check(near(CarryRules.cap_kg(items._carry_body(1), cfg) - CarryRules.cap_kg(body0, cfg), bonus), "a worn %s lets you carry %.0f kg more" % [items.table.sentence_name(n(pack_id)), bonus])
	# A worn bag (a Fibre - Backpack, worn on the shoulder): what it holds counts in full.
	var bag_id: String = "fibre_shoulder_bag"
	items.give(1, n(bag_id), 1)
	act(Net.ACT_WEAR, inv.numbers.find(n(bag_id)))
	var worn_at: int = -1
	var worn: Array = items._characters[DAVE].get("worn", [])

	for i in worn.size():
		if typeof(worn[i]) == TYPE_ARRAY and (worn[i] as Array).size() > 0 and int(worn[i][0]) == n(bag_id):
			worn_at = i

	check(worn_at >= 0, "the Fibre - Backpack is worn")
	items.give(1, n("stone"), 6)
	before = load_of(1)
	said.clear()
	act(Net.ACT_CHEST_OPEN, -1 - worn_at)
	act(Net.ACT_CHEST_PUT, inv.numbers.find(n("stone")), -1 - worn_at, 6)
	act(Net.ACT_CHEST_CLOSE, 0)
	check(inv.count_of(n("stone")) == 0 and near(load_of(1), before), "6 stones put in the worn shoulder bag still weigh %.3f kg on you (%.3f; %d left in the pack; %s)" % [6.0 * kg("stone"), load_of(1), inv.count_of(n("stone")), str(said)])


# 5. Shoulder logs and a chest.
func _logs_and_chests() -> void:
	clear_pack(1)
	items._characters[DAVE]["worn"] = []
	var log_id: String = "log_oak"
	items.give(1, n(log_id), 1)
	items.give(1, n(log_id), 1)
	check(near(load_of(1), 2.0 * kg(log_id)), "two oak logs on the shoulder weigh 2 x %.0f kg" % kg(log_id))
	var third: int = lay(log_id, 1, HERE + Vector3(-0.5, 0.0, 0.5))
	said.clear()
	act(Net.ACT_PICKUP, third)
	check(items.inventory_of(1).count_of(n(log_id)) == 2 and said.has(CarryRules.logs_full_say(cfg)), "a third is refused: \"%s\" (%s)" % [CarryRules.logs_full_say(cfg), str(said)])
	clear_pack(1)
	var chest: int = items.dev_place("chest@7,0,0")
	var cbox = items._chests[int(items._items[chest]["struct"]["uid"])]
	cbox.add(n("stone"), 40)
	cbox.add(n("iron_ingot"), 50)
	check(cbox.count_of(n("stone")) == 40 and cbox.count_of(n("iron_ingot")) == 50 and near(load_of(1), 0.0), "a chest takes any weight and none of it is on you")


# 6. Two players, a restart and a dropped line.
func _two_players_restart() -> void:
	clear_pack(1)
	clear_pack(2)
	items.give(1, n("stone"), 9)
	items.give(2, n("stick"), 5)
	var dave: float = load_of(1)
	var anna: float = load_of(2)
	check(near(dave, 9.0 * kg("stone")) and near(anna, 5.0 * kg("stick")), "Dave and Anna each carry their own load (%.2f, %.2f kg)" % [dave, anna])
	restart()
	check(near(load_of(1), dave) and near(load_of(2), anna), "after a restart both read the same")
	items.peer_left(2)
	items.peer_connected_hello(2, ANNA)
	items.report_position(2, HERE)
	check(near(load_of(2), anna), "Anna's line drops and she comes back to the same load (%.2f kg)" % load_of(2))


# 7. The build 9257 fixture: each character's load is its 9257 pack's weight.
func _save_9257() -> void:
	var fixture: String = "res://src/worldgen/tools/save_fixtures/build_9257"
	var dir: String = DIR + "_9257"

	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(dir + sub)

		for file in DirAccess.get_files_at(dir + sub):
			DirAccess.remove_absolute(dir + sub + "/" + file)

	for sub in ["", "/world_items"]:
		for file in DirAccess.get_files_at(fixture + sub):
			if file.ends_with(".json") and file != "expected_snapshot.json":
				var f: FileAccess = FileAccess.open(dir + ("/" + ItemsScript.AREA_DIR if sub != "" else "") + "/" + file, FileAccess.WRITE)
				f.store_string(FileAccess.get_file_as_string(fixture + sub + "/" + file))
				f.close()

	var snap: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture + "/expected_snapshot.json"))
	var old = ItemsScript.new()
	old.send_full = func(_p, _b): pass
	old.send_slots = func(_p, _b): pass
	old.send_world_items = func(_p, _a, _r): pass
	old.ground_height = func(_x, _z): return 6.0
	old.setup(ItemTableScript.load_default(), dir)
	var wrong: Array = []
	var peer: int = 600

	for key in snap["packs"]:   # no 9257 pack holds crop seeds or linseed, which _count_old_seeds would multiply on load (test_save_9257 in_todays_seeds)
		var want: float = 0.0

		for row in snap["packs"][key]:
			var parts: PackedStringArray = str(row).split(" ")
			var count: int = int(parts[1].substr(1))
			want += CarryRules.weight_of(parts[0], cfg) * float(count)

			if int(old.table.entry(parts[0]).get("capacity_ml", 0)) > 0:
				want += float(int(parts[2].substr(1))) / 1000.0

		old.peer_connected_hello(peer, str(key))
		old.report_position(peer, Vector3(58167.0, 6.0, 71364.0))
		old._kg_cache.clear()
		var got: float = old.carried_kg_of(peer)

		if absf(got - want) > 0.001:
			wrong.append("%s: 9257 pack %.3f kg, today %.3f kg" % [key, want, got])

		old.peer_left(peer)
		peer += 1

	check(snap["packs"].size() >= 3 and wrong.is_empty(), "each 9257 character carries what its 9257 pack weighs (%d packs; %s)" % [snap["packs"].size(), str(wrong)])
	old._finish_writer()
