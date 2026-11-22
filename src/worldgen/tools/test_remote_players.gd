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

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


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
	players.send_rows = func(peer, ids, positions, yaws, states, held, times): sent.append([peer, ids, positions, yaws, states, held, times])
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

	looks.clear()
	players.worn_changed(2, PackedInt32Array([5, 0, 9]))
	check(looks.is_empty(), "the same worn pieces send nothing")
	fake.worn[2] = [6, 0, 9]
	players.worn_changed(2, PackedInt32Array([6, 0, 9]))
	check(looks.size() == 2, "new worn pieces go to the others (%d)" % looks.size())

	fake.pos.erase(2)
	players.forget(2)
	sent.clear()
	clock[0] = 2700
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
	check(moved > 0.6 and moved <= 4.2 + 0.01, "the body walked between its sent points (%.2f m of 4.2)" % moved)

	if DynastyBodyScript.available():
		var clip: String = str(body["rig"].current())
		check(clip in ["walk", "jog", "walk_torch", "jog_torch"], "walking plays a gait clip (%s)" % clip)

	view.on_rows(PackedInt32Array(), PackedVector3Array(), PackedFloat32Array(), PackedByteArray(), PackedInt32Array(), PackedInt32Array())
	check(view.drawn_count() == 0, "a player out of range is removed")
	view.on_rows(PackedInt32Array([7]), PackedVector3Array([at]), PackedFloat32Array([0.0]), PackedByteArray([2 | PlayerViewScript.SWIM]), PackedInt32Array([0]), PackedInt32Array([t0 + 3000]))
	check(view.drawn_count() == 1, "and drawn again when back in range")

	for i in range(5):
		await process_frame

	if DynastyBodyScript.available() and view._bodies.has(7):
		var swim_clip: String = str(view._bodies[7]["rig"].current())
		check(swim_clip.begins_with("swim"), "a swimming player plays the swim clip (%s)" % swim_clip)


func _init() -> void:
	_server()
	await _client()
	print("test_remote_players: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
