extends SceneTree

# Torches and Tree sap (Dave 16 Nov 2026), through the real server:
#   Simple - Torch = stick, twine, plant fibre; Improved - Torch = the same plus Tree sap (the resin item).
#   Every felled softwood tree gives wood_species.json tree_sap.felled Tree sap, large (beside its logs) or small (with its firewood); a hardwood gives none.
#   A craft that uses up softwood logs gives per_softwood_log Tree sap for each; a hardwood log gives none, and a mixed queue counts each craft's own log.
#   A loose softwood log picked apart with a pickaxe gives per_softwood_log too.
#   A placed Improved torch comes back as an Improved torch.
#   godot --headless --path . --script res://src/worldgen/tools/test_tree_sap.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")   # the hand slot a craft holds its tool in (protocol 126)

var failures: int = 0
var items


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n_of(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return items.inventory_of(1).count_of(n_of(id))


func recipe(id: String) -> Dictionary:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return items.recipes.recipe(int(n))

	return {}


func needs_of(id: String) -> Array:
	var out: Array = []

	for need in recipe(id).get("needs", []):
		out.append([items.table.id_of(int(need[0])), int(need[1])])

	return out


# The Tree sap among a felled tree's pieces (_fall_pieces rows: [number, count, position, ...]).
func sap_in(rows: Array) -> int:
	var total: int = 0

	for row in rows:
		total += int(row[1]) if int(row[0]) == n_of("resin") else 0

	return total


func craft(id: String, times: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(recipe(id).get("number", 0)), 0, times, CraftHand.at(items, 1, int(recipe(id).get("number", 0))))

	for s in range(120 * times):
		items._craft_tick(0.5)


func _watchdog() -> void:
	print("FAIL the test did not finish (a script error stopped it)")
	quit(1)


func _init() -> void:
	create_timer(200.0).timeout.connect(_watchdog)   # a script error part-way would leave the test hanging
	var dir: String = "user://test_tree_sap_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "treesap00001")
	items.vitals_of(1)["weight"] = 2000.0
	var sap: Dictionary = items.table.tree_sap
	var felled: int = int(sap.get("felled", 0))
	var per_log: int = int(sap.get("per_softwood_log", 0))

	# The items and recipes as Dave named them.
	check(items.table.name_of(n_of("resin")) == "Tree sap" and str(sap.get("item", "")) == "resin", "Tree sap is the resin item (%s)" % items.table.name_of(n_of("resin")))
	check(needs_of("torch") == [["stick", 1], ["twine", 1], ["plant_fibre", 1]] and items.table.name_of(n_of("torch")) == "Simple - Torch", "Simple - Torch: stick, twine, plant fibre (%s)" % str(needs_of("torch")))
	check(needs_of("improved_torch") == [["stick", 1], ["twine", 1], ["plant_fibre", 1], ["resin", 1]] and items.table.name_of(n_of("improved_torch")) == "Improved - Torch", "Improved - Torch: the same plus Tree sap (%s)" % str(needs_of("improved_torch")))
	var simple: Dictionary = items.table.entry("torch")
	var better: Dictionary = items.table.entry("improved_torch")
	check(str(better.get("tool_class", "")) == "torch" and float(better.get("burn_s", 0.0)) > float(simple.get("burn_s", 0.0)) and bool(better.get("goes_out", false)) and bool(items.table.entry("improved_torch_doused").get("retired", false)), "an Improved torch is a torch that burns longer, put out and lit again as itself (no doused twin)")
	check(felled > 0 and per_log > 0, "tree_sap gives %d for a felled softwood tree and %d a softwood log" % [felled, per_log])

	# Felling: a large and a small softwood tree give their sap; a hardwood does not.
	for species in ["spruce", "scots_pine", "balsam_fir"]:
		var tree: Dictionary = {"species": species, "yaw": 0.0, "pitch": 0.0, "length": 12.0, "radius": 0.3}
		var base: Vector3 = Vector3(0.0, 10.0, 0.0)
		var big: Array = items._fall_pieces(710000, tree, base)
		var small: Array = items._fall_pieces(710001, {"species": species, "yaw": 0.0, "pitch": 0.0, "length": 5.0, "radius": 0.1}, base)
		var logs: int = big.filter(func(r): return items.table.is_softwood_log(int(r[0]))).size()
		var cfg: Dictionary = items._drops["trunk"]
		var rolled: int = sap_in(items._trunk_extras(710000, tree, logs, cfg, base, items._crown_litter(710000, tree, cfg, base).is_empty()))   # the old per-log resin roll, unchanged
		check(logs > 0 and sap_in(big) == felled + rolled, "a large felled %s gives %d Tree sap beside its %d logs, plus %d from the per-log roll (%d)" % [species, felled, logs, rolled, sap_in(big)])
		check(sap_in(small) == felled, "a small felled %s gives %d Tree sap with its firewood (%d)" % [species, felled, sap_in(small)])

	for species in ["oak", "birch"]:
		var hard: Array = items._fall_pieces(710002, {"species": species, "yaw": 0.0, "pitch": 0.0, "length": 12.0, "radius": 0.3}, Vector3(0.0, 10.0, 0.0))
		var hard_small: Array = items._fall_pieces(710003, {"species": species, "yaw": 0.0, "pitch": 0.0, "length": 5.0, "radius": 0.1}, Vector3(0.0, 10.0, 0.0))
		check(sap_in(hard) == 0 and sap_in(hard_small) == 0, "a felled %s gives no Tree sap" % species)

	# Processing: 6 Wooden blocks from any log with a saw. A queue of three takes a spruce log, an oak log and a plain Log (the lowest member first:
	# the inventory order is the group's, so the test puts each in by hand and crafts one at a time, then all three in one queue entry).
	var inv = items.inventory_of(1)
	items.give(1, n_of("hand_saw"), 1)
	var saw_slot: int = inv.numbers.find(n_of("hand_saw"))

	if not inv.on_hotbar(saw_slot):
		inv.move(saw_slot, 0)

	inv.add(n_of("log_spruce"), 1)
	craft("saw_blocks", 1)
	check(have("wooden_block") == 6 and have("resin") == per_log, "a spruce log sawn into blocks gives %d Tree sap (%d)" % [per_log, have("resin")])
	inv.add(n_of("log_oak"), 1)
	craft("saw_blocks", 1)
	check(have("wooden_block") == 12 and have("resin") == per_log, "an oak log gives no Tree sap (%d)" % have("resin"))
	inv.add(n_of("log"), 1)
	craft("lumber_by_hand", 1)
	check(have("lumber") == 6 and have("resin") == 2 * per_log, "a plain Log sawn into Planks gives Tree sap too (%d)" % have("resin"))
	inv.add(n_of("log_oak"), 2)
	inv.add(n_of("log_spruce"), 1)
	craft("saw_blocks", 3)
	check(have("wooden_block") == 30 and have("resin") == 3 * per_log, "three logs in one queue (two oak, one spruce) give Tree sap for the spruce alone (%d)" % have("resin"))

	# The craft-sap count itself: a three-craft entry whose rows are oak, spruce, oak gives sap only on the middle craft.
	var oak: int = n_of("log_oak")
	var spruce: int = n_of("log_spruce")
	var rows: Array = [[oak, {}, 0, 1], [spruce, {}, 0, 1], [oak, {}, 0, 1]]
	var got: Array = []

	for left in [3, 2, 1]:
		got.append(items._craft_sap([0, left, [[n_of("log"), 1, rows]]]))

	check(got == [0, per_log, 0], "each craft of a queue entry counts its own log (%s)" % str(got))

	# A loose softwood log picked apart with a pickaxe is processed too: its Tree sap lies with the kindling; an oak log's gives none.
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	for pair in [["log", per_log], ["log_oak", 0]]:
		var log_id: int = items._next_id
		items._items[log_id] = {"number": n_of(str(pair[0])), "count": 1, "pos": Vector3(1.0, 10.0, 0.0), "left": 1.0e9}
		items._next_id += 1
		var before: int = 0

		for k in items._items:
			before += int(items._items[k]["count"]) if int(items._items[k].get("number", 0)) == n_of("resin") and not items._items[k].has("struct") else 0

		items._last_process.clear()
		items._chop_loose_log(1, inv, log_id, [-1, "pick", 1.0])
		var after: int = 0

		for k in items._items:
			after += int(items._items[k]["count"]) if int(items._items[k].get("number", 0)) == n_of("resin") and not items._items[k].has("struct") else 0

		check(not items._items.has(log_id) and after - before == int(pair[1]), "a %s picked into kindling leaves %d Tree sap (%d)" % [pair[0], int(pair[1]), after - before])

	# Placing and taking back an Improved torch keeps it Improved (its own Standing torch).
	inv.add(n_of("improved_torch"), 1, 0, {"out": 1})   # one the rain put out: the same torch, marked out
	var slot: int = inv.numbers.find(n_of("improved_torch"))
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._place_torch(1, inv, slot, false, 0, Vector3(1.0, 10.0, 0.0))
	var placed: int = -1

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "improved_standing_torch":
			placed = int(id)

	check(placed >= 0 and have("improved_torch") == 0, "an Improved torch stands in the ground as an Improved - Standing torch")
	var def: Dictionary = items._structures.get("improved_standing_torch", {})
	check(str(def.get("kit", "")) == "improved_torch" and str(items._structures.get("improved_torch_sconce", {}).get("kit", "")) == "improved_torch" and not def.has("kit_out"), "its kit is the Improved torch")

	if placed >= 0:
		items._take_down(1, inv, placed)

	check(have("improved_torch") == 1, "taken back, it is an Improved torch again")

	print("tree sap: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
