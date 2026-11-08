extends SceneTree

# Goblin friendship, step 1 (docs/design/goblin_friendship_step1_design.md, Dave 8 Nov 2026): trust per band and character from gifts (once a
# night), steps Tolerated and Known, forgetting, harm and wariness, the save; and the band's behaviour: a Tolerated player watched rather than
# fled from, a Known player's things left alone (their food taken), a return gift once a day, a wary band running at twice spook_m.
#   godot --headless --path . --script res://src/worldgen/tools/test_goblin_friendship.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const TrustScript := preload("res://src/stream/server_goblin_trust.gd")

const GROUND := 100.0
const DAY := 86400.0
const PATH := [Vector3(0.0, GROUND, 0.0), Vector3(20.0, 95.0, 0.0), Vector3(60.0, 80.0, 0.0), Vector3(100.0, 72.0, 0.0)]

var failures: int = 0
var now: float = 100.0 * DAY + 22.0 * 3600.0   # 22:00 on day 100
var infos: Array = []
var loose: Dictionary = {}
var gifts_left: Array = []


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
	a.hour_now = func(): return 23.0
	a.lair_mouths = func(_x, _z): return PackedVector2Array([Vector2(0.0, 0.0)])
	a.lair_path = func(_x, _z): return PackedVector3Array(PATH)
	a.big_game.player_info = func(): return infos
	a.goblins.peer_key = func(peer): return "dave" if int(peer) == 1 else "other"
	a.goblins.item_number = func(id): return 7 if str(id) == "dried_berries" else 8
	a.goblins.gift_drop = func(number, count, pos, by):
		gifts_left.append([number, count, pos, by])
		return true
	a.goblins.stealable = func(centre, r):
		var out: Array = []

		for id in loose:
			if Vector2(loose[id][0].x - centre.x, loose[id][0].z - centre.z).length() <= r:
				out.append([id, loose[id][0], loose[id][1], loose[id][2]])

		return out
	a.goblins.trust.game_seconds = func(): return now
	a.rng.seed = 17
	return a


func band(a) -> Array:
	infos = [{"peer": 9, "pos": Vector3(-150.0, GROUND, 0.0)}]
	a._top_up_lair("goblin", a.species_def("goblin"), infos[0]["pos"], [infos[0]["pos"]])
	infos = []
	var out: Array = []

	for id in a.animals:
		out.append(a.animals[id])

	return out


func step_with(a, g: Dictionary, p: Vector3) -> void:
	var d: float = Vector2(p.x - g["pos"].x, p.z - g["pos"].z).length()
	a._step(g, 0.25, d, p, d, p)


func _init() -> void:
	# 1. Trust: three nights of gifts reach Tolerated; two in one night count once; forgetting; harm; the save.
	var t = TrustScript.new()
	var probe = make()
	t.cfg = probe.species_def("goblin")["ally"]
	t.game_seconds = func(): return now
	t.gift("0,0", "dave")
	t.gift("0,0", "dave")
	check(is_equal_approx(t.trust("0,0", "dave"), 1.0), "two gifts in one night count once (%.1f)" % t.trust("0,0", "dave"))
	now += DAY
	t.gift("0,0", "dave")
	now += DAY
	t.gift("0,0", "dave")
	check(t.step_of("0,0", "dave") == "tolerated", "three nights of gifts reach Tolerated (%s)" % t.step_of("0,0", "dave"))
	check(t.step_of("0,0", "other") == "stranger" and t.step_of("5,5", "dave") == "stranger", "trust belongs to one band and one character")
	now += 7.0 * DAY
	check(is_equal_approx(t.trust("0,0", "dave"), 2.0), "7 game days without a gift forget 1 (%.1f)" % t.trust("0,0", "dave"))
	t.store_dir = "user://test_goblin_trust"
	DirAccess.make_dir_recursive_absolute(t.store_dir)
	t.save()
	var t2 = TrustScript.new()
	t2.cfg = t.cfg
	t2.game_seconds = t.game_seconds
	t2.store_dir = t.store_dir
	t2.load_records()
	check(is_equal_approx(t2.trust("0,0", "dave"), 2.0), "trust survives a save and a load (%.1f)" % t2.trust("0,0", "dave"))
	t.harm("0,0", "dave")
	check(t.trust("0,0", "dave") == 0.0 and t.wary("0,0", "dave"), "a hit resets trust and makes the band wary")

	# 2. A Tolerated player 20 m away is watched; a stranger there is fled from.
	var a = make()
	var gs: Array = band(a)
	var g: Dictionary = gs[0]
	a.goblins.trust.records = {"0,0": {"dave": {"trust": 3.0, "last_gift_s": now, "wary_until_s": -1.0, "night": -1, "gift_day": -1}}}
	infos = [{"peer": 1, "pos": g["pos"] + Vector3(20.0, 0.0, 0.0)}]
	step_with(a, g, infos[0]["pos"])
	check(int(g["state"]) == a.ALERT, "a Tolerated player 20 m off is watched, not fled from (state %d)" % int(g["state"]))
	var g2: Dictionary = gs[1]
	infos = [{"peer": 2, "pos": g2["pos"] + Vector3(20.0, 0.0, 0.0)}]
	step_with(a, g2, infos[0]["pos"])
	check(int(g2["state"]) == a.FLEE, "a stranger 20 m off is fled from (state %d)" % int(g2["state"]))

	# 3. Known: that player's tools are left, their food is a gift, another player's tool is stolen.
	a.goblins.trust.records["0,0"]["dave"]["trust"] = 7.0
	infos = []
	loose = {1: [Vector3(10.0, GROUND, 5.0), "dave", "tool"], 2: [Vector3(20.0, GROUND, 5.0), "other", "tool"], 3: [Vector3(30.0, GROUND, 5.0), "dave", "food"]}
	g["state"] = a.GRAZE
	g["pos"] = Vector3(0.0, GROUND, 0.0)
	check(a.goblins._pick_steal(g, a.species_def("goblin")) and int(g["prize"]) == 2, "a Known player's tool is left, another's is taken (prize %d)" % int(g.get("prize", -1)))
	loose.erase(2)
	check(a.goblins._pick_steal(g, a.species_def("goblin")) and int(g["prize"]) == 3, "a Known player's food is taken as a gift (prize %d)" % int(g.get("prize", -1)))
	loose = {4: [Vector3(5.0, GROUND, 5.0), "goblin:0,0", "food"]}
	check(not a.goblins._pick_steal(g, a.species_def("goblin")), "a band's own return gift is never taken back")
	loose = {}

	# 4. A goblin that watched at a fire beside a Known player leaves one return gift a day.
	var fire: Vector3 = Vector3(60.0, GROUND, 0.0)
	a._fire_cache = [[fire, 10.0]]
	infos = [{"peer": 1, "pos": fire + Vector3(2.0, 0.0, 0.0)}]

	for k in 2:
		g["task"] = "watch"
		g["watching"] = true
		g["fire"] = fire
		g["fire_r"] = 10.0
		g["alert"] = 0.01
		g["state"] = a.ALERT
		g["pos"] = Vector3(48.0, GROUND, 0.0)
		step_with(a, g, Vector3.INF)
		check(gifts_left.size() == 1, "watch %d: one return gift a day (%d)" % [k + 1, gifts_left.size()])

	if not gifts_left.is_empty():
		check(str(gifts_left[0][3]) == "goblin:0,0" and (gifts_left[0][2] as Vector3).distance_to(Vector3(48.0, GROUND, 0.0)) < 0.5, "the gift lies at the watching spot, marked as the band's")

	# 5. Harm: a hit from that player resets trust and the band runs from them at twice spook_m.
	a._fire_cache = []
	a.damage(int(g2["id"]), 1.0, 1)
	check(a.goblins.trust.trust("0,0", "dave") == 0.0 and a.goblins.trust.wary("0,0", "dave"), "hurting one of the band resets trust and makes it wary")
	g["task"] = ""
	g["state"] = a.GRAZE
	g["pos"] = Vector3(0.0, GROUND, 0.0)
	infos = [{"peer": 1, "pos": Vector3(50.0, GROUND, 0.0)}]
	step_with(a, g, infos[0]["pos"])
	check(int(g["state"]) == a.FLEE, "a wary band runs from that player 50 m off (state %d)" % int(g["state"]))

	print("test_goblin_friendship: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
