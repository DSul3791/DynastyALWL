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
			check(fastest < 12.0 * 1.5, "%s: never a jump (fastest %.1f m/s for a 12 m/s bear; smooth catches up at most 1.3 times plus its slack)" % [what, fastest])

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
	# Two players side by side (robot bear hunt 23 Nov 2026, dev 74c4a4e8: hunters 1.4 m apart, a bear charging through the nearer one was
	# put out of it onto its far side, inside the other, 0.22 m from their middle): out of one is never into the other; it stays where it was.
	var bm: float = AnimalContact.contact_m("bear")
	var pair: Array = [Vector3(2.75, 0.0, 0.0), Vector3(1.36, 0.0, 0.0)]
	var bear: Dictionary = {"sp": "bear", "pos": Vector3(2.6, 0.0, 0.0), "state": 11}
	a.keep_off_players(bear, Vector3.ZERO, pair)
	var bear_near: float = minf(Vector2(bear["pos"].x - pair[0].x, bear["pos"].z).length(), Vector2(bear["pos"].x - pair[1].x, bear["pos"].z).length())
	check(bear_near >= bm - 0.02, "a bear stepping between two players is inside neither (nearest %.2f m, contact %.2f m, at %s)" % [bear_near, bm, str(bear["pos"])])
	var crossing: Dictionary = {"sp": "bear", "pos": Vector3(0.4, 0.0, 0.1), "state": 11}   # a 2.9 m step from x -2.5 across a lone player's middle
	a.keep_off_players(crossing, Vector3(-2.5, 0.0, 0.0), [Vector3.ZERO])
	check(crossing["pos"].x < 0.0 and Vector2(crossing["pos"].x, crossing["pos"].z).length() >= bm - 0.01, "a bear stepping across a lone player's middle stops on the side it came from (%s)" % str(crossing["pos"]))
	var under: Dictionary = {"sp": "bear", "pos": Vector3(0.2, 0.0, 0.0), "state": 0}   # a short step under a player standing 5 m up (a ledge, a floor)
	a.keep_off_players(under, Vector3(-0.3, 0.0, 0.0), [Vector3(0.0, 5.0, 0.0)])
	check(under["pos"].is_equal_approx(Vector3(0.2, 0.0, 0.0)), "a bear walking under a player 5 m up goes on its way (%s)" % str(under["pos"]))
	var squeezed: Dictionary = {"sp": "deer", "pos": Vector3(0.2, 10.0, 0.0), "state": 0}
	var beside: Array = [Vector3(0.0, 10.0, 0.0), Vector3(dm + 0.3, 10.0, 0.0)]
	check(not a.make_way(squeezed, beside[0], 0.1, beside) and squeezed["pos"].is_equal_approx(Vector3(0.2, 10.0, 0.0)), "a deer a player walked into does not step out into a second player beside them")

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

	# The walker stops at a body (robots 23 Nov 2026, AUDIT where: a robot walking through a standing elephant shoved its drawn body 5 m from
	# where the server had it). Straight in: they stand at its contact distance; across it: they slide round; one the animal came onto goes
	# no nearer and may step away; one 3 m above (a bridge) passes.
	var em: float = AnimalContact.contact_m("elephant")
	var el: Array = [[Vector3.ZERO, em]]
	var walk_from: Vector3 = Vector3(em + 0.5, 0.0, 0.0)
	var walk_to: Vector3 = Vector3(em - 0.6, 0.0, 0.0)
	var walk_end: Vector3 = walk_to + AnimalContact.walker_stop(walk_from, walk_to, el)
	check(absf(Vector2(walk_end.x, walk_end.z).length() - em) < 0.001, "walking straight into an elephant they stand against it, %.2f m from its middle (%.2f)" % [em, Vector2(walk_end.x, walk_end.z).length()])
	var cross_from: Vector3 = Vector3(em, 0.0, -0.3)
	var cross_to: Vector3 = Vector3(em - 0.2, 0.0, 0.3)
	var cross_end: Vector3 = cross_to + AnimalContact.walker_stop(cross_from, cross_to, el)
	check(absf(Vector2(cross_end.x, cross_end.z).length() - em) < 0.001 and cross_end.z > 0.2, "walking across its side they slide round it (%.2f, %.2f)" % [cross_end.x, cross_end.z])
	var under_from: Vector3 = Vector3(1.0, 0.0, 0.0)
	check(AnimalContact.walker_stop(under_from, Vector3(0.6, 0.0, 0.0), el).is_equal_approx(Vector3(0.4, 0.0, 0.0)) and AnimalContact.walker_stop(under_from, Vector3(1.4, 0.0, 0.0), el) == Vector3.ZERO, "one the animal came onto goes no nearer, and steps away freely")
	check(AnimalContact.walker_stop(walk_from, walk_to, [[Vector3(0.0, 3.0, 0.0), em]]) == Vector3.ZERO, "a body 3 m above or below is passed")
	# A hitch frame long enough to cross the body stops where it would enter, not on its far side.
	var hitch_end: Vector3 = Vector3(-em - 1.0, 0.0, 0.1) + AnimalContact.walker_stop(Vector3(em + 1.0, 0.0, 0.1), Vector3(-em - 1.0, 0.0, 0.1), el)
	check(hitch_end.x > 0.0 and absf(Vector2(hitch_end.x, hitch_end.z).length() - em) < 0.01, "a hitch-frame step clean through the body stops on the near side (%.2f, %.2f)" % [hitch_end.x, hitch_end.z])
	var over_end: Vector3 = Vector3(-1.0, 0.0, 0.1) + AnimalContact.walker_stop(Vector3(em + 0.3, 0.0, 0.1), Vector3(-1.0, 0.0, 0.1), el)
	check(over_end.x > 0.0 and absf(Vector2(over_end.x, over_end.z).length() - em) < 0.01, "a hitch step over its middle into its far half also stops on the near side (%.2f, %.2f)" % [over_end.x, over_end.z])
	# Ringed by three wolves touching them: a step out between two is never shut in (only the body the move enters first stops it).
	var ring_m: float = AnimalContact.contact_m("wolf")
	var ring: Array = []

	for k in 3:
		ring.append([Vector3(cos(TAU * k / 3.0) * ring_m, 0.0, sin(TAU * k / 3.0) * ring_m), ring_m])

	var out_at: Vector3 = Vector3.ZERO
	var out_dir: Vector3 = Vector3(cos(PI / 3.0), 0.0, sin(PI / 3.0))   # between the first two

	for f in 60:
		var step_to: Vector3 = out_at + out_dir * 0.05
		out_at = step_to + AnimalContact.walker_stop(out_at, step_to, ring)

	check(Vector2(out_at.x, out_at.z).length() > ring_m * 1.5, "ringed by three wolves, a walker steps out between two (%.2f m out)" % Vector2(out_at.x, out_at.z).length())
	# Never shut in: held short at bodies for 2.5 s on end the walker goes through; a slide or a break of over 0.4 s starts the count again.
	var hold: Array = [-1, -100000]
	hold = AnimalContact.walker_held(hold, 1000, true, 2500, 400)
	check(int(hold[0]) == 1000 and not bool(hold[2]), "held at a body: the count starts")
	hold = AnimalContact.walker_held(hold, 3400, true, 2500, 400)
	check(not bool(hold[2]), "2.4 s held: still stopped")
	hold = AnimalContact.walker_held(hold, 3600, true, 2500, 400)
	check(bool(hold[2]), "2.6 s held on end: let through")
	hold = AnimalContact.walker_held(hold, 3700, false, 2500, 400)
	hold = AnimalContact.walker_held(hold, 4200, false, 2500, 400)
	check(int(hold[0]) == -1, "free for over 0.4 s: the next hold counts from its start")
	# The walker pressing into a standing elephant on this screen never shoves its drawn body: the walker stops 0.1 m inside its contact
	# distance, the drawing keeps it off only 0.12 m inside (animal_view, the review of #1774).
	var drawn_el: Vector3 = Vector3(3.0, 0.0, 0.0)
	var presser: Vector3 = Vector3.ZERO

	for f in 120:
		var press_to: Vector3 = presser + Vector3(0.08, 0.0, 0.0)
		presser = press_to + AnimalContact.walker_stop(presser, press_to, [[drawn_el, em - 0.1]])
		drawn_el = AnimalContact.stop_toward(presser, drawn_el, Vector3(3.0, 0.0, 0.0), em - 0.12)

	check(drawn_el.distance_to(Vector3(3.0, 0.0, 0.0)) < 0.01 and absf(presser.distance_to(drawn_el) - (em - 0.1)) < 0.01, "a walker pressing into a standing elephant stops at it and its drawn body stays put (%.2f m moved)" % drawn_el.distance_to(Vector3(3.0, 0.0, 0.0)))
	# Stopped just inside its contact distance, a standing animal the walker presses into makes way on the server (make_way), so the walker
	# is never held by one standing in their way, without the let-through.
	var pass_players: Array = [Vector3(0.0, 10.0, 0.0)]
	var ps = _animals(pass_players, [])
	ps.cfg["senses"] = {}

	for key in ["spook_m", "alert_m", "threat_m"]:
		ps.cfg["species"]["cow"][key] = 0.0   # it stands, unafraid: only make_way moves it

	ps.cfg["species"]["cow"].erase("defend")
	var cow: int = ps.spawn("cow", 3.0, 0.0)
	ps.animals[cow]["pos"] = Vector3(3.0, 10.0, 0.0)
	var cm: float = AnimalContact.contact_m("cow") - 0.1   # animal_view WALK_INTO_M
	var walker: Vector3 = Vector3(0.0, 10.0, 0.0)
	var passed_s: float = INF

	for f in 900:
		var goal: Vector3 = walker + Vector3(3.0 / 60.0, 0.0, 0.0)
		walker = goal + AnimalContact.walker_stop(walker, goal, [[ps.animals[cow]["pos"], cm]] if ps.animals.has(cow) else [])
		pass_players[0] = walker
		ps.tick(1.0 / 60.0)

		if walker.x > 6.0 and passed_s == INF:
			passed_s = float(f) / 60.0

	check(passed_s < 14.0, "a walker pressing into a standing cow in their way is not held: it makes way, 3 m on in %.1f s" % passed_s)
	# A blow reaches the body, not its middle: an elephant held off at its contact distance is within a knife's 2.5 m and a punch's 1.8 m.
	var reach_s = _animals([Vector3(0.0, 10.0, 0.0)], [])
	var eid: int = reach_s.spawn("elephant", em, 0.0)
	reach_s.animals[eid]["pos"] = Vector3(em, 10.0, 0.0)
	check(reach_s.target_along(Vector3(0.0, 11.6, 0.0), Vector3.RIGHT, 1.8) == eid and reach_s.target_along(Vector3(0.0, 11.6, 0.0), Vector3.RIGHT, em - AnimalContact.body_m("elephant") - 0.1) == 0, "an elephant at its contact distance is in a punch's reach (to its body), not in one short of its body")

	print("test_animal_contact: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)


func _row_of(rows: Array, id: int) -> Array:
	for row in rows:
		if int(row[0]) == id:
			return row

	return [id, 0, Vector3.ZERO, 0.0, 0, -1]
