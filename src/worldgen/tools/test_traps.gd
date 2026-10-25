extends SceneTree

# Snares (data/animals/traps.json, server_traps.gd): the catch rate on a worn trail and in open grass, small game only, the carcass, wear and breaking, sprung snares, the per-player cap, save and reload.
#   godot --headless --path . --script res://src/worldgen/tools/test_traps.gd      Prints "Test done: N pass, N fail".

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var passes: int = 0
var failures: int = 0
var said: Array = []
var near: Array = []                 # the animal rows the stub reports near any snare
var taken: Array = []
var strength: float = 0.6
var rain: float = 0.0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func make(dir: String, wipe: bool):
	DirAccess.make_dir_recursive_absolute(dir)

	if wipe:
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return 12.0 * 3600.0
	items.animals_near = func(_point, _radius): return near
	items.animal_snare = func(id) -> bool:
		taken.append(id)
		return true
	items.trail_strength = func(_x, _z): return strength
	items.rain_now = func(): return rain
	items.setup(ItemTableScript.load_default(), dir)
	items._fate_rng.seed = 4242
	items.peer_connected_hello(1, "trap-key-00000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	return items


func lay(items, at: Vector3) -> int:
	var id: int = items._next_id
	items._next_id += 1
	items._items[id] = {"number": 1, "count": 1, "pos": at, "left": 1.0e9, "wear": 0, "struct": {"kind": "snare_trap", "yaw": 0.0}}
	items._traps.on_placed(1, id)
	return id


func reset(items, id: int) -> void:
	var st: Dictionary = items._items[id]["struct"]
	items._items.erase(int(st.get("catch", 0)))
	st["catch"] = 0
	st["quiet"] = 0.0
	items._items[id]["wear"] = 0


func catches(items, id: int, looks: int) -> int:
	var got: int = 0

	for n in looks:
		reset(items, id)

		if items._traps.check_one(id):
			got += 1

	return got


func _init() -> void:
	var items = make("user://test_traps", true)
	var traps = items._traps
	var rabbit: Dictionary = {"id": 7, "sp": "rabbit", "pos": Vector3(1.0, 10.0, 1.0)}
	near = [rabbit]

	check(is_equal_approx(traps.trail_factor(0.0), 0.1) and is_equal_approx(traps.trail_factor(0.6), 1.0) and is_equal_approx(traps.trail_factor(5.0), 1.0), "the trail factor runs from the open-grass floor to full")
	check(traps.trail_factor(0.2) > traps.trail_factor(0.1) and traps.trail_factor(0.2) < traps.trail_factor(0.3), "the trail factor rises with the strength")

	var id: int = lay(items, Vector3(0.0, 10.0, 0.0))
	check(str(items._items[id]["struct"]["owner"]) == "trap-key-00000001", "a set snare knows its owner")

	# On a worn trail a rabbit beside the snare is caught at the data rate (0.35 by day); in open grass under a fifth of that.
	var base: float = float(traps.cfg["base_chance"])
	var on_trail: int = catches(items, id, 2000)
	check(absf(float(on_trail) / 2000.0 - base) < 0.04, "a snare on a trail catches at the data rate (%d of 2000)" % on_trail)
	strength = 0.0
	var in_grass: int = catches(items, id, 2000)
	check(in_grass < on_trail / 5, "open grass catches under a fifth of a trail (%d against %d)" % [in_grass, on_trail])
	strength = 0.6

	# Night is likelier, a storm halves it, bait doubles it.
	var day_p: float = traps.chance_at(Vector3.ZERO, rabbit, false)
	items.game_seconds = func(): return 23.0 * 3600.0
	check(traps.chance_at(Vector3.ZERO, rabbit, false) > day_p, "small game moves more at night")
	items.game_seconds = func(): return 12.0 * 3600.0
	rain = 1.0
	check(is_equal_approx(traps.chance_at(Vector3.ZERO, rabbit, false), day_p * float(traps.cfg["storm_mult"])), "a storm cuts the chance")
	rain = 0.0
	check(is_equal_approx(traps.chance_at(Vector3.ZERO, rabbit, true), day_p * float(traps.cfg["bait_mult"])), "bait raises the chance")

	# Deer and bigger are never caught; nothing near, nothing caught.
	near = [{"id": 8, "sp": "deer", "pos": Vector3(1.0, 10.0, 1.0)}, {"id": 9, "sp": "moose", "pos": Vector3(1.0, 10.0, 0.0)}, {"id": 10, "sp": "wolf", "pos": Vector3(0.0, 10.0, 1.0)}]
	check(catches(items, id, 500) == 0, "deer, moose and wolf are never caught")
	near = []
	check(catches(items, id, 200) == 0, "no animal near, no catch")

	# A catch: the animal leaves the world, a carcass of its species lies by the snare, the snare wears and is sprung.
	near = [rabbit]
	base_up(items)
	taken.clear()
	reset(items, id)
	check(traps.check_one(id), "a sure catch is made")
	var carcass: int = int(items._items[id]["struct"]["catch"])
	check(taken == [7], "the animal was taken out of the world")
	check(items._items.has(carcass) and str(items._items[carcass]["struct"]["kind"]) == "carcass" and str(items._items[carcass]["struct"]["species"]) == "rabbit", "a rabbit carcass lies by the snare")
	check((items._items[carcass]["pos"] as Vector3).distance_to(items._items[id]["pos"]) < 2.0, "the carcass lies at the snare")
	check(int(items._items[id]["wear"]) == 1, "the snare wears one")
	check(not traps.check_one(id), "a sprung snare catches nothing while its carcass lies there")
	items._items.erase(carcass)
	check(not traps.check_one(id), "a snare is quiet for a while after a catch")
	items._items[id]["struct"]["quiet"] = 0.0
	check(traps.check_one(id), "and sets itself again once the carcass is gone")

	# Bait on the ground is eaten by the catch.
	reset(items, id)
	var bait_no: int = 0

	for number in items.table._by_number:
		if str(items.table.entry(items.table.id_of(int(number))).get("kind", "")) == "food":
			bait_no = int(number)
			break

	var bait_id: int = items._next_id
	items._next_id += 1
	items._items[bait_id] = {"number": bait_no, "count": 1, "pos": Vector3(0.3, 10.0, 0.0), "left": 1000.0}
	check(bait_no != 0 and traps.check_one(id) and not items._items.has(bait_id), "a catch uses up the bait")

	# Wear: the snare breaks at its durability, the carcass stays.
	var wear_id: int = lay(items, Vector3(40.0, 10.0, 0.0))
	var dur: int = traps._durability()
	var made: int = 0

	for n in dur + 5:
		if not items._items.has(wear_id):
			break

		var st: Dictionary = items._items[wear_id]["struct"]

		if traps.check_one(wear_id):
			made += 1
			items._items.erase(int(st.get("catch", 0)))
			st["quiet"] = 0.0

	check(made == dur and not items._items.has(wear_id), "the snare breaks on its %dth catch (%d)" % [dur, made])

	# Placement: not near buildings or fires; six snares a player, the oldest goes back.
	items._items.erase(id)
	var mine: Array = []
	var cap: int = int(traps.cfg["per_player"])
	items._items[items._next_id] = {"number": 1, "count": 1, "pos": Vector3(200.0, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "wall", "yaw": 0.0}}
	items._next_id += 1
	check(not traps.allow_place(1, Vector3(204.0, 10.0, 0.0)) and traps.allow_place(1, Vector3(230.0, 10.0, 0.0)), "a snare is not set within 8 m of a building")

	for n in cap + 2:
		mine.append(lay(items, Vector3(100.0 + 10.0 * n, 10.0, 100.0)))

	var left: int = 0

	for sid in mine:
		left += 1 if items._items.has(sid) else 0

	check(left == cap and not items._items.has(mine[0]) and not items._items.has(mine[1]) and items._items.has(mine[mine.size() - 1]), "past six snares the oldest are taken back (%d left)" % left)
	check(said.has(str(traps.cfg["say_cap"])), "the player is told")

	# Saves and reloads: wear, owner and order survive.
	var keep: int = mine[mine.size() - 1]
	items._items[keep]["wear"] = 3
	items._dirty = true
	items.save()
	items._finish_writer()
	var again = make("user://test_traps", false)
	var found: int = -1

	for sid in again._items:
		if again._traps.is_snare(again._items[sid]) and (again._items[sid]["pos"] as Vector3).distance_to(items._items[keep]["pos"]) < 0.1:
			found = sid

	check(found >= 0 and int(again._items[found].get("wear", 0)) == 3 and str(again._items[found]["struct"]["owner"]) == "trap-key-00000001" and float(again._items[found]["struct"]["seq"]) == float(items._items[keep]["struct"]["seq"]), "a set snare saves and reloads with its wear and owner")
	# The smoke knob: off by default; on, a snare with no animal near catches an imagined rabbit and takes none from the world.
	check(float(traps.cfg["test_chance"]) == 0.0, "the smoke knob is off in the data")
	traps.cfg["test_chance"] = 1.0
	near = []
	taken.clear()
	var knob_id: int = lay(items, Vector3(300.0, 10.0, 300.0))
	check(traps.check_one(knob_id) and taken.is_empty(), "with the smoke knob on, a lone snare catches an imagined rabbit")
	traps.cfg["test_chance"] = 0.0
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


# Makes every look a sure thing (the chance is clamped to 1).
func base_up(items) -> void:
	items._traps.cfg["base_chance"] = 100.0
