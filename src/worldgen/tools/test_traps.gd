extends SceneTree

# Snares (data/animals/traps.json, server_traps.gd): the catch rate on a worn trail and none off one, small game only, a roll only when an animal
# passes (Dave 22 Nov 2026), the carcass, wear and breaking, sprung snares, no limit a player, save and reload, no work for snares nobody is near, the Map's marks.
# The Bird trap (traps.json kinds.bird_trap_set, Part C plan 3): ground birds only, flat trail factor, its own words, saved like a snare.
# Snares on runs and while away (docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md, D-TRAP-1, TR-6): a snare on a trail between animal places
# fishes as on a worn trail; the time with nobody near is rolled once when a player comes back (by the rabbits' hours), one off a run never;
# a sprung one holds its catch.
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


func lay(items, at: Vector3, kind: String = "snare_trap") -> int:
	var id: int = items._next_id
	items._next_id += 1
	items._items[id] = {"number": 1, "count": 1, "pos": at, "left": 1.0e9, "wear": 0, "struct": {"kind": kind, "yaw": 0.0}}
	items._traps.on_placed(1, id)
	return id


# The Map's marks (protocol 150, marks_of): the owner's set traps, oldest first, and nobody else's; a trap gone leaves them at once,
# with no tick; a reloaded world marks its traps from the first ask.
func marks_checks(items, again, snares: Array, bird: int) -> void:
	var marks: Array = items.trap_marks(1)
	var want: Array = snares.duplicate()
	want.append(bird)
	var same: bool = marks.size() == want.size()

	for n in mini(marks.size(), want.size()):
		var it: Dictionary = items._items[int(want[n])]
		same = same and absf(float(marks[n][0]) - it["pos"].x) < 0.11 and absf(float(marks[n][1]) - it["pos"].z) < 0.11 and str(marks[n][2]) == str(it["struct"]["kind"])

	check(same, "the Map marks each set snare and the Bird trap, oldest first (%d marks)" % marks.size())
	items.peer_connected_hello(2, "trap-key-00000002")
	check(items.trap_marks(2).is_empty() and items.trap_marks(99).is_empty(), "another character's Map, or no character, marks none of them")
	check(again.trap_marks(1).size() == want.size(), "after a reload the Map marks the same traps at once (%d)" % again.trap_marks(1).size())
	var gone: int = int(snares[0])
	items._items.erase(gone)
	check(items.trap_marks(1).size() == want.size() - 1, "a trap taken up is gone from the Map at once")
	var placed: int = lay(items, Vector3(600.0, 10.0, 600.0))
	var last: Array = items.trap_marks(1)[items.trap_marks(1).size() - 1]
	check(absf(float(last[0]) - 600.0) < 0.11 and absf(float(last[1]) - 600.0) < 0.11, "a snare just set is marked at once, last")
	items._items.erase(placed)


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

	# On a worn trail a rabbit beside the snare is caught at the data rate (0.35 by day); off any trail never.
	var base: float = float(traps.cfg["base_chance"])
	var on_trail: int = catches(items, id, 2000)
	check(absf(float(on_trail) / 2000.0 - base) < 0.04, "a snare on a trail catches at the data rate (%d of 2000)" % on_trail)
	strength = 0.0
	var in_grass: int = catches(items, id, 2000)
	check(in_grass == 0 and is_equal_approx(traps.chance_at(Vector3.ZERO, rabbit, true), 0.0), "off any animal trail a snare never catches (%d of 2000)" % in_grass)
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

	# Passes (Dave 22 Nov 2026): a roll only when an animal steps up to the snare, one for each time it comes within lure_m.
	var lure: float = float(traps.cfg["lure_m"])
	var passed: int = 0

	for n in 2000:
		reset(items, id)
		taken.clear()
		traps.on_pass(100 + n, "rabbit", Vector3(lure + 3.0, 10.0, 0.0), Vector3(lure - 1.0, 10.0, 0.0))
		passed += 1 if not taken.is_empty() else 0

	check(absf(float(passed) / 2000.0 - base) < 0.04, "a rabbit coming up the trail to the snare is caught at the data rate (%d of 2000)" % passed)
	traps.cfg["base_chance"] = 100.0
	reset(items, id)
	taken.clear()
	traps.on_pass(41, "rabbit", Vector3(-6.0, 10.0, 1.0), Vector3(6.0, 10.0, 1.0))
	check(taken == [41] and items._items.has(int(items._items[id]["struct"]["catch"])), "a long step that crosses the noose counts as a pass")
	reset(items, id)
	taken.clear()
	traps.on_pass(42, "rabbit", Vector3(1.0, 10.0, 0.0), Vector3(0.5, 10.0, 0.0))
	traps.on_pass(43, "rabbit", Vector3(10.0, 10.0, 0.0), Vector3(10.0, 10.0, 3.0))
	traps.on_pass(44, "deer", Vector3(6.0, 10.0, 0.0), Vector3(0.5, 10.0, 0.0))
	check(taken.is_empty(), "no roll for one already beside it, one going by out of reach, or a deer")
	traps.cfg["base_chance"] = base

	bird_checks(items)

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

	# Placement: not near buildings or fires; no limit on how many a player sets (Dave 22 Nov 2026), none is taken back.
	items._items.erase(id)
	var mine: Array = []
	items._items[items._next_id] = {"number": 1, "count": 1, "pos": Vector3(200.0, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "wall", "yaw": 0.0}}
	items._next_id += 1
	check(not traps.allow_place(1, Vector3(204.0, 10.0, 0.0)) and traps.allow_place(1, Vector3(230.0, 10.0, 0.0)), "a snare is not set within 8 m of a building")
	said.clear()

	for n in 20:
		mine.append(lay(items, Vector3(100.0 + 10.0 * n, 10.0, 100.0)))

	var left: int = 0

	for sid in mine:
		left += 1 if items._items.has(sid) else 0

	check(left == mine.size() and not said.any(func(t): return "taken back" in str(t)), "twenty snares by one player all stay set, none taken back (%d left)" % left)

	# Saves and reloads: wear, owner and order survive.
	var keep: int = mine[mine.size() - 1]
	var bird_keep: int = lay(items, Vector3(500.0, 10.0, 500.0), "bird_trap_set")
	items._items[keep]["wear"] = 3
	items._dirty = true
	items.save()
	items._finish_writer()
	var again = make("user://test_traps", false)
	var found: int = -1

	for sid in again._items:
		if again._traps.is_snare(again._items[sid]) and (again._items[sid]["pos"] as Vector3).distance_to(items._items[keep]["pos"]) < 0.1:
			found = sid

	var bird_found: bool = false

	for sid in again._items:
		if str(again._items[sid].get("struct", {}).get("kind", "")) == "bird_trap_set" and (again._items[sid]["pos"] as Vector3).distance_to(items._items[bird_keep]["pos"]) < 0.1:
			bird_found = str(again._items[sid]["struct"]["owner"]) == "trap-key-00000001"

	check(bird_found, "a set bird trap saves and reloads with its owner")
	check(found >= 0 and int(again._items[found].get("wear", 0)) == 3 and str(again._items[found]["struct"]["owner"]) == "trap-key-00000001" and float(again._items[found]["struct"]["seq"]) == float(items._items[keep]["struct"]["seq"]), "a set snare saves and reloads with its wear and owner")
	marks_checks(items, again, mine, bird_keep)
	# The smoke knob: off by default; on, a snare with no animal near catches an imagined rabbit and takes none from the world.
	check(float(traps.cfg["test_chance"]) == 0.0, "the smoke knob is off in the data")
	traps.cfg["test_chance"] = 1.0
	near = []
	taken.clear()
	var knob_id: int = lay(items, Vector3(300.0, 10.0, 300.0))
	check(traps.check_one(knob_id) and taken.is_empty(), "with the smoke knob on, a lone snare catches an imagined rabbit")
	traps.cfg["test_chance"] = 0.0
	away_checks()
	choke_checks()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


# The Bird trap (Part C plan 3): traps.json kinds.bird_trap_set laid over the snare's numbers. Ground birds only; the snare no longer takes birds.
func bird_checks(items) -> void:
	var traps = items._traps
	var bird_cfg: Dictionary = traps.of("bird_trap_set")
	check(traps.is_kind("bird_trap_set") and traps.is_kind("snare_trap") and not traps.is_kind("chest"), "a bird trap is a trap kind")
	check(not bool(bird_cfg["needs_trail"]) and bool(traps.cfg["needs_trail"]) and float(bird_cfg["base_chance"]) == float(traps.cfg["base_chance"]), "it has its own numbers over the snare's (birds need no trail)")
	var pheasant: Dictionary = {"id": 31, "sp": "pheasant", "pos": Vector3(51.0, 10.0, 1.0)}
	var grouse: Dictionary = {"id": 32, "sp": "grouse", "pos": Vector3(51.0, 10.0, 1.0)}
	var duck: Dictionary = {"id": 33, "sp": "duck", "pos": Vector3(1.0, 10.0, 1.0)}
	var rabbit: Dictionary = {"id": 34, "sp": "rabbit", "pos": Vector3(51.0, 10.0, 1.0)}
	check(traps.animal_weight(pheasant) == 0.0 and traps.animal_weight(grouse) == 0.0 and traps.animal_weight(duck) == 0.0, "the snare takes no birds")
	check(traps.animal_weight(pheasant, bird_cfg) > 0.0 and traps.animal_weight(grouse, bird_cfg) > 0.0, "the bird trap takes pheasant and grouse")
	check(traps.animal_weight(rabbit, bird_cfg) == 0.0, "but no rabbit")
	var bird: int = lay(items, Vector3(50.0, 10.0, 0.0), "bird_trap_set")
	near = [rabbit]
	check(catches(items, bird, 300) == 0, "a rabbit beside a bird trap is never caught")
	near = [pheasant]
	strength = 0.0
	var open_ground: int = catches(items, bird, 2000)
	check(absf(float(open_ground) / 2000.0 - float(bird_cfg["base_chance"])) < 0.04, "a bird trap catches at the data rate off any trail (%d of 2000)" % open_ground)
	strength = 0.6
	var day_p: float = traps.chance_at(Vector3.ZERO, pheasant, false, bird_cfg)
	items.game_seconds = func(): return 23.0 * 3600.0
	check(traps.chance_at(Vector3.ZERO, pheasant, false, bird_cfg) < day_p, "birds roost at night: less likely")
	items.game_seconds = func(): return 12.0 * 3600.0
	taken.clear()
	traps.kinds_cfg["bird_trap_set"]["base_chance"] = 100.0
	reset(items, bird)
	check(traps.check_one(bird) and taken == [31], "a sure catch takes the pheasant")
	var carcass: int = int(items._items[bird]["struct"]["catch"])
	check(items._items.has(carcass) and str(items._items[carcass]["struct"]["species"]) == "pheasant", "a pheasant carcass lies by the bird trap")
	items._items.erase(carcass)
	traps.kinds_cfg["bird_trap_set"]["base_chance"] = float(traps.cfg["base_chance"])
	near = [duck]
	var snare: int = lay(items, Vector3(60.0, 10.0, 0.0))
	check(catches(items, snare, 300) == 0, "a duck beside a snare is not caught")
	near = []

	# Its own words when refused.
	var wall: int = items._next_id
	items._items[items._next_id] = {"number": 1, "count": 1, "pos": Vector3(70.0, 10.0, 70.0), "left": 1.0e9, "struct": {"kind": "wall", "yaw": 0.0}}
	items._next_id += 1
	said.clear()
	check(not traps.allow_place(1, Vector3(72.0, 10.0, 70.0), "bird_trap_set") and said.has(str(bird_cfg["say_near"])), "a bird trap near a building is refused in its own words")

	var birds: Array = [bird]

	for n in 8:
		birds.append(lay(items, Vector3(-100.0 - 10.0 * n, 10.0, -100.0), "bird_trap_set"))

	check(items._items.has(bird) and items._items.has(birds[birds.size() - 1]) and items._items.has(snare), "nine bird traps and a snare by one player all stay set")

	for sid in birds:
		items._items.erase(sid)

	items._items.erase(snare)
	items._items.erase(wall)


# Makes every look a sure thing (the chance is clamped to 1).
func base_up(items) -> void:
	items._traps.cfg["base_chance"] = 100.0


# Choke points (stage 2c, TR-12): a snare on a run beside a tree or a boulder catches choke_mult times as often; off a run, no lift.
func choke_checks() -> void:
	var items = make("user://test_traps_choke", true)
	var traps = items._traps
	var run_m: Array = [0.2]
	var trees: Array = [[]]
	items.run_distance = func(_x, _z, _kind): return run_m[0]
	items.trees_near_cached = func(_point, _radius): return trees[0]
	var bare: int = lay(items, Vector3(0.0, 10.0, 0.0))
	var c: Dictionary = traps.of("snare_trap")
	check(not bool(items._items[bare]["struct"].get("choke", false)) and is_equal_approx(traps._choke_mult(items._items[bare]["struct"], c), 1.0), "a snare on open run is no choke point")
	trees[0] = [[Vector3(0.8, 10.0, 0.0), "oak"]]
	var by_tree: int = lay(items, Vector3(20.0, 10.0, 0.0))
	var st: Dictionary = items._items[by_tree]["struct"]
	check(bool(st.get("choke", false)) and is_equal_approx(traps._choke_mult(st, c), float(c["choke_mult"])), "beside a tree on the run it is (x%.1f)" % traps._choke_mult(st, c))
	trees[0] = []
	var rock: int = items._next_id
	items._next_id += 1
	items._items[rock] = {"number": 1, "count": 1, "pos": Vector3(41.5, 10.0, 0.0), "boulder": {"radius": 1.0}}
	var by_rock: int = lay(items, Vector3(40.0, 10.0, 0.0))
	check(bool(items._items[by_rock]["struct"].get("choke", false)), "beside a boulder too (its edge half a metre off)")
	run_m[0] = 5.0
	traps._note_run(items._items[by_rock])
	check(is_equal_approx(traps._choke_mult(items._items[by_rock]["struct"], c), 1.0), "off any run a choke lifts nothing")
	check(is_equal_approx(traps._choke_mult({"choke": true, "run": 1.0}, traps.of("bird_trap_set")), 1.0), "a Bird trap takes no choke lift (birds keep to no runs)")

	# The lift shows in the catches: the snare by the tree, with nobody near, choke noted or not.
	var clock: Array = [20.0 * 3600.0]
	items.game_seconds = func(): return clock[0]
	items.species_active = func(_sp): return 1.0
	items.report_position(1, Vector3(5000.0, 10.0, 0.0))
	var got: Array = [0, 0]

	for side in 2:
		st["choke"] = side == 1

		for n in 1500:
			reset(items, by_tree)
			st["away_at"] = clock[0] - 6.0 * 3600.0
			got[side] += 1 if traps.check_away(by_tree) else 0

	var lift: float = float(got[1]) / maxf(float(got[0]), 1.0)
	check(got[0] > 200 and lift > 1.15 and lift < 1.75, "and a choke point catches about 1.4 times as often over a night (%d against %d)" % [got[1], got[0]])


# Snares on runs and while nobody is near (D-TRAP-1, TR-6).
func away_checks() -> void:
	var items = make("user://test_traps_away", true)
	var traps = items._traps
	var clock: Array = [20.0 * 3600.0]
	var run_m: Array = [0.2]
	var calls: Array = [0]
	items.game_seconds = func(): return clock[0]
	items.run_distance = func(_x, _z, _kind):
		calls[0] += 1
		return run_m[0]
	items.species_active = func(_sp): return 1.0
	strength = 0.0
	rain = 0.0

	# On the run: the share is full within run_full_m, half way at 1.25 m, nothing past run_none_m.
	check(is_equal_approx(traps.run_share(Vector3.ZERO, 0), 1.0), "a snare right on a run sits fully on it")
	run_m[0] = 1.25
	check(absf(traps.run_share(Vector3.ZERO, 0) - 0.5) < 0.01, "a metre and a quarter off, half")
	run_m[0] = 3.0
	check(is_equal_approx(traps.run_share(Vector3.ZERO, 0), 0.0), "past two metres, not at all")
	var rabbit: Dictionary = {"id": 9, "sp": "rabbit", "pos": Vector3(1.0, 10.0, 1.0)}
	var open_grass: float = traps.chance_at(Vector3.ZERO, rabbit, false)
	run_m[0] = 0.2
	var on_run: float = traps.chance_at(Vector3.ZERO, rabbit, false)
	strength = 0.6
	run_m[0] = 3.0
	var worn: float = traps.chance_at(Vector3.ZERO, rabbit, false)
	strength = 0.0
	check(is_equal_approx(on_run, worn) and on_run > open_grass * 5.0, "a live look on a run is as good as on a well worn trail, over five times open grass (%.3f %.3f %.3f)" % [on_run, worn, open_grass])

	# Away: the owner is far off.
	items.report_position(1, Vector3(5000.0, 10.0, 0.0))
	run_m[0] = 0.2
	var id: int = lay(items, Vector3(0.0, 10.0, 0.0))
	var st: Dictionary = items._items[id]["struct"]
	check(float(st.get("run", 0.0)) == 1.0, "a snare set on a run notes it")
	check(not traps.check_away(id) and float(st["away_at"]) == clock[0], "the first look away only starts its clock")
	clock[0] += 1800.0
	check(not traps.check_away(id), "nothing within the game hour")
	var got: int = 0
	var tries: int = 600

	for n in tries:
		reset(items, id)
		st["away_at"] = clock[0] - 3600.0

		if traps.check_away(id):
			got += 1

	var per_hour: float = float(traps.cfg["away_per_hour"])
	check(absf(float(got) / float(tries) - per_hour) < 0.025, "on a run it catches at about away_per_hour a game hour (%d of %d, %.3f)" % [got, tries, per_hour])
	reset(items, id)
	st["away_at"] = clock[0] - 100.0 * 3600.0
	var calls_before: int = calls[0]
	traps.check_away(id)
	check(float(st["away_at"]) > clock[0] - 3600.0 and calls[0] - calls_before <= 3, "a long absence is one roll, its clock caught up (%d trail looks)" % (calls[0] - calls_before))

	var caught: int = -1

	for n in 400:
		reset(items, id)
		st["away_at"] = clock[0] - 12.0 * 3600.0

		if traps.check_away(id):
			caught = int(st["catch"])
			break

	check(caught > 0 and items._items.has(caught) and str(items._items[caught]["struct"]["species"]) == "rabbit" and bool(items._items[caught]["struct"].get("snared", false)), "an away catch lays a rabbit carcass, marked as snared")
	var again: int = 0

	for n in 50:
		st["quiet"] = 0.0
		st["away_at"] = clock[0] - 12.0 * 3600.0
		again += 1 if traps.check_away(id) else 0

	check(again == 0, "a sprung snare holds its one catch until it is taken")

	run_m[0] = INF
	traps._note_run(items._items[id])
	check(float(st["run"]) == 1.0, "with the places round it not worked out (nobody near) the snare keeps the run it was noted on")
	run_m[0] = 5.0
	traps._note_run(items._items[id])
	check(float(st["run"]) == 0.0, "a snare looked at again off any run is noted off it")
	var off: int = 0

	for n in 300:
		reset(items, id)
		st["away_at"] = clock[0] - 12.0 * 3600.0
		off += 1 if traps.check_away(id) else 0

	check(off == 0, "a snare off any run catches nothing while nobody is near")
	run_m[0] = 0.2
	var bird: int = lay(items, Vector3(40.0, 10.0, 0.0), "bird_trap_set")
	var birds: int = 0

	for n in 200:
		reset(items, bird)
		items._items[bird]["struct"]["away_at"] = clock[0] - 12.0 * 3600.0
		birds += 1 if traps.check_away(bird) else 0

	check(birds == 0, "a Bird trap does not fish while away")

	# A fox earth near (stage 2b, TR-10): now and then the catch is a fox, at away_fox_share of the rabbit chance.
	var earth_near: Array = [true]
	items.fox_near = func(_x, _z, _m): return earth_near[0]
	traps._note_run(items._items[id])
	check(bool(st.get("fox", false)), "a snare on a run near a fox earth notes the fox")
	var foxes: int = 0
	var took: int = 0

	for n in 1200:
		reset(items, id)
		st["away_at"] = clock[0] - 6.0 * 3600.0

		if traps.check_away(id):
			took += 1
			foxes += 1 if str(items._items[int(st["catch"])]["struct"]["species"]) == "fox" else 0

	var share: float = float(traps.cfg["away_fox_share"])
	var want: float = share / (1.0 + share)
	check(took > 150 and absf(float(foxes) / float(took) - want) < 0.08, "about %.0f%% of those catches are a fox (%d of %d)" % [want * 100.0, foxes, took])
	earth_near[0] = false
	traps._note_run(items._items[id])
	foxes = 0

	for n in 300:
		reset(items, id)
		st["away_at"] = clock[0] - 3.0 * 3600.0

		if traps.check_away(id):
			foxes += 1 if str(items._items[int(st["catch"])]["struct"]["species"]) == "fox" else 0

	check(not bool(st.get("fox", false)) and foxes == 0, "with no earth near, never a fox")

	# Somebody near: the live look works and nothing builds up for later.
	reset(items, id)
	st["away_at"] = clock[0] - 50.0 * 3600.0
	items.report_position(1, Vector3(3.0, 10.0, 0.0))
	traps.tick(float(traps.cfg["check_s"]) + 1.0)
	check(float(st["away_at"]) == clock[0], "with the owner near, the away clock is kept at now")

	# No work for snares nobody is near: 200 set far off cost no trail look and no roll on a tick; the near one alone is looked at.
	var far: Array = []

	for n in 200:
		far.append(lay(items, Vector3(2000.0 + 10.0 * float(n % 20), 10.0, 2000.0 + 10.0 * floorf(float(n) / 20.0))))

	clock[0] += 5.0 * 3600.0
	var looks: int = calls[0]
	traps.tick(float(traps.cfg["check_s"]) + 1.0)
	var untouched: bool = true

	for sid in far:
		untouched = untouched and float(items._items[sid]["struct"]["away_at"]) == clock[0] - 5.0 * 3600.0

	check(untouched and float(st["away_at"]) == clock[0] and calls[0] - looks <= 3, "a tick touches only the snares near a player (%d trail looks for 201 snares)" % (calls[0] - looks))
	items.report_position(1, Vector3(2095.0, 10.0, 2095.0))
	traps.tick(float(traps.cfg["check_s"]) + 1.0)
	var caught_up: int = 0

	for sid in far:
		caught_up += 1 if float(items._items[sid]["struct"]["away_at"]) == clock[0] else 0

	check(caught_up == far.size(), "walking back to them catches each up once (%d of %d)" % [caught_up, far.size()])

	for sid in far:
		items._items.erase(sid)

	# The time away goes by the rabbits' own hours: twelve hours of day (rabbits abed) catch nothing, twelve of night do.
	items.report_position(1, Vector3(5000.0, 10.0, 0.0))
	items.species_active_at = func(sp, hour): return 1.0 if sp == "rabbit" and (hour >= 20.0 or hour < 8.0) else 0.0
	var by_day: int = 0
	var by_night: int = 0

	for n in 400:
		reset(items, id)
		clock[0] = 20.0 * 3600.0
		st["away_at"] = 8.0 * 3600.0
		by_day += 1 if traps.check_away(id) else 0
		reset(items, id)
		clock[0] = 32.0 * 3600.0
		st["away_at"] = 20.0 * 3600.0
		by_night += 1 if traps.check_away(id) else 0

	check(by_day == 0 and by_night > 100, "a day away catches nothing while the rabbits sleep, a night does (%d, %d of 400)" % [by_day, by_night])
