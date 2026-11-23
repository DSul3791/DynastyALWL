extends SceneTree

# The companions loop over restarts (docs/design/dog_companion_design.md, wolf_pup_taming_design.md, BANDIT_CAMPS.md 5b): what a player
# does with a stray, a dog, a wolf pup and a claimed horse while the server restarts round them, a line drops, and a second player plays
# beside them. Each "restart" saves companions.json, throws the whole animal world away (animals are never saved) and builds a new one that
# loads the file, as terrain_server does. test_dog_companion and test_wolf_pups check each step on its own; this checks the steps joined up.
#   godot --headless --path . --script res://src/worldgen/tools/test_companion_loop.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const ItemTable := preload("res://src/shared/item_table.gd")

const GROUND := 100.0
const DAY := 86400.0
const DIR := "user://test_companion_loop"

var failures: int = 0
var now: float = 100.0 * DAY + 12.0 * 3600.0   # noon on day 100
var hour: float = 12.0
var infos: Array = []
var loose: Dictionary = {}   # world id -> [position, dropped by, item id]
var next_loose: int = 1


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func key_of(peer: int) -> String:
	return {1: "dave", 2: "other", 3: "heir"}.get(peer, "")


# A fresh animal world that loads companions.json from DIR, as the server does at start.
func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return GROUND
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return infos.map(func(i): return i["pos"])
	a.setup()
	a.traits = false
	a.town = Vector2(0.0, 0.0)
	a.hour_now = func(): return hour
	a.big_game.player_info = func(): return infos
	a.companions.peer_key = func(peer): return key_of(int(peer))
	a.companions.game_seconds = func(): return now
	a.companions.ground_items = func(centre, r):
		var out: Array = []

		for id in loose:
			if Vector2(loose[id][0].x - centre.x, loose[id][0].z - centre.z).length() <= r:
				out.append([id, loose[id][0], loose[id][1], "food", loose[id][2]])

		return out
	a.companions.take_item = func(id):
		if not loose.has(id):
			return []

		loose.erase(id)
		return [5, 1]
	a.rng.seed = 41
	a.companions.store_dir = DIR
	a.companions.load_records()
	return a


# The server stops (it saves on the way down) and starts again.
func restart(a):
	a.companions.save()
	return make()


func wipe() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for f in ["companions.json", "companions.json.prev", "companions.json.tmp"]:
		if FileAccess.file_exists(DIR + "/" + f):
			DirAccess.remove_absolute(DIR + "/" + f)

	loose.clear()


func at(peer: int, x: float, z: float, stance: int = 0) -> Dictionary:
	return {"peer": peer, "pos": Vector3(x, GROUND, z), "stance": stance}


func flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


func look(a) -> void:
	a.companions._look_in = 0.0
	a.companions.tick(0.1)


func drop(where: Vector3, by: String, item: String = "raw_meat") -> int:
	var id: int = next_loose
	next_loose += 1
	loose[id] = [where, by, item]
	return id


# Steps one animal as the world tick does, against the nearest listed player.
func step_n(a, x: Dictionary, n: int, dt: float = 0.25) -> void:
	for _k in n:
		if not a.animals.has(int(x["id"])):
			return

		var best: Vector3 = Vector3.INF
		var bd: float = INF

		for i in infos:
			if flat(i["pos"], x["pos"]) < bd:
				bd = flat(i["pos"], x["pos"])
				best = i["pos"]

		a._step(x, dt, bd, best, bd, best)


func stray_for(a, key: String) -> Dictionary:
	for id in a.animals:
		if str(a.animals[id].get("stray_for", "")) == key:
			return a.animals[id]

	return {}


func strays_for(a, key: String) -> int:
	var n: int = 0

	for id in a.animals:
		n += 1 if str(a.animals[id].get("stray_for", "")) == key else 0

	return n


func live_of(a, rid: String) -> Array:
	var out: Array = []

	for id in a.animals:
		if str(a.animals[id].get("companion_id", "")) == rid:
			out.append(a.animals[id])

	return out


func record_of(a, key: String, sp: String) -> Dictionary:
	for rid in a.companions.records:
		var r: Dictionary = a.companions.records[rid]

		if str(r["owner_key"]) == key and str(r["species"]) == sp and not bool(r.get("dead", false)):
			return r

	return {}


# One meal for `key`'s stray: food dropped 3 m from it, the player 20 m off, as a player does it.
func feed_stray(a, key: String) -> void:
	var s: Dictionary = stray_for(a, key)

	if s.is_empty():
		return

	drop(s["pos"] + Vector3(3.0, 0.0, 0.0), key)
	step_n(a, s, 60)


func _init() -> void:
	wipe()

	# 1. Taming a stray over two restarts: a meal on day 1, a restart, a second meal the same day does not count, day 2's does, a
	#    restart, and day 3's makes it the dog. The stray is made again after each restart; trust is kept, not the animal.
	var a = make()
	infos = [at(1, 0.0, 0.0)]
	look(a)
	check(strays_for(a, "dave") == 1, "a stray turns up for Dave")
	infos[0]["pos"] = stray_for(a, "dave")["pos"] + Vector3(0.0, 0.0, 20.0)
	feed_stray(a, "dave")
	check(int(a.companions.strays.get("dave", {}).get("trust", 0)) == 1, "day 1: one trust (%s)" % str(a.companions.strays.get("dave", {})))
	a = restart(a)
	infos = [at(1, 0.0, 0.0)]
	look(a)
	check(strays_for(a, "dave") == 1, "after a restart one stray is there for Dave again")
	check(int(a.companions.strays.get("dave", {}).get("trust", 0)) == 1, "after a restart Dave's trust is still 1")
	infos[0]["pos"] = stray_for(a, "dave")["pos"] + Vector3(0.0, 0.0, 20.0)
	feed_stray(a, "dave")
	check(int(a.companions.strays["dave"]["trust"]) == 1, "a second meal on the same game day does not count, restart or not")
	now += DAY
	feed_stray(a, "dave")
	check(int(a.companions.strays["dave"]["trust"]) == 2, "day 2: two trust")
	a = restart(a)
	now += DAY
	infos = [at(1, 0.0, 0.0)]
	look(a)
	infos[0]["pos"] = stray_for(a, "dave")["pos"] + Vector3(0.0, 0.0, 20.0)
	var tamed: Dictionary = stray_for(a, "dave")
	feed_stray(a, "dave")
	var dog: Dictionary = record_of(a, "dave", "dog")
	check(not dog.is_empty() and tamed.has("companion_id"), "day 3, after two restarts: the stray is Dave's dog")
	check(not a.companions.strays.has("dave"), "the stray's trust is spent")
	var dog_id: String = str(dog.get("id", ""))
	var dog_name: String = str(dog.get("name", ""))

	# 2. A restart with Dave on: one dog, beside him, with its name and bond; ticks after that never make a second one, nor a stray.
	a = restart(a)
	infos = [at(1, 500.0, 500.0)]

	for _n in 4:
		look(a)

	var dogs: Array = live_of(a, dog_id)
	check(dogs.size() == 1, "after a restart one dog is made for Dave (%d)" % dogs.size())
	check(dogs.size() == 1 and flat(dogs[0]["pos"], infos[0]["pos"]) <= 4.0, "it is made beside him")
	check(str(a.companions.records.get(dog_id, {}).get("name", "")) == dog_name and is_equal_approx(float(a.companions.records[dog_id]["bond"]), 0.1), "its name and bond came back")
	check(strays_for(a, "dave") == 0, "no stray for a player with a dog after a restart")

	# 3. A second player beside Dave: their own stray; Dave's dog leaves their food, and their stray leaves Dave's.
	infos = [at(1, 0.0, 0.0), at(2, 5.0, 0.0)]
	look(a)
	var theirs: Dictionary = stray_for(a, "other")
	check(not theirs.is_empty() and strays_for(a, "other") == 1, "the second player gets their own stray")
	dogs = live_of(a, dog_id)

	if not dogs.is_empty() and not theirs.is_empty():
		var o_food: int = drop(dogs[0]["pos"] + Vector3(1.0, 0.0, 0.0), "other")
		step_n(a, dogs[0], 20)
		check(loose.has(o_food), "Dave's dog leaves the other player's food")
		infos[1]["pos"] = theirs["pos"] + Vector3(0.0, 0.0, 25.0)
		var d_food: int = drop(theirs["pos"] + Vector3(2.0, 0.0, 0.0), "dave")
		step_n(a, theirs, 40)
		check(loose.has(d_food) and int(a.companions.strays.get("other", {}).get("trust", 0)) == 0, "their stray leaves Dave's food (%s %s)" % [loose.has(d_food), a.companions.strays.get("other", {})])
		loose.erase(o_food)
		loose.erase(d_food)
		feed_stray(a, "other")
		check(int(a.companions.strays.get("other", {}).get("trust", 0)) == 1, "their stray eats their food")

	# 4. A dropped line: Dave goes; his dog goes with him, his day out unfed still costs it, a day apart costs nothing, and when he is back
	#    the same dog is made beside him, never a second one, and no stray. The other player's stray is untouched.
	var r: Dictionary = a.companions.records[dog_id]
	r["bond"] = 0.4
	r["near_day"] = a.companions._today()
	r["near_s"] = 120.0   # a little time out together today, unfed
	r["fed_day"] = a.companions._today() - 1
	infos = [at(2, 5.0, 0.0)]
	look(a)
	check(live_of(a, dog_id).is_empty(), "Dave's dog leaves the world when his line drops")
	check(strays_for(a, "other") == 1, "the other player's stray stays")
	now += DAY
	look(a)
	check(is_equal_approx(float(r["bond"]), 0.35), "the unfed day he was out with it costs 0.05 (%.2f)" % float(r["bond"]))
	now += DAY
	look(a)
	check(is_equal_approx(float(r["bond"]), 0.35), "a day he is away costs nothing (%.2f)" % float(r["bond"]))
	infos = [at(2, 5.0, 0.0), at(1, 300.0, 0.0)]
	look(a)
	look(a)
	dogs = live_of(a, dog_id)
	check(dogs.size() == 1 and flat(dogs[0]["pos"], infos[1]["pos"]) <= 4.0, "back on, the same dog is beside him (%d)" % dogs.size())
	check(strays_for(a, "dave") == 0, "and no stray is made for him")

	# 5. A full world: the wild animals are at the server cap when Dave comes back; his own dog is still made beside him (it is his, not a
	#    new wild animal), and the cap is not raised for wild ones.
	infos = [at(2, 5.0, 0.0)]
	look(a)
	var x: float = 2000.0

	while a.spawn("rabbit", x, 2000.0) != 0:
		x += 3.0

	var cap: int = int(a.cfg.get("server_cap", 150))
	check(a.animals.size() >= cap, "the world is full (%d of %d)" % [a.animals.size(), cap])
	infos = [at(2, 5.0, 0.0), at(1, 300.0, 0.0)]
	look(a)
	check(live_of(a, dog_id).size() == 1, "a full world still has room for Dave's own dog")
	check(a.animals.size() == cap + 1, "the dog still counts: the world holds the cap and Dave's dog (%d)" % a.animals.size())
	check(a.spawn("rabbit", x, 2000.0) == 0, "a full world takes no new wild animal")
	var wild: Array = []

	for id in a.animals:
		if str(a.animals[id]["sp"]) == "rabbit":
			wild.append(id)

	for id in wild:
		a.animals.erase(id)

	# 6. Death: another player kills Dave's dog; its record says died and is kept; it is never made again, not after a restart either; a
	#    stray comes for Dave so he can win another.
	dogs = live_of(a, dog_id)

	if not dogs.is_empty():
		a.damage(int(dogs[0]["id"]), 9999.0, 2)

	check(bool(r.get("dead", false)) and str((r["history"] as Array).back()["event"]) == "died", "a killed dog's record says died")
	look(a)
	check(live_of(a, dog_id).is_empty(), "a dead dog is not made again")
	a = restart(a)
	infos = [at(1, 0.0, 0.0)]
	look(a)
	look(a)
	check(a.companions.records.has(dog_id) and bool(a.companions.records[dog_id]["dead"]), "the dead dog's record is kept through a restart")
	check(live_of(a, dog_id).is_empty(), "nor after a restart")
	check(strays_for(a, "dave") == 1, "a stray comes for Dave once his dog is dead")

	# 7. A wolf pup: a young companion through a restart (drawn young, a quarter of a wolf's health), grown after grow_days even when those
	#    days passed with the server down, and grown through a further restart.
	var pup_id: int = a.spawn("wolf", 10.0, 10.0)
	var pup: Dictionary = a.animals.get(pup_id, {})
	a.companions._adopt(pup, "dave", a.companions._cfg("wolf"))
	var wolf: Dictionary = record_of(a, "dave", "wolf")
	var wolf_id: String = str(wolf.get("id", ""))
	check(bool(wolf.get("young", false)), "the pup is a young companion")
	a = restart(a)
	infos = [at(1, 0.0, 0.0)]
	look(a)
	var wolves: Array = live_of(a, wolf_id)
	var full_hp: float = float(a.species_def("wolf").get("health", 30.0))
	check(wolves.size() == 1 and int(wolves[0]["num"]) >= a.YOUNG_NUM and float(wolves[0]["hp"]) <= full_hp * 0.25 + 0.01, "after a restart it is still a young pup (%s)" % str(wolves.map(func(w): return [w["num"], w["hp"]])))
	infos = []
	a = restart(a)
	now += 21.0 * DAY
	infos = [at(1, 0.0, 0.0)]
	look(a)
	wolves = live_of(a, wolf_id)
	check(not bool(a.companions.records[wolf_id].get("young", true)), "grow_days passed with the server down: it is grown")
	check(wolves.size() == 1 and int(wolves[0]["num"]) < a.YOUNG_NUM and float(wolves[0]["hp"]) >= full_hp - 0.01, "and made grown, at full health (%s)" % str(wolves.map(func(w): return [w["num"], w["hp"]])))
	a = restart(a)
	look(a)
	wolves = live_of(a, wolf_id)
	check(wolves.size() == 1 and int(wolves[0]["num"]) < a.YOUNG_NUM, "grown through a further restart")
	check(strays_for(a, "dave") == 1, "a wolf is not a dog: Dave still gets a stray")

	# 8. A claimed bandit horse is saved at once (a crash right after cannot lose it), comes back after a restart, and needs no food: its
	#    bond stays full over unfed days out with Dave.
	var horse_id: int = a.spawn("horse", 20.0, 0.0)
	var claimed: bool = a.companions.claim(a.animals.get(horse_id, {}), 1)
	check(claimed, "Dave claims the horse")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/companions.json"))
	var on_disk: bool = false

	if typeof(parsed) == TYPE_DICTIONARY:
		for rid in parsed.get("records", {}):
			on_disk = on_disk or str(parsed["records"][rid]["species"]) == "horse"

	check(on_disk, "the claimed horse is on disk at once")
	var horse: Dictionary = record_of(a, "dave", "horse")
	var horse_rid: String = str(horse.get("id", ""))
	a = make()   # a crash: nothing saved on the way down
	infos = [at(1, 0.0, 0.0)]
	look(a)
	check(live_of(a, horse_rid).size() == 1, "after a crash the horse is beside Dave")

	for _d in 3:
		var hr: Dictionary = a.companions.records[horse_rid]
		hr["near_s"] = 900.0
		now += DAY
		look(a)

	check(is_equal_approx(float(a.companions.records[horse_rid]["bond"]), 1.0), "a horse's bond stays full on unfed days (%.2f)" % float(a.companions.records[horse_rid]["bond"]))
	var spots: Array = []

	for rid in [wolf_id, horse_rid]:
		for live in live_of(a, rid):
			spots.append(live["pos"])

	check(spots.size() == 2 and flat(spots[0], spots[1]) > 1.0, "the wolf and the horse never stand in one spot")

	# 9. The heir: Dave's living companions go to the heir at 70 % of their bond (the dead dog stays Dave's), and the heir has them after a
	#    restart; Dave has none, so a stray comes for Dave again and none for the heir... who has no dog either, so one comes for them.
	var wolf_bond: float = float(a.companions.records[wolf_id]["bond"])
	check(a.companions.inherit("dave", "heir") == 2, "the heir inherits the wolf and the horse")
	a = restart(a)
	infos = [at(3, 0.0, 0.0)]
	look(a)
	look(a)
	check(str(a.companions.records[wolf_id]["owner_key"]) == "heir" and is_equal_approx(float(a.companions.records[wolf_id]["bond"]), wolf_bond * 0.7), "after a restart the heir has the wolf at 70 %% of its bond")
	check(str(a.companions.records[dog_id]["owner_key"]) == "dave", "the dead dog stays in Dave's story")
	check(live_of(a, wolf_id).size() == 1 and live_of(a, horse_rid).size() == 1, "the heir's wolf and horse are beside them")
	check(strays_for(a, "heir") == 1, "the heir, with no dog, gets a stray")

	# 10. Bond 0 through a restart: the dog leaves, the record says lost and is kept, it is not made again after a restart, and a stray comes.
	infos = [at(1, 0.0, 0.0)]
	look(a)
	feed_stray(a, "dave")

	for _d in 2:
		now += DAY
		infos = [at(1, 0.0, 0.0)]
		look(a)
		infos[0]["pos"] = stray_for(a, "dave")["pos"] + Vector3(0.0, 0.0, 20.0) if not stray_for(a, "dave").is_empty() else infos[0]["pos"]
		feed_stray(a, "dave")

	var dog2: Dictionary = record_of(a, "dave", "dog")
	check(not dog2.is_empty(), "Dave wins a second dog")
	var dog2_id: String = str(dog2.get("id", ""))

	if not dog2.is_empty():
		dog2["bond"] = 0.05
		dog2["near_day"] = a.companions._today()
		dog2["near_s"] = 200.0
		dog2["fed_day"] = -1
		now += DAY
		look(a)
		check(str(dog2["owner_key"]) == "" and str((dog2["history"] as Array).back()["event"]) == "lost", "at bond 0 the dog leaves")
		a = restart(a)
		look(a)
		look(a)
		check(live_of(a, dog2_id).is_empty() and a.companions.records.has(dog2_id), "a lost dog is kept on record and not made again after a restart")
		check(strays_for(a, "dave") == 1, "a stray comes for Dave after his dog left")
		check(int(a.companions.next_id) > int(dog2_id), "record ids are never reused after a restart")

	# 12. A meal a day: food Dave puts down by his dog (a stack set aside to free his pack) is not all eaten; it eats one piece a game
	#     day, and the next day one more. A stray and a pup the same: one piece a day, the rest left for the next days.
	infos = [at(1, 0.0, 0.0)]
	look(a)
	look(a)
	var d3: Dictionary = record_of(a, "dave", "dog")

	if d3.is_empty():
		var s3: Dictionary = stray_for(a, "dave")
		s3["pos"] = Vector3(30.0, GROUND, 0.0)
		a.companions._adopt(s3, "dave", a.companions._cfg("dog"))
		d3 = record_of(a, "dave", "dog")

	var live3: Array = live_of(a, str(d3.get("id", "")))
	check(live3.size() == 1, "Dave has a dog for the meal check")

	if live3.size() == 1:
		d3["fed_day"] = a.companions._today() - 1
		loose.clear()
		live3[0]["pos"] = Vector3(-2.0, GROUND, -2.0)

		for k in 5:
			drop(Vector3(-3.0 - 0.2 * k, GROUND, -3.0), "dave")

		step_n(a, live3[0], 40)
		check(loose.size() == 4 and int(d3["fed_day"]) == a.companions._today(), "an unfed dog eats one piece of five (%d left)" % loose.size())
		step_n(a, live3[0], 40)
		check(loose.size() == 4, "and leaves the rest that day (%d left)" % loose.size())
		now += DAY
		step_n(a, live3[0], 40)
		check(loose.size() == 3, "the next day it eats one more (%d left)" % loose.size())

	loose.clear()
	infos = [at(2, 0.0, 0.0)]
	a.companions.strays.erase("other")
	look(a)
	var s4: Dictionary = stray_for(a, "other")
	check(not s4.is_empty(), "a stray for the other player for the meal check")

	if not s4.is_empty():
		infos[0]["pos"] = s4["pos"] + Vector3(0.0, 0.0, 20.0)

		for k in 5:
			drop(s4["pos"] + Vector3(3.0 + 0.2 * k, 0.0, 0.0), "other")

		step_n(a, s4, 80)
		check(loose.size() == 4 and int(a.companions.strays.get("other", {}).get("trust", 0)) == 1, "a stray eats one piece of five on a day (%d left)" % loose.size())

	loose.clear()

	# An orphan pup at its den: one piece a game day from each player. Dave's stack is left after his one meal, and the other player's
	# food is still eaten the same day (each player's trust is their own).
	a.wolves.game_seconds = func(): return now
	a.wolves.player_info = func(): return infos
	a.wolves.fires = func(): return []
	var pup2_id: int = a.spawn("wolf", 400.0, 0.0)
	var pup2: Dictionary = a.animals.get(pup2_id, {})
	a.wolves.dens["test_den"] = {"rest_until_s": 0.0, "orphan": {"den": [400.0, GROUND, 0.0], "pups": 2, "since_s": now, "trust": {}}}
	pup2["orphan"] = "test_den"
	infos = [at(1, 400.0, 25.0), at(2, 425.0, 0.0)]

	for k in 5:
		drop(Vector3(403.0 + 0.2 * k, GROUND, 0.0), "dave")

	step_n(a, pup2, 80)
	var den_trust: Dictionary = a.wolves.dens["test_den"]["orphan"]["trust"]
	check(loose.size() == 4 and int(den_trust.get("dave", {}).get("day", -1)) == a.companions._today(), "an orphan pup eats one piece of Dave's five on a day (%d left)" % loose.size())
	var o_meal: int = drop(Vector3(400.0, GROUND, -3.0), "other")
	step_n(a, pup2, 80)
	check(not loose.has(o_meal) and loose.size() == 4, "the same day it still eats the other player's food, and not more of Dave's (%d left)" % loose.size())
	a.animals.erase(pup2_id)
	a.wolves.dens.erase("test_den")
	loose.clear()

	# 11. What a player brings: every fish they can catch (fish_schools.json) and every meat a carcass gives is food the stray and the
	#     orphan pup eat ("raw or cooked meat, or fish", dog_companion_design.md 3), and every listed food is a real item.
	var table = ItemTable.load_default()
	var bring: Array = []
	var schools: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/fish_schools.json"))

	for kind in (schools as Dictionary).get("species_by_kind", {}):
		for row in schools["species_by_kind"][kind]:
			if not bring.has(str(row[0])):
				bring.append(str(row[0]))

	var carcass: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/carcass.json"))

	for group in carcass:
		if typeof(carcass[group]) != TYPE_DICTIONARY:
			continue

		for sp in carcass[group]:
			if typeof(carcass[group][sp]) == TYPE_DICTIONARY and carcass[group][sp].has("parts"):
				for part in carcass[group][sp]["parts"]:
					if str(table.entry(str(part[0])).get("kind", "")) == "food" and str(part[0]) != "egg" and not bring.has(str(part[0])):   # meat, not a bird's egg
						bring.append(str(part[0]))

	check(bring.has("raw_meat") and bring.has("trout"), "the catch and carcass lists read (%s)" % str(bring))

	for sp in ["dog", "wolf"]:
		var foods: Array = a.companions._cfg(sp).get("food", [])

		for f in bring:
			check(foods.has(f), "a %s eats %s a player brings it" % [sp, f])

		for f in foods:
			check(table.has_id(str(f)) and not bool(table.entry(str(f)).get("future", false)), "the %s's food %s is a real item" % [sp, f])

	print("test_companion_loop: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
