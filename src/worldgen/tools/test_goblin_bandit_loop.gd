extends SceneTree

# The goblins and bandits loop away from the fighting, over a restart and for two players at once (coordinator, 23 Nov 2026): who dropped a
# thing is kept with the world items over a restart (a goblin's own return gift is not stolen back, a Known player's tools stay left, food
# still counts as a gift) and a build 9257 store without it loads as before; goblin trust per band and character through the save (gifts once a
# night each, a return gift once a day each, harm to one leaving the other alone); the Ragtooth tribe's deals and anger per character over a
# restart and its refusal lines against goblin_tribes.json; bandits: robbery off (bandits.json, Dave's switch), a captive tied by one player
# only, the bounty to the captor as bandits.json says.
#   godot --headless --path . --script res://src/worldgen/tools/test_goblin_bandit_loop.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const TrustScript := preload("res://src/stream/server_goblin_trust.gd")
const TribesScript := preload("res://src/stream/server_tribes.gd")
const BanditsScript := preload("res://src/stream/server_bandits.gd")

const DAY := 86400.0
const BAND := "0,0"
const DAVE := "loop-key-dave"
const ANNA := "loop-key-anna"

var failures: int = 0
var now: Array = [100.0 * DAY + 22.0 * 3600.0]


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir + "/" + ItemsScript.AREA_DIR)

	for sub in [dir, dir + "/" + ItemsScript.AREA_DIR]:
		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)


func make_items(dir: String, said: Array = []):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._goals_loaded = true
	return items


func restart(items, dir: String):
	items._dirty = true
	items.save()
	items._finish_writer()
	return make_items(dir)


func row_by(items, at: Vector3, id: String) -> String:
	for row in items.stealable_near(at, 1.5):
		if str(row[4]) == id:
			return str(row[2])

	return "missing"


func _init() -> void:
	_dropper()
	_trust()
	_tribe()
	_bandits()
	print("goblin and bandit loop: %s" % ("all pass" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)


# A: who dropped a thing, over a restart; the band's choice of what to steal on the reloaded rows; a 9257 store with no droppers.
func _dropper() -> void:
	var dir: String = "user://test_goblin_bandit_loop"
	wipe(dir)
	var items = make_items(dir)
	var meat_at: Vector3 = Vector3(30.0, 10.0, 0.0)
	var axe_at: Vector3 = Vector3(36.0, 10.0, 0.0)
	var gift_at: Vector3 = Vector3(42.0, 10.0, 0.0)
	var plain_at: Vector3 = Vector3(48.0, 10.0, 0.0)
	var far_at: Vector3 = Vector3(-300.0, 10.0, 260.0)   # another area file: its rows sit after the first area's when loaded
	items._items[items._next_id] = {"number": items.table.number_of("stone_brazier"), "count": 1, "pos": Vector3(24.0, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "stone_brazier", "yaw": 0.0}}
	items._next_id += 1   # a structure row ahead of the loose ones in the same area
	check(items.drop_in_world(items.table.number_of("stone"), 2, far_at - Vector3(3.0, 0.0, 0.0), 0, 0.0, NAN, NAN, ""), "a stone with no dropper in the far area")
	check(items.drop_in_world(items.table.number_of("plant_fibre"), 2, far_at, 0, 0.0, NAN, NAN, ANNA), "Anna drops fibre in the far area")
	check(items.drop_in_world(items.table.number_of("raw_meat"), 3, meat_at, 0, 0.0, NAN, NAN, DAVE), "Dave drops raw meat")
	check(items.drop_in_world(items.table.number_of("stone_axe"), 1, axe_at, 40, 0.0, NAN, NAN, DAVE), "and a worn stone axe")
	check(items.drop_in_world(items.table.number_of("dried_berries"), 1, gift_at, 0, 0.0, NAN, NAN, "goblin:" + BAND), "the band lays a return gift")
	check(items.drop_in_world(items.table.number_of("stone"), 2, plain_at, 0, 0.0, NAN, NAN, ""), "a stone with no dropper lies there too")
	var b = restart(items, dir)
	check(row_by(b, meat_at, "raw_meat") == DAVE, "after a restart the meat is still Dave's (%s)" % row_by(b, meat_at, "raw_meat"))
	check(row_by(b, axe_at, "stone_axe") == DAVE, "so is the axe (%s)" % row_by(b, axe_at, "stone_axe"))
	check(row_by(b, gift_at, "dried_berries") == "goblin:" + BAND, "the return gift is still the band's (%s)" % row_by(b, gift_at, "dried_berries"))
	check(row_by(b, plain_at, "stone") == "", "the stone still has no dropper")
	check(row_by(b, far_at, "plant_fibre") == ANNA and row_by(b, far_at - Vector3(3.0, 0.0, 0.0), "stone") == "", "in the far area the fibre is Anna's and its stone has none (%s)" % row_by(b, far_at, "plant_fibre"))

	# The band steals on the reloaded rows: Dave Known, his axe and the band's gift are left, his meat is taken (and counts as a gift).
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.setup()
	a.traits = false
	a.goblins.stealable = b.stealable_near
	a.goblins.trust.game_seconds = func(): return now[0]
	var t = a.goblins.trust

	for n in 7:
		t.gift(BAND, DAVE)
		now[0] += DAY

	check(t.step_of(BAND, DAVE) == "known", "Dave is Known to the band (%s)" % t.step_of(BAND, DAVE))
	var g: Dictionary = {"pos": Vector3(0.0, 10.0, 0.0), "home": Vector3(0.0, 10.0, 0.0), "lair": BAND, "state": 0}
	var def: Dictionary = a.species_def("goblin")
	var picked: Array = []

	for n in 4:
		if not a.goblins._pick_steal(g, def):
			break

		var prize: int = int(g["prize"])
		picked.append(b.table.id_of(int(b._items[prize]["number"])))
		b._items.erase(prize)   # taken whole, so the next pick looks at what is left

	check(picked.has("raw_meat"), "his meat is taken as a gift (%s)" % str(picked))
	check(not picked.has("stone_axe"), "his axe is left")
	check(not picked.has("dried_berries"), "the band does not steal its own gift back")
	check(picked.has("stone"), "a thing with no dropper is stolen as before")
	b._finish_writer()

	# Build 9257's area files have no by_rows: everything loads, with no dropper (as before the change).
	var c = restart(make_items(dir), dir)
	c._finish_writer()
	var stripped: int = 0

	for file in DirAccess.get_files_at(dir + "/" + ItemsScript.AREA_DIR):
		if not file.ends_with(".json"):
			continue

		var path: String = dir + "/" + ItemsScript.AREA_DIR + "/" + file
		var text: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(text)

		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("by_rows"):
			parsed.erase("by_rows")
			var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(parsed))
			f.close()
			stripped += 1

	check(stripped >= 2, "the area files carried by_rows (%d stripped)" % stripped)
	var old = make_items(dir)
	check(row_by(old, plain_at, "stone") == "", "an old store still loads its items")
	check(row_by(old, axe_at, "stone_axe") == "" and row_by(old, meat_at, "raw_meat") == "", "with no dropper, as before")
	old._finish_writer()


# B: trust per band and character through the save: two players, gifts once a night each, a return gift once a day each, harm to one only.
func _trust() -> void:
	var dir: String = "user://test_goblin_bandit_loop_trust"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	now[0] = 200.0 * DAY + 22.0 * 3600.0
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.setup()
	var cfg: Dictionary = a.species_def("goblin").get("ally", {})
	var known: int = int(cfg["steps"]["known"])
	var t = TrustScript.new()
	t.cfg = cfg
	t.game_seconds = func(): return now[0]
	t.store_dir = dir

	for n in known:
		t.gift(BAND, DAVE)
		t.gift(BAND, DAVE)   # twice in a night counts once
		t.gift(BAND, ANNA)
		now[0] += DAY

	check(is_equal_approx(t.trust(BAND, DAVE), float(known)) and is_equal_approx(t.trust(BAND, ANNA), float(known)), "each gets their own trust, once a night (%.1f, %.1f)" % [t.trust(BAND, DAVE), t.trust(BAND, ANNA)])
	check(t.return_gift_due(BAND, DAVE, true) and not t.return_gift_due(BAND, DAVE, true), "Dave gets one return gift today")
	check(t.return_gift_due(BAND, ANNA, false), "Anna still has hers due")
	t.save()

	# A restart: the game clock does not run while the server is down, so nothing is forgotten meanwhile.
	var u = TrustScript.new()
	u.cfg = cfg
	u.game_seconds = func(): return now[0]
	u.store_dir = dir
	u.load_records()
	check(u.step_of(BAND, DAVE) == "known" and u.step_of(BAND, ANNA) == "known", "both are still Known after the restart")
	check(not u.return_gift_due(BAND, DAVE, false), "Dave's return gift today is not given twice over a restart")
	check(u.return_gift_due(BAND, ANNA, true), "Anna's is")
	u.gift(BAND, DAVE)
	u.gift(BAND, DAVE)
	check(is_equal_approx(u.trust(BAND, DAVE), float(known + 1)), "after the restart a night's gifts still count once (%.1f)" % u.trust(BAND, DAVE))
	u.harm(BAND, ANNA)
	check(u.wary(BAND, ANNA) and is_equal_approx(u.trust(BAND, ANNA), 0.0), "Anna hurts one: her trust is gone and the band is wary of her")
	check(not u.wary(BAND, DAVE) and u.step_of(BAND, DAVE) == "known", "Dave's standing with the band is untouched")
	u.save()
	var v = TrustScript.new()
	v.cfg = cfg
	v.game_seconds = func(): return now[0]
	v.store_dir = dir
	v.load_records()
	check(v.wary(BAND, ANNA) and not v.wary(BAND, DAVE), "the wariness is kept over a restart, for Anna only")
	now[0] += float(cfg.get("forget_days", 7.0)) * DAY + 1.0
	check(is_equal_approx(v.trust(BAND, DAVE), float(known)), "a week of game time with no gift and Dave forgets a step's worth (%.1f)" % v.trust(BAND, DAVE))


# D: the Ragtooth tribe: a deal's standing once a game day per character, anger kept over a restart for the striker only, lines from the data.
func _tribe() -> void:
	var dir: String = "user://test_goblin_bandit_loop_tribe"
	wipe(dir)
	var said: Array = []
	var items = make_items(dir, said)
	items.peer_connected_hello(1, DAVE)
	items.peer_connected_hello(2, ANNA)
	var clock: Array = [50.0 * DAY]
	var tr = TribesScript.new()
	tr.items = items
	tr.game_seconds = func(): return clock[0]
	tr.players = func() -> Array: return []
	tr.setup(dir)
	items.rep_key = tr.rep_id
	var att: Dictionary = tr.attitude("ragtooth")
	var gain: int = int(att["trade_rep"])
	tr.note_deal(1, "skritch")
	tr.note_deal(1, "rukz")
	tr.note_deal(2, "skritch")
	var dave_rep: int = items.rep_points(1, "skritch")
	var anna_rep: int = items.rep_points(2, "skritch")
	check(dave_rep == gain and anna_rep == gain, "a deal gives each their own standing, once a game day for the tribe (%d, %d; trade_rep %d)" % [dave_rep, anna_rep, gain])
	tr.harm(1, "snag")
	check(tr.angry("ragtooth", DAVE) and not tr.angry("ragtooth", ANNA), "Dave strikes Snag: the tribe is angry with him only")
	check(said.any(func(s): return str(s).contains("will not deal with you") and str(s).contains("The Ragtooth goblins")), "he is told, with the tribe's name from the data (%s)" % str(said))
	var tr2 = TribesScript.new()
	tr2.items = items
	tr2.game_seconds = func(): return clock[0]
	tr2.players = func() -> Array: return []
	tr2.setup(dir)
	check(tr2.angry("ragtooth", DAVE) and not tr2.angry("ragtooth", ANNA), "the anger is kept over a restart, for him only")
	check(tr2.refuse(1, "skritch", false).contains("No talk, no trade") and tr2.refuse(2, "skritch", false) == "", "Skritch refuses Dave and deals with Anna")
	tr2.note_deal(2, "skritch")
	check(items.rep_points(2, "rukz") == gain, "a second deal the same day after a restart gives no more standing")
	clock[0] += float(att["anger_game_days"]) * DAY + 1.0
	check(not tr2.angry("ragtooth", DAVE), "after anger_game_days (%.1f) he may deal again" % float(att["anger_game_days"]))
	var stock: Dictionary = tr2.tribes()["ragtooth"]["camp"]["stock"]
	check(tr2.stock_line("ragtooth", "drying_rack") == "It is empty for now.", "the camp's stock starts empty when first looked at")
	clock[0] += DAY
	var tr3 = TribesScript.new()
	tr3.items = items
	tr3.game_seconds = func(): return clock[0]
	tr3.setup(dir)
	var meat: int = mini(int(stock["per_game_day"]["raw_meat"]), int(stock["cap"]["raw_meat"]))
	var line: String = tr3.stock_line("ragtooth", "drying_rack")
	check(line == "%s: %d %s." % [str(stock["on"]["drying_rack"][0]), meat, items.table.sentence_name(items.table.number_of("raw_meat"))], "a game day later, over a restart, the rack holds per_game_day's meat as the data says (%s)" % line)
	items._finish_writer()


# E: bandits: robbery stays off (Dave's switch), a captive tied once, the bounty to the captor as bandits.json says.
func _bandits() -> void:
	var clock: Array = [900000.0]
	var b: BanditsScript = BanditsScript.new()
	b.world_seed = 4242
	b.game_seconds = func(): return clock[0]
	b.ground_height = func(_x, _z): return 50.0
	b.in_water = func(_x, _z): return false
	b.building_near = func(_at, _r): return false
	b.road_distance = func(_at, _r): return 200.0
	b.setup("")
	check(not b.robbery_on(), "robbery between players and tolls are off in bandits.json (Dave's switch, untouched)")
	var animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 50.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return []
	animals.setup()
	animals.traits = false

	for sp in animals.cfg["species"]:
		animals.cfg["species"][sp]["target_per_player"] = 0

	animals.cfg["wolves"]["cell_share"] = 0.0
	b.animals = animals
	animals.bandit_camps = b
	var players: Array = []
	animals.big_game.player_info = func(): return players
	var cell: Vector2i = Vector2i(2147483647, 0)

	for n in 200:
		if b.candidate(Vector2i(150 + n, 0)).x != INF:
			cell = Vector2i(150 + n, 0)
			break

	var spot: Vector2 = b.candidate(cell)
	b.sites[cell] = {"x": spot.x, "z": spot.y, "woke": clock[0], "points": 40.0, "levels": [2], "horses": 0}
	var said: Array = []
	var paid: Array = []
	var asked: Array = []
	b.lay_camp = func(_k, _f, _l, _o, _t, _ta): return [400]
	b.laid_still = func(_ids): return true
	b.clear_camp = func(_k, _ids): pass
	b.drop_gear = func(_g, _at): pass
	b.tell = func(peer, text): said.append([peer, str(text)])
	b.pay_bounty = func(peer, copper): paid.append([peer, copper])
	b.take_coins = func(peer, copper):
		asked.append([peer, copper])
		return false
	var guard: Vector3 = Vector3(spot.x + 6.0, 50.0, spot.y)
	b.guards_at = func(): return [guard]
	players.append({"peer": 7, "pos": Vector3(spot.x + 20.0, 50.0, spot.y)})
	players.append({"peer": 8, "pos": Vector3(spot.x + 22.0, 50.0, spot.y)})

	for n in 5:
		b.camp_tick(1.0, [players[0]["pos"], players[1]["pos"]])

	check(asked.is_empty() and b._tolls.is_empty(), "two players by the camp are asked no toll")
	var found: Array = animals.animals.values().filter(func(x): return x["sp"] == "bandit")
	check(found.size() == 1, "the camp's bandit is there (%d)" % found.size())

	if found.is_empty():
		return

	var man: Dictionary = found[0]
	var id: int = int(man["id"])
	animals.damage(id, float(man.get("hp_max", man["hp"])) * (1.0 - float(b.cfg["clearing"]["surrender_share"]) + 0.05), 8)
	check(man.has("gave_up"), "Anna's blow brings him under surrender_share and he gives up")
	check(b.bind(id, 7) and not b.bind(id, 8), "Dave ties him first; Anna cannot tie him again")
	players[0]["pos"] = Vector3(spot.x + 5.0, 50.0, spot.y)
	man["pos"] = Vector3(spot.x + 6.0, 50.0, spot.y + 1.0)

	for n in 4:
		if animals.animals.has(id):   # the server steps only the animals still there; the one handed over is gone
			b.step(man, 0.25)

	check(not animals.animals.has(id), "the guard takes him away")

	var copper: int = int(b.cfg["clearing"]["bounty_copper_per_level"]) * 2
	check(paid == [[7, copper]], "the guard pays the bounty to Dave, who led him, %d copper for level 2 (%s)" % [copper, str(paid)])
	check(said.any(func(s): return int(s[0]) == 7 and str(s[1]).contains("Bounty: %d copper" % copper)), "and the line says the same amount")
	check(not said.any(func(s): return int(s[0]) == 8 and str(s[1]).contains("Bounty")), "Anna is not paid or told of a bounty")
