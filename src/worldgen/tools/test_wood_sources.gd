extends SceneTree

# GOALS-REPAIR WP-R1A commit A (recovery GA-01 and GA-02): what a felled tree gives as it comes down in its logs (Dave 16 Nov 2026), through the real server.
#   Scots pine: every by_species row can drop (resin AND pine_tar); the resin roll is unchanged.
#   Willow: its second row (withies) drops too.
#   Oak: tannin_bark 3 (drops.json harvest_yield) once per felled tree, in the heap beside its logs; the landing adds none.
#   Maple: its 1 to 5 maple keys lie on the ground, not in the pack.
#   Tar (campfire) -> Water wheel: the data chain is as written (pine_tar 5 -> tar 1; the Water wheel asks for tar).
# The fall itself (the blows, the stump, the swing down) is tested in test_fell_autosplit; here the server's _fell_record is called directly.
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


# Fells a `species` tree `length` tall at `at`, falling along +z, and returns its stump's id.
func fell(species: String, length: float, at: Vector3) -> int:
	var stump: int = items._next_id
	items._fell_record(Vector2i(0, 0), {"name": species, "position": at, "height": length, "trunk": 0.3}, Vector2(0.0, 1.0))
	return stump


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
		var tree: Dictionary = {"state": 4, "species": "scots_pine", "yaw": 0.0, "length": 9.0, "radius": 0.3}
		items._items[700000 + n] = {"pos": Vector3.ZERO, "tree": tree}
		var rows: Array = items._trunk_extras(700000 + n, tree, 3, cfg, Vector3.ZERO, false)
		var again: Array = items._trunk_extras(700000 + n, tree, 3, cfg, Vector3.ZERO, false)
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
		var tree2: Dictionary = {"state": 4, "species": "scots_pine", "yaw": 0.0, "length": 9.0, "radius": 0.3}
		items._items[700100 + n] = {"pos": Vector3.ZERO, "tree": tree2}

		for row in items._trunk_extras(700100 + n, tree2, 3, bare, Vector3.ZERO, false):
			resin_only += int(row[1]) if int(row[0]) == resin else 0

		for row in items._trunk_extras(700100 + n, tree2, 3, cfg, Vector3.ZERO, false):
			resin_now += int(row[1]) if int(row[0]) == resin else 0

		items._items.erase(700100 + n)

	check(resin_only == resin_now, "the resin roll is unchanged by the added tar row (%d = %d)" % [resin_only, resin_now])

	# GA-02, the fall: the same rows lie in the heaps of real felled pines.
	for n in range(14):
		fell("scots_pine", 12.0, Vector3(3.0 + float(n) * 40.0, 10.0, 3.0))

	check(on_ground("pine_tar") > 0 and on_ground("resin") > 0, "14 felled pines lay pine tar (%d) and resin (%d)" % [on_ground("pine_tar"), on_ground("resin")])

	# GA-02: willow's second row (withies) is the same repair.
	var withy_total: int = 0

	for n in range(40):
		var wt: Dictionary = {"state": 4, "species": "willow", "yaw": 0.0, "length": 9.0, "radius": 0.3}
		items._items[700200 + n] = {"pos": Vector3.ZERO, "tree": wt}

		for row in items._trunk_extras(700200 + n, wt, 3, cfg, Vector3.ZERO, false):
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

	# GA-01: an oak comes down with its 3 tannin bark in the heap beside its logs, once; the landing adds none; a pine leaves none.
	var before_ground: int = on_ground("tannin_bark")
	var oak: int = fell("oak", 10.0, Vector3(3.0, 10.0, 200.0))
	check(items._items.has(oak) and on_ground("log_oak") > 0, "an oak comes down in logs")
	check(on_ground("tannin_bark") - before_ground == 3, "its heap holds the 3 tannin bark (%d)" % (on_ground("tannin_bark") - before_ground))
	check(int(items._drops["harvest_yield"]["oak"]["count"]) == 3, "the count is the drops.json harvest_yield row")

	for n in range(8):
		items.tick(0.25)   # the fall lands

	check(on_ground("tannin_bark") - before_ground == 3, "landing adds no more (%d)" % (on_ground("tannin_bark") - before_ground))
	fell("scots_pine", 10.0, Vector3(3.0, 10.0, 260.0))
	check(on_ground("tannin_bark") - before_ground == 3, "a pine adds no tannin bark")

	# Felled seeds (gardening, Dave 14 Nov 2026: "a random number of seeds between 1 and 5 seeds per tree"): a maple lays exactly its roll of maple keys on the
	# ground as it comes down, not in the pack. A maple has no other seed row, so the ground count is the roll.
	var keys_pack: int = pack("maple_keys")
	var ground_keys: int = on_ground("maple_keys")
	var maple_id: int = items._next_id
	var roll: Array = items._felled_seeds(maple_id, {"species": "maple"})
	check(roll.size() == 2 and int(roll[0]) == items.table.number_of("maple_keys") and int(roll[1]) >= 1 and int(roll[1]) <= 5, "a maple's seed is 1 to 5 maple keys (%s)" % str(roll))
	fell("maple", 9.0, Vector3(3.0, 10.0, 400.0))
	check(on_ground("maple_keys") - ground_keys == int(roll[1]) and pack("maple_keys") == keys_pack, "a felled maple lays its roll on the ground, not in the pack (%d)" % (on_ground("maple_keys") - ground_keys))

	check(bark > 0, "tannin_bark is a real item")

	print("wood sources: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
