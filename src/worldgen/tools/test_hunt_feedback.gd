extends SceneTree

# Hunt feedback, the server half (docs/design/hunt_feedback_server.md; MikeW's HUNT_FEEDBACK.md requests 1 and 2): a deer's row has no health
# until it is hit, then ends in its health share; a dog foe is field 7 (after the server ms, protocol 147) with the health after it; an arrow through the head line, the rump,
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
	check(row_of(a, id).size() == 6 and typeof(row_of(a, id)[5]) == TYPE_INT, "a healthy deer's row has six fields, the last its server ms (protocol 147) (%d)" % row_of(a, id).size())
	var hp: float = float(a.animals[id]["hp"])
	a.damage(id, hp * 0.5, 1, "arrow")
	var row: Array = row_of(a, id)
	check(row.size() == 7 and typeof(row[6]) == TYPE_FLOAT and is_equal_approx(float(row[6]), 0.5), "hurt to half, its row ends in 0.5 (%s)" % str(row.slice(5)))

	# 2. A dog foe and health together: the dog is field 7 (a Vector3), the health is last (a float).
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
	check(int(bear["state"]) == 10 and brow.size() == 8 and typeof(brow[6]) == TYPE_VECTOR3 and is_equal_approx(float(brow[7]), 0.3), "a hurt bear warning at a dog: dog at field 7, health 0.3 last (%s)" % str(brow.slice(4)))

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

	# 6. Fair hits (protocol 155, Dave 23 Nov 2026: "battle was almost impossible"): a blow is judged where the player's screen showed the
	# animal, up to rewind_max_ms back. A deer ran from x 0 to 2 (300 ms ago) and on to 4 (100 ms ago).
	var e = make()
	var eid: int = deer_at(e)
	var ed: Dictionary = e.animals[eid]
	var now: int = Time.get_ticks_msec()
	ed["pos"] = Vector3(2.0, GROUND, 0.0)
	ed["moved_ms"] = now - 300
	e.note_past(ed, Vector3(0.0, GROUND, 0.0))
	ed["pos"] = Vector3(4.0, GROUND, 0.0)
	ed["moved_ms"] = now - 100
	e.note_past(ed, Vector3(2.0, GROUND, 0.0))
	check(e.pos_at(ed, now - 300).is_equal_approx(Vector3(2.0, GROUND, 0.0)) and e.pos_at(ed, now - 200).is_equal_approx(Vector3(3.0, GROUND, 0.0)) and e.pos_at(ed, now).is_equal_approx(Vector3(4.0, GROUND, 0.0)) and e.pos_at(ed, -1).is_equal_approx(Vector3(4.0, GROUND, 0.0)), "where it was: x 2 at 300 ms ago, 3 at 200, 4 now (%s, %s)" % [str(e.pos_at(ed, now - 300)), str(e.pos_at(ed, now - 200))])
	var eye: Vector3 = Vector3(2.0, GROUND + 0.5, -2.0)
	check(e.target_along(eye, Vector3(0.0, 0.0, 1.0), 2.5) == 0, "a jab at where it was 300 ms ago, judged now, misses (it has run on)")
	check(e.target_along(eye, Vector3(0.0, 0.0, 1.0), 2.5, now - 300, now - 300) == eid, "judged at the moment the player saw it, it hits")
	check(absf(e.jab_point(eid, eye, Vector3(0.0, 0.0, 1.0), 2.5, 0.5, now - 300, now - 300).z) < 0.01, "and lands where the player saw it")
	var long_ago: int = maxi(now - 5000, 1)   # a headless test starts a second or two after the clock does: a positive time, still too old
	check(e.judged_ms(ed, long_ago, long_ago) >= now - int(e.cfg.get("rewind_max_ms", 500)) - 1 and e.judged_ms(ed, 0, 0) == -1, "never judged more than rewind_max_ms back; a client that sends none is judged now")
	check(e.moved_since(eid, now - 300, now - 300).is_equal_approx(Vector3(2.0, 0.0, 0.0)), "it has gone 2 m since, so the struck spot is moved onto the body as it is now")
	# One that stood 10 s and then stepped: until the step it was where it stood.
	var st: Dictionary = e.animals[deer_at(e, 20.0)]
	st["moved_ms"] = now - 10000
	e.note_past(st, Vector3(0.0, GROUND, 19.0))
	st["pos"] = Vector3(1.0, GROUND, 20.0)
	st["moved_ms"] = now
	e.note_past(st, Vector3(0.0, GROUND, 20.0), 100)   # a 0.1 s step
	check(e.pos_at(st, now - 200).is_equal_approx(Vector3(0.0, GROUND, 20.0)), "an animal that stood, then stepped, was where it stood 200 ms ago (%s)" % str(e.pos_at(st, now - 200)))
	# An arrow's step (target_on_segment) is judged the same way: across x 2, it misses the deer now at x 4, and hits where the archer saw it
	# 300 ms ago; the struck point is moved onto the body as it is now.
	var across_from: Vector3 = Vector3(2.0, GROUND + 0.5, -2.0)
	var across_to: Vector3 = Vector3(2.0, GROUND + 0.5, 2.0)
	check(e.target_on_segment(across_from, across_to, 0.6, 0.5).is_empty(), "an arrow across where it was, judged now, misses")
	var shot: Dictionary = e.target_on_segment(across_from, across_to, 0.6, 0.5, now - 300, now - 300)
	check(int(shot.get("id", 0)) == eid and absf((shot.get("point", Vector3.ZERO) as Vector3).x - 4.0) < 0.01 and (shot.get("at", Vector3.ZERO) as Vector3).is_equal_approx(ed["pos"]), "judged where the archer saw it, it hits, on the body as it is now (%s)" % str(shot))
	ed["state"] = 10
	check(e.judged_ms(ed, now - 400, now - 50) >= now - 51, "a warning or charging animal is judged at the present the player's screen draws it at")
	ed["state"] = 0
	check(e.judged_ms(ed, now - 400, now - 50) >= now - 51, "since protocol 168 a grazing or walking animal is judged at the present too (every animal on the ground is drawn there)")
	ed["state"] = 15
	check(e.judged_ms(ed, now - 400, now - 50) <= now - 399, "a bird in the air (drawn a delay behind) is judged at the moment drawn")

	# 7. The plan (protocol 168): a moving animal's row carries where it is walking to (a Vector2 after the six fixed fields, before the
	# health share); a standing one's has none, and an old walk goal (over PLAN_FRESH_MS) is not sent.
	var f = make()
	var fid: int = deer_at(f)
	var fd: Dictionary = f.animals[fid]
	fd["moving"] = true
	f.plan(fd, Vector3(10.0, GROUND, 3.0))
	var prow: Array = row_of(f, fid)
	check(prow.size() == 7 and prow[6] is Vector2 and (prow[6] as Vector2).is_equal_approx(Vector2(10.0, 3.0)), "a walking deer's row ends in its plan (%s)" % str(prow.slice(5)))
	fd["hp_max"] = float(fd["hp"])
	fd["hp"] = float(fd["hp"]) * 0.5
	prow = row_of(f, fid)
	check(prow.size() == 8 and prow[6] is Vector2 and prow[7] is float, "hurt, its health share is still the last field, after the plan (%s)" % str(prow.slice(5)))
	fd["plan_ms"] = Time.get_ticks_msec() - AnimalsScript.PLAN_FRESH_MS - 100
	check(not row_of(f, fid).any(func(v): return v is Vector2), "an old walk goal is not sent")
	fd["plan_ms"] = Time.get_ticks_msec()
	fd["moving"] = false
	check(not row_of(f, fid).any(func(v): return v is Vector2), "a standing animal's row has no plan")

	print("test_hunt_feedback: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
