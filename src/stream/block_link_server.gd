extends RefCounted

# Server side of the direct block line (see block_link.gd for why and the frames).
# Its own thread accepts connections and reads requests; worker threads write the
# finished blocks straight to the line, without waiting for the main thread's frame.
# A line only serves the ENet peer it says it is; the game connection stays the
# fallback when it is missing.

const KIND_HELLO := 0
const KIND_REQUEST := 1
const MAX_FRAME := 1 << 20

var on_request: Callable                 # (peer_id, keys, urgent) on the line's thread
var is_peer: Callable                    # (peer_id) -> bool: an ENet peer that is connected
var blocks_out: int = 0
var bytes_out: int = 0

var _server: TCPServer = TCPServer.new()
var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _stopping: bool = false
var _pending: Array = []                 # [tcp, inbox, since msec] before their hello
var _lines: Dictionary = {}              # peer id -> {"tcp", "inbox", "mutex"}


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


func has_line(peer_id: int) -> bool:
	_mutex.lock()
	var has: bool = _lines.has(peer_id)
	_mutex.unlock()
	return has


func drop(peer_id: int) -> void:
	_mutex.lock()
	var line: Dictionary = _lines.get(peer_id, {})
	_lines.erase(peer_id)
	_mutex.unlock()

	if not line.is_empty():
		line["mutex"].lock()
		line["tcp"].disconnect_from_host()
		line["mutex"].unlock()


# Worker thread: sends one block; false when this peer has no line (use ENet).
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
	line["mutex"].lock()
	var ok: bool = line["tcp"].get_status() == StreamPeerTCP.STATUS_CONNECTED and line["tcp"].put_data(frame) == OK
	line["mutex"].unlock()

	if not ok:
		drop(peer_id)
		return false

	_mutex.lock()
	blocks_out += 1
	bytes_out += bytes.size()
	_mutex.unlock()
	return true


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
			_pending.append([tcp, PackedByteArray(), Time.get_ticks_msec()])

		var still: Array = []

		for item in _pending:
			var peer_id: int = _read_hello(item)

			if peer_id > 0:
				_mutex.lock()
				_lines[peer_id] = {"tcp": item[0], "inbox": item[1], "mutex": Mutex.new()}
				_mutex.unlock()
			elif peer_id == 0 and Time.get_ticks_msec() - int(item[2]) < 5000:
				still.append(item)
			else:
				item[0].disconnect_from_host()

		_pending = still
		_mutex.lock()
		var lines: Dictionary = _lines.duplicate()
		_mutex.unlock()

		for peer_id in lines:
			_read_requests(peer_id, lines[peer_id])

		OS.delay_msec(1)


# 0 while waiting, -1 for a bad or unknown peer, else the peer id.
func _read_hello(item: Array) -> int:
	var tcp: StreamPeerTCP = item[0]
	tcp.poll()

	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return -1

	var available: int = tcp.get_available_bytes()

	if available > 0:
		item[1].append_array(tcp.get_data(available)[1])

	if item[1].size() < 12:
		return 0

	var peer_id: int = item[1].decode_s32(8)

	if item[1].decode_u32(0) != 8 or item[1].decode_u32(4) != KIND_HELLO or not is_peer.call(peer_id):
		return -1

	item[1] = item[1].slice(12)
	return peer_id


func _read_requests(peer_id: int, line: Dictionary) -> void:
	var tcp: StreamPeerTCP = line["tcp"]
	line["mutex"].lock()
	tcp.poll()
	var connected: bool = tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED
	var available: int = tcp.get_available_bytes() if connected else 0

	if available > 0:
		line["inbox"].append_array(tcp.get_data(available)[1])

	line["mutex"].unlock()

	if not connected:
		drop(peer_id)
		return

	var inbox: PackedByteArray = line["inbox"]
	var at: int = 0

	while inbox.size() - at >= 4:
		var size: int = inbox.decode_u32(at)

		if size < 8 or size > MAX_FRAME:
			drop(peer_id)
			return

		if inbox.size() - at - 4 < size:
			break

		if inbox.decode_u32(at + 4) == KIND_REQUEST and (size - 8) % 16 == 0:
			var urgent: int = inbox.decode_u32(at + 8)
			var keys: PackedInt32Array = inbox.slice(at + 12, at + 4 + size).to_int32_array()
			on_request.call(peer_id, keys, clampi(urgent, 0, keys.size() / 4))

		at += 4 + size

	line["inbox"] = inbox.slice(at)
