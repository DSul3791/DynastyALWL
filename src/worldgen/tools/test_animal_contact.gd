extends SceneTree

# No animal goes through a player (Dave 23 Nov 2026, first game on the real server: animals were "jumping right through us"; data/animals/contact.json,
# docs/design/ANIMAL_NETCODE.md). A charge stops against the player it reaches, also when the server runs slowly (long steps); any other step
# that would take an animal into a player is held at the player's side; a standing animal's row carries the send time (protocol 154).
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_contact.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")

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
	a.big_game.hurt_player = func(peer, amount, _lethal, _cause):
		hurt.append([peer, amount])
		return "hurt"
	return a


# A `sp` 20 m from a standing player charges them for 10 s of ticks `dt` s apart (each animal steps every fourth tick, at most 1 s at a time). Returns [hits, nearest it came (m), where it ended (m)].
func charge(sp: String, dt: float) -> Array:
	var players: Array = [Vector3(0.0, 10.0, 0.0)]
	var hurt: Array = []
	var a = _animals(players, hurt)
	var id: int = a.spawn(sp, 20.0, 0.0)
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
	check(AnimalContact.stop_toward(Vector3.ZERO, Vector3(-1.0, 0, 0), Vector3(-1.5, 0, 0), m).is_equal_approx(Vector3(-1.5, 0, 0)) and AnimalContact.stop_toward(Vector3.ZERO, Vector3(-1.0, 0, 0), Vector3(-0.5, 0, 0), m).is_equal_approx(Vector3(-1.0, 0, 0)), "one already inside moves off but not nearer")

	# A real charge (full ticks): it hits, and never comes inside the player, at 20 steps a second and with a server stepping only twice a second.
	for sp in ["elephant", "mammoth", "rhino", "buffalo", "moose", "bear", "boar", "deer"]:
		var c_m: float = AnimalContact.contact_m(sp)

		for dt in [0.05, 0.5]:
			var r: Array = charge(sp, dt)
			check(int(r[0]) >= 1 and float(r[1]) >= c_m - 0.01, "%s charging from 20 m (steps of %.2f s) hits and stops against the player: nearest %.2f m, contact %.2f m, ended %.2f m" % [sp, dt, float(r[1]), c_m, float(r[2])])

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
