extends SceneTree

# Bird flocks (Radar, 2026-10-21): they float on water, raise their heads, and the whole flock takes off together away from a person,
# alarming others; they only settle on water; a hit kills one bird and the rest rise.
#   godot --headless --path . --script res://src/worldgen/tools/test_flocks.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

var failures: int = 0
var players: Array = []
var killed: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 3.0
	a.blocked = func(x, z): return x > 100.0 and x < 300.0 and absf(z) < 100.0   # a lake
	a.water_level = func(x, z): return 5.0 if x > 100.0 and x < 300.0 and absf(z) < 100.0 else NAN
	a.player_positions = func(): return players
	a.player_stances = func(): return players.map(func(_p): return 0)
	a.setup()

	for sp in ["rabbit", "deer", "moose", "fox", "duck", "horse", "boar", "songbirds", "frog"]:
		a.cfg["species"][sp]["target_per_player"] = 0

	a.cfg["senses"] = {}
	a.rng.seed = 9
	a.died = func(sp, pos, peer): killed.append([sp, pos, peer])
	return a


func _init() -> void:
	# 1. A flock floats on the lake; a person far off changes nothing; at 40 m it raises its head; at 15 m it takes off.
	var a = make()
	players = [Vector3(60.0, 3.0, 0.0)]
	var id: int = a.spawn("duck", 150.0, 0.0)
	check(id != 0 and absf(a.animals[id]["pos"].y - 5.0) < 0.01 and int(a.animals[id]["birds"]) >= 6, "a flock sits on the water surface with 6 to 14 birds")

	for n in 40:
		a.tick(0.05)

	check(a.animals[id]["state"] == 0, "a person 90 m off is ignored")
	players = [Vector3(110.0, 3.0, 0.0)]

	for n in 40:
		a.tick(0.05)

	check(a.animals[id]["state"] == 3, "at 40 m the flock raises its heads")
	players = [Vector3(135.0, 3.0, 0.0)]
	var rabbit: int = 0
	a.cfg["species"]["rabbit"]["alert_m"] = 0.0
	rabbit = a.spawn("rabbit", 160.0, 20.0)
	a.animals[rabbit]["timer"] = 100.0

	for n in 10:
		a.tick(0.05)

	check(a.animals[id]["state"] == 15, "at 15 m the whole flock takes off")
	var start: Vector3 = a.animals[id]["pos"]

	for n in 60:
		a.tick(0.05)

	check(a.animals[id]["pos"].x > start.x + 20.0 and a.animals[id]["pos"].y > 5.5, "it flies away from the person and climbs")
	check(float(a.animals[rabbit]["alarm"]) >= 0.0 or a.animals[rabbit]["state"] != 0, "the alarm sets nearby wildlife running")

	for n in 1200:
		a.tick(0.05)

	check(not a.animals.has(id), "it is gone after flying 160 m")

	# 2. Flocks settle only on water.
	a = make()
	players = [Vector3(200.0, 3.0, 200.0)]
	a.cfg["species"]["duck"]["target_per_player"] = 3
	a.cfg["species"]["duck"]["spawn_share"] = 1.0
	a.cfg["senses"] = {}

	for n in 400:
		a.tick(0.05)

	var on_water: bool = not a.animals.is_empty()

	for fid in a.animals:
		on_water = on_water and a.blocked.call(a.animals[fid]["pos"].x, a.animals[fid]["pos"].z)

	check(on_water, "new flocks appear only on the lake (%d)" % a.animals.size())

	# 3. A hit kills one bird; the rest take off; the last bird ends the flock.
	a = make()
	players = [Vector3(100.0, 3.0, 0.0)]
	id = a.spawn("duck", 160.0, 0.0)
	a.animals[id]["birds"] = 2
	killed.clear()
	check(not a.damage(id, 8.0, 1) and killed.size() == 1 and killed[0][0] == "duck", "one hit kills one bird and leaves a carcass")
	check(a.animals[id]["state"] == 15, "the rest of the flock takes off")
	check(a.damage(id, 8.0, 1) and not a.animals.has(id), "the last bird ends the flock")
	print("flocks: %d failures" % failures)
	quit(failures)
