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
#   CUE_HURT  detail = the health lost: an attack landed on the player (server_items.gd hurt_player), a gasp at the head; never held back by
#             the gap (the server's own news, not a client's request)
#   CUE_DRINK detail 0: a mouthful of water went down (at the edge, or from a waterskin or other vessel: the body's water rose), at the mouth
#   CUE_PICKUP detail = the item number: a loose thing taken up off the ground (the thing went), where it lay
# CUE_HURT, CUE_DRINK and CUE_PICKUP were added on 23 Nov 2026 (the coordinator: what only the doer heard) under the same number, as CUE_STORE.
# Eating, and drinking food from the pack (juice, tea), send nothing: they are silent for the eater too (Dave 17 Nov 2026: "doesnt need sound
# for eating remove the sound").
# Digging, filling and the hoe are heard already (every client hears the ground edits: dig_sounds.gd), as are animal hits (animal_hit,
# protocol 96), the chopping block, the saws and the bellows (world state). A swing at nothing makes no sound for its own player either.
# Cost: one distance test per connected player per cue, a few cues a second per working player.
# Animals hear the loud ones too (hearing-range pass, 23 Nov 2026, docs/SOUND_MAP.md "Who hears what, how far"): a blow on wood, stone or
# ground, a cry of pain, craft work and a shovel's dig mark the player loud for LOUD_HOLD_MS (loud_kinds), and server_animals senses them farther for it
# (animals.json senses.action_heard_x), whatever their stance or cover. Nothing more is sent: the animals read it on their own noise sample.

const Net := preload("res://src/stream/terrain_net.gd")

const CUE_BLOW := 1
const CUE_PICK := 2
const CUE_CRAFT := 3
const CUE_STORE := 4
const CUE_HURT := 5
const CUE_DRINK := 6
const CUE_PICKUP := 7
const HURT_MIN := 4                                               # inventory_view.gd HURT_MIN: a smaller loss is a drain, not a blow
const HEAD_UP_M := 0.6                                            # the mouth, above the body's middle
const STORE_OPEN := 0
const STORE_CLOSE := 1
const STORE_PUT := 2
const STORE_TAKE := 3
const STORE_LID := 4                                              # added to the op: a chest's lid creaks open and shut; a barrel, crate, basket or station store only sounds its contents
const MATERIALS := ["wood", "stone", "soil", "ground", "brush", "flesh"]   # ground: the client hears rock or soil under the point; brush: a bush (wood, softer); flesh: a knife on a carcass
const HEAR_M := {CUE_BLOW: 60.0, CUE_PICK: 30.0, CUE_CRAFT: 25.0, CUE_STORE: 25.0, CUE_HURT: 30.0, CUE_DRINK: 10.0, CUE_PICKUP: 12.0}   # hit_sounds unit 8 m (a blow at 60 m is about 18 dB under one at 8 m); harvest 40 m reach; craft work and a chest are quiet; a cry of pain carries; a gulp and a stick picked up are close sounds
const GAP_MS := 120                                               # at most about eight cues a second from one player
const CRAFT_EVERY_MS := 4500                                      # a craft work clip lasts about 4.5 s (item_sounds.gd watch starts the next as one ends)
const HANDS_UP_M := 0.3                                           # position_of is the body's middle; the hands work a little above it
const HANDS_OUT_M := 0.8                                          # and in front
const MINE_POINT_M := 6.0                                         # a blow on the ground farther than this from the player is not its own (server_items MINE_REACH_M 4.5, plus the drift between reports)
const LOUD_HOLD_MS := 5000                                        # a player stays loud to animals this long after a loud cue (a craft's work cue comes every CRAFT_EVERY_MS)
const LOUD_RANK := {"blow": 3, "hurt": 2, "dig": 2, "craft": 1}   # loudest first, as animals.json senses.action_heard_x orders them (test_hearing_ranges); hurt and dig tie
const LOUD_NAMES := {CUE_BLOW: "blow", CUE_CRAFT: "craft", CUE_HURT: "hurt"}   # the cues animals hear (animals.json senses.action_heard_x); a pick, a chest, a gulp, a pickup and a knife cut are quiet

var items                          # ServerItems: peer_ids, position_of, held_number, table, struct_kind_of, item_pos_of, open_store_of, store_total, body_water_of, loose_item_of, inventory_of
var yaw_of: Callable = func(_peer: int) -> float: return 0.0      # the body's facing (server_players.gd), for a blow with no point of its own
var send_cue: Callable             # (to peer, about peer, cue, detail, at)
var now_ms: Callable = func() -> int: return Time.get_ticks_msec()
var sent: int = 0                  # cues sent (one per receiver), for checks

var _last_ms: Dictionary = {}      # peer -> ms of its last cue
var _craft: Dictionary = {}        # peer -> [recipe, ms of its last craft cue]
var _loud: Dictionary = {}         # peer -> {loud name: ms it ends}


# A pack action came in (terrain_server.gd, before items.action): a blow names its cue from what it struck.
func note_action(peer: int, kind: int, a: int, b: int, _count: int, at: Vector3) -> void:
	if kind in [Net.ACT_HIT, Net.ACT_HIT_SHRUB] or (kind == Net.ACT_MINE and b == 0):
		_mark_loud(peer, "blow")   # before the gap: a blow struck just after a quiet cue (a pick, a pickup) is still heard by the animals

	if kind not in [Net.ACT_HIT, Net.ACT_PROCESS, Net.ACT_HIT_SHRUB, Net.ACT_MINE] or not _due(peer):
		return   # nothing to hear, or too soon after its last cue: no pack scan for a flood

	var material: String = ""

	match kind:
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


# A pack action (terrain_server.gd, around items.action): what the thing it names was before it, [] for an action this does not hear after.
# after_action hears only what the server let through: an open of a locked or far chest, a put into a take-only store or a wall, a put or
# take that moved nothing, a drink refused (no water near, full), a pickup out of reach or of a thing too heavy, are heard as nothing.
func before_action(peer: int, kind: int, a: int, b: int) -> Array:
	if items == null:
		return []

	if kind in [Net.ACT_DIG, Net.ACT_FILL, Net.ACT_DIG_TRENCH]:
		_mark_loud(peer, "dig")   # a shovel's bite, heard by animals (every client hears the edit itself: dig_sounds.gd); taken on the try, a refused one too
		return []

	if kind in [Net.ACT_CHEST_OPEN, Net.ACT_CHEST_PUT, Net.ACT_CHEST_TAKE, Net.ACT_CHEST_CLOSE]:
		return [int(items.open_store_of(peer)), int(items.store_total(b)) if kind in [Net.ACT_CHEST_PUT, Net.ACT_CHEST_TAKE] else -1]

	if kind == Net.ACT_DRINK or (kind == Net.ACT_EAT and _water_vessel(peer, a)):
		return [float(items.body_water_of(peer))]

	if kind == Net.ACT_PICKUP:
		return items.loose_item_of(a)

	return []


func after_action(peer: int, kind: int, a: int, b: int, before: Array) -> void:
	if before.is_empty() or items == null:
		return

	match kind:
		Net.ACT_CHEST_OPEN:
			if a > 0 and int(items.open_store_of(peer)) == a and int(before[0]) != a:
				_store_cue(peer, a, STORE_OPEN)   # let in (a second open of the window already open is no new creak)
		Net.ACT_CHEST_CLOSE:
			if int(before[0]) > 0 and int(items.open_store_of(peer)) != int(before[0]):
				_store_cue(peer, int(before[0]), STORE_CLOSE)
		Net.ACT_CHEST_PUT, Net.ACT_CHEST_TAKE:
			if b > 0 and int(before[1]) >= 0 and int(items.store_total(b)) != int(before[1]):
				_store_cue(peer, b, STORE_PUT if kind == Net.ACT_CHEST_PUT else STORE_TAKE)
		Net.ACT_EAT, Net.ACT_DRINK:
			var here: Variant = items.position_of(peer)

			if float(before[0]) >= 0.0 and float(items.body_water_of(peer)) > float(before[0]) and here != null:
				cue(peer, CUE_DRINK, 0, (here as Vector3) + Vector3(0.0, HEAD_UP_M, 0.0))
		Net.ACT_PICKUP:
			var now: Array = items.loose_item_of(a)

			if now.is_empty() or int(now[1]) < int(before[1]):
				cue(peer, CUE_PICKUP, int(before[0]), before[2])   # where it lay (the server checked the reach)


# Whether pack slot `slot` of `peer` holds a water vessel (items.json capacity_ml): eating from it is a mouthful of water (server_items _eat).
func _water_vessel(peer: int, slot: int) -> bool:
	var inv = items.inventory_of(peer)

	if inv == null or items.table == null or slot < 0 or slot >= inv.slot_count or inv.numbers[slot] == 0:
		return false

	return int(items.table.entry(items.table.id_of(inv.numbers[slot])).get("capacity_ml", 0)) > 0


# An attack landed on `peer` (server_items.gd hurt_player, through hurt_heard): the others near hear the gasp at its head. Not paced by the
# gap: a bite is the server's news, and a blow struck just before must not swallow it.
func hurt(peer: int, lost: float) -> void:
	var here: Variant = items.position_of(peer) if items != null else null

	if lost >= HURT_MIN and here != null:
		cue(peer, CUE_HURT, clampi(int(lost), 0, 1000), (here as Vector3) + Vector3(0.0, HEAD_UP_M, 0.0), false)


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

	var lid: bool = kind.contains("chest")

	if not lid and op <= STORE_CLOSE:
		return   # a barrel, crate or station store opening makes no sound of its own: nothing to send

	cue(peer, CUE_STORE, op + (STORE_LID if lid else 0), (lies as Vector3) + Vector3(0.0, HANDS_UP_M, 0.0))


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
func cue(peer: int, kind: int, detail: int, at: Vector3, paced: bool = true) -> bool:
	if LOUD_NAMES.has(kind) and not (kind == CUE_BLOW and detail % 8 == MATERIALS.find("flesh")):
		_mark_loud(peer, str(LOUD_NAMES[kind]))   # even when held back by the gap: the work was done

	if not send_cue.is_valid() or items == null or not HEAR_M.has(kind) or not at.is_finite():
		return false

	if paced and not _due(peer):
		return false

	if paced:
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


# `peer` did something loud (`name`, a LOUD_RANK key): it stays loud for that LOUD_HOLD_MS. Each name keeps its own end, and the loudest
# one still sounding counts (loud_kinds): a cry between two axe blows keeps the blow's reach, and crafting after one blow is craft work
# once that blow's 5 s are up.
func _mark_loud(peer: int, name: String) -> void:
	var ends: Dictionary = _loud.get(peer, {})
	ends[name] = int(now_ms.call()) + LOUD_HOLD_MS
	_loud[peer] = ends


# The loud thing each player did lately, in items.peer_ids order (server_items.peer_positions is the same order): the loudest LOUD_RANK
# name still sounding, or "" for none. server_animals reads it on its noise sample (player_loud).
func loud_kinds() -> Array:
	var out: Array = []

	for peer in (items.peer_ids() if items != null else []):
		out.append(loud_of(peer))

	return out


# The loudest LOUD_RANK name `peer` still sounds, or "" (the wolf packs ask by peer: server_wolves heard_of).
func loud_of(peer: int) -> String:
	var now: int = int(now_ms.call())
	var ends: Dictionary = _loud.get(peer, {})
	var best: String = ""

	for name in ends:
		if now < int(ends[name]) and (best == "" or int(LOUD_RANK.get(name, 0)) > int(LOUD_RANK.get(best, 0))):
			best = str(name)

	return best


func forget(peer: int) -> void:
	_last_ms.erase(peer)
	_craft.erase(peer)
	_loud.erase(peer)
