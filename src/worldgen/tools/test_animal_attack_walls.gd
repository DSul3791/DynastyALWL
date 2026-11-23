extends SceneTree

# No animal attack goes through a wall (coordinator, 23 Nov 2026: wolves bit through walls; every other attack checked too). The real
# server_items and server_animals wired as the server scene wires them (terrain_server.gd: the big game's hurt_player with its 10-health
# floor, the walls hook on structure_blocks_step), a 72 m log wall across the way:
#   1. every big game charge (bear, boar, moose, buffalo, the big cats, hyena, rhino, elephant, dog) lands in the open, and never on a
#      player standing hard behind the wall; the animal never goes through it (running round its end is allowed);
#   2. a hunter's chase (a puma at a runner) the same;
#   3. a player who pins an animal against the wall does not push it out through the other side (make_way), nor does keeping a step
#      off them (keep_off_players);
#   4. a charge meeting a wall turns along it its nose and WALL_LOOK_S of running short of it, so the client, which draws a charge carried on
#      past its newest point, never draws it inside the wall; it gets round one short wall piece and hits (no shield); one at a player standing
#      with their back to the wall still comes home and hits.
# The wolves' bites and kills: test_wolves 6b and 5c, test_wolf_pups 5b. Shut doors and gates: test_animal_gates (the same hook).
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_attack_walls.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const BigGame := preload("res://src/stream/server_big_game.gd")
const AnimalContact := preload("res://src/shared/animal_contact.gd")

const DIR := "user://test_animal_attack_walls"
const DT := 0.05
const WALL_X := 101.6        # the wall's middle; its faces are 0.125 m either side
const BEHIND := Vector3(101.2, 10.0, 0.0)
const WALL_HALF_M := 36.0     # the wall runs z -36 to 36
const CHARGERS := ["bear", "black_bear", "boar", "moose", "buffalo", "lion", "tiger", "leopard", "puma", "lynx", "hyena", "rhino", "elephant", "dog"]

var failures: int = 0
var items
var animals
var landed: Array = []
var track: PackedStringArray = PackedStringArray()
var crossed: int = 0
var drawn_in: int = 0           # charging steps whose line, carried on carry_m (the client's drawing past the newest point), enters a wall
var carry_m: float = 0.0
var wall_x: float = WALL_X
var wall_half: float = WALL_HALF_M
var foe_at: Vector3 = Vector3.INF    # when set: `opened` is whether, while charging, it ever had an open line to this point
var opened: bool = false
var charges: int = 0                 # times it went into a charge


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "attackwalls0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	animals = AnimalsScript.new()
	animals.ground_height = func(_x, _z): return 10.0
	animals.blocked = func(_x, _z): return false
	animals.player_positions = func(): return items.peer_positions()
	animals.player_stances = func(): return [0]
	animals.setup()
	animals.traits = false

	for sp in animals.cfg["species"]:
		animals.cfg["species"][sp]["target_per_player"] = 0   # only the animals put down here

	animals.cfg["senses"] = {}
	animals.rng.seed = 7
	animals.walls = func(x0, z0, x1, z1, margin): return items.structure_blocks_step(x0, z0, x1, z1, margin)
	animals.big_game.player_info = func(): return items.wolf_info()
	animals.big_game.hurt_player = func(peer, amount, lethal, cause, from):
		var r: String = items.hurt_player(peer, amount, lethal, cause, 10.0, "", 0.0, from)
		landed.append([amount, r])
		return r

	var walls: Array = []

	for n in 36:   # 2 m log walls turned to run north and south: 72 m of wall (a charge slides along a wall it meets; a 25 m one gets round 10 m)
		walls.append(items.dev_place("log_wall@%.1f,%.1f,90" % [WALL_X, -35.0 + 2.0 * float(n)]))

	check(not walls.has(0) and animals.wall_between(Vector3(103.0, 10.0, 0.0), BEHIND), "a 72 m log wall stands across the way at x %.1f" % WALL_X)

	_charges()
	_chase()
	_pinned()
	_pull_up()

	items._finish_writer()
	print("test_animal_attack_walls: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)


# A calm `sp` at (x, 0), facing west (toward the player), with no cool-down.
func put(sp: String, x: float) -> Dictionary:
	animals.animals.clear()
	var id: int = animals.spawn(sp, x, 0.0)
	var a: Dictionary = animals.animals[id]
	a["heading"] = PI
	a["cool"] = 0.0
	return a


func stand(at: Vector3) -> void:
	var v: Dictionary = items.vitals_of(1)
	v["health"] = 100.0
	v.erase("limp")
	items.report_position(1, at)
	landed.clear()


# Ticks `seconds`; returns the smallest x the animal reached (it comes from the east), and counts in `crossed` its steps that cross the
# wall's line where the wall stands (|z| <= WALL_HALF_M). A step past the wall's end is no crossing: an animal may run round it (a lynx's
# charge slides along the wall, then it wanders). Its track (time, x, z, state at each change) is kept in `track`, printed when a check fails.
func run(a: Dictionary, seconds: float) -> float:
	var closest: float = INF
	var last: String = ""
	var was: Vector3 = a["pos"]
	track.clear()
	crossed = 0
	drawn_in = 0
	opened = false
	charges = 0
	var was_state: int = int(a["state"])

	for k in int(round(seconds / DT)):
		animals.tick(DT)

		if animals.animals.has(int(a["id"])):
			var at: Dictionary = animals.animals[int(a["id"])]
			var now: Vector3 = at["pos"]
			closest = minf(closest, float(now.x))

			if int(at["state"]) == BigGame.CHARGE and was_state != BigGame.CHARGE:
				charges += 1

			was_state = int(at["state"])

			if foe_at != Vector3.INF and int(at["state"]) == BigGame.CHARGE and not animals.wall_between(now, foe_at):
				opened = true

			var on: Vector3 = Vector3(now.x - was.x, 0.0, now.z - was.z)

			if carry_m > 0.0 and int(at["state"]) == BigGame.CHARGE and on.length() > 0.001 and animals.wall_between(now, now + on.normalized() * carry_m):
				drawn_in += 1
				track.append("  DRAWN INTO THE WALL from x %.2f z %.2f" % [now.x, now.z])

			if (was.x - wall_x) * (now.x - wall_x) < 0.0:
				var z: float = lerpf(was.z, now.z, (wall_x - was.x) / (now.x - was.x))

				if absf(z) <= wall_half:
					crossed += 1
					track.append("  CROSSED at z %.2f" % z)

			was = now
			var line: String = "x %.2f z %.2f state %d" % [float(now.x), float(now.z), int(at["state"])]

			if line != last:
				track.append("  t %.2f %s" % [float(k + 1) * DT, line])
				last = line

	return closest


func show_track(ok: bool) -> void:
	if not ok:
		print("\n".join(track))


# 1. A forced warning (no bluff) and its charge: in the open it lands; at a player hard behind the wall it never does.
func _charges() -> void:
	for sp in CHARGERS:
		var start_m: float = minf(8.0, float(animals.species_def(sp)["defend"].get("calm_m", 32.0)) - 1.0)      # inside its calm_m, or it calms (a dog 5 m, a lynx 6 m)
		stand(Vector3(0.0, 10.0, 0.0))
		var open: Dictionary = put(sp, start_m)
		var warned: bool = animals.big_game.warn(open, Vector3(0.0, 10.0, 0.0), -1.0, true)
		run(open, 8.0)
		check(warned and not landed.is_empty(), "%s: its charge lands on a player in the open (%d blows)" % [sp, landed.size()])

		stand(BEHIND)
		var walled: Dictionary = put(sp, BEHIND.x + start_m)
		animals.big_game.warn(walled, BEHIND, -1.0, true)
		var closest: float = run(walled, 12.0)
		check(landed.is_empty() and crossed == 0, "%s: its charge at a player behind the wall never lands (%d blows) and it never goes through the wall (%d crossings; nearest x %.2f)" % [sp, landed.size(), crossed, closest])
		show_track(landed.is_empty() and crossed == 0)


# 2. A hunter giving chase to a runner (no warning, no bluff) is the same charge: never through the wall.
func _chase() -> void:
	stand(Vector3(0.0, 10.0, 0.0))
	var open: Dictionary = put("puma", 8.0)
	var chased: bool = animals.big_game.chase(open, Vector3(0.0, 10.0, 0.0), 30.0)
	run(open, 6.0)
	check(chased and not landed.is_empty(), "a puma's chase lands on a runner in the open (%d blows)" % landed.size())

	stand(BEHIND)
	var walled: Dictionary = put("puma", 106.0)
	animals.big_game.chase(walled, BEHIND, 30.0)
	var closest: float = run(walled, 6.0)
	check(landed.is_empty() and crossed == 0, "a puma's chase at a runner behind the wall never lands (%d blows) nor goes through it (%d crossings; nearest x %.2f)" % [landed.size(), crossed, closest])
	show_track(landed.is_empty() and crossed == 0)


# 3. A deer against the wall's east face, a player walking into it from the east: it steps aside, never out through the wall.
func _pinned() -> void:
	var face: float = WALL_X + 0.125
	var player: Vector3 = Vector3(102.4, 10.0, 0.0)
	var deer: Dictionary = put("deer", 101.9)

	for k in 20:
		animals.make_way(deer, player, 0.1, [player])

	check(float(deer["pos"].x) > face, "a deer a player pins against the wall does not step out through it (x %.2f, the face at %.2f)" % [float(deer["pos"].x), face])

	# Nor does keeping a step off a player put it out through the wall behind it: a deer stepping in toward a player along the wall, put back
	# on the contact circle along the line from the player, would land at x 101.5, across the face.
	var stepper: Dictionary = put("deer", 102.03)
	stepper["pos"] = Vector3(102.03, 10.0, 0.3)
	animals.keep_off_players(stepper, Vector3(102.03, 10.0, 1.2), [player])
	check(float(stepper["pos"].x) > face, "a step kept off a player is never put out through the wall behind it (x %.2f)" % float(stepper["pos"].x))


# 4. A charge meeting a wall turns along it its nose and WALL_LOOK_S of running short of it, so its newest leg carried on (as the client
# draws it) never enters the wall; it runs on round a short wall and charges home (one wall piece is no shield); one at a player standing
# with their back to the wall still comes home and hits.
func _pull_up() -> void:
	var face: float = WALL_X + 0.125

	for sp in ["bear", "lion", "elephant"]:
		var speed: float = float(animals.species_def(sp)["defend"].get("charge_mps", 11.0))
		stand(BEHIND)
		var behind: Dictionary = put(sp, 112.0)
		animals.big_game.warn(behind, BEHIND, -1.0, true)
		carry_m = AnimalContact.body_m(sp) + speed * BigGame.WALL_LOOK_S
		var closest: float = run(behind, 10.0)
		var ok: bool = drawn_in == 0 and crossed == 0 and landed.is_empty() and closest < 106.0
		check(ok, "%s: charging at a player behind the long wall, no step's line carried on %.2f m enters it (%d did), it runs up to it (nearest x %.2f) and never through" % [sp, carry_m, drawn_in, closest])
		show_track(ok)

		stand(Vector3(face + 1.0, 10.0, 0.0))
		var backed: Dictionary = put(sp, 112.0)
		animals.big_game.warn(backed, Vector3(face + 1.0, 10.0, 0.0), -1.0, true)
		run(backed, 10.0)
		check(not landed.is_empty(), "%s: one standing with their back to the wall is still charged home and hit (%d blows)" % [sp, landed.size()])

	carry_m = 0.0

	# Kept from its foe by the long wall, it is still angry: it warns and charges again from where it stands (WALL_TRIES times), never landing,
	# then calms.
	stand(BEHIND)
	var angry: Dictionary = put("bear", 106.0)
	animals.big_game.warn(angry, BEHIND, -1.0, true)
	run(angry, 45.0)
	var after: int = int(animals.animals[int(angry["id"])]["state"]) if animals.animals.has(int(angry["id"])) else -1
	var tries_ok: bool = charges >= 2 and charges <= 1 + BigGame.WALL_TRIES and landed.is_empty() and crossed == 0 and not (after in [BigGame.WARN, BigGame.CHARGE, BigGame.RECOVER, BigGame.WARN_POP])
	check(tries_ok, "a bear a wall keeps from its foe charges again, %d times in all (2 to %d), never lands (%d blows) and then calms (state %d)" % [charges, 1 + BigGame.WALL_TRIES, landed.size(), after])
	show_track(tries_ok)

	# One 2 m wall piece, 200 m on (clear of the long wall), is no shield: each charger either lands or charges round it to an open line to
	# the player, never through it.
	var piece: int = items.dev_place("log_wall@301.6,0.0,90")
	var lone: Vector3 = Vector3(301.2, 10.0, 0.0)
	wall_x = 301.6
	wall_half = 1.0
	foe_at = lone
	check(piece != 0, "one 2 m log wall piece stands at x 301.6")

	for sp in ["bear", "boar", "lion", "moose", "hyena"]:
		stand(lone)
		var one: Dictionary = put(sp, lone.x + minf(10.8, float(animals.species_def(sp)["defend"].get("calm_m", 32.0)) - 1.0))   # inside its calm_m (a hyena 10 m)
		animals.big_game.warn(one, lone, -1.0, true)
		run(one, 30.0)
		var round_ok: bool = (not landed.is_empty() or opened) and crossed == 0
		check(round_ok, "a %s charging a player behind one 2 m wall piece lands (%d blows) or gets round it (%s), never through it (%d crossings)" % [sp, landed.size(), "round" if opened else "never round", crossed])
		show_track(round_ok)

	wall_x = WALL_X
	wall_half = WALL_HALF_M
	foe_at = Vector3.INF
	carry_m = 0.0
