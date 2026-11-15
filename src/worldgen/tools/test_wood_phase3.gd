extends SceneTree

# Wood system phase 3, trees and logs (docs/design/TREE_WOOD_TOOLS_DESIGN.md s1.1, s1.2, s5; Dave 15 Nov 2026): a small tree (trunk under 8 m or butt radius under 0.12 m) breaks
# entirely into Firewood (3 a metre, 2 to 24), a large one into 3 m logs; a character carries two logs and a third is refused; one log is laid down at a time; tools are stowed
# while a log is carried (eating still works); a loose log on a slope rolls downhill, settles where the ground flattens, at water or after 60 m, and its position is saved.
#   godot --headless --path . --script res://src/worldgen/tools/test_wood_phase3.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const LOGS_FULL := "You can carry two logs at most. Put one down first (Q)."
const HANDS_FULL := "Your hands are full of logs. Put them down first (Q)."

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_carry = func(_p, _id): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return 5000.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "woodphase301")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	return items


# Loose items (not trees, structures or scatter) of one kind, summed.
func loose(w, id: String) -> int:
	var total: int = 0

	for k in w._items:
		var it: Dictionary = w._items[k]

		if not it.has("tree") and not it.has("struct") and not it.has("scatter") and int(it["number"]) == w.table.number_of(id):
			total += int(it["count"])

	return total


# Fells a tree of `height` and species trunk width `trunk` at `at` and returns its trunk record's id.
func fell(w, height: float, trunk: float, at: Vector3) -> int:
	var before: Array = w._items.keys()
	w._fell_record(Vector2i(0, 0), {"name": "oak", "position": at, "height": height, "trunk": trunk}, Vector2(1.0, 0.0))

	for k in w._items:
		if not before.has(k) and w._items[k].has("tree") and int(w._items[k]["tree"]["state"]) == 3:
			return k

	return 0


func split_now(w, id: int) -> void:
	w._split_due[id] = 0
	w._auto_split()


func log_id_near(w, item: String, from: Vector3) -> int:
	var best: int = 0

	for k in w._items:
		if not w._items[k].has("tree") and int(w._items[k]["number"]) == w.table.number_of(item) and (best == 0 or w._items[k]["pos"].distance_to(from) < w._items[best]["pos"].distance_to(from)):
			best = k

	return best


func _init() -> void:
	var w = make("user://test_wood_phase3_trees")
	var cfg: Dictionary = w._drops["trunk"]

	# --- 1. The threshold: shorter than 8 m or a butt radius under 0.12 m ---
	check(w._is_small_tree({"length": 7.9, "radius": 0.3}, cfg) and not w._is_small_tree({"length": 8.0, "radius": 0.3}, cfg), "a trunk shorter than 8 m is small, 8 m is not")
	check(w._is_small_tree({"length": 20.0, "radius": 0.119}, cfg) and not w._is_small_tree({"length": 20.0, "radius": 0.12}, cfg), "a butt radius under 0.12 m is small, 0.12 m is not")
	check(float(cfg["small_tree"]["max_length_m"]) == 8.0 and float(cfg["small_tree"]["min_radius_m"]) == 0.12 and float(cfg["small_tree"]["firewood_per_m"]) == 3.0, "the thresholds and the rate are data (drops.json trunk.small_tree)")

	# --- 2. Firewood: 3 a metre, rounded, 2 to 24 ---
	check(w._small_firewood({"length": 5.0}, cfg) == 15 and w._small_firewood({"length": 1.0}, cfg) == 3 and w._small_firewood({"length": 0.2}, cfg) == 2, "5 m gives 15 Firewood, 1 m gives 3, a twig of 0.2 m still 2")
	check(w._small_firewood({"length": 7.9}, cfg) == 24 and w._small_firewood({"length": 30.0}, cfg) == 24, "never more than 24, the largest small tree's 18 kg")

	# --- 3. A felled small tree breaks into Firewood only, no logs; its seeds still drop ---
	var small: int = fell(w, 6.0, 0.3, Vector3(100.0, 10.0, 0.0))
	check(small != 0 and not bool(w._items[small]["tree"].get("keywood", true)), "a 6 m tree falls as a trunk with no log cut lines")
	split_now(w, small)
	check(not w._items.has(small), "the small trunk broke up by itself")
	check(loose(w, "firewood") == 18 and loose(w, "log_oak") == 0 and loose(w, "log") == 0, "a 6 m tree gives 18 Firewood and no logs (%d Firewood)" % loose(w, "firewood"))
	check(loose(w, "kindling") >= 1 and loose(w, "oak_seed") >= 1 and loose(w, "oak_seed") <= 5, "with its kindling and its 1 to 5 seeds (%d seed)" % loose(w, "oak_seed"))

	# A crowded spot keeps the trunk: it tries again instead of losing the Firewood (the crowd rule of drop_in_world, as for a large tree).
	var crowded = make("user://test_wood_phase3_crowd")
	var axe_n: int = crowded.table.number_of("stone_axe")

	for n in range(64):
		crowded.drop_in_world(axe_n, 1, Vector3(500.0, 10.0, 0.0), 1)   # worn, so each lies as its own item

	var packed: int = fell(crowded, 6.0, 0.3, Vector3(500.0, 10.0, 0.0))
	split_now(crowded, packed)
	check(crowded._items.has(packed) and loose(crowded, "firewood") == 0, "with no room for the heaps the small trunk stays and nothing is lost")

	for k in crowded._items.keys():
		if int(crowded._items[k]["number"]) == axe_n:
			crowded._items.erase(k)

	split_now(crowded, packed)
	check(not crowded._items.has(packed) and loose(crowded, "firewood") == 18, "and it breaks up once there is room (%d Firewood)" % loose(crowded, "firewood"))

	var thin: int = fell(w, 12.0, 0.1, Vector3(200.0, 10.0, 0.0))
	split_now(w, thin)
	check(loose(w, "firewood") == 18 + 24 and loose(w, "log_oak") == 0, "a 12 m tree with a 0.1 m butt radius is small too: 24 Firewood (%d in all)" % loose(w, "firewood"))

	# --- 4. A large tree still splits into 3 m logs, and no Firewood ---
	var firewood_before: int = loose(w, "firewood")
	var large: int = fell(w, 12.0, 0.3, Vector3(300.0, 10.0, 0.0))
	check(bool(w._items[large]["tree"].get("keywood", false)), "a large tree falls with log cut lines")
	split_now(w, large)
	check(loose(w, "log_oak") == 4 and loose(w, "firewood") == firewood_before, "a 12 m tree with a 0.3 m butt radius gives 4 oak logs and no Firewood (%d logs)" % loose(w, "log_oak"))

	# --- 5. The hand-cut fallback (a trunk that did not split): the same Firewood over the small blows ---
	var hand: int = fell(w, 6.0, 0.3, Vector3(400.0, 10.0, 0.0))
	w._split_due.erase(hand)
	w._items[hand]["tree"].erase("auto_split")
	w.report_position(1, Vector3(399.0, 10.0, 0.0))
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)

	for n in range(6):
		w._last_process.clear()
		w.action(1, Net.ACT_PROCESS, hand, 0, 0, HeldTool.at_axe(w))

	check(not w._items.has(hand) and w.inventory_of(1).count_of(w.table.number_of("firewood")) == 18 and w.inventory_of(1).count_of(w.table.number_of("log_oak")) == 0, "a 6 m trunk cut by hand gives the same 18 Firewood in the pack and no logs (%d)" % w.inventory_of(1).count_of(w.table.number_of("firewood")))

	# --- 6. The weights: a whole small tree's Firewood and two hardwood logs are carryable with the toolkit ---
	var c = make("user://test_wood_phase3_carry")
	var weights: Dictionary = c._carry_cfg
	var cap: float = CarryRules.cap_kg(75.0, weights)
	check(CarryRules.weight_of("log_oak", weights) == 22.0 and CarryRules.weight_of("log_spruce", weights) == 18.0 and CarryRules.weight_of("log_birch", weights) == 15.0 and CarryRules.weight_of("log", weights) == 18.0, "log weights: hardwood 22 kg, softwood 18, birch 15, plain Log 18")
	check(CarryRules.shoulder_max(weights) == 2 and absf(cap - 52.5) < 0.001, "two logs at most; a 75 kg character carries 52.5 kg")
	var gear: Array = [["stone_axe", 1, 0], ["stone_hammer", 1, 0], ["stone_knife", 1, 0], ["waterskin", 1, 2000], ["flatbread", 6, 0]]   # the toolkit, 2 litres of water and a day's bread

	for row in gear:
		c.give(1, c.table.number_of(str(row[0])), int(row[1]), {}, int(row[2]))

	var gear_kg: float = c.carried_kg_of(1)
	check(c.give(1, c.table.number_of("firewood"), 24) == 24 and c.inventory_of(1).count_of(c.table.number_of("firewood")) == 24 and c.carried_kg_of(1) <= cap, "24 Firewood (18 kg) with the toolkit, water and food are carried: %.1f of %.1f kg" % [c.carried_kg_of(1), cap])
	c.inventory_of(1).remove(c.table.number_of("firewood"), 24)
	var oak: int = c.table.number_of("log_oak")
	var beech: int = c.table.number_of("log_beech")
	var birch: int = c.table.number_of("log_birch")
	said.clear()
	check(c.give(1, oak, 1) == 1 and c.give(1, beech, 1) == 1 and c.shoulder_count(1) == 2 and c.carried_kg_of(1) <= cap and not said.has(LOGS_FULL), "two hardwood logs (44 kg) with the toolkit, water and food are carried: %.1f of %.1f kg (gear %.1f)" % [c.carried_kg_of(1), cap, gear_kg])

	# --- 7. A third is refused: on the ground it stays, picking it up says why ---
	check(c.give(1, birch, 1) == 0 and c.shoulder_count(1) == 2 and said.has(LOGS_FULL) and loose(c, "log_birch") == 1, "a third log is refused with the message and lies at the feet")
	said.clear()
	c.action(1, Net.ACT_PICKUP, log_id_near(c, "log_birch", Vector3.ZERO), 0, 0, Vector3.ZERO)
	check(c.shoulder_count(1) == 2 and loose(c, "log_birch") == 1 and said.has(LOGS_FULL), "picking it up with two on the shoulder is refused with the message")
	var box = InventoryScript.new(c.table, 12)
	box.add(birch, 1)
	said.clear()
	check(c._box_take(1, c.inventory_of(1), box, 0, 1) == 0 and box.count_of(birch) == 1 and said.has(LOGS_FULL), "taking it out of a chest is refused the same way")

	# --- 8. Laying down is one log at a time ---
	check(c.lay_down_shoulder(1) and c.shoulder_count(1) == 1 and c.shoulder_of(1) == "log_beech" and loose(c, "log_oak") == 1, "laying down puts one log on the ground and the other stays on the shoulder")
	c.action(1, Net.ACT_PICKUP, log_id_near(c, "log_birch", Vector3.ZERO), 0, 0, Vector3.ZERO)
	check(c.shoulder_count(1) == 2 and loose(c, "log_birch") == 0, "with a hand free the third log is picked up")
	check(box.count_of(birch) == 1 and c._box_take(1, c.inventory_of(1), box, 0, 1) == 0, "(still two: the chest's log stays)")
	check(c.lay_down_shoulder(1) and c.lay_down_shoulder(1) and c.shoulder_count(1) == 0 and not c.lay_down_shoulder(1), "the key lays them down one after the other, then does nothing")

	# --- 9. Tools are stowed while a log is carried; eating still works ---
	var t = make("user://test_wood_phase3_stow")
	var standing: Dictionary = {7: true}
	t.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	t.cut_tree = func(_c, id): standing.erase(id); return true
	t.report_position(1, Vector3(8.0, 10.0, 0.0))
	t.action(1, Net.ACT_ADMIN_GIVE, t.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	t.action(1, Net.ACT_ADMIN_GIVE, t.table.number_of("stone_hammer"), 0, 1, Vector3.ZERO)
	var axe_at: Vector3 = HeldTool.at_axe(t)
	check(HeldTool.slot_of(t, "axe") >= 0 and t._held_tool(t.inventory_of(1), HeldTool.slot_of(t, "axe"), "axe") >= 0, "with nothing carried the axe in hand is a usable tool")
	t.give(1, oak, 1)
	said.clear()
	t._last_hit.clear()
	t.action(1, Net.ACT_HIT, 7, 0, 0, axe_at)
	check(t._chops.is_empty() and standing.has(7) and said.has(HANDS_FULL), "a tree blow with a log on the shoulder does nothing and says why")
	check(t._held_tool(t.inventory_of(1), HeldTool.slot_of(t, "axe"), "axe") == -1 and t._swing_tool(1, t.inventory_of(1), HeldTool.slot_of(t, "hammer"), "hammer") == -1, "no tool resolves while a log is carried (axe, hammer: blows, repair, digging all ask here)")
	t.vitals_of(1)["fed"] = 0.0
	t._vitals_cfg["eat_pace_ms"] = 0
	var food: int = t.table.number_of("roast_forage")
	t.action(1, Net.ACT_ADMIN_GIVE, food, 0, 2, Vector3.ZERO)
	t.action(1, Net.ACT_EAT, t.inventory_of(1).numbers.find(food), 0, 0, Vector3.ZERO)
	check(float(t.vitals_of(1)["fed"]) > 0.0 and t.inventory_of(1).count_of(food) == 1 and t.shoulder_count(1) == 1, "eating still works with a log on the shoulder")
	check(t.lay_down_shoulder(1), "the log is put down")
	t._last_hit.clear()
	t.action(1, Net.ACT_HIT, 7, 0, 0, axe_at)
	check(not t._chops.is_empty(), "then the blow lands")

	# --- 10. Rolling logs ---
	var r = make("user://test_wood_phase3_roll")
	var dir: String = "user://test_wood_phase3_roll"
	var moved: Array = []
	r.send_items_moved = func(p, ids, at, _yaws): moved.append([p, ids, at])
	r.ground_height = func(x, _z): return 10.0 + 0.5 * x   # rises along +x at 0.5
	var across: float = PI * 0.5   # rot_y: the log's long axis runs along z, so +x is across it
	r.drop_in_world(oak, 1, Vector3(0.0, 10.0, 0.0), 0, 0.0, across)
	var rolling_id: int = log_id_near(r, "log_oak", Vector3.ZERO)
	r._known[1] = {rolling_id: 1}
	check(r._rolling.has(rolling_id), "a log dropped on a slope is checked")

	for n in range(1200):
		r._roll_tick(0.05)

	var rolled: Vector3 = r._items[rolling_id]["pos"]
	check(rolled.x < -59.0 and rolled.x > -61.0 and is_equal_approx(rolled.z, 0.0) and absf(rolled.y - (10.0 + 0.5 * rolled.x)) < 0.001, "it rolls downhill (across its length) and stops after 60 m on the ground (%.2f, %.2f, %.2f)" % [rolled.x, rolled.y, rolled.z])
	check(r._rolling.is_empty() and r._roll_moved.is_empty(), "then it is asleep: nothing is checked any more")
	check(not moved.is_empty() and moved[0][0] == 1 and (moved[0][1] as PackedInt32Array).has(rolling_id) and absf((moved[-1][2] as PackedVector3Array)[0].x - rolled.x) < 0.001 and moved.size() > 20, "the player who sees it is told as it goes and where it settled (%d messages)" % moved.size())
	r.save()
	r._finish_writer()
	var back = ItemsScript.new()
	back.send_full = func(_p, _b): pass
	back.send_slots = func(_p, _b): pass
	back.send_world_items = func(_p, _a, _r): pass
	back.setup(ItemTableScript.load_default(), dir)
	var kept: float = 1.0e9

	for k in back._items:
		if not back._items[k].has("tree") and int(back._items[k]["number"]) == oak:
			kept = back._items[k]["pos"].x

	check(absf(kept - rolled.x) < 0.01, "its new position is saved (%.2f)" % kept)
	back._finish_writer()

	# A log lying along the slope does not roll; flat ground holds any log.
	r._items.clear()
	r._rolling.clear()
	r.drop_in_world(oak, 1, Vector3(0.0, 10.0, 0.0), 0, 0.0, 0.0)
	r._roll_tick(0.05)
	var along_id: int = log_id_near(r, "log_oak", Vector3.ZERO)
	check(r._rolling.is_empty() and is_equal_approx(float(r._items[along_id]["pos"].x), 0.0), "a log lying along the slope stays where it is")
	r.ground_height = func(_x, _z): return 10.0
	r.drop_in_world(oak, 1, Vector3(5.0, 10.0, 5.0), 0, 0.0, across)
	r._roll_tick(0.05)
	check(r._rolling.is_empty() and loose(r, "log_oak") == 2, "on flat ground it stays")

	# It settles where the slope across it falls under 0.35 (here the ground flattens at x = -10).
	r._items.clear()
	r.ground_height = func(x, _z): return 10.0 + 0.5 * maxf(x, -10.0)
	r.drop_in_world(oak, 1, Vector3(0.0, 10.0, 0.0), 0, 0.0, across)
	var settle_id: int = log_id_near(r, "log_oak", Vector3.ZERO)

	for n in range(400):
		r._roll_tick(0.05)

	var settled: float = float(r._items[settle_id]["pos"].x)
	check(r._rolling.is_empty() and settled < -9.7 and settled > -10.3, "it stops where the ground flattens (x %.2f)" % settled)

	# Water stops it (a shore at x = -5), and the plain Log rolls like a species log.
	r._items.clear()
	r.ground_height = func(x, _z): return 10.0 + 0.5 * x
	r.water_depth_at = func(p): return 1.0 if p.x < -5.0 else 0.0
	r.drop_in_world(r.table.number_of("log"), 1, Vector3(0.0, 10.0, 0.0), 0, 0.0, across)
	var plain_id: int = log_id_near(r, "log", Vector3.ZERO)

	for n in range(400):
		r._roll_tick(0.05)

	var shore: float = float(r._items[plain_id]["pos"].x)
	check(r._rolling.is_empty() and shore <= -4.0 and shore > -5.01, "a plain Log rolls and stops at the water's edge (x %.2f)" % shore)

	# A log laid down or dropped with no turn of its own gets one in the same tick: the server rolls it across the way it goes out in its first row, which is how the
	# client draws it (inventory_view reads rot_y; _loose_extra sends it).
	r._items.clear()
	r._rolling.clear()
	r._known[1] = {}
	var rows: Array = []
	r.ground_height = func(x, z): return 10.0 + 2.0 * x + 2.0 * z
	r.send_items_moved = func(_p, ids, at, yaws): rows.append([ids, at, yaws])
	var turned: int = 0

	for n in range(8):
		r.drop_in_world(oak, 1, Vector3(float(n) * 20.0, 10.0 + 2.0 * float(n) * 20.0, 0.0))   # no rot_y given (a pack drop, the Q key)

	for k in r._items.keys():
		var rec: Dictionary = r._items[k]
		check(rec.has("rot_y") and r._loose_extra(rec).has("rot_y") and is_equal_approx(float(r._loose_extra(rec)["rot_y"]), float(rec["rot_y"])), "a log dropped with no turn is given one that its first row carries (id %d)" % k)
		r._known[1][k] = 1

	var starts: Dictionary = {}

	for k in r._items:
		starts[k] = r._items[k]["pos"]

	for n in range(6):
		r._roll_tick(0.1)

	for k in r._items:
		var turn: float = float(r._items[k]["rot_y"])
		var slope: float = 2.0 * (sin(turn) + cos(turn))   # the ground rises 2 a metre along x and along z
		var gone: Vector3 = r._items[k]["pos"] - starts[k]

		if absf(slope) > 0.35:
			turned += 1
			var along: Vector2 = Vector2(gone.x, gone.z).normalized()
			check(Vector2(gone.x, gone.z).length() > 0.1 and absf(along.dot(Vector2(sin(turn), cos(turn)))) > 0.999, "it rolls across its own turn (id %d, rot_y %.2f)" % [k, turn])
		else:
			check(gone.length() < 0.001, "a log turned along the slope stays (id %d, rot_y %.2f)" % [k, turn])

	var sent_ok: bool = not rows.is_empty()

	for row in rows:
		for i in range((row[0] as PackedInt32Array).size()):
			var id: int = (row[0] as PackedInt32Array)[i]
			sent_ok = sent_ok and absf(float((row[2] as PackedFloat32Array)[i]) - rad_to_deg(float(r._items[id]["rot_y"]))) < 0.01

	check(turned >= 1 and sent_ok, "the rows sent while it rolls carry the same turn the server rolls by (%d of 8 logs rolled)" % turned)

	# A log not lying on the ground (3 m above it: a floor, a deck, a rock) does not move.
	r._items.clear()
	r._rolling.clear()
	r.ground_height = func(x, _z): return 10.0 + 0.5 * x
	r.drop_in_world(oak, 1, Vector3(0.0, 13.0, 0.0), 0, 0.0, across)
	var high_id: int = log_id_near(r, "log_oak", Vector3.ZERO)
	check(r._rolling.has(high_id), "it is looked at once")

	for n in range(20):
		r._roll_tick(0.05)

	check(r._rolling.is_empty() and r._items[high_id]["pos"] == Vector3(0.0, 13.0, 0.0), "but a log 3 m above the ground stays where it is, not snapped down")

	# Only logs roll: a stone dropped on the same slope is not checked.
	r.water_depth_at = Callable()
	r.drop_in_world(r.table.number_of("stone"), 1, Vector3(20.0, 10.0, 0.0))
	check(r._rolling.is_empty(), "other items are never put on the roll list")

	print("wood phase 3: %d failures" % failures)
	quit(1 if failures > 0 else 0)
