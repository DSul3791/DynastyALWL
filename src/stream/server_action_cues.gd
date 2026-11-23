extends RefCounted

# Other players' work heard where it happens (protocol 156, Dave 23 Nov 2026: sound "very broad and hard to pinpoint"; the coordinator: make
# other players' tool blows, swings and hits, gathering and crafting heard by players nearby). Each player's own client plays its own
# blows, picks and craft work at once; until now nobody else heard them. The server sends one small unreliable action_cue
# (who, cue, detail, where) to the other players within the cue's earshot. One player's cues are spaced at least GAP_MS apart (a sickle
# swing naming 40 grasses gives one cue), so a hostile or hitching client cannot flood its neighbours.
#   CUE_BLOW  detail = tool * 8 + material (tool 0 axe, 1 pick: held_item.gd _hit_tool; MATERIALS below): an axe or pick blow on a tree, log, stump, bush, boulder or the
#             ground, or a knife cut on a carcass (flesh, at the carcass)
#   CUE_PICK  detail = the flora species id (flora id >> 16): a plant gathered by hand or cut by a sickle or scythe
#   CUE_CRAFT detail = the recipe number: a craft is being worked, sent again every CRAFT_EVERY_MS while it goes on, as the crafter's own work
#             sound repeats (knapping, twine, carving and the rest; item_sounds.gd work_type)
#   CUE_STORE detail = op + 4 when the store has a lid (a chest kind): op 0 opened, 1 closed, 2 something put in, 3 taken out (STORE_*), at
#             the container (23 Nov 2026, the coordinator's silent-sounds pass: only the one at a chest heard its lid and its contents). A
#             client from before CUE_STORE plays nothing for a cue it does not know (sound_stage.gd other_action), so no protocol change.
# Digging, filling and the hoe are heard already (every client hears the ground edits: dig_sounds.gd), as are animal hits (animal_hit,
# protocol 96), the chopping block, the saws and the bellows (world state). A swing at nothing makes no sound for its own player either.
# Cost: one distance test per connected player per cue, a few cues a second per working player.

const Net := preload("res://src/stream/terrain_net.gd")

const CUE_BLOW := 1
const CUE_PICK := 2
const CUE_CRAFT := 3
const CUE_STORE := 4
const STORE_OPEN := 0
const STORE_CLOSE := 1
const STORE_PUT := 2
const STORE_TAKE := 3
const STORE_LID := 4                                              # added to the op: a chest's lid creaks open and shut; a barrel, crate, basket or station store only sounds its contents
const MATERIALS := ["wood", "stone", "soil", "ground", "brush", "flesh"]   # ground: the client hears rock or soil under the point; brush: a bush (wood, softer); flesh: a knife on a carcass
const HEAR_M := {CUE_BLOW: 60.0, CUE_PICK: 30.0, CUE_CRAFT: 25.0, CUE_STORE: 25.0}   # hit_sounds unit 8 m (a blow at 60 m is about 18 dB under one at 8 m); harvest 40 m reach; craft work and a chest are quiet
const GAP_MS := 120                                               # at most about eight cues a second from one player
const CRAFT_EVERY_MS := 4500                                      # a craft work clip lasts about 4.5 s (item_sounds.gd watch starts the next as one ends)
const HANDS_UP_M := 0.3                                           # position_of is the body's middle; the hands work a little above it
const HANDS_OUT_M := 0.8                                          # and in front
const MINE_POINT_M := 6.0                                         # a blow on the ground farther than this from the player is not its own (server_items MINE_REACH_M 4.5, plus the drift between reports)

var items                          # ServerItems: peer_ids, position_of, held_number, table, struct_kind_of, item_pos_of
var yaw_of: Callable = func(_peer: int) -> float: return 0.0      # the body's facing (server_players.gd), for a blow with no point of its own
var send_cue: Callable             # (to peer, about peer, cue, detail, at)
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()
var sent: int = 0                  # cues sent (one per receiver), for checks

var _last_ms: Dictionary = {}      # peer -> ms of its last cue
var _craft: Dictionary = {}        # peer -> [recipe, ms of its last craft cue]
var _store: Dictionary = {}        # peer -> the world id of the container it last opened (ACT_CHEST_CLOSE names none)


# A pack action came in (terrain_server.gd, before items.action): a blow names its cue from what it struck.
func note_action(peer: int, kind: int, a: int, b: int, _count: int, at: Vector3) -> void:
	if kind == Net.ACT_CHEST_OPEN:
		_store[peer] = a   # kept even when the cue is held back, so the close is heard where it was opened

	if kind not in [Net.ACT_HIT, Net.ACT_PROCESS, Net.ACT_HIT_SHRUB, Net.ACT_MINE, Net.ACT_CHEST_OPEN, Net.ACT_CHEST_PUT, Net.ACT_CHEST_TAKE, Net.ACT_CHEST_CLOSE] or not _due(peer):
		return   # nothing to hear, or too soon after its last cue: no pack scan for a flood

	var material: String = ""

	match kind:
		Net.ACT_CHEST_OPEN:
			_store_cue(peer, a, STORE_OPEN)
			return
		Net.ACT_CHEST_CLOSE:
			_store_cue(peer, int(_store.get(peer, -1)), STORE_CLOSE)
			_store.erase(peer)
			return
		Net.ACT_CHEST_PUT:
			_store_cue(peer, b, STORE_PUT)
			return
		Net.ACT_CHEST_TAKE:
			_store_cue(peer, b, STORE_TAKE)
			return
		Net.ACT_HIT:
			material = "stone" if b == Net.HIT_BOULDER else "wood"
		Net.ACT_PROCESS:
			if items != null and items.struct_kind_of(a) == "carcass":
				var lies: Variant = items.item_pos_of(a)

				if lies != null and items.position_of(peer) != null and (lies as Vector3).distance_to(items.position_of(peer)) <= MINE_POINT_M:
					cue(peer, CUE_BLOW, MATERIALS.find("flesh"), (lies as Vector3) + Vector3(0.0, HANDS_UP_M, 0.0))   # the knife's cut, where the carcass lies

				return
			material = "wood"
		Net.ACT_HIT_SHRUB:
			material = "brush"
		Net.ACT_MINE:
			if b != 0:
				return   # struck nothing (protocol 118)
			material = "ground"
		_:
			return

	var point: Variant = at if kind == Net.ACT_MINE else _hands(peer)
	var here: Variant = items.position_of(peer) if items != null else null

	if point == null or here == null or (kind == Net.ACT_MINE and (not at.is_finite() or (here as Vector3).distance_to(at) > MINE_POINT_M)):
		return   # a client may not set a blow ringing anywhere it likes

	cue(peer, CUE_BLOW, tool_of(peer) * 8 + MATERIALS.find(material), point)


# A container opened, shut, filled or emptied by `peer`: heard at the container when it is a placed one near the player (a worn bag, id
# below 0, is the player's own back: nothing for others).
func _store_cue(peer: int, id: int, op: int) -> void:
	if id < 0 or items == null:
		return

	var kind: String = str(items.struct_kind_of(id))
	var lies: Variant = items.item_pos_of(id)
	var here: Variant = items.position_of(peer)

	if kind == "" or lies == null or here == null or (lies as Vector3).distance_to(here) > MINE_POINT_M:
		return   # not a placed container, or not beside the player (a client may not set a lid creaking anywhere)

	cue(peer, CUE_STORE, op + (STORE_LID if kind.contains("chest") else 0), (lies as Vector3) + Vector3(0.0, HANDS_UP_M, 0.0))


# The tool the blow was made with (0 axe, 1 pick): a pick rings as a pick, anything else as an axe (held_item.gd _hit_tool).
func tool_of(peer: int) -> int:
	if items == null or items.table == null:
		return 0

	var number: int = int(items.held_number(peer))
	return 1 if number != 0 and str(items.table.entry(items.table.id_of(number)).get("tool_class", "")) == "pick" else 0


# Where a player's hands are: the body's middle, a little up and out in front along its facing. null when it is not known.
func _hands(peer: int) -> Variant:
	var pos: Variant = items.position_of(peer) if items != null else null

	if pos == null:
		return null

	var yaw: float = float(yaw_of.call(peer))
	return (pos as Vector3) + Vector3(-sin(yaw) * HANDS_OUT_M, HANDS_UP_M, -cos(yaw) * HANDS_OUT_M)


# `peer`'s craft is being worked this tick (server_items.gd _craft_tick, about four times a second): heard at its hands when it begins and
# every CRAFT_EVERY_MS after, while it goes on. A cue held back by the gap is tried again on the next tick.
func craft_working(peer: int, recipe: int) -> void:
	var last: Array = _craft.get(peer, [0, -100000])

	if int(last[0]) == recipe and int(now_ms.call()) - int(last[1]) < CRAFT_EVERY_MS:
		return

	var point: Variant = _hands(peer)

	if point != null and cue(peer, CUE_CRAFT, recipe, point):
		_craft[peer] = [recipe, int(now_ms.call())]


# Send one cue about `peer` to every other player within the cue's earshot of `at`. False when held back (too soon after its last, or unknown).
func cue(peer: int, kind: int, detail: int, at: Vector3) -> bool:
	if not send_cue.is_valid() or items == null or not HEAR_M.has(kind) or not at.is_finite():
		return false

	if not _due(peer):
		return false

	_last_ms[peer] = int(now_ms.call())
	var reach: float = float(HEAR_M[kind])

	for other in items.peer_ids():
		if other == peer:
			continue   # its own client played it already

		var pos: Variant = items.position_of(other)

		if pos != null and (pos as Vector3).distance_to(at) <= reach:
			send_cue.call(other, peer, kind, detail, at)
			sent += 1

	return true


# Whether `peer` may send a cue now (GAP_MS since its last).
func _due(peer: int) -> bool:
	return int(now_ms.call()) - int(_last_ms.get(peer, -100000)) >= GAP_MS


func forget(peer: int) -> void:
	_last_ms.erase(peer)
	_craft.erase(peer)
	_store.erase(peer)
