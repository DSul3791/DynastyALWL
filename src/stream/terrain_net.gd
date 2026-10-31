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
#   server -> client  vent             the nearest volcanic vent within 1500 m (x, y, z), or INF when none: the volcano rumble bed sits there
#   server -> client  zone             the biome id under the player (ambience slots): at login, after a teleport or respawn, and when it changes
#   server -> client  flora_fruit      fruit trees of a chunk: pieces taken from each this season (the prompt shows what is left)
#   server -> client  flora_stripped   plants of a chunk that are bare this season (berries picked): sent with a flora chunk and when one is picked
#   client -> server  hello             the player's key, once after the welcome (inventory belongs to the key)
#   client -> server  inventory_action  move, drop, pick up or (admin) give: the server checks everything
#   server -> client  inventory_full    the whole inventory, at hello only
#   server -> client  inventory_slots   the slots that changed (slot, item number, count)
#   server -> client  world_items       items lying near the player: added ones and removed ids
#
# A block key is four ints: block x, y, z (in 16-voxel blocks at its LOD)
# and the LOD.

const PROTOCOL_VERSION := 79

signal welcome_received(info: Dictionary)
signal blocks_requested(peer_id: int, keys: PackedInt32Array, urgent: int)
signal blocks_received(keys: PackedInt32Array, payloads: Array)
signal tile_changed_received(tile: Vector2i, revision: int)
signal dig_requested(peer_id: int, center: Vector3, radius: float)
signal dug_received(center: Vector3, radius: float)
signal filled_received(center: Vector3, radius: float, material: int)
signal flora_requested(peer_id: int, chunks: PackedInt32Array)
signal flora_received(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray, full: bool)
signal position_reported(peer_id: int, position: Vector3, velocity: Vector3)
signal cut_flora_requested(peer_id: int, chunk: Vector2i, id: int)
signal flora_cut_received(chunk: Vector2i, id: int)
signal flora_stripped_received(chunk: Vector2i, ids: PackedInt32Array)
signal flora_fruit_received(chunk: Vector2i, ids: PackedInt32Array, taken: PackedInt32Array)
signal zone_received(biome_id: int)
signal vent_received(at: Vector3)
signal water_rate_requested(peer_id: int, direction: int)
signal water_rate_received(rate: float, busy: bool, spring_m3_s: float)
signal water_changed_received()
signal pulse_received()
signal quake_received(stage: int, strength: float, point: Vector3)
signal leak_received(points: PackedVector3Array, closeness: PackedByteArray)
signal ground_reset_received(tiles_stamp: String, starter_stamp: String)
signal water_requested(peer_id: int, chunks: PackedInt32Array)
signal surface_requested(peer_id: int, x: float, z: float)
signal surface_received(x: float, z: float, y: float)
signal dump_requested(peer_id: int, x: float, y: float, z: float)
signal dump_received(text: String)
signal water_received(chunk: Vector2i, water: PackedByteArray)
signal shop_received(npc_id: String, title: String, ids: PackedStringArray, pay_milli: int, get_milli: int, buys: PackedStringArray, tired_ids: PackedStringArray, tired_milli: PackedInt32Array, stock: PackedInt32Array, supply_milli: PackedInt32Array, trader_purse: int)
signal trade_requested(peer_id: int, npc_id: String, kind: int, a: int, count: int)
signal purse_received(copper: int)
signal carry_received(item_id: String)
signal trails_received(block_x: int, block_z: int, bytes: PackedByteArray)
signal reputation_received(ids: PackedStringArray, names: PackedStringArray, points: PackedInt32Array)
signal item_received(item_id: String, count: int, source: String)
signal notice_received(text: String)
signal chest_received(id: int, bytes: PackedByteArray)
signal breath_received(deciseconds: int)
signal energy_received(percent: int)
signal sick_received(hours: int)
signal limp_received(percent: int)
signal body_received(bpm: int, eta_s: int, phase: int)
signal remains_received(rows: Array)
signal worn_received(numbers: PackedInt32Array)
signal npc_roster_received(rows: Array)
signal npcs_received(rows: Array)
signal animals_received(rows: Array)
signal blood_received(points: PackedVector3Array)
signal npc_talk_requested(peer_id: int, npc_id: String, choice: int)
signal npc_say_received(npc_id: String, npc_name: String, text: String, voice_id: String, choices: PackedStringArray, ends: bool)
signal admin_place_requested(peer_id: int, kind: String, pos: Vector3, arg: String)
signal thought_received(line_id: String, text: String, kind: String)
signal skills_received(attributes: PackedInt32Array, rows: Array)
signal warmth_received(percent: int)
signal died_received(cause: String, spawn: Vector3)
signal vitals_received(hunger: int, health: int, weight_dkg: int, thirst: int, luck: int, fitness: int)
signal reject_received(reason: int)
signal craft_queue_received(entries: Array, left_ms: int)
signal strain_received(strain_pm: int, state: int, fade_pm: int, stance: int)
signal hello_requested(peer_id: int, player_key: String)
signal logout_requested(peer_id: int)
signal tunnel_setting_requested(peer_id: int, on: bool, cave_in_s: int)
signal tunnel_settings_received(on: bool, cave_in_s: int)
signal start_at_received(position: Vector3)
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
const ACT_HIT := 7        # a = tree id, b = flora chunk x, count = flora chunk z: one axe blow on a standing tree; with b = HIT_BOULDER, a = a boulder's world id: one pick or axe blow on a boulder
const HIT_BOULDER := -1000000   # the b of an ACT_HIT that strikes a boulder, not a tree
const ACT_PROCESS := 9    # a = world item id of a felled trunk: one axe blow on it gives branches, leaves, bark, logs
const ACT_SPLIT := 10     # a = slot, count = how many go to the first empty slot
const ACT_DRINK := 24         # a = pack slot of a water container in hand, or -1: with a container that has room, fill it from the water at the player's feet; otherwise drink a mouthful (the server checks water within reach)
const ACT_FALL := 23          # a = the drop in centimetres the client landed from (only sent from the sound threshold, 6 m); the server decides the damage
const ACT_CRAFT_CANCEL := 22 # a = queue entry index (as last sent): cancel it and get its ingredients back
const ACT_CRAFT_QUEUE := 21  # a = recipe number, count = how many (1 to 20): queue crafts; ingredients are taken now
const ACT_SLEEP := 26      # a = 1 fall asleep (lying, held Z for 3 s), 0 wake; the sleeping flag comes back as bit 4 of the strain() stance
const ACT_FILL := 27       # at = the ground point under the crosshair: one spade fill (spends a shovelful of soil, sand, gravel, clay or stone from the pack)
const ACT_DIG := 25        # at = the ground point under the crosshair: one spade dig (server checks spade, reach, pace; DIGGING_DESIGN.md)
const ACT_STANCE := 20     # a = wanted stance: 0 stand, 1 crouch, 2 sit, 3 lie; the server answers in strain()
const ACT_LIGHT := 19      # a = fire world id: light a loaded fire (uses tinder from the pack, see cooking.json)
const ACT_EAT := 18        # a = pack slot: eat the food or apply the medicine in it (data/items/vitals.json)
const ACT_USE_STRUCT := 17  # a = structure world id: use it (a chopping block splits one log into firewood)
const ACT_CHEST_OPEN := 14 # a = chest world id: the server answers with chest_contents
const ACT_CHEST_PUT := 15  # a = pack slot, b = chest world id, count = how many to put in
const ACT_CHEST_TAKE := 16 # a = chest slot, b = chest world id, count = how many to take out
const ACT_ICEHOLE := 31   # a = slot of an axe or pick: one blow at the ice under you; the sixth opens a fishing hole
const ACT_FISH := 30      # a = slot of a fishing rod, at = where the cast lands (water): cast the line, and click again when it bites
const ACT_WEAR := 28      # a = pack slot: put on the clothing or gear in it (the piece it replaces goes to the pack)
const ACT_UNWEAR := 29    # a = body slot index (data/items/clothing.json slots): take that piece off into the pack
const ACT_REPAIR := 13    # a = slot of a worn or broken tool: spend its repair materials, win back half its durability
const ACT_FUEL := 11      # a = fire world id: burn one stick (or a log) in the fire
const ACT_COOK := 12      # a = fire world id: roast one raw forage item at the fire
const ACT_GATHER_EDGE := 54  # at = the player's spot: take sea water into a container, or the tide-line node of the cell (data/items/shore_nodes.json)
const ACT_TILL := 50       # at = the ground point: one hoe stroke tills a metre into a tilled bed (FARMING_SPEC.md step 2)
const ACT_SOW := 51        # a = the bed's world id, b = the pack slot of the seed (step 3)
const ACT_HARVEST := 52    # a = the bed's world id: E on a ripe crop (step 5)
const ACT_WATER_BED := 53  # a = the bed's world id: pours one `water` from the pack on it (step 4)
const ACT_HOE_PATH := 36     # at = the ground point under the crosshair: one hoe stroke treads a metre of path (clears grass, no height change)
const ACT_HOE_SMOOTH := 37   # at = the ground point under the crosshair: one hoe stroke moves ground from the high spots to the low spots within 1.5 m
const ACT_HOE_GRADE_POINT := 42   # a = 0 sets point A, 1 sets point B (the hoe grade line), at = the ground point: the server remembers the point for this player
const ACT_HOE_GRADE := 43    # at = the ground point under the crosshair: one hoe stroke brings the ground within 1.5 m toward the straight ramp from A to B (0.25 m at most, no items)
const ACT_SHOOT := 49          # a = pack slot of the bow, b = draw time in ms (clamped by the server), at = aim direction: one arrow from the first arrow item in the pack (data/items/bow.json; protocol 79, taken at merge)
const ACT_PLACE_BLUEPRINT := 48   # a = blueprint number (data/items/blueprints.json), b = lift steps, count = yaw degrees, at = the spot: placed from the hammer, the materials taken from the pack (no kit item)
const ACT_NET := 47          # a = pack slot of the shore net, b = 0 start (left button down), 1 cancel (let go), at = the water point in front: hold about 20 s at the water's edge, then 1 to 3 small fish (fishing.json "net"; no protocol change)
const ACT_NEW_PLAYER := 45   # admin only: this character starts over as a brand new player (empty pack, nothing worn, fresh vitals, Admin mode off); stays flagged so Admin mode is off at every login until switched on again (no protocol change)
const ACT_SHOWROOM := 44     # a = 0 fill the showroom, 1 clear it and fill again (admin only), at = the spawn point the rows in data/items/showroom.json are laid out from: real world items
const ACT_CHEST_CLOSE := 34  # the player closed the container window: the server stops pushing its contents
const ACT_LITTER := 33     # at = a dead branch lying on the forest floor within reach: one stick into the pack (the client hides that branch)
const ACT_STRIKE := 32     # a = slot of a weapon, at = aim direction: one jab at an animal in front (the server checks reach, pace and the weapon)
const ACT_CLEAR_DROPS := 38  # a = radius in metres (admin only): removes the loose dropped items within it of the player; no protocol change, just a new kind
const ACT_ADMIN_MODE := 39   # a = 1 on, 0 off (admin only): the Admin mode switch; while on, an admin crafts anything free (no protocol change)
const ACT_RESET_EDITS := 40  # admin only: delete every saved dig and fill (collapse rubble too) and reload the baked terrain for everyone
const ACT_DUMP_WATER := 41   # at = the point (admin only): the server writes the live water cells in a 40 m box there to a text file in its store
const ACT_LAND_TYPES := 46   # at = the point (admin only): the server classifies the land round it from the live water (lake, river, marsh, swamp, bog, floodplain), checks the springs near it and writes land_types_X_Z.txt (water land types, R1)
const ACT_THROW := 5      # a = slot, at = aim direction (the server starts the throw from the player)


@rpc("authority", "call_remote", "reliable")
func welcome(info: Dictionary) -> void:
	welcome_received.emit(info)


@rpc("any_peer", "call_remote", "reliable")
func request_blocks(keys: PackedInt32Array, urgent: int) -> void:
	if multiplayer.is_server() and keys.size() % 4 == 0:
		@warning_ignore("integer_division")
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


@rpc("authority", "call_remote", "reliable")
func filled(center: Vector3, radius: float, material: int) -> void:
	filled_received.emit(center, radius, material)


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


@rpc("authority", "call_remote", "reliable")
func flora_stripped(chunk: Vector2i, ids: PackedInt32Array) -> void:
	flora_stripped_received.emit(chunk, ids)


# Fruit trees: how many pieces were taken from each of these trees this season (sent with a flora chunk and after every pick).
@rpc("authority", "call_remote", "reliable")
func flora_fruit(chunk: Vector2i, ids: PackedInt32Array, taken: PackedInt32Array) -> void:
	flora_fruit_received.emit(chunk, ids, taken)


@rpc("authority", "call_remote", "reliable")
func zone(biome_id: int) -> void:
	zone_received.emit(biome_id)


@rpc("authority", "call_remote", "reliable")
func vent(at: Vector3) -> void:
	vent_received.emit(at)


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


# The server's heartbeat, four times a second (the client's connection indicator counts the silence between them).
@rpc("authority", "call_remote", "unreliable")
func pulse() -> void:
	pulse_received.emit()


# Earth shaking in an excavation that needs bracing (tech/EXCAVATION_BRACING_GROUND_DESIGN.md section 3): stage 2 creak, 3 shake,
# 4 throes (the collapse follows), strength 0..1000 per mille, point = the working cluster. The server sends it twice a second to
# players within 40 m of a cluster in stage 2 or later; nothing sends it yet (the tunnel timers are switched off until the bracing items exist).
# Dripping ceilings (protocol 73, Dave 2026-10-23): the ceiling points near the player with water within 4 m above them, nearest first
# (at most 24), and how close the water is (0..255). Twice a second, only while there are any. Drawn and heard on the client; no water is simulated.
@rpc("authority", "call_remote", "unreliable")
func leak(points: PackedVector3Array, closeness: PackedByteArray) -> void:
	leak_received.emit(points, closeness)


@rpc("authority", "call_remote", "unreliable")
func quake(stage: int, strength_pm: int, point: Vector3) -> void:
	quake_received.emit(stage, float(strength_pm) * 0.001, point)


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


# Protocol 45: where the ground is under a point, so a player who stopped high in the air has the ground
# column below them loaded first (the client puts its streaming viewer there).
@rpc("any_peer", "call_remote", "reliable")
func request_surface(x: float, z: float) -> void:
	if multiplayer.is_server() and is_finite(x) and is_finite(z):
		surface_requested.emit(multiplayer.get_remote_sender_id(), x, z)


# Protocol 56: what the server's stores hold for one voxel (debug button "Dump ground here").
@rpc("any_peer", "call_remote", "reliable")
func request_dump(x: float, y: float, z: float) -> void:
	if multiplayer.is_server() and is_finite(x) and is_finite(y) and is_finite(z):
		dump_requested.emit(multiplayer.get_remote_sender_id(), x, y, z)


@rpc("authority", "call_remote", "reliable")
func dump_result(text: String) -> void:
	dump_received.emit(text)


@rpc("authority", "call_remote", "reliable")
func surface(x: float, z: float, y: float) -> void:
	surface_received.emit(x, z, y)


@rpc("authority", "call_remote", "reliable")
func deliver_water(chunk: Vector2i, water: PackedByteArray) -> void:
	water_received.emit(chunk, water)



# A deliberate quit (Quit game, window close): sent before the connection ends. No such message = a disconnect (protocol 69).
@rpc("any_peer", "call_remote", "reliable")
func logout() -> void:
	if multiplayer.is_server():
		logout_requested.emit(multiplayer.get_remote_sender_id())


# Tunnel collapse switch (protocol 72, Dave 2026-10-23): an admin asks to turn it on or off and sets the cave-in duration (seconds, the
# server clamps to 120..1200); the server answers everyone with the settings now in force (also sent after hello).
@rpc("any_peer", "call_remote", "reliable")
func tunnel_setting(on: bool, cave_in_s: int) -> void:
	if multiplayer.is_server():
		tunnel_setting_requested.emit(multiplayer.get_remote_sender_id(), on, cave_in_s)


@rpc("authority", "call_remote", "reliable")
func tunnel_settings(on: bool, cave_in_s: int) -> void:
	tunnel_settings_received.emit(on, cave_in_s)


# Where this character resumes (protocol 69): sent after hello when the player has a saved place (their last spot, or the nearest
# rest or shelter after a long disconnect). Without it the player stays at the world spawn.
@rpc("authority", "call_remote", "reliable")
func start_at(position: Vector3) -> void:
	start_at_received.emit(position)


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
# 1 crouch, 2 sit, 3 lie (fainting forces 3; it also stands a sitting or lying player who walks off). Bit 4 (+4) = asleep (job 86).
@rpc("authority", "call_remote", "reliable")
func strain(strain_pm: int, state: int, fade_pm: int, stance: int) -> void:
	strain_received.emit(strain_pm, state, fade_pm, stance)


# The player's hunger (stomach percent), thirst (percent of a full body), luck (-10 to 10, fixed), health (points 0 to 100) and body weight (tenths of a kg) (at hello, after eating, and when a point changes).
@rpc("authority", "call_remote", "reliable")
func vitals(hunger: int, health: int, weight_dkg: int, thirst: int, luck: int, fitness: int) -> void:
	vitals_received.emit(hunger, health, weight_dkg, thirst, luck, fitness)


# The character died (protocol 34): what killed them, and where they come back. The server has already moved the pack onto
# remains, reset the vitals and put the player at the spawn point; the client fades out and in and moves the body there.
@rpc("authority", "call_remote", "reliable")
func died(cause: String, spawn: Vector3) -> void:
	died_received.emit(cause, spawn)


# The character's skills (protocol 37, data/items/skills.json): attributes [strength, memory] (-10..10) and one row
# [skill index in the file's "skills" order, working level 0..100, rusty 0/1, cap, training level, practised today 0/1, effective value, percent of the way to the next level 0..99, percent of today's gain left 0..100] for every skill the character has practised or reads above 1 through training.
# Sent at hello and when a level, attribute or rusty flag changes (at most every 5 s).
@rpc("authority", "call_remote", "reliable")
func skills(attributes: PackedInt32Array, rows: Array) -> void:
	skills_received.emit(attributes, rows)


# What the character wears (protocol 40, data/items/clothing.json): one item number per body slot in the file's order
# (head, body, legs, feet, hands, back), 0 = nothing. Sent at hello and when it changes.
@rpc("authority", "call_remote", "reliable")
func worn(numbers: PackedInt32Array) -> void:
	worn_received.emit(numbers)


# Classic NPCs (protocol 45, data/npcs): the roster [[id, name, role, outfit], ...] at hello, then the NPCs within 120 m as
# [[id, position, heading radians, state], ...] (state 0 stand, 1 walk, 2 sit, 3 sleep) about four times a second when something changed.
@rpc("authority", "call_remote", "reliable")
func npc_roster(rows: Array) -> void:
	npc_roster_received.emit(rows)


@rpc("authority", "call_remote", "unreliable")
func npcs(rows: Array) -> void:
	npcs_received.emit(rows)


# Animals (protocol 48, data/animals/animals.json): the animals within 120 m as [[id, species number, position, heading radians,
# state 0 graze / 1 hop / 2 flee / 3 alert], ...], nearest 30, about four times a second when something near changed.
@rpc("authority", "call_remote", "unreliable")
func animals(rows: Array) -> void:
	animals_received.emit(rows)


# The blood trail of wounded animals (protocol 55): positions of drops within 120 m, nearest 80, sent when the set changes.
@rpc("authority", "call_remote", "reliable")
func blood(points: PackedVector3Array) -> void:
	blood_received.emit(points)


# Talking (protocol 45): the player asks to talk to an NPC (choice -1) or picks a choice by index; the server answers with the NPC's
# line, the choices on offer and whether the talk ends. voice_id names the voice for text to voice (Mandy). Range, pace and every
# effect are checked on the server.
@rpc("any_peer", "call_remote", "reliable")
func npc_talk(npc_id: String, choice: int) -> void:
	if multiplayer.is_server():
		npc_talk_requested.emit(multiplayer.get_remote_sender_id(), npc_id, choice)


@rpc("authority", "call_remote", "reliable")
func npc_say(npc_id: String, npc_name: String, text: String, voice_id: String, choices: PackedStringArray, ends: bool) -> void:
	npc_say_received.emit(npc_id, npc_name, text, voice_id, choices, ends)


# Admin placement (protocol 45): kind "marker" with arg "bed", "chair" or "post" adds a world marker at pos; kind "npc" with an
# NPC id as arg moves that NPC's home to pos. The server refuses anyone whose player key is not in data/admin.json.
@rpc("any_peer", "call_remote", "reliable")
func admin_place(kind: String, pos: Vector3, arg: String) -> void:
	if multiplayer.is_server():
		admin_place_requested.emit(multiplayer.get_remote_sender_id(), kind, pos, arg)


# The owner's death markers (protocol 39): [[position Vector3, seconds until the remains are cleaned up], ...] for their remains
# that still hold gear. Sent at hello, when one appears and when one is emptied or cleaned up; the client counts the time down.
@rpc("authority", "call_remote", "reliable")
func remains_marks(rows: Array) -> void:
	remains_received.emit(rows)


# The inner voice (protocol 38, data/items/inner_voice.json): one remark of the character's own thoughts. `line_id` is stable
# for the line's text (the audio file inner_voice/<line_id>.ogg Sounds records for it), `kind` the group (vomit, diarrhea, ...).
# The client plays the audio if it exists and always shows the text as a subtitle.
@rpc("authority", "call_remote", "reliable")
func thought(line_id: String, text: String, kind: String) -> void:
	thought_received.emit(line_id, text, kind)


# Sickness from rotten food (protocol 38, data/items/sickness.json): game hours left, rounded up; 0 = well. At hello and on change.
@rpc("authority", "call_remote", "reliable")
func sick(hours: int) -> void:
	sick_received.emit(hours)


# A crippling injury (protocol 58, wolves): the share of normal speed the player may move at, 100 = no limp. At hello and on change.
@rpc("authority", "call_remote", "reliable")
func limp(percent: int) -> void:
	limp_received.emit(percent)


# The heart in the ears and the wake timer (protocol 59, sleep.json and exertion.json): beats per minute (0 when awake), real
# seconds until the sleeper or fainted player is awake again (steps of 5), and the phase: 0 awake, 1 falling asleep, 2 out
# (asleep or fainted), 3 waking. Sent whenever one of them changes.
@rpc("authority", "call_remote", "reliable")
func body(bpm: int, eta_s: int, phase: int) -> void:
	body_received.emit(bpm, eta_s, phase)


# Body warmth, 0 to 100 percent (protocol 36, data/items/warmth.json): at hello and whenever the whole percent changes.
@rpc("authority", "call_remote", "reliable")
func warmth(percent: int) -> void:
	warmth_received.emit(percent)


# The energy pool, 0 to 100 percent (job 95): at hello and whenever the whole percent changes.
@rpc("authority", "call_remote", "reliable")
func energy(percent: int) -> void:
	energy_received.emit(percent)


# Air left under water in tenths of a second, or -1 when the head is above the surface (the oxygen symbol hides).
@rpc("authority", "call_remote", "reliable")
func breath(deciseconds: int) -> void:
	breath_received.emit(deciseconds)


# The contents of a chest the player opened (30 slots in the inventory byte format).
@rpc("authority", "call_remote", "reliable")
func chest_contents(id: int, bytes: PackedByteArray) -> void:
	chest_received.emit(id, bytes)


# One item gain for the pickup feed (protocol 60): sent to the player who gained it. source: pickup, harvest, craft, quest.
@rpc("authority", "call_remote", "reliable")
func item_gain(item_id: String, count: int, source: String) -> void:
	item_received.emit(item_id, count, source)


# A trader's window (protocol 62): what they sell (item ids), the multiples of an item's value you pay and they pay (thousandths),
# and the kinds of item they buy.
@rpc("authority", "call_remote", "reliable")
func shop(npc_id: String, title: String, ids: PackedStringArray, pay_milli: int, get_milli: int, buys: PackedStringArray, tired_ids: PackedStringArray, tired_milli: PackedInt32Array, stock: PackedInt32Array, supply_milli: PackedInt32Array, trader_purse: int) -> void:
	shop_received.emit(npc_id, title, ids, pay_milli, get_milli, buys, tired_ids, tired_milli, stock, supply_milli, trader_purse)


# Buy (kind 0, a = index in the shop's list) or sell (kind 1, a = pack slot). The server prices and checks everything.
@rpc("any_peer", "call_remote", "reliable")
func trade(npc_id: String, kind: int, a: int, count: int) -> void:
	if multiplayer.is_server():
		trade_requested.emit(multiplayer.get_remote_sender_id(), npc_id, kind, a, count)


# Game trails (protocol 65): one block of worn grass, compressed (src/shared/trail_codec.gd decode() gives {cell index: strength 0..1};
# index = local_x + local_z * 64 from the block's south-west corner; block = 256 m, cell = 4 m, see data/animals/trails.json).
# Sent for the 3 x 3 blocks around the player when they enter a block and when a block changes (at most every 30 s a block).
@rpc("authority", "call_remote", "reliable")
func trails(block_x: int, block_z: int, bytes: PackedByteArray) -> void:
	trails_received.emit(block_x, block_z, bytes)


# The large log on the shoulder (protocol 64): its item id, "" when nothing is carried. The client counts its weight in the load
# and Mandy's character reads InventoryView.shoulder_id to show the carry pose.
@rpc("authority", "call_remote", "reliable")
func carry(item_id: String) -> void:
	carry_received.emit(item_id)


# The purse as a number of copper (protocol 61); the client shows it as copper, bronze, silver and gold.
@rpc("authority", "call_remote", "reliable")
func purse(copper: int) -> void:
	purse_received.emit(copper)


# Each NPC this player has a reputation with: ids, display names and points (protocol 61).
@rpc("authority", "call_remote", "reliable")
func reputation(ids: PackedStringArray, names: PackedStringArray, points: PackedInt32Array) -> void:
	reputation_received.emit(ids, names, points)


# A short message for the player ("too many trunks lie here", and so on).
@rpc("authority", "call_remote", "reliable")
func notice(text: String) -> void:
	notice_received.emit(text)
