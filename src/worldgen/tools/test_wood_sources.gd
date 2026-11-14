extends SceneTree

# GOALS-REPAIR WP-R1A commit A (recovery GA-01 and GA-02): what a felled trunk gives, through the real server.
#   Scots pine: every by_species row can drop (resin AND pine_tar), by the axe and by the trunk breaking up by itself; the resin roll is unchanged.
#   Willow: its second row (withies) drops too.
#   Oak: tannin_bark 3 (drops.json harvest_yield) once per felled tree, by the axe or by the break-up, never twice, saved with the trunk (bark_taken).
#   Tar (campfire) -> Water wheel: the data chain is as written (pine_tar 5 -> tar 1; the Water wheel asks for tar).
# Hand cutting and the break-up are the player's routes; the trunk records themselves are made directly (the fell is tested in test_fell_autosplit).
#   godot --headless --path . --script res://src/worldgen/tools/test_wood_sources.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var next_id: int = 880000
var dir: String = ""


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(at_dir: String):
	DirAccess.make_dir_recursive_absolute(at_dir)
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.send_notice = func(_p, _t): pass
	w.ground_height = func(_x, _z): return 10.0
	w.setup(ItemTableScript.load_default(), at_dir)
	return w


func trunk(species: String, length: float, at: Vector3) -> int:
	next_id += 1
	items._items[next_id] = {"number": 0, "count": 1, "pos": at, "left": 1.0e9,
		"tree": {"state": 3, "species": species, "yaw": 0.0, "pitch": 0.0, "length": length, "radius": 0.3, "chunk": [0, 0]}}
	return next_id


func pack(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func on_ground(id: String) -> int:
	var total: int = 0
	var n: int = items.table.number_of(id)

	for k in items._items:
		var it: Dictionary = items._items[k]

		if not it.has("tree") and not it.has("struct") and int(it.get("number", 0)) == n:
			total += int(it["count"])

	return total


# One axe blow on trunk `id`, the player standing where that blow needs (the branch end, then the next cut line).
func blow(id: int) -> void:
	var it: Dictionary = items._items[id]
	var tree: Dictionary = it["tree"]
	var cfg: Dictionary = items._drops["trunk"]
	var length_now: float = float(tree["length"])
	var logs_phase: bool = int(tree.get("blows", 0)) >= int(cfg["branch_blows"]) and int(tree.get("logs_left", 0)) > 0
	var t: float = 0.5

	if logs_phase:
		var piece: float = length_now if int(tree["logs_left"]) <= 1 else minf(float(cfg["log_length_m"]), length_now)
		t = length_now - piece * 0.5

	items.report_position(1, it["pos"] + Vector3(0.3, 0.0, t))
	items._last_process.erase(1)
	items.action(1, Net.ACT_PROCESS, id, 0, 0, HeldTool.at_axe(items))


func hand_cut(id: int, limit: int = 60) -> void:
	for n in range(limit):
		if not items._items.has(id):
			return

		blow(id)


func _watchdog() -> void:
	print("FAIL the test did not finish (a script error stopped it)")
	quit(1)


func _init() -> void:
	create_timer(200.0).timeout.connect(_watchdog)   # a script error part-way would leave the test hanging
	dir = "user://test_wood_sources_%d" % Time.get_ticks_usec()
	items = make(dir)
	items.peer_connected_hello(1, "woodsrc00001")
	items.vitals_of(1)["weight"] = 2000.0
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	var cfg: Dictionary = items._drops["trunk"]
	var pine_tar: int = items.table.number_of("pine_tar")
	var resin: int = items.table.number_of("resin")
	var withies: int = items.table.number_of("withies")
	var bark: int = items.table.number_of("tannin_bark")

	# GA-02, the break-up: over N seeded pines the extra row drops, within its declared 1 to 2 a log; the resin roll is the one it always was (same trunk, same rolls).
	var tar_total: int = 0
	var resin_total: int = 0
	var tar_ok: bool = true

	for n in range(40):
		var tree: Dictionary = {"state": 3, "species": "scots_pine", "yaw": 0.0, "length": 9.0, "radius": 0.3}
		items._items[700000 + n] = {"pos": Vector3.ZERO, "tree": tree}
		var rows: Array = items._trunk_extras(700000 + n, tree, 3, cfg, false)
		var again: Array = items._trunk_extras(700000 + n, tree, 3, cfg, false)
		var tar_here: int = 0

		for row in rows:
			tar_here += int(row[1]) if int(row[0]) == pine_tar else 0
			resin_total += int(row[1]) if int(row[0]) == resin else 0

		tar_total += tar_here
		tar_ok = tar_ok and tar_here <= 3 * 2 and rows == again
		items._items.erase(700000 + n)

	check(tar_total > 0 and resin_total > 0, "40 pines of 3 logs give pine tar (%d) and resin (%d)" % [tar_total, resin_total])
	check(tar_ok, "a trunk's rows are the same every time and tar stays within its declared 1 to 2 a log")
	var bare: Dictionary = cfg.duplicate(true)
	(bare["by_species"] as Dictionary)["scots_pine"] = [(bare["by_species"] as Dictionary)["scots_pine"][0]]
	var resin_only: int = 0
	var resin_now: int = 0

	for n in range(40):
		var tree2: Dictionary = {"state": 3, "species": "scots_pine", "yaw": 0.0, "length": 9.0, "radius": 0.3}
		items._items[700100 + n] = {"pos": Vector3.ZERO, "tree": tree2}

		for row in items._trunk_extras(700100 + n, tree2, 3, bare, false):
			resin_only += int(row[1]) if int(row[0]) == resin else 0

		for row in items._trunk_extras(700100 + n, tree2, 3, cfg, false):
			resin_now += int(row[1]) if int(row[0]) == resin else 0

		items._items.erase(700100 + n)

	check(resin_only == resin_now, "the resin roll is unchanged by the added tar row (%d = %d)" % [resin_only, resin_now])

	# GA-02, the axe: the same rows on the hand-cutting path.
	var hand_tar: int = 0
	var hand_resin: int = 0

	for n in range(14):
		var id: int = trunk("scots_pine", 12.0, Vector3(3.0 + float(n) * 40.0, 10.0, 3.0))
		hand_cut(id)

	hand_tar = pack("pine_tar")
	hand_resin = pack("resin")
	check(hand_tar > 0 and hand_resin > 0, "14 pines cut by hand give pine tar (%d) and resin (%d)" % [hand_tar, hand_resin])

	# GA-02: willow's second row (withies) is the same repair.
	var withy_total: int = 0

	for n in range(40):
		var wt: Dictionary = {"state": 3, "species": "willow", "yaw": 0.0, "length": 9.0, "radius": 0.3}
		items._items[700200 + n] = {"pos": Vector3.ZERO, "tree": wt}

		for row in items._trunk_extras(700200 + n, wt, 3, cfg, false):
			withy_total += int(row[1]) if int(row[0]) == withies else 0

		items._items.erase(700200 + n)

	check(withy_total > 0, "willow trunks give withies too (%d)" % withy_total)

	# GA-02: Tar -> Water wheel as the data has it (not changed here).
	var tar_recipe: Dictionary = {}
	var wheel_tar: int = 0

	for number in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(number))

		if str(r.get("id", "")) == "tar":
			tar_recipe = r

		if str(r.get("id", "")) == "water_wheel":
			for need in r["needs"]:
				wheel_tar += int(need[1]) if int(need[0]) == items.table.number_of("tar") else 0

	check(not tar_recipe.is_empty() and str(tar_recipe["station"]) == "campfire" and int(tar_recipe["needs"][0][0]) == pine_tar and int(tar_recipe["needs"][0][1]) == 5, "Tar is 5 pine tar at a campfire")
	check(wheel_tar > 0, "the Water wheel asks for Tar (%d)" % wheel_tar)

	# GA-01, the axe: an oak gives 3 tannin bark once, however long the trunk takes to cut.
	var oak: int = trunk("oak", 14.0, Vector3(3.0, 10.0, 60.0))
	var at_bark: int = -1
	var steps: int = 0

	while items._items.has(oak) and steps < 60:
		blow(oak)
		steps += 1

		if at_bark < 0 and bool(items._items.get(oak, {}).get("tree", {}).get("bark_taken", false)):
			at_bark = pack("tannin_bark")
			var saved: Dictionary = (items._items[oak]["tree"] as Dictionary).duplicate()
			check(JSON.parse_string(JSON.stringify(saved)).get("bark_taken", false) == true, "the flag rides with the trunk's saved row")

	check(at_bark == 3, "the first blow on the logs strips exactly the table's 3 tannin bark (%d)" % at_bark)
	check(pack("tannin_bark") == 3, "and no more by the last log (%d)" % pack("tannin_bark"))
	check(int(items._drops["harvest_yield"]["oak"]["count"]) == 3, "the count is the drops.json harvest_yield row")

	# GA-01, partly cut, saved, loaded: the flag keeps a second oak's bark from coming twice.
	var half: int = trunk("oak", 14.0, Vector3(3.0, 10.0, 120.0))

	for n in range(5):
		blow(half)

	check(pack("tannin_bark") == 6 and bool(items._items[half]["tree"].get("bark_taken", false)), "a second oak gave its 3 at once (%d in all)" % pack("tannin_bark"))
	items.save()
	items._finish_writer()   # the write runs in the background
	items = make(dir)
	items.peer_connected_hello(1, "woodsrc00001")
	half = -1

	for k in items._items:   # a saved trunk is given a fresh record id on load: find it where it lay
		if items._items[k].has("tree") and int(items._items[k]["tree"]["state"]) == 3 and (items._items[k]["pos"] as Vector3).distance_to(Vector3(3.0, 10.0, 120.0)) < 1.0:
			half = k

	check(half >= 0 and bool(items._items[half]["tree"].get("bark_taken", false)) and int(items._items[half]["tree"].get("blows", 0)) > 0, "the half-cut trunk comes back from the save with bark_taken")
	hand_cut(half)
	check(pack("tannin_bark") == 6, "the rest of that oak gives none")

	# GA-01, the break-up: an oak that breaks up by itself leaves its bark in the heap, once; a pine leaves none.
	var before_ground: int = on_ground("tannin_bark")
	var auto_oak: int = trunk("oak", 10.0, Vector3(3.0, 10.0, 200.0))
	check(items.split_trunk(auto_oak), "an oak trunk breaks into logs")
	check(on_ground("tannin_bark") - before_ground == 3, "its heap holds the 3 tannin bark (%d)" % (on_ground("tannin_bark") - before_ground))
	var auto_pine: int = trunk("scots_pine", 10.0, Vector3(3.0, 10.0, 260.0))
	items.split_trunk(auto_pine)
	check(on_ground("tannin_bark") - before_ground == 3, "a pine adds no tannin bark")

	check(bark > 0, "tannin_bark is a real item")

	print("wood sources: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
