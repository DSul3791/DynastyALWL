extends SceneTree

# Classic NPCs step A (Radar, 2026-10-21): schedules, markers and slots, dormant NPCs, the shared steering, the admin key check
# and what 60 NPCs cost.
#   godot --headless --path . --script res://src/worldgen/tools/test_npcs.gd

const NpcsScript := preload("res://src/stream/server_npcs.gd")
const AdminScript := preload("res://src/stream/server_admin.gd")
const Steering := preload("res://src/shared/steering.gd")

var failures: int = 0
var hour: float = 3.5
var players: Array = [Vector3(53326.0, 10.0, 68480.0)]
var wall: Array = []   # [x, z, radius] circles nothing may enter


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	npcs.hour_now = func(): return hour
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.blocked = func(x, z):
		for w in wall:
			if Vector2(x - w[0], z - w[1]).length() < w[2]:
				return true
		return false
	npcs.player_positions = func(): return players
	npcs.setup(dir)
	return npcs


func rep(name: String, n: int) -> Array:
	var out: Array = []

	for i in n:
		out.append(name)

	return out


func run(npcs, seconds: float, step: float = 0.1) -> void:
	var t: float = 0.0

	while t < seconds:
		npcs.tick(step)
		t += step


func _init() -> void:
	var dir: String = "user://test_npcs"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var npcs = make(dir)
	check(npcs.npcs.size() == 2 and npcs.markers.size() >= 6, "the data loads: two NPCs and the markers")
	check(npcs.roster().size() == 2, "the roster lists both")

	# A player arrives at night: the shopkeeper is in bed, the guard is at his post, both placed by the schedule.
	run(npcs, 0.2)
	var hob: Dictionary = npcs.npcs["hob"]
	var edda: Dictionary = npcs.npcs["edda"]
	check(hob["placed"] and int(hob["state"]) == npcs.SLEEP and str(hob["package"]) == "sleep", "3:30 the shopkeeper sleeps (%s)" % str(hob["package"]))
	check(edda["placed"] and int(edda["state"]) == npcs.STAND and str(edda["package"]) == "work", "3:30 the guard stands at his post (%s)" % str(edda["package"]))
	check(str(hob["claims"].get("bed", "")) != "", "the shopkeeper holds a bed")
	check(npcs.rows_near(players[0]).size() == 2, "both are sent to a player nearby")

	# Morning: Hob gets up and walks to his post (work at 7); it takes about distance / 1.4 seconds.
	hour = 7.5
	var bed: Vector3 = hob["pos"]
	var post_id: String = ""
	run(npcs, 0.5)
	post_id = str(hob["claims"].get("post", ""))
	check(post_id != "" and int(hob["state"]) == npcs.WALK, "7:30 he is walking to a post (%s)" % post_id)
	var dist: float = Vector2(npcs.markers[post_id]["x"] - bed.x, npcs.markers[post_id]["z"] - bed.z).length()
	run(npcs, dist / 1.4 + 3.0)
	check(int(hob["state"]) == npcs.STAND and Vector2(hob["pos"].x - npcs.markers[post_id]["x"], hob["pos"].z - npcs.markers[post_id]["z"]).length() < 0.6, "and he arrives and stands there")
	check(not npcs.markers[str(hob["claims"].get("post", ""))]["users"].is_empty() and str(hob["claims"].get("bed", "")) == "", "his bed is let go")

	# Two NPCs never share one chair: with three sitters and two chairs the third has none.
	var crowd = make(dir)

	for n in 3:
		crowd._add_npc({"id": "sitter%d" % n, "name": "S", "schedule": rep("sit", 24)}, Vector3.INF)

	hour = 12.5
	run(crowd, 0.5)
	var used: Dictionary = {}

	for id in ["sitter0", "sitter1", "sitter2"]:
		var c: String = str(crowd.npcs[id]["claims"].get("chair", ""))

		if c != "":
			check(not used.has(c), "chair %s is held by one NPC only" % c)
			used[c] = true

	check(used.size() <= 2, "only two chairs, so at most two sitters hold one (%d)" % used.size())

	# Far from everyone an NPC is dormant: not stepped at all, and placed from the schedule when a player comes.
	var far = make(dir)
	players = [Vector3(0.0, 10.0, 0.0)]
	hour = 12.5
	run(far, 2.0)
	check(far.ticks_run == 0 and far.rows_near(Vector3(0.0, 10.0, 0.0)).is_empty(), "no player within 200 m: nothing is simulated or sent")
	players = [Vector3(53326.0, 10.0, 68480.0)]
	run(far, 0.2)
	check(far.npcs["hob"]["placed"] and int(far.npcs["hob"]["state"]) == far.SIT, "a player arrives at 12:30 and Hob is already in his chair")

	# The shared steering walks around something in the way and still arrives.
	var ground: Callable = func(_x, _z): return 10.0
	var block: Callable = func(x, z): return Vector2(x - 5.0, z).length() < 2.0
	var at: Vector3 = Vector3(0.0, 10.0, 0.0)
	var goal: Vector3 = Vector3(10.0, 10.0, 0.0)
	var heading: float = 0.0
	var steps: int = 0
	var entered: bool = false

	while steps < 400:
		var r: Dictionary = Steering.step(at, goal, 1.4, 0.1, ground, block, 0.4, heading)

		if r["arrived"]:
			break

		at = r["pos"]
		heading = r["heading"]
		entered = entered or Vector2(at.x - 5.0, at.z).length() < 2.0
		steps += 1

	check(steps < 400 and not entered, "steering sidesteps a pond in the way and arrives (%d steps)" % steps)
	var steep: Callable = func(x, _z): return 10.0 + maxf(x - 3.0, 0.0) * 5.0
	var wall_r: Dictionary = Steering.step(Vector3(3.0, 10.0, 0.0), Vector3(10.0, 10.0, 0.0), 1.4, 0.1, steep, Callable(), 0.4, 0.0)
	check(not wall_r["moved"] or wall_r["heading"] != 0.0, "a cliff straight ahead is not walked up")

	# Admin keys: nobody without data/admin.json.
	var admin = AdminScript.new()
	admin.enforce = true
	admin.load_keys(["user://nope/admin.json"])
	check(AdminScript.new().is_admin("anything") or AdminScript.check_enabled(), "with the check off everybody is an admin")
	var ident = load("res://src/stream/identity_provider.gd").new()
	var acct: String = ident.authenticate(1, "key-one")
	check(acct == "local:key-one" and ident.store_key(acct) == "key-one" and ident.store_key("google:abc") == "" and ident.authenticate(1, "") == "", "the local identity maps a key to local:<key> and back")
	check(not admin.is_admin("anything") and not admin.is_admin("") and admin.count() == 0, "no admin file means no admins")
	var f: FileAccess = FileAccess.open(dir + "/admin.json", FileAccess.WRITE)
	f.store_string("{\"keys\": [\"key-one\"]}")
	f.close()
	admin.load_keys([dir + "/admin.json"])
	check(admin.is_admin("key-one") and admin.is_admin("local:key-one") and not admin.is_admin("key-two"), "only listed keys are admins, as raw keys or account ids")
	check(not FileAccess.get_file_as_string("res://data/admin.example.json").contains("\"keys\": []") , "the example file shows the shape")

	# Admin additions survive a restart; two NPCs still never share.
	var placed = make(dir)
	var marker_id: String = placed.add_marker("chair", 1.0, 2.0, 90.0)
	check(placed.place_npc("hob", 53340.0, 68490.0) and not placed.place_npc("nobody", 0.0, 0.0), "admin can move a known NPC")
	var again = make(dir)
	check(again.markers.has(marker_id) and again.npcs["hob"]["home"].x == 53340.0, "admin markers and homes are saved")

	# Cost: 60 NPCs, all near and walking.
	var big = make(dir)
	for n in 58:
		big._add_npc({"id": "n%d" % n, "name": "N", "schedule": rep("work", 12) + rep("sit", 12)}, Vector3(53320.0 + float(n % 10), 0.0, 68470.0 + float(n / 10)))

	hour = 11.5
	run(big, 1.0)
	hour = 12.5
	var t0: int = Time.get_ticks_usec()
	var ticks: int = 600

	for n in ticks:
		big.tick(0.1)

	var per: float = float(Time.get_ticks_usec() - t0) / float(ticks) / 1000.0
	print("npc cost: %d NPCs, %.3f ms per 10 Hz tick, %d steps taken" % [big.npcs.size(), per, big.ticks_run])
	check(per < 1.0, "60 NPCs cost under 1 ms a tick (%.3f)" % per)

	print("npc tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
