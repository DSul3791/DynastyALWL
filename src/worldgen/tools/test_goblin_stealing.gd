extends SceneTree

# Goblin stealing and the den pile (docs/design/goblin_stealing_design.md, Dave 8 Nov 2026): at night a goblin creeps to a small unlit loose
# thing (never a lit one or one on a den pile), takes one piece and leaves the rest, gives up when a player comes near, carries the piece home
# and lays it on the den pile; killed or bled out on the way it drops it; a burning fire near the mouth keeps a killed band from coming back.
# Plain data, no world (the item rules of server_items.stealable_near are read there; this drives the goblin side).
#   godot --headless --path . --script res://src/worldgen/tools/test_goblin_stealing.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

const GROUND := 100.0
const PATH := [Vector3(0.0, GROUND, 0.0), Vector3(20.0, 95.0, 0.0), Vector3(60.0, 80.0, 0.0), Vector3(100.0, 72.0, 0.0)]

var failures: int = 0
var hour: float = 23.0
var infos: Array = []
var loose: Dictionary = {}     # world id -> {"pos", "count", "number"}
var piles: Array = []          # [number, count, position, lifetime]
var dropped: Array = []        # [number, count, position] from drop_loot
var fires: Array = []          # [position, radius]
var den_path: PackedVector3Array = PackedVector3Array(PATH)


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
	a.hour_now = func(): return hour
	a.lair_mouths = func(_x, _z): return PackedVector2Array([Vector2(0.0, 0.0)])
	a.lair_path = func(_x, _z): return den_path
	a.lair_guarded = func(x, z, radius):
		for f in fires:
			if Vector2(f[0].x - x, f[0].z - z).length() <= radius:
				return true

		return false
	a.big_game.player_info = func(): return infos
	a.drop_loot = func(number, count, pos): dropped.append([number, count, pos])
	a.goblins.stealable = func(centre, r):
		var out: Array = []

		for id in loose:
			if int(loose[id]["count"]) > 0 and Vector2(loose[id]["pos"].x - centre.x, loose[id]["pos"].z - centre.z).length() <= r:
				out.append([id, loose[id]["pos"]])

		return out
	a.goblins.take_one = func(id):
		if not loose.has(id) or int(loose[id]["count"]) <= 0:
			return []

		loose[id]["count"] = int(loose[id]["count"]) - 1
		return [int(loose[id]["number"]), 1]
	a.goblins.hoard_drop = func(number, count, pos, life_s):
		piles.append([number, count, pos, life_s])
		return true
	a.cfg["species"]["goblin"]["den_life"]["steal_share"] = 1.0
	a.rng.seed = 13
	return a


func steps(a, g: Dictionary, seconds: float, dt: float = 0.25) -> void:
	for _n in int(seconds / dt):
		if not a.animals.has(g["id"]):
			return

		a._fire_cache = fires
		var near_d: float = INF
		var near_p: Vector3 = Vector3.INF

		for info in infos:
			var d: float = Vector2(info["pos"].x - g["pos"].x, info["pos"].z - g["pos"].z).length()

			if d < near_d:
				near_d = d
				near_p = info["pos"]

		a._step(g, dt, near_d, near_p, near_d, near_p)


# A band made at night: surface goblins at the mouth.
func band(a) -> Array:
	infos = [{"peer": 1, "pos": Vector3(-150.0, GROUND, 0.0)}]
	a._top_up_lair("goblin", a.species_def("goblin"), infos[0]["pos"], [infos[0]["pos"]])
	infos = []
	var out: Array = []

	for id in a.animals:
		if a.animals[id]["sp"] == "goblin":
			out.append(a.animals[id])

	return out


func _init() -> void:
	var a = make()
	var def: Dictionary = a.species_def("goblin")
	var gs: Array = band(a)
	check(gs.size() >= 2, "a night band is made (got %d)" % gs.size())
	var g: Dictionary = gs[0]
	check(not bool(g.get("in_cave", false)), "a band made at night is out on the surface")

	# 1. What it may take: unlit, not on a den pile.
	fires = [[Vector3(60.0, GROUND, 0.0), 10.0]]
	a._fire_cache = fires
	check(not a.goblins._may_take(Vector3(62.0, GROUND, 0.0), def), "never a thing inside a fire's light")
	check(not a.goblins._may_take(Vector3(100.0, 72.0, 0.0), def), "never a thing on the den pile")
	check(a.goblins._may_take(Vector3(30.0, GROUND, 40.0), def), "a thing out in the dark may be taken")

	# 2. It picks the unlit stack, creeps there, takes one stick and leaves the rest.
	loose = {1: {"pos": Vector3(30.0, GROUND, 40.0), "count": 5, "number": 2}, 2: {"pos": Vector3(62.0, GROUND, 0.0), "count": 3, "number": 1}}
	g["state"] = a.GRAZE
	g["timer"] = 0.01
	steps(a, g, 0.25)
	check(str(g.get("task", "")) == "steal" and int(g.get("prize", -1)) == 1 and int(g["state"]) == a.goblins.SNEAK, "at night it creeps to the unlit stack (task %s, prize %d)" % [str(g.get("task", "")), int(g.get("prize", -1))])
	steps(a, g, 60.0)
	check(int(loose[1]["count"]) == 4 and int(loose[2]["count"]) == 3, "one piece taken, the rest left, nothing from the lit pile (%d, %d)" % [int(loose[1]["count"]), int(loose[2]["count"])])
	check(g.has("loot") or not piles.is_empty(), "it carries the stick")

	# 3. Home with it: into the cave and onto the den pile, at the den floor, kept a long time.
	for _n in 400:
		steps(a, g, 0.5, 0.5)

		if not piles.is_empty():
			break

	check(piles.size() == 1 and int(piles[0][0]) == 2 and int(piles[0][1]) == 1, "the stick goes on the den pile (%s)" % str(piles))

	if not piles.is_empty():
		check((piles[0][2] as Vector3).distance_to(PATH[PATH.size() - 1]) < 0.5, "the pile is on the den floor (at %s)" % str(piles[0][2]))
		check(float(piles[0][3]) >= 86400.0, "the pile lasts days, not minutes")

	check(not g.has("loot") and float(g.get("steal_wait", 0.0)) > 0.0, "the loot is laid down and it waits before stealing again")

	# 4. A player near the thing makes it give up.
	var g2: Dictionary = gs[1]
	g2["state"] = a.GRAZE
	g2["timer"] = 0.01
	g2["steal_wait"] = 0.0
	steps(a, g2, 0.25)
	check(str(g2.get("task", "")) == "steal", "the second goblin goes stealing")
	infos = [{"peer": 1, "pos": Vector3(34.0, GROUND, 40.0)}]
	steps(a, g2, 0.25)
	check(str(g2.get("task", "")) != "steal", "a player 4 m from the stack makes it give up")
	infos = []

	# 5. Killed while carrying, it drops the piece; bled out, the same.
	dropped = []
	g2["loot"] = [2, 1]
	a.damage(int(g2["id"]), 1000.0, 1)
	check(dropped.size() == 1 and int(dropped[0][0]) == 2, "a killed goblin drops what it carried (%s)" % str(dropped))

	if gs.size() >= 3:
		var g3: Dictionary = gs[2]
		dropped = []
		g3["loot"] = [2, 1]
		g3["wound"] = true
		g3["hp"] = 0.0
		check(a.bleed(g3, 0.1) and dropped.size() == 1, "a goblin that bleeds out drops what it carried")

	# 6. Respawn: a burning fire within guard_m of the mouth keeps a killed band away; one farther off does not.
	for id in a.animals.keys():
		a.animals.erase(id)

	def["lair"]["respawn_s"] = 0.0
	fires = [[Vector3(90.0, GROUND, 0.0), 10.0]]
	band(a)
	check(a.animals.is_empty(), "no new band while a fire burns 90 m from the mouth (%d)" % a.animals.size())
	fires = [[Vector3(110.0, GROUND, 0.0), 10.0]]
	band(a)
	check(not a.animals.is_empty(), "a fire 110 m off does not stop it")

	print("test_goblin_stealing: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
