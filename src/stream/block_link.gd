extends RefCounted

# Client side of the direct block line (owner bug 2026-10-20: ground after a flight
# took half a minute). Voxel Tools loads blocks one at a time, and over the game's
# ENet connection every missing block waited for a client frame to send the request
# and another to receive the answer (at 30 fps that alone is about 35 ms a block).
# This TCP connection to the server's block port is used straight from the loader
# thread: the request goes out at once and the waiting loader reads its own answer.
#
# Frames, both ways: u32 length of the rest, then
#   client -> server: u32 kind (0 hello: i32 ENet peer id; 1 request: u32 urgent count, i32 keys)
#   server -> client: i32 x, y, z, lod, then the block bytes
# Thread safe: send and pump may be called from any thread.

const KIND_HELLO := 0
const KIND_REQUEST := 1
const CONNECT_MSEC := 3000               # given up (ENet carries the blocks) if not connected by then

var stream                               # NetworkVoxelStream that gets the blocks
var blocks_in: int = 0

var _tcp: StreamPeerTCP = StreamPeerTCP.new()
var _mutex: Mutex = Mutex.new()
var _inbox: PackedByteArray = PackedByteArray()
var _peer_id: int = 0
var _state: int = 0                      # 0 connecting, 1 ready, 2 off
var _started_msec: int = 0


# Main thread: starts connecting (port 0: the server has no block port).
func open(host: String, port: int, peer_id: int) -> void:
	_peer_id = peer_id
	_started_msec = Time.get_ticks_msec()

	if port <= 0 or _tcp.connect_to_host(host, port) != OK:
		_state = 2
		return

	_tcp.set_no_delay(true)


func ready() -> bool:
	return _state == 1


func close() -> void:
	_mutex.lock()
	_tcp.disconnect_from_host()
	_state = 2
	_mutex.unlock()


# Sends a request; false when the line is not up (the caller uses ENet instead).
func send_request(keys: PackedInt32Array, urgent: int) -> bool:
	if keys.is_empty():
		return true

	var body: StreamPeerBuffer = StreamPeerBuffer.new()
	body.put_u32(0)
	body.put_u32(KIND_REQUEST)
	body.put_u32(urgent)

	for key in keys:
		body.put_32(key)

	body.seek(0)
	body.put_u32(body.get_size() - 4)
	_mutex.lock()
	var sent: bool = _state == 1 and _tcp.put_data(body.data_array) == OK

	if _state == 1 and not sent:
		_state = 2
		print("Terrain client: the block line closed; blocks come over the game connection")

	_mutex.unlock()
	return sent


# Reads what arrived and hands finished blocks to the stream.
func pump() -> void:
	var keys: PackedInt32Array = PackedInt32Array()
	var payloads: Array = []
	_mutex.lock()

	if _state == 2:
		_mutex.unlock()
		return

	_tcp.poll()
	var status: int = _tcp.get_status()

	if _state == 0:
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var hello: StreamPeerBuffer = StreamPeerBuffer.new()
			hello.put_u32(8)
			hello.put_u32(KIND_HELLO)
			hello.put_32(_peer_id)
			_tcp.put_data(hello.data_array)
			_state = 1
			print("Terrain client: block line open")
		elif status != StreamPeerTCP.STATUS_CONNECTING or Time.get_ticks_msec() - _started_msec > CONNECT_MSEC:
			_state = 2
			print("Terrain client: no block line; blocks come over the game connection")
	elif status != StreamPeerTCP.STATUS_CONNECTED:
		_state = 2
		print("Terrain client: the block line closed; blocks come over the game connection")
	else:
		var available: int = _tcp.get_available_bytes()

		if available > 0:
			var got: Array = _tcp.get_data(available)

			if got[0] == OK:
				_inbox.append_array(got[1])

		var at: int = 0

		while _inbox.size() - at >= 4:
			var size: int = _inbox.decode_u32(at)

			if _inbox.size() - at - 4 < size:
				break

			var start: int = at + 4
			keys.append_array(PackedInt32Array([_inbox.decode_s32(start), _inbox.decode_s32(start + 4), _inbox.decode_s32(start + 8), _inbox.decode_s32(start + 12)]))
			payloads.append(_inbox.slice(start + 16, start + size))
			at = start + size

		if at > 0:
			_inbox = _inbox.slice(at)

	blocks_in += payloads.size()
	var target = stream
	_mutex.unlock()

	if not payloads.is_empty() and target != null:
		target.deliver(keys, payloads)
