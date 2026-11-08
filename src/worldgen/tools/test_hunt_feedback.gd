extends SceneTree

# Hunt feedback, the server half (docs/design/hunt_feedback_server.md; MikeW's HUNT_FEEDBACK.md requests 1 and 2): a deer's row has no health
# until it is hit, then ends in its health share; a dog foe stays field 6 with the health after it; an arrow through the head line, the rump,
# low through the legs and through the middle gives head, hip, leg and chest; a jab at the chest gives chest; the hit goes to a player 50 m off
# and not to one 70 m off, also when it kills.
#   godot --headless --path . --script res://src/worldgen/tools/test_hunt_feedback.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

const GROUND := 10.0

var failures: int = 0
var players: Array = []
var sent: Array = []


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
	a.big_game.player_info = func(): return players
	a.send_hit = func(peer, id, zone, at): sent.append([peer, id, zone, at])
	return a


func row_of(a, id: int) -> Array:
	var rows: Array = a.rows_near(a.animals[id]["pos"]).filter(func(r): return int(r[0]) == id)
	return rows[0] if rows.size() == 1 else []


# A still deer at the origin facing +x.
func deer_at(a, z: float = 0.0) -> int:
	var id: int = a.spawn("deer", 0.0, z)
	a.animals[id]["heading"] = 0.0
	a.animals[id]["pos"] = Vector3(0.0, GROUND, z)
	return id


func zone_of(a, from: Vector3, to: Vector3) -> String:
	var found: Dictionary = a.target_on_segment(from, to, 0.6, 0.5)
	return AnimalsScript.HIT_ZONES[int(found.get("zone", 0))] if not found.is_empty() else "miss"


func _init() -> void:
	players = [{"peer": 1, "pos": Vector3(50.0, GROUND, 0.0), "stance": 0, "hp": 1.0, "meat": false, "spear": false, "torch": false},
		{"peer": 2, "pos": Vector3(70.0, GROUND, 0.0), "stance": 0, "hp": 1.0, "meat": false, "spear": false, "torch": false}]

	# 1. No health on a healthy deer's row; half its health gone, the row ends in 0.5.
	var a = make()
	var id: int = deer_at(a)
	check(row_of(a, id).size() == 5, "a healthy deer's row has five fields (%d)" % row_of(a, id).size())
	var hp: float = float(a.animals[id]["hp"])
	a.damage(id, hp * 0.5, 1, "arrow")
	var row: Array = row_of(a, id)
	check(row.size() == 6 and typeof(row[5]) == TYPE_FLOAT and is_equal_approx(float(row[5]), 0.5), "hurt to half, its row ends in 0.5 (%s)" % str(row.slice(5)))

	# 2. A dog foe and health together: the dog stays field 6 (a Vector3), the health is last (a float).
	var keep: Array = players
	players = []   # no player near to draw the bear off the dog
	var b = make()
	var bear: Dictionary = b.animals[b.spawn("bear", 0.0, 0.0)]
	var dog: int = b.spawn("dog", 25.0, 0.0)
	b.animals[dog]["companion_id"] = "c%d" % dog
	b._dogs = b._dog_presences()
	b._step(bear, 0.25, INF, Vector3.INF, INF, Vector3.INF)
	bear["hp_max"] = float(bear["hp"])
	bear["hp"] = float(bear["hp"]) * 0.3
	var brow: Array = row_of(b, int(bear["id"]))
	players = keep
	check(int(bear["state"]) == 10 and brow.size() == 7 and typeof(brow[5]) == TYPE_VECTOR3 and is_equal_approx(float(brow[6]), 0.3), "a hurt bear warning at a dog: dog at field 6, health 0.3 last (%s)" % str(brow.slice(4)))

	# 3. Zones from the arrow's path, the deer facing +x.
	var c = make()
	deer_at(c)
	check(zone_of(c, Vector3(0.5, GROUND + 0.6, -5.0), Vector3(0.5, GROUND + 0.6, 5.0)) == "head", "an arrow across the front, high, is a head hit (%s)" % zone_of(c, Vector3(0.5, GROUND + 0.6, -5.0), Vector3(0.5, GROUND + 0.6, 5.0)))
	check(zone_of(c, Vector3(-0.45, GROUND + 0.5, -5.0), Vector3(-0.45, GROUND + 0.5, 5.0)) == "hip", "across the rump, a hip hit (%s)" % zone_of(c, Vector3(-0.45, GROUND + 0.5, -5.0), Vector3(-0.45, GROUND + 0.5, 5.0)))
	check(zone_of(c, Vector3(0.0, GROUND + 0.1, -5.0), Vector3(0.0, GROUND + 0.1, 5.0)) == "leg", "low through the legs, a leg hit (%s)" % zone_of(c, Vector3(0.0, GROUND + 0.1, -5.0), Vector3(0.0, GROUND + 0.1, 5.0)))
	check(zone_of(c, Vector3(0.0, GROUND + 0.5, -5.0), Vector3(0.0, GROUND + 0.5, 5.0)) == "chest", "through the middle, a chest hit (%s)" % zone_of(c, Vector3(0.0, GROUND + 0.5, -5.0), Vector3(0.0, GROUND + 0.5, 5.0)))

	# 4. A jab from 2 m behind along +x, at chest height: chest.
	var jab_id: int = c.target_along(Vector3(-2.0, GROUND + 0.5, 0.0), Vector3(1.0, 0.0, 0.0), 2.5)
	var jab_at: Vector3 = c.jab_point(jab_id, Vector3(-2.0, GROUND + 0.5, 0.0), Vector3(1.0, 0.0, 0.0), 2.5)
	check(jab_id != 0 and AnimalsScript.HIT_ZONES[c.hit_zone(jab_id, jab_at)] == "chest", "a jab at chest height is a chest hit (%s)" % (AnimalsScript.HIT_ZONES[c.hit_zone(jab_id, jab_at)] if jab_id != 0 else "miss"))

	# 5. The hit goes to the player 50 m off and not to the one 70 m off; also when it kills.
	var d = make()
	var did: int = deer_at(d)
	sent = []
	var found: Dictionary = d.target_on_segment(Vector3(0.0, GROUND + 0.5, -5.0), Vector3(0.0, GROUND + 0.5, 5.0), 0.6, 0.5)
	d.damage(did, 1.0, 1, "arrow")
	d.report_hit(did, int(found["zone"]), found["point"])
	check(sent.size() == 1 and int(sent[0][0]) == 1 and int(sent[0][1]) == did and int(sent[0][2]) == 2, "the hit goes to the player 50 m off only, with the animal and zone (%s)" % str(sent))
	sent = []
	d.damage(did, 1000.0, 1, "arrow")
	d.report_hit(did, int(found["zone"]), found["point"])
	check(not d.animals.has(did) and sent.size() == 1, "and when it kills (%d sent)" % sent.size())
	players = []

	print("test_hunt_feedback: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
