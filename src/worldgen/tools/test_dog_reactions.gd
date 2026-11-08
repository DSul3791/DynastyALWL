extends SceneTree

# Wild animals and the player's dog (docs/design/dog_companion_design.md 11; MikeW, docs/design/DOG_REACTIONS.md): a deer watches a dog at
# 50 m and bolts at 39 m; a rabbit flees a barking dog from twice as far as a silent one; a goblin backs off from a barking dog, holds, and
# comes on again once the dog is quiet, and flees two; a bear warns at a dog, keeps warning while it stays off, and charges it once it comes
# within 10 m; a moose with no calf flees a dog; a wolf pack goes for the dog and bites it.
#   godot --headless --path . --script res://src/worldgen/tools/test_dog_reactions.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

const GROUND := 10.0

var failures: int = 0
var players: Array = []


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
	a.rng.seed = 7
	a.big_game.player_info = func(): return players
	a.wolves.player_info = func(): return players
	a.wolves.fires = func(): return []
	a.wolves.notice = func(_p, _t): pass
	a.wolves.hurt_player = func(_peer, _dmg, _lethal, _cause): return "hurt"
	a.wolves.game_seconds = func(): return 200.0 * 86400.0 + 12.0 * 3600.0   # day 200 noon: no pups
	return a


func dog_at(a, x: float, z: float, barking: bool = false) -> int:
	var id: int = a.spawn("dog", x, z)
	a.animals[id]["companion_id"] = "c%d" % id

	if barking:
		a.animals[id]["bark_ms"] = Time.get_ticks_msec()

	a._dogs = a._dog_presences()
	return id


func quiet(a, id: int) -> void:
	a.animals[id]["bark_ms"] = -1000000
	a._dogs = a._dog_presences()


func step(a, x: Dictionary, n: int, dt: float = 0.25) -> void:
	for _k in n:
		a._step(x, dt, INF, Vector3.INF, INF, Vector3.INF)


func flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


func _init() -> void:
	# 1. A deer watches a dog at 50 m and bolts at 39 m.
	var a = make()
	var deer_id: int = a.spawn("deer", 0.0, 0.0)
	var deer: Dictionary = a.animals[deer_id]
	var dog: int = dog_at(a, 50.0, 0.0)
	step(a, deer, 1)
	check(deer["state"] == AnimalsScript.ALERT, "a deer watches a dog 50 m off (state %d)" % deer["state"])
	a.animals[dog]["pos"] = Vector3(39.0, GROUND, 0.0)
	a._dogs = a._dog_presences()
	step(a, deer, 1)
	check(deer["state"] == AnimalsScript.FLEE, "and bolts at 39 m (state %d)" % deer["state"])

	# 2. A rabbit 35 m from a dog: a silent dog is beyond its notice, a barking one is heard twice as far and it flees.
	var b = make()
	var rab: Dictionary = b.animals[b.spawn("rabbit", 0.0, 0.0)]
	var bdog: int = dog_at(b, 35.0, 0.0)
	step(b, rab, 1)
	check(rab["state"] != AnimalsScript.FLEE, "a silent dog 35 m off leaves a rabbit be (state %d)" % rab["state"])
	b.animals[bdog]["bark_ms"] = Time.get_ticks_msec()
	b._dogs = b._dog_presences()
	step(b, rab, 1)
	check(rab["state"] == AnimalsScript.FLEE, "a barking one 35 m off sends it running (state %d)" % rab["state"])

	# 3. A goblin 15 m from a barking dog steps back about 5 m, faces it, holds, and comes on again once the dog is quiet.
	var c = make()
	var gob: Dictionary = c.animals[c.spawn("goblin", 0.0, 0.0)]
	var cdog: int = dog_at(c, 15.0, 0.0, true)
	var start: Vector3 = gob["pos"]
	step(c, gob, 20)
	check(gob.has("dog_hold") and gob["state"] == AnimalsScript.ALERT, "a goblin holds, watching a barking dog (state %d)" % gob["state"])
	check(flat(gob["pos"], start) >= 4.0 and gob["pos"].x < start.x, "after stepping back about 5 m from it (%.1f m)" % flat(gob["pos"], start))
	check(absf(angle_difference(float(gob["heading"]), 0.0)) < 0.2, "facing the dog")
	quiet(c, cdog)
	step(c, gob, 40)
	check(not gob.has("dog_hold") and gob["state"] != AnimalsScript.ALERT, "once the dog is quiet it comes on again (state %d)" % gob["state"])
	var c2 = make()
	var gob2: Dictionary = c2.animals[c2.spawn("goblin", 0.0, 0.0)]
	dog_at(c2, 12.0, 0.0, true)
	dog_at(c2, 0.0, 12.0, true)
	step(c2, gob2, 1)
	check(gob2["state"] == AnimalsScript.FLEE, "two barking dogs make a goblin flee (state %d)" % gob2["state"])
	var c3 = make()
	var gob3: Dictionary = c3.animals[c3.spawn("goblin", 0.0, 0.0)]
	dog_at(c3, 12.0, 0.0)
	step(c3, gob3, 1)
	check(not gob3.has("dog_hold"), "a silent dog does not move a goblin")

	# 4. A bear warns at a dog 25 m off, keeps warning while it stays off, and charges it once it comes within 10 m.
	var d = make()
	var bear: Dictionary = d.animals[d.spawn("bear", 0.0, 0.0)]
	var ddog: int = dog_at(d, 25.0, 0.0)
	var dog_hp: float = float(d.animals[ddog]["hp"])
	step(d, bear, 1)
	check(bear["state"] == 10 and int(bear.get("foe_dog", 0)) == ddog, "a bear warns at a dog 25 m off (state %d)" % bear["state"])
	var rows: Array = d.rows_near(Vector3.ZERO).filter(func(r): return int(r[0]) == int(bear["id"]))
	check(rows.size() == 1 and (rows[0] as Array).size() == 6 and flat(rows[0][5], d.animals[ddog]["pos"]) < 0.01, "its row carries the dog's position for the client")
	step(d, bear, 16)
	# Still a warning: the huff (WARN, 10) gives way to the jaw-pop (WARN_POP, 16) as the timer runs, and it holds there while the dog stays off.
	check(bear["state"] == 10 or bear["state"] == 16, "it keeps warning while the dog stays 25 m off (state %d)" % bear["state"])
	d.animals[ddog]["pos"] = Vector3(9.0, GROUND, 0.0)
	d._dogs = d._dog_presences()
	var charged: bool = false

	for _k in 20:
		step(d, bear, 1)
		charged = charged or bear["state"] == 11

	check(charged, "it charges once the dog is within 10 m")
	check(not d.animals.has(ddog) or float(d.animals[ddog]["hp"]) < dog_hp, "the charge hits the dog")

	# 5. A moose with no calf flees a dog rather than standing to it.
	var e = make()
	var moose: Dictionary = e.animals[e.spawn("moose", 0.0, 0.0)]
	dog_at(e, 15.0, 0.0)
	step(e, moose, 1)
	check(moose["state"] == AnimalsScript.FLEE, "a moose with no calf flees a dog 15 m off (state %d)" % moose["state"])

	# 6. A wolf pack goes for the dog and bites it.
	var f = make()
	players = [{"peer": 1, "pos": Vector3(60.0, GROUND, 0.0), "stance": 0, "hp": 1.0, "meat": false, "spear": false, "torch": false}]
	var pid: int = f.wolves.spawn_pack(0.0, 0.0)
	var fdog: int = dog_at(f, 40.0, 0.0)
	var fdog_hp: float = float(f.animals[fdog]["hp"])
	var pack: Dictionary = f.wolves.packs[pid]

	for _k in 100:
		if f.wolves.packs.has(pid):
			f.wolves._think(pack, 0.1, players)

	check(int(pack.get("prey", 0)) == fdog or not f.animals.has(fdog) or float(f.animals[fdog]["hp"]) < fdog_hp, "a prowling pack goes for the dog (phase %s)" % str(pack["phase"]))
	check(not f.animals.has(fdog) or float(f.animals[fdog]["hp"]) < fdog_hp, "and bites it")
	players = []

	print("test_dog_reactions: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
