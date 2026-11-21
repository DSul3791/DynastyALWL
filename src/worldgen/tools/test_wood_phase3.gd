extends SceneTree

# Wood system phase 3, trees and logs (docs/design/TREE_WOOD_TOOLS_DESIGN.md s1.1, s1.2, s5; Dave 15 Nov 2026): a small tree (trunk under 8 m or butt radius under 0.12 m) breaks
# entirely into Firewood (3 a metre, 2 to 24), a large one into 3 m logs; a character carries two logs and a third is refused; one log is laid down at a time; tools are stowed
# while a log is carried (eating still works). Rolling logs: test_log_physics.gd.
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


# Fells a tree of `height` and species trunk width `trunk` at `at` (it comes down at once in what it breaks into) and returns its stump's id.
func fell(w, height: float, trunk: float, at: Vector3) -> int:
	var stump: int = w._next_id
	w._fell_record(Vector2i(0, 0), {"name": "oak", "position": at, "height": height, "trunk": trunk}, Vector2(1.0, 0.0))
	return stump if w._items.has(stump) and w._items[stump].has("tree") else 0


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

	# --- 3. A felled small tree breaks into Firewood only, no logs, as it falls; its seeds still drop ---
	var small: int = fell(w, 6.0, 0.3, Vector3(100.0, 10.0, 0.0))
	check(small != 0 and int(w._items[small]["tree"]["state"]) == 4, "a 6 m tree leaves its stump and no trunk")
	check(loose(w, "firewood") == 18 and loose(w, "log_oak") == 0 and loose(w, "log") == 0, "a 6 m tree gives 18 Firewood and no logs (%d Firewood)" % loose(w, "firewood"))
	check(loose(w, "kindling") >= 1 and loose(w, "oak_seed") >= 1 and loose(w, "oak_seed") <= 5, "with its kindling and its 1 to 5 seeds (%d seed)" % loose(w, "oak_seed"))

	# A crowded spot changes nothing (Dave 16 Nov 2026: "we do not care how many items are on the ground already"): 64 items lying there, the tree still breaks up.
	var crowded = make("user://test_wood_phase3_crowd")
	var axe_n: int = crowded.table.number_of("stone_axe")

	for n in range(64):
		crowded.drop_in_world(axe_n, 1, Vector3(500.0, 10.0, 0.0), 1)   # worn, so each lies as its own item

	check(fell(crowded, 6.0, 0.3, Vector3(500.0, 10.0, 0.0)) != 0 and loose(crowded, "firewood") == 18, "64 items on the spot do not stop the small tree breaking up (%d Firewood)" % loose(crowded, "firewood"))
	crowded._finish_writer()

	var thin: int = fell(w, 12.0, 0.1, Vector3(200.0, 10.0, 0.0))
	check(thin != 0 and loose(w, "firewood") == 18 + 24 and loose(w, "log_oak") == 0, "a 12 m tree with a 0.1 m butt radius is small too: 24 Firewood (%d in all)" % loose(w, "firewood"))

	# --- 4. A large tree comes down in 3 m logs, and no Firewood ---
	var firewood_before: int = loose(w, "firewood")
	var large: int = fell(w, 12.0, 0.3, Vector3(300.0, 10.0, 0.0))
	check(large != 0 and loose(w, "log_oak") == 4 and loose(w, "firewood") == firewood_before, "a 12 m tree with a 0.3 m butt radius gives 4 oak logs and no Firewood (%d logs)" % loose(w, "log_oak"))

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

	# Rolling logs are real physics now (Dave 16 Nov 2026): test_log_physics.gd.

	print("wood phase 3: %d failures" % failures)
	quit(1 if failures > 0 else 0)
