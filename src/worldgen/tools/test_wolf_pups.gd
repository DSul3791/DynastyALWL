extends SceneTree

# Wild wolf packs and the orphan pup (docs/design/wolf_packs_and_pups_design.md, Dave 8 Nov 2026 decisions 3 and 4): no den near the town;
# pups at the den in season only; pups hide from a standing player, not from a crouched, still one; the den guard warns, ends when the
# player backs off, then rushes torch or not but is held by a campfire; a killed pack's pups are orphans and its den rests; three days of
# meals make an orphan a young companion that grows up after 20 game days and keeps out of its owner's torch light; untamed orphans are gone
# after 5 game days; the dens file survives a save; pups do not count against max_wolves.
#   godot --headless --path . --script res://src/worldgen/tools/test_wolf_pups.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const WolvesScript := preload("res://src/stream/server_wolves.gd")

const GROUND := 10.0
const DAY := 86400.0

var failures: int = 0
var now: float = 100.0 * DAY + 12.0 * 3600.0   # noon, day 100: pup season
var players: Array = []
var fires_at: Array = []
var health: Dictionary = {}
var log_bites: int = 0
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
	a.player_positions = func(): return players.map(func(p): return p["pos"])
	a.player_stances = func(): return players.map(func(p): return int(p["stance"]))
	a.setup()
	a.traits = false
	a.rng.seed = 5
	a.cfg["senses"] = {}
	a.big_game.player_info = func(): return players
	var w = a.wolves
	w.player_info = func(): return players
	w.fires = func(): return fires_at
	w.notice = func(_p, _t): pass
	w.game_seconds = func(): return now
	w.hurt_player = func(peer, dmg, lethal, _cause):
		log_bites += 1
		health[peer] = float(health.get(peer, 100.0)) - dmg
		if lethal and health[peer] <= 0.0:
			return "dead"
		if not lethal and health[peer] <= 25.0:
			health[peer] = 25.0
			return "maimed"
		return "hurt"
	a.companions.peer_key = func(peer): return "dave" if int(peer) == 1 else "other"
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
	return a


func player(peer: int, x: float, z: float, stance: int = 0, torch: bool = false) -> Dictionary:
	return {"peer": peer, "pos": Vector3(x, GROUND, z), "stance": stance, "hp": 1.0, "meat": false, "spear": false, "torch": torch}


func flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


func think(a, pid: int, seconds: float) -> void:
	for _n in int(seconds / 0.1):
		if a.wolves.packs.has(pid):
			a.wolves._fire_cache = fires_at
			a.wolves._think(a.wolves.packs[pid], 0.1, players)


func step(a, x: Dictionary, n: int, dt: float = 0.25) -> void:
	for _k in n:
		var p: Vector3 = players[0]["pos"]
		var d: float = flat(p, x["pos"])
		a._step(x, dt, d, p, d, p)


func pups_of(a, pid: int) -> Array:
	var out: Array = []

	for id in a.wolves.packs[pid]["pups"]:
		if a.animals.has(id):
			out.append(a.animals[id])

	return out


func _init() -> void:
	# 1. No den within 1200 m of the town point.
	var a = make()
	a.starter = Vector2(0.0, 0.0)
	check(a.wolves.near_town(800.0, 600.0) and not a.wolves.near_town(1000.0, 1000.0), "no wolf den within 1200 m of the town point")

	# 2. Pups at the den on day 100, none on day 200; pups are not counted against max_wolves.
	players = [player(1, 400.0, 0.0)]
	var pid: int = a.wolves.spawn_pack(100.0, 0.0)
	var adults: int = (a.wolves.packs[pid]["ids"] as Array).size()
	var n: int = a.wolves.make_pups(pid)
	check(n >= 2 and n <= 5, "a pack on day 100 has 2 to 5 pups (%d)" % n)
	check(a.wolves.wolf_count() == adults, "pups are not counted against max_wolves (%d of %d)" % [a.wolves.wolf_count(), adults])
	var pup: Dictionary = pups_of(a, pid)[0] if n > 0 else {}
	check(not pup.is_empty() and int(pup["num"]) == 103 and flat(pup["pos"], Vector3(100.0, 0.0, 0.0)) <= 3.0, "a pup is sent as young, at the den")
	now = 200.0 * DAY + 12.0 * 3600.0
	var pid2: int = a.wolves.spawn_pack(3000.0, 0.0)
	check(a.wolves.make_pups(pid2) == 0, "a pack on day 200 has no pups")
	now = 100.0 * DAY + 12.0 * 3600.0

	if pup.is_empty():
		print("test_wolf_pups: %d FAILURES (no pups)" % (failures + 1))
		quit(1)
		return

	# 3. A standing player 20 m off sends the pups into the den; a crouched, still one does not.
	players = [player(1, 120.0, 0.0)]
	step(a, pup, 1)
	check(int(pup["state"]) == a.HIDDEN, "a pup hides from a standing player 20 m off (state %d)" % int(pup["state"]))
	players = [player(1, 120.0, 0.0, 1)]
	step(a, pup, 1, 6.0)
	check(int(pup["state"]) != a.HIDDEN, "it comes out for a crouched, still player (state %d)" % int(pup["state"]))

	# 4. The den guard: a player 35 m from the den is warned (growl); backing off past 45 m ends it.
	var pack: Dictionary = a.wolves.packs[pid]
	players = [player(1, 135.0, 0.0)]
	think(a, pid, 0.2)
	check(pack["phase"] == "den_guard" and not a.wolves.events.is_empty() and a.wolves.events.back()["kind"] == "growl", "a player 35 m from the den is warned (%s)" % pack["phase"])
	players = [player(1, 150.0, 0.0)]
	think(a, pid, 0.2)
	check(pack["phase"] != "den_guard", "backing off past the guard ring ends it (%s)" % pack["phase"])

	# 5. Still within 25 m after the warning: rushed, torch or not.
	players = [player(1, 120.0, 0.0, 0, true)]
	fires_at = [players[0]["pos"]]   # the torch bearer's own light is in the fire list
	think(a, pid, 2.0)
	check(log_bites == 0 and not bool(pack.get("guard_rush", false)), "no rush during the 3 s warning")
	think(a, pid, 6.0)
	check(log_bites > 0, "after the warning a player 20 m from the den is rushed, torch or not (%d bites)" % log_bites)

	# 6. A campfire by the player holds the pack at its den.
	var b = make()
	var pidb: int = b.wolves.spawn_pack(100.0, 0.0)
	b.wolves.make_pups(pidb)
	players = [player(2, 120.0, 0.0)]
	fires_at = [Vector3(122.0, GROUND, 0.0)]
	var bites_before: int = log_bites
	think(b, pidb, 8.0)
	check(log_bites == bites_before and b.wolves.packs[pidb]["phase"] == "den_guard", "a campfire by the player holds the pack (%d bites)" % (log_bites - bites_before))
	fires_at = []

	# 7. Killing the last adult orphans the pups; the den gets no new pack while they live.
	var pups_b: int = pups_of(b, pidb).size()
	var key: String = str(b.wolves.packs[pidb]["key"])

	for id in (b.wolves.packs[pidb]["ids"] as Array).duplicate():
		b.damage(int(id), 999.0, 2)

	check(not b.wolves.packs.has(pidb) and b.wolves.dens.has(key) and int(b.wolves.dens[key]["orphan"]["pups"]) == pups_b, "a killed pack's pups are orphans (%s)" % str(b.wolves.dens.get(key, {})))
	check(b.wolves._den_resting(key), "the den gets no new pack while its orphans live")
	var orphan: Dictionary = {}

	for id in b.animals:
		if str(b.animals[id].get("orphan", "")) == key:
			orphan = b.animals[id]

	check(not orphan.is_empty(), "the orphans are still at the den")

	if orphan.is_empty():
		print("test_wolf_pups: %d FAILURES (no orphan)" % failures)
		quit(1)
		return

	# 8. Three game days of meals: the orphan follows Dave as a young companion.
	players = [player(1, 125.0, 0.0)]

	for _day in 3:
		loose[next_loose] = [orphan["pos"] + Vector3(1.0, 0.0, 0.0), "dave", "raw_meat"]
		next_loose += 1
		step(b, orphan, 30)
		now += DAY

	check(orphan.has("companion_id") and not orphan.has("orphan"), "three days of meals make the orphan Dave's companion")
	var r: Dictionary = b.companions.records.get(str(orphan.get("companion_id", "")), {})
	check(not r.is_empty() and r["species"] == "wolf" and bool(r["young"]) and int(orphan["num"]) == 103, "it is a young companion wolf")
	check(int(b.wolves.dens[key].get("orphan", {"pups": 0})["pups"]) == pups_b - 1 or pups_b == 1, "one orphan fewer at the den")

	# 9. After 20 game days it is grown.
	now += 21.0 * DAY
	b.companions.tick(2.5)
	check(not bool(r.get("young", true)) and int(orphan["num"]) == 3 and str((r["history"] as Array).back()["event"]) == "grown", "after 20 game days it is a grown wolf")

	# 10. It keeps out of its owner's torch light.
	players = [player(1, 0.0, 0.0, 0, true)]
	b._fire_cache = [[players[0]["pos"], 8.0]]
	orphan["pos"] = Vector3(20.0, GROUND, 0.0)
	step(b, orphan, 60)
	check(flat(orphan["pos"], players[0]["pos"]) >= 7.9 and flat(orphan["pos"], players[0]["pos"]) <= 12.0, "a companion wolf walks at the edge of its owner's torch light (%.1f m)" % flat(orphan["pos"], players[0]["pos"]))
	b._fire_cache = []

	# 11. Untamed orphans are gone after 5 game days, and the den then rests.
	var c = make()
	var pidc: int = c.wolves.spawn_pack(5000.0, 0.0)
	c.wolves.make_pups(pidc, true)
	var keyc: String = str(c.wolves.packs[pidc]["key"])

	for id in (c.wolves.packs[pidc]["ids"] as Array).duplicate():
		c.damage(int(id), 999.0, 2)

	now += 6.0 * DAY
	c.wolves._tend_orphans([], 2.0)
	var left: int = 0

	for id in c.animals:
		left += 1 if c.animals[id].has("orphan") else 0

	check(left == 0 and c.wolves.dens.has(keyc) and not c.wolves.dens[keyc].has("orphan") and c.wolves._den_resting(keyc), "untamed orphans are gone after 5 game days and the den rests")

	# 12. The dens file survives a save and a load.
	c.wolves.store_dir = "user://test_wolf_pups"
	DirAccess.make_dir_recursive_absolute(c.wolves.store_dir)
	c.wolves.save_dens()
	var w2 = WolvesScript.new()
	w2.host = c
	w2.game_seconds = func(): return now
	w2.store_dir = c.wolves.store_dir
	w2.load_dens()
	check(w2.dens.has(keyc) and w2._den_resting(keyc), "a resting den survives a save and a load")

	print("test_wolf_pups: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
