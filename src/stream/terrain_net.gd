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
#   client -> server  request_flora    flora chunks wanted (pairs of chunk x, z)
#   server -> client  deliver_flora    one chunk's flora (FloraPlacer.encode, removals applied)
#                                      and its rivers and lakes (WaterGrid.encode, empty if dry)
#   client -> server  report_position  where the player is and how fast it moves (a few times a second),
#                                      so the server makes the ground ahead of and under them first
#   client -> server  cut_flora        remove one flora item (test harvest)
#   server -> client  flora_cut        a flora item was removed
#   client -> server  clear_ground     throw the generated ground away (only honoured from the
#                                      same computer: the options menu's Clear saved ground)
#   server -> client  ground_cleared   done; the client clears its own cache and reloads
#
# A block key is four ints: block x, y, z (in 16-voxel blocks at its LOD)
# and the LOD.

const PROTOCOL_VERSION := 6

signal welcome_received(info: Dictionary)
signal blocks_requested(peer_id: int, keys: PackedInt32Array, urgent: int)
signal blocks_received(keys: PackedInt32Array, payloads: Array)
signal tile_changed_received(tile: Vector2i, revision: int)
signal dig_requested(peer_id: int, center: Vector3, radius: float)
signal dug_received(center: Vector3, radius: float)
signal flora_requested(peer_id: int, chunks: PackedInt32Array)
signal flora_received(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray)
signal position_reported(peer_id: int, position: Vector3, velocity: Vector3)
signal cut_flora_requested(peer_id: int, chunk: Vector2i, id: int)
signal flora_cut_received(chunk: Vector2i, id: int)
signal clear_ground_requested(peer_id: int)
signal ground_cleared_received()


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
	if multiplayer.is_server() and chunks.size() % 2 == 0:
		flora_requested.emit(multiplayer.get_remote_sender_id(), chunks)


@rpc("authority", "call_remote", "reliable")
func deliver_flora(chunk: Vector2i, bytes: PackedByteArray, water: PackedByteArray) -> void:
	flora_received.emit(chunk, bytes, water)


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


@rpc("any_peer", "call_remote", "reliable")
func clear_ground() -> void:
	clear_ground_requested.emit(multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func ground_cleared() -> void:
	ground_cleared_received.emit()
