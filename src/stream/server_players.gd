extends RefCounted

# Other players (protocol 151, Dave 22 Nov 2026, the friends' play test: players could not see each other at all). The server keeps, per
# connected player, the look its client sent (my_look: the character's name, body model and body code, the creator's sliders, colours and hair)
# and the facing that came with each position report, and sends:
#   - player_look to everyone when a player's look or worn pieces change, and every known look to a player who just sent theirs;
#   - players rows, unreliable, about eight times a second: the other players within NEAR_M (nearest MAX_ROWS), each with its position,
#     facing, state byte (stance 0..3, +4 swimming, +8 a log on the shoulder, +16 asleep, bits 5..7 a count of its tool swings, so
#     others play the chop, pick or jab clip: no new field, an older client ignores the high bits), the item in the hand and the server ms
#     that position came in.
#     A receiver gets them only when one of its rows has news, or every RESEND_MS; the client draws each between sent points (motion_buffer.gd).
# Cost: one distance test per pair of players per send (32 players: about 1000 a send, 8000 a second), the per-player readings once a send.
# Nothing here acts on another player: no collision, no damage, no looting (robbery.enabled and player-versus-player rules are Dave's).

const SEND_S := 0.125
const NEAR_M := 150.0
const MAX_ROWS := 31
const RESEND_MS := 1000
const LOOK_GAP_MS := 1000          # at most one look a second per player
const NAME_MAX := 24               # character_record.gd NAME_MAX
const BODY_MAX := 32
const CODE_MAX := 400              # a body code (body_generator.gd encode) is well under 200 characters
const SWIM := 4
const CARRY := 8
const ASLEEP := 16
const SWING_SHIFT := 5             # bits 5..7: the player's swing count, mod 8
const SWING_ACTS := [7, 8, 9, 25, 27, 50, 57]   # terrain_net.gd ACT_HIT, ACT_MINE, ACT_PROCESS, ACT_DIG, ACT_FILL, ACT_TILL, ACT_HIT_SHRUB: a blow with the tool in hand

var items                          # ServerItems: peer_ids, position_of, stance_of, held_number, worn_of, is_swimming, carries_log, is_asleep
var send_rows: Callable            # (peer, ids PackedInt32Array, positions PackedVector3Array, yaws PackedFloat32Array, states PackedByteArray, held PackedInt32Array, times PackedInt32Array)
var send_look: Callable            # (to peer, about peer, name, body, code, worn PackedInt32Array)
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()

var _looks: Dictionary = {}        # peer -> [name, body, code]
var _yaw: Dictionary = {}          # peer -> facing (the body's rotation.y, radians)
var _report_ms: Dictionary = {}    # peer -> server ms of its latest position report
var _worn_sent: Dictionary = {}    # peer -> the worn numbers last told to everyone
var _look_ms: Dictionary = {}      # peer -> server ms of its last accepted look
var _sent: Dictionary = {}         # receiver -> [newest row ms sent, ids sent, ms sent]
var _swings: Dictionary = {}       # peer -> [swing count mod 8, server ms of the latest]
var _t: float = 0.0


# A player's look (my_look). Clipped, never trusted further: the receiving client decodes the code and falls back to a plain body.
func set_look(peer: int, char_name: String, body: String, code: String) -> void:
	var look: Array = [clean_name(char_name), body.left(BODY_MAX), code.strip_edges().left(CODE_MAX)]
	var now: int = int(now_ms.call())

	if _looks.get(peer, []) == look or now - int(_look_ms.get(peer, -LOOK_GAP_MS)) < LOOK_GAP_MS:
		return   # unchanged, or a second look within LOOK_GAP_MS (a client cannot flood everyone with reliable looks)

	_look_ms[peer] = now

	var first: bool = not _looks.has(peer)
	_looks[peer] = look
	_tell_all(peer)

	if first:
		for other in _looks:
			if other != peer:
				_tell(peer, other)


# A name for a Label3D: control characters (newlines, tabs) become spaces, trimmed, at most NAME_MAX.
static func clean_name(raw: String) -> String:
	raw = raw.left(NAME_MAX * 4)   # clipped first: a hostile client's very long name costs nothing (the loop below is per character)
	var out: String = ""

	for i in raw.length():
		var c: int = raw.unicode_at(i)
		out += " " if c < 32 or c == 127 else raw[i]

	return out.strip_edges().left(NAME_MAX)


func note_report(peer: int, yaw: float) -> void:
	_yaw[peer] = wrapf(yaw, -PI, PI) if is_finite(yaw) else 0.0
	_report_ms[peer] = int(now_ms.call())


# The worn pieces changed (server_items send_worn): everyone sees the new clothes.
func worn_changed(peer: int, numbers: PackedInt32Array) -> void:
	if _looks.has(peer) and _worn_sent.get(peer, null) != numbers:
		_tell_all(peer)


# A pack action came in (server_items action): a blow with the tool in hand counts a swing, so the others see it (the next rows).
func note_action(peer: int, kind: int) -> void:
	if kind in SWING_ACTS:
		var count: int = int((_swings.get(peer, [0, 0]) as Array)[0])
		_swings[peer] = [(count + 1) & 7, int(now_ms.call())]


func forget(peer: int) -> void:
	_swings.erase(peer)
	_looks.erase(peer)
	_yaw.erase(peer)
	_report_ms.erase(peer)
	_worn_sent.erase(peer)
	_sent.erase(peer)
	_look_ms.erase(peer)


func look_of(peer: int) -> Array:
	return _looks.get(peer, [])


func tick(delta: float) -> void:
	_t += delta

	if _t < SEND_S or items == null or not send_rows.is_valid():
		return

	_t = 0.0
	var peers: Array = items.peer_ids()

	if peers.size() < 2 and _sent.is_empty():
		return

	var now: int = int(now_ms.call())
	var at: Dictionary = {}
	var info: Dictionary = {}

	for peer in peers:
		var pos: Variant = items.position_of(peer)

		if pos == null or not _looks.has(peer) or not _report_ms.has(peer):
			continue   # a player is shown once its look and its first facing report came in

		at[peer] = pos
		var swing: Array = _swings.get(peer, [0, 0])
		var state: int = clampi(int(items.stance_of(peer)), 0, 3) | (SWIM if items.is_swimming(peer) else 0) | (CARRY if items.carries_log(peer) else 0) \
				| (ASLEEP if items.is_asleep(peer) else 0) | (int(swing[0]) << SWING_SHIFT)
		info[peer] = [float(_yaw.get(peer, 0.0)), state, int(items.held_number(peer)), int(_report_ms[peer]), maxi(int(_report_ms[peer]), int(swing[1]))]

	for receiver in at:
		var rows: Array = rows_for(receiver, at)   # only a client that sent its look gets rows: one that never did (an old bot) could not draw them
		var ids: PackedInt32Array = PackedInt32Array()
		var newest: int = 0

		for row in rows:
			ids.append(int(row[0]))
			newest = maxi(newest, int(info[row[0]][4]))   # a new position or a swing is news

		var last: Array = _sent.get(receiver, [-1, PackedInt32Array(), -RESEND_MS])

		if newest <= int(last[0]) and ids == last[1] and now - int(last[2]) < RESEND_MS:
			continue

		if ids.is_empty() and (last[1] as PackedInt32Array).is_empty() and now - int(last[2]) < RESEND_MS * 5:
			continue   # nobody near, and the client was told so

		_sent[receiver] = [newest, ids, now]
		var positions: PackedVector3Array = PackedVector3Array()
		var yaws: PackedFloat32Array = PackedFloat32Array()
		var states: PackedByteArray = PackedByteArray()
		var held: PackedInt32Array = PackedInt32Array()
		var times: PackedInt32Array = PackedInt32Array()

		for row in rows:
			var one: Array = info[row[0]]
			positions.append(row[1])
			yaws.append(float(one[0]))
			states.append(int(one[1]))
			held.append(int(one[2]))
			times.append(int(one[3]))

		send_rows.call(receiver, ids, positions, yaws, states, held, times)

	for gone in _sent.keys():
		if not peers.has(gone):
			_sent.erase(gone)


# The others near `me`, nearest first, at most MAX_ROWS: [[peer, position], ...]. `at` is peer -> position of the players that can be shown.
static func rows_for(me: int, at: Dictionary) -> Array:
	var here: Variant = at.get(me, null)
	var out: Array = []

	if here == null:
		return out

	var reach2: float = NEAR_M * NEAR_M

	for peer in at:
		if peer == me:
			continue

		var d2: float = (at[peer] as Vector3).distance_squared_to(here)

		if d2 <= reach2:
			out.append([peer, at[peer], d2])

	out.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	return out.slice(0, MAX_ROWS)


func _tell_all(about: int) -> void:
	var numbers: PackedInt32Array = PackedInt32Array(items.worn_of(about)) if items != null else PackedInt32Array()
	_worn_sent[about] = numbers

	for peer in _looks:
		if peer != about:
			_tell(peer, about)


func _tell(to: int, about: int) -> void:
	if not send_look.is_valid():
		return

	var look: Array = _looks[about]
	var numbers: PackedInt32Array = _worn_sent.get(about, PackedInt32Array(items.worn_of(about)) if items != null else PackedInt32Array())
	send_look.call(to, about, str(look[0]), str(look[1]), str(look[2]), numbers)
