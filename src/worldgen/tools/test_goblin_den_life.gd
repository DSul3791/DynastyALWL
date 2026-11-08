extends SceneTree

# Goblin den life (docs/design/goblin_den_life_design.md): the cave floor path from a den mouth to the den, a group made by day asleep in the
# den, walking out at night, a player on the hill above the den not "in" it, the in-cave warning and lunge (backing off avoids it), watching
# at the edge of a fire's light, foraging at a berry bush, and a group deep in its cave still holding the mouth. Plain data, no world.
#   godot --headless --path . --script res://src/worldgen/tools/test_goblin_den_life.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const GoblinsScript := preload("res://src/stream/server_goblins.gd")

const GROUND := 100.0
# A cave under flat ground at 100 m: the mouth at x 0, a passage sloping down east to the den at x 100, 28 m under the hill.
const PATH := [Vector3(0.0, GROUND, 0.0), Vector3(20.0, 95.0, 0.0), Vector3(60.0, 80.0, 0.0), Vector3(100.0, 72.0, 0.0)]

var failures: int = 0
var hour: float = 12.0
var infos: Array = []
var hurts: int = 0
var den_path: PackedVector3Array = PackedVector3Array(PATH)
var bushes: PackedVector3Array = PackedVector3Array([Vector3(30.0, GROUND, -20.0)])


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
	a.berry_bushes = func(_p, _r): return bushes
	a.big_game.player_info = func(): return infos
	a.big_game.hurt_player = func(_peer, _amount, _lethal, _cause):
		hurts += 1
		return "hurt"
	a.rng.seed = 11
	return a


func goblins_of(a) -> Array:
	var out: Array = []

	for id in a.animals:
		if a.animals[id]["sp"] == "goblin":
			out.append(a.animals[id])

	return out


func steps(a, g: Dictionary, seconds: float, dt: float = 0.25) -> void:
	for _n in int(seconds / dt):
		if not a.animals.has(g["id"]):
			return

		var near_d: float = INF
		var near_p: Vector3 = Vector3.INF

		for info in infos:
			var d: float = Vector2(info["pos"].x - g["pos"].x, info["pos"].z - g["pos"].z).length()

			if d < near_d:
				near_d = d
				near_p = info["pos"]

		a._step(g, dt, near_d, near_p, near_d, near_p)


func _init() -> void:
	# 1. The floor path: a breadth-first walk from the mouth node to the den node, each point the node's floor (middle line less half its height).
	var cave: Dictionary = {"nodes": [[0, 102, 0, 10, 4], [20, 97, 0, 5, 4], [60, 82, 0, 5, 4], [100, 74, 0, 6, 4], [20, 97, 30, 4, 4], [200, 50, 0, 4, 4]],
		"segments": [[0, 1, "main"], [1, 4, "branch"], [1, 2, "main"], [2, 3, "main"]]}
	var path: PackedVector3Array = TileTerrainData.cave_floor_path(cave, 0, 3)
	check(path.size() == 4, "the den path has the 4 nodes from mouth to den (got %d)" % path.size())

	if path.size() == 4:
		check(path[0].is_equal_approx(Vector3(0, 100, 0)) and path[3].is_equal_approx(Vector3(100, 72, 0)), "the path starts at the mouth floor and ends at the den floor")

	check(TileTerrainData.cave_floor_path(cave, 0, 5).is_empty(), "a node not joined to the mouth gives no path")
	check(is_equal_approx(GoblinsScript.path_length(den_path), 20.0 * sqrt(1.0 + 0.0625) + sqrt(1600.0 + 225.0) + sqrt(1600.0 + 64.0)), "path_length adds the legs")

	# 2. By day a new group is made asleep in the den, on the cave floor, not on the hill above.
	hour = 12.0
	infos = [{"peer": 1, "pos": Vector3(-150.0, GROUND, 0.0)}]
	var a = make()
	a._top_up_lair("goblin", a.species_def("goblin"), infos[0]["pos"], [infos[0]["pos"]])
	var band: Array = goblins_of(a)
	check(band.size() >= 2 and band.size() <= 5, "a group of 2 to 5 is made (got %d)" % band.size())

	for g in band:
		check(bool(g.get("in_cave", false)), "a goblin made by day is in the cave")
		check(g["pos"].y < 80.0 and g["pos"].x > 90.0, "it sleeps at the den, on the floor (at %s)" % str(g["pos"]))
		check(str(g.get("lair", "")) == "0,0", "it carries its cave's key")

	# 3. A group deep in its cave still holds the mouth: no second group.
	a._top_up_lair("goblin", a.species_def("goblin"), infos[0]["pos"], [infos[0]["pos"]])
	check(goblins_of(a).size() == band.size(), "no second group while the first sleeps inside")

	# 4. A player on the hill right over the den is not in it, and the band does not react.
	var g0: Dictionary = band[0]
	infos = [{"peer": 1, "pos": Vector3(100.0, GROUND, 0.0)}]
	check(not a._in_den(g0, a.species_def("goblin"), infos[0]["pos"]), "a player on the hill above the den is not in the den")
	var before: Vector3 = g0["pos"]
	steps(a, g0, 5.0)
	check(g0["pos"].distance_to(before) < 0.5 and int(g0["state"]) < a.WARN, "the band sleeps on under a player on the hill")

	# 5. A player inside the den's threat range gets a warning; if still close when it ends, a lunge that hits.
	hurts = 0
	infos = [{"peer": 1, "pos": g0["pos"] + Vector3(-4.0, 0.0, 0.0)}]
	steps(a, g0, 0.25)
	check(int(g0["state"]) == a.WARN, "a player 4 m away in the den is warned (state %d)" % int(g0["state"]))
	steps(a, g0, 3.0)
	check(hurts == 1, "staying through the warning gets one strike (got %d)" % hurts)

	# 6. Backing off during the warning avoids the strike.
	var g1: Dictionary = band[1]
	hurts = 0
	infos = [{"peer": 1, "pos": g1["pos"] + Vector3(-4.0, 0.0, 0.0)}]
	steps(a, g1, 0.25)
	check(int(g1["state"]) == a.WARN, "the second goblin warns too")
	infos = [{"peer": 1, "pos": GoblinsScript.point_at(den_path, 40.0)}]
	steps(a, g1, 3.0)
	check(hurts == 0, "backing off about 60 m up the passage during the warning is not struck")

	# 7. At night they walk out along the path and become surface goblins at the mouth.
	hour = 23.0
	infos = []
	var g2: Dictionary = band[band.size() - 1]
	g2["cool"] = 0.0
	for _n in 400:
		steps(a, g2, 0.5, 0.5)

		if not bool(g2.get("in_cave", true)):
			break
	check(not bool(g2.get("in_cave", true)), "at night it has walked out of the cave")
	check(Vector2(g2["pos"].x, g2["pos"].z).length() < 1.0 and is_equal_approx(g2["pos"].y, GROUND), "it comes out at the mouth on the ground (at %s)" % str(g2["pos"]))
	check(g2.has("den_out"), "it ranges round the mouth it came out of")

	# 8. Watch: a fire 60 m from the mouth; it creeps to the edge of the light and stands facing the fire.
	var def: Dictionary = a.species_def("goblin")
	def["den_life"]["watch_share"] = 1.0
	var fire: Vector3 = Vector3(60.0, GROUND, 0.0)
	a._fire_cache = [[fire, 10.0]]
	g2["state"] = a.GRAZE
	g2["timer"] = 0.01
	steps(a, g2, 0.25)
	check(str(g2.get("task", "")) == "watch", "at night an idle goblin goes to watch a fire")
	infos = [{"peer": 1, "pos": fire}]   # a player sits at the fire
	steps(a, g2, 50.0)   # 48 m at 1.2 m/s, then it watches for at least 60 s
	var off: float = Vector2(g2["pos"].x - fire.x, g2["pos"].z - fire.z).length()
	check(off >= 10.0 and off <= 13.0, "it stands just outside the fire's light (%.1f m from the fire)" % off)
	check(int(g2["state"]) == a.ALERT, "it watches (ALERT) while the player sits 12 m away")
	check(Vector2.from_angle(float(g2["heading"])).dot(Vector2(fire.x - g2["pos"].x, fire.z - g2["pos"].z).normalized()) > 0.98, "it faces the fire")
	infos = [{"peer": 1, "pos": g2["pos"] + Vector3(4.0, 0.0, 0.0)}]
	steps(a, g2, 0.25)
	check(int(g2["state"]) == a.FLEE, "a player who comes within watch_spook_m makes it bolt")

	# 9. Forage: with no fire to watch it goes to a berry bush, outside the light.
	def["den_life"]["watch_share"] = 0.0
	a._fire_cache = []
	infos = []
	g2["state"] = a.GRAZE
	g2["timer"] = 0.01
	g2["task"] = ""
	steps(a, g2, 0.25)
	check(str(g2.get("task", "")) == "forage" and Vector2(g2["target"].x - bushes[0].x, g2["target"].z - bushes[0].z).length() <= 1.0, "an idle goblin at night goes to a berry bush")
	steps(a, g2, 35.0)   # about 28 m at 1.2 m/s, then it eats for at least 20 s
	check(bool(g2.get("eating", false)), "it eats at the bush")
	check(Vector2(g2["pos"].x - bushes[0].x, g2["pos"].z - bushes[0].z).length() <= 2.0, "it reaches the bush (at %s)" % str(g2["pos"]))

	# 10. A tile without paths keeps the old way: the group at the mouth, the den there.
	den_path = PackedVector3Array()
	hour = 12.0
	infos = [{"peer": 1, "pos": Vector3(-150.0, GROUND, 0.0)}]
	var b = make()
	b._top_up_lair("goblin", b.species_def("goblin"), infos[0]["pos"], [infos[0]["pos"]])

	for g in goblins_of(b):
		check(not bool(g.get("in_cave", false)) and Vector2(g["pos"].x, g["pos"].z).length() < 6.0, "without a path the group stays at the mouth")

	print("test_goblin_den_life: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
