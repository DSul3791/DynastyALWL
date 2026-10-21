extends Node

# The terrain messages between server and client (plan step 16). The same
# node sits at the same path in both scenes ("Main/TerrainNet"), which is
# what Godot's RPCs need. Each side connects to the signals it uses.
#
#   server -> client  welcome          world identity, tile revisions, spawn point
#   client -> server  request_blocks   block keys wanted; the first `urgent`
#                                      ones are needed now, the rest are
#                                      prefetch (neighbors likely needed soon)
#   server -> client  deliver_blocks   block keys and their compressed bytes
#   server -> client  tile_changed     a tile's new revision after an edit
#   client -> server  dig              ask the server to remove a sphere of ground (test edit)
#   server -> client  dug              a sphere of ground was removed: apply it to loaded terrain
#   client -> server  request_flora    flora chunks wanted (chunk x, z, 1 full or 0 trees only)
#   server -> client  deliver_flora    one chunk's flora (FloraPlacer.encode, removals applied), and whether full
#                                      and its rivers and lakes (WaterGrid.encode, empty if dry)
#   client -> server  report_position  where the player is and how fast it moves (a few times a second),
#                                      so the server makes the ground ahead of and under them first
#   client -> server  cut_flora        remove one flora item (test harvest)
#   server -> client  flora_cut        a flora item was removed
#   client -> server  hello             the player's key, once after the welcome (inventory belongs to the key)
#   client -> server  inventory_action  move, drop, pick up or (admin) give: the server checks everything
#   server -> client  inventory_full    the whole inventory, at hello only
#   server -> client  inventory_slots   the slots that changed (slot, item number, count)
#   server -> client  world_items       items lying near the player: added ones and removed ids
#
# A block key is four ints: block x, y, z (in 16-voxel blocks at its LOD)
# and the LOD.

const PROTOCOL_VERSION := 26

signal welcome_received(info: Dictionary)
signal blocks_requested(peer_id: int, keys: PackedInt32Array, urgent: int)
signal blocks_received(keys: PackedInt32Array, payloads: Array)
signal tile_changed_received(tile: Vector2i, revision: int)
signal dig_requested(peer_id: int, center: Vector3, radius: float)
signal dug_received(center: Vector3, radius: float)
signal flora_requested(peer_id: int, chunks: PackedInt32Array)
signal flora_received(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray, full: bool)
signal position_reported(peer_id: int, position: Vector3, velocity: Vector3)
signal cut_flora_requested(peer_id: int, chunk: Vector2i, id: int)
signal flora_cut_received(chunk: Vector2i, id: int)
signal water_rate_requested(peer_id: int, direction: int)
signal water_rate_received(rate: float, busy: bool, spring_m3_s: float)
signal water_changed_received()
signal ground_reset_received(tiles_stamp: String, starter_stamp: String)
signal water_requested(peer_id: int, chunks: PackedInt32Array)
signal water_received(chunk: Vector2i, water: PackedByteArray)
signal notice_received(text: String)
signal chest_received(id: int, bytes: PackedByteArray)
signal vitals_received(hunger: int, health: int, weight_dkg: int, thirst: int, luck: int, fitness: int)
signal reject_received(reason: int)
signal craft_queue_received(entries: Array, left_ms: int)
signal strain_received(strain_pm: int, state: int, fade_pm: int, stance: int)
signal hello_requested(peer_id: int, player_key: String)
signal inventory_action_requested(peer_id: int, kind: int, a: int, b: int, count: int, at: Vector3)
signal inventory_full_received(bytes: PackedByteArray)
signal inventory_slots_received(bytes: PackedByteArray)
signal world_items_received(added: Array, removed: PackedInt32Array)

# inventory_action kinds
const ACT_MOVE := 0       # a = from slot, b = to slot
const ACT_DROP := 1       # a = slot, count = how many, at = where it lands
const ACT_PICKUP := 2     # a = world item id
const ACT_ADMIN_GIVE := 3 # a = item number, count (admin tool; tests only)
const ACT_CRAFT := 4      # a = recipe number (data/items/recipes.json)
const ACT_PLACE := 6      # a = slot of a placeable item, at = where (a campfire kit becomes a fire)
const ACT_MINE := 8       # at = the point the axe struck; on bare rock the server gives stone
const ACT_HIT := 7        # a = tree id, b = flora chunk x, count = flora chunk z: one axe blow on a standing tree
const ACT_PROCESS := 9    # a = world item id of a felled trunk: one axe blow on it gives branches, leaves, bark, logs
const ACT_SPLIT := 10     # a = slot, count = how many go to the first empty slot
const ACT_DRINK := 24         # no arguments: drink from the water at the player's feet (the server checks water within reach)
const ACT_FALL := 23          # a = the drop in centimetres the client landed from (only sent from the sound threshold, 6 m); the server decides the damage
const ACT_CRAFT_CANCEL := 22 # a = queue entry index (as last sent): cancel it and get its ingredients back
const ACT_CRAFT_QUEUE := 21  # a = recipe number, count = how many (1 to 20): queue crafts; ingredients are taken now
const ACT_STANCE := 20     # a = wanted stance: 0 stand, 1 crouch, 2 sit, 3 lie; the server answers in strain()
const ACT_LIGHT := 19      # a = fire world id: light a loaded fire (uses tinder from the pack, see cooking.json)
const ACT_EAT := 18        # a = pack slot: eat the food or apply the medicine in it (data/items/vitals.json)
const ACT_USE_STRUCT := 17  # a = structure world id: use it (a chopping block splits one log into firewood)
const ACT_CHEST_OPEN := 14 # a = chest world id: the server answers with chest_contents
const ACT_CHEST_PUT := 15  # a = pack slot, b = chest world id, count = how many to put in
const ACT_CHEST_TAKE := 16 # a = chest slot, b = chest world id, count = how many to take out
const ACT_REPAIR := 13    # a = slot of a worn or broken tool: spend its repair materials, win back half its durability
const ACT_FUEL := 11      # a = fire world id: burn one stick (or a log) in the fire
const ACT_COOK := 12      # a = fire world id: roast one raw forage item at the fire
const ACT_THROW := 5      # a = slot, at = aim direction (the server starts the throw from the player)


@rpc("authority", "call_remote", "reliable")
func welcome(info: Dictionary) -> void:
	welcome_received.emit(info)


@rpc("any_peer", "call_remote", "reliable")
func request_blocks(keys: PackedInt32Array, urgent: int) -> void:
	if multiplayer.is_server() and keys.size() % 4 == 0:
		blocks_requested.emit(multiplayer.get_remote_sender_id(), keys, clampi(urgent, 0, keys.size() / 4))


@rpc("authority", "call_remote", "reliable")
func deliver_blocks(keys: PackedInt32Array, payloads: Array) -> void:
	blocks_received.emit(keys, payloads)


@rpc("authority", "call_remote", "reliable")
func tile_changed(tile: Vector2i, revision: int) -> void:
	tile_changed_received.emit(tile, revision)


@rpc("any_peer", "call_remote", "reliable")
func dig(center: Vector3, radius: float) -> void:
	if multiplayer.is_server():
		dig_requested.emit(multiplayer.get_remote_sender_id(), center, clampf(radius, 0.5, 8.0))


@rpc("authority", "call_remote", "reliable")
func dug(center: Vector3, radius: float) -> void:
	dug_received.emit(center, radius)


@rpc("any_peer", "call_remote", "reliable")
func request_flora(chunks: PackedInt32Array) -> void:
	if multiplayer.is_server() and chunks.size() % 3 == 0:
		flora_requested.emit(multiplayer.get_remote_sender_id(), chunks)


@rpc("authority", "call_remote", "reliable")
func deliver_flora(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray, full: bool) -> void:
	flora_received.emit(chunk, bytes, water, full)


@rpc("any_peer", "call_remote", "reliable")
func cut_flora(chunk: Vector2i, id: int) -> void:
	if multiplayer.is_server():
		cut_flora_requested.emit(multiplayer.get_remote_sender_id(), chunk, id)


@rpc("authority", "call_remote", "reliable")
func flora_cut(chunk: Vector2i, id: int) -> void:
	flora_cut_received.emit(chunk, id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func report_position(position: Vector3, velocity: Vector3) -> void:
	if multiplayer.is_server():
		position_reported.emit(multiplayer.get_remote_sender_id(), position, velocity.limit_length(2000.0))


# A player pressed + (1) or - (-1): step the flow rate of all water.
@rpc("any_peer", "call_remote", "reliable")
func step_water_rate(direction: int) -> void:
	if multiplayer.is_server():
		water_rate_requested.emit(multiplayer.get_remote_sender_id(), clampi(direction, -1, 1))


@rpc("authority", "call_remote", "reliable")
func water_rate(rate: float, busy: bool, spring_m3_s: float) -> void:
	water_rate_received.emit(rate, busy, spring_m3_s)


# The server's water has new levels: clients ask again for the chunks they hold.
@rpc("authority", "call_remote", "reliable")
func water_changed() -> void:
	water_changed_received.emit()


# The tile files changed (a bake finished): the server threw its generated ground
# away; clients drop their saved copy and load the ground again.
@rpc("authority", "call_remote", "reliable")
func ground_reset(tiles_stamp: String, starter_stamp: String) -> void:
	ground_reset_received.emit(tiles_stamp, starter_stamp)


@rpc("any_peer", "call_remote", "reliable")
func request_water(chunks: PackedInt32Array) -> void:
	if multiplayer.is_server() and chunks.size() % 2 == 0 and chunks.size() <= 4000:
		water_requested.emit(multiplayer.get_remote_sender_id(), chunks)


@rpc("authority", "call_remote", "reliable")
func deliver_water(chunk: Vector2i, water: PackedByteArray) -> void:
	water_received.emit(chunk, water)



@rpc("any_peer", "call_remote", "reliable")
func hello(player_key: String) -> void:
	if multiplayer.is_server() and player_key.length() <= 64:
		hello_requested.emit(multiplayer.get_remote_sender_id(), player_key)


@rpc("any_peer", "call_remote", "reliable")
func inventory_action(kind: int, a: int, b: int, count: int, at: Vector3) -> void:
	if multiplayer.is_server():
		inventory_action_requested.emit(multiplayer.get_remote_sender_id(), kind, a, b, count, at)


@rpc("authority", "call_remote", "reliable")
func inventory_full(bytes: PackedByteArray) -> void:
	inventory_full_received.emit(bytes)


@rpc("authority", "call_remote", "reliable")
func inventory_slots(bytes: PackedByteArray) -> void:
	inventory_slots_received.emit(bytes)


# added: [[id, item number, count, position, state, extra], ...] (state 0 item, 1 lit fire, 2 burnt-out fire,
# 3 felled trunk, 4 stump; extra: Dictionary with species, yaw, length, radius for states 3 and 4); removed: ids
@rpc("authority", "call_remote", "reliable")
func world_items(added: Array, removed: PackedInt32Array) -> void:
	world_items_received.emit(added, removed)


# An action the server refused, so the client can play a cue: 0 too far, 1 no tool, 2 pack full (too heavy), 3 other.
@rpc("authority", "call_remote", "reliable")
func reject(reason: int) -> void:
	reject_received.emit(reason)


# The player's crafting queue (server side, keeps running with the screen closed): entries [[recipe number, crafts
# left], ...] head first, and the milliseconds left on the head craft. Sent on every change and at hello.
@rpc("authority", "call_remote", "reliable")
func craft_queue(entries: Array, left_ms: int) -> void:
	craft_queue_received.emit(entries, left_ms)


# Over-exertion (data/items/exertion.json): strain in thousandths (1000 = over-exerted), state 0 normal,
# 1 over-exerted, 2 fainted, 3 waking, fade in thousandths of the faint or wake time gone (state 2: 0 to 1000
# as vision then heartbeat fade out; state 3: 1000 down to 0 as they return). stance is the server's answer: 0 stand,
# 1 crouch, 2 sit, 3 lie (fainting forces 3; it also stands a sitting or lying player who walks off).
@rpc("authority", "call_remote", "reliable")
func strain(strain_pm: int, state: int, fade_pm: int, stance: int) -> void:
	strain_received.emit(strain_pm, state, fade_pm, stance)


# The player's hunger (stomach percent), thirst (percent of a full body), luck (-10 to 10, fixed), health (points 0 to 100) and body weight (tenths of a kg) (at hello, after eating, and when a point changes).
@rpc("authority", "call_remote", "reliable")
func vitals(hunger: int, health: int, weight_dkg: int, thirst: int, luck: int, fitness: int) -> void:
	vitals_received.emit(hunger, health, weight_dkg, thirst, luck, fitness)


# The contents of a chest the player opened (30 slots in the inventory byte format).
@rpc("authority", "call_remote", "reliable")
func chest_contents(id: int, bytes: PackedByteArray) -> void:
	chest_received.emit(id, bytes)


# A short message for the player ("too many trunks lie here", and so on).
@rpc("authority", "call_remote", "reliable")
func notice(text: String) -> void:
	notice_received.emit(text)
