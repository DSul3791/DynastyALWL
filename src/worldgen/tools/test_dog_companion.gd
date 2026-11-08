extends SceneTree

# Dog companion, step 1 (docs/design/dog_companion_design.md, Dave 8 Nov 2026 decisions 5 and 6): a stray turns up by day near the town
# point for a player with no dog and keeps off; food that player left is eaten once they back off, once a game day; on the third day it
# becomes their dog (a record with a name and a bond). The dog follows, runs to catch up, waits at a fire's edge but not at its owner's
# torch, barks at a bear from bond 0.3, ignores its owner's blows; the bond moves with fed and unfed days and at 0 the dog leaves; an heir
# inherits it at 70 % of the bond; the records survive a save; a dog goes when its owner leaves and comes back with them.
#   godot --headless --path . --script res://src/worldgen/tools/test_dog_companion.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const CompanionsScript := preload("res://src/stream/server_companions.gd")

const GROUND := 100.0
const DAY := 86400.0

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


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return GROUND
	a.blocked = func(_x, _z): return false
	a.player_positions = func():
		var out: Array = []

		for info in infos:
			out.append(info["pos"])

		return out
	a.setup()
	a.traits = false
	a.starter = Vector2(0.0, 0.0)
	a.hour_now = func(): return hour
	a.big_game.player_info = func(): return infos
	a.companions.peer_key = func(peer): return "dave" if int(peer) == 1 else ("heir" if int(peer) == 3 else "other")
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
	a.rng.seed = 23
	return a


func drop(at: Vector3, by: String, item: String = "raw_meat") -> int:
	var id: int = next_loose
	next_loose += 1
	loose[id] = [at, by, item]
	return id


func flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


func step_n(a, d: Dictionary, n: int, dt: float = 0.25) -> void:
	for _k in n:
		var p: Vector3 = infos[0]["pos"] if not infos.is_empty() else Vector3.INF
		var dist: float = flat(p, d["pos"]) if p != Vector3.INF else INF
		a._step(d, dt, dist, p, dist, p)


func the_stray(a) -> Dictionary:
	for id in a.animals:
		if a.animals[id].has("stray_for"):
			return a.animals[id]

	return {}


func _init() -> void:
	# 1. By day a stray turns up in the 60-150 m ring round the town point for Dave, and only one; at night none comes for another player.
	var a = make()
	infos = [{"peer": 1, "pos": Vector3(0.0, GROUND, 0.0), "stance": 0}]
	a.companions.tick(2.5)
	a.companions.tick(2.5)
	var count: int = 0

	for id in a.animals:
		if a.animals[id].get("stray_for", "") == "dave":
			count += 1

	var s: Dictionary = the_stray(a)
	check(count == 1, "one stray for a player with no dog (%d)" % count)
	check(not s.is_empty() and flat(s["pos"], Vector3.ZERO) >= 59.0 and flat(s["pos"], Vector3.ZERO) <= 151.0, "the stray is 60 to 150 m from the town point")
	var night = make()
	hour = 23.0
	infos = [{"peer": 2, "pos": Vector3(0.0, GROUND, 0.0), "stance": 0}]
	night.companions.tick(2.5)
	check(the_stray(night).is_empty(), "no stray turns up at night")
	hour = 12.0

	if s.is_empty():
		print("test_dog_companion: %d FAILURES (no stray)" % (failures + 1))
		quit(1)
		return

	# 2. It keeps 12 m off a standing player who walks at it, and watches a player 20 m off.
	s["pos"] = Vector3(40.0, GROUND, 0.0)
	infos = [{"peer": 1, "pos": Vector3(34.0, GROUND, 0.0), "stance": 0}]
	step_n(a, s, 8)
	check(flat(s["pos"], infos[0]["pos"]) > 8.0, "the stray backs off a player 6 m away (%.1f m)" % flat(s["pos"], infos[0]["pos"]))
	s["pos"] = Vector3(40.0, GROUND, 0.0)
	infos[0]["pos"] = Vector3(20.0, GROUND, 0.0)
	step_n(a, s, 1)
	check(int(s["state"]) == a.ALERT, "it watches a player 20 m off (state %d)" % int(s["state"]))

	# 3. Food: not eaten while Dave stands beside it, nor another player's; eaten once Dave is 6 m off; one meal a day counts.
	var food: int = drop(Vector3(44.0, GROUND, 0.0), "dave")
	var theirs: int = drop(Vector3(38.0, GROUND, 0.0), "other")
	infos[0]["pos"] = Vector3(46.0, GROUND, 3.0)   # 3.6 m from the meat: too close (and the stray backs off)
	step_n(a, s, 4)
	check(loose.has(food), "the stray does not eat while the giver stands by the food")
	infos[0]["pos"] = Vector3(44.0, GROUND, 25.0)
	step_n(a, s, 40)
	check(not loose.has(food), "it eats the food once the giver has backed off")
	check(loose.has(theirs), "it leaves food another player dropped")
	check(int(a.companions.strays.get("dave", {}).get("trust", 0)) == 1, "one meal is one trust (%s)" % str(a.companions.strays.get("dave", {})))
	food = drop(s["pos"] + Vector3(2.0, 0.0, 0.0), "dave")
	step_n(a, s, 20)
	check(int(a.companions.strays["dave"]["trust"]) == 1, "a second meal the same game day does not count")

	# 4. Days two and three: it becomes Dave's dog, with a record.
	for _day in 2:
		now += DAY
		drop(s["pos"] + Vector3(2.0, 0.0, 0.0), "dave")
		step_n(a, s, 20)

	check(s.has("companion_id") and not s.has("stray_for"), "three days of meals make it Dave's dog")
	var rid: String = str(s.get("companion_id", ""))
	var r: Dictionary = a.companions.records.get(rid, {})
	check(not r.is_empty() and r["owner_key"] == "dave" and is_equal_approx(float(r["bond"]), 0.1) and str(r["name"]) != "", "the record: owner, bond 0.1, a name")
	check(not r.is_empty() and (r["history"] as Array).size() == 1 and str(r["history"][0]["event"]) == "tamed", "its history starts with tamed")
	a.companions.tick(2.5)
	count = 0

	for id in a.animals:
		if a.animals[id].has("stray_for"):
			count += 1

	check(count == 0, "no new stray for a player who has a dog (%d)" % count)

	# 5. Following: it closes on its owner 30 m off, running; one 100 m off (a fast travel) is caught up at once.
	loose.clear()
	s["pos"] = Vector3(0.0, GROUND, 0.0)
	infos = [{"peer": 1, "pos": Vector3(30.0, GROUND, 0.0), "stance": 0}]
	step_n(a, s, 1)
	check(int(s["state"]) == a.FLEE, "it runs to an owner 30 m off (state %d)" % int(s["state"]))
	step_n(a, s, 40)
	check(flat(s["pos"], infos[0]["pos"]) <= 5.0, "it ends up at its owner's heels (%.1f m)" % flat(s["pos"], infos[0]["pos"]))
	infos[0]["pos"] = Vector3(140.0, GROUND, 0.0)
	step_n(a, s, 1)
	check(flat(s["pos"], infos[0]["pos"]) <= 4.0, "an owner 110 m off is caught up at once")

	# 6. Fires: it waits at the edge of a campfire's keep-off ring, but not at its owner's own torch.
	infos[0]["pos"] = Vector3(0.0, GROUND, 0.0)
	s["pos"] = Vector3(20.0, GROUND, 0.0)
	a._fire_cache = [[Vector3(2.0, GROUND, 0.0), 8.0]]
	step_n(a, s, 40)
	check(flat(s["pos"], Vector3(2.0, GROUND, 0.0)) >= 7.9, "it stays out of a campfire's keep-off ring (%.1f m)" % flat(s["pos"], Vector3(2.0, GROUND, 0.0)))
	a._fire_cache = [[Vector3(0.0, GROUND, 0.0), 8.0]]   # the owner carries a torch
	s["pos"] = Vector3(20.0, GROUND, 0.0)
	step_n(a, s, 40)
	check(flat(s["pos"], infos[0]["pos"]) <= 5.0, "it comes to heel beside its owner's torch (%.1f m)" % flat(s["pos"], infos[0]["pos"]))
	a._fire_cache = []

	# 7. Barking: at bond 0.1 a bear 30 m from its owner is not barked at; at 0.3 it is, once.
	var bear: int = a.spawn("bear", 30.0, 0.0)
	s["pos"] = Vector3(-2.0, GROUND, 0.0)
	step_n(a, s, 1)
	check(int(s["state"]) != a.ALERT, "no bark at bond 0.1 (state %d)" % int(s["state"]))
	r["bond"] = 0.3
	step_n(a, s, 1)
	check(int(s["state"]) == a.ALERT and s.get("barked", {}).has(bear), "at bond 0.3 it barks at a bear 30 m from its owner")
	s["pos"] = Vector3(-10.0, GROUND, 0.0)
	step_n(a, s, 1)
	check(int(s["state"]) != a.ALERT, "one bark per bear, not every step")
	a.animals.erase(bear)

	# 8. Its owner's blow does nothing; another player's hurts it.
	var hp: float = float(s["hp"])
	a.damage(int(s["id"]), 3.0, 1)
	check(is_equal_approx(float(s["hp"]), hp), "its owner's blow does nothing")
	a.damage(int(s["id"]), 3.0, 2)
	check(float(s["hp"]) < hp, "another player's blow hurts it")

	# 9. The bond: a fed day near its owner +0.05; an unfed day out with them -0.05; at 0 it leaves.
	r["bond"] = 0.3
	r["near_day"] = a.companions._today()
	r["near_s"] = 700.0
	r["fed_day"] = a.companions._today()
	now += DAY
	a.companions._roll_day(r)
	check(is_equal_approx(float(r["bond"]), 0.35), "a fed day near its owner adds 0.05 (%.2f)" % float(r["bond"]))
	r["near_s"] = 300.0
	now += DAY
	a.companions._roll_day(r)
	check(is_equal_approx(float(r["bond"]), 0.3), "an unfed day out with its owner takes 0.05 (%.2f)" % float(r["bond"]))
	now += DAY
	a.companions._roll_day(r)
	check(is_equal_approx(float(r["bond"]), 0.3), "a day apart changes nothing (%.2f)" % float(r["bond"]))

	# 10. An heir inherits it at 70 % of the bond.
	check(a.companions.inherit("dave", "heir") == 1, "inherit moves the dog to the heir")
	check(r["owner_key"] == "heir" and is_equal_approx(float(r["bond"]), 0.21) and str((r["history"] as Array).back()["event"]) == "inherited", "the heir has it at 70 %% of the bond (%.2f)" % float(r["bond"]))

	# 11. The save: records and stray trust come back.
	a.companions.strays["other"] = {"trust": 2.0, "day": 3}
	a.companions.store_dir = "user://test_dog_companion"
	DirAccess.make_dir_recursive_absolute(a.companions.store_dir)
	a.companions.save()
	var c2 = CompanionsScript.new()
	c2.host = a
	c2.store_dir = a.companions.store_dir
	c2.load_records()
	check(c2.records.has(rid) and str(c2.records[rid]["owner_key"]) == "heir" and is_equal_approx(float(c2.records[rid]["bond"]), 0.21), "the record survives a save and a load")
	check(int(c2.strays.get("other", {}).get("trust", 0)) == 2 and c2.next_id == a.companions.next_id, "stray trust and the next id survive too")

	# 12. Its owner leaves: the dog goes; they come back: it is made again beside them.
	infos = [{"peer": 3, "pos": Vector3(500.0, GROUND, 500.0), "stance": 0}]
	a.companions.live[rid] = int(s["id"])
	infos = []
	a.companions.tick(2.5)
	check(not a.animals.has(int(s["id"])), "the dog leaves the world with its owner")
	infos = [{"peer": 3, "pos": Vector3(500.0, GROUND, 500.0), "stance": 0}]
	a.companions.tick(2.5)
	var back: int = int(a.companions.live.get(rid, 0))
	check(back != 0 and a.animals.has(back) and flat(a.animals[back]["pos"], infos[0]["pos"]) <= 4.0, "it is made again beside its owner when they come back")

	# 13. Bond at 0: it leaves its owner and the record says so.
	r["bond"] = 0.05
	r["near_day"] = a.companions._today()
	r["near_s"] = 200.0
	r["fed_day"] = -1
	now += DAY
	a.companions._roll_day(r)
	check(r["owner_key"] == "" and str((r["history"] as Array).back()["event"]) == "lost" and not a.animals.has(back), "at bond 0 the dog leaves")

	print("test_dog_companion: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
