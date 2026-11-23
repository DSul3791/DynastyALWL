extends SceneTree

# No animal goes through a player (Dave 23 Nov 2026, first game on the real server: animals were "jumping right through us"; data/animals/contact.json,
# docs/design/ANIMAL_NETCODE.md). A charge stops against the player it reaches, also when the server runs slowly (long steps); any other step
# that would take an animal into a player is held at the player's side; a standing animal's row carries the send time (protocol 154).
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_contact.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")
const MotionBuffer := preload("res://src/client/motion_buffer.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func _animals(players: Array, hurt: Array) -> Object:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return players
	a.player_stances = func(): return [0]
	a.wind = func(): return {"wind": 0.0, "wind_dir": 0.0}
	a.setup()
	a.traits = false

	for s in a.cfg["species"]:
		a.cfg["species"][s]["target_per_player"] = 0

	a.rng.seed = 7
	a.big_game.player_info = func(): return [{"peer": 1, "pos": players[0], "stance": 0, "hp": 1.0}]
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause, _from):
		hurt.append([peer, amount])
		return "hurt"
	return a


# A `sp` up to 20 m from a standing player (nearer for one that calms past calm_m or whose charge runs out before charge_m: a boar at 13.5 m,
# a deer at 7 m; Lane B 23 Nov 2026: a deer warned from 20 m rightly calmed and ran) charges them for 10 s of ticks `dt` s apart (each animal steps every fourth tick, at most 1 s at a time). Returns [hits, nearest it came (m), where it ended (m)].
func charge(sp: String, dt: float) -> Array:
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	var hurt: Array = []
	var a = _animals(players, hurt)
	var defend: Dictionary = a.species_def(sp).get("defend", {})
	var start_m: float = minf(20.0, minf(float(defend.get("calm_m", 32.0)) * 0.8, float(defend.get("charge_m", 24.0)) * 0.9))
	var id: int = a.spawn(sp, start_m, 0.0)
	var b: Dictionary = a.animals[id]
	b["temper"] = "defensive"
	b["protective"] = false
	a.big_game.warn(b, players[0], 0.1, true)
	var nearest: float = INF
	var t: float = 0.0

	while t < 10.0 and a.animals.has(id):
		a.tick(dt)
		t += dt
		nearest = minf(nearest, Vector2(b["pos"].x, b["pos"].z).length())

	return [hurt.size(), nearest, Vector2(b["pos"].x, b["pos"].z).length()]


func _init() -> void:
	# Every animal that fights reaches its hit distance before it touches the player, so a charge that comes to the player hits.
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	var too_near: Array = []

	for sp in cfg["species"]:
		var row: Dictionary = cfg["species"][sp]

		if row.has("defend") and AnimalContact.contact_m(sp) >= float(row["defend"].get("hit_m", 2.2)):
			too_near.append(sp)

	check(too_near.is_empty(), "every fighter's contact distance is inside its hit distance (%s)" % str(too_near))

	# stop_at: the first point of the stretch at the contact distance; the start when already that near; the end when it passes wide.
	var m: float = 2.0
	check(AnimalContact.stop_at(Vector3(0, 0, 0), Vector3(-10, 0, 0), Vector3(10, 0, 0), m).is_equal_approx(Vector3(-2, 0, 0)), "a charge straight through stops 2 m short")
	check(AnimalContact.stop_at(Vector3(0, 0, 0), Vector3(-1, 0, 0), Vector3(10, 0, 0), m).is_equal_approx(Vector3(-1, 0, 0)), "one already against the player stays where it was")
	check(AnimalContact.stop_at(Vector3(0, 0, 3), Vector3(-10, 0, 0), Vector3(10, 0, 0), m).is_equal_approx(Vector3(10, 0, 0)), "one passing 3 m wide runs on")
	check(AnimalContact.stop_at(Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(5, 0, 0), m).is_equal_approx(Vector3(5, 0, 0)) and AnimalContact.stop_at(Vector3(0, 0, 0), Vector3(-8, 0, 0), Vector3(-5, 0, 0), m).is_equal_approx(Vector3(-5, 0, 0)), "one going away, or stopping short of the circle, goes on")
	var side: Vector3 = AnimalContact.stop_at(Vector3(0, 0, 1), Vector3(-10, 0, 0), Vector3(10, 0, 0), m)
	check(absf(Vector2(side.x, side.z - 1.0).length() - m) < 0.001 and side.x < 0.0, "one passing 1 m wide stops on the circle, on the near side (%s)" % str(side))

	# The client's stop_toward (gate review of PR #1631): a charge carried on past the player is held on the near side, never flipped to the far
	# side; one the player walked into may move off, not nearer.
	var held: Vector3 = AnimalContact.stop_toward(Vector3.ZERO, Vector3(-2.0, 0, 0), Vector3(1.5, 0, 0), m)
	check(held.is_equal_approx(Vector3(-2.0, 0, 0)), "a carried charge going past the player stays on the near side (%s)" % str(held))
	check(AnimalContact.stop_toward(Vector3.ZERO, Vector3(-1.0, 0, 0), Vector3(-1.5, 0, 0), m).is_equal_approx(Vector3(-2.0, 0, 0)) and AnimalContact.stop_toward(Vector3.ZERO, Vector3(-1.0, 0, 0), Vector3(-0.5, 0, 0), m).is_equal_approx(Vector3(-2.0, 0, 0)), "one the player walked into steps out to the edge on its own side, never nearer")
	var round1: Vector3 = AnimalContact.stop_toward(Vector3.ZERO, Vector3(-1.9999, 0, 0), Vector3(4, 0, 0), m)
	var round2: Vector3 = AnimalContact.stop_toward(Vector3.ZERO, Vector3(-0.5, 0, 0), Vector3(3, 0, 0), m)
	check(round1.x < 0.0 and absf(Vector2(round1.x, round1.z).length() - m) < 0.01 and absf(round1.z) > 0.3, "one on the circle whose animal is already past goes round the player, not through (%s)" % str(round1))
	check(round2.x < 0.0 and Vector2(round2.x, round2.z).length() > 0.5 and absf(round2.z) > 0.1, "one the player walked into, its animal past: out and round, never across (%s)" % str(round2))

	# Robot run ClZm (23 Nov 2026): a bear held at the player's edge while the server's bear ran on, then a 42 m jump when let go. Now the
	# drawn body goes round the player and follows. The game's own loop (animal_view): stop_toward from the last spot (sm_p) with the
	# drawing's room as its reach, then MotionBuffer.smooth; at 30, 60 and 144 frames a second, the bear running at 12 m/s past the player
	# at 1 m and straight through them: never inside, never faster than smooth's catch-up allows, and with the server's bear at the end.
	for fps in [30.0, 60.0, 144.0]:
		for goal in [Vector3(40.0, 0, 30.0), Vector3(40.0, 0, 1.0), Vector3(40.0, 0, 0)]:
			var dt: float = 1.0 / fps
			var body: Dictionary = {}
			var real: Vector3 = Vector3(-2.5, 0, 0)
			var shown: Vector3 = real
			var nearest: float = INF
			var fastest: float = 0.0

			for frame in int(6.0 * fps):
				real = real.move_toward(goal, 12.0 * dt)      # the server's bear runs past the player and on
				var reach: float = 12.0 * dt * 1.05
				var spot: Vector3 = AnimalContact.stop_toward(Vector3.ZERO, body.get("sm_p", real), real, m, reach)
				var next: Vector3 = MotionBuffer.smooth(body, spot, 12.0, dt)
				fastest = maxf(fastest, next.distance_to(shown) / dt)
				shown = next
				nearest = minf(nearest, Vector2(shown.x, shown.z).length())

			var what: String = "%d fps, toward %s" % [int(fps), str(goal)]
			check(shown.distance_to(real) < 0.5, "%s: the drawn bear ends with the server's (%.2f m apart)" % [what, shown.distance_to(real)])
			check(nearest > m - 0.05, "%s: never inside the player (nearest %.2f m, circle %.1f)" % [what, nearest, m])
			check(fastest < 12.0 * 1.4, "%s: never a jump (fastest %.1f m/s for a 12 m/s bear)" % [what, fastest])

	# A charge carried on past the player (go_round false) is still held on its own side until its next row.
	check(AnimalContact.stop_toward(Vector3.ZERO, Vector3(-2.0, 0, 0), Vector3(2.5, 0, 0), m, INF, false).is_equal_approx(Vector3(-2.0, 0, 0)), "a charge carried past the player waits on its own side")

	# A real charge (full ticks): it hits, and never comes inside the player, at 20 steps a second and with a server stepping only twice a second.
	for sp in ["elephant", "mammoth", "rhino", "buffalo", "moose", "bear", "boar", "deer"]:
		var c_m: float = AnimalContact.contact_m(sp)

		for dt in [0.05, 0.5]:
			var r: Array = charge(sp, dt)
			check(int(r[0]) >= 1 and float(r[1]) >= c_m - 0.01, "%s charging (from up to 20 m, steps of %.2f s) hits and stops against the player: nearest %.2f m, contact %.2f m, ended %.2f m" % [sp, dt, float(r[1]), c_m, float(r[2])])

	# Any other step into a player is held at the player's side; a step away is left alone; the wolves' player infos work the same.
	var a = _animals([Vector3.ZERO], [])
	var deer: Dictionary = {"sp": "deer", "pos": Vector3(0.5, 0.0, 0.0), "state": 0}
	var dm: float = AnimalContact.contact_m("deer")
	check(a.keep_off_players(deer, Vector3(3.0, 0.0, 0.0), [Vector3.ZERO]) and absf(Vector2(deer["pos"].x, deer["pos"].z).length() - dm) < 0.001, "a deer stepping into a player is put on the contact circle (%s)" % str(deer["pos"]))
	var out: Dictionary = {"sp": "deer", "pos": Vector3(0.6, 0.0, 0.0), "state": 0}
	check(not a.keep_off_players(out, Vector3(0.3, 0.0, 0.0), [Vector3.ZERO]) and out["pos"].is_equal_approx(Vector3(0.6, 0.0, 0.0)), "one already too near walking out is left alone")
	var wolf: Dictionary = {"sp": "wolf", "pos": Vector3(0.0, 0.0, 0.2), "state": 7}
	var wm: float = AnimalContact.contact_m("wolf")
	check(a.keep_off_players(wolf, Vector3(0.0, 0.0, wm), [{"peer": 1, "pos": Vector3.ZERO}]) and wolf["pos"].is_equal_approx(Vector3(0.0, 0.0, wm)), "a wolf rushing in from the contact circle is held there, standing (%s)" % str(wolf["pos"]))
	var bird: Dictionary = {"sp": "crow", "pos": Vector3(0.1, 0.0, 0.0), "state": 0, "fly": true}
	check(not a.keep_off_players(bird, Vector3(3.0, 0.0, 0.0), [Vector3.ZERO]), "a bird in the air is not held")

	# A player walking into a standing animal: it steps out of them at up to half its flee speed, away from them, and stops at the contact circle
	# (robot play-testers 23 Nov 2026: a dog 0.02 m from a player, a deer 0.22 m, a horse 0.15 m). A bird in the air, a camp's horse stay.
	var mw = _animals([Vector3.ZERO], [])
	var calf: Dictionary = {"sp": "deer", "pos": Vector3(0.2, 10.0, 0.0), "state": 0}
	var walked: bool = mw.make_way(calf, Vector3(0.0, 10.0, 0.0), 0.1)
	var first_step: float = calf["pos"].x - 0.2

	for i in 40:
		mw.make_way(calf, Vector3(0.0, 10.0, 0.0), 0.1)

	var deer_pace: float = maxf(float(mw.species_def("deer").get("walk_mps", 1.5)), 0.5 * float(mw.species_def("deer").get("flee_mps", 0.0)))
	check(walked and first_step > 0.0 and first_step <= deer_pace * 0.1 + 0.001 and absf(Vector2(calf["pos"].x, calf["pos"].z).length() - dm) < 0.01, "a deer walked into steps away, at most half its flee speed, and stands at the contact circle (first step %.2f m, ends %.2f m)" % [first_step, Vector2(calf["pos"].x, calf["pos"].z).length()])
	# A player jogging into a dog at 4 m/s (robots 23 Nov 2026: a dog stayed 0.1 to 0.3 m inside a robot chasing it for 0.66 s): its 5 m/s
	# (half its flee speed) keeps it out, ending each step on the contact circle. At a full 9 m/s run a player still gains on it for a moment.
	var dog_m: float = AnimalContact.contact_m("dog")
	var dog: Dictionary = {"sp": "dog", "pos": Vector3(dog_m, 10.0, 0.0), "state": 0}   # standing at the contact circle, the runner closing at 4 m/s
	var runner: Vector3 = Vector3(0.0, 10.0, 0.0)
	var dog_worst: float = INF

	for i in 10:
		runner.x += 0.4
		mw.make_way(dog, runner, 0.1)
		dog_worst = minf(dog_worst, Vector2(dog["pos"].x - runner.x, dog["pos"].z - runner.z).length())

	check(dog_worst >= dog_m - 0.01, "a dog a player jogs into at 4 m/s keeps out of them (nearest %.2f m, contact %.2f m)" % [dog_worst, dog_m])
	var resting_wolf: Dictionary = {"sp": "wolf", "pos": Vector3(0.2, 10.0, 0.0), "state": 0}
	mw.wolves._make_way(resting_wolf, [{"peer": 1, "pos": Vector3(0.0, 10.0, 0.0)}], 0.1)
	check(resting_wolf["pos"].x > 0.2, "a resting pack wolf a player walked into steps out too (%s)" % str(resting_wolf["pos"]))
	var warned: Dictionary = {"sp": "deer", "pos": Vector3(0.2, 10.0, 0.0), "state": 10}
	check(mw.make_way(warned, Vector3(0.0, 10.0, 0.0), 0.1), "a deer warning from inside a player steps out too")
	check(not mw.make_way({"sp": "crow", "pos": Vector3(0.1, 10.0, 0.0), "state": 0, "fly": true}, Vector3(0.0, 10.0, 0.0), 0.1) and not mw.make_way({"sp": "horse", "pos": Vector3(0.1, 10.0, 0.0), "state": 0, "camp": 1}, Vector3(0.0, 10.0, 0.0), 0.1), "a bird in the air and a camp's tied horse stay")
	var tp: Array = [Vector3(0.0, 10.0, 0.0)]
	var tw = _animals(tp, [])
	var sid: int = tw.spawn("deer", 0.3, 0.0)
	tw.animals[sid]["state"] = 0

	for i in 40:
		tw.tick(0.05)

	check(not tw.animals.has(sid) or Vector2(tw.animals[sid]["pos"].x, tw.animals[sid]["pos"].z).length() >= dm - 0.01, "in the server's own ticks, a deer spawned inside a player is out of them within 2 s (%.2f m)" % (Vector2(tw.animals[sid]["pos"].x, tw.animals[sid]["pos"].z).length() if tw.animals.has(sid) else -1.0))

	# Protocol 154: a standing animal's row carries the send time, every send; a moving one keeps the time of its step.
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	var s = _animals(players, [])
	var rid: int = s.spawn("deer", 10.0, 0.0)
	var r_b: Dictionary = s.animals[rid]
	r_b["moving"] = false
	var first_ms: int = int(_row_of(s.rows_near(players[0]), rid)[5])
	OS.delay_msec(20)
	var second_ms: int = int(_row_of(s.rows_near(players[0]), rid)[5])
	check(second_ms >= first_ms + 15, "a standing animal's row is stamped with each send (%d then %d)" % [first_ms, second_ms])
	r_b["pos"] = r_b["pos"] + Vector3(0.5, 0.0, 0.0)
	r_b["moved_ms"] = second_ms + 1
	r_b["moving"] = true
	OS.delay_msec(20)
	check(int(_row_of(s.rows_near(players[0]), rid)[5]) == second_ms + 1, "a moving one carries the time of its step")
	OS.delay_msec(20)
	check(int(_row_of(s.rows_near(players[0]), rid)[5]) == second_ms + 1, "and still that time while it is between steps")

	print("test_animal_contact: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)


func _row_of(rows: Array, id: int) -> Array:
	for row in rows:
		if int(row[0]) == id:
			return row

	return [id, 0, Vector3.ZERO, 0.0, 0, -1]
