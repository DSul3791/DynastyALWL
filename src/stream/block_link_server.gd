extends RefCounted

# Server side of the direct block line (see block_link.gd for why and the frames).
# Its own thread accepts connections and reads requests; worker threads write the
# finished blocks straight to the line, without waiting for the main thread's frame.
# A line only serves the ENet peer it says it is; the game connection stays the
# fallback when it is missing.

const KIND_HELLO := 0
const KIND_REQUEST := 1
const KIND_STATUS := 2                   # (server pick page) a line that opens with [u32 4][u32 2] instead of a hello gets one status frame
                                         # [u32 size][u32 2][JSON utf-8] and is closed: name, message, build, protocol, players, max_players, locked
const MAX_FRAME := 1 << 20
const NetSettings := preload("res://src/shared/net_settings.gd")

var on_request: Callable                 # (peer_id, keys, urgent) on the line's thread
var is_peer: Callable                    # (peer_id) -> bool: an ENet peer that is connected
var blocks_out: int = 0                   # blocks the line took (some may still wait in its outbox)
var bytes_out: int = 0
var _sending: int = 0                    # workers inside send() now (first-load plan, option A); a send no longer waits on the client, only on the line's mutex
# A player whose game stops reading (hung, or a bad client) must never hold the block workers, which serve every player (22 Nov 2026).
# Sends are non-blocking: what the socket will not take now waits in that line's outbox, which the line's thread writes on. While the
# outbox holds outbox_max_bytes, a send returns false and that block goes over the game connection, so nothing the line has taken is
# ever thrown away for a slow player. A line that takes nothing for stall_msec while it has blocks waiting is dropped (logged once):
# that player gets blocks over the game connection, as when the line closes for any other reason. data/network.json
# block_line_outbox_kb and block_line_stall_ms (60 s, the ENet peer timeout's minimum: a game frozen longer is being dropped anyway);
# tests set these directly.
var outbox_max_bytes: int = NetSettings.value("block_line_outbox_kb", 8192) * 1024
var stall_msec: int = NetSettings.value("block_line_stall_ms", 60000)
var lines_dropped: int = 0               # lines dropped for a stall (each logged once)
var sends_refused: int = 0               # sends turned to the game connection because a line's outbox was full

var _server: TCPServer = TCPServer.new()
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _stopping: bool = false
var _pending: Array = []                 # [tcp, inbox, since msec] before their hello
var _lines: Dictionary = {}              # peer id -> {"tcp", "inbox", "mutex", "outbox" and "out_at" (bytes from out_at on not yet taken by the socket), "since" (msec of the last write, or when the outbox filled)}
var _status: PackedByteArray = PackedByteArray()   # the status reply's JSON, set on the main thread (set_status)


# The server's status for the server pick page; the line's thread answers with the latest one.
func set_status(info: Dictionary) -> void:
	var bytes: PackedByteArray = JSON.stringify(info).to_utf8_buffer()
	_mutex.lock()
	_status = bytes
	_mutex.unlock()


# Returns the port, or 0 when it cannot listen.
func start(port: int) -> int:
	if _server.listen(port) != OK:
		return 0

	_thread = Thread.new()
	_thread.start(_loop)
	return port


func stop() -> void:
	_mutex.lock()
	_stopping = true
	_mutex.unlock()

	if _thread != null:
		_thread.wait_to_finish()

	_server.stop()


# Forgets a player's line and closes it. `only` (a line's dictionary): drop that line only, not a newer one the same peer id opened since.
# `why`: printed when the line is really dropped (off the main thread: the line's thread or a worker), so a log says which end closed
# a line and why (cold first joins, 22 Nov 2026: every line closed just before the long freeze). Empty: silent (the player left).
func drop(peer_id: int, only: Dictionary = {}, why: String = "") -> void:
	_mutex.lock()
	var line: Dictionary = _lines.get(peer_id, {})

	if not only.is_empty() and not line.is_empty() and line["mutex"] != only["mutex"]:
		line = {}
	elif not line.is_empty():
		_lines.erase(peer_id)

	_mutex.unlock()

	if not line.is_empty() and why != "":
		print("Terrain server: block line of peer %d closed: %s" % [peer_id, why])

	if not line.is_empty():
		line["mutex"].lock()
		line["tcp"].disconnect_from_host()
		line["mutex"].unlock()


# Workers waiting in send() now (any thread).
func sending() -> int:
	_mutex.lock()
	var count: int = _sending
	_mutex.unlock()
	return count


# Worker thread: sends one block; false when this peer has no line (use ENet). Never waits for the client: what the socket does not take
# now goes to the line's outbox; false also while that outbox is full (the block goes over ENet, the line stays). True means the line
# has the block. Only a line dropped for a stall loses what its outbox held; that game was not reading, and asks again when it moves on.
func send(peer_id: int, key: Vector4i, bytes: PackedByteArray) -> bool:
	_mutex.lock()
	var line: Dictionary = _lines.get(peer_id, {})
	_mutex.unlock()

	if line.is_empty():
		return false

	var frame: PackedByteArray = PackedByteArray()
	frame.resize(20)
	frame.encode_u32(0, 16 + bytes.size())
	frame.encode_s32(4, key.x)
	frame.encode_s32(8, key.y)
	frame.encode_s32(12, key.z)
	frame.encode_s32(16, key.w)
	frame.append_array(bytes)
	_mutex.lock()
	_sending += 1
	_mutex.unlock()
	line["mutex"].lock()
	var why: String = ""
	var full: bool = false

	if line["tcp"].get_status() != StreamPeerTCP.STATUS_CONNECTED:
		why = "closed"
	elif not _write_outbox(line):
		why = "closed"
	elif _waiting(line) + frame.size() > outbox_max_bytes:
		full = true
		line["full_logged"] = bool(line.get("full_logged", false)) or _note_full(peer_id)
	else:
		if _waiting(line) == 0:
			line["since"] = Time.get_ticks_msec()

		var outbox: PackedByteArray = line["outbox"]
		line["outbox"] = PackedByteArray()   # the only reference while it grows, so append_array does not copy it
		outbox.append_array(frame)
		line["outbox"] = outbox

		if not _write_outbox(line):
			why = "closed"

	line["mutex"].unlock()
	_mutex.lock()
	_sending -= 1

	if full:
		sends_refused += 1

	_mutex.unlock()

	if why != "":
		drop(peer_id, line, "a block could not be written (the game's end is gone)")
		return false

	if full:
		return false

	_mutex.lock()
	blocks_out += 1
	bytes_out += bytes.size()
	_mutex.unlock()
	return true


const WRITE_CHUNK := 256 * 1024         # bytes handed to the socket per call (a slice is a copy; a backlog is never copied whole)


# Bytes in the line's outbox the socket has not taken (with the line's mutex held).
func _waiting(line: Dictionary) -> int:
	return (line["outbox"] as PackedByteArray).size() - int(line["out_at"])


# With the line's mutex held: writes what the socket takes now, without waiting. False when the line is broken.
func _write_outbox(line: Dictionary) -> bool:
	var outbox: PackedByteArray = line["outbox"]
	var at: int = int(line["out_at"])

	while at < outbox.size():
		var chunk: PackedByteArray = outbox.slice(at, mini(at + WRITE_CHUNK, outbox.size()))
		var result: Array = line["tcp"].put_partial_data(chunk)

		if int(result[0]) != OK:
			return false

		var sent: int = int(result[1])

		if sent > 0:
			at += sent
			line["since"] = Time.get_ticks_msec()

		if sent < chunk.size():
			break   # the socket is full: the rest waits for the line's thread

	if at >= outbox.size():
		line["outbox"] = PackedByteArray()
		at = 0
	elif at >= WRITE_CHUNK and at * 2 >= outbox.size():
		line["outbox"] = outbox.slice(at)   # forget what was sent, at most once per half of the outbox
		at = 0

	line["out_at"] = at
	return true


# The first time a line's outbox is full: one log line (with the line's mutex held; printing needs no other lock). True, for full_logged.
func _note_full(peer_id: int) -> bool:
	print("Terrain server: block line of peer %d is %d KB behind; further blocks go over the game connection until it catches up" % [peer_id, outbox_max_bytes >> 10])
	return true


# Drops a line that took nothing for the stall time; logged once (the first caller takes the line out of _lines, so a second finds nothing).
func _drop_stalled(peer_id: int, line: Dictionary) -> void:
	_mutex.lock()
	var had: bool = _lines.get(peer_id, {}).get("mutex") == line["mutex"]

	if had:
		lines_dropped += 1

	_mutex.unlock()

	if had:
		print("Terrain server: block line of peer %d dropped: it took no block data for %.0f s (the game is not reading blocks); its blocks go over the game connection" % [peer_id, stall_msec / 1000.0])
		drop(peer_id, line)


func _loop() -> void:
	while true:
		_mutex.lock()
		var stopping: bool = _stopping
		_mutex.unlock()

		if stopping:
			return

		while _server.is_connection_available():
			var tcp: StreamPeerTCP = _server.take_connection()
			tcp.set_no_delay(true)
			_pending.append([tcp, PackedByteArray(), Time.get_ticks_msec(), ""])   # [tcp, inbox, since msec, why it was refused]

		var still: Array = []

		for item in _pending:
			var peer_id: int = _read_hello(item)

			if peer_id > 0:
				_mutex.lock()
				_lines[peer_id] = {"tcp": item[0], "inbox": item[1], "mutex": Mutex.new(), "outbox": PackedByteArray(), "out_at": 0, "since": Time.get_ticks_msec()}
				_mutex.unlock()
			elif peer_id == 0 and Time.get_ticks_msec() - int(item[2]) < 5000:
				still.append(item)
			else:
				if peer_id == 0:
					print("Terrain server: a block line closed: no hello within 5 s of connecting (%d bytes came)" % (item[1] as PackedByteArray).size())
				elif str(item[3]) != "":
					print("Terrain server: a block line closed before it served anyone: %s" % str(item[3]))

				item[0].disconnect_from_host()

		_pending = still
		_mutex.lock()
		var lines: Dictionary = _lines.duplicate()
		_mutex.unlock()

		for peer_id in lines:
			_read_requests(peer_id, lines[peer_id])

		OS.delay_msec(1)


# 0 while waiting, -1 for a bad or unknown peer (item[3] says why; empty for a status request, which is normal), else the peer id.
func _read_hello(item: Array) -> int:
	var tcp: StreamPeerTCP = item[0]
	tcp.poll()

	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		item[3] = "the game's end closed it before its hello (status %d, %d bytes came)" % [tcp.get_status(), (item[1] as PackedByteArray).size()]
		return -1

	var available: int = tcp.get_available_bytes()

	if available > 0:
		item[1].append_array(tcp.get_data(available)[1])

	if item[1].size() >= 8 and item[1].decode_u32(0) == 4 and item[1].decode_u32(4) == KIND_STATUS:
		_answer_status(tcp)
		return -1

	if item[1].size() < 12:
		return 0

	var peer_id: int = item[1].decode_s32(8)

	if item[1].decode_u32(0) != 8 or item[1].decode_u32(4) != KIND_HELLO:
		item[3] = "not a hello (size %d, kind %d)" % [item[1].decode_u32(0), item[1].decode_u32(4)]
		return -1

	if not is_peer.call(peer_id):
		item[3] = "peer %d is not a connected player" % peer_id
		return -1

	item[1] = item[1].slice(12)
	return peer_id


func _answer_status(tcp: StreamPeerTCP) -> void:
	_mutex.lock()
	var body: PackedByteArray = _status
	_mutex.unlock()
	var frame: PackedByteArray = PackedByteArray()
	frame.resize(8)
	frame.encode_u32(0, 4 + body.size())
	frame.encode_u32(4, KIND_STATUS)
	frame.append_array(body)
	tcp.put_data(frame)


func _read_requests(peer_id: int, line: Dictionary) -> void:
	var tcp: StreamPeerTCP = line["tcp"]
	line["mutex"].lock()
	tcp.poll()
	var connected: bool = tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED
	var available: int = tcp.get_available_bytes() if connected else 0

	if available > 0:
		line["inbox"].append_array(tcp.get_data(available)[1])

	connected = connected and _write_outbox(line)   # the outbox goes on here between the workers' sends
	var stalled: bool = connected and _waiting(line) > 0 and Time.get_ticks_msec() - int(line["since"]) > stall_msec
	line["mutex"].unlock()

	if not connected:
		drop(peer_id, line, "the game's end closed it (status %d)" % tcp.get_status())
		return

	if stalled:
		_drop_stalled(peer_id, line)
		return

	var inbox: PackedByteArray = line["inbox"]
	var at: int = 0

	while inbox.size() - at >= 4:
		var size: int = inbox.decode_u32(at)

		if size < 8 or size > MAX_FRAME:
			drop(peer_id, line, "a request frame of %d bytes" % size)
			return

		if inbox.size() - at - 4 < size:
			break

		if inbox.decode_u32(at + 4) == KIND_REQUEST and (size - 8) % 16 == 0:
			var urgent: int = inbox.decode_u32(at + 8)
			var keys: PackedInt32Array = inbox.slice(at + 12, at + 4 + size).to_int32_array()
			on_request.call(peer_id, keys, clampi(urgent, 0, keys.size() / 4))

		at += 4 + size

	line["inbox"] = inbox.slice(at)
