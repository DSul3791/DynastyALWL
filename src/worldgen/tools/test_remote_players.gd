extends SceneTree

# Players see each other (protocol 151, Dave 22 Nov 2026, the friends' play test). Server side (server_players.gd): a player is listed to
# the others within 150 m once its look came in, nearest first, with its facing, stance bits, held item and report time; unchanged rows are
# not sent again within a second; looks go to everyone and every known look to a newcomer; a player who leaves is forgotten. Client side
# (player_view.gd): a look and a row draw one body with the player's name, moving between its sent points, its held tool in the hand; a
# body leaves when its row does.
#   godot --headless --path . --script res://src/worldgen/tools/test_remote_players.gd

const PlayersScript := preload("res://src/stream/server_players.gd")
const PlayerViewScript := preload("res://src/client/player_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const BodyModelsScript := preload("res://src/client/character/body_models.gd")
const HeldItemScript := preload("res://src/client/held_item.gd")
const MotionBufferScript := preload("res://src/client/motion_buffer.gd")
const NetScript := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL ", what)

	return ok


class FakeItems:
	extends RefCounted
	var pos: Dictionary = {}
	var stance: Dictionary = {}
	var swim: Dictionary = {}
	var held: Dictionary = {}
	var worn: Dictionary = {}

	func peer_ids() -> Array:
		return pos.keys()

	func position_of(peer: int) -> Variant:
		return pos.get(peer, null)

	func stance_of(peer: int) -> int:
		return int(stance.get(peer, 0))

	func is_swimming(peer: int) -> bool:
		return bool(swim.get(peer, false))

	func carries_log(_peer: int) -> bool:
		return false

	var asleep: Dictionary = {}

	func sleeping_of(peer: int) -> bool:
		return asleep.has(peer)

	var left: Dictionary = {}
	var flags: Dictionary = {}
	var burning: Dictionary = {}

	func left_hand_number(peer: int) -> int:
		return int(left.get(peer, 0))

	func hand_flags(peer: int) -> int:
		return int(flags.get(peer, 0))

	func torch_burning(peer: int) -> bool:
		return burning.has(peer)

	func held_number(peer: int) -> int:
		return int(held.get(peer, 0))

	func worn_of(peer: int) -> Array:
		return worn.get(peer, [0, 0, 0])


func _server() -> void:
	var fake := FakeItems.new()
	var players = PlayersScript.new()
	var clock: Array = [1000]
	var sent: Array = []
	var looks: Array = []
	players.items = fake
	players.now_ms = func() -> int: return int(clock[0])
	var flights: Array = []
	players.send_rows = func(peer, ids, positions, yaws, states, held, times, left, more): sent.append([peer, ids, positions, yaws, states, held, times, left, more])
	players.send_flight = func(peer, number, from, velocity, fire): flights.append([peer, number, from, velocity, fire])
	players.send_look = func(to, about, char_name, body, code, worn_numbers): looks.append([to, about, char_name, body, code, worn_numbers])
	fake.pos = {1: Vector3(100.0, 10.0, 100.0), 2: Vector3(110.0, 10.0, 100.0), 3: Vector3(100.0, 10.0, 400.0), 4: Vector3(101.0, 10.0, 100.0)}
	fake.stance = {2: 1}
	fake.swim = {2: true}
	fake.held = {2: 77}
	fake.worn = {2: [5, 0, 9]}

	players.set_look(1, "Ann", "body_1", "code1")
	check(looks.is_empty(), "the first look goes to nobody (no one else has sent one)")
	players.set_look(2, "  Bob the very long named woodcutter of the hills  ", "body_2", "code2")
	check(looks.size() == 2, "a second player's look goes to the first, and the first's to it (%d)" % looks.size())
	var to_one: Array = looks.filter(func(l): return int(l[0]) == 1 and int(l[1]) == 2)
	check(to_one.size() == 1 and str(to_one[0][2]).length() <= PlayersScript.NAME_MAX and str(to_one[0][2]).begins_with("Bob"), "the name is trimmed and clipped to %d" % PlayersScript.NAME_MAX)
	check(to_one.size() == 1 and to_one[0][5] == PackedInt32Array([5, 0, 9]), "the look carries the worn pieces")
	players.set_look(3, "Cal", "body_1", "code3")
	players.note_report(1, 0.0)
	players.note_report(2, 1.5)
	players.note_report(3, 0.0)
	players.note_report(4, 0.0)
	looks.clear()
	players.set_look(1, "Ann B", "body_1", "code1")
	check(looks.is_empty(), "a second look within a second is ignored (no flood of reliable looks)")
	check(PlayersScript.clean_name("a\nb\tc") == "a b c", "control characters in a name become spaces")
	clock[0] = 1200
	players.tick(0.2)
	var to_peer: Dictionary = {}

	for row in sent:
		to_peer[int(row[0])] = row

	check(to_peer.has(1) and to_peer[1][1] == PackedInt32Array([2]), "player 1 sees player 2 only: not 3 (300 m off), not 4 (no look), not itself")
	check(to_peer.has(1) and is_equal_approx(float(to_peer[1][3][0]), 1.5), "the facing goes with the row")
	check(to_peer.has(1) and int(to_peer[1][4][0]) == (1 | PlayersScript.SWIM), "the state is the stance with the swimming bit")
	check(to_peer.has(1) and int(to_peer[1][5][0]) == 77, "the held item goes with the row")
	check(to_peer.has(1) and int(to_peer[1][6][0]) == 1000, "the row carries the server ms of the position report")
	check(not to_peer.has(3), "player 3, alone, is not sent an empty list it already has")
	sent.clear()
	clock[0] = 1400
	players.tick(0.2)
	check(sent.is_empty(), "unchanged rows are not sent again within a second (%d sent)" % sent.size())
	players.note_report(2, 1.6)
	clock[0] = 1500
	players.tick(0.2)
	check(sent.size() == 1 and int(sent[0][0]) == 1, "a new position report from player 2 goes out to player 1")
	sent.clear()
	clock[0] = 2600
	players.tick(0.2)
	check(sent.size() >= 2, "unchanged rows go again after a second (%d)" % sent.size())

	# Swings and sleep ride in the state byte's high bits (no new field): a blow is news at once, a walk or a craft is not a swing.
	sent.clear()
	check(PlayersScript.SWING_ACTS.has(NetScript.ACT_HIT) and PlayersScript.SWING_ACTS.has(NetScript.ACT_MINE) and not PlayersScript.SWING_ACTS.has(NetScript.ACT_MOVE), "a hit and a mine blow are swings, a pack move is not")
	players.note_action(2, NetScript.ACT_HIT)
	players.note_action(2, NetScript.ACT_MOVE)
	fake.asleep = {2: true}
	clock[0] = 2700
	players.tick(0.2)
	check(sent.size() == 1 and int(sent[0][0]) == 1, "a swing goes out to player 1 at the next send, with no new position")
	check(sent.size() == 1 and (int(sent[0][4][0]) >> PlayersScript.SWING_SHIFT) == 1, "the swing count is 1 (a pack move is not a swing)")
	check(sent.size() == 1 and (int(sent[0][4][0]) & PlayersScript.ASLEEP) != 0 and (int(sent[0][4][0]) & 3) == 1, "the asleep bit, the stance kept")
	check(sent.size() == 1 and int(sent[0][6][0]) == 1400, "the row's time stays the position report's")
	fake.asleep = {}
	# 159: the left hand, a burning torch, the hand flags and a meal are news and go with the row.
	sent.clear()
	var torch_n: int = ItemTableScript.load_default().number_of("torch")
	fake.left = {2: torch_n}
	fake.burning = {2: true}
	fake.flags = {2: 1 | 8}   # bow raised, on a ladder
	players.note_action(2, NetScript.ACT_DRINK)
	clock[0] = 2750
	players.tick(0.2)
	check(sent.size() == 1 and int(sent[0][7][0]) == torch_n, "the left hand's torch goes with the row")
	var more_byte: int = int(sent[0][8][0]) if sent.size() == 1 else 0
	check((more_byte & PlayersScript.MORE_LIT) != 0 and ((more_byte >> PlayersScript.MORE_HANDS_SHIFT) & 15) == 9 and (more_byte >> PlayersScript.MORE_MEAL_SHIFT) == 1, "burning, the hand flags and one drink in the more byte (%d)" % more_byte)
	sent.clear()
	clock[0] = 2760
	players.tick(0.2)
	check(sent.is_empty(), "no news, nothing sent within the second")
	players.flight(2, 77, Vector3(110.0, 11.6, 100.0), Vector3(30.0, 2.0, 0.0), true)
	check(flights.size() == 1 and int(flights[0][0]) == 1 and int(flights[0][1]) == 77 and bool(flights[0][4]), "an arrow loosed by player 2 is sent to player 1 (near, with a look), not to the thrower, not to 3 (300 m off)")
	fake.left = {}
	fake.burning = {}
	fake.flags = {}
	# The row times are when the client sent each report, not when it arrived (note_move): a walker reporting every 0.2 s over a link
	# that delays each report 120 +- 30 ms keeps legs of its own length, so the others draw it at its own speed (robots: 1.3 to 1.7x bursts).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1574
	var walker_at: Vector3 = Vector3(0.0, 10.0, 0.0)
	var send_ms: float = 100000.0
	var stamps: Array = []
	var worst: float = 0.0
	var after_arrival: int = 0
	var arrivals: Array = []

	for n in range(150):
		var gap_s: float = 0.2 + rng.randf() * 0.016   # a 60 fps client sends on the first frame 0.2 s after the last
		send_ms += gap_s * 1000.0
		var speed: float = 3.3 if n < 50 else (9.0 if n < 100 else 3.3)
		var moved: Vector3 = Vector3(0.0, 0.0, -speed * gap_s)
		walker_at += moved
		arrivals.append([send_ms + 120.0 + rng.randf_range(-30.0, 30.0), walker_at, moved / gap_s])

	arrivals.sort_custom(func(a, b): return float(a[0]) < float(b[0]))   # unreliable: a later report can come first

	for row in arrivals:
		clock[0] = int(row[0])
		players.note_move(9, row[1], row[2])
		players.note_report(9, 0.0)
		stamps.append([int(players._report_ms[9]), row[1]])

		if int(players._report_ms[9]) > int(clock[0]):
			after_arrival += 1

	for k in range(10, stamps.size()):
		var leg_s: float = float(int(stamps[k][0]) - int(stamps[k - 1][0])) / 1000.0
		var leg_m: float = (stamps[k][1] as Vector3).distance_to(stamps[k - 1][1])
		var real: float = 9.0 if leg_m > 1.0 else 3.3

		if leg_s > 0.0 and leg_m > 0.0:
			worst = maxf(worst, leg_m / leg_s / real)

	check(worst < 1.15 and after_arrival == 0, "a walker's legs keep their own length through 120 +- 30 ms jitter: drawn at most %.2fx its speed (want < 1.15), no stamp after its arrival (%d)" % [worst, after_arrival])
	# A made-up report (NaN, huge numbers, a flood in one millisecond) only moves its own row's times, never ahead of the arrival nor
	# more than STAMP_BEHIND_MS behind it, and always forward.
	var bad: Array = [[Vector3(NAN, 0.0, 0.0), Vector3.ZERO], [Vector3(3e38, 0.0, 0.0), Vector3(2000.0, 0.0, 0.0)], [Vector3(-3e38, 0.0, 0.0), Vector3(2000.0, 0.0, 0.0)],
			[Vector3.ZERO, Vector3(INF, 0.0, 0.0)], [Vector3(1.0, 0.0, 0.0), Vector3(2000.0, 0.0, 0.0)], [Vector3(2.0, 0.0, 0.0), Vector3(-2000.0, 0.0, 0.0)]]
	var bad_ok: bool = true
	var last_stamp: int = int(players._report_ms[9])

	for k in range(60):
		clock[0] += 0 if k % 3 != 0 else 7
		var row: Array = bad[k % bad.size()]
		players.note_move(9, row[0], row[1])
		players.note_report(9, 0.0)
		var st: int = int(players._report_ms[9])
		bad_ok = bad_ok and st <= int(clock[0]) and st >= int(clock[0]) - int(PlayersScript.STAMP_BEHIND_MS) - 1 and st >= last_stamp
		last_stamp = st

	check(bad_ok and (players._move[9][0] as Vector3).is_finite(), "made-up reports keep the stamps within %d ms before their arrival, never after it, never back" % int(PlayersScript.STAMP_BEHIND_MS))
	clock[0] = 2760
	check(not PlayersScript.SWING_ACTS.has(NetScript.ACT_TILL_GARDEN), "the hoe grid's check-only polls (ACT_TILL_GARDEN) are not swings")
	for i in range(8):
		players.note_action(2, NetScript.ACT_MINE)
	check((int(players._swings[2][0])) == 1, "the swing count wraps at 8")
	clock[0] = 2800

	looks.clear()
	players.worn_changed(2, PackedInt32Array([5, 0, 9]))
	check(looks.is_empty(), "the same worn pieces send nothing")
	fake.worn[2] = [6, 0, 9]
	players.worn_changed(2, PackedInt32Array([6, 0, 9]))
	check(looks.size() == 2, "new worn pieces go to the others (%d)" % looks.size())

	# A game that froze or crashed (its line can take up to 2 minutes to time out, net_settings.gd): after SILENT_MS without a report the
	# player leaves the others' rows, so no ghost stands there, and is back with its next report.
	var later: int = int(clock[0]) + 100
	clock[0] = later
	players.note_move(1, fake.pos[1], Vector3.ZERO)
	players.note_report(1, 0.0)
	players.note_move(2, fake.pos[2], Vector3.ZERO)
	players.note_report(2, 0.0)
	for step in range(int(PlayersScript.SILENT_MS / 1000.0) + 1):   # the server ticks on, player 1 still reports; player 2 has gone quiet
		clock[0] = later + 1000 * (step + 1)
		players.note_move(1, fake.pos[1], Vector3.ZERO)
		players.note_report(1, 0.0)
		sent.clear()
		players.tick(0.2)

	var quiet_rows: Array = sent.filter(func(r): return int(r[0]) == 1)
	check(quiet_rows.size() == 1 and not (quiet_rows[0][1] as PackedInt32Array).has(2), "a player silent for %.0f s leaves the others' rows (no ghost)" % (PlayersScript.SILENT_MS / 1000.0))
	var quiet_two: Array = sent.filter(func(r): return int(r[0]) == 2)
	check(quiet_two.is_empty() or (quiet_two[0][1] as PackedInt32Array).has(1), "the silent player is still sent the others, for when its game wakes")
	clock[0] += 200
	players.note_move(2, fake.pos[2], Vector3.ZERO)
	players.note_report(2, 0.0)
	sent.clear()
	players.tick(0.2)
	quiet_rows = sent.filter(func(r): return int(r[0]) == 1)
	check(quiet_rows.size() == 1 and (quiet_rows[0][1] as PackedInt32Array).has(2), "its next report brings it back")
	clock[0] += PlayersScript.SILENT_MS + 5000   # the server itself stalls (a long save): nobody's reports could arrive, nobody vanishes
	sent.clear()
	players.tick(0.2)
	quiet_rows = sent.filter(func(r): return int(r[0]) == 1)
	check(quiet_rows.is_empty() or (quiet_rows[0][1] as PackedInt32Array).has(2), "a server stall of its own hides nobody")

	fake.pos.erase(2)
	players.forget(2)
	sent.clear()
	clock[0] = 2900
	players.tick(0.2)
	check(sent.size() >= 1 and (sent[0][1] as PackedInt32Array).is_empty(), "a player who left is dropped from the rows")

	var many: Dictionary = {}

	for i in range(40):
		many[i] = Vector3(float(i), 0.0, 0.0)

	var rows: Array = PlayersScript.rows_for(0, many)
	check(rows.size() == PlayersScript.MAX_ROWS and int(rows[0][0]) == 1 and int(rows[rows.size() - 1][0]) == PlayersScript.MAX_ROWS, "at most %d rows, nearest first" % PlayersScript.MAX_ROWS)


func _client() -> void:
	var table = ItemTableScript.load_default()
	var view: Node3D = PlayerViewScript.new()
	view.table = table
	get_root().add_child(view)
	var axe: int = table.number_of("stone_axe")
	var at: Vector3 = Vector3(58160.0, 30.0, 71360.0)
	var t0: int = 5000
	var camera: Camera3D = Camera3D.new()   # bodies animate by their distance from the camera (full within 15 m)
	get_root().add_child(camera)
	camera.position = at + Vector3(0.0, 1.6, 6.0)
	camera.make_current()
	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([0]), PackedInt32Array([0]), PackedInt32Array([t0]))
	check(view.drawn_count() == 0, "a row before the look draws nothing yet")
	view.on_look(7, "Dana", "body_1", "", PackedInt32Array())

	for i in range(200):
		if PlayerViewScript._can_make({"body": "body_1", "code": ""}):
			break

		await process_frame

	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([0]), PackedInt32Array([axe]), PackedInt32Array([t0]))
	check(view.drawn_count() == 1, "a look and a row draw one body (%d)" % view.drawn_count())
	var body: Dictionary = view._bodies.get(7, {})

	if body.is_empty():
		return

	var node: Node3D = body["node"]
	check((node.get_node("Name") as Label3D).text == "Dana", "the name is over the head")

	for i in range(5):
		await process_frame

	check(body.get("held_node", null) != null, "the stone axe is in the hand")

	# A walk east: rows 200 ms apart, 0.6 m each (3 m/s); the drawn body moves between them, never past the newest.
	for step in range(1, 8):
		view.on_rows(PackedInt32Array([7]), PackedVector3Array([at + Vector3(0.6 * step, 0.0, 0.0)]), PackedFloat32Array([0.0]), PackedByteArray([0]), PackedInt32Array([axe]), PackedInt32Array([t0 + 200 * step]))
		var until: int = Time.get_ticks_msec() + 200

		while Time.get_ticks_msec() < until:
			await process_frame

	var moved: float = node.position.x - at.x
	# Past the newest point the body may carry on at its last speed (3 m/s) for up to MotionBuffer.CARRY_S, then stands (motion_buffer.gd).
	check(moved > 0.6 and moved <= 4.2 + 3.0 * MotionBufferScript.CARRY_S + 0.01, "the body walked between its sent points (%.2f m of 4.2, carry at most %.1f m)" % [moved, 3.0 * MotionBufferScript.CARRY_S])

	if DynastyBodyScript.available():
		var clip: String = str(body["rig"].current())
		check(clip in ["walk", "jog", "walk_torch", "jog_torch"], "walking plays a gait clip (%s)" % clip)

	# Tester report #7 (23 Nov 2026): other players mat the grass. The first pass marks the start; after a walk the points run along the way,
	# at the feet, no more than TRAIL_STEP_M apart (up to TRAIL_MOST), and none beyond the reach.
	check(view.trail_points(node.position, 60.0).is_empty(), "the first trail pass only marks where the player is")
	var trail_from: Vector3 = node.position
	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at + Vector3(6.0, 0.0, 0.0)]), PackedFloat32Array([0.0]), PackedByteArray([0]), PackedInt32Array([axe]), PackedInt32Array([t0 + 2000]))
	var walk_until: int = Time.get_ticks_msec() + 900

	while Time.get_ticks_msec() < walk_until:
		await process_frame

	check(node.position.x - trail_from.x > 0.5, "the body walked on")
	check(view.trail_points(node.position + Vector3(1000.0, 0.0, 0.0), 60.0).is_empty(), "nothing is stamped beyond the reach")
	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at + Vector3(8.0, 0.0, 0.0)]), PackedFloat32Array([0.0]), PackedByteArray([0]), PackedInt32Array([axe]), PackedInt32Array([t0 + 2600]))
	var walk_more: int = Time.get_ticks_msec() + 900

	while Time.get_ticks_msec() < walk_more:
		await process_frame

	var before_x: float = float((view._bodies[7]["trail_at"] as Vector3).x)
	var spots: Array = view.trail_points(node.position, 60.0)
	var feet_y: float = node.position.y - 0.9
	check(not spots.is_empty() and spots.size() <= PlayerViewScript.TRAIL_MOST, "a walk leaves trail points (%d)" % spots.size())
	check(spots.all(func(p): return absf(float(p.y) - feet_y) < 0.01 and float(p.x) > before_x - 0.01), "the points are at the feet, along the way walked")
	check(spots.size() < 2 or absf(float(spots[1].x) - float(spots[0].x)) <= PlayerViewScript.TRAIL_STEP_M + 0.01, "no more than TRAIL_STEP_M between points")

	view.on_rows(PackedInt32Array(), PackedVector3Array(), PackedFloat32Array(), PackedByteArray(), PackedInt32Array(), PackedInt32Array())
	check(view.drawn_count() == 0, "a player out of range is removed")
	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([2 | PlayerViewScript.SWIM]), PackedInt32Array([0]), PackedInt32Array([t0 + 3000]))
	check(view.drawn_count() == 1, "and drawn again when back in range")

	for i in range(5):
		await process_frame

	if DynastyBodyScript.available() and view._bodies.has(7):
		var swim_clip: String = str(view._bodies[7]["rig"].current())
		check(swim_clip.begins_with("swim"), "a swimming player plays the swim clip (%s)" % swim_clip)

	# A blow (the swing count in the state's high bits moves on): the body plays the tool's work clip once, then goes back to its stance clip.
	check(PlayerViewScript.work_clip(axe, table) == "chop" and PlayerViewScript.work_clip(table.number_of("stone_pickaxe"), table) == "pick_overhead" and PlayerViewScript.work_clip(table.number_of("wooden_spear"), table) == "jab", "the work clip follows the tool: chop, pick, jab")
	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([0]), PackedInt32Array([axe]), PackedInt32Array([t0 + 3200]))

	for i in range(5):
		await process_frame

	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([1 << PlayerViewScript.SWING_SHIFT]), PackedInt32Array([axe]), PackedInt32Array([t0 + 3300]))

	for i in range(3):
		await process_frame

	if DynastyBodyScript.available() and view._bodies.has(7):
		var swing_clip: String = str(view._bodies[7]["rig"].current())
		check(swing_clip == "chop", "a swing with the axe plays the chop (%s)" % swing_clip)
		var swing_player: AnimationPlayer = view._bodies[7]["rig"].get("animation_player")
		check(swing_player.current_animation_position >= swing_player.get_animation("chop").length * HeldItemScript.HIT_AT - PlayerViewScript.SWING_LEAD_S - 0.01, "it starts just before the impact (the blow came at the impact), at %.2f s" % swing_player.current_animation_position)
		var swing_end: int = Time.get_ticks_msec() + 1600

		while Time.get_ticks_msec() < swing_end:
			await process_frame

		var after_clip: String = str(view._bodies[7]["rig"].current())
		check(after_clip != "chop" and not view._bodies[7]["rig"].is_one_shot_playing(), "the chop plays out and the body goes back to its stance clip (%s)" % after_clip)

		# 159: a burning torch in the left hand, with its light; put out, no light; a drink plays the drink clip.
		var torch_n: int = table.number_of("torch")
		view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([1 << PlayerViewScript.SWING_SHIFT]), PackedInt32Array([axe]), PackedInt32Array([t0 + 3400]), PackedInt32Array([torch_n]), PackedByteArray([PlayerViewScript.MORE_LIT]))

		for i in range(3):
			await process_frame

		var lit_torch: Node3D = view._bodies[7].get("left_node", null)
		check(lit_torch != null and lit_torch.get_parent() == view._bodies[7]["rig"].hand_mount_l and lit_torch.get_node_or_null("Light") != null and (lit_torch.get_node("Light") as OmniLight3D).visible, "a burning torch in the other player's left hand, casting its light")
		check(str(view._bodies[7].get("left_kind", "")) == "torch" and bool(view._bodies[7]["rig"].get_meta("torch_left", false)), "the arm carries it up (torch_left)")
		view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([1 << PlayerViewScript.SWING_SHIFT]), PackedInt32Array([axe]), PackedInt32Array([t0 + 3500]), PackedInt32Array([torch_n]), PackedByteArray([1 << PlayerViewScript.MORE_MEAL_SHIFT]))

		for i in range(3):
			await process_frame

		var out_torch: Node3D = view._bodies[7].get("left_node", null)
		check(out_torch != null and out_torch.get_node_or_null("Light") == null, "the torch gone out: no light")
		# Five other players with burning torches: only the LIT_MOST nearest cast light, one light each (no hand light).
		var crowd: Array = [21, 22, 23, 24, 25]

		for cp in crowd:
			view.on_look(cp, "Torch %d" % cp, "body_1", "", PackedInt32Array())

		for round_n in range(4):   # MAKE_PER_ROWS bodies a message
			var ids: PackedInt32Array = PackedInt32Array([7] + crowd)
			var crowd_at: PackedVector3Array = PackedVector3Array([at])
			for k in range(crowd.size()):
				crowd_at.append(at + Vector3(2.0 + k, 0.0, 0.0))
			view.on_rows(ids, crowd_at, PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]), PackedByteArray([1 << PlayerViewScript.SWING_SHIFT, 0, 0, 0, 0, 0]), PackedInt32Array([axe, 0, 0, 0, 0, 0]), PackedInt32Array([t0 + 3600 + round_n * 100, t0 + 3600 + round_n * 100, t0 + 3600 + round_n * 100, t0 + 3600 + round_n * 100, t0 + 3600 + round_n * 100, t0 + 3600 + round_n * 100]), PackedInt32Array([torch_n, torch_n, torch_n, torch_n, torch_n, torch_n]), PackedByteArray([1 << PlayerViewScript.MORE_MEAL_SHIFT, 1, 1, 1, 1, 1]))
			await process_frame

		for i in range(3):
			await process_frame

		var lights_on: int = 0
		var hand_on: int = 0

		for cp in crowd:
			var torch_node: Node3D = view._bodies.get(cp, {}).get("left_node", null)

			if torch_node != null and (torch_node.get_node("Light") as OmniLight3D).visible:
				lights_on += 1
				check(is_equal_approx((torch_node.get_node("Light") as OmniLight3D).light_energy, HeldItemScript.FlameRules.TORCH_LIGHT_ENERGY), "another player's torch is as bright as one's own")

			if torch_node != null and torch_node.get_node_or_null("HandLight") != null and (torch_node.get_node("HandLight") as OmniLight3D).visible:
				hand_on += 1

		check(view.drawn_count() == 6 and lights_on == PlayerViewScript.LIT_MOST and hand_on == 0, "five burning torches: the %d nearest light, one light each (%d drawn, %d lit, %d hand lights)" % [PlayerViewScript.LIT_MOST, view.drawn_count(), lights_on, hand_on])
		view.lit_most = func() -> int: return PlayerViewScript.LIT_MOST_LOW   # the Low graphics tier

		for i in range(3):
			await process_frame

		var low_on: int = 0

		for lp in [7] + crowd:
			var low_node: Node3D = view._bodies.get(lp, {}).get("left_node", null)

			if low_node != null and low_node.get_node_or_null("Light") != null and (low_node.get_node("Light") as OmniLight3D).visible:
				low_on += 1

		check(low_on == PlayerViewScript.LIT_MOST_LOW, "on the Low tier only %d torch lights (%d lit)" % [PlayerViewScript.LIT_MOST_LOW, low_on])
		view.lit_most = func() -> int: return PlayerViewScript.LIT_MOST
		var drink_clip: String = str(view._bodies[7]["rig"].current())
		check(drink_clip == "drink" or not view._bodies[7]["rig"].animation_player.has_animation("drink"), "a drink plays the drink clip (%s)" % drink_clip)


# Over a real connection (the coordinator's ask, 23 Nov 2026: smooth under 100 to 150 ms and a few percent loss): rows sent every 125 ms
# carrying 0.2 s position reports, each delivered 100 to 260 ms late (a random wobble), one in twenty lost and once four in a row, for a walk at 3 m/s, then a
# stop. The drawn body must never jump (no frame step over a normal one plus the easing's catch-up), keep moving through the walk (no stand
# then jump at a lost batch), and come to rest near the last point without running past and back.
func _check_lossy(burst_ms: int, tail_ms: int) -> void:
	var table = ItemTableScript.load_default()
	var view: Node3D = PlayerViewScript.new()
	view.table = table
	get_root().add_child(view)
	var at: Vector3 = Vector3(1000.0, 30.0, 1000.0)
	var camera: Camera3D = Camera3D.new()
	get_root().add_child(camera)
	camera.position = at + Vector3(0.0, 1.6, 6.0)
	camera.make_current()
	var peers: Array = [9, 10, 11]
	var phase: Array = [0, 70, 140]   # each client reports on its own 0.2 s beat

	for peer in peers:
		view.on_look(peer, "Lossy", "body_1", "", PackedInt32Array())

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1523
	var start_ms: int = Time.get_ticks_msec()
	var walk_ms: int = 3000
	var end_ms: int = 4600
	var queue: Array = []   # [deliver at ms, [server ms per peer], [position per peer]]
	var sent_ms: Array = [-1, -1, -1]
	var last_send: int = -1000

	# As server_players.gd: a send every 125 ms only when a report is news (or a second on), each report stamped when it reached the server.
	for send in range(0, end_ms, 125):
		var times: Array = []
		var spots: Array = []
		var news: bool = send - last_send >= 1000

		for i in range(peers.size()):
			var beat: int = send - int(phase[i])
			var report: int = maxi(beat - posmod(beat, 200), 0) + int(phase[i])
			var stamp: int = 20000 + report + (posmod(hash([i, report]), 61) if report > 0 else 0)   # the report's own trip up, with its wobble, once per report
			var walked: float = 3.0 * float(mini(report, walk_ms)) / 1000.0
			times.append(stamp)
			spots.append(at + Vector3(walked, 0.0, 3.0 * i))
			news = news or report > int(sent_ms[i])
			sent_ms[i] = maxi(int(sent_ms[i]), report)

		if not news:
			continue

		last_send = send

		if rng.randf() < 0.05 or (send >= burst_ms and send < burst_ms + 500):
			continue   # lost (ENet drops unreliable packets when the ping wobbles), and once four in a row (a throttle burst)

		queue.append([send + rng.randi_range(100, 260), times, spots])

	queue.sort_custom(func(x, y): return int(x[0]) < int(y[0]))
	var worst_step: float = 0.0
	var still_frames: int = 0
	var last_p: Dictionary = {}
	var past: float = 0.0   # the farthest any body went beyond its last point (9 m)
	var last_t: int = Time.get_ticks_usec()

	while not queue.is_empty() or Time.get_ticks_msec() - start_ms < end_ms + tail_ms:
		var now: int = Time.get_ticks_msec() - start_ms

		while not queue.is_empty() and int(queue[0][0]) <= now:
			var row: Array = queue.pop_front()
			view.on_rows(PackedInt32Array(peers), PackedVector3Array(row[2]), PackedFloat32Array([-PI * 0.5, -PI * 0.5, -PI * 0.5]), PackedByteArray([0, 0, 0]), PackedInt32Array([0, 0, 0]), PackedInt32Array(row[1]))

		await process_frame
		var dt: float = float(Time.get_ticks_usec() - last_t) / 1.0e6

		if dt < 0.05:
			continue   # measured over 50 ms windows (headless frames are far shorter than a millisecond clock can time)

		last_t = Time.get_ticks_usec()

		for peer in peers:
			var b: Dictionary = view._bodies.get(peer, {})

			if b.is_empty():
				continue

			var p: Vector3 = (b["node"] as Node3D).position

			if last_p.has(peer) and now > 1200 and now < walk_ms + 100:   # while it walks (past the first second, before the stop is drawn)
				var step: float = p.distance_to(last_p[peer]) / dt
				worst_step = maxf(worst_step, step)

				if step < 0.3:
					still_frames += 1

			last_p[peer] = p
			past = maxf(past, p.x - at.x - 9.0)

	var rest_ok: bool = true

	for peer in peers:
		rest_ok = rest_ok and view._bodies.has(peer) and absf(float((view._bodies[peer]["node"] as Node3D).position.x) - at.x - 9.0) < 0.15

	check(view.drawn_count() == 3, "three players on the lossy link are drawn (%d)" % view.drawn_count())
	check(worst_step < 3.0 * 1.5, "no jump on a lossy, late link: the fastest drawn speed %.1f m/s for a 3 m/s walk" % worst_step)
	check(still_frames == 0, "the bodies keep walking through lost and late batches (%d still 50 ms windows)" % still_frames)
	check(rest_ok, "each comes to rest at its last point (burst at %d ms)" % burst_ms)
	check(past <= 3.0 * PlayerViewScript.CARRY_S + 0.3, "no body walks on more than %.1f m past its stop (%.2f m)" % [3.0 * PlayerViewScript.CARRY_S, past])
	var hitch: Dictionary = MotionBufferScript.clock_new()
	hitch["late"] = 1.5   # a 1.5 s hitch on this computer: the batch after it reads 1.5 s late
	check(PlayerViewScript.draw_delay(hitch) <= MotionBufferScript.MAX_DELAY_S, "after a hitch the draw delay stays within %.1f s (%.2f)" % [MotionBufferScript.MAX_DELAY_S, PlayerViewScript.draw_delay(hitch)])
	check(PlayerViewScript.draw_delay(MotionBufferScript.clock_new()) >= PlayerViewScript.REPORT_S, "and never under one report gap")
	view.queue_free()
	camera.queue_free()
	await process_frame


# Dave 23 Nov 2026 on 9257: another player's spear "floating in the air almost sticking out of his chest". Every item with a hand look, on
# every body model, is put in a remote player's hand as the player's own third-person body holds it: under that body's hand mount (the left
# for a bow), its middle within reach of the hand, and a spear pointing ahead along the facing (not along the fingers, as before the fix).
func _check_holds() -> void:
	if not DynastyBodyScript.available():
		print("test_remote_players: the Dynasty glb is not imported here, the hold checks are skipped")
		return

	var table = ItemTableScript.load_default()
	var numbers: Array = []

	for id in table.ids():
		var n: int = table.number_of(str(id))

		if PlayerViewScript.held_model(n, table) != null:
			numbers.append(n)

	check(numbers.size() >= 10, "items with a hand look found (%d)" % numbers.size())
	var spears: int = 0

	for body in BodyModelsScript.ids():
		if not DynastyBodyScript.available(str(body)):
			continue

		var holder: Node3D = Node3D.new()
		holder.rotation.y = 0.7
		get_root().add_child(holder)
		var rig: Node3D = PlayerViewScript.make_rig(str(body), {})
		holder.add_child(rig)
		rig.play("idle")
		await process_frame
		var front: Vector3 = rig.global_basis * Vector3.FORWARD
		front = Vector3(front.x, 0.0, front.z).normalized()

		for n in numbers:
			var made: Array = PlayerViewScript.hold_in(rig, int(n), table)
			var id: String = table.id_of(int(n))

			if not check(made.size() == 2, "%s %s: held" % [body, id]):
				continue

			var model: Node3D = made[0]
			var mount: Node3D = model.get_parent() as Node3D
			check(mount == rig.get("hand_mount_l" if made[1] == "bow" else "hand_mount_r"), "%s %s: in the %s hand" % [body, id, "left" if made[1] == "bow" else "right"])
			var mesh: MeshInstance3D = model.get_child(0) as MeshInstance3D
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			var hand: Vector3 = mount.global_position
			var off: float = hand.distance_to(hand.clamp(box.position, box.end))
			check(off < 0.12, "%s %s (%s): the item is in the hand, %.2f m from it" % [body, id, made[1], off])

			if made[1] == "spear":
				spears += 1
				var point: Vector3 = -model.global_basis.z.normalized()
				check(point.dot(front) > 0.95, "%s %s: the spear points ahead along the facing (%.2f)" % [body, id, point.dot(front)])
				var rest: Transform3D = mount.transform
				mount.rotate_object_local(Vector3.RIGHT, 0.6)   # the hand swings, as a walk clip moves it; the spear keeps the facing, its fist the hand
				mount.position += Vector3(0.0, 0.0, 15.0)   # 0.15 m in the centimetre skeleton
				PlayerViewScript.aim_spear(model, rig)
				var fist: Node3D = model.get_node_or_null(HeldItemScript.THIRD_FIST_NAME) as Node3D
				check(fist != null and fist.global_position.distance_to(mount.global_position) < 0.02 and fist.global_basis.z.normalized().dot(mount.global_basis.z.normalized()) > 0.99, "%s %s: the fist stays on the hand, along the fingers, as it swings" % [body, id])
				mount.transform = rest

			model.free()

		holder.queue_free()

	check(spears > 0, "a spear was among the held items")


# Robots 23 Nov 2026: a player 70 m off lay down and was drawn standing (bodies past QUARTER_M are not animated, and the clip stayed idle).
# Far off the body still takes the lying, sitting or swimming pose when the state says so, once, with no animation after.
func _check_far_pose() -> void:
	if not DynastyBodyScript.available():
		return

	var view: Node3D = PlayerViewScript.new()
	view.table = ItemTableScript.load_default()
	get_root().add_child(view)
	var at: Vector3 = Vector3(1000.0, 30.0, 1000.0)
	var camera: Camera3D = Camera3D.new()
	get_root().add_child(camera)
	camera.position = at + Vector3(0.0, 1.6, PlayerViewScript.QUARTER_M + 30.0)
	camera.make_current()
	view.on_look(9, "Far", "body_1", "", PackedInt32Array())
	var ms: int = 90000
	var clips: Array = []

	for stance in [0, 3, 2, 0]:
		for i in range(12):
			ms += 125
			view.on_rows(PackedInt32Array([9]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([stance | (PlayerViewScript.ASLEEP if stance == 3 else 0)]), PackedInt32Array([0]), PackedInt32Array([ms]))
			await process_frame

		var b: Dictionary = view._bodies.get(9, {})
		clips.append(str(b["rig"].call("current")) if not b.is_empty() else "")

	check(clips == ["idle", "lie", "sit", "idle"], "a far player lying down, then sitting, then up, is drawn so (%s)" % ", ".join(clips))
	view.queue_free()
	camera.queue_free()


# Robots 23 Nov 2026: another player's spear read 0.33 m off the running hand. The hand mount is on a BoneAttachment3D, which follows the
# bones only at the skeleton's deferred update, so straight after a step of the clip it still held the last step's hand (and aim_spear
# turned the spear by that). player_view.gd follow_hand moves it to this step's hand first.
func _check_hand_follows() -> void:
	if not DynastyBodyScript.available():
		return

	var table = ItemTableScript.load_default()
	var rig: Node3D = PlayerViewScript.make_rig("body_1", {})
	get_root().add_child(rig)
	var player: AnimationPlayer = rig.get("animation_player") as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	rig.play("run")
	await process_frame
	var worst: Array = [0.0, 0.0]

	for kind in range(2):
		var made: Array = PlayerViewScript.hold_in(rig, int(table.number_of("wooden_spear" if kind == 0 else "stone_axe")), table)
		var model: Node3D = made[0]
		var mount: Node3D = model.get_parent() as Node3D
		var skel: Skeleton3D = rig.get("skeleton") as Skeleton3D
		var bone: int = skel.find_bone("RightHand") if skel.find_bone("RightHand") >= 0 else skel.find_bone("mixamorig_RightHand")

		for i in range(12):   # steps of the run clip, read straight after each as another node's _process would
			player.advance(0.07)

			if made[1] == "spear":
				PlayerViewScript.aim_spear(model, rig)
			else:
				PlayerViewScript.follow_hand(model)

			worst[kind] = maxf(float(worst[kind]), mount.global_position.distance_to((skel.global_transform * skel.get_bone_global_pose(bone)).origin))
			await process_frame

		model.free()

	check(float(worst[0]) < 0.15 and float(worst[1]) < 0.15, "the hand mount is on this step's hand straight after a run step (spear %.2f m, axe %.2f m; 0.11 m is its grip)" % [worst[0], worst[1]])
	rig.queue_free()


func _init() -> void:
	_server()
	await _client()
	await _check_lossy(1750, 800)    # a burst of lost batches mid-walk
	await _check_lossy(3000, 3500)   # the stop inside the burst: it walks on a little, then is eased back to the last point
	await _check_holds()
	await _check_hand_follows()
	await _check_far_pose()
	print("test_remote_players: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
